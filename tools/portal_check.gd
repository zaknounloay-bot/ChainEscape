extends Node
## PORTAL MECHANIC PROTOTYPE (development only): technical checks.
##   godot --headless --path . res://tools/PortalCheck.tscn
## Rules (clear traversal, blocked remote exit, both directions, direction
## kept, gates / armor + ram / spinners / locks / hidden / switches through
## a portal), malformed layouts (incomplete pair, missing partner, loops)
## rejected by the parser, the engine's loop guard on a forced bad layout,
## map round trip, Undo / Restart keep the portals, SHOW A MOVE never
## recommends an illegal move, Hammer safety, Solver vs a brute-force
## search on random small portal boards, the lab's board file, the lab
## page flow, and that portal boards can never become Social challenges.

const PROGRESS_PATH := "user://portal_check_progress.cfg"

var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MechLab.STATE_PATH))
	_run.call_deferred()


func _run() -> void:
	_rules()
	_interactions()
	_layouts()
	_loop_guard()
	_round_trip()
	_solver_vs_brute_force()
	_hammer()
	_lab_data()
	await _play_flow()
	await _lab_flow()
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("PORTAL CHECKS PASSED" if failures.is_empty() else "PORTAL CHECKS FAILED")
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


# --- Core rule ---------------------------------------------------------------------------

func _rules() -> void:
	# Clear traversal: R (0,1) > enters A (2,1), continues from A (3,3) > to the edge.
	var m := board([
		".  .  .  .  .",
		"R> .  OA .  Y^",
		".  .  .  .  .",
		".  .  .  OA .",
		".  .  .  .  ."])
	var r := id_at(m, 0, 1)
	var ln := m.lane(r)
	_check(m.move_state(r) == "ok" and ln["via"] == [[Vector2i(2, 1), Vector2i(3, 3)]] and not ln["loop"], "clear traversal: in at A (2,1), out at A (3,3), escapes")
	_check(m.portals.size() == 2 and m.block_count() == 2, "portals are not blocks (2 blocks on the board, 2 portal cells)")
	# Y (4,1) ^ is not affected by the portal in its row.
	_check(m.move_state(id_at(m, 4, 1)) == "ok" and m.lane(id_at(m, 4, 1))["via"].is_empty(), "a lane that never meets a portal is unchanged")
	# Blocked remote exit.
	m = board([
		".  .  .  .  .",
		"R> .  OA .  .",
		".  .  .  .  .",
		"OA P> .  .  .",
		".  .  .  .  ."])
	r = id_at(m, 0, 1)
	var p := id_at(m, 1, 3)
	_check(m.move_state(r) == "blocked" and m.find_blocker(r).id == p, "blocked remote exit: the blocker is the block after the exit portal")
	m.remove(p)
	_check(m.move_state(r) == "ok", "the exit lane clears -> the portal move is legal")
	# A block standing in the straight line beyond the entry portal is NOT in the way.
	m = board([
		"R> OA G^ .",
		".  .  .  .",
		".  .  .  OA",
		".  .  .  ."])
	_check(m.move_state(id_at(m, 0, 0)) == "ok", "a block behind the entry portal (straight line) is not in the way")
	# Same direction, both ways through one pair.
	m = board([
		".  Gv .  .  .",
		"B^ OA .  .  .",
		".  .  .  .  .",
		".  .  .  OA Y<",
		".  .  .  R> ."])
	var g := id_at(m, 1, 0)
	var y := id_at(m, 4, 3)
	_check(m.find_blocker(g) != null and m.find_blocker(g).id == id_at(m, 3, 4), "down through A: out of the other A still moving down (blocked by the block below it)")
	_check(m.find_blocker(y) != null and m.find_blocker(y).id == id_at(m, 0, 1), "left through the other A: out of the first A still moving left")
	# Portal cell taps: no block there.
	_check(m.block_at(Vector2i(1, 1)) == null, "nothing stands on a portal cell (a tap there selects no block)")


