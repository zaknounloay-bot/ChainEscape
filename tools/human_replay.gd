extends SceneTree
## Human behaviour analysis (development only): replays the move logs of a
## blind test's COPY RESULTS JSON on the real game rules (BoardModel, the
## board exactly as the page loaded it) and reconstructs every attempt:
## the moves in words, after each move whether the board can still be
## cleared (the Solver, exhaustively within its limit), the move that lost
## the attempt and how long play went on after it, UNDO, SHOW A MOVE (what
## it highlighted, recomputed - it is deterministic), RESTART, blocked taps,
## GIVE UP. Then, per puzzle, the mistakes repeated across attempts and the
## progress made (winnable moves before the first losing one).
##   godot --headless --path . --script res://tools/human_replay.gd -- --results=results.json [--id=E2] [--json=out.json]
## Log entries (scripts/social/vh_human_test.gd): [ms, kind, block(, events)]
## with kind m move, u UNDO, h SHOW A MOVE, x HAMMER, r RESTART, b blocked
## tap, g GIVE UP. Not in the log by design: SHOW A MOVE presses that change
## nothing (a lost position - "try Undo" - or none left), so those are
## invisible here. A move whose block could not be told (-1) stops the
## replay of that attempt (reported, never guessed).
## ?ptest11 (one SHOW A MOVE per puzzle): EVERY press is logged, with its
## outcome ([ms, "h", block, {"r": shown / lost / stuck / none, "att"}]),
## and "o" = the page was reopened (the board started again, like RESTART).
## Here the replay also says whether each press came from a position that
## could still be cleared, and per puzzle: time and attempt of the first
## SHOW A MOVE, the furthest winnable progress before it (unaided), the
## losing decisions repeated across attempts and the progress per attempt.

const EVENTS6 := preload("res://tools/extreme6_events.gd")
## Each blind test's board file (as in scripts/social/vh_human_test.gd TESTS).
const DATA := {"xtest5": "res://data/dev/extreme5.json", "xtest6": "res://data/dev/extreme6.json", "xtest7": "res://data/dev/extreme7.json",
	"vhval3": "res://data/dev/vh_validation3.json", "xtest8": "res://data/dev/extreme8.json", "vhtest4": "res://data/dev/vh_pilot4.json",
	"ptest11": "res://data/dev/extreme11.json"}

