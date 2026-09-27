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

## Hint uses split: free per-level allowance vs Hint boosters from inventory.
var free_hints_used: int = 0
var booster_hints_used: int = 0
var hammers_used: int = 0
## Hammer aimed: the next block tap smashes (if safe) instead of moving.
var hammer_armed: bool = false
## Current Chapter theme (drives background, HUD colors, block material
## and music).
var theme: Dictionary = {}
var background: ChapterBackground

## Chapter of the loaded level, recalculated on every level load.
var current_chapter: int = 1
## Print "[Chapter] ..." lines on every Chapter application (debug builds).
var chapter_log: bool = OS.is_debug_build()
## Coins from Silver/Gold blocks collected during this attempt (level card).
var reward_coins_attempt: int = 0
var reward_notes: Array = []
## Chapter whose "Chapter Complete" moment waits for the next NEXT tap
## (0 = none). Set once, when the Chapter is completed for the first time.
var pending_chapter_card: int = 0

## Tests and --level=N skip the title screen.
static var skip_title := false

var _total_blocks: int = 0
var _blocked_hint_shown := false
var _locked_hint_shown := false
var _hidden_hint_shown := false
var _session_id: int = 0  # bumps on every level start; cancels stale timers
var _solving := false


func _ready() -> void:
	progress = PlayerProgress.new().load_from_disk()
	background = ChapterBackground.new()
	add_child(background)
	_apply_settings()
	board.block_tapped.connect(_on_block_tapped)
	ui.undo_pressed.connect(undo)
	ui.restart_pressed.connect(restart)
	ui.next_pressed.connect(next_level)
	ui.replay_pressed.connect(replay)
	ui.hint_pressed.connect(request_hint)
	ui.setting_toggled.connect(_on_setting_toggled)
	ui.levels_opened.connect(open_level_select)
	ui.level_chosen.connect(func(n):
		ui.hide_title()
		start_level(n))
	ui.hammer_pressed.connect(toggle_hammer)
	ui.buy_requested.connect(buy)
	ui.shop_open_requested.connect(open_shop)
	ui.chest_claim.connect(claim_chest)
	ui.chapter_continue.connect(_after_chapter_card)
	ui.continue_pressed.connect(continue_game)
	ui.title_level_select.connect(open_level_select)
	ui.title_tapped.connect(debug_panel.register_title_tap)
	debug_panel.level_count = level_manager.level_count
	debug_panel.level_requested.connect(func(n): start_level(wrapi(n, 1, level_manager.level_count + 1)))
	debug_panel.restart_requested.connect(restart)
	debug_panel.coords_toggled.connect(func(on): board.show_coords = on)
	debug_panel.hint_requested.connect(play_hint_move)
	debug_panel.solve_requested.connect(auto_solve)
	debug_panel.visibility_changed.connect(_refresh_buttons)
	get_viewport().size_changed.connect(_layout)
	var direct: bool = Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--level="))
	start_level(_initial_level())
	ui.set_coins(progress.coins, false)
	# Real-app launch: show the title with CONTINUE - LEVEL X. (Music waits
	# for the first tap on the web, see AudioManager.)
	if not skip_title and not direct:
		ui.show_title(progress.has_progress(), current_level, progress.total_stars(), progress.coins)
	AudioManager.start_music()


