extends SceneTree
## MOVABLE MECHANIC PROTOTYPE (development only): builds the mechanic lab's
## board file, data/dev/mechlab_movable.json (?mechlab=movable).
##
##   godot --headless --path . --script res://tools/mechlab_movable_build.gd            # check + write
##   godot --headless --path . --script res://tools/mechlab_movable_build.gd -- --dry   # check + print only
##   godot --headless --path . --script res://tools/mechlab_movable_build.gd -- --search=position --seed=1 --count=60
##
## Stages: A basics, B position matters, C direction / order, D an existing
## mechanic (spinner / shell), E depth, F Portal / Sequence integration
## checks (shown last, not part of the main comparison). "control": true
## also builds a matched CONTROL: every crate becomes an ARROW block (in
## each of the four directions, or the crate simply removed), keeping the
## board's size, arrows, spinners and geometry; the solvable variant with
## the LOWEST random-tapper win rate is used (never an easy one on
## purpose), turned 180 degrees so it does not look like a replay.
##
## A rule consequence that shapes every board: the arrow that pushes a
## crate stays and the crate moves along that arrow's lane, so after the
## push the crate is still in the pusher's lane. The LAST arrow to push a
## crate can only leave if its direction can change (a spinner, a switch
## flip target, a first-stage Sequence block) or the crate leaves its lane
## through a portal.
##
## Metrics (proxies only - the human test decides), from an exact
## breadth-first search of every reachable board state:
##   min moves / min pushes  of a shortest solution
##   push traps   states on that shortest path where some legal push loses
##   push needed  no solution exists without pushing

const OUT_PATH := "res://data/dev/mechlab_movable.json"
const ARROW_FLIP := {"^": "v", "v": "^", "<": ">", ">": "<"}
const STATE_CAP := 60000

const BOARDS := [
	# --- A: basics ---------------------------------------------------------------
	# Yellow (a spinner) pushes the crate up, out of green's row. Yellow then
	# needs blue to leave, so it turns and can go.
	{"id": "A1", "stage": "A", "control": false, "map": [
		".  .  .   .  .",
		".  .  .   .  .",
		"G> .  M   .  .",
		".  .  Y^@ .  .",
		".  .  B>  .  ."]},
	# The same idea sideways: red pushes the crate right, out of green's
	# column; purple leaving turns red.
	{"id": "A2", "stage": "A", "control": false, "map": [
		".   .  Gv  .  .",
		"P<  .  .   .  .",
		"R>@ .  M   .  .",
		".   .  .   .  .",
		".   .  .   .  ."]},
	# --- B: position matters -------------------------------------------------
	# The crate sits in the lanes that matter; it has to be moved away.
	{"id": "B1", "stage": "B", "control": true, "map": [
		"P^ .  .  .  .",
		".  .  .  .  .",
		".  .  .  .  .",
		".  .  M  .  B<@",
		"R^ .  Y^ .  P<"]},
	# Two pushes; a push to the wrong place gets in the way.
	{"id": "B2", "stage": "B", "control": true, "map": [
		"Y<  .  .  .   .",
		"G>@ .  .  Gv@ Y^",
		".   .  M  .   .",
		".   .  R^ .   .",
		".   .  .  .   ."]},
	# The crate must be pushed three times.
	{"id": "B3", "stage": "B", "control": true, "map": [
		".  .  .   .  .",
		".  .  R<@ P> G^@",
		".  .  .   .  .",
		".  M  .   .  Y>",
		".  Y^ .   .  ."]},
	# --- C: direction / order ---------------------------------------------------
	# Two pushes are possible; only one leaves the crate somewhere useful.
	{"id": "C1", "stage": "C", "control": true, "map": [
		"G<  .  .  Pv .",
		".   .  .  .  .",
		".   .  .  M  .",
		"R>@ .  .  .  B>",
		"Bv@ .  .  .  ."]},
	# Timing: pushing at the wrong moment (before other arrows move) loses.
	{"id": "C2", "stage": "C", "control": false, "map": [
		".   .  Pv@ .  B>",
		".   .  M   P< .",
		"R>@ .  .   R^ .",
		"Bv  .  .   .  .",
		".   .  .   .  ."]},
	# Where the crate ends up decides which lane opens later.
	{"id": "C3", "stage": "C", "control": false, "map": [
		".   .  .  .  .",
		".   M  Y< .  .",
		"G^@ .  .  .  .",
		".   .  R< .  .",
		"G^@ Yv .  .  ."]},
	# --- D: an existing mechanic (Shell) -----------------------------------------
	# A shelled block in the crate's row: crack it, push, and mind the order.
	{"id": "D1", "stage": "D", "control": false, "map": [
		"P<  .  .   .   .",
		"R>@ .  Y>  Y>  Y>=",
		".   .  .   M   .",
		".   .  Rv  .   .",
		".   .  .   P^  ."]},
	# --- E: depth (two crates) ---------------------------------------------------
	{"id": "E1", "stage": "E", "control": true, "map": [
		".  .   .    .  .   .",
		".  P^  R<   G< .   .",
		".  .   M    .  P<  .",
		".  .   .    M  R<  .",
		".  .   B^@  .  .   .",
		".  .   Yv@  .  .   ."]},
	{"id": "E2", "stage": "E", "control": true, "map": [
		".  .  .    .  M  Y>",
		".  .  R<   .  .  Y<@",
		".  .  G^@  Pv .  .",
		".  .  .    .  .  .",
		"R> M  .    .  .  .",
		".  .  P^   Yv .  ."]},
]
## Portal / Sequence integration checks (stage F, shown last).
const CHECKS := [
	# Portal: the push sends the crate into portal A; it comes out of the
	# other A and lands one cell further, freeing green's column.
	{"id": "F1", "stage": "F", "control": false, "map": [
		".   Gv  .   .   .",
		"R>@ M   OA  .   .",
		"Y<  .   .   .   .",
		".   .   .   OA  .",
		".   .   .   .   ."]},
	# Sequence: red's first stage hits the crate - the crate moves, red
	# turns to its next arrow (down) and can leave; green goes up.
	{"id": "F2", "stage": "F", "control": false, "map": [
		".    .   .  .",
		"R>:v M   .  .",
		".    .   .  .",
		".    G^  .  ."]},
]


