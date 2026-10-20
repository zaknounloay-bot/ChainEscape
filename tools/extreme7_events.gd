extends RefCounted
## EXTREME DESIGN EXPERIMENT (development only): the central idea of each
## hand-designed board as FACTS read from the solver's own state, move by
## move, and checked over EVERY winning line (exhaustive over all reachable
## positions). Shared by tools/extreme7_build.gd and tools/extreme7_check.gd.

const EVENTS6 := preload("res://tools/extreme6_events.gd")
## The facts each recipe needs on every winning line.
const MUST := {
	"A_remote": ["gate_before_switch", "reversed_escape"],
	"B_geometry": ["aimed_ram", "carried_twice"],
}
const FACTS := ["switch_two_places", "gate_before_switch", "reversed_escape", "pulled_rammer", "aimed_ram", "carried_twice"]


## The facts reached on the solver's own solution.
static func solution_facts(s: Solver) -> Dictionary:
	var sol := s.solve_moves()
	var st := {}
	for mv in sol:
		st = fact_step(st, move_events(s, mv))
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	var facts := {}
	for k in FACTS:
		facts[k] = st.has(k)
	return facts



## What `mv` does (the solver is left unchanged): {"id", "ram", "target",
## "pulled", "pulled_from", "pulled_armored", "flipped", "turned", "gates",
## "lane": cells crossed by an escape, "odd": the escaping block's arrow
## is reversed from its start (by a switch)}.
static func move_events(s: Solver, mv: int) -> Dictionary:
	var id := mv & Solver.ID_MASK
	var e := {"id": id, "ram": (mv & Solver.RAM) != 0, "target": -1, "pulled": -1, "pulled_from": -1, "pulled_armored": false,
		"flipped": [], "turned": [], "gates": [], "lane": [], "switch": s._switch[id] >= 0, "magnet": s._mag_n > 0 and s._magnet[id] == 1}
	if e["ram"]:
		e["target"] = s._first_in_lane(id)
		return e
	var cell := s._cell.duplicate()
	var dir := s._dir.duplicate()
	var alive := s._alive.duplicate()
	var armor := s._armor.duplicate()
	var step: Vector2i = Direction.STEPS[s._dir[id]]
	var c := Vector2i(s._cell[id] % s.columns, s._cell[id] / s.columns) + step
	while c.x >= 0 and c.y >= 0 and c.x < s.columns and c.y < s.rows:
		e["lane"].append(c.y * s.columns + c.x)
		c += step
	s._do(mv)
	for o in alive.size():
		if o == id or alive[o] == 0:
			continue
		if s._alive[o] == 0:
			if s._gate[o] == 1:
				e["gates"].append(o)
			continue
		if s._cell[o] != cell[o]:
			e["pulled"] = o
			e["pulled_from"] = cell[o]
			e["pulled_armored"] = not armor.is_empty() and armor[o] == 1
		if s._dir[o] != dir[o]:
			if s._spinner[o] == 1:
				e["turned"].append(o)
			else:
				e["flipped"].append(o)
	s._undo_move(mv)
	return e


## The idea facts along a line, as a small immutable state.
## Keys: "f<id>" = the block's arrow is reversed (odd flips), "h<id>" = a
## block a magnet pulled, "c<id>" = how many magnet escapes pulled it, "s<id>" = a spinner a magnet's escape turned AND
## pulled (aimed and carried in one move); plus the facts reached:
##   switch_two_places  a switch's escape reversed a block AND opened a gate
##                      or turned a spinner
##   reversed_escape    a block left in the direction a switch reversed it to
##   gate_before_switch the switch reversed blocks only after a gate opened
##   pulled_rammer      a block a magnet pulled later rammed a shell
##   aimed_ram          that rammer was a spinner the same escape had turned
##   carried_twice      a block pulled by two magnets' escapes later rammed
static func fact_step(st: Dictionary, e: Dictionary) -> Dictionary:
	var n := st.duplicate()
	var id: int = e["id"]
	if e["ram"]:
		if n.has("h%d" % id):
			n["pulled_rammer"] = true
		if n.has("s%d" % id):
			n["aimed_ram"] = true
		if int(n.get("c%d" % id, 0)) >= 2:
			n["carried_twice"] = true
		return n
	if n.has("f%d" % id):
		n["reversed_escape"] = true
	if e["switch"] and not e["flipped"].is_empty() and (not e["gates"].is_empty() or not e["turned"].is_empty()):
		n["switch_two_places"] = true
	if e["switch"] and not e["flipped"].is_empty() and n.has("gate_open"):
		n["gate_before_switch"] = true
	if not e["gates"].is_empty():
		n["gate_open"] = true
	for f in e["flipped"]:
		if n.has("f%d" % f):
			n.erase("f%d" % f)
		else:
			n["f%d" % f] = true
	var p: int = e["pulled"]
	if p >= 0:
		n["h%d" % p] = true
		if e["magnet"]:
			n["c%d" % p] = int(n.get("c%d" % p, 0)) + 1
		if e["magnet"] and e["turned"].has(p):
			n["s%d" % p] = true
	return n


## For each idea fact: true if EVERY winning line reaches it (exhaustive over
## all reachable positions and fact states).
static func must_facts(level: LevelData, recipe: String) -> Dictionary:
	var out := {}
	for k in MUST.get(recipe, []):
		var s := Solver.from_model(EVENTS6.model_of(level))
		var memo := {}
		out[k] = not _win_without(s, {}, k, memo)
	return out


static func _win_without(s: Solver, st: Dictionary, fact: String, memo: Dictionary) -> bool:
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
		return memo[key]
	memo[key] = false
	var found := false
	for mv in s._distinct_legal():
		var e := move_events(s, mv)
		var n := fact_step(st, e)
		s._do(mv)
		found = _win_without(s, n, fact, memo)
		s._undo_move(mv)
		if found:
			break
	memo[key] = found
	return found
