extends "res://tools/extreme7_build.gd"
## EXTREME EXPERT EXPERIMENT (development only, ?xtest8=1): three
## concept-first candidates for an EXTREME tier aimed at experienced players
## (docs/extreme8.md):
##   X1_remote       DEEP REMOTE CONTROL   switch / gate / spinners
##   X2_cascade      CASCADING GEOMETRY    magnet / armor / spinners
##   X3_integration  EXPERT INTEGRATION    see the recipe
## Every acceptance rule of T1-T5 / P1-P2 / H1-H2 is kept unchanged
## (tools/extreme5_build.gd, extreme6, extreme7: Gate 0 technical limits, 5
## repeated timing runs within 40 ms, every mechanic matters, greedy players,
## rule-of-thumb learners, late traps, the near-copy guard, the idea on
## EVERY winning line), plus EXPERT gates from the calibration on the boards
## the experienced tester played (tools/extreme8_calibrate.gd):
##   - rule-of-thumb learners looking 4 and 6 moves ahead (with memory) still
##     hit >= 12 dead ends (H2, rated HARD by him: 5 / 3; T3: 17 / 18; T5,
##     his hardest: 16 / 14),
##   - >= 4 decisions on the solution that 6-move lookahead cannot settle,
##   - a greedy player looking 6 moves ahead wins <= 5 %.
## These are machine screens, not a difficulty claim: only people decide.
##   godot --headless --path . --script res://tools/extreme8_lab.gd -- --file=boards.json [--full]
##   godot --headless --path . --script res://tools/extreme8_build.gd -- --recipe=X2_cascade --seeds=seed.json --part=/tmp/x2.json
##   godot --headless --path . --script res://tools/extreme8_build.gd -- --merge=a.json,... [--write]

const EV8 := preload("res://tools/extreme8_events.gd")
const EXPERT := preload("res://tools/expert_probe.gd")
const X8_OUT := "res://data/dev/extreme8.json"
const X8_NOTES := "res://data/dev/extreme8_notes.json"
const EXPERT_LEARNER := 12.0
const EXPERT_DECISIONS := 4
const EXPERT_LOOK6_GREEDY := 0.05

const X8_RECIPES := {
	"X1_remote": {"group": "X1", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(10, 15),
		"spin": Vector2i(3, 6), "rules": {"cw": 0.6, "ccw": 0.4}, "switches": Vector2i(1, 2), "flips": Vector2i(2, 4),
		"gates": Vector2i(1, 2), "links": Vector2i(1, 3), "needs": ["switch", "gate", "spinner"], "use": ["switch"]},
	"X2_cascade": {"group": "X2", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(10, 15),
		"spin": Vector2i(2, 6), "rules": {"cw": 0.6, "ccw": 0.4}, "armor": Vector2i(1, 2), "magnets": Vector2i(2, 3),
		# The ram is the payoff of the aiming (every neighbour of the cell the
		# hammer is carried to is a magnet's lane), not a choice; the choices
		# are the magnets' timing and the hammer's turn count.
		"needs": ["armor", "spinner"], "use": ["magnet"]},
	"X3_integration": {"group": "X3", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(10, 15),
		"spin": Vector2i(4, 8), "rules": {"cw": 0.4, "ccw": 0.4, "alt": 0.2}, "magnets": Vector2i(2, 3),
		"needs": ["spinner"], "use": ["magnet"]},
}

## The facts each design needs on EVERY winning line (tools/extreme8_events.gd).
const MUST8 := {
	"X1_remote": ["flip_opens_gate", "gate_before_switch"],
	"X2_cascade": ["relay_carry", "aimed_ram"],
	"X3_integration": ["moved_turned_adv"],
}


func recipes() -> Dictionary:
	return X8_RECIPES


func out_path() -> String:
	return X8_OUT


func notes_path() -> String:
	return X8_NOTES


func own_prefix() -> String:
	return "extreme8"


func test_name() -> String:
	return "xtest8"


func id_prefix() -> String:
	return "E"


func boards_per_recipe() -> int:
	return 1


## The T1-T5 limit (T3: 14 pieces, T5: 13); still within the campaign's 7x7.
## X3 (magnets + advanced spinners): 13, because at 16 pieces its solver
## work broke the 40 ms mobile budget 3-14 times over (docs/extreme8.md).
func max_pieces() -> int:
	return 13 if _recipe_now().begins_with("X3_") else 16


func max_len() -> int:
	return 18


func file_note() -> String:
	return "Development only. EXTREME expert experiment: three concept-first candidates for experienced players (docs/extreme8.md); never shared, never production."


