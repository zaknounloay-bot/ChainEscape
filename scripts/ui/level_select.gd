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
var _total_label: Label
var _scroll: ScrollContainer

## v0.6.3 touch scrolling (iPhone QA: swipes that started on a level tile or
## a Chapter header did nothing - those controls stopped the touch before
## the ScrollContainer saw it). Now every touch inside the list is handled
## here, in _input, before any control: past TAP_SLOP pixels it is a drag
## (the list follows the finger, then keeps gliding), otherwise a tap on
## whatever is under the finger. The list's children ignore the mouse.
const TAP_SLOP := 12.0
const FLING_DECAY := 3.2  # per second (iOS-like glide)
var _tappables: Array[Control] = []
var _touching := false
var _touch_index := -1  # the finger being followed (Web may number them from 1)
var _dragging := false
var _press_pos := Vector2.ZERO
var _drag_origin_y := 0.0
var _drag_origin_scroll := 0.0
var _samples: Array = []  # [time_s, y] of the last moves, for the fling speed
var _fling := 0.0
var _scroll_f := 0.0


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
	_total_label = _label("", 22, Palette.TEXT_SOFT)
	box.add_child(_total_label)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	_scroll.add_child(_list)
	# After the list has moved (next frame): positions measured right at the
	# scroll change are still those of the previous offset.
	_scroll.get_v_scroll_bar().value_changed.connect(func(_v): _publish_after_layout())


## `chapters`: Array of GameManager.chapter_summary() dictionaries, each
## with "levels" (Array of {number, stars, unlocked, completed, mystery,
## reward, master, current}) and "unlocked".
func open(chapters: Array, total_stars: int, max_stars: int, current_chapter: int, total_score: int = 0) -> void:
	for c in _list.get_children():
		c.queue_free()
	_tappables.clear()
	_touching = false
	_dragging = false
	_fling = 0.0
	set_process(false)
	var era_shown := 0
	_last_level = 0
	for info in chapters:
		for lv in info.get("levels", []):
			_last_level = maxi(_last_level, int(lv["number"]))
	for info in chapters:
		# v0.6: a simple divider where each era begins.
		var era := Chapters.era_of_chapter(info["chapter"])
		if era["index"] != era_shown and String(era["name"]) != "":
			era_shown = era["index"]
			_list.add_child(_era_divider(era, info))
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
	# Taps and drags are resolved in _input; nothing in the list may stop a
	# touch on its own.
	_ignore_mouse(_list)
	_title_stars.text = "%d / %d ★" % [total_stars, max_stars]
	_total_label.text = "TOTAL SCORE  %s" % UIManager._fmt(total_score)
	visible = true
	# Scroll to the current Chapter.
	await get_tree().process_frame
	for c in _list.get_children():
		if c.has_meta("chapter") and c.get_meta("chapter") == current_chapter:
			_scroll.scroll_vertical = int(c.position.y)
	_publish()


func close() -> void:
	visible = false
	_touching = false
	_dragging = false
	_fling = 0.0
	set_process(false)
	_publish()


func _ignore_mouse(node: Node) -> void:
	for c in node.get_children():
		if c is Control:
			if c is BaseButton:
				_tappables.append(c)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var area := _scroll.get_global_rect()
	if event is InputEventScreenTouch and (not _touching or event.index == _touch_index):
		if event.pressed:
			if not area.has_point(event.position):
				return
			_touching = true
			_touch_index = event.index
			_dragging = false
			_fling = 0.0
			set_process(false)
			_press_pos = event.position
			_samples = [[Time.get_ticks_msec() / 1000.0, event.position.y]]
			get_viewport().set_input_as_handled()
		elif _touching:
			_touching = false
			if _dragging:
				_dragging = false
				_start_fling()
			else:
				_tap_at(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touching and event.index == _touch_index:
		var y: float = event.position.y
		if not _dragging and absf(y - _press_pos.y) > TAP_SLOP:
			# Start following the finger from here (no jump).
			_dragging = true
			_drag_origin_y = y
			_drag_origin_scroll = _scroll.scroll_vertical
		if _dragging:
			_set_scroll(_drag_origin_scroll - (y - _drag_origin_y))
			_samples.append([Time.get_ticks_msec() / 1000.0, y])
			if _samples.size() > 6:
				_samples.pop_front()
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventMouseMotion and event.button_mask != 0):
		# The same gesture again as emulated mouse events: already handled
		# as touch above (touch is emulated from the mouse on desktop too).
		if area.has_point(event.position) or _touching:
			get_viewport().set_input_as_handled()


