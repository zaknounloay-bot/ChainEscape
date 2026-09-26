class_name PlayerProgress
extends RefCounted
## Everything that persists between sessions: level progress, best score
## and best stars per level, and settings. Stored in a ConfigFile.

## Tests point this somewhere else so they never touch real progress.
static var default_path := "user://progress.cfg"

var path: String
var current_level: int = 1
var highest_completed: int = 0
## level number -> best score / best stars (0..3)
var best_scores: Dictionary = {}
var best_stars: Dictionary = {}
var music_on: bool = true
var sfx_on: bool = true
var haptics_on: bool = true


func _init(p_path: String = "") -> void:
	path = p_path if p_path != "" else default_path


func load_from_disk() -> PlayerProgress:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		current_level = int(cfg.get_value("progress", "current_level", 1))
		highest_completed = int(cfg.get_value("progress", "highest_completed", 0))
		music_on = bool(cfg.get_value("settings", "music", true))
		sfx_on = bool(cfg.get_value("settings", "sfx", true))
		haptics_on = bool(cfg.get_value("settings", "haptics", true))
		if cfg.has_section("scores"):
			for key in cfg.get_section_keys("scores"):
				best_scores[int(key)] = int(cfg.get_value("scores", key))
		if cfg.has_section("stars"):
			for key in cfg.get_section_keys("stars"):
				best_stars[int(key)] = int(cfg.get_value("stars", key))
	return self


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level", current_level)
	cfg.set_value("progress", "highest_completed", highest_completed)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sfx", sfx_on)
	cfg.set_value("settings", "haptics", haptics_on)
	for n in best_scores:
		cfg.set_value("scores", str(n), best_scores[n])
	for n in best_stars:
		cfg.set_value("stars", str(n), best_stars[n])
	cfg.save(path)


func best_score(number: int) -> int:
	return best_scores.get(number, 0)


func stars_for(number: int) -> int:
	return best_stars.get(number, 0)


## A level can be played if it is completed or the next one to beat.
func is_unlocked(number: int) -> bool:
	return number <= highest_completed + 1


func total_stars() -> int:
	var t := 0
	for n in best_stars:
		t += best_stars[n]
	return t


## Records a finished level. Returns {"new_best": bool (beat an earlier
## score), "first_clear": bool, "previous_best": int, "new_stars": bool}.
func record_result(number: int, score: int, stars: int) -> Dictionary:
	var prev: int = best_scores.get(number, 0)
	var prev_stars: int = best_stars.get(number, 0)
	var first := not best_scores.has(number)
	var out := {"new_best": not first and score > prev, "first_clear": first,
		"previous_best": prev, "new_stars": stars > prev_stars}
	best_scores[number] = maxi(prev, score)
	best_stars[number] = maxi(prev_stars, stars)
	highest_completed = maxi(highest_completed, number)
	save()
	return out
