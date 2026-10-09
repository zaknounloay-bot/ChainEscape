#!/usr/bin/env python3
"""PLAYER EXPERIENCE LAB 1-200: builds data/dev/experience_lab/ from its
sources (developer content, never production):

  * Levels 1-10: the human-approved Opening Lab (data/dev/opening_lab/).
  * Levels 11-100: production boards (levels/level_NN.json, read only) in the
    order of docs/progression_reflow_11_25.md and the minimum-intervention map
    of docs/progression_audit_1_100.md, with the token adaptations, renames
    and the two new boards (16, 20) listed below.
  * Levels 101-200: the Second Era. 101 and 106-200 are production boards
    (111-120 Switch application, 121-130 Chain Gate, 131-150 Switch + Gate;
    131 keeps its board with a corrected hint). 151-170 interleave the
    production Switch levels 151-160 and Armor levels 161-170 so Armor
    starts at 151 (151 = production 161 with one token adapted);
    102-105 are the lab's Switch learning ramp (102, 103, 105 adapted
    production boards, 104 a new board "now or later").
  * Levels 176-199: TWINS (docs/twins_176_199_integration_plan.md and
    docs/twins_176_199_lab.md). 176 / 179 / 184 are the approved Twins
    prototype boards (data/dev/twins_prototype/, copied unchanged apart from
    the prototype-only hearts / hints keys, which equal the lab defaults);
    177, 187, 190, 192, 194, 197 are new boards; 182 is production 182 with
    one bonded pair; 180 / 185 / 186 are production 179 / 186 / 185 moved by
    one slot; the other slots are production boards, unchanged. Level 200
    is production's Grand Master, unchanged.

Writes level_01..level_200.json and manifest.json (source + edits of every
level). Every edit asserts the exact original token, so a changed source can
never be adapted silently. Run from the repository root:

  python3 tools/experience_lab_build.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "dev", "experience_lab")
# Production levels 1-200 as they were before the freeze (commit 1fadb37):
# the lab's sources. Since the freeze, levels/level_01..200 ARE this lab's
# output (docs/freeze_1_300.md), so the lab is rebuilt from the archive.
PROD = os.path.join(ROOT, "data", "dev", "pre_freeze_production")


# MAGNET campaign (docs/magnet_campaign_plan.md): the 22 Magnet levels are
# production's own boards (levels/, written by tools/magnet_campaign_build.gd),
# so the lab keeps mirroring production byte for byte.
MAGNET_LEVELS = [n for n in range(76, 100) if n not in (80, 90)]


def prod_path(n):
    if n in MAGNET_LEVELS:
        return os.path.join(ROOT, "levels", "level_%02d.json" % n)
    return os.path.join(PROD if n <= 200 else os.path.join(ROOT, "levels"), "level_%02d.json" % n)

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
# Second era (temporary lab boundary at 200): 101 and 106-200 are production
# boards; 104 is a new board.
LAST = 200
SOURCES.update({n: ("prod", n) for n in range(101, LAST + 1)})
SOURCES[104] = ("new", "now_or_later")
# Armor at 151 (docs/armor_151_progression_design_audit.md, section 5): the
# production Switch levels 151-160 and Armor levels 161-170 interleaved.
# 155, 157, 160, 170 and 171-175 keep their slots; 151 is production 161
# with one token adapted (EDITS[151]).
ARMOR_INTERLEAVE = {
    151: 161, 152: 166, 153: 151, 154: 162, 155: 155, 156: 168, 157: 157, 158: 165, 159: 154, 160: 160,
    161: 167, 162: 152, 163: 164, 164: 156, 165: 169, 166: 158, 167: 163, 168: 159, 169: 153, 170: 170,
}
SOURCES.update({n: ("prod", src) for n, src in ARMOR_INTERLEAVE.items()})
# TWINS at 176 (docs/twins_176_199_integration_plan.md, section C):
# ("proto", n) = Twins prototype level n (approved on iPhone).
TWINS_PLAN = {
    176: ("proto", 1), 177: ("new", "double_link"), 179: ("proto", 2), 180: ("prod", 179),
    184: ("proto", 3), 185: ("prod", 186), 186: ("prod", 185), 187: ("new", "shell_game"),
    190: ("new", "two_bonds"), 192: ("new", "reversal"), 194: ("new", "pattern_lock"), 197: ("new", "bond_of_ages"),
}
SOURCES.update(TWINS_PLAN)

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
    51: [(1, 2, ".", "Y>", "one new arrow under the Pattern spinner gives it a third neighbour: on every winning path it turns right, right, then LEFT - and that reversed turn (with the last red key) is what lets it out"),
         (4, 3, "Y>", "Y<", "with the new arrow, limits the level's only trap to a shallow one (no losing first move; mistakes recoverable within 1-4 Undos)")],
    # Switch ramp (docs/player_experience_lab_1_100.md, "Switch learning ramp").
    102: [(2, 0, ".", "Yv", "an UNMARKED twin of the marked yellow arrow: the switch reverses only the marked one; the twin can only leave after the switch, so the contrast is seen on every winning path"),
          (2, 4, "R^", "R>", "the twin would face this red arrow head-on; pointing right keeps the board solvable")],
    103: [(0, 3, "P^", "P^&A", "a second arrow marked A: the two purples face each other head-on and ONE switch turns both around"),
          (1, 0, "Yv", "Y^", "a second safe first move (the old board had one legal move at every step)")],
    105: [(0, 4, "Y>", "Y>%B", "switch B (the second, independent group)"),
          (3, 3, "B<", "B^&B", "the arrow marked B: only switch B reverses it; both groups are required"),
          (3, 0, "Yv", "Y^", "a second safe first move")],
    53: [(3, 1, "G>@", "G>@*", "one clockwise spinner becomes a pattern spinner; its third (left) turn is on the solution path")],
    56: [(2, 5, "Bv@", "Bv@*", "one clockwise spinner becomes a pattern spinner; its third (left) turn is on the solution path (replaces the planned 55: no spinner or arrow there can ever make a third turn)")],
    # Armor intro (production 161 "First Shell" at Lab 151): the bottom-edge
    # green could leave at any time and turn its spinner neighbours into a
    # dead end that showed 8+ moves later, also after the guided lesson.
    # Pointing it right (into the green spinner) keeps it on the board until
    # that spinner has left: no losing first move, no fatal option on SHOW A
    # MOVE's line before or after the lesson; same shell, same rammer.
    151: [(2, 6, "Gv", "G>", "removes the first-encounter decoy: the edge arrow could leave at any time and strand the board 8+ moves later, also after the lesson; it now waits behind the green spinner")],
    57: [(1, 3, "G^", "G^@*", "one arrow becomes a pattern spinner (no existing spinner here can make a third turn)")],
    # TWINS in a full Elite board (docs/twins_176_199_integration_plan.md,
    # B.3): the only measured in-place pair that adds a decision - releasing
    # it turns the Pattern spinner beside it, fatal at 7 steps of SHOW A
    # MOVE's line (a visible spinner turn, never a plain escape).
    182: [(4, 5, "R<", "R<!T", "bonded to the yellow arrow beside it: the pair's release turns the Pattern spinner next to it, a timing decision"),
          (5, 5, "Y<", "Y<!T", "the red arrow's twin")],
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
    131: ("Switches can be gate links too.",
          "A switch turns the spinners beside it, too.",
          "no block in 1-300 is both a switch and a gate link; on this board the switch's escape turns its neighbour spinner (an existing rule, nothing new)"),
    105: (None,
          "Each switch turns only its own mark",
          "two independent groups (A and B) are new here; one short line, no finger"),
    51: ("Pattern spinner: right, right, left - then repeat",
         "This spinner follows a pattern: watch its bold hook",
         "the level itself now shows right, right, left; the hint points at the three-hook visual instead of spelling out the rule"),
    41: ("Dots show a spinner's rule: this one alternates",
         "This spinner alternates: watch its bold arrow",
         "the lab draws Alternating as a two-way ring, not dots; the level itself now shows the alternation"),
    13: ("A lock opens when all blocks of its color are gone",
         "A lock opens when every block of the LOCK's color is gone",
         "\"its color\" read as the locked block's own colour; the rule is about the lock's key colour"),
}

# The new boards: 16, 20 and 104 (docs/player_experience_lab_1_100.md) and
# the Twins boards of 177-197 (docs/twins_176_199_lab.md; found and verified
# with the real engine).
NEW = {
    # 177: both twins are links of Gate C, so the pair opens it in one move
    # and the green arrow aimed at the gate follows. A vertical pair (176's
    # pairs are horizontal); one spinner gives the board a little bite.
    "double_link": {
        "name": "Double Link",
        "hint": "Each twin is a gate link - one move, two links",
        "hint_finger": False,
        "map": [
            "B^ .  .        .   .  .",
            "P> .  .        Y>  R^ .",
            ".  .  Y>+C!T   Bv@ .  .",
            ".  .  Y<+C!T   .   .  .",
            ".  .  .        .   .  .",
            "G> XC .        .   .  .",
        ],
    },
    # 187: the top twin's lane runs into a shell, and twins never ram - the
    # red spinner above the shell is the rammer. Every fatal move is a pair
    # release at the wrong time (it turns the yellow spinner beside it).
    # Boards 187-197 were refined so that neither "hold the pair to the end"
    # nor a short look-ahead solves them (habit / look-ahead players as in
    # tools/human_audit.gd; docs/twins_176_199_lab.md).
    "shell_game": {
        "name": "Shell Game",
        "hint": "Twins can't crack a shell - another block must",
        "hint_finger": False,
        "map": [
            ".   .  Bv@- Yv@~ .      Rv@",
            ".   R> .    Y>@- P>+C!T R>=",
            "B>  .  .    .    P>!T   .",
            "G<  .  .    .    .      .",
            ".   .  Bv   XC   .      G^#B",
            ".   .  .    .    .      R<",
            "Y^@ .  B>   P>   .      G^@",
        ],
    },
    # 190 (Chapter 19 finale): two pairs - a horizontal purple pair and a
    # vertical, L-shaped red pair - each beside its own spinners; both have
    # wrong release moments.
    "two_bonds": {
        "name": "Two Bonds",
        "map": [
            ".  .    Gv@- R^#P . B> Bv@-",
            ".  Y>@  B^@  P>@  P^ .  .",
            ".  P<!T P<!T .    Y< P< P<",
            ".  .    .    .    .  .  .",
            ".  .    .    .    Y^ .  .",
            "Y^ R<@* Rv!U .    P^ .  B<",
            ".  .    R<!U .    .  .  .",
        ],
    },
    # 192: switch A reverses BOTH twins - back to back, they turn to face
    # each other - and the purple arrow beside it. The twins are two of
    # Gate C's three links.
    "reversal": {
        "name": "Reversal",
        "map": [
            "P>    .    G<@- .   .           .",
            "Pv&A  R^%A Y<   Bv  Y<&A+C!T    Y>&A+C!T",
            ".     .    B>   .   .           Bv",
            "B>    R<@- P^@~ .   .           .",
            ".     .    .    .   XC          .",
            ".     .    .    .   R<          .",
            "Yv@-  B<   .    R^@* P^@-       Bv+C",
        ],
    },
    # 194: the red pair sits under an Alternating and a clockwise spinner;
    # every fatal move is a release at the wrong moment. Red is also the
    # purple lock's key colour.
    "pattern_lock": {
        "name": "Pattern Lock",
        "map": [
            ".  .    Rv   .    . .",
            ".  R<   .    R>   . P<@-",
            ".  .    G^@~ Y^@  . Pv",
            "Y> Yv@- Rv!T Rv!T . Yv",
            ".  P^   .    .    . .",
            ".  P<   B>@  .    . .",
            "R< P^#R .    .    Yv@~ Bv",
        ],
    },
    # 197 (the Twins exam): an L-shaped pair - one twin marked by switch A,
    # both Gate C links - between two spinners, with the switch, two locks
    # and the gate around it.
    "bond_of_ages": {
        "name": "Bond of Ages",
        "map": [
            ".     .        .      .  .  .    B^",
            "R<@   G^&A+C!T G<+C!T G> .  B>   .",
            ".     Gv       Y>@*   .  .  B>@~ R^",
            "Rv#B  .        .      .  .  .    .",
            ".     .        .      .  .  Y>%A Yv",
            "Y<@-  .        .      P> Bv Pv@  .",
            ".     Gv#Y     Y^@    .  XC G<   .",
        ],
    },
    # Switch timing: the yellow arrow holds back both the switch and the
    # purple arrow marked A. The purple must leave UP before the switch fires;
    # fired early, it turns to face the red arrow under it, head-on.
    "now_or_later": {
        "name": "Not Yet",
        "hint": "Fire a switch at the right moment",
        "hint_finger": False,
        "map": [
            ".    .    .   .",
            ".    B>&A .   B<",
            "G>%A .    Y^  .",
            ".    .    P^&A G<",
            ".    P>   R^  .",
        ],
    },
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

def prod_name(n):
    return json.load(open(prod_path(n)))["name"]


def prod_repeat(n, kind, src, name, edits, rename, hint):
    """A repeated name is allowed only on an unchanged production board of the
    Second Era (101+) whose name production itself already gives another
    level (e.g. 62 and 115 "Afterglow"): those boards reproduce production
    exactly, so the lab never renames them."""
    if n <= 100 or kind != "prod" or src != n or edits or rename or hint:
        return False
    return any(prod_name(m) == name for m in range(1, n))


ORDER = ["name", "mystery", "hint", "hint_finger", "blocked_hint", "hearts", "hints", "stars", "map"]


def fmt(rows):
    grid = [r.split() for r in rows]
    w = max(len(t) for r in grid for t in r) + 1
    return ["".join(t.ljust(w) for t in r).rstrip() for r in grid]


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = []
    names = {}
    for n in range(1, LAST + 1):
        kind, src = SOURCES[n]
        if kind == "proto":
            path = os.path.join(ROOT, "data", "dev", "twins_prototype", "level_%02d.json" % src)
            data = json.load(open(path))
            for k in ("hearts", "hints"):
                if data.pop(k) != {"hearts": 3, "hints": 2}[k]:
                    sys.exit("L%d: the prototype's %s no longer equals the lab default" % (n, k))
            source = "Twins prototype %d" % src
        elif kind == "lab":
            path = os.path.join(ROOT, "data", "dev", "opening_lab", "level_%02d.json" % src)
            data = json.load(open(path))
            source = "Opening Lab %d" % src
        elif kind == "prod":
            path = prod_path(src)
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
            if old_hint is None:
                data["hint_finger"] = False  # a reminder line, never a finger on the solution
            hint = {"from": old_hint, "to": new_hint, "why": why}
        if data["name"] in names and not prod_repeat(n, kind, src, data["name"], edits, rename, hint):
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
                         "twins": any("!" in t for r in grid for t in r),
                         "edits": edits, "rename": rename, "hint": hint})
    with open(os.path.join(OUT, "manifest.json"), "w") as f:
        json.dump({"_comment": "Player Experience Lab 1-200: source of every lab level (tools/experience_lab_build.py).",
                   "levels": manifest}, f, indent="\t", ensure_ascii=False)
        f.write("\n")
    extra = [p for p in os.listdir(OUT) if p.startswith("level_") and p not in {"level_%02d.json" % n for n in range(1, LAST + 1)}]
    if extra:
        sys.exit("unexpected files: %s" % extra)
    print("wrote %d levels + manifest to %s" % (LAST, OUT))


if __name__ == "__main__":
    main()
