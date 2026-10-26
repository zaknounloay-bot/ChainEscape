extends "res://tools/ta90_design.gd"
## PHASE 15 (development only): measures advanced campaign levels as DESIGN
## REFERENCES for the 90-second collection (docs/ta90_collection.md). Read
## only: the level files are loaded, never written.
##   godot --headless --path . --script res://tools/ta90_campaign_ref.gd -- --levels=100,200,274,297,300 [--explore]
## Per level: size, pieces, the game's own Solver (solve time, nodes against
## the 60000-node budget), the solution length, decisions along the solution
## (one-ply: steps where a legal move loses - Solver.solve() per move, not
## exhaustive), greedy players; --explore also counts every reachable
## position (capped by tools/expert_probe.gd).


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var out := {}
	for n in str(x_args.get("levels", "100,200,274,297,300")).split(","):
		out[n] = measure_level(int(n))
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func measure_level(n: int) -> Dictionary:
	var level := LevelManager.read_level(n)
	var r := {"level": n, "rows": level.rows, "cols": level.columns, "pieces": level.blocks.size()}
	var worst := 0.0
	var nodes := 0
	var sol: Array = []
	for i in 3:
		var s := Solver.from_model(EVENTS6.model_of(level))
		var t0 := Time.get_ticks_usec()
		sol = s.solve_moves()
		worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
		nodes = s.nodes
	r["solve_ms"] = snappedf(worst, 0.1)
	r["solve_nodes"] = nodes
	r["solution"] = sol.size()
	# One-ply decisions: at each step of the solution, which legal moves lose
	# (a fresh game Solver from the position after the move).
	var s := Solver.from_model(EVENTS6.model_of(level))
	var steps := 0
	var distinct := {}
	var per := []
	var t1 := Time.get_ticks_msec()
	for i in sol.size():
		var lose := 0
		for o in s._distinct_legal():
			s._do(o)
			var ok := s._alive_count == s._crate_n or s.is_solvable()
			s._undo_move(o)
			if not ok:
				lose += 1
				distinct[_say(s, o)] = true
		per.append(lose)
		steps += 1 if lose > 0 else 0
		s._do(sol[i])
	r["decision_steps"] = steps
	r["distinct_mistakes"] = distinct.size()
	r["losing_per_step"] = per
	r["decision_ms"] = Time.get_ticks_msec() - t1
	var pol := {}
	for k in ["safe", "min_turn", "mobility", "look2"]:
		pol[k] = snappedf(PROBE.policy_win(Solver.from_model(EVENTS6.model_of(level)), k, 60, 31), 0.01)
	r["greedy"] = pol
	if x_args.has("explore"):
		var t2 := Time.get_ticks_msec()
		var memo := EXPERT.explore(Solver.from_model(EVENTS6.model_of(level)))
		r["positions"] = memo["win"].size()
		r["capped"] = memo["capped"]
		r["explore_ms"] = Time.get_ticks_msec() - t2
	print("L%d %dx%d, %d pieces: %s" % [n, level.rows, level.columns, level.blocks.size(), JSON.stringify(r)])
	return r
