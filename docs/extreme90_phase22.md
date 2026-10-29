# EXTREME Time Attack — Phase 22: continued bank development

Development only. Production, the 300 frozen levels, saves / progression,
campaign timing and Personal Best, Time Attack behaviour, the Social MVP and
Challenge a Friend are untouched. No new mechanic, feature or UI.

Product decision recorded: the initial bank target is **50 human-approved
EXTREME puzzles** (not 150–200); technical qualification never counts as
approval.

## A. Git and backup

- Branch `claude/elegant-fermat-0jrmxo`; starting HEAD `cce092a` (Phase 21);
  clean tree; upstream `origin/claude/elegant-fermat-0jrmxo`
  (`https://github.com/zaknounloay-bot/ChainEscape`).
- Before Phase 22, `origin` was at `8198480`, a direct ancestor; local
  `427eb18` (Phase 20) and `cce092a` (Phase 21) were **not** on GitHub.
- A normal push (no force) moved `origin` `8198480 → cce092a`;
  `git ls-remote` confirms `cce092aeadb8…`, and both commits are on
  `origin`. **Phases 20 and 21 are backed up.**

## Phase 21 configuration — verified, with discrepancies

Matches the brief: 24 cores in 6 families; 48 runs, 2 seeds per core;
`--ops=v20`; 12 min per run (batch 40, beam 5, patience 8); round 2 only if
fewer than 10 are accepted; at most 40 full reports.

Discrepancies, reported rather than changed:
1. The acceptance rule is Category A **and** B (A — technical; B —
   strategic), not "A or B". Kept as established.
2. Phase 21's round runner and stage-2 driver were scratch scripts, never
   committed. They are now in the repository unchanged in logic
   (`tools/extreme90_round.sh`, `tools/extreme90_stage2.py`; the data
   directory and the Godot binary are arguments) and were used for both
   Phase 22 rounds.
3. "At most one board per core" and "three per family" are per phase in the
   Phase 21 rules; across phases, the bank-wide overlap check (< 0.40) is
   the only guard. Kept as established — see the similarity notes below.

## Phase 21 human review — recorded

One joint evaluation by the user and his older son on a real iPhone (not two
independent tests): N39, N40, N42, N43, N44, N45, N47 PROMISING →
provisional; N41 (EASY) and N46 (MEDIUM) TOO EASY → downgraded, not counted
as EXTREME. Recorded in `data/dev/extreme90_p21/human_p21.json` and
`docs/extreme90_phase21.md`; boards, ids and fingerprints unchanged.

## Protocol (`data/dev/extreme90_p22/protocol.json`)

The Phase 21 protocol unchanged — the same 24 cores (copied seed files),
generator, budget, stage-2 procedure and acceptance rules — with new RNG
seeds 13 (round 1) and 14 (round 2). The similarity reference is every board
record in `data/dev`, now including N39–N47.

## B. Generation results

