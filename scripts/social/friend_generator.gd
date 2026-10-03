class_name FriendGenerator
extends RefCounted
## Social / Challenge a Friend: makes a brand-new puzzle for EASY, MEDIUM,
## HARD or VERY HARD - fast, bounded and always Solver-validated.
##
## Same engine as everything else: candidates come from the campaign's
## LevelGenerator (backward construction + its mutations), are measured
## with LevelGenerator.evaluate (the Solver's analysis and difficulty
## score), and the winner becomes a PuzzleDefinition that is rebuilt from
## its own JSON and verified again - exactly what a recipient will play.
## Photo / Message Reveal keeps its own SocialGenerator (unchanged).
##
## Search (one candidate per work unit, units run in short per-frame
## slices so the screen keeps drawing):
##   1. sample up to `sample` fresh candidates, keep the one closest to the
##      difficulty band (the first one inside it wins at once);
##   2. hill-climb that board with LevelGenerator mutations, keeping any
##      solvable change that is at least as close to the band; after
##      `stale` changes without getting closer, start a new round (1).
## Bounded twice: at most `max_evals` candidates (deterministic per seed)
## and at most `time_cap_ms` of wall-clock time (the guarantee on slow
## devices). At the time cap the closest SOLVABLE board found is returned
## if it is still acceptable for this difficulty (`accept`, which never
## reaches the next difficulty); if not, the search gets at most GRACE_MS
## more to find one, then returns the closest board anyway, flagged
## metrics.in_accept = false. A board is never returned unvalidated.
##
## Mechanics (a recipient may never have played): EASY plain arrows;
## MEDIUM, HARD, VERY HARD arrows + clockwise spinners. No locks, hidden
## arrows, other spinner rules, switches, gates, armor or reward blocks
## (checked on every result). Never one of the campaign's 200 boards, and
## never a board passed in `avoid` (NEW CHALLENGE).

const EASY := "easy"
const MEDIUM := "medium"
const HARD := "hard"
const VERY_HARD := "very_hard"
## The four real difficulties (stored with a challenge).
const DIFFICULTIES := [EASY, MEDIUM, HARD, VERY_HARD]
## A creator CHOICE, not a difficulty: resolves to one of DIFFICULTIES.
const SURPRISE := "surprise"

