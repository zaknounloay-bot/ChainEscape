extends SceneTree
## Headless unit tests for rules, solver, hints, progress and generator.
##
##   godot --headless --path . --script res://tools/run_tests.gd
##
## (Gameplay/UI flow is covered by res://tools/Playtest.tscn.)

var _fails := 0
var _checks := 0


func _initialize() -> void:
	test_directions()
	test_spinner_parse_and_turn()
	test_undo_snapshot_restores_spinners()
	test_solver_trap_detection()
	test_all_levels_solvable()
	test_hints_never_invalid()
	test_progress_persistence()
	test_hint_economy()
	test_generator()
	print("%d checks, %d failures" % [_checks, _fails])
	print("UNIT TESTS PASSED" if _fails == 0 else "UNIT TESTS FAILED")
	quit(0 if _fails == 0 else 1)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		printerr("FAIL: " + msg)


func level_from_map(map: Array) -> LevelData:
	return LevelManager.parse_level({"map": map}, 0)


func model_of(level: LevelData) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	return m


# ---------------------------------------------------------------------------

func test_directions() -> void:
	var d := Direction.UP
	for i in 4:
		check(Direction.rotate_ccw(Direction.rotate_cw(d)) == d, "cw/ccw roundtrip")
		d = Direction.rotate_cw(d)
	check(d == Direction.UP, "4 clockwise turns return to start")
	check(Direction.rotate_cw(Direction.UP) == Direction.RIGHT, "up turns to right")
	check(Direction.rotate_cw(Direction.LEFT) == Direction.UP, "left turns to up")


func test_spinner_parse_and_turn() -> void:
	var level := level_from_map(["R^ B>@ ."])
	check(level.blocks.size() == 2, "two blocks parsed")
	check(level.blocks[1].is_spinner() and not level.blocks[0].is_spinner(), "spinner token parsed")
	var m := model_of(level)
	var turned := m.remove(0)
	check(turned == [1], "neighbour spinner reported as turned")
	check(m.blocks[1].direction == Direction.DOWN, "spinner turned right -> down")


func test_undo_snapshot_restores_spinners() -> void:
	var m := model_of(level_from_map(["R^ B>@", ".  ."]))
	var history := History.new()
	history.push(m.snapshot())
	m.remove(0)
	check(m.blocks[1].direction == Direction.DOWN, "spinner turned")
	m.restore(history.pop())
	check(m.blocks.size() == 2 and m.blocks[1].direction == Direction.RIGHT, "undo restores block and spinner direction")


func test_solver_trap_detection() -> void:
	# Spinner B (points up, free). G points into B. Y is free below B.
	#   Right: B first, then G and Y.
	#   Trap:  Y first turns B to face G while G faces B -> stuck.
	var level := level_from_map([
		".  .   .",
		".  B^@ G<",
		".  Yv  ."])
	var m := model_of(level)
	var s := Solver.from_model(m)
	var a := s.analyze()
	check(a["solvable"], "trap level is solvable")
	check(a["start_moves"] == 2 and a["start_traps"] == 1, "one of the two legal starts is a trap")
	check(Solver.from_model(m).recommend_move() == 0, "hint recommends the spinner, not the trap")
	var trapped := model_of(level)
	trapped.remove(2)  # Y first
	check(trapped.blocks[0].direction == Direction.RIGHT, "spinner turned to face G")
	check(not Solver.from_model(trapped).is_solvable(), "after the trap move the board is unsolvable")
	check(Solver.from_model(trapped).recommend_move() == -1, "no hint on a lost board")
	var sol: Array = a["solution"]
	check(sol.size() == 3, "solution clears all 3 blocks")
	# Replaying the solution through the real model must clear the board.
	var replay := model_of(level)
	var legal := true
	for id in sol:
		legal = legal and replay.can_escape(id)
		replay.remove(id)
	check(legal and replay.is_empty(), "solver solution is legal in BoardModel")


func test_all_levels_solvable() -> void:
	var lm := LevelManager.new()
	lm._ready()
	check(lm.level_count >= 30, "at least 30 levels (found %d)" % lm.level_count)
	for n in range(1, lm.level_count + 1):
		var level := lm.load_level(n)
		var s := Solver.from_model(model_of(level))
		check(s.is_solvable(), "level %d solvable" % n)
		check(not s.aborted, "level %d solver did not give up" % n)
	lm.free()


## Plays each level with random (sometimes bad) legal moves and checks that
## every hint is a legal move that keeps the board solvable.
func test_hints_never_invalid() -> void:
	var lm := LevelManager.new()
	lm._ready()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var hint_checks := 0
	for n in range(1, lm.level_count + 1):
		var level := lm.load_level(n)
		for run in 3:
			var m := model_of(level)
			while not m.is_empty():
				var s := Solver.from_model(m)
				var solvable := s.is_solvable()
				var hint := Solver.from_model(m).recommend_move()
				if solvable:
					hint_checks += 1
					check(hint != -1, "L%d: hint exists on a solvable board" % n)
					if hint != -1:
						check(m.can_escape(hint), "L%d: hint %d is a legal move" % [n, hint])
						var after := BoardModel.new()
						after.setup(m.rows, m.columns, m.snapshot())
						after.remove(hint)
						check(Solver.from_model(after).is_solvable(), "L%d: hint keeps board solvable" % n)
				else:
					check(hint == -1, "L%d: no hint offered on an unsolvable board" % n)
				var free := m.free_block_ids()
				if free.is_empty():
					break  # stuck (only reachable after a bad move)
				m.remove(free[rng.randi() % free.size()])
	check(hint_checks > 100, "hint checked on many states (%d)" % hint_checks)
	lm.free()


func test_progress_persistence() -> void:
	var path := "user://test_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p := PlayerProgress.new(path).load_from_disk()
	check(p.hint_tokens == PlayerProgress.STARTING_HINTS, "fresh progress starts with starting hints")
	p.current_level = 17
	p.hint_tokens = 4
	p.music_on = false
	p.haptics_on = false
	p.save()
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.current_level == 17 and q.hint_tokens == 4, "level and hint tokens persist")
	check(not q.music_on and q.sfx_on and not q.haptics_on, "settings persist")
	var got := q.complete_level(15)
	check(got == 1 and q.hint_tokens == 5, "completing level 15 awards a hint")
	check(q.complete_level(15) == 0, "replaying a level does not award again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_hint_economy() -> void:
	var total := [0, 0, 0]
	for n in range(1, 31):
		total[(n - 1) / 10] += PlayerProgress.hints_awarded_for(n)
	# Levels 1-10 are covered by the starting token.
	check(PlayerProgress.STARTING_HINTS + total[0] == 1, "about 1 hint per 10 levels in 1-10")
	check(total[1] == 2, "about 1 hint per 5 levels in 11-20")
	check(total[2] >= 3 and total[2] <= 4, "about 1 hint per 3 levels in 21-30")


func test_generator() -> void:
	var gen := LevelGenerator.new(42)
	var profile := LevelGenerator.profile("medium")
	var level := gen.generate(profile)
	check(level != null, "generator produced a medium level")
	if level:
		var m := Solver.from_model(model_of(level)).analyze()
		check(m["solvable"], "generated level is solvable")
		check(m["start_moves"] <= profile["max_start_moves"], "generated level respects start-move limit")
		check(m["direction_share"] <= profile["max_direction_share"], "generated level has direction diversity")
		# Round-trip through the JSON map format.
		var json = JSON.parse_string(LevelManager.to_json_text(level))
		var again := LevelManager.parse_level(json, 0)
		check(again.blocks.size() == level.blocks.size(), "generated level survives JSON round-trip")
