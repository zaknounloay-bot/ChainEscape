extends "res://tools/extreme7_build.gd"
## EXTREME DESIGN EXPERIMENT (development only): the design workbench for
## hand-made boards. It does not search: it reads a board drawn by hand and
## reports what a designer needs to judge it - every reachable position
## (exhaustive), which first moves keep it solvable, where along the solution
## the player has a real choice (several legal moves, few of them winning),
## the solution traced in plain words, and the central idea's events.
##   godot --headless --path . --script res://tools/extreme7_lab.gd -- --file=boards.json [--name=A3] [--full]
## boards.json: {"A3": {"recipe": "A_remote", "map": [row, ...]}, ...}
## --full also runs the complete acceptance report (_x_report, slow).

const STATE_CAP := 400000


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	if x_args.has("full"):
		_load_known()
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	for name in d:
		if x_args.has("name") and not str(x_args["name"]).split(",").has(name):
			continue
		_lab(name, d[name]["recipe"], Array(d[name]["map"]))
	quit()


func _lab(name: String, recipe: String, map: Array) -> void:
	print("\n=== %s (%s) ===" % [name, recipe])
	for row in map:
		print("   " + row)
	var level := parse(map)
	if level == null or not _intact(map, level):
		print("   PARSE FAILED")
		return
	var s := _solver(level)
	var win := {}
	var t0 := Time.get_ticks_msec()
	var ok := _winnable(s, win)
	print("   solvable %s, %d positions (%d winnable), %d ms" % [ok, win.size(), win.values().count(true), Time.get_ticks_msec() - t0])
	if not ok or win.size() >= STATE_CAP:
		return
	var firsts := []
	for mv in s._distinct_legal():
		s._do(mv)
		firsts.append("%s%s" % [_say(s, mv), "" if win.get(s._key(), false) else " X"])
		s._undo_move(mv)
	print("   first moves: " + ", ".join(firsts))
	# The solver's solution, step by step: legal / winning moves at each step.
	var sol := s.solve_moves()
	var steps := []
	var narrow := 0
	for mv in sol:
		var legal := s._distinct_legal()
		var good := 0
		for o in legal:
			s._do(o)
			if win.get(s._key(), false) or s._alive_count == s._crate_n:
				good += 1
			s._undo_move(o)
		if legal.size() >= 2 and good * 2 <= legal.size():
			narrow += 1
		steps.append("%s [%d/%d]" % [_say(s, mv), good, legal.size()])
		s._do(mv)
	for i in sol.size():
		s._undo_move(sol[sol.size() - 1 - i])
	print("   solution %d taps, %d narrow steps (at most half the legal moves win):" % [sol.size(), narrow])
	for i in steps.size():
		print("     %2d. %s" % [i + 1, steps[i]])
	print("   idea events: " + str(solution_events(level)))
	var spec: Dictionary = recipes()[recipe]
	print("   idea check: " + str(idea_check(level, spec)))
	print("   every winning line: " + str(EV7.must_facts(level, recipe)))
	if x_args.has("full"):
		var rec := _x_report(recipe, "hand " + name, map)
		print("   ACCEPT %s  %s" % [rec["ok"], rec["why"]])
		if rec.has("x"):
			var x: Dictionary = rec["x"]
			print("   best rule dead ends %.1f, greedy best %.3f, late misleading %d, blind %s" % [x["best_rule_dead_ends"], x["greedy_best"], x["late_misleading_moves"], str(x["blind"])])
			print("   policies " + str(x["policies"]))
			print("   time runs " + str(x.get("time_runs_ms", [])))
		if rec.has("metrics"):
			var m: Dictionary = rec["metrics"]
			print("   verify nodes %s, hint %s" % [str(rec.get("verify", {})), str(rec.get("hint", {}))])
			print("   impacts sw %.1f gate %.1f armor %.1f spinner %s" % [m.get("switch_impact", 0), m.get("gate_impact", 0), m.get("armor_impact", 0), str(rec.get("rules_impact", "?"))])


## Every reachable position: winnable or not (memoised on the solver key).
func _winnable(s: Solver, win: Dictionary) -> bool:
	if s._alive_count == s._crate_n:
		return true
	var key := s._key()
	if win.has(key):
		return win[key]
	if win.size() >= STATE_CAP:
		return false
	win[key] = false
	var any := false
	for mv in s._distinct_legal():
		s._do(mv)
		var w := _winnable(s, win)
		s._undo_move(mv)
		any = any or w
	win[key] = any
	return any
