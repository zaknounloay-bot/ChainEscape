class_name LevelFingerprint
## CAMPAIGN LEVEL FINGERPRINTS (Phase 3B-A, competition foundation): one
## stable SHA-256 per campaign level, so a future time comparison only ever
## puts together results of the very same board.
##
## Input = the level file's GAMEPLAY definition: every key of
## levels/level_NN.json except the presentation-only ones (the name and the
## tutorial texts). Today that is "map" and, on some levels, "mystery"; any
## gameplay key added later (hearts, hints, stars, ...) is included
## automatically. The keys are sorted and written as compact JSON, then
## hashed together with the version and the level number:
##   sha256("chain-escape-level|v1|<number>|<canonical json>")
## Renaming a level or editing its tutorial text keeps its fingerprint; any
## change to the board or its rules gives a new one.
##
## data/level_fingerprints.json holds all of them (tools/level_fingerprints.gd
## writes and checks it; tools/run_tests.gd fails when it is stale).

const VERSION := 1
const MANIFEST_PATH := "res://data/level_fingerprints.json"
const PRESENTATION_KEYS := ["name", "hint", "hint_finger", "blocked_hint"]

static var _manifest: Array = []


## Compact JSON of the gameplay keys, sorted ("" = not a level).
static func canonical(json: Variant) -> String:
	if not json is Dictionary:
		return ""
	var keys: Array = (json as Dictionary).keys().filter(func(k): return not PRESENTATION_KEYS.has(k))
	keys.sort()
	var kept := {}
	for k in keys:
		kept[k] = json[k]
	return JSON.stringify(kept, "", true)


## The fingerprint of campaign level `number`, computed from its file
## ("" = no such level).
static func compute(number: int) -> String:
	var path := LevelManager.LEVEL_PATH % number
	if number < 1 or not FileAccess.file_exists(path):
		return ""
	var text := canonical(JSON.parse_string(FileAccess.get_file_as_string(path)))
	if text == "":
		return ""
	return ("chain-escape-level|v%d|%d|%s" % [VERSION, number, text]).sha256_text()


## Every campaign level's fingerprint, level 1 first.
static func compute_all() -> Array:
	var out := []
	var n := 1
	while FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
		out.append(compute(n))
		n += 1
	return out


## The fingerprint recorded in the manifest for `number` ("" = none).
static func expected(number: int) -> String:
	if _manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
		if data is Dictionary and int(data.get("version", 0)) == VERSION:
			_manifest = data.get("fingerprints", [])
	return str(_manifest[number - 1]) if number >= 1 and number <= _manifest.size() else ""
