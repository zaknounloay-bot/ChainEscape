class_name ExperienceLab
## PLAYER EXPERIENCE LAB 1-200 (developer page, not production):
##   ?experiencelab=reset   wipe the lab save and log, start at Lab Level 1
##   ?experiencelab=1       continue the lab
##   ?experiencelab=N       QA jump (N = 2..300): open Level N directly in
##                          an isolated QA session (see QA_SAVE_PATH)
##   ?experiencelab=N&qareset=1   restart the QA session at Level N
## Works next to other query parameters (itch.io adds ?v=...):
##   index.html?v=123456&experiencelab=reset
## (headless: --experiencelab / --experiencelab=reset)
##
## The real game - same GameManager, board, hints, hearts, stars, tools,
## sounds - with Levels 1-200 read from res://data/dev/experience_lab/ (the
## candidate progression, docs/player_experience_lab_1_100.md) and
## progress in its own save (its own file and localStorage keys): the real
## save, the Opening Lab save, Social and Challenge state are never read or
## written. Lab 100 (the Master) leads straight on into the Switch era (Lab
## 101-200: production boards, 102-105 the lab's Switch ramp; 121-130 the
## production Chain Gate levels; 131 keeps its board with a corrected lab
## hint; 151-170 interleave production 151-160 and 161-170 so ARMOR starts
## at Lab 151 (production 161 with one adapted token); 176-200 are the
## production levels, the Grand Master at 200 included). The level count is
## 200 - a temporary lab boundary, not the end of the game: NEXT after Lab
## 200 shows a lab-only "end of this test build" screen (never Level 201). Nothing here runs unless the page is opened with the
## parameter.
##
## QA SESSION (since the 1-300 freeze): a QA jump plays the frozen
## production Levels 1-300 (res://levels - Lab 1-200 are byte-identical to
## them) with production's lessons, milestones and NEXT past Level 200 into
## 201, in its own QA save. The QA save keeps the Level it started from
## (qa/origin): reloading the same jump URL (Safari reload, evicted tab)
## RESUMES the session; a different checkpoint N starts a fresh session at
## N; &qareset=1 restarts it (the parameter is then removed from the address
## so a later reload resumes again). The QA build (BuildFlags.qa_build) is
## always a QA session: without N it resumes the last one, or starts at 1.

const PARAM := "experiencelab"
const LEVEL_DIR := "res://data/dev/experience_lab"
const SAVE_PATH := "user://experience_lab_progress.cfg"
const MIRROR_KEY := "chain_escape_experiencelab_save"
const BEACON_KEY := "chain_escape_experiencelab_beacon"
const LOG_KEY := "chain_escape_experiencelab_log"
const LOG_PATH := "user://experience_lab_log.json"
const LAST_LEVEL := 200
## A QA session runs over the whole frozen campaign.
const QA_LAST_LEVEL := 300
const QA_RESET_PARAM := "qareset"
## QA session (?experiencelab=N): its own save, file AND localStorage keys,
## so a jump never touches the real save, the Opening Lab save or the
## normal lab save and lab log - even on the same browser origin as the
## Friend Test build.
const QA_SAVE_PATH := "user://experience_lab_qa.cfg"
const QA_MIRROR_KEY := "chain_escape_experiencelab_qa_save"
const QA_BEACON_KEY := "chain_escape_experiencelab_qa_beacon"
const COMPLETE_TITLE := "END OF THIS TEST BUILD"
const COMPLETE_LINE := "LAB LEVELS 1–200 · MORE LEVELS COME LATER"

## Lab-only guided lessons (GameManager's lesson system): Lab 13 teaches
## the Lock by cause and effect - every key-colour block must leave.
## Lab 101 keeps production's Switch lesson and Lab 121 production's Chain
## Gate lesson, unchanged; production's Armor lesson (161) runs at Lab 151,
## where Armor starts in the lab (the lab's lessons replace
## GameManager.LESSONS while the lab is active). Lab 176 introduces TWINS
## (the approved prototype mechanic; lab-only) with its own lesson.
## (201 / 226 / 251: production's Third Era lessons, kept in step with
## GameManager.LESSONS - the lab ends at 200, QA sessions use production's.)
const LESSONS := {13: "lock", 101: "switch", 121: "gate", 151: "armor", 176: "twins", 201: "portal", 226: "sequence", 251: "movable"}
## Where the lab introduces ARMOR (production: 161). The Chapter card's
## "NEW: Armored Blocks" line follows it (GameManager._chapter_news).
const ARMOR_INTRO := 151
## Where the lab introduces TWINS (lab only; production has none). The
## Chapter 18 card's "NEW:" line names it (GameManager._chapter_news).
const TWINS_INTRO := 176
## Lab-only, presentation-only milestones: "N / LEVELS ESCAPED!" (no coins,
## no rewards, nothing about the game ending; the game goes on after 100).
## (Since the milestone polish: the same tiers as production, chapters.json.)
const CELEBRATIONS := {25: "lab_milestone", 50: "lab_milestone_strong", 75: "lab_milestone_plus", 100: "lab_major",
	125: "lab_milestone", 150: "lab_milestone_strong", 175: "lab_milestone_plus", 200: "lab_major"}

