extends SceneTree
## MAGNET campaign levels 76-99 (docs/magnet_campaign_plan.md, approved).
## 22 boards replace 76-79, 81-89 and 91-99; Levels 80 and 90 (Mystery) stay
## byte-identical. Every level keeps its name and its exact Silver / Gold
## reward blocks (the economy is unchanged).
##
##   godot --headless --path . --script res://tools/magnet_campaign_build.gd            # verify BOARDS
##   godot --headless --path . --script res://tools/magnet_campaign_build.gd -- --write # verify + write levels
##   godot --headless --path . --script res://tools/magnet_campaign_build.gd -- --search=86 --seed=3 --minutes=8
##
## A board passes when (the campaign verifier's rules for 76-99, plus the
## plan's intent):
##   - solvable; the Magnet is NECESSARY (no win with every magnet a plain
##     arrow) - except the breathers 85 / 97, which must still pull;
##   - lessons 76-79: <= 3 start moves, depth >= 3; from 81: <= 2 start
##     moves, depth >= 8, >= 4 decision points, all four directions, no
##     direction on more than 45% of the blocks, spinners not decorative;
##   - the level's IDEA (FEATURE) happens in the solver's solution;
##   - difficulty inside the level's planned band;
##   - not more than 60% alike any other campaign board of its size;
##   - the hint (Solver.recommend_move) at the start never gives up.
## Rewards are put on plain arrows afterwards (they never change solving).

const SPECS := {
	# n: [cols, rows, blocks, magnets, spinners, lesson/breather, [diff lo, hi], feature, idea]
	76: [6, 6, 7, 1, 0, "lesson", [2.0, 7.0], "essential", "LESSON: two blocks face each other and can never leave; the magnet pulls one free"],
	77: [6, 6, 9, 1, 1, "lesson", [5.0, 11.0], "far_pull", "the pull can travel far: the block behind slides several cells"],
	78: [6, 6, 10, 2, 1, "lesson", [7.0, 13.0], "empty_magnet", "one magnet pulls; the other has nothing behind it"],
	79: [7, 6, 12, 1, 2, "lesson", [10.0, 18.0], "retarget", "first choice: clear the nearer block so the line moves to the right one"],
	81: [7, 6, 15, 1, 3, "", [16.0, 25.0], "spin_adjacent", "the magnet's escape turns the spinner beside it"],
	82: [7, 7, 16, 1, 3, "", [18.0, 27.0], "pulled_spinner", "the pulled block is a spinner"],
	83: [7, 6, 16, 1, 4, "", [20.0, 29.0], "pulled_spinner", "spinner timing before the pull"],
	84: [7, 7, 17, 1, 4, "", [21.0, 31.0], "spin_adjacent_retarget", "two escapes beside a spinner decide where things land"],
	85: [7, 6, 15, 1, 3, "breather", [13.0, 22.0], "pull", "BREATHER: a friendly spinner board with one helpful pull"],
	86: [7, 7, 17, 2, 3, "", [24.0, 34.0], "retarget", "decoys: clear them in the right order"],
	87: [7, 6, 17, 1, 4, "", [26.0, 36.0], "magnet_too_early", "the magnet is free at once - but pulling now loses"],
	88: [7, 6, 18, 2, 3, "", [27.0, 37.0], "chain", "a magnet pulls another magnet into place"],
	89: [7, 7, 18, 2, 4, "", [29.0, 39.0], "crossing", "two magnets whose pull lines cross"],
	91: [7, 7, 18, 2, 4, "", [31.0, 41.0], "shared_line", "two magnets in one line"],
	92: [7, 7, 19, 2, 4, "", [33.0, 43.0], "wait", "the magnet is free early but must wait"],
	93: [7, 7, 20, 3, 4, "", [35.0, 46.0], "chain_or_spinner", "chain pulls and spinner timing together"],
	94: [7, 7, 19, 2, 4, "", [36.0, 47.0], "patterned", "a patterned spinner meets a pulled block"],
	95: [7, 7, 19, 2, 4, "", [35.0, 46.0], "double_retarget", "two magnets, each the other's decoy"],
	96: [7, 7, 20, 2, 5, "", [38.0, 49.0], "magnet_too_early", "challenge: two visible traps"],
	97: [7, 7, 18, 2, 4, "breather", [24.0, 35.0], "two_pulls", "BREATHER: a satisfying chain of pulls"],
	98: [7, 6, 20, 3, 5, "", [44.0, 56.0], "hardest", "the hardest Magnet level: a full plan from the first tap"],
	99: [7, 6, 18, 2, 4, "", [32.0, 43.0], "retarget_spinner", "finale: every Magnet idea once more"],
}
const BREATHERS := [85, 97]
const UNCHANGED := [80, 90]

