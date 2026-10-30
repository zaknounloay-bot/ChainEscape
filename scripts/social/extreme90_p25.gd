class_name Extreme90P25
extends Extreme90P24
## DEVELOPMENT ONLY (?extreme90p25=1): the Phase 25 EXTREME candidates
## (docs/extreme90_phase25.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p24=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1-6 = N53-N58: technically qualified, NOT human-approved); every board the
## Phase 24 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## 7..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb25_*", its own hub key) and export ("ce-xb25"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P25_PARAM := "extreme90p25"
const P25_STATE_PATH := "user://xb25_hub.json"
const P25_LS_KEY := "chain_escape_xb25_hub"
const SELECTION25 := "xb25-v1"
const NEW25 := ["N53", "N54", "N55", "N56", "N57", "N58"]
## Phase 24 human results (data/dev/extreme90_p24/human_p24.json): N52 is
## human-approved EXTREME (two independent first exposures). Board and id unchanged.
const APPROVED24 := ["N52"]
const BUILD25 := "p25-qa1-20261030"


static func p25_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P25_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P25_PARAM + "=1") or where.contains(P25_PARAM + "=true")


## Every board the Phase 24 page held, in its order (the previous list).
static func previous25() -> Array:
	return Extreme90P24.selection24()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection25() -> Array:
	return NEW25 + previous25()


static func group25(k: String) -> String:
	if NEW25.has(k):
		return "phase25"
	if APPROVED24.has(k):
		return "approved"
	return Extreme90P24.group24(k)


func board_order() -> Array:
	return selection25()


func previous_boards() -> Array:
	return previous25()


func store() -> String:
	return "xb25"


func hub_state_path() -> String:
	return P25_STATE_PATH


func hub_ls_key() -> String:
	return P25_LS_KEY


func bundle_format() -> String:
	return "ce-xb25"


func publish_name() -> String:
	return "chainEscapeXb25"


func build_label() -> String:
	return "DEV BUILD " + BUILD25


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION25
	b["build"] = BUILD25
	for k in b["boards"]:
		b["boards"][k]["group"] = group25(k)
	return b
