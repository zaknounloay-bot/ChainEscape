extends Node
## PLAYER EXPERIENCE LAB 1-200 checks (developer page ?experiencelab).
##   godot --headless --path . res://tools/ExperienceLabCheck.tscn
##
## Static:
## - URL parsing: ?experiencelab=reset / =1, next to itch.io's ?v=, in the
##   hash, URL-encoded; never on look-alike keys or =0.
## - Off by default: production paths / keys / level dir untouched.
## - Data: exactly level_01..level_100 (+ manifest), each equal to its
##   source (Opening Lab / production board + the listed token edits),
##   unique names, 1-10 equal to the Opening Lab.
## - Every level solvable; mechanic introductions at the lab points
##   (spinner 6, hidden 8, lock 13, CCW 31, alternating 41, pattern 51) with
##   their hint texts; every adapted spinner rule can actually show (its
##   distinguishing turn is reachable).
## - New Levels 16 and 20 (every reachable state): every losing move shows
##   within 3 moves (Undo reach), no move that turns nothing ever loses,
##   a 4-move look-ahead player wins, SHOW A MOVE legal and solvable,
##   Hammer safety exact.
## - All 100 levels, sampled states: SHOW A MOVE legal and solvable; Hammer
##   safety exact.
## Game (real scene, lab active, isolated save):
## - Each Level 1-200 loads its lab board, hearts from 6, SHOW A MOVE, Undo
##   exact, Restart exact, Hammer refuses unsafe smashes, clears by taps;
##   Chapter cards at 10, 20 ... 200; Lab 100 goes on to Lab 101; NEXT goes
##   110 -> 111, 120 -> 121, 121 -> 122, 129 -> 130, 130 -> 131,
##   139 -> 140, 149 -> 150 -> 151 -> 152, 159 -> 160 -> 161,
##   169 -> 170 -> 171, 174 -> 175 -> 176, 179 -> 180, 189 -> 190,
##   199 -> 200; after 200 (a temporary lab boundary): the Chapter 20 card,
##   then the end-of-test-build screen, never Level 201; Level Select lists
##   1-200 only.
## - Switch ramp 102-105 on the full state graph (_switch_ramp).
## - Lab 101 and 106-200 are production boards, unchanged; Lab 131 differs
##   only by its corrected hint; 151-170 are production 151-170 interleaved
##   (Armor from 151) and Lab 151 is production 161 with one adapted token
##   (_production_era). Armor lesson at Lab 151 (_armor_lesson); Chapter
##   card "NEW: Armored Blocks" before Chapter 16.
## - Lab 200: production's Grand Master - board, theme, music, celebration,
##   GRAND MASTER! card, the one-time 600-coin bonus (never on a replay)
##   (_grand_master).
## - Lab 121 runs production's Chain Gate lesson unchanged (_gate_lesson);
##   Lab 125 is production behaviour with no lesson, hint, finger or extra
##   feedback: its gate counters only count down (_gate_125).
## - Save isolation: the production save and the Opening Lab save are
##   byte-identical before and after.

var game: GameManager
var failures: Array[String] = []
var passed := 0
var _prod_before := ""
var _olab_before := ""


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		print("FAIL: " + what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	_parsing()
	_defaults()
	_data()
	for n in [16, 20]:
		_new_level_fairness(n)
	_alternating_onboarding()
	_pattern_onboarding()
	_switch_ramp()
	_production_era()
	_twins_era()
	for n in range(1, ExperienceLab.LAST_LEVEL + 1):
		_sampled_tools(n)
	await _game()
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("EXPERIENCE LAB CHECKS PASSED" if failures.is_empty() else "EXPERIENCE LAB CHECKS FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


## The lab's production sources: production 1-200 as they were before the
## 1-300 freeze (data/dev/pre_freeze_production), 201+ unchanged. Since the
## freeze, levels/ 1-200 ARE the lab (checked in _frozen).
const PRE_FREEZE_DIR := "res://data/dev/pre_freeze_production"


static func src_path(n: int) -> String:
	# The 22 Magnet levels (76-99 without 80 / 90) are production's own boards
	# (tools/experience_lab_build.py prod_path): the lab mirrors levels/.
	if n >= 76 and n <= 99 and n != 80 and n != 90:
		return LevelManager.LEVEL_PATH % n
	return PRE_FREEZE_DIR.path_join("level_%02d.json" % n) if n <= 200 else LevelManager.LEVEL_PATH % n


static func src_level(n: int) -> LevelData:
	var keep := LevelManager.dev_twins
	LevelManager.dev_twins = true
	var lv := LevelManager.parse_level(JSON.parse_string(FileAccess.get_file_as_string(src_path(n))), n, true)
	LevelManager.dev_twins = keep
	return lv


static func lab_level(n: int) -> LevelData:
	var json = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("level_%02d.json" % n)))
	var keep := LevelManager.dev_twins
	LevelManager.dev_twins = true  # the lab's own files may carry Twins (176-199)
	var lv := LevelManager.parse_level(json, n, true)
	LevelManager.dev_twins = keep
	return lv


static func model_of(level: LevelData) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals(level.portals)
	return m


# --- Parsing / defaults ---------------------------------------------------------

func _parsing() -> void:
	var cases := [
		["?experiencelab=reset", "", "reset"], ["?experiencelab=1", "", "1"],
		["?v=123456&experiencelab=reset", "", "reset"], ["?v=123456&experiencelab=1", "", "1"],
		["?experiencelab=reset&v=9", "", "reset"], ["", "#experiencelab=reset", "reset"],
		["?EXPERIENCELAB=Reset", "", "reset"], ["?experiencelab", "", "1"], ["?experiencelab=true", "", "1"],
		["?v=1&experience%6Cab=1", "", "1"], ["?v=123456", "", ""], ["", "", ""],
		["?xexperiencelab=1", "", ""], ["?experiencelab=0", "", ""], ["?experiencelabs=1", "", ""],
		["?openinglab=reset", "", ""], ["?v=1&experiencelab=1&experiencelab=reset", "", "reset"],
		# QA jump: 2..300 opens that level (since the 1-300 freeze: production
		# Levels 1-300); anything else keeps the old meaning.
		["?experiencelab=13", "", "13"], ["?v=123456&experiencelab=41", "", "41"], ["?experiencelab=2", "", "2"],
		["?experiencelab=100", "", "100"], ["?v=1&experiencelab=50&x=2", "", "50"], ["", "#experiencelab=75", "75"],
		["?experiencelab=101", "", "101"], ["?experiencelab=110", "", "110"], ["?experiencelab=111", "", "111"],
		["?v=123456&experiencelab=121", "", "121"], ["?experiencelab=125", "", "125"], ["?experiencelab=130", "", "130"], ["?experiencelab=131", "", "131"],
		["?v=123456&experiencelab=140", "", "140"], ["?experiencelab=144", "", "144"], ["?experiencelab=150", "", "150"], ["?experiencelab=153", "", "153"],
		["?experiencelab=156", "", "156"], ["?v=1&experiencelab=160", "", "160"], ["?experiencelab=161", "", "161"],
		["?experiencelab=151", "", "151"], ["?experiencelab=170", "", "170"], ["?v=123456&experiencelab=175", "", "175"], ["?experiencelab=176", "", "176"],
		["?experiencelab=183", "", "183"], ["?v=123456&experiencelab=200", "", "200"], ["?experiencelab=201", "", "201"], ["?v=1&experiencelab=250", "", "250"], ["?experiencelab=300", "", "300"], ["?experiencelab=301", "", ""], ["?experiencelab=-5", "", ""], ["?experiencelab=13abc", "", ""],
		["?v=1&experiencelab=13&experiencelab=reset", "", "reset"],
	]
	for c in cases:
		var got := ExperienceLab.parse_mode(c[0], c[1])
		_check(got == c[2], "parse_mode(%s %s) = '%s' (want '%s')" % [c[0], c[1], got, c[2]])
	# QA session restart: &qareset=1 (exact key, any order, itch.io's ?v=).
	for c in [["?experiencelab=250&qareset=1", true], ["?v=1&qareset=1&experiencelab=50", true], ["?qareset", true], ["#qareset=yes", true],
			["?experiencelab=250", false], ["?qareset=0", false], ["?xqareset=1", false], ["?qaresets=1", false]]:
		var search: String = c[0] if not String(c[0]).begins_with("#") else ""
		var got := ExperienceLab.parse_qa_reset(search, c[0] if search == "" else "")
		_check(got == c[1], "parse_qa_reset(%s) = %s (want %s)" % [c[0], got, c[1]])


func _defaults() -> void:
	_check(not ExperienceLab.active and not OpeningLab.active and LevelManager.override_dir == "", "labs are off unless asked for")
	_check(PlayerProgress.default_path == "user://progress.cfg" and PlayerProgress.mirror_key == "chain_escape_save" and PlayerProgress.beacon_key == "chain_escape_beacon",
		"production save path and Web keys unchanged by default")
	var lm := LevelManager.new()
	lm._ready()
	_check(lm.level_count == 300, "300 production levels (%d)" % lm.level_count)
	_check(_rule_visual_kinds() == [BlockData.SpinRule.ALT, BlockData.SpinRule.PATTERN], "since the freeze the game draws Alternating / Pattern spinners with the approved symbols (%s)" % [_rule_visual_kinds()])
	_frozen()
	for n in [1, 11, 16, 20, 50, 100, 101, 111, 121, 125, 130, 131, 150, 151, 160, 161, 170, 175]:
		var a := LevelManager.to_json_text(lm.load_level(n))
		var b := LevelManager.to_json_text(LevelManager.read_level(n))
		_check(a == b, "without the lab, Level %d is production" % n)
	lm.free()


# --- The 1-300 freeze (docs/freeze_1_300.md) ---------------------------------------

## Production 1-200 are the approved lab levels, byte for byte; 201-300 are
## untouched production (the archive covers 1-200 only).
func _frozen() -> void:
	var same := 0
	for n in range(1, 201):
		var a := FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n)
		var b := FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("level_%02d.json" % n))
		if a == b and a != "":
			same += 1
	_check(same == 200, "production levels 1-200 are the approved lab levels byte for byte (%d / 200)" % same)
	_check(not FileAccess.file_exists(PRE_FREEZE_DIR.path_join("level_201.json")), "the pre-freeze archive holds 1-200 only")


