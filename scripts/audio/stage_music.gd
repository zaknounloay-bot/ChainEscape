class_name StageMusic
extends Node
## DEVELOPMENT ONLY: the 90-second Time Attack prototype's dynamic music
## (?ta90=1, Ta90TimeAttack). One original theme in four full mixes
## (tools/generate_ta90_music.py, data/dev/ta90_audio): green / orange / red
## follow the countdown stage, calm plays during the untimed continuation.
## The three timed mixes share tempo and loop length, so a stage change is a
## cross-fade that starts the next mix at the SAME loop position (the beat
## never jumps).
## Rules:
##   - It only LISTENS to the clock (set_stage from the countdown): nothing
##     here reads or changes time.
##   - Sound only after the browser unlocked audio inside a real gesture
##     (AudioManager / web/audio_unlock.js: the START tap on iPhone Safari);
##     before that a requested stage is remembered and starts on unlock.
##   - Off when the player's global music setting is off, or when the
##     page's own MUSIC toggle is off.
##   - Its own bus ("TA90Music", routed to Master), so the campaign "Music"
##     bus can stay silent on this page without touching any setting.
##   - Paused while the page is hidden; resumed when it shows again.
##   - Missing files / no audio output: silent, never an error for the page.

const BUS := "TA90Music"
const DIR := "res://data/dev/ta90_audio/"
const MIXES := {"green": "music_ta90_green.wav", "orange": "music_ta90_orange.wav", "red": "music_ta90_red.wav", "calm": "music_ta90_calm.wav"}
const VOLUME_DB := -13.0
const SILENT_DB := -40.0
const CROSSFADE := 1.6  # a stage change
const CALM_IN := 2.5  # the calm mix after TIME UP
const FADE_OUT := 1.0  # a solve / TIME UP / leaving

var enabled := true  # the page's own MUSIC toggle
var stage := ""  # the stage asked for ("" = silent)
var _mix := ""  # the mix actually sounding ("" = none)
var hidden := false
var _players: Array[AudioStreamPlayer] = []
var _cur := 0
var _streams := {}
var _fades := 0  # completed cross-fades (tests)
var _fading_out := false  # a fade-out is under way: later stop requests let it finish
## Volume ramps, driven by the WALL clock in _process (not tweens: a page
## drawing few frames - a busy phone, a background tab coming back - must
## still finish every fade on time). Per player: [from_db, to_db, start_ms,
## length_ms, stop_at_end].
var _ramps := {}


func _ready() -> void:
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = BUS
		p.volume_db = SILENT_DB
		add_child(p)
		_players.append(p)
	if not AudioManager.audio_unlocked.is_connected(_on_unlocked):
		AudioManager.audio_unlocked.connect(_on_unlocked)


## The player's global music setting is followed while playing too: off
## fades out, on again resumes the current stage.
func _process(_delta: float) -> void:
	_run_ramps()
	if not AudioManager.music_enabled and _mix != "":
		_fade_out(0.35)
	elif AudioManager.music_enabled and _mix == "" and stage != "":
		_restart()


func _exit_tree() -> void:
	_ramps.clear()
	for p in _players:
		p.stop()
		p.stream = null


## Sound allowed now: unlocked, the global setting and the toggle on.
func audible() -> bool:
	return enabled and AudioManager.music_enabled and AudioManager.unlocked


## The mix for a stage (green / orange / red / calm), "" for silence.
func set_stage(st: String) -> void:
	if st == stage and (st == "" or _mix == st or not audible()):
		return
	stage = st
	if not audible() or hidden:
		return
	if st == "":
		_fade_out(FADE_OUT)
		return
	var stream := _stream(st)
	if stream == null:
		return  # no file / no import: silent
	var out_p := _players[_cur]
	var in_p := _players[1 - _cur]
	var pos := 0.0
	# The same loop position for the timed mixes (same tempo and length).
	if out_p.playing and _mix in ["green", "orange", "red"] and st in ["green", "orange", "red"]:
		pos = fmod(out_p.get_playback_position(), stream.get_length())
	in_p.stream = stream
	in_p.volume_db = SILENT_DB
	in_p.play(pos)
	_cur = 1 - _cur
	_mix = st
	_fading_out = false
	var t := CALM_IN if st == "calm" else CROSSFADE
	_ramp(in_p, VOLUME_DB, t, false)
	if out_p.playing:
		_ramp(out_p, SILENT_DB, t, true)
		_fades += 1


## Fade out and stay silent (a solve, TIME UP, the result screen, leaving).
func stop_music(fade: float = FADE_OUT) -> void:
	stage = ""
	_fade_out(fade)


func _fade_out(fade: float) -> void:
	_mix = ""
	if _fading_out:
		return  # already fading out (several screens ask for silence): let it finish
	var playing := _players.filter(func(p): return p.playing)
	if playing.is_empty():
		return
	_fading_out = true
	for p in playing:
		_ramp(p, SILENT_DB, fade, true)


func _ramp(p: AudioStreamPlayer, to_db: float, secs: float, stop_at_end: bool) -> void:
	_ramps[p] = [p.volume_db, to_db, Time.get_ticks_msec(), maxi(1, int(secs * 1000.0)), stop_at_end]


## Advances every ramp by the wall clock (sine ease); a fade-out stops its
## player at the end.
func _run_ramps() -> void:
	var now := Time.get_ticks_msec()
	for p in _ramps.keys():
		var r: Array = _ramps[p]
		var k := clampf(float(now - int(r[2])) / float(r[3]), 0.0, 1.0)
		var e := 0.5 - 0.5 * cos(PI * k)
		p.volume_db = lerpf(r[0], r[1], e)
		if k >= 1.0:
			_ramps.erase(p)
			if r[4]:
				p.stop()
	if _fading_out and not _players.any(func(x): return x.playing):
		_fading_out = false


## The page's MUSIC toggle.
func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_fade_out(0.35)
		return
	_restart()


## The page went to the background (or came back): pause / resume.
func set_hidden(h: bool) -> void:
	hidden = h
	for p in _players:
		p.stream_paused = h
	if not h:
		_restart()


func _on_unlocked() -> void:
	_restart()


## Plays the asked stage again if nothing is sounding (after unlock, toggle
## on, coming back).
func _restart() -> void:
	if stage == "" or not audible() or hidden or (_mix == stage and _players[_cur].playing):
		return
	if not _players[_cur].playing:
		_mix = ""
	var st := stage
	stage = ""
	set_stage(st)


func _stream(st: String) -> AudioStream:
	if _streams.has(st):
		return _streams[st]
	var path: String = DIR + MIXES.get(st, "")
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s is AudioStreamWAV and s.loop_mode == AudioStreamWAV.LOOP_DISABLED:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_streams[st] = s
	return s


## For tests (published by the page).
func snapshot() -> Dictionary:
	var p := _players[_cur]
	return {"stage": stage, "mix_now": _mix, "enabled": enabled, "global": AudioManager.music_enabled, "unlocked": AudioManager.unlocked, "hidden": hidden,
		"playing": p.playing and not p.stream_paused, "sounding": _players.filter(func(x): return x.playing).size(),
		"mix": (p.stream.resource_path.get_file().trim_prefix("music_ta90_").trim_suffix(".wav") if p.stream else ""),
		"volume_db": snappedf(p.volume_db, 0.1), "fps": Engine.get_frames_per_second(), "pos": snappedf(p.get_playback_position(), 0.01) if p.playing else 0.0, "fades": _fades}
