class_name SocialReveal
extends Control
## Social: the moment a challenge is solved - a chain of blocks breaks open
## and the hidden photo and/or message appears. Reusable for the creator's
## preview (0.2B) and the recipient (later): only the end buttons differ.
##
## Layouts (never an empty frame, never "No photo" / "No message"):
##   photo + message  photo on top, the message in a card under it
##   photo only       the photo, as large as the screen allows
##   message only     the message alone, large, in the card
## Messages render with MessageText (any language, RTL / LTR, Arabic
## shaping). Lightweight: a few Tweens on nodes drawn once.

signal play_again
signal done

const ACCENT := Color("#C645E6")
const TINT := Color("#EBCBF7")
const WIDTH := 600.0
const CHAIN := 7

var _backdrop: SocialPlay.Backdrop
var _chain_root: Control
var _chain: Array[Node2D] = []
var _column: VBoxContainer
var _emblem: Control
var _emblem_block: Node2D
var _heading: Label
var _photo_frame: PanelContainer
var _photo: TextureRect
var _message_card: PanelContainer
var _message: Label
var _again: PillButton
var _back: PillButton
var _tween: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_backdrop = SocialPlay.Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_column = VBoxContainer.new()
	_column.name = "RevealColumn"
	_column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_column.grow_vertical = Control.GROW_DIRECTION_BOTH
	_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_column.add_theme_constant_override("separation", 24)
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	# Message only: an emblem above the heading, so the reveal has a focal
	# point of its own (the purple "escape" block of this track).
	_emblem = CenterContainer.new()
	_emblem.name = "RevealEmblem"
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(96, 96)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_emblem.add_child(slot)
	var eb := SocialScreen.EscapeBlock.new()
	eb.face = ACCENT
	eb.dir = Vector2.UP
	eb.half = 44.0
	eb.position = Vector2(48, 48)
	slot.add_child(eb)
	_emblem_block = eb
	_column.add_child(_emblem)
	_heading = _label("YOU ESCAPED!", 40, ACCENT, 900)
	_heading.name = "RevealHeading"
	_column.add_child(_heading)
	_photo_frame = PanelContainer.new()
	_photo_frame.name = "RevealPhotoFrame"
	_photo_frame.add_theme_stylebox_override("panel", _card(12))
	_photo_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_photo_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_photo_frame)
	_photo = TextureRect.new()
	_photo.name = "RevealPhoto"
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_frame.add_child(_photo)
	_message_card = PanelContainer.new()
	_message_card.name = "RevealMessageCard"
	_message_card.add_theme_stylebox_override("panel", _card(30))
	_message_card.custom_minimum_size = Vector2(WIDTH, 0)
	_message_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_message_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_message_card)
	_message = _label("", 30, Palette.TEXT, 800)
	_message.name = "RevealMessage"
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.custom_minimum_size = Vector2(WIDTH - 60.0, 0)
	MessageText.apply(_message)  # any language, RTL / LTR
	_message_card.add_child(_message)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(gap)
	_again = PillButton.new("PLAY AGAIN", PillButton.Icon.NONE, Color("#F8EEFC"), Palette.TEXT, 28)
	_again.name = "PlayAgain"
	_again.custom_minimum_size = Vector2(460, 96)
	_again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_again.pressed.connect(func(): play_again.emit())
	_column.add_child(_again)
	_back = PillButton.new("BACK TO CREATE CHALLENGE", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 26)
	_back.name = "BackToCreate"
	_back.custom_minimum_size = Vector2(500, 96)
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func():
		AudioManager.play_ui_tap()
		done.emit())
	_column.add_child(_back)
	# The chain that breaks open (drawn once, only moved / faded).
	_chain_root = Control.new()
	_chain_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chain_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chain_root)
	var colors := ["red", "blue", "yellow", "purple", "green", "blue", "red"]
	for i in CHAIN:
		var b := SocialScreen.EscapeBlock.new()
		b.face = ACCENT if i == CHAIN / 2 else Palette.face(colors[i])
		b.dir = Vector2.UP if i == CHAIN / 2 else (Vector2.LEFT if i < CHAIN / 2 else Vector2.RIGHT)
		b.half = 34.0
		_chain_root.add_child(b)
		_chain.append(b)


