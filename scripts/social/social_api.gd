class_name SocialApi
extends Node
## Social: talks to the "chain-escape-api" Edge Function (SocialConfig).
## The function does every privileged database / storage operation on the
## server; this client only sends a challenge and reads one back by id.
##
##   CREATE  POST <api>   {challenge_type, difficulty, puzzle, message?,
##                          image_base64?, image_type?}
##           -> {ok: true, challenge_id, expires_at}
##   READ    GET  <api>?action=read&id=<uuid>
##           -> {ok: true, challenge: {challenge_type, difficulty, puzzle,
##                                     payload, media_url, expires_at, ...}}
##
## Everything that comes back is untrusted: it is validated, and a puzzle is
## rebuilt from its explicit board data and Solver-verified, before anything
## uses it. Errors come back as short codes for friendly messages; server
## text, messages, images and signed URLs are never logged.

## Error codes: not_configured, network, timeout, rate_limited, rejected,
## server, invalid_response, invalid_id, not_found, expired, malformed,
## unsupported, too_large.

const SUPPORTED_TYPES := [SharedChallenge.TYPE_PHOTO_MESSAGE_REVEAL]


## Sends a prepared challenge. Returns {ok, challenge_id, expires_at} or
## {ok: false, error}.
func create_challenge(c: SharedChallenge) -> Dictionary:
	if not SocialConfig.sharing_enabled():
		return {"ok": false, "error": "not_configured"}
	var body := build_create_body(c)
	if body.has("error"):
		return {"ok": false, "error": body["error"]}
	var text := JSON.stringify(body)
	if text.length() > SocialConfig.MAX_REQUEST_BYTES:
		return {"ok": false, "error": "too_large"}
	var r := await _request(HTTPClient.METHOD_POST, SocialConfig.api_url(), text)
	if not r["ok"]:
		return r
	return parse_create_response(r["code"], r["data"])


## Fetches a challenge by id. Returns {ok, challenge: SharedChallenge,
## expires_at} (challenge.media_url holds the signed photo URL, if any) or
## {ok: false, error}.
func read_challenge(id: String) -> Dictionary:
	if not ShareLink.is_valid_id(id):
		return {"ok": false, "error": "invalid_id"}
	if not SocialConfig.sharing_enabled():
		return {"ok": false, "error": "not_configured"}
	var url := "%s?action=read&id=%s" % [SocialConfig.api_url(), id.to_lower()]
	var r := await _request(HTTPClient.METHOD_GET, url, "")
	if not r["ok"]:
		return r
	return parse_read_response(r["code"], r["data"])


## The CREATE request body for `c`: the exact PuzzleDefinition (explicit
## board, as serialized), the type, difficulty and payload. The photo is
## the processed copy from the creator session (<= 1080 px, re-encoded, no
## EXIF), never the original file. {"error": ...} if it can't be sent.
static func build_create_body(c: SharedChallenge) -> Dictionary:
	if c == null or c.puzzle == null or not c.type in SUPPORTED_TYPES:
		return {"error": "rejected"}
	var body := {"challenge_type": c.type, "difficulty": c.difficulty, "puzzle": c.puzzle.to_dict()}
	var message := c.message()
	if message != "":
		if message.length() > CreatorSession.MESSAGE_MAX:
			return {"error": "rejected"}
		body["message"] = message
	if not c.local_photo_jpeg.is_empty():
		if c.local_photo_jpeg.size() > SocialConfig.MAX_IMAGE_BYTES:
			return {"error": "too_large"}
		body["image_base64"] = Marshalls.raw_to_base64(c.local_photo_jpeg)
		body["image_type"] = "image/jpeg"
	if message == "" and not body.has("image_base64"):
		return {"error": "rejected"}  # nothing to reveal
	return body


static func parse_create_response(code: int, data) -> Dictionary:
	if code < 200 or code >= 300 or typeof(data) != TYPE_DICTIONARY or data.get("ok") != true:
		return {"ok": false, "error": _error_for(code, data)}
	var id := str(data.get("challenge_id", "")).to_lower()
	if not ShareLink.is_valid_id(id):
		return {"ok": false, "error": "invalid_response"}
	return {"ok": true, "challenge_id": id, "expires_at": str(data.get("expires_at", ""))}


## Validates a READ response and rebuilds the challenge from it.
static func parse_read_response(code: int, data) -> Dictionary:
	if code < 200 or code >= 300 or typeof(data) != TYPE_DICTIONARY or data.get("ok") != true:
		return {"ok": false, "error": _error_for(code, data)}
	var ch = data.get("challenge")
	if typeof(ch) != TYPE_DICTIONARY:
		return {"ok": false, "error": "malformed"}
	var expires := str(ch.get("expires_at", ""))
	if expires != "" and _is_past(expires):
		return {"ok": false, "error": "expired"}
	var result := SharedChallenge.from_api(ch)
	if result.has("error"):
		return {"ok": false, "error": result["error"]}
	return {"ok": true, "challenge": result["challenge"], "expires_at": expires}


static func _error_for(code: int, data) -> String:
	var e := ""
	if typeof(data) == TYPE_DICTIONARY:
		e = str(data.get("error", "")).to_lower()
	if code == 404 or e.contains("not found") or e.contains("not_found"):
		return "not_found"
	if code == 410 or e.contains("expired"):
		return "expired"
	if code == 429:
		return "rate_limited"
	if code >= 400 and code < 500:
		return "rejected"
	if code >= 500:
		return "server"
	return "invalid_response"


## ISO-8601 UTC timestamp in the past? (unparseable = not past; the server
## enforces expiry anyway).
static func _is_past(iso: String) -> bool:
	var t := iso.replace("Z", "").get_slice("+", 0)
	if t.length() < 19:
		return false
	var unix := Time.get_unix_time_from_datetime_string(t.substr(0, 19))
	return unix > 0 and unix < Time.get_unix_time_from_system()


func _request(method: int, url: String, body: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = SocialConfig.timeout_override if SocialConfig.timeout_override > 0.0 else SocialConfig.TIMEOUT_SEC
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json"])
	if SocialConfig.API_PUBLIC_KEY != "":
		headers.append("apikey: " + SocialConfig.API_PUBLIC_KEY)
		headers.append("Authorization: Bearer " + SocialConfig.API_PUBLIC_KEY)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "error": "network"}
	var res: Array = await req.request_completed
	req.queue_free()
	var result: int = res[0]
	if result == HTTPRequest.RESULT_TIMEOUT:
		return {"ok": false, "error": "timeout"}
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network"}
	var text := (res[3] as PackedByteArray).get_string_from_utf8()
	var data = JSON.parse_string(text) if text != "" else null
	print("[Social] API %s -> HTTP %d" % ["POST" if method == HTTPClient.METHOD_POST else "GET", res[1]])
	return {"ok": true, "code": res[1], "data": data}
