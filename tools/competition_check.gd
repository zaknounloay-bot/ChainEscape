## REAL-PLAYER RESULTS (Phase 3B-B) - client checks, headless:
##   godot --headless --path . res://tools/CompetitionCheck.tscn
##   CE_E2E_API=http://127.0.0.1:8000/ godot ... (also: real HTTP to a local
##   chain-escape-api v5 + PostgreSQL, see tools/competition_e2e.sh)
## A. Off by default (production / normal builds): no secret, no queue, no
##    request, the save byte-for-byte as before.
## B. Queue rules (fake server): only NEW attempts (no backfill), only a
##    better time than already sent / queued, offline kept + saved +
##    retried, answers sorted into acknowledged / dropped / kept, QA-only
##    diagnostics, the secret made once.
## C. Backup / restore merge of the competition data.
## D. The real game: a cleared level is queued and sent in the background;
##    the card and NEXT never wait; Personal Bests unchanged.
## E. (CE_E2E_API) end to end against the real Edge Function source.
## F. Phase 3B-C standing (fake server): only server values, null below 5
##    players, faster / slower replays, ties and rounding, offline / errors,
##    no stale answer on a newer card, the read-only lookup.
## G. Phase 3B-C on the real level card: TOP X% / quiet states, assisted
##    attempts, replays, offline then online, leave / re-enter, reload, the
##    row inside the card at a fixed height; off = no row.
extends Node

const DIR := "user://competition_check/"
var passed := 0
var failures: Array[String] = []
var _done: Array[String] = []
## Fake server: level -> {player_id -> best ms}; mode: "ok" / "network" / an error code.
var fake: Dictionary = {}
var mode := "ok"
var bodies: Array = []


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		print("FAIL: " + what)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	PlayerProgress.identity_enabled = true
	await _off()
	await _queue()
	_merge()
	await _game()
	await _standing()
	await _card()
	if OS.get_environment("CE_E2E_API") != "":
		await _e2e()
	BuildFlags.competition_override = -1
	print("%d checks passed, %d failed" % [passed, failures.size()])
	if failures.is_empty():
		print("COMPETITION CHECKS PASSED (%s)" % ", ".join(_done))
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


