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
## (tools/ta90_design.gd, docs/ta90_design.md); N4-N13: the Phase 15
## collection (docs/ta90_collection.md). Key N<k> is shown as PUZZLE k;
## neutral names, no difficulty shown. N14-N23: the Phase 16 EXTREME bank
## candidates (docs/extreme90_bank.md), played only in ?extreme90=1. N24-N30: the
## Phase 17 candidates (docs/extreme90_phase17.md), played only in ?extreme90p17=1. N31-N34:
## the Phase 18 candidates (docs/extreme90_phase18.md), played only in ?extreme90p18=1. N35-N36:
## the Phase 19 candidates (docs/extreme90_phase19.md), ?extreme90p19=1 only. TA: the validated 120-second board, used ONLY as an internal
## technical reference for the clock and the music (never listed as a new
## puzzle).
const BOARDS90 := {
	"N1": {"data": "res://data/dev/ta90_n1.json", "fp": "b5bb75f5937f03404ba786ff93d3e914d167ad2d5e28f88f5ed46e4a40377bff"},
	"N2": {"data": "res://data/dev/ta90_n2.json", "fp": "f4be705fcc692f27f13e0cc8d7eca216a4ba68d117b84dce4980bfa5e76d695f"},
	"N3": {"data": "res://data/dev/ta90_n3.json", "fp": "76d704deb06f8a6686040e5f5cfa6edeecdfc3f2a1af8f0c98be9a4922f2272c"},
	"N4": {"data": "res://data/dev/ta90_n4.json", "fp": "6adc71d670366c04f57bdef2f825990f930214ff63baa0a754f8d3362002c7e9"},
	"N5": {"data": "res://data/dev/ta90_n5.json", "fp": "3f420b14215a44aa1bb6b96c85be519ff1c247312a6300c444c673f43e650c40"},
	"N6": {"data": "res://data/dev/ta90_n6.json", "fp": "d2850675394c1963e34a0986ece8010b83f81758aa4f3790ea8a93f686afecb0"},
	"N7": {"data": "res://data/dev/ta90_n7.json", "fp": "a9465918d8f02112da791892a32c7e3ff2d79d8fe173c59b34b2d674d8e9587b"},
	"N8": {"data": "res://data/dev/ta90_n8.json", "fp": "033745db265b1291d2b19f342fb679d5ec4708fcdffa29e660a72ce0d0161e01"},
	"N9": {"data": "res://data/dev/ta90_n9.json", "fp": "c631418dff67b0bf39bfb88411be0ec9abde6b41dad3cb13dcb181b91b5b75a3"},
	"N10": {"data": "res://data/dev/ta90_n10.json", "fp": "a5474adbd79311a651865a183c1094fd080bd65fe4b26bb4bc4bb1f80f8fddfe"},
	"N11": {"data": "res://data/dev/ta90_n11.json", "fp": "a92813074460913b95b9f54433ffd156ead01c04c1e5d357ad83ea380f8bf4fb"},
	"N12": {"data": "res://data/dev/ta90_n12.json", "fp": "52dffbaefdde0a4cd91cba51a37999cf238f705d06a9da42179400fe3357fbbd"},
	"N13": {"data": "res://data/dev/ta90_n13.json", "fp": "9acdd496511edcd6e847217ec37d7029d7cc82a62d1f93258d7ac08b5d86c943"},
	"N14": {"data": "res://data/dev/ta90_n14.json", "fp": "c26a76e8fcd75672540d08e26a053559cc1a13ef9bfd12a87500f710e41b8698"},
	"N15": {"data": "res://data/dev/ta90_n15.json", "fp": "4868df06805eaa4d89925a7f42a1e2cd85d5248e8d1b3dcd609feccfcc52e087"},
	"N16": {"data": "res://data/dev/ta90_n16.json", "fp": "b46e1063d26a1090121bdcc0320412019553918d001dbdf940d9b2882152531b"},
	"N17": {"data": "res://data/dev/ta90_n17.json", "fp": "f03a0bec59608c30fdedd8b80854226242d679323f63724ff7d4306ccf506076"},
	"N18": {"data": "res://data/dev/ta90_n18.json", "fp": "4f81a66e1485b564f0e6478d1017ae9d532929cdf7d9f73566e6dd993a5b00ac"},
	"N19": {"data": "res://data/dev/ta90_n19.json", "fp": "ddb67ffbb74a9040069043a04b48addb3da640118b8e6483efd3e75ecf5cab4f"},
	"N20": {"data": "res://data/dev/ta90_n20.json", "fp": "ebff998e4fcb4be47bc015ac7c7dff6a1eb64e944e3f6f88753dd537ff5a47b0"},
	"N21": {"data": "res://data/dev/ta90_n21.json", "fp": "598cee830d3bcce7533cfe9b99847b376705e6e5c52181083c771e3fd8231c68"},
	"N22": {"data": "res://data/dev/ta90_n22.json", "fp": "1f4c569074172b7802c5525057cc87e0fd20bff67fc38e909a1270b5c448ffef"},
	"N23": {"data": "res://data/dev/ta90_n23.json", "fp": "feeefb09e8bae3941b0964f6652b2d134a092471c4bce41b74d6fa1c500e7141"},
	"N24": {"data": "res://data/dev/ta90_n24.json", "fp": "c01585766042da0d0292a8eb3be280d1fa2b2d98537549d98e13f4b03043db7d"},
	"N25": {"data": "res://data/dev/ta90_n25.json", "fp": "c1b4d6f3bb6c9ba4cc2c0881bf1c62d75d4c416f9f6b9766103e057ebe20a1c0"},
	"N26": {"data": "res://data/dev/ta90_n26.json", "fp": "995326ce4c6ac4e8825f90a31c94165b89bd58c303883433c1f444b56418b7d9"},
	"N27": {"data": "res://data/dev/ta90_n27.json", "fp": "1c4e8da7efa3442424d7418910c7352fea905efb8f968aa18ee2a4c6d7c178e1"},
	"N28": {"data": "res://data/dev/ta90_n28.json", "fp": "01e190ffd12506befa5f26347eac15fa8714b85fc929010c350e662ee3ba704b"},
	"N29": {"data": "res://data/dev/ta90_n29.json", "fp": "c3ba04c3fe248df1b882ae09bb48afc9aa24b0efd345f28b0ec59b1a27d9a75a"},
	"N30": {"data": "res://data/dev/ta90_n30.json", "fp": "fffe88195b3a60e013d29e687872efc7bd3fa66b2146f900c964bc37aa031bdd"},
	"N31": {"data": "res://data/dev/ta90_n31.json", "fp": "81fde18027c093943a6414373fbbbc452517689c9d6d3350553c6d5bd67a5f8b"},
	"N32": {"data": "res://data/dev/ta90_n32.json", "fp": "bb36f7d5fea3359b009cfbc854d221e51d0d4705a140a97c6bd7d8bf2aa09e24"},
	"N33": {"data": "res://data/dev/ta90_n33.json", "fp": "2846f6a5cab3cb3d51bad78b307bf0d6a980aa7cf591ded097a8d1e1fb796f75"},
	"N34": {"data": "res://data/dev/ta90_n34.json", "fp": "5616045b9a16674cf627f624edb7e75d793973a6adbbbb8cb3e44a4c73dbfe5a"},
	"N35": {"data": "res://data/dev/ta90_n35.json", "fp": "3e6a96041ad6e090b24ea50696b7436ff8819b14d5c73d5974ae5b9121d6adc2"},
	"N36": {"data": "res://data/dev/ta90_n36.json", "fp": "0ce35e1d021d6a7e0496c5439836e429c769a321f5bce1638484edea380971c6"},
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

## Phase 16A: the EXTREME bank's SHORT questionnaire (?extreme90=1 only; the
## hub sets short_q before the page enters the tree). Three questions after
## each tested run, whatever its outcome - and no second (post-play) set:
## the outcome, time, attempts, UNDO, blocked taps... are recorded by the game.
## SKIP leaves the whole questionnaire at once and never blocks anything.
## The answers stay in the timed record's "answers" (with "set" = SHORT_SET),
## apart from the automatic telemetry.
const SHORT_SET := "xb90-short-v1"
const SHORT_Q := [
	["difficulty", "How difficult was\nthis puzzle?", "difficulty", ["EASY", "MEDIUM", "HARD", "VERY HARD", "EXTREME"]],
	["enjoy", "How much did you\nenjoy it?\n(1 = not at all, 5 = a lot)", "enjoyment", ["1", "2", "3", "4", "5"]],
	["another", "Would you play\nanother challenge?", "play another", ["YES", "NO"]],
]
var short_q := false

## The MUSIC toggle changed (the hub remembers it).
signal music_changed(on: bool)

var music: StageMusic
var music_on := true
var _music_btn: PillButton
var _music_pub := 0


## Phase 16: p_store is the storage prefix ("ta90": the experimental
## collection, ?ta90=1; "xb90": the EXTREME bank, ?extreme90=1) - the same
## board keeps separate records per entry, its id and fingerprint unchanged
## in every record; p_word is the neutral player-facing label ("PUZZLE" /
## "CHALLENGE").
var store := "ta90"
var word := "PUZZLE"


func _init(p_board: String = "TA", p_familiarity: String = "", p_session: String = "", p_number: int = 1, p_music_on: bool = true,
		p_store: String = "ta90", p_word: String = "PUZZLE") -> void:
	super("TA", p_familiarity, p_session)
	board_key = p_board if BOARDS90.has(p_board) else "TA"
	number = p_number
	music_on = p_music_on
	store = p_store
	word = p_word
	key = store + "_" + board_key.to_lower()
	test = key
	preset = {"id": board_key, "letter": str(number), "data": BOARDS90[board_key]["data"], "fp": BOARDS90[board_key]["fp"],
		"state": state_path90(board_key, store), "ls": ls_key90(board_key, store)}
	for k in ["data", "state", "ls"]:
		_cfg[k] = preset[k]
	_cfg["title"] = "%s %d" % [word, number]
	_cfg["questions"] = P90_TIMED_Q
	_questions = P90_TIMED_Q.duplicate(true)


static func state_path90(board: String, p_store: String = "ta90") -> String:
	return "user://%s_%s_state.json" % [p_store, board.to_lower()]


static func ls_key90(board: String, p_store: String = "ta90") -> String:
	return "chain_escape_%s_%s_state" % [p_store, board.to_lower()]


static func read_state90(board: String, p_store: String = "ta90") -> Dictionary:
	var texts := [FileAccess.get_file_as_string(state_path90(board, p_store)) if FileAccess.file_exists(state_path90(board, p_store)) else ""]
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(ls_key90(board, p_store)))
	var best := {}
	for t in texts:
		var parsed = JSON.parse_string(t) if t != "" else null
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("order") and (best.is_empty() or int(parsed.get("seq", 0)) > int(best.get("seq", 0))):
			best = parsed
	return best


