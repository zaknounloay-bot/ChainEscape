class_name Ta90TimeAttack
extends PilotTimeAttack
## DEVELOPMENT ONLY: one board of the 90-second Time Attack prototype with
## dynamic music (?ta90=1, Ta90Prototype; docs/ta90_prototype.md). The pilot
## page (PilotTimeAttack -> ExpertTimeAttack -> CountdownTimeAttack)
## unchanged, except:
##   - a 90-SECOND clock (GREEN 1:30-1:01, ORANGE 1:00-0:31, RED 0:30-0:00:
##     the same stage thresholds, pill, cues and reduced-motion rules);
##   - the same tools: SHOW A MOVE x0, UNDO x3 per attempt, unlimited RESTART
##     (never a new clock), HAMMER x0, TIME UP, CONTINUE WITHOUT TIMER -
##     recorded as rules "ta90-v1";
##   - its own state file and localStorage key per board ("ta90_*"): the
##     120-second pilot's and every standalone page's data are never touched;
##   - StageMusic: the countdown stage picks the mix (green / orange / red),
##     the untimed continuation plays the calm mix, a solve / TIME UP / the
##     questions / leaving fade it out. The music only follows the clock.
##   - a MUSIC ON / OFF toggle beside the countdown (never over the board).

const LIMIT_90_MS := 90000
const TA90_RULES := {"version": "ta90-v1", "limit_ms": 90000, "undo": 3, "show_a_move": 0, "hammer": 0, "restart": "unlimited"}
## The prototype's boards. N1-N3: the Phase 14 HUMAN-REVIEW CANDIDATES
## (tools/ta90_design.gd, docs/ta90_design.md; neutral names, shown as
## PUZZLE 1-3). TA: the validated 120-second board, used ONLY as an internal
## technical reference for the clock and the music (never listed as a new
## puzzle).
const BOARDS90 := {
	"N1": {"data": "res://data/dev/ta90_n1.json", "fp": "b5bb75f5937f03404ba786ff93d3e914d167ad2d5e28f88f5ed46e4a40377bff"},
	"N2": {"data": "res://data/dev/ta90_n2.json", "fp": "f4be705fcc692f27f13e0cc8d7eca216a4ba68d117b84dce4980bfa5e76d695f"},
	"N3": {"data": "res://data/dev/ta90_n3.json", "fp": "76d704deb06f8a6686040e5f5cfa6edeecdfc3f2a1af8f0c98be9a4922f2272c"},
	"TA": {"data": "res://data/dev/extreme16_a.json", "fp": "a28e22f0a1a216ba4ac701ff549e7d212ce1fe83ae2d8e3678065da555b730cf", "reference": true},
}
const P90_TIMED_Q := [
	["first_difficulty", "How difficult was this puzzle?", "first-exposure difficulty", DIFFICULTY],
	["enjoy", "How much did you enjoy\nthe timed play?\n(1 = not at all, 5 = a lot)", "enjoyment (timed)", ["1", "2", "3", "4", "5"]],
	["excite", "How exciting was\nthe countdown?\n(1 = not at all, 5 = very)", "excitement", ["1", "2", "3", "4", "5"]],
	["frustrate", "How frustrating was it?\n(1 = not at all, 5 = very)", "frustration", ["1", "2", "3", "4", "5"]],
	["music", "Did the music make\nthe experience better?", "music improved it", ["YES", "NO", "NOT SURE", "MUSIC WAS OFF"]],
	["timer_better", "Did the timer make\nthe experience better?", "timer improved it", ["YES", "NO", "NOT SURE"]],
	["length", "90 seconds was...", "90 s", ["TOO SHORT", "APPROPRIATE", "TOO LONG"]],
	["another", "Would you play\nanother puzzle?", "play another", ["YES", "NO", "NOT SURE"]],
]

## The MUSIC toggle changed (the hub remembers it).
signal music_changed(on: bool)

var music: StageMusic
var music_on := true
var _music_btn: PillButton
var _music_pub := 0


func _init(p_board: String = "TA", p_familiarity: String = "", p_session: String = "", p_number: int = 1, p_music_on: bool = true) -> void:
	super("TA", p_familiarity, p_session)
	board_key = p_board if BOARDS90.has(p_board) else "TA"
	number = p_number
	music_on = p_music_on
	key = "ta90_" + board_key.to_lower()
	test = key
	preset = {"id": board_key, "letter": str(number), "data": BOARDS90[board_key]["data"], "fp": BOARDS90[board_key]["fp"],
		"state": state_path90(board_key), "ls": ls_key90(board_key)}
	for k in ["data", "state", "ls"]:
		_cfg[k] = preset[k]
	_cfg["title"] = "PUZZLE %d" % number
	_cfg["questions"] = P90_TIMED_Q
	_questions = P90_TIMED_Q.duplicate(true)


static func state_path90(board: String) -> String:
	return "user://ta90_%s_state.json" % board.to_lower()


static func ls_key90(board: String) -> String:
	return "chain_escape_ta90_%s_state" % board.to_lower()


