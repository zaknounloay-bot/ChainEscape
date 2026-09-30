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

	await _tap(_page_node(social, SocialScreen.Page.CHOICE, "Card_Photo"))
	_check(social.page == SocialScreen.Page.PHOTO_REVEAL, "PHOTO / MESSAGE REVEAL opens its placeholder")
	var soon: Label = social._pages[SocialScreen.Page.PHOTO_REVEAL].find_child("ComingSoon", true, false)
	_check(soon != null and soon.text == "CREATION FLOW COMING SOON", "placeholder says CREATION FLOW COMING SOON")
	await _wait(0.8)
	_check_order(social, SocialScreen.Page.PHOTO_REVEAL)
	await _shot("03_photo_placeholder")
	await _tap(_page_node(social, SocialScreen.Page.PHOTO_REVEAL, "Back"))
	_check(social.is_open() and social.page == SocialScreen.Page.CHOICE, "BACK from Photo returns to the Social choice screen")

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
