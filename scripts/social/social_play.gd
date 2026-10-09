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
## numbers. Its tools are free and per attempt, the same for every Social
## challenge: UNDO x3, SHOW A MOVE x2, HAMMER x2 (Restart / PLAY AGAIN start
## them over).
##
## Mode: CREATOR_PREVIEW (the creator plays their own challenge, 0.2B) or
## RECIPIENT (the person it was sent to, 0.2C phase 2). Both play the same
## PuzzleDefinition the same way; only texts and the end actions differ.

signal exited  # left before solving: nothing revealed
signal finished  # after the Reveal: BACK TO CREATE CHALLENGE / MAIN MENU
signal create_own(challenge_type: String)  # recipient's Reveal: CREATE YOUR OWN / CHALLENGE A FRIEND
signal photo_retry  # recipient's Reveal: the photo failed, TRY AGAIN
signal solved  # the board was cleared (just before the Reveal)

enum Mode { CREATOR_PREVIEW, RECIPIENT }

## Same undo allowance as a campaign attempt; hints come from the Solver
## (free, no boosters involved).
const MAX_UNDOS := GameManager.MAX_UNDOS
const MAX_HINTS := 2
## Free Hammers per attempt, in every Social challenge (Photo / Message
## Reveal and Challenge a Friend; provisional value for real-device testing,
## not an economy decision). Same smash rule as the Classic Hammer
## (Solver.hammer_safe + BoardModel.remove); no coins, inventory, shop or
## save are involved.
const MAX_HAMMERS := 2
const TOP_HEIGHT := 250.0
const BOTTOM_HEIGHT := 190.0
const ACCENT := Color("#C645E6")
const DIFFICULTY_NAMES := {"easy": "EASY", "medium": "MEDIUM", "hard": "HARD", "very_hard": "VERY HARD"}

var challenge: SharedChallenge
var mode: int = Mode.CREATOR_PREVIEW
var model := BoardModel.new()
var history := History.new()
var board: Board
var completed := false
var chain := 0
var undos_used := 0
var hints_used := 0
var hammers_used := 0
## Per-attempt allowances. The game always uses the defaults; only the
## development VERY HARD human test (?vhtest=1) sets its own (x1 / x1).
var max_hints := MAX_HINTS
var max_hammers := MAX_HAMMERS
## Totals for the current challenge across every attempt (start() resets
## them; RESTART / PLAY AGAIN do not). Read by the development human test.
var total_moves := 0
var total_undos := 0
var total_hints := 0
var total_hammers := 0
## Blocked taps (all), and - portal prototype, mechanic lab only - escapes
## and rams through a portal, and blocked taps whose lane ran through one.
## Always 0 portal counts on campaign / Social boards (no portals there).
var total_blocked := 0
var total_rams := 0
var total_portal_uses := 0
var total_portal_blocked := 0
## Sequence prototype (mechanic lab only; always 0 / empty elsewhere):
## first-stage advances, blocked taps on a first-stage block, second-stage
## escapes, spinner turns caused by advances, and one record per advance
## ({"ms": ticks, "cleared", "of", "turned"}).
var total_seq_advances := 0
var total_seq_blocked := 0
var total_seq_escapes := 0
var total_seq_spinner_turns := 0
var seq_events: Array = []
## Movable prototype (mechanic lab only; 0 / empty elsewhere): pushes,
## blocked taps into a crate that could not move, and one record per push
## ({"ms", "crate", "from", "to", "dir", "portal", "sequence", "cleared", "of"}).
var total_pushes := 0
var total_push_blocked := 0
var push_events: Array = []
## MAGNET lab: escapes of a magnet that pulled a block / pulled nothing.
var total_pulls := 0
var total_empty_pulls := 0
## The next board tap smashes a block (Social Hammer).
var hammer_armed := false
## Reveal's last button text ("" = the default for the mode).
var back_label := ""
## Fingerprint of the puzzle currently on the board (tests: PLAY AGAIN).
var loaded_fingerprint := ""
var plays := 0
## Recipient: the photo is still downloading ("loading") or failed
## ("failed"); "" = challenge.local_photo is all there is.
var photo_pending := ""

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
var _hammer: PillButton
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
	total_moves = 0
	total_undos = 0
	total_hints = 0
	total_hammers = 0
	total_blocked = 0
	total_rams = 0
	total_portal_uses = 0
	total_portal_blocked = 0
	total_seq_advances = 0
	total_seq_blocked = 0
	total_seq_escapes = 0
	total_seq_spinner_turns = 0
	seq_events = []
	total_pushes = 0
	total_push_blocked = 0
	push_events = []
	total_pulls = 0
	total_empty_pulls = 0
	_backdrop.set_colors(theme["bg_top"], theme["bg_bottom"])
	_title.add_theme_color_override("font_color", theme["text"])
	_chip.add_theme_color_override("font_color", theme["text_soft"])
	_progress.track_color = Color(1, 1, 1, 0.16) if theme["dark"] else theme["slot"]
	_progress.fill_color = ACCENT
	board.board_color = theme["board"]
	board.slot_color = theme["slot"]
	board.accent_color = theme["accent"]
	if c.type == SharedChallenge.TYPE_FRIEND_CHALLENGE:
		_title.text = "FRIEND CHALLENGE"
	else:
		_title.text = "SOLVE TO UNLOCK" if mode == Mode.RECIPIENT else "REVEAL CHALLENGE"
	_chip.text = DIFFICULTY_NAMES.get(c.difficulty, "")
	visible = true
	_load_puzzle()


