class_name WebBridge
## All calls from the game into the page go through here (v0.5.1).
##
## They are plain FUNCTION CALLS on the page's window.ceAudio object
## (web/audio_unlock.js) through one cached JavaScriptObject - never
## JavaScriptBridge.eval() of generated source. Evaluating a fresh source
## string compiles a new script every time; done twice a second (audio
## state) and on every save (a ~5 KB string), that kept memory growing in
## the browser over a long session. Function calls compile nothing.
## Everything is a no-op outside the Web build.

static var _api: JavaScriptObject
static var _checked := false


## window.ceAudio, or null (not Web / page script missing).
static func api() -> JavaScriptObject:
	if not _checked:
		_checked = true
		if OS.has_feature("web"):
			var w := JavaScriptBridge.get_interface("window")
			if w and w.ceAudio:
				_api = w.ceAudio
	return _api


static func available() -> bool:
	return api() != null


## window[name] = value (a read-only snapshot for tests / remote debugging).
static func publish(name: String, value: Dictionary) -> void:
	if api():
		_api.publish(name, JSON.stringify(value))


static func ls_set(key: String, value: String) -> bool:
	return api() != null and bool(_api.lsSet(key, value))


static func ls_get(key: String) -> String:
	if api() == null:
		return ""
	var v = _api.lsGet(key)
	return str(v) if v != null else ""


## Calls window.ceAudio.<method>(args...) and returns its result.
static func call_api(method: String, args: Array = []) -> Variant:
	if api() == null:
		return null
	return _api.callv(method, args)


## A method that returns a JS object: returned as a JSON string by the page
## (ceAudio.json(method)) and parsed here.
static func call_json(method: String) -> Dictionary:
	if api() == null:
		return {}
	var parsed = JSON.parse_string(str(_api.json(method)))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