## band: target on LevelGenerator.difficulty() (non-overlapping, with gaps).
## accept: what a budget-bound fallback may still return as this difficulty.
## For scale: campaign Chapter 1 averages 4.7, Chapter 3 18.2, Chapter 4
## 27.4, Chapter 6 42.1.
const SPECS := {
	EASY: {"profile": "easy", "band": Vector2(4, 9), "accept": Vector2(3, 10.9),
		"overrides": {"sizes": [Vector2i(4, 4), Vector2i(5, 4)], "blocks": Vector2i(7, 9), "spinners": Vector2i(0, 0)},
		"sample": 8, "stale": 15, "max_evals": 300, "time_cap_ms": 1500},
	MEDIUM: {"profile": "medium", "band": Vector2(12, 19), "accept": Vector2(11, 22.9),
		"overrides": {"sizes": [Vector2i(5, 5)], "blocks": Vector2i(13, 15), "spinners": Vector2i(2, 3)},
		"sample": 6, "stale": 25, "max_evals": 400, "time_cap_ms": 2000},
	# HARD and VERY HARD (phase 3b): difficulty for a PERSON, not size. The
	# score is only a sanity floor; the "human" criteria (see _human_gap)
	# decide. VERY HARD: fewer free blocks, more one-safe-move steps, fewer
	# safe choices per step, a random tapper almost never clears it. HARD
	# sits in a window below it (not too easy, not VERY HARD).
	HARD: {"profile": "hard", "band": Vector2(20, 999), "accept": Vector2(18, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(4, 4)},
		"human": {"max_start": 4, "min_one_safe": 2, "max_safe_choices": 2.5, "min_decisions": 6,
			"min_random": 0.06, "max_random": 0.25, "quick_playouts": 16, "playouts": 48, "accept_gap": 3.0},
		"sample": 3, "stale": 60, "max_evals": 4000, "time_cap_ms": 1500},
	VERY_HARD: {"profile": "expert", "band": Vector2(28, 999), "accept": Vector2(24, 999),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(5, 6)},
		"human": {"max_start": 3, "min_one_safe": 4, "max_safe_choices": 1.9, "min_decisions": 8,
			"max_random": 0.05, "quick_playouts": 12, "playouts": 40, "accept_gap": 3.0},
		"sample": 3, "stale": 60, "max_evals": 4000, "time_cap_ms": 1500},
}
## Phase 3 HARD / VERY HARD, kept for OLD-vs-NEW benchmarks only
## (tools/friend_benchmark.gd --old). Never used by the game.
const OLD_SPECS := {
	HARD: {"profile": "hard", "band": Vector2(24, 33), "accept": Vector2(23, 35.9),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(4, 4)},
		"sample": 6, "stale": 25, "max_evals": 400, "time_cap_ms": 2500},
	VERY_HARD: {"profile": "expert", "band": Vector2(40, 999), "accept": Vector2(36, 999),
		"overrides": {"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(20, 24), "spinners": Vector2i(5, 7)},
		"sample": 6, "stale": 25, "max_evals": 400, "time_cap_ms": 2500},
}
## Benchmarks / tests only: replaces SPECS[difficulty] keys (e.g. a
## "human" block) for generators created while set. Never used by the game.
static var spec_override: Dictionary = {}
## Extra time (after the cap) to find an acceptable board, if none yet.
const GRACE_MS := 500
## Work per step() call: units run until this much time has passed (a
## single unit is never split, so one long evaluation can exceed it).
const SLICE_MS := 20
## Allowed map tokens: a color + arrow, optionally a clockwise spinner.
const TOKEN_RE := "^[RBGYP][\\^v<>](@)?$"
## LOCK PROTOTYPE ONLY (benchmarks / local dev, never production): the same,
## plus a Classic colour lock ("R>#G": red arrow, locked while any green
## block remains). Production validation (mechanics_ok without allow_locks,
## SocialApi, SharedChallenge, Edge Function v4) still refuses it.
const LOCK_TOKEN_RE := "^[RBGYP][\\^v<>](@)?(#[RBGYP])?$"
## HUMAN TEST 3 ONLY (offline boards, never production): arrows + clockwise
## OR counter-clockwise spinners ("R>@-", the Classic CCW rule).
const CCW_TOKEN_RE := "^[RBGYP][\\^v<>](@-?)?$"
const CLASSIC_KEYS_PATH := "res://data/classic_board_keys.json"

## Generators ever created (tests: recipients never generate).
static var created := 0
static var _token_re: RegEx
static var _lock_token_re: RegEx
static var _ccw_token_re: RegEx
static var _reward_re: RegEx
static var _classic: Dictionary = {}

var difficulty := ""
var rng_seed := 0
var done := false
## Result: the verified exact puzzle (null until done / on failure).
var puzzle: PuzzleDefinition
## {difficulty, in_band, in_accept, evals, rounds, ms, blocks, spinners,
##  depth, decision_points, rows, cols}
var metrics: Dictionary = {}
var error := ""
var evals := 0

var _gen: LevelGenerator
var _spec: Dictionary
var _profile: Dictionary
var _band := Vector2.ZERO
var _avoid: Dictionary = {}
var _time_cap := 0
var _started_ms := 0
var _rounds := 0
# Current round: sampling fresh candidates, then climbing _cur.
var _sampling := true
var _sampled := 0
var _cur: LevelData
var _cur_gap := INF
var _stale := 0
# Best over the whole search (closest to the band, never excluded).
var _best: LevelData
var _best_m: Dictionary = {}
var _best_gap := INF
## HARD / VERY HARD: human-difficulty criteria ({} = score band only).
var _human: Dictionary = {}
# Closest candidate by the cheap signals (fallback if none was analysed).
var _cheap_best: LevelData
var _cheap_best_gap := INF


## `avoid`: board keys (board_key()) that must not come back, e.g. the
## previous challenge for NEW CHALLENGE. `time_cap_ms` < 0 = the spec's
## cap, 0 = no wall-clock cap (deterministic tests).
func _init(p_difficulty: String, p_seed: int, avoid: Array = [], time_cap_ms: int = -1) -> void:
	created += 1
	difficulty = p_difficulty
	rng_seed = p_seed
	if not SPECS.has(difficulty):
		done = true
		error = "difficulty"
		return
	_spec = SPECS[difficulty].duplicate(true)
	if spec_override.has(difficulty):
		if spec_override[difficulty].get("replace", false):
			_spec = spec_override[difficulty].duplicate(true)
		else:
			_spec.merge(spec_override[difficulty], true)
	_human = _spec.get("human", {})
	_profile = LevelGenerator.profile(_spec["profile"])
	_profile.merge(_spec["overrides"], true)
	_band = _spec["band"]
	_gen = LevelGenerator.new(rng_seed)
	for k in avoid:
		_avoid[str(k)] = true
	_time_cap = _spec["time_cap_ms"] if time_cap_ms < 0 else time_cap_ms
	_started_ms = Time.get_ticks_msec()


