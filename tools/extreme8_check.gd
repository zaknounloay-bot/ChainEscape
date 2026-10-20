extends "res://tools/extreme7_check.gd"
## EXTREME EXPERT EXPERIMENT (development only, ?xtest8=1): end-to-end checks.
##   godot --headless --path . res://tools/Extreme8Check.tscn
## Board file (1-3 concept-first candidates, at most one per design X1 / X2 /
## X3; the same per-board technical and EXTREME acceptance as T1-T5 / P1-P2 /
## H1-H2, <= 7x7, <= 16 pieces, <= 18 taps; each design's idea on EVERY
## winning line, re-checked here exhaustively (tools/extreme8_events.gd); the
## expert gates re-measured (tools/expert_probe.gd); not a duplicate or a
## variant of any board a tester played); every board played to the end in
## the real SocialPlay; SHOW A MOVE after plausible mistakes, including
## positions with no continuation; the page flow (random order, blind cards,
## five-step rating, seven questions incl. optional free text, mechanism
## events in the move log, hardest puzzle, results, bench); the earlier
## pilots' files and pages unchanged.

const DATA8 := "res://data/dev/extreme8.json"
const EV8 := preload("res://tools/extreme8_events.gd")
const EXPERT := preload("res://tools/expert_probe.gd")
const BUILD8 := preload("res://tools/extreme8_build.gd")
## Earlier development board files as they were before this experiment.
const KEEP_SHA := {
	"res://data/dev/extreme5.json": "76556b50c12b0a46c2fc486e3160b14a39bedb35c1ff6a80ba68471fbc79216b",
	"res://data/dev/extreme6.json": "5fc855ddadaee02f3b5d2506b5315c8f4f5e12c711444111f2193a937dffd093",
	"res://data/dev/extreme7.json": "199e788c7115b64844251c48525a4908ee8db7b2e54201e5992a2972d9646bb6",
	"res://data/dev/vh_validation3.json": "fd09cc91c05166b1",
	"res://data/dev/vh_pilot4.json": "fe37487e3fcc52d7",
}
const RECIPE_OF := {"X1": "X1_remote", "X2": "X2_cascade", "X3": "X3_integration"}


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS["xtest8"]["state"]))
	_run.call_deferred()


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA8))
	for f in KEEP_SHA:
		_check(FileAccess.get_file_as_string(f).sha256_text().begins_with(KEEP_SHA[f]), "%s unchanged" % f.get_file())
	_check_data8(data)
	await _play_every_board(data)
	await _hints_after_mistakes(data)
	await _page_flow8(data)
	print("EXTREME8 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_data8(data) -> void:
	_check(typeof(data) == TYPE_DICTIONARY and data.get("test") == "xtest8", "the expert-experiment board file loads")
	var a: Dictionary = data["assist"]
	_check(int(a["undo"]) == 3 and int(a["show_a_move"]) == 1 and int(a["hammer"]) == 0, "live tools unchanged: UNDO x3, SHOW A MOVE x1, HAMMER x0")
	var boards: Array = data["boards"]
	_check(boards.size() >= 1 and boards.size() <= 3, "1-3 candidates (%d of the 3 asked for)" % boards.size())
	var per := {}
	for b in boards:
		per[b["variant"]] = per.get(b["variant"], 0) + 1
	_check(per.keys().all(func(k): return RECIPE_OF.has(k)) and per.values().all(func(n): return n == 1), "at most one per design X1 / X2 / X3 (%s)" % str(per.keys()))
	var known := _known_keys8()
	var played := _played_forms()
	for b in JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme7.json"))["boards"]:
		var g := _shape_grid(Array(b["puzzle"]["map"]))
		var forms := []
		for k in 4:
			forms.append(g)
			forms.append(CANON._mirror(g))
			g = CANON._rot(g)
		played.append(["extreme7.json " + str(b["id"]), forms])
	_dev(true)
	for b in boards:
		var id: String = b["id"]
		var def := PuzzleDefinition.from_dict(b["puzzle"])
		_check(def != null and Array(def.map) == Array(b["puzzle"]["map"]), "%s: exact stored board" % id)
		var level := def.to_level()
		var tokens := 0
		for row in def.map:
			for t in String(row).split(" ", false):
				tokens += 0 if t == "." else 1
		_check(level != null and level.blocks.size() + level.portals.size() == tokens, "%s: every cell parses on the page (%d pieces)" % [id, tokens])
		_check(def.rows <= 7 and def.columns <= 7 and tokens <= 16, "%s: within the campaign's 7x7 and 16 pieces (%dx%d, %d)" % [id, def.columns, def.rows, tokens])
		var s := Solver.from_model(EVENTS.model_of(level))
		var moves := s.solve_moves()
		_check(not s.aborted and not moves.is_empty() and s.nodes <= 20000, "%s: solvable within the 20000-node working budget (%d nodes; recipient limit %d unchanged)" % [id, s.nodes, Solver.DEFAULT_NODE_LIMIT])
		var mech := mechanics(Array(def.map))
		_check(mech == b["mechanics"], "%s: mechanics recorded truthfully %s" % [id, str(mech)])
		var key: String = CANON.canonical(Array(def.map))
		_check(key == b["canonical"] and not known.has(key), "%s: not a campaign level or an earlier board (%s)" % [id, known.get(key, "new")])
		var near := _near_copy(Array(def.map), played)
		_check(near == "", "%s: not a variant of a board testers played (%s)" % [id, near if near != "" else "none"])
		_check(b["accepted"], "%s: passed every acceptance rule" % id)
		var met: Dictionary = b["metrics"]
		_check(int(met["solution_length"]) <= 18, "%s: solution of at most 18 taps (%d)" % [id, met["solution_length"]])
		for fam in ["lock", "switch", "gate", "armor", "portal", "sequence", "crate"]:
			if mech.has(fam):
				_check(float(met["impact"][fam]) >= 1.0, "%s: %s matters (impact %.1f)" % [id, fam, met["impact"][fam]])
		var x: Dictionary = b["x"]
		_check(float(x["best_rule_dead_ends"]) >= 3.0 and float(x["greedy_best"]) <= 0.05, "%s: rules of thumb (%.1f dead ends) and greedy play (%.3f)" % [id, x["best_rule_dead_ends"], x["greedy_best"]])
		_check(int(x["late_misleading_moves"]) >= 2, "%s: >= 2 distinct plausible losing moves that fail late (%d)" % [id, x["late_misleading_moves"]])
		if mech.has("magnet"):
			_check(x["magnet_matters"]["matters"], "%s: the magnets matter %s" % [id, str(x["magnet_matters"])])
		var recipe: String = RECIPE_OF[b["variant"]]
		var facts := EV8.must_facts(level, BUILD8.MUST8[recipe])
		_check(facts.values().all(func(v): return v), "%s: the design's idea on EVERY winning line %s" % [id, str(facts)])
		var ex: Dictionary = x["expert"]
		_check(ex["ok"] and float(ex["learner"]["look4"]) >= 12.0 and float(ex["learner"]["look6"]) >= 12.0 and float(ex["look6_greedy"]) <= 0.05,
			"%s: expert gates recorded and met (learners look4 / look6 %s, look6 greedy %.3f)" % [id, str(ex["learner"]), ex["look6_greedy"]])
		var m := EXPERT.measure(s)
		var stored: Dictionary = ex["measure"]["decisions"]
		_check(int(m["decisions"][6]) >= 4 and m["decisions"].keys().all(func(k): return int(stored.get(str(k), -1)) == int(m["decisions"][k])),
			"%s: %d decisions 6-move lookahead cannot settle (re-measured exhaustively, as stored)" % [id, m["decisions"][6]])
		var h: Dictionary = met["hint"]
		_check(not h["aborted"] and h["consistent"], "%s: SHOW A MOVE within budget and always finds a move on the solution" % id)
		var runs: Array = x.get("time_runs_ms", [])
		_check(runs.size() >= 5 and runs.all(func(t): return float(t) <= 40.0), "%s: within the 40 ms budget in every repeated measurement %s" % [id, str(runs)])
		_check(str(b.get("why", "")).length() > 80 and b.get("misleading_moves", []).size() >= 2, "%s: written explanation and misleading moves (analyst only)" % id)
	_dev(false)


## Campaign 1-300 and every development board file except this test's own.
func _known_keys8() -> Dictionary:
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
			if f.ends_with(".json") and not f.begins_with("extreme8"):
				_collect(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f))), dir.path_join(f), known)
	return known


