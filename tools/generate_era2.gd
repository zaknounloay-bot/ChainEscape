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
	# Fail fast on candidates the solver can't settle; the verifier re-checks
	# every written level with the full limit.
	Solver.default_limit = 20000
	var from := int(args["from"])
	var to := int(args["to"])
	var failed := []
	for n in range(from, to + 1):
		var level := _build_slot(n, int(args["seed"]), int(args["rounds"]), int(args["attempts"]), int(args["budget"]))
		if level == null:
			failed.append(n)
			print("L%d: NO CANDIDATE" % n)
			continue
		if write:
			var dest: String = (args["outdir"] + "/level_%d.json" % n) if args.has("outdir") else LevelManager.LEVEL_PATH % n
			var f := FileAccess.open(dest, FileAccess.WRITE)
			f.store_string(LevelManager.to_json_text(level))
			f.close()
	print("DONE %d-%d%s" % [from, to, (" FAILED: %s" % str(failed)) if not failed.is_empty() else ""])
	quit(0 if failed.is_empty() else 1)


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
	var in_band: bool = best_m["difficulty"] >= band.x and best_m["difficulty"] <= band.y
	print("L%d C%d %-16s %-17s %dx%d blk=%d spn=%d lck=%d hid=%d sw=%d gate=%d arm=%d start=%d dec=%d dep=%d diff=%.1f band=%.0f-%.0f%s rwd=%dS%dG %ds" % [
		n, c, best.name.left(16), p["name"], best.columns, best.rows, best_m["blocks"], best_m["spinners"], best_m["locks"], best_m["hidden"],
		best_m["switches"], best_m["gates"], best_m["armored"], best_m["start_moves"], best_m["decision_points"], best_m["depth"],
		best_m["difficulty"], band.x, minf(band.y, 999), "" if in_band else " OUT-OF-BAND", sv, gd, (Time.get_ticks_msec() - t0) / 1000])
	return best
