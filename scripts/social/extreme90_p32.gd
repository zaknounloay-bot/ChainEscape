class_name Extreme90P32
extends Extreme90P31
## DEVELOPMENT ONLY (?extreme90p32=1): the Phase 32 EXTREME candidates
## (docs/extreme90_phase32.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p31=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1.. = NEW32: technically qualified, NOT human-approved); every board the
## Phase 31 page held is on the optional PREVIOUS CHALLENGES screen (CHALLENGE
## n+1..k). Neutral labels, no difficulty shown, no locks. Its own storage
## ("xb32_*", its own hub key) and export ("ce-xb32"), every run under its
## real board id. The 90 s rules, the exact TIME UP continuation and the
## SHORT questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P32_PARAM := "extreme90p32"
const P32_STATE_PATH := "user://xb32_hub.json"
const P32_LS_KEY := "chain_escape_xb32_hub"
const SELECTION32 := "xb32-v1"
const NEW32 := ["N88", "N89", "N90", "N91", "N92", "N93"]
## Project-owner decisions on the Phase 31 boards
## (data/dev/extreme90_p31/owner_decisions_n83_n87.json), stored apart from
## the players' ratings (extreme90_p31/human_p31.json): approved N83, N86,
## N87 (bank 38/50); not approved N84, N85. N78-N82 keep "tested, no
## decision" (N82 pending an explicit owner decision). Boards and ids unchanged.
const OWNER_APPROVED31 := ["N83", "N86", "N87"]
const DOWNGRADED31 := ["N84", "N85"]
const BUILD32 := "p32-qa1-20261102"


static func p32_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P32_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P32_PARAM + "=1") or where.contains(P32_PARAM + "=true")


## Every board the Phase 31 page held, in its order (the previous list).
static func previous32() -> Array:
	return Extreme90P31.selection31()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection32() -> Array:
	return NEW32 + previous32()


static func group32(k: String) -> String:
	if NEW32.has(k):
		return "phase32"
	if OWNER_APPROVED31.has(k):
		return "approved"
	if DOWNGRADED31.has(k):
		return "downgraded"
	return Extreme90P31.group31(k)


func board_order() -> Array:
	return selection32()


func previous_boards() -> Array:
	return previous32()


func store() -> String:
	return "xb32"


func hub_state_path() -> String:
	return P32_STATE_PATH


func hub_ls_key() -> String:
	return P32_LS_KEY


func bundle_format() -> String:
	return "ce-xb32"


func publish_name() -> String:
	return "chainEscapeXb32"


func build_label() -> String:
	return "DEV BUILD " + BUILD32


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION32
	b["build"] = BUILD32
	for k in b["boards"]:
		b["boards"][k]["group"] = group32(k)
	return b
