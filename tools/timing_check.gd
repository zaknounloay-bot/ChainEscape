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
		if OS.get_cmdline_user_args().has("--verbose"):
			print("ok: " + what)
	else:
		failures.append(what)
		print("FAIL: " + what)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_timer_unit()
	_cap_unit()
	_records()
	await _game()
	await _cap_game()
	_check(_done == ["timer", "cap", "records", "game", "cap_game"], "every section ran to its end (%s)" % [_done])
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


# --- A2. Frame-cap accounting (Phase 3B-A) ---------------------------------------

## Plays `frames` frames of `delta` seconds; returns [shown ms, discarded ms].
static func _run_frames(t: AttemptTimer, delta: float, frames: int, active := true) -> Array:
	for i in frames:
		t.tick(delta, active)
	return [t.elapsed_ms(), t.discarded_ms()]


func _cap_unit() -> void:
	var t := AttemptTimer.new()
	_check(t.cap_info() == {"discarded_ms": 0, "capped_frames": 0, "longest_frame_ms": 0, "start_frame_ms": 0}, "a new timer has no cap metadata")
	# The attempt's first active frame (level build / first render) is kept
	# apart: never discarded time, shown time as before (at most MAX_FRAME).
	t.tick(2.0, true)
	t.tick(1.0 / 60.0, true)
	_check(t.elapsed_ms() == 267 and t.discarded_ms() == 0 and t.capped_frames == 0 and t.cap_info()["start_frame_ms"] == 2000,
		"a 2 s first frame (level load): start_frame 2000 ms, nothing discarded, %d ms shown (as before)" % t.elapsed_ms())
	t.tick(2.0, true)
	_check(t.discarded_ms() == 1750 and t.capped_frames == 1, "a later 2 s frame is discarded time")
	# Normal frame rates: 60 / 30 fps (and 4 fps = exactly the cap) lose nothing.
	for fps in [60.0, 30.0, 4.0]:
		t.reset()
		var r := _run_frames(t, 1.0 / fps, int(fps * 10.0))
		_check(r[1] == 0 and t.capped_frames == 0 and absi(r[0] - 10000) <= 2, "%d fps for 10 s: %d ms shown, nothing discarded" % [int(fps), r[0]])
	# Low frame rates: everything above 250 ms per frame is discarded, and only that.
	t.reset()
	t.tick(1.0 / 60.0, true)  # the start frame
	var r3 := _run_frames(t, 1.0 / 3.0, 30)
	_check(r3[0] == 7517 and absi(r3[1] - 2500) <= 1 and t.capped_frames == 30 and t.cap_info()["longest_frame_ms"] == 333,
		"3 fps for 10 s: %d ms shown (unchanged rule), %d ms discarded, 30 capped frames" % [r3[0], r3[1]])
	_check(absi(r3[0] + r3[1] - 10017) <= 1, "shown + discarded = the real active time")
	# One stall in otherwise smooth play.
	t.reset()
	_run_frames(t, 1.0 / 60.0, 300)
	t.tick(2.0, true)
	_run_frames(t, 1.0 / 60.0, 300)
	_check(t.elapsed_ms() == 10250 and t.discarded_ms() == 1750 and t.capped_frames == 1 and t.cap_info()["longest_frame_ms"] == 2000,
		"a 2 s stall: shown %d ms (was and stays capped), discarded %d ms" % [t.elapsed_ms(), t.discarded_ms()])
	# Pauses (inactive frames) never count as lost time, however long.
	t.reset()
	t.tick(30.0, false)
	t.tick(5.0, false)
	_check(t.elapsed_ms() == 0 and t.discarded_ms() == 0 and t.capped_frames == 0 and t.cap_info()["start_frame_ms"] == 0, "Shop / Settings / card pauses: no time and no discarded time (nor a start frame)")
	# Background / resume (Safari-style): the hidden span and the first frame back add nothing.
	t.reset()
	_run_frames(t, 1.0 / 60.0, 60)
	t.set_page_hidden(true)
	t.tick(0.016, true)
	t.set_page_hidden(false)
	t.tick(45.0, true)  # Safari's first frame after resuming spans the whole background time
	t.tick(1.0 / 60.0, true)
	_check(t.discarded_ms() == 0 and t.capped_frames == 0 and t.elapsed_ms() == 1017, "background + resume: the 45 s resume frame is dropped, not discarded (%d ms)" % t.elapsed_ms())
	# A long frame right after resuming (the second frame) does count.
	t.tick(0.5, true)
	_check(t.discarded_ms() == 250 and t.capped_frames == 1, "a long frame after the resume frame is discarded time (%d ms)" % t.discarded_ms())
	# Finished: nothing more; reset: a fresh attempt starts at zero.
	t.finish()
	t.tick(3.0, true)
	_check(t.discarded_ms() == 250 and t.capped_frames == 1, "after finish() nothing more is counted")
	t.reset()
	_check(t.cap_info() == {"discarded_ms": 0, "capped_frames": 0, "longest_frame_ms": 0, "start_frame_ms": 0} and t.elapsed_ms() == 0, "reset() clears the cap metadata (restart / replay / NEXT)")
	_done.append("cap")


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


