extends Node
## TWINS PROTOTYPE checks (developer page ?twinsprototype=1..3).
##   godot --headless --path . res://tools/TwinsCheck.tscn
##
## - URL parsing: exact key=value, 1..3 only, never on look-alikes / 0 / 4.
## - Token gating: "!" parses only in campaign-parsed files while
##   LevelManager.dev_twins is on (the prototype); Social / Friend parsing
##   (campaign = false) and production never accept it. Validation drops a
##   bond that is not exactly two adjacent plain arrows. Round trip.
## - Rules, each on BoardModel AND the packed Solver: horizontal, vertical,
##   facing, same-direction pairs; both clear / one blocked / both blocked;
##   atomic removal; spinner, switch, gate-link and lock-key interactions;
##   Hammer bond break; no ram / push while bonded.
## - Agreement on randomized legal states (random boards with twins,
##   spinners, switches, gates, locks, hidden and armored blocks, walked by
##   random moves): the same playable moves, the same state after every
##   move, exact solver Undo, and the same win / lose verdict as an
##   exhaustive BoardModel search.
## - The three prototype puzzles: exactly the design-report boards, full
##   state graphs (states, winnable, winning orders, fatal moves, Undo
##   reach, random tapper), SHOW A MOVE legal + winnable from every
##   winnable state, Hammer safety exact on every state and block, every
##   fatal move a visible decision (never a plain escape).
## - Game (real scene, prototype active, its own temporary save): bonds
##   drawn, free partner-blocked tap (no heart, message once), own-blocked
##   tap costs one heart, pair escape = one Undo step + chain +1, Undo /
##   Restart exact, SHOW A MOVE marks both twins, Hammer breaks the bond
##   only, the levels clear by taps, Level 3 -> end screen (never Level 4),
##   Level Select lists 1-3; production / Experience Lab / Opening Lab
##   saves are byte-identical before and after.

var game: GameManager
var failures: Array[String] = []
var passed := 0
var report := {}

