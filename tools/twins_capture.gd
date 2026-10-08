extends Node
## TWINS PROTOTYPE design review: saves frames of the bond bar, the pair
## escape and the blocked-pair feedback (needs a display, e.g. Xvfb):
##
##   xvfb-run godot --path . --resolution 390x844 res://tools/TwinsCapture.tscn -- --out=/tmp/twins
##
## - p1_start / p2_start / p3_start: the three prototype puzzles.
## - p1_wait_*: Twin Lights, a partner-blocked tap (both wobble, the
##   blocked lane flashes, the one-time message).
## - p1_pair_*: Twin Lights, the blue pair escaping (react, bond glows,
##   snaps, both fly).
## - size5 / size7 / colors6: bonds on 5x5 and 7x7 boards, horizontal and
##   vertical, in every block color (temporary demo boards written to
##   user://, never shipped).

var out := "user://twins_capture"
var game: GameManager

const DEMO := {
	1: {"name": "Bonds 5x5", "map": [
		"R>!T R<!T .    Gv   .",
		".    .    .    .    .",
		"B^!U .    Y>   .    P<",
		"Bv!U .    .    .    .",
		".    .    G^   .    ."]},
	2: {"name": "Bonds 7x7", "map": [
		".    G>!T G^!T .    .    .    Rv",
		".    .    .    .    .    .    .",
		"Y<!U .    .    B>   .    .    .",
		"Y^!U .    .    .    .    P>!V .",
		".    .    R^   .    .    Pv!V .",
		".    .    .    .    .    .    .",
		"B^!W B>!W .    .    G<   .    ."]},
	3: {"name": "Bond colors 6x6", "map": [
		"R^!T R>!T .    B<!U B^!U .",
		".    .    .    .    .    .",
		"G<!V .    .    .    .    Yv!W",
		"Gv!V .    .    .    .    Y>!W",
		".    .    .    .    .    .",
		".    P^   P<   .    .    ."]},
}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("saved " + name)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _id_at(c: int, r: int) -> int:
	var b := game.model.block_at(Vector2i(c, r))
	return b.id if b else -1


func _run() -> void:
	TwinsPrototype.apply("1")
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	game.level_manager.level_count = 3
	TwinsPrototype.seed_save(game.progress)
	AudioManager.set_music_enabled(false)
	for n in [1, 2, 3]:
		game.start_level(n, "capture")
		await _wait(1.6)
		await _shot("p%d_start" % n)
	# Twin Lights: green (4,4) leaves, then a blue twin is tapped while its
	# partner's lane (up, purple 1,2) is blocked.
	game.start_level(1, "capture")
	await _wait(1.6)
	game._on_block_tapped(_id_at(4, 4))
	await _wait(0.6)
	var tw := Time.get_ticks_msec()
	game._on_block_tapped(_id_at(2, 4))
	for ms in [30, 80, 150, 400]:
		while Time.get_ticks_msec() - tw < ms:
			await get_tree().process_frame
		await _shot("p1_wait_%03d" % ms)
	await _wait(2.6)
	game._on_block_tapped(_id_at(4, 2))  # yellow clears purple's lane
	await _wait(0.6)
	game._on_block_tapped(_id_at(1, 2))
	await _wait(0.6)
	var t0 := Time.get_ticks_msec()
	game._on_block_tapped(_id_at(1, 4))
	for ms in [20, 60, 110, 160, 220, 300, 420]:
		while Time.get_ticks_msec() - t0 < ms:
			await get_tree().process_frame
		await _shot("p1_pair_%03d" % ms)
	await _wait(0.8)
	await _shot("p1_after_pair")
	# Demo boards (not shipped): 5x5, 7x7, every color.
	var dir := "user://twins_capture_levels"
	DirAccess.make_dir_recursive_absolute(dir)
	for n in DEMO:
		var f := FileAccess.open(dir.path_join("level_%02d.json" % n), FileAccess.WRITE)
		f.store_string(JSON.stringify({"name": DEMO[n]["name"], "hint": "", "hearts": 3, "map": DEMO[n]["map"]}))
		f.close()
	LevelManager.override_dir = dir
	for n in DEMO:
		game.start_level(n, "capture")
		await _wait(1.6)
		await _shot(["", "size5", "size7", "colors6"][n])
		print("bonds on demo %d: %d" % [n, game.board.bond_count()])
	get_tree().quit(0)
