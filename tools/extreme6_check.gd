extends "res://tools/extreme5_check.gd"
## EXTREME PHASE 2 (development only, ?xtest6=1): end-to-end checks.
##   godot --headless --path . res://tools/Extreme6Check.tscn
## Board file (1-6 candidates (six asked for; fewer when the gates are not met), at most two per group A / B / C, the same
## per-board technical and EXTREME acceptance as T1-T5 with <= 14 pieces and
## <= 18 taps, each group's central idea on the solution replayed through
## BoardModel, the two boards of a group not variants of each other, no
## duplicate of a campaign level, an earlier test / pilot / lab board, T1-T5
## or a demo); the demos (each solvable, and EVERY winning line uses its
## rule, checked exhaustively; tiny and readable); every board and demo
## played to the end in the real SocialPlay; the page flow with demos, the
## five-step rating, the six questions and the results; T1-T5 untouched.

const DATA6 := "res://data/dev/extreme6.json"
const EVENTS := preload("res://tools/extreme6_events.gd")
const BUILDER_SIMILAR := preload("res://tools/extreme5_build.gd")
## data/dev/extreme5.json as committed at d7c1aeb (T1-T5 must not change).
const T15_SHA256 := "76556b50c12b0a46c2fc486e3160b14a39bedb35c1ff6a80ba68471fbc79216b"


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS["xtest6"]["state"]))
	_run.call_deferred()


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA6))
	_check(FileAccess.get_file_as_string("res://data/dev/extreme5.json").sha256_text() == T15_SHA256, "T1-T5 board file unchanged since d7c1aeb")
	_check_data6(data)
	_check_demos(data)
	await _play_every_board(data)
	await _play_demos(data)
	await _page_flow6(data)
	print("EXTREME6 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_data6(data) -> void:
	_check(typeof(data) == TYPE_DICTIONARY and data.get("test") == "xtest6", "the phase-2 board file loads")
	var a: Dictionary = data["assist"]
	_check(int(a["undo"]) == 3 and int(a["show_a_move"]) == 1 and int(a["hammer"]) == 0, "live VERY HARD assistance: UNDO x3, SHOW A MOVE x1, HAMMER x0")
	var boards: Array = data["boards"]
	# Six were asked for; fewer when the quality gates cannot be met (the
	# report names the shortfall). The check tests what is there.
	_check(boards.size() >= 1 and boards.size() <= 6, "1-6 candidates (%d of the 6 asked for)" % boards.size())
	var per := {}
	for b in boards:
		per[b["variant"]] = per.get(b["variant"], []) + [b]
	_check(per.keys().all(func(k): return k in ["A", "B", "C"]) and per.values().all(func(l): return l.size() <= 2), "at most two per group A / B / C (%s)" % str(per.keys()))
	for g in per:
		if per[g].size() == 2:
			_check(not BUILDER_SIMILAR._too_similar(Array(per[g][0]["puzzle"]["map"]), Array(per[g][1]["puzzle"]["map"])), "group %s: its two boards are not variants of each other" % g)
	var known := _known_keys()
	_collect(JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme5.json")), "extreme5.json (T1-T5)", known)
	for d in data.get("demos", []):
		known[CANON.canonical(Array(d["puzzle"]["map"]))] = "demo " + d["id"]
	var keys := {}
	_dev(true)
	for b in boards:
		var id: String = b["id"]
		var def := PuzzleDefinition.from_dict(b["puzzle"])
		_check(def != null and Array(def.map) == Array(b["puzzle"]["map"]), "%s: exact stored board" % id)
		var level := def.to_level()
		var tokens := 0
		var magnets := 0
		var portal_cells := 0
		for row in def.map:
			for t in String(row).split(" ", false):
				if t == ".":
					continue
				if t.length() == 2 and t[0] == "O":
					portal_cells += 1
				else:
					tokens += 1
				if t.length() >= 3 and t.ends_with("*") and not t.contains("@"):
					magnets += 1
		_check(level != null and level.blocks.size() == tokens and level.portals.size() == portal_cells and level.blocks.filter(func(x): return x.magnet).size() == magnets,
			"%s: every cell parses on the page (%d blocks, %d portal cells, %d magnets)" % [id, tokens, portal_cells, magnets])
		var cap := 16 if b["variant"] == "C" else 14
		_check(def.rows <= 7 and def.columns <= 7 and tokens + portal_cells <= cap, "%s: at most 7x7 and %d pieces (%dx%d, %d)" % [id, cap, def.columns, def.rows, tokens + portal_cells])
		var s := Solver.from_model(EVENTS.model_of(level))
		s.node_limit = Solver.DEFAULT_NODE_LIMIT
		var moves := s.solve_moves()
		_check(not s.aborted and not moves.is_empty() and s.nodes <= 20000, "%s: solvable within the 20000-node working budget (%d nodes)" % [id, s.nodes])
		var mech := mechanics(Array(def.map))
		_check(mech == b["mechanics"], "%s: mechanics recorded truthfully %s" % [id, str(mech)])
		var fl: int = 1
		for k in mech:
			fl = maxi(fl, FIRST_MAGNET if k == "magnet" else int(CANON.FIRST_LEVEL.get(k, 1)))
		_check(int(b["first_level"]) == fl, "%s: first level %d" % [id, fl])
		var key: String = CANON.canonical(Array(def.map))
		_check(key == b["canonical"] and not keys.has(key), "%s: no duplicate among the candidates" % id)
		keys[key] = true
		_check(not known.has(key), "%s: not a campaign level, T1-T5, pilot, earlier test, lab board or demo (%s)" % [id, known.get(key, "new")])
		_check(b["accepted"], "%s: passed every acceptance rule" % id)
		var met: Dictionary = b["metrics"]
		_check(int(met["solution_length"]) <= 18, "%s: solution of at most 18 taps (%d)" % [id, met["solution_length"]])
		for fam in ["lock", "switch", "gate", "armor", "portal", "sequence", "crate"]:
			if mech.has(fam):
				_check(float(met["impact"][fam]) >= 1.0, "%s: %s matters (impact %.1f)" % [id, fam, met["impact"][fam]])
		var x: Dictionary = b["x"]
		_check(float(x["best_rule_dead_ends"]) >= 3.0 and float(x["greedy_best"]) <= 0.05, "%s: survives the rules of thumb (%.1f dead ends) and greedy play (%.3f)" % [id, x["best_rule_dead_ends"], x["greedy_best"]])
		_check(int(x["late_misleading_moves"]) >= 2, "%s: at least 2 distinct plausible losing moves that fail late (%d)" % [id, x["late_misleading_moves"]])
		if mech.has("magnet"):
			_check(x["magnet_matters"]["matters"], "%s: the magnets matter %s" % [id, str(x["magnet_matters"])])
		var ev := EVENTS.events(level)
		var fails := EVENTS.idea_fails(b["variant"], ev)
		_check(fails.is_empty(), "%s: the group's central idea happens on the solution, replayed in BoardModel %s %s" % [id, str(fails), str(ev)])
		var h: Dictionary = met["hint"]
		_check(not h["aborted"] and h["consistent"], "%s: SHOW A MOVE within budget and always finds a move on the solution" % id)
		var runs: Array = x.get("time_runs_ms", [])
		_check(runs.size() >= 5 and runs.all(func(t): return float(t) <= 40.0), "%s: within the mobile budget in every repeated measurement %s" % [id, str(runs)])
		_check(str(b.get("why", "")).length() > 80 and b.get("misleading_moves", []).size() >= 2, "%s: written explanation and misleading moves" % id)
	_dev(false)


## Known boards: campaign 1-300 and every development board file except this
## test's own (T1-T5 are added by the caller).
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
			if f.ends_with(".json") and not f.begins_with("extreme6"):
				_collect(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f))), dir.path_join(f), known)
	return known


