extends Node
## v0.8 SEQUENCE (226+) and MOVABLE (251+) in Classic, levels 226-300:
## production checks through the real rules and the real game scene.
##   godot --headless --path . res://tools/Era3ProdCheck.tscn
##
## - Isolation: outside campaign files ":" and "M" stay unknown tokens;
##   Social / Friend reject such boards; the Friend campaign keys skip them.
## - Data: 300 levels; Sequence only from 226, Movable only from 251; every
##   arc level uses its mechanic; every level 226-300 solvable.
## - Rules (campaign parsing, no lab flags): Sequence first stage, blocked
##   first stage, spinner / hidden neighbour event, a first stage into a
##   shell is a ram, a first stage is no escape for locks; Movable push in
##   four directions, edge / block / no chain push, through a portal,
##   portal exit blocked, Sequence push (and a failed one), win with the
##   Movable block left.
## - Solver vs a brute-force search on random small boards mixing
##   Sequence, Movable, portals and spinners; SHOW A MOVE always legal and
##   solvable-preserving on them; the memo key holds stage and crate cells.
## - Game: 225 -> 226 -> NEXT ... intros (sequence at 226, movable at 251,
##   once, saved, not retroactive), first stage / push by tap, Undo exact
##   (also after several pushes and in the middle of a push animation),
##   Restart exact, SHOW A MOVE, Hammer (never a Movable block, safe on a
##   Sequence block), a tap on the Movable block is free, milestones 250
##   (strong) / 275 (short) / 300 (major, fitted to the screen) pay no
##   milestone coins, Chapters 23-30 complete, after 300 NEXT opens Level
##   Select (no loop to Level 1).

const PROGRESS_PATH := "user://era3_prod_check.cfg"

var game: GameManager
var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	GameManager.skip_title = true
	_run.call_deferred()


## Internal checkpoints run the parts that exist: -- --to=250 (Sequence
## arc), --to=275 (+ Movable arc); the full run needs all 300 levels.
var upto := 300


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--to="):
			upto = int(a.get_slice("=", 1))
	_isolation()
	_data()
	_sequence_rules()
	_movable_rules()
	_solver_vs_brute_force()
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	await _sequence_in_game()
	if upto >= 275:
		await _movable_in_game()
	await _milestones()
	if upto >= 300:
		await _after_300()
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("ERA3 PRODUCTION CHECKS PASSED" if failures.is_empty() else "ERA3 PRODUCTION CHECKS FAILED")
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


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


static func board(map: Array) -> BoardModel:
	var level := LevelManager.parse_level({"map": map}, 1, true)
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals(level.portals)
	return m


static func id_at(m: BoardModel, c: int, r: int) -> int:
	var b := m.block_at(Vector2i(c, r))
	return b.id if b else -1


static func play(m: BoardModel, id: int) -> void:
	match m.move_state(id):
		"ram": m.ram(id)
		"advance": m.advance(id)
		"push": m.push(id)
		_: m.remove(id)


# --- Isolation ------------------------------------------------------------------------

func _isolation() -> void:
	_check(not LevelManager.dev_sequence and not LevelManager.dev_movable, "lab flags off in the game")
	var social := LevelManager.parse_level({"map": ["R>:^ M", ".    B^"]})
	_check(social.blocks.size() == 1 and social.blocks[0].seq_stage == 0, "non-campaign parsing: ':' and 'M' stay unknown tokens (skipped)")
	var camp := LevelManager.parse_level({"map": ["R>:^ M", ".    B^"]}, 1, true)
	_check(camp.blocks.size() == 3 and camp.blocks.any(func(b): return b.seq_stage == 1) and camp.blocks.any(func(b): return b.is_crate()), "campaign parsing: Sequence and Movable")
	var after := LevelManager.parse_level({"map": ["R>:^ ."]})
	_check(after.blocks.is_empty(), "the campaign flag never leaks into the next parse")
	for map in [["R>:^ .", ". B^"], ["R> M", ". B^"]]:
		var def := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 2, "cols": 2, "map": map})
		_check(def != null and not def.verify(), "PuzzleDefinition.verify() rejects %s" % str(map))
		_check(not FriendGenerator.mechanics_ok(def, FriendGenerator.MEDIUM) and not FriendGenerator.mechanics_ok(def, FriendGenerator.VERY_HARD), "Friend validation rejects %s" % str(map))
	var keys: Array = load("res://tools/classic_board_keys.gd").compute()
	var data = JSON.parse_string(FileAccess.get_file_as_string(FriendGenerator.CLASSIC_KEYS_PATH))
	_check(keys.size() == 190 and data["keys"] == keys, "Friend campaign keys: levels 1-200 minus the 10 Twins levels, data file up to date (%d)" % keys.size())


