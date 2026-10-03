class_name BlockData
extends RefCounted
## Plain data for one block on the board. No visuals, no nodes.

## NORMAL blocks keep their arrow. SPINNER blocks turn 90 degrees clockwise
## every time an orthogonally adjacent block escapes. GATE (v0.6, Chain
## Gate) is a solid slab with no arrow: it can't be tapped, blocks lanes, and
## opens (disappears) once every block linked to it has escaped.
enum Kind { NORMAL, SPINNER, GATE }

## v0.4 spinner rules. Deterministic, never random: the direction of the
## next turn depends only on the rule and how many turns the spinner has
## already made (spin_step).
##   CW       always clockwise (the original spinner)
##   CCW      always counter-clockwise
##   ALT      clockwise, counter-clockwise, clockwise, ...
##   PATTERN  clockwise, clockwise, counter-clockwise, repeat
enum SpinRule { CW, CCW, ALT, PATTERN }
## v0.5 reward rarity. A reward is pure bonus: the rules never look at it.
## Escaping a SILVER / GOLD block by normal play pays its coin reward once
## (see Economy.reward_block_coins). DIAMOND is reserved for a future, very
## rare tier: the data model, map token and config key exist, no level
## uses it yet.
enum Rarity { NORMAL, SILVER, GOLD, DIAMOND }
const RARITY_NAMES := ["normal", "silver", "gold", "diamond"]
const RARITY_TOKENS := ["", "S", "G", "D"]  # level-map token after "$"
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
var rarity: int = Rarity.NORMAL

## --- v0.6 "Second Era" mechanics. Links use a group letter A / B / C, shown
## with the group's color AND letter, so every relationship is visible. ---
## SWITCH: when this block escapes, every block with flip_link == this group
## reverses its arrow (180 degrees). "" = not a switch.
var switch_group: String = ""
## Reverses its arrow when the switch of this group escapes. "" = none.
var flip_link: String = ""
## GATE blocks: the gate's group (its links carry gate_link == this group).
var gate_group: String = ""
## Counts toward the Chain Gate of this group: the gate opens when every
## block of the group has escaped. "" = not a link.
var gate_link: String = ""
## ARMORED: cannot escape while its shell is intact. The shell cracks when
## the player launches another block straight into it (see BoardModel.ram).
var armored: bool = false
## SEQUENCE PROTOTYPE (development only, ?mechlab=sequence): a two-stage
## arrow. seq_stage 0 = not a Sequence block; 1 = first stage (the arrow
## is `direction`, the NEXT arrow is `seq_next`); 2 = second stage (its
## first stage was activated: `direction` is now the former next arrow and
## it plays like a plain arrow). Stage 1 never leaves the board: with a
## clear lane it launches, comes back, sends the neighbour event (adjacent
## spinners turn, adjacent hidden arrows are revealed) and moves to stage 2.
var seq_stage: int = 0
var seq_next: int = -1

const LINK_GROUPS := ["A", "B", "C", "D"]
## Switches use A / B, Chain Gates C / D (their own letters and colors, so a
## switch is never mistaken for a gate).
const SWITCH_GROUPS := ["A", "B"]
const GATE_GROUPS := ["C", "D"]


func _init(p_id: int, p_cell: Vector2i, p_color: String, p_direction: int, p_kind: int = Kind.NORMAL) -> void:
	id = p_id
	cell = p_cell
	color = p_color
	direction = p_direction
	kind = p_kind


func is_spinner() -> bool:
	return kind == Kind.SPINNER


func is_gate() -> bool:
	return kind == Kind.GATE


func is_switch() -> bool:
	return switch_group != ""


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


## Sequence prototype: still in its first stage (a tap advances it).
func is_sequence_pending() -> bool:
	return seq_stage == 1


func is_reward() -> bool:
	return rarity != Rarity.NORMAL


func rarity_name() -> String:
	return RARITY_NAMES[rarity]


func is_lockable() -> bool:
	return lock_color != ""


func duplicate_data() -> BlockData:
	var b := BlockData.new(id, cell, color, direction, kind)
	b.lock_color = lock_color
	b.hidden = hidden
	b.spin_rule = spin_rule
	b.spin_step = spin_step
	b.rarity = rarity
	b.switch_group = switch_group
	b.flip_link = flip_link
	b.gate_group = gate_group
	b.gate_link = gate_link
	b.armored = armored
	b.seq_stage = seq_stage
	b.seq_next = seq_next
	return b
