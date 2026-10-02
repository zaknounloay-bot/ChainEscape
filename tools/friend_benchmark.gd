extends SceneTree
## Challenge a Friend: generation benchmark with the product budgets (time
## caps on), many seeds per difficulty, NEW CHALLENGE (previous board
## avoided) and SURPRISE ME.
##   godot --headless --path . --script res://tools/friend_benchmark.gd -- --seeds=200
##   ... -- --seeds=100 --human            human-difficulty table (HARD / VERY HARD)
##   ... -- --seeds=100 --human --old      the same with the phase 3 HARD / VERY HARD specs
## Desktop timings are NOT phone timings: use the in-game benchmark
## (Web build, ?friendbench=1) on a real device for those.
##
## --human re-measures every result independently of the generator: free
## blocks at the start, one-safe-move steps, safe choices per step,
## decision points, solution depth, and a 300-game random tapper (another
## seed than the generator's own measurement).


func _init() -> void:
	var n := 200
	var human := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			n = int(arg.get_slice("=", 1))
		if arg == "--human":
			human = true
		if arg == "--old":
			for d in FriendGenerator.OLD_SPECS:
				var spec: Dictionary = FriendGenerator.OLD_SPECS[d].duplicate(true)
				spec["replace"] = true
				FriendGenerator.spec_override[d] = spec
	if human:
		_human_table(n)
		quit()
		return
	print("difficulty  runs  in_band  accept  ms_p50  ms_p90  ms_p99  ms_max  diff_min  diff_p50  diff_max  evals_p50  evals_max  size(s)")
	for d in FriendGenerator.DIFFICULTIES:
		_row(d, n, false)
	for d in FriendGenerator.DIFFICULTIES:
		_row(d, maxi(n / 4, 10), true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var picks := {}
	for i in 1000:
		var d := FriendGenerator.resolve(FriendGenerator.SURPRISE, rng)
		picks[d] = picks.get(d, 0) + 1
	print("SURPRISE ME over 1000 picks: %s" % str(picks))
	quit()


## `renew`: each run is a NEW CHALLENGE (the previous run's board avoided).
func _row(d: String, n: int, renew: bool) -> void:
	var ms := []
	var diffs := []
	var ev := []
	var in_band := 0
	var accept := 0
	var sizes := {}
	var prev := ""
	var repeats := 0
	var invalid := 0
	for i in n:
		var g := FriendGenerator.new(d, 90000 + i * 104729 + (7 if renew else 0), [prev] if renew and prev != "" else [])
		var def := g.run()
		if def == null or not def.verify() or not FriendGenerator.mechanics_ok(def, d) or FriendGenerator.is_classic_board(def):
			invalid += 1
			continue
		var key := FriendGenerator.board_key(def)
		if key == prev:
			repeats += 1
		prev = key
		var m: Dictionary = g.metrics
		ms.append(m["ms"])
		diffs.append(m["difficulty"])
		ev.append(m["evals"])
		in_band += 1 if m["in_band"] else 0
		accept += 1 if m["in_accept"] else 0
		var s := "%dx%d" % [def.columns, def.rows]
		sizes[s] = sizes.get(s, 0) + 1
	ms.sort()
	diffs.sort()
	ev.sort()
	var q := func(a: Array, f: float): return a[mini(int(f * a.size()), a.size() - 1)]
	print("%-10s  %4d  %6.1f%%  %5.1f%%  %6d  %6d  %6d  %6d  %8.1f  %8.1f  %8.1f  %9d  %9d  %s%s" % [
		d + ("*" if renew else ""), n, 100.0 * in_band / n, 100.0 * accept / n,
		q.call(ms, 0.5), q.call(ms, 0.9), q.call(ms, 0.99), ms[-1],
		diffs[0], q.call(diffs, 0.5), diffs[-1], q.call(ev, 0.5), ev[-1], str(sizes),
		("  invalid %d" % invalid if invalid else "") + ("  REPEATS %d" % repeats if repeats else "")])


## Human-difficulty comparison for HARD and VERY HARD (averages, with the
## median / p90 where they matter).
func _human_table(n: int) -> void:
	print("difficulty  runs  met_all  accept  fails  ms_p50  ms_p90  ms_max | start  one_safe  safe_choices  decisions  depth  blocks  spinners | random_avg  random_p50  random_p90  random_max")
	for d in [FriendGenerator.HARD, FriendGenerator.VERY_HARD]:
		var ms := []
		var rows := []
		var met := 0
		var accept := 0
		var failed := 0
		for i in n:
			var g := FriendGenerator.new(d, 50000 + i * 7919, [])
			var def := g.run()
			if def == null or not def.verify() or not FriendGenerator.mechanics_ok(def, d) or FriendGenerator.is_classic_board(def):
				failed += 1
				continue
			ms.append(g.metrics["ms"])
			met += 1 if g.metrics["in_band"] else 0
			accept += 1 if g.metrics["in_accept"] else 0
			var lv := def.to_level()
			var model := BoardModel.new()
			model.setup(lv.rows, lv.columns, lv.blocks)
			var s := Solver.from_model(model)
			var m := s.analyze()
			m["random"] = s.random_win_rate(300, 777 + i)
			rows.append(m)
		ms.sort()
		var q := func(a: Array, f: float): return a[mini(int(f * a.size()), a.size() - 1)]
		var avg := func(k: String) -> float: return rows.reduce(func(acc, x): return acc + float(x[k]), 0.0) / maxf(rows.size(), 1)
		var r := rows.map(func(x): return float(x["random"]))
		r.sort()
		print("%-10s  %4d  %6.1f%%  %5.1f%%  %5d  %6d  %6d  %6d | %5.2f  %8.2f  %12.2f  %9.2f  %5.2f  %6.2f  %8.2f | %9.1f%%  %9.1f%%  %9.1f%%  %9.1f%%" % [
			d, n, 100.0 * met / n, 100.0 * accept / n, failed, q.call(ms, 0.5), q.call(ms, 0.9), ms[-1],
			avg.call("start_moves"), avg.call("one_safe_steps"), avg.call("safe_choices"), avg.call("decision_points"),
			avg.call("depth"), avg.call("blocks"), avg.call("spinners"),
			100.0 * avg.call("random"), 100.0 * q.call(r, 0.5), 100.0 * q.call(r, 0.9), 100.0 * r[-1]])