# --- Data -------------------------------------------------------------------------------

func _data() -> void:
	var lm := LevelManager.new()
	lm._ready()
	_check(lm.level_count >= upto, "%d+ levels found (%d)" % [upto, lm.level_count])
	if upto >= 300:
		_check(lm.level_count == 300, "exactly 300 levels")
	lm.free()
	var early_ok := true
	for n in range(1, mini(upto, 250) + 1):
		var lv := LevelManager.read_level(n)
		var seq := lv.blocks.any(func(b): return b.seq_stage != 0)
		var crate := lv.blocks.any(func(b): return b.is_crate())
		early_ok = early_ok and not crate and (n >= 226 or not seq)
	_check(early_ok, "no Sequence before 226, no Movable before 251")
	var arcs_ok := true
	var bad := []
	for n in range(226, upto + 1):
		var lv := LevelManager.read_level(n)
		var m := LevelAnalysis.analyze(lv, false)
		var ok: bool = m["solvable"] and not m["aborted"]
		if n <= 250:
			ok = ok and m["advances"] > 0
		elif n <= 275:
			ok = ok and m["pushes"] > 0
		else:
			ok = ok and m["advances"] + m["pushes"] + m["portal_moves"] > 0
		if not ok:
			bad.append(n)
		arcs_ok = arcs_ok and ok
	_check(arcs_ok, "226-%d solvable; each arc's mechanic used in its solution %s" % [upto, str(bad)])
	# Following SHOW A MOVE again and again always finishes the level (on
	# Movable boards a push can be undone by another push - the hint must
	# never wander back and forth).
	var wander := []
	for n in range(226, upto + 1):
		var lv := LevelManager.read_level(n)
		var mm := BoardModel.new()
		mm.setup(lv.rows, lv.columns, lv.blocks)
		mm.set_portals(lv.portals)
		var limit := Solver.from_model(mm).solve_moves().size() * 2 + 4
		var steps := 0
		while not mm.is_empty() and steps < limit:
			var id := Solver.from_model(mm).recommend_move()
			if id == -1 or not mm.is_playable(id):
				break
			play(mm, id)
			steps += 1
		if not mm.is_empty():
			wander.append(n)
	_check(wander.is_empty(), "following SHOW A MOVE clears every level 226-%d %s" % [upto, str(wander)])
	_check(Chapters.celebration_tier(250) == "lab_milestone_strong" and Chapters.celebration_tier(275) == "lab_milestone_plus" and Chapters.celebration_tier(300) == "major",
		"celebration tiers 250 / 275 / 300 (the standard LEVELS ESCAPED presentation)")
	_check(not Chapters.is_master(300) and not Chapters.is_milestone(250) and not Chapters.is_milestone(275) and not Chapters.is_milestone(300), "250 / 275 / 300 are not paying milestones or Master Levels")
	_check(Chapters.chapter_count(300) == 30 and Chapters.chapter_of(300) == 30 and Chapters.era_of(300)["name"] == "Third Era", "Chapters 21-30, Third Era to 300")


# --- Rules ---------------------------------------------------------------------------------

