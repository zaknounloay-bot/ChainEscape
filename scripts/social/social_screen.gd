class_name SocialScreen
extends Control
## Social MVP 0.1: CREATE CHALLENGE navigation skeleton (UI only).
## Choice page with the two Social tracks, plus one placeholder page per
## track. Opened from the title screen, drawn over it, and never touches
## game state, progress, saves or audio settings - closing it simply shows
## the title again.
##
## Motion is decorative and cheap: a handful of faint blocks drawn once and
## only moved (no per-frame redraw), plus short Tween entrances. All of it
## is skipped when the browser asks for reduced motion.

enum Page { CHOICE, PHOTO_REVEAL, CHALLENGE_FRIEND }

## Each track has its own identity color: warm purple/pink for Photo,
## cool blue/cyan for Friend (icon face, card border tint).
const TRACKS := {
	Page.PHOTO_REVEAL: {
		"title": "PHOTO / MESSAGE\nREVEAL",
		"copy": "Hide a photo or message behind a\nChain Escape challenge.",
		"color": Color("#C645E6"),
		"tint": Color("#EBCBF7"),
		"dir": Vector2.UP,
	},
	Page.CHALLENGE_FRIEND: {
		"title": "CHALLENGE A FRIEND",
		"copy": "Create a puzzle and challenge\nsomeone to escape.",
		"color": Color("#1A9FE6"),
		"tint": Color("#C3E6F8"),
		"dir": Vector2.RIGHT,
	},
}
const CARD_WIDTH := 580.0
const CARD_HEIGHT := 262.0
const ICON_SIZE := 52.0
## Background motif: faint blocks that start as one chain and escape.
const DRIFTERS := 7
const DRIFT_ALPHA := 0.10
const TAP_DELAY := 0.12

static var _reduced_motion_checked := false
static var _reduced_motion := false

var page: int = Page.CHOICE
var _pages: Dictionary = {}  # Page -> Control
var _headings: Array[Label] = []
var _soft_labels: Array[Label] = []
var _bg_top := Palette.BACKGROUND
var _bg_bottom := Palette.BACKGROUND
var _drifters: Array[Dictionary] = []  # {node, dir, speed}
var _drift_time := 0.0
var _entrance: Tween
var _entering: Control  # column waiting for its entrance to start
var _tap: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_drifters()
	_pages[Page.CHOICE] = _build_choice()
	for p in [Page.PHOTO_REVEAL, Page.CHALLENGE_FRIEND]:
		_pages[p] = _build_placeholder(p)


func open(theme: Dictionary) -> void:
	_bg_top = theme["bg_top"]
	_bg_bottom = theme["bg_bottom"]
	for l in _headings:
		l.add_theme_color_override("font_color", theme["text"])
	for l in _soft_labels:
		l.add_theme_color_override("font_color", theme["text_soft"])
	visible = true
	show_page(Page.CHOICE)
	_start_drift()
	queue_redraw()


func close() -> void:
	_stop_animations()
	visible = false
	page = Page.CHOICE
	set_process(false)


func is_open() -> bool:
	return visible


func show_page(p: int) -> void:
	_stop_animations()
	page = p
	for k in _pages:
		_pages[k].visible = k == p
	if visible:
		_animate_in(_pages[p])


## BACK: a track placeholder returns to the choice page, the choice page
## returns to the title.
func back() -> void:
	if page == Page.CHOICE:
		close()
	else:
		show_page(Page.CHOICE)


# --- Pages ---------------------------------------------------------------------

func _build_choice() -> Control:
	var box := _column()
	box.add_child(_heading("CREATE CHALLENGE"))
	box.add_child(_soft("Choose what to send.", 26))
	for p in [Page.PHOTO_REVEAL, Page.CHALLENGE_FRIEND]:
		box.add_child(_track_card(p))
	box.add_child(_back_button())
	return box


func _build_placeholder(p: int) -> Control:
	var info: Dictionary = TRACKS[p]
	var box := _column()
	box.add_child(_heading(info["title"]))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(Palette.WHITE, info["tint"]))
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	box.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 18)
	card.add_child(inner)
	inner.add_child(_icon_holder(info))
	inner.add_child(_label(info["copy"], 26, Palette.TEXT, 800))
	var soon := _label("CREATION FLOW COMING SOON", 24, info["color"].darkened(0.15), 900)
	soon.name = "ComingSoon"
	inner.add_child(soon)
	box.add_child(_back_button())
	return box


## Full-rect center column; hidden until its page is shown.
func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	box.visible = false
	add_child(box)
	return box


