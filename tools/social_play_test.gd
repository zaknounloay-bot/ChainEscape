extends Node
## Social MVP 0.2B: generate -> play -> complete -> reveal, with the exact
## puzzle rebuilt from its serialized PuzzleDefinition, and Classic kept
## untouched throughout.
##
##   godot --headless --path . res://tools/SocialPlayTest.tscn
##   (xvfb-run godot --path . --resolution 390x844 res://tools/SocialPlayTest.tscn -- --shots=/tmp/p
##    saves screenshots; needs a real renderer)

const PROGRESS_PATH := "user://social_play_test_progress.cfg"

var game: GameManager
var social: SocialScreen
var cr: RevealCreator
var play: SocialPlay
var failures: Array[String] = []
var shots_dir := ""
var _wide: PackedByteArray
var _tall: PackedByteArray


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.get_slice("=", 1)
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	SocialConfig.api_url_override = "off"  # local flow (no network in this test)
	_run.call_deferred()


func _run() -> void:
	_wide = _jpeg(1600, 900, Color("#E8703A"))
	_tall = _jpeg(900, 1600, Color("#3A7BE8"))
	# M, N-Q: generator + exact reconstruction (no UI).
	_test_generation()
	# A Classic player mid-level: levels 1-12 cleared, playing 13 with one
	# move made (Y / Z: this board must survive Social play untouched).
	GameManager.skip_title = true
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(false)
	for n in range(1, 13):
		game.progress.record_result(n, 1000 + n, 3)
	game.progress.coins = 77
	game.progress.save()
	game.start_level(13)
	await _frames(3)
	for id in game.model.blocks:
		if game.model.move_state(id) == "ok":
			game.board.block_tapped.emit(id)
			break
	await _wait(1.0)
	var classic_board := _classic_board()
	_check(game.history.size() == 1, "Classic level 13 has one move made")
	var before := _snapshot()
	var file_before := FileAccess.get_file_as_string(PROGRESS_PATH)
	# Settings > MAIN MENU -> title -> CREATE CHALLENGE (as a player would).
	game.return_to_main_menu()
	await _frames(3)
	social = game.ui._title._social
	cr = social.creator
	play = social.play
	social.open(game.ui.theme)
	await _frames(3)

	await _test_play_matrix()
	await _test_exit_before_completion()
	await _test_play_again()
	await _test_reconstruct_through_play()

	# T-X: nothing of the campaign changed; Y-Z: the Classic board is intact.
	social.close()
	await _frames(3)
	_check(_snapshot() == before, "Social play left score, coins, stars, unlocks and current level unchanged")
	_check(FileAccess.get_file_as_string(PROGRESS_PATH) == file_before, "Social play did not write the Classic save")
	_check(game.ui.is_title_open() and game.ui._title._continue.text == "CONTINUE  -  LEVEL 13", "title still offers CONTINUE - LEVEL 13")
	_check(_classic_board() == classic_board and game.history.size() == 1 and game.current_level == 13,
			"the unfinished Classic board (with its move) is exactly as it was")
	game.continue_game()
	await _frames(3)
	_check(not game.ui.is_title_open() and _classic_board() == classic_board, "CONTINUE resumes that same Classic board")
	_check(play.board != game.board and not play.is_active(), "Social play never used the Classic board")
	print("SOCIAL PLAY TEST: %s" % ("PASSED" if failures.is_empty() else "FAILED"))
	for f in failures:
		printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


# --- M, N-Q: generation and exact reconstruction ------------------------------------

