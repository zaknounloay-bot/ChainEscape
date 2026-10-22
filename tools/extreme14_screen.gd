extends "res://tools/extreme14_build.gd"
## EXTREME phase 9 (development only; tools/extreme11_screen.gd for the
## phase-9 recipe): one-edit beam screen around a designed
## core. Every round tries EVERY single edit of every board in the beam - add
## a plain arrow or a (counter-)clockwise spinner on an empty cell, change or
## remove or move a non-core piece (the frozen cells, the core, never
## change) - and
## keeps the best by exhaustive measures (the idea on EVERY winning line,
## >= 2 timing magnets, <= 700 positions, then decisions 6-move lookahead
## cannot settle, hidden losing moves, the deepest trap); the expert learners
## run only on the best few. Deterministic (no random climb).
##   godot --headless --path . --script res://tools/extreme14_screen.gd -- --file=seed.json --rounds=4 --beam=4 --out=/tmp/screen.json
## seed.json: {"map": [row, ...], "frozen": [[row, col], ...]}

const TOKENS := ["^", "v", "<", ">", "^@", "v@", "<@", ">@", "^@-", "v@-", "<@-", ">@-", "^&A", "v&A", "<&A", ">&A"]
const PALETTE := ["R", "G", "B", "Y", "P"]
var HINT_NODES := 280

var _seen := {}
var _frozen := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	cur_recipe = "C2_flip"
	x_args["recipe"] = "C2_flip"
	HINT_NODES = int(x_args.get("hint_nodes", str(HINT_NODES)))
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	for rc in d.get("frozen", []):
		_frozen[Vector2i(int(rc[1]), int(rc[0]))] = true
	var beam := [Array(d["map"])]
	var best_all := []
	for round in int(x_args.get("rounds", "3")):
		var cands := []
		for m in beam:
			for e in _edits(m):
				var r := _cheap(e)
				if not r.is_empty():
					cands.append(r)
		cands.sort_custom(func(a, b): return a["score"] > b["score"])
		var top := cands.slice(0, int(x_args.get("learn", "8")))
		for r in top:
			var par := parity(r["map"])
			r["parity_bad"] = par["mismatch_solve"] + par["mismatch_hint"]
			var ex := expert_gates(parse(r["map"]), true)
			r["learner"] = ex["learner"]
			r["learner_min"] = ex["learner_min"]
			r["gates_ok"] = ex["ok"]
			r["gates_why"] = ex["why"]
			r["score"] += 2.0 * minf(ex["learner_min"], 20.0) - (1000.0 if r["parity_bad"] > 0 else 0.0)
			if r["parity_bad"] > 0:
				r["gates_ok"] = false
				r["gates_why"] = "SOLVER PARITY FAILS (%d)" % r["parity_bad"]
		top.sort_custom(func(a, b): return a["score"] > b["score"])
		beam = top.slice(0, int(x_args.get("beam", "4"))).map(func(r): return r["map"])
		print("round %d: %d candidates, best:" % [round + 1, cands.size()])
		for r in top.slice(0, 4):
			print("  %.1f  greedy %.3f, hint nodes %s, pieces %d, positions %d, dec6/8 %d/%d, hidden6/8 %d/%d, deepest %d, opening %s, learners %s, lost hint %.1f ms %s" % [r["score"], r["greedy"], str(r["hint_nodes"]), r["pieces"], r["positions"],
				r["dec6"], r["dec8"], r["hid6"], r["hid8"], r["deepest"], r["opening"], str(r["learner"]), r["hint_ms"], "GATES OK" if r["gates_ok"] else r["gates_why"]])
			print("     " + JSON.stringify(r["map"]))
		best_all.append_array(top)
		if x_args.has("out"):
			var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
			f.store_string(JSON.stringify(best_all, " "))
			f.close()
	quit()


