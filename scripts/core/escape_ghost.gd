class_name EscapeGhost
extends Node2D
## A rounded outline that expands and fades where a block used to be.
## Marks "this cell is now free" and gives each escape a crisp accent.

var size: float = 80.0
var color: Color = Color.WHITE
var strength: float = 1.0  # grows a little with the chain
var _t: float = 0.0
var _style := StyleBoxFlat.new()


func _ready() -> void:
	_style.draw_center = false
	_style.anti_aliasing = true
	_style.set_corner_radius_all(int(size * 0.22))
	var t := create_tween()
	t.tween_property(self, "_t", 1.0, 0.32 + 0.04 * strength).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.finished.connect(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var s := size * (0.9 + 0.35 * _t * strength)
	_style.border_color = Color(color, 0.7 * (1.0 - _t))
	_style.set_border_width_all(maxi(1, int(size * 0.06 * (1.0 - _t) + 1.0)))
	_style.draw(get_canvas_item(), Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)))