static var active := false
## QA session (a jump, or the QA build): production Levels 1-300, QA save.
static var qa := false
## Level the QA session started from (0 = no QA session; while `qa` and
## still 0 before the save is loaded: resume the stored session).
static var qa_level := 0
static var _qa_reset := false
static var complete_open := false
static var _log: Array = []
static var _level_start_ms := 0
static var _card_shown_ms := 0


## The lab mode asked for by a page's query string and hash: "reset", "1",
## a QA jump level "2".."300", or "" (off). Parses key=value pairs exactly (any order, any other
## parameters such as itch.io's ?v=, URL-encoded), so "xexperiencelab=1"
## or "experiencelab=0" never switch it on.
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
			if value == "reset":
				return "reset"
			if value in ["", "1", "true", "yes", "on"]:
				mode = "1"
			elif value.is_valid_int() and int(value) >= 2 and int(value) <= QA_LAST_LEVEL:
				mode = str(int(value))
	return mode


## "" (not asked for), "1", "reset", a QA jump level "2".."300", or (QA
## build only) "qa" = resume the stored QA session.
static func requested() -> String:
	if BuildFlags.player_build():
		return ""  # player build: developer pages off
	var m := _requested_mode()
	if BuildFlags.qa_build() and not (m.is_valid_int() and int(m) >= 2):
		return "qa"  # QA build: always a QA session, never the normal save
	return m


static func _requested_mode() -> String:
	var args := OS.get_cmdline_user_args()
	if "--" + PARAM + "=reset" in args:
		return "reset"
	if "--" + PARAM in args or "--" + PARAM + "=1" in args:
		return "1"
	for a in args:
		if a.begins_with("--" + PARAM + "="):
			var m := parse_mode("?" + a.substr(2))
			if m != "":
				return m
	var loc := _location()
	if loc == null:
		return ""
	return parse_mode(str(loc.search), str(loc.hash))


## True when the page asks to restart the QA session (&qareset=1, or the
## headless --qareset).
static func parse_qa_reset(search: String, fragment: String = "") -> bool:
	for part in [search, fragment]:
		var text := String(part).strip_edges()
		while text.begins_with("?") or text.begins_with("#"):
			text = text.substr(1)
		for pair in text.split("&", false):
			var key := pair.get_slice("=", 0).uri_decode().strip_edges().to_lower()
			var value := (pair.substr(pair.find("=") + 1) if pair.contains("=") else "1").uri_decode().strip_edges().to_lower()
			if key == QA_RESET_PARAM and value in ["", "1", "true", "yes", "on"]:
				return true
	return false


static func _location() -> JavaScriptObject:
	if not OS.has_feature("web"):
		return null
	return JavaScriptBridge.get_interface("location")


## Removes &qareset from the address bar (history.replaceState: no reload),
## so a later Safari reload resumes the restarted session.
static func _drop_reset_param() -> void:
	var loc := _location()
	var history := JavaScriptBridge.get_interface("history") if loc != null else null
	if history == null:
		return
	var parts := []
	for pair in str(loc.search).trim_prefix("?").split("&", false):
		if pair.get_slice("=", 0).uri_decode().strip_edges().to_lower() != QA_RESET_PARAM:
			parts.append(pair)
	history.replaceState(null, "", str(loc.pathname) + ("?" + "&".join(parts) if not parts.is_empty() else "") + str(loc.hash))


## Points level loading and the save at the lab's own files. Must run
## before the save is loaded (first thing in GameManager._ready).
static func apply(mode: String) -> void:
	active = true
	complete_open = false
	# TWINS (Lab 176-199): the "!" token in the lab's own level files only
	# (Social / Friend parsing still rejects it; production never has it).
	LevelManager.dev_twins = true
	qa = mode == "qa" or (mode.is_valid_int() and int(mode) >= 2)
	if qa:
		# The frozen production Levels 1-300 (no override_dir) in the QA save.
		qa_level = int(mode) if mode.is_valid_int() else 0
		_qa_reset = "--" + QA_RESET_PARAM in OS.get_cmdline_user_args()
		var loc := _location()
		if loc != null:
			_qa_reset = _qa_reset or parse_qa_reset(str(loc.search), str(loc.hash))
		PlayerProgress.default_path = QA_SAVE_PATH
		PlayerProgress.mirror_key = QA_MIRROR_KEY
		PlayerProgress.beacon_key = QA_BEACON_KEY
		Diagnostics.key_prefix = "chain_escape_qa_"
		_log = []  # in memory only: the lab log is not touched
		print("[ExperienceLab] QA session (%s%s): Levels 1-%d, QA save %s" % [mode, ", reset" if _qa_reset else "", QA_LAST_LEVEL, QA_SAVE_PATH])
		return
	LevelManager.override_dir = LEVEL_DIR
	LevelManager.override_last = LAST_LEVEL
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
		print("[ExperienceLab] reset: lab save and log wiped")
	_log = _read_log()
	print("[ExperienceLab] active (%s): levels 1-%d from %s, save %s" % [mode, LAST_LEVEL, LEVEL_DIR, SAVE_PATH])


