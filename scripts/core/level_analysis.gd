class_name LevelAnalysis
extends RefCounted
## Full difficulty/quality report for one level (used by the verifier, the
## generator and tests).
##
## On top of Solver.analyze() it measures how much each advanced mechanic
## actually contributes, by re-analysing the level with that mechanic
## switched off:
##   spinner_impact / lock_impact / mystery_impact =
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
	if not m["solvable"] or not with_impacts:
		return m
	if m["spinners"] > 0:
		m["spinner_impact"] = _impact(level, m, func(b): b.kind = BlockData.Kind.NORMAL)
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


static func _base(rows: int, columns: int, blocks: Array) -> Dictionary:
	var model := BoardModel.new()
	model.setup(rows, columns, blocks)
	var s := Solver.from_model(model)
	var m := s.analyze()
	m["aborted"] = s.aborted or s.any_aborted
	return m


static func _impact(level: LevelData, full: Dictionary, strip: Callable) -> float:
	var blocks := []
	for b in level.blocks:
		var c: BlockData = b.duplicate_data()
		strip.call(c)
		blocks.append(c)
	var v := _base(level.rows, level.columns, blocks)
	if not v["solvable"]:
		return ESSENTIAL
	return snappedf(full["difficulty"] - LevelGenerator.difficulty(v), 0.1)
