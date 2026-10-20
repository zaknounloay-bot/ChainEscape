extends "res://tools/extreme6_check.gd"
## EXTREME DESIGN EXPERIMENT (development only, ?xtest7=1): end-to-end checks.
##   godot --headless --path . res://tools/Extreme7Check.tscn
## Board file (1-2 hand-designed candidates, at most one per puzzle A7 / B7,
## the same per-board technical and EXTREME acceptance as T1-T5 / P1-P2 with
## <= 14 pieces and <= 18 taps; each puzzle's central idea on EVERY winning
## line, re-checked here exhaustively (tools/extreme7_events.gd); not a
## duplicate or a variant of a campaign level, the Gate 0 pilot, T1-T5,
## P1-P2 or a demo); every board played to the end in the real SocialPlay;
## SHOW A MOVE after plausible mistakes in the real play screen
## (repeated, timed, never spent on a lost position, right again after
## UNDO); the page flow (five-step rating, six questions, results, bench);
## the earlier pilots' files (T1-T5, P1-P2) unchanged and their pages intact.

const DATA7 := "res://data/dev/extreme7.json"
const EV7 := preload("res://tools/extreme7_events.gd")
## data/dev/extreme6.json as delivered in phase 2 (P1-P2 must not change).
const P12_SHA256 := "5fc855ddadaee02f3b5d2506b5315c8f4f5e12c711444111f2193a937dffd093"
## Repeated SHOW A MOVE measurements after each mistake, and their budget
## (the Gate 0 mobile budget: 40 ms on a native desktop).
const HINT_REPEATS := 5
const HINT_MS := 40.0


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS["xtest7"]["state"]))
	_run.call_deferred()


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA7))
	_check(FileAccess.get_file_as_string("res://data/dev/extreme5.json").sha256_text() == T15_SHA256, "T1-T5 board file unchanged since d7c1aeb")
	_check(FileAccess.get_file_as_string("res://data/dev/extreme6.json").sha256_text() == P12_SHA256, "P1-P2 board file unchanged since phase 2")
	_check_data7(data)
	await _play_every_board(data)
	await _hints_after_mistakes(data)
	await _page_flow7(data)
	print("EXTREME7 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_data7(data) -> void:
	_check(typeof(data) == TYPE_DICTIONARY and data.get("test") == "xtest7", "the design-experiment board file loads")
	var a: Dictionary = data["assist"]
	_check(int(a["undo"]) == 3 and int(a["show_a_move"]) == 1 and int(a["hammer"]) == 0, "live VERY HARD assistance: UNDO x3, SHOW A MOVE x1, HAMMER x0")
	var boards: Array = data["boards"]
	_check(boards.size() >= 1 and boards.size() <= 2, "1-2 candidates (%d of the 2 asked for)" % boards.size())
	_check(not data.has("demos"), "no demos (every rule is taught by the campaign or the ?xtest6 demos)")
	var per := {}
	for b in boards:
		per[b["variant"]] = per.get(b["variant"], 0) + 1
	_check(per.keys().all(func(k): return k in ["A7", "B7"]) and per.values().all(func(n): return n == 1), "at most one per puzzle A7 / B7 (%s)" % str(per.keys()))
	var known := _known_keys7()
	var played := _played_forms()
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
				if t == ".":
					continue
				tokens += 1
				if t.length() >= 3 and t.ends_with("*") and not t.contains("@"):
					magnets += 1
		_check(level != null and level.blocks.size() == tokens and level.blocks.filter(func(x): return x.magnet).size() == magnets,
			"%s: every cell parses on the page (%d pieces, %d magnets)" % [id, tokens, magnets])
		_check(def.rows <= 7 and def.columns <= 7 and tokens <= 14, "%s: at most 7x7 and 14 pieces (%dx%d, %d)" % [id, def.columns, def.rows, tokens])
		var s := Solver.from_model(EVENTS.model_of(level))
		s.node_limit = Solver.DEFAULT_NODE_LIMIT
		var moves := s.solve_moves()
		_check(not s.aborted and not moves.is_empty() and s.nodes <= 20000, "%s: solvable within the 20000-node working budget (%d nodes)" % [id, s.nodes])
		var mech := mechanics(Array(def.map))
		_check(mech == b["mechanics"], "%s: mechanics recorded truthfully %s" % [id, str(mech)])
		var want: Array = ["switch", "gate"] if b["variant"] == "A7" else ["magnet", "armor"]
		_check(want.all(func(k): return mech.has(k)) and (mech.has("spinner_cw") or mech.has("spinner_ccw")),
			"%s: the puzzle's mechanics %s + spinners" % [id, str(want)])
		var fl: int = 1
		for k in mech:
			fl = maxi(fl, FIRST_MAGNET if k == "magnet" else int(CANON.FIRST_LEVEL.get(k, 1)))
		_check(int(b["first_level"]) == fl, "%s: first level %d" % [id, fl])
		var key: String = CANON.canonical(Array(def.map))
		_check(key == b["canonical"] and not keys.has(key), "%s: no duplicate among the candidates" % id)
		keys[key] = true
		_check(not known.has(key), "%s: not a campaign level, pilot, T1-T5, P1-P2, earlier test, lab board or demo (%s)" % [id, known.get(key, "new")])
		var near := _near_copy(Array(def.map), played)
		_check(near == "", "%s: not a variant (rotation / reflection, colours ignored) of a board testers played (%s)" % [id, near if near != "" else "none"])
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
		# The central idea, re-checked here over every winning line.
		var recipe := "A_remote" if b["variant"] == "A7" else "B_geometry"
		var facts := EV7.must_facts(level, recipe)
		_check(facts.values().all(func(v): return v) and facts.size() == EV7.MUST[recipe].size(), "%s: the central idea on EVERY winning line %s" % [id, str(facts)])
		var h: Dictionary = met["hint"]
		_check(not h["aborted"] and h["consistent"], "%s: SHOW A MOVE within budget and always finds a move on the solution" % id)
		var runs: Array = x.get("time_runs_ms", [])
		_check(runs.size() >= 5 and runs.all(func(t): return float(t) <= 40.0), "%s: within the mobile budget in every repeated measurement %s" % [id, str(runs)])
		_check(str(b.get("why", "")).length() > 80 and b.get("misleading_moves", []).size() >= 2, "%s: written explanation and misleading moves" % id)
	_dev(false)


## Campaign 1-300 and every development board file except this test's own.
func _known_keys7() -> Dictionary:
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
			if f.ends_with(".json") and not f.begins_with("extreme7"):
				_collect(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f))), dir.path_join(f), known)
	return known


