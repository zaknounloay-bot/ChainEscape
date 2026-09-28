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
	test_chapters()
	test_chapter_theme_contrast()
	test_generator_future_levels()
	test_reward_tokens()
	test_reward_blocks_pay_once()
	test_chapter_complete_once()
	test_chest_items()
	test_save_migration_v2()
	test_total_score_model()
	test_unlocks_never_regress()
	test_newest_copy_wins()
	test_corrupt_save_recovery()
	test_save_migration_v3()
	test_missing_save_holds_writes()
	test_backup_code_and_merge()
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
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
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
	check(p.has_progress() and p.highest_unlocked == 23, "continue/unlock state after migration")
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
	check(hard["coins"] > first["coins"], "later Chapters pay more for the same performance")
	var prev := 0.0
	var rising := true
	for c in range(1, 15):
		rising = rising and Economy.chapter_multiplier(c) > prev
		prev = Economy.chapter_multiplier(c)
	check(rising and Economy.chapter_multiplier(40) <= float(Economy.config()["chapter_multiplier_max"]), "Chapter multiplier rises (capped) past Chapter 10")


func test_chests_no_duplicates() -> void:
	var path := "user://test_chest.cfg"
	wipe_save(path)
	var p := PlayerProgress.new(path).load_from_disk()
	var start := p.coins
	for n in range(1, 11):
		p.best_stars[n] = 2
	var tiers := Economy.chest_tiers(p, 1)
	check(tiers[0]["claimable"] and not tiers[1]["claimable"], "20 stars opens the first chest only")
	var got := Economy.claim_chest(p, 1, 0)
	check(got == tiers[0]["coins"] and p.coins == start + got, "chest pays once")
	check(Economy.claim_chest(p, 1, 0) == 0 and p.coins == start + got, "a claimed chest can never pay again")
	check(Economy.claim_chest(p, 1, 1) == 0, "a chest above the star count cannot be claimed")
	check(Economy.chest_id(1, 0) == "g0_t0", "chest ids keep the v0.4 format (Chapter 1 = g0)")
	var q := PlayerProgress.new(path).load_from_disk()
	check(Economy.claim_chest(q, 1, 0) == 0, "claimed chests persist across restarts")
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


func test_chapters() -> void:
	check(Chapters.chapter_of(1) == 1 and Chapters.chapter_of(10) == 1 and Chapters.chapter_of(11) == 2, "chapter boundaries 10/11")
	for c in range(1, 11):
		var rg := Chapters.chapter_range(c)
		check(rg == Vector2i((c - 1) * 10 + 1, c * 10) and Chapters.chapter_of(rg.x) == c and Chapters.chapter_of(rg.y) == c,
			"chapter %d = levels %d-%d" % [c, rg.x, rg.y])
	check(Chapters.chapter_of(101) == 11 and Chapters.chapter_of(120) == 12, "101-110 = Chapter 11, 111-120 = Chapter 12")
	check(Chapters.defined_count() == 10, "ten hand-made Chapter themes")
	check(Chapters.theme_for_level(100)["id"] == Chapters.MASTER_ID and Chapters.theme_for_level(100)["music"] == "master", "level 100 has the Master theme")
	var ids := {}
	var musics := {}
	var decos := {}
	var styles := {}
	for c in range(1, 11):
		var t := Chapters.theme_for_chapter(c)
		ids[t["id"]] = true
		musics[t["music"]] = true
		decos[t["deco"]] = true
		styles[str(t["block_style"])] = true
		check(ResourceLoader.exists("res://assets/audio/music_%s.wav" % t["music"]), "music file for chapter %d (%s) exists" % [c, t["music"]])
	check(ids.size() == 10 and musics.size() == 10, "every Chapter has its own theme id and music identity")
	check(decos.size() == 10, "every Chapter has its own ambient decoration (%d)" % decos.size())
	check(styles.size() == 10, "block material changes every Chapter")
	check(ResourceLoader.exists("res://assets/audio/music_master.wav"), "Master music exists")
	# Block finish escalates (later Chapters look more premium) - hues never change.
	var gloss_rises := true
	for c in range(2, 11):
		gloss_rises = gloss_rises and Chapters.theme_for_chapter(c)["block_style"]["gloss"] >= Chapters.theme_for_chapter(c - 1)["block_style"]["gloss"]
	check(gloss_rises, "block finish grows Chapter by Chapter")
	# 101+: data-driven overflow, unique ids, names with a round number.
	var t11 := Chapters.theme_for_chapter(11)
	check(t11["id"] == 11 and String(t11["name"]).ends_with(" II") and t11["music"] != "", "Chapter 11 reuses a theme as a new round (%s)" % t11["name"])
	check(Chapters.theme_for_chapter(12)["id"] == 12 and Chapters.theme_for_level(115)["id"] == 12, "Chapter 12 = levels 111-120")
	check(Chapters.title(4) == "CHAPTER 4  ·  EMBER RIDGE", "chapter title text")


