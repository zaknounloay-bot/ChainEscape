# EXTREME phase 2: six enriched VERY HARD candidates (development only)

Base commit d7c1aeb (T1-T5). Development-only work: the `?xtest6=1` page (switched off in player / QA / Social QA builds), `data/dev/extreme6*.json`, and tools.

**Untouched:** Production, Supabase, campaign levels 1-300, the Social MVP, the live Friend generator, the shared challenge format, progression / economy, the live difficulty labels, and T1-T5 (`data/dev/extreme5.json` byte-identical, checked by hash; `?xtest5=1` unchanged).

**Goal:** richer, more surprising VERY HARD puzzles from existing mechanics, not puzzles harder than VERY HARD. Two per group:

| Group | Combination | Central idea (checked on the solution) |
|---|---|---|
| A | Magnet + Switch / Gate | A switch reverses a magnet, so it leaves the other way and pulls from the other side |
| B | Armor + Magnet | A magnet pulls a shelled block into another block's lane, which then cracks it |
| C | Portal + Spinner + Gate | A spinner that has turned leaves through a portal; a chain gate decides when the way opens |

## 1. Mechanic compatibility (before any board was built)

### 1.1 What the rules allow (code reading: LevelManager, BoardModel, Solver)

| Combination | Allowed? | In the campaign? | Notes |
|---|---|---|---|
| Magnet as a switch **flip target** (`R>&A*`) | Yes. The magnet validation forbids switch, lock, gate-link, armor, Sequence and twin roles, **not** flip targets | Never (magnets only in Levels 76-99, switches from 101) | The pull preview line follows the magnet's current direction, so it updates when the switch reverses it |
| Chain gate behind a magnet | Yes. A gate (like a crate or a twin) **stops** a pull | Never (gates from 121) | **Confusion risk:** this exception was never taught. Its only visible sign is the missing preview line. Taught by demo DA2 |
| Magnet pulling an armored block | Yes. The shell moves with the block | Never (armor from 151) | Natural: a pulled block keeps everything (arrow, shell, lock). Taught by demo DB1 |
| A magnet ramming | Yes. A ram is not an escape, so it pulls nothing | Never | Consistent with "a magnet pulls when it leaves" |
| Magnet + counter-clockwise spinners, magnet + colour lock | Yes | Never | Independent rules |
| Portal + spinner + gate (+ switch) | Yes | Portal + spinner in 47 levels, gate + portal in 3 (217, 222, 288) | Taught: no demo |
| Magnet + portal / crate / hidden | **No** (rejected by the parser) | — | Not used |

### 1.2 Removal order (BoardModel.remove)

When a block leaves:
1. adjacent spinners turn;
2. its switch reverses its targets;
3. its last link opens its gate;
4. **then** a magnet pulls.

A magnet cannot be a switch or a gate link, so its own escape never flips or opens anything. The preview is therefore always exactly what happens. Solver and BoardModel do this in the same order.

### 1.3 Game-versus-solver parity (new: `tools/Extreme6Parity.tscn`)

The existing Magnet check only ever tested magnets with clockwise spinners. The new parity check plays random small boards of each family against an exhaustive search that uses only BoardModel, tapping exactly as the play screen does (`move_state` → escape / ram):

| Family | Boards | Solvable | Verdict | Legal moves | Solutions replay | Do / undo | Pull = preview |
|---|---|---|---|---|---|---|---|
| A: magnets (incl. flip targets) + switch + gate + cw / ccw spinners + lock | 260 | 172 | 260 / 260 | 260 / 260 | 172 / 172 | exact | 13,628 / 13,628 |
| B: magnets + armor + cw / ccw spinners | 260 | 44 | 260 / 260 | 260 / 260 | 44 / 44 | exact | 12,594 / 12,594 |
| C: portals + spinners + gate (+ switch) | 406 | 240 | 406 / 406 | 406 / 406 | 240 / 240 | exact | — |

- **Features actually exercised:**
  - 280 flip-target magnets, on 194 boards where the switch changes what a magnet pulls;
  - 102 boards where a magnet's pull target is armored;
  - counter-clockwise spinners and locks.
- **Pull previews:** compared at every position up to 4 moves deep.
- **Result: 35 / 35 checks passed.**

### 1.4 Interactions that could confuse players (and what was done)

