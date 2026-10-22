extends "res://tools/extreme11_build.gd"
## EXTREME phase 6 (development only): the design workbench. It does not
## search: it reads boards drawn by hand and reports every reachable position
## (exhaustive), which first moves keep the board solvable, the solution step
## by step with how many legal moves win (and which losing moves are magnet
## escapes), the idea facts on EVERY winning line - with a winning line that
## avoids a fact, in words - the timing of every magnet, the slowest SHOW A
## MOVE after a mistake, and optionally the expert measures / acceptance.
##   godot --headless --path . --script res://tools/extreme11_lab.gd -- --file=boards.json [--name=a,b] [--expert] [--full]
## boards.json: {"name": {"recipe": "C1_cross", "map": [row, ...]}, ...}


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
		_lab11(name, d[name].get("recipe", "C1_cross"), Array(d[name]["map"]))
	quit()


func _lab11(name: String, recipe: String, map: Array) -> void:
	print("\n=== %s (%s) %d pieces ===" % [name, recipe, _pieces(map)])
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
	var worst_hint := 0.0
	var pm := model_of(level)
	var trap_lines := []
	for mv in sol:
		var legal := s._distinct_legal()
		var good := 0
		var traps := []
		for o in legal:
			s._do(o)
			var ok: bool = s._alive_count == s._crate_n or win.get(s._key(), false)
			if not ok:
				var snap := pm.snapshot()
				_play(pm, o)
				var t0 := Time.get_ticks_usec()
				var hint := Solver.from_model(pm).recommend_move()
				worst_hint = maxf(worst_hint, (Time.get_ticks_usec() - t0) / 1000.0)
				if hint != -1:
					print("   PARITY? solver says lost, SHOW A MOVE found %d" % hint)
				pm.restore(snap)
			s._undo_move(o)
			if ok:
				good += 1
			elif (o & (Solver.RAM | Solver.PUSH)) == 0 and s._magnet[o & Solver.ID_MASK] == 1:
				traps.append("M")
		steps.append("%s [%d/%d%s]" % [_say(s, mv), good, legal.size(), (" " + "".join(traps)) if not traps.is_empty() else ""])
		# Every losing move here with how long play can go on after it.
		var lose := []
		for o in legal:
			s._do(o)
			if s._alive_count != s._crate_n and not win.get(s._key(), false):
				lose.append("%s+%d" % [_say(s, o), 1 + EXPERT.longest(s, memo)])
			s._undo_move(o)
		trap_lines.append("   step %d %s: losing %s" % [steps.size(), _say(s, mv), ", ".join(lose) if not lose.is_empty() else "-"])
		_play(pm, mv)
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	print("   solution (%d): %s" % [sol.size(), ", ".join(steps)])
	if x_args.has("traps"):
		print("\n".join(trap_lines))
	print("   facts on the solution: " + str(EV11.solution_facts(s)))
	for k in MUST11.get(recipe, []):
		var w := EV11.witness(level, k)
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
	var t := EV11.timing(s, win)
	var per := []
	for id in t["per"]:
		var cell: int = s._cell[id]
		per.append("r%dc%d %d win / %d lose" % [cell / s.columns, cell % s.columns, t["per"][id][0], t["per"][id][1]])
	print("   magnet timing: %s -> %d timing magnets" % [", ".join(per), t["timing_magnets"].size()])
	print("   slowest SHOW A MOVE after a mistake on the solution: %.1f ms (native, lab)" % worst_hint)
	if x_args.has("expert") or x_args.has("full"):
		var m := EXPERT.measure(s)
		print("   expert: opening %s, win share %.3f, decisions K=4/6/8 %s/%s/%s, hidden K=6/8 %s/%s, deepest %d" % [m["opening"], m["win_share"],
			m["decisions"][4], m["decisions"][6], m["decisions"][8], m["hidden"][6], m["hidden"][8], m["deepest"]])
		var ex := expert_gates(level)
		print("   expert gates: %s  learners %s, look6 greedy %s  %s" % [ex["ok"], str(ex["learner"]), str(ex.get("look6_greedy", "-")), ex["why"]])
	if x_args.has("full"):
		var rec := _x_report(recipe, "hand " + name, map)
		print("   ACCEPT %s  %s" % [rec["ok"], rec["why"]])
		if rec.has("x"):
			var x: Dictionary = rec["x"]
			print("   best rule %.1f, greedy %.3f, late %d, time %s" % [x["best_rule_dead_ends"], x["greedy_best"], x["late_misleading_moves"], str(x.get("time_runs_ms", []))])
	cur_recipe = ""



func _play(m: BoardModel, mv: int) -> void:
	var id := mv & Solver.ID_MASK
	match m.move_state(id):
		"ok":
			m.remove(id)
		"ram":
			m.ram(id)
		"push":
			m.push(id)
		"advance":
			m.advance(id)
