class_name Palette
## Central place for every color and font used by the game.
## Tweak the look of the whole prototype from here.

# v0.2: brighter, more saturated palette. Color is decoration only - the
# rules never depend on it. Direction is always the arrow shape and
# spinners carry their own ring badge, so color-blind players lose nothing.
const BACKGROUND := Color("#F3F1FA")
const BOARD := Color("#E5E1F3")
const SLOT := Color("#D8D2EC")
const TEXT := Color("#1D1A2E")
const TEXT_SOFT := Color("#7A7596")
const ACCENT := Color("#FF5A1F")
const ACCENT_HOT := Color("#FF1F6B")  # chain text shifts toward this at high chains
const BOARD_MYSTERY := Color("#D9D2F0")  # mystery levels: deeper tint
const SLOT_MYSTERY := Color("#CBC2E6")
const GOLD := Color("#FFB300")  # stars, PERFECT
const PURPLE_BADGE := Color("#7B3FF2")  # Mystery marker
const HEART := Color("#FF2D55")
const HINT := Color("#FFC400")
const WHITE := Color("#FFFFFF")
const SHADOW := Color(0.12, 0.08, 0.30, 0.18)

## name -> [face, side (depth) color, arrow color]
## Yellow gets a dark arrow: white on yellow is too low-contrast.
const BLOCKS := {
	"red": [Color("#FF3D5A"), Color("#D01F42"), Color("#FFFFFF")],
	"blue": [Color("#1E7BFF"), Color("#0F57D6"), Color("#FFFFFF")],
	"green": [Color("#00C46A"), Color("#00914E"), Color("#FFFFFF")],
	"yellow": [Color("#FFB800"), Color("#DB8A00"), Color("#4A2A00")],
	"purple": [Color("#8A3FFC"), Color("#6224D6"), Color("#FFFFFF")],
}


## v0.5 reward metals: [frame, highlight, deep] per rarity (index 1..3).
const METALS := [
	[],
	[Color("#C9D3DE"), Color("#FFFFFF"), Color("#7D8A99")],  # silver
	[Color("#F2B51B"), Color("#FFF1B8"), Color("#A86A00")],  # gold
	[Color("#9EEBFF"), Color("#FFFFFF"), Color("#3F9FC4")],  # diamond (future)
]

## v0.5: block MATERIAL of the current Chapter (data/chapters.json
## "block_style"): saturation, gloss, rim and glow. Hues never change, so a
## red block is red in every Chapter (locks depend on colors).
static var block_style: Dictionary = {"saturation": 1.0, "gloss": 0.0, "rim": 0.0, "glow": 0.0, "edge": Color.WHITE}


static func styled_face(color_name: String) -> Color:
	return _saturate(face(color_name))


static func styled_side(color_name: String) -> Color:
	return _saturate(side(color_name))


static func _saturate(c: Color) -> Color:
	var sat: float = block_style.get("saturation", 1.0)
	if is_equal_approx(sat, 1.0):
		return c
	return Color.from_hsv(c.h, clampf(c.s * sat, 0.0, 1.0), c.v, c.a)


static func arrow(color_name: String) -> Color:
	return BLOCKS.get(color_name, BLOCKS["blue"])[2]


static func face(color_name: String) -> Color:
	return BLOCKS.get(color_name, BLOCKS["blue"])[0]


static func side(color_name: String) -> Color:
	return BLOCKS.get(color_name, BLOCKS["blue"])[1]


static var _font_cache: Dictionary = {}


## Rounded, bold UI font. Uses the device's native font on iOS/Android
## (SF Pro / Roboto) so no font asset has to ship with the prototype.
static func font(weight: int = 800) -> Font:
	if _font_cache.has(weight):
		return _font_cache[weight]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Nunito", "SF Pro Rounded", "SF Pro Display", "Roboto", "Helvetica Neue", "Arial", "sans-serif"])
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_font_cache[weight] = f
	return f
