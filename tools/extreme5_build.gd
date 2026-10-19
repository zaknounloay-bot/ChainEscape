extends "res://tools/vh_pilot4_build.gd"
## EXTREME PHASE 4 (development only, ?xtest5=1): five experimental
## candidates from EXISTING campaign mechanics, each testing one strategic
## difficulty hypothesis (docs/extreme5.md). Nothing here is production:
## the live Friend generator, the shared-challenge format, the backend, the
## difficulty labels and the 300 campaign levels are never touched.
##
## It reuses the Gate 0 builder (tools/vh_pilot4_build.gd, unchanged) for
## board construction and its technical acceptance rules unchanged (the
## recipient's 60000-node limit, the 20000-node working budget, SHOW A MOVE
## on every state and after every losing move, the 40 ms native-desktop
## mobile budget, every mechanic must matter, random tapper <= 8 %), and
## replaces the SEARCH GOAL: Gate 0 optimised solver measures that people
## turned out to beat easily; here the goal is that people's likely rules of
## thumb fail (tools/extreme_probe.gd):
##   - a trial-and-error player with memory, ordering its tries by any one
##     rule of thumb and looking 2 moves ahead, still hits >= 3 dead ends
##     (the luckiest rule counts),
##   - no one-attempt greedy player (safe-first, 2 / 4-move lookahead,
##     fewest spinner turns, most moves kept open) wins more than 5 %,
##   - plausible losing moves exist whose failure shows only later,
##   - the board stays readable (<= 7x7, <= 16 pieces) and the solution
##     short (<= 22 taps): no difficulty from length or repetition.
##
##   godot --headless --path . --script res://tools/extreme5_build.gd -- --recipe=E1_longrange --part=/tmp/e1.json [--seed=1] [--tries=12] [--climb=160] [--starts=24] [--seeds=maps.json]
##   godot --headless --path . --script res://tools/extreme5_build.gd -- --merge=/tmp/e1.json,... [--write]
##   godot --headless --path . --script res://tools/extreme5_build.gd -- --dossier=res://data/dev/extreme5.json

const PROBE := preload("res://tools/extreme_probe.gd")
const X_OUT := "res://data/dev/extreme5.json"
const X_NOTES := "res://data/dev/extreme5_notes.json"
const X_ASSIST := {"undo": 3, "show_a_move": 1, "hammer": 0}  # the live VERY HARD tools, for comparability
const MAX_PIECES := 16
const MAX_LEN := 22
const MIN_DEAD_ENDS := 3.0
const MAX_POLICY_WIN := 0.05
## Learner sessions stop after this many taps while climbing (speed only;
## acceptance runs them in full).
const CLIMB_TAPS := 4000
## The Gate 0 mobile budget (40 ms native desktop) measured once can pass or
## fail by chance on a noisy machine (cloud timings vary ~2x). Acceptance
## therefore repeats the whole measurement TIME_REPEATS times and requires
## EVERY run to be within the budget (stricter than Gate 0, never looser);
## the climb aims for SPEED_MARGIN of the budget so accepted boards have room.
const TIME_REPEATS := 5
const SPEED_MARGIN := 0.6
## Rules of thumb for the ordered learner (extreme_probe.gd).
const ORDERS := ["opportunist", "patient", "min_turn", "mobility"]
const POLICIES := ["safe", "look2", "look4", "min_turn", "mobility"]

