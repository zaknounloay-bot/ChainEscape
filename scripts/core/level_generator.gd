class_name LevelGenerator
extends RefCounted
## Prototype procedural level generator (offline/tooling use, not shipped
## as endless content yet).
##
## 1. Candidate construction runs the game BACKWARDS: blocks are "slid in"
##    from the edge one by one, each onto a cell whose lane to the edge is
##    empty, while adjacent spinners are turned counter-clockwise. Played
##    forwards, the reverse placement order is a valid solution. Placement
##    is biased toward cells that sit in existing lanes, so blocks interact.
## 2. Every candidate is still validated by the Solver - nothing is
##    accepted on construction alone.
## 3. Metrics (start moves, direction diversity, dependency depth, decision
##    points / traps) are checked against a difficulty profile, and boards
##    too similar to previously accepted ones are rejected.
##
## CLI: godot --headless --path . --script res://tools/generate_levels.gd

const COLORS := ["red", "blue", "green", "yellow", "purple"]

var rng := RandomNumberGenerator.new()
## Maps of already accepted (or curated) boards, for repetition checks.
var known_boards: Array = []
## Why the last candidates were rejected (reason -> count), for tuning.
var reject_stats: Dictionary = {}


func _init(seed: int = 0) -> void:
	rng.seed = seed


## Difficulty profiles. Every limit here is a rejection rule.
static func profile(name: String) -> Dictionary:
	var base := {
		"name": name, "sizes": [Vector2i(5, 5)], "blocks": Vector2i(10, 14), "spinners": Vector2i(0, 0),
		"min_start_moves": 1, "max_start_moves": 3, "max_direction_share": 0.40,
		"min_depth": 3, "min_decision_points": 0, "min_start_traps": 0, "max_similarity": 0.45,
		"method": "reverse", "refine_steps": 150,
	}
	match name:
		"easy":
			base.merge({"sizes": [Vector2i(4, 4), Vector2i(5, 5)], "blocks": Vector2i(8, 12), "spinners": Vector2i(0, 1),
				"max_start_moves": 3, "max_direction_share": 0.45, "min_depth": 3}, true)
		"medium":
			base.merge({"sizes": [Vector2i(5, 5)], "blocks": Vector2i(12, 16), "spinners": Vector2i(1, 2),
				"max_start_moves": 3, "min_depth": 4, "min_decision_points": 1}, true)
		"medium_hard":
			base.merge({"sizes": [Vector2i(5, 5), Vector2i(6, 6)], "blocks": Vector2i(15, 20), "spinners": Vector2i(2, 3),
				"max_start_moves": 3, "max_direction_share": 0.38, "min_depth": 5, "min_decision_points": 2}, true)
		"hard":
			base.merge({"sizes": [Vector2i(6, 6)], "blocks": Vector2i(18, 24), "spinners": Vector2i(3, 4),
				"max_start_moves": 2, "max_direction_share": 0.36, "min_depth": 6, "min_decision_points": 3,
				"min_start_traps": 1}, true)
		"expert":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(22, 28), "spinners": Vector2i(4, 6),
				"max_start_moves": 2, "max_direction_share": 0.34, "min_depth": 7, "min_decision_points": 4,
				"min_start_traps": 1}, true)
	return base


## Tries up to `attempts` candidates; returns the first accepted level or null.
## Accepted metrics are stored in `last_metrics`.
var last_metrics: Dictionary = {}


func generate(p: Dictionary, attempts: int = 300) -> LevelData:
	for i in attempts:
		var level := build_candidate(p)
		if level == null:
			_reject("construction")
			continue
		var m := evaluate(level)
		if m["solvable"] and p.get("refine_steps", 0) > 0:
			var refined := refine(level, m, p)
			level = refined[0]
			m = refined[1]
		var reason := rejection_reason(m, p, level)
		if reason != "":
			_reject(reason)
			continue
		last_metrics = m
		known_boards.append(level)
		return level
	return null


## Hill-climbing: random mutations (turn an arrow, toggle a spinner, move a
## block) are kept only if the board stays solvable and its score improves.
## Returns [level, metrics].
func refine(level: LevelData, metrics: Dictionary, p: Dictionary) -> Array:
	var best := level
	var best_m := metrics
	var best_score := _score(best_m, p)
	for step in int(p.get("refine_steps", 0)):
		var cand := _mutate(best, p)
		if cand == null:
			continue
		var m := evaluate(cand)
		if not m["solvable"] or m["aborted"]:
			continue
		var sc := _score(m, p)
		if sc >= best_score:
			best = cand
			best_m = m
			best_score = sc
	return [best, best_m]


func _score(m: Dictionary, p: Dictionary) -> float:
	var over_start: int = maxi(0, m["start_moves"] - p["max_start_moves"])
	var over_share: float = maxf(0.0, m["direction_share"] - p["max_direction_share"])
	var decisions: int = mini(m["decision_points"], p["min_decision_points"] + 3)
	return (-6.0 * over_start - 40.0 * over_share - 1.0 * m["start_moves"]
		+ 2.0 * decisions + 2.0 * mini(m["start_traps"], 2) + 0.6 * m["depth"]
		+ 1.0 * m["directions_used"])