| Interaction | Risk | Decision |
|---|---|---|
| A gate stops a pull | Never taught; only the missing line shows it | Demo **DA2** teaches it before the first group A puzzle |
| A switch reverses a magnet (and its pull side) | New, but visible: the arrow and the horseshoe turn, and the line moves | Demo **DA1** |
| A pulled armored block keeps its shell | New, but natural | Demo **DB1** |
| A pulled block landing next to a spinner does **not** turn it (only leaving does) | Plausible expectation that "arriving" does something | Not relied on; mentioned as a limitation |
| A Sequence block rams without advancing but pushes and advances | Unexplained quirk | **Not used** (no Sequence in this phase) |

## 2. Result: two of six candidates (shortfall reported, no gate weakened)

| Group | Climbs | Candidates re-checked in the final merge | Accepted | Kept |
|---|---|---|---|---|
| A: Magnet + Switch / Gate | 118 | 36 | **0** | 0 |
| B: Armor + Magnet | 64 | 39 | 5 | **2 (P1, P2)** |
| C: Portal + Spinner + Gate | 105 | 17 | **0** | 0 |

**Acceptance (unchanged from T1-T5 unless stated):**
- **Technical (Gate 0):**
  - recipient check within 60,000 nodes, working budget 20,000 nodes;
  - SHOW A MOVE on every solution state and after every losing move;
  - the 40 ms native-desktop budget in **all 5** repeated measurements;
  - every mechanic matters (impact rule);
  - random tapper ≤ 8 %.
- **EXTREME filters:**
  - the luckiest rule of thumb hits ≥ 3 dead ends;
  - no greedy player wins > 5 %;
  - ≥ 2 distinct plausible losing moves that fail late;
  - each named mechanic is a real decision.
- **New in this phase:**
  - **the group's central idea happens on the solution**, replayed in the real game rules;
  - at most 14 pieces (16 for group C, whose 2 portal cells are markers on empty cells) and at most 18 taps: VERY HARD, not longer;
  - **not a variant** (more than half the occupied cells equal, in any rotation / reflection) of any board a tester may have played: campaign 1-300, the Gate 0 pilot, T1-T5;
  - the two boards of a group not variants of each other.

