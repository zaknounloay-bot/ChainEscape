extends Node
## Social MVP 0.2C (phase 2): a shared challenge link, opened by its
## recipient - launch routing, loading / landing / unavailable screens, the
## EXACT puzzle, the reveal (photo from its signed URL, refreshed when it
## expires), CREATE YOUR OWN back into the creator, Classic isolation and
## the Classic HUD orientation. Runs against tools/mock_social_api.py
## (started and stopped here), which also serves the photos.
##
##   godot --headless --path . res://tools/RecipientTest.tscn
##   (xvfb-run godot --path . --resolution 390x844 res://tools/RecipientTest.tscn -- --shots=/tmp/s)

const PROGRESS_PATH := "user://recipient_test_progress.cfg"
const PORT := 8793
const MESSAGE := "Happy birthday! Meet me at 8"
const MESSAGE_RTL := "مفاجأة! نلتقي الساعة 8"

var game: GameManager
var social: SocialScreen
var rf: RecipientFlow
var play: SocialPlay
var failures: Array[String] = []
var passed := 0
var shots_dir := ""
var _pid := -1
var _base := "http://127.0.0.1:%d/" % PORT
var _photo: PackedByteArray
var _first_state := -1
var _save_at_launch := ""
var _sessions_checked := 0
var _first_social := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	_run.call_deferred()


func _run() -> void:
	_photo = _jpeg(1200, 900)
	_test_link_parsing()
	_pid = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/mock_social_api.py"),
		"--port", str(PORT), "--media-base", _base.trim_suffix("/")])
	SocialConfig.api_url_override = _base
	SocialConfig.allow_http_media = true
	SocialConfig.share_base_override = "https://test.chainescape.example/play/"
	if not await _wait_health():
		_check(false, "mock API did not start")
		_finish()
		return
	# A Classic player whose save says: Level 12 is next (1-11 completed).
	var seed_game := await _new_game("", true)
	for n in range(1, 12):
		seed_game.progress.record_result(n, 1000 + n, 3)
	seed_game.progress.coins = 77
	seed_game.progress.current_level = 12
	seed_game.progress.save()
	_free_game()

	var both := await _create(MESSAGE, true, "medium", 4242)
	var photo_only := await _create("", true, "hard", 99)
	var msg_only := await _create(MESSAGE_RTL, false, "easy", 7)
	await _test_hud_orientation()
	await _test_launch_valid(both)
	await _test_reveal_photo_only(photo_only)
	await _test_reveal_message_only(msg_only)
	await _test_photo_refresh_and_failure(both)
	await _test_launch_errors(msg_only)
	await _test_isolation_mid_level(both)
	await _test_create_your_own(both)
	_finish()


