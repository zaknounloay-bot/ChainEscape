extends "res://tools/extreme11_check.gd"
## EXTREME Time Attack bank (development only, ?extreme90=1): end-to-end
## checks of Extreme90Bank on the unchanged 90-second page (Ta90TimeAttack).
##   godot --headless --path . res://tools/Extreme90Check.tscn
## The bank: the five baseline boards (N3, N5, N7, N11, N13) with their exact
## Phase 14 / 15 fingerprints, then the accepted Phase 16 boards; the
## experimental collection (?ta90=1, N1-N13) still complete; neutral
## CHALLENGE labels; every board solved on the real page in a timed run and
## exported under its internal id and fingerprint; TIME UP and the untimed
## continuation with the calm mix; storage apart from ?ta90=1 and the
## 120-second pilot; no campaign progress written.

const LIM := 90000
## The baseline fingerprints, as accepted in Phases 14 / 15 (never edited).
const BASELINE := {"N3": "76d704deb06f8a6686040e5f5cfa6edeecdfc3f2a1af8f0c98be9a4922f2272c",
	"N5": "3f420b14215a44aa1bb6b96c85be519ff1c247312a6300c444c673f43e650c40",
	"N7": "a9465918d8f02112da791892a32c7e3ff2d79d8fe173c59b34b2d674d8e9587b",
	"N11": "a92813074460913b95b9f54433ffd156ead01c04c1e5d357ad83ea380f8bf4fb",
	"N13": "9acdd496511edcd6e847217ec37d7029d7cc82a62d1f93258d7ac08b5d86c943"}
const OTHER := ["user://ta90_hub.json", "user://tapilot_hub.json", "user://tapilot_ta_state.json", "user://stime_state.json", "user://tta_state.json"]
const EV6 := preload("res://tools/extreme6_events.gd")


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	_clear()
	_run.call_deferred()


func _clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Extreme90Bank.BANK_STATE_PATH))
	for b in Ta90TimeAttack.BOARDS90:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, "xb90")))


