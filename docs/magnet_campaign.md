# Magnet campaign: Levels 76–99

Implements the approved plan (`docs/magnet_campaign_plan.md`, revised in `beca155`). **Levels 80 and 90 are unchanged.** The other 22 levels of 76–99 are new Magnet boards. Their old boards are archived in `data/dev/pre_magnet_76_99/`.

## The rule (production)

- **Magnet** (`*` after the arrow in a level file, for example `R<*`). When a magnet escapes, the first block straight behind it slides into the cell the magnet left. The pull happens after the spinners turn.
- **Nothing pulls** when there is nothing behind the magnet, or when a gate, crate or twin is directly behind it.
- **Preview:** the dotted line and bracket on the block that will be pulled (`BoardModel.pull_target`), so the player always sees the pull before tapping.
- **Hammer (approved decision 1):** a smashed magnet pulls nothing (`model.remove(id, false)`). Spinners next to it still turn, as for every smash. The game shows *"Magnet smashed - nothing is pulled"*. Gameplay, `Solver.hammer_safe`, Undo and the tests all use the same rule.
- **Where Magnets are allowed:** in campaign level files and the Magnet lab. They are not allowed in Social or Friend boards. The checker accepts Magnets only in 76–99, never in 80 or 90. Magnets may not share a board with portals, crates or hidden blocks.
- **Friend Challenge:** board keys skip Magnet levels, as they already skip Twins. That leaves 168 keys, and the challenge format is unchanged.

## Tutorial (approved decision 5)

Level 76 follows `docs/tutorial_rule.md`:

1. The NEW MECHANIC card appears first. It is animated: the block behind slides into the magnet's place.
2. When the card closes, a one-time finger lesson starts. The finger points at a solvable move: *"MAGNET: clear its way first - then it pulls the block behind it"*. Once the magnet is free, it says *"MAGNET: when it leaves, the block on the dotted line slides into its place - tap it"*.
3. The player taps every move themselves.
4. The lesson ends on the first pull with *"Pulled! The block behind took the magnet's place"*. It is saved as `lesson_magnet` and never repeats.

Level 76 also starts an arc (`ARC_STARTS`), and the chapter news shows "NEW: Magnets".

## Levels

How to read the table:
- **D** is `LevelGenerator.difficulty`; **S** is the structural score.
- **Depth**, **dec**, **traps** and **start** are the checker's metrics (start = number of moves available at the start).
- **Pulls** = pulls in the Solver's solution.
- Every non-breather level is **ESSENTIAL**: with its magnets turned into plain arrows, the level becomes unsolvable or trivially different.

