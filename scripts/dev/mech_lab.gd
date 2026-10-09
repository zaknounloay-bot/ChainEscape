class_name MechLab
extends CanvasLayer
## DEVELOPMENT ONLY: the mechanic lab - human tests of prototype mechanics.
##   ?mechlab=1 (or #mechlab=1; desktop "-- --mechlab")   PORTAL lab
##   ?mechlab=sequence (desktop "-- --mechlab=sequence")    SEQUENCE lab
##   ?mechlab=magnet   (desktop "-- --mechlab=magnet")      MAGNET lab (prototype;
##                     the "Web Magnet Lab" export always opens it)
## Without one of these nothing here runs or loads. Each mechanic has its
## own board file, state file, demo, questions and result fields (see
## MECHANICS); the PORTAL lab is exactly as it was before the SEQUENCE
## lab was added (its settings are the constants below).
##
## Plays a fixed board set (data/dev/mechlab_portal.json, built offline by
## tools/mechlab_portal_build.gd) through its own SocialPlay:
##   1. a short automatic demonstration of the portal rule,
##   2. the basic portal boards (stage A) in order,
##   3. the other portal boards and their matched CONTROL boards (same
##      blocks without the portal, turned 180 degrees), in a random order
##      per device; a board and its control are never back to back. Boards
##      are only numbered - nothing says which ones are controls.
## After each board: a few short questions (fewer for controls).
##
## Never touches the backend, sharing, Classic progress / save, Photo /
## Message or the Social screens: its only storage is its own file
## (user://mechlab_portal_state.json; on the Web also the browser's local
## storage). Results are copied as JSON (COPY RESULTS).
##
## Assistance (from the board file): UNDO x3, SHOW A MOVE x1, no HAMMER,
## RESTART (resets them, as in the game).

const PARAM := "mechlab"
const DATA_PATH := "res://data/dev/mechlab_portal.json"
const STATE_PATH := "user://mechlab_portal_state.json"
const LS_KEY := "chain_escape_mechlab_portal_state"
const LONG_PAUSE_MS := 10000
const ACCENT := Color("#12A88F")
const RATINGS := ["EASY", "MEDIUM", "HARD", "VERY HARD"]

## Questions: key -> [text, options]. Every one can be skipped.
const QUESTIONS := {
	"rating": ["How difficult was this puzzle?", RATINGS],
	"focus": ["What did you mainly have to\nthink about?", ["WHICH BLOCK TO START WITH", "THE ORDER OF MY MOVES",
		"CLEARING A FAR-AWAY AREA FIRST", "WHERE A BLOCK WOULD END UP", "NOTHING MUCH"]],
	"planning": ["Did the portal change how you\nplanned this puzzle?", ["NOT REALLY", "A LITTLE", "A LOT"]],
	"clarity": ["Was it clear where a block\nwould go?", ["CLEAR", "SOMETIMES UNCLEAR", "UNCLEAR"]],
	"interest": ["The portal made this puzzle...", ["MORE INTERESTING", "NO DIFFERENCE", "MORE ANNOYING"]],
}
## Which questions follow which board.
const ASK := {
	"A": ["rating", "clarity"],
	"portal": ["rating", "focus", "planning", "clarity", "interest"],
	"control": ["rating", "focus"],
}

## The demonstration: a tiny board and the taps the lab plays on it.
const DEMO_MAP := [
	".  .  .  .  .",
	"R> .  OA .  .",
	".  .  .  .  .",
	".  .  .  G^ .",
	"OA P> .  .  .",
]
const DEMO_STEPS := [
	[0.6, "", "PORTALS: a path that enters a portal\ncontinues from the other portal\nwith the same letter - same direction."],
	[3.4, "R", "Red's path enters A... and continues\nfrom the other A, where PURPLE\nis in the way. Red is blocked."],
	[6.6, "P", "Purple leaves."],
	[8.0, "R", "Now red's whole path is clear:\nin at A, out at the other A,\noff the board."],
	[10.6, "", "If the path after the portal is\nblocked, the block can't go.\nNow you try!"],
]