func _test_generation() -> void:
	var bands := {}
	for d in SocialGenerator.SPECS:
		var diffs := []
		var sizes := []
		for i in 6:
			var g := SocialGenerator.new(d, 1000 + i * 7919)
			var p := g.run()
			_check(p != null and p.verify(), "%s #%d: a verified, solvable puzzle (%s)" % [d, i, g.error])
			if p == null:
				continue
			diffs.append(g.metrics["difficulty"])
			sizes.append(p.to_json().to_utf8_buffer().size())
			# Determinism: the same seed builds the same puzzle.
			_check(SocialGenerator.new(d, 1000 + i * 7919).run().fingerprint() == p.fingerprint(), "%s #%d: same seed, same puzzle" % [d, i])
		bands[d] = diffs
		print("generation %s: difficulty %s bytes %s" % [d, diffs, sizes])
	_check(bands["easy"].max() < bands["medium"].min() and bands["medium"].max() < bands["hard"].min(),
			"EASY < MEDIUM < HARD with no overlap (%s)" % str(bands))
	# N-Q: creator -> canonical JSON only -> destroy -> rebuild -> identical.
	for d in ["easy", "medium", "hard"]:
		var creator_def := SocialGenerator.new(d, 777).run()
		var creator_level := creator_def.to_level()
		var creator_model := BoardModel.new()
		creator_model.setup(creator_level.rows, creator_level.columns, creator_level.blocks)
		var creator_blocks := _blocks(creator_model)
		var creator_solution := Solver.from_model(creator_model).solve_moves()
		var wire := creator_def.to_json()  # the only thing that travels
		creator_def = null
		creator_level = null
		creator_model = null
		var r := PuzzleDefinition.from_json(wire)
		_check(r != null and r.verify(), "%s: rebuilt from JSON alone and verified" % d)
		var rl := r.to_level()
		var rm := BoardModel.new()
		rm.setup(rl.rows, rl.columns, rl.blocks)
		_check(_blocks(rm) == creator_blocks, "%s: every block identical (cell, color, arrow, spinner rule, hidden, lock, reward, switch, gate, armor)" % d)
		_check(Solver.from_model(rm).solve_moves() == creator_solution and not creator_solution.is_empty(), "%s: same solution" % d)
		for mv in creator_solution:
			rm.remove(mv & Solver.ID_MASK)
		_check(rm.is_empty(), "%s: the creator's solution clears the rebuilt board" % d)
	# Malformed or future data is refused, never guessed.
	var good := SocialGenerator.new("easy", 3).run().to_dict()
	for bad in [{}, {"format": "ce-puzzle", "v": 2}, _with(good, "rules", 99), _with(good, "rows", 3), _with(good, "map", ["R> ??"])]:
		var p := PuzzleDefinition.from_dict(bad)
		_check(p == null or not p.verify(), "bad puzzle data refused (%s)" % str(bad).left(40))
	var c := SharedChallenge.photo_message_reveal(_session("Hi", false, "easy"), SocialGenerator.new("easy", 4).run())
	var back := SharedChallenge.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	_check(back != null and back.puzzle.fingerprint() == c.puzzle.fingerprint() and back.message() == "Hi" and back.type == "photo_message_reveal",
			"SharedChallenge round-trips through JSON (puzzle + type + payload)")
	_check(not JSON.stringify(c.to_dict()).contains("local_photo") and c.to_dict()["payload"].has("photo"), "photo bytes never serialized, only described")


func _with(d: Dictionary, k: String, v) -> Dictionary:
	var o := d.duplicate(true)
	o[k] = v
	return o


# --- A-L: create -> play -> reveal for each case --------------------------------------

func _test_play_matrix() -> void:
	var cases := [
		["A photo+message easy", "Happy Birthday!", "wide", "easy"],
		["B photo+message medium", "Joyeux anniversaire! Très belle journée.", "tall", "medium"],
		["C photo+message hard", "Happy Birthday أحمد", "wide", "hard"],
		["D photo only", "", "tall", "easy"],
		["E message only", "Happy Birthday!", "", "easy"],
		["G Hebrew", "מזל טוב! יום הולדת שמח", "", "easy"],
		["H Arabic", "كل عام وأنت بخير", "", "easy"],
		["I mixed", "מזל טוב Loay", "", "easy"],
		["J long + portrait", ("Happy birthday to the best friend anyone could ask for! " .repeat(4)).left(200), "tall", "easy"],
		["J long message only", ("كل عام وأنت بخير يا أغلى الناس، أتمنى لك سنة مليئة بالفرح والنجاح والصحة. " .repeat(4)).left(200), "", "easy"],
	]
	for k in cases.size():
		var cs: Array = cases[k]
		await _create_and_play(cs[1], cs[2], cs[3], 100 + k)
		var name: String = cs[0]
		_check(play.is_active() and play.challenge.difficulty == cs[3], "%s: challenge playing" % name)
		_check(play._title.text == "REVEAL CHALLENGE" and play._chip.text == cs[3].to_upper(), "%s: labelled REVEAL CHALLENGE / %s (no level number)" % [name, cs[3].to_upper()])
		_check(play.model.block_count() == play.challenge.puzzle.block_count(), "%s: the board is the challenge's puzzle" % name)
		_check(play._bottom.find_child("Hammer", false, false) == null, "%s: no Hammer / hearts in Social play" % name)
		if k == 0:
			await _test_real_taps()
			await _shot("p1_play_easy")
		await _solve()
		await _wait(0.95)
		if k == 0:
			await _shot("p2_reveal_chain")
		await _wait(1.3)
		var rv := play.reveal
		_check(rv.visible, "%s: solving shows the reveal" % name)
		var photo: bool = cs[2] != ""
		var msg: bool = cs[1] != ""
		_check(rv._photo_frame.visible == photo and rv._message_card.visible == msg, "%s: shows exactly what was hidden (photo %s, message %s)" % [name, photo, msg])
		if photo:
			var img := Vector2(1600, 900) if cs[2] == "wide" else Vector2(900, 1600)
			var sz := rv._photo.custom_minimum_size
			_check(absf(sz.x / sz.y - img.x / img.y) < 0.02, "%s: photo aspect kept (%s)" % [name, sz])
		if msg:
			_check(rv._message.text == cs[1] and rv._message.get_theme_font("font") == MessageText.font(), "%s: message shown with the multilingual font" % name)
			_check(rv._message.get_visible_line_count() == rv._message.get_line_count(), "%s: the whole message is visible" % name)
		var vis := get_viewport().get_visible_rect()
		for n: Control in [rv._again, rv._back, rv._photo_frame, rv._message_card, rv._heading]:
			if n.visible:
				_check(vis.encloses(n.get_global_rect()), "%s: %s on screen (%s)" % [name, n.name, n.get_global_rect()])
		await _shot("p3_reveal_%d" % k)
		await _tap(rv._back)
		_check(social.page == SocialScreen.Page.CHOICE and not play.is_active(), "%s: BACK TO CREATE CHALLENGE returns to the choice screen" % name)


