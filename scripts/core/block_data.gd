class_name BlockData
extends RefCounted
## Plain data for one block on the board. No visuals, no nodes.

## NORMAL blocks keep their arrow. SPINNER blocks turn 90 degrees clockwise
## every time an orthogonally adjacent block escapes.
enum Kind { NORMAL, SPINNER }

var id: int
var cell: Vector2i  # x = column, y = row
var color: String
var direction: int  # Direction enum
var kind: int = Kind.NORMAL
## Locked block: cannot escape while any block of this color is still on
## the board ("" = not locked). The lock state itself is derived from the
## board (see BoardModel.is_locked), so Undo re-locks automatically.
var lock_color: String = ""
## Mystery: arrow is hidden. A hidden block cannot escape; it is revealed
## when an orthogonally adjacent block escapes.
var hidden: bool = false


func _init(p_id: int, p_cell: Vector2i, p_color: String, p_direction: int, p_kind: int = Kind.NORMAL) -> void:
	id = p_id
	cell = p_cell
	color = p_color
	direction = p_direction
	kind = p_kind


func is_spinner() -> bool:
	return kind == Kind.SPINNER


func is_lockable() -> bool:
	return lock_color != ""


func duplicate_data() -> BlockData:
	var b := BlockData.new(id, cell, color, direction, kind)
	b.lock_color = lock_color
	b.hidden = hidden
	return b
