class_name Extreme90Review
extends Extreme90Bank
## DEVELOPMENT ONLY (?extreme90p17=1): the Phase 17 EXTREME candidate
## selection (docs/extreme90_phase17.md). The Phase 16 bank page
## (Extreme90Bank, ?extreme90=1) is unchanged and stays the archive entry for
## every Phase 16 board (N17, N19, N20, N22 included); this page shows only
## the active selection:
##   - CORE (N3, N5, N7, N11, N13), the Phase 16 boards the family playtests
##     kept (N14, N15, N16, N18, N21), N23 (borderline: PROVISIONAL, internal
##     only - never shown) and the Phase 17 candidates (N24-...);
##   - shown as neutral CHALLENGE 1..k, no difficulty shown;
##   - its own storage ("xb17_*" per board, its own hub key) and export
##     ("ce-xb17"), so records never mix with ?extreme90=1 or ?ta90=1; every
##     record and the export keep the internal board id and its fingerprint;
##   - the same 90 s page and the same SHORT questionnaire (Phase 16A).
## Player / QA builds: never opened (BuildFlags.dev_pages_off()).

const REVIEW_PARAM := "extreme90p17"
const REVIEW_STATE_PATH := "user://xb17_hub.json"
const REVIEW_LS_KEY := "chain_escape_xb17_hub"
const SELECTION := "xb17-v1"
const CORE := ["N3", "N5", "N7", "N11", "N13"]
const STRONG := ["N14", "N15", "N16", "N18", "N21"]
const PROVISIONAL := ["N23"]
## Archived from the active selection (Phase 17A): still in BOARDS90, still
## played and exported by ?extreme90=1.
const ARCHIVED := ["N17", "N19", "N20", "N22"]
const NEW17 := ["N24", "N25", "N26", "N27", "N28", "N29", "N30"]


static func review_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + REVIEW_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(REVIEW_PARAM + "=1") or where.contains(REVIEW_PARAM + "=true")


static func selection() -> Array:
	return CORE + STRONG + PROVISIONAL + NEW17


func board_order() -> Array:
	return selection()


func store() -> String:
	return "xb17"


func hub_state_path() -> String:
	return REVIEW_STATE_PATH


func hub_ls_key() -> String:
	return REVIEW_LS_KEY


func bundle_format() -> String:
	return "ce-xb17"


func publish_name() -> String:
	return "chainEscapeXb17"


## The Phase 16 bank export, plus the selection: its version, each board's
## group (internal: never shown on the page) and the archived ids.
func bundle() -> Dictionary:
	var b := super.bundle()
	b["selection"] = SELECTION
	b["archived"] = ARCHIVED
	for k in b["boards"]:
		b["boards"][k]["group"] = "core" if CORE.has(k) else "strong" if STRONG.has(k) else "provisional" if PROVISIONAL.has(k) else "phase17"
	return b
