class_name Extreme90P19
extends Extreme90P18
## DEVELOPMENT ONLY (?extreme90p19=1): the Phase 19 EXTREME selection
## (docs/extreme90_phase19.md). ?extreme90=1, ?extreme90p17=1,
## ?extreme90p18=1 and ?ta90=1 are unchanged and stay the historical entries.
## QA rule (Phase 19 refinement): the primary screen shows ONLY this phase's
## new boards (CHALLENGE 1-2 = N35, N36). The boards earlier phases already
## tested - CORE, the 13 strong boards, N23 and N24 (PROVISIONAL, internal
## only - never shown) - sit on a separate, optional PREVIOUS CHALLENGES screen
## (CHALLENGE 3..k, a scrolling list) for regression or replay. Neutral labels,
## no difficulty shown, no locks. Its own storage ("xb19_*", its own hub key)
## and export ("ce-xb19"), every run under its real board id.
## A later phase extends this page: previous_boards() = this page's
## board_order(), and its new boards are found as the rest.
## The 90 s rules, the exact TIME UP continuation (Phase 18B) and the SHORT
## questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P19_PARAM := "extreme90p19"
const P19_STATE_PATH := "user://xb19_hub.json"
const P19_LS_KEY := "chain_escape_xb19_hub"
const SELECTION19 := "xb19-v2"  # v2: new boards first (CHALLENGE 1-2), the previous ones after
const NEW19 := ["N35", "N36"]
## Developer build identifier (shown small on CHOOSE A CHALLENGE, in the export).
const BUILD19 := "p19-qa3-20261028"


static func p19_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P19_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P19_PARAM + "=1") or where.contains(P19_PARAM + "=true")


## In CHALLENGE order: the new boards, then the previous selection.
static func selection19() -> Array:
	return NEW19 + Extreme90P18.selection()


static func group19(k: String) -> String:
	return "phase19" if NEW19.has(k) else Extreme90P18.group_of(k)


func board_order() -> Array:
	return selection19()


func build_label() -> String:
	return "DEV BUILD " + BUILD19


## Already tested in earlier phases: the PREVIOUS CHALLENGES screen.
func previous_boards() -> Array:
	return Extreme90P18.selection()


func store() -> String:
	return "xb19"


func hub_state_path() -> String:
	return P19_STATE_PATH


func hub_ls_key() -> String:
	return P19_LS_KEY


func bundle_format() -> String:
	return "ce-xb19"


func publish_name() -> String:
	return "chainEscapeXb19"


func grid_columns() -> int:
	return 3


func tile_height() -> int:
	return 84


func select_compact() -> bool:
	return false


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION19
	b["archived"] = ARCHIVED
	for k in b["boards"]:
		b["boards"][k]["group"] = group19(k)
		b["boards"][k]["list"] = "previous" if previous_boards().has(k) else "new"
	b["new"] = new_boards()
	b["build"] = BUILD19
	return b
