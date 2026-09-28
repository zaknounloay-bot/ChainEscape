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
	var m := _base(level.rows, level.columns, level.blocks)
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
	if not m["solvable"] or not with_impacts:
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
		var fairness := Solver.from_model(model).mystery_fairness()
		m["mystery_fair"] = fairness["fair"]
		m["mystery_reason"] = fairness["reason"]
	return m


static func _strip_switch(b: BlockData) -> void:
	b.switch_group = ""
	b.flip_link = ""


static func _strip_gate_link(b: BlockData) -> void:
	b.gate_link = ""


static func _strip_armor(b: BlockData) -> void:
	b.armored = false


static func _strip_spinner(b: BlockData) -> void:
	if b.is_spinner():
		b.kind = BlockData.Kind.NORMAL


static func _base(rows: int, columns: int, blocks: Array) -> Dictionary:
	var model := BoardModel.new()
	model.setup(rows, columns, blocks)
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
	var v := _base(level.rows, level.columns, blocks)
	if not v["solvable"]:
		return ESSENTIAL
	if structural:
		return snappedf(LevelGenerator.structural_difficulty(full) - LevelGenerator.structural_difficulty(v), 0.1)
	return snappedf(full["difficulty"] - LevelGenerator.difficulty(v), 0.1)
