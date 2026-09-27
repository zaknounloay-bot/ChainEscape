class_name BlockView
extends Node2D
## Visual representation of one block. Pure presentation: it draws itself and
## plays animations, but never decides whether a move is legal.
##
## The node origin is the center of its grid cell.

const FACE_RATIO := 0.86  # block size relative to the cell
const CORNER_RATIO := 0.22
const DEPTH_RATIO := 0.06  # height of the darker "side" under the face

var data: BlockData
var cell_size: float = 100.0
## Resting position at the center of the block's cell (set by Board).
var home: Vector2

var _tween: Tween
var _face_style := StyleBoxFlat.new()
var _side_style := StyleBoxFlat.new()
## Displayed arrow angle in radians (RIGHT = 0). Animated when a spinner
## turns, so it can differ from data.direction for a few frames.
var arrow_angle: float = 0.0:
	set(v):
		arrow_angle = v
		queue_redraw()
## Hint highlight (pulsing ring) while true.
var hinted: bool = false:
	set(v):
		hinted = v
		_hint_time = 0.0
		if not v:
			scale = Vector2.ONE
		set_process(_needs_process())
		queue_redraw()
var _hint_time: float = 0.0
var _spin_time: float = 0.0
var _turn_tween: Tween
## Lock presentation: true while the padlock is shown. _lock_open animates
## 0 (closed) -> 1 (open and gone) when the lock releases.
var locked_visual: bool = false
var _lock_open: float = 0.0:
	set(v):
		_lock_open = v
		queue_redraw()
## Reward block (Silver/Gold) already collected on an earlier run: shown
## with a faint frame only, no shimmer or gem - it pays nothing again.
var reward_spent: bool = false:
	set(v):
		reward_spent = v
		set_process(_needs_process())
		if data:
			set_cell_size(cell_size)  # re-styles: no metal halo once spent
## 0..1 white flash drawn over the face (used on tap).
var flash: float = 0.0:
	set(v):
		flash = v
		queue_redraw()


func setup(p_data: BlockData, p_cell_size: float) -> void:
	data = p_data
	arrow_angle = Direction.angle(data.direction)
	set_process(_needs_process())
	set_cell_size(p_cell_size)


func _needs_process() -> bool:
	return data != null and (hinted or data.is_spinner() or (data.is_reward() and not reward_spent))


func _process(delta: float) -> void:
	_hint_time += delta
	_spin_time += delta
	if hinted:
		var pulse := 0.5 + 0.5 * sin(_hint_time * 6.0)
		scale = Vector2.ONE * (1.0 + 0.05 * pulse)
	queue_redraw()


func set_cell_size(value: float) -> void:
	cell_size = value
	var radius := int(round(cell_size * FACE_RATIO * CORNER_RATIO))
	for s in [_face_style, _side_style]:
		s.set_corner_radius_all(radius)
		s.anti_aliasing = true
		s.anti_aliasing_size = 1.2
	_face_style.bg_color = Palette.styled_face(data.color)
	_side_style.bg_color = Palette.styled_side(data.color)
	# Chapter material: on dark Chapters a soft glow in the block's own
	# color replaces part of the drop shadow.
	var glow: float = Palette.block_style.get("glow", 0.0)
	_side_style.shadow_color = Palette.SHADOW.lerp(Color(Palette.styled_face(data.color), 0.45), glow)
	_side_style.shadow_size = int(cell_size * (0.08 + 0.07 * glow))
	_side_style.shadow_offset = Vector2(0, cell_size * 0.04 * (1.0 - glow))
	if data.is_reward() and not reward_spent:
		# Uncollected Silver/Gold: a halo in the metal's color (Gold wider).
		var gold := data.rarity >= BlockData.Rarity.GOLD
		_side_style.shadow_color = Color(Palette.METALS[data.rarity][0], 0.75 if gold else 0.6)
		_side_style.shadow_size = int(cell_size * (0.2 if gold else 0.15))
		_side_style.shadow_offset = Vector2.ZERO
	queue_redraw()


## Re-reads the Chapter block style (Board calls this on Chapter changes).
func refresh_style() -> void:
	set_cell_size(cell_size)


