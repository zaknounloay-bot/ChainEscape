extends RefCounted
## EXTREME expert calibration (development only): measures aimed at a player
## who knows every rule and looks several moves ahead, computed exhaustively
## over every reachable position of a board (tools/extreme8_*.gd).
##
## A losing move is HIDDEN at depth K when, after it, play can still go on
## for at least K more moves before the jam: a player who checks every line
## K moves ahead cannot see that it loses. (Solver._dead_within(K - 1) is
## false exactly when the longest continuation is >= K moves.)
##
##   decisions(K)   steps of the solver's solution where at least one
##                  K-hidden losing move is available (each is a decision
##                  that K-move lookahead cannot settle)
##   hidden(K)      how many such K-hidden losing moves, summed over steps
##   deepest        the longest a losing move along the solution survives
##   opening        winning first moves / legal first moves
##   win_share      winnable positions / reachable positions

const CAP := 600000


## {"win": key -> bool, "long": key -> longest continuation} filled by
## explore(); every reachable position (capped).
static func explore(s: Solver) -> Dictionary:
	var memo := {"win": {}, "long": {}, "capped": false}
	if s._crate_n > 0:
		memo["edges"] = {}
	_win(s, memo)
	if s._crate_n > 0:
		_fixpoint(memo)
	return memo


## Phase 18: Movable pushes are the only reversible moves, so only a board
## with crates has cycles - and on a cycle _win's provisional "false" (the
## position still being explored) could be memoised as a loss. With crates the
## explored graph is kept and wins are propagated to a fixpoint (a position
## wins if any move from it reaches a win or a clear board). Boards without
## crates are explored exactly as before.
static func _fixpoint(memo: Dictionary) -> void:
	var w: Dictionary = memo["win"]
	var e: Dictionary = memo["edges"]
	var changed := true
	while changed:
		changed = false
		for k in e:
			if w[k]:
				continue
			for c in e[k]:
				if c == "" or w.get(c, false):
					w[k] = true
					changed = true
					break


static func _win(s: Solver, memo: Dictionary) -> bool:
	if s._alive_count == s._crate_n:
		return true
	var key := s._key()
	var w: Dictionary = memo["win"]
	if w.has(key):
		return w[key]
	if w.size() >= CAP:
		memo["capped"] = true
		return false
	w[key] = false
	var any := false
	var kids := []
	for mv in s._distinct_legal():
		s._do(mv)
		if memo.has("edges"):
			kids.append("" if s._alive_count == s._crate_n else s._key())  # "" = a clear board
		any = _win(s, memo) or any
		s._undo_move(mv)
	w[key] = any
	if memo.has("edges"):
		memo["edges"][key] = kids
	return any


## Longest sequence of legal moves from here (0 = stuck or cleared).
static func longest(s: Solver, memo: Dictionary) -> int:
	if s._alive_count == s._crate_n:
		return 0
	var key := s._key()
	var l: Dictionary = memo["long"]
	if l.has(key):
		return l[key]
	# Phase 18: a crate board can cycle; a position already on the current
	# line counts 0 (no infinite recursion). Without crates: as before.
	if s._crate_n > 0:
		l[key] = 0
	var best := 0
	for mv in s._distinct_legal():
		s._do(mv)
		best = maxi(best, 1 + longest(s, memo))
		s._undo_move(mv)
	l[key] = best
	return best


static func measure(s: Solver, ks: Array = [2, 4, 6, 8]) -> Dictionary:
	var memo := explore(s)
	var w: Dictionary = memo["win"]
	var out := {"positions": w.size(), "winnable": w.values().count(true), "capped": memo["capped"]}
	out["win_share"] = snappedf(float(out["winnable"]) / maxf(out["positions"], 1), 0.001)
	var good := 0
	var legal0 := s._distinct_legal()
	for mv in legal0:
		s._do(mv)
		if s._alive_count == s._crate_n or w.get(s._key(), false):
			good += 1
		s._undo_move(mv)
	out["opening"] = "%d / %d" % [good, legal0.size()]
	var sol := s.solve_moves()
	var dec := {}
	var hid := {}
	for k in ks:
		dec[k] = 0
		hid[k] = 0
	var deepest := 0
	var lose_depths := []
	for mv in sol:
		var depths := []
		for o in s._distinct_legal():
			s._do(o)
			if s._alive_count != s._crate_n and not w.get(s._key(), false):
				depths.append(1 + longest(s, memo))
			s._undo_move(o)
		for d in depths:
			deepest = maxi(deepest, d)
			lose_depths.append(d)
		for k in ks:
			var n := depths.filter(func(d): return d > k).size()
			hid[k] += n
			dec[k] += 1 if n > 0 else 0
		s._do(mv)
	for i in range(sol.size() - 1, -1, -1):
		s._undo_move(sol[i])
	out["solution"] = sol.size()
	out["decisions"] = dec
	out["hidden"] = hid
	out["deepest"] = deepest
	lose_depths.sort()
	out["losing_moves_on_path"] = lose_depths.size()
	out["median_trap_delay"] = lose_depths[lose_depths.size() / 2] if not lose_depths.is_empty() else 0
	return out
