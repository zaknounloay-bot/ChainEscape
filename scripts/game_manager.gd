class_name GameManager
extends Node
## Orchestrates a play session: loads levels, applies the rules through
## BoardModel, records History for undo, tracks chains, hearts, hints,
## undos and score, and tells the Board / UI / Audio what to show.
##
## All systems talk to each other through this node via signals, so each of
## them stays small and replaceable.

## Chain values that trigger the extra "combo" sound.
const COMBO_MILESTONES := [3, 5, 8, 12, 16, 20]
## Hearts are used from this level on (levels before it are onboarding).
const HEARTS_FROM_LEVEL := 6
const MAX_HEARTS := 3
## Undo uses per level attempt.
const MAX_UNDOS := 3

@onready var level_manager: LevelManager = $LevelManager
@onready var board: Board = $Board
@onready var tutorial: TutorialHint = $TutorialHint
@onready var ui: UIManager = $UI
@onready var debug_panel: DebugPanel = $DebugPanel

var model := BoardModel.new()
var history := History.new()
var progress: PlayerProgress
var level: LevelData
var current_level: int = 1

var chain: int = 0
var best_chain: int = 0
## Blocked or locked taps this attempt.
var mistakes: int = 0
var completed: bool = false
## Hearts left this attempt, and the level's maximum (0 = no hearts).
var hearts: int = 0
var max_hearts: int = 0
## True while the "out of hearts" state is showing (input locked).
var game_over: bool = false
## Block currently highlighted by a hint (-1 = none).
var hint_block: int = -1
var undos_used: int = 0
var hints_used: int = 0
## Points from escapes (restored by Undo, so undone moves score nothing).
var escape_points: int = 0
## Settled result of the last completed level (for tests / UI).
var last_result: Dictionary = {}

var _total_blocks: int = 0
var _blocked_hint_shown := false
var _locked_hint_shown := false
var _hidden_hint_shown := false
var _session_id: int = 0  # bumps on every level start; cancels stale timers
var _solving := false


func _ready() -> void:
	progress = PlayerProgress.new().load_from_disk()
	_apply_settings()
	board.block_tapped.connect(_on_block_tapped)
	ui.undo_pressed.connect(undo)
	ui.restart_pressed.connect(restart)
	ui.next_pressed.connect(next_level)
	ui.replay_pressed.connect(replay)
	ui.hint_pressed.connect(request_hint)
	ui.setting_toggled.connect(_on_setting_toggled)
	ui.levels_opened.connect(open_level_select)
	ui.level_chosen.connect(func(n): start_level(n))
	ui.title_tapped.connect(debug_panel.register_title_tap)
	debug_panel.level_count = level_manager.level_count
	debug_panel.level_requested.connect(func(n): start_level(wrapi(n, 1, level_manager.level_count + 1)))
	debug_panel.restart_requested.connect(restart)
	debug_panel.coords_toggled.connect(func(on): board.show_coords = on)
	debug_panel.hint_requested.connect(play_hint_move)
	debug_panel.solve_requested.connect(auto_solve)
	debug_panel.visibility_changed.connect(_refresh_buttons)
	get_viewport().size_changed.connect(_layout)
	start_level(_initial_level())
	AudioManager.start_music()


func _initial_level() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			return clampi(int(arg.get_slice("=", 1)), 1, level_manager.level_count)
	return clampi(progress.current_level, 1, maxi(level_manager.level_count, 1))


# --- Level flow ------------------------------------------------------------

func start_level(number: int) -> void:
	var data := level_manager.load_level(number)
	if data == null:
		return
	_session_id += 1
	_solving = false
	level = data
	current_level = number
	model.setup(level.rows, level.columns, level.blocks)
	history.clear()
	chain = 0
	best_chain = 0
	mistakes = 0
	undos_used = 0
	hints_used = 0
	escape_points = 0
	completed = false
	game_over = false
	hint_block = -1
	_blocked_hint_shown = false
	_locked_hint_shown = false
	_hidden_hint_shown = false
	_total_blocks = model.block_count()
	max_hearts = level.hearts if level.hearts >= 0 else (MAX_HEARTS if number >= HEARTS_FROM_LEVEL else 0)
	hearts = max_hearts

	board.mystery = level.mystery
	board.build(level.rows, level.columns, level.blocks, true)
	board.refresh_locks(model)
	board.input_enabled = true
	ui.set_level(number, level_manager.level_count, level.name, level.mystery)
	ui.set_progress(0.0, false)
	ui.set_hearts(max_hearts, hearts)
	_refresh_buttons()
	tutorial.hide_hint(true)
	_layout()
	if level.hint != "":
		_show_start_hint()
	progress.current_level = number
	progress.save()
	debug_panel.set_current_level(number)


func restart() -> void:
	AudioManager.play_ui_tap()
	start_level(current_level)


func replay() -> void:
	AudioManager.play_ui_tap()
	start_level(current_level)


func next_level() -> void:
	AudioManager.play_ui_tap()
	start_level(current_level % level_manager.level_count + 1)