func _set_scroll(value: float) -> void:
	var bar := _scroll.get_v_scroll_bar()
	_scroll_f = clampf(value, 0.0, maxf(bar.max_value - bar.page, 0.0))
	_scroll.scroll_vertical = int(round(_scroll_f))


## Keeps gliding after a flick, slowing down like iOS lists.
func _start_fling() -> void:
	if _samples.size() < 2:
		return
	var a: Array = _samples[0]
	var b: Array = _samples[-1]
	var dt: float = b[0] - a[0]
	if dt <= 0.0 or Time.get_ticks_msec() / 1000.0 - b[0] > 0.12:
		return  # the finger stopped before lifting: no glide
	_fling = -(b[1] - a[1]) / dt
	_scroll_f = _scroll.scroll_vertical
	set_process(absf(_fling) > 30.0)


func _process(delta: float) -> void:
	_fling *= exp(-FLING_DECAY * delta)
	var before := _scroll_f
	_set_scroll(_scroll_f + _fling * delta)
	if absf(_fling) < 30.0 or is_equal_approx(before, _scroll_f):
		_fling = 0.0
		set_process(false)


## A tap (the finger barely moved): the tile or chest button under it.
func _tap_at(pos: Vector2) -> void:
	for b in _tappables:
		if is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(pos):
			b.pressed.emit()
			return


var _publish_pending := false


func _publish_after_layout() -> void:
	if _publish_pending or not OS.has_feature("web"):
		return
	_publish_pending = true
	await get_tree().process_frame
	_publish_pending = false
	_publish()


## Web only (browser tests): scroll position plus the screen positions of a
## visible level tile, Chapter header and empty gap, so a real-touch test
## can start swipes on each. Published on scroll changes only.
func _publish() -> void:
	if not WebBridge.available():
		return
	var vis := get_viewport().get_visible_rect().size
	var inner := _scroll.get_global_rect().grow(-40.0)
	var norm := func(p: Vector2) -> Array:
		return [snappedf(p.x / vis.x, 0.0001), snappedf(p.y / vis.y, 0.0001)]
	var tile := []  # any visible tile (locked tiles used to block swipes too)
	var open_tile := []  # a visible UNLOCKED tile (tap test)
	var open_number := 0
	var header := []
	var gap := []
	for c in _list.get_children():
		var r: Rect2 = c.get_global_rect()
		if header.is_empty() and c.has_meta("chapter"):
			var hp := r.position + Vector2(r.size.x * 0.3, 30.0)
			if inner.has_point(hp):
				header = norm.call(hp)
		if c is CenterContainer:
			for t in c.get_child(0).get_children():
				var tc: Vector2 = t.get_global_rect().get_center()
				if not t is LevelTile or not inner.has_point(tc):
					continue
				if tile.is_empty():
					tile = norm.call(tc)
					# Left of the grid on the same row: no tile, no header.
					gap = norm.call(Vector2(_scroll.get_global_rect().position.x + 6, tc.y))
				if open_tile.is_empty() and t.info["unlocked"]:
					open_tile = norm.call(tc)
					open_number = t.info["number"]
	WebBridge.publish("chainEscapeSelect", {"open": visible, "scroll": _scroll.scroll_vertical,
		"max": int(_scroll.get_v_scroll_bar().max_value - _scroll.get_v_scroll_bar().page),
		"tile": tile, "header": header, "gap": gap, "open_tile": open_tile, "open_number": open_number})


## Highest level number in the list being shown.
var _last_level := 0


## "SECOND ERA  ·  LEVELS 101-200" between the eras.
func _era_divider(era: Dictionary, info: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.set_meta("era", era["index"])
	if era["index"] > 1:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 18)
		box.add_child(gap)
	var t: Dictionary = info["theme"]
	var title := _label(String(era["name"]).to_upper(), 34, t["accent"] if era["index"] > 1 else Palette.TEXT)
	box.add_child(title)
	# v0.7: an era still being built (the Third Era, 201-300) names only the
	# levels that exist ("LEVELS 201-225").
	var sub := _label("LEVELS %d-%d" % [era["from"], mini(int(era["to"]), _last_level) if _last_level > 0 else era["to"]], 18, Palette.TEXT_SOFT)
	box.add_child(sub)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 4)
	line.color = Color(t["accent"], 0.8) if era["index"] > 1 else Color(Palette.TEXT_SOFT, 0.4)
	box.add_child(line)
	return box


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
		if info.get("milestone", false) and info["unlocked"]:
			# v0.6 milestone: a small golden ring on top.
			draw_arc(Vector2(size.x * 0.5, 14), 9, 0.0, TAU, 20, Palette.GOLD, 4, true)
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
