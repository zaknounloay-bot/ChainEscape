extends Node
## Experience Lab QA jump (?experiencelab=N): run once per level with the
## real launch path (GameManager reads the command line):
##   godot --headless --path . res://tools/ExperienceLabQaCheck.tscn -- --experiencelab=13
## Checks: Lab Level N opens directly (no title), in the temporary QA save;
## its lesson / start hint shows as on a first visit; no milestone just by
## opening; clearing it by taps gives its normal milestone and Chapter
## Complete (and after 100 the lab-complete screen); the real save, the
## Opening Lab save, the normal lab save and the lab log are byte-identical.

const MILESTONES := {25: "lab_milestone", 50: "lab_milestone_strong", 75: "lab_milestone_plus", 100: "lab_major"}

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
	_check(n >= 2 and n <= ExperienceLab.LAST_LEVEL, "QA jump asked for on the command line (%s)" % mode)
	if n < 2:
		_finish()
		return
	var before := {}
	for path in ["user://progress.cfg", OpeningLab.SAVE_PATH, ExperienceLab.SAVE_PATH, ExperienceLab.LOG_PATH]:
		before[path] = _read_all(path)
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	_check(ExperienceLab.active and ExperienceLab.qa_level == n, "Experience Lab QA mode for Lab %d" % n)
	_check(game.progress.path == ExperienceLab.QA_SAVE_PATH, "QA uses the temporary QA save (%s)" % game.progress.path)
	_check(game.current_level == n and game.level.name == _lab_level(n).name, "Lab Level %d opens directly ('%s')" % [n, game.level.name])
	_check(not game.ui.is_title_open(), "L%d: no title screen in the way" % n)
	_check(game.level_manager.level_count == ExperienceLab.LAST_LEVEL, "the lab's %d levels" % ExperienceLab.LAST_LEVEL)
	_check(game.progress.highest_completed == n - 1 and game.progress.highest_unlocked == n and not game.progress.best_scores.has(n),
		"QA save: 1-%d cleared, %d open and not yet cleared" % [n - 1, n])
	_check(game.progress.total_stars() == 0 and game.progress.coins == int(Economy.config()["starting_coins"]), "QA save invents no stars or coins (%d coins = a new save)" % game.progress.coins)
	# First-visit onboarding.
	if n == 13:
		_check(game._lesson == "lock" and game.tutorial.is_showing() and game.tutorial._text.contains("left)"), "L13: the lock lesson starts from the beginning ('%s')" % game.tutorial._text)
	elif n == 101:
		_check(game._lesson == "switch" and game.tutorial.is_showing(), "L101: production's Switch lesson starts ('%s')" % game.tutorial._text)
	else:
		_check(game._lesson == "", "L%d: no lesson" % n)
		if game.level.hint != "":
			_check(game.tutorial.is_showing() and game.tutorial._text == game.level.hint, "L%d: the level's intro hint shows ('%s')" % [n, game.tutorial._text])
	# Opening alone never celebrates.
	await _frames(20)
	_check(game.ui.major_milestone_rect().size.x == 0.0 and not game.completed, "L%d: no milestone just by opening" % n)
	# Clear it by taps (the lesson path for 13).
	var t := 0
	while not game.completed and t < 200:
		var id := Solver.from_model(game.model).recommend_move()
		if id == -1:
			break
		game._on_block_tapped(id)
		await _frames(2)
		t += 1
	var overlay := false
	t = 0
	while not (game.completed and game.ui.is_complete_visible()) and t < 600:
		await _frames(2)
		if game.ui.major_milestone_rect().size.x > 0.0:
			overlay = true
		t += 1
	_check(game.completed and game.last_result.get("level", 0) == n, "L%d clears by taps" % n)
	if n == 13:
		_check(game.progress.tips_seen.has("lesson_lock"), "L13: the lesson completed during the clear")
	if n == 101:
		_check(game.progress.tips_seen.has("lesson_switch"), "L101: the Switch lesson completed during the clear")
	var want: String = MILESTONES.get(n, "")
	_check(String(game.last_result.get("celebration", "")) == want and overlay == (want != ""),
		"L%d: milestone '%s' after the clear (want '%s', overlay %s)" % [n, game.last_result.get("celebration", ""), want, overlay])
	if want != "":
		_check(game.ui._major.get_child(0).text == str(n) and game.ui._major.get_child(1).text == "LEVELS ESCAPED!", "L%d overlay reads %d / LEVELS ESCAPED!" % [n, n])
		_check(game.ui._card_title.text == ("MASTER CLEARED!" if n == 100 else "%d LEVELS ESCAPED!" % n), "L%d card title '%s'" % [n, game.ui._card_title.text])
	_check(int(game.last_result.get("chapter_complete", 0)) == (n / 10 if n % 10 == 0 else 0), "L%d Chapter Complete as in normal progression (%s)" % [n, game.last_result.get("chapter_complete", 0)])
	game.next_level()
	await _frames(3)
	if n % 10 == 0:
		_check(game.ui.is_chapter_card_open(), "L%d: the Chapter %d card after NEXT" % [n, n / 10])
		game._after_chapter_card()
		await _frames(3)
	if n == ExperienceLab.LAST_LEVEL:
		_check(ExperienceLab.complete_open and game.current_level == n, "after Lab %d: the end-of-test-build screen" % n)
	else:
		_check(game.current_level == n + 1 and not ExperienceLab.complete_open, "NEXT goes on to Lab %d" % (n + 1))
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


static func _lab_level(n: int) -> LevelData:
	var json = JSON.parse_string(FileAccess.get_file_as_string(ExperienceLab.LEVEL_DIR.path_join("level_%02d.json" % n)))
	return LevelManager.parse_level(json, n, true)


static func _read_all(path: String) -> String:
	var out := ""
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		out += "|" + (FileAccess.get_file_as_string(path + suffix) if FileAccess.file_exists(path + suffix) else "<none>")
	return out
