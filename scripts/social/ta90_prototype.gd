class_name Ta90Prototype
extends CanvasLayer
## DEVELOPMENT ONLY (?ta90=1): the 90-second Time Attack prototype with
## dynamic music (docs/ta90_prototype.md). A separate copy of the 120-second
## pilot hub (TaPilot, unchanged) with its own storage and boards:
##   WELCOME -> (once) how familiar are you with Chain Escape? -> CHOOSE A
##   PUZZLE (the accepted Phase 13 boards) -> the 90 s Time Attack
##   (Ta90TimeAttack: the pilot page on a 90 s clock, StageMusic) -> SOLVED /
##   TIME UP -> optional CONTINUE WITHOUT TIMER (calm music) -> short
##   questions (all skippable) -> back to CHOOSE A PUZZLE.
## COPY ALL RESULTS copies one anonymous bundle (random session id,
## familiarity, the music setting, every run). Browser storage only, its own
## keys ("ta90_*"); the 120-second pilot's and every standalone page's data
## are never read or written.
## While this hub is open the campaign music bus stays silent (restored on
## exit; the player's saved setting is never changed) - the page's own
## StageMusic plays on its own bus, only after the START tap unlocked audio,
## and only if the global music setting is on.
## &ta90ref=1 (development checks only): adds TA, a validated 120-second
## board, as an internal REFERENCE row to test the clock and the music - it
## is never a new puzzle and is never listed without that flag.
## Player / QA builds: never opened (BuildFlags.dev_pages_off()); the boards
## and the music are not in those builds.

const PARAM := "ta90"
const STATE_PATH := "user://ta90_hub.json"
const LS_KEY := "chain_escape_ta90_hub"
const ACCENT := Color("#1A9FE6")
## The HUMAN-REVIEW CANDIDATES in the order shown: N1-N3 (Phase 14), N4-N13
## (Phase 15, in a mixed order of size and design target - PUZZLE k is N<k>).
const ORDER90 := ["N1", "N2", "N3", "N4", "N5", "N6", "N7", "N8", "N9", "N10", "N11", "N12", "N13"]
const WELCOME := "Clear a puzzle in 90 seconds, with music that follows the clock.\n\nPlay one puzzle, or more, in any order. Turn the music off any time with the MUSIC button.\n\nAfter each puzzle: a few quick questions (you can skip any of them).\n\nNo names, no accounts: your answers stay on this phone until you tap COPY ALL RESULTS and send them to us."

enum View { WELCOME, FAMILIARITY, SELECT, PUZZLE }

var state: Dictionary = {}
var view: int = View.WELCOME
var page: Ta90TimeAttack
var order: Array = []  # the rows shown (ORDER90, plus the reference with &ta90ref=1)
var _pages: Dictionary = {}
var _root: Control
var _rows: Dictionary = {}  # board -> [button, status label]
var _copy: PillButton
var _copy_status: Label


static func requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(PARAM + "=1") or where.contains(PARAM + "=true")


func _init() -> void:
	layer = 29  # over the game UI; the puzzle page (VhHumanTest, 30) over it


# --- What an entry is (Phase 16: Extreme90Bank overrides these; here they are
# exactly the ?ta90=1 experimental collection's constants) ---------------------------------

## The boards shown, in order.
func board_order() -> Array:
	return ORDER90


## The board pages' storage prefix (Ta90TimeAttack p_store).
func store() -> String:
	return "ta90"


func hub_state_path() -> String:
	return STATE_PATH


func hub_ls_key() -> String:
	return LS_KEY


## The neutral player-facing word for one board.
func word() -> String:
	return "PUZZLE"


func welcome_title() -> String:
	return "TIME ATTACK\nPLAYTEST"


func welcome_text() -> String:
	return WELCOME


func select_title() -> String:
	return "CHOOSE A PUZZLE"


## &ta90ref=1 adds the TA reference row (development checks).
func allows_reference() -> bool:
	return true


func bundle_format() -> String:
	return "ce-ta90"


## Phase 16A: the page's SHORT questionnaire (Ta90TimeAttack.short_q).
func short_questions() -> bool:
	return false


## The window.* name of the read-only snapshot for browser tests.
func publish_name() -> String:
	return "chainEscapeTa90"


static func reference_requested() -> bool:
	if "--ta90ref" in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	return loc != null and (str(loc.search) + str(loc.hash)).to_lower().contains("ta90ref=1")


