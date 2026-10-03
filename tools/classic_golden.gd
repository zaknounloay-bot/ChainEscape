extends SceneTree
## No-change check for the campaign rules: dumps, for every level file, the
## Solver's full solution (RAM-marked), its analysis, the first recommended
## move, and every block's BoardModel.move_state (with its blocker) at each
## step of that solution. Two dumps taken before and after an engine change
## must be byte-identical.
##   godot --headless --path . --script res://tools/classic_golden.gd -- --out=/path/golden.json


func _init() -> void:
	var out_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.get_slice("=", 1)
	var levels := []
	var n := 1
	while FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
		var level := LevelManager.parse_level(JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n)), n)
		var model := BoardModel.new()
		model.setup(level.rows, level.columns, level.blocks)
		var solver := Solver.from_model(model)
		var moves := solver.solve_moves()
		var rec := {"n": n, "solution": Array(moves), "aborted": solver.aborted,
			"recommend": Solver.from_model(model).recommend_move(), "analysis": Solver.from_model(model).analyze()}
		var states := []
		for mv in moves:
			var row := []
			var ids := model.blocks.keys()
			ids.sort()
			for id in ids:
				var blk := model.find_blocker(id)
				row.append("%d:%s:%d" % [id, model.move_state(id), blk.id if blk else -1])
			states.append(" ".join(row))
			if mv & Solver.RAM:
				model.ram(mv & Solver.ID_MASK)
			else:
				model.remove(mv)
		rec["states"] = states
		rec["cleared"] = model.is_empty()
		levels.append(rec)
		n += 1
	var text := JSON.stringify(levels, "", true)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print("classic_golden: %d levels, sha256 %s" % [levels.size(), text.sha256_text()])
	quit(0)
