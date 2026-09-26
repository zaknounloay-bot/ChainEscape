class_name Palette
## Central place for every color and font used by the game.
## Tweak the look of the whole prototype from here.

const BACKGROUND := Color("#F6F3EE")
const BOARD := Color("#ECE6DC")
const SLOT := Color("#E2DBCF")
const TEXT := Color("#2E2A33")
const TEXT_SOFT := Color("#8F877C")
const ACCENT := Color("#FF7A45")
const ACCENT_HOT := Color("#F0435A")  # chain text shifts toward this at high chains
const WHITE := Color("#FFFFFF")
const SHADOW := Color(0.24, 0.18, 0.10, 0.16)

## name -> [face, side (depth) color]
const BLOCKS := {
	"red": [Color("#F2545B"), Color("#C73B44")],
	"blue": [Color("#3D8BFD"), Color("#2A67C9")],
	"green": [Color("#2DBE7E"), Color("#1F9161")],
	"yellow": [Color("#F7B32B"), Color("#CF8B12")],
	"purple": [Color("#8E6CF0"), Color("#6A4BC4")],
}


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
