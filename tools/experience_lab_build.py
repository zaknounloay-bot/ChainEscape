#!/usr/bin/env python3
"""PLAYER EXPERIENCE LAB 1-100: builds data/dev/experience_lab/ from its
sources (developer content, never production):

  * Levels 1-10: the human-approved Opening Lab (data/dev/opening_lab/).
  * Levels 11-100: production boards (levels/level_NN.json, read only) in the
    order of docs/progression_reflow_11_25.md and the minimum-intervention map
    of docs/progression_audit_1_100.md, with the token adaptations, renames
    and the two new boards (16, 20) listed below.

Writes level_01..level_100.json and manifest.json (source + edits of every
level). Every edit asserts the exact original token, so a changed source can
never be adapted silently. Run from the repository root:

  python3 tools/experience_lab_build.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "dev", "experience_lab")

# Lab level -> source. ("lab", n) = Opening Lab n; ("prod", n) = production n;
# ("new", key) = a new board defined below.
SOURCES = {n: ("lab", n) for n in range(1, 11)}
SOURCES.update({
    11: ("prod", 13), 12: ("prod", 14), 13: ("prod", 16), 14: ("prod", 18), 15: ("prod", 15),
    16: ("new", "key_turn"), 17: ("prod", 20), 18: ("prod", 19), 19: ("prod", 22), 20: ("new", "secret_key"),
    21: ("prod", 17), 22: ("prod", 21), 23: ("prod", 24), 24: ("prod", 23), 25: ("prod", 25),
    26: ("prod", 26), 27: ("prod", 41), 28: ("prod", 28), 29: ("prod", 36), 30: ("prod", 30),
    31: ("prod", 31), 32: ("prod", 32), 33: ("prod", 33), 34: ("prod", 34), 35: ("prod", 27),
    36: ("prod", 38), 37: ("prod", 37), 38: ("prod", 29), 39: ("prod", 39), 40: ("prod", 40),
    41: ("prod", 35), 42: ("prod", 42), 43: ("prod", 43), 44: ("prod", 44), 45: ("prod", 45),
    46: ("prod", 46), 47: ("prod", 47), 48: ("prod", 48), 49: ("prod", 49), 50: ("prod", 50),
    51: ("prod", 52), 52: ("prod", 51),
})
SOURCES.update({n: ("prod", n) for n in range(53, 101)})

# Token adaptations: lab level -> [(column, row, expected old token, new token, why)].
# Map tokens: colour + arrow, then "@" spinner ("" cw, "-" ccw, "~" alternating,
# "*" pattern), "?" hidden, "#X" locked by colour X, "$S"/"$G" reward.
EDITS = {
    28: [(4, 2, "P^", "P^@", "one arrow becomes a clockwise spinner: a lock breather that is no longer a pure-lock step back")],
    32: [(4, 2, "Gv", "Gv@-", "one arrow becomes a counter-clockwise spinner: first CCW application, still a breather")],
    33: [(2, 3, "R^@", "R^@-", "one clockwise spinner becomes counter-clockwise (its turns are on the solution path)")],
    41: [(2, 0, "R<@~", "R<@", "the top-row Alternating spinner could only ever turn once (it never alternated): it becomes clockwise"),
         (2, 3, "Bv@", "Bv@~", "the Alternating rule moves to this spinner: on every winning path it turns clockwise, then counter-clockwise (back down), and only then can it leave"),
         (4, 2, "Pv@", "P<@", "removes an inherited deep dead end (tapping the blue edge arrow first lost the level 11-13 moves later); this clockwise spinner now turns clockwise twice, a contrast to the Alternating one")],
    42: [(3, 0, "Bv@", "Bv@~", "one clockwise spinner becomes alternating (it can reach its second, opposite turn)")],
    43: [(2, 1, "P<$S", "P<@~$S", "one arrow becomes an alternating spinner (no existing spinner here can ever make a second turn, so a spinner conversion would be cosmetic)")],
    50: [(5, 4, "Yv", "Yv@~", "one arrow becomes an alternating spinner whose second, opposite turn is on the solution path: the Chapter 5 showcase")],
    53: [(3, 1, "G>@", "G>@*", "one clockwise spinner becomes a pattern spinner; its third (left) turn is on the solution path")],
    56: [(2, 5, "Bv@", "Bv@*", "one clockwise spinner becomes a pattern spinner; its third (left) turn is on the solution path (replaces the planned 55: no spinner or arrow there can ever make a third turn)")],
    57: [(1, 3, "G^", "G^@*", "one arrow becomes a pattern spinner (no existing spinner here can make a third turn)")],
}

# Lab-only names (production names are untouched).
RENAMES = {
    24: ("Clockwork", "Cogwheels", "Lab 10 is already \"Clockwork\""),
    49: ("Long Way Round", "Detour", "Lab 5 is already \"Long Way Round\""),
}

# Lab-only hint text (production hints are untouched). Lab 13: "its color"
# read as the locked block's own colour; the rule is about the LOCK's
# (key) colour. The guided lock lesson teaches it on the board; this line
# is the reminder on replays.
HINTS = {
    41: ("Dots show a spinner's rule: this one alternates",
         "This spinner alternates: watch its bold arrow",
         "the lab draws Alternating as a two-way ring, not dots; the level itself now shows the alternation"),
    13: ("A lock opens when all blocks of its color are gone",
         "A lock opens when every block of the LOCK's color is gone",
         "\"its color\" read as the locked block's own colour; the rule is about the lock's key colour"),
}

# The two new boards (docs/player_experience_lab_1_100.md).
NEW = {
    "key_turn": {
        "name": "Key Turn",
        "map": [
            ".  .  Y> .  .",
            "G> Pv R<@ . Pv",
            "Yv Gv B< .  .",
            "G> .  .  .  Bv#R",
            "Yv .  .  .  .",
        ],
    },
    "secret_key": {
        "name": "Secret Key",
        "mystery": True,
        "map": [
            ".   .    G^? P<  .",
            "Pv  B<   B<? Y<  .",
            "Yv  R>#G .   Y^  .",
            "Y>  .    .   .   B>",
            "Pv? R^#G .   .   P^",
        ],
    },
}

ORDER = ["name", "mystery", "hint", "hint_finger", "blocked_hint", "hearts", "hints", "stars", "map"]


def fmt(rows):
    grid = [r.split() for r in rows]
    w = max(len(t) for r in grid for t in r) + 1
    return ["".join(t.ljust(w) for t in r).rstrip() for r in grid]


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = []
    names = {}
    for n in range(1, 101):
        kind, src = SOURCES[n]
        if kind == "lab":
            path = os.path.join(ROOT, "data", "dev", "opening_lab", "level_%02d.json" % src)
            data = json.load(open(path))
            source = "Opening Lab %d" % src
        elif kind == "prod":
            path = os.path.join(ROOT, "levels", "level_%02d.json" % src)
            data = json.load(open(path))
            source = "production P%d" % src
        else:
            data = json.loads(json.dumps(NEW[src]))
            source = "NEW (%s)" % src
        grid = [r.split() for r in data["map"]]
        edits = []
        for (c, r, old, new, why) in EDITS.get(n, []):
            if grid[r][c] != old:
                sys.exit("L%d: expected %r at (%d,%d), found %r" % (n, old, c, r, grid[r][c]))
            grid[r][c] = new
            edits.append({"cell": [c, r], "from": old, "to": new, "why": why})
        rename = None
        if n in RENAMES:
            old_name, new_name, why = RENAMES[n]
            if data["name"] != old_name:
                sys.exit("L%d: expected name %r, found %r" % (n, old_name, data["name"]))
            data["name"] = new_name
            rename = {"from": old_name, "to": new_name, "why": why}
        hint = None
        if n in HINTS:
            old_hint, new_hint, why = HINTS[n]
            if data.get("hint") != old_hint:
                sys.exit("L%d: expected hint %r, found %r" % (n, old_hint, data.get("hint")))
            data["hint"] = new_hint
            hint = {"from": old_hint, "to": new_hint, "why": why}
        if data["name"] in names:
            sys.exit("duplicate name %r at L%d and L%d" % (data["name"], names[data["name"]], n))
        names[data["name"]] = n
        data["map"] = fmt([" ".join(r) for r in grid])
        out = {k: data[k] for k in ORDER if k in data}
        for k in data:
            if k not in out:
                out[k] = data[k]
        with open(os.path.join(OUT, "level_%02d.json" % n), "w") as f:
            json.dump(out, f, indent="\t", ensure_ascii=False)
            f.write("\n")
        manifest.append({"level": n, "name": data["name"], "source": source,
                         "moved_from": src if kind == "prod" and src != n else None,
                         "edits": edits, "rename": rename, "hint": hint})
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump({"_comment": "Player Experience Lab 1-100: source of every lab level (tools/experience_lab_build.py).",
                   "levels": manifest}, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    extra = [p for p in os.listdir(OUT) if p.startswith("level_") and p not in {"level_%02d.json" % n for n in range(1, 101)}]
    if extra:
        sys.exit("unexpected files: %s" % extra)
    print("wrote 100 levels + manifest to %s" % OUT)


if __name__ == "__main__":
    main()
