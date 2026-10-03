extends SceneTree
## SEQUENCE MECHANIC PROTOTYPE (development only): builds the mechanic lab's
## board file, data/dev/mechlab_sequence.json (?mechlab=sequence).
##
##   godot --headless --path . --script res://tools/mechlab_sequence_build.gd            # check + write
##   godot --headless --path . --script res://tools/mechlab_sequence_build.gd -- --dry   # check + print only
##   godot --headless --path . --script res://tools/mechlab_sequence_build.gd -- --search=timing --seed=1 --count=60
##
## Boards are hand-picked (some found with --search, then fixed here so the
## file is reproducible). Stages: A basics, B timing / order, C spinner
## interaction, D hidden arrows (an existing neighbour-event mechanic),
## E depth. "control": true also builds a matched CONTROL board: every
## Sequence block becomes a plain arrow (its final arrow if that board is
## solvable, else its first arrow) - same size, blocks, spinners, density,
## but no first stage and so no "when do I advance it?" decision - turned
## 180 degrees (rules unchanged) so it does not look like a replay.
##
## Metrics are solver proxies only (the human test decides):
##   early traps  states on the Solver's path where advancing a Sequence
##                block now is legal but makes the board unsolvable
##   late traps   states on the path where the Solver advances, other moves
##                exist, and every one of them makes the board unsolvable
##   spinner / reveal  advances in the solution that turn a spinner /
##                reveal a hidden arrow

const OUT_PATH := "res://data/dev/mechlab_sequence.json"
const ARROW_FLIP := {"^": "v", "v": "^", "<": ">", ">": "<"}

const BOARDS := [
	# --- A: basics ---------------------------------------------------------------
	# Stage 1 -> stage 2: red launches right and comes back pointing up.
	{"id": "A1", "stage": "A", "control": false, "map": [
		".    .  .  .",
		"R>:^ .  .  .",
		".    .  B< .",
		".    G^ .  ."]},
	# Blocked stages: red's first stage (left) waits for blue; its second
	# stage (up) waits for yellow.
	{"id": "A2", "stage": "A", "control": false, "map": [
		".  .    .  .",
		".  Y>   .  .",
		"Bv R<:^ .  .",
		".  .    .  .",
		".  .    G< ."]},
	# --- B: timing / order (when to use the first stage) ---------------------
	{"id": "B1", "stage": "B", "control": true, "map": [
		".  .  B>:v Rv   Rv@",
		".  .  .    .    .",
		".  .  .    G<@  Gv:<",
		".  .  .    .    .",
		"Pv G< .    .    ."]},
	{"id": "B2", "stage": "B", "control": true, "map": [
		"Y>  .    Rv:> .  .",
		".   .    .    G< B<",
		".   .    .    .  .",
		"P^@ Pv:< .    .  .",
		".   .    G>   .  Rv"]},
	{"id": "B3", "stage": "B", "control": true, "map": [
		".   G>   .  .  Bv",
		"B>  .    .  .  Yv:>",
		".   .    B< .  .",
		"G^@ G>:< .  .  .",
		".   .    G^ .  ."]},
	# --- C: spinner interaction ----------------------------------------------
	# Teaching: green (spinner) points down into blue, blue up into green.
	# Red's first stage turns green to the left: the deadlock opens.
	{"id": "C1", "stage": "C", "control": false, "map": [
		".  .    .  .",
		".  R>:^ .  .",
		".  Gv@  .  .",
		"P> B^   .  ."]},
	# Moderate: yellow's first stage turns the spinners next to it.
	{"id": "C2", "stage": "C", "control": false, "map": [
		".  .  .  .    .",
		".  .  .  .    .",
		"B> R> .  Gv@  P^@",
		".  .  .  Y>:v .",
		".  Bv .  B<@  ."]},
	# Deeper: red's first stage turns two spinners; doing it at the wrong
	# moment loses the board.
	{"id": "C3", "stage": "C", "control": true, "map": [
		"Pv@ R>:v .  G> .",
		"G>  Bv@  .  .  .",
		".   .    P> .  .",
		".   B^@  .  .  .",
		".   Bv   .  .  ."]},
	# --- D: hidden arrows (the same neighbour event reveals them) ----------
	{"id": "D1", "stage": "D", "control": false, "map": [
		".  .  .   G^? G^:v",
		".  P> .   .   Bv@",
		".  .  .   .   .",
		".  .  .   .   Yv",
		"Y< .  P<? G^  ."]},
	# --- E: depth ----------------------------------------------------------------
	{"id": "E1", "stage": "E", "control": true, "map": [
		".  B>@  P<  .    G<@ Pv:<",
		"Y^ P>:< .   .    .   Bv",
		".  .    R^@ Y^:> .   .",
		".  .    .   B^   .   .",
		".  .    .   .    .   .",
		"R> .    R^@ .    .   ."]},
	{"id": "E2", "stage": "E", "control": true, "map": [
		".  .  R>  R>  .   R>:v",
		".  .  Y^@ Gv@ .   Yv@",
		".  .  .   .   Y<  .",
		".  .  .   Y>  Bv  .",
		".  .  Y^  .   .   .",
		".  .  .   .   Y>@ Y>:v"]},
]


