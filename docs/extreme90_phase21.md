# EXTREME Time Attack — Phase 21: scaled generation

Development only. Production, the 300 frozen levels, Supabase, the Social
MVP, Challenge a Friend, campaign timing / Personal Best and Gameplay
Feedback Polish are untouched. The 90-second rules, the Phase 18B exact TIME
UP continuation and the Phase 20 ram-log fix are unchanged.

## Step 0 — Repository safety

Branch `claude/elegant-fermat-0jrmxo`, HEAD `427eb18` (Phase 20, local),
clean tree; `origin` at `8198480`, a direct ancestor (local 1 ahead, 0
behind). Nothing overwritten or discarded.

## Human review — classification

N37 and N38 promoted to **STRONG** (two experienced players, real iPhones).
Boards and fingerprints unchanged.

| Group | Boards |
|---|---|
| CORE | N3, N5, N7, N11, N13 |
| STRONG | N14, N15, N16, N18, N21, N26, N27, N29, N30, N31, N32, N33, N34, N35, N36, N37, N38 |
| PROVISIONAL | N23, N24 |
| PHASE 21 HUMAN-REVIEW CANDIDATES | N39–N47 |
| ARCHIVED | N17, N19, N20, N22, N25, N28 |

## Predefined budget and acceptance (`data/dev/extreme90_p21/protocol.json`)

Fixed before the first search run:

- **Cores:** 24 existing cores, 6 families × 4: portal, armor, switch / gate,
  magnet, spinner, Sequence (`cores.json`). Every core first passed the
  search's own seed filters (a smoke run).
- **Runs:** 48 = 24 cores × RNG seeds 11 and 12, `--ops=v20`; 12 min, batch 40,
  beam 5, patience 8; 4 at a time, families interleaved.
- **Rounds:** round 2 runs only if round 1 accepts fewer than 10.
- **Stage 2:**
  - up to 2 qualifying clusters per run;
  - dropped before any report if the overlap is >= 0.40 with the bank, with an
    accepted board, or with a better candidate;
  - at most 40 full reports, one at a time on an idle machine, round-robin
    across families.
