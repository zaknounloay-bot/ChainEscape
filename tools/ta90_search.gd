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
##   Phase 15 (all default to the Phase 14 behaviour): "piece_free": 8 (pieces
##   without a size penalty), "position_weight": 0.004, "coverage_weight" /
##   "late_weight": 0 (sustained risk), "length_weight" / "length_cap": 0,
##   "pressure_weight" (Phase 17, 0 by default): rank by multi-turned spinners
##   and late-showing mistakes (ta90_design.gd pressure()),
##   "max_solve_nodes" (Phase 16, optional): reject boards whose opening solve
##   needs more Solver nodes (keeps large boards inside the TIME UP gate),
##   "endgame_weight": 4 (the bonus for a decision in the last third),
##   "shortcut_weight": 25 (how hard a greedy shortcut above 20 % is penalised; raised when boards stall on it),
##   Phase 18: "palette": "arrows" (grow with plain arrows only - no spinner
##   ever added to a non-spinner core) | "all" (default); "crates_max" /
##   "crate_rate": the search may also add Movable crates ("M") up to that
##   count (default 0); Phase 19: "suffix_max": {"*": 3} caps each mark.
##   Phase 20: --ops=v20 (or "operators": "v20"; default off - the earlier
##   generator's edits and scores, unchanged) turns on the strategic operators below, and
##   every run counts its QUALIFYING boards (the fixed EXTREME search targets,
##   _qualifies) - the yield measure of docs/extreme90_phase20.md.}

const TOKENS := ["^", "v", "<", ">", "^@", "v@", "<@", ">@", "^@-", "v@-", "<@-", ">@-", "^@~", "v@~", "<@~", ">@~"]
const PALETTE := ["R", "G", "B", "Y", "P"]

var _rng := RandomNumberGenerator.new()
var _seen := {}
var _frozen := {}
var _spec := {}
var _evals := 0
var _v20 := false
var _qual := {}  # Phase 20: qualifying boards seen (map key -> brief)


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
	_v20 = str(x_args.get("ops", _spec.get("operators", ""))) == "v20"
	print("generator: %s" % ("v20 (strategic operators)" if _v20 else "baseline"))
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
			"stopped": "patience" if stale >= patience else "time", "generator": "v20" if _v20 else "baseline",
			"qualifying": _qual.values(), "seconds": snappedf((Time.get_ticks_msec() - t_end) / 1000.0 + float(x_args.get("minutes", "10")) * 60.0, 0.1)}, " "))
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
	if _v20:
		var e := _edit20(g, pieces, spots)
		if not e.is_empty():
			return e
	var kind := _rng.randi_range(0, 9)
	var maxp := int(_spec.get("max_pieces", 12))
	var toks := _tokens()
	if (kind < 5 or pieces.is_empty()) and not spots.is_empty() and _pieces(map) < maxp:
		var at: Vector2i = spots[_rng.randi_range(0, spots.size() - 1)]
		var crates: int = int(_spec.get("crates_max", 0))
		if crates > 0 and _count(g, "M") < crates and _rng.randf() < float(_spec.get("crate_rate", 0.15)):
			g[at.y][at.x] = "M"
		else:
			var col: String = PALETTE[_rng.randi_range(0, PALETTE.size() - 1)]
			g[at.y][at.x] = col + toks[_rng.randi_range(0, toks.size() - 1)] + _suffix(col, g)
	elif kind < 8 and not pieces.is_empty():
		var at: Vector2i = pieces[_rng.randi_range(0, pieces.size() - 1)]
		var col: String = str(g[at.y][at.x])[0]
		g[at.y][at.x] = col + toks[_rng.randi_range(0, toks.size() - 1)] + _suffix(col, g)
	elif not pieces.is_empty():
		var at: Vector2i = pieces[_rng.randi_range(0, pieces.size() - 1)]
		g[at.y][at.x] = "."
	else:
		return []
	var out := []
	for row in g:
		out.append(" ".join(row))
	return out


