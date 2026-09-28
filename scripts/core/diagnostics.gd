class_name Diagnostics
## Stability diagnostics (v0.5.1). One compact line per level transition,
## never per frame:
##   [Diag] L45 ch5 via=next t=812s fps=60 mem=41.2MB objs=5123 nodes=402 orphans=0
##          res=311 tweens=3 fx=0 music=c05(1 playing) wasm=96MB js=12MB
## The last line is also kept in the browser's localStorage together with a
## session marker, so after an unexpected exit (for example iOS Safari
## reloading the page) the next launch reports where the previous session
## ended. The debug panel shows both (F1, or tap the level title 5 times).

const LAST_KEY := "chain_escape_diag_last"
const SESSION_KEY := "chain_escape_session"

static var enabled: bool = true
static var session_start_ms: int = Time.get_ticks_msec()
static var last_line: String = ""
## What the previous session left behind ("" = clean or first run).
static var previous_session: String = ""
static var _baseline: Dictionary = {}


## Current resource counts. Cheap: a handful of engine counters.
static func snapshot(tree: SceneTree = null) -> Dictionary:
	var d := {
		"t": (Time.get_ticks_msec() - session_start_ms) / 1000,
		"fps": int(Performance.get_monitor(Performance.TIME_FPS)),
		"mem_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"tweens": tree.get_processed_tweens().size() if tree else -1,
	}
	if OS.has_feature("web"):
		# Filled by web/audio_unlock.js (WebAssembly memory + Chrome's JS heap).
		var mem := WebBridge.call_json("memory")
		if not mem.is_empty():
			d["wasm_mb"] = mem.get("wasm", 0)
			d["js_mb"] = mem.get("js", 0)
	return d


## Logs one line for a level transition and stores it for crash forensics.
static func level_transition(level: int, chapter: int, via: String, tree: SceneTree, extra: Dictionary = {}) -> Dictionary:
	var s := snapshot(tree)
	s.merge(extra)
	if _baseline.is_empty():
		_baseline = s.duplicate()
	if not enabled:
		return s
	var line := "[Diag] L%d ch%d via=%s t=%ds fps=%d mem=%.1fMB objs=%d nodes=%d orphans=%d res=%d tweens=%d" % [
		level, chapter, via, s["t"], s["fps"], s["mem_mb"], s["objects"], s["nodes"], s["orphans"], s["resources"], s["tweens"]]
	for k in extra:
		line += " %s=%s" % [k, str(extra[k])]
	if s.has("wasm_mb"):
		line += " wasm=%sMB js=%sMB" % [s["wasm_mb"], s["js_mb"]]
	last_line = line
	print(line)
	_store(SESSION_KEY, JSON.stringify({"state": "running", "level": level, "t": s["t"], "line": line}))
	return s


## Called once at startup: reads what the previous session left and marks
## this one as running.
static func start_session() -> void:
	session_start_ms = Time.get_ticks_msec()
	var prev := _load(SESSION_KEY)
	if prev != "":
		var p = JSON.parse_string(prev)
		if typeof(p) == TYPE_DICTIONARY and p.get("state", "") == "running" and int(p.get("level", 0)) > 0:
			previous_session = "last session ended at level %d after %ds: %s | %s" % [
				int(p.get("level", 0)), int(p.get("t", 0)), _how_it_ended(), String(p.get("line", ""))]
			print("[Diag] " + previous_session)
	_store(SESSION_KEY, JSON.stringify({"state": "running", "level": 0, "t": 0, "line": ""}))


## Web: reads the page events the previous page load recorded
## (web/audio_unlock.js) and names the likely way the session ended.
static func _how_it_ended() -> String:
	if not OS.has_feature("web"):
		return "process ended without a clean quit"
	var raw := str(WebBridge.call_api("pageEvents")) if WebBridge.available() else ""
	var e = JSON.parse_string(raw) if raw != "" and raw != "<null>" else null
	if typeof(e) != TYPE_DICTIONARY:
		return "no page events recorded"
	if e.get("context_lost_at", 0):
		return "GRAPHICS RESET (WebGL context lost%s) - recovered by reload" % (" while in background" if e.get("context_lost_hidden", false) else "")
	if e.get("abort_at", 0):
		return "ENGINE ABORT: %s" % e.get("abort", "")
	if e.get("error_at", 0):
		return "JS ERROR: %s" % e.get("error", "")
	if e.get("pagehide_at", 0):
		return "page closed or navigated away normally"
	if e.get("hidden_at", 0):
		return "page was in the background (browser discarded or closed it)"
	return "CRASHED WHILE VISIBLE (no page-hide event: the browser's web process died or reloaded)"


## Clean shutdown (quit / page hidden for good): the next launch won't
## report an unexpected exit.
static func end_session() -> void:
	_store(SESSION_KEY, JSON.stringify({"state": "closed"}))


## Growth since the first level of this session (leak check in tests).
static func growth(tree: SceneTree) -> Dictionary:
	var now := snapshot(tree)
	var out := {}
	for k in ["objects", "nodes", "orphans", "resources", "mem_mb"]:
		out[k] = now[k] - _baseline.get(k, now[k])
	return out


static func _store(key: String, value: String) -> void:
	if OS.has_feature("web"):
		WebBridge.ls_set(key, value)
	else:
		var f := FileAccess.open("user://%s.json" % key, FileAccess.WRITE)
		if f:
			f.store_string(value)


static func _load(key: String) -> String:
	if OS.has_feature("web"):
		return WebBridge.ls_get(key)
	if FileAccess.file_exists("user://%s.json" % key):
		return FileAccess.get_file_as_string("user://%s.json" % key)
	return ""