| Core | Family | Seed | Evaluated | Seconds | Stop | Qualifying (raw) | Best distinct / steps / shortcut |
|---|---|---|---|---|---|---|---|
| POR_p19PX | portal | 13 | 1333 | 421 | patience | 491 | 5 / 17 / 0.00 |
| POR_p19PX | portal | 14 | 1398 | 472 | patience | 472 | 5 / 16 / 0.00 |
| POR_p18PM | portal | 13 | 1001 | 720 | time | 0 | 2 / 20 / 0.03 |
| POR_p18PM | portal | 14 | 1211 | 731 | time | 89 | 5 / 19 / 0.05 |
| POR_p18PS | portal | 13 | 2351 | 326 | patience | 0 | 1 / 13 / 1.00 |
| POR_p18PS | portal | 14 | 1659 | 348 | patience | 0 | 2 / 13 / 0.35 |
| POR_p18SPP | portal | 13 | 1723 | 573 | patience | 241 | 5 / 13 / 0.10 |
| POR_p18SPP | portal | 14 | 1451 | 586 | patience | 342 | 6 / 13 / 0.00 |
| ARM_p19AS | armor | 13 | 1199 | 217 | patience | 0 | 2 / 13 / 0.20 |
| ARM_p19AS | armor | 14 | 2057 | 413 | patience | 0 | 3 / 14 / 0.12 |
| ARM_p18AR2 | armor | 13 | 1506 | 452 | patience | 286 | 6 / 19 / 0.00 |
| ARM_p18AR2 | armor | 14 | 1182 | 427 | patience | 230 | 6 / 18 / 0.03 |
| ARM_p19MAS | armor | 13 | 1275 | 385 | patience | 186 | 4 / 17 / 0.00 |
| ARM_p19MAS | armor | 14 | 1779 | 465 | patience | 495 | 4 / 17 / 0.05 |
| ARM_bankI2 | armor | 13 | 1302 | 375 | patience | 202 | 6 / 10 / 0.03 |
| ARM_bankI2 | armor | 14 | 2320 | 618 | patience | 474 | 6 / 14 / 0.03 |
| SWI_p20SG5 | switch_gate | 13 | 1154 | 217 | patience | 0 | 3 / 14 / 0.07 |
| SWI_p20SG5 | switch_gate | 14 | 949 | 145 | patience | 1 | 4 / 12 / 0.17 |
| SWI_p19SG3 | switch_gate | 13 | 1155 | 198 | patience | 0 | 3 / 11 / 0.33 |
| SWI_p19SG3 | switch_gate | 14 | 1033 | 191 | patience | 0 | 2 / 11 / 0.17 |
| SWI_bankD | switch_gate | 13 | 951 | 747 | time | 76 | 6 / 14 / 0.03 |
| SWI_bankD | switch_gate | 14 | 865 | 745 | time | 42 | 5 / 14 / 0.12 |
| SWI_bankA | switch_gate | 13 | 1201 | 423 | patience | 149 | 5 / 11 / 0.07 |
| SWI_bankA | switch_gate | 14 | 1890 | 466 | patience | 800 | 6 / 12 / 0.00 |
| MAG_p18MG | magnet | 13 | 1855 | 610 | patience | 333 | 6 / 14 / 0.00 |
| MAG_p18MG | magnet | 14 | 1116 | 355 | patience | 127 | 4 / 15 / 0.12 |
| MAG_p18MX1 | magnet | 13 | 1128 | 387 | patience | 143 | 4 / 15 / 0.12 |
| MAG_p18MX1 | magnet | 14 | 1107 | 380 | patience | 157 | 4 / 15 / 0.07 |
| MAG_p18MX3 | magnet | 13 | 1458 | 729 | time | 166 | 4 / 20 / 0.00 |
| MAG_p18MX3 | magnet | 14 | 1388 | 712 | patience | 0 | 3 / 19 / 0.00 |
| MAG_p17E | magnet | 13 | 1308 | 422 | patience | 253 | 6 / 15 / 0.00 |
| MAG_p17E | magnet | 14 | 1943 | 728 | time | 695 | 6 / 14 / 0.00 |
| SPI_p17A | spinner | 13 | 1608 | 728 | time | 365 | 6 / 21 / 0.00 |
| SPI_p17A | spinner | 14 | 1690 | 729 | time | 215 | 6 / 19 / 0.03 |
| SPI_p17H | spinner | 13 | 1421 | 520 | patience | 449 | 6 / 15 / 0.00 |
| SPI_p17H | spinner | 14 | 1551 | 687 | patience | 334 | 6 / 15 / 0.00 |
| SPI_p17C2 | spinner | 13 | 2122 | 726 | time | 298 | 6 / 15 / 0.00 |
| SPI_p17C2 | spinner | 14 | 1276 | 377 | patience | 0 | 5 / 15 / 0.12 |
| SPI_bankB | spinner | 13 | 1327 | 734 | time | 333 | 6 / 13 / 0.12 |
| SPI_bankB | spinner | 14 | 1083 | 456 | patience | 257 | 5 / 13 / 0.00 |
| SEQ_p19SQX2 | sequence | 13 | 1817 | 711 | patience | 0 | 3 / 19 / 0.00 |
| SEQ_p19SQX2 | sequence | 14 | 1317 | 416 | patience | 0 | 2 / 20 / 0.00 |
| SEQ_p18MS2 | sequence | 13 | 2265 | 730 | time | 751 | 6 / 23 / 0.00 |
| SEQ_p18MS2 | sequence | 14 | 1707 | 701 | patience | 0 | 3 / 30 / 0.00 |
| SEQ_bankH2 | sequence | 13 | 1250 | 744 | time | 233 | 6 / 18 / 0.00 |
| SEQ_bankH2 | sequence | 14 | 1339 | 754 | time | 67 | 5 / 20 / 0.15 |
| SEQ_p17G | sequence | 13 | 1596 | 638 | patience | 529 | 6 / 13 / 0.00 |
| SEQ_p17G | sequence | 14 | 934 | 332 | patience | 150 | 6 / 13 / 0.00 |


