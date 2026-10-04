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
## v0.5: Chapter transitions through every entry point (visuals, block
## material, music), Silver/Gold rewards and anti-farming, Chapter complete
## (once) with chest and preview, Level Select by Chapter, relaunch.
##
##   godot --headless --path . res://tools/Playtest.tscn
##   godot --path . res://tools/Playtest.tscn -- --shots=/tmp/shots
##   godot --headless --path . res://tools/Playtest.tscn -- --chapters-only

const PROGRESS_PATH := "user://playtest_progress.cfg"

var game: GameManager
var shots_dir := ""
var failures: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	# Never touch the real player's progress.
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
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
	_check(total >= 200, "expected at least 200 levels")
	await _test_web_audio_gate()
	if "--chapters-only" in OS.get_cmdline_user_args():
		await _test_chapters_and_music()
		await _test_reward_blocks()
		await _test_chapter_complete()
		print("CHAPTERS-ONLY RUN: %s" % ("PASSED" if failures.is_empty() else "FAILED"))
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(0 if failures.is_empty() else 1)
		return
	await _test_perfect_and_bests()
	await _test_replay_and_level_select()
	await _test_score_display()
	await _test_second_era_mechanics()
	await _test_undo_limit()
	await _test_hint_limits()
	await _test_locked_block()
	await _test_mystery_reveal()
	await _test_out_of_hearts()
	await _test_restart()
	await _test_trap_and_stuck()
	await _test_chapters_and_music()
	await _test_reward_blocks()
	await _test_chapter_complete()
	await _test_shop_and_hammer()
	await _test_hint_booster()
	await _test_chests_and_coins()
	for n in range(1, total + 1):
		await _play_level(n)
	_test_persistence(total)
	await _test_master_level_result()
	await _test_relaunch_continue()
	if failures.is_empty():
		print("PLAYTEST PASSED: all %d levels cleared; chapters (visuals, block palette, music), silver/gold rewards + anti-farming, chapter complete + chests, save/continue, web audio gate, coins, shop, hammer, hint boosters, master level, score/stars/PERFECT, limits, locks, mystery, spinner rules OK" % total)
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


