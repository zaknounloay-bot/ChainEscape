extends SceneTree
## VERY HARD blind human test 2 (development only, ?vhtest2=1): builds
## data/dev/vh_human_test2.json from boards that already exist.
##   godot --headless --path . --script res://tools/vh_human_test2_build.gd
## Variants (never shown to the tester; every board rotated 180 degrees so
## a known board is not recognised - a rotation keeps the puzzle identical,
## clockwise spinners stay clockwise):
##   B  the 5 strongest heuristic-selected Friend boards of test 1
##   D  the 5 Classic levels after 40 that use only arrows + clockwise
##      spinners (42, 44, 47, 51, 55), exact (reward markers removed: they
##      change nothing in play but would look like Classic)
##   E  late Classic GEOMETRY (161-200) flattened to arrows + clockwise
##      spinners (other mechanics removed), the 4 that stay solvable AND keep
##      a hard structure: 163, 165, 169, 194
## Selection reasons: docs/vh_human_test2.md.

const OUT := "res://data/dev/vh_human_test2.json"
const B_IDS := ["T01", "T03", "T04", "T10", "T11"]
const D_LEVELS := [42, 44, 47, 51, 55]
const E_LEVELS := [163, 165, 169, 194]


func _init() -> void:
	var audit = load("res://tools/classic_topology_audit.gd")
	var boards := []
	var test1 = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/vh_human_test.json"))
	for b in test1["boards"]:
		if b["id"] in B_IDS:
			boards.append(_record(audit, "B", "test1 %s" % b["id"], audit.rotate180(PuzzleDefinition.from_dict(b["puzzle"]))))
	for n in D_LEVELS:
		var def := _classic(n)
		_assert(audit.pure(def), "L%d is pure" % n)
		var clean: PuzzleDefinition = audit.flatten(def)  # pure: only drops reward markers
		boards.append(_record(audit, "D", "Classic L%d (exact)" % n, audit.rotate180(clean)))
	for n in E_LEVELS:
		boards.append(_record(audit, "E", "Classic L%d geometry, flattened" % n, audit.rotate180(audit.flatten(_classic(n)))))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261003
	for i in range(boards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = boards[i]
		boards[i] = boards[j]
		boards[j] = t
	for i in boards.size():
		boards[i]["id"] = "P%02d" % (i + 1)
	var data := {"format": "ce-vh-human-test", "v": 2, "assist": {"undo": 3, "show_a_move": 1, "hammer": 1}, "boards": boards}
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()
	print("wrote %s: %d boards" % [OUT, boards.size()])
	for b in boards:
		var m: Dictionary = b["metrics"]
		print("%s %s %-36s %s blocks=%d density=%.2f start=%d safe=%d calm=%d tempting=%d scan=%.2f later_scan=%.2f hidden_steps=%d one_safe=%d depth=%d smart2=%.2f" % [
			b["id"], b["variant"], b["source"], m["size"], m["blocks"], m["density"], m["start"], m["start_safe"], m["start_calm"], m["tempting"],
			m["scan"], m["later_scan"], m["hidden_steps"], m["one_safe"], m["depth"], m["smart2"]])
	quit()


func _classic(n: int) -> PuzzleDefinition:
	var json = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n))
	return PuzzleDefinition.from_level(LevelManager.parse_level(json, n))


func _record(audit, variant: String, source: String, def: PuzzleDefinition) -> Dictionary:
	_assert(def != null and def.verify(), "%s: verified" % source)
	_assert(FriendGenerator.mechanics_ok(def, FriendGenerator.VERY_HARD), "%s: arrows + clockwise spinners only" % source)
	var rebuilt := PuzzleDefinition.from_json(def.to_json())
	_assert(rebuilt != null and rebuilt.fingerprint() == def.fingerprint(), "%s: exact JSON round trip" % source)
	var m: Dictionary = audit.measure(def)
	return {"variant": variant, "source": source, "puzzle": def.to_dict(), "fingerprint": def.fingerprint(), "metrics": m}


func _assert(ok: bool, what: String) -> void:
	if not ok:
		push_error("vh_human_test2_build: " + what)
		quit(1)