## The demos: tiny, solvable, and EVERY winning line uses the demo's rule
## (exhaustive over every reachable position).
func _check_demos(data) -> void:
	var demos: Array = data.get("demos", [])
	var groups := {}
	for b in data["boards"]:
		groups[b["variant"]] = true
	for g in ["A", "B"]:
		if groups.has(g):
			_check(demos.any(func(d): return d["group"] == g), "group %s (a combination the campaign never used) has a demo" % g)
	_check(not demos.any(func(d): return d["group"] == "C"), "no demo for group C (portal + spinner + gate is taught in the campaign)")
	_dev(true)
	for d in demos:
		var level := PuzzleDefinition.from_dict(d["puzzle"]).to_level()
		var tokens := 0
		for row in d["puzzle"]["map"]:
			for t in String(row).split(" ", false):
				tokens += 0 if t == "." else 1
		_check(level.blocks.size() == tokens and tokens <= 6 and level.rows <= 3 and level.columns <= 4, "%s: tiny (%d pieces, %dx%d) and parses" % [d["id"], tokens, level.columns, level.rows])
		var lines := []
		_all_wins(EVENTS.model_of(level), [], lines)
		var every := not lines.is_empty()
		for l in lines:
			var e := _demo_events(level, l)
			match d["id"]:
				"DA1": every = every and e["reversed_pulls"] > 0
				"DA2": every = every and e["gate_then_pull"] > 0
				"DB1": every = every and e["pulled_then_rammed"] > 0
		_check(every, "%s: solvable, and every winning line (%d) uses the demo's rule" % [d["id"], lines.size()])
		_check(str(d["text"]).length() < 130 and not str(d["text"]).to_lower().contains("solution"), "%s: one neutral rule sentence" % d["id"])
	_dev(false)


