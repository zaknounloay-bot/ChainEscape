# EXTREME 90 — Phase 33: quality recovery, learning from the whole bank

Development only. **Not deployed to Production.** Not touched:
- itch.io Production and Supabase;
- the 300 frozen Classic levels;
- the EXTREME definition, the 90-second EXTREME rules and the standard 120-second Time Attack baseline;
- the exact Solver and the repository's generator;
- every gameplay mechanic (none added or changed).

**Owner-approved EXTREME bank: 38 / 50 (12 remaining).** The 38 approvals are not reopened.
- Phase 31: N83, N86, N87 approved; N84, N85 not approved.
- Phase 32: N88–N93 **not approved** (N88–N91 and N93 MEDIUM, N92 VERY HARD): 0 / 6.
- N82: still unapproved, pending an explicit owner decision.

**Labels:** the new boards **N94–N100** were built as **TECHNICALLY QUALIFIED — HUMAN UNTESTED** (sections D–I describe them as they were before play).
**Update 2026-11-03 (section J):** the owner has played N94–N100.
- N94 and N99: rated EXTREME, **recommended for approval, not yet confirmed**.
- N96: rated VERY HARD, **borderline, owner judgment pending**.
- N95, N97, N98, N100: rated MEDIUM, **not approved**.

**The approved bank stays 38 / 50** until the owner explicitly confirms.

## A. Phase 32 closure

**Closed before any Phase 33 generation**, enforced in the runner script itself (gates G1–G4; Round 1 could not start until all four passed):

| Gate | Condition | Result |
|---|---|---|
| G1 | the Phase 32 regression complete | passed 00:47 (all pages, all phase checks, 300 Classic levels; RecipientTest only its 3 known failures) |
| G2 | Extreme11Check passes three idle reruns within 40 ms | first attempt **failed** (39.7, then 41.8 ms): the chain **halted** and the failure was investigated; the pre-registered strict rerun passed 3 / 3 (34.2, 15.2, 16.6 ms) |
| G3 | Phase 32 closed and committed locally | local commit `649c33a` |
| G4 | Git state clean | HEAD one commit on `22e57e1`, `origin` unchanged, no modified files, only Phase 33 files untracked |

- **Extreme11 investigation** (`data/dev/extreme90_p32/qa/extreme11_investigation.json`; doc 32 G): an interleaved idle A/B against the Phase 31 baseline and component timing showed identical solver work on both trees and 30–50 ms scheduling spikes on **both** (Fisher p = 0.50); no engine change since `22e57e1`. Not a Phase 32 regression. **The 40 ms gate is unchanged.**
- **Owner decisions recorded:** N88, N89, N90, N91, N93 MEDIUM; N92 VERY HARD; **all six NOT APPROVED (0 / 6)**. The records and `selection.json` carry the decision and the rating separately; fingerprints unchanged; Extreme90p32Check (350) and Ta90Check (91) pass after the update.
- **Bank: 38 / 50**, 12 remaining. N82 still pending. The 38 approvals are not reopened.
- **Not pushed.** Phase 32 and Phase 33 stay local.

## B. Historical approved-vs-not-approved analysis

