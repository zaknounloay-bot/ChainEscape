extends "res://tools/extreme11_build.gd"
## EXTREME phase 9 (development only): ONE new blind board for the 180-second
## test (docs/extreme14.md). Every acceptance rule of Q1 is kept (Gate 0
## limits, 5 repeated timing runs within 40 ms, greedy players, learners,
## late traps, the near-copy guard - now also against Q1 -, the expert gates,
## >= 2 timing magnets, SHOW A MOVE after every mistake within 40 ms, <= 700
## positions), plus:
##   - the idea on EVERY winning line (tools/extreme14_events.gd): a magnet a
##     switch reversed pulls a block (flip_pull), which later rams the shell
##     (flip_ram);
##   - SOLVER PARITY in every reachable position (tools/extreme14_parity.gd):
##     the game's Solver - SHOW A MOVE - agrees with exhaustive search. A
##     reversed magnet pulls from lines the Solver's precomputed magnet zone
##     may not cover; such a board is rejected, never shipped.
##   godot --headless --path . --script res://tools/extreme14_build.gd -- --accept=board.json --part=/tmp/r.json
##   godot --headless --path . --script res://tools/extreme14_build.gd -- --merge=a.json,... [--write]
## --learner_exception (accept only): the expert-LEARNER threshold alone
## becomes a recorded heuristic exception (a screening measure, not a
## validated predictor of human difficulty). Every other gate - solvability,
## parity, SHOW A MOVE, timing, greedy players, decisions, the idea on every
## winning line, timing magnets, near copies - still rejects. The board is
## then labelled EXPERIMENTAL - HUMAN DIFFICULTY UNVALIDATED.

const EV14 := preload("res://tools/extreme14_events.gd")
const EVENTS6 := preload("res://tools/extreme6_events.gd")
const X14_OUT := "res://data/dev/extreme14.json"
const X14_NOTES := "res://data/dev/extreme14_notes.json"

const X14_RECIPES := {
	"C2_flip": {"group": "R", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(10, 13),
		"spin": Vector2i(0, 5), "rules": {"cw": 0.6, "ccw": 0.4}, "armor": Vector2i(1, 2), "magnets": Vector2i(2, 3),
		"needs": ["armor", "switch"], "use": ["magnet"]},
}
const MUST14 := {"C2_flip": ["flip_pull", "flip_ram"]}
const LEARNER_WHY := "an expert learner (lookahead 4 / 6) solves it with"
const EXPERIMENTAL_LABEL := "EXPERIMENTAL - HUMAN DIFFICULTY UNVALIDATED"

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
	cur_recipe = "C2_flip"
	x_args["recipe"] = "C2_flip"
	var rec := _x_report("C2_flip", str(d.get("source", "hand")), Array(d["map"]))
	print("ACCEPT %s  %s" % [rec["ok"], rec.get("why", "")])
	_save_part_x(str(x_args["part"]), [rec] if rec["ok"] else [], [] if rec["ok"] else [[0.0, rec.get("why", ""), Array(d["map"])]])
	quit()


func recipes() -> Dictionary:
	return X14_RECIPES


func out_path() -> String:
	return X14_OUT


func notes_path() -> String:
	return X14_NOTES


func own_prefix() -> String:
	return "extreme14"


func test_name() -> String:
	return "ptest14"


func id_prefix() -> String:
	return "R"


func file_note() -> String:
	return "Development only. Blind timed test board; never shared, never production."


## Known / played: as phase 6, plus Q1 (played by both testers).
func _load_known() -> void:
	super._load_known()
	var x11 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme11.json"))
	_collect_maps(x11, "extreme11.json (Q1)")
	for b in x11["boards"]:
		_add_played("phase 6 " + str(b["id"]), Array(b["puzzle"]["map"]))


## Solver parity, exhaustive: in EVERY reachable position the game's Solver
## (_solve_keep_state, and recommend_move on a fresh solver as SHOW A MOVE
## does) agrees with exhaustive search. {"positions", "mismatch_solve",
## "mismatch_hint", "examples"}.
func parity(map: Array, name: String = "board") -> Dictionary:
	var level := parse(map)
	var s := _solver(level)
	var win: Dictionary = EXPERT.explore(s)["win"]
	var m := EVENTS6.model_of(level)
	var out := {"name": name, "positions": win.size(), "mismatch_solve": 0, "mismatch_hint": 0, "examples": []}
	_parity_walk(s, m, win, {}, [], out)
	return out


