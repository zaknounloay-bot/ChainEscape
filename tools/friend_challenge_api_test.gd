extends Node
## Challenge a Friend phase 2: the client model / API foundation, against
## tools/mock_social_api.py (started and stopped here).
##   godot --headless --path . res://tools/FriendChallengeApiTest.tscn
## friend_challenge CREATE / READ round trips (every difficulty, SURPRISE
## ME), exact board, type-specific validation in both directions, old
## Photo / Message Reveal records, and that a friend link opened today gets
## the friendly "not available" screen (no recipient UI yet).

const PORT := 8797

var failures: Array[String] = []
var passed := 0
var _pid := -1
var _base := "http://127.0.0.1:%d/" % PORT
var api: SocialApi


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_model()
	_pid = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/mock_social_api.py"), "--port", str(PORT)])
	SocialConfig.api_url_override = _base
	api = SocialApi.new()
	add_child(api)
	if not await _wait_health():
		_check(false, "mock API did not start")
	else:
		await _test_round_trips()
		await _test_old_records()
		await _test_recipient_guard()
	if _pid > 0:
		OS.kill(_pid)
	print("FRIEND CHALLENGE API TEST: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _test_model() -> void:
	var p := FriendGenerator.new("hard", 11, [], 0).run()
	var c := SharedChallenge.friend_challenge(p, "hard")
	var body := SocialApi.build_create_body(c)
	_check(body.keys() == ["challenge_type", "difficulty", "puzzle"] and body["challenge_type"] == "friend_challenge"
		and body["difficulty"] == "hard" and body["puzzle"] == p.to_dict(), "CREATE body: type, real difficulty, exact puzzle - nothing else")
	var s := SocialApi.build_create_body(SharedChallenge.friend_challenge(p, "hard", true))
	_check(s.get("surprise_me") == true and s["difficulty"] == "hard", "SURPRISE ME: real difficulty + surprise_me flag")
	_check(SocialApi.build_create_body(SharedChallenge.friend_challenge(p, "surprise")).has("error"), "\"surprise\" is never sent as a difficulty")
	_check(SocialApi.build_create_body(SharedChallenge.friend_challenge(p, "insane")).has("error"), "unknown difficulty refused")
	var withmsg := SharedChallenge.friend_challenge(p, "hard")
	withmsg.payload["message"] = "hi"
	_check(SocialApi.build_create_body(withmsg).has("error"), "a friend challenge never carries a message")
	var none := SharedChallenge.friend_challenge(null, "hard")
	_check(SocialApi.build_create_body(none).has("error"), "a friend challenge needs its puzzle")
	var locked := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 1, "cols": 2, "map": ["R>#B B>"]})
	_check(SocialApi.build_create_body(SharedChallenge.friend_challenge(locked, "easy")).has("error"), "friend boards: no locks / other mechanics")
	# Photo / Message Reveal: VERY HARD is not one of its difficulties.
	var pm := SharedChallenge.new()
	pm.type = SharedChallenge.TYPE_PHOTO_MESSAGE_REVEAL
	pm.difficulty = "very_hard"
	pm.puzzle = p
	pm.payload = {"message": "x", "photo": null}
	_check(SocialApi.build_create_body(pm).has("error"), "photo_message_reveal refuses very_hard")
	pm.difficulty = "hard"
	_check(not SocialApi.build_create_body(pm).has("error"), "photo_message_reveal hard + message still builds")
	_check(CreatorSession.DIFFICULTIES == ["easy", "medium", "hard"], "the Photo / Message creator still offers only EASY / MEDIUM / HARD")
	# READ validation (untrusted data).
	var ch := {"id": "x", "challenge_type": "friend_challenge", "difficulty": "very_hard", "puzzle": p.to_dict(), "payload": {}, "media_url": null}
	var r := SharedChallenge.from_api(ch)
	_check(r.has("challenge") and r["challenge"].type == "friend_challenge" and r["challenge"].difficulty == "very_hard"
		and r["challenge"].puzzle.fingerprint() == p.fingerprint() and not r["challenge"].is_surprise(), "from_api: friend_challenge, real difficulty, exact puzzle")
	for bad in [["payload", {"message": "x"}], ["payload", {"media": {"path": "a"}}], ["media_url", "https://x/y"],
			["difficulty", "surprise"], ["difficulty", "insane"], ["payload", {"surprise_me": "yes"}], ["payload", "x"]]:
		var b := ch.duplicate(true)
		b[bad[0]] = bad[1]
		_check(SharedChallenge.from_api(b).get("error", "") == "malformed", "from_api refuses friend %s = %s" % [bad[0], str(bad[1])])
	var pmv := {"challenge_type": "photo_message_reveal", "difficulty": "very_hard", "puzzle": p.to_dict(), "payload": {"message": "x"}}
	_check(SharedChallenge.from_api(pmv).get("error", "") == "malformed", "from_api refuses photo_message_reveal + very_hard")
	_check(SharedChallenge.from_api({"challenge_type": "x"}).get("error", "") == "unsupported", "unknown type -> unsupported")