func _play_level(n: int) -> void:
	var total_prev := game.progress.total_score()
	var fresh_portal := n >= 201 and not game.progress.tips_seen.has("intro_portal") and game.progress.highest_completed < n
	game.start_level(n)
	# v0.7: the first Portal level opens with the NEW MECHANIC card (once).
	_check((game.mechanic_intro != null) == (fresh_portal and not game.level.portals.is_empty()), "L%d mechanic intro shown only on the first Portal level" % n)
	while game.mechanic_intro != null:
		await _wait(0.1)
	await _wait(0.45)
	_check(game.board.input_enabled, "L%d board takes input after the intro" % n)
	_check(game.ui.hud_total_text() == "TOTAL SCORE %s" % UIManager._fmt(total_prev),
		"L%d HUD shows TOTAL SCORE %d at start (%s)" % [n, total_prev, game.ui.hud_total_text()])
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
			_check(game.model.is_playable(hinted), "L%d hint %d is a legal move" % [n, hinted])
			var after := BoardModel.new()
			after.setup(game.model.rows, game.model.columns, game.model.snapshot())
			after.set_portals(game.model.portal_groups)
			if after.move_state(hinted) == "ram":
				after.ram(hinted)  # v0.6: a hint can be a ram
			else:
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
		var kind := game.model.move_state(id)
		var chain_before_tap := game.chain
		await _tap(id)
		if kind == "ram":
			# v0.6: a ram cracks a shell and removes nothing.
			_check(game.model.block_count() == before_count and game.model.blocks.has(id), "L%d ram by block %d must not remove it" % [n, id])
		else:
			# An escape removes the block (and opens any Chain Gate it completed).
			_check(game.model.block_count() == before_count - 1 - game.model.last_opened_gates.size(), "L%d tap on block %d did not remove it" % [n, id])
		taps += 1
		if taps == 3:
			_shot("L%02d_chain" % n)
		if taps == 2 and not undo_tested and not game.model.is_empty():
			undo_tested = true
			var chain_before_last: int = chain_before_tap
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
	var extra := 1.3 if Chapters.is_milestone(n) or Chapters.celebration_tier(n) != "" else 0.0
	await _wait(extra + (2.8 if Chapters.is_master(n) else (1.0 if not game.last_result.get("perfect", false) else 1.6)))
	_shot("L%02d_complete" % n)
	var r := game.last_result
	_check(game.ui.is_complete_visible(), "L%d complete card not shown" % n)
	_check(r.get("level", -1) == n and r["score"] > 0 and r["stars"] >= 1, "L%d settled with score and stars" % n)
	_check(not r["perfect"], "L%d is not PERFECT after mistake/undo" % n)
	_check(game.progress.best_score(n) >= r["score"] and game.progress.stars_for(n) >= r["stars"], "L%d best saved" % n)
	_check_score_card(n, total_prev, r)
	print("Level %3d C%-2d %-18s blocks=%2d spn=%d rules=%s lck=%d hid=%d score=%5d stars=%d coins=+%d" % [
		n, Chapters.chapter_of(n), game.level.name, start_count, _count(func(b): return b.is_spinner()),
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


## Chapter progression through every entry point. After each transition
## settles, EVERY Chapter-specific surface must show the new Chapter: the
## calculated Chapter, background (exact colors, decoration, particles),
## board tint, block material (on the real block views), accent (HUD,
## buttons, particles) and music - and only one music player may still be
## playing (clean transitions, no lingering overlap). Nothing may be left
## over from the previous Chapter.
func _test_chapters_and_music() -> void:
	AudioManager.set_music_enabled(true)  # real music transitions (dummy driver)
	var pairs := [[10, 11], [20, 21], [30, 31], [40, 41], [50, 51], [60, 61], [70, 71], [80, 81], [90, 91], [99, 100],
		# v0.6 Second Era: into the new era, every Chapter, the milestones and Level 200.
		[100, 101], [110, 111], [120, 121], [124, 125], [125, 126], [130, 131], [140, 141], [149, 150], [150, 151],
		[160, 161], [170, 171], [174, 175], [180, 181], [190, 191], [199, 200]]
	# 1) NEXT LEVEL
	for pr in pairs:
		game.start_level(pr[0])
		await _settle()
		_expect_chapter(pr[0], "start %d" % pr[0])
		game.ui.next_pressed.emit()
		await _settle()
		_expect_chapter(pr[1], "NEXT %d->%d" % pr)
		if pr[1] in [11, 41, 61, 91]:
			_shot("chapter_after_next_%d" % pr[1])
	# 2) Level Select
	for pr in pairs:
		game.start_level(pr[0])
		await _settle()
		game.ui.level_chosen.emit(pr[1])
		await _settle()
		_expect_chapter(pr[1], "LEVEL SELECT %d->%d" % pr)
	# 3) Replay and Restart keep the Chapter exactly applied
	for n in [11, 31, 51, 71, 91, 100]:
		game.start_level(n)
		await _settle()
		game.ui.replay_pressed.emit()
		await _settle()
		_expect_chapter(n, "REPLAY %d" % n)
		game.ui.restart_pressed.emit()
		await _settle()
		_expect_chapter(n, "RESTART %d" % n)
	# 4) Debug jumps (forwards, backwards, across several Chapters)
	for pr in [[10, 11], [41, 40], [60, 61], [81, 80], [99, 100], [100, 99], [95, 5], [5, 95], [23, 77]]:
		game.start_level(pr[0])
		await _settle()
		game.debug_panel.level_requested.emit(pr[1])
		await _settle()
		_expect_chapter(pr[1], "DEBUG JUMP %d->%d" % pr)
	# 5) Rapid transitions that interrupt the background and music fades
	game.start_level(39)
	await _settle()
	game.ui.next_pressed.emit()  # 40
	await _wait(0.25)
	game.ui.next_pressed.emit()  # 41 while the fade into 40 is still running
	await _settle()
	_expect_chapter(41, "RAPID 39->40->41")
	game.start_level(70)
	await _settle()
	game.ui.next_pressed.emit()  # 71, fading C7 -> C8
	await _wait(0.4)
	game.debug_panel.level_requested.emit(61)  # back to C7 mid-fade
	await _wait(0.1)
	game.ui.level_chosen.emit(90)  # and on to C9
	await _settle()
	_expect_chapter(90, "RAPID 70->71->61->90")
	_shot("chapter9_after_rapid")
	_check(game.ui._level_label.text == "LEVEL 90", "level label follows the jumps")
	_check(game.ui._name_label.text.contains("CHAPTER 9") and game.ui._name_label.text.ends_with("10/10"), "HUD shows the Chapter and the position in it ('%s')" % game.ui._name_label.text)
	game.start_level(100)
	await _settle()
	_check(game.ui._level_label.text == "MASTER LEVEL", "Level 100 shows the Master Level label")
	_shot("L100_master_theme")
	game.start_level(200)
	await _settle()
	_check(game.ui._level_label.text == "GRAND MASTER" and AudioManager.music_theme == "master2", "Level 200 shows GRAND MASTER with its own music")
	_expect_chapter(200, "Level 200 theme")
	game.start_level(150)
	await _settle()
	_check(game.ui._level_label.text == "LEVEL 150" and AudioManager.music_theme == "milestone", "milestone 150 has milestone music")
	game.ui.levels_opened.emit()
	await _frames(3)
	var headers := game.ui._level_select._list.get_children().filter(func(c): return c.has_meta("chapter"))
	var chapter_total := Chapters.chapter_count(game.level_manager.level_count)
	_check(headers.size() == chapter_total, "Level Select groups levels into %d Chapters (%d)" % [chapter_total, headers.size()])
	var eras := game.ui._level_select._list.get_children().filter(func(c): return c.has_meta("era"))
	# v0.7: 201+ opens the Third Era divider.
	_check(eras.size() == 3 and eras[1].get_meta("era") == 2 and eras[2].get_meta("era") == 3, "Level Select shows First, Second and Third Era dividers")
	_check(_count_tiles(game.ui._level_select._list) == game.level_manager.level_count, "Level Select still shows every level")
	_shot("level_select_chapters")
	game.ui._level_select.close()
	AudioManager.set_music_enabled(false)
	print("Chapters / music / block palette / level select OK (NEXT, Level Select, Replay, Restart, debug jumps, rapid)")


func _settle() -> void:
	await _wait(maxf(ChapterBackground.FADE_TIME, AudioManager.FADE_IN_DELAY + AudioManager.FADE_IN) + 0.45)


## Checks everything Chapter-specific that is on screen for level `n`.
func _expect_chapter(n: int, label: String) -> void:
	var t := Chapters.theme_for_level(n)
	var w := game.chapter_state()
	var expect_chapter := (n - 1) / 10 + 1  # 1-10 = 1 ... 91-100 = 10 ... 191-200 = 20
	var ok: bool = (w["level"] == n and w["chapter"] == expect_chapter and w["theme_id"] == t["id"]
		and w["background_theme_id"] == t["id"] and w["background_settled"]
		and game.background._top.is_equal_approx(t["bg_top"]) and game.background._bottom.is_equal_approx(t["bg_bottom"])
		and game.background._deco_color.is_equal_approx(t["deco_color"]) and game.background._particle_color.is_equal_approx(t["particle_color"])
		and w["board_color"].is_equal_approx(t["board"]) and w["accent"].is_equal_approx(t["accent"])
		and w["ui_theme_id"] == t["id"] and game.ui._progress.fill_color.is_equal_approx(t["accent"])
		and game.ui._coin_pill.accent.is_equal_approx(t["accent"])
		and w["block_style_id"] == t["id"] and w["block_style"] == t["block_style"]
		and w["music"] == t["music"] and AudioManager.music_theme == t["music"])
	_check(ok, "%s: level %d should be Chapter %d / theme %d / music %s, got %s" % [label, n, expect_chapter, t["id"], t["music"], str(w)])
	# The block views really wear this Chapter's material.
	var views_ok := true
	for id in game.model.blocks:
		var v := game.board.get_view(id)
		if v and not v.data.is_gate():
			# v0.6.2: an uncollected Silver/Gold block is metal all over.
			var want: Color = Palette.REWARD_BODY[v.data.rarity][1] if v._metal_body() else Palette.styled_face(v.data.color)
			views_ok = views_ok and v._face_style.bg_color.is_equal_approx(want)
	_check(views_ok, "%s: block views use Chapter %d's material" % [label, expect_chapter])
	# Music: the right theme, and exactly one player left once settled.
	if not AudioManager.music_enabled:
		return
	var playing := [AudioManager._music, AudioManager._music_b].filter(func(p): return p.playing)
	_check(playing.size() == 1 and AudioManager._music.playing and AudioManager._music.stream == AudioManager._theme_stream(t["music"]),
		"%s: exactly the Chapter's music is playing (%d players)" % [label, playing.size()])


## Silver / Gold blocks: pay once when they escape by play; Undo, Restart
## and Replay can't farm them; the Hammer never pays; feedback appears.
func _test_reward_blocks() -> void:
	game.progress.tips_seen.clear()
	# Silver on level 32 (Chapter 4).
	game.start_level(32)
	await _wait(0.4)
	var silver := _reward_id(BlockData.Rarity.SILVER)
	_check(silver != -1, "level 32 has a Silver block")
	_check(game.tutorial._text.begins_with("Silver Block"), "first Silver level explains it once ('%s')" % game.tutorial._text)
	_check(game.board.get_view(silver) != null and not game.board.get_view(silver).reward_spent, "Silver block shows as a reward")
	_shot("L32_silver")
	var c0 := game.progress.coins
	await _play_until_escaped(silver)
	await _wait(0.1)
	_shot("L32_silver_coins_fly")
	_check(game.progress.coins == c0 + 5 and game.reward_coins_attempt == 5, "Silver escape pays +5 (coins %d -> %d)" % [c0, game.progress.coins])
	_check(game.progress.has_reward_block(32, silver) and game.board.spent_rewards.has(silver), "Silver recorded as collected")
	var fly := game.ui._root.get_children().filter(func(c): return c is Label and c.text == "+5")
	_check(fly.size() == 1, "a Silver '+5' pops up and flies to the counter")
	_check(fly.size() == 1 and fly[0].get_theme_color("font_color").is_equal_approx(Palette.REWARD_BODY[BlockData.Rarity.SILVER][1]), "the '+5' is Silver-colored")
	_check(game.ui._coin_pill.coins == c0, "the counter waits for the flying coins (%d)" % game.ui._coin_pill.coins)
	await _wait(1.3)
	_check(game.ui._coin_pill.coins == game.progress.coins, "coin counter updated after the fly")
	# Undo brings the block back - spent - and escaping it again pays nothing.
	game.undo()
	await _wait(0.1)
	_check(game.model.blocks.has(silver) and game.board.get_view(silver).reward_spent, "Undo returns the Silver block as spent")
	var c1 := game.progress.coins
	await _tap(silver)
	await _wait(0.1)
	_check(not game.model.blocks.has(silver) and game.progress.coins == c1, "Undo cannot farm the Silver reward")
	# Restart and Replay: still spent, still nothing.
	game.restart()
	await _wait(0.3)
	_check(game.board.get_view(silver).reward_spent, "after Restart the Silver block is shown spent")
	await _play_until_escaped(silver)
	await _wait(0.1)
	_check(game.progress.coins == c1, "Restart cannot farm the Silver reward")
	_check(game.ui._root.get_children().filter(func(c): return c is Label and c.text == "+5").is_empty(), "an already-collected Silver shows no '+5' again")
	await _solve_cleanly()
	await _wait(1.3)
	_check(game.last_result["reward_coins"] == 0, "no reward coins on a farming attempt")
	# Gold on level 51 (Chapter 6).
	game.start_level(51)
	await _wait(0.4)
	var gold := _reward_id(BlockData.Rarity.GOLD)
	_check(gold != -1 and game.tutorial._text.begins_with("Gold Block"), "level 51 has a Gold block and explains it")
	var g0 := game.progress.coins
	await _play_until_escaped(gold)
	await _wait(0.1)
	_check(game.progress.coins == g0 + 15 and game.progress.has_reward_block(51, gold), "Gold escape pays +15")
	var gfly := game.ui._root.get_children().filter(func(c): return c is Label and c.text == "+15")
	_check(gfly.size() == 1 and gfly[0].get_theme_color("font_color").is_equal_approx(Palette.REWARD_BODY[BlockData.Rarity.GOLD][1]), "a Gold-colored '+15' pops up")
	await _solve_cleanly()
	await _wait(1.3)
	_check(game.last_result["reward_coins"] == 15 and String(game.last_result["coin_notes"]).contains("Gold +15"), "level card counts the Gold reward")
	_shot("L51_card_with_gold")
	# Hammer on a Gold block: no reward, and it stays earnable by play.
	var target := -1
	var level_n := -1
	for n in [56, 64, 68, 71, 78, 81, 83, 86, 88, 91, 93, 96, 98]:
		game.start_level(n)
		await _wait(0.2)
		var gid := _reward_id(BlockData.Rarity.GOLD)
		if gid != -1 and game.is_hammer_safe(gid):
			target = gid
			level_n = n
			break
	_check(target != -1, "found a Gold block that a Hammer may smash")
	if target != -1:
		game.progress.inventory["hammer"] = 1
		var h0 := game.progress.coins
		game.toggle_hammer()
		await _tap(target)
		await _wait(0.3)
		_check(not game.model.blocks.has(target) and game.progress.coins == h0, "Hammer on Gold pays no coins (L%d)" % level_n)
		_check(not game.progress.has_reward_block(level_n, target), "a smashed Gold block is not marked collected")
		_check(game.tutorial._text.begins_with("Smashed"), "the Hammer rule is explained")
		game.restart()
		await _wait(0.3)
		await _play_until_escaped(target)
		# Other reward blocks (e.g. a Silver) may be collected on the way.
		var others := 0
		for id in game.level.blocks.map(func(b): return b.id):
			if id != target and game.progress.has_reward_block(level_n, id):
				others += Economy.reward_block_coins(game.level.blocks[id].rarity)
		_check(game.progress.has_reward_block(level_n, target) and game.progress.coins == h0 + 15 + others,
			"the smashed Gold block can still be earned by play (coins %d -> %d, others %d)" % [h0, game.progress.coins, others])
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(disk.has_reward_block(32, silver) and disk.has_reward_block(51, gold), "collected rewards persisted")
	print("Silver / Gold rewards, anti-farming (Undo, Restart, Replay, Hammer) OK")


## Chapter 3 finished by clearing level 30: the moment fires once, shows
## the Chapter's numbers, lets the chest be claimed, previews Chapter 4 and
## continues into it. Clearing level 30 again fires nothing.
func _test_chapter_complete() -> void:
	for n in range(21, 30):
		game.progress.best_scores[n] = 4000
		game.progress.best_stars[n] = 3
	game.progress.highest_completed = maxi(game.progress.highest_completed, 29)
	game.progress.completed_chapters.erase(3)
	game.start_level(30)
	await _wait(0.4)
	var coins0 := game.progress.coins
	await _solve_cleanly()
	await _wait(1.8)
	var r := game.last_result
	_check(r["chapter_complete"] == 3 and game.progress.completed_chapters.has(3), "clearing level 30 completes Chapter 3")
	_check(String(r["coin_notes"]).contains("Chapter 3 complete!"), "level card mentions the Chapter bonus")
	_check(game.ui._next_button.text == "CONTINUE", "level card offers CONTINUE into the Chapter moment")
	game.ui.next_pressed.emit()
	await _wait(0.5)
	_check(game.ui.is_chapter_card_open() and game.ui.chapter_card_chapter() == 3, "Chapter Complete card shown")
	var card: ChapterCard = game.ui._chapter_card
	_check(card._kicker.text == "CHAPTER 3" and card._stars.text == "★ %d / 30" % Economy.chapter_stars(game.progress, 3), "card shows the Chapter's stars / 30")
	_check(card._next_title.text == "CHAPTER 4  ·  EMBER RIDGE" and card._next_new.text == "NEW: Silver Blocks", "card previews Chapter 4 and its Silver Blocks")
	_shot("chapter3_complete_card")
	# Claim the chest tiers right here.
	var c1 := game.progress.coins
	for tier in Economy.chest_tiers(game.progress, 3).size():
		game.ui.chest_claim.emit(3, tier)
	_check(game.progress.coins > c1 and Economy.chest_tiers(game.progress, 3).all(func(t): return t["claimed"] or not t["claimable"]), "chest claimed from the Chapter card")
	var claimed_before := game.progress.claimed_chests.size()
	game.ui.chest_claim.emit(3, 0)
	_check(game.progress.claimed_chests.size() == claimed_before, "the card never pays a chest twice")
	card._continue.pressed.emit()
	await _settle()
	_check(not game.ui.is_chapter_card_open() and game.current_level == 31, "CONTINUE starts Chapter 4")
	_expect_chapter(31, "CONTINUE from the Chapter card")
	# Fires once: clear level 30 again.
	game.start_level(30)
	await _wait(0.4)
	await _solve_cleanly()
	await _wait(1.8)
	_check(game.last_result["chapter_complete"] == 0 and game.pending_chapter_card == 0, "Chapter completion does not fire twice")
	game.ui.next_pressed.emit()
	await _wait(0.4)
	_check(not game.ui.is_chapter_card_open() and game.current_level == 31, "NEXT goes straight on after a repeat clear")
	_check(game.progress.coins >= coins0, "coins never go down through the Chapter flow")
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(disk.completed_chapters.has(3) and disk.claimed_chests.has(Economy.chest_id(3, 0)), "Chapter completion and chest persisted")
	print("Chapter complete (once), chest claim, next-Chapter preview OK")


func _reward_id(rarity: int) -> int:
	for id in game.model.blocks:
		if game.model.blocks[id].rarity == rarity:
			return id
	return -1


func _stays_solvable(id: int) -> bool:
	var t := BoardModel.new()
	t.setup(game.model.rows, game.model.columns, game.model.snapshot())
	t.set_portals(game.model.portal_groups)
	t.remove(id)
	return t.is_empty() or Solver.from_model(t).is_solvable()


## Plays solver moves until block `id` has escaped (never smashes).
func _play_until_escaped(id: int) -> void:
	var guard := 0
	while game.model.blocks.has(id) and guard < 60:
		guard += 1
		if game.model.can_escape(id) and _stays_solvable(id):
			await _tap(id)
		else:
			var m := Solver.from_model(game.model).recommend_move()
			if m == -1:
				break
			await _tap(m)
		await _wait(0.04)
	_check(not game.model.blocks.has(id), "block %d escaped by play" % id)


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
		game.tutorial.hide_hint(true)
		await _tap(unsafe)
		await _wait(0.1)
		_check(game.model.block_count() == count and game.progress.inventory["hammer"] == 2, "unsafe smash rejected, hammer not consumed")
		_check(game.hammer_armed and game.board.hammer_mode, "after a rejected smash the Hammer stays armed (pick another block)")
		_check(not game.tutorial.is_showing(), "a rejected smash shows no explanatory text")
	else:
		print("  (no unsafe smash on L31's first state - checked in unit tests)")
	if not game.hammer_armed:
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
	game.claim_chest(1, 0)
	var paid := game.progress.coins - before
	_check(paid > 0, "chest claim pays coins")
	game.claim_chest(1, 0)
	_check(game.progress.coins == before + paid, "chest cannot be claimed twice")
	game.ui._level_select.close()
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(disk.claimed_chests.has(Economy.chest_id(1, 0)), "claimed chest persisted")
	print("Coins / chests OK")


func _test_master_level_result() -> void:
	var r := game.progress.achievements.has("master")
	_check(r, "Master Level clear recorded as an achievement")
	# v0.6: the Grand Master (200) and the milestones pay their own one-time bonus.
	_check(game.progress.achievements.has("master_200"), "Level 200 (Grand Master) clear recorded")
	for n in [125, 150, 175]:
		_check(game.progress.achievements.has("milestone_%d" % n), "milestone %d clear recorded" % n)
	# The v0.5.2 -> v0.6 unlock: completing 100 opens 101.
	_check(game.progress.is_unlocked(101) and game.progress.highest_unlocked >= 201, "all 200 levels cleared unlock through 200")
	print("Master Level achievements OK (100, 200, milestones)")


## Simulates closing and reopening the app: a fresh GameManager built from
## the save file must restore everything and offer CONTINUE - LEVEL X.
func _test_relaunch_continue() -> void:
	game.start_level(57)
	await _wait(0.2)
	game.ui.setting_toggled.emit("haptics", false)
	var expect := {"coins": game.progress.coins, "inv": game.progress.inventory.duplicate(),
		"stars": game.progress.total_stars(), "best": game.progress.best_scores.duplicate(),
		"chests": game.progress.claimed_chests.duplicate(), "chapters": game.progress.completed_chapters.duplicate(),
		"rewards": game.progress.reward_blocks.duplicate()}
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
	_check(game.progress.claimed_chests == expect["chests"] and game.progress.completed_chapters == expect["chapters"], "chests and Chapter milestones restored")
	_check(game.progress.reward_blocks == expect["rewards"] and not expect["rewards"].is_empty(), "collected Silver/Gold blocks restored")
	_check(game.ui._title._stats.text.begins_with("CHAPTER 6  ·  MIDNIGHT TIDE"), "title shows the Chapter to continue ('%s')" % game.ui._title._stats.text)
	_check(not game.progress.haptics_on and not Haptics.enabled, "settings restored after relaunch")
	_check(game.progress.highest_unlocked > 57, "unlock progress restored (not reset to level 1)")
	_check(["lesson_switch", "lesson_gate", "lesson_armor"].all(func(t): return game.progress.tips_seen.has(t)), "finished lessons survive a relaunch")
	game.ui.continue_pressed.emit()
	await _frames(2)
	_check(not game.ui.is_title_open() and game.current_level == 57, "CONTINUE resumes level 57")
	await _settle()
	_expect_chapter(57, "CONTINUE after relaunch (57)")
	# Relaunch again into Chapter 9 (81) - a fresh start must apply Chapter
	# 9, not Chapter 1 defaults or a previous Chapter.
	game.start_level(81)
	await _wait(0.2)
	game.queue_free()
	await _frames(3)
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	game.ui.continue_pressed.emit()
	await _settle()
	AudioManager.set_music_enabled(true)
	await _settle()
	_expect_chapter(81, "CONTINUE after relaunch (81)")
	AudioManager.set_music_enabled(false)
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
	await _card_settled()
	_shot("perfect_card")
	var r := game.last_result
	_check(r["perfect"] and r["stars"] == 3, "clean solve is PERFECT with 3 stars")
	_check(r["score"] == ScoreRules.max_score(game.level.blocks.size()), "PERFECT unbroken chain scores the maximum (%d vs %d)" % [r["score"], ScoreRules.max_score(game.level.blocks.size())])
	_check(r["first_clear"], "first clear flagged")
	var best := game.progress.best_score(13)
	var total := game.progress.total_score()
	_check(game.ui._card_score_caption.text == "TOTAL SCORE" and game.ui._card_score.text == UIManager._fmt(total)
		and game.ui._card_total.text == "LEVEL SCORE  %s" % UIManager._fmt(r["score"]),
		"card: big number is TOTAL SCORE %s, LEVEL SCORE labelled (%s / %s)" % [UIManager._fmt(total), game.ui._card_score.text, game.ui._card_total.text])
	# Worse run: one blocked tap.
	game.start_level(13)
	await _wait(0.4)
	await _tap(_first_in_state("blocked"))
	await _solve_cleanly()
	await _wait(1.2)
	await _card_settled()
	r = game.last_result
	_check(not r["perfect"] and not r["new_best"] and r["score"] < best, "worse run is not NEW BEST")
	_check(game.progress.best_score(13) == best and game.progress.stars_for(13) == 3, "best score/stars kept after a worse run")
	_check(game.progress.total_score() == total and r["total_gain"] == 0 and game.ui._card_reward.text.begins_with("LEVEL BEST")
		and game.ui._card_score.text == UIManager._fmt(total) and not game.ui._card_gain.visible,
		"a worse run leaves TOTAL SCORE unchanged and shows the level best (%s / %s)" % [game.ui._card_score.text, game.ui._card_reward.text])
	var disk := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(disk.best_score(13) == best and disk.stars_for(13) == 3, "best score/stars persisted to disk")
	print("PERFECT / score / personal best / stars OK (best=%d)" % best)


## v0.5.2 score display. The big card number is TOTAL SCORE and can never
## show less than the total before the level; LEVEL SCORE is its own
## labelled line; the HUD always shows TOTAL SCORE.
func _check_score_card(n: int, total_prev: int, r: Dictionary) -> void:
	var total := game.progress.total_score()
	_check(total >= total_prev, "L%d TOTAL SCORE decreased (%d -> %d)" % [n, total_prev, total])
	_check(r["total_before"] == total_prev and r["total_after"] == total, "L%d result carries total before/after (%d/%d vs %d/%d)" % [n, r["total_before"], r["total_after"], total_prev, total])
	_check(game.ui._card_score_caption.text == "TOTAL SCORE", "L%d big card number is captioned TOTAL SCORE" % n)
	var shown := _num(game.ui._card_score.text)
	_check(shown >= total_prev and shown <= total, "L%d big card number %d outside [total before %d, total after %d]" % [n, shown, total_prev, total])
	_check(game.ui._card_total.text == "LEVEL SCORE  %s" % UIManager._fmt(r["score"]), "L%d LEVEL SCORE line (%s)" % [n, game.ui._card_total.text])
	_check(game.ui.hud_total_text() == "TOTAL SCORE %s" % UIManager._fmt(total), "L%d HUD TOTAL SCORE after the card (%s)" % [n, game.ui.hud_total_text()])


static func _num(text: String) -> int:
	return int(text.replace(",", ""))


## Level card after a clear: the big number has finished counting.
func _card_settled() -> void:
	await _wait(1.0)


## NEXT LEVEL, a lower-scoring next level, a worse replay and an improved
## replay, through the real card and HUD.
func _test_score_display() -> void:
	# Level 21 cleanly (high score), then NEXT to 22.
	game.start_level(21)
	await _wait(0.4)
	var t0 := game.progress.total_score()
	await _solve_cleanly()
	await _wait(1.6)
	await _card_settled()
	var r21 := game.last_result
	var t1 := game.progress.total_score()
	_check(t1 == t0 + r21["score"] and game.ui._card_score.text == UIManager._fmt(t1),
		"first clear: big number = TOTAL SCORE %d (shows %s)" % [t1, game.ui._card_score.text])
	_check(game.ui._card_gain.visible and game.ui._card_gain.text == "+%s" % UIManager._fmt(r21["score"]), "first clear shows +gain (%s)" % game.ui._card_gain.text)
	game.ui.next_pressed.emit()
	await _wait(0.4)
	_check(game.current_level == 22, "NEXT LEVEL goes to 22")
	_check(game.ui.hud_total_text() == "TOTAL SCORE %s" % UIManager._fmt(t1), "after NEXT the HUD still shows TOTAL SCORE %d (%s)" % [t1, game.ui.hud_total_text()])
	# Level 22 with a mistake: its LEVEL SCORE is lower than level 21's.
	var blocked := _first_in_state("blocked")
	if blocked != -1:
		await _tap(blocked)
		await _wait(0.2)
	await _solve_cleanly()
	await _wait(1.6)
	await _card_settled()
	var r22 := game.last_result
	var t2 := game.progress.total_score()
	_check(t2 == t1 + r22["score"] and t2 >= t1, "TOTAL SCORE never decreases after NEXT LEVEL (%d -> %d)" % [t1, t2])
	_check(game.ui._card_score.text == UIManager._fmt(t2) and _num(game.ui._card_score.text) >= t1,
		"level 22 card: big number is TOTAL SCORE %d, not the level score %d (shows %s)" % [t2, r22["score"], game.ui._card_score.text])
	_check(game.ui._card_total.text == "LEVEL SCORE  %s" % UIManager._fmt(r22["score"]), "level 22 card: LEVEL SCORE line (%s)" % game.ui._card_total.text)
	# Worse replay of 21: nothing changes.
	game.start_level(21)
	await _wait(0.4)
	blocked = _first_in_state("blocked")
	if blocked != -1:
		await _tap(blocked)
		await _wait(0.2)
	else:
		# No blocked tap on this board: an Undo also costs points.
		var id := Solver.from_model(game.model).recommend_move()
		await _tap(id)
		await _wait(0.3)
		game.undo()
		await _wait(0.3)
	await _solve_cleanly()
	await _wait(1.6)
	await _card_settled()
	var rw := game.last_result
	_check(rw["score"] < r21["score"], "replay of 21 scored lower (%d < %d)" % [rw["score"], r21["score"]])
	_check(game.progress.total_score() == t2 and rw["total_gain"] == 0 and game.ui._card_score.text == UIManager._fmt(t2) and not game.ui._card_gain.visible,
		"a worse replay does not reduce TOTAL SCORE (%d, shows %s)" % [game.progress.total_score(), game.ui._card_score.text])
	# Improved replay of 22: TOTAL SCORE rises by exactly the improvement.
	var old_best := game.progress.best_score(22)
	game.start_level(22)
	await _wait(0.4)
	await _solve_cleanly()
	await _wait(1.6)
	await _card_settled()
	var ri := game.last_result
	var delta: int = ri["score"] - old_best
	_check(delta > 0 and ri["new_best"], "clean replay of 22 beats its best (%d > %d)" % [ri["score"], old_best])
	_check(game.progress.total_score() == t2 + delta and ri["total_gain"] == delta and game.ui._card_gain.text == "+%s" % UIManager._fmt(delta),
		"an improvement adds only the delta +%d (total %d, card %s)" % [delta, game.progress.total_score(), game.ui._card_gain.text])
	_check(game.ui._card_score.text == UIManager._fmt(t2 + delta), "improved card shows TOTAL SCORE %d (%s)" % [t2 + delta, game.ui._card_score.text])
	# Title and Level Select say TOTAL SCORE with the same number.
	var tot := UIManager._fmt(game.progress.total_score())
	game.ui.levels_opened.emit()
	await _frames(3)
	_check(game.ui._level_select._total_label.text == "TOTAL SCORE  %s" % tot, "Level Select shows TOTAL SCORE %s (%s)" % [tot, game.ui._level_select._total_label.text])
	game.ui._level_select.close()
	print("Score display OK: TOTAL SCORE never decreases (NEXT, worse replay, improvement +%d)" % delta)


## v0.6: the three Second Era mechanics through real taps.
func _test_second_era_mechanics() -> void:
	# SWITCH (101): firing it reverses its linked arrows, model and view.
	game.start_level(101)
	await _wait(0.5)
	var sw := -1
	for id in game.model.blocks:
		if game.model.blocks[id].is_switch():
			sw = id
	_check(sw != -1, "level 101 has a switch")
	var targets := game.model.blocks.values().filter(func(b): return b.flip_link != "").map(func(b): return b.id)
	# v0.6.2 first-time lesson: switch + its arrows marked, a finger on the
	# next correct move, one short line.
	_check(game._lesson == "switch" and game.board.get_view(sw).marked and targets.all(func(t): return game.board.get_view(t).marked),
		"L101 lesson: the switch and its arrows are marked")
	_check(game.tutorial.is_showing() and game.tutorial._show_finger and game.tutorial._text.contains("SWITCH"), "L101 lesson: finger + SWITCH line")
	_shot("L101_lesson")
	var before := {}
	for t in targets:
		before[t] = game.model.blocks[t].direction
	# Play the solver's line up to the switch.
	var guard := 0
	while game.model.blocks.has(sw) and guard < 30:
		guard += 1
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.1)
	await _wait(0.5)
	var flipped_ok := true
	for t in targets:
		if game.model.blocks.has(t):
			flipped_ok = flipped_ok and game.model.blocks[t].direction == Direction.opposite(before[t]) and game.board.get_view(t).data.direction == game.model.blocks[t].direction
	_check(not game.model.blocks.has(sw) and flipped_ok, "switch escaped: its linked arrows reversed (model and view)")
	_shot("L101_after_switch")
	_check(game._lesson == "" and game.progress.tips_seen.has("lesson_switch"), "L101 lesson finished by firing the switch, and saved")
	_check(not game.board.get_view(targets[0]).marked if game.board.get_view(targets[0]) else true, "L101 lesson marks removed")
	game.start_level(101)
	await _wait(0.3)
	_check(game._lesson == "" and not game.tutorial._show_finger, "L101 replay: the lesson does not repeat")
	# CHAIN GATE (121): tapping it is free; its counter follows the links; it opens.
	game.start_level(121)
	await _wait(0.5)
	var gate := -1
	for id in game.model.blocks:
		if game.model.blocks[id].is_gate():
			gate = id
	_check(gate != -1, "level 121 has a Chain Gate")
	var group: String = game.model.blocks[gate].gate_group
	_check(game.board.get_view(gate).gate_count == game.model.gate_remaining(group), "gate counter shows the links left")
	var links := game.model.blocks.values().filter(func(b): return b.gate_link == group).map(func(b): return b.id)
	_check(game._lesson == "gate" and game.board.get_view(gate).marked and links.all(func(t): return game.board.get_view(t).marked)
		and game.tutorial._show_finger and game.tutorial._text.begins_with("GATE %s opens" % group), "L121 lesson: gate + chained blocks marked, finger, line")
	_shot("L121_lesson")
	var hearts := game.hearts
	await _tap(gate)
	await _wait(0.1)
	_check(game.hearts == hearts and game.mistakes == 0 and game.tutorial._text.begins_with("Chain Gate"), "tapping a gate is free and explains it")
	guard = 0
	while game.model.blocks.has(gate) and guard < 40:
		guard += 1
		await _tap(Solver.from_model(game.model).recommend_move())
		await _wait(0.1)
	await _wait(0.6)
	_check(not game.model.blocks.has(gate) and game.board.get_view(gate) == null, "the gate opened when its last link escaped")
	_check(game._lesson == "" and game.progress.tips_seen.has("lesson_gate"), "L121 lesson finished when the gate opened, and saved")
	# ARMOR (161): a ram is not a mistake; the shell breaks; Undo restores it.
	game.start_level(161)
	await _wait(0.5)
	var armored := -1
	for id in game.model.blocks:
		if game.model.blocks[id].armored:
			armored = id
	_check(armored != -1, "level 161 has an armored block")
	var source := -1
	for mv in Solver.from_model(game.model).solve_moves():
		if mv & Solver.RAM:
			source = mv & Solver.ID_MASK
			break
	_check(game._lesson == "armor" and game.board.get_view(armored).marked and source != -1 and game.board.get_view(source).marked
		and game.tutorial._show_finger, "L161 lesson: the armored target and the block to launch are marked, finger shown")
	_shot("L161_lesson")
	await _tap(armored)
	await _wait(0.1)
	_check(game.mistakes == 0 and game.tutorial._text.begins_with("Armored"), "tapping a shell is free and explains the ram")
	guard = 0
	var rammed := false
	while game.model.blocks.has(armored) and game.model.blocks[armored].armored and guard < 40:
		guard += 1
		var id := Solver.from_model(game.model).recommend_move()
		var kind := game.model.move_state(id)
		var h := game.hearts
		var others := {}
		if kind == "ram":
			_check(not game.board.get_view(armored).get("_arrow").visible, "the intact shell hides the big arrow")
			for oid in game.model.blocks:
				if oid != armored:
					var ob: BlockData = game.model.blocks[oid]
					others[oid] = [ob.cell, ob.direction, ob.armored]
		await _tap(id)
		await _wait(0.15)
		if kind == "ram":
			await _wait(0.4)
			var same := others.size() == game.model.blocks.size() - 1
			for oid in others:
				var ob: BlockData = game.model.blocks.get(oid)
				same = same and ob != null and others[oid] == [ob.cell, ob.direction, ob.armored]
			_check(same, "the shell burst is visual only: every other block is unchanged")
			_check(game.board.get_view(armored).get("_arrow").visible, "the burst reveals the block's arrow")
			_check(game.tutorial._text == "" or game.tutorial._text.begins_with("Shell cracked"), "L161 lesson: success line after the first ram ('%s')" % game.tutorial._text)
			rammed = true
			_check(game.hearts == h and game.mistakes == 0 and game.model.blocks.has(id), "a ram costs no heart and removes nothing")
	await _wait(0.4)
	_check(rammed and not game.model.blocks[armored].armored and not game.board.get_view(armored).data.armored, "the shell broke (model and view)")
	_shot("L161_after_ram")
	game.undo()
	await _wait(0.3)
	_check(game.model.blocks[armored].armored and game.board.get_view(armored).data.armored, "Undo restores the shell")
	_check(game._lesson == "" and game.progress.tips_seen.has("lesson_armor"), "L161 lesson finished by the first ram and stays finished after Undo")
	# Later Armor levels: no lesson; tapping a shell gives the short reminder.
	game.start_level(166)
	await _wait(0.3)
	_check(game._lesson == "", "L166: no lesson")
	var shell := _first_in_state("armored")
	if shell != -1:
		await _tap(shell)
		await _wait(0.1)
		_check(game.tutorial._text.begins_with("Armored") and game.mistakes == 0, "L166: tapping a shell shows the short reminder")
	print("Second Era mechanics OK (switch flip, gate open, armor ram + undo)")


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
		d[id] = [b.direction, b.hidden, game.model.is_locked(id), b.armored]
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
