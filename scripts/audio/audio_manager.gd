extends Node
## Global audio hub (autoload "AudioManager").
##
## Two buses are created at startup: "Music" and "SFX", so each can be
## toggled (Settings) and the music can be ducked under big moments.
##
## Gameplay code only calls semantic hooks (`play_escape(chain)`,
## `play_invalid()`, ...). Each hook maps to a sound id. At startup every id
## looks for a real asset at res://assets/audio/<id>.ogg|.wav and falls back
## to a small synthesized placeholder, so final audio can be dropped in later
## without touching code.

const SOUND_IDS := ["escape", "invalid", "combo", "level_complete", "ui_tap", "undo",
	"turn", "heart_lost", "hint", "try_again", "unlock", "reveal", "star", "perfect", "new_best",
	"coin", "hammer", "chest", "master", "world"]
const MUSIC_ID := "music"
const MUSIC_VOLUME_DB := -15.0  # background level: present but never in the way
const DUCK_DB := -8.0  # extra attenuation while ducked
const ASSET_DIR := "res://assets/audio/"
const MIX_RATE := 44100
const VOICES := 8

## Major pentatonic steps in semitones: consecutive escapes climb a pleasant
## scale instead of a plain linear pitch ramp.
const CHAIN_SCALE := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]

## Sound effects on/off (Settings). Music has its own switch.
signal audio_unlocked

var sfx_enabled: bool = true
var music_enabled: bool = true
## Web browsers block audio until a user gesture. When true, music waits
## for the first tap/click/key (see _input). Always true on the web build;
## tests can set it to simulate a browser.
var require_gesture: bool = OS.has_feature("web")
var unlocked: bool = false
## Music theme currently requested ("w1".."w5", "master").
var music_theme: String = "w1"
var _music: AudioStreamPlayer  # the active player
var _music_b: AudioStreamPlayer  # the other one, for cross-fades
var _fade_tween: Tween
var _duck_tween: Tween
var _theme_streams: Dictionary = {}
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	unlocked = not require_gesture
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for id in SOUND_IDS:
		_streams[id] = _load_or_synthesize(id)
	for k in 2:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.volume_db = MUSIC_VOLUME_DB
		add_child(mp)
		if k == 0:
			_music = mp
		else:
			_music_b = mp
	_music.stream = _theme_stream(music_theme)
	_init_web_audio()


func _exit_tree() -> void:
	# Release the looping streams cleanly on quit.
	for mp in [_music, _music_b]:
		mp.stop()
		mp.stream = null


## Web audio unlock (iOS Safari first).
##
## The real unlock happens in JavaScript (web/audio_unlock.js, injected into
## the page head): it runs synchronously inside the browser's own touchend /
## click / keydown event, which is the only place iOS Safari accepts it.
## Godot's input events arrive a frame later, outside that gesture, so the
## game never tries to unlock from here - it only POLLS the context state
## and starts music / allows SFX once the context reports "running".
## If the page has no bridge (old export), it falls back to unlocking on the
## first gesture as before.
var _web: bool = OS.has_feature("web")
var _bridge: bool = false
var _gesture_seen: bool = false
var _poll_timer := 0.0
var _last_ctx_state := ""
## Sound effects actually sent to a player (for tests / diagnostics).
var sfx_played: int = 0
var _audio_test: bool = false
var _logged_sfx_dropped: bool = false
## TEMPORARY: extra [CE-Audio] logging on web builds (console + ?audiodebug overlay).
var web_audio_debug: bool = true