func _test_round_trips() -> void:
	var gens_before := FriendGenerator.created
	for d in FriendGenerator.DIFFICULTIES:
		var p := FriendGenerator.new(d, 404, [], 0).run()
		var c := await api.create_challenge(SharedChallenge.friend_challenge(p, d))
		_check(c.get("ok", false), "CREATE friend_challenge %s via SocialApi (%s)" % [d, c.get("error", "")])
		if not c.get("ok", false):
			continue
		var fps := {}
		for i in 3:  # three recipients
			var r := await api.read_challenge(c["challenge_id"])
			_check(r.get("ok", false), "READ %s #%d" % [d, i])
			if r.get("ok", false):
				var rc: SharedChallenge = r["challenge"]
				_check(rc.type == "friend_challenge" and rc.difficulty == d and rc.message() == "" and rc.media_url == "",
					"READ %s #%d: friend_challenge, %s, nothing to reveal" % [d, i, d])
				fps[rc.puzzle.fingerprint()] = true
		_check(fps.size() == 1 and fps.has(p.fingerprint()), "%s: every READ is the creator's exact puzzle" % d)
	_check(FriendGenerator.created == gens_before + 4, "reading never generates a puzzle")
	var sp := FriendGenerator.new("easy", 5, [], 0).run()
	var sc := await api.create_challenge(SharedChallenge.friend_challenge(sp, "easy", true))
	var sr := await api.read_challenge(sc.get("challenge_id", ""))
	_check(sr.get("ok", false) and sr["challenge"].difficulty == "easy" and sr["challenge"].is_surprise(), "SURPRISE ME round trip: easy + surprise flag")
	# Photo / Message Reveal still round-trips.
	var pm := SharedChallenge.new()
	pm.type = SharedChallenge.TYPE_PHOTO_MESSAGE_REVEAL
	pm.difficulty = "medium"
	pm.puzzle = SocialGenerator.new("medium", 3).run()
	pm.payload = {"message": "still here", "photo": null}
	var pc := await api.create_challenge(pm)
	var pr := await api.read_challenge(pc.get("challenge_id", ""))
	_check(pr.get("ok", false) and pr["challenge"].type == "photo_message_reveal" and pr["challenge"].message() == "still here"
		and pr["challenge"].puzzle.fingerprint() == pm.puzzle.fingerprint(), "photo_message_reveal CREATE / READ unchanged")


## A record exactly as Phase 1 / 0.2C phase 2 stored it (before friend
## support) still reads.
func _test_old_records() -> void:
	var p := SocialGenerator.new("easy", 9).run()
	var old := {"id": "11111111-2222-4333-8444-555555555555", "challenge_type": "photo_message_reveal", "difficulty": "easy",
		"puzzle": p.to_dict(), "payload": {"message": "made in 0.2C", "media": {"type": "image", "path": "x/reveal.jpg", "mime": "image/jpeg"}},
		"format_version": 1, "rules_version": 1, "created_at": "2026-09-30T10:00:00.000Z", "expires_at": "2099-01-01T00:00:00.000Z"}
	await _post("__put", {"id": old["id"], "challenge": old})
	var r := await api.read_challenge(old["id"])
	_check(r.get("ok", false) and r["challenge"].type == "photo_message_reveal" and r["challenge"].message() == "made in 0.2C"
		and r["challenge"].payload["photo"] != null and r["challenge"].puzzle.fingerprint() == p.fingerprint(),
		"an old photo_message_reveal record (pre-friend) reads unchanged (%s)" % r.get("error", ""))
	var bare := old.duplicate(true)
	bare.erase("format_version")
	bare.erase("rules_version")
	_check(SharedChallenge.from_api(bare).has("challenge"), "old records without version columns still parse")


## No Challenge a Friend recipient UI yet: a friend link gets the friendly
## "not available / newer version" screen, nothing else.
func _test_recipient_guard() -> void:
	var p := FriendGenerator.new("medium", 21, [], 0).run()
	var c := await api.create_challenge(SharedChallenge.friend_challenge(p, "medium"))
	var rf := RecipientFlow.new()
	add_child(rf)
	rf.begin(c.get("challenge_id", ""), Chapters.theme_for_chapter(1))
	var t0 := Time.get_ticks_msec()
	while rf.state == RecipientFlow.State.LOADING and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().process_frame
	_check(rf.state == RecipientFlow.State.UNAVAILABLE and rf.error_code == "unsupported" and rf.challenge == null,
		"a friend link today -> friendly unavailable screen, nothing playable (%s)" % rf.error_code)
	rf.queue_free()


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
		await get_tree().create_timer(0.25).timeout
	return false


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(msg)
