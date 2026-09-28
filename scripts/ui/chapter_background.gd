class_name ChapterBackground
extends CanvasLayer
## Full-screen ambient background: a vertical gradient, slow low-alpha
## decorative shapes and a light particle layer, all chosen by the Chapter
## theme (data/chapters.json). Sits behind everything and cross-fades
## smoothly when the Chapter changes.
##
## Everything here is deliberately faint (alpha 0.05-0.35): the board and the
## arrows must always be the clearest thing on screen.
##
## v0.5.1 - stability: every shape is a small node whose geometry is drawn
## ONCE (in white); the animation only changes its position / rotation /
## scale / modulate. Redrawing polygons every frame made Godot's Web
## runtime create new WebGL buffers every frame, and Emscripten never
## reuses those ids, so its GL tables grew for the whole session (the
## long-session crash on phones). The gradient is plain rectangles and is
## redrawn only while its colors change.

const SHAPES := 16
const PARTICLES := 26
const FADE_TIME := 1.2
const BANDS := 48

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
var _shapes: Array[Shape] = []
var _particles: Array[Shape] = []
var _drawn_deco := ""
var _drawn_particles := ""
var _drawn_size := Vector2.ZERO


func _ready() -> void:
	layer = -10
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_gradient)
	_canvas.resized.connect(func():
		_canvas.queue_redraw()
		_rebuild_shapes())
	add_child(_canvas)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in SHAPES:
		_seeds.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.6, 1.4), rng.randf() * TAU))
	for i in PARTICLES:
		_motes.append(Vector4(rng.randf(), rng.randf(), rng.randf_range(0.5, 1.5), rng.randf() * TAU))
	for i in SHAPES:
		var s := Shape.new()
		_canvas.add_child(s)
		_shapes.append(s)
	for i in PARTICLES:
		var p := Shape.new()
		_canvas.add_child(p)
		_particles.append(p)
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
			_rebuild_shapes()
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
	_rebuild_shapes()
	_canvas.queue_redraw()


## True when the rendered colors are exactly the target theme's.
func is_settled() -> bool:
	return (_top.is_equal_approx(theme["bg_top"]) and _bottom.is_equal_approx(theme["bg_bottom"])
		and _deco_color.is_equal_approx(theme["deco_color"]) and _particle_color.is_equal_approx(theme["particle_color"])
		and is_equal_approx(_deco_alpha, 1.0) and _drawn_deco == theme["deco"])


## Gradient in horizontal bands: rectangles only (no GL buffers), and only
## redrawn when its colors change.
func _draw_gradient() -> void:
	var size := _canvas.size
	for i in BANDS:
		var y0 := size.y * i / BANDS
		_canvas.draw_rect(Rect2(0, y0, size.x, size.y / BANDS + 1.0), _top.lerp(_bottom, float(i) / (BANDS - 1)))


## (Re)draws each shape's geometry once - only when the decoration kind,
## the particle kind or the screen size changes.
func _rebuild_shapes() -> void:
	if _shapes.is_empty():
		return
	var size := _canvas.size
	var deco: String = theme["deco"]
	var parts: String = theme.get("particles", "none")
	if deco == _drawn_deco and parts == _drawn_particles and size == _drawn_size:
		return
	_drawn_deco = deco
	_drawn_particles = parts
	_drawn_size = size
	for i in SHAPES:
		var s: Vector4 = _seeds[i]
		_shapes[i].setup("deco_" + deco, 20.0 + 46.0 * s.z, s, size, i)
	for i in PARTICLES:
		_particles[i].setup("part_" + parts, 1.0, _motes[i], size, i)


## Per frame: only transforms and colors change - nothing is redrawn.
func _process(delta: float) -> void:
	_time += delta
	var size := _canvas.size
	if size != _drawn_size:
		_rebuild_shapes()
	_animate_deco(size)
	_animate_particles(size)


