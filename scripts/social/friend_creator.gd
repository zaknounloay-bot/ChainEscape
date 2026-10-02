class_name FriendCreator
extends Control
## Social / Challenge a Friend (phase 3): the creator side.
##
##   CHOOSE (EASY / MEDIUM / HARD / VERY HARD / SURPRISE ME)
##     --one tap-->  CREATING ("CREATING YOUR CHALLENGE...": generate, then
##                   create on the server, as one step)
##     -->  READY (SEND ON WHATSAPP / MORE WAYS TO SHARE / COPY LINK,
##                 NEW CHALLENGE, PLAY / PREVIEW, DONE)
##
## The board comes from FriendGenerator (verified, never a campaign board,
## never one already shown in this session) and is stored as its exact
## PuzzleDefinition through the existing API (friend_challenge). The link is
## created BEFORE the share buttons show: on iPhone the share actions must
## run inside the tap, with the link already known.
##
## Low-level sharing is the proven Photo / Message machinery (SocialWeb tap
## zones "whatsapp" / "share" / "copy", ShareLink, SocialApi); only the
## presentation is Friend's own. Nothing here is saved: the challenge lives
## in memory until the creator leaves (its link keeps working).

signal exit_requested  # DONE / BACK from the first screen
signal play_requested(challenge: SharedChallenge)  # PLAY / PREVIEW

enum Step { CHOOSE, CREATING, READY }

const COLOR := Color("#1A9FE6")  # Challenge a Friend identity (0.1)
const TINT := Color("#C3E6F8")
const SOFT_BG := Color("#EAF6FD")
const WIDTH := 580.0
const POLL := 0.2
const NAMES := {"easy": "EASY", "medium": "MEDIUM", "hard": "HARD", "very_hard": "VERY HARD"}
const BLURB := {
	"easy": "A quick warm-up.",
	"medium": "A few tricky moves.",
	"hard": "Real thinking needed.",
	"very_hard": "For puzzle lovers.",
}

var step: int = Step.CHOOSE
## What the creator picked: a difficulty or FriendGenerator.SURPRISE.
var choice := ""
## The challenge on the READY screen (created on the server: has an id).
var current: SharedChallenge
## The challenge being made (generated; created once the API answers). A
## failed create keeps it, so TRY AGAIN resends this exact puzzle.
var pending: SharedChallenge
var share_url := ""
## A generation or create in progress (one at a time).
var busy := false
var last_error := ""
## "generate" | "create" while the error screen shows.
var failed := ""
## Board keys shown in this session: NEW CHALLENGE never repeats one.
var seen_keys: Array = []
var generator: FriendGenerator
var api: SocialApi
## Tests: fixed seeds (0 = random) and a fixed SURPRISE ME roll.
var debug_seed := 0
var rng := RandomNumberGenerator.new()

var _steps: Dictionary = {}
var _headings: Array[Label] = []
var _soft_labels: Array[Label] = []
var _web := false
var _poll := 0.0
var _token := 0
var _gen_frames := 0
var _gen_surprise := false
var _fade: Tween
var _anim: Tween
var _blocks: Array[Node2D] = []
var _c_title: Label
var _c_status: Label
var _c_retry: PillButton
var _c_back: PillButton
var _r_icon_block: Control
var _r_icon_dice: Control
var _r_sub: Label
var _r_status: Label
var _r_link: Label
var _r_new: PillButton


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)
	rng.randomize()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_web = OS.has_feature("web") and SocialWeb.available()
	_steps[Step.CHOOSE] = _build_choose()
	_steps[Step.CREATING] = _build_creating()
	_steps[Step.READY] = _build_ready()
	api = SocialApi.new()
	add_child(api)
	get_viewport().size_changed.connect(func(): if visible: _update_zones.call_deferred(2))


func begin(theme: Dictionary) -> void:
	reset()
	for l in _headings:
		l.add_theme_color_override("font_color", theme["text"])
	for l in _soft_labels:
		l.add_theme_color_override("font_color", theme["text_soft"])
	visible = true
	set_process(true)
	show_step(Step.CHOOSE)


