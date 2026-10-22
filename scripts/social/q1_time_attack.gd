class_name Q1TimeAttack
extends VhHumanTest
## DEVELOPMENT ONLY (?q1time=1): the 3-MINUTE CHALLENGE - the exact Q1 board
## of the phase-6 blind test (data/dev/extreme11.json, unchanged, checked by
## its fingerprint) against a 180-second countdown (docs/extreme13_time_attack.md).
## A subclass of the blind-test page: the same play screen, move log,
## mechanism events, blocked taps and the experimental tools of ?ptest11
## (UNDO x3 per attempt, ONE SHOW A MOVE per run - kept spent through
## RESTART, UNDO and a reload, a lost position costs it -, no HAMMER), with
## its own state (file and localStorage key) and its own questions.
## VhHumanTest, SocialPlay, the campaign timer and Personal Bests are not
## changed.
##
## THE CLOCK (one run = one 180 s countdown):
##   - It starts on the first normally paced frame after the board appears
##     (the campaign convention: the level build / first render, 1.7-2.3 s
##     in the Web build, does not count).
##   - It never stops: thinking, moves, UNDO, RESTART (the board starts again,
##     the clock does not), SHOW A MOVE, the page in the background, the page
##     closed. Within a page it is the monotonic engine clock; across a reload
##     or a reopen it is max(the elapsed time saved, the wall-clock time since
##     the run started) - leaving never gives time back. While the page runs it
##     is also never less than the wall-clock time since the start (a phone
##     whose monotonic clock stood still while suspended).
##   - It reaches 0:00 -> TIME UP: the run ends (not completed), the board is
##     covered, the result is recorded.
##   - A solve counts only if it happens before 0:00 (elapsed < 180000 ms).
##   - Hidden periods (Safari in the background, the phone locked) and
##     reopenings are recorded as interruptions; they are not paused.
##   - Client-side only: a determined tester can still cheat (e.g. by moving
##     the device clock back between reopenings, or by editing storage). It
##     prevents the obvious resets, nothing more.

const KEY := "q1time"
const LIMIT_MS := 180000
const WARN_MS := 30000
const SAVE_EVERY_MS := 1000
## A frame gap this long without a visibility event counts as an interruption
## (a suspended page that never said it was hidden).
const STALL_MS := 1500
## The clock starts by then even if no frame is ever normally paced.
const START_FALLBACK_MS := 4000
## The Q1 board of ?ptest11 (PuzzleDefinition.fingerprint, the page's own).
const Q1_FINGERPRINT := "3fc4f9259fd8390236caf337bc5260c9b9e06eb36fec09032cdf452adb413711"
const WARN_COLOR := Color("#B3261E")  # about 6:1 on the page background
const TA_QUESTIONS := [
	["enjoy", "How much did you enjoy it?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["excite", "How exciting was it?\n(1 = not at all, 5 = very)", "excitement", ["1", "2", "3", "4", "5"]],
	["frustrate", "How frustrating was it?\n(1 = not at all, 5 = very)", "frustration", ["1", "2", "3", "4", "5"]],
	["timer_better", "Did the 3-minute clock make\nthe puzzle better?", "timer improved it", ["YES", "NO", "NOT SURE"]],
	["again", "Would you play a\n3-minute challenge again?", "play again", ["YES", "MAYBE", "NO"]],
	["length", "Three minutes was...", "3 minutes", ["TOO SHORT", "ABOUT RIGHT", "TOO LONG"]],
	["feedback", "Optional: anything else\nabout the challenge?", "feedback", ["TEXT"]],
]
const CFG := {"data": "res://data/dev/extreme11.json", "state": "user://q1time_state.json", "title": "3-MINUTE CHALLENGE\n(DEVELOPMENT)",
	"q2": "", "q2_key": "enjoy", "q2_label": "enjoyment", "pilot": true, "questions": TA_QUESTIONS,
	"log_blocked": true, "hide_difficulty": true, "mech_events": true, "hint_budget": 1, "persist_live": true,
	"ls": "chain_escape_q1time_state"}

## Tests only: added to the clock (to reach the limit without waiting).
var debug_offset_ms := 0
var board_ok := false
var _count: Label
var _card: Control
var _card_head: Label
var _card_text: Label
var _new_run: PillButton
var _reset_btn: Control
var _start_frames := 0
var _run_live := false  # this page is counting an active run
var _base_ms := 0
var _page_t0 := 0
var _last_frame := 0
var _last_save := 0
var _hidden := false
var _hidden_since := 0
var _vis_cb: JavaScriptObject
var _last_pub := 0
var _begin_ms := 0


static func requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + KEY in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(KEY + "=1") or where.contains(KEY + "=true")


func _init() -> void:
	super("ptest11")  # the pilot setup (campaign tokens, bench flag)
	test = KEY
	_cfg = CFG
	ratings = X_RATINGS
	_questions = TA_QUESTIONS.duplicate(true)


func _ready() -> void:
	super._ready()
	var rec: Dictionary = boards.get("Q1", {})
	board_ok = boards.size() == 1 and not rec.is_empty() and PuzzleDefinition.from_dict(rec["puzzle"]).fingerprint() == Q1_FINGERPRINT
	_clock.visible = false  # the countdown replaces the elapsed clock
	_count = _label("3:00", 76, 900)
	_count.name = "Countdown"
	_count.autowrap_mode = TextServer.AUTOWRAP_OFF
	_count.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_count)
	_build_card()
	var res: Control = _pages[Screen.RESULTS]
	_new_run = _button("NEW 3-MINUTE RUN", "NewRun", ACCENT, Palette.WHITE)
	_new_run.pressed.connect(new_run)
	res.add_child(_new_run)
	res.move_child(_new_run, 3)
	_reset_btn = res.find_child("Reset", true, false)
	_watch_visibility()
	_show(screen)