# --- Data -------------------------------------------------------------------------

func _data() -> void:
	var files := Array(DirAccess.get_files_at(ExperienceLab.LEVEL_DIR)).filter(func(f): return f.ends_with(".json"))
	var want := ["manifest.json"]
	for n in range(1, ExperienceLab.LAST_LEVEL + 1):
		want.append("level_%02d.json" % n)
	files.sort()
	want.sort()
	_check(files == want, "exactly level_01..level_%d + manifest (%d files)" % [ExperienceLab.LAST_LEVEL, files.size()])
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("manifest.json")))
	var entries: Array = manifest["levels"]
	_check(entries.size() == ExperienceLab.LAST_LEVEL, "manifest has %d entries" % ExperienceLab.LAST_LEVEL)
	var names := {}
	var first := {}
	for e in entries:
		var n: int = int(e["level"])
		var lv := lab_level(n)
		_check(lv != null and lv.blocks.size() > 0, "L%d parses" % n)
		# Unique - except on an unchanged production board of 101+ whose name
		# production itself already uses (e.g. 62 / 115 "Afterglow").
		var prod_repeat: bool = n > 100 and e["source"] == "production P%d" % n and e["edits"].is_empty() and e["rename"] == null and e["hint"] == null
		_check(not names.has(lv.name) or prod_repeat, "L%d name '%s' is unique" % [n, lv.name])
		names[lv.name] = n
		# Equal to its source + edits.
		var src: String = e["source"]
		var src_json: Dictionary
		if src.begins_with("Opening Lab"):
			src_json = JSON.parse_string(FileAccess.get_file_as_string(OpeningLab.LEVEL_DIR.path_join("level_%02d.json" % n)))
		elif src.begins_with("production P"):
			src_json = JSON.parse_string(FileAccess.get_file_as_string(src_path(int(src.substr(12)))))
		elif src.begins_with("Twins prototype "):
			src_json = JSON.parse_string(FileAccess.get_file_as_string(TwinsPrototype.LEVEL_DIR.path_join("level_%02d.json" % int(src.substr(16)))))
			src_json.erase("hearts")  # prototype-only keys, equal to the lab defaults
			src_json.erase("hints")
		if not src_json.is_empty():
			var grid := []
			for row in src_json["map"]:
				grid.append(Array(String(row).split(" ", false)))
			for ed in e["edits"]:
				var c: int = int(ed["cell"][0])
				var r: int = int(ed["cell"][1])
				_check(grid[r][c] == ed["from"], "L%d edit at (%d,%d) starts from %s" % [n, c, r, ed["from"]])
				grid[r][c] = ed["to"]
			var expect := src_json.duplicate(true)
			expect["map"] = grid.map(func(row): return " ".join(row))
			if e.get("hint") != null:
				var from = e["hint"]["from"]
				_check(src_json.get("hint", "") == (from if from != null else ""), "L%d hint override source" % n)
				expect["hint"] = e["hint"]["to"]
				if from == null:
					expect["hint_finger"] = false
			if e["rename"] != null:
				_check(src_json["name"] == e["rename"]["from"], "L%d rename source name" % n)
				expect["name"] = e["rename"]["to"]
			LevelManager.dev_twins = true
			var want_lv := LevelManager.parse_level(expect, n, true)
			LevelManager.dev_twins = false
			_check(LevelManager.to_json_text(want_lv) == LevelManager.to_json_text(lv) and want_lv.hint == lv.hint and want_lv.mystery == lv.mystery,
				"L%d equals %s%s" % [n, src, " + edits" if not e["edits"].is_empty() else ""])
		# Solvable.
		var s := Solver.from_model(model_of(lv))
		s.node_limit = 3000000
		_check(not s.solve().is_empty(), "L%d solvable" % n)
		# First appearance of each mechanic.
		var feats := {"spinner": lv.blocks.any(func(b): return b.is_spinner()), "hidden": lv.blocks.any(func(b): return b.hidden),
			"lock": lv.blocks.any(func(b): return b.lock_color != ""),
			"ccw": lv.blocks.any(func(b): return b.is_spinner() and b.spin_rule == BlockData.SpinRule.CCW),
			"alt": lv.blocks.any(func(b): return b.is_spinner() and b.spin_rule == BlockData.SpinRule.ALT),
			"pattern": lv.blocks.any(func(b): return b.is_spinner() and b.spin_rule == BlockData.SpinRule.PATTERN),
			"twins": lv.blocks.any(func(b): return b.twin != "")}
		for k in feats:
			if feats[k] and not first.has(k):
				first[k] = n
		if n <= 100:
			var other := lv.blocks.filter(func(b): return b.is_switch() or b.flip_link != "" or b.is_gate() or b.armored or b.is_crate() or b.seq_stage != 0)
			_check(other.is_empty() and lv.portals.is_empty(), "L%d uses only First Era mechanics" % n)
		elif n <= 120:
			# Lab 101-120: the Switch era - Switch/Flip and nothing newer.
			var other := lv.blocks.filter(func(b): return b.is_gate() or b.armored or b.is_crate() or b.seq_stage != 0)
			_check(other.is_empty() and lv.portals.is_empty() and lv.blocks.any(func(b): return b.is_switch()), "L%d is a Switch level with no newer mechanic" % n)
		elif n <= 130:
			# Lab 121-130: the production Chain Gate levels - nothing newer.
			var other := lv.blocks.filter(func(b): return b.armored or b.is_crate() or b.seq_stage != 0)
			_check(other.is_empty() and lv.portals.is_empty() and lv.blocks.any(func(b): return b.is_gate()), "L%d is a Chain Gate level with no newer mechanic" % n)
		elif n <= 150:
			# Lab 131-150: production Switch (+ Gate) levels - never Armored.
			var other := lv.blocks.filter(func(b): return b.armored or b.is_crate() or b.seq_stage != 0)
			_check(other.is_empty() and lv.portals.is_empty() and lv.blocks.any(func(b): return b.is_switch()), "L%d is a Switch / Gate level with no newer mechanic" % n)
		elif n <= 170:
			# Lab 151-170: Armor levels (Armor, spinners, locks only) and
			# Switch levels, interleaved - never both, nothing newer.
			var newer := lv.blocks.filter(func(b): return b.is_crate() or b.seq_stage != 0)
			var armor := lv.blocks.any(func(b): return b.armored)
			var sw := lv.blocks.any(func(b): return b.is_switch() or b.is_gate())
			_check(newer.is_empty() and lv.portals.is_empty() and armor != sw, "L%d is an Armor level or a Switch level (armor %s, switch/gate %s)" % [n, armor, sw])
		elif n <= 175:
			# Lab 171-175: production Armor + Switch + Gate levels.
			var newer := lv.blocks.filter(func(b): return b.is_crate() or b.seq_stage != 0)
			_check(newer.is_empty() and lv.portals.is_empty() and lv.blocks.any(func(b): return b.armored), "L%d combines Armor with older mechanics, nothing newer" % n)
		else:
			# Lab 176-200: Second Era expert levels and the lab's TWINS - never a
			# Third Era mechanic (Portal, Sequence, Movable); Twins only in
			# their planned slots (never 200).
			var newer := lv.blocks.filter(func(b): return b.is_crate() or b.seq_stage != 0)
			_check(newer.is_empty() and lv.portals.is_empty(), "L%d uses only Second Era mechanics (+ Twins)" % n)
		var has_twins := lv.blocks.any(func(b): return b.twin != "")
		_check(has_twins == (n in TWINS_LEVELS), "L%d %s Twins" % [n, "has" if n in TWINS_LEVELS else "has no"])
		if lv.blocks.any(func(b): return b.armored) and not first.has("armor"):
			first["armor"] = n
	var want_first := {"spinner": 6, "hidden": 8, "lock": 13, "ccw": 31, "alt": 41, "pattern": 51, "armor": 151, "twins": 176}
	for k in want_first:
		_check(first.get(k, -1) == want_first[k], "%s first appears at Lab %d (%d)" % [k, want_first[k], first.get(k, -1)])
	# The intro hints travel with their boards.
	var hints := {6: "Spinners turn", 8: "Hidden arrows", 13: "A lock opens", 31: "Ring arrows", 41: "alternates", 51: "follows a pattern"}
	for n in hints:
		_check(lab_level(n).hint.contains(hints[n]), "Lab %d keeps its intro hint ('%s')" % [n, lab_level(n).hint])
	for n in range(1, ExperienceLab.LAST_LEVEL + 1):
		if not hints.has(n):
			for h in hints.values():
				_check(not lab_level(n).hint.contains(h), "intro hint '%s' only at its intro level (L%d)" % [h, n])
	# Adapted spinner rules can show (their distinguishing turn is reachable).
	for e in entries:
		for ed in e["edits"]:
			var n: int = int(e["level"])
			var to: String = ed["to"]
			if not to.contains("@"):
				continue  # a plain arrow (e.g. Lab 51's new neighbour), not a spinner rule
			var need := 1 if to.contains("@-") else (2 if to.contains("@~") else (3 if to.contains("@*") else 1))
			var lv := lab_level(n)
			var wid := -1
			for b in lv.blocks:
				if b.cell == Vector2i(int(ed["cell"][0]), int(ed["cell"][1])):
					wid = b.id
			var st := {"max": 0}
			_turns(Solver.from_model(model_of(lv)), wid, {}, st)
			_check(st["max"] >= need, "L%d adapted spinner %s can make its distinguishing turn (%d of %d)" % [n, to, st["max"], need])


func _turns(s: Solver, wid: int, seen: Dictionary, st: Dictionary) -> void:
	var k := s._key()
	if seen.has(k) or seen.size() > 200000:
		return
	seen[k] = true
	if s._alive[wid] == 1:
		st["max"] = maxi(st["max"], s._step[wid])
	for mv in s.legal_moves():
		s._do(mv)
		_turns(s, wid, seen, st)
		s._undo_move(mv)


# --- New levels: human-solvability rules on every reachable state -------------

