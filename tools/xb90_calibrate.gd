extends "res://tools/ta90_design.gd"
## PHASE 17 (development only): human-oriented diagnostics for EXTREME 90 s
## boards (docs/extreme90_phase17.md), to compare with the family playtests.
##   godot --headless --path . --script res://tools/xb90_calibrate.gd -- --file=boards.json [--out=res.json]
## boards.json: {"N14": {"map": [...]}, ...}
## Per board (all diagnostic, category C; never a rejection by itself):
##   calm_prefix   pieces a player clears with CALM moves only (no spinner
##                 turned, no switch fired, no rule touched - PROBE.risky) before
##                 the first real decision
##   core          pieces left after that calm prefix
##   trap delays   for each losing move along the solution: how many more
##                 moves can be played before the jam (the longest continuation)
##   undo_proof    share of those losing moves that can NOT be fixed with
##                 UNDO x3 (the jam comes more than 3 moves later: a RESTART
##                 and the clock pay for them)
##   win_share     winnable positions / reachable positions
##   state-change load (along the solution, through BoardModel): spinner
##                 turns, spinners turned more than once, flips, pulls, rams,
##                 Sequence advances, and the share of moves that change another
##                 piece's direction or place ("prediction moves")
##   ordering twin every spinner made a plain arrow fixed in its direction at
##                 its escape along the solution: twin decision steps / distinct
##                 mistakes against the board's ("ordering_share": how much of
##                 the decision structure is a visible ordering chain)
##   undo player   a player who takes calm moves first, else a random legal
##                 move, UNDOes (3 per attempt) when stuck, then RESTARTs: the
##                 median attempts and taps to a win over 60 runs (cap 1500)

const RUNS := 60
const TAP_CAP := 1500


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var out := {}
	for k in d:
		if x_args.has("name") and not str(x_args["name"]).split(",").has(k):
			continue
		out[k] = human_metrics(Array(d[k]["map"]))
		print("%s %s" % [k, JSON.stringify(out[k])])
	if x_args.has("out"):
		var f := FileAccess.open(str(x_args["out"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


func human_metrics(map: Array) -> Dictionary:
	var level := parse(map)
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	var win: Dictionary = memo["win"]
	var r := {"pieces": _pieces(map), "positions": win.size(), "win_share": snappedf(float(win.values().count(true)) / maxf(win.size(), 1), 0.001)}
	# The calm prefix: calm moves taken while any exists.
	var done := []
	while true:
		var calm := s._distinct_legal().filter(func(mv): return not PROBE.risky(s, mv))
		if calm.is_empty():
			break
		s._do(calm[0])
		done.append(calm[0])
	r["calm_prefix"] = done.size()
	r["calm_prefix_safe"] = s._alive_count == s._crate_n or win.get(s._key(), false)
	r["core"] = r["pieces"] - done.size()
	for i in range(done.size() - 1, -1, -1):
		s._undo_move(done[i])
	# Trap delays along the solution.
	var sol := s.solve_moves()
	var delays := []
	for mv in sol:
		for o in s._distinct_legal():
			s._do(o)
			if s._alive_count != s._crate_n and not win.get(s._key(), false):
				delays.append(EXPERT.longest(s, memo))
			s._undo_move(o)
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	delays.sort()
	r["losing_on_path"] = delays.size()
	r["trap_delay_median"] = delays[delays.size() / 2] if not delays.is_empty() else 0
	r["undo_proof"] = snappedf(float(delays.filter(func(x): return x > 3).size()) / maxf(delays.size(), 1), 0.01)
	# State-change load along the solution (BoardModel, as the screen plays it):
	# what a player must PREDICT, beyond which lanes are open.
	r.merge(_load(level, sol))
	# The ORDERING-ONLY twin: every spinner a plain arrow fixed in the
	# direction it has when it leaves along the solution (every other mechanic
	# kept). Decisions the twin keeps come from a visible ordering chain;
	# decisions it loses needed predicting turns.
	r.merge(_ordering_twin(map, level, sol, win))
	# The UNDO x3 player.
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var attempts := []
	var taps := []
	for run in RUNS:
		var res := _undo_player(s, rng)
		attempts.append(res[0])
		taps.append(res[1])
	attempts.sort()
	taps.sort()
	r["undo_player_attempts_median"] = attempts[RUNS / 2]
	r["undo_player_taps_median"] = taps[RUNS / 2]
	r["undo_player_first_try"] = snappedf(float(attempts.filter(func(x): return x == 1).size()) / RUNS, 0.01)
	return r


## [attempts, taps] for one simulated player (TAP_CAP taps at most).
func _undo_player(s: Solver, rng: RandomNumberGenerator) -> Array:
	var attempts := 1
	var taps := 0
	var path := []
	var undos := 3
	while taps < TAP_CAP:
		if s._alive_count == s._crate_n:
			break
		var legal := s._distinct_legal()
		if legal.is_empty():
			if undos > 0 and not path.is_empty():
				s._undo_move(path.pop_back())
				undos -= 1
				taps += 1
				continue
			for i in range(path.size() - 1, -1, -1):
				s._undo_move(path[i])
			path.clear()
			undos = 3
			attempts += 1
			taps += 1
			continue
		var calm := legal.filter(func(mv): return not PROBE.risky(s, mv))
		var pool: Array = calm if not calm.is_empty() else legal
		var pick: int = pool[rng.randi() % pool.size()]
		s._do(pick)
		path.append(pick)
		taps += 1
	for i in range(path.size() - 1, -1, -1):
		s._undo_move(path[i])
	return [attempts, taps]


func _ordering_twin(map: Array, level: LevelData, sol: Array, win: Dictionary) -> Dictionary:
	var m := EVENTS6.model_of(level)
	var final_dir := {}  # cell -> arrow at escape
	var arrows := ["^", "v", "<", ">"]  # Direction: UP, DOWN, LEFT, RIGHT
	for mv in sol:
		var id: int = mv & Solver.ID_MASK
		var b: BlockData = m.blocks.get(id)
		if b == null:
			continue
		var cell: Vector2i = b.cell
		var st := m.move_state(id)
		if st == "ok" and b.is_spinner():
			final_dir[cell] = arrows[b.direction]
		play_move(m, mv)
	var s0 := _solver(level)
	var d0 := _decisions(s0, win, sol)
	var twin := []
	var spin := 0
	for r in map.size():
		var cells := []
		var row: Array = Array(str(map[r]).split(" ", false))
		for c in row.size():
			var t: String = row[c]
			var at := t.find("@")
			if at >= 0:
				spin += 1
				var rest := t.substr(at + 2) if at + 1 < t.length() and t[at + 1] in ["-", "~", "*"] else t.substr(at + 1)
				t = t[0] + final_dir.get(Vector2i(c, r), t[1]) + rest
			cells.append(t)
		twin.append(" ".join(cells))
	var out := {"spinners": spin}
	var tl := parse(twin)
	if tl == null or not _intact(twin, tl):
		out["twin"] = "does not parse"
		return out
	var ts := _solver(tl)
	var tm := EXPERT.explore(ts)
	if not tm["win"].get(ts._key(), false):
		out["twin"] = "unsolvable"
		out["ordering_share"] = 0.0
		return out
	var tsol := ts.solve_moves()
	var td := _decisions(ts, tm["win"], tsol)
	out["twin"] = "%d steps, %d distinct (board: %d, %d)" % [td["decision_steps"], td["distinct_mistakes"], d0["decision_steps"], d0["distinct_mistakes"]]
	out["ordering_share"] = snappedf(float(td["distinct_mistakes"]) / maxf(d0["distinct_mistakes"], 1), 0.01)
	return out