func _draw() -> void:
	var size := cell_size * FACE_RATIO
	var depth := cell_size * DEPTH_RATIO
	# Face sits slightly above center so face + side look centered in the cell.
	var face_rect := Rect2(Vector2(-size, -size - depth) * 0.5, Vector2(size, size))
	var side_rect := Rect2(face_rect.position + Vector2(0, depth), face_rect.size)
	_side_style.draw(get_canvas_item(), side_rect)
	_face_style.draw(get_canvas_item(), face_rect)
	_draw_material(face_rect, size)
	if data.is_reward() and not reward_spent:
		_draw_reward_sweep(face_rect, size)
	var center := face_rect.get_center()
	if data.hidden:
		_draw_mystery(face_rect, size)
	elif data.is_spinner():
		_draw_spinner_badge(center, size)
		_draw_arrow(center, size * 0.78)
	else:
		_draw_arrow(center, size)
	if locked_visual:
		_draw_lock(face_rect, size)
	# Metal frame + gem sit above the lock veil so rewards read on locked
	# blocks too; they only cover the rim, never the arrow.
	if data.is_reward():
		_draw_reward(face_rect, size)
	if hinted:
		_draw_hint_ring(face_rect)
	if flash > 0.0:
		var fs := _face_style.duplicate() as StyleBoxFlat
		fs.bg_color = Color(1, 1, 1, 0.35 * flash)
		fs.shadow_size = 0
		fs.draw(get_canvas_item(), face_rect)


## Chapter finish: a gloss band on the upper face and a thin light rim.
## Both sit UNDER the arrow, so direction always reads first.
func _draw_material(face_rect: Rect2, size: float) -> void:
	var gloss: float = Palette.block_style.get("gloss", 0.0)
	var rim: float = Palette.block_style.get("rim", 0.0)
	var radius := int(round(size * CORNER_RATIO))
	if gloss > 0.0:
		var band := StyleBoxFlat.new()
		band.bg_color = Color(1, 1, 1, 0.2 * gloss)
		band.anti_aliasing = true
		band.corner_radius_top_left = radius
		band.corner_radius_top_right = radius
		band.corner_radius_bottom_left = int(radius * 0.6)
		band.corner_radius_bottom_right = int(radius * 0.6)
		var inset := size * 0.06
		band.draw(get_canvas_item(), Rect2(face_rect.position + Vector2(inset, inset * 0.7), Vector2(size - inset * 2.0, size * 0.36)))
	if rim > 0.0:
		var edge := StyleBoxFlat.new()
		edge.draw_center = false
		edge.anti_aliasing = true
		edge.set_corner_radius_all(radius)
		edge.set_border_width_all(maxi(2, int(size * 0.028)))
		edge.border_color = Color(Palette.block_style.get("edge", Color.WHITE), 0.5 * rim)
		edge.draw(get_canvas_item(), face_rect)


## Silver / Gold reward block: a thick metallic frame, a gem in the
## top-left corner and (see _draw_reward_sweep) a light sweep every few
## seconds. The block's own color stays fully visible (locks depend on it)
## and the arrow is never covered.
func _draw_reward(face_rect: Rect2, size: float) -> void:
	var metal: Array = Palette.METALS[data.rarity]
	var radius := int(round(size * CORNER_RATIO))
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.anti_aliasing = true
	frame.set_corner_radius_all(radius)
	if reward_spent:
		frame.set_border_width_all(maxi(2, int(size * 0.03)))
		frame.border_color = Color(metal[0], 0.45)
		frame.draw(get_canvas_item(), face_rect)
		return
	var w := maxi(4, int(size * 0.09))
	frame.set_border_width_all(w)
	frame.border_color = metal[2]
	frame.draw(get_canvas_item(), face_rect)
	frame.set_border_width_all(maxi(3, int(w * 0.62)))
	frame.border_color = metal[0]
	frame.draw(get_canvas_item(), face_rect.grow(-w * 0.18))
	# Highlight on the top edge sells the metal.
	var hl := face_rect.position + Vector2(radius, w * 0.4)
	draw_line(hl, hl + Vector2(size - radius * 2.0, 0), Color(metal[1], 0.9), maxf(2.0, w * 0.3), true)
	# Gem badge (top-left; the padlock uses top-right), with a dark outline
	# so it reads on every block color and Chapter.
	var g := face_rect.position + Vector2(size * 0.19, size * 0.19)
	var gs := size * 0.14
	var outline := PackedVector2Array([g + Vector2(0, -gs * 1.22), g + Vector2(gs * 1.22, 0), g + Vector2(0, gs * 1.22), g + Vector2(-gs * 1.22, 0)])
	draw_colored_polygon(outline, Color(0.08, 0.06, 0.16, 0.55))
	draw_colored_polygon(PackedVector2Array([g + Vector2(0, -gs), g + Vector2(gs, 0), g + Vector2(0, gs), g + Vector2(-gs, 0)]), metal[2])
	draw_colored_polygon(PackedVector2Array([g + Vector2(0, -gs * 0.66), g + Vector2(gs * 0.66, 0), g + Vector2(0, gs * 0.66), g + Vector2(-gs * 0.66, 0)]), metal[0])
	# Twinkle on the gem.
	var tw := 0.5 + 0.5 * sin(_spin_time * (4.0 if data.rarity >= BlockData.Rarity.GOLD else 2.6))
	draw_circle(g + Vector2(-gs * 0.2, -gs * 0.22), gs * (0.16 + 0.1 * tw), Color(metal[1], 0.7 + 0.3 * tw))


