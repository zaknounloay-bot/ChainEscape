class_name PlayerProgress
extends RefCounted
## Everything that persists between sessions: level progress, hint tokens
## and settings. Stored in a ConfigFile at `path`.

## Tests point this somewhere else so they never touch real progress.
static var default_path := "user://progress.cfg"

## Hint tokens a brand-new player starts with (covers levels 1-10).
const STARTING_HINTS := 1

var path: String
var current_level: int = 1
var highest_completed: int = 0
var hint_tokens: int = STARTING_HINTS
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
		hint_tokens = int(cfg.get_value("progress", "hint_tokens", STARTING_HINTS))
		music_on = bool(cfg.get_value("settings", "music", true))
		sfx_on = bool(cfg.get_value("settings", "sfx", true))
		haptics_on = bool(cfg.get_value("settings", "haptics", true))
	return self


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level", current_level)
	cfg.set_value("progress", "highest_completed", highest_completed)
	cfg.set_value("progress", "hint_tokens", hint_tokens)
	cfg.set_value("settings", "music", music_on)
	cfg.set_value("settings", "sfx", sfx_on)
	cfg.set_value("settings", "haptics", haptics_on)
	cfg.save(path)


## Records a completed level. Returns how many hint tokens were awarded
## (only the first completion of a level can award tokens).
func complete_level(number: int) -> int:
	var awarded := 0
	if number > highest_completed:
		highest_completed = number
		awarded = hints_awarded_for(number)
		hint_tokens += awarded
	save()
	return awarded


## Hint economy: roughly 1 token per 10 levels for 1-10 (the starting
## token), 1 per 5 levels for 11-20, then 1 per 3 levels from 21 on.
static func hints_awarded_for(level_number: int) -> int:
	if level_number <= 10:
		return 0
	if level_number <= 20:
		return 1 if level_number % 5 == 0 else 0
	return 1 if level_number % 3 == 0 else 0
