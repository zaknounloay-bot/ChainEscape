class_name LevelData
extends RefCounted
## One parsed level, independent of the file format it came from.

var number: int = 0
var name: String = ""
## Optional contextual hint (only level 1 uses one today).
var hint: String = ""
## Optional one-time text shown after the first blocked tap.
var blocked_hint: String = ""
var rows: int = 0
var columns: int = 0
var blocks: Array = []  # Array of BlockData
## Show the animated finger with `hint` (false = text only).
var hint_finger: bool = true
## Hearts for this level; -1 = use the default rule (3 from level 6 on).
var hearts: int = -1
