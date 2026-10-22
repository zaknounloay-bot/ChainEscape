extends "res://tools/extreme11_check.gd"
## The three phase-11 blind tests (development only, ?tta=1 / ?ttb=1 /
## ?ttc=1) on the SAME staged 2-minute clock: end-to-end checks of ONE test
## per run (tools/stime_check.gd adapted to ExpertTimeAttack and its new
## question sets; the other tests' and pages' storage must stay untouched,
## and only this test's board is ever loaded).
##   godot --headless --path . res://tools/TTimeCheck.tscn -- --key=tta
## Everything the phase 9 check covers, at 120 s, plus: the stage thresholds
## (2:00-1:01 green, 1:00-0:31 orange, 0:30-0:00 red, the last 10 s
## stronger), the non-colour cue (icon, weight), the pill's fixed size and
## place (never over the board; the board never moves), the brief ease into
## orange, the red pulse (never lighter than the resting red, scale only in
## the last 10 s), reduced motion (no ease, no pulse, no scale), the stages
## recorded (once each, with the time and the page's visibility) and copied
## into the frozen timed record; the new questions.

var KEY := "tta"
var BID := ""
var DATA14 := ""
var RSTATE := ""
const LIM := 120000


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--key="):
			KEY = a.trim_prefix("--key=")
	BID = ExpertTimeAttack.PRESETS[KEY]["id"]
	DATA14 = ExpertTimeAttack.PRESETS[KEY]["data"]
	RSTATE = ExpertTimeAttack.PRESETS[KEY]["state"]
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RSTATE))
	_run.call_deferred()


func _run() -> void:
	var q1t := FileAccess.get_file_as_string("user://q1time_state.json")
	var p11 := FileAccess.get_file_as_string("user://extreme11_state.json")
	_check(ExpertTimeAttack.PRESETS[KEY]["state"] == RSTATE and ExpertTimeAttack.PRESETS[KEY]["state"] != Q1TimeAttack.CFG["state"] and ExpertTimeAttack.PRESETS[KEY]["ls"] != Q1TimeAttack.CFG["ls"]
		and VhHumanTest.TESTS.values().all(func(c): return c["state"] != RSTATE and c["ls"] != ExpertTimeAttack.PRESETS[KEY]["ls"]), "its own state file and localStorage key")
	var rt := FileAccess.get_file_as_string("user://rtime_state.json")
	var others := {}
	for f in ["user://stime_state.json"] + ExpertTimeAttack.PRESETS.keys().filter(func(k): return k != KEY).map(func(k): return ExpertTimeAttack.PRESETS[k]["state"]):
		others[f] = FileAccess.get_file_as_string(f)
	var probe := ExpertTimeAttack.new(KEY)
	add_child(probe)
	await _frames(3)
	_check(probe.boards.keys() == [BID] and probe.board_ok and probe._cfg["data"] == DATA14 and ExpertTimeAttack.PRESETS.values().filter(func(p): return p["state"] == RSTATE or p["ls"] == ExpertTimeAttack.PRESETS[KEY]["ls"]).size() == 1
		and ExpertTimeAttack.PRESETS.values().map(func(p): return p["fp"]).filter(func(f): return f == ExpertTimeAttack.PRESETS[KEY]["fp"]).size() == 1,
		"test %s loads only its own board (%s); its own state, localStorage key and fingerprint" % [KEY, BID])
	await _close(probe)
	await _stages(false)
	await _stages(true)
	await _boundary()
	await _start_and_clock()
	await _reopen_and_background()
	await _timeout_continue_from_position()
	await _timeout_continue_fresh()
	await _reload_each_phase()
	await _win_and_give_up()
	_check(FileAccess.get_file_as_string("user://q1time_state.json") == q1t and FileAccess.get_file_as_string("user://extreme11_state.json") == p11
		and FileAccess.get_file_as_string("user://rtime_state.json") == rt and others.keys().all(func(f): return FileAccess.get_file_as_string(f) == others[f]),
		"?q1time, ?ptest11, ?rtime, ?stime and the other two tests' state untouched")
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic progress written")
	print("TTIME CHECK %s: %s (%d checks)" % [KEY, "PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _page(fresh: bool = true) -> ExpertTimeAttack:
	if fresh:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RSTATE))
	var t := ExpertTimeAttack.new(KEY)
	add_child(t)
	await _frames(3)
	return t


