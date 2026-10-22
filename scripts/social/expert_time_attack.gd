class_name ExpertTimeAttack
extends CountdownTimeAttack
## DEVELOPMENT ONLY: three independent blind tests, one new board each
## (docs/extreme16.md), on EXACTLY the 120-second clock and countdown of
## CountdownTimeAttack (?stime=1) - the same stages, pill, reduced-motion
## rule, start convention, the same 120 s rules (TA120_RULES: UNDO x3 per
## attempt, unlimited RESTART, NO SHOW A MOVE, HAMMER x0), the frozen timed
## result and the optional CONTINUE WITHOUT TIMER. Only the board, its
## fingerprint, the page's storage and the questions differ:
##   ?tta=1   puzzle test A   data/dev/extreme16_a.json
##   ?ttb=1   puzzle test B   data/dev/extreme16_b.json
##   ?ttc=1   puzzle test C   data/dev/extreme16_c.json
## Each page loads ONLY its own board file (another test's board is never
## loaded or shown) and keeps its own state file and localStorage key.
## Questions: at the end of the TIMED portion (before any untimed play) the
## first-exposure difficulty and the timer questions; after the untimed play,
## a FINISH, or a timed win, the outcome and puzzle questions - two separate
## sets, so a first-exposure rating is never reused for the post-learning one.

const PRESETS := {
	"tta": {"id": "TA", "letter": "A", "data": "res://data/dev/extreme16_a.json",
		"fp": "a28e22f0a1a216ba4ac701ff549e7d212ce1fe83ae2d8e3678065da555b730cf",
		"state": "user://tta_state.json", "ls": "chain_escape_tta_state"},
	"ttb": {"id": "TB", "letter": "B", "data": "res://data/dev/extreme16_b.json",
		"fp": "f8c22182180f45fa964593050c91d3fc534079338a438774f2b54dd00c924d99",
		"state": "user://ttb_state.json", "ls": "chain_escape_ttb_state"},
	"ttc": {"id": "TC", "letter": "C", "data": "res://data/dev/extreme16_c.json",
		"fp": "7f7ae09342e86e56a34ab4d52628346e455b97111a8f6c4663c97a9a587988d5",
		"state": "user://ttc_state.json", "ls": "chain_escape_ttc_state"},
}
const DIFFICULTY := ["EASY", "MEDIUM", "HARD", "VERY HARD", "EXTREME"]
const T_TIMED_Q := [
	["first_difficulty", "How difficult was this puzzle\non FIRST EXPOSURE?", "first-exposure difficulty", DIFFICULTY],
	["enjoy", "How much did you enjoy\nthe timed play?\n(1 = not at all, 5 = a lot)", "enjoyment (timed)", ["1", "2", "3", "4", "5"]],
	["excite", "How much excitement did\nthe countdown create?\n(1 = none, 5 = a lot)", "excitement", ["1", "2", "3", "4", "5"]],
	["frustrate", "How frustrating was it?\n(1 = not at all, 5 = very)", "frustration", ["1", "2", "3", "4", "5"]],
	["timer_better", "Did the timer improve play?", "timer improved play", ["YES", "NO", "NOT SURE"]],
	["length", "Was 120 seconds appropriate?", "120 s", ["TOO SHORT", "APPROPRIATE", "TOO LONG"]],
	["noticed_colours", "Did you notice the\nurgency colours?", "noticed the colours", ["YES", "NO", "NOT SURE"]],
	["another", "Would you play\nanother puzzle?", "play another", ["YES", "NO", "NOT SURE"]],
]
const T_POST_Q := [
	["solved", "Did you solve it?", "solved", ["YES", "NO"]],
	["achieve", "Satisfaction / sense of\nachievement?\n(1 = none, 5 = very strong)", "achievement", ["1", "2", "3", "4", "5"]],
	["enjoy_puzzle", "How much did you enjoy\nthe puzzle itself?\n(1 = not at all, 5 = a lot)", "enjoyment (puzzle)", ["1", "2", "3", "4", "5"]],
	["insight", "Did you discover an\nimportant insight?", "insight", ["YES", "NO", "NOT SURE"]],
	["combo", "Did the mechanic combination\nadd interest?", "combination added interest", ["YES", "A LITTLE", "NO"]],
	["feedback", "Optional: anything about\nthis puzzle?", "feedback", ["TEXT"]],
]

var key := ""
var preset := {}


## The test asked for ("tta", "ttb", "ttc"), or "" - only on development
## builds (the player / QA builds turn developer pages off).
static func requested_key() -> String:
	if BuildFlags.dev_pages_off():
		return ""
	for k in PRESETS:
		if "--" + k in OS.get_cmdline_user_args():
			return k
	if not OS.has_feature("web"):
		return ""
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return ""
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	for k in PRESETS:
		if where.contains(k + "=1") or where.contains(k + "=true"):
			return k
	return ""


func _init(test_key: String = "tta") -> void:
	super()
	key = test_key
	preset = PRESETS[key]
	test = key
	_cfg = {"data": preset["data"], "state": preset["state"], "title": "PUZZLE TEST %s\n(DEVELOPMENT)" % preset["letter"],
		"q2": "", "q2_key": "enjoy", "q2_label": "enjoyment", "pilot": true, "questions": T_TIMED_Q,
		"log_blocked": true, "hide_difficulty": true, "mech_events": true, "hint_budget": 0, "persist_live": true,
		"ls": preset["ls"]}
	_questions = T_TIMED_Q.duplicate(true)


func bid() -> String:
	return preset["id"]


func bfp() -> String:
	return preset["fp"]


func timed_q() -> Array:
	return T_TIMED_Q


func puzzle_q() -> Array:
	return T_POST_Q


func intro_text() -> String:
	return ("Puzzle test %s: one puzzle you have not seen before. Two minutes.\n\nThe clock starts when the board appears and never stops: thinking, UNDO and RESTART all use time. RESTART starts the board again, not the clock. Leaving or reloading the page does not stop it either.\n\n" % preset["letter"]
		+ _tools_text() + "\n\nIf the time runs out, you can choose to keep playing without the clock.\n\nAfterwards: a few quick questions.")


## The five difficulty answers are long: one per line on a phone.
func _build_options(opts: Array) -> void:
	if opts != DIFFICULTY:
		super._build_options(opts)
		return
	for c in _think_opts.get_children():
		_think_opts.remove_child(c)
		c.queue_free()
	for a in opts:
		var b := _button(a, "Think_%s" % a.replace(" ", "_"), Palette.WHITE, Palette.TEXT)
		b.custom_minimum_size = Vector2(0, 84)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			think(a))
		_think_opts.add_child(b)


## The post questions also record what they follow (the untimed play, a
## FINISH after TIME UP, a timed win, a GIVE UP).
func _to_puzzle_questions(continued: bool) -> void:
	var t: Dictionary = state.get("timed", {})
	var cont: Dictionary = state.get("cont", {})
	var after := "untimed play" if cont.get("continued", false) or continued else (
		"timed win" if t.get("outcome", "") == "COMPLETED" else ("finish after TIME UP" if t.get("outcome", "") == "TIME UP" else "timed give up"))
	var a2: Dictionary = state.get("puzzle_answers", {})
	a2["_after"] = after
	state["puzzle_answers"] = a2
	super._to_puzzle_questions(continued)


func _finish_untimed(solved: bool) -> void:
	var first := not _current.has("completed")
	super._finish_untimed(solved)
	if first:
		var a2: Dictionary = state.get("puzzle_answers", {})
		a2["_after"] = "untimed play (solved)" if solved else "untimed play (stopped)"
		state["puzzle_answers"] = a2
		_save_state()
