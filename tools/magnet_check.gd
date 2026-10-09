extends Node
## MAGNET prototype checks (development only, ?mechlab=magnet):
##   godot --headless --path . res://tools/MagnetCheck.tscn
## A. The "*" token is parsed ONLY in the Magnet lab (LevelManager.dev_magnet):
##    campaign level files, Social / Friend Challenge puzzles reject it; no
##    campaign level file uses it. Invalid magnets are dropped.
## B. BoardModel rule cases: pull into the vacated cell, nothing behind,
##    a gate / twin behind stops it, an adjacent spinner turns first and is
##    then pulled, the preview (pull_target) is exactly what happens, Undo
##    (snapshot / restore) puts everything back.
## C. Solver = BoardModel: on random magnet boards the Solver's verdict
##    matches an exhaustive BoardModel search, its legal moves match, its
##    solution replays move for move, and every _do / _undo_move restores
##    the state key exactly.
## D. The lab's three boards (data/dev/mechlab_magnet.json) are the build
##    tool's, solvable, need their magnets, and the lab is configured.

var failures: Array[String] = []
var passed := 0
## Sections that ran to their end (a script error would stop one silently).
var _done: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		print("ok: " + what)
	else:
		failures.append(what)
		print("FAIL: " + what)


func _ready() -> void:
	_gating()
	LevelManager.dev_magnet = true
	_validation()
	_rules()
	_solver_fuzz()
	_lab()
	_check(_done == ["gating", "validation", "rules", "solver", "lab"], "every section ran to its end (%s)" % [_done])
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	print("MAGNET CHECKS PASSED" if failures.is_empty() else "MAGNET CHECKS FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


static func _model(map: Array, campaign := false) -> BoardModel:
	var level := LevelManager.parse_level({"name": "m", "map": map}, 1, campaign)
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	return m


static func _at(m: BoardModel, c: int, r: int) -> BlockData:
	return m.block_at(Vector2i(c, r))


# --- A ------------------------------------------------------------------------------

func _gating() -> void:
	LevelManager.dev_magnet = false
	var camp := LevelManager.parse_level({"name": "c", "map": ["R^* .", ". B>"]}, 1, true)
	_check(camp.blocks.size() == 1 and not camp.blocks.any(func(b): return b.magnet), "campaign parsing rejects the Magnet token (%d blocks)" % camp.blocks.size())
	var social := LevelManager.parse_level({"name": "s", "map": ["R^* .", ". B>"]})
	_check(social.blocks.size() == 1, "Social / Friend parsing rejects the Magnet token")
	var def := PuzzleDefinition.from_dict({"format": PuzzleDefinition.FORMAT, "v": PuzzleDefinition.VERSION, "rules": PuzzleDefinition.RULES,
		"rows": 2, "cols": 2, "map": ["R^* .", ". B>"]})
	_check(def != null and not def.verify(), "a Friend Challenge puzzle with a magnet never verifies")
	_check(LevelManager.parse_level({"name": "p", "map": ["R>@* ."]}).blocks[0].is_spinner(), "'@*' is still a PATTERN spinner, not a magnet")
	var bad := 0
	var dir := DirAccess.open("res://levels")
	for f in dir.get_files():
		if not f.ends_with(".json"):
			continue
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://levels/" + f))
		for row in j.get("map", []):
			for t in String(row).split(" ", false):
				if t.ends_with("*") and not t.ends_with("@*"):
					bad += 1
	_check(bad == 0, "no campaign level file uses the Magnet token (%d found)" % bad)
	_done.append("gating")


func _validation() -> void:
	var hidden := LevelManager.parse_level({"name": "v", "map": ["R^?* .", ". B>"]})
	_check(not hidden.blocks.any(func(b): return b.magnet), "a hidden magnet is dropped")
	var portal := LevelManager.parse_level({"name": "v", "map": ["R^* OA", "OA B>"]})
	_check(not portal.blocks.any(func(b): return b.magnet), "a magnet on a portal board is dropped")
	var ok := LevelManager.parse_level({"name": "v", "map": ["R^* .", ". B>"]})
	_check(ok.blocks[0].magnet, "a plain arrow with '*' is a magnet in the lab")
	_check(LevelManager.to_json_text(ok).contains("R^*"), "the magnet survives the JSON round trip")
	_done.append("validation")


# --- B ------------------------------------------------------------------------------

func _rules() -> void:
	# Pull into the vacated cell.
	var m := _model([". R^* .", ". .   .", ". B>  ."])
	var mag := _at(m, 1, 0).id
	var blue := _at(m, 1, 2).id
	var preview := m.pull_target(mag)
	_check(preview.get("block", -1) == blue and preview["from"] == Vector2i(1, 2) and preview["to"] == Vector2i(1, 0), "preview: blue (1,2) -> (1,0)")
	var snap := m.snapshot()
	m.remove(mag)
	_check(m.blocks[blue].cell == Vector2i(1, 0) and _at(m, 1, 2) == null and m.last_pull == {"block": blue, "from": Vector2i(1, 2), "to": Vector2i(1, 0)},
		"the block behind slides into the magnet's cell (%s)" % [m.last_pull])
	_check(m.blocks[blue].direction == Direction.RIGHT, "a pulled block keeps its arrow")
	m.restore(snap)
	_check(m.blocks.has(mag) and m.blocks[blue].cell == Vector2i(1, 2), "Undo (restore) puts the magnet and the pulled block back")
	# Nothing behind.
	m = _model([". . .", ". R>* .", ". . ."])
	m.remove(_at(m, 1, 1).id)
	_check(m.last_pull.is_empty() and m.block_count() == 0, "nothing behind: nothing moves")
	# A gate behind stops the pull.
	m = _model(["XA R>+A* . .", ". .     . ."])
	_check(m.pull_target(_at(m, 1, 0).id).is_empty(), "a Chain Gate behind stops the pull")
	# A twin behind stops the pull.
	var tm := _model(["R^* .", "B^!T Y^!T", ". ."], true)  # twins: campaign-style parsing
	_check(_at(tm, 0, 1).twin != "" and tm.pull_target(_at(tm, 0, 0).id).is_empty(), "a twin behind stops the pull")
	# An adjacent spinner behind turns first, then is pulled.
	m = _model([". R^* .", ". G<@ .", ". . ."])
	var sp := _at(m, 1, 1).id
	m.remove(_at(m, 1, 0).id)
	_check(m.blocks[sp].cell == Vector2i(1, 0) and m.blocks[sp].direction == Direction.UP, "an adjacent spinner turns (left -> up) and is then pulled")
	# The pull is computed AFTER the escape: the preview is exact on random boards.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var exact := 0
	var total := 0
	for i in 300:
		var bm := _model(_random_map(rng, 5, rng.randi_range(6, 10), 2, 2))
		for id in bm.blocks.keys():
			if bm.blocks[id].magnet and bm.move_state(id) == "ok":
				var p := bm.pull_target(id)
				var s2 := bm.snapshot()
				bm.remove(id)
				total += 1
				if bm.last_pull == p:
					exact += 1
				bm.restore(s2)
	_check(total > 50 and exact == total, "the preview line is exactly the pull that happens (%d / %d escapes)" % [exact, total])
	_done.append("rules")


# --- C ------------------------------------------------------------------------------

func _solver_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var boards := 0
	var agree := 0
	var legal_ok := 0
	var replay_ok := 0
	var solvable := 0
	var undo_ok := 0
	var undo_n := 0
	for i in 250:
		var map := _random_map(rng, 5, rng.randi_range(5, 9), rng.randi_range(1, 2), rng.randi_range(0, 2))
		var m := _model(map)
		if not m.blocks.values().any(func(b): return b.magnet):
			continue
		boards += 1
		var brute := _brute(m, {})
		var s := Solver.from_model(m)
		var sol := s.solve()
		if (not sol.is_empty()) == brute:
			agree += 1
		if brute:
			solvable += 1
			var r := _model(map)
			var ok := true
			for id in sol:
				if r.move_state(id) != "ok":
					ok = false
					break
				r.remove(id)
			if ok and r.is_empty():
				replay_ok += 1
		var want := m.blocks.keys().filter(func(id): return m.move_state(id) == "ok")
		var got := Array(Solver.from_model(m).legal_moves()).map(func(mv): return mv & Solver.ID_MASK)
		want.sort()
		got.sort()
		if want == got:
			legal_ok += 1
		var s3 := Solver.from_model(m)
		var key := s3._key()
		for mv in s3.legal_moves():
			s3._do(mv)
			s3._undo_move(mv)
			undo_n += 1
			if s3._key() == key and s3._grid == Solver.from_model(m)._grid:
				undo_ok += 1
	_check(boards >= 150, "fuzz boards with magnets (%d)" % boards)
	_check(agree == boards, "Solver verdict = exhaustive BoardModel search (%d / %d, %d solvable)" % [agree, boards, solvable])
	_check(legal_ok == boards, "Solver legal moves = BoardModel's (%d / %d)" % [legal_ok, boards])
	_check(replay_ok == solvable, "every Solver solution replays through BoardModel (%d / %d)" % [replay_ok, solvable])
	_check(undo_n > 300 and undo_ok == undo_n, "Solver do / undo restores the state exactly (%d / %d)" % [undo_ok, undo_n])
	_done.append("solver")


## Exhaustive search with BoardModel only (the reference).
func _brute(m: BoardModel, memo: Dictionary) -> bool:
	if m.is_empty():
		return true
	var parts := []
	var ids := m.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d,%d,%d,%d" % [id, b.cell.x, b.cell.y, b.direction, b.spin_step])
	var k := "|".join(parts)
	if memo.has(k):
		return memo[k]
	var win := false
	for id in m.blocks.keys():
		if m.move_state(id) != "ok":
			continue
		var snap := m.snapshot()
		m.remove(id)
		win = _brute(m, memo)
		m.restore(snap)
		if win:
			break
	memo[k] = win
	return win


static func _random_map(rng: RandomNumberGenerator, size: int, n: int, magnets: int, spinners: int) -> Array:
	var cells := []
	for r in size:
		for c in size:
			cells.append(Vector2i(c, r))
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var grid := {}
	for i in n:
		var tok: String = "RBGYP"[rng.randi_range(0, 4)] + "^v<>"[rng.randi_range(0, 3)]
		if i < magnets:
			tok += "*"
		elif i < magnets + spinners:
			tok += "@"
		grid[cells[i]] = tok
	var map := []
	for r in size:
		var row := []
		for c in size:
			row.append(grid.get(Vector2i(c, r), "."))
		map.append(" ".join(row))
	return map


# --- D ------------------------------------------------------------------------------

func _lab() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/mechlab_magnet.json"))
	_check(typeof(data) == TYPE_DICTIONARY and data.get("mechanic", "") == "magnet" and data["boards"].size() == 3, "the Magnet lab board file has 3 boards")
	if typeof(data) != TYPE_DICTIONARY:
		return
	var builder = load("res://tools/mechlab_magnet_build.gd")
	var stages := []
	for i in data["boards"].size():
		var b: Dictionary = data["boards"][i]
		stages.append(b["stage"])
		var spec: Dictionary = builder.BOARDS[i]
		var map: Array = spec["map"].map(func(r): return " ".join(String(r).split(" ", false)))
		_check(Array(b["puzzle"]["map"]) == map, "%s: the file matches the build tool's board" % b["id"])
		var m: Dictionary = builder.evaluate(map)
		_check(m["problems"].is_empty(), "%s: solvable, needs its magnets, Solver = BoardModel (%s)" % [b["id"], m["problems"]])
		_check(PuzzleDefinition.from_dict(b["puzzle"]) != null and PuzzleDefinition.from_dict(b["puzzle"]).verify(), "%s: plays in the lab (PuzzleDefinition verifies)" % b["id"])
	_check(stages == ["A", "B", "C"], "stages: A introduction, B combination, C challenge (%s)" % [stages])
	_check(MechLab.MECHANICS.has("magnet") and MechLab.MECHANICS["magnet"]["data"] == "res://data/dev/mechlab_magnet.json", "the Mech Lab knows the Magnet lab")
	_check(not BuildFlags.magnet_lab() and not BuildFlags.dev_pages_off(), "test runs are not the Magnet lab build")
	_done.append("lab")