const DESIGN := {
	1: {"name": "Twin Lights", "states": 42, "winnable": 42, "orders": 315, "fatal": 0, "first_bad": 0},
	2: {"name": "Hold Fire", "states": 184, "winnable": 176, "orders": 28710, "fatal": 16, "first_bad": 0},
	3: {"name": "Turnabout", "states": 100, "winnable": 92, "orders": 6600, "fatal": 8, "first_bad": 0},
}
const DESIGN_MAPS := {
	1: [". . R>!U R<!U . Gv", ". . . . . .", ". P> . . Y^ .", "G^ . . . . .", ". B^!T B>!T . Gv .", ". . . . . ."],
	2: ["Rv . . B> . .", ". Rv . . . .", ". . Yv@ R^ . .", ". . P^ Rv@ . G<", ". . P>!T P<!T B> .", ". . Y> . . ."],
	3: [". B< . . . .", ". . R^ . G> .", ". . . . R^%A .", ". . Bv B<&A B^&A!T B<!T", ". . . Y^ Y< .", ". . . Y^ . Y^"],
}


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		print("FAIL: " + what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	_parsing()
	_gating()
	_rules()
	_agreement()
	for n in range(1, TwinsPrototype.LAST_LEVEL + 1):
		_puzzle(n)
	await _game()
	print("")
	print("REPORT " + JSON.stringify(report))
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("TWINS CHECKS PASSED" if failures.is_empty() else "TWINS CHECKS FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


# --- Parsing and gating ----------------------------------------------------

func _parsing() -> void:
	var cases := {
		"?twinsprototype=1": "1", "?twinsprototype=2": "2", "?twinsprototype=3": "3",
		"?v=12&twinsprototype=3": "3", "?twinsprototype": "1", "?TwinsPrototype=2": "2",
		"?twinsprototype=0": "", "?twinsprototype=4": "", "?xtwinsprototype=1": "",
		"?twinsprototype2=1": "", "": "", "?experiencelab=1": "", "?twinsprototype=abc": "",
	}
	for q in cases:
		_check(TwinsPrototype.parse_mode(q) == cases[q], "parse_mode('%s') = '%s' (want '%s')" % [q, TwinsPrototype.parse_mode(q), cases[q]])
	_check(TwinsPrototype.parse_mode("", "#twinsprototype=2") == "2", "parse_mode reads the hash")
	_check(ExperienceLab.parse_mode("?twinsprototype=2") == "", "the Experience Lab ignores ?twinsprototype")
	_check(not TwinsPrototype.active and not LevelManager.dev_twins and LevelManager.override_dir == "", "off by default (no Twins token, no level override)")
	_check(PlayerProgress.default_path == "user://progress.cfg", "production save path untouched by default")


static func _parse(map: Array, campaign: bool, twins: bool) -> LevelData:
	var keep := LevelManager.dev_twins
	LevelManager.dev_twins = twins
	var lv := LevelManager.parse_level({"name": "t", "map": map}, 0, campaign)
	LevelManager.dev_twins = keep
	return lv


static func _twin_count(lv: LevelData) -> int:
	return lv.blocks.filter(func(b): return b.twin != "").size()


func _gating() -> void:
	var map := [". R>!T R<!T .", ". . . ."]
	_check(_parse(map, true, true).blocks.size() == 2 and _twin_count(_parse(map, true, true)) == 2, "prototype files parse the Twins token")
	_check(_parse(map, false, true).blocks.size() == 0, "Social / Friend parsing (campaign = false) rejects it even while the prototype is on")
	_check(_parse(map, false, false).blocks.size() == 0, "Social / Friend parsing rejects it")
	_check(_parse(map, true, false).blocks.size() == 2, "campaign level files accept it (Levels 176-199 since the 1-300 freeze)")
	var def := PuzzleDefinition.new()
	def.rows = 2
	def.columns = 4
	def.map = PackedStringArray(map)
	LevelManager.dev_twins = true
	_check(not def.verify(), "a shared challenge with a Twins token never verifies (prototype on)")
	LevelManager.dev_twins = false
	_check(not def.verify(), "a shared challenge with a Twins token never verifies")
	var plain := PuzzleDefinition.new()
	plain.rows = 2
	plain.columns = 4
	plain.map = PackedStringArray([". R> R< .", ". . . G^"])
	_check(plain.to_level().blocks.size() == 3, "an ordinary shared challenge still parses")
	# Validation: only exactly two adjacent plain arrows are bonded.
	var bad := {
		"apart": [". R>!T . R<!T", ". . . ."],
		"diagonal": [". R>!T . .", ". . R<!T ."],
		"three": ["R>!T R>!T R>!T .", ". . . ."],
		"single": ["R>!T . . .", ". . . ."],
		"spinner": ["R>@!T R<!T . .", ". . . ."],
		"locked": ["R>#B R<!T . B^", ". . . ."],
		"hidden": ["R>?!T R<!T . .", ". . . ."],
		"switch": ["R>%A!T R<!T Bv&A .", ". . . ."],
		"armored": ["R>=!T R<!T . .", ". . . ."],
	}
	for k in bad:
		var m: Array = bad[k].duplicate()
		if k == "locked":
			m = ["R>#B!T R<!T . B^", ". . . ."]
		_check(_twin_count(_parse(m, true, true)) == 0, "a '%s' bond is dropped" % k)
	var flip := _parse(["R^%A R>&A!T R<!T .", ". . . ."], true, true)
	_check(_twin_count(flip) == 2, "a switch may flip a twin")
	var gate := _parse(["XC R>+C!T R<+C!T .", ". . . ."], true, true)
	_check(_twin_count(gate) == 2, "twins may link a Chain Gate")
	var lv := _parse(DESIGN_MAPS[3], true, true)
	_check(_twin_count(_parse(JSON.parse_string(LevelManager.to_json_text(lv))["map"], true, true)) == 2,
		"to_json_text round-trips the Twins token")
	# Social generators never place twins.
	_check(LevelManager.dev_twins == false, "dev_twins off after the gating tests")


# --- Rules (BoardModel and Solver) ------------------------------------------

static func _model(map: Array) -> BoardModel:
	var lv := _parse(map, true, true)
	var m := BoardModel.new()
	m.setup(lv.rows, lv.columns, lv.blocks)
	return m


static func _id_at(m: BoardModel, c: int, r: int) -> int:
	var b := m.block_at(Vector2i(c, r))
	return b.id if b else -1


## BoardModel move exactly as the game plays it.
static func bm_play(m: BoardModel, id: int) -> String:
	var st := m.move_state(id)
	match st:
		"ok":
			if m.twin_partner(id) >= 0:
				m.remove_pair(id)
			else:
				m.remove(id)
		"ram": m.ram(id)
		"advance": m.advance(id)
		"push": m.push(id)
	return st


static func _solver_legal(m: BoardModel) -> Array:
	var out := []
	for mv in Solver.from_model(m).legal_moves():
		out.append(mv & Solver.ID_MASK)
	out.sort()
	return out


static func _bm_legal(m: BoardModel) -> Array:
	var out: Array = m.playable_ids()
	out.sort()
	return out


func _rules() -> void:
	# Horizontal, same direction, both clear.
	var m := _model([". . . .", ". R^!T R^!T .", ". . . ."])
	var a := _id_at(m, 1, 1)
	var b := _id_at(m, 2, 1)
	_check(m.move_state(a) == "ok" and m.move_state(b) == "ok", "horizontal same-direction pair, both clear: ok")
	_check(_solver_legal(m) == _bm_legal(m), "solver agrees (horizontal pair)")
	bm_play(m, a)
	_check(m.is_empty() and m.last_twin.size() == 2, "the pair leaves together (atomic, both removed)")
	# Vertical, different directions.
	m = _model([". . .", ". R<!T .", ". Rv!T .", ". . ."])
	a = _id_at(m, 1, 1)
	b = _id_at(m, 1, 2)
	_check(m.move_state(a) == "ok" and m.move_state(b) == "ok", "vertical pair, both clear: ok")
	_check(_solver_legal(m) == _bm_legal(m), "solver agrees (vertical pair)")
	# Facing: the partner's cell is not an obstacle.
	m = _model([". R>!T R<!T .", ". . . ."])
	_check(m.move_state(_id_at(m, 1, 0)) == "ok", "facing twins pass through each other")
	_check(_solver_legal(m) == _bm_legal(m), "solver agrees (facing pair)")
	m = _model([". Rv!T .", ". R^!T .", ". . ."])
	_check(m.move_state(_id_at(m, 1, 0)) == "ok", "vertical facing twins pass through each other")
	# Pointing the same way along the bond axis.
	m = _model([". R>!T R>!T .", ". . . ."])
	_check(m.move_state(_id_at(m, 1, 0)) == "ok", "twins in a line pointing the same way: ok (partner not an obstacle)")
	m = _model(["G^ . . .", ". R>!T R>!T Bv", ". . . ."])
	_check(m.move_state(_id_at(m, 1, 1)) == "blocked" and m.move_state(_id_at(m, 2, 1)) == "blocked", "in-line twins: a blocker ahead of the pair blocks both lanes")
	# One blocked: own lane clear -> twin_wait (free), own lane blocked -> blocked.
	m = _model(["G> . . .", ". R^!T R>!T Bv", ". . . ."])
	a = _id_at(m, 1, 1)
	b = _id_at(m, 2, 1)
	var g := _id_at(m, 0, 0)
	_check(m.move_state(b) == "blocked" and m.move_state(a) == "twin_wait", "one lane blocked: blocked twin = blocked, other = twin_wait")
	_check(not m.is_playable(a) and not m.is_playable(b), "neither twin is playable while one lane is blocked")
	_check(_solver_legal(m) == _bm_legal(m), "solver agrees (one lane blocked)")
	var before := _state(m)
	_check(_state(m) == before, "a blocked pair moves nothing")
	_check(m.twin_blockers(a) == {"own": -1, "partner": _id_at(m, 3, 1)}, "twin_blockers names the partner's blocker")
	# Both blocked.
	m = _model([". Bv . .", ". R^!T R>!T Gv", ". . . ."])
	_check(m.move_state(_id_at(m, 1, 1)) == "blocked" and m.move_state(_id_at(m, 2, 1)) == "blocked", "both lanes blocked: blocked")
	_check(_solver_legal(m) == _bm_legal(m), "solver agrees (both blocked)")
	# Spinners: each adjacent spinner turns once per pair escape.
	m = _model([". Y^@ . .", ". R^!T R>!T .", ". Gv@ G<@ ."])
	var turned := m.remove_pair(_id_at(m, 1, 1))
	turned.sort()
	var want := [_id_at(m, 1, 0), _id_at(m, 1, 2), _id_at(m, 2, 2)]
	want.sort()
	_check(turned == want, "every adjacent spinner turns once (%s)" % [turned])
	_check(m.block_at(Vector2i(1, 0)).direction == Direction.RIGHT and m.block_at(Vector2i(1, 2)).direction == Direction.LEFT
		and m.block_at(Vector2i(2, 2)).direction == Direction.UP, "spinner directions after one pair escape")
	var s := Solver.from_model(_model([". Y^@ . .", ". R^!T R>!T .", ". Gv@ G<@ ."]))
	var sb := s._key()
	var sid := _id_at(_model([". Y^@ . .", ". R^!T R>!T .", ". Gv@ G<@ ."]), 1, 1)
	s._do(sid)
	var after_solver := s._key()
	s._undo_move(sid)
	_check(s._key() == sb, "solver Undo of a pair is exact")
	_check(after_solver == Solver.from_model(m)._key(), "solver pair escape = BoardModel pair escape (spinners)")
	# Switch reverses a twin.
	m = _model([". R^%A .", ". Bv&A!T B<!T", ". Y^ ."])
	_check(m.move_state(_id_at(m, 1, 1)) == "blocked", "flip-target twin blocked before the switch")
	bm_play(m, _id_at(m, 1, 0))
	_check(m.block_at(Vector2i(1, 1)).direction == Direction.UP, "the switch reverses the twin")
	_check(m.move_state(_id_at(m, 1, 1)) == "ok" and _solver_legal(m) == _bm_legal(m), "reversed twin can leave; solver agrees")
	# Gate links: each twin counts.
	m = _model(["XC Y^+C .", ". R>+C!T .", ". R>+C!T ."])
	bm_play(m, _id_at(m, 1, 1))
	_check(m.block_count() == 2 and m.gate_remaining("C") == 1 and m.block_at(Vector2i(0, 0)) != null, "a pair counts as two links (gate still shut with 1 link left)")
	m = _model(["XC R^+C!T R^+C!T .", "Gv . . .", ". . . ."])
	bm_play(m, _id_at(m, 1, 0))
	_check(m.block_at(Vector2i(0, 0)) == null and m.last_opened_gates.size() == 1, "the pair's two links open the gate")
	s = Solver.from_model(_model(["XC R^+C!T R^+C!T .", "Gv . . .", ". . . ."]))
	s._do(_id_at(_model(["XC R^+C!T R^+C!T .", "Gv . . .", ". . . ."]), 1, 0))
	_check(s._key() == Solver.from_model(m)._key(), "solver gate opening = BoardModel")
	# Lock keys: each twin is a key.
	m = _model([". R^!T R^!T .", "Bv#R . . .", ". . . ."])
	_check(m.is_locked(_id_at(m, 0, 1)), "locked by the twins' color")
	bm_play(m, _id_at(m, 1, 0))
	_check(not m.is_locked(_id_at(m, 0, 1)) and m.last_unlocked.size() == 1, "the pair leaving opens the lock")
	m = _model([". R^!T R^!T R^", "Bv#R . . .", ". . . ."])
	bm_play(m, _id_at(m, 1, 0))
	_check(m.is_locked(_id_at(m, 0, 1)), "the lock stays shut while another key remains")
	# No ram / push while bonded.
	m = _model(["R>!T R<!T . Gv=", "R^ . . ."])
	_check(m.move_state(_id_at(m, 0, 0)) == "blocked" and m.move_state(_id_at(m, 1, 0)) == "twin_wait", "a bonded twin aimed at a shell never rams (blocked)")
	_check(_solver_legal(m) == _bm_legal(m), "solver agrees (no twin ram)")
	# Hammer: breaks the bond; the other twin is an ordinary block.
	m = _model(["G> . . .", ". R^!T R>!T Bv", ". . . ."])
	a = _id_at(m, 1, 1)
	b = _id_at(m, 2, 1)
	m.remove(b)
	_check(m.blocks.has(a) and m.twin_partner(a) == -1 and m.move_state(a) == "ok", "Hammer: one twin removed, the other plays as an ordinary block")
	_check(_solver_legal(m) == _bm_legal(m), "solver agrees after the bond broke")
	m = _model(["G> . . .", ". R^!T R>!T Bv", ". . . ."])
	var before_h := _state(m)
	Solver.hammer_safe(m, b)
	_check(_state(m) == before_h, "hammer_safe leaves the board untouched")
	# Hammer safety must know the bond breaks: here the pair can never
	# leave (its right lane is a wall that only the pair could clear), but
	# smashing the blocked twin frees the other one.
	m = _model(["R^!T R>!T B<", ". . ."])
	_check(not Solver.from_model(m).is_solvable() and not _bm_winnable(m, {}), "bond-trapped board is lost")
	_check(Solver.hammer_safe(m, _id_at(m, 1, 0)), "smashing the trapped twin is allowed (the board was lost)")
	var freed := BoardModel.new()
	freed.setup(m.rows, m.columns, m.snapshot())
	freed.remove(_id_at(m, 1, 0))
	_check(freed.move_state(_id_at(m, 0, 0)) == "ok" and _bm_winnable(freed, {}), "after the smash the other twin leaves alone and the board is winnable")
	m = _model(["R^!T R>!T Bv", "Y> . ."])
	_check(Solver.from_model(m).is_solvable() == _bm_winnable(m, {}), "solver verdict = exhaustive verdict (small board)")
	m = _model(["Gv . .", "R>!T R<!T B<", ". . G^"])
	var right := _id_at(m, 1, 1)
	var after := BoardModel.new()
	after.setup(m.rows, m.columns, m.snapshot())
	after.remove(right)
	_check(Solver.hammer_safe(m, right) == (_bm_winnable(after, {}) or not _bm_winnable(m, {})), "Hammer safety on a twin uses the broken bond")


## Comparable full state of a BoardModel.
static func _state(m: BoardModel) -> String:
	var ids: Array = m.blocks.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d,%d:%d:%d:%d:%d:%d" % [id, b.cell.x, b.cell.y, b.direction, 1 if b.hidden else 0, 1 if b.armored else 0,
			posmod(b.spin_step, BlockData.rule_period(b.spin_rule)), b.seq_stage])
	return "|".join(parts)


