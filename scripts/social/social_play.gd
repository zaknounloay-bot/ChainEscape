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
## numbers. Its tools are free and per attempt (Restart / PLAY AGAIN start
## them over): UNDO x3, SHOW A MOVE x2, HAMMER x2 in a Photo / Message
## Reveal; in Challenge a Friend they depend on the difficulty
## (FRIEND_TOOLS, phase 4).
##
## Challenge a Friend only (phase 4): a TIME counter. One AttemptTimer runs
## for the whole challenge session - RESTART keeps it going, PLAY AGAIN
## (after solving) starts a fresh timed run. It pauses while the page is
## hidden or the EXIT dialog is open, and the final time is shown on the
## solved screen. Never saved or sent anywhere.
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
## Challenge a Friend (phase 4): [UNDO, SHOW A MOVE, HAMMER] per attempt by
## difficulty. Restart stays unlimited. An unknown difficulty gets the
## strictest set.
const FRIEND_TOOLS := {
	"easy": [3, 2, 2],
	"medium": [3, 2, 1],
	"hard": [3, 1, 1],
	"very_hard": [3, 1, 0],
}
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
## Per-attempt allowances, set by start(): the defaults for a Photo /
## Message Reveal, FRIEND_TOOLS for Challenge a Friend. Development pages
## (?vhtest / ?mechlab) set their own and turn on `dev_assist`, so start()
## keeps them (and shows no timer).
var max_undos := MAX_UNDOS
var max_hints := MAX_HINTS
var max_hammers := MAX_HAMMERS
var dev_assist := false
## Challenge a Friend: the session clock (see the class comment) and the
## final time of the last solve (ms, -1 = none yet).
var timer := AttemptTimer.new()
var final_time_ms := -1
## Times the TIME text changed (tests: once per visible second, no more).
var time_updates := 0
## ARMOR in a Photo / Message Reveal (phase 4): taught the first time, in
## play - a finger on the block aimed at the shell (brackets on both) until
## the player hits it themselves; nothing is played for them, and there is
## no separate intro card. RESTART / Undo keep teaching until that hit;
## after it, later Armor boards in this session play freely. Nothing is
## saved (a recipient may never have played Chain Escape).
static var armor_learned := false
var lesson_armor := false
var _tutor: TutorialHint
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
var _time: Label
var _time_second := -1
var _frame_usec := 0
var _visibility_cb: JavaScriptObject


func _init() -> void:
	layer = 5  # above the game UI (1), below the debug panel (20)
	visible = false


func _ready() -> void:
	_build()
	get_viewport().size_changed.connect(_layout)
	_watch_page_visibility()


## Plays `c` from its PuzzleDefinition (rebuilt from the serialized data,
## as any device would).
func start(c: SharedChallenge, p_mode: int, theme: Dictionary) -> void:
	challenge = c
	mode = p_mode
	_theme = theme
	if not dev_assist:
		var tools: Array = FRIEND_TOOLS.get(c.difficulty, FRIEND_TOOLS["very_hard"]) if is_timed() else [MAX_UNDOS, MAX_HINTS, MAX_HAMMERS]
		max_undos = tools[0]
		max_hints = tools[1]
		max_hammers = tools[2]
	_reset_timer()
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
	# Reveals show no difficulty (phase 4 MVP): the puzzle is the way to the
	# surprise, not a challenge.
	_chip.text = DIFFICULTY_NAMES.get(c.difficulty, "") if c.type == SharedChallenge.TYPE_FRIEND_CHALLENGE else ""
	_time.add_theme_color_override("font_color", theme["text"])
	visible = true
	_load_puzzle()


## Leaves without revealing anything.
func end() -> void:
	_session += 1
	_stop_armor_lesson()
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
	_maybe_teach_armor()
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
	if lesson_armor:
		_tutor.hide_hint()
		_lesson_step.call_deferred()  # after this tap: point again (or done)
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
		"armored":
			board.play_hidden_tap(id)  # free, never a mistake
			_show_message("ARMOR: another block has to hit it first")
		_:
			board.play_hidden_tap(id)  # hidden / gate: free, never a mistake
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
		_show_message("No moves left - tap Undo" if undos_used < max_undos else "No moves left - tap Restart")


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
		_show_message("No moves left - tap Undo" if undos_used < max_undos else "No moves left - tap Restart")


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
		_show_message("No moves left - tap Undo" if undos_used < max_undos else "No moves left - tap Restart")


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
	if lesson_armor:
		_finish_armor_lesson()


func _play_mechanic_effects() -> void:
	if not model.last_flipped.is_empty():
		board.play_flips(model.last_flipped.duplicate(), model)
		AudioManager.play_switch()
	if not model.last_opened_gates.is_empty():
		board.play_gate_opens(model.last_opened_gates.duplicate())
		AudioManager.play_gate()
	board.refresh_locks(model)


func undo() -> void:
	if completed or not history.can_undo() or undos_used >= max_undos:
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
	if lesson_armor:
		_lesson_step.call_deferred()
	_progress.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	_show_message("")
	_refresh_buttons()
	_publish.call_deferred()  # tests read the board after an Undo too


