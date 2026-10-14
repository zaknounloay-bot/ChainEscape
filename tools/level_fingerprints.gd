## Phase 3B-A: writes data/level_fingerprints.json - the fingerprint
## (LevelFingerprint) of every campaign level - or, with --check, verifies it
## (exit 1 on a stale, missing or mismatched entry; the level files are only
## read, never changed):
##   godot --headless --path . --script res://tools/level_fingerprints.gd
##   godot --headless --path . --script res://tools/level_fingerprints.gd -- --check
## Run after changing any level's gameplay definition (tools/run_tests.gd
## fails while the manifest is stale).
extends SceneTree


static func manifest_text(prints: Array) -> String:
	return JSON.stringify({"version": LevelFingerprint.VERSION, "levels": prints.size(),
		"algorithm": "sha256(\"chain-escape-level|v%d|<number>|<gameplay json>\")" % LevelFingerprint.VERSION,
		"fingerprints": prints}, "\t") + "\n"


## Problems of the manifest on disk against the level files ([] = in sync).
static func problems() -> Array:
	var out := []
	var prints := LevelFingerprint.compute_all()
	if not FileAccess.file_exists(LevelFingerprint.MANIFEST_PATH):
		return ["manifest missing"]
	var data = JSON.parse_string(FileAccess.get_file_as_string(LevelFingerprint.MANIFEST_PATH))
	if not data is Dictionary or int(data.get("version", 0)) != LevelFingerprint.VERSION:
		return ["manifest unreadable or wrong version"]
	var stored: Array = data.get("fingerprints", [])
	if stored.size() != prints.size() or int(data.get("levels", 0)) != prints.size():
		out.append("manifest has %d levels, the campaign %d" % [stored.size(), prints.size()])
	for i in mini(stored.size(), prints.size()):
		if str(stored[i]) != prints[i]:
			out.append("level %d: stale fingerprint" % (i + 1))
	for p in prints:
		if prints.count(p) > 1:
			out.append("duplicate fingerprint %s" % p)
			break
	return out


func _init() -> void:
	if "--check" in OS.get_cmdline_user_args():
		var bad := problems()
		for b in bad:
			printerr("FINGERPRINT: " + b)
		print("LEVEL FINGERPRINTS %s (%d levels)" % ["OK" if bad.is_empty() else "STALE", LevelFingerprint.compute_all().size()])
		quit(0 if bad.is_empty() else 1)
		return
	var prints := LevelFingerprint.compute_all()
	var f := FileAccess.open(LevelFingerprint.MANIFEST_PATH, FileAccess.WRITE)
	f.store_string(manifest_text(prints))
	f.close()
	print("level fingerprints: %d levels written to %s" % [prints.size(), LevelFingerprint.MANIFEST_PATH])
	quit()
