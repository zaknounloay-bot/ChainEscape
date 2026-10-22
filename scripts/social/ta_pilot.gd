class_name TaPilot
extends CanvasLayer
## DEVELOPMENT ONLY (?tapilot=1): the external Time Attack pilot for a few
## invited players - one link, no instructions needed:
##   WELCOME -> (once) how familiar are you with Chain Escape? -> CHOOSE A
##   PUZZLE (PUZZLE 1-4: the validated boards TA, TB, TC, S1) -> the 120 s
##   Time Attack (PilotTimeAttack: the existing page, rules and clock) ->
##   SOLVED / TIME UP -> optional CONTINUE WITHOUT TIMER -> short questions
##   (all skippable) -> back to CHOOSE A PUZZLE. One puzzle is enough; any
##   puzzle can be played in any order, again if wanted (recorded as a
##   later run, not a first exposure).
## COPY ALL RESULTS copies one bundle: every board's runs (summary + full
## records), the anonymous session id (random, made here) and the
## familiarity answer. Nothing leaves the device otherwise: no name, no
## contact, no device id, no analytics, no server; browser storage only
## (its own keys; the standalone test pages' data is never touched).
## A reload / reopen during a puzzle goes straight back to it (the clock
## never stops, see Q1TimeAttack). Player / QA builds: never opened
## (BuildFlags.dev_pages_off()); the boards are not in those builds.

const PARAM := "tapilot"
const STATE_PATH := "user://tapilot_hub.json"
const LS_KEY := "chain_escape_tapilot_hub"
const ACCENT := Color("#1A9FE6")
const WELCOME := "Clear a puzzle in two minutes.\n\nThere are 4 puzzles. Play one, or as many as you like, in any order.\n\nAfter each puzzle: a few quick questions (you can skip any of them).\n\nNo names, no accounts: your answers stay on this phone until you tap COPY ALL RESULTS and send them to us."

enum View { WELCOME, FAMILIARITY, SELECT, PUZZLE }

var state: Dictionary = {}
var view: int = View.WELCOME
var page: PilotTimeAttack
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


func _ready() -> void:
	_load_state()
	_build()
	set_process(true)
	# A puzzle left mid-way (a reload, the page closed): straight back to it.
	var cur := str(state.get("current", ""))
	if cur != "" and _in_progress(PilotTimeAttack.read_state(cur)):
		open_puzzle(cur)
	elif str(state.get("familiarity", "")) != "":
		_show(View.SELECT)
	else:
		_show(View.WELCOME)


# --- State (its own key; anonymous) --------------------------------------------------------

func _load_state() -> void:
	var texts := [FileAccess.get_file_as_string(STATE_PATH) if FileAccess.file_exists(STATE_PATH) else ""]
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(LS_KEY))
	for t in texts:
		var parsed = JSON.parse_string(t) if t != "" else null
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("session") and (state.is_empty() or int(parsed.get("seq", 0)) > int(state.get("seq", 0))):
			state = parsed
	if state.is_empty():
		# Anonymous: random, made on this device, linked to nothing else.
		state = {"session": Crypto.new().generate_random_bytes(8).hex_encode(), "familiarity": "", "current": "",
			"started": Time.get_datetime_string_from_system(true).left(10)}
		_save_state()


func _save_state() -> void:
	state["seq"] = int(state.get("seq", 0)) + 1
	var text := JSON.stringify(state)
	var f := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	if OS.has_feature("web"):
		WebBridge.ls_set(LS_KEY, text)


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
	page = PilotTimeAttack.new(board, str(state.get("familiarity", "")), str(state["session"]))
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
	for b in PilotTimeAttack.ORDER:
		var st := PilotTimeAttack.read_state(b)
		var raw: Array = st.get("results", [])
		for r in raw:
			runs.append(PilotTimeAttack.summarize(b, r))
		boards[b] = {"puzzle": PilotTimeAttack.ORDER.find(b) + 1, "fingerprint": PilotTimeAttack.BOARDS[b]["fp"], "raw": raw,
			"in_progress": {"phase": st.get("phase", "timed"), "timed": st.get("timed", {}), "untimed": st.get("cont", {})} if _in_progress(st) else {}}
	return {"format": "ce-tapilot", "v": 1, "session": state["session"], "familiarity": state.get("familiarity", ""), "started": state.get("started", ""),
		"rules": CountdownTimeAttack.TA120_RULES, "runs": runs, "boards": boards}


func results_json() -> String:
	return JSON.stringify(bundle())


## One line per board for the selection screen.
func _status(board: String) -> String:
	var st := PilotTimeAttack.read_state(board)
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


# --- Screens ------------------------------------------------------------------------------

func _show(v: int) -> void:
	view = v
	_root.visible = v != View.PUZZLE
	for k in _pages:
		_pages[k].visible = k == v
	if v == View.SELECT:
		for b in _rows:
			_rows[b][1].text = _status(b)
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
	w.add_child(_label("TIME ATTACK\nPLAYTEST", 44, 900))
	w.add_child(_label(WELCOME, 26, 700))
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
	s.add_child(_label("CHOOSE A PUZZLE", 40, 900))
	s.add_child(_label("Two minutes each. Play one or more.", 24, 700))
	for b in PilotTimeAttack.ORDER:
		var btn := _button("PUZZLE %d" % (PilotTimeAttack.ORDER.find(b) + 1), "Puzzle_%d" % (PilotTimeAttack.ORDER.find(b) + 1), Palette.WHITE, Palette.TEXT)
		btn.pressed.connect(func():
			AudioManager.play_ui_tap()
			open_puzzle(b))
		var st := _label("", 22, 700)
		st.add_theme_color_override("font_color", Palette.TEXT_SOFT)
		s.add_child(btn)
		s.add_child(st)
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


## Web: read-only snapshot for automated browser tests (window.chainEscapeTaPilot).
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
		statuses[str(PilotTimeAttack.ORDER.find(b) + 1)] = _rows[b][1].text
	WebBridge.publish("chainEscapeTaPilot", {"view": View.keys()[view], "buttons": buttons, "rects": rects, "statuses": statuses,
		"familiarity": state.get("familiarity", ""), "current": state.get("current", ""), "session": state.get("session", ""), "copy_status": _copy_status.text,
		"content_bottom": snappedf(_pages[view].get_combined_minimum_size().y / vis.y, 0.0001) if view != View.PUZZLE else -1.0})
