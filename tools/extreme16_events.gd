extends RefCounted
## EXTREME phase 11 (development only): the central idea of each of the three
## 120-second boards as FACTS read from the solver's own state move by move,
## checked over EVERY winning line:
##   moved_then_turned (A, magnet) a spinner a magnet pulled is later turned
##                     in its NEW place by a neighbour's departure, then leaves
##                     (tools/extreme8_events.gd)
##   key_turn          (B, lock) the departure of the LAST block of a locked
##                     spinner's key colour turns it as it frees it, and the
##                     spinner later escapes (whether or not it was turned
##                     while locked: tools/extreme15_events.gd requires that)
##   reversed_ram      (C, switch + shell) a block a switch reversed (an odd
##                     number of times) rams the armored shell
## Keys: EV8's (f<id> odd flips, m<id> pulled spinners ...) and EV15's.

const EV8 := preload("res://tools/extreme8_events.gd")
const EV15 := preload("res://tools/extreme15_events.gd")
const EVENTS6 := preload("res://tools/extreme6_events.gd")
const FACTS := ["moved_then_turned", "key_turn", "lock_turn", "reversed_ram"]


static func move_events(s: Solver, mv: int) -> Dictionary:
	return EV15.move_events(s, mv)  # EV8's events plus the lock turns


static func fact_step(st: Dictionary, e: Dictionary) -> Dictionary:
	var id: int = e["id"]
	var rev: bool = e["ram"] and st.has("f%d" % id)
	var n := EV8.fact_step(st, e)
	var l := EV15.fact_step(st, e)
	for k in l:
		if str(k).begins_with("L") or str(k).begins_with("K") or k in ["lock_turn", "lock_turn2"]:
			n[k] = l[k]
	if not e["ram"] and st.has("K%d" % id):
		n["key_turn"] = true
	if rev:
		n["reversed_ram"] = true
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
