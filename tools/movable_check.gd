extends Node
## MOVABLE MECHANIC PROTOTYPE (development only): technical checks.
##   godot --headless --path . res://tools/MovableCheck.tscn
## Token gating (outside the lab "M" is a bad token, as before), push rules
## (one cell, four directions, repeats, blocked destination, board edge, no
## chain pushing, locked / hidden pushers), crates never need to leave,
## Portal and Sequence pushes (and their blocked forms), Undo / Restart,
## late animation callbacks after Undo / Restart, the Solver's memo key,
## Solver vs a breadth-first search on random small crate boards, SHOW A
## MOVE, the lab's board file and page flow, and Social isolation.

const PROGRESS_PATH := "user://movable_check_progress.cfg"
const MOV_STATE := "user://mechlab_movable_state.json"

var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MOV_STATE))
	_run.call_deferred()


func _run() -> void:
	_gating()
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	_push_rules()
	_portal_and_sequence()
	_solver_key_and_round_trip()
	_solver_vs_bfs()
	_lab_data()
	await _play_flow()
	await _lab_flow()
	LevelManager.dev_movable = false
	LevelManager.dev_sequence = false
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("MOVABLE CHECKS PASSED" if failures.is_empty() else "MOVABLE CHECKS FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		print("FAIL: " + what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


static func board(map: Array) -> BoardModel:
	var level := LevelManager.parse_level({"map": map})
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals(level.portals)
	return m


static func id_at(m: BoardModel, c: int, r: int) -> int:
	var b := m.block_at(Vector2i(c, r))
	return b.id if b else -1


# --- Isolation -----------------------------------------------------------------------------

func _gating() -> void:
	LevelManager.dev_movable = false
	var level := LevelManager.parse_level({"map": ["R> M", ".  B^"]})
	_check(level.blocks.size() == 2 and not level.blocks.any(func(b): return b.is_crate()), "outside the lab \"M\" is an unknown token (skipped, as before)")
	var def := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 2, "cols": 2, "map": ["R> M", ". B^"]})
	_check(def != null and not def.verify(), "PuzzleDefinition.verify() rejects a crate board (Photo / Message / recipient)")
	_check(not FriendGenerator.mechanics_ok(def, FriendGenerator.MEDIUM), "Friend Challenge validation rejects a crate cell")
	_check(not RegEx.create_from_string("^(\\.|[RBGYP][\\^v<>](@)?)$").search("M"), "the backend's Friend cell rule (unchanged) rejects a crate cell")
	_check(MechLab.requested_mechanic() == "", "no lab without ?mechlab=...")


# --- Push rules ------------------------------------------------------------------------------

