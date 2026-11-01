class_name Extreme90P29
extends Extreme90P28
## DEVELOPMENT ONLY (?extreme90p29=1): the Phase 29 EXTREME candidates
## (docs/extreme90_phase29.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p28=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1.. = NEW29: technically qualified, NOT human-approved); every board the
## Phase 28 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## n+1..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb29_*", its own hub key) and export ("ce-xb29"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P29_PARAM := "extreme90p29"
const P29_STATE_PATH := "user://xb29_hub.json"
const P29_LS_KEY := "chain_escape_xb29_hub"
const SELECTION29 := "xb29-v1"
const NEW29 := ["N71", "N72", "N73", "N74", "N75", "N76", "N77"]
## Project-owner decisions (data/dev/extreme90_p29/owner_approvals_p29.json),
## stored apart from the players' ratings (extreme90_p28/human_p28.json):
## approved N64, N68, N69; not approved N63, N65, N67, N70; N66 borderline
## (not approved). Boards and ids unchanged.
const OWNER_APPROVED29 := ["N64", "N68", "N69"]
const DOWNGRADED29 := ["N63", "N65", "N67", "N70"]
const BORDERLINE29 := ["N66"]
const BUILD29 := "p29-qa1-20261031"


static func p29_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P29_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P29_PARAM + "=1") or where.contains(P29_PARAM + "=true")


## Every board the Phase 28 page held, in its order (the previous list).
static func previous29() -> Array:
	return Extreme90P28.selection28()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection29() -> Array:
	return NEW29 + previous29()


static func group29(k: String) -> String:
	if NEW29.has(k):
		return "phase29"
	if OWNER_APPROVED29.has(k):
		return "approved"
	if DOWNGRADED29.has(k):
		return "downgraded"
	if BORDERLINE29.has(k):
		return "borderline"
	return Extreme90P28.group28(k)


func board_order() -> Array:
	return selection29()


func previous_boards() -> Array:
	return previous29()


func store() -> String:
	return "xb29"


func hub_state_path() -> String:
	return P29_STATE_PATH


func hub_ls_key() -> String:
	return P29_LS_KEY


func bundle_format() -> String:
	return "ce-xb29"


func publish_name() -> String:
	return "chainEscapeXb29"


func build_label() -> String:
	return "DEV BUILD " + BUILD29


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION29
	b["build"] = BUILD29
	for k in b["boards"]:
		b["boards"][k]["group"] = group29(k)
	return b
