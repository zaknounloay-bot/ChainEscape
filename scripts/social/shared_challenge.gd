class_name SharedChallenge
extends RefCounted
## Social: one challenge, as the future backend will store and send it.
##
##   SharedChallenge
##     +-- puzzle        PuzzleDefinition: the exact board (generic)
##     +-- type          "photo_message_reveal" (later: "friend_challenge")
##     +-- difficulty    metadata ("easy" / "medium" / "hard")
##     +-- payload       what this type adds; for photo_message_reveal:
##                       {"message": String or null, "photo": {...} or null}
##
## Lives in memory only in 0.2B: no id, no URL, no upload, never in
## PlayerProgress or any save. The photo's bytes stay on this device
## (local_photo_jpeg / local_photo); the payload only describes them, so
## to_dict() is exactly what a later build would transmit next to an
## uploaded image.

const FORMAT := "ce-challenge"
const VERSION := 1
const TYPE_PHOTO_MESSAGE_REVEAL := "photo_message_reveal"
const TYPE_FRIEND_CHALLENGE := "friend_challenge"  # reserved, not built yet

var type := ""
var difficulty := ""
var puzzle: PuzzleDefinition
var payload: Dictionary = {}
## This device only (never serialized).
var local_photo_jpeg := PackedByteArray()
var local_photo: Texture2D


static func photo_message_reveal(session: CreatorSession, p: PuzzleDefinition) -> SharedChallenge:
	var c := SharedChallenge.new()
	c.type = TYPE_PHOTO_MESSAGE_REVEAL
	c.difficulty = session.difficulty
	c.puzzle = p
	c.payload = {
		"message": session.message if session.has_message() else null,
		"photo": {"format": "jpeg", "width": session.image_size.x, "height": session.image_size.y,
			"bytes": session.image_jpeg.size()} if session.has_photo() else null,
	}
	c.local_photo_jpeg = session.image_jpeg
	c.local_photo = session.texture
	return c


func has_photo() -> bool:
	return payload.get("photo") != null and local_photo != null


func message() -> String:
	var m = payload.get("message")
	return m if typeof(m) == TYPE_STRING else ""


func to_dict() -> Dictionary:
	return {"format": FORMAT, "v": VERSION, "type": type, "difficulty": difficulty,
		"puzzle": puzzle.to_dict() if puzzle else null, "payload": payload}


## Rebuilds everything except local media (a recipient would fetch the
## photo separately). Null if the data is malformed.
static func from_dict(data: Dictionary) -> SharedChallenge:
	if data.get("format", "") != FORMAT or int(data.get("v", 0)) != VERSION:
		return null
	var pd = data.get("puzzle")
	var p := PuzzleDefinition.from_dict(pd) if typeof(pd) == TYPE_DICTIONARY else null
	if p == null:
		return null
	var c := SharedChallenge.new()
	c.type = str(data.get("type", ""))
	c.difficulty = str(data.get("difficulty", ""))
	c.puzzle = p
	var pl = data.get("payload", {})
	c.payload = pl if typeof(pl) == TYPE_DICTIONARY else {}
	return c
