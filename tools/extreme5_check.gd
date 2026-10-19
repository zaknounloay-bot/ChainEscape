extends Node
## EXTREME RESEARCH (development only, ?xtest5=1): end-to-end checks.
##   godot --headless --path . res://tools/Extreme5Check.tscn
## Board file integrity (3-5 prototypes, one per hypothesis, live VERY HARD
## assistance, every board exact, parsed intact by the page, Solver-valid
## within the recipient's 60000 nodes and the 20000-node working budget, at
## most 7x7 and 16 pieces, solution <= 22 taps, mechanics recorded
## truthfully, every mechanic mattering, the EXTREME acceptance measures
## recorded and met, the mobile time budget, no duplicate of a campaign
## level, an earlier test / pilot / lab board or another prototype); every
## board played to the end in the real SocialPlay with the tapped block
## inferred correctly; the page flow: campaign progress, reminder card,
## clock, GIVE UP, the five-step rating (EASY ... EXTREME), the five
## questions (vs Level 300, enjoyment, achievement, fairness, planning),
## blocked taps in the action log, results, reload, &bench.

const PROGRESS_PATH := "user://extreme5_check_progress.cfg"
const CANON := preload("res://tools/vh_pilot4_canon.gd")
const DATA := "res://data/dev/extreme5.json"
const FIRST_MAGNET := 76

var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS["xtest5"]["state"]))
	_run.call_deferred()


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_check_data(data)
	await _play_every_board(data)
	await _page_flow(data)
	print("EXTREME5 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _dev(on: bool) -> void:
	LevelManager.dev_sequence = on
	LevelManager.dev_movable = on
	LevelManager.dev_magnet = on


static func mechanics(map: Array) -> Array:
	var out: Array = CANON.mechanics(map)
	for row in map:
		for t in String(row).split(" ", false):
			if t.length() >= 3 and t.ends_with("*") and not t.contains("@") and not out.has("magnet"):
				out.append("magnet")
	return out


# --- The board file --------------------------------------------------------------------------

func _check_data(data) -> void:
	_check(typeof(data) == TYPE_DICTIONARY and data.get("test") == "xtest5", "the EXTREME board file loads")
	var a: Dictionary = data["assist"]
	_check(int(a["undo"]) == 3 and int(a["show_a_move"]) == 1 and int(a["hammer"]) == 0, "live VERY HARD assistance: UNDO x3, SHOW A MOVE x1, HAMMER x0")
	var boards: Array = data["boards"]
	_check(boards.size() >= 3 and boards.size() <= 5, "3-5 prototypes (%d)" % boards.size())
	var hyps := {}
	for b in boards:
		hyps[b["variant"]] = true
	_check(hyps.size() == boards.size(), "one prototype per hypothesis (%s)" % str(hyps.keys()))
	var known := _known_keys()
	var keys := {}
	_dev(true)
	for b in boards:
		var id: String = b["id"]
		var def := PuzzleDefinition.from_dict(b["puzzle"])
		_check(def != null and Array(def.map) == Array(b["puzzle"]["map"]), "%s: exact stored board" % id)
		var level := def.to_level()
		var tokens := 0
		var magnets := 0
		for row in def.map:
			for t in String(row).split(" ", false):
				if t != ".":
					tokens += 1
				if t.length() >= 3 and t.ends_with("*") and not t.contains("@"):
					magnets += 1
		_check(level != null and level.blocks.size() == tokens and level.blocks.filter(func(x): return x.magnet).size() == magnets,
			"%s: every cell parses on the page (%d pieces, %d magnets)" % [id, tokens, magnets])
		_check(def.rows <= 7 and def.columns <= 7 and tokens <= 16, "%s: at most 7x7 and 16 pieces (%dx%d, %d)" % [id, def.columns, def.rows, tokens])
		var m := BoardModel.new()
		m.setup(level.rows, level.columns, level.blocks)
		m.set_portals(level.portals)
		var s := Solver.from_model(m)
		s.node_limit = Solver.DEFAULT_NODE_LIMIT
		var moves := s.solve_moves()
		_check(not s.aborted and not moves.is_empty(), "%s: solvable within the recipient's %d nodes (%d used)" % [id, Solver.DEFAULT_NODE_LIMIT, s.nodes])
		_check(s.nodes <= 20000, "%s: within the 20000-node working budget (%d)" % [id, s.nodes])
		var mech := mechanics(Array(def.map))
		_check(mech == b["mechanics"], "%s: mechanics recorded truthfully %s" % [id, str(mech)])
		var fl: int = 1
		for k in mech:
			fl = maxi(fl, FIRST_MAGNET if k == "magnet" else int(CANON.FIRST_LEVEL.get(k, 1)))
		_check(int(b["first_level"]) == fl, "%s: first level %d" % [id, fl])
		var key: String = CANON.canonical(Array(def.map))
		_check(key == b["canonical"] and not keys.has(key), "%s: no duplicate among the prototypes" % id)
		keys[key] = true
		_check(not known.has(key), "%s: not a campaign level, pilot, earlier test or lab board (%s)" % [id, known.get(key, "new")])
		_check(b["accepted"], "%s: passed every acceptance rule" % id)
		var met: Dictionary = b["metrics"]
		_check(int(met["solution_length"]) <= 22, "%s: solution of at most 22 taps (%d)" % [id, met["solution_length"]])
		for fam in ["lock", "switch", "gate", "armor", "portal", "sequence", "crate"]:
			if mech.has(fam):
				_check(float(met["impact"][fam]) >= 1.0, "%s: %s matters (impact %.1f)" % [id, fam, met["impact"][fam]])
		var x: Dictionary = b["x"]
		_check(float(x["best_rule_dead_ends"]) >= 3.0, "%s: every rule of thumb hits >= 3 dead ends (%.1f)" % [id, x["best_rule_dead_ends"]])
		_check(float(x["greedy_best"]) <= 0.05, "%s: no greedy player wins more than 5%% (%.3f)" % [id, x["greedy_best"]])
		_check(int(x["late_misleading_moves"]) >= 2, "%s: at least 2 distinct plausible losing moves that fail late (%d)" % [id, x["late_misleading_moves"]])
		if mech.has("magnet"):
			_check(x["magnet_matters"]["matters"], "%s: the magnets matter %s" % [id, str(x["magnet_matters"])])
		var h: Dictionary = met["hint"]
		_check(not h["aborted"] and h["consistent"], "%s: SHOW A MOVE within budget and always finds a move on the solution" % id)
		var slowest := maxf(b["verify"]["ms_desktop"], maxf(h["max_ms_desktop"], h["dead_max_ms_desktop"]))
		_check(slowest <= 40.0, "%s: within the mobile time budget when built (%.1f ms desktop)" % [id, slowest])
		var runs: Array = x.get("time_runs_ms", [])
		_check(runs.size() >= 5 and runs.all(func(t): return float(t) <= 40.0), "%s: within the mobile budget in every repeated measurement %s" % [id, str(runs)])
		_check(str(b.get("why", "")).length() > 80 and b.get("misleading_moves", []).size() >= 2, "%s: written explanation and misleading moves" % id)
	_dev(false)


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
			if f.ends_with(".json") and not f.begins_with("extreme5"):
				_collect(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f))), dir.path_join(f), known)
	return known


