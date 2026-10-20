extends SceneTree
## VERY HARD VALIDATION (development only, ?vhval3=1): the three-board
## independent human test. COPIES three previously tested boards, exactly as
## stored, from their source files - nothing is generated, rotated,
## recoloured or rebalanced:
##   T3  data/dev/extreme5.json
##   T5  data/dev/extreme5.json
##   H2  data/dev/extreme7.json
## Each copy must keep its source's map, size and fingerprint (sha256 of the
## map, as every board file stores it). Ids and groups are neutral (V1-V3 /
## X-Z, in a seeded shuffle that does not follow the source order); titles,
## explanations and misleading moves are left out (no solution text in the
## test). The source of each board is recorded under "original" for the
## analysis, never shown by the page.
##   godot --headless --path . --script res://tools/vhval3_build.gd [-- --write]

const OUT := "res://data/dev/vh_validation3.json"
const SOURCES := [["res://data/dev/extreme5.json", "T3"], ["res://data/dev/extreme5.json", "T5"], ["res://data/dev/extreme7.json", "H2"]]
## Record fields copied unchanged (measurements and the board itself).
const KEEP := ["puzzle", "mechanics", "first_level", "fingerprint", "canonical", "verify", "metrics", "x", "accepted"]


func _initialize() -> void:
	var picked := []
	var ok := true
	for s in SOURCES:
		var d = JSON.parse_string(FileAccess.get_file_as_string(s[0]))
		var found := {}
		for b in d["boards"]:
			if str(b["id"]) == s[1]:
				found = b
		if found.is_empty():
			push_error("%s not found in %s" % [s[1], s[0]])
			ok = false
			continue
		var fp := JSON.stringify(found["puzzle"]["map"]).sha256_text()
		if fp != found["fingerprint"]:
			push_error("%s: stored fingerprint does not match its map" % s[1])
			ok = false
		var rec := {}
		for k in KEEP:
			rec[k] = found[k]
		rec["original"] = {"file": s[0].trim_prefix("res://"), "id": s[1], "fingerprint": found["fingerprint"], "test": str(d.get("test", ""))}
		picked.append(rec)
		print("%s from %s: fingerprint %s, %dx%d" % [s[1], s[0], fp, found["puzzle"]["cols"], found["puzzle"]["rows"]])
	if not ok:
		quit(1)
		return
	# Neutral ids: a seeded shuffle, so V1-V3 do not follow the source order.
	var rng := RandomNumberGenerator.new()
	rng.seed = 30311
	for i in range(picked.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = picked[i]
		picked[i] = picked[j]
		picked[j] = t
	var groups := ["X", "Y", "Z"]
	var boards := []
	for i in picked.size():
		var rec: Dictionary = {"id": "V%d" % (i + 1), "variant": groups[i]}
		rec.merge(picked[i])
		boards.append(rec)
		print("V%d (group %s) = %s" % [i + 1, groups[i], rec["original"]["id"]])
	var out := {"format": "ce-vh-validation", "v": 1, "test": "vhval3",
		"assist": {"undo": 3, "show_a_move": 1, "hammer": 0},
		"note": "Development only. Three previously tested boards copied unchanged for an independent second-player test (tools/vhval3_build.gd); never shared, never production.",
		"boards": boards}
	if "--write" in OS.get_cmdline_user_args():
		var f := FileAccess.open(OUT, FileAccess.WRITE)
		f.store_string(JSON.stringify(out, "  "))
		f.close()
		print("wrote %s" % OUT)
	quit()
