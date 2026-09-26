extends SceneTree
## Static level checker using the real BoardModel rules (no rendering).
##
##   godot --headless --path . --script res://tools/verify_levels.gd
##
## For every level it reports size, block count, how many blocks are free at
## the start, and the "waves" (how many blocks become free in each round when
## everything free is cleared at once). Fails if any level can deadlock.
##
## Note: escaping only ever frees space, so a level solvable in one order is
## solvable in every order; clearing all free blocks per round is exhaustive.

func _initialize() -> void:
	var ok := true
	var n := 1
	while FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
		var json = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n))
		var level := LevelManager.parse_level(json, n)
		var model := BoardModel.new()
		model.setup(level.rows, level.columns, level.blocks)
		var waves: Array[int] = []
		while not model.is_empty():
			var free := model.free_block_ids()
			if free.is_empty():
				break
			waves.append(free.size())
			for id in free:
				model.remove(id)
		var solvable := model.is_empty()
		ok = ok and solvable and level.blocks.size() > 0
		print("Level %2d  %-20s %dx%d  blocks=%2d  start_free=%d  waves=%2d %s  %s" % [
			n, level.name, level.columns, level.rows, level.blocks.size(),
			waves[0] if waves.size() > 0 else 0, waves.size(), str(waves),
			"OK" if solvable else "DEADLOCK (%d stuck)" % model.block_count()])
		n += 1
	print("ALL LEVELS SOLVABLE" if ok else "LEVEL CHECK FAILED")
	quit(0 if ok else 1)
