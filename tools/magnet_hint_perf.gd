extends SceneTree
## Hint (SHOW A MOVE) performance on the Magnet levels 76-99:
##   godot --headless --path . --script res://tools/magnet_hint_perf.gd
## For each level: Solver.recommend_move timed at the start and at every
## position reached by 40 random playouts (random legal taps until the board
## is clear or no move is left - lost positions included, where a hint has
## the most searching to do). Reports median / 95th percentile / worst time
## and how often the Solver gave up (node limit). Desktop timings; the Web
## build on a phone is slower (run tools/web_magnet_campaign_test.mjs for
## browser numbers).

const LEVELS := [76, 77, 78, 79, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 93, 94, 95, 96, 97, 98, 99]


func _init() -> void:
	var worst_all := 0.0
	var aborted_all := 0
	for n in LEVELS:
		var json = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%02d.json" % n))
		var level := LevelManager.parse_level(json, n, true)
		var times := []
		var aborted := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = n
		var t0 := Time.get_ticks_usec()
		var start_hint := Solver.from_model(_model(level)).recommend_move()
		var start_ms := (Time.get_ticks_usec() - t0) / 1000.0
		for g in 40:
			var m := _model(level)
			while true:
				var s := Solver.from_model(m)
				var t := Time.get_ticks_usec()
				s.recommend_move()
				times.append((Time.get_ticks_usec() - t) / 1000.0)
				if s.any_aborted:
					aborted += 1
				var moves := m.blocks.keys().filter(func(id): return m.move_state(id) == "ok")
				if moves.is_empty():
					break
				m.remove(moves[rng.randi_range(0, moves.size() - 1)])
		times.sort()
		var worst: float = times[-1]
		worst_all = maxf(worst_all, worst)
		aborted_all += aborted
		print("L%d: start hint %s in %.1f ms; %d positions: median %.1f ms, p95 %.1f ms, worst %.1f ms, gave up %d" % [
			n, "ok" if start_hint != -1 else "NONE", start_ms, times.size(), times[times.size() / 2], times[int(times.size() * 0.95)], worst, aborted])
	print("HINT PERF: worst %.1f ms over all Magnet levels, solver gave up %d times" % [worst_all, aborted_all])
	quit()


static func _model(level: LevelData) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	return m
