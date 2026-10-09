extends SceneTree
## MAGNET MECHANIC PROTOTYPE (development only): checks and writes the Magnet
## lab's board file, data/dev/mechlab_magnet.json (?mechlab=magnet).
##
##   godot --headless --path . --script res://tools/mechlab_magnet_build.gd            # check + write
##   godot --headless --path . --script res://tools/mechlab_magnet_build.gd -- --dry   # check + print only
##
## The rule (BoardModel.pull_target): a MAGNET ("*" after an arrow, lab only)
## escapes like any arrow; then the first block straight BEHIND it (opposite
## its arrow) slides into the cell it left - after the escape's own spinner
## turns. A gate or a twin behind it stops the pull; nothing behind, nothing
## moves. The board shows a dotted line from that block to the magnet.
##
## Every board must be: solvable; NOT solvable with its magnets made plain
## arrows (the pull is needed); and the Solver's solution must replay move
## for move through BoardModel (model and Solver agree). Metrics (proxies
## only - the human test decides), from an exact search of every reachable
## state: min moves, pulls in a shortest solution, dead states, traps on the
## shortest path (states where some legal move loses), the random tapper's
## win rate, and which first moves lose.

const OUT_PATH := "res://data/dev/mechlab_magnet.json"

const BOARDS := [
	# A - INTRODUCTION. Blue and yellow face each other at the bottom: neither
	# can ever leave. The red MAGNET flies up and pulls blue (the block behind
	# it) into its cell, where blue's lane is free. Nothing can go wrong.
	{"id": "A1", "stage": "A", "title": "First Pull", "map": [
		".  .  .   .  .",
		".  .  .   .  .",
		"G< .  R^* .  .",
		".  .  .   .  .",
		"Pv .  B>  Y< .",
	]},
	# B - COMBINATION (Magnet + Spinner). The magnet's line shows it would pull
	# purple - the wrong block: blue and yellow at the bottom stay stuck. Let
	# purple go first and the line moves to blue. The red magnet's escape also
	# turns the yellow spinner beside it, away from the blue block it pulls in.
	{"id": "B1", "stage": "B", "title": "Turn and Pull", "map": [
		".  .  .   .    .",
		"B^ .  .   .    .",
		"Gv .  R^* Y<@  .",
		".  .  P>  .    .",
		".  .  B>  Y<   .",
	]},
	# C - CHALLENGE (two magnets + a spinner). Two visible traps:
	#  - red magnet first: its line shows green (a decoy), not the stuck
	#    yellow at the bottom - clear green first;
	#  - blue magnet first: its escape turns the purple spinner to face green
	#    and pulls it into green's row: a deadlock. Let yellow (beside the
	#    spinner) escape first - the spinner then lands pointing up, free.
	{"id": "C1", "stage": "C", "title": "Two Magnets", "map": [
		".  .   .  .    .   .",
		"B> .   .  .    .   Gv",
		".  R^* .  Pv@  Yv  .",
		".  G>  .  Bv*  .   .",
		".  .   .  .    .   .",
		".  Y>  P< .    .   .",
	]},
]


func _init() -> void:
	LevelManager.dev_magnet = true
	var dry := "--dry" in OS.get_cmdline_user_args()
	var errors := _build(dry)
	print("MAGNET LAB BUILD %s (%d problem%s)" % ["OK" if errors == 0 else "FAILED", errors, "" if errors == 1 else "s"])
	quit(0 if errors == 0 else 1)


func _build(dry: bool) -> int:
	var errors := 0
	var out := []
	for spec in BOARDS:
		var map: Array = spec["map"].map(func(r): return " ".join(String(r).split(" ", false)))
		var m := evaluate(map)
		print("%s %s: %s" % [spec["id"], spec["title"], describe(m)])
		for p in m["problems"]:
			print("  PROBLEM: " + p)
			errors += 1
		var def := PuzzleDefinition.new()
		def.rows = map.size()
		def.columns = String(map[0]).split(" ", false).size()
		def.map = PackedStringArray(map)
		var metrics := m.duplicate()
		metrics.erase("problems")
		out.append({"id": spec["id"], "variant": "magnet", "stage": spec["stage"], "pair": spec["id"], "title": spec["title"],
			"puzzle": def.to_dict(), "metrics": metrics})
	if dry or errors > 0:
		return errors
	var data := {"format": "ce-mechlab", "v": 1, "mechanic": "magnet", "assist": {"undo": 3, "show_a_move": 1, "hammer": 0}, "boards": out}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()
	print("wrote " + OUT_PATH)
	return 0


