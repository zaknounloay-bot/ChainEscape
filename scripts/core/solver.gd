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
##     switch (it only frees space, unlocks, reveals and opens gates) -
##     while armored shells remain, only if the block's own direction can
##     never change (not a spinner, not a flip target): a block that may
##     later turn toward a shell could be the rammer it needs
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
## Movable: a push move (the tapped block is launched into a crate).
const PUSH := 1 << 21

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
var _turnable: PackedByteArray  # 1 = its direction can change (spinner or flip target)
var _shells: int = 0  # shells still intact
var _flip_ids: Array = [[], [], [], []]  # group -> ids that reverse
var _gate_ids: Array = [[], [], [], []]  # group -> gate ids
var _links_alive := PackedInt32Array([0, 0, 0, 0])
# Portal (201+): cell index -> partner cell index.
# Static, so it is not part of the memo key. Empty on every campaign and
# Social board, where lanes are walked exactly as before.
var _portal_exit := PackedInt32Array()
var _has_portals := false
## Returned by _first_in_lane for a lane that loops (malformed portal
## layouts only): not free, and nothing to ram.
const LANE_LOOP := -2
# Sequence (226+): per block 0 / 1 / 2 (see
# BlockData.seq_stage) and the NEXT arrow. The stage changes during play,
# so it is part of the memo key; a first-stage block's legal move is the
# advance (it stays, turns / reveals its neighbours, takes its next arrow).
# Empty on every campaign and Social board.
var _seq_stage := PackedByteArray()
var _seq_first := PackedInt32Array()  # stage-1 arrow, to undo an advance
var _seq_next := PackedInt32Array()
var _seq_ids := PackedInt32Array()
# Movable (251+): crates are blocks that never leave;
# the board is clear when only they remain (_alive_count == _crate_n).
# Their cells change, so they are part of the memo key, and pushes can be
# undone (one stack entry per push). With crates, the search is the cycle-
# safe _dfs_crates (a crate can be pushed back and forth). 0 / empty on
# every campaign and Social board.
var _crate := PackedByteArray()
var _crate_ids := PackedInt32Array()
var _crate_n := 0
var _push_stack: Array = []
## Twins: per block the partner's id (-1 = not a twin, or its partner was
## not on the board at construction - a bond the Hammer broke). Inside the
## search both twins always leave together, so a pair is alive or gone.
var _twin := PackedInt32Array()
## v0.8 analysis only: false = pushes are not legal moves (the Movable block
## is a fixed obstacle) - "can this level be won without pushing?".
var allow_push := true
var _on_path: Dictionary = {}
var _last_low := 0


## Build from a list of BlockData (e.g. BoardModel.snapshot()).
func _init(p_rows: int, p_columns: int, blocks: Array, portals: Dictionary = {}) -> void:
	rows = p_rows
	columns = p_columns
	if not portals.is_empty():
		_has_portals = true
		_portal_exit.resize(rows * columns)
		_portal_exit.fill(-1)
		for cell in portals:
			var to: Vector2i = portals[cell]
			_portal_exit[cell.y * columns + cell.x] = to.y * columns + to.x
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
	_turnable = PackedByteArray(); _turnable.resize(n)
	_neighbours.resize(n)
	for b in blocks:
		if b.is_crate():
			if _crate_ids.is_empty():
				_crate.resize(n)
			_crate[b.id] = 1
			_crate_ids.append(b.id)
			_crate_n += 1
	for b in blocks:
		if b.seq_stage != 0:
			if _seq_ids.is_empty():
				_seq_stage.resize(n)
				_seq_first.resize(n)
				_seq_next.resize(n)
			_seq_ids.append(b.id)
			_seq_stage[b.id] = b.seq_stage
			_seq_next[b.id] = b.seq_next
			_seq_first[b.id] = b.direction
	var twins := {}
	for b in blocks:
		if b.twin != "":
			if twins.has(b.twin):
				if _twin.is_empty():
					_twin.resize(n)
					_twin.fill(-1)
				_twin[b.id] = twins[b.twin]
				_twin[twins[b.twin]] = b.id
			else:
				twins[b.twin] = b.id
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
			_shells += 1
		if b.is_spinner() or b.flip_link != "" or b.seq_stage == 1:
			_turnable[b.id] = 1
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
	return Solver.new(model.rows, model.columns, model.snapshot(), model.portals)


