class_name Extreme90P31
extends Extreme90P30
## DEVELOPMENT ONLY (?extreme90p31=1): the Phase 31 EXTREME candidates
## (docs/extreme90_phase31.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p30=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1.. = NEW31: technically qualified, NOT human-approved); every board the
## Phase 30 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## n+1..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb31_*", its own hub key) and export ("ce-xb31"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P31_PARAM := "extreme90p31"
const P31_STATE_PATH := "user://xb31_hub.json"
const P31_LS_KEY := "chain_escape_xb31_hub"
const SELECTION31 := "xb31-v1"
const NEW31 := ["N83", "N84", "N85", "N86", "N87"]
## N78-N82: played in Phase 30 (human_p30), NO owner decision recorded yet
## (N82 recommended, not approved). The owner manifest stays 35/50.
const TESTED30 := ["N78", "N79", "N80", "N81", "N82"]
const BUILD31 := "p31-qa1-20261101"


static func p31_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P31_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P31_PARAM + "=1") or where.contains(P31_PARAM + "=true")


## Every board the Phase 30 page held, in its order (the previous list).
static func previous31() -> Array:
	return Extreme90P30.selection30()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection31() -> Array:
	return NEW31 + previous31()


static func group31(k: String) -> String:
	if NEW31.has(k):
		return "phase31"
	if TESTED30.has(k):
		return "tested_no_decision"
	return Extreme90P30.group30(k)


func board_order() -> Array:
	return selection31()


func previous_boards() -> Array:
	return previous31()


func store() -> String:
	return "xb31"


func hub_state_path() -> String:
	return P31_STATE_PATH


func hub_ls_key() -> String:
	return P31_LS_KEY


func bundle_format() -> String:
	return "ce-xb31"


func publish_name() -> String:
	return "chainEscapeXb31"


func build_label() -> String:
	return "DEV BUILD " + BUILD31


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION31
	b["build"] = BUILD31
	for k in b["boards"]:
		b["boards"][k]["group"] = group31(k)
	return b