## Readability guard for every theme: HUD text on the background and block
## colors on the board keep a minimum contrast (WCAG ratio).
func test_chapter_theme_contrast() -> void:
	var themes := []
	for c in range(1, 11):
		themes.append(Chapters.theme_for_chapter(c))
	themes.append(Chapters.theme_for_level(100))
	for t in themes:
		for bg in [t["bg_top"], t["bg_bottom"]]:
			check(_contrast(t["text"], bg) >= 4.5, "%s: title text contrast %.1f" % [t["name"], _contrast(t["text"], bg)])
			check(_contrast(t["text_soft"], bg) >= 2.6, "%s: soft text contrast %.1f" % [t["name"], _contrast(t["text_soft"], bg)])
		# Blocks vs board: hue/chroma matter as much as brightness (a bright
		# yellow on a pastel board), so use the perceptual CIE76 difference.
		for color in Palette.BLOCKS:
			var de := _delta_e(Palette.face(color), t["board"])
			check(de >= 35.0, "%s: %s blocks stand out from the board (dE %.0f)" % [t["name"], color, de])
	for color in Palette.BLOCKS:
		check(_contrast(Palette.arrow(color), Palette.face(color)) >= 2.0, "%s arrow readable on its block" % color)


static func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _delta_e(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))


static func _lab(c: Color) -> Vector3:
	var r := _lin(c.r)
	var g := _lin(c.g)
	var bl := _lin(c.b)
	var x := (0.4124 * r + 0.3576 * g + 0.1805 * bl) / 0.95047
	var y := 0.2126 * r + 0.7152 * g + 0.0722 * bl
	var z := (0.0193 * r + 0.1192 * g + 0.9505 * bl) / 1.08883
	var f := func(t: float) -> float: return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
	var fx: float = f.call(x)
	var fy: float = f.call(y)
	var fz: float = f.call(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)


func test_generator_future_levels() -> void:
	check(LevelGenerator.profile_for_level(121)["name"] == "w5_master", "101+ maps to the hardest profile")
	check(LevelGenerator.profile_for_level(110)["name"] == "w_mystery_late", "every 10th future level is a mystery")
	var band := LevelGenerator.target_difficulty(150)
	check(band.x > LevelGenerator.target_difficulty(100).x, "target difficulty keeps rising past 100")
	var prev := 0.0
	var ok := true
	for c in range(1, 16):
		ok = ok and LevelGenerator.chapter_target(c) > prev
		prev = LevelGenerator.chapter_target(c)
	check(ok, "chapter difficulty targets rise through Chapter 15")
	var p3 := LevelGenerator.chapter_plan(3)
	var p4 := LevelGenerator.chapter_plan(4)
	var p6 := LevelGenerator.chapter_plan(6)
	var p12 := LevelGenerator.chapter_plan(12)
	check(p3["silver_levels"] == 0 and p4["silver_levels"] > 0 and p4["gold_levels"] == 0 and p6["gold_levels"] > 0, "Silver from Chapter 4, Gold from Chapter 6")
	check(p12["gold_levels"] > 0 and p12["diamond_levels"] == 0 and p12["profile"] == "w5_master", "Chapter 12 plan exists (no Diamond yet)")
	var slots := LevelGenerator.reward_slots(4, 5, 0.5)
	check(slots.size() == 5 and slots.all(func(n): return n >= 31 and n <= 40), "reward slots stay inside the Chapter")
	# Classification of real campaign levels.
	var lm := LevelManager.new()
	lm._ready()
	var c100 := LevelGenerator.classify(lm.load_level(100), 100)
	check(c100["chapter"] == 10 and c100["solvable"] and c100["spinner_complexity"] == 3 and c100["lock_complexity"] >= 2
		and c100["mystery_complexity"] >= 1 and c100["rewards"]["gold"] == 2, "Level 100 classified as a multi-mechanic Chapter 10 level with 2 Gold (%s)" % str(c100))
	var c5 := LevelGenerator.classify(lm.load_level(5), 5)
	check(c5["chapter"] == 1 and c5["spinner_complexity"] == 0 and c5["reward_frequency"] == 0.0, "an early level classifies as simple")
	# The generator can mark rewards on a fresh candidate, and they survive JSON.
	var gen := LevelGenerator.new(3)
	var lvl := gen.generate(LevelGenerator.profile("medium"))
	check(lvl != null, "generator produced a candidate for reward placement")
	if lvl:
		gen.assign_reward_blocks(lvl, 1, 1)
		var again := LevelManager.parse_level(JSON.parse_string(LevelManager.to_json_text(lvl)), 0)
		check(again.blocks.filter(func(b): return b.rarity == BlockData.Rarity.GOLD).size() == 1
			and again.blocks.filter(func(b): return b.rarity == BlockData.Rarity.SILVER).size() == 1, "generated reward blocks survive JSON")
		check(Solver.from_model(model_of(again)).is_solvable(), "reward blocks never change solvability")
	lm.free()


