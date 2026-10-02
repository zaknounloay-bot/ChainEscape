extends SceneTree
## VERY HARD human test (development only): builds the fixed board set the
## blind test page plays (?vhtest=1), offline, with generous search budgets.
##   godot --headless --path . --script res://tools/vh_human_test_build.gd
## Writes data/dev/vh_human_test.json and prints the per-variant statistics.
##
## Variants (the tester never sees which is which):
##   A  current production VERY HARD (FriendGenerator.SPECS, product time cap)
##   B  heuristic-selected VERY HARD with an OPENING CONSTRAINT: 1-2 legal
##      first moves, exactly ONE of them safe, and no "calm" first move (every
##      safe first move turns a spinner, so it must be thought through); deep
##      decisions kept (>= 5 one-safe steps); a rule-aware heuristic player
##      rarely wins. Arrows + clockwise spinners only. Long offline search;
##      over-generated, then the boards with the lowest independent
##      heuristic-player rates are kept.
##   C  VERY HARD + Classic Locks prototype (control; the lock audit found
##      no gain).
## Nothing here is production: the game never generates these specs.

const OUT := "res://data/dev/vh_human_test.json"
const COUNTS := {"A": 6, "B": 6, "C": 3}
const B_CANDIDATES := 14
const B_SPEC := {
	"profile": "expert", "band": Vector2(28, 999), "accept": Vector2(24, 999), "max_evals": 100000, "time_cap_ms": 30000,
	"sample": 3, "stale": 60, "replace": true,
	"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(5, 6)},
	"human": {"max_start": 2, "max_start_safe": 1, "max_start_calm": 0, "min_one_safe": 5, "max_safe_choices": 1.9,
		"min_decisions": 8, "max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
		"max_smart": 0.12, "smart_games": 30, "smart_depth": 2},
}


func _init() -> void:
	var boards := []
	var stats := {}
	# A: production VERY HARD, as the live game makes it.
	var a := []
	for i in COUNTS["A"]:
		var g := FriendGenerator.new(FriendGenerator.VERY_HARD, 71000 + i * 7919, [], -1)
		a.append(_record("A", g.run(), g, i))
	# B: over-generate with the opening constraint, keep the hardest.
	FriendGenerator.spec_override = {FriendGenerator.VERY_HARD: B_SPEC}
	var b := []
	for i in B_CANDIDATES:
		var g := FriendGenerator.new(FriendGenerator.VERY_HARD, 91000 + i * 7919, [], -1)
		var rec := _record("B", g.run(), g, 100 + i)
		if rec.is_empty() or not rec["metrics"]["met_all"]:
			continue
		var m: Dictionary = rec["metrics"]
		if m["start_safe"] == 1 and m["start_calm"] == 0 and m["start_moves"] <= 2:
			b.append(rec)
	b.sort_custom(func(x, y): return x["metrics"]["smart2"] + x["metrics"]["smart3"] < y["metrics"]["smart2"] + y["metrics"]["smart3"])
	b = b.slice(0, COUNTS["B"])
	# C: the lock prototype (control).
	var proto: Dictionary = load("res://tools/lock_prototype_bench.gd").PROTOS["proto"].duplicate(true)
	proto["replace"] = true
	FriendGenerator.spec_override = {FriendGenerator.VERY_HARD: proto}
	var c := []
	for i in COUNTS["C"]:
		var g := FriendGenerator.new(FriendGenerator.VERY_HARD, 51000 + i * 7919, [], -1)
		c.append(_record("C", g.run(), g, 200 + i))
	FriendGenerator.spec_override = {}
	for set in [a, b, c]:
		for rec in set:
			if not rec.is_empty():
				boards.append(rec)
	# Neutral ids (T01...) in a fixed shuffled order; the page shuffles again.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261002
	for i in range(boards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = boards[i]
		boards[i] = boards[j]
		boards[j] = t
	for i in boards.size():
		boards[i]["id"] = "T%02d" % (i + 1)
	var data := {"format": "ce-vh-human-test", "v": 1, "assist": {"undo": 3, "show_a_move": 1, "hammer": 1}, "boards": boards}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/dev"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()
	print("wrote %s: %d boards (A %d, B %d, C %d)" % [OUT, boards.size(), a.size(), b.size(), c.size()])
	_summary(boards)
	quit()


func _record(variant: String, def: PuzzleDefinition, g: FriendGenerator, i: int) -> Dictionary:
	if def == null:
		push_error("variant %s #%d: no board (%s)" % [variant, i, g.error])
		return {}
	var rebuilt := PuzzleDefinition.from_json(def.to_json())
	var locks := variant == "C"
	if rebuilt == null or rebuilt.fingerprint() != def.fingerprint() or not rebuilt.verify() \
			or not FriendGenerator.mechanics_ok(rebuilt, FriendGenerator.VERY_HARD, locks) or FriendGenerator.is_classic_board(rebuilt):
		push_error("variant %s #%d: board failed verification" % [variant, i])
		return {}
	var lv := rebuilt.to_level()
	var model := BoardModel.new()
	model.setup(lv.rows, lv.columns, lv.blocks)
	var s := Solver.from_model(model)
	var an := s.analyze()
	var m := {
		"start_moves": an["start_moves"], "start_safe": an["start_safe"], "start_calm": an["start_calm"],
		"one_safe_steps": an["one_safe_steps"], "safe_choices": an["safe_choices"], "decision_points": an["decision_points"],
		"depth": an["depth"], "solution_length": an["solution"].size(), "blocks": an["blocks"], "spinners": an["spinners"], "locks": an["locks"],
		"random": snappedf(s.random_win_rate(300, 1300 + i), 0.001),
		"smart2": snappedf(s.heuristic_win_rate(100, 2, 1700 + i), 0.001),
		"smart3": snappedf(s.heuristic_win_rate(60, 3, 1900 + i), 0.001),
		"gen_ms": g.metrics.get("ms", 0), "gen_evals": g.evals, "met_all": g.metrics.get("in_band", false),
	}
	return {"variant": variant, "puzzle": rebuilt.to_dict(), "fingerprint": rebuilt.fingerprint(), "metrics": m}


func _summary(boards: Array) -> void:
	print("variant  n  start  start_safe  one_safe_opening  start_calm  one_safe_steps  safe_choices  decisions  depth  smart2  smart3  random  gen_ms(p50/max)")
	for v in ["A", "B", "C"]:
		var rows := boards.filter(func(x): return x["variant"] == v)
		if rows.is_empty():
			continue
		var avg := func(k: String) -> float: return rows.reduce(func(acc, x): return acc + float(x["metrics"][k]), 0.0) / rows.size()
		var only_one := rows.filter(func(x): return x["metrics"]["start_safe"] == 1).size()
		var ms := rows.map(func(x): return int(x["metrics"]["gen_ms"]))
		ms.sort()
		print("%s  %2d  %5.2f  %10.2f  %10d/%-5d  %10.2f  %14.2f  %12.2f  %9.2f  %5.2f  %5.1f%%  %5.1f%%  %5.1f%%  %d/%d" % [v, rows.size(),
			avg.call("start_moves"), avg.call("start_safe"), only_one, rows.size(), avg.call("start_calm"), avg.call("one_safe_steps"),
			avg.call("safe_choices"), avg.call("decision_points"), avg.call("depth"),
			100 * avg.call("smart2"), 100 * avg.call("smart3"), 100 * avg.call("random"), ms[ms.size() / 2], ms[-1]])
