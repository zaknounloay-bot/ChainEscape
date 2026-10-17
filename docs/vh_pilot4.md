# VERY HARD — Gate 0 advanced-mechanics pilot (development only)

> **Status:** 28 candidate boards built and technically validated. **No human testing yet** (awaiting approval).
> Nothing in production changes: no live Friend generator, shared-challenge format, backend, Supabase, Social MVP or campaign-level change. The boards exist only in `data/dev/vh_pilot4.json`, played by the development page `?vhtest4=1` (off in the player, QA and Social QA builds).

## 1. What was built

- **`tools/vh_pilot4_build.gd`** — offline builder.
  - Hill-climbs random boards per recipe, using the method of `tools/generate_era3.gd`.
  - Keeps a board only if every acceptance rule holds (§3).
  - Merges the groups into the board file, re-validating every board with the final code.
- **`tools/vh_pilot4_canon.gd`** — board identity: canonical form under rotation, reflection, recolouring and relabelling, plus the mechanics on a board.
- **`data/dev/vh_pilot4.json`** — the 28 boards, with neutral ids V01–V28 assigned in a seeded shuffle, and each board's full technical record.
- **`scripts/social/vh_human_test.gd`** — the existing blind-test page, extended with `?vhtest4=1`. Tests 1–3 are unchanged; their own check still passes 100/100.
- **`tools/vh_pilot4_check.gd`** / **`tools/VhPilot4Check.tscn`** — 439 checks: board file, every board played to the end in the real SocialPlay, and the page flow.
- **`tools/web_vhtest4_page_test.mjs`** — the page in an exported development Web build, with real touches at iPhone SE size, plus the WebAssembly timing bench.

## 2. Groups and recipes (hidden from testers)

