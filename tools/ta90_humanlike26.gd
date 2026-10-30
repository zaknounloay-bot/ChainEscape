extends "res://tools/ta90_humanfit.gd"
## PHASE 26 (development only): human-like shortcut diagnostics
## (docs/extreme90_phase26.md, section C). Diagnostic only: no threshold, no
## rejection - it adds measures beside the unchanged Category A / B gates.
##   godot --headless --path . --script res://tools/ta90_humanlike26.gd -- --file=boards.json [--out=diag.json]
## boards.json: {"N52": {"map": [...]}, ...}
## Per board, from the full position graph:
##   open_moves / open_safe     legal moves at the start / of them still winnable
##   first_trap                 first solution step with a losing legal move (1 = the first move)
##   first_deep_trap            first step with a losing move whose dead end shows only after >= 4 moves
##   forced / free              solution steps with exactly one winning move / with >= 2 winning moves
##   win_density                winnable share of every reachable position
##   p_random                   EXACT win chance of a player who taps any legal move at random
##   p_look1 / p_look2          EXACT win chance of a random player who never makes a move that is
##                              dead (no legal move, board not clear) within 1 / 2 moves
##   p_calm                     EXACT win chance of a random player who plays "calm" moves (no spinner
##                              turned, no switch, no push ...) first whenever one exists (the
##                              "locally sensible" human of the brief), else any look1 move
##   dep_depth                  longest chain of escapes forced in order on EVERY sampled winning
##                              line (300 random winning lines): true dependency depth, not length
##   dep_pairs                  ordered escape pairs fixed on every sampled winning line
##   win_lines                  number of distinct winning move sequences (no-crate boards; -1 with crates)
## Crate boards (Movable) can cycle: their p_* use 2000 simulated games instead of the exact value.

const GAMES := 2000


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
		out[name] = humanlike(Array(d[name]["map"]))
		print("%-10s %s" % [name, JSON.stringify(out[name])])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func humanlike(map: Array) -> Dictionary:
	var level := parse(map)
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	var r := {"positions": win.size()}
	var open := s._distinct_legal()
	r["open_moves"] = open.size()
	var safe := 0
	for mv in open:
		s._do(mv)
		safe += int(s._alive_count == s._crate_n or win.get(s._key(), false))
		s._undo_move(mv)
	r["open_safe"] = safe
	r["win_density"] = snappedf(float(win.values().filter(func(v): return v).size()) / maxf(win.size(), 1), 0.01)
	var sol := s.solve_moves()
	var first_trap := 0
	var first_deep := 0
	var forced := 0
	var free := 0
	for i in sol.size():
		var winning := 0
		for o in s._distinct_legal():
			s._do(o)
			var ok: bool = s._alive_count == s._crate_n or win.get(s._key(), false)
			if not ok:
				first_trap = i + 1 if first_trap == 0 else first_trap
				if first_deep == 0 and EXPERT.longest(s, memo) >= 4:
					first_deep = i + 1
			winning += int(ok)
			s._undo_move(o)
		forced += int(winning == 1)
		free += int(winning >= 2)
		s._do(sol[i])
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	r.merge({"solution": sol.size(), "first_trap": first_trap, "first_deep_trap": first_deep, "forced": forced, "free": free})
	for kind in ["random", "look1", "look2", "calm"]:
		r["p_" + kind] = snappedf(_p_exact(s, kind, {}) if s._crate_n == 0 else _p_sim(s, kind), 0.001)
	r.merge(_dependency(s, win))
	r["win_lines"] = _lines(s, win, {}) if s._crate_n == 0 else -1
	return r


func _pool(s: Solver, kind: String) -> Array:
	var legal := s._distinct_legal()
	if kind == "random":
		return legal
	var look := 1 if kind != "look2" else 2
	var ok := []
	for mv in legal:
		s._do(mv)
		if s._alive_count == s._crate_n or not s._dead_within(look - 1):
			ok.append(mv)
		s._undo_move(mv)
	if kind == "calm":
		var calm := ok.filter(func(mv): return not PROBE.risky(s, mv))
		if not calm.is_empty():
			return calm
	return ok if not ok.is_empty() else legal


func _p_exact(s: Solver, kind: String, m: Dictionary) -> float:
	if s._alive_count == s._crate_n:
		return 1.0
	var k := s._key()
	if m.has(k):
		return m[k]
	var pool := _pool(s, kind)
	var p := 0.0
	for mv in pool:
		s._do(mv)
		p += _p_exact(s, kind, m)
		s._undo_move(mv)
	p = p / pool.size() if not pool.is_empty() else 0.0
	m[k] = p
	return p


func _p_sim(s: Solver, kind: String) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var wins := 0
	for g in GAMES:
		var done := []
		while done.size() < PROBE.CAP and s._alive_count != s._crate_n:
			var pool := _pool(s, kind)
			if pool.is_empty():
				break
			var mv: int = pool[rng.randi() % pool.size()]
			s._do(mv)
			done.append(mv)
		wins += int(s._alive_count == s._crate_n)
		for i in range(done.size() - 1, -1, -1):
			s._undo_move(done[i])
	return float(wins) / GAMES


## Escape order on 300 random winning lines: a before b on every line on which both escape.
func _dependency(s: Solver, win: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 26
	var lines := []
	for g in 300:
		var done := []
		var order := []
		while s._alive_count != s._crate_n and done.size() < PROBE.CAP:
			var good := []
			for mv in s._distinct_legal():
				s._do(mv)
				if s._alive_count == s._crate_n or win.get(s._key(), false):
					good.append(mv)
				s._undo_move(mv)
			if good.is_empty():
				break
			var mv: int = good[rng.randi() % good.size()]
			if not (mv & (Solver.RAM | Solver.PUSH)):
				order.append(mv & Solver.ID_MASK)
			s._do(mv)
			done.append(mv)
		lines.append(order)
		for i in range(done.size() - 1, -1, -1):
			s._undo_move(done[i])
	var ids := {}
	for o in lines:
		for b in o:
			ids[b] = true
	var before := {}
	for a in ids:
		for b in ids:
			if a == b:
				continue
			var always := true
			var seen := false
			for o in lines:
				var ia: int = o.find(a)
				var ib: int = o.find(b)
				if ia < 0 or ib < 0:
					continue
				seen = true
				if ia > ib:
					always = false
					break
			if seen and always:
				before[[a, b]] = true
	var h := {}
	var depth := 0
	for _pass in ids.size():
		for p in before:
			h[p[1]] = maxi(int(h.get(p[1], 0)), int(h.get(p[0], 0)) + 1)
	for b in h:
		depth = maxi(depth, int(h[b]) + 1)
	return {"dep_depth": depth, "dep_pairs": before.size(), "escapes": ids.size()}


func _lines(s: Solver, win: Dictionary, m: Dictionary) -> int:
	if s._alive_count == s._crate_n:
		return 1
	var k := s._key()
	if m.has(k):
		return m[k]
	var n := 0
	if win.get(k, false):
		for mv in s._distinct_legal():
			s._do(mv)
			n += _lines(s, win, m)
			s._undo_move(mv)
	m[k] = n
	return n