func limit() -> int:
	return LIMIT_90_MS


func timed_q() -> Array:
	return SHORT_Q if short_q else P90_TIMED_Q


func _tools_text() -> String:
	return "UNDO x3 per attempt, unlimited RESTART. No SHOW A MOVE and no HAMMER."


func intro_text() -> String:
	return "One puzzle. 90 seconds.\n\n" + _tools_text()


func _ready() -> void:
	if short_q:
		_cfg["questions"] = SHORT_Q
		_questions = SHORT_Q.duplicate(true)
	super._ready()
	if word != "PUZZLE":
		# The entry's neutral word on the way back too ("BACK TO CHALLENGES").
		for bb in find_children("BackToPuzzles", "Button", true, false):
			bb.text = "BACK TO %sS" % word
	if short_q:
		# SKIP leaves the whole questionnaire (not one question at a time).
		for c in _think_skip.pressed.get_connections():
			_think_skip.pressed.disconnect(c["callable"])
		_think_skip.pressed.connect(skip_questions)
		_continue_btn.pressed.connect(_short_after_card)
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
		if word != "PUZZLE":
			_brief_text.text = _brief_text.text.replace("PUZZLE %d" % number, "%s %d" % [word, number])


## The board's title in play (the neutral label of its entry).
func begin_puzzle() -> void:
	super.begin_puzzle()
	if word != "PUZZLE" and screen == Screen.PLAYING and play and phase() != "untimed":
		play._title.text = "%s %d" % [word, number]


