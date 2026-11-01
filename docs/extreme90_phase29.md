# EXTREME Time Attack — Phase 29: human-calibrated EXTREME design

Development only. The following are untouched:
- Production and Supabase;
- the 300 frozen Classic levels (verify_levels: all 300 solvable and passing the campaign rules);
- saves, timing and Personal Best;
- the 120-second Time Attack baseline;
- the Social MVP and Challenge a Friend;
- every gameplay mechanic.

There is no new mechanic or UI. The game-script changes are only:
- the new developer page (`scripts/social/extreme90_p29.gd`);
- its `game_manager` hook;
- seven `BOARDS90` entries.

**Outcome: 7 technically qualified, conceptually distinct candidates, N71–N77**, labelled TECHNICALLY QUALIFIED — HUMAN UNTESTED.
- Every technical gate is unchanged.
- The new human-difficulty ranking is advisory only. It rejected nothing.
- Only the owner may approve.

## A. Owner decisions and the approved count: 32 / 50

The owner's decisions are recorded in `data/dev/extreme90_p29/owner_approvals_p29.json`. The players' ratings are kept separately, in `data/dev/extreme90_p28/human_p28.json`. Fingerprints are preserved in both.

| Board | Player rating (first exposure) | Owner decision |
|---|---|---|
| N64 | EXTREME, TIME UP, enjoyment 5/5 | **APPROVED** |
| N68 | EXTREME, TIME UP, enjoyment 5/5 | **APPROVED** (release-readiness watch, C) |
| N69 | EXTREME, TIME UP, enjoyment 5/5 | **APPROVED** |
| N63 | MEDIUM | downgraded |
| N65 | EASY (19.5 s) | downgraded |
| N67 | MEDIUM | downgraded |
| N70 | EASY (37.5 s) | downgraded |
| N66 | HARD (84.4 s, 6 attempts) | borderline — NOT owner-approved |

- **Count:** 29 + N64, N68, N69 = **32 approved; 18 remaining** to the target of 50.
- **Manifest:** `data/dev/extreme90_bank_status.json` holds:
  - 32 owner-approved;
  - 3 strong provisional;
  - 9 provisional;
  - 1 borderline (N66);
  - 25 downgraded or archived;
  - 0 untested before this phase.
- **Consistency:** all 70 boards are classified exactly once.
- **Records:** nothing is deleted.

### Closure: owner decisions on N71–N77 (recorded at the Phase 29 commit)

The owner's decisions arrived with the Phase 30 brief. They are recorded in `data/dev/extreme90_p29/owner_decisions_n71_n77.json`. The player ratings are kept separately in `human_p29.json`, verbatim, and fingerprints are preserved in both.

| Board | Player rating (first exposure) | Owner decision |
|---|---|---|
| N72 | EXTREME, TIME UP, enjoyment 5/5 | **APPROVED** |
| N75 | VERY HARD, TIME UP, enjoyment 5/5 | **APPROVED** |
| N77 | EXTREME, TIME UP, enjoyment 5/5 | **APPROVED** |
| N71 | EASY | downgraded |
| N73 | HARD | downgraded |
| N74 | MEDIUM | downgraded |
| N76 | HARD | downgraded |

- **Count:** 32 + N72, N75, N77 = **35 approved; 15 remaining**.
- **Manifest:** `extreme90_bank_status.json` holds 35 approved, 3 strong provisional, 9 provisional, 1 borderline and 29 downgraded or archived. All 77 boards are classified exactly once.
- **Not supplied:** the outcome and enjoyment of the downgraded boards, and every restart, UNDO and move count. Nothing is inferred for them.
- **How the advisory flags (E) fared:** the out-of-sample check of the flags is reported in Phase 30 (C). In short, they did not predict these 7 outcomes (3 of 7 correct).

## B. Phase 28 closure (Git and QA)

