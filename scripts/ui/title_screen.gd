class_name TitleScreen
extends Control
## Launch screen: CONTINUE - LEVEL X (or PLAY for a new player) and LEVEL
## SELECT. The first tap here also unlocks audio on mobile browsers.

signal continue_pressed
signal level_select_pressed

var _continue: PillButton
var _stats: Label
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	add_child(box)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 330)
	box.add_child(spacer)
	_continue = PillButton.new("PLAY", PillButton.Icon.NONE, Palette.ACCENT, Palette.WHITE, 36)
	_continue.custom_minimum_size = Vector2(460, 120)
	_continue.pressed.connect(func(): continue_pressed.emit())
	box.add_child(_continue)
	var ls := PillButton.new("LEVEL SELECT", PillButton.Icon.GRID, Palette.WHITE, Palette.TEXT, 30)
	ls.custom_minimum_size = Vector2(460, 100)
	ls.pressed.connect(func(): level_select_pressed.emit())
	box.add_child(ls)
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_font_override("font", Palette.font(800))
	_stats.add_theme_constant_override("line_spacing", 6)
	_stats.add_theme_font_size_override("font_size", 24)
	box.add_child(_stats)
	# Save diagnostic for device testing (source, version, unlocks, total,
	# time of the last successful save, storage context).
	_diag = Label.new()
	_diag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_diag.offset_top = -96.0
	_diag.offset_bottom = -24.0
	_diag.offset_left = 24.0
	_diag.offset_right = -24.0
	_diag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_diag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diag.add_theme_font_override("font", Palette.font(700))
	_diag.add_theme_font_size_override("font_size", 15)
	_diag.modulate.a = 0.75
	add_child(_diag)


var _diag: Label


func set_diagnostic(text: String) -> void:
	_diag.text = text


func open(has_progress: bool, level: int, stars: int, coins: int, theme: Dictionary, total_score: int = 0) -> void:
	_continue.text = ("CONTINUE  -  LEVEL %d" % level) if has_progress else "PLAY"
	var where := "MASTER LEVEL" if Chapters.is_master(level) else Chapters.title(Chapters.chapter_of(level))
	_stats.text = ("%s\nTOTAL SCORE %s\n%d ★    %d COINS" % [where, UIManager._fmt(total_score), stars, coins]) if has_progress else "Tap a block. Let it escape."
	_stats.add_theme_color_override("font_color", theme["text_soft"])
	_diag.add_theme_color_override("font_color", theme["text_soft"])
	_title_color = theme["text"]
	_continue.set_background(theme["accent"].darkened(0.1) if theme["dark"] else theme["accent"])
	_bg_top = theme["bg_top"]
	_bg_bottom = theme["bg_bottom"]
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


var _title_color := Palette.TEXT:
	set(v):
		_title_color = v
		queue_redraw()
var _bg_top := Palette.BACKGROUND
var _bg_bottom := Palette.BACKGROUND
## The three escaping logo blocks: drawn once, animated by position/alpha
## only (a per-frame redraw would create new GPU buffers every frame on Web).
var _logo_blocks: Array[Node2D] = []


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _logo_blocks.is_empty():
		for i in 3:
			var b := LogoBlock.new()
			b.color_name = ["red", "blue", "yellow"][i]
			add_child(b)
			_logo_blocks.append(b)
	var cx := size.x * 0.5
	var y := size.y * 0.5 - 260.0
	for i in 3:
		var t := fmod(_time * 0.6 + i * 0.33, 1.0)
		_logo_blocks[i].position = Vector2(cx - 90 + i * 90 + (t * t) * 160.0, y + 180)
		_logo_blocks[i].modulate.a = 1.0 - t


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Backdrop and the name. Redrawn only when the theme or size changes.
func _draw() -> void:
	# Opaque Chapter-tinted backdrop so nothing of the game shows through.
	# Rect bands, not a gradient polygon (no new GPU buffers per draw).
	var bands := 32
	for b in bands:
		var y0 := size.y * b / bands
		var y1 := size.y * (b + 1) / bands
		draw_rect(Rect2(0, y0, size.x, y1 - y0 + 1.0), _bg_top.lerp(_bg_bottom, (b + 0.5) / bands))
	var cx := size.x * 0.5
	var y := size.y * 0.5 - 260.0
	var font := Palette.font(900)
	for i in 2:
		var word: String = ["CHAIN", "ESCAPE"][i]
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
		draw_string(font, Vector2(cx - w * 0.5, y + i * 96), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, _title_color)


class LogoBlock extends Node2D:
	var color_name := "red"

	func _draw() -> void:
		var st := StyleBoxFlat.new()
		st.bg_color = Palette.face(color_name)
		st.set_corner_radius_all(14)
		st.anti_aliasing = true
		st.draw(get_canvas_item(), Rect2(Vector2(-30, -30), Vector2(60, 60)))
		var ac := Palette.arrow(color_name)
		draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(-6, -14), Vector2(-6, 14)]), ac)
		draw_rect(Rect2(Vector2(-18, -5), Vector2(14, 10)), ac)
