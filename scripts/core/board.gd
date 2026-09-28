class_name Board
extends Node2D
## Visual board: turns grid coordinates into screen positions, owns the
## BlockViews, plays feedback and reports taps.
##
## It never decides rules. GameManager asks the BoardModel what is legal and
## then tells the Board what to play.

signal block_tapped(id: int)

const PADDING_CELLS := 0.22  # panel padding around the grid, in cells
const MAX_CELL := 150.0

var rows: int = 0
var columns: int = 0
var cell_size: float = 100.0
var input_enabled: bool = true
## Chapter theme colors for the board panel and empty slots.
var board_color: Color = Palette.BOARD
var slot_color: Color = Palette.SLOT
## Chapter accent: used by celebration particles.
var accent_color: Color = Palette.ACCENT
## Chapter whose block material is applied (tests / debugging).
var block_style_id: int = 0
## Reward block ids (this level) already collected on an earlier run:
## they are drawn "spent". Set by GameManager before build().
var spent_rewards: Dictionary = {}
## Hammer mode: the next tap smashes a block instead of moving it.
var hammer_mode: bool = false:
	set(v):
		hammer_mode = v
		queue_redraw()
## Mystery levels get a slightly deeper board tint.
var mystery: bool = false:
	set(v):
		mystery = v
		queue_redraw()
var show_coords: bool = false:
	set(v):
		show_coords = v
		queue_redraw()
		if _coords_layer:
			_coords_layer.queue_redraw()

## id -> BlockView for blocks that are on the board (escaping ones are removed).
var _views: Dictionary = {}
var _panel_style := StyleBoxFlat.new()
var _slot_style := StyleBoxFlat.new()
var _dot_texture: Texture2D
var _rest_position := Vector2.ZERO
var _pulse_tween: Tween
@onready var _blocks_root := Node2D.new()
@onready var _fx_root := Node2D.new()
@onready var _coords_layer := Node2D.new()  # debug labels, drawn above blocks


func _ready() -> void:
	add_child(_blocks_root)
	add_child(_fx_root)
	add_child(_coords_layer)
	_coords_layer.draw.connect(_draw_coords)
	_panel_style.bg_color = Palette.BOARD
	_panel_style.anti_aliasing = true
	_slot_style.bg_color = Palette.SLOT
	_slot_style.anti_aliasing = true
	_dot_texture = _make_dot_texture()


# --- Building & layout -----------------------------------------------------

## Creates views for a freshly loaded level.
func build(p_rows: int, p_columns: int, blocks: Array, animate: bool) -> void:
	rows = p_rows
	columns = p_columns
	for v in _blocks_root.get_children():
		v.queue_free()
	for v in _fx_root.get_children():
		v.queue_free()
	_views.clear()
	for b in blocks:
		var view := _create_view(b)
		if animate:
			view.play_appear(0.018 * (b.cell.x + b.cell.y))
	queue_redraw()


## Fits the board inside `area` (in canvas coordinates) and centers it.
func layout(area: Rect2) -> void:
	if rows == 0 or columns == 0:
		return
	var w := columns + PADDING_CELLS * 2.0
	var h := rows + PADDING_CELLS * 2.0
	cell_size = floorf(minf(minf(area.size.x / w, area.size.y / h), MAX_CELL))
	_rest_position = (area.get_center() - Vector2(columns, rows) * cell_size * 0.5).round()
	if _pulse_tween:
		_pulse_tween.kill()
	scale = Vector2.ONE
	position = _rest_position
	for id in _views:
		var view: BlockView = _views[id]
		view.set_cell_size(cell_size)
		view.home = cell_to_local(view.data.cell)
		view.position = view.home
	queue_redraw()


## Center of a grid cell in board-local coordinates. x = column, y = row.
func cell_to_local(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func local_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell_size), floori(p.y / cell_size))


## Screen-space (canvas) rectangle of the whole board panel.
func get_board_rect() -> Rect2:
	var pad := PADDING_CELLS * cell_size
	return Rect2(_rest_position - Vector2(pad, pad), Vector2(columns, rows) * cell_size + Vector2(pad, pad) * 2.0)


## Live effect + block nodes (diagnostics: must not grow across levels).
func fx_count() -> int:
	return _fx_root.get_child_count() + _blocks_root.get_child_count()