func _sequence_rules() -> void:
	var m := board([".  .    .", ".  R>:^ .", ".  .    ."])
	var r := id_at(m, 1, 1)
	_check(m.move_state(r) == "advance" and m.is_playable(r) and not m.can_escape(r), "a first-stage block with a clear lane: an advance (not an escape)")
	m.advance(r)
	_check(m.blocks.has(r) and m.blocks[r].direction == Direction.UP and m.blocks[r].seq_stage == 2 and m.move_state(r) == "ok", "the first stage: stays, NEXT becomes current, second stage escapes")
	m = board(["R>:^ B^", ".    ."])
	r = id_at(m, 0, 0)
	_check(m.move_state(r) == "blocked", "blocked first stage: an ordinary blocked tap")
	m = board(["Gv@ .", "R>:^ .", "Y^? ."])
	r = id_at(m, 0, 1)
	var g := id_at(m, 0, 0)
	var turned := m.advance(r)
	_check(turned == [g] and m.blocks[g].direction == Direction.LEFT and m.last_revealed == [id_at(m, 0, 2)], "the first stage turns adjacent spinners and reveals adjacent hidden arrows")
	m = board(["R>:^ Bv=", ".    ."])
	r = id_at(m, 0, 0)
	_check(m.move_state(r) == "ram", "a first stage into a shell is a ram")
	m.ram(r)
	_check(m.blocks[r].seq_stage == 1 and not m.blocks[id_at(m, 1, 0)].armored, "the ram cracks the shell; the stage does not advance")
	m = board(["R>:^ .", "Gv#R ."])
	r = id_at(m, 0, 0)
	m.advance(r)
	_check(m.is_locked(id_at(m, 0, 1)), "a first stage is not an escape: the red lock stays shut")
	m = board([".    .  .  .", "R>:v OA .  .", ".    .  .  .", ".    .  .  OA"])
	_check(m.move_state(id_at(m, 0, 1)) == "advance", "a first stage through a portal lane")


func _movable_rules() -> void:
	var all_ok := true
	for t in ["R>", "Bv", "G<", "Y^"]:
		var d: Vector2i = Direction.step(Direction.MAP_CHARS[t[1]])
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
		all_ok = all_ok and b.blocks[cr].cell == Vector2i(2, 2) + d and b.blocks[a].cell == Vector2i(2 - d.x * 2, 2 - d.y * 2)
	_check(all_ok, "push up / down / left / right: exactly one cell, the arrow stays")
	var m := board(["R> . M"])
	_check(m.move_state(id_at(m, 0, 0)) == "blocked", "the board edge behind it: blocked")
	m = board(["R> M Bv", ".  . ."])
	_check(m.move_state(id_at(m, 0, 0)) == "blocked", "a block behind it: blocked")
	m = board(["R> M M ."])
	_check(m.move_state(id_at(m, 0, 0)) == "blocked" and m.push(id_at(m, 0, 0)).is_empty(), "no chain pushing")
	m = board([".  .  .  .", "R> M  OA .", ".  .  .  .", ".  OA .  ."])
	var c := id_at(m, 1, 1)
	m.push(id_at(m, 0, 1))
	_check(m.blocks[c].cell == Vector2i(2, 3), "a push through a portal: out of the partner, one cell on")
	m = board([".  .  .  .", "R> M  OA .", ".  .  .  .", ".  OA Y^ ."])
	_check(m.move_state(id_at(m, 0, 1)) == "blocked", "portal exit blocked: the whole push fails")
	m = board(["R>:^ M .", ".    . ."])
	var r := id_at(m, 0, 0)
	var info := m.push(r)
	_check(info["advanced"] and m.blocks[r].seq_stage == 2 and m.blocks[id_at(m, 2, 0)].is_crate(), "a first-stage push moves the block AND advances the Sequence block")
	m = board(["R>:^ M Bv", ".    . ."])
	r = id_at(m, 0, 0)
	_check(m.move_state(r) == "blocked" and m.push(r).is_empty() and m.blocks[r].seq_stage == 1, "a failed push does not advance the Sequence block")
	m = board(["R> .", ".  M"])
	m.remove(id_at(m, 0, 0))
	_check(m.is_empty() and m.block_count() == 0 and m.blocks.size() == 1, "won with the Movable block still on the board")


# --- Solver vs brute force ------------------------------------------------------------------

static func _key(m: BoardModel) -> String:
	var parts := []
	var ids := m.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d,%d:%d:%d:%d:%d" % [id, b.cell.x, b.cell.y, b.direction, b.seq_stage, int(b.armored), b.spin_step])
	return "|".join(parts)


