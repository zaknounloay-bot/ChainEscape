# EXTREME Time Attack — Phase 24: reasoning-first puzzle design

Development only. Production, Supabase, the 300 Classic levels, saves /
progression, campaign timing and Personal Best, the 120-second Time Attack
baseline, the Social MVP and Challenge a Friend are untouched. No new
mechanic, booster, visual system, scoring or timer rule. The only game-script
changes are the new developer page (`scripts/social/extreme90_p24.gd`), its
`game_manager` hook and one `BOARDS90` entry (N52).

**Method change:** each puzzle was designed by hand around a reasoning idea.
The bench (`tools/ta90_bench24.gd`, new), the design report
(`tools/ta90_design.gd`) and the filler check (`tools/xb90_filler.gd`) were
used only to *verify* drafts. No generator search ran in Phase 24.

**Budget, fixed before drafting:** at most 8 revisions per prototype after
its first draft. Every draft is in `data/dev/extreme90_p24/design_log.json`.

**Outcome:** 1 of 3 prototypes qualifies (A → **N52**). B and C stop with
documented structural obstacles.

## A. Git backup

- **Start of Phase 24:** HEAD `bb4de69` (Phase 23); `origin` at `9c3d8b6`, a
  direct ancestor (checked with `git merge-base --is-ancestor`).
- **Push:** as the brief authorised, a normal push (no force) moved
  `origin` `9c3d8b6 → bb4de69`; `git ls-remote` confirms `bb4de69d8af9…`.
  **Phase 23 is backed up.**
- **Phase 24:** one local commit on top of `bb4de69`, not pushed (hash in the
  final report).

## B. Three reasoning structures

### A — "Pull order": a five-magnet cascade (magnet + armor + lock)

**The idea.** A magnet pulls the *first* block behind it into its own cell.

**Why the cascade, not a cycle.** If two magnets' lines cross in a cycle,
the first magnet to fire always takes its nearest block, so the order cannot
change who gets what; this was worked out by hand before any board was drawn.
In a *chain*, though, firing one magnet takes the near block out of the next
magnet's line, and only then does that magnet get the right block. That chain
is the structure.

**The board (N52):**
```
R^#B .  .  .   .   .   G>=      L (blue lock) walls in M_A; T_X
Y^*  .  .  G^= .   .   .        M_A (magnet); T_A (shell)
P^   .  .  .   B<  .   R>*      x; y; M_B
Y>   .  .  .   .   .   .        z (a free arrow)
.    .  .  .   Rv  G>  P>*      u; v; M_D
.    .  .  .   .   .   Gv=      T_B
.    .  G^= .  Bv* Yv* .        T_C; M_C; M_E
```

**Intended (and verified) reasoning sequence.**
1. **M_E first.** M_E pulls v out of row 4, the line of M_D.
2. **M_D.** It now pulls u, not v. u, delivered above T_B, rams T_B. T_B
   leaves, then u.
3. **M_C.** Column 4 is now clear down to y, so M_C pulls y. y, delivered
   facing left, rams T_C.
4. **M_B.** Row 2 is now clear to x, so M_B pulls x. x, delivered facing up,
   rams T_X. T_X leaves, then x.
5. **The blue lock opens.** T_C leaves, then y. With every blue block gone,
   the lock L opens and leaves.
6. **M_A last.** Its line in column 0 now begins at z. z, delivered facing
   right, rams T_A. T_A leaves, then z.

The whole time, z (a free arrow on row 3) must **not** escape: it is the only
block that can ever reach T_A.

