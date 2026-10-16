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

## Photo / Message Reveal (phase 4 MVP): the ONLY kind the creator makes now.
## A short, easy puzzle: 4x4, 4-6 plain arrows, no spinners. Stored with
## difficulty "easy" (the API contract is unchanged). SPECS above stay for
## tests / tools that need the older, larger boards (shared before this).
##
## At most ONE special mechanic, for discovery, never difficulty:
##   ARMOR - one armored block, a block already aimed at it with a clear
##           lane (the ram is available from the first move), and the
##           armored block's own lane clear (hit it, then it escapes).
## PORTAL and TWINS stay off: the puzzle format / recipient parser cannot
## carry them yet (see REVEAL_MECHANICS).
##
## Every reveal board is checked over EVERY reachable position: no sequence
## of taps can ever get stuck (no dead ends, no traps).
const REVEAL := "reveal"
## Stored difficulty of every new reveal (the API accepts easy/medium/hard).
const REVEAL_DIFFICULTY := "easy"
const REVEAL_SIZE := Vector2i(4, 4)
const REVEAL_BLOCKS := Vector2i(4, 6)
## Special mechanics a reveal may use. Portal: its cells are not blocks, so
## PuzzleDefinition.verify() (in every shipped build) rejects the board, and
## the Solver it builds has no portals. Twins: the "!" suffix is parsed in
## campaign level files only, so Social parsing rejects it. Enabling either
## changes the puzzle format older builds read - a separate, approved step.
const REVEAL_MECHANICS := ["armor"]
## Share of reveals with a special mechanic (deterministic per seed).
const SPECIAL_CHANCE := 0.4
## Tests: "" = random by seed, "none" = never, "armor" = always.
static var force_special := ""

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
var _special := ""  # REVEAL: the mechanic this board must have ("" = none)
var _rng := RandomNumberGenerator.new()


static func profile_for(d: String) -> Dictionary:
	var spec: Dictionary = SPECS[d]
	var p := LevelGenerator.profile(spec["profile"])
	p.merge(spec["overrides"], true)
	return p


## Generators ever created (tests: a shared challenge is never regenerated).
static var created := 0


func _init(p_difficulty: String, p_seed: int) -> void:
	created += 1
	difficulty = p_difficulty
	rng_seed = p_seed
	if difficulty == REVEAL:
		_gen = LevelGenerator.new(rng_seed)
		_profile = reveal_profile()
		_max_attempts = 60
		_rng.seed = rng_seed
		_special = force_special if force_special != "" else ("armor" if _rng.randf() < SPECIAL_CHANCE else "none")
		if _special == "none":
			_special = ""
		_started_ms = Time.get_ticks_msec()
		return
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
	if difficulty == REVEAL:
		return _reveal_step()
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


static func reveal_profile() -> Dictionary:
	var p := LevelGenerator.profile("easy")
	p.merge({"sizes": [REVEAL_SIZE], "blocks": REVEAL_BLOCKS, "spinners": Vector2i(0, 0), "min_depth": 2,
		"min_start_moves": 1, "max_start_moves": 3, "max_direction_share": 0.67, "refine_steps": 0}, true)
	return p


## REVEAL: one candidate. True when finished.
func _reveal_step() -> bool:
	var cand := _gen.build_candidate(_profile)
	if cand == null or cand.blocks.size() < REVEAL_BLOCKS.x or cand.blocks.size() > REVEAL_BLOCKS.y:
		return false
	if _special != "" and attempts > _max_attempts / 2:
		_special = ""  # no board for the mechanic so far: a plain one is fine
	if _special == "armor" and not _add_armor(cand):
		return false
	var m := _gen.evaluate(cand)
	if not m["solvable"] or m["aborted"] or not trap_free(cand):
		return false
	var def := PuzzleDefinition.from_level(cand)
	if FriendGenerator.is_classic_board(def):
		return false  # never one of the campaign's boards
	_best = cand
	_best_metrics = m
	_best_gap = 0.0
	_finish()
	return true


## ARMOR for discovery: picks an arrow B and an arrow A aimed straight at it
## (A's first blocker is B), so the ram is there from the first move, with
## B's own lane clear (after the hit, B escapes at once). False if this
## board has no such pair.
func _add_armor(level: LevelData) -> bool:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var pairs := []
	for a in model.blocks.values():
		var b := model.find_blocker(a.id)
		if b != null and model.find_blocker(b.id) == null:
			pairs.append([a.id, b.id])
	if pairs.is_empty():
		return false
	var pick: Array = pairs[_rng.randi() % pairs.size()]
	for blk in level.blocks:
		if blk.id == pick[1]:
			blk.armored = true
	return true


## True if no sequence of taps can get stuck: every position reachable from
## the start (escapes and rams) still has a move, until the board is empty.
## Exhaustive - reveal boards have at most 6 blocks (a few hundred positions).
static func trap_free(level: LevelData, limit: int = 5000) -> bool:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var seen := {}
	var stack := [model.snapshot()]
	while not stack.is_empty():
		var snap: Array = stack.pop_back()
		var parts := []
		for b in snap:
			parts.append("%d@%d,%d%s" % [b.id, b.cell.x, b.cell.y, "=" if b.armored else ""])
		parts.sort()
		var key := " ".join(parts)
		if seen.has(key):
			continue
		seen[key] = true
		if seen.size() > limit:
			return false
		model.restore(snap)
		if model.is_empty():
			continue
		var moved := false
		for id in model.blocks.keys():
			var state := model.move_state(id)
			if state != "ok" and state != "ram":
				continue
			moved = true
			model.restore(snap)
			if state == "ok":
				model.remove(id)
			else:
				model.ram(id)
			stack.append(model.snapshot())
		if not moved:
			return false
	return true


## The special mechanic a puzzle uses ("armor", or "" for none).
static func special_of(def: PuzzleDefinition) -> String:
	for row in def.map:
		for tok in String(row).split(" ", false):
			if tok.ends_with("="):
				return "armor"
	return ""


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
		"decision_points": _best_metrics["decision_points"], "attempts": attempts, "special": special_of(rebuilt),
		"ms": Time.get_ticks_msec() - _started_ms}
