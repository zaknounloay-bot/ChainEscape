extends "res://tools/extreme16_build.gd"
## EXTREME phase 13 (development only): the curated Time Attack bank - FIVE
## new boards for the 120-second test (docs/extreme17.md), each with its own
## mechanic family and idea, from MEDIUM to EXTREME. Every acceptance rule of
## phase 11 is kept unchanged (Gate 0 limits, 5 repeated timing runs within
## 40 ms, greedy players, late traps, the near-copy guard - now also against
## TA / TB / TC -, the expert gates, SHOW A MOVE after a mistake within 40 ms,
## Solver parity in every reachable position, the idea on EVERY winning line,
## every recipe mechanic a real decision), plus a TARGET BAND:
##   the expert learner (lookahead 4 / 6, the fewest dead ends of the best
##   order) must fall in the band of the board's target difficulty. The bands
##   come from the six boards with human results (docs/experimental_inventory.md):
##   TB 7, R1 9 -> MEDIUM-HARD; TA 10, Q1 12 -> HARD; TC 18 -> HARD-VERY
##   HARD; S1 23 -> VERY HARD with a TIME UP. A TARGET, never a validated
##   human rating; a board outside its band is reported, not forced in.
##   (Phase 13B: P5 and P6 retargeted to the 90 s prototype, band TA90 4-10;
##   P7-P9 paused.)
##     P5_gate      MEDIUM     chain gate + spinners              gate_through
##     P6_altshell  HARD       armored shell + alternating spinners  alt_ram
##   (P6 was first a movable crate board, crate_through: rejected - the
##   Solver's search overflows the stack on crate boards, in the game too.)
##     P7_seq       HARD       Sequence blocks + spinners         advance_turn
##     P8_flipgate  VERY HARD  switch + chain gate + spinners     flip_opens_gate
##     P9_gatepull  EXTREME    magnets + chain gate + spinners    gate_pull
##   godot --headless --path . --script res://tools/extreme17_build.gd -- --accept=board.json --recipe=P5_gate --part=/tmp/p5.json

const EV17 := preload("res://tools/extreme17_events.gd")

const X17_RECIPES := {
	"P5_gate": {"group": "P5", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(2, 5), "rules": {"cw": 0.6, "ccw": 0.4}, "gates": Vector2i(1, 1), "links": Vector2i(2, 3),
		"needs": ["gate", "spinner"], "use": []},
	"P6_altshell": {"group": "P6", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(3, 6), "rules": {"alt": 0.5, "cw": 0.3, "ccw": 0.2}, "armor": Vector2i(1, 1),
		"needs": ["armor", "spinner"], "use": ["ram"]},
	"P7_seq": {"group": "P7", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(3, 6), "rules": {"cw": 0.5, "ccw": 0.5}, "seq": Vector2i(1, 2),
		"needs": ["spinner", "sequence"], "use": ["advance"]},
	"P8_flipgate": {"group": "P8", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(2, 5), "rules": {"cw": 0.6, "ccw": 0.4}, "switches": Vector2i(1, 1), "flips": Vector2i(1, 3),
		"gates": Vector2i(1, 1), "links": Vector2i(1, 3), "needs": ["switch", "gate"], "use": ["switch"]},
	"P9_gatepull": {"group": "P9", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(2, 5), "rules": {"cw": 0.5, "ccw": 0.5}, "magnets": Vector2i(1, 2), "gates": Vector2i(1, 1),
		"links": Vector2i(1, 3), "needs": ["gate", "spinner"], "use": ["magnet"]},
}
const MUST17 := {"P5_gate": ["gate_through"], "P6_altshell": ["alt_ram"], "P7_seq": ["advance_turn"],
	"P8_flipgate": ["flip_opens_gate"], "P9_gatepull": ["gate_pull"]}
## Phase 13B: P5 and P6 retargeted to the 90-second prototype ("TA90").
const TARGET := {"P5_gate": "TA90", "P6_altshell": "TA90", "P7_seq": "HARD", "P8_flipgate": "VERY HARD", "P9_gatepull": "EXTREME"}
## The expert learner bands (inclusive) of each target difficulty.
const BANDS := {"MEDIUM": Vector2(3, 8), "HARD": Vector2(9, 15), "VERY HARD": Vector2(16, 22), "EXTREME": Vector2(23, 999),
	# 90 s, slightly more accessible: where TB (7) and TA (10-11) sit - boards the
	# two testers solved in 25-74 s on the 120 s clock.
	"TA90": Vector2(4, 10)}


