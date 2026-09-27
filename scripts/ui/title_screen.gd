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
	_stats.add_theme_font_size_override("font_size", 24)
	box.add_child(_stats)


func open(has_progress: bool, level: int, stars: int, coins: int, theme: Dictionary) -> void:
	_continue.text = ("CONTINUE  -  LEVEL %d" % level) if has_progress else "PLAY"
	_stats.text = ("%d ★    %d COINS" % [stars, coins]) if has_progress else "Tap a block. Let it escape."
	_stats.add_theme_color_override("font_color", theme["text_soft"])
	_title_color = theme["text"]
	_continue.set_background(theme["accent"].darkened(0.1) if theme["dark"] else theme["accent"])
	_bg_top = theme["bg_top"]
	_bg_bottom = theme["bg_bottom"]
	visible = true


func close() -> void:
	visible = false


var _title_color := Palette.TEXT
var _bg_top := Palette.BACKGROUND
var _bg_bottom := Palette.BACKGROUND


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


## Logo: the name plus three little blocks escaping in a loop.
func _draw() -> void:
	# Opaque World-tinted backdrop so nothing of the game shows through.
	var bands := 32
	for i in bands:
		draw_rect(Rect2(0, size.y * i / bands, size.x, size.y / bands + 1.0), _bg_top.lerp(_bg_bottom, float(i) / (bands - 1)))
	var cx := size.x * 0.5
	var y := size.y * 0.5 - 260.0
	var font := Palette.font(900)
	for i in 2:
		var word: String = ["CHAIN", "ESCAPE"][i]
		var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x
		draw_string(font, Vector2(cx - w * 0.5, y + i * 96), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 92, _title_color)
	var colors := ["red", "blue", "yellow"]
	for i in 3:
		var t := fmod(_time * 0.6 + i * 0.33, 1.0)
		var x := cx - 90 + i * 90 + (t * t) * 160.0
		var a := 1.0 - t
		var st := StyleBoxFlat.new()
		st.bg_color = Color(Palette.face(colors[i]), a)
		st.set_corner_radius_all(14)
		st.anti_aliasing = true
		st.draw(get_canvas_item(), Rect2(Vector2(x - 30, y + 150), Vector2(60, 60)))
		var ac := Color(Palette.arrow(colors[i]), a)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 16, y + 180), Vector2(x - 6, y + 166), Vector2(x - 6, y + 194)]), ac)
		draw_rect(Rect2(Vector2(x - 18, y + 175), Vector2(14, 10)), ac)
