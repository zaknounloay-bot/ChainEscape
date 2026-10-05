extends SceneTree
## v0.8 Third Era, levels 226-300: the SEQUENCE arc (226-250), the MOVABLE
## arc (251-275) and the INTEGRATION arc (276-300). Writes
## res://levels/level_N.json.
##
##   godot --headless --path . --script res://tools/generate_era3.gd -- --from=226 --to=230 [--seed=1] [--tries=40] [--climb=300] [--enough=3] [--stats] [--write]
##
## Same method as tools/generate_portal_arc.gd (which built 201-225 and is
## left untouched): every slot has a SPEC - board size, block count, which
## mechanics (at most the arc's own + two others; Integration at most four
## families), a difficulty band and the level's IDEA as solver-checkable
## needs (e.g. "seq_spinner": a first stage turns a spinner in the
## solution; "push_trap": a push along the way that loses - "where will it
## be later"; "seq_push": a first-stage Sequence block pushes the Movable
## block). Boards are found by hill climbing from random boards; a board is
## accepted only if it meets every need, sits in its band, passes every
## campaign rule of tools/verify_levels.gd (the same functions), the armor
## audit and the similarity rule, and - for the milestones 250 / 275 / 300 -
## beats every level it must beat by a margin. The board nearest the band's
## centre wins. Then name, lesson text and Silver / Gold (REWARDS).
## Without --write nothing is saved (dry run). Levels 1-225 are never
## touched (slots outside 226-300 are refused).

const Verify := preload("res://tools/verify_levels.gd")

const FROM := 226
const TO := 300

