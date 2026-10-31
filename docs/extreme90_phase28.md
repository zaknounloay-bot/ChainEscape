# EXTREME Time Attack — Phase 28: high-throughput EXTREME design

Development only. The following are untouched:
- Production and Supabase;
- the 300 frozen Classic levels (all verified);
- saves, timing and Personal Best;
- the 120-second Time Attack baseline;
- the Social MVP and Challenge a Friend.

There is no new mechanic or UI. The game-script changes are only:
- the new developer page (`scripts/social/extreme90_p28.gd`);
- its `game_manager` hook;
- eight `BOARDS90` entries.

All generator changes are in development tools.

**Outcome: 8 technically qualified, conceptually distinct candidates, N63–N70.** Phase 27 produced 1.
- Every gate is unchanged.
- The gain comes from fixing the pipeline, not from loosening anything.

## A. Updated approved count: 29 / 50

- **N62:** owner-approved. Its first-exposure result is EXTREME, TIME UP at 90 s, enjoyment 5/5.
- **Where it is recorded:**
  - the rating in `data/dev/extreme90_p27/human_p27.json`;
  - the owner's decision, separately, in `data/dev/extreme90_p28/owner_approvals_p28.json`.
- **Unchanged:** every earlier owner decision. N60 stays downgraded.
- **Manifest** (`data/dev/extreme90_bank_status.json`):

  | Class | Count |
  |---|---|
  | Owner-approved | **29** |
  | Strong provisional | 3 |
  | Provisional | 9 |
  | Technically qualified, untested | **8 (N63–N70)** |
  | Downgraded or archived | 21 |

- **Remaining to 50:** 21.

## B. Phase 27 Git backup status

- At the start of Phase 28, HEAD was `c1ddc89` (Phase 27) and `origin` was at `458fe57`, a direct ancestor (checked).
- A normal push (no force) moved `origin` to `c1ddc89`, confirmed by a re-fetch. **Phase 27 is backed up.**
- Phase 28 is one local commit on top, **not pushed** (section L).

## C. Root-cause rejection statistics (Phases 26–27)

The new tool `tools/extreme90_diag28.py` measures every run and every full evaluation (output: `data/dev/extreme90_p28/diag_p26_p27.json`).

| Measure | Phases 26–27 |
|---|---|
| Generator runs | 19 (15 with qualifying boards) |
| Qualifying boards | 6,364 |
| **…with an engine-invalid token** | **1,790 (28.1%)**; 98% in J2 seed 53 and 99% in L1 seed 62 |
| Valid and ≤ 700 positions | 1,725 |
| Full evaluations | 20 |
| Technically clean | **6 (30%)** |
| — failed: a core mechanic not essential (strict rule) | **8** |
| — failed: filler | 6 |
| — failed: invalid token reached evaluation | 3 |
| — failed: overlap | 2 |
| — failed: bench floor | 1 |
| Accepted after the human / novelty audit | 4 (N59, N60, N61, N62) |
| **Accepted per run / per full evaluation** | **0.21 / 0.20** |

**Largest bottlenecks:**
1. **Invalid tokens: 28% of the output.**
   - `ta90_search.gd`'s `_suffix` appended a mark to whatever token it was given. Its comment said "only with a plain-arrow token"; the code never checked.
   - The parser then silently "repaired" the board: an armored spinner lost its armor. So a qualifying board was not the board that would be played.
2. **Non-essential core mechanics: 40% of full evaluations.**
   - The generator counted a mechanic as mattering if removing it changed *anything* (`matters`).
   - The acceptance rule requires the board to be unsolvable without it, or to lose ≥ 2 distinct mistakes or ≥ 3 decision steps.
   - Boards whose gate or Sequence core the grown spinners had made redundant therefore qualified, and cost full evaluations.
3. **Filler: 30% of full evaluations.** Often the "filler" was a wall that kept greedy players out (removing it raised the shortcut above 20%).
4. **No cheap screen.** Every one of the 20 candidates went straight to the full evaluation: the full report with learners, plus filler, plus overlap.
5. **Concept exhaustion.** It had a pipeline component:
   - the Phase 26–27 belief that "magnets are plain arrows" was wrong (see D);
   - L1, L5 and L6 failed for pipeline reasons, not because their concepts were flawed.

## D. Generator improvements and tests

All of these are development tools only. Gameplay, the parser and the 300 levels are unchanged.

