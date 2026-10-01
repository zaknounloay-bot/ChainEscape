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
## Diagnostics snapshot of the last level transition (tests / debug panel).
var last_diag: Dictionary = {}
## Levels the Level Select grid last showed unlocked / locked.
var select_shown: Dictionary = {}

## Tests and --level=N skip the title screen.
static var skip_title := false

var _total_blocks: int = 0
var _blocked_hint_shown := false
## v0.6.2 first-time guided lesson on the level that introduces a Second Era
## mechanic ("switch" / "gate" / "armor"; "" = none). Finished once per
## save: stored as "lesson_<kind>" in progress.tips_seen.
const LESSONS := {101: "switch", 121: "gate", 161: "armor"}
var _lesson := ""
var _locked_hint_shown := false
var _hidden_hint_shown := false
var _session_id: int = 0  # bumps on every level start; cancels stale timers
var _solving := false


func _ready() -> void:
	progress = PlayerProgress.new().load_from_disk()
	_take_web_transfer()
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
		_hide_title()
		start_level(n, "select"))
	ui.hammer_pressed.connect(toggle_hammer)
	ui.buy_requested.connect(buy)
	ui.shop_open_requested.connect(open_shop)
	ui.chest_claim.connect(claim_chest)
	ui.chapter_continue.connect(_after_chapter_card)
	ui.continue_pressed.connect(continue_game)
	ui.title_level_select.connect(open_level_select)
	ui.title_tapped.connect(debug_panel.register_title_tap)
	ui.backup_requested.connect(show_backup_code)
	ui.restore_requested.connect(request_restore)
	ui.recovery_new_game.connect(_recovery_start_new)
	ui.main_menu_requested.connect(return_to_main_menu)
	debug_panel.level_count = level_manager.level_count
	debug_panel.level_requested.connect(func(n): start_level(wrapi(n, 1, level_manager.level_count + 1), "debug"))
	debug_panel.restart_requested.connect(restart)
	debug_panel.coords_toggled.connect(func(on): board.show_coords = on)
	debug_panel.hint_requested.connect(play_hint_move)
	debug_panel.solve_requested.connect(auto_solve)
	debug_panel.visibility_changed.connect(_refresh_buttons)
	debug_panel.info_source = debug_info
	get_viewport().size_changed.connect(_layout)
	var direct: bool = Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--level="))
	Diagnostics.start_session()
	start_level(_initial_level(), "launch")
	ui.set_coins(progress.coins, false)
	# Real-app launch: show the title with CONTINUE - LEVEL X. (Music waits
	# for the first tap on the web, see AudioManager.)
	if not skip_title and not direct:
		_show_title()
		_update_storage_notice()
		_open_shared_challenge()
	publish_state.call_deferred()
	AudioManager.start_music()


## Title with CONTINUE, the save diagnostic line and, when a save existed
## but can't be read or found, the recovery choice instead of a silent
## fresh start.
func _show_title() -> void:
	ui.show_title(progress.has_progress(), current_level, progress.total_stars(), progress.coins, progress.total_score())
	ui.set_save_diagnostic(save_diagnostic())
	if progress.hold_writes:
		var what := ("Your saved progress could not be read." if progress.hold_reason == "unreadable"
			else "Your saved progress is missing from this browser.")
		var had := ""
		if not progress.beacon.is_empty():
			had = "\nLast save: level %d completed, TOTAL SCORE %s." % [int(progress.beacon.get("highest_completed", 0)),
				UIManager._fmt(int(progress.beacon.get("total_score", 0)))]
		ui.show_recovery("%s%s\nNothing has been overwritten. Restore it from a backup code, or start a new game." % [what, had])
	else:
		ui.hide_recovery()


## One line for testing on real devices: where the save came from and what
## it holds (title screen, debug panel, console).
func save_diagnostic() -> String:
	var st := PlayerProgress.storage_status()
	return "SAVE %s · v%d · #%d · UNLOCKED %d · LAST PLAYED %d · TOTAL %s · SAVED %s · %s%s" % [
		progress.load_source.to_upper(), progress.version, progress.seq, mini(progress.highest_unlocked, maxi(level_manager.level_count, 1)), progress.current_level,
		UIManager._fmt(progress.total_score()), progress.saved_text(), String(st.get("context", "device")).to_upper(),
		" · WRITES HELD" if progress.hold_writes else ""]