# --- Public API ------------------------------------------------------------

## Search budget for the Hammer check (well above what any campaign state
## needs; the starting boards of all 200 levels settle in < 60k nodes).
const HAMMER_NODE_LIMIT := 400000


## v0.6.4 Hammer rule: smashing `id` (ANY block - normal, reward, armored,
## even a Chain Gate) is allowed unless it would MAKE the puzzle unsolvable:
## - the board after the smash is solvable (or empty) -> allowed;
## - the board was already lost before the smash (a trap was walked into)
##   -> allowed: the Hammer can't make it worse, and may rescue it;
## - solvable before but not after -> rejected.
## If the solver can't settle the "after" board within its budget, the
## smash is allowed only when the board is provably lost already (a live
## board is never risked).
static func hammer_safe(model: BoardModel, id: int) -> bool:
	if not model.blocks.has(id):
		return false
	var test := BoardModel.new()
	test.setup(model.rows, model.columns, model.snapshot())
	test.set_portals(model.portal_groups)
	test.remove(id)
	if test.is_empty():
		return true
	var after := Solver.from_model(test)
	after.node_limit = HAMMER_NODE_LIMIT
	if after.is_solvable():
		return true
	var now := Solver.from_model(model)
	now.node_limit = HAMMER_NODE_LIMIT
	return not now.is_solvable() and not now.aborted


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
	_on_path.clear()
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
	if _alive_count == _crate_n:
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
			elif _crate_n > 0 and allow_push and _push_target(id) != -1:
				out.append(id | PUSH)
	return out


## Share of `playouts` random games that clear the board: each one taps a
## uniformly random legal move until none is left (a "random tapper", a proxy
## for how often the next move is obvious). Deterministic for a given seed;
## the board is left as it was. With `max_wins` >= 0 it stops as soon as more
## games than that were won and returns the rate measured so far (a quick
## "clearly too easy" estimate for searches).
func random_win_rate(playouts: int, seed: int, max_wins: int = -1) -> float:
	if _alive_count == _crate_n:
		return 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wins := 0
	var games := 0
	var done: Array[int] = []
	for k in playouts:
		games += 1
		done.clear()
		while true:
			# One uniformly random legal move (reservoir pick, no list).
			var pick := -1
			var seen := 0
			for id in _alive.size():
				if _alive[id] != 1:
					continue
				var mv := -1
				if _is_legal(id):
					mv = id
				elif _ram_target(id) != -1:
					mv = id | RAM
				elif _crate_n > 0 and allow_push and _push_target(id) != -1:
					mv = id | PUSH
				if mv == -1:
					continue
				seen += 1
				if rng.randi() % seen == 0:
					pick = mv
			if pick == -1 or (_crate_n > 0 and done.size() >= 120):
				break
			_do(pick)
			done.append(pick)
		if _alive_count == _crate_n:
			wins += 1
		for i in range(done.size() - 1, -1, -1):
			_undo_move(done[i])
		if max_wins >= 0 and wins > max_wins:
			break
	return float(wins) / maxf(games, 1)


## Share of `games` played by a LOOKAHEAD player: at every step it picks a
## random legal move among those that do not lead to a visible dead end
## within `depth` more moves (no legal move left while blocks remain); if
## every move does, any legal move. A rough model of a person who looks a
## couple of moves ahead (the random tapper looks zero moves ahead).
## Deterministic for a given seed; the board is left as it was.
func lookahead_win_rate(games: int, depth: int, seed: int) -> float:
	if _alive_count == _crate_n:
		return 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wins := 0
	var done: Array[int] = []
	for k in games:
		done.clear()
		while true:
			var legal := legal_moves()
			if legal.is_empty():
				break
			var ok: Array[int] = []
			for mv in legal:
				_do(mv)
				if not _dead_within(depth):
					ok.append(mv)
				_undo_move(mv)
			var pool: Array[int] = ok if not ok.is_empty() else legal
			var pick: int = pool[rng.randi() % pool.size()]
			_do(pick)
			done.append(pick)
		if _alive_count == _crate_n:
			wins += 1
		for i in range(done.size() - 1, -1, -1):
			_undo_move(done[i])
	return float(wins) / maxf(games, 1)


