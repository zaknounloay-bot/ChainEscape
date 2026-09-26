extends SceneTree
## Command-line front end for LevelGenerator.
##
##   godot --headless --path . --script res://tools/generate_levels.gd -- \
##       --profile=hard --count=3 --seed=7 [--out=user://generated] [--attempts=400]
##
## Prints each accepted candidate as level JSON plus its metrics. Existing
## levels in res://levels are loaded first so repetitive boards are rejected.
## Candidates are written to --out (never straight into res://levels):
## a human curates them, names them and copies the good ones over.

func _initialize() -> void:
	var args := {"profile": "medium", "count": "3", "seed": "1", "out": "", "attempts": "400"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var gen := LevelGenerator.new(int(args["seed"]))
	var lm := LevelManager.new()
	lm._ready()
	for n in range(1, lm.level_count + 1):
		gen.known_boards.append(lm.load_level(n))
	lm.free()
	var p := LevelGenerator.profile(args["profile"])
	if args["out"] != "":
		DirAccess.make_dir_recursive_absolute(args["out"])
	var made := 0
	for i in int(args["count"]):
		var level := gen.generate(p, int(args["attempts"]))
		if level == null:
			print("# no candidate accepted after %s attempts" % args["attempts"])
			continue
		made += 1
		level.name = "%s %d" % [args["profile"].capitalize(), made]
		var m := gen.last_metrics
		print("# %s  %dx%d blocks=%d spinners=%d start_moves=%d start_traps=%d decisions=%d traps=%d depth=%d dir_share=%.2f difficulty=%.1f" % [
			level.name, level.columns, level.rows, m["blocks"], m["spinners"], m["start_moves"], m["start_traps"],
			m["decision_points"], m["trap_moves"], m["depth"], m["direction_share"], m["difficulty"]])
		var text := LevelManager.to_json_text(level)
		print(text)
		if args["out"] != "":
			var f := FileAccess.open("%s/candidate_%s_%s_%d.json" % [args["out"], args["profile"], args["seed"], made], FileAccess.WRITE)
			f.store_string(text)
	print("# rejected: %s" % str(gen.reject_stats))
	quit(0 if made > 0 else 1)
