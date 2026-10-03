extends SceneTree
## PORTAL MECHANIC PROTOTYPE (development only): builds the mechanic lab's
## board file, data/dev/mechlab_portal.json (?mechlab=1).
##
##   godot --headless --path . --script res://tools/mechlab_portal_build.gd            # check + write
##   godot --headless --path . --script res://tools/mechlab_portal_build.gd -- --dry   # check + print only
##   godot --headless --path . --script res://tools/mechlab_portal_build.gd -- --search=plan --seed=1 --count=4000
##
## Boards are hand-picked (some found with --search, then fixed here so the
## file is reproducible). Stages: A basic understanding, B planning, C one
## existing mechanic + portal, D depth. A board with "control": true also
## gets a matched CONTROL board: the same blocks with the portal cells
## turned into plain empty cells, rotated 180 degrees (rules unchanged,
## clockwise stays clockwise) so it does not look like a replay.
##
## Every board must parse with a valid portal layout (Portals.layout_errors
## empty: pairs complete, no lane can ever loop), be solvable, and every
## portal board must actually use a portal in its solution. The metrics
## printed here are solver proxies only - the human test decides.

const OUT_PATH := "res://data/dev/mechlab_portal.json"
const ARROW_FLIP := {"^": "v", "v": "^", "<": ">", ">": "<"}

## stage, id, map, control (= also build the matched control board).
const BOARDS := [
	# --- A: basic understanding --------------------------------------------
	# One portal pair, every path clear: the red block goes in at A and
	# comes out of the other A, still moving right.
	{"id": "A1", "stage": "A", "control": false, "map": [
		".  .  .  .  .",
		"R> .  OA .  Y^",
		".  B^ .  .  .",
		".  .  .  OA .",
		".  G> .  .  ."]},
	# The exit side is blocked: purple must leave before red can use A.
	{"id": "A2", "stage": "A", "control": false, "map": [
		".  .  .  Yv .",
		"R> .  OA .  .",
		".  .  .  .  B<",
		"OA P> .  .  .",
		".  .  G^ .  ."]},
	# Both directions: green goes down through A, yellow goes left through
	# A; each one's exit lane has a block that must leave first.
	{"id": "A3", "stage": "A", "control": false, "map": [
		".  Gv .  .  .",
		"B^ OA .  .  .",
		".  .  .  .  .",
		".  .  .  OA Y<",
		".  .  .  R> ."]},
	# --- B: planning -------------------------------------------------------------
	{"id": "B1", "stage": "B", "control": true, "map": [
		"Pv  .  .  .   P<@ B^@",
		".   .  Rv .   .   .",
		".   .  Gv .   R^  .",
		".   OA Pv Yv@ .   .",
		"Y>@ .  OA .   .   .",
		".   .  .  P>@ .   ."]},
	{"id": "B2", "stage": "B", "control": true, "map": [
		"Y>@ .   .  .   .  OA",
		"P<  .   .  .   .  .",
		"OA  .   .  G<@ .  .",
		"Y^@ B<@ P< Y<  .  B^",
		".   .   .  .   .  .",
		".   .   .  .   G< G<@"]},
	# --- C: one existing mechanic + portal -----------------------------------
	# Lock: the locked red block's lane runs through the portal.
	{"id": "C1", "stage": "C", "control": false, "map": [
		"G>@ OA   .  .  . .",
		"R<  .    .  .  . P>",
		"R^  B<   .  .  . .",
		".   .    .  .  . .",
		"G^@ R>#G OA G^ . .",
		".   .    .  .  . ."]},
	# Switch: the flip target (&A) leaves through the portal.
	{"id": "C2", "stage": "C", "control": true, "map": [
		".  .    Y<  . .  .",
		".  .    .   . .  Yv",
		"B^ G^   Y^@ . OA .",
		".  .    .   . .  .",
		".  Gv%A .   . .  .",
		".  OA   .   . B< G<&A"]},
	# Armor: a ram through the portal cracks the shell.
	{"id": "C3", "stage": "C", "control": true, "map": [
		".   . .  . R<@ B<",
		".   . Y^ . OA  R^",
		"P^  . .  . .   P<",
		"B>= . .  . .   .",
		"OA  . .  . Y<@ B^",
		"P^  . .  . .   ."]},
	# Gate: the exit lane is closed by Chain Gate C; open it first.
	{"id": "C4", "stage": "C", "control": false, "map": [
		".   .  Gv+C .  .  .",
		"R>  .  .    OA .  B^@",
		".   .  .    .  .  .",
		".   .  .    .  .  Y<+C",
		".   OA .    XC .  .",
		"P^@ .  .    .  R< ."]},
	# --- D: depth ----------------------------------------------------------------
	{"id": "D1", "stage": "D", "control": true, "map": [
		".    .  Y>@- G<@ .   .",
		".    .  OA   G<@ .   R<",
		"Y<@  .  P>   B^@ R^  .",
		"G^   Bv .    Yv  .   .",
		"P^@- OA .    .   .   .",
		".    .  .    P<  .   .",
		".    .  .    .   .   ."]},
	{"id": "D2", "stage": "D", "control": true, "map": [
		".  .   .  .   .    Y^",
		".  B>  P> B>  .    .",
		".  .   .  .   .    .",
		"R> P^@ .  Y>@ R>   Y^",
		".  OA  .  .   Y<@- .",
		".  .   Pv R<  .    OA",
		".  .   .  Y>@- .   G^@"]},
]


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var search := ""
	var seed := 1
	var count := 2000
	var dry := false
	for a in args:
		if a.begins_with("--search="):
			search = a.get_slice("=", 1)
		elif a.begins_with("--seed="):
			seed = int(a.get_slice("=", 1))
		elif a.begins_with("--count="):
			count = int(a.get_slice("=", 1))
		elif a == "--dry":
			dry = true
	if search != "":
		_search(search, seed, count)
		quit(0)
		return
	quit(_build(dry))


