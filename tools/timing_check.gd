extends Node
## TIMING + PERSONAL BEST checks (headless, its own save files only):
##   godot --headless --path . res://tools/TimingCheck.tscn
## A. AttemptTimer: start / stop, active-only accumulation, the frame cap,
##    a hidden page (nothing added, the first frame back dropped), finish.
## B. PlayerProgress time records: first time, faster, slower, assisted vs
##    clean (independent), replays improve, invalid times never recorded,
##    save / reload, a save without times, invalid stored values, merge
##    (backup restore and the embed -> own-tab transfer share merge_from),
##    backup code round trip, unrelated fields untouched.
## C. The real game (GameManager): the clock runs only while the board is
##    playable (not under the title, NEW MECHANIC card, Settings, Shop,
##    Level Select, the out-of-hearts beat or after the win); the winning
##    move records the attempt; Restart, retry and leaving reset it with no
##    record; Hint / Undo / Hammer make an attempt assisted; replays improve
##    both records; the card shows the time line; records survive a reload.

const SAVE := "user://timing_check_progress.cfg"
var passed := 0
var failures: Array[String] = []
var _done: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		print("FAIL: " + what)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_timer_unit()
	_records()
	await _game()
	_check(_done == ["timer", "records", "game"], "every section ran to its end (%s)" % [_done])
	_wipe(SAVE)
	_wipe("user://timing_check_a.cfg")
	_wipe("user://timing_check_b.cfg")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	if failures.is_empty():
		print("TIMING CHECKS PASSED")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