func _layout() -> void:
	board.layout(ui.get_board_area())
	if tutorial.is_showing() and level and level.hint != "" and not completed:
		_show_start_hint()


## Hints this level may use: level override, else 0 before 20, 1 for 20-29,
## 2 from 30 on.
func hints_allowed() -> int:
	if level and level.hints >= 0:
		return level.hints
	if current_level >= 30:
		return 2
	if current_level >= 20:
		return 1
	return 0


# --- Moves -----------------------------------------------------------------

func _on_block_tapped(id: int) -> void:
	if completed or game_over or not model.blocks.has(id):
		return
	if tutorial.is_showing():
		tutorial.hide_hint()
	match model.move_state(id):
		"ok": _escape(id)
		"blocked": _blocked(id)
		"locked": _locked_tap(id)
		"hidden": _hidden_tap(id)


func _escape(id: int) -> void:
	history.push(_capture_state())
	var at := board.get_view(id).home
	var turned := model.remove(id)
	var revealed := model.last_revealed.duplicate()
	var unlocked := model.last_unlocked.duplicate()
	chain += 1
	best_chain = maxi(best_chain, chain)
	var points := ScoreRules.escape_points(chain)
	escape_points += points
	_clear_hint()

	board.play_escape(id, chain, turned)
	board.show_points(at, "+%d" % points)
	AudioManager.play_escape(chain)
	if not turned.is_empty():
		AudioManager.play_turn()
	if not revealed.is_empty():
		board.play_reveals(revealed)
		AudioManager.play_reveal()
	if not unlocked.is_empty():
		board.play_unlocks(unlocked)
		AudioManager.play_unlock()
		Haptics.medium()
	if chain in COMBO_MILESTONES:
		AudioManager.play_combo(chain)
	Haptics.light()
	ui.show_chain(chain)
	ui.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	_refresh_buttons()

	if model.is_empty():
		_on_board_cleared()
	elif model.free_block_ids().is_empty():
		# Spinners can lock the board. Never punish: point at Undo/Restart.
		if undos_used < MAX_UNDOS:
			_show_message("No moves left - tap Undo", 3.0)
			ui.pulse_undo_button()
		else:
			_show_message("No moves left - tap Restart", 3.0)


func _blocked(id: int) -> void:
	var blocker := model.find_blocker(id)
	board.play_bump(id, blocker.id if blocker else -1)
	if _mistake():
		return
	if level.blocked_hint != "" and not _blocked_hint_shown:
		_blocked_hint_shown = true
		_show_message(level.blocked_hint, 2.6)


## Tapping a locked block is a mistake like a blocked tap, but it also shows
## which blocks hold the key (they hop).
func _locked_tap(id: int) -> void:
	board.play_locked_tap(id, model.key_blocks(id))
	if _mistake():
		return
	if not _locked_hint_shown:
		_locked_hint_shown = true
		_show_message("Locked until every %s block escapes" % model.blocks[id].lock_color, 2.8)


## Hidden arrows are never a guess: tapping one is free and just explains.
func _hidden_tap(id: int) -> void:
	board.play_hidden_tap(id)
	if not _hidden_hint_shown:
		_hidden_hint_shown = true
		_show_message("Hidden arrow - clear a neighbor to reveal it", 2.8)


## Shared mistake handling. Returns true if the attempt just ended.
func _mistake() -> bool:
	AudioManager.play_invalid()
	Haptics.medium()
	mistakes += 1
	chain = 0
	ui.show_chain(0)
	if max_hearts > 0:
		hearts -= 1
		ui.lose_heart()
		AudioManager.play_heart_lost()
		if hearts <= 0:
			_out_of_hearts()
			return true
	return false


## Short "Try Again" beat, then a fresh attempt. Never a fail screen.
func _out_of_hearts() -> void:
	game_over = true
	board.input_enabled = false
	_clear_hint()
	var session := _session_id
	await get_tree().create_timer(0.45).timeout
	if session != _session_id:
		return
	ui.show_try_again()
	AudioManager.play_try_again()
	await get_tree().create_timer(1.3).timeout
	if session != _session_id:
		return
	start_level(current_level)


func _on_board_cleared() -> void:
	completed = true
	board.input_enabled = false
	_refresh_buttons()
	var r := ScoreRules.settle({
		"escape_points": escape_points, "blocks": _total_blocks,
		"hearts_left": hearts, "max_hearts": max_hearts,
		"mistakes": mistakes, "undos": undos_used, "hints": hints_used,
	})
	r["stars"] = ScoreRules.stars(level, r)
	var rec := progress.record_result(current_level, r["score"], r["stars"])
	r.merge(rec, true)
	r["best"] = progress.best_score(current_level)
	r["is_last"] = current_level == level_manager.level_count
	r["level"] = current_level
	last_result = r
	var session := _session_id
	# Let the last block leave the screen, then celebrate, then show the card.
	await get_tree().create_timer(0.22).timeout
	if session != _session_id:
		return
	board.celebrate()
	if r["perfect"]:
		board.celebrate()
		ui.show_perfect_stamp()
		AudioManager.play_perfect()
		Haptics.medium()
		await get_tree().create_timer(0.85).timeout
	else:
		AudioManager.play_level_complete()
		Haptics.medium()
		await get_tree().create_timer(0.3).timeout
	if session != _session_id:
		return
	ui.show_complete(r)