## SEQUENCE lab (?mechlab=sequence): its own questions, demo and files.
const SEQ_QUESTIONS := {
	"rating": ["How difficult was this puzzle?", RATINGS],
	"focus": ["What were you mainly\nthinking about?", ["WHICH BLOCK TO START WITH", "WHEN TO TRIGGER THE SEQUENCE",
		"WHAT THE SPINNER WOULD BECOME", "THE ORDER OF MY MOVES", "JUST TAPPING THE SEQUENCE TWICE", "NOTHING MUCH"]],
	"planning": ["Did the Sequence block make you think\nabout WHEN to activate its first stage?", ["NOT REALLY", "A LITTLE", "A LOT"]],
	"clarity": ["Was it clear what the Sequence\nblock would do?", ["CLEAR", "SOMEWHAT CLEAR", "CONFUSING"]],
	"interest": ["Compared with a similar normal puzzle,\nthe Sequence block made it...", ["MORE INTERESTING", "NO DIFFERENCE", "LESS INTERESTING"]],
}
const SEQ_ASK := {
	"A": ["rating", "clarity"],
	"sequence": ["rating", "focus", "planning", "clarity", "interest"],
	"control": ["rating", "focus"],
}
## Red: Sequence block (now right, next up). Green: a spinner below it,
## pointing down into blue. Red's first stage turns green to the left.
const SEQ_DEMO_MAP := [
	".  .    .  .  .",
	".  .    .  .  .",
	".  R>:^ .  .  .",
	".  Gv@  .  .  .",
	".  B^   .  .  .",
]
const SEQ_DEMO_STEPS := [
	[0.5, "", "SEQUENCE block (red): the BIG arrow is\nwhere it goes NOW. The SMALL arrow\nin the corner is what it becomes NEXT."],
	[3.6, "R", "First tap: it launches, comes BACK,\nand turns to its next arrow (up).\nIt stays - and the spinner next to it TURNS."],
	[6.8, "G", "The spinner turned - now it can leave."],
	[8.3, "R", "Second tap: it leaves with\nits new arrow."],
	[9.9, "", "WHEN you use the first stage matters:\nit turns the spinners next to it.\nNow you try!"],
]
## MOVABLE lab (?mechlab=movable): its own questions, demo and files.
const MOV_QUESTIONS := {
	"rating": ["How difficult was this puzzle?", RATINGS],
	"clarity": ["Was it clear what the MOVABLE\ncrate would do?", ["CLEAR", "NOT CLEAR"]],
	"interest": ["Compared with a similar normal puzzle,\nthe MOVABLE crate made it...", ["MORE INTERESTING", "NO DIFFERENCE", "LESS INTERESTING"]],
	"planning": ["Did the MOVABLE crate make you think about\nwhere the board would be after your move?", ["NOT REALLY", "A LITTLE", "A LOT"]],
	"focus": ["What were you thinking\nabout most?", ["WHERE TO MOVE THE MOVABLE BLOCK", "WHERE THE MOVABLE BLOCK WOULD END UP",
		"THE ORDER OF MY MOVES", "WHICH ARROW TO START WITH", "JUST PUSHING IT WHEN I COULD", "NOTHING MUCH"]],
	# Controls have no crate: the same kinds of answer, without it.
	"focus_control": ["What were you thinking\nabout most?", ["WHERE THINGS WOULD BE LATER", "THE ORDER OF MY MOVES",
		"WHICH ARROW TO START WITH", "JUST TAPPING WHAT COULD MOVE", "NOTHING MUCH"]],
}
const MOV_ASK := {
	"A": ["rating", "clarity"],
	"movable": ["rating", "focus", "planning", "clarity", "interest"],
	"control": ["rating", "focus_control"],
	"integration": ["rating", "clarity"],
}
## Red hits the crate: it slides one cell. Blue hits the other crate, but
## green sits right behind it: it can't move.
const MOV_DEMO_MAP := [
	".  .  .  .  .",
	"R> .  M  .  .",
	".  .  .  .  .",
	"B> M  G^ .  .",
	".  .  .  .  .",
]
const MOV_DEMO_STEPS := [
	[0.5, "", "MOVABLE crate: no arrow.\nAn arrow launched into it PUSHES it\nexactly ONE cell."],
	[3.0, "R", "Red hits the crate: the crate\nslides ONE cell. Red stays\nwhere it was."],
	[5.9, "B", "Something is right behind this crate:\nit CAN'T move. Nothing happens."],
	[8.4, "", "Crates never need to leave:\nclear every ARROW block.\nNow you try!"],
]
## MAGNET lab (?mechlab=magnet): three fixed boards - A introduction, B
## combination (with a spinner), C challenge - no controls.
const MAG_QUESTIONS := {
	"rating": ["How difficult was this puzzle?", RATINGS],
	"clarity": ["Was it clear WHICH block the MAGNET\nwould pull, and WHERE it would land?", ["CLEAR", "NOT CLEAR"]],
	"interest": ["Compared with a normal puzzle,\nthe MAGNET made it...", ["MORE INTERESTING", "NO DIFFERENCE", "LESS INTERESTING"]],
	"planning": ["Did you plan WHICH block the\nmagnet would pull before tapping it?", ["NOT REALLY", "A LITTLE", "A LOT"]],
	"focus": ["What were you thinking\nabout most?", ["WHICH BLOCK THE MAGNET WOULD PULL", "WHERE THE PULLED BLOCK WOULD LAND",
		"THE ORDER OF MY MOVES", "THE SPINNER", "JUST TAPPING WHAT COULD MOVE", "NOTHING MUCH"]],
	"fairness": ["If you got stuck: did it feel\nfair or surprising?", ["NEVER GOT STUCK", "FAIR - I SAW WHY", "SURPRISING"]],
}
const MAG_ASK := {
	"A": ["rating", "clarity"],
	"magnet": ["rating", "focus", "planning", "clarity", "interest", "fairness"],
}
## Red (a MAGNET) flies up: blue, behind it on the dotted line, slides into
## red's cell and is free. Purple's magnet has nothing behind it: nothing
## moves. Yellow was stuck facing blue: now free.
const MAG_DEMO_MAP := [
	".    .  .    .  .",
	".    .  R^*  .  .",
	".    .  .    .  .",
	".    .  B>   .  Y<",
	"P^*  .  .    .  .",
]
const MAG_DEMO_STEPS := [
	[0.5, "", "MAGNET: the horseshoe on its back.\nWhen it escapes, the block BEHIND it\nslides into its place."],
	[3.4, "R", "Red flies out - blue, at the end\nof the dotted line, slides into\nred's cell."],
	[6.4, "B", "From there blue's way is clear."],
	[8.4, "P", "Nothing behind purple's magnet:\nnothing moves."],
	[10.6, "Y", "And yellow is free too."],
	[12.6, "", "The dotted line shows WHICH block\nwill move and WHERE.\nNow you try!"],
]
## Per-mechanic settings. "portal" is the original lab, unchanged.
const MECHANICS := {
	"portal": {"data": DATA_PATH, "state": STATE_PATH, "ls": LS_KEY, "variant": "portal", "title": "PORTAL LAB",
		"demo_title": "HOW PORTALS WORK", "groups": [["B", "C"], ["D"]],
		"names": {"portal_A": "Basic portal", "portal": "Portal", "control": "Without portal"}},
	"sequence": {"data": "res://data/dev/mechlab_sequence.json", "state": "user://mechlab_sequence_state.json",
		"ls": "chain_escape_mechlab_sequence_state", "variant": "sequence", "title": "SEQUENCE LAB",
		"demo_title": "HOW SEQUENCE BLOCKS WORK", "groups": [["B", "C", "D"], ["E"]],
		"names": {"sequence_A": "Basic sequence", "sequence": "Sequence", "control": "Without sequence"}},
	# Stage F = Portal / Sequence integration checks, always last (not part
	# of the main movable-vs-control comparison).
	"movable": {"data": "res://data/dev/mechlab_movable.json", "state": "user://mechlab_movable_state.json",
		"ls": "chain_escape_mechlab_movable_state", "variant": "movable", "title": "MOVABLE LAB",
		"demo_title": "HOW MOVABLE CRATES WORK", "groups": [["B", "C", "D"], ["E"], ["F"]],
		"names": {"movable_A": "Basic movable", "movable": "Movable", "control": "Without movable", "integration": "Portal / Sequence checks"}},
	"magnet": {"data": "res://data/dev/mechlab_magnet.json", "state": "user://mechlab_magnet_state.json",
		"ls": "chain_escape_mechlab_magnet_state", "variant": "magnet", "title": "MAGNET LAB",
		"demo_title": "HOW MAGNETS WORK", "groups": [["B"], ["C"]],
		"names": {"magnet_A": "Introduction", "magnet": "Magnet"}},
}

