class_name VhHumanTest
extends CanvasLayer
## DEVELOPMENT ONLY: blind human test of VERY HARD boards (phase 3d).
## Opens only when the page address has ?vhtest=1 (or #vhtest=1; desktop:
## "-- --vhtest"). Plays a fixed board set (data/dev/vh_human_test.json,
## built offline by tools/vh_human_test_build.gd) through its own
## SocialPlay, in a random order per device, without telling the tester
## which variant a board comes from. After each board: "How difficult was
## this puzzle?" and an optional "Did you have to stop and think before
## your first move?".
##
## Never touches the backend, sharing, Classic progress / save, Photo /
## Message or the Social screens: its only storage is its own file
## (user://vh_human_test_state.json; on the Web, the browser's local
## storage). Results can be copied as JSON (COPY RESULTS) and pasted back.
##
## Assistance for this test (VERY HARD candidate): UNDO x3, SHOW A MOVE x1,
## HAMMER x1, RESTART; reset on every RESTART, as in the game.
##
## Two tests share this page (each with its own board file, state file and
## second question):
##   ?vhtest=1   test 1 (A current VERY HARD / B heuristic-selected / C locks)
##   ?vhtest2=1  test 2 (B strongest Friend / D pure Classic / E flattened
##               late-Classic geometry), second question: "Was it
##               immediately obvious which block you could start with?"
##   ?vhtest4=1  GATE 0 PILOT (data/dev/vh_pilot4.json, tools/vh_pilot4_build.gd):
##               28 boards in five hidden groups, using existing campaign
##               mechanics (switch, gate, spinner rules, lock, armor,
##               portal, Sequence, Movable). Before the first puzzle the
##               tester says how far they have played the campaign, and
##               only boards whose mechanics they have met are served, in a
##               balanced order (one of each group per round). Each puzzle
##               starts with a neutral one-line reminder of its mechanics.
##               While playing: a clock and GIVE UP (tap twice). After each
##               puzzle: difficulty, vs Level 300, enjoyment 1-5,
##               achievement 1-5, random / unfair. At the end: which was the
##               hardest, and why. Every action is logged (time, kind,
##               tapped block) for offline replay. &bench=1 times the
##               recipient's check and SHOW A MOVE on every board instead.
##               Campaign tokens (Sequence ":", Movable "M") are parsed
##               only while this page runs, as the mechanic lab does.
##   ?xtest5=1   EXTREME RESEARCH (data/dev/extreme5.json,
##               tools/extreme5_build.gd, docs/extreme5.md): five
##               prototypes, each testing one strategic difficulty
##               hypothesis. Same flow as the pilot, with a five-step
##               rating (EASY ... EXTREME), and after it: vs Level 300,
##               enjoyment, achievement, fairness, meaningful planning.
##               Blocked taps are logged too ("b"). Magnet ("*") is parsed
##               while this page runs, as the Magnet lab does. The play
##               screen's difficulty label is left blank (no anchoring).
##   ?xtest6=1   EXTREME PHASE 2 (data/dev/extreme6.json,
##               tools/extreme6_build.gd, docs/extreme6.md): six enriched
##               VERY HARD candidates (magnet + switch / gate, armor +
##               magnet, portal + spinner + gate). The same flow and
##               questions as ?xtest5, plus "did the combination of
##               mechanics make it more interesting?". Before the first
##               puzzle of a group whose combination the campaign never
##               used, a tiny interactive DEMO (the board file's "demos"):
##               one rule, played by the tester, never rated, never the
##               puzzle's solution.
##   ?xtest7=1   EXTREME DESIGN EXPERIMENT (data/dev/extreme7.json,
##               tools/extreme7_build.gd, docs/extreme7.md): two
##               hand-designed VERY HARD candidates (switch / gate +
##               spinners; magnet + armor + spinners). The same flow and
##               questions as ?xtest6 (including the combination
##               question); no demos (every rule here is taught by the
##               campaign or by the ?xtest6 demos).
##   ?vhval3=1   VERY HARD VALIDATION (data/dev/vh_validation3.json,
##               tools/vhval3_build.gd): three previously tested boards
##               (T3, T5, H2) copied unchanged, for an independent second
##               player. Neutral ids and groups, random order, no labels,
##               no explanations; the same flow and questions as ?xtest7.
##   ?xtest8=1   EXTREME EXPERT EXPERIMENT (data/dev/extreme8.json,
##               tools/extreme8_build.gd, docs/extreme8.md): three
##               concept-first EXTREME candidates for experienced players.
##               The same flow and questions as ?xtest7, plus an optional
##               free-text answer ("what made it difficult or interesting?")
##               and the mechanism events of every move in the log (gate
##               opened, block pulled, arrow reversed, spinners turned,
##               shell cracked).
##   ?ptest11=1  EXTREME PHASE 6 (data/dev/extreme11.json,
##               tools/extreme11_build.gd, docs/extreme11.md): one board,
##               a neutral id, the ?xtest8 flow and questions, and the
##               EXPERIMENTAL SHOW A MOVE RULE (this mode only; SocialPlay
##               and every other mode keep theirs - docs/extreme11.md):
##               ONE SHOW A MOVE for the whole puzzle, kept spent through
##               RESTART, UNDO, a page refresh and coming back later (this
##               mode's own state, saved before the answer shows). A press
##               with it available always spends it: the position can be
##               cleared - a move is highlighted; it can't - "Can't be
##               cleared from here" (paid, never a free dead-end check). A
##               board with no legal move at all (the screen already says
##               "No moves left") spends nothing. Once spent, every press
##               gets the same answer and the solver is not consulted.
##               Every press is logged (outcome, attempt); the puzzle in
##               progress survives a refresh (log, time and totals carry
##               on; the board starts again - logged as "o").

