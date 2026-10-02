extends SceneTree
## LOCK PROTOTYPE (audit only, never production): compares
##   A  current HARD                (FriendGenerator.SPECS)
##   B  current VERY HARD           (FriendGenerator.SPECS)
##   C  prototype VERY HARD + Locks (the Classic colour lock "R>#G"; arrows +
##      clockwise spinners + locks only; spec below, via spec_override)
## with the product time caps, re-measuring every result independently.
##   godot --headless --path . --script res://tools/lock_prototype_bench.gd -- --n=60 [--only=A|B|C] [--proto=<name>]
## Nothing here is used by the game; production Friend validation (client,
## mock, Edge Function v4) still refuses locks.

## Prototype specs (C). "proto" = the recommended one; others for comparison.
const PROTOS := {
	"x_nolock": {
		"profile": "expert", "band": Vector2(28, 999), "accept": Vector2(24, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(5, 6)},
		"human": {"max_start": 3, "min_one_safe": 4, "max_safe_choices": 1.9, "min_decisions": 8,
			"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
			"max_smart": 0.15, "smart_games": 30, "smart_depth": 2},
		"sample": 3, "stale": 60, "max_evals": 20000, "time_cap_ms": 8000},
	"x_locks": {
		"profile": "expert", "allow_locks": true, "band": Vector2(28, 999), "accept": Vector2(24, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(4, 5), "locks": Vector2i(1, 3)},
		"human": {"max_start": 3, "min_one_safe": 4, "max_safe_choices": 1.9, "min_decisions": 8,
			"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
			"min_locks": 1, "max_smart": 0.15, "smart_games": 30, "smart_depth": 2},
		"sample": 3, "stale": 60, "max_evals": 20000, "time_cap_ms": 8000},
	"x_nolock_fast": {
		"profile": "expert", "band": Vector2(28, 999), "accept": Vector2(24, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(5, 6)},
		"human": {"max_start": 3, "min_one_safe": 4, "max_safe_choices": 1.9, "min_decisions": 8,
			"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
			"max_smart": 0.15, "smart_games": 30, "smart_depth": 2},
		"sample": 3, "stale": 60, "max_evals": 4000, "time_cap_ms": 1500},
	"x_locks_fast": {
		"profile": "expert", "allow_locks": true, "band": Vector2(28, 999), "accept": Vector2(24, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(4, 5), "locks": Vector2i(1, 3)},
		"human": {"max_start": 3, "min_one_safe": 4, "max_safe_choices": 1.9, "min_decisions": 8,
			"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
			"min_locks": 1, "max_smart": 0.15, "smart_games": 30, "smart_depth": 2},
		"sample": 3, "stale": 60, "max_evals": 4000, "time_cap_ms": 1500},
	"proto": {
		"profile": "expert", "allow_locks": true, "band": Vector2(28, 999), "accept": Vector2(24, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(4, 5), "locks": Vector2i(2, 3)},
		"human": {"max_start": 3, "min_one_safe": 4, "max_safe_choices": 1.9, "min_decisions": 8,
			"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
			"min_locks": 2, "min_locked_free_steps": 4, "min_unlock_step": 6.0},
		"sample": 3, "stale": 60, "max_evals": 4000, "time_cap_ms": 1500},
	"proto_1lock": {
		"profile": "expert", "allow_locks": true, "band": Vector2(28, 999), "accept": Vector2(24, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(4, 5), "locks": Vector2i(1, 1)},
		"human": {"max_start": 3, "min_one_safe": 4, "max_safe_choices": 1.9, "min_decisions": 8,
			"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
			"min_locks": 1, "min_locked_free_steps": 3, "min_unlock_step": 6.0},
		"sample": 3, "stale": 60, "max_evals": 4000, "time_cap_ms": 1500},
	"proto_4locks": {
		"profile": "expert", "allow_locks": true, "band": Vector2(28, 999), "accept": Vector2(24, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(4, 5), "locks": Vector2i(3, 4)},
		"human": {"max_start": 3, "min_one_safe": 4, "max_safe_choices": 1.9, "min_decisions": 8,
			"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
			"min_locks": 3, "min_locked_free_steps": 5, "min_unlock_step": 6.0},
		"sample": 3, "stale": 60, "max_evals": 4000, "time_cap_ms": 1500},
}


func _init() -> void:
	var n := 60
	var only := ""
	var proto := "proto"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="): n = int(a.get_slice("=", 1))
		if a.begins_with("--only="): only = a.get_slice("=", 1)
		if a.begins_with("--proto="): proto = a.get_slice("=", 1)
	print("group  n  met  accept  fail  ms_p50 ms_p90 ms_max | size blocks spinners locks | start depth chain one_safe safe_ch decisions | random look2 look3 smart2 smart3 | lock_free_steps lock_wait unlock_step | hammer: locked_smashable look2_after_smashing_locks look2_after_2_random_smashes")
	if only == "" or only == "A":
		_group("A HARD", FriendGenerator.HARD, {}, n)
	if only == "" or only == "B":
		_group("B VERY_HARD", FriendGenerator.VERY_HARD, {}, n)
	if only == "" or only == "C":
		var spec: Dictionary = PROTOS[proto].duplicate(true)
		spec["replace"] = true
		_group("C %s" % proto, FriendGenerator.VERY_HARD, spec, n)
	quit()