- **Commit and push:** Phase 28 was committed alone as `3cea3bd`, on Phase 27 (`c1ddc89`).
  - Push check: `origin` was an ancestor of HEAD, so a normal push was used, never a force-push.
  - After the push, the remote equals `3cea3bd`.
  - Phase 29 files were excluded from that commit.
- **Load incident:**
  - `web_p21` failed once (a timeout in the timed N39 run) while four Phase 29 generators saturated 4 cores (load about 8).
  - It was rerun in isolation at load 1.17 and **passed 84/84**, so the timeout does not reproduce.
  - From then on no generator ran during browser or timed QA. Phase 28 report J has the full regression.
- **Process incident (this phase):**
  - A wait loop using `pgrep -f extreme90_eval25.py` matched its own command line and never returned.
  - It ran nothing, so no budget was used and no result was affected.
  - It was replaced by scripts that wait on a file marker.
- **Tool race (this phase):**
  - `tools/extreme90_eval25.py` writes `<out>/bench.log`. Two evaluations sharing one out dir read each other's bench output.
  - Because of this, R05_1 was reported "unsolvable". Bench run alone, it has 471 positions and is winnable.
  - Every later evaluation used its own out dir (`ev1/<name>/`).
  - Only "missing" results could be produced by the race; no board received another's metrics.

## C. N68 performance watch (approval and release readiness kept apart)

- **Method:** `tools/web_extreme90_timing28.mjs`, on the dev build in headless Chromium (iPhone SE viewport).
  - It times the page's own `&bench=1` check: a fresh Solver with the full limit, each measurement the median of 3 solves.
  - Each measurement used a fresh browser context; there were 2 sets of 5 rounds.
  - Each set started at load below 1.5, with nothing else running.
- **Evidence:** `data/dev/extreme90_p28/qa/n68_timing_{a,b}.json`.

| Board | All 10 runs (ms) | Median |
|---|---|---|
| **N68** | 22.8, 22.9, 23.8, 23.9, 24.8, 25.1, 25.8, 27.7, 31.0, 31.5 | **24.95** |
| N63 (reference) | 13.0 – 26.7 | 14.75 |
| N64 (reference) | 12.0 – 20.3 | 14.8 |
| N57 (reference, approved-era heaviest) | 48.8 – 82.2 | 52.0 |

- **Comparison:** the loaded Phase 28 run measured N68 at 39.1 ms, which was inflated by load. Under low load N68's maximum is 31.5 ms, against the page's 250 ms WebAssembly limit. N68 is not the heaviest board.
- **Approval:** APPROVED, unchanged. It is the owner's decision, and it was not downgraded.
- **Release readiness:** green on headless Chromium. **No real iPhone was used.** Real-device timing remains open.

## D. Human-difficulty analysis (Phase 24–28 first exposures)

**Calibration set (19 boards):**
- approved: N52, N53, N55, N56, N59, N61, N62, N64, N68, N69;
- downgraded: N54, N57, N58, N60, N63, N65, N67, N70;
- borderline: N66.

All diagnostics were measured on the boards themselves (`calib_humanlike.json`, `calib_humanfit.json`, `calibration_table.json`).

**What was not available:** restart counts, UNDO counts and move sequences were not supplied, because there were no per-move exports. Nothing below infers them.

Spearman rank correlation with the human outcome (`calibration_spearman.json`; n = 19, in-sample):

| Feature | rho | Reading |
|---|---|---|
| p_calm (a calm player who avoids immediate losses wins in one try) | **−0.53** | the strongest: boards a cautious beginner can win read as easy |
| look6 (6-move lookahead greedy) | −0.45 | short planning suffices → easier |
| gmax (best one-attempt greedy policy) | −0.38 | a simple heuristic wins → easier |
| safe-opening share | +0.36 | many safe openings did **not** make boards easier |
| effective decisions | +0.32 | more real choices → harder |
| distinct mistakes | 0.00 | **the main technical gate does not separate them** — every board already clears it |

