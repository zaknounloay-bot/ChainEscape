extends "res://tools/ta90_design.gd"
## PHASE 14 (development only): a BOUNDED constructive search around a
## hand-drawn idea core (docs/ta90_design.md). Unlike the phase-13 beam
## screens it does not try every edit of every board, and it does not score
## solver depth: it samples a small batch of edits per round, only at cells
## that INTERACT with the board (an empty cell next to a piece - its leaving
## turns a spinner or frees a lane - or in the row / column of a core piece),
## and scores the board's own strategic checks (category B of
## tools/ta90_design.gd):
##   the idea on every winning line and solvability within the position cap
##   are filters; then distinct mistakes on the solution, decision steps, a
##   decision in the endgame, mistakes spread over the opening / middle /
##   endgame, the mechanic NOT decoration (counterfactual), and NO greedy
##   shortcut are the score. Fewer pieces are preferred (a compact board).
## It stops at the time budget, or when the best board has not improved for
## --patience rounds (then the strategy should change, not the run length).
##   godot --headless --path . --script res://tools/ta90_search.gd -- --file=seed.json --minutes=10 --batch=40 --beam=5 --out=res.json
## seed.json: {"map": [...], "frozen": [[row, col], ...], "target": "HARD", "facts": [...], "mechanic": "gate,armor", "max_pieces": 11, "seed": 1,
##   "endgame_weight": 4 (the bonus for a decision in the last third),
##   "shortcut_weight": 25 (how hard a greedy shortcut above 20 % is penalised; raised when boards stall on it)}

const TOKENS := ["^", "v", "<", ">", "^@", "v@", "<@", ">@", "^@-", "v@-", "<@-", ">@-", "^@~", "v@~", "<@~", ">@~"]
const PALETTE := ["R", "G", "B", "Y", "P"]

var _rng := RandomNumberGenerator.new()
var _seen := {}
var _frozen := {}
var _spec := {}
var _evals := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	_load_known()
	_spec = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	for rc in _spec.get("frozen", []):
		_frozen[Vector2i(int(rc[1]), int(rc[0]))] = true
	_rng.seed = int(x_args.get("seed", str(_spec.get("seed", 1))))
	var t_end := Time.get_ticks_msec() + int(float(x_args.get("minutes", "10")) * 60000.0)
	var batch := int(x_args.get("batch", "40"))
	var beam_n := int(x_args.get("beam", "5"))
	var patience := int(x_args.get("patience", "6"))
	var first := _score(Array(_spec["map"]))
	if first.is_empty():
		print("the seed core fails a filter (unsolvable, idea not on every line, or too many positions)")
		quit()
		return
	var beam := [first]
	var best: Dictionary = first
	var log := [_brief(first, 0)]
	var stale := 0
	var round := 0
	print("seed: %s" % _line(first))
	while Time.get_ticks_msec() < t_end and stale < patience:
		round += 1
		var cands := beam.duplicate()
		for b in beam:
			for i in batch / beam.size():
				var e := _edit(b["map"])
				if e.is_empty():
					continue
				var r := _score(e)
				if not r.is_empty():
					cands.append(r)
		cands.sort_custom(func(a, b): return a["score"] > b["score"])
		# Diversity: at most two boards with the same piece count in the beam.
		var nb := []
		var per := {}
		for c in cands:
			var k: int = c["pieces"]
			if per.get(k, 0) >= 2:
				continue
			per[k] = per.get(k, 0) + 1
			nb.append(c)
			if nb.size() >= beam_n:
				break
		beam = nb
		if beam[0]["score"] > best["score"] + 0.01:
			best = beam[0]
			stale = 0
		else:
			stale += 1
		log.append(_brief(best, round))
		print("round %d (%d evaluated, %.0f s): best %s" % [round, _evals, (Time.get_ticks_msec() - t_end) / 1000.0 + float(x_args.get("minutes", "10")) * 60.0, _line(best)])
	print("stopped after %d rounds: %s" % [round, "no improvement for %d rounds" % patience if stale >= patience else "time budget"])
	print("BEST %s" % JSON.stringify(best["map"]))
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify({"best": best, "beam": beam, "log": log, "evaluated": _evals, "rounds": round,
			"stopped": "patience" if stale >= patience else "time"}, " "))
		f.close()
	quit()