**Why A and C fell short (from the final merge's reasons):**
- **A:**
  - The chain gate was decoration on most candidates: removing it changes nothing ("gate does not matter", impact 0.0). That is a sign that the gate and the magnet compete for the same role (both control what is in a lane).
  - The rest failed on a greedy player winning 6-12 %, or the switch was "never a real decision": when to fire it is obvious.
  - The best A near-miss (a switch-reversed magnet drags a spinner across a row) loses to exactly one greedy player, "turn as few spinners as possible", 10 % of the time.
- **C:**
  - Greedy play wins 7-42 %, and often the portal or the gate does not matter.
  - This matches Gate 0, where the portal group was mostly rated EASY / MEDIUM: portal geometry seems to give greedy play more ways out.

**How the search changed during the work (method, not rules):**
1. The climb now rewards the central idea at every step. It used to check the idea only once every other gate held, which optimised difficulty on boards without the idea.
2. Climb starts are random boards that already contain the idea: 12 % of random A / C boards, 1.4 % of B boards.
3. Near the 5 % greedy limit, the climb re-measures with acceptance's own 200-game protocol. The quick 50-game estimate rejected boards on sampling noise (one game = 2 %).
4. Seeds: hand-modified T3 / T5 (and campaign Levels 217, 222, 288 for C). The near-copy guard ensures a result is not a variant of what testers played; every seed-derived candidate that stayed close to T3 / T5 was rejected.

## 3. The two candidates

| Board | Size / pieces | Solution | Luckiest rule: dead ends | Best greedy win | Late traps | Check / SHOW A MOVE / after a mistake (max nodes) | 5 repeated runs, worst ms each (native desktop) | x1 check / hint / after-mistake ms | x4 | x6 |
|---|---|---|---|---|---|---|---|---|---|---|
| P1 | 6x7 / 11 | 12 taps | 11 | 1.5 % | 4 | 8 / 34 / 117 | 19.6, 16.6, 22.1, 19.7, 29.9 | 0 / 4 / 26 | 3 / 16 / 62 | 3 / 21 / 91 |
| P2 | 6x6 / 10 | 12 taps | 9 | 1.0 % | 4 | 318 / 220 / 130 | 22.3, 15, 27.5, 22.7, 13.5 | 14 / 25 / 23 | 51 / 116 / 116 | 64 / 127 / 137 |

- The ×1 / ×4 / ×6 columns are the WebAssembly build in Chromium with CPU throttling at iPhone SE size: a simulation, not an iPhone.
- Both boards were selected by two independent strict merges, with timing runs of 13.5-29.9 ms.
- Exhaustively checked over every reachable position:
  - **every winning line uses the pull-then-ram idea;**
  - P1: 2 of its 6 legal first moves keep the board solvable;
  - P2: 1 of its 5.

### P1: "Drag the shell into the line of fire"

**The enjoyable interaction:**
- The armored red block in the top-left corner (R1C1) can never be hit where it is.
- The blue magnet at R1C5 is the way out. When it leaves to the right it drags the first block behind it along the top row, and once R1C3 and R1C4 have gone, that first block is the armored one.
- It lands in R1C5, straight above the clockwise spinner R at R3C5, which still points up and cracks it.
- The moment of discovery: **the magnet is not there to clear a lane; it is a delivery system for the shell.**

**What must be planned:**
1. Clear the top row in the right order: R at R1C3 leaves and turns the spinner Y at R1C4 to point up, then Y leaves.
2. Keep the rammer pointing up. Its two neighbours (Y at R3C6, P at R4C5) can leave at once, but each one turns it.

**Misleading moves (up to 9 moves before the jam):**
- the magnet on move 1, which drags the spinner Y instead of the shell;
- Y at R3C6 or P at R4C5 on move 1, which turns the rammer;
- the second magnet at R4C4 early, which drags P head-to-head with the spinner at R6C4.

### P2: "Two shells, two magnets, one order"

**The enjoyable interaction:** two armored blocks, cracked in two different ways.
- **The blue shell:** the red magnet at R3C4 drags it from the left edge (R3C1) into R3C4, above the counter-clockwise spinner P at R6C4, which cracks it. This works only if Y at R4C4 has left that column first; otherwise the magnet's own escape turns Y to face down, head-to-head with P.
- **The purple shell (R5C6):** cracked by the spinner P at R5C2, but only after a small chain turns that spinner to face right. P at R4C1 leaves, which turns Y at R5C1 down; Y leaves, which turns P right.
- **Only then:** the green magnet at R1C6 pulls the now unshelled purple block up into the top row, where it leaves.

**Misleading moves:**
- the green magnet on move 1, which drags the purple block up while its shell is still on, where nothing can crack it (up to 9 moves before the jam);
- P at R5C2 leaving up on move 1, which loses the only rammer for the purple shell (up to 9);
- B at R6C5 on move 1, which turns the counter-clockwise rammer (up to 9);
- the red magnet before Y has left (up to 7).

## 4. Interactive demonstrations (`data/dev/extreme6.json` "demos")

Shown before the first puzzle of a group whose combination the campaign never used. Each is one neutral sentence, a tiny board, and **the tester plays it**. Demos are never rated, logged separately, and are not any puzzle's solution.

| Demo | Rule | Board | Checked |
|---|---|---|---|
| DA1 | A switch reverses a magnet too; its pull line moves to the other side | 4x3, 5 pieces | Every winning line (4) uses a switch-reversed pull |
| DA2 | A chain gate behind a magnet stops its pull; once it opens, the magnet pulls the next block | 3x3, 5 pieces | Every winning line (2) pulls after the gate opened |
| DB1 | A magnet can pull an armored block; the shell moves with it | 3x3, 3 pieces | The only winning line pulls and then rams |

With only group B boards in this pilot, testers see **DB1** only. DA1 and DA2 stay in the file, ready for future group A boards.

## 5. The test mode (`?xtest6=1`, development builds only)

- **Separate:** its own board file, local state and storage key; `?xtest5` (T1-T5) is unchanged and checked to be unaffected.
- **Flow:** campaign progress, then the demo card when one is due ("BEFORE PUZZLE n / N, A NEW COMBINATION", TRY IT), then the reminder card, then the puzzle. The puzzle screen has a clock, GIVE UP, UNDO ×3, SHOW A MOVE ×1, no Hammer, and no difficulty label.
- **After each puzzle:**
  1. Difficulty: EASY … EXTREME.
  2. vs Level 300.
  3. Enjoyment 1-5.
  4. Achievement 1-5.
  5. Fairness.
  6. Needed planning.
  7. **Did the combination of mechanics make the puzzle more interesting?** (YES / A LITTLE / NO).
- **Measured:**
  - Solve time, restarts, UNDO, SHOW A MOVE, give-ups, blocked taps.
  - Magnet pulls, rams.
  - The full action log.
  - Each demo's time and completion.
- **Results:** COPY RESULTS exports JSON with a per-board summary (combination answers, 1-5 average).
- **Timing:** `&bench=1` times the check, SHOW A MOVE, and SHOW A MOVE after a mistake.

## 6. Validation and regression (final build)

| Test | Result |
|---|---|
| `Extreme6Parity` (new): game-vs-solver parity, families A / B / C | 35 / 35 |
| `Extreme6Check` (new). Covers: board file and acceptance; central idea replayed in BoardModel; no variants; demos exhaustive; every board and demo played to the end in the real play screen with tapped-block inference; full page walk; results; bench; `?xtest5` unchanged; T1-T5 file hash | 85 / 85 |
| `web_xtest6_page_test` (new). Covers: iPhone SE, real touches, the whole test incl. the demo, one solved and one given-up puzzle, all seven answers, storage, no errors, no network, bench ×1 / ×4 / ×6 | 14 / 14 |
| Extreme5Check (T1-T5), VhPilot4Check, VhHumanTestCheck, MagnetCheck | 147 / 147, 439 / 439, 100 / 100, passed |
| web_xtest5 / web_vhtest4 / web_vhtest page tests | 19 / 19, 14 / 14, 17 / 17 |
| Social MVP: RevealMvpTest, FriendFlowTest (149), SocialPlayTest | passed |
| T1-T5 builder after the refactor (dry-run merge of the T1-T5 candidates) | Same T1-T4. The magnet slot went to the earlier magnet prototype, which ties T5's score and passed all 5 timing runs by chance this time. That is the timing noise documented in phase 1, not a behaviour change: T5 alone passes as before. `data/dev/extreme5.json` is byte-identical |

**Dev ZIP:** `build/dev_qa/chain_escape_dev_extreme6.zip` (git-ignored, not uploaded), 13,092,552 bytes, SHA-256 `3f84a5e3e3de5f23460b0e22a42e7ae70f1504f58ef39ea45b467278e1413a33`. Open `index.html?xtest6=1`; for timing, `index.html?xtest6=1&bench=1`. It also contains `?xtest5=1` (unchanged).

## 7. Files

**New (development only):**
- `tools/extreme6_parity.gd`, `tools/Extreme6Parity.tscn`: parity check.
- `tools/extreme6_build.gd`: phase-2 builder, demos, near-copy guard.
- `tools/extreme6_events.gd`: solution replay and central-idea events (shared).
- `tools/extreme6_check.gd`, `tools/Extreme6Check.tscn`: end-to-end check.
- `tools/web_xtest6_page_test.mjs`: browser test + bench.
- `data/dev/extreme6.json`: 2 candidates + 3 demos.
- `data/dev/extreme6_notes.json`: hand-written explanations.
- `docs/extreme6.md`: this report.

**Modified (development only):**
- `scripts/social/vh_human_test.gd`: the `?xtest6=1` test (demos, combination question, publishes the demo state for tests). The other tests are unchanged.
- `tools/extreme5_build.gd`: overridable settings for the phase-2 subclass (defaults = T1-T5 values), a 200-game re-measure when a climb is near the greedy limit, and the "two boards of a recipe are not variants" rule (inactive for T1-T5, which keeps one per recipe).

## 8. Limitations and recommendations

- **L1. Shortfall: 2 of 6.** No group A or group C board met every gate. The report names why; no gate was weakened.
- **L2. One combination only.** Both candidates are Armor + Magnet, so the pilot can compare it with T1-T5 but not with A or C.
- **L3. Magnet + flip-target marker overlap (group A, not in this pilot).** When such a magnet points right, its horseshoe touches the switch-link badge (bottom left). Both stay recognisable at iPhone SE size (screenshot). A clean fix needs a block-drawing change in game code, which is outside this phase.
- **L4. Model-selected.** As with T1-T5, the boards beat our player models. The held-out lesson from phase 1 applies: people may spot the key idea at a glance. Only the human test can show the experience is richer.
- **L5. Phone timing is simulated.** Real Safari `&bench=1` is still to be run. P2 (318 nodes) is the heavier of the two.
- **L6. A pulled block landing next to a spinner does not turn it.** Only leaving turns spinners. Neither board relies on it, but a tester might expect it.

**Recommendations:**
1. Run the human test with P1 and P2 now, on a real iPhone first, with at least 2 experienced testers. Paste the COPY RESULTS so the combination answer can be compared with T5's ratings.
2. **Group A** needs hand design, not search: the search keeps producing gates that do nothing next to a magnet. A designer should build the "reverse the magnet" moment deliberately. The best near-miss (a switch-reversed magnet drags a spinner across a row) is a good starting sketch.
3. **Group C:** given Gate 0's portal results and this search, Portal + Spinner + Gate looks the least promising route to a richer VERY HARD. Deprioritise it unless a designer has a specific idea.