**Labels** (`data/dev/extreme90_p33/labels.json`, built by `make_labels.py` from the bank manifest and every phase's human / owner files; each value carries its source file):

| Group | n | What it is |
|---|---|---|
| Positive: owner APPROVED | **38** | `owner_approved` in the manifest + N83, N86, N87 |
| Negative: NOT APPROVED and human-rated | **33** | downgraded / archived / explicitly not approved, with at least one recorded rating |
| Excluded | 22 | 12 provisional / strong provisional / promising (never decided), N82 pending, N66 borderline, and 8 boards (N1, N2, N4, N6, N8–N10, N12) not approved but **never rated**: unrated is not rejected |

- **The rating is not the label.** The human difficulty rating is stored beside the decision, never in its place: N82 and N92 are VERY HARD and not approved; N87 is VERY HARD and approved.
- **Two eras.** Phases 14–24 (N1–N52) were rated by family players in mixed sessions and include portal, conveyor and hand-built boards. From Phase 25 (N53+) every rating is the owner's first exposure on 7×7 generated boards. The eras are analysed together and separately.

**Measures** (`tools/ta90_struct33.gd`, extends the Phase 31 structure tool; the exact Solver's full position graph, unchanged; all 93 boards in `struct_all.json`). New in Phase 33, along the Solver's solution line:
- `delayed` / `loud`: losing moves whose dead end is / is not forced within 3 moves (a mistake Undo 3 cannot reach back from, vs one the board punishes at once);
- `strat_steps`: steps with at least one delayed losing alternative — a **truly strategic** choice; `apparent_steps`: steps with ≥ 2 legal moves and no delayed loser — the choice is free or punished at once (**apparent**);
- `early3`, `early3_loud`, `early3_delayed`, `late_strat_share`, `max_forced_run`;
- simple-player performance from the Phase 26 tool: exact win chance of a random player (`p_random`), of one who avoids moves dead within 1 / 2 moves (`p_look1`, `p_look2`), of a "calm" player (`p_calm`), and the dependency depth (`dep_depth`, `dep_pairs`).

### Measured (medians; AUC = chance an approved board has the higher value)

| Measure | All eras: approved (38) / not (33) | AUC | P25+: approved (15) / not (24) | AUC |
|---|---|---|---|---|
| Reachable positions | 487 / 458 | 0.51 | **251 / 454** | **0.29** |
| Winning positions | 97 / 98 | 0.47 | 48 / 90 | 0.29 |
| Legal opening moves | 5.5 / 6 | 0.50 | 4 / 5 | 0.39 |
| Tempting fatal openings | 2 / 2 | 0.52 | 1 / 2.5 | 0.34 |
| **Losing moves, first 3 steps (early3)** | 7 / 7 | 0.47 | **4 / 7** | **0.18** |
| — of them punished within 3 moves (loud) | 0 / 0 | 0.55 | 0 / 0 | 0.55 |
| Strategic steps | 10.5 / 11 | 0.55 | 10 / 11 | 0.48 |
| Apparent steps | 5 / 5 | 0.51 | 5 / 5 | 0.59 |
| Forced steps | 7.5 / 7 | 0.59 | 7 / 6.5 | 0.62 |
| Longest forced run | 4 / 3 | 0.57 | 4 / 3 | 0.58 |
| Distinct mistakes on the line | 5 / 5 | 0.56 | 5 / 5 | 0.56 |
| Trap depth (median) | 9 / 9 | 0.45 | 8 / 9 | 0.37 |
| Mistakes beyond Undo 3 | 100% / 100% | 0.50 | 83% / 100% | 0.47 |
| Random player wins (exact) | 0.000 / 0.001 | 0.43 | 0.000 / 0.002 | 0.35 |
| Look-2 player wins (exact) | 0.001 / 0.002 | 0.46 | 0.001 / 0.003 | 0.43 |
| Dependency pairs (fixed on every winning line) | 79.5 / 74 | 0.63 | 81 / 73.5 | 0.65 |

**Findings (measured):**
- **Across the whole history no structural measure separates approved from not approved** (every AUC 0.41–0.63). The Phase 14–24 approvals are often large boards (positions in the thousands) with mechanics the later generator no longer uses. What made those boards EXTREME is not visible in these measures.
- **In the first-exposure era (P25+)** three measures separate the groups: early3 (AUC 0.82 for "lower = approved"), positions and winning positions (0.71). These are the Phase 31 findings, now on 39 boards instead of 30.
- **Almost every early mistake is delayed, not loud.** On approved and not-approved boards alike, the losing moves of the first three steps are almost never punished within three moves. What differs is **how many** there are. An approved board offers about 4 fatal options in its first three steps; a not-approved board about 7.
- **Apparent vs strategic choices do not separate the groups.** Every generated board has about 10–11 strategic steps and about 5 apparent ones. The generator's gates (decision steps, late, coverage) already make every board look strategic by these counts. So the counts cannot say which boards a strong human finds EXTREME.
- **Simple players lose almost everywhere.** A random or look-2 player wins under 1% on nearly every board, approved or not. Simple-player failure is a property of the gates, not of EXTREME.

**Family pattern (descriptive, P25+, small n, not a predictor):**

| Family | Approved / rated |
|---|---|
| magnet × reversal (± lock / armor / gate) | 4 / 6 (N64, N72, N77, N83; not N70, N76) |
| reversal × lock (± armor) | 4 / 8 (N61, N75, N86, N87; not N63, N88, N91, N93) |
| reversal × armor | 2 / 4 (N55, N62; not N79, N81) |
| crate (Movable) | 3 / 8 |
| magnet × lock, no switch | **0 / 4** (N67, N89, N90, N92) |
| gate, no crate | 1 / 4 (N77; not N54, N65, N84; N66 borderline) |
| Sequence | 0 / 3 (N82 pending) |

**Patterns associated with the Phase 32 downgrades (measured):** N88, N89, N90 and N93 have early3 of 9–11, the loudest openings of any board since Phase 28. Three of the six are magnet × lock without a switch. Every Phase 32 board has ≥ 209 positions; every Phase 31 approval has ≤ 143. The Phase 32 selection rule (fewest positions *within each concept*) worked as specified, but no Phase 32 concept produced a board in the range of the Phase 31 approvals (generator logs: 0 of 2,127 qualifying Phase 32 boards at ≤ 150 positions, vs 29 for T01r and 36 for the T27r run in Phase 31).

**Caution.** Fewer positions is not "more difficult": N53 (623 positions) and N68 (647) are EXTREME and approved; N84 (163) is MEDIUM.

## C. Chronological predictor validation

**Protocol** (`data/dev/extreme90_p33/protocol.json`, written before the Phase 33 measures were computed): 7 pre-specified rules; for each test phase t = 25…32 a rule's single threshold is fitted **only on phases < t**, then applied unchanged to phase t. A rule may allocate search or order candidates only if its pooled holdout balanced accuracy is ≥ 0.65 **and** it beats both baselines ("always approved", "always not approved") in at least 5 of the 8 test phases. No rule becomes a gate in any case. (`tools/extreme90_val33.py` → `validation.json`, `validation_summary.txt`.)

**Holdout results** (39 boards from phases 25–32: 15 approved, 24 not; baselines 15 / 39 and 24 / 39 correct):

| Rule | Correct | False positives | False negatives | Balanced accuracy | Precision | Phases beating both baselines |
|---|---|---|---|---|---|---|
| P1 fewer positions | 27 / 39 | 1 | 11 | 0.61 | 0.80 | 1 / 8 |
| **P2 fewer early3** | **30 / 39** | 7 | 2 | **0.79** | 0.65 | **3 / 8** |
| P3 fewer tempting openings | 15 / 39 | 24 | 0 | 0.50 | 0.38 | 0 / 8 |
| P4 lower look-2 win chance | 21 / 39 | 13 | 5 | 0.56 | 0.43 | 1 / 8 |
| P5 more strategic steps | 24 / 39 | 1 | 14 | 0.51 | 0.50 | 1 / 8 |
| P6 higher forced share | 22 / 39 | 7 | 10 | 0.52 | 0.42 | 1 / 8 |
| P7 positions AND early3 | 27 / 39 | 0 | 12 | 0.60 | 1.00 (3 / 3) | 1 / 8 |

**Only truly prospective test** (P1 and P2 were pre-registered in Phase 31 for N83+; N83–N93, 3 approved / 8 not):
- **Positions:** AUC **1.00**. All three approvals have 87–143 positions; every not-approved board has ≥ 163.
- **early3:** AUC **0.79**.

**Conclusion (stated explicitly):**
- **No rule predicts EXTREME approval reliably.** None meets the pre-registered decision rule.
- early3 is the best of 7. Its 0.79 is **optimistic by selection** (the best of 7 rules on 39 boards). It beats both baselines in only 3 of 8 phases, because several phases hold 1–6 boards and ties are common.
- Positions has a perfect prospective record on 11 boards, but on the earlier holdout phases it misses 11 of 15 approvals.
- **Major uncertainty:**
  - n = 39 in the holdout and 11 in the prospective test;
  - one rater (the owner) since Phase 25;
  - the two predictors are correlated (small boards have fewer early fatal moves);
  - the early era contradicts both.
- **Use in Phase 33:** all seven are **advisory only**. They are printed beside every candidate for the owner, and none orders or rejects a candidate. The one ordering rule that stays is the *baseline* selection rule of Phase 31 (fewest positions per concept), kept because it is the tested baseline, not because it is validated.

## D. Phase 33 generation methodology

**Baseline kept: the Phase 31 method, unchanged** (`protocol.json` `generation_baseline`): the generator of commit `c1ddc89` in its own worktree, `--ops=v20`, piece_free 13, max_pieces 17, suffix_rate 0.30, patience 8, 12 minutes, batch 40, beam 5; shortlist `extreme90_sel31.py`; `extreme90_screen30.py`; `extreme90_eval25.py --full`. The repository's generator, the exact Solver and every gate are unchanged; no mechanic, size or duration change. Job files: `tools/extreme90_gen33.py`.

**Allocation** (written before any run, from the evidence in B and C — not from a validated predictor, because none qualified):
- **Arm R** — a fresh RNG seed on 8 cores that each produced an owner-approved board: T01r (N83), T10b (N86), T30 (N87), R04 (N75), P03 (N64), L3 (N62), J1 (N59), J5 (N61). This is the first direct test of whether a core's approval transfers to a new board. Not cloning: every new board must still clear the bank-overlap gate (< 0.40) against its sibling.
- **Arm N** — 4 cores from families with approvals that never produced a rated board: K08, H2, J4, P07.
- **Round 2** only for cores with no screen PASS and a non-empty pool, new seed 332.

**Budget used:** 15 of 16 generator runs, 17 of 24 full evaluations.

| Run | Arm | Evaluated | Qualifying | Engine-valid | ≤ 150 positions | Screen PASS | Smallest PASS |
|---|---|---|---|---|---|---|---|
| T01r_s331 | R | 2141 | 774 | 765 | 38 | 6 / 11 | **95** |
| T10b_s331 | R | 1883 | 654 | 654 | 5 | 4 / 12 | **136** |
| J5_s331 | R | 1437 | 543 | 540 | 0 | 7 / 11 | 206 |
| K08_s331 | N | 1680 | 432 | 417 | 0 | 7 / 10 | 294 |
| J4_s331 | N | 1430 | 802 | 802 | 5 | 6 / 12 | 363 |
| L3_s331 | R | 1397 | 488 | 481 | 0 | 2 / 12 | 791 |
| T30_s331 | R | 1517 | 418 | 418 | 0 | 1 / 12 | 835 |
| P03_s331 | R | 1606 | 528 | 251 | 0 | 0 / 12 (overlap 7, not essential 5) | — |
| R04_s331 | R | 1657 | 420 | 420 | 0 | 0 / 12 (not essential) | — |
| P07_s331 | N | 1496 | 393 | **4** | 0 | 0 / 4 | — |
| H2_s331 | N | 1511 | **0** | 0 | 0 | — | — |
| J1_s331 | R | 1197 | **0** | 0 | 0 | — | — |
| P03_s332 (round 2) | R | 1672 | 809 | 313 | 0 | 4 / 12 | 390 |
| R04_s332 (round 2) | R | 1857 | 461 | 442 | 0 | 2 / 11 | 323 |
| P07_s332 (round 2) | N | 1581 | 244 | **0** | 0 | — | — |

- **H2 and J1** produced no qualifying board; with an empty pool they were not eligible for round 2.
- **P07** produced only engine-invalid tokens (the token guard rejected them) in both rounds.
- **Size:** Phase 32 produced 0 qualifying boards at ≤ 150 positions. Phase 33 produced 48, all from arm R (T01r, T10b) and J4. Fewer positions is advisory only, not a goal.

**Full evaluations:** the two smallest distinct screen-PASS boards of each core (one for T30). **17 / 17 are HUMAN-REVIEW CANDIDATE**; none failed a gate.

## E. Candidate selection evidence

**Rule** (pre-registered, `data/dev/extreme90_p33/select33.py`, applied mechanically): one board per concept, the fewest positions among fully qualified boards; pairwise overlap ≤ 0.30, conflicts resolved by fewest positions; at most 8. **The advisory predictors were not used to select or reject.**

- 9 concepts qualified.
- **J5 and P03 dropped:** every one of their qualified boards overlaps the T01r board by more than 0.30 (J5 0.39; P03 0.35). The cap of 8 was not reached.
- **7 boards selected, N94–N100.** Maximum pairwise overlap 0.29. 5 from arm R, 2 from arm N.

**TECHNICALLY QUALIFIED — HUMAN UNTESTED.** Records `data/dev/ta90_n94.json` … `ta90_n100.json`; `selection.json`, `fingerprints.json`, `struct_selected.json`.

| ID | Source | Concept | Mechanics | Arm (approved sibling, overlap) |
|---|---|---|---|---|
| **N94** | T01r_s331_3 | the pulled trigger | magnet, switch, spinner | R (N83, 0.32) |
| **N95** | T10b_s331_2 | the blocked key ladder | switch, lock, spinner | R (N86, 0.26) |
| **N96** | K08_s331_2 | the pulled target | magnet, switch, spinner | N |
| **N97** | R04_s332_1 | the armored key | switch, lock, armor, spinner | R (N75, 0.22) |
| **N98** | J4_s331_6 | the two-hop relay | magnet, armor | N |
| **N99** | L3_s331_7 | the reversal frees the shell | switch, armor, spinner | R (N62, 0.30) |
| **N100** | T30_s331_7 | two keys, one reversal | switch, lock, spinner | R (N87, 0.32) |

**Full metrics (desktop, unchanged tools):**

| ID | Positions | Solution | Distinct mistakes | Steps | Coverage | Late | Shortcut | Solve ms | TIME UP ms | Bank overlap | WebAssembly TIME UP ms |
|---|---|---|---|---|---|---|---|---|---|---|---|
| N94 | 95 | 15 | 6 | 13 | 0.87 | 0.87 | 0.085 | 7.1 | 5.5 | 0.33 N75 | 7.6 |
| N95 | 136 | 15 | 5 | 12 | 0.80 | 0.80 | 0.100 | 2.8 | 1.7 | 0.35 N9 | 1.0 |
| N96 | 294 | 14 | 5 | 12 | 0.86 | 0.86 | 0.017 | 5.0 | 6.7 | 0.31 N47 | 5.8 |
| N97 | 323 | 19 | 4 | 17 | 0.89 | 0.89 | 0.060 | 2.6 | 1.6 | 0.36 N79 | 1.2 |
| N98 | 363 | 13 | 4 | 10 | 0.77 | 0.77 | 0.135 | 2.7 | 2.9 | 0.35 N48 | 2.0 |
| N99 | 791 | 19 | 4 | 16 | 0.84 | 0.84 | 0.017 | 2.3 | 3.7 | 0.30 N62 | 1.1 |
| N100 | 835 | 17 | 4 | 15 | 0.88 | 0.88 | 0.125 | 4.0 | 3.6 | 0.32 N87 | 3.3 |

Every board clears every gate unchanged: distinct ≥ 4, steps ≥ 8, coverage ≥ 0.60, late ≥ 0.75, solution ≥ 13, shortcut ≤ 0.20, solve and TIME UP ≤ 40 ms, strict essentiality, 0 filler, bank overlap < 0.40, engine-valid tokens, hint-follow.

**Advisory predictions** (recorded before any human play; **none validated** — section C; not used to select; the owner is the judge):

| ID | Positions (P1, lower = approved?) | early3 (P2) | Tempting fatal openings (P3) | Look-2 win chance (P4) |
|---|---|---|---|---|
| N94 | 95 | 6 | 3 | 0.000 |
| N95 | 136 | 5 | 2 | 0.022 |
| N96 | 294 | 8 | 2 | 0.002 |
| N97 | 323 | 7 | 2 | 0.004 |
| N98 | 363 | 6 | 2 | 0.001 |
| N99 | 791 | 8 | 2 | 0.003 |
| N100 | 835 | 4 | 1 | 0.013 |
| *P25+ approved medians* | *251* | *4* | *1* | *0.001* |

- **What the owner's ratings will test:**
  - **Core transfer:** the approval share of arm R (N94, N95, N97, N99, N100) vs arm N (N96, N98).
  - **The prospective record of P1 and P2:** N94 and N95 are in the size range of every Phase 31 approval (≤ 143 positions); N99 and N100 are far above it.
- **No claim of difficulty is made.** The selection gives the owner technically sound boards. Nothing here predicts which will be EXTREME.

## F. Dedicated Phase 33 QA page

**`?extreme90p33=1`** (`scripts/social/extreme90_p33.gd`, class `Extreme90P33 extends Extreme90P32`):
- **Main screen:** CHALLENGE 1–7 = N94–N100 only.
- **PREVIOUS CHALLENGES:** the Phase 32 page's 79 boards (N88–N93 first).
- **Storage and export:** own storage (`xb33_*`) and export (`ce-xb33`, selection `xb33-v1`), DEV BUILD `p33-qa1-20261103`.
- **Groups:** N88–N93 → `downgraded` (owner: not approved); every earlier group kept.
- **Rules unchanged:** 90 s countdown; unlimited RESTART; UNDO ×3; HAMMER 0; SHOW A MOVE 0; first-exposure tracking; difficulty and enjoyment questions; COPY ALL RESULTS JSON; the exact TIME UP continuation; fingerprints.
- **Untouched:** every earlier page and its storage, the campaign and the 120-second baseline.
- **Wiring:** `game_manager.gd` entry; `ta90_time_attack.gd` BOARDS90 (N94–N100 with fingerprints); `ta90_check.gd`; `ta90_continue_check.gd` (N94–N100 added); `web_extreme90_page_test.mjs` (`--entry=extreme90p33`).
- **Check:** `tools/extreme90p33_check.gd` (`Extreme90p33Check.tscn`), derived from the Phase 32 check: offsets shifted by 7, previous list = the Phase 32 page, 23 downgraded including N88–N93 — **378 checks passed**.
- **ID N100:** the first three-digit ID. Checked in the page, the export (CHALLENGE 7) and the browser test.

## G. Complete regression report

Evidence: `data/dev/extreme90_p33/qa/` (`summary.txt` is the chain's own log, including every restart). All steps ran against the tested build (web `index.pck` sha256 `980850a9…2fe8`; player `d203ee92…49ed`).

**Passed:**
- **Headless:**
  - Extreme90p33Check 378;
  - Extreme90p18–p32 checks, all passed;
  - Ta90Check 91;
  - Ta90ContinueCheck 955 (343 cases, 0 not resumed exactly);
  - Ta90DeadendCheck N94–N100 49;
  - hint-follow N94–N100 7/7;
  - Portal, Movable and Magnet checks;
  - XB28 validate;
  - verify_levels: **all 300 Classic levels solvable and pass the campaign rules**.
- **Suites:** 17/19 pass. This includes Extreme11Check (the 40 ms gate, unchanged), TimingCheck, Q1TimeCheck, Ta90Check and TaPilotCheck.
- **Browser:**
  - web_p33 190/190;
  - every earlier page p32–p17 (176, 164, 154, 144, 130, 114, 112, 106, 94, 92, 84, 66, 62, 55, 51);
  - p19 upgrade 9/9;
  - EXTREME archive 45/45;
  - ta90 55/55;
  - tapilot 28/28;
  - friend build 25/25;
  - stime 31/31;
  - ttime (tta) 32/32.
- **After the human results were recorded:** Extreme90p33Check 378, Ta90Check 91, Ta90ContinueCheck 955 and RTimeCheck 39 all passed (`after_results.txt`).

**Not passed, and investigated:**
1. **RecipientTest** fails with exactly the same FAIL lines as in Phase 32 (diffed). This is a known, pre-existing failure.
2. **RTimeCheck:** one suite failure, "SHOW A MOVE does not pause the clock" (`qa/rtime/RTimeCheck_suite_fail.log`).
   - It then passed 6/6 idle runs (current tree against `649c33a`, alternating), 6/6 runs under load, and the after-results rerun.
   - No Phase 33 code is on its path.
   - **The original cause remains unknown.** The failing evidence is preserved, and the failure is not classed as noise.
3. **web_timing_test check A** (Classic Level 1, production player build) failed once in the chain: active 8,932 ms against a test wall clock of 8,747 ms. The allowed slack is +150 ms (`qa/timing/`).
   - **Idle A/B, serial and alternating:**
     - current builds: 2 of 3 runs failed;
     - **Phase 32 builds (`player32` / `web32`): 3 of 3 failed**;
     - only check A failed in every run.
   - **Instrumented scratch copy** (the repo test is unchanged; `timing/web_timing_diag.mjs`):
     - The test's start mark lags the page's own "title gone" frame by 155–232 ms, because of its 100 ms poll plus round trips to the page.
     - The winning touch reaches the page 83–92 ms after the test's end mark.
     - Measured inside the page from title-gone to the winning touch, the recorded active time is **61–144 ms below** that window in 4 of 4 runs.
     - So the game's timer does not over-count. The excess comes from the test's measurement window.
   - **Not a Phase 33 regression:** it reproduces on the Phase 32 baseline, and Phase 33 changes no Classic code.
   - **Unknown:** why the lag exceeds the slack in this container now, when the same Phase 32 build passed during Phase 32 QA.
   - **Unchanged:** the test, its 150 ms slack and the timer.
   - **Proposed fix (owner decision, not applied):** take both marks inside the page.

**Run conditions:**
- **Container restarts and time limits:** the container restarted four times (06:17, 08:29, 09:12, 10:26) and the 2-hour background time limit was hit twice (12:27, 14:27). Each time the chain resumed and skipped the steps that had already passed. Interrupted partial logs are kept as `*_interrupted*.log`, and none of them contained a FAIL.
- **Parallel work:** the action-log replay (section M) ran at nice 19 during web_p27, which passed 114/114.

## H. Downloadable QA ZIP

`build/dev_qa/chain_escape_dev_extreme90p33_p33-qa1-20261103.zip`:
- 16,269,255 bytes;
- sha256 `83fe3500b565da16eb5f5bc6a0fa6a6781e2159185cb50a132c0a0f65963a046`;
- its `index.pck` matches the tested build (`pck_match=yes`);
- attached to the conversation.

This ZIP was the build the owner played (DEV BUILD `p33-qa1-20261103`). It was not rebuilt after the results came in, and the export identity is preserved. `build/` is not committed.

## I. Final local Phase 33 commit

One local commit on `claude/elegant-fermat-0jrmxo`, on top of `649c33a` (Phase 32). Not pushed, not deployed; Production untouched.

**Contents:**
- `data/dev/extreme90_p33/`, including `human/` and `qa/`;
- records `ta90_n94`…`ta90_n100`;
- `scripts/social/extreme90_p33.gd`;
- `tools/extreme90p33_check.gd` and its `.tscn`;
- the Phase 33 tools (`extreme90_gen33.py`, `extreme90_val33.py`, `ta90_struct33.gd`, `ta90_replay33.gd`);
- the wiring files listed in section F;
- this document.

**Excluded:** `tools/__pycache__`, `build/`.

The approved bank stays **38 / 50**. N94, N99 and N96 await the owner's explicit decision.


## J. Human results (owner first exposure, build p33-qa1-20261103)

**Sources, both from the owner on 2026-11-03, recorded verbatim:**
1. **The "Phase 33 human results" message:** rating, 90-second outcome, completion time and enjoyment.
2. **The Phase 33 data correction:** the summary of the owner's complete **COPY ALL RESULTS JSON** for N94–N100: attempts, restarts, Undo, moves, outcome and rating.

**Files:**
- `data/dev/extreme90_p33/human_p33.json` holds the ratings and play counts.
- `data/dev/extreme90_p33/owner_status_n94_n100.json` holds the decision status, kept apart from the ratings.
- Both are written by `human/make_human33.py`.

**Fingerprints:** each record's fingerprint was checked against `fingerprints.json` and the board record.

**Action logs (update):** the owner then supplied a faithful compact transcription of the export's seven timed runs, action logs included.
- Provenance: format `ce-xb33`, build `p33-qa1-20261103`, selection `xb33-v1`, questionnaire `xb90-short-v1`, session `a3f8534565e75f12`, EXPERIENCED PLAYER.
- Files: `human/xb33_logs_transcription.txt` (verbatim) and `xb33_logs.json`.
- **Every event was validated on the engine** (section M). The export file itself is not in the repository.

| Board | Arm | Core | Rating | 90 s outcome | Attempts | Restarts | Undo | Moves | Time | Enjoyment | Owner status |
|---|---|---|---|---|---|---|---|---|---|---|---|
| N94 | R (N83) | T01r | EXTREME | TIME UP | 4 | 3 | 4 | 32 | — | 5/5 | recommended, **not confirmed** |
| N95 | R (N86) | T10b | MEDIUM | completed | 2 | 1 | 0 | 18 | 31.2 s | 5/5 | not approved |
| N96 | N | K08 | VERY HARD | TIME UP | 4 | 3 | 1 | 35 | — | 5/5 | borderline, **owner judgment** |
| N97 | R (N75) | R04 | MEDIUM | completed | 2 | 1 | 0 | 22 | 40.5 s | 5/5 | not approved |
| N98 | N | J4 | MEDIUM | completed | 2 | 1 | 0 | 19 | 36.3 s | 5/5 | not approved |
| N99 | R (N62) | L3 | EXTREME | TIME UP | 4 | 3 | 0 | 31 | — | 5/5 | recommended, **not confirmed** |
| N100 | R (N87) | T30 | MEDIUM | completed | 1 | 0 | 1 | 18 | 23.6 s | 5/5 | not approved |

**Board records (`ta90_n94` … `ta90_n100`):** updated as N88–N93 were in Phase 32.
- Each record's `human_test` holds the owner's ratings.
- `owner_decision` is set only for the four NOT APPROVED boards. A recommendation or a borderline is a status, never a decision.
- **New labels:**
  - "HUMAN TESTED, RECOMMENDED FOR APPROVAL (NOT OWNER-CONFIRMED)": N94, N99.
  - "HUMAN TESTED, BORDERLINE (OWNER JUDGMENT PENDING)": N96.
  - "HUMAN TESTED, NOT APPROVED": N95, N97, N98, N100.
- **The page does not read these fields.** The tested build and the ZIP (H) still hold the before-play labels, as in Phase 32.

**Every board scored 5/5 enjoyment,** so enjoyment does not separate them.
- **The three hard boards:** 4 attempts, 3 restarts and 31–35 moves each, and no solve inside 90 s.
- **The four MEDIUM boards:** solved in 23.6–40.5 s, three on the 2nd attempt and N100 on the 1st.

## K. What Phase 33 shows (descriptive; n = 7; no causal claim; no new gate)

Run with `human/compare33.py` (output in `compare33.txt`) and `human/prospective33.py` (output in `prospective33.txt`).

**1. Reused approved cores vs new family cores.**
- **Arm R:** 5 boards, **2 recommended (N94, N99)**, 0 borderline, 3 MEDIUM.
  - Per core attempted: 2 / 8. J1 produced no qualifying board. J5 and P03 qualified but were dropped for pairwise overlap.
- **Arm N:** 2 boards, **0 recommended**, 1 borderline (N96), 1 MEDIUM.
  - Per core attempted: 0 / 4. H2 and P07 produced no qualifying board.
- **Both boards rated EXTREME came from reused approved cores.** The one other hard rating, N96, came from a new core.
- **With n = 5 and n = 2 this does not show that reuse works better.** The arms also differ in concept, mechanics and seed.

**2. Within arm R, the sibling's own rating.**
- **EXTREME-rated siblings:** N83 → N94 EXTREME; N62 → N99 EXTREME; N86 → N95 MEDIUM. **2 / 3.**
- **VERY HARD siblings:** N75 → N97 MEDIUM; N87 → N100 MEDIUM. **0 / 2.**
- The pattern is suggestive and very small. Approval does not reliably transfer: N86's core gave a MEDIUM board.

**3. Structure (measured before play).**
- **N94 and N99 differ on almost everything:** 95 vs 791 positions; early3 6 vs 8.
- **Shared by N94, N96 and N99:**
  - beyond_undo 0.83–1.0;
  - trap_depth_median 7–12;
  - early3 ≥ 6.
- **MEDIUM boards overlap these ranges.** N97 has early3 7, and N100 has beyond_undo 1.0 with trap depth 12.
- **No measure separates the groups.**

**4. Provisional prospective check of the pre-specified predictors.**
- **Method:**
  - Thresholds are fitted exactly as `tools/extreme90_val33.py` does, on the 71 study boards of phases ≤ 32.
  - The outcome is a **rating proxy**, because approval is not yet confirmed: N94 and N99 count as positive, the four MEDIUM boards as negative, and N96 is excluded.
- **Result: no predictor beats always-not-approved (4 / 6).**
  - P1 (positions ≤ 190), P4, P5 and P6 tie the baseline at 4 / 6.
  - **P2 (early3 ≤ 5)**, the best in the chronological validation, scores **2 / 6**: it flags N95 and N100 (both MEDIUM) and misses both recommended boards.
  - P7 scores 3 / 6.
- **All predictors stay advisory and none becomes a gate.** The evidence against using them to select boards is now stronger.

**5. Play behaviour.** Analysed in full from the validated action logs in **section M**. The counts above (attempts, restarts, Undo, moves) are confirmed there by the engine replay.

**6. Selection rule.** "The fewest positions" chose N94, the smallest board, which was rated EXTREME. It also chose N95, the second smallest, which was rated MEDIUM, while N99 at 791 positions was rated EXTREME. This round neither supports nor refutes the rule.

## L. Recommendation for Phase 34 (not started; nothing generated)

**Standard unchanged.**
- EXTREME means exceptional strategic difficulty for experienced players on the 90-second clock.
- **No filler, no excess pieces and no added complexity.** Every gate stays: the 40 ms limits, strict essentiality, 0 filler, hint-follow, the eval25 full thresholds, bank overlap < 0.40 and pairwise overlap ≤ 0.30.
- The solver, the generator (c1ddc89), the mechanics, Classic and the 120-second baseline stay unchanged.

**Run after the owner decides on N94, N99 and N96.** Those decisions change which cores count as approved, so the plan below is conditional and should be pre-registered once they arrive.

1. **Arm R, the main arm (about 60–70% of the budget):** reuse approved cores whose board was rated **EXTREME**.
   - Cores that have not yet had a second board:
     - P03 (N64): it qualified in Phase 33 but was dropped for overlap with T01r;
     - J5 (N61): also dropped for overlap; it is VERY HARD, so lower priority;
     - J1 (N59): no qualifier on seed 331; one new seed;
     - R02b (N72) and R01b (N77): magnet × reversal, never reused;
     - L3 and T01r a third time, only if a new board stays under 0.40 overlap with both earlier boards from that core.
   - **Deprioritise, but do not exclude,** cores whose board was VERY HARD (R04, T30). Phase 33 is 0 / 2 there. That is an allocation choice, not a gate.
2. **Arm N, a small exploration arm (2–3 cores):** new cores in the families with Phase 25+ approvals, mainly magnet × reversal. That keeps a source of new designs as reused cores run out.
   - If the owner approves N96, K08 moves to arm R.
3. **Keep the Phase 31/33 method and budget:** 16 runs of 12 minutes, 24 full evaluations, and selection by the unchanged baseline rule. Selection stays the same so arm results stay comparable across rounds. Record each board's arm, its sibling, the sibling's rating and its overlap to the sibling.
4. **Pre-register the comparison:** EXTREME-sibling reuse vs VERY-HARD-sibling reuse vs new cores. Report it per arm. Draw no conclusion until each arm has about 10 or more rated boards.
5. **Predictors stay advisory and no new mandatory gates are added.** Phase 33 is one round and its prospective check failed (K.4).
6. **Replay every first-exposure log on the engine** with `tools/ta90_replay33.gd`. Record the measures of section M per board as **advisory, pre-registered hypotheses** (M.7), never as gates. Ask the owner for each round's COPY ALL RESULTS export.


## M. Human behaviour from the action logs (engine replay)

**Method.**
- `tools/ta90_replay33.gd` replays each run on the real rules: the same board record, and the same model build and move dispatch as the page's exact TIME UP continuation (`Ta90TimeAttack._replayed`).
- **Each event is checked against the engine.**
  - **Move:** the logged block must be playable. The board diff must give back the same block and the same effects, using `VhHumanTest.infer_tap` and `mech_events`, copied verbatim.
  - **Undo:** restores the position before the last move; 3 per attempt.
  - **Restart:** returns to the start position.
  - **Blocked tap:** the block must not be playable.
  - **Armored tap:** the block must be armored.
- **After each move:** whether the board can still be cleared (exact Solver), how many legal moves the position offered and how many of them win, and the **depth** of every losing alternative.
- **Depth** is the longest run of legal moves still possible after a losing move, which measures how long a mistake can stay hidden. The Undo allowance is 3, so a mistake of depth ≥ 4 can outlast it.
- **Choice point:** a winnable position with at least one winning and at least one losing legal move.
- **Outputs:**
  - `human/replay33.txt` and `replay33.json`: the full replay;
  - `human/attempts33.py` → `attempts33.txt`;
  - `human/choices33.py` → `choices33.txt`.

### M.1 Validation of the supplied logs (deliverable A): 49 / 49 checks pass

On every board:
- the fingerprint matches the board record;
- the piece count matches;
- every one of the 189 logged moves is legal and reproduces its block and its effect counts exactly;
- every Undo, blocked tap and armored tap is consistent;
- escapes, max cleared, cleared at end and the effect totals equal the supplied summary.

Timestamps are monotonic. Timer stages fire at 0, 30, 60 and 80 s (90-second rules).

**Recording behaviour that needs special interpretation (deliverable I), all confirmed in the code and by the replay:**
1. **The solving escape of a completed board is never logged.** The log is written by a per-frame poll (`VhHumanTest._track_pauses`), and the solved puzzle stops it. On all four completed boards exactly one escapable block is left after the log, and the last logged event is 0.2–0.6 s before the recorded elapsed time.
2. **`moves` counts escapes only** (`SocialPlay.total_moves`). Rams are logged as `m` but are counted separately; that is why N97 logs 27 moves against 22, N98 23 against 19, and N99 38 against 31.
3. **`first_move_ms` is the first escape, not the first ram.** For example, N97 logs a ram at 1.99 s, while first_move is 2.905 s.
4. **The 3-Undo allowance is per attempt.** `SocialPlay._load_puzzle` resets `undos_used` on Restart. N94's 4 Undos are 1 + 3, which is legal.
5. **`unaided_max_cleared` is one below `max_cleared` on completed boards,** for the same reason as item 1. It does not indicate help: SHOW A MOVE is 0 on this page.
6. **N98's armored tap and the logged move come from one touch.**
   - The tap on shell #8 (R6C2) at 16.868 s is 4 ms before the move of magnet #6, which sits directly above it (R5C2).
   - The armored-tap log comes from the touch handler's nearest-block guess (`_note_tap`), while the move comes from the board diff.
   - So this "armored tap" is most likely the same touch that moved #6. It is not evidence of an attempt to escape the shell.
7. **Logged times are poll times,** about one frame after the touch. TIME UP is logged 23–37 ms after 90.000 s.

### M.2 Attempt by attempt (deliverable B; measured)

Times are seconds from the start of the attempt. "Depth" is the depth of the losing move. "After" is the number of moves made in the lost position. "Same" is the number of opening moves identical to the previous attempt. "Choices" is consequential choices won / met.

| Board | Att | Duration | End | Escapes (rams) | Undo | Blocked | Cleared | First losing move (move no., time) | Legal / winning there | Depth | After | Same | Choices |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N94 | 1 | 22.0 | restart | 4 | 1 | 0 | 3/15 | #0 P> R1C7 (1, 4.7 s) | 5 / 2 | 11 | 3 | – | 0/1 |
| N94 | 2 | 23.6 | restart | 12 | 0 | 2 | 12/15 | #1 B^ R2C4 (5, 12.4 s) | 3 / 1 | 8 | 7 | 0 | 4/5 |
| N94 | 3 | 4.4 | restart | 1 | 0 | 0 | 1/15 | #2 spinner R2C5 (1, 1.1 s) | 5 / 2 | 4 | 0 | 0 | 0/1 |
| N94 | 4 | 40.1 | TIME UP | 15 | 3 | 0 | 12/15 | #0 P< R1C7 (7, 20.5 s) | 3 / 1 | 6 | 8 | 0 | 6/7 |
| N96 | 1 | 27.5 | restart | 12 | 1 | 0 | 11/14 | #12 spinner R7C4 (1, 6.0 s) | 4 / 2 | 11 | 11 | – | 0/1 |
| N96 | 2 | 31.9 | restart | 12 | 0 | 3 | 12/14 | #12 spinner R7C4 (3, 4.3 s) | 4 / 2 | 9 | 9 | 0 | 2/3 |
| N96 | 3 | 9.1 | restart | 3 | 0 | 0 | 3/14 | #9 magnet R6C3 (2, 5.7 s) | 5 / 2 | 10 | 1 | 1 | 1/2 |
| N96 | 4 | 21.5 | TIME UP | 8 | 0 | 0 | 8/14 | #12 spinner R7C4 (3, 9.4 s) | 4 / 2 | 9 | 5 | 1 | 2/3 |
| N99 | 1 | 23.9 | restart | 7 (2) | 0 | 1 | 7/16 | #14 switch R7C3 (5, 12.0 s) | 5 / 3 | 10 | 4 | – | 3/4 |
| N99 | 2 | 26.1 | restart | 10 (2) | 0 | 1 | 10/16 | #14 switch R7C3 (10, 21.4 s) | 2 / 1 | 5 | 2 | 3 | 3/4 |
| N99 | 3 | 34.2 | restart | 13 (2) | 0 | 4 | 13/16 | #8 switch R3C7 (2, 15.6 s) | 5 / 3 | 13 | 13 | 1 | 1/2 |
| N99 | 4 | 5.8 | TIME UP | 1 (1) | 0 | 0 | 1/16 | never lost | – | – | 0 | 1 | 2/2 |
| N95 | 1 | 12.4 | restart | 3 | 0 | 0 | 3/15 | #8 spinner R4C5 (2, 4.6 s) | 3 / 1 | 3 | 1 | – | 1/2 |
| N95 | 2 | 18.8 | **solved** | 15 | 0 | 0 | 15/15 | never lost | – | – | 0 | 0 | 10/10 |
| N97 | 1 | 17.4 | restart | 6 (3) | 0 | 0 | 6/16 | #2 Y> R1C4 (7, 10.4 s) | 4 / 1 | 3 | 2 | – | 6/7 |
| N97 | 2 | 23.0 | **solved** | 16 (2) | 0 | 0 | 16/16 | never lost | – | – | 0 | 0 | 11/11 |
| N98 | 1 | 21.5 | restart | 9 (2) | 0 | 0 | 9/10 | #5 magnet R5C2 (4, 11.7 s) | 5 / 3 | 7 | 7 | – | 3/4 |
| N98 | 2 | 14.8 | **solved** | 10 (2) | 0 | 0 | 10/10 | never lost | – | – | 0 | 3 | 8/8 |
| N100 | 1 | 23.6 | **solved** | 18 | 1 | 0 | 17/17 | #15 switch R7C1 (8, 13.1 s), **undone 2.8 s later** | 3 / 2 | 2 | 0 | – | 14/15 |

**Measured, not inferred:**
- **All 11 blocked taps** (N94 2, N96 3, N99 6) happened **in positions that were already lost.** None happened in a winnable position.
- **No Undo on a hard board recovered a winnable position.** The Undos came 1–10 moves after the losing move. N94's attempt 4 was 5 moves past it, beyond the 3-Undo allowance.
- **The only recovery was N100's.** One Undo, immediately after a depth-2 error, made the board winnable again.

### M.3 The earliest rigorous deviation (deliverables D, G)

**The earliest rigorous deviation is the first move after which the board can no longer be cleared.** That is the first losing move in M.2.

**The solver's own sequence is not a useful reference.** The player's moves follow it for only 0–4 moves (`solver_prefix`), yet both solved MEDIUM second attempts were never lost. Each board has many winning orders, so "different from the solver's sequence" is not "wrong". The analysis uses winnability, not sequence match.

### M.4 Hard vs MEDIUM (deliverables C, H; measured, n = 7 boards, one player)

| Measure (all attempts) | Hard: N94, N96, N99 | MEDIUM: N95, N97, N98, N100 |
|---|---|---|
| Consequential choices met | 35 | 57 |
| Losing alternatives at those choices with depth ≥ 4 | **92%, 100%, 100%** | 60%, 67%, 96%, 67% |
| Errors where a deep (≥ 4) trap was on offer | **11 / 35 (0.31)** | 1 / 38 (0.03) |
| Depth of the losing moves actually made | **11, 8, 4, 6, 11, 9, 10, 9, 10, 5, 13 (median 9)** | 3, 3, 7, 2 (median 3) |
| Moves played in a lost position before restart or end | 3, 7, 0, 8, 11, 9, 1, 5, 4, 2, 13 (median 5) | 1, 2, 7, 0 (median 1.5) |
| Same block lost in more than one attempt | N94 #0 (×2), **N96 #12 (×3)**, N99 #14 (×2) | — (one loss per board) |
| Attempt after the first restart | lost again or ran out of time in all 9 later attempts (8 lost; N99 attempt 4 timed out unlost after 5.8 s) | **error-free** on N95, N97 and N98; N100 was never restarted |
| Winning share at the losing decision | median 0.50 | median 0.47 |
| Move number of the first loss | median 3 | median 5.5 |
| Time to the first move of an attempt | median 4.1 s | median 1.8 s |

**What the measurements show:**
- **Both groups faced consequential choices.** The MEDIUM boards' solved attempts navigated 8–15 such choices without error, so MEDIUM does not mean choice-free. **The number of choices does not separate the groups** (deliverable H).
- **What separates them, measured:**
  - **How late the player's errors became visible.** On the hard boards almost every trap was deep, and every error fell into one; the player then made a median of 5 more moves before the position showed itself. On the MEDIUM boards three of the four errors had depth 2–3, were noticed within 0–2 moves and cost one restart (or one Undo on N100). The next attempt was clean.
  - **N98 is the exception:** a depth-7 error on a MEDIUM board, played 7 moves deep, then a clean second attempt. Depth alone does not decide the rating.
- **Repetition.** On the hard boards the same losing decision recurred across restarts: N96's spinner #12 in 3 of 4 attempts, N99's switch #14 in 2, N94's #0 in 2. This fits feedback arriving many moves after the cause, though the log cannot show what the player believed.
- **The winning share at the losing decision is the same in both groups** (about 1 in 2). The hard boards' traps are not narrower, only longer-hidden.
- **The pre-play structure measures do not separate the groups:** N100's `trap_depth_median` is 12 and its `beyond_undo` is 1.0, like the hard boards. The separating measure depends on the path: which deep traps sit where a player actually goes. That cannot be measured before play.

### M.5 Failure types per board (deliverable F; inferred from the measured facts, labelled)

- **N94 (EXTREME):** four losing decisions at three different blocks (#0 twice at moves 1 and 7, #1 at move 5, #2 at move 1). Depths are 4–11, and attempts 2 and 4 cleared 12/15 in lost positions.
  - **Reading:** *several distinct late-revealing traps*, plus a *move-order* error at #0 (it lost both first and seventh). The Undos came too late to reach the cause. No sign of rule misunderstanding: every blocked tap was in a lost position.
- **N99 (EXTREME):** switch #14 lost twice, at moves 5 and 10. Switch #8 lost at move 2 in attempt 3, which then ran 13 moves, up to 13/16 cleared, before the dead end showed (depth 13).
  - **Reading:** a *reversal (switch) dependency* that is a *late logical trap*. In attempt 3 the player was misled for 13 moves.
- **N96 (VERY HARD):** 3 of 4 losses were the **same early decision** (spinner #12 at move 1 or 3, with 2 of 4 legal moves winning); the fourth was #9. Depths were 9–11; the player reached 11–12/14 in lost positions.
  - **Reading:** *one recurring misleading move-order choice* with a deep consequence, and repeated ineffective experimentation around it.
- **MEDIUM boards:** one error each.
  - N95 (spinner) and N97: depth 3.
  - N98 (magnet): depth 7.
  - N100 (switch): depth 2, undone at once.
  - **Reading:** each was *immediately or quickly visible*, learnt in one attempt; no repetition.

### M.6 The three questions

**Why four attempts and EXTREME on N94 and N99, while the MEDIUM boards fell in 23.6–40.5 s?**
- **The plausible structural explanation, consistent with every measurement above:** on N94 and N99 the player's mistakes were deep traps, hidden for 4–13 moves, and they sat at more than one decision. Each restart taught little, and the same or a new trap caught the next attempt.
- **On the MEDIUM boards** the one mistake showed itself within about 3 moves, so one restart, or one Undo, sufficed.
- **This explains the outcome, not the player's reasoning.** TIME UP alone does not prove EXTREME.

**Why VERY HARD rather than EXTREME on N96, despite TIME UP?**
- **The logs show a difference in shape, not a measured cause.** N96's losses concentrate on **one** decision, spinner #12, early in the attempt. N94 and N99 caught the player at **several** distinct decisions, some late (move 5–10).
- **Hypothesis:** a single recurring insight point reads as "very hard". Several independent deep traps read as "extreme".
- **This cannot be confirmed from one player's logs.** The rating is the owner's judgment.

**Can the logs give structural explanations without claiming the player's reasoning?** Yes, as above. Everything in M.1–M.4 is measured; M.5–M.6 are labelled readings of those measurements.

### M.7 Measured vs inferred (deliverable D) and hypotheses for Phase 34

**Measured from the validated logs and the engine:**
- everything in M.1–M.4;
- legality, winnability, depths, choice points, repetitions, recovery, blocked-tap context, timings.

**Inferred (labelled):**
- the failure types in M.5;
- the explanations in M.6;
- that late feedback causes repetition.

**Not inferred at all:**
- intent, attention or reasoning from pauses (timings are only reported);
- that a long pause was thinking;
- that TIME UP means EXTREME.

**Hypotheses to pre-register for Phase 34 and test on the next rated boards.** All are advisory; **none is a gate.** Each came from 7 boards and one player.
- **H1:** EXTREME boards are those where the *errors players actually make* are deep (≥ 4, beyond Undo). Measure by replaying first-exposure logs.
- **H2:** EXTREME needs **more than one** distinct deep-trap decision, rather than one recurring decision (N96).
- **H3:** a MEDIUM rating follows when the most tempting error is shallow (≤ 3), even if deep traps exist elsewhere (N100: board `beyond_undo` 1.0, but the error made had depth 2).
- **Caveat:** none has a pre-play proxy yet; the board-level `trap_depth_median` and `beyond_undo` failed on N100. So they inform *what to look for in the logs*, not how to select boards.