## Lab 41 teaches Alternating through play: on the solution its
## Alternating spinner turns clockwise, then counter-clockwise, and only
## then leaves (the full state-graph audit is in the docs).
func _alternating_onboarding() -> void:
	var lv := lab_level(41)
	var m := model_of(lv)
	var alt := -1
	for b in m.blocks.values():
		if b.is_spinner() and b.spin_rule == BlockData.SpinRule.ALT:
			alt = b.id
	_check(alt != -1, "Lab 41 has an Alternating spinner")
	var dirs := []
	for id in Solver.from_model(m).solve():
		var cw: bool = m.blocks[alt].next_turn_cw() if m.blocks.has(alt) else false
		for t in m.remove(id):
			if t == alt:
				dirs.append("CW" if cw else "CCW")
	_check(dirs == ["CW", "CCW"], "Lab 41: its Alternating spinner turns CW then CCW on the solution (%s)" % [dirs])
	_check(m.is_empty(), "Lab 41 solution clears the board")


## Lab 51 teaches Pattern through play: on the solution its Pattern
## spinner turns right, right, then left - and only then leaves.
func _pattern_onboarding() -> void:
	var m := model_of(lab_level(51))
	var pat := -1
	for b in m.blocks.values():
		if b.is_spinner() and b.spin_rule == BlockData.SpinRule.PATTERN:
			pat = b.id
	_check(pat != -1, "Lab 51 has a Pattern spinner")
	var dirs := []
	var exit_step := -1
	for id in Solver.from_model(m).solve():
		if id == pat:
			exit_step = m.blocks[pat].spin_step
		var cw: bool = m.blocks[pat].next_turn_cw() if m.blocks.has(pat) else false
		for t in m.remove(id):
			if t == pat:
				dirs.append("CW" if cw else "CCW")
	_check(dirs == ["CW", "CW", "CCW"] and exit_step == 3, "Lab 51: its Pattern spinner turns CW, CW, CCW, then leaves (%s, left after %d)" % [dirs, exit_step])
	_check(m.is_empty(), "Lab 51 solution clears the board")


## Switch ramp (Lab 102-105), checked on the full state graph of each board:
## every reachable position, every move, every winning path.
func _switch_graph(blocks: Array, rows: int, cols: int) -> Dictionary:
	var m := BoardModel.new()
	m.setup(rows, cols, blocks)
	var dir0 := {}
	for b in m.blocks.values():
		dir0[b.id] = b.direction
	var key := func(mm: BoardModel) -> String:
		var ids: Array = mm.blocks.keys()
		ids.sort()
		return ",".join(PackedStringArray(ids.map(func(i): return "%d:%d:%d" % [i, mm.blocks[i].direction, mm.blocks[i].spin_step])))
	var k0: String = key.call(m)
	var st := {k0: {"snap": m.snapshot(), "kids": [], "empty": false, "ids": m.blocks.keys()}}
	var order := [k0]
	var i := 0
	while i < order.size():
		var k: String = order[i]
		i += 1
		m.restore(st[k]["snap"])
		for id in m.playable_ids():
			m.restore(st[k]["snap"])
			if not m.can_escape(id):
				continue
			var b: BlockData = m.blocks[id]
			var before := {}
			for o in m.blocks.values():
				before[o.id] = o.direction
			var mv := {"id": id, "switch": b.switch_group, "reversed": b.direction != dir0[id] and not b.is_spinner(), "changed": []}
			m.remove(id)
			for o in m.blocks.values():
				if o.direction != before[o.id] and not o.is_spinner():
					mv["changed"].append(o.id)
			var nk: String = key.call(m)
			mv["to"] = nk
			st[k]["kids"].append(mv)
			if not st.has(nk):
				st[nk] = {"snap": m.snapshot(), "kids": [], "empty": m.is_empty(), "ids": m.blocks.keys()}
				order.append(nk)
	var ways := {}
	var longest := {}
	for idx in range(order.size() - 1, -1, -1):
		var k: String = order[idx]
		var w := 1 if st[k]["empty"] else 0
		var lg := 0
		for c in st[k]["kids"]:
			w += ways[c["to"]]
			lg = maxi(lg, 1 + longest[c["to"]])
		ways[k] = w
		longest[k] = lg
	return {"st": st, "order": order, "ways": ways, "longest": longest, "k0": k0, "model": m}


func _id_at(lv: LevelData, cell: Vector2i) -> int:
	for b in lv.blocks:
		if b.cell == cell:
			return b.id
	return -1


## Winning moves only: every transition from a winnable state into a winnable state.
func _winning_moves(g: Dictionary) -> Array:
	var out := []
	for k in g["order"]:
		if g["ways"][k] == 0:
			continue
		for c in g["st"][k]["kids"]:
			if g["ways"][c["to"]] > 0:
				out.append([k, c])
	return out


func _solvable_without(lv: LevelData, flip_ids: Array, groups: Array) -> bool:
	var nb := []
	for b in lv.blocks:
		var c: BlockData = b.duplicate_data()
		if c.id in flip_ids:
			c.flip_link = ""
		if c.switch_group in groups:
			c.switch_group = ""
		nb.append(c)
	var g := _switch_graph(nb, lv.rows, lv.columns)
	return g["ways"][g["k0"]] > 0


func _switch_ramp() -> void:
	for n in [102, 103, 104, 105]:
		var lv := lab_level(n)
		var g := _switch_graph(lv.blocks, lv.rows, lv.columns)
		var ways: Dictionary = g["ways"]
		var k0: String = g["k0"]
		_check(ways[k0] > 0, "L%d winnable" % n)
		var worst := 0
		var losing := []
		var first_bad := 0
		for k in g["order"]:
			if ways[k] == 0:
				continue
			for c in g["st"][k]["kids"]:
				if ways[c["to"]] == 0:
					losing.append(c)
					worst = maxi(worst, g["longest"][c["to"]] + 1)
					if k == k0:
						first_bad += 1
		_check(first_bad == 0, "L%d: no losing first move" % n)
		_check(worst <= 3, "L%d: every mistake is recoverable within 3 Undos (worst %d)" % [n, worst])
		# A switch reverses exactly the arrows carrying its own mark.
		var only_own := true
		for k in g["order"]:
			for c in g["st"][k]["kids"]:
				var gname: String = c["switch"]
				var want := []
				g["model"].restore(g["st"][k]["snap"])
				if gname != "":
					for o in g["model"].blocks.values():
						if o.flip_link == gname:
							want.append(o.id)
				var got: Array = c["changed"].duplicate()
				want.sort()
				got.sort()
				if got != want:
					only_own = false
		_check(only_own, "L%d: each switch reverses exactly the arrows with its own mark, nothing else" % n)
		var wins := _winning_moves(g)
		match n:
			102:
				var marked := _id_at(lv, Vector2i(1, 0))
				var twin := _id_at(lv, Vector2i(2, 0))
				var ok_marked := wins.all(func(e): return e[1]["id"] != marked or e[1]["reversed"])
				var ok_twin := wins.all(func(e): return e[1]["id"] != twin or not e[1]["reversed"])
				var twin_seen := wins.all(func(e): return e[1]["switch"] == "" or twin in g["st"][e[0]]["ids"])
				_check(ok_marked, "L102: the marked arrow escapes reversed on every winning path")
				_check(ok_twin, "L102: the unmarked twin never reverses")
				_check(twin_seen, "L102: the twin is still on the board whenever the switch fires (the contrast is always seen)")
			103:
				var p1 := _id_at(lv, Vector2i(0, 0))
				var p2 := _id_at(lv, Vector2i(0, 3))
				for id in [p1, p2]:
					_check(wins.all(func(e): return e[1]["id"] != id or e[1]["reversed"]), "L103: marked arrow %d escapes reversed on every winning path" % id)
				# The face-off: neither purple can leave until the switch turns them
				# (the switch is required); one reversal alone would already break
				# it, but both always turn together and both leave reversed.
				_check(not _solvable_without(lv, [], ["A"]), "L103: switch A is required (the purple face-off has no other way out)")
				var both := wins.all(func(e): return e[1]["switch"] == "" or (e[1]["changed"].has(p1) and e[1]["changed"].has(p2)))
				_check(both, "L103: the one switch turns BOTH marked arrows at once")
			104:
				var purple := _id_at(lv, Vector2i(2, 3))
				var sw_early_lose := true
				var sw_late_ok := false
				var visible := true
				for k in g["order"]:
					if ways[k] == 0:
						continue
					for c in g["st"][k]["kids"]:
						if c["switch"] == "":
							continue
						if purple in g["st"][k]["ids"]:
							sw_early_lose = sw_early_lose and ways[c["to"]] == 0
							# Visible at once: the purple now points DOWN at the red arrow, which points UP at it.
							g["model"].restore(g["st"][c["to"]]["snap"])
							var pb: BlockData = g["model"].blocks.get(purple)
							var red: BlockData = g["model"].block_at(Vector2i(2, 4))
							visible = visible and pb != null and pb.direction == Direction.DOWN and red != null and red.direction == Direction.UP
						elif ways[c["to"]] > 0:
							sw_late_ok = true
				_check(sw_early_lose, "L104: firing the switch while the purple is still there always loses")
				_check(sw_late_ok, "L104: firing it after the purple left wins")
				_check(visible, "L104: the early mistake shows at once (purple and red face each other head-on)")
				_check(losing.all(func(c): return c["switch"] != ""), "L104: the early switch is the only kind of mistake")
				_check(wins.all(func(e): return e[1]["id"] != purple or not e[1]["reversed"]), "L104: the purple always leaves unreversed (before the switch)")
			105:
				_check(not _solvable_without(lv, [], ["A"]), "L105: switch A is required")
				_check(not _solvable_without(lv, [], ["B"]), "L105: switch B is required")
				for cell in [Vector2i(2, 0), Vector2i(3, 3)]:
					var id := _id_at(lv, cell)
					_check(wins.all(func(e): return e[1]["id"] != id or e[1]["reversed"]), "L105: marked arrow at %s escapes reversed on every winning path" % cell)