func _interactions() -> void:
	# Gate in the exit lane: blocks until its links are gone, then opens.
	var m := board([
		"R> OA .  .  .",
		".  .  .  .  .",
		".  .  .  OA XC",
		"B^+C .  .  .  ."])
	var r := id_at(m, 0, 0)
	_check(m.move_state(r) == "blocked" and m.find_blocker(r).is_gate(), "gate after the exit portal blocks the lane")
	m.remove(id_at(m, 0, 3))
	_check(m.move_state(r) == "ok", "the gate opens (last link escaped) -> lane through the portal is clear")
	# Armor beyond the exit: the move is a ram through the portal.
	m = board([
		"R> OA .  .  .",
		".  .  .  .  .",
		".  .  .  OA Bv=",
		".  .  .  .  ."])
	r = id_at(m, 0, 0)
	var b := id_at(m, 4, 2)
	_check(m.move_state(r) == "ram", "an armored block after the exit portal: tapping is a ram")
	_check(m.ram(r) == b and not m.blocks[b].armored and m.blocks.has(r), "the ram cracks that shell through the portal; the rammer stays")
	var s := Solver.from_model(board([
		"R> OA .  .  .",
		".  .  .  .  .",
		".  .  .  OA Bv=",
		".  .  .  .  ."]))
	var moves := s.solve_moves()
	_check(not moves.is_empty() and (moves[0] & Solver.RAM) != 0, "the Solver plans the ram through the portal")
	# Spinners turn around the ORIGIN cell only, never around the portals.
	m = board([
		"Y^@ .  .  .  .",
		"R>  OA Gv@ .  .",
		".   .  .  .  .",
		".   .  .  OA .",
		".   .  .  Pv@ ."])
	r = id_at(m, 0, 1)
	var by: int = m.blocks[id_at(m, 0, 0)].direction
	var bg: int = m.blocks[id_at(m, 2, 1)].direction
	var bp: int = m.blocks[id_at(m, 3, 4)].direction
	_check(m.move_state(r) == "ok", "spinner case: the portal lane is clear")
	var turned := m.remove(r)
	_check(turned == [id_at(m, 0, 0)] and m.blocks[id_at(m, 0, 0)].direction != by, "the spinner next to the origin cell turns")
	_check(m.blocks[id_at(m, 2, 1)].direction == bg and m.blocks[id_at(m, 3, 4)].direction == bp, "spinners next to the portals do not turn")
	# Lock: the locked block's lane through a portal still waits for its key.
	m = board([
		"R>#G OA .  .",
		"Gv   .  .  .",
		".    .  .  .",
		".    .  OA ."])
	r = id_at(m, 0, 0)
	_check(m.move_state(r) == "locked", "a locked block stays locked (lane through a portal irrelevant)")
	m.remove(id_at(m, 0, 1))
	_check(m.move_state(r) == "ok" and not m.lane(r)["via"].is_empty(), "unlocked -> escapes through the portal")
	# Switch: a flipped arrow can turn a lane into a portal lane.
	m = board([
		"OA  .  .  B<&A .",
		".   .  .  .    .",
		".   .  .  .    .",
		".   .  OA .    .",
		"Y^%A .  .  .    ."])
	var t := id_at(m, 3, 0)
	var before: Array = m.lane(t)["via"]
	m.remove(id_at(m, 0, 4))
	var after: Array = m.lane(t)["via"]
	_check(before.size() == 1 and after.is_empty() and m.blocks[t].direction == Direction.RIGHT, "switch flips the arrow: the lane no longer runs through the portal")
	# Hidden arrow: still revealed by a neighbour of its cell; a portal changes nothing.
	m = board([
		"R>  OA .  .",
		"Gv? .  .  .",
		".   .  .  .",
		".   .  OA ."])
	_check(m.move_state(id_at(m, 0, 1)) == "hidden", "hidden arrow stays hidden next to a portal user")
	m.remove(id_at(m, 0, 0))
	_check(not m.blocks[id_at(m, 0, 1)].hidden, "revealed by its neighbour escaping (through a portal)")


# --- Layouts ----------------------------------------------------------------------------