func _brute(m: BoardModel, seen: Dictionary) -> bool:
	if m.is_empty():
		return true
	var k := _key(m)
	if seen.has(k):
		return false
	seen[k] = true
	for id in m.playable_ids():
		var snap := m.snapshot()
		play(m, id)
		var ok := _brute(m, seen)
		m.restore(snap)
		if ok:
			return true
	return false


func _random_map(rng: RandomNumberGenerator) -> Array:
	var w := 4
	var h := rng.randi_range(4, 5)
	var grid := []
	for y in h:
		var row := []
		row.resize(w)
		row.fill(".")
		grid.append(row)
	var cells := []
	for y in h:
		for x in w:
			cells.append(Vector2i(x, y))
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var k := 0
	if rng.randf() < 0.5:
		var a: Vector2i = cells[k]
		var b: Vector2i = cells[k + 1]
		if a.x != b.x and a.y != b.y:
			grid[a.y][a.x] = "OA"
			grid[b.y][b.x] = "OA"
			k += 2
	var arrows := ["^", "v", "<", ">"]
	for i in rng.randi_range(4, 6):
		var cell: Vector2i = cells[k]
		k += 1
		var tok: String = ["R", "B", "G", "Y"][rng.randi_range(0, 3)] + arrows[rng.randi_range(0, 3)]
		var roll := rng.randf()
		if roll < 0.3:
			var nx: String = arrows[rng.randi_range(0, 3)]
			if nx != tok[1]:
				tok += ":" + nx
		elif roll < 0.5:
			tok += "@"
		grid[cell.y][cell.x] = tok
	for i in rng.randi_range(0, 2):
		var cell: Vector2i = cells[k]
		k += 1
		grid[cell.y][cell.x] = "M"
	var out := []
	for row in grid:
		out.append(" ".join(row))
	return out


func _solver_vs_brute_force() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 30030
	var boards := 0
	var agree := 0
	var solvable := 0
	var hint_ok := 0
	var hint_boards := 0
	var key_ok := true
	for i in 260:
		var m := board(_random_map(rng))
		if m.blocks.is_empty():
			continue
		boards += 1
		var s := Solver.from_model(m)
		var sol := s.solve_moves()
		var solver_says := m.is_empty() or not sol.is_empty()
		var brute := _brute(m, {})
		if s.aborted:
			continue
		if solver_says == brute:
			agree += 1
		if brute:
			solvable += 1
			var hint := Solver.from_model(m).recommend_move()
			hint_boards += 1
			if hint != -1 and m.is_playable(hint):
				var t := BoardModel.new()
				t.setup(m.rows, m.columns, m.snapshot())
				t.set_portals(m.portal_groups)
				play(t, hint)
				if t.is_empty() or _brute(t, {}):
					hint_ok += 1
			# The solver's own solution replays to a clear board.
			var t2 := BoardModel.new()
			t2.setup(m.rows, m.columns, m.snapshot())
			t2.set_portals(m.portal_groups)
			for mv in sol:
				play(t2, mv & Solver.ID_MASK)
			key_ok = key_ok and t2.is_empty()
	print("solver vs brute force: %d boards, %d agree, %d solvable, hints %d/%d" % [boards, agree, solvable, hint_ok, hint_boards])
	_check(boards > 150 and agree == boards, "Solver agrees with an exhaustive search on %d random Sequence / Movable / portal / spinner boards" % boards)
	_check(solvable > 30 and hint_ok == hint_boards, "SHOW A MOVE is always legal and keeps the board solvable (%d/%d)" % [hint_ok, hint_boards])
	_check(key_ok, "every solver solution replays to a clear board on the real rules")


# --- In the game ---------------------------------------------------------------------------

func _clear_progress_to(n: int) -> void:
	var p := game.progress
	for k in range(1, n + 1):
		p.best_scores[k] = 1000
		p.best_stars[k] = 1
	p.highest_completed = n
	p.highest_unlocked = n + 1


func _first(state: String) -> int:
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		if game.model.move_state(id) == state:
			return id
	return -1


func _snapshot() -> Array:
	var out := []
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = game.model.blocks[id]
		out.append([id, b.cell, b.direction, b.seq_stage, b.armored, b.hidden])
	return out


