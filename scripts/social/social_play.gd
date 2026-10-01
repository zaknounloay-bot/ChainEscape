class_name SocialPlay
extends CanvasLayer
## Social: plays one SharedChallenge's exact PuzzleDefinition with the
## Chain Escape engine (BoardModel rules, Board / BlockView visuals and
## animations, Solver hints, History undo, the same sounds), then shows the
## Reveal. Drawn on its own layer over the whole game.
##
## Kept apart from the campaign on purpose: it has its own model, board and
## history, never touches GameManager, PlayerProgress or the save, and the
## Classic level stays loaded (untouched) underneath - so Classic CONTINUE
## is exactly as it was. No hearts, coins, stars, score, boosters or level
## numbers.
##
## Mode: CREATOR_PREVIEW (the creator plays their own challenge, 0.2B) or
## RECIPIENT (the person it was sent to, later). Both play the same
## PuzzleDefinition the same way; only texts and the end actions differ.

signal exited  # left before solving: nothing revealed
signal finished  # after the Reveal: BACK TO CREATE CHALLENGE

enum Mode { CREATOR_PREVIEW, RECIPIENT }

## Same undo allowance as a campaign attempt; hints come from the Solver
## (free, no boosters involved).
const MAX_UNDOS := GameManager.MAX_UNDOS
const MAX_HINTS := 2
const TOP_HEIGHT := 250.0
const BOTTOM_HEIGHT := 190.0
const ACCENT := Color("#C645E6")
const DIFFICULTY_NAMES := {"easy": "EASY", "medium": "MEDIUM", "hard": "HARD"}

var challenge: SharedChallenge
var mode: int = Mode.CREATOR_PREVIEW
var model := BoardModel.new()
var history := History.new()
var board: Board
var completed := false
var chain := 0
var undos_used := 0
var hints_used := 0
## Reveal's last button text ("" = the default for the mode).
var back_label := ""
## Fingerprint of the puzzle currently on the board (tests: PLAY AGAIN).
var loaded_fingerprint := ""
var plays := 0

var _theme: Dictionary = {}
var _total_blocks := 0
var _session := 0
var _root: Control
var _backdrop: Backdrop
var _input: Control
var _title: Label
var _chip: Label
var _progress: BoardProgress
var _message: Label
var _exit: PillButton
var _undo: PillButton
var _hint: PillButton
var _restart: PillButton
var _bottom: HBoxContainer
var _confirm: Control
var reveal: SocialReveal
var _safe_top := 0.0
var _safe_bottom := 0.0


func _init() -> void:
	layer = 5  # above the game UI (1), below the debug panel (20)
	visible = false


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_layout)


## Plays `c` from its PuzzleDefinition (rebuilt from the serialized data,
## as any device would).
func start(c: SharedChallenge, p_mode: int, theme: Dictionary) -> void:
	challenge = c
	mode = p_mode
	_theme = theme
	plays = 0
	_backdrop.set_colors(theme["bg_top"], theme["bg_bottom"])
	_title.add_theme_color_override("font_color", theme["text"])
	_chip.add_theme_color_override("font_color", theme["text_soft"])
	_progress.track_color = Color(1, 1, 1, 0.16) if theme["dark"] else theme["slot"]
	_progress.fill_color = ACCENT
	board.board_color = theme["board"]
	board.slot_color = theme["slot"]
	board.accent_color = theme["accent"]
	_title.text = "REVEAL CHALLENGE"
	_chip.text = DIFFICULTY_NAMES.get(c.difficulty, "")
	visible = true
	_load_puzzle()


## Leaves without revealing anything.
func end() -> void:
	_session += 1
	visible = false
	completed = false
	if board:
		board.build(0, 0, [], false)
	model = BoardModel.new()
	history.clear()
	if reveal:
		reveal.hide_now()
	if _confirm:
		_confirm.visible = false
	challenge = null  # releases the photo (memory) with the session
	_publish()


func is_active() -> bool:
	return visible


## A fresh board from the challenge's PuzzleDefinition. Every (re)start
## goes through the serialized form, so PLAY AGAIN rebuilds exactly what a
## recipient would.
func _load_puzzle() -> void:
	_session += 1
	var def := PuzzleDefinition.from_json(challenge.puzzle.to_json())
	if def == null:
		push_error("Social: puzzle data could not be read")
		_leave()
		return
	challenge.puzzle = def
	loaded_fingerprint = def.fingerprint()
	plays += 1
	var level := def.to_level()
	model = BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	history.clear()
	completed = false
	chain = 0
	undos_used = 0
	hints_used = 0
	_total_blocks = model.block_count()
	reveal.hide_now()
	_confirm.visible = false
	board.mystery = level.mystery
	board.spent_rewards = {}
	board.hammer_mode = false
	board.build(level.rows, level.columns, level.blocks, true)
	board.refresh_locks(model)
	board.input_enabled = false  # taps come through _input (see _on_input)
	board.set_marks([])
	_progress.set_progress(0.0, false)
	_show_message("")
	_set_hud_visible(true)
	_layout()
	_refresh_buttons()
	_publish.call_deferred()


