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
	test_spin_rules()
	test_typed_spinners_in_solver()
	test_save_migration()
	test_economy_rewards()
	test_chests_no_duplicates()
	test_shop()
	test_hammer_safety()
	test_worlds()
	test_generator_future_levels()
	print("%d checks, %d failures" % [_checks, _fails])
	print("UNIT TESTS PASSED" if _fails == 0 else "UNIT TESTS FAILED")
	quit(0 if _fails == 0 else 1)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		printerr("FAIL: " + msg)


## Deletes a save and its backup/temp files (the loader falls back to .bak).
func wipe_save(path: String) -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


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
	check(lm.level_count >= 100, "at least 100 levels (found %d)" % lm.level_count)
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
	wipe_save(path)
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
	wipe_save(path)


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


# --- v0.4 -------------------------------------------------------------------

func test_spin_rules() -> void:
	var expect := {
		BlockData.SpinRule.CW: [true, true, true, true, true, true],
		BlockData.SpinRule.CCW: [false, false, false, false, false, false],
		BlockData.SpinRule.ALT: [true, false, true, false, true, false],
		BlockData.SpinRule.PATTERN: [true, true, false, true, true, false],
	}
	for rule in expect:
		var seq := []
		for step in 6:
			seq.append(BlockData.turn_is_cw(rule, step))
		check(seq == expect[rule], "spin rule %d follows its fixed sequence" % rule)
		# Same inputs, same outputs, every time (never random).
		for step in 6:
			check(BlockData.turn_is_cw(rule, step) == BlockData.turn_is_cw(rule, step), "rule %d deterministic" % rule)
		var b := BlockData.new(0, Vector2i.ZERO, "red", Direction.UP, BlockData.Kind.SPINNER)
		b.spin_rule = rule
		var dirs := [b.direction]
		for i in 6:
			b.apply_turn()
			dirs.append(b.direction)
		for i in 6:
			b.undo_turn()
			check(b.direction == dirs[5 - i] and b.spin_step == 5 - i, "rule %d undo_turn is the exact inverse" % rule)
	var level := level_from_map(["R^@- B>@~ G<@*", ".   .    ."])
	check(level.blocks[0].spin_rule == BlockData.SpinRule.CCW and level.blocks[1].spin_rule == BlockData.SpinRule.ALT
		and level.blocks[2].spin_rule == BlockData.SpinRule.PATTERN, "spinner rule tokens parsed")
	var json = JSON.parse_string(LevelManager.to_json_text(level))
	var again := LevelManager.parse_level(json, 0)
	check(again.blocks.map(func(b): return b.spin_rule) == level.blocks.map(func(b): return b.spin_rule), "spin rules survive JSON round-trip")


## Model and solver must agree step by step on typed spinners, and the
## model must match its own snapshot after Undo.
func test_typed_spinners_in_solver() -> void:
	var lm := LevelManager.new()
	lm._ready()
	var checked := 0
	for n in range(1, lm.level_count + 1):
		var level := lm.load_level(n)
		if not level.blocks.any(func(b): return b.is_spinner() and b.spin_rule != BlockData.SpinRule.CW):
			continue
		var m := model_of(level)
		var sol := Solver.from_model(m).solve()
		check(not sol.is_empty(), "L%d with typed spinners solvable" % n)
		for id in sol:
			var snap := m.snapshot()
			check(m.can_escape(id), "L%d solver move %d legal in the model" % [n, id])
			m.remove(id)
			var back := BoardModel.new()
			back.setup(m.rows, m.columns, snap)
			var s2 := Solver.from_model(back)
			s2._apply(id)
			var agree := true
			for b in m.snapshot():
				agree = agree and s2._dir[b.id] == b.direction and s2._step[b.id] == b.spin_step
			check(agree, "L%d model and solver agree after move %d" % [n, id])
		check(m.is_empty(), "L%d cleared by replaying the solution" % n)
		checked += 1
	check(checked >= 10, "typed-spinner levels checked (%d)" % checked)
	lm.free()


func test_save_migration() -> void:
	var path := "user://test_migrate.cfg"
	wipe_save(path)
	# A v0.3 save: no [meta] version, no economy, plus an unknown key.
	var old := ConfigFile.new()
	old.set_value("progress", "current_level", 23)
	old.set_value("progress", "highest_completed", 22)
	old.set_value("scores", "5", 4000)
	old.set_value("stars", "5", 3)
	old.set_value("stars", "6", 2)
	old.set_value("settings", "music", false)
	old.set_value("future", "something", 42)
	old.save(path)
	var p := PlayerProgress.new(path).load_from_disk()
	check(p.version == PlayerProgress.SAVE_VERSION, "old save migrated to current version")
	check(p.current_level == 23 and p.highest_completed == 22 and p.best_score(5) == 4000 and p.stars_for(6) == 2, "v0.3 progress kept")
	check(not p.music_on, "settings kept through migration")
	check(p.coins == int(Economy.config()["starting_coins"]), "migration grants starting coins")
	check(p.perfect_levels.has(5), "3-star levels count as already PERFECT (no double reward)")
	check(p.has_progress() and p.highest_unlocked() == 23, "continue/unlock state after migration")
	p.coins = 777
	p.inventory["hammer"] = 3
	p.claimed_chests.append("g0_t0")
	p.save()
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.coins == 777 and q.inventory["hammer"] == 3 and q.claimed_chests.has("g0_t0"), "coins, inventory, chests persist")
	var raw := ConfigFile.new()
	raw.load(path)
	check(raw.get_value("future", "something", 0) == 42, "unknown keys from other versions are preserved")
	check(int(raw.get_value("meta", "version", 0)) == PlayerProgress.SAVE_VERSION, "save file carries its version")
	# Damaged main file: falls back to the backup.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[[[ not a config file")
	f.close()
	var r := PlayerProgress.new(path).load_from_disk()
	check(r.current_level == 23, "damaged save falls back to the .bak copy")
	wipe_save(path)


