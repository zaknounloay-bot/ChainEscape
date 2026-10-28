# EXTREME Time Attack — Phase 20: generator improvement and strategic diversity

Development only. Production, the 300 frozen levels, Supabase, the Social
MVP, Challenge a Friend, campaign timing / Personal Best and Gameplay
Feedback Polish are untouched. The 90-second rules (timer, GREEN / ORANGE /
RED music, the final 10 s, RESTART without a timer reset, UNDO x3, no hint, no
hammer, the short questionnaire with SKIP) and the Phase 18B exact TIME UP
continuation are unchanged.

## Step 0 — Repository safety

Branch `claude/elegant-fermat-0jrmxo`, HEAD `81984807…` (the approved
baseline), clean tree, identical to `origin` (0 / 0).

## Phase 19 human review — classification

N35 and N36 promoted to **STRONG** (two experienced players each, real
iPhones: N35 TIME UP / EXTREME / 5 and 70.17 s / VERY HARD / 4; N36 78.58 s /
VERY HARD / 5 and TIME UP / VERY HARD / 4; all four "play again: YES"). A
development-stage decision on four runs — not a validated difficulty or a
market signal. Boards and fingerprints unchanged.

| Group | Boards |
|---|---|
| CORE | N3, N5, N7, N11, N13 |
| STRONG | N14, N15, N16, N18, N21, N26, N27, N29, N30, N31, N32, N33, N34, N35, N36 |
| PROVISIONAL | N23, N24 |
| ARCHIVED | N17, N19, N20, N22, N25, N28 |

## Part A — Why the searches converge on spinners and magnets

Material: the 35 Phase 18 / 19 search runs (`data/dev/extreme90_p18|p19/
search_*.json`, their seeds and logs), and a new diagnostic
(`tools/ta90_diag20.gd`, output `data/dev/extreme90_p20/diag_out.json`) run on
the best board of every search plus nine bank boards. Per board it measures
each greedy policy's win rate; along the Solver's line, how many **risky**
moves are legal at once (a move that changes another block: a spinner turn, a
switch flip, a crate push, a ram, a Sequence advance, a magnet pull); whether
each losing move is a risky move or a plain removal; and distinct mistakes
counted per block as well as by cell + arrow.

### Evidence

1. **Losing moves are risky moves.** Across 44 boards, plain removals
   lose in 2 boards only (3 moves each, N33 and its search parent); every
   other losing move is a switch tap, push, ram, pull or spinner-turning
   removal. Portals, gates and locks only ever clear lanes, so they never
   make a move lose by themselves: the portal-only, portal + gate, lock +
   Sequence and first switch / gate searches reached **0** risky moves on
   most steps and **0** distinct mistakes (PR, PG2, LS, SG).
2. **The greedy shortcut is a concurrency problem.** Every board with a
   100 % greedy shortcut (LS2, PS, SG2, SG4) has **at most one** risky move
   legal at any step (multi-risky share 0.00). All greedy policies play calm
   moves first; with one risky move at a time the calm-first player simply
   fires it when nothing else is left — and wins. Every board with >= 4
   distinct mistakes has two or more risky moves open on most steps
   (share 0.57–0.93; N35 0.57, N36 0.82, N3 0.46 with very few steps).
3. **Distinct mistakes ≈ the number of risky actors that can be misplayed.**
   Counting per block or per cell + arrow differs by at most one on every
   board (hypothesis "the label inflates spinner / magnet boards" —
   **rejected**).
4. **The generator cannot add the actors these families need.** In
   `ta90_search.gd` growth adds plain arrows (calm, monotone), and a mark
   only rides along at 25–30 % on a new or turned arrow. Switch pieces
   (`%A`) were never in any seed's suffix list, so a switch core could never
   gain a second switch; and a marked piece is not editable, so a mark,
   once added, could never be removed or moved. With spinners allowed
   (`palette: all`, Phase 18) the same portal and Movable cores reached 7
   and 7 distinct mistakes (SPP, SPC) — every new spinner is a new risky
   actor. With plain arrows they reached 0–3.
5. **Budget is not the binding limit.** 30 of 35 runs stopped on patience
   (8 rounds without improvement), not on time: random arrow edits rarely
   change the decision structure, so the score landscape is flat.