# --- Moves (same rules and feedback as a campaign level) ------------------------

func _on_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed):
		return
	if completed or not visible:
		return
	var canvas_pos: Vector2 = _input.get_global_transform_with_canvas() * event.position
	var local := board.get_global_transform_with_canvas().affine_inverse() * canvas_pos
	var id := board._find_block_near(local)
	if id != -1:
		tap_block(id)


func tap_block(id: int) -> void:
	if completed or not model.blocks.has(id):
		return
	board.clear_hint()
	match model.move_state(id):
		"ok": _escape(id)
		"blocked": _blocked(id)
		"ram": _ram(id)
		"locked":
			board.play_locked_tap(id, model.key_blocks(id))
			_mistake()
		_:
			board.play_hidden_tap(id)  # hidden / gate / armored: free, never a mistake
	_publish.call_deferred()


func _escape(id: int) -> void:
	history.push({"blocks": model.snapshot(), "chain": chain})
	var turned := model.remove(id)
	var revealed := model.last_revealed.duplicate()
	var unlocked := model.last_unlocked.duplicate()
	_play_mechanic_effects()
	chain += 1
	board.play_escape(id, chain, turned)
	AudioManager.play_escape(chain)
	if not turned.is_empty():
		AudioManager.play_turn()
	if not revealed.is_empty():
		board.play_reveals(revealed)
		AudioManager.play_reveal()
	if not unlocked.is_empty():
		board.play_unlocks(unlocked)
		AudioManager.play_unlock()
	if chain in GameManager.COMBO_MILESTONES:
		AudioManager.play_combo(chain)
	Haptics.light()
	_progress.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	_show_message("")
	_refresh_buttons()
	if model.is_empty():
		_on_solved()
	elif model.playable_ids().is_empty():
		_show_message("No moves left - tap Undo" if undos_used < MAX_UNDOS else "No moves left - tap Restart")


func _blocked(id: int) -> void:
	var blocker := model.find_blocker(id)
	board.play_bump(id, blocker.id if blocker else -1)
	_mistake()


## A wrong tap: the usual buzz, the chain resets. No hearts in Social play.
func _mistake() -> void:
	AudioManager.play_invalid()
	Haptics.medium()
	chain = 0


func _ram(id: int) -> void:
	history.push({"blocks": model.snapshot(), "chain": chain})
	var target := model.ram(id)
	board.play_ram(id, target)
	AudioManager.play_crack()
	Haptics.medium()
	_refresh_buttons()


func _play_mechanic_effects() -> void:
	if not model.last_flipped.is_empty():
		board.play_flips(model.last_flipped.duplicate(), model)
		AudioManager.play_switch()
	if not model.last_opened_gates.is_empty():
		board.play_gate_opens(model.last_opened_gates.duplicate())
		AudioManager.play_gate()
	board.refresh_locks(model)


func undo() -> void:
	if completed or not history.can_undo() or undos_used >= MAX_UNDOS:
		return
	undos_used += 1
	var state: Dictionary = history.pop()
	model.restore(state["blocks"])
	chain = state["chain"]
	board.clear_hint()
	board.sync_to(model.snapshot())
	board.refresh_locks(model)
	AudioManager.play_undo()
	_progress.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	_show_message("")
	_refresh_buttons()


func hint() -> void:
	if completed or model.is_empty():
		return
	if hints_used >= MAX_HINTS:
		_show_message("No hints left - Undo or Restart can help")
		return
	var id := Solver.from_model(model).recommend_move()
	if id == -1:
		_show_message("No moves left - tap Undo" if model.playable_ids().is_empty() else "This board can't be cleared from here - try Undo")
		return
	hints_used += 1
	board.set_hint(id)
	AudioManager.play_hint()
	_refresh_buttons()


func restart() -> void:
	AudioManager.play_ui_tap()
	_load_puzzle()


## Tests: one correct move (the Solver's pick). False if none.
func play_solver_move() -> bool:
	if completed:
		return false
	var id := Solver.from_model(model).recommend_move()
	if id == -1:
		return false
	tap_block(id)
	return true


# --- Solved: the Reveal ----------------------------------------------------------