static func profile_for(d: String) -> Dictionary:
	var spec: Dictionary = SPECS[d]
	var p := LevelGenerator.profile(spec["profile"])
	p.merge(spec["overrides"], true)
	return p


## SURPRISE ME: one of the four real difficulties, uniformly. Anything else
## is returned as is (validated by the generator).
static func resolve(choice: String, rng: RandomNumberGenerator) -> String:
	if choice == SURPRISE:
		return DIFFICULTIES[rng.randi() % DIFFICULTIES.size()]
	return choice


## Runs work units for about SLICE_MS (or `slice_ms`). True when finished.
func step(slice_ms: int = SLICE_MS) -> bool:
	if done:
		return true
	var t0 := Time.get_ticks_msec()
	while true:
		if _out_of_budget():
			_finish()
			return true
		if _unit():
			_finish()
			return true
		if Time.get_ticks_msec() - t0 >= slice_ms:
			return false
	return false


## Runs to the end in one go (tests, tools).
func run() -> PuzzleDefinition:
	while not step(1000000):
		pass
	return puzzle


func _out_of_budget() -> bool:
	if evals >= int(_spec["max_evals"]):
		return true
	if _time_cap <= 0 or evals == 0:
		return false
	var t := Time.get_ticks_msec() - _started_ms
	return t >= _time_cap + GRACE_MS or (t >= _time_cap and _best_acceptable())


func _best_acceptable() -> bool:
	if _best == null:
		return false
	return _accepts(_best_m)


## Acceptable as this difficulty (a budget-bound fallback): the score in
## the accept window and, with human criteria, within their tolerance.
func _accepts(m: Dictionary) -> bool:
	var acc: Vector2 = _spec["accept"]
	var d: float = m["difficulty"]
	if d < acc.x or d > acc.y:
		return false
	return _human.is_empty() or float(m.get("human_gap", 0.0)) <= float(_human.get("accept_gap", 0.0))


## One candidate (a fresh sample or a mutation of _cur). True = an allowed
## board inside the band.
func _unit() -> bool:
	if _rounds == 0:
		_new_round()
	var cand: LevelData
	if _sampling:
		_sampled += 1
		cand = _gen.build_candidate(_profile)
	else:
		_stale += 1
		cand = _gen._mutate(_cur, _profile)
	if cand != null and not _human.is_empty():
		if _try_human(cand):
			return true
	elif cand != null:
		evals += 1
		var m := _gen.evaluate(cand)
		if m["solvable"] and not m["aborted"]:
			var gap := _gap(m["difficulty"])
			if not _human.is_empty():
				m["human_gap"] = _human_gap(m, cand)
				gap += m["human_gap"]
			if gap < _best_gap and _allowed(cand):
				_best = cand
				_best_m = m
				_best_gap = gap
				if gap == 0.0:
					return true
			if gap <= _cur_gap:
				if gap < _cur_gap:
					_stale = 0
				_cur = cand
				_cur_gap = gap
	if _sampling and _sampled >= int(_spec["sample"]):
		_sampling = _cur == null  # nothing solvable yet: keep sampling
		if _sampling:
			_sampled = 0
	elif not _sampling and _stale >= int(_spec["stale"]):
		_new_round()
	return false


func _new_round() -> void:
	_rounds += 1
	_sampling = true
	_sampled = 0
	_stale = 0
	_cur = null
	_cur_gap = INF


