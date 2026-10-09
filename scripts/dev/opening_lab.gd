class_name OpeningLab
## OPENING EXPERIENCE LAB (developer page, local only): ?openinglab=1
##
## The real game - same GameManager, board, hints, hearts, stars, sounds -
## but Levels 1-10 come from res://data/dev/opening_lab/ (candidate opening)
## and progress lives in its own save (its own file and localStorage keys),
## so a tester starts as a brand-new player and the real save is never read
## or written. Level 11+ are the production levels, unchanged. Nothing here
## runs unless the page is opened with the parameter.
##
##   ?openinglab=1      play the candidate opening (progress is kept)
##   ?openinglab=reset  wipe the lab save and its log, then play from Level 1
##   (headless: --openinglab / --openinglab=reset)
##
## The lab also keeps a small play log (level starts, restarts, mistakes,
## undos, hints, time to clear, and the time from the completion card to
## NEXT: "voluntary next") in its own store. It is shown in the debug panel
## (tap the title 5 times) and printed as "[OpeningLab] ..." lines.

const PARAM := "openinglab"
const LEVEL_DIR := "res://data/dev/opening_lab"
const SAVE_PATH := "user://opening_lab_progress.cfg"
const MIRROR_KEY := "chain_escape_openinglab_save"
const BEACON_KEY := "chain_escape_openinglab_beacon"
const LOG_KEY := "chain_escape_openinglab_log"
const LOG_PATH := "user://opening_lab_log.json"
const LAST_LAB_LEVEL := 10

static var active := false
static var _log: Array = []
static var _level_start_ms := 0
static var _card_shown_ms := 0


## "" (not asked for), "1" or "reset".
static func requested() -> String:
	if BuildFlags.dev_pages_off():
		return ""  # player / QA build: developer pages off
	var args := OS.get_cmdline_user_args()
	if "--" + PARAM + "=reset" in args:
		return "reset"
	if "--" + PARAM in args or "--" + PARAM + "=1" in args:
		return "1"
	if not OS.has_feature("web"):
		return ""
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return ""
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	if where.contains(PARAM + "=reset"):
		return "reset"
	if where.contains(PARAM + "=1") or where.contains(PARAM + "=true"):
		return "1"
	return ""


## Points level loading and the save at the lab's own files. Must run
## before the save is loaded (first thing in GameManager._ready).
static func apply(mode: String) -> void:
	active = true
	LevelManager.override_dir = LEVEL_DIR
	LevelManager.override_last = LAST_LAB_LEVEL
	PlayerProgress.default_path = SAVE_PATH
	PlayerProgress.mirror_key = MIRROR_KEY
	PlayerProgress.beacon_key = BEACON_KEY
	if mode == "reset":
		for suffix in ["", ".bak", ".tmp", ".beacon"]:
			if FileAccess.file_exists(SAVE_PATH + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
		if FileAccess.file_exists(LOG_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(LOG_PATH))
		if OS.has_feature("web"):
			for key in [MIRROR_KEY, BEACON_KEY, LOG_KEY]:
				WebBridge.ls_set(key, "")
		print("[OpeningLab] reset: lab save and log wiped")
	_log = _read_log()
	print("[OpeningLab] active (%s): levels 1-%d from %s, save %s" % [mode, LAST_LAB_LEVEL, LEVEL_DIR, SAVE_PATH])


## One line per event, kept in the lab's own store.
static func event(kind: String, level: int, data: Dictionary = {}) -> void:
	if not active:
		return
	var now := Time.get_ticks_msec()
	var e := {"t": Time.get_unix_time_from_system(), "kind": kind, "level": level}
	match kind:
		"start":
			_level_start_ms = now
		"clear":
			e["secs"] = snappedf((now - _level_start_ms) / 1000.0, 0.1)
			_card_shown_ms = now
		"next":
			e["secs_to_next"] = snappedf((now - _card_shown_ms) / 1000.0, 0.1) if _card_shown_ms > 0 else -1.0
	e.merge(data, true)
	_log.append(e)
	if _log.size() > 400:
		_log = _log.slice(_log.size() - 400)
	print("[OpeningLab] " + JSON.stringify(e))
	_write_log()


## Per-level summary for the debug panel: attempts, clears, mistakes,
## undos, hints, best time, time to NEXT.
static func summary() -> String:
	var rows := {}
	for e in _log:
		var n: int = int(e.get("level", 0))
		if n < 1:
			continue
		if not rows.has(n):
			rows[n] = {"starts": 0, "restarts": 0, "clears": 0, "mistakes": 0, "undos": 0, "hints": 0, "secs": -1.0, "next": -1.0}
		var r: Dictionary = rows[n]
		match e.get("kind", ""):
			"start":
				r["starts"] += 1
				if e.get("via", "") in ["restart", "retry"]:
					r["restarts"] += 1
			"clear":
				r["clears"] += 1
				r["mistakes"] += int(e.get("mistakes", 0))
				r["undos"] += int(e.get("undos", 0))
				r["hints"] += int(e.get("hints", 0))
				if r["secs"] < 0 or e.get("secs", 0.0) < r["secs"]:
					r["secs"] = e.get("secs", 0.0)
			"next":
				r["next"] = e.get("secs_to_next", -1.0)
	var keys := rows.keys()
	keys.sort()
	var out := PackedStringArray(["OPENING LAB  (level: starts/restarts  clears  mistakes  undos  hints  first-clear secs  secs to NEXT)"])
	for n in keys:
		var r: Dictionary = rows[n]
		out.append("L%d: %d/%d  %d  %d  %d  %d  %.0fs  %s" % [n, r["starts"], r["restarts"], r["clears"], r["mistakes"], r["undos"], r["hints"],
			r["secs"], ("%.1fs" % r["next"]) if r["next"] >= 0 else "-"])
	return "\n".join(out)


static func log_entries() -> Array:
	return _log.duplicate()


static func _read_log() -> Array:
	var texts := []
	if OS.has_feature("web"):
		texts.append(WebBridge.ls_get(LOG_KEY))
	if FileAccess.file_exists(LOG_PATH):
		texts.append(FileAccess.get_file_as_string(LOG_PATH))
	for t in texts:
		var d = JSON.parse_string(t) if t != "" else null
		if typeof(d) == TYPE_ARRAY:
			return d
	return []


static func _write_log() -> void:
	var text := JSON.stringify(_log)
	if OS.has_feature("web"):
		WebBridge.ls_set(LOG_KEY, text)
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