# --- Backup code / transfer / recovery (v0.5.2) ---------------------------------

var _awaiting_import := false
var _import_poll := 0.0


## Web: progress handed over from an itch.io embed (OPEN GAME IN SAFARI)
## is merged into this tab's save - keeping the best of both.
func _take_web_transfer() -> void:
	if not OS.has_feature("web") or not WebBridge.available():
		return
	var text := str(WebBridge.call_api("takeTransfer"))
	if text == "" or text == "<null>":
		return
	var other := PlayerProgress.from_text(text)
	if other == null:
		print("[Save] transfer ignored: not a Chain Escape save")
		return
	var r := progress.merge_from(other)
	progress.release_hold()
	progress.save()
	print("[Save] transfer from embed: +%d levels, total %d -> %d" % [r["levels_added"], r["total_before"], r["total_after"]])


func show_backup_code() -> void:
	var code := progress.backup_code()
	print("[Save] backup code made (%d chars, seq %d)" % [code.length(), progress.seq])
	if OS.has_feature("web") and WebBridge.available():
		WebBridge.call_api("backupDialog", ["show", code])
	else:
		DisplayServer.clipboard_set(code)
		_show_message("Backup code copied to the clipboard", 2.6)


func request_restore() -> void:
	if OS.has_feature("web") and WebBridge.available():
		WebBridge.call_api("backupDialog", ["restore"])
		_awaiting_import = true
		_import_poll = 0.0
	else:
		apply_restore(DisplayServer.clipboard_get())


var _published_panels := ""


func _process(delta: float) -> void:
	if OS.has_feature("web"):
		# Re-publish the state snapshot when a panel opens or closes (its
		# button positions are only laid out while it is visible).
		var panels := "%s%s" % [ui.is_settings_open(), ui.is_recovery_open()]
		if panels != _published_panels:
			_published_panels = panels
			get_tree().create_timer(0.2).timeout.connect(publish_state)
	if not _awaiting_import:
		return
	_import_poll += delta
	if _import_poll < 0.25:
		return
	_import_poll = 0.0
	var text := str(WebBridge.call_api("takeImport"))
	if text != "" and text != "<null>":
		_awaiting_import = false
		apply_restore(text)
	elif not bool(WebBridge.call_api("dialogOpen")):
		_awaiting_import = false


## Restores a backup code (or pasted save text). Merges: never loses what
## this device already has, never pays a reward twice. Returns true if the
## code was valid.
func apply_restore(code: String) -> bool:
	var other := PlayerProgress.from_text(PlayerProgress.decode_backup(code))
	if other == null:
		_show_message("That is not a valid backup code", 2.8)
		print("[Save] restore rejected: invalid code")
		return false
	var r := progress.merge_from(other)
	progress.release_hold()
	progress.save()
	ui.set_coins(progress.coins, false)
	var target := clampi(progress.current_level, 1, maxi(level_manager.level_count, 1))
	if ui.is_title_open() or current_level != target:
		start_level(target, "restore")
		_show_title()
	print("[Save] restored: +%d levels, total %d -> %d" % [r["levels_added"], r["total_before"], r["total_after"]])
	_show_message("Progress restored - TOTAL SCORE %s" % UIManager._fmt(progress.total_score()), 3.0)
	publish_state.call_deferred()
	return true


## Recovery screen: the player confirmed START NEW GAME.
func _recovery_start_new() -> void:
	progress.release_hold()
	progress.save()
	_show_title()
	publish_state.call_deferred()


## Settings > MAIN MENU (Social MVP 0.1): the title over the current level,
## exactly as at launch. The board stays as it is behind the title, so
## CONTINUE resumes it; nothing is reset, saved or rewarded here.
func return_to_main_menu() -> void:
	AudioManager.play_ui_tap()
	_show_title()
	publish_state.call_deferred()


## Social 0.2C: opened from a shared challenge link (?challenge=<id>):
## its screens open over the title before anything else shows. Classic is
## loaded exactly as on any launch and is never touched by them.
func _open_shared_challenge() -> void:
	# Developer page (?friendbench=1): generation timing on this device.
	if FriendBench.requested():
		add_child(FriendBench.new())
		return
	var p := SocialWeb.launch_param()
	if not p.is_empty():
		ui.open_shared_challenge(str(p["raw"]))


