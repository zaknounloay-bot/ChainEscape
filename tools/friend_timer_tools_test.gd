extends Node
## Phase 4: Challenge a Friend TIME + tools by difficulty, in the real game
## (Main scene, title -> Social, the game's own SocialPlay):
##   A. tools per difficulty: allowances, badges, the dimmed VERY HARD
##      Hammer, limits enforced in gameplay (not only by the buttons),
##      RESTART unlimited and resetting the per-attempt tools;
##   B. the timer: runs while playing, pauses with EXIT and a hidden page,
##      keeps going across RESTART, freezes at the solve (shown big on the
##      solved screen), PLAY AGAIN starts a fresh run, the text changes only
##      once per visible second;
##   C. Photo / Message Reveal unchanged: tools x3 / x2 / x2, no timer, no
##      time on its reveal (also right after a VERY HARD friend challenge);
##   D. Classic untouched: save file, progress, the Classic attempt clock.
##
##   godot --headless --path . res://tools/FriendTimerToolsTest.tscn

const PROGRESS_PATH := "user://friend_timer_tools_test_progress.cfg"

var game: GameManager
var social: SocialScreen
var play: SocialPlay
var failures: Array[String] = []
var passes := 0
var puzzle: PuzzleDefinition


func _ready() -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	SocialConfig.api_url_override = "off"
	_run.call_deferred()


