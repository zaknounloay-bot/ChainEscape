#!/usr/bin/env python3
"""Phase 33: chronological holdout validation of the pre-specified approval
predictors (data/dev/extreme90_p33/protocol.json). Advisory analysis only.
  python3 tools/extreme90_val33.py labels.json struct_all.json > validation.json
Rolling origin: for each test phase t in 25..32 a single threshold per rule is
fitted only on boards of phases < t (maximum balanced accuracy, ties -> the
lenient threshold), then applied unchanged to phase t."""
import json, sys

lab = json.load(open(sys.argv[1]))["boards"]
st = json.load(open(sys.argv[2]))

def feat(i):
    s = st[i]
    return {"P1_positions": s["positions"], "P2_early3": s["early3"], "P3_open_tempting": s["open_escape_losing"],
            "P4_p_look2": s.get("p_look2"), "P5_strat_steps": s["strat_steps"],
            "P6_forced_share": round(s["forced"] / max(s["solution"], 1), 3)}

LOWER = {"P1_positions": True, "P2_early3": True, "P3_open_tempting": True, "P4_p_look2": True,
         "P5_strat_steps": False, "P6_forced_share": False}
rows = [dict(x, f=feat(x["id"])) for x in lab if x["study"] != 0 and x["id"] in st]

def pred(v, thr, low): return v <= thr if low else v >= thr

def bal(rs, k, thr, low):
    tp = sum(1 for r in rs if r["study"] == 1 and pred(r["f"][k], thr, low))
    fn = sum(1 for r in rs if r["study"] == 1 and not pred(r["f"][k], thr, low))
    tn = sum(1 for r in rs if r["study"] == -1 and not pred(r["f"][k], thr, low))
    fp = sum(1 for r in rs if r["study"] == -1 and pred(r["f"][k], thr, low))
    P, N = tp + fn, tn + fp
    b = ((tp / P if P else 0) + (tn / N if N else 0)) / (2 if P and N else 1)
    return b, tp, fp, fn, tn

def fit(rs, k):
    low = LOWER[k]
    vals = sorted(set(r["f"][k] for r in rs if r["f"][k] is not None))
    best = None
    for t in vals:
        b = bal(rs, k, t, low)[0]
        lenient = t if low else -t
        key = (round(b, 9), lenient)
        if best is None or key > best[0]:
            best = (key, t)
    return best[1]

def auc(rs, k):
    low = LOWER[k]
    pos = [r["f"][k] for r in rs if r["study"] == 1]
    neg = [r["f"][k] for r in rs if r["study"] == -1]
    if not pos or not neg: return None
    s = 0.0
    for a in pos:
        for b in neg:
            if a == b: s += 0.5
            elif (a < b) == low: s += 1
    return round(s / (len(pos) * len(neg)), 3)

out = {"n_study": len(rows), "positives": sum(r["study"] == 1 for r in rows),
       "negatives": sum(r["study"] == -1 for r in rows), "rules": {}}
rules = list(LOWER) + ["P7_positions_and_early3"]
for k in rules:
    per = []
    tot = [0, 0, 0, 0]
    hold = []
    for t in range(25, 33):
        tr = [r for r in rows if r["phase"] < t]
        te = [r for r in rows if r["phase"] == t]
        if not te: continue
        if k == "P7_positions_and_early3":
            t1, t2 = fit(tr, "P1_positions"), fit(tr, "P2_early3")
            pr = lambda r: r["f"]["P1_positions"] <= t1 and r["f"]["P2_early3"] <= t2
            thr = [t1, t2]
        else:
            thr = fit(tr, k)
            pr = lambda r, thr=thr: pred(r["f"][k], thr, LOWER[k])
        c = [0, 0, 0, 0]  # tp fp fn tn
        for r in te:
            p = pr(r)
            c[0] += p and r["study"] == 1; c[1] += p and r["study"] == -1
            c[2] += (not p) and r["study"] == 1; c[3] += (not p) and r["study"] == -1
            hold.append(r)
        tot = [a + b for a, b in zip(tot, c)]
        per.append({"test_phase": t, "train_n": len(tr), "threshold": thr, "n": len(te),
                    "tp": c[0], "fp": c[1], "fn": c[2], "tn": c[3], "correct": c[0] + c[3],
                    "ids": [r["id"] + ("+" if r["study"] == 1 else "-") for r in te]})
    P, N = tot[0] + tot[2], tot[1] + tot[3]
    res = {"per_phase": per, "pooled": {"n": P + N, "tp": tot[0], "fp": tot[1], "fn": tot[2], "tn": tot[3],
           "correct": tot[0] + tot[3], "accuracy": round((tot[0] + tot[3]) / (P + N), 3),
           "balanced_accuracy": round(((tot[0] / P if P else 0) + (tot[3] / N if N else 0)) / 2, 3),
           "precision": round(tot[0] / (tot[0] + tot[1]), 3) if tot[0] + tot[1] else None}}
    if k != "P7_positions_and_early3":
        res["auc_all_rated"] = auc(rows, k)
        res["auc_holdout_p25_32"] = auc([r for r in rows if r["phase"] >= 25], k)
        res["auc_p31_32"] = auc([r for r in rows if r["phase"] >= 31], k)
    out["rules"][k] = res
P = sum(1 for r in rows if r["phase"] >= 25 and r["study"] == 1)
N = sum(1 for r in rows if r["phase"] >= 25 and r["study"] == -1)
out["baselines_p25_32"] = {"always_approved": {"correct": P, "n": P + N, "balanced_accuracy": 0.5},
                           "always_not_approved": {"correct": N, "n": P + N, "balanced_accuracy": 0.5}}
out["table"] = [{"id": r["id"], "phase": r["phase"], "study": r["study"], "ratings": r["ratings"], **r["f"]} for r in rows]
print(json.dumps(out, indent=1))
