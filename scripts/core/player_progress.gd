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
## v3 (v0.5): + completed Chapters, collected Silver/Gold reward blocks,
##            coins earned per Chapter, one-time tips seen. v0.4 Worlds
##            (20 levels) become two completed Chapters each; chest ids are
##            unchanged (they were already per 10 levels).

const SAVE_VERSION := 3

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
	completed_chapters = _cfg.get_value("chapters", "completed", [])
	reward_blocks = _cfg.get_value("chapters", "reward_blocks", [])
	tips_seen = _cfg.get_value("chapters", "tips_seen", [])
	chapter_coins = {}
	var cc: Dictionary = _cfg.get_value("chapters", "coins", {})
	for k in cc:
		chapter_coins[int(k)] = int(cc[k])
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
	version = SAVE_VERSION


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
	_cfg.set_value("chapters", "completed", completed_chapters)
	_cfg.set_value("chapters", "reward_blocks", reward_blocks)
	_cfg.set_value("chapters", "tips_seen", tips_seen)
	_cfg.set_value("chapters", "coins", chapter_coins)
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
