extends Node
## GAMEPLAY FEEDBACK POLISH (Phase 2A) checks - headless, its own save only:
##   godot --headless --path . res://tools/FeedbackCheck.tscn
## A. Level 3 (no hearts): a blocked tap nudges, rings the real blocker,
##    never shows a heart or touches the hearts bar.
## B. Level 6 (hearts): 3 -> 2 -> 1 -> 0 hearts, each loss with ONE heart
##    rising from the tapped block and the bar's beat; the out-of-hearts
##    timing (0.45 s, then 1.3 s, then a retry) is unchanged.
## C. Hearts bar: full and lost hearts read apart on light and dark
##    Chapters (lost = faint fill + outline).
## D. Locked block: a mistake as before, the padlock responds, the short
##    rule repeats after a cooldown (and stays up while tapped again).
## E. Free taps (hidden, crate, gate, armored, twin wait): no heart, no
##    heart chip, no failure feedback recorded.
## F. Ambiguous blockers are never ringed (a stuck Movable block, a twin's
##    lane has its own rings); portal blockers keep their ring.
## G. No moves left: "tap Undo" only when Undo works, else "tap Restart"
##    (and that button pulses); the Hint dead end says the same.
## H. Rapid repeated taps never stack rings, hearts or padlock beats.
## I. Rules untouched: mistakes / chain / hearts / score settle as before,
##    nothing new in the save, no per-frame loop added.

const SAVE := "user://feedback_check_progress.cfg"
var passed := 0
var failures: Array[String] = []
var _done: Array[String] = []
var game


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		if OS.get_cmdline_user_args().has("--verbose"):
			print("ok: " + what)
	else:
		failures.append(what)
		print("FAIL: " + what)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	PlayerProgress.default_path = SAVE
	_wipe(SAVE)
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	game._hide_title()
	_check(BuildFlags.feedback_polish(), "feedback polish is on outside the player build")
	await _no_hearts()
	await _hearts_level()
	await _hearts_bar_themes()
	await _locked()
	await _free_taps()
	await _ambiguous()
	await _no_moves()
	await _rapid()
	await _rules_and_save()
	_check(_done == ["no_hearts", "hearts", "themes", "locked", "free", "ambiguous", "no_moves", "rapid", "rules"],
		"every section ran to its end (%s)" % [_done])
	game.queue_free()
	await _wait(3.5)  # pending message timers and tweens finish before quitting
	_wipe(SAVE)
	print("%d checks passed, %d failed" % [passed, failures.size()])
	if failures.is_empty():
		print("FEEDBACK CHECKS PASSED")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


