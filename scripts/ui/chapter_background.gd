class_name ChapterBackground
extends CanvasLayer
## Full-screen ambient background: a vertical gradient, slow low-alpha
## decorative shapes and a light particle layer, all chosen by the Chapter
## theme (data/chapters.json). Sits behind everything and cross-fades
## smoothly when the Chapter changes.
##
## Everything here is deliberately faint (alpha 0.05-0.3): the board and the
## arrows must always be the clearest thing on screen.

const SHAPES := 16
const PARTICLES := 26
const FADE_TIME := 1.2

var theme: Dictionary = Chapters.theme_for_chapter(1)
var _top := Color.WHITE
var _bottom := Color.WHITE
var _deco_color := Color.WHITE
var _particle_color := Color.WHITE
var _deco_alpha := 1.0
var _canvas: Control
var _tween: Tween
var _time := 0.0
var _seeds: Array = []
var _motes: Array = []


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
	for i in PARTICLES:
		_motes.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.5, 1.5), rng.randf() * TAU))
	apply_theme(theme, false)


## Switches to a theme; `animate` cross-fades colors over ~1.2 s. Every call
## re-targets from whatever is on screen right now, and a settle guard snaps
## to the exact target afterwards, so an interrupted or skipped fade can
## never leave the previous Chapter's colors behind.
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
			_particle_color = t["particle_color"]
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
	_particle_color = theme["particle_color"]
	_deco_alpha = 1.0
	_canvas.queue_redraw()


## True when the rendered colors are exactly the target theme's.
func is_settled() -> bool:
	return (_top.is_equal_approx(theme["bg_top"]) and _bottom.is_equal_approx(theme["bg_bottom"])
		and _deco_color.is_equal_approx(theme["deco_color"]) and _particle_color.is_equal_approx(theme["particle_color"])
		and is_equal_approx(_deco_alpha, 1.0))


func _process(delta: float) -> void:
	_time += delta
	_canvas.queue_redraw()


func _draw_bg() -> void:
	var size := _canvas.size
	# Vertical gradient as ONE polygon with per-vertex colors (the GPU
	# interpolates): one draw call per frame instead of dozens of bands.
	_canvas.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
		PackedColorArray([_top, _top, _bottom, _bottom]))
	_draw_deco(size)
	_draw_particles(size)


func _draw_deco(size: Vector2) -> void:
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
			"confetti":
				# Soft rounded confetti chips, slowly tumbling.
				var a := _time * 0.25 * s.z + s.w
				var ax := Vector2.from_angle(a) * r * 0.45
				var ay := Vector2.from_angle(a + PI * 0.5) * r * 0.18
				_canvas.draw_colored_polygon(PackedVector2Array([p - ax - ay, p + ax - ay, p + ax + ay, p - ax + ay]), col)
			"waves":
				_canvas.draw_arc(p, r, PI * 1.1, PI * 1.9, 18, col, 6.0, true)
				_canvas.draw_arc(p + Vector2(r * 0.9, 0), r, PI * 0.1, PI * 0.9, 18, col, 6.0, true)
			"triangles":
				var a := _time * 0.1 * s.z + s.w
				_canvas.draw_colored_polygon(PackedVector2Array([p + Vector2.from_angle(a) * r,
					p + Vector2.from_angle(a + TAU / 3) * r, p + Vector2.from_angle(a + 2 * TAU / 3) * r]), col)
			"grid":
				# Diamond nodes joined by faint lines: a tactical map.
				var q := Vector2(roundf(p.x / 90.0) * 90.0, roundf(p.y / 90.0) * 90.0)
				var d := r * 0.28
				_canvas.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -d), q + Vector2(d, 0), q + Vector2(0, d), q + Vector2(-d, 0)]), Color(col, col.a * 1.3))
				_canvas.draw_line(q, q + Vector2(90.0 * (1 + i % 3), 0), Color(col, col.a * 0.6), 2.0, true)
				_canvas.draw_line(q, q + Vector2(0, 90.0 * (1 + i % 2)), Color(col, col.a * 0.6), 2.0, true)
			"rings":
				for k in 3:
					_canvas.draw_arc(p, r * (0.4 + 0.3 * k), 0.0, TAU, 32, Color(col, col.a * (1.0 - 0.28 * k)), 3.0, true)
			"neon":
				var a2 := s.w + _time * 0.05
				var d2 := Vector2.from_angle(a2) * r * 1.4
				_canvas.draw_line(p - d2, p + d2, Color(col, col.a * 1.6), 3.0, true)
				_canvas.draw_rect(Rect2(p - Vector2(r, r) * 0.25, Vector2(r, r) * 0.5), Color(col, col.a * 0.8), false, 2.0)
			"circuit":
				# Right-angle traces ending in a node, like a circuit board.
				var q2 := Vector2(roundf(p.x / 60.0) * 60.0, roundf(p.y / 60.0) * 60.0)
				var l1 := Vector2(r * 1.6 * (1 if i % 2 == 0 else -1), 0)
				var l2 := Vector2(0, r * 1.2 * (1 if i % 3 == 0 else -1))
				_canvas.draw_polyline(PackedVector2Array([q2, q2 + l1, q2 + l1 + l2]), Color(col, col.a * 1.3), 3.0, true)
				_canvas.draw_circle(q2 + l1 + l2, 6.0, Color(col, col.a * 1.8))
				_canvas.draw_arc(q2, 7.0, 0.0, TAU, 12, Color(col, col.a * 1.8), 2.0, true)
			"aurora":
				# Long, slow translucent ribbons across the sky.
				if i < 5:
					var pts := PackedVector2Array()
					var y0 := size.y * (0.12 + 0.16 * i)
					for k in 13:
						var x := size.x * k / 12.0
						pts.append(Vector2(x, y0 + sin(x * 0.006 + _time * 0.2 * s.z + s.w) * 60.0))
					_canvas.draw_polyline(pts, Color(col, col.a * 0.9), 26.0 + 20.0 * s.z, true)
			"stars":
				Shapes.draw_star(_canvas, p, r * 0.35, Color(col, col.a * 1.5))
			"rays":
				var c0 := Vector2(size.x * 0.5, size.y * 0.42)
				var ang := TAU * i / SHAPES + _time * 0.03
				var p1 := c0 + Vector2.from_angle(ang - 0.05) * size.y
				var p2 := c0 + Vector2.from_angle(ang + 0.05) * size.y
				_canvas.draw_colored_polygon(PackedVector2Array([c0, p1, p2]), Color(col, 0.05 * _deco_alpha))


