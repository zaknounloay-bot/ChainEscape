extends RefCounted
## VERY HARD GATE 0 PILOT (development only): board identity and mechanics,
## shared by tools/vh_pilot4_build.gd and tools/vh_pilot4_check.gd.

const COLORS := ["R", "B", "G", "Y", "P"]
## First campaign level of each mechanic (tester eligibility / reminders).
const FIRST_LEVEL := {"spinner_cw": 6, "lock": 13, "spinner_ccw": 31, "spinner_alt": 41, "spinner_pattern": 51,
	"switch": 101, "gate": 121, "armor": 151, "portal": 201, "sequence": 226, "crate": 251}


static func _grid(map: Array) -> Array:
	var g := []
	for row in map:
		g.append(Array(String(row).split(" ", false)))
	return g


static func _has(map: Array, ch: String) -> bool:
	for row in map:
		if String(row).contains(ch):
			return true
	return false


## Mechanics on a board (ids of FIRST_LEVEL).
static func mechanics(map: Array) -> Array:
	var out := {}
	for row in map:
		for t in String(row).split(" ", false):
			if t == ".":
				continue
			if t == "M":
				out["crate"] = true
			elif t.length() == 2 and t[0] == "O":
				out["portal"] = true
			elif t.length() == 2 and t[0] == "X":
				out["gate"] = true
			else:
				if t.contains("@~"):
					out["spinner_alt"] = true
				elif t.contains("@*"):
					out["spinner_pattern"] = true
				elif t.contains("@-"):
					out["spinner_ccw"] = true
				elif t.contains("@"):
					out["spinner_cw"] = true
				if t.contains("#"):
					out["lock"] = true
				if t.contains("%") or t.contains("&"):
					out["switch"] = true
				if t.contains("+"):
					out["gate"] = true
				if t.contains("="):
					out["armor"] = true
				if t.contains(":"):
					out["sequence"] = true
	var keys := out.keys()
	keys.sort_custom(func(a, b): return FIRST_LEVEL.get(a, 0) < FIRST_LEVEL.get(b, 0))
	return keys


## The board with rewards stripped and every name relabelled in reading
## order (colours, switch / gate / portal / twin groups), minimised over the
## four rotations and, when it is a board of the same rules, the mirror
## images (a mirror turns clockwise spinners counter-clockwise and back;
## alternating / pattern spinners have no mirror token, so such boards are
## compared by rotation only). Same key = the same puzzle to a player.
static func canonical(map: Array) -> String:
	var g := _grid(map)
	for r in g.size():
		for c in g[r].size():
			g[r][c] = _strip_reward(g[r][c])
	var forms := []
	var cur := g
	var can_mirror := not _has(map, "@~") and not _has(map, "@*")
	for k in 4:
		forms.append(_relabel(cur))
		if can_mirror:
			forms.append(_relabel(_mirror(cur)))
		cur = _rot(cur)
	forms.sort()
	return forms[0]


static func _strip_reward(t: String) -> String:
	var p := t.find("$")
	return t if p < 0 else t.substr(0, p) + t.substr(p + 2)


const ROT := {"^": ">", ">": "v", "v": "<", "<": "^"}
const MIR := {"^": "^", "v": "v", "<": ">", ">": "<"}


static func _rot(g: Array) -> Array:
	var rows := g.size()
	var cols: int = g[0].size()
	var out := []
	for c in cols:
		var row := []
		for r in range(rows - 1, -1, -1):
			row.append(_map_dirs(g[r][c], ROT, false))
		out.append(row)
	return out


static func _mirror(g: Array) -> Array:
	var out := []
	for row in g:
		var o := []
		for c in range(row.size() - 1, -1, -1):
			o.append(_map_dirs(row[c], MIR, true))
		out.append(o)
	return out


static func _map_dirs(t: String, dmap: Dictionary, mirror: bool) -> String:
	if t == "." or t.length() < 2 or not (t[0] in COLORS):
		return t
	var out: String = t.substr(0, 1) + dmap[t.substr(1, 1)]
	var rest := t.substr(2)
	var q := rest.find(":")
	if q >= 0:
		rest = rest.substr(0, q + 1) + dmap[rest.substr(q + 1, 1)] + rest.substr(q + 2)
	if mirror and rest.begins_with("@"):
		if rest.begins_with("@-"):
			rest = "@" + rest.substr(2)
		elif not (rest.length() > 1 and rest[1] in ["~", "*"]):
			rest = "@-" + rest.substr(1)
	return out + rest


static func _relabel(g: Array) -> String:
	var colour := {}
	var groups := {"sw": {}, "gate": {}, "portal": {}, "twin": {}}
	var rows := []
	for row in g:
		var o := []
		for t in row:
			o.append(_relabel_token(t, colour, groups))
		rows.append(" ".join(o))
	return "%dx%d|" % [g[0].size(), g.size()] + "/".join(rows)


static func _relabel_token(t: String, colour: Dictionary, groups: Dictionary) -> String:
	if t == "." or t == "M":
		return t
	if t.length() == 2 and t[0] == "O":
		return "O" + _name(groups["portal"], t[1], "ABCD")
	if t.length() == 2 and t[0] == "X":
		return "X" + _name(groups["gate"], t[1], "CD")
	var out: String = _name(colour, t[0], "RBGYP") + t[1]
	var i := 2
	while i < t.length():
		var ch := t[i]
		if ch == "#":
			out += "#" + _name(colour, t[i + 1], "RBGYP")
			i += 2
		elif ch in ["%", "&"]:
			out += ch + _name(groups["sw"], t[i + 1], "AB")
			i += 2
		elif ch == "+":
			out += "+" + _name(groups["gate"], t[i + 1], "CD")
			i += 2
		elif ch == "!":
			out += "!" + _name(groups["twin"], t[i + 1], "TUVW")
			i += 2
		else:
			out += ch
			i += 1
	return out


static func _name(table: Dictionary, key: String, letters: String) -> String:
	if not table.has(key):
		table[key] = letters[mini(table.size(), letters.length() - 1)]
	return table[key]
