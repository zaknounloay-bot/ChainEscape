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
}
const RATINGS := ["EASY", "MEDIUM", "HARD", "VERY HARD"]
const ACCENT := Color("#1A9FE6")

enum Screen { INTRO, PLAYING, RATE, THINK, RESULTS }

var test := PARAM
var _cfg: Dictionary = TESTS[PARAM]
var boards: Dictionary = {}  # id -> record (variant, puzzle, metrics)
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


## Checked at launch like FriendBench (before a shared-challenge link).
static func requested() -> bool:
	return requested_test() != ""


## "vhtest2", "vhtest" or "" (not asked for).
static func requested_test() -> String:
	for key in ["vhtest2", "vhtest"]:
		if "--" + key in OS.get_cmdline_user_args():
			return key
	if not OS.has_feature("web"):
		return ""
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return ""
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	for key in ["vhtest2", "vhtest"]:
		if where.contains(key + "=1") or where.contains(key + "=true"):
			return key
	return ""


func _init(p_test: String = PARAM) -> void:
	layer = 30  # over everything (SocialPlay is layer 5)
	test = p_test if TESTS.has(p_test) else PARAM
	_cfg = TESTS[test]


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(_cfg["data"]))
	if typeof(data) == TYPE_DICTIONARY:
		_assist = data.get("assist", _assist)
		for b in data.get("boards", []):
			boards[str(b["id"])] = b
	_load_state()
	play = SocialPlay.new()
	play.max_hints = int(_assist.get("show_a_move", 1))
	play.max_hammers = int(_assist.get("hammer", 1))
	play.solved.connect(_on_solved)
	play.exited.connect(_on_gave_up)
	add_child(play)
	_build()
	_show(Screen.INTRO)
	set_process(true)


func _process(_delta: float) -> void:
	if screen == Screen.PLAYING and _current.get("first_move_ms", -1) < 0 and (play.total_moves > 0 or play.total_hammers > 0):
		_current["first_move_ms"] = Time.get_ticks_msec() - _t0
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
		_show(Screen.RESULTS)
		return
	var rec: Dictionary = boards[state["order"][i]]
	var def := PuzzleDefinition.from_dict(rec["puzzle"])
	var c := SharedChallenge.friend_challenge(def, FriendGenerator.VERY_HARD)
	_current = {"id": rec["id"], "variant": rec["variant"], "fingerprint": def.fingerprint(), "order": i + 1, "first_move_ms": -1}
	_show(Screen.PLAYING)
	play.back_label = ""
	play.start(c, SocialPlay.Mode.CREATOR_PREVIEW, Chapters.theme_for_chapter(1))
	play._title.text = "PUZZLE %d / %d" % [i + 1, total()]
	_t0 = Time.get_ticks_msec()


func _on_solved() -> void:
	if screen != Screen.PLAYING:
		return
	_finish_attempt(true)
	# Let the board celebrate for a moment, then ask.
	await get_tree().create_timer(1.0).timeout
	_show(Screen.RATE)


## EXIT -> LEAVE in the game: recorded as not solved (still rated).
func _on_gave_up() -> void:
	if screen != Screen.PLAYING:
		return
	_finish_attempt(false)
	_show(Screen.RATE)


func _finish_attempt(solved: bool) -> void:
	_current["completed"] = solved
	_current["time_ms"] = Time.get_ticks_msec() - _t0
	_current["moves"] = play.total_moves
	_current["restarts"] = maxi(0, play.plays - 1)
	_current["undos"] = play.total_undos
	_current["show_a_move"] = play.total_hints
	_current["hammer"] = play.total_hammers


func rate(i: int) -> void:
	_current["rating"] = RATINGS[i]
	_show(Screen.THINK)


func think(answer: String) -> void:
	_current[_cfg["q2_key"]] = answer
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