func _init_web_audio() -> void:
	if not _web:
		return
	_bridge = str(JavaScriptBridge.eval("typeof window.ceAudio")) == "object"
	var search := str(JavaScriptBridge.eval("location.search"))
	_audio_test = search.contains("audiotest")
	_wlog("Godot audio: bridge=%s platform=%s music=%s sfx=%s" % [_bridge,
		str(JavaScriptBridge.eval("window.ceAudio ? window.ceAudio.platform : navigator.userAgent")),
		"ON" if music_enabled else "OFF", "ON" if sfx_enabled else "OFF"])
	# Web playback runs as STREAM (project setting
	# audio/general/default_playback_type.web = Stream): Godot mixes and
	# feeds one Web Audio node, the long-proven path on iOS Safari. Godot's
	# default for Web is SAMPLE (each sound a Web Audio buffer), which has
	# open iOS WebKit bugs. TEMPORARY A/B switch for device testing:
	# ?audiomode=sample (or =stream) overrides every player.
	var forced := ""
	if search.contains("audiomode=sample"):
		forced = "SAMPLE"
		for p in _players + [_music, _music_b]:
			p.playback_type = AudioServer.PLAYBACK_TYPE_SAMPLE
	elif search.contains("audiomode=stream"):
		forced = "STREAM"
		for p in _players + [_music, _music_b]:
			p.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_wlog("playback type: %s (project default for Web: %s)" % [
		forced + " (forced by URL)" if forced != "" else playback_type_name(),
		"STREAM" if int(ProjectSettings.get_setting("audio/general/default_playback_type.web", 1)) == 0 else "SAMPLE"])


## Effective playback type of the music player (web diagnostics).
func playback_type_name() -> String:
	match _music.playback_type:
		AudioServer.PLAYBACK_TYPE_STREAM: return "STREAM"
		AudioServer.PLAYBACK_TYPE_SAMPLE: return "SAMPLE"
	return "STREAM" if int(ProjectSettings.get_setting("audio/general/default_playback_type.web", 1)) == 0 else "SAMPLE"


func _wlog(msg: String) -> void:
	if not (_web and web_audio_debug):
		return
	print("[CE-Audio] " + msg)
	if _bridge:
		JavaScriptBridge.eval("window.ceAudio.log(%s)" % JSON.stringify("(godot) " + msg), true)


func _input(event: InputEvent) -> void:
	if unlocked:
		return
	var gesture: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed)
	if not gesture:
		return
	if not _gesture_seen:
		_gesture_seen = true
		_wlog("user gesture received by Godot (context: %s)" % _ctx_state())
	if not _bridge:
		unlock_audio()  # desktop / old export fallback


func _page_gestures() -> int:
	return int(JavaScriptBridge.eval("window.ceAudio.gestures()"))


func _ctx_state() -> String:
	if not _bridge:
		return "n/a"
	return str(JavaScriptBridge.eval("window.ceAudio.state()"))


## Web builds publish their audio state to the page (window.chainEscapeAudio)
## so automated browser tests - and curious developers - can check it.
func _publish_web_state() -> void:
	if not _web:
		return
	JavaScriptBridge.eval("window.chainEscapeAudio = {unlocked: %s, musicPlaying: %s, theme: '%s', musicEnabled: %s, sfxEnabled: %s, context: '%s', sfxPlayed: %d};" % [
		str(unlocked).to_lower(), str(_music.playing).to_lower(), music_theme, str(music_enabled).to_lower(),
		str(sfx_enabled).to_lower(), _ctx_state(), sfx_played], true)


var _publish_timer := 0.0


func _process(delta: float) -> void:
	if not _web:
		return
	_poll_timer += delta
	if _bridge and _poll_timer >= 0.15:
		_poll_timer = 0.0
		var state := _ctx_state()
		if state != _last_ctx_state:
			_wlog("AudioContext state: %s" % state)
			_last_ctx_state = state
		# Some browsers create the context already "running" (e.g. high media
		# engagement); still wait for a real user gesture before any sound.
		if state == "running" and not unlocked and _page_gestures() > 0:
			unlock_audio()
	_publish_timer += delta
	if _publish_timer >= 0.5:
		_publish_timer = 0.0
		_publish_web_state()