func _all_wins(m: BoardModel, path: Array, out: Array) -> void:
	if m.is_empty():
		out.append(path.duplicate())
		return
	for id in m.blocks.keys():
		var st := m.move_state(id)
		if st != "ok" and st != "ram":
			continue
		var snap := m.snapshot()
		if st == "ok":
			m.remove(id)
		else:
			m.ram(id)
		path.append(id)
		_all_wins(m, path, out)
		path.pop_back()
		m.restore(snap)


func _demo_events(level: LevelData, line: Array) -> Dictionary:
	var m := EVENTS.model_of(level)
	var flips := {}
	var pa := {}
	var gate_open := false
	var e := {"reversed_pulls": 0, "pulled_then_rammed": 0, "gate_then_pull": 0}
	for id in line:
		if m.move_state(id) == "ram":
			if pa.has(m.ram(id)):
				e["pulled_then_rammed"] += 1
			continue
		var b: BlockData = m.blocks[id]
		var mag := b.magnet
		var rev := int(flips.get(id, 0)) % 2 == 1
		m.remove(id)
		for f in m.last_flipped:
			flips[f] = int(flips.get(f, 0)) + 1
		if not m.last_opened_gates.is_empty():
			gate_open = true
		if mag and not m.last_pull.is_empty():
			e["reversed_pulls"] += 1 if rev else 0
			e["gate_then_pull"] += 1 if gate_open else 0
			if m.blocks[m.last_pull["block"]].armored:
				pa[m.last_pull["block"]] = true
	return e


func _play_demos(data) -> void:
	await _play_every_board({"boards": data.get("demos", []).map(func(d): return {"id": d["id"], "recipe": "demo", "puzzle": d["puzzle"]})})


# --- The page ----------------------------------------------------------------------------------

