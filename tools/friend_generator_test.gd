extends SceneTree
## Challenge a Friend, phase 1: the generated-puzzle engine.
##   godot --headless --path . --script res://tools/friend_generator_test.gd
## Profiles and bands, Solver validation of every result (rebuilt from its
## JSON), allowed mechanics per difficulty, determinism, NEW CHALLENGE
## never repeating, SURPRISE ME, the work / time budget, and that no result
## is one of the campaign's 200 boards.

const SEEDS := 12

var failures: Array[String] = []
var passed := 0


func _init() -> void:
	_test_specs()
	_test_classic_keys()
	_test_generation()
	_test_new_challenge()
	_test_surprise()
	_test_budget()
	print("FRIEND GENERATOR TEST: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	quit(0 if failures.is_empty() else 1)


func _test_specs() -> void:
	var ds := FriendGenerator.DIFFICULTIES
	_check(ds == ["easy", "medium", "hard", "very_hard"], "four real difficulties, in order")
	_check(not FriendGenerator.SPECS.has(FriendGenerator.SURPRISE), "SURPRISE ME is not a profile")
	for i in ds.size() - 1:
		var a: Dictionary = FriendGenerator.SPECS[ds[i]]
		var b: Dictionary = FriendGenerator.SPECS[ds[i + 1]]
		_check(a["band"].y < b["band"].x, "%s band ends below %s band" % [ds[i], ds[i + 1]])
		_check(a["accept"].y < b["band"].x and a["accept"].y < b["accept"].x,
			"%s fallback can never reach %s" % [ds[i], ds[i + 1]])
	var h: Dictionary = FriendGenerator.SPECS["hard"]
	var v: Dictionary = FriendGenerator.SPECS["very_hard"]
	_check(v["band"].x - h["band"].y >= 5.0, "HARD and VERY HARD bands are at least 5 points apart")
	for d in ds:
		var p := FriendGenerator.profile_for(d)
		_check(p["locks"] == Vector2i.ZERO and p["hidden"] == Vector2i.ZERO and p["spin_rules"].is_empty()
			and p["switches"] == Vector2i.ZERO and p["gates"] == Vector2i.ZERO and p["armored"] == Vector2i.ZERO,
			"%s profile: no locks / hidden / spinner rules / switches / gates / armor" % d)
		for s in p["sizes"]:
			_check(s.x <= 6 and s.y <= 7, "%s: boards at most 6x7 (no slow 7x7)" % d)
	_check(FriendGenerator.profile_for("easy")["spinners"] == Vector2i.ZERO, "EASY: no spinners")
	_check(FriendGenerator.new("impossible", 1).error == "difficulty", "unknown difficulty refused")


## The precomputed campaign keys match the level files, and every campaign
## board is recognised.
func _test_classic_keys() -> void:
	var live: Array = load("res://tools/classic_board_keys.gd").compute()
	var data = JSON.parse_string(FileAccess.get_file_as_string(FriendGenerator.CLASSIC_KEYS_PATH))
	_check(live.size() == 200, "200 campaign levels read")
	_check(typeof(data) == TYPE_DICTIONARY and data["keys"] == live, "data/classic_board_keys.json is up to date")
	var all := true
	for n in range(1, 201):
		var json = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n))
		all = all and FriendGenerator.is_classic_board(PuzzleDefinition.from_level(LevelManager.parse_level(json, n)))
	_check(all, "all 200 campaign boards recognised as campaign boards")