## Audio is usable: start music (if ON) and allow SFX (if ON). Runs once;
## later taps never restart music.
func unlock_audio() -> void:
	if unlocked:
		return
	unlocked = true
	_wlog("audio unlocked (context: %s)" % _ctx_state())
	audio_unlocked.emit()
	start_music()
	_wlog("music: %s" % ("started (theme %s, playing=%s)" % [music_theme, _music.playing] if music_enabled else "OFF in settings - not started"))
	_wlog("sound effects: %s" % ("enabled" if sfx_enabled else "OFF in settings"))
	if _audio_test:
		_run_audio_test()
	_publish_web_state()


## TEMPORARY (?audiotest=1): one short, quiet test through Web Audio
## directly, then one through Godot's SFX path, to prove audio is live.
func _run_audio_test() -> void:
	if _bridge:
		JavaScriptBridge.eval("window.ceAudio.testTone()", true)
	await get_tree().create_timer(0.4).timeout
	if sfx_enabled:
		play("coin", 1.0, -6.0)
		var t0 := float(str(JavaScriptBridge.eval("window.ceAudio ? window.ceAudio.time() : -1")))
		await get_tree().create_timer(0.3).timeout
		var t1 := float(str(JavaScriptBridge.eval("window.ceAudio ? window.ceAudio.time() : -1")))
		_wlog("SFX test: Godot 'coin' played; audio clock %.2f -> %.2f (%s)" % [t0, t1, "advancing" if t1 > t0 else "NOT advancing"])
	else:
		_wlog("SFX test skipped: Sound Effects are OFF in settings")


func _notification(what: int) -> void:
	# Coming back to the tab / app: make sure the loop is still running.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		_wlog("app focus/resume: context %s" % _ctx_state())
		start_music()


# --- Settings ----------------------------------------------------------------

func set_sfx_enabled(on: bool) -> void:
	sfx_enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not on)


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
	if on:
		start_music()
	else:
		_music.stop()
		_music_b.stop()


# --- Music -----------------------------------------------------------------

func is_music_playing() -> bool:
	return _music.playing


## Starts the current theme if allowed (music on, audio unlocked).
func start_music() -> void:
	if not music_enabled or not unlocked:
		return
	if _music.stream and not _music.playing:
		_music.volume_db = MUSIC_VOLUME_DB
		_music.play()
		if _web:
			_wlog("music play attempt: theme %s (%s, context %s) -> playing=%s" % [music_theme, playback_type_name(), _ctx_state(), _music.playing])


## Switches the music theme with a smooth cross-fade (World changes).
func set_music_theme(theme: String, fade: float = 1.5) -> void:
	if theme == music_theme and _music.stream != null:
		start_music()
		return
	music_theme = theme
	var stream := _theme_stream(theme)
	if not music_enabled or not unlocked or not _music.playing:
		_music.stream = stream
		start_music()
		return
	if _fade_tween:
		_fade_tween.kill()
	var old := _music
	_music = _music_b
	_music_b = old
	_music.stream = stream
	_music.volume_db = -40.0
	_music.play()
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(_music, "volume_db", MUSIC_VOLUME_DB, fade).set_trans(Tween.TRANS_SINE)
	_fade_tween.tween_property(old, "volume_db", -40.0, fade).set_trans(Tween.TRANS_SINE)
	_fade_tween.chain().tween_callback(old.stop)


## Dips the music for `hold` seconds (e.g. under the level-complete jingle).
func duck_music(hold: float = 1.2) -> void:
	var bus := AudioServer.get_bus_index("Music")
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(db): AudioServer.set_bus_volume_db(bus, db),
			AudioServer.get_bus_volume_db(bus), DUCK_DB, 0.12)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(func(db): AudioServer.set_bus_volume_db(bus, db), DUCK_DB, 0.0, 0.8)


func _theme_stream(theme: String) -> AudioStream:
	if not _theme_streams.has(theme):
		_theme_streams[theme] = _load_music(MUSIC_ID + "_" + theme)
	return _theme_streams[theme]


func _load_music(id: String) -> AudioStream:
	var stream: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var path: String = ASSET_DIR + id + "." + ext
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream is AudioStreamWAV and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	return stream