func get_view(id: int) -> BlockView:
	return _views.get(id)


func _create_view(b: BlockData) -> BlockView:
	var view := BlockView.new()
	view.setup(b.duplicate_data(), cell_size)
	view.reward_spent = b.is_reward() and spent_rewards.has(b.id)
	view.home = cell_to_local(b.cell)
	view.position = view.home
	_blocks_root.add_child(view)
	_views[b.id] = view
	return view


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	if rows == 0:
		return
	var pad := PADDING_CELLS * cell_size
	_panel_style.bg_color = board_color.darkened(0.08) if mystery else board_color
	_slot_style.bg_color = slot_color.darkened(0.08) if mystery else slot_color
	_panel_style.border_color = Color("#FF4D4D")
	_panel_style.set_border_width_all(6 if hammer_mode else 0)
	_panel_style.set_corner_radius_all(int(cell_size * 0.28))
	_panel_style.draw(get_canvas_item(), Rect2(Vector2(-pad, -pad), Vector2(columns, rows) * cell_size + Vector2(pad, pad) * 2.0))
	_slot_style.set_corner_radius_all(int(cell_size * 0.18))
	var slot := cell_size * 0.80
	for r in rows:
		for c in columns:
			var center := cell_to_local(Vector2i(c, r))
			_slot_style.draw(get_canvas_item(), Rect2(center - Vector2(slot, slot) * 0.5, Vector2(slot, slot)))
	_coords_layer.queue_redraw()


## Debug overlay: "column,row" in the corner of every cell.
func _draw_coords() -> void:
	if not show_coords:
		return
	for r in rows:
		for c in columns:
			var corner := Vector2(c, r) * cell_size + Vector2(cell_size * 0.1, cell_size * 0.26)
			_coords_layer.draw_string(Palette.font(800), corner + Vector2(2, 2), "%d,%d" % [c, r],
					HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell_size * 0.17), Color(0, 0, 0, 0.5))
			_coords_layer.draw_string(Palette.font(800), corner, "%d,%d" % [c, r],
					HORIZONTAL_ALIGNMENT_LEFT, -1, int(cell_size * 0.17), Color.WHITE)


# --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	# Touch only: desktop mouse clicks are converted to touches via
	# input_devices/pointing/emulate_touch_from_mouse, so taps fire exactly once.
	if event is InputEventScreenTouch and event.pressed:
		var local: Vector2 = (make_input_local(event) as InputEventScreenTouch).position
		var id := _find_block_near(local)
		if id != -1:
			get_viewport().set_input_as_handled()
			block_tapped.emit(id)


## Block under the finger; small gaps between blocks still count as a hit.
func _find_block_near(local: Vector2) -> int:
	var cell := local_to_cell(local)
	for id in _views:
		if _views[id].data.cell == cell:
			return id
	return -1


# --- Feedback --------------------------------------------------------------

## Sends a block off-screen. `chain` makes the effect a touch stronger.
## `turned` = spinner ids the escape turned (from BoardModel.remove).
func play_escape(id: int, chain: int, turned: Array = []) -> void:
	var view: BlockView = _views.get(id)
	if view == null:
		return
	_views.erase(id)
	if view.hinted:
		view.hinted = false
	animate_turns(turned)
	var dir := Direction.vector(view.data.direction)
	var duration := clampf(0.28 - 0.012 * (chain - 1), 0.20, 0.28)
	var tween := view.play_escape(_offscreen_point(view.home, dir), duration)
	tween.finished.connect(view.queue_free)
	var ghost := EscapeGhost.new()
	ghost.size = cell_size * BlockView.FACE_RATIO
	ghost.color = Palette.face(view.data.color)
	ghost.strength = 1.0 + 0.08 * mini(chain, 8)
	ghost.position = view.home
	_fx_root.add_child(ghost)
	_burst(view.home, -dir, Palette.face(view.data.color), 5 + mini(chain, 8), 0.8 + 0.05 * mini(chain, 8), 70.0)
	if chain >= 5:
		_pulse(0.008 + 0.002 * mini(chain - 5, 5))