func _ready() -> void:
	order = board_order().duplicate()
	if allows_reference() and (reference_requested() or order.is_empty()):
		order.append("TA")
	_silence_campaign_music(true)
	_load_state()
	_build()
	set_process(true)
	# A puzzle left mid-way (a reload, the page closed): straight back to it.
	var cur := str(state.get("current", ""))
	if cur != "" and order.has(cur) and _in_progress(Ta90TimeAttack.read_state90(cur, store())):
		open_puzzle(cur)
	elif str(state.get("familiarity", "")) != "":
		_show(View.SELECT)
	else:
		_show(View.WELCOME)


# --- State (its own key; anonymous) --------------------------------------------------------

func _load_state() -> void:
	var texts := [FileAccess.get_file_as_string(hub_state_path()) if FileAccess.file_exists(hub_state_path()) else ""]
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(hub_ls_key()))
	for t in texts:
		var parsed = JSON.parse_string(t) if t != "" else null
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("session") and (state.is_empty() or int(parsed.get("seq", 0)) > int(state.get("seq", 0))):
			state = parsed
	if state.is_empty():
		# Anonymous: random, made on this device, linked to nothing else.
		state = {"session": Crypto.new().generate_random_bytes(8).hex_encode(), "familiarity": "", "current": "", "music_on": true,
			"started": Time.get_datetime_string_from_system(true).left(10)}
		_save_state()


