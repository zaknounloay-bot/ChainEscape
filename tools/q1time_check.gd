extends "res://tools/extreme11_check.gd"
## The 3-MINUTE CHALLENGE (development only, ?q1time=1): end-to-end checks.
##   godot --headless --path . res://tools/Q1TimeCheck.tscn
## The exact Q1 board (fingerprint; the board file unchanged); its own state,
## separate from ?ptest11 and every other test; the countdown (accuracy,
## start on the first active frame, RESTART / UNDO / SHOW A MOVE never give
## time back or pause it); TIME UP during play, right after RESTART and in a
## lost position (not completed, the board covered, recorded); a solve before
## 0:00 and exactly at the boundary; a reload / reopen (the clock and the
## SHOW A MOVE budget are not restored; time while closed counts; a run that
## expired while closed ends at once); page visibility (recorded, never
## paused); the questions and the record; a new run gets a fresh clock and
## SHOW A MOVE; ?ptest11 keeps its own rule and state.

const STATE := "user://q1time_state.json"
const LIM := 180000


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.TESTS["ptest11"]["state"]))
	_run.call_deferred()


func _run() -> void:
	_check(FileAccess.get_file_as_string(DATA11).sha256_text() == "435a1afddfe1416be019e7d28380211ed0fc8f1981a62759ee23a1635cf8fef6", "the Q1 board file is unchanged")
	_check(not VhHumanTest.TESTS.has("q1time") and Q1TimeAttack.CFG["state"] != VhHumanTest.TESTS["ptest11"]["state"]
		and Q1TimeAttack.CFG["ls"] != VhHumanTest.TESTS["ptest11"]["ls"] and VhHumanTest.TESTS.values().all(func(c): return c["state"] != STATE and c["ls"] != Q1TimeAttack.CFG["ls"]),
		"its own state file and localStorage key; no existing test mode changed")
	await _clock_rules()
	await _timeouts()
	await _boundary()
	await _reopen()
	await _visibility()
	await _questions_and_new_run()
	await _ptest11_untouched()
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")
	print("Q1 TIME CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _page(fresh: bool = true) -> Q1TimeAttack:
	if fresh:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))
	var t := Q1TimeAttack.new()
	add_child(t)
	await _frames(3)
	return t


func _enter(t: Q1TimeAttack) -> void:
	t._start.pressed.emit()
	await _frames(1)
	if t.screen == VhHumanTest.Screen.BRIEF:
		t.begin_from_card()
	await _frames(4)


func _solution() -> Array:
	var b = JSON.parse_string(FileAccess.get_file_as_string(DATA11))["boards"][0]
	var s := Solver.from_model(EVENTS.model_of(PuzzleDefinition.from_dict(b["puzzle"]).to_level()))
	return s.solve_moves().map(func(m): return m & Solver.ID_MASK)


