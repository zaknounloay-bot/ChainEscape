extends Node
## Social MVP 0.2C (phase 1): CREATE -> backend -> challenge id -> share link,
## against tools/mock_social_api.py (started and stopped by this test).
##
##   godot --headless --path . res://tools/SocialApiTest.tscn
##   (xvfb-run godot --path . --resolution 390x844 res://tools/SocialApiTest.tscn -- --shots=/tmp/s)

const PROGRESS_PATH := "user://social_api_test_progress.cfg"
const PORT := 8791

var game: GameManager
var social: SocialScreen
var cr: RevealCreator
var failures: Array[String] = []
var shots_dir := ""
var _pid := -1
var _base := "http://127.0.0.1:%d/" % PORT
var _wide: PackedByteArray


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	_run.call_deferred()


func _run() -> void:
	_wide = _jpeg(1600, 900)
	_test_links()
	_test_parsing()
	_pid = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/mock_social_api.py"), "--port", str(PORT)])
	SocialConfig.api_url_override = _base
	SocialConfig.share_base_override = "https://test.chainescape.example/play/"
	if not await _wait_health():
		_check(false, "mock API did not start")
		_finish()
		return
	# Classic player mid-level (must survive everything below untouched).
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	for n in range(1, 9):
		game.progress.record_result(n, 1000 + n, 3)
	game.progress.coins = 55
	game.progress.save()
	game.start_level(9)
	await _frames(3)
	for id in game.model.blocks:
		if game.model.move_state(id) == "ok":
			game.board.block_tapped.emit(id)
			break
	await _wait(0.8)
	var classic := _classic()
	var before := _snapshot()
	var file_before := FileAccess.get_file_as_string(PROGRESS_PATH)
	game.return_to_main_menu()
	await _frames(3)
	social = game.ui._title._social
	cr = social.creator
	social.open(game.ui.theme)
	await _frames(3)

	await _test_create("A message only", "Happy Birthday!", false, "easy")
	await _test_create("B photo + message", "كل عام وأنت بخير", true, "medium")
	await _test_create("C photo only", "", true, "hard")
	await _test_retry_and_failures()
	await _test_read()

	social.close()
	await _frames(3)
	_check(_snapshot() == before, "K: Classic progress (score, coins, stars, unlocks, level) unchanged")
	_check(FileAccess.get_file_as_string(PROGRESS_PATH) == file_before, "K: Classic save file not written")
	_check(_classic() == classic and game.history.size() == 1, "K: the unfinished Classic board is exactly as it was")
	game.continue_game()
	await _frames(3)
	_check(not game.ui.is_title_open() and _classic() == classic, "CONTINUE resumes the same Classic board")
	_finish()