## Title "CONTINUE - LEVEL X" / "PLAY": the level is already loaded behind it.
func continue_game() -> void:
	_hide_title()
	AudioManager.play_ui_tap()
	ui.show_chapter_banner(level_banner(current_level))


func _initial_level() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			return clampi(int(arg.get_slice("=", 1)), 1, level_manager.level_count)
	return clampi(progress.current_level, 1, maxi(level_manager.level_count, 1))


# --- Level flow ------------------------------------------------------------

## `via` says how the level was entered (diagnostics only).
func start_level(number: int, via: String = "load") -> void:
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
	ui.set_total_score(progress.total_score())
	ui.set_progress(0.0, false)
	ui.set_hearts(max_hearts, hearts)
	_refresh_buttons()
	tutorial.hide_hint(true)
	_lesson = ""
	board.set_marks([])
	_layout()
	var lesson: String = LESSONS.get(number, "")
	if lesson != "" and not progress.tips_seen.has("lesson_" + lesson) and _lesson_blocks(lesson).size() > 0:
		_lesson = lesson
		_lesson_step()
	elif level.hint != "":
		_show_start_hint()
	if level.hint != "":
		# A lesson level explains its own mechanic: no extra tip later.
		for pair in [["switch", level.blocks.any(func(x): return x.is_switch())],
				["gate", level.blocks.any(func(x): return x.is_gate())], ["armor", level.blocks.any(func(x): return x.armored)]]:
			if pair[1] and not progress.tips_seen.has(pair[0]):
				progress.tips_seen.append(pair[0])
	else:
		_maybe_explain_rewards()
	progress.current_level = number
	progress.save()
	debug_panel.set_current_level(number)
	last_diag = Diagnostics.level_transition(number, current_chapter, via, get_tree(), {
		"fx": board.fx_count(), "music": AudioManager.music_theme, "music_players": AudioManager.music_playing_count(),
		"sfx": AudioManager.sfx_playing_count(), "save_seq": progress.seq})
	publish_state()


func restart() -> void:
	AudioManager.play_ui_tap()
	start_level(current_level, "restart")


func replay() -> void:
	AudioManager.play_ui_tap()
	start_level(current_level, "replay")


func next_level() -> void:
	AudioManager.play_ui_tap()
	if pending_chapter_card != 0:
		_show_chapter_card(pending_chapter_card)
		return
	start_level(current_level % level_manager.level_count + 1, "next")


func _layout() -> void:
	board.layout(ui.get_board_area())
	if _lesson != "" and level and not completed:
		_lesson_step()
	elif tutorial.is_showing() and level and level.hint != "" and not completed:
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
	var tap_state := model.move_state(id)
	match tap_state:
		"ok": _escape(id)
		"blocked": _blocked(id)
		"locked": _locked_tap(id)
		"hidden": _hidden_tap(id)
		"ram": _ram(id)
		"gate": _gate_tap(id)
		"armored": _armored_tap(id)
	# Free "explain" taps (gate, shell, hidden, locked) keep their message;
	# the lesson moves on after real moves.
	if _lesson != "" and not completed and not game_over and tap_state in ["ok", "ram", "blocked"]:
		_lesson_step()


func _escape(id: int) -> void:
	history.push(_capture_state())
	var at := board.get_view(id).home
	var escaped: BlockData = model.blocks[id]
	var turned := model.remove(id)
	var revealed := model.last_revealed.duplicate()
	var unlocked := model.last_unlocked.duplicate()
	if (_lesson == "switch" and not model.last_flipped.is_empty()) or (_lesson == "gate" and not model.last_opened_gates.is_empty()):
		_finish_lesson()
	_play_second_era_effects()
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
	elif model.playable_ids().is_empty():
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


## v0.6: the effects of a switch firing and gates opening (after any
## removal: escape or Hammer), plus every gate counter.
func _play_second_era_effects() -> void:
	var flipped := model.last_flipped.duplicate()
	var opened := model.last_opened_gates.duplicate()
	if not flipped.is_empty():
		board.play_flips(flipped, model)
		AudioManager.play_switch()
	if not opened.is_empty():
		board.play_gate_opens(opened)
		AudioManager.play_gate()
		Haptics.medium()
	board.refresh_locks(model)