## Periodic light sweep across the face, drawn UNDER the arrow (Gold sweeps
## more often than Silver).
func _draw_reward_sweep(face_rect: Rect2, size: float) -> void:
	var radius := size * CORNER_RATIO
	var period := 2.2 if data.rarity >= BlockData.Rarity.GOLD else 3.2
	var k := fposmod(_spin_time, period) / 0.55
	if k >= 1.0:
		return
	var x := face_rect.position.x - size * 0.3 + k * size * 1.6
	var slant := size * 0.3
	var band := size * 0.14
	var left := face_rect.position.x + radius * 0.4
	var right := face_rect.end.x - radius * 0.4
	var top := face_rect.position.y + size * 0.06
	var bottom := face_rect.end.y - size * 0.06
	var pts := PackedVector2Array([
		Vector2(clampf(x, left, right), top), Vector2(clampf(x + band, left, right), top),
		Vector2(clampf(x + band - slant, left, right), bottom), Vector2(clampf(x - slant, left, right), bottom)])
	draw_colored_polygon(pts, Color(1, 1, 1, 0.3 * sin(k * PI)))


## Chunky white arrow: rectangular shaft + triangular head.
func _draw_arrow(center: Vector2, size: float) -> void:
	var fwd := Vector2.from_angle(arrow_angle)
	var side := Vector2(-fwd.y, fwd.x)
	var length := size * 0.50
	var head_len := size * 0.24
	var head_w := size * 0.22
	var shaft_w := size * 0.075
	var tip := center + fwd * length * 0.5
	var base := center - fwd * length * 0.5
	var neck := tip - fwd * head_len
	var shaft := PackedVector2Array([
		base + side * shaft_w, neck + side * shaft_w,
		neck - side * shaft_w, base - side * shaft_w,
	])
	var head := PackedVector2Array([tip, neck + side * head_w, neck - side * head_w])
	var col := Palette.arrow(data.color)
	draw_colored_polygon(shaft, col)
	draw_colored_polygon(head, col)
	# Anti-aliased outlines smooth the polygon edges.
	shaft.append(shaft[0])
	head.append(head[0])
	draw_polyline(shaft, col, 1.5, true)
	draw_polyline(head, col, 1.5, true)