func _push_rules() -> void:
	var m := board([
		".  .  .  .  .",
		"R> .  M  .  .",
		".  .  .  .  ."])
	var r := id_at(m, 0, 1)
	var c := id_at(m, 2, 1)
	_check(m.blocks[c].is_crate() and m.block_count() == 1 and m.move_state(c) == "crate", "\"M\" parses as a crate: not an arrow, not tappable, not counted")
	_check(m.move_state(r) == "push" and m.is_playable(r) and not m.can_escape(r), "an arrow whose lane meets a crate with room behind it: a push")
	var info := m.push(r)
	_check(m.blocks[c].cell == Vector2i(3, 1) and m.blocks[r].cell == Vector2i(0, 1) and info["from"] == Vector2i(2, 1) and info["to"] == Vector2i(3, 1),
		"the crate moves exactly one cell; the arrow stays in its cell")
	m.push(r)
	_check(m.blocks[c].cell == Vector2i(4, 1), "pushed again: one more cell")
	_check(m.move_state(r) == "blocked" and m.find_blocker(r).id == c, "at the board edge the crate can't move: an ordinary blocked tap")
	_check(m.push(r).is_empty() and m.blocks[c].cell == Vector2i(4, 1), "push() on a blocked push does nothing")
	# Four directions.
	var dirs := {"R>": Vector2i(1, 0), "Bv": Vector2i(0, 1), "G<": Vector2i(-1, 0), "Y^": Vector2i(0, -1)}
	var all_ok := true
	for t in dirs:
		var d: Vector2i = dirs[t]
		var grid := []
		for y in 5:
			var row := []
			row.resize(5)
			row.fill(".")
			grid.append(row)
		grid[2][2] = "M"
		grid[2 - d.y * 2][2 - d.x * 2] = t
		var map := []
		for row in grid:
			map.append(" ".join(row))
		var b := board(map)
		var a := id_at(b, 2 - d.x * 2, 2 - d.y * 2)
		var cr := id_at(b, 2, 2)
		all_ok = all_ok and b.move_state(a) == "push"
		b.push(a)
		all_ok = all_ok and b.blocks[cr].cell == Vector2i(2, 2) + d
	_check(all_ok, "a crate can be pushed up, down, left and right (it has no direction of its own)")
	# Blocked destination; no chain pushing.
	m = board(["R> M Bv", ".  . ."])
	_check(m.move_state(id_at(m, 0, 0)) == "blocked", "a block right behind the crate: blocked")
	m = board(["R> M M .", ".  . . ."])
	r = id_at(m, 0, 0)
	_check(m.move_state(r) == "blocked" and m.push(r).is_empty() and m.blocks[id_at(m, 1, 0)].is_crate() and m.blocks[id_at(m, 2, 0)].is_crate(),
		"no chain pushing: a crate behind a crate blocks the whole push")
	# A gate behind the crate blocks; a locked / hidden pusher can't push.
	m = board(["R> M XC", "B^+C . ."])
	_check(m.move_state(id_at(m, 0, 0)) == "blocked", "a Chain Gate behind the crate blocks the push")
	m = board(["R>#G M .", "Gv   . ."])
	_check(m.move_state(id_at(m, 0, 0)) == "locked", "a locked arrow can't push")
	m = board(["R>? M .", "Gv  . ."])
	_check(m.move_state(id_at(m, 0, 0)) == "hidden", "a hidden arrow can't push")
	# A spinner pusher: the push turns nobody (it is not an escape).
	m = board([".  Gv@ .", "R> .   M", ".  .   ."])
	var g := id_at(m, 1, 0)
	var gd: int = m.blocks[g].direction
	m = board(["Gv@ .  .  .", "R>  .  M  .", ".   .  .  ."])
	g = id_at(m, 0, 0)
	gd = m.blocks[g].direction
	m.push(id_at(m, 0, 1))
	_check(m.blocks[g].direction == gd, "a push sends no neighbour event (spinners next to the pusher don't turn)")
	# Crates never need to leave.
	m = board(["R> .", ".  M"])
	m.remove(id_at(m, 0, 0))
	_check(m.is_empty() and m.blocks.size() == 1 and m.block_count() == 0, "the board is clear when only crates remain")


