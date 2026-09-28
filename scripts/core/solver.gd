class_name Solver
extends RefCounted
## Exhaustive solver for Chain Escape boards (spinners, locks, mystery and,
## since v0.6, switches, Chain Gates and armored blocks).
##
## Used by the Hint button, the level verifier and the LevelGenerator.
##
## Key pruning rule: a move that can never hurt is applied greedily without
## branching. Safe moves are:
##   * escaping a free block that has NO adjacent spinner and is not a
##     switch (it only frees space, unlocks, reveals and opens gates)
##   * a ram (it only removes an armored block's shell)
## The search only branches on moves that turn spinners or fire a switch,
## and remembers dead states. Normal levels without spinners/switches solve
## in linear time.
##
## Locks, hidden arrows, switch flips and open gates are all derived from the
## alive set, so the memo key (alive set + spinner directions/steps + armor
## shells) stays exact.
##
## Moves are block ids (what the player taps). Internally a ram is marked
## with the RAM bit; the public results are plain tap ids (a block that is
## first used to ram and later escapes appears twice).

const DEFAULT_NODE_LIMIT := 60000
## Node limit for new solvers. Level generation lowers it so hopeless
## candidates are rejected quickly; the game and the verifier keep 60000.
static var default_limit: int = DEFAULT_NODE_LIMIT
const RAM := 1 << 20
const ID_MASK := RAM - 1

var rows: int
var columns: int
var node_limit: int = default_limit
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
var _rule: PackedInt32Array  # spinner rule (BlockData.SpinRule)
var _step: PackedInt32Array  # spinner turns made so far
var _color: PackedInt32Array  # color index per block
var _lock: PackedInt32Array  # key color index, -1 = not locked
var _hidden: PackedByteArray  # concealed at construction time
var _neighbours: Array = []  # per block: neighbour ids at construction (gates excluded)
var _color_count := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
var _color_names: Array = []
var _failed: Dictionary = {}
var _path: Array[int] = []
# v0.6
var _gate: PackedByteArray  # 1 = Chain Gate
var _switch: PackedInt32Array  # switch group index, -1 = not a switch
var _link: PackedInt32Array  # gate group index this block counts toward, -1
var _armor: PackedByteArray  # 1 = shell intact
var _armored_ids: PackedInt32Array
var _flip_ids: Array = [[], [], [], []]  # group -> ids that reverse
var _gate_ids: Array = [[], [], [], []]  # group -> gate ids
var _links_alive := PackedInt32Array([0, 0, 0, 0])


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
	_rule = PackedInt32Array(); _rule.resize(n)
	_step = PackedInt32Array(); _step.resize(n)
	_color = PackedInt32Array(); _color.resize(n)
	_lock = PackedInt32Array(); _lock.resize(n)
	_lock.fill(-1)
	_hidden = PackedByteArray(); _hidden.resize(n)
	_gate = PackedByteArray(); _gate.resize(n)
	_switch = PackedInt32Array(); _switch.resize(n)
	_switch.fill(-1)
	_link = PackedInt32Array(); _link.resize(n)
	_link.fill(-1)
	_armor = PackedByteArray(); _armor.resize(n)
	_armored_ids = PackedInt32Array()
	_neighbours.resize(n)
	for b in blocks:
		_rule[b.id] = b.spin_rule
		_step[b.id] = b.spin_step
		_color[b.id] = _color_index(b.color)
		_color_count[_color[b.id]] += 1
		if b.lock_color != "":
			_lock[b.id] = _color_index(b.lock_color)
		_hidden[b.id] = 1 if b.hidden else 0
		if b.is_gate():
			_gate[b.id] = 1
			_gate_ids[_group(b.gate_group)].append(b.id)
		if b.switch_group != "":
			_switch[b.id] = _group(b.switch_group)
		if b.flip_link != "":
			_flip_ids[_group(b.flip_link)].append(b.id)
		if b.gate_link != "":
			_link[b.id] = _group(b.gate_link)
			_links_alive[_link[b.id]] += 1
		if b.armored:
			_armor[b.id] = 1
			_armored_ids.append(b.id)
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
	for b in blocks:
		var nb := []
		for step in Direction.STEPS:
			var x: int = b.cell.x + step.x
			var y: int = b.cell.y + step.y
			if x >= 0 and y >= 0 and x < columns and y < rows and _grid[y * columns + x] != -1:
				var o := _grid[y * columns + x]
				if _gate[o] == 0:
					nb.append(o)
		_neighbours[b.id] = nb


