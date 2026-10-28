class_name Extreme90P21
extends Extreme90P20
## DEVELOPMENT ONLY (?extreme90p21=1): the Phase 21 EXTREME candidates
## (docs/extreme90_phase21.md). ?extreme90=1, ?extreme90p17=1 .. ?extreme90p20=1
## and ?ta90=1 are unchanged and stay the historical entries.
## QA rule: the primary screen shows ONLY this phase's new boards (CHALLENGE
## 1-9 = N39-N47); every board the Phase 20 page held (N37, N38 - now STRONG -
## then N35, N36 and the Phase 18B selection) is on the optional PREVIOUS
## CHALLENGES screen (CHALLENGE 10..k). Neutral labels, no difficulty shown, no
## locks. Its own storage ("xb21_*", its own hub key) and export ("ce-xb21"),
## every run under its real board id. The 90 s rules, the exact TIME UP
## continuation (Phase 18B, with the Phase 20 ram log) and the SHORT
## questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P21_PARAM := "extreme90p21"
const P21_STATE_PATH := "user://xb21_hub.json"
const P21_LS_KEY := "chain_escape_xb21_hub"
const SELECTION21 := "xb21-v1"
const NEW21 := ["N39", "N40", "N41", "N42", "N43", "N44", "N45", "N46", "N47"]
## Phase 21: N37 / N38 played by two experienced players on real iPhones and
## promoted to STRONG (docs/extreme90_phase21.md); ids and boards unchanged.
const TESTED20 := ["N37", "N38"]
const BUILD21 := "p21-qa1-20261028"


static func p21_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P21_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P21_PARAM + "=1") or where.contains(P21_PARAM + "=true")


## Every board the Phase 20 page held, in its order (the previous list).
static func previous21() -> Array:
	return Extreme90P20.selection20()


## In CHALLENGE order: the new boards, then the previous ones.
static func selection21() -> Array:
	return NEW21 + previous21()


static func group21(k: String) -> String:
	if NEW21.has(k):
		return "phase21"
	if TESTED20.has(k):
		return "strong"
	return Extreme90P20.group20(k)


func board_order() -> Array:
	return selection21()


func previous_boards() -> Array:
	return previous21()


func store() -> String:
	return "xb21"


func hub_state_path() -> String:
	return P21_STATE_PATH


func hub_ls_key() -> String:
	return P21_LS_KEY


func bundle_format() -> String:
	return "ce-xb21"


func publish_name() -> String:
	return "chainEscapeXb21"


func build_label() -> String:
	return "DEV BUILD " + BUILD21


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION21
	b["build"] = BUILD21
	for k in b["boards"]:
		b["boards"][k]["group"] = group21(k)
	return b
