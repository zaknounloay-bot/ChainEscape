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
signal moment_done  # the Photo / Message reveal moment ended (or was skipped)

const ACCENT := Color("#C645E6")
const TINT := Color("#EBCBF7")
const WIDTH := 600.0
const CHAIN := 7
const CTA_TEXT := "CREATE YOUR OWN SURPRISE"
## Photo / Message Reveal (phase 4): the gift -> envelope -> card moment,
## seconds from the reveal's start. A soft gift box settles near the lower
## centre and rests there a moment (anticipation, to BEAT_LID), then opens
## gently; an envelope rises out of it and settles where the card will be,
## the box fading only once the envelope is clear of it; its top flap opens;
## the photo (or, message only, the message card) rises out of the
## envelope's pocket and grows into its place; the envelope fades away; the
## message and the buttons settle. About 2.45 s, automatic; a tap skips to
## the end; reduced motion shows the end at once.
## Nothing waits for the photo: loading / failed takes its place in the same
## beat, and the message comes on time.
const BEAT_LID := 0.9
const BEAT_RISE := 1.08
const BEAT_BOX_OUT := 1.4
const BEAT_FLAP := 1.54
const BEAT_CARD := 1.72
const BEAT_ENVELOPE_OUT := 1.8
const BEAT_HEADING := 1.82
const BEAT_MESSAGE := 1.96
const BEAT_BUTTONS := 2.1
const BEAT_END := 2.45
## The solved-screen heading: a reveal's, and a friend challenge's.
const HEADING := "SURPRISE UNLOCKED!"
const FRIEND_HEADING := "YOU ESCAPED!"
## The reveal's warm, gentle colours.
const GIFT_LAVENDER := Color("#CDB9F2")
const GIFT_LAVENDER_LIGHT := Color("#E4D7F8")
const GIFT_LAVENDER_DEEP := Color("#B39ADF")
const GIFT_BLUSH := Color("#F3AFC6")
const GIFT_BLUSH_SOFT := Color("#F8D3DF")
const GIFT_IVORY := Color("#FFF8EC")
const GIFT_CREAM := Color("#FBEEDF")
const GIFT_FOLD := Color("#E9D6C2")
const GIFT_GOLD := Color("#E3BC63")
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
## "playing" while the Photo / Message reveal moment runs, "done" after it
## (or after a skip). Friend Challenge keeps its own short reveal.
var phase := "done"
var skipped := false
## How long the last reveal moment took (ms; tests).
var moment_ms := 0
var _moment_t0 := 0
var _veil: ColorRect
## The envelope moment, in two layers: the box, the envelope's back, its
## inside and its opened flap behind the column; its front pocket and closed
## flap in front of it - so the card rises out from inside the envelope.
var _env_back: RevealEnvelope
var _env_front: RevealEnvelope
var _buttons_tween: Tween
## Challenge a Friend only (phase 4): the completion time under the
## heading. Never shown for a Photo / Message Reveal.
var _time_box: VBoxContainer
var _time_value: Label


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
	_heading = _label(FRIEND_HEADING, 40, ACCENT, 900)
	_heading.name = "RevealHeading"
	_column.add_child(_heading)
	_time_box = VBoxContainer.new()
	_time_box.name = "RevealTime"
	_time_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_time_box.add_theme_constant_override("separation", -8)
	_time_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_box.visible = false
	_column.add_child(_time_box)
	var caption := _label("YOUR TIME", 24, Palette.TEXT_SOFT, 900)
	caption.name = "RevealTimeCaption"
	_time_box.add_child(caption)
	_time_value = _label("", 76, Palette.TEXT, 900)
	_time_value.name = "RevealTimeValue"
	var digits := FontVariation.new()
	digits.base_font = Palette.font(900)
	digits.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	_time_value.add_theme_font_override("font", digits)
	_time_box.add_child(_time_value)
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
	# The soft veil the photo develops from (lifted by the reveal moment).
	_veil = ColorRect.new()
	_veil.name = "RevealVeil"
	_veil.color = Color("#F8EEFC")
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.modulate.a = 0.0
	_photo_frame.add_child(_veil)
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
	MessageText.apply(_message, 800, true)  # any language, RTL / LTR, emoji
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
	# The envelope moment (Photo / Message Reveal): behind and in front of the column.
	_env_back = RevealEnvelope.new()
	_env_back.name = "RevealEnvelopeBack"
	_env_back.visible = false
	add_child(_env_back)
	move_child(_env_back, _column.get_index())
	_env_front = RevealEnvelope.new()
	_env_front.name = "RevealEnvelopeFront"
	_env_front.front = true
	_env_front.visible = false
	add_child(_env_front)
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
## `time_ms` (Challenge a Friend only): the completion time, -1 = none.
func show_reveal(c: SharedChallenge, theme: Dictionary, mode: int, photo: String = "", time_ms: int = -1) -> void:
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
	_heading.text = FRIEND_HEADING if friend else HEADING
	# A reveal's focal point is the envelope (and then the photo / message).
	_emblem.visible = friend and not expects_photo
	_time_box.visible = friend and time_ms >= 0
	_time_value.text = UIManager.fmt_time(time_ms) if _time_box.visible else ""
	_time_value.add_theme_color_override("font_color", theme.get("text", Palette.TEXT))
	_time_box.get_child(0).add_theme_color_override("font_color", theme.get("text_soft", Palette.TEXT_SOFT))
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
	if friend:
		# Challenge a Friend: its own short reveal, exactly as before.
		phase = "done"
		_set_parts_alpha(1.0)
		_set_buttons_active(true)
		for part in [_photo_frame, _photo_status, _message_card]:
			part.scale = Vector2.ONE
		_animate()
		if recipient:
			_start_cta()
	else:
		_animate_reveal(recipient)
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
	phase = "done"
	_hide_envelope()
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
func _start_cta(delay: float = 1.2) -> void:
	if _cta_tween:
		_cta_tween.kill()
	_cta.scale = Vector2.ONE
	_cta.modulate = Color(1, 1, 1, 0.72)
	cta_pulses = 0
	var shown := _shown
	get_tree().create_timer(delay).timeout.connect(func():
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


## A tap during the reveal moment shows everything at once.
func _gui_input(event: InputEvent) -> void:
	if phase != "playing":
		return
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		accept_event()
		skip()


## Photo / Message Reveal: the gift -> envelope -> card moment (see BEAT_*).
func _animate_reveal(recipient: bool) -> void:
	if _tween:
		_tween.kill()
	skipped = false
	_moment_t0 = Time.get_ticks_msec()
	for b in _chain:
		b.visible = false
	_veil.modulate.a = 0.0
	_cta.modulate = Color(1, 1, 1, 1)
	_cta.scale = Vector2.ONE
	_hide_envelope()
	if SocialScreen.reduced_motion():
		_column.modulate.a = 1.0
		_set_parts_alpha(1.0)
		_finish_reveal(recipient)
		return
	phase = "playing"
	_set_buttons_active(false)
	_column.modulate.a = 1.0
	_set_parts_alpha(0.0)
	var photo_part: Control = _photo_frame if _photo_frame.visible else (_photo_status if _photo_status.visible else null)
	# What comes out of the envelope: the photo (or its loading card), else the message.
	var card: Control = photo_part if photo_part != null else (_message_card if _message_card.visible else null)
	var shown := _shown
	for env in [_env_back, _env_front]:
		env.reset()
		env.visible = true
	_tween = create_tween()
	# 1. The gift box settles in (once placed: _place_envelope), then opens gently.
	_tween.tween_interval(0.0)
	_env_tween("box", 1.0, 0.3, 0.06, Tween.TRANS_SINE)
	_env_tween("lid", 1.0, 0.42, BEAT_LID, Tween.TRANS_SINE)
	_tween.parallel().tween_callback(func(): AudioManager.play_perfect()).set_delay(BEAT_LID)
	# 2. The envelope rises out of the box and settles where the card will be.
	_env_tween("rise", 1.0, 0.5, BEAT_RISE, Tween.TRANS_CUBIC)
	_env_tween("box", 0.0, 0.36, BEAT_BOX_OUT, Tween.TRANS_SINE)
	# 3. Its top flap opens, with a soft glow.
	_env_tween("flap", 1.0, 0.26, BEAT_FLAP, Tween.TRANS_SINE)
	_env_tween("glow", 1.0, 0.4, BEAT_FLAP, Tween.TRANS_SINE)
	# 4. The card rises out of the pocket and grows into its place.
	if card != null:
		_tween.parallel().tween_property(card, "modulate:a", 1.0, 0.16).set_delay(BEAT_CARD)
		_tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.5).set_delay(BEAT_CARD).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if card == _photo_frame:
			_veil.modulate.a = 0.55
			_tween.parallel().tween_property(_veil, "modulate:a", 0.0, 0.4).set_delay(BEAT_CARD + 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 5. The envelope fades away behind the card.
	_env_tween("fade", 1.0, 0.22, BEAT_ENVELOPE_OUT, Tween.TRANS_SINE)
	# 6. The heading, the message (after a photo) and the buttons settle.
	_tween.parallel().tween_property(_heading, "modulate:a", 1.0, 0.3).set_delay(BEAT_HEADING)
	if _message_card.visible and card != _message_card:
		_tween.parallel().tween_property(_message_card, "modulate:a", 1.0, 0.3).set_delay(BEAT_MESSAGE)
		_tween.parallel().tween_property(_message_card, "scale", Vector2.ONE, 0.35).set_delay(BEAT_MESSAGE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for part in _button_parts():
		_tween.parallel().tween_property(part, "modulate:a", 1.0, 0.3).set_delay(BEAT_BUTTONS)
	_tween.tween_interval(maxf(0.0, BEAT_END - BEAT_BUTTONS - 0.3))
	_tween.tween_callback(func():
		if shown == _shown:
			_finish_reveal(recipient))
	# Pivots and the envelope's place once the column is laid out.
	_set_pivots_later.call_deferred(card, 2)


## One envelope property, tweened on both layers in the current beat.
func _env_tween(prop: String, value: float, seconds: float, delay: float, trans: int) -> void:
	for env in [_env_back, _env_front]:
		_tween.parallel().tween_property(env, prop, value, seconds).set_delay(delay).set_trans(trans).set_ease(Tween.EASE_IN_OUT)


func _hide_envelope() -> void:
	for env in [_env_back, _env_front]:
		if env:
			env.visible = false


func _set_pivots_later(card: Control, defers_left: int) -> void:
	if defers_left > 0:
		_set_pivots_later.call_deferred(card, defers_left - 1)
		return
	_set_pivots(card)


## The card that rises from the gift grows from its bottom edge; the
## message card (after a photo) from its centre.
func _set_pivots(card: Control) -> void:
	# The envelope settles over the card's lower middle (its pocket there),
	# the gift box below it; the card grows out of the pocket, from that point.
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var env_w := 0.0
	if card != null and phase == "playing":
		var r := card.get_global_rect()
		env_w = clampf(r.size.x * 0.74, 300.0, 430.0)
		var pocket := Vector2(r.get_center().x, r.position.y + r.size.y * 0.62)
		var vis := get_viewport().get_visible_rect().size
		var box := Vector2(pocket.x, minf(r.end.y + 70.0, vis.y - 120.0))
		for env in [_env_back, _env_front]:
			env.place(to_local * box, to_local * pocket, env_w)
	for part in [_photo_frame, _photo_status, _message_card]:
		var rising: bool = part == card
		# The rising card grows from the pocket point (62% down), so it reads as
		# coming up out of the envelope; others from their centre.
		part.pivot_offset = Vector2(part.size.x * 0.5, part.size.y * (0.62 if rising else 0.5))
		if phase == "playing" and part.visible and part.modulate.a < 0.01:
			var start := clampf(env_w * 0.8 / maxf(part.size.x, 1.0), 0.3, 0.9) if rising else 0.94
			part.scale = Vector2(start, start)


## Ends the reveal moment now: everything shown, buttons active.
func skip() -> void:
	if phase != "playing":
		return
	skipped = true
	if _tween:
		_tween.kill()
	for b in _chain:
		b.visible = false
	_hide_envelope()
	_emblem_block.scale = Vector2.ONE
	_veil.modulate.a = 0.0
	_set_parts_alpha(1.0)
	for part in [_photo_frame, _photo_status, _message_card]:
		part.scale = Vector2.ONE
	_finish_reveal(_mode == SocialPlay.Mode.RECIPIENT)


func _finish_reveal(recipient: bool) -> void:
	phase = "done"
	moment_ms = Time.get_ticks_msec() - _moment_t0
	moment_done.emit()
	_hide_envelope()
	for part in [_photo_frame, _photo_status, _message_card]:
		part.scale = Vector2.ONE  # (a photo that arrives later shows at full size)
	for b in _chain:
		b.visible = false
	_set_buttons_active(true)
	if recipient:
		_start_cta(0.25)


## The reveal's parts that fade in (the column itself stays opaque).
func _set_parts_alpha(a: float) -> void:
	for part in [_emblem, _heading, _photo_frame, _photo_status, _message_card, _time_box] + _button_parts():
		part.modulate.a = a


func _button_parts() -> Array:
	return [_cta, _cta_line, _row, _again, _back]


## Buttons only take taps once they are shown (a tap before that skips).
func _set_buttons_active(on: bool) -> void:
	for b in [_cta, _again, _back, _photo_retry]:
		b.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


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


## The Photo / Message Reveal envelope moment, drawn with a few shapes (no
## assets). Two instances share the same state: `front = false` draws the
## gift box, the glow, the envelope's back, its inside and its OPENED flap
## (behind the card); `front = true` draws the pocket and the CLOSED flap with
## its gold seal (in front of the card). Redrawn only while a value changes.
class RevealEnvelope extends Node2D:
	var front := false
	var box_at := Vector2.ZERO  # where the gift box sits
	var pocket_at := Vector2.ZERO  # where the envelope settles (its pocket centre)
	var width := 380.0
	## 0..1 each (tweened): the box shown, its lid lifted, the envelope risen,
	## the flap opened, the glow, the envelope faded away.
	var box := 0.0:
		set(v):
			box = v
			queue_redraw()
	var lid := 0.0:
		set(v):
			lid = v
			queue_redraw()
	var rise := 0.0:
		set(v):
			rise = v
			queue_redraw()
	var flap := 0.0:
		set(v):
			flap = v
			queue_redraw()
	var glow := 0.0:
		set(v):
			glow = v
			queue_redraw()
	var fade := 0.0:
		set(v):
			fade = v
			queue_redraw()

	func reset() -> void:
		box = 0.0
		lid = 0.0
		rise = 0.0
		flap = 0.0
		glow = 0.0
		fade = 0.0

	func place(p_box: Vector2, p_pocket: Vector2, p_width: float) -> void:
		box_at = p_box
		pocket_at = p_pocket
		width = p_width
		queue_redraw()

	func _draw() -> void:
		if not front:
			_draw_box()
		_draw_envelope()

	## A soft lavender box with a blush ribbon and a gold knot; the lid lifts
	## gently and tips back a little.
	func _draw_box() -> void:
		if box <= 0.0:
			return
		var a := box
		var w := 170.0
		var h := 120.0
		var c := box_at
		_rounded(Rect2(c + Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), Color(SocialReveal.GIFT_LAVENDER, a), 16)
		_rounded(Rect2(c + Vector2(-w * 0.5, h * 0.12), Vector2(w, h * 0.38)), Color(SocialReveal.GIFT_LAVENDER_DEEP, 0.3 * a), 16)
		draw_rect(Rect2(c + Vector2(-13, -h * 0.5), Vector2(26, h)), Color(SocialReveal.GIFT_BLUSH, a))
		var lift := Vector2(16.0, -54.0) * lid
		draw_set_transform(c + Vector2(-w * 0.5 - 9, -h * 0.5) + lift, -0.22 * lid, Vector2.ONE)
		_rounded(Rect2(Vector2(0, -30), Vector2(w + 18, 32)), Color(SocialReveal.GIFT_LAVENDER_LIGHT, a), 13)
		draw_rect(Rect2(Vector2((w + 18) * 0.5 - 14, -30), Vector2(28, 32)), Color(SocialReveal.GIFT_BLUSH, a))
		var knot := Vector2((w + 18) * 0.5, -30)
		for s in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([knot, knot + Vector2(38 * s, -24), knot + Vector2(42 * s, -4), knot + Vector2(10 * s, 2)]), Color(SocialReveal.GIFT_BLUSH, a))
		draw_circle(knot, 9.0, Color(SocialReveal.GIFT_GOLD, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## The envelope: it rises from inside the box (small) to the pocket point
	## (full size); then the top flap turns up, and at the end it fades.
	func _draw_envelope() -> void:
		if rise <= 0.0:
			return
		var e := 1.0 - pow(1.0 - rise, 3.0)
		var center := (box_at + Vector2(0, -20)).lerp(pocket_at, e)
		var s := lerpf(0.45, 1.0, e)
		var a := clampf(rise / 0.22, 0.0, 1.0) * (1.0 - fade)
		if a <= 0.0:
			return
		var w := width * s
		var h := w * 0.64
		var top := center.y - h * 0.5
		var left := center.x - w * 0.5
		var right := center.x + w * 0.5
		var bottom := center.y + h * 0.5
		var flap_h := h * 0.56
		var open := clampf(flap, 0.0, 1.0)
		if not front:
			# A gentle glow behind it as it opens.
			if glow > 0.0:
				for i in 4:
					draw_circle(center + Vector2(0, -h * 0.25), w * (0.42 + i * 0.13), Color(SocialReveal.GIFT_IVORY.lerp(SocialReveal.GIFT_GOLD, i / 5.0), 0.12 * glow * a * (1.0 - i / 4.5)))
			# The back, and its blush lining (seen once the flap opens).
			_rounded(Rect2(Vector2(left, top), Vector2(w, h)), Color(SocialReveal.GIFT_IVORY, a), 10)
			if open > 0.0:
				draw_colored_polygon(PackedVector2Array([Vector2(left + 8, top + 6), Vector2(right - 8, top + 6), Vector2(center.x, top + flap_h * 0.92)]), Color(SocialReveal.GIFT_BLUSH_SOFT, a * open))
			# The flap, once more than half open, stands up behind the card.
			if open >= 0.5:
				_flap(left, right, top, flap_h * (2.0 * open - 1.0), -1.0, a)
			return
		# Front: the pocket (side folds meeting in the middle, the bottom fold).
		var meet := Vector2(center.x, top + h * 0.58)
		draw_colored_polygon(PackedVector2Array([Vector2(left, top + h * 0.2), meet, Vector2(right, top + h * 0.2), Vector2(right, bottom), Vector2(left, bottom)]), Color(SocialReveal.GIFT_CREAM, a))
		for side in [left, right]:
			draw_line(Vector2(side, bottom), meet, Color(SocialReveal.GIFT_FOLD, a), 2.0, true)
		draw_line(Vector2(left, top + h * 0.2), meet, Color(SocialReveal.GIFT_FOLD, 0.6 * a), 1.5, true)
		draw_line(Vector2(right, top + h * 0.2), meet, Color(SocialReveal.GIFT_FOLD, 0.6 * a), 1.5, true)
		# The closed flap (folding up through its edge in the first half).
		if open < 0.5:
			_flap(left, right, top, flap_h * (1.0 - 2.0 * open), 1.0, a)

	## The flap: a soft lavender triangle from the top corners to its tip
	## (`length` down for dir 1, up for dir -1), with the gold seal at its tip.
	func _flap(left: float, right: float, top: float, length: float, dir: float, a: float) -> void:
		var tip := Vector2((left + right) * 0.5, top + dir * length)
		draw_colored_polygon(PackedVector2Array([Vector2(left, top), Vector2(right, top), tip]), Color(SocialReveal.GIFT_LAVENDER_LIGHT, a))
		draw_polyline(PackedVector2Array([Vector2(left, top), tip, Vector2(right, top)]), Color(SocialReveal.GIFT_LAVENDER, a), 2.0, true)
		if length > 14.0:
			draw_circle(tip - Vector2(0, dir * 10.0), 15.0, Color(SocialReveal.GIFT_GOLD, a))
			draw_circle(tip - Vector2(0, dir * 10.0), 9.0, Color(SocialReveal.GIFT_IVORY.lerp(SocialReveal.GIFT_GOLD, 0.55), a))

	func _rounded(r: Rect2, col: Color, radius: int) -> void:
		var st := StyleBoxFlat.new()
		st.bg_color = col
		st.set_corner_radius_all(radius)
		st.anti_aliasing = true
		st.draw(get_canvas_item(), r)