Totals: 48 runs, 69551 boards evaluated, 6.9 CPU-hours of search, 35 runs with qualifying boards, 10431 qualifying boards (raw), 69 stage-2 candidates.

Round 1 (seed 13): 18 of 24 runs qualified, 36 candidates, 4 after the
pre-filter, 4 reports, 1 technically qualified. Round 2 (seed 14, run
because fewer than 10): 17 of 24 runs qualified, 33 candidates, 5 after the
pre-filter, 5 reports, 3 technically qualified. Budget spent with **4
technically qualified**, 9 of 40 reports used — **below the 5–10 target**.

### Every candidate and decision

| Candidate | Stage | Decision | Reason |
|---|---|---|---|
| SPI_p17A_s13_1 | prefilter | dropped | overlap 0.47 with N47 |
| SPI_p17A_s13_2 | prefilter | dropped | overlap 0.50 with N47 |
| SPI_p17H_s13_1 | prefilter | dropped | overlap 0.42 with N29 |
| SPI_p17H_s13_2 | prefilter | dropped | overlap 0.44 with N5 |
| SEQ_p17G_s13_1 | prefilter | dropped | overlap 0.56 with N28 |
| SEQ_p18MS2_s13_2 | prefilter | dropped | overlap 0.89 with the better candidate SEQ_p18MS2_s13_1 |
| SEQ_p17G_s13_2 | prefilter | dropped | overlap 0.47 with N28 |
| POR_p19PX_s13_1 | prefilter | dropped | overlap 0.55 with N37 |
| POR_p19PX_s13_2 | prefilter | dropped | overlap 0.48 with N37 |
| MAG_p17E_s13_1 | prefilter | dropped | overlap 0.47 with N27 |
| SPI_p17C2_s13_2 | prefilter | dropped | overlap 0.88 with the better candidate SPI_p17C2_s13_1 |
| MAG_p17E_s13_2 | prefilter | dropped | overlap 0.53 with N27 |
| ARM_p19MAS_s13_1 | prefilter | dropped | overlap 0.41 with N35 |
| ARM_p19MAS_s13_2 | prefilter | dropped | overlap 0.41 with N35 |
| MAG_p18MX3_s13_1 | prefilter | dropped | overlap 0.41 with N31 |
| ARM_p18AR2_s13_2 | prefilter | dropped | overlap 0.94 with the better candidate ARM_p18AR2_s13_1 |
| MAG_p18MX3_s13_2 | prefilter | dropped | overlap 0.42 with N38 |
| SEQ_bankH2_s13_1 | prefilter | dropped | overlap 0.52 with N21 |
| SEQ_bankH2_s13_2 | prefilter | dropped | overlap 0.43 with N21 |
| MAG_p18MX1_s13_1 | prefilter | dropped | overlap 0.46 with N44 |
| MAG_p18MX1_s13_2 | prefilter | dropped | overlap 0.42 with N46 |
| MAG_p18MG_s13_1 | prefilter | dropped | overlap 0.45 with N38 |
| SWI_bankD_s13_2 | prefilter | dropped | overlap 0.70 with the better candidate SWI_bankD_s13_1 |
| POR_p18SPP_s13_1 | prefilter | dropped | overlap 0.43 with N34 |
| POR_p18SPP_s13_2 | prefilter | dropped | overlap 0.43 with N34 |
| MAG_p18MG_s13_2 | prefilter | dropped | overlap 0.45 with N32 |
| SPI_bankB_s13_1 | prefilter | dropped | overlap 0.47 with N43 |
| SPI_bankB_s13_2 | prefilter | dropped | overlap 0.47 with N43 |
| ARM_bankI2_s13_1 | prefilter | dropped | overlap 0.40 with N43 |
| ARM_bankI2_s13_2 | prefilter | dropped | overlap 0.40 with N43 |
| SWI_bankA_s13_1 | prefilter | dropped | overlap 0.40 with N42 |
| SWI_bankA_s13_2 | prefilter | dropped | overlap 0.40 with N42 |
| ARM_p18AR2_s13_1 → N48 | report | ACCEPTED |  |
| SWI_bankD_s13_1 | report | rejected | the TIME UP check takes 127.5 ms in its worst position (> 40) |
| SPI_p17C2_s13_1 | report | rejected | solve 42.1 ms (> 40) |
| SEQ_p18MS2_s13_1 | report | rejected | filler: 1 trivial removals ['r6c2 M'] |
| SPI_p17H_s14_1 | prefilter | dropped | overlap 0.48 with N29 |
| SPI_p17A_s14_1 | prefilter | dropped | overlap 0.47 with N47 |
| SPI_p17H_s14_2 | prefilter | dropped | overlap 0.48 with N29 |
| MAG_p17E_s14_1 | prefilter | dropped | overlap 0.55 with N27 |
| MAG_p17E_s14_2 | prefilter | dropped | overlap 0.65 with N27 |
| SPI_p17A_s14_2 | prefilter | dropped | overlap 0.44 with N47 |
| SEQ_p17G_s14_1 | prefilter | dropped | overlap 0.40 with N9 |
| POR_p18PM_s14_2 | prefilter | dropped | overlap 0.82 with the better candidate POR_p18PM_s14_1 |
| POR_p19PX_s14_2 | prefilter | dropped | overlap 0.42 with N37 |
| SEQ_p17G_s14_2 | prefilter | dropped | overlap 0.47 with N4 |
| ARM_p19MAS_s14_1 | prefilter | dropped | overlap 0.41 with N35 |
| ARM_p18AR2_s14_1 | prefilter | dropped | overlap 0.52 with N39 |
| POR_p18SPP_s14_1 | prefilter | dropped | overlap 0.48 with N34 |
| POR_p18SPP_s14_2 | prefilter | dropped | overlap 0.48 with N34 |
| SEQ_bankH2_s14_1 | prefilter | dropped | overlap 0.40 with N30 |
| ARM_p18AR2_s14_2 | prefilter | dropped | overlap 0.52 with N39 |
| SEQ_bankH2_s14_2 | prefilter | dropped | overlap 0.42 with N30 |
| SWI_bankD_s14_1 | prefilter | dropped | overlap 0.40 with N25 |
| MAG_p18MX1_s14_1 | prefilter | dropped | overlap 0.48 with N46 |
| MAG_p18MX1_s14_2 | prefilter | dropped | overlap 0.55 with N46 |
| ARM_bankI2_s14_1 | prefilter | dropped | overlap 0.42 with N17 |
| ARM_bankI2_s14_2 | prefilter | dropped | overlap 0.42 with N43 |
| SWI_bankA_s14_1 | prefilter | dropped | overlap 0.56 with N42 |
| SWI_bankA_s14_2 | prefilter | dropped | overlap 0.50 with N42 |
| SPI_bankB_s14_1 | prefilter | dropped | overlap 0.50 with N43 |
| MAG_p18MG_s14_1 | prefilter | dropped | overlap 0.50 with N32 |
| MAG_p18MG_s14_2 | prefilter | dropped | overlap 0.50 with N32 |
| SPI_bankB_s14_2 | prefilter | dropped | overlap 0.50 with N43 |
| POR_p18PM_s14_1 → N49 | report | ACCEPTED |  |
| ARM_p19MAS_s14_2 → N50 | report | ACCEPTED |  |
| SWI_bankD_s14_2 | report | rejected | the TIME UP check takes 64.5 ms in its worst position (> 40) |
| POR_p19PX_s14_1 → N51 | report | ACCEPTED |  |
| SWI_p20SG5_s14_1 | report | rejected | a simple greedy player wins 38% (> 20%): a shortcut |

