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

## v0.6 Chain Gate counter: linked blocks still on the board (redrawn only
## when it changes).
var gate_count: int = 0:
	set(v):
		if v != gate_count:
			gate_count = v
			if _over:
				_over.queue_redraw()

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
	_face_style.bg_color = Palette.styled_face(data.color) if not data.is_gate() else Palette.GATE[0]
	_side_style.bg_color = Palette.styled_side(data.color) if not data.is_gate() else Palette.GATE[1]
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
	_arrow.visible = not data.hidden and not data.is_gate()
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
	if not data.is_gate():
		_draw_era2_material(face_rect, size, radius)


## v0.6 Second Era finishes (Chapters 11-20). Same square, same arrow: only
## the surface treatment changes, drawn once per state change, always under
## the arrow and at low contrast so direction still reads first.
func _draw_era2_material(f: Rect2, size: float, radius: int) -> void:
	var st: Dictionary = Palette.block_style
	var ci := get_canvas_item()
	var light := Palette.styled_face(data.color).lightened(0.55)
	var neon: float = st.get("neon", 0.0)
	if neon > 0.0:
		# Neon glass: a bright inner light line in the block's own hue.
		var line := StyleBoxFlat.new()
		line.draw_center = false
		line.anti_aliasing = true
		line.set_corner_radius_all(maxi(radius - 3, 2))
		line.set_border_width_all(maxi(2, int(size * 0.03)))
		line.border_color = Color(light, 0.75 * neon)
		line.draw(ci, f.grow(-size * 0.07))
	var glass: float = st.get("glass", 0.0)
	if glass > 0.0:
		# Glass reflection: a soft diagonal band across the upper-left face.
		var a := f.position + Vector2(size * 0.1, size * 0.1)
		draw_colored_polygon(PackedVector2Array([a, a + Vector2(size * 0.42, 0), a + Vector2(0, size * 0.42)]), Color(1, 1, 1, 0.16 * glass))
	var metal: float = st.get("metal", 0.0)
	if metal > 0.0:
		# Industrial metal: a brushed band along the top and a dark bevel
		# along the bottom, plus two small bolts.
		draw_rect(Rect2(f.position + Vector2(radius, size * 0.05), Vector2(size - radius * 2.0, size * 0.05)), Color(1, 1, 1, 0.22 * metal))
		draw_rect(Rect2(f.position + Vector2(radius, size * 0.9), Vector2(size - radius * 2.0, size * 0.045)), Color(0, 0, 0, 0.18 * metal))
		for x in [0.14, 0.86]:
			draw_rect(Rect2(f.position + Vector2(size * x - size * 0.025, size * 0.86), Vector2(size * 0.05, size * 0.05)), Color(1, 1, 1, 0.35 * metal))
	var plasma: float = st.get("plasma", 0.0)
	if plasma > 0.0:
		# Energy / plasma: a double inner ring, like a charged cell.
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.anti_aliasing = true
		ring.set_corner_radius_all(maxi(radius - 6, 2))
		ring.set_border_width_all(maxi(1, int(size * 0.018)))
		ring.border_color = Color(light, 0.55 * plasma)
		ring.draw(ci, f.grow(-size * 0.13))
		ring.border_color = Color(1, 1, 1, 0.25 * plasma)
		ring.draw(ci, f.grow(-size * 0.2))
	var facet: float = st.get("facet", 0.0)
	if facet > 0.0:
		# Crystal: faint facet cuts from the corners toward a center diamond.
		var ctr := f.get_center()
		var d := size * 0.2
		var col := Color(1, 1, 1, 0.18 * facet)
		for corner in [f.position + Vector2(size * 0.12, size * 0.12), f.position + Vector2(size * 0.88, size * 0.12),
				f.position + Vector2(size * 0.88, size * 0.88), f.position + Vector2(size * 0.12, size * 0.88)]:
			draw_line(corner, ctr + (corner - ctr).normalized() * d, col, maxf(1.5, size * 0.015), true)
		draw_polyline(PackedVector2Array([ctr + Vector2(0, -d), ctr + Vector2(d, 0), ctr + Vector2(0, d), ctr + Vector2(-d, 0), ctr + Vector2(0, -d)]),
			Color(1, 1, 1, 0.12 * facet), maxf(1.5, size * 0.015), true)
	var elite: float = st.get("elite", 0.0)
	if elite > 0.0:
		# Elite / Master: thin gold filigree on all four corners.
		var g := Color(Palette.block_style.get("edge", Color("#FFE08A")), 0.85 * elite)
		var w := maxf(2.0, size * 0.03)
		var l := size * 0.16
		var k := size * 0.09
		for cx in [0, 1]:
			for cy in [0, 1]:
				var p: Vector2 = f.position + Vector2(k + cx * (size - 2 * k), k + cy * (size - 2 * k))
				var sx: float = 1.0 if cx == 0 else -1.0
				var sy: float = 1.0 if cy == 0 else -1.0
				draw_line(p, p + Vector2(l * sx, 0), g, w, true)
				draw_line(p, p + Vector2(0, l * sy), g, w, true)


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
	if data.hidden or data.is_gate():
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
	if data.is_gate():
		_draw_gate(c, f, size)
		return
	if data.is_switch():
		_draw_switch_chip(c, f, size)
	elif data.flip_link != "":
		_draw_flip_badge(c, f, size)
	if data.gate_link != "":
		_draw_link_badge(c, f, size)
	if locked_visual:
		_draw_lock(c, f, size)
	# Metal frame + gem sit above the lock veil so rewards read on locked
	# blocks too; they only cover the rim, never the arrow.
	if data.is_reward():
		_draw_reward(c, f, size)
	# The shell is the rule: it is drawn above everything else.
	if data.armored:
		_draw_armor(c, f, size)


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


