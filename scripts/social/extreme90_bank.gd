class_name Extreme90Bank
extends Ta90Prototype
## DEVELOPMENT ONLY (?extreme90=1): EXTREME Time Attack - a dedicated bank of
## EXTREME puzzles only (docs/extreme90_bank.md). The 90-second hub
## (Ta90Prototype) and page (Ta90TimeAttack) unchanged - the same rules
## (ta90-v1: 90 s, GREEN / ORANGE / RED music, calm after TIME UP, MUSIC
## ON / OFF, UNDO x3, unlimited RESTART, SHOW A MOVE x0, HAMMER x0, optional
## untimed continuation) and the same research questions and export - with:
##   - only the bank's boards, shown as neutral CHALLENGE 1..k;
##   - its own storage ("xb90_*" per board, its own hub key), so the same
##     board keeps separate records here and in ?ta90=1; every record and the
##     export keep the internal board id (N3, N5, ...) and its fingerprint;
##   - no TA reference row.
## ?ta90=1 stays the developer entry for the whole experimental collection
## (N1-N13). Player / QA builds: never opened (BuildFlags.dev_pages_off()).

const BANK_PARAM := "extreme90"
const BANK_STATE_PATH := "user://xb90_hub.json"
const BANK_LS_KEY := "chain_escape_xb90_hub"
## The bank, in the order shown (CHALLENGE k = BANK[k - 1]). N3, N5, N7, N11,
## N13: chosen from the family playtests (N3 the experiential reference);
## N14-N23: the Phase 16 HUMAN-REVIEW CANDIDATES (CHALLENGE 6-15).
const BANK := ["N3", "N5", "N7", "N11", "N13", "N14", "N15", "N16", "N17", "N18", "N19", "N20", "N21", "N22", "N23"]
const BANK_WELCOME := "EXTREME challenges: clear each one in 90 seconds, with music that follows the clock.\n\nPlay one challenge, or more, in any order. Turn the music off any time with the MUSIC button.\n\nAfter each challenge: three quick questions (or tap SKIP).\n\nNo names, no accounts: your answers stay on this phone until you tap COPY ALL RESULTS and send them to us."


static func bank_requested() -> bool:
	if BuildFlags.dev_pages_off():
		return false
	if "--" + BANK_PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(BANK_PARAM + "=1") or where.contains(BANK_PARAM + "=true")


func board_order() -> Array:
	return BANK


func store() -> String:
	return "xb90"


func hub_state_path() -> String:
	return BANK_STATE_PATH


func hub_ls_key() -> String:
	return BANK_LS_KEY


func word() -> String:
	return "CHALLENGE"


func welcome_title() -> String:
	return "EXTREME\nTIME ATTACK"


func welcome_text() -> String:
	return BANK_WELCOME


func select_title() -> String:
	return "CHOOSE A CHALLENGE"


func allows_reference() -> bool:
	return false


func bundle_format() -> String:
	return "ce-xb90"


func publish_name() -> String:
	return "chainEscapeXb90"


## Phase 16A: three questions after each challenge, SKIP for all of them, no
## post-play set (Ta90TimeAttack.SHORT_Q).
func short_questions() -> bool:
	return true


## The export as before, plus each board's mechanics (from its data file) and
## the questionnaire version - the answers stay in each run's
## "timed_answers", apart from the automatic telemetry.
func bundle() -> Dictionary:
	var b := super.bundle()
	b["questionnaire"] = Ta90TimeAttack.SHORT_SET
	for k in b["boards"]:
		var d = JSON.parse_string(FileAccess.get_file_as_string(Ta90TimeAttack.BOARDS90[k]["data"]))
		var mech := []
		if typeof(d) == TYPE_DICTIONARY:
			for rec in d.get("boards", []):
				if str(rec.get("id", "")) == k:
					mech = rec.get("mechanics", [])
		b["boards"][k]["mechanics"] = mech
	return b
