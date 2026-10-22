extends "res://tools/extreme8_build.gd"
## EXTREME phase 6 (development only, ?ptest11=1): ONE hand-designed
## crossing-magnet candidate for experienced analytical players
## (docs/extreme11.md). Every acceptance rule of T1-T5 / P1-P2 / H1-H2 /
## E1-E2 is kept unchanged (Gate 0 technical limits, 5 repeated timing runs
## within 40 ms, every mechanic matters, greedy players, rule-of-thumb
## learners, late traps, the near-copy guard, the expert gates of
## tools/extreme8_build.gd), plus this design's own gates:
##   - the idea on EVERY winning line (tools/extreme11_events.gd): a block on
##     two magnets' pull lines is pulled by one of them (contested_pull), it
##     is a spinner turned in its new place (contested_turn), and it later
##     rams the shell (contested_ram);
##   - timing: >= 2 magnets whose escape wins in some winnable positions and
##     loses in others (WHEN each leaves matters, not only whether);
##   - performance: SHOW A MOVE after every mistake along the solution within
##     40 ms in the lab, each lost position timed 5 times (the real screen measured up to
##     twice the lab on E2;
##     the 40 ms budget itself is checked in the real screen), at most 700
##     reachable positions.
## These are machine screens, not a difficulty claim: only people decide.
##   godot --headless --path . --script res://tools/extreme11_lab.gd -- --file=boards.json [--expert] [--full]
##   godot --headless --path . --script res://tools/extreme11_build.gd -- --recipe=C1_cross --seeds=seed.json --part=/tmp/c1.json
##   godot --headless --path . --script res://tools/extreme11_build.gd -- --accept=board.json --part=/tmp/q.json
##   godot --headless --path . --script res://tools/extreme11_build.gd -- --merge=a.json,... [--write]
## --accept: a finished board ({"map": [...], "source": "..."}) through the
## full acceptance into a part file, as a climb would record it.

const EV11 := preload("res://tools/extreme11_events.gd")
const X11_OUT := "res://data/dev/extreme11.json"
const X11_NOTES := "res://data/dev/extreme11_notes.json"
const TIMING_MAGNETS := 2
## Performance (the 40 ms budget, phones): SHOW A MOVE in a LOST position must
## prove that nothing wins, which costs about the number of reachable
## positions. E2 (614 positions) took 39 ms in the lab and 57-77 ms in the
## real screen; T5 (283) 13 ms. So: an extra lab screen after EVERY losing
## move along the solution (the inherited gate times the risky ones only),
## within the 40 ms budget itself, each position timed 5 times (this
## container's timing varies by up to ~1.6x in slow spells: one 124-node
## position measured 21-35 ms; margins of 20 / 30 ms tried first only
## measured the machine). The real screen is timed by
## tools/extreme11_check.gd (the page's own button), and the climb / screen
## are steered below 400 positions and 280 / 130 SHOW A MOVE nodes.
const LOST_HINT_LAB_MS := 40.0
const SOFT_POSITIONS := 400
const MAX_POSITIONS := 700

const X11_RECIPES := {
	"C1_cross": {"group": "Q", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(10, 13),
		"spin": Vector2i(2, 6), "rules": {"cw": 0.6, "ccw": 0.4}, "armor": Vector2i(1, 2), "magnets": Vector2i(2, 3),
		"needs": ["armor", "spinner"], "use": ["magnet"]},
}

## The facts the design needs on EVERY winning line.
const MUST11 := {
	"C1_cross": ["contested_pull", "contested_turn", "contested_ram"],
}


func _initialize() -> void:
	if not Array(OS.get_cmdline_user_args()).any(func(a): return str(a).begins_with("--accept=")):
		super._initialize()
		return
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	_load_known()
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["accept"])))
	cur_recipe = "C1_cross"
	x_args["recipe"] = "C1_cross"
	var rec := _x_report("C1_cross", str(d.get("source", "hand")), Array(d["map"]))
	print("ACCEPT %s  %s" % [rec["ok"], rec.get("why", "")])
	_save_part_x(str(x_args["part"]), [rec] if rec["ok"] else [], [] if rec["ok"] else [[0.0, rec.get("why", ""), Array(d["map"])]])
	quit()


func recipes() -> Dictionary:
	return X11_RECIPES


func out_path() -> String:
	return X11_OUT


func notes_path() -> String:
	return X11_NOTES


func own_prefix() -> String:
	return "extreme11"


func test_name() -> String:
	return "ptest11"


func id_prefix() -> String:
	return "Q"


