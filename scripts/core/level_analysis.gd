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
	m["portal_moves"] = 0
	m["portal_cells_entered"] = 0
	m["portal_groups_used"] = 0
	if not m["solvable"]:
		return m
	if not level.portals.is_empty():
		_portal_use(level, m)
	if not with_impacts:
		return m
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
		m["portal_impact"] = ESSENTIAL if not v["solvable"] else snappedf(m["difficulty"] - LevelGenerator.difficulty(v), 0.1)
	return m


static func _strip_switch(b: BlockData) -> void:
	b.switch_group = ""
	b.flip_link = ""


static func _strip_gate_link(b: BlockData) -> void:
	b.gate_link = ""


static func _strip_armor(b: BlockData) -> void:
	b.armored = false


## How the solver's solution uses the portals: moves whose lane goes
## through one, distinct portal cells entered, distinct pairs used.
static func _portal_use(level: LevelData, m: Dictionary) -> void:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	model.set_portals(level.portals)
	var cells := {}
	var groups := {}
	for id in m["solution"]:
		var via: Array = model.lane(id)["via"]
		if not via.is_empty():
			m["portal_moves"] += 1
			for hop in via:
				cells[hop[0]] = true
				groups[level.portals[hop[0]]] = true
		if model.move_state(id) == "ram":
			model.ram(id)
		else:
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
	if structural:
		return snappedf(LevelGenerator.structural_difficulty(full) - LevelGenerator.structural_difficulty(v), 0.1)
	return snappedf(full["difficulty"] - LevelGenerator.difficulty(v), 0.1)
