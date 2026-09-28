extends Node
## Long-session stability test (v0.5.1): plays the campaign CONTINUOUSLY in
## one process, the way a player does - real touch input, the real NEXT
## button, Chapter Complete cards, Silver/Gold rewards, music and SFX on,
## a save after every step - and watches for leaks.
##
##   godot --headless --path . res://tools/Soak.tscn [-- --from=1 --to=100 --cycles=2]
##
## Every level transition logs one [Diag] line (memory, objects, nodes,
## orphan nodes, resources, tweens, effect nodes, playing audio players).
## FAILS if: a level can't be cleared, the game leaves the level flow
## (title shown, level mismatch), orphan nodes appear, effect/block nodes or
## tweens pile up, audio players keep playing, objects/nodes/resources/memory
## grow from cycle to cycle, or the save on disk falls behind the game.

const PROGRESS_PATH := "user://soak_progress.cfg"

var game: GameManager
var failures: Array[String] = []
var from := 1
var to := 100
var cycles := 1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = int(a.get_slice("=", 1))
		elif a.begins_with("--to="):
			to = int(a.get_slice("=", 1))
		elif a.begins_with("--cycles="):
			cycles = int(a.get_slice("=", 1))
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	GameManager.skip_title = true
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	# Real settings: music and SFX on (dummy audio driver when headless).
	AudioManager.unlocked = true
	AudioManager.set_music_enabled(true)
	AudioManager.set_sfx_enabled(true)
	# Unlock everything up to `from` so the run can start anywhere.
	for n in range(1, from):
		game.progress.record_result(n, 1000, 1)
	game.start_level(from, "soak")
	await _wait(0.5)
	var cycle_marks: Array = []
	var levels_played := 0
	for cycle in cycles:
		var n := from
		while true:
			if game.current_level != n:
				_fail("expected level %d, game is on %d" % [n, game.current_level])
				break
			if game.ui.is_title_open():
				_fail("title screen appeared during play at level %d" % n)
				break
			await _clear_level(n)
			levels_played += 1
			_check_level_end(n)
			if n == to:
				break
			# NEXT, and the Chapter Complete card when it appears.
			game.ui.next_pressed.emit()
			await _wait(0.35)
			if game.ui.is_chapter_card_open():
				await _wait(0.3)
				game.ui._chapter_card._continue.pressed.emit()
				await _wait(0.2)
			n += 1
			if not failures.is_empty() and failures.size() > 20:
				break
		# End of a cycle: settle, then measure.
		await _wait(2.5)
		cycle_marks.append(Diagnostics.snapshot(get_tree()))
		print("[Soak] cycle %d done at level %d: %s" % [cycle + 1, game.current_level, str(cycle_marks[-1])])
		if cycle < cycles - 1:
			game.start_level(from, "soak")
			await _wait(0.5)
	_check_growth(cycle_marks)
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	if disk.highest_completed < to or disk.highest_unlocked < mini(to + 1, game.level_manager.level_count):
		_fail("save on disk fell behind: highest_completed %d, highest_unlocked %d" % [disk.highest_completed, disk.highest_unlocked])
	if disk.total_score() != game.progress.total_score():
		_fail("total score on disk %d != game %d" % [disk.total_score(), game.progress.total_score()])
	print("[Soak] %d levels played in %ds, total score %d, coins %d" % [levels_played, Diagnostics.snapshot()["t"], game.progress.total_score(), game.progress.coins])
	if failures.is_empty():
		print("SOAK PASSED: %d levels (%d-%d x%d) continuous, no crash, no leak, saves in step" % [levels_played, from, to, cycles])
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		print("SOAK FAILED (%d problems)" % failures.size())
		get_tree().quit(1)


func _clear_level(n: int) -> void:
	await _wait(0.25)
	var guard := 0
	while not game.model.is_empty() and guard < 200:
		guard += 1
		var id := Solver.from_model(game.model).recommend_move()
		if id == -1:
			_fail("L%d: no move with %d blocks left" % [n, game.model.block_count()])
			return
		await _tap(id)
		await _frames(2)
	var total_before := game.progress.total_score()
	# Card appears after the celebration (Master Level: longest).
	var t := 0.0
	while not game.ui.is_complete_visible() and t < 4.0:
		await _wait(0.1)
		t += 0.1
	if not game.ui.is_complete_visible():
		_fail("L%d: level card never appeared" % n)
	if game.progress.total_score() < total_before:
		_fail("L%d: total score went down" % n)


## After each level: nothing piles up and the save is in step.
func _check_level_end(n: int) -> void:
	var d := game.last_diag
	if d.get("orphans", 0) > 0:
		_fail("L%d: %d orphan nodes at level start" % [n, d["orphans"]])
	if d.get("fx", 0) > 80:
		_fail("L%d: %d effect/block nodes alive at level start" % [n, d["fx"]])
	if d.get("tweens", 0) > 40:
		_fail("L%d: %d tweens alive at level start" % [n, d["tweens"]])
	if d.get("music_players", 0) > 2:
		_fail("L%d: %d music players playing at level start" % [n, d["music_players"]])
	if game.progress.highest_completed < n:
		_fail("L%d: completion not recorded" % n)


## Cycle-over-cycle growth must stay flat (a real leak grows every cycle).
func _check_growth(marks: Array) -> void:
	if marks.size() < 2:
		return
	var a: Dictionary = marks[0]
	var b: Dictionary = marks[-1]
	var limits := {"objects": 300, "nodes": 30, "resources": 60, "mem_mb": 8.0}
	for k in limits:
		var grew: float = b[k] - a[k]
		print("[Soak] growth over %d cycles: %s %+.1f" % [marks.size() - 1, k, grew])
		if grew > limits[k]:
			_fail("%s grew by %.1f between cycle 1 and %d" % [k, grew, marks.size()])


func _tap(id: int) -> void:
	var view := game.board.get_view(id)
	if view == null:
		return
	var ev := InputEventScreenTouch.new()
	ev.position = game.board.get_global_transform_with_canvas() * view.home
	ev.pressed = true
	get_tree().root.push_input(ev, true)
	var up := ev.duplicate()
	up.pressed = false
	get_tree().root.push_input(up, true)
	await _frames(1)


func _fail(msg: String) -> void:
	failures.append(msg)
	printerr("FAIL: " + msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(k: int) -> void:
	for i in k:
		await get_tree().process_frame