| Group | Boards | Recipe | How it is meant to create difficulty |
|---|---|---|---|
| **G0 Baseline** | 2 | live VERY HARD | `FriendGenerator` exactly as the game runs it (comparison) |
| | 2 | controls | The two boards people found hardest before (test 2 P13 / P09, Classic L165 / L169 geometry), rotated 180° and recoloured (never seen this way) |
| | 3 | coupled | Arrows + clockwise spinners only (today's format). 8–10 spinners in 15–18 blocks, so at most ~45% of solution moves are risk-free. Targets the "most of the board plays itself" failure |
| | 1 | late traps | Arrows + clockwise spinners. Mistakes show late (random play continues ≥ 4 moves before getting stuck), beyond UNDO ×3. **Shortfall:** only one board fits the mobile time budget (§5) |
| **G1 Remote control** | 5 | switch / flip + chain gates + CW spinners | One escape reverses arrows elsewhere, and gates open only when their links are gone. The order of distant actions decides |
| **G2 Rotation logic** | 5 | CW / CCW / alternating / pattern spinners (+ locks on 3) | Each spinner turns its own way, and alternating / pattern spinners depend on how often they have turned, so the rotation sequence must be planned. Locks add colour order |
| **G3 Topology & sequencing** | 5 | portals + Sequence + CW spinners | Lanes continue through portals. A Sequence block's first move comes back with a new arrow and turns neighbours, so *when* to advance it matters |
| **G4 Movable crate** | 2 | crate-led | Pushes along the solution have many losing alternatives ("where will the crate be later?") |
| | 2 | crate + armor (+ spinners) | The crate and the rams compete for the same lanes |
| | 1 | crate + spinners | Pushes interact with spinner turns |

**Tester eligibility:**
- Before the first puzzle, the page asks how far the tester has played: all 300 levels, past 250, 225, 200 or 150, or "not that far".
- It serves only boards whose mechanics first appear at or before that level (lock 13, CCW 31, ALT 41, pattern 51, switch 101, gate 121, armor 151, portal 201, Sequence 226, crate 251).
- Confusion about unfamiliar rules therefore can't count as difficulty.

## 3. Acceptance rules (every generated board)

1. **Allowed tokens.** Existing campaign tokens only, parsed intact (no portal, link or switch dropped by validation). At most 7×7.
2. **Recipient check.** Solvable by the recipient-equivalent check (a fresh Solver with the full 60,000-node limit), within a 20,000-node working budget. All boards actually need **≤ 2,868 nodes**.
3. **Every advanced mechanic matters.** `LevelAnalysis` impact ≥ 1.0: the board without that mechanic is clearly easier, or unsolvable (99). Spinner rules are tested by making every spinner clockwise.
4. **Not trivial.** The recipe's targets are met:
   - share of risk-free moves (moves that turn no spinner and fire no switch: `Solver._is_risky`);
   - decision points and solution length;
   - real use of the recipe's mechanics (portal moves, Sequence advances, pushes, losing pushes, rams).
5. **Random tapper** wins ≤ 8%.
6. **SHOW A MOVE** stays within the 60,000 nodes on every state of the solution and after every losing move, and always finds a move on the solution path.
7. **Mobile time budget** (§5): the check, SHOW A MOVE, and SHOW A MOVE after a mistake each take ≤ 40 ms native desktop.
8. **No duplicate** under rotation, reflection, recolouring or relabelling of:
   - the 300 campaign levels;
   - every board file under `data/dev` (tests 1–3, mechanic labs and other development boards: 138 distinct boards);
   - the other candidates.

   The two G0 controls are, by design, earlier test boards in a new orientation.

**Baselines.** The live and control boards are kept as they are; they are the comparison and are not tuned.

## 4. The 28 boards

"Risk-free moves" is the share of solution moves that turn no spinner and fire no switch. **For comparison:** the live VERY HARD boards are at 67–84%, the earlier hardest boards at 81–86%, and the new recipes at 31–70%. A **heuristic player** that plays risk-free moves first, then looks 2 moves ahead (`Solver.heuristic_win_rate`) was the best proxy for people in the lock audit. It wins 57–67% of the live boards, and ≤ 20% on 20 of the 24 new boards. The exceptions are V04 (late traps, 53%), V13 and V17 (topology, 33% each) and V14 (remote control, 23%).

| Id | Group / recipe | Size | Blocks | Mechanics | Sol. | Decisions | One-safe | Risk-free moves | Random win | Heuristic win |
|---|---|---|---|---|---|---|---|---|---|---|
| V20 | G0 control | 7x7 | 21 | CW | 21 | 17 | 11 | 81% | 0% | 10% |
| V28 | G0 control | 7x7 | 22 | CW | 22 | 17 | 7 | 86% | 0% | 23% |
| V05 | G0 coupled | 6x6 | 17 | CW | 17 | 15 | 7 | 41% | 0% | 3% |
| V11 | G0 coupled | 6x6 | 15 | CW | 15 | 13 | 12 | 40% | 0% | 0% |
| V23 | G0 coupled | 6x6 | 16 | CW | 16 | 14 | 11 | 44% | 0% | 0% |
| V04 | G0 late | 7x7 | 20 | CW | 20 | 17 | 9 | 55% | 6% | 53% |
| V03 | G0 live | 6x6 | 18 | CW | 18 | 0 | 0 | 67% | 40% | 67% |
| V12 | G0 live | 6x6 | 19 | CW | 19 | 9 | 9 | 84% | 0% | 57% |
| V02 | G1 remote | 6x6 | 14 | CW, switch, gate | 14 | 12 | 6 | 50% | 2% | 0% |
| V06 | G1 remote | 6x6 | 15 | CW, switch, gate | 15 | 14 | 10 | 60% | 0% | 17% |
| V14 | G1 remote | 6x6 | 13 | CW, switch, gate | 13 | 10 | 4 | 46% | 1% | 23% |
| V16 | G1 remote | 6x6 | 17 | CW, switch, gate | 17 | 16 | 12 | 59% | 0% | 0% |
| V22 | G1 remote | 7x7 | 15 | CW, switch, gate | 15 | 12 | 6 | 60% | 0% | 20% |
| V01 | G2 rotation | 6x6 | 14 | CW, CCW, ALT, PAT | 14 | 12 | 8 | 43% | 0% | 0% |
| V07 | G2 rotation | 6x6 | 14 | CW, lock, CCW, ALT, PAT | 14 | 12 | 6 | 43% | 0% | 10% |
| V15 | G2 rotation | 6x7 | 14 | CW, lock, CCW, PAT | 14 | 10 | 5 | 36% | 0% | 10% |
| V18 | G2 rotation | 6x7 | 13 | CW, CCW, ALT, PAT | 13 | 11 | 6 | 38% | 0% | 3% |
| V24 | G2 rotation | 6x6 | 13 | CW, lock, CCW, ALT, PAT | 13 | 9 | 4 | 31% | 4% | 20% |
| V10 | G3 topology | 7x7 | 11 | CW, portal, seq | 13 | 11 | 10 | 54% | 0% | 3% |
| V13 | G3 topology | 6x7 | 11 | CW, portal, seq | 14 | 10 | 5 | 57% | 6% | 33% |
| V17 | G3 topology | 6x6 | 13 | CW, portal, seq | 15 | 13 | 8 | 60% | 0% | 33% |
| V21 | G3 topology | 6x6 | 11 | CW, portal, seq | 14 | 12 | 5 | 50% | 0% | 0% |
| V26 | G3 topology | 6x6 | 12 | CW, portal, seq | 15 | 9 | 5 | 53% | 0% | 0% |
| V09 | G4 crate | 6x7 | 11 + 1 crate | CW, crate | 15 | 12 | 2 | 40% | 0% | 0% |
| V25 | G4 crate | 6x6 | 10 + 1 crate | CW, crate | 10 | 7 | 1 | 70% | 1% | 20% |
| V19 | G4 crate_armor | 6x6 | 11 + 1 crate | CW, armor, crate | 18 | 15 | 7 | 56% | 0% | 0% |
| V27 | G4 crate_armor | 6x6 | 13 + 1 crate | CW, armor, crate | 19 | 15 | 1 | 53% | 0% | 0% |
| V08 | G4 crate_spin | 6x7 | 13 + 1 crate | CW, crate | 14 | 10 | 1 | 57% | 1% | 0% |

| Id | Impact of each advanced mechanic (difficulty lost without it; 99 = unsolvable without it) | Use in the solution |
|---|---|---|
| V20 | spinners 36.3 | - |
| V28 | spinners 38.8 | - |
| V05 | spinners 99 | - |
| V11 | spinners 99 | - |
| V23 | spinners 99 | - |
| V04 | spinners 99 | - |
| V03 | spinners 99 | - |
| V12 | spinners 99 | - |
| V02 | spinners 26.3; switch 99; gate 1.1 | - |
| V06 | spinners 99; switch 38.8; gate 27 | 14 switch decisions |
| V14 | spinners 99; switch 99; gate 23.9 | - |
| V16 | spinners 99; switch 99; gate 7.6 | 11 switch decisions |
| V22 | spinners 99; switch 34; gate 17.9 | 12 switch decisions |
| V01 | spinners 99; spinner rules 99 | - |
| V07 | spinners 99; spinner rules 23.4; lock 1.1 | - |
| V15 | spinners 99; spinner rules 21; lock 18.2 | - |
| V18 | spinners 99; spinner rules 17.8 | - |
| V24 | spinners 99; spinner rules 4.3; lock 15.8 | - |
| V10 | spinners 27; portal 15.7; Sequence 8.1 | 4 portal moves, 2 Sequence advances |
| V13 | spinners 99; portal 1.7; Sequence 16.9 | 3 portal moves, 3 Sequence advances |
| V17 | spinners 99; portal 18.4; Sequence 4.9 | 5 portal moves, 2 Sequence advances |
| V21 | spinners 34.9; portal 15.6; Sequence 7.5 | 4 portal moves, 3 Sequence advances |
| V26 | spinners 99; portal 1.1; Sequence 99 | 5 portal moves, 3 Sequence advances |
| V09 | spinners 99; crate 29.8 | 5 pushes, 3 losing pushes along the way |
| V25 | spinners 99; crate 19.1 | 1 pushes, 7 losing pushes along the way |
| V19 | spinners 99; armor 6.5; crate 44.2 | 2 rams, 6 pushes, 9 losing pushes along the way |
| V27 | spinners 99; armor 2.7; crate 28.9 | 1 rams, 6 pushes, 6 losing pushes along the way |
| V08 | spinners 99; crate 23.3 | 2 pushes, 5 losing pushes along the way |

| Id | Check nodes | Check ms desktop / x1 / x4 / x6 | SHOW A MOVE nodes | ms desktop / x4 | After a mistake nodes | ms desktop / x1 / x4 / x6 |
|---|---|---|---|---|---|---|
| V20 | 5 | 0.47 / 0.6 / 2.6 / 5.5 | 4 | 0.99 / 2.2 | 14 | 3.88 / 1.8 / 9.8 / 14.8 |
| V28 | 15 | 1.68 / 1.9 / 2.1 / 13.1 | 9 | 2.16 / 8.8 | 2 | 0.56 / 0.5 / 1.6 / 3.7 |
| V05 | 29 | 1.41 / 2.7 / 8.9 / 7 | 28 | 2.54 / 7.8 | 213 | 38.74 / 50.7 / 229.7 / 296.1 |
| V11 | 30 | 1.58 / 2.3 / 9.9 / 13.3 | 29 | 1.98 / 9.4 | 10 | 0.62 / 1 / 2.3 / 4.6 |
| V23 | 24 | 1.25 / 1.5 / 7.4 / 12.6 | 21 | 4.11 / 9.3 | 8 | 1.81 / 0.5 / 0.6 / 4.3 |
| V04 | 18 | 1.21 / 1.6 / 6.7 / 12.3 | 17 | 1.76 / 1.2 | 27 | 6.52 / 4.7 / 28.5 / 38.8 |
| V03 | 7 | 0.48 / 0.6 / 2.8 / 5 | 6 | 0.71 / 3.9 | 0 | 0 / - / - / - |
| V12 | 6 | 0.59 / 1 / 3.8 / 5.8 | 5 | 0.74 / 3.5 | 2 | 0.25 / 0.4 / 2.4 / 0.3 |
| V02 | 12 | 0.52 / 0.9 / 3.4 / 7 | 11 | 3.12 / 7.4 | 10 | 2.81 / 0.8 / 5.4 / 5.8 |
| V06 | 7 | 0.39 / 0.6 / 3 / 0.5 | 6 | 0.51 / 2.3 | 5 | 0.65 / 0.7 / 3.1 / 5.5 |
| V14 | 24 | 1.26 / 1.6 / 7.7 / 12.4 | 15 | 1.29 / 11 | 5 | 0.68 / 0.7 / 4 / 9.7 |
| V16 | 23 | 1.32 / 1.6 / 7.7 / 4.5 | 22 | 1.59 / 6.6 | 25 | 3.51 / 4 / 19.6 / 33.5 |
| V22 | 32 | 1.98 / 2.6 / 10.3 / 21.2 | 28 | 3.51 / 9.7 | 11 | 2.65 / 4.5 / 15.9 / 26.7 |
| V01 | 49 | 2.36 / 7.2 / 17.8 / 26.7 | 48 | 2.72 / 15.6 | 47 | 10.98 / 16.6 / 71.6 / 99.2 |
| V07 | 64 | 3.06 / 4.3 / 12.7 / 26.3 | 39 | 3.02 / 12.9 | 21 | 2.68 / 2 / 5.7 / 7.6 |
| V15 | 37 | 2.03 / 2 / 10 / 2 | 9 | 1.7 / 9.8 | 54 | 12.08 / 5.1 / 29.1 / 11.5 |
| V18 | 21 | 0.8 / 1.7 / 5.5 / 18.2 | 20 | 1.45 / 4.6 | 156 | 15.11 / 33.2 / 104.9 / 126.5 |
| V24 | 18 | 1.39 / 1 / 5.2 / 7.2 | 11 | 0.83 / 5.5 | 6 | 0.36 / 0.3 / 0.3 / 2.9 |
| V10 | 24 | 1.32 / 2.7 / 5.5 / 1.5 | 23 | 1.84 / 8.8 | 6 | 0.64 / 1.1 / 3.5 / 8.3 |
| V13 | 7 | 0.44 / 0.5 / 1.9 / 0.4 | 6 | 0.64 / 0.4 | 21 | 2.92 / 3.3 / 16.8 / 4.7 |
| V17 | 47 | 3.36 / 4 / 21.3 / 41 | 46 | 3.29 / 20.3 | 61 | 20 / 19.8 / 90.9 / 122.5 |
| V21 | 136 | 8.07 / 10.8 / 48.8 / 74.8 | 85 | 9.96 / 69 | 39 | 14.26 / 12.2 / 88.6 / 95.9 |
| V26 | 45 | 2.42 / 5.1 / 14.2 / 5.8 | 40 | 4 / 17.5 | 22 | 2.73 / 2.4 / 9.5 / 8 |
| V09 | 228 | 4.9 / 5.8 / 23.3 / 34.1 | 228 | 4.63 / 18.6 | 151 | 3.35 / 4.6 / 21.3 / 32.3 |
| V25 | 219 | 3.99 / 4.7 / 22.3 / 26.3 | 219 | 4.1 / 25.3 | 1499 | 28.19 / 44.1 / 157.2 / 246.1 |
| V19 | 1326 | 27.62 / 34.2 / 127.8 / 297.4 | 1326 | 29.45 / 152.7 | 1564 | 32.1 / 39.4 / 152.8 / 319.8 |
| V27 | 1568 | 37.25 / 43.6 / 209.6 / 295.4 | 1568 | 35.23 / 198.2 | 1182 | 27.04 / 30.4 / 157.6 / 248.2 |
| V08 | 651 | 16.34 / 19.3 / 87.9 / 131 | 651 | 23.16 / 97.9 | 295 | 7.3 / 8.6 / 29.6 / 88.4 |

#### G0
**V20** (G0_control, 7x7; test 2 P09 (Classic L169 geometry, flattened), rotated 180 + recoloured)
```
     .      .      .      .      .     G^      .
     .     R<     P>     Rv      .      .      .
     .    Y>@    P^@     Rv      .      .     P^
     .      .      .      .     Y>     R>    Bv@
    P>     R^      .     Yv     Gv      .      .
     .      .    Bv@     R<      .    G^@      .
   B^@     G<      .      .      .      .     B<
```
**V28** (G0_control, 7x7; test 2 P13 (Classic L165 geometry, flattened), rotated 180 + recoloured)
```
   Y>@      .      .     G>    Y>@     P^      .
    B^     G>      .      .     B>    Bv@      .
     .     Y<    Pv@      .      .      .     B<
     .      .     Yv      .     R<     Yv     G^
     .      .      .      .      .      .      .
    B^      .     Rv      .      .      .      .
    R<    G<@     Y<      .      .     Y>     B^
```
**V05** (G0_coupled, 6x6; generated (G0_coupled, seed 21, try 25))
```
    R<    Yv@    Rv@      .     Y<      .
     .      .      .      .    Rv@      .
     .    B>@     P>      .      .     R^
     .     B>      .      .    R>@    G<@
     .      .      .      .     P<    G^@
   Gv@    Y^@     G<      .      .    P^@
```
**V11** (G0_coupled, 6x6; generated (G0_coupled, seed 21, try 6))
```
     .      .      .      .      .      .
     .     G^      .      .     Pv      .
   G>@    R<@      .      .    R<@    Y>@
     .     B^    Gv@      .      .     Y<
     .    Bv@    P<@     P<      .      .
    Y>    R^@      .    P<@      .      .
```
**V23** (G0_coupled, 6x6; generated (G0_coupled, seed 21, try 18))
```
    P<      .      .      .     Rv      .
    Rv      .      .     B<      .      .
    Bv    B<@     Pv      .    Y<@    G^@
   R>@    Y^@      .      .      .      .
   Pv@      .     P>      .      .      .
   P>@    Y<@    P^@      .      .      .
```
**V04** (G0_late, 7x7; generated (G0_late, seed 11, try 7))
```
     .      .      .      .      .    R>@     Bv
     .      .     B^      .     P<     G<      .
   G>@     B>    Bv@     P^    P>@      .     Pv
     .      .     B>     Gv      .      .      .
     .      .      .      .      .     B^      .
     .      .     G^      .      .    R^@      .
     .      .      .     R<     B>    P<@     P>
```
**V03** (G0_live, 6x6; live VERY HARD (FriendGenerator seed 240011))
```
    Gv    Yv@      .    Rv@     P<      .
     .     B^     Y<    Gv@      .      .
     .      .      .    Pv@     Y>     Gv
     .      .     B^     G^      .      .
     .     Y^     G>      .      .     G>
     .    P>@    B>@      .     P>      .
```
**V12** (G0_live, 6x6; live VERY HARD (FriendGenerator seed 240157))
```
     .     Yv      .      .      .     B<
    P^    G>@      .    B^@     Pv     G^
    Y^      .      .      .    R>@      .
   P>@      .     Y>     P>     G>     Y^
    B^      .      .      .     R>    Gv@
    G^      .      .      .      .    B<@
```
#### G1
**V02** (G1_remote, 6x6; generated (G1_remote, seed 11, try 15))
```
     .      .      .      .      .      .
  Rv&B   Y^&A     R<    Gv@  Y<@+C  Pv@+C
  Gv&B   G>%A      .      .     XC      .
     .   B>%B      .    R>@     Y>      .
     .      .      .    Rv@      .      .
  R^&A      .      .   B<&A      .      .
```
**V06** (G1_remote, 6x6; generated (G1_remote, seed 11, try 8))
```
   P^@  R>@+C     B<    Rv@     B^      .
     .     Pv   G^+C      .      .      .
   B>@   Gv&A      . Y<&A+C      .     XC
     .      .      .      .      .      .
     .      .     P^      .   R^&A   R>%A
    G>      .     R^      .      .      .
```
**V14** (G1_remote, 6x6; generated (G1_remote, seed 11, try 9))
```
     .      .      .   G<&B  R>@+C      .
  G<%A   R<&A    Y>@    P<@  P<@+D    Bv@
     . R>&B+C      .      .      .     XC
  Y^%B      .      .      .      .      .
  P>&B      .      .      .     XD      .
     .      .      . Y^&A+D      . Y^&A+C
```
**V16** (G1_remote, 6x6; generated (G1_remote, seed 12, try 1))
```
     .      .      .      .      .      .
     .      .     R^    B>@ Bv&A+C      .
Gv&B+D    G^@    P<@     XD   B>%A     G>
   P^@     G>     P^ B>&B+C      . B^&B+D
     .      .      .      .      .      .
     .   Y^%B   R<&A     G<  B^@+C     XC
```
**V22** (G1_remote, 7x7; generated (G1_remote, seed 11, try 24))
```
    Y>      .      .      .      .      .   P^%A
     .      .    P>@     XC   P<+D   R<&A     B<
     .      .  P>@+D      .      .     XD      .
     .     R^   Y<&A   R<+C  Y^@+C     Yv      .
     .      .      .      .      .      .      .
     .      .      .      .      .      .    R^@
     .      .      .      .      .     G>     Y>
```
#### G2
**V01** (G2_rotation, 6x6; generated (G2_rotation, seed 11, try 25))
```
     .      .      .      .      .     G^
     .    Y>@     P>      .   Pv@-   Y>@~
     .    R>@      .     Y>      .      .
     .      .     G^   Rv@~    P<@      .
     .      .      .     R>   Gv@*   P>@-
     .      .      .      .     B<      .
```
**V07** (G2_rotation, 6x6; generated (G2_rotation, seed 11, try 9))
```
     .     G>      . P^@~#B      .      .
   Yv@     P^      .   Rv@~   Yv@-     Pv
  P^@~   G>@*     Y^   Y<@*      .      .
     .      .   R^#R      .      .      .
    Rv    B^@      .      .      .      .
     .      .      .      .      .      .
```
**V15** (G2_rotation, 6x7; generated (G2_rotation, seed 11, try 2))
```
     .   P^@-   R>@*      .      .      .
     .      .      .      .      .      .
     .      .      .      .      .      .
     .      .     P^     R>      .     R^
     .    Pv@ Pv@*#G   G^@-    B>@    G<@
     .      .     Pv      .      .     B^
  Y>@-  P^@#R      .      .      .      .
```
**V18** (G2_rotation, 6x7; generated (G2_rotation, seed 11, try 15))
```
     .      .      .      .      .      .
     .      .      .      .      .      .
     .     Y^      .      .     G<      .
    Y^    R<@      .      .      .      .
     .   Rv@~      .   R>@-      .      .
     .   P>@*    B<@   Pv@~      .      .
     .     G<     Y<    R<@      .    Y<@
```
**V24** (G2_rotation, 6x6; generated (G2_rotation, seed 11, try 5))
```
     .      .      .      .   R>@~   B<@~
    Pv      .     Y<      .     B<   B^@~
  Gv@*   Yv@*    P<@   Rv@-      .      .
    Gv      .      . Y^@~#R     P^      .
     .      .      .      .      .      .
     .      .      .      .      .      .
```
#### G3
**V10** (G3_topology, 7x7; generated (G3_topology, seed 11, try 19))
```
   Y>@      .    R^@      .      .      .      .
    G<    G<@    G<@     OA      .      .   B<:^
     .      .    P>@      .      .      .     Y^
  B^:<      .     OA      .      .      .      .
     .      .      .      .      .      .      .
     .      .      .     B^      .      .      .
    P^      .      .      .      .      .      .
```
**V13** (G3_topology, 6x7; generated (G3_topology, seed 11, try 22))
```
     .   B<:>      .      .      .      .
  B^:<      .      .      .      .      .
     .      .      .      .     OA      .
    OA     G^      .     P<     B^      .
     .      .      .      .      .      .
     .      .      .     B>    R^@   P>:^
    P>      .      .      .    B>@    P<@
```
**V17** (G3_topology, 6x6; generated (G3_topology, seed 11, try 21))
```
    Pv     OB      .     P<    Yv@   B>:v
    P<      .    B>@      .    Gv@      .
   Yv@      .      .      .     OA      .
     .     G<     OB      .      .      .
    OA      .      .      .    B<@      .
    Y>   G>:v      .      .     Yv      .
```
**V21** (G3_topology, 6x6; generated (G3_topology, seed 11, try 5))
```
     .      .   B>:v     OA      .      .
     .      .      .      .      .    Y^@
     .   G^:>      .      .      .    R>@
     .      .    G<@     R^      .    Pv@
    OA      .    Pv@     Y^      .      .
     .      .      .   G<:^      .     B<
```
**V26** (G3_topology, 6x6; generated (G3_topology, seed 11, try 26))
```
     .     OA     Y^      .      .      .
     .      .    B^@    R<@      .     OB
     .      .     OA    B>@   P>:^      .
     .      .      .      .     B^      .
     .      .     B<    R^@   R^:<      .
     .     P^   G>:^    G<@     OB      .
```
#### G4
**V09** (G4_crate, 6x7; generated (G4_crate, seed 11, try 9))
```
    P<    G^@     Rv      .      .      .
     .      M     Pv      .      .     G<
     .      .      .      .      .     Y^
     .      .      .      .      .      .
    B^      .     Y<      .      .      .
   G^@      .      .      .      .      .
    P>      .      .      .      .      .
```
**V25** (G4_crate, 6x6; generated (G4_crate, seed 11, try 2))
```
     .      .      .      .      .      .
     .     B<      .      .      .     Y<
     .     Y^      .     R^      .      .
     .     Y^      M    P<@      .      .
     .      .     G^      .      .      .
     .      .      .      .     Pv    G^@
```
**V19** (G4_crate_armor, 6x6; generated (G4_crate_armor, seed 11, try 6))
```
     .      .     Rv      .      .      .
     .      .    Rv=      M     G<     R<
     .    G>@      .      .      .      .
     .      .      .     P^      .     P<
     .      .      .      .      .      .
   G<@    R^@    B>=      .      .      .
```
**V27** (G4_crate_armor, 6x6; generated (G4_crate_armor, seed 11, try 7))
```
    P<      .    G<=    Y>@      .     G<
   R>@     Gv     R^      M     G<      .
     .      .      .      .      .      .
     .      .      .      .     R<      .
     .      .      .      .      .      .
     .     Y>      .      .    Rv@     Rv
```
**V08** (G4_crate_spin, 6x7; generated (G4_crate_spin, seed 11, try 1))
```
    Yv      .      .     G<      .      .
     .      .      .      .    Y<@     R>
     .      M      .     B^      .     G<
     .      .     B^    Y^@    B<@      .
     .      .      .      .      .      .
    Gv     R<      .      .      .      .
     .     Y^      .      .      .      .
```

Token legend:
- `R>`: red arrow, right. `@` clockwise spinner, `@-` counter-clockwise, `@~` alternating, `@*` pattern.
- `#G`: locked until no green block remains.
- `%A`: switch A. `&A`: flips when switch A leaves.
- `XC`: chain gate C. `+C`: link of gate C.
- `=`: armored. `OA`: portal pair A. `:^`: Sequence block, next arrow up. `M`: Movable crate.

## 5. Solver and mobile performance

**Measured:**
- **Native desktop** (Godot 4.3): the builder, median of 5.
- **The exported Web build** (WebAssembly) in headless Chromium at iPhone SE size (`&bench=1`), at CPU throttling ×1, ×4 and ×6 (Chrome DevTools emulation).

Throttled Chromium is a **simulation of a slower device, not an iPhone measurement**. No real-device timing has been done yet.

| | Recipient check | SHOW A MOVE (solution states) | SHOW A MOVE after a mistake |
|---|---|---|---|
| Max nodes (all 28) | 2,868 | 2,868 | see table |
| Max, Web ×1 | 43.6 ms | 41.9 ms | 50.7 ms |
| Max, Web ×4 (simulation) | 209.6 ms | 198.2 ms | 229.7 ms |
| Max, Web ×6 (simulation) | 297.4 ms | 326.7 ms | 319.8 ms |

**What the measurements show:**
- **Web ×4 vs native desktop.** Web ×4 took 4–7× the native desktop time across the boards. That's why the acceptance budget is 40 ms native: it keeps ×4 under ~300 ms.
- **The first set failed the budget.** Three boards of the first 28 exceeded it, and were replaced by candidates that passed every rule:
  - a late-traps board: SHOW A MOVE after a mistake, 1.5 s at ×4;
  - a coupled board: 0.75 s at ×4;
  - a crate + spinners board: ~0.3 s on every measure.
- **The expensive case is SHOW A MOVE right after a mistake.** It has to prove that every move from a dead position loses. Boards whose mistakes surface late, which is what the late-traps recipe wants, have large dead positions. This is a real tension between "costly recovery" and phone performance.
- **The most expensive boards to check are the crate boards** (up to 2,868 nodes, because the search has to be cycle-safe). They still fit the budget.


## 6. Validity and duplicate checks (`VhPilot4Check`: 439 / 439 passed)

- **The file.** 28 boards in groups G0 8 and G1–G4 5 each, ids V01–V28, live VERY HARD assistance (UNDO ×3, SHOW A MOVE ×1, HAMMER ×0).
- **Every board:**
  - exact, every cell parsed as the page parses it, and at most 7×7;
  - solvable within the recipient's 60,000 nodes;
  - mechanics and first level recorded truthfully;
  - every present advanced mechanic with impact ≥ 1.0;
  - within the 20,000-node working budget and the mobile time budget.
- **No duplicates.** No candidate matches another candidate, a campaign level, an earlier test or a lab board, under rotation, reflection, recolouring or relabelling. The two controls match their earlier test boards, as intended.
- **Every board played to the end in the real SocialPlay** (the play screen the page uses), move by move. The page's action log identified every tapped block, including pushes, rams and Sequence advances.
- **The page:**
  - campaign question → eligible boards only (past level 150: no switch, gate, armor, portal, Sequence or crate boards);
  - balanced order: each of the first five rounds holds one board of every group;
  - reminder card: neutral rules, never the group;
  - clock and GIVE UP (two taps), then the five questions in order;
  - the action log, resume after a reload, the hardest-puzzle question, and results that name the groups only at the end;
  - the bench mode.
- **Browser** (`web_vhtest4_page_test.mjs`: 14 / 14). Real touches at iPhone SE size:
  - campaign question → card → puzzle → GIVE UP twice → the five questions → puzzle 2 solved by touches → questions;
  - state saved in the test's own browser storage;
  - no page errors and no network requests.
  - The GIVE UP button sits above the board, clear of every game button.
- **Unchanged:**
  - tests 1–3: `VhHumanTestCheck` 100 / 100, and `web_vhtest_page_test.mjs` 17 / 17 on the same build;
  - `RevealMvpTest`, `FriendFlowTest` (149), `SocialPlayTest`: passed.

## 7. Human test procedure (not started)

**Build.** A development Web build (preset "Web", no custom features), so developer pages are on. It must **not** replace the Social QA or Production uploads.

**Tester URL:** `…/index.html?vhtest4=1`. The flow:
1. The tester answers how far they have played.
2. Up to 28 puzzles, in a balanced random order.
3. Before each puzzle: a one-line reminder of its rules.
4. While playing: a clock, UNDO ×3, SHOW A MOVE ×1, no HAMMER, RESTART, and GIVE UP (two taps).
5. After each puzzle: difficulty (EASY–VERY HARD), compared with Level 300 (easier / similar / harder / not sure), enjoyment 1–5, sense of achievement 1–5, random or unfair (yes / no).
6. At the end: which puzzle was hardest, and why.
7. **COPY RESULTS**, pasted into the chat.

**Breaks.** Testers can stop and continue later, and the card at the halfway point suggests a break. I recommend two sessions of about 14 puzzles.

**Testers.** At least 6:
- at least 2–3 experts who have finished all 300 levels (they see all 28);
- intermediate players see only the groups they know.

**Recorded automatically:**
- time and time to the first move;
- the longest pause and pauses ≥ 10 s (recorded, not used as a pass / fail rule);
- moves, pushes, rams, Sequence advances, portal uses and blocked taps;
- restarts, UNDO, SHOW A MOVE and give-ups;
- the full action log, for offline replay.

**Decision rules.** Use the go / no-go criteria from the Gate 0 proposal, judged per group against G0, with human ratings first and metrics only as support. This is an exploratory screen: no statistical proof is claimed. A group that passes earns a second validation with new testers.

## 8. Movable Crate

**Value for planning.**
- In all five G4 boards the crate matters a lot: removing it lowers difficulty by 19–44. **None of the five can be won without pushing.**
- The solutions contain 1–6 pushes each, with 3–9 losing pushes along the way: a push that looks fine and makes a later escape impossible.
- That is exactly the "anticipate where it will be" decision you asked for.
- **Repetitive pushing** is capped by the recipe at 6 pushes per solution. The crate + armor boards V19 and V27 sit at that cap (6 pushes in 18–19 moves), so watch them for "effort rather than strategy" in the human test.

**Combinations.**
- **Crate + armor** (V19, V27): the longest solutions (18–19 moves) with 15 decision points.
- **Crate-led** (V09, V25): fewer decisions. V25 is the lightest board of the pilot (10 moves, 70% risk-free), which makes it a useful lower anchor.

**Deadlocks.**
- Every board starts solvable.
- SHOW A MOVE on crate boards follows a real solution, so it can't push back and forth.
- Dead positions after a losing push are expected and are the puzzle. The game already says "No moves left - tap Undo/Restart" when nothing can move.

**Solver cost.** The highest of the pilot: up to 2,868 nodes and 43.6 ms (×1) for the check, because the search has to be cycle-safe. Generation was also the slowest (~20 s per try).
- It still fits every budget after filtering.
- 4 of 6 crate + spinners candidates were rejected for time. More spinners plus a crate multiplies the search.
- **Recommendation:** crate boards are viable, but every future crate board needs the time measurement, not only the node count.

## 9. Twins and Magnet (assessment only; not in this pilot)

Measured on the campaign levels that use them:

**Magnet** (levels 76–99, 22 levels).
- Essential (unsolvable without it) in 21 of the 22. Late levels are decision-rich: L98 has 3 magnets, 16 decision points and difficulty 48.9.
- Solver cost is low: at most 567 nodes (32 ms native).
- Like the crate, a pull changes the geometry ("which block slides in when this leaves?"), so it is a strong candidate for a later group.
- **Constraints:**
  - plain arrows only;
  - no portals, crates or hidden arrows on the board;
  - campaign / lab parsing only (the Friend parser rejects `*`).
- Code comments still call it "prototype / never in the campaign", but the frozen levels use it. **Recommend** a later pilot group: Magnet + spinners (+ switch).

**Twins** (levels 176–197, 10 levels).
- Impact is small or negative in most levels (−2.5 to +1.1). The exceptions are the two lessons (essential) and L197 (+9.9).
- A bonded pair is one move instead of two, so Twins usually *remove* a decision rather than add one.
- **Constraints:** two adjacent plain arrows, no portals, campaign parsing only.
- **Recommend:** low priority; test only in a combination with evidence of value, such as L197.

## 10. Known limitations and risks

1. **No real-device timing yet.** All phone figures are a simulation (×4 / ×6 throttled Chromium). The worst board reaches ~320 ms at ×6.
   - **Before testers start:** open `?vhtest4=1&bench=1` once on a real iPhone SE and read `window.chainEscapeVhBench` (Safari Web Inspector), or ask me to add an on-screen summary.
2. **Late-traps shortfall.** Only one late-traps board fits the time budget (V04), and its heuristic win rate (53%) is high. The "costly recovery" idea is under-represented: 3 coupled + 1 late instead of 2 + 2. Making late traps phone-safe would need a cheaper SHOW A MOVE after mistakes, which is a separate design decision.
3. **Proxies are not people.** Risk-free share, decision points and heuristic win rates were used only to filter out boards that were obviously easy or broken; they do not predict human ratings (tests 1–3).
4. **Spinner-rule boards (G2)** use all four rules at once on four of five boards. That is closer to campaign Chapter 4–6 vocabulary than to Level 300, so the reminders matter.
5. **Small sample.** About 10–15 expert playthroughs per group. The pilot is a screen for promising recipes, not proof.
6. **Board size** is 6×6 to 7×7 (crate and topology boards 6×6 to 7×7), the same as the campaign maximum. Readability was checked in screenshots at iPhone SE size.

## 11. Recommendation

1. **Run one real-iPhone bench** (`&bench=1`) before the human test.
2. **Run the human pilot as described in §7.** At least 6 testers, including 2–3 who have completed all 300 levels.
3. **Groups most worth watching:**
   - **G2 rotation logic:** the lowest risk-free share, 31–43%;
   - **G4 crate + armor:** long, decision-rich solutions;
   - **G1 remote control:** essential switches and gates with low heuristic win rates.

   Each of these targets the failure mechanism behind the 0 / 92 result.
4. **Watch G3 (portals + Sequence) for confusion rather than difficulty.** It depends most on players having internalised levels 201–250.
5. **No format or backend change** before a group passes with real people.