func _mutate(level: LevelData, p: Dictionary) -> LevelData:
	var copy := LevelData.new()
	copy.rows = level.rows
	copy.columns = level.columns
	var occupied := {}
	for b in level.blocks:
		copy.blocks.append(b.duplicate_data())
		occupied[b.cell] = true
	var b: BlockData = copy.blocks[rng.randi() % copy.blocks.size()]
	var roll := rng.randf()
	var spinner_list := copy.blocks.filter(func(x): return x.is_spinner())
	var spinners := spinner_list.size()
	if roll < 0.25 and spinners > 0:
		# Trap motif: make a neighbour of a spinner point INTO it. If the
		# spinner is later turned to face that neighbour, both are stuck.
		var sp: BlockData = spinner_list[rng.randi() % spinners]
		var dirs := [0, 1, 2, 3]
		var d: int = dirs[rng.randi() % 4]
		var nb_cell: Vector2i = sp.cell + Direction.step(d)
		var nb: BlockData = null
		for x in copy.blocks:
			if x.cell == nb_cell:
				nb = x
		if nb == null:
			return null
		# Direction from neighbour back to the spinner.
		nb.direction = [Direction.DOWN, Direction.UP, Direction.RIGHT, Direction.LEFT][d]
	elif roll < 0.65:
		b.direction = (b.direction + rng.randi_range(1, 3)) % 4
	elif roll < 0.82:
		if b.is_spinner() and spinners > p["spinners"].x:
			b.kind = BlockData.Kind.NORMAL
		elif not b.is_spinner() and spinners < p["spinners"].y:
			b.kind = BlockData.Kind.SPINNER
		else:
			return null
	else:
		var empty := []
		for r in copy.rows:
			for c in copy.columns:
				if not occupied.has(Vector2i(c, r)):
					empty.append(Vector2i(c, r))
		if empty.is_empty():
			return null
		b.cell = empty[rng.randi() % empty.size()]
	var grid := {}
	for x in copy.blocks:
		grid[x.cell] = x
	copy.blocks.clear()
	_finish(copy, grid)
	return copy


## Builds one unvalidated candidate using the profile's "method":
## "reverse" (solvable by construction) or "random" (dense random board,
## filtered by the solver afterwards - better at producing few free moves).
func build_candidate(p: Dictionary) -> LevelData:
	if p.get("method", "reverse") == "random":
		return build_random(p)
	return build_reverse(p)


func build_random(p: Dictionary) -> LevelData:
	var sizes: Array = p["sizes"]
	var size: Vector2i = sizes[rng.randi() % sizes.size()]
	var n_blocks := rng.randi_range(p["blocks"].x, p["blocks"].y)
	var n_spinners := rng.randi_range(p["spinners"].x, p["spinners"].y)
	var level := LevelData.new()
	level.columns = size.x
	level.rows = size.y
	var cells := []
	for r in level.rows:
		for c in level.columns:
			cells.append(Vector2i(c, r))
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var grid := {}
	for i in mini(n_blocks, cells.size()):
		var kind := BlockData.Kind.SPINNER if i < n_spinners else BlockData.Kind.NORMAL
		grid[cells[i]] = BlockData.new(i, cells[i], "blue", rng.randi() % 4, kind)
	_finish(level, grid)
	return level


## Backwards construction (see class comment). Returns null if the board got
## too crowded to place every block.
func build_reverse(p: Dictionary) -> LevelData:
	var sizes: Array = p["sizes"]
	var size: Vector2i = sizes[rng.randi() % sizes.size()]  # x = columns, y = rows
	var n_blocks := rng.randi_range(p["blocks"].x, p["blocks"].y)
	var n_spinners := rng.randi_range(p["spinners"].x, p["spinners"].y)
	var level := LevelData.new()
	level.columns = size.x
	level.rows = size.y
	var grid := {}  # Vector2i -> BlockData
	# A block on the edge facing out can never be blocked, so it is a
	# guaranteed free starting move. Budget them.
	var edge_budget: int = maxi(p["max_start_moves"] - 1, 1)
	for i in n_blocks:
		var options := []
		var weights := []
		var blocks_free := []  # per option: how many currently free blocks it blocks
		for r in level.rows:
			for c in level.columns:
				var cell := Vector2i(c, r)
				if grid.has(cell):
					continue
				var through := _lanes_through(grid, cell, level)
				for d in 4:
					var faces_edge := not _inside(cell + Direction.step(d), level)
					if faces_edge and edge_budget <= 0:
						continue
					if _lane_empty(grid, cell, d, level):
						options.append([cell, d])
						blocks_free.append(through.x)
						# Strongly favour cells that block currently free blocks
						# (fewer obvious moves), then any lane interaction.
						weights.append(0.15 + 8.0 * through.x + 1.5 * through.y)
		if options.is_empty():
			return null
		# Usually take one of the options that blocks the most free blocks,
		# so the finished board has few obvious starting moves.
		var best: int = blocks_free.max()
		var pick: Array
		if best > 0 and rng.randf() < p.get("greed", 0.8):
			var top := []
			for k in options.size():
				if blocks_free[k] == best:
					top.append(options[k])
			pick = top[rng.randi() % top.size()]
		else:
			pick = options[_weighted(weights)]
		var cell: Vector2i = pick[0]
		if not _inside(cell + Direction.step(pick[1]), level):
			edge_budget -= 1
		# Reverse of "escape turns neighbours clockwise".
		for step in Direction.STEPS:
			var n: BlockData = grid.get(cell + step)
			if n != null and n.is_spinner():
				n.direction = Direction.rotate_ccw(n.direction)
		var remaining := n_blocks - i
		var make_spinner := n_spinners > 0 and rng.randf() < float(n_spinners) / remaining
		# Spinners placed as the very first reverse step (last to leave) are
		# pointless; keep them for when neighbours will exist.
		if make_spinner and i < 2:
			make_spinner = false
		if make_spinner:
			n_spinners -= 1
		var b := BlockData.new(i, cell, "blue", pick[1], BlockData.Kind.SPINNER if make_spinner else BlockData.Kind.NORMAL)
		grid[cell] = b
	_finish(level, grid)
	return level