## v0.6 ARMORED: launching a block into a shell cracks it. A productive
## move, never a mistake: no heart, the chain is kept (but earns nothing).
func _ram(id: int) -> void:
	history.push(_capture_state())
	var target := model.ram(id)
	_clear_hint()
	if _lesson == "armor":
		_finish_lesson()
	board.play_ram(id, target)
	AudioManager.play_crack()
	Haptics.medium()
	_refresh_buttons()
	if model.playable_ids().is_empty():
		_show_message("No moves left - tap Undo", 3.0)
		ui.pulse_undo_button()


## Chain Gates never move: tapping one is free and explains what opens it.
func _gate_tap(id: int) -> void:
	board.play_hidden_tap(id)
	var g: BlockData = model.blocks[id]
	var left := model.gate_remaining(g.gate_group)
	_show_message("Chain Gate %s: clear the %d block%s with its %s chain mark" % [g.gate_group, left, "" if left == 1 else "s", g.gate_group], 2.8)


## A shelled block can't leave yet: free tap, explains the ram.
func _armored_tap(id: int) -> void:
	board.play_hidden_tap(id)
	_show_message("Armored - launch another block into it to crack the shell", 2.8)


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
	start_level(current_level, "retry")


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
	# Each Master Level pays its bonus once per save ("master" = Level 100,
	# kept from v0.5; "master_200" = the Grand Master).
	var master_key := "master" if current_level == Chapters.master_level() else "master_%d" % current_level
	if r["master"] and not progress.achievements.has(master_key):
		progress.achievements.append(master_key)
		var mc := int(Economy.config()["rewards"].get("master_clear_%d" % current_level, Economy.config()["rewards"]["master_clear"]))
		progress.add_coins(mc, chapter)
		coins += mc
		notes.append("GRAND MASTER" if current_level > Chapters.master_level() else "MASTER")
	# v0.6 milestone levels (125 / 150 / 175): a one-time bonus.
	r["milestone"] = Chapters.is_milestone(current_level)
	var ms_key := "milestone_%d" % current_level
	if r["milestone"] and not progress.achievements.has(ms_key):
		progress.achievements.append(ms_key)
		var bonus := int(Economy.config()["rewards"].get("milestone_clear", 0))
		progress.add_coins(bonus, chapter)
		coins += bonus
		notes.append("MILESTONE")
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
		# Master Levels: the biggest celebration in the game (Level 200 the
		# biggest of all).
		var grand := current_level > Chapters.master_level()
		for i in (5 if grand else 3):
			board.celebrate()
		ui.show_perfect_stamp("GRAND MASTER!" if grand else "MASTER!", 1.6 if grand else 1.2)
		AudioManager.play_master()
		Haptics.medium()
		await get_tree().create_timer(2.0 if grand else 1.6).timeout
	elif r["milestone"]:
		for i in 2:
			board.celebrate()
		ui.show_perfect_stamp("MILESTONE!", 0.9)
		AudioManager.play_milestone()
		Haptics.medium()
		await get_tree().create_timer(1.3).timeout
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
	publish_state.call_deferred()
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
	if _lesson != "":
		_lesson_step()
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
		if model.playable_ids().is_empty():
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


## v0.6.4 Hammer: removes ANY block the player picks (normal, reward,
## armored, even a Chain Gate), unless that smash would MAKE the puzzle
## unsolvable. A rejected smash costs nothing, keeps the Hammer armed (pick
## another block or CANCEL) and only gives a short shake + buzz.
func _smash(id: int) -> void:
	if not model.blocks.has(id):
		return
	if not is_hammer_safe(id):
		AudioManager.play_invalid()
		board.play_hidden_tap(id)
		Haptics.medium()
		return
	hammer_armed = false
	board.hammer_mode = false
	tutorial.hide_hint()
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
	_play_second_era_effects()
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
	# A lesson whose mechanic block was smashed can't be shown any more: end
	# it quietly without marking it learned (it returns next time).
	if _lesson != "" and _lesson_blocks(_lesson).is_empty():
		_lesson = ""
		board.set_marks([])
		board.set_hint(-1)
	ui.set_progress(1.0 - float(model.block_count()) / maxf(_total_blocks, 1.0))
	_refresh_buttons()
	if model.is_empty():
		_on_board_cleared()


