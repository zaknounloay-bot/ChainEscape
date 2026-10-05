extends SceneTree
## v0.7 Third Era, the PORTAL arc: builds levels 201-225 and writes
## res://levels/level_N.json.
##
##   godot --headless --path . --script res://tools/generate_portal_arc.gd -- --from=201 --to=225 [--seed=1] [--tries=40] [--write]
##
## Every slot has a SPEC: board size, block count, portal pairs, which older
## mechanic (at most two families) it may use, a difficulty band and the
## IDEA it must show, as a solver-checkable "need" (e.g. "remote": a portal
## lane blocked on the far side at the start; "trap_start": a portal move
## that is available at the start and loses). Boards are found by hill
## climbing from random boards (mutate, keep if not worse); a board is
## accepted only if it meets its need, sits in its band, passes every
## campaign rule of tools/verify_levels.gd (the same functions), the armor
## audit, and is not similar to any existing board. Among accepted boards
## the one nearest the band's centre wins. Then name, lesson text and
## Silver / Gold (REWARDS, placed by LevelGenerator.assign_reward_blocks).
## Without --write nothing is saved (dry run). tools/verify_levels.gd then
## re-checks the whole campaign.
##
## Levels 1-200 are never touched (slots outside 201-225 are refused).

const Verify := preload("res://tools/verify_levels.gd")

const ARC_FROM := 201
const ARC_TO := 225

## Breathers (209 / 215 / 220) are easier on purpose; 225 is the arc's
## milestone and must beat every other arc level (checked by the verifier).
const SPECS := {
	# --- Learn -------------------------------------------------------------
	201: {"name": "First Portal", "size": Vector2i(5, 5), "blocks": [5, 6], "diff": [6.0, 9.0], "need": ["essential"],
		"hint": "New: PORTAL. Blocks go in one A and come out the other A."},
	202: {"name": "Same Way Out", "size": Vector2i(5, 5), "blocks": [7, 9], "diff": [7.0, 10.5], "need": ["essential", "dirs2"],
		"hint": "Out of a portal, a block keeps moving the same way."},
	203: {"name": "Far Side", "size": Vector2i(5, 5), "blocks": [7, 9], "diff": [8.0, 12.0], "need": ["essential", "remote"],
		"hint": "Look past the portal: a block there stops the way out."},
	204: {"name": "Take Turns", "size": Vector2i(5, 6), "blocks": [8, 10], "diff": [8.5, 12.5], "need": ["essential", "shared", "remote"],
		"hint": "Two blocks, one portal: choose who goes first."},
	205: {"name": "Through and Back", "size": Vector2i(6, 6), "blocks": [10, 13], "spin": [1, 1], "diff": [11.0, 17.0], "need": ["essential", "pm3"]},
	# --- Apply -------------------------------------------------------------
	206: {"name": "Far Wall", "size": Vector2i(6, 6), "blocks": [12, 14], "spin": [2, 3], "diff": [27.0, 32.0], "need": ["remote2", "pm2"]},
	207: {"name": "Turning Door", "size": Vector2i(6, 6), "blocks": [12, 14], "spin": [2, 3], "diff": [30.0, 35.0], "need": ["spinner_portal", "pm2"]},
	208: {"name": "Unseen Exit", "size": Vector2i(6, 6), "blocks": [12, 14], "spin": [1, 2], "hidden": [2, 2], "diff": [31.0, 37.0], "need": ["hidden_portal", "pm2"]},
	209: {"name": "Open Doors", "size": Vector2i(6, 6), "blocks": [11, 13], "spin": [2, 3], "diff": [23.0, 27.0], "need": ["pm2"], "breather": true},
	210: {"name": "Both Sides", "size": Vector2i(6, 6), "blocks": [13, 15], "spin": [2, 3], "diff": [34.0, 40.0], "need": ["two_way", "pm3"]},
	211: {"name": "Locked Passage", "size": Vector2i(6, 6), "blocks": [16, 18], "spin": [2, 3], "lock": true, "diff": [38.0, 43.0], "need": ["lock_portal", "pm2"]},
	212: {"name": "Counterturn", "size": Vector2i(6, 6), "blocks": [16, 18], "spin": [3, 4], "rules": ["@-", "@~"], "diff": [40.0, 45.0], "need": ["spinner_portal", "pm2"]},
	# --- Apply: two pairs ----------------------------------------------------
	213: {"name": "Twin Doors", "size": Vector2i(6, 6), "blocks": [16, 18], "pairs": 2, "spin": [3, 4], "diff": [42.0, 47.0], "need": ["two_pairs", "pm3"],
		"hint": "Two portal pairs: A leads to A, B leads to B."},
	214: {"name": "Which Way First", "size": Vector2i(6, 7), "blocks": [18, 20], "spin": [3, 4], "diff": [44.0, 49.0], "need": ["trap", "shared", "pm3"]},
	215: {"name": "Easy Passage", "size": Vector2i(6, 6), "blocks": [15, 17], "pairs": 2, "spin": [2, 3], "diff": [34.0, 38.0], "need": ["two_pairs"], "breather": true},
	# --- Master / interact --------------------------------------------------------
	216: {"name": "Mirror Door", "size": Vector2i(6, 7), "blocks": [18, 20], "spin": [2, 3], "switch": true, "diff": [45.0, 50.0], "need": ["switch_portal", "pm2"]},
	217: {"name": "Chain Door", "size": Vector2i(6, 7), "blocks": [18, 20], "spin": [3, 4], "gate": true, "diff": [46.0, 51.0], "need": ["gate_portal", "pm2"]},
	218: {"name": "Shell Shot", "size": Vector2i(6, 7), "blocks": [18, 20], "spin": [3, 4], "armor": true, "diff": [46.0, 52.0], "need": ["armor_portal", "pm2"]},
	219: {"name": "Long Way Round", "size": Vector2i(7, 7), "blocks": [20, 23], "spin": [4, 5], "diff": [50.0, 56.0], "need": ["remote", "pm4"]},
	220: {"name": "Clear Flow", "size": Vector2i(6, 7), "blocks": [17, 19], "pairs": 2, "spin": [3, 4], "diff": [38.0, 42.0], "need": ["pm4", "two_pairs"], "breather": true},
	221: {"name": "Crossroads", "size": Vector2i(7, 7), "blocks": [20, 23], "pairs": 2, "spin": [4, 5], "diff": [52.0, 57.0], "need": ["two_pairs", "two_way", "pm4"]},
	222: {"name": "Old Friends", "size": Vector2i(7, 7), "blocks": [19, 22], "switch": true, "gate": true, "diff": [53.0, 58.0], "need": ["switch_portal", "gate_portal", "pm3"]},
	223: {"name": "False Door", "size": Vector2i(7, 7), "blocks": [20, 23], "spin": [4, 5], "diff": [54.0, 59.0], "need": ["trap_start", "pm3"]},
	224: {"name": "Threshold", "size": Vector2i(7, 7), "blocks": [21, 24], "pairs": 2, "spin": [4, 5], "diff": [55.0, 60.0], "need": ["two_pairs", "pm4"]},
	225: {"name": "The Gateway", "size": Vector2i(7, 7), "blocks": [22, 25], "pairs": 2, "spin": [4, 6], "rules": ["@", "@-"], "diff": [61.0, 75.0],
		"seed_from": [224, 221, 219], "need": ["two_pairs", "two_way", "pm5", "trap"], "hint": "Milestone. Plan the whole route through both portals."},
}

