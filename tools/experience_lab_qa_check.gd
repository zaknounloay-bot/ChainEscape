extends Node
## Experience Lab QA session (?experiencelab=N, N = 2..300): run once per
## level with the real launch path (GameManager reads the command line):
##   godot --headless --path . res://tools/ExperienceLabQaCheck.tscn -- --experiencelab=13 --qareset
## --qaexpect=full (default): a FRESH session at N (from --qareset, a new
##   checkpoint, or no QA save): Level N (the frozen production board) opens
##   directly (no title) in the QA save; its lesson / start hint shows as on
##   a first visit; no milestone just by opening; clearing it by taps gives
##   its normal milestone and Chapter Complete; NEXT goes on to N+1 (200 ->
##   201 too); the real save, the Opening Lab save, the normal lab save, the
##   lab log and the normal game's session diagnostics are byte-identical.
## --qaexpect=fresh: only the fresh-session checks (nothing is played).
## --qaexpect=resume: the same N again without --qareset (a Safari reload):
##   the stored session resumes where it was (after a full run: Level N+1,
##   N cleared), nothing re-seeded.

const PROTECTED := ["user://progress.cfg", "user://chain_escape_diag_last.json", "user://chain_escape_session.json"]

var game: GameManager
var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	_run.call_deferred()


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		print("FAIL: " + what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	var mode := ExperienceLab.requested()
	var n := int(mode) if mode.is_valid_int() else 0
	var expect := "full"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--qaexpect="):
			expect = a.get_slice("=", 1)
	_check(n >= 2 and n <= ExperienceLab.QA_LAST_LEVEL, "QA jump asked for on the command line (%s)" % mode)
	if n < 2:
		_finish()
		return
	var before := {}
	for path in PROTECTED + [OpeningLab.SAVE_PATH, ExperienceLab.SAVE_PATH, ExperienceLab.LOG_PATH]:
		before[path] = _read_all(path)
	var stored := ConfigFile.new()
	var stored_seq := int(stored.get_value("meta", "seq", 0)) if stored.load(ExperienceLab.QA_SAVE_PATH) == OK else 0
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	_check(ExperienceLab.active and ExperienceLab.qa and ExperienceLab.qa_level == n, "Experience Lab QA session for Level %d" % n)
	_check(game.progress.path == ExperienceLab.QA_SAVE_PATH and PlayerProgress.mirror_key == ExperienceLab.QA_MIRROR_KEY
		and PlayerProgress.beacon_key == ExperienceLab.QA_BEACON_KEY, "QA uses the QA save and its own Web keys (%s)" % game.progress.path)
	_check(game.level_manager.level_count == ExperienceLab.QA_LAST_LEVEL and LevelManager.override_dir == "",
		"the QA session plays the frozen production Levels 1-%d" % game.level_manager.level_count)
	_check(not game.ui.is_title_open(), "L%d: no title screen in the way" % n)
	_check(int(game.progress.extra("qa", "origin", 0)) == n, "the QA save records its checkpoint (qa/origin %s)" % game.progress.extra("qa", "origin", 0))
	if expect == "resume":
		_check(game.progress.load_source != "new" and stored_seq > 1 and game.progress.seq > stored_seq,
			"resume: the stored QA save is loaded and goes on, not re-seeded (source %s, seq %d after %d)" % [game.progress.load_source, game.progress.seq, stored_seq])
		_check(game.current_level == n + 1 and game.progress.current_level == n + 1 and game.progress.best_scores.has(n) and game.progress.highest_completed >= n,
			"resume: the session continues at Level %d with Level %d cleared (level %d, highest %d)" % [n + 1, n, game.current_level, game.progress.highest_completed])
		_check(game.level.name == _prod_level(n + 1).name, "resume: Level %d is the production board ('%s')" % [n + 1, game.level.name])
		for path in before:
			_check(_read_all(path) == before[path], "%s is byte-identical" % path)
		_finish()
		return
	_check(game.current_level == n and game.level.name == _prod_level(n).name, "Level %d (production board) opens directly ('%s')" % [n, game.level.name])
	_check(game.progress.highest_completed == n - 1 and game.progress.highest_unlocked == n and not game.progress.best_scores.has(n),
		"fresh QA save: 1-%d cleared, %d open and not yet cleared" % [n - 1, n])
	_check(game.progress.total_stars() == 0 and game.progress.coins == int(Economy.config()["starting_coins"]) and game.progress.achievements.is_empty()
		and game.progress.perfect_levels.is_empty() and game.progress.reward_blocks.is_empty(),
		"fresh QA save invents no stars, coins, achievements or rewards (%d coins = a new save)" % game.progress.coins)
	if expect == "fresh":
		for path in before:
			_check(_read_all(path) == before[path], "%s is byte-identical" % path)
		_finish()
		return
	# First-visit onboarding.
	# The NEW MECHANIC card, then the finger lesson (docs/tutorial_rule.md).
	const THIRD_ERA := {76: "magnet", 201: "portal", 226: "sequence", 251: "movable"}
	if THIRD_ERA.has(n):
		# The NEW MECHANIC card first (input off, nothing of the lesson under
		# it), then the guided finger lesson.
		_check(game.mechanic_intro != null and not game.board.input_enabled and not game.tutorial.is_showing() and _finger(game) == -1,
			"L%d: the NEW MECHANIC card opens first, the lesson waits under nothing" % n)
		var w := 0
		while game.mechanic_intro != null and w < 600:
			await _frames(2)
			w += 1
		await _frames(4)
		var f := _finger(game)
		_check(game._lesson == THIRD_ERA[n] and game.tutorial.is_showing() and game.board.input_enabled and f >= 0 and game.model.move_state(f) in ["ok", "advance", "push"],
			"L%d: after the card the %s lesson starts, finger on a legal move ('%s', finger %d)" % [n, THIRD_ERA[n], game.tutorial._text, f])
	elif n == 13:
		_check(game._lesson == "lock" and game.tutorial.is_showing() and game.tutorial._text.contains("left)"), "L13: the lock lesson starts from the beginning ('%s')" % game.tutorial._text)
	elif n == 101:
		_check(game._lesson == "switch" and game.tutorial.is_showing(), "L101: production's Switch lesson starts ('%s')" % game.tutorial._text)
	elif n == 151:
		_check(game._lesson == "armor" and game.tutorial.is_showing() and game.tutorial._text.begins_with("Armored: can't escape"),
			"L151: production's Armor lesson starts ('%s')" % game.tutorial._text)
	elif n == 121:
		_check(game._lesson == "gate" and game.tutorial.is_showing() and game.tutorial._text == "GATE C opens when every block chained C escapes (1 left)",
			"L121: production's Chain Gate lesson starts ('%s')" % game.tutorial._text)
	elif n == 176:
		_check(game._lesson == "twins" and game.tutorial.visible and game.tutorial._text.contains("TWIN") and game.board.bond_count() == 2,
			"L176: the Twins lesson starts on Twin Lights ('%s')" % game.tutorial._text)
	else:
		_check(game._lesson == "", "L%d: no lesson" % n)
		if game.level.hint != "":
			_check(game.tutorial.is_showing() and game.tutorial._text == game.level.hint, "L%d: the level's intro hint shows ('%s')" % [n, game.tutorial._text])
	# Earlier lessons / mechanic tips count as seen (as for a real player).
	if n > 101:
		_check(game.progress.tips_seen.has("lesson_switch") and game.progress.tips_seen.has("switch"), "L%d: the Switch lesson and tip count as seen" % n)
	if n > 121:
		_check(game.progress.tips_seen.has("lesson_gate") and game.progress.tips_seen.has("gate"), "L%d: the Chain Gate lesson and tip count as seen" % n)
	if n > 151:
		_check(game.progress.tips_seen.has("lesson_armor") and game.progress.tips_seen.has("armor"), "L%d: the Armor lesson and tip count as seen" % n)
	if n == 161:
		_check(game._lesson == "", "Lab 161: no Armor lesson again")
	if n > 176:
		_check(game.progress.tips_seen.has("lesson_twins"), "L%d: the Twins lesson counts as seen" % n)
	_check(game.level.blocks.any(func(b): return b.twin != "") == (n in [176, 177, 179, 182, 184, 187, 190, 192, 194, 197]),
		"L%d: Twins exactly in the Twins levels" % n)
	if n == 125:
		_check(game.level.hint == "" and not game.tutorial.is_showing() and game.hint_block == -1, "L125: production start - no hint, message or finger")
	# Opening alone never celebrates.
	await _frames(20)
	_check(game.ui.major_milestone_rect().size.x == 0.0 and not game.completed, "L%d: no milestone just by opening" % n)
	# Clear it by taps (the lesson path for 13). A Third Era lesson is
	# followed FINGER by finger until it ends (never a trap).
	var t := 0
	if THIRD_ERA.has(n):
		var kind: String = THIRD_ERA[n]
		while game._lesson != "" and not game.completed and t < 60:
			var f := _finger(game)
			if f < 0:
				break
			_check(Solver.from_model(game.model).is_solvable(), "L%d: the level is still solvable where the finger points (step %d)" % [n, t])
			game._on_block_tapped(f)
			await _frames(3)
			t += 1
		_check(game._lesson == "" and game.progress.tips_seen.has("lesson_" + kind) and (game.completed or Solver.from_model(game.model).is_solvable()),
			"L%d: following the finger ends the %s lesson after its key action (%d taps), level cleared or still solvable ('%s')" % [n, kind, t, game.tutorial._text])
	t = 0
	while not game.completed and t < 200:
		var id := Solver.from_model(game.model).recommend_move()
		if id == -1:
			break
		game._on_block_tapped(id)
		await _frames(2)
		t += 1
	var overlay := false
	var stamps := {}
	var vw := game.get_viewport().get_visible_rect().size.x
	t = 0
	while not (game.completed and game.ui.is_complete_visible()) and t < 600:
		await _frames(2)
		if game.ui.major_milestone_rect().size.x > 0.0:
			overlay = true
			var r := game.ui.major_milestone_rect()
			_check(r.position.x >= 0.0 and r.end.x <= vw, "L%d: the milestone overlay stays on screen" % n)
		var st: Dictionary = game.ui.stamp_state()
		if not st.is_empty() and absf(st["scale"] - 1.0) < 0.02 and st["alpha"] > 0.99:
			stamps[st["text"]] = st
		t += 1
	for text in stamps:
		var rest: Array = stamps[text]["rest"]
		_check(rest[0] >= UIManager.MAJOR_MARGIN - 0.5 and rest[2] <= vw - UIManager.MAJOR_MARGIN + 0.5,
			"L%d: the '%s' stamp rests fully on screen (%.0f..%.0f of %.0f, font %d)" % [n, text, rest[0], rest[2], vw, stamps[text]["font_size"]])
	_check(game.completed and game.last_result.get("level", 0) == n, "L%d clears by taps" % n)
	if n == 13:
		_check(game.progress.tips_seen.has("lesson_lock"), "L13: the lesson completed during the clear")
	if n == 101:
		_check(game.progress.tips_seen.has("lesson_switch"), "L101: the Switch lesson completed during the clear")
	if n == 121:
		_check(game.progress.tips_seen.has("lesson_gate"), "L121: the Chain Gate lesson completed during the clear")
	if n == 151:
		_check(game.progress.tips_seen.has("lesson_armor"), "L151: the Armor lesson completed during the clear")
	if n == 176:
		_check(game.progress.tips_seen.has("lesson_twins"), "L176: the Twins lesson completed during the clear")
	_check(game.mistakes == 0, "L%d: SHOW A MOVE's line costs no heart" % n)
	if n == 200:
		_check(game.last_result.get("master", false) and stamps.has("GRAND MASTER!") and str(game.last_result.get("coin_notes", "")).contains("GRAND MASTER")
			and game.progress.achievements.has("master_200") and game.last_result.get("coins", 0) >= int(Economy.config()["rewards"]["master_clear_200"]),
			"L200: the GRAND MASTER stamp and its one-time bonus (in the QA save) ('%s', stamps %s)" % [game.last_result.get("coin_notes", ""), stamps.keys()])
	if n == 100:
		_check(stamps.has("MASTER!") and game.progress.achievements.has("master"), "L100: the MASTER stamp and its one-time bonus (stamps %s)" % [stamps.keys()])
	if n in [125, 150, 175]:
		_check(game.progress.achievements.has("milestone_%d" % n) and str(game.last_result.get("coin_notes", "")).contains("MILESTONE"),
			"L%d: the milestone bonus is still paid once ('%s')" % [n, game.last_result.get("coin_notes", "")])
	if n % 25 == 0:
		_check(not stamps.has("MILESTONE!") and not stamps.keys().any(func(k): return String(k).ends_with(" LEVELS!")), "L%d: no extra MILESTONE stamp (%s)" % [n, stamps.keys()])
	var want := String(Chapters.config().get("celebration_levels", {}).get(str(n), ""))  # production's tiers
	var big := want.begins_with("lab_") or want == "major"  # the "N / LEVELS ESCAPED!" overlay
	_check(String(game.last_result.get("celebration", "")) == want and overlay == big,
		"L%d: milestone '%s' after the clear (want '%s', overlay %s)" % [n, game.last_result.get("celebration", ""), want, overlay])
	if big:
		_check(game.ui._major.get_child(0).text == str(n) and game.ui._major.get_child(1).text == "LEVELS ESCAPED!", "L%d overlay reads %d / LEVELS ESCAPED!" % [n, n])
		_check(game.ui._card_title.text == "%d LEVELS ESCAPED!" % n, "L%d card title '%s'" % [n, game.ui._card_title.text])
	_check(int(game.last_result.get("chapter_complete", 0)) == (n / 10 if n % 10 == 0 else 0), "L%d Chapter Complete as in normal progression (%s)" % [n, game.last_result.get("chapter_complete", 0)])
	game.next_level()
	await _frames(3)
	if n % 10 == 0:
		_check(game.ui.is_chapter_card_open(), "L%d: the Chapter %d card after NEXT" % [n, n / 10])
		game._after_chapter_card()
		await _frames(3)
	if n == game.level_manager.level_count:
		_check(game.ui.is_level_select_open() and game.progress.best_scores.has(n), "after Level %d (the last): Level Select, %d cleared in the QA save" % [n, n])
	else:
		_check(game.current_level == n + 1 and not ExperienceLab.complete_open and game.level.name == _prod_level(n + 1).name,
			"NEXT goes on to Level %d ('%s')" % [n + 1, game.level.name])
		_check(game.progress.current_level == n + 1 and game.progress.best_scores.has(n), "the QA save holds the progress (Level %d next, %d cleared)" % [n + 1, n])
		if THIRD_ERA.has(n + 1):
			# Reached by play: the NEW MECHANIC card first, then the lesson.
			_check(game.mechanic_intro != null and not game.board.input_enabled, "L%d reached by NEXT opens the NEW MECHANIC card" % (n + 1))
			var w2 := 0
			while game.mechanic_intro != null and w2 < 600:
				await _frames(2)
				w2 += 1
			await _frames(4)
			_check(game._lesson == THIRD_ERA[n + 1] and _finger(game) >= 0, "L%d reached by NEXT: the %s lesson starts after the card" % [n + 1, THIRD_ERA[n + 1]])
	for path in before:
		_check(_read_all(path) == before[path], "%s is byte-identical after the QA session" % path)
	_finish()


func _finish() -> void:
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("EXPERIENCE LAB QA CHECKS PASSED" if failures.is_empty() else "EXPERIENCE LAB QA CHECKS FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


## The block the lesson finger points at (-1: none).
static func _finger(g: GameManager) -> int:
	for id in g.board._views:
		if g.board._views[id].hinted:
			return id
	return -1


static func _prod_level(n: int) -> LevelData:
	var json = JSON.parse_string(FileAccess.get_file_as_string("res://levels/level_%02d.json" % n))
	return LevelManager.parse_level(json, n, true)


static func _read_all(path: String) -> String:
	var out := ""
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		out += "|" + (FileAccess.get_file_as_string(path + suffix) if FileAccess.file_exists(path + suffix) else "<none>")
	return out
