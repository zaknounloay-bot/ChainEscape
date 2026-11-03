extends SceneTree
## Phase 33 (development only): replays the first-exposure TIME ATTACK 90 logs of
## ?extreme90p33=1 (format ce-xb33) on the real game rules and checks every
## logged event against the engine. Nothing is inferred from timestamps.
##   godot --headless --path . --script res://tools/ta90_replay33.gd -- \
##       --logs=data/dev/extreme90_p33/human/xb33_logs.json --json=out.json
## The board: data/dev/ta90_<id>.json, built exactly as the page and its exact
## TIME UP continuation build it (Ta90TimeAttack._replayed: BoardModel.setup +
## set_portals; moves dispatched by move_state: ok / advance / push / ram).
## Per logged event:
##   m  the logged block must be playable (move_state); the board diff must
##      give back the same block (VhHumanTest.infer_tap) and the same
##      mechanic effects (VhHumanTest.mech_events); then: can the board still
##      be cleared (exact Solver), how many legal moves the position offered
##      and how many of them still won (a consequential choice = at least one
##      winning and at least one losing legal move).
##   u  UNDO restores the position before the last move (SocialPlay.undo; 3
##      per attempt: SocialPlay._load_puzzle resets undos_used on RESTART).
##   r  RESTART: the start position; a new attempt.
##   b  blocked tap: the logged block must NOT be playable there.
##   a  tap on an armored block: the logged block must be armored there.
##   z / t  timer stage / TIME UP (no board change).
## A move whose logged block is not playable, or whose board diff disagrees,
## is reported and NOT replayed further in that attempt (never guessed).

const ESC := ["ok", "ram", "push", "advance"]
var args := {}
var _memo := {}


