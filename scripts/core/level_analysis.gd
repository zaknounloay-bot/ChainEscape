class_name LevelAnalysis
extends RefCounted
## Full difficulty/quality report for one level (used by the verifier, the
## generator and tests).
##
## On top of Solver.analyze() it measures how much each advanced mechanic
## actually contributes, by re-analysing the level with that mechanic
## switched off:
##   spinner_impact / lock_impact / mystery_impact and (v0.6)
##   switch_impact / gate_impact / armor_impact =
##       difficulty(level) - difficulty(level without the mechanic)
##   (ESSENTIAL if the level becomes unsolvable without it).
## A mechanic that adds no difficulty/decisions is "decoration" and is
## rejected on campaign levels. Mystery levels also get a fairness check.

const ESSENTIAL := 99.0


static func analyze(level: LevelData, with_impacts: bool = true) -> Dictionary:
	var m := _base(level.rows, level.columns, level.blocks, level.portals)
	m["name"] = level.name
	m["mystery"] = level.mystery
	m["solution_length"] = m["solution"].size()
	# v0.8 SEQUENCE / MOVABLE (226+ / 251+): how many there are and how the
	# solver's solution uses them (all 0 on every earlier level).
	m["sequence_blocks"] = level.blocks.filter(func(b): return b.seq_stage != 0).size()
	m["crates"] = level.blocks.filter(func(b): return b.is_crate()).size()
	m["advances"] = 0
	m["pushes"] = 0
	m["crate_portal_pushes"] = 0
	m["sequence_impact"] = 0.0
	m["movable_impact"] = 0.0
	m["push_essential"] = false
	m["portal_moves"] = 0
	m["portal_cells_entered"] = 0
	m["portal_groups_used"] = 0
	if m["solvable"] and (not level.portals.is_empty() or m["sequence_blocks"] + m["crates"] > 0):
		_replay_use(level, m)
	m["difficulty"] = LevelGenerator.difficulty(m) if m["solvable"] else 0.0
	m["spinner_impact"] = 0.0
	m["lock_impact"] = 0.0
	m["mystery_impact"] = 0.0
	m["mystery_fair"] = true
	m["switch_impact"] = 0.0
	m["gate_impact"] = 0.0
	m["armor_impact"] = 0.0
	# PORTAL (201+): pairs on the board and how much they add (the level
	# with every portal cell turned into an empty cell).
	m["portal_pairs"] = level.portals.size() / 2
	m["portal_impact"] = 0.0
	# MAGNET (76-99): magnets on the board, pulls in the solver's solution
	# (replayed through BoardModel) and what the magnets add (structural;
	# ESSENTIAL if the level can't be won with every magnet a plain arrow).
	m["magnets"] = level.blocks.filter(func(b): return b.magnet).size()
	m["pulls"] = 0
	m["magnet_impact"] = 0.0
	if m["solvable"] and m["magnets"] > 0:
		var r := BoardModel.new()
		r.setup(level.rows, level.columns, level.blocks)
		for mv in m["solution"]:
			var id: int = mv & Solver.ID_MASK
			if r.blocks.has(id) and r.move_state(id) == "ok":
				r.remove(id)
				if not r.last_pull.is_empty():
					m["pulls"] += 1
	if not m["solvable"] or not with_impacts:
		return m
	if m["magnets"] > 0:
		m["magnet_impact"] = _impact(level, m, func(b): b.magnet = false, false, true)
	# v0.6 mechanics are measured STRUCTURALLY (depth, decisions, traps,
	# start moves, rams) - their own count terms don't count, so a switch,
	# gate or shell that changes nothing about how the level is solved is
	# reported as decoration.
	if m["switches"] > 0:
		m["switch_impact"] = _impact(level, m, _strip_switch, false, true)
	if m["gates"] > 0:
		m["gate_impact"] = _impact(level, m, _strip_gate_link, true, true)
	if m["armored"] > 0:
		m["armor_impact"] = _impact(level, m, _strip_armor, false, true)
	if m["spinners"] > 0:
		m["spinner_impact"] = _impact(level, m, _strip_spinner)
	if m["locks"] > 0:
		m["lock_impact"] = _impact(level, m, func(b): b.lock_color = "")
	if m["hidden"] > 0:
		m["mystery_impact"] = _impact(level, m, func(b): b.hidden = false)
		var model := BoardModel.new()
		model.setup(level.rows, level.columns, level.blocks)
		model.set_portals(level.portals)
		var fairness := Solver.from_model(model).mystery_fairness()
		m["mystery_fair"] = fairness["fair"]
		m["mystery_reason"] = fairness["reason"]
	if not level.portals.is_empty():
		var v := _base(level.rows, level.columns, level.blocks)
		if v["solvable"] and m["sequence_blocks"] + m["crates"] > 0:
			_fill_era3(level.rows, level.columns, level.blocks, {}, v)
		m["portal_impact"] = ESSENTIAL if not v["solvable"] else snappedf(m["difficulty"] - LevelGenerator.difficulty(v), 0.1)
	# v0.8: SEQUENCE - the same level with every Sequence block a plain arrow
	# pointing its NEXT way (the lab's matched control); MOVABLE - the level
	# without its Movable blocks, and whether it can be won at all without
	# pushing (push_essential).
	if m["sequence_blocks"] > 0:
		m["sequence_impact"] = _impact(level, m, _strip_sequence, false, true)
	if m["crates"] > 0:
		var kept := level.blocks.filter(func(b): return not b.is_crate()).map(func(b): return b.duplicate_data())
		var v := _base(level.rows, level.columns, kept, level.portals)
		if v["solvable"]:
			_fill_era3(level.rows, level.columns, kept, level.portals, v)
		m["movable_impact"] = ESSENTIAL if not v["solvable"] else snappedf(LevelGenerator.structural_difficulty(m) - LevelGenerator.structural_difficulty(v), 0.1)
		var model := BoardModel.new()
		model.setup(level.rows, level.columns, level.blocks)
		model.set_portals(level.portals)
		var no_push := Solver.from_model(model)
		no_push.allow_push = false
		m["push_essential"] = not no_push.is_solvable() and not no_push.aborted
	return m