## Share of `games` played by a HEURISTIC player, a closer model of a
## person who has understood the rules: a move that turns no spinner (and
## fires no switch / rams no shell) can never spoil the board, so it plays
## those first (any of them, at random); only when every legal move is
## "risky" does it think, picking among the risky moves that do not lead to
## a visible dead end within `depth` moves. Deterministic per seed.
func heuristic_win_rate(games: int, depth: int, seed: int) -> float:
	if _alive_count == _crate_n:
		return 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wins := 0
	var done: Array[int] = []
	for k in games:
		done.clear()
		while true:
			var legal := legal_moves()
			if legal.is_empty():
				break
			var calm: Array[int] = []
			for mv in legal:
				if not _is_risky(mv):
					calm.append(mv)
			var pool: Array[int] = calm
			if pool.is_empty():
				for mv in legal:
					_do(mv)
					if not _dead_within(depth):
						pool.append(mv)
					_undo_move(mv)
			if pool.is_empty():
				pool = legal
			var pick: int = pool[rng.randi() % pool.size()]
			_do(pick)
			done.append(pick)
		if _alive_count == _crate_n:
			wins += 1
		for i in range(done.size() - 1, -1, -1):
			_undo_move(done[i])
	return float(wins) / maxf(games, 1)


## True if every way of playing `depth` more moves gets stuck (blocks left,
## no legal move) - a dead end a person could see by looking ahead.
func _dead_within(depth: int) -> bool:
	if _alive_count == _crate_n:
		return false
	var legal := legal_moves()
	if legal.is_empty():
		return true
	if depth <= 0:
		return false
	for mv in legal:
		_do(mv)
		var dead := _dead_within(depth - 1)
		_undo_move(mv)
		if not dead:
			return false
	return true