# --- v0.5 -------------------------------------------------------------------

func test_reward_tokens() -> void:
	var l := level_from_map(["R>$S B<@-#R$G .", "Yv?$D G^ ."])
	check(l.blocks[0].rarity == BlockData.Rarity.SILVER and l.blocks[1].rarity == BlockData.Rarity.GOLD
		and l.blocks[2].rarity == BlockData.Rarity.DIAMOND and not l.blocks[3].is_reward(), "rarity tokens $S $G $D parsed")
	check(l.blocks[1].is_spinner() and l.blocks[1].lock_color == "red", "rarity combines with other modifiers")
	var again := LevelManager.parse_level(JSON.parse_string(LevelManager.to_json_text(l)), 0)
	check(again.blocks.map(func(b): return b.rarity) == l.blocks.map(func(b): return b.rarity), "rarities survive JSON round-trip")
	var listed := LevelManager.parse_level({"rows": 1, "columns": 2, "blocks": [
		{"row": 0, "column": 0, "color": "red", "direction": "left", "rarity": "gold"}]}, 0)
	check(listed.blocks[0].rarity == BlockData.Rarity.GOLD, "rarity in the explicit block list format")
	check(Economy.reward_block_coins(BlockData.Rarity.SILVER) == 5 and Economy.reward_block_coins(BlockData.Rarity.GOLD) == 15, "Silver +5, Gold +15 (configurable)")
	check(Economy.reward_block_coins(BlockData.Rarity.DIAMOND) == 0 and Economy.reward_block_coins(BlockData.Rarity.NORMAL) == 0, "Diamond disabled, normal blocks pay nothing")
	# Rules ignore rarity: same moves, same solution.
	var plain := level_from_map(["R> B<@-#R .", "Yv? G^ ."])
	check(Solver.from_model(model_of(l)).solve() == Solver.from_model(model_of(plain)).solve(), "rarity never changes the rules")


## Anti-farming: a reward block pays exactly once per save, whatever
## happens (repeat escapes after Undo/Restart/Replay, relaunch).
func test_reward_blocks_pay_once() -> void:
	var path := "user://test_rewards.cfg"
	wipe_save(path)
	var p := PlayerProgress.new(path).load_from_disk()
	var lvl := level_from_map(["R>$S G<$G ."])
	var start := p.coins
	check(Economy.collect_reward_block(p, 35, lvl.blocks[0]) == 5 and p.coins == start + 5, "Silver pays +5")
	check(Economy.collect_reward_block(p, 35, lvl.blocks[0]) == 0 and p.coins == start + 5, "the same Silver never pays twice (Undo / Restart / Replay)")
	check(Economy.collect_reward_block(p, 36, lvl.blocks[0]) == 5, "a different level's block is a different reward")
	check(Economy.collect_reward_block(p, 35, lvl.blocks[1]) == 15, "Gold pays +15")
	check(p.chapter_coins.get(4, 0) == 25, "reward coins count toward the Chapter's coins")
	var q := PlayerProgress.new(path).load_from_disk()
	check(Economy.collect_reward_block(q, 35, lvl.blocks[0]) == 0 and Economy.collect_reward_block(q, 35, lvl.blocks[1]) == 0, "collected rewards persist across relaunch")
	check(q.collected_rewards(35) == {0: true, 1: true} and q.collected_rewards(3).is_empty(), "collected ids per level")
	check(Economy.collect_reward_block(q, 35, level_from_map(["R>"]).blocks[0]) == 0, "normal blocks never pay")
	wipe_save(path)


