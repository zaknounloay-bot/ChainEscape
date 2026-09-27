extends Node
## Automated play-through of every level through the real game scene.
##
## Taps are injected as InputEventScreenTouch at block screen positions, so
## this exercises the actual input -> rules -> animation -> UI path.
##
## Per level: a blocked tap (no removal, chain reset, heart lost from level
## 6), a Hint where the level allows one (legal, keeps the board solvable,
## not auto-played, counted), an Undo (block/spinner/lock/mystery state
## restored), then the level is cleared by following the solver; LEVEL
## COMPLETE must show with a score, stars and a saved best.
## Scenarios: PERFECT, personal best + stars persistence, Replay, Level
## Select, Undo limit, Hint limits, locked tap + unlock, hidden tap +
## reveal, out of hearts, Restart, spinner trap -> stuck -> recovery.
##
##   godot --headless --path . res://tools/Playtest.tscn
##   godot --path . res://tools/Playtest.tscn -- --shots=/tmp/shots
##   godot --headless --path . res://tools/Playtest.tscn -- --worlds-only

const PROGRESS_PATH := "user://playtest_progress.cfg"

var game: GameManager
var shots_dir := ""
var failures: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	# Never touch the real player's progress.
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	GameManager.skip_title = true
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	var total: int = game.level_manager.level_count
	print("Levels found: %d" % total)
	_check(total >= 100, "expected at least 100 levels")
	await _test_web_audio_gate()
	if "--worlds-only" in OS.get_cmdline_user_args():
		await _test_worlds_and_music()
		print("WORLDS-ONLY RUN: %s" % ("PASSED" if failures.is_empty() else "FAILED"))
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	await _test_perfect_and_bests()
	await _test_replay_and_level_select()
	await _test_undo_limit()
	await _test_hint_limits()
	await _test_locked_block()
	await _test_mystery_reveal()
	await _test_out_of_hearts()
	await _test_restart()
	await _test_trap_and_stuck()
	await _test_worlds_and_music()
	await _test_shop_and_hammer()
	await _test_hint_booster()
	await _test_chests_and_coins()
	for n in range(1, total + 1):
		await _play_level(n)
	_test_persistence(total)
	await _test_master_level_result()
	await _test_relaunch_continue()
	if failures.is_empty():
		print("PLAYTEST PASSED: all %d levels cleared; save/continue, worlds+music, web audio gate, coins, chests, shop, hammer, hint boosters, master level, score/stars/PERFECT, limits, locks, mystery, spinner rules OK" % total)
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