## One random edit at an interacting cell (never a frozen one), or [].
func _edit(map: Array) -> Array:
	var g := []
	for row in map:
		g.append(Array(str(row).split(" ", false)))
	var rows := g.size()
	var cols: int = g[0].size()
	var pieces := []
	var spots := []
	for r in rows:
		for c in cols:
			if g[r][c] != "." and not _frozen.has(Vector2i(c, r)) and _editable(g[r][c]):
				pieces.append(Vector2i(c, r))
			if g[r][c] == "." and _interacts(g, r, c):
				spots.append(Vector2i(c, r))
	var kind := _rng.randi_range(0, 9)
	var maxp := int(_spec.get("max_pieces", 12))
	if (kind < 5 or pieces.is_empty()) and not spots.is_empty() and _pieces(map) < maxp:
		var at: Vector2i = spots[_rng.randi_range(0, spots.size() - 1)]
		g[at.y][at.x] = PALETTE[_rng.randi_range(0, PALETTE.size() - 1)] + TOKENS[_rng.randi_range(0, TOKENS.size() - 1)]
	elif kind < 8 and not pieces.is_empty():
		var at: Vector2i = pieces[_rng.randi_range(0, pieces.size() - 1)]
		g[at.y][at.x] = str(g[at.y][at.x])[0] + TOKENS[_rng.randi_range(0, TOKENS.size() - 1)]
	elif not pieces.is_empty():
		var at: Vector2i = pieces[_rng.randi_range(0, pieces.size() - 1)]
		g[at.y][at.x] = "."
	else:
		return []
	var out := []
	for row in g:
		out.append(" ".join(row))
	return out


## Plain arrows and spinners can be edited; designed pieces (switches, flip
## targets, gates, links, shells, locks, magnets) only by hand.
static func _editable(t: String) -> bool:
	return not (t.ends_with("*") or t.contains("=") or t.contains("%") or t.contains("&") or t.contains("#")
		or t.begins_with("X") or t == "M" or t.contains("+") or t.contains(":"))


## An empty cell interacts: next to a piece, or in a core piece's row / column.
func _interacts(g: Array, r: int, c: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var rr: int = r + d.y
		var cc: int = c + d.x
		if rr >= 0 and rr < g.size() and cc >= 0 and cc < g[0].size() and g[rr][cc] != ".":
			return true
	for at in _frozen:
		if (at.y == r or at.x == c) and g[at.y][at.x] != ".":
			return true
	return false


## The strategic score, or {} if a filter fails.
func _score(map: Array) -> Dictionary:
	var key := "|".join(map)
	if _seen.has(key):
		return {}
	_seen[key] = true
	_evals += 1
	var level := parse(map)
	if level == null or not _intact(map, level):
		return {}
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	if memo["capped"] or win.size() > int(_spec.get("max_positions", MAX_POSITIONS)) or not win.get(s._key(), false):
		return {}
	for k in _spec.get("facts", []):
		if not EV17.witness(level, k).is_empty():
			return {}
	var sol := s.solve_moves()
	var dec := _decisions(s, win, sol)
	var need: Dictionary = NEED.get(str(_spec.get("target", "MEDIUM")), NEED["MEDIUM"])
	# Where the mistakes are: opening / middle / endgame thirds.
	var thirds := [0, 0, 0]
	var lps: Array = dec["losing_per_step"]
	for i in lps.size():
		if lps[i] > 0:
			thirds[mini(2, i * 3 / maxi(1, lps.size()))] = 1
	var matters := 0
	var mechs := str(_spec.get("mechanic", "")).split(",", false)
	for mech in mechs:
		if _counterfactual(map, mech, dec)["matters"]:
			matters += 1
	var shortcut := 0.0
	for k in POLICIES:
		shortcut = maxf(shortcut, PROBE.policy_win(s, k, 40, 31))
	var pieces := _pieces(map)
	var sc: float = 4.0 * mini(dec["distinct_mistakes"], need["distinct"] + 2) + 1.5 * mini(dec["decision_steps"], need["steps"] + 3) \
		+ 3.0 * (thirds[0] + thirds[1] + thirds[2]) + (float(_spec.get("endgame_weight", 4.0)) if dec["endgame_decision"] else 0.0) \
		+ 6.0 * matters - 8.0 * (mechs.size() - matters) \
		- float(_spec.get("shortcut_weight", 25.0)) * maxf(0.0, shortcut - SHORTCUT_MAX) - 8.0 * shortcut \
		- 0.6 * maxi(0, pieces - 8) - 0.004 * win.size()
	return {"map": map, "score": snappedf(sc, 0.01), "pieces": pieces, "positions": win.size(), "solution": sol.size(),
		"distinct": dec["distinct_mistakes"], "steps": dec["decision_steps"], "endgame": dec["endgame_decision"], "thirds": thirds,
		"matters": "%d/%d" % [matters, mechs.size()], "shortcut": snappedf(shortcut, 0.001), "per_step": lps}


func _line(r: Dictionary) -> String:
	return "%.1f | %d pieces, %d positions, solution %d, distinct %d, steps %d, endgame %s, thirds %s, mechanic %s, shortcut %.0f%% | %s" % [r["score"], r["pieces"],
		r["positions"], r["solution"], r["distinct"], r["steps"], r["endgame"], str(r["thirds"]), r["matters"], r["shortcut"] * 100.0, JSON.stringify(r["map"])]


func _brief(r: Dictionary, round: int) -> Dictionary:
	return {"round": round, "score": r["score"], "pieces": r["pieces"], "positions": r["positions"], "distinct": r["distinct"],
		"steps": r["steps"], "endgame": r["endgame"], "matters": r["matters"], "shortcut": r["shortcut"], "evaluated": _evals}
