"""Phase 33: the consequential choices the player actually met (from replay33.json).
A choice point = a WINNABLE position where at least one legal move wins and at least
one loses. For each, the depth of every losing alternative = the longest run of legal
moves still possible after it (how long the mistake can stay hidden; UNDO is 3, so a
mistake of depth >= 4 can outlast the UNDO budget). MEASURED on the engine; descriptive.
  python3 data/dev/extreme90_p33/human/choices33.py > data/dev/extreme90_p33/human/choices33.txt
"""
import json, os, statistics as st
D = os.path.dirname(os.path.abspath(__file__))
R = json.load(open(os.path.join(D, "replay33.json")))
HARD = ["N94", "N96", "N99"]; MED = ["N95", "N97", "N98", "N100"]
def board(k):
    cps = [c for a in R[k]["attempts"] for c in a["choice_points"]]
    lose_d = [x["depth"] for c in cps for x in c["losing"]]
    chosen_wrong = [c for c in cps if not c["chosen_won"]]
    d_chosen = [[x["depth"] for x in c["losing"] if x["id"] == c["chosen"]][0] for c in chosen_wrong]
    shallow_only = [c for c in cps if all(x["depth"] <= 3 for x in c["losing"])]
    has_hidden = [c for c in cps if any(x["depth"] >= 4 for x in c["losing"])]
    err_hidden = [c for c in chosen_wrong if [x["depth"] for x in c["losing"] if x["id"] == c["chosen"]][0] >= 4]
    return dict(cps=len(cps), lose=len(lose_d), hidden_share=round(sum(d >= 4 for d in lose_d) / max(len(lose_d), 1), 2),
                med_depth=st.median(lose_d) if lose_d else 0, wrong=len(chosen_wrong), d_chosen=d_chosen,
                hidden_pts=len(has_hidden), shallow_pts=len(shallow_only),
                err_rate_hidden=(len(err_hidden), len(has_hidden)),
                err_rate_shallow=(len([c for c in chosen_wrong if c in shallow_only]), len(shallow_only)))
print("Choice points met from winnable positions (all attempts), and the depth of their losing alternatives")
print("%-5s %-9s %7s %8s %12s %10s %8s %18s %26s %26s" % ("board", "rating", "points", "losing", "depth>=4", "med depth", "errors", "depth of errors", "errors at hidden points", "errors at shallow points"))
for k in HARD + MED:
    b = board(k)
    print("%-5s %-9s %7d %8d %12s %10s %8d %18s %20d / %-5d %20d / %-5d" % (k, R[k]["meta"]["rating"], b["cps"], b["lose"], b["hidden_share"], b["med_depth"], b["wrong"],
          b["d_chosen"], b["err_rate_hidden"][0], b["err_rate_hidden"][1], b["err_rate_shallow"][0], b["err_rate_shallow"][1]))
for name, ks in (("hard (N94, N96, N99)", HARD), ("MEDIUM (N95, N97, N98, N100)", MED)):
    bs = [board(k) for k in ks]
    eh = sum(b["err_rate_hidden"][0] for b in bs); nh = sum(b["err_rate_hidden"][1] for b in bs)
    es = sum(b["err_rate_shallow"][0] for b in bs); ns = sum(b["err_rate_shallow"][1] for b in bs)
    print("  %-30s points %d; losing alternatives with depth >= 4: %s; errors where a hidden (>=4) trap was on offer %d/%d = %.2f; where every trap was shallow (<=3) %d/%d" % (
        name, sum(b["cps"] for b in bs), [b["hidden_share"] for b in bs], eh, nh, eh / max(nh, 1), es, ns))
print("Depth = longest legal continuation after the losing move (engine, exhaustive, memoised).")