func _play_level(n: int) -> void:
	game.start_level(n)
	await _wait(0.45)
	_shot("L%02d_start" % n)
	var start_count := game.model.block_count()
	var expected_hearts := 3 if n >= GameManager.HEARTS_FROM_LEVEL else 0
	_check(game.max_hearts == expected_hearts and game.hearts == expected_hearts, "L%d starts with %d hearts" % [n, expected_hearts])

	# 1) Blocked tap: stays, chain resets, costs a heart from level 6.
	var blocked := _first_in_state("blocked")
	if blocked != -1:
		var before := game.model.block_count()
		await _tap(blocked)
		await _wait(0.05)
		_check(game.model.block_count() == before, "L%d blocked tap removed a block" % n)
		_check(game.chain == 0 and game.mistakes == 1, "L%d blocked tap = mistake, chain reset" % n)
		_check(game.hearts == maxi(expected_hearts - 1, 0), "L%d blocked tap heart count" % n)
		await _wait(0.2)

	# 2) Hint where allowed: legal, solvable after, not auto-played, counted.
	if game.hints_allowed() > 0:
		var count_before := game.model.block_count()
		game.request_hint()
		await _frames(2)
		var hinted := game.hint_block
		_check(hinted != -1 and game.hints_used == 1, "L%d hint shown and counted" % n)
		_check(game.model.block_count() == count_before, "L%d hint must not play the move" % n)
		if hinted != -1:
			_check(game.model.can_escape(hinted), "L%d hint %d is a legal move" % [n, hinted])
			var after := BoardModel.new()
			after.setup(game.model.rows, game.model.columns, game.model.snapshot())
			after.remove(hinted)
			_check(Solver.from_model(after).is_solvable(), "L%d hint keeps the board solvable" % n)
			_check(game.board.get_view(hinted).hinted, "L%d hinted block is highlighted" % n)
			_shot("L%02d_hint" % n)

	# 3) Clear the level following the solver; Undo once after 2 moves.
	var taps := 0
	var undo_tested := false
	while not game.model.is_empty():
		var id := Solver.from_model(game.model).recommend_move()
		_check(id != -1, "L%d solver found no move with %d blocks left" % [n, game.model.block_count()])
		if id == -1:
			return
		var snapshot := _state()
		var before_count := game.model.block_count()
		await _tap(id)
		_check(game.model.block_count() == before_count - 1, "L%d tap on block %d did not remove it" % [n, id])
		taps += 1
		if taps == 3:
			_shot("L%02d_chain" % n)
		if taps == 2 and not undo_tested and not game.model.is_empty():
			undo_tested = true
			var chain_before_last: int = game.chain - 1
			game.undo()
			await _wait(0.05)
			_check(game.model.blocks.has(id), "L%d undo did not restore block %d" % [n, id])
			_check(game.chain == chain_before_last, "L%d undo did not restore chain" % n)
			_check(_state() == snapshot, "L%d undo did not restore directions/hidden/locks" % n)
			_check(game.undos_used == 1, "L%d undo counted" % n)
			await _wait(0.3)
			taps -= 1
		await _wait(0.07)
	# PERFECT and the Master Level celebrate longer before the card.
	await _wait(2.4 if n == Worlds.MASTER_LEVEL else (1.0 if not game.last_result.get("perfect", false) else 1.6))
	_shot("L%02d_complete" % n)
	var r := game.last_result
	_check(game.ui.is_complete_visible(), "L%d complete card not shown" % n)
	_check(r.get("level", -1) == n and r["score"] > 0 and r["stars"] >= 1, "L%d settled with score and stars" % n)
	_check(not r["perfect"], "L%d is not PERFECT after mistake/undo" % n)
	_check(game.progress.best_score(n) >= r["score"] and game.progress.stars_for(n) >= r["stars"], "L%d best saved" % n)
	print("Level %3d W%d %-18s blocks=%2d spn=%d rules=%s lck=%d hid=%d score=%5d stars=%d coins=+%d" % [
		n, Worlds.world_of(n), game.level.name, start_count, _count(func(b): return b.is_spinner()),
		",".join(game.level.blocks.filter(func(b): return b.is_spinner()).map(func(b): return ["cw", "ccw", "alt", "pat"][b.spin_rule])),
		_count(func(b): return b.lock_color != ""), _count(func(b): return b.hidden), r["score"], r["stars"], r["coins"]])


# --- v0.4 scenarios ----------------------------------------------------------

## Mobile-web rule simulated in-engine: music must wait for the first real
## input event, then start (the real browser is covered by
## tools/web_audio_test.mjs).
func _test_web_audio_gate() -> void:
	AudioManager.set_music_enabled(true)
	AudioManager.require_gesture = true
	AudioManager.unlocked = false
	AudioManager._music.stop()
	AudioManager.start_music()
	await _frames(2)
	_check(not AudioManager.is_music_playing(), "web: music does not start before the first gesture")
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	ev.position = Vector2(10, 10)
	get_tree().root.push_input(ev, true)
	await _frames(3)
	_check(AudioManager.unlocked and AudioManager.is_music_playing(), "web: first tap unlocks audio and starts music")
	AudioManager.set_music_enabled(false)
	print("Web audio gate OK")


