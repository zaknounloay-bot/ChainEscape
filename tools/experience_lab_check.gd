extends Node
## PLAYER EXPERIENCE LAB 1-130 checks (developer page ?experiencelab).
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
## - Each Level 1-130 loads its lab board, hearts from 6, SHOW A MOVE, Undo
##   exact, Restart exact, Hammer refuses unsafe smashes, clears by taps;
##   Chapter cards at 10, 20 ... 130; Lab 100 goes on to Lab 101; NEXT goes
##   110 -> 111, 120 -> 121, 121 -> 122, 129 -> 130; after 130 (a temporary
##   lab boundary): the end-of-test-build screen, never Level 131; Level
##   Select lists 1-130 only.
## - Switch ramp 102-105 on the full state graph (_switch_ramp).
## - Lab 101 and 106-130 are the production boards, unchanged (_production_era).
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
	for n in range(1, ExperienceLab.LAST_LEVEL + 1):
		_sampled_tools(n)
	await _game()
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("EXPERIENCE LAB CHECKS PASSED" if failures.is_empty() else "EXPERIENCE LAB CHECKS FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


static func lab_level(n: int) -> LevelData:
	var json = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("level_%02d.json" % n)))
	return LevelManager.parse_level(json, n, true)


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
		# QA jump: 2..100 opens that level; anything else keeps the old meaning.
		["?experiencelab=13", "", "13"], ["?v=123456&experiencelab=41", "", "41"], ["?experiencelab=2", "", "2"],
		["?experiencelab=100", "", "100"], ["?v=1&experiencelab=50&x=2", "", "50"], ["", "#experiencelab=75", "75"],
		["?experiencelab=101", "", "101"], ["?experiencelab=110", "", "110"], ["?experiencelab=111", "", "111"],
		["?v=123456&experiencelab=121", "", "121"], ["?experiencelab=125", "", "125"], ["?experiencelab=130", "", "130"], ["?experiencelab=131", "", ""], ["?experiencelab=-5", "", ""], ["?experiencelab=13abc", "", ""],
		["?v=1&experiencelab=13&experiencelab=reset", "", "reset"],
	]
	for c in cases:
		var got := ExperienceLab.parse_mode(c[0], c[1])
		_check(got == c[2], "parse_mode(%s %s) = '%s' (want '%s')" % [c[0], c[1], got, c[2]])


func _defaults() -> void:
	_check(not ExperienceLab.active and not OpeningLab.active and LevelManager.override_dir == "", "labs are off unless asked for")
	_check(PlayerProgress.default_path == "user://progress.cfg" and PlayerProgress.mirror_key == "chain_escape_save" and PlayerProgress.beacon_key == "chain_escape_beacon",
		"production save path and Web keys unchanged by default")
	var lm := LevelManager.new()
	lm._ready()
	_check(lm.level_count == 300, "300 production levels (%d)" % lm.level_count)
	_check(_rule_visual_kinds() == [], "without the lab every spinner keeps the production drawing (%s)" % [_rule_visual_kinds()])
	for n in [1, 11, 16, 20, 50, 100, 101, 111, 121, 125, 130]:
		var a := LevelManager.to_json_text(lm.load_level(n))
		var b := LevelManager.to_json_text(LevelManager.read_level(n))
		_check(a == b, "without the lab, Level %d is production" % n)
	lm.free()


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
			src_json = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % int(src.substr(12))))
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
			var want_lv := LevelManager.parse_level(expect, n, true)
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
			"pattern": lv.blocks.any(func(b): return b.is_spinner() and b.spin_rule == BlockData.SpinRule.PATTERN)}
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
		else:
			# Lab 121-130: the production Chain Gate levels - nothing newer.
			var other := lv.blocks.filter(func(b): return b.armored or b.is_crate() or b.seq_stage != 0)
			_check(other.is_empty() and lv.portals.is_empty() and lv.blocks.any(func(b): return b.is_gate()), "L%d is a Chain Gate level with no newer mechanic" % n)
	var want_first := {"spinner": 6, "hidden": 8, "lock": 13, "ccw": 31, "alt": 41, "pattern": 51}
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
			m.remove(hid)
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
					m.remove(id)
					var ok := m.is_empty() or Solver.from_model(m).is_solvable()
					m.restore(t)
					return ok)
				if not opts.is_empty():
					mv = opts[rng.randi() % opts.size()]
			var before := m.snapshot()
			m.remove(mv)
			if not m.is_empty() and not Solver.from_model(m).is_solvable():
				bad_hint += 1 if mv == rec else 0
				m.restore(before)
				break
			steps += 1
		m.restore(snap)
	_check(bad_hint == 0, "L%d SHOW A MOVE legal and solvable on sampled states (%d)" % [n, checked])
	_check(bad_hammer == 0, "L%d Hammer never allows an unsafe smash on sampled states" % n)


