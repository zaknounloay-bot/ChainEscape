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
	# Colour emoji, ONLY 🏆 ❤️ 🔥 ⭐ 🧩 (a 12 KB subset; names allow exactly these).
	"res://assets/fonts/NotoColorEmoji-Subset5.ttf",
]
## Unicode isolates: the message keeps its own direction inside the
## quotes (U+2068 FIRST STRONG ISOLATE ... U+2069 POP DIRECTIONAL ISOLATE).
static var FSI := String.chr(0x2068)
static var PDI := String.chr(0x2069)

## Photo / Message Reveal messages (phase 4) also get this larger emoji cut
## (115 common emoji: hearts, faces, hands, celebration, flowers; 288 KB,
## same Noto Color Emoji 2.047). Names and every other text keep the small
## 5-emoji font above. Emoji outside it (flags, skin tones, newer emoji)
## have no glyph - see missing_emoji().
const REVEAL_EMOJI := "res://assets/fonts/NotoColorEmoji-Reveal.ttf"

static var _fonts: Dictionary = {}
static var _reveal_emoji: Font


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


## The message font with the larger emoji set in front of the small one
## (Photo / Message Reveal messages only).
static func reveal_font(weight: int = 800) -> Font:
	var key := -weight
	if _fonts.has(key):
		return _fonts[key]
	# The emoji set comes FIRST, the usual message font after it: the UI
	# font has plain text glyphs for a few emoji (❤ ☀ ✌ ⭐ ...), which would
	# otherwise win over the colour ones. The emoji set has nothing but those
	# 115 emoji, so every other character still comes from the message font
	# (and its Arabic / Hebrew fallbacks), shaped as before.
	var em := _emoji_font()
	if em == null:
		_fonts[key] = font(weight)
		return _fonts[key]
	var f: Font = em.duplicate()
	var chain: Array[Font] = [font(weight)]
	f.fallbacks = chain
	_fonts[key] = f
	return f


static func _emoji_font() -> Font:
	if _reveal_emoji == null:
		_reveal_emoji = load(REVEAL_EMOJI) as Font
	return _reveal_emoji


## Emoji in `text` that no message font can draw (they would show as empty
## boxes), each once, in order. Variation selectors, joiners and isolates
## are not counted.
static func missing_emoji(text: String) -> Array[String]:
	var out: Array[String] = []
	var em := _emoji_font()
	for i in text.length():
		var c := text.unicode_at(i)
		var emoji := c >= 0x1F000 or (c >= 0x2600 and c <= 0x27BF) or (c >= 0x2B00 and c <= 0x2BFF) or (c >= 0x2190 and c <= 0x21FF)
		if not emoji or c == 0xFE0F or c == 0x200D:
			continue
		if em == null or not em.has_char(c):
			var s := String.chr(c)
			if not out.has(s):
				out.append(s)
	return out


## Makes a Label ready for any personal message.
static func apply(label: Label, weight: int = 800, reveal: bool = false) -> void:
	label.add_theme_font_override("font", reveal_font(weight) if reveal else font(weight))
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