## v0.6 CHAIN GATE: a dark steel slab (no arrow) with a big chain icon, the
## group letter and the number of linked blocks still on the board, all in
## the group's color.
func _draw_gate(c: CanvasItem, f: Rect2, size: float) -> void:
	var col := Palette.link(data.gate_group)
	var ci := c.get_canvas_item()
	# Diagonal hazard stripes, clipped to the inner plate.
	var inner := f.grow(-size * 0.1)
	var stripe := size * 0.14
	var k := -inner.size.y
	while k < inner.size.x:
		var a := Vector2(maxf(k, 0.0), maxf(-k, 0.0))
		var b := Vector2(minf(k + inner.size.y, inner.size.x), minf(inner.size.x - k, inner.size.y))
		if a.x < b.x:
			c.draw_line(inner.position + a, inner.position + b, Color(col, 0.10), stripe * 0.5)
		k += stripe * 1.4
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.anti_aliasing = true
	frame.set_corner_radius_all(int(size * CORNER_RATIO))
	frame.set_border_width_all(maxi(3, int(size * 0.06)))
	frame.border_color = Color(col, 0.9)
	frame.draw(ci, f)
	# Chain: two interlocked rounded links.
	var ctr := f.get_center() + Vector2(0, -size * 0.1)
	var lw := maxf(3.0, size * 0.06)
	for i in 2:
		var o := Vector2((i - 0.5) * size * 0.2, 0)
		var link := StyleBoxFlat.new()
		link.draw_center = false
		link.anti_aliasing = true
		link.set_corner_radius_all(int(size * 0.09))
		link.set_border_width_all(int(lw))
		link.border_color = Palette.GATE[2] if i == 0 else col
		link.draw(ci, Rect2(ctr + o - Vector2(size * 0.15, size * 0.09), Vector2(size * 0.3, size * 0.18)))
	# "C  2": group letter + links left.
	var font := Palette.font(900)
	var fs := int(size * 0.24)
	var txt := "%s %d" % [data.gate_group, gate_count]
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, f.get_center() + Vector2(-w * 0.5, size * 0.33), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## A round badge in a corner: link color, dark outline, white letter.
func _draw_badge_at(c: CanvasItem, at: Vector2, size: float, group: String, glyph: String) -> void:
	var r := size * 0.155
	c.draw_circle(at, r * 1.18, Color(0.06, 0.05, 0.12, 0.8))
	c.draw_circle(at, r, Palette.link(group))
	var font := Palette.font(900)
	var fs := int(size * 0.21)
	var txt := glyph + group if glyph != "" else group
	var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#101018"))


