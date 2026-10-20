extends SceneTree
## VERY HARD GATE 0 PILOT (development only, ?vhtest4=1): builds the 28
## candidate boards of data/dev/vh_pilot4.json from EXISTING campaign
## mechanics, with a technical report for every board. Nothing here is
## production: the live Friend generator, the shared-challenge format, the
## backend and the 300 campaign levels are never touched.
##
##   # one recipe (or group) into a part file - run several in parallel:
##   godot --headless --path . --script res://tools/vh_pilot4_build.gd -- --recipe=G1_remote --part=/tmp/g1.json [--seed=1] [--tries=24] [--climb=220]
##   # the baseline boards (live VERY HARD + earlier controls):
##   godot --headless --path . --script res://tools/vh_pilot4_build.gd -- --baseline --part=/tmp/g0.json
##   # merge the parts: duplicate checks, final ids, the board file:
##   godot --headless --path . --script res://tools/vh_pilot4_build.gd -- --merge=/tmp/g0.json,/tmp/g1.json,... [--write]
##
## Groups (the tester never sees them):
##   G0 BASELINE   2 live VERY HARD (FriendGenerator, unchanged spec), 2
##                 earlier hardest-for-people boards (test 2 P13 / P09,
##                 rotated 180 degrees and recoloured: never seen that way),
##                 4 new arrows + clockwise boards: "coupled" (few moves are
##                 ever risk-free) and "late" (mistakes show up late).
##   G1 REMOTE     switch / flip + chain gates (+ clockwise spinners)
##   G2 ROTATION   clockwise / counter-clockwise / alternating / pattern
##                 spinners (+ colour locks)
##   G3 TOPOLOGY   portals + Sequence blocks (+ clockwise spinners)
##   G4 CRATE      Movable crates: crate-led, crate + armor, crate + spinners
##
## Boards are found by hill climbing from random boards (the method of
## tools/generate_era3.gd) and kept only if every acceptance rule holds:
## solvable within the recipient's 60000-node limit (and a much lower
## working budget), every advanced mechanic MATTERS (LevelAnalysis impact:
## the board without it is easier or unsolvable), the solution is not
## dominated by risk-free moves, a random tapper rarely wins, SHOW A MOVE
## stays within budget on every state of the solution and after every trap,
## and no duplicate (rotation / reflection / recolouring / relabelling) of a
## campaign level, an earlier test board, a lab board or another candidate.

const OUT := "res://data/dev/vh_pilot4.json"
const CANON := preload("res://tools/vh_pilot4_canon.gd")
const ASSIST := {"undo": 3, "show_a_move": 1, "hammer": 0}  # live VERY HARD [3, 1, 0]
## Working search budget while climbing / accepting (the recipient keeps 60000).
const WORK_LIMIT := 20000
const RECIPIENT_LIMIT := 60000
## A mechanic "matters" if taking it away lowers the board's difficulty by
## at least this much (LevelAnalysis impact), or makes it unsolvable.
const MIN_IMPACT := 1.0
## Mobile time budget, as NATIVE DESKTOP milliseconds, for the recipient's
## check, SHOW A MOVE on the solution and SHOW A MOVE after a mistake.
## Calibrated on the pilot's own boards: the Web (WebAssembly) build in
## Chromium with 4x CPU throttling took 4-7x the desktop time, so 40 ms
## keeps every measure under ~300 ms in that simulation (not an iPhone
## measurement).
const MOBILE_MS_DESKTOP := 40.0
const COLORS := ["R", "B", "G", "Y", "P"]
const DIRS := ["^", ">", "v", "<"]
const RULE_SUFFIX := {"cw": "@", "ccw": "@-", "alt": "@~", "pattern": "@*"}
## First campaign level of each mechanic (tester eligibility / reminders).
const FIRST_LEVEL := CANON.FIRST_LEVEL