# --- Build ---------------------------------------------------------------------------

func _build(dry: bool) -> int:
	var out := []
	var failures := 0
	for spec in BOARDS:
		var m := evaluate(spec["map"])
		var line := "%s [%s] %s" % [spec["id"], spec["stage"], describe(m)]
		if not m["errors"].is_empty() or not m["solvable"] or m["portal_moves"] == 0:
			line += "   <-- FAIL %s" % str(m["errors"])
			failures += 1
		print(line)
		out.append(_record(spec["id"], "portal", spec["stage"], spec["map"], m, spec["id"]))
		if spec.get("control", false):
			var cmap := control_map(spec["map"])
			var cm := evaluate(cmap)
			var cid := str(spec["id"]) + "_CTRL"
			var cline := "%s [%s] %s" % [cid, spec["stage"], describe(cm)]
			if not cm["errors"].is_empty() or not cm["solvable"]:
				cline += "   <-- FAIL"
				failures += 1
			print(cline)
			out.append(_record(cid, "control", spec["stage"], cmap, cm, spec["id"]))
	print("%d boards, %d failures" % [out.size(), failures])
	if failures > 0 or dry:
		return 1 if failures > 0 else 0
	var data := {"format": "ce-mechlab", "v": 1, "mechanic": "portal",
		"assist": {"undo": 3, "show_a_move": 1, "hammer": 0}, "boards": out}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()
	print("wrote %s" % OUT_PATH)
	return 0


func _record(id: String, variant: String, stage: String, map: Array, m: Dictionary, pair: String) -> Dictionary:
	var rows := map.size()
	var canon := []
	for row in map:
		canon.append(" ".join(String(row).split(" ", false)))
	var cols: int = String(canon[0]).split(" ", false).size()
	return {"id": id, "variant": variant, "stage": stage, "pair": pair,
		"puzzle": {"format": PuzzleDefinition.FORMAT, "v": PuzzleDefinition.VERSION, "rules": PuzzleDefinition.RULES,
			"rows": rows, "cols": cols, "map": canon},
		"metrics": {"blocks": m["blocks"], "solution": m["sol_len"], "start_moves": m["start"], "portal_moves": m["portal_moves"],
			"remote_blocked_at_start": m["remote_dep"], "random_win": m["random_win"]}}


## The matched control: portal cells become empty cells, then the whole
## board turns 180 degrees.
static func control_map(map: Array) -> Array:
	var rows := []
	for i in range(map.size() - 1, -1, -1):
		var tokens := String(map[i]).split(" ", false)
		var out := PackedStringArray()
		for j in range(tokens.size() - 1, -1, -1):
			var t := tokens[j]
			if t.begins_with(Portals.TOKEN_PREFIX):
				out.append(".")
			elif t != "." and t[0] != "X":
				out.append(t[0] + ARROW_FLIP[t[1]] + t.substr(2))
			else:
				out.append(t)
		rows.append(" ".join(out))
	return rows


# --- Metrics (solver proxies) ---------------------------------------------------------

