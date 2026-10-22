extends "res://tools/extreme8_check.gd"
## EXTREME phase 6 (development only, ?ptest11=1): end-to-end checks.
##   godot --headless --path . res://tools/Extreme11Check.tscn
## The board file (ONE crossing-magnet board, neutral id and group; the
## per-board technical, EXTREME and expert acceptance of T1-T5 / P1-P2 /
## H1-H2 / E1-E2 re-checked; the idea on EVERY winning line and >= 2 timing
## magnets, re-measured exhaustively (tools/extreme11_events.gd); not a
## duplicate or variant of any board a tester played); the board played to
## the end in the real SocialPlay; SHOW A MOVE after plausible mistakes
## within 40 ms through this page's own button; and the EXPERIMENTAL SHOW A
## MOVE RULE of this mode (docs/extreme11.md): one per puzzle, spent before
## it answers, kept spent through RESTART, UNDO, a refresh (a new page on the
## same saved state) and coming back; a lost position costs it ("Can't be
## cleared"); no legal move costs nothing; once spent the same answer
## everywhere; every press logged with its outcome; the puzzle in progress
## survives a refresh. The other test modes keep their SHOW A MOVE (refilled
## by RESTART) and the earlier files are unchanged.

const DATA11 := "res://data/dev/extreme11.json"
const EV11 := preload("res://tools/extreme11_events.gd")
const BUILD11 := preload("res://tools/extreme11_build.gd")
const KEY11 := "ptest11"


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS[KEY11]["state"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS["xtest8"]["state"]))
	_run.call_deferred()