## Leave: everything is forgotten; a reply still on its way is ignored.
func reset() -> void:
	_token += 1
	choice = ""
	current = null
	pending = null
	share_url = ""
	busy = false
	last_error = ""
	failed = ""
	seen_keys.clear()
	generator = null
	if _anim:
		_anim.kill()
	if _fade:
		_fade.kill()
	visible = false
	set_process(false)
	step = Step.CHOOSE
	for s in _steps:
		_steps[s].visible = false
	if _web:
		SocialWeb.reset()
		_publish()


## Back from PLAY / PREVIEW: the READY screen, challenge and link kept.
func resume_after_play() -> void:
	visible = true
	set_process(true)
	show_step(Step.READY if current != null else Step.CHOOSE)


func show_step(s: int) -> void:
	step = s
	if s == Step.READY:
		_refresh_ready()
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


# --- Creating -------------------------------------------------------------------

## One tap on a difficulty (or SURPRISE ME): generate and create.
func pick(p_choice: String) -> void:
	if busy or step != Step.CHOOSE:
		return  # double tap: one creation at a time
	AudioManager.play_ui_tap()
	choice = p_choice
	_start_new()


## NEW CHALLENGE: back to the difficulty choice (nothing is generated
## until a difficulty is picked). The current challenge and its link stay
## valid: BACK on the choice returns to them. Boards already shown in this
## session are still never repeated.
func new_challenge() -> void:
	if busy or step != Step.READY:
		return
	AudioManager.play_ui_tap()
	show_step(Step.CHOOSE)


func _start_new() -> void:
	busy = true
	failed = ""
	last_error = ""
	pending = null
	var surprise := choice == FriendGenerator.SURPRISE
	var d := FriendGenerator.resolve(choice, rng)
	var seed_value := (debug_seed + seen_keys.size()) if debug_seed != 0 else (rng.randi() | 1)
	generator = FriendGenerator.new(d, seed_value, seen_keys.duplicate())
	_gen_surprise = surprise
	_gen_frames = 0
	_show_creating()


func _show_creating() -> void:
	_c_title.text = "CREATING YOUR\nCHALLENGE…"
	_c_status.text = ""
	_c_status.visible = false
	_c_retry.visible = false
	_c_back.visible = true
	show_step(Step.CREATING)
	_start_anim()


## Generation runs in short slices, one per frame (the screen keeps
## drawing), after the CREATING screen has been drawn once.
func _generate_step() -> void:
	_gen_frames += 1
	if _gen_frames < 2 or not generator.step():
		return
	var g := generator
	generator = null
	if g.puzzle == null:
		push_warning("[Social] friend challenge not generated (%s)" % g.error)
		_fail("generate", g.error)
		return
	seen_keys.append(FriendGenerator.board_key(g.puzzle))
	pending = SharedChallenge.friend_challenge(g.puzzle, g.difficulty, _gen_surprise)
	_create()


## Sends `pending` (its exact puzzle) to the server. A reply that arrives
## after the creator left or cancelled is ignored.
func _create() -> void:
	if pending == null:
		return
	busy = true
	_token += 1
	var token := _token
	var r: Dictionary = await api.create_challenge(pending)
	if token != _token:
		return
	if not r.get("ok", false):
		_fail("create", str(r.get("error", "invalid_response")))
		return
	var url := ShareLink.build(ShareLink.default_base(), str(r["challenge_id"]))
	busy = false
	pending.remote_id = str(r["challenge_id"])
	pending.expires_at = str(r.get("expires_at", ""))
	current = pending
	pending = null
	share_url = url
	_stop_anim()
	show_step(Step.READY)


func _fail(kind: String, code: String) -> void:
	busy = false
	failed = kind
	last_error = code
	_stop_anim()
	if kind == "generate":
		_c_title.text = "COULDN'T CREATE\nA CHALLENGE"
		_c_status.text = "Please try again."
	else:
		_c_title.text = "COULDN'T GET YOUR\nLINK READY"
		_c_status.text = _error_text(code)
	_c_status.visible = true
	_c_retry.visible = true
	_c_back.visible = true
	_update_zones.call_deferred(1)


## TRY AGAIN: a failed create resends the SAME puzzle; a failed generation
## generates again (same choice).
func _retry() -> void:
	if busy:
		return
	AudioManager.play_ui_tap()
	if failed == "create" and pending != null:
		failed = ""
		_show_creating()
		_create()
	else:
		_start_new()