## Hidden arrow: a "?" and a dashed inner border. Color stays visible
## (locks may depend on it); only the direction is unknown.
func _draw_mystery(face_rect: Rect2, size: float) -> void:
	var col := Palette.arrow(data.color)
	var inner := face_rect.grow(-size * 0.12)
	var dash := size * 0.08
	var pts := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y), inner.position]
	for i in 4:
		draw_dashed_line(pts[i], pts[i + 1], Color(col, 0.45), maxf(2.0, size * 0.03), dash, true)
	var font := Palette.font(900)
	var fs := int(size * 0.55)
	var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, face_rect.get_center() + Vector2(-w * 0.5, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Padlock in the top-right corner, colored like its key color, over a
## soft veil that makes the block read as "not available yet".
func _draw_lock(face_rect: Rect2, size: float) -> void:
	var t := _lock_open
	var veil := _face_style.duplicate() as StyleBoxFlat
	veil.bg_color = Color(0.1, 0.07, 0.25, 0.30 * (1.0 - t))
	veil.shadow_size = 0
	veil.draw(get_canvas_item(), face_rect)
	var s := size * 0.36 * (1.0 + 0.5 * t)
	var a := 1.0 - t
	var c := face_rect.position + Vector2(face_rect.size.x - size * 0.16, size * 0.18)
	var body := Rect2(c + Vector2(-s * 0.5, -s * 0.1), Vector2(s, s * 0.72))
	# Shackle (lifts as the lock opens).
	var lift := s * 0.35 * t
	draw_arc(c + Vector2(0, -s * 0.1 - lift), s * 0.3, PI, TAU, 16, Color(1, 1, 1, a), maxf(3.0, s * 0.16), true)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Palette.face(data.lock_color), a)
	st.border_color = Color(1, 1, 1, a)
	st.set_border_width_all(maxi(2, int(s * 0.1)))
	st.set_corner_radius_all(int(s * 0.18))
	st.anti_aliasing = true
	st.shadow_color = Color(0, 0, 0, 0.25 * a)
	st.shadow_size = 3
	st.draw(get_canvas_item(), body)
	draw_circle(body.get_center() + Vector2(0, -s * 0.04), s * 0.09, Color(1, 1, 1, a))


