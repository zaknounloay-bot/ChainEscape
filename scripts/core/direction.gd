class_name Direction
## Direction helpers shared by the model, views and level loader.
##
## Directions are stored as ints so they serialize cleanly into history
## snapshots and level data.

enum { UP, DOWN, LEFT, RIGHT }

const NAMES := ["up", "down", "left", "right"]

## Grid step for each direction, as Vector2i(column, row).
const STEPS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

## Single-character arrows used by the compact level "map" format.
const MAP_CHARS := {"^": UP, "v": DOWN, "<": LEFT, ">": RIGHT}


static func step(dir: int) -> Vector2i:
	return STEPS[dir]


## Screen-space unit vector (y grows downward, same as the grid).
static func vector(dir: int) -> Vector2:
	return Vector2(STEPS[dir])


## Next direction clockwise on screen: UP -> RIGHT -> DOWN -> LEFT -> UP.
static func rotate_cw(dir: int) -> int:
	return [RIGHT, LEFT, UP, DOWN][dir]


static func rotate_ccw(dir: int) -> int:
	return [LEFT, RIGHT, DOWN, UP][dir]


## Screen angle (radians) of an arrow pointing in `dir`, with RIGHT = 0.
static func angle(dir: int) -> float:
	return vector(dir).angle()


static func from_string(value: String) -> int:
	var idx := NAMES.find(value.strip_edges().to_lower())
	if idx == -1:
		push_error("Unknown direction '%s'" % value)
		return UP
	return idx


static func to_name(dir: int) -> String:
	return NAMES[dir]
