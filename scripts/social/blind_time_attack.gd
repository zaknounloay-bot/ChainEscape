class_name BlindTimeAttack
extends Q1TimeAttack
## DEVELOPMENT ONLY (?rtime=1): a NEW unseen board (data/dev/extreme14.json,
## "R1", checked by its fingerprint) played blind against the 3-minute clock
## of the Q1 challenge (Q1TimeAttack: the same countdown, start convention,
## reload / background rules, ONE SHOW A MOVE per run, newest-saved-copy
## loading), plus (docs/extreme14.md):
##   - TIME UP is FINAL for the timed phase: the timed record is frozen
##     (state["timed"]) and never rewritten.
##   - Then the timed questions, and after TIME UP an OPTIONAL "CONTINUE
##     WITHOUT TIMER": the same board, from the position at 0:00 when it can
##     still be cleared (else a fresh board, said so). Unlimited RESTART, UNDO
##     x3 per attempt, the run's SHOW A MOVE only if it was not spent. Its own
##     record (state["cont"]) and log; it can never change the timed result.
##   - Then the puzzle questions (difficulty, enjoyment, achievement, fair,
##     planning, combination, free text).
##   - Blocked taps are logged WITH the tapped block.
## Phases (state["phase"]): "timed" -> "timed_q" -> ("offer" -> "untimed")
## -> "puzzle_q" -> the results. A reload resumes the phase: questions at
## the question reached, the untimed board rebuilt to its position.

