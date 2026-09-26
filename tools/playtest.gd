extends Node
## Automated play-through of every level through the real game scene.
##
## Taps are injected as InputEventScreenTouch at block screen positions, so
## this exercises the actual input -> rules -> animation -> UI path.
##
## Per level: a blocked tap (no removal, chain reset, heart lost from level
## 6), a Hint where the level allows one (legal, keeps the board solvable,
## not auto-played, counted), an Undo (block/spinner/lock/mystery state
## restored), then the level is cleared by following the solver; LEVEL
## COMPLETE must show with a score, stars and a saved best.
## Scenarios: PERFECT, personal best + stars persistence, Replay, Level
## Select, Undo limit, Hint limits, locked tap + unlock, hidden tap +
## reveal, out of hearts, Restart, spinner trap -> stuck -> recovery.
##
##   godot --headless --path . res://tools/Playtest.tscn
##   godot --path . res://tools/Playtest.tscn -- --shots=/tmp/shots

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
	_check(total >= 60, "expected at least 60 levels")
	await _test_perfect_and_bests()
	await _test_replay_and_level_select()
	await _test_undo_limit()
	await _test_hint_limits()
	await _test_locked_block()
	await _test_mystery_reveal()
	await _test_out_of_hearts()
	await _test_restart()
	await _test_trap_and_stuck()
	for n in range(1, total + 1):
		await _play_level(n)
	_test_persistence(total)
	if failures.is_empty():
		print("PLAYTEST PASSED: all %d levels cleared; score/stars/PERFECT/bests/undo+hint limits/locks/mystery/replay/level select OK" % total)
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
	var blocked := _first_in_state("blocked")
	if blocked != -1:
		var before := game.model.block_count()
		await _tap(blocked)
		await _wait(0.05)
		_check(game.model.block_count() == before, "L%d blocked tap removed a block" % n)
		_check(game.chain == 0 and game.mistakes == 1, "L%d blocked tap = mistake, chain reset" % n)
		_check(game.hearts == maxi(expected_hearts - 1, 0), "L%d blocked tap heart count" % n)
		await _wait(0.2)

	# 2) Hint where allowed: legal, solvable after, not auto-played, counted.
	if game.hints_allowed() > 0:
		var count_before := game.model.block_count()
		game.request_hint()
		await _frames(2)
		var hinted := game.hint_block
		_check(hinted != -1 and game.hints_used == 1, "L%d hint shown and counted" % n)
		_check(game.model.block_count() == count_before, "L%d hint must not play the move" % n)
		if hinted != -1:
			_check(game.model.can_escape(hinted), "L%d hint %d is a legal move" % [n, hinted])
			var after := BoardModel.new()
			after.setup(game.model.rows, game.model.columns, game.model.snapshot())
			after.remove(hinted)
			_check(Solver.from_model(after).is_solvable(), "L%d hint keeps the board solvable" % n)
			_check(game.board.get_view(hinted).hinted, "L%d hinted block is highlighted" % n)
			_shot("L%02d_hint" % n)

	# 3) Clear the level following the solver; Undo once after 2 moves.
	var taps := 0
	var undo_tested := false
	while not game.model.is_empty():
		var id := Solver.from_model(game.model).recommend_move()
		_check(id != -1, "L%d solver found no move with %d blocks left" % [n, game.model.block_count()])
		if id == -1:
			return
		var snapshot := _state()
		var before_count := game.model.block_count()
		await _tap(id)
		_check(game.model.block_count() == before_count - 1, "L%d tap on block %d did not remove it" % [n, id])
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
			_check(_state() == snapshot, "L%d undo did not restore directions/hidden/locks" % n)
			_check(game.undos_used == 1, "L%d undo counted" % n)
			await _wait(0.3)
			taps -= 1
		await _wait(0.07)
	await _wait(1.0 if not game.last_result.get("perfect", false) else 1.6)
	_shot("L%02d_complete" % n)
	var r := game.last_result
	_check(game.ui.is_complete_visible(), "L%d complete card not shown" % n)
	_check(r.get("level", -1) == n and r["score"] > 0 and r["stars"] >= 1, "L%d settled with score and stars" % n)
	_check(not r["perfect"], "L%d is not PERFECT after mistake/undo" % n)
	_check(game.progress.best_score(n) >= r["score"] and game.progress.stars_for(n) >= r["stars"], "L%d best saved" % n)
	print("Level %2d  %-18s blocks=%2d spn=%d lck=%d hid=%d score=%5d stars=%d hints=%d" % [
		n, game.level.name, start_count, _count(func(b): return b.is_spinner()), _count(func(b): return b.lock_color != ""),
		_count(func(b): return b.hidden), r["score"], r["stars"], game.hints_used])


