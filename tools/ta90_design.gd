extends "res://tools/extreme17_build.gd"
## PHASE 14 (development only): the design report for 90-second boards
## (docs/ta90_design.md). Every board is measured in three SEPARATE
## categories:
##   A  HARD TECHNICAL (mandatory, never weakened): the map parses intact; a
##      well-formed puzzle (PuzzleDefinition, fingerprint, verify); solvable;
##      the Solver agrees with exhaustive search in EVERY reachable position
##      (solve and hint); the Solver's solution replays to an empty board
##      through BoardModel, twice, identically (deterministic); <= 700
##      positions; solve time on desktop <= 40 ms (5 runs); the TIME UP check
##      (the only Solver call during a 90 s run) <= 40 ms from EVERY reachable
##      position; SHOW A MOVE work reported (the 90 s mode has no SHOW A MOVE).
##   B  STRATEGIC QUALITY (the board's own design checks): the intended idea
##      holds on EVERY winning line (exhaustive facts); the mechanic is NOT
##      decoration (neutralising it makes the board unsolvable or changes its
##      decisions); DECISION steps on the solution - steps where a legal move
##      loses -, counted as DISTINCT mistakes (one mistake repeated step after
##      step counts once); a decision in the last third (endgame); no trivial
##      shortcut (no simple greedy player wins more than 20 %).
##   C  DIFFICULTY ESTIMATES (diagnostic only, never a rejection by itself):
##      greedy players, 6-move lookahead greedy, expert learners, decisions
##      lookahead cannot settle, hidden losing moves, deepest trap, positions.
## Verdict: A fails -> REJECTED; A holds and B holds for the target ->
## HUMAN-REVIEW CANDIDATE (never "approved": people decide); else NEEDS WORK
## (with the reasons).
##   godot --headless --path . --script res://tools/ta90_design.gd -- --file=boards.json [--name=a,b] [--quick]
## boards.json: {"name": {"map": [...], "target": "MEDIUM|HARD|VERY HARD", "facts": ["..."], "mechanic": "switch,gate"}}
## mechanic: a comma list of switch | gate | lock | armor | magnet | alt; each must matter.
## --quick: skip the learners (category C) and parity (category A is then
## marked incomplete).