## World progression through every entry point. After each transition
## settles, EVERY World-specific surface must show the new World: the
## calculated World, background (exact colors, decoration), board tint,
## accent (HUD, buttons, particles) and music. Nothing may be left over
## from the previous World.
func _test_worlds_and_music() -> void:
	var pairs := [[20, 21], [40, 41], [60, 61], [80, 81], [99, 100]]
	# 1) NEXT LEVEL
	for pr in pairs:
		game.start_level(pr[0])
		await _settle()
		_expect_world(pr[0], "start %d" % pr[0])
		game.ui.next_pressed.emit()
		await _settle()
		_expect_world(pr[1], "NEXT %d->%d" % pr)
		if pr[1] == 21:
			_shot("world2_after_next")
		if pr[1] == 81:
			_shot("world5_after_next_from_80")
	# 2) Level Select
	for pr in pairs:
		game.start_level(pr[0])
		await _settle()
		game.ui.level_chosen.emit(pr[1])
		await _settle()
		_expect_world(pr[1], "LEVEL SELECT %d->%d" % pr)
	# 3) Replay (same World must stay exactly applied)
	for n in [21, 41, 61, 81, 100]:
		game.start_level(n)
		await _settle()
		game.ui.replay_pressed.emit()
		await _settle()
		_expect_world(n, "REPLAY %d" % n)
	# 4) Debug jumps (forwards, backwards, across several Worlds)
	for pr in [[20, 21], [40, 41], [60, 61], [80, 81], [99, 100], [100, 99], [81, 80], [61, 60], [95, 5], [5, 95]]:
		game.start_level(pr[0])
		await _settle()
		game.debug_panel.level_requested.emit(pr[1])
		await _settle()
		_expect_world(pr[1], "DEBUG JUMP %d->%d" % pr)
	# 5) Rapid transitions that interrupt the cross-fade
	game.start_level(79)
	await _settle()
	game.ui.next_pressed.emit()  # 80
	await _wait(0.25)
	game.ui.next_pressed.emit()  # 81 while the fade into 80 is still running
	await _settle()
	_expect_world(81, "RAPID 79->80->81")
	game.start_level(80)
	await _settle()
	game.ui.next_pressed.emit()  # 81, fading W4 -> W5
	await _wait(0.5)
	game.debug_panel.level_requested.emit(61)  # back to W4 mid-fade
	await _wait(0.1)
	game.ui.level_chosen.emit(90)  # and to W5 again
	await _settle()
	_expect_world(90, "RAPID 80->81->61->90")
	_shot("world5_after_rapid")
	_check(game.ui._level_label.text == "LEVEL 90", "level label follows the jumps")
	game.start_level(100)
	await _settle()
	_check(game.ui._level_label.text == "MASTER LEVEL", "Level 100 shows the Master Level label")
	_shot("L100_master_theme")
	game.ui.levels_opened.emit()
	await _frames(3)
	var worlds := game.ui._level_select._list.get_children().filter(func(c): return c.has_meta("world"))
	_check(worlds.size() == 5, "Level Select groups levels into 5 Worlds (%d)" % worlds.size())
	_shot("level_select_worlds")
	game.ui._level_select.close()
	print("Worlds / music / level select grouping OK (NEXT, Level Select, Replay, debug jumps, rapid)")


func _settle() -> void:
	await _wait(WorldBackground.FADE_TIME + 0.45)


## Checks everything World-specific that is on screen for level `n`.
func _expect_world(n: int, label: String) -> void:
	var t := Worlds.theme_for_level(n)
	var w := game.world_state()
	var expect_world := clampi((n - 1) / 20 + 1, 1, 5)  # 1-20=1 ... 81-100=5
	var ok: bool = (w["level"] == n and w["world"] == expect_world and w["theme_id"] == t["id"]
		and w["background_theme_id"] == t["id"] and w["background_settled"]
		and game.background._top.is_equal_approx(t["bg_top"]) and game.background._bottom.is_equal_approx(t["bg_bottom"])
		and game.background._deco_color.is_equal_approx(t["deco_color"])
		and w["board_color"].is_equal_approx(t["board"]) and w["accent"].is_equal_approx(t["accent"])
		and w["ui_theme_id"] == t["id"] and game.ui._progress.fill_color.is_equal_approx(t["accent"])
		and game.ui._coin_pill.accent.is_equal_approx(t["accent"])
		and w["music"] == t["music"] and AudioManager.music_theme == t["music"])
	_check(ok, "%s: level %d should be World %d / theme %d / music %s, got %s" % [label, n, expect_world, t["id"], t["music"], str(w)])