## Recipes. sizes: Vector2i(columns, rows). Counts are ranges. needs: the
## mechanic families whose impact must be > 0. goal: acceptance targets.
const RECIPES := {
	"G0_coupled": {"group": "G0", "count": 2, "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(15, 18),
		"spin": Vector2i(8, 10), "rules": {"cw": 1.0}, "needs": ["spinner"],
		"goal": {"max_calm": 0.45, "min_one_safe": 3, "min_dec": 7, "len": Vector2i(14, 22)}},
	"G0_late": {"group": "G0", "count": 2, "sizes": [Vector2i(7, 7)], "blocks": Vector2i(18, 21),
		"spin": Vector2i(5, 7), "rules": {"cw": 1.0}, "needs": ["spinner"],
		"goal": {"max_calm": 0.55, "min_dec": 6, "min_trap_delay": 4.0, "len": Vector2i(16, 24)}},
	"G1_remote": {"group": "G1", "count": 5, "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(13, 17),
		"spin": Vector2i(3, 5), "rules": {"cw": 1.0}, "switches": Vector2i(1, 2), "flips": Vector2i(2, 3),
		"gates": Vector2i(1, 2), "links": Vector2i(2, 3), "needs": ["switch", "gate"],
		"goal": {"max_calm": 0.6, "min_dec": 5, "len": Vector2i(12, 22)}},
	"G2_rotation": {"group": "G2", "count": 5, "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(13, 16),
		"spin": Vector2i(7, 9), "rules": {"cw": 0.3, "ccw": 0.25, "alt": 0.25, "pattern": 0.2}, "locks": Vector2i(0, 2),
		"needs": ["spinner", "rules"], "goal": {"max_calm": 0.45, "min_one_safe": 3, "min_dec": 6, "len": Vector2i(12, 20)}},
	"G3_topology": {"group": "G3", "count": 5, "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(11, 15),
		"spin": Vector2i(4, 6), "rules": {"cw": 1.0}, "portals": Vector2i(1, 2), "seq": Vector2i(2, 3),
		"needs": ["portal", "sequence"], "goal": {"max_calm": 0.65, "min_dec": 4, "len": Vector2i(12, 22)}},
	"G4_crate": {"group": "G4", "count": 2, "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 12),
		"spin": Vector2i(1, 2), "rules": {"cw": 1.0}, "crates": Vector2i(1, 2), "needs": ["crate"],
		"goal": {"max_calm": 0.7, "min_dec": 3, "len": Vector2i(10, 20), "min_push_traps": 2, "max_pushes": 6}},
	"G4_crate_armor": {"group": "G4", "count": 2, "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(10, 13),
		"spin": Vector2i(2, 3), "rules": {"cw": 1.0}, "crates": Vector2i(1, 1), "armor": Vector2i(1, 2),
		"needs": ["crate", "armor"], "goal": {"max_calm": 0.65, "min_dec": 3, "len": Vector2i(10, 22), "min_push_traps": 1, "max_pushes": 6}},
	"G4_crate_spin": {"group": "G4", "count": 1, "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(10, 13),
		"spin": Vector2i(3, 5), "rules": {"cw": 1.0}, "crates": Vector2i(1, 2), "needs": ["crate", "spinner"],
		"goal": {"max_calm": 0.6, "min_dec": 4, "len": Vector2i(10, 22), "min_push_traps": 1, "max_pushes": 6}},
}
## Baseline controls from earlier tests: the boards people found hardest.
const CONTROL_IDS := ["P13", "P09"]
const LIVE_SEEDS := [240011, 240157, 240293, 240439, 240577, 240719]
## Cosmetic recolouring for the controls (arrows + clockwise only: colour
## changes nothing there).
const RECOLOUR := {"R": "B", "B": "G", "G": "Y", "Y": "P", "P": "R"}

var rng := RandomNumberGenerator.new()
var known_keys := {}  # canonical key -> where it came from
var _token_re: RegEx


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	rng.seed = int(args.get("seed", "1"))
	Solver.default_limit = WORK_LIMIT
	_load_known()
	if args.has("merge"):
		# --want=RECIPE:N,... changes how many boards a recipe gives (e.g. when
		# a recipe can't fill its slots within the acceptance rules).
		var want := {}
		for w in str(args.get("want", "")).split(",", false):
			want[w.get_slice(":", 0)] = int(w.get_slice(":", 1))
		_merge(str(args["merge"]).split(","), args.has("write"), want)
	elif args.has("baseline"):
		_save_part(str(args.get("part", "")), _baseline())
	elif args.has("recipe"):
		var name := str(args["recipe"])
		_save_part(str(args.get("part", "")), _build_recipe(name, int(args.get("tries", "24")), int(args.get("climb", "220"))))
	else:
		print("nothing to do: --recipe=NAME | --baseline | --merge=a,b,...")
	quit()


func _save_part(path: String, boards: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"boards": boards}, "  "))
	f.close()
	print("wrote %d boards to %s" % [boards.size(), path])


# --- Baseline --------------------------------------------------------------------------------

func _baseline() -> Array:
	var out := []
	Solver.default_limit = RECIPIENT_LIMIT
	var made := 0
	for s in LIVE_SEEDS:
		if made >= 2:
			break
		var g := FriendGenerator.new(FriendGenerator.VERY_HARD, s, [], -1)
		var def := g.run()
		if def == null:
			continue
		var map := Array(def.map)
		if known_keys.has(canonical(map)):
			continue
		var rec := _report("G0", "G0_live", "live VERY HARD (FriendGenerator seed %d)" % s, map, [])
		if rec.get("ok", false):
			out.append(rec)
			made += 1
	var t2 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/vh_human_test2.json"))
	for b in t2["boards"]:
		if b["id"] in CONTROL_IDS:
			var map := _recolour(_rotate180(Array(b["puzzle"]["map"])))
			var rec := _report("G0", "G0_control", "test 2 %s (%s), rotated 180 + recoloured" % [b["id"], b["source"]], map, [])
			rec["control_of"] = b["id"]
			out.append(rec)
	Solver.default_limit = WORK_LIMIT
	return out


func _rotate180(map: Array) -> Array:
	var rows := []
	var flip := {"^": "v", "v": "^", "<": ">", ">": "<"}
	for r in range(map.size() - 1, -1, -1):
		var cells := String(map[r]).split(" ", false)
		var out := []
		for c in range(cells.size() - 1, -1, -1):
			var t := cells[c]
			if t != "." and flip.has(t.substr(1, 1)):
				t = t.substr(0, 1) + flip[t.substr(1, 1)] + t.substr(2)
			out.append(t)
		rows.append(" ".join(out))
	return rows