func _run() -> void:
	var g := FriendGenerator.new(FriendGenerator.MEDIUM, 4242, [], 0)
	puzzle = g.run()
	_check(puzzle != null and puzzle.verify(), "a verified MEDIUM friend puzzle (seed 4242)")
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	for n in range(1, 6):
		game.progress.record_result(n, 1000 + n, 3)
	game.progress.save()
	game.start_level(6)
	await _frames(3)
	game.return_to_main_menu()
	await _frames(3)
	var before := _snapshot()
	var file_before := FileAccess.get_file_as_string(PROGRESS_PATH)
	var classic_ms := game.attempt_timer.elapsed_ms()
	social = game.ui._title._social
	play = social.play
	social.open(game.ui.theme)
	await _frames(3)

	await _test_tools()
	await _test_timer()
	await _test_reveal_unchanged()

	play.end()
	social.close()
	await _frames(3)
	_check(_snapshot() == before, "D. progress (score, coins, stars, unlocks, current level) unchanged")
	_check(FileAccess.get_file_as_string(PROGRESS_PATH) == file_before, "D. the Classic save file was not written")
	_check(game.attempt_timer.elapsed_ms() == classic_ms, "D. the Classic attempt clock did not run during Social play (%d ms)" % game.attempt_timer.elapsed_ms())
	_check(SocialPlay.MAX_UNDOS == 3 and SocialPlay.MAX_HINTS == 2 and SocialPlay.MAX_HAMMERS == 2, "D. SocialPlay defaults unchanged (x3 / x2 / x2)")

	for f in failures:
		print("FAIL " + f)
	print("\n%d passed, %d failed" % [passes, failures.size()])
	print("FRIEND TIMER + TOOLS TEST PASSED" if failures.is_empty() else "FRIEND TIMER + TOOLS TEST FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


func _friend(d: String) -> SharedChallenge:
	return SharedChallenge.friend_challenge(PuzzleDefinition.from_json(puzzle.to_json()), d)


func _start(c: SharedChallenge) -> void:
	play.start(c, SocialPlay.Mode.CREATOR_PREVIEW, game.ui.theme)
	await _frames(3)


## A block that escapes right now and is not the last one.
func _calm_move() -> int:
	for id in play.model.blocks:
		if play.model.move_state(id) == "ok":
			return id
	return -1


# --- A. Tools by difficulty ------------------------------------------------------

func _test_tools() -> void:
	var want := {"easy": [3, 2, 2], "medium": [3, 2, 1], "hard": [3, 1, 1], "very_hard": [3, 1, 0]}
	for d in want:
		var w: Array = want[d]
		var tag := "A. %s" % d.to_upper()
		await _start(_friend(d))
		_check([play.max_undos, play.max_hints, play.max_hammers] == w, "%s: UNDO x%d, SHOW A MOVE x%d, HAMMER x%d" % [tag, w[0], w[1], w[2]])
		_check(play._undo.badge_text == str(w[0]) and play._hint.badge_text == str(w[1]) and play._hammer.badge_text == str(w[2]), "%s: badges %s / %s / %s" % [tag, play._undo.badge_text, play._hint.badge_text, play._hammer.badge_text])
		_check(play._hammer.is_visible_in_tree() and (play._hammer.modulate.a < 0.9) == (w[2] == 0), "%s: Hammer shown%s" % [tag, ", dimmed at 0" if w[2] == 0 else ""])
		# SHOW A MOVE: exactly the allowance, then refused.
		for i in w[1] + 2:
			play.hint()
			play.board.clear_hint()
		_check(play.hints_used == w[1] and play._hint.modulate.a < 0.9 and play._message.text.begins_with("No SHOW A MOVE left"), "%s: SHOW A MOVE stops at %d" % [tag, w[1]])
		# HAMMER: exactly the allowance (safe smashes), then refused.
		for i in w[2] + 2:
			play.toggle_hammer()
			if play.hammer_armed:
				var target := -1
				for id in play.model.blocks:
					if Solver.hammer_safe(play.model, id):
						target = id
						break
				play.tap_block(target)
		_check(play.hammers_used == w[2] and not play.hammer_armed, "%s: HAMMER stops at %d" % [tag, w[2]])
		if w[2] == 0:
			_check(play._message.text == "No Hammer in VERY HARD challenges", "%s: a tap on the Hammer only explains (\"%s\")" % [tag, play._message.text])
		# Enforced in gameplay: an armed Hammer with none left spends nothing.
		var n := play.model.block_count()
		play.hammer_armed = true
		play.tap_block(play.model.blocks.keys()[0])
		_check(play.model.block_count() == n and play.hammers_used == w[2] and not play.hammer_armed, "%s: no smash beyond the allowance, even if armed" % tag)
		# UNDO: moves, then exactly x3.
		for i in 5:
			var id := _calm_move()
			if id != -1 and play.model.block_count() > 2:
				play.tap_block(id)
		var undone := 0
		for i in 5:
			var size_before := play.history.size()
			play.undo()
			if play.history.size() < size_before:
				undone += 1
		_check(undone == w[0] and play.undos_used == w[0] and play._undo.disabled, "%s: UNDO stops at %d (%d undone)" % [tag, w[0], undone])
		# RESTART: unlimited, and every tool is back.
		for i in 12:
			play.restart()
		await _frames(2)
		_check(play.plays == 13 and play.undos_used == 0 and play.hints_used == 0 and play.hammers_used == 0 and play._hint.badge_text == str(w[1]), "%s: 12 RESTARTs allowed, tools back each time" % tag)
	# An unknown difficulty gets the strictest set.
	await _start(_friend("legendary"))
	_check([play.max_undos, play.max_hints, play.max_hammers] == [3, 1, 0], "A. an unknown difficulty gets the strictest tools (x3 / x1 / x0)")


# --- B. Timer --------------------------------------------------------------------

func _test_timer() -> void:
	await _start(_friend("hard"))
	_check(play.is_timed() and play._time.is_visible_in_tree() and play._time.text == "TIME  0:00", "B. the live TIME shows 0:00 at the start (\"%s\")" % play._time.text)
	var f0 := Engine.get_process_frames()
	var u0 := play.time_updates
	await _wait(2.3)
	var t1 := play.timer.elapsed_ms()
	_check(t1 >= 2000 and t1 <= 2600, "B. it runs while playing (%d ms after 2.3 s)" % t1)
	_check(play._time.text == "TIME  0:02", "B. the text follows (\"%s\")" % play._time.text)
	var frames := Engine.get_process_frames() - f0
	_check(play.time_updates - u0 <= 3 and frames > 20, "B. the text changed %d times in %d frames (once per second)" % [play.time_updates - u0, frames])
	# EXIT open: paused.
	play._exit.pressed.emit()
	await _wait(1.2)
	var t2 := play.timer.elapsed_ms()
	_check(t2 - t1 < 150, "B. paused while EXIT is open (+%d ms)" % (t2 - t1))
	play._confirm.find_child("KeepPlaying", true, false).pressed.emit()
	await _wait(1.0)
	var t3 := play.timer.elapsed_ms()
	_check(t3 - t2 >= 800, "B. KEEP PLAYING resumes it (+%d ms)" % (t3 - t2))
	# Hidden page: paused.
	play.set_page_hidden(true)
	await _wait(1.2)
	var t4 := play.timer.elapsed_ms()
	_check(t4 - t3 < 150, "B. paused while the page is hidden (+%d ms)" % (t4 - t3))
	play.set_page_hidden(false)
	await _wait(1.0)
	var t5 := play.timer.elapsed_ms()
	_check(t5 - t4 >= 750, "B. visible again: it resumes (+%d ms)" % (t5 - t4))
	# RESTART: the same session, the clock keeps going.
	var id := _calm_move()
	play.tap_block(id)
	play.restart()
	await _frames(3)
	var t6 := play.timer.elapsed_ms()
	_check(t6 >= t5 and play.final_time_ms == -1 and play._time.text != "TIME  0:00", "B. RESTART keeps the clock (%d ms, \"%s\")" % [t6, play._time.text])
	# Solve: frozen, shown big on the solved screen.
	var guard := 0
	while not play.completed and guard < 200:
		guard += 1
		if not play.play_solver_move():
			break
		await _frames(1)
	_check(play.completed, "B. solved with the Solver's moves")
	var final := play.final_time_ms
	_check(final >= t6 and final == play.timer.elapsed_ms() and play.timer.finished, "B. the time freezes at the solve (%d ms)" % final)
	await _wait(1.6)
	_check(play.timer.elapsed_ms() == final, "B. nothing is added after the solve")
	_check(play.reveal.visible and play.reveal._time_box.visible and play.reveal._time_value.text == UIManager.fmt_time(final)
		and play.reveal._heading.text == "YOU ESCAPED!", "B. the solved screen shows YOUR TIME %s" % play.reveal._time_value.text)
	var tb := play.reveal._time_box.get_global_rect()
	var hd := play.reveal._heading.get_global_rect()
	var vis := play.get_viewport().get_visible_rect()
	_check(tb.position.y >= hd.end.y - 1.0 and vis.encloses(tb), "B. the time sits under the heading, on screen")
	# PLAY AGAIN: a fresh timed run.
	play.reveal.play_again.emit()
	await _frames(3)
	_check(not play.completed and play.final_time_ms == -1 and play.timer.elapsed_ms() < 300 and play._time.text == "TIME  0:00" and not play.reveal.visible,
		"B. PLAY AGAIN starts a fresh timed run (%d ms)" % play.timer.elapsed_ms())
	await _wait(1.1)
	_check(play.timer.elapsed_ms() >= 900, "B. ... and it runs (%d ms)" % play.timer.elapsed_ms())
	# Leaving and starting again: a fresh run too.
	play.end()
	await _start(_friend("easy"))
	_check(play.timer.elapsed_ms() < 300 and play._time.text == "TIME  0:00", "B. a new challenge starts at 0:00")


# --- C. Photo / Message Reveal ------------------------------------------------------

func _test_reveal_unchanged() -> void:
	await _start(_friend("very_hard"))
	var s := CreatorSession.new()
	s.set_message("Happy birthday!")
	s.set_difficulty("hard")
	var c := SharedChallenge.photo_message_reveal(s, PuzzleDefinition.from_json(puzzle.to_json()))
	await _start(c)
	_check([play.max_undos, play.max_hints, play.max_hammers] == [3, 2, 2], "C. Reveal right after a VERY HARD friend challenge: tools x3 / x2 / x2")
	_check(not play.is_timed() and not play._time.is_visible_in_tree(), "C. Reveal: no TIME shown")
	await _wait(1.2)
	var guard := 0
	while not play.completed and guard < 200:
		guard += 1
		if not play.play_solver_move():
			break
		await _frames(1)
	await _wait(1.2)
	_check(play.completed and play.final_time_ms == -1, "C. Reveal solved: no final time recorded")
	_check(play.reveal.visible and not play.reveal._time_box.visible and play.reveal._message_card.visible, "C. Reveal: the message, no time on the reveal")


func _snapshot() -> String:
	var p := game.progress
	return var_to_str([p.coins, p.best_scores, p.best_stars, p.highest_unlocked, p.highest_completed,
		p.current_level, p.inventory, p.total_score(), p.total_stars(), p.tips_seen, p.achievements])


func _check(cond: bool, msg: String) -> void:
	if cond:
		passes += 1
		print("PASS " + msg)
	else:
		failures.append(msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