## True if smashing `id` does not MAKE the puzzle unsolvable (the rule is
## Solver.hammer_safe, shared with the tests).
func is_hammer_safe(id: int) -> bool:
	return Solver.hammer_safe(model, id)


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
		ui.show_chapter_banner(level_banner(number))


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
	# The Silver / Gold chime a beat after the escape sound, so it is heard
	# on its own instead of being masked by it.
	var session := _session_id
	var rarity := b.rarity
	get_tree().create_timer(0.09).timeout.connect(func():
		if session == _session_id:
			AudioManager.play_reward(rarity))
	Haptics.light()
	ui.fly_coins(board.get_global_transform_with_canvas() * at, coins, b.rarity, progress.coins)


## First level with an uncollected Silver (or Gold) block: one short line
## explaining it. Shown once per save.
func _maybe_explain_rewards() -> void:
	if _maybe_explain_mechanics():
		return
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


## v0.6: the first time a player meets a Second Era mechanic outside its
## lesson level (e.g. via Level Select), one short line explains it. Shown
## once per save. Returns true if a line was shown.
func _maybe_explain_mechanics() -> bool:
	var tips := [
		["switch", func(b): return b.is_switch(), "SWITCH: when it escapes, every arrow with its mark reverses"],
		["gate", func(b): return b.is_gate(), "CHAIN GATE: it opens once every block with its chain mark escapes"],
		["armor", func(b): return b.armored, "ARMORED: launch another block into it to crack the shell"],
	]
	for tip in tips:
		if progress.tips_seen.has(tip[0]):
			continue
		if level.blocks.any(tip[1]):
			progress.tips_seen.append(tip[0])
			progress.save()
			_show_message(tip[2], 3.6)
			return true
	return false


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
		"score": score, "total_score": progress.total_score(), "rewards_total": rewards_total, "rewards_got": rewards_got,
		"tiers": Economy.chest_tiers(progress, chapter),
		"next_title": Chapters.title(next) if has_next else "", "next_theme": Chapters.theme_for_chapter(next),
		"next_new": _chapter_news(next) if has_next else "", "completed": progress.completed_chapters.has(chapter)}


## What is new in a Chapter (for the preview line).
## Banner when a new look starts: Master / milestone / "SECOND ERA" at the
## era's first level / the Chapter title.
func level_banner(number: int) -> String:
	if Chapters.is_master(number):
		return "GRAND MASTER LEVEL" if number > Chapters.master_level() else "MASTER LEVEL"
	if Chapters.is_milestone(number):
		return "MILESTONE  ·  LEVEL %d" % number
	var era := Chapters.era_of(number)
	if era["index"] > 1 and number == era["from"]:
		return "%s\n%s" % [String(era["name"]).to_upper(), Chapters.title(Chapters.chapter_of(number))]
	return Chapters.title(Chapters.chapter_of(number))


func _chapter_news(chapter: int) -> String:
	var rg := Chapters.chapter_range(chapter)
	var news := []
	# v0.6 Second Era mechanics, where each is introduced.
	for intro in [[101, "Switch Blocks"], [121, "Chain Gates"], [161, "Armored Blocks"]]:
		if intro[0] >= rg.x and intro[0] <= rg.y:
			news.append(intro[1])
	var blocks: Dictionary = Economy.config().get("reward_blocks", {})
	for name in blocks:
		var from := int(blocks[name].get("from_level", 0))
		if bool(blocks[name].get("enabled", false)) and from >= rg.x and from <= rg.y:
			news.append("%s Blocks" % String(name).capitalize())
	for m in Chapters.master_levels():
		if m >= rg.x and m <= rg.y:
			news.append("the Grand Master" if m > Chapters.master_level() else "the Master Level")
	return "NEW: " + " & ".join(news) if not news.is_empty() else ""


func _show_chapter_card(chapter: int) -> void:
	pending_chapter_card = 0
	AudioManager.play_chapter_complete()
	Haptics.medium()
	ui.show_chapter_card(chapter_summary(chapter))
	publish_state.call_deferred()