func _new_level_fairness(n: int) -> void:
	var lv := lab_level(n)
	var s := Solver.from_model(model_of(lv))
	var win := {}
	_explore(s, win)
	# Walk every reachable state again, checking each move (win[] filled).
	var seen := {}
	var res := {"fatal": 0, "deep": 0, "calm": 0, "hint_bad": 0, "hammer_bad": 0, "states": 0}
	_check_walk(s, win, seen, res, model_of(lv))
	_check(res["deep"] == 0, "L%d: every losing move shows within 3 moves (%d of %d do not)" % [n, res["deep"], res["fatal"]])
	_check(res["calm"] == 0, "L%d: a move that turns nothing never loses" % n)
	_check(res["hint_bad"] == 0, "L%d: SHOW A MOVE legal and solvable on all %d states" % [n, res["states"]])
	_check(res["hammer_bad"] == 0, "L%d: Hammer safety exact on all states" % n)
	var look := Solver.from_model(model_of(lv)).lookahead_win_rate(300, 4, 11)
	_check(look >= 0.5, "L%d: a 4-move look-ahead player wins (%.2f)" % [n, look])
	var m := LevelAnalysis.analyze(lv)
	_check(m["lock_impact"] >= 0.5, "L%d: the lock matters (impact %.1f)" % [n, m["lock_impact"]])
	if n == 16:
		_check(m["spinner_impact"] >= 0.5, "L16: the spinner matters (impact %.1f)" % m["spinner_impact"])
		_check(lv.blocks.size() >= 10 and lv.blocks.size() <= 12, "L16: 10-12 blocks (%d)" % lv.blocks.size())
	if n == 20:
		_check(m["mystery_impact"] >= 0.3 and m["mystery_fair"], "L20: hidden arrows matter and are fair (impact %.1f)" % m["mystery_impact"])
		_check(lv.blocks.size() >= 12 and lv.blocks.size() <= 14 and lv.mystery, "L20: 12-14 blocks, mystery (%d)" % lv.blocks.size())


func _explore(s: Solver, win: Dictionary) -> bool:
	var k := s._key()
	if win.has(k):
		return win[k]
	if s._alive_count == s._crate_n:
		win[k] = true
		return true
	var w := false
	for mv in s.legal_moves():
		s._do(mv)
		if _explore(s, win):
			w = true
		s._undo_move(mv)
	win[k] = w
	return w


## Shortest number of further moves until no legal move is left.
func _stuck_in(s: Solver, depth: int) -> bool:
	if s._alive_count == s._crate_n:
		return false
	var legal := s.legal_moves()
	if legal.is_empty():
		return true
	if depth <= 0:
		return false
	for mv in legal:
		s._do(mv)
		var r := _stuck_in(s, depth - 1)
		s._undo_move(mv)
		if r:
			return true
	return false


func _check_walk(s: Solver, win: Dictionary, seen: Dictionary, res: Dictionary, m: BoardModel) -> void:
	var k := s._key()
	if seen.has(k) or s._alive_count == s._crate_n:
		return
	seen[k] = true
	res["states"] += 1
	var winnable: bool = win[k]
	if winnable:
		for mv in s.legal_moves():
			s._do(mv)
			var after: bool = s._alive_count == s._crate_n or win[s._key()]
			if not after:
				res["fatal"] += 1
				# visible: some line of at most 2 more moves already has no move left
				if not _stuck_in(s, 2):
					res["deep"] += 1
			s._undo_move(mv)
			if not after and not s._is_risky(mv):
				res["calm"] += 1
	for mv in s.legal_moves():
		s._do(mv)
		_check_walk(s, win, seen, res, m)
		s._undo_move(mv)


# --- Sampled SHOW A MOVE / Hammer on all 100 ---------------------------------------

func _sampled_tools(n: int) -> void:
	var lv := lab_level(n)
	var m := model_of(lv)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + n
	var bad_hint := 0
	var bad_hammer := 0
	var checked := 0
	for walk in 3:
		var snap := m.snapshot()
		var steps := 0
		while not m.is_empty() and steps < 40:
			var s := Solver.from_model(m)
			s.node_limit = 400000
			var rec := s.recommend_move()
			if rec == -1 or not m.is_playable(rec):
				bad_hint += 1
				break
			# Hammer: one random block per state, checked exhaustively.
			var ids := m.blocks.keys()
			var hid: int = ids[rng.randi() % ids.size()]
			var safe := Solver.hammer_safe(m, hid)
			var hs := m.snapshot()
			m.remove(hid, false)  # a smash: a smashed magnet pulls nothing
			var keeps := m.is_empty() or Solver.from_model(m).is_solvable()
			m.restore(hs)
			if safe and not keeps:
				bad_hammer += 1
			checked += 1
			# Advance: the hint move most of the time, otherwise any safe move.
			var mv := rec
			if rng.randf() < 0.4:
				var opts := m.playable_ids().filter(func(id):
					var t := m.snapshot()
					_tap(m, id)
					var ok := m.is_empty() or Solver.from_model(m).is_solvable()
					m.restore(t)
					return ok)
				if not opts.is_empty():
					mv = opts[rng.randi() % opts.size()]
			var before := m.snapshot()
			_tap(m, mv)
			if not m.is_empty() and not Solver.from_model(m).is_solvable():
				bad_hint += 1 if mv == rec else 0
				m.restore(before)
				break
			steps += 1
		m.restore(snap)
	_check(bad_hint == 0, "L%d SHOW A MOVE legal and solvable on sampled states (%d)" % [n, checked])
	_check(bad_hammer == 0, "L%d Hammer never allows an unsafe smash on sampled states" % n)


## One tap on the model: a ram cracks the shell (the rammer stays), any
## other playable block escapes.
static func _tap(m: BoardModel, id: int) -> void:
	if m.move_state(id) == "ram":
		m.ram(id)
	elif m.twin_partner(id) >= 0:
		m.remove_pair(id)  # TWINS: the pair leaves as one move
	else:
		m.remove(id)


# --- The real game ------------------------------------------------------------------

func _snapshot() -> Array:
	var out := []
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = game.model.blocks[id]
		out.append([id, b.cell, b.direction, b.hidden, b.spin_step, b.armored])
	return out


func _game() -> void:
	# Save isolation: snapshot the production and Opening Lab saves.
	_prod_before = _read_all("user://progress.cfg")
	_olab_before = _read_all(OpeningLab.SAVE_PATH)
	ExperienceLab.apply("reset")
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	# The GameManager applies the lab itself only from the URL / command
	# line; here it is applied directly, so the 100-level cap is set below.
	get_tree().root.add_child(game)
	await _frames(5)
	game.level_manager.level_count = mini(game.level_manager.level_count, ExperienceLab.LAST_LEVEL)
	AudioManager.set_music_enabled(false)
	_check(game.progress.path == ExperienceLab.SAVE_PATH, "the game uses the lab save (%s)" % game.progress.path)
	_check(_rule_visual_kinds() == [BlockData.SpinRule.ALT, BlockData.SpinRule.PATTERN], "in the lab Alternating / Pattern spinners use the approved rule symbols (%s)" % [_rule_visual_kinds()])
	var started_after_100 := false
	await _lock_lesson()
	await _gate_lesson()
	await _gate_125()
	await _armor_lesson()
	await _twins_lesson()
	for n in range(1, ExperienceLab.LAST_LEVEL + 1):
		game.start_level(n, "test")
		await _frames(2)
		var lv := lab_level(n)
		_check(game.level.name == lv.name and LevelManager.to_json_text(game.level) == LevelManager.to_json_text(lv), "game L%d loads the lab board" % n)
		_check(game.max_hearts == (3 if n >= 6 else 0), "L%d hearts %d" % [n, game.max_hearts])
		var start := _snapshot()
		game.progress.inventory["hint"] = 5
		game.request_hint()
		_check(game.hint_block != -1 and game.model.is_playable(game.hint_block), "L%d SHOW A MOVE marks a legal move" % n)
		var sol := Solver.from_model(game.model).solve()
		for i in mini(2, sol.size() - 1):
			game._on_block_tapped(sol[i])
			await _frames(1)
		game.undos_used = 0
		for i in mini(2, sol.size() - 1):
			game.undo()
			await _frames(1)
		_check(_snapshot() == start, "L%d Undo restores the exact board" % n)
		for i in mini(3, sol.size() - 1):
			game._on_block_tapped(sol[i])
			await _frames(1)
		game.restart()
		await _frames(2)
		_check(_snapshot() == start, "L%d Restart restores the exact start" % n)
		# Hammer: the first unsafe block (if any) is refused; a safe one keeps it solvable.
		game.progress.inventory["hammer"] = 99
		var unsafe := -1
		var safe_id := -1
		for e in start:
			if game.is_hammer_safe(e[0]):
				if safe_id == -1:
					safe_id = e[0]
			elif unsafe == -1:
				unsafe = e[0]
		if unsafe != -1:
			game.toggle_hammer()
			game._on_block_tapped(unsafe)
			await _frames(1)
			_check(game.model.blocks.has(unsafe), "L%d Hammer refuses an unsafe smash" % n)
			if game.hammer_armed:
				game.toggle_hammer()
		if safe_id != -1:
			game.restart()
			await _frames(2)
			game.toggle_hammer()
			game._on_block_tapped(safe_id)
			await _frames(1)
			_check(not game.model.blocks.has(safe_id) and (game.model.is_empty() or Solver.from_model(game.model).is_solvable()), "L%d a safe smash keeps it solvable" % n)
		game.restart()
		await _frames(2)
		sol = Solver.from_model(game.model).solve()
		for id in sol:
			game._on_block_tapped(id)
			await _frames(1)
		var t := 0
		var overlay := false
		var fits := true
		var vis := game.get_viewport().get_visible_rect()
		while not (game.completed and game.ui.is_complete_visible()) and t < 600:
			await _frames(2)
			var rr: Rect2 = game.ui.major_milestone_rect()
			if rr.size.x > 0.0:
				overlay = true
				fits = fits and rr.position.x >= 0.0 and rr.position.y >= 0.0 and rr.end.x <= vis.size.x and rr.end.y <= vis.size.y
			t += 1
		_check(game.completed and game.last_result.get("level", 0) == n, "L%d clears by taps" % n)
		var tier: String = game.last_result.get("celebration", "")
		var want_tier: String = ExperienceLab.CELEBRATIONS.get(n, "")  # every 25th level (the approved presentation)
		_check(tier == want_tier, "L%d milestone tier '%s' (want '%s')" % [n, tier, want_tier])
		_check(overlay == (want_tier != ""), "L%d %s the LEVELS ESCAPED overlay" % [n, "shows" if want_tier != "" else "never shows"])
		if overlay:
			_check(fits, "L%d milestone overlay fits the screen" % n)
			var big: String = game.ui._major.get_child(0).text
			var line: String = game.ui._major.get_child(1).text
			_check(big == str(n) and line == "LEVELS ESCAPED!", "L%d overlay reads '%s / %s'" % [n, big, line])
			var title: String = game.ui._card_title.text
			_check(title == "%d LEVELS ESCAPED!" % n, "L%d card title '%s'" % [n, title])
			for word in ["FINAL", "GRAND", "GAME COMPLETE", "FINISHED", "THE END", "HALFWAY"]:
				_check(not (big + " " + line + " " + title).to_upper().contains(word), "L%d milestone text has no '%s'" % [n, word])
		if n % 10 == 0:
			_check(int(game.last_result.get("chapter_complete", 0)) == n / 10, "Chapter %d completes at Lab %d" % [n / 10, n])
		if n == 100:
			# The Master no longer ends the lab: Chapter 10 card, then Lab 101.
			_check(not game.last_result.get("is_last", false), "Lab 100 is not the last lab level")
			game.next_level()
			await _frames(3)
			_check(game.ui.is_chapter_card_open(), "after Lab 100: the Chapter 10 card")
			game._after_chapter_card()
			await _frames(3)
			_check(game.current_level == 101 and not ExperienceLab.complete_open, "after Lab 100's card: NEXT goes on to Lab 101 (level %d)" % game.current_level)
		if n in [110, 120, 121, 129, 130, 139, 149, 150, 151, 159, 160, 169, 170, 174, 175, 176, 177, 179, 180, 184, 185, 186, 187, 190, 192, 194, 197, 198, 199]:
			# Natural progression through the Second Era (a Chapter card after 110 / 120).
			_check(not game.last_result.get("is_last", false), "Lab %d is not the last lab level" % n)
			game.next_level()
			await _frames(3)
			if n % 10 == 0:
				_check(game.ui.is_chapter_card_open(), "after Lab %d: the Chapter %d card" % [n, n / 10])
				game._after_chapter_card()
				await _frames(3)
			_check(game.current_level == n + 1 and not ExperienceLab.complete_open, "Lab %d: NEXT goes on to Lab %d (level %d)" % [n, n + 1, game.current_level])
		if n == ExperienceLab.LAST_LEVEL:
			_check(game.last_result.get("is_last", false), "Lab %d is the last lab level (a temporary boundary)" % n)
	# After 200: the Chapter 20 card, then the end-of-test-build screen, never 201.
	game.next_level()
	await _frames(3)
	if game.ui.is_chapter_card_open():
		game._after_chapter_card()
		await _frames(3)
	_check(ExperienceLab.complete_open and game.current_level == ExperienceLab.LAST_LEVEL, "after Lab %d: the end-of-test-build screen (level %d)" % [ExperienceLab.LAST_LEVEL, game.current_level])
	_check(game.level_manager.level_count == ExperienceLab.LAST_LEVEL, "the lab has exactly %d levels" % ExperienceLab.LAST_LEVEL)
	started_after_100 = ExperienceLab.log_entries().any(func(e): return e.get("kind") == "start" and int(e.get("level")) > ExperienceLab.LAST_LEVEL)
	_check(not started_after_100, "Level %d is never started" % (ExperienceLab.LAST_LEVEL + 1))
	for word in ["GAME COMPLETE", "THE END", "FINAL"]:
		_check(not (ExperienceLab.COMPLETE_TITLE + " " + ExperienceLab.COMPLETE_LINE).to_upper().contains(word), "the end-of-test-build screen does not say '%s'" % word)
	var layer := game.get_node_or_null("ExperienceLabComplete")
	var texts := []
	if layer:
		for nd in layer.find_children("*", "Label", true, false):
			texts.append(nd.text)
	_check(ExperienceLab.COMPLETE_TITLE in texts and ExperienceLab.COMPLETE_LINE in texts, "the lab-complete screen shows its two lines")
	# Its button opens Level Select with the lab's levels only.
	var btn: Button = layer.find_children("*", "Button", true, false)[0] if layer else null
	if btn:
		btn.pressed.emit()
		await _frames(3)
	_check(game.ui.is_level_select_open() and game.select_shown["unlocked"].size() + game.select_shown["locked"].size() == ExperienceLab.LAST_LEVEL, "Level Select lists Lab 1-%d" % ExperienceLab.LAST_LEVEL)
	# Save isolation.
	_check(_read_all("user://progress.cfg") == _prod_before, "the production save is byte-identical after the lab session")
	_check(_read_all(OpeningLab.SAVE_PATH) == _olab_before, "the Opening Lab save is byte-identical after the lab session")
	_check(FileAccess.file_exists(ExperienceLab.SAVE_PATH) and game.progress.highest_completed == ExperienceLab.LAST_LEVEL, "the lab's own save holds the progress (%d)" % game.progress.highest_completed)
	# The Grand Master after the full run (its first clear is the run's own).
	await _grand_master()
	_check(_read_all("user://progress.cfg") == _prod_before, "the production save is still byte-identical after the Grand Master checks")


