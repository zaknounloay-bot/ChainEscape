extends "res://tools/extreme16_build.gd"
## EXTREME phase 11 (development only; tools/extreme15_lab.gd for the three
## phase-11 recipes, --recipe=A_carry|B_keyturn|C_flipram): the design workbench for hand-drawn
## boards: every reachable position (exhaustive), the winning first moves,
## the solution with how many legal moves win at each step, every losing
## move with how long play goes on after it, the idea facts on EVERY winning
## line (with a winning line that avoids one, in words), the magnets' timing,
## Solver parity, and optionally the expert measures / full acceptance.
##   godot --headless --path . --script res://tools/extreme16_lab.gd -- --recipe=A_carry --file=boards.json [--name=a,b] [--expert] [--full] [--deadends]
## --deadends: every losing move (at the start and along the solution) is
## followed down its LONGEST line to where play stops, and the pieces left
## stranded there are listed (what the mistake really costs, and when).


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
		_lab14(name, Array(d[name]["map"]))
	quit()


func _lab14(name: String, map: Array) -> void:
	print("\n=== %s, %d pieces ===" % [name, _pieces(map)])
	for row in map:
		print("   " + row)
	var level := parse(map)
	if level == null or not _intact(map, level):
		print("   PARSE FAILED")
		return
	cur_recipe = str(x_args.get("recipe", "A_carry"))
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	print("   %d positions, %d winnable%s" % [win.size(), win.values().count(true), " (CAPPED)" if memo["capped"] else ""])
	if not win.get(s._key(), false):
		print("   UNSOLVABLE")
		return
	var p := parity(map)
	print("   solver parity: %d solve / %d hint mismatches%s" % [p["mismatch_solve"], p["mismatch_hint"], (" e.g. " + JSON.stringify(p["examples"][0])) if not p["examples"].is_empty() else ""])
	if p["mismatch_solve"] > 0:
		return
	var sol := s.solve_moves()
	var steps := []
	var traps := []
	for mv in sol:
		var legal := s._distinct_legal()
		var good := 0
		var lose := []
		for o in legal:
			s._do(o)
			var ok: bool = s._alive_count == s._crate_n or win.get(s._key(), false)
			if not ok:
				lose.append("%s+%d" % [_say(s, o), 1 + EXPERT.longest(s, memo)])
			s._undo_move(o)
			good += 1 if ok else 0
		steps.append("%s [%d/%d]" % [_say(s, mv), good, legal.size()])
		traps.append("   step %d %s: losing %s" % [steps.size(), _say(s, mv), ", ".join(lose) if not lose.is_empty() else "-"])
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	print("   solution (%d): %s" % [sol.size(), ", ".join(steps)])
	print("\n".join(traps))
	print("   facts on the solution: " + str(EV16.solution_facts(s)))
	for k in MUST16.get(cur_recipe, []):
		var w := EV16.witness(level, k)
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
	if x_args.has("deadends"):
		_deadends(level, s, memo, sol)
	var hc := _hint_cost(level)
	print("   SHOW A MOVE nodes: along the solution %d, after a mistake %d" % [hc["max_nodes"], hc["dead_max_nodes"]])
	if x_args.has("expert") or x_args.has("full"):
		var m := EXPERT.measure(s)
		print("   expert: opening %s, win share %.3f, decisions K=4/6/8 %s/%s/%s, hidden K=6/8 %s/%s, deepest %d" % [m["opening"], m["win_share"],
			m["decisions"][4], m["decisions"][6], m["decisions"][8], m["hidden"][6], m["hidden"][8], m["deepest"]])
		var ex := expert_gates(level)
		print("   expert gates: %s  learners %s, look6 greedy %s  %s" % [ex["ok"], str(ex["learner"]), str(ex.get("look6_greedy", "-")), ex["why"]])
	if x_args.has("full"):
		var rec := _x_report(cur_recipe, "hand " + name, map)
		print("   ACCEPT %s  %s" % [rec["ok"], rec["why"]])


func _deadends(level: LevelData, s: Solver, memo: Dictionary, sol: Array) -> void:
	var win: Dictionary = memo["win"]
	var m := EVENTS6.model_of(level)
	var seen := {}
	for step in sol.size() + 1:
		for o in s._distinct_legal():
			s._do(o)
			var lost: bool = not (s._alive_count == s._crate_n or win.get(s._key(), false))
			s._undo_move(o)
			if not lost or seen.has(_say(s, o)):
				continue
			seen[_say(s, o)] = true
			# The longest line after the mistake, to where play stops.
			var line := [o]
			var snap := m.snapshot()
			_play_on(m, o)
			s._do(o)
			while true:
				var best := -1
				var best_len := -1
				for mv in s._distinct_legal():
					s._do(mv)
					var l := EXPERT.longest(s, memo)
					s._undo_move(mv)
					if l > best_len:
						best_len = l
						best = mv
				if best < 0:
					break
				line.append(best)
				_play_on(m, best)
				s._do(best)
			var words := []
			for i in line.size():
				words.append("")
			for i in range(line.size() - 1, -1, -1):
				s._undo_move(line[i])
			for i in line.size():
				words[i] = _say(s, line[i])
				s._do(line[i])
			for i in range(line.size() - 1, -1, -1):
				s._undo_move(line[i])
			var left := []
			for b in m.blocks.values():
				left.append("r%dc%d%s%s%s" % [b.cell.y, b.cell.x, b.color.substr(0, 1).to_upper(), "^v<>"[b.direction], "=" if b.armored else ""])
			m.restore(snap)
			print("   after %d solution moves, LOSING %s: the longest line goes on %d more moves (%s), then stops with %s" % [step, words[0], line.size() - 1, ", ".join(words.slice(1)), " ".join(left)])
			# Every place play can stop after this mistake, grouped by what is stranded.
			var ends := {}
			_play_on(m, o)
			s._do(o)
			_ends(s, m, {}, ends)
			s._undo_move(o)
			m.restore(snap)
			var keys := ends.keys()
			keys.sort_custom(func(a, b): return ends[a] > ends[b])
			print("      every dead end: " + "; ".join(keys.map(func(k): return "%s (%d)" % [k, ends[k]])))
		if step < sol.size():
			_play_on(m, sol[step])
			s._do(sol[step])
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])


func _ends(s: Solver, m: BoardModel, seen: Dictionary, ends: Dictionary) -> void:
	if s._alive_count == s._crate_n:
		return
	var key := s._key()
	if seen.has(key):
		return
	seen[key] = true
	var legal := s._distinct_legal()
	if legal.is_empty():
		var left := []
		for b in m.blocks.values():
			left.append("r%dc%d%s%s%s" % [b.cell.y, b.cell.x, b.color.substr(0, 1).to_upper(), "^v<>"[b.direction], "=" if b.armored else ""])
		left.sort()
		var k := " ".join(left)
		ends[k] = int(ends.get(k, 0)) + 1
		return
	for mv in legal:
		var snap := m.snapshot()
		_play_on(m, mv)
		s._do(mv)
		_ends(s, m, seen, ends)
		s._undo_move(mv)
		m.restore(snap)