func _clock_rules() -> void:
	var t: Q1TimeAttack = await _page()
	_check(t.board_ok and t.boards.size() == 1 and PuzzleDefinition.from_dict(t.boards["Q1"]["puzzle"]).fingerprint() == Q1TimeAttack.Q1_FINGERPRINT,
		"the exact Q1 board (fingerprint %s...)" % Q1TimeAttack.Q1_FINGERPRINT.substr(0, 8))
	_check(t.screen == VhHumanTest.Screen.INTRO and t._intro_text.text.contains("Three minutes") and t._intro_text.text.contains("never stops") and not t._start.disabled,
		"intro: the rule told up front")
	t._start.pressed.emit()
	await _frames(1)
	_check(t.screen == VhHumanTest.Screen.BRIEF and t._brief_text.text.contains("The clock starts when the board appears") and not t.run_active(),
		"no campaign question; the card does not start the clock")
	t.begin_from_card()
	_check(t.screen == VhHumanTest.Screen.PLAYING and not t.run_active() and t._count.text == "3:00", "board shown, clock at 3:00, not yet running (the build frame)")
	await _frames(4)
	var p := t.play
	_check(t.run_active() and t._run_live and p.max_undos == 3 and p.max_hints == 1 and p.max_hammers == 0 and p._chip.text == "",
		"running from the first active frame; UNDO x3, SHOW A MOVE x1, HAMMER x0, no difficulty label")
	var e0 := t.elapsed_ms()
	var w0 := Time.get_ticks_msec()
	await _wait(1.0)
	var de := t.elapsed_ms() - e0
	var dw := Time.get_ticks_msec() - w0
	_check(absi(de - dw) <= 30 and t._count.text == "2:59", "countdown accuracy: %d ms counted over %d ms, shows %s" % [de, dw, t._count.text])
	var sol := _solution()
	p.tap_block(sol[0])
	p.tap_block(sol[1])
	await _wait(0.1)
	var e1 := t.elapsed_ms()
	p.restart()
	await _frames(2)
	_check(t.elapsed_ms() >= e1 and p.model.block_count() == 13 and t.run_active(), "RESTART: the board starts again, the clock does not (%d -> %d ms)" % [e1, t.elapsed_ms()])
	p.tap_block(sol[0])
	await _wait(0.1)
	var e2 := t.elapsed_ms()
	p.undo()
	await _frames(2)
	_check(t.elapsed_ms() >= e2 and p.model.block_count() == 13, "UNDO gives no time back")
	var e3 := t.elapsed_ms()
	p._hint.pressed.emit()
	await _wait(0.3)
	_check(t.hint_spent("Q1") and t.elapsed_ms() - e3 >= 280 and t.run_active(), "SHOW A MOVE spent; the clock does not pause (%d ms on)" % (t.elapsed_ms() - e3))
	t.debug_offset_ms = LIM - 25000 - t.elapsed_ms()
	await _frames(2)
	_check(t._count.text == "0:25" and t._count.get_theme_color("font_color") == Q1TimeAttack.WARN_COLOR, "last 30 s: a colour change only (%s)" % t._count.text)
	_check(t._count.get_global_rect().end.y <= p.board.get_board_rect().position.y and t._count.get_global_rect().position.y >= p._progress.get_global_rect().end.y,
		"the countdown sits between the top bar and the board, never over it")
	t.queue_free()
	await _frames(2)


func _expire(t: Q1TimeAttack) -> void:
	t.debug_offset_ms = LIM - t.elapsed_ms() + 5
	await _frames(2)


func _timeouts() -> void:
	var sol := _solution()
	# (a) mid-attempt
	var t: Q1TimeAttack = await _page()
	await _enter(t)
	for i in 4:
		t.play.tap_block(sol[i])
		await _wait(0.03)
	await _expire(t)
	var r := t._current
	_check(t._card.visible and t._card_head.text == "TIME UP" and t._root.visible and r["outcome"] == "TIME UP" and not r["completed"]
		and int(r["elapsed_ms"]) == LIM and int(r["remaining_ms"]) == 0 and r["log"][-1][1] == "t" and int(r["max_cleared"]) >= 4 and not t.run_active(),
		"TIME UP mid-attempt: run over, not completed, the board covered, 0:00 recorded, progress %d of %d" % [int(r.get("max_cleared", 0)), int(r.get("pieces", 0))])
	var saved = JSON.parse_string(FileAccess.get_file_as_string(STATE))
	_check(saved["live"]["finished"] and saved["live"]["record"]["outcome"] == "TIME UP" and saved["run"]["done"], "TIME UP is saved at once")
	t.queue_free()
	await _frames(2)
	# (b) right after RESTART
	t = await _page()
	await _enter(t)
	t.play.tap_block(sol[0])
	await _wait(0.05)
	t.play.restart()
	await _frames(1)
	await _expire(t)
	_check(t._current["outcome"] == "TIME UP" and int(t._current["attempts"]) == 2 and int(t._current["restarts"]) == 1, "TIME UP right after RESTART (attempt 2)")
	t.queue_free()
	await _frames(2)
	# (c) in a lost position, after SHOW A MOVE said so
	t = await _page()
	await _enter(t)
	var lost := -1
	var s := Solver.from_model(t.play.model)
	for mv in s._distinct_legal():
		s._do(mv)
		var dead: bool = s._solve_keep_state().is_empty()
		s._undo_move(mv)
		if dead:
			lost = mv & Solver.ID_MASK
			break
	t.play.tap_block(lost)
	await _wait(0.05)
	t.budget_hint()
	await _frames(1)
	await _expire(t)
	_check(lost >= 0 and t._current["outcome"] == "TIME UP" and t._current["log"].any(func(e): return e[1] == "h" and e[3]["r"] == "lost") and int(t._current["show_a_move"]) == 1,
		"TIME UP in a lost position, after a spent SHOW A MOVE")
	t.queue_free()
	await _frames(2)