## The chosen boards (from --search --seed=1, picked for a smooth ramp inside
## each Chapter, Level 98 the clear peak; rewards added on write).
const BOARDS := {
	76: [
		". . . . . .",
		". . . . . .",
		". Yv . . R<* Pv",
		". Rv . . . P^",
		". . . . . .",
		". P< Bv . . .",
	],
	77: [
		". . . . . .",
		". . . . . .",
		"Bv P^ . R>* Y^ Yv",
		". . . G< . G<",
		". . . . . .",
		"G^@ . . . P< .",
	],
	78: [
		". . . B> . Yv*",
		". . Y^ B< Y>@ .",
		". . . B^ . .",
		". . . . R< .",
		". . . . . .",
		". . Y^ . R<* Y^",
	],
	79: [
		". Yv . . . B< .",
		". . . . . G^ G<@",
		". G> . . . . R^",
		". . . . . . .",
		"G^ B< . . . . .",
		"G^ Rv* Y<@ . Rv . .",
	],
	81: [
		". . . Y>@ P<@ G< .",
		". . . . G^ . .",
		". . R> Pv* P^@ . .",
		". . . . . . .",
		"Rv . . R< B^ G^ .",
		"Rv Y< . . P< G^ .",
	],
	82: [
		". Y^ R>@ . Pv . .",
		"G>@ . B^ . . . .",
		". . . . . . .",
		"P^ . Yv@ . P>* . .",
		". . . . . Bv R<",
		"B^ . G< . . P> Pv",
		". . R^ . . . B<",
	],
	83: [
		". B> . G>@ P>* . .",
		"Rv@ B^@ . . . . .",
		". Yv . . . Y< .",
		". . R< G< . . .",
		"G^ Yv@ . G^ . G^ R<",
		". G> . B^ . . .",
	],
	84: [
		"B> . . . . Gv .",
		"R> . . . . . B>",
		". . . G<@ . B> B^",
		"B^ . R<@ R^* . . G^@",
		". . Y^ Y< . . .",
		". . . Y> G< . .",
		". . . . R>@ . R<",
	],
	85: [
		". . . Gv@ . . .",
		". Pv . . . . .",
		". . . G>@ . Bv .",
		"Y^ R< B< B> . Pv Yv",
		". . . Rv@ . . B<",
		". . B^ G<* . R< .",
	],
	86: [
		". Pv@ . R>* Y^@ . .",
		". . . . . . Pv",
		"Bv . . Y<* P^ G< .",
		". . Y> . Gv@ . Pv",
		". . . . . . .",
		"Y< . . . . . P<",
		". Y^ B< . R< Y< .",
	],
	87: [
		". G^* G>@ . . P<@ Pv",
		". . B> . . . Gv",
		". R> . . G>@ B^ .",
		". Rv Y^ G< P< G^@ G>",
		". R> . . . B^ .",
		". . . . . . .",
	],
	88: [
		"Bv . P< P< Y> . .",
		". G>@ . . Y^* R>* .",
		"Rv P^ B^@ R^ R<@ P> G<",
		". . . . . . .",
		". . R^ . . P^ .",
		"G> . . . . P^ .",
	],
	89: [
		"Bv B>@ . Rv . . .",
		". . Y>@ . . G> .",
		". . G^ . R<* Bv Y<",
		". . . . . . .",
		"R> . . . B> R^ R^@",
		". B^ . G> . Gv@ .",
		". . . . Y> Yv* .",
	],
	91: [
		"G> B>* . . R<@ . .",
		". . . . G< . .",
		". P^@ . G<@ . . .",
		". B^* . . G^ . .",
		". Y> . P< Pv . .",
		"G^ P^@ P< B^ . . .",
		". . Y^ R^ R< . .",
	],
	92: [
		". Y< . B<* . Gv .",
		"Pv . . Rv . . Y<",
		"Bv . . . . . P^",
		". R> . . . . R^",
		"G>@ . . . B> Y^ .",
		"R> . . B>@ Y<@ P^ Y>*",
		". . . . . . G^@",
	],
	93: [
		"B> . . Y> G>@ . Yv",
		"Y^* R^ P< Y^ R^@ . Gv",
		". Y>@ . B< . . .",
		"P^* Bv . . . . .",
		". Gv . . . . .",
		". . . . . . R<",
		"Y>@ G< G^ R^* . . .",
	],
	94: [
		"Rv . . . . . Y<",
		". . B>@* . . P< .",
		". B^ Y< B>* P> B^ .",
		"Yv . . . . . P<@",
		"Yv@ G^@ . G< R^ . .",
		"Y<* . . . . . Gv",
		". . . . . B^ Y^",
	],
	95: [
		". . . Gv@ B>@ B> Y^",
		". . . . R^ . .",
		". Yv . P^ . . .",
		". . . . . Y> Y^@",
		"Y> P> . . . Bv* .",
		". Pv* Rv B^@ G< . .",
		". R< P< . . B< .",
	],
	96: [
		"Y> . R^* P<@ . B> .",
		". P> . G^ . Y^ .",
		"B> . B> . . P^ .",
		"G>@ . . . B>@ B^ .",
		"Y^* . . Yv . . .",
		". . P> B<@ . . G<@",
		". . Y^ . . . P<",
	],
	97: [
		"Gv . . Y> . P>* Bv",
		". . Gv . P<@ . .",
		"R^ R>* . Bv . . .",
		". . . . G^ . B<",
		". . P^@ B>@ . . Bv",
		". . Rv@ . . . .",
		". . Yv . . G< Y<",
	],
	98: [
		". . B> G> Yv . .",
		"Yv Pv R^@ Y^ . Rv .",
		". . . R> G^@ Pv .",
		"P>@ . G^* R<@ Rv* Gv .",
		". . . . G>@ Pv* .",
		". . B> G< . . .",
	],
	99: [
		". . . . Bv@ G< .",
		"Bv R> . . Gv G^ .",
		". . P> Yv . . .",
		"B> P^ . . Y^* . P>*",
		". . R> Rv G>@ R> G^@",
		". . . . . . P^@",
	],
}