func _enter(t: ExpertTimeAttack) -> void:
	t._start.pressed.emit()
	await _frames(1)
	if t.screen == VhHumanTest.Screen.BRIEF:
		t.begin_from_card()
	await _frames(4)


func _close(t: Node) -> void:
	t.queue_free()
	await _frames(2)


func _solution() -> Array:
	var b = JSON.parse_string(FileAccess.get_file_as_string(DATA14))["boards"][0]
	var s := Solver.from_model(EVENTS.model_of(PuzzleDefinition.from_dict(b["puzzle"]).to_level()))
	return s.solve_moves().map(func(m): return m & Solver.ID_MASK)


func _expire(t: ExpertTimeAttack) -> void:
	t.debug_offset_ms = LIM - t.elapsed_ms() + 5
	await _frames(2)


func _answer_timed(t: ExpertTimeAttack) -> void:
	(t._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	for ans in ["VERY HARD", "3", "4", "2", "YES", "APPROPRIATE", "YES", "YES"]:
		t.think(ans)
	await _frames(1)


func _answer_puzzle(t: ExpertTimeAttack) -> void:
	if t._card.visible:
		(t._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	(t.find_child("Think_YES", true, false) as Button).pressed.emit()
	for ans in ["4", "5", "YES", "A LITTLE"]:
		t.think(ans)
	(t.find_child("ThinkText", true, false) as LineEdit).text = " the switch "
	(t.find_child("Think_NEXT", true, false) as Button).pressed.emit()
	await _frames(2)


func _start_and_clock() -> void:
	var t: ExpertTimeAttack = await _page()
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA14))
	_check(t.board_ok and t.boards.size() == 1 and PuzzleDefinition.from_dict(data["boards"][0]["puzzle"]).fingerprint() == ExpertTimeAttack.PRESETS[KEY]["fp"],
		"the exact new board (fingerprint %s...)" % ExpertTimeAttack.PRESETS[KEY]["fp"].substr(0, 8))
	var intro := t._intro_text.text
	_check(intro.contains("not seen before") and intro.contains("keep playing without the clock") and not intro.to_upper().contains("EXTREME")
		and not JSON.stringify(data["boards"][0]).to_lower().contains("turncoat"), "intro: neutral, the rules and the optional untimed play told up front")
	await _enter(t)
	var p := t.play
	_check(t.run_active() and p.max_undos == 3 and p.max_hints == 1 and p.max_hammers == 0 and p._chip.text == "" and t._count.text in ["2:00", "1:59"],
		"starts at 2:00: UNDO x3, SHOW A MOVE x1, HAMMER x0, no difficulty label")
	var blocked := -1
	for id in p.model.blocks:
		if p.model.move_state(id) == "blocked":
			blocked = id
			break
	# A real touch on the blocked block, through the play screen's input.
	var canvas_pos: Vector2 = p.board.get_global_transform_with_canvas() * p.board.get_view(blocked).home
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = p._input.get_global_transform_with_canvas().affine_inverse() * canvas_pos
	p._input.gui_input.emit(ev)
	await _frames(3)
	var bt: Array = t._current["log"].filter(func(e): return e[1] == "b")
	_check(blocked >= 0 and bt.size() == 1 and int(bt[0][2]) == blocked, "a blocked tap is logged WITH its block (%d) %s total_blocked %d" % [blocked, str(bt), p.total_blocked])
	var sol := _solution()
	p.tap_block(sol[0])
	await _wait(0.1)
	var e1 := t.elapsed_ms()
	p.restart()
	await _frames(2)
	_check(t.elapsed_ms() >= e1 and t.run_active(), "RESTART does not reset the clock")
	p.tap_block(sol[0])
	await _wait(0.1)
	var eu := t.elapsed_ms()
	var full := p._total_blocks
	p.undo()
	await _frames(2)
	_check(t.elapsed_ms() >= eu and p.model.block_count() == full and t._current["log"].any(func(e): return e[1] == "u"), "UNDO gives no time back (logged)")
	# A touch on the armored shell (no move, no mistake): logged "a" WITH the block.
	var shell := -1
	for id in p.model.blocks:
		if p.model.blocks[id].armored:
			shell = id
	if shell >= 0:
		var ev2 := InputEventScreenTouch.new()
		ev2.pressed = true
		ev2.position = p._input.get_global_transform_with_canvas().affine_inverse() * (p.board.get_global_transform_with_canvas() * p.board.get_view(shell).home)
		p._input.gui_input.emit(ev2)
		await _frames(3)
	var at: Array = t._current["log"].filter(func(e): return e[1] == "a")
	if shell >= 0:
		_check(at.size() == 1 and int(at[0][2]) == shell, "a tap on the armored shell is logged WITH its block (%d) %s" % [shell, str(at)])
	var e2 := t.elapsed_ms()
	p._hint.pressed.emit()
	await _wait(0.3)
	_check(t.hint_spent(BID) and t.elapsed_ms() - e2 >= 280, "SHOW A MOVE does not pause the clock")
	await _close(t)


