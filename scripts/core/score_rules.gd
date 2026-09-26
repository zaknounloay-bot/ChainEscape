class_name ScoreRules
extends RefCounted
## Every scoring and star rule in one place (Classic mode, no timer).
##
## Escapes score during play; everything else is settled when the level is
## cleared. Escape points are part of the Undo snapshot, so undoing a move
## also takes back its points (no farming), while penalties stay.

const ESCAPE := 100            # every block that escapes
const CHAIN_STEP := 20         # +20 per link of the current chain...
const CHAIN_CAP := 10          # ...up to +200 at chain x11
const COMPLETE := 500          # clearing the board
const PER_HEART := 200         # each heart left (levels without hearts: 3 minus mistakes)
const NO_MISTAKES := 300       # no blocked/locked taps
const NO_HINTS := 300
const NO_UNDO := 300
const PERFECT := 1000          # no heart lost + no Undo + no Hint
const MISTAKE_PENALTY := 100   # per blocked/locked tap
const UNDO_PENALTY := 150      # per Undo
const HINT_PENALTY := 250      # per Hint

## Default star rules; a level can override any key in its "stars" object.
##   rule names: complete, no_hints, no_undo, no_mistakes, perfect, score,
##               perfect_or_score
const DEFAULT_STARS := {"two": "no_hints", "three": "perfect_or_score", "score": 0}
## Auto 3-star target: a clean run that used Undo once still makes it; a
## run with a blocked tap does not.
const AUTO_TARGET_MARGIN := 1500


static func escape_points(chain: int) -> int:
	return ESCAPE + CHAIN_STEP * clampi(chain - 1, 0, CHAIN_CAP)


## `r` keys: escape_points, blocks, hearts_left, max_hearts, mistakes,
## undos, hints. Returns r plus the breakdown, "perfect" and "score".
static func settle(r: Dictionary) -> Dictionary:
	var out := r.duplicate()
	var hearts_left: int = r["hearts_left"] if r["max_hearts"] > 0 else 3 - mini(3, r["mistakes"])
	out["perfect"] = r["mistakes"] == 0 and r["undos"] == 0 and r["hints"] == 0
	out["bonus_complete"] = COMPLETE
	out["bonus_hearts"] = hearts_left * PER_HEART
	out["bonus_clean"] = (NO_MISTAKES if r["mistakes"] == 0 else 0) + (NO_HINTS if r["hints"] == 0 else 0) + (NO_UNDO if r["undos"] == 0 else 0)
	out["bonus_perfect"] = PERFECT if out["perfect"] else 0
	out["penalties"] = r["mistakes"] * MISTAKE_PENALTY + r["undos"] * UNDO_PENALTY + r["hints"] * HINT_PENALTY
	out["score"] = maxi(0, r["escape_points"] + out["bonus_complete"] + out["bonus_hearts"]
			+ out["bonus_clean"] + out["bonus_perfect"] - out["penalties"])
	return out


## Best possible score: one unbroken chain, full hearts, PERFECT.
static func max_score(blocks: int) -> int:
	var esc := 0
	for i in range(1, blocks + 1):
		esc += escape_points(i)
	return esc + COMPLETE + 3 * PER_HEART + NO_MISTAKES + NO_HINTS + NO_UNDO + PERFECT


static func rules_for(level: LevelData) -> Dictionary:
	var rules := DEFAULT_STARS.duplicate()
	rules.merge(level.star_rules, true)
	if int(rules["score"]) <= 0:
		rules["score"] = max_score(level.blocks.size()) - AUTO_TARGET_MARGIN
	return rules


## Stars for a settled result (1..3). Stars are cumulative: star 3 also
## needs star 2.
static func stars(level: LevelData, result: Dictionary) -> int:
	var rules := rules_for(level)
	var s := 1
	if _passes(rules["two"], result, rules):
		s = 2
		if _passes(rules["three"], result, rules):
			s = 3
	return s


static func _passes(rule: String, r: Dictionary, rules: Dictionary) -> bool:
	match rule:
		"complete": return true
		"no_hints": return r["hints"] == 0
		"no_undo": return r["undos"] == 0
		"no_mistakes": return r["mistakes"] == 0
		"perfect": return r["perfect"]
		"score": return r["score"] >= int(rules["score"])
		"perfect_or_score": return r["perfect"] or r["score"] >= int(rules["score"])
	push_error("Unknown star rule '%s'" % rule)
	return false


## Human-readable requirement text for the complete screen / README.
static func describe(rule: String, rules: Dictionary) -> String:
	match rule:
		"complete": return "Complete the level"
		"no_hints": return "No Hint used"
		"no_undo": return "No Undo used"
		"no_mistakes": return "No blocked taps"
		"perfect": return "PERFECT clear"
		"score": return "Score %d+" % int(rules["score"])
		"perfect_or_score": return "PERFECT or %d+" % int(rules["score"])
	return rule
