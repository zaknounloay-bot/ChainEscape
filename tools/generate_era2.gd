extends SceneTree
## v0.6: builds the Second Era campaign slots (levels 101-200) with the
## LevelGenerator, one slot at a time, and writes res://levels/level_N.json.
##
##   godot --headless --path . --script res://tools/generate_era2.gd -- --from=101 --to=110 [--seed=1] [--rounds=6] [--write]
##
## Per slot: the Second Era plan picks the profile (LevelGenerator.era2_profile)
## and the difficulty band (target_difficulty). Candidates are built, solved,
## refined and rejected by the profile's rules (solvable, few obvious moves,
## depth, decisions, every mechanic must matter, mystery fair, not similar to
## any existing board). Among accepted candidates the one closest to the
## band's center wins. The slot then gets its name, the lesson text on
## introduction levels, and its Silver / Gold blocks from the Chapter plan.
## Without --write nothing is saved (dry run). tools/verify_levels.gd then
## re-checks the whole campaign.
##
## --repair (v0.6.1) keeps the existing level instead of starting over: it
## mutates it (the generator's own mutations) until every rule passes,
## including armor safety, staying as close as it can to --target (default:
## the level's current difficulty). Name, lesson text and Silver / Gold stay.

const NAMES := {
	11: ["First Switch", "Mirror Turn", "Flip Side", "Reverse Gear", "Two Ways", "Neon Hinge", "Glass Relay", "Backlight", "Switchback", "Prism Row"],
	12: ["Neon Loop", "Relay Garden", "Night Glass", "Toggle Tide", "Afterglow", "Pane Shift", "Signal Fade", "Glass Knot", "Lumen Lock", "Neon Crown"],
	13: ["First Gate", "Chain Link", "Steel Door", "Rivet Row", "Gatekeeper", "Twin Links", "Iron Latch", "Cog Line", "Hinge Works", "Foundry"],
	14: ["Piston", "Gear Train", "Pressure Plate", "Conveyor", "Bolt Cutter", "Crank Shaft", "Flywheel", "Turnstile", "Forge Gate", "Assembly"],
	15: ["Charge", "Arc Line", "Ion Field", "Surge", "Pulse Grid", "Static", "Current Knot", "Overload", "Capacitor", "Halfway Deep"],
	16: ["Plasma Veil", "Flux", "Coil", "Spark Gap", "Resonance", "Live Wire", "Discharge", "Field Lines", "Ionic Drift", "Plasma Core"],
	17: ["First Shell", "Hard Case", "Crystal Ward", "Cracked Glass", "Deep Shard", "Quartz Wall", "Ice Vault", "Geode", "Star Frost", "Void Prism"],
	18: ["Nebula", "Dark Matter", "Crystal Orbit", "Cold Star", "Shatter Point", "Event Horizon", "Frozen Relay", "Crystal Heart", "Deep Field", "Pulsar"],
	19: ["Elite Entry", "Gold Standard", "High Council", "Grand Design", "Crown Line", "Masterwork", "Apex", "Summit Key", "Champion", "Laurel"],
	20: ["Final Ascent", "Sovereign", "Last Light", "Paragon", "Zenith", "Grandmaster Path", "Pinnacle", "Legacy", "Eternal Chain", "The Grand Master"],
}

## Lesson text on the levels that introduce (or deepen) a mechanic.
const HINTS := {
	101: "New: SWITCH. When it escapes, every arrow with its mark reverses.",
	102: "Look for the matching mark: only those arrows turn around.",
	106: "Plan the switch: fire it when the reversed arrow helps you.",
	111: "Switches and spinners: think one step ahead.",
	121: "New: CHAIN GATE. It opens once every block with its chain mark escapes.",
	126: "The number on a gate shows how many linked blocks are left.",
	131: "Switches can be gate links too.",
	161: "New: ARMORED block. Launch another block into it to crack the shell.",
	166: "Cracking a shell is free - aim first, then clear.",
	171: "Switch, gate and shell: read every mark before you tap.",
	200: "The Grand Master. Every rule of both eras.",
}