func _new_order() -> void:
	# One board, no campaign question, no hardest-puzzle question.
	state = {"order": boards.keys(), "index": 0, "results": state.get("results", []), "reached": 300, "hardest": {"skipped": true},
		"started": Time.get_datetime_string_from_system()}


## Every save is numbered; the NEWEST copy wins on load. (The page saves to
## a user:// file, flushed to IndexedDB asynchronously on the Web, and to a
## synchronous localStorage mirror. The parent prefers the file when both
## hold as many answers, so a reload right after a save could bring back a
## stale run - an unspent SHOW A MOVE or a smaller elapsed time.)
func _save_state() -> void:
	state["seq"] = int(state.get("seq", 0)) + 1
	super._save_state()


func _load_state() -> void:
	var path: String = _cfg["state"]
	var texts := [FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""]
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(_cfg["ls"]))
	var best = null
	for t in texts:
		var parsed = JSON.parse_string(t) if t != "" else null
		if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("order") or not parsed["order"].all(func(id): return boards.has(str(id))):
			continue
		if best == null or int(parsed.get("seq", 0)) > int(best.get("seq", 0)):
			best = parsed
	if best != null:
		state = best
		state["index"] = int(state["index"])
	else:
		_new_order()
		_save_state()


func _tools_text() -> String:
	return "UNDO x%d per attempt, ONE SHOW A MOVE for the whole run (RESTART, UNDO or leaving does not give it back), no HAMMER." % int(_assist["undo"])


# --- The clock ---------------------------------------------------------------------------

## Milliseconds used of this run (0 before it starts).
func elapsed_ms() -> int:
	var run: Dictionary = state.get("run", {})
	if not _run_live:
		return int(run.get("elapsed_ms", 0))
	# The engine's monotonic clock; and never less than the wall clock since
	# the run started (a suspended page whose monotonic clock stood still).
	var mono := _base_ms + Time.get_ticks_msec() - _page_t0
	var wall := int((Time.get_unix_time_from_system() - float(run.get("started_unix", 0.0))) * 1000.0)
	return maxi(mono, wall) + debug_offset_ms