## A reload in the timed phase: the clock is not restored, SHOW A MOVE stays
## spent; going to the background is recorded and the clock keeps running;
## the result says the run was interrupted; every log entry is timestamped.
func _reopen_and_background() -> void:
	var sol := _solution()
	var t: ExpertTimeAttack = await _page()
	await _enter(t)
	t.play.tap_block(sol[0])
	await _wait(0.05)
	t.play._hint.pressed.emit()
	await _wait(0.5)
	var before := t.elapsed_ms()
	t.queue_free()  # the page closes (a reload or the tab closed)
	await _frames(2)
	await _wait(1.0)
	var t2: ExpertTimeAttack = await _page(false)
	_check(t2.run_active() and t2.hint_spent(BID), "after a reload: the run is still on, SHOW A MOVE still spent")
	await _enter(t2)
	_check(t2.elapsed_ms() >= before + 950 and t2.play.max_hints == 0 and int(t2._current["reopens"]) == 1 and t2._current["log"].any(func(e): return e[1] == "o"),
		"the clock is not restored (%d -> %d ms, the closed time counts); the hint not refilled; reopen logged" % [before, t2.elapsed_ms()])
	var e0 := t2.elapsed_ms()
	t2.page_hidden(true)
	await _wait(0.6)
	t2.page_hidden(false)
	await _frames(2)
	_check(int(t2.state["run"]["hidden_count"]) == 1 and t2.elapsed_ms() - e0 >= 550 and t2._current["log"].any(func(e): return e[1] == "v"), "background: recorded, the clock kept running")
	await _expire(t2)
	var timed: Dictionary = t2.state.get("timed", {})
	_check(timed.get("outcome", "") == "TIME UP" and timed.get("interrupted", false) and int(timed.get("reopens", 0)) == 1
		and timed["log"].all(func(e): return typeof(e[0]) in [TYPE_INT, TYPE_FLOAT] and e[0] >= 0),
		"the frozen TIME UP says interrupted (reopen, background); every log entry timestamped")
	await _close(t2)


