class_name Extreme90P24
extends Extreme90P22
## DEVELOPMENT ONLY (?extreme90p24=1): the Phase 24 EXTREME prototype
## (docs/extreme90_phase24.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p22=1
## and ?ta90=1 are unchanged and stay the historical entries (Phase 23 made no
## board and no page).
## QA rule: the primary screen shows ONLY this phase's new board (CHALLENGE 1
## = N52: designed by hand, technically qualified, NOT human-approved); every
## board the Phase 22 page held is on the optional PREVIOUS CHALLENGES screen
## (CHALLENGE 2..k). Neutral labels, no difficulty shown, no locks. Its own
## storage ("xb24_*", its own hub key) and export ("ce-xb24"), every run under
## its real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P24_PARAM := "extreme90p24"
const P24_STATE_PATH := "user://xb24_hub.json"
const P24_LS_KEY := "chain_escape_xb24_hub"
const SELECTION24 := "xb24-v1"
const NEW24 := ["N52"]
## Phase 22 human results (data/dev/extreme90_p22/human_p22.json): N48, N49
## and N51 strong provisional, N50 downgraded. Boards and ids unchanged.
const STRONG_PROVISIONAL22 := ["N48", "N49", "N51"]
const DOWNGRADED22 := ["N50"]
const BUILD24 := "p24-qa1-20261029"


static func p24_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P24_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P24_PARAM + "=1") or where.contains(P24_PARAM + "=true")


## Every board the Phase 22 page held, in its order (the previous list).
static func previous24() -> Array:
	return Extreme90P22.selection22()


## In CHALLENGE order: the new board, then the previous ones.
static func selection24() -> Array:
	return NEW24 + previous24()


static func group24(k: String) -> String:
	if NEW24.has(k):
		return "phase24"
	if DOWNGRADED22.has(k):
		return "downgraded"
	if STRONG_PROVISIONAL22.has(k):
		return "strong_provisional"
	return Extreme90P22.group22(k)


func board_order() -> Array:
	return selection24()


func previous_boards() -> Array:
	return previous24()


func store() -> String:
	return "xb24"


func hub_state_path() -> String:
	return P24_STATE_PATH


func hub_ls_key() -> String:
	return P24_LS_KEY


func bundle_format() -> String:
	return "ce-xb24"


func publish_name() -> String:
	return "chainEscapeXb24"


func build_label() -> String:
	return "DEV BUILD " + BUILD24


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION24
	b["build"] = BUILD24
	for k in b["boards"]:
		b["boards"][k]["group"] = group24(k)
	return b
