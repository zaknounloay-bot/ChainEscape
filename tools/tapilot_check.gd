extends "res://tools/extreme11_check.gd"
## The external Time Attack pilot (development only, ?tapilot=1): end-to-end
## checks of the hub (TaPilot) and its board pages (PilotTimeAttack).
##   godot --headless --path . res://tools/TaPilotCheck.tscn
## One entry point, the four validated boards (fingerprints), welcome ->
## familiarity (once) -> selection -> the 120 s run (TA120_RULES: no SHOW A
## MOVE, UNDO x3, unlimited RESTART, no HAMMER; RESTART / reload never give
## time back) -> SOLVED / TIME UP -> optional untimed play -> skippable
## questions -> back to selection; leaving mid-way and resuming; one export
## bundle (anonymous: session id, familiarity; no names, no device id, no
## design data); a puzzle played again is not a first exposure; every
## standalone page's storage untouched.

const LIM := 120000
const STANDALONE := ["user://stime_state.json", "user://tta_state.json", "user://ttb_state.json", "user://ttc_state.json",
	"user://rtime_state.json", "user://q1time_state.json", "user://extreme11_state.json"]


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	_clear()
	_run.call_deferred()


func _clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TaPilot.STATE_PATH))
	for b in PilotTimeAttack.ORDER:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PilotTimeAttack.state_path(b)))