## longest() memoised on the board state (the same rules; only faster): the
## depth of every losing alternative at every position the player met.
func depth_of(m: BoardModel) -> int:
	var key := JSON.stringify(snap(m))
	if _memo.has(key):
		return _memo[key]
	var best := 0
	for id in m.blocks.keys():
		var st := m.move_state(id)
		if not (st in ESC):
			continue
		var sn := m.snapshot()
		apply(m, id, st)
		best = maxi(best, 1 + depth_of(m))
		m.restore(sn)
	_memo[key] = best
	return best


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var logs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(args["logs"])))
	var out := {}
	var ids: Array = logs.keys()
	ids.sort_custom(func(a, b): return int(a.substr(1)) < int(b.substr(1)))
	for id in ids:
		if args.has("id") and str(args["id"]) != id:
			continue
		out[id] = replay(id, logs[id])
	if args.has("json"):
		var f := FileAccess.open(str(args["json"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, " "))
		f.close()
	quit()


static func snap(m: BoardModel) -> Dictionary:
	var o := {}
	for id in m.blocks:
		var b: BlockData = m.blocks[id]
		o[id] = [b.cell, b.direction, b.seq_stage, b.armored, b.kind]
	return o


static func cell(m: BoardModel, id: int) -> String:
	var b: BlockData = m.blocks.get(id)
	if b == null:
		return "#%d(gone)" % id
	var k := ""
	if b.armored:
		k = " shell"
	elif b.kind == BlockData.Kind.SPINNER:
		k = " spinner"
	elif b.magnet:
		k = " magnet"
	elif b.switch_group != "":
		k = " switch"
	elif b.lock_color != "":
		k = " lock"
	return "#%d %s%s R%dC%d%s" % [id, b.color.substr(0, 1).to_upper(), ["^", "v", "<", ">"][b.direction], b.cell.y + 1, b.cell.x + 1, k]


static func apply(m: BoardModel, id: int, st: String) -> void:
	match st:
		"ok":
			m.remove(id)
		"advance":
			m.advance(id)
		"push":
			m.push(id)
		"ram":
			m.ram(id)


static func winnable(m: BoardModel) -> int:
	if m.is_empty():
		return 1
	var s := Solver.from_model(m)
	s.node_limit = Solver.DEFAULT_NODE_LIMIT
	var sol := s.solve()
	if s.aborted:
		return -1
	return 1 if not sol.is_empty() else 0


## Legal moves of a position, each with whether it keeps the board winnable.
static func options(m: BoardModel) -> Array:
	var o := []
	var ids: Array = m.blocks.keys()
	ids.sort()
	for id in ids:
		var st := m.move_state(id)
		if not (st in ESC):
			continue
		var sn := m.snapshot()
		apply(m, id, st)
		o.append({"id": id, "st": st, "win": winnable(m)})
		m.restore(sn)
	return o


## Longest run of legal moves from a position (how long play can go on).
static func longest(m: BoardModel, depth: int = 0) -> int:
	if depth > 24:
		return 0
	var best := 0
	for id in m.blocks.keys():
		var st := m.move_state(id)
		if not (st in ESC):
			continue
		var sn := m.snapshot()
		apply(m, id, st)
		best = maxi(best, 1 + longest(m, depth + 1))
		m.restore(sn)
		if best >= 24:
			break
	return best


func replay(id: String, rec: Dictionary) -> Dictionary:
	var meta: Dictionary = rec["meta"]
	var board: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/ta90_%s.json" % id.to_lower()))["boards"][0]
	var def := PuzzleDefinition.from_dict(board["puzzle"])
	var level := def.to_level()
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals(level.portals)
	var total := m.block_count()
	var start := m.snapshot()
	var checks := []
	var fp_ok: bool = def.fingerprint() == str(meta["fp"]) and str(board["fingerprint"]) == str(meta["fp"])
	checks.append(["fingerprint (board record == supplied)", fp_ok])
	checks.append(["pieces %d == supplied %s" % [total, meta["pieces"]], total == int(meta["pieces"])])
	var s0 := Solver.from_model(m)
	var solution: Array = s0.solve()
	var sol_ids := []
	for mv in solution:
		sol_ids.append(int(mv) if typeof(mv) != TYPE_DICTIONARY else int(mv.get("id", -1)))
	print("\n=== %s  %s, %s, %d pieces; exact solution %d moves: %s" % [id, meta["rating"], meta["outcome"], total, sol_ids.size(), str(sol_ids)])
	var attempts := []
	var history: Array = []
	var undos_att := 0
	var a := _new_att(1, 0)
	var lost := false
	var bad := ""
	var problems := []
	var mech_tot := {}
	var escapes_logged := 0
	var max_cleared := 0
	for e in rec["log"]:
		var t := int(e[0])
		var k: String = e[1]
		var blk := int(e[2])
		match k:
			"m":
				if bad != "":
					a["events"].append("%6.2fs m %d NOT REPLAYED (%s)" % [t / 1000.0, blk, bad])
					continue
				var st := m.move_state(blk) if m.blocks.has(blk) else "absent"
				if not (st in ESC):
					bad = "logged block %d not playable: %s" % [blk, st]
					problems.append("%s attempt %d at %d ms: %s" % [id, a["n"], t, bad])
					a["events"].append("%6.2fs m %d INVALID (%s)" % [t / 1000.0, blk, st])
					continue
				var opts := options(m)
				var nwin := opts.filter(func(o): return o["win"] == 1).size()
				var chosen: Dictionary = opts.filter(func(o): return o["id"] == blk)[0]
				if not lost and nwin >= 1 and nwin < opts.size():
					# A consequential choice from a winnable position: the depth of
					# every losing alternative (how long it would hide) and what was chosen.
					var lds := []
					for o in opts:
						if o["win"] == 0:
							var sn2 := m.snapshot()
							apply(m, int(o["id"]), str(o["st"]))
							lds.append({"id": o["id"], "depth": depth_of(m)})
							m.restore(sn2)
					a["choice_points"].append({"ms": t, "move": a["moves"] + 1, "legal": opts.size(), "winning": nwin,
						"losing": lds, "chosen": blk, "chosen_won": chosen["win"] == 1})
				var before := snap(m)
				var word := cell(m, blk)
				history.append(m.snapshot())
				apply(m, blk, st)
				var after := snap(m)
				var ev := mech_events(before, after)
				var logged: Dictionary = e[3] if e.size() > 3 else {}
				var inferred := infer_tap(before, after)
				var ev_ok := JSON.stringify(_sorted(ev)) == JSON.stringify(_sorted(logged))
				var id_ok := inferred == blk or (inferred < 0 and st == "ram")
				if not ev_ok:
					problems.append("%s attempt %d at %d ms: effects engine %s vs log %s" % [id, a["n"], t, str(ev), str(logged)])
				if not id_ok:
					problems.append("%s attempt %d at %d ms: board diff gives block %d, log %d" % [id, a["n"], t, inferred, blk])
				for kk in ev:
					mech_tot[kk] = int(mech_tot.get(kk, 0)) + int(ev[kk])
				if st == "ok":
					escapes_logged += 1
					a["escapes"] += 1
				else:
					a[st + "s"] = int(a.get(st + "s", 0)) + 1
				a["moves"] += 1
				var w := winnable(m)
				var cleared := total - m.block_count()
				a["max_cleared"] = maxi(int(a["max_cleared"]), cleared)
				max_cleared = maxi(max_cleared, cleared)
				var choice := nwin >= 1 and nwin < opts.size()
				if choice and w == 1:
					a["choices_won"] += 1
				if choice:
					a["choices"] += 1
				var tag := ""
				if w == 0 and not lost:
					lost = true
					a["lost_at_move"] = a["moves"]
					a["lost_ms"] = t
					a["losing_move"] = word + ("" if st == "ok" else " " + st)
					a["lost_options"] = "%d legal, %d winning" % [opts.size(), nwin]
					a["trap_depth"] = longest(m)
					var alt := opts.filter(func(o): return o["win"] == 1).map(func(o): return o["id"])
					a["winning_alternatives"] = alt
					tag = "  <== LOST (%d of %d legal moves still won: %s); play can go on up to %d more moves" % [nwin, opts.size(), str(alt), a["trap_depth"]]
				elif w == 0:
					a["after_loss"] += 1
					tag = "  (lost)"
				elif w == -1:
					tag = "  (solver limit)"
				a["path"].append(blk)
				a["events"].append("%6.2fs m %s%s -> cleared %d/%d, options %d legal / %d winning%s%s" % [t / 1000.0, word,
					"" if st == "ok" else " [" + st + "]", cleared, total, opts.size(), nwin, "  CHOICE" if choice else "", tag])
			"u":
				if history.is_empty():
					problems.append("%s attempt %d at %d ms: UNDO with no move to undo" % [id, a["n"], t])
					continue
				undos_att += 1
				if undos_att > 3:
					problems.append("%s attempt %d at %d ms: a 4th UNDO in one attempt (allowance 3)" % [id, a["n"], t])
				m.restore(history.pop_back())
				a["undos"] += 1
				if a["path"].size() > 0:
					a["path"].pop_back()
				var w := winnable(m)
				var was_lost := lost
				if w == 1 and lost:
					lost = false
					a["recovered_by_undo"] += 1
				a["events"].append("%6.2fs UNDO -> cleared %d/%d%s" % [t / 1000.0, total - m.block_count(), total,
					" (winnable again)" if was_lost and w == 1 else (" (still lost)" if w == 0 else "")])
			"b":
				var st := m.move_state(blk) if m.blocks.has(blk) else "absent"
				var okb := not (st in ESC)
				if not okb:
					problems.append("%s attempt %d at %d ms: blocked tap on %d but it is playable (%s)" % [id, a["n"], t, blk, st])
				a["blocked"] += 1
				if lost:
					a["blocked_after_loss"] += 1
				a["events"].append("%6.2fs blocked tap %s (%s)%s" % [t / 1000.0, cell(m, blk), st, "  [in a lost position]" if lost else ""])
			"a":
				var arm: bool = m.blocks.has(blk) and m.blocks[blk].armored
				if not arm:
					problems.append("%s attempt %d at %d ms: armored tap on %d, not armored" % [id, a["n"], t, blk])
				a["events"].append("%6.2fs armored tap %s" % [t / 1000.0, cell(m, blk)])
			"r":
				a["end_ms"] = t
				a["end"] = "RESTART"
				a["cleared_end"] = total - m.block_count()
				a["lost_at_end"] = lost
				attempts.append(a)
				a = _new_att(attempts.size() + 1, t)
				m.restore(start)
				history.clear()
				undos_att = 0
				lost = false
				bad = ""
			"t":
				a["events"].append("%6.2fs TIME UP" % [t / 1000.0])
			"z":
				pass
	a["end_ms"] = int(meta["elapsed"])
	a["cleared_end"] = total - m.block_count()
	a["lost_at_end"] = lost
	if str(meta["completed"]) == "true":
		# The page logs from a per-frame poll; the solving escape ends the
		# puzzle before the next poll, so the last move is never logged.
		var left := m.block_count()
		var last := ""
		if left == 1:
			var lid: int = m.blocks.keys()[0]
			last = m.move_state(lid)
			a["unlogged_final"] = cell(m, lid) + " [" + last + "]"
		var fin_ok := left == 1 and last == "ok"
		checks.append(["completed: exactly one escapable block left after the log (the unlogged solving escape)", fin_ok])
		if fin_ok:
			escapes_logged += 1
			a["escapes"] += 1
			a["cleared_end"] = total
			a["max_cleared"] = total
			max_cleared = total
		a["end"] = "SOLVED"
	else:
		a["end"] = "TIME UP"
	attempts.append(a)
	checks.append(["moves (escapes incl. unlogged final) %d == supplied %s" % [escapes_logged, meta["moves"]], escapes_logged == int(meta["moves"])])
	checks.append(["max cleared %d == supplied %s" % [max_cleared, meta["max_cleared"]], max_cleared == int(meta["max_cleared"])])
	if meta.has("cleared_end"):
		checks.append(["cleared at end %d == supplied %s" % [a["cleared_end"], meta["cleared_end"]], int(a["cleared_end"]) == int(meta["cleared_end"])])
	var mech_sup := {}
	for kv in str(meta["mech"]).split(","):
		var p := kv.split(":")
		mech_sup[p[0]] = int(p[1])
	checks.append(["effects %s == supplied %s" % [str(_sorted(mech_tot)), str(_sorted(mech_sup))], JSON.stringify(_sorted(mech_tot)) == JSON.stringify(_sorted(mech_sup))])
	checks.append(["every logged event consistent with the engine", problems.is_empty()])
	for c in checks:
		print("  [%s] %s" % ["OK" if c[1] else "MISMATCH", c[0]])
	for p in problems:
		print("  PROBLEM: " + p)
	# Per-attempt summary + the moves repeated from the previous attempts.
	for i in attempts.size():
		var x: Dictionary = attempts[i]
		var pre := 0
		if i > 0:
			var prev: Array = attempts[i - 1]["path"]
			while pre < mini(prev.size(), x["path"].size()) and prev[pre] == x["path"][pre]:
				pre += 1
		x["same_opening_as_previous"] = pre
		var sp := 0
		while sp < mini(sol_ids.size(), x["path"].size()) and sol_ids[sp] == x["path"][sp]:
			sp += 1
		x["solver_prefix"] = sp
		print("  attempt %d [%5.1f-%5.1f s, %4.1f s] %s: %d moves (%d escapes), %d undo, %d blocked; cleared max %d, at end %d; %s; same opening as previous: %d; solver-solution prefix: %d; consequential choices met %d (won %d)" % [
			x["n"], x["start_ms"] / 1000.0, x["end_ms"] / 1000.0, (x["end_ms"] - x["start_ms"]) / 1000.0, x["end"], x["moves"], x["escapes"], x["undos"], x["blocked"],
			x["max_cleared"], x["cleared_end"],
			("LOST at move %d (%.1f s) by %s [%s]; trap depth %d; %d more moves in the lost position" % [x["lost_at_move"], x["lost_ms"] / 1000.0, x["losing_move"], x["lost_options"], x["trap_depth"], x["after_loss"]]) if x["lost_at_move"] > 0 else "never lost",
			pre, sp, x["choices"], x["choices_won"]])
		if args.has("verbose"):
			for ev in x["events"]:
				print("      " + ev)
	return {"meta": meta, "checks": checks, "problems": problems, "solution": sol_ids, "attempts": attempts, "pieces": total}


func _new_att(n: int, t0: int) -> Dictionary:
	return {"n": n, "start_ms": t0, "end_ms": -1, "end": "", "moves": 0, "escapes": 0, "undos": 0, "blocked": 0, "blocked_after_loss": 0,
		"max_cleared": 0, "cleared_end": 0, "lost_at_move": -1, "lost_ms": -1, "losing_move": "", "lost_options": "", "trap_depth": 0,
		"after_loss": 0, "recovered_by_undo": 0, "choices": 0, "choices_won": 0, "path": [], "events": [], "winning_alternatives": [], "choice_points": []}


static func _sorted(d: Dictionary) -> Dictionary:
	var o := {}
	var ks: Array = d.keys()
	ks.sort()
	for k in ks:
		o[k] = int(d[k])
	return o


# --- Copied VERBATIM from scripts/social/vh_human_test.gd (VhHumanTest.mech_events / infer_tap):
# that class cannot compile in --script mode (autoloads). Keep in sync with the page.
static func mech_events(before: Dictionary, after: Dictionary) -> Dictionary:
	var ev := {}
	for id in before:
		var b: Array = before[id]
		if not after.has(id):
			if b[4] == BlockData.Kind.GATE:
				ev["gate"] = int(ev.get("gate", 0)) + 1
			continue
		var a: Array = after[id]
		if b[4] != BlockData.Kind.CRATE and b[0] != a[0]:
			ev["pull"] = int(ev.get("pull", 0)) + 1
		if b[1] != a[1] and b[2] == a[2]:
			var k := "turn" if b[4] == BlockData.Kind.SPINNER else "flip"
			ev[k] = int(ev.get(k, 0)) + 1
		if b[3] and not a[3]:
			ev["ram"] = int(ev.get("ram", 0)) + 1
	return ev


## The block a move was made with, from the board before / after: the
## block that escaped; else the Sequence block that advanced; else (a push
## or a ram) the block whose lane runs straight into the crate that moved
## or the shell that broke. -1 if none can be told.
static func infer_tap(before: Dictionary, after: Dictionary) -> int:
	for id in before:
		var kind: int = before[id][4]
		if not after.has(id) and kind != BlockData.Kind.CRATE and kind != BlockData.Kind.GATE:
			return id
	var target := Vector2i(-1, -1)
	var push := Vector2i.ZERO  # how the crate moved: the pusher points this way
	for id in after:
		if not before.has(id):
			continue
		if before[id][2] == 1 and after[id][2] == 2:
			return id
		if before[id][4] == BlockData.Kind.CRATE and before[id][0] != after[id][0]:
			target = before[id][0]
			push = after[id][0] - before[id][0]
		if before[id][3] and not after[id][3]:
			target = before[id][0]
	if target.x < 0:
		return -1
	var at := {}
	for id in before:
		at[before[id][0]] = id
	var found := []
	for id in before:
		var kind: int = before[id][4]
		if kind == BlockData.Kind.CRATE or kind == BlockData.Kind.GATE:
			continue
		var step := Direction.step(before[id][1])
		if push != Vector2i.ZERO and step != push:
			continue
		var c: Vector2i = before[id][0] + step
		for n in 20:
			if at.has(c):
				if c == target:
					found.append(id)
				break
			c += step
	# A ram that two blocks could have made can't be told apart: -1.
	return found[0] if found.size() == 1 else -1


## Pilot &bench=1: the recipient's check (a fresh Solver, the full
## 60000-node limit) and SHOW A MOVE on every board, timed on this device.
## Published as window.chainEscapeVhBench (and kept in bench_results).