## Leaves without revealing anything.
func end() -> void:
	_session += 1
	visible = false
	completed = false
	hammer_armed = false
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
	model.set_portals(level.portals)  # portal prototype: {} on every real board
	history.clear()
	completed = false
	chain = 0
	undos_used = 0
	hints_used = 0
	hammers_used = 0
	hammer_armed = false
	_total_blocks = model.block_count()
	reveal.hide_now()
	_confirm.visible = false
	board.mystery = level.mystery
	board.spent_rewards = {}
	board.hammer_mode = false
	board.portals = level.portals
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
	if hammer_armed:
		_smash(id)
		_publish.call_deferred()
		return
	match model.move_state(id):
		"ok": _escape(id)
		"advance": _advance(id)
		"push": _push(id)
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
	var via := _portal_via(id)
	if model.blocks[id].seq_stage == 2:
		total_seq_escapes += 1
	var magnet: bool = model.blocks[id].magnet
	var turned := model.remove(id)
	var revealed := model.last_revealed.duplicate()
	var unlocked := model.last_unlocked.duplicate()
	var pull := model.last_pull.duplicate()
	_play_mechanic_effects()
	chain += 1
	total_moves += 1
	board.play_escape(id, chain, turned, via)
	if magnet:
		# MAGNET: the block behind slides into the cell it left.
		if pull.is_empty():
			total_empty_pulls += 1
		else:
			total_pulls += 1
			board.play_pull(pull, SocialScreen.reduced_motion())
			AudioManager.play_push()
	AudioManager.play_escape(chain)
	if not via.is_empty():
		total_portal_uses += 1
		AudioManager.play("reveal", 0.7)  # portal prototype: placeholder "whoosh"
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
	var via := _portal_via(id)
	total_blocked += 1
	if model.blocks[id].seq_stage == 1:
		total_seq_blocked += 1
	if blocker != null and blocker.is_crate():
		total_push_blocked += 1  # Movable prototype: the crate could not move
	board.play_bump(id, blocker.id if blocker else -1, via)
	_mistake()
	if not via.is_empty():
		# Portal prototype: the reason may be far away - say where.
		total_portal_blocked += 1
		_show_message("Blocked after portal %s" % str(model.portal_groups.get(via[-1][0], "")))


## SEQUENCE PROTOTYPE: a first-stage block with a clear lane launches,
## comes back, sends the neighbour event and takes its next arrow (see
## BoardModel.advance). A real move: Undo-able, never a mistake; the chain
## is kept (it is not an escape).
func _advance(id: int) -> void:
	history.push({"blocks": model.snapshot(), "chain": chain})
	var turned := model.advance(id)
	var revealed := model.last_revealed.duplicate()
	total_seq_advances += 1
	total_seq_spinner_turns += turned.size()
	seq_events.append({"ms": Time.get_ticks_msec(), "cleared": _total_blocks - model.block_count(), "of": _total_blocks, "turned": turned.size()})
	board.play_advance(id, model.blocks[id].direction, turned)
	AudioManager.play("switch", 1.25)  # placeholder
	if not turned.is_empty():
		AudioManager.play_turn()
	if not revealed.is_empty():
		board.play_reveals(revealed)
		AudioManager.play_reveal()
	Haptics.light()
	_show_message("")
	_refresh_buttons()
	if model.playable_ids().is_empty():
		_show_message("No moves left - tap Undo" if undos_used < MAX_UNDOS else "No moves left - tap Restart")


