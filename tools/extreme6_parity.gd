extends Node
## EXTREME PHASE 2 (development only): game-versus-solver parity for the
## mechanic combinations of the six enriched puzzles, three of them never
## used together in the campaign (magnets appear only with clockwise
## spinners, Levels 76-99).
##   godot --headless --path . res://tools/Extreme6Parity.tscn
##
## On random small boards of each family, the Solver must agree with an
## exhaustive search that uses only BoardModel (the rules the play screen
## runs: BoardModel.move_state -> remove / ram, exactly as SocialPlay taps):
##   - the verdict (solvable or not),
##   - the legal moves (escapes and rams) of the start position,
##   - every Solver solution replays tap by tap through BoardModel,
##   - every Solver _do / _undo_move restores its state exactly,
##   - every magnet escape pulls exactly the previewed block
##     (BoardModel.pull_target), also after switches and gates changed it.
## Families:
##   A  magnets (some of them switch FLIP TARGETS) + a switch + a chain gate
##      + clockwise / counter-clockwise spinners + a colour lock
##   B  magnets + armored blocks (+ clockwise / counter-clockwise spinners)
##   C  portals + spinners + a chain gate (+ a switch)

var failures: Array[String] = []
var passed := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	LevelManager.dev_magnet = true
	for fam in ["A", "B", "C"]:
		_family(fam, 260 if fam != "C" else 520)
	LevelManager.dev_magnet = false
	print("EXTREME6 PARITY: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _family(fam: String, n: int) -> void:
	rng.seed = {"A": 61, "B": 67, "C": 71}[fam]
	var boards := 0
	var agree := 0
	var solvable := 0
	var legal_ok := 0
	var replay_ok := 0
	var undo_n := 0
	var undo_ok := 0
	var pulls := 0
	var pulls_ok := 0
	var features := {}
	for i in n:
		var map := _random_map(fam)
		var level := LevelManager.parse_level({"name": "parity", "map": map}, 0, true)
		if level == null or level.blocks.is_empty():
			continue
		if fam == "C" and level.portals.is_empty():
			continue  # a looping random portal layout (dropped by the parser): not a portal board
		var m := _model(level)
		_note_features(level, features)
		boards += 1
		var brute := _brute(m, {})
		var s := Solver.from_model(m)
		var sol := s.solve()
		if (not sol.is_empty()) == brute:
			agree += 1
		elif failures.size() < 20:
			failures.append("%s: verdict differs (brute %s) on %s" % [fam, brute, JSON.stringify(map)])
		if brute:
			solvable += 1
			var r := _model(level)
			var ok := true
			for id in sol:
				var st := r.move_state(id)
				if st == "ok":
					r.remove(id)
				elif st == "ram":
					r.ram(id)
				else:
					ok = false
					break
			if ok and r.is_empty():
				replay_ok += 1
			elif failures.size() < 20:
				failures.append("%s: solution does not replay on %s" % [fam, JSON.stringify(map)])
		var want := m.blocks.keys().filter(func(id): return m.move_state(id) in ["ok", "ram"])
		var got := Array(Solver.from_model(m).legal_moves()).map(func(mv): return mv & Solver.ID_MASK)
		want.sort()
		got.sort()
		if want == got:
			legal_ok += 1
		elif failures.size() < 20:
			failures.append("%s: legal moves differ %s vs %s on %s" % [fam, str(want), str(got), JSON.stringify(map)])
		var s3 := Solver.from_model(m)
		var key := s3._key()
		var grid := s3._grid.duplicate()
		for mv in s3.legal_moves():
			s3._do(mv)
			s3._undo_move(mv)
			undo_n += 1
			if s3._key() == key and s3._grid == grid:
				undo_ok += 1
		var pc := _pull_previews(m, 0)
		pulls += pc[0]
		pulls_ok += pc[1]
	_check(boards >= (n * 0.8 if fam != "C" else 150), "%s: random boards (%d)" % [fam, boards])
	_check(agree == boards, "%s: Solver verdict = exhaustive BoardModel search (%d / %d, %d solvable)" % [fam, agree, boards, solvable])
	_check(solvable >= boards / 10, "%s: enough solvable boards to replay (%d)" % [fam, solvable])
	_check(legal_ok == boards, "%s: Solver legal moves = BoardModel's (%d / %d)" % [fam, legal_ok, boards])
	_check(replay_ok == solvable, "%s: every Solver solution replays through BoardModel (%d / %d)" % [fam, replay_ok, solvable])
	_check(undo_n > 300 and undo_ok == undo_n, "%s: Solver do / undo restores the state exactly (%d / %d)" % [fam, undo_ok, undo_n])
	if fam != "C":
		_check(pulls > 100 and pulls_ok == pulls, "%s: every magnet escape pulls exactly the previewed block, at every depth (%d / %d)" % [fam, pulls_ok, pulls])
	var need: Array = {"A": ["magnet", "flip_magnet", "switch", "gate", "ccw", "lock", "pull_switch_changed"],
		"B": ["magnet", "armor", "pulled_armor", "ccw"], "C": ["portal", "spinner", "gate", "switch"]}[fam]
	for f in need:
		_check(features.get(f, 0) > 0, "%s: boards actually exercise %s (%d)" % [fam, f, features.get(f, 0)])
	print("%s: %d boards, %d solvable, %d pull previews, features %s" % [fam, boards, solvable, pulls, str(features)])


## Every reachable magnet escape (depth-limited walk): the pull that happens
## equals the preview. Counts boards where a switch reversed a magnet before
## its pull and where an armored block was pulled (features).
func _pull_previews(m: BoardModel, depth: int) -> Array:
	var n := 0
	var ok := 0
	if depth > 3:
		return [0, 0]
	for id in m.blocks.keys():
		var st := m.move_state(id)
		if st != "ok" and st != "ram":
			continue
		var snap := m.snapshot()
		if st == "ok" and m.blocks[id].magnet:
			var p := m.pull_target(id)
			m.remove(id)
			n += 1
			if m.last_pull == p:
				ok += 1
		elif st == "ok":
			m.remove(id)
		else:
			m.ram(id)
		var sub := _pull_previews(m, depth + 1)
		n += sub[0]
		ok += sub[1]
		m.restore(snap)
	return [n, ok]


func _note_features(level: LevelData, f: Dictionary) -> void:
	var add := func(k: String): f[k] = f.get(k, 0) + 1
	for b in level.blocks:
		if b.magnet:
			add.call("magnet")
			if b.flip_link != "":
				add.call("flip_magnet")
		if b.switch_group != "":
			add.call("switch")
		if b.is_gate():
			add.call("gate")
		if b.armored:
			add.call("armor")
		if b.lock_color != "":
			add.call("lock")
		if b.is_spinner():
			add.call("spinner")
			if b.spin_rule == 1:
				add.call("ccw")
	if not level.portals.is_empty():
		add.call("portal")
	# Dynamic features, from the start position: a switch that reverses a
	# magnet changes its pull; a magnet whose pull target is armored.
	var m := _model(level)
	for id in m.blocks:
		var b: BlockData = m.blocks[id]
		if b.magnet:
			var t := m.pull_target(id)
			if not t.is_empty() and m.blocks[t["block"]].armored:
				add.call("pulled_armor")
			if b.flip_link != "":
				var before := m.pull_target(id)
				b.direction = Direction.opposite(b.direction)
				var after := m.pull_target(id)
				b.direction = Direction.opposite(b.direction)
				if before != after:
					add.call("pull_switch_changed")


func _model(level: LevelData) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks.map(func(b): return b.duplicate_data()))
	m.set_portals(level.portals)
	return m