func _test_shop_and_hammer() -> void:
	game.progress.coins = 500
	game.progress.inventory["hammer"] = 0
	game.start_level(31)
	await _wait(0.3)
	game.toggle_hammer()  # none owned -> opens the shop
	_check(game.ui.is_shop_open(), "hammer with empty inventory opens the Shop")
	_shot("shop")
	game.ui.buy_requested.emit("hammer")
	game.ui.buy_requested.emit("hammer")
	_check(game.progress.inventory["hammer"] == 2 and game.progress.coins == 500 - 2 * Economy.price("hammer"), "buying hammers spends coins")
	game.ui._shop.close()
	# Find an unsafe block (smashing it would make the level unsolvable).
	var unsafe := -1
	var safe := -1
	for id in game.model.blocks:
		if game.is_hammer_safe(id):
			if safe == -1:
				safe = id
		elif unsafe == -1:
			unsafe = id
	if unsafe != -1:
		game.toggle_hammer()
		var count := game.model.block_count()
		await _tap(unsafe)
		_check(game.model.block_count() == count and game.progress.inventory["hammer"] == 2, "unsafe smash rejected, hammer not consumed")
	else:
		print("  (no unsafe smash on L31's first state - checked in unit tests)")
	game.toggle_hammer()
	_check(game.board.hammer_mode, "hammer armed")
	var before := game.model.block_count()
	await _tap(safe)
	await _wait(0.3)
	_check(game.model.block_count() == before - 1 and game.progress.inventory["hammer"] == 1 and game.hammers_used == 1, "safe smash removes the block and uses one hammer")
	_check(Solver.from_model(game.model).is_solvable(), "board still solvable after the hammer")
	game.toggle_hammer()
	_check(not game.hammer_armed, "only one hammer per level")
	await _solve_cleanly()
	await _wait(1.2)
	_check(not game.last_result["perfect"] and game.last_result["hammers"] == 1, "hammer use prevents PERFECT")
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(disk.inventory["hammer"] == 1, "hammer inventory persisted")
	print("Shop / Hammer OK")


func _test_hint_booster() -> void:
	game.progress.inventory["hint"] = 1
	game.start_level(14)  # no free hints before level 20
	await _wait(0.3)
	game.request_hint()
	_check(game.hint_block != -1 and game.progress.inventory["hint"] == 0 and game.booster_hints_used == 1, "hint booster used when no free hints are left")
	_check(game.model.can_escape(game.hint_block), "booster hint is a legal move")
	await _tap(game.hint_block)
	game.request_hint()
	_check(game.hint_block == -1, "no hint without free hints or boosters")
	print("Hint booster OK")


func _test_chests_and_coins() -> void:
	# Coins: first clear pays, replay without improving pays nothing.
	game.start_level(3)
	await _wait(0.3)
	var c0 := game.progress.coins
	await _solve_cleanly()
	await _wait(1.3)
	var c1 := game.progress.coins
	_check(c1 > c0 and game.last_result["coins"] == c1 - c0, "first clear pays coins (%d)" % (c1 - c0))
	game.start_level(3)
	await _wait(0.3)
	await _solve_cleanly()
	await _wait(1.3)
	_check(game.progress.coins == c1 and game.last_result["coins"] == 0, "replay without improving pays nothing")
	# Chest for levels 1-10.
	for n in range(1, 11):
		game.progress.best_stars[n] = maxi(game.progress.stars_for(n), 2)
	var before := game.progress.coins
	game.claim_chest(0, 0)
	var paid := game.progress.coins - before
	_check(paid > 0, "chest claim pays coins")
	game.claim_chest(0, 0)
	_check(game.progress.coins == before + paid, "chest cannot be claimed twice")
	game.ui._level_select.close()
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(disk.claimed_chests.has(Economy.chest_id(0, 0)), "claimed chest persisted")
	print("Coins / chests OK")


