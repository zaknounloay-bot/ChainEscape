class_name PlayerProgress
extends RefCounted
## The ONE authoritative player-progress model: everything that persists
## between sessions lives here and nowhere else.
##
## Save format is VERSIONED ([meta] version) and self-checking:
##   * every save gets a sequence number (meta/seq) and a timestamp
##   * it is written atomically (tmp file + rename, previous file kept as
##     .bak) AND, on the Web, mirrored synchronously into localStorage, so a
##     closed tab, a crash or a slow IndexedDB sync can't lose the last save
##   * loading reads EVERY copy (main, .bak, .tmp, Web mirror), keeps the
##     newest one that is intact, and never silently resets: an unreadable
##     file is quarantined (copied aside) and salvaged line by line
##   * unlocks never go backwards: highest_unlocked is stored explicitly
##     and also re-derived from completions and best scores
##
## v1 (v0.2-v0.3): progress, scores, stars, settings.
## v2 (v0.4): + coins, inventory, claimed chests, completed worlds,
##            achievements, perfect levels, last played level.
## v3 (v0.5): + completed Chapters, collected Silver/Gold reward blocks,
##            coins earned per Chapter, one-time tips seen.
## v4 (v0.5.1): + explicit highest_unlocked, last_completed_level,
##            total_score (sum of best scores, cross-checked), save sequence
##            number and timestamp, Web localStorage mirror.

const SAVE_VERSION := 4
## localStorage key of the Web mirror (a full copy of the save file).
const MIRROR_KEY := "chain_escape_save"

## Tests point this somewhere else so they never touch real progress.
static var default_path := "user://progress.cfg"
## Print "[Save] ..." lines for every load and write (diagnostics).
static var log_enabled: bool = true

var path: String
var version: int = SAVE_VERSION
## Save sequence number: +1 on every write. Picks the newest copy on load.
var seq: int = 0
var saved_unix: int = 0
## Last played level (the CONTINUE target).
var current_level: int = 1
var highest_completed: int = 0
## The last level the player finished (any clear, including replays).
var last_completed_level: int = 0
## Every level up to this one is playable. Stored explicitly and only ever
## raised; also re-derived on load so a partial save can't relock levels.
var highest_unlocked: int = 1
## level number -> best score / best stars (0..3)
var best_scores: Dictionary = {}
var best_stars: Dictionary = {}
## Levels completed PERFECT at least once (first PERFECT pays coins).
var perfect_levels: Array = []
var coins: int = 0
## Booster inventory: {"hint": n, "hammer": n}
var inventory: Dictionary = {"hint": 0, "hammer": 0}
var claimed_chests: Array = []
## v0.4 World milestones (kept only for migration / older builds).
var completed_worlds: Array = []
## Chapters whose "Chapter Complete" moment and bonus already happened.
var completed_chapters: Array = []
## Collected reward blocks, "level:block_id" (each pays once per save).
var reward_blocks: Array = []
## Chapter -> coins earned in it (for the Chapter Complete summary).
var chapter_coins: Dictionary = {}
## One-time explanations already shown ("silver", "gold", ...).
var tips_seen: Array = []
var achievements: Array = []
var music_on: bool = true
var sfx_on: bool = true
var haptics_on: bool = true
## True if a save existed when loaded (drives CONTINUE on the title).
var existed: bool = false
## Where the loaded data came from: "file", "bak", "tmp", "mirror",
## "salvaged:<source>", "new" or "unreadable" (diagnostics).
var load_source: String = "new"
## Problems met while loading (corrupt copies, integrity fixes...).
var load_issues: Array = []

var _cfg := ConfigFile.new()


func _init(p_path: String = "") -> void:
	path = p_path if p_path != "" else default_path


# --- Load ------------------------------------------------------------------

