extends Node
## Automated play-through of every level through the real game scene.
##
## Taps are injected as InputEventScreenTouch at block screen positions, so
## this exercises the actual input -> rules -> animation -> UI path.
## For each level it also checks a blocked tap (no removal, chain reset) and
## an Undo, then clears the board and waits for the LEVEL COMPLETE card.
##
##   godot --headless --path . res://tools/Playtest.tscn
##   godot --path . res://tools/Playtest.tscn -- --shots=/tmp/shots
##     (with a display, also saves screenshots)

var game: GameManager
var shots_dir := ""
var failures: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	var total: int = game.level_manager.level_count
	print("Levels found: %d" % total)
	for n in range(1, total + 1):
		await _play_level(n)
	if failures.is_empty():
		print("PLAYTEST PASSED: all %d levels cleared" % total)
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


func _play_level(n: int) -> void:
	game.start_level(n)
	await _wait(0.5)
	_shot("L%02d_start" % n)
	var start_count := game.model.block_count()
	var taps := 0
	var blocked_tested := false
	var undo_tested := false
	var order: Array = []
	while not game.model.is_empty():
		# 1) Once per level, tap a blocked block: must stay, chain must reset.
		if not blocked_tested:
			var blocked := _first_blocked()
			if blocked != -1:
				blocked_tested = true
				var before := game.model.block_count()
				await _tap(blocked)
				await _wait(0.05)
				_shot("L%02d_bump" % n)
				_check(game.model.block_count() == before, "L%d blocked tap removed a block" % n)
				_check(game.chain == 0, "L%d chain not reset after blocked tap" % n)
				await _wait(0.2)
		# 2) Tap a free block.
		var free: Array = game.model.free_block_ids()
		_check(not free.is_empty(), "L%d deadlock with %d blocks left" % [n, game.model.block_count()])
		if free.is_empty():
			return
		free.sort()
		var id: int = free[0]
		var before_count := game.model.block_count()
		await _tap(id)
		_check(game.model.block_count() == before_count - 1, "L%d tap on free block %d did not remove it" % [n, id])
		order.append(id)
		taps += 1
		if taps == 3:
			_shot("L%02d_chain" % n)
		# 3) Once per level (after 2 escapes), Undo and verify restoration.
		if taps == 2 and not undo_tested and not game.model.is_empty():
			undo_tested = true
			var chain_before_last: int = game.chain - 1
			game.undo()
			await _wait(0.05)
			_check(game.model.blocks.has(id), "L%d undo did not restore block %d" % [n, id])
			_check(game.chain == chain_before_last, "L%d undo did not restore chain" % n)
			_check(game.board.get_view(id) != null, "L%d undo did not recreate the view" % n)
			await _wait(0.3)
			taps -= 1
			order.pop_back()
		await _wait(0.09)
	await _wait(0.9)
	_shot("L%02d_complete" % n)
	_check(game.ui.is_complete_visible(), "L%d complete card not shown" % n)
	print("Level %2d  %-22s blocks=%2d  best_chain=%2d  order=%s" % [n, game.level.name, start_count, game.best_chain, str(order)])


func _first_blocked() -> int:
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		if not game.model.can_escape(id):
			return id
	return -1


func _tap(id: int) -> void:
	var view := game.board.get_view(id)
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
