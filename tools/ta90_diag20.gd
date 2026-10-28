extends "res://tools/ta90_design.gd"
## PHASE 20 (development only): why do non-spinner searches stall? A
## diagnostic over finished boards (docs/extreme90_phase20.md, Part A). Per board:
##   the win rate of EACH one-attempt greedy policy (which one is the shortcut);
##   along the Solver's line: how many RISKY moves (a move that changes another
##   block - Solver._is_risky + magnet zones) are legal at once, the share of
##   steps with >= 2 of them (an order among risky moves to get wrong);
##   the losing moves split by what they are (a risky move vs a plain removal),
##   and the distinct mistakes counted by cell + arrow (ta90_design.gd's
##   label) vs by block (one block = one mistake).
##   godot --headless --path . --script res://tools/ta90_diag20.gd -- --file=boards.json --out=diag.json
## boards.json: {"name": {"map": [...], "mechanic": "switch,gate"}}


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
		out[name] = diag(Array(d[name]["map"]))
		print("%-10s %s" % [name, JSON.stringify(out[name])])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func diag(map: Array) -> Dictionary:
	var level := parse(map)
	if level == null:
		return {"error": "does not parse"}
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	if not win.get(s._key(), false):
		return {"error": "unsolvable"}
	var sol := s.solve_moves()
	var pol := {}
	for k in POLICIES:
		pol[k] = PROBE.policy_win(s, k, 60, 31)
	var risky_avail := []
	var lose_risky := 0
	var lose_calm := 0
	var by_label := {}
	var by_block := {}
	for i in sol.size():
		var n_risky := 0
		for o in s._distinct_legal():
			var r := PROBE.risky(s, o)
			n_risky += int(r)
			s._do(o)
			var ok: bool = s._alive_count == s._crate_n or win.get(s._key(), false)
			s._undo_move(o)
			if not ok:
				by_label[_say(s, o)] = true
				by_block[o & Solver.ID_MASK] = true
				if r:
					lose_risky += 1
				else:
					lose_calm += 1
		risky_avail.append(n_risky)
		s._do(sol[i])
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	var multi := risky_avail.filter(func(x): return x >= 2).size()
	return {"positions": win.size(), "solution": sol.size(), "greedy": pol, "risky_per_step": risky_avail,
		"multi_risky_share": snappedf(float(multi) / maxf(sol.size(), 1), 0.01), "losing_risky": lose_risky, "losing_calm": lose_calm,
		"distinct_label": by_label.size(), "distinct_block": by_block.size()}