func _run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA11))
	for f in KEEP_SHA:
		_check(FileAccess.get_file_as_string(f).sha256_text().begins_with(KEEP_SHA[f]), "%s unchanged" % f.get_file())
	_check(FileAccess.get_file_as_string(DATA8).sha256_text().begins_with("9c77e061"), "extreme8.json unchanged")
	_check_data11(data)
	await _play_every_board(data)
	await _budget_after_mistakes(data)
	await _budget_rule(data)
	await _page_flow11(data)
	await _other_modes_keep_their_rule()
	print("EXTREME11 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_data11(data) -> void:
	_check(typeof(data) == TYPE_DICTIONARY and data.get("test") == KEY11, "the phase-6 board file loads")
	var a: Dictionary = data["assist"]
	_check(int(a["undo"]) == 3 and int(a["show_a_move"]) == 1 and int(a["hammer"]) == 0, "tools: UNDO x3, SHOW A MOVE x1 (per puzzle here), HAMMER x0")
	var boards: Array = data["boards"]
	_check(boards.size() == 1, "exactly one board (%d)" % boards.size())
	var b: Dictionary = boards[0]
	_check(str(b["id"]) == "Q1" and str(b["variant"]) == "Q" and not JSON.stringify(b).to_lower().contains("convey")
		and not JSON.stringify(b).to_upper().contains("EXTREME"), "neutral id, group and record (no design name, no difficulty)")
	var known := _known_keys11()
	var played := _played_forms()
	for f in ["res://data/dev/extreme7.json", DATA8]:
		for o in JSON.parse_string(FileAccess.get_file_as_string(f))["boards"]:
			var g := _shape_grid(Array(o["puzzle"]["map"]))
			var forms := []
			for k in 4:
				forms.append(g)
				forms.append(CANON._mirror(g))
				g = CANON._rot(g)
			played.append([f.get_file() + " " + str(o["id"]), forms])
	_dev(true)
	var id: String = b["id"]
	var def := PuzzleDefinition.from_dict(b["puzzle"])
	_check(def != null and Array(def.map) == Array(b["puzzle"]["map"]), "%s: exact stored board" % id)
	var level := def.to_level()
	var tokens := 0
	for row in def.map:
		for t in String(row).split(" ", false):
			tokens += 0 if t == "." else 1
	_check(level != null and level.blocks.size() == tokens, "%s: every cell parses on the page (%d pieces)" % [id, tokens])
	_check(def.rows <= 7 and def.columns <= 7 and tokens >= 10 and tokens <= 13, "%s: mobile size, 10-13 pieces (%dx%d, %d)" % [id, def.columns, def.rows, tokens])
	var s := Solver.from_model(EVENTS.model_of(level))
	var moves := s.solve_moves()
	_check(not s.aborted and not moves.is_empty() and s.nodes <= 20000, "%s: solvable within the 20000-node working budget (%d nodes)" % [id, s.nodes])
	var mech := mechanics(Array(def.map))
	_check(mech == b["mechanics"] and mech.has("magnet") and mech.any(func(k): return str(k).begins_with("spinner")) and mech.has("armor"), "%s: mechanics recorded truthfully %s" % [id, str(mech)])
	var magnets := level.blocks.filter(func(x): return x.magnet)
	_check(magnets.size() >= 2 and magnets.size() <= 3 and magnets.all(func(x): return not x.is_spinner() and not x.armored and not x.hidden and x.switch_group == "" and x.flip_link == ""),
		"%s: 2-3 magnets, each a plain arrow (%d)" % [id, magnets.size()])
	var key: String = CANON.canonical(Array(def.map))
	_check(key == b["canonical"] and not known.has(key), "%s: not a campaign level or an earlier board (%s)" % [id, known.get(key, "new")])
	var near := _near_copy(Array(def.map), played)
	_check(near == "", "%s: not a variant of a board testers played (%s)" % [id, near if near != "" else "none"])
	_check(b["accepted"], "%s: passed every acceptance rule" % id)
	var met: Dictionary = b["metrics"]
	_check(int(met["solution_length"]) <= 18, "%s: solution of at most 18 taps (%d)" % [id, met["solution_length"]])
	_check(float(met["impact"]["armor"]) >= 1.0, "%s: armor matters (impact %.1f)" % [id, met["impact"]["armor"]])
	var x: Dictionary = b["x"]
	_check(float(x["best_rule_dead_ends"]) >= 3.0 and float(x["greedy_best"]) <= 0.05, "%s: rules of thumb (%.1f dead ends) and greedy play (%.3f)" % [id, x["best_rule_dead_ends"], x["greedy_best"]])
	_check(int(x["late_misleading_moves"]) >= 2, "%s: >= 2 distinct plausible losing moves that fail late (%d)" % [id, x["late_misleading_moves"]])
	_check(x["magnet_matters"]["matters"], "%s: the magnets matter %s" % [id, str(x["magnet_matters"])])
	for k in BUILD11.MUST11["C1_cross"]:
		var w := EV11.witness(level, k)
		_check(w.is_empty(), "%s: %s on EVERY winning line (exhaustive)" % [id, k])
	var memo := EXPERT.explore(Solver.from_model(EVENTS.model_of(level)))
	var tm := EV11.timing(Solver.from_model(EVENTS.model_of(level)), memo["win"])
	_check(tm["timing_magnets"].size() >= 2 and tm["timing_magnets"].size() == x["timing"]["timing_magnets"].size(),
		"%s: %d magnets whose escape wins at one moment and loses at another (re-measured, as stored)" % [id, tm["timing_magnets"].size()])
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
	_dev(false)


## Campaign 1-300 and every development board file except this test's own.
func _known_keys11() -> Dictionary:
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
			if f.ends_with(".json") and not f.begins_with("extreme11"):
				_collect(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f))), dir.path_join(f), known)
	return known


# --- SHOW A MOVE after mistakes, through this page's own button -------------------------------

## The page in this mode, on the board, on a fresh state (a "new device").
func _fresh_page() -> VhHumanTest:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS[KEY11]["state"]))
	var t := VhHumanTest.new(KEY11)
	add_child(t)
	await _frames(3)
	t._start.pressed.emit()
	t.set_reached(300)
	t.begin_from_card()
	await _frames(3)
	return t


