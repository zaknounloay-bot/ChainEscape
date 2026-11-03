"""Phase 33 descriptive comparison (N94-N100): recommended/borderline vs MEDIUM, and
arm R (reused owner-approved core) vs arm N (new family core). DESCRIPTIVE ONLY:
n = 7; no rule is fitted, no gate is derived, no causal claim is made.
  python3 data/dev/extreme90_p33/human/compare33.py > data/dev/extreme90_p33/human/compare33.txt
"""
import json, os, statistics as st
P = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
h = json.load(open(os.path.join(P, "human_p33.json")))["boards"]
o = json.load(open(os.path.join(P, "owner_status_n94_n100.json")))["boards"]
sel = json.load(open(os.path.join(P, "selection.json")))
ss = json.load(open(os.path.join(P, "struct_selected.json")))
sa = json.load(open(os.path.join(P, "struct_all.json")))
lab = {b["id"]: b for b in json.load(open(os.path.join(P, "labels.json")))["boards"]}
M = ["positions", "solution", "early3", "open_escape_losing", "p_look2", "strat_steps", "forced",
     "max_forced_run", "trap_depth_median", "delayed", "beyond_undo", "dep_depth", "win_lines", "mean_winning", "mistakes"]
def cls(k):
    s = o[k]["status"]
    return "REC" if s.startswith("RECOMMENDED") else ("BORDER" if s.startswith("BORDERLINE") else "MEDIUM")
print("Phase 33 human results vs arm (owner first exposure, build p33-qa1-20261103)")
print("%-5s %-4s %-14s %-10s %-9s %-7s %-6s sibling (its rating)" % ("id", "arm", "core", "rating", "outcome", "time", "status"))
for k in h:
    s = sel[k]; sib = s.get("approved_sibling")
    sr = (sib + " " + "/".join(lab[sib]["ratings"])) if sib else "-"
    print("%-5s %-4s %-14s %-10s %-9s %-7s %-6s %s" % (k, s["arm"], s["core"].split("_")[0], h[k]["difficulty"], h[k]["outcome_90s"],
          h[k]["solve_time_s"] if isinstance(h[k]["solve_time_s"], float) else "-", cls(k), sr))
print()
for arm in ("R", "N"):
    ks = [k for k in h if sel[k]["arm"] == arm]
    print("arm %s: %d boards; recommended %d (%s); borderline %d; MEDIUM/not approved %d; EXTREME-rated %d; EXTREME or VERY HARD %d" % (
        arm, len(ks), sum(cls(k) == "REC" for k in ks), ", ".join(k for k in ks if cls(k) == "REC") or "-",
        sum(cls(k) == "BORDER" for k in ks), sum(cls(k) == "MEDIUM" for k in ks),
        sum(h[k]["difficulty"] == "EXTREME" for k in ks), sum(h[k]["difficulty"] in ("EXTREME", "VERY HARD") for k in ks)))
print()
print("Play counts (summary of the owner's COPY ALL RESULTS JSON; the action logs are NOT in this session)")
print("%-5s %-10s %-9s %8s %8s %5s %6s %9s %12s" % ("id", "rating", "outcome", "attempts", "restarts", "undo", "moves", "solution", "moves-sol"))
for k in h:
    b = h[k]; sol = ss[sel[k]["key"]]["solution"]
    print("%-5s %-10s %-9s %8s %8s %5s %6s %9s %12s" % (k, b["difficulty"], b["outcome_90s"], b["attempts"], b["restarts"], b["undo_used"], b["moves"], sol, b["moves"] - sol))
for g, f in (("REC+BORDER (N94, N96, N99)", lambda k: cls(k) != "MEDIUM"), ("MEDIUM (N95, N97, N98, N100)", lambda k: cls(k) == "MEDIUM")):
    ks = [k for k in h if f(k)]
    print("  %-30s attempts %s; restarts %s; undo %s; moves %s (median %s); moves/attempt median %.2f" % (g,
        [h[k]["attempts"] for k in ks], [h[k]["restarts"] for k in ks], [h[k]["undo_used"] for k in ks],
        [h[k]["moves"] for k in ks], st.median([h[k]["moves"] for k in ks]), st.median([h[k]["moves"] / h[k]["attempts"] for k in ks])))
print("  'moves-sol' is plain arithmetic (total moves minus the solution length), NOT a per-attempt split:")
print("  how the moves fell across attempts is in the action logs, which are not available here.")
print()
print("Structure (tools/ta90_struct33.gd, exact solver; recorded BEFORE human play)")
print("%-20s" % "measure" + "".join("%9s" % k for k in h) + "   med REC+BORDER  med MEDIUM")
for m in M:
    row = {k: ss[sel[k]["key"]].get(m) for k in h}
    a = [row[k] for k in h if cls(k) != "MEDIUM"]; b = [row[k] for k in h if cls(k) == "MEDIUM"]
    f = lambda v: ("%9.3g" % v) if isinstance(v, float) else "%9s" % v
    print("%-20s" % m + "".join(f(row[k]) for k in h) + "   %10.3g  %10.3g" % (st.median(a), st.median(b)))
print()
print("Reused cores: the child vs its owner-approved sibling (sibling measures from struct_all.json)")
for k in h:
    sib = sel[k].get("approved_sibling")
    if not sib: continue
    c = ss[sel[k]["key"]]; p = sa.get(sib, {})
    print("  %s (%s) <- %s (%s): overlap %.2f; positions %s vs %s; solution %s vs %s; early3 %s vs %s; strat_steps %s vs %s" % (
        k, h[k]["difficulty"], sib, "/".join(lab[sib]["ratings"]), sel[k]["overlap_to_sibling"],
        c["positions"], p.get("positions"), c["solution"], p.get("solution"), c["early3"], p.get("early3"), c["strat_steps"], p.get("strat_steps")))
print()
print("Caveat: 7 boards, one tester's first exposure, one round. Medians above are descriptive;")
print("no threshold is fitted and nothing here is a gate. Arm membership was assigned by the")
print("pre-registered protocol, but concept quality, mechanics and seeds also differ between arms.")
