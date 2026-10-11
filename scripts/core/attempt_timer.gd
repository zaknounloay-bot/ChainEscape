class_name AttemptTimer
extends RefCounted
## ACTIVE-PLAY time of one level attempt (Timing + Personal Best).
##
## GameManager calls tick(delta, active) once per frame. Time only adds up
## while `active` (the board takes input and nothing blocks it: no NEW
## MECHANIC card, menu, title, card or out-of-hearts beat) and the page is
## visible. Each frame adds at most MAX_FRAME seconds, so one long frame
## (a stall, or the first frame after Safari resumes a suspended page) can
## never add more than that; the first frame after the page becomes
## visible again is dropped entirely. finish() freezes the attempt.
##
## A new attempt is a new AttemptTimer state (reset()): restart, retry
## after the hearts ran out, Level Select, NEXT - each starts at 0.
## Pure bookkeeping: no allocation, no I/O, no engine calls.

## Longest single frame counted (seconds).
const MAX_FRAME := 0.25

## Active seconds of this attempt so far.
var elapsed: float = 0.0
## True once finish() ran (the winning move): nothing more is added.
var finished: bool = false
## The page / app is hidden (Safari in the background, phone locked, tab
## switched): nothing is added until it is visible again.
var page_hidden: bool = false
var _skip_next: bool = false


func reset() -> void:
	elapsed = 0.0
	finished = false
	_skip_next = false


func tick(delta: float, active: bool) -> void:
	if finished or page_hidden:
		return
	if _skip_next:
		_skip_next = false  # this frame's delta spans the hidden time
		return
	if active and delta > 0.0:
		elapsed += minf(delta, MAX_FRAME)


func set_page_hidden(hidden: bool) -> void:
	if hidden == page_hidden:
		return
	page_hidden = hidden
	if not hidden:
		_skip_next = true


## Freezes the attempt (the winning move) and returns its time in ms.
func finish() -> int:
	finished = true
	return elapsed_ms()


func elapsed_ms() -> int:
	return int(roundf(elapsed * 1000.0))