func hint() -> void:
	if completed or model.is_empty():
		return
	if hints_used >= max_hints:
		_show_message("No SHOW A MOVE left - Undo or Restart can help")
		_publish.call_deferred()
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
	_publish.call_deferred()


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
		_show_message("No Hammer in %s challenges" % DIFFICULTY_NAMES.get(challenge.difficulty, "these") if max_hammers == 0
			else "No Hammers left - Undo or Restart can help")
		_publish.call_deferred()
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
	if hammers_used >= max_hammers:  # never spend a Hammer that isn't there
		_disarm()
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
		_show_message("No moves left - tap Undo" if undos_used < max_undos else "No moves left - tap Restart")


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
	if is_timed():
		final_time_ms = timer.finish()
		_set_time_text(final_time_ms, true)
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
	reveal.show_reveal(challenge, _theme, mode, photo_pending if mode == Mode.RECIPIENT else "", final_time_ms if is_timed() else -1)
	if back_label != "":
		reveal._back.text = back_label
	_publish.call_deferred()  # tests: the reveal (moment) has started
	get_tree().create_timer(1.6).timeout.connect(_publish)


func _play_again() -> void:
	AudioManager.play_ui_tap()
	_reset_timer()  # a fresh timed run (RESTART keeps the clock going)
	_load_puzzle()


func _leave() -> void:
	end()
	exited.emit()


# --- ARMOR first encounter (Photo / Message Reveal, phase 4) ---------------------

func has_armor() -> bool:
	return model.blocks.values().any(func(b): return b.armored)


func _maybe_teach_armor() -> void:
	_stop_armor_lesson()
	if dev_assist or armor_learned or not has_armor():
		return
	lesson_armor = true
	_lesson_step.call_deferred()


## One beat: brackets on the shell and on the block aimed at it, the finger
## on that block (the hit is always the key move), one short line.
func _lesson_step() -> void:
	if not lesson_armor or completed:
		return
	if not has_armor():
		_stop_armor_lesson()  # the shell is gone another way (Hammer)
		return
	var marks := []
	for b in model.blocks.values():
		if b.armored:
			marks.append(b.id)
	var target := -1
	for id in model.blocks.keys():
		if model.move_state(id) == "ram":
			target = id
			break
	var text := "Tap the marked block: it hits the ARMOR and cracks the shell"
	if target == -1:
		target = Solver.from_model(model).recommend_move()
		text = "ARMOR can't escape until another block hits it"
	else:
		marks.append(target)
	board.set_marks(marks)
	if target != -1:
		_tutor.show_hint("", Vector2.ZERO, board.block_screen_position(target), true)
	_show_message(text)
	_publish.call_deferred()


func _finish_armor_lesson() -> void:
	_stop_armor_lesson()
	armor_learned = true
	_show_message("Shell cracked! Now it escapes like any block")


func _stop_armor_lesson() -> void:
	lesson_armor = false
	if _tutor:
		_tutor.hide_hint(true)
	if board:
		board.set_marks([])


# --- Challenge a Friend timer (phase 4) ---------------------------------------------

## A Challenge a Friend in the game (development pages excluded).
func is_timed() -> bool:
	return challenge != null and challenge.type == SharedChallenge.TYPE_FRIEND_CHALLENGE and not dev_assist


## Is the clock running this frame? Only while the board is in play: shown,
## not solved, no EXIT dialog. (A hidden page: AttemptTimer.page_hidden.)
func clock_active() -> bool:
	return visible and not completed and not _confirm.visible


func _reset_timer() -> void:
	timer.reset()
	final_time_ms = -1
	_frame_usec = Time.get_ticks_usec()
	_set_time_text(0, true)


func _process(_delta: float) -> void:
	# The real monotonic clock between frames (as GameManager's attempt
	# clock): Godot smooths `delta`. Text changes once per visible second.
	var now := Time.get_ticks_usec()
	var dt := (now - _frame_usec) / 1_000_000.0
	_frame_usec = now
	if not is_timed() or completed:
		return
	timer.tick(dt, clock_active())
	_set_time_text(timer.elapsed_ms())


func _set_time_text(ms: int, force: bool = false) -> void:
	var sec := maxi(ms, 0) / 1000
	if sec == _time_second and not force:
		return
	_time_second = sec
	_time.text = "TIME  " + UIManager.fmt_time(ms)
	time_updates += 1
	if OS.has_feature("web") and _test_hooks():
		_publish.call_deferred()  # browser tests only: the snapshot follows the clock


## Tests (and native pause): the page went hidden / visible.
func set_page_hidden(hidden: bool) -> void:
	timer.set_page_hidden(hidden)
	_publish.call_deferred()


