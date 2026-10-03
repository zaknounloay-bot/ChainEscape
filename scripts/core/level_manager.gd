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
##    "R>@-" / "R>@~" / "R>@*" = counter-clockwise / alternating / pattern
##           spinner (see BlockData.SpinRule)
##    "R>?" = HIDDEN arrow (mystery): revealed when a neighbour escapes
##    "R>#G" = LOCKED: cannot escape while any green block remains
##    "R>$S" / "R>$G" = SILVER / GOLD reward block (v0.5; "$D" = future
##           Diamond). Plays by the normal rules, pays coins once.
##    v0.6 (Second Era), group letter A-D (switches A / B, gates C / D):
##    "R>%A" = SWITCH of group A: when it escapes, blocks marked &A reverse
##    "R>&A" = reverses its arrow when switch A escapes
##    "XA"   = CHAIN GATE of group A (no color / arrow; can't be tapped)
##    "R>+A" = LINK of gate A: the gate opens when every +A block is gone
##    "R>="  = ARMORED: launch another block into it to crack the shell
##    PORTAL PROTOTYPE (development only, ?mechlab=1; see Portals):
##    "OA"   = a cell of portal pair A (no block; groups A-D, exactly two
##             cells each). No campaign level uses it.
##    Modifiers can be combined in the order  @ ? #K $R %A &A +A =
##    (spinners cannot be hidden, hidden blocks cannot be locked; switches,
##    flip targets and armored blocks are plain arrows: no spinner, no
##    hidden; armored blocks are never locked or switches).
##      { "name": "Hello", "map": ["R> . .", ". B^ ."] }
##
## 2) Explicit block list:
##      { "rows": 4, "columns": 4,
##        "blocks": [ { "row": 0, "column": 1, "color": "red", "direction": "up",
##                      "spinner": true, "rarity": "gold" } ] }
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
var _info_cache: Dictionary = {}


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


## Cached summary for Level Select: {"mystery": bool, "rewards": {id: rarity}}.
func level_info(number: int) -> Dictionary:
	if not _info_cache.has(number):
		var l := load_level(number)
		var rewards := {}
		if l != null:
			for b in l.blocks:
				if b.is_reward():
					rewards[b.id] = b.rarity
		_info_cache[number] = {"mystery": l != null and l.mystery, "rewards": rewards}
	return _info_cache[number]


## True if level `number` is a Mystery level (cached; for Level Select).
func is_mystery(number: int) -> bool:
	return level_info(number)["mystery"]


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
		_token_re = RegEx.create_from_string("^([RBGYPrbgyp])([\\^v<>])(@[-~*]?)?(\\?)?(#[RBGYPrbgyp])?(\\$[SGD])?(%[ABCD])?(&[ABCD])?(\\+[ABCD])?(=)?$")
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
			if t.length() == 2 and t[0] == Portals.TOKEN_PREFIX and Portals.GROUPS.has(t[1]):
				level.portals[Vector2i(c, r)] = t[1]
				continue
			if t.length() == 2 and t[0] == "X" and "ABCD".contains(t[1]):
				var g := BlockData.new(next_id, Vector2i(c, r), GATE_COLOR, Direction.UP, BlockData.Kind.GATE)
				g.gate_group = t[1]
				level.blocks.append(g)
				next_id += 1
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
			if spinner:
				b.spin_rule = maxi(0, BlockData.RULE_SUFFIX.find(m.get_string(3).substr(1)))
			if m.get_string(5) != "":
				b.lock_color = COLOR_LETTERS[m.get_string(5).substr(1).to_upper()]
			if m.get_string(6) != "":
				b.rarity = BlockData.RARITY_TOKENS.find(m.get_string(6).substr(1))
			b.switch_group = m.get_string(7).substr(1)
			b.flip_link = m.get_string(8).substr(1)
			b.gate_link = m.get_string(9).substr(1)
			b.armored = m.get_string(10) != ""
			_validate_block(b, level)
			level.blocks.append(b)
			next_id += 1
	_validate_links(level)
	_validate_portals(level)


## Portal prototype: a malformed layout (a group without exactly two cells,
## or a lane that could loop) is reported and dropped entirely, never
## guessed at.
static func _validate_portals(level: LevelData) -> void:
	if level.portals.is_empty():
		return
	var errors := Portals.layout_errors(level.rows, level.columns, level.portals)
	if not errors.is_empty():
		for e in errors:
			push_error("Level %d: %s" % [level.number, e])
		level.portals = {}


## Gates are colorless: this color is never a lock key and never drawn.
const GATE_COLOR := "gate"


