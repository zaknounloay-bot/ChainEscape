extends RefCounted
## MAGNET per-magnet rule (campaign verifier, campaign build, pull audit):
## every magnet must be able to make a meaningful pull on at least one
## winning line - from a winnable state, the magnet escapes, pulls a block,
## and the board stays winnable. It need not pull in every solution
## (optional but functional magnets are fine).
##
## Decided on the COMPLETE reachable state graph with the game's own
## BoardModel rules (Hammer, Undo and hints excluded), so a pull from a
## distance or after a spinner turned the magnet counts.

const Self := preload("res://tools/magnet_pull_rule.gd")


## Magnets that can never pull on a winning line: [{"id", "cell"}].
static func inert(level: LevelData) -> Array:
	var out := []
	var g := graph(level)
	for id in g["mags"]:
		if g["mags"][id]["winning_pulls"] == 0:
			out.append({"id": id, "cell": Self.cell_of(level, id)})
	return out


## Complete reachable graph. keys: sorted state keys; edges: sorted
## "from>move>to"; win: sorted winnable keys; mags: per magnet id - escapes
## (reachable states where it escapes), pulls (of those, with a pull),
## winning_pulls (pulls from a winnable state into a winnable state) and
## dirs (every direction it faces).
static func graph(level: LevelData) -> Dictionary:
	var m := model(level)
	var mags := {}
	for b in level.blocks:
		if b.magnet:
			mags[b.id] = {"escapes": 0, "pulls": 0, "winning_pulls": 0, "dirs": {}}
	var start := key(m)
	var snaps := {start: m.snapshot()}
	var kids := {}  # key -> [[move, ram, child_key, pulled]]
	var queue := [start]
	while not queue.is_empty():
		var k: String = queue.pop_back()
		m.restore(snaps[k])
		for id in mags:
			if m.blocks.has(id):
				mags[id]["dirs"][m.blocks[id].direction] = true
		var out := []
		for id in m.playable_ids():
			m.restore(snaps[k])
			var ram: bool = m.move_state(id) == "ram"
			var pulled := false
			if ram:
				m.ram(id)
			elif m.twin_partner(id) >= 0:
				m.remove_pair(id)
			else:
				if mags.has(id):
					mags[id]["escapes"] += 1
					pulled = not m.pull_target(id).is_empty()
					if pulled:
						mags[id]["pulls"] += 1
				m.remove(id)
			var ck := key(m)
			if not snaps.has(ck):
				snaps[ck] = m.snapshot()
				queue.append(ck)
			out.append([id, ram, ck, pulled])
		kids[k] = out
	# Winnable: the empty board, and every state with a winnable child.
	var win := {}
	var changed := true
	while changed:
		changed = false
		for k in kids:
			if win.has(k):
				continue
			var ok: bool = (snaps[k] as Array).is_empty()
			for c in kids[k]:
				if win.has(c[2]):
					ok = true
			if ok:
				win[k] = true
				changed = true
	var edges := []
	for k in kids:
		for c in kids[k]:
			edges.append("%s>%d%s>%s" % [k, c[0], "r" if c[1] else "", c[2]])
			if c[3] and win.has(k) and win.has(c[2]):
				mags[c[0]]["winning_pulls"] += 1
	edges.sort()
	var keys := kids.keys()
	keys.sort()
	var wk := win.keys()
	wk.sort()
	return {"keys": keys, "edges": edges, "win": wk, "win_count": wk.size(), "mags": mags}


static func key(m: BoardModel) -> String:
	var parts := []
	for id in m.blocks:
		var b: BlockData = m.blocks[id]
		parts.append("%d:%d,%d:%d:%d:%d" % [id, b.cell.x, b.cell.y, b.direction, int(b.armored), b.seq_stage])
	parts.sort()
	return "|".join(parts)


static func model(level: LevelData) -> BoardModel:
	var m := BoardModel.new()
	m.setup(level.rows, level.columns, level.blocks)  # magnets never share a board with portals
	return m


static func cell_of(level: LevelData, id: int) -> Vector2i:
	for b in level.blocks:
		if b.id == id:
			return b.cell
	return Vector2i(-1, -1)
