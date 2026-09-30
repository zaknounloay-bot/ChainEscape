class_name SocialScreen
extends Control
## Social MVP 0.1: CREATE CHALLENGE navigation skeleton (UI only).
## Choice page with the two Social tracks, plus one placeholder page per
## track. Opened from the title screen, drawn over it, and never touches
## game state, progress, saves or audio settings - closing it simply shows
## the title again.

enum Page { CHOICE, PHOTO_REVEAL, CHALLENGE_FRIEND }

const TRACKS := {
	Page.PHOTO_REVEAL: {
		"title": "PHOTO / MESSAGE REVEAL",
		"copy": "Hide a photo or message behind a Chain Escape challenge.",
		"block": "purple",
	},
	Page.CHALLENGE_FRIEND: {
		"title": "CHALLENGE A FRIEND",
		"copy": "Create a puzzle and challenge someone to escape.",
		"block": "blue",
	},
}
const CARD_WIDTH := 560.0

var page: int = Page.CHOICE
var _pages: Dictionary = {}  # Page -> Control
var _headings: Array[Label] = []
var _soft_labels: Array[Label] = []
var _bg_top := Palette.BACKGROUND
var _bg_bottom := Palette.BACKGROUND


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	show_page(Page.CHOICE)
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	page = Page.CHOICE


func is_open() -> bool:
	return visible


func show_page(p: int) -> void:
	page = p
	for k in _pages:
		_pages[k].visible = k == p


## BACK: a track placeholder returns to the choice page, the choice page
## returns to the title.
func back() -> void:
	if page == Page.CHOICE:
		close()
	else:
		show_page(Page.CHOICE)


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
	var heading := _heading(info["title"])
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	box.add_child(heading)
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.WHITE
	st.set_corner_radius_all(40)
	st.anti_aliasing = true
	st.set_content_margin_all(36)
	st.shadow_color = Palette.SHADOW
	st.shadow_size = 10
	st.shadow_offset = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	box.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 16)
	card.add_child(inner)
	inner.add_child(_label(info["copy"], 28, Palette.TEXT, 800))
	inner.add_child(_label("COMING IN THE NEXT BUILD", 24, Palette.ACCENT, 900))
	inner.add_child(_label("The creation flow will be added in a later version.", 22, Palette.TEXT_SOFT, 700))
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


## Big white card (the whole card is the touch target).
func _track_card(p: int) -> PillButton:
	var info: Dictionary = TRACKS[p]
	var card := PillButton.new("", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 30)
	card.custom_minimum_size = Vector2(CARD_WIDTH, 200)
	card.name = "Card_%s" % ("Photo" if p == Page.PHOTO_REVEAL else "Friend")
	card.pressed.connect(func():
		AudioManager.play_ui_tap()
		show_page(p))
	var block := TitleScreen.LogoBlock.new()
	block.color_name = info["block"]
	block.position = Vector2(76, 100)
	card.add_child(block)
	var text := VBoxContainer.new()
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 140.0
	text.offset_right = -32.0
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 8)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(text)
	var title := _label(info["title"], 30, Palette.TEXT, 900)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(title)
	var copy := _label(info["copy"], 22, Palette.TEXT_SOFT, 700)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(copy)
	return card


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


func _label(t: String, fs: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


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
