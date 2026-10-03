extends Node
## SEQUENCE MECHANIC PROTOTYPE (development only): technical checks.
##   godot --headless --path . res://tools/SequenceCheck.tscn
## Token gating (outside the lab a Sequence cell is a bad token, exactly as
## before), the two stages, blocked stages, the neighbour event (spinners of
## every rule, hidden arrows; nothing diagonal or further away), rams, locks,
## Undo / Restart, SHOW A MOVE, Hammer safety, Solver vs a brute-force
## search on random small Sequence boards (the stage is in the memo key),
## the lab's board file and page flow, and Social / Friend isolation.

const PROGRESS_PATH := "user://sequence_check_progress.cfg"
const SEQ_STATE := "user://mechlab_sequence_state.json"

var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	PlayerProgress.default_path = PROGRESS_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEQ_STATE))
	_run.call_deferred()


func _run() -> void:
	_gating()
	LevelManager.dev_sequence = true
	_rules()
	_neighbour_event()
	_other_mechanics()
	_round_trip()
	_solver_vs_brute_force()
	_hammer()
	_lab_data()
	await _play_flow()
	await _lab_flow()
	LevelManager.dev_sequence = false
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("SEQUENCE CHECKS PASSED" if failures.is_empty() else "SEQUENCE CHECKS FAILED")
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
	return m


static func id_at(m: BoardModel, c: int, r: int) -> int:
	var b := m.block_at(Vector2i(c, r))
	return b.id if b else -1


# --- Isolation -----------------------------------------------------------------------------

func _gating() -> void:
	LevelManager.dev_sequence = false
	var level := LevelManager.parse_level({"map": ["R>:^ .", ".    B^"]})
	_check(level.blocks.size() == 1 and level.blocks[0].seq_stage == 0, "outside the lab a Sequence cell is an unknown token (skipped, as before)")
	var def := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 2, "cols": 2, "map": ["R>:^ .", ". B^"]})
	_check(def != null and not def.verify(), "PuzzleDefinition.verify() rejects a Sequence board (Photo / Message / recipient)")
	_check(not FriendGenerator.mechanics_ok(def, FriendGenerator.MEDIUM), "Friend Challenge validation rejects a Sequence cell")
	_check(not RegEx.create_from_string("^(\\.|[RBGYP][\\^v<>](@)?)$").search("R>:^"), "the backend's Friend cell rule (unchanged) rejects a Sequence cell")
	var plain := LevelManager.parse_level({"map": ["R> B^@ Gv#R Y<$S"]})
	_check(plain.blocks.size() == 4 and plain.blocks.all(func(b): return b.seq_stage == 0), "ordinary tokens parse exactly as before")
	_check(not MechLab.requested() and MechLab.requested_mechanic() == "", "no lab without ?mechlab=...")


# --- Rules ---------------------------------------------------------------------------------

func _rules() -> void:
	var m := board([
		".    .  .  .",
		"R>:^ .  .  .",
		".    .  B< .",
		".    G^ .  ."])
	var r := id_at(m, 0, 1)
	var b: BlockData = m.blocks[r]
	_check(b.seq_stage == 1 and b.direction == Direction.RIGHT and b.seq_next == Direction.UP, "R>:^ parses: stage 1, arrow right, next up")
	_check(m.move_state(r) == "advance" and m.is_playable(r) and not m.can_escape(r), "stage 1 with a clear lane: the move is an advance (not an escape)")
	m.advance(r)
	_check(m.blocks.has(r) and m.blocks[r].seq_stage == 2 and m.blocks[r].direction == Direction.UP and m.blocks[r].cell == Vector2i(0, 1),
		"after the advance: still on the board, same cell, stage 2, arrow up")
	_check(m.move_state(r) == "ok", "stage 2: a plain arrow (clear lane up -> escape)")
	m.remove(r)
	_check(not m.blocks.has(r), "stage 2 escapes and is removed")
	# Blocked stage 1 and blocked stage 2.
	m = board([
		".  .    .  .",
		".  Y>   .  .",
		"Bv R<:^ .  .",
		".  .    .  .",
		".  .    G< ."])
	r = id_at(m, 1, 2)
	_check(m.move_state(r) == "blocked" and m.find_blocker(r).id == id_at(m, 0, 2), "stage 1 blocked: an ordinary blocked tap (the blocker is the first block in the lane)")
	m.remove(id_at(m, 0, 2))
	_check(m.move_state(r) == "advance", "stage 1 lane cleared -> advance")
	m.advance(r)
	_check(m.move_state(r) == "blocked" and m.find_blocker(r).id == id_at(m, 1, 1), "stage 2 blocked by the block above it")
	_check(m.advance(r).is_empty() and m.blocks[r].seq_stage == 2, "advance() on a stage-2 block does nothing")
	# Validation: one special role per arrow.
	var bad := LevelManager.parse_level({"map": ["R>@:^ G>?:v B>#R:< Y>=:^"]})
	_check(bad.blocks.all(func(x): return x.seq_stage == 0), "a Sequence block with another modifier (spinner, hidden, lock, armor) is rejected")


