extends SceneTree
## Challenge a Friend: writes data/classic_board_keys.json - the board key
## (FriendGenerator.board_key) of each of the campaign's 200 levels, so a
## generated challenge can never be one of them without loading 200 level
## files at run time. Run after changing any level file:
##   godot --headless --path . --script res://tools/classic_board_keys.gd
## (tools/run_tests.gd recomputes the keys and fails if this file is stale.)


static func compute() -> Array:
	var keys := []
	var n := 1
	while FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
		var json = JSON.parse_string(FileAccess.get_file_as_string(LevelManager.LEVEL_PATH % n))
		var level := LevelManager.parse_level(json, n)
		keys.append(FriendGenerator.board_key(PuzzleDefinition.from_level(level)))
		n += 1
	return keys


func _init() -> void:
	var keys := compute()
	var f := FileAccess.open(FriendGenerator.CLASSIC_KEYS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"levels": keys.size(), "keys": keys}, "\t") + "\n")
	f.close()
	print("classic board keys: %d levels written to %s" % [keys.size(), FriendGenerator.CLASSIC_KEYS_PATH])
	quit()