var _known: Array = []  # [n, LevelData] of every other campaign board


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var k := a.trim_prefix("--")
		args[k.get_slice("=", 0)] = k.get_slice("=", 1) if k.contains("=") else "1"
	_load_known()
	if args.has("search"):
		_search(int(args["search"]), int(args.get("seed", "1")), float(args.get("minutes", "6")))
		quit()
		return
	var errors := _verify(args.has("write"))
	print("MAGNET CAMPAIGN BUILD %s (%d problem%s)" % ["OK" if errors == 0 else "FAILED", errors, "" if errors == 1 else "s"])
	quit(0 if errors == 0 else 1)


func _load_known() -> void:
	for n in range(1, 301):
		if n >= 76 and n <= 99 and not UNCHANGED.has(n):
			continue  # the boards being replaced
		var path := "res://levels/level_%02d.json" % n
		var j = JSON.parse_string(FileAccess.get_file_as_string(path))
		_known.append([n, LevelManager.parse_level(j, n, true)])


# --- Evaluation ------------------------------------------------------------------------

static func parse(map: Array, n: int) -> LevelData:
	return LevelManager.parse_level({"name": "L%d" % n, "map": map}, n, true)


## Problems of `map` as level `n` ([] = passes) and its metrics.
func evaluate(map: Array, n: int, full := true) -> Dictionary:
	var spec: Array = SPECS[n]
	var level := parse(map, n)
	var out := {"problems": [], "cost": 0.0, "m": {}}
	var mags := level.blocks.filter(func(b): return b.magnet)
	if mags.size() != spec[3]:
		return _fail(out, "magnet count", 2000.0)
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var s := Solver.from_model(model)
	var sol := s.solve()
	if sol.is_empty():
		return _fail(out, "unsolvable" if not s.aborted else "solver gave up", 1000.0)
	var lesson: bool = spec[5] == "lesson"
	var start := Solver.from_model(model)._distinct_legal().size()
	var max_start := 3 if lesson else 2
	if start > max_start:
		return _fail(out, "start moves %d > %d" % [start, max_start], 500.0 + 60.0 * (start - max_start))
	var plain := []
	for b in level.blocks:
		var c: BlockData = b.duplicate_data()
		c.magnet = false
		plain.append(c)
	var ps := Solver.new(level.rows, level.columns, plain)
	var essential := not ps.is_solvable() and not ps.aborted
	if not BREATHERS.has(n) and not essential:
		return _fail(out, "magnet not necessary", 400.0)
	var m := LevelAnalysis.analyze(level, full)
	out["m"] = m
	var cost := 0.0
	var probs := []
	if m["pulls"] == 0:
		probs.append("no pull in the solution")
		cost += 300.0
	if lesson:
		if m["depth"] < 3:
			probs.append("depth %d < 3" % m["depth"])
			cost += 40.0 * (3 - m["depth"])
	else:
		if m["depth"] < 8:
			probs.append("depth %d < 8" % m["depth"])
			cost += 30.0 * (8 - m["depth"])
		if m["decision_points"] < 4:
			probs.append("decisions %d < 4" % m["decision_points"])
			cost += 30.0 * (4 - m["decision_points"])
		if m["directions_used"] < 4:
			probs.append("directions %d" % m["directions_used"])
			cost += 40.0
		if m["direction_share"] > 0.45:
			probs.append("direction share %.2f" % m["direction_share"])
			cost += 200.0 * (m["direction_share"] - 0.45) + 20.0
	if full and m["spinners"] > 0 and m["spinner_impact"] < 0.5:
		probs.append("spinners decorative (%.1f)" % m["spinner_impact"])
		cost += 60.0
	var band: Array = spec[6]
	if m["difficulty"] < band[0]:
		probs.append("difficulty %.1f < %.1f" % [m["difficulty"], band[0]])
		cost += 6.0 * (band[0] - m["difficulty"])
	elif m["difficulty"] > band[1]:
		probs.append("difficulty %.1f > %.1f" % [m["difficulty"], band[1]])
		cost += 6.0 * (m["difficulty"] - band[1])
	var feat := _feature(spec[7], level, model, sol)
	if feat != "":
		probs.append(feat)
		cost += 120.0
	for k in _known:
		var other: LevelData = k[1]
		if other.rows == level.rows and other.columns == level.columns and LevelGenerator.similarity(level, other) > 0.6:
			probs.append("60%%+ like L%d" % k[0])
			cost += 150.0
			break
	if full:
		var h := Solver.from_model(model)
		var hint := h.recommend_move()
		if hint == -1 or h.any_aborted:
			probs.append("hint at the start gave up")
			cost += 200.0
	out["problems"] = probs
	out["cost"] = cost
	out["essential"] = essential
	out["start"] = start
	return out