## Shows the reveal for `c`. Buttons depend on who is playing.
func show_reveal(c: SharedChallenge, theme: Dictionary, mode: int) -> void:
	_backdrop.set_colors(theme["bg_top"], theme["bg_bottom"])
	var has_photo := c.has_photo()
	var text := c.message()
	var has_message := text != ""
	_photo_frame.visible = has_photo
	_message_card.visible = has_message
	_emblem.visible = not has_photo
	# Message only: a roomier card, the message centered in it.
	_message_card.custom_minimum_size = Vector2(WIDTH, 0 if has_photo else 280)
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.text = text
	# Message only: the message is the whole reveal - larger type.
	_message.add_theme_font_size_override("font_size", 30 if has_photo else 40)
	if has_photo:
		_photo.texture = c.local_photo
		_fit_photo(c, text)
	_back.text = "BACK TO CREATE CHALLENGE" if mode == SocialPlay.Mode.CREATOR_PREVIEW else "DONE"
	visible = true
	_animate()
	if has_photo:
		_shrink_to_fit.call_deferred(2)


func hide_now() -> void:
	if _tween:
		_tween.kill()
	visible = false
	_photo.texture = null


## Photo as large as the screen allows, aspect kept (never stretched or
## cropped); it gives way to a long message so the buttons stay on screen.
func _fit_photo(c: SharedChallenge, text: String) -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var msg_h := 0.0
	if text != "":
		var lines := text.count("\n") + ceili(text.length() / 30.0)
		msg_h = 60.0 + mini(lines, 9) * 42.0
	var max_h := clampf(vh - 470.0 - msg_h, 220.0, 820.0)
	var img := Vector2(c.local_photo.get_size())
	var s := minf((WIDTH - 24.0) / img.x, max_h / img.y)
	_photo.custom_minimum_size = (img * s).floor()


## After layout: if the real message height (fonts differ per device)
## still pushes the column past the screen, the photo gives up the rest.
func _shrink_to_fit(defers_left: int) -> void:
	if defers_left > 0:
		_shrink_to_fit.call_deferred(defers_left - 1)
		return
	if not visible or not _photo_frame.visible:
		return
	var room := get_viewport().get_visible_rect().size.y - 48.0
	var over := _column.get_combined_minimum_size().y - room
	if over <= 0.0:
		return
	var sz := _photo.custom_minimum_size
	var h := maxf(160.0, sz.y - over)
	_photo.custom_minimum_size = (sz * (h / sz.y)).floor()


func _animate() -> void:
	if _tween:
		_tween.kill()
	var vis := get_viewport().get_visible_rect().size
	var center := vis * 0.5
	var gap := 76.0
	for i in CHAIN:
		var b: Node2D = _chain[i]
		b.position = center + Vector2((i - CHAIN / 2) * gap, 0)
		b.modulate.a = 1.0
		b.scale = Vector2.ONE
		b.visible = true
	_column.modulate.a = 0.0
	_emblem_block.scale = Vector2.ONE
	if SocialScreen.reduced_motion():
		for b in _chain:
			b.visible = false
		_column.modulate.a = 1.0
		return
	_tween = create_tween()
	# 1. The chain holds for a beat...
	_tween.tween_interval(0.35)
	# 2. ...then breaks open: every block escapes outward (the middle one
	#    upward), and the hidden content fades in behind it.
	_tween.tween_callback(func(): AudioManager.play_perfect())
	for i in CHAIN:
		var b: Node2D = _chain[i]
		var off := i - CHAIN / 2
		var target := b.position + (Vector2(signf(off) * (vis.x * 0.7 + absf(off) * 40.0), -80.0 * absf(off)) if off != 0 else Vector2(0, -vis.y * 0.6))
		_tween.parallel().tween_property(b, "position", target, 0.55).set_delay(0.04 * absf(off)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(b, "modulate:a", 0.0, 0.5).set_delay(0.1 + 0.04 * absf(off))
	_tween.parallel().tween_property(_column, "modulate:a", 1.0, 0.5).set_delay(0.25)
	if _emblem.visible:
		_emblem_block.scale = Vector2(0.4, 0.4)
		_tween.parallel().tween_property(_emblem_block, "scale", Vector2.ONE, 0.6).set_delay(0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		for b in _chain:
			b.visible = false)


func _card(margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.WHITE
	s.set_corner_radius_all(40)
	s.anti_aliasing = true
	s.set_border_width_all(3)
	s.border_color = TINT
	s.set_content_margin_all(margin)
	s.shadow_color = Palette.SHADOW
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 4)
	return s


func _label(t: String, fs: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l
