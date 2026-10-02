extends Node
## Challenge a Friend phase 3: creator flow + minimal recipient, end to end
## against tools/mock_social_api.py (started and stopped here).
##   godot --headless --path . res://tools/FriendFlowTest.tscn
##   (xvfb-run godot --path . --resolution 405x720 res://tools/FriendFlowTest.tscn -- --shots=/tmp/s)
## Every difficulty, SURPRISE ME (real difficulty stored, re-rolled by NEW
## CHALLENGE), NEW CHALLENGE (never the same board), backend retry with the
## SAME board, double taps, leaving mid-creation, creator PLAY / PREVIEW,
## share text + link, the recipient landing / exact board / completion /
## CHALLENGE A FRIEND loop, layouts, and Classic isolation.

const PROGRESS_PATH := "user://friend_flow_test_progress.cfg"
const PORT := 8799

var game: GameManager
var social: SocialScreen
var fc: FriendCreator
var play: SocialPlay
var failures: Array[String] = []
var passed := 0
var shots_dir := ""
var _pid := -1
var _base := "http://127.0.0.1:%d/" % PORT
var _save_at_start := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	_run.call_deferred()


func _run() -> void:
	_test_share_text()
	_pid = OS.create_process("python3", [ProjectSettings.globalize_path("res://tools/mock_social_api.py"), "--port", str(PORT)])
	SocialConfig.api_url_override = _base
	SocialConfig.share_base_override = "https://test.chainescape.example/play/"
	if not await _wait_health():
		_check(false, "mock API did not start")
		_finish()
		return
	# A Classic player at Level 7, mid-level (must survive everything).
	await _new_game("", true)
	for n in range(1, 7):
		game.progress.record_result(n, 1000 + n, 3)
	game.progress.coins = 42
	game.progress.current_level = 7
	game.progress.save()
	await _new_game("", false)
	game.continue_game()
	await _frames(3)
	for id in game.model.blocks.keys():
		if game.model.move_state(id) == "ok":
			game.board.block_tapped.emit(id)
			break
	await _wait(0.8)
	var classic := _classic()
	game.return_to_main_menu()
	await _frames(2)
	var snap := _snapshot()
	_save_at_start = FileAccess.get_file_as_string(PROGRESS_PATH)

	await _open_friend()
	await _test_choose_screen()
	var links := await _test_each_difficulty()
	await _test_surprise()
	await _test_new_challenge()
	await _test_backend_retry()
	await _test_new_challenge_failure()
	await _test_double_tap_and_leave()
	var hard_link: Dictionary = links.get("hard", {})
	await _test_creator_preview()
	await _test_recipient(hard_link)

	# Classic: untouched by all of it.
	# (Each game launch rewrites [meta] seq / time; the progress itself must not change.)
	_check(_body(FileAccess.get_file_as_string(PROGRESS_PATH)) == _body(_save_at_start), "Classic save contents untouched by Challenge a Friend")
	await _new_game("", false)
	game.continue_game()
	await _frames(3)
	_check(game.current_level == 7 and _snapshot().begins_with(snap.get_slice("|", 0)), "Classic progress (level 7, coins, stars) unchanged")
	_check(game.ui._hint_button.text == "SHOW A MOVE" and game.ui._hammer_button.text == "HAMMER", "Classic HUD: SHOW A MOVE (same label as Social), HAMMER")
	await _shot("F10_classic_hud")
	_finish()


