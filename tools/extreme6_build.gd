extends "res://tools/extreme5_build.gd"
## EXTREME EXPERIENCE PILOT, PHASE 2 (development only, ?xtest6=1): six
## enriched VERY HARD candidates, two per group, from EXISTING mechanics:
##   A  MAGNET + SWITCH / GATE   a switch reverses a magnet, so it leaves the
##                               other way and pulls from the other side
##   B  ARMOR + MAGNET           a magnet pulls a shelled block into a
##                               rammer's lane, then it is cracked
##   C  PORTAL + SPINNER + GATE  a turned spinner leaves through a portal; a
##                               chain gate decides when the way opens
##                               (<= 16 pieces: two of them are portal cells)
## Same hybrid method and acceptance as T1-T5 (tools/extreme5_build.gd,
## unchanged rules: Gate 0 technical limits, 5 repeated timing runs within
## 40 ms, every mechanic matters, distinct late traps, greedy players), with
## a smaller board (<= 14 pieces, <= 18 taps: VERY HARD, not longer) and
## each group's CENTRAL IDEA checked on the solution (idea_check). The two
## boards of a group must not be variants of each other. The T1-T5 file
## (data/dev/extreme5.json) counts as a known board set.
##
##   godot --headless --path . --script res://tools/extreme6_build.gd -- --recipe=A_magswitch --part=/tmp/a.json [--seed=1] [--tries=10] [--climb=500] [--starts=30] [--seeds=maps.json]
##   godot --headless --path . --script res://tools/extreme6_build.gd -- --merge=/tmp/a.json,... [--write]
##   godot --headless --path . --script res://tools/extreme6_build.gd -- --dossier=res://data/dev/extreme6.json

const EVENTS := preload("res://tools/extreme6_events.gd")
const X6_OUT := "res://data/dev/extreme6.json"
const X6_NOTES := "res://data/dev/extreme6_notes.json"

const X6_RECIPES := {
	"A_magswitch": {"group": "A", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(10, 13),
		"spin": Vector2i(2, 3), "rules": {"cw": 0.6, "ccw": 0.4}, "switches": Vector2i(1, 1), "flips": Vector2i(2, 3),
		"gates": Vector2i(1, 1), "links": Vector2i(1, 2), "magnets": Vector2i(2, 2), "flip_magnets": Vector2i(1, 2),
		"needs": ["switch", "gate"], "use": ["magnet", "switch"]},
	"B_armormag": {"group": "B", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(10, 13),
		"spin": Vector2i(2, 4), "rules": {"cw": 0.6, "ccw": 0.4}, "armor": Vector2i(1, 2), "magnets": Vector2i(2, 2),
		"needs": ["armor", "spinner"], "use": ["magnet", "ram"]},
	"C_portalgate": {"group": "C", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(10, 13),
		"spin": Vector2i(4, 6), "rules": {"cw": 0.6, "ccw": 0.4}, "portals": Vector2i(1, 1), "gates": Vector2i(1, 1),
		"links": Vector2i(1, 2), "needs": ["portal", "gate", "spinner"], "use": ["portal"]},
}


func recipes() -> Dictionary:
	return X6_RECIPES


func out_path() -> String:
	return X6_OUT


func notes_path() -> String:
	return X6_NOTES


func own_prefix() -> String:
	return "extreme6"


func test_name() -> String:
	return "xtest6"


func id_prefix() -> String:
	return "P"


func boards_per_recipe() -> int:
	return 2


## 14 pieces; group C 16 (its two portal cells are markers on empty cells,
## and with 14 a board has too few blocks for a real decision - the T1-T5
## limit was 16).
func max_pieces() -> int:
	return 16 if _recipe_now().begins_with("C_") else 14


var cur_recipe := ""


func _recipe_now() -> String:
	return cur_recipe if cur_recipe != "" else str(x_args.get("recipe", ""))


func max_len() -> int:
	return 18


