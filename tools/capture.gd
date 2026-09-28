extends Node
## Design-review helper: loads a level, performs taps and saves a strip of
## frames so animations can be inspected without a device.
##
##   godot --path . res://tools/Capture.tscn -- --level=3 --taps=2,1 --out=/tmp/cap
##   (add --coords to draw grid coordinates, --debug to open the debug panel,
##    --settings to open the settings card, --hint to show a hint,
##    --title / --shop / --levels for the title screen, Shop and Level Select,
##    --solve to auto-solve the level and save the level card,
##    --gallery=5,15,25 to save the start frame of several levels (one per
##    Chapter shows every theme), --chapter-card=4 for a Chapter Complete card)
##
## Each tap saves frames at the listed delays (seconds after the tap).

const DELAYS := [0.0, 0.05, 0.1, 0.16, 0.24]

var out := "user://capture"
var level := 1
var taps: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var v := arg.get_slice("=", 1)
		if arg.begins_with("--out="):
			out = v
		elif arg.begins_with("--level="):
			level = int(v)
		elif arg.begins_with("--taps="):
			for t in v.split(",", false):
				taps.append(int(t))
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	PlayerProgress.default_path = "user://capture_progress.cfg"
	GameManager.skip_title = not ("--title" in OS.get_cmdline_user_args())
	var game: GameManager = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.start_level(level)
	if "--coords" in OS.get_cmdline_user_args():
		game.board.show_coords = true
	if "--hint" in OS.get_cmdline_user_args():
		game.debug_panel.visible = true
		game.request_hint()
		game.debug_panel.visible = false
	if "--shop" in OS.get_cmdline_user_args():
		game.open_shop()
	if "--levels" in OS.get_cmdline_user_args():
		game.progress.highest_completed = maxi(game.progress.highest_completed, 53)
		for n in range(1, 54):
			game.progress.best_stars[n] = [3, 2, 3, 1][n % 4]
			game.progress.best_scores[n] = 1000
		game.open_level_select()
	if "--settings" in OS.get_cmdline_user_args():
		game.ui._open_settings()
	if "--solve" in OS.get_cmdline_user_args():
		await game.auto_solve()
		await get_tree().create_timer(2.5).timeout
		_save("solved")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--gallery="):
			for n in arg.get_slice("=", 1).split(",", false):
				game.start_level(int(n))
				await get_tree().create_timer(2.0).timeout
				_save("L%03d" % int(n))
		elif arg.begins_with("--chapter-card="):
			var c := int(arg.get_slice("=", 1))
			var rg := Chapters.chapter_range(c)
			for n in range(1, rg.y + 1):
				game.progress.best_scores[n] = 5000
				game.progress.best_stars[n] = 3 if n % 3 != 0 else 2
			game.progress.highest_completed = rg.y
			game.progress.chapter_coins[c] = 214
			game.start_level(rg.y)
			await get_tree().create_timer(1.6).timeout
			game._show_chapter_card(c)
			await get_tree().create_timer(0.6).timeout
			_save("chapter_card_%d" % c)
	await get_tree().create_timer(0.6).timeout
	_save("start")
	var i := 0
	for id in taps:
		var view := game.board.get_view(id)
		if view == null:
			continue
		var ev := InputEventScreenTouch.new()
		ev.position = game.board.get_global_transform_with_canvas() * view.home
		ev.pressed = true
		get_tree().root.push_input(ev, true)
		var elapsed := 0.0
		for d in DELAYS:
			if d > elapsed:
				await get_tree().create_timer(d - elapsed).timeout
				elapsed = d
			await RenderingServer.frame_post_draw
			_save("tap%d_%03d" % [i, int(d * 1000)])
		await get_tree().create_timer(0.3).timeout
		i += 1
	await get_tree().create_timer(1.0).timeout
	_save("end")
	get_tree().quit()


func _save(name: String) -> void:
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
