extends "res://tools/extreme6_build.gd"
## EXTREME DESIGN EXPERIMENT (development only, ?xtest7=1): two HAND-DESIGNED
## VERY HARD candidates (docs/extreme7.md). Each board was drawn around one
## strategic idea first (insight, then dependency chain, then the board);
## the solver only validates it, and a search may only refine cells outside
## the designed core (--refine with a seed board and its frozen cells).
##   A_remote    SWITCH / GATE + SPINNERS  one switch acts in two places at
##                                         once; the timing must suit both
##   B_geometry  MAGNET + ARMOR + SPINNERS the shell cannot be reached: a
##                                         magnet brings the hammer to it,
##                                         turning the spinner as it drags it
## Same acceptance as T1-T5 and P1/P2 (tools/extreme5_build.gd and
## tools/extreme6_build.gd rules, unchanged: Gate 0 technical limits, 5
## repeated timing runs within 40 ms, every mechanic matters, greedy
## players, rule-of-thumb learners, late traps, <= 14 pieces, <= 18 taps,
## not a variant of a played board), plus each idea checked over EVERY
## winning line (exhaustively, extreme7_events.gd), not only on the solver's one.
##   godot --headless --path . --script res://tools/extreme7_lab.gd -- --file=boards.json [--full]
##   godot --headless --path . --script res://tools/extreme7_build.gd -- --recipe=A_remote --seeds=seed.json --part=/tmp/a.json [--climb=300]
##   godot --headless --path . --script res://tools/extreme7_build.gd -- --merge=/tmp/a.json,/tmp/b.json [--write]

const EV7 := preload("res://tools/extreme7_events.gd")
const X7_OUT := "res://data/dev/extreme7.json"
const X7_NOTES := "res://data/dev/extreme7_notes.json"

## Groups A7 / B7: the phase-2 idea events of extreme6 (groups A / B / C)
## do not apply; this file's own idea is checked by idea_check.
## Search fields are only used by --refine (mutations outside the frozen
## core keep these counts); the designed core is in the seed file.
const X7_RECIPES := {
	"A_remote": {"group": "A7", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(2, 5), "rules": {"cw": 0.6, "ccw": 0.4}, "switches": Vector2i(1, 1), "flips": Vector2i(1, 3),
		"gates": Vector2i(1, 1), "links": Vector2i(1, 2), "needs": ["switch", "gate", "spinner"], "use": ["switch"]},
	"B_geometry": {"group": "B7", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(9, 13),
		"spin": Vector2i(2, 5), "rules": {"cw": 0.6, "ccw": 0.4}, "armor": Vector2i(1, 2), "magnets": Vector2i(1, 2),
		"needs": ["armor", "spinner"], "use": ["magnet", "ram"]},
}

## The idea facts each recipe needs on EVERY winning line (EV7.must_facts).
const MUST := EV7.MUST


func recipes() -> Dictionary:
	return X7_RECIPES


func out_path() -> String:
	return X7_OUT


func notes_path() -> String:
	return X7_NOTES


func own_prefix() -> String:
	return "extreme7"


func test_name() -> String:
	return "xtest7"


func id_prefix() -> String:
	return "H"


func boards_per_recipe() -> int:
	return 1


func max_pieces() -> int:
	return 14


func max_len() -> int:
	return 18


func file_note() -> String:
	return "Development only. EXTREME design experiment: two hand-designed VERY HARD candidates (docs/extreme7.md); never shared, never production."


## No new demonstrations: the testers of this experiment already met every
## combination here in ?xtest6 (switch reversing blocks, gates, magnet + armor).
func extra_file_fields() -> Dictionary:
	return {}


## Known / played boards: as phase 2, plus the phase 2 boards P1 / P2.
func _load_known() -> void:
	super._load_known()
	var x6 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme6.json"))
	_collect_maps(x6, "extreme6.json (P1-P2)")
	for b in x6["boards"]:
		_add_played("phase 2 " + str(b["id"]), Array(b["puzzle"]["map"]))
	for d in x6.get("demos", []):
		known_keys[canonical(Array(d["puzzle"]["map"]))] = "demo " + d["id"]


