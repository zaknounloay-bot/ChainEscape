class_name RevealCreator
extends Control
## Social MVP 0.2A/0.2B: creator side of PHOTO / MESSAGE REVEAL.
##
##   CHOOSE PHOTO -> PREVIEW -> MESSAGE -> DIFFICULTY -> REVIEW -> GENERATING
##
## Collects a CreatorSession (photo and/or message, difficulty) in memory.
## CREATE CHALLENGE (0.2B) generates and verifies the exact puzzle
## (SocialGenerator), wraps it in a SharedChallenge and asks SocialScreen to
## play it (play_requested). Nothing is saved, uploaded or shared. Hosted
## by SocialScreen (its backdrop and drifting blocks stay behind it).
##
## Photo: on the Web build the page script (web/social_creator.js) opens
## the native picker from the tap itself (needed on iPhone Safari) and
## hands back a downscaled JPEG; on desktop a native file dialog is used.
## Message: the Web build uses a native text field (iPhone keyboard), the
## desktop build a TextEdit on the screen.

signal exit_requested  # leave the flow, back to the Social choice screen
signal play_requested(challenge: SharedChallenge)  # a verified challenge is ready

enum Step { CHOOSE, PREVIEW, MESSAGE, DIFFICULTY, REVIEW, GENERATING, SHARE }

const ACCENT := Color("#C645E6")  # Photo / Message Reveal identity (0.1)
const TINT := Color("#EBCBF7")
const SOFT_BG := Color("#F8EEFC")
const ERROR := Color("#D0344F")
const WIDTH := 580.0
const MAX_EDGE := 1080  # longest edge of the local working copy (desktop)
const POLL := 0.2
const DIFFICULTY_TEXT := {
	"easy": ["EASY", "A quick challenge."],
	"medium": ["MEDIUM", "A little more thinking."],
	"hard": ["HARD", "Make them earn the reveal."],
}

var session := CreatorSession.new()
var step: int = Step.CHOOSE
## Editing one field from REVIEW: finishing that step returns to REVIEW.
var editing := false
## Photo shown on PREVIEW, not yet accepted (USE THIS PHOTO commits it).
var _pending: CreatorSession
var _draft := ""  # message being written, committed on CONTINUE / BACK
var _steps: Dictionary = {}  # Step -> VBoxContainer
var _headings: Array[Label] = []
var _soft_labels: Array[Label] = []
var _fade: Tween
var _poll := 0.0
var _file_dialog: FileDialog
var _web := false

# Nodes the flow updates.
var _choose_status: Label
var _preview_frame: PanelContainer
var _preview_image: TextureRect
var _preview_status: Label
var _message_card: Control
var _message_text: Label
var _message_edit: TextEdit
var _message_count: Label
var _message_note: Label
var _message_continue: PillButton
var _message_skip: PillButton
var _difficulty_buttons: Dictionary = {}  # id -> PillButton
var _difficulty_continue: PillButton
var _review_photo: TextureRect
var _review_no_photo: Label
var _review_message: Label
var _review_difficulty: Label
var _review_status: Label
var _review_create: PillButton
var _gen_blocks: Array[Node2D] = []
var _gen_title: Label
var _gen_status: Label
var _gen_retry: PillButton
var _gen_back: PillButton
## Generation in progress (one candidate per frame; null when idle).
var generator: SocialGenerator
## Tests: fixed generator seed (0 = random).
var debug_seed := 0
var _gen_frames := 0
var _gen_anim: Tween
var _gen_preview: PillButton

# 0.2C: the generated challenge is kept until the creator leaves, so a
# failed upload is retried with the SAME puzzle; it is only rebuilt when
# the creator changes the photo, message or difficulty.
var prepared: SharedChallenge
var _prepared_sig := ""
var api: SocialApi
var uploading := false
var _upload_token := 0
var last_error := ""
## The created challenge's share link ("" until the API returned an id).
var share_url := ""
var _share_status: Label
var _share_link: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_web = OS.has_feature("web") and SocialWeb.available()
	_steps[Step.CHOOSE] = _build_choose()
	_steps[Step.PREVIEW] = _build_preview()
	_steps[Step.MESSAGE] = _build_message()
	_steps[Step.DIFFICULTY] = _build_difficulty()
	_steps[Step.REVIEW] = _build_review()
	_steps[Step.GENERATING] = _build_generating()
	_steps[Step.SHARE] = _build_share()
	api = SocialApi.new()
	add_child(api)
	get_viewport().size_changed.connect(_on_resized)


## Enter the flow with a fresh session.
func begin(theme: Dictionary) -> void:
	reset()
	for l in _headings:
		l.add_theme_color_override("font_color", theme["text"])
	for l in _soft_labels:
		l.add_theme_color_override("font_color", theme["text_soft"])
	visible = true
	set_process(true)
	show_step(Step.CHOOSE)


## Back from a challenge left before it was solved: the creator's choices
## are all still here.
func resume_review() -> void:
	generator = null
	editing = false
	show_step(Step.REVIEW)


## Back from playing / previewing: the share screen if the challenge was
## created on the server, else the review.
func resume_after_play() -> void:
	if is_created():
		show_step(Step.SHARE)
	else:
		resume_review()


