extends "res://tools/extreme14_build.gd"
## EXTREME phase 9 (development only): SOLVER PARITY on boards, exhaustive.
## In EVERY reachable position, the game's Solver (what SHOW A MOVE uses)
## must agree with an exhaustive search of the same rules
## (extreme14_build.gd parity()). Why: the Solver plays "safe" moves greedily;
## "safe" excludes blocks in a magnet's pull zone, which is computed once,
## from the magnets' STARTING cells and directions. A magnet that a switch
## reverses, or that another magnet moves, pulls from lines that zone may not
## cover. On such a board SHOW A MOVE could answer "can't be cleared" in a
## winnable position.
##   godot --headless --path . --script res://tools/extreme14_parity.gd -- --file=boards.json
## boards.json: {"name": {"map": [row, ...]}, ...}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	for name in d:
		print(JSON.stringify(parity(Array(d[name]["map"]), name)))
	quit()