## MOVABLE PROTOTYPE: `id` is launched into the crate in its lane; the crate
## moves one cell (BoardModel.push), `id` stays. A real move: Undo-able,
## never a mistake; the chain is kept (it is not an escape). A first-stage
## Sequence pusher also uses its first stage (counted as an advance).
func _push(id: int) -> void:
	history.push({"blocks": model.snapshot(), "chain": chain})
	var pusher_via := _portal_via(id)
	var info := model.push(id)
	if info.is_empty():
		return
	var revealed := model.last_revealed.duplicate() if info["advanced"] else []
	total_pushes += 1
	if not pusher_via.is_empty():
		total_portal_uses += 1
	if info["advanced"]:
		total_seq_advances += 1
		total_seq_spinner_turns += info["turned"].size()
		seq_events.append({"ms": Time.get_ticks_msec(), "cleared": _total_blocks - model.block_count(), "of": _total_blocks, "turned": info["turned"].size()})
	push_events.append({"ms": Time.get_ticks_msec(), "crate": info["crate"], "from": [info["from"].x, info["from"].y], "to": [info["to"].x, info["to"].y],
		"dir": Direction.NAMES[info["dir"]], "portal": not info["via"].is_empty() or not pusher_via.is_empty(), "sequence": info["advanced"],
		"cleared": _total_blocks - model.block_count(), "of": _total_blocks, "attempt": plays})
	board.play_push(id, info, pusher_via, SocialScreen.reduced_motion())
	AudioManager.play("hammer", 0.62)  # placeholder CLUNK
	if not info["turned"].is_empty():
		AudioManager.play_turn()
	if not revealed.is_empty():
		board.play_reveals(revealed)
		AudioManager.play_reveal()
	Haptics.medium()
	_show_message("")
	_refresh_buttons()
	if model.playable_ids().is_empty():
		_show_message("No moves left - tap Undo" if undos_used < MAX_UNDOS else "No moves left - tap Restart")


## Portal prototype: portals `id`'s lane runs through ([] on every real board).
func _portal_via(id: int) -> Array:
	return [] if model.portals.is_empty() else model.lane(id)["via"]


## A wrong tap: the usual buzz, the chain resets. No hearts in Social play.
func _mistake() -> void:
	AudioManager.play_invalid()
	Haptics.medium()
	chain = 0


func _ram(id: int) -> void:
	history.push({"blocks": model.snapshot(), "chain": chain})
	var via := _portal_via(id)
	var target := model.ram(id)
	total_rams += 1
	if not via.is_empty():
		total_portal_uses += 1
	board.play_ram(id, target, via)
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
	_disarm()
	undos_used += 1
	total_undos += 1
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
	_publish.call_deferred()  # tests read the board after an Undo too


func hint() -> void:
	if completed or model.is_empty():
		return
	if hints_used >= max_hints:
		_show_message("No SHOW A MOVE left - Undo or Restart can help")
		return
	var id := Solver.from_model(model).recommend_move()
	if id == -1:
		_show_message("No moves left - tap Undo" if model.playable_ids().is_empty() else "This board can't be cleared from here - try Undo")
		return
	hints_used += 1
	total_hints += 1
	board.set_hint(id)
	AudioManager.play_hint()
	_refresh_buttons()


# --- Hammer (every Social challenge) -------------------------------------------

func hammer_available() -> bool:
	return challenge != null


## Arms / disarms the Hammer (the button reads CANCEL while armed).
func toggle_hammer() -> void:
	if completed or not hammer_available():
		return
	AudioManager.play_ui_tap()
	if hammer_armed:
		_disarm()
		_show_message("")
		_publish.call_deferred()
		return
	if hammers_used >= max_hammers:
		_show_message("No Hammers left - Undo or Restart can help")
		return
	hammer_armed = true
	board.hammer_mode = true
	_show_message("Tap a block to smash it")
	_refresh_buttons()
	_publish.call_deferred()


func _disarm() -> void:
	if hammer_armed:
		hammer_armed = false
		board.hammer_mode = false
		_refresh_buttons()