## Phase 18: the tokens the search may place ("palette": "arrows" - plain
## arrows only, so a non-spinner core never grows spinners; "all" - TOKENS,
## the Phase 14-17 default).
func _tokens() -> Array:
	return TOKENS.slice(0, 4) if str(_spec.get("palette", "all")) == "arrows" else TOKENS


## Phase 18: "suffixes" (e.g. ["&A", "+B", "#R"]): a new or changed piece
## sometimes (suffix_rate, default 0.25) also takes one of the core's own
## mechanic marks - a flip target of switch A, a link of gate B, a lock - so a
## switch / gate / lock core grows dependencies, not only plain arrows. The
## parser's rules still apply (an invalid mark makes the board not intact:
## filtered). Only with a plain-arrow token (flip targets / locks on spinners
## are refused by the engine anyway).
## Phase 19: "suffix_max" ({"*": 3, ...}) caps how many pieces may carry a
## mark (mechanic economy during the search: no magnet-crowded boards).
func _suffix(col: String, g: Array = []) -> String:
	var sx: Array = _spec.get("suffixes", [])
	if sx.is_empty() or _rng.randf() >= float(_spec.get("suffix_rate", 0.25)):
		return ""
	var x := str(sx[_rng.randi_range(0, sx.size() - 1)])
	var cap: Dictionary = _spec.get("suffix_max", {})
	if cap.has(x) and _marked(g, x) >= int(cap[x]):
		return ""
	return "" if x.begins_with("#") and x.substr(1) == col else x  # never locked by its own colour


## Pieces carrying the mark `x` (a magnet "*" is never a spinner's "@*").
static func _marked(g: Array, x: String) -> int:
	var n := 0
	for row in g:
		for t in row:
			var s := str(t)
			if x == "*":
				n += int(s.ends_with("*") and not s.contains("@"))
			else:
				n += int(s.contains(x))
	return n


static func _count(g: Array, tok: String) -> int:
	var n := 0
	for row in g:
		n += Array(row).count(tok)
	return n


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
	# Phase 16: a Solver-cost cap (the nodes of the opening solve), so large
	# boards stay inside the 40 ms TIME UP gate of ta90_design.gd.
	if _spec.has("max_solve_nodes") and s.nodes > int(_spec["max_solve_nodes"]):
		return {}
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
	# Phase 20: how often two or more risky moves are open at once along the
	# line (a calm-first player then still has an order to get wrong).
	var conc := _concurrency(s, sol)
	var sc: float = 4.0 * mini(dec["distinct_mistakes"], need["distinct"] + 2) + 1.5 * mini(dec["decision_steps"], need["steps"] + 3) \
		+ 3.0 * (thirds[0] + thirds[1] + thirds[2]) + (float(_spec.get("endgame_weight", 4.0)) if dec["endgame_decision"] else 0.0) \
		+ 6.0 * matters - 8.0 * (mechs.size() - matters) \
		- float(_spec.get("shortcut_weight", 25.0)) * maxf(0.0, shortcut - float(need.get("shortcut", SHORTCUT_MAX))) - 8.0 * shortcut \
		- 0.6 * maxi(0, pieces - int(_spec.get("piece_free", 8))) - float(_spec.get("position_weight", 0.004)) * win.size()
	# Phase 15 (0 by default: earlier seeds reproduce): sustained risk.
	var sl := float(maxi(1, sol.size()))
	sc += float(_spec.get("coverage_weight", 0.0)) * (dec["decision_steps"] / sl) + float(_spec.get("late_weight", 0.0)) * (dec["last_decision"] / sl)
	sc += float(_spec.get("length_weight", 0.0)) * mini(sol.size(), int(_spec.get("length_cap", 0)))
	# Phase 17 (0 by default): the human-calibrated pressure diagnostics as a
	# RANKING term - multi-turned spinners and late-showing mistakes.
	var pr := {}
	if float(_spec.get("pressure_weight", 0.0)) > 0.0:
		pr = pressure(level, s, memo, sol)
		sc += float(_spec["pressure_weight"]) * (mini(pr["multi_turned"], 5) + 0.5 * mini(pr["trap_delay_median"], 9))
	if _v20:
		sc += float(_spec.get("concurrency_weight", 12.0)) * conc
	var out := _result(map, sc, pieces, win, sol, dec, thirds, matters, mechs, shortcut, lps, sl, pr, conc)
	if _qualifies(out, need, mechs.size()):
		_qual[key] = _brief(out, -1).merged({"map": map, "solution": out["solution"], "coverage": out["coverage"], "late": out["late"]})
	return out


