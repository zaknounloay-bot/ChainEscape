extends "res://tools/extreme7_build.gd"
## EXTREME expert calibration (development only): the expert measures of
## tools/expert_probe.gd, plus deep-lookahead learners and greedy players,
## on boards people have already rated, to see which measures order them the
## way the experienced tester did (T5 hardest, then T3, then H2).
##   godot --headless --path . --script res://tools/extreme8_calibrate.gd -- [--boards=T3,T5,H2] [--file=extra.json]
## extra.json: {"name": {"map": [...]}, ...}

const EXPERT := preload("res://tools/expert_probe.gd")
const RATED := [["res://data/dev/extreme5.json", ["T1", "T2", "T3", "T4", "T5"]], ["res://data/dev/extreme6.json", ["P1", "P2"]],
	["res://data/dev/extreme7.json", ["H1", "H2"]]]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var want: Array = str(x_args.get("boards", "")).split(",", false)
	var boards := []
	for f in RATED:
		for b in JSON.parse_string(FileAccess.get_file_as_string(f[0]))["boards"]:
			if b["id"] in f[1] and (want.is_empty() or want.has(b["id"])):
				boards.append([b["id"], Array(b["puzzle"]["map"])])
	if x_args.has("file"):
		var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
		for k in d:
			if want.is_empty() or want.has(k):
				boards.append([k, Array(d[k]["map"])])
	for b in boards:
		print(JSON.stringify(expert_report(b[0], b[1])))
	quit()


func expert_report(name: String, map: Array) -> Dictionary:
	var level := parse(map)
	var s := _solver(level)
	var t0 := Time.get_ticks_msec()
	var r := EXPERT.measure(s)
	r["name"] = name
	var learn := {}
	for look in [2, 4, 6]:
		var best := 99.0
		for o in ORDERS:
			best = minf(best, PROBE.learner_stats(s, 9, look, o, 30000)["dead_ends_med"])
		learn["look%d" % look] = best
	r["learner_best_dead_ends"] = learn
	var g := {}
	for k in ["safe", "look2", "look4", "look6", "min_turn", "mobility"]:
		g[k] = PROBE.policy_win(s, k, 60 if k == "look6" else 120, 31)
	r["greedy"] = g
	r["ms"] = Time.get_ticks_msec() - t0
	return r