func _portal_and_sequence() -> void:
	# Through a portal: one step into portal A, out of its partner, onto
	# the next cell.
	var m := board([
		".   .  .   .   .",
		"R>  M  OA  .   .",
		".   .  .   .   .",
		".   .  .   OA  .",
		".   .  .   .   ."])
	var r := id_at(m, 0, 1)
	var c := id_at(m, 1, 1)
	var t := m.push_target(r)
	_check(m.move_state(r) == "push" and t["cell"] == Vector2i(4, 3) and t["via"] == [[Vector2i(2, 1), Vector2i(3, 3)]], "Portal push: in at A, out of the other A, onto the next cell")
	m.push(r)
	_check(m.blocks[c].cell == Vector2i(4, 3) and m.find_blocker(r).id == c, "the crate lands there (still in the pusher's lane, through the portal)")
	# Blocked portal push: the cell after the exit portal is taken.
	m = board([
		".   .  .   .   .",
		"R>  M  OA  .   .",
		".   .  .   .   .",
		".   .  .   OA  Bv",
		".   .  .   .   ."])
	r = id_at(m, 0, 1)
	_check(m.move_state(r) == "blocked" and m.push(r).is_empty() and m.blocks[id_at(m, 1, 1)].is_crate(), "Portal push blocked after the exit: the whole push fails, the crate stays")
	# The pusher's own lane through a portal reaches the crate.
	m = board([
		"R> OA .  .",
		".  .  .  .",
		".  .  OA M",
		".  .  .  ."])
	r = id_at(m, 0, 0)
	_check(m.move_state(r) == "blocked", "pushed through a portal toward the edge: blocked")
	m = board([
		"Rv  .  .  .",
		"OA  .  .  .",
		".   .  .  .",
		".   .  OA .",
		".   .  M  .",
		".   .  .  ."])
	r = id_at(m, 0, 0)
	m.push(r)
	_check(m.blocks[id_at(m, 2, 5)] != null and m.blocks[id_at(m, 2, 5)].is_crate(), "an arrow's lane through a portal pushes the crate on the other side (same direction)")
	# Sequence: a successful first-stage push moves the crate AND advances.
	m = board([
		"Gv@ .  .  .",
		"R>:v M .  .",
		".   .  .  ."])
	r = id_at(m, 0, 1)
	var g := id_at(m, 0, 0)
	var gd: int = m.blocks[g].direction
	_check(m.move_state(r) == "push", "a first-stage Sequence block into a crate: a push")
	var info := m.push(r)
	_check(info["advanced"] and m.blocks[r].seq_stage == 2 and m.blocks[r].direction == Direction.DOWN and m.blocks[r].cell == Vector2i(0, 1)
		and m.blocks[id_at(m, 2, 1)].is_crate(), "Sequence push: the crate moves one cell, the block stays and takes its next arrow")
	_check(m.blocks[g].direction != gd and info["turned"] == [g], "...and its first stage sends the neighbour event (the spinner turns)")
	# Failed Sequence push: nothing moves, the stage stays.
	m = board(["R>:v M Bv", ".    . ."])
	r = id_at(m, 0, 0)
	_check(m.move_state(r) == "blocked" and m.push(r).is_empty() and m.blocks[r].seq_stage == 1 and m.blocks[r].direction == Direction.RIGHT,
		"failed Sequence push: the crate stays and the Sequence block does NOT advance")
	# Solver on a Sequence push.
	var s := Solver.from_model(board(["R>:v M  .", ".    .  .", ".    G^ ."]))
	var moves := s.solve_moves()
	_check(not moves.is_empty() and (moves[0] & Solver.PUSH) != 0, "the Solver plans the Sequence push")



# --- Solver -----------------------------------------------------------------------------

func _solver_key_and_round_trip() -> void:
	var a := Solver.from_model(board(["R> M .", ".  . ."]))
	var b := Solver.from_model(board(["R> . M", ".  . ."]))
	_check(a._key() != b._key(), "the Solver's memo key includes crate positions")
	var m := board(["R> M .", ".  . ."])
	var before := Solver.from_model(m)._key()
	m.push(id_at(m, 0, 0))
	_check(Solver.from_model(m)._key() != before, "a push changes the key")
	var map := ["R>  M  .", "Gv@ .  OA", ".   OA M"]
	var lv := LevelManager.parse_level({"map": map})
	var text := LevelManager.to_json_text(lv)
	var lv2 := LevelManager.parse_level(JSON.parse_string(text))
	var crates_a := lv.blocks.filter(func(x): return x.is_crate()).map(func(x): return x.cell)
	var crates_b := lv2.blocks.filter(func(x): return x.is_crate()).map(func(x): return x.cell)
	_check(crates_a == crates_b and crates_a.size() == 2 and lv2.portals == lv.portals and text.count("M") >= 2, "map -> JSON text -> map keeps every crate (and portals)")
	m = board(map)
	var snap := m.snapshot()
	m.push(id_at(m, 0, 0))
	m.restore(snap)
	_check(m.blocks[id_at(m, 1, 0)] != null and m.blocks[id_at(m, 1, 0)].is_crate() and m.block_at(Vector2i(2, 0)) == null, "snapshot / restore puts crates back exactly")


static func _key(m: BoardModel) -> String:
	var ids := m.blocks.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var bd: BlockData = m.blocks[id]
		parts.append("%d:%d,%d:%d:%d:%d:%d:%d" % [id, bd.cell.x, bd.cell.y, bd.direction, bd.spin_step, 1 if bd.armored else 0, 1 if bd.hidden else 0, bd.seq_stage])
	return " ".join(parts)


static func _apply(m: BoardModel, id: int) -> String:
	var st := m.move_state(id)
	match st:
		"ok": m.remove(id)
		"advance": m.advance(id)
		"ram": m.ram(id)
		"push": m.push(id)
	return st


static func _copy(m: BoardModel) -> BoardModel:
	var t := BoardModel.new()
	t.setup(m.rows, m.columns, m.snapshot())
	t.set_portals(m.portal_groups)
	return t