func _run() -> void:
	var before := {}
	for f in OTHER:
		before[f] = FileAccess.get_file_as_string(f)
	for b in Ta90TimeAttack.BOARDS90:
		before[Ta90TimeAttack.state_path90(b)] = FileAccess.get_file_as_string(Ta90TimeAttack.state_path90(b))
	AudioManager.unlocked = true
	AudioManager.music_enabled = true
	_bank()
	await _hub_and_select()
	for b in Extreme90Bank.BANK:
		await _solve_on_page(b)
	await _timeup_untimed(Extreme90Bank.BANK[0])
	await _short_flows()
	_check(before.keys().all(func(f): return FileAccess.get_file_as_string(f) == before[f]),
		"?ta90=1's records (hub and every board), the 120-second pilot's and the standalone pages' storage untouched")
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no campaign progress written")
	print("EXTREME90 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _rec(b: String) -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(Ta90TimeAttack.BOARDS90[b]["data"]))
	return d["boards"].filter(func(x): return str(x["id"]) == b)[0]


func _bank() -> void:
	var bank: Array = Extreme90Bank.BANK
	var same := true
	for b in BASELINE:
		same = same and Ta90TimeAttack.BOARDS90[b]["fp"] == BASELINE[b] and PuzzleDefinition.from_dict(_rec(b)["puzzle"]).fingerprint() == BASELINE[b]
	_check(bank.slice(0, 5) == ["N3", "N5", "N7", "N11", "N13"] and same,
		"the bank starts with N3, N5, N7, N11, N13: their board data and fingerprints exactly as accepted in Phases 14 / 15")
	var ok := true
	var fps := {}
	for b in bank:
		var def := PuzzleDefinition.from_dict(_rec(b)["puzzle"])
		ok = ok and Ta90TimeAttack.BOARDS90.has(b) and def.fingerprint() == Ta90TimeAttack.BOARDS90[b]["fp"] and not Ta90TimeAttack.BOARDS90[b].get("reference", false)
		fps[def.fingerprint()] = true
	_check(ok and fps.size() == bank.size() and not bank.has("TA"), "every bank board (%d) loads with its own fingerprint; no reference board" % bank.size())
	var arch: Array = Ta90Prototype.ORDER90
	_check(arch.size() == 13 and range(1, 14).all(func(i): return arch[i - 1] == "N%d" % i and FileAccess.file_exists(Ta90TimeAttack.BOARDS90["N%d" % i]["data"])),
		"the experimental collection (?ta90=1, N1-N13) is complete and its data files are kept (the 8 boards outside the bank archived, not deleted)")
	_check(Extreme90Bank.BANK_STATE_PATH != Ta90Prototype.STATE_PATH and Extreme90Bank.BANK_LS_KEY != Ta90Prototype.LS_KEY
		and Ta90TimeAttack.state_path90("N3", "xb90") != Ta90TimeAttack.state_path90("N3") and Ta90TimeAttack.ls_key90("N3", "xb90") != Ta90TimeAttack.ls_key90("N3"),
		"the bank's own storage (hub and boards), apart from ?ta90=1")


func _hub() -> Extreme90Bank:
	var h := Extreme90Bank.new()
	add_child(h)
	await _frames(3)
	return h


func _close(n: Node) -> void:
	n.queue_free()
	await _frames(2)


func _hint_gone(sp: SocialPlay) -> bool:
	var hb: Button = sp._hint
	return not hb.is_visible_in_tree() and hb.pressed.get_connections().is_empty() and hb.process_mode == Node.PROCESS_MODE_DISABLED and sp.max_hints == 0


func _solution(b: String) -> Array:
	var s := Solver.from_model(EV6.model_of(PuzzleDefinition.from_dict(_rec(b)["puzzle"]).to_level()))
	return s.solve_moves().map(func(m): return m & Solver.ID_MASK)


func _hub_and_select() -> void:
	var mbus := AudioServer.get_bus_index("Music")
	var h := await _hub()
	_check(h.view == Ta90Prototype.View.WELCOME and AudioServer.is_bus_mute(mbus), "?extreme90=1: the welcome screen; the campaign music bus silent while open")
	(h.find_child("PilotStart", true, false) as Button).pressed.emit()
	await _frames(1)
	(h.find_child("Familiar_PLAYED_A_LITTLE", true, false) as Button).pressed.emit()
	await _frames(2)
	var vis := h.get_viewport().get_visible_rect()
	var n: int = Extreme90Bank.BANK.size()
	var tiles_ok := true
	for i in range(1, n + 1):
		var t: Control = h.find_child("Puzzle_%d" % i, true, false)
		tiles_ok = tiles_ok and t != null and t.text == "CHALLENGE %d" % i and vis.encloses(t.get_global_rect()) and t.size.y >= 80
	_check(h.view == Ta90Prototype.View.SELECT and h.order == Extreme90Bank.BANK and tiles_ok and h.find_child("Puzzle_%d" % (n + 1), true, false) == null
		and h._rows.values().all(func(r): return r[1].text == "New") and vis.encloses(h._copy.get_global_rect()),
		"CHOOSE A CHALLENGE: only the bank, CHALLENGE 1-%d (neutral, no difficulty, no reference), all on screen with COPY ALL RESULTS" % n)
	await _close(h)
	_check(not AudioServer.is_bus_mute(mbus), "closing the bank restores the campaign music bus")


## A bank board on the real page: its brief, a timed run under ta90-v1, the
## Solver's line clears it, and the export carries it under its internal id.
func _solve_on_page(b: String) -> void:
	var h := await _hub()
	h.open_puzzle(b)
	await _frames(3)
	var p := h.page
	var k: int = Extreme90Bank.BANK.find(b) + 1
	var brief: String = p._brief_text.text
	_check(p.board_ok and p.store == "xb90" and p.screen == VhHumanTest.Screen.BRIEF and brief.begins_with("CHALLENGE %d" % k) and not brief.contains("PUZZLE")
		and brief.contains("You have 90 seconds.") and brief.contains("No hints."), "%s: CHALLENGE %d's brief (neutral label, 90 seconds, no hints)" % [b, k])
	p._brief_go.pressed.emit()
	await _frames(4)
	_check(p.run_active() and p.limit() == LIM and _hint_gone(p.play) and p.play.max_undos == 3 and p.play.max_hammers == 0 and p.play._title.text == "CHALLENGE %d" % k
		and p._current.get("assist", {}).get("version", "") == "ta90-v1" and p.music.stage == "green", "%s: a 90 s run (ta90-v1, UNDO x3, no SHOW A MOVE / HAMMER), GREEN music" % b)
	for mv in _solution(b):
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(p.state["timed"]["outcome"] == "COMPLETED" and p._card_head.text == "SOLVED" and p.music.stage == "", "%s: the Solver's line clears it (SOLVED; the music fades out)" % b)
	await _close(h)
	h = await _hub()
	var bd: Dictionary = h.bundle()
	var bb: Dictionary = bd["boards"][b]
	var tm: Dictionary = bb["in_progress"].get("timed", {}) if not bb["in_progress"].is_empty() else {}
	_check(bd["format"] == "ce-xb90" and bb["fingerprint"] == Ta90TimeAttack.BOARDS90[b]["fp"] and bb["puzzle"] == k and tm.get("outcome", "") == "COMPLETED"
		and FileAccess.file_exists(Ta90TimeAttack.state_path90(b, "xb90")), "%s: exported as CHALLENGE %d under its id and fingerprint; stored as xb90_%s" % [b, k, b.to_lower()])
	await _close(h)


## TIME UP, the questions and the untimed continuation (calm mix) on a bank board.
func _timeup_untimed(b: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, "xb90")))
	var h := await _hub()
	h.open_puzzle(b)
	await _frames(3)
	var p := h.page
	if p.screen == VhHumanTest.Screen.BRIEF:
		p._brief_go.pressed.emit()
	await _frames(4)
	p.debug_offset_ms += (LIM - 30000) - p.elapsed_ms()
	await _frames(3)
	_check(p._stage == "red" and p.music.stage == "red", "%s: 0:30 RED, the red mix" % b)
	p.debug_offset_ms += LIM - p.elapsed_ms()
	await _frames(3)
	_check(p.state.get("timed", {}).get("outcome", "") == "TIME UP" and int(p.state["timed"]["elapsed_ms"]) == LIM and p.music.stage == "", "%s: TIME UP at 90 s; the music fades out" % b)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(p.screen == VhHumanTest.Screen.THINK and p._questions == Ta90TimeAttack.SHORT_Q and p._q_label.text == Ta90TimeAttack.SHORT_Q[0][1],
		"%s: after TIME UP, the SHORT questionnaire (3 questions)" % b)
	for a in ["EXTREME", "4", "YES"]:
		p.think(a)
	await _frames(2)
	_check(p.phase() == "offer" and p._untimed_btn.visible and p.state["timed"]["answers"] == {"difficulty": "EXTREME", "enjoy": "4", "another": "YES"}
		and p.state["timed"]["answers_set"] == Ta90TimeAttack.SHORT_SET, "%s: 3 answers, then CONTINUE WITHOUT TIMER is offered (no other question)" % b)
	p._untimed_btn.pressed.emit()
	await _frames(4)
	_check(p.phase() == "untimed" and p._count.text == "NO TIMER" and p.music.stage == "calm" and _hint_gone(p.play), "%s: CONTINUE WITHOUT TIMER - NO TIMER, the calm mix, still no SHOW A MOVE" % b)
	p.play.restart()
	await _frames(1)
	for mv in _solution(b):
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(p._card_head.text == "SOLVED" and p.state["timed"]["outcome"] == "TIME UP" and not p._card_text.text.contains("questions"),
		"%s: solved without the timer; the timed result stays TIME UP; the card announces no more questions" % b)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(4)
	var rs: Array = Ta90TimeAttack.read_state90(b, "xb90").get("results", [])
	_check(rs.size() == 1 and rs[0]["timed"]["outcome"] == "TIME UP" and rs[0]["untimed"].get("completed", false) and rs[0]["puzzle_answers"] == {"_after": "untimed play"}
		and h.view == Ta90Prototype.View.SELECT, "%s: CONTINUE stores the run at once - no post-play questionnaire after the untimed game; back to CHOOSE A CHALLENGE" % b)
	await _close(h)