## One recipe per hypothesis. Same schema as the Gate 0 recipes, plus
## "magnets". needs: families that must matter (Gate 0 impact rule) and be
## used in a real decision of the solution.
const X_RECIPES := {
	# E1 LONG-RANGE: colour locks open only when a whole colour has gone, so
	# an early escape decides what is possible much later; clockwise and
	# counter-clockwise spinners make every escape near them a commitment.
	"E1_longrange": {"group": "E1", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(13, 15),
		"spin": Vector2i(6, 8), "rules": {"cw": 0.5, "ccw": 0.5}, "locks": Vector2i(2, 3), "needs": ["spinner", "lock"], "use": []},
	# E2 CONTROL: a switch reverses its flip targets for good, and a chain
	# gate opens only after its links are gone: two remote systems whose
	# timing depends on each other and on the spinners.
	"E2_control": {"group": "E2", "sizes": [Vector2i(6, 6), Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(13, 15),
		"spin": Vector2i(4, 6), "rules": {"cw": 0.6, "ccw": 0.4}, "switches": Vector2i(1, 2), "flips": Vector2i(2, 3),
		"gates": Vector2i(1, 1), "links": Vector2i(2, 3), "needs": ["switch", "gate"], "use": ["switch"]},
	# E3 SPATIAL: one or two crates whose position decides later routes; few
	# pushes (no repetitive pushing), each one a commitment. At most two
	# spinners: the crate is the puzzle (and crates + many spinners are too
	# slow for SHOW A MOVE on a phone, Gate 0).
	"E3_crate": {"group": "E3", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(9, 12),
		"spin": Vector2i(1, 2), "rules": {"cw": 1.0}, "crates": Vector2i(1, 2), "needs": ["crate"], "use": ["push"],
		"max_pushes": 4},
	# E4 ROTATION + ORDER: Sequence blocks turn their spinner neighbours when
	# they advance (without leaving), mixed spinner rules: what turns when,
	# and in which order, must be reasoned about together.
	"E4_rotseq": {"group": "E4", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(12, 15),
		"spin": Vector2i(6, 8), "rules": {"cw": 0.4, "ccw": 0.35, "alt": 0.25}, "seq": Vector2i(2, 3),
		"needs": ["spinner", "sequence"], "use": ["advance"]},
	# E5 PULL: magnets drag the block behind them into the cell they leave -
	# the board's geometry changes, so lanes that are blocked now open
	# later (and the reverse). Clockwise spinners only.
	"E5_magnet": {"group": "E5", "sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(13, 15),
		"spin": Vector2i(5, 7), "rules": {"cw": 1.0}, "magnets": Vector2i(2, 3), "needs": ["spinner"], "use": ["magnet"]},
}

var x_args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	rng.seed = int(x_args.get("seed", "1"))
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	_load_known()
	if x_args.has("merge"):
		_x_merge(str(x_args["merge"]).split(","), x_args.has("write"))
	elif x_args.has("recipe"):
		var name := str(x_args["recipe"])
		var found := _x_build(name, int(x_args.get("tries", "12")), int(x_args.get("climb", "160")))
		print("%s: %d accepted" % [name, found.size()])
	elif x_args.has("dossier"):
		_dossier(str(x_args["dossier"]))
	else:
		print("nothing to do: --recipe=NAME | --merge=a,b,... | --dossier=file")
	quit()


## Known boards: the 300 campaign levels and every development board file
## (including the Gate 0 pilot), except this test's own file.
func _load_known() -> void:
	for n in range(1, 301):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%02d.json" % n))
		known_keys[canonical(Array(d["map"]))] = "campaign L%d" % n
	var stack := ["res://data/dev"]
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir.path_join(sub))
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json") and not f.begins_with("extreme5"):
				_collect_maps(JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(f))), dir.path_join(f))
	print("known boards: %d" % known_keys.size())


func mechanics(map: Array) -> Array:
	var out := CANON.mechanics(map)
	if _magnets_in(map) > 0:
		out.append("magnet")
	return out


## Magnet tokens: a plain arrow with the "*" suffix (not a pattern spinner).
static func _magnets_in(map: Array) -> int:
	var n := 0
	for row in map:
		for t in String(row).split(" ", false):
			if t.length() >= 3 and t.ends_with("*") and not t.contains("@"):
				n += 1
	return n


func _solver(level: LevelData) -> Solver:
	return Solver.from_model(model_of(level))


# --- Search ----------------------------------------------------------------------------------