func _group(name: String, d: String, override: Dictionary, n: int) -> void:
	FriendGenerator.spec_override = {} if override.is_empty() else {d: override}
	var allow_locks: bool = override.get("allow_locks", false)
	var ms := []
	var rows := []
	var met := 0
	var accept := 0
	var failed := 0
	for i in n:
		var g := FriendGenerator.new(d, 31000 + i * 7919, [], -1)
		var def := g.run()
		if def == null or not def.verify() or not FriendGenerator.mechanics_ok(def, d, allow_locks) or FriendGenerator.is_classic_board(def):
			failed += 1
			continue
		# Exact-board safety: rebuilt from its JSON, same fingerprint, verified.
		var rebuilt := PuzzleDefinition.from_json(def.to_json())
		if rebuilt == null or rebuilt.fingerprint() != def.fingerprint() or not rebuilt.verify():
			failed += 1
			continue
		ms.append(g.metrics["ms"])
		met += 1 if g.metrics["in_band"] else 0
		accept += 1 if g.metrics["in_accept"] else 0
		rows.append(_measure(rebuilt, i))
	FriendGenerator.spec_override = {}
	ms.sort()
	var q := func(a: Array, f: float): return a[mini(int(f * a.size()), a.size() - 1)] if not a.is_empty() else 0
	var avg := func(k: String) -> float: return rows.reduce(func(acc, x): return acc + float(x[k]), 0.0) / maxf(rows.size(), 1)
	print("%-14s %3d %4d%% %5d%% %4d %6d %6d %6d | %s %5.1f %4.1f %4.1f | %4.1f %4.1f %4.1f %5.1f %5.2f %5.1f | %4.1f%% %4.1f%% %4.1f%% %4.1f%% %4.1f%% | %5.1f %5.1f %5.1f | %4.1f %4.1f%% %4.1f%%" % [
		name, n, 100 * met / n, 100 * accept / n, failed, q.call(ms, 0.5), q.call(ms, 0.9), ms[-1] if not ms.is_empty() else 0,
		"6x6", avg.call("blocks"), avg.call("spinners"), avg.call("locks"),
		avg.call("start_moves"), avg.call("depth"), avg.call("chain"), avg.call("one_safe_steps"), avg.call("safe_choices"), avg.call("decision_points"),
		100 * avg.call("random"), 100 * avg.call("look2"), 100 * avg.call("look3"), 100 * avg.call("smart2"), 100 * avg.call("smart3"),
		avg.call("locked_free_steps"), avg.call("lock_wait"), avg.call("unlock_step"),
		avg.call("smashable_locked"), 100 * avg.call("look2_lock_smash"), 100 * avg.call("look2_any_smash")])


func _measure(def: PuzzleDefinition, i: int) -> Dictionary:
	var lv := def.to_level()
	var model := BoardModel.new()
	model.setup(lv.rows, lv.columns, lv.blocks)
	var s := Solver.from_model(model)
	var m := s.analyze()
	m["random"] = s.random_win_rate(300, 777 + i)
	m["look2"] = s.lookahead_win_rate(100, 2, 555 + i)
	m["look3"] = s.lookahead_win_rate(60, 3, 333 + i)
	m["smart2"] = s.heuristic_win_rate(100, 2, 222 + i)
	m["smart3"] = s.heuristic_win_rate(60, 3, 111 + i)
	m["chain"] = _chain(model)
	# HAMMER audit: how many locked blocks the CURRENT Social Hammer rule
	# (Solver.hammer_safe) would let a player smash at the start, and how a
	# 2-move-lookahead player does after smashing them (up to 2: the free
	# Hammers), versus after 2 smashes of random safe blocks.
	var locked := []
	for id in model.blocks:
		if model.is_locked(id):
			locked.append(id)
	var smashable := locked.filter(func(id): return Solver.hammer_safe(model, id))
	m["smashable_locked"] = smashable.size()
	m["look2_lock_smash"] = _after_smashes(model, smashable.slice(0, 2), 900 + i) if not smashable.is_empty() else m["look2"]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4040 + i
	var any := []
	var probe := BoardModel.new()
	probe.setup(model.rows, model.columns, model.snapshot())
	for k in 2:
		var ids := probe.blocks.keys().filter(func(id): return Solver.hammer_safe(probe, id))
		if ids.is_empty():
			break
		var id: int = ids[rng.randi() % ids.size()]
		any.append(id)
		probe.remove(id)
	m["look2_any_smash"] = _after_smashes(model, any, 700 + i)
	return m


func _after_smashes(model: BoardModel, ids: Array, seed_value: int) -> float:
	var copy := BoardModel.new()
	copy.setup(model.rows, model.columns, model.snapshot())
	for id in ids:
		if copy.blocks.has(id) and Solver.hammer_safe(copy, id):
			copy.remove(id)
	return Solver.from_model(copy).lookahead_win_rate(100, 2, seed_value)


## Longest "must leave first" chain at the start: a block depends on every
## block in its lane and, when locked, on every block of its key colour.
## (Static: spinner turns later in the game are ignored.)
func _chain(model: BoardModel) -> int:
	var memo := {}
	var best := 0
	for id in model.blocks:
		best = maxi(best, _depth(model, id, memo, {}))
	return best


func _depth(model: BoardModel, id: int, memo: Dictionary, path: Dictionary) -> int:
	if memo.has(id):
		return memo[id]
	if path.has(id):
		return 0  # cycle (only through spinner lanes): ignore
	path[id] = true
	var b: BlockData = model.blocks[id]
	var deps := []
	var cell: Vector2i = b.cell + Direction.step(b.direction)
	while cell.x >= 0 and cell.y >= 0 and cell.x < model.columns and cell.y < model.rows:
		var o := model.block_at(cell)
		if o != null:
			deps.append(o.id)
		cell += Direction.step(b.direction)
	if b.lock_color != "":
		deps.append_array(model.key_blocks(id))
	var d := 1
	for x in deps:
		d = maxi(d, 1 + _depth(model, x, memo, path))
	path.erase(id)
	memo[id] = d
	return d
