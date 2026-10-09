class_name BuildFlags
## Build-time switches. PLAYER BUILD: the "Web Friend Test" export preset sets
## the custom feature "player_build" (export_presets.cfg). In that build the
## debug panel can never open (no F1, no 5 taps on the title, no --debug)
## and the developer pages (?experiencelab, ?openinglab, ?twinsprototype,
## ?mechlab, ?friendbench, ?vhtest) are off: a player only ever gets the
## normal game. Every other export and every test run is unchanged.


static func player_build() -> bool:
	return OS.has_feature("player_build")