## White card, the whole card is the touch target: icon on top, then the
## centered title and description (explicit line breaks, never wrapped
## mid-phrase, never under the icon).
func _track_card(p: int) -> PillButton:
	var info: Dictionary = TRACKS[p]
	var card := PillButton.new("", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 30)
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.name = "Card_%s" % ("Photo" if p == Page.PHOTO_REVEAL else "Friend")
	var tint: Color = info["tint"]
	card.add_theme_stylebox_override("normal", _card_style(Palette.WHITE, tint))
	card.add_theme_stylebox_override("hover", _card_style(Palette.WHITE, tint))
	card.add_theme_stylebox_override("pressed", _card_style(Palette.WHITE.darkened(0.04), tint))
	card.add_theme_stylebox_override("hover_pressed", _card_style(Palette.WHITE.darkened(0.04), tint))
	card.pressed.connect(func(): _on_card(p))
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 24.0
	content.offset_right = -24.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 10)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(content)
	content.add_child(_icon_holder(info))
	var title := _label(info["title"], 30, Palette.TEXT, 900)
	title.add_theme_constant_override("line_spacing", -2)
	content.add_child(title)
	var gap := Control.new()  # extra air between title and description
	gap.custom_minimum_size = Vector2(0, 2)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(gap)
	var copy := _label(info["copy"], 22, Palette.TEXT_SOFT, 700)
	content.add_child(copy)
	# Grow with the content if a device's font runs taller than expected.
	var fit := func():
		card.custom_minimum_size.y = maxf(CARD_HEIGHT, content.get_combined_minimum_size().y + 40.0)
	content.minimum_size_changed.connect(fit)
	fit.call_deferred()
	return card


## Short press response (PillButton's scale bounce) before navigating.
func _on_card(p: int) -> void:
	if _tap and _tap.is_running():
		return
	AudioManager.play_ui_tap()
	_tap = create_tween()
	_tap.tween_interval(0.0 if _reduced_motion else TAP_DELAY)
	_tap.tween_callback(func():
		_tap = null
		if visible and page == Page.CHOICE:
			show_page(p))


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(40)
	s.anti_aliasing = true
	s.set_border_width_all(3)
	s.border_color = border
	s.set_content_margin_all(30)
	s.shadow_color = Palette.SHADOW
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s


## A centered, fixed-size slot holding the track's block icon.
func _icon_holder(info: Dictionary) -> Control:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(slot)
	var icon := EscapeBlock.new()
	icon.face = info["color"]
	icon.dir = info["dir"]
	icon.half = ICON_SIZE * 0.5
	icon.position = Vector2(ICON_SIZE, ICON_SIZE) * 0.5
	slot.add_child(icon)
	return holder


func _back_button() -> PillButton:
	var b := PillButton.new("BACK", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 30)
	b.custom_minimum_size = Vector2(460, 100)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.name = "Back"
	b.pressed.connect(func():
		AudioManager.play_ui_tap()
		back())
	return b


func _heading(t: String) -> Label:
	var l := _label(t, 46, Palette.TEXT, 900)
	_headings.append(l)
	return l


func _soft(t: String, fs: int) -> Label:
	var l := _label(t, fs, Palette.TEXT_SOFT, 800)
	_soft_labels.append(l)
	return l