## CONTINUE on the Chapter card: straight into the next Chapter.
func _after_chapter_card() -> void:
	start_level(current_level % level_manager.level_count + 1, "chapter")


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
				"milestone": Chapters.is_milestone(n),
				"current": n == current_level,
			})
		info["levels"] = levels
		info["unlocked"] = levels.any(func(l): return l["unlocked"])
		chapters.append(info)
	ui.open_level_select(chapters, progress.total_stars(), level_manager.level_count * 3, current_chapter, progress.total_score())
	# What the grid actually shows (diagnostics / browser tests).
	select_shown = {"unlocked": [], "locked": []}
	for c in chapters:
		for lv in c["levels"]:
			select_shown["unlocked" if lv["unlocked"] else "locked"].append(lv["number"])
	publish_state.call_deferred()


# --- Persistence & diagnostics -------------------------------------------------

## Leaving the app / tab / closing: save now (every change is already saved
## the moment it happens; this is the belt-and-braces flush).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST:
			if progress:
				progress.save()
		NOTIFICATION_WM_CLOSE_REQUEST:
			if progress:
				progress.save()
			Diagnostics.end_session()


func _hide_title() -> void:
	ui.hide_title()
	publish_state.call_deferred()
	if OS.has_feature("web"):
		WebBridge.call_api("saveNotice", [false])


## Web only: when this browser context can't keep progress (Safari/iOS in a
## cross-origin iframe such as an itch.io embed, or storage blocked), say so
## on the title and offer to open the game in its own tab, where saving
## works. Never shown when saving works.
func _update_storage_notice() -> void:
	if not OS.has_feature("web"):
		return
	var st := PlayerProgress.storage_status()
	print("[Save] storage: %s" % str(st))
	print("[Save] " + save_diagnostic())
	# Safari embeds get the full-screen "open in its own tab" gate from the
	# page script (web/audio_unlock.js) before anything is played.
	if st["persistent"] or st.get("ephemeral", false):
		return
	WebBridge.call_api("saveNotice", [true, "This browser is blocking saved data (private browsing?). Progress may not be kept - use BACKUP CODE in Settings.", "OPEN GAME"])


## Web: a read-only snapshot of the game for automated browser tests and
## remote debugging (window.chainEscapeState). Publishing it never changes
## the game. Button centers are normalized (0..1) screen positions.
func publish_state() -> void:
	if not OS.has_feature("web"):
		return
	var vis := get_viewport().get_visible_rect().size
	var center := func(c: Control) -> Array:
		var p := c.get_global_rect().get_center()
		return [snappedf(p.x / vis.x, 0.0001), snappedf(p.y / vis.y, 0.0001)]
	var st := {
		"level": current_level, "chapter": current_chapter, "completed": completed,
		"level_score": last_result.get("score", 0) if completed else 0,
		"total_score": progress.total_score(), "coins": progress.coins, "stars": progress.total_stars(),
		"highest_completed": progress.highest_completed, "highest_unlocked": progress.highest_unlocked,
		"last_played": progress.current_level, "save_seq": progress.seq, "save_source": progress.load_source,
		"inventory": progress.inventory, "title_open": ui.is_title_open(), "card_open": ui.is_complete_visible(),
		"chapter_card_open": ui.is_chapter_card_open(), "continue_text": ui._title._continue.text,
		"next": center.call(ui._next_button), "chapter_continue": center.call(ui._chapter_card._continue),
		"title_continue": center.call(ui._title._continue), "levels_button": center.call(ui._levels_button),
		"music": AudioManager.music_theme, "diag": last_diag,
		"hud_total": ui.hud_total_text(), "card_big": ui._card_score.text, "card_caption": ui._card_score_caption.text,
		"card_level": ui._card_total.text, "recovery_open": ui.is_recovery_open(), "writes_held": progress.hold_writes,
		"save_diag": save_diagnostic(), "settings_open": ui.is_settings_open(),
		"settings_button": center.call(ui._settings_button), "backup_button": center.call(ui._backup_button),
		"restore_button": center.call(ui._restore_button), "recovery_restore": center.call(ui._recovery_restore),
		"recovery_new": center.call(ui._recovery_new),
		"select_open": ui.is_level_select_open(), "select_unlocked": select_shown.get("unlocked", []).size(),
		"select_max_unlocked": (select_shown.get("unlocked", []) as Array).max() if not select_shown.get("unlocked", []).is_empty() else 0,
		"select_locked_first": (select_shown.get("locked", []) as Array).min() if not select_shown.get("locked", []).is_empty() else 0,
	}
	WebBridge.publish("chainEscapeState", st)


