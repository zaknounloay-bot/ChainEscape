class_name WorldBackground
extends CanvasLayer
## Full-screen ambient background: a vertical gradient plus slow, low-alpha
## decorative shapes that depend on the World. Sits behind everything and
## cross-fades smoothly when the World changes.

const SHAPES := 16

var theme: Dictionary = Worlds.THEMES[0]
var _top := Color.WHITE
var _bottom := Color.WHITE
var _deco_color := Color.WHITE
var _deco_alpha := 1.0
var _canvas: Control
var _tween: Tween
var _time := 0.0
var _seeds: Array = []


func _ready() -> void:
	layer = -10
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_bg)
	add_child(_canvas)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in SHAPES:
		_seeds.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4), rng.randf() * TAU))
	apply_theme(theme, false)


const FADE_TIME := 1.2

## Switches to a theme; `animate` cross-fades colors over ~1.2 s. Every call
## re-targets from whatever is on screen right now, and a settle guard snaps
## to the exact target afterwards, so an interrupted or skipped fade can
## never leave the previous World's colors behind.
func apply_theme(t: Dictionary, animate: bool = true) -> void:
	var same: bool = t["id"] == theme["id"] and is_settled()
	theme = t
	if _tween:
		_tween.kill()
	if not animate or same:
		_snap()
		return
	var from_top := _top
	var from_bottom := _bottom
	_tween = create_tween()
	# Fade decoration out, swap, fade in; blend gradient meanwhile.
	_tween.tween_method(func(k: float):
		_top = from_top.lerp(t["bg_top"], k)
		_bottom = from_bottom.lerp(t["bg_bottom"], k)
		_deco_alpha = absf(1.0 - 2.0 * k)
		if k >= 0.5:
			_deco_color = t["deco_color"]
		_canvas.queue_redraw(), 0.0, 1.0, FADE_TIME).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_snap)
	# Guard: even if this tween is killed or stalls, land on the target.
	var target_id: int = t["id"]
	get_tree().create_timer(FADE_TIME + 0.3).timeout.connect(func():
		if theme["id"] == target_id and not is_settled():
			_snap())


## Exactly the target theme on screen (no leftovers from the previous one).
func _snap() -> void:
	_top = theme["bg_top"]
	_bottom = theme["bg_bottom"]
	_deco_color = theme["deco_color"]
	_deco_alpha = 1.0
	_canvas.queue_redraw()


## True when the rendered colors are exactly the target theme's.
func is_settled() -> bool:
	return (_top.is_equal_approx(theme["bg_top"]) and _bottom.is_equal_approx(theme["bg_bottom"])
		and _deco_color.is_equal_approx(theme["deco_color"]) and is_equal_approx(_deco_alpha, 1.0))


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


func _draw_bg() -> void:
	var size := _canvas.size
	# Gradient in horizontal bands (cheap, no texture).
	var bands := 48
	for i in bands:
		var y0 := size.y * i / bands
		var c := _top.lerp(_bottom, float(i) / (bands - 1))
		_canvas.draw_rect(Rect2(0, y0, size.x, size.y / bands + 1.0), c)
	var kind: String = theme["deco"]
	var base_a := 0.16 if theme["dark"] else 0.22
	for i in SHAPES:
		var s: Vector4 = _seeds[i]
		var drift := Vector2(sin(_time * 0.12 * s.z + s.w), cos(_time * 0.09 * s.z + s.w)) * 24.0
		var p := Vector2(s.x * size.x, s.y * size.y) + drift
		var r := 20.0 + 46.0 * s.z
		var col := Color(_deco_color, base_a * _deco_alpha * (0.6 + 0.4 * sin(_time * 0.5 + s.w)))
		match kind:
			"bubbles":
				_canvas.draw_circle(p, r, col)
			"waves":
				_canvas.draw_arc(p, r, PI * 1.1, PI * 1.9, 18, col, 6.0, true)
				_canvas.draw_arc(p + Vector2(r * 0.9, 0), r, PI * 0.1, PI * 0.9, 18, col, 6.0, true)
			"triangles":
				var a := _time * 0.1 * s.z + s.w
				_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(a) * r,
					p + Vector2.from_angle(a + TAU / 3) * r, p + Vector2.from_angle(a + 2 * TAU / 3) * r]), col)
			"neon":
				var a2 := s.w + _time * 0.05
				var d := Vector2.from_angle(a2) * r * 1.4
				_canvas.draw_line(p - d, p + d, Color(col, col.a * 1.6), 3.0, true)
				_canvas.draw_rect(Rect2(p - Vector2(r, r) * 0.25, Vector2(r, r) * 0.5), Color(col, col.a * 0.8), false, 2.0)
			"stars":
				Shapes.draw_star(_canvas, p, r * 0.35, Color(col, col.a * 1.5))
			"rays":
				var c0 := Vector2(size.x * 0.5, size.y * 0.42)
				var ang := TAU * i / SHAPES + _time * 0.03
				var p1 := c0 + Vector2.from_angle(ang - 0.05) * size.y
				var p2 := c0 + Vector2.from_angle(ang + 0.05) * size.y
				_canvas.draw_colored_polygon(PackedVector2Array([c0, p1, p2]), Color(col, 0.05 * _deco_alpha))
