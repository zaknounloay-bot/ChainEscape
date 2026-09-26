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
##    "R>@" = same, but a SPINNER (turns clockwise when a neighbour escapes)
##    "R>?" = HIDDEN arrow (mystery): revealed when a neighbour escapes
##    "R>#G" = LOCKED: cannot escape while any green block remains
##    Modifiers can be combined in the order  @ ? #K  (spinners cannot be
##    hidden, and hidden blocks cannot be locked).
##      { "name": "Hello", "map": ["R> . .", ". B^ ."] }
##
## 2) Explicit block list:
##      { "rows": 4, "columns": 4,
##        "blocks": [ { "row": 0, "column": 1, "color": "red", "direction": "up",
##                      "spinner": true } ] }
##
## Optional keys: "name", "hint" (start text + finger), "hint_finger" (bool,
## default true), "blocked_hint", "hearts" (override the heart count),
## "hints" (override hints per level), "mystery" (bool), "stars"
## ({"two": rule, "three": rule, "score": target}; see ScoreRules).
##
## Levels are discovered by number, so adding level_11.json is all it takes
## to add a level.

const LEVEL_PATH := "res://levels/level_%02d.json"

const COLOR_LETTERS := {"R": "red", "B": "blue", "G": "green", "Y": "yellow", "P": "purple"}

var level_count: int = 0
var _mystery_cache: Dictionary = {}


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


## True if level `number` is a Mystery level (cached; for Level Select).
func is_mystery(number: int) -> bool:
	if not _mystery_cache.has(number):
		var l := load_level(number)
		_mystery_cache[number] = l != null and l.mystery
	return _mystery_cache[number]


static func parse_level(json: Dictionary, number: int = 0) -> LevelData:
	var level := LevelData.new()
	level.number = number
	level.name = json.get("name", "Level %d" % number)
	level.hint = json.get("hint", "")
	level.blocked_hint = json.get("blocked_hint", "")
	level.hint_finger = bool(json.get("hint_finger", true))
	level.hearts = int(json.get("hearts", -1))
	level.hints = int(json.get("hints", -1))
	level.star_rules = json.get("stars", {})
	if json.has("map"):
		_parse_map(json["map"], level)
	else:
		_parse_block_list(json, level)
	level.mystery = bool(json.get("mystery", false)) or level.blocks.any(func(b): return b.hidden)
	return level


static var _token_re: RegEx


static func _parse_map(map: Array, level: LevelData) -> void:
	if _token_re == null:
		_token_re = RegEx.create_from_string("^([RBGYPrbgyp])([\\^v<>])(@)?(\\?)?(#[RBGYPrbgyp])?$")
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
			var m := _token_re.search(t)
			if m == null:
				push_error("Level %d: bad map token '%s' at row %d col %d" % [level.number, t, r, c])
				continue
			var color: String = COLOR_LETTERS[m.get_string(1).to_upper()]
			var spinner := m.get_string(3) != ""
			var b := BlockData.new(next_id, Vector2i(c, r), color, Direction.MAP_CHARS[m.get_string(2)],
					BlockData.Kind.SPINNER if spinner else BlockData.Kind.NORMAL)
			b.hidden = m.get_string(4) != ""
			if m.get_string(5) != "":
				b.lock_color = COLOR_LETTERS[m.get_string(5).substr(1).to_upper()]
			_validate_block(b, level)
			level.blocks.append(b)
			next_id += 1


static func _validate_block(b: BlockData, level: LevelData) -> void:
	if b.hidden and b.is_spinner():
		push_error("Level %d: spinner at %s cannot be hidden" % [level.number, b.cell])
		b.hidden = false
	if b.hidden and b.lock_color != "":
		push_error("Level %d: hidden block at %s cannot be locked" % [level.number, b.cell])
		b.lock_color = ""
	if b.lock_color == b.color:
		push_error("Level %d: block at %s is locked by its own color" % [level.number, b.cell])
		b.lock_color = ""


static func _parse_block_list(json: Dictionary, level: LevelData) -> void:
	level.rows = int(json.get("rows", 0))
	level.columns = int(json.get("columns", 0))
	var next_id := 0
	for b in json.get("blocks", []):
		var cell := Vector2i(int(b["column"]), int(b["row"]))
		var kind := BlockData.Kind.SPINNER if b.get("spinner", false) else BlockData.Kind.NORMAL
		var block := BlockData.new(next_id, cell, String(b["color"]), Direction.from_string(String(b["direction"])), kind)
		block.lock_color = String(b.get("lock", ""))
		block.hidden = bool(b.get("hidden", false))
		_validate_block(block, level)
		level.blocks.append(block)
		next_id += 1


## Serializes a level back to the "map" JSON form (used by the generator).
static func to_json_text(level: LevelData) -> String:
	var grid := []
	for r in level.rows:
		var row := []
		row.resize(level.columns)
		row.fill(". ")
		grid.append(row)
	var letters := {}
	for k in COLOR_LETTERS:
		letters[COLOR_LETTERS[k]] = k
	var arrows := {}
	for k in Direction.MAP_CHARS:
		arrows[Direction.MAP_CHARS[k]] = k
	for b in level.blocks:
		grid[b.cell.y][b.cell.x] = (letters.get(b.color, "B") + arrows[b.direction] + ("@" if b.is_spinner() else "")
				+ ("?" if b.hidden else "") + ("#" + letters[b.lock_color] if b.lock_color != "" else ""))
	var lines := PackedStringArray()
	for row in grid:
		var cells := PackedStringArray()
		for t in row:
			cells.append(String(t).rpad(4))
		lines.append('\t\t"%s"' % " ".join(cells).strip_edges())
	var extra := '\t"mystery": true,\n' if level.mystery else ""
	return '{\n\t"name": "%s",\n%s\t"map": [\n%s\n\t]\n}\n' % [level.name, extra, ",\n".join(lines)]