func test_chapter_complete_once() -> void:
	var path := "user://test_chapter.cfg"
	wipe_save(path)
	var p := PlayerProgress.new(path).load_from_disk()
	for n in range(1, 10):
		p.record_result(n, 1000, 2)
	check(Economy.check_chapter_complete(p, 1, 100) == 0, "9 of 10 levels: Chapter not complete")
	p.record_result(10, 1000, 2)
	var start := p.coins
	var bonus := Economy.check_chapter_complete(p, 1, 100)
	check(bonus == int(Economy.config()["rewards"]["chapter_complete"]) and p.coins == start + bonus, "10 of 10: Chapter complete pays once")
	check(Economy.check_chapter_complete(p, 1, 100) == 0 and p.coins == start + bonus, "Chapter completion never fires twice")
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.completed_chapters.has(1) and Economy.check_chapter_complete(q, 1, 100) == 0, "Chapter completion persists")
	wipe_save(path)


func test_chest_items() -> void:
	var path := "user://test_chest_items.cfg"
	wipe_save(path)
	var p := PlayerProgress.new(path).load_from_disk()
	for n in range(21, 31):
		p.best_stars[n] = 3
	var tiers := Economy.chest_tiers(p, 3)
	check(tiers.size() == 3 and tiers.all(func(t): return t["claimable"]), "30 stars: all three chest tiers claimable")
	check(Economy.chest_level(p, 3) == 2, "chest upgraded to the top tier")
	var hammers: int = p.inventory.get("hammer", 0)
	var got := Economy.claim_chest(p, 3, 2)
	check(got == int(tiers[2]["coins"]) and p.inventory["hammer"] == hammers + 1, "premium tier pays coins and a Hammer")
	check(Economy.claim_chest(p, 3, 2) == 0 and p.inventory["hammer"] == hammers + 1, "premium tier items never duplicate")
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.inventory["hammer"] == hammers + 1 and q.claimed_chests.has("g2_t2"), "chest items persist")
	wipe_save(path)


## A real v0.4 (save v2) file: Worlds become Chapters, nothing is paid
## twice and nothing is lost.
func test_save_migration_v2() -> void:
	var path := "user://test_migrate_v2.cfg"
	wipe_save(path)
	var old := ConfigFile.new()
	old.set_value("meta", "version", 2)
	old.set_value("progress", "current_level", 57)
	old.set_value("progress", "highest_completed", 56)
	old.set_value("progress", "completed_worlds", [1, 2])
	old.set_value("progress", "perfect_levels", [5])
	old.set_value("progress", "achievements", [])
	for n in range(1, 57):
		old.set_value("scores", str(n), 3000)
		old.set_value("stars", str(n), 2)
	old.set_value("economy", "coins", 480)
	old.set_value("economy", "inventory", {"hint": 2, "hammer": 1})
	old.set_value("economy", "claimed_chests", ["g0_t0", "g1_t0", "g2_t1"])
	old.set_value("settings", "sfx", false)
	old.save(path)
	var p := PlayerProgress.new(path).load_from_disk()
	var bonus := int(Economy.config()["rewards"]["chapter_complete"])
	check(p.version == PlayerProgress.SAVE_VERSION, "v2 save migrated to the current version")
	check(p.current_level == 57 and p.highest_completed == 56 and p.best_score(40) == 3000 and p.stars_for(56) == 2, "v0.4 progress kept")
	check(p.inventory == {"hint": 2, "hammer": 1} and not p.sfx_on, "inventory and settings kept")
	check([1, 2, 3, 4].all(func(c): return p.completed_chapters.has(c)), "completed Worlds 1-2 = Chapters 1-4 complete (no second bonus)")
	check(p.completed_chapters.has(5) and not p.completed_chapters.has(6), "Chapter 5 (41-50) fully cleared inside unfinished World 3 is completed now")
	check(p.coins == 480 + bonus, "only the never-paid Chapter 5 bonus is added (%d)" % p.coins)
	check(Economy.claim_chest(p, 1, 0) == 0 and Economy.claim_chest(p, 3, 1) == 0, "chests claimed in v0.4 stay claimed")
	check(Economy.check_chapter_complete(p, 2, 100) == 0, "no Chapter Complete moment fires for old progress")
	p.save()
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.coins == 480 + bonus and q.completed_chapters.size() == 5, "re-loading a migrated save pays nothing again")
	wipe_save(path)