func _count(pred: Callable) -> int:
	return game.level.blocks.filter(pred).size()


## PERFECT on level 13: exact max score, 3 stars, PERFECT stamp; then a
## worse replay keeps the best.
func _test_perfect_and_bests() -> void:
	game.start_level(13)
	await _wait(0.4)
	await _solve_cleanly()
	await _wait(1.8)
	_shot("perfect_card")
	var r := game.last_result
	_check(r["perfect"] and r["stars"] == 3, "clean solve is PERFECT with 3 stars")
	_check(r["score"] == ScoreRules.max_score(game.level.blocks.size()), "PERFECT unbroken chain scores the maximum (%d vs %d)" % [r["score"], ScoreRules.max_score(game.level.blocks.size())])
	_check(r["first_clear"], "first clear flagged")
	var best := game.progress.best_score(13)
	# Worse run: one blocked tap.
	game.start_level(13)
	await _wait(0.4)
	await _tap(_first_in_state("blocked"))
	await _solve_cleanly()
	await _wait(1.2)
	r = game.last_result
	_check(not r["perfect"] and not r["new_best"] and r["score"] < best, "worse run is not NEW BEST")
	_check(game.progress.best_score(13) == best and game.progress.stars_for(13) == 3, "best score/stars kept after a worse run")
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(disk.best_score(13) == best and disk.stars_for(13) == 3, "best score/stars persisted to disk")
	print("PERFECT / score / personal best / stars OK (best=%d)" % best)


func _test_replay_and_level_select() -> void:
	game.ui.replay_pressed.emit()
	await _wait(0.3)
	_check(game.current_level == 13 and not game.completed and game.model.block_count() == game.level.blocks.size(), "Replay restarts the same level")
	game.ui.levels_opened.emit()
	await _frames(3)
	_check(game.ui.is_level_select_open(), "level select opens")
	_shot("level_select")
	var tiles := game.ui._level_select._grid.get_child_count()
	_check(tiles == game.level_manager.level_count, "level select shows every level (%d)" % tiles)
	game.ui.level_chosen.emit(5)
	game.ui._level_select.close()
	await _wait(0.3)
	_check(game.current_level == 5 and not game.ui.is_level_select_open(), "choosing a level starts it")
	print("Replay / Level Select OK")


func _test_undo_limit() -> void:
	game.start_level(12)
	await _wait(0.4)
	for i in GameManager.MAX_UNDOS + 1:
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.05)
		game.undo()
		await _wait(0.05)
	_check(game.undos_used == GameManager.MAX_UNDOS, "undo limited to %d (used %d)" % [GameManager.MAX_UNDOS, game.undos_used])
	_check(game.history.can_undo() and game.ui._undo_button.disabled, "undo button disabled at 0 uses")
	print("Undo limit OK")


func _test_hint_limits() -> void:
	for spec in [[12, 0], [25, 1], [35, 2]]:
		game.start_level(spec[0])
		await _wait(0.3)
		_check(game.hints_allowed() == spec[1], "L%d allows %d hints" % spec)
		for i in 3:
			game.request_hint()
			await _frames(1)
			if game.hint_block != -1:
				await _tap(game.hint_block)  # follow it so the next can show
				await _wait(0.05)
		_check(game.hints_used == spec[1], "L%d hint cap respected (used %d)" % [spec[0], game.hints_used])
	# Debug mode: unlimited and free.
	game.start_level(12)
	await _wait(0.3)
	game.debug_panel.visible = true
	game.request_hint()
	_check(game.hint_block != -1 and game.hints_used == 0, "debug mode: unlimited hints")
	game.debug_panel.visible = false
	print("Hint limits OK")


