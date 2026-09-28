class_name BlockView
extends Node2D
## Visual representation of one block. Pure presentation: it draws itself and
## plays animations, but never decides whether a move is legal.
##
## The node origin is the center of its grid cell.
##
## v0.5.1 - stability: geometry is drawn only when the block's STATE
## changes (color, lock, reveal, turn, reward collected, cell size). Every
## continuous animation - the spinner ring's idle wobble, the hint pulse,
## the Silver/Gold shine and gem twinkle, the tap flash and the arrow's turn
## - moves or fades a child part that was drawn once. Redrawing polygons and
## rounded boxes every frame made Godot's Web runtime create new WebGL
## buffers every frame, and Emscripten never reuses those ids, so memory
## grew for the whole session.

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
## turns, so it can differ from data.direction for a few frames. Only
## rotates the arrow part - nothing is redrawn.
var arrow_angle: float = 0.0:
	set(v):
		arrow_angle = v
		if _arrow:
			_arrow.rotation = v
## Hint highlight (pulsing ring) while true.
var hinted: bool = false:
	set(v):
		hinted = v
		_hint_time = 0.0
		if not v:
			scale = Vector2.ONE
		if _ring:
			_ring.visible = v
		set_process(_needs_process())
var _hint_time: float = 0.0
var _spin_time: float = 0.0
var _turn_tween: Tween
## Lock presentation: true while the padlock is shown. _lock_open animates
## 0 (closed) -> 1 (open and gone) when the lock releases.
var locked_visual: bool = false
var _lock_open: float = 0.0:
	set(v):
		_lock_open = v
		if _over:
			_over.queue_redraw()
## Reward block (Silver/Gold) already collected on an earlier run: shown
## with a faint frame only, no shine or gem - it pays nothing again.
var reward_spent: bool = false:
	set(v):
		reward_spent = v
		set_process(_needs_process())
		if data:
			set_cell_size(cell_size)  # re-styles: no metal halo once spent
## 0..1 white flash over the face (used on tap). Only fades a part.
var flash: float = 0.0:
	set(v):
		flash = v
		if _flash:
			_flash.modulate.a = v
			_flash.visible = v > 0.0

# Parts drawn once, in this order (later = on top).
var _shine: Part  # Silver/Gold glint band (alpha pulses)
var _arrow: Part  # the arrow (rotates)
var _badge: Part  # spinner ring (wobbles)
var _over: Part  # static overlay: "?", lock veil + padlock, reward frame, rule strip
var _twinkle: Part  # gem highlight (pulses)
var _ring: Part  # hint ring (pulses)
var _flash: Part  # tap flash (fades)


func setup(p_data: BlockData, p_cell_size: float) -> void:
	data = p_data
	_shine = _part(_draw_shine)
	_arrow = _part(_draw_arrow_part)
	_badge = _part(_draw_badge)
	_over = _part(_draw_overlay)
	_twinkle = _part(_draw_twinkle)
	_ring = _part(_draw_hint_ring)
	_flash = _part(_draw_flash)
	_ring.visible = false
	_flash.visible = false
	arrow_angle = Direction.angle(data.direction)
	set_process(_needs_process())
	set_cell_size(p_cell_size)


func _part(fn: Callable) -> Part:
	var p := Part.new()
	p.fn = fn
	add_child(p)
	return p


func _needs_process() -> bool:
	return data != null and (hinted or data.is_spinner() or (data.is_reward() and not reward_spent))


## Per frame: transforms and alpha only.
func _process(delta: float) -> void:
	_hint_time += delta
	_spin_time += delta
	if hinted:
		var pulse := 0.5 + 0.5 * sin(_hint_time * 6.0)
		scale = Vector2.ONE * (1.0 + 0.05 * pulse)
		_ring.scale = Vector2.ONE * (1.0 + 0.045 * pulse)
	if data.is_spinner() and not data.hidden:
		_badge.rotation = sin(_spin_time * 2.0) * 0.12  # gentle idle wobble
	if data.is_reward() and not reward_spent:
		# A glint every few seconds (Gold more often) + a twinkling gem.
		var period := 2.2 if data.rarity >= BlockData.Rarity.GOLD else 3.2
		var k := fposmod(_spin_time, period) / 0.55
		_shine.modulate.a = sin(k * PI) if k < 1.0 else 0.0
		var tw := 0.5 + 0.5 * sin(_spin_time * (4.0 if data.rarity >= BlockData.Rarity.GOLD else 2.6))
		_twinkle.modulate.a = 0.7 + 0.3 * tw
		_twinkle.scale = Vector2.ONE * (0.8 + 0.4 * tw)


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
	refresh()