## size = Vector2i(columns, rows). blocks = arrow blocks (Sequence blocks
## included, Movable blocks not). seq / crates / spin / pairs = counts.
## lesson: the lesson shape (verify_levels ARCS lists the lessons).
const SPECS := {
	# --- SEQUENCE arc: Learn ------------------------------------------------
	226: {"name": "First Sequence", "size": Vector2i(5, 5), "blocks": [4, 6], "seq": [1, 1], "diff": [5.0, 9.0], "need": ["ad1"],
		"hint": "New: SEQUENCE. Tap once to turn it, tap again to escape."},
	227: {"name": "Next Arrow", "size": Vector2i(5, 5), "blocks": [5, 7], "seq": [2, 2], "diff": [6.0, 11.0], "need": ["ad2"],
		"hint": "The small arrow shows where it goes next."},
	228: {"name": "Turn and Through", "size": Vector2i(5, 6), "blocks": [6, 8], "seq": [1, 2], "pairs": 1, "diff": [8.0, 13.0], "need": ["seq_portal"],
		"hint": "A Sequence lane can run through a portal too."},
	229: {"name": "Spin Cycle", "size": Vector2i(6, 6), "blocks": [9, 12], "seq": [1, 2], "spin": [1, 2], "diff": [19.0, 25.0], "need": ["seq_spinner"],
		"hint": "Its first tap turns the spinners next to it."},
	230: {"name": "Double Door", "size": Vector2i(6, 6), "blocks": [11, 13], "seq": [2, 2], "spin": [1, 2], "pairs": 1, "diff": [24.0, 30.0], "need": ["seq_portal", "ad2"]},
	# --- SEQUENCE arc: Apply / interact --------------------------------------
	231: {"name": "Wait For It", "size": Vector2i(6, 6), "blocks": [12, 14], "seq": [2, 2], "spin": [2, 3], "diff": [33.0, 38.0], "need": ["seq_trap"],
		"hint": "Too early can be too bad: choose WHEN to use the first tap."},
	232: {"name": "Unseen Turn", "size": Vector2i(6, 6), "blocks": [14, 17], "seq": [1, 2], "spin": [2, 3], "hidden": [1, 2], "diff": [35.0, 40.0], "need": ["seq_hidden"]},
	233: {"name": "Key Rhythm", "size": Vector2i(6, 6), "blocks": [13, 15], "seq": [1, 2], "spin": [1, 2], "lock": true, "diff": [37.0, 42.0], "need": ["seq_lock"]},
	234: {"name": "Crack First", "size": Vector2i(6, 7), "blocks": [15, 18], "seq": [1, 2], "spin": [2, 3], "armor": true, "diff": [38.0, 43.0], "need": ["seq_armor"]},
	235: {"name": "Easy Rhythm", "size": Vector2i(6, 6), "blocks": [11, 13], "seq": [2, 3], "spin": [1, 2], "diff": [29.0, 33.0], "need": ["ad2"], "breather": true},
	236: {"name": "Counter Step", "size": Vector2i(6, 6), "blocks": [13, 15], "seq": [2, 2], "spin": [2, 3], "rules": ["@-", "@~"], "diff": [40.0, 45.0], "need": ["seq_spinner"]},
	237: {"name": "Portal Rhythm", "size": Vector2i(6, 7), "blocks": [15, 18], "seq": [2, 2], "spin": [2, 3], "pairs": 1, "diff": [41.0, 46.0], "need": ["seq_portal", "seq_trap"]},
	238: {"name": "Three Beats", "size": Vector2i(6, 7), "blocks": [14, 16], "seq": [3, 3], "spin": [2, 3], "diff": [42.0, 47.0], "need": ["ad3"]},
	239: {"name": "Late Turn", "size": Vector2i(6, 7), "blocks": [16, 18], "seq": [2, 2], "spin": [3, 4], "pairs": 1, "diff": [44.0, 49.0], "need": ["seq_trap", "remote"]},
	240: {"name": "Twin Rhythm", "size": Vector2i(6, 7), "blocks": [16, 18], "seq": [2, 2], "spin": [2, 3], "pairs": 2, "diff": [45.0, 50.0], "need": ["two_pairs", "seq_portal"]},
	# --- SEQUENCE arc: Master + Portal ------------------------------------------
	241: {"name": "Echo", "size": Vector2i(6, 7), "blocks": [17, 19], "seq": [2, 3], "spin": [3, 5], "diff": [47.0, 52.0], "need": ["seq_spinner", "seq_trap"]},
	242: {"name": "Relay", "size": Vector2i(6, 7), "blocks": [17, 19], "seq": [2, 3], "spin": [3, 4], "pairs": 1, "diff": [48.0, 53.0], "need": ["seq_portal", "pm3"]},
	243: {"name": "Shell Game", "size": Vector2i(6, 7), "blocks": [17, 19], "seq": [2, 2], "armor": true, "spin": [3, 4], "diff": [49.0, 54.0], "need": ["seq_armor"]},
	244: {"name": "Smooth Run", "size": Vector2i(6, 6), "blocks": [13, 15], "seq": [2, 3], "spin": [1, 2], "pairs": 1, "diff": [39.0, 43.0], "need": ["seq_portal"], "breather": true},
	245: {"name": "Double Take", "size": Vector2i(6, 7), "blocks": [17, 19], "seq": [3, 3], "spin": [3, 4], "rules": ["@", "@~"], "diff": [51.0, 56.0], "need": ["seq_spinner", "ad3"]},
	246: {"name": "Locked Step", "size": Vector2i(7, 7), "blocks": [17, 20], "seq": [2, 2], "lock": true, "spin": [3, 4], "diff": [52.0, 57.0], "need": ["seq_lock", "seq_trap"]},
	247: {"name": "Long Fuse", "size": Vector2i(7, 7), "blocks": [18, 20], "seq": [2, 3], "spin": [3, 5], "pairs": 1, "diff": [53.0, 58.0], "need": ["seq_trap", "remote"]},
	248: {"name": "Mirror Step", "size": Vector2i(7, 7), "blocks": [18, 20], "seq": [2, 2], "hidden": [1, 2], "spin": [3, 4], "diff": [54.0, 59.0], "need": ["seq_hidden", "seq_spinner"]},
	249: {"name": "Last Call", "size": Vector2i(7, 7), "blocks": [18, 21], "seq": [3, 3], "spin": [4, 5], "pairs": 1, "diff": [55.0, 60.0], "need": ["seq_spinner", "seq_portal"]},
	250: {"name": "Perfect Timing", "size": Vector2i(7, 7), "blocks": [19, 22], "seq": [3, 4], "spin": [4, 6], "pairs": 1, "diff": [62.0, 76.0],
		"need": ["seq_trap", "seq_spinner", "ad3"], "milestone_from": 226,
		"hint": "Milestone. WHEN you use each first tap is the whole puzzle."},
	# --- MOVABLE arc: Learn -------------------------------------------------------
	251: {"name": "First Push", "size": Vector2i(5, 5), "blocks": [3, 5], "crates": [1, 1], "spin": [1, 1], "diff": [5.0, 10.0], "need": ["push_ess"],
		"hint": "New: MOVABLE. Hit it with an arrow to push it one cell."},
	252: {"name": "Other Side", "size": Vector2i(5, 5), "blocks": [4, 6], "crates": [1, 1], "spin": [1, 1], "diff": [6.0, 12.0], "need": ["push_ess", "push_dirs2"],
		"hint": "Push it from any side. It never has to leave."},
	253: {"name": "Where It Lands", "size": Vector2i(5, 5), "blocks": [4, 6], "crates": [1, 1], "spin": [1, 1], "diff": [8.0, 14.0], "need": ["push_ess", "push_trap"],
		"hint": "Think where it stops: it can block you later."},
	254: {"name": "Push Order", "size": Vector2i(5, 6), "blocks": [5, 7], "crates": [1, 1], "spin": [1, 1], "diff": [10.0, 16.0], "need": ["push_ess", "pu2"],
		"hint": "Who pushes first decides where it ends up."},
	255: {"name": "First Crate Puzzle", "size": Vector2i(6, 6), "blocks": [7, 10], "crates": [1, 1], "spin": [1, 2], "diff": [18.0, 24.0], "need": ["push_ess", "pu2"]},
	# --- MOVABLE arc: Apply / future position ----------------------------------------
	256: {"name": "Two Crates", "size": Vector2i(6, 6), "blocks": [8, 11], "crates": [2, 2], "spin": [1, 2], "diff": [26.0, 31.0], "need": ["push_ess", "pu3"]},
	257: {"name": "Clear the Lane", "size": Vector2i(6, 6), "blocks": [8, 11], "crates": [1, 1], "spin": [1, 2], "diff": [28.0, 33.0], "need": ["push_ess", "push_trap", "pu2"]},
	258: {"name": "Soft Push", "size": Vector2i(6, 6), "blocks": [8, 10], "crates": [1, 1], "spin": [1, 2], "diff": [22.0, 26.0], "need": ["pu2"], "breather": true},
	259: {"name": "Corner Pocket", "size": Vector2i(6, 6), "blocks": [9, 12], "crates": [1, 1], "spin": [1, 2], "diff": [30.0, 35.0], "need": ["push_ess", "push_trap", "pu3"]},
	260: {"name": "Return Trip", "size": Vector2i(6, 6), "blocks": [9, 12], "crates": [1, 1], "spin": [1, 2], "diff": [32.0, 37.0], "need": ["push_ess", "push_dirs2", "pu3"]},
	261: {"name": "Crate Lines", "size": Vector2i(6, 6), "blocks": [9, 12], "crates": [2, 2], "spin": [1, 2], "diff": [34.0, 39.0], "need": ["push_ess", "pu4"]},
	262: {"name": "Stopper", "size": Vector2i(6, 7), "blocks": [10, 13], "crates": [1, 1], "spin": [2, 2], "diff": [35.0, 40.0], "need": ["push_ess", "push_trap"]},
	263: {"name": "Two Moves Ahead", "size": Vector2i(6, 7), "blocks": [10, 13], "crates": [1, 2], "spin": [1, 2], "diff": [37.0, 42.0], "need": ["push_ess", "push_trap", "pu3"]},
	264: {"name": "Easy Slide", "size": Vector2i(6, 6), "blocks": [9, 11], "crates": [1, 1], "spin": [1, 2], "diff": [30.0, 34.0], "need": ["pu2"], "breather": true},
	265: {"name": "Future Lane", "size": Vector2i(6, 7), "blocks": [10, 13], "crates": [2, 2], "spin": [1, 2], "diff": [39.0, 44.0], "need": ["push_ess", "push_trap", "pu4"]},
	# --- MOVABLE arc: Interact -----------------------------------------------------------
	266: {"name": "Spin and Push", "size": Vector2i(6, 7), "blocks": [10, 13], "crates": [1, 2], "spin": [2, 3], "diff": [40.0, 45.0], "need": ["push_ess", "push_spinner"]},
	267: {"name": "Hard Shell", "size": Vector2i(6, 7), "blocks": [10, 13], "crates": [1, 1], "spin": [1, 2], "armor": true, "diff": [41.0, 46.0], "need": ["push_ess", "rams"]},
	268: {"name": "Crate Portal", "size": Vector2i(6, 7), "blocks": [10, 13], "crates": [1, 1], "spin": [1, 2], "pairs": 1, "diff": [42.0, 47.0], "need": ["push_ess", "push_portal"]},
	269: {"name": "Sequence Push", "size": Vector2i(6, 7), "blocks": [10, 13], "crates": [1, 1], "seq": [1, 2], "spin": [1, 2], "diff": [43.0, 48.0], "need": ["push_ess", "seq_push"]},
	270: {"name": "Sliding Door", "size": Vector2i(6, 6), "blocks": [9, 12], "crates": [1, 1], "spin": [1, 2], "pairs": 1, "diff": [34.0, 38.0], "need": ["pu2", "push_portal"], "breather": true},
	271: {"name": "Plan Ahead", "size": Vector2i(6, 7), "blocks": [11, 14], "crates": [1, 2], "spin": [2, 3], "pairs": 1, "diff": [47.0, 52.0], "need": ["push_ess", "push_trap", "pu3"]},
	272: {"name": "Crossing", "size": Vector2i(7, 7), "blocks": [11, 14], "crates": [2, 2], "seq": [1, 2], "spin": [1, 2], "diff": [48.0, 53.0], "need": ["push_ess", "seq_push"]},
	273: {"name": "Hold Position", "size": Vector2i(7, 7), "blocks": [12, 15], "crates": [1, 2], "seq": [1, 2], "spin": [2, 3], "diff": [50.0, 55.0], "need": ["push_ess", "push_trap", "seq_trap"]},
	274: {"name": "Edge of Plan", "size": Vector2i(7, 7), "blocks": [12, 15], "crates": [2, 2], "spin": [2, 3], "pairs": 1, "diff": [46.0, 52.0], "need": ["push_ess", "push_trap", "pu4"]},
	275: {"name": "Future Perfect", "size": Vector2i(7, 7), "blocks": [13, 16], "crates": [2, 2], "spin": [2, 4], "pairs": 1, "diff": [52.0, 70.0],
		"need": ["push_ess", "push_trap", "pu4", "push_portal"], "milestone_from": 251,
		"hint": "Milestone. Choose where the Movable blocks will be LATER."},
	# --- INTEGRATION I --------------------------------------------------------------------
	276: {"name": "Crossover", "size": Vector2i(6, 7), "blocks": [16, 19], "seq": [2, 2], "spin": [3, 4], "pairs": 2, "diff": [48.0, 53.0], "need": ["seq_portal", "two_pairs"]},
	277: {"name": "Pushed Through", "size": Vector2i(6, 7), "blocks": [11, 14], "crates": [1, 1], "spin": [2, 3], "pairs": 1, "diff": [49.0, 54.0], "need": ["push_ess", "crate_portal"]},
	278: {"name": "Step and Shove", "size": Vector2i(6, 7), "blocks": [11, 14], "crates": [1, 2], "seq": [2, 2], "spin": [1, 2], "diff": [50.0, 55.0], "need": ["push_ess", "seq_push", "ad2"]},
	279: {"name": "Spinning Rhythm", "size": Vector2i(7, 7), "blocks": [18, 21], "seq": [2, 3], "spin": [4, 6], "rules": ["@", "@-", "@~"], "diff": [51.0, 56.0], "need": ["seq_trap", "seq_spinner"]},
	280: {"name": "Shell Through", "size": Vector2i(6, 7), "blocks": [17, 20], "seq": [1, 2], "armor": true, "pairs": 1, "spin": [2, 3], "diff": [52.0, 57.0], "need": ["armor_portal"]},
	# --- INTEGRATION II ---------------------------------------------------------------------
	281: {"name": "Open Road", "size": Vector2i(6, 7), "blocks": [16, 18], "seq": [2, 2], "spin": [2, 3], "pairs": 1, "diff": [44.0, 48.0], "need": ["seq_portal"], "breather": true},
	282: {"name": "Moving Target", "size": Vector2i(7, 7), "blocks": [12, 15], "crates": [1, 2], "spin": [3, 4], "diff": [54.0, 59.0], "need": ["push_ess", "push_spinner", "push_trap"]},
	283: {"name": "Hidden Door", "size": Vector2i(7, 7), "blocks": [18, 21], "seq": [2, 2], "hidden": [1, 2], "spin": [2, 3], "pairs": 1, "diff": [55.0, 60.0], "need": ["seq_hidden", "pm2"]},
	284: {"name": "Locked Crate", "size": Vector2i(7, 7), "blocks": [12, 15], "crates": [1, 1], "spin": [2, 3], "lock": true, "diff": [56.0, 61.0], "need": ["push_ess", "lock_crate"]},
	285: {"name": "Two Way Street", "size": Vector2i(7, 7), "blocks": [18, 21], "seq": [2, 3], "spin": [3, 4], "pairs": 2, "diff": [57.0, 62.0], "need": ["two_pairs", "two_way", "seq_portal"]},
	# --- ADVANCED ------------------------------------------------------------------------
	286: {"name": "Shove Off", "size": Vector2i(7, 7), "blocks": [12, 15], "crates": [1, 1], "seq": [1, 2], "pairs": 1, "spin": [1, 2], "diff": [58.0, 63.0], "need": ["push_ess", "seq_push", "push_portal"]},
	287: {"name": "Easy Orbit", "size": Vector2i(6, 7), "blocks": [13, 15], "crates": [1, 1], "seq": [1, 2], "spin": [1, 2], "diff": [47.0, 52.0], "need": ["pu2", "ad1"], "breather": true},
	288: {"name": "Toll Gate", "size": Vector2i(7, 7), "blocks": [18, 21], "seq": [2, 2], "gate": true, "pairs": 1, "spin": [2, 3], "diff": [59.0, 64.0], "need": ["seq_portal", "pm2"]},
	289: {"name": "Ram Line", "size": Vector2i(7, 7), "blocks": [12, 15], "crates": [1, 1], "armor": true, "spin": [2, 3], "diff": [48.0, 56.0], "need": ["push_ess", "rams"]},
	290: {"name": "Half Light", "size": Vector2i(7, 7), "blocks": [13, 16], "crates": [1, 1], "hidden": [1, 2], "spin": [2, 3], "diff": [48.0, 56.0], "need": ["push_ess", "push_trap"]},
	# --- EXPERT ---------------------------------------------------------------------------
	291: {"name": "Cold Logic", "size": Vector2i(7, 7), "blocks": [13, 16], "crates": [1, 2], "seq": [2, 2], "spin": [2, 3], "diff": [49.0, 57.0], "need": ["push_ess", "push_trap", "seq_trap"]},
	292: {"name": "Switchback Run", "size": Vector2i(7, 7), "blocks": [19, 22], "seq": [2, 2], "switch": true, "pairs": 1, "spin": [2, 3], "diff": [63.0, 68.0], "need": ["switch_portal", "seq_portal"]},
	293: {"name": "Far Reach", "size": Vector2i(7, 7), "blocks": [13, 16], "crates": [1, 1], "spin": [2, 3], "pairs": 1, "diff": [49.0, 57.0], "need": ["push_ess", "push_portal"]},
	294: {"name": "Clear Skies", "size": Vector2i(7, 7), "blocks": [14, 17], "seq": [2, 2], "crates": [1, 1], "spin": [1, 2], "diff": [44.0, 50.0], "need": ["pu2", "ad2"], "breather": true},
	295: {"name": "Heavy Lock", "size": Vector2i(7, 7), "blocks": [13, 16], "crates": [1, 1], "seq": [1, 2], "lock": true, "spin": [1, 2], "diff": [49.0, 57.0], "need": ["push_ess", "lock_crate", "ad1"]},
	# --- ROAD TO 300 ----------------------------------------------------------------------
	296: {"name": "Clockwork Heart", "size": Vector2i(7, 7), "blocks": [19, 22], "seq": [3, 3], "spin": [4, 6], "rules": ["@~", "@-", "@"], "pairs": 1, "diff": [65.0, 70.0], "need": ["seq_trap", "seq_spinner", "seq_portal"]},
	297: {"name": "Deep Freight", "size": Vector2i(6, 7), "blocks": [12, 15], "crates": [1, 2], "spin": [2, 3], "diff": [48.0, 56.0], "need": ["push_ess", "push_trap", "pu3"]},
	298: {"name": "Vault", "size": Vector2i(7, 7), "blocks": [14, 17], "crates": [1, 1], "seq": [1, 2], "armor": true, "diff": [50.0, 58.0], "need": ["push_ess", "rams", "seq_push"]},
	299: {"name": "Last Mile", "size": Vector2i(7, 7), "blocks": [20, 23], "seq": [2, 3], "spin": [4, 5], "pairs": 2, "diff": [68.0, 73.0], "need": ["seq_trap", "two_pairs", "seq_portal"]},
	300: {"name": "Every Way Out", "size": Vector2i(7, 7), "blocks": [15, 19], "seq": [2, 3], "crates": [1, 2], "spin": [2, 4], "pairs": 1, "diff": [70.0, 95.0],
		"need": ["push_ess", "push_trap", "seq_trap", "seq_push", "push_portal"], "milestone_from": 201, "margin": 0.5,
		"hint": "300 LEVELS. Portals, Sequence, spinners: plan every route."},
}