enum Screen { INTRO, DEMO, PLAYING, QUESTION, RESULTS }

## "portal" or "sequence" (which lab this is).
var mechanic := "portal"
var _cfg: Dictionary = MECHANICS["portal"]
var _questions: Dictionary = QUESTIONS
var _ask: Dictionary = ASK
var _demo_map: Array = DEMO_MAP
var _demo_steps: Array = DEMO_STEPS

var boards: Dictionary = {}  # id -> record
var state: Dictionary = {}  # order, index, results, demo_seen
var screen: int = Screen.INTRO
var play: SocialPlay
var _assist: Dictionary = {"undo": 3, "show_a_move": 1, "hammer": 0}
var _current: Dictionary = {}
var _asks: Array = []
var _q := 0
var _t0 := 0
var _act_sig := []
var _last_act := 0
var _demo_session := 0
var _root: Control
var _pages: Dictionary = {}
var _intro_text: Label
var _start: PillButton
var _q_title: Label
var _q_box: VBoxContainer
var _results_text: Label
var _copy: PillButton
var _copy_status: Label
var _demo_layer: Control
var _demo_caption: Label
var _demo_buttons: HBoxContainer


## Checked at launch, like the VERY HARD tests.
static func requested() -> bool:
	return requested_mechanic() != ""


## "sequence" (?mechlab=sequence), "portal" (?mechlab=1 / =true / =portal)
## or "" (not asked for).
static func requested_mechanic() -> String:
	if BuildFlags.magnet_lab():
		return "magnet"  # the Magnet lab build: always (and only) this lab
	if BuildFlags.dev_pages_off():
		return ""  # player / QA build: developer pages off
	var args := OS.get_cmdline_user_args()
	if "--" + PARAM + "=magnet" in args:
		return "magnet"
	if "--" + PARAM + "=sequence" in args:
		return "sequence"
	if "--" + PARAM + "=movable" in args:
		return "movable"
	if "--" + PARAM in args:
		return "portal"
	if not OS.has_feature("web"):
		return ""
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return ""
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	if where.contains(PARAM + "=sequence"):
		return "sequence"
	if where.contains(PARAM + "=movable"):
		return "movable"
	if where.contains(PARAM + "=magnet"):
		return "magnet"
	if where.contains(PARAM + "=1") or where.contains(PARAM + "=true") or where.contains(PARAM + "=portal"):
		return "portal"
	return ""


func _init(p_mechanic: String = "portal") -> void:
	layer = 30  # over everything (SocialPlay is layer 5)
	mechanic = p_mechanic if MECHANICS.has(p_mechanic) else "portal"
	_cfg = MECHANICS[mechanic]
	if mechanic == "sequence":
		# Lab-only parsing of the Sequence token (off in the game and Social).
		LevelManager.dev_sequence = true
		_questions = SEQ_QUESTIONS
		_ask = SEQ_ASK
		_demo_map = SEQ_DEMO_MAP
		_demo_steps = SEQ_DEMO_STEPS
	elif mechanic == "movable":
		# Lab-only parsing of the crate token (and Sequence, for the
		# integration check boards).
		LevelManager.dev_movable = true
		LevelManager.dev_sequence = true
		_questions = MOV_QUESTIONS
		_ask = MOV_ASK
		_demo_map = MOV_DEMO_MAP
		_demo_steps = MOV_DEMO_STEPS
	elif mechanic == "magnet":
		# Lab-only parsing of the Magnet token (never in the game or Social).
		LevelManager.dev_magnet = true
		_questions = MAG_QUESTIONS
		_ask = MAG_ASK
		_demo_map = MAG_DEMO_MAP
		_demo_steps = MAG_DEMO_STEPS


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(_cfg["data"]))
	if typeof(data) == TYPE_DICTIONARY:
		_assist = data.get("assist", _assist)
		for b in data.get("boards", []):
			boards[str(b["id"])] = b
	_load_state()
	play = SocialPlay.new()
	play.max_hints = int(_assist.get("show_a_move", 1))
	play.max_hammers = int(_assist.get("hammer", 0))
	play.solved.connect(_on_solved)
	play.exited.connect(_on_gave_up)
	add_child(play)
	_build()
	_show(Screen.INTRO)