func _finish() -> void:
	_free_game()
	if _pid > 0:
		OS.kill(_pid)
	print("FRIEND FLOW TEST: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# --- Tests --------------------------------------------------------------------------

func _test_share_text() -> void:
	_check(SocialConfig.friend_share_text("hard") == "I made a HARD Chain Escape for you 🔗\nCan you escape it?", "share text (HARD)")
	_check(SocialConfig.friend_share_text("very_hard") == "I made a VERY HARD Chain Escape for you 🔗\nCan you escape it?", "share text (VERY HARD)")


func _open_friend() -> void:
	social = game.ui._title._social
	fc = social.friend
	play = social.play
	game.ui._title._open_social()
	await _frames(3)
	await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Friend", true, false))
	await _wait(0.3)
	_check(social.page == SocialScreen.Page.CHALLENGE_FRIEND and fc.visible and fc.step == FriendCreator.Step.CHOOSE,
		"CHALLENGE A FRIEND card opens the difficulty choice")


func _test_choose_screen() -> void:
	var box: Control = fc._steps[FriendCreator.Step.CHOOSE]
	var names := ["Difficulty_easy", "Difficulty_medium", "Difficulty_hard", "Difficulty_very_hard", "SurpriseMe", "Back"]
	var prev := -INF
	var vis := get_viewport().get_visible_rect()
	for n in names:
		var c: Control = box.find_child(n, true, false)
		_check(c != null and c.is_visible_in_tree() and vis.encloses(c.get_global_rect()) and c.get_global_rect().position.y > prev,
			"choice screen: %s shown, on screen, in order" % n)
		if c:
			prev = c.get_global_rect().position.y
	_check(not box.find_child("Continue", true, false) and not box.find_child("Generate", true, false), "no CONTINUE / GENERATE button")
	await _shot("F1_choose")


## One tap on each difficulty -> READY with that difficulty, created on the
## server with the exact board. Returns {difficulty: {id, fp, url}}.
func _test_each_difficulty() -> Dictionary:
	var out := {}
	for d in FriendGenerator.DIFFICULTIES:
		var before: int = (await _get_json("__count"))["count"]
		await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Difficulty_" + d, true, false), 0.0)
		_check(fc.step == FriendCreator.Step.CREATING and fc._c_title.text.begins_with("CREATING YOUR"), "%s: CREATING YOUR CHALLENGE… straight away" % d)
		if d == "very_hard":
			await _shot("F2_creating")
		await _until(func(): return fc.step == FriendCreator.Step.READY or fc.failed != "", 15.0)
		_check(fc.step == FriendCreator.Step.READY and fc.current != null, "%s: CHALLENGE READY (%s)" % [d, fc.last_error])
		if fc.current == null:
			continue
		var c := fc.current
		_check(c.type == "friend_challenge" and c.difficulty == d and not c.is_surprise(), "%s: friend challenge, difficulty %s, not a surprise" % [d, d])
		_check(FriendGenerator.mechanics_ok(c.puzzle, d) and c.puzzle.verify() and not FriendGenerator.is_classic_board(c.puzzle),
			"%s: valid generated board (not a campaign level)" % d)
		_check((await _get_json("__count"))["count"] == before + 1, "%s: exactly one CREATE" % d)
		var id := ShareLink.parse(fc.share_url)
		_check(fc.share_url == "https://test.chainescape.example/play/?challenge=" + id and ShareLink.is_valid_id(id), "%s: link carries only the id" % d)
		var stored = (await _get_json("?action=read&id=" + id))["challenge"]
		_check(PuzzleDefinition.from_dict(stored["puzzle"]).fingerprint() == c.puzzle.fingerprint() and stored["difficulty"] == d
			and stored["payload"] == {}, "%s: server stores the exact board, the real difficulty, no surprise flag" % d)
		_check(fc._r_sub.text == "%s CHALLENGE" % FriendCreator.NAMES[d], "%s: READY says '%s CHALLENGE'" % [d, FriendCreator.NAMES[d]])
		_check_ready_layout(d)
		out[d] = {"id": id, "fp": c.puzzle.fingerprint(), "url": fc.share_url}
		if d == "hard":
			await _shot("F3_ready_hard")
		await _tap(fc._steps[FriendCreator.Step.READY].find_child("Done", true, false))
		_check(social.page == SocialScreen.Page.CHOICE and not fc.visible, "%s: DONE -> CREATE CHALLENGE" % d)
		await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Friend", true, false))
		await _wait(0.3)
	return out


func _check_ready_layout(d: String) -> void:
	var box: Control = fc._steps[FriendCreator.Step.READY]
	var vis := get_viewport().get_visible_rect()
	var prev := -INF
	for n in ["SendWhatsApp", "ShareChallenge", "CopyLink", "NewChallenge", "Done"]:
		var c: Control = box.find_child(n, true, false)
		var ok := c != null and c.is_visible_in_tree() and vis.encloses(c.get_global_rect()) and c.get_global_rect().position.y > prev + 1.0
		_check(ok, "%s READY: %s on screen, in order" % [d, n])
		if c:
			prev = c.get_global_rect().position.y
	var pv: Control = box.find_child("PreviewChallenge", true, false)
	_check(pv.is_visible_in_tree() and vis.encloses(pv.get_global_rect()), "%s READY: PLAY / PREVIEW on screen" % d)


func _test_surprise() -> void:
	fc.rng.seed = 12345
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("SurpriseMe", true, false))
	await _until(func(): return fc.step == FriendCreator.Step.READY or fc.failed != "", 15.0)
	var c := fc.current
	_check(c != null and c.difficulty in FriendGenerator.DIFFICULTIES and c.is_surprise() and fc.choice == FriendGenerator.SURPRISE,
		"SURPRISE ME: a real difficulty, remembered as a surprise")
	if c == null:
		return
	_check(fc._r_sub.text == "SURPRISE PICK: " + FriendCreator.NAMES[c.difficulty] and fc._r_icon_dice.visible, "READY: 'SURPRISE PICK: %s' + dice" % FriendCreator.NAMES[c.difficulty])
	var stored = (await _get_json("?action=read&id=" + ShareLink.parse(fc.share_url)))["challenge"]
	_check(stored["difficulty"] == c.difficulty and stored["payload"] == {"surprise_me": true}, "stored: real difficulty + surprise_me flag")
	var text := SocialConfig.friend_share_text(c.difficulty)
	_check(not text.to_lower().contains("surprise") and text.contains(FriendCreator.NAMES[c.difficulty]), "share text names the real difficulty, never SURPRISE")
	await _shot("F4_ready_surprise")
	# NEW CHALLENGE -> the choice -> SURPRISE ME again: a new roll each time.
	var diffs := {c.difficulty: true}
	var keys := {FriendGenerator.board_key(c.puzzle): true}
	for i in 6:
		await _new_challenge_to_choice("surprise #%d" % i)
		await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("SurpriseMe", true, false))
		await _until(func(): return fc.step == FriendCreator.Step.READY and not fc.busy, 15.0)
		diffs[fc.current.difficulty] = true
		keys[FriendGenerator.board_key(fc.current.puzzle)] = true
		_check(fc.current.is_surprise() and fc._r_sub.text.begins_with("SURPRISE PICK: "), "SURPRISE ME again #%d: still a surprise" % i)
	_check(diffs.size() >= 2, "SURPRISE ME re-rolls the difficulty each time (%s)" % str(diffs.keys()))
	_check(keys.size() == 7, "7 surprise challenges, 7 different boards")
	await _tap(fc._steps[FriendCreator.Step.READY].find_child("Done", true, false))