static func _fail(out: Dictionary, why: String, cost: float) -> Dictionary:
	out["problems"] = [why]
	out["cost"] = cost
	return out


## "" if the level's idea happens in the solver's solution, else why not.
static func _feature(kind: String, level: LevelData, start: BoardModel, sol: Array) -> String:
	var r := BoardModel.new()
	r.setup(level.rows, level.columns, level.blocks)
	var first_target := {}
	for b in r.blocks.values():
		if b.magnet:
			var t := r.pull_target(b.id)
			first_target[b.id] = t.get("block", -1)
	var pulls := []  # {"magnet", "block", "dist", "spinner", "magnet_pulled", "retarget", "index", "turned"}
	var escaped_empty := 0
	for i in sol.size():
		var id: int = sol[i] & Solver.ID_MASK
		var was: BlockData = r.blocks[id]
		var mag := was.magnet
		var dir_before := {}
		for b in r.blocks.values():
			dir_before[b.id] = b.direction
		r.remove(id)
		if mag:
			if r.last_pull.is_empty():
				escaped_empty += 1
			else:
				var p := r.last_pull
				var pb: BlockData = r.blocks[p["block"]]
				pulls.append({"magnet": id, "block": p["block"], "dist": (p["from"] - p["to"]).abs().x + (p["from"] - p["to"]).abs().y,
					"spinner": pb.is_spinner(), "magnet_pulled": pb.magnet, "retarget": first_target.get(id, -1) != p["block"],
					"index": i, "turned": dir_before.get(p["block"], pb.direction) != pb.direction})
	var spin_adjacent := false
	for b in start.blocks.values():
		if b.magnet:
			for st in Direction.STEPS:
				var o := start.block_at(b.cell + st)
				if o != null and o.is_spinner():
					spin_adjacent = true
	var mags := start.blocks.values().filter(func(b): return b.magnet)
	match kind:
		"essential", "pull":
			return "" if not pulls.is_empty() else "no pull"
		"far_pull":
			return "" if pulls.any(func(p): return p["dist"] >= 3) else "no pull of 3+ cells"
		"empty_magnet":
			return "" if escaped_empty >= 1 and not pulls.is_empty() else "needs one pull and one empty magnet"
		"retarget":
			return "" if pulls.any(func(p): return p["retarget"]) else "no retargeted pull"
		"double_retarget":
			return "" if pulls.filter(func(p): return p["retarget"]).size() >= 2 else "needs two retargeted pulls"
		"spin_adjacent":
			return "" if spin_adjacent else "no spinner beside a magnet"
		"spin_adjacent_retarget":
			return "" if spin_adjacent and pulls.any(func(p): return p["retarget"]) else "needs a spinner beside a magnet and a retarget"
		"pulled_spinner":
			return "" if pulls.any(func(p): return p["spinner"]) else "no spinner pulled"
		"retarget_spinner":
			return "" if pulls.any(func(p): return p["retarget"]) and (pulls.any(func(p): return p["spinner"]) or spin_adjacent) else "needs a retarget and a spinner pull"
		"chain":
			return "" if pulls.any(func(p): return p["magnet_pulled"]) else "no magnet pulled by a magnet"
		"chain_or_spinner":
			return "" if pulls.any(func(p): return p["magnet_pulled"]) and pulls.any(func(p): return p["spinner"] or p["turned"]) else "needs a chain pull and a spinner pull"
		"two_pulls":
			return "" if pulls.size() >= 2 else "needs two pulls"
		"crossing":
			if mags.size() < 2:
				return "two magnets needed"
			var a: BlockData = mags[0]
			var b: BlockData = mags[1]
			var vertical_a: bool = Direction.STEPS[a.direction].x == 0
			var vertical_b: bool = Direction.STEPS[b.direction].x == 0
			return "" if vertical_a != vertical_b and pulls.size() >= 2 else "needs a vertical and a horizontal magnet, both pulling"
		"shared_line":
			if mags.size() < 2:
				return "two magnets needed"
			var a2: BlockData = mags[0]
			var b2: BlockData = mags[1]
			return "" if (a2.cell.x == b2.cell.x or a2.cell.y == b2.cell.y) and pulls.size() >= 2 else "needs two pulling magnets in one line"
		"wait":
			# A magnet free at the start that the solution only uses late.
			for b in mags:
				if start.move_state(b.id) == "ok":
					var idx := sol.map(func(x): return x & Solver.ID_MASK).find(b.id)
					if idx >= sol.size() / 2:
						return ""
			return "no free magnet that must wait"
		"magnet_too_early":
			for b in mags:
				if start.move_state(b.id) == "ok":
					var t := start.snapshot()
					start.remove(b.id)
					var lost := not Solver.from_model(start).is_solvable()
					start.restore(t)
					if lost:
						return ""
			return "no free magnet whose early pull loses"
		"patterned":
			var patterned := start.blocks.values().any(func(b): return b.is_spinner() and b.spin_rule >= BlockData.SpinRule.ALT)
			return "" if patterned and (spin_adjacent or pulls.any(func(p): return p["spinner"])) else "needs a patterned spinner meeting a pull"
		"hardest":
			return "" if pulls.size() >= 2 and pulls.any(func(p): return p["retarget"]) else "needs 2+ pulls with a retarget"
	return ""


