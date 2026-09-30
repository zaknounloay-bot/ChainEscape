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
	await _shot("02_social_choice")

	await _tap(_page_node(social, SocialScreen.Page.CHOICE, "Card_Photo"))
	_check(social.page == SocialScreen.Page.PHOTO_REVEAL, "PHOTO / MESSAGE REVEAL opens its placeholder")
	await _shot("03_photo_placeholder")
	await _tap(_page_node(social, SocialScreen.Page.PHOTO_REVEAL, "Back"))
	_check(social.is_open() and social.page == SocialScreen.Page.CHOICE, "BACK from Photo returns to the Social choice screen")

	await _tap(_page_node(social, SocialScreen.Page.CHOICE, "Card_Friend"))
	_check(social.page == SocialScreen.Page.CHALLENGE_FRIEND, "CHALLENGE A FRIEND opens its placeholder")
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

	print("SOCIAL SMOKE: %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	for f in failures:
		printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


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
	await _frames(3)


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