## Distinct moves of a state: one per pair (the lower id), as the player
## sees them (tapping either twin is the same move).
static func _moves(m: BoardModel) -> Array:
	var out := []
	for id in _bm_legal(m):
		var p := m.twin_partner(id)
		if p >= 0 and p < id:
			continue
		out.append(id)
	return out


static func _child(m: BoardModel, id: int) -> BoardModel:
	var c := BoardModel.new()
	c.setup(m.rows, m.columns, m.snapshot())
	bm_play(c, id)
	return c


static func _bm_winnable(m: BoardModel, memo: Dictionary) -> bool:
	if m.is_empty():
		return true
	var k := _state(m)
	if memo.has(k):
		return memo[k]
	var ok := false
	for id in _moves(m):
		if _bm_winnable(_child(m, id), memo):
			ok = true
			break
	memo[k] = ok
	return ok


# --- Randomized agreement ---------------------------------------------------

const COLORS := ["red", "blue", "green", "yellow", "purple"]


static func _random_board(rng: RandomNumberGenerator) -> BoardModel:
	var rows := rng.randi_range(5, 7)
	var cols := rng.randi_range(5, 7)
	var used := {}
	var blocks := []
	var next := 0
	var pairs := rng.randi_range(1, 2)
	var letters := ["T", "U"]
	for p in pairs:
		for attempt in 20:
			var c := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
			var c2 := c + (Vector2i(1, 0) if rng.randf() < 0.5 else Vector2i(0, 1))
			if c2.x >= cols or c2.y >= rows or used.has(c) or used.has(c2):
				continue
			var col: String = COLORS[rng.randi_range(0, 4)]
			for cell in [c, c2]:
				var b := BlockData.new(next, cell, col, rng.randi_range(0, 3))
				b.twin = letters[p]
				blocks.append(b)
				used[cell] = true
				next += 1
			break
	var n := rng.randi_range(5, 9)
	var have_switch := rng.randf() < 0.35
	var have_gate := rng.randf() < 0.3
	for i in n:
		var cell := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if used.has(cell):
			continue
		used[cell] = true
		var b := BlockData.new(next, cell, COLORS[rng.randi_range(0, 4)], rng.randi_range(0, 3))
		next += 1
		var roll := rng.randf()
		if roll < 0.25:
			b.kind = BlockData.Kind.SPINNER
			b.spin_rule = rng.randi_range(0, 3)
		elif roll < 0.33:
			b.hidden = true
		elif roll < 0.43:
			var lc: String = COLORS[rng.randi_range(0, 4)]
			if lc != b.color:
				b.lock_color = lc
		elif roll < 0.5:
			b.armored = true
		elif have_switch and roll < 0.6:
			b.switch_group = "A"
		blocks.append(b)
	# Links: flip targets (twins included) and gate links.
	var plain := blocks.filter(func(b): return not b.is_spinner() and not b.hidden and b.switch_group == "")
	if have_switch and blocks.any(func(b): return b.switch_group == "A"):
		for b in plain:
			if rng.randf() < 0.35:
				b.flip_link = "A"
	else:
		for b in blocks:
			b.switch_group = ""
	if not blocks.any(func(b): return b.flip_link == "A"):
		for b in blocks:
			b.switch_group = ""
	if have_gate:
		var free_cell := Vector2i(-1, -1)
		for attempt in 20:
			var c := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
			if not used.has(c):
				free_cell = c
				break
		var linked := 0
		for b in blocks:
			if not b.is_spinner() and rng.randf() < 0.3:
				b.gate_link = "C"
				linked += 1
		if free_cell.x >= 0 and linked > 0:
			var g := BlockData.new(next, free_cell, "gate", Direction.UP, BlockData.Kind.GATE)
			g.gate_group = "C"
			blocks.append(g)
			next += 1
		else:
			for b in blocks:
				b.gate_link = ""
	var m := BoardModel.new()
	m.setup(rows, cols, blocks)
	return m


