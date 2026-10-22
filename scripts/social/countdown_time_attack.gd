class_name CountdownTimeAttack
extends BlindTimeAttack
## DEVELOPMENT ONLY (?stime=1): a NEW unseen board (data/dev/extreme15.json,
## "S1", checked by its fingerprint) played blind against a 2-MINUTE clock,
## with a more prominent, staged countdown (docs/extreme15.md). Everything
## else is the phase 9 test (BlindTimeAttack / Q1TimeAttack): the start
## convention, the clock that RESTART / UNDO / the background / a reload
## never stop or give back, UNDO x3 per attempt, HAMMER x0, the frozen timed
## result, the optional CONTINUE WITHOUT TIMER with its own record and log,
## isolated state.
##
## THE 120 s TIME ATTACK RULES (phase 12B, TA120_RULES; this page and the
## ?tta / ?ttb / ?ttc pages that extend it): NO SHOW A MOVE - not in the timed
## run, not in the untimed continuation. The button is removed from the play
## screen (hidden, disconnected, no input), the budget is 0, and a request
## from anywhere else is refused without asking the solver. UNDO x3 per
## attempt, unlimited RESTART, HAMMER x0. Every new record carries "assist"
## (these rules and their version). The phase 10 / 11 human sessions were
## played under TA120_RULES_V1 (ONE SHOW A MOVE per timed run): records
## without "assist" are exported with those rules, never rewritten.
## Q1TimeAttack (?q1time) and BlindTimeAttack (?rtime) keep their own
## historical 180 s rules (ONE SHOW A MOVE per run): nothing here is shared
## with them.
##
## The countdown: a pill of FIXED size between the top bar and the board
## (never over it; the board and the buttons never move), white digits on a
## coloured fill, and a second, non-colour cue - its icon and the digits'
## weight - for each stage:
##   GREEN   2:00-1:01  clock icon, weight 700, still
##   ORANGE  1:00-0:31  half-filled clock, weight 800; the fill eases from
##           green to orange once (0.4 s)
##   RED     0:30-0:00  warning triangle, weight 900; a gentle pulse of the
##           fill (1.25 s); in the last 10 s the triangle is filled, the pulse
##           a little deeper and quicker (0.9 s) with a 3 % breathing scale.
##           Never a flash: the fill only darkens (white digits keep at least
##           their resting contrast), well under 3 changes a second.
## Reduced motion (the browser's prefers-reduced-motion): no easing, no pulse,
## no scale - the stage, the icon and the weight still change.
## The stages reached are recorded (when, and whether the page was showing
## then) - that a stage appeared is NOT evidence that it was noticed.

const SKEY := "stime"
const S1_ID := "S1"
const S1_FINGERPRINT := "7714b7488829cefa28ea49fa427c4b2b51fabac8c2a1bae77fc9520a399efa2b"
const LIMIT_120_MS := 120000
const ORANGE_FROM_S := 60  # displayed seconds: 1:00 is the first orange second
const RED_FROM_S := 30
const FINAL_FROM_S := 10
const STAGE_FILL := {"green": Color("#1E7B34"), "orange": Color("#C2410C"), "red": Color("#B91C1C")}
const PULSE_DARK := Color("#7F1111")  # the deepest point of the red pulse
const STAGE_WEIGHT := {"green": 700, "orange": 800, "red": 900}
const PILL_SIZE := Vector2(360, 108)
const TA120_RULES := {"version": "ta120-v2", "limit_ms": 120000, "undo": 3, "show_a_move": 0, "hammer": 0, "restart": "unlimited"}
const TA120_RULES_V1 := {"version": "ta120-v1", "limit_ms": 120000, "undo": 3, "show_a_move": 1, "hammer": 0, "restart": "unlimited"}