func _test_new_challenge() -> void:
	await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Friend", true, false))
	await _wait(0.3)
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Difficulty_medium", true, false))
	await _until(func(): return fc.step == FriendCreator.Step.READY, 15.0)
	var keys := {FriendGenerator.board_key(fc.current.puzzle): true}
	var first_url := fc.share_url
	var first_fp := fc.current.puzzle.fingerprint()
	# NEW CHALLENGE -> the choice; BACK there returns to the same challenge.
	await _new_challenge_to_choice("first")
	await _shot("F4b_new_challenge_choice")
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Back", true, false))
	_check(fc.visible and fc.step == FriendCreator.Step.READY and fc.share_url == first_url and fc.current.puzzle.fingerprint() == first_fp,
		"BACK on the choice -> the previous CHALLENGE READY, same link and board")
	# Each NEW CHALLENGE + a difficulty: a new board, never one shown before.
	var picks := ["medium", "medium", "hard", "medium"]
	for i in picks.size():
		await _new_challenge_to_choice("#%d" % i)
		await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Difficulty_" + picks[i], true, false))
		await _until(func(): return fc.step == FriendCreator.Step.READY and not fc.busy, 15.0)
		_check(fc.current.difficulty == picks[i] and not fc.current.is_surprise() and fc._r_sub.text == "%s CHALLENGE" % FriendCreator.NAMES[picks[i]],
			"NEW CHALLENGE #%d + %s -> a %s challenge" % [i, picks[i], picks[i]])
		keys[FriendGenerator.board_key(fc.current.puzzle)] = true
	_check(keys.size() == 5 and fc.seen_keys.size() == 5, "5 challenges, 5 different boards (never repeated in the session)")
	_check(fc.share_url != first_url, "a NEW CHALLENGE has its own link")
	var old = (await _get_json("?action=read&id=" + ShareLink.parse(first_url)))["challenge"]
	_check(PuzzleDefinition.from_dict(old["puzzle"]).fingerprint() == first_fp, "the earlier link still reads its own exact board")