func _result(map: Array, sc: float, pieces: int, win: Dictionary, sol: Array, dec: Dictionary, thirds: Array, matters: int, mechs,
		shortcut: float, lps: Array, sl: float, pr: Dictionary, conc: float) -> Dictionary:
	return {"map": map, "score": snappedf(sc, 0.01), "pieces": pieces, "positions": win.size(), "solution": sol.size(),
		"distinct": dec["distinct_mistakes"], "steps": dec["decision_steps"], "endgame": dec["endgame_decision"], "thirds": thirds,
		"matters": "%d/%d" % [matters, mechs.size()], "shortcut": snappedf(shortcut, 0.001), "per_step": lps,
		"coverage": snappedf(dec["decision_steps"] / sl, 0.01), "late": snappedf(dec["last_decision"] / sl, 0.01),
		"multi_turned": pr.get("multi_turned", -1), "trap_delay": pr.get("trap_delay_median", -1), "concurrency": snappedf(conc, 0.01)}


## Phase 20: the share of the Solver line's steps with >= 2 risky legal moves.
func _concurrency(s: Solver, sol: Array) -> float:
	var multi := 0
	for mv in sol:
		var n := 0
		for o in s._distinct_legal():
			n += int(PROBE.risky(s, o))
		multi += int(n >= 2)
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	return float(multi) / maxf(sol.size(), 1)


## Phase 20: the search-level EXTREME targets (NEED, fixed before the
## experiment): the board would pass category B's numbers (the full report
## still decides).
func _qualifies(r: Dictionary, need: Dictionary, n_mechs: int) -> bool:
	return r["distinct"] >= int(need["distinct"]) and r["steps"] >= int(need["steps"]) and (r["endgame"] or not need["endgame"]) \
		and r["coverage"] >= float(need.get("coverage", 0.0)) and r["late"] >= float(need.get("late", 0.0)) \
		and r["solution"] >= int(need.get("min_solution", 0)) and r["shortcut"] <= float(need.get("shortcut", SHORTCUT_MAX)) \
		and r["matters"] == "%d/%d" % [n_mechs, n_mechs]


## Phase 20 strategic operators (--ops=v20), or [] to fall back to the earlier
## edit. 1. ACTOR (actor_rate, default 0.3): add a risky actor of the core's
## OWN mechanics - another switch of an existing group (at most 2 per group),
## one of the spec's marks (flip target, shell, magnet, lock, link; caps
## kept), a crate (crates_max) - on a plain piece or a new one. 2. MARKS ARE
## REVERSIBLE: a non-frozen marked piece can be removed, unmarked, or turned
## with its mark kept (before Phase 20 a mark, once added, stayed for good).
## 3. FOCUSED PLACEMENT: new pieces go mostly (focus_rate, 0.7) into the rows
## / columns of risky actors (switches, crates, shells, magnets, flip targets).
func _edit20(g: Array, plain: Array, spots: Array) -> Array:
	var marked := []
	var focus := []
	for r in g.size():
		for c in g[0].size():
			var t := str(g[r][c])
			if t != "." and not _frozen.has(Vector2i(c, r)) and not _editable(t) and not t.begins_with("X"):
				marked.append(Vector2i(c, r))
	for at in spots:
		if _in_actor_lane(g, at):
			focus.append(at)
	var maxp := int(_spec.get("max_pieces", 12))
	var roll := _rng.randf()
	if roll < float(_spec.get("actor_rate", 0.3)):
		return _actor(g, plain, focus if not focus.is_empty() else spots, maxp)
	if roll < float(_spec.get("actor_rate", 0.3)) + 0.15 and not marked.is_empty():
		var at: Vector2i = marked[_rng.randi_range(0, marked.size() - 1)]
		var t := str(g[at.y][at.x])
		var k := _rng.randi_range(0, 2)
		if k == 0:
			g[at.y][at.x] = "."
		elif k == 1 and t != "M":
			g[at.y][at.x] = t.substr(0, 2)  # unmark: colour + arrow
		elif t != "M":
			g[at.y][at.x] = t[0] + TOKENS[_rng.randi_range(0, 3)] + t.substr(2)  # turn, mark kept
		else:
			return []
		return _join(g)
	# Otherwise the earlier edit, with new pieces placed in actor lanes first.
	if not focus.is_empty() and _rng.randf() < float(_spec.get("focus_rate", 0.7)) and _pieces(_join(g)) < maxp and _rng.randf() < 0.5:
		var at: Vector2i = focus[_rng.randi_range(0, focus.size() - 1)]
		var col: String = PALETTE[_rng.randi_range(0, PALETTE.size() - 1)]
		var toks := _tokens()
		g[at.y][at.x] = col + toks[_rng.randi_range(0, toks.size() - 1)] + _suffix(col, g)
		return _join(g)
	return []


