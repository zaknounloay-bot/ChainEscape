extends RefCounted
## EXTREME phase 10 (development only): the central idea of the 120-second
## board as FACTS read from the solver's own state move by move, checked over
## EVERY winning line:
##   lock_turn   a LOCKED spinner (its key colour still on the board) is
##               turned by a neighbour's departure, and later escapes: its
##               exit depends on how many turns it took before it opened
##   lock_turn2  ... turned at least twice while locked
##   key_turn    the departure of the LAST block of its key colour turns it
##               (the key and the turn come in one move)
## Keys: L<id> = turns of locked spinner <id> while it was still locked.

const EV8 := preload("res://tools/extreme8_events.gd")
const EVENTS6 := preload("res://tools/extreme6_events.gd")
const FACTS := ["lock_turn", "lock_turn2", "key_turn"]


## EV8's events plus, for this escape, the locked spinners it turns while they
## stay locked ("locked_turned") and those it turns as it frees them
## ("key_turned"), read from the solver BEFORE the move.
static func move_events(s: Solver, mv: int) -> Dictionary:
	var e := EV8.move_events(s, mv)
	e["locked_turned"] = []
	e["key_turned"] = []
	if e["ram"]:
		return e
	var id: int = e["id"]
	for t in e["turned"]:
		if s._lock[t] < 0:
			continue
		var key: int = s._lock[t]
		var left: int = s._color_count[key] - (1 if s._color[id] == key else 0)
		if left > 0:
			e["locked_turned"].append(t)
		elif s._color[id] == key:
			e["key_turned"].append(t)
	return e


static func fact_step(st: Dictionary, e: Dictionary) -> Dictionary:
	var n := st.duplicate()
	var id: int = e["id"]
	for t in e.get("locked_turned", []):
		n["L%d" % t] = int(n.get("L%d" % t, 0)) + 1
	for t in e.get("key_turned", []):
		n["K%d" % t] = true
	if not e["ram"] and n.has("L%d" % id):
		n["lock_turn"] = true
		if int(n["L%d" % id]) >= 2:
			n["lock_turn2"] = true
		if n.has("K%d" % id):
			n["key_turn"] = true
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