# --- Undo ------------------------------------------------------------------

## Everything needed to rewind one successful move. Spinner directions,
## hidden flags and (derived) locks are part of the block snapshot.
func _capture_state() -> Dictionary:
	return {"blocks": model.snapshot(), "chain": chain, "escape_points": escape_points}


func undo() -> void:
	if completed or game_over or not history.can_undo():
		return
	if undos_used >= MAX_UNDOS:
		_show_message("No undos left - Restart to try again", 2.4)
		return
	undos_used += 1
	var state: Dictionary = history.pop()
	model.restore(state["blocks"])
	chain = state["chain"]
	escape_points = state["escape_points"]
	_clear_hint()
	board.sync_to(model.snapshot())
	board.refresh_locks(model)
	AudioManager.play_undo()
	ui.show_chain(0)
	ui.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	_refresh_buttons()


# --- Hints -----------------------------------------------------------------

## Debug mode (panel open or launched with --debug) gives unlimited hints.
func unlimited_hints() -> bool:
	return debug_panel.visible


## Highlights one recommended legal move. Never plays it. Uses one of the
## level's hints, except when the board is already lost (then it points at
## Undo for free).
func request_hint() -> void:
	if completed or game_over or model.is_empty():
		return
	if hint_block != -1:
		return  # already showing; don't charge twice
	var unlimited := unlimited_hints()
	if not unlimited and hints_used >= hints_allowed():
		if hints_allowed() == 0:
			_show_message("Hints unlock at level 20", 2.4)
		else:
			_show_message("No hints left for this level", 2.4)
		return
	var id := Solver.from_model(model).recommend_move()
	if id == -1:
		if model.free_block_ids().is_empty():
			_show_message("No moves left - tap Undo", 2.6)
		else:
			_show_message("This board can't be cleared from here - try Undo", 3.0)
		ui.pulse_undo_button()
		return
	if not unlimited:
		hints_used += 1
	hint_block = id
	board.set_hint(id)
	AudioManager.play_hint()
	_refresh_buttons()


func _clear_hint() -> void:
	if hint_block != -1:
		hint_block = -1
		board.clear_hint()


func _refresh_buttons() -> void:
	if level == null:
		return
	ui.set_undo_state(history.can_undo() and not completed, MAX_UNDOS - undos_used)
	ui.set_hint_state(hints_allowed() - hints_used, hints_allowed(), unlimited_hints())


# --- Level select --------------------------------------------------------------

func open_level_select() -> void:
	var levels := []
	for n in range(1, level_manager.level_count + 1):
		levels.append({
			"number": n, "stars": progress.stars_for(n),
			"unlocked": progress.is_unlocked(n) or debug_panel.visible,
			"completed": progress.best_scores.has(n),
			"mystery": level_manager.is_mystery(n),
			"current": n == current_level,
		})
	ui.open_level_select(levels, progress.total_stars())


# --- Settings ----------------------------------------------------------------

func _apply_settings() -> void:
	AudioManager.set_music_enabled(progress.music_on)
	AudioManager.set_sfx_enabled(progress.sfx_on)
	Haptics.enabled = progress.haptics_on
	ui.apply_settings(progress.music_on, progress.sfx_on, progress.haptics_on)


func _on_setting_toggled(key: String, on: bool) -> void:
	match key:
		"music": progress.music_on = on
		"sfx": progress.sfx_on = on
		"haptics": progress.haptics_on = on
	progress.save()
	_apply_settings()
	AudioManager.play_ui_tap()


# --- Tutorial / messages -----------------------------------------------------

func _show_start_hint() -> void:
	var rect := board.get_board_rect()
	var text_pos := Vector2(rect.get_center().x, rect.end.y + 56.0)
	if not level.hint_finger:
		tutorial.show_hint(level.hint, text_pos)
		return
	var target := Solver.from_model(model).recommend_move()
	if target == -1:
		return
	tutorial.show_hint(level.hint, text_pos, board.block_screen_position(target), true)


## One line of text under the board that fades out by itself.
func _show_message(text: String, seconds: float) -> void:
	var rect := board.get_board_rect()
	tutorial.show_hint(text, Vector2(rect.get_center().x, rect.end.y + 56.0))
	var session := _session_id
	get_tree().create_timer(seconds).timeout.connect(func():
		if session == _session_id and tutorial._text == text:
			tutorial.hide_hint())


# --- Debug helpers -------------------------------------------------------------

## Plays the solver's recommended move (always a correct one). Returns false
## if there is none.
func play_hint_move() -> bool:
	if completed or game_over:
		return false
	var id := Solver.from_model(model).recommend_move()
	if id == -1:
		return false
	_on_block_tapped(id)
	return true


## Plays the whole level with a short delay between taps.
func auto_solve() -> void:
	if _solving:
		return
	_solving = true
	var session := _session_id
	while session == _session_id and play_hint_move():
		await get_tree().create_timer(0.14).timeout
	_solving = false