## Leave the flow: the session (photo, message, difficulty) is discarded.
func reset() -> void:
	session = CreatorSession.new()
	_pending = null
	_draft = ""
	editing = false
	step = Step.CHOOSE
	generator = null
	prepared = null
	_prepared_sig = ""
	share_url = ""
	uploading = false
	_upload_token += 1  # a reply still on its way is ignored
	last_error = ""
	if _gen_anim:
		_gen_anim.kill()
	if _fade:
		_fade.kill()
	visible = false
	set_process(false)
	if _web:
		SocialWeb.reset()
		_publish()
	for s in _steps:
		_steps[s].visible = false


func show_step(s: int) -> void:
	step = s
	match s:
		Step.CHOOSE:
			_show_status(_choose_status, "")
		Step.PREVIEW:
			_refresh_preview()
		Step.MESSAGE:
			_refresh_message()
		Step.DIFFICULTY:
			_refresh_difficulty()
		Step.REVIEW:
			_refresh_review()
		Step.GENERATING:
			_start_generating()
		Step.SHARE:
			_refresh_share()
	for k in _steps:
		_steps[k].visible = k == s
	var col: Control = _steps[s]
	if _fade:
		_fade.kill()
	if SocialScreen.reduced_motion():
		col.modulate.a = 1.0
	else:
		col.modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(col, "modulate:a", 1.0, 0.22)
	_update_zones.call_deferred(2)


# --- Navigation -----------------------------------------------------------------

func _back() -> void:
	AudioManager.play_ui_tap()
	match step:
		Step.CHOOSE:
			if editing:
				_finish_edit()
			else:
				exit_requested.emit()
		Step.PREVIEW:
			_pending = null
			show_step(Step.CHOOSE)
		Step.MESSAGE:
			session.set_message(_draft)
			if editing:
				_finish_edit()
			elif session.has_photo():
				_pending = _copy_photo(session)
				show_step(Step.PREVIEW)
			else:
				show_step(Step.CHOOSE)
		Step.DIFFICULTY:
			if editing:
				_finish_edit()
			else:
				_draft = session.message
				show_step(Step.MESSAGE)
		Step.REVIEW:
			show_step(Step.DIFFICULTY)
		Step.GENERATING:
			if uploading:
				return  # wait for the reply (no double submission)
			generator = null
			show_step(Step.REVIEW)
		Step.SHARE:
			exit_requested.emit()


## After a photo decision: the next step, or back to REVIEW when editing
## (via MESSAGE if there is now nothing to reveal).
func _after_photo() -> void:
	if editing and (session.has_photo() or session.has_message()):
		_finish_edit()
	else:
		_draft = session.message
		show_step(Step.MESSAGE)


func _finish_edit() -> void:
	editing = false
	show_step(Step.REVIEW)


func _edit(s: int) -> void:
	AudioManager.play_ui_tap()
	editing = true
	match s:
		Step.CHOOSE:
			if session.has_photo():
				_pending = _copy_photo(session)
				show_step(Step.PREVIEW)
			else:
				show_step(Step.CHOOSE)
		Step.MESSAGE:
			_draft = session.message
			show_step(Step.MESSAGE)
		Step.DIFFICULTY:
			show_step(Step.DIFFICULTY)


# --- Step 1: choose photo ----------------------------------------------------------

func _build_choose() -> VBoxContainer:
	var box := _column()
	box.add_child(_step_label("STEP 1 OF 4  ·  PHOTO"))
	box.add_child(_heading("PHOTO / MESSAGE\nREVEAL"))
	box.add_child(_soft("Hide something special behind a\nChain Escape challenge.", 26))
	var glyph := PhotoGlyph.new()
	glyph.custom_minimum_size = Vector2(220, 160)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(glyph)
	var choose := _primary("CHOOSE PHOTO", "ChoosePhoto")
	choose.pressed.connect(_choose_photo)
	box.add_child(choose)
	var skip := _secondary("SKIP PHOTO", "SkipPhoto")
	skip.pressed.connect(func():
		AudioManager.play_ui_tap()
		_pending = null
		session.clear_photo()
		_after_photo())
	box.add_child(skip)
	box.add_child(_soft("No photo? Send just a message.", 22))
	_choose_status = _status_label()
	box.add_child(_choose_status)
	box.add_child(_back_button())
	return box


## Desktop: native file dialog. Web: the page script already opened the
## picker from this same tap (see web/social_creator.js), nothing to do.
func _choose_photo() -> void:
	AudioManager.play_ui_tap()
	if _web:
		return
	if OS.has_feature("web"):
		_set_status("Photo selection isn't available in this browser. You can skip the photo.")
		return
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.use_native_dialog = true
		_file_dialog.title = "Choose a photo"
		_file_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
		_file_dialog.file_selected.connect(_load_desktop_photo)
		add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.8)