const SHORTCUT_MAX := 0.20
## Distinct decisions (and an endgame decision) each target asks for.
const NEED := {"MEDIUM": {"distinct": 2, "steps": 3, "endgame": false},
	"HARD": {"distinct": 3, "steps": 4, "endgame": true},
	"VERY HARD": {"distinct": 4, "steps": 5, "endgame": true}}


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
		if x_args.has("name") and not str(x_args["name"]).split(",").has(name):
			continue
		out[name] = report(name, d[name])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func report(name: String, spec: Dictionary) -> Dictionary:
	var map: Array = Array(spec["map"])
	var target: String = spec.get("target", "MEDIUM")
	var quick := x_args.has("quick")
	cur_recipe = "P5_gate"  # the shared phase-13 tools; the facts below are the board's own
	print("\n=== %s (target %s, %d pieces) ===" % [name, target, _pieces(map)])
	for row in map:
		print("   " + row)
	var r := {"name": name, "target": target, "map": map, "A": {}, "B": {}, "C": {}, "why_a": [], "why_b": []}
	# --- A: hard technical --------------------------------------------------------------
	var level := parse(map)
	if level == null or not _intact(map, level):
		r["why_a"].append("the map does not parse intact")
		return _verdict(r)
	var def := PuzzleDefinition.from_dict({"format": PuzzleDefinition.FORMAT, "v": PuzzleDefinition.VERSION, "rules": PuzzleDefinition.RULES,
		"rows": map.size(), "cols": str(map[0]).split(" ", false).size(), "map": map})
	if def == null or not def.verify():
		r["why_a"].append("not a well-formed, verifiable puzzle")
		return _verdict(r)
	r["A"]["fingerprint"] = def.fingerprint()
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	r["A"]["positions"] = win.size()
	r["A"]["winnable"] = win.values().count(true)
	if memo["capped"] or win.size() > MAX_POSITIONS:
		r["why_a"].append("%d positions (> %d)" % [win.size(), MAX_POSITIONS])
	if not win.get(s._key(), false):
		r["why_a"].append("unsolvable")
		return _verdict(r)
	if not quick:
		var p := parity(map)
		r["A"]["parity"] = [p["mismatch_solve"], p["mismatch_hint"]]
		if p["mismatch_solve"] > 0 or p["mismatch_hint"] > 0:
			r["why_a"].append("Solver / exhaustive disagree in %d / %d positions" % [p["mismatch_solve"], p["mismatch_hint"]])
	var sol := s.solve_moves()
	r["A"]["solution"] = sol.size()
	var rp1 := _replay(level, sol)
	var rp2 := _replay(level, sol)
	r["A"]["replay"] = rp1 == rp2 and rp1 == "empty"
	if not r["A"]["replay"]:
		r["why_a"].append("the solution does not replay deterministically to an empty board (%s / %s)" % [rp1, rp2])
	var worst := 0.0
	for i in 5:
		var t0 := Time.get_ticks_usec()
		var s2 := _solver(parse(map))
		s2.solve_moves()
		worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
	r["A"]["solve_ms"] = snappedf(worst, 0.1)
	if worst > 40.0:
		r["why_a"].append("solve %.1f ms (> 40)" % worst)
	var hc := _hint_cost(level)
	r["A"]["hint_nodes"] = [hc["max_nodes"], hc["dead_max_nodes"]]
	# The only Solver call while a 90 s run is played: at TIME UP, from the
	# board at 0:00 (can it still be cleared?). Worst over EVERY reachable position.
	var tu := _timeup_cost(level, s)
	r["A"]["timeup_worst_ms"] = tu["ms"]
	r["A"]["timeup_worst_nodes"] = tu["nodes"]
	if tu["ms"] > 40.0:
		r["why_a"].append("the TIME UP check takes %.1f ms in its worst position (> 40)" % tu["ms"])
	# --- B: strategic quality -----------------------------------------------------------------
	for k in spec.get("facts", []):
		var w := EV17.witness(level, k)
		r["B"]["idea_" + k] = w.is_empty()
		if not w.is_empty():
			r["why_b"].append("a winning line without %s: %s" % [k, ", ".join(w.map(func(mv): return _say(s, mv)))])
	var dec := _decisions(s, win, sol)
	r["B"].merge(dec)
	var need: Dictionary = NEED.get(target, NEED["MEDIUM"])
	if dec["distinct_mistakes"] < need["distinct"]:
		r["why_b"].append("%d distinct mistakes on the solution (< %d)" % [dec["distinct_mistakes"], need["distinct"]])
	if dec["decision_steps"] < need["steps"]:
		r["why_b"].append("%d decision steps (< %d)" % [dec["decision_steps"], need["steps"]])
	if need["endgame"] and not dec["endgame_decision"]:
		r["why_b"].append("no decision in the last third")
	for mech in str(spec.get("mechanic", "")).split(",", false):
		var cf := _counterfactual(map, mech, dec)
		r["B"]["matters_" + mech] = cf["matters"]
		r["B"]["without_" + mech] = cf["what"]
		if not cf["matters"]:
			r["why_b"].append("the %s is decoration: %s" % [mech, cf["what"]])
	var pol := {}
	var best := 0.0
	for k in POLICIES:
		var g := PROBE.policy_win(s, k, 200 if k != "look4" else 120, 31)
		pol[k] = snappedf(g, 0.001)
		best = maxf(best, g)
	r["C"]["greedy"] = pol
	r["B"]["shortcut"] = snappedf(best, 0.001)
	if best > SHORTCUT_MAX:
		r["why_b"].append("a simple greedy player wins %.0f%% (> %.0f%%): a shortcut" % [best * 100.0, SHORTCUT_MAX * 100.0])
	var near := near_copy_of(map)
	if near != "":
		r["why_b"].append("a variant of " + near)
	# --- C: estimates (diagnostic) ------------------------------------------------------------
	var m := EXPERT.measure(s)
	r["C"]["decisions_k4_6_8"] = [m["decisions"][4], m["decisions"][6], m["decisions"][8]]
	r["C"]["hidden_k6_8"] = [m["hidden"][6], m["hidden"][8]]
	r["C"]["deepest"] = m["deepest"]
	r["C"]["opening"] = m["opening"]
	r["C"]["win_share"] = snappedf(m["win_share"], 0.001)
	r["C"]["look6_greedy"] = snappedf(PROBE.policy_win(s, "look6", 120, 31), 0.001)
	if not quick:
		var ex := expert_gates(level, true)
		r["C"]["learner"] = ex["learner"]
	print("   solution: %s" % ", ".join(dec["line"]))
	return _verdict(r)


func _verdict(r: Dictionary) -> Dictionary:
	if not r["why_a"].is_empty():
		r["verdict"] = "REJECTED"
	elif r["why_b"].is_empty() and not x_args.has("quick"):
		r["verdict"] = "HUMAN-REVIEW CANDIDATE"
	else:
		r["verdict"] = "NEEDS WORK"
	print("   A %s" % JSON.stringify(r["A"]))
	print("   B %s" % JSON.stringify(r["B"]).replace("\"line\"", "\"line(see above)\""))
	print("   C %s" % JSON.stringify(r["C"]))
	print("   VERDICT: %s%s" % [r["verdict"], ("  -- " + "; ".join(r["why_a"] + r["why_b"])) if r["verdict"] != "HUMAN-REVIEW CANDIDATE" else ""])
	return r


