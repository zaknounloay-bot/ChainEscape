class_name Extreme90P19
extends Extreme90P18
## DEVELOPMENT ONLY (?extreme90p19=1): the Phase 19 EXTREME selection
## (docs/extreme90_phase19.md). ?extreme90=1, ?extreme90p17=1,
## ?extreme90p18=1 and ?ta90=1 are unchanged and stay the historical entries.
## The active selection: CORE, the 13 strong human-review boards, N23 and N24
## (PROVISIONAL, internal only - never shown), then the Phase 19 candidates;
## neutral CHALLENGE 1..k, no difficulty shown, no locks. The list scrolls (full
## size tiles), and a neutral line says which challenges are the newest. Its
## own storage ("xb19_*", its own hub key) and export ("ce-xb19").
## The 90 s rules, the exact TIME UP continuation (Phase 18B) and the SHORT
## questionnaire are the page's own (Ta90TimeAttack), unchanged.

const P19_PARAM := "extreme90p19"
const P19_STATE_PATH := "user://xb19_hub.json"
const P19_LS_KEY := "chain_escape_xb19_hub"
const SELECTION19 := "xb19-v1"
const NEW19 := ["N35", "N36"]


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


static func selection19() -> Array:
	return Extreme90P18.selection() + NEW19


static func group19(k: String) -> String:
	return "phase19" if NEW19.has(k) else Extreme90P18.group_of(k)


func board_order() -> Array:
	return selection19()


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


func select_scroll() -> bool:
	return true


## Where the newest challenges are (neutral: no difficulty, no ids).
func select_note() -> String:
	if NEW19.is_empty():
		return ""
	var first := Extreme90P18.selection().size() + 1
	return "Newest: CHALLENGE %d-%d (scroll down)" % [first, first + NEW19.size() - 1]


func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION19
	b["archived"] = ARCHIVED
	for k in b["boards"]:
		b["boards"][k]["group"] = group19(k)
	return b