## v0.6: every link must lead somewhere visible. A switch needs at least one
## block to flip, a gate needs at least one link, and every link needs its
## switch / gate. Broken links are removed (and reported).
static func _validate_links(level: LevelData) -> void:
	var switches := {}
	var gates := {}
	var flips := {}
	var links := {}
	for b in level.blocks:
		if b.switch_group != "":
			switches[b.switch_group] = true
		if b.is_gate():
			gates[b.gate_group] = true
		if b.flip_link != "":
			flips[b.flip_link] = true
		if b.gate_link != "":
			links[b.gate_link] = true
	for b in level.blocks:
		if b.flip_link != "" and not switches.has(b.flip_link):
			push_error("Level %d: block at %s flips with switch %s, which does not exist" % [level.number, b.cell, b.flip_link])
			b.flip_link = ""
		if b.gate_link != "" and not gates.has(b.gate_link):
			push_error("Level %d: block at %s links gate %s, which does not exist" % [level.number, b.cell, b.gate_link])
			b.gate_link = ""
		if b.switch_group != "" and not flips.has(b.switch_group):
			push_error("Level %d: switch %s at %s has nothing to flip" % [level.number, b.switch_group, b.cell])
			b.switch_group = ""
	var kept := []
	for b in level.blocks:
		if b.is_gate() and not links.has(b.gate_group):
			push_error("Level %d: gate %s at %s has no links" % [level.number, b.gate_group, b.cell])
			continue
		kept.append(b)
	if kept.size() != level.blocks.size():
		level.blocks = kept
		for i in kept.size():
			kept[i].id = i


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
	# v0.6 mechanics stay readable: one special role per arrow.
	if (b.switch_group != "" or b.flip_link != "" or b.armored) and (b.is_spinner() or b.hidden):
		push_error("Level %d: switch / flip / armored block at %s cannot be a spinner or hidden" % [level.number, b.cell])
		b.switch_group = ""
		b.flip_link = ""
		b.armored = false
	if b.switch_group != "" and b.flip_link != "":
		push_error("Level %d: block at %s cannot be a switch and a flip target" % [level.number, b.cell])
		b.flip_link = ""
	if b.armored and (b.lock_color != "" or b.switch_group != ""):
		push_error("Level %d: armored block at %s cannot be locked or a switch" % [level.number, b.cell])
		b.armored = false


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
		block.spin_rule = ["cw", "ccw", "alt", "pattern"].find(String(b.get("spin", "cw")))
		block.spin_rule = maxi(block.spin_rule, 0)
		block.rarity = maxi(0, BlockData.RARITY_NAMES.find(String(b.get("rarity", "normal"))))
		block.switch_group = String(b.get("switch", ""))
		block.flip_link = String(b.get("flip", ""))
		block.gate_link = String(b.get("gate_link", ""))
		block.armored = bool(b.get("armored", false))
		if b.has("gate"):
			block.kind = BlockData.Kind.GATE
			block.gate_group = String(b["gate"])
			block.color = GATE_COLOR
		_validate_block(block, level)
		level.blocks.append(block)
		next_id += 1
	_validate_links(level)


## Serializes a level back to the "map" JSON form (used by the generator).
static func to_json_text(level: LevelData) -> String:
	var grid := []
	for r in level.rows:
		var row := []
		row.resize(level.columns)
		row.fill(".")
		grid.append(row)
	var letters := {}
	for k in COLOR_LETTERS:
		letters[COLOR_LETTERS[k]] = k
	var arrows := {}
	for k in Direction.MAP_CHARS:
		arrows[Direction.MAP_CHARS[k]] = k
	for cell in level.portals:
		grid[cell.y][cell.x] = Portals.TOKEN_PREFIX + level.portals[cell]
	for b in level.blocks:
		if b.is_gate():
			grid[b.cell.y][b.cell.x] = "X" + b.gate_group
			continue
		grid[b.cell.y][b.cell.x] = (letters.get(b.color, "B") + arrows[b.direction] + ("@" + BlockData.RULE_SUFFIX[b.spin_rule] if b.is_spinner() else "")
				+ ("?" if b.hidden else "") + ("#" + letters[b.lock_color] if b.lock_color != "" else "")
				+ ("$" + BlockData.RARITY_TOKENS[b.rarity] if b.is_reward() else "")
				+ ("%" + b.switch_group if b.switch_group != "" else "") + ("&" + b.flip_link if b.flip_link != "" else "")
				+ ("+" + b.gate_link if b.gate_link != "" else "") + ("=" if b.armored else ""))
	var rows := []
	for row in grid:
		rows.append(" ".join(PackedStringArray(row)))
	var json := {"name": level.name, "map": rows}
	if level.mystery:
		json["mystery"] = true
	if level.hint != "":
		json["hint"] = level.hint
		json["hint_finger"] = level.hint_finger
	return format_level_json(json)


## House style for level files: known keys first, one "map" row per line
## with the cells padded into columns.
static func format_level_json(json: Dictionary) -> String:
	var order := ["name", "mystery", "hint", "hint_finger", "blocked_hint", "hearts", "hints", "stars"]
	for k in json:
		if not order.has(k) and k != "map":
			order.append(k)
	var lines := PackedStringArray()
	for k in order:
		if json.has(k):
			lines.append('\t"%s": %s' % [k, JSON.stringify(json[k])])
	if json.has("map"):
		var cells := []
		var width := 1
		for row in json["map"]:
			var tokens := String(row).split(" ", false)
			cells.append(tokens)
			for t in tokens:
				width = maxi(width, t.length())
		var rows := PackedStringArray()
		for tokens in cells:
			var padded := PackedStringArray()
			for i in tokens.size():
				padded.append(tokens[i] if i == tokens.size() - 1 else String(tokens[i]).rpad(width + 2))
			rows.append('\t\t"%s"' % "".join(padded))
		lines.append('\t"map": [\n%s\n\t]' % ",\n".join(rows))
	return "{\n%s\n}\n" % ",\n".join(lines)
