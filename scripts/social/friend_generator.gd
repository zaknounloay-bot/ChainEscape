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
	HARD: {"profile": "hard", "band": Vector2(24, 33), "accept": Vector2(23, 35.9),
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 20), "spinners": Vector2i(4, 4)},
		"sample": 6, "stale": 25, "max_evals": 400, "time_cap_ms": 2500},
	VERY_HARD: {"profile": "expert", "band": Vector2(40, 999), "accept": Vector2(36, 999),
		"overrides": {"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(20, 24), "spinners": Vector2i(5, 7)},
		"sample": 6, "stale": 25, "max_evals": 400, "time_cap_ms": 2500},
}
## Extra time (after the cap) to find an acceptable board, if none yet.
const GRACE_MS := 500
## Work per step() call: units run until this much time has passed (a
## single unit is never split, so one long evaluation can exceed it).
const SLICE_MS := 20
## Allowed map tokens: a color + arrow, optionally a clockwise spinner.
const TOKEN_RE := "^[RBGYP][\\^v<>](@)?$"
const CLASSIC_KEYS_PATH := "res://data/classic_board_keys.json"

## Generators ever created (tests: recipients never generate).
static var created := 0
static var _token_re: RegEx
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
	_spec = SPECS[difficulty]
	_profile = profile_for(difficulty)
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
	var acc: Vector2 = _spec["accept"]
	var d: float = _best_m["difficulty"]
	return d >= acc.x and d <= acc.y


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
	if cand != null:
		evals += 1
		var m := _gen.evaluate(cand)
		if m["solvable"] and not m["aborted"]:
			var gap := _gap(m["difficulty"])
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


func _gap(d: float) -> float:
	return absf(d - clampf(d, _band.x, _band.y))


## Plain arrows (+ clockwise spinners above EASY), not a campaign board and
## not one to avoid.
func _allowed(level: LevelData) -> bool:
	var def := PuzzleDefinition.from_level(level)
	if not mechanics_ok(def, difficulty):
		return false
	var key := board_key(def)
	return not _avoid.has(key) and not is_classic_board(def)


func _finish() -> void:
	done = true
	if _best == null:
		error = "no_solvable_board"
		return
	var def := PuzzleDefinition.from_level(_best)
	# Rebuilt from the data alone, as a recipient would: must verify.
	var rebuilt := PuzzleDefinition.from_json(def.to_json())
	if rebuilt == null or rebuilt.fingerprint() != def.fingerprint() or not rebuilt.verify() \
			or not mechanics_ok(rebuilt, difficulty):
		error = "verification"
		return
	puzzle = rebuilt
	var d: float = _best_m["difficulty"]
	var acc: Vector2 = _spec["accept"]
	metrics = {"difficulty": snappedf(d, 0.1), "in_band": _best_gap == 0.0, "in_accept": d >= acc.x and d <= acc.y,
		"evals": evals, "rounds": _rounds, "ms": Time.get_ticks_msec() - _started_ms,
		"blocks": _best_m["blocks"], "spinners": _best_m["spinners"], "depth": _best_m["depth"],
		"decision_points": _best_m["decision_points"], "rows": rebuilt.rows, "cols": rebuilt.columns}
	print("[Social] friend challenge: %s %s" % [difficulty, JSON.stringify(metrics)])


# --- Checks shared with tests ---------------------------------------------------

## Only the mechanics this difficulty may use: plain arrows, and clockwise
## spinners above EASY. (No locks, hidden, rules, switches, gates, armor,
## rewards.)
static func mechanics_ok(def: PuzzleDefinition, d: String) -> bool:
	if _token_re == null:
		_token_re = RegEx.create_from_string(TOKEN_RE)
	for row in def.map:
		for t in String(row).split(" ", false):
			if t == ".":
				continue
			var m := _token_re.search(t)
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
