extends SceneTree
## VERY HARD investigation (development only): board GEOMETRY / VISUAL
## SEARCH audit of Classic levels vs generated Friend boards.
##   godot --headless --path . --script res://tools/classic_topology_audit.gd [-- --levels]
## Groups: Classic 41-60 (only the pure arrows + clockwise-spinner levels),
## Classic 161-200 / 191-200 as they are (all use other mechanics too),
## the same late boards FLATTENED to arrows + clockwise spinners (other
## mechanics removed; kept only if still solvable), and the Friend VERY
## HARD A / B boards of the first human test (data/dev/vh_human_test.json).
## --levels also prints one row per board.
##
## The visual metrics are HYPOTHESES about human search, not proof:
##   edge_dist     how far an opening block sits from the outer ring
##   edge_exit     opening = an outer-ring block pointing straight out
##                 (the most obvious move there is)
##   buried        occupied neighbours (of 8) around an opening block
##   tempting      blocked arrows that are "almost out": at most 2 cells
##                 from the edge along their arrow, with blockers
##   scan          SALIENCE model of the eye: arrows nearest to leaving
##                 (fewest cells to the edge along the arrow) are checked
##                 first; scan = the share of the board checked before the
##                 first SAFE move is found (0 = the first arrow you look at)
##   later_scan    the same at every solution step, average; and the number
##                 of steps where the next safe move is not in the first 30%

const PURE_RE := "^[RBGYP][\\^v<>](@)?$"


func _init() -> void:
	var per_level := "--levels" in OS.get_cmdline_user_args()
	var groups := {}
	groups["Classic 41-60 pure"] = []
	groups["Classic 161-200 raw"] = []
	groups["Classic 191-200 raw"] = []
	groups["Classic 161-200 flat"] = []
	var flat_failed := 0
	for n in range(1, 201):
		var json = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n))
		var level := LevelManager.parse_level(json, n)
		var def := PuzzleDefinition.from_level(level)
		var row := {"name": "L%d" % n, "def": def}
		if n >= 41 and n <= 60 and pure(def):
			groups["Classic 41-60 pure"].append(row)
		if n >= 161:
			groups["Classic 161-200 raw"].append(row)
			if n >= 191:
				groups["Classic 191-200 raw"].append(row)
			var flat := flatten(def)
			if flat != null and flat.verify():
				groups["Classic 161-200 flat"].append({"name": "L%d-flat" % n, "def": flat})
			else:
				flat_failed += 1
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/vh_human_test.json"))
	for v in ["A", "B"]:
		groups["Friend VH " + v] = []
		for b in data["boards"]:
			if b["variant"] == v:
				groups["Friend VH " + v].append({"name": b["id"], "def": PuzzleDefinition.from_dict(b["puzzle"])})
	print("Classic 161-200 flattened: %d solvable, %d not" % [groups["Classic 161-200 flat"].size(), flat_failed])
	var keys := ["size", "blocks", "empty", "density", "start", "start_safe", "start_calm", "edge_exit", "edge_dist", "buried", "tempting",
		"scan", "later_scan", "hidden_steps", "branch_after_1", "one_safe", "depth", "spin_turns", "cluster", "smart2"]
	print("group | n | " + " | ".join(keys))
	for g in groups:
		var rows := []
		for r in groups[g]:
			var m := measure(r["def"])
			m["name"] = r["name"]
			rows.append(m)
			if per_level:
				print("  %s %s" % [r["name"], _fmt(m, keys)])
		var avg := {}
		for k in keys:
			if k == "size":
				var sizes := {}
				for m in rows:
					sizes[m["size"]] = true
				avg[k] = "/".join(sizes.keys())
			else:
				avg[k] = rows.reduce(func(a, m): return a + float(m[k]), 0.0) / maxf(rows.size(), 1)
		print("%s | %d | %s" % [g, rows.size(), _fmt(avg, keys)])
	quit()


