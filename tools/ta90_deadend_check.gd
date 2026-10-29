extends "res://tools/ta90_continue_check.gd"
## PHASE 23 (development only): TIME UP on a position that can no longer be
## cleared - the case the Phase 22 human session met on N49 and N51
## (winnable_at_timeup = false, the untimed continuation STOPPED).
##   godot --headless --path . res://tools/Ta90DeadendCheck.tscn [-- --boards=N49,N51]
## Per board, on the real 90-second page: a timed run that plays a LOSING move
## (moves along the Solver's line first, so the dead end comes mid-game), then
## TIME UP:
##   - the offer resumes the board of 0:00 (never a fresh board), records it as
##     not winnable and says so ("can no longer be cleared: RESTART ...");
##   - an EXHAUSTIVE search (expert_probe.explore, independent of the page's
##     Solver call) confirms the 0:00 position has no winning line;
##   - CONTINUE WITHOUT TIMER shows exactly that board;
##   - RESTART in the untimed game gives the full fresh board, which the
##     exhaustive search confirms solvable; the timed result stays TIME UP;
##   - stopping the untimed game (GIVE UP, confirmed; the STOPPED card, then
##     CONTINUE, as a player leaves it) stores ONE result: timed
##     TIME UP, untimed STOPPED, not completed, winnable_at_timeup false;
##   - a new hub reads the stored state back intact (no corruption).

const EXPERT_P := preload("res://tools/expert_probe.gd")


func _run() -> void:
	AudioManager.unlocked = true
	AudioManager.music_enabled = true
	var only := str(x_args_get("boards", "N49,N51"))
	for b in only.split(","):
		await _deadend(b)
	print("TA90 DEADEND CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


static func _exhaustive_win(m: BoardModel) -> bool:
	var s := Solver.from_model(m)
	var memo: Dictionary = EXPERT_P.explore(s)
	return memo["win"].get(s._key(), false) and not memo["capped"]


func _deadend(b: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ta90TimeAttack.state_path90(b, ST)))
	var h := await _hub()
	var p := await _start(h, b)
	var sol := _solution(b)
	var k := maxi(1, sol.size() / 3)
	for i in k:
		_touch(p, sol[i])
		await _wait(0.05)
	var lm := _losing_move(p.play.model)
	_check(lm >= 0, "%s: a losing move exists after %d moves of the Solver's line" % [b, k])
	if lm < 0:
		await _close(h)
		return
	_touch(p, lm)
	await _wait(0.3)
	var at0 := state_of(p.play.model)
	var fresh := EV6.model_of(PuzzleDefinition.from_dict(_rec(b)["puzzle"]).to_level())
	var dead_exh := not _exhaustive_win(p.play.model)
	p.debug_offset_ms += LIM - p.elapsed_ms()
	await _frames(3)
	_check(p.state.get("timed", {}).get("outcome", "") == "TIME UP", "%s: TIME UP at 90 s" % b)
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(1)
	p._think_skip.pressed.emit()
	await _frames(2)
	var offer: Dictionary = p.state.get("offer", {})
	_check(offer.get("from", "") == "timeout_state" and not offer.get("winnable_at_timeup", true) and dead_exh
		and p._card_text.text.contains("can no longer be cleared"),
		"%s: the 0:00 position is a dead end - recorded winnable_at_timeup = false, confirmed by exhaustive search, said on the card; still the board of 0:00 (from %s, resume %s), never a fresh one" % [b, offer.get("from", ""), offer.get("resume", "")])
	p._untimed_btn.pressed.emit()
	await _frames(4)
	_check(p.phase() == "untimed" and state_of(p.play.model) == at0, "%s: CONTINUE WITHOUT TIMER shows exactly that board (%d blocks)" % [b, at0.size()])
	p.play.restart()
	await _frames(3)
	_check(state_of(p.play.model) == state_of(fresh) and _exhaustive_win(p.play.model) and p.state["timed"]["outcome"] == "TIME UP" and p.phase() == "untimed",
		"%s: RESTART in the untimed game - the full fresh board (%d blocks), solvable by exhaustive search; the timed result stays TIME UP" % [b, state_of(fresh).size()])
	p.give_up()
	p.give_up()
	await _frames(3)
	var stopped_card: bool = p._card.visible and p._card_head.text == "STOPPED"
	(p._card.find_child("TA_Continue", true, false) as Button).pressed.emit()
	await _frames(4)
	var rs: Array = Ta90TimeAttack.read_state90(b, ST).get("results", [])
	var r: Dictionary = rs[-1] if not rs.is_empty() else {}
	var u: Dictionary = r.get("untimed", {})
	_check(stopped_card and rs.size() == 1 and r.get("timed", {}).get("outcome", "") == "TIME UP" and u.get("outcome", "") == "STOPPED" and not u.get("completed", true)
		and u.get("winnable_at_timeup", true) == false and u.get("from", "") == "timeout_state",
		"%s: stopping the untimed game (the STOPPED card, then CONTINUE) stores ONE result - timed TIME UP, untimed STOPPED (not completed), winnable_at_timeup false, from timeout_state" % b)
	await _close(h)
	var h2 := await _hub()
	var back := Ta90TimeAttack.read_state90(b, ST)
	_check(back.get("results", []).size() == 1 and JSON.stringify(back.get("results", [])) == JSON.stringify(rs), "%s: a new page reads the stored record back intact" % b)
	await _close(h2)