Reports used: 9 of 40; technically qualified 4.

Main reasons: **55 of the 60 pre-filter drops were boards too close
(>= 0.40) to an existing bank board**, only 5 were same-core variants — the
24 cores, searched four times now (Phases 21–22, 4 seeds), are largely
exhausted. At the report: 3 Category A failures (TIME UP check 127.5 ms and
64.5 ms, solve 42.1 ms — measured once, not re-run), 1 filler (a crate that
changes nothing), 1 greedy shortcut (38 % > 20 %).

## C. The Phase 22 candidates

All four are **TECHNICALLY QUALIFIED** (Category A and B pass, every
mechanic essential, no filler, overlap < 0.40, exact TIME UP continuation
with UNDO) — **not human-approved**.

| ID | Family / core | RNG seed | Grid / pieces | Mechanics | Strategic concept | Fingerprint |
|---|---|---|---|---|---|---|
| N48 | D/C rammer + magnet / ARM_p18AR2 | 13 | 7×7 / 17 | armor, magnet | the magnet brings the rammer: a pull drags a block into the lane of a shell - or into a lane where it is only in the way (the same core and idea as N39, a different board: overlap 0.39) | `87f57a0e9a27afac445022e965f3e2f9e53cef379f9a799c360ff7def04fbe18` |
| N49 | B/A portal + movable + Sequence / POR_p18PM | 14 | 7×7 / 13 | portal, movable, sequence | the crate goes through the portal: a Sequence pusher sends it to the far side of the board, where it blocks a different lane - and every push also advances the pusher's own arrow | `773dba8256092fb58f7e31bf4c9beeca3b27c84800de4e1540ae28f954bad6a8` |
| N50 | A/E crate + switch + armor / ARM_p19MAS | 14 | 7×7 / 14 | movable, switch, armor | push, turn, ram: a block pushes the crate out of a column, is turned around by its switch and must then crack the shell behind it - turn early and the crate stays, leave a shell and it is stuck (the idea N35 grew from, a different core) | `a9f453627f0b4c667ce31e01fab41093dd2f8cd9bdd0cc3489058db2661ee4ff` |
| N51 | B portal-first (portal + crate + switch) / POR_p19PX | 14 | 7×7 / 15 | portal, movable, switch | the crate travels: pushed into the portal it lands on the far side, in a lane someone still needs - who must leave before the push, and the pusher can only leave after its switch (the idea N37 grew from, a different core) | `4ad502c26b6c21bfcd977e3a885e2d2ff8cbc734c2378415cd2029ea456e1e9a` |