func remaining_ms() -> int:
	return maxi(0, LIMIT_MS - elapsed_ms())


func run_active() -> bool:
	var run: Dictionary = state.get("run", {})
	return run.has("started_unix") and not run.get("done", false)


func _start_run() -> void:
	var n: int = state.get("results", []).size() + 1
	state["run"] = {"n": n, "started_unix": Time.get_unix_time_from_system(), "elapsed_ms": 0, "done": false, "reopens": 0,
		"hidden_count": 0, "hidden_ms": 0, "stalls": 0}
	_base_ms = 0
	_page_t0 = Time.get_ticks_msec()
	_last_frame = _page_t0
	_last_save = _page_t0
	_run_live = true
	_current["run"] = n
	_current["run_start_ms"] = Time.get_ticks_msec() - _t0
	_save_live()


func _process(delta: float) -> void:
	super._process(delta)
	if screen != Screen.PLAYING:
		return
	var now := Time.get_ticks_msec()
	var sf: Array = _current.get("start_frames", [])
	if sf.size() < 20 and _begin_ms > 0:
		sf.append(now - _begin_ms)  # ms since the board was shown, per frame (diagnostics)
		_current["start_frames"] = sf
	if _start_frames > 0:
		# Wait out the board's build / first render (1.7-2.3 s in the Web
		# build, the campaign timer leaves it out too): start on the first
		# normally paced frame after at least two frames.
		# normally paced = not longer than the campaign timer's MAX_FRAME; a
		# phone that never gets there still starts after START_FALLBACK_MS.
		var paced := now - _last_frame <= int(AttemptTimer.MAX_FRAME * 1000.0) or now - _begin_ms >= START_FALLBACK_MS
		_last_frame = now
		_start_frames = maxi(_start_frames - 1, 1 if not paced else 0)
		if _start_frames == 0 and not run_active() and board_ok:
			_start_run()
	if not _run_live or not run_active():
		_draw_count()
		return
	var gap := now - _last_frame
	_last_frame = now
	if gap > STALL_MS and not _hidden:
		# Suspended without a visibility event: an interruption (still counted).
		state["run"]["stalls"] = int(state["run"]["stalls"]) + 1
		_current["log"].append([now - _t0, "v", -1, {"stall_ms": gap}])
	var cleared := play._total_blocks - play.model.block_count()
	_current["max_cleared"] = maxi(int(_current.get("max_cleared", 0)), cleared)
	if elapsed_ms() >= LIMIT_MS:
		_time_up()
		return
	if now - _last_save >= SAVE_EVERY_MS:
		_last_save = now
		state["run"]["elapsed_ms"] = elapsed_ms()
		_save_live()
	_draw_count()


func _draw_count() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_pub >= 250:
		_last_pub = now
		_publish_ta()  # tests read the clock (cheap; Web only)
	var left := remaining_ms()
	var sec := int(ceil(left / 1000.0))
	_count.text = "%d:%02d" % [sec / 60, sec % 60]
	_count.add_theme_color_override("font_color", WARN_COLOR if left <= WARN_MS else Palette.TEXT)
	# Between the play screen's top bar and the board, never over the board.
	if play and play.board and play._progress.is_visible_in_tree():
		var top := play._progress.get_global_rect().end.y
		var board_top := play.board.get_board_rect().position.y
		var h := _count.get_combined_minimum_size().y
		_count.position.y = clampf((top + board_top - h) / 2.0, top, board_top - h - 4.0)
		_count.size.x = get_viewport().get_visible_rect().size.x
		_count.position.x = 0.0


## 0:00: the run ends (not completed).
func _time_up() -> void:
	if not run_active():
		return
	var now := Time.get_ticks_msec()
	_current["log"].append([now - _t0, "t", -1])
	_current["outcome"] = "TIME UP"
	_current["elapsed_ms"] = LIMIT_MS
	_finish_attempt(false)
	_show(Screen.RATE)