func _on_solved() -> void:
	completed = true
	_refresh_buttons()
	var session := _session
	await get_tree().create_timer(0.25).timeout
	if session != _session:
		return
	board.celebrate()
	AudioManager.play_level_complete()
	Haptics.medium()
	await get_tree().create_timer(0.55).timeout
	if session != _session:
		return
	_set_hud_visible(false)
	reveal.show_reveal(challenge, _theme, mode)
	if back_label != "":
		reveal._back.text = back_label
	get_tree().create_timer(1.6).timeout.connect(_publish)


func _play_again() -> void:
	AudioManager.play_ui_tap()
	_load_puzzle()


func _leave() -> void:
	end()
	exited.emit()


# --- HUD ---------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_backdrop = Backdrop.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # nothing below is touchable
	_root.add_child(_backdrop)
	board = Board.new()
	board.input_enabled = false
	add_child(board)
	# Taps on the board arrive here (the backdrop would stop them otherwise).
	var input_layer := Control.new()
	input_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	input_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(input_layer)
	_input = Control.new()
	_input.name = "BoardInput"
	_input.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input.mouse_filter = Control.MOUSE_FILTER_STOP
	_input.gui_input.connect(_on_input)
	input_layer.add_child(_input)

	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	var top := VBoxContainer.new()
	top.name = "Top"
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top)
	_title = _label("REVEAL CHALLENGE", 34, Palette.TEXT, 900)
	_title.name = "ChallengeTitle"
	top.add_child(_title)
	_chip = _label("", 24, Palette.TEXT_SOFT, 900)
	_chip.name = "DifficultyChip"
	top.add_child(_chip)
	var bar_holder := CenterContainer.new()
	bar_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress = BoardProgress.new()
	_progress.custom_minimum_size = Vector2(360, 16)
	bar_holder.add_child(_progress)
	top.add_child(bar_holder)
	_exit = PillButton.new("EXIT", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT_SOFT, 22)
	_exit.name = "Exit"
	_exit.custom_minimum_size = Vector2(120, 76)
	_exit.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_exit.pressed.connect(func():
		AudioManager.play_ui_tap()
		_confirm.visible = true
		_publish.call_deferred())
	hud.add_child(_exit)
	_message = _label("", 24, Palette.TEXT, 800)
	_message.name = "Message"
	_message.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(_message)
	_bottom = HBoxContainer.new()
	_bottom.name = "Bottom"
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_theme_constant_override("separation", 14)
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_bottom)
	_undo = _bottom_button("UNDO", PillButton.Icon.UNDO, undo)
	_hint = _bottom_button("HINT", PillButton.Icon.HINT, hint)
	_restart = _bottom_button("RESTART", PillButton.Icon.RESTART, restart)

	reveal = SocialReveal.new()
	reveal.play_again.connect(_play_again)
	reveal.done.connect(func():
		end()
		finished.emit())
	add_child(reveal)
	_confirm = _build_confirm()
	add_child(_confirm)


func _bottom_button(text: String, icon: int, action: Callable) -> PillButton:
	var b := PillButton.new(text, icon, Palette.WHITE, Palette.TEXT, 20, true, true)
	b.name = text.capitalize()
	b.custom_minimum_size = Vector2(150, 104)
	b.pressed.connect(action)
	_bottom.add_child(b)
	return b


