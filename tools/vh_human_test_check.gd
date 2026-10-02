extends Node
## Development VERY HARD human test page (?vhtest=1): end-to-end checks.
##   godot --headless --path . res://tools/VhHumanTestCheck.tscn
## Board set integrity (exact boards, variants, opening statistics), blind
## random order, VERY HARD assistance x1 / x1 (reset by RESTART), solve ->
## rating -> next, give up -> recorded as not solved, resume after a reload,
## results export, and that nothing else is touched (no Classic save, the
## game's SocialPlay defaults unchanged).

const PROGRESS_PATH := "user://vh_test_check_progress.cfg"

var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VhHumanTest.STATE_PATH))
	_run.call_deferred()


func _run() -> void:
	_check_data()
	var t := VhHumanTest.new()
	add_child(t)
	await _frames(3)
	_check(t.total() == 15 and t.screen == VhHumanTest.Screen.INTRO, "15 boards, intro screen")
	var order: Array = t.state["order"]
	var variants := order.map(func(id): return t.boards[id]["variant"])
	_check(variants.count("A") == 6 and variants.count("B") == 6 and variants.count("C") == 3, "order holds every board once (A 6, B 6, C 3)")
	_check(not _visible_text(t).contains("Group") and not _visible_text(t).contains("variant"), "the intro never names a variant")
	# Puzzle 1: assistance x1 / x1, blind labels.
	t.start_next()
	await _frames(2)
	var p := t.play
	_check(p.visible and p._title.text == "PUZZLE 1 / 15" and p._chip.text == "VERY HARD", "puzzle 1: 'PUZZLE 1 / 15', 'VERY HARD' (no variant shown)")
	_check(p.loaded_fingerprint == t.boards[order[0]]["fingerprint"], "puzzle 1 is the exact stored board")
	_check(p._undo.badge_text == "3" and p._hint.badge_text == "1" and p._hammer.badge_text == "1" and p._hammer.modulate.a == 1.0,
		"VERY HARD test assistance: UNDO x3, SHOW A MOVE x1, HAMMER x1")
	p.hint()
	p.hint()
	_check(p.hints_used == 1 and p._message.text.begins_with("No SHOW A MOVE left") and p._hint.badge_text == "0", "SHOW A MOVE x1: a second one is refused")
	p.toggle_hammer()
	var sid := _safe_block(p)
	p.tap_block(sid)
	await _wait(0.4)
	p.toggle_hammer()
	_check(p.hammers_used == 1 and not p.hammer_armed and p._message.text.begins_with("No Hammers left"), "HAMMER x1: a second one is refused")
	p.restart()
	await _frames(2)
	_check(p.hints_used == 0 and p.hammers_used == 0 and p._hint.badge_text == "1" and p._hammer.badge_text == "1" and p.loaded_fingerprint == t.boards[order[0]]["fingerprint"],
		"RESTART: same board, SHOW A MOVE x1 and HAMMER x1 again")
	_check(p.total_hints == 1 and p.total_hammers == 1 and p.plays == 2, "totals for the puzzle survive RESTART (1 SHOW A MOVE, 1 HAMMER, 2 attempts)")
	await _solve(p)
	await _wait(1.3)
	_check(t.screen == VhHumanTest.Screen.RATE and t._rate_title.text.contains("SOLVED") and t._root.visible, "solved -> 'How difficult was this puzzle?'")
	t.rate(3)
	_check(t.screen == VhHumanTest.Screen.THINK, "then the optional first-move question")
	t.think("YES")
	await _frames(2)
	var r: Dictionary = t.state["results"][0]
	_check(r["id"] == order[0] and r["variant"] == t.boards[order[0]]["variant"] and r["completed"] and r["rating"] == "VERY HARD"
		and r["think_first"] == "YES" and r["show_a_move"] == 1 and r["hammer"] == 1 and r["restarts"] == 1 and r["moves"] > 0
		and r["time_ms"] > 0 and r["first_move_ms"] >= 0, "result 1 recorded: variant, time, moves, restarts, undos, SHOW A MOVE, HAMMER, rating, first move (%s)" % str(r))
	_check(t.screen == VhHumanTest.Screen.PLAYING and p._title.text == "PUZZLE 2 / 15" and p.hints_used == 0 and p.hammers_used == 0, "puzzle 2 starts fresh")
	# Puzzle 2: give up (EXIT -> LEAVE).
	p._exit.pressed.emit()
	p._confirm.find_child("Leave", true, false).pressed.emit()
	await _frames(2)
	_check(t.screen == VhHumanTest.Screen.RATE and t._rate_title.text.contains("NOT SOLVED"), "EXIT -> LEAVE: recorded as not solved, still rated")
	t.rate(2)
	t.think("")
	await _frames(2)
	_check(t.state["results"].size() == 2 and not t.state["results"][1]["completed"] and t.state["results"][1]["think_first"] == "", "give-up recorded (optional question skipped)")
	# Reload: same order, resumes at puzzle 3.
	t.play.end()
	t.queue_free()
	await _frames(2)
	var t2 := VhHumanTest.new()
	add_child(t2)
	await _frames(3)
	_check(t2.state["order"] == order and t2.state["index"] == 2 and t2.state["results"].size() == 2 and t2._start.text.begins_with("CONTINUE  3 / 15"),
		"after a reload: same order, CONTINUE 3 / 15, results kept")
	var exported = JSON.parse_string(t2.results_json())
	_check(typeof(exported) == TYPE_DICTIONARY and exported["results"].size() == 2 and exported["summary"].size() >= 1
		and exported["assist"]["show_a_move"] == 1 and exported["assist"]["hammer"] == 1, "COPY RESULTS JSON: results + per-variant summary")
	t2._show(VhHumanTest.Screen.RESULTS)
	await _frames(2)
	_check(t2._copy.is_visible_in_tree() and t2._results_text.text.contains("2 of 15") and not t2._results_text.text.contains("Group"),
		"results mid-test: COPY RESULTS, no group named (still blind)")
	# After the last puzzle: the comparison by group.
	t2.state["index"] = t2.total()
	t2._show(VhHumanTest.Screen.RESULTS)
	_check(t2._results_text.text.contains("Group "), "results after the last puzzle: the comparison by group")
	t2.reset_test()
	_check(t2.state["index"] == 0 and t2.state["results"].is_empty(), "START OVER clears the results")
	# Nothing else touched.
	_check(not FileAccess.file_exists(PROGRESS_PATH), "no Classic save written")
	var fresh := SocialPlay.new()
	_check(fresh.max_hints == 2 and fresh.max_hammers == 2, "the game's SocialPlay keeps SHOW A MOVE x2 / HAMMER x2")
	fresh.free()
	t2.play.end()
	print("VH HUMAN TEST CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## The stored board set: exact, valid, the intended variants and openings.
func _check_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(VhHumanTest.DATA_PATH))
	_check(typeof(data) == TYPE_DICTIONARY and data["boards"].size() == 15, "data/dev/vh_human_test.json: 15 boards")
	if typeof(data) != TYPE_DICTIONARY:
		return
	for b in data["boards"]:
		var def := PuzzleDefinition.from_dict(b["puzzle"])
		var v: String = b["variant"]
		_check(def != null and def.fingerprint() == b["fingerprint"] and def.verify()
			and FriendGenerator.mechanics_ok(def, FriendGenerator.VERY_HARD, v == "C") and not FriendGenerator.is_classic_board(def),
			"%s (%s): exact, Solver-valid, allowed mechanics, not a campaign board" % [b["id"], v])
		if v == "B":
			var m: Dictionary = b["metrics"]
			_check(m["start_moves"] <= 2 and m["start_safe"] == 1 and m["start_calm"] == 0, "%s (B): 1-2 first moves, exactly one safe, none 'calm'" % b["id"])
		if v != "C":
			_check(not def.to_json().contains("#"), "%s (%s): no locks" % [b["id"], v])


func _solve(p: SocialPlay) -> void:
	var guard := 0
	while not p.completed and guard < 200:
		p.play_solver_move()
		await _wait(0.05)
		guard += 1


func _safe_block(p: SocialPlay) -> int:
	var ids := p.model.blocks.keys()
	ids.sort()
	for id in ids:
		if Solver.hammer_safe(p.model, id) and p.model.move_state(id) == "ok":
			return id
	return -1


func _visible_text(root: Node) -> String:
	var out := []
	for n in root.find_children("*", "", true, false):
		if (n is Label or n is Button) and n.is_visible_in_tree():
			out.append(n.text)
	return "\n".join(out)


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