## Subtle particles that make each Chapter feel alive (rising embers,
## falling snow, twinkling glints ...). Positions are pure functions of time.
func _draw_particles(size: Vector2) -> void:
	var kind: String = theme.get("particles", "none")
	if kind == "none":
		return
	var peak := 0.26 if theme["dark"] else 0.34
	for i in PARTICLES:
		var s: Vector4 = _motes[i]
		var t := _time * 0.03 * s.z + s.x
		var x := s.y * size.x + sin(_time * 0.4 * s.z + s.w) * 18.0
		var a := peak * _deco_alpha
		var col := Color(_particle_color, a)
		match kind:
			"motes", "dust":
				var y := fposmod(s.x * size.y - _time * 8.0 * s.z, size.y)
				_canvas.draw_circle(Vector2(x, y), 2.0 + 2.0 * s.z, Color(col, a * (0.5 + 0.5 * sin(_time + s.w))))
			"petals":
				var y := fposmod(t * size.y, size.y)
				var rot := _time * 0.8 * s.z + s.w
				var ax := Vector2.from_angle(rot) * 7.0
				var ay := Vector2.from_angle(rot + PI * 0.5) * 3.5
				var c := Vector2(x, y)
				_canvas.draw_colored_polygon(PackedVector2Array([c - ax, c - ay, c + ax, c + ay]), col)
			"bubbles":
				var y := size.y - fposmod(t * size.y * 1.4, size.y)
				_canvas.draw_arc(Vector2(x, y), 4.0 + 5.0 * s.z, 0.0, TAU, 14, col, 1.6, true)
			"embers", "pulses":
				var life := fposmod(t * 2.0, 1.0)
				var y := size.y * (1.05 - life * 0.9)
				_canvas.draw_circle(Vector2(x, y), 2.0 + 2.5 * s.z * (1.0 - life), Color(col, a * (1.0 - life)))
			"glints", "gold_dust":
				var tw := maxf(0.0, sin(_time * 1.3 * s.z + s.w * 3.0))
				var p := Vector2(s.y * size.x, s.x * size.y)
				if kind == "gold_dust":
					p.y = fposmod(s.x * size.y - _time * 6.0 * s.z, size.y)
				var r := (3.0 + 4.0 * s.z) * tw
				_canvas.draw_line(p - Vector2(r, 0), p + Vector2(r, 0), Color(col, a * tw), 1.6, true)
				_canvas.draw_line(p - Vector2(0, r), p + Vector2(0, r), Color(col, a * tw), 1.6, true)
				_canvas.draw_circle(p, 1.5, Color(col, a * tw))
			"sparks":
				var life := fposmod(t * 3.0, 1.0)
				var p := Vector2(x, size.y * s.x) + Vector2.from_angle(s.w) * life * 90.0
				var v := Vector2.from_angle(s.w) * 8.0
				_canvas.draw_line(p, p + v, Color(col, a * (1.0 - life)), 2.0, true)
			"snow":
				var y := fposmod(t * size.y, size.y)
				_canvas.draw_circle(Vector2(x, y), 1.5 + 2.0 * s.z, Color(col, a * 0.8))
