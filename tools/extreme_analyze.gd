extends SceneTree
## EXTREME research, Phase A (development only): the human-like play proxies
## of tools/extreme_probe.gd on every Gate 0 pilot board (or any board file
## with a "boards" list of {id, puzzle: {map}}), as a table and a JSON file.
##
##   godot --headless --path . --script res://tools/extreme_analyze.gd -- [--in=res://data/dev/vh_pilot4.json] [--out=/tmp/a.json] [--runs=40]

const PROBE := preload("res://tools/extreme_probe.gd")


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	var path := str(args.get("in", "res://data/dev/vh_pilot4.json"))
	var runs := int(args.get("runs", "40"))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var boards: Array = data["boards"]
	boards.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var rows := []
	print("id   L0de L0tap L2de L2tap | safe  look2 look4 minT | risky forced real lose | opp pat minT mob best")
	for b in boards:
		var map: Array = b["puzzle"]["map"] if b.has("puzzle") else b["map"]
		var level := LevelManager.parse_level({"name": "probe", "map": map}, 0, true)
		var r := measure(level, runs)
		r["id"] = b["id"]
		rows.append(r)
		var l0: Dictionary = r["learner0"]
		var l2: Dictionary = r["learner2"]
		var p: Dictionary = r["policies"]
		var c: Dictionary = r["choices"]
		print("%s %5.1f %5.0f %4.1f %5.0f | %.2f  %.2f  %.2f  %.2f | %5d %6d %4d %4d | %s" % [b["id"], l0["dead_ends_med"], l0["taps_med"],
			l2["dead_ends_med"], l2["taps_med"], p["safe"], p["look2"], p["look4"], p["min_turn"],
			c["risky_steps"], c["forced_risky"], c["real_choices"], c["losing_options"],
			"%3.0f %3.0f %4.0f %3.0f %4.0f" % [r["ordered"]["opportunist"], r["ordered"]["patient"], r["ordered"]["min_turn"], r["ordered"]["mobility"], r["ordered"]["best"]]])
	if args.has("out"):
		var f := FileAccess.open(str(args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify({"rows": rows}, " "))
		f.close()
	quit()


## Dead ends (median) for a learner using each rule of thumb, looking 2
## moves ahead; "best" = the luckiest rule (an optimistic model of a person).
static func _ordered(s: Solver, runs: int) -> Dictionary:
	var out := {}
	var best := 1e9
	for o in ["opportunist", "patient", "min_turn", "mobility"]:
		var r := PROBE.learner_stats(s, runs, 2, o)
		out[o] = r["dead_ends_med"]
		best = minf(best, r["dead_ends_med"])
	out["best"] = best
	return out


static func solver_of(level: LevelData) -> Solver:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals(level.portals)
	return Solver.from_model(m)


static func measure(level: LevelData, runs: int) -> Dictionary:
	var s := solver_of(level)
	return {
		"learner0": PROBE.learner_stats(s, runs, 0),
		"learner2": PROBE.learner_stats(s, maxi(runs / 2, 1), 2),
		"policies": {
			"safe": PROBE.policy_win(s, "safe", 200, 11),
			"look2": PROBE.policy_win(s, "look2", 200, 12),
			"look4": PROBE.policy_win(s, "look4", 120, 13),
			"min_turn": PROBE.policy_win(s, "min_turn", 200, 14),
			"mobility": PROBE.policy_win(s, "mobility", 200, 15),
		},
		"ordered": _ordered(s, maxi(runs / 2, 1)),
		"choices": PROBE.choices(s),
		"misleading": PROBE.misleading(s, 4),
	}
