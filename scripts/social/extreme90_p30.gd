class_name Extreme90P30
extends Extreme90P29
## DEVELOPMENT ONLY (?extreme90p30=1): the Phase 30 EXTREME candidates
## (docs/extreme90_phase30.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p29=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1.. = NEW30: technically qualified, NOT human-approved); every board the
## Phase 29 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## n+1..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb30_*", its own hub key) and export ("ce-xb30"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P30_PARAM := "extreme90p30"
const P30_STATE_PATH := "user://xb30_hub.json"
const P30_LS_KEY := "chain_escape_xb30_hub"
const SELECTION30 := "xb30-v1"
const NEW30 := ["N78", "N79", "N80", "N81", "N82"]
## Project-owner decisions (data/dev/extreme90_p29/owner_decisions_n71_n77.json),
## stored apart from the players' ratings (extreme90_p29/human_p29.json):
## approved N72, N75, N77; not approved N71, N73, N74, N76. Boards and ids unchanged.
const OWNER_APPROVED30 := ["N72", "N75", "N77"]
const DOWNGRADED30 := ["N71", "N73", "N74", "N76"]
const BUILD30 := "p30-qa1-20261031"


static func p30_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P30_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P30_PARAM + "=1") or where.contains(P30_PARAM + "=true")


## Every board the Phase 29 page held, in its order (the previous list).
static func previous30() -> Array:
	return Extreme90P29.selection29()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection30() -> Array:
	return NEW30 + previous30()


static func group30(k: String) -> String:
	if NEW30.has(k):
		return "phase30"
	if OWNER_APPROVED30.has(k):
		return "approved"
	if DOWNGRADED30.has(k):
		return "downgraded"
	return Extreme90P29.group29(k)


func board_order() -> Array:
	return selection30()


func previous_boards() -> Array:
	return previous30()


func store() -> String:
	return "xb30"


func hub_state_path() -> String:
	return P30_STATE_PATH


func hub_ls_key() -> String:
	return P30_LS_KEY


func bundle_format() -> String:
	return "ce-xb30"


func publish_name() -> String:
	return "chainEscapeXb30"


func build_label() -> String:
	return "DEV BUILD " + BUILD30


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION30
	b["build"] = BUILD30
	for k in b["boards"]:
		b["boards"][k]["group"] = group30(k)
	return b
