extends "res://tools/extreme90_check.gd"
## Phase 19 EXTREME selection (development only, ?extreme90p19=1): end-to-end
## checks of Extreme90P19 on the unchanged 90-second page (the Phase 18 check,
## run on the Phase 19 page: its storage, export, groups; the primary screen
## with only the new boards, the optional PREVIOUS CHALLENGES screen).
##   godot --headless --path . res://tools/Extreme90p19Check.tscn
## The selection: CORE (exact Phase 14 / 15 fingerprints), the nine strong
## boards, N23 and N24 provisional (internal only) and the Phase 18
## candidates; the archived boards (N17, N19, N20, N22, N25, N28) out of the
## selection but kept in BOARDS90 and on ?extreme90=1 / ?extreme90p17=1;
## neutral CHALLENGE labels; every board solved on the real page and exported
## under its id and fingerprint; TIME UP, the SHORT questionnaire and the
## untimed continuation; SKIP; the TIME UP position of a Movable / portal
## board kept for the untimed continuation; its own storage, apart from
## every earlier entry.

const ST := "xb19"


func _clear() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Extreme90P19.P19_STATE_PATH))
	for b in Ta90TimeAttack.BOARDS90:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, ST)))


func _run() -> void:
	var before := {}
	for f in OTHER + [Extreme90Bank.BANK_STATE_PATH, Extreme90Review.REVIEW_STATE_PATH, Extreme90P18.P18_STATE_PATH]:
		before[f] = FileAccess.get_file_as_string(f)
	for b in Ta90TimeAttack.BOARDS90:
		for st in ["ta90", "xb90", "xb17", "xb18"]:
			before[Ta90TimeAttack.state_path90(b, st)] = FileAccess.get_file_as_string(Ta90TimeAttack.state_path90(b, st))
	AudioManager.unlocked = true
	AudioManager.music_enabled = true
	_selection()
	await _select_screen()
	for b in Extreme90P19.selection19():
		await _solve17(b)
	await _timeup17(Extreme90P19.NEW19[-1])
	await _skip17(Extreme90P19.selection19()[0])
	await _export17()
	await _timeup_position18()
	_check(before.keys().all(func(f): return FileAccess.get_file_as_string(f) == before[f]),
		"?extreme90=1's, ?extreme90p17=1's, ?extreme90p18=1's and ?ta90=1's records (hubs and every board), the 120-second pilot's and the standalone pages' storage untouched")
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no campaign progress written")
	print("EXTREME90 P19 CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _selection() -> void:
	var sel := Extreme90P19.selection19()
	var same := true
	for b in BASELINE:
		same = same and Ta90TimeAttack.BOARDS90[b]["fp"] == BASELINE[b] and PuzzleDefinition.from_dict(_rec(b)["puzzle"]).fingerprint() == BASELINE[b]
	var nn: int = Extreme90P19.NEW19.size()
	_check(sel.slice(0, nn) == Extreme90P19.NEW19 and sel.size() == nn + 20, "the Phase 19 boards first: CHALLENGE 1-%d = %s" % [nn, ", ".join(Extreme90P19.NEW19)])
	_check(sel.slice(nn, nn + 5) == ["N3", "N5", "N7", "N11", "N13"] and same, "then CORE: N3, N5, N7, N11, N13 with their exact Phase 14 / 15 fingerprints")
	_check(sel.slice(nn) == Extreme90P18.selection() and Extreme90P18.selection().size() == 20,
		"then the Phase 18B selection unchanged: 13 strong (N31-N34 included), N23 and N24 provisional")
	var groups := {}
	for b in sel:
		groups[Extreme90P19.group19(b)] = int(groups.get(Extreme90P19.group19(b), 0)) + 1
	_check(int(groups.get("core", 0)) + int(groups.get("strong", 0)) == 18 and int(groups.get("provisional", 0)) == 2
		and int(groups.get("phase19", 0)) == Extreme90P19.NEW19.size(), "18 core / strong, 2 provisional, %d Phase 19 candidates" % Extreme90P19.NEW19.size())
	_check(Extreme90P18.ARCHIVED.all(func(a): return _archived_ok(a, sel)),
		"N17, N19, N20, N22, N25, N28 archived: out of the selection, still defined and still on ?extreme90=1 / ?extreme90p17=1")
	var ok := true
	var fps := {}
	var nums := []
	for b in sel:
		var def := PuzzleDefinition.from_dict(_rec(b)["puzzle"])
		ok = ok and def != null and def.fingerprint() == Ta90TimeAttack.BOARDS90[b]["fp"] and not Ta90TimeAttack.BOARDS90[b].get("reference", false)
		fps[def.fingerprint()] = true
	for b in Extreme90P19.NEW19:
		nums.append(int(str(b).substr(1)))
	_check(ok and fps.size() == sel.size() and not sel.has("TA"), "every selection board (%d) loads with its own fingerprint; no reference board" % sel.size())
	_check(nums == range(35, 35 + nums.size()) and Extreme90P19.NEW19.all(func(b): return not Extreme90P18.selection().has(b) and not Extreme90Bank.BANK.has(b)),
		"the Phase 19 boards are N35-N%d: new ids, on no earlier entry" % (34 + nums.size()))
	_check(Extreme90Bank.BANK.size() == 15 and Ta90Prototype.ORDER90.size() == 13 and Extreme90Review.selection().size() == 18 and Extreme90P18.selection().size() == 20,
		"?extreme90=1 (15), ?extreme90p17=1 (18), ?extreme90p18=1 (20) and ?ta90=1 (13) unchanged")
	_check(Extreme90P19.P19_STATE_PATH != Extreme90P18.P18_STATE_PATH and Ta90TimeAttack.state_path90("N3", ST) != Ta90TimeAttack.state_path90("N3", "xb18"),
		"the selection's own storage (hub and boards), apart from every earlier entry")


func _hub() -> Extreme90Bank:
	var h := Extreme90P19.new()
	add_child(h)
	await _frames(3)
	return h


func _select_screen() -> void:
	var mbus := AudioServer.get_bus_index("Music")
	var h := await _hub()
	_check(h.view == Ta90Prototype.View.WELCOME and AudioServer.is_bus_mute(mbus), "?extreme90p19=1: the welcome screen; the campaign music bus silent while open")
	(h.find_child("PilotStart", true, false) as Button).pressed.emit()
	await _frames(1)
	(h.find_child("Familiar_PLAYED_A_LITTLE", true, false) as Button).pressed.emit()
	await _frames(2)
	var vis := h.get_viewport().get_visible_rect()
	var sel := Extreme90P19.selection19()
	var nn: int = Extreme90P19.NEW19.size()
	var main: Control = h._pages[Ta90Prototype.View.SELECT]
	var tiles_ok := true
	var hidden := true
	for i in range(1, nn + 1):
		var t: Control = main.find_child("Puzzle_%d" % i, true, false)
		tiles_ok = tiles_ok and t != null and t.text == "CHALLENGE %d" % i and vis.encloses(t.get_global_rect()) and t.size.y >= 80
	for l in h.find_children("*", "Label", true, false) + h.find_children("*", "Button", true, false):
		var tx: String = l.text.to_upper()
		hidden = hidden and not tx.contains("PROVISIONAL") and not tx.contains("CORE") and not tx.contains("N23") and not tx.contains("EXTREME\n") or tx == "EXTREME\nTIME ATTACK"
	var more: Control = main.find_child("PreviousChallenges", true, false)
	_check(h.view == Ta90Prototype.View.SELECT and h.order == sel and h.new_boards() == Extreme90P19.NEW19 and tiles_ok
		and main.find_child("Puzzle_%d" % (nn + 1), true, false) == null and main.find_child("PuzzleScroll", true, false) == null and main.find_child("SelectNote", true, false) == null
		and more != null and vis.encloses(more.get_global_rect()) and vis.encloses(h._copy.get_global_rect()) and vis.encloses(main.find_child("HowItWorks", true, false).get_global_rect()),
		"CHOOSE A CHALLENGE: ONLY the new boards (CHALLENGE 1-%d = %s, found as the boards not on the previous list), no scrolling; PREVIOUS CHALLENGES, COPY ALL RESULTS and HOW IT WORKS on the iPhone SE screen" % [nn, ", ".join(Extreme90P19.NEW19)])
	_check(hidden, "no internal group, id or difficulty shown (N23's provisional status stays internal)")
	(more as Button).pressed.emit()
	await _frames(2)
	var pv: Control = h._pages[Ta90Prototype.View.PREVIOUS]
	var sc: ScrollContainer = pv.find_child("PreviousScroll", true, false)
	var reach := true
	for i in range(nn + 1, sel.size() + 1):
		var t := pv.find_child("Puzzle_%d" % i, true, false) as Button
		sc.ensure_control_visible(t)
		await _frames(2)
		var fits: bool = t.get_theme_font("font").get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, t.get_theme_font_size("font_size")).x <= t.size.x - 24
		reach = reach and t.text == "CHALLENGE %d" % i and sc.get_global_rect().encloses(t.get_global_rect()) and t.size.y >= 84 and fits
	var bk: Control = pv.find_child("PreviousBack", true, false)
	_check(h.view == Ta90Prototype.View.PREVIOUS and pv.visible and not main.visible and reach and vis.encloses(sc.get_global_rect()) and vis.encloses(bk.get_global_rect())
		and pv.find_child("Puzzle_1", true, false) == null and h.previous_boards() == Extreme90P18.selection(),
		"PREVIOUS CHALLENGES (optional): the %d earlier boards, CHALLENGE %d-%d, a scrolling list (84 high, full label), BACK on screen; none of the new boards" % [sel.size() - nn, nn + 1, sel.size()])
	(bk as Button).pressed.emit()
	await _frames(2)
	_check(h.view == Ta90Prototype.View.SELECT and main.visible, "BACK: to the primary screen")
	# A previous challenge opens directly (no lock) and returns to its own list.
	(more as Button).pressed.emit()
	await _frames(1)
	h.open_puzzle(sel[nn])
	await _frames(3)
	var opened: bool = h.page != null and h.page.board_ok and h.view == Ta90Prototype.View.PUZZLE
	h.close_puzzle(true)
	await _frames(2)
	var back_prev: bool = opened and h.view == Ta90Prototype.View.PREVIOUS
	h.open_puzzle(sel[0])
	await _frames(3)
	h.close_puzzle(true)
	await _frames(2)
	_check(back_prev and h.view == Ta90Prototype.View.SELECT and str(h.state.get("current", "")) == "",
		"%s (a previous challenge) opens at once, no lock, and leads back to PREVIOUS CHALLENGES; %s back to the primary screen" % [sel[nn], sel[0]])
	await _close(h)
	_check(not AudioServer.is_bus_mute(mbus), "closing the selection restores the campaign music bus")