func _save_state() -> void:
	state["seq"] = int(state.get("seq", 0)) + 1
	var text := JSON.stringify(state)
	var f := FileAccess.open(hub_state_path(), FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	if OS.has_feature("web"):
		WebBridge.ls_set(hub_ls_key(), text)


## A board's page has something unfinished (a run, the questions, the untimed game).
static func _in_progress(st: Dictionary) -> bool:
	if st.is_empty():
		return false
	var run_on: bool = st.get("run", {}).has("started_unix") and not st.get("run", {}).get("done", false)
	return run_on or st.has("timed")


func set_familiarity(answer: String) -> void:
	state["familiarity"] = answer
	_save_state()
	_show(View.SELECT)


# --- One puzzle ---------------------------------------------------------------------------

## Opens a board's page: resumes what is unfinished, else a new run (the
## card before the board first).
func open_puzzle(board: String) -> void:
	close_puzzle(false)
	state["current"] = board
	_save_state()
	page = Ta90TimeAttack.new(board, str(state.get("familiarity", "")), str(state["session"]), order.find(board) + 1, bool(state.get("music_on", true)), store(), word())
	page.short_q = short_questions()
	page.music_changed.connect(func(on):
		state["music_on"] = on
		_save_state())
	page.leave.connect(close_puzzle.bind(true), CONNECT_DEFERRED)
	add_child(page)
	_show(View.PUZZLE)
	if not page.board_ok:
		return  # the page says the test is disabled
	if int(page.state.get("index", 0)) >= page.total() and not page.run_active():
		page.new_run()  # played before: a new run (not a first exposure)
	elif page.run_active() or page.phase() != "timed":
		page.begin_puzzle()  # resume: the clock was never stopped
	else:
		page.start_next()


func close_puzzle(show_select: bool = true) -> void:
	if page:
		if page.play:
			page.play.end()
		page.queue_free()
		page = null
	if show_select:
		state["current"] = ""
		_save_state()
		_show(View.SELECT)


# --- Export -------------------------------------------------------------------------------

## Every board's runs in one bundle (anonymous).
func bundle() -> Dictionary:
	var boards := {}
	var runs := []
	for b in order:
		var st := Ta90TimeAttack.read_state90(b, store())
		var raw: Array = st.get("results", [])
		for r in raw:
			runs.append(PilotTimeAttack.summarize(b, r))
		boards[b] = {"puzzle": order.find(b) + 1, "fingerprint": Ta90TimeAttack.BOARDS90[b]["fp"], "reference": Ta90TimeAttack.BOARDS90[b].get("reference", false), "raw": raw,
			"in_progress": {"phase": st.get("phase", "timed"), "timed": st.get("timed", {}), "untimed": st.get("cont", {})} if _in_progress(st) else {}}
	return {"format": bundle_format(), "v": 1, "session": state["session"], "familiarity": state.get("familiarity", ""), "started": state.get("started", ""),
		"music_on": state.get("music_on", true), "rules": Ta90TimeAttack.TA90_RULES, "runs": runs, "boards": boards}


func results_json() -> String:
	return JSON.stringify(bundle())


## One line per board for the selection screen.
func _status(board: String) -> String:
	var st := Ta90TimeAttack.read_state90(board, store())
	var res: Array = st.get("results", [])
	if _in_progress(st):
		return "In progress - tap to continue"
	if res.is_empty():
		return "Not played yet"
	var s := PilotTimeAttack.summarize(board, res[-1])
	var line := ""
	if s["timed_success"]:
		line = "Solved in %s" % Q1TimeAttack._mmss(int(s["elapsed_ms"]), false)
	elif s["timed_outcome"] == "TIME UP":
		line = "Time up" + (" - solved without the timer" if s["untimed_success"] else "")
	else:
		line = "Stopped"
	return line + ("  (played %d times)" % res.size() if res.size() > 1 else "")


## The grid tile's status (a few words: the full line does not fit a tile).
func short_status(board: String) -> String:
	var st := Ta90TimeAttack.read_state90(board, store())
	var res: Array = st.get("results", [])
	if _in_progress(st):
		return "Continue"
	if res.is_empty():
		return "New"
	var s := PilotTimeAttack.summarize(board, res[-1])
	var line := "Stopped"
	if s["timed_success"]:
		line = "Solved " + Q1TimeAttack._mmss(int(s["elapsed_ms"]), false)
	elif s["timed_outcome"] == "TIME UP":
		line = "Time up" + (" / solved" if s["untimed_success"] else "")
	return line + (" x%d" % res.size() if res.size() > 1 else "")


# --- Screens ------------------------------------------------------------------------------

func _show(v: int) -> void:
	view = v
	_root.visible = v != View.PUZZLE
	for k in _pages:
		_pages[k].visible = k == v
	if v == View.SELECT:
		for b in _rows:
			_rows[b][1].text = _status(b) if Ta90TimeAttack.BOARDS90[b].get("reference", false) else short_status(b)
		_copy_status.text = ""
		if OS.has_feature("web"):
			SocialWeb.set_share(results_json(), "", "")
	_zones.call_deferred()


func _process(_delta: float) -> void:
	if view == View.SELECT:
		var r := SocialWeb.take_share_result() if OS.has_feature("web") else ""
		if r == "copied":
			_copy_status.text = "COPIED - paste it into the chat"
		elif r == "failed":
			_copy_status.text = "COULDN'T COPY - take a screenshot instead"
		if r != "":
			_publish()


## COPY ALL RESULTS: the copy runs in the page script inside the tap (iOS).
func _zones() -> void:
	await get_tree().process_frame
	if view == View.SELECT and _copy.is_visible_in_tree():
		var vis := get_viewport().get_visible_rect().size
		var r := _copy.get_global_rect()
		SocialWeb.set_zones([{"id": "copy", "x": r.position.x / vis.x, "y": r.position.y / vis.y, "w": r.size.x / vis.x, "h": r.size.y / vis.y}])
	elif view != View.PUZZLE:
		SocialWeb.set_zones([])
	_publish()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = Palette.BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# WELCOME
	var w := _column()
	w.add_child(_label(welcome_title(), 44, 900))
	w.add_child(_label(welcome_text(), 26, 700))
	var go := _button("START", "PilotStart", ACCENT, Palette.WHITE)
	go.pressed.connect(func():
		AudioManager.play_ui_tap()
		_show(View.SELECT if str(state.get("familiarity", "")) != "" else View.FAMILIARITY))
	w.add_child(go)
	_pages[View.WELCOME] = w
	# FAMILIARITY (asked once)
	var f := _column()
	f.add_child(_label("How familiar are you\nwith Chain Escape?", 36, 900))
	for a in PilotTimeAttack.FAMILIARITY:
		var b := _button(a, "Familiar_%s" % a.replace(" ", "_"), Palette.WHITE, Palette.TEXT)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			set_familiarity(a))
		f.add_child(b)
	_pages[View.FAMILIARITY] = f
	# SELECT
	var s := _column()
	s.add_theme_constant_override("separation", 10)
	s.add_child(_label(select_title(), 40, 900))
	s.add_child(_label("90 seconds each. Play one or more.", 24, 700))
	if board_order().is_empty():
		# No new board passed its checks yet: say so - the reference is not a new puzzle.
		var note := _label("Technical test build: no new 90-second puzzle has passed its checks yet. REFERENCE (TA) is an existing board, used to test the clock and the music.", 20, 700)
		note.name = "ReferenceNote"
		note.add_theme_color_override("font_color", Palette.TEXT_SOFT)
		s.add_child(note)
	# Phase 15: up to 15 puzzles on an iPhone SE without scrolling - a grid of
	# compact tiles (PUZZLE n + a short status), three to a row; the reference
	# (&ta90ref=1 only) keeps its own full-width, labelled row below.
	var grid := GridContainer.new()
	grid.name = "PuzzleGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	s.add_child(grid)
	for b in order:
		var ref: bool = Ta90TimeAttack.BOARDS90[b].get("reference", false)
		var n := order.find(b) + 1
		var btn: PillButton
		var st := _label("", 18 if not ref else 22, 700)
		st.add_theme_color_override("font_color", Palette.TEXT_SOFT)
		if ref:
			btn = _button("REFERENCE (TA)", "Puzzle_%d" % n, Palette.WHITE, Palette.TEXT)
			s.add_child(btn)
			s.add_child(st)
		else:
			# A long word ("CHALLENGE 12") must never widen its tile past a
			# third of the screen: a smaller font, and the text clipped.
			btn = PillButton.new("%s %d" % [word(), n], PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 18 if word().length() > 6 else 24)
			btn.name = "Puzzle_%d" % n
			btn.custom_minimum_size = Vector2(0, 84)
			btn.clip_text = true
			var tile := VBoxContainer.new()
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile.add_theme_constant_override("separation", 2)
			tile.add_child(btn)
			tile.add_child(st)
			grid.add_child(tile)
		btn.pressed.connect(func():
			AudioManager.play_ui_tap()
			open_puzzle(b))
		_rows[b] = [btn, st]
	_copy = _button("COPY ALL RESULTS", "CopyResults", ACCENT, Palette.WHITE)
	s.add_child(_copy)  # the copy itself runs in the page script, inside the tap (iOS)
	_copy_status = _label("", 22, 800)
	s.add_child(_copy_status)
	var how := _button("HOW IT WORKS", "HowItWorks", Palette.BACKGROUND, Palette.TEXT_SOFT)
	how.custom_minimum_size = Vector2(0, 80)
	how.pressed.connect(func(): _show(View.WELCOME))
	s.add_child(how)
	_pages[View.SELECT] = s


