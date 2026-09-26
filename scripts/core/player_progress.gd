class_name PlayerProgress
extends RefCounted
## Everything that persists between sessions (a real save file).
##
## Save format is VERSIONED ([meta] version). Loading runs migrations from
## older versions, keeps any keys it does not know (so a newer save opened
## by an older build is not wiped), writes atomically (tmp file + rename)
## and falls back to the previous save (.bak) if the main file is damaged.
##
## v1 (v0.2-v0.3): progress, scores, stars, settings.
## v2 (v0.4): + coins, inventory, claimed chests, completed worlds,
##            achievements, perfect levels, last played level.

const SAVE_VERSION := 2

## Tests point this somewhere else so they never touch real progress.
static var default_path := "user://progress.cfg"

var path: String
var version: int = SAVE_VERSION
## Last played level (the CONTINUE target).
var current_level: int = 1
var highest_completed: int = 0
## level number -> best score / best stars (0..3)
var best_scores: Dictionary = {}
var best_stars: Dictionary = {}
## Levels completed PERFECT at least once (first PERFECT pays coins).
var perfect_levels: Array = []
var coins: int = 0
## Booster inventory: {"hint": n, "hammer": n}
var inventory: Dictionary = {"hint": 0, "hammer": 0}
var claimed_chests: Array = []
var completed_worlds: Array = []
var achievements: Array = []
var music_on: bool = true
var sfx_on: bool = true
var haptics_on: bool = true
## True if a save file existed when loaded (drives CONTINUE on the title).
var existed: bool = false

var _cfg := ConfigFile.new()


func _init(p_path: String = "") -> void:
	path = p_path if p_path != "" else default_path


func load_from_disk() -> PlayerProgress:
	_cfg = ConfigFile.new()
	var err := _cfg.load(path)
	if err != OK and FileAccess.file_exists(path + ".bak"):
		_cfg = ConfigFile.new()
		err = _cfg.load(path + ".bak")
	if err != OK:
		_start_fresh()
		return self
	existed = true
	version = int(_cfg.get_value("meta", "version", 1))
	current_level = int(_cfg.get_value("progress", "current_level", 1))
	highest_completed = int(_cfg.get_value("progress", "highest_completed", 0))
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
	_migrate()
	return self


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
	version = SAVE_VERSION


func _start_fresh() -> void:
	var eco := Economy.config()
	coins = int(eco["starting_coins"])
	inventory = eco["starting_inventory"].duplicate()
	version = SAVE_VERSION
	existed = false


func save() -> void:
	# Known keys are written into the loaded ConfigFile, so unknown keys
	# from other versions survive.
	_cfg.set_value("meta", "version", SAVE_VERSION)
	_cfg.set_value("progress", "current_level", current_level)
	_cfg.set_value("progress", "highest_completed", highest_completed)
	_cfg.set_value("progress", "completed_worlds", completed_worlds)
	_cfg.set_value("progress", "achievements", achievements)
	_cfg.set_value("progress", "perfect_levels", perfect_levels)
	_cfg.set_value("settings", "music", music_on)
	_cfg.set_value("settings", "sfx", sfx_on)
	_cfg.set_value("settings", "haptics", haptics_on)
	_cfg.set_value("economy", "coins", coins)
	_cfg.set_value("economy", "inventory", inventory)
	_cfg.set_value("economy", "claimed_chests", claimed_chests)
	for n in best_scores:
		_cfg.set_value("scores", str(n), best_scores[n])
	for n in best_stars:
		_cfg.set_value("stars", str(n), best_stars[n])
	var tmp := path + ".tmp"
	if _cfg.save(tmp) != OK:
		return
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		_cfg.save(path)
		return
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			dir.remove(path.get_file() + ".bak")
		dir.rename(path.get_file(), path.get_file() + ".bak")
	dir.rename(tmp.get_file(), path.get_file())
	existed = true


func _int_section(section: String) -> Dictionary:
	var out := {}
	if _cfg.has_section(section):
		for key in _cfg.get_section_keys(section):
			out[int(key)] = int(_cfg.get_value(section, key))
	return out


func best_score(number: int) -> int:
	return best_scores.get(number, 0)


func stars_for(number: int) -> int:
	return best_stars.get(number, 0)


## A level can be played if it is completed or the next one to beat.
func is_unlocked(number: int) -> bool:
	return number <= highest_unlocked()


func highest_unlocked() -> int:
	return highest_completed + 1


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
## "new_stars": bool, "first_perfect": bool}.
func record_result(number: int, score: int, stars: int, perfect: bool = false) -> Dictionary:
	var prev: int = best_scores.get(number, 0)
	var prev_stars: int = best_stars.get(number, 0)
	var first := not best_scores.has(number)
	var first_perfect := perfect and not perfect_levels.has(number)
	var out := {"new_best": not first and score > prev, "first_clear": first,
		"previous_best": prev, "previous_stars": prev_stars, "new_stars": stars > prev_stars,
		"first_perfect": first_perfect}
	best_scores[number] = maxi(prev, score)
	best_stars[number] = maxi(prev_stars, stars)
	if first_perfect:
		perfect_levels.append(number)
	highest_completed = maxi(highest_completed, number)
	save()
	return out
