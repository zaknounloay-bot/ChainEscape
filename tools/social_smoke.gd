extends Node
## Social MVP 0.1 smoke test: CREATE CHALLENGE navigation on the title
## screen, driven by real touch events, and a check that Social navigation
## leaves Classic progress and the save file untouched.
##
##   godot --headless --path . res://tools/SocialSmoke.tscn
##   (add -- --shots=/tmp/social to save screenshots; needs a real renderer,
##    e.g. xvfb-run godot --path . res://tools/SocialSmoke.tscn -- --shots=...)

const PROGRESS_PATH := "user://social_smoke_progress.cfg"

var game: GameManager
var failures: Array[String] = []
var shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	# Never touch the real player's progress.
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	_run.call_deferred()


func _run() -> void:
	# A player with some Classic progress: levels 1-12 cleared, playing 13.
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	_check(game.level_manager.level_count == 200, "200 levels present (got %d)" % game.level_manager.level_count)
	for n in range(1, 13):
		game.progress.record_result(n, 1000 + n, 3)
	game.progress.coins = 77
	game.start_level(13)
	await _frames(3)
	game.progress.save()
	game.queue_free()
	await _frames(3)
	# Relaunch into the title, as a returning player sees it.
	GameManager.skip_title = false
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	var title: TitleScreen = game.ui._title
	var social: SocialScreen = title._social
	_check(game.ui.is_title_open(), "title screen shown on launch")
	_check(title._continue.text == "CONTINUE  -  LEVEL 13", "title offers CONTINUE - LEVEL 13 (got '%s')" % title._continue.text)
	var before := _snapshot()
	var file_before := FileAccess.get_file_as_string(PROGRESS_PATH)
	var create: PillButton = title.find_child("CreateChallenge", true, false)
	_check(create != null and create.is_visible_in_tree(), "CREATE CHALLENGE button visible on the title")
	_check_layout(title, create)
	await _shot("01_title")

	await _tap(create)
	_check(social.is_open() and social.page == SocialScreen.Page.CHOICE, "CREATE CHALLENGE opens the Social choice screen")
	_check(game.ui.is_title_open(), "title stays open underneath (Classic untouched)")
	await _wait(0.8)  # entrance finished
	_check_cards(social)
	_check_order(social, SocialScreen.Page.CHOICE)
	await _shot("02_social_choice")

	await _test_reveal_creator(social)

	await _tap(_page_node(social, SocialScreen.Page.CHOICE, "Card_Friend"))
	_check(social.page == SocialScreen.Page.CHALLENGE_FRIEND, "CHALLENGE A FRIEND opens its placeholder")
	await _wait(0.8)
	_check_order(social, SocialScreen.Page.CHALLENGE_FRIEND)
	await _shot("04_friend_placeholder")
	await _tap(_page_node(social, SocialScreen.Page.CHALLENGE_FRIEND, "Back"))
	_check(social.page == SocialScreen.Page.CHOICE, "BACK from Friend returns to the Social choice screen")

	await _tap(_page_node(social, SocialScreen.Page.CHOICE, "Back"))
	_check(not social.is_open() and game.ui.is_title_open(), "BACK from the choice screen returns to the title")
	_check(_snapshot() == before, "Social navigation leaves Classic progress unchanged")
	_check(FileAccess.get_file_as_string(PROGRESS_PATH) == file_before, "Social navigation does not write the save file")
	_check(game.current_level == 13 and title._continue.text == "CONTINUE  -  LEVEL 13", "title still offers CONTINUE - LEVEL 13")

	# Classic flows from the title still work after a Social round trip.
	var ls: PillButton = title._continue.get_parent().get_child(2)
	await _tap(ls)
	_check(game.ui.is_level_select_open(), "LEVEL SELECT still opens from the title")
	game.ui._level_select.close()
	await _frames(2)
	await _tap(title._continue)
	_check(not game.ui.is_title_open() and game.current_level == 13, "CONTINUE still resumes level 13")
	_check(not social.is_open(), "Social screen closed with the title")
	await _test_main_menu()

	print("SOCIAL SMOKE: %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	for f in failures:
		printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


## Settings > MAIN MENU from gameplay: back to the title with nothing reset;
## CONTINUE resumes the same board. Settings toggles and DONE still work.
func _test_main_menu() -> void:
	await _wait(1.5)
	# Make one move so there is in-level progress to keep.
	for id in game.model.blocks:
		if game.model.move_state(id) == "ok":
			game.board.block_tapped.emit(id)
			break
	await _wait(1.5)
	var board_before := var_to_str([game.model.blocks.keys(), game.history.size(), game.completed])
	var before := _snapshot()
	# Settings toggles still work (flip VIBRATION off and back on).
	await _tap(game.ui._settings_button)
	_check(game.ui.is_settings_open(), "Settings opens during gameplay")
	var haptics: PillButton = game.ui._setting_buttons["haptics"]
	var was: bool = game.progress.haptics_on
	await _tap(haptics)
	_check(game.progress.haptics_on != was, "VIBRATION toggle still works")
	await _tap(haptics)
	_check(game.progress.haptics_on == was, "VIBRATION toggles back")
	var menu: PillButton = game.ui._main_menu_button
	var done_rect := (menu.get_parent().get_child(menu.get_index() + 1) as Control).get_global_rect()
	_check(menu.is_visible_in_tree() and menu.get_global_rect().end.y <= done_rect.position.y, "MAIN MENU sits above DONE")
	_check(game.ui._backup_button.is_visible_in_tree() and game.ui._restore_button.is_visible_in_tree(), "BACKUP CODE and RESTORE still in Settings")
	_check(game.ui.backup_requested.is_connected(game.show_backup_code) and game.ui.restore_requested.is_connected(game.request_restore), "BACKUP / RESTORE still wired")
	await _shot("05_settings")
	var file_before := FileAccess.get_file_as_string(PROGRESS_PATH)
	await _tap(menu)
	_check(game.ui.is_title_open() and not game.ui.is_settings_open(), "MAIN MENU returns to the title and closes Settings")
	_check(game.ui._title._continue.text == "CONTINUE  -  LEVEL 13", "title offers CONTINUE - LEVEL 13 after MAIN MENU")
	_check(_snapshot() == before, "MAIN MENU leaves progress, score, coins and stars unchanged")
	_check(FileAccess.get_file_as_string(PROGRESS_PATH) == file_before, "MAIN MENU does not write the save file")
	await _shot("06_main_menu_title")
	await _tap(game.ui._title._continue)
	_check(not game.ui.is_title_open() and game.current_level == 13, "CONTINUE after MAIN MENU resumes level 13")
	var board_after := var_to_str([game.model.blocks.keys(), game.history.size(), game.completed])
	_check(board_after == board_before, "the board is exactly as it was left (no restart)")
	# DONE still just closes Settings.
	await _tap(game.ui._settings_button)
	var done: PillButton = menu.get_parent().get_child(menu.get_index() + 1)
	await _tap(done)
	_check(not game.ui.is_settings_open() and not game.ui.is_title_open(), "DONE closes Settings and stays in the level")


## Social MVP 0.2A: the whole Photo / Message Reveal creation flow, driven
## by taps (photos arrive through receive_photo, as the Web picker and the
## desktop dialog deliver them).
func _test_reveal_creator(social: SocialScreen) -> void:
	_test_session_rules()
	_test_multilingual()
	var cr: RevealCreator = social.creator
	var wide := _test_jpeg(1600, 900, Color("#E8703A"))
	var tall := _test_jpeg(900, 1600, Color("#3A7BE8"))
	await _tap(_page_node(social, SocialScreen.Page.CHOICE, "Card_Photo"))
	_check(social.page == SocialScreen.Page.PHOTO_REVEAL and cr.visible and cr.step == RevealCreator.Step.CHOOSE,
			"PHOTO / MESSAGE REVEAL opens the creation flow (CHOOSE PHOTO)")
	await _wait(0.4)
	_check_step(cr, ["ChoosePhoto", "SkipPhoto", "Back"])
	await _shot("03_reveal_choose")
	# Pick a photo -> PREVIEW (not yet in the session).
	cr.receive_photo(wide, Vector2i(4000, 2250))
	await _wait(0.4)
	_check(cr.step == RevealCreator.Step.PREVIEW and not cr.session.has_photo(), "a chosen photo opens PREVIEW, not yet committed")
	_check_step(cr, ["UsePhoto", "ChooseAnother", "Back"])
	_check_aspect(cr._preview_image, Vector2(1600, 900), "preview keeps the landscape aspect")
	await _shot("04_reveal_preview")
	# CHOOSE ANOTHER: a new pick replaces the preview.
	cr.receive_photo(tall)
	await _wait(0.3)
	_check(cr.step == RevealCreator.Step.PREVIEW and cr._pending.image_size == Vector2i(900, 1600), "choosing another photo replaces the preview")
	_check_aspect(cr._preview_image, Vector2(900, 1600), "preview keeps the portrait aspect")
	_check_step(cr, ["UsePhoto", "ChooseAnother", "Back"])
	await _shot("04b_reveal_preview_portrait")
	_check(not cr.receive_photo(PackedByteArray([1, 2, 3])) and cr._pending.image_size == Vector2i(900, 1600), "an unreadable photo is refused, the preview stays")
	await _tap(_cnode(cr, "Back"))
	_check(cr.step == RevealCreator.Step.CHOOSE and not cr.session.has_photo(), "BACK from PREVIEW returns to CHOOSE PHOTO without the photo")
	cr.receive_photo(wide, Vector2i(4000, 2250))
	await _wait(0.3)
	await _tap(_cnode(cr, "UsePhoto"))
	_check(cr.step == RevealCreator.Step.MESSAGE and cr.session.has_photo() and cr.session.source_size == Vector2i(4000, 2250), "USE THIS PHOTO commits it and opens ADD A MESSAGE")
	# Message: 200-character limit, count, CONTINUE.
	await _wait(0.3)
	_check_step(cr, ["MessageCard", "MessageCount", "Continue", "SkipMessage", "Back"])
	var edit: TextEdit = cr._message_edit
	edit.insert_text_at_caret("x".repeat(250))
	await _frames(2)  # TextEdit emits text_changed deferred
	_check(edit.text.length() == 200 and cr._message_count.text == "200 / 200", "message capped at 200 characters with a count (%s)" % cr._message_count.text)
	edit.text = ""
	edit.insert_text_at_caret("Happy birthday!\nSee you soon")
	await _frames(2)  # TextEdit emits text_changed deferred
	await _shot("05_reveal_message")
	await _tap(_cnode(cr, "Continue"))
	_check(cr.step == RevealCreator.Step.DIFFICULTY and cr.session.message == "Happy birthday!\nSee you soon", "CONTINUE keeps the message and opens CHOOSE DIFFICULTY")
	# Difficulty.
	await _wait(0.3)
	_check_step(cr, ["Difficulty_easy", "Difficulty_medium", "Difficulty_hard", "Continue", "Back"])
	_check(cr._difficulty_continue.disabled, "CONTINUE waits for a difficulty")
	await _tap(_cnode(cr, "Difficulty_medium"))
	_check(cr.session.difficulty == "medium" and not cr._difficulty_continue.disabled, "MEDIUM selected")
	await _shot("06_reveal_difficulty")
	await _tap(_cnode(cr, "Continue"))
	_check(cr.step == RevealCreator.Step.REVIEW, "CONTINUE opens READY TO CREATE?")
	await _wait(0.3)
	_check_step(cr, ["ReviewPhoto", "ReviewMessage", "ReviewDifficulty", "EditPhoto", "EditMessage", "EditDifficulty", "Create", "Back"])
	_check(cr._review_message.text.contains("Happy birthday!") and cr._review_difficulty.text.ends_with("MEDIUM") and not cr._review_create.disabled,
			"REVIEW shows the photo, message and difficulty")
	_check(cr._review_message.size.y >= 50.0, "REVIEW message is actually visible (2 lines, height %d)" % cr._review_message.size.y)
	await _shot("07_reveal_review")
	# Edit difficulty: photo and message stay.
	await _tap(_cnode(cr, "EditDifficulty"))
	_check(cr.step == RevealCreator.Step.DIFFICULTY, "EDIT DIFFICULTY opens the difficulty step")
	await _tap(_cnode(cr, "Difficulty_hard"))
	await _tap(_cnode(cr, "Continue"))
	_check(cr.step == RevealCreator.Step.REVIEW and cr.session.difficulty == "hard" and cr.session.has_photo()
			and cr.session.message == "Happy birthday!\nSee you soon", "editing the difficulty keeps photo and message")
	# Edit message: whitespace only = no message; photo and difficulty stay.
	await _tap(_cnode(cr, "EditMessage"))
	_check(cr.step == RevealCreator.Step.MESSAGE and cr._message_edit.text == "Happy birthday!\nSee you soon", "EDIT MESSAGE opens with the current message")
	cr._message_edit.text = ""
	cr._message_edit.insert_text_at_caret("   \n  ")
	await _frames(2)  # TextEdit emits text_changed deferred
	await _tap(_cnode(cr, "Continue"))
	_check(cr.step == RevealCreator.Step.REVIEW and not cr.session.has_message() and cr._review_message.text == "No message"
			and cr.session.has_photo() and cr.session.difficulty == "hard", "a whitespace-only message counts as no message; the rest stays")
	# Edit photo: message and difficulty stay.
	await _tap(_cnode(cr, "EditPhoto"))
	_check(cr.step == RevealCreator.Step.PREVIEW and cr._pending.image_size == Vector2i(1600, 900), "EDIT PHOTO shows the current photo")
	cr.receive_photo(tall)
	await _wait(0.3)
	await _tap(_cnode(cr, "UsePhoto"))
	_check(cr.step == RevealCreator.Step.REVIEW and cr.session.image_size == Vector2i(900, 1600) and cr.session.difficulty == "hard",
			"choosing another photo from REVIEW keeps the difficulty")
	# Worst case on REVIEW: portrait photo + a full 200-character message.
	await _tap(_cnode(cr, "EditMessage"))
	cr._message_edit.text = ""
	cr._message_edit.insert_text_at_caret(("Happy birthday to the best friend anyone could ask for! " .repeat(4)).left(200))
	await _frames(2)  # TextEdit emits text_changed deferred
	await _tap(_cnode(cr, "Continue"))
	await _wait(0.3)
	_check(cr.step == RevealCreator.Step.REVIEW and cr.session.message.length() == 200, "a 200-character message reaches REVIEW")
	_check_step(cr, ["ReviewPhoto", "ReviewMessage", "ReviewDifficulty", "EditPhoto", "EditMessage", "EditDifficulty", "Create", "Back"])
	_check(cr._review_message.get_visible_line_count() == cr._review_message.get_line_count(), "the whole 200-character message is shown on REVIEW (%d lines)" % cr._review_message.get_line_count())
	await _shot("07b_reveal_review_full")
	# Back through the steps, then message only (skip the photo).
	await _tap(_cnode(cr, "Back"))
	_check(cr.step == RevealCreator.Step.DIFFICULTY, "BACK: REVIEW -> DIFFICULTY")
	await _tap(_cnode(cr, "Back"))
	_check(cr.step == RevealCreator.Step.MESSAGE, "BACK: DIFFICULTY -> MESSAGE")
	await _tap(_cnode(cr, "Back"))
	_check(cr.step == RevealCreator.Step.PREVIEW, "BACK: MESSAGE -> PREVIEW (a photo is chosen)")
	await _tap(_cnode(cr, "Back"))
	_check(cr.step == RevealCreator.Step.CHOOSE, "BACK: PREVIEW -> CHOOSE PHOTO")
	await _tap(_cnode(cr, "SkipPhoto"))
	_check(cr.step == RevealCreator.Step.MESSAGE and not cr.session.has_photo(), "SKIP PHOTO removes the photo and opens ADD A MESSAGE")
	cr._message_edit.text = ""
	await _frames(2)  # TextEdit emits text_changed deferred
	await _wait(0.3)
	_check(not cr._message_skip.visible and cr._message_continue.disabled, "message only: a message is required (no SKIP, CONTINUE waits)")
	cr._message_edit.insert_text_at_caret("Meet me at the park at 5")
	await _frames(2)  # TextEdit emits text_changed deferred
	_check(not cr._message_continue.disabled, "CONTINUE enabled once there is a message")
	await _shot("08_reveal_message_only")
	await _tap(_cnode(cr, "Continue"))
	_check(cr.step == RevealCreator.Step.DIFFICULTY and cr.session.difficulty == "hard", "difficulty kept after changing the photo choice")
	await _tap(_cnode(cr, "Continue"))
	_check(cr.step == RevealCreator.Step.REVIEW and cr._review_no_photo.visible and not cr._review_photo.visible, "REVIEW says No photo")
	await _shot("09_reveal_review_message_only")
	await _tap(_cnode(cr, "Create"))
	_check(cr.step == RevealCreator.Step.READY, "CREATE CHALLENGE shows CHALLENGE READY")
	await _wait(0.5)
	_check_step(cr, ["ReadySummary", "SharingComingNext", "BackToCreate"])
	var share: PillButton = _cnode(cr, "SharingComingNext")
	_check(share.disabled, "SHARING COMING NEXT is not active")
	_check(cr._ready_summary.text.contains("No photo") and cr._ready_summary.text.contains("Message") and cr._ready_summary.text.contains("Hard"), "READY summary (%s)" % cr._ready_summary.text)
	var d := cr.session.to_dict()
	_check(d["challenge_type"] == "photo_message_reveal" and d["image"] == null and d["message"] == "Meet me at the park at 5" and d["difficulty"] == "hard"
			and not d.has("id") and not d.has("url"), "session data ready for a future SharedChallenge (no id, no url)")
	await _shot("10_reveal_ready")
	await _tap(_cnode(cr, "BackToCreate"))
	_check(social.page == SocialScreen.Page.CHOICE and not cr.visible and not cr.session.has_message() and cr.session.difficulty == "",
			"BACK TO CREATE CHALLENGE returns to the choice screen and discards the session")
	# Re-enter: a fresh session; BACK from CHOOSE PHOTO leaves the flow.
	await _tap(_page_node(social, SocialScreen.Page.CHOICE, "Card_Photo"))
	_check(cr.step == RevealCreator.Step.CHOOSE and not cr.session.has_photo() and cr.session.message == "", "re-entering starts a fresh session")
	await _tap(_cnode(cr, "Back"))
	_check(social.page == SocialScreen.Page.CHOICE and not cr.visible, "BACK from CHOOSE PHOTO returns to the Social choice screen")
	_check(get_tree().root.find_children("*", "HTTPRequest", true, false).is_empty(), "no network requests exist in the scene")
	await _wait(0.8)


## Personal messages in any language (0.2A fix). Shapes each sample with
## the message font as the Web build has it (engine font + bundled
## fallbacks, no system fonts): every glyph found, the right direction,
## Arabic letters joined.
const MESSAGES := {
	"en": ["Happy Birthday!", TextServer.DIRECTION_LTR],
	"fr": ["Joyeux anniversaire! Très belle journée. é è ê ë à â ç ù û ô ï", TextServer.DIRECTION_LTR],
	"he": ["מזל טוב! יום הולדת שמח", TextServer.DIRECTION_RTL],
	"ar": ["كل عام وأنت بخير", TextServer.DIRECTION_RTL],
	"en+ar": ["Happy Birthday أحمد", TextServer.DIRECTION_LTR],
	"he+en": ["מזל טוב Loay", TextServer.DIRECTION_RTL],
	"fr+ar": ["Bonjour أحمد", TextServer.DIRECTION_LTR],
	"ar-num": ["عمرك ٣٠ سنة! (30) مبروك، يا صديقي؟", TextServer.DIRECTION_RTL],
	"he-num": ["שלום, מה שלומך? 123! (בדיוק)", TextServer.DIRECTION_RTL],
	"ru": ["С днём рождения!", TextServer.DIRECTION_LTR],
}


func _test_multilingual() -> void:
	var ts := TextServerManager.get_primary_interface()
	_check(ts.has_feature(TextServer.FEATURE_BIDI_LAYOUT) and ts.has_feature(TextServer.FEATURE_SHAPING), "text server has BiDi + shaping (%s)" % ts.get_name())
	# As on the Web: the engine font plus the bundled fallbacks, and no
	# system fonts to fall back on.
	var web_font: FontFile = ThemeDB.fallback_font.duplicate()
	web_font.allow_system_fallback = false
	var chain: Array[Font] = []
	for fb: FontFile in MessageText.font().fallbacks:
		var c: FontFile = fb.duplicate()
		c.allow_system_fallback = false
		chain.append(c)
	web_font.fallbacks = chain
	var plain: FontFile = ThemeDB.fallback_font.duplicate()
	plain.allow_system_fallback = false
	_check(_shape(TextServerManager.get_primary_interface(), plain, "كل عام وأنت بخير")["missing"] > 0,
			"without the fallbacks, Arabic is missing on the Web font (the reported bug)")
	_check(web_font.fallbacks.size() == 2, "message font carries the Arabic + Hebrew fallbacks")
	_check(Palette.font(800).fallbacks.is_empty(), "the shared UI font is unchanged (no fallbacks added)")
	for key in MESSAGES:
		var text: String = MESSAGES[key][0]
		var r := _shape(ts, web_font, text)
		_check(r["missing"] == 0, "%s: every glyph found (%d missing)" % [key, r["missing"]])
		_check(r["dir"] == MESSAGES[key][1], "%s: direction %s" % [key, "RTL" if MESSAGES[key][1] == TextServer.DIRECTION_RTL else "LTR"])
	# Arabic joining: a letter inside a word uses a different (joined) glyph
	# than the same letter alone.
	var alone: int = _shape(ts, web_font, "ع")["glyphs"][0]["index"]
	var joined: Array = _shape(ts, web_font, "عام")["glyphs"]
	_check(joined.any(func(g): return g["index"] != alone) and joined.all(func(g): return g["index"] != alone), "Arabic letters are shaped (joined forms)")
	var emoji := _shape(ts, web_font, "🎉❤️")
	print("emoji on the Web font: %d of %d glyphs missing (drawn as boxes)" % [emoji["missing"], emoji["glyphs"].size()])
	# Quoting isolates the message and never drops a character.
	var q := MessageText.quoted("a\nb")
	_check(q.begins_with("\u201C") and q.ends_with("\u201D") and q.count(String.chr(0x2068)) == 2 and q.count(String.chr(0x2069)) == 2, "quoted() isolates every line")
	_check(_shape(ts, web_font, MessageText.quoted("كل عام وأنت بخير"))["missing"] == 0, "isolate marks are invisible (no boxes)")


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


func _test_session_rules() -> void:
	var s := CreatorSession.new()
	_check(s.validate().has("nothing_to_reveal") and s.validate().has("difficulty"), "an empty session cannot be created")
	s.set_message("   \n\t  ")
	_check(not s.has_message(), "whitespace-only message = no message")
	s.set_message("y".repeat(260))
	_check(s.message.length() == 200, "message cut at 200 characters")
	s.set_message("a\n\n\n\nb\nc\nd\ne\nf\ng")
	_check(s.message == "a\n\nb\nc\nd\ne", "blank runs collapse, at most 6 lines (%s)" % s.message.c_escape())
	s.set_difficulty("impossible")
	_check(s.difficulty == "", "unknown difficulty ignored")
	s.set_difficulty("easy")
	_check(s.is_valid(), "message + difficulty is a valid reveal")
	_check(not s.set_photo_jpeg(PackedByteArray([0, 1])), "bad JPEG bytes refused")


func _test_jpeg(w: int, h: int, col: Color) -> PackedByteArray:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(col)
	img.fill_rect(Rect2i(w / 4, h / 4, w / 2, h / 2), Color.WHITE)
	return img.save_jpg_to_buffer(0.85)


func _cnode(cr: RevealCreator, node_name: String) -> Control:
	var n: Control = cr._steps[cr.step].find_child(node_name, true, false)
	_check(n != null and n.is_visible_in_tree(), "step %d: %s visible" % [cr.step, node_name])
	return n


## Every listed control of the current step is visible and fully on
## screen, and the column's items do not overlap.
func _check_step(cr: RevealCreator, names: Array) -> void:
	var vis := get_viewport().get_visible_rect()
	for n in names:
		var c := _cnode(cr, n)
		if c:
			_check(vis.encloses(c.get_global_rect()), "step %d: %s on screen (%s)" % [cr.step, n, c.get_global_rect()])
	var prev_end := -INF
	for c: Control in cr._steps[cr.step].get_children():
		if not c.visible:
			continue
		var r := c.get_global_rect()
		_check(r.position.y >= prev_end - 0.5, "step %d: '%s' does not overlap the item above" % [cr.step, c.name])
		prev_end = r.end.y


func _check_aspect(rect: TextureRect, img: Vector2, msg: String) -> void:
	var sz := rect.custom_minimum_size
	_check(sz.x > 100 and absf(sz.x / sz.y - img.x / img.y) < 0.02, "%s (%s)" % [msg, sz])


## After the entrance, a page's items rest in order, top to bottom, fully
## visible and on screen (the slide never leaves anything misplaced).
func _check_order(social: SocialScreen, page: int) -> void:
	var vis := get_viewport().get_visible_rect()
	var prev_end := -INF
	for c: Control in social._pages[page].get_children():
		var r := c.get_global_rect()
		_check(r.position.y >= prev_end - 0.5 and vis.encloses(r) and c.modulate.a == 1.0,
				"page %d: '%s' in order, on screen, fully visible (%s)" % [page, c.name, r])
		prev_end = r.end.y


## Cards: the icon never overlaps the text, title and description are
## centered, Photo's title breaks into two intended lines.
func _check_cards(social: SocialScreen) -> void:
	for n in ["Card_Photo", "Card_Friend"]:
		var card: Control = social._pages[SocialScreen.Page.CHOICE].find_child(n, true, false)
		var content: VBoxContainer = card.get_child(0)
		var icon_r: Rect2 = (content.get_child(0) as Control).get_global_rect()
		var title: Label = content.get_child(1)
		var copy: Label = content.get_child(3)
		var cr := card.get_global_rect()
		for l: Label in [title, copy]:
			var r := l.get_global_rect()
			_check(not r.intersects(icon_r), "%s: icon does not overlap '%s'" % [n, l.text])
			_check(cr.encloses(r), "%s: '%s' inside the card" % [n, l.text])
			_check(absf(r.get_center().x - cr.get_center().x) < 2.0, "%s: '%s' centered" % [n, l.text])
		_check(copy.get_global_rect().position.y - title.get_global_rect().end.y >= 12.0, "%s: space between title and description" % n)
		_check(title.get_line_count() == (2 if n == "Card_Photo" else 1) and copy.get_line_count() == 2, "%s: intended line breaks" % n)
		print("card %s rect=%s" % [n, cr])


## PLAY / LEVEL SELECT keep their V17 positions; the new button sits below
## them, inside the screen, clear of the save diagnostic line.
func _check_layout(title: TitleScreen, create: Control) -> void:
	var vis := get_viewport().get_visible_rect()
	var play := title._continue.get_global_rect()
	var ls := (title._continue.get_parent().get_child(2) as Control).get_global_rect()
	var cr := create.get_global_rect()
	var stats := title._stats.get_global_rect()
	var diag := title._diag.get_global_rect()
	print("layout play=%s level_select=%s create=%s stats=%s diag=%s view=%s" % [play, ls, cr, stats, diag, vis])
	_check(vis.encloses(cr), "CREATE CHALLENGE fully on screen")
	_check(cr.position.y >= ls.end.y and not cr.intersects(ls) and not cr.intersects(play), "CREATE CHALLENGE below LEVEL SELECT, no overlap")
	_check(stats.end.y <= diag.position.y, "stats line clear of the save diagnostic line")
	_check(cr.size.y >= 88.0 and cr.size.x >= 440.0, "CREATE CHALLENGE is a large touch target")


func _page_node(social: SocialScreen, page: int, node_name: String) -> Control:
	var n: Control = social._pages[page].find_child(node_name, true, false)
	_check(n != null and n.is_visible_in_tree(), "%s visible on page %d" % [node_name, page])
	return n


func _snapshot() -> String:
	var p := game.progress
	return var_to_str([p.coins, p.best_scores, p.best_stars, p.highest_unlocked, p.highest_completed,
		p.current_level, p.inventory, p.total_score(), p.total_stars()])


## A press + release at the control's center, through the viewport's GUI
## input path (a finger on a phone arrives as this emulated mouse event).
func _tap(c: Control) -> void:
	if c == null:
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
	await _wait(0.3)  # the card press response runs before navigating


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await _frames(2)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [shots_dir, name])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
