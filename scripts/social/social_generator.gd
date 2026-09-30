class_name SocialGenerator
extends RefCounted
## Social: makes a new puzzle for EASY / MEDIUM / HARD with the campaign's
## own LevelGenerator (same construction, Solver validation, refinement and
## difficulty score). Nothing of the campaign levels is read or changed.
##
## Each Social difficulty is a campaign generator profile with a few limits
## overridden, plus a target band on LevelGenerator.difficulty():
##   EASY   profile "easy",   4x4 or 5x4, 7-9 blocks, no spinners,  band 4-9
##   MEDIUM profile "medium", 5x5, 12-15 blocks, 1-2 spinners,       band 14-22
##   HARD   profile "hard",   6x6, 18-22 blocks, 3-4 spinners,       band 28-60
## (for scale: campaign Chapter 1 averages 4.7, Chapter 3 18.2, Chapter 6
## 42.1). Only plain arrows and clockwise spinners: a recipient may never
## have played Chain Escape, so no locks, hidden arrows, switches, gates,
## armor or reward blocks.
##
## One candidate per step() so the Web build keeps drawing between
## attempts. A candidate counts only if the Solver clears it; the one
## closest to the band wins (the first inside it ends the search). The
## winner is turned into a PuzzleDefinition and verified AGAIN from that
## data, exactly as a recipient would rebuild it. Deterministic for a
## given seed (attempt-bounded).

const SPECS := {
	"easy": {"profile": "easy", "band": Vector2(4, 9), "attempts": 30,
		"overrides": {"sizes": [Vector2i(4, 4), Vector2i(5, 4)], "blocks": Vector2i(7, 9), "spinners": Vector2i(0, 0), "refine_steps": 30}},
	"medium": {"profile": "medium", "band": Vector2(14, 22), "attempts": 40,
		"overrides": {"sizes": [Vector2i(5, 5)], "blocks": Vector2i(12, 15), "spinners": Vector2i(1, 2), "refine_steps": 50}},
	"hard": {"profile": "hard", "band": Vector2(28, 60), "attempts": 40,
		"overrides": {"sizes": [Vector2i(6, 6)], "blocks": Vector2i(18, 22), "spinners": Vector2i(3, 4), "refine_steps": 60}},
}
## Safety net only: a step never starts after this (normal runs end far
## sooner, after 1-15 attempts).
const TIME_BUDGET_MS := 30000

var difficulty := ""
var rng_seed := 0
var done := false
## Result: the verified exact puzzle (null until done, or on failure).
var puzzle: PuzzleDefinition
var metrics: Dictionary = {}
var attempts := 0
var error := ""

var _gen: LevelGenerator
var _profile: Dictionary
var _band := Vector2.ZERO
var _max_attempts := 0
var _best: LevelData
var _best_metrics: Dictionary = {}
var _best_gap := INF
var _started_ms := 0


static func profile_for(d: String) -> Dictionary:
	var spec: Dictionary = SPECS[d]
	var p := LevelGenerator.profile(spec["profile"])
	p.merge(spec["overrides"], true)
	return p


func _init(p_difficulty: String, p_seed: int) -> void:
	difficulty = p_difficulty
	rng_seed = p_seed
	if not SPECS.has(difficulty):
		done = true
		error = "difficulty"
		return
	_gen = LevelGenerator.new(rng_seed)
	_profile = profile_for(difficulty)
	_band = SPECS[difficulty]["band"]
	_max_attempts = SPECS[difficulty]["attempts"]
	_started_ms = Time.get_ticks_msec()


## One candidate. Returns true when finished (see puzzle / error).
func step() -> bool:
	if done:
		return true
	if attempts >= _max_attempts or Time.get_ticks_msec() - _started_ms > TIME_BUDGET_MS:
		_finish()
		return true
	attempts += 1
	var cand := _gen.build_candidate(_profile)
	if cand != null:
		var m := _gen.evaluate(cand)
		if m["solvable"] and not m["aborted"]:
			var refined := _gen.refine(cand, m, _profile)
			cand = refined[0]
			m = refined[1]
			if m["solvable"] and not m["aborted"] and m.get("armor_dead_ends", 0) == 0:
				var d: float = m["difficulty"]
				var gap := absf(d - clampf(d, _band.x, _band.y))
				if gap < _best_gap:
					_best = cand
					_best_metrics = m
					_best_gap = gap
				if gap == 0.0:
					_finish()
					return true
	return false


## Runs to the end in one go (tests, tools).
func run() -> PuzzleDefinition:
	while not step():
		pass
	return puzzle


func _finish() -> void:
	done = true
	if _best == null:
		error = "no_solvable_board"
		return
	var def := PuzzleDefinition.from_level(_best)
	# Rebuilt from the data alone, as a recipient would: must verify.
	var rebuilt := PuzzleDefinition.from_json(def.to_json())
	if rebuilt == null or rebuilt.fingerprint() != def.fingerprint() or not rebuilt.verify():
		error = "verification"
		return
	puzzle = rebuilt
	metrics = {"difficulty": snappedf(_best_metrics["difficulty"], 0.1), "in_band": _best_gap == 0.0,
		"blocks": _best_metrics["blocks"], "spinners": _best_metrics["spinners"], "depth": _best_metrics["depth"],
		"decision_points": _best_metrics["decision_points"], "attempts": attempts,
		"ms": Time.get_ticks_msec() - _started_ms}