func _load_desktop_photo(path: String) -> void:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		_set_status("That file couldn't be opened as a photo. Try another one.")
		return
	var source := img.get_size()
	var longest := maxi(source.x, source.y)
	if longest > MAX_EDGE:
		var s := float(MAX_EDGE) / longest
		img.resize(maxi(1, roundi(source.x * s)), maxi(1, roundi(source.y * s)), Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	receive_photo(img.save_jpg_to_buffer(0.85), source)


## A photo arrived (Web picker, desktop dialog or a test): show it on
## PREVIEW without touching the session until USE THIS PHOTO.
func receive_photo(jpeg: PackedByteArray, source: Vector2i = Vector2i.ZERO) -> bool:
	var p := CreatorSession.new()
	if not p.set_photo_jpeg(jpeg, source):
		_set_status("That photo couldn't be opened. Try another one.")
		return false
	_pending = p
	_show_status(_choose_status, "")
	_show_status(_preview_status, "")
	if step == Step.PREVIEW:
		_refresh_preview()
		_update_zones.call_deferred(2)
	else:
		show_step(Step.PREVIEW)
	return true


func _set_status(text: String) -> void:
	if step == Step.PREVIEW:
		_show_status(_preview_status, text)
	else:
		_show_status(_choose_status, text)


# --- Step 1b: preview --------------------------------------------------------------

func _build_preview() -> VBoxContainer:
	var box := _column()
	box.add_child(_step_label("STEP 1 OF 4  ·  PHOTO"))
	box.add_child(_heading("YOUR PHOTO"))
	box.add_child(_soft("They'll see it when they escape.", 26))
	_preview_frame = PanelContainer.new()
	var st := _card_style(Palette.WHITE, TINT, 14)
	_preview_frame.add_theme_stylebox_override("panel", st)
	_preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_preview_frame)
	_preview_image = TextureRect.new()
	_preview_image.name = "PreviewImage"
	_preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_frame.add_child(_preview_image)
	var use := _primary("USE THIS PHOTO", "UsePhoto")
	use.pressed.connect(func():
		AudioManager.play_ui_tap()
		if _pending and _pending.has_photo():
			_take_photo_from(_pending)
			_pending = null
			_after_photo())
	box.add_child(use)
	var another := _secondary("CHOOSE ANOTHER", "ChooseAnother")
	another.pressed.connect(_choose_photo)
	box.add_child(another)
	_preview_status = _status_label()
	box.add_child(_preview_status)
	box.add_child(_back_button())
	return box


func _refresh_preview() -> void:
	_show_status(_preview_status, "")
	var tex: Texture2D = _pending.texture if _pending else null
	_preview_image.texture = tex
	_fit_preview()


## The frame hugs the photo: aspect ratio kept, never stretched or cropped,
## as large as the screen allows under the heading and buttons.
func _fit_preview() -> void:
	var tex := _preview_image.texture
	var vh := get_viewport().get_visible_rect().size.y
	var box_size := Vector2(WIDTH - 28.0, clampf(vh - 700.0, 380.0, 760.0))
	var img := Vector2(tex.get_size()) if tex else box_size
	var s := minf(box_size.x / img.x, box_size.y / img.y)
	_preview_image.custom_minimum_size = (img * s).floor()


func _take_photo_from(p: CreatorSession) -> void:
	session.image_jpeg = p.image_jpeg
	session.image_size = p.image_size
	session.source_size = p.source_size
	session.texture = p.texture


func _copy_photo(from: CreatorSession) -> CreatorSession:
	var p := CreatorSession.new()
	p.image_jpeg = from.image_jpeg
	p.image_size = from.image_size
	p.source_size = from.source_size
	p.texture = from.texture
	return p


# --- Step 2: message ---------------------------------------------------------------

func _build_message() -> VBoxContainer:
	var box := _column()
	box.add_child(_step_label("STEP 2 OF 4  ·  MESSAGE"))
	box.add_child(_heading("ADD A MESSAGE"))
	box.add_child(_soft("Add something they'll see when they escape.", 24))
	if _web:
		# Tap the card: the page opens a native text field (keyboard).
		var card := PillButton.new("", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 26)
		card.name = "MessageCard"
		for state in ["normal", "hover"]:
			card.add_theme_stylebox_override(state, _card_style(Palette.WHITE, TINT, 26))
		for state in ["pressed", "hover_pressed"]:
			card.add_theme_stylebox_override(state, _card_style(SOFT_BG, TINT, 26))
		card.custom_minimum_size = Vector2(WIDTH, 260)
		card.pressed.connect(func(): AudioManager.play_ui_tap())
		_message_text = _label("", 28, Palette.TEXT, 800)
		MessageText.apply(_message_text)  # any language, RTL / LTR
		_message_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_message_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_message_text.max_lines_visible = CreatorSession.MESSAGE_MAX_LINES
		_message_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_message_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_message_text.offset_left = 28.0
		_message_text.offset_right = -28.0
		_message_text.offset_top = 18.0
		_message_text.offset_bottom = -18.0
		card.add_child(_message_text)
		_message_card = card
	else:
		var panel := PanelContainer.new()
		panel.name = "MessageCard"
		panel.add_theme_stylebox_override("panel", _card_style(Palette.WHITE, TINT, 18))
		panel.custom_minimum_size = Vector2(WIDTH, 260)
		_message_edit = TextEdit.new()
		_message_edit.name = "MessageEdit"
		_message_edit.placeholder_text = "Write your message"
		_message_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		MessageText.apply_edit(_message_edit)  # any language, RTL / LTR
		_message_edit.add_theme_font_size_override("font_size", 28)
		_message_edit.add_theme_color_override("font_color", Palette.TEXT)
		_message_edit.add_theme_color_override("font_placeholder_color", Palette.TEXT_SOFT)
		_message_edit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		_message_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_message_edit.text_changed.connect(_on_edit_changed)
		_message_edit.text_set.connect(_on_edit_changed)  # text assigned by code
		panel.add_child(_message_edit)
		_message_card = panel
	box.add_child(_message_card)
	_message_count = _label("0 / %d" % CreatorSession.MESSAGE_MAX, 22, Palette.TEXT_SOFT, 800)
	_message_count.name = "MessageCount"
	box.add_child(_message_count)
	_message_continue = _primary("CONTINUE", "Continue")
	_message_continue.pressed.connect(func():
		AudioManager.play_ui_tap()
		session.set_message(_draft)
		if not session.has_photo() and not session.has_message():
			return
		if editing:
			_finish_edit()
		else:
			show_step(Step.DIFFICULTY))
	box.add_child(_message_continue)
	_message_skip = _secondary("SKIP", "SkipMessage")
	_message_skip.pressed.connect(func():
		AudioManager.play_ui_tap()
		_draft = ""
		session.set_message("")
		if editing:
			_finish_edit()
		else:
			show_step(Step.DIFFICULTY))
	box.add_child(_message_skip)
	_message_note = _status_label()
	_message_note.add_theme_color_override("font_color", Palette.TEXT_SOFT)
	box.add_child(_message_note)
	box.add_child(_back_button())
	return box