## Silver / Gold per level: Chapter 21 3S 1G (like Chapter 11, the lessons
## have none), Chapter 22 5S 3G, Chapter 23 (221-225) 3S 2G.
const REWARDS := {
	206: [1, 0], 208: [0, 1], 209: [1, 0], 210: [1, 0],
	211: [0, 1], 212: [1, 0], 213: [1, 1], 215: [1, 0], 217: [1, 0], 219: [1, 1],
	221: [1, 0], 222: [0, 1], 224: [1, 0], 225: [1, 1],
}

const COLORS := ["R", "B", "G", "Y", "P"]
const ARROWS := ["^", "v", "<", ">"]

var rng := RandomNumberGenerator.new()
var known: Array = []  # LevelData of every other existing level (similarity)
var arc_struct := {}  # structural difficulty of arc levels written so far
var stats := {}  # why boards were rejected (printed with --stats)


func _initialize() -> void:
	var args := {"from": str(ARC_FROM), "to": str(ARC_TO), "seed": "1", "tries": "40", "climb": "220"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var write := "--write" in OS.get_cmdline_user_args()
	Solver.default_limit = 40000
	var from := int(args["from"])
	var to := int(args["to"])
	if from < ARC_FROM or to > ARC_TO:
		printerr("generate_portal_arc: only levels %d-%d" % [ARC_FROM, ARC_TO])
		quit(1)
		return
	var failed := 0
	for n in range(from, to + 1):
		_load_known(n)
		rng.seed = hash([int(args["seed"]), n])
		var t0 := Time.get_ticks_msec()
		var best := _build_slot(n, int(args["tries"]), int(args["climb"]))
		if best.is_empty():
			printerr("L%d: no board found" % n)
			failed += 1
			continue
		var level: LevelData = best["level"]
		var m: Dictionary = best["m"]
		print("L%d %-16s %dx%d blk %d diff %.1f struct %.1f start %d depth %d dec %d len %d  portal pm%d cells%d groups%d imp %s  (%ds)" % [
			n, level.name, level.columns, level.rows, m["blocks"], m["difficulty"], LevelGenerator.structural_difficulty(m),
			m["start_moves"], m["depth"], m["decision_points"], m["solution_length"], m["portal_moves"], m["portal_cells_entered"],
			m["portal_groups_used"], str(m["portal_impact"]), (Time.get_ticks_msec() - t0) / 1000])
		var text := LevelManager.to_json_text(level)
		print(text)
		if write:
			var f := FileAccess.open(LevelManager.LEVEL_PATH % n, FileAccess.WRITE)
			f.store_string(text)
			f.close()
	quit(1 if failed > 0 else 0)


func _load_known(skip: int) -> void:
	known.clear()
	arc_struct.clear()
	var n := 1
	while FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
		if n != skip:
			var lv := LevelManager.read_level(n)
			known.append(lv)
			if n >= ARC_FROM and n < ARC_TO:
				var m := LevelAnalysis.analyze(lv, false)
				arc_struct[n] = [m["difficulty"], LevelGenerator.structural_difficulty(m)]
		n += 1


# --- One slot -------------------------------------------------------------------

func _build_slot(n: int, tries: int, climb: int) -> Dictionary:
	var spec: Dictionary = SPECS[n]
	var lo: float = spec["diff"][0]
	var hi: float = spec["diff"][1]
	var best := {}
	var best_err := INF
	for t in tries:
		var map := _random_board(spec) if not spec.has("seed_from") else _seed_board(spec)
		var e := _cheap(n, map, spec)
		var score := _score(e, spec)
		for it in climb:
			var cand := _mutate(map, spec)
			var ce := _cheap(n, cand, spec)
			var cs := _score(ce, spec)
			if cs >= score:
				map = cand
				e = ce
				score = cs
			if e["ok"]:
				break
		if not e["ok"]:
			_stat("climb: miss %d shape %.1f dist %.1f solvable %s" % [e["miss"], e["shape"], e["dist"], e["solvable"]])
			continue
		var full := _accept(n, map, spec)
		if full.is_empty():
			continue
		var d: float = full["m"]["difficulty"]
		var err := absf(d - (lo + hi) * 0.5)
		if err < best_err:
			best_err = err
			best = full
			print("  L%d try %d: diff %.1f" % [n, t, d])
	if "--stats" in OS.get_cmdline_user_args():
		print("  L%d rejects: %s" % [n, str(stats)])
	stats.clear()
	return best


func _stat(k: String) -> void:
	stats[k] = stats.get(k, 0) + 1


## Fast checks for the climb (no impacts): the idea, the band and the
## late-game shape. "ok" = worth a full check.
func _cheap(n: int, map: Array, spec: Dictionary) -> Dictionary:
	var e := {"ok": false, "valid": false, "solvable": false, "miss": 0, "dist": 0.0, "shape": 0.0, "pm": 0, "sim": 0.0}
	var level := _parse(n, map, spec)
	if level == null:
		return e
	e["valid"] = true
	e["sim"] = 0.0
	for other in known:
		if other.rows == level.rows and other.columns == level.columns:
			e["sim"] = maxf(e["sim"], LevelGenerator.similarity(level, other))
	var m := LevelAnalysis.analyze(level, false)
	if not m["solvable"] or m["aborted"]:
		return e
	e["solvable"] = true
	e["pm"] = m["portal_moves"]
	var lo: float = spec["diff"][0]
	var hi: float = spec["diff"][1]
	var d: float = m["difficulty"]
	e["dist"] = maxf(0.0, lo - d) + maxf(0.0, d - hi)
	var lesson := n <= ARC_FROM + 4
	var shape := 0.0
	if lesson:
		shape += maxi(0, m["start_moves"] - 3) * 1.0 + maxi(0, 3 - m["depth"]) * 1.0
	else:
		shape += maxi(0, m["start_moves"] - 2) * 1.0 + maxi(0, 8 - m["depth"]) * 0.5 + maxi(0, 4 - m["decision_points"]) * 0.5
		shape += (0.0 if m["directions_used"] == 4 else 1.0) + maxf(0.0, m["direction_share"] - 0.45) * 10.0
	e["shape"] = shape
	var info := _interactions(level, m)
	var miss := 0
	for need in spec["need"]:
		if need == "essential" or need == "trap" or need == "trap_start":
			continue  # checked in _accept (they need extra solves)
		if not _need_ok(need, info, m):
			miss += 1
	e["miss"] = miss
	e["ok"] = miss == 0 and shape == 0.0 and e["dist"] == 0.0 and e["sim"] <= Verify.MAX_SIMILARITY
	return e


func _score(e: Dictionary, spec: Dictionary) -> float:
	if not e["valid"]:
		return -1000.0
	if not e["solvable"]:
		return -500.0
	return 100.0 - e["miss"] * 15.0 - e["shape"] * 6.0 - e["dist"] * 2.0 + mini(e["pm"], 5) * 1.0 \
		- maxf(0.0, e["sim"] - Verify.MAX_SIMILARITY) * 100.0


## Full acceptance: every campaign rule (the verifier's own functions), the
## extra-solve needs, armor safety, similarity, and the 225 milestone rule.
func _accept(n: int, map: Array, spec: Dictionary) -> Dictionary:
	var level := _parse(n, map, spec)
	if level == null:
		return {}
	var m := LevelAnalysis.analyze(level)
	if not m["solvable"] or m["aborted"]:
		_stat("full analysis gave up")
		return {}
	var issue := Verify._rule_issue(n, m)
	if issue != "":
		_stat(issue)
		return {}
	if "essential" in spec["need"] and m["portal_impact"] < LevelAnalysis.ESSENTIAL:
		_stat("not essential")
		return {}
	if "trap" in spec["need"] and _portal_traps(level, false) == 0:
		_stat("no trap")
		return {}
	if "trap_start" in spec["need"] and _portal_traps(level, true) == 0:
		_stat("no start trap")
		return {}
	if m["armored"] > 0 and not _armor_safe(level):
		_stat("armor unsafe")
		return {}
	for other in known:
		if other.rows == level.rows and other.columns == level.columns and LevelGenerator.similarity(level, other) > Verify.MAX_SIMILARITY:
			_stat("similar")
			return {}
	if n == ARC_TO:
		var s := LevelGenerator.structural_difficulty(m)
		for k in arc_struct:
			if m["difficulty"] <= arc_struct[k][0] + 2.0 or s <= arc_struct[k][1] + 2.0:
				_stat("not above L%d" % k)
				return {}
	# Name, lesson text, rewards (never changes solvability).
	var gen := LevelGenerator.new(hash([n, 7]))
	var rw: Array = REWARDS.get(n, [0, 0])
	gen.assign_reward_blocks(level, rw[0], rw[1])
	if Verify._reward_issue(n, level) != "":
		_stat("reward issue")
		return {}
	var got := Verify._reward_text(level)
	if got.count("S") != rw[0] or got.count("G") != rw[1]:
		_stat("rewards not placed")
		return {}
	return {"level": level, "m": m}


func _parse(n: int, map: Array, spec: Dictionary) -> LevelData:
	var json := {"name": spec["name"], "map": map}
	if spec.has("hint"):
		json["hint"] = spec["hint"]
		json["hint_finger"] = false
	if spec.get("hidden", [0, 0])[1] > 0:
		json["mystery"] = true
	var groups := {}
	for r in map.size():
		var tokens := String(map[r]).split(" ", false)
		for c in tokens.size():
			if tokens[c].begins_with(Portals.TOKEN_PREFIX):
				groups[Vector2i(c, r)] = tokens[c].substr(1)
	if not Portals.layout_errors(map.size(), String(map[0]).split(" ", false).size(), groups).is_empty():
		return null  # a lane could loop: the parser would drop the portals
	# Readability: the two cells of a pair are never in the same row or
	# column and never next to each other (not even diagonally).
	for a in groups:
		for b in groups:
			if a != b and groups[a] == groups[b] and (a.x == b.x or a.y == b.y or (absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1)):
				return null
	var level := LevelManager.parse_level(json, n)
	if level.portals.size() != spec.get("pairs", 1) * 2:
		return null
	return level


# --- What the board does with its portals -----------------------------------------------

func _interactions(level: LevelData, m: Dictionary) -> Dictionary:
	var info := {"remote": 0, "gate_lane": false, "spinner": false, "hidden": false, "lock": false,
		"switch": false, "ram": false, "shared": false, "dirs": {}}
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	model.set_portals(level.portals)
	var hidden_ids := {}
	var locks := {}
	for b in level.blocks:
		if b.lock_color != "":
			locks[b.lock_color] = true
	for id in model.blocks:
		var b: BlockData = model.blocks[id]
		if b.hidden:
			hidden_ids[id] = true
		var ln := model.lane(id)
		if not ln["via"].is_empty() and ln["blocker"] != null:
			if ln["blocker"].is_gate():
				info["gate_lane"] = true
			elif model.move_state(id) != "ram" and not b.is_gate():
				info["remote"] += 1
	var entries := {}
	for id in m["solution"]:
		var b: BlockData = model.blocks[id]
		var ln := model.lane(id)
		var ram := model.move_state(id) == "ram"
		if not ln["via"].is_empty():
			info["dirs"][b.direction] = true
			var cell: Vector2i = ln["via"][0][0]
			entries[cell] = entries.get(cell, 0) + 1
			if entries[cell] >= 2:
				info["shared"] = true
			if b.is_spinner():
				info["spinner"] = true
			if hidden_ids.has(id):
				info["hidden"] = true
			if b.lock_color != "" or locks.has(b.color):
				info["lock"] = true  # a locked block, or its key, goes through a portal
			if b.is_switch() or b.flip_link != "":
				info["switch"] = true
			if ram:
				info["ram"] = true
		if ram:
			model.ram(id)
		else:
			model.remove(id)
	return info


func _need_ok(need: String, info: Dictionary, m: Dictionary) -> bool:
	match need:
		"dirs2":
			return info["dirs"].size() >= 2
		"remote":
			return info["remote"] >= 1
		"remote2":
			return info["remote"] >= 2
		"shared":
			return info["shared"]
		"two_way":
			return m["portal_cells_entered"] == m["portal_pairs"] * 2
		"two_pairs":
			return m["portal_groups_used"] >= 2
		"spinner_portal":
			return info["spinner"]
		"hidden_portal":
			return info["hidden"]
		"lock_portal":
			return info["lock"]
		"switch_portal":
			return info["switch"]
		"gate_portal":
			return info["gate_lane"]
		"armor_portal":
			return info["ram"]
	if need.begins_with("pm"):
		return m["portal_moves"] >= int(need.substr(2))
	return false


## Losing portal moves: legal moves through a portal that leave the board
## unsolvable - at the start only, or anywhere along the solver's solution.
func _portal_traps(level: LevelData, start_only: bool) -> int:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	model.set_portals(level.portals)
	var path := Solver.from_model(model).solve()
	var traps := 0
	for step in path.size():
		for id in model.blocks.keys():
			var st := model.move_state(id)
			if (st != "ok" and st != "ram") or model.lane(id)["via"].is_empty():
				continue
			var snap := model.snapshot()
			if st == "ram":
				model.ram(id)
			else:
				model.remove(id)
			var s := Solver.from_model(model)
			if not s.is_solvable() and not s.aborted:
				traps += 1
			model.restore(snap)
		if start_only:
			break
		var mv: int = path[step]
		if model.move_state(mv) == "ram":
			model.ram(mv)
		else:
			model.remove(mv)
	return traps


func _armor_safe(level: LevelData) -> bool:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	model.set_portals(level.portals)
	var r := Solver.from_model(model).armor_audit()
	return r["complete"] and r["armor_dead_ends"] == 0


# --- Random boards and mutations ----------------------------------------------------------

func _random_board(spec: Dictionary) -> Array:
	var size: Vector2i = spec["size"]
	var grid := []
	for r in size.y:
		var row := []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	for g in ["A", "B"].slice(0, spec.get("pairs", 1)):
		var a := _free(grid, size)
		var b := a
		while b.x == a.x or b.y == a.y or grid[b.y][b.x] != ".":
			b = Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		grid[a.y][a.x] = "O" + g
		grid[b.y][b.x] = "O" + g
	var n_blocks := rng.randi_range(spec["blocks"][0], spec["blocks"][1])
	var spin: Array = spec.get("spin", [0, 0])
	var n_spin := rng.randi_range(spin[0], spin[1])
	var rules: Array = spec.get("rules", ["@"])
	var tokens := []
	for i in n_blocks:
		tokens.append(COLORS[rng.randi_range(0, 4)] + ARROWS[rng.randi_range(0, 3)])
	var k := 0
	for i in n_spin:
		tokens[k] += rules[i % rules.size()]
		k += 1
	for i in spec.get("hidden", [0, 0])[0]:
		tokens[k] += "?"
		k += 1
	if spec.get("lock", false):
		var key := String(tokens[k + 1])[0]
		var col: String = COLORS[(COLORS.find(key) + 1 + rng.randi_range(0, 3)) % 5]
		tokens[k] = col + String(tokens[k])[1] + "#" + key
		k += 2
	if spec.get("switch", false):
		tokens[k] += "%A"
		tokens[k + 1] += "&A"
		tokens[k + 2] += "&A"
		k += 3
	if spec.get("gate", false):
		tokens.append("XC")
		tokens[k] += "+C"
		tokens[k + 1] += "+C"
		k += 2
	if spec.get("armor", false):
		tokens[k] += "="
		k += 1
	for t in tokens:
		var c := _free(grid, size)
		grid[c.y][c.x] = t
	return _rows(grid)


## The milestone grows out of an earlier arc board (a random one of
## `seed_from`, Silver / Gold removed): the climb then has to move it far
## enough to pass the similarity rule (penalised in _score) and beat every
## arc level.
func _seed_board(spec: Dictionary) -> Array:
	var from: Array = spec["seed_from"]
	var n: int = from[rng.randi_range(0, from.size() - 1)]
	var json = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n))
	var out := []
	for row in json["map"]:
		var cells := PackedStringArray()
		for t in String(row).split(" ", false):
			cells.append(t.replace("$S", "").replace("$G", ""))
		out.append(" ".join(cells))
	return out