static func _group(letter: String) -> int:
	return maxi(0, BlockData.LINK_GROUPS.find(letter))


func _color_index(c: String) -> int:
	var i := _color_names.find(c)
	if i == -1:
		_color_names.append(c)
		i = _color_names.size() - 1
	return i


static func from_model(model: BoardModel) -> Solver:
	return Solver.new(model.rows, model.columns, model.snapshot())


# --- Public API ------------------------------------------------------------

## Returns a full solution (block ids in tap order), or [] if the board
## cannot be cleared (check `aborted` to tell "unsolvable" from "gave up").
## An already-empty board returns [] with is_solved() true.
func solve() -> Array[int]:
	return _strip(solve_moves())


## Like solve(), with rams marked by the RAM bit.
func solve_moves() -> Array[int]:
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


static func _strip(moves: Array) -> Array[int]:
	var out: Array[int] = []
	for m in moves:
		out.append(m & ID_MASK)
	return out


func is_solvable() -> bool:
	if _alive_count == 0:
		return true
	return not solve_moves().is_empty()


## Moves available right now: escapes (plain ids) and rams (RAM bit set).
func legal_moves() -> Array[int]:
	var out: Array[int] = []
	for id in _alive.size():
		if _alive[id] == 1:
			if _is_legal(id):
				out.append(id)
			elif _ram_target(id) != -1:
				out.append(id | RAM)
	return out


## Best move for a hint: a legal move after which the board is still
## solvable. Prefers the real decisions (moves that turn spinners or fire a
## switch) over always-safe moves. Returns the block id to tap, or -1 if no
## legal move keeps the board solvable.
func recommend_move() -> int:
	var safe_pick := -1
	for mv in legal_moves():
		_do(mv)
		var ok := _alive_count == 0 or not _solve_keep_state().is_empty()
		_undo_move(mv)
		if not ok:
			continue
		if _is_risky(mv):
			return mv & ID_MASK
		if safe_pick == -1:
			safe_pick = mv & ID_MASK
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
		"locks": 0, "hidden": 0,
		"rule_cw": 0, "rule_ccw": 0, "rule_alt": 0, "rule_pattern": 0,
		# v0.6
		"switches": 0, "flip_targets": 0, "gates": 0, "gate_links": 0, "armored": 0, "rams": 0,
		"switch_decisions": 0, "branching": 0.0,
	}
	for sid in _spinner_ids:
		m["rule_" + ["cw", "ccw", "alt", "pattern"][_rule[sid]]] += 1
	var arrows := 0
	for id in _alive.size():
		if _alive[id] == 1:
			m["locks"] += 1 if _lock[id] >= 0 else 0
			m["hidden"] += 1 if _is_concealed(id) else 0
			m["switches"] += 1 if _switch[id] >= 0 else 0
			m["gates"] += _gate[id]
			m["gate_links"] += 1 if _link[id] >= 0 else 0
			m["armored"] += _armor[id]
			if _gate[id] == 0:
				arrows += 1
	for g in 4:
		m["flip_targets"] += _flip_ids[g].size()
	# Gates are not arrows: they don't count as blocks to clear or directions.
	m["blocks"] = arrows
	var counts := [0, 0, 0, 0]
	for id in _alive.size():
		if _alive[id] == 1 and _gate[id] == 0:
			counts[_dir[id]] += 1
	m["direction_share"] = float(counts.max()) / maxf(arrows, 1)
	m["directions_used"] = counts.filter(func(c): return c > 0).size()

	var solution := solve_moves()
	m["solvable"] = _alive_count == 0 or not solution.is_empty()
	m["solution"] = _strip(solution)
	if not m["solvable"]:
		return m
	# Walk the solution; at every state count legal moves that are traps
	# (legal now, but the board becomes unsolvable afterwards).
	var applied: Array = []
	var round_free: Array[int] = legal_moves()
	var depth := 1
	var legal_sum := 0
	for step in solution.size():
		var traps := 0
		var legal := legal_moves()
		legal_sum += legal.size()
		for mv in legal:
			if not _is_risky(mv):
				continue  # safe moves are never traps
			_do(mv)
			var ok := _alive_count == 0 or not _solve_keep_state().is_empty()
			_undo_move(mv)
			if not ok:
				traps += 1
				if _switch[mv & ID_MASK] >= 0:
					m["switch_decisions"] += 1
		if step == 0:
			m["start_traps"] = traps
		if traps > 0:
			m["decision_points"] += 1
			m["trap_moves"] += traps
		var move: int = solution[step]
		if move & RAM:
			m["rams"] += 1
		if not round_free.has(move):
			depth += 1
			round_free = legal
		_do(move)
		applied.append(move)
	m["depth"] = depth
	m["branching"] = snappedf(float(legal_sum) / maxf(solution.size(), 1), 0.01)
	# Restore the starting state.
	for i in range(applied.size() - 1, -1, -1):
		_undo_move(applied[i])
	return m


