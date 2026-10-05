extends Node
## OPENING EXPERIENCE LAB checks (developer page ?openinglab).
##   godot --headless --path . res://tools/OpeningLabCheck.tscn
##
## - Isolation: without the lab, Levels 1-10 load from res://levels exactly
##   as before; with it, 1-10 come from res://data/dev/opening_lab and 11+
##   are production; the save path / localStorage keys are the lab's own and
##   the defaults are untouched otherwise.
## - Rules: every candidate solvable (Solver), only the intended mechanics
##   (plain 1-5, spinner from 6, hidden from 8, nothing else), small boards.
## - SHOW A MOVE: on every reachable state of every candidate, the
##   recommended move is legal and keeps the board solvable (and is -1 only
##   on boards that are already lost).
## - Hammer: on every reachable state, Solver.hammer_safe agrees with an
##   exhaustive check (a smash never makes a solvable board unsolvable).
## - Game: through the real game scene with the lab active: each level
##   loads, clears by taps, Undo restores the exact board, Restart restores
##   the exact start, SHOW A MOVE marks a legal move, the Hammer refuses an
##   unsafe smash and a safe one keeps the board solvable, hearts start at
##   Level 6, and NEXT after Level 10 opens production Level 11.

const PROGRESS_PATH := "user://opening_lab_check.cfg"

var game: GameManager
var failures: Array[String] = []
var passed := 0


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
	_isolation_static()
	for n in range(1, 11):
		_rules(n)
	# The game scene with the lab active and its own (test) save.
	OpeningLab.apply("1")
	PlayerProgress.default_path = PROGRESS_PATH
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	for n in range(1, 11):
		await _in_game(n)
	await _flow()
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("OPENING LAB CHECKS PASSED" if failures.is_empty() else "OPENING LAB CHECKS FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


static func lab_level(n: int) -> LevelData:
	var json = JSON.parse_string(FileAccess.get_file_as_string(OpeningLab.LEVEL_DIR.path_join("level_%02d.json" % n)))
	return LevelManager.parse_level(json, n, true)


static func model_of(level: LevelData) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals(level.portals)
	return m


# --- Isolation --------------------------------------------------------------------

func _isolation_static() -> void:
	_check(not OpeningLab.active and LevelManager.override_dir == "", "lab is off unless asked for")
	_check(PlayerProgress.default_path == "user://progress.cfg" and PlayerProgress.mirror_key == "chain_escape_save" and PlayerProgress.beacon_key == "chain_escape_beacon",
		"production save path and Web keys unchanged by default")
	var lm := LevelManager.new()
	lm._ready()
	_check(lm.level_count == 300, "300 production levels (%d)" % lm.level_count)
	for n in range(1, 12):
		var prod := FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n)
		var a := lm.load_level(n)
		var b := LevelManager.parse_level(JSON.parse_string(prod), n, true)
		_check(a != null and LevelManager.to_json_text(a) == LevelManager.to_json_text(b), "without the lab, Level %d is production" % n)
	LevelManager.override_dir = OpeningLab.LEVEL_DIR
	LevelManager.override_last = OpeningLab.LAST_LAB_LEVEL
	for n in range(1, 12):
		var got := LevelManager.to_json_text(lm.load_level(n))
		var want := LevelManager.to_json_text(lab_level(n) if n <= 10 else LevelManager.read_level(n))
		_check(got == want, "with the lab, Level %d is %s" % [n, "the lab candidate" if n <= 10 else "production"])
	LevelManager.override_dir = ""
	LevelManager.override_last = 0
	lm.free()


# --- Rules / solver / hint / hammer --------------------------------------------

func _rules(n: int) -> void:
	var lv := lab_level(n)
	var m := model_of(lv)
	var s := Solver.from_model(m)
	var sol := s.solve()
	_check(not sol.is_empty(), "L%d solvable" % n)
	_check(lv.rows <= 5 and lv.columns <= 5 and lv.blocks.size() <= 10, "L%d small board (%dx%d, %d blocks)" % [n, lv.columns, lv.rows, lv.blocks.size()])
	var spin := lv.blocks.filter(func(b): return b.is_spinner()).size()
	var hid := lv.blocks.filter(func(b): return b.hidden).size()
	var other := lv.blocks.filter(func(b): return b.lock_color != "" or b.is_switch() or b.is_gate() or b.armored or b.is_crate() or b.seq_stage != 0 or b.flip_link != "")
	_check(other.is_empty() and lv.portals.is_empty(), "L%d uses only arrows / spinners / hidden" % n)
	_check((spin == 0 or n >= 6) and (hid == 0 or n >= 8), "L%d: spinner only from 6, hidden only from 8" % n)
	_check((n != 6 or spin > 0) and (n != 8 or hid > 0), "L%d introduces its mechanic" % n)
	# Every reachable state: hint legal + solvable-preserving; hammer_safe exact.
	var seen := {}
	var stats := {"states": 0, "hint_bad": 0, "hammer_bad": 0, "lost_hint": 0}
	_walk(m, seen, stats)
	_check(stats["hint_bad"] == 0, "L%d SHOW A MOVE legal and solvable on all %d states" % [n, stats["states"]])
	_check(stats["hammer_bad"] == 0, "L%d Hammer safety exact on all states" % n)
	print("L%d %-16s %dx%d blocks=%d spinners=%d hidden=%d solution=%d states=%d" % [n, lv.name, lv.columns, lv.rows, lv.blocks.size(), spin, hid, sol.size(), stats["states"]])


