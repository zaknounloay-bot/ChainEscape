extends Node
## Design-review helper: loads a level, performs taps and saves a strip of
## frames so animations can be inspected without a device.
##
##   godot --path . res://tools/Capture.tscn -- --level=3 --taps=2,1 --out=/tmp/cap
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
	var game: GameManager = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	game.start_level(level)
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