## Real touch events on the Social board (the phone path), and a touch on
## an empty spot does nothing.
func _test_real_taps() -> void:
	await _wait(0.6)
	var count := play.model.block_count()
	var target := -1
	for id in play.model.blocks:
		if play.model.move_state(id) == "ok":
			target = id
			break
	var classic_before := _classic_board()
	await _touch(play.board.block_screen_position(target))
	_check(play.model.block_count() == count - 1 and not play.model.blocks.has(target), "a real touch on a free block makes it escape")
	_check(_classic_board() == classic_before, "the touch did not reach the Classic board underneath")
	await _wait(0.5)
	await _tap(play._undo)
	_check(play.model.block_count() == count, "UNDO puts it back")


# --- S: leaving before the end ---------------------------------------------------------

func _test_exit_before_completion() -> void:
	await _create_and_play("Secret message", "wide", "medium", 300)
	play.play_solver_move()
	await _wait(0.4)
	await _tap(play._exit)
	_check(play._confirm.visible and not play.reveal.visible, "EXIT asks first (reveal still hidden)")
	await _shot("p4_leave_confirm")
	await _tap(play._confirm.find_child("KeepPlaying", true, false))
	_check(play.is_active() and not play._confirm.visible, "KEEP PLAYING returns to the board")
	await _tap(play._exit)
	await _tap(play._confirm.find_child("Leave", true, false))
	_check(not play.is_active() and not play.reveal.visible, "LEAVE ends the challenge without revealing anything")
	_check(cr.visible and cr.step == RevealCreator.Step.REVIEW and cr.session.message == "Secret message" and cr.session.has_photo()
			and cr.session.difficulty == "medium", "back on the review with photo, message and difficulty kept")
	# Without a backend (local mode), CREATE again plays again, as in 0.2B.
	await _tap(_cnode("Create"))
	var t0 := Time.get_ticks_msec()
	while not play.is_active() and Time.get_ticks_msec() - t0 < 20000:
		await _frames(1)
	_check(play.is_active(), "local mode: CREATE again after leaving starts a challenge")
	await _wait(0.3)
	await _tap(play._exit)
	await _tap(play._confirm.find_child("Leave", true, false))
	_check(cr.step == RevealCreator.Step.REVIEW, "and leaving it returns to the review again")
	await _tap(_cnode("Back"))
	await _tap(_cnode("Back"))
	await _tap(_cnode("Back"))
	await _tap(_cnode("Back"))
	await _tap(_cnode("Back"))
	_check(social.page == SocialScreen.Page.CHOICE, "BACK steps out to the choice screen")


# --- R: PLAY AGAIN = the exact same puzzle ------------------------------------------

func _test_play_again() -> void:
	await _create_and_play("Again!", "", "hard", 400)
	var fp := play.loaded_fingerprint
	var first := _blocks(play.model)
	await _solve()
	await _wait(2.4)
	_check(play.reveal.visible, "hard challenge solved and revealed")
	await _tap(play.reveal._again)
	await _wait(0.4)
	_check(play.is_active() and not play.reveal.visible and play.plays == 2, "PLAY AGAIN starts over")
	_check(play.loaded_fingerprint == fp and _blocks(play.model) == first, "PLAY AGAIN rebuilt the exact same puzzle from its data")
	await _shot("p5_play_again")
	await _solve()
	await _wait(2.4)
	_check(play.reveal.visible, "solved again, revealed again")
	await _tap(play.reveal._back)