# --- Search --------------------------------------------------------------------------------

const DIRS := ["^", "v", "<", ">"]
const COLORS := ["R", "B", "G", "Y", "P"]


func _search(n: int, seed: int, minutes: float) -> void:
	var spec: Array = SPECS[n]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 1000 + n
	var deadline := Time.get_ticks_msec() + int(minutes * 60000.0)
	var best_cost := INF
	var found := 0
	while Time.get_ticks_msec() < deadline:
		var grid := _random(spec, rng, n)
		var cost: float = evaluate(_map(grid, spec), n, false)["cost"]
		var temp := 30.0
		var stale := 0
		while stale < 400 and Time.get_ticks_msec() < deadline:
			var cand := _mutate(grid, spec, rng, n)
			var c: float = evaluate(_map(cand, spec), n, false)["cost"]
			if c <= cost or rng.randf() < exp(-(c - cost) / maxf(temp, 0.01)):
				stale = 0 if c < cost else stale + 1
				grid = cand
				cost = c
			else:
				stale += 1
			temp *= 0.995
			if cost == 0.0:
				var full := evaluate(_map(grid, spec), n, true)
				if full["cost"] == 0.0:
					var m: Dictionary = full["m"]
					found += 1
					print("FOUND L%d %s" % [n, JSON.stringify({"map": _map(grid, spec), "difficulty": m["difficulty"],
						"structural": LevelGenerator.structural_difficulty(m), "depth": m["depth"], "decisions": m["decision_points"],
						"traps": m["trap_moves"], "start_traps": m["start_traps"], "start": full["start"], "pulls": m["pulls"]})])
					if found >= 3:
						return
					break
				cost = full["cost"]
		if cost < best_cost:
			best_cost = cost
	print("SEARCH L%d done: found %d, best cost %.1f" % [n, found, best_cost])