## Web: Safari in the background, the phone locked, another tab - the clock
## stops until the page is visible again (as GameManager does for Classic).
func _watch_page_visibility() -> void:
	if not OS.has_feature("web"):
		return
	var doc = JavaScriptBridge.get_interface("document")
	var win = JavaScriptBridge.get_interface("window")
	if doc == null or win == null:
		return
	_visibility_cb = JavaScriptBridge.create_callback(_on_page_visibility)
	doc.addEventListener("visibilitychange", _visibility_cb)
	win.addEventListener("pagehide", _visibility_cb)
	win.addEventListener("pageshow", _visibility_cb)
	timer.set_page_hidden(bool(doc.hidden))


func _on_page_visibility(args: Array) -> void:
	var doc = JavaScriptBridge.get_interface("document")
	var hidden := bool(doc.hidden) if doc != null else false
	if not args.is_empty() and args[0] != null and str(args[0].type) == "pagehide":
		hidden = true
	set_page_hidden(hidden)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		timer.set_page_hidden(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		timer.set_page_hidden(false)


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
	# Challenge a Friend: the live TIME (tabular digits: the width never
	# jumps as the seconds change).
	_time = _label("", 34, Palette.TEXT, 900)
	_time.name = "FriendTime"
	var digits := FontVariation.new()
	digits.base_font = Palette.font(900)
	digits.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	_time.add_theme_font_override("font", digits)
	_time.visible = false
	top.add_child(_time)
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

	_tutor = TutorialHint.new()
	_tutor.name = "ArmorLesson"
	add_child(_tutor)
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
	reveal.moment_done.connect(func():
		_publish.call_deferred()
		get_tree().create_timer(0.9).timeout.connect(_publish))  # after the CTA's one pulse
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
	_time.visible = on and is_timed()
	_chip.visible = on and _chip.text != ""  # reveals: no difficulty line
	_input.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	board.visible = on


func _refresh_buttons() -> void:
	_undo.badge_text = str(max_undos - undos_used)
	_undo.disabled = completed or not history.can_undo() or undos_used >= max_undos
	_hint.badge_text = str(max_hints - hints_used)
	_hint.modulate.a = 1.0 if hints_used < max_hints else 0.5
	_hint.disabled = completed
	# Challenge a Friend shows a Hammer it doesn't have (VERY HARD) dimmed at
	# 0, so the player sees it is not part of this difficulty; a tap only
	# explains. Development pages keep hiding it.
	_hammer.visible = hammer_available() and (max_hammers > 0 or (is_timed() and not dev_assist))
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
	var norm_rect := func(r: Rect2) -> Array: return [snappedf(r.position.x / vis.x, 0.0001), snappedf(r.position.y / vis.y, 0.0001),
		snappedf(r.end.x / vis.x, 0.0001), snappedf(r.end.y / vis.y, 0.0001)]
	var rect := func(c: Control) -> Array: return norm_rect.call(c.get_global_rect()) if c.is_visible_in_tree() else []
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
	WebBridge.publish("chainEscapeSocialPlay", {"active": visible, "completed": completed, "revealed": reveal.visible, "reveal_phase": reveal.phase if reveal.visible else "", "reveal_skipped": reveal.skipped, "reveal_moment_ms": reveal.moment_ms,
		"difficulty": challenge.difficulty if challenge else "", "blocks": model.block_count(), "free": free, "next": next,
		"fingerprint": loaded_fingerprint, "plays": plays, "hammers_left": max_hammers - hammers_used,
		"hints_left": max_hints - hints_used, "undos_left": max_undos - undos_used,
		"tools": [max_undos, max_hints, max_hammers], "timed": is_timed(), "time_ms": timer.elapsed_ms(), "time_text": _time.text,
		"time_visible": _time.is_visible_in_tree(), "final_time_ms": final_time_ms, "time_updates": time_updates,
		"page_hidden": timer.page_hidden, "message_text": _message.text,
		"lesson": "armor" if lesson_armor else "", "armor_learned": armor_learned,
		"lesson_finger": norm.call(_tutor._target) if lesson_armor and _tutor.visible else [],
		"marked": board._views.keys().filter(func(v): return board._views[v].marked).map(func(v): return norm.call(board.get_global_transform_with_canvas() * board.get_view(v).home)) if visible else [],
		"armored": model.blocks.values().filter(func(b): return b.armored).map(func(b): return norm.call(board.get_global_transform_with_canvas() * board.get_view(b.id).home)) if visible and not completed else [],
		"reveal_time": reveal._time_value.text if reveal._time_box.visible else "", "reveal_heading_text": reveal._heading.text if reveal.visible else "",
		"rects": {"time": rect.call(_time), "chip": rect.call(_chip), "title": rect.call(_title), "exit": rect.call(_exit),
			"progress": rect.call(_progress), "bottom": rect.call(_bottom), "board": norm_rect.call(board_area()),
			"reveal_time": rect.call(reveal._time_box), "reveal_heading": rect.call(reveal._heading),
			"reveal_column": rect.call(reveal._column), "reveal_photo": rect.call(reveal._photo_frame), "reveal_message": rect.call(reveal._message_card)}, "hammer_armed": hammer_armed, "confirm": _confirm.visible, "buttons": buttons,
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
	if lesson_armor:
		_lesson_step.call_deferred()  # the finger follows the board


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