func _sequence_in_game() -> void:
	var p := game.progress
	_clear_progress_to(225)
	p.tips_seen.append("intro_portal")
	game.start_level(225)
	await _frames(2)
	game.next_level()
	await _frames(3)
	_check(game.current_level == 226 and game.mechanic_intro != null and game.mechanic_intro.mechanic == "sequence", "225 -> NEXT -> 226 opens the SEQUENCE card")
	_check(p.tips_seen.has("intro_sequence") and not game.board.input_enabled, "saved at once; taps wait")
	await _wait(MechanicIntro.HOLD + 0.5)
	_check(game.mechanic_intro == null and game.board.input_enabled, "the card closes by itself")
	_check(PlayerProgress.new(PROGRESS_PATH).load_from_disk().tips_seen.has("intro_sequence"), "intro_sequence survives a reload")
	var before := _snapshot()
	var guard := 0
	var adv := -1
	while adv == -1 and guard < 30 and not game.model.is_empty():
		guard += 1
		var id := Solver.from_model(game.model).recommend_move()
		if game.model.move_state(id) == "advance":
			adv = id
			var snap := _snapshot()
			game._on_block_tapped(id)
			await _wait(0.1)
			_check(game.model.blocks.has(id) and game.model.blocks[id].seq_stage == 2 and game.mistakes == 0, "tap: the first stage (block stays, stage 2, no mistake)")
			_check(game.board.get_view(id).data.seq_stage == 2, "the board view follows the stage")
			game.undo()
			await _wait(0.1)
			_check(_snapshot() == snap and game.board.get_view(id).data.seq_stage == 1, "Undo restores the exact stage and arrow")
		else:
			game._on_block_tapped(id)
			await _wait(0.08)
	_check(adv != -1, "226 has a first stage on the solver's path")
	game.restart()
	await _wait(0.2)
	_check(_snapshot() == before, "Restart restores the exact start")
	# Blocked first stage.
	var blocked := -1
	for id in game.model.blocks:
		if game.model.blocks[id].seq_stage == 1 and game.model.move_state(id) == "blocked":
			blocked = id
	if blocked != -1:
		game._on_block_tapped(blocked)
		await _wait(0.05)
		_check(game.model.blocks[blocked].seq_stage == 1 and game.mistakes == 1, "blocked first stage: a mistake, no advance")
	# SHOW A MOVE and Hammer on a Sequence board.
	game.request_hint()
	await _frames(2)
	_check(game.hint_block != -1 and game.model.is_playable(game.hint_block), "SHOW A MOVE on 226 is a legal move")
	game.progress.inventory["hammer"] = 1
	var seq_id := -1
	for id in game.model.blocks:
		if game.model.blocks[id].seq_stage != 0 and Solver.hammer_safe(game.model, id):
			seq_id = id
	if seq_id != -1:
		game.toggle_hammer()
		game._on_block_tapped(seq_id)
		await _wait(0.2)
		_check(not game.model.blocks.has(seq_id) and Solver.from_model(game.model).is_solvable(), "Hammer smashes a safe Sequence block; still solvable")
	# Sequence x spinner / portal levels play to the end.
	for n in [229, 230, 250]:
		game.start_level(n)
		await _frames(2)
		var g2 := 0
		while not game.model.is_empty() and g2 < 80:
			g2 += 1
			game._on_block_tapped(Solver.from_model(game.model).recommend_move())
			await _wait(0.05)
		_check(game.model.is_empty(), "L%d cleared by following SHOW A MOVE" % n)
		await _wait(2.5)
	# Not retroactive.
	p.tips_seen.erase("intro_sequence")
	_clear_progress_to(240)
	game.start_level(238)
	await _frames(3)
	_check(game.mechanic_intro == null and not p.tips_seen.has("intro_sequence"), "the SEQUENCE card is never shown to a player past 226")