1. **`tools/xb28_validate.gd`** — the engine's modifier rules as a validator, mirroring `level_manager.gd` rule for rule.
   - Token rules:
     - switch, flip target or armor on a spinner;
     - a hidden spinner;
     - a hidden block that is locked;
     - a block locked by its own colour;
     - a block that is both switch and flip target;
     - an armored block that is locked or a switch;
     - a Sequence block with any other mark;
     - a magnet with a spinner, lock, switch, link, armor, Sequence or twin role;
     - a twin that is not a plain arrow.
   - Board rules:
     - a magnet on a board with portals, crates or hidden blocks;
     - missing switch or gate partners.
   - **Finding: a magnet MAY be a flip target.** `_validate_magnets` does not forbid `&`. This opened the "turned magnet" family (N64).
2. **Token guard in `tools/ta90_search.gd`.** `"token_guard"` defaults to true; `false` restores the old behaviour.
   - `_suffix` never appends a mark that is illegal on its token.
   - Every generated board is checked with `board_problems()` **before parsing or solving**. Refused boards are counted (`invalid_refused` in the run file).
3. **Strict essentiality inside the search.** `"strict_essential"` defaults to true.
   - The generator scores and qualifies with the acceptance rule itself.
   - Spinners on the board count as a mechanic too, so grown spinners must carry decisions.
4. **`"spinners_max"`** (optional): once the board holds that many spinners, new pieces are plain arrows. Phase 28 used 4, and 6 for P05.
5. **`tools/extreme90_screen28.py` — the early screen**, run on whole shortlists before any full evaluation. It checks, cheapest first:
   - valid tokens;
   - bank overlap;
   - one quick design report covering Category A (including the 40 ms TIME UP gate), Category B and every counterfactual;
   - the strict essentiality rule;
   - one filler pass.
   - Calibration: on four Phase 26–27 boards with known outcomes it reproduced every decision in 53 s.
6. Supporting tools:
   - **`tools/extreme90_shortlist28.py`:** valid, ≤ 700 positions, lowest overlap first;
   - **`tools/extreme90_diag28.py`:** the statistics in C;
   - **`tools/extreme90_tokens26.py`:** the Python port of the same rules.

**Tests: `tools/xb28_validate_check.gd`, which passes (3 checks, plus 1 per run file):**
- **Agreement with the real parser:** 21 valid and 17 invalid tokens, each parsed by `LevelManager` and written back. Accepted tokens come back unchanged and refused tokens come back changed, with no disagreement.
- **Existing bank records unchanged:** all 70 EXTREME records are valid and keep their fingerprints.
- **No campaign or gameplay change:** all 300 Classic levels are valid. `verify_levels` also passes in regression.
- **Generator output:** the pipeline-test runs (L1, L6) and every Phase 28 run have **0 invalid qualifying boards**. In Phases 26–27, L1 seed 62 had 205 of 207.

**Pipeline test** (`data/dev/extreme90_p28/pipeline_test/`, 3-minute runs, not counted in the budget):
- On Phase 27's L6 core, where the gate was not essential on all 3 boards evaluated in Phase 27, the strict generator gave 56 qualifying boards and **6 of 6 screened PASS**.

**Phase 28 after the fixes** (`diag_p28.json`):

| Measure | Phases 26–27 | **Phase 28** |
|---|---|---|
| Invalid-token rate | 28.1% | **0%** (0 / 2,651) |
| Technically clean full evaluations | 30% | **100% (10 / 10)** |
| Accepted per run | 0.21 | **0.50** (8 / 16) |
| Accepted per full evaluation | 0.20 | **0.80** (8 / 10) |

*Note:* the overlap column in `diag_p28.json` is computed against the current bank, which now contains N63–N70, so those boards appear to overlap themselves. The selection used the bank as it stood at selection time.

## E. Concept funnel (39 proposals, 28 families)

Full list: `data/dev/extreme90_p28/concept_funnel.json`. Every proposal records its family, its decision and the reason, decided **before generation**.

- **Rejected before generation (26)**, as duplicates or infeasible. Examples:
  - N62, N61, N59, N60, N53, N52 and N44 / N58 themselves;
  - N41 / N38, N20 / N42, N34 / N40, K2 / H6, N16, N19, N25, N54;
  - infeasible: a crate without a direction change; Sequence + switch; "two rammers share a shell" (a ram can never be wrong).
- **Advanced to hand cores (13):**