func _animate_deco(size: Vector2) -> void:
	var kind: String = theme["deco"]
	var base_a := 0.16 if theme["dark"] else 0.22
	for i in SHAPES:
		var node := _shapes[i]
		var s: Vector4 = _seeds[i]
		var drift := Vector2(sin(_time * 0.12 * s.z + s.w), cos(_time * 0.09 * s.z + s.w)) * 24.0
		var p := Vector2(s.x * size.x, s.y * size.y) + drift
		var a := base_a * _deco_alpha * (0.6 + 0.4 * sin(_time * 0.5 + s.w))
		node.visible = true
		node.rotation = 0.0
		match kind:
			"confetti":
				node.rotation = _time * 0.25 * s.z + s.w
			"triangles":
				node.rotation = _time * 0.1 * s.z + s.w
			"neon":
				node.rotation = s.w + _time * 0.05
			"grid":
				p = Vector2(roundf(p.x / 90.0) * 90.0, roundf(p.y / 90.0) * 90.0)
			"circuit":
				p = Vector2(roundf(p.x / 60.0) * 60.0, roundf(p.y / 60.0) * 60.0)
			"aurora":
				# Ribbons travel sideways (the wave is drawn once, wider than the screen).
				node.visible = i < 5
				var wl := TAU / 0.006
				p = Vector2(-fposmod(_time * 0.2 * s.z / 0.006 + s.w / 0.006, wl), size.y * (0.12 + 0.16 * i))
				a *= 0.9
			"rays":
				p = Vector2(size.x * 0.5, size.y * 0.42)
				node.rotation = TAU * i / SHAPES + _time * 0.03
				a = 0.05 * _deco_alpha
			# v0.6 Second Era decorations (rotation / drift / alpha only).
			"hexglass":
				node.rotation = s.w + _time * 0.04 * (1.0 if i % 2 == 0 else -1.0)
				a *= 1.1
			"gears":
				node.rotation = _time * 0.18 * (1.0 if i % 2 == 0 else -1.0) / (0.6 + s.z)
			"plasma":
				node.rotation = _time * 0.35 * s.z + s.w
				a *= 0.8 + 0.4 * sin(_time * 1.6 + s.w)
			"shards":
				node.rotation = s.w + sin(_time * 0.2 + s.w) * 0.4
				p.y += sin(_time * 0.3 + s.w) * 14.0
			"crowns":
				node.rotation = sin(_time * 0.25 + s.w) * 0.12
				a *= 0.9
		node.position = p
		node.modulate = Color(_deco_color, a)


func _animate_particles(size: Vector2) -> void:
	var kind: String = theme.get("particles", "none")
	var peak := 0.26 if theme["dark"] else 0.34
	for i in PARTICLES:
		var node := _particles[i]
		node.visible = kind != "none"
		if kind == "none":
			continue
		var s: Vector4 = _motes[i]
		var t := _time * 0.03 * s.z + s.x
		var x := s.y * size.x + sin(_time * 0.4 * s.z + s.w) * 18.0
		var a := peak * _deco_alpha
		var pos := Vector2(x, 0)
		var sc := 1.0
		node.rotation = 0.0
		match kind:
			"motes", "dust":
				pos.y = fposmod(s.x * size.y - _time * 8.0 * s.z, size.y)
				a *= 0.5 + 0.5 * sin(_time + s.w)
			"petals":
				pos.y = fposmod(t * size.y, size.y)
				node.rotation = _time * 0.8 * s.z + s.w
			"bubbles":
				pos.y = size.y - fposmod(t * size.y * 1.4, size.y)
			"embers", "pulses":
				var life := fposmod(t * 2.0, 1.0)
				pos.y = size.y * (1.05 - life * 0.9)
				sc = maxf(0.05, 1.0 - life * 0.55)
				a *= 1.0 - life
			"glints", "gold_dust":
				var tw := maxf(0.0, sin(_time * 1.3 * s.z + s.w * 3.0))
				pos = Vector2(s.y * size.x, s.x * size.y)
				if kind == "gold_dust":
					pos.y = fposmod(s.x * size.y - _time * 6.0 * s.z, size.y)
				sc = maxf(0.05, tw)
				a *= tw
			"sparks":
				var life := fposmod(t * 3.0, 1.0)
				pos = Vector2(x, size.y * s.x) + Vector2.from_angle(s.w) * life * 90.0
				a *= 1.0 - life
			"snow":
				pos.y = fposmod(t * size.y, size.y)
				a *= 0.8
			"streaks":
				# Neon light streaks rising diagonally.
				var life := fposmod(t * 1.6, 1.0)
				pos = Vector2(fposmod(s.y * size.x + life * 120.0, size.x), size.y * (1.05 - life * 1.1))
				node.rotation = -PI * 0.35
				a *= sin(life * PI)
			"crystals":
				pos.y = fposmod(t * size.y * 0.7, size.y)
				node.rotation = _time * 0.5 * s.z + s.w
				a *= 0.6 + 0.4 * sin(_time * 2.0 + s.w)
		node.position = pos
		node.scale = Vector2(sc, sc)
		node.modulate = Color(_particle_color, a)


