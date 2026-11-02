# EXTREME 90 — Phase 31: recovering human difficulty

Development only. **Not deployed to Production.** Not touched:
- Supabase;
- the 300 frozen Classic levels;
- the 120-second Time Attack baseline;
- the exact Solver;
- every gameplay mechanic.

Every acceptance gate is the Phase 30 gate, unchanged.

**Owner-approved EXTREME bank: 38 / 50 (12 remaining)**, after the Phase 31 owner decision (section K): **N83, N86 and N87 approved**.
- Before that decision the bank was 35 / 50; sections A–G were written then and say so.
- N84 and N85 are **not** approved.
- N82 is *recommended* for approval but has **not** been approved by the owner, so it is not counted (pending an explicit owner decision).
- N80 stays borderline. N78, N79 and N81 stay outside the bank.

**Labels:** new boards are labelled **TECHNICALLY QUALIFIED — HUMAN UNTESTED** until the owner plays them. After the owner decision (section K), the N83–N87 records carry "OWNER APPROVED" (N83, N86, N87) or "HUMAN TESTED, NOT APPROVED" (N84, N85). Owner approval, human difficulty, technical qualification and release readiness are recorded separately.

**Evidence standard:**
- "Measured" means read from a record, a run file, a Git diff or a command line in this repository.
- "Interpretation" and "hypothesis" are labelled as such.
- The human sample is small and non-random, mostly from one experienced player. **No result here is a causal proof or a significance test.**

## A. Phase 30 closure and summary

**Phase 30 closure (section 3 of the brief):**
- **QA:** the interrupted Phase 30 regression was finished without repeating passed steps (chain 08:50 → 18:11).
  - `web_p30` 154/154; every earlier page passed;
  - 300 Classic levels verified;
  - RecipientTest failed only its 3 known layout checks.
- **Commit:** **local** commit `5ab64b4` on Phase 29 (`7260dd7`). **Not pushed.** Production untouched.
- **Erratum before the commit:** the five Phase 30 records said `--ops=v20`, but every Phase 30 run omitted the flag. The source sentence was corrected; maps and fingerprints are unchanged. The tested Phase 30 ZIP, which the owner already played, keeps the old sentence (Phase 30 report, section K).
- **Phase 31 erratum:** the same error affected the Phase 29 round 92 boards **N71, N72, N76, N77** (RNG seed 92). Their records and `extreme90_p29/selection.json` are corrected in this phase. N73, N74 and N75 (round 91) really used v20 and are unchanged.

**Summary of the Phase 31 result (details in B–G):**
1. **The decline has two measured technical causes, not one.**
   - **(a) The v20 operators were silently off** from Phase 29 round 92 onwards (9 of the 12 most recent boards).
   - **(b) The search itself got narrower from Phase 28:** the reliability checks added *inside* the search (strict essentiality in the search score, spinners_max) steer it away from partial boards the old search kept growing. On 3 of the 6 new concepts the current generator produced **no qualifying board at all**, where the Phase 25–27 generator produced hundreds.
   - **(c) Selection** moved from "fewest positions" to "lowest overlap", which picks large boards (P30 median 774 positions vs 237–251 in P26–P27). Positions is the only record measure that predicted the owner's ratings out of sample.
