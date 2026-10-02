extends Node
## LOCK PROTOTYPE (audit only, never production): safety checks on
## generated VERY HARD + Locks boards, played through the real SocialPlay.
##   godot --headless --path . res://tools/LockPrototypeCheck.tscn
## Determinism, exact JSON round trip, production validation still refusing
## locks, SHOW A MOVE never pointing at a locked block, a locked tap changing
## nothing, UNDO / RESTART restoring locks, the stored PuzzleDefinition
## staying immutable, and what the CURRENT Social Hammer does to locks.

const BOARDS := 6

var failures: Array[String] = []
var passed := 0
var notes := {"hammer_locked_allowed": 0, "hammer_locked_refused": 0, "locked_boards": 0, "hint_steps": 0}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var spec: Dictionary = load("res://tools/lock_prototype_bench.gd").PROTOS["proto"].duplicate(true)
	spec["replace"] = true
	FriendGenerator.spec_override = {FriendGenerator.VERY_HARD: spec}
	var play := SocialPlay.new()
	get_tree().root.add_child(play)
	await get_tree().process_frame
	var theme := Chapters.theme_for_chapter(1)
	for i in BOARDS:
		var seed_value := 61000 + i * 7919
		var def := FriendGenerator.new(FriendGenerator.VERY_HARD, seed_value, [], 0).run()
		if def == null:
			_check(false, "board %d generated" % i)
			continue
		var again := FriendGenerator.new(FriendGenerator.VERY_HARD, seed_value, [], 0).run()
		_check(again != null and again.fingerprint() == def.fingerprint(), "board %d: same seed, same board (deterministic)" % i)
		var rebuilt := PuzzleDefinition.from_json(def.to_json())
		_check(rebuilt != null and rebuilt.fingerprint() == def.fingerprint() and rebuilt.verify() and rebuilt.to_json() == def.to_json(),
			"board %d: exact JSON round trip, Solver-verified" % i)
		var has_lock := def.to_json().contains("#")
		notes["locked_boards"] += 1 if has_lock else 0
		_check(FriendGenerator.mechanics_ok(def, FriendGenerator.VERY_HARD, true), "board %d: only arrows / clockwise spinners / locks" % i)
		if has_lock:
			_check(not FriendGenerator.mechanics_ok(def, FriendGenerator.VERY_HARD), "board %d: production Friend validation still refuses locks" % i)
			var api := SharedChallenge.from_api({"challenge": {"id": "x", "challenge_type": "friend_challenge", "difficulty": "very_hard",
				"puzzle": def.to_dict(), "payload": {}, "expires_at": "2099-01-01T00:00:00Z"}})
			_check(api.has("error"), "board %d: today's client refuses a lock board from the API (%s)" % [i, str(api.get("error", "accepted!"))])
		await _play(play, def, theme, i)
	FriendGenerator.spec_override = {}
	print("[LockPrototypeCheck] %s" % str(notes))
	print("LOCK PROTOTYPE CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func _play(play: SocialPlay, def: PuzzleDefinition, theme: Dictionary, i: int) -> void:
	var c := SharedChallenge.friend_challenge(def, FriendGenerator.VERY_HARD)
	var fp := def.fingerprint()
	play.start(c, SocialPlay.Mode.CREATOR_PREVIEW, theme)
	await get_tree().process_frame
	# A locked tap: nothing moves, nothing is spent.
	var locked := play.model.blocks.keys().filter(func(id): return play.model.is_locked(id))
	if not locked.is_empty():
		var before := var_to_str(play.model.snapshot())
		play.tap_block(locked[0])
		_check(var_to_str(play.model.snapshot()) == before and play.history.size() == 0, "board %d: tapping a locked block changes nothing" % i)
	# CURRENT Social Hammer on a locked block (audit, not a rule change).
	for id in locked:
		if Solver.hammer_safe(play.model, id):
			notes["hammer_locked_allowed"] += 1
		else:
			notes["hammer_locked_refused"] += 1
	# SHOW A MOVE at every step of a full solve: always a legal, unlocked move.
	var bad_hints := 0
	var unlock_seen := false
	var guard := 0
	while not play.completed and guard < 80:
		guard += 1
		play.hints_used = 0
		var was_locked := play.model.blocks.keys().filter(func(id): return play.model.is_locked(id))
		play.hint()
		var hinted := -1
		for id in play.model.blocks:
			if play.board.get_view(id).hinted:
				hinted = id
		notes["hint_steps"] += 1
		if hinted == -1 or play.model.move_state(hinted) != "ok" or play.model.is_locked(hinted):
			bad_hints += 1
		play.tap_block(hinted if hinted != -1 else -1)
		await get_tree().process_frame
		var now_locked := play.model.blocks.keys().filter(func(id): return play.model.is_locked(id))
		if not unlock_seen and now_locked.size() < was_locked.filter(func(id): return play.model.blocks.has(id)).size():
			# UNDO right after a lock opened: the lock is back exactly.
			unlock_seen = true
			var after := var_to_str(play.model.snapshot())
			play.undo()
			var relocked := play.model.blocks.keys().filter(func(id): return play.model.is_locked(id))
			_check(relocked.size() == was_locked.size(), "board %d: UNDO after an unlock restores the lock" % i)
			play.undos_used = 0
			play.tap_block(hinted)
			await get_tree().process_frame
			_check(var_to_str(play.model.snapshot()) == after, "board %d: redoing the move opens it again identically" % i)
	_check(bad_hints == 0, "board %d: SHOW A MOVE never pointed at a locked / illegal block (%d bad)" % [i, bad_hints])
	_check(play.completed, "board %d: solved by following SHOW A MOVE" % i)
	_check(not locked.is_empty() == unlock_seen or locked.is_empty(), "board %d: a lock opened during the solve" % i)
	# RESTART: the exact board, locks back.
	play.restart()
	await get_tree().process_frame
	var relocked := play.model.blocks.keys().filter(func(id): return play.model.is_locked(id))
	_check(play.loaded_fingerprint == fp and relocked.size() == locked.size() and c.puzzle.fingerprint() == fp,
		"board %d: RESTART rebuilds the exact board with its locks; stored puzzle unchanged" % i)
	play.end()
	await get_tree().process_frame


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(msg)
