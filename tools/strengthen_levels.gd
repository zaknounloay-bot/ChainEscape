extends SceneTree
## Difficulty tuning for existing campaign levels (v0.5).
##
##   godot --headless --path . --script res://tools/strengthen_levels.gd -- \
##       --targets=62:48,64:48 [--steps=700] [--seed=1] [--write]
##
## Hill-climbs a level toward a target difficulty with the generator's own
## mutations (turn an arrow, spinner trap motif, toggle a spinner, change a
## spinner rule within the kinds the level already uses, move a block, add a
## block). The level keeps its size, name, mechanics and rule identity.
## Every accepted step must stay solvable and satisfy the late-campaign
## rules (<= 2 starting moves, depth >= 8, >= 4 decision points, all four
## directions, no direction on more than 45% of blocks). The final result
## must also pass the full LevelAnalysis checks (every mechanic essential or
## impactful, mystery fair) and must not resemble another campaign board.
## Without --write it only reports.

const MAX_SHARE := 0.45
const MAX_SIMILARITY := 0.6
## Never overshoot the target by more than this.
const CAP_MARGIN := 1.5


func _initialize() -> void:
	var args := {"targets": "", "steps": "700", "seed": "1"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var write := "--write" in OS.get_cmdline_user_args()
	var lm := LevelManager.new()
	lm._ready()
	var all := {}
	for n in range(1, lm.level_count + 1):
		all[n] = lm.load_level(n)
	for spec in String(args["targets"]).split(",", false):
		var n := int(spec.get_slice(":", 0))
		var target := float(spec.get_slice(":", 1))
		var t0 := Time.get_ticks_msec()
		var result := strengthen(all[n], target, int(args["steps"]), int(args["seed"]) * 1000 + n, all)
		var secs := (Time.get_ticks_msec() - t0) / 1000.0
		if result.is_empty():
			print("L%d: no valid stronger version found (%.0fs)" % [n, secs])
			continue
		print("L%d %s: difficulty %.1f -> %.1f  blocks %d -> %d  depth %d dec %d start %d  (%.0fs)" % [
			n, all[n].name, result["from"], result["m"]["difficulty"], all[n].blocks.size(), result["level"].blocks.size(),
			result["m"]["depth"], result["m"]["decision_points"], result["m"]["start_moves"], secs])
		if write:
			_write(n, result["level"])
	lm.free()
	quit()


func strengthen(original: LevelData, target: float, steps: int, seed: int, all: Dictionary) -> Dictionary:
	var gen := LevelGenerator.new(seed)
	var p := _profile_for(original)
	var start := gen.evaluate(original)
	var best := original
	var best_m := start
	var accepted: Array = []  # [level, metrics] in increasing difficulty
	for step in steps:
		if best_m["difficulty"] >= target:
			break
		var cand: LevelData = _add_block(gen, best, original) if gen.rng.randf() < 0.12 else gen._mutate(best, p)
		if cand == null:
			continue
		var m := gen.evaluate(cand)
		if not _cheap_ok(m, original) or m["difficulty"] > target + CAP_MARGIN:
			continue
		if m["difficulty"] >= best_m["difficulty"]:
			best = cand
			best_m = m
			if m["difficulty"] > start["difficulty"] + 0.05:
				accepted.append([cand, m])
	# Walk back from the strongest version to the first that passes the
	# expensive checks.
	for i in range(accepted.size() - 1, -1, -1):
		var lvl: LevelData = accepted[i][0]
		lvl.name = original.name
		lvl.mystery = lvl.blocks.any(func(b): return b.hidden)
		if _full_ok(lvl, original, all):
			return {"level": lvl, "m": accepted[i][1], "from": start["difficulty"]}
	return {}


## Mutation limits derived from the level itself, so it keeps its identity.
func _profile_for(level: LevelData) -> Dictionary:
	var p := LevelGenerator.profile("w5_expert")
	var spinners := level.blocks.filter(func(b): return b.is_spinner()).size()
	var locks := level.blocks.filter(func(b): return b.lock_color != "").size()
	var hidden := level.blocks.filter(func(b): return b.hidden).size()
	p["sizes"] = [Vector2i(level.columns, level.rows)]
	p["spinners"] = Vector2i(spinners, spinners + 1)
	p["locks"] = Vector2i(locks, locks)
	p["hidden"] = Vector2i(hidden, hidden)
	var rules := {}
	for b in level.blocks:
		if b.is_spinner() and b.spin_rule != BlockData.SpinRule.CW:
			var name: String = ["cw", "ccw", "alt", "pattern"][b.spin_rule]
			var have: int = level.blocks.filter(func(x): return x.is_spinner() and x.spin_rule == b.spin_rule).size()
			rules[name] = Vector2i(have, have + 1)
	p["spin_rules"] = rules
	return p


func _add_block(gen: LevelGenerator, level: LevelData, original: LevelData) -> LevelData:
	if level.blocks.size() >= original.blocks.size() + 3:
		return null
	var copy := LevelData.new()
	copy.rows = level.rows
	copy.columns = level.columns
	var occupied := {}
	for b in level.blocks:
		copy.blocks.append(b.duplicate_data())
		occupied[b.cell] = true
	var empty := []
	for r in copy.rows:
		for c in copy.columns:
			if not occupied.has(Vector2i(c, r)):
				empty.append(Vector2i(c, r))
	if empty.is_empty():
		return null
	var cell: Vector2i = empty[gen.rng.randi() % empty.size()]
	var color: String = LevelGenerator.COLORS[gen.rng.randi() % LevelGenerator.COLORS.size()]
	copy.blocks.append(BlockData.new(copy.blocks.size(), cell, color, gen.rng.randi() % 4))
	return gen._rebuilt(copy)


func _cheap_ok(m: Dictionary, original: LevelData) -> bool:
	if not m["solvable"] or m["aborted"]:
		return false
	if m["start_moves"] > 2 or m["depth"] < 8 or m["decision_points"] < 4:
		return false
	return m["directions_used"] == 4 and m["direction_share"] <= MAX_SHARE


func _full_ok(level: LevelData, original: LevelData, all: Dictionary) -> bool:
	var m := LevelAnalysis.analyze(level)
	if not m["solvable"] or m["aborted"]:
		return false
	if m["spinners"] > 0 and m["spinner_impact"] < 0.5:
		return false
	if m["locks"] > 0 and m["lock_impact"] < 0.5:
		return false
	if m["hidden"] > 0 and (not m["mystery_fair"] or m["mystery_impact"] < 0.3):
		return false
	for n in all:
		var other: LevelData = all[n]
		if n < 11 or other.name == original.name:
			continue
		if other.rows == level.rows and other.columns == level.columns and LevelGenerator.similarity(level, other) > MAX_SIMILARITY:
			return false
	return true


## Rewrites only the "map" of the level file; every other key is kept.
func _write(n: int, level: LevelData) -> void:
	var path := LevelManager.LEVEL_PATH % n
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var mapped: Dictionary = JSON.parse_string(LevelManager.to_json_text(level))
	json["map"] = mapped["map"]
	if level.mystery:
		json["mystery"] = true
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(LevelManager.format_level_json(json))
	f.close()