## --alt: alternative specs tried for a slot (the better accepted board is
## kept). 300 without a Movable block: Portal (two pairs) + Sequence +
## spinners - the Third Era's two "routing" mechanics at full depth.
const ALT_SPECS := {
	300: {"name": "Every Way Out", "size": Vector2i(7, 7), "blocks": [20, 23], "seq": [3, 4], "spin": [4, 6], "rules": ["@", "@-"], "pairs": 2, "diff": [70.0, 95.0],
		"need": ["seq_trap", "two_pairs", "two_way", "seq_portal", "seq_spinner"], "milestone_from": 201, "margin": 0.5,
		"hint": "300 LEVELS. Portals, Sequence, spinners: plan every route."},
}

## Silver / Gold per level [silver, gold]. Chapter 23: the Sequence lessons
## have none; Chapters 24-25 / 27-30: 5 S and 3-4 G like Chapters 20-22;
## Chapter 26: the Movable lessons have none.
const REWARDS := {
	229: [1, 0],
	231: [1, 0], 232: [0, 1], 234: [1, 0], 235: [1, 0], 237: [0, 1], 238: [1, 0], 239: [1, 1],
	241: [1, 0], 242: [0, 1], 244: [1, 0], 246: [1, 1], 247: [0, 1], 248: [1, 0], 250: [1, 1],
	255: [1, 0], 256: [0, 1], 257: [1, 0], 259: [1, 0], 260: [0, 1],
	261: [1, 0], 262: [0, 1], 264: [1, 0], 265: [1, 0], 267: [0, 1], 268: [1, 0], 269: [1, 1],
	271: [1, 0], 272: [0, 1], 273: [1, 0], 275: [1, 1], 276: [1, 0], 277: [0, 1], 279: [1, 0], 280: [0, 1],
	281: [1, 0], 282: [0, 1], 283: [1, 0], 284: [0, 1], 285: [1, 0], 287: [1, 0], 288: [0, 1], 289: [1, 0], 290: [0, 1],
	291: [1, 0], 292: [0, 1], 293: [1, 0], 295: [0, 1], 296: [1, 0], 297: [1, 0], 298: [0, 1], 300: [1, 1],
}