func _x_build(name: String, tries: int, climb: int) -> Array:
	var spec: Dictionary = X_RECIPES[name]
	var found := []
	var near := []  # best rejected boards: [score, why, map]
	var seen := {}
	var t0 := Time.get_ticks_msec()
	var part := str(x_args.get("part", ""))
	var seeds := _seed_maps()
	for t in tries:
		var cur: Array
		var cur_e: Dictionary
		if t < seeds.size():
			# Hybrid: a hand-designed (or earlier near-miss) board to polish.
			cur = seeds[t]
			cur_e = _x_eval(cur, spec)
			if not cur_e["solvable"]:
				print("%s seed %d: not solvable, skipped" % [name, t])
				continue
		else:
			# The best of several random boards, so the climb starts somewhere.
			cur = []
			cur_e = {"score": -1e9}
			for k in int(x_args.get("starts", "24")):
				var m := _x_random_valid(spec)
				if m.is_empty():
					continue
				var e0 := _x_eval(m, spec)
				if e0["score"] > cur_e["score"]:
					cur = m
					cur_e = e0
			if cur.is_empty():
				continue
		var best_map := cur
		var best_e := cur_e
		var stale := 0
		for step in climb:
			var cand := _mutate(cur, spec)
			if stale > 40 and stale % 40 == 1:
				# Stuck: jump from the best board so far by a few changes.
				cand = best_map
				for k in 3:
					cand = _mutate(cand, spec)
			var e := _x_eval(cand, spec)
			if e["score"] >= cur_e["score"] or (stale > 40 and stale % 40 == 1):
				stale = 0 if e["score"] > best_e["score"] else stale + 1
				cur = cand
				cur_e = e
			else:
				stale += 1
			if cur_e["score"] > best_e["score"] or (cur_e.get("goal_ok", false) and not best_e.get("goal_ok", false)):
				best_map = cur
				best_e = cur_e
			if stale > 160:
				break
		cur = best_map
		cur_e = best_e
		if not cur_e.get("goal_ok", false):
			print("%s try %d: rejected in climb (%s) score %.1f" % [name, t, cur_e.get("why", "?"), cur_e["score"]])
			near.append([snappedf(cur_e["score"], 0.1), cur_e.get("why", ""), cur])
		else:
			var key := canonical(cur)
			if seen.has(key) or known_keys.has(key):
				print("%s try %d: duplicate" % [name, t])
			else:
				var rec := _x_report(name, "generated (%s, seed %d, try %d)" % [name, rng.seed, t], cur)
				if not rec["ok"]:
					print("%s try %d: rejected at acceptance: %s" % [name, t, rec["why"]])
					near.append([snappedf(cur_e["score"], 0.1), "acceptance: " + rec["why"], cur])
				else:
					seen[key] = true
					found.append(rec)
					print("%s try %d: ACCEPTED x-score %.1f (%d found, %ds)" % [name, t, rec["x_score"], found.size(), (Time.get_ticks_msec() - t0) / 1000])
		near.sort_custom(func(a, b): return a[0] > b[0])
		near = near.slice(0, 6)
		if part != "":
			_save_part_x(part, found, near)
	found.sort_custom(func(a, b): return a["x_score"] > b["x_score"])
	return found


## Saved after every try (a restarted container keeps what was found).
func _save_part_x(path: String, boards: Array, near: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"boards": boards, "near": near}, "  "))
	f.close()


## --seeds=file.json: {"maps": [[row, ...], ...]} boards to start from.
func _seed_maps() -> Array:
	if not x_args.has("seeds"):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["seeds"])))
	return d.get("maps", []) if typeof(d) == TYPE_DICTIONARY else []


func _x_random_valid(spec: Dictionary) -> Array:
	for i in 300:
		var map := _random_board(spec)
		var nm := _pick(spec.get("magnets", Vector2i.ZERO))
		if nm > 0:
			map = _add_magnets(map, nm)
		var e := _x_eval(map, spec, true)
		if e["solvable"]:
			return map
	return []


