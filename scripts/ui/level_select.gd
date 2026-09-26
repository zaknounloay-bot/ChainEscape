class_name LevelSelect
extends ColorRect
## Simple level grid: number, best stars, locked/completed state and a
## marker on Mystery levels. No world map (intentionally).

signal level_chosen(number: int)

const COLUMNS := 5

var _grid: GridContainer
var _title_stars: Label


func _init() -> void:
	color = Palette.BACKGROUND
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 40
	box.offset_left = 24
	box.offset_right = -24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var back := PillButton.new("BACK", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 26)
	back.custom_minimum_size = Vector2(150, 76)
	back.pressed.connect(close)
	header.add_child(back)
	var title := Label.new()
	title.text = "LEVELS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Palette.font(900))
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Palette.TEXT)
	header.add_child(title)
	_title_stars = Label.new()
	_title_stars.custom_minimum_size = Vector2(150, 0)
	_title_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title_stars.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_stars.add_theme_font_override("font", Palette.font(900))
	_title_stars.add_theme_font_size_override("font_size", 26)
	_title_stars.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	header.add_child(_title_stars)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	center.add_child(_grid)


## `levels`: Array of {number, stars, unlocked, completed, mystery, current}.
func open(levels: Array, total_stars: int) -> void:
	for c in _grid.get_children():
		c.queue_free()
	for info in levels:
		var tile := LevelTile.new(info)
		tile.pressed.connect(func():
			if info["unlocked"]:
				level_chosen.emit(info["number"])
				close())
		_grid.add_child(tile)
	_title_stars.text = "%d / %d ★" % [total_stars, levels.size() * 3]
	visible = true


func close() -> void:
	visible = false


class LevelTile extends Button:
	var info: Dictionary

	func _init(p_info: Dictionary) -> void:
		info = p_info
		custom_minimum_size = Vector2(118, 132)
		focus_mode = Control.FOCUS_NONE
		flat = true
		disabled = not info["unlocked"]

	func _draw() -> void:
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(24)
		st.anti_aliasing = true
		var r := Rect2(Vector2(0, 0), size - Vector2(0, 6))
		if not info["unlocked"]:
			st.bg_color = Palette.SLOT
		elif info["current"]:
			st.bg_color = Palette.ACCENT
		else:
			st.bg_color = Palette.WHITE
		st.shadow_color = Palette.SHADOW if info["unlocked"] else Color(0, 0, 0, 0)
		st.shadow_size = 6
		st.shadow_offset = Vector2(0, 3)
		st.draw(get_canvas_item(), r)
		var ink := Palette.WHITE if info["current"] else Palette.TEXT
		var font := Palette.font(900)
		if info["unlocked"]:
			var txt := str(info["number"])
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
			draw_string(font, Vector2((size.x - w) * 0.5, 62), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, ink)
			for i in 3:
				var c := Vector2(size.x * 0.5 + (i - 1) * 30, 96)
				Shapes.draw_star(self, c, 12, Palette.GOLD if i < info["stars"] else Color(ink, 0.18))
		else:
			# Padlock.
			var c := Vector2(size.x * 0.5, 64)
			draw_arc(c + Vector2(0, -8), 13, PI, TAU, 16, Palette.TEXT_SOFT, 6, true)
			var body := StyleBoxFlat.new()
			body.bg_color = Palette.TEXT_SOFT
			body.set_corner_radius_all(6)
			body.draw(get_canvas_item(), Rect2(c + Vector2(-20, -8), Vector2(40, 30)))
		if info["mystery"]:
			# "?" badge in the corner.
			var b := Vector2(size.x - 18, 18)
			draw_circle(b, 16, Palette.PURPLE_BADGE)
			var qw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, b + Vector2(-qw * 0.5, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.WHITE)