| # | Name | Size | Blocks / magnets | Role and idea | D | S | Depth | Dec | Traps | Start | Pulls |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 76 | Dynamo | 6×6 | 7 / 1 | LESSON: two blocks face each other; the magnet pulls one free | 5.0 | 4.3 | 5 | 0 | 0 | 2 | 1 |
| 77 | Feedback | 6×6 | 9 / 1 | lesson: the pull travels several cells | 5.9 | 4.5 | 6 | 0 | 0 | 3 | 1 |
| 78 | Wavelength | 6×6 | 10 / 1 | lesson: the pulled block leaves from the magnet's cell | 8.0 | 6.5 | 6 | 1 | 1 | 3 | 1 |
| 79 | Hyperloop | 7×6 | 12 / 1 | lesson: first choice, clear the nearer block to retarget the line | 15.4 | 13.2 | 9 | 3 | 3 | 3 | 1 |
| *80* | *Dark Matter* | | | ***unchanged*** (no Magnet) | *50.7* | | | | | | |
| 81 | Summit Path | 7×6 | 15 / 1 | the magnet's escape turns the spinner beside it | 19.4 | 16.4 | 11 | 4 | 4 | 1 | 1 |
| 82 | Thin Air | 7×7 | 16 / 1 | the pulled block is a spinner | 22.5 | 19.4 | 15 | 4 | 4 | 2 | 1 |
| 83 | Ridge Line | 7×6 | 16 / 1 | spinner timing before the pull | 24.6 | 21.0 | 13 | 6 | 6 | 2 | 1 |
| 84 | Iron Crown | 7×7 | 17 / 1 | two escapes beside a spinner decide where things land | 26.1 | 22.4 | 12 | 7 | 7 | 2 | 1 |
| 85 | Avalanche | 7×6 | 15 / 1 | BREATHER: friendly spinners, one helpful pull | 20.1 | 17.0 | 12 | 4 | 4 | 1 | 1 |
| 86 | Glacier | 7×7 | 17 / 2 | decoys: clear them in the right order | 24.2 | 21.1 | 13 | 6 | 6 | 2 | 2 |
| 87 | Stormwatch | 7×6 | 17 / 1 | the magnet is free at once, but pulling now loses | 27.4 | 23.7 | 13 | 6 | 10 | 2 | 1 |
| 88 | High Pass | 7×6 | 18 / 2 | a magnet pulls another magnet into place | 30.5 | 27.2 | 13 | 9 | 10 | 2 | 2 |
| 89 | Keystone | 7×7 | 18 / 2 | two magnets whose pull lines cross | 32.8 | 29.0 | 15 | 9 | 9 | 2 | 2 |
| *90* | *Eclipse Peak* | | | ***unchanged*** (no Magnet) | *54.2* | | | | | | |
| 91 | Grandmaster | 7×7 | 18 / 2 | two magnets in one line | 31.7 | 27.9 | 14 | 9 | 9 | 1 | 2 |
| 92 | Checkmate | 7×7 | 19 / 2 | the magnet is free early but must wait | 34.2 | 30.3 | 14 | 10 | 10 | 2 | 2 |
| 93 | Gordian Knot | 7×7 | 20 / 2 | chain pulls and spinner timing together | 35.6 | 31.6 | 16 | 10 | 10 | 2 | 2 |
| 94 | Clockwork Crown | 7×7 | 19 / 1 | a patterned spinner meets a pulled block | 36.9 | 32.2 | 14 | 11 | 11 | 2 | 1 |
| 95 | Paradox | 7×7 | 19 / 2 | two magnets, each the other's decoy | 36.0 | 32.0 | 14 | 11 | 13 | 2 | 2 |
| 96 | Endgame | 7×7 | 20 / 1 | challenge: two visible traps | 41.9 | 37.4 | 13 | 14 | 14 | 2 | 1 |
| 97 | Apex | 7×7 | 18 / 2 | BREATHER: a satisfying chain of pulls | 24.7 | 20.9 | 15 | 5 | 5 | 1 | 2 |
| 98 | Zenith | 7×6 | 20 / 3 | **the hardest Magnet level**: a full plan from the first tap | **48.9** | **44.4** | 15 | 16 | 21 | 2 | 3 |
| 99 | Last Light | 7×6 | 18 / 2 | finale: every Magnet idea once more | 34.4 | 30.6 | 13 | 11 | 11 | 2 | 2 |
| *100* | *The Master* | | | ***unchanged***: era finale | *67.7* | *54.5* | | | | | |

**Preserved on every replaced level:**
- the old level name;
- the exact Silver and Gold counts, which sit on plain arrows only, so they never change how the level is solved.

**Shared checker rules** (verified for every level 61+):
- at most 2 start moves, depth ≥ 8 and decisions ≥ 4;
- all four directions, with no direction above 45%;
- spinners are never decorative;
- similarity below 60%.

The lesson levels 76–79 use their own lesson shape instead.

**L98 is the hardest Magnet level** on both scores: 48.9 / 44.4, against the next hardest, L96, at 41.9 / 37.4. **L100 stays the era finale:** structural 54.5, the hardest level in 76–100.

## Chapter difficulty (approved decision 4)

| | Chapter 8 (71–80) | Chapter 9 (81–90) | Chapter 10 (91–100) |
|---|---|---|---|
| Full chapter average | 33.1 | 28.2 | 39.2 |
| Magnet levels only | 8.6 (76–79) | 25.3 (81–89) | 36.0 (91–99) |