## Every board a tester may have played (campaign, Gate 0 pilot, T1-T5,
## P1-P2): [name, colourless grid] in all 8 rotations / reflections.
func _played_forms() -> Array:
	var maps := []
	for n in range(1, 301):
		maps.append(["campaign L%d" % n, Array(JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%02d.json" % n))["map"])])
	for f in ["vh_pilot4.json", "extreme5.json", "extreme6.json"]:
		for b in JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/" + f))["boards"]:
			maps.append([f + " " + str(b["id"]), Array(b["puzzle"]["map"])])
	var out := []
	for m in maps:
		var g := _shape_grid(m[1])
		var forms := []
		for k in 4:
			forms.append(g)
			forms.append(CANON._mirror(g))
			g = CANON._rot(g)
		out.append([m[0], forms])
	return out


func _shape_grid(map: Array) -> Array:
	var g := []
	for row in map:
		var r := []
		for t in String(row).split(" ", false):
			t = CANON._strip_reward(t)
			if t.length() >= 2 and "RBGYP".contains(t[0]):
				t = "*" + t.substr(1)
				var at := t.find("#")
				if at >= 0:
					t = t.substr(0, at + 1) + "k" + t.substr(at + 2)
			r.append(t)
		g.append(r)
	return g


## More than half of the occupied cells hold the same piece (shape, arrow,
## modifiers; colours ignored) in some rotation / reflection of a played board.
func _near_copy(map: Array, played: Array) -> String:
	var g := _shape_grid(map)
	for p in played:
		for f in p[1]:
			if f.size() != g.size() or f[0].size() != g[0].size():
				continue
			var same := 0
			var occupied := 0
			for r in g.size():
				for c in g[r].size():
					if g[r][c] != "." or f[r][c] != ".":
						occupied += 1
						if g[r][c] == f[r][c]:
							same += 1
			if occupied > 0 and same * 2 > occupied:
				return p[0]
	return ""


# --- SHOW A MOVE after mistakes, in the real play screen ----------------------------------------

## Plausible mistakes: along the solver's solution, every legal move that
## loses (the position can no longer be cleared), up to MISTAKES of them
## from the earliest steps. Each is made in SocialPlay at its step; SHOW A
## MOVE is then pressed HINT_REPEATS times: each answer within the budget,
## the lost position recognised ("can't be cleared from here - try Undo"),
## no SHOW A MOVE spent; after UNDO it names a winning move again.
const MISTAKES := 6


func _hints_after_mistakes(data) -> void:
	_dev(true)
	for b in data["boards"]:
		var def := PuzzleDefinition.from_dict(b["puzzle"])
		var s := Solver.from_model(EVENTS.model_of(def.to_level()))
		var sol := s.solve_moves()
		var mistakes := []
		for i in sol.size():
			for mv in s._distinct_legal():
				if mistakes.size() < MISTAKES and mv != sol[i]:
					s._do(mv)
					if s._alive_count > s._crate_n and s.recommend_move() == -1:
						mistakes.append([i, mv])
					s._undo_move(mv)
			s._do(sol[i])
		var worst := 0.0
		for z in mistakes:
			var p := SocialPlay.new()
			p.dev_assist = true
			p.max_hammers = 0
			p.max_undos = 3
			add_child(p)
			p.start(SharedChallenge.friend_challenge(def, FriendGenerator.VERY_HARD), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
			await _frames(2)
			for i in int(z[0]):
				p.tap_block(sol[i] & Solver.ID_MASK)
				await _wait(0.02)
			p.tap_block(int(z[1]) & Solver.ID_MASK)
			await _wait(0.05)
			var ok := Solver.from_model(p.model).recommend_move() == -1
			for k in HINT_REPEATS:
				var t0 := Time.get_ticks_usec()
				p.hint()
				var ms := (Time.get_ticks_usec() - t0) / 1000.0
				worst = maxf(worst, ms)
				ok = ok and ms <= HINT_MS and p.hints_used == 0 and p._message.text.contains("try Undo")
			p.undo()
			await _wait(0.05)
			p.hint()
			var again := p.hints_used == 1 and Solver.from_model(p.model).recommend_move() != -1
			_check(ok and again, "%s: mistake at step %d (block %d): SHOW A MOVE x%d says try Undo, spends nothing, works again after UNDO" % [b["id"], int(z[0]) + 1, int(z[1]) & Solver.ID_MASK, HINT_REPEATS])
			p.queue_free()
			await _frames(1)
		print("%s: SHOW A MOVE after %d mistakes x%d: slowest %.1f ms" % [b["id"], mistakes.size(), HINT_REPEATS, worst])
		_check(mistakes.size() >= 2 and worst <= HINT_MS, "%s: %d mistakes tried, slowest SHOW A MOVE %.1f ms (<= %.0f ms native desktop)" % [b["id"], mistakes.size(), worst, HINT_MS])
	_dev(false)


# --- The page ----------------------------------------------------------------------------------

func _page_flow7(data) -> void:
	var n: int = data["boards"].size()
	var t := VhHumanTest.new("xtest7")
	add_child(t)
	await _frames(3)
	_check(t.pilot and t.ratings.size() == 5 and t._questions.size() == 6 and t._intro_text.text.contains("seven quick questions") and t.demos.is_empty(),
		"xtest7: five-step rating, six questions (announced as seven with the rating), no demos")
	t._start.pressed.emit()
	t.set_reached(300)
	var order: Array = t.state["order"]
	_check(order.size() == n, "all 300 levels: every candidate offered (%d)" % n)
	var guard := 0
	while t.screen != VhHumanTest.Screen.HARDEST and guard < 20:
		guard += 1
		if t.screen == VhHumanTest.Screen.INTRO:
			t._start.pressed.emit()
		if t.screen != VhHumanTest.Screen.BRIEF:
			break
		var idx := int(t.state["index"])
		_check(t._brief_go.text == "START PUZZLE" and t._brief_text.text.begins_with("PUZZLE %d / %d" % [idx + 1, n]), "puzzle card %d" % (idx + 1))
		t.begin_from_card()
		await _frames(3)
		var p := t.play
		_check(t.screen == VhHumanTest.Screen.PLAYING and p._chip.text == "" and t._hud.visible, "puzzle %d plays (clock, GIVE UP, no difficulty label)" % (idx + 1))
		var k := 0
		while not p.completed and k < 60:
			p.tap_block(Solver.from_model(p.model).recommend_move())
			await _wait(0.03)
			k += 1
		await _wait(1.3)
		_check(t.screen == VhHumanTest.Screen.RATE and _has_button(t, "Rate_EXTREME"), "puzzle %d solved in the real play screen -> five-step rating" % (idx + 1))
		t.rate(3)
		for ans in ["SIMILAR", "4", "4", "YES", "A LITTLE"]:
			t.think(ans)
		_check(t._q_label.text.contains("combination") and _has_button(t, "Think_A_LITTLE"), "the combination question (YES / A LITTLE / NO)")
		t.think("YES")
	_check(t.screen == VhHumanTest.Screen.HARDEST and t.state["results"].size() == n, "all %d puzzles played -> hardest puzzle" % n)
	var r: Dictionary = t.state["results"][0]
	_check(r.get("combo", "") == "YES" and r["rating"] == "VERY HARD" and r["completed"] and r["log"].filter(func(e): return e[1] == "m").size() > 0
		and r.has("restarts") and r.has("undos") and r.has("show_a_move") and r.has("time_ms") and r.has("gave_up"),
		"result: rating, six answers, restarts, undos, SHOW A MOVE, time, give-up, move log")
	t.set_hardest(1, "the switch")
	var ex = JSON.parse_string(t.results_json())
	_check(ex["test"] == "xtest7" and ex["results"].size() == n, "results JSON names the test and every puzzle")
	var sm: Dictionary = ex["summary"]
	_check(sm.values().all(func(v): return v.has("combo_yes") and v.has("avg_rating_1to5") and v.has("gave_up") and v.has("restarts")), "summary per puzzle: rating, combination answers, give-ups, restarts")
	_check(t._summary_text().contains("combination more interesting"), "the summary text shows the combination answers")
	await t._run_bench()
	_check(t.bench_results.size() == n and t.bench_results.all(func(x): return x["verify_nodes"] > 0 and x.has("hint_ms") and x.has("dead_hint_ms")), "bench: every board timed")
	t.queue_free()
	await _frames(1)
	# The earlier pilots' pages still load their own boards.
	var t5 := VhHumanTest.new("xtest5")
	add_child(t5)
	await _frames(2)
	_check(t5.boards.size() == 5 and t5.demos.is_empty() and t5._questions.size() == 5, "?xtest5 unchanged: 5 boards, no demos, five questions")
	t5.queue_free()
	await _frames(1)
	var t6 := VhHumanTest.new("xtest6")
	add_child(t6)
	await _frames(2)
	_check(t6.boards.size() == 2 and t6.demos.size() == 3 and t6._questions.size() == 6, "?xtest6 unchanged: P1-P2, three demos, six questions")
	t6.queue_free()
	await _frames(1)
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")
	_dev(false)