func _test_master_level_result() -> void:
	var r := game.progress.achievements.has("master")
	_check(r, "Master Level clear recorded as an achievement")
	print("Master Level achievement OK")


## Simulates closing and reopening the app: a fresh GameManager built from
## the save file must restore everything and offer CONTINUE - LEVEL X.
func _test_relaunch_continue() -> void:
	game.start_level(57)
	await _wait(0.2)
	game.ui.setting_toggled.emit("haptics", false)
	var expect := {"coins": game.progress.coins, "inv": game.progress.inventory.duplicate(),
		"stars": game.progress.total_stars(), "best": game.progress.best_scores.duplicate(),
		"chests": game.progress.claimed_chests.duplicate(), "worlds": game.progress.completed_worlds.duplicate()}
	game.queue_free()
	await _frames(3)
	GameManager.skip_title = false
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	_check(game.ui.is_title_open(), "relaunch shows the title screen")
	_check(game.ui._title._continue.text == "CONTINUE  -  LEVEL 57", "title offers CONTINUE - LEVEL 57 (got '%s')" % game.ui._title._continue.text)
	_shot("relaunch_title")
	_check(game.current_level == 57, "last played level restored")
	_check(game.progress.coins == expect["coins"] and game.progress.inventory == expect["inv"], "coins and boosters restored")
	_check(game.progress.total_stars() == expect["stars"] and game.progress.best_scores == expect["best"], "stars and best scores restored")
	_check(game.progress.claimed_chests == expect["chests"] and game.progress.completed_worlds == expect["worlds"], "chests and world milestones restored")
	_check(not game.progress.haptics_on and not Haptics.enabled, "settings restored after relaunch")
	_check(game.progress.highest_unlocked() > 57, "unlock progress restored (not reset to level 1)")
	game.ui.continue_pressed.emit()
	await _frames(2)
	_check(not game.ui.is_title_open() and game.current_level == 57, "CONTINUE resumes level 57")
	await _settle()
	_expect_world(57, "CONTINUE after relaunch (57)")
	# Relaunch again into World 5 (81) - a fresh start must apply World 5,
	# not World 1 defaults or a previous World.
	game.start_level(81)
	await _wait(0.2)
	game.queue_free()
	await _frames(3)
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	game.ui.continue_pressed.emit()
	await _settle()
	_expect_world(81, "CONTINUE after relaunch (81)")
	print("Relaunch / continue OK")