var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var res = JSON.parse_string(FileAccess.get_file_as_string(str(args["results"])))
	var test: String = res.get("test", "")
	var data_path: String = DATA[test]
	var boards := {}
	for b in JSON.parse_string(FileAccess.get_file_as_string(data_path))["boards"]:
		boards[str(b["id"])] = b
	var out := []
	for r in res["results"]:
		if args.has("id") and str(r["id"]) != str(args["id"]):
			continue
		out.append(replay(boards[str(r["id"])], r))
	if args.has("json"):
		var f := FileAccess.open(str(args["json"]), FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	quit()


func _cell(m: BoardModel, id: int) -> String:
	var b: BlockData = m.blocks.get(id)
	if b == null:
		return "#%d" % id
	return "%s%s at R%dC%d" % [b.color.substr(0, 1).to_upper(), ["^", "v", "<", ">"][b.direction], b.cell.y + 1, b.cell.x + 1]


func _winnable(m: BoardModel) -> int:
	if m.is_empty():
		return 1
	var s := Solver.from_model(m)
	s.node_limit = Solver.DEFAULT_NODE_LIMIT
	var sol := s.solve()
	if s.aborted:
		return -1  # unknown (over the recipient's limit)
	return 1 if not sol.is_empty() else 0


## Longest run of legal moves from a lost position (how long play can go on).
func _longest(m: BoardModel, depth: int = 0) -> int:
	if depth > 30:
		return 0
	var best := 0
	for id in m.blocks.keys():
		var st := m.move_state(id)
		if not (st in ["ok", "ram", "push", "advance"]):
			continue
		var snap := m.snapshot()
		_apply(m, id, st)
		best = maxi(best, 1 + _longest(m, depth + 1))
		m.restore(snap)
	return best


func _apply(m: BoardModel, id: int, st: String) -> void:
	match st:
		"ok":
			m.remove(id)
		"ram":
			m.ram(id)
		"push":
			m.push(id)
		"advance":
			m.advance(id)


func replay(board: Dictionary, r: Dictionary) -> Dictionary:
	var def := PuzzleDefinition.from_dict(board["puzzle"])
	var level := def.to_level()
	var m := EVENTS6.model_of(level)
	var start := m.snapshot()
	var history: Array = []
	var attempts := []
	var cur := {"moves": [], "lost_at": -1, "lost_move": "", "after_loss": 0, "hints": [], "undos": 0, "blocked": 0, "end": "", "max_cleared": 0}
	var lost := false
	var stopped := ""
	var hint_used := false
	var first_hint := {}
	var unaided_best := 0  # most winnable moves before SHOW A MOVE was first used
	var presses := []
	print("\n=== %s (%s) rating %s, %s, %.1f s, restarts %s, SHOW A MOVE %s, undos %s" % [r["id"], r.get("variant", ""), r.get("rating", ""),
		"solved" if r.get("completed", false) else "NOT solved", float(r.get("time_ms", 0)) / 1000.0, r.get("restarts", 0), r.get("show_a_move", 0), r.get("undos", 0)])
	for e in r.get("log", []):
		var kind: String = e[1]
		var t := "%5.1fs" % (float(e[0]) / 1000.0)
		match kind:
			"m":
				var id := int(e[2])
				if id < 0 or not m.blocks.has(id):
					stopped = "move %d: block not identified in the log" % cur["moves"].size()
					cur["moves"].append("%s ?" % t)
					continue
				var st := m.move_state(id)
				if not (st in ["ok", "ram", "push", "advance"]):
					stopped = "move %d: logged block %s not playable (%s)" % [cur["moves"].size(), _cell(m, id), st]
					continue
				var word := _cell(m, id) + ("" if st == "ok" else " " + st)
				history.append(m.snapshot())
				_apply(m, id, st)
				var w := _winnable(m)
				var tag := "" if w == 1 else (" LOST" if w == 0 else " ?")
				if w == 0 and not lost:
					lost = true
					cur["lost_at"] = cur["moves"].size()
					cur["lost_move"] = word
					cur["delay"] = _longest(m)
				elif w == 0:
					cur["after_loss"] += 1
				cur["moves"].append("%s %s%s" % [t, word, tag])
				cur["max_cleared"] = maxi(int(cur["max_cleared"]), level.blocks.size() - m.blocks.size())
			"u":
				if not history.is_empty():
					m.restore(history.pop_back())
				cur["undos"] += 1
				var w := _winnable(m)
				if w == 1 and lost:
					lost = false
					cur["moves"].append("%s UNDO (winnable again)" % t)
				else:
					cur["moves"].append("%s UNDO%s" % [t, " (still lost)" if w == 0 else ""])
			"h":
				var s := Solver.from_model(m)
				var hid := s.recommend_move()
				var what := ("highlighted " + _cell(m, hid)) if hid >= 0 else "no winning move (try Undo)"
				if e.size() > 3 and typeof(e[3]) == TYPE_DICTIONARY:
					# One SHOW A MOVE per puzzle: the page's own outcome, and
					# whether the position could still be cleared.
					var outcome: String = e[3].get("r", "")
					var w := _winnable(m)
					var where := "winnable" if w == 1 else ("LOST" if w == 0 else "?")
					var said: String = {"shown": "highlighted " + _cell(m, hid), "lost": "spent: can't be cleared",
						"stuck": "no legal move (nothing spent)", "none": "refused: none left"}.get(outcome, outcome)
					what = "%s (%s position)" % [said, where]
					presses.append({"ms": int(e[0]), "outcome": outcome, "position": where, "attempt": attempts.size() + 1})
					if outcome in ["shown", "lost"] and not hint_used:
						hint_used = true
						first_hint = {"ms": int(e[0]), "attempt": attempts.size() + 1, "after_moves": cur["moves"].size()}
				cur["hints"].append("%s after %d moves: %s" % [t, cur["moves"].size(), what])
				cur["moves"].append("%s SHOW A MOVE -> %s" % [t, what])
			"b":
				cur["blocked"] += 1
			"r", "g", "o":
				cur["end"] = {"r": "restart", "g": "gave up", "o": "page reopened"}[kind]
				attempts.append(cur)
				cur = {"moves": [], "lost_at": -1, "lost_move": "", "after_loss": 0, "hints": [], "undos": 0, "blocked": 0, "end": "", "max_cleared": 0}
				m.restore(start)
				history.clear()
				lost = false
			"x":
				cur["moves"].append("%s HAMMER (not replayed)" % t)
	if not cur["moves"].is_empty() or attempts.is_empty():
		cur["end"] = "solved" if m.is_empty() else ("open" if cur["end"] == "" else cur["end"])
		attempts.append(cur)
	var firsts := {}
	for i in attempts.size():
		var a: Dictionary = attempts[i]
		var won_before_loss: int = a["lost_at"] if a["lost_at"] >= 0 else a["moves"].size()
		print("  attempt %d (%s): %d moves, %s, %d blocked taps, %d undo, hints %s" % [i + 1, a["end"], a["moves"].size(),
			("lost on move %d by %s, play went on %d more moves (could have gone on up to %d)" % [a["lost_at"] + 1, a["lost_move"], a["after_loss"], a.get("delay", 0)]) if a["lost_at"] >= 0 else "never lost",
			a["blocked"], a["undos"], str(a["hints"])])
		if args.has("verbose"):
			for mv in a["moves"]:
				print("      " + mv)
		if a["lost_move"] != "":
			firsts[a["lost_move"]] = firsts.get(a["lost_move"], []) + [i + 1]
		a["winnable_prefix"] = won_before_loss
		if first_hint.is_empty() or i + 1 < int(first_hint["attempt"]):
			unaided_best = maxi(unaided_best, won_before_loss)
		elif i + 1 == int(first_hint["attempt"]):
			unaided_best = maxi(unaided_best, mini(won_before_loss, int(first_hint["after_moves"])))
	print("  losing moves repeated across attempts: %s" % str(firsts))
	var progress := attempts.map(func(a): return a["winnable_prefix"])
	print("  winnable moves before the first losing one, per attempt (learning): %s" % str(progress))
	if not presses.is_empty():
		print("  SHOW A MOVE presses: %s" % str(presses))
		print("  first SHOW A MOVE: %s; furthest unaided progress: %d winnable moves" % [
			("%.1f s, attempt %d, after %d moves" % [float(first_hint["ms"]) / 1000.0, first_hint["attempt"], first_hint["after_moves"]]) if not first_hint.is_empty() else "never used", unaided_best])
	if stopped != "":
		print("  NOTE: " + stopped)
	return {"id": r["id"], "attempts": attempts, "repeated_losing_moves": firsts, "stopped": stopped, "progress": progress,
		"show_a_move_presses": presses, "first_show_a_move": first_hint, "unaided_best": unaided_best}