## A failed CREATE keeps the exact puzzle; TRY AGAIN resends it.
func _test_backend_retry() -> void:
	await _tap(fc._steps[FriendCreator.Step.READY].find_child("Done", true, false))
	await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Friend", true, false))
	await _wait(0.3)
	await _post("__mode", {"fail_next": "500"})
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Difficulty_hard", true, false))
	await _until(func(): return fc.failed != "" or fc.step == FriendCreator.Step.READY, 15.0)
	_check(fc.failed == "create" and fc.step == FriendCreator.Step.CREATING and fc._c_title.text == "COULDN'T GET YOUR\nLINK READY"
		and fc._c_retry.is_visible_in_tree() and fc._c_back.is_visible_in_tree(), "server failure: COULDN'T GET YOUR LINK READY + TRY AGAIN + BACK")
	_check(not fc._c_status.text.contains("internal"), "no raw server text")
	await _shot("F5_link_error")
	var kept := fc.pending.puzzle.fingerprint()
	var failed_body = await _get_json("__last")
	await _tap(fc._c_retry)
	await _until(func(): return fc.step == FriendCreator.Step.READY, 15.0)
	var resent = await _get_json("__last")
	_check(fc.step == FriendCreator.Step.READY and fc.current.puzzle.fingerprint() == kept
		and PuzzleDefinition.from_dict(resent["puzzle"]).fingerprint() == kept
		and PuzzleDefinition.from_dict(failed_body["puzzle"]).fingerprint() == kept, "TRY AGAIN resends the SAME exact puzzle")
	# Generation failure (forced): its own message, TRY AGAIN generates again.
	await _tap(fc._steps[FriendCreator.Step.READY].find_child("Done", true, false))
	await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Friend", true, false))
	await _wait(0.3)
	fc.choice = "easy"
	fc.show_step(FriendCreator.Step.CREATING)
	fc._fail("generate", "no_solvable_board")
	await _frames(2)
	_check(fc._c_title.text == "COULDN'T CREATE\nA CHALLENGE" and fc._c_retry.is_visible_in_tree() and fc._c_back.is_visible_in_tree(),
		"generation failure: COULDN'T CREATE A CHALLENGE + TRY AGAIN + BACK")
	await _tap(fc._c_retry)
	await _until(func(): return fc.step == FriendCreator.Step.READY, 15.0)
	_check(fc.current != null and fc.current.difficulty == "easy", "TRY AGAIN after a generation failure creates a challenge")


