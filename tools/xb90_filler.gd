extends "res://tools/ta90_design.gd"
## PHASE 17 (development only): independent trivial removals - category C
## (docs/extreme90_phase17.md). For every piece: the board without it; a
## removal is TRIVIAL when the board stays solvable with the same decision
## steps and distinct mistakes (the piece adds nothing to the decisions:
## filler). Reported, never a rejection by itself.
##   godot --headless --path . --script res://tools/xb90_filler.gd -- --file=boards.json [--name=A1,D1] [--out=res.json]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var out := {}
	for k in d:
		if x_args.has("name") and not str(x_args["name"]).split(",").has(k):
			continue
		out[k] = removals(Array(d[k]["map"]))
		print("%s %s" % [k, JSON.stringify(out[k])])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func _structure(map: Array) -> Dictionary:
	var level := parse(map)
	if level == null or not _intact(map, level):
		return {}
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	if not memo["win"].get(s._key(), false):
		return {}
	return _decisions(s, memo["win"], s.solve_moves())


func removals(map: Array) -> Dictionary:
	var base := _structure(map)
	var trivial := []
	var tested := 0
	for r in map.size():
		var row: Array = Array(str(map[r]).split(" ", false))
		for c in row.size():
			if row[c] == "." or str(row[c]).begins_with("X"):
				continue
			var m2 := map.duplicate()
			var row2 := row.duplicate()
			row2[c] = "."
			m2[r] = " ".join(row2)
			tested += 1
			var d := _structure(m2)
			if not d.is_empty() and d["decision_steps"] >= base["decision_steps"] and d["distinct_mistakes"] >= base["distinct_mistakes"]:
				trivial.append("r%dc%d %s" % [r, c, row[c]])
	return {"pieces_tested": tested, "trivial_removals": trivial.size(), "trivial": trivial, "steps": base.get("decision_steps", 0), "distinct": base.get("distinct_mistakes", 0)}
