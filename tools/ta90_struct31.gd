extends "res://tools/ta90_humanlike26.gd"
## PHASE 31 (development only): structural play analysis of rated boards
## (docs/extreme90_phase31.md, section D). Measures only - no gate, no rank.
##   godot --headless --path . --script res://tools/ta90_struct31.gd -- --file=boards.json [--out=struct.json]
## boards.json: {"N52": {"map": [...]}, ...}
## Per board, from the full position graph (the exact Solver, unchanged):
##   positions / winning        reachable positions / of them still winnable
##   open_moves / open_safe     legal moves at the start / of them still winnable
##   open_escape_losing         opening moves that let a block escape AND lose (a tempting first move)
##   first_choice               first solution step with both a winning and a losing legal move
##   forced / optional          solution steps with exactly 1 winning move / with >= 2
##   mean_winning               mean number of winning moves per solution step (route slack)
##   mistakes                   distinct losing moves met along the solution line
##   tempting                   of them, the ones that let a block escape (visible progress, still fatal)
##   trap_depth_median          median longest play still possible after a mistake (how long it hides)
##   beyond_undo                share of mistakes whose dead end can stay hidden for >= 4 moves
##                              (Undo 3 cannot reach back past them)
##   instant_dead               share of mistakes that leave no legal move at all at once
##   repeat_taps                solution moves on a block already moved earlier in the line
##   escape_order_free          solution steps where >= 2 different blocks can escape and still win
## Crate boards (Movable) can cycle: trap depth there uses EXPERT.longest's cycle guard.


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var out := {}
	for name in d:
		out[name] = structure(Array(d[name]["map"]))
		print("%-8s %s" % [name, JSON.stringify(out[name])])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func _ok(s: Solver, win: Dictionary) -> bool:
	return s._alive_count == s._crate_n or win.get(s._key(), false)


func structure(map: Array) -> Dictionary:
	var level := parse(map)
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	var r := {"positions": win.size(), "winning": win.values().count(true), "capped": memo["capped"]}
	var open := s._distinct_legal()
	var safe := 0
	var esc_lose := 0
	for mv in open:
		var before := s._alive_count
		s._do(mv)
		var ok := _ok(s, win)
		safe += int(ok)
		esc_lose += int(not ok and s._alive_count < before)
		s._undo_move(mv)
	r.merge({"open_moves": open.size(), "open_safe": safe, "open_escape_losing": esc_lose})
	var sol := s.solve_moves()
	var first_choice := 0
	var forced := 0
	var optional := 0
	var wsum := 0
	var mistakes := {}
	var tempting := {}
	var depths := []
	var dead := 0
	var moved := {}
	var repeats := 0
	var order_free := 0
	for i in sol.size():
		var winning := 0
		var losing := 0
		var esc_ids := {}
		for o in s._distinct_legal():
			var before := s._alive_count
			var name := _say(s, o)
			s._do(o)
			var ok := _ok(s, win)
			if ok:
				winning += 1
				if s._alive_count < before:
					esc_ids[o & Solver.ID_MASK] = true
			else:
				losing += 1
				if not mistakes.has(name):
					mistakes[name] = true
					var l := EXPERT.longest(s, memo)
					depths.append(l)
					dead += int(l == 0)
					if s._alive_count < before:
						tempting[name] = true
			s._undo_move(o)
		if first_choice == 0 and winning >= 1 and losing >= 1:
			first_choice = i + 1
		forced += int(winning == 1)
		optional += int(winning >= 2)
		wsum += winning
		order_free += int(esc_ids.size() >= 2)
		var id: int = sol[i] & Solver.ID_MASK
		repeats += int(moved.has(id))
		moved[id] = true
		s._do(sol[i])
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	depths.sort()
	var deep := depths.filter(func(x): return x >= 4).size()
	r.merge({"solution": sol.size(), "first_choice": first_choice, "forced": forced, "optional": optional,
		"mean_winning": snappedf(float(wsum) / maxf(sol.size(), 1), 0.01),
		"mistakes": mistakes.size(), "tempting": tempting.size(),
		"tempting_share": snappedf(float(tempting.size()) / maxf(mistakes.size(), 1), 0.01),
		"trap_depth_median": depths[depths.size() / 2] if not depths.is_empty() else 0,
		"beyond_undo": snappedf(float(deep) / maxf(depths.size(), 1), 0.01),
		"instant_dead": snappedf(float(dead) / maxf(depths.size(), 1), 0.01),
		"repeat_taps": repeats, "escape_order_free": order_free})
	return r