## Mystery fairness: hidden arrows must never be needed to choose well.
##
## Walks the solution. At every state with concealed blocks, it takes each
## concealed block, tries its three other possible directions, and checks
## that every risky visible move keeps the same "trap / not trap" status. If
## so, a player can always pick a good move from visible information only;
## hidden arrows are uncovered, not guessed. (Alternatives that would make
## the level unsolvable are skipped.)
func mystery_fairness() -> Dictionary:
	var result := {"fair": true, "states_checked": 0, "reason": ""}
	var solution := solve_moves()
	if solution.is_empty() and _alive_count > 0:
		return {"fair": false, "states_checked": 0, "reason": "unsolvable"}
	var applied: Array = []
	for step in solution.size():
		var concealed := []
		for id in _alive.size():
			if _alive[id] == 1 and _is_concealed(id):
				concealed.append(id)
		if not concealed.is_empty():
			result["states_checked"] += 1
			var risky := legal_moves().filter(func(x): return _is_risky(x))
			if not risky.is_empty():
				var base := _trap_map(risky)
				for h in concealed:
					var true_dir := _dir[h]
					for d in 4:
						if d == true_dir:
							continue
						_dir[h] = d
						if not _solve_keep_state().is_empty() and _trap_map(risky) != base:
							result["fair"] = false
							result["reason"] = "step %d: hidden block %d decides a trap" % [step, h]
						_dir[h] = true_dir
		var move: int = solution[step]
		applied.append(move)
		_do(move)
	for i in range(applied.size() - 1, -1, -1):
		_undo_move(applied[i])
	return result


func _trap_map(moves: Array) -> Array:
	var out := []
	for mv in moves:
		_do(mv)
		out.append(_alive_count > 0 and _solve_keep_state().is_empty())
		_undo_move(mv)
	return out


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
	# 1) Greedily apply safe moves: plain escapes and rams.
	var safe: Array[int] = []
	var progress := true
	while progress:
		progress = false
		for id in _alive.size():
			if _alive[id] == 0:
				continue
			if _is_legal(id):
				if _spinner_neighbours(id) == 0 and _switch[id] < 0:
					_apply(id)
					safe.append(id)
					_path.append(id)
					progress = true
			elif not _armored_ids.is_empty() and _ram_target(id) != -1:
				_do(id | RAM)
				safe.append(id | RAM)
				_path.append(id | RAM)
				progress = true
	if _alive_count == 0:
		return true
	var key := _key()
	if not _failed.has(key):
		# 2) Branch on moves that turn spinners or fire a switch.
		for id in _alive.size():
			if _alive[id] == 1 and _is_legal(id):
				_apply(id)
				_path.append(id)
				if _dfs():
					return true
				_path.pop_back()
				_undo(id)
				if aborted:
					break
		if not aborted:
			_failed[key] = true
	# Backtrack the safe moves too.
	for i in range(safe.size() - 1, -1, -1):
		_undo_move(safe[i])
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
		# ALT / PATTERN spinners: where they are in their sequence matters.
		var period := BlockData.rule_period(_rule[sid])
		if period > 1:
			dirs = dirs * period + posmod(_step[sid], period)
	parts.append(str(dirs))
	if not _armored_ids.is_empty():
		var shells := 0
		for i in _armored_ids.size():
			shells |= _armor[_armored_ids[i]] << (i % 62)
		parts.append(str(shells))
	return ":".join(parts)


## A move that may hurt: it turns spinners or fires a switch.
func _is_risky(move: int) -> bool:
	if move & RAM:
		return false
	return _spinner_neighbours(move) > 0 or _switch[move] >= 0


## Can escape now: not a gate, not hidden, not locked, not armored, lane clear.
func _is_legal(id: int) -> bool:
	if _gate[id] == 1 or _armor[id] == 1:
		return false
	if _hidden[id] == 1 and _is_concealed(id):
		return false
	if _lock[id] >= 0 and _color_count[_lock[id]] > 0:
		return false
	return _is_free(id)