## SHORT questionnaire: an answer is recorded with the set's version.
func think(answer: String) -> void:
	if short_q and phase() == "timed_q":
		state["timed"]["answers_set"] = SHORT_SET
	super.think(answer)


## SHORT questionnaire: SKIP - the remaining questions are left unanswered
## (recorded as skipped, never inferred) and play goes on at once.
func skip_questions() -> void:
	AudioManager.play_ui_tap()
	if phase() != "timed_q":
		think("")
		return
	var t: Dictionary = state["timed"]
	t["answers_set"] = SHORT_SET
	t["answers_skipped"] = true
	_q = _questions.size()
	state["q"] = _q
	_save_state()
	if str(t.get("outcome", "")) == "TIME UP":
		_show_offer()
	else:
		_to_puzzle_questions(false)


## SHORT questionnaire: no second, post-play set - the run is stored at once
## (after a timed win / GIVE UP, a FINISH or the untimed play after TIME UP).
func _to_puzzle_questions(continued: bool) -> void:
	if not short_q:
		super._to_puzzle_questions(continued)
		return
	var t: Dictionary = state.get("timed", {})
	var cont: Dictionary = state.get("cont", {})
	if not continued and not state.has("cont"):
		state["cont"] = {"continued": false}
	# What the run ended with (automatic, as the post set recorded it).
	state["puzzle_answers"] = {"_after": "untimed play" if cont.get("continued", false) or continued else (
		"timed win" if t.get("outcome", "") == "COMPLETED" else ("finish after TIME UP" if t.get("outcome", "") == "TIME UP" else "timed give up"))}
	_card.visible = false
	_store_results()