static func _key(m: BoardModel) -> String:
	var ids := m.blocks.keys()
	ids.sort()
	var parts := PackedStringArray()
	for id in ids:
		var b: BlockData = m.blocks[id]
		parts.append("%d.%d.%d" % [id, b.direction, int(b.hidden)])
	return ",".join(parts)


func _walk(m: BoardModel, seen: Dictionary, stats: Dictionary) -> void:
	var k := _key(m)
	if seen.has(k) or m.is_empty():
		return
	seen[k] = true
	stats["states"] += 1
	var solvable := Solver.from_model(m).is_solvable()
	var rec := Solver.from_model(m).recommend_move()
	if solvable:
		if rec == -1 or not m.is_playable(rec):
			stats["hint_bad"] += 1
		else:
			var snap := m.snapshot()
			m.remove(rec)
			if not m.is_empty() and not Solver.from_model(m).is_solvable():
				stats["hint_bad"] += 1
			m.restore(snap)
	elif rec != -1:
		stats["hint_bad"] += 1
	# Hammer: hammer_safe(id) must be true exactly when smashing keeps a
	# solvable board solvable (on a lost board every smash is allowed).
	for id in m.blocks.keys():
		var safe := Solver.hammer_safe(m, id)
		var snap2 := m.snapshot()
		m.remove(id)
		var after := m.is_empty() or Solver.from_model(m).is_solvable()
		m.restore(snap2)
		if solvable and safe != after:
			stats["hammer_bad"] += 1
	var snap3 := m.snapshot()
	for id in m.playable_ids():
		m.remove(id)
		_walk(m, seen, stats)
		m.restore(snap3)


# --- In the real game -------------------------------------------------------------

func _snapshot() -> Array:
	var out := []
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = game.model.blocks[id]
		out.append([id, b.cell, b.direction, b.hidden, b.spin_step])
	return out


func _in_game(n: int) -> void:
	game.start_level(n, "test")
	await _frames(3)
	var lv := lab_level(n)
	_check(game.level.name == lv.name and LevelManager.to_json_text(game.level) == LevelManager.to_json_text(lv), "game L%d loads the lab candidate" % n)
	_check(game.max_hearts == (3 if n >= 6 else 0), "L%d hearts %d (from Level 6)" % [n, game.max_hearts])
	var start := _snapshot()
	# SHOW A MOVE marks a legal move (debug unlimited hints are off here).
	game.progress.inventory["hint"] = 5
	game.request_hint()
	_check(game.hint_block != -1 and game.model.is_playable(game.hint_block), "L%d SHOW A MOVE marks a legal move" % n)
	# Undo: two moves, two undos -> the exact start.
	var sol := Solver.from_model(game.model).solve()
	for i in mini(2, sol.size() - 1):
		game._on_block_tapped(sol[i])
		await _frames(2)
	game.undos_used = 0
	for i in mini(2, sol.size() - 1):
		game.undo()
		await _frames(2)
	_check(_snapshot() == start, "L%d Undo restores the exact board" % n)
	# Restart: a few moves then Restart -> the exact start.
	for i in mini(3, sol.size() - 1):
		game._on_block_tapped(sol[i])
		await _frames(2)
	game.restart()
	await _frames(3)
	_check(_snapshot() == start, "L%d Restart restores the exact start" % n)
	# Hammer: every block at the start, refused exactly when unsafe.
	game.progress.inventory["hammer"] = 99
	var ok := true
	for id in start.map(func(e): return e[0]):
		game.restart()
		await _frames(2)
		var safe := game.is_hammer_safe(id)
		game.toggle_hammer()
		game._on_block_tapped(id)
		await _frames(2)
		var smashed := not game.model.blocks.has(id)
		if game.hammer_armed:
			game.toggle_hammer()
		if smashed != safe or (smashed and not game.model.is_empty() and not Solver.from_model(game.model).is_solvable()):
			ok = false
	_check(ok, "L%d Hammer: refused when unsafe, safe smashes keep it solvable" % n)
	# Clear it by taps along a solution.
	game.restart()
	await _frames(3)
	sol = Solver.from_model(game.model).solve()
	for id in sol:
		game._on_block_tapped(id)
		await _frames(2)
	await get_tree().create_timer(2.2).timeout
	_check(game.completed and game.last_result.get("level", 0) == n and game.last_result.get("stars", 0) == 3, "L%d clears by taps with 3 stars" % n)


func _flow() -> void:
	# NEXT after Level 10 opens production Level 11.
	game.next_level()
	await _frames(3)
	if game.ui.is_chapter_card_open():
		game._after_chapter_card()
		await _frames(3)
	_check(game.current_level == 11 and LevelManager.to_json_text(game.level) == LevelManager.to_json_text(LevelManager.read_level(11)), "NEXT after lab Level 10 opens production Level 11")
	_check(OpeningLab.log_entries().any(func(e): return e.get("kind") == "next" and int(e.get("level")) == 10), "the lab log records NEXT")
	_check(OpeningLab.summary().begins_with("OPENING LAB"), "the lab summary is available")
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OpeningLab.LOG_PATH))
