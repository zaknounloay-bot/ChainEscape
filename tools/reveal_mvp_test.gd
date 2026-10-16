extends Node
## Phase 4: Photo / Message Reveal experience MVP, in the real game (Main
## scene, title -> Social, the game's own creator and SocialPlay):
##   A. generator: 4x4, 4-6 blocks, no spinners, at most ONE special
##      mechanic (Armor only; Portal / Twins off), every reachable position
##      solvable, verified from its JSON, deterministic, never a campaign
##      board; Armor boards: the hit is there from the first move;
##   B. creator: no difficulty step (PHOTO -> MESSAGE -> REVIEW), always
##      "easy", the 200-unit message rule as the server counts it;
##   C. the Armor first encounter: no separate intro card; finger and
##      brackets on the block aimed at the shell, nothing played for the
##      player, kept through RESTART, finished only by the player's hit;
##   D. the reveal moment: photo + message, photo only, message only,
##      a photo still loading: gift box -> envelope -> card (~2.45 s),
##      "SURPRISE UNLOCKED!", buttons inactive until done,
##      tap-to-skip, reduced motion; Friend Challenge's result unchanged;
##   E. messages: Hebrew / Arabic shaping and direction kept, the larger
##      emoji set drawn, unsupported emoji reported;
##   F. an older 12-block reveal link plays its exact stored board;
##   G. no timer / difficulty / competitive UI in a reveal; Classic untouched.
##
##   godot --headless --path . res://tools/RevealMvpTest.tscn

const PROGRESS_PATH := "user://reveal_mvp_test_progress.cfg"

var game: GameManager
var social: SocialScreen
var play: SocialPlay
var failures: Array[String] = []
var passes := 0


func _ready() -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	SocialConfig.api_url_override = "off"
	_run.call_deferred()


