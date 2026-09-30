class_name MessageText
## Social: how a user-written personal message is drawn, in any language.
## Used by every screen that shows the message (creator card and review
## now, the recipient reveal later).
##
## Glyphs: the UI font (Palette.font) is a SystemFont. On the Web build the
## browser gives Godot no access to system fonts, so it falls back to the
## engine's built-in Open Sans (Latin, Greek, Cyrillic only). Messages get
## their own copy of that font with bundled fallbacks for the scripts it
## lacks (Arabic, Hebrew). The shared UI font is not changed.
## To support another script later, add its font to FALLBACKS (order =
## priority). Large ones (CJK, color emoji) should be loaded on demand
## rather than bundled.
##
## Direction: Godot's text server (ICU BiDi + HarfBuzz) shapes Arabic and
## orders mixed RTL / LTR text by the Unicode BiDi algorithm. Each line
## takes its direction from its first strong letter (TEXT_DIRECTION_AUTO);
## strings are never reversed by hand.

const FALLBACKS := [
	"res://assets/fonts/NotoSansArabic-SemiBold.woff2",
	"res://assets/fonts/NotoSansHebrew-SemiBold.woff2",
]
## Unicode isolates: the message keeps its own direction inside the
## quotes (U+2068 FIRST STRONG ISOLATE ... U+2069 POP DIRECTIONAL ISOLATE).
static var FSI := String.chr(0x2068)
static var PDI := String.chr(0x2069)

static var _fonts: Dictionary = {}


## The UI font of that weight plus the multilingual fallbacks.
static func font(weight: int = 800) -> Font:
	if _fonts.has(weight):
		return _fonts[weight]
	var f: Font = Palette.font(weight).duplicate()
	var chain: Array[Font] = []
	for path in FALLBACKS:
		var fb := load(path) as Font
		if fb:
			chain.append(fb)
	f.fallbacks = chain
	_fonts[weight] = f
	return f


## Makes a Label ready for any personal message.
static func apply(label: Label, weight: int = 800) -> void:
	label.add_theme_font_override("font", font(weight))
	label.text_direction = Control.TEXT_DIRECTION_AUTO
	label.language = ""  # detected per run by the text server


static func apply_edit(edit: TextEdit, weight: int = 800) -> void:
	edit.add_theme_font_override("font", font(weight))
	edit.text_direction = Control.TEXT_DIRECTION_AUTO


## The message in quotes; the message itself is isolated, so an Arabic or
## Hebrew message stays right-to-left while the quote marks stay in place.
static func quoted(message: String) -> String:
	var lines := message.split("\n")
	for i in lines.size():
		lines[i] = FSI + lines[i] + PDI
	return "“" + "\n".join(lines) + "”"