func _random(spec: Array, rng: RandomNumberGenerator, n: int) -> Dictionary:
	var cells := []
	for r in spec[1]:
		for c in spec[0]:
			cells.append(Vector2i(c, r))
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var grid := {}
	for i in spec[2]:
		grid[cells[i]] = _token(i, spec, rng, n)
	return grid


func _token(i: int, spec: Array, rng: RandomNumberGenerator, n: int) -> String:
	var t: String = COLORS[rng.randi_range(0, 4)] + DIRS[rng.randi_range(0, 3)]
	if i < spec[3]:
		return t + "*"
	if i < spec[3] + spec[4]:
		if spec[7] == "patterned" and i == spec[3]:
			return t + "@*"
		return t + "@"
	return t


func _mutate(grid: Dictionary, spec: Array, rng: RandomNumberGenerator, _n: int) -> Dictionary:
	var g := grid.duplicate()
	var keys := g.keys()
	var cell: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
	var tok: String = g[cell]
	match rng.randi_range(0, 2):
		0:
			g[cell] = tok.substr(0, 1) + DIRS[rng.randi_range(0, 3)] + tok.substr(2)
		1:
			var to := Vector2i(rng.randi_range(0, spec[0] - 1), rng.randi_range(0, spec[1] - 1))
			if not g.has(to):
				g.erase(cell)
				g[to] = tok
		2:
			var other: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
			g[cell] = g[other]
			g[other] = tok
	return g


