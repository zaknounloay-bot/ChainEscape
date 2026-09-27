class_name Chapters
## Chapters (v0.5): every 10 levels is a Chapter with its own background,
## accent colors, ambient decoration and particles, music and block
## material. Level 100 keeps a unique Master theme.
##
## Everything visual comes from res://data/chapters.json - no theme lives in
## UI code. Chapters past the defined list (101+) reuse the themes named in
## "overflow.cycle" with a round number ("Deep Current II"), so the game can
## keep growing without new art or code.
##
## A theme only changes presentation. Block hues, arrows and every rule stay
## identical, so readability is the same everywhere.

const CONFIG_PATH := "res://data/chapters.json"
const COLOR_KEYS := ["bg_top", "bg_bottom", "board", "slot", "text", "text_soft", "accent", "deco_color", "particle_color"]
const MASTER_ID := 1000

static var _config: Dictionary = {}
static var _themes: Array = []  # parsed chapter themes 1..N (Colors, ids)
static var _master: Dictionary = {}


static func config() -> Dictionary:
	if _config.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_config = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
		_themes.clear()
		var list: Array = _config.get("chapters", [])
		for i in list.size():
			_themes.append(_parse(list[i], i + 1))
		_master = _parse(_config.get("master", list[-1] if not list.is_empty() else {}), MASTER_ID)
		_master["chapter"] = chapter_of(master_level())
	return _config


static func levels_per_chapter() -> int:
	return int(config().get("levels_per_chapter", 10))


static func master_level() -> int:
	return int(config().get("master_level", 100))


## Number of hand-made chapter themes (10). Chapters past it still exist.
static func defined_count() -> int:
	config()
	return _themes.size()


## 1-10 = Chapter 1, 11-20 = Chapter 2 ... 91-100 = Chapter 10, 101-110 = 11.
static func chapter_of(level_number: int) -> int:
	return maxi(1, (level_number - 1) / levels_per_chapter() + 1)


static func chapter_range(chapter: int) -> Vector2i:
	var size := levels_per_chapter()
	return Vector2i((chapter - 1) * size + 1, chapter * size)


static func chapter_count(total_levels: int) -> int:
	return chapter_of(maxi(total_levels, 1))


static func is_master(level_number: int) -> bool:
	return level_number == master_level()


## Theme of a chapter (1-based). Chapters past the defined list cycle.
static func theme_for_chapter(chapter: int) -> Dictionary:
	config()
	if _themes.is_empty():
		return {}
	if chapter <= _themes.size():
		return _themes[maxi(chapter, 1) - 1]
	var cycle: Array = config().get("overflow", {}).get("cycle", [_themes.size()])
	var k := chapter - _themes.size() - 1
	var base: Dictionary = _themes[int(cycle[k % cycle.size()]) - 1].duplicate(true)
	base["id"] = chapter
	base["chapter"] = chapter
	base["name"] = "%s %s" % [base["name"], _roman(2 + k / cycle.size())]
	return base


## The theme to show for a level: its chapter's, or the Master theme.
static func theme_for_level(level_number: int) -> Dictionary:
	config()
	if is_master(level_number):
		return _master
	return theme_for_chapter(chapter_of(level_number))


static func chapter_name(chapter: int) -> String:
	return String(theme_for_chapter(chapter).get("name", "Chapter %d" % chapter))


## "CHAPTER 4  ·  EMBER RIDGE" (banner / headers).
static func title(chapter: int) -> String:
	return "CHAPTER %d  ·  %s" % [chapter, chapter_name(chapter).to_upper()]


static func _parse(raw: Dictionary, id: int) -> Dictionary:
	var t := raw.duplicate(true)
	t["id"] = id
	t["chapter"] = id
	for k in COLOR_KEYS:
		t[k] = Color(String(raw.get(k, "#FFFFFF")))
	var style: Dictionary = raw.get("block_style", {}).duplicate()
	style["edge"] = Color(String(style.get("edge", "#FFFFFF")))
	for k in ["saturation", "gloss", "rim", "glow"]:
		style[k] = float(style.get(k, 1.0 if k == "saturation" else 0.0))
	t["block_style"] = style
	t["dark"] = bool(raw.get("dark", false))
	return t


static func _roman(n: int) -> String:
	var vals := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var out := ""
	for v in vals:
		while n >= v[0]:
			out += v[1]
			n -= v[0]
	return out