# --- Gameplay hooks --------------------------------------------------------

func play_escape(chain: int) -> void:
	play("escape", chain_pitch(chain), -4.0)


func play_invalid() -> void:
	play("invalid", 1.0, -6.0)


## Called on chain milestones (x3, x5, x8...). Pitch follows the chain.
func play_combo(chain: int) -> void:
	play("combo", chain_pitch(chain - 2), -8.0)


func play_level_complete() -> void:
	duck_music(1.3)
	play("level_complete", 1.0, -3.0)


func play_ui_tap() -> void:
	play("ui_tap", 1.0, -10.0)


func play_undo() -> void:
	play("undo", 1.0, -8.0)


func play_turn() -> void:
	play("turn", 1.0, -9.0)


func play_heart_lost() -> void:
	play("heart_lost", 1.0, -5.0)


func play_hint() -> void:
	play("hint", 1.0, -6.0)


func play_try_again() -> void:
	play("try_again", 1.0, -5.0)


func play_unlock() -> void:
	play("unlock", 1.0, -4.0)


func play_reveal() -> void:
	play("reveal", 1.0, -6.0)


## Stars pop with rising pitch (index 0..2).
func play_star(index: int) -> void:
	play("star", pow(2.0, [0, 4, 7][clampi(index, 0, 2)] / 12.0), -5.0)


func play_perfect() -> void:
	duck_music(1.8)
	play("perfect", 1.0, -2.0)


func play_new_best() -> void:
	play("new_best", 1.0, -5.0)


func play_coin() -> void:
	play("coin", 1.0, -6.0)


func play_hammer() -> void:
	play("hammer", 1.0, -3.0)


func play_chest() -> void:
	play("chest", 1.0, -3.0)


func play_master() -> void:
	duck_music(2.8)
	play("master", 1.0, -1.0)


func play_world() -> void:
	play("world", 1.0, -5.0)


static func chain_pitch(chain: int) -> float:
	var idx := maxi(chain - 1, 0)
	if idx >= CHAIN_SCALE.size():
		# Past the top, keep a melody going in the upper octave instead of
		# repeating one note (long cascades like level 10).
		var top := 5
		idx = CHAIN_SCALE.size() - top + (idx - CHAIN_SCALE.size()) % top
	return pow(2.0, CHAIN_SCALE[idx] / 12.0)


# --- Core ------------------------------------------------------------------