## Title "CONTINUE - LEVEL X" / "PLAY": the level is already loaded behind it.
func continue_game() -> void:
	ui.hide_title()
	AudioManager.play_ui_tap()
	ui.show_chapter_banner("MASTER LEVEL" if Chapters.is_master(current_level) else Chapters.title(current_chapter))


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
	free_hints_used = 0
	booster_hints_used = 0
	hammers_used = 0
	hammer_armed = false
	board.hammer_mode = false
	escape_points = 0
	completed = false
	game_over = false
	hint_block = -1
	_blocked_hint_shown = false
	_locked_hint_shown = false
	_hidden_hint_shown = false
	_total_blocks = model.block_count()
	reward_coins_attempt = 0
	reward_notes = []
	if pending_chapter_card != 0 and Chapters.chapter_of(number) != pending_chapter_card:
		pending_chapter_card = 0  # the player moved on to another Chapter
	max_hearts = level.hearts if level.hearts >= 0 else (MAX_HEARTS if number >= HEARTS_FROM_LEVEL else 0)
	hearts = max_hearts

	_apply_chapter_theme(number)
	board.mystery = level.mystery
	board.spent_rewards = progress.collected_rewards(number)
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
	else:
		_maybe_explain_rewards()
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
	if pending_chapter_card != 0:
		_show_chapter_card(pending_chapter_card)
		return
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
	if hammer_armed:
		_smash(id)
		return
	match model.move_state(id):
		"ok": _escape(id)
		"blocked": _blocked(id)
		"locked": _locked_tap(id)
		"hidden": _hidden_tap(id)


func _escape(id: int) -> void:
	history.push(_capture_state())
	var at := board.get_view(id).home
	var escaped: BlockData = model.blocks[id]
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
	if escaped.is_reward():
		_collect_reward(escaped, at)
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
		"mistakes": mistakes, "undos": undos_used, "hints": hints_used, "hammers": hammers_used,
	})
	r["stars"] = ScoreRules.stars(level, r)
	var rec := progress.record_result(current_level, r["score"], r["stars"], r["perfect"])
	r.merge(rec, true)
	# Coins: only improvements pay (see Economy.level_reward).
	var chapter := Chapters.chapter_of(current_level)
	var reward := Economy.level_reward(current_level, rec["first_clear"], rec["previous_stars"], r["stars"], rec["first_perfect"])
	var coins: int = reward["coins"]
	var notes: Array = reward["lines"]
	progress.add_coins(coins, chapter)
	r["master"] = Chapters.is_master(current_level)
	if r["master"] and not progress.achievements.has("master"):
		progress.achievements.append("master")
		var mc := int(Economy.config()["rewards"]["master_clear"])
		progress.add_coins(mc, chapter)
		coins += mc
		notes.append("MASTER")
	# Chapter milestone: fires (and pays) once per save.
	var chapter_bonus := Economy.check_chapter_complete(progress, chapter, level_manager.level_count)
	if chapter_bonus > 0:
		coins += chapter_bonus
		notes.append("Chapter %d complete!" % chapter)
		pending_chapter_card = chapter
	progress.save()
	# Silver/Gold coins were paid the moment each block escaped; the card
	# shows them too so the attempt's total is honest.
	coins += reward_coins_attempt
	notes.append_array(reward_notes)
	r["chapter_complete"] = chapter if chapter_bonus > 0 else 0
	r["reward_coins"] = reward_coins_attempt
	r["coins"] = coins
	r["coin_notes"] = " · ".join(notes)
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
	if r["master"]:
		# Level 100: the biggest celebration in the game.
		for i in 3:
			board.celebrate()
		ui.show_perfect_stamp("MASTER!", 1.2)
		AudioManager.play_master()
		Haptics.medium()
		await get_tree().create_timer(1.6).timeout
	elif r["perfect"]:
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
	if coins > reward_coins_attempt:
		AudioManager.play_coin()
	_refresh_buttons()


# --- Undo ------------------------------------------------------------------

## Everything needed to rewind one successful move. Spinner directions,
## hidden flags and (derived) locks are part of the block snapshot.
func _capture_state() -> Dictionary:
	return {"blocks": model.snapshot(), "chain": chain, "escape_points": escape_points}


func undo() -> void:
	if completed or game_over or not history.can_undo():
		return
	if hammer_armed:
		toggle_hammer()
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
	var free_left := hints_allowed() - free_hints_used
	var owned: int = progress.inventory.get("hint", 0)
	if not unlimited and free_left <= 0 and owned <= 0:
		# Explain gently; the coin pill pulses to point at the Shop.
		_show_message("No hints left - get Hint boosters in the Shop", 2.6)
		ui.pulse_coins()
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
		if free_left > 0:
			free_hints_used += 1
		else:
			booster_hints_used += 1
			progress.inventory["hint"] = owned - 1
			progress.save()
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
	ui.set_hint_state(hints_allowed() - free_hints_used, hints_allowed(), unlimited_hints(), progress.inventory.get("hint", 0))
	ui.set_hammer_state(progress.inventory.get("hammer", 0), hammer_armed, not completed and hammers_used < _hammer_limit())
	ui.set_coins(progress.coins)


