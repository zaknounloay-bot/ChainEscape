extends RefCounted
## EXTREME phase 13 (development only): the central idea of each of the five
## curated Time Attack boards (P5-P9) as FACTS read from the solver's own
## state move by move, checked over EVERY winning line (exhaustive), with the
## mechanics the 120 s pool has not used yet:
##   gate_through    a block escapes along a lane through the cell of a chain
##                   gate that an earlier move opened (the gate was a wall
##                   until its links were cleared)
##   crate_through   a block escapes along a lane through a movable crate's
##                   STARTING cell after the crate was pushed out of it
##                   (kept for the record: crate boards were rejected, the
##                   Solver's search overflows the stack on them)
##   alt_ram         an ALTERNATING spinner (it turns clockwise, then
##                   counter-clockwise, ...) rams the armored shell after it
##                   turned at least once: how many times it turned decides
##                   where it faces
##   advance_turn    a Sequence block's FIRST move (it comes back with its
##                   next arrow) turns a spinner, and that spinner later
##                   escapes
##   flip_opens_gate a block a switch reversed leaves, and its leaving opens a
##                   chain gate (tools/extreme8_events.gd)
##   gate_pull       a magnet's escape pulls a block that sat beyond a chain
##                   gate's cell on its line - possible only after the gate
##                   opened (a gate stops a pull)
## Plus every fact of tools/extreme16_events.gd. Keys: EV16's, G<cell> an
## opened gate's cell, Q<id> a spinner a Sequence advance turned, N<id> how
## many times a spinner turned.

const EV16 := preload("res://tools/extreme16_events.gd")
const EV8 := preload("res://tools/extreme8_events.gd")
const EVENTS6 := preload("res://tools/extreme6_events.gd")
const FACTS := ["gate_through", "crate_through", "alt_ram", "advance_turn", "flip_opens_gate", "gate_pull", "moved_then_turned", "key_turn", "reversed_ram"]

## Each crate's starting cell (set when a search starts; a crate never
## comes back into play once pushed away from it in these facts).
static var crate_start: Dictionary = {}


static func _reset(s: Solver) -> void:
	crate_start = {}
	for i in s._crate_ids:
		crate_start[s._cell[i]] = true


## EV16's events, plus: the cells of the gates this move opens, whether it is
## a Sequence advance (the block stays, with its next arrow), the crate cells
## it leaves empty, and the line behind a magnet up to the pulled block.
static func move_events(s: Solver, mv: int) -> Dictionary:
	var e := EV16.move_events(s, mv)
	var id: int = e["id"]
	e["gate_cells"] = []
	for g in e["gates"]:
		e["gate_cells"].append(s._cell[g])
	e["advance"] = false
	e["escaped"] = false
	e["crate_cells"] = []
	e["pull_line"] = []
	e["alt"] = s._spinner[id] == 1 and s._rule[id] == BlockData.SpinRule.ALT
	if e["ram"]:
		return e
	var stage := s._seq_stage[id] if s._seq_stage.size() > id else 0
	var pulled: int = e["pulled"]
	var from: int = e["pulled_from"]
	var behind := []
	if e["magnet"] and pulled >= 0:
		# The cells from the magnet back to where the pulled block sat.
		var step: Vector2i = -Direction.STEPS[s._dir[id]]
		var c := Vector2i(s._cell[id] % s.columns, s._cell[id] / s.columns) + step
		while c.x >= 0 and c.y >= 0 and c.x < s.columns and c.y < s.rows:
			var ci := c.y * s.columns + c.x
			if ci == from:
				break
			behind.append(ci)
			c += step
	e["pull_line"] = behind
	s._do(mv)
	e["advance"] = s._alive[id] == 1 and s._seq_stage.size() > id and s._seq_stage[id] != stage
	e["escaped"] = s._alive[id] == 0  # not a push (the launched block stays) nor an advance
	for cell in crate_start:
		var held := false
		for i in s._crate_ids:
			if s._alive[i] == 1 and s._cell[i] == cell:
				held = true
		if not held:
			e["crate_cells"].append(cell)
	s._undo_move(mv)
	return e


static func fact_step(st: Dictionary, e: Dictionary) -> Dictionary:
	var n := EV16.fact_step(st, e)
	var id: int = e["id"]
	if e["ram"] and e["alt"] and int(st.get("N%d" % id, 0)) >= 1:
		n["alt_ram"] = true
	for t in e["turned"]:
		n["N%d" % t] = int(n.get("N%d" % t, 0)) + 1
	if not e["ram"]:
		if e["advance"]:
			for t in e["turned"]:
				n["Q%d" % t] = true
		elif e["escaped"] and n.has("Q%d" % id):
			n["advance_turn"] = true
		if e["escaped"]:
			for cell in e["lane"]:
				if st.has("G%d" % cell):
					n["gate_through"] = true
				if e["crate_cells"].has(cell):
					n["crate_through"] = true
		for cell in e["pull_line"]:
			if st.has("G%d" % cell):
				n["gate_pull"] = true
	for cell in e["gate_cells"]:
		n["G%d" % cell] = true
	return n


static func solution_facts(s: Solver) -> Dictionary:
	_reset(s)
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
	_reset(s)
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