const COLORS := ["R", "B", "G", "Y", "P"]
const ARROWS := ["^", "v", "<", ">"]
const OPP := {"^": "v", "v": "^", "<": ">", ">": "<"}
const MARGIN := 2.0  # a milestone beats every level it must beat by this much

var rng := RandomNumberGenerator.new()
var known: Array = []  # LevelData of every other existing level (similarity)
var beat := {}  # n -> [difficulty, structural] of the levels a milestone must beat
var stats := {}
## --cheap=N: node budget for the climb's quick analysis (default 40000; a
## board that needs more is simply not climbed on). Acceptance always uses
## the full 40000.
var cheap_limit := 40000


func _initialize() -> void:
	var args := {"from": str(FROM), "to": str(TO), "seed": "1", "tries": "40", "climb": "300"}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	var write := "--write" in OS.get_cmdline_user_args()
	Solver.default_limit = 40000
	cheap_limit = int(args.get("cheap", "40000"))
	var from := int(args["from"])
	var to := int(args["to"])
	if from < FROM or to > TO:
		printerr("generate_era3: only levels %d-%d" % [FROM, TO])
		quit(1)
		return
	var failed := 0
	for n in range(from, to + 1):
		_load_known(n)
		rng.seed = hash([int(args["seed"]), n])
		var t0 := Time.get_ticks_msec()
		var best := _build_slot(n, int(args["tries"]), int(args["climb"]))
		if best.is_empty():
			printerr("L%d: no board found" % n)
			failed += 1
			continue
		var level: LevelData = best["level"]
		var m: Dictionary = best["m"]
		print("L%d %-18s %dx%d blk %d diff %.1f struct %.1f start %d depth %d dec %d len %d  seq %d ad %d (imp %s)  mov %d pu %d (ess %s imp %s)  portal %d pm %d  (%ds)" % [
			n, level.name, level.columns, level.rows, m["blocks"], m["difficulty"], LevelGenerator.structural_difficulty(m),
			m["start_moves"], m["depth"], m["decision_points"], m["solution_length"], m["sequence_blocks"], m["advances"], str(m["sequence_impact"]),
			m["crates"], m["pushes"], str(m["push_essential"]), str(m["movable_impact"]), m["portal_pairs"], m["portal_moves"],
			(Time.get_ticks_msec() - t0) / 1000])
		var text := LevelManager.to_json_text(level)
		print(text)
		if write:
			var f := FileAccess.open(LevelManager.LEVEL_PATH % n, FileAccess.WRITE)
			f.store_string(text)
			f.close()
	quit(1 if failed > 0 else 0)


