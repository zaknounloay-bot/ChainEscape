class_name RecipientFlow
extends Control
## Social 0.2C phase 2: someone opened a shared challenge link.
##
##   launch ?challenge=<id>  ->  LOADING "Opening your Chain Escape..."
##     -> API READ -> SharedChallenge.from_api (exact PuzzleDefinition,
##        Solver-verified; never regenerated) -> LANDING "SOMEONE SENT YOU
##        A CHAIN ESCAPE" + difficulty + PLAY        (nothing revealed yet)
##     -> PLAY: SocialPlay (RECIPIENT) -> Reveal -> CREATE YOUR OWN
##   malformed / unknown / expired / invalid -> UNAVAILABLE + MAIN MENU
##   offline / timeout / server trouble      -> ERROR + RETRY + MAIN MENU
##
## The photo is downloaded from the challenge's temporary signed URL while
## the recipient plays, so the reveal is usually instant. If the URL has
## expired (or the download fails), the challenge is read again for a
## fresh URL - the puzzle never changes. Nothing here touches Classic
## state, PlayerProgress or the save; nothing private is logged.

signal play_requested(challenge: SharedChallenge)
signal main_menu_requested
## The photo's state changed: "loading" / "ready" / "failed".
signal photo_changed(state: String)

enum State { CLOSED, LOADING, LANDING, UNAVAILABLE, ERROR }

const ACCENT := Color("#C645E6")
const TINT := Color("#EBCBF7")
const DIFFICULTY_NAMES := {"easy": "EASY", "medium": "MEDIUM", "hard": "HARD"}
## Errors worth a RETRY (the link itself may be fine).
const RETRYABLE := ["network", "timeout", "server", "rate_limited", "invalid_response", "not_configured"]
const MAX_PHOTO_BYTES := 8 * 1024 * 1024
const MAX_PHOTO_EDGE := 2048

var state: int = State.CLOSED
var challenge_id := ""
var challenge: SharedChallenge
## Last error code (tests / diagnostics; never shown raw).
var error_code := ""
## "none" | "loading" | "ready" | "failed"
var photo_state := "none"
## READ requests made for this link (tests: retry, fresh photo URL).
var reads := 0
var api: SocialApi

var _session := 0
var _pages: Dictionary = {}  # State -> Control
var _labels: Array[Label] = []  # recolored per theme
var _soft: Array[Label] = []
var _difficulty: Label
var _err_title: Label
var _err_body: Label
var _retry: PillButton
var _spinner: Node2D
var _spin: Tween


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	api = SocialApi.new()
	add_child(api)
	_pages[State.LOADING] = _build_loading()
	_pages[State.LANDING] = _build_landing()
	_pages[State.UNAVAILABLE] = _build_error()


## Opens the link's challenge: `raw` is the launch parameter as given.
func begin(raw: String, theme: Dictionary) -> void:
	reset(false)
	visible = true
	for l in _labels:
		l.add_theme_color_override("font_color", theme["text"])
	for l in _soft:
		l.add_theme_color_override("font_color", theme["text_soft"])
	challenge_id = raw.strip_edges().to_lower()
	if not ShareLink.is_valid_id(challenge_id):
		challenge_id = ""
		_fail("invalid_id")
		return
	_load()


## Back to the landing (left the puzzle before solving).
func show_landing() -> void:
	if challenge == null:
		return
	visible = true
	_show(State.LANDING)


## Forgets the challenge (and its photo) and cancels anything in flight.
func reset(publish: bool = true) -> void:
	_session += 1
	challenge = null
	challenge_id = ""
	error_code = ""
	photo_state = "none"
	reads = 0
	state = State.CLOSED
	_stop_spinner()
	for k in _pages:
		_pages[k].visible = false
	visible = false
	if publish:
		_publish()


## TRY AGAIN on the reveal's photo: a fresh signed URL, then the download.
func retry_photo() -> void:
	if challenge == null or challenge.payload.get("photo") == null or photo_state == "ready":
		return
	_download_photo(true)


# --- Loading -------------------------------------------------------------------

func _load() -> void:
	_show(State.LOADING)
	var session := _session
	reads += 1
	var r: Dictionary = await api.read_challenge(challenge_id)
	if session != _session:
		return
	if not r.get("ok", false):
		_fail(str(r.get("error", "invalid_response")))
		return
	# Phase 2 backend foundation only: Challenge a Friend has no recipient
	# screens yet, so its links show the friendly "newer version" screen
	# rather than the Photo / Message Reveal landing.
	if r["challenge"].type != SharedChallenge.TYPE_PHOTO_MESSAGE_REVEAL:
		_fail("unsupported")
		return
	challenge = r["challenge"]
	_difficulty.text = "Difficulty: %s" % DIFFICULTY_NAMES.get(challenge.difficulty, "")
	_show(State.LANDING)
	# The photo comes now, while they play (never shown before solving).
	if challenge.payload.get("photo") != null:
		_download_photo(false)