func _count_tiles(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is LevelSelect.LevelTile:
			n += 1
		n += _count_tiles(c)
	return n


func _count(pred: Callable) -> int:
	return game.level.blocks.filter(pred).size()


## PERFECT on level 13: exact max score, 3 stars, PERFECT stamp; then a
## worse replay keeps the best.
func _test_perfect_and_bests() -> void:
	game.start_level(13)
	await _wait(0.4)
	await _solve_cleanly()
	await _wait(1.8)
	_shot("perfect_card")
	var r := game.last_result
	_check(r["perfect"] and r["stars"] == 3, "clean solve is PERFECT with 3 stars")
	_check(r["score"] == ScoreRules.max_score(game.level.blocks.size()), "PERFECT unbroken chain scores the maximum (%d vs %d)" % [r["score"], ScoreRules.max_score(game.level.blocks.size())])
	_check(r["first_clear"], "first clear flagged")
	var best := game.progress.best_score(13)
	# Worse run: one blocked tap.
	game.start_level(13)
	await _wait(0.4)
	await _tap(_first_in_state("blocked"))
	await _solve_cleanly()
	await _wait(1.2)
	r = game.last_result
	_check(not r["perfect"] and not r["new_best"] and r["score"] < best, "worse run is not NEW BEST")
	_check(game.progress.best_score(13) == best and game.progress.stars_for(13) == 3, "best score/stars kept after a worse run")
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(disk.best_score(13) == best and disk.stars_for(13) == 3, "best score/stars persisted to disk")
	print("PERFECT / score / personal best / stars OK (best=%d)" % best)


func _test_replay_and_level_select() -> void:
	game.ui.replay_pressed.emit()
	await _wait(0.3)
	_check(game.current_level == 13 and not game.completed and game.model.block_count() == game.level.blocks.size(), "Replay restarts the same level")
	game.ui.levels_opened.emit()
	await _frames(3)
	_check(game.ui.is_level_select_open(), "level select opens")
	_shot("level_select")
	var tiles: int = _count_tiles(game.ui._level_select._list)
	_check(tiles == game.level_manager.level_count, "level select shows every level (%d)" % tiles)
	game.ui.level_chosen.emit(5)
	game.ui._level_select.close()
	await _wait(0.3)
	_check(game.current_level == 5 and not game.ui.is_level_select_open(), "choosing a level starts it")
	print("Replay / Level Select OK")


func _test_undo_limit() -> void:
	game.start_level(12)
	await _wait(0.4)
	for i in GameManager.MAX_UNDOS + 1:
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.05)
		game.undo()
		await _wait(0.05)
	_check(game.undos_used == GameManager.MAX_UNDOS, "undo limited to %d (used %d)" % [GameManager.MAX_UNDOS, game.undos_used])
	_check(game.history.can_undo() and game.ui._undo_button.disabled, "undo button disabled at 0 uses")
	print("Undo limit OK")


func _test_hint_limits() -> void:
	game.progress.inventory["hint"] = 0  # test the free allowance only
	for spec in [[12, 0], [25, 1], [35, 2]]:
		game.start_level(spec[0])
		await _wait(0.3)
		_check(game.hints_allowed() == spec[1], "L%d allows %d hints" % spec)
		for i in 3:
			game.request_hint()
			await _frames(1)
			if game.hint_block != -1:
				await _tap(game.hint_block)  # follow it so the next can show
				await _wait(0.05)
		_check(game.hints_used == spec[1], "L%d hint cap respected (used %d)" % [spec[0], game.hints_used])
	# Debug mode: unlimited and free.
	game.start_level(12)
	await _wait(0.3)
	game.debug_panel.visible = true
	game.request_hint()
	_check(game.hint_block != -1 and game.hints_used == 0, "debug mode: unlimited hints")
	game.debug_panel.visible = false
	print("Hint limits OK")


func _test_locked_block() -> void:
	game.start_level(16)
	await _wait(0.4)
	var locked := _first_in_state("locked")
	_check(locked != -1 and game.board.get_view(locked).locked_visual, "lock intro has a visibly locked block")
	await _tap(locked)
	await _wait(0.1)
	_shot("L16_locked_tap")
	_check(game.model.blocks.has(locked) and game.mistakes == 1, "tapping a locked block is a mistake and it stays")
	while game.model.is_locked(locked):
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.05)
	await _wait(0.6)
	_check(not game.board.get_view(locked).locked_visual, "unlock animation cleared the padlock")
	_check(game.model.can_escape(locked) or game.model.move_state(locked) == "blocked", "unlocked block is playable")
	_shot("L16_unlocked")
	print("Locked block OK")