func _layouts() -> void:
	var single := LevelManager.parse_level({"map": ["R> OA .", ".  .  .", ".  .  ."]})
	_check(single.portals.is_empty() and single.blocks.size() == 1, "an incomplete pair (one OA) is rejected; blocks still load")
	var missing := LevelManager.parse_level({"map": ["R> OA .", ".  .  OB", ".  .  ."]})
	_check(missing.portals.is_empty(), "missing partners (OA and OB alone) are rejected")
	var three := LevelManager.parse_level({"map": ["OA .  OA", ".  .  .", "R^ .  OA"]})
	_check(three.portals.is_empty(), "three cells in one pair are rejected")
	_check(not Portals.layout_errors(3, 4, {Vector2i(0, 0): "A", Vector2i(3, 0): "A"}).is_empty(), "a pair in one row with cells between them can loop: rejected")
	_check(Portals.layout_errors(3, 4, {Vector2i(1, 0): "A", Vector2i(2, 0): "A"}).is_empty(), "two adjacent cells in a row cannot loop: accepted")
	var looped := LevelManager.parse_level({"map": ["OA R> .  OA", ".  .  .  .", ".  .  .  ."]})
	_check(looped.portals.is_empty(), "the parser drops a looping layout")
	# Two pairs that loop together.
	var two := {Vector2i(5, 0): "A", Vector2i(1, 3): "A", Vector2i(5, 3): "B", Vector2i(1, 0): "B"}
	_check(not Portals.layout_errors(4, 6, two).is_empty(), "two pairs forming a loop are rejected")
	var good := {Vector2i(2, 1): "A", Vector2i(3, 3): "A", Vector2i(0, 4): "B", Vector2i(4, 0): "B"}
	_check(Portals.layout_errors(5, 5, good).is_empty(), "two valid pairs are accepted")
	var level := LevelManager.parse_level({"map": [".  .  .  .  OB", ".  .  OA .  .", "R> .  .  .  .", ".  .  .  OA .", "OB .  .  .  ."]})
	_check(level.portals.size() == 4, "two pairs parse")


## The engine never hangs, even when a looping layout is forced past the parser.
func _loop_guard() -> void:
	var level := LevelManager.parse_level({"map": [".  R> .  .", ".  .  .  .", ".  .  .  ."]})
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals({Vector2i(0, 0): "A", Vector2i(3, 0): "A"})
	var r := id_at(m, 1, 0)
	var t0 := Time.get_ticks_msec()
	var ln := m.lane(r)
	_check(ln["loop"] and m.move_state(r) == "blocked" and m.find_blocker(r) == null, "forced loop: the lane is 'blocked' (no blocker), never followed forever")
	var s := Solver.from_model(m)
	var solvable := s.is_solvable()
	_check(not solvable and Time.get_ticks_msec() - t0 < 2000, "forced loop: the Solver finishes (unsolvable) instantly")
	_check(Solver.from_model(m).recommend_move() == -1 and Solver.from_model(m).legal_moves().is_empty(), "forced loop: SHOW A MOVE recommends nothing illegal")


func _round_trip() -> void:
	var map := [".  .  .  .  OB", ".  .  OA .  .", "R> .  .  B^@ .", ".  .  .  OA .", "OB .  .  .  ."]
	var a := LevelManager.parse_level({"map": map})
	var text := LevelManager.to_json_text(a)
	var b := LevelManager.parse_level(JSON.parse_string(text))
	_check(a.portals == b.portals and a.blocks.size() == b.blocks.size() and text.contains("OA") and text.contains("OB"), "map -> JSON text -> map keeps every portal and block")
	var def := PuzzleDefinition.from_level(a)
	var back := PuzzleDefinition.from_dict(def.to_dict()).to_level()
	_check(back.portals == a.portals, "the lab's PuzzleDefinition round trip keeps portals (dev only)")
	_check(not def.verify(), "PuzzleDefinition.verify() rejects a portal board: it can never be a Social challenge")
	_check(not RegEx.create_from_string("^(\\.|[RBGYP][\\^v<>](@)?)$").search("OA"), "the backend's Friend cell rule (unchanged) rejects a portal cell")


# --- Solver -----------------------------------------------------------------------------

## Brute force over BoardModel states (no pruning): can the board be cleared?
func _brute(m: BoardModel, seen: Dictionary) -> bool:
	if m.is_empty():
		return true
	var key := _state_key(m)
	if seen.has(key):
		return seen[key]
	seen[key] = false
	for id in m.blocks.keys():
		var st := m.move_state(id)
		if st != "ok" and st != "ram":
			continue
		var snap := m.snapshot()
		if st == "ok":
			m.remove(id)
		else:
			m.ram(id)
		var ok := _brute(m, seen)
		m.restore(snap)
		if ok:
			seen[key] = true
			return true
	return false


static func _state_key(m: BoardModel) -> String:
	var ids := m.blocks.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d:%d:%d:%d" % [id, b.direction, b.spin_step, 1 if b.armored else 0, 1 if b.hidden else 0])
	return " ".join(parts)