func load_from_disk() -> PlayerProgress:
	load_issues = []
	var best: ConfigFile = null
	var best_rank := []
	var any_found := false
	var seen := PackedStringArray()
	for c in _candidates():
		any_found = true
		var cfg := ConfigFile.new()
		var source: String = c["source"]
		if cfg.parse(c["text"]) != OK:
			load_issues.append("%s unreadable" % source)
			_quarantine(c["text"], source)
			cfg = _salvage(c["text"])
			if cfg == null:
				continue
			source = "salvaged:" + source
		var rank := _rank(cfg)
		seen.append("%s#%d" % [source, rank[0]])
		if best == null or _rank_less(best_rank, rank):
			best = cfg
			best_rank = rank
			load_source = source
	if best == null:
		# Nothing readable. Start fresh WITHOUT touching the old files
		# (unreadable ones were copied aside above).
		_start_fresh()
		load_source = "unreadable" if any_found else "new"
		_log("load: %s -> fresh progress%s" % [load_source, " (%s)" % ", ".join(load_issues) if not load_issues.is_empty() else ""])
		return self
	_cfg = best
	existed = true
	version = int(_cfg.get_value("meta", "version", 1))
	seq = int(_cfg.get_value("meta", "seq", 0))
	saved_unix = int(_cfg.get_value("meta", "saved_unix", 0))
	current_level = int(_cfg.get_value("progress", "current_level", 1))
	highest_completed = int(_cfg.get_value("progress", "highest_completed", 0))
	last_completed_level = int(_cfg.get_value("progress", "last_completed_level", highest_completed))
	highest_unlocked = int(_cfg.get_value("progress", "highest_unlocked", 1))
	music_on = bool(_cfg.get_value("settings", "music", true))
	sfx_on = bool(_cfg.get_value("settings", "sfx", true))
	haptics_on = bool(_cfg.get_value("settings", "haptics", true))
	best_scores = _int_section("scores")
	best_stars = _int_section("stars")
	coins = int(_cfg.get_value("economy", "coins", 0))
	inventory = {"hint": 0, "hammer": 0}
	inventory.merge(_cfg.get_value("economy", "inventory", {}), true)
	claimed_chests = _cfg.get_value("economy", "claimed_chests", [])
	completed_worlds = _cfg.get_value("progress", "completed_worlds", [])
	achievements = _cfg.get_value("progress", "achievements", [])
	perfect_levels = _cfg.get_value("progress", "perfect_levels", [])
	completed_chapters = _cfg.get_value("chapters", "completed", [])
	reward_blocks = _cfg.get_value("chapters", "reward_blocks", [])
	tips_seen = _cfg.get_value("chapters", "tips_seen", [])
	chapter_coins = {}
	var cc: Dictionary = _cfg.get_value("chapters", "coins", {})
	for k in cc:
		chapter_coins[int(k)] = int(cc[k])
	var stored_total := int(_cfg.get_value("progress", "total_score", -1))
	_migrate()
	_check_integrity(stored_total)
	load_issues.push_front("copies: " + " ".join(seen))
	_log("load: source=%s version=%d seq=%d last_played=%d highest_completed=%d highest_unlocked=%d total_score=%d coins=%d stars=%d%s" % [
		load_source, version, seq, current_level, highest_completed, highest_unlocked, total_score(), coins, total_stars(),
		" issues=[%s]" % ", ".join(load_issues) if not load_issues.is_empty() else ""])
	return self


## Every copy of the save that exists: main file, backup, unfinished temp
## file and (Web) the localStorage mirror. [{source, text}]
func _candidates() -> Array:
	var out := []
	for pair in [["file", path], ["bak", path + ".bak"], ["tmp", path + ".tmp"]]:
		if FileAccess.file_exists(pair[1]):
			var text := FileAccess.get_file_as_string(pair[1])
			if text.strip_edges() != "":
				out.append({"source": pair[0], "text": text})
			else:
				load_issues.append("%s empty" % pair[0])
	var mirror := _mirror_read()
	if mirror != "":
		out.append({"source": "mirror", "text": mirror})
	return out


## Newest first: save sequence, then how far the player got, then stars
## and coins (for files written before sequence numbers existed).
func _rank(cfg: ConfigFile) -> Array:
	var stars := 0
	if cfg.has_section("stars"):
		for k in cfg.get_section_keys("stars"):
			stars += int(cfg.get_value("stars", k, 0))
	return [int(cfg.get_value("meta", "seq", 0)), int(cfg.get_value("progress", "highest_completed", 0)),
		stars, int(cfg.get_value("economy", "coins", 0))]


static func _rank_less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