func _on_edit_changed() -> void:
	var t := _message_edit.text
	if t.length() > CreatorSession.MESSAGE_MAX:
		t = t.left(CreatorSession.MESSAGE_MAX)
		_message_edit.text = t
		_message_edit.set_caret_line(_message_edit.get_line_count() - 1)
		_message_edit.set_caret_column(_message_edit.get_line(_message_edit.get_line_count() - 1).length())
	_draft = t
	_update_message_state()


## Text from the page's native field (Web) or a test.
func set_draft(text: String) -> void:
	_draft = text.left(CreatorSession.MESSAGE_MAX)
	if _message_edit:
		_message_edit.text = _draft
	_refresh_message_text()
	_update_message_state()


func _refresh_message() -> void:
	if _message_edit:
		_message_edit.text = _draft
	_refresh_message_text()
	_update_message_state()


func _refresh_message_text() -> void:
	if _message_text == null:
		return
	var clean := CreatorSession.clean_message(_draft)
	_message_text.text = clean if clean != "" else "Tap to write your message"
	_message_text.add_theme_color_override("font_color", Palette.TEXT if clean != "" else Palette.TEXT_SOFT)
	if _web:
		SocialWeb.set_draft(_draft)


func _update_message_state() -> void:
	var clean := CreatorSession.clean_message(_draft)
	_message_count.text = "%d / %d" % [_draft.length(), CreatorSession.MESSAGE_MAX]
	var photo := session.has_photo()
	# Message only (no photo): the message is what gets revealed.
	_message_skip.visible = photo
	_message_continue.disabled = not photo and clean == ""
	_show_status(_message_note, "" if photo else "No photo, so write the message they'll reveal.")


# --- Step 3: difficulty ------------------------------------------------------------

func _build_difficulty() -> VBoxContainer:
	var box := _column()
	box.add_child(_step_label("STEP 3 OF 4  ·  DIFFICULTY"))
	box.add_child(_heading("CHOOSE DIFFICULTY"))
	box.add_child(_soft("How hard should the escape be?", 26))
	for i in CreatorSession.DIFFICULTIES.size():
		var id: String = CreatorSession.DIFFICULTIES[i]
		var b := PillButton.new("", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 30)
		b.name = "Difficulty_%s" % id
		b.custom_minimum_size = Vector2(WIDTH, 132)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			session.set_difficulty(id)
			_refresh_difficulty())
		var content := VBoxContainer.new()
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		content.add_theme_constant_override("separation", 6)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(content)
		var pips := HBoxContainer.new()
		pips.alignment = BoxContainer.ALIGNMENT_CENTER
		pips.add_theme_constant_override("separation", 8)
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in 3:
			var slot := Control.new()
			slot.custom_minimum_size = Vector2(20, 20)
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pip := SocialScreen.EscapeBlock.new()
			pip.face = ACCENT if k <= i else TINT
			pip.half = 10.0
			pip.dir = Vector2.UP
			pip.position = Vector2(10, 10)
			slot.add_child(pip)
			pips.add_child(slot)
		content.add_child(pips)
		content.add_child(_label(DIFFICULTY_TEXT[id][0], 30, Palette.TEXT, 900))
		content.add_child(_label(DIFFICULTY_TEXT[id][1], 22, Palette.TEXT_SOFT, 700))
		box.add_child(b)
		_difficulty_buttons[id] = b
	_difficulty_continue = _primary("CONTINUE", "Continue")
	_difficulty_continue.pressed.connect(func():
		AudioManager.play_ui_tap()
		if session.difficulty == "":
			return
		if editing:
			_finish_edit()
		else:
			show_step(Step.REVIEW))
	box.add_child(_difficulty_continue)
	box.add_child(_back_button())
	return box


