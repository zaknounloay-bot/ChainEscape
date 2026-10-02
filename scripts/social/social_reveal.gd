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
##
## Recipient (0.2C phase 2): the photo arrives from the network, so its
## frame can show "loading" / "couldn't load + TRY AGAIN" until it does;
## and CREATE YOUR OWN invites them to make one (one gentle pulse, once).

signal play_again
signal done
signal create_own
signal photo_retry

const ACCENT := Color("#C645E6")
const TINT := Color("#EBCBF7")
const WIDTH := 600.0
const CHAIN := 7
const CTA_TEXT := "CREATE YOUR OWN"
## Challenge a Friend (phase 3): the recipient's invitation.
const FRIEND_CTA_TEXT := "CHALLENGE A FRIEND"

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
## Recipient only: CREATE YOUR OWN, its line, and PLAY AGAIN + MAIN MENU
## side by side (so everything fits above the fold).
var _cta: PillButton
var _cta_line: Label
var _row: HBoxContainer
var _cta_tween: Tween
## Photo still on its way / failed (recipient): shown in place of the photo.
var _photo_status: PanelContainer
var _photo_status_label: Label
var _photo_retry: PillButton
## "none" | "ready" | "loading" | "failed"
var photo_state := "none"
## Times CREATE YOUR OWN has pulsed in this reveal (tests: exactly once).
var cta_pulses := 0
var _shown := 0  # reveal counter: stale timers do nothing
var _text := ""
var _mode := 0


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
	_photo_status = PanelContainer.new()
	_photo_status.name = "RevealPhotoStatus"
	_photo_status.add_theme_stylebox_override("panel", _card(24))
	_photo_status.custom_minimum_size = Vector2(WIDTH - 40.0, 200)
	_photo_status.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_photo_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_photo_status)
	_column.move_child(_photo_status, _photo_frame.get_index() + 1)
	var status_box := VBoxContainer.new()
	status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	status_box.add_theme_constant_override("separation", 16)
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo_status.add_child(status_box)
	_photo_status_label = _label("", 26, Palette.TEXT_SOFT, 800)
	_photo_status_label.name = "PhotoStatusText"
	_photo_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_box.add_child(_photo_status_label)
	_photo_retry = PillButton.new("TRY AGAIN", PillButton.Icon.NONE, Color("#F8EEFC"), Palette.TEXT, 24)
	_photo_retry.name = "PhotoRetry"
	_photo_retry.custom_minimum_size = Vector2(260, 76)
	_photo_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_photo_retry.pressed.connect(func():
		AudioManager.play_ui_tap()
		photo_retry.emit())
	status_box.add_child(_photo_retry)
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
	# The arrow is drawn (CtaArrow): the Web build's fallback font has no
	# "→" glyph. The trailing spaces leave room for it.
	_cta = PillButton.new(CTA_TEXT + "    ", PillButton.Icon.NONE, ACCENT, Palette.WHITE, 30)
	_cta.name = "CreateYourOwn"
	_cta.custom_minimum_size = Vector2(500, 100)
	_cta.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cta.pressed.connect(func():
		AudioManager.play_ui_tap()
		create_own.emit())
	_column.add_child(_cta)
	_cta.add_child(CtaArrow.new())
	_cta_line = _label("Surprise someone with a challenge.", 24, Palette.TEXT_SOFT, 800)
	_cta_line.name = "CtaLine"
	_column.add_child(_cta_line)
	_row = HBoxContainer.new()
	_row.name = "RecipientActions"
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_row)
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
## `photo` (recipient): "loading" / "failed" while the challenge's photo is
## not here yet; "" = use c.local_photo as is.
func show_reveal(c: SharedChallenge, theme: Dictionary, mode: int, photo: String = "") -> void:
	_shown += 1
	_mode = mode
	_backdrop.set_colors(theme["bg_top"], theme["bg_bottom"])
	var has_photo := c.has_photo()
	var expects_photo := has_photo or (photo != "" and c.payload.get("photo") != null)
	var text := c.message()
	_text = text
	var has_message := text != ""
	photo_state = "ready" if has_photo else (photo if expects_photo else "none")
	_photo_frame.visible = has_photo
	_photo_status.visible = expects_photo and not has_photo
	_set_photo_status_text()
	_message_card.visible = has_message
	_emblem.visible = not expects_photo
	# Message only: a roomier card, the message centered in it.
	_message_card.custom_minimum_size = Vector2(WIDTH, 0 if expects_photo else 280)
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.text = text
	# Message only: the message is the whole reveal - larger type.
	_message.add_theme_font_size_override("font_size", 30 if expects_photo else 40)
	var recipient := mode == SocialPlay.Mode.RECIPIENT
	_place_buttons(recipient)
	# A friend challenge has nothing to reveal: its invitation is to make
	# one in return (no supporting line).
	var friend := c.type == SharedChallenge.TYPE_FRIEND_CHALLENGE
	_cta.text = (FRIEND_CTA_TEXT if friend else CTA_TEXT) + "    "
	_cta.name = "ChallengeAFriend" if friend else "CreateYourOwn"
	_cta_line.visible = recipient and not friend
	for ch in _cta.get_children():
		if ch is CtaArrow:
			ch.queue_redraw()
	if has_photo:
		_photo.texture = c.local_photo
		_fit_photo(c.local_photo.get_size(), text)
	_back.text = "MAIN MENU" if recipient else "BACK TO CREATE CHALLENGE"
	visible = true
	_animate()
	if recipient:
		_start_cta()
	if has_photo:
		_shrink_to_fit.call_deferred(2)