## SHORT questionnaire: the difficulty words one per line (compact), the
## 1-5 and YES / NO answers in one row.
func _build_options(opts: Array) -> void:
	if not short_q or not (opts in [SHORT_Q[0][3], SHORT_Q[2][3]]):
		super._build_options(opts)
		return
	for c in _think_opts.get_children():
		_think_opts.remove_child(c)
		c.queue_free()
	var box: BoxContainer = _think_opts
	if opts == SHORT_Q[2][3]:
		box = HBoxContainer.new()
		box.add_theme_constant_override("separation", 18)
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		_think_opts.add_child(box)
	for a in opts:
		var b := _button(a, "Think_%s" % a.replace(" ", "_"), Palette.WHITE, Palette.TEXT)
		b.custom_minimum_size = Vector2(220 if opts == SHORT_Q[2][3] else 0, 76)
		b.pressed.connect(func():
			AudioManager.play_ui_tap()
			think(a))
		box.add_child(b)


func _show_card() -> void:
	super._show_card()
	_card_text.text = _card_text.text.replace("The 2 minutes are over.", "The 90 seconds are over.")
	if short_q:
		_card_text.text = _card_text.text.replace("A few quick questions about the timed run next.", "Three quick questions next (or SKIP).")
	if music:
		music.stop_music()


## SHORT questionnaire: after the untimed game the result card says nothing
## about more questions, and its CONTINUE stores the run (no post-play set).
func _show_untimed_card() -> void:
	super._show_untimed_card()
	if short_q:
		_card_text.text = _card_text.text.replace("\n\nA few quick questions about the puzzle next.", "")


func _short_after_card() -> void:
	if short_q and phase() == "puzzle_q":
		_to_puzzle_questions(true)


## Phase 18B (approved product rule, docs/extreme90_phase18b.md): TIME UP
## ends the timed result; CONTINUE WITHOUT TIMER resumes the EXACT board of
## 0:00 - never a fresh board in its place, even when that position can no
## longer be cleared (RESTART starts again, UNDO takes moves back). The board
## at 0:00 is captured at TIME UP (every field of every block); the run's
## moves are replayed as the play screen dispatches them (escape, Sequence
## advance, push, ram, portals included) and used when they rebuild exactly
## that board (UNDO history kept), else the captured board itself is restored.
func _show_offer() -> void:
	var moves := attempt_moves(state["timed"].get("log", []))
	var at0: Array = state["timed"].get("board_at_timeup", [])
	var m := _replayed(moves)
	var method := "replay"
	if m == null or (not at0.is_empty() and board_state(m) != at0):
		method = "snapshot" if not at0.is_empty() else "fresh"
		m = model_from_state(at0) if not at0.is_empty() else null
	var winnable := m != null and (m.is_empty() or not Solver.from_model(m).solve().is_empty())
	_offer_fresh = method == "fresh"
	state["offer"] = {"from": "fresh" if _offer_fresh else "timeout_state", "moves": moves if method == "replay" else [],
		"resume": method, "winnable_at_timeup": winnable}
	if method == "snapshot":
		state["offer"]["board"] = at0
	_set_phase("offer")
	_card_head.text = "TIME UP"
	var where := " from where you were at 0:00." if not _offer_fresh else ".\nThe board at 0:00 could not be rebuilt, so it starts fresh."
	if not _offer_fresh and not winnable:
		where += "\nThat position can no longer be cleared: RESTART starts it again."
	_card_text.text = "The timed result is recorded: TIME UP.\n\nYou can keep playing the same puzzle without the clock" + where + "\nThis does not change the timed result."
	_continue_btn.visible = false
	_untimed_btn.visible = true
	_finish_btn.visible = true
	_card.visible = true
	_publish_ta()
	_publish_settled()
	_save_state()
	if music:
		music.stop_music()