func _budget_after_mistakes(data) -> void:
	_dev(true)
	var def := PuzzleDefinition.from_dict(data["boards"][0]["puzzle"])
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
	_dev(false)
	var worst := 0.0
	for z in mistakes:
		var t: VhHumanTest = await _fresh_page()
		var p := t.play
		for i in int(z[0]):
			p.tap_block(sol[i] & Solver.ID_MASK)
			await _wait(0.02)
		p.tap_block(int(z[1]) & Solver.ID_MASK)
		await _wait(0.05)
		var t0 := Time.get_ticks_usec()
		t.budget_hint()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		var last: Array = t._current["log"][-1]
		_check(last[1] == "h" and last[3]["r"] == "lost" and t.hint_spent("Q1") and p._message.text.contains("Can't be cleared") and p.max_hints == 0,
			"mistake at step %d: SHOW A MOVE says it can't be cleared AND is spent (%.1f ms)" % [int(z[0]) + 1, ms])
		var t1 := Time.get_ticks_usec()
		t.budget_hint()
		var ms2 := (Time.get_ticks_usec() - t1) / 1000.0
		p.undo()
		await _wait(0.05)
		t.budget_hint()
		_check(t._current["log"][-1][3]["r"] == "none" and p._message.text == "No SHOW A MOVE left in this puzzle" and ms2 < 10.0,
			"... then the same refusal after UNDO (now winnable) as in the lost position; no solver work (%.2f ms)" % ms2)
		t.queue_free()
		await _frames(1)
	print("Q1: SHOW A MOVE after %d mistakes (page button): slowest %.1f ms" % [mistakes.size(), worst])
	_check(mistakes.size() >= 2 and worst <= HINT_MS, "Q1: %d mistakes tried, slowest SHOW A MOVE %.1f ms (<= %.0f ms native desktop)" % [mistakes.size(), worst, HINT_MS])


# --- The rule -----------------------------------------------------------------------------------