## TIME UP in a position that can still be cleared: the untimed game goes on from it.
func _timeout_continue_from_position() -> void:
	var sol := _solution()
	var t: ExpertTimeAttack = await _page()
	await _enter(t)
	var p := t.play
	for i in 3:
		p.tap_block(sol[i])
		await _wait(0.03)
	p._hint.pressed.emit()  # the run's one SHOW A MOVE: spent in the timed phase
	await _frames(1)
	var before := p.model.snapshot().map(func(b): return [b.id, b.cell, b.direction, b.armored])
	await _expire(t)
	var timed: Dictionary = t.state.get("timed", {})
	_check(timed.get("outcome", "") == "TIME UP" and not timed["completed"] and int(timed["remaining_ms"]) == 0 and t.phase() == "timed_q"
		and t._card.visible and t._card_head.text == "TIME UP", "TIME UP: the timed result frozen (not completed), the timed questions next")
	var frozen := JSON.stringify(timed)
	await _answer_timed(t)
	var ta: Dictionary = t.state["timed"]["answers"]
	_check(ta["first_difficulty"] == "VERY HARD" and ta["enjoy"] == "3" and ta["excite"] == "4" and ta["frustrate"] == "2" and ta["timer_better"] == "YES" and ta["length"] == "APPROPRIATE"
		and ta["noticed_colours"] == "YES" and ta["another"] == "YES" and ta.size() == 8,
		"timed questions (before any untimed play): first-exposure difficulty, enjoyment, excitement, frustration, timer improved, 120 s, noticed the colours, another puzzle")
	_check(t.phase() == "offer" and t._card.visible and t._untimed_btn.visible and t._finish_btn.visible and t.state["offer"]["from"] == "timeout_state",
		"the offer: CONTINUE WITHOUT TIMER (from the 0:00 position, which can still be cleared) or FINISH")
	t._untimed_btn.pressed.emit()
	await _frames(3)
	var after := t.play.model.snapshot().map(func(b): return [b.id, b.cell, b.direction, b.armored])
	_check(t.phase() == "untimed" and t.screen == VhHumanTest.Screen.PLAYING and t._count.text == "NO TIMER" and JSON.stringify(after) == JSON.stringify(before),
		"untimed: the same board, the position at 0:00 rebuilt exactly, NO TIMER")
	_check(t.play.max_hints == 0 and t._current["log"][0][1] == "c" and t._current["phase"] == "untimed", "the spent SHOW A MOVE is not refilled; a separate log starting with the continuation marker")
	for k in 5:
		t.play.restart()
		await _wait(0.05)
	_check(t.play.plays == 6 and t.play.model.block_count() == t.play._total_blocks, "unlimited RESTART in the untimed game (5 here)")
	for mv in sol:
		t.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	var cont: Dictionary = t.state["cont"]
	_check(cont["continued"] and cont["completed"] and cont["outcome"] == "COMPLETED WITHOUT TIMER" and int(cont["record"]["restarts"]) == 5
		and int(cont["record"]["moves"]) >= sol.size() and t._card_head.text == "SOLVED" and t._card_text.text.contains("stays: TIME UP"),
		"solved without the timer: its own record (restarts, moves, time) %s" % JSON.stringify({"c": cont.get("completed"), "o": cont.get("outcome"), "r": cont.get("record", {}).get("restarts"), "m": cont.get("record", {}).get("moves"), "head": t._card_head.text, "txt": t._card_text.text}))
	var now_timed: Dictionary = t.state["timed"].duplicate(true)
	now_timed.erase("answers")  # added by the timed questions; nothing else may change
	_check(JSON.stringify(now_timed) == frozen and now_timed["outcome"] == "TIME UP", "the timed record is byte-identical after the untimed solve (TIME UP)")
	await _answer_puzzle(t)
	var r: Dictionary = t.state["results"][0]
	_check(r["timed"]["outcome"] == "TIME UP" and r["untimed"]["completed"] and r["puzzle_answers"]["solved"] == "YES" and r["puzzle_answers"]["feedback"] == "the switch"
		and r["puzzle_answers"]["achieve"] == "4" and r["puzzle_answers"]["enjoy_puzzle"] == "5" and r["puzzle_answers"]["insight"] == "YES" and r["puzzle_answers"]["combo"] == "A LITTLE"
		and r["puzzle_answers"]["_after"] == "untimed play (solved)" and not r["puzzle_answers"].has("first_difficulty") and r["timed"]["answers"]["first_difficulty"] == "VERY HARD",
		"results: the timed and untimed records kept apart; the first-exposure rating with the timed record, the post-play answers (after the untimed solve) apart")
	_check(t.screen == VhHumanTest.Screen.RESULTS and not t.state.has("timed") and not t.state.has("cont") and not t.state.has("budget") and t._new_run.visible,
		"results screen; nothing left in progress")
	var ex = JSON.parse_string(t.results_json())
	_check(ex["format"] == "ce-time-attack-blind" and ex["runs"].size() == 1, "results JSON")
	await _close(t)