## The next challenge fails -> the previous challenge and link stay:
## BACK (error) -> the choice, BACK (choice) -> the previous READY.
func _test_new_challenge_failure() -> void:
	var prev_url := fc.share_url
	var prev_fp := fc.current.puzzle.fingerprint()
	await _post("__mode", {"fail_next": "500"})
	await _new_challenge_to_choice("before a failure")
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Difficulty_medium", true, false))
	await _until(func(): return fc.failed != "", 15.0)
	_check(fc.failed == "create" and fc.current.puzzle.fingerprint() == prev_fp and fc.share_url == prev_url,
		"next challenge failed: the previous challenge and link are still there")
	await _tap(fc._c_back)
	_check(fc.step == FriendCreator.Step.CHOOSE and not fc.busy and fc.failed == "", "BACK on the error -> the difficulty choice")
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Back", true, false))
	_check(fc.step == FriendCreator.Step.READY and fc.share_url == prev_url and fc.current.puzzle.fingerprint() == prev_fp,
		"BACK -> the previous CHALLENGE READY, same link and board")


func _test_double_tap_and_leave() -> void:
	await _tap(fc._steps[FriendCreator.Step.READY].find_child("Done", true, false))
	await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Friend", true, false))
	await _wait(0.3)
	var before: int = (await _get_json("__count"))["count"]
	fc.pick("easy")
	fc.pick("easy")
	fc.pick("hard")
	await _until(func(): return fc.step == FriendCreator.Step.READY, 15.0)
	await _wait(0.5)
	_check((await _get_json("__count"))["count"] == before + 1 and fc.current.difficulty == "easy", "double taps create exactly one challenge")
	# Leave while the server is still answering: the late reply is ignored.
	await _tap(fc._steps[FriendCreator.Step.READY].find_child("Done", true, false))
	await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Friend", true, false))
	await _wait(0.3)
	await _post("__mode", {"fail_next": "timeout"})  # the mock answers after 6 s
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Difficulty_easy", true, false))
	await _until(func(): return fc.generator == null and fc.busy, 10.0)
	await _tap(fc._c_back)
	_check(fc.step == FriendCreator.Step.CHOOSE and fc.current == null and not fc.busy, "BACK during creation -> difficulty choice")
	await _wait(6.8)
	_check(fc.step == FriendCreator.Step.CHOOSE and fc.current == null and fc.failed == "", "the late server reply changes nothing")


## PLAY / PREVIEW: the exact created board; nothing about the challenge changes.
func _test_creator_preview() -> void:
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Difficulty_medium", true, false))
	await _until(func(): return fc.step == FriendCreator.Step.READY, 15.0)
	var url := fc.share_url
	var fp := fc.current.puzzle.fingerprint()
	var gens := FriendGenerator.created
	await _tap(fc._steps[FriendCreator.Step.READY].find_child("PreviewChallenge", true, false))
	_check(play.visible and play.mode == SocialPlay.Mode.CREATOR_PREVIEW and play.loaded_fingerprint == fp
		and play._title.text == "FRIEND CHALLENGE" and play._chip.text == "MEDIUM", "PLAY / PREVIEW: the exact created board (FRIEND CHALLENGE, MEDIUM)")
	await _shot("F6_preview")
	await _tap(play._exit)
	await _tap(play._confirm.find_child("Leave", true, false))
	_check(not play.visible and fc.step == FriendCreator.Step.READY and fc.share_url == url, "EXIT -> CHALLENGE READY, link kept")
	await _tap(fc._steps[FriendCreator.Step.READY].find_child("PreviewChallenge", true, false))
	await _solve()
	_check(play.reveal.visible and play.reveal._heading.text == "YOU ESCAPED!" and play.reveal._again.is_visible_in_tree()
		and play.reveal._back.text == "BACK TO SHARE" and not play.reveal._cta.is_visible_in_tree()
		and not play.reveal._photo_frame.visible and not play.reveal._message_card.visible, "preview solved: YOU ESCAPED! + PLAY AGAIN + BACK TO SHARE")
	await _shot("F7_preview_solved")
	await _tap(play.reveal._again)
	_check(play.loaded_fingerprint == fp and play.plays == 2, "PLAY AGAIN: same exact board")
	await _solve()
	await _tap(play.reveal._back)
	_check(not play.visible and fc.step == FriendCreator.Step.READY and fc.share_url == url and fc.current.puzzle.fingerprint() == fp,
		"BACK TO SHARE -> the same CHALLENGE READY")
	_check(FriendGenerator.created == gens, "previewing never generates")