## Best move for a hint: a legal move after which the board is still
## solvable. Prefers the real decisions (moves that turn spinners or fire a
## switch) over always-safe moves. Returns the block id to tap, or -1 if no
## legal move keeps the board solvable.
func recommend_move() -> int:
	if _crate_n > 0:
		# v0.8 Movable boards: the next move of an actual solution from here.
		# (The rule below prefers "risky" moves, and every push is one - so
		# following hint after hint could push a block back and forth for
		# ever while each single hint stayed legal and safe.) Always legal,
		# always keeps the board solvable, and always makes progress.
		if _alive_count == _crate_n:
			return -1
		var sol := solve_moves()
		return sol[0] & ID_MASK if not sol.is_empty() else -1
	var safe_pick := -1
	for mv in legal_moves():
		_do(mv)
		var ok := _alive_count == _crate_n or not _solve_keep_state().is_empty()
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
		# Human-facing (Challenge a Friend): steps along the solution where
		# several moves are legal but exactly ONE keeps the board solvable,
		# and the average number of safe moves per step.
		"one_safe_steps": 0, "safe_choices": 0.0,
		# Locks (planning): steps where at least one block has a clear lane
		# but is still LOCKED (looks free, isn't), the total of such
		# block-steps, and the average solution step at which a lock opens.
		"locked_free_steps": 0, "lock_wait": 0, "unlock_step": 0.0,
		# Opening: legal moves at the start that keep the board solvable,
		# and legal moves that turn no spinner (always safe, so obvious to a
		# player who knows the rules).
		"start_safe": 0, "start_calm": 0,
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
	m["solvable"] = _alive_count == _crate_n or not solution.is_empty()
	m["solution"] = _strip(solution)
	if not m["solvable"]:
		return m
	# Walk the solution; at every state count legal moves that are traps
	# (legal now, but the board becomes unsolvable afterwards).
	var applied: Array = []
	var round_free: Array[int] = legal_moves()
	var depth := 1
	var legal_sum := 0
	var safe_sum := 0
	var opened := {}  # locked id -> step it opened
	for step in solution.size():
		var tempting := 0
		for id in _alive.size():
			if _alive[id] == 1 and _lock[id] >= 0:
				if _color_count[_lock[id]] > 0:
					if _is_free(id):
						tempting += 1
				elif not opened.has(id):
					opened[id] = step
		if tempting > 0:
			m["locked_free_steps"] += 1
			m["lock_wait"] += tempting
		var traps := 0
		var legal := legal_moves()
		legal_sum += legal.size()
		for mv in legal:
			if not _is_risky(mv):
				continue  # safe moves are never traps
			_do(mv)
			var ok := _alive_count == _crate_n or not _solve_keep_state().is_empty()
			_undo_move(mv)
			if not ok:
				traps += 1
				if _switch[mv & ID_MASK] >= 0:
					m["switch_decisions"] += 1
		if step == 0:
			m["start_traps"] = traps
			m["start_safe"] = legal.size() - traps
			for mv in legal:
				if not _is_risky(mv):
					m["start_calm"] += 1
		if traps > 0:
			m["decision_points"] += 1
			m["trap_moves"] += traps
		safe_sum += legal.size() - traps
		if legal.size() > 1 and legal.size() - traps == 1:
			m["one_safe_steps"] += 1
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
	m["safe_choices"] = snappedf(float(safe_sum) / maxf(solution.size(), 1), 0.01)
	if not opened.is_empty():
		m["unlock_step"] = snappedf(opened.values().reduce(func(a, b): return a + b, 0) / float(opened.size()), 0.01)
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
	if solution.is_empty() and _alive_count > _crate_n:
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
		out.append(_alive_count > _crate_n and _solve_keep_state().is_empty())
		_undo_move(mv)
	return out


# --- Search ----------------------------------------------------------------

func _solve_keep_state() -> Array[int]:
	# Solve from the current (possibly mutated) state without disturbing it.
	var saved_path := _path.duplicate()
	var saved_failed := _failed
	var saved_on_path := _on_path
	_failed = {}
	_on_path = {}
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
	_on_path = saved_on_path
	if ok and result.is_empty():
		result = [-1]  # solved with zero moves (already empty)
	return result


func _dfs() -> bool:
	if _crate_n > 0:
		return _dfs_crates(_path.size())
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
				if _spinner_neighbours(id) == 0 and _switch[id] < 0 and (_shells == 0 or _turnable[id] == 0) and not _pending(id) \
						and _partner(id) < 0:
					_apply(id)
					safe.append(id)
					_path.append(id)
					progress = true
			elif not _armored_ids.is_empty() and _ram_target(id) != -1:
				_do(id | RAM)
				safe.append(id | RAM)
				_path.append(id | RAM)
				progress = true
	if _alive_count == _crate_n:
		return true
	var key := _key()
	if not _failed.has(key):
		# 2) Branch on moves that turn spinners or fire a switch.
		for id in _alive.size():
			if _alive[id] == 1 and _is_legal(id) and not (_partner(id) >= 0 and _partner(id) < id):
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
	if not _seq_ids.is_empty():
		var stages := 0
		for i in _seq_ids.size():
			stages |= (1 if _seq_stage[_seq_ids[i]] == 1 else 0) << (i % 62)
		parts.append("s" + str(stages))
	if _crate_n > 0:
		var cells := PackedStringArray()
		for cid in _crate_ids:
			cells.append(str(_cell[cid]))
		parts.append("m" + ",".join(cells))
	if not _armored_ids.is_empty():
		var shells := 0
		for i in _armored_ids.size():
			shells |= _armor[_armored_ids[i]] << (i % 62)
		parts.append(str(shells))
	return ":".join(parts)