## v0.8: a comparison board's own Sequence / Movable counts (so an impact
## measures only the mechanic that was taken away).
static func _fill_era3(rows: int, columns: int, blocks: Array, portals: Dictionary, v: Dictionary) -> void:
	var copy := LevelData.new()
	copy.rows = rows
	copy.columns = columns
	copy.blocks = blocks
	copy.portals = portals
	v["sequence_blocks"] = blocks.filter(func(b): return b.seq_stage != 0).size()
	v["crates"] = blocks.filter(func(b): return b.is_crate()).size()
	for k in ["advances", "pushes", "crate_portal_pushes", "portal_moves", "portal_cells_entered", "portal_groups_used"]:
		v[k] = 0
	_replay_use(copy, v)


static func _strip_sequence(b: BlockData) -> void:
	if b.seq_stage == 1:
		b.direction = b.seq_next
	b.seq_stage = 0
	b.seq_next = -1


static func _strip_switch(b: BlockData) -> void:
	b.switch_group = ""
	b.flip_link = ""


static func _strip_gate_link(b: BlockData) -> void:
	b.gate_link = ""


static func _strip_armor(b: BlockData) -> void:
	b.armored = false


## Replays the solver's solution on the real rules and counts how it uses
## the Third Era mechanics: moves whose lane goes through a portal,
## distinct portal cells entered and pairs used (201+); Sequence first
## stages (advances) and pushes, and pushes that carry the Movable block
## through a portal (v0.8).
static func _replay_use(level: LevelData, m: Dictionary) -> void:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	model.set_portals(level.portals)
	var cells := {}
	var groups := {}
	for id in m["solution"]:
		var via: Array = model.lane(id)["via"] if not level.portals.is_empty() else []
		if not via.is_empty():
			m["portal_moves"] += 1
			for hop in via:
				cells[hop[0]] = true
				groups[level.portals[hop[0]]] = true
		match model.move_state(id):
			"ram":
				model.ram(id)
			"advance":
				m["advances"] += 1
				model.advance(id)
			"push":
				m["pushes"] += 1
				var info := model.push(id)
				if info.get("advanced", false):
					m["advances"] += 1
				if not info.get("via", []).is_empty():
					m["crate_portal_pushes"] += 1
					for hop in info["via"]:
						cells[hop[0]] = true
						groups[level.portals[hop[0]]] = true
			_:
				model.remove(id)
	m["portal_cells_entered"] = cells.size()
	m["portal_groups_used"] = groups.size()


static func _strip_spinner(b: BlockData) -> void:
	if b.is_spinner():
		b.kind = BlockData.Kind.NORMAL


static func _base(rows: int, columns: int, blocks: Array, portals: Dictionary = {}) -> Dictionary:
	var model := BoardModel.new()
	model.setup(rows, columns, blocks)
	model.set_portals(portals)
	var s := Solver.from_model(model)
	var m := s.analyze()
	m["aborted"] = s.aborted or s.any_aborted
	return m


static func _impact(level: LevelData, full: Dictionary, strip: Callable, drop_gates: bool = false, structural: bool = false) -> float:
	var blocks := []
	for b in level.blocks:
		if drop_gates and b.is_gate():
			continue
		var c: BlockData = b.duplicate_data()
		strip.call(c)
		blocks.append(c)
	var v := _base(level.rows, level.columns, blocks, level.portals)
	if not v["solvable"]:
		return ESSENTIAL
	if full.get("sequence_blocks", 0) + full.get("crates", 0) > 0:
		_fill_era3(level.rows, level.columns, blocks, level.portals, v)
	if structural:
		return snappedf(LevelGenerator.structural_difficulty(full) - LevelGenerator.structural_difficulty(v), 0.1)
	return snappedf(full["difficulty"] - LevelGenerator.difficulty(v), 0.1)