## Phone B: the link -> Friend landing -> exact board -> completion ->
## CHALLENGE A FRIEND -> a new challenge of their own.
func _test_recipient(info: Dictionary) -> void:
	var gens := FriendGenerator.created
	await _new_game(info["id"], false)
	await _until(func(): return social.recipient.state != RecipientFlow.State.LOADING, 10.0)
	var rf := social.recipient
	_check(rf.state == RecipientFlow.State.LANDING and rf._l_title.text == "YOUR FRIEND\nCHALLENGED YOU"
		and rf._l_sub.text == "Can you escape this HARD\nChain Escape?" and rf._l_block.visible and not rf._l_gift.visible
		and not rf._l_chip.visible, "recipient landing: YOUR FRIEND CHALLENGED YOU / Can you escape this HARD Chain Escape?")
	await _shot("F8_recipient_landing")
	await _tap(rf._pages[RecipientFlow.State.LANDING].find_child("Play", true, false))
	_check(play.visible and play.mode == SocialPlay.Mode.RECIPIENT and play.loaded_fingerprint == info["fp"]
		and play._title.text == "FRIEND CHALLENGE" and play._chip.text == "HARD", "PLAY: the creator's exact board (HARD)")
	await _test_tools(info["fp"])
	await _solve()
	var r := play.reveal
	_check(r.visible and r._heading.text == "YOU ESCAPED!" and r._cta.is_visible_in_tree() and r._cta.text.strip_edges() == "CHALLENGE A FRIEND"
		and not r._cta_line.visible and r._again.is_visible_in_tree() and r._back.text == "MAIN MENU", "completion: YOU ESCAPED! + CHALLENGE A FRIEND + PLAY AGAIN + MAIN MENU")
	_check(not r._photo_frame.visible and not r._photo_status.visible and not r._message_card.visible, "completion: nothing to reveal, no empty frames")
	var vh := get_viewport().get_visible_rect().size.y
	_check(r._cta.get_global_rect().end.y <= vh and r._back.get_global_rect().end.y <= vh, "completion fits on screen")
	await _wait(1.6)
	await _shot("F9_recipient_done")
	# Use a Hammer, then PLAY AGAIN: the same board, both Hammers back.
	var plays_before := play.plays
	await _tap(r._again)
	_check(play.loaded_fingerprint == info["fp"] and play.plays == plays_before + 1, "PLAY AGAIN: same exact board")
	await _tap(play._hammer)
	var sid := _safe_block()
	play.tap_block(sid)
	await _wait(0.4)
	_check(play.hammers_used == 1, "a Hammer used on the replay")
	await _solve()
	await _tap(play.reveal._again)
	_check(play.hammers_used == 0 and not play.hammer_armed and play._hammer.badge_text == "2" and play.loaded_fingerprint == info["fp"],
		"PLAY AGAIN: Hammer x2 again, same board")
	await _solve()
	await _solve()
	_check(FriendGenerator.created == gens, "the recipient never generates a board")
	await _tap(play.reveal._cta)
	_check(social.page == SocialScreen.Page.CHALLENGE_FRIEND and social.friend.step == FriendCreator.Step.CHOOSE and not play.visible,
		"CHALLENGE A FRIEND -> the Friend creator")
	fc = social.friend
	await _tap(fc._steps[FriendCreator.Step.CHOOSE].find_child("Difficulty_easy", true, false))
	await _until(func(): return fc.step == FriendCreator.Step.READY, 15.0)
	_check(fc.current != null and ShareLink.parse(fc.share_url) != info["id"], "phone B made its own challenge: a new link")