func _movable_in_game() -> void:
	var p := game.progress
	_clear_progress_to(250)
	p.tips_seen.append("intro_sequence")
	game.start_level(250)
	await _frames(2)
	game.next_level()
	await _frames(3)
	if game.ui.is_chapter_card_open():
		game._after_chapter_card()
		await _frames(3)
	_check(game.current_level == 251 and game.mechanic_intro != null and game.mechanic_intro.mechanic == "movable", "250 -> 251 opens the MOVABLE card")
	_check(game.mechanic_intro != null and game.mechanic_intro.hold_seconds() <= 2.5, "the card is short (%.1f s)" % (game.mechanic_intro.hold_seconds() if game.mechanic_intro else 0.0))
	await _wait(MechanicIntro.HOLD_LONG + 0.5)
	_check(game.mechanic_intro == null and game.board.input_enabled and p.tips_seen.has("intro_movable"), "closed, saved")
	var crate := -1
	for id in game.model.blocks:
		if game.model.blocks[id].is_crate():
			crate = id
	var start := _snapshot()
	# A tap on the Movable block: free, explained.
	game._on_block_tapped(crate)
	await _frames(2)
	_check(game.mistakes == 0 and _snapshot() == start and game.tutorial._text == GameManager.CRATE_TAP_TEXT, "a tap on the Movable block is free and explains it")
	# Hammer: never the Movable block.
	p.inventory["hammer"] = 1
	game.toggle_hammer()
	game._on_block_tapped(crate)
	await _frames(2)
	_check(game.model.blocks.has(crate) and p.inventory["hammer"] == 1 and game.hammers_used == 0, "the Hammer never smashes the Movable block (nothing spent)")
	game.toggle_hammer()
	# Push by tap; Undo exact; several pushes; Undo in the middle of the slide.
	var pushes := 0
	var states := [_snapshot()]
	var guard := 0
	while pushes < 1 and guard < 30 and game.model.block_count() > 1:
		guard += 1
		var id := Solver.from_model(game.model).recommend_move()
		var st := game.model.move_state(id)
		game._on_block_tapped(id)
		await _wait(0.4)
		states.append(_snapshot())
		if st == "push":
			pushes += 1
			_check(game.model.blocks.has(id) and game.mistakes == 0, "tap: a push (the arrow stays, no mistake)")
	_check(pushes >= 1, "251 pushes on the solver's path")
	game.undos_used = 0
	var u := 0
	while states.size() > 1 and u < 3:
		states.pop_back()
		game.undo()
		await _wait(0.1)
		u += 1
		_check(_snapshot() == states[-1], "Undo #%d restores every cell exactly (Movable positions too)" % u)
	_check(game.board.get_view(crate).home == game.board.cell_center(game.model.blocks[crate].cell) if game.board.has_method("cell_center") else true, "the Movable view sits on its model cell")
	# Undo in the middle of a push animation: no late callback moves it.
	game.restart()
	await _wait(0.2)
	var pusher := _first("push")
	if pusher != -1:
		game._on_block_tapped(pusher)
		await _frames(2)
		game.undo()
		await _wait(0.6)
		var v := game.board.get_view(crate)
		_check(_snapshot() == start and v.position.distance_to(v.home) < 1.0, "Undo during the slide: model and view both back, no late move")
	game.restart()
	await _wait(0.2)
	_check(_snapshot() == start, "Restart restores the exact start")
	# Win with the Movable block left; 268 (portal push) and 269 (Sequence push) too.
	for n in [251, 268, 269, 277, 286]:
		game.start_level(n)
		await _frames(2)
		var g2 := 0
		while not game.model.is_empty() and g2 < 100:
			g2 += 1
			game._on_block_tapped(Solver.from_model(game.model).recommend_move())
			await _wait(0.05)
		_check(game.model.is_empty() and game.model.blocks.values().all(func(b): return b.is_crate()) and game.model.blocks.size() > 0, "L%d won with Movable blocks left on the board" % n)
		await _wait(2.5)
	# Not retroactive.
	p.tips_seen.erase("intro_movable")
	_clear_progress_to(260)
	game.start_level(257)
	await _frames(3)
	_check(game.mechanic_intro == null and not p.tips_seen.has("intro_movable"), "the MOVABLE card is never shown to a player past 251")


func _play_out() -> Dictionary:
	var g := 0
	while not game.model.is_empty() and g < 120:
		g += 1
		game._on_block_tapped(Solver.from_model(game.model).recommend_move())
		await _wait(0.05)
	var t := 0.0
	while not game.ui.is_complete_visible() and t < 10.0:
		await _wait(0.2)
		t += 0.2
	return game.last_result