func _process(_delta: float) -> void:
	if screen == Screen.PLAYING:
		if _current.get("first_move_ms", -1) < 0 and _actions() > 0:
			_current["first_move_ms"] = Time.get_ticks_msec() - _t0
		_track_pauses()
		if mechanic == "sequence":
			_track_sequence()
		if mechanic == "movable" and _current.get("first_push_ms", -1) < 0 and play.total_pushes > 0:
			_current["first_push_ms"] = Time.get_ticks_msec() - _t0
		if mechanic == "magnet" and _current.get("first_pull_ms", -1) < 0 and play.total_pulls + play.total_empty_pulls > 0:
			_current["first_pull_ms"] = Time.get_ticks_msec() - _t0
	if screen == Screen.RESULTS:
		var r := SocialWeb.take_share_result()
		if r == "copied":
			_copy_status.text = "COPIED - paste it into the chat"
		elif r == "failed":
			_copy_status.text = "COULDN'T COPY - take a screenshot instead"


func _actions() -> int:
	return play.total_moves + play.total_blocked + play.total_rams + play.total_seq_advances + play.total_pushes


## Sequence lab: when a first-stage block first became usable (lane
## clear) and when the first advance happened (ms after the board opened).
func _track_sequence() -> void:
	if _current.get("seq_first_usable_ms", -1) < 0 and not play.completed:
		for id in play.model.blocks:
			if play.model.move_state(id) == "advance":
				_current["seq_first_usable_ms"] = Time.get_ticks_msec() - _t0
				break
	if _current.get("seq_first_advance_ms", -1) < 0 and play.total_seq_advances > 0:
		_current["seq_first_advance_ms"] = Time.get_ticks_msec() - _t0


# --- Flow ------------------------------------------------------------------------------

func total() -> int:
	return state["order"].size()


func start_next() -> void:
	var i: int = state["index"]
	if i >= total():
		_show(Screen.RESULTS)
		return
	var rec: Dictionary = boards[state["order"][i]]
	_current = {"id": rec["id"], "variant": rec["variant"], "stage": rec["stage"], "pair": rec["pair"], "order": i + 1,
		"first_move_ms": -1, "longest_pause_ms": 0, "long_pauses": []}
	if mechanic == "sequence":
		_current["seq_first_usable_ms"] = -1
		_current["seq_first_advance_ms"] = -1
	if mechanic == "movable":
		_current["first_push_ms"] = -1
	if mechanic == "magnet":
		_current["first_pull_ms"] = -1
	_show(Screen.PLAYING)
	_start_board(rec["puzzle"])
	play._title.text = "PUZZLE %d / %d" % [i + 1, total()]
	_t0 = Time.get_ticks_msec()
	_last_act = _t0
	_act_sig = []