func _init() -> void:
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var search := ""
	var seed := 1
	var count := 40
	var dry := false
	for a in OS.get_cmdline_user_args():
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
	for spec in BOARDS + CHECKS:
		var m := evaluate(spec["map"])
		var line := "%s [%s] %s" % [spec["id"], spec["stage"], describe(m)]
		if not m["errors"].is_empty() or not m["solvable"] or m["min_pushes"] == 0:
			line += "   <-- FAIL %s" % str(m["errors"])
			failures += 1
		print(line)
		var variant: String = "integration" if spec["stage"] == "F" else "movable"
		out.append(_record(spec["id"], variant, spec["stage"], spec["map"], m, spec["id"]))
		if spec.get("control", false):
			var cmap := control_map(spec["map"])
			var cid := str(spec["id"]) + "_CTRL"
			if cmap.is_empty():
				print("%s   <-- FAIL (no solvable control)" % cid)
				failures += 1
				continue
			var cm := evaluate(cmap)
			print("%s [%s] %s" % [cid, spec["stage"], describe(cm)])
			out.append(_record(cid, "control", spec["stage"], cmap, cm, spec["id"]))
	print("%d boards, %d failures" % [out.size(), failures])
	if failures > 0 or dry:
		return 1 if failures > 0 else 0
	var data := {"format": "ce-mechlab", "v": 1, "mechanic": "movable",
		"assist": {"undo": 3, "show_a_move": 1, "hammer": 0}, "boards": out}
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()
	print("wrote %s" % OUT_PATH)
	return 0