## Exact reachability: can the board be cleared? (breadth-first, every state).
static func _bfs_solvable(m: BoardModel) -> bool:
	var seen := {_key(m): true}
	var queue := [_copy(m)]
	var head := 0
	while head < queue.size():
		var cur: BoardModel = queue[head]
		head += 1
		if cur.is_empty():
			return true
		for id in cur.playable_ids():
			var nxt := _copy(cur)
			_apply(nxt, id)
			var k := _key(nxt)
			if not seen.has(k):
				seen[k] = true
				queue.append(nxt)
	return false


func _random_map(rng: RandomNumberGenerator) -> Array:
	var size := Vector2i(rng.randi_range(3, 5), rng.randi_range(3, 4))
	var grid := []
	for r in size.y:
		var row := []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	var tokens := ["M"]
	if rng.randf() < 0.35:
		tokens.append("M")
	var n := rng.randi_range(2, 5)
	for i in n:
		var t: String = ["R", "B", "G", "Y"][rng.randi_range(0, 3)] + ["^", "v", "<", ">"][rng.randi_range(0, 3)]
		var roll := rng.randf()
		if roll < 0.4:
			t += ["@", "@-", "@~"][rng.randi_range(0, 2)]
		elif roll < 0.55:
			t += ":" + ["^", "v", "<", ">"][rng.randi_range(0, 3)]
		elif roll < 0.62:
			t += "?"
		elif roll < 0.68:
			t += "="
		tokens.append(t)
	var portal := rng.randf() < 0.3
	if portal:
		tokens.append("OA")
		tokens.append("OA")
	for t in tokens:
		var tries := 0
		while tries < 200:
			tries += 1
			var c := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
			if grid[c.y][c.x] == ".":
				grid[c.y][c.x] = t
				break
	var map := []
	for row in grid:
		map.append(" ".join(row))
	return map


func _solver_vs_bfs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9090
	var boards := 0
	var agree := 0
	var solvable := 0
	var replay_ok := 0
	var hint_ok := 0
	var with_push := 0
	var with_portal_push := 0
	var tries := 0
	while boards < 450 and tries < 4000:
		tries += 1
		var map := _random_map(rng)
		var m := board(map)
		if m.block_count() == 0:
			continue
		boards += 1
		var s := Solver.from_model(m)
		var moves := s.solve_moves()
		var solver_says := not moves.is_empty() and not s.aborted
		var exact := _bfs_solvable(m)
		if solver_says == exact:
			agree += 1
		else:
			print("  disagreement: solver %s bfs %s aborted %s  %s" % [solver_says, exact, s.aborted, str(map)])
		if not solver_says:
			continue
		solvable += 1
		var play := board(map)
		var legal := true
		var pushed := false
		for mv in moves:
			var id: int = mv & Solver.ID_MASK
			if not play.is_playable(id):
				legal = false
				break
			if play.move_state(id) == "push":
				pushed = true
				if not play.push_target(id)["via"].is_empty():
					with_portal_push += 1
			_apply(play, id)
		if legal and play.is_empty():
			replay_ok += 1
		if pushed:
			with_push += 1
		var walk := board(map)
		var ok := true
		for step in 60:
			if walk.is_empty():
				break
			var rec := Solver.from_model(walk).recommend_move()
			if rec == -1 or not walk.is_playable(rec):
				ok = false
				break
			_apply(walk, rec)
		if ok and walk.is_empty():
			hint_ok += 1
	_check(agree == boards and boards >= 400, "Solver agrees with an exact search on %d / %d random small crate boards (%d solvable)" % [agree, boards, solvable])
	_check(replay_ok == solvable, "every Solver solution replays legally with the real rules (%d)" % replay_ok)
	_check(hint_ok == solvable, "SHOW A MOVE, followed to the end, is always legal and clears the board (%d)" % hint_ok)
	# Push-heavy sample: every lab board, mutated (one arrow turned or one
	# block moved), checked the same way.
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/mechlab_movable.json"))
	var m_boards := 0
	var m_agree := 0
	if typeof(data) == TYPE_DICTIONARY:
		for rec in data["boards"]:
			var base: Array = rec["puzzle"]["map"]
			for k in 14:
				var map := _mutate(base, rng) if k > 0 else base
				var m := board(map)
				if m.block_count() == 0:
					continue
				m_boards += 1
				var s := Solver.from_model(m)
				var moves := s.solve_moves()
				var solver_says := not moves.is_empty() and not s.aborted
				if solver_says == _bfs_solvable(m):
					m_agree += 1
				else:
					print("  disagreement (mutated lab board): %s" % str(map))
				if not solver_says:
					continue
				var play := board(map)
				var pushed := false
				var legal := true
				for mv in moves:
					var id: int = mv & Solver.ID_MASK
					if not play.is_playable(id):
						legal = false
						break
					if play.move_state(id) == "push":
						pushed = true
						if not play.push_target(id)["via"].is_empty():
							with_portal_push += 1
					_apply(play, id)
				if not (legal and play.is_empty()):
					m_agree -= 1000
				if pushed:
					with_push += 1
	_check(m_agree == m_boards and m_boards > 200, "Solver agrees with the exact search on %d / %d mutated lab boards; solutions replay legally" % [m_agree, m_boards])
	print("  samples: %d random boards (%d solvable), %d mutated lab boards, %d push solutions (%d through a portal)" % [boards, solvable, m_boards, with_push, with_portal_push])
	_check(with_push >= 60 and with_portal_push >= 3, "the samples exercise pushes (%d solutions push, %d through a portal)" % [with_push, with_portal_push])