## HARD / VERY HARD: one candidate, climbed on CHEAP human signals (free
## blocks at the start + a quick random-tapper rate, after one solvability
## check). Only a board that already passes them gets the full Solver
## analysis (score, one-safe steps, decisions) and a longer random-tapper
## measurement. True = a board meeting every criterion.
func _try_human(cand: LevelData) -> bool:
	evals += 1
	var model := BoardModel.new()
	model.setup(cand.rows, cand.columns, cand.blocks)
	var s := Solver.from_model(model)
	var start := s.legal_moves().size()
	if not s.is_solvable() or s.aborted:
		return false
	# Quick estimate: stops once the board is clearly too easy.
	var games := int(_human.get("quick_playouts", 24))
	var quick := s.random_win_rate(games, rng_seed + evals, int(ceil(float(_human["max_random"]) * games)) + 2)
	var gap := maxf(0.0, start - float(_human["max_start"])) * 2.0 + maxf(0.0, quick - float(_human["max_random"])) * 40.0
	# (A floor is checked on the full measurement only: the quick one is noisy.)
	if gap < _cheap_best_gap:
		_cheap_best = cand
		_cheap_best_gap = gap
	if gap == 0.0 and _allowed(cand):
		var m := _gen.evaluate(cand)
		if m["solvable"] and not m["aborted"]:
			m["human_gap"] = _human_gap(m, cand)
			gap = _gap(m["difficulty"]) + m["human_gap"]
			if gap < _best_gap:
				_best = cand
				_best_m = m
				_best_gap = gap
				if gap == 0.0:
					return true
	if gap <= _cur_gap:
		if gap < _cur_gap:
			_stale = 0
		_cur = cand
		_cur_gap = gap
	return false


func _gap(d: float) -> float:
	return absf(d - clampf(d, _band.x, _band.y))


## How far a board is from feeling like this difficulty to a PERSON (0 =
## meets every criterion). The Solver score above mostly grows with size and
## solution length; these measure the choices a player actually faces:
##   max_start         free blocks at the start (fewer = no easy way in)
##   min_one_safe      steps where several blocks can move but only ONE
##                     keeps the board solvable (real decisions)
##   max_safe_choices  average number of safe moves per step (fewer = less
##                     "tap anything that is free")
##   min_decisions     steps where a wrong (spinner-turning) move exists
##   max_random        share of random-tapper games that still clear the
##                     board (Solver.random_win_rate, `playouts` games,
##                     computed only once the other criteria are met)
## Each shortfall is weighted to roughly one score point per unit.
func _human_gap(m: Dictionary, level: LevelData) -> float:
	var h := _human
	var gap := 0.0
	gap += maxf(0.0, m["start_moves"] - float(h["max_start"])) * 2.0
	gap += maxf(0.0, float(h["min_one_safe"]) - m["one_safe_steps"]) * 1.5
	gap += maxf(0.0, m["safe_choices"] - float(h["max_safe_choices"])) * 4.0
	gap += maxf(0.0, float(h["min_decisions"]) - m["decision_points"]) * 1.0
	# LOCK PROTOTYPE ONLY (no production spec sets these): locks that matter,
	# i.e. blocks that look free (clear lane) but must wait for their key
	# colour, and that open late in the solution.
	# HUMAN TEST ONLY (offline VERY HARD candidates, never a production
	# spec): the opening. Few safe first moves, none of them "calm" (every
	# safe first move turns a spinner, so it has to be thought through).
	if h.has("max_start_safe"):
		gap += maxf(0.0, m["start_safe"] - float(h["max_start_safe"])) * 3.0
	if h.has("max_start_calm"):
		gap += maxf(0.0, m["start_calm"] - float(h["max_start_calm"])) * 3.0
	gap += maxf(0.0, float(h.get("min_locks", 0)) - m.get("locks", 0)) * 2.0
	gap += maxf(0.0, float(h.get("min_locked_free_steps", 0)) - m.get("locked_free_steps", 0)) * 1.0
	gap += maxf(0.0, float(h.get("min_unlock_step", 0)) - m.get("unlock_step", 0.0)) * 0.5
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	# LOCK PROTOTYPE ONLY: a heuristic player (spinner-free moves first, a
	# short lookahead at forced spinner moves; Solver.heuristic_win_rate)
	# must rarely win. Measured only once everything else is met.
	m["smart_win"] = -1.0
	if h.has("max_smart") and gap == 0.0:
		var smart := Solver.from_model(model).heuristic_win_rate(int(h.get("smart_games", 30)), int(h.get("smart_depth", 2)), rng_seed + evals * 17)
		m["smart_win"] = smart
		gap += maxf(0.0, smart - float(h["max_smart"])) * 30.0
	var rate := Solver.from_model(model).random_win_rate(int(h["playouts"]), rng_seed + evals * 31)
	m["random_win"] = rate
	gap += maxf(0.0, rate - float(h["max_random"])) * 40.0
	gap += maxf(0.0, float(h.get("min_random", 0.0)) - rate) * 40.0
	return gap