static func evaluate(map: Array, profile: String = "") -> Dictionary:
	var m := {"errors": [], "solvable": false, "sol_len": 0, "start": 0, "portal_moves": 0, "remote_dep": 0,
		"random_win": 0.0, "blocks": 0, "interaction": profile in ["", "plan", "deep"], "portal_rams": 0}
	var rows := map.size()
	var cols: int = String(map[0]).split(" ", false).size()
	var groups := {}
	for r in rows:
		var tokens := String(map[r]).split(" ", false)
		if tokens.size() != cols:
			m["errors"].append("row %d has %d cells" % [r, tokens.size()])
		for c in tokens.size():
			if tokens[c].begins_with(Portals.TOKEN_PREFIX):
				groups[Vector2i(c, r)] = tokens[c].substr(1)
	m["errors"].append_array(Portals.layout_errors(rows, cols, groups))
	var level := LevelManager.parse_level({"map": map})
	if level.portals.size() != groups.size():
		m["errors"].append("parser dropped portals")
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	model.set_portals(level.portals)
	m["blocks"] = model.block_count()
	for id in model.blocks:
		var ln := model.lane(id)
		if not ln["via"].is_empty() and ln["blocker"] != null and model.move_state(id) != "ram":
			m["remote_dep"] += 1
		if profile == "gate" and not ln["via"].is_empty() and ln["blocker"] != null and ln["blocker"].is_gate():
			m["interaction"] = true
	var solver := Solver.from_model(model)
	m["start"] = solver.legal_moves().size()
	var moves := solver.solve_moves()
	m["solvable"] = not moves.is_empty() and not solver.aborted
	m["sol_len"] = moves.size()
	for mv in moves:
		var id: int = mv & Solver.ID_MASK
		var ln := model.lane(id)
		if not ln["via"].is_empty():
			m["portal_moves"] += 1
			var mover: BlockData = model.blocks[id]
			if mv & Solver.RAM:
				m["portal_rams"] += 1
			if profile == "armor" and mv & Solver.RAM:
				m["interaction"] = true
			elif profile == "gate" and ln["blocker"] != null and ln["blocker"].is_gate():
				m["interaction"] = true
			elif profile == "lock" and mover.lock_color != "":
				m["interaction"] = true
			elif profile == "switch" and mover.flip_link != "":
				m["interaction"] = true
			elif profile == "spinner" and mover.is_spinner():
				m["interaction"] = true
		if mv & Solver.RAM:
			model.ram(id)
		else:
			model.remove(id)
	var fresh := BoardModel.new()
	fresh.setup(level.rows, level.columns, level.blocks)
	fresh.set_portals(level.portals)
	m["random_win"] = snappedf(Solver.from_model(fresh).random_win_rate(400, 7), 0.001)
	return m


static func describe(m: Dictionary) -> String:
	return "blocks %d  solvable %s  solution %d  start moves %d  portal moves %d  remote-blocked %d  random win %.2f" % [
		m["blocks"], m["solvable"], m["sol_len"], m["start"], m["portal_moves"], m["remote_dep"], m["random_win"]]


# --- Search (design aid; prints candidates, writes nothing) ------------------------------

func _search(profile: String, seed: int, count: int) -> void:
	# Hill climbing from random boards: mutate, keep the change if the
	# score does not drop, restart after a while. Prints every board that
	# meets the targets (and its matched control's numbers).
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var found := 0
	var seen := {}
	for restart in count:
		var map := _random_board(rng, profile)
		var m := evaluate(map, profile)
		var score := _score(m)
		for it in 250:
			var cand := _mutate(map, rng, profile)
			var cm := evaluate(cand, profile)
			var cs := _score(cm)
			if cs >= score:
				map = cand
				m = cm
				score = cs
			if _good(m) and _spinners(map) <= SPINNER_CAP.get(profile, 9) and not seen.has(str(map)):
				seen[str(map)] = true
				var ctrl := evaluate(control_map(map), profile)
				if not ctrl["solvable"] or ctrl["random_win"] - m["random_win"] < 0.15:
					continue
				found += 1
				print("--- candidate %d (restart %d)  portal: %s  interaction %s" % [found, restart, describe(m), m["interaction"]])
				print("    control: %s" % describe(ctrl))
				for row in map:
					print("    \"%s\"," % row)
				if found >= 10:
					return
				break


static func _spinners(map: Array) -> int:
	var n := 0
	for row in map:
		n += String(row).count("@")
	return n


static func _good(m: Dictionary) -> bool:
	return m["errors"].is_empty() and m["solvable"] and m["portal_moves"] >= 2 and m["remote_dep"] >= 1 \
		and m["start"] <= 3 and m["random_win"] <= 0.35 and m["random_win"] >= 0.01 and m["interaction"]


static func _score(m: Dictionary) -> float:
	if not m["errors"].is_empty():
		return -1000.0
	if not m["solvable"]:
		return 0.0
	var s := 100.0 + mini(m["portal_moves"], 3) * 12.0 + mini(m["remote_dep"], 2) * 12.0
	s -= maxi(0, m["start"] - 2) * 8.0
	s += (1.0 - m["random_win"]) * 40.0
	s += 25.0 if m["interaction"] else 0.0
	return s


