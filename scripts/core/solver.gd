class_name Solver
extends RefCounted
## Exhaustive solver for Chain Escape boards (with spinners).
##
## Used by the Hint button, the level verifier and the LevelGenerator.
##
## Key pruning rule: removing a free block that has NO adjacent spinner can
## never hurt (it only frees space and turns nothing), so such "safe" moves
## are applied greedily without branching. The search only branches on moves
## that turn spinners, and remembers dead states. Normal levels without
## spinners therefore solve in linear time.

const DEFAULT_NODE_LIMIT := 60000

var rows: int
var columns: int
var node_limit: int = DEFAULT_NODE_LIMIT
var nodes: int = 0
## True if the last search hit node_limit (result unknown, treated as unsolved).
var aborted: bool = false
## True if any sub-search in recommend_move()/analyze() gave up.
var any_aborted: bool = false

# Compact board state, indexed by block id.
var _grid: PackedInt32Array  # cell index -> block id or -1
var _cell: PackedInt32Array
var _dir: PackedInt32Array
var _spinner: PackedByteArray
var _alive: PackedByteArray
var _alive_count: int = 0
var _spinner_ids: PackedInt32Array
var _failed: Dictionary = {}
var _path: Array[int] = []


## Build from a list of BlockData (e.g. BoardModel.snapshot()).
func _init(p_rows: int, p_columns: int, blocks: Array) -> void:
	rows = p_rows
	columns = p_columns
	var max_id := -1
	for b in blocks:
		max_id = maxi(max_id, b.id)
	var n := max_id + 1
	_grid = PackedInt32Array()
	_grid.resize(rows * columns)
	_grid.fill(-1)
	_cell = PackedInt32Array(); _cell.resize(n)
	_dir = PackedInt32Array(); _dir.resize(n)
	_spinner = PackedByteArray(); _spinner.resize(n)
	_alive = PackedByteArray(); _alive.resize(n)
	_alive.fill(0)
	_spinner_ids = PackedInt32Array()
	for b in blocks:
		var idx: int = b.cell.y * columns + b.cell.x
		_grid[idx] = b.id
		_cell[b.id] = idx
		_dir[b.id] = b.direction
		_spinner[b.id] = 1 if b.is_spinner() else 0
		_alive[b.id] = 1
		_alive_count += 1
		if b.is_spinner():
			_spinner_ids.append(b.id)


static func from_model(model: BoardModel) -> Solver:
	return Solver.new(model.rows, model.columns, model.snapshot())


# --- Public API ------------------------------------------------------------

## Returns a full solution (list of block ids in tap order), or [] if the
## board cannot be cleared (check `aborted` to tell "unsolvable" from
## "gave up"). An already-empty board returns [] with is_solved() true.
func solve() -> Array[int]:
	nodes = 0
	aborted = false
	_failed.clear()
	_path.clear()
	if _dfs():
		var result: Array[int] = _path.duplicate()
		_rewind(_path)
		_path.clear()
		return result
	return []


func is_solvable() -> bool:
	if _alive_count == 0:
		return true
	return not solve().is_empty()


## Ids of blocks that could escape right now.
func legal_moves() -> Array[int]:
	var out: Array[int] = []
	for id in _alive.size():
		if _alive[id] == 1 and _is_free(id):
			out.append(id)
	return out


## Best move for a hint: a legal move after which the board is still
## solvable. Prefers moves that turn spinners (the real decisions) over
## always-safe moves. Returns -1 if no legal move keeps the board solvable.
func recommend_move() -> int:
	var safe_pick := -1
	for id in legal_moves():
		var turned := _apply(id)
		var ok := _alive_count == 0 or not _solve_keep_state().is_empty()
		_undo(id, turned)
		if not ok:
			continue
		if turned.size() > 0:
			return id
		if safe_pick == -1:
			safe_pick = id
	return safe_pick


## Difficulty metrics for tools and the LevelGenerator. Can be slow on big
## boards (it solves once per legal move along the solution).
func analyze() -> Dictionary:
	var m := {
		"rows": rows, "columns": columns, "blocks": _alive_count,
		"spinners": _spinner_ids.size(),
		"start_moves": legal_moves().size(),
		"solvable": false, "solution": [],
		"start_traps": 0, "decision_points": 0, "trap_moves": 0,
		"depth": 0, "direction_share": 0.0, "directions_used": 0,
	}
	# Direction diversity.
	var counts := [0, 0, 0, 0]
	for id in _alive.size():
		if _alive[id] == 1:
			counts[_dir[id]] += 1
	m["direction_share"] = float(counts.max()) / maxf(_alive_count, 1)
	m["directions_used"] = counts.filter(func(c): return c > 0).size()

	var solution := solve()
	m["solvable"] = _alive_count == 0 or not solution.is_empty()
	m["solution"] = solution
	if not m["solvable"]:
		return m
	# Walk the solution; at every state count legal moves that are traps
	# (legal now, but the board becomes unsolvable afterwards).
	var applied: Array = []
	var round_free: Array[int] = legal_moves()
	var depth := 1
	for step in solution.size():
		var traps := 0
		var legal := legal_moves()
		for id in legal:
			if _spinner_neighbours(id) == 0:
				continue  # safe moves are never traps
			var t := _apply(id)
			var ok := _alive_count == 0 or not _solve_keep_state().is_empty()
			_undo(id, t)
			if not ok:
				traps += 1
		if step == 0:
			m["start_traps"] = traps
		if traps > 0:
			m["decision_points"] += 1
			m["trap_moves"] += traps
		var move: int = solution[step]
		if not round_free.has(move):
			depth += 1
			round_free = legal
		applied.append([move, _apply(move)])
	m["depth"] = depth
	# Restore the starting state.
	for i in range(applied.size() - 1, -1, -1):
		_undo(applied[i][0], applied[i][1])
	return m


