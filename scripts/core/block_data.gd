class_name BlockData
extends RefCounted
## Plain data for one block on the board. No visuals, no nodes.

var id: int
var cell: Vector2i  # x = column, y = row
var color: String
var direction: int  # Direction enum


func _init(p_id: int, p_cell: Vector2i, p_color: String, p_direction: int) -> void:
	id = p_id
	cell = p_cell
	color = p_color
	direction = p_direction


func duplicate_data() -> BlockData:
	return BlockData.new(id, cell, color, direction)