## TIME UP in a position that can no longer be cleared: a fresh board, said so.
func _timeout_continue_fresh() -> void:
	var t: ExpertTimeAttack = await _page()
	await _enter(t)
	var p := t.play
	var s := Solver.from_model(p.model)
	var lost := -1
	for mv in s._distinct_legal():
		s._do(mv)
		var dead: bool = s._solve_keep_state().is_empty()
		s._undo_move(mv)
		if dead:
			lost = mv & Solver.ID_MASK
			break
	p.tap_block(lost)
	await _wait(0.05)
	await _expire(t)
	await _answer_timed(t)
	_check(lost >= 0 and t.phase() == "offer" and t.state["offer"]["from"] == "fresh" and t._card_text.text.contains("starts fresh"),
		"after TIME UP in a lost position: CONTINUE WITHOUT TIMER says it starts a fresh board")
	t._untimed_btn.pressed.emit()
	await _frames(3)
	_check(t.play.model.block_count() == t.play._total_blocks and t.play.max_hints == 1, "the fresh untimed board; the unspent SHOW A MOVE is still there (once)")
	var sol := _solution()
	t.play.tap_block(sol[0])
	await _wait(0.05)
	for k in 3:
		t.play.undo()
		await _frames(1)
	t.play.tap_block(sol[0])
	await _wait(0.05)
	var u := t.play.undos_used
	t.play.undo()
	await _frames(1)
	_check(u == 1 and t.play.undos_used == 2, "UNDO x3 per attempt in the untimed game")
	t.give_up()
	t.give_up()
	await _wait(0.2)
	_check(t.state["cont"]["outcome"] == "STOPPED" and not t.state["cont"]["completed"] and t._card_head.text == "STOPPED" and t.state["timed"]["outcome"] == "TIME UP",
		"stopping the untimed game: recorded as stopped; the timed result stays TIME UP")
	await _close(t)


