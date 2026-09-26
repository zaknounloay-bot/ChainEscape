extends Node
## Global audio hub (autoload "AudioManager").
##
## Gameplay code only calls semantic hooks (`play_escape(chain)`,
## `play_invalid()`, ...). Each hook maps to a sound id. At startup every id
## looks for a real asset at res://assets/audio/<id>.ogg|.wav and falls back
## to a small synthesized placeholder, so final audio can be dropped in later
## without touching code.

const SOUND_IDS := ["escape", "invalid", "combo", "level_complete", "ui_tap", "undo"]
const ASSET_DIR := "res://assets/audio/"
const MIX_RATE := 44100
const VOICES := 8

## Major pentatonic steps in semitones: consecutive escapes climb a pleasant
## scale instead of a plain linear pitch ramp.
const CHAIN_SCALE := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for id in SOUND_IDS:
		_streams[id] = _load_or_synthesize(id)


# --- Gameplay hooks --------------------------------------------------------

func play_escape(chain: int) -> void:
	play("escape", chain_pitch(chain), -4.0)


func play_invalid() -> void:
	play("invalid", 1.0, -6.0)


## Called on chain milestones (x3, x5, x8...). Pitch follows the chain.
func play_combo(chain: int) -> void:
	play("combo", chain_pitch(chain - 2), -8.0)


func play_level_complete() -> void:
	play("level_complete", 1.0, -3.0)


func play_ui_tap() -> void:
	play("ui_tap", 1.0, -10.0)


func play_undo() -> void:
	play("undo", 1.0, -8.0)


static func chain_pitch(chain: int) -> float:
	var idx := clampi(chain - 1, 0, CHAIN_SCALE.size() - 1)
	return pow(2.0, CHAIN_SCALE[idx] / 12.0)


# --- Core ------------------------------------------------------------------

func play(id: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not enabled or not _streams.has(id):
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
