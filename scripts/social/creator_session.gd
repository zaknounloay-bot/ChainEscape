class_name CreatorSession
extends RefCounted
## Social MVP 0.2A: what the creator has chosen so far in the Photo /
## Message Reveal flow. Memory only - never written to PlayerProgress, the
## Classic save or anywhere else, and dropped when the creator leaves the
## flow. Shaped so it can later become a SharedChallenge (to_dict()).

const TYPE_PHOTO_MESSAGE_REVEAL := "photo_message_reveal"
## Counted as the server counts it (JavaScript string length: UTF-16 code
## units, so most emoji count 2) - see utf16_length().
const MESSAGE_MAX := 200
const MESSAGE_MAX_LINES := 6
## Difficulties the API accepts for this type. The creator no longer asks
## (phase 4 MVP): every new reveal is SocialGenerator.REVEAL, stored "easy".
const DIFFICULTIES := ["easy", "medium", "hard"]

var challenge_type := TYPE_PHOTO_MESSAGE_REVEAL
## Local working copy of the chosen photo: a downscaled JPEG made on this
## device (the original file is never modified or kept).
var image_jpeg := PackedByteArray()
var image_size := Vector2i.ZERO
## Size of the photo the creator picked, before downscaling.
var source_size := Vector2i.ZERO
## Display texture of image_jpeg (not part of the challenge data).
var texture: Texture2D
var message := ""
var difficulty := SocialGenerator.REVEAL_DIFFICULTY  # always "easy" for new reveals


func has_photo() -> bool:
	return not image_jpeg.is_empty()


func has_message() -> bool:
	return message != ""


## Photo from JPEG bytes. Returns false (and keeps the old photo) if the
## bytes are not a readable image.
func set_photo_jpeg(bytes: PackedByteArray, source: Vector2i = Vector2i.ZERO) -> bool:
	var img := Image.new()
	if bytes.is_empty() or img.load_jpg_from_buffer(bytes) != OK or img.is_empty():
		return false
	image_jpeg = bytes
	image_size = img.get_size()
	source_size = source if source != Vector2i.ZERO else image_size
	texture = ImageTexture.create_from_image(img)
	return true


func clear_photo() -> void:
	image_jpeg = PackedByteArray()
	image_size = Vector2i.ZERO
	source_size = Vector2i.ZERO
	texture = null


## Whitespace-only means no message. Line breaks are kept (at most
## MESSAGE_MAX_LINES lines, no empty runs) and the text is cut at
## MESSAGE_MAX characters.
func set_message(text: String) -> void:
	message = clean_message(text)


static func clean_message(text: String) -> String:
	var lines: Array[String] = []
	var blank := false
	for raw in text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
		var line := String(raw).strip_edges(false, true)
		if line.strip_edges() == "":
			if not lines.is_empty() and not blank:
				lines.append("")
			blank = true
			continue
		blank = false
		lines.append(line)
	while not lines.is_empty() and lines[-1] == "":
		lines.pop_back()
	while lines.size() > MESSAGE_MAX_LINES:
		lines.pop_back()
	# The Web text field cuts at 200 UTF-16 units and can split an emoji in
	# two; that half arrives as U+FFFD (never typed on purpose): drop it.
	var out := "\n".join(PackedStringArray(lines)).replace(String.chr(0xFFFD), "").strip_edges()
	return utf16_left(out, MESSAGE_MAX)


## Length as JavaScript (and the server) counts it: UTF-16 code units, so a
## character outside the Basic Multilingual Plane (most emoji) counts 2.
static func utf16_length(text: String) -> int:
	var n := 0
	for i in text.length():
		n += 2 if text.unicode_at(i) > 0xFFFF else 1
	return n


## The longest start of `text` within `limit` UTF-16 units (never splits a
## character).
static func utf16_left(text: String, limit: int) -> String:
	var n := 0
	for i in text.length():
		n += 2 if text.unicode_at(i) > 0xFFFF else 1
		if n > limit:
			return text.left(i)
	return text


func set_difficulty(d: String) -> void:
	if d in DIFFICULTIES:
		difficulty = d


## Problems that stop CREATE CHALLENGE (empty = ready).
func validate() -> Array[String]:
	var errors: Array[String] = []
	if challenge_type != TYPE_PHOTO_MESSAGE_REVEAL:
		errors.append("type")
	if not has_photo() and not has_message():
		errors.append("nothing_to_reveal")
	if utf16_length(message) > MESSAGE_MAX:
		errors.append("message_too_long")
	if not difficulty in DIFFICULTIES:
		errors.append("difficulty")
	return errors


func is_valid() -> bool:
	return validate().is_empty()


## Plain data for the future SharedChallenge step (no ids, no URLs, no
## upload - those belong to the backend build). The image stays a local
## reference here.
func to_dict() -> Dictionary:
	return {
		"challenge_type": challenge_type,
		"image": {"local": has_photo(), "format": "jpeg", "width": image_size.x, "height": image_size.y,
			"bytes": image_jpeg.size()} if has_photo() else null,
		"message": message if has_message() else null,
		"difficulty": difficulty,
	}
