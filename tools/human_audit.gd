extends SceneTree
## HUMAN-SOLVABILITY AUDIT (analysis only - changes nothing).
##   godot --headless --path . --script res://tools/human_audit.gd -- --from=226 --to=300 [--detail=295] [--limit=3000000]
##
## For each level it builds the COMPLETE reachable state graph with the
## game's own Solver rules (escapes, rams, Sequence first stages, Movable
## pushes; Undo / Hammer / hints excluded), then measures:
##   winnable / doomed states (a doomed state can never be won),
##   per decision: legal moves L, safe moves S (stay winnable), fatal F,
##   forced steps (S = 1 while L >= 2), meaningful choices (two safe moves
##   that do not commute), dead-end depth after a fatal move (moves still
##   playable before the board is stuck: shortest / random / longest),
##   deviation survival on the solver's solution, k-lookahead player win
##   rates, and fatal moves by kind (calm escape, spinner-turning escape,
##   Sequence first stage, ram, push).
## Writes one JSON line per level (prefix "JSON ") and, with --detail=N, a
## step-by-step walk of level N's solution.

const KIND_NAMES := ["calm", "turn", "advance", "ram", "push"]
const LOOK := [0, 1, 2, 3, 4, 6, 8]
const WALKS := 3000
const LOOK_GAMES := 1500

var keys := {}
var moves: Array = []  # PackedInt32Array per state
var kinds: Array = []  # PackedByteArray per state
var kids: Array = []  # PackedInt32Array per state
var win := PackedByteArray()
var post := PackedInt32Array()
var crate_cfg := PackedStringArray()


func _init() -> void:
	var from := 226
	var to := 300
	var detail := -1
	var limit := 3000000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = int(a.get_slice("=", 1))
		elif a.begins_with("--to="):
			to = int(a.get_slice("=", 1))
		elif a.begins_with("--detail="):
			detail = int(a.get_slice("=", 1))
		elif a.begins_with("--dir="):
			level_dir = a.get_slice("=", 1)
		elif a.begins_with("--limit="):
			limit = int(a.get_slice("=", 1))
	for n in range(from, to + 1):
		if not FileAccess.file_exists(LevelManager.LEVEL_PATH % n if level_dir == "" else level_dir.path_join("level_%02d.json" % n)):
			continue
		var t0 := Time.get_ticks_msec()
		var r := _audit(n, limit, n == detail)
		r["ms"] = Time.get_ticks_msec() - t0
		print("JSON " + JSON.stringify(r))
	quit()


var level_dir := ""  # --dir=res://...: read level_NN.json from there (e.g. the opening lab)


func _solver(n: int) -> Solver:
	LevelManager.dev_twins = level_dir != ""  # lab level files may carry Twins
	var lv := LevelManager.read_level(n) if level_dir == "" else \
		LevelManager.parse_level(JSON.parse_string(FileAccess.get_file_as_string(level_dir.path_join("level_%02d.json" % n))), n, true)
	var model := BoardModel.new()
	model.setup(lv.rows, lv.columns, lv.blocks)
	model.set_portals(lv.portals)
	var s := Solver.from_model(model)
	s.node_limit = 5000000
	return s


func _kind(s: Solver, mv: int) -> int:
	if mv & Solver.PUSH:
		return 4
	if mv & Solver.RAM:
		return 3
	var id := mv & Solver.ID_MASK
	if not s._seq_ids.is_empty() and s._seq_stage[id] == 1:
		return 2
	if s._partner(id) >= 0:
		# TWINS (lab boards): a pair release is a "turn" only when it turns a spinner.
		return 1 if s._spinner_neighbours(id) > 0 else 0
	return 1 if s._is_risky(mv) else 0


func _new_state(s: Solver, k: String) -> int:
	var id := moves.size()
	keys[k] = id
	var w := s._alive_count == s._crate_n
	win.append(1 if w else 0)
	var pm := PackedInt32Array()
	if not w:
		for mv in s.legal_moves():
			# TWINS: tapping either twin is the same move - count the pair once.
			var p := s._partner(mv & Solver.ID_MASK) if (mv & (Solver.RAM | Solver.PUSH)) == 0 else -1
			if p < 0 or p > (mv & Solver.ID_MASK):
				pm.append(mv)
	var ms := pm
	var pk := PackedByteArray()
	for mv in ms:
		pk.append(_kind(s, mv))
	moves.append(pm)
	kinds.append(pk)
	kids.append(PackedInt32Array())
	if s._crate_n > 0:
		var c := PackedStringArray()
		for cid in s._crate_ids:
			c.append(str(s._cell[cid]))
		crate_cfg.append(",".join(c))
	return id


