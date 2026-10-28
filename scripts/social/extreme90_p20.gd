class_name Extreme90P20
extends Extreme90P19
## DEVELOPMENT ONLY (?extreme90p20=1): the Phase 20 EXTREME candidates
## (docs/extreme90_phase20.md). ?extreme90=1, ?extreme90p17=1, ?extreme90p18=1,
## ?extreme90p19=1 and ?ta90=1 are unchanged and stay the historical entries.
## QA rule (Phase 19 refinement): the primary screen shows ONLY this phase's
## new boards (CHALLENGE 1-2 = N37, N38); every board the Phase 19 page held
## (N35, N36 - now STRONG - and the Phase 18B selection) is on the optional
## PREVIOUS CHALLENGES screen (CHALLENGE 3..k). Neutral labels, no difficulty
## shown, no locks. Its own storage ("xb20_*", its own hub key) and export
## ("ce-xb20"), every run under its real board id. The 90 s rules, the exact
## TIME UP continuation (Phase 18B) and the SHORT questionnaire are the page's
## own (Ta90TimeAttack), unchanged.

const P20_PARAM := "extreme90p20"
const P20_STATE_PATH := "user://xb20_hub.json"
const P20_LS_KEY := "chain_escape_xb20_hub"
const SELECTION20 := "xb20-v1"
const NEW20 := ["N37", "N38"]
## Phase 20: N35 / N36 played by two experienced players on real iPhones and
## promoted to STRONG (docs/extreme90_phase20.md); ids and boards unchanged.
const TESTED19 := ["N35", "N36"]
const BUILD20 := "p20-qa1-20261028"


static func p20_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P20_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P20_PARAM + "=1") or where.contains(P20_PARAM + "=true")


## Every board the Phase 19 page held, in its order (the previous list).
static func previous20() -> Array:
	return Extreme90P19.selection19()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection20() -> Array:
	return NEW20 + previous20()


static func group20(k: String) -> String:
	if NEW20.has(k):
		return "phase20"
	if TESTED19.has(k):
		return "strong"
	return Extreme90P18.group_of(k)


func board_order() -> Array:
	return selection20()


func previous_boards() -> Array:
	return previous20()


func store() -> String:
	return "xb20"


func hub_state_path() -> String:
	return P20_STATE_PATH


func hub_ls_key() -> String:
	return P20_LS_KEY


func bundle_format() -> String:
	return "ce-xb20"


func publish_name() -> String:
	return "chainEscapeXb20"


func build_label() -> String:
	return "DEV BUILD " + BUILD20


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION20
	b["build"] = BUILD20
	for k in b["boards"]:
		b["boards"][k]["group"] = group20(k)
	return b
