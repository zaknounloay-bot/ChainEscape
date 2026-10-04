## Armor safety audit (v0.6.1): for every level with armored blocks, walks
## every reachable state and reports dead ends that still hold a shell
## (a shell that can never be cracked without the Hammer).
##   godot --headless --path . --script res://tools/armor_audit.gd [-- --from=161 --to=200 --limit=400000]
extends SceneTree


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=")
			args[kv[0]] = kv[1]
	var from := int(args.get("from", "101"))
	var to := int(args.get("to", "999"))
	var limit := int(args.get("limit", "400000"))
	var bad := 0
	for n in range(from, to + 1):
		var path := LevelManager.LEVEL_PATH % n
		if not FileAccess.file_exists(path):
			continue
		var level := LevelManager.parse_level(JSON.parse_string(FileAccess.get_file_as_string(path)), n)
		var model := BoardModel.new()
		model.setup(level.rows, level.columns, level.blocks)
		model.set_portals(level.portals)
		var solver := Solver.from_model(model)
		if solver._armored_ids.is_empty():
			continue
		var t0 := Time.get_ticks_msec()
		var r := solver.armor_audit(limit)
		var ok: bool = r["armor_dead_ends"] == 0 and r["complete"]
		if not ok:
			bad += 1
		var ex := []
		for mv in r["example"]:
			ex.append(("R" if mv & Solver.RAM else "") + str(mv & Solver.ID_MASK))
		# Cross-check with the game's own rules (BoardModel: the code the
		# tap handler runs), independent of the Solver.
		var mr := {"states": 0, "armor_dead_ends": 0, "dead_ends": 0, "boards": {}}
		_model_walk(model, {}, mr, limit)
		var sb: Array = (r["boards"] as Dictionary).keys()
		var mb: Array = (mr["boards"] as Dictionary).keys()
		sb.sort()
		mb.sort()
		if sb != mb:
			bad += 1
			ok = false
			print("L%d MISMATCH model: dead_ends=%d armor_dead_ends=%d states=%d" % [n, mr["dead_ends"], mr["armor_dead_ends"], mr["states"]])
		print("L%d shells=%d states=%d complete=%s dead_ends=%d armor_dead_ends=%d %dms %s %s" % [n, solver._armored_ids.size(), r["states"], r["complete"], r["dead_ends"], r["armor_dead_ends"], Time.get_ticks_msec() - t0, "OK" if ok else "UNSAFE", " ".join(ex)])
	print("ARMOR AUDIT: %d unsafe" % bad)
	quit(1 if bad > 0 else 0)


static func _model_key(model: BoardModel) -> String:
	var ids := model.blocks.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var b: BlockData = model.blocks[id]
		parts.append("%d.%d.%d.%d.%d" % [id, b.direction, int(b.armored), int(b.hidden), b.spin_step])
	return ",".join(parts)


static func _model_walk(model: BoardModel, seen: Dictionary, out: Dictionary, limit: int) -> void:
	var key := _model_key(model)
	if seen.has(key) or seen.size() >= limit:
		return
	seen[key] = true
	out["states"] = seen.size()
	if model.is_empty():
		return
	var moves := model.playable_ids()
	if moves.is_empty():
		var ids := model.blocks.keys()
		ids.sort()
		var board := PackedStringArray()
		var shell := false
		for id in ids:
			var b: BlockData = model.blocks[id]
			shell = shell or b.armored
			board.append(("=" if b.armored else "") + str(id))
		var desc := " ".join(board)
		if not (out["boards"] as Dictionary).has(desc):
			out["boards"][desc] = true
			out["dead_ends"] += 1
			if shell:
				out["armor_dead_ends"] += 1
		return
	var snap := model.snapshot()
	for id in moves:
		if model.move_state(id) == "ram":
			model.ram(id)
		else:
			model.remove(id)
		_model_walk(model, seen, out, limit)
		model.restore(snap)
