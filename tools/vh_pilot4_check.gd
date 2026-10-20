extends Node
## VERY HARD GATE 0 PILOT (development only, ?vhtest4=1): end-to-end checks.
##   godot --headless --path . res://tools/VhPilot4Check.tscn
## Board file integrity (28 boards, five hidden groups, live VERY HARD
## assistance, every board exact, parsed intact, Solver-valid within the
## recipient's 60000 nodes, at most 7x7, mechanics recorded truthfully,
## every advanced mechanic mattering, no duplicate of a campaign level, an
## earlier test or lab board, or another candidate); every board played to
## the end in the real SocialPlay (as the page plays it) with the tapped
## block inferred correctly for the action log; and the page flow: campaign
## progress -> balanced order of eligible boards, reminder card, clock,
## GIVE UP (two taps), the five questions, the hardest puzzle, results,
## resume after a reload, &bench timings. Tests 1-3 keep their own check
## (VhHumanTestCheck).

const PROGRESS_PATH := "user://vh_pilot4_check_progress.cfg"
const CANON := preload("res://tools/vh_pilot4_canon.gd")
const DATA := "res://data/dev/vh_pilot4.json"
const GROUP_SIZES := {"G0": 8, "G1": 5, "G2": 5, "G3": 5, "G4": 5}

var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS["vhtest4"]["state"]))
	_run.call_deferred()


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_check_data(data)
	await _play_every_board(data)
	await _page_flow()
	print("VH PILOT4 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# --- The board file --------------------------------------------------------------------------

func _check_data(data) -> void:
	_check(typeof(data) == TYPE_DICTIONARY and data.get("test") == "vhtest4", "the pilot board file loads")
	var a: Dictionary = data["assist"]
	_check(int(a["undo"]) == 3 and int(a["show_a_move"]) == 1 and int(a["hammer"]) == 0, "live VERY HARD assistance: UNDO x3, SHOW A MOVE x1, HAMMER x0")
	var boards: Array = data["boards"]
	_check(boards.size() == 28, "28 boards (%d)" % boards.size())
	var counts := {}
	var ids := {}
	for b in boards:
		counts[b["variant"]] = counts.get(b["variant"], 0) + 1
		ids[b["id"]] = true
	_check(counts == GROUP_SIZES, "groups G0 8, G1-G4 5 each (%s)" % str(counts))
	_check(ids.size() == 28 and ids.keys().all(func(i): return str(i).begins_with("V")), "28 neutral ids (V01-V28)")
	var known := _known_keys()
	var keys := {}
	LevelManager.dev_sequence = true
	LevelManager.dev_movable = true
	for b in boards:
		var id: String = b["id"]
		var def := PuzzleDefinition.from_dict(b["puzzle"])
		_check(def != null and Array(def.map) == Array(b["puzzle"]["map"]), "%s: exact stored board" % id)
		var level := def.to_level()
		var tokens := 0
		var portal_cells := 0
		for row in def.map:
			for t in String(row).split(" ", false):
				if t == ".":
					continue
				if t.length() == 2 and t[0] == "O":
					portal_cells += 1
				else:
					tokens += 1
		_check(level != null and level.blocks.size() == tokens and level.portals.size() == portal_cells, "%s: every cell parses (page parsing)" % id)
		_check(def.rows <= 7 and def.columns <= 7, "%s: at most 7x7 (%dx%d)" % [id, def.columns, def.rows])
		var m := BoardModel.new()
		m.setup(level.rows, level.columns, level.blocks)
		m.set_portals(level.portals)
		var s := Solver.from_model(m)
		s.node_limit = Solver.DEFAULT_NODE_LIMIT
		var moves := s.solve_moves()
		_check(not s.aborted and not moves.is_empty(), "%s: solvable within the recipient's %d nodes (%d used)" % [id, Solver.DEFAULT_NODE_LIMIT, s.nodes])
		var mech: Array = CANON.mechanics(Array(def.map))
		_check(mech == b["mechanics"], "%s: mechanics recorded truthfully %s" % [id, str(mech)])
		var fl: int = 1 if mech.is_empty() else mech.map(func(k): return CANON.FIRST_LEVEL.get(k, 1)).max()
		_check(int(b["first_level"]) == fl, "%s: first level %d" % [id, fl])
		var key: String = CANON.canonical(Array(def.map))
		_check(key == b["canonical"] and not keys.has(key), "%s: no duplicate among the candidates" % id)
		keys[key] = true
		if b["recipe"] == "G0_control":
			_check(known.get(key, "").contains("vh_human_test"), "%s: a control from an earlier test (rotated + recoloured), as intended" % id)
		else:
			_check(not known.has(key), "%s: not a campaign level, earlier test or lab board (%s)" % [id, known.get(key, "new")])
		if b["recipe"] in ["G0_control", "G0_live"]:
			continue
		_check(b["accepted"], "%s: passed every acceptance rule (%s)" % [id, b["note"]])
		var imp: Dictionary = b["metrics"]["impact"]
		for fam in ["lock", "switch", "gate", "armor", "portal", "sequence", "crate"]:
			var present := mech.any(func(k): return k == fam)
			if present:
				_check(float(imp[fam]) >= 1.0, "%s: %s matters (impact %.1f)" % [id, fam, imp[fam]])
		_check(b["verify"]["nodes"] <= 20000, "%s: recipient check within the 20000-node working budget (%d)" % [id, b["verify"]["nodes"]])
		_check(not b["metrics"]["hint"]["aborted"] and b["metrics"]["hint"]["consistent"], "%s: SHOW A MOVE within budget and always finds a move on the solution" % id)
		var h: Dictionary = b["metrics"]["hint"]
		var slowest := maxf(b["verify"]["ms_desktop"], maxf(h["max_ms_desktop"], h["dead_max_ms_desktop"]))
		_check(slowest <= 40.0, "%s: within the mobile time budget when built (%.1f ms desktop)" % [id, slowest])
	LevelManager.dev_sequence = false
	LevelManager.dev_movable = false


func _known_keys() -> Dictionary:
	var known := {}
	for n in range(1, 301):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%02d.json" % n))
		known[CANON.canonical(Array(d["map"]))] = "campaign L%d" % n
	var stack := ["res://data/dev"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json") and not f.begins_with("vh_pilot4"):
				_collect(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f))), dir.path_join(f), known)
	return known


