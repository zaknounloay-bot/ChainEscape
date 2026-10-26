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
	for a in ["HARD", "4", "5", "2", "YES", "YES", "APPROPRIATE", "YES"]:
		p.think(a)
	await _frames(2)
	p._untimed_btn.pressed.emit()
	await _frames(4)
	_check(p.phase() == "untimed" and p._count.text == "NO TIMER" and p.music.stage == "calm" and _hint_gone(p.play), "%s: CONTINUE WITHOUT TIMER - NO TIMER, the calm mix, still no SHOW A MOVE" % b)
	p.play.restart()
	await _frames(1)
	for mv in _solution(b):
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	_check(p._card_head.text == "SOLVED" and p.state["timed"]["outcome"] == "TIME UP", "%s: solved without the timer; the timed result stays TIME UP" % b)
	await _close(h)