## LIVE TIMER HUD (QA / dev builds): TIME under TOTAL SCORE, BEST under the
## coins - fed by AttemptTimer only, text only when the second changes.
func _live_hud() -> void:
	var ui: UIManager = game.ui
	_check(BuildFlags.live_timer_hud() and game._live_timer, "live timer HUD is on outside the player build")
	var records := [game.progress.best_times.duplicate(), game.progress.clean_times.duplicate()]
	await _start(7)
	var st: Dictionary = ui.live_timer_state()
	_check(st["time_caption"] == "TIME" and st["best_caption"] == "MY BEST" and st["caption_size"] == 27 and st["value_size"] == 34
		and ui._hud_time_caption.get_theme_font_size("font_size") == 27 and ui._hud_time_value.get_theme_font_size("font_size") == 34,
		"layout C: captions TIME / MY BEST 27, values 34")
	_check(ui._hearts.heart_size == 44.0 and ui._hearts.gap == 15.0, "layout C: hearts 44, gap 15")
	_check(ui._coin_pill.get_global_rect().get_center().x < ui.get_viewport().get_visible_rect().size.x * 0.5
		and ui._coin_pill.get_global_rect().position.y >= ui._hud_total.get_global_rect().end.y,
		"layout C: the coin pill sits under TOTAL SCORE (left)")
	# Layout C: no CHAIN popup - but the chain, its escape bonus and the score
	# work exactly as before.
	var pts0: int = game.escape_points
	var esc := 0
	for i in 3:
		var mv := Solver.from_model(game.model).recommend_move()
		if mv < 0 or game.model.move_state(mv) != "ok":
			break
		var c_before: int = game.chain
		game._on_block_tapped(mv)
		await _frames(1)
		if game.chain == c_before + 1:
			esc += 1
	var want := 0
	for c in range(1, esc + 1):
		want += ScoreRules.escape_points(c)
	st = ui.live_timer_state()
	_check(esc >= 2 and game.chain == esc and game.escape_points - pts0 == want and not st["chain_visible"] and ui._chain_label.modulate.a == 0.0,
		"layout C: a %d-escape chain scores %d (ScoreRules), the CHAIN popup stays hidden" % [esc, game.escape_points - pts0])
	await _start(7)
	st = ui.live_timer_state()
	_check(st["visible"] and st["time"] == "0:00" and st["best"] == UIManager.NO_BEST_TEXT and game.progress.best_time(7) == 0,
		"new attempt: TIME 0:00, BEST shows a dash (no record yet): %s / %s" % [st["time"], st["best"]])
	# The text follows AttemptTimer; only whole seconds change it.
	game.attempt_timer.elapsed = 64.4
	await _frames(2)
	_check(ui._hud_time_value.text == UIManager.fmt_time(game.attempt_timer.elapsed_ms()) and ui._hud_time_value.text == "1:04",
		"TIME shows AttemptTimer as M:SS (%s at %d ms)" % [ui._hud_time_value.text, game.attempt_timer.elapsed_ms()])
	var u0 := ui.live_time_updates
	var s0 := game.attempt_timer.elapsed_ms() / 1000
	var w0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w0 < 2300:
		await _frames(1)
	var s1 := game.attempt_timer.elapsed_ms() / 1000
	var frames_ok := ui.live_time_updates - u0 == s1 - s0 and s1 - s0 >= 2
	_check(frames_ok, "the text changed once per visible second (%d updates over %d seconds, every frame ticked)" % [ui.live_time_updates - u0, s1 - s0])
	# Frozen while the clock is paused (Settings open).
	ui._open_settings()
	await _frames(2)
	var frozen := ui._hud_time_value.text
	var u1 := ui.live_time_updates
	await _frames(30)
	_check(ui._hud_time_value.text == frozen and ui.live_time_updates == u1 and not game._attempt_active(), "Settings open: TIME frozen at %s" % frozen)
	ui._close_settings()
	await _frames(2)
	# Hint, Undo, Hammer: the clock and the HUD keep running, nothing else changes.
	game.progress.inventory["hint"] = 5
	game.request_hint()
	var e_h := game.attempt_timer.elapsed
	await _frames(10)
	_check(game.attempt_timer.elapsed > e_h and ui._hud_time_value.text == UIManager.fmt_time(game.attempt_timer.elapsed_ms()) and ui.live_timer_state()["visible"],
		"after Show a Move the HUD keeps running (%s)" % ui._hud_time_value.text)
	game._clear_hint()
	var id := Solver.from_model(game.model).recommend_move()
	game._on_block_tapped(id)
	await _frames(2)
	game.undo()
	var e_u := game.attempt_timer.elapsed
	await _frames(10)
	_check(game.attempt_timer.elapsed > e_u and ui._hud_time_value.text == UIManager.fmt_time(game.attempt_timer.elapsed_ms()), "after Undo the HUD keeps running")
	game.progress.inventory["hammer"] = 3
	game.toggle_hammer()
	var target := -1
	for bid in game.model.blocks:
		if game.is_hammer_safe(bid) and not game.model.blocks[bid].is_crate():
			target = bid
			break
	game._on_block_tapped(target)
	var e_m := game.attempt_timer.elapsed
	await _frames(10)
	_check(target >= 0 and game.hammers_used == 1 and game.attempt_timer.elapsed > e_m and ui._hud_time_value.text == UIManager.fmt_time(game.attempt_timer.elapsed_ms()),
		"after the Hammer the HUD keeps running")
	_check(game.progress.best_times == records[0] and game.progress.clean_times == records[1], "the HUD never touches the stored records")
	# Restart: a fresh attempt at 0:00; BEST unchanged.
	game.restart()
	await _frames(1)
	st = ui.live_timer_state()
	_check(st["time"] == "0:00" and st["best"] == UIManager.NO_BEST_TEXT, "Restart: TIME back to 0:00 at once, BEST still a dash")
	# A clear: the HUD shows the final time = the card's TIME; BEST = the record.
	game.tutorial.hide_hint(true)
	game.attempt_timer.elapsed = 12.3
	await _solve()
	for i in 120:
		if ui.is_complete_visible():
			break
		await _frames(2)
	await _frames(20)
	var tr: Dictionary = game.last_time_result
	st = ui.live_timer_state()
	var tp: Dictionary = ui.time_panel_state()
	_check(game.completed and st["time"] == UIManager.fmt_time(tr["time_ms"]) and st["time"] == tp["time"] and st["best"] == UIManager.fmt_time(game.progress.best_time(7)),
		"after the clear: HUD TIME %s = card TIME %s, BEST %s = the stored record" % [st["time"], tp["time"], st["best"]])
	_check(not st["visible"] and tp["visible"], "the result card open: the live HUD steps aside (the card shows the times)")
	# Replay: 0:00, BEST shows the record.
	game.start_level(7, "replay")
	await _frames(2)
	st = ui.live_timer_state()
	_check(st["visible"] and st["time"] == "0:00" and st["best"] == UIManager.fmt_time(game.progress.best_time(7)) and game.progress.best_time(7) > 0,
		"Replay: the HUD is back - TIME 0:00, BEST %s" % st["best"])
	# A hearts level: the HUD sits in the empty corners - no overlap with the
	# hearts, TOTAL SCORE, the coins, the title / chapter line or the board.
	await _start(6)
	await _frames(3)
	st = ui.live_timer_state()
	var vis := ui.get_viewport().get_visible_rect().size
	var frac := func(r: Rect2) -> Rect2: return Rect2(r.position / vis, r.size / vis)
	var tr_r := Rect2(Vector2(st["time_rect"][0], st["time_rect"][1]), Vector2(st["time_rect"][2] - st["time_rect"][0], st["time_rect"][3] - st["time_rect"][1]))
	var br_r := Rect2(Vector2(st["best_rect"][0], st["best_rect"][1]), Vector2(st["best_rect"][2] - st["best_rect"][0], st["best_rect"][3] - st["best_rect"][1]))
	var others := {"hearts": ui._hearts.get_global_rect(), "total score": ui._hud_total_value.get_global_rect(), "coins": ui._coin_pill.get_global_rect(),
		"level title": ui._level_label.get_global_rect(), "chapter line": ui._name_label.get_global_rect(), "board": Rect2(game.board.global_position - Vector2.ONE * game.board.cell_size * Board.PADDING_CELLS,
			Vector2(game.board.columns + 2 * Board.PADDING_CELLS, game.board.rows + 2 * Board.PADDING_CELLS) * game.board.cell_size)}
	var hits := []
	for k in others:
		var o: Rect2 = frac.call(others[k])
		if o.size.x > 0 and (o.intersects(tr_r) or o.intersects(br_r)):
			hits.append(k)
	_check(game.max_hearts > 0 and st["visible"] and hits.is_empty() and tr_r.position.x >= 0 and br_r.end.x <= 1.0,
		"hearts level 6: TIME / MY BEST overlap nothing, the board included (%s)" % [hits])
	# NEW MECHANIC card: the HUD is at 0:00 and frozen until the card is gone.
	game.progress.tips_seen.erase("intro_sequence")
	game.progress.tips_seen.append("lesson_sequence")
	game.progress.highest_completed = 225  # the card is for players arriving at 226
	game.start_level(226, "select")
	await _frames(2)
	var m := ui._hud_time_value.text
	await _frames(20)
	_check(game.mechanic_intro != null and m == "0:00" and ui._hud_time_value.text == "0:00", "NEW MECHANIC card: TIME stays 0:00")
	for i in 300:
		if game.mechanic_intro == null:
			break
		await _frames(2)
	var w2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - w2 < 1300:
		await _frames(1)
	_check(game._attempt_active() and ui._hud_time_value.text != "0:00", "the card gone: TIME runs (%s)" % ui._hud_time_value.text)