func _boundary() -> void:
	var sol := _solution()
	# Just before 0:00: the last move counts.
	var t: Q1TimeAttack = await _page()
	await _enter(t)
	for i in sol.size() - 1:
		t.play.tap_block(sol[i])
		await _wait(0.02)
	t.debug_offset_ms = LIM - 50 - (t.elapsed_ms() - t.debug_offset_ms)
	t.play.tap_block(sol[-1])  # the solve is handled inside this tap
	var r := t._current
	_check(r.get("outcome", "") == "COMPLETED" and r["completed"] and int(r["remaining_ms"]) > 0 and int(r["remaining_ms"]) <= 60,
		"solved 50 ms before 0:00: COMPLETED (%d ms left)" % int(r.get("remaining_ms", -1)))
	await _wait(1.3)
	_check(t._card.visible and t._card_head.text == "SOLVED" and t.screen == VhHumanTest.Screen.THINK, "the SOLVED card, then the questions")
	t.queue_free()
	await _frames(2)
	# Exactly at 0:00 (the frame has not run yet): not completed.
	t = await _page()
	await _enter(t)
	for i in sol.size() - 1:
		t.play.tap_block(sol[i])
		await _wait(0.02)
	t.debug_offset_ms = LIM - (t.elapsed_ms() - t.debug_offset_ms)
	t.play.tap_block(sol[-1])
	r = t._current
	_check(r.get("outcome", "") == "TIME UP" and not r["completed"] and int(r["remaining_ms"]) == 0, "the last move at 0:00 does not count: TIME UP (elapsed < 180000 ms required)")
	t.queue_free()
	await _frames(2)
	# Solved well within time: the normal case.
	t = await _page()
	await _enter(t)
	for mv in sol:
		t.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	r = t._current
	_check(r["outcome"] == "COMPLETED" and int(r["elapsed_ms"]) < 10000 and int(r["remaining_ms"]) == LIM - int(r["elapsed_ms"]) and int(r["show_a_move"]) == 0,
		"solved before the limit: elapsed %d ms, remaining %d ms" % [int(r["elapsed_ms"]), int(r["remaining_ms"])])
	t.queue_free()
	await _frames(2)


