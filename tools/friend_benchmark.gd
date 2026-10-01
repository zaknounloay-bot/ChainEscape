extends SceneTree
## Challenge a Friend: generation benchmark with the product budgets (time
## caps on), many seeds per difficulty, NEW CHALLENGE (previous board
## avoided) and SURPRISE ME.
##   godot --headless --path . --script res://tools/friend_benchmark.gd -- --seeds=200
## Desktop timings are NOT phone timings: use the in-game benchmark
## (Web build, ?friendbench=1) on a real device for those.


func _init() -> void:
	var n := 200
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			n = int(arg.get_slice("=", 1))
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