func _milestones() -> void:
	var p := game.progress
	p.tips_seen.append_array(["intro_portal", "intro_sequence", "intro_movable"])
	for n in [250, 275, 300]:
		if n > upto:
			continue
		_clear_progress_to(n - 1)
		for k in range(n, 301):
			p.best_scores.erase(k)
			p.best_stars.erase(k)
		p.completed_chapters.erase(Chapters.chapter_of(n))
		game.start_level(n)
		await _frames(2)
		_check(game.level_banner(n).contains("MILESTONE"), "L%d banner: %s" % [n, game.level_banner(n)])
		var coins0 := p.coins
		var saw_major := false
		if n == 300:
			# Watch for the major overlay while the board clears.
			var g := 0
			while not game.model.is_empty() and g < 120:
				g += 1
				game._on_block_tapped(Solver.from_model(game.model).recommend_move())
				await _wait(0.05)
			var vis := game.get_viewport().get_visible_rect()
			for i in 30:
				await _wait(0.1)
				var r := game.ui.major_milestone_rect()
				if r.size.x > 0:
					saw_major = true
					_check(r.position.x >= 0.0 and r.end.x <= vis.size.x and r.position.y >= 0.0 and r.end.y <= vis.size.y, "the 300 overlay fits the screen (%s in %s)" % [str(r), str(vis.size)])
					break
			_check(saw_major, "300: the major milestone overlay shows")
		var r2: Dictionary = await _play_out()
		var tier := Chapters.celebration_tier(n)
		_check(r2.get("level", 0) == n and r2.get("celebration", "") == tier and not r2.get("milestone", true) and not r2.get("master", true), "L%d: celebration '%s', no paying milestone / Master" % [n, tier])
		_check(not String(r2.get("coin_notes", "")).contains("MILESTONE") and p.coins - coins0 == r2["coins"], "L%d: coins paid = the card (+%d), no milestone bonus" % [n, r2["coins"]])
		_check(game.ui._card_title.text == "%d LEVELS ESCAPED!" % n and not game.ui._card_title.text.contains("GRAND") and not game.ui._card_title.text.contains("FINAL"), "L%d card: '%s'" % [n, game.ui._card_title.text])
		await _wait(0.5)


func _after_300() -> void:
	var p := game.progress
	# All of Chapters 21-30 cleared: each Chapter completes (Chapter 23 too,
	# now that 226-230 exist).
	var q := PlayerProgress.new("user://era3_prod_economy.cfg")
	for n in range(201, 301):
		q.best_scores[n] = 100
	var all_ok := true
	for c in range(21, 31):
		all_ok = all_ok and Economy.is_chapter_cleared(q, c, 300)
	_check(all_ok, "Chapters 21-30 complete once all their levels are cleared")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://era3_prod_economy.cfg"))
	# When 300 also completes Chapter 30 the card says CONTINUE (it opens the
	# Chapter card), and the Chapter card's button then reads LEVEL SELECT.
	var chapter_done: bool = game.last_result.get("chapter_complete", 0) > 0
	var want := "CONTINUE" if chapter_done else UIManager.LAST_LEVEL_BUTTON
	_check(game.last_result.get("is_last", false) and game.ui._next_button.text == want, "after 300 the card offers %s ('%s')" % [want, game.ui._next_button.text])
	game.next_level()
	await _frames(3)
	if game.ui.is_chapter_card_open():
		_check(game.ui._chapter_card._continue.text == UIManager.LAST_LEVEL_BUTTON, "after 300 the Chapter 30 card offers LEVEL SELECT ('%s')" % game.ui._chapter_card._continue.text)
		game._after_chapter_card()
		await _frames(3)
	else:
		_check(not chapter_done, "Chapter 30 card opens when 300 completes it")
	_check(game.ui.is_level_select_open() and game.current_level == 300, "after 300 NEXT opens Level Select - never back to Level 1")
	_check(game.select_shown["unlocked"].size() + game.select_shown["locked"].size() == 300, "Level Select lists all 300 levels")