func _reopen() -> void:
	var sol := _solution()
	var t: Q1TimeAttack = await _page()
	await _enter(t)
	t.play.tap_block(sol[0])
	await _wait(0.05)
	t.play._hint.pressed.emit()
	await _wait(0.5)
	var before := t.elapsed_ms()
	t.queue_free()  # the page closes (a reload or the tab closed)
	await _frames(2)
	await _wait(1.0)  # closed for a second
	var t2: Q1TimeAttack = await _page(false)
	_check(t2.run_active() and t2._start.text.contains("CLOCK IS RUNNING") and t2.hint_spent("Q1"), "after a reload: the run is still on, SHOW A MOVE still spent")
	await _enter(t2)
	var after := t2.elapsed_ms()
	_check(after >= before + 950 and t2.play.max_hints == 0 and int(t2.state["run"]["reopens"]) == 1 and int(t2._current["reopens"]) == 1
		and t2._current["log"].any(func(e): return e[1] == "o"), "the clock is not restored: %d ms before, %d after (the closed time counts); reopen recorded" % [before, after])
	# The saved elapsed time is a floor even if the wall clock says less.
	t2.queue_free()
	await _frames(2)
	var st = JSON.parse_string(FileAccess.get_file_as_string(STATE))
	st["run"]["elapsed_ms"] = 100000
	st["run"]["started_unix"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(STATE, FileAccess.WRITE)
	f.store_string(JSON.stringify(st))
	f.close()
	var t3: Q1TimeAttack = await _page(false)
	await _enter(t3)
	_check(t3.elapsed_ms() >= 100000 and t3._count.text <= "1:20", "the saved time is a floor (a clock set back gives nothing): %s left" % t3._count.text)
	t3.queue_free()
	await _frames(2)
	# Expired while closed: TIME UP at once on return.
	st = JSON.parse_string(FileAccess.get_file_as_string(STATE))
	st["run"]["started_unix"] = Time.get_unix_time_from_system() - 200.0
	f = FileAccess.open(STATE, FileAccess.WRITE)
	f.store_string(JSON.stringify(st))
	f.close()
	var t4: Q1TimeAttack = await _page(false)
	await _enter(t4)
	_check(t4._card.visible and t4._card_head.text == "TIME UP" and t4._current["outcome"] == "TIME UP" and t4._current["interrupted"], "a run that ran out while the page was closed ends with TIME UP on return (interrupted)")
	t4.queue_free()
	await _frames(2)
	var t5: Q1TimeAttack = await _page(false)
	await _enter(t5)
	_check(t5._card.visible and t5._card_head.text == "TIME UP" and not t5.run_active(), "reloading after TIME UP shows the result again, no new clock")
	t5.queue_free()
	await _frames(2)


func _visibility() -> void:
	var t: Q1TimeAttack = await _page()
	await _enter(t)
	var e0 := t.elapsed_ms()
	t.page_hidden(true)
	await _wait(0.6)
	t.page_hidden(false)
	await _frames(2)
	var run: Dictionary = t.state["run"]
	_check(int(run["hidden_count"]) == 1 and int(run["hidden_ms"]) >= 550 and t.elapsed_ms() - e0 >= 550 and t._current["log"].any(func(e): return e[1] == "v"),
		"background: recorded (%d ms hidden), the clock kept running" % int(run["hidden_ms"]))
	var saved = JSON.parse_string(FileAccess.get_file_as_string(STATE))
	_check(int(saved["run"]["hidden_count"]) == 1, "saved on the way out and back")
	await _expire(t)
	_check(t._current["interrupted"] and int(t._current["hidden_count"]) == 1, "the result says the run was interrupted")
	t.queue_free()
	await _frames(2)


func _questions_and_new_run() -> void:
	var sol := _solution()
	var t: Q1TimeAttack = await _page()
	await _enter(t)
	t.play.tap_block(sol[0])
	await _wait(0.05)
	t.play._hint.pressed.emit()
	await _frames(1)
	for mv in sol.slice(1):
		t.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(t._card.visible and t._questions.size() == 7 and t._q_label.text.contains("enjoy"), "SOLVED card over the first question")
	(t._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	for ans in ["4", "5", "2", "YES", "MAYBE", "ABOUT RIGHT"]:
		t.think(ans)
	(t.find_child("ThinkText", true, false) as LineEdit).text = " tense "
	(t.find_child("Think_NEXT", true, false) as Button).pressed.emit()
	await _frames(2)
	var r: Dictionary = t.state["results"][0]
	_check(r["enjoy"] == "4" and r["excite"] == "5" and r["frustrate"] == "2" and r["timer_better"] == "YES" and r["again"] == "MAYBE" and r["length"] == "ABOUT RIGHT" and r["feedback"] == "tense",
		"enjoyment, excitement, frustration, did the timer help, again, 3 minutes too short / right / long, free text")
	_check(r["outcome"] == "COMPLETED" and r.has("elapsed_ms") and r.has("remaining_ms") and int(r["attempts"]) == 1 and r.has("restarts") and r.has("undos")
		and int(r["hint_presses"]) == 1 and int(r["show_a_move"]) == 1 and r.has("blocked_taps") and r["log"].size() > 10 and int(r["max_cleared"]) == 13
		and r.has("interrupted") and r["board_fingerprint"] == Q1TimeAttack.Q1_FINGERPRINT, "the record: outcome, times, attempts, restarts, undos, SHOW A MOVE, blocked taps, log, progress, interruptions")
	_check(t.screen == VhHumanTest.Screen.RESULTS and t._new_run.visible and not t.state.has("run") and not t.state.has("budget"), "results: a new run can start")
	var ex = JSON.parse_string(t.results_json())
	_check(ex["format"] == "ce-q1-time-attack" and ex["runs"].size() == 1 and ex["limit_ms"] == LIM, "results JSON")
	t.new_run()
	await _frames(1)
	t.begin_from_card()
	await _frames(4)
	_check(t.run_active() and t.play.max_hints == 1 and t.elapsed_ms() < 1000 and int(t.state["run"]["n"]) == 2, "a NEW run: a fresh 3:00 and a fresh SHOW A MOVE")
	t.queue_free()
	await _frames(2)


func _ptest11_untouched() -> void:
	var t := VhHumanTest.new("ptest11")
	add_child(t)
	await _frames(3)
	_check(t._cfg.has("hint_budget") and t._cfg["state"] == "user://extreme11_state.json" and not t.state.has("run")
		and not FileAccess.get_file_as_string("user://extreme11_state.json").contains("q1time"), "?ptest11 unchanged: its own rule and state")
	t.queue_free()
	await _frames(1)