| ID | Category A | Category B | Positions (search complexity) | Solution | Solve | TIME UP worst | Parity | Distinct | Steps | Shortcut | look6 | Learner (look4 / 6) | Filler | Essential mechanics | Closest bank (overlap) | Closest new |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N48 | pass | pass | 540 | 23 | 22 ms | 18.2 ms / 380 | 0 / 0 | 6 | 19 | 0.02 | 0 | 4 / 4 | 0 trivial removals | no armor: 14 / 4; no magnet: unsolvable without it | N39 (0.39) | N50 (0.25) |
| N49 | pass | pass | 877 | 22 | 4.9 ms | 19.7 ms / 784 | 0 / 0 | 5 | 19 | 0.025 | 0.05 | 1 / 1 | 0 trivial removals | no movable: unsolvable without it; no portal: unsolvable without it; no sequence: unsolvable without it | N41 (0.38) | N51 (0.33) |
| N50 | pass | pass | 673 | 18 | 5.6 ms | 13.8 ms / 747 | 0 / 0 | 4 | 17 | 0.095 | 0.25 | 2 / 2 | 0 trivial removals | no armor: 13 / 4; no movable: 0 / 0; no switch: unsolvable without it | N35 (0.35) | N51 (0.25) |
| N51 | pass | pass | 311 | 18 | 4.6 ms | 6 ms / 237 | 0 / 0 | 5 | 16 | 0 | 0 | 5 / 4 | 0 trivial removals | no movable: 10 / 1; no portal: unsolvable without it; no switch: unsolvable without it | N37 (0.36) | N49 (0.33) |

## D. Quality assessment

- **Genuinely new:** N49 — a three-way dependency (crate, portal, Sequence:
  without any one of them the board is unsolvable): a Sequence pusher sends
  the crate through the portal and its own arrow advances with the push. All
  four boards are free of spinners and three of magnets, which helps the
  bank's balance (Phase 21 had spinners on 5 of 9).
- **Concept repeats (honest):** three of four come from the same core
  lineage as an existing board and pass the overlap rule only narrowly in
  idea, if not in layout — **N48** repeats N39's core and idea
  (magnet-delivered rammers, overlap 0.39, the highest allowed below the
  0.40 cap); **N50** is the "push, turn, ram" idea N35 grew from (0.35);
  **N51** is the "crate through the portal" idea of N37 (0.36). N49 and N51
  share the crate-through-portal idea (0.33 to each other).
- **Most promising:** N49 (new interaction, look-6 greedy 0.05, shortcut
  0.025) and N51 (shortcut 0.00, look-6 0.00, learners 5 / 4).