const S_TIMED_Q := [
	["enjoy", "How much did you enjoy\nthe timed run?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["excite", "How exciting was the\n2-minute clock?\n(1 = not at all, 5 = very)", "excitement", ["1", "2", "3", "4", "5"]],
	["frustrate", "How frustrating was it?\n(1 = not at all, 5 = very)", "frustration", ["1", "2", "3", "4", "5"]],
	["timer_better", "Did the timer make\nthe game better?", "timer improved it", ["YES", "NO", "NOT SURE"]],
	["length", "120 seconds was...", "120 s", ["TOO SHORT", "APPROPRIATE", "TOO LONG"]],
	["noticed_colours", "Did you notice the timer\nchanging from green to orange\nand then red?", "noticed the colours", ["YES", "NO", "NOT SURE"]],
	["colour_urgency", "Did the colour changes\ncreate a sense of urgency?", "colours created urgency", ["YES", "NO", "NOT SURE"]],
	["again", "Would you play this\ntimed mode again?", "play again", ["YES", "NO", "NOT SURE"]],
]
const S_PUZZLE_Q := [
	["difficulty", "Without the clock, how difficult\nis this puzzle itself?", "difficulty", ["EASY", "MEDIUM", "HARD", "VERY HARD", "EXTREME"]],
	["enjoy", "How much did you enjoy\nthe puzzle?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["achieve", "How strong was your sense\nof achievement?\n(1 = none, 5 = very strong)", "achievement", ["1", "2", "3", "4", "5"]],
	["planned", "Did it require real planning\n(thinking several moves ahead)?", "needed planning", ["YES", "A LITTLE", "NO"]],
	["combo", "Did the combination of mechanics\nmake the puzzle more interesting?", "combination more interesting", ["YES", "A LITTLE", "NO"]],
	["feedback", "Optional: what made this puzzle\ndifficult or interesting?", "feedback", ["TEXT"]],
]
const S_CFG := {"data": "res://data/dev/extreme15.json", "state": "user://stime_state.json", "title": "PUZZLE TEST\n(DEVELOPMENT)",
	"q2": "", "q2_key": "enjoy", "q2_label": "enjoyment", "pilot": true, "questions": S_TIMED_Q,
	"log_blocked": true, "hide_difficulty": true, "mech_events": true, "hint_budget": 0, "persist_live": true,
	"ls": "chain_escape_stime_state"}

## Set by tests (headless has no browser preference).
var reduced_motion := false
var _pill: Panel
var _fill: StyleBoxFlat
var _icon: StageIcon
var _stage := ""
var _final := false
var _fonts := {}
var _ease: Tween
var _pulse_t0 := 0
var _fit := 1.0  # < 1 only where the gap above the board is too small for the pill


static func requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + SKEY in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(SKEY + "=1") or where.contains(SKEY + "=true")


func _init() -> void:
	super()
	test = SKEY
	_cfg = S_CFG
	_questions = S_TIMED_Q.duplicate(true)


func bid() -> String:
	return S1_ID


func bfp() -> String:
	return S1_FINGERPRINT


func limit() -> int:
	return LIMIT_120_MS


func timed_q() -> Array:
	return S_TIMED_Q


func puzzle_q() -> Array:
	return S_PUZZLE_Q


func intro_text() -> String:
	return ("One puzzle you have not seen before. Two minutes.\n\nThe clock starts when the board appears and never stops: thinking, UNDO and RESTART all use time. RESTART starts the board again, not the clock. Leaving or reloading the page does not stop it either.\n\n"
		+ _tools_text() + "\n\nIf the time runs out, you can choose to keep playing without the clock.\n\nAfterwards: a few quick questions.")


func _ready() -> void:
	reduced_motion = reduced_motion or _browser_reduced_motion()
	super._ready()
	for st in STAGE_WEIGHT:
		_fonts[st] = Palette.font(STAGE_WEIGHT[st])
	# The pill: fixed size, its own layer of the HUD; the digits live in it.
	_pill = Panel.new()
	_pill.name = "CountdownPill"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.size = PILL_SIZE
	_pill.custom_minimum_size = PILL_SIZE
	_pill.pivot_offset = PILL_SIZE / 2.0
	_fill = StyleBoxFlat.new()
	_fill.bg_color = STAGE_FILL["green"]
	_fill.set_corner_radius_all(int(PILL_SIZE.y / 2.0))
	_fill.shadow_color = Color(0, 0, 0, 0.18)
	_fill.shadow_size = 6
	_fill.shadow_offset = Vector2(0, 3)
	_pill.add_theme_stylebox_override("panel", _fill)
	_hud.add_child(_pill)
	_icon = StageIcon.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2(34, 22)
	_icon.size = Vector2(64, 64)
	_pill.add_child(_icon)
	_count.get_parent().remove_child(_count)
	_pill.add_child(_count)
	_count.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_count.position = Vector2(96, 0)
	_count.size = Vector2(PILL_SIZE.x - 96 - 34, PILL_SIZE.y)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 72)
	_count.add_theme_color_override("font_color", Palette.WHITE)
	_count.text = "2:00"
	if _new_run:
		_new_run.text = "NEW 2-MINUTE RUN"
	_set_stage("green", false, true)
	_remove_show_a_move()
	_show(screen)


func _tools_text() -> String:
	return "UNDO x%d per attempt, unlimited RESTART. No SHOW A MOVE and no HAMMER in this test." % int(TA120_RULES["undo"])


# --- No SHOW A MOVE (TA120_RULES) -----------------------------------------------------------

## The button leaves the play screen for good: hidden, every connection cut,
## no mouse / touch / focus / keyboard, not processed; and a budget of 0.
func _remove_show_a_move() -> void:
	_assist = {"undo": int(TA120_RULES["undo"]), "show_a_move": 0, "hammer": 0}
	play.max_hints = 0
	var h: Button = play._hint
	for c in h.pressed.get_connections():
		h.pressed.disconnect(c["callable"])
	h.visible = false
	h.disabled = true
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.focus_mode = Control.FOCUS_NONE
	h.shortcut = null
	h.process_mode = Node.PROCESS_MODE_DISABLED


## A SHOW A MOVE request from anywhere (none is reachable from the screen):
## refused, the solver is never asked, nothing is shown or recorded.
func budget_hint() -> void:
	play.max_hints = 0


## The rules of a record: those it carries, else (older records, played
## before phase 12B) the phase 10 / 11 rules.
static func record_rules(rec: Dictionary) -> Dictionary:
	return rec["assist"] if typeof(rec.get("assist")) == TYPE_DICTIONARY else TA120_RULES_V1


func _browser_reduced_motion() -> bool:
	if not OS.has_feature("web"):
		return false
	var v = JavaScriptBridge.eval("!!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)", true)
	# The bridge returns a JS boolean as an int (1 / 0).
	return (typeof(v) == TYPE_BOOL and v) or (typeof(v) in [TYPE_INT, TYPE_FLOAT] and v != 0)


## The stage for a number of DISPLAYED seconds (what the digits show).
static func stage_for(secs: int) -> String:
	if secs > ORANGE_FROM_S:
		return "green"
	if secs > RED_FROM_S:
		return "orange"
	return "red"


func _show(s: int) -> void:
	super._show(s)
	if _pill:
		_pill.visible = s == Screen.PLAYING


func _show_card() -> void:
	super._show_card()
	_card_text.text = _card_text.text.replace("The 3 minutes are over.", "The 2 minutes are over.")


# --- The countdown, drawn every frame (no node is created or rebuilt) ----------------------

func _draw_count() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_pub >= 250:
		_last_pub = now
		_publish_ta()
	if phase() == "untimed":
		_count.text = "NO TIMER"
		_count.add_theme_font_size_override("font_size", 44)
		_set_stage("none", false)
	else:
		_count.add_theme_font_size_override("font_size", 72)
		var left := remaining_ms()
		var sec := int(ceil(left / 1000.0))
		_count.text = "%d:%02d" % [sec / 60, sec % 60]
		_set_stage(stage_for(sec), sec <= FINAL_FROM_S and sec > 0 or (sec == 0 and _final))
		_pulse()
	_place_pill()


func _place_pill() -> void:
	if not (play and play.board and play._progress.is_visible_in_tree()):
		return
	# Between the top bar and the board, never over the board.
	# Never over the board: where the gap is smaller than the pill (not on a
	# phone in portrait), the whole pill is scaled down to fit (a transform:
	# nothing else moves).
	var top := play._progress.get_global_rect().end.y
	var board_top := play.board.get_board_rect().position.y
	var gap := board_top - top - 8.0
	_fit = clampf(gap / PILL_SIZE.y, 0.3, 1.0)
	var h := PILL_SIZE.y * _fit
	var y := top + maxf(0.0, (gap - h) / 2.0) + 4.0
	# The pill is scaled about its centre: place that centre.
	var cx := get_viewport().get_visible_rect().size.x / 2.0
	_pill.position = Vector2(roundf(cx - PILL_SIZE.x / 2.0), roundf(y + h / 2.0 - PILL_SIZE.y / 2.0))
	_pill.size = PILL_SIZE
	if _stage != "red" or reduced_motion:
		_pill.scale = Vector2.ONE * _fit


func _set_stage(st: String, l10: bool, force: bool = false) -> void:
	if st == _stage and l10 == _final and not force:
		return
	var was := _stage
	_stage = st
	_final = l10
	if st == "none":
		_fill.bg_color = Palette.TEXT_SOFT
		_icon.stage = "none"
		_icon.queue_redraw()
		_count.add_theme_font_override("font", _fonts["green"])
		_pill.scale = Vector2.ONE * _fit
		return
	_icon.stage = st
	_icon.last10 = l10
	_icon.queue_redraw()
	_count.add_theme_font_override("font", _fonts[st])
	if _ease:
		_ease.kill()
	if was != st and was in ["green", "orange"] and not reduced_motion:
		# One brief, restrained ease to the new fill (no flash).
		_ease = create_tween()
		_ease.tween_property(_fill, "bg_color", STAGE_FILL[st], 0.4)
	else:
		_fill.bg_color = STAGE_FILL[st]
	if st == "red" and was != "red":
		_pulse_t0 = Time.get_ticks_msec()
	_note_stage(st, l10, was)


## The red pulse: the fill darkens and comes back (never lighter than the
## resting red), slower and shallower before the last 10 s.
func _pulse() -> void:
	if _stage != "red" or reduced_motion or (_ease and _ease.is_running()):
		_pill.scale = Vector2.ONE * _fit
		return
	var period := 0.9 if _final else 1.25
	var depth := 0.55 if _final else 0.35
	var t := (Time.get_ticks_msec() - _pulse_t0) / 1000.0
	var k := 0.5 - 0.5 * cos(TAU * t / period)  # 0 at rest, 1 at the deepest
	_fill.bg_color = STAGE_FILL["red"].lerp(PULSE_DARK, depth * k)
	_pill.scale = Vector2.ONE * _fit * (1.0 + (0.03 * k if _final else 0.0))


## Light instrumentation: which stages the run reached, when (elapsed ms),
## and whether the page was showing at that moment. Logged once per stage.
func _note_stage(st: String, l10: bool, was: String) -> void:
	if not run_active() or not _current.has("log"):
		return
	var run: Dictionary = state["run"]
	var stages: Dictionary = run.get("stages", {})
	var key := "final10" if l10 else st
	if stages.has(key):
		return
	stages[key] = {"at_ms": elapsed_ms(), "page_hidden": _hidden, "from": was}
	run["stages"] = stages
	_current["log"].append([Time.get_ticks_msec() - _t0, "z", -1, {"stage": key, "elapsed_ms": elapsed_ms(), "page_hidden": _hidden}])
	_save_live()


func _start_run() -> void:
	super._start_run()
	_current["assist"] = TA120_RULES.duplicate()
	_stage = ""
	_set_stage("green", false, true)


func _finish_attempt(solved: bool) -> void:
	var timed := phase() != "untimed"
	super._finish_attempt(solved)
	if timed and state.has("timed") and not state["timed"].has("stages"):
		var stages: Dictionary = state.get("run", {}).get("stages", {})
		var reached := ["green"]
		for k in ["orange", "red", "final10"]:
			if stages.has(k):
				reached.append(k)
		state["timed"]["stages"] = stages
		state["timed"]["stages_reached"] = reached
		state["timed"]["reduced_motion"] = reduced_motion
		_save_state()


## The untimed continuation: the same rules (no SHOW A MOVE), in its own record.
func begin_untimed() -> void:
	super.begin_untimed()
	play.max_hints = 0
	if not _current.has("assist"):
		_current["assist"] = TA120_RULES.duplicate()
		_save_untimed()
	play._refresh_buttons()


## The export names the rules of every run: the current ones, and for each
## stored run the rules it was played under (older runs: TA120_RULES_V1).
func results_json() -> String:
	var runs := []
	for r in state.get("results", []):
		var x: Dictionary = r.duplicate()
		x["assist"] = record_rules(r.get("timed", {}))
		runs.append(x)
	return JSON.stringify({"format": "ce-time-attack-blind", "v": 1, "test": test, "board": bid(), "fingerprint": bfp(), "limit_ms": limit(),
		"device": OS.get_name(), "assist": TA120_RULES, "rules_version": TA120_RULES["version"], "runs": runs,
		"in_progress": {"phase": phase(), "timed": state.get("timed", {}), "untimed": state.get("cont", {})} if state.has("timed") or run_active() else {}})


## The test snapshot also carries the countdown's look (tests read it and
## compare it with the screen's pixels).
func _publish_ta() -> void:
	super._publish_ta()
	if not OS.has_feature("web") or not is_inside_tree() or _pill == null:
		return
	var vis := get_viewport().get_visible_rect().size
	var r := pill_rect()
	WebBridge.publish("chainEscapeCountdown", {"stage": _stage, "final": _final, "reduced_motion": reduced_motion,
		"visible": _pill.is_visible_in_tree(), "fill": _fill.bg_color.to_html(false), "rest_fill": STAGE_FILL.get(_stage, Palette.TEXT_SOFT).to_html(false),
		"weight": STAGE_WEIGHT.get(_stage, 700), "icon": _icon.stage + ("_final" if _final else ""), "scale": _pill.scale.x, "text": _count.text,
		"rect": [snappedf(r.position.x / vis.x, 0.0001), snappedf(r.position.y / vis.y, 0.0001), snappedf(r.size.x / vis.x, 0.0001), snappedf(r.size.y / vis.y, 0.0001)],
		"board_top": snappedf(play.board.get_board_rect().position.y / vis.y, 0.0001) if play and play.board else -1.0,
		"stages": state.get("run", {}).get("stages", {})})


## Where the pill is drawn (scaled about its centre).
func pill_rect() -> Rect2:
	return Rect2(_pill.get_global_transform().origin, PILL_SIZE * _pill.scale)


## The non-colour cue: a clock (green), a half-filled clock (orange), a
## warning triangle (red; filled in the last 10 s). Drawn only when the
## stage changes.
class StageIcon extends Control:
	var stage := "green"
	var last10 := false

	func _draw() -> void:
		var w := Color.WHITE
		var c := size / 2.0
		match stage:
			"green", "orange":
				var rad := size.x * 0.42
				if stage == "orange":
					draw_circle(c, rad, Color(1, 1, 1, 0.35))
					var pts := PackedVector2Array([c])
					for i in 17:
						var a := -PI / 2.0 + PI * i / 16.0
						pts.append(c + Vector2(cos(a), sin(a)) * rad)
					draw_colored_polygon(pts, w)
				draw_arc(c, rad, 0, TAU, 40, w, 5.0, true)
				var hand := Color(0.12, 0.12, 0.12, 0.85) if stage == "orange" else w
				draw_line(c, c + Vector2(0, -rad * 0.62), w if stage == "green" else hand, 5.0, true)
				draw_line(c, c + Vector2(rad * 0.5, 0), w if stage == "green" else hand, 5.0, true)
			"red":
				var top := Vector2(c.x, size.y * 0.06)
				var bl := Vector2(size.x * 0.04, size.y * 0.92)
				var br := Vector2(size.x * 0.96, size.y * 0.92)
				var tri := PackedVector2Array([top, br, bl])
				if last10:
					draw_colored_polygon(tri, w)
				draw_polyline(PackedVector2Array([top, br, bl, top]), w, 5.0, true)
				var mark := Color(0.5, 0.06, 0.06) if last10 else w
				draw_line(Vector2(c.x, size.y * 0.36), Vector2(c.x, size.y * 0.64), mark, 6.0, true)
				draw_circle(Vector2(c.x, size.y * 0.78), 3.6, mark)