**Board-level explanations**
- **N65 and N70 (EASY):** a simple strategy wins (p_calm 2.1% and 4.0%; gmax about 10%).
- **N63 (MEDIUM):** one insight, then a forced chain (72% of the solution is forced moves).
- **N67 (MEDIUM):** p_calm 1.8%, gmax 10.5%.
- **N66 (HARD despite 84 s and 6 attempts):** gmax 13% suggests trial and error, not deep reasoning.
- **N57 and N58:** shallow dependency (depth 3 and 2).
- **N64, N68 and N69 (EXTREME):** every simple player sits near 0 (p_calm ≤ 0.008).
- **Crate boards:** they can be EXTREME despite modest dependency depth; N68 has depth 5.

**Advisory flags.** These were fitted after the fact, so the fit is in-sample and not validated.

| Flag | Rule |
|---|---|
| simple_strategy | p_calm ≥ 0.01, or gmax ≥ 0.09, or look6 ≥ 0.08 |
| linear | forced share > 0.60 |
| shallow | dependency depth ≤ 3 |

| Board | Group | p_calm | gmax | look6 | forced | depth | flags |
|---|---|---|---|---|---|---|---|
| N52 | approved | 0.001 | 0.070 | 0.017 | 0.53 | 9 | — |
| N53 | approved | 0.000 | 0.080 | 0.000 | 0.47 | 8 | — |
| N55 | approved | 0.001 | 0.010 | 0.008 | 0.41 | 11 | — |
| N56 | approved | 0.000 | 0.000 | 0.000 | 0.44 | 12 | — |
| N59 | approved | 0.009 | 0.045 | 0.025 | 0.33 | 12 | — |
| N61 | approved | 0.005 | 0.008 | 0.042 | 0.12 | 8 | — |
| N62 | approved | 0.001 | 0.025 | 0.067 | 0.56 | 10 | — |
| N64 | approved | 0.001 | 0.000 | 0.033 | 0.24 | 11 | — |
| N68 | approved | 0.000 | 0.000 | 0.000 | 0.40 | 5 | — |
| N69 | approved | 0.008 | 0.080 | 0.017 | 0.57 | 8 | — |
| N54 | downgraded | 0.012 | 0.050 | 0.175 | 0.41 | 7 | simple |
| N57 | downgraded | 0.000 | 0.000 | 0.000 | 0.21 | 3 | shallow |
| N58 | downgraded | 0.007 | 0.145 | 0.050 | 0.40 | 2 | simple, shallow |
| N60 | downgraded | 0.002 | 0.165 | 0.100 | 0.58 | 11 | simple |
| N63 | downgraded | 0.001 | 0.008 | 0.008 | 0.72 | 12 | linear |
| N65 | downgraded | 0.021 | 0.095 | 0.083 | 0.56 | 11 | simple |
| N67 | downgraded | 0.018 | 0.105 | 0.042 | 0.41 | 7 | simple |
| N70 | downgraded | 0.040 | 0.105 | 0.050 | 0.27 | 8 | simple |
| N66 | borderline | 0.011 | 0.130 | 0.050 | 0.50 | 9 | simple |

- **Fit:** the flags mark 9 of 9 non-approved boards and 0 of 10 approved boards.
- **Caution:** the thresholds were chosen *on these 19 boards*, so they will over-fit. That is why they are advisory (E) until tested on independent first exposures, such as N71–N77.

## E. The advisory ranking layer (`tools/ta90_rank29.gd`)

- **Placement:** it runs after the early screen and before full evaluation, on every screened PASS board.
- **Metrics:** the Phase 26 diagnostics, plus gmax (5 policies × 120 games), look6 and forced share.
- **Output:** the three flags and a `rank_key` (fewer flags first, then the simple players, then depth).
- **What it changes:** only the order of full evaluations, and which board represents a concept.
- **What it never changes:** it rejects nothing, it changes no gate, and it does not replace the owner. Flagged boards stay eligible.
- **Validation plan:** N71–N77 include 3 unflagged and 4 flagged boards. Their first-exposure ratings will test whether the flags predict human difficulty out of sample.

