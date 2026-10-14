class_name Competition
extends Node
## REAL-PLAYER RESULTS (Phase 3B-B), client side - QA build only for now
## (BuildFlags.competition()). No UI: it records, sends and remembers.
##
## When a level is cleared, the attempt's time is queued if it beats what
## this player already sent or queued for that level (PlayerProgress
## comp_pending / comp_sent, saved with the progress). Only attempts
## finished while competition is on count: older Personal Bests are never
## sent (no backfill). Sending happens in the background after the clear,
## at start and on a backoff timer - never blocking play, the card or NEXT.
##
## Server answers:
##   ok                     -> acknowledged (comp_sent), the standing kept
##   invalid_* (400)        -> that result can never be valid: dropped
##   wrong_secret (403)     -> this id belongs to another secret: dropped,
##                             further sending stops (locked)
##   anything else          -> network, timeout, 5xx, 429 busy, pool closed,
##                             or a server without results: kept, retried
##                             later (backoff 30 s .. 10 min)
## Hints, Undo and Hammer are allowed; the time is AttemptTimer's (the
## shown time); timing diagnostics go to the QA pool only.

const PERMANENT := ["invalid_level", "invalid_fingerprint", "invalid_time", "invalid_player", "invalid_secret"]
const RETRY_MIN := 30.0
const RETRY_MAX := 600.0

var progress: PlayerProgress
## Test hook: func(body: Dictionary) -> Dictionary like SocialApi.post_action.
var transport: Callable
var pool := "qa"
var locked := false
var sending := false
var requests := 0
## level -> {"percentile": int|null, "best_ms": int} from the last answer.
var standings: Dictionary = {}
var last_error := ""
var _api: SocialApi
var _retry: Timer
var _retry_wait := RETRY_MIN


func _init(p: PlayerProgress) -> void:
	progress = p
	pool = "prod" if BuildFlags.player_build() else "qa"


func _ready() -> void:
	_api = SocialApi.new()
	add_child(_api)
	_retry = Timer.new()
	_retry.one_shot = true
	_retry.timeout.connect(flush)
	add_child(_retry)


## At start (after the save is loaded): the secret exists, then anything
## still pending is sent. True = the save changed (the caller saves).
func start() -> bool:
	var made := progress.ensure_comp_secret()
	flush.call_deferred()
	return made


## A cleared level. Queues the attempt if it is a new best for competition
## (the caller saves the progress right after). Returns true when queued.
func note_clear(level: int, time_ms: int, cap: Dictionary) -> bool:
	if locked or not PlayerProfile.is_valid_id(progress.player_id) or not progress.valid_time(time_ms):
		return false
	var fp := LevelFingerprint.expected(level)
	if fp == "":
		return false
	var known := int(progress.comp_sent.get(level, 0))
	if progress.comp_pending.has(level):
		known = mini(known, int(progress.comp_pending[level]["t"])) if known > 0 else int(progress.comp_pending[level]["t"])
	if known > 0 and time_ms >= known:
		return false
	progress.comp_pending[level] = {"t": time_ms, "fp": fp, "diag": cap.duplicate() if pool == "qa" else {}}
	return true


func pending_count() -> int:
	return progress.comp_pending.size()


## Sends everything pending, one level at a time. Safe to call any time.
func flush() -> void:
	if sending or locked or progress.comp_pending.is_empty() or not PlayerProfile.is_valid_secret(progress.comp_secret):
		return
	sending = true
	var changed := false
	var levels := progress.comp_pending.keys()
	levels.sort()
	var retry := false
	for level in levels:
		if not progress.comp_pending.has(level):
			continue
		var e: Dictionary = progress.comp_pending[level]
		var body := {"action": "submit_result", "pool": pool, "player_id": progress.player_id, "secret": progress.comp_secret,
			"level": int(level), "fingerprint": e["fp"], "time_ms": int(e["t"])}
		if pool == "qa" and not (e.get("diag", {}) as Dictionary).is_empty():
			body["diag"] = e["diag"]
		requests += 1
		var r: Dictionary
		if transport.is_valid():
			r = await transport.call(body)
		else:
			r = await _api.post_action(body)
		var data = r.get("data", null)
		var err := str(data.get("error", "")) if data is Dictionary else ""
		if r.get("ok", false) and int(r.get("code", 0)) == 200 and data is Dictionary and data.get("ok", false):
			var best := int(data.get("best_ms", e["t"]))
			progress.comp_sent[level] = mini(int(progress.comp_sent.get(level, best)), best)
			if progress.comp_pending.has(level) and int(progress.comp_pending[level]["t"]) >= best:
				progress.comp_pending.erase(level)
			standings[level] = {"percentile": data.get("percentile", null), "best_ms": best}
			changed = true
			last_error = ""
		elif r.get("ok", false) and (err in PERMANENT or err == "wrong_secret"):
			progress.comp_pending.erase(level)
			changed = true
			last_error = err
			if err == "wrong_secret":
				locked = true
				break
		else:
			last_error = err if err != "" else str(r.get("error", "http_%d" % int(r.get("code", 0))))
			retry = true
			break
	if changed:
		progress.save()
	sending = false
	if retry and _retry != null:
		_retry.start(_retry_wait)
		_retry_wait = minf(_retry_wait * 2.0, RETRY_MAX)
	elif not retry:
		_retry_wait = RETRY_MIN


## Test / diagnostics snapshot (no secret, no player id).
func state() -> Dictionary:
	return {"enabled": true, "pool": pool, "pending": progress.comp_pending.keys(), "sent": progress.comp_sent.duplicate(),
		"standings": standings.duplicate(true), "locked": locked, "requests": requests, "last_error": last_error,
		"has_secret": PlayerProfile.is_valid_secret(progress.comp_secret)}