const RKEY := "rtime"
const R1_ID := "R1"
const R1_FINGERPRINT := "db0dd7e1ae7c721c3c59d1f6f18aee26d71358773d8f6db52e886e758ddfeebc"
const TIMED_Q := [
	["excite", "How exciting was the\n3-minute clock?\n(1 = not at all, 5 = very)", "excitement", ["1", "2", "3", "4", "5"]],
	["enjoy", "How much did you enjoy\nthe timed run?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["frustrate", "How frustrating was it?\n(1 = not at all, 5 = very)", "frustration", ["1", "2", "3", "4", "5"]],
	["timer_better", "Did the countdown make\nthe experience better?", "countdown improved it", ["YES", "NO", "NOT SURE"]],
	["length", "180 seconds was...", "180 s", ["TOO SHORT", "ABOUT RIGHT", "TOO LONG"]],
	["again", "Would you play this\ntimed mode again?", "play again", ["YES", "MAYBE", "NO"]],
]
const PUZZLE_Q := [
	["difficulty", "Without the clock, how difficult\nis this puzzle itself?", "difficulty", ["EASY", "MEDIUM", "HARD", "VERY HARD", "EXTREME"]],
	["enjoy", "How much did you enjoy\nthe puzzle?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["achieve", "How strong was your sense\nof achievement?\n(1 = none, 5 = very strong)", "achievement", ["1", "2", "3", "4", "5"]],
	["fair", "Were the rules of play\nclear and fair?", "fair", ["YES", "MOSTLY", "NO"]],
	["planned", "Did it require real planning\n(thinking several moves ahead)?", "needed planning", ["YES", "A LITTLE", "NO"]],
	["combo", "Did the combination of mechanics\nmake the puzzle more interesting?", "combination more interesting", ["YES", "A LITTLE", "NO"]],
	["feedback", "Optional: what made this puzzle\ndifficult or interesting?", "feedback", ["TEXT"]],
]
const R_CFG := {"data": "res://data/dev/extreme14.json", "state": "user://rtime_state.json", "title": "PUZZLE TEST\n(DEVELOPMENT)",
	"q2": "", "q2_key": "excite", "q2_label": "excitement", "pilot": true, "questions": TIMED_Q,
	"log_blocked": true, "hide_difficulty": true, "mech_events": true, "hint_budget": 1, "persist_live": true,
	"ls": "chain_escape_rtime_state"}

var _untimed_btn: PillButton
var _finish_btn: PillButton
var _continue_btn: PillButton
var _last_tap := -1
var _tap_board: Object = null
var _offer_fresh := false


static func requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + RKEY in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(RKEY + "=1") or where.contains(RKEY + "=true")


func _init() -> void:
	super()
	test = RKEY
	_cfg = R_CFG
	_questions = TIMED_Q.duplicate(true)


func _ready() -> void:
	super._ready()
	var rec: Dictionary = boards.get(R1_ID, {})
	board_ok = boards.size() == 1 and not rec.is_empty() and R1_FINGERPRINT != "" \
		and PuzzleDefinition.from_dict(rec["puzzle"]).fingerprint() == R1_FINGERPRINT
	_continue_btn = _card.find_child("TA_Continue", true, false)
	var col: Control = _continue_btn.get_parent()
	_untimed_btn = _button("CONTINUE WITHOUT TIMER", "TA_Untimed", ACCENT, Palette.WHITE)
	_untimed_btn.pressed.connect(begin_untimed)
	col.add_child(_untimed_btn)
	_finish_btn = _button("FINISH", "TA_Finish", Palette.WHITE, Palette.TEXT)
	_finish_btn.pressed.connect(func():
		AudioManager.play_ui_tap()
		_to_puzzle_questions(false))
	col.add_child(_finish_btn)
	_untimed_btn.visible = false
	_finish_btn.visible = false
	_show(screen)


func phase() -> String:
	return str(state.get("phase", "timed"))


func _set_phase(p: String) -> void:
	state["phase"] = p
	_save_state()


# --- Blocked taps with the tapped block ---------------------------------------------------

## Taps reach SocialPlay through its BoardInput control (the board's own
## input is off there); the same lookup tells which block was under the
## finger. SocialPlay is not changed.
func _watch_taps() -> void:
	if play._input == null or play._input == _tap_board:
		return
	_tap_board = play._input
	play._input.gui_input.connect(_note_tap)


func _note_tap(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed) or play.board == null:
		return
	var canvas_pos: Vector2 = play._input.get_global_transform_with_canvas() * event.position
	var local := play.board.get_global_transform_with_canvas().affine_inverse() * canvas_pos
	_last_tap = play.board._find_block_near(local)
	# A tap on an armored block changes nothing on the board (no move, no
	# mistake), so the action log never sees it: logged here ("a"), with the
	# block. SocialPlay has already handled the tap (it connected first).
	if _last_tap >= 0 and screen == Screen.PLAYING and _current.has("log") and not _current.has("completed") \
			and play.model.blocks.has(_last_tap) and play.model.blocks[_last_tap].armored:
		_current["log"].append([Time.get_ticks_msec() - _t0, "a", _last_tap])
		_save_live()


func _log_action(sig: Array, now: int) -> void:
	var n: int = _current.get("log", []).size()
	super._log_action(sig, now)
	var log: Array = _current.get("log", [])
	if log.size() > n and log[-1][1] == "b" and int(log[-1][2]) < 0:
		log[-1][2] = _last_tap


# --- The timed phase ends ------------------------------------------------------------------

func _finish_attempt(solved: bool) -> void:
	if phase() == "untimed":
		_finish_untimed(solved)
		return
	super._finish_attempt(solved)
	_current["armored_taps"] = _current.get("log", []).filter(func(e): return e[1] == "a").size()
	_current["board_fingerprint"] = R1_FINGERPRINT
	_current["phase"] = "timed"
	if not state.has("timed"):
		# Frozen: the timed result of this session, never rewritten.
		state["timed"] = _current.duplicate(true)
		state["phase"] = "timed_q"
		state["q"] = 0
		_save_state()


func _show(s: int) -> void:
	if s == Screen.RATE:
		match phase():
			"untimed", "puzzle_q":
				_q = int(state.get("q", 0))
				_questions = PUZZLE_Q.duplicate(true)
				super._show(Screen.THINK)
				_show_untimed_card()
			_:
				_questions = TIMED_Q.duplicate(true)
				_q = int(state.get("q", 0))
				super._show(Screen.THINK)
				_show_card()
		return
	super._show(s)
	if s == Screen.INTRO and board_ok:
		_intro_text.text = ("One puzzle you have not seen before. Three minutes.\n\nThe clock starts when the board appears and never stops: thinking, UNDO, RESTART and SHOW A MOVE all use time. RESTART starts the board again, not the clock. Leaving or reloading the page does not stop it either.\n\n"
			+ _tools_text() + "\n\nIf the time runs out, you can choose to keep playing without the clock.\n\nAfterwards: a few quick questions.")
	if s == Screen.INTRO and phase() != "timed" and int(state.get("index", 0)) < total():
		_start.text = "CONTINUE"
	if s == Screen.INTRO and not board_ok:
		_intro_text.text = "This build's test board does not match.\nThe test is disabled."


func _show_card() -> void:
	super._show_card()
	_continue_btn.visible = true
	_untimed_btn.visible = false
	_finish_btn.visible = false
	_card_text.text = _card_text.text.replace("A few quick questions next.", "A few quick questions about the timed run next.")
	_publish_settled()


func _draw_count() -> void:
	super._draw_count()
	if phase() == "untimed":
		_count.text = "NO TIMER"
		_count.add_theme_color_override("font_color", Palette.TEXT_SOFT)
		if _last_pub == Time.get_ticks_msec():
			_publish_ta()  # super published the clock text a moment ago


# --- Questions -----------------------------------------------------------------------------

func _build_options(opts: Array) -> void:
	if opts != PUZZLE_Q[0][3]:
		super._build_options(opts)
		return
	for c in _think_opts.get_children():
		_think_opts.remove_child(c)
		c.queue_free()
	for a in opts:  # five long answers: one per line on a phone
		var b := _button(a, "Think_%s" % a.replace(" ", "_"), Palette.WHITE, Palette.TEXT)
		b.custom_minimum_size = Vector2(0, 84)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			think(a))
		_think_opts.add_child(b)


func think(answer: String) -> void:
	var p := phase()
	var key: String = _questions[_q][0]
	if p == "timed_q":
		var t: Dictionary = state["timed"]
		var ans: Dictionary = t.get("answers", {})
		ans[key] = answer
		t["answers"] = ans
	else:
		var a2: Dictionary = state.get("puzzle_answers", {})
		a2[key] = answer
		state["puzzle_answers"] = a2
	_q += 1
	state["q"] = _q
	_save_state()
	if _q < _questions.size():
		_show(Screen.THINK)
		return
	if p == "timed_q":
		if str(state["timed"].get("outcome", "")) == "TIME UP":
			_show_offer()
		else:
			_to_puzzle_questions(false)
		return
	_store_results()


func _to_puzzle_questions(continued: bool) -> void:
	if not continued and not state.has("cont"):
		state["cont"] = {"continued": false}
	_card.visible = false
	_questions = PUZZLE_Q.duplicate(true)
	_q = 0
	state["q"] = 0
	_set_phase("puzzle_q")
	_show(Screen.THINK)


func _store_results() -> void:
	play.end()
	var results: Array = state.get("results", [])
	results.append({"id": R1_ID, "run": int(state["timed"].get("run", results.size() + 1)), "timed": state["timed"],
		"untimed": state.get("cont", {"continued": false}), "puzzle_answers": state.get("puzzle_answers", {}),
		"board_fingerprint": R1_FINGERPRINT})
	state["results"] = results
	state["index"] = int(state["index"]) + 1
	for k in ["live", "run", "budget", "timed", "cont", "phase", "q", "puzzle_answers"]:
		state.erase(k)
	_save_state()
	_current = {}
	start_next()


# --- After TIME UP: CONTINUE WITHOUT TIMER -------------------------------------------------

## The moves of the last attempt in a log (RESTART / reopen start a new
## attempt, UNDO takes one back): the position at the end of that log.
static func attempt_moves(log: Array) -> Array:
	var moves := []
	for e in log:
		match str(e[1]):
			"m":
				moves.append(int(e[2]))
			"u":
				if not moves.is_empty():
					moves.pop_back()
			"r", "o":
				moves.clear()
			"c", "k":
				moves = Array(e[3].get("moves", [])) if e.size() > 3 else []
	return moves


## Replays `moves` on a fresh model: the model, or null if a move is not legal.
func _replayed(moves: Array) -> BoardModel:
	var rec: Dictionary = boards[R1_ID]
	var level := PuzzleDefinition.from_dict(rec["puzzle"]).to_level()
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	for id in moves:
		match m.move_state(int(id)):
			"ok":
				m.remove(int(id))
			"ram":
				m.ram(int(id))
			_:
				return null
	return m


func _show_offer() -> void:
	var moves := attempt_moves(state["timed"].get("log", []))
	var m := _replayed(moves)
	var winnable := m != null and (m.is_empty() or not Solver.from_model(m).solve().is_empty())
	_offer_fresh = not winnable
	state["offer"] = {"from": "fresh" if _offer_fresh else "timeout_state", "moves": [] if _offer_fresh else moves}
	_set_phase("offer")
	_card_head.text = "TIME UP"
	_card_text.text = ("The timed result is recorded: TIME UP.\n\nYou can keep playing the same puzzle without the clock"
		+ (" from where you were at 0:00." if not _offer_fresh else ".\nThe board at 0:00 can no longer be cleared, so it starts fresh.")
		+ "\nThis does not change the timed result.")
	_continue_btn.visible = false
	_untimed_btn.visible = true
	_finish_btn.visible = true
	_card.visible = true
	_publish_ta()
	_publish_settled()


## The card's buttons move when the column lays out (next frame): the test
## snapshot is published again once they are in place.
func _publish_settled() -> void:
	for i in 2:
		await get_tree().process_frame
	_publish_ta()


## CONTINUE WITHOUT TIMER (or the same after a reload): the board, rebuilt
## to its position; a separate record and log.
func begin_untimed() -> void:
	AudioManager.play_ui_tap()
	var resume := phase() == "untimed"
	if not resume:
		var offer: Dictionary = state.get("offer", {"from": "fresh", "moves": []})
		state["cont"] = {"continued": true, "from": offer["from"], "start_moves": offer["moves"], "reopens": 0}
		state.erase("live")
		_set_phase("untimed")
	var cont: Dictionary = state["cont"]
	var rec: Dictionary = boards[R1_ID]
	var def := PuzzleDefinition.from_dict(rec["puzzle"])
	var c := SharedChallenge.friend_challenge(def, FriendGenerator.VERY_HARD)
	var live: Dictionary = state.get("live", {})
	var moves: Array = cont["start_moves"]
	if resume and live.get("phase", "") == "untimed" and typeof(live.get("record")) == TYPE_DICTIONARY:
		_current = live["record"].duplicate(true)
		moves = attempt_moves(_current["log"])
		cont["reopens"] = int(cont.get("reopens", 0)) + 1
	else:
		_current = {"id": R1_ID, "variant": rec["variant"], "phase": "untimed", "fingerprint": def.fingerprint(), "order": 1,
			"first_move_ms": -1, "longest_pause_ms": 0, "long_pauses": [], "gave_up": false, "log": [], "hint_presses": 0, "unaided_max_cleared": 0}
	_card.visible = false
	_show(Screen.PLAYING)
	play.back_label = ""
	_act_sig = []
	play.max_hints = 0 if hint_spent(R1_ID) else int(_cfg["hint_budget"])
	play.start(c, SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	play._title.text = "NO TIMER"
	play._chip.text = ""
	_watch_taps()
	var ok := _replayed(moves) != null
	if ok:
		for id in moves:
			play.tap_block(int(id))  # the same moves, the same rules
	_t0 = Time.get_ticks_msec() - int(live.get("elapsed_ms", 0) if resume else 0)
	_last_act = Time.get_ticks_msec()
	_current["log"].append([Time.get_ticks_msec() - _t0, "k" if resume else "c", -1, {"moves": moves if ok else [], "from": cont.get("from", "fresh")}])
	_prev_snap = _snap()
	_act_sig = _sig()
	_act_sig_prev = _sig()
	play._refresh_buttons()
	_save_untimed()


func _save_untimed() -> void:
	_current["time_ms"] = Time.get_ticks_msec() - _t0
	state["live"] = {"id": R1_ID, "phase": "untimed", "elapsed_ms": Time.get_ticks_msec() - _t0, "record": _current}
	_save_state()


func _save_live() -> void:
	if phase() == "untimed":
		if not _current.has("completed"):
			_save_untimed()
		return
	super._save_live()


func _on_solved() -> void:
	if phase() == "untimed" and screen == Screen.PLAYING:
		_finish_untimed(true)
		await get_tree().create_timer(1.0).timeout
		_show(Screen.RATE)
		return
	super._on_solved()


func _on_gave_up() -> void:
	if phase() == "untimed" and screen == Screen.PLAYING:
		_current["gave_up"] = true
		_current["log"].append([Time.get_ticks_msec() - _t0, "g", -1])
		_finish_untimed(false)
		_show(Screen.RATE)
		return
	super._on_gave_up()


## The untimed record (separate from the frozen timed one).
func _finish_untimed(solved: bool) -> void:
	if _current.has("completed"):
		return
	_track_pauses()  # the winning tap is logged on the next frame otherwise
	var log: Array = _current["log"]
	_current["completed"] = solved
	_current["outcome"] = "COMPLETED WITHOUT TIMER" if solved else "STOPPED"
	_current["time_ms"] = Time.get_ticks_msec() - _t0
	for k in [["moves", "m"], ["restarts", "r"], ["undos", "u"], ["hint_presses", "h"], ["blocked_taps", "b"], ["armored_taps", "a"], ["reopens", "k"]]:
		_current[k[0]] = log.filter(func(e): return e[1] == k[1]).size()
	_current["show_a_move"] = log.filter(func(e): return e[1] == "h" and e.size() > 3 and e[3].get("r", "") in ["shown", "lost"]).size()
	_current["max_cleared"] = maxi(int(_current.get("max_cleared", 0)), play._total_blocks - play.model.block_count())
	var cont: Dictionary = state["cont"]
	cont["record"] = _current
	cont["completed"] = solved
	cont["outcome"] = _current["outcome"]
	state.erase("live")
	state["q"] = 0
	state["phase"] = "puzzle_q"
	_save_state()


func _show_untimed_card() -> void:
	var cont: Dictionary = state.get("cont", {})
	_card_head.text = "SOLVED" if cont.get("completed", false) else "STOPPED"
	_card_text.text = ("Solved without the timer." if cont.get("completed", false) else "You stopped the untimed game.") \
		+ "\nThe timed result stays: %s.\n\nA few quick questions about the puzzle next." % str(state.get("timed", {}).get("outcome", "?"))
	_continue_btn.visible = true
	_untimed_btn.visible = false
	_finish_btn.visible = false
	_card.visible = true
	_publish_ta()
	_publish_settled()


func give_up() -> void:
	if phase() == "untimed" and screen == Screen.PLAYING:
		var now := Time.get_ticks_msec()
		if _give_up_armed == 0 or now > _give_up_armed:
			_give_up_armed = now + GIVE_UP_CONFIRM_MS
			_give_up.text = "TAP AGAIN TO STOP"
			return
		_give_up_armed = 0
		_on_gave_up()
		return
	super.give_up()


# --- Resuming a phase after a reload -------------------------------------------------------

func begin_puzzle() -> void:
	match phase():
		"timed_q":
			_current = state["timed"].duplicate(true)
			_show(Screen.RATE)
		"offer":
			_questions = TIMED_Q.duplicate(true)
			_q = _questions.size() - 1
			_show(Screen.THINK)
			_show_offer()
		"untimed":
			begin_untimed()
		"puzzle_q":
			_questions = PUZZLE_Q.duplicate(true)
			_q = int(state.get("q", 0))
			_show(Screen.THINK)
		_:
			super.begin_puzzle()
			_watch_taps()


func results_json() -> String:
	return JSON.stringify({"format": "ce-time-attack-blind", "v": 1, "test": RKEY, "board": R1_ID, "fingerprint": R1_FINGERPRINT, "limit_ms": LIMIT_MS,
		"device": OS.get_name(), "assist": _assist, "runs": state.get("results", []),
		"in_progress": {"phase": phase(), "timed": state.get("timed", {}), "untimed": state.get("cont", {})} if state.has("timed") or run_active() else {}})


func _summary_text() -> String:
	var lines := []
	var runs: Array = state.get("results", [])
	if runs.is_empty():
		lines.append("No run finished yet.")
	for r in runs:
		var t: Dictionary = r["timed"]
		var u: Dictionary = r.get("untimed", {})
		lines.append("Run %d - timed: %s (%s used, %s left); without timer: %s" % [int(r.get("run", 0)), t.get("outcome", "?"),
			_mmss(int(t.get("elapsed_ms", 0)), false), _mmss(int(t.get("remaining_ms", 0)), false),
			(str(u.get("outcome", "-")) if u.get("continued", false) else "not played")])
	if run_active() or state.has("timed"):
		lines.append("")
		lines.append("A run is in progress.")
	lines.append("")
	lines.append("Tap COPY RESULTS and paste it into the chat.")
	return "\n".join(lines)