static func _model(map: Array) -> BoardModel:
	var level := LevelManager.parse_level({"name": "magnet", "map": map})
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	return m


static func _label(m: BoardModel, id: int) -> String:
	var b: BlockData = m.blocks[id]
	return "%s%s%s(%d,%d)" % [b.color.left(1).to_upper(), ["^", "v", "<", ">"][b.direction], "*" if b.magnet else ("@" if b.is_spinner() else ""), b.cell.x, b.cell.y]


static func evaluate(map: Array) -> Dictionary:
	var problems := []
	var m := _model(map)
	var level := LevelManager.parse_level({"name": "magnet", "map": map})
	var magnets := m.blocks.values().filter(func(b): return b.magnet)
	if magnets.is_empty():
		problems.append("no magnet")
	for b in magnets:
		if m.pull_target(b.id).is_empty():
			problems.append("magnet at %s starts with nothing to pull" % b.cell)
	var s := Solver.from_model(m)
	var sol := s.solve()
	if sol.is_empty():
		problems.append("not solvable")
	# The pull is needed: with every magnet a plain arrow there is no solution.
	var plain := []
	for b in level.blocks:
		var d: BlockData = b.duplicate_data()
		d.magnet = false
		plain.append(d)
	if Solver.new(level.rows, level.columns, plain).is_solvable():
		problems.append("solvable without magnets")
	# Model and Solver agree: the Solver's solution replays through BoardModel.
	var r := _model(map)
	var pulls_in_solution := 0
	for id in sol:
		if r.move_state(id) != "ok":
			problems.append("solution move %d not legal in BoardModel" % id)
			break
		r.remove(id)
		if not r.last_pull.is_empty():
			pulls_in_solution += 1
	if not sol.is_empty() and not r.is_empty():
		problems.append("solution does not clear the board in BoardModel")
	# Exact search of every reachable state.
	var stats := _explore(m, {})
	var first := []
	for id in m.blocks.keys():
		if m.move_state(id) != "ok":
			continue
		var snap := m.snapshot()
		var name := _label(m, id)
		m.remove(id)
		var ok := m.is_empty() or Solver.from_model(m).is_solvable()
		m.restore(snap)
		first.append(name + ("" if ok else " LOSES"))
	return {"blocks": m.block_count(), "magnets": magnets.size(), "spinners": m.blocks.values().filter(func(b): return b.is_spinner()).size(),
		"min_moves": sol.size(), "pulls": pulls_in_solution, "states": stats["states"], "dead_states": stats["dead"],
		"random_win": snappedf(Solver.from_model(m).random_win_rate(1000, 11), 0.001), "first_moves": first, "problems": problems}


## Every reachable state once: counts states and dead ends (no legal move
## left with blocks still on the board, or no way to clear it from here).
static func _explore(m: BoardModel, seen: Dictionary) -> Dictionary:
	var out := {"states": 0, "dead": 0}
	_visit(m, seen, out)
	return out


static func _visit(m: BoardModel, seen: Dictionary, out: Dictionary) -> bool:
	var k := _key(m)
	if seen.has(k):
		return seen[k]
	out["states"] += 1
	if m.is_empty():
		seen[k] = true
		return true
	var any := false
	for id in m.blocks.keys():
		if m.move_state(id) != "ok":
			continue
		var snap := m.snapshot()
		m.remove(id)
		if _visit(m, seen, out):
			any = true
		m.restore(snap)
	seen[k] = any
	if not any:
		out["dead"] += 1
	return any


static func _key(m: BoardModel) -> String:
	var parts := []
	var ids := m.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d,%d,%d,%d" % [id, b.cell.x, b.cell.y, b.direction, b.spin_step])
	return "|".join(parts)


static func describe(m: Dictionary) -> String:
	return "%d blocks (%d magnet, %d spinner), min %d moves, %d pulls, %d states (%d dead), random win %.3f, first moves: %s" % [
		m["blocks"], m["magnets"], m["spinners"], m["min_moves"], m["pulls"], m["states"], m["dead_states"], m["random_win"], ", ".join(m["first_moves"])]