func file_note() -> String:
	return "Development only. EXTREME phase 2: enriched VERY HARD candidates (docs/extreme6.md); never shared, never production."


## The interactive demonstrations shown before the first puzzle of a group
## whose mechanic combination the campaign never used (A, B). Tiny boards,
## one rule each, never the puzzle's solution (data/dev/extreme6.json "demos").
func extra_file_fields() -> Dictionary:
	return {"demos": DEMOS}


const DEMOS := [
	{"id": "DA1", "group": "A", "text": "A switch reverses every block linked to it - a magnet too. Its pull line moves to the other side.",
		"try": "Try it: clear this board.",
		"puzzle": {"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 3, "cols": 4, "map": [". . Y^%A .", "Gv B>&A* . Pv", ". . . R^"]}},
	{"id": "DA2", "group": "A", "text": "A chain gate behind a magnet stops its pull. Once the gate opens, the magnet pulls the next block behind it.",
		"try": "Try it: clear this board.",
		"puzzle": {"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 3, "cols": 3, "map": [". . P^+C", "Y<* XC Bv", ". . G^"]}},
	{"id": "DB1", "group": "B", "text": "A magnet can pull an armored block. The shell moves with it - into another block's lane.",
		"try": "Try it: clear this board.",
		"puzzle": {"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 3, "cols": 3, "map": ["Bv . .", "Y<* . Rv=", ". . ."]}},
]


## Known boards: as T1-T5, plus the T1-T5 file itself (a previous pilot).
## Also the boards a tester may have PLAYED (campaign 1-300, the Gate 0
## pilot, T1-T5) for the near-copy guard: a candidate seeded from T3 / T5
## or a campaign level must end up a different puzzle, not a variant.
func _load_known() -> void:
	super._load_known()
	var t15 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/extreme5.json"))
	_collect_maps(t15, "extreme5.json (T1-T5)")
	for d in DEMOS:
		known_keys[canonical(Array(d["puzzle"]["map"]))] = "demo " + d["id"]
	for n in range(1, 301):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%02d.json" % n))
		_add_played("campaign L%d" % n, Array(d["map"]))
	for b in JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/vh_pilot4.json"))["boards"]:
		_add_played("pilot " + str(b["id"]), Array(b["puzzle"]["map"]))
	for b in t15["boards"]:
		_add_played("T1-T5 " + str(b["id"]), Array(b["puzzle"]["map"]))
	print("known boards incl. T1-T5 and the demos: %d; played boards for the near-copy guard: %d" % [known_keys.size(), played.size()])


## [name, [8 forms: grids of colourless tokens]] of every played board.
var played := []


func _add_played(name: String, map: Array) -> void:
	var g := _grid(map)
	for r in g.size():
		for c in g[r].size():
			g[r][c] = _shape(CANON._strip_reward(g[r][c]))
	var forms := []
	var cur := g
	for k in 4:
		forms.append(cur)
		forms.append(CANON._mirror(cur))
		cur = CANON._rot(cur)
	played.append([name, forms])


## A token without its colour letters (shape, arrow and modifiers only).
static func _shape(t: String) -> String:
	if t.length() >= 2 and t[0] in COLORS:
		var out := "*" + t.substr(1)
		var at := out.find("#")
		if at >= 0:
			out = out.substr(0, at + 1) + "k" + out.substr(at + 2)
		return out
	return t


## The played board this one is a variant of (more than half of the
## occupied cells hold the same piece in some rotation / reflection), or "".
func near_copy_of(map: Array) -> String:
	var g := _grid(map)
	for r in g.size():
		for c in g[r].size():
			g[r][c] = _shape(g[r][c])
	for p in played:
		for f in p[1]:
			if f.size() != g.size() or f[0].size() != g[0].size():
				continue
			var same := 0
			var occupied := 0
			for r in g.size():
				for c in g[r].size():
					if g[r][c] != "." or f[r][c] != ".":
						occupied += 1
						if g[r][c] == f[r][c]:
							same += 1
			if occupied > 0 and same * 2 > occupied:
				return p[0]
	return ""


## Group A: some magnets are switch flip targets ("&A*").
func _add_magnets(map: Array, n: int) -> Array:
	var spec: Dictionary = recipes().get(str(x_args.get("recipe", "")), {})
	var want_flip := _pick(spec.get("flip_magnets", Vector2i.ZERO))
	var g := _grid(map)
	var plain := []
	var flips := []
	for r in g.size():
		for c in g[r].size():
			var t: String = g[r][c]
			if t.length() == 2 and t[0] in COLORS:
				plain.append(Vector2i(c, r))
			elif t.length() == 4 and t[0] in COLORS and t.substr(2, 1) == "&":
				flips.append(Vector2i(c, r))
	plain.shuffle()
	flips.shuffle()
	var made := 0
	for i in mini(want_flip, flips.size()):
		var at: Vector2i = flips[i]
		g[at.y][at.x] += "*"
		made += 1
	for i in mini(n - made, plain.size()):
		var at: Vector2i = plain[i]
		g[at.y][at.x] += "*"
	return _rows(g)


## The group's central idea, on the solver's solution replayed through
## BoardModel (tools/extreme6_events.gd).
func idea_check(level: LevelData, spec: Dictionary) -> Array:
	var why := EVENTS.idea_fails(spec["group"], EVENTS.events(level))
	var near := near_copy_of(_level_map(level))
	if near != "":
		why.append("a variant of " + near)
	return why


func parse(map: Array) -> LevelData:
	var level := super.parse(map)
	if level != null:
		level.set_meta("map", map)
	return level


## The map of a parsed level, rebuilt from its source (the climb keeps the
## map; idea_check only gets the level, so the map rides along on it).
func _level_map(level: LevelData) -> Array:
	return level.get_meta("map", [])


## The climb rewards the group's idea at every step (it is cheap: one solve
## and a replay), not only once every other gate holds - otherwise the search
## optimises difficulty on boards that never use the idea.
func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := super._x_eval(map, spec, quick)
	if quick or not e["solvable"]:
		return e
	var fails := EVENTS.idea_fails(spec["group"], EVENTS.events(parse(map)))
	if not fails.is_empty():
		e["score"] -= 25.0
		e["goal_ok"] = false
		if not str(e["why"]).contains(fails[0]):
			e["why"] = ", ".join(([e["why"]] if str(e["why"]) != "" else []) + fails)
	return e


## Climb starts: a random board whose solution already USES the group's idea
## (cheap filter: one solve and a replay), so the climb improves a board
## that has the idea instead of hoping a mutation creates it. Falls back to
## any solvable board after IDEA_TRIES random boards.
const IDEA_TRIES := 1500
var idea_hits := 0
var idea_samples := 0


func _x_random_valid(spec: Dictionary) -> Array:
	for i in IDEA_TRIES:
		var map := _random_board(spec)
		var nm := _pick(spec.get("magnets", Vector2i.ZERO))
		if nm > 0:
			map = _add_magnets(map, nm)
		var level := parse(map)
		if level == null or level.blocks.is_empty() or not _intact(map, level):
			continue
		idea_samples += 1
		var ev := EVENTS.events(level)
		if ev.is_empty():
			continue
		if EVENTS.idea_fails(spec["group"], ev).is_empty():
			idea_hits += 1
			return map
	return super._x_random_valid(spec)


func solution_events(level: LevelData) -> Dictionary:
	return EVENTS.events(level)


## The dossier and the report also show the idea events.
func _x_report(recipe: String, source: String, map: Array) -> Dictionary:
	cur_recipe = recipe
	var rec := super._x_report(recipe, source, map)
	cur_recipe = ""
	if rec.has("x"):
		rec["x"]["idea_events"] = solution_events(parse(map))
	return rec
