extends "res://tools/ta90_humanlike26.gd"
## PHASE 29 (development only): the advisory human-difficulty ranking layer
## (docs/extreme90_phase29.md, section E). It runs on screened boards BEFORE
## full evaluation and decides nothing: every technical gate stays where it
## is. Per board: the Phase 26 diagnostics (tools/ta90_humanlike26.gd) plus
## the simple players humans tracked best in the Phase 24-28 calibration:
##   gmax   the best one-attempt greedy policy (safe / look2 / look4 /
##          min_turn / mobility, 120 games each - the Category B shortcut set)
##   look6  the 6-move lookahead greedy (Category C)
##   forced_share, dep_depth, p_calm (from ta90_humanlike26.gd)
## and three ADVISORY risk flags, fitted after the fact on 19 rated boards
## (in-sample, not validated - data/dev/extreme90_p29/calibration_table.json):
##   simple_strategy  p_calm >= 0.01 or gmax >= 0.09 or look6 >= 0.08
##   linear           forced_share > 0.60 (one insight, then a forced chain)
##   shallow          dep_depth <= 3 (repetition: pushes rather than reasoning)
##   godot --headless --path . --script res://tools/ta90_rank29.gd -- --file=boards.json [--out=rank.json]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	_load_known()
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var out := {}
	for name in d:
		var r := humanlike(Array(d[name]["map"]))
		var s := _solver(parse(Array(d[name]["map"])))
		var g := 0.0
		for k in POLICIES:
			g = maxf(g, PROBE.policy_win(s, k, 120, 31))
		r["gmax"] = snappedf(g, 0.001)
		r["look6"] = snappedf(PROBE.policy_win(s, "look6", 120, 31), 0.001)
		r["forced_share"] = snappedf(float(r["forced"]) / maxf(r["solution"], 1), 0.01)
		var flags := []
		if r["p_calm"] >= 0.01 or r["gmax"] >= 0.09 or r["look6"] >= 0.08:
			flags.append("simple_strategy")
		if r["forced_share"] > 0.60:
			flags.append("linear")
		if r["dep_depth"] <= 3:
			flags.append("shallow")
		r["flags"] = flags
		# Advisory order only: fewer flags first, then the simple players (lower
		# is harder for people in the calibration), then dependency depth.
		r["rank_key"] = [flags.size(), snappedf(r["p_calm"] * 10.0 + r["gmax"] + r["look6"], 0.001), -int(r["dep_depth"])]
		out[name] = r
		print("%-12s flags %s gmax %.3f look6 %.3f p_calm %.3f forced %.2f dep %d" % [name, flags, r["gmax"], r["look6"], r["p_calm"], r["forced_share"], r["dep_depth"]])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()