## Taps the block the lesson's finger points at until the lesson ends.
func _follow_lesson() -> int:
	var taps := 0
	for i in 30:
		if game._lesson == "" or game.completed:
			break
		var id := -1
		for bid in game.model.blocks:
			if game.board._views.has(bid) and game.board._views[bid].hinted:
				id = bid
				break
		if id < 0:
			await _frames(5)
			continue
		game._on_block_tapped(id)
		taps += 1
		await _frames(2)
	return taps


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
	_check(game.ui.time_summary == "TIME %s" % UIManager.fmt_time(t1) and game.ui._time_panel.visible,
		"the first card shows the time alone: '%s'" % game.ui.time_summary)
	var tp: Dictionary = game.ui.time_panel_state()
	_check(tp["visible"] and not tp["banner"] and not tp["record"] and tp["time"] == UIManager.fmt_time(t1) and tp["best_caption"] == "PERSONAL BEST" and tp["best"] == UIManager.fmt_time(t1),
		"timing block, first time: TIME %s | PERSONAL BEST %s, no record banner" % [tp["time"], tp["best"]])
	_check(game.ui._card_reward.visible and game.ui._card_total.text.begins_with("LEVEL SCORE"), "LEVEL SCORE / LEVEL BEST unchanged on the card")
	# Replay slower (clean): no record.
	r = await _clear(1, 9.0)
	_check(not r["new_best_time"] and not r["new_clean_time"] and game.progress.best_time(1) == t1, "a slower replay changes no record")
	for i in 120:
		if game.ui.is_complete_visible():
			break
		await _frames(2)
	_check(game.ui.time_summary == "TIME %s   ·   BEST %s" % [UIManager.fmt_time(r["time_ms"]), UIManager.fmt_time(t1)], "card: '%s'" % game.ui.time_summary)
	tp = game.ui.time_panel_state()
	_check(tp["visible"] and not tp["banner"] and not tp["record"] and tp["time"] == UIManager.fmt_time(r["time_ms"]) and tp["best_caption"] == "PERSONAL BEST" and tp["best"] == UIManager.fmt_time(t1),
		"timing block, slower replay: TIME %s | PERSONAL BEST %s (the stored record), neutral" % [tp["time"], tp["best"]])
	# Replay faster with a hint: BEST only.
	r = await _clear(1, 3.0, "hint")
	_check(not r["clean"] and r["new_best_time"] and not r["new_clean_time"] and game.progress.best_clean_time(1) == t1 and game.progress.best_time(1) == r["time_ms"],
		"a faster replay with a Hint improves BEST only (assisted)")
	for i in 120:
		if game.ui.is_complete_visible():
			break
		await _frames(2)
	_check(game.ui.time_summary.ends_with("NEW BEST TIME!"), "card: '%s'" % game.ui.time_summary)
	tp = game.ui.time_panel_state()
	_check(tp["visible"] and tp["banner"] and tp["record"] and tp["time"] == UIManager.fmt_time(r["time_ms"]) and tp["best_caption"] == "PREVIOUS BEST" and tp["best"] == UIManager.fmt_time(t1)
		and game.ui._time_value.get_theme_color("font_color") == Palette.ACCENT,
		"timing block, faster replay: NEW PERSONAL BEST! - TIME %s (accent) | PREVIOUS BEST %s" % [tp["time"], tp["best"]])
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
	# Guided finger lesson (the first time a mechanic is taught): the player
	# follows the finger - no clock until the lesson's key move ends it.
	_check(game.mechanic_intro == null and game._lesson == "portal" and not game._attempt_active(), "the card gone, the PORTAL finger lesson runs: the clock does not run")
	var l0 := game.attempt_timer.elapsed
	await _frames(20)
	_check(game.attempt_timer.elapsed == l0, "no time adds up while the guided lesson runs")
	var steps := await _follow_lesson()
	_check(game._lesson == "" and game.progress.tips_seen.has("lesson_portal") and steps > 0 and not game.completed, "the lesson's key move ends it (%d guided taps)" % steps)
	await _frames(1)
	var l1 := game.attempt_timer.elapsed
	await _frames(20)
	_check(game._attempt_active() and game.attempt_timer.elapsed > l1, "independent play: the clock runs again")
	_check(not game.attempt_assisted, "following the lesson's finger is not assistance")
	game.attempt_timer.elapsed = 3.0  # independent play after the lesson
	await _solve()
	r = game.last_time_result
	_check(game.completed and r.get("clean", false) and _near(r.get("time_ms", 0), 3.0) and game.progress.best_clean_time(201) == r["time_ms"],
		"the attempt records only independent play, clean (%d ms)" % r.get("time_ms", 0))
	# Replay: the lesson was learned - no lesson, the clock runs from the start.
	game.start_level(201, "replay")
	await _frames(3)
	_check(game._lesson == "" and game._attempt_active(), "replay of a lesson level: no lesson, the clock runs from the start")
	# Every production lesson level: no clock while its lesson runs.
	var taught: Array = []
	for n in GameManager.LESSONS:
		var kind: String = GameManager.LESSONS[n]
		game.progress.tips_seen.erase("lesson_" + kind)
		game.progress.highest_completed = maxi(game.progress.highest_completed, n - 1)
		game.start_level(n, "select")
		await _frames(2)
		for i in 400:
			if game.mechanic_intro == null:
				break
			await _frames(2)
		await _frames(2)
		if game._lesson != "":
			var e := game.attempt_timer.elapsed
			await _frames(10)
			if game.attempt_timer.elapsed == e and not game._attempt_active():
				taught.append(n)
	_check(taught == GameManager.LESSONS.keys(), "every lesson that runs in the campaign stops the clock (lesson levels %s)" % [taught])
	# A lesson ended early (the Hammer removes every block it is about) also
	# resumes the clock; the Hammer itself makes the attempt assisted. The
	# first lesson level where that is possible is used.
	var ended := -1
	for n in GameManager.LESSONS:
		var kind: String = GameManager.LESSONS[n]
		game.progress.tips_seen.erase("lesson_" + kind)
		game.start_level(n, "select")
		await _frames(2)
		for i in 400:
			if game.mechanic_intro == null:
				break
			await _frames(2)
		await _frames(2)
		for i in 8:
			if game._lesson == "" or game.completed:
				break
			var target := -1
			for bid in game._lesson_blocks(game._lesson):
				if game.is_hammer_safe(bid) and not game.model.blocks[bid].is_crate():
					target = bid
					break
			if target < 0:
				break
			game.progress.inventory["hammer"] = 3
			if not game.hammer_armed:
				game.toggle_hammer()
			game._on_block_tapped(target)
			await _frames(2)
		if game._lesson == "" and game.hammers_used > 0 and not game.completed:
			ended = n
			break
		if game.hammer_armed:
			game.toggle_hammer()
	await _frames(1)
	var h1 := game.attempt_timer.elapsed
	await _frames(10)
	_check(ended > 0 and game._attempt_active() and game.attempt_timer.elapsed > h1 and game.attempt_assisted and not game.progress.tips_seen.has("lesson_" + GameManager.LESSONS[ended]),
		"Hammer on the lesson's blocks (Level %d): the lesson ends quietly, the clock runs, the attempt is assisted (Hammer)" % ended)
	await _live_hud()
	# Records survive a reload from disk.
	var reload := PlayerProgress.new(SAVE).load_from_disk()
	_check(reload.best_times == game.progress.best_times and reload.clean_times == game.progress.clean_times and reload.best_time(1) > 0,
		"records survive a reload (%s / %s)" % [reload.best_times, reload.clean_times])
	game.queue_free()
	await _frames(2)
	_done.append("game")