func _collect(v, where: String, known: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if v.has("original"):
			return  # a declared copy of a board kept elsewhere (vh_validation3.json), not a new board
		if v.has("map") and typeof(v["map"]) == TYPE_ARRAY and not v["map"].is_empty() and typeof(v["map"][0]) == TYPE_STRING:
			var k: String = CANON.canonical(Array(v["map"]))
			if not known.has(k):
				known[k] = where
		for key in v:
			_collect(v[key], where, known)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_collect(x, where, known)


# --- Every board in the real play screen -------------------------------------------------------

## Each board through SocialPlay exactly as the page plays it (page parsing,
## dev assistance), solved move by move with SHOW A MOVE's own choice; the
## page's action-log inference must name every tapped block.
func _play_every_board(data) -> void:
	LevelManager.dev_sequence = true
	LevelManager.dev_movable = true
	for b in data["boards"]:
		var p := SocialPlay.new()
		p.dev_assist = true
		p.max_hammers = 0
		add_child(p)
		var def := PuzzleDefinition.from_dict(b["puzzle"])
		p.start(SharedChallenge.friend_challenge(def, FriendGenerator.VERY_HARD), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
		await _frames(2)
		var ok_tap := true
		var first_bad := ""
		var guard := 0
		while not p.completed and guard < 80:
			var before := _snap(p)
			var id := Solver.from_model(p.model).recommend_move()
			if id == -1:
				break
			p.tap_block(id)
			await _wait(0.03)
			var inferred := VhHumanTest.infer_tap(before, _snap(p))
			if inferred != id and ok_tap:
				ok_tap = false
				var aft := _snap(p)
				var gone := before.keys().filter(func(k): return not aft.has(k))
				var moved := before.keys().filter(func(k): return aft.has(k) and aft[k] != before[k])
				first_bad = "tapped %d %s, inferred %d; gone %s; changed %s" % [id, str(before.get(id, [])), inferred, str(gone.map(func(k): return [k, before[k]])), str(moved.map(func(k): return [k, before[k], aft[k]]))]
			guard += 1
		_check(p.completed, "%s (%s): played to the end in SocialPlay (%d moves)" % [b["id"], b["recipe"], guard])
		_check(ok_tap, "%s: the action log names every tapped block %s" % [b["id"], first_bad])
		p.queue_free()
		await _frames(1)
	LevelManager.dev_sequence = false
	LevelManager.dev_movable = false


func _snap(p: SocialPlay) -> Dictionary:
	var out := {}
	for id in p.model.blocks:
		var bl: BlockData = p.model.blocks[id]
		out[id] = [bl.cell, bl.direction, bl.seq_stage, bl.armored, bl.kind]
	return out


# --- The page ----------------------------------------------------------------------------------

func _page_flow() -> void:
	var t := VhHumanTest.new("vhtest4")
	add_child(t)
	await _frames(3)
	_check(t.pilot and t.screen == VhHumanTest.Screen.INTRO and t.total() == 0 and t._intro_text.text.contains("Up to 28 puzzles"),
		"intro: up to 28 puzzles, nothing ordered before the campaign question")
	_check(LevelManager.dev_sequence and LevelManager.dev_movable, "campaign tokens parsed while the page runs")
	t._start.pressed.emit()
	_check(t.screen == VhHumanTest.Screen.PROFILE, "START -> 'How far have you played the campaign?'")
	t.set_reached(150)
	var early: Array = t.state["order"].map(func(i): return t.boards[i])
	_check(early.size() > 0 and early.all(func(b): return int(b["first_level"]) <= 150), "past level 150: only boards with mechanics up to level 150 (%d)" % early.size())
	t.set_reached(300)
	var order: Array = t.state["order"]
	_check(t.total() == 28 and order.size() == 28, "all 300 levels: every board offered")
	var balanced := true
	for r in 5:
		var round_groups := {}
		for k in 5:
			round_groups[t.boards[order[r * 5 + k]]["variant"]] = true
		balanced = balanced and round_groups.size() == 5
	_check(balanced, "balanced order: each of the first five rounds holds one board of every group")
	t._start.pressed.emit()
	_check(t.screen == VhHumanTest.Screen.BRIEF and t._brief_text.text.begins_with("PUZZLE 1 / 28"), "the reminder card before puzzle 1")
	var rec: Dictionary = t.boards[order[0]]
	for m in rec["mechanics"]:
		if VhHumanTest.REMINDERS.has(m) and m != "spinner_cw":
			_check(t._brief_text.text.contains(VhHumanTest.REMINDERS[m]), "reminder for %s" % m)
	_check(not t._brief_text.text.contains(rec["variant"]) and not t._brief_text.text.contains(rec["recipe"]), "the card never names the group or recipe")
	t.begin_puzzle()
	await _frames(3)
	var p := t.play
	_check(t.screen == VhHumanTest.Screen.PLAYING and p._title.text == "PUZZLE 1 / 28" and t._hud.visible and t._clock.is_visible_in_tree(),
		"puzzle 1 plays with the clock and GIVE UP")
	_check(p.max_undos == 3 and p.max_hints == 1 and p.max_hammers == 0, "assistance UNDO x3, SHOW A MOVE x1, HAMMER x0")
	var sid := Solver.from_model(p.model).recommend_move()
	p.tap_block(sid)
	await _wait(0.6)
	t.give_up()
	_check(t.screen == VhHumanTest.Screen.PLAYING and t._give_up.text.contains("AGAIN"), "GIVE UP: the first tap only asks again")
	t.give_up()
	_check(t.screen == VhHumanTest.Screen.RATE and t._rate_title.text.contains("NOT SOLVED"), "GIVE UP twice: not solved, then rated")
	t.rate(2)
	_check(t.screen == VhHumanTest.Screen.THINK and t._q_label.text.contains("Level 300") and _has_button(t, "Think_HARDER"), "then: compared with Level 300")
	t.think("HARDER")
	_check(t._q_label.text.contains("enjoy") and _has_button(t, "Think_5"), "then: enjoyment 1-5")
	t.think("4")
	_check(t._q_label.text.contains("achievement"), "then: sense of achievement 1-5")
	t.think("3")
	_check(t._q_label.text.contains("unfair") and _has_button(t, "Think_YES"), "then: random or unfair?")
	t.think("NO")
	var r: Dictionary = t.state["results"][0]
	_check(r["gave_up"] and not r["completed"] and r["rating"] == "HARD" and r["l300"] == "HARDER" and r["enjoy"] == "4" and r["achieve"] == "3" and r["unfair"] == "NO",
		"puzzle 1 recorded: gave up, HARD, harder than L300, enjoy 4, achieve 3, fair")
	var log: Array = r["log"]
	_check(log.size() >= 2 and log[0][1] == "m" and log[0][2] == sid and log[-1][1] == "g", "action log: the move (block %d) and the give-up" % sid)
	_check(t.screen == VhHumanTest.Screen.BRIEF and t._brief_text.text.begins_with("PUZZLE 2 / 28"), "next: the reminder card of puzzle 2")
	t.begin_puzzle()
	await _frames(2)
	var guard := 0
	while not p.completed and guard < 80:
		p.tap_block(Solver.from_model(p.model).recommend_move())
		await _wait(0.03)
		guard += 1
	await _wait(1.3)
	_check(t.screen == VhHumanTest.Screen.RATE and t._rate_title.text.contains("SOLVED"), "puzzle 2 solved -> rated")
	t.rate(3)
	for a in ["SIMILAR", "5", "5", "NO"]:
		t.think(a)
	var r2: Dictionary = t.state["results"][1]
	_check(r2["completed"] and not r2["gave_up"] and r2["log"].filter(func(e): return e[1] == "m").size() == guard and r2["log"].all(func(e): return e[1] != "m" or e[2] >= 0),
		"puzzle 2: every move logged with its block")
	# Resume after a reload: same order, reached kept.
	var t2 := VhHumanTest.new("vhtest4")
	add_child(t2)
	await _frames(2)
	_check(t2.state["order"] == order and int(t2.state["reached"]) == 300 and t2.state["results"].size() == 2 and t2._start.text.begins_with("CONTINUE  3 / 28"),
		"after a reload: same order and progress, CONTINUE 3 / 28")
	_check(t2.screen == VhHumanTest.Screen.INTRO, "the reloaded page waits at the intro")
	t2.queue_free()
	# The end: the hardest puzzle, then the results with every group named.
	t.play.end()
	t.state["index"] = t.total()
	t.start_next()
	_check(t.screen == VhHumanTest.Screen.HARDEST and _has_button(t, "Hardest_2"), "after the last puzzle: which was the hardest?")
	t.set_hardest(2, "too many turns")
	var ex = JSON.parse_string(t.results_json())
	_check(t.screen == VhHumanTest.Screen.RESULTS and ex["hardest"]["order"] == 2 and ex["hardest"]["id"] == order[1] and ex["hardest"]["why"] == "too many turns"
		and int(ex["reached"]) == 300 and ex["results"].size() == 2, "results JSON: hardest + why, campaign progress, both puzzles")
	_check(t._results_text.text.contains("Group ") and t._results_text.text.contains("harder than L300"), "results name the groups only at the end")
	# &bench: the recipient's check and SHOW A MOVE timed on every board.
	await t._run_bench()
	_check(t.bench_results.size() == 28 and t.bench_results.all(func(x): return x["verify_nodes"] > 0 and x.has("hint_ms")), "bench: every board timed (check + SHOW A MOVE)")
	t.queue_free()
	await _frames(1)
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")
	LevelManager.dev_sequence = false
	LevelManager.dev_movable = false


func _has_button(t: VhHumanTest, n: String) -> bool:
	for b in t.find_children("*", "BaseButton", true, false):
		if String(b.name) == n and b.is_visible_in_tree():
			return true
	return false


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
