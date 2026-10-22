extends "res://tools/extreme14_build.gd"
## EXTREME phase 9 (development only): the decoration screen. Every piece of
## a board is removed in turn and the smaller board goes through the FULL
## acceptance (with --learner_exception, the same rules the board itself
## passed). A piece is needed when its removal fails acceptance or lowers
## the expert learner measure; a removal that passes with no lower learner
## measure means the piece is decoration.
##   godot --headless --path . --script res://tools/extreme14_prune.gd -- --file=board.json [--cells=2,5;4,0] --learner_exception


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	_load_known()
	cur_recipe = "C2_flip"
	x_args["recipe"] = "C2_flip"
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var map: Array = Array(d["map"])
	var only := {}
	if x_args.has("cells"):
		for c in str(x_args["cells"]).split(";", false):
			only[c] = true
	for r in map.size():
		var cells: PackedStringArray = str(map[r]).split(" ", false)
		for c in cells.size():
			if cells[c] == "." or (not only.is_empty() and not only.has("%d,%d" % [r, c])):
				continue
			var m2 := map.duplicate()
			var row := cells.duplicate()
			row[c] = "."
			m2[r] = " ".join(row)
			var line := "r%dc%d %s removed: " % [r, c, cells[c]]
			var level := parse(m2)
			if level == null or not _intact(m2, level):
				print(line + "NEEDED (the board no longer parses: a link loses its piece)")
				continue
			var rec := _x_report("C2_flip", "prune", m2)
			var lm = rec.get("x", {}).get("expert", {}).get("learner", {})
			print(line + ("PASSES (decoration?) learners %s" % str(lm) if rec["ok"] else "NEEDED - %s %s" % [rec.get("why", ""), ("learners " + str(lm)) if lm is Dictionary and not lm.is_empty() else ""]))
	quit()