## Turns `n` plain arrows (colour + arrow, no modifier) into magnets.
func _add_magnets(map: Array, n: int) -> Array:
	var g := _grid(map)
	var plain := []
	for r in g.size():
		for c in g[r].size():
			var t: String = g[r][c]
			if t.length() == 2 and t[0] in COLORS:
				plain.append(Vector2i(c, r))
	plain.shuffle()
	for i in mini(n, plain.size()):
		var at: Vector2i = plain[i]
		g[at.y][at.x] += "*"
	return _rows(g)


## Climbing evaluation. `quick` = solvability only.
func _x_eval(map: Array, spec: Dictionary, quick: bool = false) -> Dictionary:
	var e := {"solvable": false, "score": -1000.0, "goal_ok": false, "why": ""}
	var level := parse(map)
	if level == null or level.blocks.is_empty() or not _intact(map, level):
		e["why"] = "parse"
		return e
	if level.blocks.filter(func(b): return b.magnet).size() != _magnets_in(map):
		e["why"] = "magnet dropped"
		return e
	var m := LevelAnalysis.analyze(level, false)
	if m.get("aborted", false) or not m["solvable"]:
		e["why"] = "unsolvable/aborted"
		return e
	e["solvable"] = true
	if quick:
		return e
	var s := _solver(level)
	var why := []
	var pol := 0.0
	for k in POLICIES:
		pol = maxf(pol, PROBE.policy_win(s, k, 30 if k == "look4" else 50, 21))
	var best := 99.0
	var best_mean := 99.0
	for o in _orders(s):
		var r := PROBE.learner_stats(s, 4, 2, o, CLIMB_TAPS)
		best = minf(best, r["dead_ends_med"])
		best_mean = minf(best_mean, r["dead_ends_mean"])
	var blind: float = PROBE.learner_stats(s, 4, 0, "random", CLIMB_TAPS)["dead_ends_mean"]
	var sol_len: int = m["solution_length"]
	var pieces := _pieces(map)
	# Means (not medians) and the decision counts keep the score smooth, so
	# the climb has a direction even among easy boards.
	var sc: float = 10.0 * minf(best_mean, 6.0) + 1.5 * minf(blind, 12.0) - 60.0 * maxf(pol - 0.02, 0.0) \
		+ 0.5 * m["decision_points"] + 0.5 * m["one_safe_steps"]
	if pieces > MAX_PIECES:
		sc -= 5.0 * (pieces - MAX_PIECES)
		why.append("pieces %d" % pieces)
	if sol_len > MAX_LEN or sol_len < 10:
		sc -= 4.0 * (maxi(sol_len - MAX_LEN, 0) + maxi(10 - sol_len, 0))
		why.append("len %d" % sol_len)
	var c := PROBE.choices(s)
	for u in spec["use"]:
		var k: Dictionary = c["mech"].get(u, {})
		if k.get("with_losing_alt", 0) < 1:
			sc -= 15.0
			why.append("%s never a real decision" % u)
	if spec.has("max_pushes") and m["pushes"] > spec["max_pushes"]:
		sc -= 6.0 * (m["pushes"] - spec["max_pushes"])
		why.append("pushes %d" % m["pushes"])
	if best < MIN_DEAD_ENDS:
		why.append("best rule %.1f dead ends" % best)
	if pol > MAX_POLICY_WIN:
		why.append("greedy wins %.2f" % pol)
	if why.is_empty():
		# Close to the goal: the Gate 0 impact rule (every advanced family
		# on the board must matter), checked only here because it is slow.
		var mi := LevelAnalysis.analyze(level, true)
		var imp := {"lock": mi["lock_impact"], "switch": mi["switch_impact"], "gate": mi["gate_impact"], "armor": mi["armor_impact"],
			"portal": mi["portal_impact"], "sequence": mi["sequence_impact"], "crate": mi["movable_impact"], "spinner": mi["spinner_impact"]}
		var present := {"lock": mi["locks"] > 0, "switch": mi["switches"] > 0, "gate": mi["gates"] > 0, "armor": mi["armored"] > 0,
			"portal": mi["portal_pairs"] > 0, "sequence": mi["sequence_blocks"] > 0, "crate": mi["crates"] > 0, "spinner": false}
		for n in spec["needs"]:
			present[n] = true
		for fam in present:
			if present[fam] and float(imp[fam]) < MIN_IMPACT:
				sc -= 10.0
				why.append("%s impact %.1f" % [fam, imp[fam]])
	if why.is_empty():
		# Close to the goal: the mobile time budget (Gate 0's rule, unchanged).
		var v := _verify_cost(level)
		var h := _hint_cost(level)
		var slowest := maxf(v["ms_desktop"], maxf(h["max_ms_desktop"], h["dead_max_ms_desktop"]))
		if slowest > MOBILE_MS_DESKTOP * SPEED_MARGIN or h["aborted"] or v["nodes"] > WORK_LIMIT:
			sc -= 10.0 + minf(slowest / 10.0, 30.0)
			why.append("slow (%.0f ms desktop)" % slowest)
	e["score"] = sc
	e["best"] = best
	e["goal_ok"] = why.is_empty()
	e["why"] = ", ".join(why)
	return e