| Core | Concept | Family | Round 81 | Round 82 | Result |
|---|---|---|---|---|---|
| P01 | the reversed block waits at the gate | switch × gate | 267 qual., 6 / 8 screened PASS | — | **N65** |
| P02 | the locked trigger | switch × lock | 509, 8 / 8 | — | **N63** |
| P03 | the turned magnet (magnet flip target) | magnet × switch | 300, 8 / 8 | — | **N64** |
| P04 | the relocated switch | magnet × switch | 384, 7 / 8 | — | **N70** |
| P05 | pull the prisoner | magnet × lock | 0 | 105, 3 / 6 (spinners_max 6) | **N67** |
| P06 | the key is also a link | lock × gate | 199, 8 / 8 | — | **N66** |
| P07 | the armored key | lock × armor | 0 | stopped | **monotone** |
| P08 | the battering ram | Sequence × armor | 201, 0 / 8 (filler wall; 36–38% greedy without it) | 0 | stopped |
| P09 | the gate guards the shell | gate × armor | 0 | stopped | **monotone** |
| P10 | the gate holds the boomerang | Sequence × gate | 0 | stopped | **monotone** |
| P11 | the far gate | portal × gate | 0 | stopped | **monotone** |
| P12 | the shuttle and the door | crate × switch × lock | 186, 6 / 8 | — | **N68** |
| P13 | two walls in one row | crate × gate × switch | 192, 0 / 8 (filler walls) | 308, 7 / 8 | **N69** |

**The structural finding: "monotone" mechanic sets.** Lock + armor, gate + armor, Sequence + gate and portal + gate only *enable* moves. With them no move can become irreversibly wrong, because a lock opening, a gate opening, a ram or a portal lane never hurts. Every decision on such a board therefore came from grown spinners, and the strict rule now correctly refuses them. Each concept needs at least one **snapshot** mechanic: switch, magnet, crate, Sequence advance or spinner turn.

## F. Qualified candidates N63–N70

All eight are marked **TECHNICALLY QUALIFIED — HUMAN UNTESTED**. Records: `data/dev/ta90_n63.json` … `ta90_n70.json`.

| ID | Concept | Mechanics | Fingerprint |
|---|---|---|---|
| N63 | the locked trigger | switch, lock, spinners | `1db9dd7964966799…` |
| N64 | the turned magnet | magnet (flip target), switch, armor, spinners | `9816c00f2e2d7851…` |
| N65 | the reversed block waits at the gate | switch, gate, spinners | `8096b0c58078ade0…` |
| N66 | the key is also a link | lock, gate, spinners | `8bca19912c66d998…` |
| N67 | pull the prisoner | magnet, lock, armor, spinners | `1f3e94cc1bf610f0…` |
| N68 | the shuttle and the door | crate, switch, lock, spinners | `b0427dddc6458f59…` |
| N69 | two walls in one row | crate, gate, switch, spinners | `a93aa6be7c312905…` |
| N70 | the relocated switch | magnet, switch, spinners | `5b1aa7335b91df64…` |

**What each core does:**
- **N63:** the locked switch W1 and its key face each other. A second, free switch piece reverses the key out; the key's departure unlocks W1, whose firing reverses everything still present.
- **N64:** the magnet is a flip target. The reversal turns its pull line to the other side, so firing before or after the switch decides which block is pulled — and which spinners its departure and the arrival turn.
- **N65:** the reversal turns a block toward the gate, which opens only with its last link — and the switch piece is one of the links. The second switch piece undoes the reversal if fired too early.
- **N66:** the yellow key is also a gate link. Its departure unlocks the locked blocks and counts toward the gate that walls the long rammer lane.
- **N67:** the magnet pulls a *locked* rammer into its shell's row. It strikes only after the last yellow key, the magnet itself among them, has left.
- **N68:** the key and a flip-target pusher shuttle the crate out of the key's lane, and only the reversal lets the pushers out of the crate's line. The key opens two locks.
- **N69:** the row-3 spinner can escape only once the crate is pushed out of the row (by a flip target that then needs the reversal) **and** the gate is open.
- **N70:** the switch walls in the very block it reverses; the magnet's pull moves it out of that lane.

## G. Individual metrics

Desktop timing. "Best greedy" is the full report's shortcut figure (the gate is 20%).