func _test_generation() -> void:
	for d in FriendGenerator.DIFFICULTIES:
		var spec: Dictionary = FriendGenerator.SPECS[d]
		var p := FriendGenerator.profile_for(d)
		var keys := {}
		for i in SEEDS:
			var seed_value := 5000 + i * 7919
			var g := FriendGenerator.new(d, seed_value, [], 0)  # no wall-clock cap: deterministic
			var def := g.run()
			_check(def != null, "%s #%d generated (%s)" % [d, i, g.error])
			if def == null:
				continue
			var rebuilt := PuzzleDefinition.from_json(def.to_json())
			_check(rebuilt != null and rebuilt.verify(), "%s #%d: Solver-valid when rebuilt from its JSON" % [d, i])
			_check(FriendGenerator.mechanics_ok(def, d), "%s #%d: only allowed mechanics" % [d, i])
			_check(not FriendGenerator.is_classic_board(def), "%s #%d: not a campaign board" % [d, i])
			var m: Dictionary = g.metrics
			_check(m["in_accept"], "%s #%d: difficulty %.1f acceptable" % [d, i, m["difficulty"]])
			_check(g.evals <= int(spec["max_evals"]), "%s #%d: within the work budget" % [d, i])
			var sizes: Array = p["sizes"]
			_check(sizes.has(Vector2i(def.columns, def.rows)), "%s #%d: board size %dx%d" % [d, i, def.columns, def.rows])
			_check(def.block_count() >= p["blocks"].x - 1 and def.block_count() <= p["blocks"].y, "%s #%d: block count" % [d, i])
			keys[FriendGenerator.board_key(def)] = true
			if i < 3:
				var again := FriendGenerator.new(d, seed_value, [], 0).run()
				_check(again != null and again.fingerprint() == def.fingerprint(), "%s #%d: same seed, same puzzle" % [d, i])
		_check(keys.size() == SEEDS, "%s: %d seeds, %d different boards" % [d, SEEDS, keys.size()])


## NEW CHALLENGE: a new seed and the previous board in `avoid`.
func _test_new_challenge() -> void:
	for d in FriendGenerator.DIFFICULTIES:
		var prev := FriendGenerator.new(d, 42, [], 0).run()
		# Even with the SAME seed, the avoided board can never come back.
		var same_seed := FriendGenerator.new(d, 42, [FriendGenerator.board_key(prev)], 0).run()
		_check(same_seed != null and FriendGenerator.board_key(same_seed) != FriendGenerator.board_key(prev),
			"%s: an avoided board is never returned (same seed)" % d)
		var chain_ok := true
		var seen := [FriendGenerator.board_key(prev)]
		for i in 6:
			var nxt := FriendGenerator.new(d, 100 + i, [seen[-1]], 0).run()
			chain_ok = chain_ok and nxt != null and FriendGenerator.board_key(nxt) != seen[-1]
			if nxt:
				seen.append(FriendGenerator.board_key(nxt))
		_check(chain_ok, "%s: 6 NEW CHALLENGEs in a row, each different from the one before" % d)


func _test_surprise() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var counts := {}
	var valid := true
	for i in 400:
		var d := FriendGenerator.resolve(FriendGenerator.SURPRISE, rng)
		valid = valid and d in FriendGenerator.DIFFICULTIES
		counts[d] = counts.get(d, 0) + 1
	_check(valid, "SURPRISE ME only picks one of the four real difficulties")
	_check(counts.size() == 4 and counts.values().min() > 60, "SURPRISE ME reaches all four (%s)" % str(counts))
	_check(FriendGenerator.resolve("hard", rng) == "hard", "a real difficulty passes through unchanged")
	var g := FriendGenerator.new(FriendGenerator.resolve(FriendGenerator.SURPRISE, rng), 7, [], 0)
	_check(g.difficulty in FriendGenerator.DIFFICULTIES and g.run() != null, "a SURPRISE ME challenge stores a real difficulty")


## The bounds: a tiny time cap still returns a validated board at once, and
## the work cap holds.
func _test_budget() -> void:
	for d in FriendGenerator.DIFFICULTIES:
		var t0 := Time.get_ticks_msec()
		var g := FriendGenerator.new(d, 31337, [], 1)  # 1 ms wall-clock cap
		var def := g.run()
		var ms := Time.get_ticks_msec() - t0
		_check(def == null or (def.verify() and FriendGenerator.mechanics_ok(def, d)),
			"%s: a capped search returns only a validated board" % d)
		_check(ms < FriendGenerator.GRACE_MS + 1500, "%s: a 1 ms cap ends quickly (%d ms: cap + grace + one candidate)" % [d, ms])
		_check(def == null or not g.metrics.is_empty(), "%s: capped result carries its metrics" % d)
	# Stepping in slices: never runs past the end, finishes.
	var g2 := FriendGenerator.new("very_hard", 77)
	var steps := 0
	while not g2.step() and steps < 100000:
		steps += 1
	_check(g2.done and g2.puzzle != null, "step() slices finish with a puzzle (%d steps)" % steps)
	_check(g2.metrics["ms"] <= int(FriendGenerator.SPECS["very_hard"]["time_cap_ms"]) + FriendGenerator.GRACE_MS + 1500,
		"VERY HARD stays within its time cap (+ grace + one candidate): %d ms" % g2.metrics["ms"])


func _check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(msg)
