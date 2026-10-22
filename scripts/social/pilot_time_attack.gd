class_name PilotTimeAttack
extends ExpertTimeAttack
## DEVELOPMENT ONLY: one board of the external Time Attack pilot (?tapilot=1,
## TaPilot). The page of ?tta / ?ttb / ?ttc (ExpertTimeAttack ->
## CountdownTimeAttack) unchanged - the 120 s clock and its green / orange /
## red stages, reduced motion, TA120_RULES (UNDO x3 per attempt, unlimited
## RESTART, no SHOW A MOVE, no HAMMER), TIME UP, CONTINUE WITHOUT TIMER with
## its own record - on one of the four validated boards (S1, TA, TB, TC,
## checked by their fingerprints). Only these differ:
##   - its own state file and localStorage key per board ("tapilot_*"): the
##     standalone pages' data is never read or written;
##   - the pilot's short question sets (every question can be skipped);
##   - the card before the board: the basic rule for players who never
##     played, the board's mechanics (one neutral line each, never a hint),
##     the tools and the clock;
##   - neutral names (PUZZLE 1-4), no board id or design note on screen;
##   - "BACK TO PUZZLES" instead of the results screen (signal `leave`).
## Each timed record also carries the anonymous pilot session id and the
## player's familiarity answer.

signal leave

## The four boards in the order shown (PUZZLE 1-4).
const ORDER := ["TA", "TB", "TC", "S1"]
const BOARDS := {
	"TA": {"data": "res://data/dev/extreme16_a.json", "fp": "a28e22f0a1a216ba4ac701ff549e7d212ce1fe83ae2d8e3678065da555b730cf"},
	"TB": {"data": "res://data/dev/extreme16_b.json", "fp": "f8c22182180f45fa964593050c91d3fc534079338a438774f2b54dd00c924d99"},
	"TC": {"data": "res://data/dev/extreme16_c.json", "fp": "7f7ae09342e86e56a34ab4d52628346e455b97111a8f6c4663c97a9a587988d5"},
	"S1": {"data": "res://data/dev/extreme15.json", "fp": CountdownTimeAttack.S1_FINGERPRINT},
}
const FAMILIARITY := ["NEVER PLAYED", "PLAYED A LITTLE", "EXPERIENCED PLAYER"]
const BASICS := "Tap a block to move it: it slides the way its arrow points and leaves the board if nothing is in its way. If another block is in the way, it stays where it is. Clear every block to solve the puzzle."
const P_TIMED_Q := [
	["first_difficulty", "How difficult was this puzzle?", "first-exposure difficulty", DIFFICULTY],
	["enjoy", "How much did you enjoy\nthe timed play?\n(1 = not at all, 5 = a lot)", "enjoyment (timed)", ["1", "2", "3", "4", "5"]],
	["excite", "How exciting was\nthe countdown?\n(1 = not at all, 5 = very)", "excitement", ["1", "2", "3", "4", "5"]],
	["frustrate", "How frustrating was it?\n(1 = not at all, 5 = very)", "frustration", ["1", "2", "3", "4", "5"]],
	["timer_better", "Did the timer make\nthe experience better?", "timer improved it", ["YES", "NO", "NOT SURE"]],
	["length", "Two minutes was...", "120 s", ["TOO SHORT", "APPROPRIATE", "TOO LONG"]],
	["another", "Would you play\nanother puzzle?", "play another", ["YES", "NO", "NOT SURE"]],
]
const P_POST_Q := [
	["solved", "Did you solve it?", "solved", ["YES", "NO"]],
	["enjoy_puzzle", "How much did you enjoy\nthe puzzle?\n(1 = not at all, 5 = a lot)", "enjoyment (puzzle)", ["1", "2", "3", "4", "5"]],
	["achieve", "How strong was your sense\nof achievement?\n(1 = none, 5 = very strong)", "achievement", ["1", "2", "3", "4", "5"]],
	["feedback", "Optional: anything you want\nto tell us about this puzzle?", "feedback", ["TEXT"]],
]

var board_key := "TA"
var familiarity := ""
var session_id := ""
var number := 1


func _init(p_board: String = "TA", p_familiarity: String = "", p_session: String = "") -> void:
	super("tta")
	board_key = p_board if BOARDS.has(p_board) else "TA"
	familiarity = p_familiarity
	session_id = p_session
	number = ORDER.find(board_key) + 1
	key = "tapilot_" + board_key.to_lower()
	test = key
	preset = {"id": board_key, "letter": str(number), "data": BOARDS[board_key]["data"], "fp": BOARDS[board_key]["fp"],
		"state": state_path(board_key), "ls": ls_key(board_key)}
	_cfg = _cfg.duplicate()
	for k in ["data", "state", "ls"]:
		_cfg[k] = preset[k]
	_cfg["title"] = "PUZZLE %d" % number
	_cfg["questions"] = P_TIMED_Q
	_questions = P_TIMED_Q.duplicate(true)