func set_locked(on: bool, animate: bool = false) -> void:
	if on:
		locked_visual = true
		_lock_open = 0.0
	elif locked_visual:
		if animate:
			var t := create_tween()
			t.tween_property(self, "_lock_open", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.tween_callback(func():
				locked_visual = false
				queue_redraw())
			flash = 1.0
			create_tween().tween_property(self, "flash", 0.0, 0.4)
		else:
			locked_visual = false
			_lock_open = 0.0


## Mystery reveal: a quick card-flip, then the arrow is shown.
func play_reveal() -> void:
	var t := create_tween()
	t.tween_property(self, "scale:x", 0.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		data.hidden = false
		flash = 1.0
		queue_redraw())
	t.tween_property(self, "scale:x", 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "flash", 0.0, 0.25)


## Locked block tapped: rattle sideways.
func play_rattle() -> void:
	position = home
	var t := _new_tween()
	for i in 3:
		t.tween_property(self, "position", home + Vector2(cell_size * 0.05, 0), 0.035)
		t.tween_property(self, "position", home - Vector2(cell_size * 0.05, 0), 0.035)
	t.tween_property(self, "position", home, 0.04)


## "I am one of the keys": a small hop.
func play_key_pulse(delay: float = 0.0) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_property(self, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Spinner marker: a ring of two clockwise arcs with arrowheads around the
## arrow. A shape, not a color, so it reads for color-blind players too.
func _draw_spinner_badge(center: Vector2, size: float) -> void:
	var col := Color(Palette.arrow(data.color), 0.85)
	var r := size * 0.39
	var w := maxf(2.0, size * 0.045)
	var cw := data.next_turn_cw()
	var drift := sin(_spin_time * 2.0) * 0.12  # gentle idle wobble
	for k in 2:
		var a0 := drift + PI * k + 0.35
		var a1 := a0 + PI - 0.7
		draw_arc(center, r, a0, a1, 20, col, w, true)
		# Arrowhead shows the direction of the NEXT turn.
		var at := a1 if cw else a0
		var tip := center + Vector2.from_angle(at) * r
		var tangent := Vector2.from_angle(at + (PI * 0.5 if cw else -PI * 0.5))
		var normal := Vector2.from_angle(at)
		var hs := size * 0.075
		var pts := PackedVector2Array([tip + tangent * hs * 1.3, tip + normal * hs, tip - normal * hs])
		draw_colored_polygon(pts, col)
	# ALT / PATTERN: a small sequence strip at the bottom of the face.
	# Filled dot = clockwise turn, ring = counter-clockwise; the upcoming
	# turn is drawn bigger. The rule is visible, never a surprise.
	var period := BlockData.rule_period(data.spin_rule)
	if period > 1:
		var dot := size * 0.05
		var y := center.y + size * 0.40
		var x0 := center.x - (period - 1) * dot * 1.6
		var next_i := posmod(data.spin_step, period)
		var strip := StyleBoxFlat.new()
		strip.bg_color = Color(0, 0, 0, 0.22)
		strip.set_corner_radius_all(int(dot * 1.6))
		strip.anti_aliasing = true
		strip.draw(get_canvas_item(), Rect2(Vector2(x0 - dot * 1.7, y - dot * 1.5), Vector2((period - 1) * dot * 3.2 + dot * 3.4, dot * 3.0)))
		for i in period:
			var p := Vector2(x0 + i * dot * 3.2, y)
			var rr := dot * (1.35 if i == next_i else 0.9)
			if BlockData.turn_is_cw(data.spin_rule, i):
				draw_circle(p, rr, col)
			else:
				draw_arc(p, rr * 0.85, 0.0, TAU, 12, col, maxf(1.5, dot * 0.5), true)


func _draw_hint_ring(face_rect: Rect2) -> void:
	var pulse := 0.5 + 0.5 * sin(_hint_time * 6.0)
	var grow := cell_size * (0.05 + 0.04 * pulse)
	# Two-tone ring (dark outline + bright band) reads on every block color.
	var width := maxi(4, int(cell_size * 0.055))
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.anti_aliasing = true
	ring.set_corner_radius_all(int(cell_size * FACE_RATIO * CORNER_RATIO) + int(grow) + 2)
	ring.set_border_width_all(width + 4)
	ring.border_color = Color(Palette.TEXT, 0.85)
	ring.draw(get_canvas_item(), face_rect.grow(grow + 2))
	ring.set_border_width_all(width)
	ring.border_color = Palette.HINT.lerp(Palette.WHITE, 0.35 * pulse)
	ring.draw(get_canvas_item(), face_rect.grow(grow))


# --- Animations ------------------------------------------------------------

## Spinner turned by a neighbour: animate the arrow a quarter turn.
## `clockwise` false is used when Undo turns it back.
func play_turn(new_direction: int, clockwise: bool = true, delay: float = 0.0) -> void:
	data.direction = new_direction
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	var target := arrow_angle + (PI * 0.5 if clockwise else -PI * 0.5)
	# Snap any half-finished turn so we always end exactly on the direction.
	var exact := Direction.angle(new_direction)
	target = exact + TAU * roundf((target - exact) / TAU)
	_turn_tween = create_tween()
	if delay > 0.0:
		_turn_tween.tween_interval(delay)
	_turn_tween.tween_property(self, "arrow_angle", target, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _new_tween() -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	return _tween


## Pop in at level start. `delay` is used to stagger blocks.
func play_appear(delay: float) -> void:
	scale = Vector2.ZERO
	var t := _new_tween()
	t.tween_interval(delay)
	t.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fly out along the arrow. The caller frees the node via `finished`.
func play_escape(target: Vector2, duration: float) -> Tween:
	z_index = 10
	var t := _new_tween()
	flash = 1.0
	t.tween_property(self, "flash", 0.0, 0.12)
	var fwd := Direction.vector(data.direction)
	# Stretch along the travel axis for a sense of speed.
	var stretch := Vector2(1.0 + absf(fwd.x) * 0.10 - absf(fwd.y) * 0.06, 1.0 + absf(fwd.y) * 0.10 - absf(fwd.x) * 0.06)
	t.parallel().tween_property(self, "scale", stretch, duration * 0.4)
	t.parallel().tween_property(self, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	return t


## Short nudge toward the blocked direction and back: "this path is blocked".
func play_bump(amount: float, delay: float = 0.0) -> void:
	position = home
	var fwd := Direction.vector(data.direction)
	var t := _new_tween()
	if delay > 0.0:
		t.tween_interval(delay)
	t.tween_property(self, "position", home + fwd * amount, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", home, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Small recoil on the block that caused a bump, in the pushed direction.
func play_hit(push_dir: int, amount: float, delay: float) -> void:
	position = home
	var t := _new_tween()
	t.tween_interval(delay)
	t.tween_property(self, "position", home + Direction.vector(push_dir) * amount, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "position", home, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Fly back in from off-screen (used by Undo).
func play_return(from: Vector2) -> void:
	position = from
	modulate.a = 0.0
	var t := _new_tween()
	t.tween_property(self, "position", home, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "modulate:a", 1.0, 0.12)