# --- The page ----------------------------------------------------------------------------------

func _page_flow8(data) -> void:
	var n: int = data["boards"].size()
	var t := VhHumanTest.new("xtest8")
	add_child(t)
	await _frames(3)
	_check(t.pilot and t.ratings == ["EASY", "MEDIUM", "HARD", "VERY HARD", "EXTREME"] and t._questions.size() == 7 and t.demos.is_empty()
		and t._intro_text.text.contains("eight quick questions") and not t._intro_text.text.to_upper().contains("EXTREME"),
		"xtest8: five-step rating, seven questions (announced as eight with the rating), no demos, no difficulty named")
	t._start.pressed.emit()
	t.set_reached(300)
	var orders := {}
	for k in 12:
		t._new_order()
		orders[str(t.state["order"])] = true
	_check(n < 2 or orders.size() >= 2, "the order is randomised per tester (%d different orders in 12 draws)" % orders.size())
	t.set_reached(300)
	_check(t.state["order"].size() == n, "all 300 levels: every board offered (%d)" % n)
	var guard := 0
	var first := true
	while t.screen != VhHumanTest.Screen.HARDEST and guard < 20:
		guard += 1
		if t.screen == VhHumanTest.Screen.INTRO:
			t._start.pressed.emit()
		if t.screen != VhHumanTest.Screen.BRIEF:
			break
		var idx := int(t.state["index"])
		var rec: Dictionary = t.boards[t.state["order"][idx]]
		_check(t._brief_go.text == "START PUZZLE" and t._brief_text.text.begins_with("PUZZLE %d / %d" % [idx + 1, n])
			and not t._brief_text.text.contains(str(rec.get("title", "@@"))) and not t._brief_text.text.contains(rec["variant"]),
			"puzzle card %d: neutral (no title, no design name)" % (idx + 1))
		t.begin_from_card()
		await _frames(3)
		var p := t.play
		_check(t.screen == VhHumanTest.Screen.PLAYING and p._chip.text == "" and p.max_undos == 3 and p.max_hints == 1 and p.max_hammers == 0,
			"puzzle %d plays: no difficulty label, UNDO x3 / SHOW A MOVE x1 / HAMMER x0" % (idx + 1))
		if first:
			first = false
			for id in p.model.blocks:
				if p.model.move_state(id) == "blocked":
					p.tap_block(id)
					await _wait(0.05)
					break
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
		_check(t.screen == VhHumanTest.Screen.RATE and _has_button(t, "Rate_EXTREME"), "puzzle %d solved in the real play screen -> EASY ... EXTREME" % (idx + 1))
		t.rate(4)
		for ans in ["HARDER", "5", "5", "YES", "YES", "YES"]:
			t.think(ans)
		var field := t.find_child("ThinkText", true, false) as LineEdit
		_check(t._q_label.text.contains("difficult or interesting") and field != null and _has_button(t, "Think_NEXT") and _has_button(t, "Think_SKIP"),
			"the optional free-text question (field, NEXT, SKIP)")
		if idx == 0:
			field.text = "  the second magnet  "
			(t.find_child("Think_NEXT", true, false) as Button).pressed.emit()
		else:
			t.think("")
	_check(t.screen == VhHumanTest.Screen.HARDEST and t.state["results"].size() == n, "all %d puzzles played -> which was the hardest, and why" % n)
	var r0: Dictionary = t.state["results"][0]
	_check(r0["feedback"] == "the second magnet" and t.state["results"].slice(1).all(func(r): return r["feedback"] == ""), "free text recorded (trimmed), skipped answers empty")
	_check(r0["completed"] and int(r0["restarts"]) >= 1 and int(r0["undos"]) >= 1 and r0.has("show_a_move") and r0.has("time_ms") and r0.has("gave_up")
		and r0["log"].any(func(e): return e[1] == "b") and r0["log"].any(func(e): return e[1] == "m"),
		"recorded: time, restarts, UNDO, SHOW A MOVE, give-up, blocked taps, move log")
	var with_ev := 0
	for r in t.state["results"]:
		for e in r["log"]:
			if e.size() > 3 and typeof(e[3]) == TYPE_DICTIONARY:
				with_ev += 1
	_check(with_ev > 0 and t.state["results"].all(func(r): return r.has("mech") and not r["mech"].is_empty()),
		"mechanism events in the move log (%d moves) and per puzzle %s" % [with_ev, str(t.state["results"].map(func(r): return r.get("mech", {})))])
	_check(t.state["results"].all(func(r): return r["rating"] == "EXTREME" and r["l300"] == "HARDER" and r["enjoy"] == "5" and r["achieve"] == "5" and r["fair"] == "YES" and r["planned"] == "YES" and r["combo"] == "YES"),
		"every puzzle: difficulty, vs Level 300, enjoyment, achievement, fairness, planning, combination")
	t.set_hardest(1, "the first one")
	var ex = JSON.parse_string(t.results_json())
	_check(ex["test"] == "xtest8" and ex["results"].size() == n and ex["hardest"]["why"] == "the first one", "results JSON: the test, every puzzle, the hardest and why")
	await t._run_bench()
	_check(t.bench_results.size() == n and t.bench_results.all(func(x): return x["verify_nodes"] > 0 and x.has("hint_ms") and x.has("dead_hint_ms")), "bench: every board timed")
	t.queue_free()
	await _frames(1)
	for key in ["xtest5", "xtest6", "xtest7", "vhval3"]:
		var o := VhHumanTest.new(key)
		add_child(o)
		await _frames(2)
		_check(o.boards.size() == {"xtest5": 5, "xtest6": 2, "xtest7": 2, "vhval3": 3}[key] and o._questions.size() == {"xtest5": 5, "xtest6": 6, "xtest7": 6, "vhval3": 6}[key],
			"?%s unchanged: its own boards and questions" % key)
		o.queue_free()
		await _frames(1)
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")
	_dev(false)
