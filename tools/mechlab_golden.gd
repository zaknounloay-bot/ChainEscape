extends SceneTree
## No-change check for the mechanic lab boards: like classic_golden.gd but
## for a lab board file (default: the PORTAL lab; --file= for the SEQUENCE
## lab - Sequence tokens are parsed here). Dumps each board's
## parsed portals, Solver solution, first SHOW A MOVE and every block's
## move state / blocker / lane at each solution step.
##   godot --headless --path . --script res://tools/mechlab_golden.gd -- --out=/path/golden.json [--file=res://data/dev/mechlab_portal.json]


func _init() -> void:
	LevelManager.dev_sequence = true
	var out_path := ""
	var file := "res://data/dev/mechlab_portal.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.get_slice("=", 1)
		elif a.begins_with("--file="):
			file = a.get_slice("=", 1)
	var data = JSON.parse_string(FileAccess.get_file_as_string(file))
	var dump := []
	for rec in data["boards"]:
		var level := PuzzleDefinition.from_dict(rec["puzzle"]).to_level()
		var model := BoardModel.new()
		model.setup(level.rows, level.columns, level.blocks)
		model.set_portals(level.portals)
		var moves := Solver.from_model(model).solve_moves()
		var out := {"id": rec["id"], "portals": str(level.portals), "solution": Array(moves),
			"recommend": Solver.from_model(model).recommend_move(), "random": Solver.from_model(model).random_win_rate(200, 3)}
		var states := []
		for mv in moves:
			var ids := model.blocks.keys()
			ids.sort()
			var row := []
			for id in ids:
				var ln := model.lane(id)
				var blk: BlockData = ln["blocker"]
				row.append("%d:%s:%d:%s" % [id, model.move_state(id), blk.id if blk else -1, str(ln["via"])])
			states.append(" ".join(row))
			var mid: int = mv & Solver.ID_MASK
			if mv & Solver.RAM:
				model.ram(mid)
			elif model.move_state(mid) == "advance":
				model.advance(mid)
			else:
				model.remove(mid)
		out["states"] = states
		dump.append(out)
	var text := JSON.stringify(dump, "", true)
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	print("mechlab_golden: %d boards, sha256 %s" % [dump.size(), text.sha256_text()])
	quit(0)