func _solver_vs_brute_force() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var boards := 0
	var agree := 0
	var solvable := 0
	var replay_ok := 0
	var portal_used := 0
	while boards < 300:
		var size := Vector2i(rng.randi_range(3, 5), rng.randi_range(3, 5))
		var cells := []
		for r in size.y:
			for c in size.x:
				cells.append(Vector2i(c, r))
		for i in range(cells.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = cells[i]
			cells[i] = cells[j]
			cells[j] = t
		var groups := {cells[0]: "A", cells[1]: "A"}
		if rng.randf() < 0.3 and cells.size() > 8:
			groups[cells[2]] = "B"
			groups[cells[3]] = "B"
		if not Portals.layout_errors(size.y, size.x, groups).is_empty():
			continue
		var grid := []
		for r in size.y:
			var row := []
			row.resize(size.x)
			row.fill(".")
			grid.append(row)
		for cell in groups:
			grid[cell.y][cell.x] = "O" + groups[cell]
		var n := rng.randi_range(3, mini(7, cells.size() - groups.size()))
		var k := groups.size()
		for i in n:
			var cell: Vector2i = cells[k + i]
			var t: String = ["R", "B", "G", "Y"][rng.randi_range(0, 3)] + ["^", "v", "<", ">"][rng.randi_range(0, 3)]
			var roll := rng.randf()
			if roll < 0.35:
				t += ["@", "@-", "@~"][rng.randi_range(0, 2)]
			elif roll < 0.45:
				t += "="
			grid[cell.y][cell.x] = t
		var map := []
		for row in grid:
			map.append(" ".join(row))
		var m := board(map)
		if m.portals.is_empty():
			continue
		boards += 1
		var s := Solver.from_model(m)
		var moves := s.solve_moves()
		var solver_says := not moves.is_empty() and not s.aborted
		var brute := _brute(board(map), {})
		if solver_says == brute:
			agree += 1
		else:
			print("  disagreement: solver %s brute %s  %s" % [solver_says, brute, str(map)])
		if solver_says:
			solvable += 1
			# Replay the Solver's moves with the real rules.
			var play := board(map)
			var legal := true
			var used := false
			for mv in moves:
				var id: int = mv & Solver.ID_MASK
				if not play.lane(id)["via"].is_empty():
					used = true
				var st := play.move_state(id)
				if mv & Solver.RAM:
					legal = legal and st == "ram"
					play.ram(id)
				else:
					legal = legal and st == "ok"
					play.remove(id)
			if legal and play.is_empty():
				replay_ok += 1
			if used:
				portal_used += 1
			# SHOW A MOVE from every state along the way is legal.
			var walk := board(map)
			var hint_ok := true
			for step in 30:
				if walk.is_empty():
					break
				var rec := Solver.from_model(walk).recommend_move()
				if rec == -1:
					hint_ok = false
					break
				var st := walk.move_state(rec)
				if st == "ok":
					walk.remove(rec)
				elif st == "ram":
					walk.ram(rec)
				else:
					hint_ok = false
					break
			if not hint_ok:
				replay_ok -= 1000
	_check(agree == boards, "Solver agrees with brute force on %d / %d random small portal boards (%d solvable)" % [agree, boards, solvable])
	_check(replay_ok == solvable, "every Solver solution and SHOW A MOVE sequence replays legally with the real rules (%d boards)" % solvable)
	_check(portal_used > 20, "the sample exercises portal moves (%d solutions use a portal)" % portal_used)


func _hammer() -> void:
	# A board where smashing one block makes it unsolvable, through a portal.
	# Y (2,0) spinner: must turn once (via R escaping) to point free.
	var maps := [
		["R> OA Y^@ .", ".  .  Gv  .", ".  .  .   .", ".  .  OA  P<"],
		[".  Rv OA .", "B> .  .  .", ".  Y^@ .  G<", ".  .  .  OA"],
	]
	var checked := 0
	var agree := 0
	for map in maps:
		var m := board(map)
		var before := _brute(board(map), {})
		for id in m.blocks.keys():
			var test := board(map)
			test.remove(id)
			var after := test.is_empty() or _brute(test, {})
			var expect := after or not before
			checked += 1
			if Solver.hammer_safe(m, id) == expect:
				agree += 1
	_check(agree == checked and checked > 0, "Hammer safety on portal boards matches brute force (%d / %d smashes)" % [agree, checked])
	# hammer_safe copies the portals into its test board.
	var m2 := board(["R> OA .", ".  .  .", "Pv .  OA"])
	var test := BoardModel.new()
	test.setup(m2.rows, m2.columns, m2.snapshot())
	test.set_portals(m2.portal_groups)
	_check(test.portals == m2.portals, "a copied board keeps its portals (as hammer_safe builds it)")


# --- Lab data ---------------------------------------------------------------------------

func _lab_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(MechLab.DATA_PATH))
	_check(typeof(data) == TYPE_DICTIONARY and data.get("mechanic", "") == "portal", "lab board file loads")
	if typeof(data) != TYPE_DICTIONARY:
		return
	var ids := {}
	var portal_n := 0
	var control_n := 0
	var ok := true
	for rec in data["boards"]:
		ids[rec["id"]] = rec
	for rec in data["boards"]:
		var def := PuzzleDefinition.from_dict(rec["puzzle"])
		if def == null:
			ok = false
			print("  bad puzzle " + str(rec["id"]))
			continue
		var level := def.to_level()
		var m := BoardModel.new()
		m.setup(level.rows, level.columns, level.blocks)
		m.set_portals(level.portals)
		var s := Solver.from_model(m)
		var moves := s.solve_moves()
		var uses := 0
		for mv in moves:
			if not m.lane(mv & Solver.ID_MASK)["via"].is_empty():
				uses += 1
			if mv & Solver.RAM:
				m.ram(mv & Solver.ID_MASK)
			else:
				m.remove(mv)
		if moves.is_empty() or s.aborted or not m.is_empty():
			ok = false
			print("  unsolvable " + str(rec["id"]))
		if rec["variant"] == "portal":
			portal_n += 1
			if level.portals.is_empty() or uses == 0:
				ok = false
				print("  portal board without a portal move " + str(rec["id"]))
		else:
			control_n += 1
			if not level.portals.is_empty() or not ids.has(rec["pair"]) or ids[rec["pair"]]["variant"] != "portal":
				ok = false
				print("  bad control " + str(rec["id"]))
			elif level.blocks.size() != PuzzleDefinition.from_dict(ids[rec["pair"]]["puzzle"]).to_level().blocks.size():
				ok = false
				print("  control block count differs " + str(rec["id"]))
	_check(ok, "every lab board is solvable; portal boards use a portal; controls match their portal board without portals")
	_check(portal_n >= 8 and portal_n <= 12 and control_n >= 4, "%d portal boards, %d matched controls" % [portal_n, control_n])


