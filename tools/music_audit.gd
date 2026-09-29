extends Node
## Music regression audit (v0.6.3): drives the real game through every kind
## of music transition and samples both music players EVERY FRAME:
##   - silence: no music player playing while music is on (max gap)
##   - abrupt cut: a player stops while still audible (> -30 dB)
##   - restart: the same stream jumps back to the start
##   - players: never more than 2 playing (a cross-fade), 1 when settled
##   - settled: the right theme, full volume, Music bus not left ducked
##
##   godot --headless --path . res://tools/MusicAudit.tscn

const PROGRESS_PATH := "user://music_audit_progress.cfg"
const AUDIBLE_DB := -30.0

var game: GameManager
var failures: Array[String] = []
var _sampling := false
var _stats := {}


func _ready() -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH + suffix))
	PlayerProgress.default_path = PROGRESS_PATH
	GameManager.skip_title = true
	_run.call_deferred()


func _run() -> void:
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	AudioManager.set_music_enabled(true)
	game.start_level(1)
	await _wait(2.5)
	_settled("start (Level 1)", "c01")

	await _scenario("Chapter change 1 -> 11 (fade)", func(): game.start_level(11), "c02", 3.0)
	await _scenario("Era change 100 -> 101", func():
		game.start_level(100)
		await _wait(2.5)
		game.start_level(101), Chapters.theme_for_level(101)["music"], 3.0)
	await _scenario("Milestone 124 -> 125 -> 126", func():
		game.start_level(124)
		await _wait(2.5)
		game.start_level(125)
		await _wait(2.5)
		_check(AudioManager.music_theme == Chapters.theme_for_level(125)["music"], "milestone 125 plays its own music (%s)" % AudioManager.music_theme)
		game.start_level(126), Chapters.theme_for_level(126)["music"], 3.0)
	await _scenario("Master 199 -> 200", func():
		game.start_level(199)
		await _wait(2.5)
		game.start_level(200), "master2", 3.0)
	await _scenario("Rapid changes (0.2 s / 0.3 s apart) 21 -> 31 -> 41", func():
		game.start_level(21)
		await _wait(0.2)
		game.start_level(31)
		await _wait(0.3)
		game.start_level(41), Chapters.theme_for_level(41)["music"], 3.0)
	await _scenario("Change during the fade tail (0.65 s) 51 -> 61", func():
		game.start_level(51)
		await _wait(0.65)
		game.start_level(61), Chapters.theme_for_level(61)["music"], 3.0)
	await _scenario("Restart / replay x3 on 61 (same theme, no restart)", func():
		for i in 3:
			game.restart()
			await _wait(0.3)
			game.replay()
			await _wait(0.3), Chapters.theme_for_level(61)["music"], 2.0, true)
	await _scenario("Focus regained during a fade 61 -> 71", func():
		game.start_level(71)
		await _wait(0.3)
		AudioManager.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN), Chapters.theme_for_level(71)["music"], 3.0)
	await _scenario("Level-complete duck, then a Chapter change", func():
		AudioManager.duck_music()
		await _wait(0.3)
		game.start_level(81), Chapters.theme_for_level(81)["music"], 3.5)
	await _scenario("Music off and on during a fade 81 -> 91", func():
		game.start_level(91)
		await _wait(0.3)
		AudioManager.set_music_enabled(false)
		await _wait(0.3)
		AudioManager.set_music_enabled(true), Chapters.theme_for_level(91)["music"], 3.0, false, true)
	await _scenario("Level Select open/close, then pick a level in another Chapter", func():
		game.open_level_select()
		await _wait(0.4)
		game.ui._level_select.close()
		await _wait(0.3)
		game.start_level(150), Chapters.theme_for_level(150)["music"], 3.0)

	# Relaunch: a fresh game instance keeps exactly one music player going
	# with the Chapter theme of the level it continues.
	game.queue_free()
	await _frames(3)
	game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(5)
	game.start_level(150)
	await _wait(2.5)
	_settled("relaunch -> Level 150", Chapters.theme_for_level(150)["music"])

	if failures.is_empty():
		print("MUSIC AUDIT PASSED")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		print("MUSIC AUDIT FAILED (%d)" % failures.size())
		get_tree().quit(1)