func _explore(s: Solver, limit: int) -> bool:
	keys.clear()
	moves.clear()
	kinds.clear()
	kids.clear()
	win = PackedByteArray()
	post = PackedInt32Array()
	crate_cfg = PackedStringArray()
	var st_id := PackedInt32Array([_new_state(s, s._key())])
	var st_idx := PackedInt32Array([0])
	var st_mv := PackedInt32Array([-1])
	while not st_id.is_empty():
		var top := st_id.size() - 1
		var sid := st_id[top]
		var ms: PackedInt32Array = moves[sid]
		if st_idx[top] < ms.size():
			var mv := ms[st_idx[top]]
			st_idx[top] += 1
			s._do(mv)
			var k := s._key()
			if keys.has(k):
				kids[sid].append(keys[k])
				s._undo_move(mv)
			else:
				if moves.size() >= limit:
					s._undo_move(mv)
					# unwind everything
					for i in range(st_mv.size() - 1, 0, -1):
						s._undo_move(st_mv[i])
					return false
				var nid := _new_state(s, k)
				kids[sid].append(nid)
				st_id.append(nid)
				st_idx.append(0)
				st_mv.append(mv)
		else:
			post.append(sid)
			var back := st_mv[top]
			st_id.resize(top)
			st_idx.resize(top)
			st_mv.resize(top)
			if back != -1:
				s._undo_move(back)
	return true


