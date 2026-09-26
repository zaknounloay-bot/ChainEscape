extends Node
## Automated play-through of every level through the real game scene.
##
## Taps are injected as InputEventScreenTouch at block screen positions, so
## this exercises the actual input -> rules -> animation -> UI path.
##
## Per level: a blocked tap (no removal, chain reset, heart lost from level
## 6), a Hint (legal, keeps the board solvable, not auto-played, costs a
## token), an Undo (block and spinner directions restored), then the level
## is cleared by following the solver and LEVEL COMPLETE must appear.
## Extra scenarios: running out of hearts, Restart, a spinner trap leading to
## "no moves", and progress / hint tokens persisting to disk.
##
##   godot --headless --path . res://tools/Playtest.tscn
##   godot --path . res://tools/Playtest.tscn -- --shots=/tmp/shots
##     (with a display, also saves screenshots)

const PROGRESS_PATH := "user://playtest_progress.cfg"

var game: GameManager
var shots_dir := ""
var failures: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	# Never touch the real player's progress.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	PlayerProgress.default_path = PROGRESS_PATH
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	var total: int = game.level_manager.level_count
	print("Levels found: %d" % total)
	_check(total >= 30, "expected at least 30 levels")
	game.progress.hint_tokens = 50  # enough to test a hint on every level
	await _test_out_of_hearts()
	await _test_restart()
	await _test_trap_and_stuck()
	for n in range(1, total + 1):
		await _play_level(n)
	_test_persistence(total)
	if failures.is_empty():
		print("PLAYTEST PASSED: all %d levels cleared, hearts/hints/undo/restart/persistence OK" % total)
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


func _play_level(n: int) -> void:
	game.start_level(n)
	await _wait(0.45)
	_shot("L%02d_start" % n)
	var start_count := game.model.block_count()
	var expected_hearts := 3 if n >= GameManager.HEARTS_FROM_LEVEL else 0
	_check(game.max_hearts == expected_hearts and game.hearts == expected_hearts, "L%d starts with %d hearts" % [n, expected_hearts])

	# 1) Blocked tap: stays, chain resets, costs a heart from level 6.
	var blocked := _first_blocked()
	if blocked != -1:
		var before := game.model.block_count()
		await _tap(blocked)
		await _wait(0.05)
		_shot("L%02d_bump" % n)
		_check(game.model.block_count() == before, "L%d blocked tap removed a block" % n)
		_check(game.chain == 0, "L%d chain not reset after blocked tap" % n)
		_check(game.hearts == maxi(expected_hearts - 1, 0), "L%d blocked tap heart count" % n)
		await _wait(0.2)

	# 2) Hint: highlights a legal, still-solvable move, spends one token,
	#    and does not play it.
	var tokens_before: int = game.progress.hint_tokens
	var count_before := game.model.block_count()
	game.request_hint()
	await _frames(2)
	var hinted := game.hint_block
	_check(hinted != -1, "L%d hint produced a move" % n)
	_check(game.model.block_count() == count_before, "L%d hint must not play the move" % n)
	_check(game.progress.hint_tokens == tokens_before - 1, "L%d hint spent exactly one token" % n)
	if hinted != -1:
		_check(game.model.can_escape(hinted), "L%d hint %d is a legal move" % [n, hinted])
		_check(game.board.get_view(hinted).hinted, "L%d hinted block is highlighted" % n)
		_shot("L%02d_hint" % n)
		game.request_hint()  # second press while showing: free, no change
		_check(game.progress.hint_tokens == tokens_before - 1, "L%d repeated hint press not charged" % n)

	# 3) Clear the level following the solver; Undo once after 2 moves.
	var taps := 0
	var undo_tested := false
	var order: Array = []
	while not game.model.is_empty():
		var id := Solver.from_model(game.model).recommend_move()
		_check(id != -1, "L%d solver found no move with %d blocks left" % [n, game.model.block_count()])
		if id == -1:
			return
		var snapshot := _directions()
		var before_count := game.model.block_count()
		await _tap(id)
		_check(game.model.block_count() == before_count - 1, "L%d tap on block %d did not remove it" % [n, id])
		_check(game.hint_block == -1, "L%d hint cleared after a move" % n)
		order.append(id)
		taps += 1
		if taps == 3:
			_shot("L%02d_chain" % n)
		if taps == 2 and not undo_tested and not game.model.is_empty():
			undo_tested = true
			var chain_before_last: int = game.chain - 1
			game.undo()
			await _wait(0.05)
			_check(game.model.blocks.has(id), "L%d undo did not restore block %d" % [n, id])
			_check(game.chain == chain_before_last, "L%d undo did not restore chain" % n)
			_check(game.board.get_view(id) != null, "L%d undo did not recreate the view" % n)
			_check(_directions() == snapshot, "L%d undo did not restore spinner directions" % n)
			await _wait(0.3)
			taps -= 1
			order.pop_back()
		await _wait(0.08)
	await _wait(0.9)
	_shot("L%02d_complete" % n)
	_check(game.ui.is_complete_visible(), "L%d complete card not shown" % n)
	_check(game.progress.highest_completed >= n, "L%d completion not recorded" % n)
	print("Level %2d  %-22s blocks=%2d spinners=%d best_chain=%2d tokens=%d" % [
		n, game.level.name, start_count, game.level.blocks.filter(func(b): return b.is_spinner()).size(),
		game.best_chain, game.progress.hint_tokens])


