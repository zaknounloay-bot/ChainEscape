extends "res://tools/extreme15_build.gd"
## EXTREME phase 11 (development only): THREE new blind boards for the
## 120-second test (docs/extreme16.md), one per mechanic family. Every
## acceptance rule of phase 10 is kept (Gate 0 limits, 5 repeated timing
## runs within 40 ms, greedy players, learners, late traps, the near-copy
## guard - now also against S1 -, the expert gates, SHOW A MOVE after every
## mistake within 40 ms, Solver parity in every reachable position), plus each
## board's idea on EVERY winning line (tools/extreme16_events.gd):
##   A_carry    (magnets, spinners)           moved_then_turned
##   B_keyturn  (a lock, spinners, <= 6)      key_turn
##   C_flipram  (switch, shell, spinners)     reversed_ram
##   godot --headless --path . --script res://tools/extreme16_build.gd -- --recipe=A_carry --seeds=core.json --part=/tmp/a.json
##   godot --headless --path . --script res://tools/extreme16_build.gd -- --accept=board.json --recipe=B_keyturn --part=/tmp/b.json

const EV16 := preload("res://tools/extreme16_events.gd")
const MAX_SPINNERS_B := 6

const X16_RECIPES := {
	"A_carry": {"group": "TA", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(3, 5), "rules": {"cw": 0.5, "ccw": 0.5}, "magnets": Vector2i(2, 3),
		"needs": ["spinner"], "use": ["magnet"]},
	"B_keyturn": {"group": "TB", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 12),
		"spin": Vector2i(3, 5), "rules": {"cw": 0.4, "ccw": 0.3, "alt": 0.3}, "locks": Vector2i(1, 2),
		"needs": ["lock", "spinner"], "use": []},
	"C_flipram": {"group": "TC", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(2, 4), "rules": {"cw": 0.6, "ccw": 0.4}, "switches": Vector2i(1, 1), "flips": Vector2i(2, 3),
		"armor": Vector2i(1, 1), "gates": Vector2i(0, 1), "links": Vector2i(1, 2),
		"needs": ["switch", "armor"], "use": ["switch"]},
}
const MUST16 := {"A_carry": ["moved_then_turned"], "B_keyturn": ["key_turn"], "C_flipram": ["reversed_ram"]}


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
	var recipe := str(x_args["recipe"])
	cur_recipe = recipe
	var rec := _x_report(recipe, str(d.get("source", "hand")), Array(d["map"]))
	print("ACCEPT %s  %s" % [rec["ok"], rec.get("why", "")])
	_save_part_x(str(x_args["part"]), [rec] if rec["ok"] else [], [] if rec["ok"] else [[0.0, rec.get("why", ""), Array(d["map"])]])
	quit()


func recipes() -> Dictionary:
	return X16_RECIPES


func out_path() -> String:
	return "res://data/dev/extreme16.json"


func notes_path() -> String:
	return "res://data/dev/extreme16_notes.json"


func own_prefix() -> String:
	return "extreme16"


func test_name() -> String:
	return "ptest16"


func id_prefix() -> String:
	return "T"


## Known / played: as phase 10, plus S1 (played by both testers).
func _load_known() -> void:
	super._load_known()
	var x15 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme15.json"))
	_collect_maps(x15, "extreme15.json (S1)")
	for b in x15["boards"]:
		_add_played("phase 10 " + str(b["id"]), Array(b["puzzle"]["map"]))


static func spinners_in(map: Array) -> int:
	var n := 0
	for row in map:
		for t in str(row).split(" ", false):
			if t.contains("@"):
				n += 1
	return n


func idea_check(level: LevelData, spec: Dictionary) -> Array:
	var why := super.idea_check(level, spec)
	var recipe := _recipe_of(level)
	if not MUST16.has(recipe):
		return why
	for k in MUST16[recipe]:
		if not EV16.witness(level, k).is_empty():
			why.append("a winning line without " + k)
	if recipe == "B_keyturn" and spinners_in(_level_map(level)) > MAX_SPINNERS_B:
		why.append("%d spinners (> %d: complexity must not come from spinner count)" % [spinners_in(_level_map(level)), MAX_SPINNERS_B])
	if why.is_empty():
		var p := parity(_level_map(level))
		if p["mismatch_solve"] > 0 or p["mismatch_hint"] > 0:
			why.append("the Solver disagrees with exhaustive search in %d / %d positions (SHOW A MOVE unreliable)" % [p["mismatch_solve"], p["mismatch_hint"]])
	return why


func solution_events(level: LevelData) -> Dictionary:
	if MUST16.has(_recipe_of(level)):
		return EV16.solution_facts(_solver(level))
	return super.solution_events(level)


func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := super._x_eval(map, spec, quick)
	var recipe := _recipe_for_spec(spec)
	if quick or not e["solvable"] or not MUST16.has(recipe):
		return e
	var level := parse(map)
	var miss := []
	for k in MUST16[recipe]:
		if not EV16.witness(level, k).is_empty():
			miss.append("a winning line without " + k)
	if recipe == "B_keyturn" and spinners_in(map) > MAX_SPINNERS_B:
		miss.append("too many spinners")
	if not miss.is_empty():
		e["score"] -= 25.0 * miss.size()
		e["goal_ok"] = false
		e["why"] = ", ".join(([e["why"]] if str(e["why"]) != "" else []) + miss)
	return e


func _x_report(recipe: String, source: String, map: Array) -> Dictionary:
	var rec := super._x_report(recipe, source, map)
	if rec.has("x") and MUST16.has(recipe):
		rec["x"]["idea_facts"] = EV16.solution_facts(_solver(parse(map)))
		rec["x"]["spinners"] = spinners_in(map)
	return rec
