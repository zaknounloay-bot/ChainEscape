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
## 0..1 white flash drawn over the face (used on tap).
var flash: float = 0.0:
	set(v):
		flash = v
		queue_redraw()


func setup(p_data: BlockData, p_cell_size: float) -> void:
	data = p_data
	set_cell_size(p_cell_size)


func set_cell_size(value: float) -> void:
	cell_size = value
	var radius := int(round(cell_size * FACE_RATIO * CORNER_RATIO))
	for s in [_face_style, _side_style]:
		s.set_corner_radius_all(radius)
		s.anti_aliasing = true
		s.anti_aliasing_size = 1.2
	_face_style.bg_color = Palette.face(data.color)
	_side_style.bg_color = Palette.side(data.color)
	_side_style.shadow_color = Palette.SHADOW
	_side_style.shadow_size = int(cell_size * 0.08)
	_side_style.shadow_offset = Vector2(0, cell_size * 0.04)
	queue_redraw()


func _draw() -> void:
	var size := cell_size * FACE_RATIO
	var depth := cell_size * DEPTH_RATIO
	# Face sits slightly above center so face + side look centered in the cell.
	var face_rect := Rect2(Vector2(-size, -size - depth) * 0.5, Vector2(size, size))
	var side_rect := Rect2(face_rect.position + Vector2(0, depth), face_rect.size)
	_side_style.draw(get_canvas_item(), side_rect)
	_face_style.draw(get_canvas_item(), face_rect)
	_draw_arrow(face_rect.get_center(), size)
	if flash > 0.0:
		var fs := _face_style.duplicate() as StyleBoxFlat
		fs.bg_color = Color(1, 1, 1, 0.35 * flash)
		fs.shadow_size = 0
		fs.draw(get_canvas_item(), face_rect)


## Chunky white arrow: rectangular shaft + triangular head.
func _draw_arrow(center: Vector2, size: float) -> void:
	var fwd := Direction.vector(data.direction)
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
	var col := Color(1, 1, 1, 0.97)
	draw_colored_polygon(shaft, col)
	draw_colored_polygon(head, col)
	# Anti-aliased outlines smooth the polygon edges.
	shaft.append(shaft[0])
	head.append(head[0])
	draw_polyline(shaft, col, 1.5, true)
	draw_polyline(head, col, 1.5, true)


# --- Animations ------------------------------------------------------------

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