static func _wipe(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _fresh(name: String) -> PlayerProgress:
	var path := DIR + name + ".cfg"
	_wipe(path)
	var p := PlayerProgress.new(path).load_from_disk()
	p.ensure_identity()
	return p


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The fake server (same rules as ce_submit_result / ce_level_standing:
## one best per player; percentiles arrive as JSON floats).
func _serve(body: Dictionary) -> Dictionary:
	bodies.append(body.duplicate(true))
	await get_tree().process_frame
	if mode == "ok" and body.get("action", "") == "level_standing":
		var sl: Dictionary = fake.get(body["level"], {})
		if not sl.has(body["player_id"]):
			return {"ok": true, "code": 200, "data": {"ok": true, "none": true, "best_ms": null, "percentile": null}}
		return {"ok": true, "code": 200, "data": {"ok": true, "best_ms": sl[body["player_id"]], "percentile": _pct(sl, int(sl[body["player_id"]]))}}
	match mode:
		"ok":
			var lv: Dictionary = fake.get(body["level"], {})
			var prev := int(lv.get(body["player_id"], 0))
			var best: int = body["time_ms"] if prev == 0 else mini(prev, body["time_ms"])
			lv[body["player_id"]] = best
			fake[body["level"]] = lv
			return {"ok": true, "code": 200, "data": {"ok": true, "improved": prev == 0 or best < prev, "best_ms": best, "percentile": _pct(lv, best)}}
		"network":
			return {"ok": false, "error": "network"}
		"busy":
			return {"ok": true, "code": 429, "data": {"ok": false, "error": "busy"}}
		"wrong_secret":
			return {"ok": true, "code": 403, "data": {"ok": false, "error": "wrong_secret"}}
		"database_error":
			return {"ok": true, "code": 500, "data": {"ok": false, "error": "database_error"}}
		"v4":  # a server without results: challenge CREATE validation
			return {"ok": true, "code": 400, "data": {"ok": false, "error": "invalid_challenge_type"}}
		_:
			return {"ok": true, "code": 400, "data": {"ok": false, "error": mode}}


## The backend's TOP X% (index.ts topPercent): null below 5 players.
static func _pct(lv: Dictionary, best: int):
	if lv.size() < 5:
		return null
	var faster := 0
	for t in lv.values():
		if int(t) < best:
			faster += 1
	return float(clampi(int(roundf(100.0 * (faster + 1) / lv.size())), 1, 100))


func _comp(p: PlayerProgress) -> Competition:
	var c := Competition.new(p)
	c.transport = _serve
	add_child(c)
	return c


# --- A. Off ------------------------------------------------------------------------

func _off() -> void:
	BuildFlags.competition_override = -1
	_check(not BuildFlags.competition(), "competition is off outside the QA build (here: a normal run)")
	var path := DIR + "game_off.cfg"
	_wipe(path)
	PlayerProgress.default_path = path
	var game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	_check(game.competition == null, "the game creates no Competition when off")
	game._hide_title()
	game.start_level(2, "select")
	await _frames(2)
	game.tutorial.hide_hint(true)
	game._lesson = ""
	await _solve(game)
	var text := FileAccess.get_file_as_string(path)
	_check(game.completed and text.contains("[times]") and not text.contains("[competition]") and not text.contains("secret="),
		"a cleared level with competition off: no secret, no [competition] in the save")
	_check(game.progress.comp_secret == "" and game.progress.comp_pending.is_empty(), "nothing queued in memory either")
	for i in 180:
		if game.ui.is_complete_visible():
			break
		await _frames(1)
	var tp_off: Dictionary = game.ui.time_panel_state()
	_check(game.ui.is_complete_visible() and tp_off["visible"] and not tp_off["comp_row"] and tp_off["comp"] == "",
		"competition off (production): the card has no standing row, the timing block as before")
	game.queue_free()
	await _frames(2)
	_wipe(path)
	_done.append("off")


func _solve(game) -> void:
	for i in 200:
		if game.completed or game.model.is_empty():
			break
		var id: int = Solver.from_model(game.model).recommend_move()
		if id < 0:
			break
		game._on_block_tapped(id)
		await _frames(1)
	await _frames(3)


# --- B. Queue rules ------------------------------------------------------------------

func _queue() -> void:
	fake = {}
	bodies = []
	mode = "ok"
	var p := _fresh("queue")
	p.record_time(3, 4000, true)  # an old Personal Best (before competition)
	p.record_result(3, 9000, 3)
	p.save()
	var c := _comp(p)
	_check(c.start() and PlayerProfile.is_valid_secret(p.comp_secret), "start() makes the secret once (64 hex)")
	var secret := p.comp_secret
	_check(not c.start() and p.comp_secret == secret, "... and never again")
	await _frames(3)
	_check(bodies.is_empty() and p.comp_pending.is_empty(), "no backfill: the old Personal Best of Level 3 is not sent")
	# New attempts.
	_check(c.note_clear(3, 6000, {"discarded_ms": 0, "capped_frames": 0, "longest_frame_ms": 0, "start_frame_ms": 1800}),
		"a new clear is queued (even when slower than the old local PB: only competition attempts count)")
	_check(not c.note_clear(3, 6500, {}), "a slower attempt than the queued one is not queued")
	_check(c.note_clear(3, 5500, {}) and int(p.comp_pending[3]["t"]) == 5500, "a faster one replaces the queued time")
	_check(not c.note_clear(301, 5000, {}) and not c.note_clear(3, 0, {}), "no level / no valid time: nothing queued")
	p.save()
	await c.flush()
	_check(p.comp_pending.is_empty() and int(p.comp_sent[3]) == 5500 and c.standings[3]["best_ms"] == 5500 and c.standings[3]["percentile"] == null,
		"flush: acknowledged (sent 5500), pending cleared, percentile null below 5 players")
	var b: Dictionary = bodies[-1]
	_check(b["action"] == "submit_result" and b["pool"] == "qa" and b["player_id"] == p.player_id and b["secret"] == secret
		and b["fingerprint"] == LevelFingerprint.expected(3) and b["time_ms"] == 5500 and not b.has("name") and not b.has("display_name"),
		"the request: pool qa, id, secret, level fingerprint, time - never the display name")
	_check(not c.note_clear(3, 5500, {}) and not c.note_clear(3, 7000, {}), "equal or slower than the acknowledged best: not sent again")
	_check(c.note_clear(3, 5000, {}), "a faster replay is queued again")
	# Offline: kept, saved, survives a reload, retried.
	mode = "network"
	var n0 := bodies.size()
	await c.flush()
	_check(bodies.size() == n0 + 1 and p.comp_pending.has(3) and c.last_error == "network" and c._retry.time_left > 0.0,
		"offline: the result stays queued and a retry is scheduled (%.0f s)" % c._retry.time_left)
	p.save()
	var again := PlayerProgress.new(p.path).load_from_disk()
	_check(again.comp_pending.has(3) and int(again.comp_pending[3]["t"]) == 5000 and again.comp_secret == secret and int(again.comp_sent[3]) == 5500,
		"queued result, acknowledged bests and the secret survive a reload")
	mode = "busy"
	await c.flush()
	_check(p.comp_pending.has(3) and c.last_error == "busy", "429 busy: kept for later")
	mode = "v4"
	await c.flush()
	_check(p.comp_pending.has(3), "a server without results (version 4): kept for later, not dropped")
	mode = "ok"
	await c.flush()
	_check(p.comp_pending.is_empty() and int(p.comp_sent[3]) == 5000, "back online: sent, acknowledged 5000")
	# Diagnostics: QA pool only.
	c.note_clear(4, 8000, {"discarded_ms": 12, "capped_frames": 1, "longest_frame_ms": 262, "start_frame_ms": 1900})
	await c.flush()
	_check(bodies[-1].has("diag") and bodies[-1]["diag"]["start_frame_ms"] == 1900, "QA pool: timing diagnostics sent")
	c.pool = "prod"
	c.note_clear(5, 8000, {"discarded_ms": 12})
	await c.flush()
	_check(not bodies[-1].has("diag") and bodies[-1]["pool"] == "prod", "prod pool: no diagnostics")
	c.pool = "qa"
	# Permanent answers drop the result; wrong_secret also stops sending.
	mode = "invalid_time"
	c.note_clear(6, 9000, {})
	await c.flush()
	_check(not p.comp_pending.has(6) and c.last_error == "invalid_time" and not c.locked, "invalid_time: dropped, sending goes on")
	mode = "wrong_secret"
	c.note_clear(7, 9000, {})
	await c.flush()
	_check(not p.comp_pending.has(7) and c.locked and not c.note_clear(8, 9000, {}), "wrong_secret: dropped and further sending stops")
	# Five players on one level (fake server): the percentile comes back.
	mode = "ok"
	var others := [9000, 10000, 11000, 12000]
	for i in others.size():
		await _serve({"action": "submit_result", "level": 9, "player_id": "other-%d" % i, "time_ms": others[i]})
	var c2 := _comp(_fresh("queue2"))
	c2.start()
	c2.note_clear(9, 10500, {})
	await c2.flush()
	_check(c2.standings[9]["percentile"] == 60, "5 players on a level: the answer carries the percentile (TOP %s%%)" % str(c2.standings[9]["percentile"]))
	_check(not c2.state().has("secret") and not str(c2.state()).contains(c2.progress.comp_secret), "the state snapshot never shows the secret")
	c.queue_free()
	c2.queue_free()
	_done.append("queue")


# --- C. Merge ----------------------------------------------------------------------

func _merge() -> void:
	var src := _fresh("m_src")
	src.record_result(1, 9000, 3)
	src.ensure_comp_secret()
	src.comp_sent = {1: 4000}
	src.comp_pending = {2: {"t": 6000, "fp": LevelFingerprint.expected(2), "diag": {}}}
	# Adopted: a save without progress takes the player, secret and results.
	var dst := _fresh("m_dst")
	var r := dst.merge_from(PlayerProgress.from_text(_text(src)))
	_check(r["profile"] == "adopted" and dst.player_id == src.player_id and dst.comp_secret == src.comp_secret
		and int(dst.comp_sent[1]) == 4000 and dst.comp_pending.has(2), "restore on a new device: the same competitor (id, secret, sent, pending)")
	# Kept local: another player's competition data never comes along.
	var mine := _fresh("m_mine")
	mine.record_result(5, 9000, 3)
	mine.ensure_comp_secret()
	var my_secret := mine.comp_secret
	r = mine.merge_from(PlayerProgress.from_text(_text(src)))
	_check(r["profile"] == "kept_local" and mine.comp_secret == my_secret and mine.comp_sent.is_empty() and mine.comp_pending.is_empty(),
		"another player's code on a save with progress: no foreign secret or results")
	# Same player: the faster of each.
	var same := PlayerProgress.from_text(_text(src))
	same.comp_sent = {1: 3500}
	same.comp_pending = {2: {"t": 6500, "fp": LevelFingerprint.expected(2), "diag": {}}, 3: {"t": 7000, "fp": LevelFingerprint.expected(3), "diag": {}}}
	r = src.merge_from(same)
	_check(r["profile"].begins_with("same") and int(src.comp_sent[1]) == 3500 and int(src.comp_pending[2]["t"]) == 6000 and src.comp_pending.has(3),
		"same player from another device: faster sent / pending of each level kept")
	# A backup code carries it.
	var q := PlayerProgress.from_text(PlayerProgress.decode_backup(src.backup_code()))
	_check(q.comp_secret == src.comp_secret and int(q.comp_sent[1]) == 3500, "a backup code carries the secret and the acknowledged bests")
	_done.append("merge")


func _text(p: PlayerProgress) -> String:
	return PlayerProgress.decode_backup(p.backup_code())


# --- D. The real game ------------------------------------------------------------------

func _game() -> void:
	BuildFlags.competition_override = 1
	fake = {}
	bodies = []
	mode = "network"  # offline first
	var path := DIR + "game_on.cfg"
	_wipe(path)
	PlayerProgress.default_path = path
	var game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	_check(game.competition != null and PlayerProfile.is_valid_secret(game.progress.comp_secret), "competition on: created, secret made at start")
	game.competition.transport = _serve
	game._hide_title()
	game.start_level(2, "select")
	await _frames(2)
	game.tutorial.hide_hint(true)
	game._lesson = ""
	await _solve(game)
	for i in 180:
		if game.ui.is_complete_visible():
			break
		await _frames(1)
	_check(game.completed and game.ui.is_complete_visible(), "the level clears and the card shows while offline")
	await _frames(5)
	var t: int = game.last_time_result["time_ms"]
	_check(game.progress.comp_pending.has(2) and int(game.progress.comp_pending[2]["t"]) == t and game.progress.best_time(2) == t,
		"offline: the attempt is queued; the Personal Best is the same shown time (%d ms)" % t)
	_check(FileAccess.get_file_as_string(path).contains("[competition]"), "the queue is in the (QA) save")
	mode = "ok"
	game.next_level()
	await _frames(4)
	_check(game.current_level == 3 and not game.completed, "NEXT works without waiting for the server")
	await game.competition.flush()
	_check(game.progress.comp_pending.is_empty() and int(game.progress.comp_sent[2]) == t, "back online: the queued result is sent and acknowledged")
	_check(game.competition.state()["requests"] >= 2 and not str(game.competition.state()).contains(game.progress.comp_secret), "test state: no secret")
	game.queue_free()
	await _frames(2)
	BuildFlags.competition_override = -1
	_wipe(path)
	_done.append("game")


# --- E. End to end -------------------------------------------------------------------

func _e2e() -> void:
	SocialConfig.api_url_override = OS.get_environment("CE_E2E_API")
	SocialConfig.timeout_override = 10.0
	var pcts := []
	var cs: Array[Competition] = []
	for i in 5:
		var p := _fresh("e2e_%d" % i)
		var c := Competition.new(p)  # no transport: the real SocialApi over HTTP
		add_child(c)
		c.start()
		c.note_clear(12, 20000 + i * 1000, {"discarded_ms": 0, "capped_frames": 0, "longest_frame_ms": 0, "start_frame_ms": 1700})
		await c.flush()
		cs.append(c)
		var pc = c.standings.get(12, {}).get("percentile", "x")
		pcts.append(int(pc) if pc is float or pc is int else pc)  # JSON numbers arrive as floats
	_check(pcts == [null, null, null, null, 100], "real HTTP: 5 new players on Level 12 -> %s" % [pcts])
	var c0 := cs[0]
	c0.note_clear(12, 19000, {})
	await c0.flush()
	_check(c0.standings[12]["percentile"] == 20 and c0.progress.comp_pending.is_empty(), "real HTTP: the fastest replays -> TOP %s%%" % str(c0.standings[12]["percentile"]))
	var imp := _fresh("e2e_imp")
	imp.player_id = cs[1].progress.player_id
	imp.ensure_comp_secret()
	var ci := Competition.new(imp)
	add_child(ci)
	ci.note_clear(12, 1000, {})
	await ci.flush()
	_check(ci.locked and ci.last_error == "wrong_secret", "real HTTP: someone else's id with another secret -> wrong_secret, nothing changes")
	SocialConfig.api_url_override = ""
	_done.append("e2e")


# --- F. Standing (Phase 3B-C) --------------------------------------------------------

## Seeds `n` other players on a level of the fake server.
func _others(level: int, times: Array) -> void:
	var lv: Dictionary = fake.get(level, {})
	for i in times.size():
		lv["other-%d-%d" % [level, i]] = int(times[i])
	fake[level] = lv


func _standing() -> void:
	fake = {}
	bodies = []
	mode = "ok"
	var p := _fresh("standing")
	var c := _comp(p)
	c.start()
	var seen := []
	c.standing_changed.connect(func(n): seen.append(n))
	# Before 5 players: no percentile, never a count.
	var m := c.mark()
	c.note_clear(20, 30000, {})
	_check(c.card_status(20, m)["state"] == "checking", "queued, no answer yet: checking")
	await c.flush()
	var st := c.card_status(20, m)
	_check(st["state"] == "needs_players" and not st.has("percentile") and seen == [20], "1 player: NOT ENOUGH PLAYERS YET (no percentile, no count)")
	_check(c.card_status(20, c.mark())["state"] == "checking", "a card opened after that answer does not reuse it (checking until a newer one)")
	# 5 players: the server's value. 20 / 25 / 30 (us) / 35 / 40 s -> TOP 60%.
	_others(20, [20000, 25000, 35000, 40000])
	m = c.mark()
	var n0 := bodies.size()
	await c.lookup(20)
	st = c.card_status(20, m)
	_check(bodies.size() == n0 + 1 and bodies[-1]["action"] == "level_standing" and not bodies[-1].has("time_ms"),
		"the lookup is level_standing (read-only: no time, no result written)")
	_check(st["state"] == "top" and st["percentile"] == 60 and st["best_ms"] == 30000 and st["percentile"] is int, "5 players: TOP 60% (server value, as an int)")
	# A faster replay improves the standing: 22 s -> 1 faster -> TOP 40%.
	m = c.mark()
	_check(c.note_clear(20, 22000, {}), "a faster replay is queued")
	await c.flush()
	st = c.card_status(20, m)
	_check(st["state"] == "top" and st["percentile"] == 40 and st["best_ms"] == 22000 and st["improved"], "faster replay: TOP 40%, best 22.000 s")
	# A slower replay changes nothing: not queued, not sent; the lookup shows the stored best.
	m = c.mark()
	n0 = bodies.size()
	_check(not c.note_clear(20, 50000, {}) and int(p.comp_sent[20]) == 22000, "slower replay: not queued, the sent best stays 22.000 s")
	await c.lookup(20)
	st = c.card_status(20, m)
	_check(bodies.size() == n0 + 1 and bodies[-1]["action"] == "level_standing" and st["percentile"] == 40 and st["best_ms"] == 22000 and not st["improved"],
		"slower replay: the standing of the stored best (TOP 40%, 22.000 s), nothing submitted")
	# Ties and rounding come from the server: 7 players, 1 / 2 / 2 (us) / 3 / 4 / 5 / 6 s.
	_others(21, [1000, 2000, 3000, 4000, 5000, 6000])
	m = c.mark()
	c.note_clear(21, 2000, {})
	await c.flush()
	st = c.card_status(21, m)
	_check(st["percentile"] == 29 and _pct(fake[21], 2000) == 29.0, "tie at 2 s on 7 players: both TOP 29% (round(200/7)), as the server says")
	# The card shows the server's number even where a local formula would differ.
	var c3 := Competition.new(_fresh("standing_raw"))
	c3.transport = func(body: Dictionary) -> Dictionary:
		bodies.append(body.duplicate(true))
		await get_tree().process_frame
		return {"ok": true, "code": 200, "data": {"ok": true, "improved": true, "best_ms": body["time_ms"], "percentile": 37.0}}
	add_child(c3)
	c3.start()
	m = c3.mark()
	c3.note_clear(22, 9000, {})
	await c3.flush()
	_check(c3.card_status(22, m)["percentile"] == 37, "whatever the server answers (37) is what is shown - no local calculation")
	c3.queue_free()
	# Offline: kept, the card says it will be sent; back online: the standing.
	mode = "network"
	m = c.mark()
	c.note_clear(20, 21000, {})
	c.note_clear(23, 7000, {})
	await c.flush()
	_check(c.card_status(20, m)["state"] == "offline" and c.card_status(23, m)["state"] == "offline", "offline: every queued level shows SAVED, WILL SEND LATER")
	mode = "database_error"
	m = c.mark()
	await c.flush()
	_check(c.card_status(20, m)["state"] == "offline" and p.comp_pending.has(20), "500 database_error: kept, same quiet state")
	mode = "ok"
	m = c.mark()
	await c.flush()
	_check(c.card_status(20, m)["state"] == "top" and c.card_status(23, m)["state"] == "needs_players" and p.comp_pending.is_empty(),
		"back online: both answered (TOP %s%%; a new level with 1 player: not enough players)" % str(c.card_status(20, m).get("percentile")))
	mode = "network"
	m = c.mark()
	await c.lookup(20)
	_check(c.card_status(20, m)["state"] == "unavailable", "a lookup while offline: NOT AVAILABLE RIGHT NOW (nothing queued, nothing invented)")
	# Permanent answers: nothing to show.
	mode = "invalid_time"
	m = c.mark()
	c.note_clear(24, 9000, {})
	await c.flush()
	_check(c.card_status(24, m)["state"] == "hidden", "invalid_time: the result is dropped and nothing is shown")
	# The lookup never registers anyone: no request for a level never sent.
	mode = "ok"
	n0 = bodies.size()
	await c.lookup(25)
	_check(bodies.size() == n0 and c.card_status(25, c.mark())["state"] == "hidden", "no lookup for a level never sent (never registers a player)")
	# A faster time queued while a submit is on its way: the older answer is not shown.
	var p4 := _fresh("standing_slow")
	var c4 := Competition.new(p4)
	c4.transport = func(body: Dictionary) -> Dictionary:
		await _frames(5)  # a slow network
		return await _serve(body)
	add_child(c4)
	c4.start()
	var seen4 := []
	c4.standing_changed.connect(func(n): seen4.append(n))
	await _frames(2)
	m = c4.mark()
	c4.note_clear(26, 9000, {})
	c4.flush.call_deferred()
	await _frames(2)
	_check(c4.sending, "the 9.000 s submit is in flight")
	c4.note_clear(26, 8000, {})
	await _frames(30)
	var sends := 0
	for b in bodies:
		if b.get("level", 0) == 26 and b.get("action", "") == "submit_result" and b["player_id"] == p4.player_id:
			sends += 1
	_check(sends == 2 and int(p4.comp_sent[26]) == 8000 and c4.card_status(26, m).get("best_ms", 0) == 8000 and seen4 == [26],
		"faster time queued mid-request: sent right after, and only the newer answer reaches the card")
	c4.queue_free()
	# wrong_secret: locked, nothing shown.
	mode = "wrong_secret"
	m = c.mark()
	c.note_clear(27, 9000, {})
	await c.flush()
	_check(c.locked and c.card_status(27, m)["state"] == "hidden" and c.card_status(20, m)["state"] == "hidden", "wrong_secret: locked, no standing shown anywhere")
	mode = "ok"
	c.queue_free()
	_done.append("standing")


# --- G. The level card (Phase 3B-C) ---------------------------------------------------

func _clear(game, level: int, seconds: float, assist: String = "") -> void:
	if game.current_level != level or game.completed:
		game.start_level(level, "select")
		await _frames(2)
	game.tutorial.hide_hint(true)
	game._lesson = ""
	if assist.contains("hint"):
		game.progress.inventory["hint"] = 5
		game.request_hint()
		await _frames(2)
		game._clear_hint()
	if assist.contains("undo"):
		game._on_block_tapped(Solver.from_model(game.model).recommend_move())
		await _frames(2)
		game.undo()
		await _frames(2)
	if assist.contains("hammer"):
		game.progress.inventory["hammer"] = 3
		game.toggle_hammer()
		for bid in game.model.blocks:
			if game.is_hammer_safe(bid) and not game.model.blocks[bid].is_crate():
				game._on_block_tapped(bid)
				break
		await _frames(2)
	game.attempt_timer.elapsed = seconds
	await _solve(game)
	for i in 180:
		if game.ui.is_complete_visible():
			break
		await _frames(1)
	await _frames(6)


func _comp_text(game) -> String:
	return str(game.ui.time_panel_state()["comp"])


func _card() -> void:
	BuildFlags.competition_override = 1
	fake = {}
	bodies = []
	mode = "ok"
	var path := DIR + "card.cfg"
	_wipe(path)
	PlayerProgress.default_path = path
	var game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	game.competition.transport = _serve
	game._hide_title()
	# Level 3, no one else: the quiet state - no number at all.
	await _clear(game, 3, 15.0)
	var tp: Dictionary = game.ui.time_panel_state()
	_check(tp["comp_row"] and _comp_text(game) == "TOP %   ·   NOT ENOUGH PLAYERS YET" and RegEx.create_from_string("[0-9]").search(_comp_text(game)) == null,
		"fewer than 5 players: '%s' (no percentile, no count)" % _comp_text(game))
	# Level 2 with 4 others (5, 8, 20, 30 s): an assisted clear (Show a Move) at ~12 s -> TOP 60%.
	_others(2, [5000, 8000, 20000, 30000])
	await _clear(game, 2, 12.0, "hint")
	var t1: int = game.last_time_result["time_ms"]
	_check(game.attempt_assisted and int(game.progress.comp_sent.get(2, 0)) == t1, "an attempt with Show a Move is sent like any other (%d ms)" % t1)
	_check(_comp_text(game) == "TOP 60%", "5 players: the card shows '%s'" % _comp_text(game))
	tp = game.ui.time_panel_state()
	var card_rect: Rect2 = game.ui._card.get_global_rect()
	var row_rect: Rect2 = game.ui._comp_row.get_global_rect()
	var vis: Vector2 = game.ui.get_viewport().get_visible_rect().size
	var buttons_top: float = game.ui._card_buttons.get_global_rect().position.y
	var time_rect: Rect2 = game.ui._time_value.get_global_rect()
	_check(card_rect.encloses(row_rect) and row_rect.end.y <= buttons_top and row_rect.position.y >= time_rect.end.y - 1.0
		and card_rect.position.x >= 0.0 and card_rect.end.x <= vis.x,
		"the row sits inside the card, under TIME | PERSONAL BEST, above REPLAY / NEXT, no horizontal overflow")
	var vsize: int = game.ui._comp_value.get_theme_font_size("font_size")
	var tsize: int = game.ui._time_value.get_theme_font_size("font_size")
	_check(vsize < tsize and game.ui._comp_value.get_combined_minimum_size().x < row_rect.size.x + 1.0,
		"hierarchy: TOP X%% (%d px) smaller than the time (%d px), on one line" % [vsize, tsize])
	# A slower replay with Undo: nothing sent; the card shows the stored best's standing, labelled.
	var sent_before := int(game.progress.comp_sent[2])
	var pb_before: int = game.progress.best_time(2)
	var n0 := bodies.size()
	game.replay()
	await _frames(2)
	await _clear(game, 2, 40.0, "undo")
	_check(int(game.progress.comp_sent[2]) == sent_before and game.progress.best_time(2) == pb_before, "slower replay: neither the sent best nor the Personal Best change")
	var submits := 0
	for b in bodies.slice(n0):
		if b["action"] == "submit_result":
			submits += 1
	_check(submits == 0 and bodies.size() == n0 + 1 and bodies[-1]["action"] == "level_standing", "slower replay: one read-only lookup, no submission")
	_check(_comp_text(game) == "YOUR BEST TOP 60%", "slower replay card: '%s' (the standing belongs to the earlier best)" % _comp_text(game))
	var rect_slow: Rect2 = game.ui._comp_row.get_global_rect()
	# A faster replay with Undo and Hammer: 3 s -> TOP 20%.
	game.replay()
	await _frames(2)
	await _clear(game, 2, 3.0, "undo hammer")
	_check(game.hammers_used == 1 and int(game.progress.comp_sent[2]) == game.last_time_result["time_ms"] and _comp_text(game) == "TOP 20%",
		"faster replay with Undo + Hammer: sent and '%s'" % _comp_text(game))
	# Offline: the card says so; back online while it is up: it updates in place, same height.
	mode = "network"
	game.replay()
	await _frames(2)
	await _clear(game, 2, 2.0)
	_check(_comp_text(game) == "TOP %   ·   SAVED, WILL SEND LATER" and game.progress.comp_pending.has(2), "offline: '%s', the result kept" % _comp_text(game))
	var rect_off: Rect2 = game.ui._comp_row.get_global_rect()
	_check(is_equal_approx(rect_off.size.y, rect_slow.size.y) and is_equal_approx(game.ui._comp_row.size.y, game.ui.COMP_ROW_HEIGHT),
		"the row keeps one height in every state (%.0f)" % game.ui._comp_row.size.y)
	mode = "ok"
	await game.competition.flush()
	await _frames(2)
	_check(_comp_text(game) == "TOP 20%" and game.progress.comp_pending.is_empty() and game.ui._comp_row.get_global_rect() == rect_off,
		"back online with the card up: '%s', the card did not move" % _comp_text(game))
	# Leave before the answer: it never shows on a later card as new.
	mode = "network"
	game.replay()
	await _frames(2)
	await _clear(game, 2, 1.5)
	game.next_level()
	await _frames(4)
	mode = "ok"
	await game.competition.flush()
	_check(not game.ui.is_complete_visible() and game.current_level == 3 and game.progress.comp_pending.is_empty(), "left the card, then the queued result was sent in the background")
	game.start_level(2, "select")
	await _frames(2)
	await _clear(game, 2, 30.0)
	_check(_comp_text(game) == "YOUR BEST TOP 20%" and bodies[-1]["action"] == "level_standing", "re-entered, slower: a fresh lookup ('%s')" % _comp_text(game))
	# Reload: standings live in memory only; the next card asks again.
	var sent := game.progress.comp_sent.duplicate()
	game.queue_free()
	await _frames(2)
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	game.competition.transport = _serve
	game._hide_title()
	_check(game.competition.standings.is_empty() and game.progress.comp_sent == sent, "reload: acknowledged bests kept, no standing carried over")
	n0 = bodies.size()
	await _clear(game, 2, 45.0)
	_check(_comp_text(game) == "YOUR BEST TOP 20%" and bodies.size() == n0 + 1 and bodies[-1]["action"] == "level_standing", "after reload: one lookup, '%s'" % _comp_text(game))
	# Server answers 500 on the lookup: the quiet offline state.
	mode = "database_error"
	game.replay()
	await _frames(2)
	await _clear(game, 2, 46.0)
	_check(_comp_text(game) == "TOP %   ·   NOT AVAILABLE RIGHT NOW", "lookup answered 500: '%s' (nothing queued)" % _comp_text(game))
	mode = "ok"
	game.queue_free()
	await _frames(2)
	BuildFlags.competition_override = -1
	_wipe(path)
	_done.append("card")
