extends "res://tools/extreme7_check.gd"
## VERY HARD VALIDATION (development only, ?vhval3=1): end-to-end checks.
##   godot --headless --path . res://tools/VhVal3Check.tscn
## The three boards are EXACT copies of T3 / T5 (extreme5.json) and H2
## (extreme7.json): same puzzle record, same fingerprint, recomputed from the
## map; the sources unchanged; neutral ids and groups; no solution text in
## the file; every board parsed intact, Solver-valid within the working
## budget, played to the end in the real SocialPlay; SHOW A MOVE after
## plausible mistakes; the page flow (random order, blind cards, five-step
## rating, six questions, hardest puzzle, results with every recorded
## measure, bench); the other test pages and their storage unaffected.

const DATA_V := "res://data/dev/vh_validation3.json"
## The source files as they were when the boards were first tested.
const X7_SHA256 := "199e788c7115b64844251c48525a4908ee8db7b2e54201e5992a2972d9646bb6"
const WANT := {"T3": "res://data/dev/extreme5.json", "T5": "res://data/dev/extreme5.json", "H2": "res://data/dev/extreme7.json"}


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS["vhval3"]["state"]))
	_run.call_deferred()


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_V))
	_check(FileAccess.get_file_as_string("res://data/dev/extreme5.json").sha256_text() == T15_SHA256, "source extreme5.json (T1-T5) unchanged")
	_check(FileAccess.get_file_as_string("res://data/dev/extreme6.json").sha256_text() == P12_SHA256, "extreme6.json (P1-P2) unchanged")
	_check(FileAccess.get_file_as_string("res://data/dev/extreme7.json").sha256_text() == X7_SHA256, "source extreme7.json (H1-H2) unchanged")
	_check_copies(data)
	# The shared play-through names each board's recipe: give it the neutral
	# group here (the test file itself has no recipe field).
	var play_data := {"boards": data["boards"].map(func(b): return b.merged({"recipe": "group " + str(b["variant"])}))}
	await _play_every_board(play_data)
	await _hints_after_mistakes(data)
	await _page_flow_v(data)
	print("VHVAL3 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_copies(data) -> void:
	_check(typeof(data) == TYPE_DICTIONARY and data.get("test") == "vhval3", "the validation board file loads")
	var a: Dictionary = data["assist"]
	_check(int(a["undo"]) == 3 and int(a["show_a_move"]) == 1 and int(a["hammer"]) == 0, "live VERY HARD tools: UNDO x3, SHOW A MOVE x1, HAMMER x0")
	var boards: Array = data["boards"]
	_check(boards.size() == 3, "exactly three boards (%d)" % boards.size())
	var ids := boards.map(func(b): return str(b["id"]))
	var groups := boards.map(func(b): return str(b["variant"]))
	ids.sort()
	groups.sort()
	_check(ids == ["V1", "V2", "V3"] and groups == ["X", "Y", "Z"], "neutral ids V1-V3 and groups X-Z")
	var seen := {}
	_dev(true)
	for b in boards:
		var id: String = b["id"]
		var o: Dictionary = b.get("original", {})
		var name := str(o.get("id", ""))
		_check(WANT.has(name) and "res://" + str(o.get("file", "")) == WANT[name] and not seen.has(name), "%s: copy of %s from %s" % [id, name, o.get("file", "?")])
		seen[name] = true
		var src := {}
		for s in JSON.parse_string(FileAccess.get_file_as_string(WANT.get(name, DATA_V)))["boards"]:
			if str(s["id"]) == name:
				src = s
		_check(not src.is_empty() and b["puzzle"] == src["puzzle"], "%s: the puzzle record is identical to %s (map, size, rules)" % [id, name])
		var fp := JSON.stringify(b["puzzle"]["map"]).sha256_text()
		_check(fp == b["fingerprint"] and fp == src.get("fingerprint", "") and fp == o.get("fingerprint", ""), "%s: fingerprint %s... matches the original %s" % [id, fp.substr(0, 12), name])
		_check(b["canonical"] == src.get("canonical", "") and b["mechanics"] == src.get("mechanics", []) and int(b["first_level"]) == int(src.get("first_level", -1)), "%s: canonical form, mechanics and first level as in the original" % id)
		for k in ["title", "why", "misleading_moves", "rules_defeated", "recipe", "source"]:
			_check(not b.has(k), "%s: no '%s' (no names or solution text in the test file)" % [id, k])
		var def := PuzzleDefinition.from_dict(b["puzzle"])
		var level := def.to_level()
		var tokens := 0
		for row in def.map:
			for t in String(row).split(" ", false):
				tokens += 0 if t == "." else 1
		_check(level != null and level.blocks.size() == tokens, "%s: every cell parses on the page (%d pieces)" % [id, tokens])
		var s := Solver.from_model(EVENTS.model_of(level))
		var moves := s.solve_moves()
		_check(not s.aborted and not moves.is_empty() and s.nodes <= 20000, "%s: solvable within the 20000-node working budget (%d nodes; recipient limit %d)" % [id, s.nodes, Solver.DEFAULT_NODE_LIMIT])
	_check(seen.size() == 3, "T3, T5 and H2 each present once")
	_dev(false)


# --- The page ----------------------------------------------------------------------------------

func _page_flow_v(data) -> void:
	var n: int = data["boards"].size()
	var originals: Array = data["boards"].map(func(b): return str(b["original"]["id"]))
	var t := VhHumanTest.new("vhval3")
	add_child(t)
	await _frames(3)
	_check(t.pilot and t.ratings == ["EASY", "MEDIUM", "HARD", "VERY HARD", "EXTREME"] and t._questions.size() == 6 and t.demos.is_empty(),
		"vhval3: five-step rating, six questions (vs L300, enjoyment, achievement, fairness, planning, combination), no demos")
	_check(not _mentions(t._intro_text.text, originals) and not t._intro_text.text.to_upper().contains("VERY HARD"), "intro names no puzzle and no difficulty")
	t._start.pressed.emit()
	# Campaign progress filters the boards (a player who has not reached a
	# mechanic does not get it): below Level 151 the armor board is held back.
	t.set_reached(130)
	_check(t.state["order"].size() == 2, "progress 130: only the two boards whose mechanics come before Level 151 (%d)" % t.state["order"].size())
	t.set_reached(300)
	var orders := {}
	for k in 12:
		t._new_order()
		orders[str(t.state["order"])] = true
	_check(orders.size() >= 3, "the order is randomised per tester (%d different orders in 12 draws)" % orders.size())
	t.set_reached(300)
	var order: Array = t.state["order"]
	_check(order.size() == n, "all 300 levels: every board offered (%d)" % n)
	var guard := 0
	var first := true
	while t.screen != VhHumanTest.Screen.HARDEST and guard < 20:
		guard += 1
		if t.screen == VhHumanTest.Screen.INTRO:
			t._start.pressed.emit()
		if t.screen != VhHumanTest.Screen.BRIEF:
			break
		var idx := int(t.state["index"])
		_check(t._brief_go.text == "START PUZZLE" and t._brief_text.text.begins_with("PUZZLE %d / %d" % [idx + 1, n]) and not _mentions(t._brief_text.text, originals),
			"puzzle card %d: neutral, names no original board" % (idx + 1))
		t.begin_from_card()
		await _frames(3)
		var p := t.play
		_check(t.screen == VhHumanTest.Screen.PLAYING and p._chip.text == "" and t._hud.visible and p.max_undos == 3 and p.max_hints == 1 and p.max_hammers == 0,
			"puzzle %d plays: no difficulty label, clock, GIVE UP, UNDO x3 / SHOW A MOVE x1 / HAMMER x0" % (idx + 1))
		if first:
			# A blocked tap, an UNDO and a RESTART are recorded.
			first = false
			var blocked := -1
			for id in p.model.blocks:
				if p.model.move_state(id) == "blocked":
					blocked = id
			if blocked >= 0:
				p.tap_block(blocked)
				await _wait(0.05)
			p.play_solver_move()
			await _wait(0.05)
			p.undo()
			await _wait(0.05)
			p.restart()
			await _wait(0.1)
		var k := 0
		while not p.completed and k < 60:
			p.tap_block(Solver.from_model(p.model).recommend_move())
			await _wait(0.03)
			k += 1
		await _wait(1.3)
		_check(t.screen == VhHumanTest.Screen.RATE and _has_button(t, "Rate_EXTREME") and _has_button(t, "Rate_EASY"), "puzzle %d solved in the real play screen -> EASY ... EXTREME" % (idx + 1))
		t.rate(3)
		for ans in ["SIMILAR", "4", "4", "YES", "A LITTLE"]:
			t.think(ans)
		_check(t._q_label.text.contains("combination") and _has_button(t, "Think_A_LITTLE"), "the combination question")
		t.think("YES")
	_check(t.screen == VhHumanTest.Screen.HARDEST and t.state["results"].size() == n, "all %d puzzles played -> which was the most challenging, and why" % n)
	var r0: Dictionary = t.state["results"][0]
	_check(r0["completed"] and int(r0["restarts"]) >= 1 and int(r0["undos"]) >= 1 and r0.has("show_a_move") and r0.has("time_ms") and r0.has("gave_up")
		and r0["log"].any(func(e): return e[1] == "b") and r0["log"].any(func(e): return e[1] == "m") and r0["log"].any(func(e): return e[1] == "u") and r0["log"].any(func(e): return e[1] == "r"),
		"recorded: solve time, restarts, UNDO, SHOW A MOVE, give-up, blocked taps and the move sequence")
	_check(t.state["results"].all(func(r): return r.has("l300") and r.has("enjoy") and r.has("achieve") and r.has("fair") and r.has("planned") and r.has("combo") and r.has("rating")),
		"every puzzle: difficulty, enjoyment, achievement, fairness, planning, combination, vs Level 300")
	t.set_hardest(2, "the second one")
	var ex = JSON.parse_string(t.results_json())
	_check(ex["test"] == "vhval3" and ex["results"].size() == n and ex["hardest"]["why"] == "the second one", "results JSON: the test, every puzzle, the hardest and why")
	_check(not _mentions(t.results_json(), originals) and not t.results_json().contains("original"), "results JSON uses neutral ids only")
	await t._run_bench()
	_check(t.bench_results.size() == n and t.bench_results.all(func(x): return x["verify_nodes"] > 0 and x.has("hint_ms") and x.has("dead_hint_ms")), "bench: every board timed")
	t.queue_free()
	await _frames(1)
	for key in ["xtest5", "xtest6", "xtest7"]:
		var o := VhHumanTest.new(key)
		add_child(o)
		await _frames(2)
		_check(o.boards.size() == {"xtest5": 5, "xtest6": 2, "xtest7": 2}[key], "?%s unchanged: its own boards (%d)" % [key, o.boards.size()])
		o.queue_free()
		await _frames(1)
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")
	_dev(false)


func _mentions(text: String, names: Array) -> bool:
	for nm in names:
		if text.contains(nm):
			return true
	return false
