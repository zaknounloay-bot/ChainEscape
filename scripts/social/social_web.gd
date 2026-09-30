class_name SocialWeb
## Social MVP 0.2A: calls into web/social_creator.js (window.ceSocial) for
## the photo picker and the message dialog. Separate from WebBridge (audio,
## saves, backup codes) on purpose. Plain function calls on one cached
## object, never JavaScriptBridge.eval(). No-op outside the Web build.

static var _api: JavaScriptObject
static var _checked := false


static func api() -> JavaScriptObject:
	if not _checked:
		_checked = true
		if OS.has_feature("web"):
			var w := JavaScriptBridge.get_interface("window")
			if w and w.ceSocial:
				_api = w.ceSocial
	return _api


static func available() -> bool:
	return api() != null


## Screen rectangles (normalized 0..1 to the viewport) where a tap opens
## the photo picker (id "photo") or the message dialog (id "message").
static func set_zones(zones: Array) -> void:
	if api():
		_api.setZones(JSON.stringify(zones))


static func clear_zones() -> void:
	set_zones([])


## {} while nothing is ready, else {ok, w, h, source_w, source_h, b64} or
## {ok: false, error}.
static func take_photo() -> Dictionary:
	return _take("takePhoto")


static func photo_busy() -> bool:
	return api() != null and bool(_api.photoBusy())


static func set_draft(text: String) -> void:
	if api():
		_api.setDraft(text)


## {} while the dialog is open / unused, else {done, text}.
static func take_message() -> Dictionary:
	return _take("takeMessage")


static func dialog_open() -> bool:
	return api() != null and bool(_api.dialogOpen())


static func reset() -> void:
	if api():
		_api.reset()


static func _take(method: String) -> Dictionary:
	if api() == null:
		return {}
	var raw = _api.callv(method, [])
	if raw == null or str(raw) == "":
		return {}
	var parsed = JSON.parse_string(str(raw))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
