class_name GameManager
extends Node
## Orchestrates a play session: loads levels, applies the rules through
## BoardModel, records History for undo, tracks chains and tells the Board /
## UI / Audio what to show.
##
## All systems talk to each other through this node via signals, so each of
## them stays small and replaceable.

## Chain values that trigger the extra "combo" sound.
const COMBO_MILESTONES := [3, 5, 8, 12, 16, 20]

@onready var level_manager: LevelManager = $LevelManager
@onready var board: Board = $Board
@onready var tutorial: TutorialHint = $TutorialHint
@onready var ui: UIManager = $UI
@onready var debug_panel: DebugPanel = $DebugPanel

var model := BoardModel.new()
var history := History.new()
var level: LevelData
var current_level: int = 1

var chain: int = 0
var best_chain: int = 0
var mistakes: int = 0
var completed: bool = false

var _total_blocks: int = 0
var _blocked_hint_shown := false
var _session_id: int = 0  # bumps on every level start; cancels stale timers
var _solving := false


func _ready() -> void:
	board.block_tapped.connect(_on_block_tapped)
	ui.undo_pressed.connect(undo)
	ui.restart_pressed.connect(restart)
	ui.next_pressed.connect(next_level)
	ui.title_tapped.connect(debug_panel.register_title_tap)
	debug_panel.level_count = level_manager.level_count
	debug_panel.level_requested.connect(func(n): start_level(wrapi(n, 1, level_manager.level_count + 1)))
	debug_panel.restart_requested.connect(restart)
	debug_panel.coords_toggled.connect(func(on): board.show_coords = on)
	debug_panel.hint_requested.connect(play_hint_move)
	debug_panel.solve_requested.connect(auto_solve)
	get_viewport().size_changed.connect(_layout)
	start_level(_initial_level())


func _initial_level() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			return clampi(int(arg.get_slice("=", 1)), 1, level_manager.level_count)
	return level_manager.load_saved_level()


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
	completed = false
	_blocked_hint_shown = false
	_total_blocks = model.block_count()

	board.build(level.rows, level.columns, level.blocks, true)
	board.input_enabled = true
	ui.set_level(number, level_manager.level_count, level.name)
	ui.set_progress(0.0, false)
	ui.set_undo_enabled(false)
	tutorial.hide_hint(true)
	_layout()
	if level.hint != "":
		_show_start_hint()
	level_manager.save_current_level(number)
	debug_panel.set_current_level(number)


func restart() -> void:
	AudioManager.play_ui_tap()
	start_level(current_level)


func next_level() -> void:
	AudioManager.play_ui_tap()
	start_level(current_level % level_manager.level_count + 1)


func _layout() -> void:
	board.layout(ui.get_board_area())
	if tutorial.is_showing() and level and level.hint != "" and not completed:
		_show_start_hint()


# --- Moves -----------------------------------------------------------------

func _on_block_tapped(id: int) -> void:
	if completed or not model.blocks.has(id):
		return
	if tutorial.is_showing():
		tutorial.hide_hint()

	if model.can_escape(id):
		_escape(id)
	else:
		_blocked(id)


func _escape(id: int) -> void:
	history.push(_capture_state())
	model.remove(id)
	chain += 1
	best_chain = maxi(best_chain, chain)

	board.play_escape(id, chain)
	AudioManager.play_escape(chain)
	if chain in COMBO_MILESTONES:
		AudioManager.play_combo(chain)
	Haptics.light()
	ui.show_chain(chain)
	ui.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	ui.set_undo_enabled(true)

	if model.is_empty():
		_on_board_cleared()


func _blocked(id: int) -> void:
	var blocker := model.find_blocker(id)
	board.play_bump(id, blocker.id if blocker else -1)
	AudioManager.play_invalid()
	Haptics.medium()
	mistakes += 1
	chain = 0
	ui.show_chain(0)
	if level.blocked_hint != "" and not _blocked_hint_shown:
		_blocked_hint_shown = true
		var rect := board.get_board_rect()
		tutorial.show_hint(level.blocked_hint, Vector2(rect.get_center().x, rect.end.y + 56.0))
		var session := _session_id
		get_tree().create_timer(2.6).timeout.connect(func():
			if session == _session_id:
				tutorial.hide_hint())


func _on_board_cleared() -> void:
	completed = true
	board.input_enabled = false
	ui.set_undo_enabled(false)
	var session := _session_id
	# Let the last block leave the screen, then celebrate, then show the card.
	await get_tree().create_timer(0.22).timeout
	if session != _session_id:
		return
	board.celebrate()
	AudioManager.play_level_complete()
	Haptics.medium()
	await get_tree().create_timer(0.3).timeout
	if session != _session_id:
		return
	ui.show_complete(best_chain, mistakes == 0, current_level == level_manager.level_count)


# --- Undo ------------------------------------------------------------------

## Everything needed to rewind one successful move.
func _capture_state() -> Dictionary:
	return {"blocks": model.snapshot(), "chain": chain}


func undo() -> void:
	if completed or not history.can_undo():
		return
	var state: Dictionary = history.pop()
	model.restore(state["blocks"])
	chain = state["chain"]
	board.sync_to(model.snapshot())
	AudioManager.play_undo()
	ui.show_chain(0)
	ui.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	ui.set_undo_enabled(history.can_undo())


# --- Tutorial --------------------------------------------------------------

func _show_start_hint() -> void:
	var free := model.free_block_ids()
	if free.is_empty():
		return
	free.sort()
	var view := board.get_view(free[0])
	var rect := board.get_board_rect()
	tutorial.show_hint(level.hint, Vector2(rect.get_center().x, rect.end.y + 56.0), board.to_global(view.home), true)


# --- Debug helpers -------------------------------------------------------------

## Taps one currently free block (lowest id). Returns false if none.
func play_hint_move() -> bool:
	if completed:
		return false
	var free := model.free_block_ids()
	if free.is_empty():
		return false
	free.sort()
	_on_block_tapped(free[0])
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