## Recipient: the photo arrived (or failed again) while the reveal shows.
func set_photo(tex: Texture2D) -> void:
	if not visible or photo_state == "none" or tex == null:
		return
	photo_state = "ready"
	_photo.texture = tex
	_fit_photo(tex.get_size(), _text)
	_photo_status.visible = false
	_photo_frame.visible = true
	_shrink_to_fit.call_deferred(2)


func set_photo_state(state: String) -> void:
	if not visible or photo_state == "none" or photo_state == "ready":
		return
	photo_state = state
	_set_photo_status_text()


func _set_photo_status_text() -> void:
	_photo_status_label.text = "Loading the photo…" if photo_state == "loading" else "The photo couldn't be loaded."
	_photo_retry.visible = photo_state == "failed"


func hide_now() -> void:
	_shown += 1
	if _tween:
		_tween.kill()
	if _cta_tween:
		_cta_tween.kill()
	visible = false
	_photo.texture = null
	photo_state = "none"


## Creator: PLAY AGAIN and BACK stacked, no invitation. Recipient: CREATE
## YOUR OWN first, then PLAY AGAIN and MAIN MENU side by side, smaller.
func _place_buttons(recipient: bool) -> void:
	_cta.visible = recipient
	_cta_line.visible = recipient
	_row.visible = recipient
	var holder: Control = _row if recipient else _column
	for b in [_again, _back]:
		if b.get_parent() != holder:
			b.get_parent().remove_child(b)
			holder.add_child(b)
	if not recipient:
		_column.move_child(_again, _row.get_index() + 1)
		_column.move_child(_back, _again.get_index() + 1)
	_again.custom_minimum_size = Vector2(260, 84) if recipient else Vector2(460, 96)
	_back.custom_minimum_size = Vector2(260, 84) if recipient else Vector2(500, 96)
	_again.add_theme_font_size_override("font_size", 24 if recipient else 28)
	_back.add_theme_font_size_override("font_size", 24 if recipient else 26)


## CREATE YOUR OWN is there from the start but quieter while the reveal
## plays; ~1.2 s in it comes up to full strength with ONE gentle pulse.
## Never repeated, no flashing, no timer shown.
func _start_cta() -> void:
	if _cta_tween:
		_cta_tween.kill()
	_cta.scale = Vector2.ONE
	_cta.modulate = Color(1, 1, 1, 0.72)
	cta_pulses = 0
	var shown := _shown
	get_tree().create_timer(1.2).timeout.connect(func():
		if shown != _shown or not visible:
			return
		cta_pulses += 1
		_cta.pivot_offset = _cta.size * 0.5
		_cta_tween = create_tween()
		_cta_tween.tween_property(_cta, "modulate:a", 1.0, 0.3)
		if not SocialScreen.reduced_motion():
			_cta_tween.parallel().tween_property(_cta, "scale", Vector2(1.06, 1.06), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			_cta_tween.tween_property(_cta, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))


## Photo as large as the screen allows, aspect kept (never stretched or
## cropped); it gives way to a long message so the buttons stay on screen.
func _fit_photo(img_size: Vector2, text: String) -> void:
	var vh := get_viewport().get_visible_rect().size.y
	var msg_h := 0.0
	if text != "":
		var lines := text.count("\n") + ceili(text.length() / 30.0)
		msg_h = 60.0 + mini(lines, 9) * 42.0
	var buttons_h := 560.0 if _mode == SocialPlay.Mode.RECIPIENT else 470.0
	var max_h := clampf(vh - buttons_h - msg_h, 220.0, 820.0)
	var img := Vector2(img_size)
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


## The "->" after CREATE YOUR OWN: covers the button, draws the arrow in
## the room the trailing spaces leave after the text.
class CtaArrow extends Control:
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var b := get_parent() as Button
		var f := b.get_theme_font("font")
		var fs := b.get_theme_font_size("font_size")
		var full := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var word := f.get_string_size(b.text.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((size.x - full) * 0.5 + word + (full - word) * 0.55, size.y * 0.5)
		draw_rect(Rect2(at + Vector2(-13, -3.5), Vector2(16, 7)), Color.WHITE)
		draw_colored_polygon(PackedVector2Array([at + Vector2(13, 0), at + Vector2(1, -11), at + Vector2(1, 11)]), Color.WHITE)
