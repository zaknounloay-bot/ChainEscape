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


## The fake server (same rules as ce_submit_result: one best per player).
func _serve(body: Dictionary) -> Dictionary:
	bodies.append(body.duplicate(true))
	await get_tree().process_frame
	match mode:
		"ok":
			var lv: Dictionary = fake.get(body["level"], {})
			var prev := int(lv.get(body["player_id"], 0))
			var best: int = body["time_ms"] if prev == 0 else mini(prev, body["time_ms"])
			lv[body["player_id"]] = best
			fake[body["level"]] = lv
			var faster := 0
			for t in lv.values():
				if int(t) < best:
					faster += 1
			var pct = null if lv.size() < 5 else clampi(int(roundf(100.0 * (faster + 1) / lv.size())), 1, 100)
			return {"ok": true, "code": 200, "data": {"ok": true, "improved": prev == 0 or best < prev, "best_ms": best, "percentile": pct}}
		"network":
			return {"ok": false, "error": "network"}
		"busy":
			return {"ok": true, "code": 429, "data": {"ok": false, "error": "busy"}}
		"wrong_secret":
			return {"ok": true, "code": 403, "data": {"ok": false, "error": "wrong_secret"}}
		"v4":  # a server without results: challenge CREATE validation
			return {"ok": true, "code": 400, "data": {"ok": false, "error": "invalid_challenge_type"}}
		_:
			return {"ok": true, "code": 400, "data": {"ok": false, "error": mode}}


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