## SWITCH: a toggle chip in the bottom-left corner ("toggle knob + letter").
func _draw_switch_chip(c: CanvasItem, f: Rect2, size: float) -> void:
	var col := Palette.link(data.switch_group)
	var chip := Rect2(f.position + Vector2(size * 0.05, size * 0.69), Vector2(size * 0.5, size * 0.26))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.05, 0.12, 0.8)
	st.border_color = col
	st.set_border_width_all(maxi(2, int(size * 0.025)))
	st.set_corner_radius_all(int(chip.size.y * 0.5))
	st.anti_aliasing = true
	st.draw(c.get_canvas_item(), chip)
	c.draw_circle(chip.position + Vector2(chip.size.y * 0.5, chip.size.y * 0.5), chip.size.y * 0.32, col)
	var font := Palette.font(900)
	var fs := int(size * 0.21)
	c.draw_string(font, chip.position + Vector2(chip.size.y * 1.05, chip.size.y * 0.5 + fs * 0.36), data.switch_group,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## FLIP TARGET: a badge "⇅A" in the bottom-left corner (same color as its switch).
func _draw_flip_badge(c: CanvasItem, f: Rect2, size: float) -> void:
	var at := f.position + Vector2(size * 0.19, size * 0.81)
	_draw_badge_at(c, at, size, data.flip_link, "")
	# Two tiny opposite arrows around the badge: "this one reverses".
	var col := Palette.link(data.flip_link)
	var r := size * 0.23
	c.draw_arc(at, r, -PI * 0.9, -PI * 0.1, 10, col, maxf(1.5, size * 0.02), true)
	c.draw_arc(at, r, PI * 0.1, PI * 0.9, 10, col, maxf(1.5, size * 0.02), true)


## GATE LINK: a chain badge in the bottom-right corner (gate's color + letter).
func _draw_link_badge(c: CanvasItem, f: Rect2, size: float) -> void:
	var at := f.position + Vector2(size * 0.8, size * 0.8)
	var col := Palette.link(data.gate_link)
	c.draw_circle(at, size * 0.18, Color(0.06, 0.05, 0.12, 0.8))
	var link := StyleBoxFlat.new()
	link.draw_center = false
	link.anti_aliasing = true
	link.set_corner_radius_all(int(size * 0.05))
	link.set_border_width_all(maxi(2, int(size * 0.03)))
	link.border_color = col
	link.draw(c.get_canvas_item(), Rect2(at - Vector2(size * 0.12, size * 0.13), Vector2(size * 0.24, size * 0.11)))
	var font := Palette.font(900)
	var fs := int(size * 0.18)
	var w := font.get_string_size(data.gate_link, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, at + Vector2(-w * 0.5, size * 0.13), data.gate_link, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## ARMORED: a thick riveted steel frame around the face. The arrow stays
## fully visible in the middle.
func _draw_armor(c: CanvasItem, f: Rect2, size: float) -> void:
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.anti_aliasing = true
	frame.set_corner_radius_all(int(size * CORNER_RATIO))
	var w := maxi(5, int(size * 0.12))
	frame.set_border_width_all(w)
	frame.border_color = Palette.ARMOR[2]
	frame.draw(c.get_canvas_item(), f)
	frame.set_border_width_all(maxi(3, int(w * 0.6)))
	frame.border_color = Palette.ARMOR[0]
	frame.draw(c.get_canvas_item(), f.grow(-w * 0.2))
	var hl := f.position + Vector2(size * CORNER_RATIO, w * 0.35)
	c.draw_line(hl, hl + Vector2(size * (1.0 - 2.0 * CORNER_RATIO), 0), Color(Palette.ARMOR[1], 0.8), maxf(2.0, w * 0.25), true)
	for p in [Vector2(0.12, 0.12), Vector2(0.88, 0.12), Vector2(0.88, 0.88), Vector2(0.12, 0.88)]:
		var at: Vector2 = f.position + p * size
		c.draw_circle(at, size * 0.035, Palette.ARMOR[2])
		c.draw_circle(at + Vector2(-1, -1), size * 0.022, Palette.ARMOR[1])


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


## v0.6: a switch escaped - this arrow reverses (half a turn).
func play_flip(new_direction: int, delay: float = 0.0) -> void:
	data.direction = new_direction
	if _turn_tween and _turn_tween.is_valid():
		_turn_tween.kill()
	var exact := Direction.angle(new_direction)
	var target := arrow_angle + PI
	target = exact + TAU * roundf((target - exact) / TAU)
	_turn_tween = create_tween()
	if delay > 0.0:
		_turn_tween.tween_interval(delay)
	_turn_tween.tween_property(self, "arrow_angle", target, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash = 0.8
	create_tween().tween_property(self, "flash", 0.0, 0.3).set_delay(delay)


## v0.6: this block rammed a shelled block - dash forward and bounce back.
func play_ram(amount: float) -> void:
	position = home
	var fwd := Direction.vector(data.direction)
	var t := _new_tween()
	t.tween_property(self, "position", home + fwd * amount, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "position", home, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## v0.6: the shell breaks (the overlay is redrawn without it).
func play_crack(delay: float) -> void:
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_callback(func():
		data.armored = false
		flash = 1.0
		_over.queue_redraw())
	t.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "flash", 0.0, 0.3)


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