## A random order for this device: variants interleaved, never told.
func _new_order() -> void:
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
	return JSON.stringify({"format": "ce-vh-human-results", "v": 1, "test": test, "q2_key": _cfg["q2_key"], "started": state.get("started", ""),
		"device": OS.get_name(), "assist": _assist, "results": state["results"], "summary": summary()})


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
		s["rating"].append(RATINGS.find(r["rating"]) + 1)
		s["very_hard"] += 1 if r["rating"] == "VERY HARD" else 0
		s["q2_yes"] += 1 if r.get(_cfg["q2_key"], "") == "YES" else 0
		s["show_a_move"] += r["show_a_move"]
		s["hammer"] += r["hammer"]
		s["restarts"] += r["restarts"]
		if r.get("first_move_ms", -1) >= 0:
			s["first_move_s"].append(snappedf(r["first_move_ms"] / 1000.0, 0.1))
	for v in out:
		var s: Dictionary = out[v]
		var t: Array = s["time_s"]
		t.sort()
		s["median_time_s"] = t[t.size() / 2] if not t.is_empty() else -1
		var fm: Array = s["first_move_s"]
		fm.sort()
		s["median_first_move_s"] = fm[fm.size() / 2] if not fm.is_empty() else -1
		s["avg_rating_1to4"] = snappedf(s["rating"].reduce(func(a, b): return a + b, 0) / float(maxi(s["n"], 1)), 0.01)
	return out


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
		lines.append("Group %s: %d played, %d solved, median %ss, rated %.1f / 4, VERY HARD x%d, %s x%d" % [
			v, s["n"], s["solved"], str(s["median_time_s"]), s["avg_rating_1to4"], s["very_hard"], _cfg["q2_label"], s["q2_yes"]])
	lines.append("")
	lines.append("Tap COPY RESULTS and paste it into the chat.")
	return "\n".join(lines)


# --- Screens ----------------------------------------------------------------------------

func _show(s: int) -> void:
	screen = s
	for k in _pages:
		_pages[k].visible = k == s
	_root.visible = s != Screen.PLAYING
	match s:
		Screen.INTRO:
			var i: int = state["index"]
			_intro_text.text = ("%d puzzles, one after another, in a random order.\n\n" % total()
				+ "Play each one as you normally would. You have UNDO x%d, SHOW A MOVE x%d and HAMMER x%d per attempt; RESTART gives them back.\n\n" % [int(_assist["undo"]), int(_assist["show_a_move"]), int(_assist["hammer"])]
				+ "If you want to give up, tap EXIT and LEAVE.\n\nAfter each puzzle: one question about how difficult it was.")
			_start.text = "START" if i == 0 else ("CONTINUE  %d / %d" % [i + 1, total()] if i < total() else "SEE RESULTS")
		Screen.RATE:
			_rate_title.text = "PUZZLE %d / %d %s\n\nHow difficult was this puzzle?" % [_current.get("order", 0), total(), "SOLVED" if _current.get("completed", false) else "NOT SOLVED"]
		Screen.RESULTS:
			_results_text.text = _summary_text()
			_copy_status.text = ""
			SocialWeb.set_share(results_json(), "", "")
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
		if int(state["index"]) >= total():
			_show(Screen.RESULTS)
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
	for i in RATINGS.size():
		var b := _button(RATINGS[i], "Rate_%s" % RATINGS[i].replace(" ", "_"), Palette.WHITE, Palette.TEXT)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			rate(i))
		rate_box.add_child(b)
	_pages[Screen.RATE] = rate_box
	# THINK (optional)
	var think_box := _column()
	think_box.add_child(_label(_cfg["q2"], 34, 900))
	for a in ["YES", "NO"]:
		var b := _button(a, "Think_%s" % a, Palette.WHITE, Palette.TEXT)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			think(a))
		think_box.add_child(b)
	var skip := _button("SKIP", "Think_SKIP", Palette.BACKGROUND, Palette.TEXT_SOFT)
	skip.pressed.connect(func(): think(""))
	think_box.add_child(skip)
	_pages[Screen.THINK] = think_box
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
	if _root.visible:
		for b in _pages[screen].find_children("*", "BaseButton", true, false):
			if b.is_visible_in_tree():
				var c: Vector2 = b.get_global_rect().get_center()
				buttons[String(b.name)] = [snappedf(c.x / vis.x, 0.0001), snappedf(c.y / vis.y, 0.0001)]
	WebBridge.publish("chainEscapeVhTest", {"screen": Screen.keys()[screen], "index": state.get("index", 0), "total": total(),
		"results": state.get("results", []).size(), "buttons": buttons})