## BACK while creating / after an error: cancel, back to the difficulty
## choice (a challenge made before stays there: BACK again returns to it).
func _cancel() -> void:
	AudioManager.play_ui_tap()
	_token += 1
	busy = false
	generator = null
	pending = null
	failed = ""
	_stop_anim()
	show_step(Step.CHOOSE)


func _error_text(code: String) -> String:
	match code:
		"network", "timeout":
			return "Check your connection and try again."
		"rate_limited":
			return "Lots of challenges right now.\nPlease wait a minute and try again."
		"not_configured":
			return "Sharing isn't available in this version."
	return "Something went wrong on our side.\nPlease try again."


# --- READY --------------------------------------------------------------------------

func _refresh_ready() -> void:
	if current == null:
		return
	var dname: String = NAMES.get(current.difficulty, "")
	var surprise := current.is_surprise()
	_r_sub.text = ("SURPRISE PICK: %s" % dname) if surprise else ("%s CHALLENGE" % dname)
	_r_icon_dice.visible = surprise
	_r_icon_block.visible = not surprise
	_r_status.text = ""
	_r_status.visible = false
	_r_link.text = share_url if share_url != "" else "Links are made by the Web version"
	if _web:
		SocialWeb.set_share(share_url, SocialConfig.friend_share_text(current.difficulty), SocialConfig.SHARE_TITLE)


## Web: the page script already acted inside the tap (zones); the result
## arrives through _process. Elsewhere: copy the link.
func _share_pressed() -> void:
	AudioManager.play_ui_tap()
	if _web or share_url == "":
		return
	DisplayServer.clipboard_set(share_url)
	_show_share_result("copied")


## Only COPY LINK confirms anything: a hand-off to another app can't be
## confirmed by the browser, and the user sees that app open anyway.
func _show_share_result(r: String) -> void:
	match r:
		"copied":
			_r_status.text = "LINK COPIED"
		"failed":
			_r_status.text = "COULDN'T SHARE - TRY COPY LINK"
		_:
			_r_status.text = ""
	_r_status.visible = _r_status.text != ""


func _preview() -> void:
	AudioManager.play_ui_tap()
	if current != null and step == Step.READY:
		play_requested.emit(current)


# --- Frame / web ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible:
		return
	if step == Step.CREATING and generator != null:
		_generate_step()
		return
	if not _web or step != Step.READY:
		return
	_poll += delta
	if _poll < POLL:
		return
	_poll = 0.0
	var sr := SocialWeb.take_share_result()
	if sr != "":
		_show_share_result(sr)
		_publish()


func _update_zones(defers_left: int = 0) -> void:
	if defers_left > 0:
		_update_zones.call_deferred(defers_left - 1)
		return
	if not _web:
		return
	var zones := []
	if visible and step == Step.READY:
		var box: Control = _steps[Step.READY]
		zones.append(_zone("whatsapp", box.find_child("SendWhatsApp", true, false)))
		zones.append(_zone("share", box.find_child("ShareChallenge", true, false)))
		zones.append(_zone("copy", box.find_child("CopyLink", true, false)))
	SocialWeb.set_zones(zones)
	_publish()


func _zone(id: String, c: Control) -> Dictionary:
	var vis := get_viewport().get_visible_rect().size
	var r := c.get_global_rect()
	return {"id": id, "x": r.position.x / vis.x, "y": r.position.y / vis.y, "w": r.size.x / vis.x, "h": r.size.y / vis.y}


## Read-only snapshot for automated browser tests (window.chainEscapeFriend).
func _publish() -> void:
	if not OS.has_feature("web") or not is_inside_tree():
		return
	var vis := get_viewport().get_visible_rect().size
	var buttons := {}
	if visible:
		for b in _steps[step].find_children("*", "BaseButton", true, false):
			if b.is_visible_in_tree():
				var c: Vector2 = b.get_global_rect().get_center()
				buttons[String(b.name)] = [snappedf(c.x / vis.x, 0.0001), snappedf(c.y / vis.y, 0.0001), b.disabled]
	WebBridge.publish("chainEscapeFriend", {"open": visible, "step": Step.keys()[step], "choice": choice, "busy": busy,
		"difficulty": current.difficulty if current else "", "surprise": current.is_surprise() if current else false,
		"share_url": share_url, "error": last_error, "failed": failed, "buttons": buttons,
		"fingerprint": current.puzzle.fingerprint() if current else "", "boards": seen_keys.size(),
		"share_status": _r_status.text if _r_status else "", "subtitle": _r_sub.text if _r_sub else ""})


