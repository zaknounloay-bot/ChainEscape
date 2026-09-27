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
##   * v0.5 Chapters: every Chapter's average difficulty is at least
##     MIN_CHAPTER_STEP above the previous Chapter's (cosmetic progression
##     never replaces puzzle progression)
##   * v0.5 reward blocks: only from their "from_level" (economy.json), at
##     most 2 per level (3 on the Master Level), never on a disabled rarity

const HIGH_LEVEL := 21
const LATE_LEVEL := 61
const MAX_SIMILARITY := 0.6
const MIN_CHAPTER_STEP := 2.0


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
	print("  # C name               size blk spn rules  lck hid start trp dec dep len dir%  diff   S    L    M  fair rwd status")
	var diffs := {}
	for i in files.size():
		var json = JSON.parse_string(FileAccess.get_file_as_string(files[i]))
		var level := LevelManager.parse_level(json, i + 1)
		levels.append(level)
		var m := LevelAnalysis.analyze(level)
		var n := i + 1
		diffs[n] = m["difficulty"]
		var status := "OK"
		var rwd := _reward_text(level)
		if not m["solvable"] or m["aborted"]:
			status = "GAVE UP" if m["aborted"] else "UNSOLVABLE"
			problems.append("L%d %s" % [n, status])
		elif campaign:
			var issue := _rule_issue(n, m)
			if issue == "":
				issue = _reward_issue(n, level)
			if issue != "":
				status = issue
				problems.append("L%d %s" % [n, issue])
		var rules := "c%da%dp%d" % [m["rule_ccw"], m["rule_alt"], m["rule_pattern"]] if m["spinners"] > 0 else "-"
		print("%3d %2d %-17s %dx%d %3d %3d %-6s %3d %3d %5d %3d %3d %3d %3d %4d %5.1f %4s %4s %4s  %-4s %-3s %s" % [
			n, Chapters.chapter_of(n), level.name.left(17), level.columns, level.rows, m["blocks"], m["spinners"], rules, m["locks"], m["hidden"],
			m["start_moves"], m["start_traps"], m["decision_points"], m["depth"], m["solution_length"],
			int(m["direction_share"] * 100), m["difficulty"],
			_imp(m["spinner_impact"], m["spinners"]), _imp(m["lock_impact"], m["locks"]), _imp(m["mystery_impact"], m["hidden"]),
			("yes" if m["mystery_fair"] else "NO") if m["hidden"] > 0 else "-", rwd, status])
	var master := Chapters.master_level()
	if campaign and diffs.has(master):
		var top: float = diffs.values().max()
		if diffs[master] < top:
			problems.append("L100 (Master) is not the hardest level (%.1f < %.1f)" % [diffs[master], top])
	if campaign:
		# Chapter difficulty curve.
		var line := PackedStringArray()
		var prev := -1.0
		for c in range(1, Chapters.chapter_count(files.size()) + 1):
			var rg := Chapters.chapter_range(c)
			var sum := 0.0
			var cnt := 0
			for k in range(rg.x, mini(rg.y, files.size()) + 1):
				sum += diffs[k]
				cnt += 1
			var avg := sum / maxf(cnt, 1)
			line.append("C%d %.1f" % [c, avg])
			if prev >= 0.0 and avg < prev + MIN_CHAPTER_STEP:
				problems.append("Chapter %d average difficulty %.1f is not above Chapter %d (%.1f) by %.1f" % [c, avg, c - 1, prev, MIN_CHAPTER_STEP])
			prev = avg
		print("Chapter difficulty: " + "  ".join(line))
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
	if n == Chapters.master_level():
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


static func _reward_issue(n: int, level: LevelData) -> String:
	var count := 0
	for b in level.blocks:
		if not b.is_reward():
			continue
		count += 1
		var cfg: Dictionary = Economy.config()["reward_blocks"].get(b.rarity_name(), {})
		if not bool(cfg.get("enabled", false)):
			return "DISABLED REWARD RARITY"
		if n < int(cfg.get("from_level", 0)):
			return "%s BLOCK BEFORE LEVEL %d" % [b.rarity_name().to_upper(), int(cfg["from_level"])]
	if count > (3 if n == Chapters.master_level() else 2):
		return "TOO MANY REWARD BLOCKS"
	return ""


## "S", "G", "SG", "GG" ... (reward blocks on the level).
static func _reward_text(level: LevelData) -> String:
	var t := ""
	for b in level.blocks:
		if b.is_reward():
			t += BlockData.RARITY_TOKENS[b.rarity]
	return t if t != "" else "-"


static func _imp(v: float, count: int) -> String:
	if count == 0:
		return "-"
	if v >= LevelAnalysis.ESSENTIAL:
		return "ESS"
	return "%.1f" % v