func _refresh_difficulty() -> void:
	_update_zones.call_deferred(1)
	for id in _difficulty_buttons:
		var b: PillButton = _difficulty_buttons[id]
		var on: bool = session.difficulty == id
		var bg := SOFT_BG if on else Palette.WHITE
		var border := ACCENT if on else TINT
		var w := 5 if on else 3
		for state in ["normal", "hover"]:
			b.add_theme_stylebox_override(state, _card_style(bg, border, 0, w))
		for state in ["pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(state, _card_style(bg.darkened(0.03), border, 0, w))
	_difficulty_continue.disabled = session.difficulty == ""


# --- Step 4: review ----------------------------------------------------------------

func _build_review() -> VBoxContainer:
	var box := _column()
	box.add_theme_constant_override("separation", 20)
	box.add_child(_step_label("STEP 4 OF 4  ·  REVIEW"))
	box.add_child(_heading("READY TO CREATE?"))
	box.add_child(_soft("When they escape, they'll see:", 26))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_style(Palette.WHITE, TINT, 24))
	card.custom_minimum_size = Vector2(WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(card)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	card.add_child(inner)
	_review_photo = TextureRect.new()
	_review_photo.name = "ReviewPhoto"
	_review_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_review_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_review_photo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_review_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_review_photo)
	_review_no_photo = _label("No photo", 24, Palette.TEXT_SOFT, 800)
	_review_no_photo.name = "ReviewNoPhoto"
	inner.add_child(_review_no_photo)
	# The whole message fits: 200 characters wrap to at most 8 lines here.
	_review_message = _label("", 24, Palette.TEXT, 800)
	MessageText.apply(_review_message)  # any language, RTL / LTR
	_review_message.name = "ReviewMessage"
	_review_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_review_message.custom_minimum_size = Vector2(WIDTH - 60.0, 0)
	_review_message.max_lines_visible = 8
	inner.add_child(_review_message)
	var line := ColorRect.new()
	line.color = TINT
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(line)
	_review_difficulty = _label("", 24, Palette.TEXT, 900)
	_review_difficulty.name = "ReviewDifficulty"
	inner.add_child(_review_difficulty)
	var edits := HBoxContainer.new()
	edits.add_theme_constant_override("separation", 10)
	edits.custom_minimum_size = Vector2(WIDTH, 0)
	for e in [["PHOTO", "EditPhoto", Step.CHOOSE], ["MESSAGE", "EditMessage", Step.MESSAGE], ["DIFFICULTY", "EditDifficulty", Step.DIFFICULTY]]:
		var b := PillButton.new("EDIT\n" + e[0], PillButton.Icon.NONE, SOFT_BG, Palette.TEXT, 18)
		b.name = e[1]
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var target: int = e[2]
		b.pressed.connect(func(): _edit(target))
		edits.add_child(b)
	box.add_child(edits)
	_review_status = _status_label()
	box.add_child(_review_status)
	_review_create = _primary("CREATE CHALLENGE", "Create")
	_review_create.pressed.connect(_create)
	box.add_child(_review_create)
	box.add_child(_back_button())
	return box


func _refresh_review() -> void:
	var photo := session.has_photo()
	_review_photo.visible = photo
	_review_no_photo.visible = not photo
	if photo:
		_review_photo.texture = session.texture
		# The thumbnail gives way to a long message, so the card always fits.
		var lines := session.message.count("\n") + ceili(session.message.length() / 30.0) if session.has_message() else 0
		var max_h := clampf(300.0 - maxi(0, lines - 3) * 30.0, 150.0, 300.0)
		var img := Vector2(session.image_size)
		var s := minf(WIDTH * 0.8 / img.x, max_h / img.y)
		_review_photo.custom_minimum_size = (img * s).floor()
	_review_message.text = MessageText.quoted(session.message) if session.has_message() else "No message"
	_review_message.add_theme_color_override("font_color", Palette.TEXT if session.has_message() else Palette.TEXT_SOFT)
	_review_difficulty.text = "DIFFICULTY  ·  %s" % DIFFICULTY_TEXT.get(session.difficulty, ["NOT CHOSEN"])[0]
	var errors := session.validate()
	_review_create.disabled = not errors.is_empty()
	_show_status(_review_status, "" if errors.is_empty() else _error_text(errors))


func _error_text(errors: Array[String]) -> String:
	if "nothing_to_reveal" in errors:
		return "Add a photo or a message to reveal."
	if "difficulty" in errors:
		return "Choose a difficulty."
	return "Something is missing. Check your choices."


## 0.2B/0.2C: validate, then generate the exact puzzle (GENERATING step);
## with a backend configured it is then uploaded and a share link made.
func _create() -> void:
	AudioManager.play_ui_tap()
	var errors := session.validate()
	if not errors.is_empty():
		_show_status(_review_status, _error_text(errors))
		return
	show_step(Step.GENERATING)


# --- Step 5: generating the challenge -----------------------------------------

