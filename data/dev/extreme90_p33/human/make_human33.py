"""Phase 33 human results (N94-N100), recorded verbatim from the project owner's
'PHASE 33 HUMAN RESULTS' message (2026-11-03). Ratings and owner decisions are kept
in separate files. Nothing inferred: fields the owner did not supply stay 'not supplied'.
  python3 data/dev/extreme90_p33/human/make_human33.py
"""
import json, os
D = os.path.dirname(os.path.abspath(__file__))
P = os.path.dirname(D)
fp = json.load(open(os.path.join(P, "fingerprints.json")))
sel = json.load(open(os.path.join(P, "selection.json")))
NS = "not supplied"
# Exactly as supplied. First message: rating, outcome, solve time (completed), enjoyment.
# Data correction (same day): the owner's COPY ALL RESULTS JSON summary: attempts, restarts,
# Undo, moves. (difficulty, outcome, attempts, restarts, undo, moves, solve_time_s, enjoyment)
H = {
    "N94": ("EXTREME", "TIME UP", 4, 3, 4, 32, None, "5/5"),
    "N95": ("MEDIUM", "COMPLETED", 2, 1, 0, 18, 31.2, "5/5"),
    "N96": ("VERY HARD", "TIME UP", 4, 3, 1, 35, None, "5/5"),
    "N97": ("MEDIUM", "COMPLETED", 2, 1, 0, 22, 40.5, "5/5"),
    "N98": ("MEDIUM", "COMPLETED", 2, 1, 0, 19, 36.3, "5/5"),
    "N99": ("EXTREME", "TIME UP", 4, 3, 0, 31, None, "5/5"),
    "N100": ("MEDIUM", "COMPLETED", 1, 0, 1, 18, 23.6, "5/5"),
}
EXPORT = ("data/dev/extreme90_p33/human/xb33_logs.json (the owner's compact transcription of the export, "
          "every event validated on the engine: tools/ta90_replay33.gd -> replay33.txt)")
LOGS = json.load(open(os.path.join(D, "xb33_logs.json")))
human = {"source": "Project owner, 2026-11-03: (1) Phase 33 human results message (rating, outcome, "
         "completion time, enjoyment); (2) Phase 33 data correction: the summary of the owner's complete "
         "COPY ALL RESULTS JSON for N94-N100 (attempts, restarts, Undo, moves, outcome, rating), first "
         "exposure of ?extreme90p33=1 (build p33-qa1-20261103). Recorded verbatim; nothing inferred. The "
         "export file itself is not in the repository; its seven timed runs, action logs included, were "
         "supplied as a faithful compact transcription (xb33_logs_transcription.txt / xb33_logs.json: session "
         "a3f8534565e75f12, questionnaire xb90-short-v1, EXPERIENCED PLAYER) and every event was validated "
         "on the engine (replay33.txt: 49/49 checks).",
         "recorded": "2026-11-03", "build": "p33-qa1-20261103",
         "export": {"supplied_by_owner": True, "available_in_session": "as a compact transcription (validated)",
                    "summary_fields_recorded": ["attempts", "restarts", "undo", "moves", "outcome", "difficulty"]},
         "boards": {}}
for k, (d, o, a, r, u, mv, t, e) in H.items():
    human["boards"][k] = {
        "difficulty": d, "outcome_90s": o, "attempts": a, "restarts": r, "undo_used": u, "moves": mv,
        "solve_time_s": t if t is not None else "TIME UP (no completion at 90 s)",
        "enjoyment": e, "action_log": EXPORT, "per_attempt_timing": "replay33.json / attempts33.txt (measured)",
        "show_a_move": "0 available (TA90 rule); 0 presses", "hammer": 0, "interrupted": False, "another": "YES",
        "blocked_taps": int(LOGS[k]["meta"]["blocked"]), "first_move_ms": int(LOGS[k]["meta"]["first_move"]),
        "longest_pause_ms": int(LOGS[k]["meta"]["longest_pause"]) if "longest_pause" in LOGS[k]["meta"] else "in the export (not transcribed)",
        "max_cleared": int(LOGS[k]["meta"]["max_cleared"]),
        "fingerprint": fp[k], "source_board": sel[k]["key"], "core": sel[k]["core"],
        "arm": sel[k]["arm"]}