func _reload_each_phase() -> void:
	var sol := _solution()
	var t: ExpertTimeAttack = await _page()
	await _enter(t)
	for i in 2:
		t.play.tap_block(sol[i])
		await _wait(0.03)
	await _expire(t)
	(t._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	t.think("HARD")
	t.think("5")
	await _close(t)
	var t2: ExpertTimeAttack = await _page(false)
	await _enter(t2)
	_check(t2.phase() == "timed_q" and t2._q == 2 and t2.state["timed"]["outcome"] == "TIME UP" and not t2.run_active(), "reload during the timed questions: back at question 3, TIME UP kept")
	(t2._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	for ans in ["1", "NO", "TOO SHORT", "YES", "NO", "YES"]:
		t2.think(ans)
	await _close(t2)
	var t3: ExpertTimeAttack = await _page(false)
	await _enter(t3)
	_check(t3.phase() == "offer" and t3._untimed_btn.visible, "reload at the offer: the offer again")
	t3._untimed_btn.pressed.emit()
	await _frames(3)
	t3.play.tap_block(sol[2])
	await _wait(0.1)
	var pos := t3.play.model.snapshot().map(func(b): return [b.id, b.cell, b.direction, b.armored])
	await _close(t3)
	var t4: ExpertTimeAttack = await _page(false)
	await _enter(t4)
	var pos4 := t4.play.model.snapshot().map(func(b): return [b.id, b.cell, b.direction, b.armored])
	_check(t4.phase() == "untimed" and JSON.stringify(pos4) == JSON.stringify(pos) and t4._current["log"].any(func(e): return e[1] == "k")
		and int(t4.state["cont"]["reopens"]) == 1, "reload in the untimed game: the same position rebuilt, the record continues (reopen logged)")
	t4.give_up()
	t4.give_up()
	await _wait(0.2)
	(t4._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	(t4.find_child("Think_NO", true, false) as Button).pressed.emit()
	await _close(t4)
	var t5: ExpertTimeAttack = await _page(false)
	await _enter(t5)
	_check(t5.phase() == "puzzle_q" and t5._q == 1 and t5.state["puzzle_answers"]["solved"] == "NO" and t5.state["puzzle_answers"]["_after"] == "untimed play (stopped)", "reload during the post questions: resumed at question 2 (after the stopped untimed play)")
	await _close(t5)


func _win_and_give_up() -> void:
	var sol := _solution()
	var t: ExpertTimeAttack = await _page()
	await _enter(t)
	for mv in sol:
		t.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(t.state["timed"]["outcome"] == "COMPLETED" and int(t.state["timed"]["remaining_ms"]) > 0 and t._card_head.text == "SOLVED", "a timed WIN")
	await _answer_timed(t)
	_check(t.phase() == "puzzle_q" and not t._untimed_btn.visible and t.state["cont"]["continued"] == false, "after a WIN: no offer, straight to the puzzle questions")
	await _answer_puzzle(t)
	_check(t.state["results"][0]["timed"]["outcome"] == "COMPLETED", "WIN recorded")
	await _close(t)
	t = await _page()
	await _enter(t)
	t.give_up()
	t.give_up()
	await _wait(0.2)
	_check(t.state["timed"]["outcome"] == "GAVE UP" and t.phase() == "timed_q", "GIVE UP ends the timed run (GAVE UP)")
	await _answer_timed(t)
	_check(t.phase() == "puzzle_q", "after GIVE UP: the puzzle questions (no untimed offer)")
	await _close(t)



# --- The staged countdown -----------------------------------------------------------------

## Moves the clock so that `left` ms remain (the test offset; the run's own
## clock rules are unchanged).
func _set_left(t: ExpertTimeAttack, left: int) -> void:
	t.debug_offset_ms += (LIM - left) - t.elapsed_ms()
	await _frames(2)


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Samples the fill and scale for `secs` seconds.
func _samples(t: ExpertTimeAttack, secs: float) -> Array:
	var out := []
	var end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < end:
		await _frames(1)
		out.append([t._fill.bg_color, t._pill.scale.x])
	return out


func _stages(reduced: bool) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RSTATE))
	var t := ExpertTimeAttack.new(KEY)
	t.reduced_motion = reduced
	add_child(t)
	await _frames(3)
	await _enter(t)
	var tag := " (reduced motion)" if reduced else ""
	var board0 := t.play.board.get_board_rect()
	var pos0 := t.pill_rect()
	var size0 := t._pill.size
	var green: Color = CountdownTimeAttack.STAGE_FILL["green"]
	var orange: Color = CountdownTimeAttack.STAGE_FILL["orange"]
	var red: Color = CountdownTimeAttack.STAGE_FILL["red"]
	_check(t.limit() == LIM and t._count.text in ["2:00", "1:59"] and t._stage == "green" and t._fill.bg_color == green and t._icon.stage == "green"
		and t._count.get_theme_font("font") == t._fonts["green"] and t.pill_rect().end.y <= board0.position.y and t._pill.size == CountdownTimeAttack.PILL_SIZE,
		"2:00: green pill, clock icon, weight 700, between the top bar and the board" + tag)
	var steady := true
	var rows := [[60500, "1:01", "green", false], [60000, "1:00", "orange", false], [30500, "0:31", "orange", false], [30000, "0:30", "red", false], [10500, "0:11", "red", false], [10000, "0:10", "red", true]]
	for row in rows:
		await _set_left(t, int(row[0]))
		if row[2] == "orange" and row[1] == "1:00":
			# The brief ease into orange (none with reduced motion).
			var mid := t._fill.bg_color
			_check((mid == orange) == reduced and (reduced or (mid != green)), "1:00: %s%s" % ["orange at once" if reduced else "eases from green to orange (no jump, no flash)", tag])
			await _wait(0.6)
		var ok: bool = t._count.text == row[1] and t._stage == row[2] and t._final == row[3] and t._icon.stage == row[2] and t._icon.last10 == row[3] \
			and t._count.get_theme_font("font") == t._fonts[row[2]]
		if row[2] != "red":
			ok = ok and t._fill.bg_color == CountdownTimeAttack.STAGE_FILL[row[2]]
		_check(ok, "%s: %s%s, icon %s, weight %d%s" % [row[1], row[2], " (last 10 s)" if row[3] else "", row[2], CountdownTimeAttack.STAGE_WEIGHT[row[2]], tag])
		steady = steady and (t._final or t.pill_rect() == pos0) and t._pill.size == size0 and t.play.board.get_board_rect() == board0 and t.pill_rect().end.y <= board0.position.y
	_check(steady, "no layout shift: the pill keeps its place and size, the board its place, at every stage" + tag)
	# The red pulse (before and in the last 10 s).
	await _set_left(t, 25000)
	var a := await _samples(t, 1.4)
	await _set_left(t, 8000)
	var b := await _samples(t, 1.1)
	var lighter := (a + b).any(func(x): return _luma(x[0]) > _luma(red) + 0.002)
	var varied_a := a.any(func(x): return x[0] != red)
	var fit := t._fit
	var max_a: float = a.map(func(x): return x[1] / fit).max()
	var max_b: float = b.map(func(x): return x[1] / fit).max()
	if reduced:
		_check(not varied_a and (a + b).all(func(x): return x[0] == red and absf(x[1] - fit) < 0.0001), "reduced motion: no pulse, no scale, in the red stage and the last 10 s")
	else:
		_check(varied_a and not lighter and absf(max_a - 1.0) < 0.001 and max_b > 1.001 and max_b <= 1.031,
			"red: a gentle pulse (the fill only darkens, never flashes lighter); scale only in the last 10 s (max %.3f)" % max_b)
	# Recorded once each, with the time and the page's visibility.
	var st: Dictionary = t.state["run"].get("stages", {})
	var z: Array = t._current["log"].filter(func(e): return e[1] == "z")
	_check(st.has("green") and st.has("orange") and st.has("red") and st.has("final10") and z.size() == 4 and int(st["orange"]["at_ms"]) >= 59000 and int(st["red"]["at_ms"]) >= 89000
		and st["red"]["page_hidden"] == false, "the stages reached are recorded once each (when, and whether the page was showing)" + tag)
	t.debug_offset_ms += LIM - t.elapsed_ms() + 5
	await _frames(2)
	var timed: Dictionary = t.state.get("timed", {})
	_check(timed.get("outcome", "") == "TIME UP" and timed.get("stages_reached", []) == ["green", "orange", "red", "final10"] and timed.get("reduced_motion", null) == reduced
		and int(timed["limit_ms"]) == LIM and int(timed["remaining_ms"]) == 0, "TIME UP at 120 s: the frozen record carries the stages reached" + tag)
	_check(not t._pill.visible and t._card.visible and t._card_text.text.contains("2 minutes"), "the result card replaces the board and the pill (\"The 2 minutes are over.\")" + tag)
	await _close(t)


## The 0:00 boundary at 120 s: a solve before it counts, at it does not.
func _boundary() -> void:
	var sol := _solution()
	for case in [["before", LIM - 400], ["at", LIM]]:
		var t: ExpertTimeAttack = await _page()
		await _enter(t)
		for i in sol.size() - 1:
			t.play.tap_block(sol[i])
		await _wait(0.05)
		t.debug_offset_ms += int(case[1]) - t.elapsed_ms()
		if case[0] == "at":
			await _frames(2)
		t.play.tap_block(sol[-1])
		await _wait(0.1)
		var timed: Dictionary = t.state.get("timed", {})
		if case[0] == "before":
			_check(timed.get("outcome", "") == "COMPLETED" and int(timed["remaining_ms"]) > 0 and int(timed["remaining_ms"]) <= 400, "solved just before 0:00: COMPLETED (%d ms left)" % int(timed.get("remaining_ms", -1)))
		else:
			_check(timed.get("outcome", "") == "TIME UP" and not timed["completed"], "at 0:00: TIME UP (a move after the clock ran out never wins)")
		await _close(t)