## Blocked tap: nudge the tapped block and make the blocker react.
func play_bump(id: int, blocker_id: int) -> void:
	var view: BlockView = _views.get(id)
	if view == null:
		return
	view.play_bump(cell_size * 0.12)
	var blocker: BlockView = _views.get(blocker_id)
	if blocker:
		var dist := (blocker.home - view.home).length() / cell_size
		blocker.play_hit(view.data.direction, cell_size * 0.05, 0.05 + 0.015 * dist)


## Spinners turned by an escape/smash: animate each by its own rule.
func animate_turns(turned: Array) -> void:
	for sid in turned:
		var sv: BlockView = _views.get(sid)
		if sv:
			var cw := sv.data.next_turn_cw()
			var d := sv.data.direction
			sv.data.spin_step += 1
			sv.play_turn(Direction.rotate_cw(d) if cw else Direction.rotate_ccw(d), cw, 0.05)


## Makes views match the model after an Undo. Returning blocks fly back in.
func sync_to(blocks: Array) -> void:
	var wanted := {}
	for b in blocks:
		wanted[b.id] = b
	for id in _views.keys():
		if not wanted.has(id):
			_views[id].queue_free()
			_views.erase(id)
	for id in wanted:
		if _views.has(id):
			var existing: BlockView = _views[id]
			if existing.data.direction != wanted[id].direction:
				# A spinner turned back by Undo: animate the reverse of the
				# turn it made.
				var undone_cw := BlockData.turn_is_cw(wanted[id].spin_rule, wanted[id].spin_step)
				existing.play_turn(wanted[id].direction, not undone_cw)
			existing.data.spin_step = wanted[id].spin_step
			if existing.data.hidden != wanted[id].hidden:
				# A mystery arrow hidden again by Undo.
				existing.data.hidden = wanted[id].hidden
				existing.refresh()
			continue
		var view := _create_view(wanted[id])
		view.play_return(_offscreen_point(view.home, Direction.vector(view.data.direction)).lerp(view.home, 0.55))


## Chapter look: board and slot tint, accent, and the block material
## (Palette.block_style) re-applied to every block on the board.
func set_theme(t: Dictionary) -> void:
	board_color = t["board"]
	slot_color = t["slot"]
	accent_color = t["accent"]
	Palette.block_style = t["block_style"]
	block_style_id = t["id"]
	for id in _views:
		_views[id].refresh_style()
	queue_redraw()


## Silver / Gold block escaped by normal play: metal sparkles and a quick
## expanding ring at its old position. Short, never blocks input.
func play_reward(at_local: Vector2, rarity: int) -> void:
	var metal: Array = Palette.METALS[rarity]
	var gold := rarity >= BlockData.Rarity.GOLD
	_burst(at_local, Vector2.UP, metal[1], 16 if gold else 10, 1.2, 180.0)
	_burst(at_local, Vector2.UP, metal[0], 12 if gold else 8, 1.0, 180.0)
	var ring := RewardRing.new()
	ring.color = metal[0]
	ring.max_radius = cell_size * (0.95 if gold else 0.75)
	ring.position = at_local
	_fx_root.add_child(ring)
	_pulse(0.012 if gold else 0.006)


