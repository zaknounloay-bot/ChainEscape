class_name LevelGenerator
extends RefCounted
## Prototype procedural level generator (offline/tooling use, not shipped
## as endless content yet).
##
## 1. Candidate construction runs the game BACKWARDS: blocks are "slid in"
##    from the edge one by one, each onto a cell whose lane to the edge is
##    empty, while adjacent spinners are turned counter-clockwise. Played
##    forwards, the reverse placement order is a valid solution. Placement
##    is biased toward cells that sit in existing lanes, so blocks interact.
## 2. Every candidate is still validated by the Solver - nothing is
##    accepted on construction alone.
## 3. Metrics (start moves, direction diversity, dependency depth, decision
##    points / traps) are checked against a difficulty profile, and boards
##    too similar to previously accepted ones are rejected.
##
## CLI: godot --headless --path . --script res://tools/generate_levels.gd

const COLORS := ["red", "blue", "green", "yellow", "purple"]

var rng := RandomNumberGenerator.new()
## Maps of already accepted (or curated) boards, for repetition checks.
var known_boards: Array = []
## Why the last candidates were rejected (reason -> count), for tuning.
var reject_stats: Dictionary = {}
## Optional wall-clock deadline (Time.get_ticks_msec(), 0 = none): generate()
## and refine() stop there and return what they have.
var deadline_ms: int = 0


func _out_of_time() -> bool:
	return deadline_ms > 0 and Time.get_ticks_msec() > deadline_ms


func _init(seed: int = 0) -> void:
	rng.seed = seed