static func read_state90(board: String) -> Dictionary:
	var texts := [FileAccess.get_file_as_string(state_path90(board)) if FileAccess.file_exists(state_path90(board)) else ""]
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(ls_key90(board)))
	var best := {}
	for t in texts:
		var parsed = JSON.parse_string(t) if t != "" else null
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("order") and (best.is_empty() or int(parsed.get("seq", 0)) > int(best.get("seq", 0))):
			best = parsed
	return best


func limit() -> int:
	return LIMIT_90_MS


func timed_q() -> Array:
	return P90_TIMED_Q


func _tools_text() -> String:
	return "UNDO x3 per attempt, unlimited RESTART. No SHOW A MOVE and no HAMMER."


func intro_text() -> String:
	return "One puzzle. 90 seconds.\n\n" + _tools_text()


func _ready() -> void:
	super._ready()
	_count.text = "1:30"
	if _new_run:
		_new_run.text = "NEW 90-SECOND RUN"
	_brief_go.text = "START - 1:30"
	music = StageMusic.new()
	music.name = "StageMusic"
	music.enabled = music_on
	add_child(music)
	_music_btn = PillButton.new("", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 20)
	_music_btn.name = "MusicToggle"
	_music_btn.custom_minimum_size = Vector2(150, 64)
	_music_btn.size = Vector2(150, 64)
	_music_btn.pressed.connect(func(): set_music(not music_on))
	_hud.add_child(_music_btn)
	_refresh_music_btn()


## The page's MUSIC toggle.
func set_music(on: bool) -> void:
	music_on = on
	music.set_enabled(on)
	_refresh_music_btn()
	music_changed.emit(on)
	_publish_ta()


func _refresh_music_btn() -> void:
	if _music_btn:
		_music_btn.text = "MUSIC ON" if music_on else "MUSIC OFF"
		_music_btn.modulate.a = 1.0 if music_on else 0.7


func _show(s: int) -> void:
	super._show(s)
	if _music_btn:
		_music_btn.visible = s == Screen.PLAYING
	if s != Screen.PLAYING and music:
		music.stop_music()  # questions, cards: a clean, quiet screen
	if s == Screen.BRIEF:
		_brief_go.text = "START - 1:30"
		_brief_text.text = _brief_text.text.replace("You have 2 minutes.", "You have 90 seconds.")


func _show_card() -> void:
	super._show_card()
	_card_text.text = _card_text.text.replace("The 2 minutes are over.", "The 90 seconds are over.")
	if music:
		music.stop_music()


func _show_offer() -> void:
	super._show_offer()
	if music:
		music.stop_music()


func _start_run() -> void:
	super._start_run()
	_current["assist"] = TA90_RULES.duplicate()


func begin_untimed() -> void:
	super.begin_untimed()
	_current["assist"] = TA90_RULES.duplicate()
	_save_untimed()
	if music:
		music.set_stage("calm")


## The countdown stage picks the mix (the music never sets the stage).
func _set_stage(st: String, l10: bool, force: bool = false) -> void:
	super._set_stage(st, l10, force)
	if music == null:
		return
	if phase() == "untimed" and screen == Screen.PLAYING:
		music.set_stage("calm")
	elif st in ["green", "orange", "red"] and run_active() and screen == Screen.PLAYING:
		music.set_stage(st)


func _finish_attempt(solved: bool) -> void:
	if music:
		music.stop_music()
	super._finish_attempt(solved)


func page_hidden(h: bool) -> void:
	super.page_hidden(h)
	if music:
		music.set_hidden(h)


## The toggle sits beside the countdown pill, on its row - never over the board.
func _place_pill() -> void:
	super._place_pill()
	if _music_btn == null or not _music_btn.visible:
		return
	var r := pill_rect()
	var vis := get_viewport().get_visible_rect().size
	var x := r.end.x + 14.0
	if x + _music_btn.size.x > vis.x - 8.0:
		x = vis.x - 8.0 - _music_btn.size.x
	# Centred on the pill's row, but never lower than the pill: never over the board.
	var y := minf(r.position.y + (r.size.y - _music_btn.size.y) / 2.0, r.end.y - _music_btn.size.y)
	_music_btn.position = Vector2(roundf(x), roundf(y))


## The music state is published on its own (tests read it on every screen).
func _process(delta: float) -> void:
	super._process(delta)
	if OS.has_feature("web") and Time.get_ticks_msec() - _music_pub >= 300:
		_publish_music()


func _publish_ta() -> void:
	super._publish_ta()
	_publish_music()


func _publish_music() -> void:
	_music_pub = Time.get_ticks_msec()
	if not OS.has_feature("web") or not is_inside_tree() or music == null:
		return
	var vis := get_viewport().get_visible_rect().size
	var snap := music.snapshot()
	if _music_btn and _music_btn.is_visible_in_tree():
		var r := _music_btn.get_global_rect()
		snap["button"] = [snappedf(r.get_center().x / vis.x, 0.0001), snappedf(r.get_center().y / vis.y, 0.0001)]
		snap["button_rect"] = [snappedf(r.position.x / vis.x, 0.0001), snappedf(r.position.y / vis.y, 0.0001), snappedf(r.size.x / vis.x, 0.0001), snappedf(r.size.y / vis.y, 0.0001)]
	snap["limit_ms"] = limit()
	WebBridge.publish("chainEscapeStageMusic", snap)
