extends "res://tools/extreme90p18_check.gd"
## PHASE 18B (development only): CONTINUE WITHOUT TIMER resumes the EXACT
## board at TIME UP, on the real 90-second page (docs/extreme90_phase18b.md).
##   godot --headless --path . res://tools/Ta90ContinueCheck.tscn
## For every board of the Phase 18 selection (every mechanic the 90 s mode
## plays: spinners of all four rules, switches / flips, gates, locks, shells
## and rams, magnets, a portal pair, a crate, Sequence blocks):
##   - a timed run: moves along the Solver's line, TIME UP (test clock);
##   - the same with a LOSING move last (the position at 0:00 cannot be
##     cleared any more);
##   - the same after UNDO and a RESTART during the timed run (only the
##     current attempt counts);
##   the board at 0:00 (every field of every block) is captured, SKIP,
##   CONTINUE WITHOUT TIMER, and the board shown is compared field by field.
## Then, on chosen boards: the timed result stays TIME UP; an untimed solve
## is stored apart; RESTART during the untimed game starts fresh and is
## logged; a reload during the untimed game comes back to the same board.

const BOARDS_ALL := ["N3", "N5", "N7", "N11", "N13", "N14", "N15", "N16", "N18", "N21", "N26", "N27", "N29", "N30",
	"N23", "N24", "N31", "N32", "N33", "N34"]
var results := {}


func _run() -> void:
	AudioManager.unlocked = true
	AudioManager.music_enabled = true
	var only := str(x_args_get("boards", ""))
	var boards: Array = BOARDS_ALL if only == "" else Array(only.split(","))
	for b in boards:
		for mode in ["prefix", "dead", "undo_restart", "lost_tap"]:
			await _case(b, mode)
	await _untimed_flows("N33")
	await _untimed_flows("N5")
	await _untimed_flows("N34", true)
	var bad := []
	for k in results:
		if not results[k]["same"]:
			bad.append(k)
	print("CONTINUE SUMMARY: %d cases, %d not resumed exactly: %s" % [results.size(), bad.size(), ", ".join(bad)])
	print("TA90 CONTINUE CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func x_args_get(k: String, d: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + k + "="):
			return a.substr(k.length() + 3)
	return d


## Every gameplay field of every block, sorted by id (JSON-safe).
static func state_of(m: BoardModel) -> Array:
	var out := []
	var ids: Array = m.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = m.blocks[id]
		out.append([b.id, b.cell.x, b.cell.y, b.color, b.direction, b.kind, b.lock_color, b.hidden, b.spin_rule, b.spin_step,
			b.switch_group, b.flip_link, b.gate_group, b.gate_link, b.armored, b.seq_stage, b.seq_next, b.twin, b.magnet])
	return out


## A move that loses from the current position (legal, the board can no
## longer be cleared after it), or -1.
func _losing_move(m: BoardModel) -> int:
	for id in m.blocks.keys():
		var st := m.move_state(id)
		if not ["ok", "advance", "push", "ram"].has(st):
			continue
		var s := Solver.from_model(m)
		var m2 := BoardModel.new()
		m2.setup(m.rows, m.columns, m.snapshot())
		m2.set_portals(m.portal_groups)
		play_move17(m2, id)
		if m2.block_count() > 0 and Solver.from_model(m2).solve().is_empty():
			return id
	return -1


func _case(b: String, mode: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, ST)))
	var h := await _hub()
	var p := await _start(h, b)
	var sol := _solution(b)
	var k := maxi(1, sol.size() * 2 / 5)
	if mode == "undo_restart":
		for i in mini(2, sol.size()):
			p.play.tap_block(sol[i])
			await _wait(0.05)
		p.play.restart()
		await _frames(2)
	for i in k:
		p.play.tap_block(sol[i])
		await _wait(0.05)
	if mode == "undo_restart":
		p.play.undo()
		await _frames(2)
		p.play.tap_block(sol[k - 1])
		await _wait(0.05)
	if mode == "lost_tap":
		# A move the log could not attribute (infer_tap -> -1): the replay
		# fails, the board of 0:00 must come back from the captured state.
		p._current["log"].append([p.elapsed_ms(), "m", -1])
	if mode == "dead":
		var lm := _losing_move(p.play.model)
		if lm < 0:
			await _close(h)
			return
		p.play.tap_block(lm)
		await _wait(0.05)
	await _wait(0.3)
	var at0 := state_of(p.play.model)
	p.debug_offset_ms += LIM - p.elapsed_ms()
	await _frames(3)
	var timed_ok: bool = p.state.get("timed", {}).get("outcome", "") == "TIME UP"
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	p._think_skip.pressed.emit()
	await _frames(2)
	var offer: Dictionary = p.state.get("offer", {})
	p._untimed_btn.pressed.emit()
	await _frames(4)
	var resumed := state_of(p.play.model)
	var same := resumed == at0
	results["%s/%s" % [b, mode]] = {"same": same, "from": offer.get("from", ""), "resume": offer.get("resume", "")}
	if mode == "lost_tap":
		_check(offer.get("resume", "") == "snapshot", "%s lost_tap: the unreplayable log is detected and the captured board restored (resume %s)" % [b, offer.get("resume", "")])
	if mode == "dead":
		_check(offer.get("from", "") == "timeout_state" and not offer.get("winnable_at_timeup", true),
			"%s dead: the position at 0:00 cannot be cleared - still resumed (never a fresh board), recorded as not winnable" % b)
	_check(timed_ok and p.phase() == "untimed" and p.state["timed"]["outcome"] == "TIME UP",
		"%s %s: TIME UP is the timed result; the untimed game starts" % [b, mode])
	_check(same, "%s %s: CONTINUE WITHOUT TIMER shows the exact board of 0:00 (%d blocks; offer from %s)" % [b, mode, at0.size(), offer.get("from", "")])
	if mode == "prefix" and k >= 2:
		# UNDO right after resuming: the last move before TIME UP is taken back.
		var ref := EV6.model_of(PuzzleDefinition.from_dict(_rec(b)["puzzle"]).to_level())
		for i in k - 1:
			play_move17(ref, int(sol[i]))
		p.play.undo()
		await _frames(2)
		_check(state_of(p.play.model) == state_of(ref), "%s prefix: UNDO after CONTINUE WITHOUT TIMER takes back the last move made before TIME UP" % b)
	await _close(h)


