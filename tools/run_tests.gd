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
	test_locks()
	test_mystery_reveal()
	test_mystery_fairness()
	test_score_rules()
	test_stars_data_driven()
	test_progress_persistence()
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
	check(lm.level_count >= 60, "at least 60 levels (found %d)" % lm.level_count)
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
	check(p.highest_completed == 0 and p.is_unlocked(1) and not p.is_unlocked(2), "fresh progress: only level 1 open")
	p.current_level = 17
	p.music_on = false
	p.haptics_on = false
	var r1 := p.record_result(3, 4200, 2)
	check(r1["first_clear"] and not r1["new_best"], "first clear is flagged as first, not NEW BEST")
	var r2 := p.record_result(3, 5100, 3)
	check(r2["new_best"] and r2["previous_best"] == 4200, "beating a score is NEW BEST")
	var r3 := p.record_result(3, 1000, 1)
	check(not r3["new_best"], "a worse score is not NEW BEST")
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.current_level == 17 and q.highest_completed == 3, "level progress persists")
	check(q.best_score(3) == 5100 and q.stars_for(3) == 3, "best score and best stars persist (never go down)")
	check(q.is_unlocked(4) and not q.is_unlocked(5), "next level unlocks after a clear")
	check(not q.music_on and q.sfx_on and not q.haptics_on, "settings persist")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_locks() -> void:
	# B is locked by green; the two greens are free; R waits on B.
	var level := level_from_map(["Rv   .   .", "B>#G .   .", "Gv   .   G^"])
	check(level.blocks[1].lock_color == "green", "lock token parsed")
	var m := model_of(level)
	check(m.is_locked(1) and m.move_state(1) == "locked", "locked while greens remain")
	check(m.key_blocks(1).size() == 2, "key blocks are the two greens")
	var snap := m.snapshot()
	m.remove(2)
	check(m.is_locked(1) and m.last_unlocked.is_empty(), "still locked after first green")
	m.remove(3)
	check(not m.is_locked(1) and m.last_unlocked == [1], "unlocks when the last green leaves")
	check(m.can_escape(1), "unlocked block with a clear lane can escape")
	m.restore(snap)
	check(m.is_locked(1), "undo snapshot re-locks")
	var s := Solver.from_model(model_of(level))
	check(not s.legal_moves().has(1), "solver: locked block is not a legal move")
	check(s.solve() == [2, 3, 1, 0] or s.solve().size() == 4, "solver clears the lock level")
	var bad := level_from_map(["B>#G G<"])
	check(not Solver.from_model(model_of(bad)).is_solvable(), "lock facing its only key is unsolvable")


func test_mystery_reveal() -> void:
	var level := level_from_map([".  Bv  .  P<", "R> Y>? .  .", ".  Gv  .  ."])
	check(level.mystery and level.blocks[3].hidden, "hidden token parsed, level marked mystery")
	var m := model_of(level)
	check(m.move_state(3) == "hidden", "hidden block cannot escape (even with a clear lane)")
	var snap := m.snapshot()
	m.remove(4)  # G, a neighbour
	check(m.last_revealed == [3] and not m.blocks[3].hidden, "neighbour escape reveals the arrow")
	check(m.can_escape(3), "revealed block with a clear lane can escape")
	m.restore(snap)
	check(m.blocks[3].hidden, "undo hides the arrow again")
	var s := Solver.from_model(model_of(level))
	check(not s.legal_moves().has(3), "solver: hidden block is not a legal move")
	check(s.is_solvable(), "mystery intro solvable")


func test_mystery_fairness() -> void:
	# Fair: no spinner decisions depend on the hidden arrow.
	var fair := level_from_map([".  Bv  .  P<", "R> Y>? .  .", ".  Gv  .  ."])
	check(Solver.from_model(model_of(fair)).mystery_fairness()["fair"], "mystery intro is fair")
	# Unfair: whether taking Y first is a trap depends on the hidden G arrow
	# (G pointing left = trap, G pointing up = fine). Must be rejected.
	var unfair := level_from_map([".  .   .   .", ".  B^@ G<? R>", ".  Yv  .   ."])
	var res := Solver.from_model(model_of(unfair)).mystery_fairness()
	check(not res["fair"], "hidden arrow that decides a trap is flagged unfair")


func test_score_rules() -> void:
	var base := {"escape_points": 0, "blocks": 5, "hearts_left": 3, "max_hearts": 3, "mistakes": 0, "undos": 0, "hints": 0}
	for i in range(1, 6):
		base["escape_points"] += ScoreRules.escape_points(i)
	var perfect := ScoreRules.settle(base)
	check(perfect["perfect"], "no mistakes/undo/hints is PERFECT")
	check(perfect["score"] == ScoreRules.max_score(5), "perfect unbroken chain = max score")
	check(perfect["bonus_perfect"] == ScoreRules.PERFECT, "PERFECT bonus applied")
	var with_undo := base.duplicate()
	with_undo["undos"] = 1
	var u := ScoreRules.settle(with_undo)
	check(not u["perfect"] and u["score"] == perfect["score"] - ScoreRules.PERFECT - ScoreRules.NO_UNDO - ScoreRules.UNDO_PENALTY, "undo: no PERFECT, loses bonus, pays penalty")
	var with_hint := base.duplicate()
	with_hint["hints"] = 1
	check(not ScoreRules.settle(with_hint)["perfect"], "hint prevents PERFECT")
	var with_mistake := base.duplicate()
	with_mistake["mistakes"] = 1
	with_mistake["hearts_left"] = 2
	var mk := ScoreRules.settle(with_mistake)
	check(not mk["perfect"] and mk["score"] < u["score"], "a heart lost costs more than an undo")
	check(ScoreRules.escape_points(1) == 100 and ScoreRules.escape_points(50) == 100 + 20 * ScoreRules.CHAIN_CAP, "chain bonus grows and caps")
	var lvl := level_from_map(["R> G> B> Y> P>"])
	check(ScoreRules.stars(lvl, perfect) == 3, "PERFECT = 3 stars")
	check(ScoreRules.stars(lvl, u) == 3, "one undo, otherwise clean, still reaches the 3-star score")
	check(ScoreRules.stars(lvl, ScoreRules.settle(with_hint)) == 1, "hint used = star 2 missed (stars are cumulative)")
	check(ScoreRules.stars(lvl, mk) == 2, "a blocked tap = 2 stars")


func test_stars_data_driven() -> void:
	var lvl := LevelManager.parse_level({"map": ["R> G>"], "stars": {"two": "no_mistakes", "three": "no_undo"}}, 0)
	var r := ScoreRules.settle({"escape_points": 220, "blocks": 2, "hearts_left": 0, "max_hearts": 0, "mistakes": 0, "undos": 0, "hints": 1})
	check(ScoreRules.stars(lvl, r) == 3, "custom star rules from level data are used")
	check(ScoreRules.rules_for(lvl)["score"] == ScoreRules.max_score(2) - ScoreRules.AUTO_TARGET_MARGIN, "auto 3-star target")


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