## N (through the real player): creator's instance -> JSON -> destroyed ->
## a brand-new SocialPlay built from the JSON alone shows the same board.
func _test_reconstruct_through_play() -> void:
	for d in ["easy", "medium", "hard"]:
		var def := SocialGenerator.new(d, 555).run()
		var c := SharedChallenge.photo_message_reveal(_session("x", false, d), def)
		var a := SocialPlay.new()
		get_tree().root.add_child(a)
		await _frames(1)
		a.start(c, SocialPlay.Mode.CREATOR_PREVIEW, game.ui.theme)
		var creator_blocks := _blocks(a.model)
		var wire := JSON.stringify(c.to_dict())
		a.end()
		a.queue_free()
		c = null
		await _frames(2)
		var got := SharedChallenge.from_dict(JSON.parse_string(wire))
		var b := SocialPlay.new()
		get_tree().root.add_child(b)
		await _frames(1)
		b.start(got, SocialPlay.Mode.RECIPIENT, game.ui.theme)
		_check(_blocks(b.model) == creator_blocks and b.board.rows == def.rows and b.board.columns == def.columns,
				"%s: a new player built from the transferred data shows the identical board" % d)
		b.end()
		b.queue_free()
		await _frames(1)


# --- Helpers ------------------------------------------------------------------------

func _create_and_play(message: String, photo: String, difficulty: String, seed_value: int) -> void:
	if social.page != SocialScreen.Page.CHOICE:
		social.show_page(SocialScreen.Page.CHOICE)
	await _tap(social._pages[SocialScreen.Page.CHOICE].find_child("Card_Photo", true, false))
	if photo != "":
		cr.receive_photo(_wide if photo == "wide" else _tall)
		await _wait(0.3)
		await _tap(_cnode("UsePhoto"))
	else:
		await _tap(_cnode("SkipPhoto"))
	await _wait(0.3)
	if message != "":
		cr._message_edit.text = message
		await _frames(2)
		await _tap(_cnode("Continue"))
	else:
		await _tap(_cnode("SkipMessage"))
	await _tap(_cnode("Difficulty_" + difficulty))
	await _tap(_cnode("Continue"))
	cr.debug_seed = seed_value
	await _tap(_cnode("Create"))
	var t0 := Time.get_ticks_msec()
	while not play.is_active() and Time.get_ticks_msec() - t0 < 20000:
		await _frames(1)
	_check(play.is_active(), "challenge generated and started (%s, %s)" % [difficulty, message.left(12)])
	await _wait(0.3)


func _session(message: String, photo: bool, difficulty: String) -> CreatorSession:
	var s := CreatorSession.new()
	s.set_message(message)
	s.set_difficulty(difficulty)
	if photo:
		s.set_photo_jpeg(_wide)
	return s


func _solve() -> void:
	var guard := 0
	while play.play_solver_move() and guard < 80:
		guard += 1
		await _wait(0.1)
	_check(play.completed, "the Solver's moves clear the board")


func _blocks(m: BoardModel) -> Array:
	var out := []
	var ids := m.blocks.keys()
	ids.sort()
	for id in ids:
		var b: BlockData = m.blocks[id]
		out.append([b.id, b.cell, b.color, b.direction, b.kind, b.spin_rule, b.hidden, b.lock_color, b.rarity,
			b.switch_group, b.flip_link, b.gate_group, b.gate_link, b.armored])
	return out


func _classic_board() -> String:
	return var_to_str([game.current_level, _blocks(game.model), game.board.fx_count() >= 0])


func _snapshot() -> String:
	var p := game.progress
	return var_to_str([p.coins, p.best_scores, p.best_stars, p.highest_unlocked, p.highest_completed,
		p.current_level, p.inventory, p.total_score(), p.total_stars(), p.tips_seen, p.achievements])


func _cnode(n: String) -> Control:
	var c: Control = cr._steps[cr.step].find_child(n, true, false)
	_check(c != null and c.is_visible_in_tree(), "step %d: %s visible" % [cr.step, n])
	return c


func _jpeg(w: int, h: int, col: Color) -> PackedByteArray:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(col)
	img.fill_rect(Rect2i(w / 4, h / 4, w / 2, h / 2), Color.WHITE)
	return img.save_jpg_to_buffer(0.85)


## Button press through the GUI (as the smoke test does).
func _tap(c: Control) -> void:
	if c == null:
		_check(false, "tap target missing")
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = c.get_global_rect().get_center()
	ev.global_position = ev.position
	ev.pressed = true
	get_tree().root.push_input(ev, true)
	await _frames(1)
	var up := ev.duplicate()
	up.pressed = false
	get_tree().root.push_input(up, true)
	await _wait(0.3)


## A finger on the screen (InputEventScreenTouch, like a phone).
func _touch(at: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.position = at
	ev.pressed = true
	get_tree().root.push_input(ev, true)
	await _frames(1)
	var up := ev.duplicate()
	up.pressed = false
	get_tree().root.push_input(up, true)
	await _frames(2)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await _frames(2)
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_tree().root.get_texture().get_image().save_png("%s/%s.png" % [shots_dir, name])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
