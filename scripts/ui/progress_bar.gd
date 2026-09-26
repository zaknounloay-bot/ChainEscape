class_name BoardProgress
extends Control
## Thin rounded bar showing how much of the board has been cleared.

var value: float = 0.0:
	set(v):
		value = v
		queue_redraw()
var _tween: Tween


func set_progress(target: float, animate: bool = true) -> void:
	if _tween:
		_tween.kill()
	if not animate:
		value = target
		return
	_tween = create_tween()
	_tween.tween_property(self, "value", target, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var h := size.y
	var track := StyleBoxFlat.new()
	track.bg_color = Palette.SLOT
	track.set_corner_radius_all(int(h * 0.5))
	track.anti_aliasing = true
	track.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
	if value > 0.001:
		var fill := track.duplicate() as StyleBoxFlat
		fill.bg_color = Palette.ACCENT
		fill.draw(get_canvas_item(), Rect2(Vector2.ZERO, Vector2(maxf(h, size.x * value), h)))