func _record(id: String, variant: String, stage: String, map: Array, m: Dictionary, pair: String) -> Dictionary:
	var canon := []
	for row in map:
		canon.append(" ".join(String(row).split(" ", false)))
	var cols: int = String(canon[0]).split(" ", false).size()
	return {"id": id, "variant": variant, "stage": stage, "pair": pair,
		"puzzle": {"format": PuzzleDefinition.FORMAT, "v": PuzzleDefinition.VERSION, "rules": PuzzleDefinition.RULES,
			"rows": map.size(), "cols": cols, "map": canon},
		"metrics": {"arrows": m["arrows"], "crates": m["crates"], "min_moves": m["min_moves"], "min_pushes": m["min_pushes"],
			"push_traps": m["push_traps"], "push_needed": m["push_needed"], "start_moves": m["start"], "random_win": m["random_win"],
			"states": m["states"]}}


static func rotate(map: Array) -> Array:
	var rows := []
	for i in range(map.size() - 1, -1, -1):
		var tokens := String(map[i]).split(" ", false)
		var out := PackedStringArray()
		for j in range(tokens.size() - 1, -1, -1):
			var t := tokens[j]
			if t != "." and t != "M" and t[0] != "X" and t[0] != "O":
				t = t[0] + ARROW_FLIP[t[1]] + t.substr(2)
				if t.contains(":"):
					t = t.substr(0, t.length() - 1) + ARROW_FLIP[t[t.length() - 1]]
			out.append(t)
		rows.append(" ".join(out))
	return rows


## The fairest-hard control: each crate becomes an arrow (any direction,
## colour Y / B / P) or an empty cell; the solvable variant with the lowest
## random win rate.
static func control_map(map: Array) -> Array:
	var variants := []
	for d in ["^", "v", "<", ">", "."]:
		var rows := []
		var k := 0
		for row in map:
			var out := PackedStringArray()
			for t in String(row).split(" ", false):
				if t == "M":
					out.append("." if d == "." else ["Y", "B", "P"][k % 3] + d)
					k += 1
				else:
					out.append(t)
			rows.append(" ".join(out))
		variants.append(rows)
	var best := []
	var best_win := 2.0
	for v in variants:
		var level := LevelManager.parse_level({"map": v})
		var model := BoardModel.new()
		model.setup(level.rows, level.columns, level.blocks)
		model.set_portals(level.portals)
		var s := Solver.from_model(model)
		if not s.is_solvable() or s.aborted:
			continue
		var w := Solver.from_model(model).random_win_rate(300, 5)
		if w < best_win:
			best_win = w
			best = v
	return rotate(best) if not best.is_empty() else []


# --- Metrics ---------------------------------------------------------------------------------

static func _model(map: Array) -> BoardModel:
	var level := LevelManager.parse_level({"map": map})
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	model.set_portals(level.portals)
	return model


static func state_key(m: BoardModel) -> String:
	var ids := m.blocks.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d,%d:%d:%d:%d:%d:%d" % [id, b.cell.x, b.cell.y, b.direction, b.spin_step, 1 if b.armored else 0, 1 if b.hidden else 0, b.seq_stage])
	return " ".join(parts)


static func play(m: BoardModel, id: int) -> String:
	var st := m.move_state(id)
	match st:
		"ok": m.remove(id)
		"advance": m.advance(id)
		"ram": m.ram(id)
		"push": m.push(id)
	return st


static func copy(m: BoardModel) -> BoardModel:
	var t := BoardModel.new()
	t.setup(m.rows, m.columns, m.snapshot())
	t.set_portals(m.portal_groups)
	return t


## Breadth-first search over every reachable state. Returns {"found": bool,
## "path": [tap ids], "kinds": [move kinds], "states": n, "capped": bool}.
static func bfs(start: BoardModel, allow_push: bool = true) -> Dictionary:
	var k0 := state_key(start)
	var parent := {k0: null}
	var queue := [[copy(start), k0]]
	var head := 0
	while head < queue.size():
		var cur: BoardModel = queue[head][0]
		var key: String = queue[head][1]
		head += 1
		if cur.is_empty():
			var path := []
			var kinds := []
			var k = key
			while parent[k] != null:
				path.push_front(parent[k][1])
				kinds.push_front(parent[k][2])
				k = parent[k][0]
			return {"found": true, "path": path, "kinds": kinds, "states": parent.size(), "capped": false}
		if parent.size() > STATE_CAP:
			return {"found": false, "path": [], "kinds": [], "states": parent.size(), "capped": true}
		for id in cur.playable_ids():
			if not allow_push and cur.move_state(id) == "push":
				continue
			var nxt := copy(cur)
			var kind := play(nxt, id)
			var nk := state_key(nxt)
			if parent.has(nk):
				continue
			parent[nk] = [key, id, kind]
			queue.append([nxt, nk])
	return {"found": false, "path": [], "kinds": [], "states": parent.size(), "capped": false}