# --- Search ----------------------------------------------------------------

func _solve_keep_state() -> Array[int]:
	# Solve from the current (possibly mutated) state without disturbing it.
	var saved_path := _path.duplicate()
	var saved_failed := _failed
	_failed = {}
	_path.clear()
	nodes = 0
	aborted = false
	var ok := _dfs()
	if aborted:
		any_aborted = true
	var result: Array[int] = _path.duplicate() if ok else ([] as Array[int])
	if ok:
		_rewind(_path)
	_path = saved_path
	_failed = saved_failed
	if ok and result.is_empty():
		result = [-1]  # solved with zero moves (already empty)
	return result


func _dfs() -> bool:
	nodes += 1
	if nodes > node_limit:
		aborted = true
		return false
	# 1) Greedily apply safe moves (free, and turning no spinner).
	var safe: Array[int] = []
	var progress := true
	while progress:
		progress = false
		for id in _alive.size():
			if _alive[id] == 1 and _spinner_neighbours(id) == 0 and _is_free(id):
				_apply(id)
				safe.append(id)
				_path.append(id)
				progress = true
	if _alive_count == 0:
		return true
	var key := _key()
	if not _failed.has(key):
		# 2) Branch on moves that turn spinners.
		for id in _alive.size():
			if _alive[id] == 1 and _is_free(id):
				var turned := _apply(id)
				_path.append(id)
				if _dfs():
					return true
				_path.pop_back()
				_undo(id, turned)
				if aborted:
					break
		if not aborted:
			_failed[key] = true
	# Backtrack the safe moves too.
	for i in range(safe.size() - 1, -1, -1):
		_undo(safe[i], [])
		_path.pop_back()
	return false


func _key() -> String:
	var parts := PackedStringArray()
	var mask := 0
	for id in _alive.size():
		if _alive[id] == 1:
			mask |= 1 << (id % 62)
		if id % 62 == 61:
			parts.append(str(mask))
			mask = 0
	parts.append(str(mask))
	var dirs := 0
	for sid in _spinner_ids:
		dirs = dirs * 4 + _dir[sid]
	parts.append(str(dirs))
	return ":".join(parts)


func _is_free(id: int) -> bool:
	var idx := _cell[id]
	var c := idx % columns
	var r := idx / columns
	var step: Vector2i = Direction.STEPS[_dir[id]]
	c += step.x
	r += step.y
	while c >= 0 and r >= 0 and c < columns and r < rows:
		if _grid[r * columns + c] != -1:
			return false
		c += step.x
		r += step.y
	return true


func _spinner_neighbours(id: int) -> int:
	var idx := _cell[id]
	var c := idx % columns
	var r := idx / columns
	var n := 0
	for step in Direction.STEPS:
		var x: int = c + step.x
		var y: int = r + step.y
		if x >= 0 and y >= 0 and x < columns and y < rows:
			var other := _grid[y * columns + x]
			if other != -1 and _spinner[other] == 1:
				n += 1
	return n


## Removes `id` and turns adjacent spinners. Returns the turned spinner ids.
func _apply(id: int) -> Array:
	var idx := _cell[id]
	_grid[idx] = -1
	_alive[id] = 0
	_alive_count -= 1
	var turned := []
	var c := idx % columns
	var r := idx / columns
	for step in Direction.STEPS:
		var x: int = c + step.x
		var y: int = r + step.y
		if x >= 0 and y >= 0 and x < columns and y < rows:
			var other := _grid[y * columns + x]
			if other != -1 and _spinner[other] == 1:
				_dir[other] = Direction.rotate_cw(_dir[other])
				turned.append(other)
	return turned


## Undo a successful search's moves (the search leaves them applied).
func _rewind(path: Array[int]) -> void:
	for i in range(path.size() - 1, -1, -1):
		_undo(path[i])


## Puts `id` back and turns its alive spinner neighbours back. Must be called
## in reverse order of _apply, so the neighbours are exactly those turned.
func _undo(id: int, _turned: Array = []) -> void:
	var idx := _cell[id]
	var c := idx % columns
	var r := idx / columns
	for step in Direction.STEPS:
		var x: int = c + step.x
		var y: int = r + step.y
		if x >= 0 and y >= 0 and x < columns and y < rows:
			var other := _grid[y * columns + x]
			if other != -1 and _spinner[other] == 1:
				_dir[other] = Direction.rotate_ccw(_dir[other])
	_grid[idx] = id
	_alive[id] = 1
	_alive_count += 1