func _init() -> void:
	LevelManager.dev_sequence = true
	var args := OS.get_cmdline_user_args()
	var search := ""
	var seed := 1
	var count := 40
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
		if not m["errors"].is_empty() or not m["solvable"] or m["sequence"] == 0:
			line += "   <-- FAIL %s" % str(m["errors"])
			failures += 1
		print(line)
		out.append(_record(spec["id"], "sequence", spec["stage"], spec["map"], m, spec["id"]))
		if spec.get("control", false):
			var cmap := control_map(spec["map"])
			var cm := evaluate(cmap)
			var cid := str(spec["id"]) + "_CTRL"
			var cline := "%s [%s] %s" % [cid, spec["stage"], describe(cm)]
			if cmap.is_empty() or not cm["errors"].is_empty() or not cm["solvable"]:
				cline += "   <-- FAIL (no solvable control)"
				failures += 1
			print(cline)
			out.append(_record(cid, "control", spec["stage"], cmap, cm, spec["id"]))
	print("%d boards, %d failures" % [out.size(), failures])
	if failures > 0 or dry:
		return 1 if failures > 0 else 0
	var data := {"format": "ce-mechlab", "v": 1, "mechanic": "sequence",
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
		"metrics": {"blocks": m["blocks"], "sequence_blocks": m["sequence"], "solution": m["sol_len"], "start_moves": m["start"],
			"early_traps": m["early"], "late_traps": m["late"], "spinner_advances": m["spin_adv"], "reveal_advances": m["reveal_adv"],
			"random_win": m["random_win"]}}


## Every Sequence token as a plain arrow (`final`: its NEXT arrow, else its
## first arrow), then the board turned 180 degrees.
static func plain_map(map: Array, final: bool) -> Array:
	var rows := []
	for i in range(map.size() - 1, -1, -1):
		var tokens := String(map[i]).split(" ", false)
		var out := PackedStringArray()
		for j in range(tokens.size() - 1, -1, -1):
			var t := tokens[j]
			if t.contains(":"):
				t = t[0] + (t[t.length() - 1] if final else t[1])
			if t != "." and t[0] != "X":
				t = t[0] + ARROW_FLIP[t[1]] + t.substr(2)
			out.append(t)
		rows.append(" ".join(out))
	return rows


static func control_map(map: Array) -> Array:
	for final in [true, false]:
		var c := plain_map(map, final)
		if evaluate(c)["solvable"]:
			return c
	return []


# --- Metrics (solver proxies) ---------------------------------------------------------

static func _model(map: Array) -> BoardModel:
	var level := LevelManager.parse_level({"map": map})
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	return model


static func _solvable(model: BoardModel) -> bool:
	if model.is_empty():
		return true
	var s := Solver.from_model(model)
	return s.is_solvable() and not s.aborted


static func _play(model: BoardModel, id: int) -> void:
	match model.move_state(id):
		"ok": model.remove(id)
		"advance": model.advance(id)
		"ram": model.ram(id)