func _fail(code: String) -> void:
	error_code = code
	challenge = null
	var retry := code in RETRYABLE and challenge_id != ""
	if retry:
		_err_title.text = "COULDN'T OPEN\nTHIS CHALLENGE"
		_err_body.text = ("Check your connection and try again." if code in ["network", "timeout"]
			else "Something went wrong on our side.\nPlease try again in a moment.")
	elif code == "unsupported":
		_err_title.text = "THIS CHALLENGE\nISN'T AVAILABLE"
		_err_body.text = "It was made with a newer version of\nChain Escape. Try again later."
	else:
		_err_title.text = "THIS CHALLENGE\nISN'T AVAILABLE"
		_err_body.text = "It may have expired or the link\nmay be invalid."
	_retry.visible = retry
	_show(State.ERROR if retry else State.UNAVAILABLE)


# --- Photo -----------------------------------------------------------------------

## Downloads the photo from the signed URL. A failure (an expired URL
## included) first asks the API for a fresh URL - same challenge, same
## puzzle - and tries once more; still failing = "failed" (TRY AGAIN).
func _download_photo(fresh_first: bool) -> void:
	var session := _session
	_set_photo("loading")
	var tex: Texture2D = null
	if not fresh_first and challenge.media_url != "":
		tex = await _fetch_photo(challenge.media_url)
		if session != _session:
			return
	if tex == null:
		reads += 1
		var r: Dictionary = await api.read_challenge(challenge_id)
		if session != _session:
			return
		# Only the new URL is taken; the board the player has stays as is.
		if r.get("ok", false) and r["challenge"].puzzle.fingerprint() == challenge.puzzle.fingerprint() \
				and r["challenge"].media_url != "":
			challenge.media_url = r["challenge"].media_url
			tex = await _fetch_photo(challenge.media_url)
			if session != _session:
				return
	if tex == null:
		_set_photo("failed")
		return
	challenge.local_photo = tex
	_set_photo("ready")


func _set_photo(s: String) -> void:
	photo_state = s
	photo_changed.emit(s)
	_publish()


## One GET of the image (no extra headers: a plain CORS request). Decoded
## by its content (JPEG / PNG / WebP), size-checked; null on any failure.
## Only the HTTP status is ever logged - never the URL.
func _fetch_photo(url: String) -> Texture2D:
	if not (url.begins_with("https://") or SocialConfig.allow_http_media):
		return null
	var req := HTTPRequest.new()
	req.timeout = SocialConfig.timeout_override if SocialConfig.timeout_override > 0.0 else SocialConfig.TIMEOUT_SEC
	req.body_size_limit = MAX_PHOTO_BYTES
	add_child(req)
	if req.request(url) != OK:
		req.queue_free()
		return null
	var res: Array = await req.request_completed
	req.queue_free()
	print("[Social] photo -> HTTP %d" % res[1])
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		return null
	return decode_photo(res[3])


static func decode_photo(bytes: PackedByteArray) -> Texture2D:
	if bytes.size() < 12 or bytes.size() > MAX_PHOTO_BYTES:
		return null
	var img := Image.new()
	var err := ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		err = img.load_png_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(bytes)
	if err != OK or img.is_empty():
		return null
	var edge := maxi(img.get_width(), img.get_height())
	if edge > MAX_PHOTO_EDGE:
		var s := float(MAX_PHOTO_EDGE) / edge
		img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)


# --- Pages -------------------------------------------------------------------------

func _show(s: int) -> void:
	state = s
	var page_key := State.UNAVAILABLE if s == State.ERROR else s
	for k in _pages:
		_pages[k].visible = k == page_key
	if s == State.LOADING:
		_start_spinner()
	else:
		_stop_spinner()
	_publish()
	# Again once the column is laid out (button positions for tests).
	if is_inside_tree():
		var session := _session
		get_tree().create_timer(0.25).timeout.connect(func():
			if session == _session and state == s:
				_publish())


func _build_loading() -> Control:
	var box := _column()
	var slot := _icon_slot(110)
	_spinner = SocialScreen.EscapeBlock.new()
	_spinner.face = ACCENT
	_spinner.dir = Vector2.UP
	_spinner.half = 40.0
	_spinner.position = Vector2(55, 55)
	slot.get_child(0).add_child(_spinner)
	box.add_child(slot)
	var l := _text("Opening your Chain Escape…", 32, 900, false)
	l.name = "LoadingText"
	box.add_child(l)
	return box


func _build_landing() -> Control:
	var box := _column()
	var slot := _icon_slot(150)
	var gift := Gift.new()
	gift.position = Vector2(75, 80)
	slot.get_child(0).add_child(gift)
	box.add_child(slot)
	var h := _text("SOMEONE SENT YOU\nA CHAIN ESCAPE", 50, 900, false)
	h.name = "LandingTitle"
	box.add_child(h)
	box.add_child(_text("Solve it to unlock your surprise.", 28, 800, true))
	var chip := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.WHITE
	st.set_corner_radius_all(30)
	st.anti_aliasing = true
	st.set_border_width_all(3)
	st.border_color = TINT
	st.content_margin_left = 28
	st.content_margin_right = 28
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	chip.add_theme_stylebox_override("panel", st)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_difficulty = _plain("Difficulty: EASY", 26, ACCENT.darkened(0.2), 900)
	_difficulty.name = "Difficulty"
	chip.add_child(_difficulty)
	box.add_child(chip)
	box.add_child(_gap(10))
	var play := _button("PLAY", ACCENT, Palette.WHITE, 36, Vector2(460, 116))
	play.name = "Play"
	play.pressed.connect(func():
		AudioManager.play_ui_tap()
		if challenge != null:
			play_requested.emit(challenge))
	box.add_child(play)
	box.add_child(_main_menu_button())
	return box


