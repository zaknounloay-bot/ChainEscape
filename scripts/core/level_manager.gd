class_name LevelManager
extends Node
## Loads level definitions from res://levels/level_XX.json.
##
## Two equivalent JSON layouts are accepted, so designers can pick whichever
## is quicker to write:
##
## 1) "map" (recommended) - one string per row, space separated cells.
##    "."  = empty cell
##    "R>" = color letter (R,B,G,Y,P) + arrow (^ v < >)
##      { "name": "Hello", "map": ["R> . .", ". B^ ."] }
##
## 2) Explicit block list:
##      { "rows": 4, "columns": 4,
##        "blocks": [ { "row": 0, "column": 1, "color": "red", "direction": "up" } ] }
##
## Levels are discovered by number, so adding level_11.json is all it takes
## to add a level.

const LEVEL_PATH := "res://levels/level_%02d.json"
const SAVE_PATH := "user://progress.cfg"

const COLOR_LETTERS := {"R": "red", "B": "blue", "G": "green", "Y": "yellow", "P": "purple"}

var level_count: int = 0


func _ready() -> void:
	level_count = 0
	while FileAccess.file_exists(LEVEL_PATH % (level_count + 1)):
		level_count += 1
	if level_count == 0:
		push_error("No levels found at %s" % LEVEL_PATH)


func load_level(number: int) -> LevelData:
	var path := LEVEL_PATH % number
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Could not read level file %s" % path)
		return null
	var json = JSON.parse_string(text)
	if typeof(json) != TYPE_DICTIONARY:
		push_error("Level file %s is not a JSON object" % path)
		return null
	return parse_level(json, number)


static func parse_level(json: Dictionary, number: int = 0) -> LevelData:
	var level := LevelData.new()
	level.number = number
	level.name = json.get("name", "Level %d" % number)
	level.hint = json.get("hint", "")
	level.blocked_hint = json.get("blocked_hint", "")
	if json.has("map"):
		_parse_map(json["map"], level)
	else:
		_parse_block_list(json, level)
	return level


static func _parse_map(map: Array, level: LevelData) -> void:
	level.rows = map.size()
	level.columns = 0
	var next_id := 0
	for r in map.size():
		var tokens: PackedStringArray = String(map[r]).split(" ", false)
		level.columns = max(level.columns, tokens.size())
		for c in tokens.size():
			var t := tokens[c]
			if t == "." or t == "..":
				continue
			if t.length() != 2 or not COLOR_LETTERS.has(t[0].to_upper()) or not Direction.MAP_CHARS.has(t[1]):
				push_error("Level %d: bad map token '%s' at row %d col %d" % [level.number, t, r, c])
				continue
			var color: String = COLOR_LETTERS[t[0].to_upper()]
			level.blocks.append(BlockData.new(next_id, Vector2i(c, r), color, Direction.MAP_CHARS[t[1]]))
			next_id += 1


static func _parse_block_list(json: Dictionary, level: LevelData) -> void:
	level.rows = int(json.get("rows", 0))
	level.columns = int(json.get("columns", 0))
	var next_id := 0
	for b in json.get("blocks", []):
		var cell := Vector2i(int(b["column"]), int(b["row"]))
		level.blocks.append(BlockData.new(next_id, cell, String(b["color"]), Direction.from_string(String(b["direction"]))))
		next_id += 1


# --- Progress --------------------------------------------------------------

func load_saved_level() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 1
	return clampi(int(cfg.get_value("progress", "current_level", 1)), 1, max(level_count, 1))


func save_current_level(number: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level", number)
	cfg.save(SAVE_PATH)