func _neighbour_event() -> void:
	# Spinners around the cell turn by their rule; diagonal / far ones don't.
	# Red (lane right clear) has spinners above (clockwise), left
	# (counter-clockwise) and below (pattern); others are diagonal / far.
	var m := board([
		".    Gv@  Yv@~ .",
		"Pv@- R>:^ .    .",
		".    B^@* .    .",
		"Gv@  .    .    Rv@~"])
	var r := id_at(m, 1, 1)
	var up := id_at(m, 1, 0)
	var left := id_at(m, 0, 1)
	var down := id_at(m, 1, 2)
	var diag := id_at(m, 2, 0)
	var far := id_at(m, 0, 3)
	var d_up: int = m.blocks[up].direction
	var d_left: int = m.blocks[left].direction
	var d_down: int = m.blocks[down].direction
	var d_diag: int = m.blocks[diag].direction
	var d_far: int = m.blocks[far].direction
	_check(m.move_state(r) == "advance", "neighbour case: lane clear")
	var turned := m.advance(r)
	turned.sort()
	var want := [up, left, down]
	want.sort()
	_check(turned == want, "the advance turns exactly the orthogonal neighbours")
	_check(m.blocks[up].direction == Direction.rotate_cw(d_up) and m.blocks[up].spin_step == 1, "clockwise spinner: a clockwise turn, step counted")
	_check(m.blocks[left].direction == Direction.rotate_ccw(d_left), "counter-clockwise spinner: a counter-clockwise turn")
	_check(m.blocks[down].direction == Direction.rotate_cw(d_down), "pattern spinner: its first (clockwise) turn")
	_check(m.blocks[diag].direction == d_diag and m.blocks[far].direction == d_far, "diagonal / far spinners do not turn")
	# Alternating spinner: second advance-type event turns it the other way.
	m = board([
		"R>:^ .",
		"Yv@~ .",
		"G>:v ."])
	var y := id_at(m, 0, 1)
	var dy: int = m.blocks[y].direction
	m.advance(id_at(m, 0, 0))
	m.advance(id_at(m, 0, 2))
	_check(m.blocks[y].direction == dy and m.blocks[y].spin_step == 2, "alternating spinner: clockwise then counter-clockwise (two advances next to it)")
	# Hidden arrows next to it are revealed (the same neighbour event).
	m = board([
		"Gv?  R>:^ .",
		".    Y^?  .",
		"B^?  .    ."])
	r = id_at(m, 1, 0)
	m.advance(r)
	_check(not m.blocks[id_at(m, 0, 0)].hidden and not m.blocks[id_at(m, 1, 1)].hidden and m.last_revealed.size() == 2, "hidden arrows next to it are revealed")
	_check(m.blocks[id_at(m, 0, 2)].hidden, "a hidden arrow further away stays hidden")