## A move that may hurt: it turns spinners, fires a switch, or (while shells
## remain) removes a block that could still turn into a rammer.
func _is_risky(move: int) -> bool:
	if move & PUSH:
		return true
	if move & RAM:
		return false
	return _spinner_neighbours(move) > 0 or _switch[move] >= 0 or (_shells > 0 and _turnable[move] == 1) or _pending(move) \
			or _partner(move) >= 0


## Can escape now: not a gate, not hidden, not locked, not armored, lane clear.
## Twins: both twins can, each lane ignoring the partner's cell.
func _is_legal(id: int) -> bool:
	var p := _partner(id)
	if p < 0:
		return _is_legal_one(id)
	_grid[_cell[p]] = -1
	var own := _is_legal_one(id)
	_grid[_cell[p]] = p
	if not own:
		return false
	_grid[_cell[id]] = -1
	var other := _is_legal_one(p)
	_grid[_cell[id]] = id
	return other


## Twins: the live partner of `id`, or -1.
func _partner(id: int) -> int:
	if _twin.is_empty():
		return -1
	var p := _twin[id]
	return p if p >= 0 and _alive[p] == 1 else -1


func _is_legal_one(id: int) -> bool:
	if _gate[id] == 1 or _armor[id] == 1:
		return false
	if _crate_n > 0 and _crate[id] == 1:
		return false
	if _hidden[id] == 1 and _is_concealed(id):
		return false
	if _lock[id] >= 0 and _color_count[_lock[id]] > 0:
		return false
	return _is_free(id)


## If `id` could be tapped and its lane runs straight into a shelled block,
## that block's id (a ram); else -1.
func _ram_target(id: int) -> int:
	if _partner(id) >= 0:
		return -1  # twins never ram
	if _gate[id] == 1 or _armor[id] == 1:
		return -1
	if _crate_n > 0 and _crate[id] == 1:
		return -1
	if _hidden[id] == 1 and _is_concealed(id):
		return -1
	if _lock[id] >= 0 and _color_count[_lock[id]] > 0:
		return -1
	var t := _first_in_lane(id)
	return t if t >= 0 and _armor[t] == 1 else -1


## Still hidden: no neighbour (at construction time) has escaped yet - or,
## Sequence, advanced past its first stage (the same neighbour
## event; a block that was already in stage 2 at construction had revealed
## its neighbours then, so this stays exact).
func _is_concealed(id: int) -> bool:
	if _hidden[id] == 0:
		return false
	for n in _neighbours[id]:
		if _alive[n] == 0:
			return false
		if not _seq_ids.is_empty() and _seq_stage[n] == 2:
			return false
	return true


## Sequence: a first-stage block (its legal move is an advance).
func _pending(id: int) -> bool:
	return not _seq_ids.is_empty() and _seq_stage[id] == 1


func _is_free(id: int) -> bool:
	return _first_in_lane(id) == -1


## The first block in `id`'s arrow direction, or -1 if the lane is clear.
func _first_in_lane(id: int) -> int:
	if _has_portals:
		return _first_in_portal_lane(id)
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


## Portal: the same walk, continuing from a portal's partner in
## the same direction. Entering a portal twice (or running past the step
## limit) means the lane loops: LANE_LOOP.
func _first_in_portal_lane(id: int) -> int:
	var idx := _cell[id]
	var c := idx % columns
	var r := idx / columns
	var step: Vector2i = Direction.STEPS[_dir[id]]
	c += step.x
	r += step.y
	var entered := {}
	var limit := (rows + columns) * 9 + 4
	var steps := 0
	while c >= 0 and r >= 0 and c < columns and r < rows:
		steps += 1
		if steps > limit:
			return LANE_LOOP
		var i := r * columns + c
		if i == idx:
			return LANE_LOOP  # back at its own cell: a looping layout
		var to := _portal_exit[i]
		if to != -1:
			if entered.has(i):
				return LANE_LOOP
			entered[i] = true
			c = to % columns + step.x
			r = to / columns + step.y
			continue
		var o := _grid[i]
		if o != -1:
			return o
		c += step.x
		r += step.y
	return -1


func _spinner_neighbours(id: int) -> int:
	var p := _partner(id)
	if p >= 0:
		return _spinner_neighbours_one(id) + _spinner_neighbours_one(p)
	return _spinner_neighbours_one(id)