## The board at 0:00, captured before the timed record is frozen.
func _time_up() -> void:
	if run_active() and play != null and play.model != null:
		_current["board_at_timeup"] = board_state(play.model)
	super._time_up()


## Every move replayed on a fresh model as the play screen dispatches it
## (escape, Sequence advance, push, ram; the board's portals set): the model,
## or null if a move is not legal there (Phase 17's escapes-and-rams replay
## read a Sequence advance as illegal).
func _replayed(moves: Array) -> BoardModel:
	var rec: Dictionary = boards.get(bid(), {})
	var level := PuzzleDefinition.from_dict(rec.get("puzzle", {})).to_level() if not rec.is_empty() else null
	if level == null:
		return null
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)
	m.set_portals(level.portals)
	for id in moves:
		match m.move_state(int(id)):
			"ok":
				m.remove(int(id))
			"advance":
				m.advance(int(id))
			"push":
				m.push(int(id))
			"ram":
				m.ram(int(id))
			_:
				return null
	return m


## Every gameplay field of every block, by id (JSON-safe): the board state
## the continuation must reproduce.
static func board_state(m: BoardModel) -> Array:
	var out := []
	var ids: Array = m.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = m.blocks[id]
		out.append([b.id, b.cell.x, b.cell.y, b.color, b.direction, b.kind, b.lock_color, b.hidden, b.spin_rule, b.spin_step,
			b.rarity, b.switch_group, b.flip_link, b.gate_group, b.gate_link, b.armored, b.seq_stage, b.seq_next, b.twin, b.magnet])
	return out


static func blocks_from_state(st: Array) -> Array:
	var out := []
	for e in st:
		var b := BlockData.new(int(e[0]), Vector2i(int(e[1]), int(e[2])), str(e[3]), int(e[4]), int(e[5]))
		b.lock_color = str(e[6])
		b.hidden = bool(e[7])
		b.spin_rule = int(e[8])
		b.spin_step = int(e[9])
		b.rarity = int(e[10])
		b.switch_group = str(e[11])
		b.flip_link = str(e[12])
		b.gate_group = str(e[13])
		b.gate_link = str(e[14])
		b.armored = bool(e[15])
		b.seq_stage = int(e[16])
		b.seq_next = int(e[17])
		b.twin = str(e[18])
		b.magnet = bool(e[19])
		out.append(b)
	return out


func model_from_state(st: Array) -> BoardModel:
	var rec: Dictionary = boards.get(bid(), {})
	var level := PuzzleDefinition.from_dict(rec["puzzle"]).to_level()
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, blocks_from_state(st))
	m.set_portals(level.portals)
	return m


## The play screen shows `st` (the board itself, as UNDO does - no replay).
func _show_state(st: Array) -> void:
	play.model.restore(blocks_from_state(st))
	play.history.clear()
	play.board.clear_hint()
	play.board.sync_to(play.model.snapshot())
	play.board.refresh_locks(play.model)
	play._progress.set_progress(1.0 - float(play.model.block_count()) / maxf(play._total_blocks, 1.0))
	play._refresh_buttons()


## Phase 18B: every save of the untimed game keeps its board (a reload comes
## back to exactly this board, not to a replay of inferred taps).
func _save_untimed() -> void:
	super._save_untimed()
	if play != null and play.model != null and state.has("live"):
		state["live"]["board"] = board_state(play.model)
		_save_state()


func _start_run() -> void:
	super._start_run()
	_current["assist"] = TA90_RULES.duplicate()


func begin_untimed() -> void:
	# The board to show: after a reload during the untimed game, the board it
	# had (saved with every action); else the board of 0:00 when the offer
	# had to restore it rather than replay the moves.
	var resume := phase() == "untimed"
	var target: Array = []
	if resume:
		target = state.get("live", {}).get("board", [])
	else:
		target = state.get("offer", {}).get("board", [])
	super.begin_untimed()
	var cont: Dictionary = state.get("cont", {})
	cont["resume"] = state.get("offer", {}).get("resume", cont.get("resume", "replay"))
	cont["winnable_at_timeup"] = state.get("offer", {}).get("winnable_at_timeup", cont.get("winnable_at_timeup", true))
	if not target.is_empty() and board_state(play.model) != target:
		_show_state(target)
		if resume:
			cont["reopen_restored"] = int(cont.get("reopen_restored", 0)) + 1
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
