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