static func pure(def: PuzzleDefinition) -> bool:
	var re := RegEx.create_from_string(PURE_RE)
	for row in def.map:
		for t in String(row).split(" ", false):
			if t != "." and re.search(_strip_reward(t)) == null:
				return false
	return true


static func _strip_reward(t: String) -> String:
	return RegEx.create_from_string("\\$[SGD]").sub(t, "", true)


## Same geometry and arrows, only arrows + clockwise spinners: every spinner
## rule becomes clockwise; locks, hidden, rewards, switches, flips, gate
## links and armor are dropped; gate slabs become empty cells. Returns null
## if a token can't be read. (Solvability is checked by the caller.)
static func flatten(def: PuzzleDefinition) -> PuzzleDefinition:
	var tok := RegEx.create_from_string("^([RBGYPrbgyp])([\\^v<>])(@[-~*]?)?")
	var rows := []
	for row in def.map:
		var cells := []
		for t in String(row).split(" ", false):
			if t == "." or t.begins_with("X"):
				cells.append(".")
				continue
			var m := tok.search(t)
			if m == null:
				return null
			cells.append(m.get_string(1).to_upper() + m.get_string(2) + ("@" if m.get_string(3) != "" else ""))
		rows.append(" ".join(cells))
	return PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": def.rows, "cols": def.columns, "map": rows})


## 180-degree rotation (orientation-preserving: clockwise stays clockwise),
## for showing a known board without it being recognised.
static func rotate180(def: PuzzleDefinition) -> PuzzleDefinition:
	var flip := {"^": "v", "v": "^", "<": ">", ">": "<"}
	var rows := []
	for r in range(def.map.size() - 1, -1, -1):
		var cells := Array(String(def.map[r]).split(" ", false))
		cells.reverse()
		for i in cells.size():
			var t: String = cells[i]
			if t != ".":
				cells[i] = t[0] + flip[t[1]] + t.substr(2)
		rows.append(" ".join(cells))
	return PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": def.rows, "cols": def.columns, "map": rows})


## 90-degree clockwise rotation (orientation-preserving like rotate180):
## cell (c, r) -> (rows-1-r, c); arrows turn a quarter clockwise; the board
## becomes rows x columns. Spinner rules are kept.
static func rotate90(def: PuzzleDefinition) -> PuzzleDefinition:
	var turn := {"^": ">", ">": "v", "v": "<", "<": "^"}
	var grid := []
	for row in def.map:
		grid.append(Array(String(row).split(" ", false)))
	var rows := []
	for c in def.columns:
		var cells := []
		for r in range(def.rows - 1, -1, -1):
			var t: String = grid[r][c]
			cells.append(t if t == "." else t[0] + turn[t[1]] + t.substr(2))
		rows.append(" ".join(cells))
	return PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": def.columns, "cols": def.rows, "map": rows})