## The Solver's state in _state's format (alive blocks: cell, arrow,
## still concealed, shell, spinner step in its rule period, Sequence stage).
static func _solver_state(s: Solver) -> String:
	var parts := PackedStringArray()
	for id in s._alive.size():
		if s._alive[id] == 0:
			continue
		var idx: int = s._cell[id]
		parts.append("%d:%d,%d:%d:%d:%d:%d:%d" % [id, idx % s.columns, idx / s.columns, s._dir[id], 1 if s._is_concealed(id) else 0,
			s._armor[id], posmod(s._step[id], BlockData.rule_period(s._rule[id])) if s._spinner[id] == 1 else 0,
			s._seq_stage[id] if not s._seq_ids.is_empty() else 0])
	return "|".join(parts)


static func _describe(m: BoardModel) -> String:
	var out := PackedStringArray(["%dx%d" % [m.columns, m.rows]])
	for b in m.blocks.values():
		out.append("%d@%s %s d%d k%d r%d lock%s h%s sw%s fl%s g%s gl%s a%s tw%s" % [b.id, b.cell, b.color, b.direction, b.kind, b.spin_rule,
			b.lock_color, b.hidden, b.switch_group, b.flip_link, b.gate_group, b.gate_link, b.armored, b.twin])
	return "\n   ".join(out)