## About 12-13 pieces (the brief), mobile-friendly.
func max_pieces() -> int:
	return 13


func max_len() -> int:
	return 18


func file_note() -> String:
	return "Development only. Blind test board (docs/extreme11.md); never shared, never production."


## Known / played: as phase 4, plus E1-E2 (played by the experienced tester).
func _load_known() -> void:
	super._load_known()
	var x8 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme8.json"))
	_collect_maps(x8, "extreme8.json (E1-E2)")
	for b in x8["boards"]:
		_add_played("phase 4 " + str(b["id"]), Array(b["puzzle"]["map"]))


func idea_check(level: LevelData, spec: Dictionary) -> Array:
	var why := super.idea_check(level, spec)
	var recipe := _recipe_of(level)
	for k in MUST11.get(recipe, []):
		if not EV11.witness(level, k).is_empty():
			why.append("a winning line without " + k)
	if MUST11.has(recipe):
		var s := _solver(level)
		var t := EV11.timing(s, EXPERT.explore(s)["win"])
		if t["timing_magnets"].size() < TIMING_MAGNETS:
			why.append("only %d timing magnets (< %d)" % [t["timing_magnets"].size(), TIMING_MAGNETS])
	return why


func solution_events(level: LevelData) -> Dictionary:
	return EV11.solution_facts(_solver(level))


func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := super._x_eval(map, spec, quick)
	if quick or not e["solvable"]:
		return e
	var recipe := _recipe_for_spec(spec)
	var level := parse(map)
	var miss := []
	for k in MUST11.get(recipe, []):
		if not EV11.witness(level, k).is_empty():
			miss.append("a winning line without " + k)
	var n: int = EXPERT.explore(_solver(level))["win"].size()
	e["positions"] = n
	e["score"] -= 0.03 * maxi(0, n - SOFT_POSITIONS)
	if n > MAX_POSITIONS:
		miss.append("%d positions (> %d: SHOW A MOVE too slow when lost)" % [n, MAX_POSITIONS])
	if not miss.is_empty():
		e["score"] -= 25.0 * miss.size()
		e["goal_ok"] = false
		e["why"] = ", ".join(([e["why"]] if str(e["why"]) != "" else []) + miss)
	return e


## The slowest SHOW A MOVE (Solver.recommend_move on a fresh solver, as the
## page does) after any losing move along the solution, in ms (lab): each
## lost position timed `reps` times and its median taken (this machine has
## slow spells of a second or more; a heavy position is slow every time).
func lost_hint_ms(level: LevelData, reps: int = 5) -> float:
	var s := _solver(level)
	var m := model_of(level)
	var worst := 0.0
	for mv in s.solve_moves():
		for o in s._distinct_legal():
			var snap := m.snapshot()
			_play_on(m, o)
			if not m.is_empty() and m.playable_ids().size() > 0 and Solver.from_model(m).recommend_move() == -1:
				var t := []
				for k in reps:
					var t0 := Time.get_ticks_usec()
					Solver.from_model(m).recommend_move()
					t.append((Time.get_ticks_usec() - t0) / 1000.0)
				t.sort()
				worst = maxf(worst, t[t.size() / 2])
			m.restore(snap)
		_play_on(m, mv)
		s._do(mv)
	return worst


static func _play_on(m: BoardModel, mv: int) -> void:
	var id := mv & Solver.ID_MASK
	match m.move_state(id):
		"ok":
			m.remove(id)
		"ram":
			m.ram(id)
		"push":
			m.push(id)
		"advance":
			m.advance(id)


func _x_report(recipe: String, source: String, map: Array) -> Dictionary:
	var rec := super._x_report(recipe, source, map)
	if not rec.has("x"):
		return rec
	var level := parse(map)
	var s := _solver(level)
	rec["x"]["idea_facts"] = EV11.solution_facts(s)
	var memo := EXPERT.explore(s)
	var t := EV11.timing(s, memo["win"])
	rec["x"]["timing"] = {"timing_magnets": t["timing_magnets"], "per": t["per"]}
	rec["x"]["positions"] = memo["win"].size()
	# The slowest lost position, each timed 5 times (median).
	var lost := snappedf(lost_hint_ms(level), 0.1)
	rec["x"]["lost_hint_lab_ms"] = lost
	if lost > LOST_HINT_LAB_MS:
		rec["ok"] = false
		rec["why"] = "; ".join(([rec["why"]] if str(rec["why"]) != "" else []) + ["SHOW A MOVE after a mistake %.1f ms in the lab (> %.0f)" % [lost, LOST_HINT_LAB_MS]])
	return rec