func _budget_rule(data) -> void:
	var path: String = VhHumanTest.TESTS[KEY11]["state"]
	var t: VhHumanTest = await _fresh_page()
	var p := t.play
	_check(p.max_hints == 1 and p._hint.badge_text == "1" and not t.hint_spent("Q1"), "a new puzzle: ONE SHOW A MOVE")
	_check(not p._hint.pressed.is_connected(p.hint) and p._hint.pressed.is_connected(t.budget_hint), "this mode answers SHOW A MOVE itself (SocialPlay's own handler not connected here)")
	p.play_solver_move()
	await _wait(0.05)
	p._hint.pressed.emit()
	await _frames(1)
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(t.hint_spent("Q1") and _hinted(p) >= 0 and p.max_hints == 0 and p._hint.badge_text == "0"
		and typeof(saved) == TYPE_DICTIONARY and saved.get("budget", {}).has("Q1"),
		"the press highlights a move, spends it and is saved before anything else")
	var e: Array = t._current["log"][-1]
	_check(e[1] == "h" and e[2] >= 0 and e[3]["r"] == "shown" and int(e[3]["att"]) == 1 and int(t._current["first_hint_attempt"]) == 1 and t._current.has("first_hint_ms"),
		"logged: the press, its outcome, the attempt and when")
	p.restart()
	await _wait(0.1)
	_check(p.max_hints == 0 and p._hint.badge_text == "0", "RESTART does not give it back")
	p._hint.pressed.emit()
	await _frames(1)
	_check(t._current["log"][-1][3]["r"] == "none" and int(t._current["log"][-1][3]["att"]) == 2 and _hinted(p) < 0, "a press after RESTART is refused (and logged)")
	p.play_solver_move()
	await _wait(0.05)
	p.undo()
	await _wait(0.05)
	p._hint.pressed.emit()
	await _frames(1)
	_check(t._current["log"][-1][3]["r"] == "none" and _hinted(p) < 0, "UNDO does not give it back")
	var presses := int(t._current["hint_presses"])
	# A refresh: the page closes and a new one opens on the same saved state.
	p.play_solver_move()
	await _wait(0.05)
	var moves_before := int(t._current["log"].filter(func(x): return x[1] == "m").size())
	t.queue_free()
	await _frames(2)
	var t2 := VhHumanTest.new(KEY11)
	add_child(t2)
	await _frames(3)
	_check(t2.hint_spent("Q1") and t2.state.has("live"), "after a refresh: still spent, the puzzle in progress kept")
	t2._start.pressed.emit()
	if t2.screen == VhHumanTest.Screen.BRIEF:
		t2.begin_from_card()
	await _frames(3)
	var p2 := t2.play
	_check(t2.screen == VhHumanTest.Screen.PLAYING and p2.max_hints == 0 and p2._hint.badge_text == "0", "the reopened puzzle has no SHOW A MOVE")
	_check(int(t2._current["reopens"]) == 1 and t2._current["log"].any(func(x): return x[1] == "o")
		and t2._current["log"].filter(func(x): return x[1] == "m").size() == moves_before and int(t2._current["hint_presses"]) == presses,
		"the record carries on: log, presses, reopen logged as \"o\"")
	p2._hint.pressed.emit()
	await _frames(1)
	_check(t2._current["log"][-1][3]["r"] == "none" and int(t2._current["log"][-1][3]["att"]) == 3, "refused after the refresh too (attempt 3: the first play, a restart, the reopen)")
	# A board with no legal move: the screen already says so - nothing spent.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	t2.queue_free()
	await _frames(2)
	var t3: VhHumanTest = await _fresh_page()
	var p3 := t3.play
	var stuck := _stuck_line(p3.model)
	if stuck.is_empty():
		_check(true, "no position without a legal move on this board (nothing to check)")
	else:
		for id in stuck:
			p3.tap_block(id)
			await _wait(0.03)
		p3._hint.pressed.emit()
		await _frames(1)
		_check(p3.model.playable_ids().is_empty() and t3._current["log"][-1][3]["r"] == "stuck" and not t3.hint_spent("Q1") and p3.max_hints == 1,
			"no legal move left: the visible \"No moves left\" answer, nothing spent")
	t3.queue_free()
	await _frames(1)
	# Solved after the hint: the record.
	var t4: VhHumanTest = await _fresh_page()
	var p4 := t4.play
	p4._hint.pressed.emit()
	await _frames(1)
	var k := 0
	while not p4.completed and k < 60:
		p4.tap_block(Solver.from_model(p4.model).recommend_move())
		await _wait(0.03)
		k += 1
	await _wait(1.3)
	var r := t4._current
	_check(t4.screen == VhHumanTest.Screen.RATE and r["completed"] and int(r["show_a_move"]) == 1 and int(r["hint_presses"]) == 1
		and int(r["attempts"]) == 1 and int(r["first_hint_attempt"]) == 1 and r.has("unaided_max_cleared"), "solved: SHOW A MOVE 1, presses, attempts, first hint and unaided progress recorded")
	# A refresh on the questions goes back to the questions, not the board.
	t4.queue_free()
	await _frames(2)
	var t5 := VhHumanTest.new(KEY11)
	add_child(t5)
	await _frames(3)
	t5._start.pressed.emit()
	if t5.screen == VhHumanTest.Screen.BRIEF:
		t5.begin_from_card()
	await _frames(2)
	_check(t5.screen == VhHumanTest.Screen.RATE and t5._current.get("completed", false), "a refresh after solving returns to the questions")
	t5.queue_free()
	await _frames(1)


## The highlighted block (-1 = none).
func _hinted(p: SocialPlay) -> int:
	for vid in p.board._views:
		if p.board._views[vid].hinted:
			return vid
	return -1


## Moves from the start that leave no legal move at all ([] if none within 8).
func _stuck_line(m: BoardModel) -> Array:
	var line := []
	if _stuck_dfs(m, line, 0):
		return line
	return []


func _stuck_dfs(m: BoardModel, line: Array, depth: int) -> bool:
	if not m.is_empty() and m.playable_ids().is_empty():
		return true
	if depth >= 8:
		return false
	for id in m.playable_ids():
		if m.move_state(id) != "ok":
			continue
		var snap := m.snapshot()
		m.remove(id)
		line.append(id)
		if _stuck_dfs(m, line, depth + 1):
			m.restore(snap)
			return true
		line.pop_back()
		m.restore(snap)
	return false


# --- The page --------------------------------------------------------------------------------

