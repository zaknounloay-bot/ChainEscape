class_name LevelSelect
extends ColorRect
## Level grid grouped by Chapter (v0.5). Each Chapter header shows its
## number and name in the Chapter's own colors, stars collected / 30, a
## "complete" tick and the Chapter chest tiers (claimable right here).
## Tiles show number, best stars, completed/locked state, a Mystery marker,
## a Silver/Gold gem while a reward block is still uncollected, and a crown
## on the Master Level. No world map (intentionally).

signal level_chosen(number: int)
signal chest_claim(chapter: int, tier: int)

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
	var title := _label("CHAPTERS", 44, Palette.TEXT)
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


## `chapters`: Array of GameManager.chapter_summary() dictionaries, each
## with "levels" (Array of {number, stars, unlocked, completed, mystery,
## reward, master, current}) and "unlocked".
func open(chapters: Array, total_stars: int, max_stars: int, current_chapter: int) -> void:
	for c in _list.get_children():
		c.queue_free()
	for info in chapters:
		_list.add_child(_chapter_header(info))
		var grid := GridContainer.new()
		grid.columns = COLUMNS
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		var center := CenterContainer.new()
		center.add_child(grid)
		_list.add_child(center)
		for lv in info["levels"]:
			var tile := LevelTile.new(lv)
			tile.pressed.connect(func():
				if lv["unlocked"]:
					level_chosen.emit(lv["number"])
					close())
			grid.add_child(tile)
	_title_stars.text = "%d / %d ★" % [total_stars, max_stars]
	visible = true
	# Scroll to the current Chapter.
	await get_tree().process_frame
	for c in _list.get_children():
		if c.has_meta("chapter") and c.get_meta("chapter") == current_chapter:
			_scroll.scroll_vertical = int(c.position.y)


func close() -> void:
	visible = false


func _chapter_header(info: Dictionary) -> Control:
	var t: Dictionary = info["theme"]
	var c: int = info["chapter"]
	var panel := PanelContainer.new()
	panel.set_meta("chapter", c)
	var st := StyleBoxFlat.new()
	st.bg_color = t["bg_bottom"] if t["dark"] else t["bg_top"].lerp(t["bg_bottom"], 0.6)
	st.border_color = t["accent"]
	st.border_width_left = 10
	st.set_corner_radius_all(22)
	st.set_content_margin_all(16)
	st.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", st)
	if not info["unlocked"]:
		panel.modulate = Color(1, 1, 1, 0.55)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(names)
	var kicker := _label("CHAPTER %d%s" % [c, "  ✓" if info["completed"] else ""], 20, t["accent"] if t["dark"] else t["accent"].darkened(0.2))
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(kicker)
	var nm := _label(String(t["name"]).to_upper(), 28, t["text"])
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(nm)
	row.add_child(_label("%d/%d ★" % [info["stars"], info["max_stars"]], 26, t["text"]))
	var chests := HBoxContainer.new()
	chests.alignment = BoxContainer.ALIGNMENT_CENTER
	chests.add_theme_constant_override("separation", 10)
	col.add_child(chests)
	for i in info["tiers"].size():
		chests.add_child(chest_button(c, i, info["tiers"][i], func(): chest_claim.emit(c, i)))
	return panel


## One Chapter-chest tier as a pill: "20★" (not yet), glowing gold when
## claimable, "✓" once claimed. Shared with the Chapter Complete card.
static func chest_button(chapter: int, tier: int, info: Dictionary, on_claim: Callable) -> PillButton:
	var text := "✓" if info["claimed"] else "%d★" % info["stars"]
	var bg := Palette.GOLD if info["claimable"] else (Palette.SLOT if not info["claimed"] else Palette.BACKGROUND)
	var b := PillButton.new(text, PillButton.Icon.CHEST, bg, Palette.TEXT, 20, true)
	b.custom_minimum_size = Vector2(128, 60)
	b.disabled = not info["claimable"]
	var items := ""
	for item in info["items"]:
		items += " + %d %s" % [info["items"][item], item]
	b.tooltip_text = "%s chest: %d coins%s" % [info["name"], info["coins"], items]
	b.set_meta("chapter", chapter)
	b.set_meta("tier", tier)
	b.pressed.connect(on_claim)
	return b


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
		var master: bool = info["master"]
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
		if info["reward"] > 0 and info["unlocked"]:
			# Uncollected Silver/Gold block on this level: a reason to replay.
			var metal: Array = Palette.METALS[info["reward"]]
			var g := Vector2(20, 20)
			var gs := 12.0
			draw_colored_polygon(PackedVector2Array([g + Vector2(0, -gs), g + Vector2(gs, 0), g + Vector2(0, gs), g + Vector2(-gs, 0)]), metal[2])
			draw_colored_polygon(PackedVector2Array([g + Vector2(0, -gs * 0.6), g + Vector2(gs * 0.6, 0), g + Vector2(0, gs * 0.6), g + Vector2(-gs * 0.6, 0)]), metal[0])
