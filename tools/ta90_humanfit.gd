extends "res://tools/ta90_design.gd"
## PHASE 23 (development only): one uniform feature set for every board with
## recorded human results, to study why the technical classification and the
## human difficulty disagree (docs/extreme90_phase23.md, Part I). Diagnostic
## only: it introduces no threshold and rejects nothing.
##   godot --headless --path . --script res://tools/ta90_humanfit.gd -- --file=boards.json --out=features.json
## boards.json: {"N14": {"map": [...]}, ...}
## Per board, along the Solver's line and from the full position graph:
##   distinct / steps / coverage            (category B, as ta90_design.gd)
##   shortcut, look6                        (greedy players, as category B / C)
##   learner4 / learner6                    (trial-and-error dead ends, category C)
##   calm_prefix, safe_share                (moves that can be made first with no risk at all)
##   undo_proof, quick_fail_share           (losing moves that show within 3 moves: UNDO fixes them)
##   trap_delay                             (median moves a losing line survives)
##   deep_traps                             (distinct losing moves whose dead end shows only after >= 4 moves)
##   effective_decisions                    (steps with >= 2 risky legal moves, one of which loses)
##   concurrency                            (steps with >= 2 risky legal moves, share)
##   positions, solution, pieces


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	_load_known()
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var out := {}
	for name in d:
		out[name] = features(Array(d[name]["map"]))
		print("%-5s %s" % [name, JSON.stringify(out[name])])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func features(map: Array) -> Dictionary:
	var level := parse(map)
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	var sol := s.solve_moves()
	var dec := _decisions(s, win, sol)
	var pr := pressure(level, s, memo, sol)
	var best := 0.0
	for k in POLICIES:
		best = maxf(best, PROBE.policy_win(s, k, 120, 31))
	var ex := expert_gates(level, true)
	var eff := 0
	var multi := 0
	var deep := {}
	var quick := 0
	var losing := 0
	for mv in sol:
		var n_risky := 0
		var loses := false
		for o in s._distinct_legal():
			n_risky += int(PROBE.risky(s, o))
			s._do(o)
			if s._alive_count != s._crate_n and not win.get(s._key(), false):
				loses = true
				losing += 1
				var depth: int = EXPERT.longest(s, memo)
				quick += int(depth <= 3)
				s._undo_move(o)
				if depth >= 4:
					deep[_say(s, o)] = true
			else:
				s._undo_move(o)
		multi += int(n_risky >= 2)
		eff += int(n_risky >= 2 and loses)
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	var sl := float(maxi(sol.size(), 1))
	return {"positions": win.size(), "solution": sol.size(), "pieces": _pieces(map),
		"distinct": dec["distinct_mistakes"], "steps": dec["decision_steps"], "coverage": snappedf(dec["decision_steps"] / sl, 0.01),
		"shortcut": snappedf(best, 0.001), "look6": snappedf(PROBE.policy_win(s, "look6", 120, 31), 0.001),
		"learner4": ex["learner"].get("look4", -1), "learner6": ex["learner"].get("look6", -1),
		"calm_prefix": pr["calm_prefix"], "safe_share": snappedf(pr["calm_prefix"] / sl, 0.01),
		"undo_proof": pr["undo_proof"], "quick_fail_share": snappedf(float(quick) / maxf(losing, 1), 0.01),
		"trap_delay": pr["trap_delay_median"], "deep_traps": deep.size(),
		"effective_decisions": eff, "concurrency": snappedf(multi / sl, 0.01)}