func test_economy_rewards() -> void:
	var first := Economy.level_reward(5, true, 0, 3, true)
	check(first["coins"] > 0, "first clear with 3 stars and PERFECT pays")
	var replay := Economy.level_reward(5, false, 3, 3, false)
	check(replay["coins"] == 0, "replaying without improving pays nothing (no farming)")
	var better := Economy.level_reward(5, false, 1, 3, false)
	check(better["coins"] == 2 * int(Economy.config()["rewards"]["per_new_star"]), "only newly earned stars pay")
	var low := Economy.level_reward(5, true, 0, 1, false)
	check(first["coins"] > low["coins"], "better performance earns more")
	var hard := Economy.level_reward(95, true, 0, 3, true)
	check(hard["coins"] > first["coins"], "harder worlds pay more for the same performance")


func test_chests_no_duplicates() -> void:
	var path := "user://test_chest.cfg"
	wipe_save(path)
	var p := PlayerProgress.new(path).load_from_disk()
	var start := p.coins
	for n in range(1, 11):
		p.best_stars[n] = 2
	var tiers := Economy.chest_tiers(p, 0)
	check(tiers[0]["claimable"] and not tiers[1]["claimable"], "20 stars opens the first chest only")
	var got := Economy.claim_chest(p, 0, 0)
	check(got == tiers[0]["coins"] and p.coins == start + got, "chest pays once")
	check(Economy.claim_chest(p, 0, 0) == 0 and p.coins == start + got, "a claimed chest can never pay again")
	check(Economy.claim_chest(p, 0, 1) == 0, "a chest above the star count cannot be claimed")
	var q := PlayerProgress.new(path).load_from_disk()
	check(Economy.claim_chest(q, 0, 0) == 0, "claimed chests persist across restarts")
	wipe_save(path)


func test_shop() -> void:
	var path := "user://test_shop.cfg"
	wipe_save(path)
	var p := PlayerProgress.new(path).load_from_disk()
	p.coins = Economy.price("hint") + Economy.price("hammer") - 1
	check(Economy.buy(p, "hint"), "can buy a hint")
	check(not Economy.buy(p, "hammer"), "cannot buy what you cannot afford")
	check(p.coins == Economy.price("hammer") - 1 and p.inventory["hammer"] == 0, "failed purchase changes nothing")
	check(Economy.price("hammer") > Economy.price("hint"), "hammer costs more than hint")
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.inventory["hint"] == p.inventory["hint"], "inventory persists")
	wipe_save(path)


## Hammer safety, exhaustively on real board states: the rule the game uses
## must accept exactly the smashes that keep the level solvable.
func test_hammer_safety() -> void:
	var lm := LevelManager.new()
	lm._ready()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var accepted := 0
	var rejected := 0
	for n in [11, 31, 45, 61, 75, 88, 97]:
		if n > lm.level_count:
			continue
		var m := model_of(lm.load_level(n))
		for step in 6:
			for id in m.blocks.keys():
				var t := BoardModel.new()
				t.setup(m.rows, m.columns, m.snapshot())
				t.remove(id)
				var ok := t.is_empty() or Solver.from_model(t).is_solvable()
				if ok:
					accepted += 1
				else:
					rejected += 1
				# Whatever the rule accepts must replay to an empty board.
				if ok and not t.is_empty():
					var sol := Solver.from_model(t).solve()
					for x in sol:
						t.remove(x)
					check(t.is_empty(), "L%d accepted smash of %d really stays solvable" % [n, id])
			var free := m.free_block_ids()
			if free.is_empty():
				break
			m.remove(free[rng.randi() % free.size()])
	check(accepted > 50, "many safe smashes found (%d)" % accepted)
	check(rejected > 0, "unsafe smashes exist and are detected (%d)" % rejected)
	lm.free()


func test_worlds() -> void:
	check(Worlds.world_of(1) == 1 and Worlds.world_of(20) == 1 and Worlds.world_of(21) == 2, "world boundaries")
	check(Worlds.world_of(81) == 5 and Worlds.world_of(99) == 5, "world 5 range")
	check(Worlds.theme_for_level(100)["id"] == Worlds.MASTER_THEME["id"], "level 100 has the Master theme")
	var musics := {}
	for n in range(1, 101):
		musics[Worlds.theme_for_level(n)["music"]] = true
	check(musics.size() == 6, "six music themes (5 worlds + master)")
	for t in Worlds.THEMES + [Worlds.MASTER_THEME]:
		check(ResourceLoader.exists("res://assets/audio/music_%s.wav" % t["music"]), "music file for %s exists" % t["music"])


func test_generator_future_levels() -> void:
	check(LevelGenerator.profile_for_level(121)["name"] == "w5_master", "101+ maps to the hardest profile")
	check(LevelGenerator.profile_for_level(110)["name"] == "w_mystery_late", "every 10th future level is a mystery")
	var band := LevelGenerator.target_difficulty(150)
	check(band.x > LevelGenerator.target_difficulty(100).x, "target difficulty keeps rising past 100")
