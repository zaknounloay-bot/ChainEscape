class_name PlayerProfile
## PLAYER IDENTITY (Phase 3A, QA): the anonymous player id and the optional
## display name - the rules only; the values live in PlayerProgress
## ([profile] section of the same save).
##
## The id is a random UUID v4 made on this device from Godot's Crypto
## (mbedTLS CTR-DRBG seeded from the OS entropy source; on the Web,
## Emscripten's getentropy = crypto.getRandomValues). It is NOT an account
## and NOT a credential: nothing on a server knows it, it is never shown in
## the game, and holding it proves nothing. It only keeps "this save's
## player" stable across saves, reloads and a restore.
##
## Display names: optional, duplicates allowed, kept simple and
## predictable - letters with their accents / vowel marks, digits, single
## spaces, - _ . ' and at most MAX_EMOJI of the five EMOJI; 2-20 user-perceived characters (grapheme
## clusters: a letter plus its marks counts once) after trimming. Scripts
## may be mixed in one name ("Loay לואי"). The letters allowed are exactly
## those the Web build can draw: Latin (incl. Vietnamese), Greek and
## Cyrillic from the engine's built-in Open Sans, Hebrew and Arabic from the
## bundled Noto fallbacks (ProfileCheck checks every allowed code point
## against those fonts). Everything else (controls, bidi / zero-width
## formatting, emoji, symbols, scripts without a font) is refused, never
## silently stripped, so what the player typed is what is kept. The only
## folding: typographic apostrophes (iPhone Smart Punctuation types ’) become
## ', and an emoji's variation selector is made canonical (❤ always gets
## U+FE0F, the others never need it). Unicode NFC normalization is done by the native text field
## (web/social_creator.js) before the name gets here; GDScript has no
## normalizer, so this only validates.

const NAME_MIN := 2
const NAME_MAX := 20
## Combining marks allowed on one letter (Hebrew points: dagesh + vowel +
## shin dot; Arabic: shadda + haraka) - stops "zalgo" stacks.
const MAX_MARKS := 3
## The only emoji a name may use (Phase 3A, approved): the bundled
## NotoColorEmoji-Subset5.ttf draws exactly these. Each counts as one
## character; a name may hold at most MAX_EMOJI of them. Anything else
## (other emoji, skin tones, joiners, flags, keycaps) is refused.
const EMOJI := [0x1F3C6, 0x2764, 0x1F525, 0x2B50, 0x1F9E9]  # 🏆 ❤️ 🔥 ⭐ 🧩
const MAX_EMOJI := 2
const VS16 := 0xFE0F

static var _id_re: RegEx


## A new random UUID v4 ("xxxxxxxx-xxxx-4xxx-[89ab]xxx-xxxxxxxxxxxx").
static func new_id() -> String:
	var b := Crypto.new().generate_random_bytes(16)
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	var h := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [h.substr(0, 8), h.substr(8, 4), h.substr(12, 4), h.substr(16, 4), h.substr(20, 12)]


static func is_valid_id(id: String) -> bool:
	if _id_re == null:
		_id_re = RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	return _id_re.search(id) != null


## Checks a typed name. {"ok": true, "name": cleaned} ("" = no name: the
## player cleared it) or {"ok": false, "error": code}. Codes:
## "unsupported" (a character outside the allowed set), "emoji" (an emoji
## other than the five, or a skin tone / joiner / flag), "mark" (an accent /
## vowel mark with no letter, or too many on one letter), "too_short",
## "too_long", "no_letters".
static func clean_name(raw: String) -> Dictionary:
	var out := PackedStringArray()
	var marks := 0
	var prev_space := true  # collapses runs and drops leading spaces
	var prev_emoji := false
	var emojis := 0
	for i in raw.length():
		var c := raw.unicode_at(i)
		if c == 0x2018 or c == 0x2019 or c == 0x2BC:
			c = 0x27
		if c == VS16:
			# Only right after an allowed emoji (where it is already canonical).
			if not prev_emoji or (i > 0 and raw.unicode_at(i - 1) == VS16):
				return {"ok": false, "error": "unsupported"}
			continue
		if is_emoji(c):
			emojis += 1
			if emojis > MAX_EMOJI:
				return {"ok": false, "error": "too_many_emoji"}
			out.append(String.chr(c) + (String.chr(VS16) if c == 0x2764 else ""))
			prev_space = false
			prev_emoji = true
			marks = 0
			continue
		prev_emoji = false
		if c == 0x20:
			if not prev_space:
				out.append(" ")
			prev_space = true
			marks = 0
			continue
		if is_mark(c):
			marks += 1
			if prev_space or marks > MAX_MARKS or (i > 0 and (is_emoji(raw.unicode_at(i - 1)) or raw.unicode_at(i - 1) == VS16)):
				return {"ok": false, "error": "mark"}
			out.append(String.chr(c))
			continue
		if not is_base(c):
			# An emoji the name cannot use gets its own, clearer reason.
			var emoji_like := (c >= 0x1F000 and c <= 0x1FAFF) or (c >= 0x2600 and c <= 0x27BF) or (c >= 0x2B00 and c <= 0x2BFF) \
				or c == 0x20E3 or (c >= 0xE0020 and c <= 0xE007F) or (c == 0x200D and prev_emoji_raw(raw, i))
			return {"ok": false, "error": "emoji" if emoji_like else "unsupported"}
		out.append(String.chr(c))
		prev_space = false
		marks = 0
	var name := "".join(out).strip_edges()
	if name == "":
		return {"ok": true, "name": ""}
	var n := grapheme_count(name)
	if n < NAME_MIN:
		return {"ok": false, "error": "too_short"}
	if n > NAME_MAX:
		return {"ok": false, "error": "too_long"}
	var has_letter := false
	for i in name.length():
		var c := name.unicode_at(i)
		if is_base(c) and not _is_punct(c):
			has_letter = true
			break
	if not has_letter:
		return {"ok": false, "error": "no_letters"}
	return {"ok": true, "name": name}


