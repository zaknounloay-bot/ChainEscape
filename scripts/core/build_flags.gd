class_name BuildFlags
## Build-time switches. PLAYER BUILD: the "Web Friend Test" export preset sets
## the custom feature "player_build" (export_presets.cfg). In that build the
## debug panel can never open (no F1, no 5 taps on the title, no --debug)
## and the developer pages (?experiencelab, ?openinglab, ?twinsprototype,
## ?mechlab, ?friendbench, ?vhtest) are off: a player only ever gets the
## normal game. Every other export and every test run is unchanged.
##
## QA BUILD: the "Web QA" export preset sets the custom feature "qa_build".
## That build only ever runs the Experience Lab QA session (Levels 1-300,
## its own QA save - see ExperienceLab): the normal save, Friend Challenge
## and every other developer page are never opened, with or without URL
## parameters.
##
## MAGNET LAB BUILD: the "Web Magnet Lab" export preset sets "magnet_lab".
## That build only ever opens the Magnet mechanic lab (?mechlab=magnet,
## prototype) over a game that uses its own save keys - never the normal
## save, Friend Challenge or any other developer page; no debug panel.


static func player_build() -> bool:
	return OS.has_feature("player_build")


static func qa_build() -> bool:
	return OS.has_feature("qa_build")


static func magnet_lab() -> bool:
	return OS.has_feature("magnet_lab")


## No debug panel (F1, title taps, --debug): the player build and the
## Magnet lab build.
static func debug_off() -> bool:
	return player_build() or magnet_lab()


## GAMEPLAY HUD, layout C, with the live TIME / MY BEST timer (approved
## after real-iPhone QA): on in EVERY build, the player (production) build
## included. To roll the Production HUD back to the 1-300 release layout
## (coins top-right, 34-unit hearts, CHAIN popup, no live timer), return
## `not player_build()` here - nothing else changes.
static func live_timer_hud() -> bool:
	return true


## GAMEPLAY FEEDBACK POLISH (Phase 2A, QA): a stronger heart loss with a
## small heart rising from the tapped block, the blocker of a blocked tap
## ringed (only when it is unambiguous), a lock-icon response with a
## repeating explanation, and "No moves left" naming only a button that
## works; a grey SHOW A MOVE / HAMMER opens the Shop only when inventory
## is the one thing missing. Visual / guidance only - rules, hearts,
## scoring, prices, limits and saves are unchanged. Approved after
## real-iPhone QA: on in EVERY build, the player (production) build
## included. To roll Production back to the released feedback, return
## `not player_build()` here - nothing else changes.
static func feedback_polish() -> bool:
	return true


## PLAYER IDENTITY (Phase 3A, QA): an anonymous random player id in the
## save's [profile] section and an optional display name in Settings.
## Local only - nothing is sent anywhere. On in every build except the
## player (production) build, which neither creates an id nor shows the
## name row (a [profile] already in a save is kept untouched there).
static func player_identity() -> bool:
	return not player_build()


## The other developer pages (?openinglab, ?twinsprototype, ?mechlab,
## ?friendbench, ?vhtest): off in the player build and in the QA build.
static func dev_pages_off() -> bool:
	return player_build() or qa_build() or magnet_lab()