## Centered label; line breaks come only from the text itself.
func _label(t: String, fs: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


# --- Motion --------------------------------------------------------------------

## Web: honor the system "reduce motion" setting (read once, no eval).
static func reduced_motion() -> bool:
	if not _reduced_motion_checked:
		_reduced_motion_checked = true
		if OS.has_feature("web"):
			var w := JavaScriptBridge.get_interface("window")
			if w and w.matchMedia:
				var mq = w.matchMedia("(prefers-reduced-motion: reduce)")
				_reduced_motion = mq != null and bool(mq.matches)
	return _reduced_motion


## Entrance: heading, first card, second card, then BACK - a short fade and
## slide each. Items stay tappable throughout.
func _animate_in(box: Control) -> void:
	if reduced_motion():
		return
	for c in box.get_children():
		c.modulate.a = 0.0
	_entering = box
	_begin_entrance.call_deferred(box, 2)


## Deferred twice so the column has its final size and child positions
## (visibility, minimum size and sorting are all deferred updates) before
## the slide reads them. A final re-sort guarantees the resting layout.
func _begin_entrance(box: Control, defers_left: int) -> void:
	if defers_left > 0:
		_begin_entrance.call_deferred(box, defers_left - 1)
		return
	if _entering != box or not visible or not box.visible:
		return
	_entering = null
	var items := box.get_children()
	var t := create_tween().set_parallel(true)
	_entrance = t
	var delay := 0.0
	for i in items.size():
		var c: Control = items[i]
		var base_y := c.position.y
		c.position.y = base_y + 34.0
		t.tween_property(c, "position:y", base_y, 0.34).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(c, "modulate:a", 1.0, 0.26).set_delay(delay)
		# Heading and subtitle arrive together; each card and BACK follow.
		delay += 0.04 if i == 0 and items.size() > 4 else 0.1
	t.chain().tween_callback(box.queue_sort)


## Kills any running entrance / tap and leaves every item fully visible
## and placed by its container.
func _stop_animations() -> void:
	if _entrance:
		_entrance.kill()
		_entrance = null
	_entering = null
	if _tap:
		_tap.kill()
		_tap = null
	for k in _pages:
		for c in _pages[k].get_children():
			c.modulate.a = 1.0
		_pages[k].queue_sort()


func _build_drifters() -> void:
	var colors := ["red", "blue", "yellow", "purple", "green", "blue", "red"]
	var dirs := [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]
	for i in DRIFTERS:
		var b := EscapeBlock.new()
		b.face = Palette.face(colors[i])
		b.dir = dirs[i]
		b.half = 26.0 + (i % 3) * 6.0
		b.modulate.a = DRIFT_ALPHA
		add_child(b)
		_drifters.append({"node": b, "dir": dirs[i], "speed": 16.0 + (i * 7) % 13})


## On open the faint blocks sit in one chain across the top, then break
## apart and drift off in their arrow's direction.
func _start_drift() -> void:
	var reduced := reduced_motion()
	var w := maxf(size.x, 720.0)
	var gap := 78.0
	var x0 := w * 0.5 - gap * (DRIFTERS - 1) * 0.5
	var y := maxf(size.y, 1280.0) * 0.11
	for i in _drifters.size():
		var node: Node2D = _drifters[i]["node"]
		node.position = Vector2(x0 + gap * i, y + (18.0 if i % 2 else 0.0))
		node.visible = true
	_drift_time = 0.0
	set_process(not reduced)


func _process(delta: float) -> void:
	if not visible:
		set_process(false)
		return
	_drift_time += delta
	# A quick burst when the chain opens, easing into a slow drift.
	var burst := 240.0 * exp(-_drift_time * 3.0)
	var margin := 70.0
	for d in _drifters:
		var node: Node2D = d["node"]
		node.position += d["dir"] * (d["speed"] + burst) * delta
		# Escaped past an edge: re-enter from the opposite side.
		if node.position.x < -margin:
			node.position.x = size.x + margin
		elif node.position.x > size.x + margin:
			node.position.x = -margin
		if node.position.y < -margin:
			node.position.y = size.y + margin
		elif node.position.y > size.y + margin:
			node.position.y = -margin


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Same opaque Chapter-tinted backdrop as the title (rect bands, redrawn
## only on open / resize).
func _draw() -> void:
	var bands := 32
	for b in bands:
		var y0 := size.y * b / bands
		var y1 := size.y * (b + 1) / bands
		draw_rect(Rect2(0, y0, size.x, y1 - y0 + 1.0), _bg_top.lerp(_bg_bottom, (b + 0.5) / bands))


## A Chain Escape block with its arrow, drawn once (moved, never redrawn).
class EscapeBlock extends Node2D:
	var face := Palette.face("blue")
	var dir := Vector2.RIGHT
	var half := 30.0

	func _draw() -> void:
		var st := StyleBoxFlat.new()
		st.bg_color = face.darkened(0.18)
		st.set_corner_radius_all(int(half * 0.45))
		st.anti_aliasing = true
		st.draw(get_canvas_item(), Rect2(Vector2(-half, -half + half * 0.12), Vector2(half, half) * 2.0))
		st.bg_color = face
		st.draw(get_canvas_item(), Rect2(Vector2(-half, -half), Vector2(half * 2.0, half * 2.0 - half * 0.1)))
		var s := half / 30.0
		var side := Vector2(-dir.y, dir.x)
		var tip := dir * 16.0 * s
		var back := -dir * 6.0 * s
		draw_colored_polygon(PackedVector2Array([tip, back + side * 14.0 * s, back - side * 14.0 * s]), Color.WHITE)
		var tail := PackedVector2Array([back + side * 5.0 * s, back - side * 5.0 * s,
				-dir * 18.0 * s - side * 5.0 * s, -dir * 18.0 * s + side * 5.0 * s])
		draw_colored_polygon(tail, Color.WHITE)