func _other_mechanics() -> void:
	# Ram: a stage-1 block whose lane runs into a shell rams it; the stage stays.
	var m := board(["R>:^ .  Bv="])
	var r := id_at(m, 0, 0)
	_check(m.move_state(r) == "ram", "stage 1 into a shell: a ram (existing rule)")
	m.ram(r)
	_check(m.blocks[r].seq_stage == 1 and m.move_state(r) == "blocked", "the ram does not advance the stage (the cracked block is still in the lane)")
	m.remove(id_at(m, 2, 0))
	_check(m.move_state(r) == "advance", "once it leaves, stage 1 can advance")
	# Lock: the block's colour keeps the lock closed until it LEAVES (an advance is not leaving).
	m = board([
		"R>:^ .  .",
		".    .  .",
		".    .  Gv#R"])
	r = id_at(m, 0, 0)
	var g := id_at(m, 2, 2)
	m.advance(r)
	_check(m.move_state(g) == "locked", "after the advance its colour is still on the board: the lock stays")
	m.remove(r)
	_check(m.move_state(g) == "ok", "after it escapes the lock opens")
	# Solver on these: a solvable board with a Sequence block is solved.
	var s := Solver.from_model(board(["R>:^ .  Bv=", ".    .  ."]))
	var moves := s.solve_moves()
	_check(not moves.is_empty() and (moves[0] & Solver.RAM) != 0, "the Solver rams, advances and escapes as needed")


func _round_trip() -> void:
	var map := [".  R>:^ .", "Gv@ .  B<:v", ".  .   ."]
	var a := LevelManager.parse_level({"map": map})
	var text := LevelManager.to_json_text(a)
	var b := LevelManager.parse_level(JSON.parse_string(text))
	var same := a.blocks.size() == b.blocks.size()
	for i in a.blocks.size():
		same = same and a.blocks[i].seq_stage == b.blocks[i].seq_stage and a.blocks[i].seq_next == b.blocks[i].seq_next and a.blocks[i].direction == b.blocks[i].direction
	_check(same and text.contains("R>:^") and text.contains("B<:v"), "map -> JSON text -> map keeps both arrows and the stage")
	var m := board(map)
	var snap := m.snapshot()
	m.advance(id_at(m, 1, 0))
	m.restore(snap)
	_check(m.blocks[id_at(m, 1, 0)].seq_stage == 1 and m.blocks[id_at(m, 1, 0)].direction == Direction.RIGHT
		and m.blocks[id_at(m, 0, 1)].direction == Direction.DOWN, "snapshot / restore brings back stage 1, its arrow and the spinner")


# --- Solver -----------------------------------------------------------------------------

func _brute(m: BoardModel, seen: Dictionary) -> bool:
	if m.is_empty():
		return true
	var key := _state_key(m)
	if seen.has(key):
		return seen[key]
	seen[key] = false
	for id in m.blocks.keys():
		var st := m.move_state(id)
		if st != "ok" and st != "ram" and st != "advance":
			continue
		var snap := m.snapshot()
		match st:
			"ok": m.remove(id)
			"ram": m.ram(id)
			"advance": m.advance(id)
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
		parts.append("%d:%d:%d:%d:%d:%d" % [id, b.direction, b.spin_step, 1 if b.armored else 0, 1 if b.hidden else 0, b.seq_stage])
	return " ".join(parts)


static func _apply(m: BoardModel, id: int, ram: bool) -> String:
	var st := m.move_state(id)
	if ram:
		m.ram(id)
	elif st == "advance":
		m.advance(id)
	else:
		m.remove(id)
	return st


func _random_map(rng: RandomNumberGenerator) -> Array:
	var size := Vector2i(rng.randi_range(3, 5), rng.randi_range(3, 5))
	var grid := []
	for r in size.y:
		var row := []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	var n := rng.randi_range(3, mini(8, size.x * size.y - 2))
	var placed := 0
	var seqs := 0
	while placed < n:
		var c := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		if grid[c.y][c.x] != ".":
			continue
		var t: String = ["R", "B", "G", "Y"][rng.randi_range(0, 3)] + ["^", "v", "<", ">"][rng.randi_range(0, 3)]
		var roll := rng.randf()
		if roll < 0.3 or (seqs == 0 and placed == n - 1):
			t += ":" + ["^", "v", "<", ">"][rng.randi_range(0, 3)]
			seqs += 1
		elif roll < 0.55:
			t += ["@", "@-", "@~", "@*"][rng.randi_range(0, 3)]
		elif roll < 0.62:
			t += "?"
		elif roll < 0.68:
			t += "="
		grid[c.y][c.x] = t
		placed += 1
	var map := []
	for row in grid:
		map.append(" ".join(row))
	return map