func _actor(g: Array, plain: Array, spots: Array, maxp: int) -> Array:
	var kinds := []
	var groups := {}
	for row in g:
		for t in row:
			var i := str(t).find("%")
			if i >= 0:
				groups[str(t).substr(i + 1, 1)] = true
	for grp in groups:
		if _marked(g, "%" + grp) < 2:
			kinds.append("%" + grp)
	var cap: Dictionary = _spec.get("suffix_max", {})
	for x in _spec.get("suffixes", []):
		if not cap.has(x) or _marked(g, x) < int(cap[x]):
			kinds.append(str(x))
	if int(_spec.get("crates_max", 0)) > _count(g, "M"):
		kinds.append("M")
	if kinds.is_empty():
		return []
	var kind: String = kinds[_rng.randi_range(0, kinds.size() - 1)]
	var on_plain := not plain.is_empty() and kind != "M" and _rng.randf() < 0.5
	if not on_plain and (spots.is_empty() or _pieces(_join(g)) >= maxp):
		return []
	var at: Vector2i = plain[_rng.randi_range(0, plain.size() - 1)] if on_plain else spots[_rng.randi_range(0, spots.size() - 1)]
	if kind == "M":
		g[at.y][at.x] = "M"
		return _join(g)
	var col: String = str(g[at.y][at.x])[0] if on_plain else PALETTE[_rng.randi_range(0, PALETTE.size() - 1)]
	if kind.begins_with("#") and kind.substr(1) == col:
		return []
	var arrow: String = str(g[at.y][at.x])[1] if on_plain else TOKENS[_rng.randi_range(0, 3)]
	g[at.y][at.x] = col + arrow + kind
	return _join(g)


## A cell in the row / column of a risky actor (or of a piece it acts on).
func _in_actor_lane(g: Array, at: Vector2i) -> bool:
	for r in g.size():
		for c in g[0].size():
			if r != at.y and c != at.x:
				continue
			var t := str(g[r][c])
			if t == "M" or t.contains("%") or t.contains("&") or t.contains("=") or (t.ends_with("*") and not t.contains("@")):
				return true
	return false


static func _join(g: Array) -> Array:
	var out := []
	for row in g:
		out.append(" ".join(row))
	return out


func _line(r: Dictionary) -> String:
	return "%.1f | %d pieces, %d positions, solution %d, distinct %d, steps %d (cover %.2f, late %.2f), endgame %s, mechanic %s, shortcut %.0f%% | %s" % [r["score"], r["pieces"],
		r["positions"], r["solution"], r["distinct"], r["steps"], r.get("coverage", 0.0), r.get("late", 0.0), r["endgame"], r["matters"], r["shortcut"] * 100.0, JSON.stringify(r["map"])]


func _brief(r: Dictionary, round: int) -> Dictionary:
	return {"round": round, "score": r["score"], "pieces": r["pieces"], "positions": r["positions"], "distinct": r["distinct"],
		"steps": r["steps"], "endgame": r["endgame"], "matters": r["matters"], "shortcut": r["shortcut"], "evaluated": _evals}