func _recolour(map: Array) -> Array:
	var rows := []
	for row in map:
		var out := []
		for t in String(row).split(" ", false):
			out.append(RECOLOUR[t.substr(0, 1)] + t.substr(1) if RECOLOUR.has(t.substr(0, 1)) else t)
		rows.append(" ".join(out))
	return rows


# --- Recipe search ---------------------------------------------------------------------------

func _build_recipe(name: String, tries: int, climb: int) -> Array:
	var spec: Dictionary = RECIPES[name]
	var found := []  # accepted records
	var seen := {}
	var t0 := Time.get_ticks_msec()
	for t in tries:
		var cur := _random_valid(spec)
		if cur.is_empty():
			continue
		var cur_e := _evaluate(cur, spec)
		var stale := 0
		for step in climb:
			var cand := _mutate(cur, spec)
			var e := _evaluate(cand, spec)
			if e["score"] >= cur_e["score"]:
				stale = 0 if e["score"] > cur_e["score"] else stale + 1
				cur = cand
				cur_e = e
			else:
				stale += 1
			if stale > 70:
				break
		if cur_e["score"] < 0.0 or not cur_e.get("goal_ok", false):
			print("%s try %d: rejected in climb (%s) score %.1f" % [name, t, cur_e.get("why", "?"), cur_e["score"]])
			continue
		var key := canonical(cur)
		if seen.has(key) or known_keys.has(key):
			print("%s try %d: duplicate" % [name, t])
			continue
		var rec := _report(spec["group"], name, "generated (%s, seed %d, try %d)" % [name, rng.seed, t], cur, spec["needs"])
		if not rec["ok"]:
			print("%s try %d: rejected at acceptance: %s" % [name, t, rec["why"]])
			continue
		seen[key] = true
		rec["score"] = snappedf(cur_e["score"], 0.1)
		found.append(rec)
		print("%s try %d: ACCEPTED score %.1f (%d found, %ds)" % [name, t, cur_e["score"], found.size(), (Time.get_ticks_msec() - t0) / 1000])
	found.sort_custom(func(a, b): return a["score"] > b["score"])
	return found


## A random board for the spec that parses and is solvable (or {}).
func _random_valid(spec: Dictionary) -> Array:
	for i in 300:
		var map := _random_board(spec)
		var e := _evaluate(map, spec)
		if e["solvable"]:
			return map
	return []


func _random_board(spec: Dictionary) -> Array:
	var size: Vector2i = spec["sizes"][rng.randi_range(0, spec["sizes"].size() - 1)]
	var grid := []
	for r in size.y:
		var row := []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	var n_blocks := _pick(spec["blocks"])
	var n_spin := mini(_pick(spec["spin"]), n_blocks)
	var n_seq := _pick(spec.get("seq", Vector2i.ZERO))
	var n_armor := _pick(spec.get("armor", Vector2i.ZERO))
	var n_switch := _pick(spec.get("switches", Vector2i.ZERO))
	var n_gate := _pick(spec.get("gates", Vector2i.ZERO))
	var n_lock := _pick(spec.get("locks", Vector2i.ZERO))
	# Portals first (cells without blocks), then crates and gates.
	for p in _pick(spec.get("portals", Vector2i.ZERO)):
		for k in 2:
			var c := _free(grid, size)
			grid[c.y][c.x] = "O" + "ABCD"[p]
	for k in _pick(spec.get("crates", Vector2i.ZERO)):
		var c := _free(grid, size)
		grid[c.y][c.x] = "M"
	var colors := []
	for i in n_blocks:
		colors.append(COLORS[rng.randi_range(0, COLORS.size() - 1)])
	var roles := []  # per block: "spin", "seq", "armor", "switch", "flip", "plain"
	for i in n_blocks:
		roles.append("plain")
	var idx := range(n_blocks)
	idx.shuffle()
	var k := 0
	for i in n_spin:
		roles[idx[k]] = "spin"; k += 1
	for i in mini(n_seq, n_blocks - k):
		roles[idx[k]] = "seq"; k += 1
	for i in mini(n_armor, n_blocks - k):
		roles[idx[k]] = "armor"; k += 1
	var switch_of := {}
	var flip_of := {}
	for s in n_switch:
		if k >= n_blocks:
			break
		roles[idx[k]] = "switch"; switch_of[idx[k]] = "AB"[s]; k += 1
		for f in _pick(spec["flips"]):
			if k >= n_blocks:
				break
			roles[idx[k]] = "flip"; flip_of[idx[k]] = "AB"[s]; k += 1
	var link_of := {}
	for g in n_gate:
		var linkable := range(n_blocks).filter(func(b): return roles[b] in ["plain", "spin", "flip"] and not link_of.has(b))
		linkable.shuffle()
		for l in mini(_pick(spec["links"]), linkable.size()):
			link_of[linkable[l]] = "CD"[g]
		var c := _free(grid, size)
		grid[c.y][c.x] = "X" + "CD"[g]
	var lock_of := {}
	var lockable := range(n_blocks).filter(func(b): return roles[b] in ["plain", "spin"])
	lockable.shuffle()
	for l in mini(n_lock, lockable.size()):
		var b: int = lockable[l]
		var others := range(n_blocks).filter(func(o): return o != b).map(func(o): return colors[o])
		lock_of[b] = others[rng.randi_range(0, others.size() - 1)]
	var rules: Dictionary = spec.get("rules", {"cw": 1.0})
	for b in n_blocks:
		var d: String = DIRS[rng.randi_range(0, 3)]
		var t: String = colors[b] + d
		match roles[b]:
			"spin":
				t += RULE_SUFFIX[_weighted(rules)]
			"seq":
				var nd := d
				while nd == d:
					nd = DIRS[rng.randi_range(0, 3)]
				t += ":" + nd
			"armor":
				t += "="
			"switch":
				t += "%" + switch_of[b]
			"flip":
				t += "&" + flip_of[b]
		if lock_of.has(b):
			t = _insert_lock(t, lock_of[b])
		if link_of.has(b):
			t += "+" + link_of[b]
		var c := _free(grid, size)
		grid[c.y][c.x] = t
	return _rows(grid)


