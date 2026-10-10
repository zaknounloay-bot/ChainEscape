extends SceneTree
## Campaign verifier: real rules + Solver + LevelAnalysis, no rendering.
##
##   godot --headless --path . --script res://tools/verify_levels.gd
##   godot --headless --path . --script res://tools/verify_levels.gd -- --file=path/to/level.json
##   godot --headless --path . --script res://tools/verify_levels.gd -- --to=250   (checkpoint: 1..250)
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
##   * v0.7 Third Era, the PORTAL arc (201-225):
##       - portals only from 201
##       - every arc level uses a portal in its solution, and (except the
##         breathers 209 / 215 / 220) the portal changes how it is solved
##         (impact >= 1.0) - no decoration
##       - the Portal lessons 201-205 need the portal (unsolvable without),
##         may be small (<= 3 start moves, depth >= 3), and 201-204 use no
##         other mechanic; from 206 the late-game rules apply
##       - no mechanic stacking: at most two older mechanic families
##         (spinners, locks, mystery, switches, gates, armor) per level
##       - Level 225 (the arc's milestone) is the hardest level of the arc,
##         by difficulty AND by structural difficulty
##   * MAGNET arc 76-99 (80 and 90 unchanged): magnets only there, every
##     arc level pulls, the Magnet is necessary outside the breathers 85 / 97,
##     EVERY magnet can pull on at least one winning line (no inert magnets;
##     tools/magnet_pull_rule.gd - optional magnets are fine),
##     lessons 76-79 may be small, Level 98 is the arc's hardest; Chapter 8
##     starts its own curve (ARC_STARTS) and Chapter 9 is compared with
##     Chapter 8 on Magnet levels only (MAGNET_ARC_CHAPTER_CHECK)
##   * v0.8 Third Era arcs: SEQUENCE 226-250, MOVABLE 251-275, INTEGRATION
##     276-300 (ARCS below):
##       - Sequence blocks only from 226, Movable blocks only from 251
##       - every Sequence-arc level uses a first stage, every Movable-arc
##         level a push; every Integration level uses a Third Era mechanic
##       - every Portal / Sequence / Movable on a level matters (portal and
##         sequence impact >= 1.0; Movable: no win without pushing, or
##         impact >= 1.0) - except on the arc's breathers
##       - lessons (226-228, 251-254) may be small (<= 3 start moves, depth
##         >= 3); 226-227 use nothing else; Movable lessons need a push to
##         be won (and one spinner, the only way a last pusher can leave)
##       - no stacking: the arc's mechanic + at most 2 other families
##         (Integration: at most 4 families in all)
##       - 250 / 275 are the hardest levels of their arcs, 300 the hardest
##         of the whole Third Era (difficulty AND structural)
##       - a Chapter holding a new mechanic's first level (226, 251) starts
##         its own difficulty curve