func _finish() -> void:
	if _pid > 0:
		OS.kill(_pid)
	print("SOCIAL API TEST: %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	for f in failures:
		printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# --- H / I: links ---------------------------------------------------------------------

func _test_links() -> void:
	var id := "3f2b8c1e-9a4d-4e7b-8c21-5d6e7f809a1b"
	for base in ["https://html-classic.itch.zone/html/123/index.html", "https://chainescape.app/", "https://x.io/game/?foo=1#bar"]:
		var url := ShareLink.build(base, id)
		_check(ShareLink.parse(url) == id, "H: build/parse round trip (%s)" % url)
		_check(url.ends_with("?challenge=" + id) and url.count("?") == 1 and not url.contains("#"), "I: link carries only ?challenge=<id> (%s)" % url)
	_check(ShareLink.parse("https://a.b/?x=1&challenge=" + id.to_upper()) == id, "H: upper-case id accepted, normalized")
	_check(ShareLink.parse("https://a.b/#challenge=" + id) == id, "H: #challenge= also accepted")
	for bad in ["https://a.b/", "https://a.b/?challenge=", "https://a.b/?challenge=12345", "https://a.b/?challenge=" + id + "x",
			"https://a.b/?challenge=../../etc", "https://a.b/?challenge=" + id.replace("-", "")]:
		_check(ShareLink.parse(bad) == "", "H: malformed link refused (%s)" % bad)
	_check(ShareLink.build("https://a.b/", "nope") == "", "H: no link for an invalid id")


# --- F / G: response parsing (no network) ------------------------------------------

func _test_parsing() -> void:
	var good := SocialGenerator.new("easy", 9).run().to_dict()
	var ok_ch := {"id": "3f2b8c1e-9a4d-4e7b-8c21-5d6e7f809a1b", "challenge_type": "photo_message_reveal", "difficulty": "easy",
		"puzzle": good, "payload": {"message": "Hi"}, "media_url": null, "expires_at": "2099-01-01T00:00:00.000Z"}
	var r := SocialApi.parse_read_response(200, {"ok": true, "challenge": ok_ch})
	_check(r["ok"] and r["challenge"].puzzle.fingerprint() == PuzzleDefinition.from_dict(good).fingerprint() and r["challenge"].message() == "Hi",
			"a valid READ response rebuilds the exact puzzle")
	var cases := {
		"no challenge": {"ok": true},
		"unknown type": _with(ok_ch, "challenge_type", "friend_challenge"),
		"bad difficulty": _with(ok_ch, "difficulty", "insane"),
		"newer rules": _with(ok_ch, "puzzle", _with(good, "rules", 2)),
		"bad map": _with(ok_ch, "puzzle", _with(good, "map", ["R> ??"])),
		"unsolvable": _with(ok_ch, "puzzle", {"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 1, "cols": 2, "map": ["R> R<"]}),
		"long message": _with(ok_ch, "payload", {"message": "x".repeat(201)}),
		"nothing to reveal": _with(ok_ch, "payload", {"message": "  "}),
		"http media": _with(_with(ok_ch, "payload", {"media": {"path": "a"}}), "media_url", "http://evil.example/x.jpg"),
		"payload not object": _with(ok_ch, "payload", "x"),
	}
	for k in cases:
		var res := SocialApi.parse_read_response(200, cases[k] if k == "no challenge" else {"ok": true, "challenge": cases[k]})
		_check(not res["ok"], "F: malformed READ refused (%s -> %s)" % [k, res.get("error", "")])
	_check(SocialApi.parse_read_response(200, {"ok": true, "challenge": _with(ok_ch, "expires_at", "2020-01-01T00:00:00Z")})["error"] == "expired",
			"G: a past expires_at is treated as expired")
	_check(SocialApi.parse_read_response(404, {"ok": false, "error": "challenge not found"})["error"] == "not_found", "G: 404 -> not_found")
	_check(SocialApi.parse_read_response(410, {"ok": false})["error"] == "expired", "G: 410 -> expired")
	_check(SocialApi.parse_read_response(200, "<html>")["error"] == "invalid_response", "F: non-JSON READ refused")
	_check(SocialApi.parse_create_response(200, {"ok": true, "challenge_id": "x"})["error"] == "invalid_response", "F: CREATE with a bad id refused")
	_check(SocialApi.parse_create_response(500, {"ok": false, "error": "internal: stack trace"})["error"] == "server", "F: server text never surfaces (only a code)")


# --- A-D: CREATE through the real creator flow ---------------------------------------

func _test_create(name: String, message: String, photo: bool, difficulty: String) -> void:
	await _fill(message, photo, difficulty, 100 + name.length())
	await _tap(_cnode("Create"))
	await _until(func(): return cr.step == RevealCreator.Step.SHARE or cr.last_error != "", 25.0)
	_check(cr.step == RevealCreator.Step.SHARE, "%s: CHALLENGE READY shown (error '%s')" % [name, cr.last_error])
	var body: Dictionary = await _get_json("__last")
	var p := cr.prepared
	var sent_def := PuzzleDefinition.from_dict(body.get("puzzle", {}))
	_check(sent_def != null and sent_def.fingerprint() == p.puzzle.fingerprint() and Array(sent_def.map) == Array(p.puzzle.map),
			"D %s: the exact PuzzleDefinition was sent" % name)
	_check(body.get("challenge_type") == "photo_message_reveal" and body.get("difficulty") == difficulty, "%s: type and difficulty sent" % name)
	_check(body.get("message", "") == message, "%s: message sent as plain text (or omitted)" % name)
	if photo:
		var sent := Marshalls.base64_to_raw(str(body.get("image_base64", "")))
		_check(sent == cr.session.image_jpeg and body.get("image_type") == "image/jpeg" and sent.size() < 600000,
				"%s: the processed photo copy was uploaded (%d bytes)" % [name, sent.size()])
	else:
		_check(not body.has("image_base64"), "%s: no image sent" % name)
	var url := cr.share_url
	_check(ShareLink.parse(url) == p.remote_id and ShareLink.is_valid_id(p.remote_id), "%s: share link carries the new id" % name)
	_check(not url.contains("map") and not url.contains("base64") and (message == "" or not url.contains(message.uri_encode())) and url.length() < 200,
			"I %s: link has no reveal content (%s)" % [name, url])
	_check(_cnode("ShareChallenge") != null and _cnode("CopyLink") != null and _cnode("PreviewChallenge") != null, "%s: SHARE / COPY LINK / PREVIEW shown" % name)
	await _shot("s_%s" % name.left(1))
	# COPY LINK (desktop: clipboard).
	await _tap(_cnode("CopyLink"))
	var headless := DisplayServer.get_name() == "headless"  # no clipboard there
	_check(cr._share_status.text == "LINK COPIED" and (headless or DisplayServer.clipboard_get() == url), "%s: COPY LINK copies the link" % name)
	# PLAY / PREVIEW plays the same puzzle, then comes back to the share screen.
	await _tap(_cnode("PreviewChallenge"))
	await _until(func(): return social.play.is_active(), 5.0)
	_check(social.play.is_active() and social.play.loaded_fingerprint == p.puzzle.fingerprint(), "%s: PREVIEW plays the shared puzzle" % name)
	await _wait(0.3)
	await _tap(social.play._exit)
	await _tap(social.play._confirm.find_child("Leave", true, false))
	_check(cr.step == RevealCreator.Step.SHARE and cr.share_url == url, "%s: leaving the preview returns to the share screen" % name)
	await _tap(_cnode("Done"))
	_check(social.page == SocialScreen.Page.CHOICE and cr.share_url == "", "%s: DONE leaves the flow" % name)


# --- E / L: failures keep everything, retries keep the puzzle --------------------------

func _test_retry_and_failures() -> void:
	await _fill("Retry me", true, "medium", 4242)
	await _post("__mode", {"fail_next": "500"})
	var count0: int = (await _get_json("__count"))["count"]
	await _tap(_cnode("Create"))
	await _until(func(): return cr.last_error != "", 25.0)
	_check(cr.last_error == "server" and cr.step == RevealCreator.Step.GENERATING and cr._gen_retry.visible, "E: server error shows TRY AGAIN")
	_check(not cr._gen_status.text.contains("stack") and cr._gen_title.text.begins_with("COULDN'T CREATE"), "E: friendly message, no server text")
	await _shot("s_error")
	var fp := cr.prepared.puzzle.fingerprint()
	_check(cr.session.message == "Retry me" and cr.session.has_photo() and cr.session.difficulty == "medium", "L: photo, message and difficulty kept after the failure")
	# Network down: same puzzle again.
	SocialConfig.api_url_override = "http://127.0.0.1:9/"
	await _tap(cr._gen_retry)
	await _until(func(): return not cr.uploading, 15.0)
	_check(cr.last_error == "network" and cr.prepared.puzzle.fingerprint() == fp, "E: network failure, prepared puzzle kept")
	# Timeout.
	SocialConfig.api_url_override = _base
	SocialConfig.timeout_override = 2.0
	await _post("__mode", {"fail_next": "timeout"})
	await _tap(cr._gen_retry)
	await _until(func(): return not cr.uploading, 15.0)
	_check(cr.last_error == "timeout", "E: timeout handled (%s)" % cr.last_error)
	SocialConfig.timeout_override = 0.0
	await _wait(4.5)  # let the mock finish the slow reply
	# Garbage / bad id replies.
	for mode in ["garbage", "bad_id", "429"]:
		await _post("__mode", {"fail_next": mode})
		await _tap(cr._gen_retry)
		await _until(func(): return not cr.uploading, 15.0)
		_check(cr.last_error in ["invalid_response", "rate_limited"] and cr.step == RevealCreator.Step.GENERATING, "F: %s reply handled (%s)" % [mode, cr.last_error])
	# BACK to the review (nothing lost), CREATE again -> same puzzle, success.
	await _tap(cr._gen_back)
	_check(cr.step == RevealCreator.Step.REVIEW and cr.session.message == "Retry me" and cr.session.has_photo(), "L: BACK keeps every choice")
	var count1: int = (await _get_json("__count"))["count"]
	await _tap(_cnode("Create"))
	# A second tap while the request runs must not send twice.
	cr._start_generating()
	await _until(func(): return cr.step == RevealCreator.Step.SHARE or (cr.last_error != "" and not cr.uploading), 25.0)
	var count2: int = (await _get_json("__count"))["count"]
	_check(cr.step == RevealCreator.Step.SHARE, "E: TRY AGAIN path succeeds")
	_check(count2 - count1 == 1, "no double submission (%d requests)" % (count2 - count1))
	var body: Dictionary = await _get_json("__last")
	_check(PuzzleDefinition.from_dict(body["puzzle"]).fingerprint() == fp, "E: the retried upload sent the SAME puzzle")
	# Changing a choice after that builds a new puzzle (only then).
	await _tap(_cnode("Done"))


# --- G: READ (recipient preparation) ---------------------------------------------------

func _test_read() -> void:
	await _fill("Read me back", true, "hard", 777)
	await _tap(_cnode("Create"))
	await _until(func(): return cr.step == RevealCreator.Step.SHARE, 25.0)
	var id := ShareLink.parse(cr.share_url)
	var creator_fp := cr.prepared.puzzle.fingerprint()
	var creator_blocks := _blocks(cr.prepared.puzzle)
	await _tap(_cnode("Done"))
	var r: Dictionary = await cr.api.read_challenge(id)
	_check(r["ok"], "READ by id works (%s)" % r.get("error", ""))
	if r["ok"]:
		var c: SharedChallenge = r["challenge"]
		_check(c.puzzle.fingerprint() == creator_fp and _blocks(c.puzzle) == creator_blocks, "READ: identical puzzle, block by block (no regeneration)")
		_check(c.message() == "Read me back" and c.media_url.begins_with("https://") and c.difficulty == "hard", "READ: payload + signed media URL")
	_check((await cr.api.read_challenge("not-an-id"))["error"] == "invalid_id", "G: malformed id refused before any request")
	_check((await cr.api.read_challenge("3f2b8c1e-9a4d-4e7b-8c21-5d6e7f809a1b"))["error"] == "not_found", "G: unknown id -> not_found")
	await _post("__expire", {"id": id})
	_check((await cr.api.read_challenge(id))["error"] == "expired", "G: expired challenge -> expired")


# --- Helpers ---------------------------------------------------------------------------

func _fill(message: String, photo: bool, difficulty: String, seed_value: int) -> void:
	if social.page != SocialScreen.Page.CHOICE:
		social.show_page(SocialScreen.Page.CHOICE)
	await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Photo", true, false))
	if photo:
		cr.receive_photo(_wide)
		await _wait(0.3)
		await _tap(_cnode("UsePhoto"))
	else:
		await _tap(_cnode("SkipPhoto"))
	await _wait(0.3)
	if message != "":
		cr._message_edit.text = message
		await _frames(2)
		await _tap(_cnode("Continue"))
	else:
		await _tap(_cnode("SkipMessage"))
	await _tap(_cnode("Difficulty_" + difficulty))
	await _tap(_cnode("Continue"))
	cr.debug_seed = seed_value


func _blocks(p: PuzzleDefinition) -> Array:
	var l := p.to_level()
	var out := []
	for b in l.blocks:
		out.append([b.id, b.cell, b.color, b.direction, b.kind, b.spin_rule, b.hidden, b.lock_color, b.rarity])
	return out


func _with(d: Dictionary, k: String, v) -> Dictionary:
	var o := d.duplicate(true)
	o[k] = v
	return o


func _get_json(path: String):
	var req := HTTPRequest.new()
	add_child(req)
	req.request(_base + path)
	var res: Array = await req.request_completed
	req.queue_free()
	return JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())


func _post(path: String, data: Dictionary) -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.request(_base + path, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data))
	await req.request_completed
	req.queue_free()


func _wait_health() -> bool:
	for i in 40:
		var req := HTTPRequest.new()
		add_child(req)
		req.timeout = 1.0
		req.request(_base)
		var res: Array = await req.request_completed
		req.queue_free()
		if res[0] == HTTPRequest.RESULT_SUCCESS and res[1] == 200:
			return true
		await _wait(0.25)
	return false


func _until(cond: Callable, seconds: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await _frames(1)


func _classic() -> String:
	var out := []
	var ids := game.model.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = game.model.blocks[id]
		out.append([id, b.cell, b.direction])
	return var_to_str([game.current_level, out])


func _snapshot() -> String:
	var p := game.progress
	return var_to_str([p.coins, p.best_scores, p.best_stars, p.highest_unlocked, p.highest_completed, p.current_level, p.inventory, p.total_score()])


func _cnode(n: String) -> Control:
	var c: Control = cr._steps[cr.step].find_child(n, true, false)
	_check(c != null and c.is_visible_in_tree(), "step %d: %s visible" % [cr.step, n])
	return c


func _jpeg(w: int, h: int) -> PackedByteArray:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color("#E8703A"))
	img.fill_rect(Rect2i(w / 4, h / 4, w / 2, h / 2), Color.WHITE)
	return img.save_jpg_to_buffer(0.85)


func _tap(c: Control) -> void:
	if c == null:
		_check(false, "tap target missing")
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = c.get_global_rect().get_center()
	ev.global_position = ev.position
	ev.pressed = true
	get_tree().root.push_input(ev, true)
	await _frames(1)
	var up := ev.duplicate()
	up.pressed = false
	get_tree().root.push_input(up, true)
	await _wait(0.3)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await _frames(2)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [shots_dir, name])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
