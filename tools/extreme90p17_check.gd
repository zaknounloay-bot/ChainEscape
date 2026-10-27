extends "res://tools/extreme90_check.gd"
## Phase 17 EXTREME selection (development only, ?extreme90p17=1): end-to-end
## checks of Extreme90Review on the unchanged 90-second page.
##   godot --headless --path . res://tools/Extreme90p17Check.tscn
## The selection: CORE (exact Phase 14 / 15 fingerprints), the five strong
## Phase 16 boards, N23 provisional (internal only) and the Phase 17
## candidates; the archived boards (N17, N19, N20, N22) out of the selection
## but kept in BOARDS90 and on ?extreme90=1; neutral CHALLENGE labels; every
## board solved on the real page and exported under its id and fingerprint;
## TIME UP, the SHORT questionnaire and the untimed continuation; SKIP; its
## own storage, apart from ?extreme90=1, ?ta90=1 and the 120-second pilot.

const ST := "xb17"


func _clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Extreme90Review.REVIEW_STATE_PATH))
	for b in Ta90TimeAttack.BOARDS90:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, ST)))


func _run() -> void:
	var before := {}
	for f in OTHER + [Extreme90Bank.BANK_STATE_PATH]:
		before[f] = FileAccess.get_file_as_string(f)
	for b in Ta90TimeAttack.BOARDS90:
		for st in ["ta90", "xb90"]:
			before[Ta90TimeAttack.state_path90(b, st)] = FileAccess.get_file_as_string(Ta90TimeAttack.state_path90(b, st))
	AudioManager.unlocked = true
	AudioManager.music_enabled = true
	_selection()
	await _select_screen()
	for b in Extreme90Review.selection():
		await _solve17(b)
	await _timeup17(Extreme90Review.selection()[-1])
	await _skip17(Extreme90Review.selection()[0])
	await _export17()
	_check(before.keys().all(func(f): return FileAccess.get_file_as_string(f) == before[f]),
		"?extreme90=1's and ?ta90=1's records (hubs and every board), the 120-second pilot's and the standalone pages' storage untouched")
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no campaign progress written")
	print("EXTREME90 P17 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _selection() -> void:
	var sel := Extreme90Review.selection()
	var same := true
	for b in BASELINE:
		same = same and Ta90TimeAttack.BOARDS90[b]["fp"] == BASELINE[b] and PuzzleDefinition.from_dict(_rec(b)["puzzle"]).fingerprint() == BASELINE[b]
	_check(Extreme90Review.CORE == ["N3", "N5", "N7", "N11", "N13"] and sel.slice(0, 5) == Extreme90Review.CORE and same,
		"CORE first: N3, N5, N7, N11, N13 with their exact Phase 14 / 15 fingerprints")
	_check(Extreme90Review.STRONG == ["N14", "N15", "N16", "N18", "N21"] and Extreme90Review.PROVISIONAL == ["N23"]
		and sel.slice(5, 11) == ["N14", "N15", "N16", "N18", "N21", "N23"], "then the strong Phase 16 boards and N23 (provisional)")
	_check(Extreme90Review.ARCHIVED.all(func(a): return not sel.has(a) and Extreme90Bank.BANK.has(a) and Ta90TimeAttack.BOARDS90.has(a) and FileAccess.file_exists(Ta90TimeAttack.BOARDS90[a]["data"])),
		"N17, N19, N20, N22 archived: out of the selection, still defined (data, fingerprint) and still on ?extreme90=1")
	var ok := true
	var fps := {}
	var nums := []
	for b in sel:
		var def := PuzzleDefinition.from_dict(_rec(b)["puzzle"])
		ok = ok and def != null and def.fingerprint() == Ta90TimeAttack.BOARDS90[b]["fp"] and not Ta90TimeAttack.BOARDS90[b].get("reference", false)
		fps[def.fingerprint()] = true
	for b in Extreme90Review.NEW17:
		nums.append(int(str(b).substr(1)))
	_check(ok and fps.size() == sel.size() and not sel.has("TA"), "every selection board (%d) loads with its own fingerprint; no reference board" % sel.size())
	_check(nums == range(24, 24 + nums.size()) and Extreme90Review.NEW17.all(func(b): return not Extreme90Bank.BANK.has(b) and not Ta90Prototype.ORDER90.has(b)),
		"the Phase 17 boards are N24-N%d: new ids, no existing id reused, not on ?extreme90=1 or ?ta90=1" % (23 + nums.size()))
	_check(Extreme90Bank.BANK.size() == 15 and Ta90Prototype.ORDER90.size() == 13, "?extreme90=1 (15 boards) and ?ta90=1 (13 boards) unchanged")
	_check(Extreme90Review.REVIEW_STATE_PATH != Extreme90Bank.BANK_STATE_PATH and Extreme90Review.REVIEW_LS_KEY != Extreme90Bank.BANK_LS_KEY
		and Ta90TimeAttack.state_path90("N3", ST) != Ta90TimeAttack.state_path90("N3", "xb90") and Ta90TimeAttack.ls_key90("N3", ST) != Ta90TimeAttack.ls_key90("N3", "xb90"),
		"the selection's own storage (hub and boards), apart from ?extreme90=1")


func _hub() -> Extreme90Bank:
	var h := Extreme90Review.new()
	add_child(h)
	await _frames(3)
	return h


func _select_screen() -> void:
	var mbus := AudioServer.get_bus_index("Music")
	var h := await _hub()
	_check(h.view == Ta90Prototype.View.WELCOME and AudioServer.is_bus_mute(mbus), "?extreme90p17=1: the welcome screen; the campaign music bus silent while open")
	(h.find_child("PilotStart", true, false) as Button).pressed.emit()
	await _frames(1)
	(h.find_child("Familiar_PLAYED_A_LITTLE", true, false) as Button).pressed.emit()
	await _frames(2)
	var vis := h.get_viewport().get_visible_rect()
	var sel := Extreme90Review.selection()
	var n: int = sel.size()
	var tiles_ok := true
	var hidden := true
	for i in range(1, n + 1):
		var t: Control = h.find_child("Puzzle_%d" % i, true, false)
		tiles_ok = tiles_ok and t != null and t.text == "CHALLENGE %d" % i and vis.encloses(t.get_global_rect()) and t.size.y >= 80
	for l in h.find_children("*", "Label", true, false) + h.find_children("*", "Button", true, false):
		var tx: String = l.text.to_upper()
		hidden = hidden and not tx.contains("PROVISIONAL") and not tx.contains("CORE") and not tx.contains("N23") and not tx.contains("EXTREME\n") or tx == "EXTREME\nTIME ATTACK"
	_check(h.view == Ta90Prototype.View.SELECT and h.order == sel and tiles_ok and h.find_child("Puzzle_%d" % (n + 1), true, false) == null
		and vis.encloses(h._copy.get_global_rect()), "CHOOSE A CHALLENGE: the selection only, CHALLENGE 1-%d, all on screen with COPY ALL RESULTS" % n)
	_check(hidden, "no internal group, id or difficulty shown (N23's provisional status stays internal)")
	await _close(h)
	_check(not AudioServer.is_bus_mute(mbus), "closing the selection restores the campaign music bus")


func _solve17(b: String) -> void:
	var h := await _hub()
	h.open_puzzle(b)
	await _frames(3)
	var p := h.page
	var k: int = Extreme90Review.selection().find(b) + 1
	var brief: String = p._brief_text.text
	_check(p.board_ok and p.store == ST and brief.begins_with("CHALLENGE %d" % k) and brief.contains("You have 90 seconds.") and brief.contains("No hints."),
		"%s: CHALLENGE %d's brief (neutral, 90 seconds, no hints)" % [b, k])
	p._brief_go.pressed.emit()
	await _frames(4)
	_check(p.run_active() and p.limit() == LIM and _hint_gone(p.play) and p.play.max_undos == 3 and p.play.max_hammers == 0 and p.short_q
		and p._current.get("assist", {}).get("version", "") == "ta90-v1" and p.music.stage == "green", "%s: a 90 s run (ta90-v1, UNDO x3, no hints / HAMMER, short questions), GREEN music" % b)
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
	_check(bd["format"] == "ce-xb17" and bb["fingerprint"] == Ta90TimeAttack.BOARDS90[b]["fp"] and bb["puzzle"] == k and tm.get("outcome", "") == "COMPLETED"
		and FileAccess.file_exists(Ta90TimeAttack.state_path90(b, ST)), "%s: exported as CHALLENGE %d under its id and fingerprint; stored as xb17_%s" % [b, k, b.to_lower()])
	await _close(h)


func _timeup17(b: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, ST)))
	var h := await _hub()
	var p := await _start(h, b)
	p.debug_offset_ms += (LIM - 60000) - p.elapsed_ms()
	await _frames(3)
	_check(p._stage == "orange" and p.music.stage == "orange", "%s: 1:00 ORANGE, the orange mix" % b)
	p.debug_offset_ms += (LIM - 30000) - p.elapsed_ms()
	await _frames(3)
	_check(p._stage == "red" and p.music.stage == "red", "%s: 0:30 RED, the red mix" % b)
	p.debug_offset_ms += LIM - p.elapsed_ms()
	await _frames(3)
	_check(p.state.get("timed", {}).get("outcome", "") == "TIME UP" and int(p.state["timed"]["elapsed_ms"]) == LIM and p.music.stage == "", "%s: TIME UP at 90 s; the music fades out" % b)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	_check(p.screen == VhHumanTest.Screen.THINK and p._questions == Ta90TimeAttack.SHORT_Q and p._think_skip.visible, "%s: after TIME UP, the 3 short questions with SKIP" % b)
	for a in ["VERY HARD", "5", "YES"]:
		p.think(a)
	await _frames(2)
	_check(p.phase() == "offer" and p.state["timed"]["answers"] == {"difficulty": "VERY HARD", "enjoy": "5", "another": "YES"}, "%s: 3 answers, then CONTINUE WITHOUT TIMER offered" % b)
	p._untimed_btn.pressed.emit()
	await _frames(4)
	_check(p.phase() == "untimed" and p._count.text == "NO TIMER" and p.music.stage == "calm" and _hint_gone(p.play), "%s: untimed continuation - NO TIMER, the calm mix, no hints" % b)
	p.play.restart()
	await _frames(1)
	for mv in _solution(b):
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(4)
	var rs: Array = Ta90TimeAttack.read_state90(b, ST).get("results", [])
	_check(rs.size() == 1 and rs[0]["timed"]["outcome"] == "TIME UP" and rs[0]["untimed"].get("completed", false) and h.view == Ta90Prototype.View.SELECT,
		"%s: solved untimed; the timed result stays TIME UP; stored at once" % b)
	await _close(h)