func _column() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40.0
	box.offset_right = -40.0
	box.offset_top = 70.0
	box.offset_bottom = -50.0
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
	b.custom_minimum_size = Vector2(0, 96)
	return b


## Web: read-only snapshot for automated browser tests (window.chainEscapeTa90).
func _publish() -> void:
	if not OS.has_feature("web") or not is_inside_tree():
		return
	var vis := get_viewport().get_visible_rect().size
	var buttons := {}
	var rects := {}
	if _root.visible:
		for b in _pages[view].find_children("*", "BaseButton", true, false):
			if b.is_visible_in_tree():
				var r: Rect2 = b.get_global_rect()
				buttons[String(b.name)] = [snappedf(r.get_center().x / vis.x, 0.0001), snappedf(r.get_center().y / vis.y, 0.0001)]
				rects[String(b.name)] = [snappedf(r.position.x / vis.x, 0.0001), snappedf(r.position.y / vis.y, 0.0001), snappedf(r.size.x / vis.x, 0.0001), snappedf(r.size.y / vis.y, 0.0001)]
	var statuses := {}
	for b in _rows:
		statuses[str(order.find(b) + 1)] = _rows[b][1].text
	WebBridge.publish(publish_name(), {"order": order, "music_on": state.get("music_on", true), "view": View.keys()[view], "buttons": buttons, "rects": rects, "statuses": statuses,
		"familiarity": state.get("familiarity", ""), "current": state.get("current", ""), "session": state.get("session", ""), "copy_status": _copy_status.text,
		"content_bottom": snappedf(_pages[view].get_combined_minimum_size().y / vis.y, 0.0001) if view != View.PUZZLE else -1.0})


## The campaign music bus stays silent while the prototype is open (the
## player's saved setting is never changed); restored on exit.
func _silence_campaign_music(on: bool) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, on or not AudioManager.music_enabled)


func _exit_tree() -> void:
	_silence_campaign_music(false)
