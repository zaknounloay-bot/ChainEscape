extends "res://tools/extreme8_build.gd"
## Human behaviour analysis (development only): candidate features of
## STRATEGIC difficulty for experienced players, computed on every board
## people have rated, to test against their ratings (docs/extreme9_analysis.md).
##   godot --headless --path . --script res://tools/expert_features.gd
## Per board, on the solver's solution and every losing move along it:
##   side_effects   solution moves that change another block (a spinner
##                  turned, a block pulled, an arrow reversed, a gate opened)
##   pulls          solution moves that move another block (geometry change)
##   visible_loss   share of the losing moves along the solution after which
##                  the board shows a STATIC stand-off right away: two blocks
##                  facing each other with nothing between, neither a spinner,
##                  a switch target or in a magnet's pull line - the kind of
##                  loss an expert reads at a glance
##   hidden_loss    losing moves along the solution that are neither visible
##                  stand-offs nor detectable by 4-move lookahead
##   pull_cells     how far the solution's pulls move blocks, in cells
##                  (total, and the longest single pull)
##   magnet_traps   losing moves along the solution that are a magnet's
##                  escape (a wrong pull), and on how many steps one exists
##   perceptive     a rule-of-thumb learner (look 2, memory) that also
##                  abandons any position with a visible stand-off at once:
##                  dead ends of its luckiest habit

const EV6 := preload("res://tools/extreme6_events.gd")
const BANK := [["res://data/dev/extreme5.json", ["T1", "T2", "T3", "T4", "T5"]], ["res://data/dev/extreme6.json", ["P1", "P2"]],
	["res://data/dev/extreme7.json", ["H1", "H2"]], ["res://data/dev/extreme8.json", ["E1", "E2"]]]


func _initialize() -> void:
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	for f in BANK:
		for b in JSON.parse_string(FileAccess.get_file_as_string(f[0]))["boards"]:
			if b["id"] in f[1]:
				print(JSON.stringify(features(str(b["id"]), Array(b["puzzle"]["map"]))))
	quit()


## A static stand-off on the board right now (see the header).
static func visible_standoff(m: BoardModel) -> bool:
	var flip_live := {}
	var pull_line := {}
	for b in m.blocks.values():
		if b.switch_group != "":
			flip_live[b.switch_group] = true
		if b.magnet:
			var back: Vector2i = Direction.STEPS[Direction.opposite(b.direction)]
			var c: Vector2i = b.cell + back
			while m.is_inside(c):
				pull_line[c] = true
				c += back
	for a in m.blocks.values():
		if a.is_gate() or a.is_crate() or a.is_spinner() or (a.flip_link != "" and flip_live.has(a.flip_link)) or pull_line.has(a.cell):
			continue
		var o := m.find_blocker(a.id)
		if o == null or o.is_spinner() or o.is_gate() or o.is_crate() or o.armored or a.armored:
			continue
		if (o.flip_link != "" and flip_live.has(o.flip_link)) or pull_line.has(o.cell):
			continue
		var back := m.find_blocker(o.id)
		if back != null and back.id == a.id:
			return true
	return false