func _load_known(skip: int) -> void:
	known.clear()
	beat.clear()
	var spec: Dictionary = _spec(skip)
	var n := 1
	while FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
		if n != skip:
			var lv := LevelManager.read_level(n)
			known.append(lv)
			if spec.has("milestone_from") and n >= int(spec["milestone_from"]) and n < skip:
				var m := LevelAnalysis.analyze(lv, false)
				beat[n] = [m["difficulty"], LevelGenerator.structural_difficulty(m)]
		n += 1


# --- One slot -------------------------------------------------------------------

func _spec(n: int) -> Dictionary:
	return ALT_SPECS[n] if "--alt" in OS.get_cmdline_user_args() and ALT_SPECS.has(n) else SPECS[n]


func _build_slot(n: int, tries: int, climb: int) -> Dictionary:
	var spec: Dictionary = _spec(n)
	var lo: float = spec["diff"][0]
	var hi: float = spec["diff"][1]
	var best := {}
	var best_err := INF
	var accepted := 0
	var enough := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--enough="):
			enough = int(a.get_slice("=", 1))
	for t in tries:
		var map := _random_board(spec)
		var e := _cheap(n, map, spec)
		var score := _score(e)
		for it in climb:
			var cand := _mutate(map, spec)
			var ce := _cheap(n, cand, spec)
			var cs := _score(ce)
			if cs >= score:
				map = cand
				e = ce
				score = cs
			if e["ok"]:
				break
		if not e["ok"]:
			_stat("climb: miss %s shape %.1f dist %.1f" % [str(e["missed"]), e["shape"], e["dist"]])
			continue
		var full := _accept(n, map, spec)
		if full.is_empty():
			continue
		var d: float = full["m"]["difficulty"]
		# Milestones: the harder the better (inside the band); others: the
		# band's centre.
		var err := (hi - d) if spec.has("milestone_from") else absf(d - (lo + hi) * 0.5)
		accepted += 1
		if err < best_err:
			best_err = err
			best = full
			print("  L%d try %d: diff %.1f" % [n, t, d])
		# Enough: --enough accepted boards (default 3), or one near the centre.
		if accepted >= enough or (not spec.has("milestone_from") and best_err <= 1.0):
			break
	if "--stats" in OS.get_cmdline_user_args():
		print("  L%d rejects: %s" % [n, str(stats)])
	stats.clear()
	return best


func _stat(k: String) -> void:
	stats[k] = stats.get(k, 0) + 1


func _is_lesson(n: int) -> bool:
	for arc in Verify.ARCS:
		if n in arc["lessons"]:
			return true
	return false


## Fast checks for the climb (no impacts): the needs, the band, the shape.
func _cheap(n: int, map: Array, spec: Dictionary) -> Dictionary:
	var e := {"ok": false, "valid": false, "solvable": false, "miss": 0, "missed": [], "dist": 0.0, "shape": 0.0, "sim": 0.0, "beat": 0.0}
	var level := _parse(n, map, spec)
	if level == null:
		return e
	e["valid"] = true
	for other in known:
		if other.rows == level.rows and other.columns == level.columns:
			e["sim"] = maxf(e["sim"], LevelGenerator.similarity(level, other))
	Solver.default_limit = cheap_limit  # the climb: a smaller search budget
	var m := LevelAnalysis.analyze(level, false)
	Solver.default_limit = 40000
	if not m["solvable"] or m["aborted"]:
		return e
	e["solvable"] = true
	var lo: float = spec["diff"][0]
	var hi: float = spec["diff"][1]
	var d: float = m["difficulty"]
	e["dist"] = maxf(0.0, lo - d) + maxf(0.0, d - hi)
	var shape := 0.0
	if _is_lesson(n):
		shape += maxi(0, m["start_moves"] - 3) * 1.0 + maxi(0, 3 - m["depth"]) * 1.0
	else:
		shape += maxi(0, m["start_moves"] - 2) * 1.0 + maxi(0, 8 - m["depth"]) * 0.5 + maxi(0, 4 - m["decision_points"]) * 0.5
		shape += (0.0 if m["directions_used"] == 4 else 1.0) + maxf(0.0, m["direction_share"] - 0.45) * 10.0
	e["shape"] = shape
	if spec.has("milestone_from"):
		var s := LevelGenerator.structural_difficulty(m)
		for k in beat:
			e["beat"] += maxf(0.0, beat[k][0] + spec.get("margin", MARGIN) - d) + maxf(0.0, beat[k][1] + spec.get("margin", MARGIN) - s)
	var info := _interactions(level, m)
	if "push_ess" in spec["need"] or (m["crates"] > 0 and not spec.get("breather", false)):
		# One solve with pushes forbidden: can it be won without pushing?
		var no_push := Solver.from_model(_model(level))
		no_push.allow_push = false
		if no_push.is_solvable() or no_push.aborted:
			e["miss"] += 1
			e["missed"].append("push_ess")
	for need in spec["need"]:
		if need in ["push_ess", "push_trap", "seq_trap", "trap_start"]:
			continue  # push_ess above; the traps in _accept (extra solves)
		if not _need_ok(need, info, m):
			e["miss"] += 1
			e["missed"].append(need)
	e["ok"] = e["miss"] == 0 and shape == 0.0 and e["dist"] == 0.0 and e["sim"] <= Verify.MAX_SIMILARITY and e["beat"] == 0.0
	return e