## Level 6: three blocked taps -> Try Again -> fresh attempt with 3 hearts.
func _test_out_of_hearts() -> void:
	game.start_level(6)
	await _wait(0.4)
	for i in 3:
		var b := _first_blocked()
		_check(b != -1, "level 6 has a blocked block")
		await _tap(b)
		await _wait(0.1)
	_check(game.hearts == 0 and game.game_over, "out of hearts after 3 blocked taps")
	var count := game.model.block_count()
	await _tap(game.model.free_block_ids()[0])
	_check(game.model.block_count() == count, "input locked while out of hearts")
	await _wait(0.7)
	_shot("hearts_try_again")
	await _wait(1.4)
	_check(not game.game_over and game.hearts == 3, "level restarted with 3 hearts")
	_check(game.model.block_count() == game.level.blocks.size(), "restart after try-again restores all blocks")
	print("Out-of-hearts flow OK")


func _test_restart() -> void:
	game.start_level(7)
	await _wait(0.4)
	await _tap(Solver.from_model(game.model).recommend_move())
	await _tap(_first_blocked())
	_check(game.hearts == 2, "heart lost before restart")
	game.restart()
	await _wait(0.1)
	_check(game.model.block_count() == game.level.blocks.size() and game.hearts == 3 and not game.history.can_undo(),
		"restart resets blocks, hearts and history")
	print("Restart OK")


## Level 10: taking the free non-spinner first turns the spinner into a
## dead end. The board must report no moves, Hint must not charge, Undo
## must recover.
func _test_trap_and_stuck() -> void:
	game.start_level(10)
	await _wait(0.4)
	var legal := game.model.free_block_ids()
	var trap := -1
	for id in legal:
		var m := BoardModel.new()
		m.setup(game.model.rows, game.model.columns, game.model.snapshot())
		m.remove(id)
		if not Solver.from_model(m).is_solvable():
			trap = id
	_check(trap != -1, "level 10 has a trap move")
	if trap == -1:
		return
	await _tap(trap)
	await _wait(0.3)
	_shot("L10_trapped")
	var tokens: int = game.progress.hint_tokens
	game.request_hint()
	_check(game.hint_block == -1 and game.progress.hint_tokens == tokens, "no hint (and no charge) on a lost board")
	# Play on until nothing is free.
	while not game.model.free_block_ids().is_empty():
		await _tap(game.model.free_block_ids()[0])
		await _wait(0.05)
	_check(not game.model.is_empty(), "trap leads to a stuck board")
	await _wait(0.2)
	_shot("L10_stuck")
	while game.history.can_undo():
		game.undo()
	await _wait(0.3)
	_check(game.model.block_count() == game.level.blocks.size(), "undo recovers from the trap")
	_check(Solver.from_model(game.model).is_solvable(), "board solvable again after undo")
	print("Trap / stuck / undo recovery OK")


func _test_persistence(total: int) -> void:
	var reloaded := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(reloaded.hint_tokens == game.progress.hint_tokens, "hint tokens persisted (%d vs %d)" % [reloaded.hint_tokens, game.progress.hint_tokens])
	_check(reloaded.current_level == total, "current level persisted")
	_check(reloaded.highest_completed == total, "highest completed persisted")
	print("Persistence OK (tokens=%d, level=%d, completed=%d)" % [reloaded.hint_tokens, reloaded.current_level, reloaded.highest_completed])


func _directions() -> Dictionary:
	var d := {}
	for id in game.model.blocks:
		d[id] = game.model.blocks[id].direction
	return d


func _first_blocked() -> int:
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		if not game.model.can_escape(id):
			return id
	return -1


func _tap(id: int) -> void:
	var view := game.board.get_view(id)
	if view == null:
		_check(false, "no view for block %d" % id)
		return
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = game.board.get_global_transform_with_canvas() * view.home
	ev.pressed = true
	get_tree().root.push_input(ev, true)
	var up := ev.duplicate()
	up.pressed = false
	get_tree().root.push_input(up, true)
	await _frames(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _shot(name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [shots_dir, name])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