## F. Concept funnel and generation

**Concept funnel** (`concept_funnel.json`): 37 proposals.

| Proposal group | Count | Outcome |
|---|---|---|
| X01–X24 | 24 | rejected before generating: 19 are existing bank concepts or their families (X01–X15, X21–X24), 3 are engine-impossible (X17–X19), 1 is a monotone set (X16), 1 is structurally weak (X20) |
| R10 | 1 | rejected: the hand core was unsolvable as drawn; no guessing at spinner rules |
| R01–R08 | 8 | advanced in round 91 |
| R09, R01b, R02b, R08b | 4 | added in round 92 |

**Pipeline:**
- unchanged Phase 28 pipeline: token guard, strict essentiality including spinners, spinners_max, and the early screen;
- then the advisory rank (E);
- then full evaluation.

The protocol was fixed before generating; its amendments are logged in `protocol.json`.

| Round | Run (seed) | Qualifying | Invalid tokens | Note |
|---|---|---|---|---|
| 91 | R01 GATEDMAGNET | 0 | 0 | stalled at 2 distinct mistakes |
| 91 | R02 LOCKEDCARGO | 0 | 0 | stalled at 2 |
| 91 | R03 WALLEDSWITCH | 163 | 0 | |
| 91 | R04 ARMOREDKEY | 15 | 0 | |
| 91 | R05 TWOCRATES | 116 | 0 | |
| 91 | R06 LINKKEYCRATE | 85 | 0 | |
| 91 | R07 LOCKEDLINK | — | — | the seed's own core token was mis-ordered (`B^&A+C#Y`); refused at start |
| 91 | R08 TWOTURNED | 0 | 0 | stalled at 3, shortcut 18–20% |
| 92 | R07 (token fixed: `B^#Y&A+C`) | 0 | 0 | best 4 mistakes, coverage 0.63, no endgame decision |
| 92 | R09 LOCKEDPUSHER (new) | 162 | 0 | |
| 92 | R01b (no added armor, suffix rate 0.4) | 192 | 0 | |
| 92 | R02b (no added armor, suffix rate 0.4) | 491 | 0 | |
| 92 | R08b (no added armor, suffix rate 0.4) | 230 | 0 | |
| 92 | R03, second seed | 146 | 0 | all flagged; round-91 pick kept |
| 92 | R04, second seed | 0 | 0 | |
| 92 | R06, second seed | 5 | 0 | all flagged; round-91 pick kept |

- **The magnet revision:** removing the added armor fixed the stalled magnet concepts. Armor is monotone and cannot create a loss, so its suffixes were wasted mutations. The frozen cores keep their own armored piece.

**Early screen:** 73 shortlisted boards, 51 PASS. The 22 rejections:
- 14 filler;
- 4 bank overlap ≥ 0.40 (R04 vs N66);
- 2 greedy shortcut 23% (R01b_2, R01b_4);
- 2 TIME UP above 40 ms (R05_3 at 52.5 ms, R06_0 at 43.9 ms), both measured during 4 parallel screens.
  - Neither was re-measured alone, because their concepts already had qualifying boards (R05_4, R06_5).
  - Both stay rejected, and the gate is not relaxed.
- The 1000-position shortlist cap was used for round 92 (the default is 700). Positions are not a gate; the 40 ms solve and TIME UP gates still apply.

**Full evaluations:** 14, two at a time, with no generator running.
- All 14 met Category A and B. The early screen made these evaluations nearly certain.
- **R05_4:** it measured a 49 ms solve while two evaluations ran in parallel. Alone, in its own directory, it measured **28 ms**. Both measurements are recorded, and the single, unloaded one decides.