# --- Tools: UNDO x3, SHOW A MOVE x2, HAMMER x2 (free, per attempt) ----------------

func _test_tools(fp: String) -> void:
	var prog := game.progress
	var econ := var_to_str([prog.coins, prog.inventory, prog.best_scores, prog.current_level])
	var vis := get_viewport().get_visible_rect()
	var row: Array[Control] = [play._undo, play._hint, play._hammer, play._restart]
	var ok_row := true
	for i in row.size():
		ok_row = ok_row and row[i].is_visible_in_tree() and vis.encloses(row[i].get_global_rect())
		if i > 0:
			ok_row = ok_row and row[i].get_global_rect().position.x >= row[i - 1].get_global_rect().end.x
	_check(ok_row, "tool row: UNDO, SHOW A MOVE, HAMMER, RESTART on screen, side by side")
	_check(play._undo.badge_text == "3" and play._hint.text == "SHOW A MOVE" and play._hint.badge_text == "2", "UNDO x3, SHOW A MOVE x2")
	_check(play._hammer.text == "HAMMER" and play._hammer.badge_text == "2" and play._hammer.modulate.a == 1.0 and not play._hammer.disabled,
		"HAMMER x2, active from the start (not greyed out)")
	await _shot("F8b_tools")
	# SHOW A MOVE: highlights the Solver's move, never plays it.
	var before := var_to_str(play.model.snapshot())
	var expect := Solver.from_model(play.model).recommend_move()
	await _tap(play._hint)
	var hinted := []
	for id in play.model.blocks.keys():
		if play.board.get_view(id).hinted:
			hinted.append(id)
	_check(hinted == [expect] and var_to_str(play.model.snapshot()) == before and play.hints_used == 1 and play._hint.badge_text == "1",
		"SHOW A MOVE highlights one valid move (the Solver's) and plays nothing")
	# Arm, then CANCEL: nothing spent.
	await _tap(play._hammer)
	_check(play.hammer_armed and play.board.hammer_mode and play._hammer.text == "CANCEL", "HAMMER arms (button reads CANCEL)")
	await _shot("F8c_hammer_armed")
	await _tap(play._hammer)
	_check(not play.hammer_armed and not play.board.hammer_mode and play.hammers_used == 0 and play._hammer.badge_text == "2", "CANCEL: nothing spent")
	# A rejected smash (one that would make the board unsolvable), if any.
	var unsafe := -1
	for id in play.model.blocks.keys():
		if not Solver.hammer_safe(play.model, id):
			unsafe = id
			break
	print("[FriendFlowTest] refused-smash case: %s" % ("block %d" % unsafe if unsafe != -1 else "none on this board"))
	if unsafe != -1:
		await _tap(play._hammer)
		before = var_to_str(play.model.snapshot())
		play.tap_block(unsafe)
		await _wait(0.3)
		_check(var_to_str(play.model.snapshot()) == before and play.hammer_armed and play.hammers_used == 0,
			"a smash that would make the board unsolvable is refused: nothing spent, still armed")
		await _tap(play._hammer)
	else:
		passed += 1  # (every block on this board is safe to smash)
	# Smash 1: exactly BoardModel.remove (spinners next to it turn as on an escape).
	await _tap(play._hammer)
	var sid := _safe_block()
	var expected := BoardModel.new()
	expected.setup(play.model.rows, play.model.columns, play.model.snapshot())
	expected.remove(sid)
	var count := play.model.block_count()
	play.tap_block(sid)
	await _wait(0.5)
	_check(not play.model.blocks.has(sid) and play.model.block_count() == count - 1 and var_to_str(play.model.snapshot()) == var_to_str(expected.snapshot()),
		"smash removes the block; the board changes exactly as the Classic Hammer rule says")
	_check(play.hammers_used == 1 and play._hammer.badge_text == "1" and not play.hammer_armed and play._hammer.text == "HAMMER", "Hammer x1 left")
	_check(Solver.from_model(play.model).is_solvable(), "the board is still solvable after the smash")
	# Undo brings the block back; the Hammer is not refunded (as in Classic).
	await _tap(play._undo)
	_check(play.model.blocks.has(sid) and play.hammers_used == 1 and play.undos_used == 1, "UNDO brings the smashed block back (Hammer not refunded)")
	# Smash 2, then none left.
	await _tap(play._hammer)
	play.tap_block(_safe_block())
	await _wait(0.5)
	_check(play.hammers_used == 2 and play._hammer.badge_text == "0" and play._hammer.modulate.a < 1.0, "Hammer x0 left")
	await _tap(play._hammer)
	_check(not play.hammer_armed and play._message.text.begins_with("No Hammers left"), "no third Hammer")
	_check(Solver.from_model(play.model).is_solvable(), "still solvable after two smashes")
	_check(play.challenge.puzzle.fingerprint() == fp and play.loaded_fingerprint == fp, "the shared PuzzleDefinition is untouched by smashes")
	# RESTART: the exact board, every tool back.
	await _tap(play._restart)
	_check(play.loaded_fingerprint == fp and play.hammers_used == 0 and play.hints_used == 0 and play.undos_used == 0
		and play._hammer.badge_text == "2" and play._hint.badge_text == "2" and play._undo.badge_text == "3" and play.model.block_count() == play._total_blocks,
		"RESTART: same exact board, UNDO x3 / SHOW A MOVE x2 / HAMMER x2 again")
	_check(var_to_str([prog.coins, prog.inventory, prog.best_scores, prog.current_level]) == econ,
		"Classic coins, Hammer / boosters and progress untouched by the tools")