static func measure(def: PuzzleDefinition) -> Dictionary:
	var lv := def.to_level()
	var model := BoardModel.new()
	model.setup(lv.rows, lv.columns, lv.blocks)
	var s := Solver.from_model(model)
	var a := s.analyze()
	var m := {"size": "%dx%d" % [lv.columns, lv.rows], "blocks": model.block_count(),
		"empty": lv.rows * lv.columns - model.block_count(),
		"density": float(model.block_count()) / (lv.rows * lv.columns),
		"start": a["start_moves"], "start_safe": a["start_safe"], "start_calm": a["start_calm"],
		"one_safe": a["one_safe_steps"], "depth": a["depth"]}
	# Openings: where they are and how they look.
	var openings := []
	for id in model.blocks:
		if model.move_state(id) == "ok":
			openings.append(id)
	var safe_open := []
	for id in openings:
		var probe := BoardModel.new()
		probe.setup(model.rows, model.columns, model.snapshot())
		probe.remove(id)
		if probe.is_empty() or Solver.from_model(probe).is_solvable():
			safe_open.append(id)
	m["edge_exit"] = openings.filter(func(id): return _edge_dist(model, id) == 0 and _lane(model, id) == 0).size()
	m["edge_dist"] = _avg(safe_open.map(func(id): return _edge_dist(model, id)))
	m["buried"] = _avg(safe_open.map(func(id): return _neighbours(model, id)))
	var tempting := 0
	for id in model.blocks:
		if model.move_state(id) != "ok" and _lane(model, id) <= 2 and model.find_blocker(id) != null:
			tempting += 1
	m["tempting"] = tempting
	m["scan"] = _scan(model, safe_open)
	# Later moments: walk the Solver's solution.
	var sol: Array = s.solve()
	var walk := BoardModel.new()
	walk.setup(model.rows, model.columns, model.snapshot())
	var scans := []
	var hidden_steps := 0
	var spin_turns := 0
	var branch_after_1 := 0
	for step in sol.size():
		if step > 0:
			var safe := []
			for id in walk.blocks:
				if walk.move_state(id) == "ok":
					var p := BoardModel.new()
					p.setup(walk.rows, walk.columns, walk.snapshot())
					p.remove(id)
					if p.is_empty() or Solver.from_model(p).is_solvable():
						safe.append(id)
			var sc := _scan(walk, safe)
			scans.append(sc)
			if sc > 0.3:
				hidden_steps += 1
			if step == 1:
				branch_after_1 = walk.blocks.keys().filter(func(id): return walk.move_state(id) == "ok").size()
		var turned := walk.remove(sol[step])
		spin_turns += 1 if not turned.is_empty() else 0
	m["later_scan"] = _avg(scans)
	m["hidden_steps"] = hidden_steps
	m["spin_turns"] = spin_turns
	m["branch_after_1"] = branch_after_1
	m["cluster"] = _avg(model.blocks.keys().map(func(id): return _neighbours(model, id)))
	m["smart2"] = s.heuristic_win_rate(60, 2, 4242)
	return m


## Cells between the block and the outer ring (0 = on the ring).
static func _edge_dist(model: BoardModel, id: int) -> int:
	var c: Vector2i = model.blocks[id].cell
	return mini(mini(c.x, model.columns - 1 - c.x), mini(c.y, model.rows - 1 - c.y))


## Cells between the block and the edge ALONG its arrow (occupied or not).
static func _lane(model: BoardModel, id: int) -> int:
	var b: BlockData = model.blocks[id]
	var n := 0
	var cell: Vector2i = b.cell + Direction.step(b.direction)
	while model.is_inside(cell):
		n += 1
		cell += Direction.step(b.direction)
	return n


static func _neighbours(model: BoardModel, id: int) -> int:
	var c: Vector2i = model.blocks[id].cell
	var n := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if (dx != 0 or dy != 0) and model.block_at(c + Vector2i(dx, dy)) != null:
				n += 1
	return n


## Salience scan: blocks ordered by how close their arrow is to the edge
## (ties: on the ring first); the share of blocks checked before the first
## safe move (ties counted at their average position).
static func _scan(model: BoardModel, safe: Array) -> float:
	if safe.is_empty() or model.block_count() == 0:
		return 1.0
	var key := func(id): return _lane(model, id) * 10 + _edge_dist(model, id)
	var best := 1 << 30
	for id in safe:
		best = mini(best, key.call(id))
	var before := 0
	var tied := 0
	for id in model.blocks:
		var k: int = key.call(id)
		if k < best:
			before += 1
		elif k == best:
			tied += 1
	return (before + (tied - 1) * 0.5) / float(model.block_count())


static func _avg(a: Array) -> float:
	return a.reduce(func(x, y): return x + float(y), 0.0) / maxf(a.size(), 1) if not a.is_empty() else 0.0


func _fmt(m: Dictionary, keys: Array) -> String:
	var out := []
	for k in keys:
		var v = m[k]
		out.append(("%.2f" % v) if typeof(v) == TYPE_FLOAT else str(v))
	return " | ".join(out)
