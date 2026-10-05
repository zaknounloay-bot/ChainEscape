class_name LevelData
extends RefCounted
## One parsed level, independent of the file format it came from.

var number: int = 0
var name: String = ""
## Optional contextual hint (only level 1 uses one today).
var hint: String = ""
## Optional one-time text shown after the first blocked tap.
var blocked_hint: String = ""
var rows: int = 0
var columns: int = 0
var blocks: Array = []  # Array of BlockData
## Show the animated finger with `hint` (false = text only).
var hint_finger: bool = true
## Hearts for this level; -1 = use the default rule (3 from level 6 on).
var hearts: int = -1
## Mystery level (some arrows start hidden). Derived from blocks if not set.
var mystery: bool = false
## Hints allowed this level; -1 = default rule (see GameManager).
var hints: int = -1
## Star rules, data-driven per level. Keys: "two", "three" (rule names, see
## ScoreRules) and "score" (3-star score target, 0 = auto).
var star_rules: Dictionary = {}
## PORTAL (levels 201+, see Portals): Vector2i cell -> pair
## letter. Empty on every campaign and Social board.
var portals: Dictionary = {}