func _skip17(b: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, ST)))
	var h := await _hub()
	var p := await _start(h, b)
	var restarts_ms := p.elapsed_ms()
	p.play.tap_block(_solution(b)[0])
	await _wait(0.2)
	p.play.restart()
	await _frames(2)
	_check(p.run_active() and p.elapsed_ms() >= restarts_ms, "%s: RESTART keeps the clock running (no reset)" % b)
	p.give_up()
	p.give_up()
	await _frames(3)
	var gave: bool = p.state.get("timed", {}).get("outcome", "") == "GAVE UP"
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	p._think_skip.pressed.emit()
	await _frames(4)
	var rs: Array = Ta90TimeAttack.read_state90(b, ST).get("results", [])
	_check(gave and rs.size() == 1 and rs[0]["timed"]["outcome"] == "GAVE UP" and rs[0]["puzzle_answers"] == {"_after": "timed give up"} and h.view == Ta90Prototype.View.SELECT,
		"%s: GIVE UP, one-tap SKIP: stored at once, back to the selection" % b)
	await _close(h)


func _export17() -> void:
	var h := await _hub()
	var bd: Dictionary = h.bundle()
	var groups_ok := true
	for k in bd["boards"]:
		var g: String = bd["boards"][k]["group"]
		groups_ok = groups_ok and g == ("core" if Extreme90Review.CORE.has(k) else "strong" if Extreme90Review.STRONG.has(k) else "provisional" if k == "N23" else "phase17")
	_check(bd["format"] == "ce-xb17" and bd["selection"] == Extreme90Review.SELECTION and bd["archived"] == Extreme90Review.ARCHIVED and bd["questionnaire"] == Ta90TimeAttack.SHORT_SET
		and bd["boards"].keys().size() == Extreme90Review.selection().size() and groups_ok and bd["boards"]["N23"]["group"] == "provisional",
		"export ce-xb17: the selection version, each board's group (N23 provisional), the archived ids, the questionnaire version")
	var js := JSON.stringify(bd)
	var back = JSON.parse_string(js)
	_check(typeof(back) == TYPE_DICTIONARY and back["boards"].keys().size() == bd["boards"].keys().size(), "the export is valid JSON and round-trips")
	await _close(h)
	var old := Extreme90Bank.new()
	add_child(old)
	await _frames(3)
	var ob: Dictionary = old.bundle()
	_check(ob["format"] == "ce-xb90" and not ob.has("selection") and ob["boards"].keys().size() == Extreme90Bank.BANK.size(), "?extreme90=1's export (ce-xb90) unchanged: the archive still exports all 15 boards")
	await _close(old)
