extends "res://tools/ta90_humanfit.gd"
## PHASE 24 (development only): the hand-design bench (docs/extreme90_phase24.md).
## For a board drawn by hand, print what the designer needs to see before any
## report: solvable or not, the Solver's line, and at EVERY step the legal
## moves that lose, each with the depth at which its dead end shows (the
## longest line still playable after it). Then the human-fit features
## (tools/ta90_humanfit.gd) and the greedy win rates. Verification only: it
## generates nothing and decides nothing.
##   godot --headless --path . --script res://tools/ta90_bench24.gd -- --file=boards.json [--name=a,b]
## boards.json: {"name": {"map": [...]}, ...}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	_load_known()
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	for name in d:
		if x_args.has("name") and not str(x_args["name"]).split(",").has(name):
			continue
		bench(name, Array(d[name]["map"]))
	quit()


func bench(name: String, map: Array) -> void:
	var level := parse(map)
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	print("== %s: %d positions%s, winnable %s" % [name, win.size(), " (CAPPED)" if memo["capped"] else "", win.get(s._key(), false)])
	if not win.get(s._key(), false):
		return
	var sol := s.solve_moves()
	for i in sol.size():
		var lose := []
		for o in s._distinct_legal():
			s._do(o)
			if s._alive_count != s._crate_n and not win.get(s._key(), false):
				lose.append("%s(%d)" % [_say(s, o), EXPERT.longest(s, memo)])
			s._undo_move(o)
		print("  %2d  %-12s lose: %s" % [i + 1, _say(s, sol[i]), " ".join(lose)])
		s._do(sol[i])
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	var g := {}
	for k in POLICIES:
		g[k] = snappedf(PROBE.policy_win(s, k, 120, 31), 0.01)
	print("  greedy %s" % JSON.stringify(g))
	print("  features %s" % JSON.stringify(features(map)))
