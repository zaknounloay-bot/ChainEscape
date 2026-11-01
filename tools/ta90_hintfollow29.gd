extends SceneTree
## PHASE 29 (development only): hint-following check (docs/extreme90_phase29.md, J).
## From the start position, repeatedly takes the engine's own hint
## (Solver.from_model(board).recommend_move(), exactly what the page's
## automated touch solver and SHOW A MOVE use) and plays it as SocialPlay does.
## A board passes when this reaches an empty board. It found that every R05
## board (two crates in one column) cycles between its two pushers. The
## Solver is a game feature and is NOT changed; such boards are withdrawn.
##   godot --headless --path . --script res://tools/ta90_hintfollow29.gd -- --boards=N71,N72 [--file=drafts.json]
const EVENTS6 := preload("res://tools/extreme6_events.gd")
func _initialize() -> void:
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var a := OS.get_cmdline_user_args()
	var src = JSON.parse_string(FileAccess.get_file_as_string(a[1].trim_prefix("--file="))) if a.size() > 1 else null
	for n in a[0].trim_prefix("--boards=").split(","):
		var level: LevelData
		if src != null:
			level = LevelManager.parse_level({"name": n, "map": src[n]["map"]}, 0, true)
		else:
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/ta90_%s.json" % n.to_lower()))
			level = PuzzleDefinition.from_dict(d["boards"][0]["puzzle"]).to_level()
		var m: BoardModel = EVENTS6.model_of(level)
		var seq := []
		var won := false
		for i in 60:
			if m.block_count() == 0:
				won = true
				break
			var id := Solver.from_model(m).recommend_move()
			if id == -1:
				break
			seq.append(id)
			var ok := false
			match m.move_state(id):
				"ok": m.remove(id); ok = true
				"advance": m.advance(id); ok = true
				"push": m.push(id); ok = true
				"ram": m.ram(id); ok = true
			if not ok:
				break
		print("%s HINT-FOLLOW %s: %s after %d moves; ids %s" % [n, "PASS" if (won or m.block_count() == 0) else "FAIL", "WIN" if won or m.block_count() == 0 else "NO WIN (%d blocks)" % m.block_count(), seq.size(), seq.slice(0, 24)])
	quit()