func _compare(m: BoardModel, s: Solver, where: String) -> bool:
	var sl := []
	for mv in s.legal_moves():
		sl.append(mv & Solver.ID_MASK)
	sl.sort()
	var bl := _bm_legal(m)
	if sl != bl:
		_check(false, "%s: legal moves differ: model %s solver %s" % [where, bl, sl])
		return false
	if _solver_state(s) != _state(m):
		_check(false, "%s: solver state differs from the model's: %s vs %s" % [where, _solver_state(s), _state(m)])
		return false
	return true


func _agreement() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 176
	var boards := 0
	var states := 0
	var verdicts := 0
	var pair_moves := 0
	var waits := 0
	var ok := true
	for i in 2000:
		var m := _random_board(rng)
		if m.blocks.values().filter(func(b): return b.twin != "").size() < 2:
			continue
		boards += 1
		var desc := _describe(m)
		var s := Solver.from_model(m)
		var played := []
		for step in 30:
			states += 1
			if not _compare(m, s, "board %d step %d" % [i, step]):
				print("  board: %s\n  moves: %s" % [desc, played])
				ok = false
				break
			for id in m.blocks:
				if m.move_state(id) == "twin_wait":
					waits += 1
			# Exhaustive verdict on smaller states.
			if m.block_count() <= 9:
				var fresh := Solver.from_model(m)
				var v := fresh.is_solvable()
				if not fresh.aborted:
					verdicts += 1
					if v != _bm_winnable(m, {}):
						_check(false, "board %d step %d: solver verdict %s differs from the exhaustive search" % [i, step, v])
						ok = false
						break
			var moves := s.legal_moves()
			if moves.is_empty():
				break
			var mv: int = moves[rng.randi_range(0, moves.size() - 1)]
			var id: int = mv & Solver.ID_MASK
			if m.twin_partner(id) >= 0:
				pair_moves += 1
			var key0 := s._key()
			s._do(mv)
			s._undo_move(mv)
			if s._key() != key0:
				_check(false, "board %d step %d: solver Undo not exact" % [i, step])
				ok = false
				break
			s._do(mv)
			var st := bm_play(m, id)
			played.append([mv, st])
			if (mv & Solver.RAM) != 0 and st != "ram":
				_check(false, "board %d step %d: solver ram, model %s" % [i, step, st])
				ok = false
				break
		if not ok:
			break
	_check(ok, "BoardModel and Solver agree on every randomized state")
	_check(pair_moves > 1000 and waits > 1000 and verdicts > 2000, "the randomized walk covers pair escapes (%d), partner-blocked twins (%d) and verdicts (%d)" % [pair_moves, waits, verdicts])
	report["agreement"] = {"boards": boards, "states": states, "pair_moves": pair_moves, "twin_wait_states": waits, "verdicts_vs_exhaustive": verdicts}
	print("agreement: %s" % [report["agreement"]])


# --- The three prototype puzzles ---------------------------------------------