## "Leave the challenge?" - leaving never reveals anything.
func _build_confirm() -> Control:
	var dim := ColorRect.new()
	dim.name = "LeaveConfirm"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(Palette.TEXT, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(center)
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.WHITE
	st.set_corner_radius_all(40)
	st.anti_aliasing = true
	st.set_content_margin_all(36)
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(540, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	box.add_child(_label("LEAVE THE CHALLENGE?", 36, Palette.TEXT, 900))
	var why := _label("The reveal stays hidden until the puzzle is solved.", 24, Palette.TEXT_SOFT, 800)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(460, 0)
	box.add_child(why)
	var keep := PillButton.new("KEEP PLAYING", PillButton.Icon.NONE, ACCENT, Palette.WHITE, 28)
	keep.name = "KeepPlaying"
	keep.custom_minimum_size = Vector2(0, 96)
	keep.pressed.connect(func():
		AudioManager.play_ui_tap()
		dim.visible = false)
	box.add_child(keep)
	var leave := PillButton.new("LEAVE", PillButton.Icon.NONE, Palette.BACKGROUND, Palette.TEXT, 26)
	leave.name = "Leave"
	leave.custom_minimum_size = Vector2(0, 88)
	leave.pressed.connect(func():
		AudioManager.play_ui_tap()
		_leave())
	box.add_child(leave)
	return dim


func _set_hud_visible(on: bool) -> void:
	for n in [_title, _chip, _progress.get_parent(), _exit, _message, _bottom]:
		n.visible = on
	_input.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	board.visible = on


func _refresh_buttons() -> void:
	_undo.badge_text = str(MAX_UNDOS - undos_used)
	_undo.disabled = completed or not history.can_undo() or undos_used >= MAX_UNDOS
	_hint.badge_text = str(MAX_HINTS - hints_used)
	_hint.modulate.a = 1.0 if hints_used < MAX_HINTS else 0.5
	_hint.disabled = completed
	_restart.disabled = completed


func _show_message(text: String) -> void:
	_message.text = text


## Web: read-only snapshot for automated browser tests
## (window.chainEscapeSocialPlay), like window.chainEscapeState. Positions
## are normalized (0..1) screen coordinates.
func _publish() -> void:
	if not OS.has_feature("web"):
		return
	var vis := get_viewport().get_visible_rect().size
	var norm := func(p: Vector2) -> Array: return [snappedf(p.x / vis.x, 0.0001), snappedf(p.y / vis.y, 0.0001)]
	var free := []
	var next := []
	if visible and not completed:
		var to_screen := board.get_global_transform_with_canvas()
		for id in model.playable_ids():
			free.append(norm.call(to_screen * board.get_view(id).home))
		# The Solver's next move, only for automated browser tests that ask
		# for it (window.ceTestHooks): players never pay for the extra solve.
		if _test_hooks():
			var hint_id := Solver.from_model(model).recommend_move()
			if hint_id != -1:
				next = norm.call(to_screen * board.get_view(hint_id).home)
	var buttons := {}
	for b in [_exit, _undo, _hint, _restart, reveal._again, reveal._back,
			_confirm.find_child("KeepPlaying", true, false), _confirm.find_child("Leave", true, false)]:
		if b.is_visible_in_tree():
			buttons[String(b.name)] = norm.call(b.get_global_rect().get_center())
	WebBridge.publish("chainEscapeSocialPlay", {"active": visible, "completed": completed, "revealed": reveal.visible,
		"difficulty": challenge.difficulty if challenge else "", "blocks": model.block_count(), "free": free, "next": next,
		"fingerprint": loaded_fingerprint, "plays": plays, "confirm": _confirm.visible, "buttons": buttons,
		"has_photo": reveal._photo_frame.visible and reveal.visible, "message": reveal._message.text if reveal.visible else ""})


static var _hooks_checked := false
static var _hooks := false


static func _test_hooks() -> bool:
	if not _hooks_checked:
		_hooks_checked = true
		var w := JavaScriptBridge.get_interface("window")
		_hooks = w != null and bool(w.ceTestHooks)
	return _hooks


func _layout() -> void:
	if _root == null:
		return
	_safe_top = 0.0
	_safe_bottom = 0.0
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := Rect2(DisplayServer.get_display_safe_area())
		var scale_y := get_viewport().get_visible_rect().size.y / maxf(win.y, 1.0)
		_safe_top = safe.position.y * scale_y
		_safe_bottom = maxf(0.0, (win.y - safe.end.y) * scale_y)
	var top: Control = _title.get_parent()
	top.offset_top = _safe_top + 34.0
	_exit.offset_left = 24.0
	_exit.offset_right = 24.0 + 120.0
	_exit.offset_top = _safe_top + 28.0
	_exit.offset_bottom = _safe_top + 28.0 + 76.0
	_bottom.offset_top = -_safe_bottom - BOTTOM_HEIGHT + 40.0
	_bottom.offset_bottom = -_safe_bottom - 46.0
	_message.offset_top = -_safe_bottom - BOTTOM_HEIGHT - 50.0
	_message.offset_bottom = -_safe_bottom - BOTTOM_HEIGHT + 4.0
	_message.offset_left = 30.0
	_message.offset_right = -30.0
	board.layout(board_area())


func board_area() -> Rect2:
	var vis := get_viewport().get_visible_rect()
	var t := _safe_top + TOP_HEIGHT
	var b := vis.size.y - _safe_bottom - BOTTOM_HEIGHT - 50.0
	return Rect2(Vector2(24.0, t), Vector2(vis.size.x - 48.0, maxf(b - t, 100.0)))


func _label(t: String, fs: int, col: Color, weight: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	return l


## Opaque Chapter-tinted backdrop (rect bands, redrawn only on change).
class Backdrop extends Control:
	var top := Palette.BACKGROUND
	var bottom := Palette.BACKGROUND

	func set_colors(t: Color, b: Color) -> void:
		top = t
		bottom = b
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var bands := 32
		for i in bands:
			var y0 := size.y * i / bands
			var y1 := size.y * (i + 1) / bands
			draw_rect(Rect2(0, y0, size.x, y1 - y0 + 1.0), top.lerp(bottom, (i + 0.5) / bands))