func _build_generating() -> VBoxContainer:
	var box := _column()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 3:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var b := SocialScreen.EscapeBlock.new()
		b.face = [Palette.face("red"), ACCENT, Palette.face("blue")][i]
		b.dir = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT][i]
		b.half = 26.0
		b.position = Vector2(28, 28)
		slot.add_child(b)
		row.add_child(slot)
		_gen_blocks.append(b)
	box.add_child(row)
	_gen_title = _heading("CREATING YOUR\nCHALLENGE")
	box.add_child(_gen_title)
	_gen_status = _soft("", 26)
	_gen_status.name = "GeneratingStatus"
	box.add_child(_gen_status)
	_gen_retry = _primary("TRY AGAIN", "TryAgain")
	_gen_retry.pressed.connect(func():
		AudioManager.play_ui_tap()
		_start_generating())
	box.add_child(_gen_retry)
	_gen_preview = _secondary("PLAY / PREVIEW", "PreviewChallenge")
	_gen_preview.pressed.connect(_preview)
	box.add_child(_gen_preview)
	_gen_back = _back_button()
	box.add_child(_gen_back)
	return box


func _start_generating() -> void:
	_gen_title.text = "CREATING YOUR\nCHALLENGE"
	_gen_retry.visible = false
	_gen_back.visible = false
	_gen_preview.visible = false
	_start_gen_anim()
	# Same photo, message and difficulty as the prepared challenge: keep
	# its exact puzzle (only the upload is repeated).
	if SocialConfig.sharing_enabled() and prepared != null and _prepared_sig == _session_sig():
		_gen_status.text = "Getting your link ready..."
		_upload.call_deferred()
		return
	prepared = null
	var seed_value := debug_seed if debug_seed != 0 else (randi() | 1)
	generator = SocialGenerator.new(session.difficulty, seed_value)
	_gen_frames = 0
	_gen_status.text = "Building a %s puzzle..." % DIFFICULTY_TEXT[session.difficulty][0]


func _start_gen_anim() -> void:
	if _gen_anim:
		_gen_anim.kill()
	if not SocialScreen.reduced_motion():
		_gen_anim = create_tween().set_loops()
		for b in _gen_blocks:
			_gen_anim.tween_property(b, "scale", Vector2(1.18, 1.18), 0.18)
			_gen_anim.tween_property(b, "scale", Vector2.ONE, 0.18)


## One generator attempt per frame (after the screen has drawn once).
func _generate_step() -> void:
	_gen_frames += 1
	if _gen_frames < 3 or not generator.step():
		return
	var g := generator
	generator = null
	if _gen_anim:
		_gen_anim.kill()
	for b in _gen_blocks:
		b.scale = Vector2.ONE
	if g.puzzle == null:
		# Never play an unverified board: say so and keep every choice.
		push_warning("[Social] no challenge after %d attempts (%s)" % [g.attempts, g.error])
		_gen_title.text = "COULDN'T CREATE\nTHE CHALLENGE"
		_gen_status.text = "Your photo and message are kept.\nPlease try again."
		_gen_retry.visible = true
		_gen_back.visible = true
		return
	print("[Social] challenge ready: %s %s" % [session.difficulty, JSON.stringify(g.metrics)])
	prepared = SharedChallenge.photo_message_reveal(session, g.puzzle)
	_prepared_sig = _session_sig()
	if not SocialConfig.sharing_enabled():
		# No backend in this build: play it here, exactly as in 0.2B.
		play_requested.emit(prepared)
		return
	_start_gen_anim()
	_gen_status.text = "Getting your link ready..."
	_upload()


## Sends the prepared challenge (its exact puzzle) to the server. One
## request at a time; a reply that arrives after the creator left is
## ignored.
func _upload() -> void:
	if uploading or prepared == null:
		return
	uploading = true
	_upload_token += 1
	var token := _upload_token
	var r := await api.create_challenge(prepared)
	if token != _upload_token:
		return
	uploading = false
	if _gen_anim:
		_gen_anim.kill()
	for b in _gen_blocks:
		b.scale = Vector2.ONE
	if not r["ok"]:
		last_error = r["error"]
		push_warning("[Social] create failed: %s" % last_error)
		_gen_title.text = "COULDN'T CREATE\nCHALLENGE"
		_gen_status.text = _upload_error_text(last_error)
		_gen_retry.visible = true
		_gen_preview.visible = true
		_gen_back.visible = true
		_update_zones.call_deferred(1)
		return
	last_error = ""
	prepared.remote_id = r["challenge_id"]
	prepared.expires_at = r["expires_at"]
	share_url = ShareLink.build(ShareLink.default_base(), prepared.remote_id)
	show_step(Step.SHARE)


func _upload_error_text(code: String) -> String:
	match code:
		"network", "timeout":
			return "Check your connection and try again.\nYour photo and message are kept."
		"rate_limited":
			return "Lots of challenges right now.\nPlease wait a minute and try again."
		"too_large":
			return "This photo is too large to send.\nTry another photo."
		"not_configured":
			return "Sharing isn't available in this version.\nYou can still play it here."
	return "Something went wrong on our side.\nPlease try again."


## True once the server accepted the prepared challenge (it has an id).
func is_created() -> bool:
	return prepared != null and prepared.remote_id != ""


## Plays the prepared challenge here (same puzzle as the shared one).
func _preview() -> void:
	AudioManager.play_ui_tap()
	if prepared != null:
		play_requested.emit(prepared)