owner = {"source": "Phase 33 human results message (project owner), OWNER DECISION STATUS section. "
         "Stored apart from the difficulty ratings. Recommendations are NOT approvals: the approved bank "
         "stays 38/50 until the owner explicitly confirms.",
         "recorded": "2026-11-03", "approved_bank": "38/50 (unchanged)", "boards": {
    "N94": {"decision": "NONE YET", "status": "RECOMMENDED FOR APPROVAL - NOT CONFIRMED BY OWNER"},
    "N99": {"decision": "NONE YET", "status": "RECOMMENDED FOR APPROVAL - NOT CONFIRMED BY OWNER"},
    "N96": {"decision": "NONE YET", "status": "BORDERLINE - REQUIRES OWNER JUDGMENT"},
    "N95": {"decision": "NOT APPROVED", "status": "DOWNGRADED (MEDIUM)"},
    "N97": {"decision": "NOT APPROVED", "status": "DOWNGRADED (MEDIUM)"},
    "N98": {"decision": "NOT APPROVED", "status": "DOWNGRADED (MEDIUM)"},
    "N100": {"decision": "NOT APPROVED", "status": "DOWNGRADED (MEDIUM)"}}}
for k in owner["boards"]:
    owner["boards"][k]["fingerprint"] = fp[k]
json.dump(human, open(os.path.join(P, "human_p33.json"), "w"), indent=1)
json.dump(owner, open(os.path.join(P, "owner_status_n94_n100.json"), "w"), indent=1)
print("wrote human_p33.json, owner_status_n94_n100.json")

# Board records and selection.json: the Phase 32 precedent (ta90_n88..n93): human_test
# filled from human_p33.json; owner_decision only where the owner decided (NOT APPROVED);
# recommendations / borderline are a status, never an owner_decision. The page does not
# read these fields (labels are not shown), so the tested build is unaffected.
LABEL = {"NOT APPROVED": "TECHNICALLY QUALIFIED - HUMAN TESTED, NOT APPROVED",
         "RECOMMENDED": "TECHNICALLY QUALIFIED - HUMAN TESTED, RECOMMENDED FOR APPROVAL (NOT OWNER-CONFIRMED)",
         "BORDERLINE": "TECHNICALLY QUALIFIED - HUMAN TESTED, BORDERLINE (OWNER JUDGMENT PENDING)"}
R = os.path.dirname(P)
for k, hb in human["boards"].items():
    ob = owner["boards"][k]
    ht = {"status": "TESTED (owner first exposure, Phase 33 page)", "difficulty": hb["difficulty"],
          "enjoyment": hb["enjoyment"], "outcome_90s": hb["outcome_90s"],
          "solve_time_ms": int(round(hb["solve_time_s"] * 1000)) if isinstance(hb["solve_time_s"], float) else "TIME UP (no completion)",
          "attempts": hb["attempts"], "restarts": hb["restarts"], "undo_used": hb["undo_used"], "moves": hb["moves"],
          "action_log": hb["action_log"], "blocked_taps": hb["blocked_taps"], "notes": "owner's COPY ALL RESULTS export (validated transcription)",
          "owner_status": ob["status"], "file": "data/dev/extreme90_p33/human_p33.json"}
    path = os.path.join(R, "ta90_%s.json" % k.lower())
    rec = json.load(open(path)); b = rec["boards"][0]
    assert b["fingerprint"] == hb["fingerprint"] == fp[k]
    b["human_test"] = ht
    if ob["decision"] == "NOT APPROVED":
        b["label"] = LABEL["NOT APPROVED"]
        b["owner_decision"] = {"decision": "NOT APPROVED", "recorded": "2026-11-03",
                               "file": "data/dev/extreme90_p33/owner_status_n94_n100.json"}
    else:
        b["label"] = LABEL["RECOMMENDED" if ob["status"].startswith("RECOMMENDED") else "BORDERLINE"]
        b.pop("owner_decision", None)
    json.dump(rec, open(path, "w"), indent=1)
    sel[k]["human_test"] = dict(ht, owner_decision=ob["decision"])
json.dump(sel, open(os.path.join(P, "selection.json"), "w"), indent=1)
print("updated records ta90_n94..n100 and selection.json")
