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
##
## Competition foundation (Phase 3B-A): what the MAX_FRAME cap left out is
## counted too (`discarded`, `capped_frames`, `longest_frame`) - metadata
## for a future validator only. It never changes `elapsed`, the shown time
## or the Personal Best. Only ACTIVE frames longer than MAX_FRAME count:
## pauses (inactive frames) and the dropped first frame after the page was
## hidden are intentional and add nothing. The attempt's FIRST active frame
## is kept apart (`start_frame`): it carries the level build / first render
## (measured 1.7-2.3 s in the Web build), which is not play.

## Longest single frame counted (seconds).
const MAX_FRAME := 0.25

## Active seconds of this attempt so far.
var elapsed: float = 0.0
## True once finish() ran (the winning move): nothing more is added.
var finished: bool = false
## The page / app is hidden (Safari in the background, phone locked, tab
## switched): nothing is added until it is visible again.
var page_hidden: bool = false
## Active time the MAX_FRAME cap did not count this attempt (seconds).
var discarded: float = 0.0
## Active frames longer than MAX_FRAME this attempt.
var capped_frames: int = 0
## The longest of those frames (seconds; 0 = none).
var longest_frame: float = 0.0
## The attempt's first active frame (seconds; 0 = none yet) - level load.
var start_frame: float = 0.0
var _skip_next: bool = false
var _started: bool = false


func reset() -> void:
	elapsed = 0.0
	finished = false
	_skip_next = false
	discarded = 0.0
	capped_frames = 0
	longest_frame = 0.0
	start_frame = 0.0
	_started = false


func tick(delta: float, active: bool) -> void:
	if finished or page_hidden:
		return
	if _skip_next:
		_skip_next = false  # this frame's delta spans the hidden time
		return
	if active and delta > 0.0:
		if not _started:
			_started = true
			start_frame = delta
			elapsed += minf(delta, MAX_FRAME)
		elif delta > MAX_FRAME:
			elapsed += MAX_FRAME
			discarded += delta - MAX_FRAME
			capped_frames += 1
			longest_frame = maxf(longest_frame, delta)
		else:
			elapsed += delta


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


func discarded_ms() -> int:
	return int(roundf(discarded * 1000.0))


## This attempt's cap metadata (for a future competitive submission).
func cap_info() -> Dictionary:
	return {"discarded_ms": discarded_ms(), "capped_frames": capped_frames, "longest_frame_ms": int(roundf(longest_frame * 1000.0)),
		"start_frame_ms": int(roundf(start_frame * 1000.0))}