func _score(e: Dictionary) -> float:
	if not e["valid"]:
		return -1000.0
	if not e["solvable"]:
		return -500.0
	return 100.0 - e["miss"] * 15.0 - e["shape"] * 6.0 - e["dist"] * 2.0 - e["beat"] * 1.0 \
		- maxf(0.0, e["sim"] - Verify.MAX_SIMILARITY) * 100.0


## Full acceptance: every campaign rule (the verifier's own functions), the
## extra-solve needs, armor safety, similarity, rewards.
func _accept(n: int, map: Array, spec: Dictionary) -> Dictionary:
	var level := _parse(n, map, spec)
	if level == null:
		return {}
	var m := LevelAnalysis.analyze(level)
	if not m["solvable"] or m["aborted"]:
		_stat("full analysis gave up")
		return {}
	var issue := Verify._rule_issue(n, m)
	if issue != "":
		_stat(issue)
		return {}
	if "push_ess" in spec["need"] and not m["push_essential"]:
		_stat("push not essential")
		return {}
	# Difficulty must not come from pushing the same block again and again.
	if m["pushes"] > maxi(4, int(m["solution_length"] * 0.4)):
		_stat("too many pushes")
		return {}
	# Breathers stay real puzzles: their Third Era mechanics must matter too
	# (the verifier allows less on breathers; the generator does not).
	if spec.get("breather", false):
		if m["sequence_blocks"] > 0 and m["sequence_impact"] < 1.0:
			_stat("breather: sequence minor")
			return {}
		if m["portal_pairs"] > 0 and m["portal_impact"] < 1.0:
			_stat("breather: portal minor")
			return {}
		if m["crates"] > 0 and not m["push_essential"] and m["movable_impact"] < 1.0:
			_stat("breather: movable minor")
			return {}
	for kind in ["push_trap", "seq_trap", "trap_start"]:
		if kind in spec["need"] and _traps(level, kind) == 0:
			_stat("no " + kind)
			return {}
	if m["armored"] > 0 and not _armor_safe(level):
		_stat("armor unsafe")
		return {}
	for other in known:
		if other.rows == level.rows and other.columns == level.columns and LevelGenerator.similarity(level, other) > Verify.MAX_SIMILARITY:
			_stat("similar")
			return {}
	if spec.has("milestone_from"):
		var s := LevelGenerator.structural_difficulty(m)
		for k in beat:
			if m["difficulty"] <= beat[k][0] + spec.get("margin", MARGIN) or s <= beat[k][1] + spec.get("margin", MARGIN):
				_stat("not above L%d" % k)
				return {}
	var gen := LevelGenerator.new(hash([n, 7]))
	var rw: Array = REWARDS.get(n, [0, 0])
	gen.assign_reward_blocks(level, rw[0], rw[1])
	if Verify._reward_issue(n, level) != "":
		_stat("reward issue")
		return {}
	var got := Verify._reward_text(level)
	if got.count("S") != rw[0] or got.count("G") != rw[1]:
		_stat("rewards not placed")
		return {}
	# The level must survive its own JSON exactly (rewards included).
	var again := LevelManager.parse_level(JSON.parse_string(LevelManager.to_json_text(level)), n, true)
	if not Solver.from_model(_model(again)).is_solvable():
		_stat("round trip")
		return {}
	return {"level": level, "m": m}


func _model(level: LevelData) -> BoardModel:
	var model := BoardModel.new()
	model.setup(level.rows, level.columns, level.blocks)
	model.set_portals(level.portals)
	return model


func _parse(n: int, map: Array, spec: Dictionary) -> LevelData:
	var json := {"name": spec["name"], "map": map}
	if spec.has("hint"):
		json["hint"] = spec["hint"]
		json["hint_finger"] = false
	if spec.get("hidden", [0, 0])[1] > 0:
		json["mystery"] = true
	var groups := {}
	for r in map.size():
		var tokens := String(map[r]).split(" ", false)
		for c in tokens.size():
			if tokens[c].begins_with(Portals.TOKEN_PREFIX):
				groups[Vector2i(c, r)] = tokens[c].substr(1)
	if not groups.is_empty():
		if not Portals.layout_errors(map.size(), String(map[0]).split(" ", false).size(), groups).is_empty():
			return null
		for a in groups:
			for b in groups:
				if a != b and groups[a] == groups[b] and (a.x == b.x or a.y == b.y or (absi(a.x - b.x) <= 1 and absi(a.y - b.y) <= 1)):
					return null
	var level := LevelManager.parse_level(json, n, true)
	if level.portals.size() != spec.get("pairs", 0) * 2:
		return null
	return level


# --- What the solution does with the mechanics --------------------------------------------