## G. Qualified candidates N71–N77

Order: the advisory-unflagged boards first, then the flagged ones. CHALLENGE 1–7 = N71–N77.

**Withdrawn before QA: the R05 concept (two crates in one column).**
- **What happened:** the board first numbered N73 (R05_4) passed every gate, but `web_p29` could not solve it by touches in a timed 90 s run.
- **Cause:** the page's touch solver follows the engine's own hint (`Solver.recommend_move`). On crate boards that hint takes the first move of whatever solution `solve_moves()` returns. That solution is not always the shortest, and on every R05 board the hint shuttles the two pushers back and forth for ever. On desktop the hinted moves were ids 3, 4, 3, 4, … on all 7 screened R05 boards.
- **The board itself is fine:** it is solvable, and its solution replays to an empty board.
- **Decision:** the Solver is a game feature and is not changed, and the test is not special-cased. The concept is withdrawn (`data/dev/extreme90_p29/withdrawn_r05.json`). The ids were renumbered N71–N77 before any commit or exposure.
- **New QA step:** `tools/ta90_hintfollow29.gd` follows the hint from the start position. All 7 candidates and all 8 Phase 28 boards reach an empty board.

| ID | Source | Concept | Mechanics | Advisory flags |
|---|---|---|---|---|
| **N71** | R09_4 | **the locked pusher**: the only block that can push the crate is locked and is the flip target. Its key must cross the crate's landing lane before the push, and the switch decides which way the freed pusher faces. | crate, switch, lock, spinner | — |
| **N72** | R02b_4 | **the turned magnet with locked cargo**: the reversal picks the pull side, and the cargo on one side is locked, so pull, key and reversal must be ordered | magnet, switch, lock, armor, spinner | — |
| **N73** | R06_5 | **the key-link and the crate**: the key opens both the lock and the gate, but its lane is the crate's | crate, switch, gate, lock, spinner | — |
| **N74** | R03_0 | **the crate walls in the switch**: the switch fires only once the crate is out of its row, and the pusher needs that very reversal | crate, switch, spinner | simple_strategy |
| **N75** | R04_0 | **the armored key**: the cracked key can leave only the way the reversal leaves it facing | switch, lock, armor, spinner | simple_strategy |
| **N76** | R08bs92_3 | **two turned magnets**: two magnets on one switch; one must pull before the reversal, the other after | magnet, switch, armor, spinner | simple_strategy |
| **N77** | R01b_7 | **the turned magnet behind a gate**: the reversal picks the side, and a gate decides whether that side can be pulled | magnet, switch, gate, armor, spinner | simple_strategy |

- **Records:** `data/dev/ta90_n71.json` … `ta90_n78.json`. Each carries its design report, filler result, overlap and advisory rank.
- **Fingerprints:** listed in `data/dev/extreme90_p29/fingerprints.json`.

## H. Individual metrics (full evaluation; desktop)

| ID | Positions | Solution | Distinct mistakes | Decision steps | Coverage | Late | Shortcut | Solve ms | TIME UP ms | Bank overlap |
|---|---|---|---|---|---|---|---|---|---|---|
| N71 | 882 | 17 | 6 | 14 | 0.82 | 0.82 | 0.000 | 7.0 | 30.5 | 0.31 N15 |
| N72 | 290 | 18 | 6 | 15 | 0.83 | 0.83 | 0.000 | 10.1 | 8.0 | 0.30 N64 |
| N73 | 458 | 15 | 6 | 14 | 0.93 | 0.93 | 0.035 | 33.2 | 25.8 | 0.37 N68 |
| N74 | 695 | 14 | 6 | 12 | 0.86 | 0.93 | 0.01 | 7.3 | 21.3 | 0.30 N60 |
| N75 | 517 | 18 | 4 | 14 | 0.78 | 0.83 | 0.06 | 3.3 | 4.3 | 0.38 N66 |
| N76 | 916 | 19 | 5 | 17 | 0.89 | 0.89 | 0.045 | 4.3 | 15.5 | 0.35 N39 |
| N77 | 493 | 17 | 5 | 13 | 0.76 | 0.82 | 0.083 | 7.3 | 8.1 | 0.39 N46 |