## The block the lesson finger / highlight is on (-1 = none).
func _lesson_target() -> int:
	for vid in game.board._views:
		if game.board._views[vid].hinted:
			return vid
	return -1


## Lab 13: the lock lesson - cause and effect.
func _lock_lesson() -> void:
	game.progress.tips_seen.erase("lesson_lock")
	game.start_level(13, "test")
	await _frames(3)
	_check(game._lesson == "lock", "L13 opens the lock lesson")
	var lock_id := -1
	var greens := []
	for b in game.model.blocks.values():
		if b.lock_color != "":
			lock_id = b.id
	var key_color: String = game.model.blocks[lock_id].lock_color
	for b in game.model.blocks.values():
		if b.color == key_color:
			greens.append(b.id)
	_check(greens.size() >= 2, "L13 has %d key-colour blocks (at least 2: 'ALL of them')" % greens.size())
	_check(game.board._views[lock_id].marked and greens.all(func(g): return game.board._views[g].marked), "L13 lesson marks the lock and every key block")
	var first: int = _lesson_target()
	_check(first in greens, "L13 finger points at a key-colour block first")
	var nearest := greens.duplicate()
	var lc: Vector2i = game.model.blocks[lock_id].cell
	nearest.sort_custom(func(a, b): return (game.model.blocks[a].cell - lc).length_squared() < (game.model.blocks[b].cell - lc).length_squared())
	_check(first == nearest[0], "L13 the first key block shown is the one nearest the lock")
	_check(game.tutorial.is_showing() and game.tutorial._text.contains("(%d left)" % greens.size()), "L13 lesson text counts the key blocks ('%s')" % game.tutorial._text)
	# Key 1 leaves: the lock stays closed, the lesson goes on, the counter drops.
	game._on_block_tapped(first)
	await _frames(3)
	_check(game.model.is_locked(lock_id), "L13 after the first key block leaves, the lock is still CLOSED")
	_check(game._lesson == "lock" and game.tutorial._text.contains("(%d left)" % (greens.size() - 1)), "L13 counter after key 1: '%s'" % game.tutorial._text)
	var second: int = _lesson_target()
	_check(second in greens and second != first, "L13 finger moves to the next key block")
	# Undo keeps the lesson consistent.
	game.undos_used = 0
	game.undo()
	await _frames(2)
	_check(game.model.is_locked(lock_id) and _lesson_target() == first and game._lesson == "lock", "L13 Undo returns to the first lesson step")
	game._on_block_tapped(first)
	await _frames(2)
	# The last key block leaves: the lock opens at once, the lesson ends.
	game._on_block_tapped(second)
	await _frames(2)
	_check(not game.model.is_locked(lock_id) and game.model.is_playable(lock_id), "L13 the LAST key block leaving opens the lock immediately")
	_check(game._lesson == "" and game.progress.tips_seen.has("lesson_lock"), "L13 lesson complete and remembered")
	# The level still clears; a replay shows the plain hint, not the lesson.
	for id in Solver.from_model(game.model).solve():
		game._on_block_tapped(id)
		await _frames(1)
	await get_tree().create_timer(1.5).timeout
	_check(game.completed, "L13 clears after the lesson")
	game.start_level(13, "test")
	await _frames(2)
	_check(game._lesson == "" and game.level.hint.contains("LOCK's color"), "L13 replay: no lesson again, the plain hint")
	game.progress.tips_seen.erase("lesson_lock")


## Lab 101 and 106-175 are production boards: same JSON (map tokens, name,
## hint, finger, hearts, stars, ...) and the same parsed level as their
## source. Lab 131 differs only by its corrected hint; 151-170 come from the
## approved Armor interleave; Lab 151 (production 161) differs only by the
## one adapted token.
const LAB_131_HINT := "A switch turns the spinners beside it, too."
const PROD_131_HINT := "Switches can be gate links too."
## docs/armor_151_progression_design_audit.md, section 5.
const ARMOR_ORDER := {151: 161, 152: 166, 153: 151, 154: 162, 155: 155, 156: 168, 157: 157, 158: 165, 159: 154, 160: 160,
	161: 167, 162: 152, 163: 164, 164: 156, 165: 169, 166: 158, 167: 163, 168: 159, 169: 153, 170: 170,
	171: 171, 172: 172, 173: 173, 174: 174, 175: 175}
const LAB_151_EDIT := [2, 6, "Gv", "G>"]