func _interactions(level: LevelData, m: Dictionary) -> Dictionary:
	var info := {"remote": 0, "gate_lane": false, "switch_portal": false, "ram": false, "rams": 0,
		"seq_spinner": false, "seq_portal": false, "seq_hidden": false, "seq_armor": false, "seq_lock": false,
		"seq_push": false, "push_portal": false, "crate_portal": false, "push_spinner": false, "push_dirs": {},
		"lock_crate": false}
	var model := _model(level)
	var lock_keys := {}
	for b in level.blocks:
		if b.lock_color != "":
			lock_keys[b.lock_color] = true
	for b in level.blocks:
		if b.seq_stage != 0 and lock_keys.has(b.color):
			info["seq_lock"] = true
	for id in model.blocks:
		var b: BlockData = model.blocks[id]
		var ln := model.lane(id)
		if not ln["via"].is_empty() and ln["blocker"] != null:
			if ln["blocker"].is_gate():
				info["gate_lane"] = true
			elif model.move_state(id) not in ["ram", "push"] and not b.is_gate() and not b.is_crate():
				info["remote"] += 1
	for id in m["solution"]:
		var b: BlockData = model.blocks[id]
		var via: Array = model.lane(id)["via"] if not level.portals.is_empty() else []
		match model.move_state(id):
			"ram":
				info["rams"] += 1
				if not via.is_empty():
					info["ram"] = true
				if b.seq_stage != 0:
					info["seq_armor"] = true  # a Sequence block cracks a shell
				model.ram(id)
			"advance":
				if not via.is_empty():
					info["seq_portal"] = true
				var turned := model.advance(id)
				if not turned.is_empty():
					info["seq_spinner"] = true
				if not model.last_revealed.is_empty():
					info["seq_hidden"] = true
			"push":
				if b.is_spinner():
					info["push_spinner"] = true
				info["push_dirs"][b.direction] = true
				var push := model.push(id)
				if push.get("advanced", false):
					info["seq_push"] = true
					if not push["turned"].is_empty():
						info["seq_spinner"] = true
				if not push.get("via", []).is_empty():
					info["crate_portal"] = true
					info["push_portal"] = true
				if not via.is_empty():
					info["push_portal"] = true
			_:
				if b.seq_stage == 2 and not via.is_empty():
					info["seq_portal"] = true
				if (b.is_switch() or b.flip_link != "") and not via.is_empty():
					info["switch_portal"] = true
				if b.color in lock_keys:
					# A lock's key leaves while a Movable block is still on
					# the board and has been pushed: the crate decided when.
					pass
				model.remove(id)
	# Movable x lock: some locked block's lane or a key's lane is first
	# blocked by a Movable block at the start.
	var start := _model(level)
	for id in start.blocks:
		var b: BlockData = start.blocks[id]
		if b.lock_color == "" and not lock_keys.has(b.color):
			continue
		var blk := start.find_blocker(id)
		if blk != null and blk.is_crate():
			info["lock_crate"] = true
	return info


func _need_ok(need: String, info: Dictionary, m: Dictionary) -> bool:
	match need:
		"remote": return info["remote"] >= 1
		"two_way": return m["portal_cells_entered"] == m["portal_pairs"] * 2
		"two_pairs": return m["portal_groups_used"] >= 2
		"gate_portal": return info["gate_lane"]
		"switch_portal": return info["switch_portal"]
		"armor_portal": return info["ram"]
		"rams": return info["rams"] >= 1
		"seq_spinner": return info["seq_spinner"]
		"seq_portal": return info["seq_portal"]
		"seq_hidden": return info["seq_hidden"]
		"seq_armor": return info["seq_armor"]
		"seq_lock": return info["seq_lock"]
		"seq_push": return info["seq_push"]
		"push_portal": return info["push_portal"]
		"crate_portal": return info["crate_portal"]
		"push_spinner": return info["push_spinner"]
		"push_dirs2": return info["push_dirs"].size() >= 2
		"lock_crate": return info["lock_crate"]
	if need.begins_with("ad"):
		return m["advances"] >= int(need.substr(2))
	if need.begins_with("pu"):
		return m["pushes"] >= int(need.substr(2))
	if need.begins_with("pm"):
		return m["portal_moves"] >= int(need.substr(2))
	return false


## Losing moves of one kind - "push_trap": a push, "seq_trap": a first
## stage (an advance, or a first-stage push) - anywhere along the solver's
## solution; "trap_start": a portal move at the start.
func _traps(level: LevelData, kind: String) -> int:
	var model := _model(level)
	var path := Solver.from_model(model).solve()
	var traps := 0
	for step in path.size():
		for id in model.blocks.keys():
			var st := model.move_state(id)
			var b: BlockData = model.blocks[id]
			var hit := false
			match kind:
				"push_trap": hit = st == "push"
				"seq_trap": hit = st == "advance" or (st == "push" and b.seq_stage == 1)
				"trap_start": hit = (st == "ok" or st == "ram") and not model.lane(id)["via"].is_empty()
			if not hit:
				continue
			var snap := model.snapshot()
			_play(model, id, st)
			var s := Solver.from_model(model)
			if not model.is_empty() and not s.is_solvable() and not s.aborted:
				traps += 1
			model.restore(snap)
		if kind == "trap_start":
			break
		var mv: int = path[step]
		_play(model, mv, model.move_state(mv))
	return traps


static func _play(model: BoardModel, id: int, st: String) -> void:
	match st:
		"ram": model.ram(id)
		"advance": model.advance(id)
		"push": model.push(id)
		_: model.remove(id)


func _armor_safe(level: LevelData) -> bool:
	var r := Solver.from_model(_model(level)).armor_audit()
	return r["complete"] and r["armor_dead_ends"] == 0


# --- Random boards and mutations ----------------------------------------------------------

func _seq_token(color: String, dir: String) -> String:
	var next: String = ARROWS[rng.randi_range(0, 3)]
	while next == dir:
		next = ARROWS[rng.randi_range(0, 3)]
	return color + dir + ":" + next


