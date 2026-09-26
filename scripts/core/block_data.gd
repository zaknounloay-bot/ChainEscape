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


func _init(p_id: int, p_cell: Vector2i, p_color: String, p_direction: int, p_kind: int = Kind.NORMAL) -> void:
	id = p_id
	cell = p_cell
	color = p_color
	direction = p_direction
	kind = p_kind


func is_spinner() -> bool:
	return kind == Kind.SPINNER


func duplicate_data() -> BlockData:
	return BlockData.new(id, cell, color, direction, kind)