- On full-chapter averages, Chapter 9 sits below Chapter 8. That is because Chapter 8 now ends with four lesson levels plus the unchanged dense Level 80.
- The approved exception is one named check, `MAGNET_ARC_CHAPTER_CHECK`, in `tools/verify_levels.gd`. It compares Magnet levels only (25.3 > 8.6: pass).
- Every other chapter check runs unchanged, and both averages are printed.

## Gameplay indicators (human-solvability audit)

`tools/human_audit.gd --from=75 --to=100` builds the complete reachable state graph with the game's own rules. Undo, the Hammer and hints are excluded.

Columns:
- **Habit:** a player who plays calm moves freely and never looks ahead.
- **LA-k:** a player who looks k moves ahead. Neither model uses Undo or hearts, so these are strict lower bounds for a real player.
- **Risky:** solution steps where a wrong choice is possible.
- **Forced:** steps with exactly one safe move among several.
- **Trap share:** the share of choices that lose.
- **Dead-end:** moves still playable after a fatal move.
- **Win:** winnable states out of all states.

| # | Habit | LA-2 | LA-4 | LA-8 | Len | Risky | Forced | Trap share | Dead-end | Win |
|---|---|---|---|---|---|---|---|---|---|---|
| 75 | 25% | 0% | 0% | 0% | 23 | 14 | 6 | 67% | 13.8 | 137/284 |
| 76 | 100% | 100% | 100% | 100% | 7 | 0 | 0 | 0% | 0 | 16/16 |
| 77 | 94% | 100% | 100% | 100% | 9 | 0 | 0 | 1% | 2 | 22/24 |
| 78 | 100% | 75% | 83% | 100% | 10 | 2 | 0 | 11% | 5.7 | 43/55 |
| 79 | 100% | 33% | 67% | 100% | 12 | 3 | 0 | 27% | 4.8 | 30/47 |
| **80** | **6%** | **1%** | **1%** | **10%** | 23 | 14 | 10 | 43% | 8.5 | 267/282 |
| 81 | 100% | 82% | 99% | 100% | 15 | 4 | 1 | 7% | 3.6 | 142/154 |
| 82 | 100% | 53% | 100% | 100% | 16 | 4 | 4 | 25% | 2.5 | 28/32 |
| 83 | 12% | 69% | 94% | 100% | 16 | 6 | 6 | 19% | 2.7 | 43/49 |
| 84 | 13% | 4% | 8% | 44% | 17 | 7 | 7 | 56% | 6.5 | 66/141 |
| 85 | 100% | 64% | 100% | 100% | 15 | 4 | 1 | 13% | 3.4 | 86/94 |
| 86 | 10% | 1% | 2% | 22% | 17 | 6 | 1 | 65% | 7.5 | 151/313 |
| 87 | 17% | 1% | 1% | 34% | 17 | 6 | 3 | 41% | 6.1 | 75/121 |
| 88 | 100% | 4% | 10% | 73% | 18 | 9 | 8 | 39% | 6.1 | 82/117 |
| 89 | 24% | 2% | 2% | 3% | 18 | 9 | 6 | 42% | 8.0 | 99/165 |
| **90** | 7% | 9% | 20% | 56% | 24 | 14 | 13 | 41% | 5.9 | 180/214 |
| 91 | 100% | 4% | 10% | 82% | 18 | 9 | 5 | 44% | 6.0 | 56/82 |
| 92 | 55% | 5% | 6% | 27% | 19 | 10 | 4 | 28% | 8.5 | 339/379 |
| 93 | 50% | 0% | 1% | 1% | 20 | 10 | 7 | 49% | 12.6 | 238/292 |
| 94 | 49% | 12% | 14% | 19% | 19 | 11 | 3 | 27% | 9.5 | 309/502 |
| 95 | 1% | 0% | 0% | 1% | 19 | 11 | 4 | 78% | 6.3 | 108/389 |
| 96 | 48% | 2% | 2% | 3% | 20 | 14 | 3 | 55% | 9.7 | 706/1196 |
| 97 | 100% | 96% | 100% | 100% | 18 | 5 | 1 | 1% | 4.1 | 69/75 |
| 98 | 3% | 0% | 1% | 8% | 20 | 16 | 10 | 68% | 6.4 | 471/946 |
| 99 | 51% | 43% | 51% | 62% | 18 | 11 | 1 | 20% | 5.5 | 352/442 |
| **100** | 8% | 1% | 1% | 0% | 24 | 21 | 6 | 55% | 9.1 | 581/810 |