## Removes the tapped block, as the Classic Hammer does, unless that would
## MAKE the puzzle unsolvable: then nothing is spent, the block shakes and
## the Hammer stays armed. Neighbouring spinners turn exactly as when a
## block escapes (same BoardModel.remove). Undo brings the block back (the
## Hammer is not refunded, as in Classic).
func _smash(id: int) -> void:
	if not model.blocks.has(id):
		return
	if not Solver.hammer_safe(model, id):
		AudioManager.play_invalid()
		board.play_hidden_tap(id)
		Haptics.medium()
		_show_message("That block is needed - pick another")
		return
	hammer_armed = false
	board.hammer_mode = false
	hammers_used += 1
	total_hammers += 1
	history.push({"blocks": model.snapshot(), "chain": chain})
	var turned := model.remove(id)
	var revealed := model.last_revealed.duplicate()
	var unlocked := model.last_unlocked.duplicate()
	_play_mechanic_effects()
	board.play_smash(id)
	board.animate_turns(turned)
	AudioManager.play_hammer()
	Haptics.medium()
	if not revealed.is_empty():
		board.play_reveals(revealed)
	if not unlocked.is_empty():
		board.play_unlocks(unlocked)
		AudioManager.play_unlock()
	_progress.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	_show_message("")
	_refresh_buttons()
	if model.is_empty():
		_on_solved()
	elif model.playable_ids().is_empty():
		_show_message("No moves left - tap Undo" if undos_used < MAX_UNDOS else "No moves left - tap Restart")


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
	solved.emit()
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
	reveal.show_reveal(challenge, _theme, mode, photo_pending if mode == Mode.RECIPIENT else "")
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
	_hint = UIManager.hint_button()
	_hint.name = "Hint"
	_hint.pressed.connect(hint)
	_bottom.add_child(_hint)
	# Same pill as the Classic Hammer, but always active: it is free here
	# (Photo / Message Reveal and Challenge a Friend alike).
	_hammer = PillButton.new("HAMMER", PillButton.Icon.HAMMER, Palette.WHITE, Palette.TEXT, 20, true, true)
	_hammer.name = "Hammer"
	_hammer.custom_minimum_size = Vector2(150, 104)
	_hammer.pressed.connect(toggle_hammer)
	_bottom.add_child(_hammer)
	_restart = _bottom_button("RESTART", PillButton.Icon.RESTART, restart)

	reveal = SocialReveal.new()
	reveal.play_again.connect(_play_again)
	reveal.done.connect(func():
		end()
		finished.emit())
	reveal.create_own.connect(func():
		var t := challenge.type if challenge else ""
		end()
		create_own.emit(t))
	reveal.photo_retry.connect(func(): photo_retry.emit())
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
	_hint.badge_text = str(max_hints - hints_used)
	_hint.modulate.a = 1.0 if hints_used < max_hints else 0.5
	_hint.disabled = completed
	_hammer.visible = hammer_available() and max_hammers > 0
	_hammer.text = "CANCEL" if hammer_armed else "HAMMER"
	_hammer.badge_text = str(max_hammers - hammers_used)
	_hammer.modulate.a = 1.0 if hammer_armed or hammers_used < max_hammers else 0.5
	_hammer.disabled = completed
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
	for b in [_exit, _undo, _hint, _hammer, _restart, reveal._again, reveal._back, reveal._cta, reveal._photo_retry,
			_confirm.find_child("KeepPlaying", true, false), _confirm.find_child("Leave", true, false)]:
		if b.is_visible_in_tree():
			buttons[String(b.name)] = norm.call(b.get_global_rect().get_center())
	WebBridge.publish("chainEscapeSocialPlay", {"active": visible, "completed": completed, "revealed": reveal.visible,
		"difficulty": challenge.difficulty if challenge else "", "blocks": model.block_count(), "free": free, "next": next,
		"fingerprint": loaded_fingerprint, "plays": plays, "hammers_left": max_hammers - hammers_used, "hammer_armed": hammer_armed, "confirm": _confirm.visible, "buttons": buttons,
		"has_photo": reveal._photo_frame.visible and reveal.visible, "photo_state": reveal.photo_state if reveal.visible else "",
		"cta_pulses": reveal.cta_pulses if reveal.visible else 0, "mode": "recipient" if mode == Mode.RECIPIENT else "creator",
		"magnets": board.magnet_links(), "pulls": total_pulls,
		"magnet_at": board.magnet_links().map(func(l): return norm.call(board.get_global_transform_with_canvas() * board.get_view(l[0]).home)) if visible else [],
		# The revealed text only for automated tests (never otherwise exposed).
		"message": reveal._message.text if reveal.visible and _test_hooks() else ""})


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