6. **Performance caps bind only for crates in open rows and lock-free magnet
   boards** (MF2 round 1: 5 325 positions, 96.5 ms; MG3 without its locks:
   42.2 ms). They are safety requirements and stay.

### Per family — primary reason for failure

| Family (runs) | Best reached | Primary reason | Kind |
|---|---|---|---|
| Portal-first (PR, PG2, PS, PX, PX2) | 0–3 distinct | the portal is monotone: it reroutes lanes but makes no losing move; the only risky actors were one or two switches / a crate, mostly one at a time | mechanic limitation (as a trap source) + generator (no actors added) |
| Switch / Gate (SG, SG2, SG3, SG4) | 0–2 distinct, shortcut up to 100 % | one switch tap open at a time (gate and lanes serialise them): a calm-first player wins | core construction + generator (no second switch possible) |
| Rammer / Armor (AR, AS, AS2) | 0–3 distinct | one rammer / switch pair at a time; shells only gate a ram | core construction + generator |
| Sequence (LS, MS, SQX, SQX2) | 0–3 distinct | an advance repeats the same mistake on step after step | difficulty model (one actor) + core |
| Lock (LS2, MX3, MG2) | 1–3 distinct | locks are monotone; decorative in MG3 | mechanic limitation (as a trap source) |
| Magnet (MG, MG3, MX1, MX4) / Spinner | 4–8 distinct | each magnet / spinner is a risky actor, and growth adds them cheaply | (reference) |

### Hypotheses (not yet evidence)

- Raising the number of *concurrently available* risky actors of the core's
  own mechanics, and rewarding concurrency, should defeat the calm-first
  shortcut and raise distinct mistakes in switch, armor and portal-plus-actor
  families. Part C tests this.
- Portals, gates and locks can contribute as **shapers** (where an actor's
  effect lands, which actor opens first), not as trap sources.

## Part B — The improved generator (`tools/ta90_search.gd --ops=v20`)

Narrow changes to the existing development search; no new mechanic, no
solver change, the runtime untouched. Off by default: without `--ops=v20`
the search makes the same edits and the same scores as before (it only also
measures concurrency and counts qualifying boards).

1. **Actor operator** (30 % of edits): adds a risky actor of the core's *own*
   mechanics — another switch piece of an existing group (at most 2 per
   group), one of the seed's marks (flip target, shell, magnet, lock, gate
   link; the seed's caps kept), a crate within `crates_max` — on a plain
   piece or a new one.
2. **Reversible marks:** a non-frozen marked piece can be removed, unmarked,
   or turned with its mark kept (before, a mark, once added, stayed for good).
3. **Focused placement:** new pieces go mostly into the rows / columns of
   risky actors (switches, crates, shells, magnets, flip targets).
4. **Concurrency term:** + 12 × (share of solution steps with >= 2 risky
   legal moves) — the property Part A found missing on every shortcut board.
   A ranking term only; acceptance is unchanged.
5. **Yield counter** (both arms): every evaluated board meeting the fixed
   EXTREME search targets (`_qualifies`) is recorded.

Also added: `tools/ta90_diag20.gd` (Part A's diagnostic; it also works as a
cheap core lint: a core with one risky move at a time predicts a shortcut).
Not done, on purpose: no incremental solver (the budget was not binding —
Part A, point 5), no change to the thresholds or the TIME UP gate.

## Part C — Controlled experiment

Protocol fixed before running (`data/dev/extreme90_p20/protocol.json`): the
Phase 19 cores unchanged; RNG seeds 1 and 2; 12 min, batch 40, beam 5,
patience 8; each wave = one family's 4 runs in parallel (both arms on the
same load); qualifying = NEED.EXTREME (distinct >= 4, steps >= 8, endgame,
coverage >= 0.60, late >= 0.75, solution >= 13, shortcut <= 0.20, every
mechanic matters). "Meaningful benefit" = v20 finds a board passing the full
Category A + B report in >= 2 of the 3 weak families where the baseline finds
none or fewer.

