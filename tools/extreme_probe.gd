extends RefCounted
## EXTREME research (development only): human-like play proxies for a board.
## Nothing here is used by the game; tools/extreme_analyze.gd (Gate 0
## failure analysis) and tools/extreme5_build.gd (the five prototypes) call
## it on Solver instances built from a parsed map.
##
## The earlier proxies (random tapper, a heuristic player that never
## remembers anything between games) model ONE attempt. People restart and
## remember what failed, so the measures here model a whole SESSION:
##
##   learner   trial and error with memory: plays the always-safe moves
##             (Solver._is_risky false) first, tries the risky ones in a
##             random order, and when stuck backs up to the last choice and
##             tries another one, never repeating a position it has already
##             seen fail. Counted: dead ends hit before the win and taps
##             (forward moves + taps to back up). `look` = how many moves
##             ahead it checks before committing to a move (0 = blind).
##   policies  one-attempt greedy players (no memory): safe-first random,
##             safe-first + lookahead, "turn as few spinners as possible".
##   choices   along a solution: how many genuinely different risky moves
##             were available and how many of them lose, per step, and for
##             each mechanic move (push / switch / advance / portal lane)
##             whether it was the only risky move on offer ("forced").

const CAP := 160  # moves per greedy attempt (crate boards can cycle)


## Solver._is_risky, plus every move a Magnet can change (a magnet's own
## escape, and escapes inside the zone its pulls reach): those can hurt too.
static func risky(s: Solver, mv: int) -> bool:
	if s._is_risky(mv):
		return true
	if s._mag_n == 0 or (mv & (Solver.RAM | Solver.PUSH)):
		return false
	var id := mv & Solver.ID_MASK
	return s._magnet[id] == 1 or s._mag_zone[s._cell[id]] == 1


## Trial-and-error session with memory. Returns {dead_ends, taps, won}.
##
## `order` ranks the risky moves the way a person with a rule of thumb might
## (ties at random): "random", "opportunist" (escape a spinner as soon as it
## can go), "patient" (escape spinners last), "min_turn" (turn as few
## spinners as possible), "mobility" (keep the most moves open),
## "push_last" (push a crate only when nothing else is left).
static func learner(s: Solver, seed: int, look: int = 0, tap_limit: int = 20000, order: String = "random") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := {"dead_ends": 0, "taps": 0, "won": false, "seen": {}, "limit": tap_limit, "order": order}
	var crates := s._crate_n > 0 or s._mag_n > 0  # no move is safe for sure
	_learn(s, rng, look, crates, st)
	return {"dead_ends": st["dead_ends"], "taps": st["taps"], "won": st["won"]}


static func _learn(s: Solver, rng: RandomNumberGenerator, look: int, crates: bool, st: Dictionary) -> bool:
	if s._alive_count == s._crate_n:
		st["won"] = true
		return true
	if st["taps"] > st["limit"]:
		return false
	var key := s._key()
	if st["seen"].has(key):
		return false
	st["seen"][key] = true
	var legal := s._distinct_legal()
	var calm: Array = []
	var rk: Array = []
	for mv in legal:
		if risky(s, mv):
			rk.append(mv)
		else:
			calm.append(mv)
	_shuffle(calm, rng)
	_shuffle(rk, rng)
	if st["order"] != "random":
		var score := {}
		for mv in rk:
			score[mv] = _rank(s, mv, st["order"])
		rk.sort_custom(func(a, b): return score[a] < score[b])
	var order: Array
	if not crates and not calm.is_empty():
		order = [calm[0]]  # an always-safe move: just play it
	else:
		order = calm + rk
	if look > 0:
		var keep := []
		for mv in order:
			s._do(mv)
			var dead := s._alive_count > s._crate_n and s._dead_within(look - 1)
			s._undo_move(mv)
			if not dead:
				keep.append(mv)
		if not keep.is_empty():
			order = keep
	if order.is_empty():
		st["dead_ends"] += 1
		return false
	for mv in order:
		s._do(mv)
		st["taps"] += 1
		if _learn(s, rng, look, crates, st):
			s._undo_move(mv)
			return true
		s._undo_move(mv)
		st["taps"] += 1  # backing up (UNDO, or a restart and replay)
	return false