## Lock "#K" goes right after the spinner suffix (parser order @ ? #K ...).
func _insert_lock(t: String, key: String) -> String:
	var at := 2
	if t.length() > 2 and t[2] == "@":
		at = 3 if t.length() == 3 or not (t[3] in ["-", "~", "*"]) else 4
	return t.substr(0, at) + "#" + key + t.substr(at)


func _pick(v: Vector2i) -> int:
	return rng.randi_range(v.x, v.y)


func _weighted(w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += w[k]
	var x := rng.randf() * total
	for k in w:
		x -= w[k]
		if x <= 0.0:
			return k
	return w.keys()[0]


func _free(grid: Array, size: Vector2i) -> Vector2i:
	while true:
		var c := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		if grid[c.y][c.x] == ".":
			return c
	return Vector2i.ZERO


func _rows(grid: Array) -> Array:
	var out := []
	for row in grid:
		out.append(" ".join(row))
	return out


func _grid(map: Array) -> Array:
	var g := []
	for row in map:
		g.append(Array(String(row).split(" ", false)))
	return g


## One random change: move / swap a piece, turn an arrow, re-roll a spinner
## rule, a Sequence block's next arrow or a lock key.
func _mutate(map: Array, spec: Dictionary) -> Array:
	var g := _grid(map)
	var rows := g.size()
	var cols: int = g[0].size()
	var cells := []
	var blocks := []
	for r in rows:
		for c in cols:
			if g[r][c] != ".":
				cells.append(Vector2i(c, r))
				if g[r][c].length() >= 2 and g[r][c][0] in COLORS:
					blocks.append(Vector2i(c, r))
	var op := rng.randi_range(0, 9)
	if op <= 3:  # move any piece to an empty cell
		var from: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var to := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if g[to.y][to.x] == ".":
			g[to.y][to.x] = g[from.y][from.x]
			g[from.y][from.x] = "."
	elif op <= 6 and not blocks.is_empty():  # turn an arrow
		var at: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
		var t: String = g[at.y][at.x]
		var nd: String = DIRS[rng.randi_range(0, 3)]
		var seq := t.find(":")
		if seq >= 0 and t.substr(seq + 1, 1) == nd:
			nd = DIRS[(DIRS.find(nd) + 1) % 4]
		g[at.y][at.x] = t.substr(0, 1) + nd + t.substr(2)
	elif op == 7 and cells.size() >= 2:  # swap two pieces
		var a: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var b: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
		var tmp: String = g[a.y][a.x]
		g[a.y][a.x] = g[b.y][b.x]
		g[b.y][b.x] = tmp
	elif not blocks.is_empty():  # re-roll a spinner rule / next arrow / lock key
		var at: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
		var t: String = g[at.y][at.x]
		var rules: Dictionary = spec.get("rules", {"cw": 1.0})
		if t.length() > 2 and t[2] == "@" and rules.size() > 1:
			var suffix_len := 2 if t.length() > 3 and t[3] in ["-", "~", "*"] else 1
			g[at.y][at.x] = t.substr(0, 2) + RULE_SUFFIX[_weighted(rules)] + t.substr(2 + suffix_len)
		elif t.find(":") >= 0:
			var nd := t.substr(1, 1)
			while nd == t.substr(1, 1):
				nd = DIRS[rng.randi_range(0, 3)]
			g[at.y][at.x] = t.substr(0, t.find(":") + 1) + nd
		elif t.find("#") >= 0:
			var p := t.find("#")
			g[at.y][at.x] = t.substr(0, p + 1) + COLORS[rng.randi_range(0, 4)] + t.substr(p + 2)
		else:
			g[at.y][at.x] = COLORS[rng.randi_range(0, 4)] + t.substr(1)
	return _rows(g)


# --- Evaluation ------------------------------------------------------------------------------

func parse(map: Array) -> LevelData:
	return LevelManager.parse_level({"name": "pilot", "map": map}, 0, true)


func model_of(level: LevelData) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals(level.portals)
	return m


## Expected pieces survived parsing (portal / link validation drops broken
## ones silently, which would make the board something else).
func _intact(map: Array, level: LevelData) -> bool:
	var tokens := 0
	var portals := 0
	for row in map:
		for t in String(row).split(" ", false):
			if t == ".":
				continue
			if t.length() == 2 and t[0] == "O":
				portals += 1
			else:
				tokens += 1
	if tokens != level.blocks.size() or portals != level.portals.size():
		return false
	# Every switch / flip / gate link written survived link validation.
	var sw := 0
	var fl := 0
	var ln := 0
	for row in map:
		for t in String(row).split(" ", false):
			sw += 1 if t.contains("%") else 0
			fl += 1 if t.contains("&") else 0
			ln += 1 if t.contains("+") else 0
	return sw == level.blocks.filter(func(b): return b.switch_group != "").size() \
		and fl == level.blocks.filter(func(b): return b.flip_link != "").size() \
		and ln == level.blocks.filter(func(b): return b.gate_link != "").size()


func _has(map: Array, ch: String) -> bool:
	for row in map:
		if String(row).contains(ch):
			return true
	return false


## Cheap climbing evaluation: solvability, the solver's analysis, the
## calm share and the recipe's usage / goal checks.
func _evaluate(map: Array, spec: Dictionary) -> Dictionary:
	var e := {"solvable": false, "score": -1000.0, "goal_ok": false, "why": ""}
	var level := parse(map)
	if level == null or level.blocks.is_empty() or not _intact(map, level):
		e["why"] = "parse"
		return e
	var m := LevelAnalysis.analyze(level, false)
	if m.get("aborted", false) or not m["solvable"]:
		e["why"] = "unsolvable/aborted"
		return e
	e["solvable"] = true
	var c := calm_stats(level)
	var goal: Dictionary = spec["goal"]
	var sol_len: int = m["solution_length"]
	var s := 0.0
	s += m["decision_points"] * 2.0 + m["one_safe_steps"] * 2.0 + minf(m["trap_moves"], 30) * 0.3 + m["depth"] * 0.8
	# Calm MOVES: solution moves that turn no spinner and fire no switch
	# (a player who knows the rules plays them without thinking).
	var calm_moves := float(c["calm_moves"]) / maxf(sol_len, 1)
	e["calm_moves_share"] = calm_moves
	s -= calm_moves * 25.0 + m["start_calm"] * 2.0 + maxf(0.0, m["start_moves"] - 3) * 2.0
	var why := []
	if sol_len < goal["len"].x or sol_len > goal["len"].y:
		s -= 6.0 * (maxi(goal["len"].x - sol_len, 0) + maxi(sol_len - goal["len"].y, 0))
		why.append("len %d" % sol_len)
	if calm_moves > goal["max_calm"]:
		s -= 60.0 * (calm_moves - goal["max_calm"])
		why.append("calm moves %.2f" % calm_moves)
	if m["decision_points"] < goal.get("min_dec", 0):
		why.append("dec %d" % m["decision_points"])
	if m["one_safe_steps"] < goal.get("min_one_safe", 0):
		why.append("one_safe %d" % m["one_safe_steps"])
	# Usage of the recipe's mechanics in the solver's solution.
	var needs: Array = spec["needs"]
	if "portal" in needs:
		s += minf(m["portal_moves"], 4) * 2.0
		if m["portal_moves"] < 2:
			why.append("portal_moves %d" % m["portal_moves"])
	if "sequence" in needs:
		s += minf(m["advances"], 3) * 2.0
		if m["advances"] < 1:
			why.append("advances %d" % m["advances"])
	if "switch" in needs:
		s += minf(m["switch_decisions"], 4) * 2.0
	if "crate" in needs:
		var pt := push_traps(level)
		e["push_traps"] = pt
		s += minf(pt, 5) * 2.5
		s += 8.0 if m["pushes"] >= 1 else -8.0
		if m["pushes"] < 1:
			why.append("no push")
		if m["pushes"] > goal.get("max_pushes", 99):
			s -= (m["pushes"] - goal["max_pushes"]) * 4.0
			why.append("pushes %d" % m["pushes"])
		if pt < goal.get("min_push_traps", 0):
			why.append("push_traps %d" % pt)
	if "armor" in needs and m["rams"] < 1:
		why.append("no ram")
	if goal.has("min_trap_delay") and why.is_empty():
		var td := trap_delay(level, 6)
		e["trap_delay"] = td["avg"]
		s += minf(td["avg"], 8.0) * 3.0
		if td["avg"] < goal["min_trap_delay"]:
			why.append("trap_delay %.1f" % td["avg"])
	e["score"] = s
	e["goal_ok"] = why.is_empty()
	e["why"] = ", ".join(why)
	return e


## Steps of the solver's solution at which a risk-free ("calm") move is
## available, and how many solution moves are calm themselves. A calm move
## turns no spinner and fires no switch (Solver._is_risky): a player who
## knows the rules can play it without thinking.
func calm_stats(level: LevelData) -> Dictionary:
	var s := Solver.from_model(model_of(level))
	var sol := s.solve_moves()
	var steps := 0
	var moves := 0
	var applied := []
	for mv in sol:
		var legal := s._distinct_legal()
		if legal.any(func(x): return not s._is_risky(x)):
			steps += 1
		if not s._is_risky(mv):
			moves += 1
		s._do(mv)
		applied.append(mv)
	for i in range(applied.size() - 1, -1, -1):
		s._undo_move(applied[i])
	var n := maxi(sol.size(), 1)
	return {"calm_steps": steps, "calm_share": snappedf(float(steps) / n, 0.01), "calm_moves": moves}


## Losing pushes along the solution: a legal push after which the board
## can no longer be cleared ("where will the crate be later?").
func push_traps(level: LevelData) -> int:
	var s := Solver.from_model(model_of(level))
	var sol := s.solve_moves()
	var n := 0
	var applied := []
	for mv in sol:
		for x in s._distinct_legal():
			if x & Solver.PUSH:
				s._do(x)
				var ok := s._alive_count == s._crate_n or not s._solve_keep_state().is_empty()
				s._undo_move(x)
				if not ok:
					n += 1
		s._do(mv)
		applied.append(mv)
	for i in range(applied.size() - 1, -1, -1):
		s._undo_move(applied[i])
	return n


## After each losing move along the solution: how many more moves random
## play can still make before no move is left (how LATE a mistake shows).
func trap_delay(level: LevelData, games: int) -> Dictionary:
	var s := Solver.from_model(model_of(level))
	var sol := s.solve_moves()
	var delays := []
	var applied := []
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for mv in sol:
		for x in s._distinct_legal():
			if not s._is_risky(x):
				continue
			s._do(x)
			var ok := s._alive_count == s._crate_n or not s._solve_keep_state().is_empty()
			if not ok:
				var total := 0
				for g in games:
					var played := []
					while played.size() < 60:
						var legal := s._distinct_legal()
						if legal.is_empty():
							break
						var y: int = legal[r.randi_range(0, legal.size() - 1)]
						s._do(y)
						played.append(y)
					total += played.size()
					for i in range(played.size() - 1, -1, -1):
						s._undo_move(played[i])
				delays.append(float(total) / games)
			s._undo_move(x)
		s._do(mv)
		applied.append(mv)
	for i in range(applied.size() - 1, -1, -1):
		s._undo_move(applied[i])
	if delays.is_empty():
		return {"avg": 0.0, "max": 0.0, "traps": 0}
	return {"avg": snappedf(delays.reduce(func(a, b): return a + b, 0.0) / delays.size(), 0.1), "max": snappedf(delays.max(), 0.1), "traps": delays.size()}


# --- Acceptance report ----------------------------------------------------------------------

## The full technical record of a board (and whether it is accepted).
func _report(group: String, recipe: String, source: String, map: Array, needs: Array) -> Dictionary:
	var rec := {"group": group, "recipe": recipe, "source": source, "map": map, "ok": false, "why": ""}
	var level := parse(map)
	if level == null or not _intact(map, level):
		rec["why"] = "does not parse intact"
		return rec
	var mech := mechanics(map)
	rec["mechanics"] = mech
	# Recipient-equivalent check (PuzzleDefinition.verify: a fresh Solver,
	# the full 60000-node limit) - nodes and native desktop time.
	var v := _verify_cost(level)
	rec["verify"] = v
	if not v["solved"]:
		rec["why"] = "not solvable within %d nodes" % RECIPIENT_LIMIT
		return rec
	Solver.default_limit = RECIPIENT_LIMIT
	var m := LevelAnalysis.analyze(level, true)
	Solver.default_limit = WORK_LIMIT
	var c := calm_stats(level)
	var td := trap_delay(level, 10)
	var model := model_of(level)
	var rand := Solver.from_model(model).random_win_rate(80, 4242)
	var heur := Solver.from_model(model).heuristic_win_rate(30, 2, 4343)
	var hint := _hint_cost(level)
	var met := {
		"size": "%dx%d" % [level.columns, level.rows], "blocks": m["blocks"], "crates": m["crates"],
		"solution_length": m["solution_length"], "start_moves": m["start_moves"], "start_calm": m["start_calm"],
		"start_safe": m["start_safe"], "decision_points": m["decision_points"], "one_safe_steps": m["one_safe_steps"],
		"safe_choices": m["safe_choices"], "branching": m["branching"], "trap_moves": m["trap_moves"], "depth": m["depth"],
		"calm_steps": c["calm_steps"], "calm_share": c["calm_share"], "calm_moves": c["calm_moves"],
		"calm_moves_share": snappedf(float(c["calm_moves"]) / maxf(m["solution_length"], 1), 0.01),
		"trap_delay_avg": td["avg"], "trap_delay_max": td["max"], "random_win": rand, "heuristic_win": heur,
		"difficulty": snappedf(m["difficulty"], 0.1),
		"spinners": m["spinners"], "rules": {"cw": m["rule_cw"], "ccw": m["rule_ccw"], "alt": m["rule_alt"], "pattern": m["rule_pattern"]},
		"locks": m["locks"], "switches": m["switches"], "flip_targets": m["flip_targets"], "gates": m["gates"], "gate_links": m["gate_links"],
		"armored": m["armored"], "rams": m["rams"], "portal_pairs": m["portal_pairs"], "portal_moves": m["portal_moves"],
		"sequence_blocks": m["sequence_blocks"], "advances": m["advances"], "pushes": m["pushes"], "switch_decisions": m["switch_decisions"],
		"push_traps": push_traps(level) if m["crates"] > 0 else 0, "push_essential": m["push_essential"],
		"impact": {"spinner": m["spinner_impact"], "lock": m["lock_impact"], "switch": m["switch_impact"], "gate": m["gate_impact"],
			"armor": m["armor_impact"], "portal": m["portal_impact"], "sequence": m["sequence_impact"], "crate": m["movable_impact"],
			"rules": rules_impact(level, m)},
		"hint": hint,
	}
	rec["metrics"] = met
	rec["fingerprint"] = JSON.stringify(map).sha256_text()
	rec["canonical"] = canonical(map)
	# Acceptance.
	var why := []
	if level.rows > 7 or level.columns > 7:
		why.append("bigger than 7x7")
	if v["nodes"] > WORK_LIMIT:
		why.append("verify needs %d nodes (> %d working budget)" % [v["nodes"], WORK_LIMIT])
	if hint["max_nodes"] > RECIPIENT_LIMIT or hint["aborted"]:
		why.append("SHOW A MOVE over budget (%d nodes)" % hint["max_nodes"])
	var slowest := maxf(v["ms_desktop"], maxf(hint["max_ms_desktop"], hint["dead_max_ms_desktop"]))
	if slowest > MOBILE_MS_DESKTOP:
		why.append("over the mobile time budget (%.0f ms desktop > %.0f)" % [slowest, MOBILE_MS_DESKTOP])
	for n in needs:
		var imp: float = met["impact"].get(n, 0.0)
		if imp < MIN_IMPACT:
			why.append("%s does not matter (impact %.1f)" % [n, imp])
	# Every advanced family on the board must matter, not only the needed ones.
	for fam in ["lock", "switch", "gate", "armor", "portal", "sequence", "crate"]:
		if _family_present(fam, met) and float(met["impact"][fam]) < MIN_IMPACT:
			why.append("%s is decoration (impact %.1f)" % [fam, met["impact"][fam]])
	if rand > 0.08:
		why.append("random tapper wins %.0f%%" % (rand * 100))
	if recipe.begins_with("G0_live") or recipe.begins_with("G0_control"):
		why = why.filter(func(w): return not w.begins_with("random"))  # baselines are kept as they are
	rec["ok"] = why.is_empty()
	rec["why"] = "; ".join(why)
	return rec


func _family_present(fam: String, met: Dictionary) -> bool:
	match fam:
		"lock": return met["locks"] > 0
		"switch": return met["switches"] > 0
		"gate": return met["gates"] > 0
		"armor": return met["armored"] > 0
		"portal": return met["portal_pairs"] > 0
		"sequence": return met["sequence_blocks"] > 0
		"crate": return met["crates"] > 0
	return false


## Counter-clockwise / alternating / pattern spinners: the same board with
## every spinner clockwise (ESSENTIAL if that board can't be cleared;
## otherwise the difficulty they add). 0 when every spinner is clockwise.
func rules_impact(level: LevelData, m: Dictionary) -> float:
	if m["rule_ccw"] + m["rule_alt"] + m["rule_pattern"] == 0:
		return 0.0
	var blocks := []
	for b in level.blocks:
		var d: BlockData = b.duplicate_data()
		d.spin_rule = 0
		blocks.append(d)
	var mm := BoardModel.new()
	mm.setup(level.rows, level.columns, blocks)
	mm.set_portals(level.portals)
	var s := Solver.from_model(mm)
	var a := s.analyze()
	if not a["solvable"]:
		return LevelAnalysis.ESSENTIAL
	return snappedf(m["difficulty"] - LevelGenerator.difficulty(a), 0.1)


## PuzzleDefinition.verify's search: a fresh Solver with the recipient's
## 60000-node limit. Native desktop time (median of 5).
func _verify_cost(level: LevelData) -> Dictionary:
	var times := []
	var nodes := 0
	var solved := false
	var aborted := false
	for i in 5:
		var s := Solver.from_model(model_of(level))
		s.node_limit = RECIPIENT_LIMIT
		var t0 := Time.get_ticks_usec()
		var moves := s.solve_moves()
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
		nodes = s.nodes
		aborted = s.aborted
		solved = not s.aborted and (not moves.is_empty() or s._alive_count == s._crate_n)
	times.sort()
	return {"nodes": nodes, "ms_desktop": snappedf(times[2], 0.01), "solved": solved, "aborted": aborted}


## SHOW A MOVE (Solver.recommend_move on a fresh Solver, as SocialPlay
## does): on every state of the solution, and right after every losing move
## along it (the player has just made a mistake). Max nodes / native ms.
func _hint_cost(level: LevelData) -> Dictionary:
	var base := Solver.from_model(model_of(level))
	base.node_limit = RECIPIENT_LIMIT
	var sol := base.solve_moves()
	var out := {"max_nodes": 0, "max_ms_desktop": 0.0, "dead_max_nodes": 0, "dead_max_ms_desktop": 0.0, "states": 0, "dead_states": 0, "aborted": false, "consistent": true}
	for step in sol.size() + 1:
		# Fresh solver at this state (no memo carried over).
		var s := Solver.from_model(model_of(level))
		s.node_limit = RECIPIENT_LIMIT
		for i in step:
			s._do(sol[i])
		if s._alive_count == s._crate_n:
			break
		s.nodes = 0
		var t0 := Time.get_ticks_usec()
		var mv := s.recommend_move()
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		out["states"] += 1
		if s.nodes >= out["max_nodes"]:
			out["worst_path"] = sol.slice(0, step)
		out["max_nodes"] = maxi(out["max_nodes"], s.nodes)
		out["max_ms_desktop"] = maxf(out["max_ms_desktop"], snappedf(ms, 0.01))
		if s.aborted:
			out["aborted"] = true
		if mv == -1:
			out["consistent"] = false
		# After each losing move from this state.
		for x in s._distinct_legal():
			if not s._is_risky(x):
				continue
			s._do(x)
			s.nodes = 0
			s.aborted = false
			var dead := s._solve_keep_state().is_empty()
			if dead:
				var d := Solver.from_model(model_of(level))
				d.node_limit = RECIPIENT_LIMIT
				for i in step:
					d._do(sol[i])
				d._do(x)
				d.nodes = 0
				var t1 := Time.get_ticks_usec()
				d.recommend_move()
				var dms := (Time.get_ticks_usec() - t1) / 1000.0
				out["dead_states"] += 1
				if d.nodes >= out["dead_max_nodes"]:
					out["dead_worst_path"] = sol.slice(0, step) + [x]
				out["dead_max_nodes"] = maxi(out["dead_max_nodes"], d.nodes)
				out["dead_max_ms_desktop"] = maxf(out["dead_max_ms_desktop"], snappedf(dms, 0.01))
			s._undo_move(x)
	return out


## Mechanics on a board, and its canonical key (rotation / reflection /
## recolouring / relabelling): tools/vh_pilot4_canon.gd.
func mechanics(map: Array) -> Array:
	return CANON.mechanics(map)


func canonical(map: Array) -> String:
	return CANON.canonical(map)


## Keys of every board a tester may have seen: the 300 campaign levels and
## every board file under data/dev (earlier tests, labs).
func _load_known() -> void:
	for n in range(1, 301):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%02d.json" % n))
		known_keys[canonical(Array(d["map"]))] = "campaign L%d" % n
	var stack := ["res://data/dev"]
	var files := 0
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json") and not f.begins_with("vh_pilot4"):
				var data = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f)))
				files += 1
				_collect_maps(data, dir.path_join(f))
	print("known boards: %d (campaign 300 + %d dev files)" % [known_keys.size(), files])