# --- v0.5.1 stabilization ------------------------------------------------------

func _fresh(path: String) -> PlayerProgress:
	wipe_save(path)
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path("user://")):
		if f.begins_with(path.get_file() + ".corrupt"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + f))
	return PlayerProgress.new(path).load_from_disk()


## TOTAL SCORE = sum of the best score of every completed level. It only
## ever grows, by exactly the improvement, and never drops when moving on.
func test_total_score_model() -> void:
	var path := "user://test_total.cfg"
	var p := _fresh(path)
	check(p.total_score() == 0, "fresh total score is 0")
	var r1 := p.record_result(1, 8200, 3)
	check(p.total_score() == 8200 and r1["total_gain"] == 8200 and r1["total_after"] == 8200, "first clear adds its score to the total")
	var r2 := p.record_result(2, 6000, 2)
	check(p.total_score() == 14200 and r2["total_before"] == 8200, "the next level's lower score ADDS to the total (8200 -> 14200), never replaces it")
	var r3 := p.record_result(1, 5000, 1)
	check(p.total_score() == 14200 and r3["total_gain"] == 0, "a worse replay changes nothing")
	var r4 := p.record_result(1, 9000, 3)
	check(p.total_score() == 15000 and r4["total_gain"] == 800, "a better replay adds only the improvement (+800)")
	for i in 5:
		p.record_result(2, 6000, 2)
	check(p.total_score() == 15000, "replaying the same result can't farm total score")
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.total_score() == 15000, "total score persists")
	var raw := ConfigFile.new()
	raw.load(path)
	check(int(raw.get_value("progress", "total_score", -1)) == 15000, "total score stored in the save for integrity checks")
	wipe_save(path)


## highest_unlocked / last played / last completed are explicit and never
## go backwards, even if a save is partial or inconsistent.
func test_unlocks_never_regress() -> void:
	var path := "user://test_unlock.cfg"
	var p := _fresh(path)
	for n in range(1, 46):
		p.record_result(n, 3000, 2)
	p.current_level = 46
	p.save()
	check(p.highest_unlocked == 46 and p.last_completed_level == 45 and p.highest_completed == 45, "explicit unlock fields after 45 clears")
	p.record_result(10, 5000, 3)
	check(p.highest_unlocked == 46 and p.highest_completed == 45 and p.last_completed_level == 10, "replaying an old level never lowers unlocks")
	# A damaged / inconsistent save: highest fields say 1, but best scores exist up to 45.
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", 4)
	cfg.set_value("progress", "highest_completed", 0)
	cfg.set_value("progress", "highest_unlocked", 1)
	cfg.set_value("progress", "current_level", 46)
	for n in range(1, 46):
		cfg.set_value("scores", str(n), 3000)
	wipe_save(path)
	cfg.save(path)
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.highest_completed == 45 and q.highest_unlocked == 46 and q.is_unlocked(45) and not q.is_unlocked(47), "unlocks re-derived from best scores (never relocked)")
	check(q.current_level == 46 and q.has_progress(), "CONTINUE target kept")
	wipe_save(path)


## Loading picks the NEWEST intact copy (main, .bak, .tmp), by save
## sequence - e.g. a crash between writing the temp file and renaming it.
func test_newest_copy_wins() -> void:
	var path := "user://test_copies.cfg"
	var p := _fresh(path)
	p.record_result(1, 1000, 1)
	p.current_level = 2
	p.save()
	var seq_main := p.seq
	# A newer temp file left behind by an interrupted save.
	var newer := ConfigFile.new()
	newer.load(path)
	newer.set_value("meta", "seq", seq_main + 5)
	newer.set_value("progress", "current_level", 9)
	newer.set_value("progress", "highest_completed", 8)
	newer.save(path + ".tmp")
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.load_source == "tmp" and q.current_level == 9 and q.highest_unlocked == 9, "a newer .tmp copy wins (source %s)" % q.load_source)
	check(q.seq == seq_main + 5, "sequence number restored")
	q.save()
	check(q.seq == seq_main + 6 and not FileAccess.file_exists(path + ".tmp"), "next save continues the sequence and cleans up")
	var before := q.seq
	q.save()
	q.save()
	check(q.seq == before + 2 and q.saved_unix > 0, "every save increments the sequence and stamps the time")
	wipe_save(path)