func _solver_vs_brute_force() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var boards := 0
	var agree := 0
	var solvable := 0
	var replay_ok := 0
	var hint_ok := 0
	var with_advance_turns := 0
	while boards < 300:
		var map := _random_map(rng)
		boards += 1
		var s := Solver.from_model(board(map))
		var moves := s.solve_moves()
		var solver_says := not moves.is_empty() and not s.aborted
		var brute := _brute(board(map), {})
		if solver_says == brute:
			agree += 1
		else:
			print("  disagreement: solver %s brute %s  %s" % [solver_says, brute, str(map)])
		if not solver_says:
			continue
		solvable += 1
		var play := board(map)
		var legal := true
		var turned_any := false
		for mv in moves:
			var id: int = mv & Solver.ID_MASK
			var st := play.move_state(id)
			if mv & Solver.RAM:
				legal = legal and st == "ram"
			else:
				legal = legal and (st == "ok" or st == "advance")
			if st == "advance" and play.turns_spinners(id):
				turned_any = true
			_apply(play, id, (mv & Solver.RAM) != 0)
		if legal and play.is_empty():
			replay_ok += 1
		if turned_any:
			with_advance_turns += 1
		# SHOW A MOVE from every state along the way is legal and keeps it solvable.
		var walk := board(map)
		var ok := true
		for step in 40:
			if walk.is_empty():
				break
			var rec := Solver.from_model(walk).recommend_move()
			if rec == -1 or not walk.is_playable(rec):
				ok = false
				break
			_apply(walk, rec, walk.move_state(rec) == "ram")
		if ok and walk.is_empty():
			hint_ok += 1
	_check(agree == boards, "Solver agrees with brute force on %d / %d random small Sequence boards (%d solvable)" % [agree, boards, solvable])
	_check(replay_ok == solvable, "every Solver solution replays legally with the real rules (%d)" % replay_ok)
	_check(hint_ok == solvable, "SHOW A MOVE, followed to the end, only ever recommends legal moves and clears the board (%d)" % hint_ok)
	_check(with_advance_turns > 10, "the sample exercises advances that turn spinners (%d solutions)" % with_advance_turns)


func _hammer() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var checked := 0
	var agree := 0
	for i in 40:
		var map := _random_map(rng)
		var m := board(map)
		var before := _brute(board(map), {})
		for id in m.blocks.keys():
			var test := board(map)
			test.remove(id)
			var after := test.is_empty() or _brute(test, {})
			checked += 1
			if Solver.hammer_safe(m, id) == (after or not before):
				agree += 1
	_check(agree == checked, "Hammer safety on Sequence boards matches brute force (%d / %d smashes)" % [agree, checked])


# --- Lab data ---------------------------------------------------------------------------

func _lab_data() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/mechlab_sequence.json"))
	_check(typeof(data) == TYPE_DICTIONARY and data.get("mechanic", "") == "sequence", "Sequence lab board file loads")
	if typeof(data) != TYPE_DICTIONARY:
		return
	var ids := {}
	for rec in data["boards"]:
		ids[rec["id"]] = rec
	var ok := true
	var seq_n := 0
	var ctrl_n := 0
	for rec in data["boards"]:
		var level := PuzzleDefinition.from_dict(rec["puzzle"]).to_level()
		var m := BoardModel.new()
		m.setup(level.rows, level.columns, level.blocks)
		var s := Solver.from_model(m)
		var moves := s.solve_moves()
		var advances := 0
		for mv in moves:
			if _apply(m, mv & Solver.ID_MASK, (mv & Solver.RAM) != 0) == "advance":
				advances += 1
		var seqs := level.blocks.filter(func(b): return b.seq_stage == 1).size()
		if moves.is_empty() or s.aborted or not m.is_empty():
			ok = false
			print("  unsolvable " + str(rec["id"]))
		if rec["variant"] == "sequence":
			seq_n += 1
			if seqs == 0 or advances != seqs:
				ok = false
				print("  sequence board without its advances " + str(rec["id"]))
		else:
			ctrl_n += 1
			var main := PuzzleDefinition.from_dict(ids[rec["pair"]]["puzzle"]).to_level()
			if seqs != 0 or level.blocks.size() != main.blocks.size() or level.rows != main.rows or level.columns != main.columns:
				ok = false
				print("  bad control " + str(rec["id"]))
	_check(ok, "every lab board is solvable; Sequence boards advance every Sequence block; controls have none and match their board's size and blocks")
	_check(seq_n >= 10 and seq_n <= 12 and ctrl_n >= 4, "%d Sequence boards, %d matched controls" % [seq_n, ctrl_n])


