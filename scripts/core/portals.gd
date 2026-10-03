class_name Portals
extends RefCounted
## PORTAL MECHANIC PROTOTYPE (development only, ?mechlab=1). No campaign
## level, Social board or backend record contains a portal: on every such
## board the portal data is empty and none of this code changes anything.
##
## A portal pair is two board cells with the same group letter (map token
## "OA" / "OB"). Portals are static board data, never blocks: they can't be
## tapped or smashed, don't count toward clearing the board, and nothing
## stands on them. Rule: a lane that reaches a portal continues from its
## partner, in the same direction. Portals have no orientation.
##
## Loops: with the direction fixed, a lane that enters the same portal twice
## would repeat forever. The engine treats such a lane as blocked (and stops
## after a step limit no matter what); the level parser rejects any portal
## layout where an empty board would allow such a loop, so a valid board
## can never produce one.

const GROUPS := ["A", "B", "C", "D"]
const TOKEN_PREFIX := "O"


## {cell: group} -> {cell: partner cell}. Only complete pairs are included.
static func pairs(groups: Dictionary) -> Dictionary:
	var by_group := {}
	for cell in groups:
		var g: String = groups[cell]
		if not by_group.has(g):
			by_group[g] = []
		by_group[g].append(cell)
	var out := {}
	for g in by_group:
		var cells: Array = by_group[g]
		if cells.size() == 2:
			out[cells[0]] = cells[1]
			out[cells[1]] = cells[0]
	return out


## Upper bound on cells a lane can visit on a valid board (every cell at
## most once per portal entry) - the engine's safety stop.
static func step_limit(rows: int, columns: int, pair_map: Dictionary) -> int:
	return (rows + columns) * (pair_map.size() + 1) + 4


## Walks a lane from `start` (exclusive) in direction `dir`, following
## portals. `occupied(cell) -> bool` says whether a block stands there.
## Returns {"cell": Vector2i of the first occupied cell or (-1, -1),
## "loop": bool, "via": [[entry, exit], ...] portals passed (in order)}.
static func walk(rows: int, columns: int, pair_map: Dictionary, start: Vector2i, dir: int, occupied: Callable) -> Dictionary:
	var step := Direction.step(dir)
	var cell := start + step
	var via := []
	var entered := {}
	var limit := step_limit(rows, columns, pair_map)
	var steps := 0
	while cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows:
		steps += 1
		if steps > limit:
			return {"cell": Vector2i(-1, -1), "loop": true, "via": via}
		if cell == start:
			# Back where it started: only possible on a looping layout.
			return {"cell": Vector2i(-1, -1), "loop": true, "via": via}
		if pair_map.has(cell):
			if entered.has(cell):
				return {"cell": Vector2i(-1, -1), "loop": true, "via": via}
			entered[cell] = true
			var exit: Vector2i = pair_map[cell]
			via.append([cell, exit])
			cell = exit + step
			continue
		if occupied.call(cell):
			return {"cell": cell, "loop": false, "via": via}
		cell += step
	return {"cell": Vector2i(-1, -1), "loop": false, "via": via}


## Problems with a portal layout (empty = valid): a group without exactly
## two cells, or a lane that could loop: every lane a block could have (any
## non-portal cell, any direction) is walked on the empty board.
static func layout_errors(rows: int, columns: int, groups: Dictionary) -> Array:
	var errors := []
	var count := {}
	for cell in groups:
		var g: String = groups[cell]
		count[g] = count.get(g, 0) + 1
		if not GROUPS.has(g):
			errors.append("portal %s at %s: unknown group" % [g, cell])
		if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
			errors.append("portal %s at %s: outside the board" % [g, cell])
	for g in count:
		if count[g] != 2:
			errors.append("portal %s: %d cell(s), a pair needs exactly 2" % [g, count[g]])
	if not errors.is_empty():
		return errors
	var pair_map := pairs(groups)
	var never := func(_c: Vector2i) -> bool: return false
	for y in rows:
		for x in columns:
			var start := Vector2i(x, y)
			if pair_map.has(start):
				continue
			for d in 4:
				var r: Dictionary = walk(rows, columns, pair_map, start, d, never)
				if r["loop"]:
					errors.append("portals: a lane from %s moving %s would loop" % [start, Direction.NAMES[d]])
					return errors
	return errors
