class_name EscapeGhost
extends Node2D
## A rounded outline that expands and fades where a block used to be.
## Marks "this cell is now free" and gives each escape a crisp accent.
##
## Drawn once; the tween only scales and fades the node (a per-frame redraw
## would create new GPU buffers every frame on Web).

var size: float = 80.0
var color: Color = Color.WHITE
var strength: float = 1.0  # grows a little with the chain
var _style := StyleBoxFlat.new()


func _ready() -> void:
	_style.draw_center = false
	_style.anti_aliasing = true
	_style.set_corner_radius_all(int(size * 0.22))
	_style.border_color = Color(color, 0.7)
	_style.set_border_width_all(maxi(1, int(size * 0.06 + 1.0)))
	var d := 0.32 + 0.04 * strength
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * (1.0 + 0.35 * strength / 0.9), d).from(Vector2.ONE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 0.0, d).from(1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.finished.connect(queue_free)


func _draw() -> void:
	var s := size * 0.9
	_style.draw(get_canvas_item(), Rect2(Vector2(-s, -s) * 0.5, Vector2(s, s)))