func _spinner_neighbours_one(id: int) -> int:
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
	if move & PUSH:
		_do_push(move & ID_MASK)
		return
	if move & RAM:
		_armor[_first_in_lane(move & ID_MASK)] = 0
		_shells -= 1
	else:
		_apply(move)


## Exact inverse of _do (LIFO order).
func _undo_move(move: int) -> void:
	if move & PUSH:
		_undo_push(move & ID_MASK)
		return
	if move & RAM:
		_armor[_first_in_lane(move & ID_MASK)] = 1
		_shells += 1
	else:
		_undo(move)


## Removes `id`: turns adjacent spinners, fires its switch, and opens its
## Chain Gate if it was the last link. Returns the turned spinner ids.
## Twins: the pair leaves as one move. Removing them one after the other is
## the same event as BoardModel.remove_pair: no cell touches both twins
## (each adjacent spinner turns once), twins are never switches or
## spinners, and a gate opened by the first is never a spinner next to the
## second.
func _apply(id: int) -> Array:
	var p := _partner(id)
	if p < 0:
		return _apply_one(id)
	var turned := _apply_one(id)
	turned.append_array(_apply_one(p))
	return turned


func _apply_one(id: int) -> Array:
	if _pending(id):
		return _advance(id)
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


## Sequence: the first stage. Neighbour event around its cell
## (spinners turn, hidden reveal is derived), then the next arrow.
func _advance(id: int) -> Array:
	var idx := _cell[id]
	var c := idx % columns
	var r := idx / columns
	var turned := []
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
	_dir[id] = _seq_next[id]
	_seq_stage[id] = 2
	return turned


## Exact inverse of _advance.
func _unadvance(id: int) -> void:
	_seq_stage[id] = 1
	_dir[id] = _seq_first[id]
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


## MOVABLE: the cell the crate first in `id`'s lane would be
## pushed to (one cell in `id`'s direction, through portals as any lane,
## onto an empty cell), or -1 (no crate first in the lane / no room).
## Same conditions as a ram for the tapped block itself.
func _push_target(id: int) -> int:
	if _partner(id) >= 0:
		return -1  # twins never push
	if _gate[id] == 1 or _armor[id] == 1 or _crate[id] == 1:
		return -1
	if _hidden[id] == 1 and _is_concealed(id):
		return -1
	if _lock[id] >= 0 and _color_count[_lock[id]] > 0:
		return -1
	var t := _first_in_lane(id)
	if t < 0 or _crate[t] == 0:
		return -1
	var idx := _cell[t]
	var step: Vector2i = Direction.STEPS[_dir[id]]
	var c := idx % columns + step.x
	var r := idx / columns + step.y
	var entered := {}
	while c >= 0 and r >= 0 and c < columns and r < rows:
		var i := r * columns + c
		if _has_portals and _portal_exit[i] != -1:
			if entered.has(i):
				return -1
			entered[i] = true
			c = _portal_exit[i] % columns + step.x
			r = _portal_exit[i] / columns + step.y
			continue
		return i if _grid[i] == -1 else -1
	return -1


func _do_push(id: int) -> void:
	var t := _first_in_lane(id)
	var dest := _push_target(id)
	var from := _cell[t]
	_grid[from] = -1
	_grid[dest] = t
	_cell[t] = dest
	var adv := _pending(id)
	if adv:
		_advance(id)
	_push_stack.append([t, from, adv])


func _undo_push(id: int) -> void:
	var e: Array = _push_stack.pop_back()
	if e[2]:
		_unadvance(id)
	var t: int = e[0]
	_grid[_cell[t]] = -1
	_grid[e[1]] = t
	_cell[t] = e[1]