## Re-reads the Chapter block style (Board calls this on Chapter changes).
func refresh_style() -> void:
	set_cell_size(cell_size)


## Redraws every part once (a state change: reveal, lock, turn, reward...).
func refresh() -> void:
	var center := _face_rect().get_center()
	for p in [_arrow, _badge, _ring]:
		p.position = center
	_twinkle.position = _gem_center()
	var reward := data.is_reward() and not reward_spent
	_shine.visible = reward
	_twinkle.visible = reward
	_badge.visible = data.is_spinner() and not data.hidden
	_arrow.visible = not data.hidden
	for p in get_children():
		if p is Part:
			p.queue_redraw()
	queue_redraw()


func _face_rect() -> Rect2:
	var size := cell_size * FACE_RATIO
	var depth := cell_size * DEPTH_RATIO
	# Face sits slightly above center so face + side look centered in the cell.
	return Rect2(Vector2(-size, -size - depth) * 0.5, Vector2(size, size))


func _gem_center() -> Vector2:
	var size := cell_size * FACE_RATIO
	return _face_rect().position + Vector2(size * 0.19, size * 0.19)


# --- Drawing (only on state changes) ------------------------------------------

func _draw() -> void:
	var face_rect := _face_rect()
	var size := face_rect.size.x
	var side_rect := Rect2(face_rect.position + Vector2(0, cell_size * DEPTH_RATIO), face_rect.size)
	_side_style.draw(get_canvas_item(), side_rect)
	_face_style.draw(get_canvas_item(), face_rect)
	_draw_material(face_rect, size)


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


## Silver/Gold glint: a soft diagonal band inside the face; its alpha pulses.
func _draw_shine(c: CanvasItem) -> void:
	if not data.is_reward() or reward_spent:
		return
	var f := _face_rect()
	var size := f.size.x
	var w := size * 0.12
	var inset := size * 0.14
	var pts := PackedVector2Array([
		f.position + Vector2(inset + size * 0.3, inset), f.position + Vector2(inset + size * 0.3 + w, inset),
		f.position + Vector2(inset + w, size - inset), f.position + Vector2(inset, size - inset)])
	c.draw_colored_polygon(pts, Color(1, 1, 1, 0.3))


## Chunky white arrow pointing RIGHT around the part's origin; the part
## rotates to the block's direction.
func _draw_arrow_part(c: CanvasItem) -> void:
	if data.hidden:
		return
	var size := cell_size * FACE_RATIO * (0.78 if data.is_spinner() else 1.0)
	var length := size * 0.50
	var head_len := size * 0.24
	var head_w := size * 0.22
	var shaft_w := size * 0.075
	var tip := Vector2(length * 0.5, 0)
	var base := -tip
	var neck := tip - Vector2(head_len, 0)
	var shaft := PackedVector2Array([base + Vector2(0, shaft_w), neck + Vector2(0, shaft_w), neck - Vector2(0, shaft_w), base - Vector2(0, shaft_w)])
	var head := PackedVector2Array([tip, neck + Vector2(0, head_w), neck - Vector2(0, head_w)])
	var col := Palette.arrow(data.color)
	c.draw_colored_polygon(shaft, col)
	c.draw_colored_polygon(head, col)
	# Anti-aliased outlines smooth the polygon edges.
	shaft.append(shaft[0])
	head.append(head[0])
	c.draw_polyline(shaft, col, 1.5, true)
	c.draw_polyline(head, col, 1.5, true)


## Spinner marker: a ring of two arcs with arrowheads around the arrow,
## pointing the way the NEXT turn goes. A shape, not a color, so it reads
## for color-blind players too. Redrawn only when a turn happens.
func _draw_badge(c: CanvasItem) -> void:
	if not data.is_spinner() or data.hidden:
		return
	var size := cell_size * FACE_RATIO
	var col := Color(Palette.arrow(data.color), 0.85)
	var r := size * 0.39
	var w := maxf(2.0, size * 0.045)
	var cw := data.next_turn_cw()
	for k in 2:
		var a0 := PI * k + 0.35
		var a1 := a0 + PI - 0.7
		c.draw_arc(Vector2.ZERO, r, a0, a1, 20, col, w, true)
		var at := a1 if cw else a0
		var tip := Vector2.from_angle(at) * r
		var tangent := Vector2.from_angle(at + (PI * 0.5 if cw else -PI * 0.5))
		var normal := Vector2.from_angle(at)
		var hs := size * 0.075
		c.draw_colored_polygon(PackedVector2Array([tip + tangent * hs * 1.3, tip + normal * hs, tip - normal * hs]), col)


