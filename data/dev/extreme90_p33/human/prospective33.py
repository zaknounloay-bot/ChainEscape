"""Phase 33 PROVISIONAL prospective check of the pre-specified predictors on N94-N100.
Thresholds are fitted exactly as tools/extreme90_val33.py does, on ALL study boards of
phases <= 32 (nothing from Phase 33), then applied unchanged. The outcome is a RATING
PROXY, not the study label: owner approval is not confirmed for any Phase 33 board, so
'+' = recommended for approval (N94, N99), '-' = MEDIUM and not approved (N95, N97, N98,
N100); N96 (borderline) excluded. Advisory only; no gate.
  python3 data/dev/extreme90_p33/human/prospective33.py > data/dev/extreme90_p33/human/prospective33.txt
"""
import json, os, sys, types
R = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))))
P = os.path.join(R, "data/dev/extreme90_p33")
src = open(os.path.join(R, "tools/extreme90_val33.py")).read().split("out = {")[0]
sys.argv = ["x", os.path.join(P, "labels.json"), os.path.join(P, "struct_all.json")]
m = types.ModuleType("v"); exec(src, m.__dict__)
o = json.load(open(os.path.join(P, "owner_status_n94_n100.json")))["boards"]
sel = json.load(open(os.path.join(P, "selection.json")))
ss = json.load(open(os.path.join(P, "struct_selected.json")))
def y(k):
    s = o[k]["status"]
    return 1 if s.startswith("RECOMMENDED") else (0 if s.startswith("BORDERLINE") else -1)
test = []
for k in o:
    s = ss[sel[k]["key"]]
    f = {"P1_positions": s["positions"], "P2_early3": s["early3"], "P3_open_tempting": s["open_escape_losing"],
         "P4_p_look2": s.get("p_look2"), "P5_strat_steps": s["strat_steps"],
         "P6_forced_share": round(s["forced"] / max(s["solution"], 1), 3)}
    test.append({"id": k, "y": y(k), "f": f})
print("train: %d study boards of phases <= 32 (%d approved, %d not)" % (len(m.rows), sum(r['study'] == 1 for r in m.rows), sum(r['study'] == -1 for r in m.rows)))
print("test (rating proxy): + %s | - %s | excluded %s" % (
    [t["id"] for t in test if t["y"] == 1], [t["id"] for t in test if t["y"] == -1], [t["id"] for t in test if t["y"] == 0]))
for k in list(m.LOWER) + ["P7_positions_and_early3"]:
    if k == "P7_positions_and_early3":
        t1, t2 = m.fit(m.rows, "P1_positions"), m.fit(m.rows, "P2_early3")
        pr = lambda f: f["P1_positions"] <= t1 and f["P2_early3"] <= t2; thr = [t1, t2]
    else:
        thr = m.fit(m.rows, k); low = m.LOWER[k]
        pr = lambda f, thr=thr, low=low, k=k: m.pred(f[k], thr, low)
    ev = [t for t in test if t["y"] != 0]
    tp = sum(1 for t in ev if t["y"] == 1 and pr(t["f"])); fn = sum(1 for t in ev if t["y"] == 1 and not pr(t["f"]))
    tn = sum(1 for t in ev if t["y"] == -1 and not pr(t["f"])); fp = sum(1 for t in ev if t["y"] == -1 and pr(t["f"]))
    print("%-24s thr %-10s predicted+ %-28s correct %d/6 (TP %d FP %d FN %d TN %d)  N96 predicted %s" % (
        k, thr, [t["id"] for t in test if pr(t["f"])], tp + tn, tp, fp, fn, tn, "+" if pr(test[2]["f"]) else "-"))
print("baselines: always + 2/6, always - 4/6")