## Keeps every entry that still parses (sections and key=value pairs,
## including values Godot writes over several lines, like dictionaries), so
## a damaged file loses only the damaged entries.
func _salvage(text: String) -> ConfigFile:
	var lines := text.split("\n")
	var kept := PackedStringArray()
	var entries := 0
	var i := 0
	while i < lines.size():
		var l := lines[i].strip_edges()
		i += 1
		if l.begins_with("[") and l.ends_with("]") and l.find("=") == -1:
			kept.append(l)
			continue
		var eq := l.find("=")
		if eq <= 0:
			continue
		# Multi-line value: join lines until brackets balance (max 200).
		var entry := l
		var guard := 0
		while _open_brackets(entry) > 0 and i < lines.size() and guard < 200:
			entry += "\n" + lines[i]
			i += 1
			guard += 1
		var test := ConfigFile.new()
		if test.parse("[x]\n" + entry) == OK:
			kept.append(entry)
			entries += 1
	if entries == 0:
		return null
	var cfg := ConfigFile.new()
	if cfg.parse("\n".join(kept)) != OK:
		return null
	load_issues.append("salvaged %d entries" % entries)
	return cfg


static func _open_brackets(t: String) -> int:
	return t.count("{") + t.count("[") - t.count("}") - t.count("]")


