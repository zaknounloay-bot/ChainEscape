extends SceneTree
## Places the campaign's Silver / Gold reward blocks from the Chapter plan.
##
##   godot --headless --path . --script res://tools/place_reward_blocks.gd [-- --write]
##
## For every Chapter, LevelGenerator.chapter_plan() says how many of its 10
## levels carry a Silver / Gold block; reward_slots() spreads them evenly
## and assign_reward_blocks() picks the block (Gold: cleared late in the
## solver's solution; Silver: second half; never hidden, never the last
## block). The Master Level gets 2 Gold + 1 Silver. Deterministic and
## repeatable (existing marks are cleared first). Rewards never change the
## rules, so solvability is untouched - the verifier re-checks it anyway.
## Without --write it only prints the plan.

const MASTER_REWARDS := {"silver": 1, "gold": 2}


func _initialize() -> void:
	var write := "--write" in OS.get_cmdline_user_args()
	var lm := LevelManager.new()
	lm._ready()
	var totals := {"silver": 0, "gold": 0}
	for c in range(1, Chapters.chapter_count(lm.level_count) + 1):
		var plan := LevelGenerator.chapter_plan(c)
		var silver_slots := LevelGenerator.reward_slots(c, plan["silver_levels"], 0.5)
		var gold_slots := LevelGenerator.reward_slots(c, plan["gold_levels"], 0.15)
		var line := PackedStringArray()
		var rg := Chapters.chapter_range(c)
		for n in range(rg.x, mini(rg.y, lm.level_count) + 1):
			var sv := silver_slots.count(n)
			var gd := gold_slots.count(n)
			if Chapters.is_master(n):
				sv = MASTER_REWARDS["silver"]
				gd = MASTER_REWARDS["gold"]
			var level := lm.load_level(n)
			var gen := LevelGenerator.new(n)
			gen.assign_reward_blocks(level, sv, gd)
			var got := {"silver": 0, "gold": 0}
			for b in level.blocks:
				if b.is_reward():
					got[b.rarity_name()] += 1
			totals["silver"] += got["silver"]
			totals["gold"] += got["gold"]
			if got["silver"] + got["gold"] > 0:
				line.append("%d:%s" % [n, "S".repeat(got["silver"]) + "G".repeat(got["gold"])])
			if write:
				_write(n, level)
		print("Chapter %2d  %-16s %s" % [c, Chapters.chapter_name(c), " ".join(line) if not line.is_empty() else "-"])
	print("Total: %d Silver, %d Gold (%d + %d coins available)" % [totals["silver"], totals["gold"],
		totals["silver"] * Economy.reward_block_coins(BlockData.Rarity.SILVER), totals["gold"] * Economy.reward_block_coins(BlockData.Rarity.GOLD)])
	lm.free()
	quit()


## Rewrites only the "map" of the level file, and only if a cell changed
## (older files keep their own column padding).
func _write(n: int, level: LevelData) -> void:
	var path := LevelManager.LEVEL_PATH % n
	var json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var mapped: Dictionary = JSON.parse_string(LevelManager.to_json_text(level))
	if _tokens(json["map"]) == _tokens(mapped["map"]):
		return
	json["map"] = mapped["map"]
	var text := LevelManager.format_level_json(json)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func _tokens(map: Array) -> Array:
	return map.map(func(row): return Array(String(row).split(" ", false)))