## The untimed game: an untimed solve stored apart (timed stays TIME UP);
## RESTART during it starts fresh and is logged; a reload comes back to the
## same board.
func _untimed_flows(b: String, lost_tap: bool = false) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, ST)))
	var h := await _hub()
	var p := await _start(h, b)
	var sol := _solution(b)
	for i in sol.size() / 2:
		p.play.tap_block(sol[i])
		await _wait(0.05)
	await _wait(0.3)
	if lost_tap:
		p._current["log"].append([p.elapsed_ms(), "m", -1])
	p.debug_offset_ms += LIM - p.elapsed_ms()
	await _frames(3)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	p._think_skip.pressed.emit()
	await _frames(2)
	p._untimed_btn.pressed.emit()
	await _frames(4)
	# One more move, then a reload (the page closed and opened again).
	var rest := Solver.from_model(p.play.model).solve_moves().map(func(mv): return mv & Solver.ID_MASK)
	if not rest.is_empty():
		p.play.tap_block(rest[0])
		await _wait(0.3)
	var before := state_of(p.play.model)
	await _close(h)
	h = await _hub()
	await _frames(4)
	p = h.page
	var back := p != null and p.phase() == "untimed" and state_of(p.play.model) == before
	_check(back, "%s: a reload during the untimed game comes back to the same board%s" % [b, " (snapshot-restored start)" if lost_tap else ""])
	if p == null:
		await _close(h)
		return
	# RESTART during the untimed game: a fresh board, logged.
	p.play.restart()
	await _frames(2)
	var fresh := state_of(EV6.model_of(PuzzleDefinition.from_dict(_rec(b)["puzzle"]).to_level()))
	_check(state_of(p.play.model) == fresh and p._current.get("log", []).any(func(e): return e[1] == "r"),
		"%s: RESTART during the untimed game starts a fresh board and is logged" % b)
	# Solve it without the timer.
	for mv in sol:
		p.play.tap_block(mv)
		await _wait(0.03)
	await _wait(1.3)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(4)
	var rs: Array = Ta90TimeAttack.read_state90(b, ST).get("results", [])
	var r: Dictionary = rs[-1] if not rs.is_empty() else {}
	_check(not r.is_empty() and r["timed"]["outcome"] == "TIME UP" and r["untimed"].get("completed", false) and r["untimed"].get("continued", false)
		and r["untimed"].get("from", "") == "timeout_state" and r["untimed"].get("outcome", "") == "COMPLETED WITHOUT TIMER" and int(r["untimed"]["record"].get("restarts", 0)) == 1,
		"%s: solved without the timer - stored apart (untimed COMPLETED WITHOUT TIMER, 1 restart), the timed result still TIME UP" % b)
	var bd: Dictionary = h.bundle()
	var runs: Array = bd["runs"].filter(func(x): return x["board"] == b)
	var last: Dictionary = runs[-1] if not runs.is_empty() else {}
	_check(not last.is_empty() and last["timed_outcome"] == "TIME UP" and not last["timed_success"] and last["untimed_played"] and last["untimed_success"]
		and last["untimed_outcome"] == "COMPLETED WITHOUT TIMER" and last["untimed_restarts"] == 1 and last.get("untimed_from", "") == "timeout_state"
		and last.get("untimed_resume", "") == ("snapshot" if lost_tap else "replay"),
		"%s: export - timed_outcome TIME UP (not a win), untimed played / solved / restarts apart, untimed_from timeout_state, resume %s" % [b, last.get("untimed_resume", "")])
	await _close(h)