All 22 levels are solvable, and every reachable state graph is complete and finite.

## Transitions (approved requirement: assess, do not change 80)

- **75 → 76:** a deliberate reset to an easy lesson, as at every arc start (151, 176, 201, …). Card, then lesson: verified headless and in the browser.
- **79 → 80: the largest jump in the campaign.**
  - D rises from 15.4 to 50.7.
  - The habit player's win rate falls from 100% to 6%; the 4-move look-ahead player's from 67% to 1%.
  - The solution doubles from 12 to 23 moves.
  - Level 80 has no Magnet, so the player meets a dense spinner board straight after three gentle lessons.
  - Mitigations already in place: 3 hearts, Undo, SHOW A MOVE, and the Hammer.
  - This is the main risk to watch in human testing. Fixes only if testers stall, all outside Level 80: make 79 slightly harder, or end Chapter 8's lessons at 78.
- **89 → 90:** 32.8 → 54.2. A similar but smaller jump, because 81–89 have already built spinner skill. Gameplay indicators: 89 is already hard for the look-ahead models (LA-4 2%). Moderate risk.
- **98 → 99 → 100:** 48.9 → 34.4 → 67.7. 99 is a deliberate short breath before the era finale. L100 keeps its role as the hardest and final level of the era.

## Hints (SHOW A MOVE)

`tools/magnet_hint_perf.gd`, desktop CPU: the start position plus every position of 40 random playouts per level, 11,000+ positions including lost ones.

- Worst: 67.3 ms (L98). Median below 2 ms on every level.
- The Solver gave up 0 times.
- L98: start 47 ms, p95 47 ms.
- In the browser (WebAssembly in Chromium, CPU rendering, iPhone viewport), SHOW A MOVE on 76/88/95/98/99 showed its block 173–323 ms after the tap. That time includes polling and the frame.

**How this was achieved:** the Solver's "safe greedy move" is sound only away from magnets. Blocks only ever move into magnet start cells, so a block outside those cells, their neighbours and every magnet back line can still be taken greedily. Before this change, hints on magnet boards took up to 16 s.

## Tests

| Test | Covers |
|---|---|
| `tools/verify_levels.gd` | all 300 levels solvable with campaign rules; the Magnet rules ("NOT NECESSARY", "NEVER PULLS", lesson shape, only in 76–99, not 80/90); `MAGNET_ARC_CHAPTER_CHECK`; L98 hardest |
| `tools/MagnetCheck.tscn` | 68 checks: gating, validation, rules, Solver (fuzz against exhaustive search), lab, campaign (every magnet smash agrees with `hammer_safe`, Undo), real game (card → lesson → pull → saved) |
| `tools/magnet_campaign_build.gd` (no arguments: verify) | every board meets its spec and idea |
| `tools/magnet_hint_perf.gd` | hint timing |
| `tools/web_magnet_campaign_test.mjs` | the exported game in Chromium at iPhone size with real touches: the 76 card, then the lesson followed by touch until the pull; Undo; Restart; no repeat after reload; hint timing; the Hammer on a magnet (no pull, Undo); 79→80, 89→90, 99→100; QA jump `?experiencelab=76` |

The Experience Lab mirrors levels 1–200 byte-for-byte, including the new 76–99.

Browser tests only (no effect on the Friend Test build, where `player_build` is set): in dev and QA builds, `window.chainEscapeState` now also refreshes after each tap, Undo, Hint and Hammer. It additionally lists block positions, magnets and the Undo, Hint, Hammer and Restart button positions.

## Regression (clean checkout of `37540d1`; test fixes re-run on `27f83f4`)

**No-change goldens, `beca155` vs new:**
- All **278 protected levels** (1–75, 80, 90, 100–300) are byte-identical: Solver solutions, analysis, first hint and every move state.
- The Portal, Sequence and Movable lab boards are byte-identical too.

