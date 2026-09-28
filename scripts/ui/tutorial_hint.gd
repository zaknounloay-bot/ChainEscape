class_name TutorialHint
extends Node2D
## Minimal contextual guidance: an animated "finger" tapping a target block
## plus one short line of text under the board. Disappears on interaction.

const CYCLE := 1.3

## Message color; follows the Chapter theme (light text on dark Chapters).
static var text_color: Color = Palette.TEXT

var _text: String = ""
var _target := Vector2.ZERO  # canvas position of the block to tap
var _text_pos := Vector2.ZERO
var _show_finger := false
var _time := 0.0
var _fade_tween: Tween


var _label: Part
var _finger: Part
var _ripple: Part


func _ready() -> void:
	z_index = 50
	_ripple = _part(_draw_ripple)
	_finger = _part(_draw_finger)
	_label = _part(_draw_text)
	modulate.a = 0.0
	visible = false


## Show text (and, if `finger` is true, a tapping indicator on `target`).
func show_hint(text: String, text_pos: Vector2, target: Vector2 = Vector2.ZERO, finger: bool = false) -> void:
	_text = text
	_text_pos = text_pos
	_target = target
	_show_finger = finger
	_time = 0.0
	visible = true
	_fade_to(1.0, 0.25)
	_label.queue_redraw()


func _part(fn: Callable) -> Part:
	var p := Part.new()
	p.fn = fn
	add_child(p)
	return p


func hide_hint(immediate: bool = false) -> void:
	if not visible:
		return
	if immediate:
		modulate.a = 0.0
		visible = false
		return
	_fade_to(0.0, 0.18).finished.connect(func(): visible = false)


func is_showing() -> bool:
	return visible and modulate.a > 0.0


func _fade_to(alpha: float, time: float) -> Tween:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, time)
	return _fade_tween


## Per frame: only positions, scales and alphas change. The text, finger
## and ripple are drawn once (a per-frame redraw would create new GPU
## buffers every frame on Web).
func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_label.position = Vector2(0, sin(_time * 3.0) * 3.0)
	_finger.visible = _show_finger
	_ripple.visible = _show_finger
	if not _show_finger:
		return
	var t := fmod(_time, CYCLE) / CYCLE
	var approach := clampf(t / 0.3, 0.0, 1.0)
	approach = 1.0 - pow(1.0 - approach, 3.0)
	var lift := clampf((t - 0.65) / 0.35, 0.0, 1.0)
	var offset := Vector2(46, 70) * (1.0 - approach) + Vector2(46, 70) * lift
	var pressed := t > 0.3 and t < 0.65
	# Press slightly below-right of center so the arrow stays readable.
	var press_at := _target + Vector2(22, 30)
	_finger.position = press_at + offset
	_finger.scale = Vector2.ONE * (0.85 if pressed else 1.0)
	_finger.modulate.a = minf(approach * 1.5, 1.0) * (1.0 - lift)
	# Ripple ring right after the "press".
	_ripple.position = press_at
	var rt := clampf((t - 0.3) / 0.5, 0.0, 1.0) if t > 0.3 else 0.0
	_ripple.scale = Vector2.ONE * (24.0 + rt * 46.0) / 24.0
	_ripple.modulate.a = (1.0 - rt) if t > 0.3 else 0.0


func _draw_text(c: CanvasItem) -> void:
	if _text == "":
		return
	var font := Palette.font(800)
	var size := 30
	var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	# Shrink long lines to fit the screen width.
	var max_w := get_viewport_rect().size.x - 48.0
	while w > max_w and size > 18:
		size -= 1
		w = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string(font, _text_pos + Vector2(-w * 0.5, 0), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, text_color)


func _draw_ripple(c: CanvasItem) -> void:
	c.draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 6.0 / 1.5, true)


## A soft fingertip (at the origin) with its shadow and the finger body
## trailing toward the bottom-right like a hand.
func _draw_finger(c: CanvasItem) -> void:
	var radius := 26.0
	var body_dir := Vector2(0.55, 1.0).normalized()
	var shadow := Color(0, 0, 0, 0.18)
	var sh := Vector2(4, 6)
	c.draw_line(sh, sh + body_dir * 70.0, shadow, radius * 2.0, true)
	c.draw_circle(sh, radius, shadow)
	var edge := Color(Palette.TEXT, 0.55)
	c.draw_line(Vector2.ZERO, body_dir * 70.0, edge, radius * 2.0 + 5.0, true)
	c.draw_circle(Vector2.ZERO, radius + 2.5, edge)
	c.draw_line(Vector2.ZERO, body_dir * 70.0, Color.WHITE, radius * 2.0, true)
	c.draw_circle(Vector2.ZERO, radius, Color.WHITE)


class Part extends Node2D:
	var fn: Callable

	func _draw() -> void:
		fn.call(self)
