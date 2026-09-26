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
	"turn", "heart_lost", "hint", "try_again"]
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
var sfx_enabled: bool = true
var music_enabled: bool = true
var _music: AudioStreamPlayer
var _duck_tween: Tween
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
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
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = MUSIC_VOLUME_DB
	_music.stream = _load_music()
	add_child(_music)


func _exit_tree() -> void:
	# Release the looping stream cleanly on quit.
	_music.stop()
	_music.stream = null


# --- Settings ----------------------------------------------------------------

func set_sfx_enabled(on: bool) -> void:
	sfx_enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not on)


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
	if on:
		start_music()
	elif _music.playing:
		_music.stop()


# --- Music -----------------------------------------------------------------

func start_music() -> void:
	if music_enabled and _music.stream and not _music.playing:
		_music.play()


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


func _load_music() -> AudioStream:
	var stream: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:
		var path: String = ASSET_DIR + MUSIC_ID + "." + ext
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
	if not sfx_enabled or not _streams.has(id):
		return
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