func _start_board(puzzle: Dictionary) -> void:
	var def := PuzzleDefinition.from_dict(puzzle)
	var c := SharedChallenge.friend_challenge(def, FriendGenerator.MEDIUM)
	play.back_label = ""
	play.start(c, SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	play._chip.text = ""


func _on_solved() -> void:
	if screen != Screen.PLAYING:
		return
	_finish_attempt(true)
	await get_tree().create_timer(1.0).timeout
	_begin_questions()


func _on_gave_up() -> void:
	if screen == Screen.DEMO:
		return
	if screen != Screen.PLAYING:
		return
	_finish_attempt(false)
	_begin_questions()


func _track_pauses() -> void:
	var sig := [play.total_moves, play.total_blocked, play.total_rams, play.total_undos, play.total_hints, play.plays, play.total_seq_advances, play.total_pushes]
	if _act_sig.is_empty():
		_act_sig = sig
		return
	if sig == _act_sig:
		return
	_act_sig = sig
	var now := Time.get_ticks_msec()
	var gap := now - _last_act
	_last_act = now
	_current["longest_pause_ms"] = maxi(int(_current.get("longest_pause_ms", 0)), gap)
	if gap >= LONG_PAUSE_MS:
		var cleared := play._total_blocks - play.model.block_count()
		_current["long_pauses"].append({"ms": gap, "attempt": play.plays, "cleared": cleared, "of": play._total_blocks})


func _finish_attempt(solved: bool) -> void:
	_current["completed"] = solved
	_current["time_ms"] = Time.get_ticks_msec() - _t0
	_current["moves"] = play.total_moves
	_current["rams"] = play.total_rams
	_current["blocked_taps"] = play.total_blocked
	_current["portal_uses"] = play.total_portal_uses
	_current["portal_blocked_taps"] = play.total_portal_blocked
	_current["restarts"] = maxi(0, play.plays - 1)
	_current["undos"] = play.total_undos
	_current["show_a_move"] = play.total_hints
	if mechanic == "sequence":
		_current.erase("portal_uses")
		_current.erase("portal_blocked_taps")
		_current["seq_advances"] = play.total_seq_advances
		_current["seq_blocked_taps"] = play.total_seq_blocked
		_current["seq_escapes"] = play.total_seq_escapes
		_current["seq_spinner_turns"] = play.total_seq_spinner_turns
		# Each advance: when (ms after the board opened), in which attempt,
		# and how much of the board was already cleared at that moment.
		var events := []
		for e in play.seq_events:
			events.append({"ms": int(e["ms"]) - _t0, "cleared": e["cleared"], "of": e["of"], "turned": e["turned"]})
		_current["advances"] = events
	if mechanic == "movable":
		_current.erase("portal_blocked_taps")
		_movable_metrics()
	if mechanic == "magnet":
		# Magnet lab: escapes of a magnet that pulled a block / nothing (all
		# attempts of this board).
		_current.erase("portal_blocked_taps")
		_current.erase("portal_uses")
		_current["pulls"] = play.total_pulls
		_current["empty_pulls"] = play.total_empty_pulls


## Movable lab: pushes (all attempts of this board), blocked pushes, pushes
## by direction, distinct cells each crate occupied (its start included),
## corrections (a push straight back against that crate's previous push,
## and pushes back onto a cell that crate already visited in the same
## attempt), portal / Sequence pushes, and every push event (ms after the
## board opened, attempt, crate, from, to, direction, arrows cleared).
func _movable_metrics() -> void:
	_current["pushes"] = play.total_pushes
	_current["push_blocked"] = play.total_push_blocked
	_current["seq_advances"] = play.total_seq_advances
	var by_dir := {"up": 0, "down": 0, "left": 0, "right": 0}
	var start := {}  # crate -> starting cell
	var level := PuzzleDefinition.from_dict(boards[_current["id"]]["puzzle"]).to_level()
	for b in level.blocks:
		if b.is_crate():
			start[b.id] = [b.cell.x, b.cell.y]
	var seen := {}
	for cid in start:
		seen[str([cid, start[cid]])] = true
	var reversals := 0
	var revisits := 0
	var portal_pushes := 0
	var seq_pushes := 0
	var last_dir := {}
	var visited := {}  # attempt-crate -> cells
	var events := []
	for e in play.push_events:
		by_dir[e["dir"]] += 1
		seen[str([e["crate"], e["to"]])] = true
		var key := "%d-%d" % [e["attempt"], e["crate"]]
		if not visited.has(key):
			visited[key] = {str(start.get(e["crate"], [])): true}
			last_dir.erase(key)
		if visited[key].has(str(e["to"])):
			revisits += 1
		visited[key][str(e["to"])] = true
		var opposite := {"up": "down", "down": "up", "left": "right", "right": "left"}
		if last_dir.get(key, "") == opposite[e["dir"]]:
			reversals += 1
		last_dir[key] = e["dir"]
		portal_pushes += 1 if e["portal"] else 0
		seq_pushes += 1 if e["sequence"] else 0
		events.append({"ms": int(e["ms"]) - _t0, "attempt": e["attempt"], "crate": e["crate"], "from": e["from"], "to": e["to"],
			"dir": e["dir"], "cleared": e["cleared"], "of": e["of"], "portal": e["portal"], "sequence": e["sequence"]})
	_current["pushes_by_dir"] = by_dir
	_current["crate_positions"] = seen.size()
	_current["push_reversals"] = reversals
	_current["push_revisits"] = revisits
	_current["portal_pushes"] = portal_pushes
	_current["sequence_pushes"] = seq_pushes
	_current["push_events"] = events


func _begin_questions() -> void:
	var v: String = _current["variant"]
	_asks = _ask["A"] if v != "control" and _current["stage"] == "A" else _ask[v]
	_q = 0
	_show(Screen.QUESTION)


## Answer to the question showing ("" = skipped); then the next one, or
## the next board.
func answer(text: String) -> void:
	_current[_asks[_q]] = text
	_q += 1
	if _q < _asks.size():
		_show(Screen.QUESTION)
		return
	play.end()
	state["results"].append(_current.duplicate())
	state["index"] = int(state["index"]) + 1
	_save_state()
	_current = {}
	start_next()


func reset_test() -> void:
	state = {}
	_new_order()
	_save_state()
	_show(Screen.INTRO)


# --- Demonstration ----------------------------------------------------------------------

func start_demo() -> void:
	_show(Screen.DEMO)
	_demo_session += 1
	var session := _demo_session
	var rows := []
	for row in _demo_map:
		rows.append(" ".join(String(row).split(" ", false)))
	_start_board({"format": PuzzleDefinition.FORMAT, "v": PuzzleDefinition.VERSION, "rules": PuzzleDefinition.RULES,
		"rows": rows.size(), "cols": String(rows[0]).split(" ", false).size(), "map": rows})
	play._title.text = _cfg["demo_title"]
	_demo_buttons.visible = false
	var t0 := 0.0
	for step in _demo_steps:
		await get_tree().create_timer(float(step[0]) - t0).timeout
		t0 = float(step[0])
		if session != _demo_session or screen != Screen.DEMO:
			return
		_demo_caption.text = step[2]
		if step[1] != "":
			for id in play.model.blocks:
				if play.model.blocks[id].color == LevelManager.COLOR_LETTERS[step[1]]:
					play.tap_block(id)
					break
	_demo_buttons.visible = true
	state["demo_seen"] = true
	_save_state()
	_update_zones.call_deferred()
	_publish()


func _end_demo() -> void:
	_demo_session += 1
	play.end()


# --- State (this file only) -------------------------------------------------------------

func _load_state() -> void:
	var path: String = _cfg["state"]
	var texts := [FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""]
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(_cfg["ls"]))
	var best = null
	for t in texts:
		var parsed = JSON.parse_string(t) if t != "" else null
		if typeof(parsed) == TYPE_DICTIONARY and parsed.get("order", []).size() == boards.size() \
				and parsed["order"].all(func(id): return boards.has(str(id))) \
				and (best == null or parsed.get("results", []).size() > best.get("results", []).size()):
			best = parsed
	if best != null:
		state = best
		state["index"] = int(state["index"])
	else:
		_new_order()
		_save_state()