| Family | Arm | Seed | Evaluated | Seconds | Stop | Qualifying (raw / clusters*) | Best: distinct / steps / shortcut / positions | Concurrency |
|---|---|---|---|---|---|---|---|---|
| Portal (PX2) | baseline | 1 | 980 | 360 | patience | 430 / 13 | 5 / 11 / 0.10 / 454 | 0.75 |
| | baseline | 2 | 928 | 295 | patience | 0 / 0 | 3 / 12 / 0.17 / 1142 | 0.93 |
| | v20 | 1 | 712 | 266 | patience | 261 / 12 | 5 / 14 / 0.00 / 445 | 0.88 |
| | v20 | 2 | 966 | 357 | patience | 223 / 7 | 5 / 13 / 0.00 / 834 | 0.73 |
| Switch / Gate (SG4) | baseline | 1 | 987 | 89 | patience | 0 | 2 / 8 / 1.00 / 42 | 0.00 |
| | baseline | 2 | 795 | 69 | patience | 0 | 2 / 8 / 1.00 / 66 | 0.00 |
| | v20 | 1 | 700 | 119 | patience | 0 | 3 / 11 / 0.42 / 266 | 0.63 |
| | v20 | 2 | 946 | 134 | patience | 0 | 3 / 12 / 0.28 / 144 | 0.69 |
| Rammer / Armor (AS2) | baseline | 1 | 777 | 172 | patience | 0 | 2 / 18 / 0.00 / 967 | 0.65 |
| | baseline | 2 | 750 | 153 | patience | 0 | 3 / 14 / 0.07 / 385 | 0.50 |
| | v20 | 1 | 1734 | 471 | patience | 731 / 16 | 6 / 17 / 0.03 / 862 | 0.80 |
| | v20 | 2 | 1180 | 315 | patience | 185 / 6 | 4 / 17 / 0.07 / 681 | 0.81 |
| Magnet (MG3, reference) | baseline | 1 | 726 | 173 | patience | 0 | 2 / 15 / 0.05 / 223 | 0.88 |
| | baseline | 2 | 1221 | 362 | patience | 0 | 3 / 15 / 0.00 / 358 | 0.88 |
| | v20 | 1 | 886 | 199 | patience | 0 | 3 / 15 / 0.00 / 372 | 0.88 |
| | v20 | 2 | 1202 | 321 | patience | 0 | 3 / 15 / 0.00 / 257 | 0.88 |

\* Added after the runs, as a reading aid only (not a threshold): raw counts
are mostly one-cell neighbours of the same board, so qualifying boards are
also grouped into clusters (two boards in one cluster differ in <= 3 cells).

Full Category A + B report (`ta90_design.gd`, one board at a time on an idle
machine) on the top qualifying board of every qualifying run:

| Board | A | B | Positions | TIME UP worst | Distinct / steps | Shortcut | look6 greedy | Mechanic counterfactuals |
|---|---|---|---|---|---|---|---|---|
| PX2 baseline s1 | pass | pass | 454 | 12.8 ms | 5 / 11 | 0.15 | 0.26 | no crate 2 / 2; no portal 3 / 3; no switch unsolvable |
| PX2 v20 s1 | pass | pass | 445 | 21.2 ms | 5 / 14 | 0.02 | 0.02 | no crate 0 / 0; no portal 9 / 4; no switch unsolvable |
| PX2 v20 s2 | pass | pass | 834 | 19.2 ms | 5 / 13 | 0.05 | 0.09 | no crate 4 / 2; no portal 9 / 3; no switch unsolvable |
| AS2 v20 s1 | pass | pass | 862 | 4.6 ms | 6 / 17 | 0.06 | 0.08 | no armor 6 / 2; no switch unsolvable |
| AS2 v20 s2 | pass | pass | 681 | 5.3 ms | 4 / 17 | 0.15 | 0.17 | no armor 2 / 1; no switch unsolvable |

**Result against the protocol: benefit shown in 2 of 3 weak families.**

- **Rammer / Armor — clear:** baseline 0 of 2 runs qualify, v20 2 of 2.
- **Portal-first — modest:** baseline 1 of 2, v20 2 of 2, with lower
  shortcuts (0.00 vs 0.10–0.17). The baseline's seed-1 success also shows
  that Phase 19's single-seed runs could abandon a viable family on luck.
- **Switch / Gate — not reached:** v20 removed the 100 % shortcut (to
  28–42 %) and added a distinct mistake, but no board qualified.
- **Magnet (reference):** no difference (3 vs 3 distinct); the operators do
  not just favour the families they were built for.
- Search cost is comparable: v20 evaluated 700–1734 boards in 2–8 minutes,
  the baseline 726–1221 in 1–6 minutes; every run stopped on patience.