## Most spinners a search candidate may have (the portal, not a spinner
## maze, should be what the board is about).
const SPINNER_CAP := {"plan": 3, "spinner": 3, "lock": 2, "gate": 2, "armor": 2, "switch": 2, "deep": 5}


func _mutate(map: Array, rng: RandomNumberGenerator, profile: String) -> Array:
	var grid := []
	for row in map:
		grid.append(Array(String(row).split(" ", false)))
	var rows := grid.size()
	var cols: int = grid[0].size()
	var blocks := []
	var empty := []
	for r in rows:
		for c in cols:
			var t: String = grid[r][c]
			if t == ".":
				empty.append(Vector2i(c, r))
			elif not t.begins_with("O") and not t.begins_with("X"):
				blocks.append(Vector2i(c, r))
	var kind := rng.randi_range(0, 9)
	if kind <= 4 and not blocks.is_empty():
		# New arrow.
		var b: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
		var t: String = grid[b.y][b.x]
		grid[b.y][b.x] = t[0] + ["^", "v", "<", ">"][rng.randi_range(0, 3)] + t.substr(2)
	elif kind <= 7 and not blocks.is_empty() and not empty.is_empty():
		# Move a block.
		var b: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
		var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
		grid[e.y][e.x] = grid[b.y][b.x]
		grid[b.y][b.x] = "."
	elif kind == 8 and not blocks.is_empty():
		# Spinner on / off (plain blocks only).
		var b: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
		var t: String = grid[b.y][b.x]
		if t.length() == 2:
			grid[b.y][b.x] = t + "@"
		elif t.ends_with("@"):
			grid[b.y][b.x] = t.substr(0, 2)
	else:
		# Move one portal cell (never into a loop: evaluate() rejects those).
		var ps := []
		for r in rows:
			for c in cols:
				if String(grid[r][c]).begins_with("O"):
					ps.append(Vector2i(c, r))
		if not empty.is_empty() and not ps.is_empty():
			var p: Vector2i = ps[rng.randi_range(0, ps.size() - 1)]
			var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
			grid[e.y][e.x] = grid[p.y][p.x]
			grid[p.y][p.x] = "."
	var out := []
	for row in grid:
		out.append(" ".join(row))
	return out


func _random_board(rng: RandomNumberGenerator, profile: String) -> Array:
	var size := Vector2i(6, 6)
	var n_blocks := rng.randi_range(9, 12)
	var n_spin := rng.randi_range(2, 3)
	if profile == "deep":
		size = Vector2i(6, 7)
		n_blocks = rng.randi_range(13, 16)
		n_spin = rng.randi_range(3, 5)
	elif profile in ["lock", "gate", "armor", "switch", "spinner"]:
		n_blocks = rng.randi_range(8, 11)
		n_spin = 2 if profile == "spinner" else rng.randi_range(0, 1)
	var grid := []
	for r in size.y:
		var row := []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	# One portal pair, in different rows and columns.
	var a := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
	var b := a
	while b.x == a.x or b.y == a.y:
		b = Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
	grid[a.y][a.x] = "OA"
	grid[b.y][b.x] = "OA"
	var colors := ["R", "B", "G", "Y", "P"]
	var arrows := ["^", "v", "<", ">"]
	var tokens := []
	for i in n_blocks:
		var t: String = colors[rng.randi_range(0, 4)] + arrows[rng.randi_range(0, 3)]
		if i < n_spin:
			t += "@" if profile != "deep" or rng.randf() < 0.6 else "@-"
		tokens.append(t)
	match profile:
		"lock":
			tokens[n_spin] = "R" + arrows[rng.randi_range(0, 3)] + "#G"
			tokens[n_spin + 1] = "G" + arrows[rng.randi_range(0, 3)]
		"gate":
			tokens.append("XC")
			tokens[n_spin] = tokens[n_spin].substr(0, 2) + "+C"
			tokens[n_spin + 1] = tokens[n_spin + 1].substr(0, 2) + "+C"
		"armor":
			tokens[n_spin] = tokens[n_spin].substr(0, 2) + "="
		"switch":
			tokens[n_spin] = tokens[n_spin].substr(0, 2) + "%A"
			tokens[n_spin + 1] = tokens[n_spin + 1].substr(0, 2) + "&A"
	for t in tokens:
		while true:
			var c := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
			if grid[c.y][c.x] == ".":
				grid[c.y][c.x] = t
				break
	var out := []
	for row in grid:
		out.append(" ".join(row))
	return out