## Plain arrows (+ clockwise spinners above EASY), not a campaign board and
## not one to avoid.
func _allowed(level: LevelData) -> bool:
	var def := PuzzleDefinition.from_level(level)
	if not mechanics_ok(def, difficulty, _spec.get("allow_locks", false), _spec.get("allow_ccw", false)):
		return false
	var key := board_key(def)
	return not _avoid.has(key) and not is_classic_board(def)


func _finish() -> void:
	done = true
	if _best == null and _cheap_best != null and _allowed(_cheap_best):
		# Nothing reached the full analysis: measure the closest candidate.
		var m := _gen.evaluate(_cheap_best)
		if m["solvable"] and not m["aborted"]:
			m["human_gap"] = _human_gap(m, _cheap_best)
			_best = _cheap_best
			_best_m = m
			_best_gap = _gap(m["difficulty"]) + m["human_gap"]
	if _best == null:
		error = "no_solvable_board"
		return
	var def := PuzzleDefinition.from_level(_best)
	# Rebuilt from the data alone, as a recipient would: must verify.
	var rebuilt := PuzzleDefinition.from_json(def.to_json())
	if rebuilt == null or rebuilt.fingerprint() != def.fingerprint() or not rebuilt.verify() \
			or not mechanics_ok(rebuilt, difficulty, _spec.get("allow_locks", false), _spec.get("allow_ccw", false)):
		error = "verification"
		return
	puzzle = rebuilt
	var d: float = _best_m["difficulty"]
	metrics = {"difficulty": snappedf(d, 0.1), "in_band": _best_gap == 0.0, "in_accept": _accepts(_best_m),
		"evals": evals, "rounds": _rounds, "ms": Time.get_ticks_msec() - _started_ms,
		"blocks": _best_m["blocks"], "spinners": _best_m["spinners"], "depth": _best_m["depth"],
		"decision_points": _best_m["decision_points"], "rows": rebuilt.rows, "cols": rebuilt.columns,
		"start_moves": _best_m["start_moves"], "one_safe_steps": _best_m["one_safe_steps"],
		"safe_choices": _best_m["safe_choices"], "human_gap": snappedf(float(_best_m.get("human_gap", 0.0)), 0.01),
		"random_win": snappedf(float(_best_m.get("random_win", -1.0)), 0.001)}
	print("[Social] friend challenge: %s %s" % [difficulty, JSON.stringify(metrics)])


# --- Checks shared with tests ---------------------------------------------------

## Only the mechanics this difficulty may use: plain arrows, and clockwise
## spinners above EASY. (No locks, hidden, rules, switches, gates, armor,
## rewards.)
static func mechanics_ok(def: PuzzleDefinition, d: String, allow_locks: bool = false, allow_ccw: bool = false) -> bool:
	if _token_re == null:
		_token_re = RegEx.create_from_string(TOKEN_RE)
		_lock_token_re = RegEx.create_from_string(LOCK_TOKEN_RE)
		_ccw_token_re = RegEx.create_from_string(CCW_TOKEN_RE)
	var re := _lock_token_re if allow_locks else (_ccw_token_re if allow_ccw else _token_re)
	for row in def.map:
		for t in String(row).split(" ", false):
			if t == ".":
				continue
			var m := re.search(t)
			if m == null or (d == EASY and m.get_string(1) != ""):
				return false
	return true


## Identity of a board for "same puzzle?" checks: size + cells, ignoring
## reward markers ($S / $G / $D: they never change how a board plays).
static func board_key(def: PuzzleDefinition) -> String:
	if _reward_re == null:
		_reward_re = RegEx.create_from_string("\\$[SGD]")
	var rows := []
	for row in def.map:
		var cells := []
		for t in String(row).split(" ", false):
			cells.append(_reward_re.sub(t, "", true))
		rows.append(" ".join(cells))
	return ("%dx%d|" % [def.rows, def.columns] + "/".join(rows)).sha256_text()


## True if `def` is one of the campaign's 200 boards (keys precomputed in
## data/classic_board_keys.json by tools/classic_board_keys.gd; the unit
## test recomputes them from the level files).
static func is_classic_board(def: PuzzleDefinition) -> bool:
	if _classic.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string(CLASSIC_KEYS_PATH))
		if typeof(data) == TYPE_DICTIONARY:
			for k in data.get("keys", []):
				_classic[str(k)] = true
	return _classic.has(board_key(def))