func _test_locked_block() -> void:
	game.start_level(16)
	await _wait(0.4)
	var locked := _first_in_state("locked")
	_check(locked != -1 and game.board.get_view(locked).locked_visual, "lock intro has a visibly locked block")
	await _tap(locked)
	await _wait(0.1)
	_shot("L16_locked_tap")
	_check(game.model.blocks.has(locked) and game.mistakes == 1, "tapping a locked block is a mistake and it stays")
	while game.model.is_locked(locked):
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.05)
	await _wait(0.6)
	_check(not game.board.get_view(locked).locked_visual, "unlock animation cleared the padlock")
	_check(game.model.can_escape(locked) or game.model.move_state(locked) == "blocked", "unlocked block is playable")
	_shot("L16_unlocked")
	print("Locked block OK")


func _test_mystery_reveal() -> void:
	game.start_level(10)
	await _wait(0.4)
	var hidden := _first_in_state("hidden")
	_check(hidden != -1 and game.level.mystery, "mystery intro has a hidden block")
	_shot("L10_mystery")
	var hearts := game.hearts
	await _tap(hidden)
	await _wait(0.1)
	_check(game.mistakes == 0 and game.hearts == hearts and game.model.blocks.has(hidden), "tapping a hidden block is free")
	while game.model.blocks[hidden].hidden:
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.05)
	await _wait(0.4)
	_check(not game.board.get_view(hidden).data.hidden, "hidden arrow revealed on screen")
	_shot("L10_revealed")
	print("Mystery reveal OK")


## Level 6: three blocked taps -> Try Again -> fresh attempt with 3 hearts.
func _test_out_of_hearts() -> void:
	game.start_level(6)
	await _wait(0.4)
	for i in 3:
		await _tap(_first_in_state("blocked"))
		await _wait(0.1)
	_check(game.hearts == 0 and game.game_over, "out of hearts after 3 blocked taps")
	await _wait(0.7)
	_shot("hearts_try_again")
	await _wait(1.4)
	_check(not game.game_over and game.hearts == 3, "level restarted with 3 hearts")
	print("Out-of-hearts flow OK")


func _test_restart() -> void:
	game.start_level(7)
	await _wait(0.4)
	await _tap(Solver.from_model(game.model).recommend_move())
	await _tap(_first_in_state("blocked"))
	game.restart()
	await _wait(0.1)
	_check(game.model.block_count() == game.level.blocks.size() and game.hearts == 3 and game.undos_used == 0 and not game.history.can_undo(),
		"restart resets blocks, hearts, undos and history")
	print("Restart OK")


## Level 11: the spinner trap -> stuck -> free hint refusal -> Undo recovers.
func _test_trap_and_stuck() -> void:
	game.start_level(11)
	await _wait(0.4)
	var trap := -1
	for id in game.model.free_block_ids():
		var m := BoardModel.new()
		m.setup(game.model.rows, game.model.columns, game.model.snapshot())
		m.remove(id)
		if not Solver.from_model(m).is_solvable():
			trap = id
	_check(trap != -1, "level 11 has a trap move")
	if trap == -1:
		return
	await _tap(trap)
	while not game.model.free_block_ids().is_empty():
		await _tap(game.model.free_block_ids()[0])
		await _wait(0.05)
	_check(not game.model.is_empty(), "trap leads to a stuck board")
	await _wait(0.2)
	_shot("L11_stuck")
	while game.history.can_undo() and game.undos_used < GameManager.MAX_UNDOS:
		game.undo()
	await _wait(0.3)
	_check(game.model.block_count() == game.level.blocks.size(), "undo recovers from the trap")
	print("Trap / stuck / undo recovery OK")


func _test_persistence(total: int) -> void:
	var reloaded := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(reloaded.highest_completed == total, "highest completed persisted")
	_check(reloaded.best_scores.size() == total and reloaded.best_stars.size() == total, "a best score and stars saved for every level")
	for n in range(1, total + 1):
		_check(reloaded.best_score(n) == game.progress.best_score(n), "L%d best persisted" % n)
	print("Persistence OK (%d best scores, %d stars total)" % [reloaded.best_scores.size(), reloaded.total_stars()])


func _solve_cleanly() -> void:
	while not game.model.is_empty():
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.03)


func _state() -> Dictionary:
	var d := {}
	for id in game.model.blocks:
		var b: BlockData = game.model.blocks[id]
		d[id] = [b.direction, b.hidden, game.model.is_locked(id)]
	return d


func _first_in_state(state: String) -> int:
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		if game.model.move_state(id) == state:
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
