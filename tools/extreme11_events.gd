extends RefCounted
## EXTREME phase 6 (development only): the central idea of the crossing-magnet
## prototype as FACTS read from the solver's own state move by move (the
## events of tools/extreme8_events.gd, plus the facts below), checked over
## EVERY winning line (exhaustive). A witness - a winning line WITHOUT a fact
## - is returned for the designer when the idea does not hold.
##   contested_pull   a magnet's escape pulled a block that was, at that
##                    moment, also the first block behind ANOTHER magnet (two
##                    pull lines met on it: the order decided where it went)
##   contested_turn   ... and that block was a spinner which, after the pull,
##                    was turned by a later escape next to it (also one that
##                    carries it on: its arrow when it arrives decides)
##   contested_ram    ... and that block later rammed a shell
## Plus the timing measures (static, over every reachable position):
##   timing_magnets   magnets whose escape wins in some winnable positions and
##                    loses in others (when it leaves matters, not only if)

const EV8 := preload("res://tools/extreme8_events.gd")
const EVENTS6 := preload("res://tools/extreme6_events.gd")
const FACTS := ["contested_pull", "contested_turn", "contested_ram", "relay", "aimed_ram", "moved_then_turned"]


## The first live block straight behind magnet `id` (solver state), or -1
## (as BoardModel._first_behind: a gate, crate or twin stops the pull).
static func first_behind(s: Solver, id: int) -> int:
	var back: Vector2i = -Direction.STEPS[s._dir[id]]
	var c := Vector2i(s._cell[id] % s.columns, s._cell[id] / s.columns) + back
	while c.x >= 0 and c.y >= 0 and c.x < s.columns and c.y < s.rows:
		var o := _block_at(s, c.y * s.columns + c.x)
		if o >= 0:
			if s._gate[o] == 1 or (s._crate_n > 0 and s._crate[o] == 1):
				return -1
			return o
		c += back
	return -1


static func _block_at(s: Solver, cell: int) -> int:
	for o in s._alive.size():
		if s._alive[o] == 1 and s._cell[o] == cell:
			return o
	return -1


## extreme8's events of one move, plus whether the pulled block was contested.
static func move_events(s: Solver, mv: int) -> Dictionary:
	var e := EV8.move_events(s, mv)
	e["contested"] = false
	var p: int = e["pulled"]
	if p >= 0 and e["magnet"]:
		for o in s._alive.size():
			if o != e["id"] and s._alive[o] == 1 and s._magnet[o] == 1 and first_behind(s, o) == p:
				e["contested"] = true
				break
	return e


## Keys: extreme8's keys, plus x<id> a contested block that was pulled,
## y<id> ... a spinner, now waiting to be turned in its new place.
static func fact_step(st: Dictionary, e: Dictionary) -> Dictionary:
	var n := EV8.fact_step(st, e)
	var id: int = e["id"]
	if e["ram"]:
		if n.has("x%d" % id):
			n["contested_ram"] = true
		return n
	var p: int = e["pulled"]
	# Any later turn counts, also by a magnet whose escape carries it again
	# (the turn comes before the pull, so the contested pull's own escape
	# never counts: y<id> is set below).
	for t in e["turned"]:
		if n.has("y%d" % t):
			n["contested_turn"] = true
	if p >= 0 and e["contested"]:
		n["contested_pull"] = true
		n["x%d" % p] = true
		if e["pulled_spinner"]:
			n["y%d" % p] = true
	return n


static func solution_facts(s: Solver) -> Dictionary:
	var sol := s.solve_moves()
	var st := {}
	for mv in sol:
		st = fact_step(st, move_events(s, mv))
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	var out := {}
	for k in FACTS:
		out[k] = st.has(k)
	return out


## A winning line (solver moves) that never reaches `fact`, or [] if none.
static func witness(level: LevelData, fact: String) -> Array:
	var s := Solver.from_model(EVENTS6.model_of(level))
	var path: Array = []
	if _find(s, {}, fact, {}, path):
		return path
	return []


static func _find(s: Solver, st: Dictionary, fact: String, memo: Dictionary, path: Array) -> bool:
	if st.has(fact):
		return false
	if s._alive_count == s._crate_n:
		return true
	var keys := st.keys()
	keys.sort()
	var parts := []
	for k in keys:
		parts.append("%s:%s" % [k, st[k]])
	var key := s._key() + "|" + ",".join(parts)
	if memo.has(key):
		return false
	memo[key] = true
	for mv in s._distinct_legal():
		var n := fact_step(st, move_events(s, mv))
		s._do(mv)
		path.append(mv)
		var found := _find(s, n, fact, memo, path)
		s._undo_move(mv)
		if found:
			return true
		path.pop_back()
	return false


## Timing over every reachable position (`win` = expert_probe.explore's
## key -> winnable): for each magnet, in how many winnable positions its
## escape is legal and wins / loses. {"per": {id: [wins, losses]},
## "timing_magnets": ids with both > 0}.
static func timing(s: Solver, win: Dictionary) -> Dictionary:
	var per := {}
	var seen := {}
	_timing(s, win, per, seen)
	var tm := []
	for id in per:
		if per[id][0] > 0 and per[id][1] > 0:
			tm.append(id)
	tm.sort()
	return {"per": per, "timing_magnets": tm}


static func _timing(s: Solver, win: Dictionary, per: Dictionary, seen: Dictionary) -> void:
	if s._alive_count == s._crate_n:
		return
	var key := s._key()
	if seen.has(key) or not win.get(key, false):
		return
	seen[key] = true
	for mv in s._distinct_legal():
		var id := mv & Solver.ID_MASK
		var magnet_escape: bool = (mv & (Solver.RAM | Solver.PUSH)) == 0 and s._mag_n > 0 and s._magnet[id] == 1
		s._do(mv)
		var ok: bool = s._alive_count == s._crate_n or win.get(s._key(), false)
		if magnet_escape:
			if not per.has(id):
				per[id] = [0, 0]
			per[id][0 if ok else 1] += 1
		if ok:
			_timing(s, win, per, seen)
		s._undo_move(mv)
