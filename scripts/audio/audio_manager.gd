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
	"coin", "hammer", "chest", "master", "chapter", "silver", "gold", "chapter_complete",
	# v0.6 Second Era
	"switch", "gate", "crack", "milestone"]
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
## Music theme currently requested ("c01".."c10", "master"; see
## data/chapters.json).
var music_theme: String = "c01"
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
## and starts music / allows SFX once the context reports "running" after a
## real gesture. Web playback is STREAM (project setting
## audio/general/default_playback_type.web): Godot mixes everything and feeds
## one Web Audio node, the long-proven path on iOS Safari.
## If the page has no bridge (old export), it falls back to unlocking on the
## first gesture.
var _web: bool = OS.has_feature("web")
var _bridge: bool = false
var _poll_timer := 0.0
var _publish_timer := 0.0
var _blocked_since := -1.0
var _stuck_warned := false
## Sound effects actually sent to a player (for tests / diagnostics).
var sfx_played: int = 0


func _init_web_audio() -> void:
	if not _web:
		return
	_bridge = WebBridge.available()
	if not _bridge:
		push_warning("[CE-Audio] page unlock script missing - unlocking on the first Godot input instead")


func _input(event: InputEvent) -> void:
	if unlocked:
		return
	var gesture: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed)
	if gesture and not _bridge:
		unlock_audio()  # desktop / old export fallback


func _page_gestures() -> int:
	return int(WebBridge.api().gestures())


func _ctx_state() -> String:
	if not _bridge:
		return "n/a"
	return str(WebBridge.api().state())


## Web builds publish their audio state to the page (window.chainEscapeAudio)
## so automated browser tests can check it.
func _publish_web_state() -> void:
	WebBridge.publish("chainEscapeAudio", {"unlocked": unlocked, "musicPlaying": _music.playing,
		"musicPos": snappedf(_music.get_playback_position(), 0.001) if _music.playing else 0.0, "theme": music_theme,
		"musicEnabled": music_enabled, "sfxEnabled": sfx_enabled, "context": _ctx_state(), "sfxPlayed": sfx_played})


func _process(delta: float) -> void:
	if not _web:
		return
	_poll_timer += delta
	if _bridge and not unlocked and _poll_timer >= 0.15:
		_poll_timer = 0.0
		# Some browsers create the context already "running" (e.g. high media
		# engagement); still wait for a real user gesture before any sound.
		var gestures := _page_gestures()
		if gestures > 0 and _ctx_state() == "running":
			unlock_audio()
		elif gestures >= 3:
			_warn_if_stuck()
	_publish_timer += delta
	if _publish_timer >= 0.5:
		_publish_timer = 0.0
		_publish_web_state()


## The only runtime audio log: the browser kept audio blocked although the
## player tapped several times.
func _warn_if_stuck() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _blocked_since < 0.0:
		_blocked_since = now
	elif not _stuck_warned and now - _blocked_since > 2.0:
		_stuck_warned = true
		push_warning("[CE-Audio] audio still '%s' after %d taps - the browser is blocking playback" % [_ctx_state(), _page_gestures()])


## Audio is usable: start music (if ON) and allow SFX (if ON). Runs once;
## later taps never restart music.
func unlock_audio() -> void:
	if unlocked:
		return
	unlocked = true
	audio_unlocked.emit()
	start_music()
	if _web:
		_publish_web_state()


func _notification(what: int) -> void:
	# Coming back to the tab / app: make sure the loop is still running.
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
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
		# Cancel a Chapter fade in progress too, so turning music back on
		# starts the current theme right away.
		if _fade_tween:
			_fade_tween.kill()
		_music.stop()
		_music_b.stop()


# --- Music -----------------------------------------------------------------

## Music players currently playing (diagnostics: 1, or 2 during a fade).
func music_playing_count() -> int:
	return [_music, _music_b].filter(func(p): return p.playing).size()


## SFX voices currently sounding (diagnostics; the pool is fixed at VOICES).
func sfx_playing_count() -> int:
	return _players.filter(func(p): return p.playing).size()


func is_music_playing() -> bool:
	return _music.playing


## Starts the current theme if allowed (music on, audio unlocked).
func start_music() -> void:
	if not music_enabled or not unlocked:
		return
	# v0.6.3: a Chapter fade in progress starts the next theme itself; an
	# early play() here (e.g. focus regained mid-fade) would start it at full
	# volume and then restart it when the fade's scheduled start fires.
	if is_music_transitioning():
		return
	if _music.stream and not _music.playing:
		_music.volume_db = MUSIC_VOLUME_DB
		_music.play()


## Chapter change: the old theme fades out, the new one fades in just
## behind it (a short tail overlap, never two full themes at once).
const FADE_OUT := 0.8
const FADE_IN_DELAY := 0.55
const FADE_IN := 1.1


