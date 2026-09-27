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


func _ready() -> void:
	z_index = 50
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
	queue_redraw()


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


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	if _show_finger:
		_draw_finger()
	if _text != "":
		var font := Palette.font(800)
		var size := 30
		var w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		# Shrink long lines to fit the screen width.
		var max_w := get_viewport_rect().size.x - 48.0
		while w > max_w and size > 18:
			size -= 1
			w = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var bob := sin(_time * 3.0) * 3.0
		draw_string(font, _text_pos + Vector2(-w * 0.5, bob), _text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, text_color)


## A soft fingertip that presses the target, then a ripple ring.
func _draw_finger() -> void:
	var t := fmod(_time, CYCLE) / CYCLE
	var approach := clampf(t / 0.3, 0.0, 1.0)
	approach = 1.0 - pow(1.0 - approach, 3.0)
	var lift := clampf((t - 0.65) / 0.35, 0.0, 1.0)
	var offset := Vector2(46, 70) * (1.0 - approach) + Vector2(46, 70) * lift
	var alpha := minf(approach * 1.5, 1.0) * (1.0 - lift)
	var pressed := t > 0.3 and t < 0.65
	var radius := 26.0 * (0.85 if pressed else 1.0)
	# Press slightly below-right of center so the arrow stays readable.
	var tip := _target + Vector2(22, 30) + offset
	# Ripple ring right after the "press".
	if t > 0.3:
		var rt := clampf((t - 0.3) / 0.5, 0.0, 1.0)
		draw_arc(_target + Vector2(22, 30), 24.0 + rt * 46.0, 0.0, TAU, 48, Color(1, 1, 1, 0.9 * (1.0 - rt)), 6.0, true)
	# Finger: shadow, then a white fingertip with a thin outline, then the
	# finger body trailing toward the bottom-right like a hand.
	var body_dir := Vector2(0.55, 1.0).normalized()
	var shadow := Color(0, 0, 0, 0.18 * alpha)
	draw_line(tip + Vector2(4, 6), tip + Vector2(4, 6) + body_dir * 70.0, shadow, radius * 2.0, true)
	draw_circle(tip + Vector2(4, 6), radius, shadow)
	var fill := Color(1, 1, 1, alpha)
	var edge := Color(Palette.TEXT, 0.55 * alpha)
	draw_line(tip, tip + body_dir * 70.0, edge, radius * 2.0 + 5.0, true)
	draw_circle(tip, radius + 2.5, edge)
	draw_line(tip, tip + body_dir * 70.0, fill, radius * 2.0, true)
	draw_circle(tip, radius, fill)