## Difficulty profiles. Every limit here is a rejection rule.
static func profile(name: String) -> Dictionary:
	var base := {
		"name": name, "sizes": [Vector2i(5, 5)], "blocks": Vector2i(10, 14), "spinners": Vector2i(0, 0),
		"min_start_moves": 1, "max_start_moves": 3, "max_direction_share": 0.40,
		"min_depth": 3, "min_decision_points": 0, "min_start_traps": 0, "max_similarity": 0.45,
		"method": "reverse", "refine_steps": 150,
		"locks": Vector2i(0, 0), "hidden": Vector2i(0, 0),
		# Spinner rule mix: rule name -> Vector2i(min, max) spinners of that
		# rule ("ccw", "alt", "pattern"; the rest stay classic clockwise).
		"spin_rules": {},
		# A mechanic must add at least this much difficulty to be kept.
		"min_mechanic_impact": 0.5,
		# v0.6 Second Era mechanics: how many switches (each flipping `flips`
		# arrows), Chain Gates (each with `links` linked blocks) and armored
		# blocks. "essential": mechanics the level must NOT be solvable
		# without (teaching levels). New mechanics must add at least
		# min_new_impact of STRUCTURAL difficulty (see LevelAnalysis).
		"switches": Vector2i(0, 0), "flips": Vector2i(1, 2),
		"gates": Vector2i(0, 0), "links": Vector2i(1, 2),
		"armored": Vector2i(0, 0),
		"essential": [], "min_new_impact": 1.0,
	}
	match name:
		"easy":
			base.merge({"sizes": [Vector2i(4, 4), Vector2i(5, 5)], "blocks": Vector2i(8, 12), "spinners": Vector2i(0, 1),
				"max_start_moves": 3, "max_direction_share": 0.45, "min_depth": 3}, true)
		"medium":
			base.merge({"sizes": [Vector2i(5, 5)], "blocks": Vector2i(12, 16), "spinners": Vector2i(1, 2),
				"max_start_moves": 3, "min_depth": 4, "min_decision_points": 1}, true)
		"medium_hard":
			base.merge({"sizes": [Vector2i(5, 5), Vector2i(6, 6)], "blocks": Vector2i(15, 20), "spinners": Vector2i(2, 3),
				"max_start_moves": 3, "max_direction_share": 0.38, "min_depth": 5, "min_decision_points": 2}, true)
		"hard":
			base.merge({"sizes": [Vector2i(6, 6)], "blocks": Vector2i(18, 24), "spinners": Vector2i(3, 4),
				"max_start_moves": 2, "max_direction_share": 0.36, "min_depth": 6, "min_decision_points": 3,
				"min_start_traps": 1}, true)
		"expert":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(22, 28), "spinners": Vector2i(4, 6),
				"max_start_moves": 2, "max_direction_share": 0.34, "min_depth": 7, "min_decision_points": 4,
				"min_start_traps": 1}, true)
		# --- v0.3 profiles: locked blocks, mystery and combinations ---
		"lock_easy":
			base.merge({"sizes": [Vector2i(4, 4), Vector2i(5, 5)], "blocks": Vector2i(9, 13), "locks": Vector2i(1, 2),
				"max_start_moves": 3, "min_depth": 4}, true)
		"lock_medium":
			base.merge({"sizes": [Vector2i(5, 5)], "blocks": Vector2i(12, 16), "locks": Vector2i(2, 3),
				"max_start_moves": 2, "min_depth": 6, "max_direction_share": 0.38}, true)
		"lock_hard":
			base.merge({"sizes": [Vector2i(5, 5), Vector2i(6, 6)], "blocks": Vector2i(15, 20), "locks": Vector2i(3, 4),
				"max_start_moves": 2, "min_depth": 8, "max_direction_share": 0.36}, true)
		"spin_lock":
			base.merge({"sizes": [Vector2i(5, 5), Vector2i(6, 6)], "blocks": Vector2i(14, 19), "spinners": Vector2i(2, 3),
				"locks": Vector2i(1, 2), "max_start_moves": 2, "min_depth": 6, "min_decision_points": 3,
				"max_direction_share": 0.36}, true)
		"spin_lock_hard":
			base.merge({"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 23), "spinners": Vector2i(3, 4),
				"locks": Vector2i(2, 3), "max_start_moves": 2, "min_depth": 8, "min_decision_points": 5,
				"min_start_traps": 1, "max_direction_share": 0.34}, true)
		"spin_lock_expert":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(20, 26), "spinners": Vector2i(4, 5),
				"locks": Vector2i(2, 3), "max_start_moves": 2, "min_depth": 9, "min_decision_points": 7,
				"min_start_traps": 1, "max_direction_share": 0.33}, true)
		"mystery_medium":
			base.merge({"sizes": [Vector2i(5, 5)], "blocks": Vector2i(11, 15), "hidden": Vector2i(2, 3),
				"max_start_moves": 3, "min_depth": 5}, true)
		"mystery_hard":
			base.merge({"sizes": [Vector2i(5, 5), Vector2i(6, 6)], "blocks": Vector2i(14, 19), "spinners": Vector2i(1, 2),
				"hidden": Vector2i(2, 4), "max_start_moves": 2, "min_depth": 6, "min_decision_points": 2}, true)
		"mystery_expert":
			base.merge({"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 23), "spinners": Vector2i(2, 4),
				"locks": Vector2i(1, 2), "hidden": Vector2i(3, 4), "max_start_moves": 2, "min_depth": 8,
				"min_decision_points": 4, "max_direction_share": 0.36}, true)
		# --- v0.4 profiles: advanced spinner rules (worlds 4-5) ---
		"w4_very_hard":
			base.merge({"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 22), "spinners": Vector2i(3, 4),
				"locks": Vector2i(1, 2), "spin_rules": {"ccw": Vector2i(1, 2), "alt": Vector2i(0, 1)},
				"max_start_moves": 2, "min_depth": 8, "min_decision_points": 6, "min_start_traps": 1,
				"max_direction_share": 0.34, "refine_steps": 320}, true)
		"w4_advanced":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(19, 24), "spinners": Vector2i(4, 5),
				"locks": Vector2i(1, 3), "spin_rules": {"alt": Vector2i(1, 2), "pattern": Vector2i(1, 1), "ccw": Vector2i(0, 1)},
				"max_start_moves": 2, "min_depth": 9, "min_decision_points": 8, "min_start_traps": 1,
				"max_direction_share": 0.33, "refine_steps": 320}, true)
		"w5_expert":
			base.merge({"sizes": [Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(21, 27), "spinners": Vector2i(5, 6),
				"locks": Vector2i(2, 3), "spin_rules": {"ccw": Vector2i(1, 2), "alt": Vector2i(1, 2), "pattern": Vector2i(1, 2)},
				"max_start_moves": 2, "min_depth": 10, "min_decision_points": 10, "min_start_traps": 1,
				"max_direction_share": 0.32, "refine_steps": 320}, true)
		"w5_master":
			base.merge({"sizes": [Vector2i(7, 7)], "blocks": Vector2i(24, 30), "spinners": Vector2i(6, 8),
				"locks": Vector2i(2, 4), "spin_rules": {"ccw": Vector2i(1, 3), "alt": Vector2i(1, 2), "pattern": Vector2i(1, 2)},
				"max_start_moves": 2, "min_depth": 12, "min_decision_points": 12, "min_start_traps": 1,
				"max_direction_share": 0.30, "refine_steps": 320}, true)
		"master_100":
			base.merge({"sizes": [Vector2i(7, 7)], "blocks": Vector2i(24, 29), "spinners": Vector2i(6, 7),
				"locks": Vector2i(2, 3), "hidden": Vector2i(2, 3), "spin_rules": {"ccw": Vector2i(1, 2), "alt": Vector2i(1, 2), "pattern": Vector2i(1, 2)},
				"max_start_moves": 2, "min_depth": 12, "min_decision_points": 10, "min_start_traps": 1,
				"max_direction_share": 0.31, "refine_steps": 400}, true)
		"w_mystery_late":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(19, 25), "spinners": Vector2i(4, 5),
				"locks": Vector2i(1, 3), "hidden": Vector2i(3, 5), "spin_rules": {"ccw": Vector2i(0, 1), "alt": Vector2i(1, 1), "pattern": Vector2i(0, 1)},
				"max_start_moves": 2, "min_depth": 9, "min_decision_points": 6, "max_direction_share": 0.34, "refine_steps": 320}, true)
		# --- v0.6 Second Era (levels 101-200). Boards stay at most 7x7: the
		# difficulty comes from dependencies and decisions, not size. ---
		"sw_intro":
			base.merge({"sizes": [Vector2i(4, 4), Vector2i(4, 5)], "blocks": Vector2i(6, 9), "switches": Vector2i(1, 1),
				"flips": Vector2i(1, 1), "essential": ["switch"], "max_start_moves": 3, "min_depth": 3,
				"max_direction_share": 0.5, "refine_steps": 120}, true)
		"sw_basic":
			base.merge({"sizes": [Vector2i(5, 5)], "blocks": Vector2i(11, 15), "spinners": Vector2i(0, 1),
				"switches": Vector2i(1, 2), "flips": Vector2i(1, 2), "essential": ["switch"], "max_start_moves": 2,
				"min_depth": 7, "min_decision_points": 2, "refine_steps": 200}, true)
		"sw_mix":
			base.merge({"sizes": [Vector2i(6, 6)], "blocks": Vector2i(16, 21), "spinners": Vector2i(2, 3),
				"locks": Vector2i(0, 2), "spin_rules": {"ccw": Vector2i(0, 1)}, "switches": Vector2i(1, 2), "flips": Vector2i(1, 2),
				"max_start_moves": 2, "min_depth": 9, "min_decision_points": 5, "min_start_traps": 1,
				"max_direction_share": 0.36, "refine_steps": 280}, true)
		"gate_intro":
			base.merge({"sizes": [Vector2i(6, 6)], "blocks": Vector2i(16, 20), "spinners": Vector2i(2, 3),
				"locks": Vector2i(0, 1), "gates": Vector2i(1, 1), "links": Vector2i(1, 1), "min_new_impact": 2.0,
				"max_start_moves": 2, "min_depth": 9, "min_decision_points": 5, "min_start_traps": 1,
				"max_direction_share": 0.36, "refine_steps": 280}, true)
		"gate_multi":
			base.merge({"sizes": [Vector2i(6, 6)], "blocks": Vector2i(17, 21), "spinners": Vector2i(2, 4),
				"spin_rules": {"alt": Vector2i(0, 1)}, "gates": Vector2i(1, 2), "links": Vector2i(2, 3),
				"max_start_moves": 2, "min_depth": 10, "min_decision_points": 6, "min_start_traps": 1,
				"max_direction_share": 0.35, "refine_steps": 300}, true)
		"gate_switch":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(18, 22), "spinners": Vector2i(3, 4),
				"locks": Vector2i(0, 2), "spin_rules": {"ccw": Vector2i(0, 1), "alt": Vector2i(0, 1)},
				"switches": Vector2i(1, 1), "flips": Vector2i(1, 2), "gates": Vector2i(1, 1), "links": Vector2i(1, 3),
				"max_start_moves": 2, "min_depth": 10, "min_decision_points": 7, "min_start_traps": 1,
				"max_direction_share": 0.34, "refine_steps": 320}, true)
		"deep":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(18, 23), "spinners": Vector2i(3, 5),
				"locks": Vector2i(1, 2), "spin_rules": {"ccw": Vector2i(0, 1), "alt": Vector2i(0, 1), "pattern": Vector2i(0, 1)},
				"switches": Vector2i(1, 2), "flips": Vector2i(1, 2), "gates": Vector2i(0, 1), "links": Vector2i(2, 3),
				"max_start_moves": 2, "min_depth": 11, "min_decision_points": 8, "min_start_traps": 1,
				"max_direction_share": 0.33, "refine_steps": 340}, true)
		"deep_mystery":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(18, 23), "spinners": Vector2i(3, 4),
				"locks": Vector2i(0, 2), "hidden": Vector2i(2, 3), "spin_rules": {"alt": Vector2i(0, 1)},
				"switches": Vector2i(1, 1), "flips": Vector2i(1, 2), "gates": Vector2i(1, 1), "links": Vector2i(1, 2),
				"max_start_moves": 2, "min_depth": 10, "min_decision_points": 7, "max_direction_share": 0.34, "refine_steps": 340}, true)
		"armor_intro":
			base.merge({"sizes": [Vector2i(6, 6), Vector2i(6, 7)], "blocks": Vector2i(18, 22), "spinners": Vector2i(4, 5),
				"locks": Vector2i(0, 1), "spin_rules": {"ccw": Vector2i(0, 1)}, "armored": Vector2i(1, 1), "min_new_impact": 2.0,
				"max_start_moves": 2, "min_depth": 11, "min_decision_points": 8, "min_start_traps": 1,
				"max_direction_share": 0.34, "refine_steps": 320}, true)
		"armor_routes":
			base.merge({"sizes": [Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(20, 24), "spinners": Vector2i(4, 6),
				"locks": Vector2i(0, 2), "spin_rules": {"ccw": Vector2i(0, 1), "alt": Vector2i(0, 1)}, "armored": Vector2i(1, 2),
				"max_start_moves": 2, "min_depth": 13, "min_decision_points": 11, "min_start_traps": 1,
				"max_direction_share": 0.33, "refine_steps": 340}, true)
		"armor_mix":
			base.merge({"sizes": [Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(19, 24), "spinners": Vector2i(3, 5),
				"locks": Vector2i(0, 2), "spin_rules": {"ccw": Vector2i(0, 1), "alt": Vector2i(0, 1), "pattern": Vector2i(0, 1)},
				"switches": Vector2i(1, 1), "flips": Vector2i(1, 2), "gates": Vector2i(1, 1), "links": Vector2i(1, 2),
				"armored": Vector2i(1, 2), "max_start_moves": 2, "min_depth": 12, "min_decision_points": 10,
				"min_start_traps": 1, "max_direction_share": 0.33, "refine_steps": 360}, true)
		# 181-199: expert. Each level focuses on a subset (one mechanic
		# deeply, two interacting, or occasionally three) - never everything.
		"expert_switch":
			base.merge({"sizes": [Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(20, 25), "spinners": Vector2i(5, 6),
				"locks": Vector2i(1, 2), "spin_rules": {"ccw": Vector2i(1, 2), "alt": Vector2i(1, 1), "pattern": Vector2i(0, 1)},
				"switches": Vector2i(2, 2), "flips": Vector2i(1, 2), "max_start_moves": 2, "min_depth": 13,
				"min_decision_points": 12, "min_start_traps": 1, "max_direction_share": 0.32, "refine_steps": 380}, true)
		"expert_gate_armor":
			base.merge({"sizes": [Vector2i(6, 7), Vector2i(7, 7)], "blocks": Vector2i(20, 25), "spinners": Vector2i(4, 6),
				"locks": Vector2i(0, 2), "spin_rules": {"ccw": Vector2i(1, 1), "alt": Vector2i(0, 1), "pattern": Vector2i(0, 1)},
				"gates": Vector2i(1, 2), "links": Vector2i(2, 3), "armored": Vector2i(1, 2), "max_start_moves": 2,
				"min_depth": 13, "min_decision_points": 12, "min_start_traps": 1, "max_direction_share": 0.32, "refine_steps": 380}, true)
		"expert_triple":
			base.merge({"sizes": [Vector2i(7, 7)], "blocks": Vector2i(21, 26), "spinners": Vector2i(4, 6),
				"locks": Vector2i(1, 2), "hidden": Vector2i(0, 2), "spin_rules": {"ccw": Vector2i(0, 1), "alt": Vector2i(1, 1), "pattern": Vector2i(0, 1)},
				"switches": Vector2i(1, 1), "flips": Vector2i(1, 2), "gates": Vector2i(1, 1), "links": Vector2i(2, 3),
				"armored": Vector2i(1, 1), "max_start_moves": 2, "min_depth": 13, "min_decision_points": 12,
				"min_start_traps": 1, "max_direction_share": 0.32, "refine_steps": 400}, true)
		"master_200":
			base.merge({"sizes": [Vector2i(7, 7)], "blocks": Vector2i(22, 27), "spinners": Vector2i(5, 7),
				"locks": Vector2i(1, 2), "hidden": Vector2i(1, 2), "spin_rules": {"ccw": Vector2i(1, 2), "alt": Vector2i(1, 1), "pattern": Vector2i(1, 1)},
				"switches": Vector2i(1, 2), "flips": Vector2i(1, 2), "gates": Vector2i(1, 2), "links": Vector2i(2, 3),
				"armored": Vector2i(1, 2), "max_start_moves": 2, "min_depth": 15, "min_decision_points": 14,
				"min_start_traps": 1, "max_direction_share": 0.30, "refine_steps": 450}, true)
	return base


## Future levels (101+): which profile a campaign level number maps to.
## Every 10th level from 60 on is a mystery level; otherwise the Chapter
## plan decides.
static func profile_for_level(n: int) -> Dictionary:
	if n > 100:
		return profile(era2_profile(n))
	if n % 10 == 0 and n >= 60:
		return profile("w_mystery_late")
	return profile(chapter_plan(Chapters.chapter_of(n))["profile"])


## v0.6 Second Era plan: which profile builds campaign level n (101-200).
##   101-105 teach the Switch (small, switch essential)
##   106-110 switch + normal movement;  111-120 switch + spinners / locks
##   121-125 a single Chain Gate (essential); 126-130 gates with more links
##   131-140 gates + switches + spinners / locks
##   141-160 deepening: everything so far, no new mechanic (mystery every 5th)
##   161-165 introduce Armored blocks (essential); 166-170 armor routes
##   171-180 armor + switch + gate
##   181-199 expert: each level focuses on one, two or three mechanics
##   200     the Master Level
static func era2_profile(n: int) -> String:
	if n >= 200:
		return "master_200"
	if n <= 105:
		return "sw_intro"
	if n <= 110:
		return "sw_basic"
	if n <= 120:
		return "sw_mix"
	if n == 125:
		return "gate_multi"  # milestone: the lesson's exam
	if n <= 125:
		return "gate_intro"
	if n <= 130:
		return "gate_multi"
	if n <= 140:
		return "gate_switch"
	if n <= 160:
		return "deep_mystery" if n % 5 == 0 else "deep"
	if n <= 165:
		return "armor_intro"
	if n <= 170:
		return "armor_routes"
	if n <= 180:
		return "armor_mix"
	return ["expert_triple", "expert_switch", "expert_gate_armor"][n % 3]


## v0.6 milestone levels (special presentation + reward).
const MILESTONES := [125, 150, 175]
## Second Era Chapter averages (11-20). Chapter 11 re-starts lower: it
## teaches the Switch from scratch. From Chapter 12 on it climbs again.
const ERA2_TARGETS := [24.0, 44.0, 47.0, 50.0, 53.0, 56.0, 59.0, 62.0, 65.0, 68.0]


## Average difficulty of each shipped Chapter (the campaign's measured curve,
## see tools/verify_levels.gd). Future Chapters keep climbing.
const CHAPTER_TARGETS := [4.7, 11.1, 18.2, 27.4, 32.4, 42.1, 46.1, 49.9, 53.3, 58.8]
const FUTURE_CHAPTER_STEP := 3.0


## Target difficulty curve for campaign slot `n`: the Chapter's average,
## rising gently inside the Chapter. Used to accept generated levels for a
## given slot (e.g. future levels 101+).
static func target_difficulty(n: int) -> Vector2:
	if n > 100 and n <= 105:
		# Switch lessons: small and gentle, a little harder each time.
		var c0 := 8.0 + (n - 101) * 4.0
		return Vector2(c0 * 0.6, c0 * 1.6)
	if n == 200:
		return Vector2(ERA2_TARGETS[-1] * 1.1, 999.0)
	if n in MILESTONES:
		var cm := chapter_target(Chapters.chapter_of(n)) * 1.08
		return Vector2(cm * 0.95, cm * 1.35)
	var center := chapter_target(Chapters.chapter_of(n))
	var k := float((n - 1) % Chapters.levels_per_chapter()) / maxf(Chapters.levels_per_chapter() - 1, 1)
	center *= 0.9 + 0.2 * k
	return Vector2(center * 0.8, center * 1.25)


static func chapter_target(chapter: int) -> float:
	if chapter <= CHAPTER_TARGETS.size():
		return CHAPTER_TARGETS[maxi(chapter, 1) - 1]
	if chapter <= CHAPTER_TARGETS.size() + ERA2_TARGETS.size():
		return ERA2_TARGETS[chapter - CHAPTER_TARGETS.size() - 1]
	return ERA2_TARGETS[-1] + FUTURE_CHAPTER_STEP * (chapter - CHAPTER_TARGETS.size() - ERA2_TARGETS.size())


## v0.5 Chapter plan: how a Chapter is built. Profile (mechanic mix and
## rejection rules), difficulty band, and how many of its 10 levels carry a
## Silver / Gold reward block. The campaign's placements were made from
## this table (tools/place_reward_blocks.gd); Chapters 11+ extend it.
static func chapter_plan(chapter: int) -> Dictionary:
	var profiles := ["medium", "medium", "spin_lock", "spin_lock", "spin_lock_hard", "spin_lock_hard",
		"w4_very_hard", "w4_advanced", "w5_expert", "w5_expert",
		# v0.6 Second Era (the per-level plan is era2_profile())
		"sw_mix", "sw_mix", "gate_switch", "gate_switch", "deep", "deep", "armor_routes", "armor_mix", "expert_triple", "expert_triple"]
	# Second Era: Silver/Gold are used more strategically, not more often -
	# about the same count as Chapters 7-10, Gold on the hardest paths.
	var silver := [0, 0, 0, 5, 6, 5, 5, 6, 6, 6, 3, 4, 4, 4, 5, 4, 4, 5, 5, 5]
	var gold := [0, 0, 0, 0, 0, 2, 3, 3, 4, 4, 1, 2, 3, 3, 3, 3, 3, 4, 4, 4]
	var i := clampi(chapter, 1, profiles.size()) - 1
	return {
		"chapter": chapter,
		"profile": profiles[i] if chapter <= profiles.size() else "master_200",
		"difficulty": Vector2(chapter_target(chapter) * 0.8, chapter_target(chapter) * 1.25),
		"silver_levels": silver[i],
		"gold_levels": gold[i],
		# Reserved: a future Diamond tier would be one level per Chapter at most.
		"diamond_levels": 0,
		"max_rewards_per_level": 2,
	}


## Which levels of a Chapter carry a reward block: `count` of them, spread
## evenly (`phase` shifts Gold away from Silver).
static func reward_slots(chapter: int, count: int, phase: float) -> Array:
	var rg := Chapters.chapter_range(chapter)
	var size := rg.y - rg.x + 1
	var out := []
	for k in count:
		var idx := int(floor((k + phase) * size / float(count))) % size
		out.append(rg.x + idx)
	return out


## Marks reward blocks on a level: Gold on a block cleared late in the
## solver's solution (it must wait for planning), Silver on one cleared in
## the second half. Hidden blocks are skipped (a "?" should stay a clean
## question) and the final block too (it would be a free reward). Existing
## rarities are cleared first, so this is repeatable.
func assign_reward_blocks(level: LevelData, silver: int, gold: int) -> void:
	for b in level.blocks:
		b.rarity = BlockData.Rarity.NORMAL
	if silver + gold == 0:
		return
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var order := Solver.from_model(model).solve()
	if order.is_empty():
		return
	var by_id := {}
	for b in level.blocks:
		by_id[b.id] = b
	if level.blocks.any(func(x): return x.is_switch() or x.flip_link != "" or x.gate_link != "" or x.armored):
		_assign_strategic(level, order, by_id, silver, gold)
		return
	var eligible := []
	for i in range(order.size() / 2, order.size() - 1):
		if not by_id[order[i]].hidden:
			eligible.append(order[i])
	for g in gold:
		if eligible.is_empty():
			return
		# Gold: from the latest third of the eligible blocks.
		var from := maxi(eligible.size() * 2 / 3, 0)
		var id: int = eligible[from + rng.randi() % maxi(eligible.size() - from, 1)]
		by_id[id].rarity = BlockData.Rarity.GOLD
		eligible.erase(id)
	for sv in silver:
		if eligible.is_empty():
			return
		var id: int = eligible[rng.randi() % eligible.size()]
		by_id[id].rarity = BlockData.Rarity.SILVER
		eligible.erase(id)


## v0.6 Second Era placement: more strategic, not more frequent.
## Gold goes on a block cleared late that is tied to a mechanic (armored,
## gate-linked or flipped by a switch): earning it means mastering that
## dependency. Silver prefers a SWITCH or a spinner neighbour - a block
## whose timing is a real decision. Never hidden, never the last block,
## never a gate. Rewards never change the rules (solvability unchanged).
func _assign_strategic(level: LevelData, order: Array, by_id: Dictionary, silver: int, gold: int) -> void:
	var last_pos := {}
	for i in order.size():
		last_pos[order[i]] = i
	var final_id: int = order[-1]
	var ids := last_pos.keys().filter(func(id): return id != final_id and not by_id[id].hidden and not by_id[id].is_gate())
	ids.sort_custom(func(x, y): return last_pos[x] < last_pos[y])
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var late := ids.slice(ids.size() / 2)
	for g in gold:
		var role := late.filter(func(id): return by_id[id].armored or by_id[id].gate_link != "" or by_id[id].flip_link != "")
		var pool := role if not role.is_empty() else late
		if pool.is_empty():
			break
		var id: int = pool[rng.randi() % pool.size()]
		by_id[id].rarity = BlockData.Rarity.GOLD
		late.erase(id)
		ids.erase(id)
	var mid := ids.slice(ids.size() / 4)
	for sv in silver:
		var timing := mid.filter(func(id): return by_id[id].is_switch() or model.turns_spinners(id))
		var pool := timing if not timing.is_empty() else mid
		if pool.is_empty():
			break
		var id: int = pool[rng.randi() % pool.size()]
		by_id[id].rarity = BlockData.Rarity.SILVER
		mid.erase(id)


## Classification a future generator (and the verifier) can sort by:
## Chapter, difficulty, spinner / lock / mystery complexity (0 none ..
## 3 heavy), reward-block frequency and solvability.
static func classify(level: LevelData, number: int = 0) -> Dictionary:
	var m := LevelAnalysis.analyze(level, false)
	var n := number if number > 0 else level.number
	var rule_kinds := int(m.get("rule_ccw", 0) > 0) + int(m.get("rule_alt", 0) > 0) + int(m.get("rule_pattern", 0) > 0)
	var spinners: int = m.get("spinners", 0)
	var locks: int = m.get("locks", 0)
	var hidden: int = m.get("hidden", 0)
	var rewards := {"silver": 0, "gold": 0, "diamond": 0}
	for b in level.blocks:
		if b.is_reward():
			rewards[b.rarity_name()] += 1
	var reward_count: int = rewards["silver"] + rewards["gold"] + rewards["diamond"]
	return {
		"chapter": Chapters.chapter_of(maxi(n, 1)),
		"solvable": m["solvable"] and not m.get("aborted", false),
		"difficulty": m.get("difficulty", 0.0),
		"spinner_complexity": 0 if spinners == 0 else (1 if rule_kinds == 0 else (2 if rule_kinds == 1 else 3)),
		"lock_complexity": 0 if locks == 0 else (1 if locks == 1 else (2 if locks <= 3 else 3)),
		"mystery_complexity": 0 if hidden == 0 else (1 if hidden <= 2 else (2 if hidden <= 4 else 3)),
		"rewards": rewards,
		"reward_frequency": float(reward_count) / maxf(level.blocks.size(), 1.0),
	}


## Generate a candidate for campaign slot `n`: right profile, difficulty in
## the target band, full validation. Returns null if nothing qualified.
## Output still goes to a human for curation - never auto-released.
func generate_for_level(n: int, attempts: int = 200) -> LevelData:
	var p := profile_for_level(n)
	var band := target_difficulty(n)
	for i in attempts:
		var level := generate(p, 1)
		if level == null:
			continue
		if last_metrics["difficulty"] >= band.x and last_metrics["difficulty"] <= band.y:
			level.number = n
			return level
		known_boards.pop_back()
		_reject("difficulty_band")
	return null


## Tries up to `attempts` candidates; returns the first accepted level or null.
## Accepted metrics are stored in `last_metrics`.
var last_metrics: Dictionary = {}


func generate(p: Dictionary, attempts: int = 300) -> LevelData:
	for i in attempts:
		if _out_of_time():
			return null
		var level := build_candidate(p)
		if level == null:
			_reject("construction")
			continue
		if _wants_new_mechanics(p):
			level = _decorate(level, p)
			if level == null:
				_reject("decoration")
				continue
		var m := evaluate(level)
		if m["solvable"] and p.get("refine_steps", 0) > 0:
			var refined := refine(level, m, p)
			level = refined[0]
			m = refined[1]
		var reason := rejection_reason(m, p, level)
		if reason != "":
			_reject(reason)
			continue
		last_metrics = m
		known_boards.append(level)
		return level
	return null


## Hill-climbing: random mutations (turn an arrow, toggle a spinner, move a
## block) are kept only if the board stays solvable and its score improves.
## Returns [level, metrics].
func refine(level: LevelData, metrics: Dictionary, p: Dictionary) -> Array:
	var best := level
	var best_m := metrics
	var best_score := _score(best_m, p)
	for step in int(p.get("refine_steps", 0)):
		if _out_of_time():
			break
		var cand := _mutate(best, p)
		if cand == null:
			continue
		var m := evaluate(cand)
		if not m["solvable"] or m["aborted"]:
			continue
		var sc := _score(m, p)
		if sc >= best_score:
			best = cand
			best_m = m
			best_score = sc
	return [best, best_m]


func _score(m: Dictionary, p: Dictionary) -> float:
	var missing: int = maxi(0, p["locks"].x - m.get("locks", 0)) + maxi(0, p["hidden"].x - m.get("hidden", 0))
	for rule in p["spin_rules"]:
		missing += maxi(0, p["spin_rules"][rule].x - m.get("rule_" + rule, 0))
	missing += maxi(0, p["switches"].x - m.get("switches", 0)) + maxi(0, p["gates"].x - m.get("gates", 0)) + maxi(0, p["armored"].x - m.get("armored", 0))
	var over_start: int = maxi(0, m["start_moves"] - p["max_start_moves"])
	var over_share: float = maxf(0.0, m["direction_share"] - p["max_direction_share"])
	var decisions: int = mini(m["decision_points"], p["min_decision_points"] + 3)
	return (-8.0 * missing - 6.0 * over_start - 40.0 * over_share - 1.0 * m["start_moves"]
		+ 2.0 * decisions + 2.0 * mini(m["start_traps"], 2) + 0.6 * m["depth"]
		+ 1.0 * m["directions_used"] + 1.5 * mini(m.get("switch_decisions", 0), 3) + 0.5 * mini(m.get("rams", 0), 2))


func _mutate(level: LevelData, p: Dictionary) -> LevelData:
	var copy := LevelData.new()
	copy.rows = level.rows
	copy.columns = level.columns
	var occupied := {}
	for b in level.blocks:
		copy.blocks.append(b.duplicate_data())
		occupied[b.cell] = true
	var arrows := copy.blocks.filter(func(x): return not x.is_gate())
	if arrows.is_empty():
		return null
	var b: BlockData = arrows[rng.randi() % arrows.size()]
	if _wants_new_mechanics(p) and rng.randf() < 0.3:
		if not _mutate_new_mechanic(copy, p):
			return null
		return _rebuilt(copy)
	var plain := not (b.is_switch() or b.flip_link != "" or b.armored)
	var roll := rng.randf()
	var spinner_list := copy.blocks.filter(func(x): return x.is_spinner())
	var spinners := spinner_list.size()
	var locks := copy.blocks.filter(func(x): return x.lock_color != "").size()
	var hiddens := copy.blocks.filter(func(x): return x.hidden).size()
	var wants_locks: bool = p["locks"].y > 0
	var wants_hidden: bool = p["hidden"].y > 0
	if wants_locks and rng.randf() < 0.22:
		# Lock / unlock / re-key a block, or recolor one (colors are keys).
		var r2 := rng.randf()
		if r2 < 0.2:
			b.color = COLORS[rng.randi() % COLORS.size()]
			if b.lock_color == b.color:
				b.lock_color = ""
		elif b.lock_color != "" and (locks > p["locks"].x or r2 < 0.45):
			b.lock_color = ""
		elif locks < p["locks"].y and not b.hidden and not b.armored and not b.is_switch():
			var keys := COLORS.filter(func(c): return c != b.color and copy.blocks.any(func(x): return x.color == c))
			if keys.is_empty():
				return null
			b.lock_color = keys[rng.randi() % keys.size()]
		else:
			return null
		return _rebuilt(copy)
	if wants_hidden and rng.randf() < 0.18:
		if b.hidden and hiddens > p["hidden"].x:
			b.hidden = false
		elif not b.hidden and hiddens < p["hidden"].y and not b.is_spinner() and b.lock_color == "" and plain:
			b.hidden = true
		else:
			return null
		return _rebuilt(copy)
	if not p["spin_rules"].is_empty() and spinners > 0 and rng.randf() < 0.2:
		# Change a spinner's rule (cw / ccw / alt / pattern) within limits.
		var sp: BlockData = spinner_list[rng.randi() % spinners]
		var names := ["cw", "ccw", "alt", "pattern"]
		var options := ["cw"]
		for rule in p["spin_rules"]:
			var have := spinner_list.filter(func(x): return x.spin_rule == names.find(rule)).size()
			if have < p["spin_rules"][rule].y:
				options.append(rule)
		sp.spin_rule = names.find(options[rng.randi() % options.size()])
		sp.spin_step = 0
		return _rebuilt(copy)
	if roll < 0.25 and spinners > 0:
		# Trap motif: make a neighbour of a spinner point INTO it. If the
		# spinner is later turned to face that neighbour, both are stuck.
		var sp: BlockData = spinner_list[rng.randi() % spinners]
		var dirs := [0, 1, 2, 3]
		var d: int = dirs[rng.randi() % 4]
		var nb_cell: Vector2i = sp.cell + Direction.step(d)
		var nb: BlockData = null
		for x in copy.blocks:
			if x.cell == nb_cell:
				nb = x
		if nb == null:
			return null
		# Direction from neighbour back to the spinner.
		nb.direction = [Direction.DOWN, Direction.UP, Direction.RIGHT, Direction.LEFT][d]
	elif roll < 0.65:
		b.direction = (b.direction + rng.randi_range(1, 3)) % 4
	elif roll < 0.82:
		if b.is_spinner() and spinners > p["spinners"].x:
			b.kind = BlockData.Kind.NORMAL
		elif not b.is_spinner() and spinners < p["spinners"].y and not b.hidden and plain:
			b.kind = BlockData.Kind.SPINNER
		else:
			return null
	else:
		var empty := []
		for r in copy.rows:
			for c in copy.columns:
				if not occupied.has(Vector2i(c, r)):
					empty.append(Vector2i(c, r))
		if empty.is_empty():
			return null
		b.cell = empty[rng.randi() % empty.size()]
	return _rebuilt(copy)


## Re-numbers ids in reading order, keeping colors (locks depend on them).
func _rebuilt(copy: LevelData) -> LevelData:
	var grid := {}
	for x in copy.blocks:
		grid[x.cell] = x
	copy.blocks.clear()
	_finish(copy, grid, false)
	_sanitize(copy)
	return copy


## Builds one unvalidated candidate using the profile's "method":
## "reverse" (solvable by construction) or "random" (dense random board,
## filtered by the solver afterwards - better at producing few free moves).
func build_candidate(p: Dictionary) -> LevelData:
	if p.get("method", "reverse") == "random":
		return build_random(p)
	return build_reverse(p)


func build_random(p: Dictionary) -> LevelData:
	var sizes: Array = p["sizes"]
	var size: Vector2i = sizes[rng.randi() % sizes.size()]
	var n_blocks := rng.randi_range(p["blocks"].x, p["blocks"].y)
	var n_spinners := rng.randi_range(p["spinners"].x, p["spinners"].y)
	var level := LevelData.new()
	level.columns = size.x
	level.rows = size.y
	var cells := []
	for r in level.rows:
		for c in level.columns:
			cells.append(Vector2i(c, r))
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = cells[i]
		cells[i] = cells[j]
		cells[j] = t
	var grid := {}
	for i in mini(n_blocks, cells.size()):
		var kind := BlockData.Kind.SPINNER if i < n_spinners else BlockData.Kind.NORMAL
		grid[cells[i]] = BlockData.new(i, cells[i], "blue", rng.randi() % 4, kind)
	_finish(level, grid)
	return level


## Backwards construction (see class comment). Returns null if the board got
## too crowded to place every block.
func build_reverse(p: Dictionary) -> LevelData:
	var sizes: Array = p["sizes"]
	var size: Vector2i = sizes[rng.randi() % sizes.size()]  # x = columns, y = rows
	var n_blocks := rng.randi_range(p["blocks"].x, p["blocks"].y)
	var n_spinners := rng.randi_range(p["spinners"].x, p["spinners"].y)
	var level := LevelData.new()
	level.columns = size.x
	level.rows = size.y
	var grid := {}  # Vector2i -> BlockData
	# A block on the edge facing out can never be blocked, so it is a
	# guaranteed free starting move. Budget them.
	var edge_budget: int = maxi(p["max_start_moves"] - 1, 1)
	for i in n_blocks:
		var options := []
		var weights := []
		var blocks_free := []  # per option: how many currently free blocks it blocks
		for r in level.rows:
			for c in level.columns:
				var cell := Vector2i(c, r)
				if grid.has(cell):
					continue
				var through := _lanes_through(grid, cell, level)
				for d in 4:
					var faces_edge := not _inside(cell + Direction.step(d), level)
					if faces_edge and edge_budget <= 0:
						continue
					if _lane_empty(grid, cell, d, level):
						options.append([cell, d])
						blocks_free.append(through.x)
						# Strongly favour cells that block currently free blocks
						# (fewer obvious moves), then any lane interaction.
						weights.append(0.15 + 8.0 * through.x + 1.5 * through.y)
		if options.is_empty():
			return null
		# Usually take one of the options that blocks the most free blocks,
		# so the finished board has few obvious starting moves.
		var best: int = blocks_free.max()
		var pick: Array
		if best > 0 and rng.randf() < p.get("greed", 0.8):
			var top := []
			for k in options.size():
				if blocks_free[k] == best:
					top.append(options[k])
			pick = top[rng.randi() % top.size()]
		else:
			pick = options[_weighted(weights)]
		var cell: Vector2i = pick[0]
		if not _inside(cell + Direction.step(pick[1]), level):
			edge_budget -= 1
		# Reverse of "escape turns neighbours clockwise".
		for step in Direction.STEPS:
			var n: BlockData = grid.get(cell + step)
			if n != null and n.is_spinner():
				n.undo_turn()
		var remaining := n_blocks - i
		var make_spinner := n_spinners > 0 and rng.randf() < float(n_spinners) / remaining
		# Spinners placed as the very first reverse step (last to leave) are
		# pointless; keep them for when neighbours will exist.
		if make_spinner and i < 2:
			make_spinner = false
		if make_spinner:
			n_spinners -= 1
		var b := BlockData.new(i, cell, "blue", pick[1], BlockData.Kind.SPINNER if make_spinner else BlockData.Kind.NORMAL)
		grid[cell] = b
	_finish(level, grid)
	return level


## Ids in reading order, colors that differ from left/top neighbours.
func _finish(level: LevelData, grid: Dictionary, recolor: bool = true) -> void:
	var ordered := grid.values()
	ordered.sort_custom(func(a, b): return a.cell.y * 100 + a.cell.x < b.cell.y * 100 + b.cell.x)
	for i in ordered.size():
		var b: BlockData = ordered[i]
		b.id = i
		if not recolor:
			level.blocks.append(b)
			continue
		var avoid := []
		for step in [Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: BlockData = grid.get(b.cell + step)
			if n:
				avoid.append(n.color)
		var choices := COLORS.filter(func(c): return not avoid.has(c))
		b.color = choices[rng.randi() % choices.size()]
		level.blocks.append(b)


func evaluate(level: LevelData) -> Dictionary:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var s := Solver.from_model(model)
	var m := s.analyze()
	m["aborted"] = s.aborted or s.any_aborted
	m["difficulty"] = difficulty(m)
	return m


## Empty string = accepted.
func rejection_reason(m: Dictionary, p: Dictionary, level: LevelData = null) -> String:
	if not m["solvable"] or m["aborted"]:
		return "unsolvable"
	if m["start_moves"] < p["min_start_moves"] or m["start_moves"] > p["max_start_moves"]:
		return "start_moves"
	if m["direction_share"] > p["max_direction_share"] or m["directions_used"] < 4:
		return "direction_diversity"
	if m["depth"] < p["min_depth"]:
		return "shallow"
	if m["decision_points"] < p["min_decision_points"] or m["start_traps"] < p["min_start_traps"]:
		return "no_decisions"
	if m.get("locks", 0) < p["locks"].x or m.get("hidden", 0) < p["hidden"].x:
		return "missing_mechanic"
	if m.get("switches", 0) < p["switches"].x or m.get("gates", 0) < p["gates"].x or m.get("armored", 0) < p["armored"].x:
		return "missing_new_mechanic"
	for rule in p["spin_rules"]:
		if m.get("rule_" + rule, 0) < p["spin_rules"][rule].x:
			return "missing_spin_rule"
	if level != null and is_repetitive(level, p["max_similarity"]):
		return "repetitive"
	if level != null and (m.get("locks", 0) > 0 or m.get("hidden", 0) > 0 or m["spinners"] > 0
			or m.get("switches", 0) > 0 or m.get("gates", 0) > 0 or m.get("armored", 0) > 0):
		# Every advanced mechanic must add real difficulty/decisions, and
		# mystery must be fair. (Expensive, so it runs last.)
		var full := LevelAnalysis.analyze(level)
		var need: float = p["min_mechanic_impact"]
		if m["spinners"] > 0 and full["spinner_impact"] < need:
			return "spinners_decorative"
		if m.get("locks", 0) > 0 and full["lock_impact"] < need:
			return "locks_decorative"
		if m.get("hidden", 0) > 0 and (full["mystery_impact"] < need * 0.6 or not full["mystery_fair"]):
			return "mystery_unfair_or_decorative"
		var need_new: float = p["min_new_impact"]
		if m.get("switches", 0) > 0 and full["switch_impact"] < need_new:
			return "switch_decorative"
		if m.get("gates", 0) > 0 and full["gate_impact"] < need_new:
			return "gate_decorative"
		if m.get("armored", 0) > 0 and full["armor_impact"] < need_new:
			return "armor_decorative"
		for e in p["essential"]:
			if full[e + "_impact"] < LevelAnalysis.ESSENTIAL:
				return "not_essential_" + e
	return ""


## Single number for sorting levels by difficulty. Weighted toward ordering
## decisions, not raw block count.
static func difficulty(m: Dictionary) -> float:
	return (m["blocks"] * 0.15 + m["depth"] * 0.6 + m["decision_points"] * 1.5
		+ m["trap_moves"] * 0.4 + m["start_traps"] * 1.0 + m["spinners"] * 0.5
		+ (4 - mini(m["start_moves"], 4)) * 0.5
		+ m.get("locks", 0) * 0.8 + m.get("hidden", 0) * 0.6
		+ m.get("rule_ccw", 0) * 0.3 + m.get("rule_alt", 0) * 0.6 + m.get("rule_pattern", 0) * 0.8
		# v0.6 (zero for every level without the new mechanics):
		+ m.get("switches", 0) * 0.8 + m.get("flip_targets", 0) * 0.3 + m.get("switch_decisions", 0) * 0.8
		+ m.get("gates", 0) * 0.8 + m.get("gate_links", 0) * 0.3
		+ m.get("armored", 0) * 0.8 + m.get("rams", 0) * 0.3)


## How hard the level is to SOLVE, ignoring how many of each mechanic it
## has: dependency depth, decisions, traps, obvious start moves, rams and
## switch decisions. Used to measure a v0.6 mechanic's real impact.
static func structural_difficulty(m: Dictionary) -> float:
	return (m["depth"] * 0.6 + m["decision_points"] * 1.5 + m["trap_moves"] * 0.4 + m["start_traps"] * 1.0
		+ (4 - mini(m["start_moves"], 4)) * 0.5 + m.get("rams", 0) * 0.3 + m.get("switch_decisions", 0) * 0.8
		+ m.get("solution", []).size() * 0.05)


## Fraction of cells with the same content (same arrow, both occupied) as
## any known board of the same size.
func is_repetitive(level: LevelData, max_similarity: float) -> bool:
	for other in known_boards:
		if other.rows != level.rows or other.columns != level.columns:
			continue
		if similarity(level, other) > max_similarity:
			return true
	return false


static func similarity(a: LevelData, b: LevelData) -> float:
	var cells := {}
	for x in a.blocks:
		cells[x.cell] = x.direction
	var same := 0
	for y in b.blocks:
		if cells.get(y.cell, -1) == y.direction:
			same += 1
	return float(same) / maxf(maxf(a.blocks.size(), b.blocks.size()), 1.0)


# --- helpers -----------------------------------------------------------------

func _inside(c: Vector2i, level: LevelData) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < level.columns and c.y < level.rows


func _lane_empty(grid: Dictionary, cell: Vector2i, d: int, level: LevelData) -> bool:
	var step := Direction.step(d)
	var c := cell + step
	while c.x >= 0 and c.y >= 0 and c.x < level.columns and c.y < level.rows:
		if grid.has(c):
			return false
		c += step
	return true


## Placed blocks whose lane contains `cell`:
## x = those that are currently free (placing here would block them),
## y = all of them.
func _lanes_through(grid: Dictionary, cell: Vector2i, level: LevelData) -> Vector2i:
	var n := Vector2i.ZERO
	for b in grid.values():
		var step := Direction.step(b.direction)
		var d: Vector2i = cell - b.cell
		var hit := (step.x != 0 and d.y == 0 and signi(d.x) == step.x) or (step.y != 0 and d.x == 0 and signi(d.y) == step.y)
		if hit:
			n.y += 1
			if _lane_empty(grid, b.cell, b.direction, level):
				n.x += 1
	return n


func _weighted(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return weights.size() - 1


func _reject(reason: String) -> void:
	reject_stats[reason] = reject_stats.get(reason, 0) + 1


# --- v0.6 Second Era: switches, Chain Gates, armored blocks -------------------------

static func _wants_new_mechanics(p: Dictionary) -> bool:
	return p["switches"].y > 0 or p["gates"].y > 0 or p["armored"].y > 0


## A block that can take a new role (no spinner, hidden arrow, lock or
## other v0.6 role): switches, flip targets and armor stay readable.
static func _plain(b: BlockData) -> bool:
	return not (b.is_gate() or b.is_spinner() or b.hidden or b.lock_color != "" or b.is_switch()
		or b.flip_link != "" or b.armored or b.gate_link != "")


## Adds the profile's switches, gates and armored blocks to a solvable base
## board. Returns a solvable decorated copy, or null.
func _decorate(level: LevelData, p: Dictionary) -> LevelData:
	for attempt in 8:
		var copy := _copy(level)
		var ok := true
		for i in rng.randi_range(p["switches"].x, p["switches"].y):
			ok = ok and _add_switch(copy, BlockData.SWITCH_GROUPS[i], p)
		for i in rng.randi_range(p["gates"].x, p["gates"].y):
			ok = ok and _add_gate(copy, BlockData.GATE_GROUPS[i], p)
		for i in rng.randi_range(p["armored"].x, p["armored"].y):
			ok = ok and _add_armor(copy)
		if not ok:
			continue
		copy = _rebuilt(copy)
		var model := BoardModel.new()
		model.setup(copy.rows, copy.columns, copy.blocks)
		var solver := Solver.from_model(model)
		if solver.is_solvable() and not solver.aborted:
			return copy
	return null


func _copy(level: LevelData) -> LevelData:
	var copy := LevelData.new()
	copy.rows = level.rows
	copy.columns = level.columns
	for b in level.blocks:
		copy.blocks.append(b.duplicate_data())
	return copy


func _pick(list: Array) -> Variant:
	return list[rng.randi() % list.size()] if not list.is_empty() else null


## A switch plus 1-2 arrows it reverses. Prefers targets that are currently
## blocked (reversing them matters).
func _add_switch(level: LevelData, group: String, p: Dictionary) -> bool:
	var plain := level.blocks.filter(func(x): return _plain(x))
	if plain.size() < 3:
		return false
	var sw: BlockData = _pick(plain)
	sw.switch_group = group
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var targets := plain.filter(func(x): return x != sw)
	var blocked := targets.filter(func(x): return not model.can_escape(x.id))
	for i in rng.randi_range(p["flips"].x, p["flips"].y):
		var pool := blocked if not blocked.is_empty() and rng.randf() < 0.75 else targets
		var t: BlockData = _pick(pool)
		if t == null:
			break
		t.flip_link = group
		targets.erase(t)
		blocked.erase(t)
	return true


## Turns a block that stands in other blocks' lanes into a Chain Gate and
## links 1-3 other arrows to it.
func _add_gate(level: LevelData, group: String, p: Dictionary) -> bool:
	var grid := {}
	for x in level.blocks:
		grid[x.cell] = x
	var candidates := []
	for x in level.blocks:
		if _plain(x) and x.rarity == BlockData.Rarity.NORMAL and _lanes_through(grid, x.cell, level).y > 0:
			candidates.append(x)
	var g: BlockData = _pick(candidates)
	if g == null:
		return false
	g.kind = BlockData.Kind.GATE
	g.color = LevelManager.GATE_COLOR
	g.gate_group = group
	g.direction = Direction.UP
	var links := level.blocks.filter(func(x): return not x.is_gate() and x.gate_link == "")
	for i in rng.randi_range(p["links"].x, p["links"].y):
		var l: BlockData = _pick(links)
		if l == null:
			break
		l.gate_link = group
		links.erase(l)
	return true


## Shells a block that some other arrow can be launched into.
func _add_armor(level: LevelData) -> bool:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var aimed := {}
	for x in level.blocks:
		if not x.is_gate():
			var t := model.find_blocker(x.id)
			if t != null:
				aimed[t.id] = true
	var candidates := level.blocks.filter(func(x): return _plain(x) and aimed.has(x.id))
	if candidates.is_empty():
		candidates = level.blocks.filter(func(x): return _plain(x))
	var a: BlockData = _pick(candidates)
	if a == null:
		return false
	a.armored = true
	return true


## Refinement moves for the new mechanics: move a switch, a flip target, a
## gate link or a shell to another block (counts stay the same).
func _mutate_new_mechanic(level: LevelData, p: Dictionary) -> bool:
	var plain := level.blocks.filter(func(x): return _plain(x))
	var ops := []
	if level.blocks.any(func(x): return x.is_switch()):
		ops.append_array(["switch", "flip"])
	if level.blocks.any(func(x): return x.gate_link != ""):
		ops.append("link")
	if level.blocks.any(func(x): return x.armored):
		ops.append("armor")
	var op = _pick(ops)
	var to: BlockData = _pick(plain)
	if op == null or to == null:
		return false
	match op:
		"switch":
			var sw: BlockData = _pick(level.blocks.filter(func(x): return x.is_switch()))
			to.switch_group = sw.switch_group
			sw.switch_group = ""
		"flip":
			var f: BlockData = _pick(level.blocks.filter(func(x): return x.flip_link != ""))
			if f == null:
				return false
			to.flip_link = f.flip_link
			f.flip_link = ""
		"link":
			var l: BlockData = _pick(level.blocks.filter(func(x): return x.gate_link != ""))
			to.gate_link = l.gate_link
			l.gate_link = ""
			to.armored = false
		"armor":
			var a: BlockData = _pick(level.blocks.filter(func(x): return x.armored))
			to.armored = true
			a.armored = false
	return true


## Quietly enforces the loader's rules on a generated board (no errors
## printed): one special role per arrow, every link has its switch / gate.
func _sanitize(level: LevelData) -> void:
	for b in level.blocks:
		if b.is_gate():
			b.switch_group = ""
			b.flip_link = ""
			b.gate_link = ""
			b.armored = false
			b.lock_color = ""
			b.hidden = false
			b.rarity = BlockData.Rarity.NORMAL
			continue
		if b.is_spinner() or b.hidden:
			b.switch_group = ""
			b.flip_link = ""
			b.armored = false
		if b.is_switch():
			b.flip_link = ""
		if b.armored and (b.lock_color != "" or b.is_switch()):
			b.armored = false
		if b.lock_color == LevelManager.GATE_COLOR:
			b.lock_color = ""
	var switches := {}
	var flips := {}
	var gates := {}
	var links := {}
	for b in level.blocks:
		if b.is_switch():
			switches[b.switch_group] = true
		if b.flip_link != "":
			flips[b.flip_link] = true
		if b.is_gate():
			gates[b.gate_group] = true
		if b.gate_link != "":
			links[b.gate_link] = true
	for b in level.blocks:
		if b.flip_link != "" and not switches.has(b.flip_link):
			b.flip_link = ""
		if b.gate_link != "" and not gates.has(b.gate_link):
			b.gate_link = ""
		if b.is_switch() and not flips.has(b.switch_group):
			b.switch_group = ""
		if b.is_gate() and not links.has(b.gate_group):
			# A gate without links would never open: make it a plain block.
			b.kind = BlockData.Kind.NORMAL
			b.color = COLORS[b.id % COLORS.size()]
			b.gate_group = ""
