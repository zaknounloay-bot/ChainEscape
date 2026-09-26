class_name StarsRow
extends Control
## Three stars; earned ones pop in one after another.

var star_radius: float = 34.0
var earned: int = 0
var _scales := [1.0, 1.0, 1.0]


func _init(radius: float = 34.0) -> void:
	star_radius = radius
	custom_minimum_size = Vector2(radius * 2.0 * 3 + radius * 0.8 * 2, radius * 2.2)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_stars(n: int, animate: bool) -> void:
	earned = n
	for i in 3:
		_scales[i] = 1.0 if (not animate or i >= n) else 0.0
	queue_redraw()
	if animate:
		var t := create_tween()
		for i in n:
			t.tween_interval(0.12)
			t.tween_method(func(v): _scales[i] = v; queue_redraw(), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_callback(func(): AudioManager.play_star(i))


func _draw() -> void:
	var gap := star_radius * 0.8
	var total := star_radius * 6.0 + gap * 2.0
	var x0 := (size.x - total) * 0.5 + star_radius
	for i in 3:
		var c := Vector2(x0 + i * (star_radius * 2.0 + gap), size.y * 0.5 + (0.0 if i == 1 else star_radius * 0.12))
		var r: float = star_radius * (1.12 if i == 1 else 1.0)
		Shapes.draw_star(self, c, r, Palette.SLOT)
		if i < earned and _scales[i] > 0.01:
			Shapes.draw_star(self, c + Vector2(0, 2), r * _scales[i], Color(0.6, 0.35, 0.0, 0.25))
			Shapes.draw_star(self, c, r * _scales[i], Palette.GOLD, Color(1, 1, 1, 0.9))