func _collect(v, where: String, known: Dictionary) -> void:
	if typeof(v) == TYPE_DICTIONARY:
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

func _play_every_board(data) -> void:
	_dev(true)
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
				first_bad = "tapped %d, inferred %d" % [id, inferred]
			guard += 1
		_check(p.completed, "%s (%s): played to the end in SocialPlay (%d moves)" % [b["id"], b["recipe"], guard])
		_check(ok_tap, "%s: the action log names every tapped block %s" % [b["id"], first_bad])
		p.queue_free()
		await _frames(1)
	_dev(false)


func _snap(p: SocialPlay) -> Dictionary:
	var out := {}
	for id in p.model.blocks:
		var bl: BlockData = p.model.blocks[id]
		out[id] = [bl.cell, bl.direction, bl.seq_stage, bl.armored, bl.kind]
	return out


# --- The page ----------------------------------------------------------------------------------

func _page_flow(data) -> void:
	var n: int = data["boards"].size()
	var t := VhHumanTest.new("xtest5")
	add_child(t)
	await _frames(3)
	_check(t.pilot and t.ratings.size() == 5 and t.screen == VhHumanTest.Screen.INTRO and t.total() == 0, "intro: EXTREME research page, nothing ordered yet")
	_check(t._intro_text.text.contains("six quick questions"), "intro announces six questions after each puzzle")
	_check(LevelManager.dev_magnet and LevelManager.dev_sequence and LevelManager.dev_movable, "campaign tokens (Magnet, Sequence, Movable) parsed while the page runs")
	t._start.pressed.emit()
	_check(t.screen == VhHumanTest.Screen.PROFILE, "START -> 'How far have you played the campaign?'")
	t.set_reached(300)
	var order: Array = t.state["order"]
	_check(t.total() == n and order.size() == n, "all 300 levels: every prototype offered (%d)" % n)
	t._start.pressed.emit()
	_check(t.screen == VhHumanTest.Screen.BRIEF and t._brief_text.text.begins_with("PUZZLE 1 / %d" % n), "the reminder card before puzzle 1")
	var rec: Dictionary = t.boards[order[0]]
	for m in rec["mechanics"]:
		if VhHumanTest.REMINDERS.has(m) and m != "spinner_cw":
			_check(t._brief_text.text.contains(VhHumanTest.REMINDERS[m]), "reminder for %s" % m)
	_check(not t._brief_text.text.contains(rec["variant"]) and not t._brief_text.text.contains(rec["recipe"]), "the card never names the hypothesis")
	t.begin_puzzle()
	await _frames(3)
	var p := t.play
	_check(t.screen == VhHumanTest.Screen.PLAYING and t._hud.visible, "puzzle 1 plays with the clock and GIVE UP")
	_check(p._chip.text == "", "no difficulty label on the play screen (no anchoring)")
	_check(p.max_undos == 3 and p.max_hints == 1 and p.max_hammers == 0, "assistance UNDO x3, SHOW A MOVE x1, HAMMER x0")
	# A blocked tap (a block that can't move now), then a real move.
	var s := Solver.from_model(p.model)
	var legal := {}
	for mv in s.legal_moves():
		legal[mv & Solver.ID_MASK] = true
	var stuck := -1
	for id in p.model.blocks:
		var bl: BlockData = p.model.blocks[id]
		if not legal.has(id) and bl.kind == BlockData.Kind.NORMAL:
			stuck = id
			break
	if stuck >= 0:
		p.tap_block(stuck)
		await _wait(0.6)
	var sid := Solver.from_model(p.model).recommend_move()
	p.tap_block(sid)
	await _wait(0.6)
	t.give_up()
	t.give_up()
	_check(t.screen == VhHumanTest.Screen.RATE and _has_button(t, "Rate_EXTREME") and _has_button(t, "Rate_VERY_HARD"), "GIVE UP twice -> the five-step rating with EXTREME")
	t.rate(4)
	_check(t._q_label.text.contains("Level 300"), "then: compared with Level 300")
	t.think("HARDER")
	_check(t._q_label.text.contains("enjoy"), "then: enjoyment 1-5")
	t.think("4")
	_check(t._q_label.text.contains("achievement"), "then: achievement 1-5")
	t.think("5")
	_check(t._q_label.text.contains("fair") and _has_button(t, "Think_MOSTLY"), "then: fairness (YES / MOSTLY / NO)")
	t.think("MOSTLY")
	_check(t._q_label.text.contains("planning") and _has_button(t, "Think_A_LITTLE"), "then: real planning (YES / A LITTLE / NO)")
	t.think("YES")
	var r: Dictionary = t.state["results"][0]
	_check(r["gave_up"] and r["rating"] == "EXTREME" and r["l300"] == "HARDER" and r["enjoy"] == "4" and r["achieve"] == "5" and r["fair"] == "MOSTLY" and r["planned"] == "YES",
		"puzzle 1 recorded: gave up, EXTREME, harder than L300, enjoy 4, achieve 5, mostly fair, needed planning")
	var log: Array = r["log"]
	_check(stuck < 0 or (log.size() >= 3 and log[0][1] == "b" and r["blocked_taps"] >= 1), "action log: the blocked tap first (%s)" % str(log.slice(0, 3)))
	_check(log.any(func(e): return e[1] == "m" and e[2] == sid) and log[-1][1] == "g", "action log: the move (block %d) and the give-up" % sid)
	_check(t.screen == VhHumanTest.Screen.BRIEF, "next: the reminder card of puzzle 2")
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
	for ans in ["SIMILAR", "5", "5", "YES", "A LITTLE"]:
		t.think(ans)
	var r2: Dictionary = t.state["results"][1]
	_check(r2["completed"] and r2["rating"] == "VERY HARD" and r2["planned"] == "A LITTLE" and r2["log"].filter(func(e): return e[1] == "m").size() == guard
		and r2["log"].all(func(e): return e[1] != "m" or e[2] >= 0), "puzzle 2: every move logged with its block")
	var t2 := VhHumanTest.new("xtest5")
	add_child(t2)
	await _frames(2)
	_check(t2.state["order"] == order and t2.state["results"].size() == 2 and t2._start.text.begins_with("CONTINUE  3 / %d" % n), "after a reload: same order and progress")
	t2.queue_free()
	t.play.end()
	t.state["index"] = t.total()
	t.start_next()
	_check(t.screen == VhHumanTest.Screen.HARDEST, "after the last puzzle: which was the hardest?")
	t.set_hardest(1, "had to plan the order")
	var ex = JSON.parse_string(t.results_json())
	_check(ex["test"] == "xtest5" and ex["hardest"]["id"] == order[0] and ex["results"].size() == 2, "results JSON: test, hardest + why, both puzzles")
	var sm: Dictionary = ex["summary"]
	var first: Dictionary = sm[t.boards[order[0]]["variant"]]
	_check(first.get("extreme", 0) == 1 and first.has("avg_rating_1to5") and first.get("planned", -1) == 1, "summary: EXTREME count, 1-5 average, planning")
	_check(t._results_text.text.contains("rated") and t._results_text.text.contains("/ 5"), "results text on the five-step scale")
	# Every board: the clock and GIVE UP sit above the board, never over it.
	for k in n:
		t.state["index"] = k
		t.begin_puzzle()
		await _frames(4)
		var top: float = t.play.board.get_board_rect().position.y
		var hud_end := maxf(t._give_up.get_global_rect().end.y, t._clock.get_global_rect().end.y)
		_check(hud_end <= top, "%s: clock and GIVE UP above the board (%.0f <= %.0f)" % [order[k], hud_end, top])
		t.play.end()
	t.state["index"] = t.total()
	await t._run_bench()
	_check(t.bench_results.size() == n and t.bench_results.all(func(x): return x["verify_nodes"] > 0 and x.has("hint_ms") and x.has("dead_hint_ms")),
		"bench: every board timed (check, SHOW A MOVE, SHOW A MOVE after a mistake)")
	t.queue_free()
	await _frames(1)
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")
	_dev(false)


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