class RewardRing extends Node2D:
	## Drawn once at full size; the tween only scales and fades it (a
	## per-frame redraw would create new GPU buffers every frame on Web).
	var color := Color.WHITE
	var max_radius := 60.0

	func _ready() -> void:
		z_index = 30
		scale = Vector2.ONE * 0.3
		var t := create_tween()
		t.tween_property(self, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "modulate:a", 0.0, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_callback(queue_free)

	func _draw() -> void:
		draw_arc(Vector2.ZERO, max_radius, 0.0, TAU, 40, Color(color, 0.9), 4.0, true)


## Hammer smash: shake, crack burst, then the block is gone.
func play_smash(id: int) -> void:
	var view: BlockView = _views.get(id)
	if view == null:
		return
	_views.erase(id)
	var home := view.home
	var t := view.create_tween()
	t.tween_property(view, "scale", Vector2(1.15, 0.85), 0.06)
	t.tween_property(view, "scale", Vector2(0.2, 0.2), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(view, "modulate:a", 0.0, 0.14)
	t.tween_callback(view.queue_free)
	_burst(home, Vector2.UP, Palette.face(view.data.color), 22, 1.3, 180.0)
	_burst(home, Vector2.DOWN, Color("#FFFFFF"), 10, 1.0, 180.0)
	_pulse(0.02)


## Shows every view's padlock according to the model (no animation).
func refresh_locks(model: BoardModel) -> void:
	for id in _views:
		_views[id].set_locked(model.is_locked(id), false)


func play_unlocks(ids: Array) -> void:
	for id in ids:
		var v: BlockView = _views.get(id)
		if v:
			v.set_locked(false, true)
			_burst(v.home, Vector2.UP, Palette.face(v.data.lock_color), 12, 1.0, 180.0)


func play_reveals(ids: Array) -> void:
	for i in ids.size():
		var v: BlockView = _views.get(ids[i])
		if v:
			v.play_reveal()


## Locked block tapped: rattle it and make its key blocks hop.
func play_locked_tap(id: int, key_ids: Array) -> void:
	var v: BlockView = _views.get(id)
	if v:
		v.play_rattle()
	for i in key_ids.size():
		var k: BlockView = _views.get(key_ids[i])
		if k:
			k.play_key_pulse(0.05 * i)


## Hidden block tapped: small wobble (not a mistake).
func play_hidden_tap(id: int) -> void:
	var v: BlockView = _views.get(id)
	if v:
		v.play_key_pulse()


## Floating "+120" at a block's position.
func show_points(at_local: Vector2, text: String, color: Color = Palette.ACCENT) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Palette.font(900))
	l.add_theme_font_size_override("font_size", int(clampf(cell_size * 0.3, 22, 38)))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.WHITE)
	l.add_theme_constant_override("outline_size", 6)
	l.z_index = 40
	_fx_root.add_child(l)
	l.reset_size()
	l.position = at_local - l.size * 0.5
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - cell_size * 0.7, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
	t.tween_callback(l.queue_free)


## Highlights one block as the hint (clears any previous highlight).
func set_hint(id: int) -> void:
	for vid in _views:
		_views[vid].hinted = (vid == id)


func clear_hint() -> void:
	set_hint(-1)


## Screen position of a block's center (for tutorial fingers etc.).
func block_screen_position(id: int) -> Vector2:
	var view: BlockView = _views.get(id)
	return to_global(view.home) if view else global_position


## Short celebration when the board is cleared.
func celebrate() -> void:
	var center := Vector2(columns, rows) * cell_size * 0.5
	var colors := Palette.BLOCKS.keys()
	for i in colors.size():
		var angle := -PI * 0.5 + (i - 2) * 0.35
		_burst(center, Vector2.from_angle(angle), Palette.face(colors[i]), 14, 1.6, 70.0)
	# A ring of the World's accent color.
	_burst(center, Vector2.UP, accent_color, 18, 1.4, 180.0)
	_pulse(0.025)


## Smallest distance that moves a block fully outside the visible screen.
func _offscreen_point(from: Vector2, dir: Vector2) -> Vector2:
	var screen := get_global_transform_with_canvas().affine_inverse() * get_viewport().get_visible_rect()
	var margin := cell_size
	var dist := 0.0
	if dir.x > 0:
		dist = screen.end.x - from.x + margin
	elif dir.x < 0:
		dist = from.x - screen.position.x + margin
	elif dir.y > 0:
		dist = screen.end.y - from.y + margin
	else:
		dist = from.y - screen.position.y + margin
	return from + dir * dist


func _pulse(strength: float) -> void:
	# Scale around the board center so it feels like a gentle "thump".
	var center := Vector2(columns, rows) * cell_size * 0.5
	if _pulse_tween:
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.tween_method(func(s: float):
		scale = Vector2(s, s)
		position = _rest_position + center * (1.0 - s), 1.0 + strength, 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _burst(at: Vector2, dir: Vector2, color: Color, amount: int, speed_scale: float, spread: float = 40.0) -> void:
	var p := CPUParticles2D.new()
	p.texture = _dot_texture
	p.position = at
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.45 * speed_scale
	p.direction = dir
	p.spread = spread
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = cell_size * 1.6 * speed_scale
	p.initial_velocity_max = cell_size * 3.2 * speed_scale
	p.damping_min = cell_size * 4.0
	p.damping_max = cell_size * 6.0
	p.scale_amount_min = cell_size * 0.0025
	p.scale_amount_max = cell_size * 0.005
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = cell_size * 0.2
	_fx_root.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _make_dot_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.55, Color(1, 1, 1, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex
