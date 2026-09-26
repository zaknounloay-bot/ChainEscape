class_name LevelSelect
extends ColorRect
## Level grid grouped by World. Each World shows its name and stars; each
## group of 10 levels has a Treasure Chest row (3 star thresholds). Tiles
## show number, best stars, completed/locked state, a Mystery marker and a
## crown on the Master Level. No world map (intentionally).

signal level_chosen(number: int)
signal chest_claim(group: int, tier: int)

const COLUMNS := 5

var _list: VBoxContainer
var _title_stars: Label
var _scroll: ScrollContainer


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
	var title := _label("LEVELS", 48, Palette.TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_title_stars = _label("", 26, Palette.TEXT_SOFT)
	_title_stars.custom_minimum_size = Vector2(150, 0)
	_title_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_title_stars)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)


## `levels`: Array of {number, stars, unlocked, completed, mystery, current}.
## `chests`: group -> Array of {stars, coins, claimed, claimable}; `group_stars`: group -> int.
func open(levels: Array, total_stars: int, chests: Dictionary, group_stars: Dictionary) -> void:
	for c in _list.get_children():
		c.queue_free()
	var current_world := 1
	for w in range(1, Worlds.THEMES.size() + 1):
		var rg := Worlds.world_range(w)
		if rg.x > levels.size():
			break
		var world_levels := levels.slice(rg.x - 1, mini(rg.y, levels.size()))
		var stars := 0
		for info in world_levels:
			stars += info["stars"]
			if info["current"]:
				current_world = w
		var head := _world_header(w, stars, world_levels.size() * 3)
		_list.add_child(head)
		for g in range(2):
			var group := (rg.x - 1) / 10 + g
			var gl := world_levels.slice(g * 10, g * 10 + 10)
			if gl.is_empty():
				continue
			var grid := GridContainer.new()
			grid.columns = COLUMNS
			grid.add_theme_constant_override("h_separation", 14)
			grid.add_theme_constant_override("v_separation", 14)
			var center := CenterContainer.new()
			center.add_child(grid)
			_list.add_child(center)
			for info in gl:
				var tile := LevelTile.new(info)
				tile.pressed.connect(func():
					if info["unlocked"]:
						level_chosen.emit(info["number"])
						close())
				grid.add_child(tile)
			if chests.has(group):
				_list.add_child(_chest_row(group, chests[group], group_stars.get(group, 0)))
	_title_stars.text = "%d / %d ★" % [total_stars, levels.size() * 3]
	visible = true
	# Scroll to the current World.
	await get_tree().process_frame
	var target := 0.0
	var seen := 0
	for c in _list.get_children():
		if c.has_meta("world"):
			seen = c.get_meta("world")
			if seen == current_world:
				target = c.position.y
	_scroll.scroll_vertical = int(target)


func close() -> void:
	visible = false


func _world_header(w: int, stars: int, max_stars: int) -> Control:
	var t: Dictionary = Worlds.THEMES[w - 1]
	var panel := PanelContainer.new()
	panel.set_meta("world", w)
	var st := StyleBoxFlat.new()
	st.bg_color = t["bg_bottom"]
	st.set_corner_radius_all(22)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var name := _label("WORLD %d  ·  %s" % [w, String(t["name"]).to_upper()], 26, t["text"])
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name)
	row.add_child(_label("%d/%d ★" % [stars, max_stars], 24, t["text"]))
	return panel


func _chest_row(group: int, tiers: Array, have: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var rg := Economy.group_range(group)
	row.add_child(_label("%d-%d  ★%d" % [rg.x, rg.y, have], 20, Palette.TEXT_SOFT))
	for i in tiers.size():
		var tier: Dictionary = tiers[i]
		var text := "✓" if tier["claimed"] else "%d★" % tier["stars"]
		var bg := Palette.GOLD if tier["claimable"] else (Palette.SLOT if not tier["claimed"] else Palette.BACKGROUND)
		var b := PillButton.new(text, PillButton.Icon.CHEST, bg, Palette.TEXT, 20, true)
		b.custom_minimum_size = Vector2(128, 60)
		b.disabled = not tier["claimable"]
		b.tooltip_text = "%d coins" % tier["coins"]
		b.pressed.connect(func(): chest_claim.emit(group, i))
		row.add_child(b)
	return row


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Palette.font(900))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


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
		var master: bool = info["number"] == Worlds.MASTER_LEVEL
		if not info["unlocked"]:
			st.bg_color = Palette.SLOT
		elif info["current"]:
			st.bg_color = Palette.ACCENT
		elif master:
			st.bg_color = Color("#241E10")
		else:
			st.bg_color = Palette.WHITE
		if master:
			st.border_color = Palette.GOLD
			st.set_border_width_all(4)
		st.shadow_color = Palette.SHADOW if info["unlocked"] else Color(0, 0, 0, 0)
		st.shadow_size = 6
		st.shadow_offset = Vector2(0, 3)
		st.draw(get_canvas_item(), r)
		var ink := Palette.WHITE if info["current"] else (Palette.GOLD if master else Palette.TEXT)
		var font := Palette.font(900)
		if info["unlocked"]:
			var txt := str(info["number"])
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
			draw_string(font, Vector2((size.x - w) * 0.5, 62), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 42, ink)
			for i in 3:
				var c := Vector2(size.x * 0.5 + (i - 1) * 30, 96)
				Shapes.draw_star(self, c, 12, Palette.GOLD if i < info["stars"] else Color(ink, 0.18))
		else:
			var c := Vector2(size.x * 0.5, 64)
			draw_arc(c + Vector2(0, -8), 13, PI, TAU, 16, Palette.TEXT_SOFT, 6, true)
			var body := StyleBoxFlat.new()
			body.bg_color = Palette.TEXT_SOFT
			body.set_corner_radius_all(6)
			body.draw(get_canvas_item(), Rect2(c + Vector2(-20, -8), Vector2(40, 30)))
		if master:
			# Crown.
			var c2 := Vector2(size.x * 0.5, 16)
			draw_colored_polygon(PackedVector2Array([c2 + Vector2(-16, 8), c2 + Vector2(-16, -6), c2 + Vector2(-8, 2),
				c2 + Vector2(0, -10), c2 + Vector2(8, 2), c2 + Vector2(16, -6), c2 + Vector2(16, 8)]), Palette.GOLD)
		elif info["mystery"]:
			var b := Vector2(size.x - 18, 18)
			draw_circle(b, 16, Palette.PURPLE_BADGE)
			var qw := font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, b + Vector2(-qw * 0.5, 8), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.WHITE)