func _production_era() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("manifest.json")))["levels"]
	var used := []
	for n in [101] + range(106, 176) + [ExperienceLab.LAST_LEVEL]:
		var src: int = ARMOR_ORDER.get(n, n)
		_check(manifest[n - 1]["source"] == "production P%d" % src, "Lab %d comes from production %d (%s)" % [n, src, manifest[n - 1]["source"]])
		if n >= 151 and n <= 175:
			used.append(src)
		var lab_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("level_%02d.json" % n)))
		var prod_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src_path(src)))
		for d in [lab_json, prod_json]:
			d["map"] = d["map"].map(func(row): return Array(String(row).split(" ", false)))
		if n == 151:
			var e: Array = LAB_151_EDIT
			_check(lab_json["map"][e[1]][e[0]] == e[3] and prod_json["map"][e[1]][e[0]] == e[2], "Lab 151: (%d,%d) %s -> %s is its one adaptation" % e)
			lab_json["map"][e[1]][e[0]] = e[2]
			_check(manifest[150]["edits"].size() == 1, "Lab 151 lists exactly one edit")
		elif n >= 152:
			_check(manifest[n - 1]["edits"].is_empty() and manifest[n - 1]["hint"] == null and manifest[n - 1]["rename"] == null, "Lab %d: no edit, hint or rename" % n)
		if n == 131:
			_check(lab_json["hint"] == LAB_131_HINT and prod_json["hint"] == PROD_131_HINT, "Lab 131 has the corrected hint, production 131 keeps its own ('%s' / '%s')" % [lab_json["hint"], prod_json["hint"]])
			lab_json["hint"] = prod_json["hint"]
		_check(lab_json == prod_json, "Lab %d JSON is production Level %d (every field, every map token%s)" % [n, src, " except the hint" if n == 131 else (" except the adapted token" if n == 151 else "")])
		var lab := lab_level(n)
		var prod := src_level(src)
		if n == 131:
			lab.hint = prod.hint  # the only difference (checked above)
		if n != 151:
			_check(LevelManager.to_json_text(lab) == LevelManager.to_json_text(prod) and lab.name == prod.name and lab.hint == prod.hint
				and lab.hint_finger == prod.hint_finger and lab.mystery == prod.mystery, "Lab %d parses to production Level %d" % [n, src])
	used.sort()
	_check(used == range(151, 176), "production 151-175 each appear exactly once in Lab 151-175")
	# Lab 151 (adapted 161): same shell, same first rammer; no losing first
	# move; no fatal option anywhere on SHOW A MOVE's line.
	var a := model_of(lab_level(151))
	_check(a.blocks.values().filter(func(b): return b.armored).size() == 1, "Lab 151 has one shell")
	var first_bad := 0
	for id in a.blocks.keys():
		if a.is_playable(id):
			var sn := a.snapshot()
			if a.move_state(id) == "ram": a.ram(id)
			else: a.remove(id)
			if not Solver.from_model(a).is_solvable(): first_bad += 1
			a.restore(sn)
	_check(first_bad == 0, "Lab 151: no losing first move (%d)" % first_bad)
	var steps := 0
	var fatal_steps := 0
	var ram_step := -1
	var rammer := Vector2i(-1, -1)
	while not a.is_empty() and steps < 40:
		steps += 1
		for id in a.blocks.keys():
			if a.is_playable(id):
				var sn := a.snapshot()
				if a.move_state(id) == "ram": a.ram(id)
				else: a.remove(id)
				if not (a.is_empty() or Solver.from_model(a).is_solvable()):
					fatal_steps += 1
				a.restore(sn)
		var mv := Solver.from_model(a).recommend_move()
		if a.move_state(mv) == "ram":
			if ram_step == -1:
				ram_step = steps
				rammer = a.blocks[mv].cell
			a.ram(mv)
		else:
			a.remove(mv)
	_check(a.is_empty() and fatal_steps == 0, "Lab 151: SHOW A MOVE's line clears it with no fatal option on the way (%d)" % fatal_steps)
	_check(ram_step == 9 and rammer == Vector2i(0, 0), "Lab 151: the first ram (end of the lesson) is the red arrow at (0,0), move %d %s" % [ram_step, rammer])
	# The corrected 131 hint is true on the board: the switch's escape turns
	# a neighbouring spinner (no block anywhere is both a switch and a link).
	var m := model_of(lab_level(131))
	var sw := m.blocks.values().filter(func(b): return b.is_switch())
	_check(sw.size() == 1 and not lab_level(131).hint_finger, "Lab 131: one switch, no finger")
	if sw.size() == 1:
		var turned := m.remove(sw[0].id)
		_check(not turned.is_empty(), "Lab 131: the switch's escape turns a spinner beside it (%s)" % [turned])
	for n in range(1, 301):
		var lv := LevelManager.read_level(n)
		_check(not lv.blocks.any(func(b): return b.is_switch() and b.gate_link != ""), "production L%d: no block is both a switch and a gate link" % n)
	# Lessons: the lab keeps production's Switch (101) and Gate (121) lessons,
	# runs production's Armor lesson at 151 (never again at 161) and adds none
	# elsewhere (125 especially).
	_check(ExperienceLab.LESSONS == {13: "lock", 76: "magnet", 101: "switch", 121: "gate", 151: "armor", 176: "twins", 201: "portal", 226: "sequence", 251: "movable"},
		"lessons are 13 lock, 76 magnet, 101 switch, 121 gate, 151 armor, 176 twins, 201 portal, 226 sequence, 251 movable (%s)" % [ExperienceLab.LESSONS])
	_check(GameManager.LESSONS == ExperienceLab.LESSONS, "since the freeze the game's lessons are the lab's (%s)" % [GameManager.LESSONS])
	_check(ExperienceLab.ARMOR_INTRO == 151 and not ExperienceLab.LESSONS.has(161), "the lab introduces Armor at 151, no lesson at Lab 161")
	# Every 25th level: the same LEVELS ESCAPED presentation in the lab and
	# in production; 125 / 150 / 175 stay paying milestone levels.
	for k in range(25, 201, 25):
		_check(ExperienceLab.CELEBRATIONS.get(k, "") == String(Chapters.config()["celebration_levels"].get(str(k), "")) and ExperienceLab.CELEBRATIONS[k].begins_with("lab_"),
			"Lab %d celebrates as production (%s)" % [k, ExperienceLab.CELEBRATIONS.get(k, "")])
	_check(ExperienceLab.CELEBRATIONS.size() == 8, "lab celebrations: every 25th level of 1-200")
	_check(Chapters.is_milestone(125) and Chapters.is_milestone(150) and Chapters.is_milestone(175), "125 / 150 / 175 keep their paying milestone")


# --- TWINS at 176-199 (docs/twins_176_199_lab.md) ---------------------------------

## The lab's Twins levels (docs/twins_176_199_integration_plan.md, section C).
const TWINS_LEVELS := [176, 177, 179, 182, 184, 187, 190, 192, 194, 197]
## Lab 176-199 sources: production boards (moved where listed), the approved
## prototype boards and the new boards.
const TWINS_SOURCES := {
	176: "Twins prototype 1", 177: "NEW (double_link)", 178: "production P178", 179: "Twins prototype 2", 180: "production P179",
	181: "production P181", 182: "production P182", 183: "production P183", 184: "Twins prototype 3", 185: "production P186",
	186: "production P185", 187: "NEW (shell_game)", 188: "production P188", 189: "production P189", 190: "NEW (two_bonds)",
	191: "production P191", 192: "NEW (reversal)", 193: "production P193", 194: "NEW (pattern_lock)", 195: "production P195",
	196: "production P196", 197: "NEW (bond_of_ages)", 198: "production P198", 199: "production P199",
}
const LAB_182_EDITS := [[4, 5, "R<", "R<!T"], [5, 5, "Y<", "Y<!T"]]


func _twins_era() -> void:
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("manifest.json")))["levels"]
	var used := []
	for n in range(176, 200):
		var e: Dictionary = manifest[n - 1]
		_check(e["source"] == TWINS_SOURCES[n], "Lab %d comes from %s (%s)" % [n, TWINS_SOURCES[n], e["source"]])
		_check(bool(e.get("twins", false)) == (n in TWINS_LEVELS), "manifest marks Lab %d's Twins correctly" % n)
		var src: String = TWINS_SOURCES[n]
		if src.begins_with("production P"):
			var p := int(src.substr(12))
			used.append(p)
			var lab_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("level_%02d.json" % n)))
			var prod_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src_path(p)))
			for d in [lab_json, prod_json]:
				d["map"] = d["map"].map(func(row): return Array(String(row).split(" ", false)))
			if n == 182:
				_check(e["edits"].size() == 2, "Lab 182 lists exactly its two Twins edits")
				for ed in LAB_182_EDITS:
					_check(lab_json["map"][ed[1]][ed[0]] == ed[3] and prod_json["map"][ed[1]][ed[0]] == ed[2], "Lab 182: (%d,%d) %s -> %s" % ed)
					lab_json["map"][ed[1]][ed[0]] = ed[2]
			else:
				_check(e["edits"].is_empty() and e["hint"] == null and e["rename"] == null, "Lab %d: no edit, hint or rename" % n)
			_check(lab_json == prod_json, "Lab %d JSON is production Level %d%s" % [n, p, " apart from the bond" if n == 182 else ""])
	used.sort()
	_check(used == [178, 179, 181, 182, 183, 185, 186, 188, 189, 191, 193, 195, 196, 198, 199],
		"Lab 176-199 use production 178 179 181 182 183 185 186 188 189 191 193 195 196 198 199 once each (%s)" % [used])
	for n in [1, 50, 100, 101, 150, 151, 175, 200]:
		_check(not lab_level(n).blocks.any(func(b): return b.twin != ""), "Lab %d has no Twins" % n)
	# Every Twins level: complete state graph on the Solver's rules (a pair =
	# one move) and BoardModel <-> Solver agreement on random walks.
	for n in TWINS_LEVELS:
		var lv := lab_level(n)
		var g := _twin_graph(Solver.from_model(model_of(lv)), 400000)
		if g.is_empty():
			_check(n == 182, "L%d full state graph within budget" % n)
		else:
			_check(g["winnable_start"], "L%d solvable (full graph)" % n)
			_check(g["plain"] == 0, "L%d: every fatal move is visible (spinner / switch / pair-turn), %d plain" % [n, g["plain"]])
			# 182 keeps its production board's one losing first move (its source
			# has the same); 192 may have one (plan, section F); all others none.
			var allowed := 0
			if n == 182:
				var src := _twin_graph(Solver.from_model(model_of(src_level(182))), 400000)
				allowed = src.get("first_bad", -1)
				_check(allowed == 1, "production 182 itself has one losing first move (%d)" % allowed)
			elif n == 192:
				allowed = 1
			_check(g["first_bad"] <= allowed, "L%d: losing first moves %d (allowed %d)" % [n, g["first_bad"], allowed])
			if n >= 179:
				_check(g["decisions"] > 0, "L%d: Twins create a decision (fatal pair release or switch / spinner timing near the pair: %d)" % [n, g["decisions"]])
			print("TWINS L%d %s" % [n, JSON.stringify(g)])
		_check(_agree(lv, 600 + n), "L%d: BoardModel and Solver agree on random walks" % n)
	# 182: the bond adds a real release-timing decision (B.3 of the plan).
	var m := model_of(lab_level(182))
	var fatal_release := 0
	var guard := 0
	while not m.is_empty() and guard < 60:
		guard += 1
		for id in m.blocks.keys():
			if m.twin_partner(id) > id and m.move_state(id) == "ok":
				var t := BoardModel.new()
				t.setup(m.rows, m.columns, m.snapshot())
				t.remove_pair(id)
				var ts := Solver.from_model(t)
				ts.node_limit = 400000
				if not t.is_empty() and not ts.is_solvable() and not ts.aborted:
					fatal_release += 1
		_tap(m, Solver.from_model(m).recommend_move())
	_check(m.is_empty() and fatal_release >= 5, "Lab 182: SHOW A MOVE's line clears it; releasing the pair is fatal at %d steps (a timing decision)" % fatal_release)