# --- Boosters: Hammer ------------------------------------------------------------

func _hammer_limit() -> int:
	return int(Economy.config()["hammer_per_level"])


## Arms / disarms the Hammer. With none owned, opens the Shop.
func toggle_hammer() -> void:
	if completed or game_over:
		return
	if hammer_armed:
		hammer_armed = false
		board.hammer_mode = false
		tutorial.hide_hint()
		_refresh_buttons()
		return
	if progress.inventory.get("hammer", 0) <= 0:
		_show_message("No Hammers yet - buy one in the Shop", 2.4)
		open_shop()
		return
	if hammers_used >= _hammer_limit():
		_show_message("One Hammer per level", 2.2)
		return
	hammer_armed = true
	board.hammer_mode = true
	_show_message("Tap a block to smash it", 3.0)
	_refresh_buttons()


## Smashes block `id` if (and only if) the level stays solvable. A rejected
## smash does not use up the Hammer.
func _smash(id: int) -> void:
	hammer_armed = false
	board.hammer_mode = false
	if not is_hammer_safe(id):
		AudioManager.play_invalid()
		board.play_hidden_tap(id)
		_show_message("That would make the level unsolvable - Hammer kept", 2.8)
		_refresh_buttons()
		return
	progress.inventory["hammer"] = progress.inventory.get("hammer", 0) - 1
	progress.save()
	hammers_used += 1
	history.push(_capture_state())
	# Reward rule: a Hammer never collects a Silver/Gold reward (the block is
	# not marked collected either, so it can still be earned by play later).
	var smashed_reward: bool = model.blocks[id].is_reward() and not progress.has_reward_block(current_level, id)
	var turned := model.remove(id)
	var revealed := model.last_revealed.duplicate()
	var unlocked := model.last_unlocked.duplicate()
	_clear_hint()
	board.play_smash(id)
	board.animate_turns(turned)
	AudioManager.play_hammer()
	Haptics.medium()
	if smashed_reward:
		_show_message("Smashed - Silver/Gold coins only pay when a block escapes", 2.8)
	if not revealed.is_empty():
		board.play_reveals(revealed)
	if not unlocked.is_empty():
		board.play_unlocks(unlocked)
		AudioManager.play_unlock()
	ui.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	_refresh_buttons()
	if model.is_empty():
		_on_board_cleared()


## True if removing `id` leaves a solvable (or empty) board.
func is_hammer_safe(id: int) -> bool:
	if not model.blocks.has(id):
		return false
	var test := BoardModel.new()
	test.setup(model.rows, model.columns, model.snapshot())
	test.remove(id)
	if test.is_empty():
		return true
	var s := Solver.from_model(test)
	return s.is_solvable() and not s.aborted


# --- Economy: Shop & chests -----------------------------------------------------

func open_shop() -> void:
	ui.open_shop(progress.coins, progress.inventory)


func buy(item: String) -> void:
	if Economy.buy(progress, item):
		AudioManager.play_coin()
	else:
		AudioManager.play_invalid()
	ui.refresh_shop(progress.coins, progress.inventory)
	_refresh_buttons()


func claim_chest(chapter: int, tier: int) -> void:
	var coins := Economy.claim_chest(progress, chapter, tier)
	if coins > 0:
		AudioManager.play_chest()
		ui.set_coins(progress.coins)
		_refresh_buttons()
		# Refresh whatever shows the chest (now claimed).
		if ui.is_chapter_card_open():
			ui.refresh_chapter_card(chapter_summary(ui.chapter_card_chapter()))
		if ui.is_level_select_open():
			open_level_select()


# --- Chapters ----------------------------------------------------------------------