## One decoration shape or particle. Its geometry is drawn once, in white,
## around its own origin; the parent animates transform and modulate.
class Shape extends Node2D:
	var kind := ""
	var r := 40.0
	var s := Vector4.ZERO
	var screen := Vector2.ZERO
	var index := 0

	func setup(p_kind: String, p_r: float, p_seed: Vector4, p_screen: Vector2, p_index: int) -> void:
		kind = p_kind
		r = p_r
		s = p_seed
		screen = p_screen
		index = p_index
		queue_redraw()

	func _draw() -> void:
		var w := Color.WHITE
		match kind:
			"deco_bubbles":
				draw_circle(Vector2.ZERO, r, w)
			"deco_confetti":
				var ax := Vector2(r * 0.45, 0)
				var ay := Vector2(0, r * 0.18)
				draw_colored_polygon(PackedVector2Array([-ax - ay, ax - ay, ax + ay, -ax + ay]), w)
			"deco_waves":
				draw_arc(Vector2.ZERO, r, PI * 1.1, PI * 1.9, 18, w, 6.0, true)
				draw_arc(Vector2(r * 0.9, 0), r, PI * 0.1, PI * 0.9, 18, w, 6.0, true)
			"deco_triangles":
				draw_colored_polygon(PackedVector2Array([Vector2.from_angle(0.0) * r,
					Vector2.from_angle(TAU / 3) * r, Vector2.from_angle(2 * TAU / 3) * r]), w)
			"deco_grid":
				var d := r * 0.28
				draw_colored_polygon(PackedVector2Array([Vector2(0, -d), Vector2(d, 0), Vector2(0, d), Vector2(-d, 0)]), Color(w, 1.0))
				draw_line(Vector2.ZERO, Vector2(90.0 * (1 + index % 3), 0), Color(w, 0.46), 2.0, true)
				draw_line(Vector2.ZERO, Vector2(0, 90.0 * (1 + index % 2)), Color(w, 0.46), 2.0, true)
			"deco_rings":
				for k in 3:
					draw_arc(Vector2.ZERO, r * (0.4 + 0.3 * k), 0.0, TAU, 32, Color(w, 1.0 - 0.28 * k), 3.0, true)
			"deco_neon":
				var dd := Vector2(r * 1.4, 0)
				draw_line(-dd, dd, Color(w, 1.0), 3.0, true)
				draw_rect(Rect2(-Vector2(r, r) * 0.25, Vector2(r, r) * 0.5), Color(w, 0.5), false, 2.0)
			"deco_circuit":
				var l1 := Vector2(r * 1.6 * (1 if index % 2 == 0 else -1), 0)
				var l2 := Vector2(0, r * 1.2 * (1 if index % 3 == 0 else -1))
				draw_polyline(PackedVector2Array([Vector2.ZERO, l1, l1 + l2]), Color(w, 0.8), 3.0, true)
				draw_circle(l1 + l2, 6.0, w)
				draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 12, w, 2.0, true)
			"deco_aurora":
				# A long wave (screen width + one wavelength) that is slid sideways.
				var pts := PackedVector2Array()
				var wl := TAU / 0.006
				var width := screen.x + wl + 40.0
				var steps := int(width / 40.0) + 1
				for k in steps + 1:
					var x := k * 40.0
					pts.append(Vector2(x, sin(x * 0.006) * 60.0))
				draw_polyline(pts, w, 26.0 + 20.0 * s.z, true)
			"deco_stars":
				Shapes.draw_star(self, Vector2.ZERO, r * 0.35, w)
			"deco_rays":
				var len := screen.y
				draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(-0.05) * len, Vector2.from_angle(0.05) * len]), w)
			# --- v0.6 Second Era decorations ---
			"deco_hexglass":
				var hex := PackedVector2Array()
				for k in 7:
					hex.append(Vector2.from_angle(TAU * k / 6.0) * r)
				draw_polyline(hex, Color(w, 0.9), 3.0, true)
				var inner := PackedVector2Array()
				for k in 7:
					inner.append(Vector2.from_angle(TAU * k / 6.0) * r * 0.6)
				draw_polyline(inner, Color(w, 0.45), 2.0, true)
			"deco_gears":
				var teeth := 8
				var pts := PackedVector2Array()
				for k in teeth * 2 + 1:
					var ang := TAU * k / (teeth * 2.0)
					pts.append(Vector2.from_angle(ang) * (r if k % 2 == 0 else r * 0.78))
				draw_polyline(pts, Color(w, 0.85), 4.0, true)
				draw_arc(Vector2.ZERO, r * 0.32, 0.0, TAU, 20, Color(w, 0.7), 4.0, true)
			"deco_plasma":
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(w, 0.8), 2.5, true)
				draw_arc(Vector2.ZERO, r * 0.55, 0.3, TAU * 0.75, 20, Color(w, 0.6), 2.0, true)
				draw_circle(Vector2(r, 0), 4.0, w)
				draw_circle(Vector2.ZERO, 5.0, Color(w, 0.9))
			"deco_shards":
				draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r * 0.35, -r * 0.1), Vector2(r * 0.12, r * 0.8),
					Vector2(-r * 0.3, r * 0.2)]), Color(w, 0.55))
				draw_polyline(PackedVector2Array([Vector2(0, -r), Vector2(r * 0.12, r * 0.8)]), Color(w, 0.9), 2.0, true)
			"deco_crowns":
				if index % 2 == 0:
					var cr := r * 0.7
					draw_colored_polygon(PackedVector2Array([Vector2(-cr, cr * 0.4), Vector2(-cr, -cr * 0.3), Vector2(-cr * 0.5, cr * 0.05),
						Vector2(0, -cr * 0.6), Vector2(cr * 0.5, cr * 0.05), Vector2(cr, -cr * 0.3), Vector2(cr, cr * 0.4)]), Color(w, 0.8))
				else:
					# Laurel: two arcs of small leaves.
					for side in [-1.0, 1.0]:
						for k in 5:
							var ang: float = PI * 0.5 + side * (0.35 + 0.28 * k)
							draw_circle(Vector2.from_angle(ang) * r * 0.8, 4.0 + 1.5 * (4 - k) * 0.5, Color(w, 0.8))
			# --- particles ---
			"part_motes", "part_dust":
				draw_circle(Vector2.ZERO, 2.0 + 2.0 * s.z, w)
			"part_petals":
				draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(0, -3.5), Vector2(7, 0), Vector2(0, 3.5)]), w)
			"part_bubbles":
				draw_arc(Vector2.ZERO, 4.0 + 5.0 * s.z, 0.0, TAU, 14, w, 1.6, true)
			"part_embers", "part_pulses":
				draw_circle(Vector2.ZERO, 2.0 + 2.5 * s.z, w)
			"part_glints", "part_gold_dust":
				var rr := 3.0 + 4.0 * s.z
				draw_line(Vector2(-rr, 0), Vector2(rr, 0), w, 1.6, true)
				draw_line(Vector2(0, -rr), Vector2(0, rr), w, 1.6, true)
				draw_circle(Vector2.ZERO, 1.5, w)
			"part_sparks":
				draw_line(Vector2.ZERO, Vector2.from_angle(s.w) * 8.0, w, 2.0, true)
			"part_snow":
				draw_circle(Vector2.ZERO, 1.5 + 2.0 * s.z, w)
			"part_streaks":
				draw_line(Vector2(-10.0 - 8.0 * s.z, 0), Vector2(10.0 + 8.0 * s.z, 0), w, 2.0, true)
			"part_crystals":
				var cr := 3.0 + 3.0 * s.z
				draw_colored_polygon(PackedVector2Array([Vector2(0, -cr * 1.4), Vector2(cr, 0), Vector2(0, cr * 1.4), Vector2(-cr, 0)]), w)