func _safe_block() -> int:
	var ids := play.model.blocks.keys()
	ids.sort()
	for id in ids:
		if Solver.hammer_safe(play.model, id):
			return id
	return -1


# --- Helpers ------------------------------------------------------------------------

## NEW CHALLENGE on READY: back to the difficulty choice, nothing generated
## or created by the tap itself.
func _new_challenge_to_choice(what: String) -> void:
	var gens := FriendGenerator.created
	var count: int = (await _get_json("__count"))["count"]
	var url := fc.share_url
	await _tap(fc._steps[FriendCreator.Step.READY].find_child("NewChallenge", true, false))
	await _wait(0.4)
	_check(fc.step == FriendCreator.Step.CHOOSE and not fc.busy and fc.generator == null and FriendGenerator.created == gens
		and (await _get_json("__count"))["count"] == count and fc.share_url == url,
		"NEW CHALLENGE (%s) -> the difficulty choice, nothing generated" % what)

func _new_game(link: String, skip: bool) -> void:
	_free_game()
	SocialWeb.launch_override = link
	GameManager.skip_title = skip
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	SocialWeb.launch_override = ""
	social = game.ui._title._social
	fc = social.friend
	play = social.play
	AudioManager.set_music_enabled(false)
	await _frames(3)


func _free_game() -> void:
	if game and is_instance_valid(game):
		game.get_parent().remove_child(game)
		game.free()
	game = null


func _solve() -> void:
	var guard := 0
	while not play.completed and guard < 300:
		play.play_solver_move()
		await _wait(0.1)
		guard += 1
	await _until(func(): return play.reveal.visible, 5.0)
	await _wait(0.9)


func _body(save: String) -> String:
	return save.substr(save.find("[progress]"))


func _classic() -> String:
	var out := []
	var ids := game.model.blocks.keys()
	ids.sort()
	for id in ids:
		out.append([id, game.model.blocks[id].cell, game.model.blocks[id].direction])
	return var_to_str([game.current_level, out])


func _snapshot() -> String:
	var p := game.progress
	return var_to_str([p.coins, p.best_scores, p.best_stars, p.highest_unlocked, p.current_level, p.inventory]) + "|"


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


func _tap(c: Control, settle := 0.3) -> void:
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
	if settle > 0.0:
		await _wait(settle)


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
