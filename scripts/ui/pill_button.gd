class_name PillButton
extends Button
## Rounded button with an optional hand-drawn icon (no image assets needed).

enum Icon { NONE, UNDO, RESTART, HINT, GEAR }

var icon_kind: int = Icon.NONE
## Small counter bubble in the top-right corner ("" = hidden).
var badge_text: String = "":
	set(v):
		badge_text = v
		queue_redraw()
## Horizontal position of the icon center.
var icon_x: float = 50.0
var _press_tween: Tween


func _init(p_text: String = "", p_icon: int = Icon.NONE, bg: Color = Palette.WHITE, fg: Color = Palette.TEXT, font_size: int = 30, compact: bool = false) -> void:
	text = p_text
	icon_kind = p_icon
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	add_theme_font_override("font", Palette.font(800))
	add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, fg)
	add_theme_color_override("font_disabled_color", Color(fg, 0.35))
	var left_pad := (84 if not compact else 68) if icon_kind != Icon.NONE else 36
	if p_text == "":
		left_pad = 0
	_right_pad = 36 if not compact else 22
	if p_text == "":
		_right_pad = 0
	icon_x = 50.0 if not compact else 36.0
	add_theme_stylebox_override("normal", _style(bg, left_pad))
	add_theme_stylebox_override("hover", _style(bg, left_pad))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", _style(bg.darkened(0.06), left_pad))
	add_theme_stylebox_override("hover_pressed", _style(bg.darkened(0.06), left_pad))
	add_theme_stylebox_override("disabled", _style(Color(bg, 0.55), left_pad, false))
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	resized.connect(func(): pivot_offset = size * 0.5)


var _right_pad := 36


func _style(bg: Color, left_pad: int, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(48)
	s.anti_aliasing = true
	s.content_margin_left = left_pad
	s.content_margin_right = _right_pad
	s.content_margin_top = 18
	s.content_margin_bottom = 18
	if shadow:
		s.shadow_color = Palette.SHADOW
		s.shadow_size = 10
		s.shadow_offset = Vector2(0, 4)
	return s


func _on_down() -> void:
	_animate_scale(0.95, 0.05)


func _on_up() -> void:
	_animate_scale(1.0, 0.12)


func _animate_scale(target: float, time: float) -> void:
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.tween_property(self, "scale", Vector2(target, target), time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	if badge_text != "":
		_draw_badge()
	if icon_kind == Icon.NONE:
		return
	var col: Color = get_theme_color("font_disabled_color" if disabled else "font_color")
	var c := Vector2(icon_x if text != "" else size.x * 0.5, size.y * 0.5)
	var r := 15.0
	var w := 5.0
	if icon_kind == Icon.UNDO:
		# U-turn: arrowhead pointing left at the top, curving round the right.
		var head := c + Vector2(-r * 0.9, -r * 0.8)
		draw_line(head + Vector2(4, 0), c + Vector2(0, -r * 0.8), col, w, true)
		draw_arc(c + Vector2(0, r * 0.1), r * 0.9, -PI * 0.5, PI * 0.5, 24, col, w, true)
		draw_line(c + Vector2(0, r), c + Vector2(-r * 0.6, r), col, w, true)
		_arrow_head(head, Vector2.LEFT, col)
	elif icon_kind == Icon.RESTART:
		# Circular arrow with a gap at the top.
		var a0 := -PI / 3.0
		var a1 := PI * 4.0 / 3.0
		draw_arc(c, r, a0, a1, 32, col, w, true)
		_arrow_head(c + Vector2.from_angle(a1) * r, Vector2(-sin(a1), cos(a1)), col)


	elif icon_kind == Icon.HINT:
		# Light bulb.
		draw_arc(c + Vector2(0, -4), 12.0, PI * 0.75, PI * 2.25, 28, col, w, true)
		draw_line(c + Vector2(-8, 6), c + Vector2(-5, 12), col, w, true)
		draw_line(c + Vector2(8, 6), c + Vector2(5, 12), col, w, true)
		draw_line(c + Vector2(-6, 14), c + Vector2(6, 14), col, w, true)
		draw_line(c + Vector2(-4, 19), c + Vector2(4, 19), col, w, true)
	elif icon_kind == Icon.GEAR:
		for k in 8:
			var a := TAU * k / 8.0
			draw_line(c + Vector2.from_angle(a) * 11.0, c + Vector2.from_angle(a) * 18.0, col, 6.0, true)
		draw_arc(c, 12.0, 0.0, TAU, 32, col, 5.0, true)
		draw_arc(c, 4.0, 0.0, TAU, 16, col, 3.0, true)


func _draw_badge() -> void:
	var font := Palette.font(900)
	var fs := 22
	var w := maxf(34.0, font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0)
	var rect := Rect2(Vector2(size.x - w * 0.75, -10), Vector2(w, 34))
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.HINT if badge_text != "0" else Palette.TEXT_SOFT
	st.set_corner_radius_all(17)
	st.anti_aliasing = true
	st.border_color = Palette.WHITE
	st.set_border_width_all(3)
	st.draw(get_canvas_item(), rect)
	var tw := font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(rect.get_center().x - tw * 0.5, rect.position.y + 25), badge_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.TEXT)


func _arrow_head(at: Vector2, dir: Vector2, col: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([at + dir * 9.0, at - dir * 3.0 + side * 9.0, at - dir * 3.0 - side * 9.0])
	draw_colored_polygon(pts, col)
	pts.append(pts[0])
	draw_polyline(pts, col, 1.0, true)
