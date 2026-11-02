#!/usr/bin/env python3
"""Phase 31: measured record features of N53-N82 joined with first-exposure
human ratings and the generator mode that produced each board. Facts only:
every number is read from data/dev/ta90_nNN.json (design_report) or the
phase human_*.json files; nothing is inferred.
  python3 tools/extreme90_features31.py > data/dev/extreme90_p31/features_n53_n82.json"""
import json, re, sys
HUMAN = {  # first-exposure rating of the project owner (player_1), from data/dev/extreme90_p2x/human_p2x.json and the Phase 31 brief
 "N53":"EXTREME","N54":"MEDIUM","N55":"VERY HARD","N56":"EXTREME","N57":"EASY","N58":"HARD",
 "N59":"EXTREME","N60":"MEDIUM","N61":"VERY HARD","N62":"EXTREME",
 "N63":"MEDIUM","N64":"EXTREME","N65":"EASY","N66":"HARD","N67":"MEDIUM","N68":"EXTREME","N69":"EXTREME","N70":"EASY",
 "N71":"EASY","N72":"EXTREME","N73":"HARD","N74":"MEDIUM","N75":"VERY HARD","N76":"HARD","N77":"EXTREME",
 "N78":"MEDIUM","N79":"MEDIUM","N80":"HARD","N81":"MEDIUM","N82":"VERY HARD"}
GEN = {}  # filled from the run that holds the exact map (see docs/extreme90_phase31.md B)
for n in range(53, 71): GEN["N%d" % n] = "v20"
for n in (73, 74, 75): GEN["N%d" % n] = "v20"
for n in (71, 72, 76, 77, 78, 79, 80, 81, 82): GEN["N%d" % n] = "baseline"
GEN["N58"] = "hand/other"
PHASE = {**{"N%d" % n: 25 for n in range(53, 59)}, **{"N%d" % n: 26 for n in range(59, 62)}, "N62": 27,
         **{"N%d" % n: 28 for n in range(63, 71)}, **{"N%d" % n: 29 for n in range(71, 78)}, **{"N%d" % n: 30 for n in range(78, 83)}}
rows = []
for n in range(53, 83):
    i = "N%d" % n
    b = json.load(open("data/dev/ta90_n%d.json" % n))["boards"][0]
    r = b["design_report"]; A, B, C = r["A"], r["B"], r.get("C", {})
    m = b["puzzle"]["map"]
    toks = [t for row in m for t in row.split() if t != "."]
    pieces = [t for t in toks if t[0] in "RGBYP"]
    lps = B.get("losing_per_step", [])
    op = C.get("opening", "")
    mo = re.match(r"(\d+) / (\d+)", op)
    pr = C.get("pressure", {})
    rows.append({"id": i, "phase": PHASE[i], "generator": GEN[i], "human": HUMAN[i],
        "hard": HUMAN[i] in ("VERY HARD", "EXTREME"),
        "size": "%dx%d" % (b["puzzle"]["cols"], b["puzzle"]["rows"]), "pieces": len(pieces),
        "spinners": sum("@" in t for t in pieces), "crates": toks.count("M"),
        "positions": A["positions"], "winnable": A.get("winnable"), "solution": A["solution"],
        "decision_steps": B["decision_steps"], "distinct": B["distinct_mistakes"],
        "coverage": B["coverage"], "late": B["late"], "shortcut": B["shortcut"],
        "losing_sum": sum(lps), "losing_max": max(lps) if lps else 0, "early3": sum(lps[:3]),
        "opening_losing": int(mo.group(1)) if mo else None, "opening_moves": int(mo.group(2)) if mo else None,
        "deepest": C.get("deepest"), "hidden_k6_8": C.get("hidden_k6_8"), "decisions_k4_6_8": C.get("decisions_k4_6_8"),
        "look6_greedy": C.get("look6_greedy"), "win_share": C.get("win_share"),
        "trap_delay_median": pr.get("trap_delay_median"), "calm_prefix": pr.get("calm_prefix"),
        "undo_proof": pr.get("undo_proof"), "prediction_share": pr.get("prediction_share")})
json.dump(rows, sys.stdout, indent=1)