func _solve17(b: String) -> void:
	var h := await _hub()
	h.open_puzzle(b)
	await _frames(3)
	var p := h.page
	var k: int = Extreme90P19.selection19().find(b) + 1
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
	_check(bd["format"] == "ce-xb19" and bb["fingerprint"] == Ta90TimeAttack.BOARDS90[b]["fp"] and bb["puzzle"] == k and tm.get("outcome", "") == "COMPLETED"
		and FileAccess.file_exists(Ta90TimeAttack.state_path90(b, ST)), "%s: exported as CHALLENGE %d under its id and fingerprint; stored as xb19_%s" % [b, k, b.to_lower()])
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
		groups_ok = groups_ok and g == Extreme90P19.group19(k) and bd["boards"][k]["fingerprint"] == Ta90TimeAttack.BOARDS90[k]["fp"] and not bd["boards"][k]["mechanics"].is_empty()
	_check(bd["format"] == "ce-xb19" and bd["selection"] == Extreme90P19.SELECTION19 and bd["archived"] == Extreme90P18.ARCHIVED and bd["questionnaire"] == Ta90TimeAttack.SHORT_SET
		and bd["boards"].keys().size() == Extreme90P19.selection19().size() and groups_ok and bd["boards"]["N23"]["group"] == "provisional",
		"export ce-xb19: the selection version (xb19-v2), each board's group (N23 provisional), the archived ids, the questionnaire version")
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
	var p17 := Extreme90Review.new()
	add_child(p17)
	await _frames(3)
	var pb: Dictionary = p17.bundle()
	_check(pb["format"] == "ce-xb17" and pb["selection"] == "xb17-v1" and pb["boards"].keys().size() == 18 and pb["boards"]["N25"]["group"] == "phase17",
		"?extreme90p17=1's export (ce-xb17) unchanged: all 18 Phase 17 boards, N25 / N28 still there")
	await _close(p17)
	var lists_ok := true
	for k in bd["boards"]:
		lists_ok = lists_ok and bd["boards"][k]["list"] == ("new" if Extreme90P19.NEW19.has(k) else "previous") and bd["boards"][k]["puzzle"] == Extreme90P19.selection19().find(k) + 1
	_check(lists_ok and bd["new"] == Extreme90P19.NEW19 and bd["boards"]["N35"]["puzzle"] == 1 and bd["boards"]["N3"]["puzzle"] == Extreme90P19.NEW19.size() + 1,
		"export: every board under its real id with its challenge number and its list (new / previous); the new boards named")