## Known / played: as phase 3, plus H1-H2 (both were played by testers).
func _load_known() -> void:
	super._load_known()
	var x7 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme7.json"))
	_collect_maps(x7, "extreme7.json (H1-H2)")
	for b in x7["boards"]:
		_add_played("phase 3 " + str(b["id"]), Array(b["puzzle"]["map"]))


func _recipe_of(level: LevelData) -> String:
	if cur_recipe != "":
		return cur_recipe
	return str(x_args.get("recipe", ""))


func idea_check(level: LevelData, _spec: Dictionary) -> Array:
	var why := []
	var recipe := _recipe_of(level)
	for k in MUST8.get(recipe, []):
		if not EV8.witness(level, k).is_empty():
			why.append("a winning line without " + k)
	var near := near_copy_of(_level_map(level))
	if near != "":
		why.append("a variant of " + near)
	return why


func solution_events(level: LevelData) -> Dictionary:
	return EV8.solution_facts(_solver(level))


func _recipe_for_spec(spec: Dictionary) -> String:
	for r in recipes():
		if recipes()[r] == spec:
			return r
	return ""


## The idea on every winning line at every climb step, and - once every
## other goal holds - the expert gates (deep-lookahead learners), so the
## search is steered toward deep traps, not only many shallow ones.
func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := super._x_eval(map, spec, quick)
	if quick or not e["solvable"]:
		return e
	var recipe := _recipe_for_spec(spec)
	var level := parse(map)
	var miss := []
	for k in MUST8.get(recipe, []):
		if not EV8.witness(level, k).is_empty():
			miss.append("a winning line without " + k)
	if not miss.is_empty():
		e["score"] -= 25.0 * miss.size()
		e["goal_ok"] = false
		e["why"] = ", ".join(([e["why"]] if str(e["why"]) != "" else []) + miss)
		return e
	if e["goal_ok"]:
		var ex := expert_gates(level, true)
		e["score"] += 2.0 * minf(ex["learner_min"], 20.0)
		if not ex["ok"]:
			e["goal_ok"] = false
			e["why"] = ex["why"]
	return e


## The expert gates. `quick` = fewer learner sessions (climb); acceptance
## uses more.
func expert_gates(level: LevelData, quick: bool = false) -> Dictionary:
	var s := _solver(level)
	var runs := 5 if quick else 11
	var learn := {}
	var lmin := 99.0
	for look in [4, 6]:
		var best := 99.0
		for o in ORDERS:
			best = minf(best, PROBE.learner_stats(s, runs, look, o, 30000)["dead_ends_med"])
		learn["look%d" % look] = best
		lmin = minf(lmin, best)
	var why := []
	if lmin < EXPERT_LEARNER:
		why.append("an expert learner (lookahead 4 / 6) solves it with %.0f dead ends (< %.0f)" % [lmin, EXPERT_LEARNER])
	var out := {"learner": learn, "learner_min": lmin}
	if why.is_empty() or not quick:
		var m := EXPERT.measure(s)
		out["measure"] = m
		if int(m["decisions"][6]) < EXPERT_DECISIONS:
			why.append("only %d decisions that 6-move lookahead cannot settle (< %d)" % [m["decisions"][6], EXPERT_DECISIONS])
		var g := PROBE.policy_win(s, "look6", 60 if quick else 120, 31)
		out["look6_greedy"] = g
		if g > EXPERT_LOOK6_GREEDY:
			why.append("a 6-move lookahead greedy player wins %.0f%%" % (g * 100))
	out["ok"] = why.is_empty()
	out["why"] = ", ".join(why)
	return out


func _x_report(recipe: String, source: String, map: Array) -> Dictionary:
	var rec := super._x_report(recipe, source, map)
	if not rec.has("x"):
		return rec
	cur_recipe = recipe
	var level := parse(map)
	var ex := expert_gates(level)
	rec["x"]["expert"] = ex
	rec["x"]["idea_facts"] = EV8.solution_facts(_solver(level))
	cur_recipe = ""
	if not ex["ok"]:
		rec["ok"] = false
		rec["why"] = "; ".join(([rec["why"]] if str(rec["why"]) != "" else []) + [ex["why"]])
	return rec


# --- Iterated refinement -----------------------------------------------------------------------

## Each new try continues from the best board so far (the near list is
## sorted best first), instead of the original seed: the refinement keeps
## its progress across tries. The frozen core never changes.
var _seed_list: Array = []


func _seed_maps() -> Array:
	_seed_list = super._seed_maps()
	return _seed_list


func _save_part_x(path: String, boards: Array, near: Array) -> void:
	super._save_part_x(path, boards, near)
	if not near.is_empty():
		for i in _seed_list.size():
			_seed_list[i] = Array(near[0][2])
