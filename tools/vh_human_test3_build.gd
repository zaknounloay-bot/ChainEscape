extends SceneTree
## VERY HARD blind human test 3 (development only, ?vhtest3=1): builds
## data/dev/vh_human_test3.json.
##   godot --headless --path . --script res://tools/vh_human_test3_build.gd [-- --candidates=16]
## Controlled variable: CLOCKWISE + COUNTER-CLOCKWISE spinners (the Classic
## "@-" rule; not a new mechanic). Both groups play with HAMMER x0.
##   C  CONTROL: the 4 arrows + clockwise boards that were HARDEST FOR PEOPLE
##      in test 2 (most restarts / highest ratings across the 3 testers):
##      P13 (late-Classic L165 geometry), P09 (L169 geometry), P10 (Friend
##      T04), P02 (Classic L44). Rotated 90 degrees (never seen that way).
##   X  EXPERIMENTAL: new arrows + clockwise + counter-clockwise boards
##      (offline FriendGenerator search, same human criteria as test-1 B),
##      kept only if spinner DIRECTION MATTERS: >= 2 counter-clockwise and
##      >= 2 clockwise spinners, and at >= 2 solution steps a player who
##      assumes every spinner turns clockwise would misjudge whether a move
##      is safe ("misread steps"). The candidates with the most misread
##      steps and the most delayed traps are kept.
## Extra measures for every board:
##   misread_steps   steps where "all spinners turn clockwise" gives a
##                   wrong safe / trap judgement for at least one legal move
##   cw_solvable     the same board with every spinner clockwise is solvable
##   trap_delay      after a wrong (trap) move, how many more moves random
##                   play can still make before getting stuck (average over
##                   every trap along the solution): how LATE a mistake shows
##   trap_delay_max  the longest of those
## Nothing here is production.

const OUT := "res://data/dev/vh_human_test3.json"
const CONTROL_IDS := ["P13", "P09", "P10", "P02"]
const X_COUNT := 7
const X_SPEC := {
	"profile": "expert", "allow_ccw": true, "band": Vector2(28, 999), "accept": Vector2(24, 999), "max_evals": 100000,
	"time_cap_ms": 30000, "sample": 3, "stale": 60, "replace": true,
	"overrides": {"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(18, 21), "spinners": Vector2i(5, 7),
		"spin_rules": {"ccw": Vector2i(2, 3)}},
	"human": {"max_start": 3, "min_one_safe": 5, "max_safe_choices": 1.9, "min_decisions": 8,
		"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0,
		"max_smart": 0.12, "smart_games": 30, "smart_depth": 2},
}