func _build_error() -> Control:
	var box := _column()
	var slot := _icon_slot(110)
	var b := SocialScreen.EscapeBlock.new()
	b.face = Color("#B9B3C9")
	b.dir = Vector2.DOWN
	b.half = 40.0
	b.position = Vector2(55, 55)
	slot.get_child(0).add_child(b)
	box.add_child(slot)
	_err_title = _text("THIS CHALLENGE\nISN'T AVAILABLE", 46, 900, false)
	_err_title.name = "ErrorTitle"
	box.add_child(_err_title)
	_err_body = _text("It may have expired or the link\nmay be invalid.", 28, 800, true)
	_err_body.name = "ErrorBody"
	box.add_child(_err_body)
	box.add_child(_gap(10))
	_retry = _button("RETRY", ACCENT, Palette.WHITE, 32, Vector2(460, 104))
	_retry.name = "Retry"
	_retry.pressed.connect(func():
		AudioManager.play_ui_tap()
		if challenge_id != "":
			_load())
	box.add_child(_retry)
	box.add_child(_main_menu_button())
	return box


func _main_menu_button() -> PillButton:
	var b := _button("MAIN MENU", Palette.WHITE, Palette.TEXT, 30, Vector2(460, 96))
	b.name = "MainMenu"
	b.pressed.connect(func():
		AudioManager.play_ui_tap()
		main_menu_requested.emit())
	return b


func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	box.visible = false
	add_child(box)
	return box


func _icon_slot(side: float) -> CenterContainer:
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(side, side)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(slot)
	return holder


func _button(t: String, bg: Color, fg: Color, fs: int, sz: Vector2) -> PillButton:
	var b := PillButton.new(t, PillButton.Icon.NONE, bg, fg, fs)
	b.custom_minimum_size = sz
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _gap(h: float) -> Control:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _text(t: String, fs: int, weight: int, soft: bool) -> Label:
	var l := _plain(t, fs, Palette.TEXT_SOFT if soft else Palette.TEXT, weight)
	(_soft if soft else _labels).append(l)
	return l


func _plain(t: String, fs: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


## The loading block bobs gently (no spinner wheel; nothing with reduced motion).
func _start_spinner() -> void:
	_stop_spinner()
	_spinner.position = Vector2(55, 55)
	if SocialScreen.reduced_motion():
		return
	_spin = create_tween().set_loops()
	_spin.tween_property(_spinner, "position:y", 41.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_spin.tween_property(_spinner, "position:y", 55.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_spinner() -> void:
	if _spin:
		_spin.kill()
		_spin = null


# --- Test snapshot ------------------------------------------------------------------

## Read-only state for automated browser tests (window.chainEscapeRecipient):
## screen, error code, difficulty and button positions - never the message,
## photo or URLs.
func _publish() -> void:
	if not OS.has_feature("web") or not is_inside_tree():
		return
	var vis := get_viewport().get_visible_rect().size
	var buttons := {}
	for k in _pages:
		for b in _pages[k].find_children("*", "PillButton", true, false):
			if b.is_visible_in_tree():
				var c: Vector2 = b.get_global_rect().get_center()
				buttons[String(b.name)] = [snappedf(c.x / vis.x, 0.0001), snappedf(c.y / vis.y, 0.0001)]
	var names := {State.CLOSED: "closed", State.LOADING: "loading", State.LANDING: "landing",
		State.UNAVAILABLE: "unavailable", State.ERROR: "error"}
	WebBridge.publish("chainEscapeRecipient", {"state": names[state], "error": error_code,
		"difficulty": challenge.difficulty if challenge else "", "photo": photo_state, "reads": reads,
		"buttons": buttons})


## A small gift box (drawn once): the landing's "you received something".
class Gift extends Node2D:
	func _draw() -> void:
		var box := StyleBoxFlat.new()
		box.bg_color = ACCENT
		box.set_corner_radius_all(14)
		box.anti_aliasing = true
		box.draw(get_canvas_item(), Rect2(-56, -22, 112, 74))
		var lid := StyleBoxFlat.new()
		lid.bg_color = ACCENT.lightened(0.12)
		lid.set_corner_radius_all(12)
		lid.anti_aliasing = true
		lid.draw(get_canvas_item(), Rect2(-64, -44, 128, 30))
		var ribbon := Color("#FFD23F")
		draw_rect(Rect2(-9, -44, 18, 96), ribbon)
		# The bow: two loops and a knot.
		for side in [-1.0, 1.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -46), Vector2(30 * side, -72),
				Vector2(38 * side, -56), Vector2(10 * side, -44)]), ribbon)
		draw_circle(Vector2(0, -46), 10.0, ribbon.darkened(0.12))