## Lower = tried first.
static func _rank(s: Solver, mv: int, order: String) -> float:
	var id := mv & Solver.ID_MASK
	var plain := (mv & (Solver.RAM | Solver.PUSH)) == 0
	match order:
		"opportunist":
			return 0.0 if plain and s._spinner[id] == 1 else 1.0
		"patient":
			return 1.0 if plain and s._spinner[id] == 1 else 0.0
		"min_turn":
			return float(s._spinner_neighbours(id)) if plain else 0.5
		"mobility":
			s._do(mv)
			var n := s._distinct_legal().size()
			s._undo_move(mv)
			return -float(n)
		"push_last":
			return 1.0 if mv & Solver.PUSH else 0.0
	return 0.0


## Median / mean of `runs` learner sessions.
static func learner_stats(s: Solver, runs: int, look: int = 0, order: String = "random", tap_limit: int = 20000) -> Dictionary:
	var de := []
	var taps := []
	var lost := 0
	for i in runs:
		var r := learner(s, 1000 + i * 7919, look, tap_limit, order)
		de.append(r["dead_ends"])
		taps.append(r["taps"])
		if not r["won"]:
			lost += 1
	return {"dead_ends_med": _median(de), "dead_ends_mean": snappedf(_mean(de), 0.1),
		"taps_med": _median(taps), "taps_mean": snappedf(_mean(taps), 0.1), "unfinished": lost}


