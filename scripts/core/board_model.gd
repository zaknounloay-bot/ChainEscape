class_name BoardModel
extends RefCounted
## Pure game rules for a Chain Escape board.
##
## A block may escape when every cell between it and the board edge (in its
## arrow direction) is empty. When a block escapes, adjacent SPINNER blocks
## turn clockwise, which is what makes move order matter.
##
## v0.3 adds two conditions on top of "lane is clear":
##   * LOCKED blocks stay put while any block of their key color remains.
##   * HIDDEN (mystery) blocks stay put until an adjacent block escapes,
##     which reveals their arrow.
##
## v0.6 (Second Era) adds three more, all visible and deterministic:
##   * SWITCH blocks: when one escapes, every block linked to its group
##     reverses its arrow.
##   * CHAIN GATES: solid slabs that block lanes and can't be tapped; a gate
##     opens (is removed) the moment every block linked to it has escaped.
##   * ARMORED blocks: can't escape while shelled. Tapping a block whose lane
##     runs straight into a shelled block RAMS it: the tapped block stays,
##     the shell breaks. A ram is a legal move, never a mistake.
##
## Knows nothing about nodes, tweens or screens, which keeps it trivially
## testable (see tools/verify_levels.gd) and lets the undo system work on
## plain snapshots.

var rows: int = 0
var columns: int = 0

## id -> BlockData for every block still on the board.
var blocks: Dictionary = {}

## Vector2i cell -> block id. Kept in sync with `blocks` for O(1) lookups.
var _occupancy: Dictionary = {}
## color -> number of blocks of that color on the board (for locks).
var _color_count: Dictionary = {}
## Filled by remove(): blocks whose arrow was revealed / lock opened.
var last_revealed: Array = []
var last_unlocked: Array = []
## v0.6, filled by remove(): arrows reversed by a switch, gates opened
## ({"id", "cell", "group"}).
var last_flipped: Array = []
var last_opened_gates: Array = []
## PORTAL (levels 201+, see Portals): static board data,
## Vector2i cell -> pair letter, and cell -> partner cell. Empty on every
## campaign and Social board, where every rule below is unchanged. setup()
## and restore() leave them alone (they never change during play).
var portal_groups: Dictionary = {}
var portals: Dictionary = {}
## MOVABLE (levels 251+, see BlockData.Kind.CRATE): crates on
## the board. They are blocks (lanes stop at them, snapshots / Undo carry
## their cells) but never escape: the board is clear when only crates are
## left. 0 on every campaign and Social board.
var _crates: int = 0
## Filled by push(): {"crate", "from", "to", "dir", "via", "advanced",
## "turned"} of the last successful push.
var last_push: Dictionary = {}


func setup(p_rows: int, p_columns: int, p_blocks: Array) -> void:
	rows = p_rows
	columns = p_columns
	blocks.clear()
	_occupancy.clear()
	_color_count.clear()
	_crates = 0
	for b in p_blocks:
		_add(b.duplicate_data())


## Portal: sets this board's portal pairs ({cell: letter}).
func set_portals(groups: Dictionary) -> void:
	portal_groups = groups.duplicate()
	portals = Portals.pairs(portal_groups)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func block_at(cell: Vector2i) -> BlockData:
	var id = _occupancy.get(cell, -1)
	return blocks.get(id) if id != -1 else null


## Clear: no blocks left (Movable: or only crates).
func is_empty() -> bool:
	return blocks.is_empty() or (_crates > 0 and blocks.size() == _crates)


## Blocks that still have to leave (crates never count).
func block_count() -> int:
	return blocks.size() - _crates


## Returns the first block standing between `id` and the board edge,
## or null if the path is clear.
func find_blocker(id: int) -> BlockData:
	var b: BlockData = blocks[id]
	if not portals.is_empty():
		return lane(id)["blocker"]
	var step := Direction.step(b.direction)
	var cell := b.cell + step
	while is_inside(cell):
		var other := block_at(cell)
		if other != null:
			return other
		cell += step
	return null


## Portal: `id`'s whole lane. {"blocker": first block in it (or
## null), "loop": true if the lane could never reach the edge (malformed
## layout only), "via": [[entry, exit], ...] portals it passes, in order}.
## Without portals: the straight lane (via is empty, loop false).
func lane(id: int) -> Dictionary:
	var b: BlockData = blocks.get(id)
	if b == null:
		return {"blocker": null, "loop": false, "via": []}
	var r := Portals.walk(rows, columns, portals, b.cell, b.direction, func(c: Vector2i) -> bool: return _occupancy.has(c))
	var cell: Vector2i = r["cell"]
	return {"blocker": block_at(cell) if cell.x >= 0 else null, "loop": r["loop"], "via": r["via"]}