| ID | Pos. | Moves | Distinct | Steps | Cov / late | Best greedy | look6 | Solve / TIME UP ms | Overlap (bank) |
|---|---|---|---|---|---|---|---|---|---|
| N63 | 255 | 18 | 4 | 16 | 0.89 / 0.89 | 0.8% | 0.008 | 16.4 / 16.3 | 0.36 N39 |
| N64 | 367 | 17 | 5 | 13 | 0.76 / 0.76 | 0% | 0.033 | 15.8 / 11.3 | 0.33 N39 |
| N65 | 347 | 16 | 5 | 14 | 0.88 / 0.88 | 9.5% | **0.083** | 2.1 / 2.7 | 0.32 N52 |
| N66 | 343 | 18 | 4 | 15 | 0.83 / 0.83 | 13% | 0.050 | 5.7 / 4.3 | 0.28 N38 |
| N67 | 564 | 17 | 4 | 14 | 0.82 / 0.82 | 10.5% | 0.042 | 4.4 / 17.2 | 0.32 N59 |
| N68 | 647 | 15 | **7** | 14 | 0.93 / 0.93 | 0% | 0 | 24.6 / 21.6 | 0.30 N33 |
| N69 | 249 | 14 | 5 | 12 | 0.86 / 0.86 | 8% | 0.017 | 24.3 / 13.2 | 0.22 N35 |
| N70 | 258 | 15 | 5 | 13 | 0.87 / 0.87 | 10.5% | 0.050 | 8.5 / 7.1 | 0.29 N43 |

- **Filler:** 0 on all eight.
- **Pairwise overlap among the eight:** at most **0.38** (N65 / N67). The first N67 pick overlapped P01_5 at 0.48, and P01's chosen board was swapped to keep both concepts.
- **Exact Solver lines and the losing moves at each step:** in each record's `design_report.B.line` and `losing_per_step`.
- **Core-on-line check (done by hand):**
  - N63: the free switch fires at step 8, the key leaves at step 9, the locked switch fires at step 13.
  - N64: the switch at step 10, the turned magnet at step 11.
  - N65: the switch at step 9, the last link at step 13, the reversed block through the gate at step 14.
  - N66: the key-link at step 3, the gate opens at step 8, the long ram at step 9.
  - N67: the pull at step 3, the last key at step 11, the ram at step 14.
  - N68: the crate pushes at steps 6–8 and 12, the key leaves at step 9, two locks open at steps 10–11.
  - N69: the crate pushed out at steps 4–6, the last link at step 10, the row spinner through the gate at step 12.
  - N70: the pull of the switch at step 6, the walled-in block leaves at step 13.

## H. Essentiality and shortcut findings

**Essentiality** (strict rule, every mechanic and the spinners). On each board every mechanic either makes the board unsolvable when removed, or removes ≥ 2 distinct mistakes or ≥ 3 decision steps.
- Examples: N68 without the crate has 0 decisions. N64 without its armor drops from 13 / 5 to 4 / 1. N69 without its gate drops from 12 to 9 steps.

**Human-like shortcut audit.** This combines the diagnostics (`tools/ta90_humanlike26.gd`) with inspection.
- No obvious shortcut was found. Calm-player win chance is 0–4%; random and look-2 players are about 0.
- **Strongest profiles:**
  - N63: dependency depth 12, 13 forced steps, only 1 of 4 openings safe;
  - N64: depth 11, all greedy 0, win density 0.13;
  - N68: 7 distinct mistakes, all greedy 0.
- **Flags** (calibrated on Phase 25–27 human results: look6 ≤ 0.042 on the approved boards; N54 0.175 and N60 0.10 rated MEDIUM):
  - **N65:** look6 0.083, the highest here.
  - **N66, N70:** look6 0.050.
  - **N70:** a calm player wins 4% (the highest), win density 0.26.
  - **N68 and N69:** shallow dependency (depth 5 / 8, 14–15 moves). These are crate boards, and N57 (depth 3) rated EASY.