## Everything static that sits above the arrow.
func _draw_overlay(c: CanvasItem) -> void:
	var f := _face_rect()
	var size := f.size.x
	if data.hidden:
		_draw_mystery(c, f, size)
	elif data.is_spinner():
		_draw_rule_strip(c, f.get_center(), size)
	if locked_visual:
		_draw_lock(c, f, size)
	# Metal frame + gem sit above the lock veil so rewards read on locked
	# blocks too; they only cover the rim, never the arrow.
	if data.is_reward():
		_draw_reward(c, f, size)


## Hidden arrow: a "?" and a dashed inner border. Color stays visible
## (locks may depend on it); only the direction is unknown.
func _draw_mystery(c: CanvasItem, face_rect: Rect2, size: float) -> void:
	var col := Palette.arrow(data.color)
	var inner := face_rect.grow(-size * 0.12)
	var dash := size * 0.08
	var pts := [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y), inner.position]
	for i in 4:
		c.draw_dashed_line(pts[i], pts[i + 1], Color(col, 0.45), maxf(2.0, size * 0.03), dash, true)
	var font := Palette.font(900)
	var fs := int(size * 0.55)
	var w := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, face_rect.get_center() + Vector2(-w * 0.5, fs * 0.36), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## ALT / PATTERN: a small sequence strip at the bottom of the face. Filled
## dot = clockwise turn, ring = counter-clockwise; the upcoming turn is
## drawn bigger. The rule is visible, never a surprise.
func _draw_rule_strip(c: CanvasItem, center: Vector2, size: float) -> void:
	var period := BlockData.rule_period(data.spin_rule)
	if period <= 1:
		return
	var col := Color(Palette.arrow(data.color), 0.85)
	var dot := size * 0.05
	var y := center.y + size * 0.40
	var x0 := center.x - (period - 1) * dot * 1.6
	var next_i := posmod(data.spin_step, period)
	var strip := StyleBoxFlat.new()
	strip.bg_color = Color(0, 0, 0, 0.22)
	strip.set_corner_radius_all(int(dot * 1.6))
	strip.anti_aliasing = true
	strip.draw(c.get_canvas_item(), Rect2(Vector2(x0 - dot * 1.7, y - dot * 1.5), Vector2((period - 1) * dot * 3.2 + dot * 3.4, dot * 3.0)))
	for i in period:
		var p := Vector2(x0 + i * dot * 3.2, y)
		var rr := dot * (1.35 if i == next_i else 0.9)
		if BlockData.turn_is_cw(data.spin_rule, i):
			c.draw_circle(p, rr, col)
		else:
			c.draw_arc(p, rr * 0.85, 0.0, TAU, 12, col, maxf(1.5, dot * 0.5), true)


## Padlock in the top-right corner, colored like its key color, over a
## soft veil that makes the block read as "not available yet".
func _draw_lock(c: CanvasItem, face_rect: Rect2, size: float) -> void:
	var t := _lock_open
	var veil := _face_style.duplicate() as StyleBoxFlat
	veil.bg_color = Color(0.1, 0.07, 0.25, 0.30 * (1.0 - t))
	veil.shadow_size = 0
	veil.draw(c.get_canvas_item(), face_rect)
	var s := size * 0.36 * (1.0 + 0.5 * t)
	var a := 1.0 - t
	var cc := face_rect.position + Vector2(face_rect.size.x - size * 0.16, size * 0.18)
	var body := Rect2(cc + Vector2(-s * 0.5, -s * 0.1), Vector2(s, s * 0.72))
	var lift := s * 0.35 * t
	c.draw_arc(cc + Vector2(0, -s * 0.1 - lift), s * 0.3, PI, TAU, 16, Color(1, 1, 1, a), maxf(3.0, s * 0.16), true)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Palette.face(data.lock_color), a)
	st.border_color = Color(1, 1, 1, a)
	st.set_border_width_all(maxi(2, int(s * 0.1)))
	st.set_corner_radius_all(int(s * 0.18))
	st.anti_aliasing = true
	st.shadow_color = Color(0, 0, 0, 0.25 * a)
	st.shadow_size = 3
	st.draw(c.get_canvas_item(), body)
	c.draw_circle(body.get_center() + Vector2(0, -s * 0.04), s * 0.09, Color(1, 1, 1, a))


