extends SceneTree
## Level checker using the real rules and Solver (no rendering).
##
##   godot --headless --path . --script res://tools/verify_levels.gd
##   godot --headless --path . --script res://tools/verify_levels.gd -- --file=path/to/level.json
##
## For every level: size, blocks, spinners, legal starting moves, how many
## of them are traps, decision points along the solution, dependency depth,
## direction diversity and the generator's difficulty score. Fails if any
## level is unsolvable or the solver gave up.

func _initialize() -> void:
	var files: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="):
			files.append(a.get_slice("=", 1))
	if files.is_empty():
		var n := 1
		while FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
			files.append(LevelManager.LEVEL_PATH % n)
			n += 1
	var ok := true
	print("  #  name                  size blk spn start traps decis depth dir%  diff  status")
	for i in files.size():
		var json = JSON.parse_string(FileAccess.get_file_as_string(files[i]))
		var level := LevelManager.parse_level(json, i + 1)
		var model := BoardModel.new()
		model.setup(level.rows, level.columns, level.blocks)
		var s := Solver.from_model(model)
		var m := s.analyze()
		var solved: bool = m["solvable"] and not s.aborted and not s.any_aborted
		ok = ok and solved and level.blocks.size() > 0
		print("%3d  %-20s %dx%d  %3d %3d %5d %5d %5d %5d %4d %5.1f  %s" % [
			i + 1, level.name.left(20), level.columns, level.rows, m["blocks"], m["spinners"],
			m["start_moves"], m["start_traps"], m["decision_points"], m["depth"],
			int(m["direction_share"] * 100), LevelGenerator.difficulty(m),
			"OK" if solved else ("GAVE UP" if s.aborted else "UNSOLVABLE")])
	print("ALL LEVELS SOLVABLE" if ok else "LEVEL CHECK FAILED")
	quit(0 if ok else 1)
