class_name Competition
extends Node
## REAL-PLAYER RESULTS (Phase 3B-B), client side - the QA build ("qa" pool)
## and the player build ("prod" pool) (BuildFlags.competition()). It records, sends and remembers; Phase 3B-C
## adds the standing shown on the level card (card_status, lookup).
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
##
## STANDING ON THE CARD (Phase 3B-C): only what the server answered -
## "TOP X%" or null (fewer than 5 players); never a rank, a count or a
## locally computed value. Every answer and every failure carries a
## sequence number, so a card shows only what arrived after its own clear
## (card_status(level, since)) - never an older standing as a new one. A
## clear that queues nothing (not faster than the sent best) asks for the
## current standing with the read-only level_standing (lookup), which
## never registers a player or writes a result.

signal standing_changed(level: int)

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
## level -> {"percentile": int|null, "best_ms": int, "improved": bool,
## "seq": int} from the last answer (submit_result or level_standing).
var standings: Dictionary = {}
## level -> {"error": String, "retry": bool, "seq": int}: the last failure
## for that level (cleared by the next answer).
var level_errors: Dictionary = {}
var last_error := ""
var _seq := 0
var _again := false
var _looking: Dictionary = {}
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
	if sending:
		_again = true  # queued while a flush runs: sent right after it
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
			if not progress.comp_pending.has(level):  # else a faster time was queued meanwhile: its own answer follows
				_answer(level, data.get("percentile", null), best, bool(data.get("improved", false)))
			changed = true
			last_error = ""
		elif r.get("ok", false) and (err in PERMANENT or err == "wrong_secret"):
			progress.comp_pending.erase(level)
			changed = true
			last_error = err
			_fail(level, err, false)
			if err == "wrong_secret":
				locked = true
				break
		else:
			last_error = err if err != "" else str(r.get("error", "http_%d" % int(r.get("code", 0))))
			retry = true
			break
	if retry:
		for level in progress.comp_pending:  # nothing more is sent until the retry
			_fail(level, last_error, true)
	if changed:
		progress.save()
	sending = false
	if _again and not retry and not locked:
		_again = false
		flush.call_deferred()
	if retry and _retry != null:
		_retry.start(_retry_wait)
		_retry_wait = minf(_retry_wait * 2.0, RETRY_MAX)
	elif not retry:
		_retry_wait = RETRY_MIN


## The current standing of a level this player already sent, read-only
## (level_standing: never registers a player, never writes a result).
## Only when nothing for that level is queued - a queued result's own
## answer is newer. One request per level at a time.
func lookup(level: int) -> void:
	if locked or _looking.has(level) or progress.comp_pending.has(level) or not progress.comp_sent.has(level) \
			or not PlayerProfile.is_valid_secret(progress.comp_secret):
		return
	var fp := LevelFingerprint.expected(level)
	if fp == "":
		return
	_looking[level] = true
	var body := {"action": "level_standing", "pool": pool, "player_id": progress.player_id, "secret": progress.comp_secret,
		"level": level, "fingerprint": fp}
	requests += 1
	var r: Dictionary
	if transport.is_valid():
		r = await transport.call(body)
	else:
		r = await _api.post_action(body)
	_looking.erase(level)
	if progress.comp_pending.has(level):
		return  # a new result was queued meanwhile: its submit answer is the newer one
	var data = r.get("data", null)
	var err := str(data.get("error", "")) if data is Dictionary else ""
	if r.get("ok", false) and int(r.get("code", 0)) == 200 and data is Dictionary and data.get("ok", false):
		if data.get("none", false):
			_fail(level, "none", false)  # the server has no result for this player here: nothing to show
		else:
			_answer(level, data.get("percentile", null), int(data.get("best_ms", 0)), false)
	elif r.get("ok", false) and (err in PERMANENT or err == "wrong_secret"):
		_fail(level, err, false)
		if err == "wrong_secret":
			locked = true
	else:
		_fail(level, err if err != "" else str(r.get("error", "http_%d" % int(r.get("code", 0)))), true)


## A sequence mark: card_status(level, mark()) shows only what arrives
## after this moment.
func mark() -> int:
	return _seq


## What the level card shows for `level`, from answers newer than `since`:
##   {"state": "top", "percentile": X, "best_ms": ms}  TOP X% (server value)
##   {"state": "needs_players"}   the server has fewer than 5 players
##   {"state": "offline"}         a queued result not answered yet (network,
##                                server error, busy): kept, sent later
##   {"state": "unavailable"}     the standing could not be fetched now
##   {"state": "checking"}        a request for it is on its way
##   {"state": "hidden"}          nothing to show (locked, dropped, none)
func card_status(level: int, since: int) -> Dictionary:
	if locked:
		return {"state": "hidden"}
	var s: Dictionary = standings.get(level, {})
	var e: Dictionary = level_errors.get(level, {})
	var s_new := not s.is_empty() and int(s["seq"]) > since
	var e_new := not e.is_empty() and int(e["seq"]) > since
	if s_new and (not e_new or int(s["seq"]) > int(e["seq"])):
		if s["percentile"] == null:
			return {"state": "needs_players"}
		return {"state": "top", "percentile": int(s["percentile"]), "best_ms": int(s["best_ms"]), "improved": s["improved"]}
	if e_new:
		if not e["retry"]:
			return {"state": "hidden"}
		return {"state": "offline"} if progress.comp_pending.has(level) else {"state": "unavailable"}
	if progress.comp_pending.has(level) or _looking.has(level) or progress.comp_sent.has(level):
		return {"state": "checking"}
	return {"state": "hidden"}


func _answer(level: int, percentile, best_ms: int, improved: bool) -> void:
	_seq += 1
	var pct = null
	if percentile is int or percentile is float:
		pct = clampi(int(roundf(float(percentile))), 1, 100)  # JSON numbers arrive as floats
	standings[level] = {"percentile": pct, "best_ms": best_ms, "improved": improved, "seq": _seq}
	level_errors.erase(level)
	standing_changed.emit(level)


func _fail(level: int, err: String, retry: bool) -> void:
	_seq += 1
	level_errors[level] = {"error": err, "retry": retry, "seq": _seq}
	standing_changed.emit(level)


## Test / diagnostics snapshot (no secret, no player id).
func state() -> Dictionary:
	return {"enabled": true, "pool": pool, "pending": progress.comp_pending.keys(), "sent": progress.comp_sent.duplicate(),
		"standings": standings.duplicate(true), "level_errors": level_errors.duplicate(true), "locked": locked, "requests": requests, "last_error": last_error,
		"has_secret": PlayerProfile.is_valid_secret(progress.comp_secret)}