## Applies the Chapter (or Master) theme for `number`: background, ambient
## decoration and particles, board, block material, HUD accent colors and
## music.
##
## Called from start_level(), which every entry point goes through (NEXT
## LEVEL, Level Select, Continue, Replay, Restart, debug jumps, relaunch).
## The Chapter is RECALCULATED from the level number every time and every
## Chapter-specific surface is re-applied unconditionally - nothing depends
## on what the previous level showed. Only the banner/sound depend on
## whether the Chapter actually changed.
func _apply_chapter_theme(number: int) -> void:
	var t := Chapters.theme_for_level(number)
	var previous_id: int = theme.get("id", 0)
	var first: bool = theme.is_empty()
	theme = t
	current_chapter = Chapters.chapter_of(number)
	background.apply_theme(t, not first and previous_id != t["id"])
	board.set_theme(t)
	ui.apply_theme(t)
	AudioManager.set_music_theme(t["music"])
	_log_chapter(number, previous_id)
	if previous_id != t["id"] and not first:
		AudioManager.play_chapter()
		ui.show_chapter_banner("MASTER LEVEL" if Chapters.is_master(number) else Chapters.title(current_chapter))


## Debug log of every Chapter application (debug builds / editor only).
func _log_chapter(number: int, previous_id: int) -> void:
	if not chapter_log:
		return
	print("[Chapter] level=%d chapter=%d theme=%s (id %d, prev %d) music=%s%s" % [
		number, current_chapter, theme["name"], theme["id"], previous_id, AudioManager.music_theme,
		"  <- transition" if previous_id != theme["id"] else ""])


## What is actually applied right now (for tests and debugging).
func chapter_state() -> Dictionary:
	return {"level": current_level, "chapter": current_chapter, "theme_id": theme.get("id", 0),
		"background_theme_id": background.theme["id"], "background_settled": background.is_settled(),
		"board_color": board.board_color, "accent": board.accent_color, "ui_theme_id": ui.theme["id"],
		"block_style_id": board.block_style_id, "block_style": Palette.block_style,
		"music": AudioManager.music_theme}


# --- Reward blocks ----------------------------------------------------------------

## A Silver/Gold block escaped by normal play: pay once (Economy decides and
## saves), then celebrate briefly without interrupting play.
func _collect_reward(b: BlockData, at: Vector2) -> void:
	var coins := Economy.collect_reward_block(progress, current_level, b)
	if coins <= 0:
		return  # already collected on an earlier run / attempt
	board.spent_rewards[b.id] = true
	reward_coins_attempt += coins
	reward_notes.append("%s +%d" % [b.rarity_name().capitalize(), coins])
	board.play_reward(at, b.rarity)
	AudioManager.play_reward(b.rarity)
	Haptics.light()
	ui.fly_coins(board.get_global_transform_with_canvas() * at, coins, b.rarity, progress.coins)


## First level with an uncollected Silver (or Gold) block: one short line
## explaining it. Shown once per save.
func _maybe_explain_rewards() -> void:
	var collected := progress.collected_rewards(current_level)
	for rarity in [BlockData.Rarity.GOLD, BlockData.Rarity.SILVER]:
		var tip: String = BlockData.RARITY_NAMES[rarity]
		if progress.tips_seen.has(tip):
			continue
		if level.blocks.any(func(b): return b.rarity == rarity and not collected.has(b.id)):
			progress.tips_seen.append(tip)
			progress.save()
			_show_message("%s Block: let it escape for +%d coins" % [tip.capitalize(), Economy.reward_block_coins(rarity)], 3.4)
			return


# --- Chapter complete ---------------------------------------------------------------