static func evaluate(map: Array) -> Dictionary:
	var m := {"errors": [], "solvable": false, "sol_len": 0, "start": 0, "sequence": 0, "early": 0, "late": 0,
		"spin_adv": 0, "reveal_adv": 0, "random_win": 0.0, "blocks": 0}
	var cols: int = String(map[0]).split(" ", false).size()
	var tokens := 0
	for r in map.size():
		var row := String(map[r]).split(" ", false)
		if row.size() != cols:
			m["errors"].append("row %d has %d cells" % [r, row.size()])
		for t in row:
			if t != ".":
				tokens += 1
	var model := _model(map)
	if model.block_count() != tokens:
		m["errors"].append("a cell did not parse")
	m["blocks"] = model.block_count()
	for b in model.blocks.values():
		if b.seq_stage == 1:
			m["sequence"] += 1
	var solver := Solver.from_model(model)
	m["start"] = solver.legal_moves().size()
	var moves := solver.solve_moves()
	m["solvable"] = not moves.is_empty() and not solver.aborted
	m["sol_len"] = moves.size()
	m["random_win"] = snappedf(Solver.from_model(model).random_win_rate(400, 7), 0.001)
	if not m["solvable"]:
		return m
	for mv in moves:
		var id: int = mv & Solver.ID_MASK
		# Early traps: any Sequence block that could advance now but must not.
		for q in model.blocks.keys():
			if q == id or model.move_state(q) != "advance":
				continue
			var test := _copy(model)
			test.advance(q)
			if not _solvable(test):
				m["early"] += 1
		var st := model.move_state(id)
		if st == "advance":
			# Late trap: every other legal move now loses.
			var others := 0
			var all_lose := true
			for o in model.playable_ids():
				if o == id:
					continue
				others += 1
				var test := _copy(model)
				_play(test, o)
				if _solvable(test):
					all_lose = false
					break
			if others > 0 and all_lose:
				m["late"] += 1
			var turned := model.advance(id)
			if not turned.is_empty():
				m["spin_adv"] += 1
			if not model.last_revealed.is_empty():
				m["reveal_adv"] += 1
		else:
			_play(model, id)
	return m


static func _copy(model: BoardModel) -> BoardModel:
	var t := BoardModel.new()
	t.setup(model.rows, model.columns, model.snapshot())
	return t


static func describe(m: Dictionary) -> String:
	return "blocks %d  seq %d  solvable %s  solution %d  start %d  early-traps %d  late-traps %d  spinner-adv %d  reveal-adv %d  random win %.2f" % [
		m["blocks"], m["sequence"], m["solvable"], m["sol_len"], m["start"], m["early"], m["late"], m["spin_adv"], m["reveal_adv"], m["random_win"]]


# --- Search (design aid; prints candidates, writes nothing) ------------------------------

## Profiles: size, blocks, spinners, Sequence blocks, hidden arrows.
const PROFILES := {
	"timing": {"size": Vector2i(5, 5), "blocks": Vector2i(7, 9), "spin": Vector2i(1, 2), "seq": Vector2i(1, 2), "hidden": 0},
	"spinner": {"size": Vector2i(5, 5), "blocks": Vector2i(6, 9), "spin": Vector2i(2, 3), "seq": Vector2i(1, 1), "hidden": 0},
	"hidden": {"size": Vector2i(5, 5), "blocks": Vector2i(7, 9), "spin": Vector2i(1, 2), "seq": Vector2i(1, 2), "hidden": 2},
	"deep": {"size": Vector2i(6, 6), "blocks": Vector2i(11, 14), "spin": Vector2i(3, 4), "seq": Vector2i(2, 3), "hidden": 0},
}