func _finish() -> void:
	_check_save_untouched()
	_check(_sessions_checked >= 15, "S: save checked after every shared-challenge session (%d)" % _sessions_checked)
	_free_game()
	if _pid > 0:
		OS.kill(_pid)
	print("RECIPIENT TEST: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# --- Tests --------------------------------------------------------------------------

func _test_link_parsing() -> void:
	var id := "5a264212-44fb-499b-9e05-59c738ed98b2"
	_check(ShareLink.parse("https://x.itch.zone/html/1/index.html?challenge=" + id) == id, "A: ?challenge=<uuid> parsed")
	_check(ShareLink.parse("https://x.example/index.html#challenge=" + id.to_upper()) == id, "B: #challenge=<uuid> parsed")
	_check(ShareLink.parse("https://x.example/index.html?challenge=abc") == "", "D: malformed id rejected")
	_check(ShareLink.parse("https://x.example/index.html") == "", "C: no parameter")
	var link := ShareLink.build("https://html-classic.itch.zone/html/19500310/index.html?foo=1#bar", id)
	_check(link == "https://html-classic.itch.zone/html/19500310/index.html?challenge=" + id, "U: link = base + ?challenge=<id> only")


## T: Classic HUD = the V17 layout, whatever the device language.
func _test_hud_orientation() -> void:
	_check(int(ProjectSettings.get_setting("internationalization/rendering/root_node_layout_direction", 0)) == 1,
		"T: root layout direction pinned to left-to-right")
	for loc in ["en_US", "he_IL", "ar_SA"]:
		TranslationServer.set_locale(loc)
		var g := await _new_game("", true)
		g.start_level(12)
		await _frames(4)
		var ui := g.ui
		_check(not ui._root.is_layout_rtl() and not get_tree().root.is_layout_rtl(), "T(%s): Classic UI not right-to-left" % loc)
		var cx := func(c: Control) -> float: return c.get_global_rect().get_center().x
		var w := get_viewport().get_visible_rect().size.x
		_check(cx.call(ui._levels_button) < w * 0.5 and cx.call(ui._settings_button) > w * 0.5,
			"T(%s): Level Select left, Settings right" % loc)
		_check(cx.call(ui._hud_total) < w * 0.5 and cx.call(ui._coin_pill) > w * 0.5,
			"T(%s): TOTAL SCORE left, coins right" % loc)
		var order := [ui._undo_button, ui._hint_button, ui._hammer_button, ui._restart_button].map(func(b): return cx.call(b))
		_check(order[0] < order[1] and order[1] < order[2] and order[2] < order[3],
			"T(%s): bottom row UNDO -> SHOW A MOVE -> HAMMER -> RESTART (%s)" % [loc, str(order)])
		if loc == "he_IL":
			await _shot("T_classic_hud_he")
		_free_game()
	TranslationServer.set_locale("en_US")


## A, G-L, P, R: a valid link, photo + message.
func _test_launch_valid(info: Dictionary) -> void:
	var gens := SocialGenerator.created
	var reads0: int = (await _get_json("__reads"))["reads"]
	await _new_game(info["id"], false)
	_check(social.visible and social.page == SocialScreen.Page.RECIPIENT, "A: a valid link opens the recipient flow over the title")
	_check(_first_state == RecipientFlow.State.LOADING and _first_social, "A: the loading screen from the very first frame (no Main Menu first)")
	_check(_visible_text(rf).contains("Opening your Chain Escape"), "loading copy shown")
	await _shot("A_loading")
	await _until(func(): return rf.state != RecipientFlow.State.LOADING, 10.0)
	_check(rf.state == RecipientFlow.State.LANDING, "A: landing after READ (%s)" % rf.error_code)
	_check((await _get_json("__reads"))["reads"] == reads0 + 1, "A: exactly one READ for the challenge")
	# G: the exact board.
	_check(rf.challenge.puzzle.fingerprint() == info["fp"] and _blocks(rf.challenge.puzzle) == info["blocks"],
		"G: exact serialized board reconstructed, block by block")
	# I: nothing revealed on the landing.
	var shown := _visible_text(social)
	_check(shown.contains("SOMEONE SENT YOU") and shown.contains("Solve it to unlock your surprise.") and shown.contains("Difficulty: MEDIUM"),
		"landing copy + difficulty")
	_check(not shown.contains("Happy birthday") and not _any_texture_visible(social) and not play.visible,
		"I: landing shows no message, no photo, no reveal")
	await _until(func(): return rf.photo_state == "ready", 10.0)
	_check(rf.photo_state == "ready" and not _any_texture_visible(social), "photo prefetched while on the landing, still hidden")
	await _shot("I_landing")
	# J: PLAY = the exact board, Social rules.
	await _tap(_rnode("Play"))
	await _frames(3)
	_check(play.visible and play.mode == SocialPlay.Mode.RECIPIENT, "J: PLAY opens the Social board (recipient)")
	_check(play.loaded_fingerprint == info["fp"] and play.model.block_count() == info["blocks"].size(), "J: the board on screen is the exact shared puzzle")
	_check(play._undo.visible and play._hint.visible and play._restart.visible and SocialPlay.MAX_UNDOS == 3 and SocialPlay.MAX_HINTS == 2
		and play._hint.text == "SHOW A MOVE", "J: 3 Undo, 2 SHOW A MOVE, Restart")
	_check(play._hammer.is_visible_in_tree() and play._hammer.badge_text == "2" and play._hammer.modulate.a == 1.0,
		"J: HAMMER x2, free and active (phase 3b: same Social tools as Challenge a Friend)")
	_check(not _visible_text(play).contains("COINS"), "J: no coins or hearts")
	await _shot("J_play")
	# Exit confirm -> landing.
	await _tap(play._exit)
	await _tap(play._confirm.find_child("Leave", true, false))
	_check(not play.visible and rf.state == RecipientFlow.State.LANDING, "EXIT -> LEAVE returns to the landing (nothing revealed)")
	await _tap(_rnode("Play"))
	await _solve()
	# K, L: the reveal.
	_check(play.reveal.visible, "K: solving shows the reveal")
	_check(play.reveal.photo_state == "ready" and play.reveal._photo_frame.visible and play.reveal._photo.texture != null
		and play.reveal._photo.texture.get_size() == Vector2(1200, 900), "L: the sender's photo, from its signed URL")
	_check(play.reveal._message_card.visible and play.reveal._message.text == MESSAGE, "L: the sender's message")
	_check(play.reveal._cta.visible and play.reveal._cta.text.begins_with("CREATE YOUR OWN") and _visible_text(play.reveal).contains("Surprise someone with a challenge."),
		"CREATE YOUR OWN + its line on the reveal")
	_check(play.reveal._back.text == "MAIN MENU" and play.reveal._again.is_visible_in_tree(), "PLAY AGAIN + MAIN MENU")
	_check(_above_fold(play.reveal), "everything on the reveal fits on screen (no scrolling)")
	_check(play.reveal.cta_pulses == 0 and play.reveal._cta.modulate.a < 0.9, "R: CTA quieter while the reveal plays")
	await _shot("L_reveal_photo_message")
	await _wait(1.6)
	_check(play.reveal.cta_pulses == 1, "R: one pulse ~1.2 s in")
	await _wait(3.0)
	_check(play.reveal.cta_pulses == 1 and is_equal_approx(play.reveal._cta.modulate.a, 1.0) and play.reveal._cta.scale.is_equal_approx(Vector2.ONE),
		"R: pulsed once only, then still")
	await _shot("R_reveal_after_pulse")
	# P: PLAY AGAIN = the same puzzle.
	await _tap(play.reveal._again)
	_check(play.visible and not play.reveal.visible and play.plays == 2 and play.loaded_fingerprint == info["fp"], "P: PLAY AGAIN replays the exact same puzzle")
	await _solve()
	_check(play.reveal.visible and play.reveal.photo_state == "ready", "P: and reveals again")
	_check(SocialGenerator.created == gens, "H: no puzzle was generated for the recipient (exact board only)")
	# MAIN MENU: back to the title, Classic untouched.
	await _tap(play.reveal._back)
	_check(not social.visible and game.ui.is_title_open(), "MAIN MENU -> the normal title")
	_check(game.ui._title._continue.text == "CONTINUE  -  LEVEL 12" and game.current_level == 12, "S: title offers CONTINUE - LEVEL 12")


func _test_reveal_photo_only(info: Dictionary) -> void:
	await _new_game(info["id"], false)
	await _until(func(): return rf.state == RecipientFlow.State.LANDING and rf.photo_state == "ready", 10.0)
	_check(_visible_text(social).contains("Difficulty: HARD"), "hard difficulty on the landing")
	await _tap(_rnode("Play"))
	await _solve()
	_check(play.reveal._photo_frame.visible and not play.reveal._message_card.visible and not play.reveal._emblem.visible,
		"M: photo-only reveal (no empty message card)")
	_check(_above_fold(play.reveal), "M: fits on screen")
	await _shot("M_reveal_photo_only")


func _test_reveal_message_only(info: Dictionary) -> void:
	await _new_game(info["id"], false)
	await _until(func(): return rf.state == RecipientFlow.State.LANDING, 10.0)
	_check(rf.photo_state == "none", "message-only: no photo download")
	await _tap(_rnode("Play"))
	await _solve()
	_check(not play.reveal._photo_frame.visible and not play.reveal._photo_status.visible and play.reveal._message.text == MESSAGE_RTL
		and play.reveal._emblem.visible, "N: message-only reveal (Arabic text kept as written)")
	_check(play.reveal._message.text_direction == Control.TEXT_DIRECTION_AUTO, "N: message keeps automatic RTL/LTR direction")
	await _shot("N_reveal_message_only")


## O: expired signed URL -> fresh one; failed photo -> TRY AGAIN; slow photo.
func _test_photo_refresh_and_failure(info: Dictionary) -> void:
	# Expired: the URL from READ stops working before it is used.
	await _post("__media", {"delay": 1.5})
	var reads0: int = (await _get_json("__reads"))["reads"]
	await _new_game(info["id"], false)
	await _until(func(): return rf.state == RecipientFlow.State.LANDING, 10.0)
	await _post("__media", {"expire": true, "delay": 0.0})
	await _until(func(): return rf.photo_state != "loading", 10.0)
	_check(rf.photo_state == "ready", "O: expired signed URL -> re-read for a fresh one -> photo loaded")
	_check((await _get_json("__reads"))["reads"] == reads0 + 2 and rf.challenge.puzzle.fingerprint() == info["fp"],
		"O: one extra READ, same exact puzzle")
	# Failed: storage down -> the reveal says so, TRY AGAIN later works.
	await _post("__media", {"fail": true})
	await _new_game(info["id"], false)
	await _until(func(): return rf.state == RecipientFlow.State.LANDING and rf.photo_state != "loading", 10.0)
	_check(rf.photo_state == "failed", "O: photo download failure detected (after a fresh URL)")
	await _tap(_rnode("Play"))
	await _solve()
	_check(play.reveal.visible and play.reveal.photo_state == "failed" and play.reveal._photo_status.visible
		and play.reveal._photo_retry.is_visible_in_tree() and not play.reveal._photo_frame.visible, "O: reveal shows 'couldn't be loaded' + TRY AGAIN")
	_check(play.reveal._message.text == MESSAGE and play.reveal._cta.visible, "O: the message and CREATE YOUR OWN still show")
	_check(not _visible_text(play.reveal).contains("storage") and not _visible_text(play.reveal).contains("http"), "O: no storage path / URL in the UI")
	await _shot("O_photo_failed")
	await _post("__media", {"fail": false, "delay": 1.0})
	await _tap(play.reveal._photo_retry)
	_check(play.reveal.photo_state == "loading" and _visible_text(play.reveal).contains("Loading the photo"), "O: TRY AGAIN -> loading")
	await _until(func(): return play.reveal.photo_state == "ready", 10.0)
	_check(play.reveal._photo_frame.visible and play.reveal._photo.texture != null and not play.reveal._photo_status.visible,
		"O: TRY AGAIN -> photo appears in the reveal")
	_check(_above_fold(play.reveal), "O: still fits")
	# Slow: still downloading when solved -> loading placeholder, then the photo.
	await _post("__media", {"delay": 4.0})
	await _new_game(info["id"], false)
	await _until(func(): return rf.state == RecipientFlow.State.LANDING, 10.0)
	await _tap(_rnode("Play"))
	await _solve()
	_check(play.reveal.photo_state == "loading" and play.reveal._photo_status.visible, "O: slow photo -> 'Loading the photo...' in the reveal")
	await _shot("O_photo_loading")
	await _until(func(): return play.reveal.photo_state == "ready", 10.0)
	_check(play.reveal._photo_frame.visible, "O: slow photo appears when it arrives")
	await _post("__media", {"delay": 0.0})


## C, D, E, F + network failures and invalid data.
func _test_launch_errors(info: Dictionary) -> void:
	await _new_game("", false)
	_check(not social.visible and game.ui.is_title_open() and rf.state == RecipientFlow.State.CLOSED, "C: no parameter -> normal title")
	var reads0: int = (await _get_json("__reads"))["reads"]
	for raw in ["abc", "=", "5a264212-44fb-499b-9e05-59c738ed98b", "5a264212-44fb-499b-9e05-59c738ed98b2x", "'><script>"]:
		await _new_game(raw, false)
		await _frames(2)
		_check(rf.state == RecipientFlow.State.UNAVAILABLE and not _rnode_q("Retry").is_visible_in_tree()
			and _visible_text(rf).contains("ISN'T AVAILABLE") and _visible_text(rf).contains("It may have expired or the link"),
			"D: malformed '%s' -> friendly unavailable screen" % raw)
	_check((await _get_json("__reads"))["reads"] == reads0, "D: malformed ids never reach the API")
	await _shot("D_unavailable")
	await _tap(_rnode("MainMenu"))
	_check(not social.visible and game.ui.is_title_open(), "D: MAIN MENU -> title")
	await _expect_unavailable("3f2b8c1e-9a4d-4e7b-8c21-5d6e7f809a1b", "not_found", "E: unknown challenge")
	# F: expired (a challenge of its own, so the others stay readable).
	var gone := await _create("bye", false, "easy", 3)
	await _post("__expire", {"id": gone["id"]})
	await _expect_unavailable(gone["id"], "expired", "F: expired challenge")
	# Unsupported version / invalid puzzle / nothing to reveal (stored raw).
	var good: Dictionary = (await _get_json("?action=read&id=" + info["id"]))["challenge"]
	var cases := {
		"unsupported": _with_puzzle(good, "v", 2),
		"malformed": _with_puzzle(good, "map", ["R> R> R>", "B^ B^ B^"]),
	}
	var unsolvable := good.duplicate(true)
	unsolvable["puzzle"]["map"] = ["R> R< . . .", ". . . . .", ". . . . .", ". . . . .", ". . . . ."]
	unsolvable["puzzle"]["rows"] = 5
	unsolvable["puzzle"]["cols"] = 5
	cases["malformed#2"] = unsolvable
	var empty := good.duplicate(true)
	empty["payload"] = {"message": null}
	cases["malformed#3"] = empty
	var bad_url := good.duplicate(true)
	bad_url["media_url"] = "javascript:alert(1)"
	_check(SharedChallenge.from_api(bad_url).get("error", "") == "malformed", "a non-https media URL is refused")
	var long_msg := good.duplicate(true)
	long_msg["payload"]["message"] = "x".repeat(201)
	_check(SharedChallenge.from_api(long_msg).get("error", "") == "malformed", "a message over 200 characters is refused")
	var other := good.duplicate(true)
	other["challenge_type"] = "mystery_type"
	_check(SharedChallenge.from_api(other).get("error", "") == "unsupported", "an unknown challenge type is refused")
	var diff := good.duplicate(true)
	diff["difficulty"] = "insane"
	_check(SharedChallenge.from_api(diff).get("error", "") == "malformed", "an unknown difficulty is refused")
	var i := 0
	for code in cases:
		i += 1
		var id := "00000000-0000-4000-8000-00000000000%d" % i
		await _post("__put", {"id": id, "challenge": cases[code]})
		await _expect_unavailable(id, code.get_slice("#", 0), "invalid data (%s)" % code)
	# Network trouble: friendly error + RETRY that works.
	for mode in ["500", "garbage"]:
		await _post("__mode", {"fail_next_read": mode})
		await _new_game(info["id"], false)
		await _until(func(): return rf.state != RecipientFlow.State.LOADING, 10.0)
		_check(rf.state == RecipientFlow.State.ERROR and _rnode_q("Retry").is_visible_in_tree()
			and _visible_text(rf).contains("COULDN'T OPEN"), "server %s -> error screen with RETRY" % mode)
		_check(not _visible_text(rf).contains("internal") and not _visible_text(rf).contains("html"), "no raw server text shown (%s)" % mode)
		await _tap(_rnode("Retry"))
		await _until(func(): return rf.state != RecipientFlow.State.LOADING, 10.0)
		_check(rf.state == RecipientFlow.State.LANDING, "RETRY after %s -> landing" % mode)
	await _shot("error_retry_landing")
	SocialConfig.timeout_override = 2.0
	await _post("__mode", {"fail_next_read": "timeout"})
	await _new_game(info["id"], false)
	await _until(func(): return rf.state != RecipientFlow.State.LOADING, 10.0)
	_check(rf.state == RecipientFlow.State.ERROR and rf.error_code == "timeout" and _visible_text(rf).contains("Check your connection"),
		"timeout -> 'check your connection' + RETRY")
	await _shot("timeout_error")
	SocialConfig.timeout_override = 0.0
	await _wait(4.5)  # let the mock finish the slow request
	SocialConfig.api_url_override = "http://127.0.0.1:9/"
	await _new_game(info["id"], false)
	await _until(func(): return rf.state != RecipientFlow.State.LOADING, 10.0)
	_check(rf.state == RecipientFlow.State.ERROR and rf.error_code == "network", "offline -> error screen with RETRY")
	SocialConfig.api_url_override = _base
	await _tap(_rnode("Retry"))
	await _until(func(): return rf.state != RecipientFlow.State.LOADING, 10.0)
	_check(rf.state == RecipientFlow.State.LANDING, "back online: RETRY -> landing")


## S: halfway through Classic Level 12, a shared challenge, then CONTINUE.
func _test_isolation_mid_level(info: Dictionary) -> void:
	await _new_game("", false)
	_save_at_launch = ""  # Classic is played here; checked explicitly below
	game.continue_game()
	await _frames(3)
	_check(game.current_level == 12, "S: CONTINUE -> Level 12")
	var moves := 0
	for id in game.model.blocks.keys():
		if moves >= 2:
			break
		if game.model.move_state(id) == "ok":
			game.board.block_tapped.emit(id)
			moves += 1
			await _wait(0.8)
	var board := _classic()
	var snap := _snapshot()
	var hist := game.history.size()
	var file_before := FileAccess.get_file_as_string(PROGRESS_PATH)
	_check(hist == moves and moves > 0, "S: Level 12 half played (%d moves)" % moves)
	game.return_to_main_menu()
	await _frames(2)
	game.ui.open_shared_challenge(info["id"])
	await _until(func(): return rf.state == RecipientFlow.State.LANDING and rf.photo_state == "ready", 10.0)
	await _tap(_rnode("Play"))
	await _solve()
	await _tap(play.reveal._again)
	await _solve()
	await _tap(play.reveal._back)
	_check(game.ui.is_title_open() and not social.visible, "S: MAIN MENU after the reveal -> title")
	game.continue_game()
	await _frames(3)
	_check(_classic() == board and game.history.size() == hist and game.current_level == 12,
		"S: the unfinished Level 12 board is exactly as it was")
	_check(_snapshot() == snap and FileAccess.get_file_as_string(PROGRESS_PATH) == file_before,
		"S: level, score, stars, coins, inventory, progression unchanged; save not written")
	_check(game.hearts == game.max_hearts or game.max_hearts == 0, "S: hearts untouched")


## Q, U and the loop: CREATE YOUR OWN -> the existing creator -> a new link.
func _test_create_your_own(info: Dictionary) -> void:
	await _new_game(info["id"], false)
	await _until(func(): return rf.state == RecipientFlow.State.LANDING and rf.photo_state == "ready", 10.0)
	await _tap(_rnode("Play"))
	await _solve()
	await _tap(play.reveal._cta)
	await _frames(3)
	var cr := social.creator
	_check(social.visible and social.page == SocialScreen.Page.PHOTO_REVEAL and cr.visible and cr.step == RevealCreator.Step.CHOOSE,
		"Q: CREATE YOUR OWN -> the existing Photo / Message Reveal creator")
	_check(not play.visible and rf.state == RecipientFlow.State.CLOSED and rf.challenge == null, "Q: the received challenge is left behind")
	await _shot("Q_creator")
	# The recipient now creates their own.
	await _tap(cr._steps[cr.step].find_child("SkipPhoto", true, false))
	await _wait(0.3)
	cr._message_edit.text = "Your turn!"
	await _frames(2)
	await _tap(cr._steps[cr.step].find_child("Continue", true, false))
	await _tap(cr._steps[cr.step].find_child("Difficulty_easy", true, false))
	await _tap(cr._steps[cr.step].find_child("Continue", true, false))
	cr.debug_seed = 31
	await _tap(cr._steps[cr.step].find_child("Create", true, false))
	await _until(func(): return cr.step == RevealCreator.Step.SHARE, 25.0)
	var new_id := ShareLink.parse(cr.share_url)
	_check(ShareLink.is_valid_id(new_id) and new_id != info["id"], "loop: the recipient got a new share link")
	_check(cr.share_url == "https://test.chainescape.example/play/?challenge=" + new_id
		and not cr.share_url.contains("Your") and not cr.share_url.contains("turn"), "U: share URL carries only the challenge id")
	await _shot("Q_new_link")
	# And that link opens for the next person.
	await _new_game(new_id, false)
	await _until(func(): return rf.state != RecipientFlow.State.LOADING, 10.0)
	_check(rf.state == RecipientFlow.State.LANDING and rf.challenge.message() == "Your turn!", "loop: the new challenge opens for its recipient")


# --- Helpers ------------------------------------------------------------------------

## Creates a challenge on the mock; {id, fp, blocks}.
func _create(message: String, photo: bool, difficulty: String, seed_value: int) -> Dictionary:
	var p := SocialGenerator.new(difficulty, seed_value).run()
	var c := SharedChallenge.new()
	c.type = SharedChallenge.TYPE_PHOTO_MESSAGE_REVEAL
	c.difficulty = difficulty
	c.puzzle = p
	c.payload = {"message": message if message != "" else null, "photo": {"format": "jpeg"} if photo else null}
	if photo:
		c.local_photo_jpeg = _photo
	var api := SocialApi.new()
	add_child(api)
	var r: Dictionary = await api.create_challenge(c)
	api.queue_free()
	_check(r.get("ok", false), "mock CREATE (%s)" % r.get("error", ""))
	return {"id": r.get("challenge_id", ""), "fp": p.fingerprint(), "blocks": _blocks(p)}


func _expect_unavailable(id: String, code: String, what: String) -> void:
	await _new_game(id, false)
	await _until(func(): return rf.state != RecipientFlow.State.LOADING, 10.0)
	_check(rf.state == RecipientFlow.State.UNAVAILABLE and rf.error_code == code and not _rnode_q("Retry").is_visible_in_tree()
		and _visible_text(rf).contains("ISN'T AVAILABLE"), "%s -> unavailable screen (%s / %s)" % [what, rf.error_code, code])
	_check(not play.visible and rf.challenge == null, "%s: nothing playable" % what)


func _with_puzzle(ch: Dictionary, k: String, v) -> Dictionary:
	var o := ch.duplicate(true)
	o["puzzle"][k] = v
	return o


## A fresh game instance, as a page load with `link` as its ?challenge=
## value ("" = no parameter).
func _new_game(link: String, skip: bool) -> GameManager:
	_check_save_untouched()
	_free_game()
	SocialWeb.launch_override = link
	GameManager.skip_title = skip
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	SocialWeb.launch_override = ""
	_first_state = game.ui._title._social.recipient.state
	_first_social = game.ui._title._social.visible
	# A launch saves Classic's current level (V17); after that, nothing a
	# shared challenge does may write the save.
	_save_at_launch = FileAccess.get_file_as_string(PROGRESS_PATH) if not skip else ""
	social = game.ui._title._social
	rf = social.recipient
	play = social.play
	AudioManager.set_music_enabled(false)
	await _frames(2)
	return game


## S: the save file is exactly as the launch left it.
func _check_save_untouched() -> void:
	if game == null or _save_at_launch == "":
		return
	_sessions_checked += 1
	_check(FileAccess.get_file_as_string(PROGRESS_PATH) == _save_at_launch,
		"S: shared-challenge session %d did not write the Classic save" % _sessions_checked)
	_save_at_launch = ""


func _free_game() -> void:
	if game and is_instance_valid(game):
		game.get_parent().remove_child(game)
		game.free()
	game = null


func _solve() -> void:
	var guard := 0
	while not play.completed and guard < 200:
		play.play_solver_move()
		await _wait(0.12)
		guard += 1
	await _until(func(): return play.reveal.visible, 5.0)
	await _wait(0.9)


func _rnode(n: String) -> Control:
	var c := _rnode_q(n)
	_check(c != null and c.is_visible_in_tree(), "recipient: %s visible" % n)
	return c


func _rnode_q(n: String) -> Control:
	for k in rf._pages:
		var c: Control = rf._pages[k].find_child(n, true, false)
		if c and c.is_visible_in_tree():
			return c
	for k in rf._pages:
		var c: Control = rf._pages[k].find_child(n, true, false)
		if c:
			return c
	return null


## Every visible Label / Button text under `root`.
func _visible_text(root: Node) -> String:
	var out := []
	for n in root.find_children("*", "", true, false):
		if n is Label and n.is_visible_in_tree():
			out.append(n.text)
		elif n is Button and n.is_visible_in_tree():
			out.append(n.text)
	return "\n".join(out)


func _any_texture_visible(root: Node) -> bool:
	for n in root.find_children("*", "TextureRect", true, false):
		if n.is_visible_in_tree() and n.texture != null:
			return true
	return false


func _above_fold(r: SocialReveal) -> bool:
	var vh := get_viewport().get_visible_rect().size.y
	for c in [r._cta, r._again, r._back]:
		if c.is_visible_in_tree() and c.get_global_rect().end.y > vh + 1.0:
			return false
	return r._column.get_global_rect().position.y >= -1.0


func _blocks(p: PuzzleDefinition) -> Array:
	var l := p.to_level()
	var out := []
	for b in l.blocks:
		out.append([b.id, b.cell, b.color, b.direction, b.kind, b.spin_rule, b.hidden, b.lock_color, b.rarity])
	return out


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
	return var_to_str([p.coins, p.best_scores, p.best_stars, p.highest_unlocked, p.highest_completed, p.current_level,
		p.inventory, p.total_score(), game.hints_used, game.undos_used, game.hammers_used, game.hearts])


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


func _jpeg(w: int, h: int) -> PackedByteArray:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color("#3A8EE8"))
	img.fill_rect(Rect2i(w / 4, h / 4, w / 2, h / 2), Color("#FFD23F"))
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
	if cond:
		passed += 1
	else:
		failures.append(msg)


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await _frames(3)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [shots_dir, name])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
