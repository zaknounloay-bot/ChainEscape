extends RefCounted
## EXTREME expert experiment (development only): each design's central idea
## as FACTS read from the solver's own state move by move (the same events as
## tools/extreme7_events.gd, plus the facts below), checked over EVERY winning
## line (exhaustive). A witness - a winning line WITHOUT a fact - is returned
## for the designer when the idea does not hold.
##   relay             a magnet was dragged by another magnet's escape, and
##                     later its own escape pulled a block
##   relay_carry       ... and the block it pulled later rammed a shell
##   aimed_ram         a magnet's escape turned AND carried a spinner, which
##                     later rammed a shell
##   flip_opens_gate   a block reversed by a switch left, and its leaving
##                     opened a chain gate
##   reversed_escape   a block left in the direction a switch reversed it to
##   gate_before_switch a switch reversed blocks only after a gate opened
##   moved_then_turned a spinner a magnet pulled was later turned in its new
##                     place by a neighbour's escape, then left
##   two_moved_turned  ... for two different spinners
##   moved_turned_adv  moved_then_turned by a counter-clockwise or
##                     alternating spinner (an advanced turn rule)

const EV7 := preload("res://tools/extreme7_events.gd")
const EVENTS6 := preload("res://tools/extreme6_events.gd")
const FACTS := ["relay", "relay_carry", "aimed_ram", "flip_opens_gate", "reversed_escape", "gate_before_switch", "moved_then_turned", "two_moved_turned", "moved_turned_adv"]


## extreme7's events of one move, plus what the pulled block was.
static func move_events(s: Solver, mv: int) -> Dictionary:
	var e := EV7.move_events(s, mv)
	var p: int = e["pulled"]
	e["pulled_magnet"] = p >= 0 and s._mag_n > 0 and s._magnet[p] == 1
	e["pulled_spinner"] = p >= 0 and s._spinner[p] == 1
	e["was_link"] = not e["ram"] and s._link[e["id"]] >= 0
	# Spinners with an advanced turn rule (anything but plain clockwise).
	e["adv"] = []
	for id in ([p] if p >= 0 else []) + e["turned"]:
		if s._spinner[id] == 1 and s._rule[id] != BlockData.SpinRule.CW:
			e["adv"].append(id)
	return e


## Keys: f<id> odd flips; r<id> a magnet dragged by a magnet; c<id> a block
## carried by a relayed magnet; s<id> a spinner turned + carried by one
## escape; m<id> a spinner a magnet moved; t<id> ... later turned in place;
## mt = count of spinners that left after moved_then_turned; gate_open.
static func fact_step(st: Dictionary, e: Dictionary) -> Dictionary:
	var n := st.duplicate()
	var id: int = e["id"]
	if e["ram"]:
		if n.has("s%d" % id):
			n["aimed_ram"] = true
		if n.has("c%d" % id):
			n["relay_carry"] = true
		return n
	if n.has("f%d" % id):
		n["reversed_escape"] = true
		if not e["gates"].is_empty():
			n["flip_opens_gate"] = true
	if e["switch"] and not e["flipped"].is_empty() and n.has("gate_open"):
		n["gate_before_switch"] = true
	if not e["gates"].is_empty():
		n["gate_open"] = true
	if n.has("t%d" % id):
		n["mt"] = int(n.get("mt", 0)) + 1
		n["moved_then_turned"] = true
		if n.has("a%d" % id):
			n["moved_turned_adv"] = true
		if int(n["mt"]) >= 2:
			n["two_moved_turned"] = true
	for f in e["flipped"]:
		if n.has("f%d" % f):
			n.erase("f%d" % f)
		else:
			n["f%d" % f] = true
	var p: int = e["pulled"]
	# Spinners turned in place (not the one this escape just carried).
	for t in e["turned"]:
		if t != p and n.has("m%d" % t):
			n["t%d" % t] = true
	if p >= 0:
		if e["magnet"] and n.has("r%d" % id):
			n["relay"] = true
			n["c%d" % p] = true
		if e["pulled_magnet"] and e["magnet"]:
			n["r%d" % p] = true
		if e["pulled_spinner"]:
			n["m%d" % p] = true
			if e["adv"].has(p):
				n["a%d" % p] = true
			if e["turned"].has(p):
				n["s%d" % p] = true
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


## For each fact: true if EVERY winning line reaches it.
static func must_facts(level: LevelData, facts: Array) -> Dictionary:
	var out := {}
	for k in facts:
		out[k] = witness(level, k).is_empty()
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
		return false  # explored: no line from here (a found line returns at once)
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