static func _wipe(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


# --- A. AttemptTimer -----------------------------------------------------------

func _timer_unit() -> void:
	var t := AttemptTimer.new()
	_check(t.elapsed_ms() == 0 and not t.finished and not t.page_hidden, "a new timer is at 0")
	t.tick(0.1, true)
	t.tick(0.1, true)
	_check(t.elapsed_ms() == 200, "active frames add up (%d ms)" % t.elapsed_ms())
	t.tick(0.5, false)
	_check(t.elapsed_ms() == 200, "inactive frames add nothing")
	t.tick(3.0, true)
	_check(t.elapsed_ms() == 450, "one long frame adds at most %.2f s (%d ms)" % [AttemptTimer.MAX_FRAME, t.elapsed_ms()])
	t.tick(-1.0, true)
	t.tick(0.0, true)
	_check(t.elapsed_ms() == 450, "zero / negative frames add nothing")
	t.set_page_hidden(true)
	for i in 10:
		t.tick(0.1, true)
	_check(t.elapsed_ms() == 450, "while the page is hidden nothing is added")
	t.set_page_hidden(false)
	t.tick(0.25, true)
	_check(t.elapsed_ms() == 450, "the first frame after the page is visible again is dropped (it spans the hidden time)")
	t.tick(0.05, true)
	_check(t.elapsed_ms() == 500, "then active time adds up again (%d ms)" % t.elapsed_ms())
	t.set_page_hidden(false)
	t.tick(0.05, true)
	_check(t.elapsed_ms() == 550, "a repeated 'visible' signal drops no frame")
	var ms := t.finish()
	t.tick(0.1, true)
	_check(ms == 550 and t.elapsed_ms() == 550 and t.finished, "finish() freezes the attempt (%d ms)" % ms)
	t.reset()
	_check(t.elapsed_ms() == 0 and not t.finished, "reset() starts a fresh attempt")
	t.tick(0.0004, true)
	_check(t.elapsed_ms() == 0, "under half a millisecond rounds to 0 ms (never recorded)")
	_done.append("timer")


# --- B. Records and saves --------------------------------------------------------

func _records() -> void:
	_wipe("user://timing_check_a.cfg")
	var p := PlayerProgress.new("user://timing_check_a.cfg").load_from_disk()
	_check(p.best_time(1) == 0 and p.best_clean_time(1) == 0, "no record = 0 (no recorded time)")
	var r := p.record_time(1, 5000, true)
	_check(r["new_best_time"] and r["new_clean_time"] and r["best_before"] == 0 and p.best_time(1) == 5000 and p.best_clean_time(1) == 5000,
		"first clean clear: BEST and BEST CLEAN = 5000")
	r = p.record_time(1, 6000, true)
	_check(not r["new_best_time"] and not r["new_clean_time"] and p.best_time(1) == 5000 and p.best_clean_time(1) == 5000, "a slower clean clear changes nothing")
	r = p.record_time(1, 3000, false)
	_check(r["new_best_time"] and not r["new_clean_time"] and p.best_time(1) == 3000 and p.best_clean_time(1) == 5000,
		"a faster ASSISTED clear improves BEST only (clean record kept)")
	r = p.record_time(1, 2500, false)
	_check(p.best_time(1) == 2500 and p.best_clean_time(1) == 5000, "another faster assisted clear never erases the clean record")
	r = p.record_time(1, 4000, true)
	_check(not r["new_best_time"] and r["new_clean_time"] and p.best_time(1) == 2500 and p.best_clean_time(1) == 4000,
		"a faster clean clear improves BEST CLEAN only when BEST is already faster")
	r = p.record_time(1, 2000, true)
	_check(r["new_best_time"] and r["new_clean_time"] and p.best_time(1) == 2000 and p.best_clean_time(1) == 2000, "a clean clear can improve both")
	p.record_time(2, 7000, false)
	_check(p.best_time(2) == 7000 and p.best_clean_time(2) == 0, "an assisted first clear: BEST only, no clean time")
	for bad in [0, -5, PlayerProgress.MAX_TIME_MS + 1]:
		var rb := p.record_time(3, bad, true)
		_check(not rb["new_best_time"] and p.best_time(3) == 0 and p.best_clean_time(3) == 0, "an invalid time (%d) is never recorded" % bad)
	p.record_time(0, 1000, true)
	_check(not p.best_times.has(0), "level 0 is never recorded")
	# Unrelated fields: untouched by records.
	p.coins = 777
	p.inventory = {"hint": 4, "hammer": 2}
	p.record_result(1, 5000, 3, true)
	p.record_result(2, 4000, 2, false)
	var before := _fields(p)
	p.record_time(1, 1500, true)
	_check(_fields(p) == before, "recording a time changes no other field")
	p.save()
	# Save / reload.
	var text := FileAccess.get_file_as_string("user://timing_check_a.cfg")
	_check(text.contains("[times]") and text.contains("[clean_times]"), "the save holds [times] and [clean_times]")
	var q := PlayerProgress.new("user://timing_check_a.cfg").load_from_disk()
	_check(q.best_times == p.best_times and q.clean_times == p.clean_times, "save / reload keeps both records (%s / %s)" % [q.best_times, q.clean_times])
	_check(_fields(q) == _fields(p), "save / reload keeps every other field")
	# A save from before timing (no sections): loads unchanged, no times.
	var old_text := "[meta]\n\nversion=5\nseq=9\n\n[progress]\n\ncurrent_level=12\nhighest_completed=11\nhighest_unlocked=12\n\n[economy]\n\ncoins=345\ninventory={\"hint\": 2, \"hammer\": 1}\n\n[chapters]\n\ntips_seen=[\"lesson_lock\"]\n\n[scores]\n\n1=5000\n2=4800\n\n[stars]\n\n1=3\n2=2\n"
	var o := PlayerProgress.from_text(old_text)
	_check(o != null and o.best_times.is_empty() and o.clean_times.is_empty() and o.highest_completed == 11 and o.coins == 345 and o.best_scores == {1: 5000, 2: 4800} and o.inventory["hammer"] == 1,
		"a save without timing fields loads unchanged, with no times")
	_wipe("user://timing_check_b.cfg")
	var fb := FileAccess.open("user://timing_check_b.cfg", FileAccess.WRITE)
	fb.store_string(old_text)
	fb.close()
	var ob := PlayerProgress.new("user://timing_check_b.cfg").load_from_disk()
	var ob_fields := _fields(ob)
	ob.save()
	var ob2 := PlayerProgress.new("user://timing_check_b.cfg").load_from_disk()
	_check(_fields(ob2) == ob_fields and not FileAccess.get_file_as_string("user://timing_check_b.cfg").contains("[times]"),
		"an old save saved again: same fields, no empty timing sections added")
	# Invalid stored values are "no recorded time".
	var bad_text := old_text + "\n[times]\n\n1=0\n2=-5\n3=\"abc\"\n4=999999999999\n5=1500\nx=100\n6=2500.7\n\n[clean_times]\n\n5=1200\n7=0\n"
	var bq := PlayerProgress.from_text(bad_text)
	_check(bq.best_times == {5: 1200, 6: 2500} and bq.clean_times == {5: 1200},
		"invalid stored times are dropped; a clean time faster than BEST becomes BEST (%s / %s)" % [bq.best_times, bq.clean_times])
	# Merge (backup restore and the embed -> own-tab transfer both use it).
	var a := PlayerProgress.from_text(old_text)
	a.best_times = {1: 5000, 2: 3000, 4: 9000}
	a.clean_times = {1: 6000, 4: 9000}
	var b := PlayerProgress.from_text(old_text)
	b.best_times = {1: 4000, 2: 3500, 3: 7000}
	b.clean_times = {1: 6500, 3: 7000, 2: 3200}
	b.best_times[5] = 0
	b.clean_times[6] = -1
	a.merge_from(b)
	_check(a.best_times == {1: 4000, 2: 3000, 3: 7000, 4: 9000}, "merge: the smaller valid BEST of each level wins (%s)" % a.best_times)
	_check(a.clean_times == {1: 6000, 2: 3200, 3: 7000, 4: 9000}, "merge: the smaller valid BEST CLEAN of each level wins (%s)" % a.clean_times)
	_check(not a.best_times.has(5) and not a.clean_times.has(6), "merge: invalid times never become records")
	var c := PlayerProgress.from_text(old_text)
	c.best_times = {1: 2000}
	c.clean_times = {1: 2000}
	var d := PlayerProgress.from_text(old_text)
	c.merge_from(d)
	_check(c.best_times == {1: 2000} and c.clean_times == {1: 2000}, "merge: a save without times never removes records")
	# Backup code round trip -> merge (the RESTORE path).
	var code := q.backup_code()
	var restored := PlayerProgress.from_text(PlayerProgress.decode_backup(code))
	var fresh := PlayerProgress.from_text(old_text)
	fresh.merge_from(restored)
	_check(fresh.best_times == q.best_times and fresh.clean_times == q.clean_times, "a backup code carries both records into a restore")
	_wipe("user://timing_check_a.cfg")
	_wipe("user://timing_check_b.cfg")
	_done.append("records")


static func _fields(p: PlayerProgress) -> String:
	return JSON.stringify([p.current_level, p.highest_completed, p.highest_unlocked, p.best_scores, p.best_stars, p.perfect_levels, p.coins,
		p.inventory, p.claimed_chests, p.completed_chapters, p.reward_blocks, p.chapter_coins, p.tips_seen, p.achievements,
		p.music_on, p.sfx_on, p.haptics_on])


# --- C. The real game ----------------------------------------------------------------

var game: GameManager


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Clears the board with the Solver's moves, tapped as a player would (a
## tap while a tip shows only hides it, as in the game).
func _solve() -> void:
	for i in 80:
		if game.completed or game.model.is_empty():
			return
		var id := Solver.from_model(game.model).recommend_move()
		if id < 0:
			return
		game._on_block_tapped(id)
		await _frames(1)


## Starts level n as a fresh attempt with no tip / lesson in the way.
func _start(n: int) -> void:
	game.start_level(n, "select")
	await _frames(2)
	game.tutorial.hide_hint(true)
	game._lesson = ""
	game.board.set_marks([])


## Plays level n with `secs` of simulated active time, returns the record.
func _clear(n: int, secs: float, assist: String = "") -> Dictionary:
	await _start(n)
	match assist:
		"hint":
			game.progress.inventory["hint"] = 5
			game.request_hint()
		"undo":
			var id := Solver.from_model(game.model).recommend_move()
			game._on_block_tapped(id)
			await _frames(1)
			game.undo()
		"hammer":
			game.progress.inventory["hammer"] = 3
			game.toggle_hammer()
			var target := -1
			for bid in game.model.blocks:
				if game.is_hammer_safe(bid) and not game.model.blocks[bid].is_crate():
					target = bid
					break
			game._on_block_tapped(target)
			await _frames(1)
	game.attempt_timer.elapsed = secs
	await _solve()
	return game.last_time_result


func _near(ms: int, secs: float) -> bool:
	return ms >= int(secs * 1000.0) and ms <= int(secs * 1000.0) + 1500


func _game() -> void:
	PlayerProgress.default_path = SAVE
	_wipe(SAVE)
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	# Under the title (launch): no clock.
	_check(game.ui.is_title_open() and not game._attempt_active(), "under the title the clock does not run")
	var e0 := game.attempt_timer.elapsed_ms()
	await _frames(20)
	_check(game.attempt_timer.elapsed_ms() == e0, "no time adds up behind the title")
	game._hide_title()
	await _start(1)
	_check(game._attempt_active(), "a playable board runs the clock")
	var e1 := game.attempt_timer.elapsed
	var w1 := Time.get_ticks_msec()
	await _frames(20)
	var wall := (Time.get_ticks_msec() - w1) / 1000.0
	var got := game.attempt_timer.elapsed - e1
	_check(got > 0.0 and absf(got - wall) <= 0.05, "real frames add active time: the real clock (%.3f s counted, %.3f s on the clock)" % [got, wall])
	# Blocking menus.
	for menu in ["settings", "shop", "levels"]:
		match menu:
			"settings": game.ui._open_settings()
			"shop": game.open_shop()
			"levels": game.open_level_select()
		await _frames(2)
		var before := game.attempt_timer.elapsed
		await _frames(20)
		_check(not game._attempt_active() and game.attempt_timer.elapsed == before, "%s open: the clock stops" % menu)
		match menu:
			"settings": game.ui._close_settings()
			"shop": game.ui._shop.close()
			"levels": game.ui._level_select.close()
		await _frames(2)
		_check(game._attempt_active(), "%s closed: the clock runs again" % menu)
	# Hidden page.
	game.attempt_timer.set_page_hidden(true)
	var h0 := game.attempt_timer.elapsed
	await _frames(20)
	_check(game.attempt_timer.elapsed == h0, "a hidden page adds no time")
	game.attempt_timer.set_page_hidden(false)
	await _frames(5)
	_check(game.attempt_timer.elapsed > h0, "visible again: the clock runs again")
	# 1st clear, clean, ~5 s.
	var r := await _clear(1, 5.0)
	_check(game.completed and _near(r.get("time_ms", 0), 5.0) and r["clean"] and r["new_best_time"] and r["best_before"] == 0,
		"Level 1 cleared clean: %d ms recorded (first time)" % r.get("time_ms", 0))
	var t1: int = r["time_ms"]
	_check(game.progress.best_time(1) == t1 and game.progress.best_clean_time(1) == t1, "BEST and BEST CLEAN = the first clean time")
	var frozen := game.attempt_timer.elapsed_ms()
	await _frames(30)
	_check(game.attempt_timer.elapsed_ms() == frozen and not game._attempt_active(), "after the winning move the clock is frozen (celebration / card not counted)")
	for i in 120:
		if game.ui.is_complete_visible():
			break
		await _frames(2)
	_check(game.ui._card_time.text == "TIME %s" % UIManager.fmt_time(t1) and game.ui._card_time.visible,
		"the first card shows the time alone: '%s'" % game.ui._card_time.text)
	_check(game.ui._card_reward.visible and game.ui._card_total.text.begins_with("LEVEL SCORE"), "LEVEL SCORE / LEVEL BEST unchanged on the card")
	# Replay slower (clean): no record.
	r = await _clear(1, 9.0)
	_check(not r["new_best_time"] and not r["new_clean_time"] and game.progress.best_time(1) == t1, "a slower replay changes no record")
	for i in 120:
		if game.ui.is_complete_visible():
			break
		await _frames(2)
	_check(game.ui._card_time.text == "TIME %s   ·   BEST %s" % [UIManager.fmt_time(r["time_ms"]), UIManager.fmt_time(t1)], "card: '%s'" % game.ui._card_time.text)
	# Replay faster with a hint: BEST only.
	r = await _clear(1, 3.0, "hint")
	_check(not r["clean"] and r["new_best_time"] and not r["new_clean_time"] and game.progress.best_clean_time(1) == t1 and game.progress.best_time(1) == r["time_ms"],
		"a faster replay with a Hint improves BEST only (assisted)")
	for i in 120:
		if game.ui.is_complete_visible():
			break
		await _frames(2)
	_check(game.ui._card_time.text.ends_with("NEW BEST TIME!"), "card: '%s'" % game.ui._card_time.text)
	var tb: int = r["time_ms"]
	# Undo and Hammer also make an attempt assisted.
	r = await _clear(1, 2.0, "undo")
	_check(not r["clean"] and game.progress.best_clean_time(1) == t1 and game.progress.best_time(1) == r["time_ms"] and r["time_ms"] < tb,
		"an Undo makes the attempt assisted (BEST improves, BEST CLEAN kept)")
	await _start(6)
	r = await _clear(6, 4.0, "hammer")
	_check(r.get("time_ms", 0) > 0 and not r["clean"] and game.progress.best_time(6) == r["time_ms"] and game.progress.best_clean_time(6) == 0,
		"a Hammer makes the attempt assisted (no clean time for Level 6)")
	# A faster clean replay improves BEST CLEAN (and BEST when faster).
	r = await _clear(1, 1.0)
	_check(r["clean"] and r["new_clean_time"] and r["new_best_time"] and game.progress.best_clean_time(1) == r["time_ms"] and game.progress.best_time(1) == r["time_ms"],
		"a faster clean replay improves BEST CLEAN and BEST")
	# Restart resets the attempt; no record from the abandoned one.
	await _start(2)
	game.request_hint()
	game.attempt_timer.elapsed = 7.0
	game.restart()
	await _frames(1)
	_check(game.attempt_timer.elapsed < 0.5 and not game.attempt_assisted and game.progress.best_time(2) == 0, "Restart: a fresh attempt (time ~0, not assisted), nothing recorded")
	# Leaving an unfinished level records nothing.
	game.attempt_timer.elapsed = 6.0
	await _start(3)
	_check(game.progress.best_time(2) == 0 and game.attempt_timer.elapsed < 0.5, "leaving a level unfinished records nothing; the next level starts at 0")
	# Out of hearts: the beat stops the clock, the retry is a fresh attempt.
	await _start(6)
	_check(game.max_hearts > 0, "Level 6 has hearts")
	game.attempt_timer.elapsed = 8.0
	var lost := false
	for i in 12:
		if game.game_over:
			lost = true
			break
		var blocked := -1
		for bid in game.model.blocks:
			if game.model.move_state(bid) == "blocked":
				blocked = bid
				break
		if blocked < 0:
			break
		game._on_block_tapped(blocked)
		await _frames(1)
	_check(lost and not game._attempt_active(), "out of hearts: the clock stops during the beat")
	var b6 := game.progress.best_time(6)
	for i in 200:
		if not game.game_over:
			break
		await _frames(2)
	_check(not game.game_over and game.attempt_timer.elapsed < 0.5 and game.progress.best_time(6) == b6, "the retry is a fresh attempt; the failed one recorded nothing")
	# NEW MECHANIC card: no clock until it is gone.
	game.progress.tips_seen.erase("intro_portal")
	game.progress.highest_completed = 200
	game.start_level(201, "select")
	await _frames(2)
	_check(game.mechanic_intro != null and not game._attempt_active(), "NEW MECHANIC card open: the clock does not run")
	var m0 := game.attempt_timer.elapsed
	await _frames(20)
	_check(game.attempt_timer.elapsed == m0, "no time adds up under the NEW MECHANIC card")
	for i in 300:
		if game.mechanic_intro == null:
			break
		await _frames(2)
	await _frames(3)
	_check(game._attempt_active() and game.attempt_timer.elapsed > m0, "the card gone: the clock runs")
	# Records survive a reload from disk.
	var reload := PlayerProgress.new(SAVE).load_from_disk()
	_check(reload.best_times == game.progress.best_times and reload.clean_times == game.progress.clean_times and reload.best_time(1) > 0,
		"records survive a reload (%s / %s)" % [reload.best_times, reload.clean_times])
	game.queue_free()
	await _frames(2)
	_done.append("game")