## Ids in reading order, colors that differ from left/top neighbours.
func _finish(level: LevelData, grid: Dictionary) -> void:
	var ordered := grid.values()
	ordered.sort_custom(func(a, b): return a.cell.y * 100 + a.cell.x < b.cell.y * 100 + b.cell.x)
	for i in ordered.size():
		var b: BlockData = ordered[i]
		b.id = i
		var avoid := []
		for step in [Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: BlockData = grid.get(b.cell + step)
			if n:
				avoid.append(n.color)
		var choices := COLORS.filter(func(c): return not avoid.has(c))
		b.color = choices[rng.randi() % choices.size()]
		level.blocks.append(b)


func evaluate(level: LevelData) -> Dictionary:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var s := Solver.from_model(model)
	var m := s.analyze()
	m["aborted"] = s.aborted or s.any_aborted
	m["difficulty"] = difficulty(m)
	return m


## Empty string = accepted.
func rejection_reason(m: Dictionary, p: Dictionary, level: LevelData = null) -> String:
	if not m["solvable"] or m["aborted"]:
		return "unsolvable"
	if m["start_moves"] < p["min_start_moves"] or m["start_moves"] > p["max_start_moves"]:
		return "start_moves"
	if m["direction_share"] > p["max_direction_share"] or m["directions_used"] < 4:
		return "direction_diversity"
	if m["depth"] < p["min_depth"]:
		return "shallow"
	if m["decision_points"] < p["min_decision_points"] or m["start_traps"] < p["min_start_traps"]:
		return "no_decisions"
	if level != null and is_repetitive(level, p["max_similarity"]):
		return "repetitive"
	return ""


## Single number for sorting levels by difficulty. Weighted toward ordering
## decisions, not raw block count.
static func difficulty(m: Dictionary) -> float:
	return (m["blocks"] * 0.15 + m["depth"] * 0.6 + m["decision_points"] * 1.5
		+ m["trap_moves"] * 0.4 + m["start_traps"] * 1.0 + m["spinners"] * 0.5
		+ (4 - mini(m["start_moves"], 4)) * 0.5)


## Fraction of cells with the same content (same arrow, both occupied) as
## any known board of the same size.
func is_repetitive(level: LevelData, max_similarity: float) -> bool:
	for other in known_boards:
		if other.rows != level.rows or other.columns != level.columns:
			continue
		if similarity(level, other) > max_similarity:
			return true
	return false


static func similarity(a: LevelData, b: LevelData) -> float:
	var cells := {}
	for x in a.blocks:
		cells[x.cell] = x.direction
	var same := 0
	for y in b.blocks:
		if cells.get(y.cell, -1) == y.direction:
			same += 1
	return float(same) / maxf(maxf(a.blocks.size(), b.blocks.size()), 1.0)


# --- helpers -----------------------------------------------------------------

func _inside(c: Vector2i, level: LevelData) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < level.columns and c.y < level.rows


func _lane_empty(grid: Dictionary, cell: Vector2i, d: int, level: LevelData) -> bool:
	var step := Direction.step(d)
	var c := cell + step
	while c.x >= 0 and c.y >= 0 and c.x < level.columns and c.y < level.rows:
		if grid.has(c):
			return false
		c += step
	return true


## Placed blocks whose lane contains `cell`:
## x = those that are currently free (placing here would block them),
## y = all of them.
func _lanes_through(grid: Dictionary, cell: Vector2i, level: LevelData) -> Vector2i:
	var n := Vector2i.ZERO
	for b in grid.values():
		var step := Direction.step(b.direction)
		var d: Vector2i = cell - b.cell
		var hit := (step.x != 0 and d.y == 0 and signi(d.x) == step.x) or (step.y != 0 and d.x == 0 and signi(d.y) == step.y)
		if hit:
			n.y += 1
			if _lane_empty(grid, b.cell, b.direction, level):
				n.x += 1
	return n


func _weighted(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1


func _reject(reason: String) -> void:
	reject_stats[reason] = reject_stats.get(reason, 0) + 1