## Identity of what the creator chose (photo bytes, message, difficulty).
func _session_sig() -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(session.difficulty.to_utf8_buffer())
	h.update(("\n" + session.message + "\n").to_utf8_buffer())
	if session.has_photo():
		h.update(session.image_jpeg)
	return h.finish().hex_encode()


# --- Step 6: share (0.2C) ------------------------------------------------------

func _build_share() -> VBoxContainer:
	var box := _column()
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(slot)
	var icon := SocialScreen.EscapeBlock.new()
	icon.face = ACCENT
	icon.dir = Vector2.UP
	icon.half = 36.0
	icon.position = Vector2(38, 38)
	slot.add_child(icon)
	box.add_child(holder)
	box.add_child(_heading("CHALLENGE READY!"))
	box.add_child(_soft("Your Chain Escape is ready to send.", 26))
	# SEND ON WHATSAPP opens the main WhatsApp app (wa.me) with the message
	# and link; MORE WAYS TO SHARE is the system share sheet (AirDrop,
	# Messages, Mail...); COPY LINK copies. On the Web all three run inside
	# the tap (page script zones).
	var whatsapp := _primary("SEND ON WHATSAPP", "SendWhatsApp")
	whatsapp.pressed.connect(func(): _share_pressed(false))
	box.add_child(whatsapp)
	var share := _secondary("MORE WAYS TO SHARE", "ShareChallenge")
	share.pressed.connect(func(): _share_pressed(false))
	box.add_child(share)
	var copy := _secondary("COPY LINK", "CopyLink")
	copy.pressed.connect(func(): _share_pressed(true))
	box.add_child(copy)
	_share_status = _label("", 24, ACCENT.darkened(0.15), 900)
	_share_status.name = "ShareStatus"
	_share_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_share_status.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_child(_share_status)
	_share_link = _label("", 18, Palette.TEXT_SOFT, 700)
	_share_link.name = "ShareLink"
	_share_link.custom_minimum_size = Vector2(WIDTH, 0)
	_share_link.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_share_link)
	box.add_child(_soft("Only the link is shared. The link expires in 30 days.", 20))
	var preview := PillButton.new("PLAY / PREVIEW CHALLENGE", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 24)
	preview.name = "PreviewChallenge"
	preview.custom_minimum_size = Vector2(460, 92)
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.pressed.connect(_preview)
	box.add_child(preview)
	var done := PillButton.new("DONE", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 26)
	done.name = "Done"
	done.custom_minimum_size = Vector2(460, 92)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func():
		AudioManager.play_ui_tap()
		exit_requested.emit())
	box.add_child(done)
	return box


func _refresh_share() -> void:
	_share_status.text = ""
	# No page address outside the Web build (and no SHARE_BASE_URL): the
	# challenge exists, but there is no link to hand over here.
	_share_link.text = share_url if share_url != "" else "Links are made by the Web version"
	if _web:
		SocialWeb.set_share(share_url, SocialConfig.SHARE_TEXT, SocialConfig.SHARE_TITLE)


## Web: the page script already shared / copied inside the tap (zones), the
## result arrives through _process. Elsewhere: copy to the clipboard.
func _share_pressed(_copy_only: bool) -> void:
	AudioManager.play_ui_tap()
	if _web or share_url == "":
		return
	DisplayServer.clipboard_set(share_url)
	_show_share_result("copied")


## Neutral wording: the browser only hands the link to another app; it can
## never know whether a message was actually sent.
func _show_share_result(r: String) -> void:
	match r:
		"whatsapp":
			_share_status.text = "OPENED WHATSAPP"
		"shared":
			_share_status.text = "HANDED TO THE APP YOU CHOSE"
		"copied":
			_share_status.text = "LINK COPIED"
		"failed":
			_share_status.text = "COULDN'T SHARE - TRY COPY LINK"
		_:
			_share_status.text = ""


# --- Web polling and tap zones -------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	if step == Step.GENERATING:
		if generator:
			_generate_step()
		return
	if not _web:
		return
	_poll += delta
	if _poll < POLL:
		return
	_poll = 0.0
	if step == Step.SHARE:
		var sr := SocialWeb.take_share_result()
		if sr != "":
			_show_share_result(sr)
			_publish()
		return
	if step == Step.CHOOSE or step == Step.PREVIEW:
		var r := SocialWeb.take_photo()
		if not r.is_empty():
			_on_web_photo(r)
			_update_zones.call_deferred(2)
		elif SocialWeb.photo_busy():
			_set_status("Opening your photo...")
	elif step == Step.MESSAGE:
		var m := SocialWeb.take_message()
		if bool(m.get("done", false)):
			set_draft(str(m.get("text", "")))
			_update_zones.call_deferred(2)


func _on_web_photo(r: Dictionary) -> void:
	if not bool(r.get("ok", false)):
		var why := str(r.get("error", ""))
		_set_status("That photo is too large. Try another one." if why == "too_large"
			else "That photo couldn't be opened. Try another one.")
		return
	var bytes := Marshalls.base64_to_raw(str(r.get("b64", "")))
	receive_photo(bytes, Vector2i(int(r.get("source_w", 0)), int(r.get("source_h", 0))))