static func evaluate(map: Array) -> Dictionary:
	var m := {"errors": [], "solvable": false, "min_moves": -1, "min_pushes": 0, "push_traps": 0, "push_needed": false,
		"start": 0, "random_win": 0.0, "arrows": 0, "crates": 0, "states": 0, "solver_ok": false}
	var cols: int = String(map[0]).split(" ", false).size()
	var tokens := 0
	for r in map.size():
		var row := String(map[r]).split(" ", false)
		if row.size() != cols:
			m["errors"].append("row %d has %d cells" % [r, row.size()])
		for t in row:
			if t != "." and not t.begins_with("O"):
				tokens += 1
	var model := _model(map)
	if model.blocks.size() != tokens:
		m["errors"].append("a cell did not parse")
	m["arrows"] = model.block_count()
	m["crates"] = model.blocks.size() - model.block_count()
	m["start"] = model.playable_ids().size()
	var s := Solver.from_model(model)
	var moves := s.solve_moves()
	# The Solver's own solution must replay with the real rules.
	var replay := copy(model)
	var ok := not moves.is_empty() and not s.aborted
	for mv in moves:
		var id: int = mv & Solver.ID_MASK
		if not replay.is_playable(id):
			ok = false
			break
		play(replay, id)
	m["solver_ok"] = ok and replay.is_empty()
	var b := bfs(model)
	m["states"] = b["states"]
	m["solvable"] = b["found"] and m["solver_ok"]
	if not b["found"]:
		if b["capped"]:
			m["errors"].append("state cap")
		return m
	m["min_moves"] = b["path"].size()
	m["min_pushes"] = b["kinds"].count("push")
	m["random_win"] = snappedf(Solver.from_model(model).random_win_rate(400, 7), 0.001)
	var nb := bfs(model, false)
	m["push_needed"] = not nb["found"]
	# Push traps along the shortest path.
	var cur := copy(model)
	for id in b["path"]:
		for q in cur.playable_ids():
			if cur.move_state(q) != "push":
				continue
			var t := copy(cur)
			t.push(q)
			var ts := Solver.from_model(t)
			if not t.is_empty() and not ts.is_solvable() and not ts.aborted:
				m["push_traps"] += 1
		play(cur, id)
	return m


static func describe(m: Dictionary) -> String:
	return "arrows %d crates %d  solvable %s  min moves %d  min pushes %d  push traps %d  push needed %s  start %d  random win %.2f  states %d" % [
		m["arrows"], m["crates"], m["solvable"], m["min_moves"], m["min_pushes"], m["push_traps"], m["push_needed"], m["start"], m["random_win"], m["states"]]


# --- Search (design aid; prints candidates, writes nothing) --------------------------------

const PROFILES := {
	"position": {"size": Vector2i(5, 5), "arrows": Vector2i(5, 7), "spin": Vector2i(1, 2), "crates": 1, "armor": 0},
	"multi": {"size": Vector2i(5, 5), "arrows": Vector2i(5, 7), "spin": Vector2i(2, 2), "crates": 1, "armor": 0},
	"order": {"size": Vector2i(5, 5), "arrows": Vector2i(6, 8), "spin": Vector2i(1, 2), "crates": 1, "armor": 0},
	"shell": {"size": Vector2i(5, 5), "arrows": Vector2i(6, 8), "spin": Vector2i(1, 2), "crates": 1, "armor": 1},
	"deep": {"size": Vector2i(6, 6), "arrows": Vector2i(7, 9), "spin": Vector2i(2, 3), "crates": 2, "armor": 0},
}


