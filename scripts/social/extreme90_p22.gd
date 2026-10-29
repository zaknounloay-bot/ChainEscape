class_name Extreme90P22
extends Extreme90P21
## DEVELOPMENT ONLY (?extreme90p22=1): the Phase 22 EXTREME candidates
## (docs/extreme90_phase22.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p21=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1-4 = N48-N51: technically qualified, NOT human-approved); every board the
## Phase 21 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## 5..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb22_*", its own hub key) and export ("ce-xb22"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the SHORT
## questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P22_PARAM := "extreme90p22"
const P22_STATE_PATH := "user://xb22_hub.json"
const P22_LS_KEY := "chain_escape_xb22_hub"
const SELECTION22 := "xb22-v1"
const NEW22 := ["N48", "N49", "N50", "N51"]
## Phase 21 joint human evaluation (data/dev/extreme90_p21/human_p21.json):
## promising boards stay provisional candidates; N41 (EASY) and N46 (MEDIUM)
## are downgraded. Boards and ids unchanged.
const PROMISING21 := ["N39", "N40", "N42", "N43", "N44", "N45", "N47"]
const DOWNGRADED21 := ["N41", "N46"]
const BUILD22 := "p22-qa1-20261029"


static func p22_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P22_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P22_PARAM + "=1") or where.contains(P22_PARAM + "=true")


## Every board the Phase 21 page held, in its order (the previous list).
static func previous22() -> Array:
	return Extreme90P21.selection21()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection22() -> Array:
	return NEW22 + previous22()


static func group22(k: String) -> String:
	if NEW22.has(k):
		return "phase22"
	if DOWNGRADED21.has(k):
		return "downgraded"
	if PROMISING21.has(k):
		return "provisional"
	return Extreme90P21.group21(k)


func board_order() -> Array:
	return selection22()


func previous_boards() -> Array:
	return previous22()


func store() -> String:
	return "xb22"


func hub_state_path() -> String:
	return P22_STATE_PATH


func hub_ls_key() -> String:
	return P22_LS_KEY


func bundle_format() -> String:
	return "ce-xb22"


func publish_name() -> String:
	return "chainEscapeXb22"


func build_label() -> String:
	return "DEV BUILD " + BUILD22


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION22
	b["build"] = BUILD22
	for k in b["boards"]:
		b["boards"][k]["group"] = group22(k)
	return b