## Exhaustive search with BoardModel only: taps exactly as SocialPlay plays
## them ("ok" = escape, "ram" = crack the shell in the lane).
func _brute(m: BoardModel, memo: Dictionary) -> bool:
	if m.is_empty():
		return true
	var parts := []
	var ids := m.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d,%d,%d,%d,%d" % [id, b.cell.x, b.cell.y, b.direction, b.spin_step, 1 if b.armored else 0])
	var k := "|".join(parts)
	if memo.has(k):
		return memo[k]
	var win := false
	for id in ids:
		var st := m.move_state(id)
		if st != "ok" and st != "ram":
			continue
		var snap := m.snapshot()
		if st == "ok":
			m.remove(id)
		else:
			m.ram(id)
		win = _brute(m, memo)
		m.restore(snap)
		if win:
			break
	memo[k] = win
	return win


const COLORS := ["R", "B", "G", "Y", "P"]
const DIRS := ["^", ">", "v", "<"]


func _random_map(fam: String) -> Array:
	var size := 5
	var grid := {}
	var free := []
	for r in size:
		for c in size:
			free.append(Vector2i(c, r))
	for i in range(free.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = free[i]
		free[i] = free[j]
		free[j] = t
	var take := func() -> Vector2i: return free.pop_back()
	var arrow := func() -> String: return COLORS[rng.randi_range(0, 4)] + DIRS[rng.randi_range(0, 3)]
	match fam:
		"A":
			grid[take.call()] = arrow.call() + "%A"  # the switch
			var flips := rng.randi_range(1, 3)
			for k in flips:
				# Flip targets: magnets about half the time.
				grid[take.call()] = arrow.call() + "&A" + ("*" if rng.randf() < 0.55 else "")
			grid[take.call()] = arrow.call() + "*"
			grid[take.call()] = "XC"
			for k in rng.randi_range(1, 2):
				grid[take.call()] = arrow.call() + "+C"
			for k in rng.randi_range(0, 2):
				grid[take.call()] = arrow.call() + ("@" if rng.randf() < 0.5 else "@-")
			if rng.randf() < 0.5:
				var t: String = arrow.call()
				var key: String = COLORS[(COLORS.find(t[0]) + 1 + rng.randi_range(0, 3)) % 5]
				grid[take.call()] = t + "#" + key
		"B":
			for k in rng.randi_range(1, 2):
				grid[take.call()] = arrow.call() + "*"
			for k in rng.randi_range(1, 2):
				grid[take.call()] = arrow.call() + "="
			for k in rng.randi_range(2, 4):
				grid[take.call()] = arrow.call()
			for k in rng.randi_range(0, 2):
				grid[take.call()] = arrow.call() + ("@" if rng.randf() < 0.5 else "@-")
			# Line an armored block up behind a magnet now and then (pulled armor).
			if rng.randf() < 0.6:
				var c := rng.randi_range(0, size - 1)
				var cells := [Vector2i(c, 0), Vector2i(c, 2)]
				if not grid.has(cells[0]) and not grid.has(cells[1]):
					grid[cells[0]] = COLORS[rng.randi_range(0, 4)] + "^*"
					grid[cells[1]] = COLORS[rng.randi_range(0, 4)] + DIRS[rng.randi_range(0, 3)] + "="
		"C":
			for g in ["A"]:
				grid[take.call()] = "O" + g
				grid[take.call()] = "O" + g
			grid[take.call()] = "XC"
			for k in rng.randi_range(1, 2):
				grid[take.call()] = arrow.call() + "+C"
			for k in rng.randi_range(1, 3):
				grid[take.call()] = arrow.call() + ("@" if rng.randf() < 0.6 else "@-")
			for k in rng.randi_range(1, 3):
				grid[take.call()] = arrow.call()
			if rng.randf() < 0.5:
				grid[take.call()] = arrow.call() + "%A"
				grid[take.call()] = arrow.call() + "&A"
	var map := []
	for r in size:
		var row := []
		for c in size:
			row.append(grid.get(Vector2i(c, r), "."))
		map.append(" ".join(row))
	return map


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(msg)