const HIGH_LEVEL := 21
const LATE_LEVEL := 61
const MAX_SIMILARITY := 0.6
const MIN_CHAPTER_STEP := 2.0
const PORTAL_FROM := 201
const PORTAL_ARC_END := 225
const PORTAL_BREATHERS := [209, 215, 220]
## v0.8: the SEQUENCE arc (226-250), the MOVABLE arc (251-275) and the
## INTEGRATION arc (276-300). Each arc ends on a milestone that must be its
## hardest level; 300 must be the hardest level of the whole Third Era.
const SEQ_FROM := 226
const MOV_FROM := 251
const INTEGRATION_FROM := 276
const ERA3_END := 300
const ARCS := [
	{"from": 226, "to": 250, "mech": "sequence", "lessons": [226, 227, 228], "pure": [226, 227], "breathers": [235, 244]},
	# Movable lessons can't be "pure": the last arrow to push a Movable block
	# stays stuck behind it unless it can turn (the lab's rule consequence),
	# so each lesson has one plain clockwise spinner as its last pusher.
	{"from": 251, "to": 275, "mech": "movable", "lessons": [251, 252, 253, 254], "pure": [], "breathers": [258, 264, 270]},
	{"from": 276, "to": 300, "mech": "", "lessons": [], "pure": [], "breathers": [281, 287, 294]},
]
## Chapters that hold a new mechanic's first level start their own
## difficulty curve (like an era): the lessons are easier on purpose.
## Chapters that introduce a new mechanic start their own difficulty curve:
## Armor (151) and Twins (176) since the 1-300 freeze, then the Third Era arcs.
const ARC_STARTS := [76, 151, 176, 201, 226, 251]
## MAGNET arc (docs/magnet_campaign_plan.md, approved): 76-99 except the
## unchanged Mystery levels 80 and 90. Magnets only here; every arc level
## pulls; outside the breathers the Magnet is NECESSARY (no win with every
## magnet a plain arrow); the lessons 76-79 may be small (<= 3 start moves,
## depth >= 3); Level 98 is the arc's hardest level.
const MagnetPullRule := preload("res://tools/magnet_pull_rule.gd")
const MAGNET_FROM := 76
const MAGNET_TO := 99
const MAGNET_UNCHANGED := [80, 90]
const MAGNET_LESSONS := [76, 77, 78, 79]
const MAGNET_BREATHERS := [85, 97]
const MAGNET_HARDEST := 98
## MAGNET_ARC_CHAPTER_CHECK (approved, narrow): Chapter 9 is compared with
## Chapter 8 on their MAGNET levels only (76-79 vs 81-89). Chapter 8 mixes
## the unchanged pre-arc boards 71-75 and Level 80 (about 49.5 on average)
## with the gentle Magnet lessons, so its full average says nothing about the
## arc's curve. The step is the same MIN_CHAPTER_STEP; every other Chapter
## check (including C10 vs C9 on full averages) is unchanged.
const MAGNET_ARC_CHAPTER := 9
## Since the 1-300 freeze (docs/freeze_1_300.md): Armor from 151 (approved in
## the Experience Lab; production had 161) and TWINS only in 176-199.
const ARMOR_FROM := 151
const TWINS_FROM := 176
const TWINS_TO := 199
## The Twins learning boards (approved prototype boards A / B / C and Double
## Link): like the Switch lessons 101-105 they may be small.
const TWINS_LESSONS := [176, 177, 179, 184]
const TWINS_LESSON_MAX_START := 6
## The Elite Twins boards (187-197) were designed and validated with stronger
## measures than the start-move proxy (habit / look-ahead players inside the
## production Elite band, full state graphs: docs/twins_176_199_lab.md) and
## deliberately give more freedom: up to 6 opening moves (a pair counted
## once). Depth and decision rules still apply.
const TWINS_MAX_START := 6
## Human-approved Twins board whose SHOW A MOVE line crosses only one trap
## step (decision_points 1) although 54% of its winnable states hold a fatal
## option (full graph). Reported in docs/freeze_1_300.md.
const TWINS_DECISIONS_ACCEPTED := [190]
## Human-approved Twins board with 47% of its arrows in one direction (rule:
## 45%). Reported in docs/freeze_1_300.md.
const TWINS_DIRECTION_ACCEPTED := [187]
## Human-approved Twins boards whose locks measure as decorative (lock impact
## < 0.5). Reported in docs/freeze_1_300.md.
const TWINS_LOCKS_ACCEPTED := [190, 197]
## Human-approved Twins boards (iPhone playtest of Lab 176-200, commit 44db502)
## whose Chain Gate measures as decorative here (structural impact 0.0).
## Accepted by decision - "no further Twins redesign" - and reported as a known
## issue in docs/freeze_1_300.md; every other gate must still matter.
const TWINS_GATE_ACCEPTED := [187, 192, 197]