## Text for the debug panel (tap the level title 5 times on a phone).
func debug_info() -> String:
	var st := PlayerProgress.storage_status()
	return "%s\nSave: source=%s seq=%d v%d  last_played=%d  highest_completed=%d  highest_unlocked=%d  total_score=%d  coins=%d  saved=%s%s\nStorage: %s\n%s" % [
		Diagnostics.last_line, progress.load_source, progress.seq, progress.version, progress.current_level,
		progress.highest_completed, progress.highest_unlocked, progress.total_score(), progress.coins, progress.saved_text(),
		("  HELD(%s) beacon=%s" % [progress.hold_reason, JSON.stringify(progress.beacon)]) if progress.hold_writes else "", str(st),
		("Previous session: " + Diagnostics.previous_session) if Diagnostics.previous_session != "" else "Previous session: closed normally / first run"]


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


## v0.6.2 guided lesson: the blocks that matter for the mechanic (marked
## with brackets) - the switch and every arrow it reverses, the gate and
## every block chained to it, or the armored block.
func _lesson_blocks(kind: String) -> Array:
	var out := []
	var groups := {}
	for b in model.blocks.values():
		if (kind == "switch" and b.is_switch()) or (kind == "gate" and b.is_gate()) or (kind == "armor" and b.armored):
			out.append(b.id)
			groups[b.switch_group if kind == "switch" else b.gate_group] = true
	for b in model.blocks.values():
		if (kind == "switch" and groups.has(b.flip_link)) or (kind == "gate" and groups.has(b.gate_link)):
			out.append(b.id)
	return out


## One lesson beat: brackets on the mechanic's blocks, a finger on the next
## correct move (the solver's pick, so never a trap) and one short line.
## Called at the start and after every tap / undo until the player has
## done the mechanic's key action once.
func _lesson_step() -> void:
	var marks := _lesson_blocks(_lesson)
	var next := Solver.from_model(model).recommend_move()
	var text := ""
	var is_key := false
	match _lesson:
		"switch":
			is_key = next != -1 and model.blocks[next].is_switch()
			var g: String = model.blocks[marks[0]].switch_group if not marks.is_empty() else "A"
			text = ("Tap the SWITCH - every arrow marked %s turns around" % g) if is_key else ("SWITCH %s reverses its marked arrows - clear its way first" % g)
		"gate":
			var gid: int = marks[0] if not marks.is_empty() else -1
			var g: String = model.blocks[gid].gate_group if gid != -1 else "C"
			text = "GATE %s opens when every block chained %s escapes (%d left)" % [g, g, model.gate_remaining(g)]
		"armor":
			is_key = next != -1 and model.move_state(next) == "ram"
			# Mark the block that will be launched (the solution's first ram).
			for mv in Solver.from_model(model).solve_moves():
				if mv & Solver.RAM:
					marks.append(mv & Solver.ID_MASK)
					break
			if is_key:
				text = "Hit the armored block to break its shell"
			else:
				text = "Armored: can't escape. Clear a path for the marked block to hit it"
	board.set_marks(marks)
	if next == -1:
		board.set_hint(-1)
		tutorial.show_hint("No correct move here - tap Undo", _message_position())
		ui.pulse_undo_button()
		return
	board.set_hint(next)
	tutorial.show_hint(text, _message_position(), board.block_screen_position(next), true)


## The player did the key action once: remove the lesson for good.
func _finish_lesson() -> void:
	var kind := _lesson
	_lesson = ""
	board.set_marks([])
	board.set_hint(-1)
	if not progress.tips_seen.has("lesson_" + kind):
		progress.tips_seen.append("lesson_" + kind)
		progress.save()
	var done: String = {"switch": "The marked arrows turned around - now plan your switches!",
		"gate": "The gate is open - its lane is free!",
		"armor": "Shell cracked! Now it moves like any other block"}[kind]
	_show_message(done, 2.8)


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