func _search(profile: String, seed: int, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var p: Dictionary = PROFILES[profile]
	var found := 0
	var seen := {}
	for restart in count:
		var map := _random_board(rng, p)
		var m := evaluate(map)
		var score := _score(m, profile)
		for it in 160:
			var cand := _mutate(map, rng)
			var cm := evaluate(cand)
			var cs := _score(cm, profile)
			if cs >= score:
				map = cand
				m = cm
				score = cs
			if _good(m, profile) and not _same_twice(map) and not seen.has(str(map)):
				seen[str(map)] = true
				var ctrl_map := control_map(map)
				if ctrl_map.is_empty():
					continue
				var ctrl := evaluate(ctrl_map)
				found += 1
				print("--- candidate %d (restart %d)  sequence: %s" % [found, restart, describe(m)])
				print("    control: %s" % describe(ctrl))
				for row in map:
					print("    \"%s\"," % row)
				if found >= 8:
					return
				break


## A Sequence block whose NEXT arrow equals its arrow would read as "tap it
## twice": the lab boards never use one.
static func _same_twice(map: Array) -> bool:
	for row in map:
		for t in String(row).split(" ", false):
			if t.contains(":") and t[1] == t[t.length() - 1]:
				return true
	return false


static func _good(m: Dictionary, profile: String) -> bool:
	if not m["errors"].is_empty() or not m["solvable"] or m["start"] > 3 or m["random_win"] > 0.4 or m["random_win"] < 0.01:
		return false
	match profile:
		"timing":
			return m["early"] >= 1 and m["late"] >= 1
		"spinner":
			return m["spin_adv"] >= 1 and (m["early"] + m["late"]) >= 1
		"hidden":
			return m["reveal_adv"] >= 1 and (m["early"] + m["late"]) >= 1
		"deep":
			return m["early"] >= 2 and m["late"] >= 1 and m["spin_adv"] >= 1
	return false


static func _score(m: Dictionary, profile: String) -> float:
	if not m["errors"].is_empty():
		return -1000.0
	if not m["solvable"]:
		return 0.0
	var s: float = 100.0 + mini(m["early"], 3) * 10.0 + mini(m["late"], 2) * 12.0 + (1.0 - m["random_win"]) * 30.0
	s -= maxi(0, m["start"] - 3) * 8.0
	if profile in ["spinner", "deep"]:
		s += mini(m["spin_adv"], 2) * 10.0
	if profile == "hidden":
		s += mini(m["reveal_adv"], 2) * 10.0
	return s


func _random_board(rng: RandomNumberGenerator, p: Dictionary) -> Array:
	var size: Vector2i = p["size"]
	var grid := []
	for r in size.y:
		var row := []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	var colors := ["R", "B", "G", "Y", "P"]
	var arrows := ["^", "v", "<", ">"]
	var n: int = rng.randi_range(p["blocks"].x, p["blocks"].y)
	var n_spin: int = rng.randi_range(p["spin"].x, p["spin"].y)
	var n_seq: int = rng.randi_range(p["seq"].x, p["seq"].y)
	var n_hid: int = p["hidden"]
	for i in n:
		var t: String = colors[rng.randi_range(0, 4)] + arrows[rng.randi_range(0, 3)]
		if i < n_seq:
			t += ":" + arrows.filter(func(a): return a != t[1])[rng.randi_range(0, 2)]
		elif i < n_seq + n_spin:
			t += "@"
		elif i < n_seq + n_spin + n_hid:
			t += "?"
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
	var blocks := []
	var empty := []
	for r in grid.size():
		for c in grid[0].size():
			if grid[r][c] == ".":
				empty.append(Vector2i(c, r))
			else:
				blocks.append(Vector2i(c, r))
	var arrows := ["^", "v", "<", ">"]
	var kind := rng.randi_range(0, 9)
	var b: Vector2i = blocks[rng.randi_range(0, blocks.size() - 1)]
	var t: String = grid[b.y][b.x]
	if kind <= 3:
		grid[b.y][b.x] = t[0] + arrows[rng.randi_range(0, 3)] + t.substr(2)
	elif kind <= 5 and t.contains(":"):
		grid[b.y][b.x] = t.substr(0, t.length() - 1) + arrows.filter(func(a): return a != t[1])[rng.randi_range(0, 2)]
	elif not empty.is_empty():
		var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
		grid[e.y][e.x] = t
		grid[b.y][b.x] = "."
	var out := []
	for row in grid:
		out.append(" ".join(row))
	return out