# --- Play flow ----------------------------------------------------------------------------

func _play_flow() -> void:
	var play := SocialPlay.new()
	add_child(play)
	await _frames(2)
	var map := [".  .    .  .", ".  Y>   .  .", "Bv R<:^ .  .", ".  Gv@  .  .", ".  .    .  ."]
	var def := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 5, "cols": 4, "map": map})
	play.start(SharedChallenge.friend_challenge(def, FriendGenerator.MEDIUM), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	await _frames(2)
	var r := id_at(play.model, 1, 2)
	var g := id_at(play.model, 1, 3)
	_check(play.model.blocks[r].seq_stage == 1 and play.board.get_view(r).data.seq_stage == 1, "SocialPlay loads the Sequence block (rules and view)")
	play.tap_block(r)
	_check(play.total_blocked == 1 and play.total_seq_blocked == 1 and play.model.blocks[r].seq_stage == 1, "blocked stage 1: counted, the stage does not advance")
	play.tap_block(id_at(play.model, 0, 2))
	var g_dir: int = play.model.blocks[g].direction
	play.tap_block(r)
	_check(play.total_seq_advances == 1 and play.total_seq_spinner_turns == 1 and play.model.blocks[r].seq_stage == 2
		and play.model.blocks[g].direction != g_dir and play.seq_events.size() == 1 and play.model.blocks.has(r), "advance: counted with its spinner turn; the block stays")
	_check(play.history.size() == 2, "the advance is an Undo-able move")
	play.undo()
	_check(play.model.blocks[r].seq_stage == 1 and play.model.blocks[r].direction == Direction.LEFT and play.model.blocks[g].direction == g_dir,
		"Undo: back to stage 1, first arrow, spinner turned back")
	await get_tree().create_timer(0.5).timeout
	_check(play.board.get_view(r).data.seq_stage == 1 and play.board.get_view(r).data.direction == Direction.LEFT, "Undo: the view shows stage 1 again")
	play.tap_block(r)
	play.tap_block(r)
	_check(play.total_seq_blocked == 1 and play.total_blocked == 2, "stage 2 blocked (yellow above): a blocked tap, not a blocked first stage")
	play.tap_block(id_at(play.model, 1, 1))
	play.tap_block(r)
	_check(play.total_seq_escapes == 1 and not play.model.blocks.has(r), "stage 2 escape counted")
	play.restart()
	await _frames(1)
	_check(play.model.blocks[id_at(play.model, 1, 2)].seq_stage == 1 and play.model.block_count() == 4, "Restart: stage 1 again, every block back")
	play.hint()
	var hinted := -1
	for id in play.model.blocks:
		if play.board.get_view(id).hinted:
			hinted = id
	_check(hinted != -1 and play.model.is_playable(hinted), "SHOW A MOVE marks a legal move")
	var normal := PuzzleDefinition.from_dict({"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 2, "cols": 2, "map": ["R> .", ". B^"]})
	play.start(SharedChallenge.friend_challenge(normal, FriendGenerator.EASY), SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	await _frames(1)
	_check(play.total_seq_advances == 0 and play.seq_events.is_empty() and play.max_hammers == SocialPlay.MAX_HAMMERS, "a normal board afterwards: counters reset, SocialPlay defaults unchanged")
	play.end()
	play.queue_free()


func _lab_flow() -> void:
	var lab := MechLab.new("sequence")
	add_child(lab)
	await _frames(3)
	var order: Array = lab.state["order"]
	_check(lab.mechanic == "sequence" and lab.total() == lab.boards.size() and lab.total() >= 14, "sequence lab: its own board set (%d boards)" % lab.total())
	_check(lab._intro_text.text.begins_with("SEQUENCE LAB") and not lab._intro_text.text.to_lower().contains("control"), "intro: Sequence wording, never names controls")
	var adjacent := false
	for i in range(1, order.size()):
		if lab.boards[order[i]]["pair"] == lab.boards[order[i - 1]]["pair"]:
			adjacent = true
	_check(not adjacent and lab.boards[order[0]]["stage"] == "A" and lab.boards[order[1]]["stage"] == "A", "basics first; a board and its control never back to back")
	# Demo: about 10 s, plays by itself, ends with WATCH AGAIN / START.
	lab.start_demo()
	await _frames(2)
	_check(lab.screen == MechLab.Screen.DEMO and lab.play.model.blocks.values().any(func(b): return b.seq_stage == 1), "demo: a Sequence board")
	await get_tree().create_timer(10.6).timeout
	var red := -1
	for id in lab.play.model.blocks:
		if lab.play.model.blocks[id].color == "red":
			red = id
	_check(lab._demo_buttons.visible and red == -1 and lab.play.total_seq_advances == 1 and lab.play.total_seq_spinner_turns == 1,
		"demo: advance (spinner turns), spinner leaves, red leaves; buttons shown")
	lab._end_demo()
	lab.start_next()
	await _frames(2)
	var p := lab.play
	_check(p._title.text == "PUZZLE 1 / %d" % lab.total() and p._chip.text == "" and not p._hammer.visible and p._hint.badge_text == "1", "puzzle 1: neutral title, no HAMMER, SHOW A MOVE x1")
	for i in 80:
		if p.completed or not p.play_solver_move():
			break
	await get_tree().create_timer(1.3).timeout
	_check(lab.screen == MechLab.Screen.QUESTION and lab._asks == MechLab.SEQ_ASK["A"], "solved basic board -> rating, clarity")
	lab.answer("EASY")
	_check(lab._q_title.text.contains("Sequence") and lab._q_box.get_child_count() == 4, "clarity: CLEAR / SOMEWHAT CLEAR / CONFUSING (+ SKIP)")
	lab.answer("CLEAR")
	await _frames(2)
	var r0: Dictionary = lab.state["results"][0]
	_check(r0["rating"] == "EASY" and r0["clarity"] == "CLEAR" and r0["seq_advances"] >= 1 and r0.has("seq_first_usable_ms") and r0["advances"].size() >= 1
		and not r0.has("portal_uses"), "result 1: answers and Sequence metrics recorded")
	# Jump to a non-basic Sequence board: the full question set.
	lab.play.end()
	var idx := -1
	for i in order.size():
		if lab.boards[order[i]]["variant"] == "sequence" and lab.boards[order[i]]["stage"] != "A":
			idx = i
			break
	lab.state["index"] = idx
	lab.start_next()
	await _frames(2)
	lab.play._leave()
	await _frames(2)
	_check(lab._asks == MechLab.SEQ_ASK["sequence"], "a Sequence board asks rating, focus, planning, clarity, interest")
	lab.answer("HARD")
	var opts := []
	for c in lab._q_box.get_children():
		opts.append(c.text)
	_check(opts.has("JUST TAPPING THE SEQUENCE TWICE") and opts.has("WHEN TO TRIGGER THE SEQUENCE") and opts.has("WHAT THE SPINNER WOULD BECOME"), "focus options include 'just tapping twice'")
	for i in 4:
		lab.answer("")
	var json = JSON.parse_string(lab.results_json())
	_check(typeof(json) == TYPE_DICTIONARY and json["mechanic"] == "sequence" and json["results"].size() == 2 and json["summary"].has("sequence_A")
		and json["summary"]["sequence_A"].has("seq_advances"), "COPY RESULTS JSON: mechanic, results, summary with Sequence counters")
	_check(FileAccess.file_exists(SEQ_STATE) and not FileAccess.file_exists(PROGRESS_PATH), "own state file only; never the Classic save")
	lab.reset_test()
	lab.play.end()
	lab.queue_free()
	# The PORTAL lab is still the default lab, with its own files.
	var portal := MechLab.new()
	_check(portal.mechanic == "portal" and portal._cfg["data"] == MechLab.DATA_PATH and portal._cfg["state"] == MechLab.STATE_PATH, "MechLab() is still the PORTAL lab")
	portal.free()