func _orders(s: Solver) -> Array:
	return ORDERS + (["push_last"] if s._crate_n > 0 else [])


## Blocks, crates, gates and portal cells: what the player has to read.
static func _pieces(map: Array) -> int:
	var n := 0
	for row in map:
		for t in String(row).split(" ", false):
			if t != ".":
				n += 1
	return n


# --- Acceptance --------------------------------------------------------------------------------

## The Gate 0 technical record and acceptance (unchanged), plus the EXTREME
## measures and acceptance (larger samples than the climb).
func _x_report(recipe: String, source: String, map: Array) -> Dictionary:
	var spec: Dictionary = X_RECIPES[recipe]
	var rec := _report(spec["group"], recipe, source, map, spec["needs"])
	rec["mechanics"] = mechanics(map)
	if not rec.has("metrics"):
		rec["x_score"] = -1000.0
		return rec
	var level := parse(map)
	var s := _solver(level)
	var x := {}
	var ordered := {}
	var best := 99.0
	for o in _orders(s):
		var r := PROBE.learner_stats(s, 15, 2, o)
		ordered[o] = r
		best = minf(best, r["dead_ends_med"])
	x["ordered"] = ordered
	x["best_rule_dead_ends"] = best
	x["blind"] = PROBE.learner_stats(s, 30, 0)
	var pol := {}
	var worst := 0.0
	for k in POLICIES:
		pol[k] = PROBE.policy_win(s, k, 200 if k != "look4" else 120, 31)
		worst = maxf(worst, pol[k])
	x["policies"] = pol
	x["greedy_best"] = worst
	x["choices"] = PROBE.choices(s)
	var all_mis := PROBE.misleading(s, 60)
	var mis := all_mis.slice(0, 6)
	x["misleading"] = mis
	# Distinct moves (not the same move at several steps) that fail late.
	var late := {}
	for z in all_mis:
		if int(z[2]) >= 4:
			late[z[1]] = true
	x["late_misleading_moves"] = late.size()
	x["pieces"] = _pieces(map)
	x["magnets"] = _magnets_in(map)
	if x["magnets"] > 0:
		x["magnet_matters"] = _magnet_matters(map, best)
	rec["x"] = x
	var why := [] if rec["ok"] else [rec["why"]]
	var met: Dictionary = rec["metrics"]
	if x["pieces"] > MAX_PIECES:
		why.append("%d pieces (> %d)" % [x["pieces"], MAX_PIECES])
	if met["solution_length"] > MAX_LEN:
		why.append("solution %d taps (> %d)" % [met["solution_length"], MAX_LEN])
	if best < MIN_DEAD_ENDS:
		why.append("a rule of thumb solves it with %.1f dead ends (< %.0f)" % [best, MIN_DEAD_ENDS])
	if worst > MAX_POLICY_WIN:
		why.append("a greedy player wins %.0f%%" % (worst * 100))
	if late.size() < 2:
		why.append("fewer than 2 distinct plausible losing moves that fail late")
	for u in spec["use"]:
		if x["choices"]["mech"].get(u, {}).get("with_losing_alt", 0) < 1:
			why.append("%s is never a real decision" % u)
	if spec.has("max_pushes") and met["pushes"] > spec["max_pushes"]:
		why.append("%d pushes (> %d)" % [met["pushes"], spec["max_pushes"]])
	if x["magnets"] > 0 and not x["magnet_matters"]["matters"]:
		why.append("magnets do not matter")
	if why.is_empty():
		# The mobile budget in every one of TIME_REPEATS repeated measurements.
		var runs := []
		for i in TIME_REPEATS:
			var v := _verify_cost(level)
			var h := _hint_cost(level)
			runs.append(snappedf(maxf(v["ms_desktop"], maxf(h["max_ms_desktop"], h["dead_max_ms_desktop"])), 0.1))
		x["time_runs_ms"] = runs
		if runs.max() > MOBILE_MS_DESKTOP:
			why.append("over the mobile time budget in a repeated run (%s ms desktop > %.0f)" % [str(runs), MOBILE_MS_DESKTOP])
	rec["ok"] = why.is_empty()
	rec["why"] = "; ".join(why)
	rec["x_score"] = snappedf(10.0 * minf(best, 8.0) + 1.5 * minf(float(x["blind"]["dead_ends_med"]), 15.0) - 100.0 * worst, 0.1)
	return rec