## EXTREME research: the rating and the follow-up questions.
const X_RATINGS := ["EASY", "MEDIUM", "HARD", "VERY HARD", "EXTREME"]
const X_QUESTIONS := [
	["l300", "Compared with Campaign Level 300,\nthis puzzle was...", "vs Level 300", ["EASIER", "SIMILAR", "HARDER", "NOT SURE"]],
	["enjoy", "How much did you enjoy it?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["achieve", "How strong was your sense\nof achievement?\n(1 = none, 5 = very strong)", "achievement", ["1", "2", "3", "4", "5"]],
	["fair", "Did the puzzle feel fair?", "fair", ["YES", "MOSTLY", "NO"]],
	["planned", "Did it require real planning\n(thinking several moves ahead)?", "needed planning", ["YES", "A LITTLE", "NO"]],
]
## EXTREME phase 2: the ?xtest5 questions plus the combination question.
const X6_QUESTIONS := [
	["l300", "Compared with Campaign Level 300,\nthis puzzle was...", "vs Level 300", ["EASIER", "SIMILAR", "HARDER", "NOT SURE"]],
	["enjoy", "How much did you enjoy it?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["achieve", "How strong was your sense\nof achievement?\n(1 = none, 5 = very strong)", "achievement", ["1", "2", "3", "4", "5"]],
	["fair", "Did the puzzle feel fair?", "fair", ["YES", "MOSTLY", "NO"]],
	["planned", "Did it require real planning\n(thinking several moves ahead)?", "needed planning", ["YES", "A LITTLE", "NO"]],
	["combo", "Did the combination of mechanics\nmake the puzzle more interesting?", "combination more interesting", ["YES", "A LITTLE", "NO"]],
]
## EXTREME expert experiment: the ?xtest6 questions plus optional free text
## (options ["TEXT"]: a text field with NEXT, or SKIP).
const X8_QUESTIONS := [
	["l300", "Compared with Campaign Level 300,\nthis puzzle was...", "vs Level 300", ["EASIER", "SIMILAR", "HARDER", "NOT SURE"]],
	["enjoy", "How much did you enjoy it?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["achieve", "How strong was your sense\nof achievement?\n(1 = none, 5 = very strong)", "achievement", ["1", "2", "3", "4", "5"]],
	["fair", "Did the puzzle feel fair?", "fair", ["YES", "MOSTLY", "NO"]],
	["planned", "Did it require real planning\n(thinking several moves ahead)?", "needed planning", ["YES", "A LITTLE", "NO"]],
	["combo", "Did the combination of mechanics\nmake the puzzle more interesting?", "combination more interesting", ["YES", "A LITTLE", "NO"]],
	["feedback", "Optional: what made this puzzle\ndifficult or interesting?", "feedback", ["TEXT"]],
]
const PARAM := "vhtest"
const DATA_PATH := "res://data/dev/vh_human_test.json"
const STATE_PATH := "user://vh_human_test_state.json"
const TESTS := {
	"vhtest": {"data": DATA_PATH, "state": STATE_PATH, "title": "VERY HARD TEST\n(DEVELOPMENT)",
		"q2": "Did you have to stop and think\nbefore your first move?", "q2_key": "think_first", "q2_label": "stopped to think",
		"ls": "chain_escape_vhtest_state"},
	"vhtest2": {"data": "res://data/dev/vh_human_test2.json", "state": "user://vh_human_test2_state.json", "title": "VERY HARD TEST 2\n(DEVELOPMENT)",
		"q2": "Was it immediately obvious which\nblock you could start with?", "q2_key": "start_obvious", "q2_label": "start obvious",
		"ls": "chain_escape_vhtest2_state"},
	# Test 3: controlled variable = clockwise + counter-clockwise spinners;
	# HAMMER x0 for every board (from the board file's "assist").
	"vhtest3": {"data": "res://data/dev/vh_human_test3.json", "state": "user://vh_human_test3_state.json", "title": "VERY HARD TEST 3\n(DEVELOPMENT)",
		"q2": "During the puzzle, did you have to\nstop and plan your next moves?", "q2_key": "planned", "q2_label": "had to plan",
		"q3": "Did a move that looked right turn out\nto be a mistake later?", "q3_key": "late_mistake", "q3_label": "late mistake",
		"note": "Spinners turn when a block next to them leaves. The arrowheads on a spinner's ring show which way it turns: some turn clockwise, some counter-clockwise.",
		"ls": "chain_escape_vhtest3_state"},
	# Gate 0 pilot: advanced campaign mechanics (see the header).
	"vhtest4": {"data": "res://data/dev/vh_pilot4.json", "state": "user://vh_pilot4_state.json", "title": "VERY HARD PILOT\n(DEVELOPMENT)",
		"q2": "", "q2_key": "l300", "q2_label": "harder than L300", "pilot": true,
		"ls": "chain_escape_vhtest4_state"},
	# EXTREME research prototypes (see the header).
	"xtest5": {"data": "res://data/dev/extreme5.json", "state": "user://extreme5_state.json", "title": "EXTREME RESEARCH\n(DEVELOPMENT)",
		"q2": "", "q2_key": "l300", "q2_label": "harder than L300", "pilot": true, "ratings": X_RATINGS, "questions": X_QUESTIONS,
		"log_blocked": true, "hide_difficulty": true, "ls": "chain_escape_xtest5_state"},
	# EXTREME phase 2 (see the header).
	"xtest6": {"data": "res://data/dev/extreme6.json", "state": "user://extreme6_state.json", "title": "PUZZLE PILOT 2\n(DEVELOPMENT)",
		"q2": "", "q2_key": "l300", "q2_label": "harder than L300", "pilot": true, "ratings": X_RATINGS, "questions": X6_QUESTIONS,
		"log_blocked": true, "hide_difficulty": true, "demos": true, "ls": "chain_escape_xtest6_state"},
	# EXTREME design experiment (see the header).
	"xtest7": {"data": "res://data/dev/extreme7.json", "state": "user://extreme7_state.json", "title": "PUZZLE PILOT 3\n(DEVELOPMENT)",
		"q2": "", "q2_key": "l300", "q2_label": "harder than L300", "pilot": true, "ratings": X_RATINGS, "questions": X6_QUESTIONS,
		"log_blocked": true, "hide_difficulty": true, "combo": true, "ls": "chain_escape_xtest7_state"},
	# VERY HARD validation, second player (see the header).
	"vhval3": {"data": "res://data/dev/vh_validation3.json", "state": "user://vh_validation3_state.json", "title": "PUZZLE TEST\n(DEVELOPMENT)",
		"q2": "", "q2_key": "l300", "q2_label": "harder than L300", "pilot": true, "ratings": X_RATINGS, "questions": X6_QUESTIONS,
		"log_blocked": true, "hide_difficulty": true, "combo": true, "ls": "chain_escape_vhval3_state"},
	# EXTREME expert experiment (see the header).
	"xtest8": {"data": "res://data/dev/extreme8.json", "state": "user://extreme8_state.json", "title": "PUZZLE TEST\n(DEVELOPMENT)",
		"q2": "", "q2_key": "l300", "q2_label": "harder than L300", "pilot": true, "ratings": X_RATINGS, "questions": X8_QUESTIONS,
		"log_blocked": true, "hide_difficulty": true, "combo": true, "mech_events": true, "ls": "chain_escape_xtest8_state"},
	# EXTREME phase 6, one board, the experimental SHOW A MOVE rule (see the header).
	"ptest11": {"data": "res://data/dev/extreme11.json", "state": "user://extreme11_state.json", "title": "PUZZLE TEST\n(DEVELOPMENT)",
		"q2": "", "q2_key": "l300", "q2_label": "harder than L300", "pilot": true, "ratings": X_RATINGS, "questions": X8_QUESTIONS,
		"log_blocked": true, "hide_difficulty": true, "combo": true, "mech_events": true, "hint_budget": 1, "persist_live": true,
		"ls": "chain_escape_ptest11_state"},
}
## Pilot follow-up questions: [key, text, label, options].
const PILOT_QUESTIONS := [
	["l300", "Compared with Campaign Level 300,\nthis puzzle was...", "vs Level 300", ["EASIER", "SIMILAR", "HARDER", "NOT SURE"]],
	["enjoy", "How much did you enjoy it?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["achieve", "How strong was your sense\nof achievement?\n(1 = none, 5 = very strong)", "achievement", ["1", "2", "3", "4", "5"]],
	["unfair", "Did the puzzle feel\nrandom or unfair?", "random / unfair", ["YES", "NO"]],
]
## Pilot: how far the tester has played -> the highest first-level of a
## mechanic they have met (boards above it are not served).
const REACHED := [["ALL 300 LEVELS", 300], ["PAST LEVEL 250", 250], ["PAST LEVEL 225", 225], ["PAST LEVEL 200", 200],
	["PAST LEVEL 150", 150], ["NOT THAT FAR", 100]]
## Pilot: one neutral line per mechanic (rules only, never a hint).
const REMINDERS := {
	"spinner_cw": "Spinners (ring around the arrow) turn when a block next to them leaves.",
	"spinner_ccw": "The ring shows which way a spinner turns: some turn counter-clockwise.",
	"spinner_alt": "Alternating spinners change direction every turn.",
	"spinner_pattern": "Pattern spinners turn clockwise, clockwise, counter-clockwise, and repeat.",
	"lock": "A locked block can't leave while any block of its key colour is still on the board.",
	"switch": "When a switch leaves, every block linked to it reverses its arrow.",
	"gate": "A chain gate opens when every block linked to it has left.",
	"armor": "An armored block must be hit by another block before it can leave.",
	"portal": "A lane that reaches a portal continues out of the matching portal.",
	"sequence": "A Sequence block's first move comes back with its next arrow; the second move escapes.",
	"crate": "A Movable block never leaves: a block launched into it pushes it one cell.",
	"magnet": "When a magnet leaves, the first block behind it slides into the cell it left.",
}
## Pilot: GIVE UP needs a second tap within this time.
const GIVE_UP_CONFIRM_MS := 3000
## A pause between two actions (move, UNDO, SHOW A MOVE, RESTART) at least
## this long is recorded as a "long pause" (test 3 analytics).
const LONG_PAUSE_MS := 10000
const RATINGS := ["EASY", "MEDIUM", "HARD", "VERY HARD"]
const ACCENT := Color("#1A9FE6")

enum Screen { INTRO, PLAYING, RATE, THINK, RESULTS, PROFILE, BRIEF, HARDEST }

var test := PARAM
var _cfg: Dictionary = TESTS[PARAM]
## The rating scale of this test (EXTREME research: five steps).
var ratings: Array = RATINGS
var boards: Dictionary = {}  # id -> record (variant, puzzle, metrics)
## EXTREME phase 2: the interactive demos (board file "demos"), in order.
var demos: Array = []
var _demo: Dictionary = {}  # the demo on screen / being played
var state: Dictionary = {}  # order, index, results
var screen: int = Screen.INTRO
var play: SocialPlay
var _assist: Dictionary = {"undo": 3, "show_a_move": 1, "hammer": 1}
var _current: Dictionary = {}  # result being recorded
var _t0 := 0
var _root: Control
var _pages: Dictionary = {}
var _intro_text: Label
var _start: PillButton
var _results_text: Label
var _copy: PillButton
var _copy_status: Label
var _rate_title: Label
var _q_label: Label
var _q := 0  # which follow-up question is showing
## Follow-up questions after the rating: [[key, text, label], ...].
var _questions: Array = []
var _act_sig := []
var _last_act := 0
## Pilot only.
var pilot := false
var bench := false
var bench_results: Array = []
var _think_opts: BoxContainer
var _think_skip: PillButton
var _brief_text: Label
var _brief_go: PillButton
var _hud: Control
var _clock: Label
var _give_up: PillButton
var _give_up_armed := 0
var _hardest_grid: GridContainer
var _hardest_why: LineEdit
var _hardest_pick := -1
var _hardest_label: Label
var _prev_snap: Dictionary = {}


## Checked at launch like FriendBench (before a shared-challenge link).
static func requested() -> bool:
	return requested_test() != ""


## "vhtest3", "vhtest2", "vhtest" or "" (not asked for).
static func requested_test() -> String:
	if BuildFlags.dev_pages_off():
		return ""  # player / QA build: developer pages off
	for key in ["ptest11", "xtest8", "vhval3", "xtest7", "xtest6", "xtest5", "vhtest4", "vhtest3", "vhtest2", "vhtest"]:
		if "--" + key in OS.get_cmdline_user_args():
			return key
	if not OS.has_feature("web"):
		return ""
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return ""
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	for key in ["ptest11", "xtest8", "vhval3", "xtest7", "xtest6", "xtest5", "vhtest4", "vhtest3", "vhtest2", "vhtest"]:
		if where.contains(key + "=1") or where.contains(key + "=true"):
			return key
	return ""


func _init(p_test: String = PARAM) -> void:
	layer = 30  # over everything (SocialPlay is layer 5)
	test = p_test if TESTS.has(p_test) else PARAM
	_cfg = TESTS[test]
	pilot = _cfg.get("pilot", false)
	ratings = _cfg.get("ratings", RATINGS)
	if pilot:
		_questions = _cfg.get("questions", PILOT_QUESTIONS).duplicate(true)
		bench = _bench_requested()
		# Campaign tokens on this page only (as the mechanic lab does).
		LevelManager.dev_sequence = true
		LevelManager.dev_movable = true
		LevelManager.dev_magnet = true
		return
	_questions = [[_cfg["q2_key"], _cfg["q2"], _cfg["q2_label"], ["YES", "NO"]]]
	if _cfg.has("q3"):
		_questions.append([_cfg["q3_key"], _cfg["q3"], _cfg["q3_label"], ["YES", "NO"]])


## Pilot: "&bench=1" (desktop: "-- --bench").
static func _bench_requested() -> bool:
	if "--bench" in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	return loc != null and (str(loc.search) + str(loc.hash)).to_lower().contains("bench=1")


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(_cfg["data"]))
	if typeof(data) == TYPE_DICTIONARY:
		_assist = data.get("assist", _assist)
		for b in data.get("boards", []):
			boards[str(b["id"])] = b
		if _cfg.get("demos", false):
			demos = data.get("demos", [])
	_load_state()
	play = SocialPlay.new()
	play.dev_assist = true  # its own tools, no Friend timer
	play.max_hints = int(_assist.get("show_a_move", 1))
	play.max_hammers = int(_assist.get("hammer", 1))
	if pilot:
		play.max_undos = int(_assist.get("undo", 3))
	play.solved.connect(_on_solved)
	play.exited.connect(_on_gave_up)
	add_child(play)
	if _cfg.has("hint_budget"):
		# Phase 6: this page answers its own SHOW A MOVE (SocialPlay unchanged).
		play._hint.pressed.disconnect(play.hint)
		play._hint.pressed.connect(budget_hint)
	_build()
	_show(Screen.INTRO)
	set_process(true)
	if bench:
		_run_bench.call_deferred()


func _process(_delta: float) -> void:
	if screen == Screen.PLAYING and _current.get("first_move_ms", -1) < 0 and (play.total_moves > 0 or play.total_hammers > 0):
		_current["first_move_ms"] = Time.get_ticks_msec() - _t0
	if screen == Screen.PLAYING:
		_track_pauses()
		if pilot:
			var sec := (Time.get_ticks_msec() - _t0) / 1000
			_clock.text = "%d:%02d" % [sec / 60, sec % 60]
			if _give_up_armed > 0 and Time.get_ticks_msec() > _give_up_armed:
				_give_up_armed = 0
				_give_up.text = "GIVE UP"
	if screen == Screen.RESULTS:
		var r := SocialWeb.take_share_result()
		if r == "copied":
			_copy_status.text = "COPIED - paste it into the chat"
		elif r == "failed":
			_copy_status.text = "COULDN'T COPY - take a screenshot instead"


# --- Flow ------------------------------------------------------------------------------

func total() -> int:
	return state["order"].size()


func start_next() -> void:
	var i: int = state["index"]
	if i >= total():
		_show(Screen.HARDEST if pilot and not state.has("hardest") and total() > 0 else Screen.RESULTS)
		return
	if pilot:
		_demo = _pending_demo()
		_show(Screen.BRIEF)  # the reminder (or demo) card; its START begins the puzzle (or demo)
		return
	begin_puzzle()


## Phase 2: the first demo of the next puzzle's group not played yet ({}).
func _pending_demo() -> Dictionary:
	if demos.is_empty() or int(state["index"]) >= total():
		return {}
	var group: String = boards[state["order"][state["index"]]]["variant"]
	var done: Array = state.get("demos_done", [])
	for d in demos:
		if d["group"] == group and not done.has(d["id"]):
			return d
	return {}


## The card's START: the demo if one is due, else the puzzle.
func begin_from_card() -> void:
	if _demo.is_empty():
		begin_puzzle()
	else:
		begin_demo()


## Phase 2: plays the demo board (never rated; its own record).
func begin_demo() -> void:
	var def := PuzzleDefinition.from_dict(_demo["puzzle"])
	var c := SharedChallenge.friend_challenge(def, FriendGenerator.VERY_HARD)
	_current = {"demo": _demo["id"], "first_move_ms": -1, "longest_pause_ms": 0, "long_pauses": [], "gave_up": false, "log": []}
	_give_up_armed = 0
	_give_up.text = "GIVE UP"
	_show(Screen.PLAYING)
	play.back_label = ""
	_act_sig = []
	play.start(c, SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	play._title.text = "TRY IT"
	play._chip.text = ""
	_t0 = Time.get_ticks_msec()
	_last_act = _t0
	_prev_snap = _snap()
	_act_sig_prev = _sig()


## Phase 2: a demo ends (solved, or given up): recorded, never rated; then
## the next card (the next demo, or the puzzle's reminder card).
func _end_demo(solved: bool) -> void:
	_current["completed"] = solved
	_current["time_ms"] = Time.get_ticks_msec() - _t0
	_current["restarts"] = maxi(0, play.plays - 1)
	_current["show_a_move"] = play.total_hints
	play.end()
	var done: Array = state.get("demos_done", [])
	done.append(_current["demo"])
	state["demos_done"] = done
	var rec: Array = state.get("demos", [])
	rec.append(_current.duplicate())
	state["demos"] = rec
	_save_state()
	_current = {}
	start_next()


## Starts puzzle `index` (pilot: from the reminder card).
func begin_puzzle() -> void:
	var i: int = state["index"]
	var rec: Dictionary = boards[state["order"][i]]
	if _cfg.get("persist_live", false) and state.get("live", {}).get("id", "") == rec["id"] and state["live"].get("finished", false):
		# Played to the end before a refresh: straight to the rating.
		_current = state["live"]["record"].duplicate(true)
		_show(Screen.RATE)
		return
	var def := PuzzleDefinition.from_dict(rec["puzzle"])
	var c := SharedChallenge.friend_challenge(def, FriendGenerator.VERY_HARD)
	_current = {"id": rec["id"], "variant": rec["variant"], "fingerprint": def.fingerprint(), "order": i + 1, "first_move_ms": -1,
		"longest_pause_ms": 0, "long_pauses": []}
	if pilot:
		_current["mechanics"] = rec.get("mechanics", [])
		_current["gave_up"] = false
		_current["log"] = []
		_give_up_armed = 0
		_give_up.text = "GIVE UP"
	_show(Screen.PLAYING)
	play.back_label = ""
	_act_sig = []
	if _cfg.has("hint_budget"):
		play.max_hints = 0 if hint_spent(rec["id"]) else int(_cfg["hint_budget"])
		_current["unaided_max_cleared"] = 0
		_current["hint_presses"] = 0
	play.start(c, SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	play._title.text = "PUZZLE %d / %d" % [i + 1, total()]
	if _cfg.get("hide_difficulty", false):
		play._chip.text = ""  # EXTREME research: no "VERY HARD" label to anchor the rating
	_t0 = Time.get_ticks_msec()
	_last_act = _t0
	if _cfg.get("persist_live", false):
		_resume_live(rec["id"])
	if pilot:
		_prev_snap = _snap()
		_act_sig_prev = _sig()
	play._refresh_buttons()


func _on_solved() -> void:
	if screen != Screen.PLAYING:
		return
	if _current.has("demo"):
		await get_tree().create_timer(1.0).timeout
		_end_demo(true)
		return
	_finish_attempt(true)
	# Let the board celebrate for a moment, then ask.
	await get_tree().create_timer(1.0).timeout
	_show(Screen.RATE)


## EXIT -> LEAVE in the game: recorded as not solved (still rated).
func _on_gave_up() -> void:
	if screen != Screen.PLAYING:
		return
	if pilot:
		_current["gave_up"] = true
		_current["log"].append([Time.get_ticks_msec() - _t0, "g", -1])
	if _current.has("demo"):
		_end_demo(false)
		return
	_finish_attempt(false)
	_show(Screen.RATE)


## Pauses between actions (a move, UNDO, SHOW A MOVE, HAMMER, RESTART).
## Recorded: the longest, and every pause >= LONG_PAUSE_MS with where it
## happened (attempt number, blocks already cleared in that attempt / total).
func _track_pauses() -> void:
	var sig := _sig()
	if _act_sig.is_empty():
		_act_sig = sig
		return
	if sig == _act_sig:
		return
	_act_sig = sig
	var now := Time.get_ticks_msec()
	var gap := now - _last_act
	_last_act = now
	if pilot:
		_log_action(sig, now)
	_current["longest_pause_ms"] = maxi(int(_current.get("longest_pause_ms", 0)), gap)
	if gap >= LONG_PAUSE_MS:
		var cleared := play._total_blocks - play.model.block_count()
		_current["long_pauses"].append({"ms": gap, "attempt": play.plays, "cleared": cleared, "of": play._total_blocks})


## What has happened so far in this puzzle. Pushes, rams and Sequence
## advances are moves too (their own counters); EXTREME research also
## counts blocked taps (a tap that moved nothing).
func _sig() -> Array:
	var sig := [play.total_moves, play.total_undos, play.total_hints, play.total_hammers, play.plays,
		play.total_pushes, play.total_rams, play.total_seq_advances]
	if _cfg.get("log_blocked", false):
		sig.append(play.total_blocked)
	return sig


func _finish_attempt(solved: bool) -> void:
	_current["completed"] = solved
	_current["time_ms"] = Time.get_ticks_msec() - _t0
	_current["moves"] = play.total_moves
	_current["restarts"] = maxi(0, play.plays - 1)
	_current["undos"] = play.total_undos
	_current["show_a_move"] = play.total_hints
	_current["hammer"] = play.total_hammers
	if pilot:
		_current["pushes"] = play.total_pushes
		_current["advances"] = play.total_seq_advances
		_current["rams"] = play.total_rams
		_current["portal_uses"] = play.total_portal_uses
		_current["blocked_taps"] = play.total_blocked
		if _cfg.get("log_blocked", false):
			_current["pulls"] = play.total_pulls
	if _cfg.has("hint_budget"):
		_current["show_a_move"] = int(_current.get("hint_spends", 0))
	if _cfg.get("persist_live", false):
		# Totals from before a refresh (the board started again there).
		var carry: Dictionary = _current.get("carry", {})
		for k in carry:
			_current[k] = int(_current.get(k, 0)) + int(carry[k])
		_current["attempts"] = int(_current["restarts"]) + int(_current.get("reopens", 0)) + 1
		_current.erase("carry")
		_current.erase("live_totals")
		# Finished: a refresh now goes back to the questions, not the board.
		state["live"] = {"id": _current["id"], "finished": true, "record": _current}
		_save_state()


func rate(i: int) -> void:
	_current["rating"] = ratings[i]
	_q = 0
	_show(Screen.THINK)


## Answer to the follow-up question showing ("" = skipped); the next one,
## or the next puzzle.
func think(answer: String) -> void:
	_current[_questions[_q][0]] = answer
	_q += 1
	if _q < _questions.size():
		_show(Screen.THINK)
		return
	play.end()
	state["results"].append(_current.duplicate())
	state["index"] = int(state["index"]) + 1
	state.erase("live")
	_save_state()
	_current = {}
	start_next()


func reset_test() -> void:
	state = {}
	_new_order()
	_save_state()
	_show(Screen.INTRO)


# --- Pilot ---------------------------------------------------------------------------------

## GIVE UP (pilot): the first tap arms it, a second tap within
## GIVE_UP_CONFIRM_MS ends the puzzle as not solved (then the questions).
func give_up() -> void:
	if screen != Screen.PLAYING:
		return
	var now := Time.get_ticks_msec()
	if _give_up_armed == 0 or now > _give_up_armed:
		_give_up_armed = now + GIVE_UP_CONFIRM_MS
		_give_up.text = "TAP AGAIN TO GIVE UP"
		return
	_give_up_armed = 0
	_current["gave_up"] = true
	_current["log"].append([now - _t0, "g", -1])
	if _current.has("demo"):
		_end_demo(false)
		return
	_finish_attempt(false)
	_show(Screen.RATE)


## Pilot: the tester's campaign progress; builds the balanced order of the
## boards they can play.
func set_reached(level: int) -> void:
	state = {"reached": level}
	_new_order()
	_save_state()
	_show(Screen.INTRO)


## Pilot: the hardest puzzle (its position in this tester's order) and why.
func set_hardest(order_pos: int, why: String) -> void:
	var id := ""
	if order_pos >= 1 and order_pos <= state["results"].size():
		id = str(state["results"][order_pos - 1]["id"])
	state["hardest"] = {"order": order_pos, "id": id, "why": why.strip_edges()}
	_save_state()
	_show(Screen.RESULTS)


# --- Phase 6: one SHOW A MOVE per puzzle (?ptest11; see the header) ----------------------

## True once this puzzle's SHOW A MOVE was used (this mode's own state).
func hint_spent(id: String) -> bool:
	return state.get("budget", {}).has(id)


## This page's SHOW A MOVE button. Spends before it answers, and saves first.
func budget_hint() -> void:
	if screen != Screen.PLAYING or play.completed or play.model.is_empty() or not _current.has("id"):
		return
	var id: String = _current["id"]
	var now := Time.get_ticks_msec()
	var attempt := int(_current.get("carry", {}).get("restarts", 0)) + int(_current.get("reopens", 0)) + play.plays
	var entry := [now - _t0, "h", -1, {"att": attempt}]
	_current["hint_presses"] = int(_current.get("hint_presses", 0)) + 1
	if hint_spent(id):
		# The same answer in every position: no solver, nothing revealed.
		play._show_message("No SHOW A MOVE left in this puzzle")
		entry[3]["r"] = "none"
	elif play.model.playable_ids().is_empty():
		# Already on screen for everyone ("No moves left"): not hidden information.
		play._show_message("No moves left - tap Undo" if play.undos_used < play.max_undos else "No moves left - tap Restart")
		entry[3]["r"] = "stuck"
	else:
		var budget: Dictionary = state.get("budget", {})
		budget[id] = {"ms": now - _t0, "attempt": attempt}
		state["budget"] = budget
		_current["hint_spends"] = int(_current.get("hint_spends", 0)) + 1
		_current["first_hint_ms"] = now - _t0
		_current["first_hint_attempt"] = attempt
		play.max_hints = 0
		play.hints_used = 0
		_save_live()  # spent on disk before anything is shown
		var hid := Solver.from_model(play.model).recommend_move()
		if hid >= 0:
			play.board.set_hint(hid)
			AudioManager.play_hint()
			entry[2] = hid
			entry[3]["r"] = "shown"
		else:
			play._show_message("Can't be cleared from here - SHOW A MOVE used")
			entry[3]["r"] = "lost"
		budget[id]["r"] = entry[3]["r"]
	_current["log"].append(entry)
	_last_act = now
	_save_live()
	play._refresh_buttons()
	play._publish.call_deferred()


## The puzzle in progress, saved after every logged action (a refresh or a
## return later carries on with the same record, time and budget).
func _save_live() -> void:
	if not _cfg.get("persist_live", false) or not _current.has("id"):
		_save_state()
		return
	if _current.has("completed"):
		# Finished (the last move can be logged a frame after the solve):
		# stays finished, a refresh goes to the questions.
		state["live"] = {"id": _current["id"], "finished": true, "record": _current}
		_save_state()
		return
	_current["time_ms"] = Time.get_ticks_msec() - _t0
	_current["live_totals"] = {"moves": play.total_moves, "restarts": maxi(0, play.plays - 1), "undos": play.total_undos,
		"hammer": play.total_hammers, "pushes": play.total_pushes, "advances": play.total_seq_advances, "rams": play.total_rams,
		"portal_uses": play.total_portal_uses, "blocked_taps": play.total_blocked, "pulls": play.total_pulls}
	state["live"] = {"id": _current["id"], "elapsed_ms": Time.get_ticks_msec() - _t0, "record": _current}
	_save_state()


## A puzzle that was in progress when the page closed: the record, clock and
## totals continue; the board starts again (logged "o").
func _resume_live(id: String) -> void:
	var live: Dictionary = state.get("live", {})
	if live.get("id", "") != id or typeof(live.get("record")) != TYPE_DICTIONARY:
		return
	var rec: Dictionary = live["record"].duplicate(true)
	var carry: Dictionary = rec.get("carry", {})
	for k in rec.get("live_totals", {}):
		carry[k] = int(carry.get(k, 0)) + int(rec["live_totals"][k])
	rec["carry"] = carry
	rec.erase("live_totals")
	rec["reopens"] = int(rec.get("reopens", 0)) + 1
	_current = rec
	_t0 = Time.get_ticks_msec() - int(live.get("elapsed_ms", 0))
	_last_act = Time.get_ticks_msec()
	_current["log"].append([int(live.get("elapsed_ms", 0)), "o", -1])
	_save_live()


## Every block's place and state (to infer the tapped block of a move).
func _snap() -> Dictionary:
	var out := {}
	for id in play.model.blocks:
		var b: BlockData = play.model.blocks[id]
		out[id] = [b.cell, b.direction, b.seq_stage, b.armored, b.kind]
	return out


## One action of the pilot log: [ms since the puzzle started, kind, block]:
## "m" move (tapped block id, or -1 if it can't be told), "u" UNDO,
## "h" SHOW A MOVE, "x" HAMMER, "r" RESTART, "b" blocked tap (EXTREME
## research only; the block is not known: -1).
func _log_action(sig: Array, now: int) -> void:
	var prev: Array = _act_sig_prev
	_act_sig_prev = sig.duplicate()
	var snap := _snap()
	var kind := ""
	if prev.is_empty():
		kind = "m" if sig[0] + sig[5] + sig[6] + sig[7] > 0 else ""
	elif sig[4] > prev[4]:
		kind = "r"
	elif sig[1] > prev[1]:
		kind = "u"
	elif sig[2] > prev[2]:
		kind = "h"
	elif sig[3] > prev[3]:
		kind = "x"
	elif sig[0] > prev[0] or sig[5] > prev[5] or sig[6] > prev[6] or sig[7] > prev[7]:
		kind = "m"
	elif sig.size() > 8 and sig[8] > prev[8]:
		kind = "b"
	if kind != "":
		var entry := [now - _t0, kind, infer_tap(_prev_snap, snap) if kind == "m" else -1]
		if kind == "m" and _cfg.get("mech_events", false):
			var ev := mech_events(_prev_snap, snap)
			if not ev.is_empty():
				entry.append(ev)
				var tot: Dictionary = _current.get("mech", {})
				for k in ev:
					tot[k] = int(tot.get(k, 0)) + int(ev[k])
				_current["mech"] = tot
		_current["log"].append(entry)
		if _cfg.has("hint_budget") and not hint_spent(str(_current.get("id", ""))):
			# Furthest progress before SHOW A MOVE was used (blocks cleared).
			_current["unaided_max_cleared"] = maxi(int(_current.get("unaided_max_cleared", 0)), play._total_blocks - play.model.block_count())
		if _cfg.get("persist_live", false) and _current.has("id"):
			_save_live()
	_prev_snap = snap

var _act_sig_prev: Array = []


## What one move did, from the board before / after (EXTREME expert
## experiment): {"gate": gates opened, "pull": blocks moved by a magnet,
## "flip": arrows reversed by a switch, "turn": spinners turned, "ram":
## shells cracked}; only the non-zero counts. Read from the board only (the
## same rules the player sees), never from the solver.
static func mech_events(before: Dictionary, after: Dictionary) -> Dictionary:
	var ev := {}
	for id in before:
		var b: Array = before[id]
		if not after.has(id):
			if b[4] == BlockData.Kind.GATE:
				ev["gate"] = int(ev.get("gate", 0)) + 1
			continue
		var a: Array = after[id]
		if b[4] != BlockData.Kind.CRATE and b[0] != a[0]:
			ev["pull"] = int(ev.get("pull", 0)) + 1
		if b[1] != a[1] and b[2] == a[2]:
			var k := "turn" if b[4] == BlockData.Kind.SPINNER else "flip"
			ev[k] = int(ev.get(k, 0)) + 1
		if b[3] and not a[3]:
			ev["ram"] = int(ev.get("ram", 0)) + 1
	return ev


## The block a move was made with, from the board before / after: the
## block that escaped; else the Sequence block that advanced; else (a push
## or a ram) the block whose lane runs straight into the crate that moved
## or the shell that broke. -1 if none can be told.
static func infer_tap(before: Dictionary, after: Dictionary) -> int:
	for id in before:
		var kind: int = before[id][4]
		if not after.has(id) and kind != BlockData.Kind.CRATE and kind != BlockData.Kind.GATE:
			return id
	var target := Vector2i(-1, -1)
	var push := Vector2i.ZERO  # how the crate moved: the pusher points this way
	for id in after:
		if not before.has(id):
			continue
		if before[id][2] == 1 and after[id][2] == 2:
			return id
		if before[id][4] == BlockData.Kind.CRATE and before[id][0] != after[id][0]:
			target = before[id][0]
			push = after[id][0] - before[id][0]
		if before[id][3] and not after[id][3]:
			target = before[id][0]
	if target.x < 0:
		return -1
	var at := {}
	for id in before:
		at[before[id][0]] = id
	var found := []
	for id in before:
		var kind: int = before[id][4]
		if kind == BlockData.Kind.CRATE or kind == BlockData.Kind.GATE:
			continue
		var step := Direction.step(before[id][1])
		if push != Vector2i.ZERO and step != push:
			continue
		var c: Vector2i = before[id][0] + step
		for n in 20:
			if at.has(c):
				if c == target:
					found.append(id)
				break
			c += step
	# A ram that two blocks could have made can't be told apart: -1.
	return found[0] if found.size() == 1 else -1


## Pilot &bench=1: the recipient's check (a fresh Solver, the full
## 60000-node limit) and SHOW A MOVE on every board, timed on this device.
## Published as window.chainEscapeVhBench (and kept in bench_results).
func _run_bench() -> void:
	var ids := boards.keys()
	ids.sort()
	bench_results = []
	for id in ids:
		await get_tree().process_frame
		var rec: Dictionary = boards[id]
		var def := PuzzleDefinition.from_dict(rec["puzzle"])
		var level := def.to_level()
		var times := []
		var nodes := 0
		for k in 3:
			var s := _solver(level, [])
			var t0 := Time.get_ticks_usec()
			s.solve_moves()
			times.append((Time.get_ticks_usec() - t0) / 1000.0)
			nodes = s.nodes
		times.sort()
		var row := {"id": id, "verify_ms": snappedf(times[1], 0.01), "verify_nodes": nodes}
		var hint: Dictionary = rec.get("metrics", {}).get("hint", {})
		for k in [["hint", "worst_path"], ["dead_hint", "dead_worst_path"]]:
			var path: Array = hint.get(k[1], [])
			if k[0] == "dead_hint" and path.is_empty():
				continue
			var s := _solver(level, path)
			s.nodes = 0
			var t1 := Time.get_ticks_usec()
			s.recommend_move()
			row[k[0] + "_ms"] = snappedf((Time.get_ticks_usec() - t1) / 1000.0, 0.01)
			row[k[0] + "_nodes"] = s.nodes
		bench_results.append(row)
	if OS.has_feature("web"):
		WebBridge.publish("chainEscapeVhBench", {"done": true, "results": bench_results})


static func _solver(level: LevelData, path: Array) -> Solver:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks.map(func(b): return b.duplicate_data()))
	m.set_portals(level.portals)
	var s := Solver.from_model(m)
	s.node_limit = Solver.DEFAULT_NODE_LIMIT
	for mv in path:
		s._do(int(mv))
	return s


# --- State (this file only) -------------------------------------------------------------

func _load_state() -> void:
	# The file, and on the Web its synchronous localStorage mirror (this
	# test's own key, as the Classic save does for its own): the copy with
	# more answers wins, so closing Safari right after a rating loses nothing.
	var path: String = _cfg["state"]
	var texts := [FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""]
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(_cfg["ls"]))
	var best = null
	for t in texts:
		var parsed = JSON.parse_string(t) if t != "" else null
		if typeof(parsed) == TYPE_DICTIONARY and (parsed.get("order", []).size() == boards.size() or (pilot and parsed.has("reached"))) \
				and parsed["order"].all(func(id): return boards.has(str(id))) \
				and (best == null or parsed.get("results", []).size() > best.get("results", []).size()):
			best = parsed
	if best != null:
		state = best
		state["index"] = int(state["index"])
	else:
		_new_order()
		_save_state()


## A random order for this device: variants interleaved, never told.
## Pilot: only the boards whose mechanics the tester has met, one of each
## group per round in a random group order (balanced), nothing before the
## tester said how far they have played.
func _new_order() -> void:
	if pilot:
		var reached := int(state.get("reached", 0))
		var buckets := {}
		for id in boards:
			var b: Dictionary = boards[id]
			if reached > 0 and int(b.get("first_level", 1)) <= reached:
				var v: String = b["variant"]
				if not buckets.has(v):
					buckets[v] = []
				buckets[v].append(id)
		var prng := RandomNumberGenerator.new()
		prng.randomize()
		for v in buckets:
			buckets[v].sort()
			_shuffle(buckets[v], prng)
		var order := []
		while not buckets.is_empty():
			var groups := buckets.keys()
			groups.sort()
			_shuffle(groups, prng)
			for v in groups:
				order.append(buckets[v].pop_back())
				if buckets[v].is_empty():
					buckets.erase(v)
		state = {"order": order, "index": 0, "results": [], "reached": reached, "started": Time.get_datetime_string_from_system()}
		return
	var ids := boards.keys()
	ids.sort()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = ids[i]
		ids[i] = ids[j]
		ids[j] = t
	state = {"order": ids, "index": 0, "results": [], "started": Time.get_datetime_string_from_system()}


static func _shuffle(a: Array, prng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := prng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t


func _save_state() -> void:
	var text := JSON.stringify(state)
	var f := FileAccess.open(_cfg["state"], FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	if OS.has_feature("web"):
		WebBridge.ls_set(_cfg["ls"], text)


## Everything recorded, plus a per-variant summary (variants are only
## named here, after every puzzle was played).
func results_json() -> String:
	var out := {"format": "ce-vh-human-results", "v": 1, "test": test, "q2_key": _cfg["q2_key"], "q3_key": _cfg.get("q3_key", ""), "started": state.get("started", ""),
		"device": OS.get_name(), "assist": _assist, "results": state["results"], "summary": summary()}
	if pilot:
		out["reached"] = state.get("reached", 0)
		out["hardest"] = state.get("hardest", {})
		out["boards_offered"] = total()
		if _cfg.get("demos", false):
			out["demos"] = state.get("demos", [])
	return JSON.stringify(out)


func summary() -> Dictionary:
	var out := {}
	for r in state["results"]:
		var v: String = r["variant"]
		if not out.has(v):
			out[v] = {"n": 0, "solved": 0, "time_s": [], "rating": [], "very_hard": 0, "q2_yes": 0, "show_a_move": 0, "hammer": 0, "restarts": 0, "first_move_s": []}
		var s: Dictionary = out[v]
		s["n"] += 1
		s["solved"] += 1 if r["completed"] else 0
		if r["completed"]:
			s["time_s"].append(snappedf(r["time_ms"] / 1000.0, 0.1))
		s["rating"].append(ratings.find(r["rating"]) + 1)
		s["very_hard"] += 1 if r["rating"] == "VERY HARD" else 0
		if ratings.size() > RATINGS.size():
			s["extreme"] = s.get("extreme", 0) + (1 if r["rating"] == "EXTREME" else 0)
			s["unfair"] = s.get("unfair", 0) + (1 if r.get("fair", "") == "NO" else 0)
			s["planned"] = s.get("planned", 0) + (1 if r.get("planned", "") == "YES" else 0)
			if r.has("combo"):
				s["combo_yes"] = s.get("combo_yes", 0) + (1 if r["combo"] == "YES" else 0)
			s["blocked_taps"] = s.get("blocked_taps", 0) + int(r.get("blocked_taps", 0))
			s["undos"] = s.get("undos", 0) + int(r.get("undos", 0))
		s["q2_yes"] += 1 if r.get(_cfg["q2_key"], "") == "YES" else 0
		if _cfg.has("q3_key"):
			s["q3_yes"] = s.get("q3_yes", 0) + (1 if r.get(_cfg["q3_key"], "") == "YES" else 0)
		s["long_pauses"] = s.get("long_pauses", 0) + r.get("long_pauses", []).size()
		s["show_a_move"] += r["show_a_move"]
		s["hammer"] += r["hammer"]
		s["restarts"] += r["restarts"]
		if r.get("first_move_ms", -1) >= 0:
			s["first_move_s"].append(snappedf(r["first_move_ms"] / 1000.0, 0.1))
		if pilot:
			s["gave_up"] = s.get("gave_up", 0) + (1 if r.get("gave_up", false) else 0)
			s["harder_than_l300"] = s.get("harder_than_l300", 0) + (1 if r.get("l300", "") == "HARDER" else 0)
			s["similar_l300"] = s.get("similar_l300", 0) + (1 if r.get("l300", "") == "SIMILAR" else 0)
			s["unfair"] = s.get("unfair", 0) + (1 if r.get("unfair", "") == "YES" else 0)
			for k in ["enjoy", "achieve"]:
				if str(r.get(k, "")) != "":
					s[k] = s.get(k, []) + [int(r[k])]
	for v in out:
		var s: Dictionary = out[v]
		var t: Array = s["time_s"]
		t.sort()
		s["median_time_s"] = t[t.size() / 2] if not t.is_empty() else -1
		var fm: Array = s["first_move_s"]
		fm.sort()
		s["median_first_move_s"] = fm[fm.size() / 2] if not fm.is_empty() else -1
		s["avg_rating_1to4"] = snappedf(s["rating"].reduce(func(a, b): return a + b, 0) / float(maxi(s["n"], 1)), 0.01)
		if ratings.size() > RATINGS.size():
			s.erase("avg_rating_1to4")  # a five-step scale here
			s["avg_rating_1to5"] = snappedf(s["rating"].reduce(func(a, b): return a + b, 0) / float(maxi(s["n"], 1)), 0.01)
		for k in ["enjoy", "achieve"]:
			if s.has(k) and not s[k].is_empty():
				s["avg_" + k] = snappedf(s[k].reduce(func(a, b): return a + b, 0) / float(s[k].size()), 0.01)
	return out


func _tools_text() -> String:
	if _cfg.has("hint_budget"):
		return "Play it as you normally would. You have UNDO x%d per attempt (RESTART gives it back) and ONE SHOW A MOVE for the whole puzzle: it does not come back after RESTART, UNDO or if you leave and return." % int(_assist["undo"])
	var parts := ["UNDO x%d" % int(_assist["undo"]), "SHOW A MOVE x%d" % int(_assist["show_a_move"])]
	if int(_assist["hammer"]) > 0:
		parts.append("HAMMER x%d" % int(_assist["hammer"]))
	return "Play each one as you normally would. You have %s per attempt%s; RESTART gives them back." % [
		" and ".join([", ".join(parts.slice(0, parts.size() - 1)), parts[-1]]), "" if int(_assist["hammer"]) > 0 else " (no HAMMER in this test)"]


func _summary_text() -> String:
	var lines := ["%d of %d puzzles played." % [state["results"].size(), total()], ""]
	if int(state["index"]) < total():
		# Still blind: no group is named until every puzzle was played.
		lines.append("The comparison by group appears when every puzzle is done.")
		lines.append("")
		lines.append("Tap COPY RESULTS and paste it into the chat.")
		return "\n".join(lines)
	var sm := summary()
	var keys := sm.keys()
	keys.sort()
	for v in keys:
		var s: Dictionary = sm[v]
		if ratings.size() > RATINGS.size():
			lines.append("%s: %d played, %d solved, %d given up, median %ss, rated %.1f / 5, EXTREME x%d, VERY HARD x%d, harder than L300 x%d, enjoy %s, achieve %s, unfair x%d, needed planning x%d" % [
				v, s["n"], s["solved"], s.get("gave_up", 0), str(s["median_time_s"]), s["avg_rating_1to5"], s.get("extreme", 0), s["very_hard"],
				s.get("harder_than_l300", 0), str(s.get("avg_enjoy", "-")), str(s.get("avg_achieve", "-")), s.get("unfair", 0), s.get("planned", 0)]
				+ (", combination more interesting x%d" % s.get("combo_yes", 0) if _cfg.get("combo", _cfg.get("demos", false)) else ""))
			continue
		if pilot:
			lines.append("Group %s: %d played, %d solved, %d given up, median %ss, rated %.1f / 4, VERY HARD x%d, harder than L300 x%d, enjoy %s, achieve %s, unfair x%d" % [
				v, s["n"], s["solved"], s.get("gave_up", 0), str(s["median_time_s"]), s["avg_rating_1to4"], s["very_hard"], s.get("harder_than_l300", 0),
				str(s.get("avg_enjoy", "-")), str(s.get("avg_achieve", "-")), s.get("unfair", 0)])
			continue
		lines.append("Group %s: %d played, %d solved, median %ss, rated %.1f / 4, VERY HARD x%d, %s x%d%s" % [
			v, s["n"], s["solved"], str(s["median_time_s"]), s["avg_rating_1to4"], s["very_hard"], _cfg["q2_label"], s["q2_yes"],
			(", %s x%d" % [_cfg["q3_label"], s.get("q3_yes", 0)]) if _cfg.has("q3_key") else ""])
	lines.append("")
	lines.append("Tap COPY RESULTS and paste it into the chat.")
	return "\n".join(lines)


# --- Screens ----------------------------------------------------------------------------

func _show(s: int) -> void:
	screen = s
	for k in _pages:
		_pages[k].visible = k == s
	_root.visible = s != Screen.PLAYING
	if _hud:
		_hud.visible = s == Screen.PLAYING
	match s:
		Screen.INTRO:
			if not pilot:
				_show_intro()
				return
			var i: int = state["index"]
			_intro_text.text = ("Up to %d puzzles, one after another, in a random order. You can stop at any time and continue later.\n\n" % boards.size()
				+ _tools_text() + "\n\nEach puzzle starts with a one-line reminder of its rules.\nIf you want to stop a puzzle, tap GIVE UP twice.\n\nAfter each puzzle: %s quick questions." % ["five", "six", "seven", "eight"][clampi(_questions.size() - 4, 0, 3)])
			_start.text = "START" if i == 0 else ("CONTINUE  %d / %d" % [i + 1, total()] if i < total() else "SEE RESULTS")
		Screen.THINK:
			_q_label.text = _questions[_q][1]
			_build_options(_questions[_q][3])
		Screen.BRIEF:
			if not _demo.is_empty():
				_brief_text.text = "\n\n".join(["BEFORE PUZZLE %d / %d" % [int(state["index"]) + 1, total()], "A NEW COMBINATION", _demo["text"], _demo["try"]])
				_brief_go.text = "TRY IT"
				_update_zones.call_deferred()
				_publish()
				return
			_brief_go.text = "START PUZZLE"
			var rec: Dictionary = boards[state["order"][state["index"]]]
			var lines := ["PUZZLE %d / %d" % [int(state["index"]) + 1, total()], ""]
			var mech: Array = rec.get("mechanics", [])
			var has_spinner := mech.any(func(m): return str(m).begins_with("spinner"))
			if has_spinner:
				lines.append(REMINDERS["spinner_cw"])
			for m in mech:
				if m != "spinner_cw" and REMINDERS.has(m):
					lines.append(REMINDERS[m])
			if int(state["index"]) == total() / 2 and int(state["index"]) > 0:
				lines.append("")
				lines.append("Halfway: a good moment for a break.")
			_brief_text.text = "\n\n".join(lines)
		Screen.HARDEST:
			_hardest_pick = -1
			_fill_hardest()
		Screen.RATE:
			_rate_title.text = "PUZZLE %d / %d %s\n\nHow difficult was this puzzle?" % [_current.get("order", 0), total(), "SOLVED" if _current.get("completed", false) else "NOT SOLVED"]
		Screen.RESULTS:
			_results_text.text = _summary_text()
			_copy_status.text = ""
			SocialWeb.set_share(results_json(), "", "")
	_update_zones.call_deferred()
	_publish()


func _show_intro() -> void:
	var i: int = state["index"]
	_intro_text.text = ("%d puzzles, one after another, in a random order.\n\n" % total()
		+ _tools_text() + "\n\n"
		+ (str(_cfg["note"]) + "\n\n" if _cfg.has("note") else "")
		+ "If you want to give up, tap EXIT and LEAVE.\n\nAfter each puzzle: a few quick questions.")
	_start.text = "START" if i == 0 else ("CONTINUE  %d / %d" % [i + 1, total()] if i < total() else "SEE RESULTS")
	_update_zones.call_deferred()
	_publish()


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
	intro.add_child(_label(_cfg["title"], 40, 900))
	_intro_text = _label("", 26, 700)
	intro.add_child(_intro_text)
	_start = _button("START", "Start", ACCENT, Palette.WHITE)
	_start.pressed.connect(func():
		AudioManager.play_ui_tap()
		if pilot and int(state.get("reached", 0)) == 0:
			_show(Screen.PROFILE)
		elif int(state["index"]) >= total():
			start_next()
		else:
			start_next())
	intro.add_child(_start)
	var see := _button("RESULTS SO FAR", "Results", Palette.WHITE, Palette.TEXT)
	see.pressed.connect(func(): _show(Screen.RESULTS))
	intro.add_child(see)
	_pages[Screen.INTRO] = intro
	# RATE
	var rate_box := _column()
	_rate_title = _label("How difficult was this puzzle?", 34, 900)
	rate_box.add_child(_rate_title)
	for i in ratings.size():
		var b := _button(ratings[i], "Rate_%s" % ratings[i].replace(" ", "_"), Palette.WHITE, Palette.TEXT)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			rate(i))
		rate_box.add_child(b)
	_pages[Screen.RATE] = rate_box
	# THINK (optional)
	var think_box := _column()
	_q_label = _label(_cfg["q2"], 34, 900)
	think_box.add_child(_q_label)
	_think_opts = VBoxContainer.new()
	_think_opts.add_theme_constant_override("separation", 22)
	think_box.add_child(_think_opts)
	_build_options(_questions[0][3])
	_think_skip = _button("SKIP", "Think_SKIP", Palette.BACKGROUND, Palette.TEXT_SOFT)
	_think_skip.pressed.connect(func(): think(""))
	think_box.add_child(_think_skip)
	_pages[Screen.THINK] = think_box
	if pilot:
		_build_pilot()
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


## The answer buttons of the follow-up question showing (YES / NO for
## tests 1-3; a 1-5 scale in one row; EASIER / SIMILAR / ...).
func _build_options(opts: Array) -> void:
	for c in _think_opts.get_children():
		_think_opts.remove_child(c)
		c.queue_free()
	if opts == ["TEXT"]:
		# Free text (optional): a field and NEXT; SKIP stays below.
		var field := LineEdit.new()
		field.name = "ThinkText"
		field.custom_minimum_size = Vector2(0, 80)
		field.add_theme_font_size_override("font_size", 26)
		_think_opts.add_child(field)
		var next := _button("NEXT", "Think_NEXT", ACCENT, Palette.WHITE)
		next.pressed.connect(func():
			AudioManager.play_ui_tap()
			think(field.text.strip_edges()))
		_think_opts.add_child(next)
		return
	var row: BoxContainer = _think_opts
	if opts.size() == 5:
		row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		_think_opts.add_child(row)
	for a in opts:
		var b := _button(a, "Think_%s" % a.replace(" ", "_"), Palette.WHITE, Palette.TEXT)
		if opts.size() == 5:
			b.custom_minimum_size = Vector2(110, 110)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			think(a))
		row.add_child(b)


## Pilot pages: campaign progress, the reminder card, the hardest
## puzzle, and the clock + GIVE UP shown over the board.
func _build_pilot() -> void:
	var prof := _column()
	prof.add_child(_label("How far have you played\nthe campaign?", 34, 900))
	for r in REACHED:
		var b := _button(r[0], "Reached_%d" % r[1], Palette.WHITE, Palette.TEXT)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			set_reached(r[1]))
		prof.add_child(b)
	_pages[Screen.PROFILE] = prof
	var brief := _column()
	_brief_text = _label("", 28, 800)
	brief.add_child(_brief_text)
	var go := _button("START PUZZLE", "BeginPuzzle", ACCENT, Palette.WHITE)
	_brief_go = go
	go.pressed.connect(func():
		AudioManager.play_ui_tap()
		begin_from_card())
	brief.add_child(go)
	_pages[Screen.BRIEF] = brief
	var hard := _column()
	hard.add_child(_label("Which puzzle was the hardest?", 34, 900))
	_hardest_label = _label("Tap its number (the order you played them in).", 22, 700)
	hard.add_child(_hardest_label)
	_hardest_grid = GridContainer.new()
	_hardest_grid.columns = 7
	_hardest_grid.add_theme_constant_override("h_separation", 10)
	_hardest_grid.add_theme_constant_override("v_separation", 10)
	hard.add_child(_hardest_grid)
	hard.add_child(_label("Why? (optional - you can also write it in the chat)", 22, 700))
	_hardest_why = LineEdit.new()
	_hardest_why.name = "HardestWhy"
	_hardest_why.custom_minimum_size = Vector2(0, 80)
	_hardest_why.add_theme_font_size_override("font_size", 26)
	hard.add_child(_hardest_why)
	var done := _button("DONE", "HardestDone", ACCENT, Palette.WHITE)
	done.pressed.connect(func():
		AudioManager.play_ui_tap()
		set_hardest(_hardest_pick, _hardest_why.text))
	hard.add_child(done)
	_pages[Screen.HARDEST] = hard
	# While playing: GIVE UP in the play screen's top bar (top right, on the
	# EXIT row) with the clock under it - never over the board, whatever its
	# size (7-row boards reach higher than the old place below the bar).
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = false
	add_child(_hud)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	box.offset_top = 28.0
	box.offset_left = 30.0
	box.offset_right = -30.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	_hud.add_child(box)
	_give_up = _button("GIVE UP", "GiveUp", Palette.WHITE, Palette.TEXT_SOFT)
	_give_up.custom_minimum_size = Vector2(0, 72)
	_give_up.size_flags_horizontal = Control.SIZE_SHRINK_END
	_give_up.pressed.connect(give_up)
	box.add_child(_give_up)
	_clock = _label("0:00", 26, 900)
	_clock.name = "Clock"
	_clock.autowrap_mode = TextServer.AUTOWRAP_OFF
	_clock.size_flags_horizontal = Control.SIZE_SHRINK_END
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_clock)


func _fill_hardest() -> void:
	for c in _hardest_grid.get_children():
		c.queue_free()
	for i in state["results"].size():
		var b := _button(str(i + 1), "Hardest_%d" % (i + 1), Palette.WHITE, Palette.TEXT)
		b.custom_minimum_size = Vector2(80, 80)
		b.pressed.connect(func():
			_hardest_pick = i + 1
			_hardest_label.text = "Puzzle %d selected." % (i + 1))
		_hardest_grid.add_child(b)


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


func _button(t: String, n: String, bg: Color, fg: Color) -> PillButton:
	var b := PillButton.new(t, PillButton.Icon.NONE, bg, fg, 30)
	b.name = n
	b.custom_minimum_size = Vector2(0, 100)
	return b


## Web: read-only snapshot for automated browser tests (window.chainEscapeVhTest).
func _publish() -> void:
	if not OS.has_feature("web") or not is_inside_tree():
		return
	var vis := get_viewport().get_visible_rect().size
	var buttons := {}
	if _hud and _hud.visible:
		for b in _hud.find_children("*", "BaseButton", true, false):
			var c: Vector2 = b.get_global_rect().get_center()
			buttons[String(b.name)] = [snappedf(c.x / vis.x, 0.0001), snappedf(c.y / vis.y, 0.0001)]
	if _root.visible:
		for b in _pages[screen].find_children("*", "BaseButton", true, false):
			if b.is_visible_in_tree():
				var c: Vector2 = b.get_global_rect().get_center()
				buttons[String(b.name)] = [snappedf(c.x / vis.x, 0.0001), snappedf(c.y / vis.y, 0.0001)]
	var hud_bottom := -1.0
	var board_top := -1.0
	if _hud and _hud.visible and play and play.board:
		hud_bottom = snappedf(maxf(_give_up.get_global_rect().end.y, _clock.get_global_rect().end.y) / vis.y, 0.0001)
		board_top = snappedf(play.board.get_board_rect().position.y / vis.y, 0.0001)
	WebBridge.publish("chainEscapeVhTest", {"screen": Screen.keys()[screen], "index": state.get("index", 0), "total": total(),
		"results": state.get("results", []).size(), "buttons": buttons, "hud_bottom": hud_bottom, "board_top": board_top,
		"demo": _demo.get("id", ""), "demos_done": state.get("demos_done", []).size()})
