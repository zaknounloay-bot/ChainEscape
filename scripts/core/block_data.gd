class_name BlockData
extends RefCounted
## Plain data for one block on the board. No visuals, no nodes.

## NORMAL blocks keep their arrow. SPINNER blocks turn 90 degrees clockwise
## every time an orthogonally adjacent block escapes.
enum Kind { NORMAL, SPINNER }

## v0.4 spinner rules. Deterministic, never random: the direction of the
## next turn depends only on the rule and how many turns the spinner has
## already made (spin_step).
##   CW       always clockwise (the original spinner)
##   CCW      always counter-clockwise
##   ALT      clockwise, counter-clockwise, clockwise, ...
##   PATTERN  clockwise, clockwise, counter-clockwise, repeat
enum SpinRule { CW, CCW, ALT, PATTERN }
const PATTERN_SEQUENCE := [true, true, false]  # true = clockwise
const RULE_SUFFIX := ["", "-", "~", "*"]  # level-map token after "@"

var id: int
var cell: Vector2i  # x = column, y = row
var color: String
var direction: int  # Direction enum
var kind: int = Kind.NORMAL
## Locked block: cannot escape while any block of this color is still on
## the board ("" = not locked). The lock state itself is derived from the
## board (see BoardModel.is_locked), so Undo re-locks automatically.
var lock_color: String = ""
## Mystery: arrow is hidden. A hidden block cannot escape; it is revealed
## when an orthogonally adjacent block escapes.
var hidden: bool = false
var spin_rule: int = SpinRule.CW
## Turns this spinner has made so far (drives ALT / PATTERN).
var spin_step: int = 0


func _init(p_id: int, p_cell: Vector2i, p_color: String, p_direction: int, p_kind: int = Kind.NORMAL) -> void:
	id = p_id
	cell = p_cell
	color = p_color
	direction = p_direction
	kind = p_kind


func is_spinner() -> bool:
	return kind == Kind.SPINNER


## Is turn number `step` (0-based) of `rule` clockwise?
static func turn_is_cw(rule: int, step: int) -> bool:
	match rule:
		SpinRule.CCW: return false
		SpinRule.ALT: return posmod(step, 2) == 0
		SpinRule.PATTERN: return PATTERN_SEQUENCE[posmod(step, 3)]
	return true


## Number of steps after which the rule repeats (for solver memo keys).
static func rule_period(rule: int) -> int:
	match rule:
		SpinRule.ALT: return 2
		SpinRule.PATTERN: return 3
	return 1


func next_turn_cw() -> bool:
	return turn_is_cw(spin_rule, spin_step)


## A neighbour escaped: turn according to the rule.
func apply_turn() -> void:
	direction = Direction.rotate_cw(direction) if next_turn_cw() else Direction.rotate_ccw(direction)
	spin_step += 1


## Exact inverse of apply_turn (used when constructing levels backwards).
func undo_turn() -> void:
	spin_step -= 1
	direction = Direction.rotate_ccw(direction) if next_turn_cw() else Direction.rotate_cw(direction)


func is_lockable() -> bool:
	return lock_color != ""


func duplicate_data() -> BlockData:
	var b := BlockData.new(id, cell, color, direction, kind)
	b.lock_color = lock_color
	b.hidden = hidden
	b.spin_rule = spin_rule
	b.spin_step = spin_step
	return b