## The same board with every magnet a plain arrow: unsolvable (essential),
## or how many fewer dead ends the luckiest rule of thumb hits.
func _magnet_matters(map: Array, best: float) -> Dictionary:
	var plain := []
	for row in map:
		var o := []
		for t in String(row).split(" ", false):
			o.append(t.trim_suffix("*") if t.length() >= 3 and t.ends_with("*") and not t.contains("@") else t)
		plain.append(" ".join(o))
	var level := parse(plain)
	var m := LevelAnalysis.analyze(level, false)
	if not m["solvable"]:
		return {"matters": true, "plain": "unsolvable"}
	var s := _solver(level)
	var b := 99.0
	for o in ORDERS:
		b = minf(b, PROBE.learner_stats(s, 15, 2, o)["dead_ends_med"])
	return {"matters": best - b >= 2.0, "plain": "solvable", "plain_best_rule_dead_ends": b}


# --- Merge -----------------------------------------------------------------------------------

## Re-checks every candidate with this code, keeps the best of each recipe
## and writes the board file (neutral ids T1-T5 in a seeded random order).
func _x_merge(paths: Array, write: bool) -> void:
	var by := {}
	for p in paths:
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		for b in d["boards"]:
			by.get_or_add(b["recipe"], []).append(b)
	var chosen := []
	var keys := {}
	for recipe in X_RECIPES:
		var cands: Array = by.get(recipe, [])
		var ok := []
		for b in cands:
			var key := canonical(Array(b["map"]))
			if known_keys.has(key) or keys.has(key):
				continue
			var rec := _x_report(recipe, b["source"], Array(b["map"]))
			if rec["ok"]:
				ok.append(rec)
			else:
				print("%s not kept: %s" % [recipe, rec["why"]])
		if ok.is_empty():
			print("SHORTFALL: no accepted %s board" % recipe)
			continue
		ok.sort_custom(func(a, b): return a["x_score"] > b["x_score"])
		keys[canonical(Array(ok[0]["map"]))] = true
		chosen.append(ok[0])
		print("%s: %d accepted, kept x-score %.1f" % [recipe, ok.size(), ok[0]["x_score"]])
	var r := RandomNumberGenerator.new()
	r.seed = 2027
	for i in range(chosen.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp = chosen[i]
		chosen[i] = chosen[j]
		chosen[j] = tmp
	# Hand-written explanations, by board fingerprint (data/dev/extreme5_notes.json).
	var notes = JSON.parse_string(FileAccess.get_file_as_string(X_NOTES)) if FileAccess.file_exists(X_NOTES) else {}
	var by_fp: Dictionary = notes.get("boards", {}) if typeof(notes) == TYPE_DICTIONARY else {}
	var boards := []
	for i in chosen.size():
		var c: Dictionary = chosen[i]
		var map: Array = c["map"]
		var lv := parse(map)
		boards.append({
			"id": "T%d" % (i + 1), "recipe": c["recipe"], "variant": c["group"], "source": c["source"],
			"first_level": _first_level(c["mechanics"]),
			"puzzle": {"format": "ce-puzzle", "v": 1, "rules": 1, "rows": lv.rows, "cols": lv.columns, "map": map},
			"mechanics": c["mechanics"], "fingerprint": c["fingerprint"], "canonical": c["canonical"],
			"verify": c["verify"], "metrics": c["metrics"], "x": c["x"], "accepted": true,
		})
		var note: Dictionary = by_fp.get(c["fingerprint"], {})
		for k in ["title", "why", "misleading_moves", "rules_defeated"]:
			if note.has(k):
				boards[-1][k] = note[k]
		if note.is_empty():
			print("%s has no written explanation yet (%s)" % [boards[-1]["id"], c["fingerprint"]])
		print("%s = %s  %s" % [boards[-1]["id"], c["recipe"], JSON.stringify(map)])
	if write:
		var f := FileAccess.open(X_OUT, FileAccess.WRITE)
		f.store_string(JSON.stringify({"format": "ce-extreme-proto", "v": 1, "test": "xtest5", "assist": X_ASSIST,
			"note": "Development only. EXTREME research prototypes (docs/extreme5.md); never shared, never production.",
			"boards": boards}, "  "))
		f.close()
		print("wrote %d boards to %s" % [boards.size(), X_OUT])


## The first campaign level that teaches every mechanic on the board.
func _first_level(mech: Array) -> int:
	var fl := 1
	for k in mech:
		fl = maxi(fl, 76 if k == "magnet" else int(FIRST_LEVEL.get(k, 1)))
	return fl


# --- Dossier (for the written explanations) -------------------------------------------------

## Solution and the most misleading moves of every board, in words.
func _dossier(path: String) -> void:
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	for b in d["boards"]:
		var map: Array = b["puzzle"]["map"] if b.has("puzzle") else b["map"]
		var level := parse(map)
		var s := _solver(level)
		print("\n== %s %s" % [b.get("id", "?"), b.get("recipe", "")])
		for r in map.size():
			print("   %d  %s" % [r, map[r]])
		var sol := s.solve_moves()
		var words := []
		for mv in sol:
			words.append(_say(s, mv))
			s._do(mv)
		for i in range(sol.size() - 1, -1, -1):
			s._undo_move(sol[i])
		print("solution: " + ", ".join(words))
		for z in PROBE.misleading(s, int(x_args.get("n", "6"))):
			var step: int = z[0]
			for i in step:
				s._do(sol[i])
			print("  misleading at step %d: %s (play goes on up to %d moves before stuck)" % [step + 1, _say(s, z[1]), z[2]])
			for i in range(step - 1, -1, -1):
				s._undo_move(sol[i])


func _say(s: Solver, mv: int) -> String:
	var id := mv & Solver.ID_MASK
	var cell: int = s._cell[id]
	var at := "r%dc%d" % [cell / s.columns, cell % s.columns]
	var arrow: String = ["^", "v", "<", ">"][s._dir[id]]  # Direction: UP, DOWN, LEFT, RIGHT
	if mv & Solver.PUSH:
		return "%s%s push" % [at, arrow]
	if mv & Solver.RAM:
		return "%s%s ram" % [at, arrow]
	if s._pending(id):
		return "%s%s advance" % [at, arrow]
	return "%s%s" % [at, arrow]
