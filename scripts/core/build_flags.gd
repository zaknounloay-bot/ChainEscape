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
## SOCIAL QA BUILD (Phase 4): the "Web Social QA" export preset sets
## "social_qa". The normal game with Social (CREATE CHALLENGE, both tracks,
## shared links) for testing Social changes - stable challenge links first -
## in its own save (file + Web keys, never the release save r2), with no
## debug panel, no developer pages and no competition (nothing is sent to
## the results pools).
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


static func social_qa() -> bool:
	return OS.has_feature("social_qa")


## No debug panel (F1, title taps, --debug): the player build, the Magnet
## lab build and the Social QA build.
static func debug_off() -> bool:
	return player_build() or magnet_lab() or social_qa()


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


## PLAYER IDENTITY (Phase 3A): an anonymous random player id in the save's
## [profile] section and an optional display name in Settings ("NAME: ...",
## up to 20 characters, the five approved emoji). Local only - nothing is
## sent anywhere. Approved after real-iPhone QA: on in EVERY build, the
## player (production) build included. To roll Production back, return
## `not player_build()` here: that build then neither creates an id nor
## shows the name row, and a [profile] already in a save is kept untouched.
static func player_identity() -> bool:
	return true


## REAL-PLAYER RESULTS (Phase 3B-B/C): finished attempts are sent to the
## chain-escape-api results backend (Competition) and the level card shows
## the server's TOP X%. On in the QA build (the server's "qa" pool, with
## timing diagnostics) and in the player (production) build (the "prod"
## pool, no diagnostics - Competition picks the pool from the build). Off
## in the developer and Magnet lab builds. The prod pool stays closed on
## the server until CE_PROD_POOL / CE_PROD_ORIGINS are set; until then the
## player build keeps its results queued (SAVED, WILL SEND LATER). To roll
## the production build back to no competition, return qa_build() here.
## Tests: competition_override (-1 = the build's rule, 0 = off, 1 = on).
static var competition_override := -1


static func competition() -> bool:
	if competition_override != -1:
		return competition_override == 1
	return qa_build() or player_build()


## STABLE CHALLENGE LINKS (Phase 4): share links point at the "go" Edge
## Function (SocialConfig.STABLE_LINK_BASE), which redirects to the current
## itch.io upload - so a link keeps working after a new upload. ONLY in the
## Social QA build (explicit eligibility), whose links carry to=qa (the QA
## destination). Every other build - the player (production) build, the
## developer, QA and Magnet lab builds, tests - keeps the page's own
## address, byte-for-byte as before.
## Tests: stable_links_override (-1 = the build's rule, 0 = off, 1 = on).
static var stable_links_override := -1


static func stable_links() -> bool:
	if stable_links_override != -1:
		return stable_links_override == 1
	return social_qa()


## The other developer pages (?openinglab, ?twinsprototype, ?mechlab,
## ?friendbench, ?vhtest): off in the player build, the QA build, the
## Magnet lab build and the Social QA build.
static func dev_pages_off() -> bool:
	return player_build() or qa_build() or magnet_lab() or social_qa()
