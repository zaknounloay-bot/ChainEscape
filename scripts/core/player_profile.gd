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
## predictable - letters (Latin, Hebrew, Arabic) with their accents / vowel
## marks, digits, single spaces and - _ . ' only; 2-16 characters after
## trimming. Everything else (controls, bidi / zero-width formatting,
## emoji, symbols, other scripts) is refused, never silently stripped, so
## what the player typed is what is kept. Unicode NFC normalization is done
## by the native text field (web/social_creator.js) before the name gets
## here; GDScript has no normalizer, so this only validates.

const NAME_MIN := 2
const NAME_MAX := 16
## Combining marks allowed on one letter (Hebrew points: dagesh + vowel +
## shin dot; Arabic: shadda + haraka) - stops "zalgo" stacks.
const MAX_MARKS := 3

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
## "unsupported" (a character outside the allowed set), "mark" (an accent /
## vowel mark with no letter, or too many on one letter), "too_short",
## "too_long", "no_letters".
static func clean_name(raw: String) -> Dictionary:
	var out := PackedStringArray()
	var marks := 0
	var prev_space := true  # collapses runs and drops leading spaces
	for i in raw.length():
		var c := raw.unicode_at(i)
		if c == 0x20:
			if not prev_space:
				out.append(" ")
			prev_space = true
			marks = 0
			continue
		if is_mark(c):
			marks += 1
			if prev_space or marks > MAX_MARKS:
				return {"ok": false, "error": "mark"}
			out.append(String.chr(c))
			continue
		if not is_base(c):
			return {"ok": false, "error": "unsupported"}
		out.append(String.chr(c))
		prev_space = false
		marks = 0
	var name := "".join(out).strip_edges()
	if name == "":
		return {"ok": true, "name": ""}
	if name.length() < NAME_MIN:
		return {"ok": false, "error": "too_short"}
	if name.length() > NAME_MAX:
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


## A short, friendly explanation for an error code.
static func error_text(code: String) -> String:
	match code:
		"too_short": return "Use at least %d characters" % NAME_MIN
		"too_long": return "Use at most %d characters" % NAME_MAX
		"no_letters": return "Use at least one letter or number"
		_: return "Use letters, numbers, spaces and - _ . ' only"


## Letters, digits and the four punctuation marks a name may use.
static func is_base(c: int) -> bool:
	if (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) or _is_punct(c):
		return true
	if c >= 0xC0 and c <= 0x24F:  # Latin-1 letters, Latin Extended-A / B
		return c != 0xD7 and c != 0xF7
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


## Combining marks of the allowed scripts (Latin accents, Hebrew points,
## Arabic harakat).
static func is_mark(c: int) -> bool:
	return (c >= 0x300 and c <= 0x36F) \
		or (c >= 0x591 and c <= 0x5BD) or c == 0x5BF or (c >= 0x5C1 and c <= 0x5C2) or (c >= 0x5C4 and c <= 0x5C5) or c == 0x5C7 \
		or (c >= 0x64B and c <= 0x65F) or c == 0x670 or (c >= 0x6D6 and c <= 0x6DC) or (c >= 0x6DF and c <= 0x6E4) \
		or (c >= 0x6E7 and c <= 0x6E8) or (c >= 0x6EA and c <= 0x6ED)


static func _is_punct(c: int) -> bool:
	return c == 0x2D or c == 0x5F or c == 0x2E or c == 0x27 or c == 0x5BE or c == 0x5F3 or c == 0x5F4
