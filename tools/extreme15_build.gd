extends "res://tools/extreme14_build.gd"
## EXTREME phase 10 (development only): ONE new blind board for the
## 120-second test (docs/extreme15.md). No magnets: a colour LOCK on a
## SPINNER. Every acceptance rule of phase 9 is kept (Gate 0 limits, 5
## repeated timing runs within 40 ms, greedy players, learners, late traps,
## the near-copy guard - now also against R1 -, the expert gates, SHOW A
## MOVE after every mistake within 40 ms, Solver parity in every reachable
## position), plus the idea on EVERY winning line (tools/extreme15_events.gd):
##   lock_turn   a locked spinner is turned while its key colour is still on
##               the board, and later escapes.
##   godot --headless --path . --script res://tools/extreme15_build.gd -- --accept=board.json --part=/tmp/s.json [--learner_exception]

const EV15 := preload("res://tools/extreme15_events.gd")
const X15_OUT := "res://data/dev/extreme15.json"
const X15_NOTES := "res://data/dev/extreme15_notes.json"

const X15_RECIPES := {
	"D_lock": {"group": "S", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(3, 6), "rules": {"cw": 0.5, "ccw": 0.5}, "locks": Vector2i(1, 2),
		"needs": ["lock", "spinner"], "use": []},
}
const MUST15 := {"D_lock": ["lock_turn"]}


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
	cur_recipe = "D_lock"
	x_args["recipe"] = "D_lock"
	var rec := _x_report("D_lock", str(d.get("source", "hand")), Array(d["map"]))
	print("ACCEPT %s  %s" % [rec["ok"], rec.get("why", "")])
	_save_part_x(str(x_args["part"]), [rec] if rec["ok"] else [], [] if rec["ok"] else [[0.0, rec.get("why", ""), Array(d["map"])]])
	quit()


func recipes() -> Dictionary:
	return X15_RECIPES


func out_path() -> String:
	return X15_OUT


func notes_path() -> String:
	return X15_NOTES


func own_prefix() -> String:
	return "extreme15"


func test_name() -> String:
	return "ptest15"


func id_prefix() -> String:
	return "S"


## Known / played: as phase 9, plus R1 (played by both testers).
func _load_known() -> void:
	super._load_known()
	var x14 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme14.json"))
	_collect_maps(x14, "extreme14.json (R1)")
	for b in x14["boards"]:
		_add_played("phase 9 " + str(b["id"]), Array(b["puzzle"]["map"]))


func idea_check(level: LevelData, spec: Dictionary) -> Array:
	var why := super.idea_check(level, spec)
	if _recipe_of(level) != "D_lock":
		return why
	for k in MUST15["D_lock"]:
		if not EV15.witness(level, k).is_empty():
			why.append("a winning line without " + k)
	if why.is_empty():
		var p := parity(_level_map(level))
		if p["mismatch_solve"] > 0 or p["mismatch_hint"] > 0:
			why.append("the Solver disagrees with exhaustive search in %d / %d positions (SHOW A MOVE unreliable)" % [p["mismatch_solve"], p["mismatch_hint"]])
	return why


func solution_events(level: LevelData) -> Dictionary:
	if _recipe_of(level) == "D_lock":
		return EV15.solution_facts(_solver(level))
	return super.solution_events(level)


func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := super._x_eval(map, spec, quick)
	if quick or not e["solvable"] or _recipe_for_spec(spec) != "D_lock":
		return e
	var level := parse(map)
	var miss := []
	for k in MUST15["D_lock"]:
		if not EV15.witness(level, k).is_empty():
			miss.append("a winning line without " + k)
	if not miss.is_empty():
		e["score"] -= 25.0 * miss.size()
		e["goal_ok"] = false
		e["why"] = ", ".join(([e["why"]] if str(e["why"]) != "" else []) + miss)
	return e


func _x_report(recipe: String, source: String, map: Array) -> Dictionary:
	var rec := super._x_report(recipe, source, map)
	if rec.has("x") and recipe == "D_lock":
		rec["x"]["idea_facts"] = EV15.solution_facts(_solver(parse(map)))
	return rec
