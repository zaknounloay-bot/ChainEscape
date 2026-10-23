extends "res://tools/extreme17_build.gd"
## EXTREME phase 13 (development only; tools/extreme16_prune.gd for the five
## phase-13 recipes, --recipe=...): the decoration screen. Every piece of
## a board is removed in turn and the smaller board goes through the FULL
## acceptance (with --learner_exception, the same rules the board itself
## passed). A piece is needed when its removal fails acceptance or lowers
## the expert learner measure; a removal that passes with no lower learner
## measure means the piece is decoration.
## Quick path first: a removal that already fails a cheap gate (solvable, the
## idea on every winning line, the greedy players, decisions, the 6-move
## greedy player) is NEEDED without the full acceptance; only the others
## run the full acceptance.
##   godot --headless --path . --script res://tools/extreme17_prune.gd -- --recipe=P8_flipgate --file=board.json [--cells=2,5;4,0] --learner_exception


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		x_args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	Solver.default_limit = WORK_LIMIT
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	_load_known()
	cur_recipe = str(x_args.get("recipe", "P5_gate"))
	x_args["recipe"] = cur_recipe
	var d = JSON.parse_string(FileAccess.get_file_as_string(str(x_args["file"])))
	var map: Array = Array(d["map"])
	var only := {}
	if x_args.has("cells"):
		for c in str(x_args["cells"]).split(";", false):
			only[c] = true
	for r in map.size():
		var cells: PackedStringArray = str(map[r]).split(" ", false)
		for c in cells.size():
			if cells[c] == "." or (not only.is_empty() and not only.has("%d,%d" % [r, c])):
				continue
			var m2 := map.duplicate()
			var row := cells.duplicate()
			row[c] = "."
			m2[r] = " ".join(row)
			var line := "r%dc%d %s removed: " % [r, c, cells[c]]
			var level := parse(m2)
			if level == null or not _intact(m2, level):
				print(line + "NEEDED (the board no longer parses: a link loses its piece)")
				continue
			cur_recipe = str(x_args["recipe"])  # the full report resets it
			var quick := _quick_fail(level)
			if quick != "":
				print(line + "NEEDED (quick) - " + quick)
				continue
			var rec := _x_report(str(x_args["recipe"]), "prune", m2)
			var ex: Dictionary = rec.get("x", {}).get("expert", {})
			var lm = ex.get("learner", {})
			var ms: Dictionary = ex.get("measure", {})
			var dec := "decisions K6 %s, hidden K6/K8 %s/%s, deepest %s" % [ms.get("decisions", {}).get(6, "-"), ms.get("hidden", {}).get(6, "-"), ms.get("hidden", {}).get(8, "-"), ms.get("deepest", "-")] if not ms.is_empty() else ""
			print(line + ("PASSES (decoration?) learners %s; %s" % [str(lm), dec] if rec["ok"] else "NEEDED - %s %s %s" % [rec.get("why", ""), ("learners " + str(lm)) if lm is Dictionary and not lm.is_empty() else "", dec]))
	quit()


## The first cheap gate the smaller board fails, or "".
func _quick_fail(level: LevelData) -> String:
	var s := _solver(level)
	var memo := EXPERT.explore(s)
	if not memo["win"].get(s._key(), false):
		return "unsolvable"
	for k in MUST17[cur_recipe]:
		if not EV17.witness(level, k).is_empty():
			return "a winning line without " + k
	for k in POLICIES:
		var w := PROBE.policy_win(s, k, 200 if k != "look4" else 120, 31)
		if w > MAX_POLICY_WIN:
			return "a greedy player (%s) wins %.0f%%" % [k, w * 100.0]
	var m := EXPERT.measure(s)
	if int(m["decisions"][6]) < EXPERT_DECISIONS:
		return "only %d decisions that 6-move lookahead cannot settle (< %d)" % [m["decisions"][6], EXPERT_DECISIONS]
	var g := PROBE.policy_win(s, "look6", 120, 31)
	if g > EXPERT_LOOK6_GREEDY:
		return "a 6-move lookahead greedy player wins %.0f%%" % (g * 100.0)
	return ""
