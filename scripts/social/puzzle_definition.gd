class_name PuzzleDefinition
extends RefCounted
## Social: the EXACT playable puzzle of a challenge, as explicit data.
##
## The board is stored cell by cell in the same "map" text the 200 campaign
## levels use (see LevelManager: "R>" = red block, arrow right; "B^@" = blue
## spinner; ...), and rebuilt with the same parser (LevelManager.parse_level).
## So a recipient rebuilds exactly this board without running the generator:
## a later generator (or a different device) can never turn the same
## challenge into a different puzzle. Generic on purpose: nothing here knows
## about photos, messages or who plays it.
##
## Serialized (to_dict / to_json):
##   {"format": "ce-puzzle", "v": 1, "rules": 1, "rows": 6, "cols": 6,
##    "map": ["R> .  B^@ ...", ...]}
## "v" is this data format; "rules" is the game-rules generation the
## board was verified with (bump it if BoardModel's rules ever change
## meaning, so old challenges can be recognised).

const FORMAT := "ce-puzzle"
const VERSION := 1
const RULES := 1
const MAX_SIDE := 12

var rows: int = 0
var columns: int = 0
## One string per row, cells separated by spaces (campaign map tokens).
var map: PackedStringArray = PackedStringArray()


## From a board the generator (or anything else) produced.
static func from_level(level: LevelData) -> PuzzleDefinition:
	var json = JSON.parse_string(LevelManager.to_json_text(level))
	var d := PuzzleDefinition.new()
	d.rows = level.rows
	d.columns = level.columns
	for row in json["map"]:
		# One space between cells: the canonical form (the level-file
		# padding is only for human readers).
		d.map.append(" ".join(String(row).split(" ", false)))
	return d


## Rebuilds from serialized data. Returns null if the data is not a
## well-formed puzzle of a known version (never guesses).
static func from_dict(data: Dictionary) -> PuzzleDefinition:
	if data.get("format", "") != FORMAT or int(data.get("v", 0)) != VERSION or int(data.get("rules", 0)) != RULES:
		return null
	var raw = data.get("map", null)
	if typeof(raw) != TYPE_ARRAY or raw.is_empty():
		return null
	var d := PuzzleDefinition.new()
	d.rows = int(data.get("rows", 0))
	d.columns = int(data.get("cols", 0))
	for row in raw:
		if typeof(row) != TYPE_STRING:
			return null
		d.map.append(row)
	if d.rows != d.map.size() or d.rows < 1 or d.columns < 1 or d.rows > MAX_SIDE or d.columns > MAX_SIDE:
		return null
	for row in d.map:
		if row.split(" ", false).size() != d.columns:
			return null
	return d


static func from_json(text: String) -> PuzzleDefinition:
	var data = JSON.parse_string(text)
	return from_dict(data) if typeof(data) == TYPE_DICTIONARY else null


func to_dict() -> Dictionary:
	return {"format": FORMAT, "v": VERSION, "rules": RULES, "rows": rows, "cols": columns, "map": Array(map)}


## Compact canonical JSON (fixed key order): what gets stored / sent.
func to_json() -> String:
	return JSON.stringify(to_dict(), "", false)


## Identity of the exact puzzle (same board = same fingerprint).
func fingerprint() -> String:
	return to_json().sha256_text()


## A fresh LevelData for the engine (new block objects every call).
func to_level(title: String = "") -> LevelData:
	var level := LevelManager.parse_level({"name": title, "map": Array(map)})
	return level


## Every cell parsed, the board matches its size, and the Solver can clear
## it. A puzzle that fails this is never played.
func verify() -> bool:
	var level := to_level()
	if level == null or level.rows != rows or level.columns != columns or level.blocks.is_empty():
		return false
	var tokens := 0
	for row in map:
		for t in row.split(" ", false):
			if t != ".":
				tokens += 1
	if tokens != level.blocks.size():
		return false  # a cell the parser could not read
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	var solver := Solver.from_model(model)
	var moves := solver.solve_moves()
	return not solver.aborted and not moves.is_empty()


func block_count() -> int:
	var n := 0
	for row in map:
		for t in row.split(" ", false):
			if t != ".":
				n += 1
	return n