static func _map(grid: Dictionary, spec: Array) -> Array:
	var rows := []
	for r in spec[1]:
		var row := []
		for c in spec[0]:
			row.append(grid.get(Vector2i(c, r), "."))
		rows.append(" ".join(row))
	return rows


# --- Verify / write -------------------------------------------------------------------------

func _verify(write: bool) -> int:
	var errors := 0
	if BOARDS.size() != SPECS.size():
		print("PROBLEM: %d of %d boards chosen" % [BOARDS.size(), SPECS.size()])
		errors += 1
	for n in SPECS:
		if not BOARDS.has(n):
			continue
		var map: Array = BOARDS[n]
		var r := evaluate(map, n, true)
		var m: Dictionary = r["m"]
		print("L%d %s: %s" % [n, SPECS[n][8], ("difficulty %.1f structural %.1f depth %d decisions %d traps %d start %d pulls %d" % [
			m.get("difficulty", 0.0), LevelGenerator.structural_difficulty(m) if not m.is_empty() else 0.0, m.get("depth", 0),
			m.get("decision_points", 0), m.get("trap_moves", 0), r.get("start", 0), m.get("pulls", 0)]) if not m.is_empty() else "-"])
		for p in r["problems"]:
			print("  PROBLEM L%d: %s" % [n, p])
			errors += 1
		if write and r["problems"].is_empty():
			_write(n, map)
	return errors


## The level file: the old level's name, the new map, and the old level's
## exact Silver / Gold blocks put on plain arrows (first in reading order).
func _write(n: int, map: Array) -> void:
	var path := "res://levels/level_%02d.json" % n
	var old = JSON.parse_string(FileAccess.get_file_as_string(path))
	var silver := 0
	var gold := 0
	for row in old["map"]:
		for t in String(row).split(" ", false):
			silver += int(t.contains("$S"))
			gold += int(t.contains("$G"))
	var rows := []
	for row in map:
		var cells := []
		for t in String(row).split(" ", false):
			var plain: bool = t != "." and t.length() == 2
			if plain and gold > 0:
				t += "$G"
				gold -= 1
			elif plain and silver > 0:
				t += "$S"
				silver -= 1
			cells.append(t)
		rows.append(" ".join(cells))
	# The Experience Lab build's format (tools/experience_lab_build.py: key
	# order, aligned columns), so the lab mirror stays byte-identical.
	var text := "{\n\t\"name\": %s,\n\t\"map\": [\n" % JSON.stringify(old["name"])
	var aligned := _aligned(rows)
	for i in aligned.size():
		text += "\t\t%s%s\n" % [JSON.stringify(aligned[i]), "," if i < aligned.size() - 1 else ""]
	text += "\t]\n}\n"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


## Columns padded to the longest token + 1 (experience_lab_build.py fmt).
static func _aligned(rows: Array) -> Array:
	var w := 0
	for r in rows:
		for t in String(r).split(" ", false):
			w = maxi(w, t.length())
	w += 1
	var out := []
	for r in rows:
		var line := ""
		for t in String(r).split(" ", false):
			line += t.rpad(w)
		out.append(line.strip_edges(false, true))
	return out
