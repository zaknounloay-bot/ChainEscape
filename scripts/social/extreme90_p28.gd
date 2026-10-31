class_name Extreme90P28
extends Extreme90P27
## DEVELOPMENT ONLY (?extreme90p28=1): the Phase 28 EXTREME candidates
## (docs/extreme90_phase28.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p27=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1.. = NEW28: technically qualified, NOT human-approved); every board the
## Phase 27 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## n+1..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb28_*", its own hub key) and export ("ce-xb28"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P28_PARAM := "extreme90p28"
const P28_STATE_PATH := "user://xb28_hub.json"
const P28_LS_KEY := "chain_escape_xb28_hub"
const SELECTION28 := "xb28-v1"
const NEW28 := ["N63", "N64", "N65", "N66", "N67", "N68", "N69", "N70"]
## Project-owner decision (data/dev/extreme90_p28/owner_approvals_p28.json),
## stored apart from the player's rating: N62 approved. Every earlier
## decision (Extreme90P27) unchanged; N60 stays downgraded.
const OWNER_APPROVED28 := ["N62"]
const BUILD28 := "p28-qa1-20261031"


static func p28_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P28_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P28_PARAM + "=1") or where.contains(P28_PARAM + "=true")


## Every board the Phase 27 page held, in its order (the previous list).
static func previous28() -> Array:
	return Extreme90P27.selection27()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection28() -> Array:
	return NEW28 + previous28()


static func group28(k: String) -> String:
	if NEW28.has(k):
		return "phase28"
	if OWNER_APPROVED28.has(k):
		return "approved"
	return Extreme90P27.group27(k)


func board_order() -> Array:
	return selection28()


func previous_boards() -> Array:
	return previous28()


func store() -> String:
	return "xb28"


func hub_state_path() -> String:
	return P28_STATE_PATH


func hub_ls_key() -> String:
	return P28_LS_KEY


func bundle_format() -> String:
	return "ce-xb28"


func publish_name() -> String:
	return "chainEscapeXb28"


func build_label() -> String:
	return "DEV BUILD " + BUILD28


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION28
	b["build"] = BUILD28
	for k in b["boards"]:
		b["boards"][k]["group"] = group28(k)
	return b
