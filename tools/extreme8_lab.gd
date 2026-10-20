extends "res://tools/extreme8_build.gd"
## EXTREME expert experiment (development only): the design workbench. It
## does not search: it reads boards drawn by hand and reports every reachable
## position (exhaustive), which first moves keep the board solvable, the
## solution step by step with how many legal moves win, the idea facts on
## EVERY winning line - with a winning line that avoids a fact, in words, so
## the designer can close the loophole - and optionally the expert measures.
##   godot --headless --path . --script res://tools/extreme8_lab.gd -- --file=boards.json [--name=a,b] [--expert] [--full]
## boards.json: {"name": {"recipe": "X2_cascade", "map": [row, ...]}, ...}

const STATE_CAP := 400000


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	if x_args.has("full"):
		_load_known()
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	for name in d:
		if x_args.has("name") and not str(x_args["name"]).split(",").has(name):
			continue
		_lab8(name, d[name]["recipe"], Array(d[name]["map"]))
	quit()


func _lab8(name: String, recipe: String, map: Array) -> void:
	print("\n=== %s (%s) ===" % [name, recipe])
	for row in map:
		print("   " + row)
	var level := parse(map)
	if level == null or not _intact(map, level):
		print("   PARSE FAILED")
		return
	cur_recipe = recipe
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	print("   %d positions, %d winnable%s" % [win.size(), win.values().count(true), " (CAPPED)" if memo["capped"] else ""])
	if not win.get(s._key(), false):
		print("   UNSOLVABLE")
		cur_recipe = ""
		return
	var firsts := []
	for mv in s._distinct_legal():
		s._do(mv)
		firsts.append("%s%s" % [_say(s, mv), "" if s._alive_count == s._crate_n or win.get(s._key(), false) else " X"])
		s._undo_move(mv)
	print("   first moves: " + ", ".join(firsts))
	var sol := s.solve_moves()
	var steps := []
	for mv in sol:
		var legal := s._distinct_legal()
		var good := 0
		for o in legal:
			s._do(o)
			if s._alive_count == s._crate_n or win.get(s._key(), false):
				good += 1
			s._undo_move(o)
		steps.append("%s [%d/%d]" % [_say(s, mv), good, legal.size()])
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	print("   solution (%d): %s" % [sol.size(), ", ".join(steps)])
	print("   facts on the solution: " + str(EV8.solution_facts(s)))
	for k in MUST8.get(recipe, []):
		var w := EV8.witness(level, k)
		if w.is_empty():
			print("   EVERY winning line: %s" % k)
		else:
			var words := []
			for mv in w:
				words.append(_say(s, mv))
				s._do(mv)
			for i in range(w.size() - 1, -1, -1):
				s._undo_move(w[i])
			print("   NOT %s on: %s" % [k, ", ".join(words)])
	if x_args.has("expert") or x_args.has("full"):
		var m := EXPERT.measure(s)
		print("   expert: opening %s, win share %.3f, decisions K=6/8 %s/%s, hidden K=6/8 %s/%s, deepest %d" % [m["opening"], m["win_share"],
			m["decisions"][6], m["decisions"][8], m["hidden"][6], m["hidden"][8], m["deepest"]])
		var ex := expert_gates(level)
		print("   expert gates: %s  learners %s, look6 greedy %s  %s" % [ex["ok"], str(ex["learner"]), str(ex.get("look6_greedy", "-")), ex["why"]])
	if x_args.has("full"):
		var rec := _x_report(recipe, "hand " + name, map)
		print("   ACCEPT %s  %s" % [rec["ok"], rec["why"]])
		if rec.has("x"):
			var x: Dictionary = rec["x"]
			print("   best rule %.1f, greedy %.3f, late %d, time %s" % [x["best_rule_dead_ends"], x["greedy_best"], x["late_misleading_moves"], str(x.get("time_runs_ms", []))])
	cur_recipe = ""