### Switch / Gate: the one redesign (SG5)

The diagnosis named the cause (SG4 opens one switch at a time), so the core
was redesigned once: switch B no longer waits for row 3, both switches are
open from the start (core concurrency 0.63 vs 0.00). Same budget, both arms:
baseline 0 of 2 (2 distinct), v20 1 of 2 (4 distinct, 14 steps, shortcut
0.12). The full report passes A and B, but the board is **not taken**: the
gate is close to decoration (without it: the same 14 steps, 4 → 3 distinct),
the shortcut is 0.16 against the 0.20 cap and the look-6 greedy wins 29 %.
The Switch / Gate family stays open.

## Part D — New candidates

Two boards, one per family where the benefit was shown; both **non-spinner,
non-magnet**, both **HUMAN-REVIEW CANDIDATES** (Category A and B pass; human
difficulty unvalidated). Within each family the board with the strongest
dependence on the family's own mechanic and the lowest overlap was taken; the
same-core alternatives are variants and stay out (`accepted.json`).

| ID | Grid / pieces | Mechanics | Concept | Fingerprint |
|---|---|---|---|---|
| N37 | 7×7 / 15 | 1 crate, 1 portal pair, 2 switch groups (4 switch pieces), 4 flip targets | the crate travels: pushed into the portal it comes out on the far side, in a lane a block still needs; which switch fires first decides who can still leave | `49d72b9a320cbb9253335c61b01a2f88311125d88f12f19f2a12ccf8ecfce9f4` |
| N38 | 7×7 / 15 | 5 shells, 2 switch groups (4 switch pieces), 5 flip targets | two rammers crack the shell in front, must stay, and are turned around to crack the one behind; which reversal fires first decides which shells can still be reached | `960fb50bdff4b2a3cf405c9b6906e260a4dd3bb6b1458628720e136c0c9ba552` |

| ID | Positions | Solution | Solve | TIME UP worst (desktop) | Parity | Distinct | Steps | Coverage / late | Shortcut | look6 | Learner (look4 / 6) | Trap delay | Undo-proof | Trivial removals | Closest (overlap) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N37 | 834 | 15 | 5.4 ms | 19.2 ms / 971 nodes | 0 / 0 | 5 | 13 | 0.87 / 0.93 | 0.05 | 0.09 | 1 / 2 | 10 | 0.89 | 0 | N36 (0.27); N35 0.27 |
| N38 | 862 | 20 | 6.6 ms | 4.6 ms / 135 nodes | 0 / 0 | 6 | 17 | 0.85 / 0.85 | 0.06 | 0.08 | 2 / 2 | 9 | 0.88 | 0 | N36 (0.33) |

Known weaknesses:

- **N37** leans most on its switches (without them unsolvable); the portal
  reshapes the crate's trap (without it 13 → 9 steps, 5 → 3 distinct) rather
  than being the sole trap. Learners clear it quickly (1–2 dead ends) — the
  bank shows that number does not separate boards people found hard (N3 1 / 0,
  N21 1 / 0), but it is worth watching.
- **N38** is busy for its size: four switch pieces and five shells.
- Both are 7×7, both use switches: the variety is in the second mechanic
  (portal + crate vs armor), not in the trigger.

## Part F — A continuation fix found by the new boards