## Switches the music theme with a clean sequential fade (Chapter changes).
func set_music_theme(theme: String) -> void:
	if theme == music_theme and _music.stream != null:
		start_music()
		return
	music_theme = theme
	var stream := _theme_stream(theme)
	# The track the player hears now. v0.6.3: during the first part of a
	# previous fade the new theme has not started yet and the OLD one is
	# still fading on the other player - fade that one out (it used to be
	# stopped dead: an audible cut on quick Chapter changes).
	var outgoing: AudioStreamPlayer = _music if _music.playing else (_music_b if _music_b.playing else null)
	if _fade_tween:
		_fade_tween.kill()
	if not music_enabled or not unlocked or outgoing == null:
		_music_b.stop()
		_music.stop()
		_music.stream = stream
		start_music()
		return
	var incoming: AudioStreamPlayer = _music_b if outgoing == _music else _music
	_music = incoming
	_music_b = outgoing
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = -40.0
	_fade_tween = create_tween().set_parallel()
	_fade_tween.tween_property(outgoing, "volume_db", -40.0, FADE_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_fade_tween.tween_callback(outgoing.stop).set_delay(FADE_OUT)
	_fade_tween.tween_callback(func():
		if music_enabled and unlocked:
			incoming.play()).set_delay(FADE_IN_DELAY)
	_fade_tween.tween_property(incoming, "volume_db", MUSIC_VOLUME_DB, FADE_IN).set_delay(FADE_IN_DELAY).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## True while a Chapter music change is still fading (tests).
func is_music_transitioning() -> bool:
	return _fade_tween != null and _fade_tween.is_valid() and _fade_tween.is_running()


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


func play_chapter() -> void:
	play("chapter", 1.0, -5.0)


func play_chapter_complete() -> void:
	duck_music(2.0)
	play("chapter_complete", 1.0, -2.0)


## Silver / Gold block escaped: a short premium chime (gold is richer).
func play_reward(rarity: int) -> void:
	if rarity >= BlockData.Rarity.GOLD:
		play("gold", 1.0, -1.0)
	elif rarity == BlockData.Rarity.SILVER:
		play("silver", 1.0, -2.0)


## v0.6: a switch fired (its arrows reverse).
func play_switch() -> void:
	play("switch", 1.0, -6.0)


## v0.6: a Chain Gate opened.
func play_gate() -> void:
	play("gate", 1.0, -4.0)


## v0.6: an armor shell cracked by a ram.
func play_crack() -> void:
	play("crack", 1.0, -2.0)


## v0.6: a milestone level (125 / 150 / 175) cleared.
func play_milestone() -> void:
	duck_music(2.2)
	play("milestone", 1.0, -2.0)


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
		return
	sfx_played += 1
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
		"chapter":
			return _synth_notes([[392.0, 0.0], [587.0, 0.15], [784.0, 0.3]], 1.1, 3.5)
		"silver":
			# Light, glassy two-note chime.
			return _synth_notes([[1760.0, 0.0], [2637.0, 0.06], [3520.0, 0.12]], 0.45, 12.0)
		"gold":
			# Warmer, richer sparkle that rises a little further.
			return _synth_notes([[1319.0, 0.0], [1760.0, 0.05], [2217.0, 0.1], [2637.0, 0.15], [3520.0, 0.22]], 0.7, 8.0)
		"chapter_complete":
			return _synth_notes([[523.0, 0.0], [659.0, 0.1], [784.0, 0.2], [1047.0, 0.32], [784.0, 0.5], [1047.0, 0.6], [1319.0, 0.72], [1568.0, 0.86]], 1.6, 3.2)
		"try_again":
			return _synth_notes([[523.0, 0.0], [466.0, 0.12], [392.0, 0.24]], 0.7, 6.0)
		"switch":
			# Electric toggle: a quick up-down blip pair.
			return _synth_notes([[1245.0, 0.0], [1865.0, 0.05], [1245.0, 0.1]], 0.3, 18.0)
		"gate":
			# Heavy latch, then a rising open chord.
			return _synth_notes([[196.0, 0.0], [392.0, 0.02], [784.0, 0.12], [988.0, 0.2], [1175.0, 0.28]], 0.8, 6.5)
		"crack":
			# v0.6.4 shell burst: a short explosion (noise + low thump).
			return _synth_boom(0.55)
		"milestone":
			return _synth_notes([[587.0, 0.0], [740.0, 0.1], [880.0, 0.2], [1175.0, 0.32], [1480.0, 0.46], [1760.0, 0.62]], 1.5, 3.4)
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


## Short explosion: a sharp noise crack that darkens as it fades, over a
## low thump that drops in pitch. Deterministic (seeded) noise.
func _synth_boom(length: float) -> AudioStreamWAV:
	var n := int(length * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp := 0.0
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var attack := minf(1.0, t * 900.0)
		# Noise through a one-pole low-pass that closes over time.
		var k := lerpf(0.55, 0.06, minf(t / length, 1.0))
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		var noise := lp * exp(-t * 9.0) * 1.6
		phase += TAU * lerpf(95.0, 42.0, minf(t / 0.35, 1.0)) / MIX_RATE
		var thump := sin(phase) * exp(-t * 7.0) * 0.9
		var s := (noise + thump) * attack
		data.encode_s16(i * 2, int(clampf(s * 0.55, -1.0, 1.0) * 32767.0))
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