## One-attempt greedy players. kind: "safe" (always-safe moves first, then
## any risky move), "look2"/"look4" (risky moves that are not visibly dead
## within 2/4 moves), "min_turn" (the risky move that turns the fewest
## spinners and is not dead within 1), "mobility" (the risky move that
## leaves the most moves open).
static func policy_win(s: Solver, kind: String, games: int, seed: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wins := 0
	for g in games:
		var done: Array = []
		while done.size() < CAP:
			var legal := s._distinct_legal()
			if legal.is_empty():
				break
			var calm: Array = []
			for mv in legal:
				if not risky(s, mv):
					calm.append(mv)
			var pool: Array = calm
			if pool.is_empty():
				pool = _risky_pool(s, legal, kind)
			if pool.is_empty():
				pool = legal
			var pick: int = pool[rng.randi() % pool.size()]
			s._do(pick)
			done.append(pick)
		if s._alive_count == s._crate_n:
			wins += 1
		for i in range(done.size() - 1, -1, -1):
			s._undo_move(done[i])
	return snappedf(float(wins) / maxf(games, 1), 0.001)


static func _risky_pool(s: Solver, legal: Array, kind: String) -> Array:
	match kind:
		"safe":
			return legal
		"look2", "look4", "look6":
			var d := int(kind.substr(4))
			var out := []
			for mv in legal:
				s._do(mv)
				if not s._dead_within(d - 1):
					out.append(mv)
				s._undo_move(mv)
			return out
		"mobility":
			var best := -1
			var out := []
			for mv in legal:
				s._do(mv)
				var n := s._distinct_legal().size()
				var dead := n == 0 and s._alive_count > s._crate_n
				s._undo_move(mv)
				if dead:
					continue
				if n > best:
					best = n
					out = [mv]
				elif n == best:
					out.append(mv)
			return out
		"min_turn":
			var best := 99
			var out := []
			for mv in legal:
				var turns := 0 if (mv & (Solver.RAM | Solver.PUSH)) else s._spinner_neighbours(mv & Solver.ID_MASK)
				s._do(mv)
				var dead := s._dead_within(0)
				s._undo_move(mv)
				if dead:
					continue
				if turns < best:
					best = turns
					out = [mv]
				elif turns == best:
					out.append(mv)
			return out
	return legal


## Choice structure along the solver's solution: per step the distinct
## risky moves, how many of them lose, and whether the step's own move was
## the only risky move available (forced). Mechanic moves are classified by
## what the move does.
static func choices(s: Solver) -> Dictionary:
	var sol := s.solve_moves()
	var out := {"steps": sol.size(), "risky_steps": 0, "forced_risky": 0, "real_choices": 0,
		"losing_options": 0, "mech": {}}
	var applied := []
	for mv in sol:
		var legal := s._distinct_legal()
		var rk := legal.filter(func(x): return risky(s, x))
		var calm_left := legal.size() - rk.size()
		var losing := 0
		for x in rk:
			s._do(x)
			if s._alive_count > s._crate_n and s._solve_keep_state().is_empty():
				losing += 1
			s._undo_move(x)
		var kind := _kind(s, mv)
		if risky(s, mv):
			out["risky_steps"] += 1
			if rk.size() == 1 and calm_left == 0:
				out["forced_risky"] += 1
			if losing > 0:
				out["real_choices"] += 1
			out["losing_options"] += losing
		if kind != "":
			var e: Dictionary = out["mech"].get(kind, {"moves": 0, "forced": 0, "with_losing_alt": 0})
			e["moves"] += 1
			if rk.size() <= 1 and calm_left == 0:
				e["forced"] += 1
			if losing > 0:
				e["with_losing_alt"] += 1
			out["mech"][kind] = e
		s._do(mv)
		applied.append(mv)
	for i in range(applied.size() - 1, -1, -1):
		s._undo_move(applied[i])
	return out


static func _kind(s: Solver, mv: int) -> String:
	if mv & Solver.PUSH:
		return "push"
	if mv & Solver.RAM:
		return "ram"
	var id := mv & Solver.ID_MASK
	if s._pending(id):
		return "advance"
	if s._mag_n > 0 and s._magnet[id] == 1:
		return "magnet"
	if s._switch[id] >= 0:
		return "switch"
	if s._has_portals and s._first_in_portal_lane(id) == -1:
		# Escapes through a portal when the straight lane would be blocked
		# or the walk visits a portal cell.
		if _lane_uses_portal(s, id):
			return "portal"
	if s._spinner[id] == 1:
		return "spinner_escape"
	if s._spinner_neighbours(id) > 0:
		return "spinner_turn"
	return ""


static func _lane_uses_portal(s: Solver, id: int) -> bool:
	var idx: int = s._cell[id]
	var c: int = idx % s.columns
	var r: int = idx / s.columns
	var step: Vector2i = Direction.STEPS[s._dir[id]]
	c += step.x
	r += step.y
	while c >= 0 and r >= 0 and c < s.columns and r < s.rows:
		if s._portal_exit[r * s.columns + c] != -1:
			return true
		c += step.x
		r += step.y
	return false


## The losing moves along the solution that look most natural (a one-move
## greedy player would take them) and how long play can continue after
## each before getting stuck (longest line, a proxy for how late the
## mistake shows). Returns up to `n` [step, move, horizon] entries.
static func misleading(s: Solver, n: int = 4) -> Array:
	var sol := s.solve_moves()
	var found := []
	var applied := []
	for i in sol.size():
		for x in s._distinct_legal():
			if x == sol[i] or not risky(s, x):
				continue
			s._do(x)
			var lost := s._alive_count > s._crate_n and s._solve_keep_state().is_empty()
			if lost and not s._dead_within(0):
				found.append([i, x, _horizon(s, 14)])
			s._undo_move(x)
		s._do(sol[i])
		applied.append(sol[i])
	for i in range(applied.size() - 1, -1, -1):
		s._undo_move(applied[i])
	found.sort_custom(func(a, b): return a[2] > b[2])
	return found.slice(0, n)


## Longest of 40 random lines of play (capped) before no legal move is left.
static func _horizon(s: Solver, cap: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var best := 0
	for g in 40:
		var done := []
		while done.size() < cap:
			var legal := s._distinct_legal()
			if legal.is_empty():
				break
			var mv: int = legal[rng.randi() % legal.size()]
			s._do(mv)
			done.append(mv)
		best = maxi(best, done.size())
		for i in range(done.size() - 1, -1, -1):
			s._undo_move(done[i])
	return best


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


static func _median(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	var m := b.size() / 2
	return float(b[m]) if b.size() % 2 == 1 else (b[m - 1] + b[m]) / 2.0


static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	return float(a.reduce(func(x, y): return x + y, 0)) / a.size()