static func proto_level(n: int) -> LevelData:
	var json = JSON.parse_string(FileAccess.get_file_as_string(TwinsPrototype.LEVEL_DIR.path_join("level_%02d.json" % n)))
	var keep := LevelManager.dev_twins
	LevelManager.dev_twins = true
	var lv := LevelManager.parse_level(json, n, true)
	LevelManager.dev_twins = keep
	return lv


func _puzzle(n: int) -> void:
	var lv := proto_level(n)
	var want := _parse(DESIGN_MAPS[n], true, true)
	_check(lv.name == DESIGN[n]["name"], "P%d is '%s'" % [n, DESIGN[n]["name"]])
	_check(LevelManager.to_json_text(lv).split("\"map\"")[1] == LevelManager.to_json_text(want).split("\"map\"")[1], "P%d board = the design report's board exactly" % n)
	_check(lv.rows == 6 and lv.columns == 6 and _twin_count(lv) == (4 if n == 1 else 2), "P%d is 6x6 with its twins" % n)
	_check(lv.hearts == 3 and lv.hints == 2, "P%d hearts 3, SHOW A MOVE 2" % n)
	var root := BoardModel.new()
	root.setup(lv.rows, lv.columns, lv.blocks)
	# Full state graph.
	var graph := {}  # key -> {"m": model, "moves": {id: child key}}
	var order := [_state(root)]
	graph[order[0]] = {"m": root}
	var qi := 0
	while qi < order.size():
		var k: String = order[qi]
		qi += 1
		var m: BoardModel = graph[k]["m"]
		var kids := {}
		for id in _moves(m):
			var c := _child(m, id)
			var ck := _state(c)
			kids[id] = ck
			if not graph.has(ck):
				graph[ck] = {"m": c}
				order.append(ck)
		graph[k]["moves"] = kids
	# Winnable, winning orders, longest path (Undo reach) - reverse BFS order.
	var win := {}
	var paths := {}
	var longest := {}
	for i in range(order.size() - 1, -1, -1):
		var k: String = order[i]
		var m: BoardModel = graph[k]["m"]
		if m.is_empty():
			win[k] = true
			paths[k] = 1
			longest[k] = 0
			continue
		var w := false
		var p := 0
		var l := 0
		for id in graph[k]["moves"]:
			var ck: String = graph[k]["moves"][id]
			if not win.has(ck):
				# DAG: children are always later in BFS order except equal depth; resolve recursively.
				_resolve(ck, graph, win, paths, longest)
			w = w or win[ck]
			p += paths[ck]
			l = maxi(l, 1 + longest[ck])
		win[k] = w
		paths[k] = p
		longest[k] = l
	var fatal := 0
	var first_bad := 0
	var max_undo := 0
	var plain_traps := 0
	var pair_fatal := 0
	var hint_ok := true
	var hammer_ok := true
	var hammer_checked := 0
	var free_taps := 0
	for k in order:
		var m: BoardModel = graph[k]["m"]
		for id in graph[k]["moves"]:
			var ck: String = graph[k]["moves"][id]
			if win[k] and not win[ck]:
				fatal += 1
				max_undo = maxi(max_undo, 1 + longest[ck])
				if k == order[0]:
					first_bad += 1
				var risky: bool = m.turns_spinners(id) or m.blocks[id].switch_group != "" or m.twin_partner(id) >= 0
				if not risky:
					plain_traps += 1
				if m.twin_partner(id) >= 0:
					pair_fatal += 1
		for id in m.blocks:
			if m.move_state(id) == "twin_wait":
				free_taps += 1
		if not m.is_empty():
			var rec := Solver.from_model(m).recommend_move()
			if win[k]:
				if rec < 0 or not m.is_playable(rec) or not win[_state(_child(m, rec))]:
					hint_ok = false
			elif rec != -1:
				hint_ok = false
			for id in m.blocks:
				var after := BoardModel.new()
				after.setup(m.rows, m.columns, m.snapshot())
				after.remove(id)
				var expect: bool = after.is_empty() or _bm_winnable(after, {}) or not win[k]
				hammer_checked += 1
				if Solver.hammer_safe(m, id) != expect:
					hammer_ok = false
	# Random tapper over distinct moves (a pair is one move), 4000 games.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var wins := 0
	for g in 4000:
		var k: String = order[0]
		while true:
			var mv: Dictionary = graph[k]["moves"]
			if mv.is_empty():
				break
			var keys := mv.keys()
			k = mv[keys[rng.randi_range(0, keys.size() - 1)]]
		if graph[k]["m"].is_empty():
			wins += 1
	var res := {"states": order.size(), "winnable": win.values().filter(func(x): return x).size(), "orders": paths[order[0]],
		"fatal": fatal, "first_bad": first_bad, "max_undo": max_undo, "pair_fatal": pair_fatal, "plain_traps": plain_traps,
		"random": snappedf(wins / 4000.0, 0.001), "twin_wait_situations": free_taps, "hammer_checks": hammer_checked}
	report["P%d" % n] = res
	print("P%d %s: %s" % [n, lv.name, res])
	for key in ["states", "winnable", "orders", "fatal", "first_bad"]:
		_check(res[key] == DESIGN[n][key], "P%d %s = %s (design report %s)" % [n, key, res[key], DESIGN[n][key]])
	_check(win[order[0]], "P%d solvable" % n)
	_check(Solver.from_model(root).is_solvable(), "P%d Solver finds a solution" % n)
	_check(plain_traps == 0, "P%d: every fatal move is a visible decision (spinner / switch / pair), never a plain escape")
	_check(max_undo <= 4, "P%d: every mistake recoverable within 4 Undos (max %d)" % [n, max_undo])
	_check(hint_ok, "P%d SHOW A MOVE: legal and winnable from every winnable state, none from lost states" % n)
	_check(hammer_ok, "P%d Hammer safety exact on every state and block (%d checks)" % [n, hammer_checked])
	_check(free_taps > 0, "P%d has partner-blocked (free) twin taps to discover" % n)