## Everything the Chapter Complete card and Level Select show for a Chapter.
func chapter_summary(chapter: int) -> Dictionary:
	var rg := Chapters.chapter_range(chapter)
	var last := mini(rg.y, level_manager.level_count)
	var perfect := 0
	var score := 0
	var rewards_total := 0
	var rewards_got := 0
	for n in range(rg.x, last + 1):
		if progress.perfect_levels.has(n):
			perfect += 1
		score += progress.best_score(n)
		var info := level_manager.level_info(n)
		rewards_total += info["rewards"].size()
		for id in info["rewards"]:
			if progress.has_reward_block(n, id):
				rewards_got += 1
	var next := chapter + 1
	var has_next := Chapters.chapter_range(next).x <= level_manager.level_count
	return {"chapter": chapter, "title": Chapters.title(chapter), "theme": Chapters.theme_for_chapter(chapter),
		"stars": Economy.chapter_stars(progress, chapter), "max_stars": (last - rg.x + 1) * 3,
		"coins": int(progress.chapter_coins.get(chapter, 0)), "perfect": perfect, "levels": last - rg.x + 1,
		"score": score, "rewards_total": rewards_total, "rewards_got": rewards_got,
		"tiers": Economy.chest_tiers(progress, chapter),
		"next_title": Chapters.title(next) if has_next else "", "next_theme": Chapters.theme_for_chapter(next),
		"next_new": _chapter_news(next) if has_next else "", "completed": progress.completed_chapters.has(chapter)}


## What is new in a Chapter (for the preview line).
func _chapter_news(chapter: int) -> String:
	var rg := Chapters.chapter_range(chapter)
	var news := []
	var blocks: Dictionary = Economy.config().get("reward_blocks", {})
	for name in blocks:
		var from := int(blocks[name].get("from_level", 0))
		if bool(blocks[name].get("enabled", false)) and from >= rg.x and from <= rg.y:
			news.append("%s Blocks" % String(name).capitalize())
	if Chapters.master_level() >= rg.x and Chapters.master_level() <= rg.y:
		news.append("the Master Level")
	return "NEW: " + " & ".join(news) if not news.is_empty() else ""


func _show_chapter_card(chapter: int) -> void:
	pending_chapter_card = 0
	AudioManager.play_chapter_complete()
	Haptics.medium()
	ui.show_chapter_card(chapter_summary(chapter))


## CONTINUE on the Chapter card: straight into the next Chapter.
func _after_chapter_card() -> void:
	start_level(current_level % level_manager.level_count + 1)


# --- Level select --------------------------------------------------------------

func open_level_select() -> void:
	var chapters := []
	for c in range(1, Chapters.chapter_count(level_manager.level_count) + 1):
		var info := chapter_summary(c)
		var rg := Chapters.chapter_range(c)
		var levels := []
		for n in range(rg.x, mini(rg.y, level_manager.level_count) + 1):
			var li := level_manager.level_info(n)
			var best_rarity := 0
			for id in li["rewards"]:
				if not progress.has_reward_block(n, id):
					best_rarity = maxi(best_rarity, li["rewards"][id])
			levels.append({
				"number": n, "stars": progress.stars_for(n),
				"unlocked": progress.is_unlocked(n) or debug_panel.visible,
				"completed": progress.best_scores.has(n),
				"mystery": li["mystery"], "reward": best_rarity,
				"master": Chapters.is_master(n),
				"current": n == current_level,
			})
		info["levels"] = levels
		info["unlocked"] = levels.any(func(l): return l["unlocked"])
		chapters.append(info)
	ui.open_level_select(chapters, progress.total_stars(), level_manager.level_count * 3, current_chapter)


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

func _message_position() -> Vector2:
	var rect := board.get_board_rect()
	return Vector2(rect.get_center().x, minf(rect.end.y + 56.0, ui.get_board_area().end.y + 12.0))


func _show_start_hint() -> void:
	var text_pos := _message_position()
	if not level.hint_finger:
		tutorial.show_hint(level.hint, text_pos)
		return
	var target := Solver.from_model(model).recommend_move()
	if target == -1:
		return
	tutorial.show_hint(level.hint, text_pos, board.block_screen_position(target), true)


## One line of text under the board that fades out by itself. Kept above
## the bottom buttons even when a big board fills the play area.
func _show_message(text: String, seconds: float) -> void:
	tutorial.show_hint(text, _message_position())
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