## Tells the page where the tap-to-pick / tap-to-write controls are (after
## the column has its final layout).
func _update_zones(defers_left: int = 0) -> void:
	if defers_left > 0:
		_update_zones.call_deferred(defers_left - 1)
		return
	if not _web:
		return
	var zones := []
	if visible:
		match step:
			Step.CHOOSE:
				zones.append(_zone("photo", _steps[Step.CHOOSE].find_child("ChoosePhoto", true, false)))
			Step.PREVIEW:
				zones.append(_zone("photo", _steps[Step.PREVIEW].find_child("ChooseAnother", true, false)))
			Step.MESSAGE:
				zones.append(_zone("message", _message_card))
			Step.SHARE:
				zones.append(_zone("whatsapp", _steps[Step.SHARE].find_child("SendWhatsApp", true, false)))
				zones.append(_zone("share", _steps[Step.SHARE].find_child("ShareChallenge", true, false)))
				zones.append(_zone("copy", _steps[Step.SHARE].find_child("CopyLink", true, false)))
	SocialWeb.set_zones(zones)
	_publish()


## Web: read-only snapshot for automated browser tests
## (window.chainEscapeSocial), like the game's window.chainEscapeState.
## Button centers are normalized (0..1) screen positions.
func _publish() -> void:
	var vis := get_viewport().get_visible_rect().size
	var buttons := {}
	if visible:
		for b in _steps[step].find_children("*", "BaseButton", true, false):
			if b.is_visible_in_tree():
				var c: Vector2 = b.get_global_rect().get_center()
				buttons[String(b.name)] = [snappedf(c.x / vis.x, 0.0001), snappedf(c.y / vis.y, 0.0001), b.disabled]
	WebBridge.publish("chainEscapeSocial", {"open": visible, "step": Step.keys()[step], "editing": editing,
		"has_photo": session.has_photo(), "image": [session.image_size.x, session.image_size.y],
		"pending_image": [_pending.image_size.x, _pending.image_size.y] if _pending else [],
		"message": session.message, "draft": _draft, "difficulty": session.difficulty, "buttons": buttons,
		"status": _visible_status(), "share_url": share_url, "uploading": uploading, "error": last_error,
		"share_status": _share_status.text if _share_status else ""})


func _visible_status() -> String:
	for l: Label in [_choose_status, _preview_status, _review_status]:
		if l.is_visible_in_tree():
			return l.text
	return ""


func _zone(id: String, c: Control) -> Dictionary:
	var vis := get_viewport().get_visible_rect().size
	var r := c.get_global_rect()
	return {"id": id, "x": r.position.x / vis.x, "y": r.position.y / vis.y, "w": r.size.x / vis.x, "h": r.size.y / vis.y}


func _on_resized() -> void:
	if not visible:
		return
	if step == Step.PREVIEW:
		_fit_preview()
	_update_zones.call_deferred(2)


# --- Building blocks ---------------------------------------------------------------

func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.visible = false
	add_child(box)
	return box


func _primary(text: String, node_name: String) -> PillButton:
	var b := PillButton.new(text, PillButton.Icon.NONE, ACCENT, Palette.WHITE, 30)
	b.name = node_name
	b.custom_minimum_size = Vector2(460, 104)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _secondary(text: String, node_name: String) -> PillButton:
	var b := PillButton.new(text, PillButton.Icon.NONE, SOFT_BG, Palette.TEXT, 28)
	b.name = node_name
	b.custom_minimum_size = Vector2(460, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _back_button() -> PillButton:
	var b := PillButton.new("BACK", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 30)
	b.name = "Back"
	b.custom_minimum_size = Vector2(460, 100)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_back)
	return b


func _card_style(bg: Color, border: Color, margin: int, width: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(40)
	s.anti_aliasing = true
	s.set_border_width_all(width)
	s.border_color = border
	s.set_content_margin_all(margin)
	s.shadow_color = Palette.SHADOW
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s


func _step_label(t: String) -> Label:
	var l := _label(t, 20, ACCENT.darkened(0.1), 900)
	return l


func _heading(t: String) -> Label:
	var l := _label(t, 46, Palette.TEXT, 900)
	_headings.append(l)
	return l


func _soft(t: String, fs: int) -> Label:
	var l := _label(t, fs, Palette.TEXT_SOFT, 800)
	_soft_labels.append(l)
	return l


## Status lines take no space while empty.
func _show_status(l: Label, text: String) -> void:
	l.text = text
	l.visible = text != ""


func _status_label() -> Label:
	var l := _label("", 22, ERROR, 800)
	l.visible = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH, 0)
	return l


func _label(t: String, fs: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


## A small "photo" picture (frame, hills, sun) drawn once, no image asset.
class PhotoGlyph extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#F8EEFC")
		st.border_color = Color("#EBCBF7")
		st.set_border_width_all(4)
		st.set_corner_radius_all(28)
		st.anti_aliasing = true
		st.draw(get_canvas_item(), r)
		var w := size.x
		var h := size.y
		draw_circle(Vector2(w * 0.7, h * 0.32), h * 0.11, Color("#FFC21A"))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.14, h * 0.8), Vector2(w * 0.4, h * 0.38),
				Vector2(w * 0.62, h * 0.8)]), Color("#C645E6"))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.44, h * 0.8), Vector2(w * 0.66, h * 0.52),
				Vector2(w * 0.86, h * 0.8)]), Color("#E58BF5"))