**Critical decisions (the 4 distinct mistakes on the Solver's line):**

| Mistake | What goes wrong | Moves until the dead end shows |
|---|---|---|
| M_D before M_E | it takes v; u stays in column 4 and M_C can only take u | 6 |
| M_C before M_D | it takes u; y is never delivered | 4–6 |
| M_B before M_C | it takes y; x is never delivered | 2–8 |
| z escapes | T_A has no cracker left | 1–16 |

Each magnet looks like an obvious "free" move, and all five are legal from
move 1. Firing them in the natural top-down or nearest-first order loses.

**Two interacting critical dependencies:**
- **The cascade order:** each firing changes what the next magnet will pull.
- **The protected deliveree under a delayed release:** z must survive until
  the lock opens, and the lock opens only after the cascade's y-branch is
  complete.

Solving the first dependency (pulling u away) opens z's row, which creates
the long-lived second trap.

### B — "Crate routing" (movable + spinner pushers)

**The idea.** Any block whose lane meets the crate pushes it one cell, and
the pusher stays.

**Why the dependencies interact:**
- A pusher is stuck behind the crate until something turns it away (here, a
  spinner pusher is turned when a neighbour leaves).
- The *number* of pushes decides which lanes the crate blocks.
- The *timing* of each turn decides whether the pusher can push again.

**The route verified on the Solver's line (B9a):**
1. J pushes the crate **down**, which releases H.
2. The spinner V pushes it **up three times**.
3. The spinner T pushes it **right once**.
4. Each turner leaves only after its pusher is done.

**Losing choices, each delayed 5–16 moves:**
- the wrong block pushes (H, or J at the wrong time);
- a turner leaves early;
- T leaves before it has pushed.

### C — Switch structures (lock + switch + armor, gate)

**Two dependency cycles broken by one switch (C1–C2).** Each lock waits for
the red blocks. A red block waits for a gate, and the gate waits for the shell
that the locked block must crack. The first reversal breaks the first cycle;
the second rammer is aimed only by the second reversal.

**Shared-key locked spinners (C3–C4).** One key borders two locked spinners,
so each departure counts toward two aims and one lock.

**Parity at unlock (C5–C8).** Each switch piece is also the colour key of a
lock, so the firing order fixes each locked rammer's facing at the moment its
lock opens.

## C. Which prototypes were built

| Prototype | Drafts | Result |
|---|---|---|
| **A** | A1–A9 (8 revisions) | **A9 qualifies → N52** |
| B | B1 (a different idea, set aside) + B2–B10 (8 revisions of the crate route; B9a / B9b are two variants of one revision) | does not qualify |
| C | C1–C8 (7 revisions) | does not qualify |

**What each A revision fixed (A1 was the first draft):**
- **A2:** A1 was bypassed: an added blocker cracked the shell from below.
- **A3:** the two-magnet crossing became a three-magnet chain.
- **A4:** all decisions were early; a front magnet was added.
- **A5:** a lock now delays the last stage.
- **A6:** distinct mistakes had fallen to 3, so a fifth magnet was added.
- **A7:** A6 was **bypassed** (u escaped on its own, so the new magnet was a
  decoy); rejected by hand.
- **A8:** A7 fixed the bypass but lost the long-lived trap; so z got its own
  row, and x a fourth shell.
- **A9:** A8 passed everything except overlap with N38 (0.43), so the layout
  was moved with the logic unchanged.

**B's structural obstacle.** The crate route stays within the 40 ms limit
only when it is short:
- **B9a** (12 moves, 726 positions): solve 17.4 ms, TIME UP check 24.1 ms.
  It passes A and B except the 13-move minimum.
- **13-move versions:** every stage that lengthens the route adds a pusher
  and a turner whose independent timing multiplies the search.

| Draft | Positions | Solve | TIME UP check | Verdict |
|---|---|---|---|---|
| B3 | 1682 | 40.7 ms | 63.7 ms | rejected |
| B9b | 1699 | 60.7 ms | 92.1 ms | rejected |

Lengthening it with inert blocks would be filler. **No threshold was
relaxed.**

**C's structural obstacle.** A switch reversal is immediate, visible and
repeatable:
- A rammer facing the wrong way can simply wait for the next firing.
- The only real windows are "after one firing, before the next", which a
  4-move lookahead resolves.

The best draft, C7, has 2 distinct mistakes, coverage 0.50 and a greedy
shortcut of 0.275 (above the 0.20 limit). The other C structures had no
losing move at all (C4: a locked spinner can always wait one more turn) or
were bypassed (C1: one rammer's row ran into both shells). An overshoot
window would bring back the bank's saturated turn-counting pattern (N12,
N14, N17).

## D. Dependency and trap evidence (N52)

**Counterfactual tests** (each variant benched exhaustively,
`tools/ta90_bench24.gd`):

| Variant | Result |
|---|---|
| N52 | solvable; 4 distinct, 16 steps, 763 positions |
| M_E a plain arrow / M_E removed | **unsolvable** / **unsolvable** |
| M_D a plain arrow | **unsolvable** |
| M_C a plain arrow | **unsolvable** |
| M_B a plain arrow | **unsolvable** |
| M_A a plain arrow | **unsolvable** |
| u removed / z removed | **unsolvable** / **unsolvable** |
| v removed (the front stage gone) | solvable, but 3 distinct and greedy shortcut 0.233 (> 0.20): the front stage is what defeats greedy play |
| the lock removed (L plain or gone) | solvable; 5 distinct, but 13 / 12 decision steps instead of 16 and coverage 0.68 / 0.67 instead of 0.84: the lock creates the endgame and the long-lived trap, not extra mistakes |

**Design report counterfactuals:**
- without magnets: unsolvable;
- without armor: 10 steps and 3 distinct instead of 16 and 4;
- without the lock: 13 steps instead of 16.

**Filler:** 0 trivial removals (15 pieces tested). No unrelated block can be
removed without changing the board.

## E. Solver and quality results (N52)

**Category A (technical):**
- fingerprint `919ec171833d8d04…866f86`; parity 0 / 0; deterministic replay;
- 763 positions (cap 2000); solution 19;
- solve 35.1 ms, TIME UP check worst 22.1 ms (both ≤ 40);
- WebAssembly full solve on the page: 25.8 ms.

**Category B (strategic):**

| Measure | N52 | Required |
|---|---|---|
| Distinct mistakes | 4 | ≥ 4 |
| Decision steps | 16 | ≥ 8 |
| Coverage | 0.84 | ≥ 0.60 |
| Late | 0.84 | ≥ 0.75 |
| Endgame decision | yes | yes |
| Solution | 19 | ≥ 13 |
| Greedy shortcut | 0.07 | ≤ 0.20 |

Every mechanic matters. **Verdict: HUMAN-REVIEW CANDIDATE.**

**Category C (estimates):**
- greedy players: safe 0, look-2 0, look-4 0, min-turn 0, mobility 0.07;
- look-6 greedy 0.017;
- learner dead ends 1 / 1;
- deepest trap 17 moves.

**Human-fit features** (`tools/ta90_humanfit.gd`, the Phase 23 study, as
context only):
- effective decisions 16 (the Phase 23 human-rated "hard" group ranges up to
  19; N48 and N49 have 19);
- calm prefix 0 and safe share 0 (N50, rated easy by one of two sessions,
  had a 10-move safe prefix);
- look-6 greedy 0.017 (N41, rated EASY, had 0.31);
- trap delay 6.

**On "complex-looking" vs "difficult":** N52 has 15 pieces on a 7 × 7 board.
Its difficulty is in the *order* of five individually obvious moves, not in
clutter.

## F. Comparison with the bank

**Overlap:** closest bank boards N36 0.33, N49 0.32, N38 0.30, all < 0.40.
(A8 failed at 0.43 with N38 before the layout was moved.)

**Conceptual neighbours:**

| Board | Rated | What it does | How N52 differs |
|---|---|---|---|
| N32 / N39 / N48 | N48: E / VH | "the magnet brings the rammer": ONE magnet's pull delivers a cracker | five magnets, and which block each delivers is decided by the *firing order* of the others |
| N31 / N46 | N46: MEDIUM | "the pull decides who is in the way" | the pulls are independent there; here they are chained |

**The strongest warning sign for N52 is N46:** a magnet board whose features
said hard, and which a person still rated MEDIUM. N52's pulls are predictable
one at a time; its claim to difficulty is the cascade, and only people can
confirm that.

## G. Regression and browser results

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real
iPhone was used.**

**Builds:** dev build ("Web") and player build ("Web Friend Test") exported
from the working tree. The dev log lists the N52 record; the player build
contains 0 `data/dev` files.

| Suite | Result |
|---|---|
| Browser `?extreme90p24=1` (new) | **94 / 94** |
| Browser `?extreme90p22=1` / `?extreme90p21=1` / `?extreme90p20=1` / `?extreme90p19=1` / the Phase 19 upgrade test | 92 / 92, 84 / 84, 66 / 66, 62 / 62, 9 / 9 |
| Browser `?extreme90p18=1` / `?extreme90=1` / `?extreme90p17=1` / `?ta90=1` / `?tapilot` | 55 / 55, 45 / 45, 51 / 51, 55 / 55, 28 / 28 |
| Browser campaign timing and Personal Best (`web_timing_test`) | **33 passed, 0 failed** |
| Browser friend (player) build / stime / ttime (`?tta=1`, the 120 s page with Phase 23's sampling fix) | 25 / 25, 31 / 31, **32 / 32** |
| Extreme90p24Check (new) | **186 checks, pass** |
| Extreme90p22Check / p21 / p20 / p19 / p18 | 184 / 168 / 132 / 124 / 111 checks, all pass |
| Ta90ContinueCheck, all 38 selection boards incl. N52 | **430 checks, 152 cases, 0 not resumed exactly** |
| Ta90DeadendCheck on N52, N49, N51 | **21 checks, pass** |
| PortalCheck / MovableCheck / MagnetCheck | pass |
| Headless regression, the 19-suite runner | **18 pass**; RecipientTest fails, pre-existing (below) |
| — passing suites | competition, unit tests, timing, profile, experience lab, feedback, Challenge a Friend API 58 / flow 149, Social API / smoke / play, pilot 33, extreme11 74, Q1 time 37, R time 39, Ta90Check 91, Extreme90Check 91, Extreme90p17Check 97 |
| verify_levels | all 300 levels solvable, campaign rules pass |

**Details:**
- **The `?extreme90p24=1` browser test covers:**
  - only CHALLENGE 1 = N52 on the primary screen;
  - CHALLENGE 2–38 on PREVIOUS CHALLENGES;
  - N52 solved by touch in a timed run (28.7 s);
  - the SHORT questionnaire;
  - TIME UP and the exact untimed continuation;
  - the `ce-xb24` export;
  - the player build ignoring the page.
- **WebAssembly full solve (the TIME UP check), headless Chromium:** N52
  25.8 ms. It is the slowest board on the page; N47 20.9 ms and N15
  21.2 ms are next.

**Known failure, reported separately:** RecipientTest. It is the same 3
layout checks ("TOTAL SCORE left, coins right", en_US / he_IL / ar_SA) that
have failed in every phase since Phase 16. It is not caused by Phase 24,
which changed no Social or recipient code.

## H. Human QA ZIP

- **File:** `build/dev_qa/chain_escape_dev_extreme90p24_p24-qa1-20261029.zip`
- **SHA-256:** `f5f0c1f7653c673ea86658f6d9f447140dedbf52c9e46e9e7c8551a9362f3d8b`
- **Contents:** 9 files plus `BUILD_ID.txt` (build `p24-qa1-20261029`, entry
  `index.html?extreme90p24=1`, base `bb4de69`, `index.pck` SHA-256
  `d74d9cfd627d7fd5…c9e28e9a`). No `data/dev` file is in the archive; N52's
  record is inside the pack.
- **Not uploaded** to itch.io or anywhere else.

**Human-testing instructions:**
1. **Upload:** a **new** HTML5 upload, so that Safari cannot reuse a cached
   older build.
2. **Open:** `…/index.html?extreme90p24=1` on an iPhone.
3. **What the player sees:** CHOOSE A CHALLENGE shows only CHALLENGE 1
   (N52), with the developer build id `p24-qa1-20261029`. PREVIOUS
   CHALLENGES lists the 37 earlier boards (optional).
4. **The run:** one 90-second run per player, first exposure, no help (the
   unchanged protocol: UNDO × 3, no SHOW A MOVE, no HAMMER).
5. **Afterwards:** the 3 short questions, then optionally CONTINUE WITHOUT
   TIMER.
6. **Collect:** COPY ALL RESULTS gives the `ce-xb24` bundle (run under the
   id N52).
7. **Record per player:** rating, timed outcome, time, attempts, and whether
   the players are independent of each other and of earlier sessions.

N52 counts toward the 50 only after human approval.

## I. What was learned

1. **Reasoning first works, but it is slow, and it shows where difficulty
   comes from.** Every successful step in A came from a reasoning argument:
   - the cycle-vs-chain insight;
   - delaying the last stage with a lock;
   - protecting a deliveree.

   None came from adding blocks. The bench caught two bypasses (A1, A6) that
   the numbers alone would have accepted (A6 passed every count).
2. **Delayed consequences need state that persists out of sight:** a magnet
   line, a lock count, a free block that must be left alone. Switch
   reversals are the opposite (immediate, visible, repeatable), which
   explains C's failure and matches the human data on switch boards rated
   easy (N41, N50).
3. **Crates are the most promising unused pattern, but the 40 ms TIME UP
   gate caps them:** each routing stage multiplies the solver's work. That
   is a fact about the solver, not a reason to relax the gate.
4. **The overlap rule is geometric.** A8's reasoning has nothing in common
   with N38, but its occupancy did. Moving cells while keeping the logic
   fixed solved it.

## J. Recommended next step

1. **Human-test N52 first** (H above), with independent players. Its claim
   is that a chain of individually obvious magnet pulls is EXTREME; N46 is
   the counter-example to watch.
2. **If N52 holds up,** design the next prototypes with the same method,
   reusing what worked: a hidden, persistent state that a tempting free move
   destroys, plus a delayed release (lock or gate) that pushes the decision
   late.
3. **For crate routing,** the open question is a routing structure of ≥ 13
   moves whose stages are *forced in sequence*, so the solver does not branch
   on them. That is a design problem to attempt by hand, not a reason to
   change the TIME UP gate.

Do not start Phase 25 before the N52 human results.