2. **Controlled comparison (section C):** same cores, same RNG seeds, same 12-minute budget, same modern screen. The Phase 25–27 method found screen-passing boards on **3 / 6** new concepts; Phase 30 as executed on **0 / 6**; the hybrid on **1 / 6**.
3. **Decision (section E):** generate with the **Phase 25–27 generator** (historic code, run in its own worktree; the repository's generator is unchanged) and apply **every** reliability fix **after** generation, in the unchanged modern screen and full evaluation. Select by **fewest positions** per concept.
4. **Result:** **5 new technically qualified boards, N83–N87**, from 5 distinct concepts (pairwise overlap ≤ 0.30, bank overlap ≤ 0.38), at **87–208 positions** (median 143, vs 774 in Phase 30). **TECHNICALLY QUALIFIED — HUMAN UNTESTED.** Whether they are harder for a human is for the owner to judge.

**Owner manifest at the time sections A–G were written: 35 / 50.** N82 not approved (recommended only). After the owner played the Phase 31 page, N83, N86 and N87 were approved: **38 / 50** (section K).


## B. Historical Git and generator audit

**Sources:**
- Git: commits `bb44dd1` (P25), `458fe57` (P26), `c1ddc89` (P27), `3cea3bd` (P28), `7260dd7` (P29), and the Phase 30 commit.
- Every seed spec: `data/dev/extreme90_p2x/seed_*.json`.
- Every run file: `run_*.json`, `runs/*/run.json`.
- The exact launch commands: `round*.sh` and `jobs_round30*.json`.
- The pick and shortlist tools, and each phase's `protocol.json`.

The tools below were recomputed from the raw files:
- `tools/extreme90_features31.py` → `data/dev/extreme90_p31/features_n53_n82.json`;
- `tools/ta90_struct31.gd` → `struct_n53_n82.json`.

**What did NOT change (measured):**
- **Solver and design reports:** the production solver (`scripts/core/solver.gd`) and `tools/ta90_design.gd` have no diff from `c1ddc89` to today. The only generator file that changed is `tools/ta90_search.gd`, in P28 and P30.
- **Search budget per run:** 12 min, batch 40, beam 5, in every phase. Patience was 8 until P30 round 302 and 12 after it.
- **Acceptance gates:** identical since Phase 21. Strict essentiality was already the acceptance rule; P28 moved it into the search.
- **One board per concept:** in force from **Phase 25** (protocol: "one board per core counts"), so it is *not* a difference between the periods.

### Which generator produced each human-rated board (measured: the exact map is found in the run's `qualifying` list)

| Period | v20 operators | baseline operators | Rated VERY HARD / EXTREME |
|---|---|---|---|
| P25–27 (N53–N62, excluding N58 hand-built) | 9 | 0 | 6 / 9 (N58 HARD: 6 / 10) |
| P28 (N63–N70) | 8 | 0 | 3 / 8 |
| P29 (N71–N77) | 3 (N73, N74, N75) | 4 (N71, N72, N76, N77) | v20 1/3, baseline 2/4 |
| P30 (N78–N82) | 0 | 5 | 1 / 5 |

**The decline started in Phase 28, while the v20 operators were still in use.** The operators alone therefore do not explain it.

### Material changes

**1. Generator operators: v20 → baseline (unintended).**

| | |
|---|---|
| **A. Old** | `--ops=v20` (Phase 20 strategic operators): actors of the core's own mechanics, reversible marks, new pieces placed mostly in actor lanes, plus a concurrency score term. Used in P25–P28 and P29 round 91. |
| **B. New** | No `--ops` flag, so `ta90_search.gd` falls back to its baseline edit. Used in P29 round 92 (`scratchpad round92.sh`) and **every** P30 run (`jobs_round30*.json`). |
| **C. Why introduced** | **Not deliberate.** Both protocols say `"ops": "v20"`. The flag was dropped from the launch commands, and the board records repeated "--ops=v20" (corrected in this phase; see A). |
| **D. Potential impact** | Different neighbourhoods searched. v20 grows pieces around the core's actors; baseline places them anywhere they interact. |
| **E. Evidence** | Identical seed files in P29 (different RNG seeds, CPU-saturated v20 runs) gave mixed results. Qualifying counts, v20 vs baseline: R03 163 vs 146, R04 15 vs 0, R06 85 vs 5. Median positions, v20 vs baseline: R03 1155 vs 533. Human: v20 10/20 vs baseline 3/9 across phases, confounded with phase. |
| **F. Decision** | **TEST** (section C), and restore the flag the protocols intended. |

**2. Shortlist order: cheapest first → lowest bank overlap first.**

| | |
|---|---|
| **A. Old** | P25 amendment and `tools/extreme90_pick26.py`: within a run, the **n boards with the fewest solver positions** (cap 900), ties by score. |
| **B. New** | `tools/extreme90_shortlist28.py` (P28–P30): the n boards with the **lowest bank overlap** (cap 700; ties by positions). P30 shortlists went up to ~990 positions (`sl/*.json`). |
| **C. Why introduced** | Novelty against a growing bank. P25 chose cheapest-first only for the 40 ms TIME UP gate, not for human difficulty. |
| **D. Potential impact** | Cheapest-first picks boards with a small state space. Overlap-first picks the most unusual boards, whatever their state space. |
| **E. Evidence** | See the two tables below. |
| **F. Decision** | **TEST, and restore if supported.** Overlap < 0.40 stays a hard gate either way. |

*Evidence for change 2: positions of selected boards versus their qualifying pools (measured).*

| Phase | Qualifying pool median | Selected boards median | Selected boards rated VH / EX |
|---|---|---|---|
| P25 | 811 | 508 | 3/6 |
| P26 | 831 | 237 | 2/3 |
| P27 | 798 | 251 | 1/1 |
| P28 | 810 | 345 | 3/8 |
| P29 | 795 | 517 | 3/7 |
| P30 | 995 | 774 | 1/5 |

*Evidence for change 2: solver positions as an out-of-sample signal (measured).* The table gives the AUC of "fewer positions = rated VH / EX", where 0.5 is chance. Positions is the only record measure whose direction **held out of sample**: it was fitted on P25–28 and checked on P29–30. Look6 greedy, the measure behind the P29 advisory rank, **reversed**. That is consistent with the failed P29 prediction audit (3/7).

| Measure | AUC on P25–28 | AUC on P29–30 |
|---|---|---|
| Solver positions | 0.67 | 0.77 |
| Look6 greedy | 0.78 | 0.30 |

**3. Advisory human-difficulty ranking used in selection.**

| | |
|---|---|
| **A. Old** | P25–26: no ranking; cheapest first. P26 diagnostics were reported but not used. |
| **B. New** | P27: greedy measures in the pick. P28: diagnostics rank. P29: rank29 flags first. P30: rank29 as a tie-break within a concept. |
| **C. Why introduced** | To predict human difficulty before testing. |
| **D. Potential impact** | Moves the pick toward whatever the flags reward. |
| **E. Evidence** | Flags were 3/7 correct out of sample (P30 audit). Look6 AUC reversed (0.78 → 0.30), as did p_calm and calm_prefix (0.72 → 0.42). |
| **F. Decision** | **REMOVE from selection.** Report only. |

**4. Search parameters (P30 round 302+).**

| | |
|---|---|
| **A. Old** | piece_free 13, max_pieces 17, suffix_rate 0.30, patience 8. |
| **B. New** | piece_free 15, max_pieces 19, suffix_rate 0.45, patience 12. |
| **C. Why introduced** | The focused refinement after round 301 stalled at 3 distinct mistakes. |
| **D. Potential impact** | More free pieces, so the state space can grow. |
| **E. Evidence** | The P30 qualifying pool median was 995 positions, against 795–831 in every other phase. Only 5% of the P30 pool had ≤ 400 positions (7–24% elsewhere). |
| **F. Decision** | **TEST** (arms C1 vs C2). |

**5. Concept breadth versus depth.**

| | |
|---|---|
| **A. Old** | P25: 9 cores / 18 runs. P26: 5 / 9. P27: 6 / 10. That is 1.7–2.0 runs per core; a productive core usually got a second RNG seed. |
| **B. New** | P28: 13 / 16. P29: 12 / 15. P30: 20 / 24. That is about 1.2 runs per core. |
| **C. Why introduced** | Concept diversity and novelty against the bank. |
| **D. Potential impact** | Less search inside promising cores. Only one draw from each pool, so the pick has fewer compact options. |
| **E. Evidence** | Indirect: P30 had only 5% compact boards in its pool. The 8 P30 cores with 0 qualifying boards consumed 12 of its 24 runs. |
| **F. Decision** | **Revise:** fewer cores, a second seed only where a core produced PASS boards. |

**6. Frozen hand-core size.**

| | |
|---|---|
| **A. Old** | Median frozen cells: P25 7.5, P26 4, P27 4.5. |
| **B. New** | P28 4, P29 5.5, P30 3–4 (P30 unfroze rammers). |
| **C. Why introduced** | More room for the generator; the P30 core-filler problem. |
| **D. Potential impact** | Less of each board is hand-designed reasoning. |
| **E. Evidence** | In-sample AUC of "larger frozen core = VH/EX" is 0.69; about 0.64 on P29–30 alone. A weak signal. |
| **F. Decision** | **Preserve core_essential**, and prefer cores that keep their decisive pieces frozen. Advisory. |

**7. One board per concept.** Unchanged since P25. The hypothesis "this rule reduced our ability to find the strongest puzzles" is **not supported as a cause of the decline**: the higher-yield period had the same rule. What changed is that each concept got fewer runs (change 5) and a different pick (change 2). **Decision: PRESERVE**, for distinctness.

**8. Reliability fixes: always PRESERVED, never part of any arm's difference in review.**
- Engine-valid tokens: P28 token guard. The invalid rate fell from 28% to 0%.
- Strict essentiality including spinners: P28.
- spinners_max.
- core_essential: P30.
- Early screen with filler and hint-follow: P28 / P30.
- Unique evaluation directories, per-board bench logs, the job runner with DONE markers and exit codes: P30.
- No generator beside timing measurements.
- Every performance limit, and save and QA compatibility.

**9. CPU saturation (P29 round 91).**
- **Measured:** four generators plus other load meant those v20 runs evaluated about 600–830 boards in 12 minutes, against about 1,100–1,500 for uncontended runs. Their search was therefore shallower.
- **Decision:** fixed by the P30 job runner (4 generators and nothing else). Preserve.

## C. Controlled comparison: old, current and hybrid generators

**Protocol** (`data/dev/extreme90_p31/protocol.json`, fixed before any run; amendment AM1 recorded after the experiment and before any further run).

**Arms** (the same 8 hand cores = the Phase 30 seed files; the same RNG seed as the Phase 30 run they pair with; 12 min, batch 40, beam 5; 4 generators in parallel and nothing else, as in Phase 30):

| Arm | Generator | Operators | Search parameters | Runs |
|---|---|---|---|---|
| **A** | `tools/ta90_search.gd` of `c1ddc89` (Phase 27), in worktree `p31/wtA` | v20 | piece_free 13, max_pieces 17, suffix_rate 0.30, patience 8 | 8 |
| **B** | Phase 30 as executed (recorded runs, **not re-run**) | baseline (the missing flag) | 15 / 19 / 0.45, patience 12 | 8 (existing) |
| **C1** | the Phase 30 generator, worktree `p31/wtC` at `5ab64b4` (every fix incl. core_essential) | v20 | the Phase 25–27 parameters | 8 |
| **C2** | the Phase 30 generator | v20 | the Phase 30 parameters | 4 |

- **Comparisons:** C2 vs B isolates the operators; C1 vs C2 the parameters; A vs C1 the in-search reliability checks.
- **Same review for every arm:** each run's qualifying pool is cut to engine-valid, distinct maps; then **both** shortlist rules (S_old: the 5 cheapest; S_p30: the 5 lowest-overlap) go through **one** `tools/extreme90_screen30.py` run: bank overlap, 40 ms gates, strict essentiality, filler, hint-follow.
- **Tools:** `tools/extreme90_exp31.py` (specs and jobs), `tools/extreme90_sel31.py` (both rules on one pool), `tools/extreme90_ana31.py` → `data/dev/extreme90_p31/exp/technical.json`.
- **Jobs:** `exp/jobs_gen.log` (20 experiment runs, all exit 0), `exp/jobs_screen*.log` (screens, all exit 0).

### Measured

Per cell: boards evaluated in 12 min · engine-valid distinct qualifying boards · their median positions · screen PASS over shortlist slots (S_old + S_p30; a board picked by both rules counts in both).

| Core | A (P25–27 method) | B (P30 as run) | C1 (hybrid) | C2 (ops only) | G (Phase 31 runs, arm A method) |
|---|---|---|---|---|---|
| T01r_PULLEDTRIGGER | 1851 · 518 · 384 · 6/10 | 1770 · 0 · — · — | 1309 · 152 · 679 · 0/10 | 1344 · 352 · 911 · 2/10 | s308: 1518 · 378 · 737 · 5/10 |
| T03r_PULLTHEKEY | 1404 · 187 · 951 · 0/10 | 1858 · 0 · — · — | 1460 · 0 · — · — | — | — |
| T05r_ARMOREDLINK | 1626 · 344 · 1326 · 0/10 | 1757 · 0 · — · — | 1571 · 7 · 1609 · 0/0 | — | — |
| T27r_TRIGGERLINK | 1722 · 402 · 724 · 6/10 | 2384 · 0 · — · — | 1811 · 0 · — · — | 1315 · 0 · — · — | s308: 2083 · 661 · 297 · 0/10 |
| T48_BOOMERANGDOOR | 1409 · 145 · 1043 · 0/10 | 1313 · 0 · — · — | 1475 · 0 · — · — | — | — |
| T57_TWOEFFECTS | 2189 · 356 · 982 · 4/10 | 1836 · 0 · — · — | 1624 · 436 · 797 · 6/10 | — | s308: 2215 · 454 · 669 · 7/10 |
| T59_AIMEDRAM | 1504 · 345 · 905 · 7/10 | 1757 · 501 · 1074 · 9/10 | 1339 · 495 · 1095 · 4/10 | 1815 · 517 · 1463 · 8/10 | — |
| T61_BOOMERANGRAM | 1517 · 2 · 463 · 0/4 | 1435 · 393 · 1055 · 0/10 | 1240 · 240 · 1190 · 4/10 | 1837 · 176 · 1248 · 0/10 | — |
| T10_KEYLADDER | — | 1275 · 74 · 803 · 0/10 | — | — | s301: 1560 · 445 · 482 · 3/10 |
| T10b_LADDERBLOCK | — | 1570 · 0 · — · — | — | — | s302: 1473 · 361 · 542 · 8/10 |
| T30_TWOKEYS | — | 1201 · 0 · — · — | — | — | s302: 1112 · 98 · 394 · 6/10 |
| T03_PULLTHEKEY | — | 1580 · 0 · — · — | — | — | s301: 1213 · 294 · 899 · 0/10 |
| T05_ARMOREDLINK | — | 1574 · 0 · — · — | — | — | s301: 1177 · 2 · 822 · 0/4 |

**On the 6 new concepts (T01r, T03r, T05r, T27r, T48, T57):**

| Arm | Runs | With a valid qualifying pool | Concepts with a screen PASS |
|---|---|---|---|
| A | 6 | **6** | **3** (T01r, T27r, T57) |
| B | 6 | **0** | **0** |
| C1 | 6 | 3 | 1 (T57) |
| C2 | 2 | 1 | 1 (T01r) |

**T59 / T61 (calibration only):** their concepts are already N81 / N82. Every arm finds boards there, and near copies of N81 / N82 fail the overlap gate.

**Throughput:** all arms evaluated 1,100–2,400 boards per run, so no arm was starved of CPU.

### What this shows (and does not)

- **Operators (C2 vs B):** on T01r, v20 gave 352 qualifying boards against 0 for baseline; on T27r both gave 0; on T59 / T61 both gave pools. **The missing flag mattered on some concepts, not on all.**
- **In-search reliability checks (A vs C1, same operators, same parameters):** A had a valid pool on 6 / 6 concepts, C1 on 3 / 6. Where both had pools, A's boards were smaller (T01r median 384 vs 679 positions).
  - Mechanism (read from the code of `tools/ta90_search.gd`; the run files show `core_refused` = 0 on C1's empty runs, so core_essential was **not** the cause):
    - with strict_essential (default since P28) every board that holds a spinner counts "spinners" as one more mechanic in the search **score** (+6 if strictly essential, −8 if not) and in the qualification test;
    - spinners_max (4) stops new spinners once 4 are on the board.
    - The beam therefore moves away from intermediate boards whose grown spinners do not *yet* carry decisions. The old search keeps growing them, and many become strictly essential a few pieces later (interpretation, consistent with the pools).
  - Applying the same checks **after** the search keeps the guarantee: 34 of A's shortlist slots failed "not essential" in the modern screen and were discarded, but enough passed.
- **Parameters (C1 vs C2):** mixed (T01r: C2 better; T59 / T61: C1 at least as good). No clear effect.
- **Selection rule:** on the same pools (new concepts, every arm), S_old's 22 PASS boards had **median 210 positions**, S_p30's 31 **median 430**. S_p30 passed the screen slightly more often (fewer overlap failures), S_old produced the small boards.
- **Not shown:** whether any of this makes boards harder *for humans*. That needs the owner's play (pre-registered predictions in G).
- **Limits:** one RNG seed per core and arm; 8 cores. A real difference on 3 / 6 vs 0 / 6 concepts, but not a precise rate.


## D. Human difficulty: structural analysis

**Groups** (first exposure, project owner):

| Group | Boards | Note |
|---|---|---|
| Earlier approved | N53, N55, N56, N59, N61, N62 | |
| Recent approved | N64, N68, N69, N72, N75, N77 | |
| Recent human-easy | N63, N65, N67, N70, N71, N74, N78, N79, N81 | |
| HARD / borderline | N66, N73, N76, N80 | N58 HARD is hand-built |
| Not yet approved | N82 | VERY HARD; recommended for approval |

All numbers come from the exact Solver's full position graph (`tools/ta90_struct31.gd`), unchanged.

### Measured

| Measure (medians) | VH/EX (13) | HARD (5) | EASY/MEDIUM (12) | Direction held P25–28 → P29–30? |
|---|---|---|---|---|
| Reachable positions | **367** | 562 | **546** | yes (AUC 0.67 → 0.77) |
| Winning positions | **51** | 100 | **148** | in-sample only (0.75 → 0.53) |
| Legal opening moves | 4 | 5 | 5.5 | weakly (0.64 → 0.58) |
| Tempting fatal openings (a block escapes, the board is lost) | **1** | 1 | **3** | yes (0.71 → 0.73) |
| **Losing moves in the first 3 solution steps** | **4** | 6 | **7** | yes (AUC 0.87 → 0.83), found post hoc |
| First meaningful choice (step) | 1 | 1 | 1 | no difference: every board has a fatal option at move 1 |
| Forced steps (exactly 1 winning move) | 7 | 8 | 7 | no |
| Optional steps (≥ 2 winning moves) | 10 | 9 | 11 | no |
| Mean winning moves per step | 1.79 | 1.77 | 2.00 | unstable |
| Distinct mistakes on the line | 5 | 5 | 5 | no |
| Mistakes that look like progress (a block escapes) | 100% | 75% | 100% | no: nearly universal |
| Trap depth (longest play still possible after a mistake) | 9 | 10 | 9.5 | no |
| Mistakes hidden ≥ 4 moves (Undo 3 cannot reach back) | 100% | 100% | 100% | no: universal |
| Repeat taps of one block on the line | 3 | 2 | 2 | no |

**Findings:**
- The generator gates already guarantee several features on **every** qualifying board:
  - a fatal option on the first move;
  - mistakes that look like progress;
  - traps that stay hidden longer than Undo 3.

  Those features therefore cannot tell hard boards from easy ones.
- The two measures that separate the groups in both periods are:
  - **the size of the reachable state space**;
  - **how many of the opening moves are tempting and fatal**. On hard boards the start is *quiet*: few moves, and the escapes available are mostly safe.

### Interpretation (not measured; hypotheses for the owner to judge)

- **Small state space.**
  - A small state space means few independent pieces. Almost every move changes what the other pieces can do.
  - When reachable positions are about 200–400, a player who "just tries things" has little room to drift into a winning order by accident. Every line runs into the core's dependency.
  - At 700–900 positions, many orders of satellite pieces are interchangeable. A player can make visible progress, notice a trap late and restart with most of the board already understood.
  - This fits N78, N79 and N81: 774, 791 and 528 positions, solved in 32–46 s.
  - It does not fit every board. N82 has 791 positions and was VERY HARD, and N53 has 623 and was EXTREME. Positions is a tendency, not a rule.
- **Several tempting fatal openings make the core visible early.**
  - On the easy boards, 3 of the opening escapes lose. A player who loses quickly at the start learns where the dependency is in the first 10–20 s.
  - On the hard boards, the opening escapes are mostly safe. The fatal decision comes later, inside a board the player believes is going well. This matches the owner's descriptions of TIME UP after "nearly solving".
- **Why a human might choose incorrectly on the hard boards.**
  - On every board the wrong move is usually an escape: it removes a block and looks like progress, and the loss shows only after 5–15 more moves (measured).
  - What differs is **when the board first punishes a guess**. In the opening steps of the solution line, a hard board offers fewer fatal moves.

**Losing legal moves in the first three steps (measured):**

| Group | Median | Lines (first five steps) |
|---|---|---|
| VH / EX | **4** | N59 `1,1,1,1,1`; N62 `1,1,1,1,2`; N64 `1,1,2,2,2`; N75 `1,1,1,1,1`; N77 `1,1,2,3,2` |
| Others | **7** | N63 `3,3,3,3,3`; N65 `3,3,2,3,3`; N79 `3,2,3,2,3`; N78 `3,3,1,1,1` |

| AUC of "fewer early fatal moves = VH / EX" | P25–28 | P29–30 |
|---|---|---|
| | **0.87** | **0.83** |

- **Interpretation.** With unlimited Restart, a board that is "loud" at the start teaches its constraint in the first attempts. A board that is quiet at the start lets the player build a plan that fails late.
- **Caution.**
  - This measure was found **after** looking at all 30 rated boards, among about 35 measures tried. It is **not validated**, and with n = 30 a high AUC can appear by chance.
  - It is therefore **recorded as a pre-registered prediction for N83+** (section G). It is **not used to select boards**.
  - Solver positions has a stronger standing. It was the *actual selection rule* of Phases 25–26, chosen for timing before any human result existed. The period that used it is the period with the higher human-hard rate.
- **Readability.** All boards are 7×7 with 11–18 pieces, and the hard and easy groups have the same piece counts (median 15). Difficulty does not come from clutter.

### What this means for selection

- Of the measures available **before** any human play, solver positions is the only one with a stable, pre-specified record. It is the rule Phases 25–26 actually used.
- Phase 31 therefore selects by **fewest positions** among fully qualified boards, one per concept.
- `early3` and tempting fatal openings are **recorded** for every new board as predictions, and **not** used to select.

## E. Decision

**Chosen strategy: the Phase 25–27 generator for breadth, the modern pipeline for every guarantee, positions-first selection.**

| Element | Choice | Evidence |
|---|---|---|
| Generator | `tools/ta90_search.gd` of `c1ddc89`, run unchanged in worktree `p31/wtA` | C: 6 / 6 concepts with pools, 3 / 6 with PASS boards, vs 0 / 6 for Phase 30 as run |
| Operators | `--ops=v20` (now actually on; checked in every job file) | B change 1; C2 vs B |
| Parameters | Phase 25–27 (13 / 17 / 0.30, patience 8) | C1 vs C2: no clear effect, so the historical values |
| Reliability | **every** fix applied after generation: engine-valid tokens, bank overlap, 40 ms gates, strict essentiality incl. spinners, filler, hint-follow, full evaluation | B change 8 |
| Selection | one board per concept, **fewest positions** among the boards that pass everything | D; C (S_old gives the small boards) |
| Budget | 20 experiment runs + **8** Phase 31 runs (the maximum); 24 full evaluations (the maximum). Not the 24 extra runs of earlier phases | protocol.json budget, AM1 |

**What is not changed:** the repository's `tools/ta90_search.gd` (the current generator), the production solver, every gate and threshold, every gameplay mechanic.

**Is the old method better?** On technical yield, **yes, measurably** (C). On human difficulty, **unknown**: N83–N87 are the test.

## F. Concept and search report

**Concepts:** the 13 Phase 30 cores that had not produced a board. No new mechanic, no new core.

| Concept | Phase 30 (B) | Phase 31 runs | Result |
|---|---|---|---|
| T01r the pulled trigger (magnet + switch) | 0 qualifying | A s302, C1, C2, G s308 | **N83** |
| T27r the trigger is the last link (switch + gate) | 0 | A s302, C1, C2, G s308 | **N84** |
| T57 one escape, two effects (switch + spinner) | 0 | A s305, C1, G s308 | **N85** |
| T10 / T10b the key ladder (switch + lock) | 74 / 0, no PASS | G s301 / s302 | **N86** (T10b) |
| T30 two keys, one reversal (switch + lock) | 0 | G s302 | **N87** |
| T03 / T03r pull the key (magnet + lock) | 0 / 0 | A s302, C1, G s301 | none: every shortlisted board "not essential" or overlap |
| T05 / T05r the armored link (switch + gate + armor) | 0 / 0 | A s302, C1, G s301 | none: tokens invalid or Category A/B |
| T48 the boomerang door | 0 | A s303, C1 | none: "not essential" |
| T59 / T61 | N81 / N82 | A, C1, C2 (calibration) | not used (overlap with N81 / N82) |

**Amendment AM1** (recorded before the 8 runs): the protocol allowed extra runs only for cores with PASS boards (a second RNG seed: T01r, T27r, T57). With three concepts the phase could produce at most three boards, so AM1 used the other 5 of the 8 runs on the five Phase 30 concepts the experiment had not covered, each with its Phase 30 RNG seed (so they also extend the A-vs-B pairing: the old method found PASS boards on T10, T10b and T30, where Phase 30 found none).

**Deeper search:** the second seed (s308) found PASS boards on T01r (5) and T57 (7), none on T27r (s308's pool was small boards that failed strict essentiality).

**Funnel:** 28 runs → 53 screen-PASS boards on 5 new concepts → 24 full evaluations (the maximum; picks from both rules in every concept) → 23 met every gate (1 failed shortcut 0.208 > 0.20) → **5 selected**, one per concept.

## G. Five new technical candidates: N83–N87

**TECHNICALLY QUALIFIED — HUMAN UNTESTED.** Records `data/dev/ta90_n83.json` … `ta90_n87.json`; fingerprints in `data/dev/extreme90_p31/fingerprints.json`; selection in `selection.json`.

| ID | Source | Concept | Mechanics |
|---|---|---|---|
| **N83** | A_T01r_s302_2 | **the pulled trigger**: a fixed magnet pulls the switch piece into its own cell, so *when* the magnet leaves decides where the reversal fires and which lane opens | magnet, switch, spinner |
| **N84** | A_T27r_s302_0 | **the trigger is the last link**: the switch piece is also the gate's link, so one move reverses the targets and opens the gate | switch, gate, spinner |
| **N85** | G_T57_s308_0 | **one escape, two effects**: the switch piece stands beside a spinner, so one escape turns the spinner and reverses the targets | switch, spinner |
| **N86** | G_T10b_s302_0 | **the blocked key ladder**: the last prisoner blocks the key's exit, so the key must be reversed to leave - and that reversal turns the locked middle key away | switch, lock, spinner |
| **N87** | G_T30_s302_0 | **two keys, one reversal**: both keys are flip targets of one switch; one press turns both | switch, lock, spinner |

**Full metrics (desktop, unchanged tools):**

| ID | Positions | Solution | Distinct mistakes | Steps | Coverage | Late | Shortcut | Solve ms | TIME UP ms | Bank overlap |
|---|---|---|---|---|---|---|---|---|---|---|
| N83 | 87 | 15 | 5 | 13 | 0.87 | 0.87 | 0.008 | 5.7 | 4.2 | 0.38 N81 |
| N84 | 163 | 14 | 4 | 12 | 0.86 | 0.86 | 0.010 | 5.2 | 3.0 | 0.35 N17 |
| N85 | 208 | 16 | 5 | 14 | 0.88 | 0.88 | 0.110 | 4.6 | 4.7 | 0.35 N21 |
| N86 | 143 | 16 | 6 | 14 | 0.88 | 0.88 | 0.158 | 4.5 | 4.1 | 0.36 N61 |
| N87 | 94 | 14 | 4 | 11 | 0.79 | 0.86 | 0.117 | 3.2 | 1.5 | 0.32 N46 |

- **Gates:** all five clear every Phase 30 gate unchanged: distinct ≥ 4, steps ≥ 8, coverage ≥ 0.60, late ≥ 0.75, solution ≥ 13, shortcut ≤ 0.20, solve and TIME UP ≤ 40 ms, 0 filler, bank overlap < 0.40, engine-valid tokens, hint-follow.
- **Strict essentiality** (`B.without_*`, the exact Solver):
  - switch: unsolvable without it on all five;
  - magnet (N83): unsolvable without it;
  - gate (N84): without it 7 decision steps / 3 mistakes instead of 12 / 4;
  - lock: N86 4 / 2 instead of 14 / 6; N87 0 / 0 instead of 11 / 4;
  - spinners: unsolvable without them on N84, N86, N87; on N83 3 / 2 instead of 13 / 5; on N85 4 / 1 instead of 14 / 5.
- **Diversity:** five different cores and four different mechanic sets; pairwise overlap ≤ **0.30**; bank overlap ≤ **0.38**.

**Pre-registered predictions** (recorded now, before any human play; **not used to select**; the owner is the judge):

| ID | Positions (fewer = harder?) | early3 (lower = harder?) | Tempting fatal openings (fewer = harder?) |
|---|---|---|---|
| N83 | 87 | 5 | 2 |
| N84 | 163 | 6 | 2 |
| N85 | 208 | 6 | 2 |
| N86 | 143 | 7 | 3 |
| N87 | 94 | 4 | 2 |
| *reference medians: VH/EX* | *367* | *4* | *1* |
| *reference medians: EASY/MEDIUM* | *546* | *7* | *3* |

**Expected risks, stated per board (not predictions):**
- **N83:** closest of the set to the bank (0.38, N81, which the owner rated MEDIUM). Only 87 positions: it may be quick once the magnet timing is seen.
- **N84:** a gate whose link is the trigger; the core may read as "do the switch last", a simple rule.
- **N85:** the spinner is next to the switch, so the double effect is visible; the risk is a forced middle (5 forced steps only, many optional ones).
- **N86:** the highest early3 (7) and 3 tempting fatal openings: the structural measures predict it the *least* hard of the five.
- **N87:** two locks with one switch; the lowest early3 (4) and few positions, but a short solution (14).
- **All five:** small boards (87–208 positions). If the owner finds them *too small to be hard*, that would refute the positions hypothesis. That is a useful result.

## H. Complete regression report

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real iPhone was used.** No generator or other CPU-heavy job ran during this QA (chain 20:27 on 1 Nov → 07:09 on 2 Nov, including one resume).

**Phase 31 development page and builds**

| Test | Result |
|---|---|
| Dev export / player export | OK (0 `data/dev` files in the player build) |
| `web_p31` (`?extreme90p31=1`): the 5 new boards solved by touches in timed 90 s runs, SKIP, questionnaire, TIME UP and continuation, export `ce-xb31`, PREVIOUS CHALLENGES (68 boards), WebAssembly TIME UP for every board | **PASSED 164/164** (attempt 2; see below) |
| Extreme90p31Check | PASSED (326 checks); re-run after the owner-decision edit of the records: **PASSED (326)** |
| Ta90DeadendCheck N83–N87 | PASSED (35 checks) |
| Hint-follow N83–N87 | 5/5 PASS |
| xb28_validate (EXTREME records valid, fingerprints unchanged; 300 Classic levels valid) | PASSED; re-run after the owner-decision edit: **PASSED** |
| Ta90ContinueCheck | PASSED (812 checks, 291 cases, 0 not resumed exactly) |
| PortalCheck, MovableCheck, MagnetCheck | PASSED |

**`web_p31` attempt 1:**
- **What happened:** it ended with exit 124, killed by the shell wrapper's 3,400-second limit. That limit had been sized for the Phase 30 page (63 boards). The Phase 31 page has 73 boards, and every board is played in real time.
- **Where it stopped:** 145 checks had passed. It was on CHALLENGE 71 (N32), whose last line is `timeout card N32 null`.
- **Attempt 2:** the same build, not re-exported, with a 7,000-second wrapper. It passed **164/164**, N32 included.
- **Log:** attempt 1 is kept as evidence (`qa/web_p31_attempt1_wrapper_timeout.log`).

**WebAssembly TIME UP** (headless Chromium, `web_p31` BENCH; the page's limit is 250 ms):
- N83 10.6 ms;
- N84 5.5 ms;
- N85 3.5 ms;
- N86 3.2 ms;
- N87 1.5 ms.

The heaviest board on the page is the older N57, at 41.8 ms.

**Earlier pages (regression), on the Phase 31 build**

| Page check (headless Godot) | Result | Browser test | Result |
|---|---|---|---|
| Extreme90p30Check | 306 | `web_p30` | 154/154 |
| Extreme90p29Check | 288 | `web_p29` | 144/144 |
| Extreme90p28Check | 260 | `web_p28` | 130/130 |
| Extreme90p27Check | 226 | `web_p27` | 114/114 |
| Extreme90p26Check | 222 | `web_p26` | 112/112 |
| Extreme90p25Check | 212 | `web_p25` | 106/106 |
| Extreme90p24Check | 186 | `web_p24` | 94/94 |
| Extreme90p22Check | 184 | `web_p22` | 92/92 |
| Extreme90p21Check | 168 | `web_p21` | 84/84 |
| Extreme90p20Check | 132 | `web_p20` | 66/66 |
| Extreme90p19Check | 124 | `web_p19` + P19 save upgrade | 62/62 + 9/9 |
| Extreme90p18Check | 111 | `web_p18` | 55/55 |
| — | | `?extreme90p17=1`, `?extreme90=1` archive | 51/51, 45/45 |

**Other suites**
- Browser: `?ta90=1` 55/55; `?tapilot` 28/28; web timing (timing and Personal Best) PASSED; friend build 25/25; `stime` 31/31; `ttime` (tta) 32/32.
- Headless suites: 18 of 19 pass.
- **RecipientTest fails only its 3 known layout checks** ("TOTAL SCORE left, coins right" for en_US, he_IL and ar_SA). They are unchanged since Phase 26, so this is not a regression.
- **verify_levels: all 300 Classic levels are solvable and pass the campaign rules.**

**Evidence:** `data/dev/extreme90_p31/qa/`: summary, suites summary, hint-follow log, `web_p31` log and BENCH, and the attempt 1 log.

## I. Downloadable QA ZIP

**`build/dev_qa/chain_escape_dev_extreme90p31_p31-qa1-20261101.zip`**
- **Size:** 15,899,976 bytes.
- **SHA-256:** `dbe77220b5b7877c7e441d8e4d02f831b2a8a025681ece51c92b00a935009e53`.
- **Build:** DEV BUILD `p31-qa1-20261101` (BUILD_ID.txt included).
- **Same as the tested build:** its `index.pck` (SHA-256 `61351bc153fa52bb1db8aa87c3357c2e19330851d3271f3bc556b37d2e5ff5ee`) is byte-identical to the build that passed `web_p31`.
- **Delivery:** attached in the Phase 31 conversation, and already played by the owner (section K).
- `build/` is not in Git.
- **The ZIP was deliberately not rebuilt after the owner decision.** The dev pck includes `data/*.json`, so the tested ZIP's five records still say "TECHNICALLY QUALIFIED - HUMAN UNTESTED". Maps, ids, fingerprints and gameplay are identical, and it is the build the owner tested.

**Playtest:**
- **Where:** `index.html?extreme90p31=1` on a private draft or a local server, not Production.
- **Main screen:** CHALLENGE 1–5 = N83–N87.
- **Rules:** 90 s, unlimited RESTART, UNDO ×3, HAMMER 0, SHOW A MOVE 0, first-exposure tracking, difficulty and enjoyment questions, COPY ALL RESULTS JSON.
- **PREVIOUS CHALLENGES:** the 68 earlier boards.
- **Testing:** headless browser only; not tested on a real iPhone.

## J. Final local Phase 31 commit

- **Contents:** this commit holds only Phase 31:
  - the Phase 31 tools (`extreme90_ana31.py`, `extreme90_exp31.py`, `extreme90_sel31.py`, `extreme90_features31.py`, `ta90_struct31.gd`);
  - `data/dev/extreme90_p31/` (protocol with amendment AM1, the experiment, the 24 full evaluations, the selection, fingerprints, the human results and owner decisions, the QA evidence);
  - the records for N83–N87 with the owner decision;
  - the Phase 29 provenance erratum (N71, N72, N76, N77 and `extreme90_p29/selection.json`);
  - `?extreme90p31=1` (`scripts/social/extreme90_p31.gd`, hooks in `game_manager.gd` and `ta90_time_attack.gd`);
  - its check (`extreme90p31_check.gd`, `Extreme90p31Check.tscn`);
  - the check and web test entries;
  - this report.
- **Budget used:** 20 experiment runs plus 8 amendment runs (AM1), and 24 full evaluations, all exit 0. No new generation round was started after the evaluations.
- **Unchanged:** the repository's generator, the production solver, every gameplay mechanic, the 300 Classic levels, the 120-second baseline, Production and Supabase.
- **Base:** it sits on Phase 30 (`5ab64b4`). It is a **local** commit; it is **not pushed**.
- **Phase 32:** not begun. Its baseline is fixed in section K.

## K. Owner decision on N83–N87 (after the owner played the QA build)

Recorded verbatim from the owner's Phase 31 decision message; nothing is inferred. Files:
- `data/dev/extreme90_p31/human_p31.json`: the player ratings;
- `data/dev/extreme90_p31/owner_decisions_n83_n87.json`: the owner decisions, stored separately from the ratings, from technical qualification and from release readiness;
- the five records (`data/dev/ta90_n83.json` … `ta90_n87.json`): label, `owner_decision` and `human_p31` fields;
- `selection.json`: an `owner_decision` entry per board.

The maps and fingerprints are unchanged (checked against `fingerprints.json`).

| ID | Owner rating | Enjoyment | Owner decision | Fingerprint |
|---|---|---|---|---|
| N83 | EXTREME | 5/5 | **APPROVED** | `78a09b2fee3efd8489fa4c4c8b0f4f363c56a0a71ed645efbfd9e57313fec9ff` |
| N86 | EXTREME | 5/5 | **APPROVED** | `8d1800aa83cbcc6919b2116b176d268b7d144ffb66245a2053f7fff19d349b93` |
| N87 | VERY HARD | 5/5 | **APPROVED** | `a9a6a5925dda083cbdc013ecbd434333e5600b6d1d30ef2720891e08a27633e5` |
| N84 | MEDIUM | not supplied | not approved | `eab0d042cdae8a03b0d03142b4a3dedf5e0d1f8775f90915dab148da1f89b1fd` |
| N85 | HARD | not supplied | not approved | `7402bad1588b4f4ca5fefbab33155e2619e8522d14678b30f69face7ceda818b` |

- The 90-second outcome, Restart and UNDO counts, attempts and move sequences were **not supplied** for any board.
- N87 was rated VERY HARD and is explicitly approved for the EXTREME bank by the owner, as N75 was in Phase 30.

**Bank: 35 → 38 / 50. 12 approved puzzles remain.**
- N82 (Phase 30) stays **not approved**, pending an explicit owner decision.
- N80 stays borderline. N78, N79, N81, N84 and N85 stay outside the bank.

**Release readiness (N83, N86, N87):**
- technically qualified;
- WebAssembly TIME UP within the page limit in headless Chromium (`web_p31` BENCH: 10.6, 3.2 and 1.5 ms);
- **not tested on a real iPhone.**

**Pre-registered predictions against the owner's ratings.** Section G recorded these before any play.

The comparison is between the three boards rated VERY HARD or EXTREME (N83, N86, N87) and the two that were not (N84, N85). The pairwise score is the share of VH/EX-versus-other pairs that the measure orders as predicted; 0.5 is chance.

| Measure (prediction) | VH / EX | Others | Pairwise ordered as predicted |
|---|---|---|---|
| Positions (fewer = harder) | 87, 143, 94 | 163, 208 | **6 / 6 (1.00)** |
| early3 (lower = harder) | 5, 7, 4 | 6, 6 | 4 / 6 (0.67) |
| Tempting fatal openings (fewer = harder) | 2, 3, 2 | 2, 2 | 2 / 6 (0.33, ties count ½) |

- **Positions held:** the three smallest boards are exactly the three rated VERY HARD or EXTREME.
- **The per-board risk note for N86 was wrong:** it predicted N86 as the *least* hard of the five, and the owner rated it EXTREME.
- **Approval rate:** 3 of 5 approved in Phase 31, against 0 of 5 in Phase 30 (N82 recommended but not approved).
- **Caveat:** this is 5 boards and one experienced player. It is consistent with the section E decision, but it is not a significance test or a causal proof.

**Phase 32 baseline (owner instruction):**
- **Generation:** keep the Phase 31 approach as the baseline. That is the Phase 25–27 generator run in its own worktree (the repository's generator is unchanged), with fewest positions selected per concept.
- **Checks:** apply every modern technical safety check after generation:
  - engine-valid token guard;
  - strict essentiality of every declared mechanic;
  - the modern screen and full evaluation, gates unchanged;
  - hint-follow and dead-end checks;
  - bank and pairwise overlap.
- **Not begun:** Phase 32 has not started.

**The tested QA build is not changed.** The page code (`scripts/social/extreme90_p31.gd`), which groups N83–N87 as "phase31", is unchanged, so the build that passed `web_p31` and was attached as the ZIP stays the build the owner played. The owner decision lives in the data files and in this report. The first page built after this decision should carry the new groups, as `extreme90_p30.gd` did for N72, N75 and N77.