func _page_flow6(data) -> void:
	var n: int = data["boards"].size()
	var t := VhHumanTest.new("xtest6")
	add_child(t)
	await _frames(3)
	_check(t.pilot and t.ratings.size() == 5 and t._questions.size() == 6 and t._intro_text.text.contains("seven quick questions"), "xtest6: five-step rating, six questions (announced as seven with the rating)")
	_check(t.demos.size() == data.get("demos", []).size(), "xtest6: the demos are loaded")
	t._start.pressed.emit()
	t.set_reached(300)
	var order: Array = t.state["order"]
	_check(order.size() == n, "all 300 levels: every candidate offered (%d)" % n)
	# Walk the whole test: every card, every demo, every puzzle (solved by the
	# solver's moves through the real play screen), every question.
	var demo_seen := []
	var groups_before_demo := {}
	var guard := 0
	while t.screen != VhHumanTest.Screen.HARDEST and guard < 40:
		guard += 1
		if t.screen == VhHumanTest.Screen.INTRO:
			t._start.pressed.emit()
		if t.screen != VhHumanTest.Screen.BRIEF:
			break
		var g: String = t.boards[order[t.state["index"]]]["variant"]
		if not t._demo.is_empty():
			_check(t._brief_text.text.contains("A NEW COMBINATION") and t._brief_go.text == "TRY IT" and t._demo["group"] == g,
				"demo card %s before the first %s puzzle" % [t._demo["id"], g])
			demo_seen.append(t._demo["id"])
			t.begin_from_card()
			await _frames(3)
			_check(t.screen == VhHumanTest.Screen.PLAYING and t.play._title.text == "TRY IT" and t.play._chip.text == "", "%s plays as TRY IT, no difficulty label" % demo_seen[-1])
			var k := 0
			while not t.play.completed and k < 20:
				t.play.tap_block(Solver.from_model(t.play.model).recommend_move())
				await _wait(0.03)
				k += 1
			await _wait(1.4)
			continue
		groups_before_demo[g] = true
		_check(t._brief_go.text == "START PUZZLE", "puzzle card %d" % (int(t.state["index"]) + 1))
		t.begin_from_card()
		await _frames(3)
		var p := t.play
		_check(t.screen == VhHumanTest.Screen.PLAYING and p._chip.text == "" and t._hud.visible, "puzzle %d plays (clock, GIVE UP, no difficulty label)" % (int(t.state["index"]) + 1))
		var k2 := 0
		while not p.completed and k2 < 60:
			p.tap_block(Solver.from_model(p.model).recommend_move())
			await _wait(0.03)
			k2 += 1
		await _wait(1.3)
		_check(t.screen == VhHumanTest.Screen.RATE and _has_button(t, "Rate_EXTREME"), "puzzle %d solved in the real play screen -> five-step rating" % (int(t.state["index"]) + 1))
		t.rate(3)
		for ans in ["SIMILAR", "4", "4", "YES", "A LITTLE"]:
			t.think(ans)
		_check(t._q_label.text.contains("combination") and _has_button(t, "Think_A_LITTLE"), "the combination question (YES / A LITTLE / NO)")
		t.think("YES")
	var want_demos: int = data.get("demos", []).filter(func(d): return order.any(func(id): return t.boards[id]["variant"] == d["group"])).size()
	_check(demo_seen.size() == want_demos, "every due demo shown exactly once (%s)" % str(demo_seen))
	_check(t.screen == VhHumanTest.Screen.HARDEST and t.state["results"].size() == n, "all %d puzzles played -> hardest puzzle" % n)
	var r: Dictionary = t.state["results"][0]
	_check(r.get("combo", "") == "YES" and r["rating"] == "VERY HARD" and r["completed"] and r["log"].filter(func(e): return e[1] == "m").size() > 0, "result: rating, combination answer, move log")
	t.set_hardest(1, "the magnet")
	var ex = JSON.parse_string(t.results_json())
	_check(ex["test"] == "xtest6" and ex["demos"].size() == want_demos and ex["demos"].all(func(d): return d["completed"]), "results JSON: the demos played (never rated) and every puzzle")
	_check(not ex["results"].any(func(x): return x.has("demo")), "demos never appear among the rated puzzles")
	var sm: Dictionary = ex["summary"]
	_check(sm.values().all(func(v): return v.has("combo_yes") and v.has("avg_rating_1to5")), "summary per group: combination answers and 1-5 rating")
	await t._run_bench()
	_check(t.bench_results.size() == n and t.bench_results.all(func(x): return x["verify_nodes"] > 0 and x.has("hint_ms") and x.has("dead_hint_ms")), "bench: every board timed")
	t.queue_free()
	await _frames(1)
	# ?xtest5 still loads its own five boards and has no demos.
	var t5 := VhHumanTest.new("xtest5")
	add_child(t5)
	await _frames(2)
	_check(t5.boards.size() == 5 and t5.demos.is_empty() and t5._questions.size() == 5, "?xtest5 unchanged: 5 boards, no demos, five questions")
	t5.queue_free()
	await _frames(1)
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")
	_dev(false)