## Stage A boards first, in order; then stages B + C, then stage D, each
## shuffled so a board and its matched control are never back to back.
func _new_order() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var order := []
	var ids := boards.keys()
	ids.sort()
	for id in ids:
		if boards[id]["stage"] == "A":
			order.append(id)
	for stages in _cfg["groups"]:
		var group := ids.filter(func(id): return boards[id]["stage"] in stages)
		order.append_array(_shuffle_apart(group, rng))
	state = {"order": order, "index": 0, "results": [], "demo_seen": false, "started": Time.get_datetime_string_from_system()}


func _shuffle_apart(group: Array, rng: RandomNumberGenerator) -> Array:
	var best := group.duplicate()
	for attempt in 400:
		var g := group.duplicate()
		for i in range(g.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = g[i]
			g[i] = g[j]
			g[j] = t
		var ok := true
		for i in range(1, g.size()):
			if boards[g[i]]["pair"] == boards[g[i - 1]]["pair"]:
				ok = false
				break
		best = g
		if ok:
			break
	return best


func _save_state() -> void:
	var text := JSON.stringify(state)
	var f := FileAccess.open(_cfg["state"], FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	if OS.has_feature("web"):
		WebBridge.ls_set(_cfg["ls"], text)


# --- Results ----------------------------------------------------------------------------

func results_json() -> String:
	return JSON.stringify({"format": "ce-mechlab-results", "v": 1, "mechanic": mechanic, "started": state.get("started", ""),
		"device": OS.get_name(), "assist": _assist, "demo_seen": state.get("demo_seen", false),
		"order": state["order"], "results": state["results"], "summary": summary(), "pairs": pairs()})


## Per group: basic boards (stage A), the mechanic's other boards, controls.
## Counters: the portal lab's (portal uses...) or the sequence lab's.
func summary() -> Dictionary:
	var out := {}
	var counters := ["restarts", "undos", "show_a_move", "blocked_taps", "portal_blocked_taps", "portal_uses"]
	if mechanic == "sequence":
		counters = ["restarts", "undos", "show_a_move", "blocked_taps", "seq_advances", "seq_blocked_taps", "seq_escapes", "seq_spinner_turns"]
	elif mechanic == "movable":
		counters = ["restarts", "undos", "show_a_move", "blocked_taps", "pushes", "push_blocked", "push_reversals", "push_revisits", "portal_pushes", "sequence_pushes"]
	elif mechanic == "magnet":
		counters = ["restarts", "undos", "show_a_move", "blocked_taps", "pulls", "empty_pulls"]
	for r in state["results"]:
		var g: String = r["variant"] + "_A" if r["variant"] != "control" and r["stage"] == "A" else r["variant"]
		if not out.has(g):
			out[g] = {"n": 0, "solved": 0, "time_s": [], "rating": [], "very_hard": 0, "hard": 0, "long_pauses": 0, "answers": {}}
			for k in counters:
				out[g][k] = 0
		var s: Dictionary = out[g]
		s["n"] += 1
		s["solved"] += 1 if r["completed"] else 0
		if r["completed"]:
			s["time_s"].append(snappedf(r["time_ms"] / 1000.0, 0.1))
		var ri := RATINGS.find(r.get("rating", ""))
		if ri >= 0:
			s["rating"].append(ri + 1)
		s["very_hard"] += 1 if r.get("rating", "") == "VERY HARD" else 0
		s["hard"] += 1 if r.get("rating", "") == "HARD" else 0
		for k in counters:
			s[k] += int(r.get(k, 0))
		s["long_pauses"] += r.get("long_pauses", []).size()
		for k in ["focus", "planning", "clarity", "interest", "focus_control", "fairness"]:
			if r.has(k) and r[k] != "":
				if not s["answers"].has(k):
					s["answers"][k] = {}
				s["answers"][k][r[k]] = s["answers"][k].get(r[k], 0) + 1
	for g in out:
		var s: Dictionary = out[g]
		var t: Array = s["time_s"]
		t.sort()
		s["median_time_s"] = t[t.size() / 2] if not t.is_empty() else -1
		s["avg_rating_1to4"] = snappedf(s["rating"].reduce(func(a, b): return a + b, 0) / float(maxi(s["rating"].size(), 1)), 0.01)
	return out


## Matched pairs played so far: the mechanic's board vs its control.
func pairs() -> Array:
	var by_id := {}
	for r in state["results"]:
		by_id[r["id"]] = r
	var out := []
	for id in by_id:
		var r: Dictionary = by_id[id]
		if r["variant"] != "control" or not by_id.has(r["pair"]):
			continue
		var p: Dictionary = by_id[r["pair"]]
		var main := {"rating": p.get("rating", ""), "time_s": snappedf(p["time_ms"] / 1000.0, 0.1), "moves": p["moves"], "restarts": p["restarts"], "undos": p["undos"], "focus": p.get("focus", ""), "order": p["order"]}
		if mechanic == "movable":
			main["planning"] = p.get("planning", "")
			main["interest"] = p.get("interest", "")
			main["pushes"] = p.get("pushes", 0)
			main["push_reversals"] = p.get("push_reversals", 0)
			main["crate_positions"] = p.get("crate_positions", 0)
		if mechanic == "sequence":
			main["planning"] = p.get("planning", "")
			main["interest"] = p.get("interest", "")
			main["seq_advances"] = p.get("seq_advances", 0)
			main["seq_spinner_turns"] = p.get("seq_spinner_turns", 0)
		out.append({"pair": r["pair"], str(_cfg["variant"]): main,
			"control": {"rating": r.get("rating", ""), "time_s": snappedf(r["time_ms"] / 1000.0, 0.1), "moves": r["moves"], "restarts": r["restarts"], "undos": r["undos"], "focus": r.get("focus", r.get("focus_control", "")), "order": r["order"]}})
	return out


func _summary_text() -> String:
	var lines := ["%d of %d puzzles played." % [state["results"].size(), total()], ""]
	if int(state["index"]) < total():
		lines.append("The comparison appears when every puzzle is done.")
		lines.append("")
		lines.append("Tap COPY RESULTS and paste it into the chat.")
		return "\n".join(lines)
	var sm := summary()
	var v: String = _cfg["variant"]
	for g in [v + "_A", v, "control", "integration"]:
		if not sm.has(g):
			continue
		var s: Dictionary = sm[g]
		lines.append("%s: %d played, %d solved, median %ss, rated %.1f / 4, restarts %d, UNDO %d" % [
			_cfg["names"][g], s["n"], s["solved"], str(s["median_time_s"]),
			s["avg_rating_1to4"], s["restarts"], s["undos"]])
	lines.append("")
	for p in pairs():
		lines.append("Pair %s: %s %s vs without %s" % [p["pair"], v, p[v]["rating"], p["control"]["rating"]])
	lines.append("")
	lines.append("Tap COPY RESULTS and paste it into the chat.")
	return "\n".join(lines)


# --- Screens ----------------------------------------------------------------------------

func _show(s: int) -> void:
	screen = s
	for k in _pages:
		_pages[k].visible = k == s
	_root.visible = s != Screen.PLAYING and s != Screen.DEMO
	_demo_layer.visible = s == Screen.DEMO
	match s:
		Screen.INTRO:
			var i: int = state["index"]
			_intro_text.text = ((("MAGNET LAB (prototype): %d puzzles.\n\n" % total()
				+ "A MAGNET (the horseshoe on its back) escapes like any arrow. Then the first block straight BEHIND it slides into the cell it left - the dotted line shows which block and where. Nothing behind it: nothing moves.\n\n")
				if mechanic == "magnet" else (("PORTAL LAB: %d puzzles. Some have PORTALS, some don't.\n\n" % total()
				+ "A path that enters a portal continues from the other portal with the same letter, in the same direction.\n\n")
				if mechanic == "portal" else (("SEQUENCE LAB: %d puzzles. Some have SEQUENCE blocks, some don't.\n\n" % total()
				+ "A Sequence block shows its arrow NOW (big) and its NEXT arrow (small, in the corner). The first tap with a clear path launches it and brings it back with its next arrow - spinners next to it turn. The second tap lets it leave.\n\n")
				if mechanic == "sequence" else ("MOVABLE LAB: %d puzzles. Some have MOVABLE crates, some don't.\n\n" % total()
				+ "A crate has no arrow and never has to leave. An arrow launched into it pushes it exactly ONE cell (the arrow stays). If something is right behind the crate, or the edge, it can't move.\n\n"))))
				+ "You have UNDO x%d and SHOW A MOVE x%d per attempt (no HAMMER); RESTART gives them back.\n\n" % [int(_assist["undo"]), int(_assist["show_a_move"])]
				+ "To give up on a puzzle, tap EXIT and LEAVE. After each puzzle: a few quick questions.")
			_start.text = "WATCH THE DEMO" if i == 0 and not state.get("demo_seen", false) else ("START" if i == 0 else ("CONTINUE  %d / %d" % [i + 1, total()] if i < total() else "SEE RESULTS"))
		Screen.QUESTION:
			var key: String = _asks[_q]
			var q: Array = _questions[key]
			var head := ""
			if _q == 0:
				head = "PUZZLE %d / %d  %s\n\n" % [_current.get("order", 0), total(), "SOLVED" if _current.get("completed", false) else "NOT SOLVED"]
			_q_title.text = head + str(q[0])
			for c in _q_box.get_children():
				_q_box.remove_child(c)
				c.queue_free()
			for o in q[1]:
				var b := _button(o, "Answer_%s" % String(o).replace(" ", "_"), Palette.WHITE, Palette.TEXT, 26)
				b.pressed.connect(func():
					AudioManager.play_ui_tap()
					answer(o))
				_q_box.add_child(b)
			var skip := _button("SKIP", "Answer_SKIP", Palette.BACKGROUND, Palette.TEXT_SOFT, 26)
			skip.pressed.connect(func(): answer(""))
			_q_box.add_child(skip)
		Screen.RESULTS:
			_results_text.text = _summary_text()
			_copy_status.text = ""
			SocialWeb.set_share(results_json(), "", "")
	_update_zones.call_deferred()
	_publish.call_deferred()


func _update_zones() -> void:
	await get_tree().process_frame
	var zones := []
	if screen == Screen.RESULTS and _copy.is_visible_in_tree():
		var vis := get_viewport().get_visible_rect().size
		var r := _copy.get_global_rect()
		zones.append({"id": "copy", "x": r.position.x / vis.x, "y": r.position.y / vis.y, "w": r.size.x / vis.x, "h": r.size.y / vis.y})
	SocialWeb.set_zones(zones)
	_publish()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Palette.BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# INTRO
	var intro := _column()
	intro.add_child(_label(str(_cfg["title"]) + "\n(DEVELOPMENT)", 40, 900))
	_intro_text = _label("", 26, 700)
	intro.add_child(_intro_text)
	_start = _button("START", "Start", ACCENT, Palette.WHITE)
	_start.pressed.connect(func():
		AudioManager.play_ui_tap()
		if int(state["index"]) >= total():
			_show(Screen.RESULTS)
		elif int(state["index"]) == 0 and not state.get("demo_seen", false):
			start_demo()
		else:
			start_next())
	intro.add_child(_start)
	var demo := _button("REPLAY THE DEMO", "Demo", Palette.WHITE, Palette.TEXT)
	demo.pressed.connect(start_demo)
	intro.add_child(demo)
	var see := _button("RESULTS SO FAR", "Results", Palette.WHITE, Palette.TEXT)
	see.pressed.connect(func(): _show(Screen.RESULTS))
	intro.add_child(see)
	_pages[Screen.INTRO] = intro
	# QUESTION
	var qcol := _column()
	_q_title = _label("", 32, 900)
	qcol.add_child(_q_title)
	_q_box = VBoxContainer.new()
	_q_box.add_theme_constant_override("separation", 16)
	qcol.add_child(_q_box)
	_pages[Screen.QUESTION] = qcol
	# RESULTS
	var res := _column()
	res.add_child(_label("RESULTS", 40, 900))
	_results_text = _label("", 22, 700)
	_results_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	res.add_child(_results_text)
	_copy = _button("COPY RESULTS", "CopyResults", ACCENT, Palette.WHITE)
	res.add_child(_copy)  # the copy itself runs in the page script, inside the tap (iOS)
	_copy_status = _label("", 22, 800)
	res.add_child(_copy_status)
	var back := _button("BACK", "Back", Palette.WHITE, Palette.TEXT)
	back.pressed.connect(func(): _show(Screen.INTRO))
	res.add_child(back)
	var reset := _button("START OVER (CLEARS RESULTS)", "Reset", Palette.BACKGROUND, Palette.TEXT_SOFT)
	reset.pressed.connect(reset_test)
	res.add_child(reset)
	_pages[Screen.RESULTS] = res
	# DEMO: over the playing board; swallows taps (the lab plays the moves),
	# caption at the top, buttons over the tool bar.
	_demo_layer = Control.new()
	_demo_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_demo_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_demo_layer)
	var cap_bg := ColorRect.new()
	cap_bg.color = Palette.BACKGROUND
	cap_bg.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cap_bg.offset_top = 0.0
	cap_bg.offset_bottom = 250.0
	_demo_layer.add_child(cap_bg)
	_demo_caption = _label("", 28, 800)
	_demo_caption.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_demo_caption.offset_left = 30.0
	_demo_caption.offset_right = -30.0
	_demo_caption.offset_top = 30.0
	_demo_caption.offset_bottom = 240.0
	_demo_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_demo_layer.add_child(_demo_caption)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.94)
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bg.offset_top = -200.0
	_demo_layer.add_child(bar_bg)
	_demo_buttons = HBoxContainer.new()
	_demo_buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_demo_buttons.offset_left = 30.0
	_demo_buttons.offset_right = -30.0
	_demo_buttons.offset_top = -170.0
	_demo_buttons.offset_bottom = -50.0
	_demo_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_demo_buttons.add_theme_constant_override("separation", 20)
	_demo_layer.add_child(_demo_buttons)
	var again := _button("WATCH AGAIN", "DemoAgain", Palette.WHITE, Palette.TEXT, 26)
	again.custom_minimum_size = Vector2(280, 100)
	again.pressed.connect(func():
		AudioManager.play_ui_tap()
		start_demo())
	_demo_buttons.add_child(again)
	var go := _button("START PUZZLES", "DemoDone", ACCENT, Palette.WHITE, 26)
	go.custom_minimum_size = Vector2(320, 100)
	go.pressed.connect(func():
		AudioManager.play_ui_tap()
		_end_demo()
		if int(state["index"]) < total():
			start_next()
		else:
			_show(Screen.INTRO))
	_demo_buttons.add_child(go)
	_demo_layer.visible = false