func _edits(map: Array) -> Array:
	var g := _grid(map)
	var out := []
	for r in g.size():
		for c in g[r].size():
			var at := Vector2i(c, r)
			if _frozen.has(at):
				continue
			var t: String = g[r][c]
			if t != "." and (t.ends_with("*") or t.contains("=") or t.contains("%")):
				continue
			var col: String = PALETTE[(r * 3 + c) % PALETTE.size()] if t == "." else t[0]
			if t != ".":
				var e := g.duplicate(true)
				e[r][c] = "."
				out.append(_rows(e))
				# Move it (same token) to any free empty cell.
				for r2 in g.size():
					for c2 in g[r2].size():
						if g[r2][c2] == "." and not _frozen.has(Vector2i(c2, r2)):
							var e3 := e.duplicate(true)
							e3[r2][c2] = t
							out.append(_rows(e3))
			for k in TOKENS:
				var nt: String = col + k
				if nt == t:
					continue
				var e2 := g.duplicate(true)
				e2[r][c] = nt
				out.append(_rows(e2))
	return out


## The exhaustive measures (no learners), or {} if a gate fails.
func _cheap(map: Array) -> Dictionary:
	var key := canonical(map)
	if _seen.has(key):
		return {}
	_seen[key] = true
	if _pieces(map) > max_pieces():
		return {}
	var level := parse(map)
	if level == null or not _intact(map, level):
		return {}
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	if memo["capped"] or win.size() > MAX_POSITIONS or not win.get(s._key(), false):
		return {}
	for k in MUST14["C2_flip"]:
		if not EV14.witness(level, k).is_empty():
			return {}
	if EV11.timing(s, win)["timing_magnets"].size() < TIMING_MAGNETS:
		return {}
	# The greedy players of every earlier acceptance (<= 5 %).
	var pol := 0.0
	for k in POLICIES:
		var w := PROBE.policy_win(s, k, 60, 31)
		if w > 0.1:
			return {}
		if w > MAX_POLICY_WIN:
			w = PROBE.policy_win(s, k, 200 if k != "look4" else 120, 31)
			if w > MAX_POLICY_WIN:
				return {}
		pol = maxf(pol, w)
	# SHOW A MOVE work along the solution and after a mistake (~0.13 ms a
	# node here; 280 nodes keeps the 40 ms budget with a margin).
	var hc := _hint_cost(level)
	if hc["max_nodes"] > HINT_NODES or hc["dead_max_nodes"] > HINT_NODES or hc["aborted"]:
		return {}
	if x_args.has("hint_ms"):
		# Measured time too, twice (the lower of the two passes counts).
		var hc2 := _hint_cost(level)
		var lim := float(x_args["hint_ms"])
		if minf(maxf(hc["max_ms_desktop"], hc["dead_max_ms_desktop"]), maxf(hc2["max_ms_desktop"], hc2["dead_max_ms_desktop"])) > lim:
			return {}
	var m := EXPERT.measure(s)
	var sol: int = m["solution"]
	if sol < 10 or sol > max_len():
		return {}
	var dec6 := int(m["decisions"][6])
	var dec8 := int(m["decisions"][8])
	var hid6 := int(m["hidden"][6])
	var hid8 := int(m["hidden"][8])
	var sc := 6.0 * dec6 + 4.0 * dec8 + 1.0 * hid6 + 1.5 * hid8 + 0.5 * int(m["deepest"]) - 0.03 * maxi(0, win.size() - SOFT_POSITIONS)
	var hint := lost_hint_ms(level)
	if hint > LOST_HINT_LAB_MS * 1.5:
		return {}
	return {"map": map, "score": sc, "greedy": pol, "hint_nodes": [hc["max_nodes"], hc["dead_max_nodes"]], "pieces": _pieces(map), "positions": win.size(), "dec6": dec6, "dec8": dec8, "hid6": hid6, "hid8": hid8,
		"deepest": m["deepest"], "opening": m["opening"], "hint_ms": hint, "learner": {}, "learner_min": 0.0, "gates_ok": false, "gates_why": ""}