func _parity_walk(s: Solver, m: BoardModel, win: Dictionary, seen: Dictionary, path: Array, out: Dictionary) -> void:
	if s._alive_count == s._crate_n:
		return
	var key := s._key()
	if seen.has(key):
		return
	seen[key] = true
	var truth: bool = win.get(key, false)
	var found := not s._solve_keep_state().is_empty()
	if found != truth:
		out["mismatch_solve"] += 1
		if out["examples"].size() < 3:
			out["examples"].append({"kind": "solve", "truth": truth, "path": path.map(func(mv): return _say(s, mv))})
	var hint := Solver.from_model(m).recommend_move()
	var hint_ok := hint == -1 if not truth else hint >= 0
	if hint >= 0 and truth:
		# The hinted block's move in THIS search (keys are comparable here).
		hint_ok = false
		for mv in s._distinct_legal():
			if (mv & Solver.ID_MASK) == hint:
				s._do(mv)
				hint_ok = s._alive_count == s._crate_n or win.get(s._key(), false)
				s._undo_move(mv)
				break
	if not hint_ok:
		out["mismatch_hint"] += 1
		if out["examples"].size() < 3:
			out["examples"].append({"kind": "hint", "truth": truth, "hint": hint, "path": path.duplicate()})
	for mv in s._distinct_legal():
		var snap := m.snapshot()
		_play_on(m, mv)
		s._do(mv)
		path.append(mv)
		_parity_walk(s, m, win, seen, path, out)
		path.pop_back()
		s._undo_move(mv)
		m.restore(snap)


func idea_check(level: LevelData, spec: Dictionary) -> Array:
	var why := super.idea_check(level, spec)
	if _recipe_of(level) != "C2_flip":
		return why
	for k in MUST14["C2_flip"]:
		if not EV14.witness(level, k).is_empty():
			why.append("a winning line without " + k)
	var s := _solver(level)
	var t := EV11.timing(s, EXPERT.explore(s)["win"])
	if t["timing_magnets"].size() < TIMING_MAGNETS:
		why.append("only %d timing magnets (< %d)" % [t["timing_magnets"].size(), TIMING_MAGNETS])
	if why.is_empty():
		var p := parity(_level_map(level))
		if p["mismatch_solve"] > 0 or p["mismatch_hint"] > 0:
			why.append("the Solver disagrees with exhaustive search in %d / %d positions (SHOW A MOVE unreliable)" % [p["mismatch_solve"], p["mismatch_hint"]])
	return why


func solution_events(level: LevelData) -> Dictionary:
	return EV14.solution_facts(_solver(level))


func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := super._x_eval(map, spec, quick)
	if quick or not e["solvable"] or _recipe_for_spec(spec) != "C2_flip":
		return e
	var level := parse(map)
	var miss := []
	for k in MUST14["C2_flip"]:
		if not EV14.witness(level, k).is_empty():
			miss.append("a winning line without " + k)
	if not miss.is_empty():
		e["score"] -= 25.0 * miss.size()
		e["goal_ok"] = false
		e["why"] = ", ".join(([e["why"]] if str(e["why"]) != "" else []) + miss)
	return e


func _x_report(recipe: String, source: String, map: Array) -> Dictionary:
	var rec := super._x_report(recipe, source, map)
	if not rec.has("x"):
		return rec
	var level := parse(map)
	rec["x"]["idea_facts"] = EV14.solution_facts(_solver(level))
	var p := parity(map)
	rec["x"]["parity"] = {"positions": p["positions"], "mismatch_solve": p["mismatch_solve"], "mismatch_hint": p["mismatch_hint"]}
	if p["mismatch_solve"] > 0 or p["mismatch_hint"] > 0:
		rec["ok"] = false
		rec["why"] = "; ".join(([rec["why"]] if str(rec["why"]) != "" else []) + ["Solver parity fails in %d / %d positions" % [p["mismatch_solve"], p["mismatch_hint"]]])
	if x_args.has("learner_exception"):
		# Only the learner clause is lifted; any other reason still rejects.
		var kept := []
		var lifted := []
		for part in str(rec["why"]).split("; ", false):
			var sub := []
			for c in part.split(", ", false):
				(lifted if c.begins_with(LEARNER_WHY) else sub).append(c)
			if not sub.is_empty():
				kept.append(", ".join(sub))
		rec["x"]["heuristic_exceptions"] = lifted
		if not lifted.is_empty():
			rec["why"] = "; ".join(kept)
			rec["ok"] = kept.is_empty()
			if rec["ok"]:
				rec["label"] = EXPERIMENTAL_LABEL
	return rec