func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40.0
	box.offset_right = -40.0
	box.offset_top = 90.0
	box.offset_bottom = -60.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	_root.add_child(box)
	return box


func _label(t: String, fs: int, weight: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Palette.TEXT)
	return l


func _button(t: String, n: String, bg: Color, fg: Color, fs: int = 30) -> PillButton:
	var b := PillButton.new(t, PillButton.Icon.NONE, bg, fg, fs)
	b.name = n
	b.custom_minimum_size = Vector2(0, 96)
	return b


## Web: read-only snapshot for automated browser tests (window.chainEscapeMechLab).
func _publish() -> void:
	if not OS.has_feature("web") or not is_inside_tree():
		return
	var vis := get_viewport().get_visible_rect().size
	var buttons := {}
	var holders := [_demo_buttons] if screen == Screen.DEMO else ([_pages[screen]] if _pages.has(screen) else [])
	for h in holders:
		for b in h.find_children("*", "BaseButton", true, false):
			if b.is_visible_in_tree():
				var c: Vector2 = b.get_global_rect().get_center()
				buttons[String(b.name)] = [snappedf(c.x / vis.x, 0.0001), snappedf(c.y / vis.y, 0.0001)]
	WebBridge.publish("chainEscapeMechLab", {"screen": Screen.keys()[screen], "index": state.get("index", 0), "total": total(),
		"results": state.get("results", []).size(), "question": _asks[_q] if screen == Screen.QUESTION else "", "buttons": buttons})
