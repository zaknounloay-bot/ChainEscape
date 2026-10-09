extends Node
## v0.7 PORTAL in Classic (levels 201-225): production checks through the
## real game scene.
##   godot --headless --path . res://tools/PortalProdCheck.tscn
##
## Data: 225 levels load; 1-200 have no portals, every arc level has a
## valid layout, is solvable and uses a portal; the eras / Chapters / the
## 225 celebration config. Economy: Chapter 23 (221-230) is never
## "complete" at 225; Level 225 pays no milestone bonus (presentation only).
## Intro: the NEW MECHANIC card shows once on the first Portal level, is
## saved in tips_seen (also after a reload), is never shown retroactively
## (a player who already cleared 201), blocks taps while open, a tap closes
## it, reduced motion keeps it still. (Not over the title: the browser
## test covers CONTINUE.) Play: 200 -> NEXT -> 201; a blocked portal tap
## ("Blocked after portal A"), a portal escape, Undo, Restart, SHOW A MOVE
## and the Hammer on a portal board; Level Select lists Chapters 21-23 with
## 225 marked; Level 225 completes with the short MILESTONE celebration.

const PROGRESS_PATH := "user://portal_prod_check.cfg"

var game: GameManager
var failures: Array[String] = []
var passed := 0


func _ready() -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	GameManager.skip_title = true
	_run.call_deferred()