# --- Screens ----------------------------------------------------------------------------

func _build_choose() -> VBoxContainer:
	var box := _column()
	box.add_child(_heading("CHALLENGE A FRIEND"))
	box.add_child(_soft("Pick how hard it should be.", 26))
	for i in FriendGenerator.DIFFICULTIES.size():
		var id: String = FriendGenerator.DIFFICULTIES[i]
		var b := _card("Difficulty_%s" % id, NAMES[id], BLURB[id], Palette.WHITE)
		b.get_child(0).get_child(0).add_child(_pips(i + 1))
		b.pressed.connect(func(): pick(id))
		box.add_child(b)
	var s := _card("SurpriseMe", "SURPRISE ME", "We pick the difficulty.", SOFT_BG)
	var dice_slot := Control.new()
	dice_slot.custom_minimum_size = Vector2(44, 44)
	dice_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dice := Dice.new()
	dice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dice_slot.add_child(dice)
	s.get_child(0).get_child(0).add_child(dice_slot)
	s.pressed.connect(func(): pick(FriendGenerator.SURPRISE))
	box.add_child(s)
	var back := _button("BACK", "Back", Palette.WHITE, Palette.TEXT, 30, Vector2(460, 96))
	back.pressed.connect(func():
		if busy:
			return
		AudioManager.play_ui_tap()
		# After NEW CHALLENGE: back to the challenge already made, unchanged.
		if current != null:
			show_step(Step.READY)
		else:
			exit_requested.emit())
	box.add_child(back)
	return box


func _build_creating() -> VBoxContainer:
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
		b.face = [Palette.face("red"), COLOR, Palette.face("yellow")][i]
		b.dir = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP][i]
		b.half = 26.0
		b.position = Vector2(28, 28)
		slot.add_child(b)
		row.add_child(slot)
		_blocks.append(b)
	box.add_child(row)
	_c_title = _heading("CREATING YOUR\nCHALLENGE…")
	_c_title.name = "CreatingTitle"
	box.add_child(_c_title)
	_c_status = _soft("", 26)
	_c_status.name = "CreatingStatus"
	_c_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_c_status.custom_minimum_size = Vector2(WIDTH, 0)
	box.add_child(_c_status)
	_c_retry = _button("TRY AGAIN", "TryAgain", COLOR, Palette.WHITE, 30, Vector2(460, 104))
	_c_retry.pressed.connect(_retry)
	box.add_child(_c_retry)
	_c_back = _button("BACK", "Back", Palette.WHITE, Palette.TEXT, 30, Vector2(460, 96))
	_c_back.pressed.connect(_cancel)
	box.add_child(_c_back)
	return box


func _build_ready() -> VBoxContainer:
	var box := _column()
	box.add_theme_constant_override("separation", 18)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(76, 76)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(slot)
	var block_holder := Control.new()
	block_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := SocialScreen.EscapeBlock.new()
	icon.face = COLOR
	icon.dir = Vector2.RIGHT
	icon.half = 36.0
	icon.position = Vector2(38, 38)
	block_holder.add_child(icon)
	slot.add_child(block_holder)
	_r_icon_block = block_holder
	var dice := Dice.new()
	dice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(dice)
	_r_icon_dice = dice
	box.add_child(holder)
	box.add_child(_heading("CHALLENGE READY!"))
	_r_sub = _label("", 26, COLOR.darkened(0.25), 900)
	_r_sub.name = "ReadySubtitle"
	box.add_child(_r_sub)
	var whatsapp := _button("SEND ON WHATSAPP", "SendWhatsApp", COLOR, Palette.WHITE, 30, Vector2(460, 100))
	whatsapp.pressed.connect(_share_pressed)
	box.add_child(whatsapp)
	var share := _button("MORE WAYS TO SHARE", "ShareChallenge", SOFT_BG, Palette.TEXT, 28, Vector2(460, 90))
	share.pressed.connect(_share_pressed)
	box.add_child(share)
	var copy := _button("COPY LINK", "CopyLink", SOFT_BG, Palette.TEXT, 28, Vector2(460, 90))
	copy.pressed.connect(_share_pressed)
	box.add_child(copy)
	_r_status = _label("", 24, COLOR.darkened(0.25), 900)
	_r_status.name = "ShareStatus"
	_r_status.visible = false
	box.add_child(_r_status)
	_r_link = _label("", 18, Palette.TEXT_SOFT, 700)
	_r_link.name = "ShareLink"
	_r_link.custom_minimum_size = Vector2(WIDTH, 0)
	_r_link.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(_r_link)
	box.add_child(_soft("Only the link is shared. The link expires in 30 days.", 20))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_r_new = _button("NEW CHALLENGE", "NewChallenge", Palette.WHITE, Palette.TEXT, 22, Vector2(272, 88))
	_r_new.pressed.connect(new_challenge)
	row.add_child(_r_new)
	var preview := _button("PLAY / PREVIEW", "PreviewChallenge", Palette.WHITE, Palette.TEXT, 22, Vector2(272, 88))
	preview.pressed.connect(_preview)
	row.add_child(preview)
	box.add_child(row)
	var done := _button("DONE", "Done", Palette.WHITE, Palette.TEXT, 26, Vector2(460, 88))
	done.pressed.connect(func():
		AudioManager.play_ui_tap()
		exit_requested.emit())
	box.add_child(done)
	return box


