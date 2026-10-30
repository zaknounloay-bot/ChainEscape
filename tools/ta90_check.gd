extends "res://tools/extreme11_check.gd"
## The 90-second Time Attack prototype with dynamic music (development only,
## ?ta90=1): end-to-end checks of the hub (Ta90Prototype), the page
## (Ta90TimeAttack) and the music (StageMusic).
##   godot --headless --path . res://tools/Ta90Check.tscn
## The 90 s clock and its stages (GREEN 1:30-1:01, ORANGE 1:00-0:31, RED
## 0:30-0:00), the rules (SHOW A MOVE x0, UNDO x3, unlimited RESTART that
## never gives time back, HAMMER x0), TIME UP and CONTINUE WITHOUT TIMER;
## the music follows the stage (cross-fade at the same loop position), the
## calm mix in the untimed game, silence on the cards and questions, the
## MUSIC toggle, the global music setting, the page in the background, and
## that the music never changes the clock; separate storage (the 120-second
## pilot and every standalone page untouched); the campaign music bus silent
## while the prototype is open and restored after.

const LIM := 90000
const OTHER := ["user://tapilot_hub.json", "user://tapilot_ta_state.json", "user://tapilot_s1_state.json", "user://stime_state.json", "user://tta_state.json",
	"user://rtime_state.json", "user://q1time_state.json", "user://extreme11_state.json"]
var REF := "N1"  # the full timed flow runs on the first Phase 14 board


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	_clear()
	_run.call_deferred()


func _clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90Prototype.STATE_PATH))
	for b in Ta90TimeAttack.BOARDS90:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b)))