func can_escape(id: int) -> bool:
	return move_state(id) == "ok"


## Why a block can or cannot leave: "ok", "hidden", "locked", "blocked",
## and (v0.6) "gate" (a Chain Gate, never tappable), "armored" (its shell
## is intact) or "ram" (its lane runs straight into a shelled block:
## tapping it cracks that shell).
func move_state(id: int) -> String:
	var b: BlockData = blocks.get(id)
	if b == null:
		return "blocked"
	if b.is_gate():
		return "gate"
	if b.kind == BlockData.Kind.CRATE:
		return "crate"
	if b.hidden:
		return "hidden"
	if is_locked(id):
		return "locked"
	if b.armored:
		return "armored"
	var blocker := find_blocker(id)
	if blocker == null:
		if not portals.is_empty() and lane(id)["loop"]:
			return "blocked"
		# Sequence: a first-stage block with a clear lane advances
		# instead of escaping.
		return "advance" if b.seq_stage == 1 else "ok"
	if blocker.kind == BlockData.Kind.CRATE:
		# Movable: launched into a crate - a push if the crate
		# can move one cell, else an ordinary blocked tap.
		return "push" if push_target(id)["cell"].x >= 0 else "blocked"
	return "ram" if blocker.armored else "blocked"


## A tap that does something: an escape or a ram.
func is_playable(id: int) -> bool:
	var st := move_state(id)
	return st == "ok" or st == "ram" or st == "advance" or st == "push"


## Ram: `id` is launched into the shelled block in its lane, which loses its
## shell. `id` stays where it is. Returns the rammed block's id (-1 if the
## move was not a ram).
func ram(id: int) -> int:
	if move_state(id) != "ram":
		return -1
	var target := find_blocker(id)
	target.armored = false
	return target.id


## Blocks still linked to the Chain Gate group (the gate's counter).
func gate_remaining(group: String) -> int:
	var n := 0
	for b in blocks.values():
		if b.gate_link == group:
			n += 1
	return n


func is_locked(id: int) -> bool:
	var b: BlockData = blocks.get(id)
	return b != null and b.lock_color != "" and _color_count.get(b.lock_color, 0) > 0


## Blocks that must leave before `id` unlocks.
func key_blocks(id: int) -> Array:
	var b: BlockData = blocks.get(id)
	var out := []
	if b and b.lock_color != "":
		for other in blocks.values():
			if other.color == b.lock_color:
				out.append(other.id)
	return out


func count_of_color(color: String) -> int:
	return _color_count.get(color, 0)


## Removes the block from the board. Caller must check can_escape first.
## Spinners orthogonally adjacent to the removed block turn (by their rule).
## Returns the ids of the spinners that turned (for animation).
func remove(id: int) -> Array:
	var b: BlockData = blocks.get(id)
	if b == null:
		return []
	var was_locked := []
	for other in blocks.values():
		if other.lock_color == b.color and is_locked(other.id):
			was_locked.append(other.id)
	_occupancy.erase(b.cell)
	blocks.erase(id)
	_color_count[b.color] = _color_count.get(b.color, 1) - 1
	if b.kind == BlockData.Kind.CRATE:
		_crates -= 1  # only a Hammer test board removes a crate
	var turned := []
	last_revealed = []
	for step in Direction.STEPS:
		var n := block_at(b.cell + step)
		if n == null:
			continue
		if n.is_spinner():
			n.apply_turn()
			turned.append(n.id)
		if n.hidden:
			n.hidden = false
			last_revealed.append(n.id)
	last_unlocked = was_locked.filter(func(x): return not is_locked(x))
	# v0.6: a switch reverses its linked arrows...
	last_flipped = []
	if b.switch_group != "":
		for other in blocks.values():
			if other.flip_link == b.switch_group:
				other.direction = Direction.opposite(other.direction)
				last_flipped.append(other.id)
	# ...and the last link of a Chain Gate opens it (the gate is removed; it
	# was never "escaped", so it turns and reveals nothing).
	last_opened_gates = []
	if b.gate_link != "" and gate_remaining(b.gate_link) == 0:
		for g in blocks.values().duplicate():
			if g.is_gate() and g.gate_group == b.gate_link:
				last_opened_gates.append({"id": g.id, "cell": g.cell, "group": g.gate_group})
				_occupancy.erase(g.cell)
				blocks.erase(g.id)
				_color_count[g.color] = _color_count.get(g.color, 1) - 1
	return turned