# --- Page visibility (Safari in the background, the phone locked) -------------------------

func _watch_visibility() -> void:
	if not OS.has_feature("web"):
		return
	var doc = JavaScriptBridge.get_interface("document")
	var win = JavaScriptBridge.get_interface("window")
	if doc == null or win == null:
		return
	_vis_cb = JavaScriptBridge.create_callback(_on_visibility)
	doc.addEventListener("visibilitychange", _vis_cb)
	win.addEventListener("pagehide", _vis_cb)
	win.addEventListener("pageshow", _vis_cb)


func _on_visibility(args: Array) -> void:
	var doc = JavaScriptBridge.get_interface("document")
	var hidden := bool(doc.hidden) if doc != null else false
	if not args.is_empty() and args[0] != null and str(args[0].type) == "pagehide":
		hidden = true
	page_hidden(hidden)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		page_hidden(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		page_hidden(false)


## The page went into / came back from the background. Nothing is paused:
## the clock keeps running; the period is recorded, and the run is saved at
## once on the way out (iOS may end a hidden page without notice).
func page_hidden(hidden: bool) -> void:
	if hidden == _hidden:
		return
	_hidden = hidden
	var now := Time.get_ticks_msec()
	if not (_run_live and run_active()):
		return
	if hidden:
		_hidden_since = now
		state["run"]["elapsed_ms"] = elapsed_ms()
		_save_live()
		return
	var away := now - _hidden_since
	state["run"]["hidden_count"] = int(state["run"]["hidden_count"]) + 1
	state["run"]["hidden_ms"] = int(state["run"]["hidden_ms"]) + away
	_current["log"].append([now - _t0, "v", -1, {"hidden_ms": away}])
	_last_frame = now  # the gap is already recorded as hidden
	_save_live()


# --- Flow --------------------------------------------------------------------------------

func begin_puzzle() -> void:
	var active := run_active()
	if active:
		state["run"]["reopens"] = int(state["run"]["reopens"]) + 1
	super.begin_puzzle()
	if screen != Screen.PLAYING:
		return  # finished before a reload: the result card
	if active:
		# A reload / reopen of a run in progress: no time given back.
		var run: Dictionary = state["run"]
		var wall := int((Time.get_unix_time_from_system() - float(run["started_unix"])) * 1000.0)
		_base_ms = maxi(int(run["elapsed_ms"]), wall)
		_page_t0 = Time.get_ticks_msec()
		_last_frame = _page_t0
		_last_save = _page_t0
		_run_live = true
		_current["run"] = int(run["n"])
		if elapsed_ms() >= LIMIT_MS:
			_time_up()
			return
		_save_live()
	else:
		_run_live = false
		_start_frames = 2  # the first frames build and render the board (not play)
		_last_frame = Time.get_ticks_msec()
		_begin_ms = _last_frame
	_draw_count()


func _on_solved() -> void:
	if screen != Screen.PLAYING or not run_active():
		return
	var el := elapsed_ms()
	if el >= LIMIT_MS:
		_time_up()  # the last move came at or after 0:00
		return
	_current["outcome"] = "COMPLETED"
	_current["elapsed_ms"] = el
	_finish_attempt(true)
	await get_tree().create_timer(1.0).timeout
	_show(Screen.RATE)


func _finish_attempt(solved: bool) -> void:
	super._finish_attempt(solved)
	if not _current.has("outcome"):
		_current["outcome"] = "GAVE UP" if _current.get("gave_up", false) else ("COMPLETED" if solved else "NOT COMPLETED")
	var el := clampi(int(_current.get("elapsed_ms", elapsed_ms())), 0, LIMIT_MS)
	var run: Dictionary = state.get("run", {})
	_current["elapsed_ms"] = el
	_current["remaining_ms"] = LIMIT_MS - el
	_current["limit_ms"] = LIMIT_MS
	_current["completed"] = _current["outcome"] == "COMPLETED"
	_current["max_cleared"] = maxi(int(_current.get("max_cleared", 0)), play._total_blocks - play.model.block_count())
	_current["cleared_at_end"] = play._total_blocks - play.model.block_count()
	_current["pieces"] = play._total_blocks
	_current["run_reopens"] = int(run.get("reopens", 0))
	_current["hidden_count"] = int(run.get("hidden_count", 0))
	_current["hidden_ms"] = int(run.get("hidden_ms", 0))
	_current["stalls"] = int(run.get("stalls", 0))
	_current["interrupted"] = _current["run_reopens"] > 0 or _current["hidden_count"] > 0 or _current["stalls"] > 0
	_current["board_fingerprint"] = Q1_FINGERPRINT
	if not run.is_empty():
		run["done"] = true
		run["elapsed_ms"] = el
	_run_live = false
	state["live"] = {"id": _current["id"], "finished": true, "record": _current}
	_save_state()


func think(answer: String) -> void:
	super.think(answer)
	if not state.has("live") and state.get("run", {}).get("done", false):
		state.erase("run")  # the run and its answers are stored in results
		state.erase("budget")
		_save_state()


## After a finished run: a fresh 180 s and a fresh SHOW A MOVE.
func new_run() -> void:
	if run_active() or int(state["index"]) < total():
		return
	state["index"] = 0
	state.erase("budget")
	state.erase("live")
	state.erase("run")
	_save_state()
	start_next()


# --- Screens -----------------------------------------------------------------------------

func _show(s: int) -> void:
	if _card:
		_card.visible = false
	if s == Screen.RATE:
		# No difficulty question here: the result, then the questions.
		_q = 0
		super._show(Screen.THINK)
		_show_card()
		return
	if s == Screen.HARDEST or s == Screen.PROFILE:
		s = Screen.RESULTS if int(state.get("index", 0)) >= total() else Screen.INTRO
	super._show(s)
	match s:
		Screen.INTRO:
			_start.disabled = not board_ok
			if not board_ok:
				_intro_text.text = "This build's Q1 board does not match the tested board.\nThe challenge is disabled."
			else:
				_intro_text.text = ("One puzzle. Three minutes.\n\nThe clock starts when the board appears and never stops: thinking, UNDO, RESTART and SHOW A MOVE all use time. RESTART starts the board again, not the clock. Leaving or reloading the page does not stop it either.\n\n"
					+ _tools_text() + "\n\nAfter the run: a few quick questions.")
				_start.text = "START" if not run_active() else "CONTINUE (THE CLOCK IS RUNNING)"
				if int(state["index"]) >= total():
					_start.text = "SEE RESULTS"
		Screen.BRIEF:
			_brief_text.text = "3:00\n\n" + _brief_text.text.replace("PUZZLE 1 / 1\n\n", "") + "\n\nThe clock starts when the board appears."
		Screen.RESULTS:
			_new_run.visible = not run_active() and int(state["index"]) >= total()
			if _reset_btn:
				_reset_btn.visible = not run_active()
	if _count:
		_count.visible = s == Screen.PLAYING
	_publish_ta()


func _build_card() -> void:
	_card = ColorRect.new()
	(_card as ColorRect).color = Palette.BACKGROUND
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.visible = false
	add_child(_card)
	var col := _column()
	col.get_parent().remove_child(col)  # _column() puts it on the page root
	_card.add_child(col)
	_card_head = _label("", 64, 900)
	col.add_child(_card_head)
	_card_text = _label("", 30, 800)
	col.add_child(_card_text)
	var go := _button("CONTINUE", "TA_Continue", ACCENT, Palette.WHITE)
	go.pressed.connect(func():
		AudioManager.play_ui_tap()
		_card.visible = false
		_publish_ta())
	col.add_child(go)


func _show_card() -> void:
	var r := _current
	var used := int(r.get("elapsed_ms", 0))
	var left := int(r.get("remaining_ms", 0))
	match str(r.get("outcome", "")):
		"COMPLETED":
			_card_head.text = "SOLVED"
			_card_text.text = "in %s, with %s left." % [_mmss(used, false), _mmss(left, false)]
		"TIME UP":
			_card_head.text = "TIME UP"
			_card_text.text = "The 3 minutes are over.\nMost pieces cleared in one attempt: %d of %d." % [int(r.get("max_cleared", 0)), int(r.get("pieces", 13))]
		_:
			_card_head.text = "STOPPED"
			_card_text.text = "after %s.\nMost pieces cleared in one attempt: %d of %d." % [_mmss(used, false), int(r.get("max_cleared", 0)), int(r.get("pieces", 13))]
	_card_text.text += "\n\nA few quick questions next."
	_card.visible = true
	_publish_ta()


static func _mmss(ms: int, up: bool) -> String:
	var sec := int(ceil(ms / 1000.0)) if up else ms / 1000
	return "%d:%02d" % [sec / 60, sec % 60]


func results_json() -> String:
	return JSON.stringify({"format": "ce-q1-time-attack", "v": 1, "test": KEY, "board": "Q1", "fingerprint": Q1_FINGERPRINT, "limit_ms": LIMIT_MS,
		"device": OS.get_name(), "assist": _assist, "runs": state.get("results", []), "run_in_progress": state.get("run", {}) if run_active() else {}})


func _summary_text() -> String:
	var lines := []
	var runs: Array = state.get("results", [])
	if runs.is_empty():
		lines.append("No run finished yet.")
	for r in runs:
		lines.append("Run %d: %s - %s used, %s left; %d attempts, SHOW A MOVE %d, UNDO %d%s" % [int(r.get("run", 0)), r.get("outcome", "?"),
			_mmss(int(r.get("elapsed_ms", 0)), false), _mmss(int(r.get("remaining_ms", 0)), false), int(r.get("attempts", 1)),
			int(r.get("show_a_move", 0)), int(r.get("undos", 0)), " (interrupted)" if r.get("interrupted", false) else ""])
	if run_active():
		lines.append("")
		lines.append("A run is in progress: its clock is still running.")
	lines.append("")
	lines.append("Tap COPY RESULTS and paste it into the chat.")
	return "\n".join(lines)


## Web: a read-only snapshot for the browser tests (window.chainEscapeTimeAttack).
func _publish_ta() -> void:
	if not OS.has_feature("web") or not is_inside_tree():
		return
	var vis := get_viewport().get_visible_rect().size
	var buttons := {}
	if _card and _card.visible:
		for b in _card.find_children("*", "BaseButton", true, false):
			var c: Vector2 = b.get_global_rect().get_center()
			buttons[String(b.name)] = [snappedf(c.x / vis.x, 0.0001), snappedf(c.y / vis.y, 0.0001)]
	if screen == Screen.RESULTS and _new_run and _new_run.is_visible_in_tree():
		var c2: Vector2 = _new_run.get_global_rect().get_center()
		buttons["NewRun"] = [snappedf(c2.x / vis.x, 0.0001), snappedf(c2.y / vis.y, 0.0001)]
	var count_bottom := -1.0
	var board_top := -1.0
	if _count and _count.is_visible_in_tree() and play and play.board:
		count_bottom = snappedf(_count.get_global_rect().end.y / vis.y, 0.0001)
		board_top = snappedf(play.board.get_board_rect().position.y / vis.y, 0.0001)
	WebBridge.publish("chainEscapeTimeAttack", {"screen": Screen.keys()[screen], "card": _card != null and _card.visible,
		"card_head": _card_head.text if _card else "", "count_text": _count.text if _count else "", "warn": _count != null and _count.get_theme_color("font_color") == WARN_COLOR,
		"remaining_ms": remaining_ms(), "elapsed_ms": elapsed_ms(), "run_active": run_active(), "run_live": _run_live, "board_ok": board_ok,
		"count_bottom": count_bottom, "board_top": board_top, "buttons": buttons, "runs": state.get("results", []).size()})


func _publish() -> void:
	super._publish()
	_publish_ta()