func _initialize() -> void:
	var files: Array = []
	var upto := 1 << 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="):
			files.append(a.get_slice("=", 1))
		elif a.begins_with("--to="):
			upto = int(a.get_slice("=", 1))  # campaign checkpoint: levels 1..N only
	var campaign := files.is_empty()
	if campaign:
		var n := 1
		while n <= upto and FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
			files.append(LevelManager.LEVEL_PATH % n)
			n += 1
	var problems: Array[String] = []
	var levels: Array = []
	print("  # C name               size blk spn rules  lck hid start trp dec dep len dir%  diff   S    L    M  fair rwd status")
	var diffs := {}
	var structs := {}
	for i in files.size():
		var json = JSON.parse_string(FileAccess.get_file_as_string(files[i]))
		var level := LevelManager.parse_level(json, i + 1, true)
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
			if issue == "" and m.get("magnets", 0) > 0:
				issue = _magnet_pull_issue(level)
			if issue == "":
				issue = _reward_issue(n, level)
			if issue != "":
				status = issue
				problems.append("L%d %s" % [n, issue])
		var rules := "c%da%dp%d" % [m["rule_ccw"], m["rule_alt"], m["rule_pattern"]] if m["spinners"] > 0 else "-"
		var era2 := ""
		if m["portal_pairs"] > 0:
			era2 += " po%d:%s mv%d" % [m["portal_pairs"], _imp(m["portal_impact"], m["portal_pairs"]), m["portal_moves"]]
		if m["sequence_blocks"] > 0:
			era2 += " sq%d:%s ad%d" % [m["sequence_blocks"], _imp(m["sequence_impact"], m["sequence_blocks"]), m["advances"]]
		if m["crates"] > 0:
			era2 += " mo%d:%s%s pu%d" % [m["crates"], _imp(m["movable_impact"], m["crates"]), "!" if m["push_essential"] else "", m["pushes"]]
		if m["switches"] + m["gates"] + m["armored"] > 0:
			era2 += " sw%d:%s gt%d:%s ar%d:%s" % [m["switches"], _imp(m["switch_impact"], m["switches"]), m["gates"], _imp(m["gate_impact"], m["gates"]),
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
	if campaign and diffs.has(PORTAL_ARC_END):
		# The Portal arc's milestone is its hardest level, both ways.
		var top_d := 0.0
		var top_s := 0.0
		var top_n := 0
		for k in range(PORTAL_FROM, PORTAL_ARC_END):
			top_d = maxf(top_d, diffs[k])
			if structs[k] > top_s:
				top_s = structs[k]
				top_n = k
		print("L%d (Portal milestone) difficulty %.1f structural %.1f; next structural: L%d %.1f" % [
			PORTAL_ARC_END, diffs[PORTAL_ARC_END], structs[PORTAL_ARC_END], top_n, top_s])
		if diffs[PORTAL_ARC_END] <= top_d or structs[PORTAL_ARC_END] <= top_s:
			problems.append("L%d is not the hardest level of the Portal arc" % PORTAL_ARC_END)
	if campaign:
		# v0.8: each arc's milestone is its hardest level (both ways); 300 is
		# the hardest level of the whole Third Era.
		for arc in ARCS:
			var last: int = arc["to"]
			if not diffs.has(last):
				continue
			var lo: int = PORTAL_FROM if last == ERA3_END else arc["from"]
			var top_d := 0.0
			var top_s := 0.0
			var top_n := 0
			for k in range(lo, last):
				if not diffs.has(k):
					continue
				top_d = maxf(top_d, diffs[k])
				if structs[k] > top_s:
					top_s = structs[k]
					top_n = k
			print("L%d (milestone) difficulty %.1f structural %.1f; next structural: L%d %.1f (from L%d)" % [last, diffs[last], structs[last], top_n, top_s, lo])
			if diffs[last] <= top_d or structs[last] <= top_s:
				problems.append("L%d is not the hardest level of levels %d-%d" % [last, lo, last])
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
			for a in ARC_STARTS:
				if a >= rg.x and a <= rg.y:
					prev = -1.0  # v0.8: so does a Chapter that introduces a new mechanic
			if c == MAGNET_ARC_CHAPTER and files.size() >= MAGNET_TO:
				# MAGNET_ARC_CHAPTER_CHECK: Magnet levels only (see above).
				var m8 := _arc_avg(diffs, Chapters.chapter_range(c - 1))
				var m9 := _arc_avg(diffs, rg)
				print("MAGNET_ARC_CHAPTER_CHECK: Chapter %d vs %d on Magnet levels only: %.1f vs %.1f (full averages %.1f vs %.1f)" % [c, c - 1, m9, m8, avg, prev])
				if m9 < m8 + MIN_CHAPTER_STEP:
					problems.append("Chapter %d Magnet-level average %.1f is not above Chapter %d's (%.1f) by %.1f" % [c, m9, c - 1, m8, MIN_CHAPTER_STEP])
			elif prev >= 0.0 and avg < prev + MIN_CHAPTER_STEP:
				problems.append("Chapter %d average difficulty %.1f is not above Chapter %d (%.1f) by %.1f" % [c, avg, c - 1, prev, MIN_CHAPTER_STEP])
			prev = avg
		print("Chapter difficulty: " + "  ".join(line))
		if files.size() >= MAGNET_TO:
			var arc_line := PackedStringArray()
			for c in [8, 9, 10]:
				arc_line.append("C%d %.1f" % [c, _arc_avg(diffs, Chapters.chapter_range(c))])
			print("Magnet-level averages (76-99 without 80 / 90): " + "  ".join(arc_line))
			# Level 98: the arc's hardest, by difficulty AND structural difficulty.
			var top_d := -1.0
			var top_s := -1.0
			for k in range(MAGNET_FROM, MAGNET_TO + 1):
				if k == MAGNET_HARDEST or MAGNET_UNCHANGED.has(k):
					continue
				top_d = maxf(top_d, diffs[k])
				top_s = maxf(top_s, structs[k])
			print("L%d (Magnet arc) difficulty %.1f structural %.1f; next: %.1f / %.1f" % [MAGNET_HARDEST, diffs[MAGNET_HARDEST], structs[MAGNET_HARDEST], top_d, top_s])
			if diffs[MAGNET_HARDEST] <= top_d or structs[MAGNET_HARDEST] <= top_s:
				problems.append("L%d is not the hardest Magnet level" % MAGNET_HARDEST)
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
	if m["armored"] > 0 and n < ARMOR_FROM:
		return "ARMOR BEFORE %d" % ARMOR_FROM
	if m.get("twins", 0) > 0 and (n < TWINS_FROM or n > TWINS_TO):
		return "TWINS OUTSIDE %d-%d" % [TWINS_FROM, TWINS_TO]
	var magnet := _magnet_issue(n, m)
	if magnet != "-":
		return magnet
	if m["switches"] > 0 and m["switch_impact"] < 1.0:
		return "SWITCH DECORATIVE"
	if m["gates"] > 0 and m["gate_impact"] < 1.0 and not TWINS_GATE_ACCEPTED.has(n):
		return "GATE DECORATIVE"
	if m["armored"] > 0 and m["armor_impact"] < 1.0:
		return "ARMOR DECORATIVE"
	# v0.8 Third Era: SEQUENCE, MOVABLE, INTEGRATION.
	if m.get("sequence_blocks", 0) > 0 and n < SEQ_FROM:
		return "SEQUENCE BEFORE %d" % SEQ_FROM
	if m.get("crates", 0) > 0 and n < MOV_FROM:
		return "MOVABLE BEFORE %d" % MOV_FROM
	var era3 := _era3_issue(n, m)
	if era3 != "-":
		return era3
	# v0.7 Third Era: the PORTAL arc.
	if m.get("portal_pairs", 0) > 0 and n < PORTAL_FROM:
		return "PORTAL BEFORE %d" % PORTAL_FROM
	if n >= PORTAL_FROM and n <= PORTAL_ARC_END:
		if m["portal_pairs"] == 0 or m["portal_moves"] == 0:
			return "PORTAL ARC LEVEL WITHOUT A PORTAL MOVE"
		if not PORTAL_BREATHERS.has(n) and m["portal_impact"] < 1.0:
			return "PORTAL DECORATIVE"
		var older := _older_families(m)
		if older > 2:
			return "MECHANIC STACKING (%d older mechanics)" % older
		if n <= PORTAL_FROM + 4:
			if m["portal_impact"] < LevelAnalysis.ESSENTIAL:
				return "PORTAL LESSON NEEDS AN ESSENTIAL PORTAL"
			if n <= PORTAL_FROM + 3 and older > 0:
				return "PORTAL LESSON MIXES MECHANICS"
			if m["start_moves"] > 3 or m["depth"] < 3:
				return "PORTAL LESSON SHAPE"
			return ""
	if n >= 101 and n <= 105:
		if m["switches"] == 0 or m["switch_impact"] < LevelAnalysis.ESSENTIAL:
			return "SWITCH LESSON NEEDS AN ESSENTIAL SWITCH"
		if m["start_moves"] > 3 or m["depth"] < 3:
			return "SWITCH LESSON SHAPE"
		return ""
	if n == ARMOR_FROM:
		# The approved Armor lesson (Lab 151): gentle on purpose, like the
		# Switch lessons - the shell must matter, the shape may be small.
		if m["armored"] == 0 or m["armor_impact"] < 1.0:
			return "ARMOR LESSON NEEDS A SHELL THAT MATTERS"
		return ""
	if TWINS_LESSONS.has(n):
		if m.get("twins", 0) == 0:
			return "TWINS LESSON WITHOUT TWINS"
		if m["start_moves"] > TWINS_LESSON_MAX_START:
			return "TWINS LESSON SHAPE"
		return ""
	if n == 200:
		var kinds := int(m["rule_cw"] > 0) + int(m["rule_ccw"] > 0) + int(m["rule_alt"] > 0) + int(m["rule_pattern"] > 0)
		if kinds < 3 or m["locks"] == 0 or m["hidden"] == 0 or m["switches"] == 0 or m["gates"] == 0 or m["armored"] == 0:
			return "GRAND MASTER NEEDS EVERY MECHANIC FAMILY"
	if n >= LATE_LEVEL:
		var twins: bool = m.get("twins", 0) > 0
		if m["start_moves"] > (TWINS_MAX_START if twins else 2):
			return "TOO MANY START MOVES (61+)"
		if m["depth"] < 8:
			return "TOO SHALLOW (61+)"
		if m["decision_points"] < 4 and not TWINS_DECISIONS_ACCEPTED.has(n):
			return "TOO FEW DECISIONS (61+)"
	if n == Chapters.master_level():
		var rule_kinds := int(m["rule_cw"] > 0) + int(m["rule_ccw"] > 0) + int(m["rule_alt"] > 0) + int(m["rule_pattern"] > 0)
		if rule_kinds < 3 or m["locks"] == 0 or m["hidden"] == 0:
			return "MASTER NEEDS SPINNER RULES + LOCKS + MYSTERY"
	if n >= HIGH_LEVEL:
		if m["start_moves"] > (TWINS_MAX_START if m.get("twins", 0) > 0 else 3):
			return "TOO MANY START MOVES"
		if m["depth"] < 5:
			return "TOO SHALLOW"
		if m["directions_used"] < 4 or (m["direction_share"] > 0.45 and not TWINS_DIRECTION_ACCEPTED.has(n)):
			return "ONE DIRECTION DOMINATES"
	if m["spinners"] > 0 and m["spinner_impact"] < 0.5:
		return "SPINNERS DECORATIVE"
	if m["locks"] > 0 and m["lock_impact"] < 0.5 and not TWINS_LOCKS_ACCEPTED.has(n):
		return "LOCKS DECORATIVE"
	if m["hidden"] > 0:
		if not m["mystery_fair"]:
			return "MYSTERY UNFAIR"
		if m["mystery_impact"] < 0.3:
			return "MYSTERY DECORATIVE"
	return ""


## MAGNET arc 76-99. "-" = keep checking (the usual late-game rules
## follow); "" = fine (a lesson: the late-game shape rules are skipped).
## Per magnet: each one must be able to pull on at least one winning line
## (tools/magnet_pull_rule.gd; it need not pull in every solution).
static func _magnet_pull_issue(level: LevelData) -> String:
	var dead := MagnetPullRule.inert(level)
	if dead.is_empty():
		return ""
	return "MAGNET AT %s NEVER PULLS ON A WINNING LINE" % ", ".join(dead.map(func(d): return "(%d,%d)" % [d["cell"].x, d["cell"].y]))


static func _magnet_issue(n: int, m: Dictionary) -> String:
	var in_arc := n >= MAGNET_FROM and n <= MAGNET_TO and not MAGNET_UNCHANGED.has(n)
	if m.get("magnets", 0) > 0 and not in_arc:
		return "MAGNET OUTSIDE %d-%d (80 and 90 excluded)" % [MAGNET_FROM, MAGNET_TO]
	if not in_arc:
		return "-"
	if m.get("magnets", 0) == 0:
		return "MAGNET ARC LEVEL WITHOUT A MAGNET"
	if m.get("pulls", 0) == 0:
		return "MAGNET NEVER PULLS"
	if m["hidden"] > 0:
		return "MAGNET WITH MYSTERY BLOCKS"
	if not MAGNET_BREATHERS.has(n) and m.get("magnet_impact", 0.0) < LevelAnalysis.ESSENTIAL:
		return "MAGNET NOT NECESSARY"
	if n in MAGNET_LESSONS:
		if m["start_moves"] > 3 or m["depth"] < 3:
			return "MAGNET LESSON SHAPE"
		if m["spinners"] > 0 and m["spinner_impact"] < 0.5:
			return "SPINNERS DECORATIVE"
		return ""
	return "-"


## v0.8 arcs 226-300. "-" = not an arc level (keep checking); "" = fine
## (lessons skip the late-game shape rules, as the Switch / Portal lessons).
static func _era3_issue(n: int, m: Dictionary) -> String:
	for arc in ARCS:
		if n < arc["from"] or n > arc["to"]:
			continue
		var breather: bool = n in arc["breathers"]
		var mech: String = arc["mech"]
		# Every Third Era mechanic on the level must matter (not on breathers).
		if not breather:
			if m["portal_pairs"] > 0 and (m["portal_moves"] == 0 or m["portal_impact"] < 1.0):
				return "PORTAL DECORATIVE"
			if m["sequence_blocks"] > 0 and m["sequence_impact"] < 1.0:
				return "SEQUENCE DECORATIVE"
			if m["crates"] > 0 and not m["push_essential"] and m["movable_impact"] < 1.0:
				return "MOVABLE DECORATIVE"
		if m["crates"] > 0 and m["pushes"] == 0:
			return "MOVABLE NEVER PUSHED"
		if m["portal_pairs"] > 0 and m["portal_moves"] == 0 and m["crate_portal_pushes"] == 0:
			return "PORTAL NEVER USED"
		var fams := _families(m)
		if mech == "sequence":
			if m["sequence_blocks"] == 0 or m["advances"] == 0:
				return "SEQUENCE ARC LEVEL WITHOUT A SEQUENCE MOVE"
		elif mech == "movable":
			if m["crates"] == 0 or m["pushes"] == 0:
				return "MOVABLE ARC LEVEL WITHOUT A PUSH"
			if n in arc["lessons"] and not m["push_essential"]:
				return "MOVABLE LESSON MUST NEED A PUSH"
		else:
			if m["portal_pairs"] + m["sequence_blocks"] + m["crates"] == 0:
				return "INTEGRATION LEVEL WITHOUT A THIRD ERA MECHANIC"
		# No stacking: the arc's own mechanic plus at most two others; the
		# integration arc at most four families in all.
		var others := fams.size() - (1 if mech != "" and fams.has(mech) else 0)
		if mech != "" and others > 2:
			return "MECHANIC STACKING (%s)" % ",".join(fams)
		if mech == "" and fams.size() > 4:
			return "MECHANIC STACKING (%s)" % ",".join(fams)
		if n in arc["pure"] and fams.size() > 1:
			return "LESSON MIXES MECHANICS (%s)" % ",".join(fams)
		if n in arc["lessons"]:
			if m["start_moves"] > 3 or m["depth"] < 3:
				return "LESSON SHAPE"
			return ""
		return "-"
	return "-"


## Average difficulty of a Chapter's Magnet-arc levels (80 / 90 excluded).
static func _arc_avg(diffs: Dictionary, rg: Vector2i) -> float:
	var sum := 0.0
	var cnt := 0
	for k in range(rg.x, rg.y + 1):
		if k >= MAGNET_FROM and k <= MAGNET_TO and not MAGNET_UNCHANGED.has(k) and diffs.has(k):
			sum += diffs[k]
			cnt += 1
	return sum / maxf(cnt, 1)


## Mechanic families on a level (for the no-stacking rules).
static func _families(m: Dictionary) -> Array:
	var out := []
	for pair in [["spinner", m["spinners"]], ["lock", m["locks"]], ["mystery", m["hidden"]], ["switch", m["switches"]],
			["gate", m["gates"]], ["armor", m["armored"]], ["portal", m.get("portal_pairs", 0)],
			["sequence", m.get("sequence_blocks", 0)], ["movable", m.get("crates", 0)]]:
		if pair[1] > 0:
			out.append(pair[0])
	return out


## Older mechanic families on a level (the Portal arc allows two).
static func _older_families(m: Dictionary) -> int:
	return int(m["spinners"] > 0) + int(m["locks"] > 0) + int(m["hidden"] > 0) + int(m["switches"] > 0) \
		+ int(m["gates"] > 0) + int(m["armored"] > 0)


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
	model.set_portals(level.portals)
	var r := Solver.from_model(model).armor_audit()
	if not r["complete"]:
		return "ARMOR AUDIT INCOMPLETE (%d states)" % r["states"]
	if r["armor_dead_ends"] == 0:
		return ""
	var taps := PackedStringArray()
	for mv in r["example"]:
		taps.append(("R" if mv & Solver.RAM else "") + str(mv & Solver.ID_MASK))
	return "ARMOR UNCRACKABLE: %d dead end(s) with an intact shell, e.g. taps %s" % [r["armor_dead_ends"], " ".join(taps)]