## Silver / Gold reward block: a thick metallic frame and a gem in the
## top-left corner (the padlock uses top-right). The block's own color
## stays fully visible (locks depend on it).
func _draw_reward(c: CanvasItem, face_rect: Rect2, size: float) -> void:
	var metal: Array = Palette.METALS[data.rarity]
	var radius := int(round(size * CORNER_RATIO))
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.anti_aliasing = true
	frame.set_corner_radius_all(radius)
	if reward_spent:
		frame.set_border_width_all(maxi(2, int(size * 0.03)))
		frame.border_color = Color(metal[0], 0.45)
		frame.draw(c.get_canvas_item(), face_rect)
		return
	var w := maxi(4, int(size * 0.09))
	frame.set_border_width_all(w)
	frame.border_color = metal[2]
	frame.draw(c.get_canvas_item(), face_rect)
	frame.set_border_width_all(maxi(3, int(w * 0.62)))
	frame.border_color = metal[0]
	frame.draw(c.get_canvas_item(), face_rect.grow(-w * 0.18))
	var hl := face_rect.position + Vector2(radius, w * 0.4)
	c.draw_line(hl, hl + Vector2(size - radius * 2.0, 0), Color(metal[1], 0.9), maxf(2.0, w * 0.3), true)
	# Gem badge with a dark outline so it reads on every block color.
	var g := _gem_center()
	var gs := size * 0.14
	c.draw_colored_polygon(PackedVector2Array([g + Vector2(0, -gs * 1.22), g + Vector2(gs * 1.22, 0), g + Vector2(0, gs * 1.22), g + Vector2(-gs * 1.22, 0)]), Color(0.08, 0.06, 0.16, 0.55))
	c.draw_colored_polygon(PackedVector2Array([g + Vector2(0, -gs), g + Vector2(gs, 0), g + Vector2(0, gs), g + Vector2(-gs, 0)]), metal[2])
	c.draw_colored_polygon(PackedVector2Array([g + Vector2(0, -gs * 0.66), g + Vector2(gs * 0.66, 0), g + Vector2(0, gs * 0.66), g + Vector2(-gs * 0.66, 0)]), metal[0])


## Gem highlight dot (the part pulses in size and alpha).
func _draw_twinkle(c: CanvasItem) -> void:
	if not data.is_reward() or reward_spent:
		return
	var metal: Array = Palette.METALS[data.rarity]
	var gs := cell_size * FACE_RATIO * 0.14
	c.draw_circle(Vector2(-gs * 0.2, -gs * 0.22), gs * 0.21, metal[1])


## Two-tone hint ring around the face (reads on every block color).
func _draw_hint_ring(c: CanvasItem) -> void:
	var f := _face_rect()
	var local := Rect2(-f.size * 0.5, f.size)
	var grow := cell_size * 0.07
	var width := maxi(4, int(cell_size * 0.055))
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.anti_aliasing = true
	ring.set_corner_radius_all(int(cell_size * FACE_RATIO * CORNER_RATIO) + int(grow) + 2)
	ring.set_border_width_all(width + 4)
	ring.border_color = Color(Palette.TEXT, 0.85)
	ring.draw(c.get_canvas_item(), local.grow(grow + 2))
	ring.set_border_width_all(width)
	ring.border_color = Palette.HINT.lerp(Palette.WHITE, 0.2)
	ring.draw(c.get_canvas_item(), local.grow(grow))


func _draw_flash(c: CanvasItem) -> void:
	var fs := _face_style.duplicate() as StyleBoxFlat
	fs.bg_color = Color(1, 1, 1, 0.35)
	fs.shadow_size = 0
	fs.draw(c.get_canvas_item(), _face_rect())


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
				_over.queue_redraw())
			flash = 1.0
			create_tween().tween_property(self, "flash", 0.0, 0.4)
			return
		locked_visual = false
		_lock_open = 0.0
	_over.queue_redraw()


## Mystery reveal: a quick card-flip, then the arrow is shown.
func play_reveal() -> void:
	var t := create_tween()
	t.tween_property(self, "scale:x", 0.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_callback(func():
		data.hidden = false
		flash = 1.0
		refresh())
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


# --- Animations ------------------------------------------------------------

## Spinner turned by a neighbour: animate the arrow a quarter turn.
## `clockwise` false is used when Undo turns it back. Only the arrow part
## rotates; the ring and rule strip are redrawn once for the next turn.
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
	_badge.queue_redraw()
	_over.queue_redraw()


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


## A child drawn once by a BlockView function; only its transform and
## modulate change afterwards.
class Part extends Node2D:
	var fn: Callable

	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)