func _page_flow11(data) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS[KEY11]["state"]))
	var t := VhHumanTest.new(KEY11)
	add_child(t)
	await _frames(3)
	var intro := t._intro_text.text
	_check(t.pilot and t.ratings == ["EASY", "MEDIUM", "HARD", "VERY HARD", "EXTREME"] and t._questions.size() == 7 and t.demos.is_empty()
		and intro.contains("eight quick questions") and intro.contains("ONE SHOW A MOVE for the whole puzzle") and not intro.to_upper().contains("EXTREME")
		and not intro.to_lower().contains("convey"), "ptest11: one board, the ?xtest8 questions, the SHOW A MOVE rule told up front, nothing named")
	t._start.pressed.emit()
	t.set_reached(300)
	_check(t.state["order"] == ["Q1"], "the one board offered")
	if t.screen == VhHumanTest.Screen.INTRO:
		t._start.pressed.emit()
	_check(t.screen == VhHumanTest.Screen.BRIEF and t._brief_text.text.begins_with("PUZZLE 1 / 1") and not t._brief_text.text.contains("Q1"), "the puzzle card is neutral")
	t.begin_from_card()
	await _frames(3)
	var p := t.play
	_check(t.screen == VhHumanTest.Screen.PLAYING and p._chip.text == "" and p.max_undos == 3 and p.max_hints == 1 and p.max_hammers == 0,
		"plays: no difficulty label, UNDO x3 / SHOW A MOVE x1 / HAMMER x0")
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
	_check(t.screen == VhHumanTest.Screen.RATE and _has_button(t, "Rate_EXTREME"), "solved in the real play screen -> EASY ... EXTREME")
	t.rate(4)
	for ans in ["HARDER", "5", "4", "YES", "YES", "A LITTLE"]:
		t.think(ans)
	var field := t.find_child("ThinkText", true, false) as LineEdit
	field.text = " the timing "
	(t.find_child("Think_NEXT", true, false) as Button).pressed.emit()
	_check(t.state["results"].size() == 1 and not t.state.has("live"), "rated and answered: the record stored, nothing left in progress")
	var r0: Dictionary = t.state["results"][0]
	_check(r0["rating"] == "EXTREME" and r0["l300"] == "HARDER" and r0["enjoy"] == "5" and r0["achieve"] == "4" and r0["fair"] == "YES" and r0["planned"] == "YES"
		and r0["combo"] == "A LITTLE" and r0["feedback"] == "the timing", "difficulty, vs Level 300, enjoyment, achievement, fairness, planning, combination, free text")
	_check(r0["completed"] and int(r0["restarts"]) >= 1 and int(r0["undos"]) >= 1 and int(r0["blocked_taps"]) >= 1 and r0.has("time_ms") and r0.has("mech")
		and r0["log"].any(func(e): return e[1] == "b") and r0["log"].any(func(e): return e[1] == "r") and r0["log"].any(func(e): return e[1] == "u"),
		"recorded: moves with timestamps, restarts, undos, blocked taps, mechanism events, time")
	var ex = JSON.parse_string(t.results_json())
	_check(ex["test"] == KEY11 and ex["results"].size() == 1, "results JSON")
	await t._run_bench()
	_check(t.bench_results.size() == 1 and t.bench_results.all(func(x): return x["verify_nodes"] > 0 and x.has("hint_ms") and x.has("dead_hint_ms")), "bench: the board timed")
	t.queue_free()
	await _frames(1)
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")


## ?xtest8 (and so every earlier mode): SHOW A MOVE is SocialPlay's, one per
## attempt, refilled by RESTART, a lost position free - unchanged.
func _other_modes_keep_their_rule() -> void:
	var t := VhHumanTest.new("xtest8")
	add_child(t)
	await _frames(3)
	t._start.pressed.emit()
	t.set_reached(300)
	t.begin_from_card()
	await _frames(3)
	var p := t.play
	_check(p._hint.pressed.is_connected(p.hint) and not t.state.has("budget"), "?xtest8: SocialPlay's own SHOW A MOVE")
	p._hint.pressed.emit()
	await _frames(1)
	var used := p.hints_used
	p.restart()
	await _wait(0.1)
	_check(used == 1 and p.hints_used == 0 and p.max_hints == 1, "?xtest8: RESTART still gives SHOW A MOVE back")
	t.queue_free()
	await _frames(1)