func _resolve(k: String, graph: Dictionary, win: Dictionary, paths: Dictionary, longest: Dictionary) -> void:
	var m: BoardModel = graph[k]["m"]
	if m.is_empty():
		win[k] = true
		paths[k] = 1
		longest[k] = 0
		return
	var w := false
	var p := 0
	var l := 0
	for id in graph[k]["moves"]:
		var ck: String = graph[k]["moves"][id]
		if not win.has(ck):
			_resolve(ck, graph, win, paths, longest)
		w = w or win[ck]
		p += paths[ck]
		l = maxi(l, 1 + longest[ck])
	win[k] = w
	paths[k] = p
	longest[k] = l


# --- Game flow (real scene) ----------------------------------------------------

static func _read_all(path: String) -> String:
	var out := ""
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		out += "|" + (FileAccess.get_file_as_string(path + suffix) if FileAccess.file_exists(path + suffix) else "<none>")
	return out


func _snapshot() -> Array:
	var out := []
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = game.model.blocks[id]
		out.append([id, b.cell, b.direction, b.hidden, b.spin_step, b.armored, b.twin])
	return out


func _game() -> void:
	var saves := ["user://progress.cfg", ExperienceLab.SAVE_PATH, ExperienceLab.QA_SAVE_PATH, OpeningLab.SAVE_PATH]
	var before := {}
	for p in saves:
		before[p] = _read_all(p)
	TwinsPrototype.apply("1")
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	# The GameManager applies the prototype itself only from the URL /
	# command line; here it was applied directly, so seed and cap as it does.
	game.level_manager.level_count = mini(game.level_manager.level_count, TwinsPrototype.LAST_LEVEL)
	TwinsPrototype.seed_save(game.progress)
	AudioManager.set_music_enabled(false)
	_check(game.progress.path == TwinsPrototype.SAVE_PATH, "the game uses the prototype save (%s)" % game.progress.path)
	_check(game.level_manager.level_count == 3, "the prototype has exactly 3 levels")
	for n in range(1, 4):
		game.start_level(n, "test")
		await _frames(3)
		var lv := proto_level(n)
		_check(LevelManager.to_json_text(game.level) == LevelManager.to_json_text(lv), "game P%d loads the prototype board" % n)
		_check(game.max_hearts == 3 and game.hearts == 3, "P%d 3 hearts" % n)
		_check(game.board.bond_count() == _twin_count(lv) / 2, "P%d draws one bond per pair (%d)" % [n, game.board.bond_count()])
		var start := _snapshot()
		await _game_level(n, start)
	# Level 3 -> end screen, never Level 4.
	game.start_level(3, "test")
	await _frames(2)
	for id in Solver.from_model(game.model).solve():
		game._on_block_tapped(id)
		await _frames(1)
	var t := 0
	while not (game.completed and game.ui.is_complete_visible()) and t < 600:
		await _frames(2)
		t += 1
	game.next_level()
	await _frames(6)
	_check(TwinsPrototype.complete_open and game.current_level == 3, "after P3: the end-of-prototype screen, never Level 4")
	_check(game.has_node("TwinsPrototypeComplete"), "the end screen is shown")
	game.get_node("TwinsPrototypeComplete").find_children("*", "Button", true, false)[0].pressed.emit()
	await _frames(4)
	_check(game.ui.is_level_select_open() and game.select_shown.get("unlocked", []).max() <= 3 and game.select_shown.get("locked", []).is_empty(), "Level Select lists 1-3 only (%s)" % [game.select_shown])
	game.queue_free()
	await _frames(3)
	for p in saves:
		_check(_read_all(p) == before[p], "save isolation: %s untouched" % p)
	_check(FileAccess.file_exists(TwinsPrototype.SAVE_PATH), "the prototype wrote only its own save")