- **Gates:** every board clears every gate: distinct ≥ 4, steps ≥ 8, coverage ≥ 0.60, late ≥ 0.75, solution ≥ 13, shortcut ≤ 0.20, solve and TIME UP ≤ 40 ms, 0 filler, overlap < 0.40.
- **WebAssembly timing:** the per-board timing is in J (`web_p29` BENCH).

**Advisory diagnostics** (rank29):

| ID | p_calm | gmax | look6 | forced | depth |
|---|---|---|---|---|---|
| N71 | 0.000 | 0.000 | 0.000 | 0.18 | 11 |
| N72 | 0.000 | 0.000 | 0.000 | 0.44 | 12 |
| N73 | 0.006 | 0.042 | 0.025 | 0.53 | 9 |
| N74 | 0.019 | 0.008 | 0.075 | 0.21 | 6 |
| N75 | 0.018 | 0.067 | 0.342 | 0.39 | 8 |
| N76 | 0.009 | 0.058 | 0.083 | 0.26 | 9 |
| N77 | 0.038 | 0.083 | 0.108 | 0.35 | 7 |

- **Highest risk:** N75's look6 of 0.34 is the highest advisory risk in this set.

## I. Essentiality, shortcuts and diversity

- **Strict essentiality** holds for every mechanic on every board: the board is unsolvable without the mechanic, or has ≥ 2 distinct mistakes or ≥ 3 decision steps fewer.
  - **Spinners:** unsolvable without them on all 7, except N73 (14 → 9 steps) and N76 (5 → 1 distinct mistakes); both still clear the rule.
- **Shortcuts:** the greedy shortcut is ≤ 0.083 on every board, against the 0.20 gate.
- **Pairwise overlap among N71–N77:** at most **0.38** (N72 vs N77, the lock and gate variants of the turned magnet). Every other pair is below 0.30.
- **Within-concept duplicates:** high overlaps such as R03_0/R03_7 at 0.69 stayed out; one board per concept.
- **Closest bank relations:**
  - N71 → N68 / N66;
  - N72 and N77 → N64;
  - N74 → N68 / N69 (the crate + switch family);
  - N73 → N66 / N68;
  - N75 → N61 / N62 / N66;
  - N76 → N64.
- **Family risk** (stated plainly): there are three turned-magnet boards (N72, N76, N77), all extensions of the approved N64, and three crate boards (N71, N73, N74). Their dependencies differ, but players may perceive families. The owner may prefer to keep fewer from each.

## J. Exact regression results

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real iPhone was used.** No generator ran during this QA.

**Phase 29 development page and builds** (QA chain 20:13 → 03:37; no generator ran during it)

| Test | Result |
|---|---|
| Dev export / player export | OK (0 `data/dev` files in the player build) |
| `web_p29` (`?extreme90p29=1`): the 7 new boards solved by touches in timed 90 s runs, SKIP, questionnaire, TIME UP and continuation, export `ce-xb29`, WebAssembly TIME UP for every board | **PASSED 144/144** |
| Extreme90p29Check | PASSED (288 checks) |
| Ta90DeadendCheck N71–N77 | PASSED (49 checks) |
| Hint-follow N71–N77 (`tools/ta90_hintfollow29.gd`) | 7/7 PASS |
| xb28_validate (77 EXTREME records valid, fingerprints unchanged; 300 Classic levels valid) | PASSED |
| Ta90ContinueCheck | PASSED (705 checks, 252 cases, 0 not resumed exactly) |
| PortalCheck, MovableCheck, MagnetCheck | PASSED |

