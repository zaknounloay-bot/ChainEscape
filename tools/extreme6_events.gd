extends RefCounted
## EXTREME phase 2 (development only): what happens on a board's solver
## solution, replayed tap by tap through BoardModel (the rules the play
## screen runs). Shared by tools/extreme6_build.gd (each group's central
## idea) and tools/extreme6_check.gd.
##   reversed_pulls          a magnet escaped and pulled AFTER a switch
##                           reversed it (an odd number of flips)
##   pulled_then_rammed      an armored block pulled by a magnet, later rammed
##   turned_spinner_portal   a spinner that has turned leaves through a portal
## Also counts pulls, rams and portal escapes. {} = no solution / no replay.


static func model_of(level: LevelData) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks.map(func(b): return b.duplicate_data()))
	m.set_portals(level.portals)
	return m


static func solution(level: LevelData) -> Array:
	return Array(Solver.from_model(model_of(level)).solve())


static func events(level: LevelData, sol: Array = []) -> Dictionary:
	if sol.is_empty():
		sol = solution(level)
	if sol.is_empty():
		return {}
	var m := model_of(level)
	var flips := {}
	var pulled_armor := {}
	var start_dir := {}
	for id in m.blocks:
		start_dir[id] = m.blocks[id].direction
	var ev := {"reversed_pulls": 0, "pulled_then_rammed": 0, "turned_spinner_portal": 0, "pulls": 0, "rams": 0, "portal_escapes": 0}
	for id in sol:
		var st := m.move_state(id)
		if st == "ram":
			var t := m.ram(id)
			ev["rams"] += 1
			if pulled_armor.has(t):
				ev["pulled_then_rammed"] += 1
			continue
		if st != "ok":
			return {}
		var b: BlockData = m.blocks[id]
		var via: Array = m.lane(id)["via"] if not m.portals.is_empty() else []
		if not via.is_empty():
			ev["portal_escapes"] += 1
			if b.is_spinner() and b.direction != start_dir[id]:
				ev["turned_spinner_portal"] += 1
		var was_magnet := b.magnet
		var reversed := int(flips.get(id, 0)) % 2 == 1
		m.remove(id)
		for f in m.last_flipped:
			flips[f] = int(flips.get(f, 0)) + 1
		if was_magnet and not m.last_pull.is_empty():
			ev["pulls"] += 1
			if reversed:
				ev["reversed_pulls"] += 1
			var p: int = m.last_pull["block"]
			if m.blocks.has(p) and m.blocks[p].armored:
				pulled_armor[p] = true
	if not m.is_empty():
		return {}
	return ev


## The idea of each group holds on the events (reasons it fails; [] = holds).
static func idea_fails(group: String, ev: Dictionary) -> Array:
	if ev.is_empty():
		return ["no solution replays"]
	match group:
		"A":
			return [] if ev["reversed_pulls"] > 0 else ["no pull by a switch-reversed magnet"]
		"B":
			return [] if ev["pulled_then_rammed"] > 0 else ["no armored block pulled and then rammed"]
		"C":
			return [] if ev["turned_spinner_portal"] > 0 else ["no turned spinner leaving through a portal"]
	return []