## A damaged save is never silently replaced by a blank one: it is copied
## aside, the backup is used, and if nothing parses the readable lines are
## salvaged.
func test_corrupt_save_recovery() -> void:
	var path := "user://test_corrupt.cfg"
	var p := _fresh(path)
	for n in range(1, 13):
		p.record_result(n, 2000, 2)
	p.coins = 345
	p.current_level = 13
	p.save()
	p.save()  # .bak now holds a good copy too
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[[[ torn write")
	f.close()
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.load_source == "bak" and q.current_level == 13 and q.coins == 345 and q.highest_unlocked == 13, "damaged main file: the backup is used (source %s)" % q.load_source)
	var quarantined := Array(DirAccess.get_files_at(ProjectSettings.globalize_path("user://"))).filter(func(x): return x.begins_with("test_corrupt.cfg.corrupt"))
	check(quarantined.size() >= 1, "the damaged copy is kept aside for recovery (%s)" % str(quarantined))
	# Everything damaged, but most lines intact: salvage them.
	var good := FileAccess.get_file_as_string(path + ".bak")
	wipe_save(path)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(good.replace("[economy]", "[economy]\ncoins=%%%%broken\n{{{"))
	f.close()
	var r := PlayerProgress.new(path).load_from_disk()
	check(r.load_source.begins_with("salvaged") and r.highest_completed == 12 and r.current_level == 13 and r.best_score(5) == 2000,
		"unreadable save: intact lines salvaged (source %s, highest %d)" % [r.load_source, r.highest_completed])
	check(r.existed and r.has_progress(), "salvaged progress offers CONTINUE (not a blank start)")
	# Nothing readable at all: fresh progress, but the file is preserved.
	wipe_save(path)
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("garbage ]]] === {{")
	f.close()
	var s := PlayerProgress.new(path).load_from_disk()
	check(s.load_source == "unreadable" and not s.existed, "nothing readable: reported, not hidden (source %s)" % s.load_source)
	check(s.hold_writes and not s.save() and FileAccess.get_file_as_string(path) == "garbage ]]] === {{",
		"nothing readable: writes are HELD - the unreadable save is never overwritten by a blank one")
	s.release_hold()
	check(s.save() and s.seq == 1, "START NEW GAME (release_hold) lets writes resume")
	wipe_save(path)


## v0.5.2 recovery safety: the save is gone but its beacon survived, so the
## game knows progress existed - it must not start over and overwrite.
func test_missing_save_holds_writes() -> void:
	var path := "user://test_missing.cfg"
	var p := _fresh(path)
	for n in range(1, 21):
		p.record_result(n, 3000, 2)
	p.current_level = 21
	p.save()
	check(FileAccess.file_exists(path + ".beacon"), "every save writes a beacon next to it")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.load_source == "missing" and q.hold_writes and q.hold_reason == "missing" and int(q.beacon.get("highest_completed", 0)) == 20,
		"save gone, beacon says level 20 was completed: reported as MISSING (source %s)" % q.load_source)
	check(not q.save() and not FileAccess.file_exists(path), "no blank save is written while the recovery choice is pending")
	# A brand-new player (no beacon) is NOT held.
	var fresh := _fresh("user://test_new_player.cfg")
	check(fresh.load_source == "new" and not fresh.hold_writes and fresh.save(), "a new player starts normally")
	wipe_save("user://test_new_player.cfg")
	wipe_save(path)


## v0.5.2 backup code: the whole save as a copyable text code. Restoring
## MERGES (best of both), so it can never lose progress or pay twice.
func test_backup_code_and_merge() -> void:
	var path := "user://test_backup.cfg"
	var p := _fresh(path)
	for n in range(1, 46):
		p.record_result(n, 4000 + n, 2)
	p.record_result(3, 9000, 3, true)
	p.coins = 1234
	p.inventory = {"hint": 4, "hammer": 2}
	p.claimed_chests = ["c1_t0", "c2_t1"]
	p.completed_chapters = [1, 2, 3, 4]
	p.reward_blocks = ["32:4"]
	p.current_level = 46
	p.save()
	var code := p.backup_code()
	check(code.begins_with(PlayerProgress.BACKUP_PREFIX) and code.length() < 4000 and code.find(" ") == -1, "backup code is one compact token (%d chars)" % code.length())
	var text := PlayerProgress.decode_backup(code)
	var d := PlayerProgress.from_text(text)
	check(d != null and d.highest_completed == 45 and d.total_score() == p.total_score() and d.coins == 1234 and d.best_score(3) == 9000,
		"backup code decodes to the same progress")
	check(PlayerProgress.decode_backup("CE1-not!!valid") == "" and PlayerProgress.decode_backup("hello") == "" and PlayerProgress.from_text("") == null,
		"invalid codes are rejected")
	# Restore into a device that has its own, partly better progress.
	var other := _fresh("user://test_backup_other.cfg")
	other.record_result(1, 99999, 3)
	other.record_result(50, 5000, 2)
	other.coins = 50
	other.claimed_chests = ["c5_t0"]
	var r := other.merge_from(d)
	check(other.best_score(1) == 99999 and other.best_score(3) == 9000 and other.best_score(50) == 5000 and other.best_score(45) == 4045,
		"merge keeps the better best score of every level")
	check(other.highest_completed == 50 and other.highest_unlocked == 51 and other.coins == 1234 and other.inventory["hint"] == 4,
		"merge: unlocks max, coins/boosters max (never summed)")
	check(other.claimed_chests.has("c1_t0") and other.claimed_chests.has("c5_t0") and other.has_reward_block(32, 4) and other.completed_chapters.size() == 4,
		"merge: claimed chests / Chapters / reward blocks united - already paid stays paid")
	check(r["total_after"] >= r["total_before"] and r["total_after"] == other.total_score(), "merge never lowers TOTAL SCORE")
	var again := other.merge_from(PlayerProgress.from_text(text))
	check(again["total_after"] == r["total_after"] and other.coins == 1234 and again["levels_added"] == 0, "merging the same code twice changes nothing")
	# Raw save text (the Web transfer from an embed) is accepted too.
	check(PlayerProgress.decode_backup(text) == text, "raw save text is accepted as a transfer")
	wipe_save("user://test_backup_other.cfg")
	wipe_save(path)


## v0.5 (save v3) files migrate to v4 with everything kept.
func test_save_migration_v3() -> void:
	var path := "user://test_migrate_v3.cfg"
	var p := _fresh(path)
	var old := ConfigFile.new()
	old.set_value("meta", "version", 3)
	old.set_value("progress", "current_level", 58)
	old.set_value("progress", "highest_completed", 57)
	for n in range(1, 58):
		old.set_value("scores", str(n), 4000 + n)
		old.set_value("stars", str(n), 2)
	old.set_value("economy", "coins", 910)
	old.set_value("economy", "inventory", {"hint": 3, "hammer": 2})
	old.set_value("economy", "claimed_chests", ["g0_t0", "g4_t2"])
	old.set_value("chapters", "completed", [1, 2, 3, 4, 5])
	old.set_value("chapters", "reward_blocks", ["32:4", "51:7"])
	old.set_value("settings", "music", false)
	wipe_save(path)
	old.save(path)
	p = PlayerProgress.new(path).load_from_disk()
	var expect_total := 0
	for n in range(1, 58):
		expect_total += 4000 + n
	check(p.version == PlayerProgress.SAVE_VERSION and p.load_source == "file", "v3 save migrated to v%d" % PlayerProgress.SAVE_VERSION)
	check(p.current_level == 58 and p.highest_completed == 57 and p.highest_unlocked == 58 and p.last_completed_level == 57, "v3 progress + derived unlock fields")
	check(p.coins == 910 and p.inventory == {"hint": 3, "hammer": 2} and p.claimed_chests.size() == 2 and p.completed_chapters.size() == 5, "coins, inventory, chests, Chapters kept")
	check(p.has_reward_block(32, 4) and p.has_reward_block(51, 7) and not p.music_on, "reward blocks and settings kept")
	check(p.total_score() == expect_total, "total score = sum of v3 best scores (%d)" % p.total_score())
	p.save()
	var q := PlayerProgress.new(path).load_from_disk()
	check(q.coins == 910 and q.total_score() == expect_total and q.seq == 1, "re-saved in v4 without changes")
	wipe_save(path)
