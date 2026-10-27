class_name Extreme90P18
extends Extreme90Bank
## DEVELOPMENT ONLY (?extreme90p18=1): the Phase 18 EXTREME selection
## (docs/extreme90_phase18.md). ?extreme90=1 (Phase 16), ?extreme90p17=1
## (Phase 17) and ?ta90=1 are unchanged and stay the archive / historical
## entries; every archived board keeps its data, fingerprint and records there.
## This page shows only the active selection after the Phase 17 playtests:
##   - CORE (N3, N5, N7, N11, N13), the STRONG human-review boards (N14, N15,
##     N16, N18, N21, N26, N27, N29, N30), N23 and N24 (PROVISIONAL, internal
##     only - never shown) and the Phase 18 candidates (N31-...);
##   - neutral CHALLENGE 1..k, no difficulty shown, no locks: any challenge
##     (the new ones included) can be opened directly;
##   - its own storage ("xb18_*" per board, its own hub key) and export
##     ("ce-xb18"), each board with its id, fingerprint, mechanics and group;
##   - the same 90 s page and the same SHORT questionnaire (Phase 16A).
## Player / QA builds: never opened (BuildFlags.dev_pages_off()).

const P18_PARAM := "extreme90p18"
const P18_STATE_PATH := "user://xb18_hub.json"
const P18_LS_KEY := "chain_escape_xb18_hub"
const SELECTION := "xb18-v1"
const CORE := ["N3", "N5", "N7", "N11", "N13"]
const STRONG := ["N14", "N15", "N16", "N18", "N21", "N26", "N27", "N29", "N30"]
const PROVISIONAL := ["N23", "N24"]
## Archived from the active selection (Phases 17 / 18): still in BOARDS90,
## still played and exported by ?extreme90=1 / ?extreme90p17=1.
const ARCHIVED := ["N17", "N19", "N20", "N22", "N25", "N28"]
const NEW18 := ["N31", "N32", "N33", "N34"]


static func p18_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + P18_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(P18_PARAM + "=1") or where.contains(P18_PARAM + "=true")


static func selection() -> Array:
	return CORE + STRONG + PROVISIONAL + NEW18


static func group_of(k: String) -> String:
	if CORE.has(k):
		return "core"
	if STRONG.has(k):
		return "strong"
	if PROVISIONAL.has(k):
		return "provisional"
	return "phase18"


func board_order() -> Array:
	return selection()


func store() -> String:
	return "xb18"


func hub_state_path() -> String:
	return P18_STATE_PATH


func hub_ls_key() -> String:
	return P18_LS_KEY


func bundle_format() -> String:
	return "ce-xb18"


func publish_name() -> String:
	return "chainEscapeXb18"


## More than 18 challenges: still three to a row (four would clip "CHALLENGE
## 17" to "CHALLEN"), slightly lower tiles so seven rows stay on one iPhone SE
## screen. Up to 21 challenges fit this way; more need another layout.
func grid_columns() -> int:
	return 3


func tile_height() -> int:
	return 80 if board_order().size() > 18 else 84


func select_compact() -> bool:
	return board_order().size() > 18


## The Phase 16 bank export (ids, fingerprints, mechanics, runs, answers), plus
## the selection version, each board's group (internal) and the archived ids.
func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION
	b["archived"] = ARCHIVED
	for k in b["boards"]:
		b["boards"][k]["group"] = group_of(k)
	return b
