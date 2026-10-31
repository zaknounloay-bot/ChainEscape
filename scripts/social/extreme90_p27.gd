class_name Extreme90P27
extends Extreme90P26
## DEVELOPMENT ONLY (?extreme90p27=1): the Phase 27 EXTREME candidates
## (docs/extreme90_phase27.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p26=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1.. = NEW27: technically qualified, NOT human-approved); every board the
## Phase 26 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## n+1..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb27_*", its own hub key) and export ("ce-xb27"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P27_PARAM := "extreme90p27"
const P27_STATE_PATH := "user://xb27_hub.json"
const P27_LS_KEY := "chain_escape_xb27_hub"
const SELECTION27 := "xb27-v1"
const NEW27 := ["N62"]
## Project-owner decisions (data/dev/extreme90_p27/owner_approvals_p27.json),
## stored apart from the players' ratings: approved N53, N55, N56, N59, N61;
## not approved N54, N57, N58, N60. Boards and ids unchanged.
const OWNER_APPROVED27 := ["N53", "N55", "N56", "N59", "N61"]
const DOWNGRADED27 := ["N54", "N57", "N58", "N60"]
const BUILD27 := "p27-qa1-20261030"


static func p27_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P27_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P27_PARAM + "=1") or where.contains(P27_PARAM + "=true")


## Every board the Phase 26 page held, in its order (the previous list).
static func previous27() -> Array:
	return Extreme90P26.selection26()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection27() -> Array:
	return NEW27 + previous27()


static func group27(k: String) -> String:
	if NEW27.has(k):
		return "phase27"
	if OWNER_APPROVED27.has(k):
		return "approved"
	if DOWNGRADED27.has(k):
		return "downgraded"
	return Extreme90P26.group26(k)


func board_order() -> Array:
	return selection27()


func previous_boards() -> Array:
	return previous27()


func store() -> String:
	return "xb27"


func hub_state_path() -> String:
	return P27_STATE_PATH


func hub_ls_key() -> String:
	return P27_LS_KEY


func bundle_format() -> String:
	return "ce-xb27"


func publish_name() -> String:
	return "chainEscapeXb27"


func build_label() -> String:
	return "DEV BUILD " + BUILD27


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION27
	b["build"] = BUILD27
	for k in b["boards"]:
		b["boards"][k]["group"] = group27(k)
	return b