## The real game (real frame clock): a blocked main thread during play is
## discarded time; during menus / a hidden page it is not; restart and
## replay start at zero; the shown time, the record and the save are as
## before.
func _cap_game() -> void:
	PlayerProgress.default_path = SAVE
	_wipe(SAVE)
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	game._hide_title()
	await _start(2)
	await _frames(10)
	_check(game._attempt_active() and game.attempt_timer.discarded_ms() == 0, "smooth play: nothing discarded (%d ms)" % game.attempt_timer.discarded_ms())
	var e0 := game.attempt_timer.elapsed
	OS.delay_msec(700)  # a real 0.7 s stall on the main thread
	await _frames(2)
	var d1 := game.attempt_timer.discarded_ms()
	_check(game.attempt_timer.capped_frames == 1 and d1 >= 400 and d1 <= 520 and game.attempt_timer.elapsed - e0 <= 0.30,
		"a 0.7 s stall while playing: %d ms discarded, at most %.2f s shown (as before)" % [d1, AttemptTimer.MAX_FRAME])
	for menu in ["settings", "shop"]:
		if menu == "settings":
			game.ui._open_settings()
		else:
			game.open_shop()
		await _frames(2)
		OS.delay_msec(700)
		await _frames(2)
		_check(game.attempt_timer.discarded_ms() == d1 and game.attempt_timer.capped_frames == 1, "%s open + a 0.7 s stall: nothing discarded (a pause)" % menu)
		if menu == "settings":
			game.ui._close_settings()
		else:
			game.ui._shop.close()
		await _frames(2)
	# Hidden page (Safari in the background): hidden span + resume frame add nothing.
	game.attempt_timer.set_page_hidden(true)
	await _frames(2)
	OS.delay_msec(700)
	await _frames(2)
	game.attempt_timer.set_page_hidden(false)
	OS.delay_msec(700)  # the resume frame is long too
	await _frames(3)
	_check(game.attempt_timer.discarded_ms() == d1 and game.attempt_timer.capped_frames == 1, "hidden page + long resume frame: nothing discarded")
	# The state publishes the metadata; the finished attempt carries it; the save does not.
	_check(game.attempt_timer.cap_info()["discarded_ms"] == d1, "cap metadata readable during the attempt")
	await _solve()
	var r: Dictionary = game.last_time_result
	_check(game.completed and r.get("discarded_ms", -1) == d1 and r.get("capped_frames", -1) == 1 and r["time_ms"] == game.attempt_timer.elapsed_ms()
		and r["new_best_time"] and game.progress.best_time(2) == r["time_ms"],
		"the finished attempt carries the metadata; the record is the shown time (%d ms, discarded %d)" % [r["time_ms"], d1])
	var saved := FileAccess.get_file_as_string(SAVE)
	_check(saved.contains("[times]") and not saved.contains("discard") and not saved.contains("capped"), "nothing of it is saved")
	# Replay and restart: a fresh attempt, zero metadata.
	game.replay()
	await _frames(3)
	_check(game.attempt_timer.cap_info()["discarded_ms"] == 0 and game.attempt_timer.capped_frames == 0, "REPLAY starts with nothing discarded")
	OS.delay_msec(600)
	await _frames(2)
	_check(game.attempt_timer.capped_frames == 1, "a stall in the replay counts in the replay")
	game.restart()
	await _frames(3)
	_check(game.attempt_timer.discarded_ms() == 0 and game.attempt_timer.capped_frames == 0 and game.attempt_timer.cap_info()["start_frame_ms"] < 250,
		"RESTART starts with nothing discarded (a fresh start frame: %d ms)" % game.attempt_timer.cap_info()["start_frame_ms"])
	game.queue_free()
	await _frames(2)
	_wipe(SAVE)
	_done.append("cap_game")
