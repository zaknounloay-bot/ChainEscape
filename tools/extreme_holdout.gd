extends SceneTree
## EXTREME research (development only): HELD-OUT measures - never used to
## search for or select the prototypes (tools/extreme5_build.gd optimises
## the 2-move learners and the greedy players of extreme_probe.gd). They
## check whether the selected boards are hard only for the models they were
## selected against.
##
##   planning depth  for every losing move along the solution (a risky move
##                   after which the board can no longer be cleared): the
##                   smallest number of further moves a player must look
##                   ahead to SEE that it is lost (every line is stuck
##                   within that many moves). Capped at DEPTH_CAP. A deep
##                   value = the mistake can only be avoided by planning (or
##                   by having made it before).
##   look6           single attempts by a player who rejects any move that
##                   is visibly lost within 6 moves (random otherwise).
##   learner look4   trial and error with memory, ordering by "keep the
##                   most moves open", looking 4 moves ahead.
##
##   godot --headless --path . --script res://tools/extreme_holdout.gd -- --in=res://data/dev/extreme5.json [--out=file]

const PROBE := preload("res://tools/extreme_probe.gd")
const DEPTH_CAP := 9


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	LevelManager.dev_magnet = true
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(args.get("in", "res://data/dev/extreme5.json"))))
	var boards: Array = data["boards"]
	boards.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	var rows := []
	print("id    traps  depth_med depth_max deep(>=5)  look6_win  learner4_dead_ends")
	for b in boards:
		var map: Array = b["puzzle"]["map"]
		var level := LevelManager.parse_level({"name": "holdout", "map": map}, 0, true)
		var m := BoardModel.new()
		m.setup(level.rows, level.columns, level.blocks)
		m.set_portals(level.portals)
		var s := Solver.from_model(m)
		var depths := planning_depths(s)
		var look6 := PROBE.policy_win(s, "look6", 60, 41) if s._crate_n == 0 else _look6_capped(s)
		var l4: Dictionary = PROBE.learner_stats(s, 8, 4, "mobility", 6000)
		var sorted := depths.duplicate()
		sorted.sort()
		var med: float = sorted[sorted.size() / 2] if not sorted.is_empty() else 0.0
		var mx: int = sorted[-1] if not sorted.is_empty() else 0
		var deep := depths.filter(func(d): return d >= 5).size()
		var row := {"id": b["id"], "traps": depths.size(), "depth_med": med, "depth_max": mx, "deep": deep, "look6": look6, "learner4": l4["dead_ends_med"]}
		rows.append(row)
		print("%-5s %5d %9.1f %9d %9d %10.2f %12.1f" % [b["id"], depths.size(), med, mx, deep, look6, l4["dead_ends_med"]])
	if args.has("out"):
		var f := FileAccess.open(str(args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify({"rows": rows}, " "))
		f.close()
	quit()


## Crate boards can push back and forth: the same player, 160-move cap
## (PROBE.policy_win caps every game).
func _look6_capped(s: Solver) -> float:
	return PROBE.policy_win(s, "look6", 30, 41)


## Planning depth of every losing risky move along the solver's solution.
static func planning_depths(s: Solver) -> Array:
	var sol := s.solve_moves()
	var out := []
	var applied := []
	for mv in sol:
		for x in s._distinct_legal():
			if x == mv or not PROBE.risky(s, x):
				continue
			s._do(x)
			if s._alive_count > s._crate_n and s._solve_keep_state().is_empty():
				var d := 0
				while d < DEPTH_CAP and not s._dead_within(d):
					d += 1
				out.append(d + 1)  # the losing move itself + d more moves
			s._undo_move(x)
		s._do(mv)
		applied.append(mv)
	for i in range(applied.size() - 1, -1, -1):
		s._undo_move(applied[i])
	return out