func features(name: String, map: Array) -> Dictionary:
	var level := parse(map)
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	var m := EV6.model_of(level)
	var sol := s.solve_moves()
	var side := 0
	var pulls := 0
	var losing := 0
	var visible := 0
	var hidden4 := 0
	var magnet_traps := 0
	var magnet_steps := 0
	var pull_cells := 0
	var pull_max := 0
	for mv in sol:
		var step_has_magnet_trap := false
		# The losing moves available at this step (on the solver's model).
		for o in s._distinct_legal():
			s._do(o)
			var lost: bool = s._alive_count != s._crate_n and not win.get(s._key(), false)
			var deep: bool = lost and not s._dead_within(3)
			s._undo_move(o)
			if not lost:
				continue
			losing += 1
			if s._mag_n > 0 and (o & (Solver.RAM | Solver.PUSH)) == 0 and s._magnet[o & Solver.ID_MASK] == 1:
				magnet_traps += 1
				step_has_magnet_trap = true
			var snap := m.snapshot()
			_play(m, o)
			if visible_standoff(m):
				visible += 1
			elif deep:
				hidden4 += 1
			m.restore(snap)
		magnet_steps += 1 if step_has_magnet_trap else 0
		var before := m.snapshot()
		m.last_pull = {}  # a ram or push does not clear it
		_play(m, mv)
		var ev := _effects(before, m.snapshot())
		if not m.last_pull.is_empty():
			var dcell: Vector2i = m.last_pull["to"] - m.last_pull["from"]
			var dist := absi(dcell.x) + absi(dcell.y)
			pull_cells += dist
			pull_max = maxi(pull_max, dist)
		if not ev.is_empty():
			side += 1
		pulls += 1 if ev.has("pull") else 0
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	var best := 99.0
	for o in ORDERS:
		best = minf(best, _perceptive(level, o))
	return {"name": name, "solution": sol.size(), "side_effects": side, "pulls": pulls, "losing_moves": losing,
		"visible_loss": snappedf(float(visible) / maxf(losing, 1), 0.01), "hidden_loss": hidden4, "perceptive": best,
		"magnet_traps": magnet_traps, "magnet_trap_steps": magnet_steps, "pull_cells": pull_cells, "pull_max": pull_max}


func _play(m: BoardModel, mv: int) -> void:
	var id := mv & Solver.ID_MASK
	var st := m.move_state(id)
	match st:
		"ok":
			m.remove(id)
		"ram":
			m.ram(id)
		"push":
			m.push(id)
		"advance":
			m.advance(id)


## What one move did to the other blocks (as VhHumanTest.mech_events):
## gates opened, blocks moved, arrows changed, shells cracked.
static func _effects(before: Array, after: Array) -> Dictionary:
	var a := {}
	for b in after:
		a[b.id] = b
	var ev := {}
	var gone := 0
	for b in before:
		if not a.has(b.id):
			gone += 1
			if b.kind == BlockData.Kind.GATE:
				ev["gate"] = true
			continue
		var n: BlockData = a[b.id]
		if b.kind != BlockData.Kind.CRATE and n.cell != b.cell:
			ev["pull"] = true
		if n.direction != b.direction and n.seq_stage == b.seq_stage:
			ev["turn"] = true
		if b.armored and not n.armored:
			ev["ram"] = true
	return ev


## The perceptive learner: the probe's look-2 learner with memory, which also
## treats a position with a visible stand-off as a dead end at once (median
## dead ends over 9 sessions of one habit).
func _perceptive(level: LevelData, order: String) -> float:
	var des := []
	for k in 9:
		var s := _solver(level)
		var m := EV6.model_of(level)
		var st := {"dead": 0, "taps": 0, "seen": {}}
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + k * 7919
		_learn(s, m, rng, order, st)
		des.append(st["dead"])
	des.sort()
	return des[des.size() / 2]


func _learn(s: Solver, m: BoardModel, rng: RandomNumberGenerator, order: String, st: Dictionary) -> bool:
	if s._alive_count == s._crate_n:
		return true
	if st["taps"] > 20000:
		return false
	var key := s._key()
	if st["seen"].has(key):
		return false
	st["seen"][key] = true
	if visible_standoff(m):
		st["dead"] += 1
		return false
	var legal := s._distinct_legal()
	var keep := []
	for mv in legal:
		s._do(mv)
		var dead := s._alive_count > s._crate_n and s._dead_within(1)
		s._undo_move(mv)
		if not dead:
			keep.append(mv)
	if keep.is_empty():
		st["dead"] += 1
		return false
	var score := {}
	for mv in keep:
		score[mv] = PROBE._rank(s, mv, order) + rng.randf() * 0.01
	keep.sort_custom(func(a, b): return score[a] < score[b])
	for mv in keep:
		var snap := m.snapshot()
		_play(m, mv)
		s._do(mv)
		st["taps"] += 1
		var ok := _learn(s, m, rng, order, st)
		s._undo_move(mv)
		m.restore(snap)
		if ok:
			return true
	return false
