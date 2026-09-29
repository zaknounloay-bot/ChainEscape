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
##     most 2 per level (3 on the Master Level), never on a disabled rarity,
##     never on an armored block (v0.6.2: a reward must never read as a shell)
##   * v0.6 Second Era (101-200):
##       - switches only from 101, Chain Gates from 121, armored blocks from
##         161 (a mechanic is always introduced before it is combined)
##       - every switch / gate / shell must change how the level is solved
##         (structural impact >= 1.0) - no decoration
##       - the Switch lessons 101-105 need the switch (unsolvable without)
##         and may be small (<= 3 start moves, depth >= 3); from 106 the
##         late-game rules apply
##       - Chapter averages rise inside each era; Chapter 11 starts the
##         Second Era lower on purpose (it teaches a new mechanic)
##       - each Master Level (100, 200) is the hardest level of its era -
##         by difficulty AND by structural difficulty (v0.6.2) - and
##         Level 200 uses switches, gates, armor, spinners of 3+ rules,
##         locks and mystery
##   * v0.6.1 armor safety (every level, campaign or --file): the verifier
##     walks EVERY state a player can reach without the Hammer (all escapes
##     and rams, in every order, cross-checked by BoardModel in
##     tools/armor_audit.gd). The level fails if any reachable dead end still
##     holds an intact shell - that covers a shell left as the last block, a
##     shell whose every possible rammer escaped or turned away first, and
##     so any level that could only be finished with the Hammer. The search
##     must finish (no state cap reached).

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
	var structs := {}
	for i in files.size():
		var json = JSON.parse_string(FileAccess.get_file_as_string(files[i]))
		var level := LevelManager.parse_level(json, i + 1)
		levels.append(level)
		var m := LevelAnalysis.analyze(level)
		var n := i + 1
		diffs[n] = m["difficulty"]
		structs[n] = LevelGenerator.structural_difficulty(m)
		var status := "OK"
		var rwd := _reward_text(level)
		if not m["solvable"] or m["aborted"]:
			status = "GAVE UP" if m["aborted"] else "UNSOLVABLE"
			problems.append("L%d %s" % [n, status])
		elif m["armored"] > 0 and _armor_issue(level) != "":
			status = "ARMOR UNCRACKABLE"
			problems.append("L%d %s" % [n, _armor_issue(level)])
		elif campaign:
			var issue := _rule_issue(n, m)
			if issue == "":
				issue = _reward_issue(n, level)
			if issue != "":
				status = issue
				problems.append("L%d %s" % [n, issue])
		var rules := "c%da%dp%d" % [m["rule_ccw"], m["rule_alt"], m["rule_pattern"]] if m["spinners"] > 0 else "-"
		var era2 := ""
		if m["switches"] + m["gates"] + m["armored"] > 0:
			era2 = " sw%d:%s gt%d:%s ar%d:%s" % [m["switches"], _imp(m["switch_impact"], m["switches"]), m["gates"], _imp(m["gate_impact"], m["gates"]),
				m["armored"], _imp(m["armor_impact"], m["armored"])]
		print("%3d %2d %-17s %dx%d %3d %3d %-6s %3d %3d %5d %3d %3d %3d %3d %4d %5.1f %4s %4s %4s  %-4s %-3s %s%s" % [
			n, Chapters.chapter_of(n), level.name.left(17), level.columns, level.rows, m["blocks"], m["spinners"], rules, m["locks"], m["hidden"],
			m["start_moves"], m["start_traps"], m["decision_points"], m["depth"], m["solution_length"],
			int(m["direction_share"] * 100), m["difficulty"],
			_imp(m["spinner_impact"], m["spinners"]), _imp(m["lock_impact"], m["locks"]), _imp(m["mystery_impact"], m["hidden"]),
			("yes" if m["mystery_fair"] else "NO") if m["hidden"] > 0 else "-", rwd, status, era2])
	if campaign:
		# Each Master Level is the hardest level of its era.
		for master in Chapters.master_levels():
			if not diffs.has(master):
				continue
			var era := Chapters.era_of(master)
			var top := 0.0
			for k in diffs:
				if k >= era["from"] and k <= era["to"]:
					top = maxf(top, diffs[k])
			if diffs[master] < top:
				problems.append("L%d (Master) is not the hardest level of the %s (%.1f < %.1f)" % [master, era["name"], diffs[master], top])
			# v0.6.2: and the hardest to REASON about (structural difficulty:
			# depth, decisions, traps, start traps, rams, switch decisions),
			# so its rank does not come from mechanic counts alone.
			var top_s := 0.0
			var top_n := 0
			for k in structs:
				if k != master and k >= era["from"] and k <= era["to"] and structs[k] > top_s:
					top_s = structs[k]
					top_n = k
			print("L%d (Master) structural difficulty %.1f; next: L%d %.1f" % [master, structs[master], top_n, top_s])
			if structs[master] <= top_s:
				problems.append("L%d (Master) is not the hardest to reason about in the %s (structural %.1f <= L%d %.1f)" % [master, era["name"], structs[master], top_n, top_s])
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
			if Chapters.era_of_chapter(c)["from"] == Chapters.chapter_range(c).x and c > 1:
				prev = -1.0  # a new era starts its own curve
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
	# v0.6 Second Era.
	if m["switches"] > 0 and n < 101:
		return "SWITCH BEFORE 101"
	if m["gates"] > 0 and n < 121:
		return "CHAIN GATE BEFORE 121"
	if m["armored"] > 0 and n < 161:
		return "ARMOR BEFORE 161"
	if m["switches"] > 0 and m["switch_impact"] < 1.0:
		return "SWITCH DECORATIVE"
	if m["gates"] > 0 and m["gate_impact"] < 1.0:
		return "GATE DECORATIVE"
	if m["armored"] > 0 and m["armor_impact"] < 1.0:
		return "ARMOR DECORATIVE"
	if n >= 101 and n <= 105:
		if m["switches"] == 0 or m["switch_impact"] < LevelAnalysis.ESSENTIAL:
			return "SWITCH LESSON NEEDS AN ESSENTIAL SWITCH"
		if m["start_moves"] > 3 or m["depth"] < 3:
			return "SWITCH LESSON SHAPE"
		return ""
	if n == 200:
		var kinds := int(m["rule_cw"] > 0) + int(m["rule_ccw"] > 0) + int(m["rule_alt"] > 0) + int(m["rule_pattern"] > 0)
		if kinds < 3 or m["locks"] == 0 or m["hidden"] == 0 or m["switches"] == 0 or m["gates"] == 0 or m["armored"] == 0:
			return "GRAND MASTER NEEDS EVERY MECHANIC FAMILY"
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
		if b.armored:
			return "REWARD ON ARMORED BLOCK"
		var cfg: Dictionary = Economy.config()["reward_blocks"].get(b.rarity_name(), {})
		if not bool(cfg.get("enabled", false)):
			return "DISABLED REWARD RARITY"
		if n < int(cfg.get("from_level", 0)):
			return "%s BLOCK BEFORE LEVEL %d" % [b.rarity_name().to_upper(), int(cfg["from_level"])]
	if count > (3 if Chapters.is_master(n) else 2):
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


## Empty if no order of taps can strand a shell; else the reason and one
## tap sequence into such a dead end (block ids, R = ram).
func _armor_issue(level: LevelData) -> String:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var r := Solver.from_model(model).armor_audit()
	if not r["complete"]:
		return "ARMOR AUDIT INCOMPLETE (%d states)" % r["states"]
	if r["armor_dead_ends"] == 0:
		return ""
	var taps := PackedStringArray()
	for mv in r["example"]:
		taps.append(("R" if mv & Solver.RAM else "") + str(mv & Solver.ID_MASK))
	return "ARMOR UNCRACKABLE: %d dead end(s) with an intact shell, e.g. taps %s" % [r["armor_dead_ends"], " ".join(taps)]