func _free(grid: Array, size: Vector2i) -> Vector2i:
	while true:
		var c := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		if grid[c.y][c.x] == ".":
			return c
	return Vector2i.ZERO


func _rows(grid: Array) -> Array:
	var out := []
	for row in grid:
		out.append(" ".join(PackedStringArray(row)))
	return out


func _mutate(map: Array, spec: Dictionary) -> Array:
	var grid := []
	for row in map:
		grid.append(Array(String(row).split(" ", false)))
	var rows := grid.size()
	var cols: int = grid[0].size()
	var blocks := []
	var empty := []
	var portals := []
	for r in rows:
		for c in cols:
			var t: String = grid[r][c]
			if t == ".":
				empty.append(Vector2i(c, r))
			elif t.begins_with("O"):
				portals.append(Vector2i(c, r))
			elif not t.begins_with("X"):
				blocks.append(Vector2i(c, r))
	var kind := rng.randi_range(0, 11)
	if kind <= 4 and not blocks.is_empty():
		# New arrow.
		var b: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
		var t: String = grid[b.y][b.x]
		grid[b.y][b.x] = t[0] + ARROWS[rng.randi_range(0, 3)] + t.substr(2)
	elif kind <= 7 and not empty.is_empty():
		# Move a block or a gate.
		var movable := blocks.duplicate()
		for r in rows:
			for c in cols:
				if String(grid[r][c]).begins_with("X"):
					movable.append(Vector2i(c, r))
		var b: Vector2i = movable[rng.randi_range(0, movable.size() - 1)]
		var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
		grid[e.y][e.x] = grid[b.y][b.x]
		grid[b.y][b.x] = "."
	elif kind == 8 and not blocks.is_empty():
		# New colour (keeps every modifier; a lock never keys on itself).
		var b: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
		var t: String = grid[b.y][b.x]
		var col: String = COLORS[rng.randi_range(0, 4)]
		if not t.contains("#" + col):
			grid[b.y][b.x] = col + t.substr(1)
	elif kind == 9 and not blocks.is_empty() and not empty.is_empty():
		# Add or remove a plain block (inside the block range).
		var count := blocks.size()
		if rng.randf() < 0.5 and count < spec["blocks"][1]:
			var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
			grid[e.y][e.x] = COLORS[rng.randi_range(0, 4)] + ARROWS[rng.randi_range(0, 3)]
		elif count > spec["blocks"][0]:
			var b: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
			if String(grid[b.y][b.x]).length() == 2:
				grid[b.y][b.x] = "."
	elif not empty.is_empty() and not portals.is_empty():
		# Move one portal cell (layouts that could loop are rejected by the parser).
		var p: Vector2i = portals[rng.randi_range(0, portals.size() - 1)]
		var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
		grid[e.y][e.x] = grid[p.y][p.x]
		grid[p.y][p.x] = "."
	return _rows(grid)