func _init() -> void:
	var n_cand := 16
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--candidates="):
			n_cand = int(a.get_slice("=", 1))
	var audit = load("res://tools/classic_topology_audit.gd")
	var boards := []
	var t2 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/vh_human_test2.json"))
	for b in t2["boards"]:
		if b["id"] in CONTROL_IDS:
			var def: PuzzleDefinition = audit.rotate90(PuzzleDefinition.from_dict(b["puzzle"]))
			boards.append(_record(audit, "C", "test2 %s (%s), rotated 90" % [b["id"], b["source"]], def, 0, 0))
	FriendGenerator.spec_override = {FriendGenerator.VERY_HARD: X_SPEC}
	var cands := []
	var t0 := Time.get_ticks_msec()
	for i in n_cand:
		var g := FriendGenerator.new(FriendGenerator.VERY_HARD, 131000 + i * 7919, [], -1)
		var def := g.run()
		if def == null:
			print("candidate %d: none (%s)" % [i, g.error])
			continue
		var rec := _record(audit, "X", "generated seed %d" % (131000 + i * 7919), def, g.metrics.get("ms", 0), g.evals)
		var m: Dictionary = rec["metrics"]
		print("candidate %d: met=%s ms=%d cw=%d ccw=%d misread=%d cw_solvable=%s trap_delay=%.1f/%d smart2=%.2f one_safe=%d depth=%d" % [
			i, g.metrics.get("in_band", false), g.metrics.get("ms", 0), m["cw"], m["ccw"], m["misread_steps"], m["cw_solvable"],
			m["trap_delay"], m["trap_delay_max"], m["smart2"], m["one_safe"], m["depth"]])
		if m["ccw"] >= 2 and m["cw"] >= 2 and m["misread_steps"] >= 2:
			cands.append(rec)
	FriendGenerator.spec_override = {}
	print("X: %d of %d candidates qualify (%.0f s total)" % [cands.size(), n_cand, (Time.get_ticks_msec() - t0) / 1000.0])
	cands.sort_custom(func(a, b): return _x_score(a) > _x_score(b))
	for rec in cands.slice(0, X_COUNT):
		boards.append(rec)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261004
	for i in range(boards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = boards[i]
		boards[i] = boards[j]
		boards[j] = t
	for i in boards.size():
		boards[i]["id"] = "Q%02d" % (i + 1)
	var data := {"format": "ce-vh-human-test", "v": 3, "assist": {"undo": 3, "show_a_move": 1, "hammer": 0}, "boards": boards}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()
	print("wrote %s: %d boards" % [OUT, boards.size()])
	print("id  group  size  blocks  cw  ccw  start/safe/calm  one_safe  depth  misread  cw_solvable  trap_delay(avg/max)  tempting  smart2  random  source")
	for b in boards:
		var m: Dictionary = b["metrics"]
		print("%s  %s  %s  %d  %d  %d  %d/%d/%d  %d  %d  %d  %s  %.1f/%d  %d  %.2f  %.3f  %s" % [b["id"], b["variant"], m["size"], m["blocks"], m["cw"], m["ccw"],
			m["start"], m["start_safe"], m["start_calm"], m["one_safe"], m["depth"], m["misread_steps"], m["cw_solvable"],
			m["trap_delay"], m["trap_delay_max"], m["tempting"], m["smart2"], m["random"], b["source"]])
	quit()


func _x_score(rec: Dictionary) -> float:
	var m: Dictionary = rec["metrics"]
	return m["misread_steps"] * 2.0 + m["trap_delay"] + (3.0 if not m["cw_solvable"] else 0.0) - m["smart2"] * 10.0


func _record(audit, variant: String, source: String, def: PuzzleDefinition, ms: int, evals: int) -> Dictionary:
	var ok: bool = def != null and def.verify() and FriendGenerator.mechanics_ok(def, FriendGenerator.VERY_HARD, false, true)
	var rebuilt := PuzzleDefinition.from_json(def.to_json()) if def else null
	if not ok or rebuilt == null or rebuilt.fingerprint() != def.fingerprint() or FriendGenerator.is_classic_board(def):
		push_error("vh_human_test3_build: %s failed verification" % source)
		quit(1)
		return {}
	var m: Dictionary = audit.measure(def)
	m.merge(direction_measures(def), true)
	var lv := def.to_level()
	var model := BoardModel.new()
	model.setup(lv.rows, lv.columns, lv.blocks)
	m["random"] = snappedf(Solver.from_model(model).random_win_rate(300, 77), 0.001)
	m["gen_ms"] = ms
	m["gen_evals"] = evals
	return {"variant": variant, "source": source, "puzzle": def.to_dict(), "fingerprint": def.fingerprint(), "metrics": m}


## Spinner-direction measures (see the header).
static func direction_measures(def: PuzzleDefinition) -> Dictionary:
	var lv := def.to_level()
	var model := BoardModel.new()
	model.setup(lv.rows, lv.columns, lv.blocks)
	var cw := 0
	var ccw := 0
	for b in model.blocks.values():
		if b.is_spinner():
			if b.spin_rule == BlockData.SpinRule.CCW:
				ccw += 1
			else:
				cw += 1
	var all_cw := _as_cw(model)
	var out := {"cw": cw, "ccw": ccw, "cw_solvable": Solver.from_model(all_cw).is_solvable(),
		"misread_steps": 0, "trap_delay": 0.0, "trap_delay_max": 0}
	var sol: Array = Solver.from_model(model).solve()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var delays := []
	for mv in sol:
		var misread := false
		for id in model.blocks.keys():
			if model.move_state(id) != "ok":
				continue
			var real_safe := _safe_after(model, id)
			if real_safe != _safe_after(_as_cw(model), id):
				misread = true
			if not real_safe:
				delays.append(_delay(model, id, rng))
		if misread:
			out["misread_steps"] += 1
		model.remove(mv)
	if not delays.is_empty():
		out["trap_delay"] = snappedf(delays.reduce(func(a, b): return a + b, 0.0) / delays.size(), 0.1)
		out["trap_delay_max"] = int(delays.max())
	return out


## A copy of the board in which every spinner turns clockwise.
static func _as_cw(model: BoardModel) -> BoardModel:
	var snap := model.snapshot()
	for b in snap:
		if b.is_spinner():
			b.spin_rule = BlockData.SpinRule.CW
			b.spin_step = 0
	var m := BoardModel.new()
	m.setup(model.rows, model.columns, snap)
	return m


static func _safe_after(model: BoardModel, id: int) -> bool:
	var p := BoardModel.new()
	p.setup(model.rows, model.columns, model.snapshot())
	p.remove(id)
	return p.is_empty() or Solver.from_model(p).is_solvable()


## After the trap move `id`: average number of further random moves before
## no move is left (10 games). 0 = stuck at once (the mistake shows).
static func _delay(model: BoardModel, id: int, rng: RandomNumberGenerator) -> float:
	var total := 0
	for k in 10:
		var p := BoardModel.new()
		p.setup(model.rows, model.columns, model.snapshot())
		p.remove(id)
		var n := 0
		while true:
			var legal := p.blocks.keys().filter(func(x): return p.move_state(x) == "ok")
			if legal.is_empty():
				break
			p.remove(legal[rng.randi() % legal.size()])
			n += 1
		total += n
	return total / 10.0