static func _wipe(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _start(n: int) -> void:
	game.start_level(n, "select")
	await _frames(2)
	game.tutorial.hide_hint(true)
	game._lesson = ""
	game.board.set_marks([])


## First block of `state` (non-twin unless `twin`), filtered by `pred`.
func _find(state: String, pred: Callable = func(_id): return true) -> int:
	var ids: Array = game.model.blocks.keys()
	ids.sort()
	for id in ids:
		if game.model.move_state(id) == state and pred.call(id):
			return id
	return -1


func _straight_blocked(id) -> bool:
	return game.model.twin_partner(id) < 0


## Live (not freed / not queued) children of the board's effects layer of
## a given inner class.
func _live_fx(kind: String) -> Array:
	var out := []
	for c in game.board._fx_root.get_children():
		if c.is_queued_for_deletion():
			continue
		var s: Script = c.get_script()
		if s and s.resource_path == "" and c.has_method("_draw") and _fx_kind(c) == kind:
			out.append(c)
	return out


func _fx_kind(c: Node) -> String:
	if c is Board.HeartChip:
		return "chip"
	if c is Board.RewardRing:
		return "ring"
	return ""


# --- A. No hearts ---------------------------------------------------------------

func _no_hearts() -> void:
	await _start(3)
	_check(game.max_hearts == 0, "Level 3 has no hearts")
	var id := _find("blocked", _straight_blocked)
	var blocker: BlockData = game.model.find_blocker(id)
	var chips: int = game.board.heart_chips_shown
	var m0: int = game.mistakes
	game._on_block_tapped(id)
	await _frames(2)
	var f: Dictionary = game.last_feedback
	_check(f.get("kind") == "blocked" and f.get("id") == id, "L3: a blocked tap is recorded as 'blocked'")
	_check(f.get("ringed") == blocker.id and game.board.last_ring_id == blocker.id, "L3: the real blocker (#%d) is ringed" % blocker.id)
	_check(not f.get("heart_chip") and game.board.heart_chips_shown == chips and _live_fx("chip").is_empty(), "L3: no heart rises (no hearts on this level)")
	_check(game.hearts == 0 and not game.ui._hearts.is_animating(), "L3: hearts untouched")
	_check(game.mistakes == m0 + 1 and game.chain == 0, "L3: still counted as a mistake (as before)")
	var v: BlockView = game.board.get_view(id)
	var fwd := Vector2(Direction.vector(game.model.blocks[id].direction))
	await _frames(3)
	var out := (v.position - v.home).dot(fwd)
	_check(out > game.board.cell_size * 0.12, "L3: the nudge is longer than the release one (%.1f px > 0.12 cell)" % out)
	await _wait(0.5)
	_check(v.position.distance_to(v.home) < 0.5, "L3: the block settles back home")
	_done.append("no_hearts")


# --- B. Hearts ------------------------------------------------------------------

func _hearts_level() -> void:
	await _start(6)
	_check(game.max_hearts == 3 and game.hearts == 3 and game.ui._hearts.hearts == 3, "L6 starts with 3 hearts")
	var id := _find("blocked", _straight_blocked)
	for expect in [2, 1]:
		var chips: int = game.board.heart_chips_shown
		game._on_block_tapped(id)
		await _frames(2)
		_check(game.hearts == expect and game.ui._hearts.hearts == expect, "L6: a blocked tap -> %d heart(s) left (bar agrees)" % expect)
		_check(game.last_feedback.get("heart_chip") and game.board.heart_chips_shown == chips + 1 and _live_fx("chip").size() == 1,
			"L6 (%d left): exactly one heart rises from the tapped block" % expect)
		var chip: Node2D = _live_fx("chip")[0]
		var home: Vector2 = game.board.get_view(id).home
		_check(chip.position.distance_to(home) < game.board.cell_size, "L6 (%d left): the heart starts at the tapped block" % expect)
		_check(game.ui._hearts.is_animating(), "L6 (%d left): the hearts bar plays its loss beat" % expect)
		_check(not chip.has_method("_process"), "the heart chip has no per-frame loop")
		await _wait(0.8)
		_check(_live_fx("chip").is_empty() and not game.ui._hearts.is_animating(), "L6 (%d left): the heart and the bar beat end within 0.8 s" % expect)
	# Last heart: the unchanged out-of-hearts beat.
	var t0 := Time.get_ticks_msec()
	game._on_block_tapped(id)
	await _frames(1)
	_check(game.hearts == 0 and game.game_over and game.last_feedback.get("heart_chip"), "L6: the last heart is shown leaving too")
	var retry_at := -1
	for i in 400:
		await _frames(1)
		if not game.game_over:
			retry_at = Time.get_ticks_msec() - t0
			break
	_check(retry_at >= 1700 and retry_at <= 2300, "out of hearts: retry after 0.45 s + 1.3 s as before (%d ms)" % retry_at)
	_check(game.hearts == 3 and game.ui._hearts.hearts == 3, "the retry starts with 3 full hearts")
	_done.append("hearts")


# --- C. Hearts bar themes -------------------------------------------------------

func _hearts_bar_themes() -> void:
	var dark := -1
	var light := -1
	for n in range(6, 301):
		var t := Chapters.theme_for_level(n)
		if t.get("dark", false) and dark < 0:
			dark = n
		elif not t.get("dark", false) and light < 0:
			light = n
	for n in [light, dark]:
		await _start(n)
		var hb: HeartsBar = game.ui._hearts
		var is_dark: bool = Chapters.theme_for_level(n)["dark"]
		_check(hb.strong and hb.heart_size == UIManager.QA_HEART_SIZE, "L%d: strong hearts bar at the layout C size (%d)" % [n, hb.heart_size])
		_check(hb.empty_outline.a >= 0.4 and hb.empty_color.a <= 0.6,
			"L%d (%s): a lost heart is a faint fill (a=%.2f) with a clear outline (a=%.2f)" % [n, "dark" if is_dark else "light", hb.empty_color.a, hb.empty_outline.a])
		var bg: Color = Chapters.theme_for_level(n).get("bg_top", Color.WHITE)
		var ol := bg.lerp(Color(hb.empty_outline, 1.0), hb.empty_outline.a)
		_check(absf(ol.get_luminance() - bg.get_luminance()) >= 0.2, "L%d: the lost-heart outline stands out from the background (Δ%.2f)" % [n, absf(ol.get_luminance() - bg.get_luminance())])
		var full := bg.lerp(Palette.HEART, 1.0)
		var empty := bg.lerp(Color(hb.empty_color, 1.0), hb.empty_color.a)
		_check(_cdist(full, empty) >= 0.35, "L%d: a full heart and a lost one are far apart in color" % n)
	_done.append("themes")


static func _cdist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# --- D. Locked ------------------------------------------------------------------

func _refill() -> void:
	game.hearts = 3
	game.ui.set_hearts(3, 3)


func _locked() -> void:
	await _start(13)
	var id := _find("locked")
	_check(id >= 0, "L13 has a locked block")
	var v: BlockView = game.board.get_view(id)
	var keys: Array = game.model.key_blocks(id)
	var m0: int = game.mistakes
	game._on_block_tapped(id)
	await _frames(2)
	var color := String(game.model.blocks[id].lock_color).to_upper()
	var text: String = game.LOCKED_TEXT % color
	_check(game.last_feedback.get("kind") == "locked" and game.mistakes == m0 + 1 and game.hearts == 2, "a locked tap is still a mistake (one heart)")
	_check(v.lock_pop_active() and v._lock_pop > 0.0, "the padlock responds")
	_check(game.last_feedback.get("heart_chip"), "the lost heart rises from the locked block")
	_check(game.tutorial.is_showing() and game.tutorial._text == text, "the rule is explained: '%s'" % game.tutorial._text)
	_check(game.last_feedback.get("ringed") == -1, "a locked tap rings no blocker (it is not a blocked lane)")
	if not keys.is_empty():
		var kv: BlockView = game.board.get_view(keys[0])
		await _frames(3)
		_check(kv.scale.x > 1.0, "its key blocks still hop")
	await _wait(0.5)
	_check(not v.lock_pop_active() and v._lock_pop == 0.0, "the padlock beat ends (< 0.5 s) and leaves it at rest")
	# Tapped again while the rule is up: it stays up.
	_refill()
	game._on_block_tapped(id)
	await _frames(2)
	_check(game.tutorial.is_showing() and game.tutorial._text == text, "a second tap while the rule is up keeps it up")
	# Let it expire, then tap inside the cooldown: no repeat.
	await _wait(2.6)
	_check(not game.tutorial.is_showing(), "the rule hides by itself")
	_refill()
	game._on_block_tapped(id)
	await _frames(2)
	_check(not game.tutorial.is_showing() and game.last_feedback.get("kind") == "locked" and v.lock_pop_active(),
		"inside the %.0f s cooldown the padlock still responds but the text does not nag" % game.LOCKED_HINT_COOLDOWN)
	await _wait(game.LOCKED_HINT_COOLDOWN - 2.4)
	_refill()
	game._on_block_tapped(id)
	await _frames(2)
	_check(game.tutorial.is_showing() and game.tutorial._text == text, "after the cooldown the rule is explained again")
	_done.append("locked")


# --- E. Free taps ---------------------------------------------------------------

func _free_taps() -> void:
	for spec in [[8, "hidden"], [251, "crate"], [121, "gate"], [151, "armored"], [176, "twin_wait"]]:
		await _start(spec[0])
		var id := _find(spec[1])
		if id < 0:
			_check(false, "L%d has a '%s' block" % spec)
			continue
		var h: int = game.hearts
		var m0: int = game.mistakes
		var chips: int = game.board.heart_chips_shown
		var seq: int = game._feedback_seq
		game._on_block_tapped(id)
		await _frames(2)
		_check(game.hearts == h and game.mistakes == m0 and game.board.heart_chips_shown == chips and game._feedback_seq == seq,
			"L%d %s tap: free - no heart, no heart chip, no failure feedback" % spec)
	_done.append("free")


# --- F. Ambiguous blockers --------------------------------------------------------

func _ambiguous() -> void:
	# A Movable block that can't be pushed: blocked, but never ringed.
	var found := false
	for n in range(251, 301):
		await _start(n)
		var id := _find("blocked", func(i): return _straight_blocked(i) and game.model.find_blocker(i) != null and game.model.find_blocker(i).is_crate())
		if id < 0:
			continue
		found = true
		var h: int = game.hearts
		game._on_block_tapped(id)
		await _frames(2)
		_check(game.last_feedback.get("ringed") == -1 and _live_fx("ring").is_empty(), "L%d: a stuck Movable block is never ringed as the cause" % n)
		_check(game.hearts == h - 1, "L%d: ... and the blocked tap still costs its heart" % n)
		break
	_check(found, "a level with a block stuck behind a Movable block")
	# Portal: the far blocker keeps its ring.
	await _start(201)
	var pid := _find("blocked", func(i): return game.model.lane(i)["blocker"] != null and not game.model.lane(i)["via"].is_empty() and not game.model.lane(i)["blocker"].is_crate())
	if pid >= 0:
		game._on_block_tapped(pid)
		await _frames(2)
		_check(game.last_feedback.get("ringed") == game.model.lane(pid)["blocker"].id, "L201: the portal blocker is ringed")
	else:
		var sid := _find("blocked")
		game._on_block_tapped(sid)
		await _frames(2)
		_check(game.last_feedback.get("ringed") == game.model.find_blocker(sid).id, "L201: the blocker is ringed")
	# Twins: their own rings, nothing extra.
	found = false
	for n in range(176, 201):
		await _start(n)
		var tid := _find("blocked", func(i): return game.model.twin_partner(i) >= 0)
		if tid < 0:
			continue
		found = true
		game._on_block_tapped(tid)
		await _frames(2)
		_check(game.last_feedback.get("kind") == "blocked" and game.last_feedback.get("ringed") == -1 and game.last_feedback.get("heart_chip"),
			"L%d: a blocked twin keeps the twins' rings (no extra ring) and shows the heart" % n)
		break
	_check(found, "a level with a blocked twin")
	_done.append("ambiguous")


# --- G. No moves left -----------------------------------------------------------

## Escapes only (classic + spinners): a move path to a board that still
## has blocks but no playable one.
func _dead_path(m: BoardModel, path: Array, budget: Array) -> Array:
	budget[0] -= 1
	if budget[0] <= 0:
		return []
	var playable: Array = m.playable_ids()
	if playable.is_empty():
		return path if not m.is_empty() else []
	for id in playable:
		if m.move_state(id) != "ok":
			return []
		var snap := m.snapshot()
		m.remove(id)
		var r := _dead_path(m, path + [id], budget)
		m.restore(snap)
		if not r.is_empty():
			return r
	return []


func _no_moves() -> void:
	var level := -1
	var path := []
	for n in range(6, 100):
		await _start(n)
		if game.model.blocks.values().filter(func(b): return b.is_spinner()).is_empty():
			continue
		var m: BoardModel = game.model
		path = _dead_path(m, [], [4000])
		await _start(n)  # fresh board after the search
		if not path.is_empty():
			level = n
			break
	_check(level > 0, "found a spinner board that can run out of moves (L%d, %d moves)" % [level, path.size()])
	if level < 0:
		_done.append("no_moves")
		return
	if OS.get_cmdline_user_args().has("--verbose"):
		print("dead path L%d: %s" % [level, path])
	for id in path:
		game._on_block_tapped(id)
		await _frames(1)
	await _frames(4)
	_check(game.tutorial._text == "No moves left - tap Undo" and game.last_feedback.get("points_at") == "undo", "dead end with Undo available: 'tap Undo' (%s)" % game.tutorial._text)
	_check(game.ui._undo_button.scale.x > 1.0, "... and the Undo button pulses")
	# Use all three undos, landing in the dead end each time.
	for k in game.MAX_UNDOS:
		await _wait(0.9)
		game.undo()
		await _frames(2)
		game._on_block_tapped(path[-1])
		await _frames(4)
	_check(game.undos_used == game.MAX_UNDOS, "all undos used (%d)" % game.undos_used)
	_check(game.tutorial._text == "No moves left - tap Restart" and game.last_feedback.get("points_at") == "restart",
		"dead end with no Undo left: 'tap Restart' (%s)" % game.tutorial._text)
	_check(game.ui._restart_button.scale.x > 1.0 and is_equal_approx(game.ui._undo_button.scale.x, 1.0), "... the Restart button pulses, Undo does not")
	# Hint on a lost board with no Undo: same honest pointer.
	await _wait(1.0)
	game.progress.inventory["hint"] = 3
	game.request_hint()
	await _frames(2)
	_check(game.tutorial._text == "No moves left - tap Restart", "Hint on that board: 'tap Restart' (%s)" % game.tutorial._text)
	# Hint on a board that still has moves but can't be cleared.
	var hint_level := -1
	for n in range(6, 100):
		await _start(n)
		var m: BoardModel = game.model
		var first := -1
		for id in m.playable_ids():
			if m.move_state(id) != "ok":
				continue
			var snap := m.snapshot()
			m.remove(id)
			var bad: bool = not m.is_empty() and not m.playable_ids().is_empty() and not Solver.from_model(m).is_solvable()
			m.restore(snap)
			if bad:
				first = id
				break
		if first >= 0:
			game._on_block_tapped(first)
			await _frames(2)
			game.tutorial.hide_hint(true)
			game.progress.inventory["hint"] = 3
			game.request_hint()
			await _frames(2)
			hint_level = n
			_check(game.tutorial._text == "This board can't be cleared from here - tap Undo" and game.hint_block == -1,
				"L%d: Hint on a lost board that still has moves: '%s' (no hint spent)" % [n, game.tutorial._text])
			break
	_check(hint_level > 0, "found a board that can be lost with moves still left")
	_done.append("no_moves")


# --- H. Rapid taps --------------------------------------------------------------

func _rapid() -> void:
	await _start(3)
	var id := _find("blocked", _straight_blocked)
	var blocker: int = game.model.find_blocker(id).id
	for i in 6:
		game._on_block_tapped(id)
	await _frames(2)
	var rings := _live_fx("ring").filter(func(r): return r.position.distance_to(game.board.get_view(blocker).home) < 1.0)
	_check(rings.size() == 1, "6 rapid blocked taps: one ring on the blocker (%d)" % rings.size())
	await _wait(0.6)
	var v: BlockView = game.board.get_view(id)
	_check(v.position.distance_to(v.home) < 0.5 and game.board.get_view(blocker).position.distance_to(game.board.get_view(blocker).home) < 0.5,
		"... and both blocks settle home")
	await _start(13)
	var lid := _find("locked")
	for i in 3:
		_refill()
		game._on_block_tapped(lid)
		await _frames(1)
	_check(_live_fx("chip").size() == 1, "rapid locked taps: one heart chip at a time")
	var lv: BlockView = game.board.get_view(lid)
	await _wait(0.8)
	_check(not lv.lock_pop_active() and lv._lock_pop == 0.0 and lv.position.distance_to(lv.home) < 0.5, "... the padlock and block come to rest")
	_check(not game.ui._hearts.is_animating() and game.ui._hearts._fall_alpha.max() == 0.0 and game.ui._hearts._pop.max() == 1.0,
		"... the hearts bar comes to rest (no stuck pop or falling heart)")
	for b in [game.ui._undo_button, game.ui._restart_button]:
		for i in 4:
			game.ui._pulse(b)
	await _wait(1.0)
	_check(is_equal_approx(game.ui._undo_button.scale.x, 1.0) and is_equal_approx(game.ui._restart_button.scale.x, 1.0), "repeated button pulses end at rest size")
	_done.append("rapid")


# --- I. Rules and save ----------------------------------------------------------

func _rules_and_save() -> void:
	await _start(7)
	var id := _find("blocked", _straight_blocked)
	game._on_block_tapped(id)
	await _frames(2)
	_check(game.mistakes == 1 and game.hearts == 2 and game.chain == 0, "L7: one mistake, one heart, chain reset (rules as before)")
	var guard := 0
	while not game.completed and guard < 200:
		guard += 1
		var mv := Solver.from_model(game.model).recommend_move()
		if mv < 0:
			break
		game._on_block_tapped(mv)
		await _frames(1)
	_check(game.completed, "L7 cleared after the mistake")
	var r: Dictionary = game.last_result
	var expect := ScoreRules.settle({
		"escape_points": game.escape_points, "blocks": game._total_blocks,
		"hearts_left": game.hearts, "max_hearts": game.max_hearts,
		"mistakes": game.mistakes, "undos": game.undos_used, "hints": game.hints_used, "hammers": game.hammers_used})
	_check(r.get("score") == expect.get("score") and r.get("stars") == ScoreRules.stars(game.level, expect), "score and stars come from the unchanged ScoreRules (%s / %s)" % [r.get("score"), r.get("stars")])
	game.progress.save()
	var raw := FileAccess.get_file_as_string(SAVE)
	_check(raw != "" and not raw.contains("feedback") and not raw.contains("heart_chip"), "nothing new is written to the save")
	_done.append("rules")