**WebAssembly TIME UP** (headless Chromium, `web_p29` BENCH; the page's limit is 250 ms):
- N71 11.7 ms;
- N72 11.5 ms;
- N73 22.7 ms;
- N74 13.2 ms;
- N75 2.5 ms;
- N76 5.9 ms;
- N77 3.6 ms.

The heaviest board on the page is the older N57, at 46.9 ms.

**Earlier pages (regression), on the Phase 29 build**

| Page check (headless Godot) | Result | Browser test | Result |
|---|---|---|---|
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
- Headless suites: 18 of 19 pass. These are unit tests, Competition, Timing, Profile, ExperienceLab, Feedback, FriendChallengeApi, FriendFlow, SocialApi, SocialSmoke, SocialPlay, TaPilot, Extreme11, Q1Time, RTime, Ta90, Extreme90 and Extreme90p17.
- **RecipientTest fails only its 3 known layout checks.** The failing check is "TOTAL SCORE left, coins right", once each for en_US, he_IL and ar_SA. They are unchanged since Phase 26, so this is not a regression.
- **verify_levels: all 300 Classic levels are solvable and pass the campaign rules.**

**First QA attempt (8 boards), kept for the record**
- **What happened:** the first chain ran on the 8-board selection. `web_p29` failed 3/12: CHALLENGE 3, the R05 board, could not be solved by touches.
- **Diagnosis:** the engine hint loops on every R05 board; see G.
- **What changed:** R05 was withdrawn, the ids were renumbered, and the chain was rerun from the exports. Its logs are kept in `qa_attempt1_8boards`.
- **Evidence:** `data/dev/extreme90_p29/qa/` (summary, suites, hint-follow log, WebAssembly bench).

## K. Verified downloadable QA ZIP

**`build/dev_qa/chain_escape_dev_extreme90p29_p29-qa1-20261031.zip`**
- **Size:** 15,385,271 bytes.
- **SHA-256:** `747688e8be0fe18144b017795aec98ef8445e0c73da8a16da30a3f6fa201d8ed`.
- **Build:** DEV BUILD `p29-qa1-20261031`. Its `index.pck` is byte-identical to the build that passed `web_p29`.
- **Delivery:** attached as a file.
- `build/` is not in Git.

**Playtest:**
- Open `index.html?extreme90p29=1`, on a private draft or a local server — not Production.
- CHALLENGE 1–7 = N71–N77. The labels are neutral.
- The protocol is unchanged:
  - 90 s;
  - unlimited RESTART;
  - UNDO ×3;
  - HAMMER 0;
  - SHOW A MOVE 0;
  - the 3 short questions, then the exact untimed continuation.
- COPY ALL RESULTS exports `ce-xb29`.
- First exposures count. Please note whether players shared solutions.

## L. Final local Phase 29 commit

- **Contents:** this commit holds only Phase 29:
  - the human results and owner decisions (35/50);
  - the advisory ranking tool and the hint-follow tool;
  - the records for N71–N77;
  - `?extreme90p29=1` and its check and web test entry;
  - the QA evidence;
  - this report.
- **Base:** it sits on Phase 28 (`3cea3bd`) and is pushed with a normal push after an ancestry check, never a force-push.
- **Not in this commit:** Phase 30 work, which stays local:
  - `data/dev/extreme90_p30/`;
  - `tools/extreme90_jobs30.py`;
  - `tools/extreme90_screen30.py`;
  - the `extreme90_eval25.py` bench-log change.

**Budget consumed:**

| Item | Ceiling | Used |
|---|---|---|
| Generator runs | 24 | **16** (round 91: 8; round 92: 8) |
| Full evaluations | 40 | **14** (all 14 met A and B; 8 selected, one per concept; R05 then withdrawn for the hint loop → 7) |
| Focused improvement round | 1 if fewer than 5 qualify | not needed (7 qualified) |