static func state_path(board: String) -> String:
	return "user://tapilot_%s_state.json" % board.to_lower()


static func ls_key(board: String) -> String:
	return "chain_escape_tapilot_%s_state" % board.to_lower()


## A board's saved state without opening its page (the newest saved copy,
## as the page itself loads it), or {}.
static func read_state(board: String) -> Dictionary:
	var texts := [FileAccess.get_file_as_string(state_path(board)) if FileAccess.file_exists(state_path(board)) else ""]
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(ls_key(board)))
	var best := {}
	for t in texts:
		var parsed = JSON.parse_string(t) if t != "" else null
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("order") and (best.is_empty() or int(parsed.get("seq", 0)) > int(best.get("seq", 0))):
			best = parsed
	return best


func timed_q() -> Array:
	return P_TIMED_Q


func puzzle_q() -> Array:
	return P_POST_Q


func _ready() -> void:
	super._ready()
	# BACK TO PUZZLES on the card before the board and on every question.
	for s in [Screen.BRIEF, Screen.THINK]:
		var back := _button("BACK TO PUZZLES", "BackToPuzzles", Palette.BACKGROUND, Palette.TEXT_SOFT)
		back.custom_minimum_size = Vector2(0, 88)
		back.pressed.connect(func():
			AudioManager.play_ui_tap()
			leave.emit())
		_pages[s].add_child(back)
	_brief_go.text = "START - 2:00"


## The card before the board (no puzzle name, no hint): the basic rule for
## a player who never played, the board's mechanics, the tools, the clock.
func _show(s: int) -> void:
	super._show(s)
	if s != Screen.BRIEF:
		return
	_brief_go.text = "START - 2:00"
	var lines := ["PUZZLE %d" % number]
	if familiarity == FAMILIARITY[0]:
		lines.append(BASICS)
	var mech: Array = boards.get(bid(), {}).get("mechanics", [])
	if mech.any(func(m): return str(m).begins_with("spinner")):
		lines.append(REMINDERS["spinner_cw"])
	for m in mech:
		if m != "spinner_cw" and REMINDERS.has(m):
			lines.append(REMINDERS[m])
	lines.append("UNDO takes back a move (3 per attempt). RESTART starts the board again - the clock keeps running. No hints.")
	lines.append("You have 2 minutes. The clock starts when the board appears.")
	_brief_text.text = "\n\n".join(lines)
	_brief_text.add_theme_font_size_override("font_size", 24 if familiarity == FAMILIARITY[0] else 26)


func begin_puzzle() -> void:
	super.begin_puzzle()
	if screen == Screen.PLAYING and play:
		play._title.text = "PUZZLE %d" % number if phase() != "untimed" else "NO TIMER"


func _start_run() -> void:
	super._start_run()
	_current["pilot"] = {"session": session_id, "familiarity": familiarity, "board": board_key, "run": int(_current.get("run", 1))}


## No results screen: back to the pilot's puzzle selection.
func start_next() -> void:
	if int(state.get("index", 0)) >= total():
		leave.emit()
		return
	super.start_next()


## One finished run, summarised for the pilot's export (the full records
## stay in "raw").
static func summarize(board: String, r: Dictionary) -> Dictionary:
	var t: Dictionary = r.get("timed", {})
	var u: Dictionary = r.get("untimed", {})
	var rec: Dictionary = u.get("record", {})
	return {"board": board, "fingerprint": r.get("board_fingerprint", BOARDS.get(board, {}).get("fp", "")), "run": int(r.get("run", 1)),
		"first_exposure": int(r.get("run", 1)) == 1, "session": t.get("pilot", {}).get("session", ""), "familiarity": t.get("pilot", {}).get("familiarity", ""),
		"timed_outcome": t.get("outcome", ""), "timed_success": t.get("outcome", "") == "COMPLETED", "elapsed_ms": int(t.get("elapsed_ms", 0)),
		"remaining_ms": int(t.get("remaining_ms", 0)), "attempts": int(t.get("restarts", 0)) + int(t.get("run_reopens", 0)) + 1,
		"restarts": int(t.get("restarts", 0)), "reopens": int(t.get("run_reopens", 0)), "undos": int(t.get("undos", 0)),
		"moves": int(t.get("moves", 0)), "blocked_taps": int(t.get("blocked_taps", 0)),
		"hint_allowance": int(CountdownTimeAttack.record_rules(t).get("show_a_move", 0)), "rules": CountdownTimeAttack.record_rules(t).get("version", ""),
		"stages_reached": t.get("stages_reached", []), "reduced_motion": t.get("reduced_motion", false), "interrupted": t.get("interrupted", false),
		"untimed_played": u.get("continued", false), "untimed_outcome": u.get("outcome", "") if u.get("continued", false) else "",
		"untimed_success": u.get("completed", false) == true, "untimed_ms": int(rec.get("time_ms", 0)), "untimed_restarts": int(rec.get("restarts", 0)),
		"timed_answers": t.get("answers", {}), "post_answers": r.get("puzzle_answers", {})}