## QA session start (GameManager._ready, right after the save is loaded):
## RESUMES the stored QA session when it started from the same Level (a
## Safari reload or an evicted tab reopens the same URL); otherwise - a new
## checkpoint, &qareset=1, no or unreadable QA save - wipes the QA save and
## seeds a fresh session at Level N. Returns the progress to play with.
static func qa_session(progress: PlayerProgress, levels: LevelManager) -> PlayerProgress:
	var origin := int(progress.extra("qa", "origin", 0)) if progress.existed and not progress.hold_writes else 0
	if qa_level == 0:
		qa_level = origin if origin > 0 else 1  # QA build without N: the stored session
	if origin == qa_level and not _qa_reset:
		print("[ExperienceLab] QA session resumed (started at Level %d, now Level %d)" % [qa_level, progress.current_level])
		return progress
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		if FileAccess.file_exists(QA_SAVE_PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(QA_SAVE_PATH + suffix))
	if OS.has_feature("web"):
		for key in [QA_MIRROR_KEY, QA_BEACON_KEY]:
			WebBridge.ls_set(key, "")
	progress = PlayerProgress.new().load_from_disk()
	seed_qa(progress, levels)
	if _qa_reset:
		_drop_reset_param()
	print("[ExperienceLab] QA session started at Level %d%s" % [qa_level, " (reset)" if _qa_reset else ""])
	return progress


## QA jump: the fresh QA save holds what a player arriving at Level
## `qa_level` would have - Levels 1..N-1 cleared (score 0, no stars, so no
## coins or stars are invented), the Chapters before N's complete, and the
## one-time tips of the earlier levels seen (the Lab 13 lock lesson only
## when N > 13). Level N itself is first-time: its lesson / hint, its
## first clear, its milestone and its Chapter Complete all behave normally.
static func seed_qa(progress: PlayerProgress, levels: LevelManager) -> void:
	var n := qa_level
	for i in range(1, n):
		progress.best_scores[i] = 0
		progress.best_stars[i] = 0
	progress.highest_completed = n - 1
	progress.last_completed_level = n - 1
	progress.highest_unlocked = n
	progress.current_level = n
	for c in range(1, Chapters.chapter_of(n)):
		progress.completed_chapters.append(c)
	for level_number in LESSONS:
		if level_number < n:
			progress.tips_seen.append("lesson_" + String(LESSONS[level_number]))
	for i in range(1, n):
		var data := levels.load_level(i)
		if data == null:
			continue
		for rarity in [BlockData.Rarity.GOLD, BlockData.Rarity.SILVER]:
			var tip: String = BlockData.RARITY_NAMES[rarity]
			if not progress.tips_seen.has(tip) and data.blocks.any(func(b): return b.rarity == rarity):
				progress.tips_seen.append(tip)
		# A level with its own hint marks its Second Era mechanic as explained
		# (as GameManager.start_level does), e.g. the Switch at Lab 101 and
		# the Chain Gate at Lab 121.
		if data.hint != "":
			for pair in [["switch", data.blocks.any(func(b): return b.is_switch())], ["gate", data.blocks.any(func(b): return b.is_gate())],
					["armor", data.blocks.any(func(b): return b.armored)]]:
				if pair[1] and not progress.tips_seen.has(pair[0]):
					progress.tips_seen.append(pair[0])
	progress.set_extra("qa", "origin", n)
	progress.save()
	print("[ExperienceLab] QA save seeded: cleared 1-%d, chapters %s, tips %s" % [n - 1, progress.completed_chapters, progress.tips_seen])


## The lab-only "end of this test build" screen (after Lab Level 200 - a
## temporary lab boundary). `on_close` opens Level Select (the lab's 1-200).
static func show_complete(host: Node, on_close: Callable) -> void:
	complete_open = true
	event("lab_complete", LAST_LEVEL)
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.name = "ExperienceLabComplete"
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
		l.custom_minimum_size = Vector2(0, 0)
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
	if _log.size() > 2000:
		_log = _log.slice(_log.size() - 2000)
	print("[ExperienceLab] " + JSON.stringify(e))
	_write_log()


## Per-level summary for the debug panel (tap the title 5 times).
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
	var out := PackedStringArray(["EXPERIENCE LAB  (level: starts/restarts  clears  mistakes  undos  hints  first-clear secs  secs to NEXT)"])
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
	if qa_level > 0:
		return  # QA jump: the normal lab log is left as it is
	var text := JSON.stringify(_log)
	if OS.has_feature("web"):
		WebBridge.ls_set(LOG_KEY, text)
	var f := FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
