class_name BoardModel
extends RefCounted
## Pure game rules for a Chain Escape board.
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


func setup(p_rows: int, p_columns: int, p_blocks: Array) -> void:
	rows = p_rows
	columns = p_columns
	blocks.clear()
	_occupancy.clear()
	for b in p_blocks:
		_add(b.duplicate_data())


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func block_at(cell: Vector2i) -> BlockData:
	var id = _occupancy.get(cell, -1)
	return blocks.get(id) if id != -1 else null


func is_empty() -> bool:
	return blocks.is_empty()


func block_count() -> int:
	return blocks.size()


## Returns the first block standing between `id` and the board edge,
## or null if the path is clear.
func find_blocker(id: int) -> BlockData:
	var b: BlockData = blocks[id]
	var step := Direction.step(b.direction)
	var cell := b.cell + step
	while is_inside(cell):
		var other := block_at(cell)
		if other != null:
			return other
		cell += step
	return null


func can_escape(id: int) -> bool:
	return blocks.has(id) and find_blocker(id) == null


## Removes the block from the board. Caller must check can_escape first.
func remove(id: int) -> void:
	var b: BlockData = blocks.get(id)
	if b == null:
		return
	_occupancy.erase(b.cell)
	blocks.erase(id)


## Ids of every block that could escape right now.
func free_block_ids() -> Array:
	var result := []
	for id in blocks:
		if find_blocker(id) == null:
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
