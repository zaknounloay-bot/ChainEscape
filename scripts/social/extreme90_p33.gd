class_name Extreme90P33
extends Extreme90P32
## DEVELOPMENT ONLY (?extreme90p33=1): the Phase 33 EXTREME candidates
## (docs/extreme90_phase33.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p32=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1.. = NEW33: technically qualified, NOT human-approved); every board the
## Phase 32 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## n+1..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb33_*", its own hub key) and export ("ce-xb33"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P33_PARAM := "extreme90p33"
const P33_STATE_PATH := "user://xb33_hub.json"
const P33_LS_KEY := "chain_escape_xb33_hub"
const SELECTION33 := "xb33-v1"
const NEW33 := ["N94", "N95", "N96", "N97", "N98", "N99", "N100"]
## Project-owner decisions on the Phase 32 boards
## (data/dev/extreme90_p32/owner_decisions_n88_n93.json), stored apart from
## the difficulty ratings: N88-N93 all NOT approved (bank stays 38/50).
## Boards and ids unchanged.
const DOWNGRADED32 := ["N88", "N89", "N90", "N91", "N92", "N93"]
const BUILD33 := "p33-qa1-20261103"


static func p33_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P33_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P33_PARAM + "=1") or where.contains(P33_PARAM + "=true")


## Every board the Phase 32 page held, in its order (the previous list).
static func previous33() -> Array:
	return Extreme90P32.selection32()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection33() -> Array:
	return NEW33 + previous33()


static func group33(k: String) -> String:
	if NEW33.has(k):
		return "phase33"
	if DOWNGRADED32.has(k):
		return "downgraded"
	return Extreme90P32.group32(k)


func board_order() -> Array:
	return selection33()


func previous_boards() -> Array:
	return previous33()


func store() -> String:
	return "xb33"


func hub_state_path() -> String:
	return P33_STATE_PATH


func hub_ls_key() -> String:
	return P33_LS_KEY


func bundle_format() -> String:
	return "ce-xb33"


func publish_name() -> String:
	return "chainEscapeXb33"


func build_label() -> String:
	return "DEV BUILD " + BUILD33


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION33
	b["build"] = BUILD33
	for k in b["boards"]:
		b["boards"][k]["group"] = group33(k)
	return b