## If `id` could be tapped and its lane runs straight into a shelled block,
## that block's id (a ram); else -1.
func _ram_target(id: int) -> int:
	if _gate[id] == 1 or _armor[id] == 1:
		return -1
	if _hidden[id] == 1 and _is_concealed(id):
		return -1
	if _lock[id] >= 0 and _color_count[_lock[id]] > 0:
		return -1
	var t := _first_in_lane(id)
	return t if t != -1 and _armor[t] == 1 else -1


## Still hidden: no neighbour (at construction time) has escaped yet.
func _is_concealed(id: int) -> bool:
	if _hidden[id] == 0:
		return false
	for n in _neighbours[id]:
		if _alive[n] == 0:
			return false
	return true


func _is_free(id: int) -> bool:
	return _first_in_lane(id) == -1


## The first block in `id`'s arrow direction, or -1 if the lane is clear.
func _first_in_lane(id: int) -> int:
	var idx := _cell[id]
	var c := idx % columns
	var r := idx / columns
	var step: Vector2i = Direction.STEPS[_dir[id]]
	c += step.x
	r += step.y
	while c >= 0 and r >= 0 and c < columns and r < rows:
		var o := _grid[r * columns + c]
		if o != -1:
			return o
		c += step.x
		r += step.y
	return -1


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


## Applies a move (escape, or ram with the RAM bit).
func _do(move: int) -> void:
	if move & RAM:
		_armor[_first_in_lane(move & ID_MASK)] = 0
	else:
		_apply(move)


## Exact inverse of _do (LIFO order).
func _undo_move(move: int) -> void:
	if move & RAM:
		_armor[_first_in_lane(move & ID_MASK)] = 1
	else:
		_undo(move)


## Removes `id`: turns adjacent spinners, fires its switch, and opens its
## Chain Gate if it was the last link. Returns the turned spinner ids.
func _apply(id: int) -> Array:
	var idx := _cell[id]
	_grid[idx] = -1
	_alive[id] = 0
	_alive_count -= 1
	_color_count[_color[id]] -= 1
	var turned := []
	var c := idx % columns
	var r := idx / columns
	for step in Direction.STEPS:
		var x: int = c + step.x
		var y: int = r + step.y
		if x >= 0 and y >= 0 and x < columns and y < rows:
			var other := _grid[y * columns + x]
			if other != -1 and _spinner[other] == 1:
				var cw := BlockData.turn_is_cw(_rule[other], _step[other])
				_dir[other] = Direction.rotate_cw(_dir[other]) if cw else Direction.rotate_ccw(_dir[other])
				_step[other] += 1
				turned.append(other)
	if _switch[id] >= 0:
		for t in _flip_ids[_switch[id]]:
			_dir[t] = Direction.opposite(_dir[t])
	if _link[id] >= 0:
		var g := _link[id]
		_links_alive[g] -= 1
		if _links_alive[g] == 0:
			for gid in _gate_ids[g]:
				_grid[_cell[gid]] = -1
				_alive[gid] = 0
				_alive_count -= 1
	return turned


## Undo a successful search's moves (the search leaves them applied).
func _rewind(path: Array[int]) -> void:
	for i in range(path.size() - 1, -1, -1):
		_undo_move(path[i])


## Puts `id` back: closes the gate it opened, un-flips its switch targets
## and turns its spinner neighbours back. Must be called in reverse order
## of _apply, so the neighbours are exactly those turned.
func _undo(id: int, _turned: Array = []) -> void:
	if _link[id] >= 0:
		var g := _link[id]
		if _links_alive[g] == 0:
			for gid in _gate_ids[g]:
				_grid[_cell[gid]] = gid
				_alive[gid] = 1
				_alive_count += 1
		_links_alive[g] += 1
	if _switch[id] >= 0:
		for t in _flip_ids[_switch[id]]:
			_dir[t] = Direction.opposite(_dir[t])
	var idx := _cell[id]
	var c := idx % columns
	var r := idx / columns
	for step in Direction.STEPS:
		var x: int = c + step.x
		var y: int = r + step.y
		if x >= 0 and y >= 0 and x < columns and y < rows:
			var other := _grid[y * columns + x]
			if other != -1 and _spinner[other] == 1:
				_step[other] -= 1
				var cw := BlockData.turn_is_cw(_rule[other], _step[other])
				_dir[other] = Direction.rotate_ccw(_dir[other]) if cw else Direction.rotate_cw(_dir[other])
	_grid[idx] = id
	_alive[id] = 1
	_alive_count += 1
	_color_count[_color[id]] += 1
