extends SceneTree
## MAGNET pull audit (analysis only - changes nothing).
##   godot --headless --path . --script res://tools/magnet_pull_audit.gd -- [--levels=78,93] [--file=res://path.json --n=78]
##
## For every magnet of a level, over the COMPLETE reachable state graph (the
## game's own BoardModel rules; Hammer, Undo and hints excluded):
##   escapes   reachable states where the magnet escapes (a playable move),
##   pulls     ... of those, how many pull a block (BoardModel.pull_target),
##   winning   pulls made from a winnable state into a winnable state (a pull a
##             winning player can actually use),
##   dirs      every direction the magnet ever faces (spinners can turn it),
##   back      whether any cell exists behind it in any of those directions.
## The campaign rule built on this graph: tools/magnet_pull_rule.gd.
## Then the same graph with that one magnet as a plain arrow: identical states,
## moves and winnable states mean the magnet never changes the puzzle. Also
## compares the Solver's solution, its start hint and LevelAnalysis.

const Rule := preload("res://tools/magnet_pull_rule.gd")

var _opts := {}


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		_opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var levels: Array = []
	if _opts.has("file"):
		levels = [int(_opts.get("n", "0"))]
	elif _opts.has("levels"):
		levels = Array(_opts["levels"].split(",")).map(func(s): return int(s))
	else:
		levels = range(76, 100).filter(func(n): return n != 80 and n != 90)
	for n in levels:
		var path: String = _opts.get("file", "res://levels/level_%02d.json" % n)
		var level := LevelManager.parse_level(JSON.parse_string(FileAccess.get_file_as_string(path)), n, true)
		_audit(n, level)
	quit()


func _audit(n: int, level: LevelData) -> void:
	var g := Rule.graph(level)
	print("L%d %s: %d states, %d winnable, %d magnets" % [n, level.name, g["keys"].size(), g["win_count"], g["mags"].size()])
	for id in g["mags"]:
		var s: Dictionary = g["mags"][id]
		var b: BlockData = _block(level, id)
		var dirs: Array = s["dirs"].keys().map(func(d): return Direction.NAMES[d] if "NAMES" in Direction else str(d))
		var any_back := false
		for d in s["dirs"].keys():
			var c: Vector2i = b.cell + Direction.STEPS[Direction.opposite(d)]
			any_back = any_back or (c.x >= 0 and c.y >= 0 and c.x < level.columns and c.y < level.rows)
		# The same level with this one magnet as a plain arrow.
		var plain := _copy(level)
		_block(plain, id).magnet = false
		var p := Rule.graph(plain)
		var same_graph: bool = p["keys"] == g["keys"] and p["edges"] == g["edges"] and p["win"] == g["win"]
		var sol_a := Solver.new(level.rows, level.columns, level.blocks).solve()
		var sol_b := Solver.new(plain.rows, plain.columns, plain.blocks).solve()
		var hint_a := Rule.model(level)
		var hint_b := Rule.model(plain)
		var ha := Solver.from_model(hint_a).recommend_move()
		var hb := Solver.from_model(hint_b).recommend_move()
		var an_a := LevelAnalysis.analyze(level, false)
		var an_b := LevelAnalysis.analyze(plain, false)
		var keys_diff := []
		for k in an_a:
			if str(an_a[k]) != str(an_b.get(k)):
				keys_diff.append("%s %s->%s" % [k, an_a[k], an_b.get(k)])
		print("  magnet #%d %s at (%d,%d) facing %s: escapes in %d states, pulls in %d (%d on a winning line); faces %s; a cell behind it: %s" % [
			id, b.color_name() if b.has_method("color_name") else str(b.color), b.cell.x, b.cell.y, str(b.direction),
			s["escapes"], s["pulls"], s["winning_pulls"], str(s["dirs"].keys()), "yes" if any_back else "NEVER (board edge)"])
		print("    as a plain arrow: same state graph %s; solution %s; start hint %s; analysis changes: %s" % [
			same_graph, "same" if sol_a == sol_b else "DIFFERENT %s vs %s" % [sol_a, sol_b], "same" if ha == hb else "DIFFERENT",
			"none" if keys_diff.is_empty() else ", ".join(keys_diff)])


static func _copy(level: LevelData) -> LevelData:
	var c := LevelData.new()
	c.name = level.name
	c.rows = level.rows
	c.columns = level.columns
	c.blocks = level.blocks.map(func(b): return b.duplicate_data())
	return c


static func _block(level: LevelData, id: int) -> BlockData:
	for b in level.blocks:
		if b.id == id:
			return b
	return null
