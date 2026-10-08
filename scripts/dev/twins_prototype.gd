class_name TwinsPrototype
## TWINS PROTOTYPE (developer page, lab only): ?twinsprototype=1 / 2 / 3
##
## Three sample puzzles for human validation of the TWINS mechanic (see
## docs/twins_176_design_validation.md): the real game - same GameManager,
## board, hearts, Undo, SHOW A MOVE, Hammer - but the ONLY levels are
## res://data/dev/twins_prototype/level_01..03.json, and progress lives in
## its own temporary save (its own file and localStorage keys, wiped on every
## launch), so the production save, the Experience Lab saves and Social /
## Friend data are never read or written. Nothing here runs unless the page
## is opened with the parameter; the "!" Twins token is parsed only while
## this mode is on, and only in these level files.
##
##   ?twinsprototype=1   start at prototype Level 1 ("Twin Lights")
##   ?twinsprototype=2   jump to Level 2 ("Hold Fire"), Level 1 marked cleared
##   ?twinsprototype=3   jump to Level 3 ("Turnabout"), Levels 1-2 marked cleared
##   (headless: --twinsprototype=N)

const PARAM := "twinsprototype"
const LEVEL_DIR := "res://data/dev/twins_prototype"
const SAVE_PATH := "user://twins_prototype_progress.cfg"
const MIRROR_KEY := "chain_escape_twinsprototype_save"
const BEACON_KEY := "chain_escape_twinsprototype_beacon"
const LAST_LEVEL := 3
## The temporary save starts with a few boosters so the Hammer and
## SHOW A MOVE can be tried on the twins (prototype save only).
const START_HAMMERS := 3
const START_HINTS := 3
const COMPLETE_TITLE := "END OF TWINS PROTOTYPE"
const COMPLETE_LINE := "3 SAMPLE PUZZLES · THANK YOU FOR TESTING"

static var active := false
static var start_level := 0
static var complete_open := false
static var _log: Array = []


## The prototype level asked for by a page's query string and hash: "1",
## "2", "3", or "" (off). Exact key=value parsing (any order, URL-encoded,
## other parameters such as itch.io's ignored): "xtwinsprototype=1",
## "twinsprototype=0" or "twinsprototype=4" never switch it on.
static func parse_mode(search: String, fragment: String = "") -> String:
	var mode := ""
	for part in [search, fragment]:
		var text := String(part).strip_edges()
		while text.begins_with("?") or text.begins_with("#"):
			text = text.substr(1)
		for pair in text.split("&", false):
			var key := pair.get_slice("=", 0).uri_decode().strip_edges().to_lower()
			var value := (pair.substr(pair.find("=") + 1) if pair.contains("=") else "").uri_decode().strip_edges().to_lower()
			if key != PARAM:
				continue
			if value in ["", "true", "yes", "on"]:
				mode = "1"
			elif value.is_valid_int() and int(value) >= 1 and int(value) <= LAST_LEVEL:
				mode = str(int(value))
	return mode


static func requested() -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + PARAM:
			return "1"
		if a.begins_with("--" + PARAM + "="):
			var m := parse_mode("?" + a.substr(2))
			if m != "":
				return m
	if not OS.has_feature("web"):
		return ""
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return ""
	return parse_mode(str(loc.search), str(loc.hash))


## Points level loading, the Twins token and the save at the prototype's own
## files, and wipes that save. Must run before the save is loaded.
static func apply(mode: String) -> void:
	active = true
	complete_open = false
	start_level = clampi(int(mode), 1, LAST_LEVEL)
	LevelManager.override_dir = LEVEL_DIR
	LevelManager.override_last = LAST_LEVEL
	LevelManager.dev_twins = true
	PlayerProgress.default_path = SAVE_PATH
	PlayerProgress.mirror_key = MIRROR_KEY
	PlayerProgress.beacon_key = BEACON_KEY
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		if FileAccess.file_exists(SAVE_PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + suffix))
	if OS.has_feature("web"):
		for key in [MIRROR_KEY, BEACON_KEY]:
			WebBridge.ls_set(key, "")
	_log = []
	print("[TwinsPrototype] active: Level %d of 1-%d from %s (temporary save %s)" % [start_level, LAST_LEVEL, LEVEL_DIR, SAVE_PATH])


## The fresh prototype save: Levels before the start level cleared (score 0,
## no stars, so nothing is invented), a few boosters to try on the twins.
static func seed_save(progress: PlayerProgress) -> void:
	for i in range(1, start_level):
		progress.best_scores[i] = 0
		progress.best_stars[i] = 0
	progress.highest_completed = start_level - 1
	progress.last_completed_level = start_level - 1
	progress.highest_unlocked = start_level
	progress.current_level = start_level
	progress.inventory["hammer"] = START_HAMMERS
	progress.inventory["hint"] = START_HINTS
	for tip in ["Silver", "Gold", "switch", "gate", "armor"]:
		if not progress.tips_seen.has(tip):
			progress.tips_seen.append(tip)
	progress.save()


## The prototype's end screen (after Level 3). `on_close` opens Level Select
## (the prototype's three levels).
static func show_complete(host: Node, on_close: Callable) -> void:
	complete_open = true
	event("prototype_complete", {})
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.name = "TwinsPrototypeComplete"
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.1, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	dim.add_child(box)
	for spec in [[COMPLETE_TITLE, 44, Color("#FFD24A")], [COMPLETE_LINE, 34, Color.WHITE], ["(development build - not part of the game)", 22, Color("#B9AEE8")]]:
		var l := Label.new()
		l.text = spec[0]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", spec[1])
		l.add_theme_color_override("font_color", spec[2])
		box.add_child(l)
	var b := PillButton.new("LEVEL SELECT", PillButton.Icon.GRID, Palette.ACCENT, Palette.WHITE, 30)
	b.custom_minimum_size = Vector2(360, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		complete_open = false
		layer.queue_free()
		on_close.call())
	box.add_child(b)
	host.add_child(layer)


## Play log (memory and console only; nothing is stored).
static func event(kind: String, data: Dictionary = {}) -> void:
	if not active:
		return
	var e := {"t": Time.get_ticks_msec(), "kind": kind}
	e.merge(data, true)
	_log.append(e)
	if _log.size() > 400:
		_log = _log.slice(_log.size() - 400)
	print("[TwinsPrototype] " + JSON.stringify(e))


static func log_entries() -> Array:
	return _log.duplicate()