## Complete state graph with the Solver's rules, a pair counted once. {} if
## it exceeds `limit` states.
func _twin_graph(s: Solver, limit: int) -> Dictionary:
	var keys := {}
	var kids := []
	var flags := []
	var empty := PackedByteArray()
	var post := PackedInt32Array()
	var add := func(k: String) -> int:
		var id := kids.size()
		keys[k] = id
		empty.append(1 if s._alive_count == s._crate_n else 0)
		kids.append(PackedInt32Array())
		var fl := PackedByteArray()
		var ms := PackedInt32Array()
		if empty[id] == 0:
			for mv in s.legal_moves():
				var bid := mv & Solver.ID_MASK
				var p := s._partner(bid)
				if (mv & Solver.RAM) == 0 and p >= 0 and p < bid:
					continue
				var f := 0
				if (mv & Solver.RAM) == 0:
					f = (1 if s._spinner_neighbours(bid) > 0 else 0) | (2 if s._switch[bid] >= 0 else 0) | (4 if p >= 0 else 0)
				ms.append(mv)
				fl.append(f)
		flags.append([ms, fl])
		return id
	var st_id := PackedInt32Array([add.call(s._key())])
	var st_idx := PackedInt32Array([0])
	var st_mv := PackedInt32Array([-1])
	while not st_id.is_empty():
		var top := st_id.size() - 1
		var sid := st_id[top]
		var ms: PackedInt32Array = flags[sid][0]
		if st_idx[top] < ms.size():
			var mv := ms[st_idx[top]]
			st_idx[top] += 1
			s._do(mv)
			var k := s._key()
			if keys.has(k):
				kids[sid].append(keys[k])
				s._undo_move(mv)
			else:
				if kids.size() >= limit:
					s._undo_move(mv)
					for i in range(st_mv.size() - 1, 0, -1):
						s._undo_move(st_mv[i])
					return {}
				var nid: int = add.call(k)
				kids[sid].append(nid)
				st_id.append(nid)
				st_idx.append(0)
				st_mv.append(mv)
		else:
			post.append(sid)
			var back := st_mv[top]
			st_id.resize(top)
			st_idx.resize(top)
			st_mv.resize(top)
			if back != -1:
				s._undo_move(back)
	var win := PackedByteArray()
	win.resize(kids.size())
	for sid in post:
		var w := empty[sid]
		for c in kids[sid]:
			if win[c] == 1:
				w = 1
		win[sid] = w
	var r := {"states": kids.size(), "winnable_start": win[0] == 1, "fatal": 0, "plain": 0, "first_bad": 0, "decisions": 0}
	for sid in kids.size():
		if win[sid] == 0:
			continue
		for i in kids[sid].size():
			if win[kids[sid][i]] == 1:
				continue
			var f: int = flags[sid][1][i]
			r["fatal"] += 1
			if sid == 0:
				r["first_bad"] += 1
			if f == 0 or f == 4:
				r["plain"] += 1
			if f & 4 or f & 2 or f & 1:
				r["decisions"] += 1
	return r


## BoardModel and Solver: same playable moves and same state after every
## move, on 8 random walks.
func _agree(lv: LevelData, seed: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for walk in 8:
		var m := model_of(lv)
		var s := Solver.from_model(m)
		while not m.is_empty():
			var a: Array = m.playable_ids()
			a.sort()
			var b := []
			for mv in s.legal_moves():
				b.append(mv & Solver.ID_MASK)
			b.sort()
			if a != b or _model_state(m) != _solver_state(s):
				print("  disagreement: model %s solver %s" % [a, b])
				return false
			if b.is_empty():
				break
			var moves := s.legal_moves()
			var mv: int = moves[rng.randi_range(0, moves.size() - 1)]
			s._do(mv)
			_tap(m, mv & Solver.ID_MASK)
	return true


## Comparable full states (alive blocks: cell, arrow, concealed, shell,
## spinner step within its rule period).
static func _model_state(m: BoardModel) -> String:
	var ids: Array = m.blocks.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d,%d:%d:%d:%d:%d" % [id, b.cell.x, b.cell.y, b.direction, 1 if b.hidden else 0, 1 if b.armored else 0,
			posmod(b.spin_step, BlockData.rule_period(b.spin_rule)) if b.is_spinner() else 0])
	return "|".join(parts)


static func _solver_state(s: Solver) -> String:
	var parts := PackedStringArray()
	for id in s._alive.size():
		if s._alive[id] == 0:
			continue
		var idx: int = s._cell[id]
		parts.append("%d:%d,%d:%d:%d:%d:%d" % [id, idx % s.columns, idx / s.columns, s._dir[id], 1 if s._is_concealed(id) else 0,
			s._armor[id], posmod(s._step[id], BlockData.rule_period(s._rule[id])) if s._spinner[id] == 1 else 0])
	return "|".join(parts)


## Lab 176: the Twins lesson - marks, finger on the next correct move, the
## free partner-blocked tap explained, finished by the first pair escape.
func _twins_lesson() -> void:
	game.progress.tips_seen.erase("lesson_twins")
	GameManager.twin_wait_explained = false
	game.start_level(176, "test")
	await _frames(3)
	_check(game._lesson == "twins", "L176 opens the Twins lesson")
	_check(game.level.name == "Twin Lights" and game.board.bond_count() == 2, "L176 is Twin Lights with two bonds")
	var marks: Array = game.board._views.keys().filter(func(v): return game.board._views[v].marked)
	marks.sort()
	var twins: Array = game.model.blocks.keys().filter(func(id): return game.model.twin_partner(id) >= 0)
	twins.sort()
	_check(marks == twins, "L176 lesson marks every twin (%s / %s)" % [marks, twins])
	var target := _lesson_target()
	_check(target != -1 and game.model.is_playable(target), "L176 lesson finger is on a playable block")
	_check(game.tutorial.is_showing() or game.tutorial.visible, "L176 lesson line shows")
	# A partner-blocked tap: free, explained, the lesson goes on.
	var wait_id := -1
	for id in game.model.blocks:
		if game.model.move_state(id) == "twin_wait":
			wait_id = id
	if wait_id == -1:
		game._on_block_tapped(_lesson_target())
		await _frames(2)
		for id in game.model.blocks:
			if game.model.move_state(id) == "twin_wait":
				wait_id = id
	var hearts: int = game.hearts
	if wait_id != -1:
		game._on_block_tapped(wait_id)
		await _frames(2)
		_check(game.hearts == hearts and game._lesson == "twins" and game.tutorial._text == GameManager.TWIN_WAIT_TEXT,
			"L176 partner-blocked tap: free, explained, lesson continues ('%s')" % game.tutorial._text)
	else:
		_check(false, "L176 has a partner-blocked tap early on")
	var guard := 0
	while game._lesson == "twins" and guard < 20:
		guard += 1
		var t := _lesson_target()
		if t == -1:
			break
		game._on_block_tapped(t)
		await _frames(2)
	_check(game._lesson == "" and game.progress.tips_seen.has("lesson_twins"), "L176 lesson ends with the first pair escape and is remembered")
	_check(game.mistakes == 0, "L176 lesson costs no heart")
	game.start_level(176, "test")
	await _frames(3)
	_check(game._lesson == "", "L176 replay: no lesson again")
	game.progress.tips_seen.erase("lesson_twins")


## Lab 151: production's Armor lesson on the adapted board, step by step;
## the Chapter card announces Armor before Chapter 16 (lab) / 17 (production).
func _armor_lesson() -> void:
	_check(game._chapter_news(16).contains("Armored Blocks") and not game._chapter_news(17).contains("Armored Blocks"),
		"lab: the card before Chapter 16 says NEW: Armored Blocks, Chapter 17's does not ('%s' / '%s')" % [game._chapter_news(16), game._chapter_news(17)])
	_check(game._chapter_news(18).contains("Twins") and not game._chapter_news(17).contains("Twins") and not game._chapter_news(19).contains("Twins"),
		"lab: the card before Chapter 18 says NEW: Twins, no other card does ('%s')" % game._chapter_news(18))
	ExperienceLab.active = false
	var prod16: String = game._chapter_news(16)
	var prod17: String = game._chapter_news(17)
	var prod_twins := range(1, 31).filter(func(c): return game._chapter_news(c).contains("Twins"))
	ExperienceLab.active = true
	_check(prod16.contains("Armored Blocks") and not prod17.contains("Armored"), "since the freeze the game announces Armored Blocks for Chapter 16 ('%s' / '%s')" % [prod16, prod17])
	_check(prod_twins == [18], "since the freeze the game announces Twins on the Chapter 18 card only (%s)" % [prod_twins])
	game.progress.tips_seen.erase("lesson_armor")
	game.start_level(151, "test")
	await _frames(3)
	_check(game._lesson == "armor", "L151 opens production's Armor lesson")
	var shell := -1
	for b in game.model.blocks.values():
		if b.armored:
			shell = b.id
	var rammer := -1
	for mv in Solver.from_model(game.model).solve_moves():
		if mv & Solver.RAM:
			rammer = mv & Solver.ID_MASK
			break
	_check(shell != -1 and rammer != -1 and game.model.blocks[rammer].cell == Vector2i(0, 0), "L151: the shell and its rammer (the red arrow at (0,0))")
	_check(game.board._views[shell].marked and game.board._views[rammer].marked, "L151 lesson highlights the shell and the rammer")
	var steps := 0
	var cracked := false
	while game._lesson == "armor" and steps < 30:
		var want := Solver.from_model(game.model).recommend_move()
		var is_ram: bool = game.model.move_state(want) == "ram"
		_check(_lesson_target() == want, "L151 step %d: finger on production's pick" % steps)
		var text: String = "Hit the armored block to break its shell" if is_ram else "Armored: can't escape. Clear a path for the marked block to hit it"
		_check(game.tutorial.is_showing() and game.tutorial._text == text, "L151 step %d: production lesson text ('%s')" % [steps, game.tutorial._text])
		game._on_block_tapped(want)
		await _frames(2)
		steps += 1
		if is_ram:
			cracked = true
			_check(want == rammer and game.model.blocks.has(rammer) and not game.model.blocks[shell].armored, "L151 the ram cracks the shell; the rammer stays")
			_check(game.tutorial._text == "Shell cracked! Now it moves like any other block", "L151 production completion line ('%s')" % game.tutorial._text)
		else:
			_check(game.model.blocks[shell].armored, "L151 the shell holds until the ram")
	_check(cracked and steps == 9 and game._lesson == "" and game.progress.tips_seen.has("lesson_armor"), "L151 lesson complete after %d steps and remembered" % steps)
	var sol := Solver.from_model(game.model).solve()
	_check(not sol.is_empty() and sol.has(shell), "L151 the cracked block can now escape like any other")
	for id in sol:
		game._on_block_tapped(id)
		await _frames(1)
	await get_tree().create_timer(1.5).timeout
	_check(game.completed, "L151 clears after the lesson")
	game.start_level(151, "test")
	await _frames(2)
	_check(game._lesson == "", "L151 replay: no lesson again")
	game.start_level(161, "test")
	await _frames(2)
	_check(game._lesson == "" and game.level.hint == "", "Lab 161 (Ice Vault): no Armor lesson or intro hint")
	game.progress.tips_seen.erase("lesson_armor")


