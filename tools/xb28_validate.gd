extends RefCounted
## PHASE 28 (development only): the engine's modifier rules as a validator the
## generator applies BEFORE any solving (docs/extreme90_phase28.md, section D).
## The level parser (scripts/core/level_manager.gd) refuses or silently repairs
## these tokens with an error, so a generated board carrying one is not the
## board that would be played. Mirrors, rule for rule:
##   token: switch / flip target / armor on a spinner; a hidden spinner; a
##   hidden lock; a lock of its own colour; switch + flip target; armor +
##   lock / switch; a Sequence block with any other mark; a magnet with a
##   spinner / lock / switch / link / armor / Sequence / twin role (a magnet
##   MAY be a flip target); a campaign twin that is not a plain arrow;
##   board: a magnet on a board with portals, crates or hidden blocks; a flip
##   target / link whose switch / gate is missing; a switch with nothing to
##   flip; a gate with no link.
## Never used by the game. tools/xb28_validate_check.gd tests it.

const _RE := "^([RBGYP])([\\^v<>])(@[-~*]?)?(\\?)?(#[RBGYP])?(\\$[SGD])?(%[ABCD])?(&[ABCD])?(\\+[ABCD])?(=)?(:[\\^v<>])?(![TUVW])?(\\*)?$"
static var _re: RegEx


## Why a block token breaks an engine rule ([] = valid). Non-block tokens
## ("." , "M", "XC", "OA") are always valid here.
static func token_problems(t: String) -> Array:
	if t == "." or t == "M" or (t.length() == 2 and (t[0] == "X" or t[0] == "O")):
		return []
	if _re == null:
		_re = RegEx.create_from_string(_RE)
	var m := _re.search(t)
	if m == null:
		return ["unparsable token " + t]
	var spinner := m.get_string(3) != ""
	var hidden := m.get_string(4) != ""
	var lock := m.get_string(5)
	var sw := m.get_string(7) != ""
	var flip := m.get_string(8) != ""
	var armor := m.get_string(10) != ""
	var seq := m.get_string(11) != ""
	var twin := m.get_string(12) != ""
	var magnet := m.get_string(13) != ""
	var out := []
	if spinner and (sw or flip or armor):
		out.append("switch / flip / armor on a spinner")
	if spinner and hidden:
		out.append("hidden spinner")
	if hidden and lock != "":
		out.append("hidden and locked")
	if lock != "" and lock.substr(1) == m.get_string(1):
		out.append("locked by its own colour")
	if sw and flip:
		out.append("switch and flip target")
	if armor and (lock != "" or sw):
		out.append("armored and locked / switch")
	var reward := m.get_string(6) != ""
	var link := m.get_string(9) != ""
	if seq and (spinner or hidden or lock != "" or reward or sw or flip or link or armor or twin or magnet):
		out.append("Sequence with another mark")
	# level_manager._validate_magnets: no spinner, lock, switch, link, armor,
	# Sequence or twin role (a flip target, a reward or a hidden arrow may be
	# a magnet; a hidden block forbids magnets board-wide - board_problems).
	if magnet and (spinner or lock != "" or sw or link or armor or seq or twin):
		out.append("magnet with a spinner / lock / switch / link / armor / Sequence / twin role")
	# level_manager._validate_twins (campaign only): a flip target or a link may be a twin.
	if twin and (spinner or hidden or lock != "" or sw or armor or reward or seq):
		out.append("twin that is not a plain arrow")
	return out


## Every rule above on a whole map (rows of space-separated tokens).
static func board_problems(map: Array) -> Array:
	var out := []
	var switches := {}
	var flips := {}
	var gates := {}
	var links := {}
	var magnets := false
	var forbid_magnet := false
	for r in map.size():
		var row := str(map[r]).split(" ", false)
		for c in row.size():
			var t := row[c]
			for p in token_problems(t):
				out.append("r%dc%d %s: %s" % [r, c, t, p])
			if t == "M" or t.begins_with("O") or t.contains("?"):
				forbid_magnet = true
			if t.begins_with("X"):
				gates[t.substr(1, 1)] = true
				continue
			var i := t.find("%")
			if i >= 0:
				switches[t.substr(i + 1, 1)] = true
			i = t.find("&")
			if i >= 0:
				flips[t.substr(i + 1, 1)] = true
			i = t.find("+")
			if i >= 0:
				links[t.substr(i + 1, 1)] = true
			if t.length() >= 3 and t.ends_with("*") and not t.contains("@"):
				magnets = true
	if magnets and forbid_magnet:
		out.append("magnet on a board with portals, crates or hidden blocks")
	for g in flips:
		if not switches.has(g):
			out.append("flip target of a missing switch " + g)
	for g in switches:
		if not flips.has(g):
			out.append("switch %s has nothing to flip" % g)
	for g in links:
		if not gates.has(g):
			out.append("link of a missing gate " + g)
	for g in gates:
		if not links.has(g):
			out.append("gate %s has no links" % g)
	return out


## The marks a generated piece with this colour + arrow token may still take
## (the generator's suffixes, filtered by the token rules).
static func allowed(col: String, arrow_token: String, mark: String) -> bool:
	return token_problems(col + arrow_token + mark).is_empty()
