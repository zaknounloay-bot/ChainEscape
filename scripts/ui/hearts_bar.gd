class_name HeartsBar
extends Control
## Row of hearts (lives). Full hearts are bright, lost ones are soft
## outlines. Losing a heart plays a short pop-and-drop animation.

const HEART_SIZE := 34.0
const GAP := 12.0

var max_hearts: int = 3
## Color of lost-heart outlines (lighter on dark Chapters).
var empty_color: Color = Palette.SLOT
var hearts: int = 3
## Per-heart animation state: scale, y offset, alpha of the "falling" copy.
var _pop := [1.0, 1.0, 1.0]
var _fall := [0.0, 0.0, 0.0]
var _fall_alpha := [0.0, 0.0, 0.0]
var _shake: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(3 * HEART_SIZE + 2 * GAP, HEART_SIZE + 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_hearts(p_max: int, current: int) -> void:
	max_hearts = p_max
	hearts = current
	_pop.resize(max_hearts)
	_pop.fill(1.0)
	_fall.resize(max_hearts)
	_fall.fill(0.0)
	_fall_alpha.resize(max_hearts)
	_fall_alpha.fill(0.0)
	custom_minimum_size.x = max_hearts * HEART_SIZE + (max_hearts - 1) * GAP
	queue_redraw()


## Animates the heart at index `hearts - 1` breaking off.
func lose_heart() -> void:
	if hearts <= 0:
		return
	hearts -= 1
	var i := hearts
	var t := create_tween()
	t.tween_method(func(v): _pop[i] = v; queue_redraw(), 1.0, 1.45, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v): _pop[i] = v; queue_redraw(), 1.45, 1.0, 0.12)
	t.parallel().tween_method(func(v): _shake = v; queue_redraw(), 1.0, 0.0, 0.35)
	# A copy of the heart drops and fades while the slot turns into an outline.
	_fall_alpha[i] = 1.0
	t.parallel().tween_method(func(v): _fall[i] = v; queue_redraw(), 0.0, 40.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_method(func(v): _fall_alpha[i] = v; queue_redraw(), 1.0, 0.0, 0.45)


func _draw() -> void:
	var total := max_hearts * HEART_SIZE + (max_hearts - 1) * GAP
	var x0 := (size.x - total) * 0.5 + HEART_SIZE * 0.5
	for i in max_hearts:
		var c := Vector2(x0 + i * (HEART_SIZE + GAP), size.y * 0.5)
		if i == hearts:
			c.x += sin(_shake * 40.0) * 5.0 * _shake
		var full := i < hearts
		var s: float = HEART_SIZE * _pop[i]
		if full:
			_draw_heart(c + Vector2(0, 2), s, Color(0.5, 0.0, 0.1, 0.18))  # tiny shadow
			_draw_heart(c, s, Palette.HEART)
			_draw_heart(c + Vector2(-s * 0.14, -s * 0.12), s * 0.28, Color(1, 1, 1, 0.45))  # shine
		else:
			_draw_heart(c, s, empty_color)
			if _fall_alpha[i] > 0.0:
				_draw_heart(c + Vector2(0, _fall[i]), s, Color(Palette.HEART, _fall_alpha[i]))


static func heart_points(center: Vector2, size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var k := size / 34.0
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(center + Vector2(x, y + 1.5) * k)
	return pts


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	var pts := heart_points(center, size)
	draw_colored_polygon(pts, color)
	pts.append(pts[0])
	draw_polyline(pts, color, 1.2, true)
