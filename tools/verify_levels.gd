extends SceneTree
## Campaign verifier: real rules + Solver + LevelAnalysis, no rendering.
##
##   godot --headless --path . --script res://tools/verify_levels.gd
##   godot --headless --path . --script res://tools/verify_levels.gd -- --file=path/to/level.json
##
## Per level it reports size, blocks, spinners, locks, hidden arrows, legal
## starting moves, starting traps, decision points, dependency depth,
## solution length, largest direction share, difficulty score, how much
## each mechanic adds (S/L/M impact; "ESS" = level unsolvable without it)
## and mystery fairness.
##
## Campaign rules (the run FAILS if any is broken):
##   * every level solvable (and the solver did not give up)
##   * from level 21: at most 3 starting moves, depth >= 5, all four
##     directions used, no direction on more than 45% of blocks
##   * every level that uses spinners / locks / mystery: that mechanic must
##     add difficulty (impact >= 0.5; mystery >= 0.3) - no decoration
##   * mystery levels: provably fair (hidden arrows never decide a trap)
##   * from level 61: at most 2 starting moves, depth >= 8, >= 4 decision
##     points (misleading-but-fair options)
##   * Level 100 (Master): spinners of 3+ rules, locks and mystery, fair,
##     and the highest difficulty score in the campaign
##   * from level 11: no two boards of the same size more than 60% alike

const HIGH_LEVEL := 21
const LATE_LEVEL := 61
const MAX_SIMILARITY := 0.6


func _initialize() -> void:
	var files: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="):
			files.append(a.get_slice("=", 1))
	var campaign := files.is_empty()
	if campaign:
		var n := 1
		while FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
			files.append(LevelManager.LEVEL_PATH % n)
			n += 1
	var problems: Array[String] = []
	var levels: Array = []
	print("  # W name               size blk spn rules  lck hid start trp dec dep len dir%  diff   S    L    M  fair status")
	var diffs := {}
	for i in files.size():
		var json = JSON.parse_string(FileAccess.get_file_as_string(files[i]))
		var level := LevelManager.parse_level(json, i + 1)
		levels.append(level)
		var m := LevelAnalysis.analyze(level)
		var n := i + 1
		diffs[n] = m["difficulty"]
		var status := "OK"
		if not m["solvable"] or m["aborted"]:
			status = "GAVE UP" if m["aborted"] else "UNSOLVABLE"
			problems.append("L%d %s" % [n, status])
		elif campaign:
			var issue := _rule_issue(n, m)
			if issue != "":
				status = issue
				problems.append("L%d %s" % [n, issue])
		var rules := "c%da%dp%d" % [m["rule_ccw"], m["rule_alt"], m["rule_pattern"]] if m["spinners"] > 0 else "-"
		print("%3d %d %-17s %dx%d %3d %3d %-6s %3d %3d %5d %3d %3d %3d %3d %4d %5.1f %4s %4s %4s  %-4s %s" % [
			n, Worlds.world_of(n), level.name.left(17), level.columns, level.rows, m["blocks"], m["spinners"], rules, m["locks"], m["hidden"],
			m["start_moves"], m["start_traps"], m["decision_points"], m["depth"], m["solution_length"],
			int(m["direction_share"] * 100), m["difficulty"],
			_imp(m["spinner_impact"], m["spinners"]), _imp(m["lock_impact"], m["locks"]), _imp(m["mystery_impact"], m["hidden"]),
			("yes" if m["mystery_fair"] else "NO") if m["hidden"] > 0 else "-", status])
	if campaign and diffs.has(Worlds.MASTER_LEVEL):
		var top: float = diffs.values().max()
		if diffs[Worlds.MASTER_LEVEL] < top:
			problems.append("L100 (Master) is not the hardest level (%.1f < %.1f)" % [diffs[Worlds.MASTER_LEVEL], top])
	if campaign:
		for i in range(10, levels.size()):
			for j in range(10, i):
				var a: LevelData = levels[i]
				var b: LevelData = levels[j]
				if a.rows == b.rows and a.columns == b.columns and LevelGenerator.similarity(a, b) > MAX_SIMILARITY:
					problems.append("L%d is too similar to L%d" % [i + 1, j + 1])
	for p in problems:
		printerr("PROBLEM: " + p)
	print("ALL %d LEVELS SOLVABLE AND PASS CAMPAIGN RULES" % files.size() if problems.is_empty() else "LEVEL CHECK FAILED (%d problems)" % problems.size())
	quit(0 if problems.is_empty() else 1)


static func _rule_issue(n: int, m: Dictionary) -> String:
	if n >= LATE_LEVEL:
		if m["start_moves"] > 2:
			return "TOO MANY START MOVES (61+)"
		if m["depth"] < 8:
			return "TOO SHALLOW (61+)"
		if m["decision_points"] < 4:
			return "TOO FEW DECISIONS (61+)"
	if n == Worlds.MASTER_LEVEL:
		var rule_kinds := int(m["rule_cw"] > 0) + int(m["rule_ccw"] > 0) + int(m["rule_alt"] > 0) + int(m["rule_pattern"] > 0)
		if rule_kinds < 3 or m["locks"] == 0 or m["hidden"] == 0:
			return "MASTER NEEDS SPINNER RULES + LOCKS + MYSTERY"
	if n >= HIGH_LEVEL:
		if m["start_moves"] > 3:
			return "TOO MANY START MOVES"
		if m["depth"] < 5:
			return "TOO SHALLOW"
		if m["directions_used"] < 4 or m["direction_share"] > 0.45:
			return "ONE DIRECTION DOMINATES"
	if m["spinners"] > 0 and m["spinner_impact"] < 0.5:
		return "SPINNERS DECORATIVE"
	if m["locks"] > 0 and m["lock_impact"] < 0.5:
		return "LOCKS DECORATIVE"
	if m["hidden"] > 0:
		if not m["mystery_fair"]:
			return "MYSTERY UNFAIR"
		if m["mystery_impact"] < 0.3:
			return "MYSTERY DECORATIVE"
	return ""


static func _imp(v: float, count: int) -> String:
	if count == 0:
		return "-"
	if v >= LevelAnalysis.ESSENTIAL:
		return "ESS"
	return "%.1f" % v