## Runs `action` while sampling every frame, then waits `settle` seconds and
## checks the settled state. `same_theme`: the stream must never restart.
## `music_toggled`: silence is expected while music is switched off.
func _scenario(label: String, action: Callable, theme: String, settle: float, same_theme := false, music_toggled := false) -> void:
	_stats = {"max_players": 0, "max_silence": 0.0, "silence": 0.0, "cuts": 0, "restarts": 0, "last": {}}
	_sampling = true
	_sample_loop()
	await action.call()
	await _wait(settle)
	_sampling = false
	await _frames(2)
	var s := _stats
	print("[Music] %-58s players<=%d  longest silence %.2fs  abrupt cuts %d  restarts %d  -> %s" % [label, s["max_players"], s["max_silence"], s["cuts"], s["restarts"], AudioManager.music_theme])
	_check(s["max_players"] <= 2, "%s: at most 2 music players at once (%d)" % [label, s["max_players"]])
	if not music_toggled:
		_check(s["max_silence"] < 0.15, "%s: no silence gap (longest %.2fs)" % [label, s["max_silence"]])
	_check(s["cuts"] == 0, "%s: no audible track stopped abruptly (%d)" % [label, s["cuts"]])
	if same_theme:
		_check(s["restarts"] == 0, "%s: the theme kept playing, never restarted (%d)" % [label, s["restarts"]])
	else:
		_check(s["restarts"] <= 0, "%s: no track restarted mid-play (%d)" % [label, s["restarts"]])
	_settled(label, theme)


func _settled(label: String, theme: String) -> void:
	var bus := AudioServer.get_bus_index("Music")
	_check(AudioManager.music_theme == theme, "%s: theme %s (got %s)" % [label, theme, AudioManager.music_theme])
	_check(AudioManager.music_playing_count() == 1, "%s: exactly one music player playing (%d)" % [label, AudioManager.music_playing_count()])
	_check(AudioManager._music.playing and AudioManager._music.stream == AudioManager._theme_stream(theme), "%s: the active player plays %s" % [label, theme])
	_check(absf(AudioManager._music.volume_db - AudioManager.MUSIC_VOLUME_DB) < 0.5, "%s: full music volume (%.1f dB)" % [label, AudioManager._music.volume_db])
	_check(absf(AudioServer.get_bus_volume_db(bus)) < 0.1, "%s: Music bus not left ducked (%.1f dB)" % [label, AudioServer.get_bus_volume_db(bus)])


func _sample_loop() -> void:
	var t := 0.0
	var prev := {}
	while _sampling:
		var dt := get_process_delta_time()
		await get_tree().process_frame
		t += dt
		var playing := 0
		var now := {}
		for p in [AudioManager._music, AudioManager._music_b]:
			now[p] = [p.playing, p.volume_db, p.stream, p.get_playback_position()]
			if p.playing:
				playing += 1
			if prev.has(p):
				var was: Array = prev[p]
				# Stopped while audible (a fade ends below -30 dB).
				if was[0] and not p.playing and was[1] > AUDIBLE_DB and AudioManager.music_enabled:
					_stats["cuts"] += 1
				# Same stream jumped back (a restart), not a loop wrap.
				if was[0] and p.playing and was[2] == p.stream and p.get_playback_position() + 0.05 < was[3] and was[3] < (p.stream.get_length() - 0.5 if p.stream else 0.0):
					_stats["restarts"] += 1
		prev = now
		_stats["max_players"] = maxi(_stats["max_players"], playing)
		if playing == 0 and AudioManager.music_enabled:
			_stats["silence"] += dt
			_stats["max_silence"] = maxf(_stats["max_silence"], _stats["silence"])
		else:
			_stats["silence"] = 0.0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