## Sequence blocks (":") are lab tokens: parsed by every phase-13 tool.
func _init() -> void:
	LevelManager.dev_sequence = true


func recipes() -> Dictionary:
	return X17_RECIPES


func out_path() -> String:
	return "res://data/dev/extreme17.json"


func notes_path() -> String:
	return "res://data/dev/extreme17_notes.json"


func own_prefix() -> String:
	return "extreme17"


func test_name() -> String:
	return "ptest17"


func id_prefix() -> String:
	return "P"


## The band a learner score falls in ("" below MEDIUM: too easy).
static func band_of(learner: float) -> String:
	for t in ["MEDIUM", "HARD", "VERY HARD", "EXTREME"]:
		if learner >= BANDS[t].x and learner <= BANDS[t].y:
			return t
	return ""


## Known / played: as phase 11, plus TA, TB, TC (played by both testers).
func _load_known() -> void:
	super._load_known()
	for f in ["extreme16_a", "extreme16_b", "extreme16_c"]:
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/%s.json" % f))
		_collect_maps(d, f + ".json")
		for b in d["boards"]:
			_add_played("phase 11 " + str(b["id"]), Array(b["puzzle"]["map"]))


func idea_check(level: LevelData, spec: Dictionary) -> Array:
	var why := super.idea_check(level, spec)  # the near-copy guard (no earlier recipe's idea applies)
	var recipe := _recipe_of(level)
	if not MUST17.has(recipe):
		return why
	for k in MUST17[recipe]:
		if not EV17.witness(level, k).is_empty():
			why.append("a winning line without " + k)
	if why.is_empty():
		var p := parity(_level_map(level))
		if p["mismatch_solve"] > 0 or p["mismatch_hint"] > 0:
			why.append("the Solver disagrees with exhaustive search in %d / %d positions (SHOW A MOVE unreliable)" % [p["mismatch_solve"], p["mismatch_hint"]])
	return why


func solution_events(level: LevelData) -> Dictionary:
	if MUST17.has(_recipe_of(level)):
		return EV17.solution_facts(_solver(level))
	return super.solution_events(level)


func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := super._x_eval(map, spec, quick)
	var recipe := _recipe_for_spec(spec)
	if quick or not e["solvable"] or not MUST17.has(recipe):
		return e
	var level := parse(map)
	var miss := []
	for k in MUST17[recipe]:
		if not EV17.witness(level, k).is_empty():
			miss.append("a winning line without " + k)
	if not miss.is_empty():
		e["score"] -= 25.0 * miss.size()
		e["goal_ok"] = false
		e["why"] = ", ".join(([e["why"]] if str(e["why"]) != "" else []) + miss)
	return e


## Phase 11's report (the learner screen recorded, not a gate), then the
## target band: the learner must fall in the band of the recipe's target.
func _x_report(recipe: String, source: String, map: Array) -> Dictionary:
	var rec := super._x_report(recipe, source, map)
	if not rec.has("x") or not MUST17.has(recipe):
		return rec
	rec["x"]["idea_facts"] = EV17.solution_facts(_solver(parse(map)))
	var lm := float(rec["x"].get("expert", {}).get("learner_min", 0.0))
	var target: String = TARGET[recipe]
	var measured := band_of(lm)
	var in_band: bool = lm >= BANDS[target].x and lm <= BANDS[target].y
	rec["x"]["target"] = target
	rec["x"]["band"] = measured
	rec["x"]["in_band"] = in_band
	rec["x"]["band_range"] = [BANDS[target].x, BANDS[target].y]
	rec["x"]["heuristic_exceptions"] = []  # the learner is the band here, not an exception
	rec["label"] = "EXPERIMENTAL - TARGET %s - HUMAN DIFFICULTY UNVALIDATED" % target
	if not in_band:
		rec["ok"] = false
		rec["why"] = "; ".join(([rec["why"]] if str(rec["why"]) != "" else []) + ["expert learner %.0f is outside the %s band %.0f-%.0f" % [lm, target, BANDS[target].x, BANDS[target].y]])
	return rec