# --- Building blocks ---------------------------------------------------------------

## A difficulty card: one tap = create. Icon area on the left, name and a
## short line on the right.
func _card(node_name: String, title: String, blurb: String, bg: Color) -> PillButton:
	var b := PillButton.new("", PillButton.Icon.NONE, bg, Palette.TEXT, 30)
	b.name = node_name
	b.custom_minimum_size = Vector2(WIDTH, 112)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover"]:
		b.add_theme_stylebox_override(state, _card_style(bg, TINT))
	for state in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(state, _card_style(bg.darkened(0.04), COLOR))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 36.0
	row.offset_right = -36.0
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var icon := CenterContainer.new()
	icon.custom_minimum_size = Vector2(96, 0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var t := _label(title, 30, Palette.TEXT, 900)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(t)
	var s := _label(blurb, 22, Palette.TEXT_SOFT, 700)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(s)
	return b


## 1-4 small Friend-colored blocks (difficulty at a glance).
func _pips(n: int) -> HBoxContainer:
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in 4:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(19, 19)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pip := SocialScreen.EscapeBlock.new()
		pip.face = COLOR if k < n else TINT
		pip.half = 9.0
		pip.dir = Vector2.UP
		pip.position = Vector2(9.5, 9.5)
		slot.add_child(pip)
		pips.add_child(slot)
	return pips


func _start_anim() -> void:
	_stop_anim()
	if SocialScreen.reduced_motion():
		return
	_anim = create_tween().set_loops()
	for b in _blocks:
		_anim.tween_property(b, "scale", Vector2(1.18, 1.18), 0.18)
		_anim.tween_property(b, "scale", Vector2.ONE, 0.18)


func _stop_anim() -> void:
	if _anim:
		_anim.kill()
		_anim = null
	for b in _blocks:
		b.scale = Vector2.ONE


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


func _button(text: String, node_name: String, bg: Color, fg: Color, fs: int, sz: Vector2) -> PillButton:
	var b := PillButton.new(text, PillButton.Icon.NONE, bg, fg, fs)
	b.name = node_name
	b.custom_minimum_size = sz
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(40)
	s.anti_aliasing = true
	s.set_border_width_all(3)
	s.border_color = border
	s.shadow_color = Palette.SHADOW
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s


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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


## A drawn die showing five (emoji render as boxes in the Web build).
class Dice extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var r := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
		var st := StyleBoxFlat.new()
		st.bg_color = COLOR.darkened(0.18)
		st.set_corner_radius_all(int(side * 0.22))
		st.anti_aliasing = true
		st.draw(get_canvas_item(), Rect2(r.position + Vector2(0, side * 0.06), r.size))
		st.bg_color = COLOR
		st.draw(get_canvas_item(), Rect2(r.position, r.size - Vector2(0, side * 0.04)))
		var c := r.get_center() - Vector2(0, side * 0.02)
		var o := side * 0.26
		for p in [Vector2(-o, -o), Vector2(o, -o), Vector2.ZERO, Vector2(-o, o), Vector2(o, o)]:
			draw_circle(c + p, side * 0.085, Color.WHITE)