func _audit(n: int, limit: int, detail: bool) -> Dictionary:
	var s := _solver(n)
	var r := {"level": n}
	var solution := s.solve_moves()
	r["sol_len"] = solution.size()
	if not _explore(s, limit):
		r["complete"] = false
		r["states"] = moves.size()
		return r
	r["complete"] = true
	var N := moves.size()
	r["states"] = N
	# --- winnable (fixed point; one pass on a DAG) ---
	var wn := PackedByteArray()
	wn.resize(N)
	for i in N:
		wn[i] = win[i]
	var changed := true
	var passes := 0
	while changed and passes < 200:
		changed = false
		passes += 1
		for sid in post:
			if wn[sid] == 1:
				continue
			for c in kids[sid]:
				if wn[c] == 1:
					wn[sid] = 1
					changed = true
					break
	var n_win := 0
	for i in N:
		n_win += wn[i]
	r["winnable_states"] = n_win
	r["win_terminals"] = Array(win).count(1)
	# cycles at all? (a child later in post-order than its parent = back edge)
	var pos := PackedInt32Array()
	pos.resize(N)
	for i in post.size():
		pos[post[i]] = i
	var cyclic := false
	for sid in N:
		for c in kids[sid]:
			if pos[c] > pos[sid]:
				cyclic = true
	r["cyclic"] = cyclic
	# --- doomed region: shortest / longest / random moves until stuck ---
	const INF := 1 << 28
	var dmin := PackedInt32Array()
	var dmax := PackedInt32Array()
	var drand := PackedFloat32Array()
	dmin.resize(N)
	dmax.resize(N)
	drand.resize(N)
	for i in N:
		dmin[i] = 0 if (wn[i] == 0 and (moves[i] as PackedInt32Array).is_empty()) else INF
		dmax[i] = 0
		drand[i] = 0.0
	for it in (40 if cyclic else 1):
		var ch := false
		for sid in post:
			if wn[sid] == 1 or (moves[sid] as PackedInt32Array).is_empty():
				continue
			var mn := INF
			var mx := 0
			var sum := 0.0
			for c in kids[sid]:
				mn = mini(mn, dmin[c] + 1)
				mx = maxi(mx, dmax[c] + 1)
				sum += drand[c] + 1.0
			var e := sum / (kids[sid] as PackedInt32Array).size()
			if mn != dmin[sid] or (it == 0 and mx != dmax[sid]) or absf(e - drand[sid]) > 0.01:
				ch = true
			dmin[sid] = mn
			if it == 0:
				dmax[sid] = mx
			drand[sid] = e
		if not ch:
			break
	# --- dead-within-k for the lookahead players ---
	var dw: Array = []
	var prev := PackedByteArray()
	prev.resize(N)
	for i in N:
		prev[i] = 1 if (win[i] == 0 and (moves[i] as PackedInt32Array).is_empty()) else 0
	dw.append(prev)
	for k in range(1, LOOK.max() + 1):
		var cur := PackedByteArray()
		cur.resize(N)
		for i in N:
			if win[i] == 1:
				cur[i] = 0
			elif (moves[i] as PackedInt32Array).is_empty():
				cur[i] = 1
			else:
				var all_dead := 1
				for c in kids[i]:
					if prev[c] == 0:
						all_dead = 0
						break
				cur[i] = all_dead
		dw.append(cur)
		prev = cur
	# --- safe-walk statistics (a player who never errs: which decisions
	# does he meet, and what traps sit beside the right moves?) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + n
	var steps := 0
	var sum_ratio := 0.0
	var forced := 0
	var multi := 0  # steps with L >= 2
	var meaningful := 0
	var trap_steps := 0
	var fatal_opts := 0
	var fatal_rand_sum := 0.0
	var fatal_min_sum := 0.0
	var fatal_hidden3 := 0  # fatal options whose random continuation lasts >= 3 moves
	var fatal_min3 := 0  # ... whose SHORTEST continuation to stuck is >= 3 moves
	var fatal_max := 0
	var fatal_kind := [0, 0, 0, 0, 0]
	var opt_kind := [0, 0, 0, 0, 0]
	var first_trap_sum := 0.0
	var first_trap_n := 0
	var mean_cache := {}
	var cap := maxi(60, solution.size() * 4)
	for w in WALKS:
		var sid := 0
		var t := 0
		var first := -1
		while win[sid] == 0 and t < cap:
			var ks: PackedInt32Array = kids[sid]
			var L := ks.size()
			var safe := []
			for i in L:
				var c := ks[i]
				opt_kind[kinds[sid][i]] += 1
				if wn[c] == 1:
					safe.append(i)
				else:
					fatal_opts += 1
					fatal_kind[kinds[sid][i]] += 1
					fatal_rand_sum += drand[c] + 1.0
					fatal_min_sum += dmin[c] + 1
					fatal_max = maxi(fatal_max, dmax[c] + 1)
					if drand[c] >= 2.0:
						fatal_hidden3 += 1
					if dmin[c] >= 2:
						fatal_min3 += 1
			if safe.is_empty():
				break
			steps += 1
			sum_ratio += float(safe.size()) / L
			if L >= 2:
				multi += 1
				if safe.size() == 1:
					forced += 1
			if L > safe.size():
				trap_steps += 1
				if first == -1:
					first = t
			if safe.size() >= 2:
				if not mean_cache.has(sid):
					mean_cache[sid] = _meaningful(sid, safe, wn)
				if mean_cache[sid]:
					meaningful += 1
			sid = ks[safe[rng.randi() % safe.size()]]
			t += 1
		if first >= 0:
			first_trap_sum += first
			first_trap_n += 1
	r["safe_ratio"] = snappedf(sum_ratio / maxf(steps, 1), 0.001)
	r["forced_share"] = snappedf(float(forced) / maxf(multi, 1), 0.001)
	r["meaningful_share"] = snappedf(float(meaningful) / maxf(steps, 1), 0.001)
	r["trap_step_share"] = snappedf(float(trap_steps) / maxf(steps, 1), 0.001)
	r["steps_per_walk"] = snappedf(float(steps) / WALKS, 0.01)
	r["fatal_per_walk"] = snappedf(float(fatal_opts) / WALKS, 0.01)
	r["fatal_rand_depth"] = snappedf(fatal_rand_sum / maxf(fatal_opts, 1), 0.01)
	r["fatal_min_depth"] = snappedf(fatal_min_sum / maxf(fatal_opts, 1), 0.01)
	r["fatal_max_depth"] = fatal_max
	r["fatal_hidden_share"] = snappedf(float(fatal_hidden3) / maxf(fatal_opts, 1), 0.001)
	r["fatal_min3_share"] = snappedf(float(fatal_min3) / maxf(fatal_opts, 1), 0.001)
	r["first_trap"] = snappedf(first_trap_sum / maxf(first_trap_n, 1), 0.1)
	var fk := {}
	var fs := {}
	for i in 5:
		fk[KIND_NAMES[i]] = fatal_kind[i]
		fs[KIND_NAMES[i]] = snappedf(float(fatal_kind[i]) / maxf(opt_kind[i], 1), 0.001)
	r["fatal_by_kind"] = fk
	r["fatal_rate_by_kind"] = fs
	# --- the solver's solution: decisions, traps and deviation survival ---
	var sid := 0
	var dev_ok := 0
	var dev_all := 0
	var sol_traps := 0
	var sol_hidden := 0
	var sol_forced := 0
	var first_doom := -1
	var trace := []
	for step in solution.size():
		var mv := solution[step]
		var ms: PackedInt32Array = moves[sid]
		var ks: PackedInt32Array = kids[sid]
		var idx := ms.find(mv)
		if idx < 0:
			break
		var safe_n := 0
		var fat := []
		for i in ks.size():
			if wn[ks[i]] == 1:
				safe_n += 1
				if i != idx:
					dev_ok += 1
			else:
				fat.append(i)
			if i != idx:
				dev_all += 1
		if not fat.is_empty():
			sol_traps += 1
			if first_doom == -1:
				first_doom = step
			for i in fat:
				if drand[ks[i]] >= 2.0:
					sol_hidden += 1
					break
		if safe_n == 1 and ks.size() >= 2:
			sol_forced += 1
		if detail:
			var opts := []
			for i in ks.size():
				var c := ks[i]
				opts.append("%s%d%s%s" % ["*" if i == idx else "", ms[i] & Solver.ID_MASK, ["", "~", "+", "R", "P"][kinds[sid][i]],
					"" if wn[c] == 1 else "[X min%d rnd%.1f max%d]" % [dmin[c] + 1, drand[c] + 1.0, dmax[c] + 1]])
			trace.append("step %2d  L=%d S=%d  %s" % [step + 1, ks.size(), safe_n, "  ".join(opts)])
		sid = ks[idx]
	r["sol_trap_steps"] = sol_traps
	r["sol_hidden_trap_steps"] = sol_hidden
	r["sol_forced_steps"] = sol_forced
	r["sol_first_trap"] = first_doom + 1
	r["deviation_survival"] = snappedf(float(dev_ok) / maxf(dev_all, 1), 0.001)
	# --- k-lookahead players (no hints, no undo) ---
	var look := {}
	for k in LOOK:
		var wins := 0
		var dk: PackedByteArray = dw[k]
		for g in LOOK_GAMES:
			var cur := 0
			var t := 0
			while win[cur] == 0 and t < cap:
				var ks: PackedInt32Array = kids[cur]
				if ks.is_empty():
					break
				var pool := []
				for c in ks:
					if dk[c] == 0:
						pool.append(c)
				if pool.is_empty():
					pool = Array(ks)
				cur = pool[rng.randi() % pool.size()]
				t += 1
			wins += win[cur]
		look[str(k)] = snappedf(float(wins) / LOOK_GAMES, 0.001)
	r["lookahead_win"] = look
	# --- HEURISTIC players: the Classic rule "a move that turns nothing
	# (calm escape) can never spoil the board" - play calm moves freely,
	# think (k-lookahead) only about risky moves (spinner turn, first stage,
	# ram, push). Measures whether that rule still holds and suffices. ---
	var heur := {}
	for k in [0, 2, 4, 8]:
		var wins := 0
		var dk: PackedByteArray = dw[k]
		for g in LOOK_GAMES:
			var cur := 0
			var t := 0
			while win[cur] == 0 and t < cap:
				var ks: PackedInt32Array = kids[cur]
				if ks.is_empty():
					break
				var pool := []
				for i in ks.size():
					if kinds[cur][i] == 0:
						pool.append(ks[i])
				if pool.is_empty():
					for c in ks:
						if dk[c] == 0:
							pool.append(c)
				if pool.is_empty():
					pool = Array(ks)
				cur = pool[rng.randi() % pool.size()]
				t += 1
			wins += win[cur]
		heur[str(k)] = snappedf(float(wins) / LOOK_GAMES, 0.001)
	r["heuristic_win"] = heur
	r["calm_fatal_share"] = snappedf(float(fatal_kind[0]) / maxf(fatal_opts, 1), 0.001)
	# solution anatomy: pushes, risky decisions, calm traps
	var sid2 := 0
	var pushes := 0
	var risky_dec := 0
	var calm_trap := 0
	for step in solution.size():
		var mv2 := solution[step]
		var ms2: PackedInt32Array = moves[sid2]
		var ks2: PackedInt32Array = kids[sid2]
		var idx2 := ms2.find(mv2)
		if idx2 < 0:
			break
		if mv2 & Solver.PUSH:
			pushes += 1
		var has_fatal_risky := false
		var has_fatal_calm := false
		for i in ks2.size():
			if wn[ks2[i]] == 0:
				if kinds[sid2][i] == 0:
					has_fatal_calm = true
				else:
					has_fatal_risky = true
		if has_fatal_risky:
			risky_dec += 1
		if has_fatal_calm:
			calm_trap += 1
		sid2 = ks2[idx2]
	r["sol_pushes"] = pushes
	r["sol_risky_decisions"] = risky_dec
	r["sol_calm_trap_steps"] = calm_trap
	# --- Movable: how many useful crate positions exist? ---
	if not crate_cfg.is_empty():
		var all_c := {}
		var win_c := {}
		var end_c := {}
		for i in N:
			all_c[crate_cfg[i]] = true
			if wn[i] == 1:
				win_c[crate_cfg[i]] = true
			if win[i] == 1:
				end_c[crate_cfg[i]] = true
		r["crate_configs"] = all_c.size()
		r["crate_configs_winnable"] = win_c.size()
		r["crate_configs_final"] = end_c.size()
	if detail:
		r["trace"] = trace
		r["solution"] = Array(solution).map(func(m): return "%d%s" % [m & Solver.ID_MASK, "P" if m & Solver.PUSH else ("R" if m & Solver.RAM else "")])
		r["doomed_at_depth"] = _doom_profile(wn)
		# winning lines (acyclic part of the winnable graph) and distinct
		# Movable routes among them
		var paths := {}
		var routes := {}
		for sid3 in post:
			if wn[sid3] == 0:
				continue
			if win[sid3] == 1:
				paths[sid3] = 1
				routes[sid3] = {"": true}
				continue
			var cnt := 0
			var rs := {}
			for i in (kids[sid3] as PackedInt32Array).size():
				var c: int = kids[sid3][i]
				if wn[c] == 0 or pos[c] > pos[sid3]:
					continue
				cnt += paths.get(c, 0)
				var tag := ""
				if not crate_cfg.is_empty() and crate_cfg[c] != crate_cfg[sid3]:
					tag = crate_cfg[c] + ">"
				for x in routes.get(c, {}):
					if rs.size() < 5000:
						rs[tag + x] = true
			paths[sid3] = cnt
			routes[sid3] = rs
		r["winning_lines"] = paths.get(0, 0)
		r["crate_routes"] = (routes.get(0, {}) as Dictionary).size()
		r["crate_route_list"] = (routes.get(0, {}) as Dictionary).keys().slice(0, 8)
	return r