## Replays the Solver's moves through BoardModel (the play screen's rules):
## "empty" when the board clears, else where it stopped.
func _replay(level: LevelData, moves: Array) -> String:
	var m := EVENTS6.model_of(level)
	for mv in moves:
		var id: int = mv & Solver.ID_MASK
		match m.move_state(id):
			"ok":
				m.remove(id)
			"ram":
				m.ram(id)
			_:
				return "illegal move %d" % id
	return "empty" if m.block_count() == 0 else "%d blocks left" % m.block_count()


## The TIME UP check (Solver.from_model(board).solve(), as the page runs it)
## from every reachable position: the worst time (best of 3 runs) and nodes.
func _timeup_cost(level: LevelData, s: Solver) -> Dictionary:
	var paths := {s._key(): []}
	var queue := [[]]
	while not queue.is_empty():
		var path: Array = queue.pop_front()
		for mv in path:
			s._do(mv)
		for o in s._distinct_legal():
			s._do(o)
			var k := s._key()
			if not paths.has(k):
				paths[k] = path + [o]
				queue.append(path + [o])
			s._undo_move(o)
		for i in range(path.size() - 1, -1, -1):
			s._undo_move(path[i])
	var worst := 0.0
	var nodes := 0
	for k in paths:
		var best := 1e9
		for run in 3:
			var m := EVENTS6.model_of(level)
			for mv in paths[k]:
				if mv & Solver.RAM:
					m.ram(mv & Solver.ID_MASK)
				else:
					m.remove(mv & Solver.ID_MASK)
			var sv := Solver.from_model(m)
			var t0 := Time.get_ticks_usec()
			sv.solve()
			best = minf(best, (Time.get_ticks_usec() - t0) / 1000.0)
			nodes = maxi(nodes, sv.nodes)
		worst = maxf(worst, best)
	return {"ms": snappedf(worst, 0.1), "nodes": nodes, "positions": paths.size()}


## Along the Solver's solution: steps where a legal move loses, the distinct
## losing moves (by block and arrow), and a decision in the last third.
func _decisions(s: Solver, win: Dictionary, sol: Array) -> Dictionary:
	var steps := 0
	var distinct := {}
	var endgame := false
	var line := []
	var per_step := []
	for i in sol.size():
		var lose := []
		for o in s._distinct_legal():
			s._do(o)
			var ok: bool = s._alive_count == s._crate_n or win.get(s._key(), false)
			s._undo_move(o)
			if not ok:
				lose.append(_say(s, o))
		if not lose.is_empty():
			steps += 1
			for l in lose:
				distinct[l] = true
			if i >= sol.size() * 2 / 3:
				endgame = true
		per_step.append(lose.size())
		line.append("%s%s" % [_say(s, sol[i]), (" [x%d]" % lose.size()) if not lose.is_empty() else ""])
		s._do(sol[i])
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	return {"decision_steps": steps, "distinct_mistakes": distinct.size(), "endgame_decision": endgame, "losing_per_step": per_step,
		"mistakes": distinct.keys(), "line": line}


## The board with its mechanic neutralised: does it still play the same?
func _counterfactual(map: Array, mech: String, dec: Dictionary) -> Dictionary:
	var m2 := []
	for row in map:
		var cells := []
		for t in str(row).split(" ", false):
			var x: String = t
			match mech:
				"switch":
					x = _strip(_strip(x, "%"), "&")
				"gate":
					x = "." if x.begins_with("X") else _strip(x, "+")
				"lock":
					x = _strip(x, "#")
				"armor":
					x = x.replace("=", "")
				"magnet":
					x = x.trim_suffix("*") if not x.contains("@") else x
				"alt":
					x = x.replace("@~", "@")
			cells.append(x)
		m2.append(" ".join(cells))
	if m2 == map:
		return {"matters": false, "what": "nothing to neutralise"}
	var level := parse(m2)
	if level == null:
		return {"matters": true, "what": "the board falls apart without it"}
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	if not memo["win"].get(s._key(), false):
		return {"matters": true, "what": "unsolvable without it"}
	var d2 := _decisions(s, memo["win"], s.solve_moves())
	var same: bool = d2["decision_steps"] == dec["decision_steps"] and d2["distinct_mistakes"] == dec["distinct_mistakes"]
	return {"matters": not same, "what": "without it: %d decision steps, %d distinct mistakes (with it: %d, %d)" % [d2["decision_steps"], d2["distinct_mistakes"], dec["decision_steps"], dec["distinct_mistakes"]]}


static func _strip(t: String, mark: String) -> String:
	var i := t.find(mark)
	return t if i < 0 else t.substr(0, i) + t.substr(i + 2)