- **Risk of playing below EXTREME:** **N50** — its diagnostics resemble N41,
  which was rated EASY (look-6 greedy 0.25 vs N41's 0.31; learners 2 / 2;
  4 distinct mistakes, the floor; the armor removes 4 decision steps but no
  mistake). N49's learners clear it in 1 / 1 dead ends.
- **Artificial difficulty:** solutions are 18–23 moves (N48 23, N49 22) —
  long but not padded (0 trivial removals; coverage 0.83–0.94). N48 carries
  9 magnets and 6 shells: busy.
- The automated diagnostics did not predict N46's MEDIUM rating; all of the
  above are screening signals, not difficulty verdicts.

## The Phase 22 testing page (`?extreme90p22=1`)

`Extreme90P22` (extends `Extreme90P21`). CHOOSE A CHALLENGE shows only
CHALLENGE 1–4 = N48–N51; PREVIOUS CHALLENGES holds CHALLENGE 5–37 = every
board of the Phase 21 page in its order. Its own storage `xb22_*` /
`chain_escape_xb22_hub`, export `ce-xb22` (`selection: "xb22-v1"`), every run
under its real id and fingerprint, groups `phase22` (N48–N51), `provisional`
(N23, N24 and the seven promising Phase 21 boards), `downgraded` (N41, N46),
`strong`, `core`; build id "DEV BUILD p22-qa1-20261029". The Phase 21 page and
every earlier page are unchanged.

## G. Progress toward 50 human-approved puzzles

From the repository's evidence (`data/dev/extreme90_p18/human_p17.json`,
`human_p18.json`, `data/dev/extreme90_p21/human_p21.json`,
`docs/extreme90_phase17.md`, `docs/extreme90_bank.md`, the Phase 20 / 21
reports):

| Status | Boards | Count |
|---|---|---|
| Puzzle records | N1–N51 | 51 |
| Human-approved per the project classification (CORE + STRONG) | CORE N3, N5, N7, N11, N13; STRONG N14, N15, N16, N18, N21, N26, N27, N29, N30, N31, N32, N33, N34, N35, N36, N37, N38 | **22** |
| — of these with per-board human results in the repository | N14, N15, N16, N18, N21, N26, N27, N29, N30 (one player each); N31–N34 (three players); N35, N36 (two players) | 15 |
| — decision recorded, per-board results not in the repository | CORE N3 (the documented EXTREME reference), N5, N7, N11, N13 ("chosen from the family playtests"); N37, N38 (promoted after two players, Phase 21 brief) | 7 |
| — with at least one recorded rating of EXTREME | N14, N15, N18, N21, N31, N32, N33, N35 (N3 as the reference) | 8 (+ N3) |
| Human-tested, promising (provisional) | N23, N24; N39, N40, N42, N43, N44, N45, N47 | 9 |
| Technically qualified, not yet tested | N48, N49, N50, N51 | 4 |
| Downgraded / archived | N41, N46 (Phase 21); N17, N19, N20, N22, N25, N28 (EXTREME bank archive); N1, N2, N4, N6, N8, N9, N10, N12 (the `?ta90=1` collection, not in the EXTREME bank) | 16 |

**Remaining to reach 50: 28** (counting the 22 by the project's
classification). Several STRONG boards were rated VERY HARD rather than
EXTREME by their players (N16, N26, N27, N29, N30, N36; N34 HARD / VERY HARD / VERY HARD),
and no rating is statistically validated: by the strictest reading only 8
boards (plus the N3 reference) carry a recorded EXTREME rating.

## E. QA (this build, run in Phase 22)

Dev build ("Web") and player build ("Web Friend Test") exported from the
working tree; the player build contains 0 `data/dev` files.