## Two safe moves that do not commute = a real choice between winning lines.
func _meaningful(sid: int, safe: Array, wn: PackedByteArray) -> bool:
	var ms: PackedInt32Array = moves[sid]
	var ks: PackedInt32Array = kids[sid]
	var lim := mini(safe.size(), 12)
	for a in lim:
		for b in range(a + 1, lim):
			var ia: int = safe[a]
			var ib: int = safe[b]
			var ca := ks[ia]
			var cb := ks[ib]
			var ja := (moves[ca] as PackedInt32Array).find(ms[ib])
			var jb := (moves[cb] as PackedInt32Array).find(ms[ia])
			if ja < 0 or jb < 0:
				return true
			var x: int = kids[ca][ja]
			var y: int = kids[cb][jb]
			if x != y or wn[x] == 0:
				return true
	return false


## BFS depth from the start: winnable vs doomed states per depth.
func _doom_profile(wn: PackedByteArray) -> Array:
	var depth := PackedInt32Array()
	depth.resize(moves.size())
	depth.fill(-1)
	depth[0] = 0
	var q := [0]
	var head := 0
	var prof := []
	while head < q.size():
		var s: int = q[head]
		head += 1
		while prof.size() <= depth[s]:
			prof.append([0, 0])
		prof[depth[s]][0 if wn[s] == 1 else 1] += 1
		for c in kids[s]:
			if depth[c] == -1:
				depth[c] = depth[s] + 1
				q.append(c)
	return prof
