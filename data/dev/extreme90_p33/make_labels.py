#!/usr/bin/env python3
"""Phase 33: one label table for N1-N93, OWNER DECISION kept separate from the
HUMAN DIFFICULTY RATING. Facts only, each with its source file; nothing inferred.
  python3 data/dev/extreme90_p33/make_labels.py > data/dev/extreme90_p33/labels.json

owner:   APPROVED | NOT_APPROVED (downgraded, archived or explicitly not approved)
         | PROVISIONAL (strong / provisional / promising, never decided) | PENDING (N82)
         | BORDERLINE (N66: borderline, not owner-approved)
ratings: the recorded human difficulty ratings (owner's first exposure first when known);
         [] = no rating recorded in any rating file.
study:   +1 approved, -1 human-rated and not approved, 0 = excluded from the binary study
         (provisional, pending, borderline, or not approved without any recorded rating).
"""
import json, re

D = "data/dev/"
def J(p): return json.load(open(D + p))

PHASE = {}
for lo, hi, p in [(1, 3, 14), (4, 13, 15), (14, 23, 16), (24, 30, 17), (31, 34, 18), (35, 36, 19), (37, 38, 20),
                  (39, 47, 21), (48, 51, 22), (52, 52, 24), (53, 58, 25), (59, 61, 26), (62, 62, 27), (63, 70, 28),
                  (71, 77, 29), (78, 82, 30), (83, 87, 31), (88, 93, 32)]:
    for n in range(lo, hi + 1): PHASE["N%d" % n] = p

st = J("extreme90_bank_status.json")
owner, osrc = {}, {}
for k, tag in [("owner_approved", "APPROVED"), ("downgraded_or_archived", "NOT_APPROVED"),
               ("strong_provisional", "PROVISIONAL"), ("provisional", "PROVISIONAL"),
               ("borderline_not_approved", "BORDERLINE")]:
    for n in st[k]:
        owner[n], osrc[n] = tag, "extreme90_bank_status.json:" + k
# after the manifest (updated 2026-10-31, Phase 29 decisions)
for n in ["N78", "N79", "N80", "N81"]:
    owner[n], osrc[n] = "NOT_APPROVED", "never approved; Phase 31 brief rated them (features_n53_n82.json); exported as tested_no_decision"
owner["N82"], osrc["N82"] = "PENDING", "extreme90_p31/owner_decisions_n83_n87.json:pending"
p31 = J("extreme90_p31/owner_decisions_n83_n87.json")
for n in p31["approved_by_owner"]: owner[n], osrc[n] = "APPROVED", "extreme90_p31/owner_decisions_n83_n87.json"
for n in p31["not_approved"]: owner[n], osrc[n] = "NOT_APPROVED", "extreme90_p31/owner_decisions_n83_n87.json"
p32 = J("extreme90_p32/owner_decisions_n88_n93.json")
for n, v in p32["boards"].items():
    owner[n], osrc[n] = "NOT_APPROVED", "extreme90_p32/owner_decisions_n88_n93.json"

ratings, rsrc = {}, {}
for n, v in J("extreme90_p23/human_ratings.json")["ratings"].items():
    ratings[n], rsrc[n] = list(v), "extreme90_p23/human_ratings.json"
for n, v in J("extreme90_p21/human_p21.json")["boards"].items():
    if "rated" in v and n not in ratings: ratings[n], rsrc[n] = [v["rated"]], "extreme90_p21/human_p21.json"
for row in J("extreme90_p31/features_n53_n82.json"):
    ratings[row["id"]], rsrc[row["id"]] = [row["human"]], "extreme90_p31/features_n53_n82.json (owner first exposure)"
for n, v in J("extreme90_p31/human_p31.json")["boards"].items():
    ratings[n], rsrc[n] = [v["difficulty"]], "extreme90_p31/human_p31.json"
for n, v in p32["boards"].items():
    ratings[n], rsrc[n] = [v["difficulty"]], "extreme90_p32/owner_decisions_n88_n93.json"
ratings.setdefault("N52", ["EXTREME"]); rsrc.setdefault("N52", "extreme90_p25 report: recorded EXTREME rating (docs/extreme90_phase25.md K)")

rows = []
for n in sorted(PHASE, key=lambda x: int(x[1:])):
    o = owner.get(n, "UNKNOWN")
    r = ratings.get(n, [])
    study = 1 if o == "APPROVED" else (-1 if o == "NOT_APPROVED" and r else 0)
    rows.append({"id": n, "phase": PHASE[n], "owner": o, "owner_source": osrc.get(n, "none"),
                 "ratings": r, "rating_source": rsrc.get(n, "none recorded"), "study": study})
c = {}
for x in rows: c[x["owner"]] = c.get(x["owner"], 0) + 1
out = {"note": __doc__.strip(), "counts": c,
       "study_counts": {"positive": sum(x["study"] == 1 for x in rows), "negative": sum(x["study"] == -1 for x in rows),
                        "excluded": sum(x["study"] == 0 for x in rows)},
       "boards": rows}
assert c.get("APPROVED") == 38, c
print(json.dumps(out, indent=1))
