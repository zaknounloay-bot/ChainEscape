class_name Worlds
## The five Worlds (20 levels each) plus the special Master Level theme.
##
## A theme only changes the surroundings: background gradient, board and
## slot tint, HUD text/accent colors, ambient decoration and music. Block
## colors and arrows never change, so readability is identical everywhere.

const LEVELS_PER_WORLD := 20
const MASTER_LEVEL := 100

const THEMES := [
	{"id": 1, "name": "First Light", "music": "w1",
		"bg_top": Color("#F7F5FD"), "bg_bottom": Color("#E9E4F7"),
		"board": Color("#E5E1F3"), "slot": Color("#D8D2EC"),
		"text": Color("#1D1A2E"), "text_soft": Color("#7A7596"), "accent": Color("#FF5A1F"),
		"deco": "bubbles", "deco_color": Color("#B9AEE8"), "dark": false},
	{"id": 2, "name": "Deep Current", "music": "w2",
		"bg_top": Color("#E3ECFF"), "bg_bottom": Color("#C4D3F7"),
		"board": Color("#C6D3F2"), "slot": Color("#B3C2E8"),
		"text": Color("#13213F"), "text_soft": Color("#566A94"), "accent": Color("#2F6BFF"),
		"deco": "waves", "deco_color": Color("#8FA9EA"), "dark": false},
	{"id": 3, "name": "Ember Ridge", "music": "w3",
		"bg_top": Color("#FFE6D6"), "bg_bottom": Color("#F4B69B"),
		"board": Color("#F0C7B3"), "slot": Color("#E5AF97"),
		"text": Color("#3A1408"), "text_soft": Color("#8A4A33"), "accent": Color("#E8341C"),
		"deco": "triangles", "deco_color": Color("#E98A63"), "dark": false},
	{"id": 4, "name": "Neon Night", "music": "w4",
		"bg_top": Color("#211A44"), "bg_bottom": Color("#0D0A1F"),
		"board": Color("#2B2455"), "slot": Color("#3A3170"),
		"text": Color("#F3EEFF"), "text_soft": Color("#A99BD8"), "accent": Color("#22E5FF"),
		"deco": "neon", "deco_color": Color("#FF3DCB"), "dark": true},
	{"id": 5, "name": "Master's Summit", "music": "w5",
		"bg_top": Color("#18213A"), "bg_bottom": Color("#070A14"),
		"board": Color("#212C48"), "slot": Color("#2D3A5C"),
		"text": Color("#FFF6DD"), "text_soft": Color("#C9B98A"), "accent": Color("#FFC43D"),
		"deco": "stars", "deco_color": Color("#FFD978"), "dark": true},
]

const MASTER_THEME := {"id": 6, "name": "Master Level", "music": "master",
	"bg_top": Color("#1C1608"), "bg_bottom": Color("#050403"),
	"board": Color("#241E10"), "slot": Color("#352C16"),
	"text": Color("#FFE9A8"), "text_soft": Color("#C9A94F"), "accent": Color("#FFD24A"),
	"deco": "rays", "deco_color": Color("#FFCE47"), "dark": true}


static func world_of(level_number: int) -> int:
	return clampi((level_number - 1) / LEVELS_PER_WORLD + 1, 1, THEMES.size())


static func theme_for_level(level_number: int) -> Dictionary:
	if level_number == MASTER_LEVEL:
		return MASTER_THEME
	return THEMES[world_of(level_number) - 1]


static func world_range(world: int) -> Vector2i:
	return Vector2i((world - 1) * LEVELS_PER_WORLD + 1, world * LEVELS_PER_WORLD)


static func world_name(world: int) -> String:
	return THEMES[clampi(world, 1, THEMES.size()) - 1]["name"]