func _run() -> void:
	var before := {}
	for f in STANDALONE:
		before[f] = FileAccess.get_file_as_string(f)
	_isolation()
	await _first_visit()
	await _timeup_untimed_and_reload()
	await _win_other_board()
	await _leave_mid_questions()
	await _export_bundle()
	await _play_again()
	_check(STANDALONE.all(func(f): return FileAccess.get_file_as_string(f) == before[f]), "every standalone test page's storage untouched (?stime, ?tta/b/c, ?rtime, ?q1time, ?ptest11)")
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic (campaign) progress written")
	print("TAPILOT CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _hub() -> TaPilot:
	var h := TaPilot.new()
	add_child(h)
	await _frames(3)
	return h


func _close(n: Node) -> void:
	n.queue_free()
	await _frames(2)


func _solution(board: String) -> Array:
	var b = JSON.parse_string(FileAccess.get_file_as_string(PilotTimeAttack.BOARDS[board]["data"]))["boards"][0]
	var s := Solver.from_model(EVENTS.model_of(PuzzleDefinition.from_dict(b["puzzle"]).to_level()))
	return s.solve_moves().map(func(m): return m & Solver.ID_MASK)


func _begin(h: TaPilot) -> PilotTimeAttack:
	var p := h.page
	if p.screen == VhHumanTest.Screen.BRIEF:
		p._brief_go.pressed.emit()
	await _frames(4)
	return p


func _expire(p: PilotTimeAttack) -> void:
	p.debug_offset_ms = LIM - p.elapsed_ms() + 5
	await _frames(2)


func _answer(p: PilotTimeAttack, answers: Array) -> void:
	for a in answers:
		p.think(a)
	await _frames(1)


func _hint_gone(sp: SocialPlay) -> bool:
	var h: Button = sp._hint
	return not h.is_visible_in_tree() and h.pressed.get_connections().is_empty() and h.mouse_filter == Control.MOUSE_FILTER_IGNORE \
		and h.focus_mode == Control.FOCUS_NONE and h.process_mode == Node.PROCESS_MODE_DISABLED and sp.max_hints == 0


func _isolation() -> void:
	var paths := PilotTimeAttack.ORDER.map(func(b): return PilotTimeAttack.state_path(b))
	var keys := PilotTimeAttack.ORDER.map(func(b): return PilotTimeAttack.ls_key(b))
	_check(PilotTimeAttack.ORDER == ["TA", "TB", "TC", "S1"] and paths.all(func(x): return not STANDALONE.has(x)) and keys.all(func(k): return not k in [CountdownTimeAttack.S_CFG["ls"], "chain_escape_tta_state", "chain_escape_ttb_state", "chain_escape_ttc_state"])
		and not paths.has(TaPilot.STATE_PATH), "the pilot keeps its own storage (4 board states + the hub), apart from every standalone page")
	var fps_ok := true
	for b in PilotTimeAttack.ORDER:
		var d = JSON.parse_string(FileAccess.get_file_as_string(PilotTimeAttack.BOARDS[b]["data"]))
		fps_ok = fps_ok and d["boards"].size() == 1 and str(d["boards"][0]["id"]) == b and PuzzleDefinition.from_dict(d["boards"][0]["puzzle"]).fingerprint() == PilotTimeAttack.BOARDS[b]["fp"]
	_check(fps_ok and PilotTimeAttack.BOARDS["TA"]["fp"] == ExpertTimeAttack.PRESETS["tta"]["fp"] and PilotTimeAttack.BOARDS["TB"]["fp"] == ExpertTimeAttack.PRESETS["ttb"]["fp"]
		and PilotTimeAttack.BOARDS["TC"]["fp"] == ExpertTimeAttack.PRESETS["ttc"]["fp"] and PilotTimeAttack.BOARDS["S1"]["fp"] == CountdownTimeAttack.S1_FINGERPRINT,
		"the four validated boards, unchanged (fingerprints S1, TA, TB, TC)")


func _first_visit() -> void:
	var h: TaPilot = await _hub()
	_check(h.view == TaPilot.View.WELCOME and h.state["session"].length() == 16 and h.state["familiarity"] == "", "first visit: the welcome screen; an anonymous random session id")
	(h.find_child("PilotStart", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(h.view == TaPilot.View.FAMILIARITY, "START: the one question - how familiar are you with Chain Escape?")
	(h.find_child("Familiar_NEVER_PLAYED", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(h.view == TaPilot.View.SELECT and h.state["familiarity"] == "NEVER PLAYED" and PilotTimeAttack.ORDER.all(func(b): return h._status(b) == "Not played yet")
		and h.find_child("Puzzle_4", true, false) != null and h._copy.is_visible_in_tree(), "selection: PUZZLE 1-4, each 'Not played yet', COPY ALL RESULTS")
	await _close(h)
	h = await _hub()
	_check(h.view == TaPilot.View.SELECT, "a second visit skips the welcome and the question (familiarity kept)")
	await _close(h)


## PUZZLE 1 (TA), a never-played player: the card, the rules on the board,
## RESTART / UNDO / a reload never give time back, TIME UP, the untimed game,
## the questions with skips, back to the selection.
func _timeup_untimed_and_reload() -> void:
	var h: TaPilot = await _hub()
	(h.find_child("Puzzle_1", true, false) as Button).pressed.emit()
	await _frames(3)
	var p := h.page
	var brief := p._brief_text.text
	_check(h.view == TaPilot.View.PUZZLE and p.board_ok and p.screen == VhHumanTest.Screen.BRIEF and brief.begins_with("PUZZLE 1") and brief.contains(PilotTimeAttack.BASICS)
		and brief.contains(VhHumanTest.REMINDERS["magnet"]) and brief.contains("No hints") and brief.contains("2 minutes") and not brief.contains("3:00") and RegEx.create_from_string("\\b(TA|TB|TC|S1)\\b").search(brief) == null
		and p._brief_go.text == "START - 2:00" and p.find_child("BackToPuzzles", true, false) != null,
		"the card before PUZZLE 1 (never played): the basic rule, its mechanics, the tools, 2 minutes; no board id, no hint")
	p = await _begin(h)
	var sp := p.play
	_check(p.run_active() and sp.max_undos == 3 and sp.max_hints == 0 and sp.max_hammers == 0 and _hint_gone(sp) and sp._title.text == "PUZZLE 1" and p._count.text in ["2:00", "1:59"]
		and p._stage == "green" and p._pill.visible, "PUZZLE 1 on the 120 s clock: 2:00 green; UNDO x3, SHOW A MOVE x0 (no control), HAMMER x0")
	var pil: Dictionary = p._current.get("pilot", {})
	_check(pil.get("session", "") == h.state["session"] and pil.get("familiarity", "") == "NEVER PLAYED" and p._current.get("assist", {}).get("show_a_move", -1) == 0,
		"the run's record: the anonymous session, the familiarity, hint allowance 0")
	var sol := _solution("TA")
	sp.tap_block(sol[0])
	await _wait(0.1)
	var e1 := p.elapsed_ms()
	sp.restart()
	await _frames(2)
	sp.tap_block(sol[0])
	await _wait(0.05)
	sp.undo()
	await _frames(2)
	_check(p.elapsed_ms() >= e1 and p.run_active() and sp.undos_used == 1, "RESTART and UNDO never give time back")
	var before := p.elapsed_ms()
	await _close(h)  # the page is closed / reloaded mid-run
	await _wait(1.0)
	h = await _hub()
	p = h.page
	_check(h.view == TaPilot.View.PUZZLE and p != null and p.board_key == "TA" and p.run_active() and p.screen == VhHumanTest.Screen.PLAYING and p.elapsed_ms() >= before + 950
		and _hint_gone(p.play), "a reload mid-run: straight back to PUZZLE 1, the clock not restored (%d -> %d ms), still no SHOW A MOVE" % [before, p.elapsed_ms()])
	for i in 2:
		p.play.tap_block(sol[i])
		await _wait(0.03)
	await _expire(p)
	var t: Dictionary = p.state.get("timed", {})
	_check(t.get("outcome", "") == "TIME UP" and not t.get("completed", true) and p._card_head.text == "TIME UP" and p._card_text.text.contains("2 minutes")
		and t.get("stages_reached", []).size() >= 1, "TIME UP: frozen (not completed), the card says 2 minutes")
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(p.screen == VhHumanTest.Screen.THINK and p._q_label.text == PilotTimeAttack.P_TIMED_Q[0][1] and p._think_skip.is_visible_in_tree(), "the questions: first-exposure difficulty first, SKIP available")
	await _answer(p, ["VERY HARD", "4", "", "2", "YES", "", "YES"])  # two skipped
	_check(p.phase() == "offer" and p._untimed_btn.visible and p._finish_btn.visible, "after TIME UP: CONTINUE WITHOUT TIMER or FINISH")
	p._untimed_btn.pressed.emit()
	await _frames(3)
	_check(p.phase() == "untimed" and p._count.text == "NO TIMER" and p.play._title.text == "NO TIMER" and _hint_gone(p.play) and p.play.max_undos == 3, "untimed: the same puzzle, NO TIMER, still no SHOW A MOVE, UNDO x3")
	p.play.restart()
	await _frames(1)
	for mv in sol:
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(p.state["cont"].get("completed", false) and p.state["timed"]["outcome"] == "TIME UP", "solved without the timer; the timed result stays TIME UP")
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(p._q_label.text == PilotTimeAttack.P_POST_Q[0][1], "then: did you solve it, enjoyment, achievement, optional text")
	await _answer(p, ["YES", "5", "4"])
	(p.find_child("ThinkText", true, false) as LineEdit).text = " nice one "
	(p.find_child("Think_NEXT", true, false) as Button).pressed.emit()
	await _frames(4)
	_check(h.view == TaPilot.View.SELECT and h.page == null and h.state["current"] == "" and h._status("TA") == "Time up - solved without the timer",
		"back to the selection: PUZZLE 1 shows 'Time up - solved without the timer'")
	await _close(h)


## PUZZLE 4 (S1): a timed WIN, then straight to the selection.
func _win_other_board() -> void:
	var h: TaPilot = await _hub()
	(h.find_child("Puzzle_4", true, false) as Button).pressed.emit()
	await _frames(3)
	_check(h.page.board_key == "S1" and h.page._brief_text.text.begins_with("PUZZLE 4") and h.page._brief_text.text.contains(VhHumanTest.REMINDERS["lock"]), "PUZZLE 4 is S1 (its own mechanics on the card)")
	var p := await _begin(h)
	for mv in _solution("S1"):
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(p.state["timed"]["outcome"] == "COMPLETED" and p._card_head.text == "SOLVED", "a timed WIN on PUZZLE 4")
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _answer(p, ["HARD", "5", "5", "1", "YES", "APPROPRIATE", "YES"])
	_check(p.phase() == "puzzle_q" and not p._untimed_btn.visible, "after a WIN: no untimed offer")
	await _answer(p, ["", "", "", ""])  # everything skipped
	await _frames(3)
	_check(h.view == TaPilot.View.SELECT and h._status("S1").begins_with("Solved in ") and h._status("TA").begins_with("Time up"), "back to the selection; each puzzle keeps its own result")
	await _close(h)


## PUZZLE 2 (TB): leaving during the questions (nothing forced) and coming back.
func _leave_mid_questions() -> void:
	var h: TaPilot = await _hub()
	(h.find_child("Puzzle_2", true, false) as Button).pressed.emit()
	await _frames(3)
	var p := await _begin(h)
	await _expire(p)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _answer(p, ["MEDIUM"])
	(p.find_child("BackToPuzzles", true, false) as Button).pressed.emit()
	await _frames(3)
	_check(h.view == TaPilot.View.SELECT and h.page == null and h._status("TB") == "In progress - tap to continue", "BACK TO PUZZLES during the questions: allowed; PUZZLE 2 shows 'In progress'")
	(h.find_child("Puzzle_2", true, false) as Button).pressed.emit()
	await _frames(3)
	p = h.page
	_check(p.screen == VhHumanTest.Screen.THINK and p._q == 1 and p.phase() == "timed_q" and p.state["timed"]["answers"]["first_difficulty"] == "MEDIUM", "PUZZLE 2 again: back at question 2, the answer kept")
	(p.find_child("BackToPuzzles", true, false) as Button).pressed.emit()
	await _frames(3)
	await _close(h)


func _export_bundle() -> void:
	var h: TaPilot = await _hub()
	var j := h.results_json()
	var b = JSON.parse_string(j)
	var runs: Array = b["runs"]
	var ta: Dictionary = runs.filter(func(r): return r["board"] == "TA")[0] if runs.any(func(r): return r["board"] == "TA") else {}
	var s1: Dictionary = runs.filter(func(r): return r["board"] == "S1")[0] if runs.any(func(r): return r["board"] == "S1") else {}
	_check(b["format"] == "ce-tapilot" and b["session"] == h.state["session"] and b["familiarity"] == "NEVER PLAYED" and runs.size() == 2 and b["boards"].size() == 4
		and b["rules"]["show_a_move"] == 0, "COPY ALL RESULTS: one bundle with both finished puzzles, the session and the familiarity")
	_check(ta.get("fingerprint", "") == PilotTimeAttack.BOARDS["TA"]["fp"] and ta["timed_outcome"] == "TIME UP" and not ta["timed_success"] and ta["untimed_played"] and ta["untimed_success"]
		and ta["untimed_outcome"] == "COMPLETED WITHOUT TIMER" and ta["elapsed_ms"] == LIM and ta["restarts"] == 1 and ta["attempts"] == 3 and ta["reopens"] == 1 and ta["undos"] == 1
		and ta["hint_allowance"] == 0 and ta["moves"] >= 4 and ta.has("blocked_taps") and ta["stages_reached"].size() >= 1 and ta["first_exposure"] and ta["familiarity"] == "NEVER PLAYED"
		and ta["timed_answers"]["first_difficulty"] == "VERY HARD" and ta["timed_answers"]["excite"] == "" and ta["post_answers"]["feedback"] == "nice one" and ta["post_answers"]["solved"] == "YES",
		"PUZZLE 1 in the bundle: TIME UP and the untimed solve kept apart; time, attempts / restarts / reopen, UNDO, moves, blocked taps, hint allowance 0, stages, answers (skips empty) %s" % JSON.stringify(ta).left(300))
	_check(s1.get("timed_success", false) and s1["untimed_played"] == false and s1["elapsed_ms"] < LIM and s1["timed_answers"]["first_difficulty"] == "HARD" and s1["post_answers"].get("solved", "x") == "",
		"PUZZLE 4 in the bundle: a timed success, no untimed play")
	_check(not b["boards"]["TB"]["in_progress"].is_empty() and b["boards"]["TB"]["raw"].is_empty() and b["boards"]["TC"]["raw"].is_empty(), "PUZZLE 2 exported as in progress; PUZZLE 3 empty")
	var low := j.to_lower()
	_check(not low.contains("\"metrics\"") and not low.contains("\"recipe\"") and not low.contains("\"device\"") and not low.contains("\"email") and not low.contains("\"name\""),
		"anonymous and clean: no device field, no name / contact, no design data in the export")
	await _close(h)


## A puzzle played again: a new run, never a first exposure.
func _play_again() -> void:
	var h: TaPilot = await _hub()
	(h.find_child("Puzzle_4", true, false) as Button).pressed.emit()
	await _frames(3)
	var p := await _begin(h)
	_check(p.run_active() and int(p.state["run"]["n"]) == 2, "PUZZLE 4 again: a new 2-minute run (run 2)")
	p.give_up()
	p.give_up()
	await _wait(0.2)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _answer(p, ["", "", "", "", "", "", "", "", "", "", ""])
	await _frames(3)
	var runs: Array = h.bundle()["runs"].filter(func(r): return r["board"] == "S1")
	_check(h.view == TaPilot.View.SELECT and runs.size() == 2 and runs[0]["first_exposure"] and not runs[1]["first_exposure"] and runs[1]["timed_outcome"] == "GAVE UP"
		and h._status("S1").contains("played 2 times"), "the second run is recorded as run 2 (not a first exposure)")
	await _close(h)