## Phase 18: TIME UP on a Movable / portal board after a push (or a portal
## escape): CONTINUE WITHOUT TIMER starts from that position (Ta90TimeAttack.
## _replayed dispatches it as the play screen does). Every other board keeps
## BlindTimeAttack's replay: N5 (Sequence) unchanged.
func _timeup_position18() -> void:
	var b := ""
	for k in Extreme90P18.NEW18:
		var lv := PuzzleDefinition.from_dict(_rec(k)["puzzle"]).to_level()
		if not lv.portals.is_empty() or lv.blocks.any(func(x): return x.is_crate()):
			b = k
			break
	if b == "":
		_check(true, "no Movable / portal board in the selection (TIME UP position check not needed)")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, ST)))
	var h := await _hub()
	var p := await _start(h, b)
	var sol := _solution(b)
	var cut := 0
	var m := EV6.model_of(PuzzleDefinition.from_dict(_rec(b)["puzzle"]).to_level())
	for i in sol.size():
		var st := m.move_state(int(sol[i]))
		play_move17(m, int(sol[i]))
		if st == "push" or not m.portals.is_empty():
			cut = i + 1
			if st == "push" or i >= 2:
				break
	for i in cut:
		p.play.tap_block(sol[i])
		await _wait(0.05)
	await _wait(0.6)
	p.debug_offset_ms += LIM - p.elapsed_ms()
	await _frames(3)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	p._think_skip.pressed.emit()
	await _frames(2)
	var offer: Dictionary = p.state.get("offer", {})
	_check(p.phase() == "offer" and offer.get("from", "") == "timeout_state" and Array(offer.get("moves", [])).size() == cut and cut > 0,
		"%s: TIME UP after %d moves (a push / a portal lane among them): the untimed offer keeps that position (%s)" % [b, cut, offer.get("from", "")])
	p._untimed_btn.pressed.emit()
	await _frames(4)
	var ref := EV6.model_of(PuzzleDefinition.from_dict(_rec(b)["puzzle"]).to_level())
	for i in cut:
		play_move17(ref, int(sol[i]))
	_check(p.phase() == "untimed" and p.play.model.block_count() == ref.block_count() and p.play.model.snapshot().size() == ref.snapshot().size(),
		"%s: CONTINUE WITHOUT TIMER resumes the TIME UP board (%d blocks left, as at 0:00)" % [b, ref.block_count()])
	await _close(h)
	# Phase 18B: N5 (Sequence): the 90 s page now replays a Sequence advance
	# (BlindTimeAttack's own replay, used by the older pages, is unchanged and
	# still reads it as illegal).
	var hb := await _hub()
	hb.open_puzzle("N5")
	await _frames(3)
	var t: Ta90TimeAttack = hb.page
	var s5 := _solution("N5")
	var fixed := true
	var base_unchanged := true
	var saw_advance := false
	for k in range(0, s5.size() + 1):
		var r5 := EV6.model_of(PuzzleDefinition.from_dict(_rec("N5")["puzzle"]).to_level())
		for i in k:
			saw_advance = saw_advance or r5.move_state(int(s5[i])) == "advance"
			play_move17(r5, int(s5[i]))
		var mine := t._replayed(s5.slice(0, k))
		fixed = fixed and mine != null and Ta90TimeAttack.board_state(mine) == Ta90TimeAttack.board_state(r5)
		base_unchanged = base_unchanged and (_base_replay("N5", s5.slice(0, k)) == (not saw_advance))
	_check(fixed and base_unchanged and saw_advance,
		"N5 (Sequence): every prefix of its line, advances included, replays exactly on the 90 s page; BlindTimeAttack's own replay unchanged")
	await _close(hb)


## An archived board: out of `sel`, still defined, still on an earlier entry.
static func _archived_ok(a: String, sel: Array) -> bool:
	return not sel.has(a) and Ta90TimeAttack.BOARDS90.has(a) and FileAccess.file_exists(Ta90TimeAttack.BOARDS90[a]["data"]) \
		and (Extreme90Bank.BANK.has(a) or Extreme90Review.selection().has(a))


## BlindTimeAttack._replayed as it was (escapes and rams only): replayable?
func _base_replay(b: String, moves: Array) -> bool:
	var level := PuzzleDefinition.from_dict(_rec(b)["puzzle"]).to_level()
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	for id in moves:
		match m.move_state(int(id)):
			"ok":
				m.remove(int(id))
			"ram":
				m.ram(int(id))
			_:
				return false
	return true


static func play_move17(m: BoardModel, id: int) -> void:
	match m.move_state(id):
		"ok":
			m.remove(id)
		"advance":
			m.advance(id)
		"push":
			m.push(id)
		"ram":
			m.ram(id)