func _mutate(map: Array, rng: RandomNumberGenerator) -> Array:
	var grid := []
	for row in map:
		grid.append(Array(String(row).split(" ", false)))
	var cells := []
	var empty := []
	for r in grid.size():
		for c in grid[0].size():
			var t: String = grid[r][c]
			if t == ".":
				empty.append(Vector2i(c, r))
			elif not t.begins_with("O"):
				cells.append(Vector2i(c, r))
	var b: Vector2i = cells[rng.randi_range(0, cells.size() - 1)]
	var t: String = grid[b.y][b.x]
	if t != "M" and rng.randf() < 0.5:
		grid[b.y][b.x] = t[0] + ["^", "v", "<", ">"][rng.randi_range(0, 3)] + t.substr(2)
	elif not empty.is_empty():
		var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
		grid[e.y][e.x] = t
		grid[b.y][b.x] = "."
	var out := []
	for row in grid:
		out.append(" ".join(row))
	return out


# --- Lab data ---------------------------------------------------------------------------

func _lab_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/mechlab_movable.json"))
	_check(typeof(data) == TYPE_DICTIONARY and data.get("mechanic", "") == "movable", "Movable lab board file loads")
	if typeof(data) != TYPE_DICTIONARY:
		return
	var ids := {}
	for rec in data["boards"]:
		ids[rec["id"]] = rec
	var ok := true
	var mov_n := 0
	var ctrl_n := 0
	var integ := 0
	for rec in data["boards"]:
		var level := PuzzleDefinition.from_dict(rec["puzzle"]).to_level()
		var m := BoardModel.new()
		m.setup(level.rows, level.columns, level.blocks)
		m.set_portals(level.portals)
		var s := Solver.from_model(m)
		var moves := s.solve_moves()
		var pushes := 0
		for mv in moves:
			if not m.is_playable(mv & Solver.ID_MASK):
				ok = false
				break
			if _apply(m, mv & Solver.ID_MASK) == "push":
				pushes += 1
		if moves.is_empty() or s.aborted or not m.is_empty():
			ok = false
			print("  unsolvable " + str(rec["id"]))
		var crates := level.blocks.filter(func(b): return b.is_crate()).size()
		match rec["variant"]:
			"movable":
				mov_n += 1
				if crates == 0 or pushes == 0:
					ok = false
					print("  movable board without a push " + str(rec["id"]))
			"integration":
				integ += 1
			"control":
				ctrl_n += 1
				var main := PuzzleDefinition.from_dict(ids[rec["pair"]]["puzzle"]).to_level()
				if crates != 0 or level.rows != main.rows or level.columns != main.columns:
					ok = false
					print("  bad control " + str(rec["id"]))
	_check(ok, "every lab board is solvable (Solver solution replayed); Movable boards need a push; controls have no crate and keep the size")
	_check(mov_n >= 10 and mov_n <= 12 and ctrl_n >= 5 and integ >= 2, "%d Movable boards, %d matched controls, %d integration checks" % [mov_n, ctrl_n, integ])