func _run() -> void:
	var before := {}
	for f in OTHER:
		before[f] = FileAccess.get_file_as_string(f)
	AudioManager.unlocked = true
	AudioManager.music_enabled = true
	_boards()
	await _hub_flow()
	await _timeup_untimed()
	await _win_and_music_controls()
	await _export_and_isolation()
	await _new_boards()
	_check(OTHER.all(func(f): return FileAccess.get_file_as_string(f) == before[f]), "the 120-second pilot's and every standalone page's storage untouched")
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no campaign progress written")
	print("TA90 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _boards() -> void:
	var ok := true
	for b in Ta90TimeAttack.BOARDS90:
		var d = JSON.parse_string(FileAccess.get_file_as_string(Ta90TimeAttack.BOARDS90[b]["data"]))
		var rec: Dictionary = d["boards"].filter(func(x): return str(x["id"]) == b)[0]
		ok = ok and PuzzleDefinition.from_dict(rec["puzzle"]).fingerprint() == Ta90TimeAttack.BOARDS90[b]["fp"]
	_check(ok and Ta90TimeAttack.BOARDS90["TA"].get("reference", false) and not Ta90Prototype.ORDER90.has("TA"),
		"every prototype board matches its fingerprint; TA is only an internal reference, never a new puzzle")
	var o: Array = Ta90Prototype.ORDER90
	_check(o.size() == 13 and o.slice(0, 3) == ["N1", "N2", "N3"] and o.all(func(b): return not Ta90TimeAttack.BOARDS90[b].get("reference", false))
		and o.all(func(b): return b == "N%d" % (o.find(b) + 1)) and Ta90TimeAttack.BOARDS90.keys().filter(func(b): return not (Extreme90Bank.BANK.has(b) or Extreme90Review.NEW17.has(b) or Extreme90P18.NEW18.has(b) or Extreme90P19.NEW19.has(b) or Extreme90P20.NEW20.has(b) or Extreme90P21.NEW21.has(b) or Extreme90P22.NEW22.has(b) or Extreme90P24.NEW24.has(b) or Extreme90P25.NEW25.has(b)) or o.has(b)).size() == 14,
		"the collection: N1-N3 (Phase 14) and N4-N13 (Phase 15), key N<k> = PUZZLE k, every one a HUMAN-REVIEW CANDIDATE; TA the only reference")
	var fps := {}
	for b in Ta90TimeAttack.BOARDS90:
		fps[Ta90TimeAttack.BOARDS90[b]["fp"]] = true
	_check(fps.size() == Ta90TimeAttack.BOARDS90.size() and Ta90TimeAttack.BOARDS90["N1"]["fp"] == "b5bb75f5937f03404ba786ff93d3e914d167ad2d5e28f88f5ed46e4a40377bff"
		and Ta90TimeAttack.BOARDS90["N2"]["fp"] == "f4be705fcc692f27f13e0cc8d7eca216a4ba68d117b84dce4980bfa5e76d695f"
		and Ta90TimeAttack.BOARDS90["N3"]["fp"] == "76d704deb06f8a6686040e5f5cfa6edeecdfc3f2a1af8f0c98be9a4922f2272c",
		"every board has its own fingerprint; N1-N3 unchanged")
	_check(Ta90TimeAttack.LIMIT_90_MS == LIM and Ta90TimeAttack.TA90_RULES["show_a_move"] == 0 and Ta90TimeAttack.TA90_RULES["undo"] == 3
		and Ta90TimeAttack.TA90_RULES["hammer"] == 0 and Ta90TimeAttack.TA90_RULES["restart"] == "unlimited", "rules ta90-v1: 90 s, SHOW A MOVE x0, UNDO x3, unlimited RESTART, HAMMER x0")
	_check(Ta90TimeAttack.state_path90("P5") != PilotTimeAttack.state_path("P5") and Ta90Prototype.STATE_PATH != TaPilot.STATE_PATH and Ta90Prototype.LS_KEY != TaPilot.LS_KEY
		and Ta90TimeAttack.ls_key90("TA") != PilotTimeAttack.ls_key("TA"), "its own storage (hub and boards), apart from the 120-second pilot")


func _hub() -> Ta90Prototype:
	var h := Ta90Prototype.new()
	add_child(h)
	await _frames(3)
	return h


func _close(n: Node) -> void:
	n.queue_free()
	await _frames(2)


func _solution(board: String) -> Array:
	var d = JSON.parse_string(FileAccess.get_file_as_string(Ta90TimeAttack.BOARDS90[board]["data"]))
	var b: Dictionary = d["boards"].filter(func(x): return str(x["id"]) == board)[0]
	var s := Solver.from_model(EVENTS.model_of(PuzzleDefinition.from_dict(b["puzzle"]).to_level()))
	return s.solve_moves().map(func(m): return m & Solver.ID_MASK)


func _set_left(p: Ta90TimeAttack, left: int) -> void:
	p.debug_offset_ms += (LIM - left) - p.elapsed_ms()
	await _frames(3)


func _open(h: Ta90Prototype, board: String) -> Ta90TimeAttack:
	h.open_puzzle(board)
	await _frames(3)
	var p := h.page
	if p.screen == VhHumanTest.Screen.BRIEF:
		p._brief_go.pressed.emit()
	await _frames(4)
	return p


func _hint_gone(sp: SocialPlay) -> bool:
	var h: Button = sp._hint
	return not h.is_visible_in_tree() and h.pressed.get_connections().is_empty() and h.process_mode == Node.PROCESS_MODE_DISABLED and sp.max_hints == 0


func _playing_mix(p: Ta90TimeAttack) -> String:
	var m := p.music.snapshot()
	return str(m["mix"]) if m["playing"] else ""


func _hub_flow() -> void:
	var mbus := AudioServer.get_bus_index("Music")
	var h: Ta90Prototype = await _hub()
	_check(h.view == Ta90Prototype.View.WELCOME and AudioServer.is_bus_mute(mbus), "?ta90=1: the welcome screen; the campaign music bus is silent while the prototype is open")
	(h.find_child("PilotStart", true, false) as Button).pressed.emit()
	await _frames(1)
	(h.find_child("Familiar_PLAYED_A_LITTLE", true, false) as Button).pressed.emit()
	await _frames(2)
	_check(h.view == Ta90Prototype.View.SELECT and h.order.has(REF), "familiarity once, then CHOOSE A PUZZLE")
	var vis := h.get_viewport().get_visible_rect()
	var tiles_ok := true
	for i in range(1, 14):
		var t: Control = h.find_child("Puzzle_%d" % i, true, false)
		tiles_ok = tiles_ok and t != null and t.text == "PUZZLE %d" % i and vis.encloses(t.get_global_rect()) and t.size.y >= 80
	var sts := h._rows.values().map(func(r): return r[1].text)
	_check(h.order == Ta90Prototype.ORDER90 and h.find_child("ReferenceNote", true, false) == null and tiles_ok
		and h.find_child("Puzzle_14", true, false) == null and sts.all(func(t): return t == "New") and h._copy.is_visible_in_tree() and vis.encloses(h._copy.get_global_rect()),
		"the selection: a grid of PUZZLE 1-13 tiles (neutral names, no difficulty), all on screen with COPY ALL RESULTS, each 'New'; no reference row without &ta90ref=1")
	await _close(h)
	_check(not AudioServer.is_bus_mute(mbus), "closing the prototype restores the campaign music bus (the saved setting was never changed)")


## The full timed run on the reference board: stages, music, RESTART, TIME
## UP, the untimed game with the calm mix.
func _timeup_untimed() -> void:
	var h: Ta90Prototype = await _hub()
	h.open_puzzle(REF)
	await _frames(3)
	var p := h.page
	_check(p.screen == VhHumanTest.Screen.BRIEF and p._brief_go.text == "START - 1:30" and p._brief_text.text.contains("You have 90 seconds.") and not p._brief_text.text.contains("2 minutes")
		and p.music.stage == "", "the card before the board: 90 seconds, START - 1:30; no music yet")
	p._brief_go.pressed.emit()
	await _frames(4)
	var sp := p.play
	_check(p.limit() == LIM and p.run_active() and p._count.text in ["1:30", "1:29"] and p._stage == "green" and sp.max_undos == 3 and sp.max_hammers == 0 and _hint_gone(sp)
		and p._current.get("assist", {}).get("version", "") == "ta90-v1" and int(p._current["assist"]["limit_ms"]) == LIM, "1:30 GREEN; UNDO x3, SHOW A MOVE x0 (no control), HAMMER x0; the record says ta90-v1, 90 s")
	_check(p.music.stage == "green" and _playing_mix(p) == "green" and p._music_btn.visible and p._music_btn.text == "MUSIC ON"
		and p._music_btn.get_global_rect().end.y <= sp.board.get_board_rect().position.y and not p._music_btn.get_global_rect().intersects(p.pill_rect()),
		"the GREEN mix plays; the MUSIC toggle sits beside the countdown, never over the board or the pill")
	# Music never moves the clock: the clock's own value only.
	var e0 := p.elapsed_ms()
	var w0 := Time.get_ticks_msec()
	p.set_music(false)
	p.set_music(true)
	await _wait(0.3)
	var drift: int = (p.elapsed_ms() - e0) - (Time.get_ticks_msec() - w0)
	_check(absi(drift) <= 40, "toggling the music changes nothing on the clock (drift %d ms)" % drift)
	await _set_left(p, 61000)
	_check(p._count.text == "1:01" and p._stage == "green" and p.music.stage == "green", "1:01 is still GREEN (green music)")
	var pos_before: float = p.music._players[p.music._cur].get_playback_position()
	await _set_left(p, 60000)
	var in_p: AudioStreamPlayer = p.music._players[p.music._cur]
	_check(p._count.text == "1:00" and p._stage == "orange" and p.music.stage == "orange" and _playing_mix(p) == "orange" and absf(in_p.get_playback_position() - pos_before) < 0.4,
		"1:00 ORANGE: the orange mix cross-fades in at the SAME loop position (%.2f -> %.2f s)" % [pos_before, in_p.get_playback_position()])
	await _wait(1.9)
	_check(p.music.snapshot()["sounding"] == 1 and p.music._fades >= 1, "the cross-fade ends with one mix sounding (smooth, no stack-up)")
	await _set_left(p, 31000)
	_check(p._stage == "orange" and p.music.stage == "orange", "0:31 is still ORANGE")
	await _set_left(p, 30000)
	_check(p._count.text == "0:30" and p._stage == "red" and p.music.stage == "red" and _playing_mix(p) == "red", "0:30 RED: the red mix")
	var sol := _solution(REF)
	sp.tap_block(sol[0])
	await _wait(0.1)
	var e1 := p.elapsed_ms()
	sp.restart()
	await _frames(3)
	_check(p.elapsed_ms() >= e1 and p.run_active() and p.music.stage == "red" and _playing_mix(p) == "red", "RESTART: the board again; the clock and the music go on (still RED)")
	sp.tap_block(sol[0])
	await _wait(0.05)
	sp.undo()
	await _frames(2)
	_check(p.elapsed_ms() >= e1 and sp.undos_used == 1, "UNDO gives no time back")
	p.page_hidden(true)
	await _frames(2)
	_check(p.music.hidden and not p.music.snapshot()["playing"] and p.run_active(), "page in the background: the music pauses, the clock keeps running")
	p.page_hidden(false)
	await _frames(3)
	_check(not p.music.hidden and _playing_mix(p) == "red", "back in front: the red mix again")
	await _set_left(p, 0)
	await _frames(2)
	var t: Dictionary = p.state.get("timed", {})
	_check(t.get("outcome", "") == "TIME UP" and int(t.get("elapsed_ms", 0)) == LIM and p._card_text.text.contains("The 90 seconds are over.") and p.music.stage == "",
		"TIME UP at 90 s: the card says 90 seconds; the music fades out")
	await _wait(1.2)
	_check(p.music.snapshot()["sounding"] == 0, "after TIME UP: silence (a clean result screen)")
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(p._q_label.text == Ta90TimeAttack.P90_TIMED_Q[0][1] and p.music.snapshot()["sounding"] == 0, "the questions: no music")
	for a in ["HARD", "4", "5", "2", "YES", "YES", "APPROPRIATE", "YES"]:
		p.think(a)
	await _frames(2)
	_check(p.phase() == "offer" and p._untimed_btn.visible and p.state["timed"]["answers"]["music"] == "YES" and p.state["timed"]["answers"]["length"] == "APPROPRIATE",
		"the timed answers (with the music question and 90 s), then CONTINUE WITHOUT TIMER")
	p._untimed_btn.pressed.emit()
	await _frames(4)
	_check(p.phase() == "untimed" and p._count.text == "NO TIMER" and p.music.stage == "calm" and _playing_mix(p) == "calm" and _hint_gone(p.play)
		and p._current.get("assist", {}).get("version", "") == "ta90-v1", "CONTINUE WITHOUT TIMER: the same puzzle, NO TIMER, the CALM mix, still no SHOW A MOVE")
	p.play.restart()
	await _frames(1)
	for mv in sol:
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(p.state["cont"]["completed"] and p.state["timed"]["outcome"] == "TIME UP" and p.music.stage == "", "solved without the timer: recorded apart (TIME UP stays); the music fades out")
	await _wait(1.2)
	_check(p.music.snapshot()["sounding"] == 0, "the SOLVED card: silence")
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	for a in ["YES", "4", "4", ""]:
		p.think(a)
	await _frames(4)
	_check(h.view == Ta90Prototype.View.SELECT and h.page == null, "back to CHOOSE A PUZZLE")
	await _close(h)


## A timed win (the music stops at once); the MUSIC toggle and the global
## setting.
func _win_and_music_controls() -> void:
	var h: Ta90Prototype = await _hub()
	var p := await _open(h, REF)
	_check(p.run_active() and int(p.state["run"]["n"]) == 2 and _playing_mix(p) == "green", "a second run: a new 90 s clock, GREEN music")
	p._music_btn.pressed.emit()
	await _wait(0.6)
	_check(not p.music_on and p._music_btn.text == "MUSIC OFF" and p.music.snapshot()["sounding"] == 0 and h.state["music_on"] == false, "MUSIC OFF: silence at once; the hub remembers it")
	await _set_left(p, 45000)
	_check(p._stage == "orange" and p.music.snapshot()["sounding"] == 0, "muted: the stage still changes, nothing plays")
	p._music_btn.pressed.emit()
	await _frames(3)
	_check(p.music_on and _playing_mix(p) == "orange", "MUSIC ON again: the CURRENT stage's mix (orange), not green")
	AudioManager.music_enabled = false
	p.music.set_enabled(true)
	await _wait(0.6)
	await _frames(2)
	await _wait(0.6)
	_check(not p.music.audible() and p.music.snapshot()["sounding"] == 0, "global music setting OFF (even while playing): the prototype fades out and plays nothing")
	AudioManager.music_enabled = true
	await _frames(3)
	_check(_playing_mix(p) == "orange", "global music setting ON again: the current stage's mix (orange) resumes")
	for mv in _solution(REF):
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(p.state["timed"]["outcome"] == "COMPLETED" and int(p.state["timed"]["remaining_ms"]) > 0 and p._card_head.text == "SOLVED" and p.music.stage == "", "a timed WIN: SOLVED; the music fades out")
	await _wait(1.2)
	_check(p.music.snapshot()["sounding"] == 0, "the SOLVED card: silence")
	p.set_music(false)
	await _close(h)
	# Left on the SOLVED card: the hub reopens the same run at its questions.
	h = await _hub()
	p = h.page
	_check(h.view == Ta90Prototype.View.PUZZLE and p != null and p.phase() == "timed_q" and p.screen == VhHumanTest.Screen.THINK and not p.music_on
		and p._music_btn.text == "MUSIC OFF" and p.music.snapshot()["sounding"] == 0, "a reload on the SOLVED card: straight back to that run's questions; MUSIC OFF kept; silence")
	for i in 14:
		if is_instance_valid(p) and p.screen == VhHumanTest.Screen.THINK:
			p.think("")
		await _frames(1)
	_check(h.view == Ta90Prototype.View.SELECT and h.page == null, "every question skipped: back to CHOOSE A PUZZLE")
	await _close(h)


func _export_and_isolation() -> void:
	var h: Ta90Prototype = await _hub()
	var b = JSON.parse_string(h.results_json())
	var runs: Array = b["runs"]
	var r0: Dictionary = runs[0] if not runs.is_empty() else {}
	_check(b["format"] == "ce-ta90" and b["rules"]["version"] == "ta90-v1" and runs.size() == 2 and r0.get("timed_outcome", "") == "TIME UP" and r0.get("untimed_success", false)
		and r0.get("hint_allowance", -1) == 0 and r0.get("rules", "") == "ta90-v1" and r0.get("elapsed_ms", 0) == LIM and r0["timed_answers"].get("music", "") == "YES"
		and b["boards"]["N1"]["reference"] == false and b["boards"]["N1"]["fingerprint"] == Ta90TimeAttack.BOARDS90["N1"]["fp"] and not b["boards"].has("TA") and not b.has("device"),
		"COPY ALL RESULTS: one ce-ta90 bundle (2 runs, rules ta90-v1, 90 s, TIME UP and the untimed solve apart, the music answer; N1 with its fingerprint, no reference row)")
	await _close(h)


## Phase 14 / 15: every board of the collection except REF (it plays the full
## flow above) on the real page - its brief (90 seconds, its mechanics
## explained, no hints), then the Solver's line tapped in a timed run clears
## it (SOLVED, music off), and the run is recorded under its own key.
func _new_boards() -> void:
	for b in Ta90Prototype.ORDER90.filter(func(x): return x != REF):
		var h: Ta90Prototype = await _hub()
		h.open_puzzle(b)
		await _frames(3)
		var p := h.page
		var mech: Array = p.boards.get(b, {}).get("mechanics", [])
		var brief: String = p._brief_text.text
		_check(p.board_ok and p.screen == VhHumanTest.Screen.BRIEF and brief.contains("You have 90 seconds.") and brief.contains("No hints.")
			and mech.all(func(m): return m == "spinner_cw" or not VhHumanTest.REMINDERS.has(m) or brief.contains(VhHumanTest.REMINDERS[m])),
			"%s: the board loads (fingerprint), the brief says 90 seconds, no hints, and explains its mechanics %s" % [b, str(mech)])
		p._brief_go.pressed.emit()
		await _frames(4)
		_check(p.run_active() and _hint_gone(p.play) and p.play.max_undos == 3, "%s: a 90 s run, no SHOW A MOVE, UNDO x3" % b)
		for mv in _solution(b):
			p.play.tap_block(mv)
			await _wait(0.03)
		await _wait(1.3)
		_check(p.state["timed"]["outcome"] == "COMPLETED" and p._card_head.text == "SOLVED" and p.music.stage == "",
			"%s: the Solver's line clears it on the page in a timed run (SOLVED; the music fades out)" % b)
		await _close(h)
		h = await _hub()
		var bb: Dictionary = h.bundle()["boards"][b]
		var tm: Dictionary = bb["in_progress"].get("timed", {}) if not bb["in_progress"].is_empty() else {}
		_check(bb["fingerprint"] == Ta90TimeAttack.BOARDS90[b]["fp"] and bb["puzzle"] == Ta90Prototype.ORDER90.find(b) + 1 and tm.get("outcome", "") == "COMPLETED"
			and int(tm.get("limit_ms", 0)) == LIM and tm.get("assist", {}).get("version", "") == "ta90-v1" and int(tm.get("moves", -1)) >= 0,
			"%s: the export carries the run under its own key (PUZZLE %d, its fingerprint, COMPLETED, 90 s, rules ta90-v1)" % [b, Ta90Prototype.ORDER90.find(b) + 1])
		await _close(h)