N38's continuation check failed one assertion: UNDO right after CONTINUE
WITHOUT TIMER did not take back the last move before TIME UP. Cause: the tap
log infers the tapped block from the board (`VhHumanTest.infer_tap`); a ram
that two blocks could have made is logged as -1, so the timed moves cannot
be replayed and the page restores the captured board instead — **the exact
board** (Phase 18B's guarantee held), but without UNDO history. This is not
N38-specific: any armor board where two rammers face one shell can hit it on
some play path.

Fix (`Ta90TimeAttack._log_action`, the 90-second pages only): such a ram is
logged with the block the player actually touched (the page already records
it, `_last_tap`, for blocked taps). The replay still verifies the rebuilt
board; if it differs, the captured board is restored as before. The
continuation check now taps as a player does (the touched block noted, then
the play screen's tap). Gameplay is unchanged; only the log is more complete.

## Part E — The Phase 20 testing page (`?extreme90p20=1`)

`Extreme90P20` (extends `Extreme90P19`, the verified QA3 design).
- **CHOOSE A CHALLENGE:** only CHALLENGE 1 = N37 and CHALLENGE 2 = N38, with
  PREVIOUS CHALLENGES, COPY ALL RESULTS and HOW IT WORKS.
- **PREVIOUS CHALLENGES:** CHALLENGE 3–24 = every board of the Phase 19 page
  in its order (N35, N36, then the Phase 18B selection).
- **No locks;** a previous board opened from that screen returns there.
- **Storage and export:** its own storage `xb20_*` / `chain_escape_xb20_hub`
  and export `ce-xb20` (`selection: "xb20-v1"`).
- **Export contents:** every run under its real board id and fingerprint,
  each board's challenge number, list (new / previous) and group: `phase20`
  for N37 / N38, `strong` for N35 / N36 here, `core` / `strong` /
  `provisional` for the rest; archived ids listed.
- **Earlier pages untouched:** the Phase 19 page and its records are
  unchanged; its own export still shows N35 / N36 as `phase19`.
- **Build id:** "DEV BUILD p20-qa1-20261028" in small text under the buttons,
  and in the export.

## Updated classification

| Group | Boards |
|---|---|
| CORE | N3, N5, N7, N11, N13 |
| STRONG | N14, N15, N16, N18, N21, N26, N27, N29, N30, N31, N32, N33, N34, N35, N36 |
| PROVISIONAL | N23, N24 |
| PHASE 20 HUMAN-REVIEW CANDIDATES | N37, N38 |
| ARCHIVED | N17, N19, N20, N22, N25, N28 |

20 core / strong, 2 provisional, 2 new candidates. No earlier board,
definition, fingerprint or record changed.

## QA (final build)

Dev build ("Web") and player build ("Web Friend Test") exported from the
working tree; the player build contains 0 `data/dev` files.

| Suite | Result |
|---|---|
| Browser `?extreme90p20=1` (iPhone SE viewport) | 66 / 66. Primary screen only N37 / N38. PREVIOUS CHALLENGES 3–24 all reachable, BACK. Every board played by touch; TIME UP and exact continuation; SKIP; export with real ids, lists and build id; player build ignores the page |
| Browser `?extreme90p19=1` / Phase 19 upgrade test | 62 / 62, 9 / 9 |
| Browser `?extreme90p18=1` / `?extreme90=1` / `?extreme90p17=1` / `?ta90=1` / `?tapilot` | 55 / 55, 45 / 45, 51 / 51, 55 / 55, 28 / 28 |
| Browser timing / friend build / stime / ttime tta | pass, 25 / 25, 31 / 31, 32 / 32 |
| Extreme90p20Check | 132 checks |
| Extreme90p19Check / Extreme90p18Check | 124 / 111 |
| Ta90ContinueCheck (all 24 boards, exact TIME UP continuation) | 276 checks, 96 cases, 0 not resumed exactly |
| PortalCheck / MovableCheck / MagnetCheck | pass |
| Headless regression (unit tests, competition, timing, profile, feedback, friend, social, pilot, extreme11, q1 / r time, Ta90Check 91, Extreme90Check 91, Extreme90p17Check 97) | pass |
| verify_levels | all 300 levels solvable, campaign rules pass |

**Pre-existing failure (not Phase 20):** RecipientTest — the same 3 layout
checks ("TOTAL SCORE left, coins right", en_US / he_IL / ar_SA).

WebAssembly full solve (the TIME UP check), headless Chromium: N37 10.3 ms,
N38 9.6 ms; slowest on the page N16 26.2 ms.

The browser tests run headless Chromium at an iPhone SE viewport; they are
**not** equivalent to testing on a real iPhone.

## Safety audit of the change

Runtime changes (development pages only):
- a dev-gated hook in `game_manager.gd` (only with `?extreme90p20=1`, dev builds);
- two `BOARDS90` entries (N37, N38) and the `Extreme90P20` page;
- the ram log fix in `Ta90TimeAttack._log_action` (90-second dev pages;
  logging only, the replay still verified).

Tools: `ta90_search.gd` (`--ops=v20`, off by default), `ta90_diag20.gd`, the
Phase 20 check, the browser test entry, and the continuation check's touch
emulation.

No campaign level, Production code, Supabase, Social / Challenge a Friend
code, existing board definition, fingerprint or record changed. One local
commit; nothing pushed, merged, deployed or uploaded.