func _run() -> void:
	_test_generator()
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	game.start_level(4)
	await _frames(3)
	game.return_to_main_menu()
	await _frames(3)
	var before := _snapshot()
	var file_before := FileAccess.get_file_as_string(PROGRESS_PATH)
	social = game.ui._title._social
	play = social.play
	social.open(game.ui.theme)
	await _frames(3)

	await _test_creator()
	await _test_armor_lesson()
	await _test_reveal_moment()
	_test_messages()
	await _test_old_link()

	play.end()
	social.close()
	await _frames(3)
	_check(_snapshot() == before and FileAccess.get_file_as_string(PROGRESS_PATH) == file_before, "G. Classic progress and save file untouched")
	for f in failures:
		print("FAIL " + f)
	print("\n%d passed, %d failed" % [passes, failures.size()])
	print("REVEAL MVP TEST PASSED" if failures.is_empty() else "REVEAL MVP TEST FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


# --- A. Generator -----------------------------------------------------------------

func _test_generator() -> void:
	var sizes_ok := true
	var one_special := true
	var no_spinners := true
	var trap_free := true
	var verified := true
	var classic := false
	var armor := 0
	var armor_ok := true
	var counts := {}
	var n := 120
	SocialGenerator.force_special = ""
	for seed in range(1, n + 1):
		var g := SocialGenerator.new(SocialGenerator.REVEAL, seed)
		var p := g.run()
		if p == null:
			verified = false
			continue
		var level := p.to_level()
		var b := p.block_count()
		counts[b] = counts.get(b, 0) + 1
		sizes_ok = sizes_ok and p.rows == 4 and p.columns == 4 and b >= 4 and b <= 6
		var armored := level.blocks.filter(func(x): return x.armored).size()
		var special := 1 if armored > 0 else 0
		special += 1 if not level.portals.is_empty() else 0
		special += 1 if level.blocks.any(func(x): return x.twin != "") else 0
		one_special = one_special and special <= 1 and armored <= 1
		no_spinners = no_spinners and not level.blocks.any(func(x): return x.is_spinner() or x.hidden or x.lock_color != "" or x.switch_group != "" or x.magnet or x.seq_stage != 0)
		trap_free = trap_free and SocialGenerator.trap_free(level)
		var again := PuzzleDefinition.from_json(p.to_json())
		verified = verified and again != null and again.verify() and again.fingerprint() == p.fingerprint()
		classic = classic or FriendGenerator.is_classic_board(p)
		if armored == 1:
			armor += 1
			var m := BoardModel.new()
			m.setup(level.rows, level.columns, level.blocks)
			armor_ok = armor_ok and m.blocks.keys().any(func(id): return m.move_state(id) == "ram")
	_check(sizes_ok, "A. %d reveals: all 4x4 with 4-6 blocks %s" % [n, str(counts)])
	_check(one_special, "A. at most ONE special mechanic, at most one armored block; no portals, no twins")
	_check(no_spinners, "A. no spinners, hidden, locks, switches, magnets or Sequence blocks")
	_check(trap_free, "A. every reachable position of every board can still be cleared (no dead ends)")
	_check(verified, "A. every board verifies from its own JSON (as a recipient rebuilds it)")
	_check(not classic, "A. never a campaign board")
	_check(armor >= n * 0.25 and armor <= n * 0.55, "A. Armor on %d of %d reveals (about 40%%)" % [armor, n])
	_check(armor_ok, "A. Armor boards: the hit is available from the first move")
	_check(SocialGenerator.new(SocialGenerator.REVEAL, 77).run().fingerprint() == SocialGenerator.new(SocialGenerator.REVEAL, 77).run().fingerprint(), "A. same seed, same board")
	SocialGenerator.force_special = "armor"
	var forced := SocialGenerator.new(SocialGenerator.REVEAL, 5).run()
	SocialGenerator.force_special = "none"
	var plain := SocialGenerator.new(SocialGenerator.REVEAL, 5).run()
	SocialGenerator.force_special = ""
	_check(SocialGenerator.special_of(forced) == "armor" and SocialGenerator.special_of(plain) == "", "A. forced Armor / plain boards for tests")
	_check(SocialGenerator.REVEAL_MECHANICS == ["armor"], "A. Portal and Twins stay disabled (puzzle format / parser blockers)")


# --- B. Creator -------------------------------------------------------------------

func _test_creator() -> void:
	var cr := social.creator
	social.show_page(SocialScreen.Page.PHOTO_REVEAL)
	await _frames(3)
	_check(cr.visible and cr.step == RevealCreator.Step.CHOOSE, "B. the creator opens on PHOTO")
	_check(cr.find_child("Difficulty_easy", true, false) == null and cr.find_child("EditDifficulty", true, false) == null
		and cr.find_child("ReviewDifficulty", true, false) == null, "B. no difficulty buttons anywhere")
	cr.receive_photo(_jpeg(900, 1600, Color("#3A7BE8")))
	await _frames(2)
	_check(cr.step == RevealCreator.Step.PREVIEW, "B. a chosen photo goes to its confirmation (PREVIEW)")
	_find(cr, "UsePhoto").pressed.emit()
	await _frames(2)
	_check(cr.step == RevealCreator.Step.MESSAGE and cr.session.has_photo(), "B. USE THIS PHOTO -> MESSAGE")
	cr.set_draft("Happy birthday! 🎉")
	_find(cr, "Continue").pressed.emit()
	await _frames(2)
	_check(cr.step == RevealCreator.Step.REVIEW, "B. MESSAGE -> REVIEW directly (no difficulty step)")
	_check(_step_text(cr) == "STEP 3 OF 3  ·  REVIEW", "B. REVIEW is step 3 of 3 (\"%s\")" % _step_text(cr))
	_check(cr.session.difficulty == "easy" and cr.session.is_valid(), "B. the session is always \"easy\" and valid")
	cr._back()
	await _frames(2)
	_check(cr.step == RevealCreator.Step.MESSAGE, "B. BACK from REVIEW -> MESSAGE")
	cr.set_draft("")
	_find(cr, "SkipMessage").pressed.emit()
	await _frames(2)
	_check(cr.step == RevealCreator.Step.REVIEW and not cr.session.has_message() and cr.session.has_photo(), "B. photo only: SKIP -> REVIEW")
	# Generation (no backend in this test): plays the new puzzle at once.
	var got: Array = []
	var cb := func(c): got.append(c)
	cr.play_requested.connect(cb)
	cr.debug_seed = 11
	cr._create()
	for i in 60:
		await _frames(1)
		if not got.is_empty():
			break
	cr.play_requested.disconnect(cb)
	var c: SharedChallenge = got[0] if not got.is_empty() else null
	_check(c != null and c.difficulty == "easy" and c.puzzle.rows == 4 and c.puzzle.columns == 4 and c.puzzle.block_count() <= 6 and c.puzzle.block_count() >= 4,
		"B. CREATE makes a 4x4, 4-6 block puzzle stored as \"easy\"")
	await _frames(3)
	play.end()
	# The message rule as the server counts it (UTF-16 units).
	var emoji := "🎉".repeat(150)
	var cleaned := CreatorSession.clean_message(emoji)
	_check(CreatorSession.utf16_length(cleaned) <= 200 and CreatorSession.utf16_length(cleaned) >= 199 and cleaned.length() == 100, "B. 150 emoji are cut to 100 (200 units, as the server counts)")
	_check(CreatorSession.utf16_left("ab🎉", 3) == "ab", "B. a cut never splits an emoji")
	_check(CreatorSession.clean_message("Hi " + String.chr(0xFFFD)) == "Hi", "B. half an emoji from the Web field is dropped")
	var s := CreatorSession.new()
	s.message = "x".repeat(201)
	_check(s.validate().has("message_too_long") and cr._error_text(s.validate()).begins_with("The message is too long"), "B. a too-long message is refused with a clear reason")
	_check(cr._upload_error_text("message_too_long").begins_with("The message is too long") and cr._upload_error_text("invalid_image_type").begins_with("This photo couldn't be sent"),
		"B. server refusals are explained")
	cr.reset()
	social.show_page(SocialScreen.Page.CHOICE)
	await _frames(2)


# --- C. Armor first encounter -----------------------------------------------------

func _test_armor_lesson() -> void:
	SocialPlay.armor_learned = false
	SocialGenerator.force_special = "armor"
	var p := SocialGenerator.new(SocialGenerator.REVEAL, 21).run()
	SocialGenerator.force_special = ""
	var c := SharedChallenge.photo_message_reveal(_session("For you", false), p)
	play.start(c, SocialPlay.Mode.RECIPIENT, game.ui.theme)
	await _frames(3)
	await _wait(0.3)
	_check(play.has_armor() and play.lesson_armor and play._tutor.is_showing() and play.get_children().all(func(n): return not n is MechanicIntro),
		"C. an Armor board starts the finger lesson at once (no separate intro card)")
	var ram := _ram_block()
	var armored := _armored_block()
	var marked := play.board._views.keys().filter(func(v): return play.board._views[v].marked)
	_check(ram != -1 and play._tutor._target.distance_to(play.board.block_screen_position(ram)) < 1.0, "C. the finger points at the block aimed at the shell")
	_check(marked.has(ram) and marked.has(armored), "C. brackets on the shell and on that block")
	_check(play._message.text.contains("ARMOR"), "C. one short line: \"%s\"" % play._message.text)
	await _wait(2.0)
	_check(play.model.blocks[armored].armored and play.lesson_armor, "C. nothing is played for the player (still armored after 2 s)")
	# A tap on the armored block: free, explains.
	play.tap_block(armored)
	await _frames(3)
	_check(play.model.blocks[armored].armored and play.lesson_armor, "C. tapping the shell itself explains and keeps teaching")
	# RESTART: no card again, the lesson goes on.
	play.restart()
	await _frames(3)
	_check(play.lesson_armor and play._tutor.is_showing(), "C. RESTART: the lesson is back")
	# The player's own hit finishes it.
	play.tap_block(_ram_block())
	await _wait(0.3)
	_check(not play.lesson_armor and SocialPlay.armor_learned and not play._tutor.is_showing() and play._message.text.begins_with("Shell cracked"),
		"C. the player's hit cracks the shell and ends the lesson")
	_check(play.board._views.keys().all(func(v): return not play.board._views[v].marked), "C. brackets cleared")
	var guard := 0
	while not play.completed and guard < 30 and play.play_solver_move():
		guard += 1
		await _wait(0.1)
	_check(play.completed, "C. the Armor reveal is solved")
	# Learned: the next Armor board plays freely.
	play.start(SharedChallenge.photo_message_reveal(_session("Again", false), p), SocialPlay.Mode.RECIPIENT, game.ui.theme)
	await _frames(3)
	_check(not play.lesson_armor and not play._tutor.is_showing(), "C. once learned, later Armor boards play without the lesson")
	play.end()


func _ram_block() -> int:
	for id in play.model.blocks.keys():
		if play.model.move_state(id) == "ram":
			return id
	return -1


func _armored_block() -> int:
	for b in play.model.blocks.values():
		if b.armored:
			return b.id
	return -1


# --- D. Reveal moment --------------------------------------------------------------

func _test_reveal_moment() -> void:
	var p := SocialGenerator.new("easy", 3)  # any board
	var puzzle := p.run()
	var cases := [["photo + message", true, "שלום! Happy birthday 🎉"], ["photo only", true, ""], ["message only", false, "كل عام وأنت بخير ❤️"]]
	for k in cases:
		var c := SharedChallenge.photo_message_reveal(_session(k[2], k[1]), PuzzleDefinition.from_json(puzzle.to_json()))
		play.start(c, SocialPlay.Mode.RECIPIENT, game.ui.theme)
		await _frames(3)
		_check(not play._time.is_visible_in_tree() and not play._chip.is_visible_in_tree(), "D. %s: no timer and no difficulty while playing" % k[0])
		await _solve()
		var r := play.reveal
		await _until(func(): return r.visible, 3.0)
		var t0 := Time.get_ticks_msec()
		_check(r.phase == "playing" and r._cta.mouse_filter == Control.MOUSE_FILTER_IGNORE and r._again.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"D. %s: the moment plays; buttons don't take taps yet" % k[0])
		var eb: SocialReveal.RevealEnvelope = r._env_back
		_check(eb.visible and r._env_front.visible and r._chain.all(func(b): return not b.visible), "D. %s: the gift box and envelope, no breaking chain" % k[0])
		# Anticipation: the closed gift rests on screen before it opens.
		await _wait(maxf(0.0, 0.75 - (Time.get_ticks_msec() - t0) / 1000.0))
		_check(eb.box > 0.99 and eb.lid < 0.01 and eb.rise < 0.01, "D. %s: anticipation - the closed gift fully shown at %d ms (box %.2f, lid %.2f)" % [k[0], Time.get_ticks_msec() - t0, eb.box, eb.lid])
		await _until(func(): return eb.rise > 0.5, 1.2)
		_check(eb.box > 0.9 and eb.lid > 0.95, "D. %s: the box stays while the envelope lifts out (box %.2f at rise %.2f)" % [k[0], eb.box, eb.rise])
		await _until(func(): return eb.lid > 0.95, 1.0)
		_check(eb.lid > 0.95 and eb.flap < 0.05, "D. %s: the box opens by itself (lid %.2f), the envelope still closed" % [k[0], eb.lid])
		await _until(func(): return eb.rise > 0.99 and eb.flap > 0.99, 1.2)
		_check(eb.rise > 0.99 and eb.flap > 0.99 and eb.glow > 0.5 and eb.pocket_at.distance_to(eb.box_at) > 40.0,
			"D. %s: the envelope rose out of the box and its flap opened, with a soft glow" % k[0])
		_check(not r._time_box.visible, "D. %s: no time on a reveal" % k[0])
		await _until(func(): return r.phase == "done", 4.0)
		var ms := Time.get_ticks_msec() - t0
		_check(r.phase == "done" and ms >= 2100 and ms <= 2900 and not r.skipped, "D. %s: the moment took %d ms (about 2.45 s)" % [k[0], ms])
		_check(r._heading.text == "SURPRISE UNLOCKED!" and not r._env_back.visible and not r._env_front.visible and not r._emblem.visible, "D. %s: SURPRISE UNLOCKED!, the envelope gone, no emblem" % k[0])
		await _wait(0.8)  # CREATE YOUR OWN SURPRISE: its one gentle pulse
		var all_shown := [r._heading, r._cta, r._again, r._back].all(func(x): return x.modulate.a > 0.99)
		_check(all_shown and r._cta.mouse_filter == Control.MOUSE_FILTER_STOP and r._cta.text.begins_with("CREATE YOUR OWN SURPRISE"), "D. %s: CREATE YOUR OWN SURPRISE active" % k[0])
		_check(r._photo_frame.visible == k[1] and r._message_card.visible == (k[2] != "") and not r._emblem.visible, "D. %s: the right parts shown (no emblem for a reveal)" % k[0])
		_check([r._photo_frame, r._photo_status, r._message_card].all(func(x): return x.scale.is_equal_approx(Vector2.ONE)), "D. %s: every card at full size (no layout jump)" % k[0])
		if k[2] != "":
			_check(r._message.text == CreatorSession.clean_message(k[2]) and r._message_card.modulate.a > 0.99, "D. %s: the message is there in full" % k[0])
		var vis := r.get_viewport().get_visible_rect()
		_check(vis.encloses(r._column.get_global_rect().grow(-1.0)), "D. %s: everything on screen" % k[0])
		play.end()
	# Tap to skip.
	var c2 := SharedChallenge.photo_message_reveal(_session("Skip me", true), PuzzleDefinition.from_json(puzzle.to_json()))
	play.start(c2, SocialPlay.Mode.RECIPIENT, game.ui.theme)
	await _frames(3)
	await _solve()
	await _until(func(): return play.reveal.visible, 3.0)
	await _wait(0.3)
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = Vector2(30, 30)
	play.reveal._gui_input(tap)
	_check(play.reveal.phase == "done" and play.reveal.skipped and play.reveal._message_card.modulate.a > 0.99 and play.reveal._photo_frame.modulate.a > 0.99
		and play.reveal._veil.modulate.a < 0.01 and play.reveal._cta.mouse_filter == Control.MOUSE_FILTER_STOP and not play.reveal._env_back.visible and not play.reveal._env_front.visible,
		"D. a tap skips to the end: photo, message and buttons at once, the envelope gone")
	play.end()
	# A photo still loading: the message is not held back.
	var c3 := SharedChallenge.photo_message_reveal(_session("Still here", false), PuzzleDefinition.from_json(puzzle.to_json()))
	c3.payload["photo"] = {"format": "remote"}
	play.start(c3, SocialPlay.Mode.RECIPIENT, game.ui.theme)
	play.photo_pending = "loading"
	await _frames(3)
	await _solve()
	await _until(func(): return play.reveal.visible and play.reveal.phase == "done", 5.0)
	_check(play.reveal._photo_status.visible and play.reveal._photo_status.modulate.a > 0.99 and play.reveal._message_card.modulate.a > 0.99,
		"D. photo still loading: the loading card and the message, on time")
	play.photo_pending = ""
	play.end()
	# Reduced motion: everything at once.
	SocialScreen._reduced_motion_checked = true
	SocialScreen._reduced_motion = true
	play.start(SharedChallenge.photo_message_reveal(_session("Calm", true), PuzzleDefinition.from_json(puzzle.to_json())), SocialPlay.Mode.RECIPIENT, game.ui.theme)
	await _frames(3)
	await _solve()
	await _until(func(): return play.reveal.visible, 3.0)
	_check(play.reveal.phase == "done" and play.reveal._message_card.modulate.a > 0.99 and play.reveal._chain.all(func(b): return not b.visible) and not play.reveal._env_back.visible,
		"D. reduced motion: the end state at once, no envelope animation")
	SocialScreen._reduced_motion = false
	play.end()
	# Challenge a Friend's result: exactly as before (its own reveal, YOUR TIME).
	play.start(SharedChallenge.friend_challenge(FriendGenerator.new("easy", 9, [], 0).run(), "easy"), SocialPlay.Mode.RECIPIENT, game.ui.theme)
	await _frames(3)
	await _solve()
	await _until(func(): return play.reveal.visible, 3.0)
	_check(play.reveal.phase == "done" and play.reveal._time_box.visible and play.reveal._cta.text.begins_with("CHALLENGE A FRIEND") and play.reveal._cta.mouse_filter == Control.MOUSE_FILTER_STOP
		and play.reveal._heading.text == "YOU ESCAPED!" and not play.reveal._env_back.visible and play.reveal._emblem.visible,
		"D. Friend Challenge result unchanged: YOU ESCAPED!, YOUR TIME, CHALLENGE A FRIEND, no envelope")
	_check([play.max_undos, play.max_hints, play.max_hammers] == [3, 2, 2] and play.is_timed(), "G. Friend Challenge timer and tools unchanged (EASY x3 / x2 / x2)")
	play.end()


# --- E. Messages --------------------------------------------------------------------

func _test_messages() -> void:
	var ts := TextServerManager.get_primary_interface()
	var f := MessageText.reveal_font()
	_check(f.fallbacks.size() == 1 and f.fallbacks[0] == MessageText.font() and f.has_char(0x1F451) and MessageText.font().fallbacks.size() == MessageText.FALLBACKS.size(),
		"E. reveal messages: the emoji set first, then the usual message font; other text keeps the small set")
	# As on the Web build (no system fonts): emoji set -> Open Sans -> Arabic, Hebrew, small emoji.
	var em: FontFile = (load(MessageText.REVEAL_EMOJI) as FontFile).duplicate()
	em.allow_system_fallback = false
	var em_chain: Array[Font] = [_web_font(MessageText.font())]
	em.fallbacks = em_chain
	for k in [["he", "מזל טוב! יום הולדת שמח", TextServer.DIRECTION_RTL], ["ar", "كل عام وأنت بخير", TextServer.DIRECTION_RTL], ["en+emoji", "Love you 😍🎂🌹👑", TextServer.DIRECTION_LTR],
			["he+emoji", "מזל טוב! 👑🎉", TextServer.DIRECTION_RTL]]:
		var r := _shape(ts, em, k[1])
		_check(r["missing"] == 0 and r["dir"] == k[2], "E. %s: every glyph found, direction kept" % k[0])
	var joined: Array = _shape(ts, em, "عام")["glyphs"]
	var alone: int = _shape(ts, em, "ع")["glyphs"][0]["index"]
	_check(joined.all(func(g): return g["index"] != alone), "E. Arabic still joins")
	var heart: Array = _shape(ts, em, "❤️")["glyphs"]
	_check(not heart.is_empty() and heart[0]["font_rid"] == em.get_rids()[0], "E. ❤️ is drawn by the colour emoji set (not the UI font's plain heart)")
	var latin: Array = _shape(ts, em, "Hi")["glyphs"]
	_check(latin.all(func(g): return g["font_rid"] != em.get_rids()[0]), "E. letters still come from the message font")
	_check(MessageText.missing_emoji("Happy 🎉❤️👍🌹").is_empty(), "E. common emoji are drawn")
	_check(MessageText.missing_emoji("🇮🇱🇯🇴 🦖") == ["🇮", "🇱", "🇯", "🇴", "🦖"], "E. flags and rarer emoji are reported as not drawable")
	social.creator.set_draft("Hi 🦖")
	social.creator._update_message_state()
	_check(social.creator._message_note.text == RevealCreator.EMOJI_NOTE, "E. the creator says so before sending")


# --- F. An older reveal link --------------------------------------------------------

func _test_old_link() -> void:
	var old := SocialGenerator.new("medium", 404).run()  # the pre-MVP 12-15 block board
	var data := {"id": "11111111-2222-4333-8444-555555555555", "challenge_type": "photo_message_reveal", "difficulty": "medium",
		"puzzle": old.to_dict(), "payload": {"message": "From before"}, "media_url": null, "expires_at": "2099-01-01T00:00:00Z"}
	var r := SharedChallenge.from_api(data)
	_check(r.has("challenge") and r["challenge"].puzzle.fingerprint() == old.fingerprint() and old.block_count() >= 12, "F. an older %d-block reveal still parses to its exact board" % old.block_count())
	if not r.has("challenge"):
		return
	var gens := SocialGenerator.created
	play.start(r["challenge"], SocialPlay.Mode.RECIPIENT, game.ui.theme)
	await _frames(3)
	_check(play.loaded_fingerprint == old.fingerprint() and play.model.block_count() == old.block_count() and SocialGenerator.created == gens, "F. ... and plays it as stored (nothing regenerated)")
	_check(not play._chip.is_visible_in_tree(), "F. its stored difficulty is not shown")
	await _solve()
	await _until(func(): return play.reveal.visible and play.reveal.phase == "done", 5.0)
	_check(play.reveal._message.text == "From before", "F. its reveal works")
	play.end()


# --- Helpers ------------------------------------------------------------------------

func _web_font(f: Font) -> Font:
	var web_font: FontFile = ThemeDB.fallback_font.duplicate()
	web_font.allow_system_fallback = false
	var chain: Array[Font] = []
	for fb in f.fallbacks:
		var c: FontFile = fb.duplicate()
		c.allow_system_fallback = false
		chain.append(c)
	web_font.fallbacks = chain
	return web_font


func _shape(ts: TextServer, f: Font, text: String) -> Dictionary:
	var rid := ts.create_shaped_text()
	ts.shaped_text_add_string(rid, text, f.get_rids(), 30)
	ts.shaped_text_shape(rid)
	var glyphs := ts.shaped_text_get_glyphs(rid)
	var missing := 0
	for g in glyphs:
		if not (g["font_rid"] as RID).is_valid() and (g["flags"] & TextServer.GRAPHEME_IS_VIRTUAL) == 0:
			missing += 1
	var out := {"glyphs": glyphs, "missing": missing, "dir": ts.shaped_text_get_inferred_direction(rid)}
	ts.free_rid(rid)
	return out


func _session(message: String, photo: bool) -> CreatorSession:
	var s := CreatorSession.new()
	s.set_message(message)
	if photo:
		s.set_photo_jpeg(_jpeg(1600, 900, Color("#E8703A")))
	return s


func _solve() -> void:
	var guard := 0
	while not play.completed and guard < 80 and play.play_solver_move():
		guard += 1
		await _wait(0.08)


func _step_text(cr: RevealCreator) -> String:
	for l in cr._steps[cr.step].find_children("*", "Label", true, false):
		if String(l.text).begins_with("STEP"):
			return l.text
	return ""


func _find(root: Node, n: String) -> Control:
	var c := root.find_child(n, true, false) as Control
	if c == null:
		_check(false, "missing " + n)
	return c


func _jpeg(w: int, h: int, col: Color) -> PackedByteArray:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(col)
	img.fill_rect(Rect2i(w / 4, h / 4, w / 2, h / 2), Color.WHITE)
	return img.save_jpg_to_buffer(0.85)


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


func _until(pred: Callable, sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000)
	while not pred.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