# --- Play flow (SocialPlay as the lab uses it) -------------------------------------------

func _play_flow() -> void:
	var play := SocialPlay.new()
	add_child(play)
	await _frames(2)
	var map := [".  .  .  .  .", "R> .  OA .  .", ".  .  .  .  .", "OA P> .  .  .", ".  .  G^ .  ."]
	var def := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 5, "cols": 5, "map": map})
	play.start(SharedChallenge.friend_challenge(def, FriendGenerator.MEDIUM), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	await _frames(2)
	_check(play.model.portals.size() == 2 and play.board.portals.size() == 2, "SocialPlay loads the portals into the rules and the board view")
	var r := id_at(play.model, 0, 1)
	var p := id_at(play.model, 1, 3)
	play.tap_block(r)
	_check(play.total_blocked == 1 and play.total_portal_blocked == 1 and play._message.text.contains("portal A"), "blocked portal tap: counted, 'Blocked after portal A' shown")
	play.tap_block(p)
	play.tap_block(r)
	_check(play.total_portal_uses == 1 and not play.model.blocks.has(r), "portal escape: counted, the block is gone")
	play.undo()
	_check(play.model.blocks.has(r) and play.model.portals.size() == 2 and play.model.move_state(r) == "ok", "Undo brings the block back; portals unchanged")
	play.restart()
	await _frames(1)
	_check(play.model.portals.size() == 2 and play.board.portals.size() == 2 and play.model.block_count() == 3, "Restart rebuilds the same portal board")
	_check(play.model.move_state(id_at(play.model, 0, 1)) == "blocked", "after Restart the exit is blocked again")
	play.hint()
	var hinted := -1
	for id in play.model.blocks:
		if play.board.get_view(id).hinted:
			hinted = id
	_check(hinted != -1 and play.model.is_playable(hinted), "SHOW A MOVE marks a legal move on a portal board")
	# A normal Social board: no portals anywhere.
	var normal := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 2, "cols": 2, "map": ["R> .", ". B^"]})
	play.start(SharedChallenge.friend_challenge(normal, FriendGenerator.EASY), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	await _frames(1)
	_check(play.model.portals.is_empty() and play.board.portals.is_empty() and play.total_portal_uses == 0, "a normal board after a portal board: no portals left over")
	_check(play.max_hammers == SocialPlay.MAX_HAMMERS and play.max_hints == SocialPlay.MAX_HINTS, "SocialPlay defaults unchanged")
	play.end()
	play.queue_free()


func _lab_flow() -> void:
	_check(not MechLab.requested(), "the lab does not open without ?mechlab=1 / --mechlab")
	var lab := MechLab.new()
	add_child(lab)
	await _frames(3)
	var order: Array = lab.state["order"]
	_check(lab.screen == MechLab.Screen.INTRO and lab.total() == lab.boards.size(), "lab: intro, every board in the order once")
	var a_first := true
	for i in order.size():
		var stage: String = lab.boards[order[i]]["stage"]
		if stage == "A" and i > 2:
			a_first = false
	_check(a_first and lab.boards[order[0]]["stage"] == "A", "basic boards come first")
	var adjacent := false
	for i in range(1, order.size()):
		if lab.boards[order[i]]["pair"] == lab.boards[order[i - 1]]["pair"]:
			adjacent = true
	_check(not adjacent, "a board and its control are never back to back")
	var text := lab._intro_text.text.to_lower()
	_check(not text.contains("control"), "the intro never says which boards are controls")
	lab.start_demo()
	await _frames(2)
	_check(lab.screen == MechLab.Screen.DEMO and lab.play.visible and lab.play.model.portals.size() == 2, "demo: a portal board, played by the lab")
	lab._end_demo()
	lab.start_next()
	await _frames(2)
	var p := lab.play
	_check(p._title.text == "PUZZLE 1 / %d" % lab.total() and p._chip.text == "" and p._hammer.visible == false and p._hint.badge_text == "1",
		"puzzle 1: neutral title, no difficulty chip, no HAMMER, SHOW A MOVE x1")
	# Solve it with the Solver's moves.
	for i in 60:
		if p.completed or not p.play_solver_move():
			break
	await get_tree().create_timer(1.3).timeout
	_check(lab.screen == MechLab.Screen.QUESTION and lab._asks == MechLab.ASK["A"], "solved basic board -> rating, then clarity")
	lab.answer("MEDIUM")
	lab.answer("CLEAR")
	await _frames(2)
	_check(lab.state["results"].size() == 1 and lab.state["results"][0]["rating"] == "MEDIUM" and lab.state["results"][0]["clarity"] == "CLEAR"
		and lab.state["results"][0]["completed"] and lab.state["results"][0]["portal_uses"] >= 1, "result 1 recorded (rating, clarity, portal uses)")
	_check(lab.screen == MechLab.Screen.PLAYING and p._title.text == "PUZZLE 2 / %d" % lab.total(), "next board starts")
	p._leave()
	await _frames(2)
	_check(lab.screen == MechLab.Screen.QUESTION and not lab._current["completed"], "EXIT -> LEAVE: recorded as not solved, still asked")
	for i in lab._asks.size():
		lab.answer("")
	# Reload: resumes at puzzle 3 with both results.
	lab.play.end()
	lab.queue_free()
	await _frames(2)
	var lab2 := MechLab.new()
	add_child(lab2)
	await _frames(3)
	_check(lab2.state["index"] == 2 and lab2.state["results"].size() == 2 and lab2.state["order"] == order, "reload: resumes at puzzle 3, same order")
	var json = JSON.parse_string(lab2.results_json())
	_check(typeof(json) == TYPE_DICTIONARY and json["format"] == "ce-mechlab-results" and json["results"].size() == 2 and json.has("summary") and json.has("pairs"), "COPY RESULTS JSON")
	_check(not FileAccess.file_exists(PROGRESS_PATH), "the lab never writes the Classic save")
	lab2.reset_test()
	lab2.queue_free()
