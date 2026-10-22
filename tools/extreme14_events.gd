extends RefCounted
## EXTREME phase 9 (development only): the central idea of the new blind
## board as FACTS read from the solver's own state move by move (the events
## of tools/extreme8_events.gd), checked over EVERY winning line:
##   flip_pull   a magnet that a switch had reversed escaped and pulled a
##               block - it pulled from the side it did NOT face at the start
##   flip_ram    ... and the block it pulled later rammed a shell
## (extreme8's "f<id>" keys track which blocks are reversed.)

const EV8 := preload("res://tools/extreme8_events.gd")
const EVENTS6 := preload("res://tools/extreme6_events.gd")
const FACTS := ["flip_pull", "flip_ram", "reversed_escape", "relay"]


static func fact_step(st: Dictionary, e: Dictionary) -> Dictionary:
	var id: int = e["id"]
	var mine := {}
	if e["ram"]:
		if st.has("q%d" % id):
			mine["flip_ram"] = true
	elif e["magnet"] and st.has("f%d" % id) and e["pulled"] >= 0:
		mine["flip_pull"] = true
		mine["q%d" % e["pulled"]] = true
	var n := EV8.fact_step(st, e)
	n.merge(mine, true)
	return n


static func solution_facts(s: Solver) -> Dictionary:
	var sol := s.solve_moves()
	var st := {}
	for mv in sol:
		st = fact_step(st, EV8.move_events(s, mv))
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
		var n := fact_step(st, EV8.move_events(s, mv))
		s._do(mv)
		path.append(mv)
		var found := _find(s, n, fact, memo, path)
		s._undo_move(mv)
		if found:
			return true
		path.pop_back()
	return false