func play(id: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	# Before the (web) audio unlock nothing may play: a suspended context
	# would otherwise queue sounds and burst them out on unlock.
	if not unlocked or not sfx_enabled or not _streams.has(id):
		if _web and not unlocked and not _logged_sfx_dropped:
			_logged_sfx_dropped = true
			_wlog("SFX '%s' requested before unlock - not played" % id)
		return
	sfx_played += 1
	if _web and sfx_played <= 3:
		_wlog("SFX play attempt #%d: '%s' (%s, context %s)" % [sfx_played, id, playback_type_name(), _ctx_state()])
	var p := _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	p.stream = _streams[id]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _load_or_synthesize(id: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path: String = ASSET_DIR + id + "." + ext
		if ResourceLoader.exists(path):
			return load(path)
	match id:
		"escape":
			# Bright pluck with a slight upward glide.
			return _synth([[660.0, 1.0], [1320.0, 0.25]], 0.16, 22.0, 0.25)
		"invalid":
			# Soft low "tock": clearly different, never harsh.
			return _synth([[200.0, 1.0], [300.0, 0.2]], 0.11, 38.0, -0.35)
		"combo":
			return _synth_notes([[988.0, 0.0], [1319.0, 0.06]], 0.28, 14.0)
		"level_complete":
			return _synth_notes([[523.0, 0.0], [659.0, 0.08], [784.0, 0.16], [1047.0, 0.26]], 0.8, 6.0)
		"ui_tap":
			return _synth([[1400.0, 1.0]], 0.04, 70.0, 0.0)
		"undo":
			return _synth([[700.0, 1.0], [1050.0, 0.2]], 0.12, 26.0, -0.3)
		"turn":
			# Short mechanical "tick-tock" for a spinner turning.
			return _synth_notes([[1600.0, 0.0], [1200.0, 0.045]], 0.12, 45.0)
		"heart_lost":
			# Soft descending two-note "oh no", not a buzzer.
			return _synth_notes([[587.0, 0.0], [440.0, 0.09]], 0.4, 9.0)
		"hint":
			return _synth_notes([[1175.0, 0.0], [1568.0, 0.07], [2093.0, 0.14]], 0.5, 10.0)
		"unlock":
			# Mechanical click, then a bright "open" chime.
			return _synth_notes([[1800.0, 0.0], [988.0, 0.06], [1480.0, 0.12]], 0.5, 12.0)
		"reveal":
			return _synth([[900.0, 1.0], [1800.0, 0.3]], 0.22, 14.0, 0.5)
		"star":
			return _synth_notes([[1319.0, 0.0], [2637.0, 0.0]], 0.35, 11.0)
		"perfect":
			return _synth_notes([[784.0, 0.0], [988.0, 0.07], [1175.0, 0.14], [1568.0, 0.21], [1976.0, 0.30], [2349.0, 0.40]], 1.2, 4.5)
		"new_best":
			return _synth_notes([[1047.0, 0.0], [1568.0, 0.1], [2093.0, 0.2]], 0.7, 7.0)
		"coin":
			return _synth_notes([[1976.0, 0.0], [2637.0, 0.05]], 0.3, 14.0)
		"hammer":
			# Heavy thud + crack.
			return _synth([[110.0, 1.0], [220.0, 0.5], [3300.0, 0.08]], 0.3, 16.0, -0.4)
		"chest":
			return _synth_notes([[659.0, 0.0], [831.0, 0.08], [988.0, 0.16], [1319.0, 0.24], [1976.0, 0.34]], 1.0, 5.0)
		"master":
			return _synth_notes([[523.0, 0.0], [659.0, 0.1], [784.0, 0.2], [1047.0, 0.3], [1319.0, 0.45], [1568.0, 0.6], [2093.0, 0.8]], 2.0, 2.5)
		"world":
			return _synth_notes([[392.0, 0.0], [587.0, 0.15], [784.0, 0.3]], 1.1, 3.5)
		"try_again":
			return _synth_notes([[523.0, 0.0], [466.0, 0.12], [392.0, 0.24]], 0.7, 6.0)
	return null


## Additive sine tone with exponential decay. `glide` bends pitch over time
## (0.25 = +25% by the end).
func _synth(partials: Array, length: float, decay: float, glide: float) -> AudioStreamWAV:
	var n := int(length * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phases := []
	phases.resize(partials.size())
	phases.fill(0.0)
	for i in n:
		var t := float(i) / MIX_RATE
		var env := exp(-t * decay) * minf(1.0, t * 400.0)  # tiny attack avoids clicks
		var bend := 1.0 + glide * (t / length)
		var s := 0.0
		for k in partials.size():
			phases[k] += TAU * partials[k][0] * bend / MIX_RATE
			s += sin(phases[k]) * partials[k][1]
		data.encode_s16(i * 2, int(clampf(s * env * 0.45, -1.0, 1.0) * 32767.0))
	return _wav(data)


## Several bell-like notes starting at different offsets (arpeggios).
func _synth_notes(notes: Array, length: float, decay: float) -> AudioStreamWAV:
	var n := int(length * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / MIX_RATE
		var s := 0.0
		for note in notes:
			var lt: float = t - note[1]
			if lt < 0.0:
				continue
			var env := exp(-lt * decay) * minf(1.0, lt * 300.0)
			s += (sin(TAU * note[0] * lt) + 0.3 * sin(TAU * note[0] * 2.0 * lt)) * env
		data.encode_s16(i * 2, int(clampf(s * 0.3, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w