func _random_board(spec: Dictionary) -> Array:
	var size: Vector2i = spec["size"]
	var grid := []
	for r in size.y:
		var row := []
		row.resize(size.x)
		row.fill(".")
		grid.append(row)
	for g in ["A", "B"].slice(0, spec.get("pairs", 0)):
		var a := _free(grid, size)
		var b := a
		while b.x == a.x or b.y == a.y or grid[b.y][b.x] != ".":
			b = Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		grid[a.y][a.x] = "O" + g
		grid[b.y][b.x] = "O" + g
	var n_blocks := rng.randi_range(spec["blocks"][0], spec["blocks"][1])
	var tokens := []
	for i in n_blocks:
		tokens.append(COLORS[rng.randi_range(0, 4)] + ARROWS[rng.randi_range(0, 3)])
	var k := 0
	var seq: Array = spec.get("seq", [0, 0])
	for i in rng.randi_range(seq[0], seq[1]):
		tokens[k] = _seq_token(String(tokens[k])[0], String(tokens[k])[1])
		k += 1
	var spin: Array = spec.get("spin", [0, 0])
	var rules: Array = spec.get("rules", ["@"])
	for i in rng.randi_range(spin[0], spin[1]):
		tokens[k] += rules[i % rules.size()]
		k += 1
	for i in spec.get("hidden", [0, 0])[0]:
		tokens[k] += "?"
		k += 1
	if spec.get("lock", false):
		var key := String(tokens[k + 1])[0]
		var col: String = COLORS[(COLORS.find(key) + 1 + rng.randi_range(0, 3)) % 5]
		tokens[k] = col + String(tokens[k])[1] + "#" + key
		k += 2
	if spec.get("switch", false):
		tokens[k] += "%A"
		tokens[k + 1] += "&A"
		tokens[k + 2] += "&A"
		k += 3
	if spec.get("gate", false):
		tokens.append("XC")
		tokens[k] += "+C"
		tokens[k + 1] += "+C"
		k += 2
	if spec.get("armor", false):
		tokens[k] += "="
		k += 1
	var crates: Array = spec.get("crates", [0, 0])
	for i in rng.randi_range(crates[0], crates[1]):
		tokens.append("M")
	if spec.get("lock", false) and spec.has("seq"):
		# Sequence x lock: one Sequence block wears the lock's key color.
		var lk := ""
		for t in tokens:
			if String(t).contains("#"):
				lk = String(t).substr(String(t).find("#") + 1, 1)
		for i in tokens.size():
			if String(tokens[i]).contains(":"):
				tokens[i] = lk + String(tokens[i]).substr(1)
				break
	for t in tokens:
		var c := _free(grid, size)
		grid[c.y][c.x] = t
	return _rows(grid)


func _free(grid: Array, size: Vector2i) -> Vector2i:
	while true:
		var c := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		if grid[c.y][c.x] == ".":
			return c
	return Vector2i.ZERO


func _rows(grid: Array) -> Array:
	var out := []
	for row in grid:
		out.append(" ".join(PackedStringArray(row)))
	return out


func _mutate(map: Array, spec: Dictionary) -> Array:
	var grid := []
	for row in map:
		grid.append(Array(String(row).split(" ", false)))
	var rows := grid.size()
	var cols: int = grid[0].size()
	var arrows := []  # arrow blocks
	var movable := []  # anything that can move to another cell
	var empty := []
	var portals := []
	for r in rows:
		for c in cols:
			var t: String = grid[r][c]
			if t == ".":
				empty.append(Vector2i(c, r))
			elif t.begins_with("O"):
				portals.append(Vector2i(c, r))
			else:
				movable.append(Vector2i(c, r))
				if not t.begins_with("X") and t != "M":
					arrows.append(Vector2i(c, r))
	var kind := rng.randi_range(0, 12)
	if kind <= 4 and not arrows.is_empty():
		# New arrow (a Sequence block keeps a NEXT arrow that differs).
		var b: Vector2i = arrows[rng.randi_range(0, arrows.size() - 1)]
		var t: String = grid[b.y][b.x]
		var dir: String = ARROWS[rng.randi_range(0, 3)]
		if t.contains(":"):
			var nx := t.substr(t.find(":") + 1, 1)
			if dir == nx:
				dir = OPP[nx]
			grid[b.y][b.x] = t[0] + dir + t.substr(2)
		else:
			grid[b.y][b.x] = t[0] + dir + t.substr(2)
	elif kind == 5 and not arrows.is_empty():
		# New NEXT arrow for a Sequence block.
		var seqs := arrows.filter(func(v): return String(grid[v.y][v.x]).contains(":"))
		if not seqs.is_empty():
			var b: Vector2i = seqs[rng.randi_range(0, seqs.size() - 1)]
			var t: String = grid[b.y][b.x]
			var nx: String = ARROWS[rng.randi_range(0, 3)]
			if nx != t[1]:
				grid[b.y][b.x] = t.substr(0, t.find(":") + 1) + nx
	elif kind <= 9 and not empty.is_empty() and not movable.is_empty():
		var b: Vector2i = movable[rng.randi_range(0, movable.size() - 1)]
		var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
		grid[e.y][e.x] = grid[b.y][b.x]
		grid[b.y][b.x] = "."
	elif kind == 10 and not arrows.is_empty():
		var b: Vector2i = arrows[rng.randi_range(0, arrows.size() - 1)]
		var t: String = grid[b.y][b.x]
		var col: String = COLORS[rng.randi_range(0, 4)]
		if not t.contains("#" + col) and not t.contains("#"):
			grid[b.y][b.x] = col + t.substr(1)
	elif kind == 11 and not empty.is_empty():
		# Add or remove a plain block (inside the block range).
		var plain := arrows.filter(func(v): return String(grid[v.y][v.x]).length() == 2)
		if rng.randf() < 0.5 and arrows.size() < spec["blocks"][1]:
			var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
			grid[e.y][e.x] = COLORS[rng.randi_range(0, 4)] + ARROWS[rng.randi_range(0, 3)]
		elif arrows.size() > spec["blocks"][0] and not plain.is_empty():
			var b: Vector2i = plain[rng.randi_range(0, plain.size() - 1)]
			grid[b.y][b.x] = "."
	elif not empty.is_empty() and not portals.is_empty():
		var p: Vector2i = portals[rng.randi_range(0, portals.size() - 1)]
		var e: Vector2i = empty[rng.randi_range(0, empty.size() - 1)]
		grid[e.y][e.x] = grid[p.y][p.x]
		grid[p.y][p.x] = "."
	return _rows(grid)
