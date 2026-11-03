extends "res://tools/ta90_struct31.gd"
## PHASE 33 (development only): strategic-structure measures for the
## historical approved-vs-rejected study (docs/extreme90_phase33.md, B).
## Measures only - no gate, no rank, no rejection. The exact Solver is unchanged.
##   godot --headless --path . --script res://tools/ta90_struct33.gd -- --file=boards.json [--out=struct.json] [--name=N1,N2]
## boards.json: {"N52": {"map": [...]}, ...}
## Everything of ta90_struct31.gd, plus, along the Solver's solution line:
##   lps                    losing legal moves at each solution step
##   early3                 sum of lps over the first three steps
##   delayed                losing moves whose dead end is NOT forced within 3 moves
##                          (some line of >= 4 further moves exists: Undo 3 cannot reach back)
##   loud                   losing moves forced dead within 3 moves (the board punishes quickly)
##   strat_steps            steps with >= 1 delayed losing alternative (a consequential decision)
##   strat_tempting_steps   of them, steps where a delayed losing alternative lets a block escape
##                          (the wrong move looks like progress)
##   apparent_steps         steps with >= 2 legal moves and no delayed losing alternative
##                          (the choice is free, or a mistake is punished at once)
##   first_strat            first step that is a strat step (0 = none)
##   late_strat_share       strat steps in the second half of the line / strat steps
##   early3_loud / early3_delayed   loud / delayed losing moves in the first three steps
##   max_forced_run         longest run of consecutive steps with exactly one winning move
## Plus, from ta90_humanlike26.gd (simple-player performance, exact where crate-free):
##   p_random, p_look1, p_look2, p_calm, dep_depth, dep_pairs, win_lines


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	_load_known()
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var out := {}
	for name in d:
		if x_args.has("name") and not str(x_args["name"]).split(",").has(name):
			continue
		var t0 := Time.get_ticks_msec()
		var map := Array(d[name]["map"])
		var r := structure(map)
		r.merge(strategic(map))
		var h := humanlike(map)
		for k in ["p_random", "p_look1", "p_look2", "p_calm", "dep_depth", "dep_pairs", "win_lines"]:
			if h.has(k):
				r[k] = h[k]
		r["ms"] = Time.get_ticks_msec() - t0
		out[name] = r
		print("%-8s %s" % [name, JSON.stringify(r)])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func strategic(map: Array) -> Dictionary:
	var level := parse(map)
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	var sol := s.solve_moves()
	var lps := []
	var delayed := 0
	var loud := 0
	var strat := 0
	var strat_t := 0
	var apparent := 0
	var first_strat := 0
	var late := 0
	var e_loud := 0
	var e_del := 0
	var run := 0
	var max_run := 0
	for i in sol.size():
		var legal := s._distinct_legal()
		var losing := 0
		var winning := 0
		var has_del := false
		var has_del_t := false
		for o in legal:
			var before := s._alive_count
			s._do(o)
			if _ok(s, win):
				winning += 1
			else:
				losing += 1
				var hidden := not s._dead_within(3)
				if hidden:
					delayed += 1
					has_del = true
					has_del_t = has_del_t or s._alive_count < before
					e_del += int(i < 3)
				else:
					loud += 1
					e_loud += int(i < 3)
			s._undo_move(o)
		lps.append(losing)
		if has_del:
			strat += 1
			strat_t += int(has_del_t)
			late += int(i >= sol.size() / 2)
			if first_strat == 0:
				first_strat = i + 1
		elif legal.size() >= 2:
			apparent += 1
		run = run + 1 if winning == 1 else 0
		max_run = maxi(max_run, run)
		s._do(sol[i])
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	var e3 := 0
	for i in mini(3, lps.size()):
		e3 += int(lps[i])
	return {"lps": lps, "early3": e3, "delayed": delayed, "loud": loud,
		"strat_steps": strat, "strat_tempting_steps": strat_t, "apparent_steps": apparent,
		"first_strat": first_strat,
		"late_strat_share": snappedf(float(late) / maxf(strat, 1), 0.01),
		"early3_loud": e_loud, "early3_delayed": e_del, "max_forced_run": max_run}