func _collect_maps(v, where: String) -> void:
	if typeof(v) == TYPE_DICTIONARY:
		if v.has("original"):
			return  # a declared copy of a board kept elsewhere (vh_validation3.json), not a new board
		if v.has("map") and typeof(v["map"]) == TYPE_ARRAY and not v["map"].is_empty() and typeof(v["map"][0]) == TYPE_STRING:
			var k := canonical(Array(v["map"]))
			if not known_keys.has(k):
				known_keys[k] = where
		for key in v:
			_collect_maps(v[key], where)
	elif typeof(v) == TYPE_ARRAY:
		for x in v:
			_collect_maps(x, where)


# --- Merge -----------------------------------------------------------------------------------

func _merge(paths: Array, write: bool, want: Dictionary = {}) -> void:
	var picked := []
	var keys := {}
	var wanted := {"G0_live": 2, "G0_control": 2}
	for r in RECIPES:
		wanted[r] = RECIPES[r]["count"]
	wanted.merge(want, true)
	var have := {}
	for p in paths:
		var data = JSON.parse_string(FileAccess.get_file_as_string(p))
		for rec in data["boards"]:
			var r: String = rec["recipe"]
			if have.get(r, 0) >= wanted.get(r, 0) or keys.has(rec["canonical"]):
				continue
			# Re-validated with this (final) code, whatever version found it.
			var needs: Array = RECIPES[r]["needs"] if RECIPES.has(r) else []
			var fresh := _report(rec["group"], r, rec["source"], rec["map"], needs)
			fresh["score"] = rec.get("score", 0.0)
			fresh["control_of"] = rec.get("control_of", "")
			rec = fresh
			if not rec["ok"] and not r.begins_with("G0_control"):
				print("  not kept: %s %s - %s" % [r, rec["source"], rec["why"]])
				continue
			if known_keys.has(rec["canonical"]) and not r.begins_with("G0_control"):
				continue
			keys[rec["canonical"]] = true
			have[r] = have.get(r, 0) + 1
			picked.append(rec)
	for r in wanted:
		print("%-16s %d / %d" % [r, have.get(r, 0), wanted[r]])
	# Neutral ids in a seeded shuffle (an id never hints at its group).
	var order := range(picked.size())
	var srng := RandomNumberGenerator.new()
	srng.seed = 2026
	for i in range(order.size() - 1, 0, -1):
		var j := srng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var boards := []
	for n in order.size():
		var rec: Dictionary = picked[order[n]]
		var map: Array = rec["map"]
		boards.append({"id": "V%02d" % (n + 1), "variant": rec["group"], "recipe": rec["recipe"], "source": rec["source"],
			"puzzle": {"format": PuzzleDefinition.FORMAT, "v": PuzzleDefinition.VERSION, "rules": PuzzleDefinition.RULES,
				"rows": map.size(), "cols": String(map[0]).split(" ", false).size(), "map": map},
			"mechanics": rec["mechanics"], "first_level": rec["mechanics"].map(func(k): return FIRST_LEVEL.get(k, 1)).max() if not rec["mechanics"].is_empty() else 1,
			"fingerprint": rec["fingerprint"], "canonical": rec["canonical"], "accepted": rec["ok"], "note": rec["why"],
			"verify": rec["verify"], "metrics": rec["metrics"]})
	boards.sort_custom(func(a, b): return a["id"] < b["id"])
	var out := {"format": "ce-vh-pilot", "v": 1, "test": "vhtest4", "assist": ASSIST, "boards": boards}
	print("boards: %d" % boards.size())
	if write:
		var f := FileAccess.open(OUT, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("wrote " + OUT)