- **Rejected on human grounds:**
  - P01_7: passed every technical gate, but look6 was 0.175 (N54's level);
  - P04 boards other than P04_1: calm-player win 10%.

## I. Conceptual diversity

- **Eight different dependency structures:**
  - three reversal-based, with different second mechanics (lock, gate, crate);
  - three magnet-based, each with a different role for the pull: a turned pull line, relocating a trigger, delivering a locked cargo;
  - one lock / gate;
  - one crate / gate.
- **Closest bank relatives** are named in each record (`related_bank_concept`):
  - N63 ~ N23 / N61;
  - N64 ~ N59 / N36 (no bank board has a magnet flip target);
  - N65 ~ N61 / N16;
  - N66 ~ N22;
  - N67 ~ N52 / N18;
  - N68 ~ N35 / N50 / N33;
  - N69 ~ N56 / N35;
  - N70 ~ N59 / N36.
- **Avoided:** no N52 cascade, no shared-key spinner counting, no N56 crate-gate-spinner brake, no N59 magnet relocation, no N61 deadlock, no Sequence pusher.
- **Family risk:** three magnet boards (N64, N67, N70) and three switch-centred boards (N63, N65, N68). Their dependencies differ, but players may perceive families.

## J. Exact regression results

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real iPhone was used.**

**Phase 28 development page and builds**

| Test | Result |
|---|---|
| Dev export / player export | OK (8 new boards in dev; 0 `data/dev` files in the player build) |
| `web_p28` (`?extreme90p28=1`, timed 90 s runs by touches, SKIP, export `ce-xb28`, WebAssembly TIME UP) | **PASSED 130/130** |
| Extreme90p28Check | PASSED (260 checks) |
| xb28_validate_check (validator and parser agree; 70 EXTREME records with unchanged fingerprints; 300 Classic levels valid) | PASSED (3 checks) |
| Ta90DeadendCheck, N63–N70 | PASSED (56 checks) |
| Ta90ContinueCheck | PASSED (628 checks, 224 cases, 0 not resumed exactly) |
| PortalCheck, MovableCheck, MagnetCheck | PASSED |

**Earlier development pages (regression)**

| Page check (headless Godot) | Result | Browser test (headless Chromium) | Result |
|---|---|---|---|
| Extreme90p27Check | 226 | `web_p27` | 114/114 |
| Extreme90p26Check | 222 | `web_p26` | 112/112 |
| Extreme90p25Check | 212 | `web_p25` | 106/106 |
| Extreme90p24Check | 186 | `web_p24` | 94/94 |
| Extreme90p22Check | 184 | `web_p22` | 92/92 |
| Extreme90p21Check | 168 | `web_p21` | **see the load incident below; isolated rerun 84/84** |
| Extreme90p20Check | 132 | `web_p20` | 66/66 |
| Extreme90p19Check | 124 | `web_p19` + P19 upgrade | 62/62 + 9/9 |
| Extreme90p18Check | 111 | `web_p18` | 55/55 |
| — | | `?extreme90=1` archive, `?extreme90p17=1` | 45/45, 51/51 |

**Other suites**
- Browser: `?ta90=1` 55/55; `?tapilot` 28/28; web timing PASSED; friend build 25/25; `stime` 31/31; `ttime` (tta) 32/32.
- Headless suites: 18 of 19 pass. These are unit tests, Competition, Timing, Profile, ExperienceLab, Feedback, FriendChallengeApi (58), FriendFlow (149), SocialApi, SocialSmoke, SocialPlay, TaPilot (33), Extreme11 (74), Q1Time (37), RTime (39), Ta90 (91), Extreme90 (91) and Extreme90p17 (97).
- **RecipientTest fails only its 3 known layout checks.** The failing check is "TOTAL SCORE left, coins right", once each for en_US, he_IL and ar_SA. Nothing changed since Phase 26: no new failure.
- **verify_levels: all 300 Classic levels are solvable and pass the campaign rules.** The campaign is untouched.

**Load incident (web_p21), resolved**
- **What happened:** the first `web_p21` run FAILED at check 6, a timeout in the timed N39 run (0 blocks, not completed).
- **Cause:** it ran at 15:12 while four Phase 29 generator processes were also running. The load average was about 8 on 4 cores.
- **Rerun:** after the generators finished, `web_p21` was rerun alone (load 1.17 at start). It **PASSED 84/84**, so the timeout does not reproduce.
- **Conclusion:** CPU saturation, not a regression.
- **Other tests in that period:** `web_p20` also started while the generators were running, and it passed. Every later test ran after the generators had stopped (round 91 ended at 15:30), batch D's timing test included. No generator ran during browser QA after that.

**N68 performance watch: controlled WebAssembly TIME UP timing**
- **Method:** `tools/web_extreme90_timing28.mjs`, on the dev build in headless Chromium (SwiftShader, iPhone SE viewport).
- **Measurement:** the page's own `&bench=1` check, a fresh Solver with the full limit; each measurement is the median of 3 solves.
- **Isolation:** one fresh browser context per measurement. The test ran alone; each set started at load average below 1.5 (1.18 and 1.14).
- **Load during the sets:** load rose to 1.4–3.6 from the headless browser itself; no other process was running.
- **Reference boards:** N63 and N64 (new, similar desktop cost) and N57 (approved, the heaviest Phase 25 board).
- **Evidence:** `data/dev/extreme90_p28/qa/n68_timing_a.json` and `n68_timing_b.json`.

| Board | Nodes | Set A runs (ms) | Set B runs (ms) | Median of all 10 (ms) |
|---|---|---|---|---|
| **N68** | 885 | 22.8, 23.9, 25.1, 25.8, 31.0 | 22.9, 23.8, 24.8, 27.7, 31.5 | **24.95** |
| N63 | 226 | 13.6, 13.7, 14.2, 14.5, 26.7 | 13.0, 15.0, 16.4, 21.4, 24.8 | 14.75 |
| N64 | 262 | 12.0, 12.7, 14.6, 15.0, 15.2 | 13.3, 14.3, 16.2, 16.9, 20.3 | 14.8 |
| N57 | 1,949 | 49.1, 49.6, 49.8, 51.3, 82.2 | 48.8, 52.7, 52.9, 54.0, 70.1 | 52.0 |

- **N68 under low load:** 22.8–31.5 ms (median about 25 ms), compared with **39.1 ms** in the saturated `web_p28` run. The earlier figure was inflated by load.
- **Against the page's limit:** the WebAssembly limit is 250 ms, and N68's maximum is 31.5 ms.
- **Against the bank:** N68 is not the heaviest board; approved N57 costs about 2× more.
- **Spread:** set A and set B agree to within 0.3 ms on N68's median.
- **Approval and release readiness are separate:**
  - **Approval:** N68's approval is unchanged; it is the owner's decision.
  - **Release readiness:** green on headless Chromium. **This is not real iPhone testing.** No real device was used, and real-iPhone timing remains open for release readiness.

## K. Verified downloadable QA ZIP

**`build/dev_qa/chain_escape_dev_extreme90p28_p28-qa1-20261031.zip`**
- **Size:** 15,277,245 bytes.
- **SHA-256:** `0a29ff2793ef5f3e55d5751295975937eb92e1f6ba9412a00c4bff79bc9521da`.
- **Build:** DEV BUILD `p28-qa1-20261031`. Its `index.pck` matches the build tested above.
- **Delivery:** the ZIP was attached as a file after `web_p28` passed. It was re-verified (size and SHA-256) before this commit.
- `build/` is not in Git.

**Playtest:**
- Open `index.html?extreme90p28=1`, on a private itch.io draft or a local server — not Production.
- CHALLENGE 1–8 = N63–N70. The labels are neutral.
- The protocol is unchanged:
  - 90 s;
  - unlimited RESTART;
  - UNDO ×3;
  - HAMMER 0;
  - SHOW A MOVE 0;
  - the 3 short questions, then the exact untimed continuation.
- COPY ALL RESULTS exports `ce-xb28`.
- First exposures count. Please note whether players shared solutions.

## L. Final local Phase 28 commit

- **Contents:** this commit holds only Phase 28:
  - the token guard and its tests;
  - the early-screen, shortlist and diagnostics tools;
  - the records for N63–N70;
  - `?extreme90p28=1` and its check and web test;
  - the timing tool and the QA evidence (`data/dev/extreme90_p28/qa/`);
  - this report.
- **Base:** the commit sits on Phase 27 (`c1ddc89`), which is already on `origin`. It is pushed with a normal push after an ancestry check, never a force-push.
- **Not in this commit:** the human results for N63–N70 and all Phase 29 work. These belong to Phase 29:
  - `data/dev/extreme90_p28/human_p28.json`;
  - `data/dev/extreme90_p29/`;
  - `tools/ta90_rank29.gd`.
- **Bank state:** the owner approvals of N64, N68 and N69 (32/50) are recorded in Phase 29. At this commit the manifest still shows 29/50, with N63–N70 marked TECHNICALLY QUALIFIED — HUMAN UNTESTED.

**Budget consumed:**

| Item | Initial ceiling | Used |
|---|---|---|
| Generator runs | 24 | **16** (round 81: 13; focused round 82: 3) |
| Full evaluations | 40 | **10** (8 accepted; 2 rejected — P01_5 for pairwise overlap with the only P05 boards, P01_7 for look6 0.175) |
| Early screens (not full evaluations) | — | 86 boards, plus 12 in the pipeline test |
| Additional search round | optional | not used |

**Risks:**
1. Technical qualification is not human difficulty. Five boards carry human-risk flags (H).
2. Three magnet and three switch-centred boards: family perception is possible.
3. The generator fixes change what a given seed produces. Earlier runs stay reproducible with `token_guard: false` and `strict_essential: false`.
4. Headless browser testing only: no real iPhone.
5. The known RecipientTest layout failures remain (J).