## SEQUENCE: `id`'s first stage (caller checks move_state ==
## "advance"). The block launches along its clear lane and comes back to
## its cell: the same neighbour event as an escape from that cell (adjacent
## spinners turn by their rule, adjacent hidden arrows are revealed), but
## the block stays, so nothing else happens (no lock key, gate link or
## switch: a Sequence block is a plain arrow). Then its NEXT arrow becomes
## its arrow (stage 2). Returns the spinners that turned (last_revealed is
## filled; the other last_* lists are emptied).
func advance(id: int) -> Array:
	var b: BlockData = blocks.get(id)
	if b == null or b.seq_stage != 1:
		return []
	var turned := []
	last_revealed = []
	last_unlocked = []
	last_flipped = []
	last_opened_gates = []
	for step in Direction.STEPS:
		var n := block_at(b.cell + step)
		if n == null:
			continue
		if n.is_spinner():
			n.apply_turn()
			turned.append(n.id)
		if n.hidden:
			n.hidden = false
			last_revealed.append(n.id)
	b.direction = b.seq_next
	b.seq_stage = 2
	return turned


## MOVABLE: where the crate first in `id`'s lane would go if
## `id` were launched into it: exactly one cell in `id`'s direction - and,
## like any lane, through a portal it reaches (out of its partner, same
## direction) - onto an EMPTY board cell. {"cell": Vector2i ((-1, -1) =
## no push possible: no crate first in the lane, or the edge / a block /
## another crate (no chain pushing) / a looping portal is in the way),
## "crate": id or -1, "via": portals the crate passes}.
func push_target(id: int) -> Dictionary:
	var none := {"cell": Vector2i(-1, -1), "crate": -1, "via": []}
	var b: BlockData = blocks.get(id)
	if b == null or _crates == 0:
		return none
	var crate := find_blocker(id)
	if crate == null or crate.kind != BlockData.Kind.CRATE:
		return none
	var step := Direction.step(b.direction)
	var cell := crate.cell + step
	var via := []
	var entered := {}
	while is_inside(cell) and portals.has(cell):
		if entered.has(cell):
			return none  # a looping portal layout
		entered[cell] = true
		via.append([cell, portals[cell]])
		cell = portals[cell] + step
	if not is_inside(cell) or _occupancy.has(cell):
		return none
	return {"cell": cell, "crate": crate.id, "via": via}


## MOVABLE: `id` is launched into the crate in its lane (caller
## checks move_state == "push"); the crate moves one cell (see push_target)
## and `id` stays in its cell. Nothing else happens - like a ram, a push is
## not an escape - except for a first-stage Sequence block: its first stage
## is used, exactly as BoardModel.advance (neighbour event, next arrow).
## Returns last_push.
func push(id: int) -> Dictionary:
	var t := push_target(id)
	last_push = {}
	if t["cell"].x < 0:
		return last_push
	var crate: BlockData = blocks[t["crate"]]
	var from := crate.cell
	_occupancy.erase(from)
	crate.cell = t["cell"]
	_occupancy[crate.cell] = crate.id
	var b: BlockData = blocks[id]
	last_push = {"crate": crate.id, "from": from, "to": crate.cell, "dir": b.direction, "via": t["via"], "advanced": false, "turned": []}
	if b.seq_stage == 1:
		last_push["turned"] = advance(id)
		last_push["advanced"] = true
	return last_push


## True if removing `id` would turn at least one spinner.
func turns_spinners(id: int) -> bool:
	var b: BlockData = blocks.get(id)
	if b == null:
		return false
	for step in Direction.STEPS:
		var n := block_at(b.cell + step)
		if n != null and n.is_spinner():
			return true
	return false


## Ids of every block that could escape right now (legal moves).
func free_block_ids() -> Array:
	var result := []
	for id in blocks:
		if can_escape(id):
			result.append(id)
	return result


## Escapes and rams available right now (v0.6: a ram is a real move).
func playable_ids() -> Array:
	var result := []
	for id in blocks:
		if is_playable(id):
			result.append(id)
	return result


# --- Snapshots (used by History for undo) -------------------------------

func snapshot() -> Array:
	var out := []
	for id in blocks:
		out.append(blocks[id].duplicate_data())
	return out


func restore(snap: Array) -> void:
	setup(rows, columns, snap)


func _add(b: BlockData) -> void:
	if not is_inside(b.cell):
		push_error("Block %d at %s is outside the %dx%d board" % [b.id, b.cell, columns, rows])
		return
	if _occupancy.has(b.cell):
		push_error("Two blocks share cell %s" % b.cell)
		return
	blocks[b.id] = b
	_occupancy[b.cell] = b.id
	_color_count[b.color] = _color_count.get(b.color, 0) + 1
	if b.kind == BlockData.Kind.CRATE:
		_crates += 1