# --- The real game ------------------------------------------------------------------

func _snapshot() -> Array:
	var out := []
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = game.model.blocks[id]
		out.append([id, b.cell, b.direction, b.hidden, b.spin_step])
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
	_check(_rule_visual_kinds() == [BlockData.SpinRule.ALT, BlockData.SpinRule.PATTERN], "in the lab only Alternating / Pattern spinners use the new rule symbols (%s)" % [_rule_visual_kinds()])
	var started_after_100 := false
	await _lock_lesson()
	await _gate_lesson()
	await _gate_125()
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
		var want_tier: String = {25: "lab_milestone", 50: "lab_milestone_strong", 75: "lab_milestone_plus", 100: "lab_major"}.get(n, "")
		_check(tier == want_tier, "L%d milestone tier '%s' (want '%s')" % [n, tier, want_tier])
		_check(overlay == (want_tier != ""), "L%d %s the LEVELS ESCAPED overlay" % [n, "shows" if want_tier != "" else "never shows"])
		if overlay:
			_check(fits, "L%d milestone overlay fits the screen" % n)
			var big: String = game.ui._major.get_child(0).text
			var line: String = game.ui._major.get_child(1).text
			_check(big == str(n) and line == "LEVELS ESCAPED!", "L%d overlay reads '%s / %s'" % [n, big, line])
			var title: String = game.ui._card_title.text
			_check(title == ("MASTER CLEARED!" if n == 100 else "%d LEVELS ESCAPED!" % n), "L%d card title '%s'" % [n, title])
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
		if n in [110, 120, 121, 129]:
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
	# After 130: Chapter 13 card, then the end-of-test-build screen, never 131.
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


## Lab 101 and 106-130 are the production boards: same JSON (map tokens,
## name, hint, finger, hearts, stars, ...) and the same parsed level.
func _production_era() -> void:
	for n in [101] + range(106, ExperienceLab.LAST_LEVEL + 1):
		var lab_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("level_%02d.json" % n)))
		var prod_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n))
		for d in [lab_json, prod_json]:
			d["map"] = d["map"].map(func(row): return Array(String(row).split(" ", false)))
		_check(lab_json == prod_json, "Lab %d JSON is production Level %d (every field, every map token)" % [n, n])
		var lab := lab_level(n)
		var prod := LevelManager.read_level(n)
		_check(LevelManager.to_json_text(lab) == LevelManager.to_json_text(prod) and lab.name == prod.name and lab.hint == prod.hint
			and lab.hint_finger == prod.hint_finger and lab.mystery == prod.mystery, "Lab %d parses to production Level %d" % [n, n])
	# Lessons: the lab keeps production's Switch (101) and Gate (121) lessons
	# and adds none in 102-130 (125 especially).
	_check(ExperienceLab.LESSONS == {13: "lock", 101: "switch", 121: "gate"}, "lab lessons are 13 lock, 101 switch, 121 gate (%s)" % [ExperienceLab.LESSONS])
	_check(ExperienceLab.LESSONS[121] == GameManager.LESSONS[121] and ExperienceLab.LESSONS[101] == GameManager.LESSONS[101], "Lab 101 / 121 use production's own lesson kinds")
	# Milestone 125: production's milestone level, no lab celebration on top.
	_check(Chapters.is_milestone(125) and not ExperienceLab.CELEBRATIONS.has(125) and ExperienceLab.CELEBRATIONS.keys().all(func(k): return k <= 100),
		"125 keeps production's milestone; lab celebrations stay at 25/50/75/100")


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