func _results(b: String) -> Array:
	return Ta90TimeAttack.read_state90(b, "xb90").get("results", [])


## Opens a bank board and starts its timed run (a replay when played before).
func _start(h: Extreme90Bank, b: String) -> Ta90TimeAttack:
	h.open_puzzle(b)
	await _frames(3)
	var p := h.page
	if p.screen == VhHumanTest.Screen.BRIEF:
		p._brief_go.pressed.emit()
	await _frames(4)
	return p


## Phase 16A: the SHORT questionnaire in every ending - a win answered, a win
## skipped, a GIVE UP, TIME UP skipped then FINISH - replay, the next
## challenge, the export, and ?ta90=1 still asking its own questions.
func _short_flows() -> void:
	var b: String = Extreme90Bank.BANK[1]
	var nxt: String = Extreme90Bank.BANK[2]
	for x in [b, nxt]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(x, "xb90")))
	var h := await _hub()
	# 1. A timed win, the three answers: stored at once.
	var p := await _start(h, b)
	for mv in _solution(b):
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(p._card_text.text.contains("Three quick questions next (or SKIP).") and p.short_q, "WIN: the card says three quick questions, or SKIP")
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	var backs: Array = p.find_children("BackToPuzzles", "Button", true, false)
	var opts_ok: bool = p._think_opts.find_child("Think_VERY_HARD", true, false) != null and p._think_skip.is_visible_in_tree() \
		and not backs.is_empty() and backs.all(func(x): return x.text == "BACK TO CHALLENGES")
	p.think("HARD")
	await _frames(1)
	var row: Node = p._think_opts.find_child("Think_3", true, false)
	var row_ok: bool = row != null and row.get_parent() is HBoxContainer and p._q_label.text == Ta90TimeAttack.SHORT_Q[1][1]
	p.think("5")
	await _frames(1)
	var yn: Node = p._think_opts.find_child("Think_YES", true, false)
	var yn_ok: bool = yn != null and yn.get_parent() is HBoxContainer and p._think_opts.find_child("Think_NO", true, false) != null
	p.think("NO")
	await _frames(4)
	var rs := _results(b)
	_check(opts_ok and row_ok and yn_ok, "the questions: EASY ... EXTREME one per line, 1-5 in one row, YES / NO in one row, SKIP always shown, BACK TO CHALLENGES")
	_check(rs.size() == 1 and rs[0]["timed"]["outcome"] == "COMPLETED" and rs[0]["timed"]["answers"] == {"difficulty": "HARD", "enjoy": "5", "another": "NO"}
		and rs[0]["timed"]["answers_set"] == Ta90TimeAttack.SHORT_SET and rs[0]["puzzle_answers"] == {"_after": "timed win"} and h.view == Ta90Prototype.View.SELECT,
		"WIN: the 3 answers stored at once with the set's version (no post-play questions); back to CHOOSE A CHALLENGE")
	# 2. Replay the same challenge: a new run; this time SKIP.
	p = await _start(h, b)
	_check(p.run_active() and int(p.state["run"]["n"]) == 2, "REPLAY: the same challenge again is a new 90 s run (run 2)")
	for mv in _solution(b):
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	p._think_skip.pressed.emit()
	await _frames(4)
	rs = _results(b)
	_check(rs.size() == 2 and rs[1]["timed"]["outcome"] == "COMPLETED" and rs[1]["timed"].get("answers_skipped", false)
		and not rs[1]["timed"].get("answers", {}).has("difficulty") and h.view == Ta90Prototype.View.SELECT,
		"SKIP: one tap leaves the whole questionnaire (recorded as skipped, nothing inferred); the run is stored; back to the selection")
	# 3. The next challenge: GIVE UP, then SKIP.
	p = await _start(h, nxt)
	_check(p.run_active() and p.board_key == nxt, "NEXT CHALLENGE: opens and runs after a skipped questionnaire")
	p.give_up()
	p.give_up()
	await _frames(3)
	_check(p.state.get("timed", {}).get("outcome", "") == "GAVE UP", "GIVE UP: the timed result is GAVE UP")
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(p.screen == VhHumanTest.Screen.THINK and p._questions == Ta90TimeAttack.SHORT_Q, "GIVE UP: the same three questions")
	p._think_skip.pressed.emit()
	await _frames(4)
	rs = _results(nxt)
	_check(rs.size() == 1 and rs[0]["timed"]["outcome"] == "GAVE UP" and rs[0]["puzzle_answers"] == {"_after": "timed give up"} and h.view == Ta90Prototype.View.SELECT,
		"GIVE UP + SKIP: stored at once; back to the selection")
	# 4. TIME UP, SKIP: the untimed offer straight away; FINISH stores it.
	p = await _start(h, nxt)
	p.debug_offset_ms += LIM - p.elapsed_ms()
	await _frames(3)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	p._think_skip.pressed.emit()
	await _frames(2)
	_check(p.phase() == "offer" and p._untimed_btn.visible and p._finish_btn.visible, "TIME UP + SKIP: CONTINUE WITHOUT TIMER / FINISH offered at once")
	p._finish_btn.pressed.emit()
	await _frames(4)
	rs = _results(nxt)
	_check(rs.size() == 2 and rs[1]["timed"]["outcome"] == "TIME UP" and rs[1]["timed"].get("answers_skipped", false) and rs[1]["puzzle_answers"] == {"_after": "finish after TIME UP"}
		and h.view == Ta90Prototype.View.SELECT, "FINISH after TIME UP: stored at once - no question after TIME UP beyond the three")
	# 5. The export: answers apart from the automatic telemetry.
	var bd: Dictionary = h.bundle()
	var runs: Array = bd["runs"].filter(func(r): return r["board"] == b)
	var r0: Dictionary = runs[0] if not runs.is_empty() else {}
	var raw: Array = bd["boards"][b]["raw"]
	_check(bd["questionnaire"] == Ta90TimeAttack.SHORT_SET and bd["boards"][b]["mechanics"] == _rec(b)["mechanics"] and not bd["boards"][b]["mechanics"].is_empty(),
		"export: the questionnaire version, and each board's mechanics")
	_check(runs.size() == 2 and r0["timed_outcome"] == "COMPLETED" and r0["timed_success"] and r0["fingerprint"] == Ta90TimeAttack.BOARDS90[b]["fp"]
		and r0["timed_answers"] == {"difficulty": "HARD", "enjoy": "5", "another": "NO"} and r0.has("elapsed_ms") and r0.has("restarts") and r0.has("undos")
		and r0.has("blocked_taps") and r0.has("attempts") and r0.has("moves"),
		"export: id, fingerprint, timed_outcome, time, attempts, restarts, moves, UNDO, blocked taps - the three answers apart in timed_answers")
	_check(raw.size() == 2 and raw[0]["timed"]["answers_set"] == Ta90TimeAttack.SHORT_SET and raw[1]["timed"].get("answers_skipped", false)
		and runs[1]["timed_answers"].is_empty() and runs[1]["timed_outcome"] == "COMPLETED",
		"export: the raw records keep the set's version and the skip; a skipped questionnaire leaves the answers empty, the outcome still COMPLETED")
	await _close(h)
	# 6. ?ta90=1 unchanged: its page still asks its own 8 timed questions.
	var t90 := Ta90TimeAttack.new("N3")
	_check(not t90.short_q and t90.timed_q() == Ta90TimeAttack.P90_TIMED_Q and t90.timed_q().size() == 8 and not Ta90Prototype.new().short_questions(),
		"?ta90=1 (and its records) unchanged: no short questionnaire there")
	t90.free()