func _initialize() -> void:
	var args := {"from": "101", "to": "200", "seed": "1", "rounds": "6", "attempts": "60", "budget": "420"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var write := "--write" in OS.get_cmdline_user_args()
	_target = float(args.get("target", "0"))
	# Fail fast on candidates the solver can't settle; the verifier re-checks
	# every written level with the full limit.
	Solver.default_limit = 20000
	var from := int(args["from"])
	var to := int(args["to"])
	var failed := []
	var repair := "--repair" in OS.get_cmdline_user_args()
	for n in range(from, to + 1):
		var level: LevelData
		if repair:
			level = _repair_slot(n, int(args["seed"]), int(args["budget"]))
		else:
			level = _build_slot(n, int(args["seed"]), int(args["rounds"]), int(args["attempts"]), int(args["budget"]))
		if level == null:
			failed.append(n)
			print("L%d: NO CANDIDATE" % n)
			continue
		if write and _target > 0.0 and args.get("keep_better", "1") == "1" and FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
			# Curation never makes a slot worse: keep the existing level if it
			# is already closer to the target.
			var old := LevelManager.parse_level(JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n)), n)
			var old_d: float = LevelAnalysis.analyze(old, false)["difficulty"]
			var new_d: float = _last_difficulty
			if absf(old_d - _target) <= absf(new_d - _target):
				print("L%d: kept the existing level (%.1f is closer to %.1f than %.1f)" % [n, old_d, _target, new_d])
				continue
		if write:
			var dest: String = (args["outdir"] + "/level_%d.json" % n) if args.has("outdir") else LevelManager.LEVEL_PATH % n
			var f := FileAccess.open(dest, FileAccess.WRITE)
			f.store_string(LevelManager.to_json_text(level))
			f.close()
	print("DONE %d-%d%s" % [from, to, (" FAILED: %s" % str(failed)) if not failed.is_empty() else ""])
	quit(0 if failed.is_empty() else 1)


var _target := 0.0
var _last_difficulty := 0.0


func _build_slot(n: int, seed: int, rounds: int, attempts: int, budget_s: int = 420) -> LevelData:
	var gen := LevelGenerator.new(seed * 1000 + n)
	# Time budget per slot: the best accepted candidate so far wins.
	gen.deadline_ms = Time.get_ticks_msec() + budget_s * 1000
	# Every other existing level is a "known board" (no repeats).
	var k := 1
	while FileAccess.file_exists(LevelManager.LEVEL_PATH % k):
		if k != n:
			var json = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % k))
			gen.known_boards.append(LevelManager.parse_level(json, k))
		k += 1
	var known := gen.known_boards.size()
	var p := LevelGenerator.profile_for_level(n)
	var band := LevelGenerator.target_difficulty(n)
	var center := (band.x + minf(band.y, band.x * 1.6)) * 0.5
	# Curation: --target=X steers one slot to an exact difficulty (used to
	# shape the Chapter curve after a first pass).
	if _target > 0.0:
		center = _target
		band = Vector2(_target - 3.5, _target + 3.5) if n != 200 else Vector2(_target, 999.0)
	var best: LevelData = null
	var best_m := {}
	var best_err := INF
	var t0 := Time.get_ticks_msec()
	for r in rounds:
		var level := gen.generate(p, attempts)
		if level == null:
			continue
		var m := gen.last_metrics
		gen.known_boards.resize(known)  # only compare against real levels
		var d: float = m["difficulty"]
		var err := 0.0 if d >= band.x and d <= band.y else minf(absf(d - band.x), absf(d - band.y)) * 10.0
		err += absf(d - center) * 0.1
		if err < best_err:
			best = level
			best_m = m
			best_err = err
		if d >= band.x and d <= band.y and r >= 1:
			break
	if best == null:
		print("L%d %s: rejected %s" % [n, p["name"], str(gen.reject_stats)])
		return null
	best.number = n
	var c := Chapters.chapter_of(n)
	best.name = NAMES.get(c, [])[(n - 1) % 10] if NAMES.has(c) else "Level %d" % n
	best.mystery = best_m.get("hidden", 0) > 0
	best.hint = HINTS.get(n, "")
	best.hint_finger = false
	# Silver / Gold from the Chapter plan (Master: 1 Silver + 2 Gold).
	var plan := LevelGenerator.chapter_plan(c)
	var sv := LevelGenerator.reward_slots(c, plan["silver_levels"], 0.5).count(n)
	var gd := LevelGenerator.reward_slots(c, plan["gold_levels"], 0.15).count(n)
	if n == 200:
		sv = 1
		gd = 2
	if c == 11:
		# The Switch lessons (101-105) stay focused: Chapter 11's rewards
		# live in its second half.
		sv = 1 if n in [107, 109, 110] else 0
		gd = 1 if n == 108 else 0
	gen.assign_reward_blocks(best, sv, gd)
	_last_difficulty = best_m["difficulty"]
	var in_band: bool = best_m["difficulty"] >= band.x and best_m["difficulty"] <= band.y
	print("L%d C%d %-16s %-17s %dx%d blk=%d spn=%d lck=%d hid=%d sw=%d gate=%d arm=%d start=%d dec=%d dep=%d diff=%.1f band=%.0f-%.0f%s rwd=%dS%dG %ds" % [
		n, c, best.name.left(16), p["name"], best.columns, best.rows, best_m["blocks"], best_m["spinners"], best_m["locks"], best_m["hidden"],
		best_m["switches"], best_m["gates"], best_m["armored"], best_m["start_moves"], best_m["decision_points"], best_m["depth"],
		best_m["difficulty"], band.x, minf(band.y, 999), "" if in_band else " OUT-OF-BAND", sv, gd, (Time.get_ticks_msec() - t0) / 1000])
	return best