| Suite | Result |
|---|---|
| Browser `?extreme90p22=1` (iPhone SE viewport) | **92 / 92**. Only CHALLENGE 1–4 = N48–N51; PREVIOUS CHALLENGES 5–37 reachable; every board played by touch; TIME UP and exact continuation; SKIP; export with real ids / groups / build id; player build ignores the page |
| Ta90ContinueCheck: all 37 selection boards (exact TIME UP restore, UNDO right after continuing, restart, lost tap, dead end) | **419 checks, 148 cases, 0 not resumed exactly** |
| Extreme90p22Check / p21 / p20 / p19 / p18 | 184 / 168 / 132 / 124 / 111 checks, all pass |
| Browser `?extreme90p21=1` / p20 / p19 / Phase 19 upgrade | 84 / 84, 66 / 66, 62 / 62, 9 / 9 |
| Browser `?extreme90p18=1` / `?extreme90=1` / `?extreme90p17=1` / `?ta90=1` / `?tapilot` | 55 / 55, 45 / 45, 51 / 51, 55 / 55, 28 / 28 |
| Browser campaign timing + Personal Best (`web_timing_test`) | pass (34 checks, 0 failures) |
| Browser friend (player) build / stime | 25 / 25, 31 / 31 |
| Browser ttime (`?tta=1`, the Phase 11 120 s page) | **FAILED 1 / 32** — see below |
| PortalCheck / MovableCheck / MagnetCheck | pass |
| Headless regression, 19 suites (unit tests, competition, timing, profile, feedback, Challenge a Friend API / flow, Social API / smoke / play, recipient, pilot, extreme11, q1 / r time, Ta90Check, Extreme90Check, Extreme90p17Check) | 18 pass; RecipientTest fails (pre-existing) |
| verify_levels | all 300 levels solvable, campaign rules pass |

**Pre-existing failure:** RecipientTest — the same 3 layout checks
("TOTAL SCORE left, coins right", en_US / he_IL / ar_SA) as in every phase
since Phase 16.

**Unresolved (investigated, not a Phase 22 regression):** the ttime check
"RED … a gentle pulse" failed on both runs of the Phase 22 build (luma span
54–56, then 58–61; it requires a span > 4). Investigation: (1) the `?tta`
page is `ExpertTimeAttack`; nothing changed for it in Phase 22 (the only
script changes are N48–N51 entries in `Ta90TimeAttack.BOARDS90`, which that
page never reads, and the dev-page hook); (2) the Phase 21 build passes the
same test today (54–61); (3) the pulse has a 1.25 s period while the test's 6
screenshots each took ~2.3–2.6 s here — about two periods — so samples can
alias onto the same phase; (4) a diagnostic copy of the test (scratch only,
not committed) taking 20 samples on the Phase 22 build measured 57, 61, 59,
54, 54, 61, 50, 50, 59, 61 during the red stage — the pulse renders normally
(span 11, never above the resting 61). The test was **not** changed; the
check is reported as sampling-sensitive.

WebAssembly full solve (the TIME UP check), headless Chromium: N48 34.2 ms,
N49 7.2, N50 4.1, N51 5.2 ms; slowest on the page N27 42.2 ms (it measured
15.8 ms in Phase 21: timings vary between runs on this machine).

The browser tests run headless Chromium at an iPhone SE viewport. **No real
iPhone was tested in Phase 22.**

## F. Human test instructions

- Upload `build/dev_qa/chain_escape_dev_extreme90p22_p22-qa1-20261029.zip`
  as a **new** HTML5 upload (a new itch.io address, so Safari cannot reuse an
  older cached build) and open it with `?extreme90p22=1`
  (for example `…/index.html?extreme90p22=1`).
- The main screen must read **"DEV BUILD p22-qa1-20261029"** and show only
  CHALLENGE 1–4 (= N48, N49, N50, N51). Older boards are under PREVIOUS
  CHALLENGES and need not be replayed.
- For each challenge, record: SOLVED (with time) or TIME UP; the short
  questionnaire (difficulty, enjoyment, play again) — SKIP is allowed; and,
  ideally, whether the tester played **alone or together** (Phase 21 was a
  joint session). COPY ALL RESULTS copies one bundle with every run under its
  real board id.
- Most useful to watch: N50 (diagnostics resemble N41, rated EASY) and
  whether N48 / N51 feel like repeats of N39 / N37.

## Safety audit

Runtime changes (development pages only): a dev-gated hook
(`?extreme90p22=1`, dev builds); four `BOARDS90` entries (N48–N51); the
`Extreme90P22` page. No engine, solver, gameplay, campaign, saves, timing /
Personal Best, Social / Challenge a Friend, Production or Supabase change;
no earlier board, id, definition, fingerprint or record changed. New tools:
`tools/extreme90_round.sh`, `tools/extreme90_stage2.py` (Phase 21's drivers,
now committed), the Phase 22 check and the browser-test entry.
