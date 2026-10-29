extends "res://tools/ta90_design.gd"
## PHASE 23 (development only): does a generated board still carry its core's
## critical dependency? (docs/extreme90_phase23.md, protocol rule 5). The
## generator freezes the core's cells but may add a second way round it - for
## K4_TOGGLE_s22_1 an added block cracked the core shell and the core's only
## rammer simply left. Per board, along the Solver's line:
##   core_ram    - the core's rammer (the block on --cell, which stays put while
##                 it rams) cracks a shell on the line;
##   core_trap   - leaving with that block (a move from --cell that is not a
##                 ram) is one of the board's distinct losing moves;
##   preserved   - both.
## Diagnostic: it rejects nothing by itself.
##   godot --headless --path . --script res://tools/ta90_corecheck.gd -- --file=maps.json --cell=r1c5 [--out=out.json]
## maps.json: {"name": [map rows], ...}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	var cell := str(x_args["cell"])
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var out := {}
	var kept := 0
	for name in d:
		var level := parse(Array(d[name]))
		var s := _solver(level)
		var memo := EXPERT.explore(s)
		var dec := _decisions(s, memo["win"], s.solve_moves())
		var ram: bool = dec["line"].any(func(l: String) -> bool: return l.begins_with(cell) and l.contains(" ram"))
		var trap: bool = dec["mistakes"].any(func(l: String) -> bool: return l.begins_with(cell) and not l.contains(" ram"))
		out[name] = {"core_ram": ram, "core_trap": trap, "preserved": ram and trap, "distinct": dec["distinct_mistakes"]}
		kept += int(ram and trap)
	print("CORECHECK %s: %d / %d boards preserve the core (rammer %s rams on the line, and leaving with it loses)" % [x_args["file"], kept, d.size(), cell])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()