## User-perceived characters of a cleaned name: every character that is not
## a combining mark or U+FE0F starts a new cluster (a mark always follows
## its letter here, U+FE0F its emoji - clean_name refuses anything else - and
## the allowed set has no joiners, so this is exact; web/social_creator.js counts the same with
## Intl.Segmenter).
static func grapheme_count(name: String) -> int:
	var n := 0
	for i in name.length():
		var c := name.unicode_at(i)
		if not is_mark(c) and c != VS16:
			n += 1
	return n


## A ZWJ right after an emoji (an allowed one or its U+FE0F) joins emoji.
static func prev_emoji_raw(raw: String, i: int) -> bool:
	return i > 0 and (is_emoji(raw.unicode_at(i - 1)) or raw.unicode_at(i - 1) == VS16)


static func is_emoji(c: int) -> bool:
	return EMOJI.has(c)


static func emoji_count(name: String) -> int:
	var n := 0
	for i in name.length():
		if is_emoji(name.unicode_at(i)):
			n += 1
	return n


## A short, friendly explanation for an error code.
static func error_text(code: String) -> String:
	match code:
		"too_short": return "Use at least %d characters" % NAME_MIN
		"too_long": return "Use at most %d characters" % NAME_MAX
		"no_letters": return "Use at least one letter or number"
		"too_many_emoji": return "Use at most %d emoji" % MAX_EMOJI
		"emoji": return "Unsupported emoji. Use only 🏆 ❤️ 🔥 ⭐ 🧩 (maximum %d)." % MAX_EMOJI
		_: return "Use letters, numbers, spaces, - _ . ' and 🏆 ❤️ 🔥 ⭐ 🧩 only"


## Letters, digits and the four punctuation marks a name may use.
static func is_base(c: int) -> bool:
	if (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or _is_punct(c):
		return true
	# Latin: Latin-1 letters, Latin Extended-A, the Extended-B letters Open
	# Sans has (Vietnamese horn letters, Romanian comma-below, ...), Welsh
	# w-accents and the Vietnamese block.
	if (c >= 0xC0 and c <= 0x17F and c != 0xD7 and c != 0xF7) or c == 0x192 or (c >= 0x1A0 and c <= 0x1A1) \
			or (c >= 0x1AF and c <= 0x1B0) or c == 0x1F0 or (c >= 0x1FA and c <= 0x1FF) or (c >= 0x218 and c <= 0x21B) \
			or (c >= 0x1E80 and c <= 0x1E85) or (c >= 0x1EA0 and c <= 0x1EF9):
		return true
	# Greek (monotonic, with tonos / dialytika) and Cyrillic letters.
	if c == 0x386 or (c >= 0x388 and c <= 0x38A) or c == 0x38C or (c >= 0x38E and c <= 0x3A1) or (c >= 0x3A3 and c <= 0x3CE) \
			or (c >= 0x400 and c <= 0x481) or (c >= 0x48A and c <= 0x513):
		return true
	# Hebrew: letters, Yiddish ligatures, maqaf, geresh / gershayim.
	if (c >= 0x5D0 and c <= 0x5EA) or (c >= 0x5EF and c <= 0x5F4) or c == 0x5BE:
		return true
	# Arabic: letters (incl. tatweel), Arabic-Indic and extended digits,
	# Arabic Supplement letters. Format characters (U+0600-0605, U+061C,
	# U+06DD) and symbols are not included.
	if (c >= 0x620 and c <= 0x64A) or (c >= 0x660 and c <= 0x669) or (c >= 0x66E and c <= 0x66F) \
			or (c >= 0x671 and c <= 0x6D3) or c == 0x6D5 or (c >= 0x6EE and c <= 0x6FC) or c == 0x6FF \
			or (c >= 0x750 and c <= 0x77F):
		return true
	return false


## Combining marks of the allowed scripts that the fonts draw (the Latin
## accents left after NFC, Hebrew points, Arabic harakat).
static func is_mark(c: int) -> bool:
	return c == 0x300 or c == 0x301 or c == 0x303 or c == 0x309 or c == 0x30F or c == 0x323 \
		or (c >= 0x591 and c <= 0x5BD) or c == 0x5BF or (c >= 0x5C1 and c <= 0x5C2) or (c >= 0x5C4 and c <= 0x5C5) or c == 0x5C7 \
		or (c >= 0x64B and c <= 0x65F) or c == 0x670 or (c >= 0x6D6 and c <= 0x6DC) or (c >= 0x6DF and c <= 0x6E4) \
		or (c >= 0x6E7 and c <= 0x6E8) or (c >= 0x6EA and c <= 0x6ED)


static func _is_punct(c: int) -> bool:
	return c == 0x2D or c == 0x5F or c == 0x2E or c == 0x27 or c == 0x5BE or c == 0x5F3 or c == 0x5F4
