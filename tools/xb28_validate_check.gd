extends SceneTree
## PHASE 28 (development only): tests for tools/xb28_validate.gd, the
## generator's pre-solve token guard (docs/extreme90_phase28.md, section D).
##   godot --headless --path . --script res://tools/xb28_validate_check.gd [-- --run=run.json]
## 1. Agreement with the engine: every token below is parsed by the real level
##    parser and written back (LevelManager.to_json_text). A token the
##    validator accepts must come back unchanged; a token it refuses must come
##    back changed (refused or repaired) - the validator never disagrees with
##    the parser on these cases.
## 2. Every EXTREME record (data/dev/ta90_n*.json) is valid, and its
##    fingerprint is unchanged.
## 3. Every Classic level (levels/*.json) is valid.
## 4. --run: a generator run made with the guard has 0 invalid qualifying boards.

const V := preload("res://tools/xb28_validate.gd")

## [token, partners placed beside it so the board's groups are complete]
const VALID := ["R>", "R>@", "R>@-", "R>@~", "R>@*", "R>#G", "R>@#G", "R>%A", "R>&A", "R>+C", "R>@+C", "R>=", "R>&A=",
	"R>&A+C", "R>#G&A", "R>+C=", "R>:^", "R>*", "R>#G+C", "R>%A+C", "R>&A*"]
const INVALID := ["R>@=", "R>@&A", "R>@%A", "R>@-=", "R>@~&A", "R>%A&A", "R>#G=", "R>%A=", "R>#R", "R>#G:^", "R>=:^",
	"R>:^*", "R>#G*", "R>=*", "R>+C*", "R>%A*", "R>@?"]

var passed := 0
var failures := []


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "true"
	LevelManager.dev_magnet = true
	LevelManager.dev_movable = true
	LevelManager.dev_sequence = true
	var agree := true
	var detail := []
	for t in VALID + INVALID:
		var ok: bool = V.token_problems(t).is_empty()
		var back: String = _round_trip(t)
		var same: bool = back == t
		if ok != same or ok != VALID.has(t):
			agree = false
			detail.append("%s: validator %s, parser gives '%s'" % [t, "valid" if ok else "invalid", back])
	_check(agree, "validator and level parser agree on %d valid and %d invalid tokens (%s)" % [VALID.size(), INVALID.size(), "; ".join(detail)])
	var bank_ok := true
	var n := 0
	var bad := []
	for f in DirAccess.get_files_at("res://data/dev"):
		if not (f.begins_with("ta90_n") and f.ends_with(".json")):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/dev/" + f))
		for b in d["boards"]:
			var p: Array = V.board_problems(Array(b["puzzle"]["map"]))
			var fp_ok: bool = PuzzleDefinition.from_dict(b["puzzle"]).fingerprint() == str(b["fingerprint"])
			n += 1
			if not p.is_empty() or not fp_ok:
				bank_ok = false
				bad.append("%s %s %s" % [b["id"], p, "" if fp_ok else "fingerprint changed"])
	_check(bank_ok and n >= 62, "every EXTREME record valid with its fingerprint unchanged (%d boards) %s" % [n, bad])
	var lv := 0
	var lbad := []
	for f in DirAccess.get_files_at("res://levels"):
		if not f.ends_with(".json"):
			continue
		var j = JSON.parse_string(FileAccess.get_file_as_string("res://levels/" + f))
		if typeof(j) != TYPE_DICTIONARY or not j.has("map"):
			continue
		lv += 1
		var p: Array = V.board_problems(Array(j["map"]))
		if not p.is_empty():
			lbad.append("%s %s" % [f, p])
	_check(lbad.is_empty() and lv >= 300, "every Classic level valid (%d map levels) %s" % [lv, lbad])
	if args.has("run"):
		var r = JSON.parse_string(FileAccess.get_file_as_string(str(args["run"])))
		var inv := 0
		for b in r["qualifying"]:
			inv += int(not V.board_problems(Array(b["map"])).is_empty())
		_check(inv == 0, "%s: %d qualifying boards, %d invalid; %d generated boards refused before solving" % [args["run"], r["qualifying"].size(), inv, int(r.get("invalid_refused", -1))])
	print("XB28 VALIDATE CHECK: %s (%d checks)" % ["PASSED" if failures.is_empty() else "FAILED", passed + failures.size()])
	for f in failures:
		print("  FAIL: " + f)
	quit(0 if failures.is_empty() else 1)


## The token at r1c1 of a small board after parsing and writing back, with
## the partners its marks need (a switch for a flip target, a flip target for
## a switch, a gate for a link, a key colour for a lock).
func _round_trip(t: String) -> String:
	var row0 := [".", ".", ".", ".", "."]
	if t.contains("&A"):
		row0[3] = "B^%A"
	if t.contains("%A"):
		row0[4] = "Bv&A"
	if t.contains("+C"):
		row0[0] = "XC"
	if t.contains("#G"):
		row0[2] = "G^"
	var map := [" ".join(row0), ". " + t + " . . .", ". . . . .", ". . . . .", ". . . . ."]
	var level := LevelManager.parse_level({"name": "t", "map": map}, 0, true)
	if level == null:
		return "<refused>"
	var out = JSON.parse_string(LevelManager.to_json_text(level))
	return str(out["map"][1]).split(" ", false)[1] if out["map"].size() > 1 and str(out["map"][1]).split(" ", false).size() > 1 else "<gone>"


func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("  ok  " + what)
	else:
		failures.append(what)