**Headless suites:**
- Unit tests: 33,697 checks, 0 failures.
- All pass: verifier, friend generator (493 checks), Magnet build, armor audit, MagnetCheck, Era3ProdCheck (168 board keys), PortalProdCheck, Twins, Opening Lab, Social, Friend, Recipient, Lock, VH, Portal, Sequence, Movable, Music.

**QA checkpoint sequence: 41/41 pass.** Coverage:
- every 25-level checkpoint from 50 to 275, fresh and resumed;
- the 50 edge cases;
- lesson and transition levels 13, 76–81, 89–91, 98, 99, 151, 176, 201, 226, 251 and 300.

**Browser tests, all pass:**

| Group | Results |
|---|---|
| Builds | Magnet campaign 36/36, Web QA 53/53, Friend Test 25/25, Magnet lab 21/21 |
| Campaign and labs | milestone fit 15/15, Experience Lab, Era 3, Portal arc, Twins 44/44, Opening Lab |
| UI and saves | Level Select (24), audio (75), persistence (47) |
| Friend and social | Friend flow 30/30, Friend Challenge route 14/14, mechanic-lab pages (10, 11, 12), recipient 33/33, share options 14/14, share-test page 28/28, VH-test page 17/17 |
| Backend | contract test (mock) 40/40 |

**Three suites needed test-only updates:**

| Suite | What was outdated | Fixed in |
|---|---|---|
| Playtest (300 levels) | did not expect the Magnet card at 76 | `e99d0de` |
| ExperienceLabCheck | compared lab 76–99 with the pre-freeze archive instead of production; its Hammer sampler pulled on a smash | `d0b7f62` |
| Soak | gave up after 4 s waiting for the Level 200 card, which follows the Phase 1 milestone overlay and stamp | `27f83f4` |

- The Soak timeout is **not related to Magnets**: Soak fails the same way on `beca155`.
- All three suites pass after their fixes.

## Final cleanup: four inert Magnets (after the real-iPhone QA)

On a real iPhone, the tester noticed that two Magnets seemed to do nothing. `tools/magnet_pull_audit.gd` walks the complete reachable state graph of every Magnet level. It found four Magnets that could **never pull**, in any reachable state. Each one became a plain arrow, by removing one `*` and nothing else:

| Level | Cell (col,row) | Before | After | Why it never pulled |
|---|---|---|---|---|
| 78 | (5,0) top row | `Yv*` | `Yv` | faces down from the top edge: nothing can ever be behind it |
| 93 | (3,6) bottom row | `R^*` | `R^` | faces up from the bottom edge: nothing can ever be behind it |
| 94 | (3,2) | `B>*` | `B>` | the blocks behind it always have to leave before it can |
| 96 | (0,4) | `Y^*` | `Y^` | the blocks behind it always have to leave before it can |

**The puzzles are unchanged.** For each of the four levels, the version with that Magnet as a plain arrow has exactly the same reachable states, moves and winnable states. The simulated players' win rates are identical too. Some difficulty scores move slightly, because the scorer had counted the dead Magnet as a possible decision:

| Level | Difficulty | Decisions |
|---|---|---|
| 78 | 9.9 → 8.0 | 2 → 1 |
| 93 | 35.0 → 35.6 | unchanged |

The Chapter 8 Magnet-only average moves from 9.1 to 8.6, and the Chapter 8–9 check still passes. Names, Silver/Gold rewards and every other block stay where they were. `tools/magnet_campaign_build.gd` now keeps each reward on its own cell when it rewrites a level.

**New rule.** Every Magnet must be able to pull on at least one winning line: from a winnable state, the Magnet escapes, pulls a block, and the board is still winnable.
- It does not have to pull in every solution, so optional but working Magnets pass.
- The rule lives in `tools/magnet_pull_rule.gd`.
- Three places enforce it: `tools/verify_levels.gd` ("MAGNET AT (c,r) NEVER PULLS ON A WINNING LINE"), `tools/magnet_campaign_build.gd`, and `tools/MagnetCheck.tscn`. MagnetCheck also checks that the rule still flags exactly the four former inert Magnets.
- All 33 remaining Magnets pass.