- **Acceptance (all must hold):**
  - `ta90_design.gd` HUMAN-REVIEW CANDIDATE for EXTREME (Category A and B,
    thresholds unchanged);
  - every listed mechanic essential: unsolvable without it, or >= 2 distinct
    mistakes or >= 3 decision steps fewer (Phase 20's judgement made a rule);
  - 0 trivial removals (no filler);
  - overlap < 0.40;
  - at most 1 board per core and 3 per family;
  - exact TIME UP continuation including UNDO right after continuing;
  - the browser page test.
- **Stop:** 10 accepted, or the budget spent.

## Generation summary

| Core | Family | Seed | Evaluated | Seconds | Stop | Qualifying (raw) | Best distinct / steps / shortcut |
|---|---|---|---|---|---|---|---|
| POR_p19PX | portal | 11 | 945 | 212 | patience | 298 | 4 / 13 / 0.05 |
| POR_p19PX | portal | 12 | 1980 | 475 | patience | 860 | 6 / 17 / 0.00 |
| POR_p18PM | portal | 11 | 1308 | 714 | patience | 441 | 4 / 23 / 0.00 |
| POR_p18PM | portal | 12 | 1138 | 542 | patience | 481 | 4 / 20 / 0.03 |
| POR_p18PS | portal | 11 | 1616 | 222 | patience | 0 | 2 / 12 / 0.28 |
| POR_p18PS | portal | 12 | 1618 | 164 | patience | 0 | 1 / 13 / 1.00 |
| POR_p18SPP | portal | 11 | 1779 | 590 | patience | 502 | 6 / 13 / 0.00 |
| POR_p18SPP | portal | 12 | 1809 | 671 | patience | 282 | 6 / 13 / 0.00 |
| ARM_p19AS | armor | 11 | 1364 | 181 | patience | 239 | 4 / 14 / 0.12 |
| ARM_p19AS | armor | 12 | 816 | 101 | patience | 0 | 2 / 13 / 0.15 |
| ARM_p18AR2 | armor | 11 | 1068 | 159 | patience | 138 | 4 / 22 / 0.03 |
| ARM_p18AR2 | armor | 12 | 962 | 167 | patience | 30 | 4 / 15 / 0.07 |
| ARM_p19MAS | armor | 11 | 735 | 92 | patience | 0 | 3 / 15 / 0.25 |
| ARM_p19MAS | armor | 12 | 913 | 129 | patience | 0 | 3 / 15 / 0.10 |
| ARM_bankI2 | armor | 11 | 1050 | 206 | patience | 0 | 3 / 10 / 0.35 |
| ARM_bankI2 | armor | 12 | 787 | 100 | patience | 0 | 3 / 13 / 0.25 |
| SWI_p20SG5 | switch_gate | 11 | 1251 | 206 | patience | 0 | 3 / 14 / 0.12 |
| SWI_p20SG5 | switch_gate | 12 | 773 | 109 | patience | 0 | 3 / 13 / 0.35 |
| SWI_p19SG3 | switch_gate | 11 | 1304 | 196 | patience | 0 | 3 / 11 / 0.12 |
| SWI_p19SG3 | switch_gate | 12 | 999 | 176 | patience | 0 | 3 / 12 / 0.12 |
| SWI_bankD | switch_gate | 11 | 1556 | 732 | time | 414 | 6 / 14 / 0.00 |
| SWI_bankD | switch_gate | 12 | 1339 | 678 | patience | 341 | 6 / 16 / 0.00 |
| SWI_bankA | switch_gate | 11 | 915 | 215 | patience | 262 | 5 / 12 / 0.00 |
| SWI_bankA | switch_gate | 12 | 1714 | 398 | patience | 16 | 3 / 12 / 0.03 |
| MAG_p18MG | magnet | 11 | 1369 | 276 | patience | 226 | 4 / 15 / 0.05 |
| MAG_p18MG | magnet | 12 | 1430 | 459 | patience | 296 | 5 / 15 / 0.05 |
| MAG_p18MX1 | magnet | 11 | 1211 | 347 | patience | 123 | 4 / 14 / 0.03 |
| MAG_p18MX1 | magnet | 12 | 1238 | 329 | patience | 362 | 5 / 15 / 0.00 |
| MAG_p18MX3 | magnet | 11 | 1328 | 464 | patience | 272 | 5 / 18 / 0.00 |
| MAG_p18MX3 | magnet | 12 | 1598 | 694 | patience | 0 | 3 / 20 / 0.00 |
| MAG_p17E | magnet | 11 | 1664 | 474 | patience | 425 | 5 / 14 / 0.00 |
| MAG_p17E | magnet | 12 | 2485 | 720 | time | 1049 | 6 / 15 / 0.00 |
| SPI_p17A | spinner | 11 | 1962 | 697 | patience | 589 | 6 / 22 / 0.00 |
| SPI_p17A | spinner | 12 | 1690 | 729 | time | 651 | 6 / 22 / 0.00 |
| SPI_p17H | spinner | 11 | 1403 | 393 | patience | 310 | 5 / 14 / 0.05 |
| SPI_p17H | spinner | 12 | 1236 | 382 | patience | 184 | 6 / 15 / 0.20 |
| SPI_p17C2 | spinner | 11 | 1822 | 477 | patience | 244 | 5 / 14 / 0.00 |
| SPI_p17C2 | spinner | 12 | 2381 | 624 | patience | 0 | 5 / 15 / 0.20 |
| SPI_bankB | spinner | 11 | 999 | 254 | patience | 197 | 5 / 14 / 0.03 |
| SPI_bankB | spinner | 12 | 728 | 273 | patience | 0 | 6 / 12 / 0.07 |
| SEQ_p19SQX2 | sequence | 11 | 1130 | 233 | patience | 0 | 3 / 20 / 0.05 |
| SEQ_p19SQX2 | sequence | 12 | 1150 | 287 | patience | 0 | 3 / 17 / 0.00 |
| SEQ_p18MS2 | sequence | 11 | 2133 | 736 | time | 650 | 5 / 29 / 0.00 |
| SEQ_p18MS2 | sequence | 12 | 1826 | 468 | patience | 652 | 6 / 24 / 0.00 |
| SEQ_bankH2 | sequence | 11 | 1617 | 736 | time | 687 | 6 / 20 / 0.00 |
| SEQ_bankH2 | sequence | 12 | 2205 | 713 | patience | 0 | 6 / 20 / 0.00 |
| SEQ_p17G | sequence | 11 | 1204 | 368 | patience | 178 | 5 / 13 / 0.07 |
| SEQ_p17G | sequence | 12 | 1808 | 496 | patience | 503 | 6 / 12 / 0.00 |


Totals: 48 runs, 67356 boards evaluated, 5.3 CPU-hours of search, 31 runs with qualifying boards, 11902 qualifying boards (raw).

Round 1 (seed 11): 18 of 24 runs found qualifying boards; 36 candidates, 12
after the similarity pre-filter, 12 reports, **7 accepted**. Round 2 (seed
12): 13 of 24 runs qualified; 25 candidates, 6 after the pre-filter, 2 of them
from cores already accepted (skipped), 4 reports, **2 accepted**. The budget
was spent with **9 accepted** (16 of 40 reports used); the 10-board stop was not
reached.

### Every candidate and decision

| Candidate | Stage | Decision | Reason |
|---|---|---|---|
| SPI_p17A_s11_1 | prefilter | dropped | overlap 0.50 with N24 |
| SPI_p17A_s11_2 | prefilter | dropped | overlap 0.50 with N24 |
| MAG_p17E_s11_1 | prefilter | dropped | overlap 0.78 with N27 |
| MAG_p17E_s11_2 | prefilter | dropped | overlap 0.68 with N27 |
| POR_p18PM_s11_2 | prefilter | dropped | overlap 0.79 with the better candidate POR_p18PM_s11_1 |
| SPI_p17H_s11_2 | prefilter | dropped | overlap 0.42 with N29 |
| SEQ_p18MS2_s11_2 | prefilter | dropped | overlap 0.89 with the better candidate SEQ_p18MS2_s11_1 |
| SEQ_bankH2_s11_2 | prefilter | dropped | overlap 0.91 with the better candidate SEQ_bankH2_s11_1 |
| MAG_p18MX3_s11_1 | prefilter | dropped | overlap 0.40 with N38 |
| SEQ_p17G_s11_2 | prefilter | dropped | overlap 0.45 with N15 |
| SPI_p17C2_s11_1 | prefilter | dropped | overlap 0.42 with N34 |
| SPI_p17C2_s11_2 | prefilter | dropped | overlap 0.42 with N30 |
| SWI_bankD_s11_2 | prefilter | dropped | overlap 0.84 with the better candidate SWI_bankD_s11_1 |
| POR_p18SPP_s11_2 | prefilter | dropped | overlap 0.94 with the better candidate POR_p18SPP_s11_1 |
| POR_p19PX_s11_1 | prefilter | dropped | overlap 0.42 with N37 |
| POR_p19PX_s11_2 | prefilter | dropped | overlap 0.43 with N37 |
| ARM_p18AR2_s11_2 | prefilter | dropped | overlap 0.41 with N35 |
| MAG_p18MX1_s11_1 | prefilter | dropped | overlap 0.42 with the better candidate SEQ_p18MS2_s11_1 |
| MAG_p18MX1_s11_2 | prefilter | dropped | overlap 0.40 with the better candidate SEQ_p18MS2_s11_1 |
| SPI_bankB_s11_2 | prefilter | dropped | overlap 0.73 with the better candidate SPI_bankB_s11_1 |
| MAG_p18MG_s11_1 | prefilter | dropped | overlap 0.50 with N32 |
| ARM_p19AS_s11_2 | prefilter | dropped | overlap 0.87 with the better candidate ARM_p19AS_s11_1 |
| MAG_p18MG_s11_2 | prefilter | dropped | overlap 0.52 with N32 |
| SWI_bankA_s11_2 | prefilter | dropped | overlap 0.40 with N20 |
| POR_p18PM_s11_1 | report | rejected | filler: 1 trivial removals ['r1c3 M'] |
| ARM_p18AR2_s11_1 → N39 | report | ACCEPTED |  |
| SWI_bankD_s11_1 | report | rejected | gate marginal (without it: 15 decision steps, 6 distinct mistakes (with it: 14, 6)) |
| MAG_p18MX3_s11_2 | report | rejected | lock marginal (without it: 18 decision steps, 4 distinct mistakes (with it: 18, 5)) |
| SPI_p17H_s11_1 | report | rejected | filler: 1 trivial removals ['r2c2 P^@~'] |
| SEQ_p17G_s11_1 | report | rejected | pattern marginal (without it: 13 decision steps, 4 distinct mistakes (with it: 13, 5)) |
| POR_p18SPP_s11_1 → N40 | report | ACCEPTED |  |
| ARM_p19AS_s11_1 → N41 | report | ACCEPTED |  |
| SWI_bankA_s11_1 → N42 | report | ACCEPTED |  |
| SPI_bankB_s11_1 → N43 | report | ACCEPTED |  |
| SEQ_p18MS2_s11_1 → N44 | report | ACCEPTED |  |
| SEQ_bankH2_s11_1 → N45 | report | ACCEPTED |  |
| SPI_p17A_s12_2 | prefilter | dropped | overlap 0.92 with the better candidate SPI_p17A_s12_1 |
| MAG_p17E_s12_1 | prefilter | dropped | overlap 0.43 with N27 |
| MAG_p17E_s12_2 | prefilter | dropped | overlap 0.43 with N27 |
| SEQ_p17G_s12_1 | prefilter | dropped | overlap 0.53 with N30 |
| SPI_p17H_s12_1 | prefilter | dropped | overlap 0.48 with N29 |
| POR_p19PX_s12_1 | prefilter | dropped | overlap 0.62 with N37 |
| POR_p19PX_s12_2 | prefilter | dropped | overlap 0.62 with N37 |
| SPI_p17H_s12_2 | prefilter | dropped | overlap 0.42 with N24 |
| SEQ_p18MS2_s12_2 | prefilter | dropped | overlap 0.83 with the better candidate SEQ_p18MS2_s12_1 |
| SEQ_p17G_s12_2 | prefilter | dropped | overlap 0.53 with N28 |
| POR_p18PM_s12_2 | prefilter | dropped | overlap 0.88 with the better candidate POR_p18PM_s12_1 |
| SWI_bankD_s12_1 | prefilter | dropped | overlap 0.42 with N16 |
| MAG_p18MX1_s12_1 | prefilter | dropped | overlap 0.45 with ARM_p18AR2_s11_1 |
| MAG_p18MX1_s12_2 | prefilter | dropped | overlap 0.45 with ARM_p18AR2_s11_1 |
| POR_p18SPP_s12_1 | prefilter | dropped | overlap 0.48 with POR_p18SPP_s11_1 |
| ARM_p18AR2_s12_1 | prefilter | dropped | overlap 0.45 with N32 |
| MAG_p18MG_s12_2 | prefilter | dropped | overlap 0.83 with the better candidate MAG_p18MG_s12_1 |
| SWI_bankA_s12_1 | prefilter | dropped | overlap 0.42 with N20 |
| SWI_bankA_s12_2 | prefilter | dropped | overlap 0.42 with SWI_bankA_s11_1 |
| POR_p18PM_s12_1 | report | rejected | filler: 1 trivial removals ['r0c2 M'] |
| SWI_bankD_s12_2 | report | rejected | gate marginal (without it: 16 decision steps, 5 distinct mistakes (with it: 16, 6)) |
| MAG_p18MG_s12_1 → N46 | report | ACCEPTED |  |
| SPI_p17A_s12_1 → N47 | report | ACCEPTED |  |
| SEQ_p18MS2_s12_1 | report | skipped | a board of this core is already accepted |
| POR_p18SPP_s12_2 | report | skipped | a board of this core is already accepted |

Reports used: 16 of 40; accepted 9.

Why candidates fell: 43 at the pre-filter (mostly same-core variants, then
closeness to the bank: e.g. the p17 E magnet boards are 0.68–0.78 from N27,
the p17 A spinner boards 0.50 from N24); 7 at the report — 3 with filler (two
crates, one spinner piece that changed nothing), 4 with a marginal mechanic
(two gates, a lock, a pattern rule removing fewer than 2 mistakes / 3 steps).
No candidate failed Category A.

A limitation of the pre-filter, reported rather than changed: the overlap
measure compares occupied cells only (it tells spinners, crates and portals
apart, not magnets from Sequence blocks), so it is conservative — e.g. the
MX1 magnet boards were dropped at 0.40–0.42 against a Sequence board.

## The Phase 21 boards

All nine are **HUMAN-REVIEW CANDIDATES** (Category A and B pass; human
difficulty unvalidated).

| ID | Family | Mechanics | Pieces | Strategic concept | Fingerprint |
|---|---|---|---|---|---|
| N39 | D/C rammer + magnet | armor, magnet | 15 | the magnet brings the rammer: a pull drags a block into the lane of a shell - or into a lane where it is only in the way; shells all over the board decide which pulls still help | `892e99ae1e7e527987e7770eb2d4f962dd98aca2940ad165653eeb85cbc03c39` |
| N40 | H/B spinner + portal | spinner, portal | 15 | a turn that changes the far side: a spinner's lane runs through the portal in one facing and straight out in another - every departure next to it re-aims a lane on the other side of the board | `3533e6982f8833ff882134e4660a449f3e7fe0de49cc0ce629939fbd5ec5ef1f` |
| N41 | E rammer / armor + switch | armor, switch | 14 | one rammer, two shells, one reversal group (two switch pieces): crack the shell in front, stay, be turned round to crack the one behind - leave or turn early and a shell stays | `f3531d7f7261b38effb7fd532fea36e1e27c1a96d8c837099d0e28a93cced400` |
| N42 | C switch + spinners | spinner, switch | 14 | between two switches: two switch pieces flip the same target, which must leave between the two firings - while the spinners around it decide when its lane is open | `2e61400846791306d990e0cfd677249c688ba3f9b19caa49f6e6c4ab2102b056` |
| N43 | spinner pattern + armor | spinner, pattern, armor | 14 | the pattern's rhythm: a pattern spinner (cw, cw, ccw) must ram two shells in turn; each departure beside it moves it one step of its rhythm | `e31f26fbfd26e0ab66288c719b1b16ac33fcaf9fe7967fd8776d315cd0dfda33` |
| N44 | A/F movable + Sequence | movable, sequence | 18 | the Sequence pusher: pushing a crate also advances the pusher's arrow - who must leave before a crate moves, and who only after; two crates, a long line of Sequence blocks | `b9ce007c67c1f51e1727b18ca41db8eb32f25f15d5802a7e9c30ab2018bf79fc` |
| N45 | Sequence + lock + spinners | spinner, sequence, lock | 21 | a key that leaves in two steps: the Sequence key's advance turns the locked spinner without unlocking it; its escape unlocks and turns it again | `a7f4400fb9e44439560d590b0a10ea5aeaa734890cd186d3fc7b21650aed86fb` |
| N46 | C magnet relocation | magnet | 17 | the pull decides who is in the way: each magnet drags a plain block into a lane another block still needs | `7e721e1513c712d2cac3f05688e0bfcdbfcab3716a950049a3693ff461d896ca` |
| N47 | spinner domino | spinner | 24 | domino: spinners in a row turn each other as they leave - the order of departures decides every direction | `89ba0dbdcdcb5ded036f58c75e4e7b6ce54d7a4655443446ff4cf1065249fe05` |

| ID | Positions | Solution | Solve | TIME UP worst (desktop) | Parity | Distinct | Steps | Coverage / late | Shortcut | look6 | Learner (look4 / 6) | Trap delay | Undo-proof | Counterfactuals | Closest bank (overlap) | Closest new |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N39 | 962 | 25 | 11 ms | 8.7 ms / 234 | 0 / 0 | 4 | 22 | 0.88 / 0.88 | 0.025 | 0.042 | 2 / 2 | 9 | 0.87 | no armor: 2 / 1; no magnet: unsolvable without it | N35 (0.39) | N46 (0.39) |
| N40 | 553 | 15 | 20.2 ms | 10.2 ms / 305 | 0 / 0 | 6 | 13 | 0.87 / 0.87 | 0 | 0.025 | 5 / 5 | 6 | 0.78 | no portal: 10 / 4; no spinners: unsolvable without it | N34 (0.38) | N47 (0.31) |
| N41 | 279 | 17 | 1.7 ms | 1.1 ms / 43 | 0 / 0 | 4 | 14 | 0.82 / 0.82 | 0.125 | 0.308 | 2 / 0 | 8 | 0.82 | no armor: 1 / 1; no switch: unsolvable without it | N35 (0.35) | N46 (0.24) |
| N42 | 372 | 14 | 0.8 ms | 4.5 ms / 147 | 0 / 0 | 5 | 12 | 0.86 / 0.86 | 0.017 | 0.075 | 4 / 3 | 6 | 0.86 | no switch: unsolvable without it; no spinners: 2 / 1 | N29 (0.3) | N47 (0.26) |
| N43 | 397 | 16 | 3.3 ms | 7 ms / 193 | 0 / 0 | 5 | 14 | 0.88 / 0.88 | 0.01 | 0.008 | 4 / 4 | 5 | 0.75 | no armor: 5 / 3; no pattern: unsolvable without it; no spinners: unsolvable without it | N30 (0.38) | N47 (0.22) |
| N44 | 958 | 33 | 4 ms | 21.5 ms / 811 | 0 / 0 | 5 | 29 | 0.88 / 0.94 | 0.025 | 0.008 | 2 / 2 | 9 | 0.91 | no movable: unsolvable without it; no sequence: unsolvable without it | N31 (0.36) | N46 (0.31) |
| N45 | 298 | 22 | 3.4 ms | 2.3 ms / 49 | 0 / 0 | 6 | 20 | 0.91 / 0.91 | 0 | 0.025 | 1 / 1 | 7 | 0.77 | no lock: 14 / 4; no sequence: 13 / 4; no spinners: unsolvable without it | N21 (0.39) | N42 (0.27) |
| N46 | 462 | 17 | 3.3 ms | 17.9 ms / 441 | 0 / 0 | 5 | 15 | 0.88 / 0.88 | 0.095 | 0 | 16 / 16 | 8 | 0.83 | no magnet: unsolvable without it | N32 (0.38) | N39 (0.39) |
| N47 | 741 | 24 | 17 ms | 28.8 ms / 546 | 0 / 0 | 6 | 22 | 0.92 / 0.92 | 0 | 0 | 3 / 4 | 9 | 0.84 | no spinners: unsolvable without it | N24 (0.36) | N40 (0.31) |

### Similarity and diversity

- No two Phase 21 boards overlap >= 0.40 (highest 0.39: N39 / N46); every
  board is < 0.40 from every bank board (highest 0.39: N39–N35, N45–N21).
- Nine cores, six families: portal 1 (N40), armor 2 (N39, N41), switch 1
  (N42), magnet 1 (N46), spinner 2 (N43, N47), Sequence 2 (N44, N45).
- Distinct strategic patterns: magnet-delivered rammers (N39), portal
  re-aiming by spinner turns (N40), ram–turn–ram with a reversal (N41), a
  target that must leave between two switch firings (N42), a pattern
  spinner's rhythm against shells (N43), Sequence pushers moving crates
  (N44), a two-step Sequence key on a locked spinner (N45), magnet
  relocation (N46), spinner domino (N47).
- **Mechanic balance (honest):** spinners appear on 5 of 9 boards (N40,
  N42, N43, N45, N47) — the largest share; magnets on 2 (N39, N46), armor 3,
  switches 2, Sequence 2, portal 1, crates 1, lock 1, pattern 1. Four boards
  have no spinner (N39, N41, N44, N46), two of them no magnet either (N41,
  N44). The protocol caps families, not mechanics, so spinner use was not
  limited; the spinner cores were simply the most productive.

### Known weaknesses

- **N46** carries 13 magnets on 7×7 — the "magnet clutter" Phase 19 warned
  about (its core, from Phase 18, had no magnet cap). Learners find it hard
  (16 / 16 dead ends), but readability on a phone is the main risk.
- **N39** has 11 shells and 4 magnets: busy.
- **N41** is the weakest by the diagnostics: the look-6 greedy wins 31 %,
  learners need 2 / 0 dead ends, shortcut 0.125 (under the 0.20 cap).
- **N44** needs a 33-move solution with 13 Sequence blocks — long for 90 s;
  **N47** has 24 pieces and the slowest TIME UP check (28.8 ms desktop, under
  the 40 ms gate).
- **N42** is a switch board that leans on spinners (without them 2 steps /
  1 mistake): its "switch / gate" family label is the core's, not the play.

## Phase 21 testing page (`?extreme90p21=1`)

`Extreme90P21` (extends `Extreme90P20`, the verified QA3 design):
CHOOSE A CHALLENGE shows only CHALLENGE 1–9 = N39–N47; PREVIOUS CHALLENGES
holds CHALLENGE 10–33 = every board of the Phase 20 page in its order (N37,
N38, N35, N36, then the Phase 18B selection). Its own storage `xb21_*` /
`chain_escape_xb21_hub`, export `ce-xb21` (`selection: "xb21-v1"`) with every
run under its real id and fingerprint, each board's number, list and group
(`phase21` for N39–N47, `strong` for N35–N38), build id "DEV BUILD
p21-qa1-20261028". No locks; earlier pages and their records untouched.

## QA (final build)

Dev build ("Web") and player build ("Web Friend Test") exported from the
working tree; the player build contains 0 `data/dev` files.

| Suite | Result |
|---|---|
| Browser `?extreme90p21=1` (iPhone SE viewport) | 84 / 84. Primary screen only CHALLENGE 1–9 = N39–N47. PREVIOUS CHALLENGES 10–33 all reachable, BACK. Every board played by touch; TIME UP and exact continuation; SKIP; export with real ids, lists and build id; player build ignores the page |
| Ta90ContinueCheck (all 33 boards: exact TIME UP restore, UNDO right after continuing, restart, lost tap, dead end) | 375 checks, 132 cases, 0 not resumed exactly |
| Extreme90p21Check / p20 / p19 / p18 | 168 / 132 / 124 / 111 |
| Browser `?extreme90p20=1` / `?extreme90p19=1` / Phase 19 upgrade | 66 / 66, 62 / 62, 9 / 9 |
| Browser `?extreme90p18=1` / `?extreme90=1` / `?extreme90p17=1` / `?ta90=1` / `?tapilot` | 55 / 55, 45 / 45, 51 / 51, 55 / 55, 28 / 28 |
| Browser timing / friend (player) build / stime / ttime tta | pass, 25 / 25, 31 / 31, 32 / 32 |
| PortalCheck / MovableCheck / MagnetCheck | pass |
| Headless regression: 18 suites (unit tests, competition, timing, profile, feedback, Challenge a Friend API and flow, Social API / smoke / play, pilot, extreme11, q1 / r time, Ta90Check, Extreme90Check, Extreme90p17Check) | pass |
| verify_levels | all 300 levels solvable, campaign rules pass |

**Pre-existing failure (not Phase 21):** RecipientTest — the same 3 layout
checks ("TOTAL SCORE left, coins right", en_US / he_IL / ar_SA).

WebAssembly full solve (the TIME UP check), headless Chromium: N39 9.5 ms,
N40 18.1, N41 2.8, N42 0.7, N43 2.9, N44 4.0, N45 2.6, N46 2.8, N47 17.3 ms;
slowest on the page N14 22.7 ms.

The browser tests run headless Chromium at an iPhone SE viewport; they are
**not** equivalent to testing on a real iPhone.

## Safety audit of the change

Runtime changes (development pages only):
- a dev-gated hook in `game_manager.gd` (only with `?extreme90p21=1`, dev builds);
- nine `BOARDS90` entries (N39–N47) and the `Extreme90P21` page.

No engine, solver, gameplay, campaign, Production, Supabase, Social / Challenge
a Friend change; no earlier board, definition, fingerprint or record changed.

Tools: the Phase 21 check, the browser test entry, `ta90_check` and
`ta90_continue_check` board lists. The search tool is unchanged since Phase 20.

One local commit; nothing pushed, merged, deployed or published.
