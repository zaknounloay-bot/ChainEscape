class_name SharedChallenge
extends RefCounted
## Social: one challenge, as the future backend will store and send it.
##
##   SharedChallenge
##     +-- puzzle        PuzzleDefinition: the exact board (generic)
##     +-- type          "photo_message_reveal" | "friend_challenge"
##     +-- difficulty    metadata: "easy" / "medium" / "hard", plus
##                       "very_hard" for friend_challenge only
##     +-- payload       what this type adds:
##                       photo_message_reveal {"message": String or null,
##                                             "photo": {...} or null}
##                       friend_challenge     {} or {"surprise_me": true}
##                                            (SURPRISE ME was the choice;
##                                            the real difficulty stays in
##                                            `difficulty`)
##
## The challenge is the immutable shared puzzle: every recipient of the
## same id plays the same PuzzleDefinition. Results (later) are separate
## records that point at the challenge id - never stored in it.
##
## Lives in memory only in 0.2B: no id, no URL, no upload, never in
## PlayerProgress or any save. The photo's bytes stay on this device
## (local_photo_jpeg / local_photo); the payload only describes them, so
## to_dict() is exactly what a later build would transmit next to an
## uploaded image.

const FORMAT := "ce-challenge"
const VERSION := 1
const TYPE_PHOTO_MESSAGE_REVEAL := "photo_message_reveal"
const TYPE_FRIEND_CHALLENGE := "friend_challenge"
## Difficulties each type may carry (VERY HARD is Challenge a Friend only:
## the Photo / Message Reveal creator never offers it).
const DIFFICULTIES_BY_TYPE := {
	TYPE_PHOTO_MESSAGE_REVEAL: ["easy", "medium", "hard"],
	TYPE_FRIEND_CHALLENGE: ["easy", "medium", "hard", "very_hard"],
}

var type := ""
var difficulty := ""
var puzzle: PuzzleDefinition
var payload: Dictionary = {}
## This device only (never serialized).
var local_photo_jpeg := PackedByteArray()
var local_photo: Texture2D
## Network (0.2C): the server's id once created / read, its expiry, and -
## for a challenge read from the server - the temporary signed photo URL.
## Never part of to_dict().
var remote_id := ""
var expires_at := ""
var media_url := ""


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


## Challenge a Friend: `difficulty` is the REAL one (never "surprise");
## `surprise` records that the creator chose SURPRISE ME.
static func friend_challenge(p: PuzzleDefinition, p_difficulty: String, surprise: bool = false) -> SharedChallenge:
	var c := SharedChallenge.new()
	c.type = TYPE_FRIEND_CHALLENGE
	c.difficulty = p_difficulty
	c.puzzle = p
	c.payload = {"surprise_me": true} if surprise else {}
	return c


func is_surprise() -> bool:
	return payload.get("surprise_me") == true


## A challenge as the API returns it (READ). Untrusted: every field is
## checked and the puzzle is rebuilt from its explicit board data and
## Solver-verified - never regenerated from the difficulty.
## Returns {"challenge": SharedChallenge} or {"error": code}.
static func from_api(ch: Dictionary) -> Dictionary:
	var t := str(ch.get("challenge_type", ""))
	if not DIFFICULTIES_BY_TYPE.has(t):
		return {"error": "unsupported"}
	var pd = ch.get("puzzle")
	if typeof(pd) != TYPE_DICTIONARY:
		return {"error": "malformed"}
	if str(pd.get("format", "")) != PuzzleDefinition.FORMAT or int(pd.get("v", 0)) != PuzzleDefinition.VERSION \
			or int(pd.get("rules", 0)) != PuzzleDefinition.RULES:
		return {"error": "unsupported"}  # a newer / older puzzle format
	var p := PuzzleDefinition.from_dict(pd)
	if p == null or not p.verify():
		return {"error": "malformed"}
	var d := str(ch.get("difficulty", ""))
	if not d in DIFFICULTIES_BY_TYPE[t]:
		return {"error": "malformed"}
	var pl = ch.get("payload", {})
	if pl == null:
		pl = {}
	if typeof(pl) != TYPE_DICTIONARY:
		return {"error": "malformed"}
	if t == TYPE_FRIEND_CHALLENGE:
		return _friend_from_api(ch, p, d, pl)
	var msg = pl.get("message")
	if msg != null and (typeof(msg) != TYPE_STRING or msg.length() > CreatorSession.MESSAGE_MAX):
		return {"error": "malformed"}
	var url = ch.get("media_url")
	if url != null and (typeof(url) != TYPE_STRING
			or not (url.begins_with("https://") or (SocialConfig.allow_http_media and url.begins_with("http://")))):
		return {"error": "malformed"}
	var has_media: bool = typeof(pl.get("media")) == TYPE_DICTIONARY
	var message := CreatorSession.clean_message(msg) if typeof(msg) == TYPE_STRING else ""
	if message == "" and not has_media:
		return {"error": "malformed"}  # nothing to reveal
	var c := SharedChallenge.new()
	c.type = t
	c.difficulty = d
	c.puzzle = p
	c.payload = {"message": message if message != "" else null, "photo": {"format": "remote"} if has_media else null}
	c.remote_id = str(ch.get("id", ""))
	c.expires_at = str(ch.get("expires_at", ""))
	c.media_url = url if typeof(url) == TYPE_STRING else ""
	return {"challenge": c}


## friend_challenge READ: the exact puzzle and its real difficulty. No
## message or photo belongs to this type (one present = malformed), and
## its boards use only the mechanics Challenge a Friend generates.
static func _friend_from_api(ch: Dictionary, p: PuzzleDefinition, d: String, pl: Dictionary) -> Dictionary:
	if pl.get("message") != null or pl.get("media") != null or ch.get("media_url") != null:
		return {"error": "malformed"}
	var surprise = pl.get("surprise_me", false)
	if typeof(surprise) != TYPE_BOOL or not FriendGenerator.mechanics_ok(p, FriendGenerator.MEDIUM):
		return {"error": "malformed"}
	var c := friend_challenge(p, d, surprise)
	c.remote_id = str(ch.get("id", ""))
	c.expires_at = str(ch.get("expires_at", ""))
	return {"challenge": c}


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