func _search(profile: String, seed: int, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var p: Dictionary = PROFILES[profile]
	var found := 0
	var seen := {}
	for restart in count:
		var map := _random_board(rng, p)
		var m := _quick(map)
		var score := _score(m, profile)
		for it in 120:
			var cand := _mutate(map, rng)
			var cm := _quick(cand)
			var cs := _score(cm, profile)
			if cs >= score:
				map = cand
				m = cm
				score = cs
			if _quick_good(m) and not seen.has(str(map)):
				seen[str(map)] = true
				var full := evaluate(map)
				if not _good(full, profile):
					continue
				var cmap := control_map(map)
				if cmap.is_empty():
					continue
				var cm2 := evaluate(cmap)
				found += 1
				print("--- candidate %d (restart %d)  movable: %s" % [found, restart, describe(full)])
				print("    control: %s" % describe(cm2))
				for row in map:
					print("    \"%s\"," % row)
				if found >= 8:
					return
				break


## Cheap measure for the climb: Solver + random tapper only.
static func _quick(map: Array) -> Dictionary:
	var q := {"solvable": false, "random_win": 1.0, "pushes": 0}
	var model := _model(map)
	var s := Solver.from_model(model)
	s.node_limit = 20000
	var moves := s.solve_moves()
	if moves.is_empty() or s.aborted:
		return q
	q["solvable"] = true
	for mv in moves:
		if mv & Solver.PUSH:
			q["pushes"] += 1
	q["random_win"] = Solver.from_model(model).random_win_rate(150, 3)
	return q


static func _quick_good(q: Dictionary) -> bool:
	return q["solvable"] and q["pushes"] >= 1 and q["random_win"] <= 0.6


static func _score(q: Dictionary, _profile: String) -> float:
	if not q["solvable"]:
		return 0.0
	return 100.0 + mini(q["pushes"], 3) * 10.0 + (1.0 - q["random_win"]) * 40.0


static func _good(m: Dictionary, profile: String) -> bool:
	if not m["errors"].is_empty() or not m["solvable"] or not m["push_needed"] or m["start"] > 4 or m["random_win"] > 0.6:
		return false
	match profile:
		"position":
			return m["push_traps"] >= 1
		"multi":
			return m["min_pushes"] >= 2
		"order":
			return m["push_traps"] >= 2
		"shell":
			return m["push_traps"] >= 1
		"deep":
			return m["min_pushes"] >= 2 and m["push_traps"] >= 2
	return false


func _random_board(rng: RandomNumberGenerator, p: Dictionary) -> Array:
	var size: Vector2i = p["size"]
	var grid := []
	for r in size.y:
		var row := []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	var tokens := []
	var n: int = rng.randi_range(p["arrows"].x, p["arrows"].y)
	var spin: int = rng.randi_range(p["spin"].x, p["spin"].y)
	for i in n:
		var t: String = ["R", "B", "G", "Y", "P"][rng.randi_range(0, 4)] + ["^", "v", "<", ">"][rng.randi_range(0, 3)]
		if i < spin:
			t += "@"
		elif i < spin + int(p["armor"]):
			t += "="
		tokens.append(t)
	for i in int(p["crates"]):
		tokens.append("M")
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


func _mutate(map: Array, rng: RandomNumberGenerator) -> Array:
	var grid := []
	for row in map:
		grid.append(Array(String(row).split(" ", false)))
	var filled := []
	var empty := []
	for r in grid.size():
		for c in grid[0].size():
			if grid[r][c] == ".":
				empty.append(Vector2i(c, r))
			else:
				filled.append(Vector2i(c, r))
	var b: Vector2i = filled[rng.randi_range(0, filled.size() - 1)]
	var t: String = grid[b.y][b.x]
	if rng.randf() < 0.45 and t != "M":
		grid[b.y][b.x] = t[0] + ["^", "v", "<", ">"][rng.randi_range(0, 3)] + t.substr(2)
	elif not empty.is_empty():
		var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
		grid[e.y][e.x] = t
		grid[b.y][b.x] = "."
	var out := []
	for row in grid:
		out.append(" ".join(row))
	return out