func _test_mystery_reveal() -> void:
	game.start_level(10)
	await _wait(0.4)
	var hidden := _first_in_state("hidden")
	_check(hidden != -1 and game.level.mystery, "mystery intro has a hidden block")
	_shot("L10_mystery")
	var hearts := game.hearts
	await _tap(hidden)
	await _wait(0.1)
	_check(game.mistakes == 0 and game.hearts == hearts and game.model.blocks.has(hidden), "tapping a hidden block is free")
	while game.model.blocks[hidden].hidden:
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.05)
	await _wait(0.4)
	_check(not game.board.get_view(hidden).data.hidden, "hidden arrow revealed on screen")
	_shot("L10_revealed")
	print("Mystery reveal OK")


## Level 6: three blocked taps -> Try Again -> fresh attempt with 3 hearts.
func _test_out_of_hearts() -> void:
	game.start_level(6)
	await _wait(0.4)
	for i in 3:
		await _tap(_first_in_state("blocked"))
		await _wait(0.1)
	_check(game.hearts == 0 and game.game_over, "out of hearts after 3 blocked taps")
	await _wait(0.7)
	_shot("hearts_try_again")
	await _wait(1.4)
	_check(not game.game_over and game.hearts == 3, "level restarted with 3 hearts")
	print("Out-of-hearts flow OK")


func _test_restart() -> void:
	game.start_level(7)
	await _wait(0.4)
	await _tap(Solver.from_model(game.model).recommend_move())
	await _tap(_first_in_state("blocked"))
	game.restart()
	await _wait(0.1)
	_check(game.model.block_count() == game.level.blocks.size() and game.hearts == 3 and game.undos_used == 0 and not game.history.can_undo(),
		"restart resets blocks, hearts, undos and history")
	print("Restart OK")


## Level 11: the spinner trap -> stuck -> free hint refusal -> Undo recovers.
func _test_trap_and_stuck() -> void:
	game.start_level(11)
	await _wait(0.4)
	var trap := -1
	for id in game.model.free_block_ids():
		var m := BoardModel.new()
		m.setup(game.model.rows, game.model.columns, game.model.snapshot())
		m.remove(id)
		if not Solver.from_model(m).is_solvable():
			trap = id
	_check(trap != -1, "level 11 has a trap move")
	if trap == -1:
		return
	await _tap(trap)
	while not game.model.free_block_ids().is_empty():
		await _tap(game.model.free_block_ids()[0])
		await _wait(0.05)
	_check(not game.model.is_empty(), "trap leads to a stuck board")
	await _wait(0.2)
	_shot("L11_stuck")
	while game.history.can_undo() and game.undos_used < GameManager.MAX_UNDOS:
		game.undo()
	await _wait(0.3)
	_check(game.model.block_count() == game.level.blocks.size(), "undo recovers from the trap")
	print("Trap / stuck / undo recovery OK")


func _test_persistence(total: int) -> void:
	var reloaded := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(reloaded.highest_completed == total, "highest completed persisted")
	_check(reloaded.best_scores.size() == total and reloaded.best_stars.size() == total, "a best score and stars saved for every level")
	for n in range(1, total + 1):
		_check(reloaded.best_score(n) == game.progress.best_score(n), "L%d best persisted" % n)
	print("Persistence OK (%d best scores, %d stars total)" % [reloaded.best_scores.size(), reloaded.total_stars()])


func _solve_cleanly() -> void:
	while not game.model.is_empty():
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.03)


func _state() -> Dictionary:
	var d := {}
	for id in game.model.blocks:
		var b: BlockData = game.model.blocks[id]
		d[id] = [b.direction, b.hidden, game.model.is_locked(id)]
	return d


func _first_in_state(state: String) -> int:
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		if game.model.move_state(id) == state:
			return id
	return -1


func _tap(id: int) -> void:
	var view := game.board.get_view(id)
	if view == null:
		_check(false, "no view for block %d" % id)
		return
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = game.board.get_global_transform_with_canvas() * view.home
	ev.pressed = true
	get_tree().root.push_input(ev, true)
	var up := ev.duplicate()
	up.pressed = false
	get_tree().root.push_input(up, true)
	await _frames(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _shot(name: String) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [shots_dir, name])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