## Copies an unreadable save aside (never overwritten) for recovery.
func _quarantine(text: String, source: String) -> void:
	# Named by content: the same damaged copy is kept once, not per launch.
	var dest := "%s.corrupt-%s-%s" % [path, source, text.md5_text().left(8)]
	var f := FileAccess.open(dest, FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	_log("load: %s copy unreadable - kept as %s" % [source, dest.get_file()])


## Upgrades older saves in place. Never removes player progress.
func _migrate() -> void:
	if version < 2:
		# v0.3 -> v0.4: introduce the economy with the starting grant, and
		# derive already-perfect levels from 3-star results.
		var eco := Economy.config()
		coins = int(eco["starting_coins"])
		inventory = eco["starting_inventory"].duplicate()
		for n in best_stars:
			if best_stars[n] >= 3:
				perfect_levels.append(n)
	if version < 3:
		# v0.4 -> v0.5: 20-level Worlds become 10-level Chapters. A completed
		# World already paid its bonus, so both of its Chapters count as
		# completed (no second payment, no surprise "Chapter Complete" card
		# for old progress). Chapters that were fully cleared inside an
		# unfinished World never paid anything: they get their bonus now,
		# once, silently.
		for w in completed_worlds:
			for c in [2 * int(w) - 1, 2 * int(w)]:
				if not completed_chapters.has(c):
					completed_chapters.append(c)
		var c := 1
		while Chapters.chapter_range(c).x <= highest_completed:
			if not completed_chapters.has(c) and _all_cleared(Chapters.chapter_range(c)):
				completed_chapters.append(c)
				add_coins(int(Economy.config()["rewards"]["chapter_complete"]), c)
			c += 1
	# v3 -> v4: highest_unlocked / last_completed_level are derived in
	# _check_integrity(); nothing else changes.
	if version < SAVE_VERSION:
		load_issues.append("migrated v%d -> v%d" % [version, SAVE_VERSION])
	version = SAVE_VERSION


## Repairs inconsistencies instead of failing. Progress only ever grows:
## a level with a best score counts as completed, and everything up to the
## highest completed level + 1 is unlocked.
func _check_integrity(stored_total: int) -> void:
	var max_scored := 0
	for n in best_scores:
		max_scored = maxi(max_scored, int(n))
	for n in best_stars:
		if best_stars[n] > 0:
			max_scored = maxi(max_scored, int(n))
	if max_scored > highest_completed:
		load_issues.append("highest_completed %d -> %d (from best scores)" % [highest_completed, max_scored])
		highest_completed = max_scored
	var unlocked := maxi(highest_unlocked, highest_completed + 1)
	if unlocked != highest_unlocked:
		highest_unlocked = unlocked
	last_completed_level = clampi(last_completed_level, 0, highest_completed)
	current_level = maxi(current_level, 1)  # the game clamps to its level count
	coins = maxi(coins, 0)
	for k in inventory:
		inventory[k] = maxi(int(inventory[k]), 0)
	if stored_total >= 0 and stored_total != total_score():
		load_issues.append("total_score %d recomputed as %d" % [stored_total, total_score()])


func _all_cleared(rg: Vector2i) -> bool:
	for n in range(rg.x, rg.y + 1):
		if not best_scores.has(n):
			return false
	return true


func _start_fresh() -> void:
	var eco := Economy.config()
	coins = int(eco["starting_coins"])
	inventory = eco["starting_inventory"].duplicate()
	version = SAVE_VERSION
	existed = false


# --- Save --------------------------------------------------------------------

## Writes the save atomically (tmp + rename, previous copy kept as .bak)
## and mirrors it to localStorage on the Web. Returns true if at least one
## durable copy was written.
func save() -> bool:
	seq += 1
	saved_unix = int(Time.get_unix_time_from_system())
	# Known keys are written into the loaded ConfigFile, so unknown keys
	# from other versions survive.
	_cfg.set_value("meta", "version", SAVE_VERSION)
	_cfg.set_value("meta", "seq", seq)
	_cfg.set_value("meta", "saved_unix", saved_unix)
	_cfg.set_value("progress", "current_level", current_level)
	_cfg.set_value("progress", "highest_completed", highest_completed)
	_cfg.set_value("progress", "last_completed_level", last_completed_level)
	_cfg.set_value("progress", "highest_unlocked", highest_unlocked)
	_cfg.set_value("progress", "total_score", total_score())
	_cfg.set_value("progress", "completed_worlds", completed_worlds)
	_cfg.set_value("progress", "achievements", achievements)
	_cfg.set_value("progress", "perfect_levels", perfect_levels)
	_cfg.set_value("settings", "music", music_on)
	_cfg.set_value("settings", "sfx", sfx_on)
	_cfg.set_value("settings", "haptics", haptics_on)
	_cfg.set_value("economy", "coins", coins)
	_cfg.set_value("economy", "inventory", inventory)
	_cfg.set_value("economy", "claimed_chests", claimed_chests)
	_cfg.set_value("chapters", "completed", completed_chapters)
	_cfg.set_value("chapters", "reward_blocks", reward_blocks)
	_cfg.set_value("chapters", "tips_seen", tips_seen)
	_cfg.set_value("chapters", "coins", chapter_coins)
	for n in best_scores:
		_cfg.set_value("scores", str(n), best_scores[n])
	for n in best_stars:
		_cfg.set_value("stars", str(n), best_stars[n])
	var text := _cfg.encode_to_text()
	var file_ok := _write_file(text)
	var mirror_ok := _mirror_write(text)
	existed = existed or file_ok or mirror_ok
	_log("write #%d: last_played=%d highest_completed=%d highest_unlocked=%d total_score=%d coins=%d file=%s%s" % [
		seq, current_level, highest_completed, highest_unlocked, total_score(), coins, "ok" if file_ok else "FAILED",
		(" mirror=%s" % ("ok" if mirror_ok else "FAILED")) if OS.has_feature("web") else ""])
	return file_ok or mirror_ok


func _write_file(text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("[Save] cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.close()
	# Verify before replacing the good copy.
	var check := ConfigFile.new()
	if check.parse(FileAccess.get_file_as_string(tmp)) != OK:
		push_warning("[Save] temp save did not verify - previous save kept")
		return false
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return _direct_write(text)
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			dir.remove(path.get_file() + ".bak")
		dir.rename(path.get_file(), path.get_file() + ".bak")
	if dir.rename(tmp.get_file(), path.get_file()) != OK:
		return _direct_write(text)
	return true


func _direct_write(text: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	return true


# --- Web mirror (localStorage) ------------------------------------------------

## localStorage writes are synchronous: the copy exists the moment save()
## returns, even if the tab is closed before Godot's IndexedDB sync runs.
## Also the only store left when the browser blocks IndexedDB.
func _mirror_write(text: String) -> bool:
	if not OS.has_feature("web") or path != default_path:
		return false
	var ok = JavaScriptBridge.eval("(function(){try{localStorage.setItem(%s,%s);return localStorage.getItem(%s)!==null}catch(e){return false}})()" % [
		JSON.stringify(MIRROR_KEY), JSON.stringify(text), JSON.stringify(MIRROR_KEY)], true)
	return ok == true


func _mirror_read() -> String:
	if not OS.has_feature("web") or path != default_path:
		return ""
	var v = JavaScriptBridge.eval("(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()" % JSON.stringify(MIRROR_KEY), true)
	return str(v) if v != null else ""


## Where saves can go right now (title warning, diagnostics).
static func storage_status() -> Dictionary:
	if not OS.has_feature("web"):
		return {"persistent": true, "userfs": true, "mirror": false, "ephemeral": false}
	var userfs := OS.is_userfs_persistent()
	var js = JavaScriptBridge.eval("JSON.stringify(window.ceAudio && window.ceAudio.storage ? window.ceAudio.storage() : {})", true)
	var st = JSON.parse_string(str(js))
	var info: Dictionary = st if typeof(st) == TYPE_DICTIONARY else {}
	var mirror: bool = info.get("localStorage", false)
	var ephemeral: bool = info.get("ephemeral", false)
	return {"persistent": (userfs or mirror) and not ephemeral, "userfs": userfs, "mirror": mirror,
		"ephemeral": ephemeral, "iframe": info.get("iframe", false), "cross_origin": info.get("crossOrigin", false)}


func _log(msg: String) -> void:
	if log_enabled:
		print("[Save] " + msg)


# --- Queries -------------------------------------------------------------------

func _int_section(section: String) -> Dictionary:
	var out := {}
	if _cfg.has_section(section):
		for key in _cfg.get_section_keys(section):
			out[int(key)] = int(_cfg.get_value(section, key))
	return out


## Coins EARNED (never bought): also counted per Chapter for the summary.
func add_coins(amount: int, chapter: int) -> void:
	if amount <= 0:
		return
	coins += amount
	chapter_coins[chapter] = int(chapter_coins.get(chapter, 0)) + amount


static func reward_key(level_number: int, block_id: int) -> String:
	return "%d:%d" % [level_number, block_id]


func has_reward_block(level_number: int, block_id: int) -> bool:
	return reward_blocks.has(reward_key(level_number, block_id))


## Reward block ids of a level already collected (for "spent" visuals).
func collected_rewards(level_number: int) -> Dictionary:
	var out := {}
	var prefix := "%d:" % level_number
	for k in reward_blocks:
		if String(k).begins_with(prefix):
			out[int(String(k).get_slice(":", 1))] = true
	return out


func best_score(number: int) -> int:
	return best_scores.get(number, 0)


func stars_for(number: int) -> int:
	return best_stars.get(number, 0)


## TOTAL SCORE = the sum of the best score of every completed level. It can
## only grow: a better run raises it by the improvement, a worse run or a
## replay changes nothing, moving to another level changes nothing.
func total_score() -> int:
	var t := 0
	for n in best_scores:
		t += int(best_scores[n])
	return t


## A level can be played if it is completed or the next one to beat.
func is_unlocked(number: int) -> bool:
	return number <= highest_unlocked


## True if the player has any progress worth continuing.
func has_progress() -> bool:
	return existed and (highest_completed > 0 or current_level > 1)


func total_stars() -> int:
	var t := 0
	for n in best_stars:
		t += best_stars[n]
	return t


## Records a finished level. Returns {"new_best": bool (beat an earlier
## score), "first_clear": bool, "previous_best": int, "previous_stars": int,
## "new_stars": bool, "first_perfect": bool, "total_before": int,
## "total_after": int, "total_gain": int}.
func record_result(number: int, score: int, stars: int, perfect: bool = false) -> Dictionary:
	var prev: int = best_scores.get(number, 0)
	var prev_stars: int = best_stars.get(number, 0)
	var first := not best_scores.has(number)
	var first_perfect := perfect and not perfect_levels.has(number)
	var total_before := total_score()
	var out := {"new_best": not first and score > prev, "first_clear": first,
		"previous_best": prev, "previous_stars": prev_stars, "new_stars": stars > prev_stars,
		"first_perfect": first_perfect}
	best_scores[number] = maxi(prev, score)
	best_stars[number] = maxi(prev_stars, stars)
	if first_perfect:
		perfect_levels.append(number)
	highest_completed = maxi(highest_completed, number)
	last_completed_level = number
	highest_unlocked = maxi(highest_unlocked, number + 1)
	out["total_before"] = total_before
	out["total_after"] = total_score()
	out["total_gain"] = out["total_after"] - total_before
	save()
	return out
