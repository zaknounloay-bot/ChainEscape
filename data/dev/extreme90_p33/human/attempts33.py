"""Phase 33: per-attempt table and group comparison from the engine replay
(replay33.json, written by tools/ta90_replay33.gd from xb33_logs.json).
Every number is MEASURED from the replayed log on the real rules, except where
marked. Descriptive only (n = 7 boards, one player); nothing here is a gate.
  python3 data/dev/extreme90_p33/human/attempts33.py > data/dev/extreme90_p33/human/attempts33.txt
"""
import json, os, statistics as st
D = os.path.dirname(os.path.abspath(__file__))
R = json.load(open(os.path.join(D, "replay33.json")))
HARD = ["N94", "N96", "N99"]; MED = ["N95", "N97", "N98", "N100"]
L = json.load(open(os.path.join(D, "xb33_logs.json")))

def att_rows(k):
    rows = []
    for a in R[k]["attempts"]:
        ev = [e for e in L[k]["log"] if a["start_ms"] <= e[0] <= a["end_ms"] and e[1] == "m"]
        first = (ev[0][0] - a["start_ms"]) / 1000 if ev else None
        lost_in = a["end_ms"] - a["lost_ms"] if a["lost_at_move"] > 0 else 0
        if a["lost_at_move"] > 0 and a["recovered_by_undo"] > 0:
            # lost only until the UNDO that made the board winnable again (replay event text)
            rec_ev = [x for x in a["events"] if "winnable again" in x][0]
            lost_in = int(round(float(rec_ev.split("s ")[0]) * 1000)) - a["lost_ms"]
        rows.append(dict(a=a["n"], dur=(a["end_ms"] - a["start_ms"]) / 1000, end=a["end"], moves=a["moves"], esc=a["escapes"],
            undo=a["undos"], blocked=a["blocked"], cleared=a["cleared_end"], maxc=a["max_cleared"],
            first=first, lost=a["lost_at_move"], lost_t=(a["lost_ms"] - a["start_ms"]) / 1000 if a["lost_at_move"] > 0 else None,
            losing=a["losing_move"], opts=a["lost_options"], depth=a["trap_depth"] if a["lost_at_move"] > 0 else None,
            after=a["after_loss"], lost_s=lost_in / 1000, rec=a["recovered_by_undo"], same=a["same_opening_as_previous"],
            solp=a["solver_prefix"], ch=a["choices"], chw=a["choices_won"], b_lost=a["blocked_after_loss"]))
    return rows

print("Per attempt (measured by replaying the log on the engine; times in s from the attempt's start)")
print("%-5s %-3s %6s %-8s %5s %4s %4s %4s %7s %6s %-38s %-13s %5s %5s %6s %4s %5s %5s" % ("board", "att", "dur", "end", "moves", "esc", "undo", "blkd", "clr/max", "first",
      "first losing move (move no., time)", "legal/winning", "depth", "after", "lost_s", "rec", "same", "choices"))
for k in HARD + MED:
    for r in att_rows(k):
        lm = ("%s (#%d, %.1f s)" % (r["losing"], r["lost"], r["lost_t"])) if r["lost"] > 0 else "never lost"
        print("%-5s %-3s %6.1f %-8s %5d %4d %4d %4d %3d/%-3d %6s %-38s %-13s %5s %5d %6.1f %4d %5d %2d/%-2d" % (k, r["a"], r["dur"], r["end"], r["moves"], r["esc"], r["undo"], r["blocked"],
              r["cleared"], r["maxc"], "%.1f" % r["first"] if r["first"] is not None else "-", lm[:38], r["opts"].replace(" legal, ", "/").replace(" winning", "") or "-",
              r["depth"] if r["depth"] is not None else "-", r["after"], r["lost_s"], r["rec"], r["same"], r["chw"], r["ch"]))
print("columns: depth = longest run of legal moves still possible right after the losing move (how late the loss can show itself);")
print("after = moves the player made in the lost position; lost_s = seconds spent in a lost position before RESTART / the end;")
print("rec = UNDOs that made the board winnable again; same = moves identical to the previous attempt's opening;")
print("choices = consequential choices met on the path (positions with >= 1 winning and >= 1 losing legal move): won/met.")
print()
print("Board-level (measured)")
for k in HARD + MED:
    rows = att_rows(k)
    losers = {}
    for r in rows:
        if r["lost"] > 0:
            losers.setdefault(r["losing"].split(" ")[0], []).append(r["a"])
    sol = R[k]["solution"]
    print("  %-5s %-9s attempts %d; losing decisions %d; repeated losing block %s; trap depth of losses %s; moves in lost positions %s; undo recoveries %d; exact solution %d moves" % (
        k, L[k]["meta"]["rating"], len(rows), sum(1 for r in rows if r["lost"] > 0), {b: v for b, v in losers.items() if len(v) > 1} or "-",
        [r["depth"] for r in rows if r["depth"] is not None], [r["after"] for r in rows if r["lost"] > 0], sum(r["rec"] for r in rows), len(sol)))
print()
def grp(ks, f):
    v = [f(r) for k in ks for r in att_rows(k) if f(r) is not None]
    return v
for name, f in (("trap depth of each losing move", lambda r: r["depth"]),
                ("moves made in a lost position", lambda r: r["after"] if r["lost"] > 0 else None),
                ("seconds in a lost position", lambda r: round(r["lost_s"], 1) if r["lost"] > 0 else None),
                ("winning share at the losing decision", lambda r: round(int(r["opts"].split(" winning")[0].split(", ")[1]) / int(r["opts"].split(" legal")[0]), 2) if r["lost"] > 0 else None),
                ("move number of the first loss", lambda r: r["lost"] if r["lost"] > 0 else None),
                ("time to first move (s)", lambda r: round(r["first"], 1) if r["first"] is not None else None)):
    a, b = grp(HARD, f), grp(MED, f)
    print("  %-38s hard %-34s median %-5s | MEDIUM %-24s median %s" % (name, a, st.median(a) if a else "-", b, st.median(b) if b else "-"))
print()
print("Recording notes (engine-verified, see the report): the solving escape of a completed board is not logged (per-frame")
print("poll ends with the puzzle) -> moves/escapes above include it; rams are logged 'm' but are not 'moves' (escapes only);")
print("first_move_ms counts the first escape, not the first ram; UNDO is per attempt (3, reset on RESTART); unaided_max_cleared")
print("is one below max_cleared on completed boards for the same unlogged-final reason (no SHOW A MOVE exists on this page).")