func _run() -> void:
	_data()
	_economy()
	_intro_card()
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	await _intro_flow()
	await _play_portal_level()
	await _level_select()
	await _milestone_225()
	await _not_retroactive()
	print("")
	print("%d checks passed, %d failed" % [passed, failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	print("PORTAL PRODUCTION CHECKS PASSED" if failures.is_empty() else "PORTAL PRODUCTION CHECKS FAILED")
	get_tree().quit(0 if failures.is_empty() else 1)


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failures.append(what)
		print("FAIL: " + what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


static func _load(n: int) -> LevelData:
	return LevelManager.read_level(n)


# --- Data --------------------------------------------------------------------------------

func _data() -> void:
	var lm := LevelManager.new()
	lm._ready()
	_check(lm.level_count >= 225, "at least 225 levels found (%d)" % lm.level_count)  # v0.8: 300
	lm.free()
	var none_before := true
	for n in range(1, 201):
		none_before = none_before and _load(n).portals.is_empty()
	_check(none_before, "levels 1-200 have no portals")
	for n in range(201, 226):
		var level := _load(n)
		_check(not level.portals.is_empty() and Portals.layout_errors(level.rows, level.columns, level.portals).is_empty(), "L%d: a valid portal layout" % n)
		var m := LevelAnalysis.analyze(level, false)
		_check(m["solvable"] and not m["aborted"] and m["portal_moves"] > 0, "L%d: solvable and the solution goes through a portal" % n)
		_check(LevelManager.parse_level(JSON.parse_string(LevelManager.to_json_text(level)), n).portals == level.portals, "L%d: portals survive the JSON round trip" % n)
	_check(Chapters.era_of(201)["name"] == "Third Era" and Chapters.era_of(225)["from"] == 201, "201-225 are the Third Era")
	_check(Chapters.chapter_of(201) == 21 and Chapters.chapter_of(225) == 23, "Chapters 21-23")
	_check(Chapters.celebration_tier(225) == "lab_milestone" and Chapters.celebration_tier(201) == "" and Chapters.celebration_tier(224) == "", "Level 225 has the standard milestone celebration, its neighbours none")
	_check(not Chapters.is_milestone(225) and not Chapters.is_master(225), "225 is neither a paying milestone nor a Master Level")
	_check(Chapters.theme_for_level(201).has("name") and Chapters.theme_for_level(225).has("name"), "Chapters 21-23 have themes")


func _economy() -> void:
	var p := PlayerProgress.new("user://portal_prod_economy.cfg")
	for n in range(221, 226):
		p.best_scores[n] = 100
	_check(not Economy.is_chapter_cleared(p, 23, 225), "Chapter 23 is not complete at 225 (221-230)")
	_check(Economy.check_chapter_complete(p, 23, 225) == 0 and not p.completed_chapters.has(23), "no Chapter 23 bonus at 225")
	for n in range(211, 221):
		p.best_scores[n] = 100
	_check(Economy.is_chapter_cleared(p, 22, 225), "Chapter 22 (211-220) completes normally")
	for n in range(1, 11):
		p.best_scores[n] = 100
	_check(Economy.is_chapter_cleared(p, 1, 225) and Economy.is_chapter_cleared(p, 1, 200), "full Chapters unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://portal_prod_economy.cfg"))


func _intro_card() -> void:
	_check(MechanicIntro.TEXT["portal"]["badge"] == "NEW MECHANIC!" and MechanicIntro.TEXT["portal"]["name"] == "PORTAL"
		and MechanicIntro.TEXT["portal"]["steps"] == ["ENTER A", "EXIT A", "CONTINUE"], "intro text: NEW MECHANIC! PORTAL / ENTER A -> EXIT A -> CONTINUE")
	_check(MechanicIntro.HOLD >= 1.0 and MechanicIntro.HOLD <= 2.0, "intro lasts about 1-2 s (%.1f)" % MechanicIntro.HOLD)


# --- Intro in the game ---------------------------------------------------------------------

func _intro_flow() -> void:
	var p := game.progress
	# A player who just cleared 200.
	for n in range(1, 201):
		p.best_scores[n] = 1000
		p.best_stars[n] = 1
	p.highest_completed = 200
	p.highest_unlocked = 201
	p.tips_seen.erase("intro_portal")
	game.start_level(200)
	await _frames(3)
	_check(game.mechanic_intro == null, "no intro on a level without portals")
	game.next_level()
	await _frames(3)
	_check(game.current_level == 201, "NEXT from 200 opens 201 (%d)" % game.current_level)
	_check(game.mechanic_intro != null, "first Portal level: NEW MECHANIC card shown")
	_check(p.tips_seen.has("intro_portal"), "intro saved in tips_seen at once")
	_check(not game.board.input_enabled, "board taps wait while the card is open")
	var reloaded := PlayerProgress.new(PROGRESS_PATH).load_from_disk()
	_check(reloaded.tips_seen.has("intro_portal"), "tips_seen survives a reload")
	_check(game.mechanic_intro != null and not game.mechanic_intro.reduced, "full motion by default")
	await _wait(MechanicIntro.HOLD + 0.5)
	_check(game.mechanic_intro == null and game.board.input_enabled, "the card closes by itself (~%.1f s) and play starts" % MechanicIntro.HOLD)
	game.restart()
	await _frames(3)
	_check(game.mechanic_intro == null, "Restart: no second intro")
	game.start_level(202)
	await _frames(3)
	_check(game.mechanic_intro == null, "next Portal level: no intro")
	# Tap-to-skip and reduced motion, on the card itself.
	var card := MechanicIntro.new("portal", true)
	var done := [false]
	card.finished.connect(func(): done[0] = true)
	add_child(card)
	await _frames(2)
	_check(card.reduced and card._diagram.reduced, "reduced motion: a still picture")
	card.close()
	card.close()
	await _wait(0.3)
	_check(done[0] and not is_instance_valid(card), "a tap closes the card; finished fires once")


# --- Play on a portal board -------------------------------------------------------------------

func _play_portal_level() -> void:
	game.start_level(201)
	await _frames(3)
	_check(game.mechanic_intro == null and game.board.portals.size() == 2 and game.model.portals.size() == 2, "201 loads its portals into the rules and the board")
	# A block whose lane goes through the portal and is blocked on the far side.
	var remote := -1
	for id in game.model.blocks:
		var ln := game.model.lane(id)
		if not ln["via"].is_empty() and ln["blocker"] != null and game.model.move_state(id) == "blocked":
			remote = id
	_check(remote != -1, "201 starts with a portal lane blocked on the far side")
	if remote != -1:
		game._on_block_tapped(remote)
		await _frames(2)
		_check(game.model.blocks.has(remote) and game.mistakes == 1, "blocked portal tap: nothing moves, counts as a mistake")
		_check(game.tutorial._text == GameManager.PORTAL_BLOCKED_TEXT % "A", "'Blocked after portal A' shown ('%s')" % game.tutorial._text)
	# SHOW A MOVE: legal and keeps it solvable.
	game.request_hint()
	await _frames(2)
	var hinted := game.hint_block
	_check(hinted != -1 and game.model.is_playable(hinted), "SHOW A MOVE marks a legal move on a portal board")
	# Play until a portal escape happens, then Undo it.
	var escaped_via := -1
	var guard := 0
	while escaped_via == -1 and not game.model.is_empty() and guard < 40:
		guard += 1
		var id := Solver.from_model(game.model).recommend_move()
		var via: Array = game.model.lane(id)["via"]
		var before := game.model.block_count()
		game._on_block_tapped(id)
		await _wait(0.1)
		if not via.is_empty():
			escaped_via = id
			_check(not game.model.blocks.has(id) and game.model.block_count() == before - 1, "portal escape removes the block")
	_check(escaped_via != -1, "a portal escape happened")
	game.undo()
	await _wait(0.1)
	_check(game.model.blocks.has(escaped_via) and game.model.portals.size() == 2 and game.model.is_playable(escaped_via), "Undo brings the portal escape back; portals unchanged")
	game.restart()
	await _wait(0.2)
	_check(game.model.block_count() == _load(201).blocks.size() and game.model.portals.size() == 2, "Restart rebuilds the portal board")
	# Hammer on a portal board: the shared safety rule (solver with portals).
	game.progress.inventory["hammer"] = 1
	var safe := -1
	for id in game.model.blocks:
		if Solver.hammer_safe(game.model, id):
			safe = id
			break
	_check(safe != -1, "some block is Hammer-safe on 201")
	game.toggle_hammer()
	game._on_block_tapped(safe)
	await _wait(0.2)
	_check(not game.model.blocks.has(safe) and game.hammers_used == 1, "Hammer smashes a safe block on a portal board")
	_check(Solver.from_model(game.model).is_solvable(), "the board is still solvable after the Hammer")


# --- Level Select ----------------------------------------------------------------------

func _level_select() -> void:
	game.open_level_select()
	await _frames(3)
	_check(game.select_shown["unlocked"].has(201) and game.select_shown["locked"].has(225), "Level Select: 201 open, 225 still locked")
	_check(game.select_shown["unlocked"].size() + game.select_shown["locked"].size() == game.level_manager.level_count, "Level Select lists every level")
	await _frames(2)


# --- 225 ---------------------------------------------------------------------------------

func _milestone_225() -> void:
	var p := game.progress
	for n in range(201, 225):
		p.best_scores[n] = 1000
		p.best_stars[n] = 1
	p.highest_completed = 224
	p.highest_unlocked = 225
	game.start_level(225)
	await _frames(3)
	_check(game.mechanic_intro == null, "225: no intro (already seen)")
	_check(game.level_banner(225).contains("MILESTONE"), "225 banner: MILESTONE (%s)" % game.level_banner(225))
	var coins_before := p.coins
	var guard := 0
	while not game.model.is_empty() and guard < 80:
		guard += 1
		game._on_block_tapped(Solver.from_model(game.model).recommend_move())
		await _wait(0.06)
	var t := 0.0
	while not game.ui.is_complete_visible() and t < 8.0:
		await _wait(0.2)
		t += 0.2
	var r := game.last_result
	_check(game.ui.is_complete_visible() and r.get("level", 0) == 225, "225 completes")
	_check(r.get("celebration", "") == "lab_milestone" and game.ui._card_title.text == "225 LEVELS ESCAPED!" and not r.get("milestone", true) and not r.get("master", true),
		"225: the standard milestone celebration ('%s'), not a paying milestone / Master" % game.ui._card_title.text)
	_check(not String(r.get("coin_notes", "")).contains("MILESTONE") and not p.completed_chapters.has(23), "225 pays no milestone bonus and no Chapter 23 bonus")
	_check(p.coins - coins_before == r["coins"], "coins paid = the card's normal level reward (%d)" % r["coins"])
	_check(r.get("is_last", false) == (game.level_manager.level_count == 225), "225 is the last level only while no level follows it")


func _not_retroactive() -> void:
	# A player already past 201 who has never seen the card: no card.
	var p := game.progress
	p.tips_seen.erase("intro_portal")
	p.highest_completed = 210
	game.start_level(205)
	await _frames(3)
	_check(game.mechanic_intro == null and not p.tips_seen.has("intro_portal"), "not shown retroactively (already past the level)")
	game.start_level(211)
	await _frames(3)
	_check(game.mechanic_intro == null and not p.tips_seen.has("intro_portal"), "not shown to a player who already cleared 201, on any Portal level")
