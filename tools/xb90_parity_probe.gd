extends "res://tools/ta90_design.gd"
## PHASE 18 (development only): who is right when the Solver and the design
## tools' exhaustive search (EXPERT.explore) disagree on a board? For every
## disagreeing position: a third, independent answer - a plain breadth-first
## search over BoardModel positions (cycle-safe: a visited set, no memo of
## "losing" while a position is still open) - and which side it agrees with.
##   godot --headless --path . --script res://tools/xb90_parity_probe.gd -- --file=boards.json --name=SPC_1


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	for k in d:
		if x_args.has("name") and not str(x_args["name"]).split(",").has(k):
			continue
		probe(k, Array(d[k]["map"]))
	quit()


func probe(name: String, map: Array) -> void:
	var level := parse(map)
	var s := _solver(level)
	var win: Dictionary = EXPERT.explore(s)["win"]
	var stats := {"positions": 0, "disagree": 0, "solver_right": 0, "explore_right": 0}
	_walk(level, s, win, {}, [], stats)
	print("%s %s" % [name, JSON.stringify(stats)])


func _walk(level: LevelData, s: Solver, win: Dictionary, seen: Dictionary, path: Array, st: Dictionary) -> void:
	if s._alive_count == s._crate_n:
		return
	var key := s._key()
	if seen.has(key):
		return
	seen[key] = true
	st["positions"] += 1
	var explore: bool = win.get(key, false)
	var solver := not s._solve_keep_state().is_empty()
	if explore != solver:
		st["disagree"] += 1
		var truth := _bfs(level, path)
		if truth == solver:
			st["solver_right"] += 1
		else:
			st["explore_right"] += 1
		if st["disagree"] <= 3:
			print("  disagree at %s: solver %s, explore %s, BFS %s" % [str(path), solver, explore, truth])
	for mv in s._distinct_legal():
		s._do(mv)
		_walk(level, s, win, seen, path + [mv], st)
		s._undo_move(mv)


## Can the position after `path` be cleared? Plain BFS over BoardModel states.
func _bfs(level: LevelData, path: Array) -> bool:
	var m0 := EVENTS6.model_of(level)
	for mv in path:
		play_move(m0, mv)
	var start := m0.snapshot()
	var queue := [start]
	var visited := {_skey(start): true}
	while not queue.is_empty():
		var snap: Array = queue.pop_front()
		var m := _model_at(level, snap)
		if m.block_count() == 0:
			return true
		for id in m.blocks.keys():
			if not ["ok", "advance", "push", "ram"].has(m.move_state(id)):
				continue
			var m2 := _model_at(level, snap)
			play_move(m2, id)
			var s2 := m2.snapshot()
			var k := _skey(s2)
			if not visited.has(k):
				visited[k] = true
				queue.append(s2)
	return false


## A fresh model in position `snap` (copies: the snapshot is never mutated).
func _model_at(level: LevelData, snap: Array) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, snap.map(func(b): return b.duplicate_data()))
	m.set_portals(level.portals)
	return m


## Every block's state that changes in play.
static func _skey(snap: Array) -> String:
	var parts := []
	for b in snap:
		parts.append("%d:%d,%d:%d:%d:%d:%d" % [b.id, b.cell.x, b.cell.y, b.direction, int(b.armored), b.seq_stage, b.spin_step])
	parts.sort()
	return "|".join(parts)