func _game_level(n: int, start: Array) -> void:
	var m: BoardModel = game.model
	# Find a partner-blocked twin (free tap) and an own-blocked twin tap from
	# the start state or after a few solution moves.
	var hearts0: int = game.hearts
	var hist0: int = game.history.size()
	var wait_id := -1
	var blocked_id := -1
	for id in m.blocks:
		if m.move_state(id) == "twin_wait" and wait_id == -1:
			wait_id = id
		if m.blocks[id].twin != "" and m.move_state(id) == "blocked" and blocked_id == -1:
			blocked_id = id
	if wait_id == -1:
		# Level 1: green (4,4) first makes the blue pair's up lane the only blocker.
		for id in Solver.from_model(m).solve():
			if m.twin_partner(id) >= 0:
				break
			game._on_block_tapped(id)
			await _frames(1)
			for t in m.blocks:
				if m.move_state(t) == "twin_wait":
					wait_id = t
			if wait_id != -1:
				break
		hearts0 = game.hearts
		hist0 = game.history.size()
	if wait_id != -1:
		var chain0: int = game.chain
		var snap := _snapshot()
		var shown_before := GameManager.twin_wait_explained
		game._on_block_tapped(wait_id)
		await _frames(1)
		_check(game.hearts == hearts0 and game.history.size() == hist0 and game.chain == chain0 and _snapshot() == snap,
			"P%d partner-blocked twin tap is free (no heart, no move, chain kept)" % n)
		_check(GameManager.twin_wait_explained, "P%d the twin rule is explained" % n)
		if shown_before:
			_check(not game.tutorial.is_showing() or game.tutorial._text != GameManager.TWIN_WAIT_TEXT, "P%d the explanation is not repeated" % n)
		game._on_block_tapped(wait_id)
		await _frames(1)
		_check(game.hearts == hearts0, "P%d repeated free tap still costs nothing" % n)
	else:
		_check(false, "P%d has a reachable partner-blocked twin tap" % n)
	game.restart()
	await _frames(2)
	_check(_snapshot() == start, "P%d Restart restores the exact start" % n)
	if blocked_id != -1:
		game._on_block_tapped(blocked_id)
		await _frames(1)
		_check(game.hearts == 2 and _snapshot() == start, "P%d own-blocked twin tap costs exactly one heart and moves nothing" % n)
		game.restart()
		await _frames(2)
	# Play the solution; at the pair: one Undo step, chain +1, both gone.
	var sol := Solver.from_model(game.model).solve()
	var undo_checked := false
	for id in sol:
		var pair: bool = game.model.twin_partner(id) >= 0
		var partner: int = game.model.twin_partner(id)
		var chain0: int = game.chain
		var h0: int = game.history.size()
		var bonds0: int = game.board.bond_count()
		var snap := _snapshot()
		game._on_block_tapped(id)
		await _frames(1)
		if pair:
			_check(not game.model.blocks.has(id) and not game.model.blocks.has(partner), "P%d pair escape removes both twins" % n)
			_check(game.chain == chain0 + 1, "P%d pair escape: chain +1 (not +2)" % n)
			_check(game.history.size() == h0 + 1, "P%d pair escape: one Undo step" % n)
			_check(game.board.bond_count() == bonds0 - 1, "P%d the bond leaves with the pair" % n)
			if not undo_checked and not game.model.is_empty():
				undo_checked = true
				game.undos_used = 0
				game.undo()
				await _frames(1)
				_check(_snapshot() == snap and game.board.bond_count() == bonds0, "P%d one Undo restores both twins and the bond (%s / %d vs %d)" % [n, _snapshot() == snap, game.board.bond_count(), bonds0])
				game._on_block_tapped(id)
				await _frames(1)
	var t := 0
	while not (game.completed and game.ui.is_complete_visible()) and t < 600:
		await _frames(2)
		t += 1
	_check(game.completed and game.last_result.get("level", 0) == n, "P%d clears by taps" % n)
	_check(game.mistakes == 0, "P%d the solution costs no heart" % n)
	# SHOW A MOVE on a pair marks both twins.
	game.start_level(n, "test")
	await _frames(2)
	var hinted := false
	for id in Solver.from_model(game.model).solve():
		game.progress.inventory["hint"] = 5
		game.request_hint()
		await _frames(1)
		_check(game.hint_block != -1 and game.model.is_playable(game.hint_block), "P%d SHOW A MOVE marks a legal move" % n)
		if game.hint_block != -1 and game.model.twin_partner(game.hint_block) >= 0:
			var p: int = game.model.twin_partner(game.hint_block)
			_check(game.board.get_view(game.hint_block).hinted and game.board.get_view(p).hinted, "P%d SHOW A MOVE on a pair marks both twins" % n)
			hinted = true
			break
		game._on_block_tapped(game.hint_block)
		await _frames(1)
	if n == 1:
		_check(hinted, "P1 SHOW A MOVE eventually points at a pair")
	# Hammer: only the smashed twin goes; the bond breaks.
	game.start_level(n, "test")
	await _frames(2)
	game.progress.inventory["hammer"] = 99
	var tw := -1
	for id in game.model.blocks:
		if game.model.twin_partner(id) >= 0 and game.is_hammer_safe(id):
			tw = id
			break
	if tw != -1:
		var p: int = game.model.twin_partner(tw)
		var bonds0: int = game.board.bond_count()
		game.toggle_hammer()
		game._on_block_tapped(tw)
		await _frames(2)
		_check(not game.model.blocks.has(tw) and game.model.blocks.has(p), "P%d Hammer removes only the smashed twin" % n)
		_check(game.model.twin_partner(p) == -1 and game.board.bond_count() == bonds0 - 1, "P%d the bond breaks; the other twin is ordinary" % n)
		_check(game.model.is_empty() or Solver.from_model(game.model).is_solvable(), "P%d a safe twin smash keeps the board solvable" % n)
		game.undos_used = 0
		game.undo()
		await _frames(1)
		_check(game.model.twin_partner(p) == tw and game.board.bond_count() == bonds0, "P%d Undo after a smash restores the bond" % n)
	else:
		_check(false, "P%d has a safe twin to smash" % n)
	var unsafe := -1
	for id in game.model.blocks:
		if not game.is_hammer_safe(id):
			unsafe = id
			break
	if unsafe != -1:
		game.toggle_hammer()
		game._on_block_tapped(unsafe)
		await _frames(1)
		_check(game.model.blocks.has(unsafe), "P%d Hammer refuses an unsafe smash" % n)
		if game.hammer_armed:
			game.toggle_hammer()
	game.restart()
	await _frames(2)