## MOVABLE search: plain DFS over every legal move (no greedy
## moves - with crates moving into lanes, no escape is safe for sure), with
## the states on the current path cut off (a crate pushed back and forth)
## and a state remembered as lost only when no cycle through an ancestor
## was cut below it (Tarjan-style low link: sound, never prunes a winner).
func _dfs_crates(depth: int) -> bool:
	nodes += 1
	if nodes > node_limit:
		aborted = true
		return false
	if _alive_count == _crate_n:
		return true
	var key := _key()
	if _failed.has(key):
		_last_low = 1 << 30
		return false
	if _on_path.has(key):
		_last_low = _on_path[key]
		return false
	_on_path[key] = depth
	var low := depth
	# v0.8: escapes, first stages and rams before pushes - a solution then
	# pushes only when it has to, so following SHOW A MOVE step by step
	# does not wander (a push can be undone by another push; nothing else
	# can).
	var moves := legal_moves()
	var ordered: Array[int] = []
	for mv in moves:
		if not (mv & PUSH):
			ordered.append(mv)
	for mv in moves:
		if mv & PUSH:
			ordered.append(mv)
	for mv in ordered:
		_do(mv)
		_path.append(mv)
		if _dfs_crates(depth + 1):
			_on_path.erase(key)
			return true
		low = mini(low, _last_low)
		_path.pop_back()
		_undo_move(mv)
		if aborted:
			break
	_on_path.erase(key)
	if not aborted and low >= depth:
		_failed[key] = true
	_last_low = low
	return false


## v0.6.1 armor safety: walks EVERY state a player can reach (every escape
## and ram, in every order) and looks for dead ends that still hold an intact
## shell. Such a shell can never be cracked again, so the level would need
## the Hammer. Returns {"states", "complete", "dead_ends", "armor_dead_ends",
## "example", "boards"} ("boards": each dead-end board as "id =id ...", "="
## marking an intact shell) where "example" is one tap sequence (RAM-marked) into an armor
## dead end. "complete" is false if `state_limit` states were not enough.
func armor_audit(state_limit: int = 400000) -> Dictionary:
	var out := {"states": 0, "complete": true, "dead_ends": 0, "armor_dead_ends": 0, "example": [], "boards": {}}
	if _armored_ids.is_empty():
		return out
	var seen := {}
	var path: Array[int] = []
	_audit_walk(seen, path, out, state_limit)
	out["states"] = seen.size()
	return out


func _audit_walk(seen: Dictionary, path: Array[int], out: Dictionary, limit: int) -> void:
	var key := _key()
	if seen.has(key):
		return
	if seen.size() >= limit:
		out["complete"] = false
		return
	seen[key] = true
	if _alive_count == _crate_n:
		return
	var moves := legal_moves()
	if moves.is_empty():
		# Count boards, not search states (a spinner that already left keeps
		# its last direction in the key).
		var board := PackedStringArray()
		for id in _alive.size():
			if _alive[id] == 1:
				board.append(("=" if _armor[id] == 1 else "") + str(id))
		var desc := " ".join(board)
		if not (out["boards"] as Dictionary).has(desc):
			out["boards"][desc] = true
			out["dead_ends"] += 1
			if _shells > 0:
				out["armor_dead_ends"] += 1
				if (out["example"] as Array).is_empty():
					out["example"] = path.duplicate()
		return
	for mv in moves:
		_do(mv)
		path.append(mv)
		_audit_walk(seen, path, out, limit)
		path.pop_back()
		_undo_move(mv)


## Undo a successful search's moves (the search leaves them applied).
func _rewind(path: Array[int]) -> void:
	for i in range(path.size() - 1, -1, -1):
		_undo_move(path[i])


## Puts `id` back: closes the gate it opened, un-flips its switch targets
## and turns its spinner neighbours back. Must be called in reverse order
## of _apply, so the neighbours are exactly those turned.
func _undo(id: int, _turned: Array = []) -> void:
	if not _twin.is_empty() and _twin[id] >= 0 and _alive[id] == 0:
		_undo_one(_twin[id])  # the pair left together: LIFO
	_undo_one(id)


func _undo_one(id: int) -> void:
	if _alive[id] == 1 and not _seq_ids.is_empty() and _seq_stage[id] == 2:
		_unadvance(id)  # the move was the advance (the block never left)
		return
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