# --- Play flow (Undo / Restart / late callbacks) ------------------------------------------

func _play_flow() -> void:
	var play := SocialPlay.new()
	add_child(play)
	await _frames(2)
	var map := [".  .  .   .  .", ".  .  .   .  .", "G> .  M   .  .", ".  .  Y^@ .  .", ".  .  B>  .  ."]
	var def := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 5, "cols": 5, "map": map})
	play.start(SharedChallenge.friend_challenge(def, FriendGenerator.MEDIUM), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	await _frames(2)
	var y := id_at(play.model, 2, 3)
	var crate := id_at(play.model, 2, 2)
	_check(play.board.get_view(crate).data.is_crate() and not play.board.get_view(crate)._arrow.visible, "the crate's view: no arrow")
	play.tap_block(y)
	_check(play.total_pushes == 1 and play.push_events.size() == 1 and play.model.blocks[crate].cell == Vector2i(2, 1) and play.push_events[0]["dir"] == "up",
		"tap: a push (counted, event recorded with direction)")
	# Undo right away, while the slide is still running.
	play.undo()
	_check(play.model.blocks[crate].cell == Vector2i(2, 2), "Undo: the crate is back in its cell (rules)")
	await get_tree().create_timer(0.7).timeout
	var v := play.board.get_view(crate)
	_check(v.data.cell == Vector2i(2, 2) and v.position.is_equal_approx(v.home) and v.home.is_equal_approx(play.board.cell_to_local(Vector2i(2, 2))) and v.scale.is_equal_approx(Vector2.ONE),
		"Undo mid-animation: no late callback moves the crate's view again")
	# Restart mid-animation.
	play.tap_block(y)
	play.restart()
	await get_tree().create_timer(0.7).timeout
	var v2 := play.board.get_view(id_at(play.model, 2, 2))
	_check(play.model.blocks[id_at(play.model, 2, 2)].is_crate() and v2 != null and v2.position.is_equal_approx(v2.home), "Restart mid-animation: the exact first board, views in place")
	# Blocked push: counted, no CLUNK path, nothing moves.
	play.tap_block(y)  # crate up to (2,1)
	play.tap_block(y)  # (2,0)
	await get_tree().create_timer(0.5).timeout
	play.tap_block(y)  # edge: blocked
	_check(play.total_push_blocked == 1 and play.total_blocked == 1 and play.model.blocks[id_at(play.model, 2, 0)].is_crate(), "blocked push: an ordinary blocked tap, counted, the crate stays")
	# Win with the crate still on the board.
	play.restart()
	await _frames(1)
	var solved := [false]
	play.solved.connect(func(): solved[0] = true)
	for i in 20:
		if play.completed or not play.play_solver_move():
			break
	_check(play.completed and solved[0] and play.model.blocks.size() == 1, "solved with the crate still on the board")
	# Sequence push mid-animation + Undo.
	var smap := ["Gv@  .  .  .", "R>:v M  .  .", ".    .  .  .", ".    .  .  ."]
	var sdef := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 4, "cols": 4, "map": smap})
	play.start(SharedChallenge.friend_challenge(sdef, FriendGenerator.MEDIUM), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	await _frames(2)
	var r := id_at(play.model, 0, 1)
	play.tap_block(r)
	_check(play.total_pushes == 1 and play.total_seq_advances == 1 and play.model.blocks[r].seq_stage == 2, "Sequence push: counted as a push and an advance")
	play.undo()
	await get_tree().create_timer(0.8).timeout
	var rv := play.board.get_view(r)
	var cv := play.board.get_view(id_at(play.model, 1, 1))
	_check(play.model.blocks[r].seq_stage == 1 and rv.data.seq_stage == 1 and rv.data.direction == Direction.RIGHT and cv != null and cv.position.is_equal_approx(cv.home),
		"Undo after a Sequence push: stage 1 again in rules and view, crate back, no late callback")
	var normal := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 2, "cols": 2, "map": ["R> .", ". B^"]})
	play.start(SharedChallenge.friend_challenge(normal, FriendGenerator.EASY), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	await _frames(1)
	_check(play.total_pushes == 0 and play.push_events.is_empty() and play.max_hammers == SocialPlay.MAX_HAMMERS, "a normal board afterwards: counters reset, SocialPlay defaults unchanged")
	play.end()
	play.queue_free()


func _lab_flow() -> void:
	var lab := MechLab.new("movable")
	add_child(lab)
	await _frames(3)
	var order: Array = lab.state["order"]
	_check(lab.mechanic == "movable" and lab.total() == lab.boards.size(), "movable lab: its own board set (%d boards)" % lab.total())
	var adjacent := false
	for i in range(1, order.size()):
		if lab.boards[order[i]]["pair"] == lab.boards[order[i - 1]]["pair"]:
			adjacent = true
	var last_two: Array = order.slice(order.size() - 2)
	_check(not adjacent and lab.boards[order[0]]["stage"] == "A" and last_two.all(func(id): return lab.boards[id]["variant"] == "integration"),
		"basics first, integration checks last, a board and its control never back to back")
	_check(lab._intro_text.text.begins_with("MOVABLE LAB") and not lab._intro_text.text.to_lower().contains("control"), "intro: Movable wording, never names controls")
	lab.start_demo()
	await _frames(2)
	await get_tree().create_timer(10.4).timeout
	_check(lab._demo_buttons.visible and lab.play.total_pushes == 1 and lab.play.total_push_blocked == 1, "demo: one push, one blocked push, then WATCH AGAIN / START")
	lab._end_demo()
	lab.start_next()
	await _frames(2)
	var p := lab.play
	_check(p._title.text == "PUZZLE 1 / %d" % lab.total() and not p._hammer.visible and p._hint.badge_text == "1", "puzzle 1: neutral title, no HAMMER, SHOW A MOVE x1")
	for i in 40:
		if p.completed or not p.play_solver_move():
			break
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(1.3).timeout
	_check(lab.screen == MechLab.Screen.QUESTION and lab._asks == MechLab.MOV_ASK["A"], "solved basic board -> rating, clarity")
	lab.answer("EASY")
	_check(lab._q_box.get_child_count() == 3, "clarity: CLEAR / NOT CLEAR (+ SKIP)")
	lab.answer("CLEAR")
	await _frames(2)
	var r0: Dictionary = lab.state["results"][0]
	_check(r0["pushes"] >= 1 and r0.has("pushes_by_dir") and r0["crate_positions"] >= 2 and r0["push_events"].size() >= 1 and r0["first_push_ms"] >= 0
		and r0["push_events"][0].has("from") and r0["push_events"][0].has("cleared"), "result 1: push metrics and events recorded")
	lab.play.end()
	var idx := -1
	for i in order.size():
		if lab.boards[order[i]]["variant"] == "movable" and lab.boards[order[i]]["stage"] != "A":
			idx = i
			break
	lab.state["index"] = idx
	lab.start_next()
	await _frames(2)
	lab.play._leave()
	await _frames(2)
	_check(lab._asks == MechLab.MOV_ASK["movable"], "a Movable board asks rating, focus, planning, clarity, interest")
	lab.answer("HARD")
	var opts := []
	for c in lab._q_box.get_children():
		opts.append(c.text)
	_check(opts.has("JUST PUSHING IT WHEN I COULD") and opts.has("WHERE THE MOVABLE BLOCK WOULD END UP"), "focus options include 'just pushing it when I could'")
	for i in 4:
		lab.answer("")
	var json = JSON.parse_string(lab.results_json())
	_check(typeof(json) == TYPE_DICTIONARY and json["mechanic"] == "movable" and json["summary"].has("movable_A") and json["summary"]["movable_A"].has("pushes"),
		"COPY RESULTS JSON: mechanic, summary with push counters")
	_check(FileAccess.file_exists(MOV_STATE) and not FileAccess.file_exists(PROGRESS_PATH), "own state file only; never the Classic save")
	lab.reset_test()
	lab.play.end()
	lab.queue_free()
	var portal := MechLab.new()
	var seq := MechLab.new("sequence")
	_check(portal.mechanic == "portal" and portal._cfg["data"] == MechLab.DATA_PATH and seq._cfg["data"] == "res://data/dev/mechlab_sequence.json"
		and seq._ask == MechLab.SEQ_ASK, "the PORTAL and SEQUENCE labs keep their own settings")
	portal.free()
	seq.free()
