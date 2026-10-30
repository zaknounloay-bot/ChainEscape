class_name Extreme90P26
extends Extreme90P25
## DEVELOPMENT ONLY (?extreme90p26=1): the Phase 26 EXTREME candidates
## (docs/extreme90_phase26.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p25=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1-3 = N59-N61: technically qualified, NOT human-approved); every board the
## Phase 25 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## 4..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb26_*", its own hub key) and export ("ce-xb26"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P26_PARAM := "extreme90p26"
const P26_STATE_PATH := "user://xb26_hub.json"
const P26_LS_KEY := "chain_escape_xb26_hub"
const SELECTION26 := "xb26-v1"
const NEW26 := ["N59", "N60", "N61"]
## Phase 25 human results (data/dev/extreme90_p25/human_p25.json): N53, N55
## and N56 strong provisional, N54, N57 and N58 downgraded. Boards and ids unchanged.
const STRONG_PROVISIONAL25 := ["N53", "N55", "N56"]
const DOWNGRADED25 := ["N54", "N57", "N58"]
const BUILD26 := "p26-qa1-20261030"


static func p26_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P26_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P26_PARAM + "=1") or where.contains(P26_PARAM + "=true")


## Every board the Phase 25 page held, in its order (the previous list).
static func previous26() -> Array:
	return Extreme90P25.selection25()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection26() -> Array:
	return NEW26 + previous26()


static func group26(k: String) -> String:
	if NEW26.has(k):
		return "phase26"
	if DOWNGRADED25.has(k):
		return "downgraded"
	if STRONG_PROVISIONAL25.has(k):
		return "strong_provisional"
	return Extreme90P25.group25(k)


func board_order() -> Array:
	return selection26()


func previous_boards() -> Array:
	return previous26()


func store() -> String:
	return "xb26"


func hub_state_path() -> String:
	return P26_STATE_PATH


func hub_ls_key() -> String:
	return P26_LS_KEY


func bundle_format() -> String:
	return "ce-xb26"


func publish_name() -> String:
	return "chainEscapeXb26"


func build_label() -> String:
	return "DEV BUILD " + BUILD26


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION26
	b["build"] = BUILD26
	for k in b["boards"]:
		b["boards"][k]["group"] = group26(k)
	return b
