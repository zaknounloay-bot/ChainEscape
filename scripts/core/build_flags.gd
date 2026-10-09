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


static func player_build() -> bool:
	return OS.has_feature("player_build")


static func qa_build() -> bool:
	return OS.has_feature("qa_build")


## The other developer pages (?openinglab, ?twinsprototype, ?mechlab,
## ?friendbench, ?vhtest): off in the player build and in the QA build.
static func dev_pages_off() -> bool:
	return player_build() or qa_build()