## Lab 200: production's Grand Master, unchanged: board, theme, music,
## celebration, card, and the one-time 600-coin bonus (paid once per save).
func _grand_master() -> void:
	_check(Chapters.is_master(200) and Chapters.celebration_tier(200) == "lab_major", "Lab 200 is production's Grand Master (the standard 200 LEVELS ESCAPED presentation, then GRAND MASTER)")
	var t: Dictionary = Chapters.theme_for_level(200)
	_check(t.get("name") == "Grand Master" and t.get("music") == "master2", "Lab 200 keeps the Grand Master theme and music (%s / %s)" % [t.get("name"), t.get("music")])
	_check(int(Economy.config()["rewards"].get("master_clear_200", 0)) == 600, "the Grand Master bonus is 600 coins")
	game.progress.achievements.erase("master_200")  # replay the first clear's bonus check
	game.start_level(200, "test")
	await _frames(3)
	_check(game.level.name == "The Grand Master" and game.level.hint == "The Grand Master. Every rule of both eras." and game._lesson == "", "L200: production board and hint, no lesson")
	_check(AudioManager.music_theme == "master2", "L200 plays the Grand Master music (%s)" % AudioManager.music_theme)
	_check(game.ui._level_label.text == "GRAND MASTER", "L200 header reads GRAND MASTER ('%s')" % game.ui._level_label.text)
	for pass_i in 2:
		if pass_i == 1:
			game.start_level(200, "test")
			await _frames(3)
		var coins_before: int = game.progress.coins
		for id in Solver.from_model(game.model).solve():
			game._on_block_tapped(id)
			await _frames(1)
		var t2 := 0
		while not (game.completed and game.ui.is_complete_visible()) and t2 < 600:
			await _frames(2)
			t2 += 1
		var gained: int = game.progress.coins - coins_before
		var notes: String = str(game.last_result.get("coin_notes", ""))
		_check(game.completed and game.last_result.get("master", false) and game.ui._card_title.text == "200 LEVELS ESCAPED!", "L200 clear %d: Master result and the 200 LEVELS ESCAPED! card ('%s')" % [pass_i + 1, game.ui._card_title.text])
		if pass_i == 0:
			_check(game.progress.achievements.has("master_200") and gained >= 600 and notes.contains("GRAND MASTER"), "L200 first clear pays the 600-coin Grand Master bonus once (+%d, '%s')" % [gained, notes])
		else:
			_check(gained < 600 and not notes.contains("GRAND MASTER"), "L200 replay: no second Grand Master bonus (+%d, '%s')" % [gained, notes])


## Lab 121: production's Chain Gate lesson, step by step.
func _gate_lesson() -> void:
	game.progress.tips_seen.erase("lesson_gate")
	game.start_level(121, "test")
	await _frames(3)
	_check(game._lesson == "gate", "L121 opens the production Chain Gate lesson")
	var gate := -1
	var links := []
	for b in game.model.blocks.values():
		if b.is_gate():
			gate = b.id
		elif b.gate_link != "":
			links.append(b.id)
	_check(gate != -1 and links.size() == 1, "L121 has one gate and one chained block (production)")
	_check(game.board._views[gate].marked and links.all(func(l): return game.board._views[l].marked), "L121 lesson highlights the gate and its chained block")
	var waiting := game.model.blocks.keys().filter(func(id): return id != gate and game.model.find_blocker(id) != null and game.model.find_blocker(id).id == gate)
	_check(waiting.size() == 2, "L121 two blocks wait behind the gate (%d)" % waiting.size())
	var steps := 0
	var opened := false
	while game._lesson == "gate" and steps < 30:
		var want := Solver.from_model(game.model).recommend_move()
		var g: String = game.model.blocks[gate].gate_group
		_check(_lesson_target() == want, "L121 step %d: finger on production's pick" % steps)
		_check(game.tutorial.is_showing() and game.tutorial._text == "GATE %s opens when every block chained %s escapes (%d left)" % [g, g, game.model.gate_remaining(g)],
			"L121 step %d: production lesson text ('%s')" % [steps, game.tutorial._text])
		var sfx := AudioManager.sfx_played
		var is_link: bool = want in links
		game._on_block_tapped(want)
		await _frames(2)
		steps += 1
		if is_link:
			opened = true
			_check(not game.model.blocks.has(gate) and game.board.get_view(gate) == null, "L121 the chained block escapes and the gate opens at once")
			_check(game.model.last_opened_gates.size() == 1, "L121 the gate-open event fires")
			_check(AudioManager.sfx_played >= sfx + 2 or not AudioManager.sfx_enabled, "L121 gate sound plays with the escape (%d sfx)" % (AudioManager.sfx_played - sfx))
			_check(waiting.all(func(id): return game.model.can_escape(id)), "L121 the waiting blocks are free")
			_check(game.tutorial._text == "The gate is open - its lane is free!", "L121 production completion line ('%s')" % game.tutorial._text)
		else:
			_check(game.model.blocks.has(gate), "L121 the gate stays until its chained block leaves")
	_check(opened and game._lesson == "" and game.progress.tips_seen.has("lesson_gate"), "L121 lesson complete and remembered (%d steps)" % steps)
	for id in Solver.from_model(game.model).solve():
		game._on_block_tapped(id)
		await _frames(1)
	await get_tree().create_timer(1.5).timeout
	_check(game.completed, "L121 clears after the lesson")
	game.start_level(121, "test")
	await _frames(2)
	_check(game._lesson == "", "L121 replay: no lesson again")
	game.progress.tips_seen.erase("lesson_gate")


## Lab 125: exactly production - no lesson, hint, finger, message or extra
## feedback; a chained block leaving only lowers its gate's counter.
func _gate_125() -> void:
	if not game.progress.tips_seen.has("gate"):
		game.progress.tips_seen.append("gate")  # as after Lab 121
	game.start_level(125, "test")
	await _frames(3)
	_check(game._lesson == "" and game.level.hint == "" and not game.tutorial.is_showing() and _lesson_target() == -1,
		"L125 starts with no lesson, hint, message or finger")
	_check(game.board._views.values().all(func(v): return not v.marked), "L125 nothing is highlighted")
	var gates := {}
	for b in game.model.blocks.values():
		if b.is_gate():
			gates[b.gate_group] = b.id
	_check(gates.size() == 2 and game.board._views[gates["C"]].gate_count == 3 and game.board._views[gates["D"]].gate_count == 2, "L125 gate counters start C 3, D 2")
	var counts := {"C": [3], "D": [2]}
	await get_tree().create_timer(1.5).timeout  # the level's pop-in is over
	for id in Solver.from_model(game.model).solve():
		var link: String = game.model.blocks[id].gate_link
		var before := []
		if link != "":
			var v0: BlockView = game.board._views[gates[link]]
			before = [v0.scale, v0.modulate]
		game._on_block_tapped(id)
		await _frames(1)
		if link != "" and game.model.blocks.has(gates[link]):
			# Not the last link: the gate stays shut, its number drops - nothing else.
			counts[link].append(game.board._views[gates[link]].gate_count)
			_check(game.model.last_opened_gates.is_empty() and not game.tutorial.is_showing(), "L125 a chained block leaves: no message, gate %s stays shut" % link)
			# The gate sound / pop only ever play on an opening (none here):
			# the slab itself is untouched apart from its number.
			var gv: BlockView = game.board._views[gates[link]]
			_check(gv.scale == before[0] and gv.modulate == before[1] and not gv.marked and not gv.hinted, "L125 gate %s's slab gets no animation, mark or finger" % link)
		elif link != "":
			counts[link].append(0)
	_check(counts == {"C": [3, 2, 1, 0], "D": [2, 1, 0]}, "L125 counters count down C 3-2-1-open, D 2-1-open (%s)" % [counts])
	await get_tree().create_timer(1.5).timeout
	_check(game.completed and Chapters.is_milestone(125), "L125 clears (production milestone level)")


## Which spin rules draw the lab's rule symbols (BlockView._lab_rule_visuals)
## right now - on a normal block and on a Silver coin.
func _rule_visual_kinds() -> Array:
	var out := []
	for rule in [BlockData.SpinRule.CW, BlockData.SpinRule.CCW, BlockData.SpinRule.ALT, BlockData.SpinRule.PATTERN]:
		for rarity in [BlockData.Rarity.NORMAL, BlockData.Rarity.SILVER]:
			var b := BlockData.new(0, Vector2i.ZERO, "blue", 0, BlockData.Kind.SPINNER)
			b.spin_rule = rule
			b.rarity = rarity
			var v := BlockView.new()
			v.data = b
			if v._lab_rule_visuals() and not out.has(rule):
				out.append(rule)
			v.free()
	return out


static func _read_all(path: String) -> String:
	var out := ""
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		out += "|" + (FileAccess.get_file_as_string(path + suffix) if FileAccess.file_exists(path + suffix) else "<none>")
	return out