## The idea on every winning line, plus the near-copy guard.
func idea_check(level: LevelData, _spec: Dictionary) -> Array:
	var why := []
	var recipe := _recipe_of(level)
	var f := EV7.must_facts(level, recipe)
	for k in MUST.get(recipe, []):
		if not f.get(k, false):
			why.append("a winning line without " + k)
	var near := near_copy_of(_level_map(level))
	if near != "":
		why.append("a variant of " + near)
	return why


func _recipe_of(level: LevelData) -> String:
	if cur_recipe != "":
		return cur_recipe
	if x_args.has("recipe"):
		return str(x_args["recipe"])
	return "B_geometry" if level.blocks.any(func(b): return b.magnet) else "A_remote"


func solution_events(level: LevelData) -> Dictionary:
	return EV7.solution_facts(_solver(level))


# --- Refinement around a hand-made core (--seeds) --------------------------------------------

## --seeds=file.json: {"map": [row, ...], "frozen": [[row, col], ...]}. Every
## climb starts from this one hand-made board; the frozen cells (the
## designed core: its pieces AND the empty cells its lanes need) never
## change. The search may only move, turn, add or remove other pieces.
var frozen := {}


func _seed_maps() -> Array:
	if not x_args.has("seeds"):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["seeds"])))
	frozen.clear()
	for rc in d.get("frozen", []):
		frozen[Vector2i(int(rc[1]), int(rc[0]))] = true
	var out := []
	for i in int(x_args.get("tries", "12")):
		out.append(Array(d["map"]))
	return out


func _mutate(map: Array, spec: Dictionary) -> Array:
	if frozen.is_empty():
		return super._mutate(map, spec)
	var g := _grid(map)
	var free_empty := []
	var free_pieces := []
	for r in g.size():
		for c in g[r].size():
			if frozen.has(Vector2i(c, r)):
				continue
			if g[r][c] == ".":
				free_empty.append(Vector2i(c, r))
			elif g[r][c].length() >= 2 and g[r][c][0] in COLORS and not g[r][c].ends_with("*") and not g[r][c].contains("="):
				free_pieces.append(Vector2i(c, r))
	var op := rng.randi_range(0, 9)
	if op <= 1 and not free_empty.is_empty() and _pieces(map) < max_pieces():
		# Add a plain arrow or a spinner (the recipe's spinner rules).
		var at: Vector2i = free_empty[rng.randi_range(0, free_empty.size() - 1)]
		var t: String = COLORS[rng.randi_range(0, 4)] + DIRS[rng.randi_range(0, 3)]
		if rng.randf() < 0.5:
			t += RULE_SUFFIX[_weighted(spec.get("rules", {"cw": 1.0}))]
		g[at.y][at.x] = t
		return _rows(g)
	if op == 2 and not free_pieces.is_empty():
		var at: Vector2i = free_pieces[rng.randi_range(0, free_pieces.size() - 1)]
		g[at.y][at.x] = "."
		return _rows(g)
	var orig := _grid(map)
	for k in 12:
		var cand := _grid(super._mutate(map, spec))
		var ok := true
		for at in frozen:
			if cand[at.y][at.x] != orig[at.y][at.x]:
				ok = false
				break
		if ok:
			return _rows(cand)
	return map


## The climb rewards the idea on EVERY winning line at every step (boards are
## small: the exhaustive check costs a few ms), so the search never trades
## the designed idea for difficulty from elsewhere.
func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := super._x_eval(map, spec, quick)
	if quick or not e["solvable"]:
		return e
	var recipe := ""
	for r in recipes():
		if recipes()[r] == spec:
			recipe = r
	var f := EV7.must_facts(parse(map), recipe)
	var miss := []
	for k in MUST.get(recipe, []):
		if not f.get(k, false):
			miss.append("a winning line without " + k)
	if not miss.is_empty():
		e["score"] -= 25.0 * miss.size()
		e["goal_ok"] = false
		e["why"] = ", ".join(([e["why"]] if str(e["why"]) != "" else []) + miss)
	return e