## Hill-climbs from the existing level: first toward no stranded shell,
## then toward passing every rule, then toward the target difficulty.
func _repair_slot(n: int, seed: int, budget_s: int) -> LevelData:
	var gen := LevelGenerator.new(seed * 1000 + n)
	var k := 1
	while FileAccess.file_exists(LevelManager.LEVEL_PATH % k):
		if k != n:
			gen.known_boards.append(LevelManager.parse_level(JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % k)), k))
		k += 1
	var original := LevelManager.parse_level(JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n)), n)
	var p := LevelGenerator.profile_for_level(n)
	var t0 := Time.get_ticks_msec()
	var deadline := t0 + budget_s * 1000
	var om := gen.evaluate(original)
	var target := _target if _target > 0.0 else float(om["difficulty"])
	var current := original
	var cur_score := _repair_score(gen, original, om, p, target)
	var best: LevelData = null
	var best_m := {}
	var best_err := INF
	var tries := 0
	var stale := 0
	while Time.get_ticks_msec() < deadline:
		tries += 1
		stale += 1
		if stale > 1500 and best == null:
			# Stuck on a plateau: start over from the original level.
			current = original
			cur_score = _repair_score(gen, original, om, p, target)
			stale = 0
		var cand := gen._mutate(current, p)
		if cand == null:
			continue
		var m := gen.evaluate(cand)
		if not m["solvable"] or m["aborted"]:
			continue
		var sc := _repair_score(gen, cand, m, p, target)
		if sc < cur_score:
			stale = 0
		if sc <= cur_score:
			current = cand
			cur_score = sc
		if sc < 1000.0 and absf(m["difficulty"] - target) < best_err:
			best = cand
			best_m = m
			best_err = absf(m["difficulty"] - target)
			if best_err <= 1.0:
				break
	if best == null:
		print("L%d repair: no valid candidate in %d tries (best score %.1f) rules failing: %s" % [n, tries, cur_score, str(_repair_reasons)])
		return null
	best.number = n
	best.name = original.name
	best.hint = original.hint
	best.hint_finger = original.hint_finger
	best.mystery = best_m.get("hidden", 0) > 0
	_last_difficulty = best_m["difficulty"]
	print("L%d repair: %.1f -> %.1f (target %.1f), armor dead ends %d -> 0, blk=%d spn=%d arm=%d dec=%d dep=%d, %d tries %ds" % [
		n, om["difficulty"], best_m["difficulty"], target, om["armor_dead_ends"], best_m["blocks"], best_m["spinners"],
		best_m["armored"], best_m["decision_points"], best_m["depth"], tries, (Time.get_ticks_msec() - t0) / 1000])
	return best


var _repair_reasons := {}


## Lower is better. >= 1000 means a rule still fails.
func _repair_score(gen: LevelGenerator, level: LevelData, m: Dictionary, p: Dictionary, target: float) -> float:
	var err := absf(float(m["difficulty"]) - target)
	if m["armor_dead_ends"] > 0:
		return 100000.0 + 1000.0 * m["armor_dead_ends"] + err
	var reason := gen.rejection_reason(m, p, level)
	if reason != "":
		_repair_reasons[reason] = _repair_reasons.get(reason, 0) + 1
		# Graded, so the climb can make progress toward the failing rule.
		var off: float = 5.0 * maxi(0, m["start_moves"] - p["max_start_moves"])
		off += 3.0 * maxi(0, p["min_decision_points"] - m["decision_points"]) + 3.0 * maxi(0, p["min_depth"] - m["depth"])
		off += 3.0 * maxi(0, p["min_start_traps"] - m["start_traps"]) + 40.0 * maxf(0.0, m["direction_share"] - p["max_direction_share"])
		return 1000.0 + off + err * 0.1
	return err
