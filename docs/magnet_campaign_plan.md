# Magnet campaign integration: Levels 76–99 (revised plan, awaiting approval)

**Status:** plan only. No production level file has been changed. Every level in `levels/` is identical to the frozen baseline `4bfa9bd`.

## 1. Baseline protection
- **Archive:** before any level file changes, current Levels 76–99 are copied to `data/dev/pre_magnet_76_99/`, the same way `data/dev/pre_freeze_production/` holds the pre-freeze boards.
- **Tag:** the last pre-integration commit gets a local tag, `baseline-1-300-pre-magnet`. It is not pushed without permission.
- **Commits:** all work stays on this branch, in separate commits for engine, tutorial, levels and tests, so each can be reverted on its own.

## 2. Mechanic and interaction specification (campaign)
The validated lab rule is unchanged:
1. A magnet escapes like any arrow. Its escape effects come first: adjacent spinners turn, and a switch fires (it can't carry a gate link).
2. Then the first block straight behind it slides into the cell it left, keeping its own arrow.
3. A gate, Movable crate or twin behind it stops the pull. With nothing behind it, nothing moves.

The dotted line and ring preview that exact pull (`BoardModel.pull_target`, the same function the escape uses).

| System | Campaign behaviour |
|---|---|
| **Token** | `*` is accepted in campaign level files (`parse_level(..., campaign = true)`), like the Twins token. Social, Friend Challenge and recipient parsing still reject it as a bad token. |
| **Undo / Restart** | Undo uses the snapshot; Board `sync_to` moves a pulled block back (already validated). Restart rebuilds the level. |
| **Show a Move / hints** | Solver `recommend_move` covers pulls; the finger and hint never point at a losing move. |
| **Completion** | A magnet escape is an escape: chain, score, stars and Silver/Gold collection all work as usual. A pulled reward block keeps its reward. |
| **Spinners** | The validated order: escape → adjacent spinners turn (including a spinner about to be pulled) → pull. A pulled block arriving next to a spinner turns nothing, because only an escape is a neighbour event. |
| **Not combined (1–100)** | Hidden (mystery) blocks, portals, Movable crates, Sequence, Twins and Armor never share a board with a magnet in 76–99, as in the lab. Switches and gates don't exist before 101. |

### Hammer (decided)
**A smashed Magnet does not pull.**

All other removal side effects stay exactly as for every smash: adjacent spinners turn, and locks or gates react. The game shows the line "Magnet smashed - nothing is pulled", like the Twins "Bond broken" line.

The same rule is implemented everywhere:
- **`BoardModel.remove(id, pull := true)`:** a smash passes `pull = false`.
- **`Solver.hammer_safe`:** simulates the smash with `remove(id, false)`, so the Hammer still refuses only smashes that would make the level unsolvable.
- **Undo:** restores the snapshot, so the magnet returns.
- **Elsewhere:** the Solver itself never models the Hammer (hints and solutions are escapes only).

**Tests:**
- smashing a magnet moves nothing and turns its neighbour spinners;
- `hammer_safe` agrees with the actual smash on every magnet level;
- Undo brings the magnet back with the same preview.

## 3. Tutorial: Level 76 (permanent rule, `docs/tutorial_rule.md`)
1. A **NEW MECHANIC: MAGNET** card, using `MechanicIntro`, the same card as Portal, Sequence and Movable. Its animation shows the magnet escaping and the block behind it sliding up into its place. It shows once per save (`intro_magnet`) and never to a player already past 76.
2. The **finger lesson** `76: "magnet"` follows:
   - the magnet and its pull target are bracketed;
   - the finger points at a magnet escape that keeps the level solvable;
   - the line reads "MAGNET: when it leaves, the block on the dotted line slides into its place - tap it", or "Clear the magnet's way first".
3. It ends when a magnet escape pulls a block, with the line "Pulled! The block behind took the magnet's place".
4. On a blocked tap, the existing message stays and the lesson returns afterwards, as at 201 / 226 / 251.

## 4. Level-by-level design plan
These rules hold for every level:
- **Names and rewards kept:** each level keeps its current name and its exact Silver/Gold reward blocks, 14 Silver and 9 Gold across 76–99. That keeps coin income and Chapter rewards unchanged.
- **Magnet necessary:** every magnet level is unsolvable with its magnets made plain arrows. The exceptions are the breathers, marked *(b)*.
- **Visible traps:** every losing move is explainable from the dotted lines and arrows on screen.
- **Board size:** 6×6 to 7×7, matching Chapters 8–10.

| Lvl | Name (kept) | Board | Role and idea | S/G |
|---|---|---|---|---|
| **76** | Dynamo | 6×6, about 7 blocks, 1 magnet | **Lesson.** Two blocks face each other and can never leave; the magnet pulls one free. No losing move. Easy enough to clear without a hint. | 1/0 |
| 77 | Feedback | 6×6, about 9, 1 magnet | The pull can travel any distance: the block behind slides several cells. | 0/0 |
| 78 | Wavelength | 6×6, about 10, 2 magnets | One magnet pulls; the other has nothing behind it, so nothing moves. Reading the line. | 1/1 |
| 79 | Hyperloop | 7×6, about 12, 1 magnet | First retarget: clear the nearer block so the line moves to the right one. One visible trap. | 0/0 |
| 80 | Dark Matter | **unchanged** (approved mystery board) | Chapter 8 finale breather | 1/0 |
| 81 | Summit Path | 7×6, about 13, 1 magnet + 2 spinners | **Magnet + Spinner:** the magnet's escape turns the spinner beside it, away from the block it pulls in (lab B1 idea, larger). | 1/1 |
| 82 | Thin Air | 7×7, about 14 | The pulled block **is** a spinner: it is turned by the magnet's escape first, then lands. | 0/0 |
| 83 | Ridge Line | 7×6, about 16 | Spinner timing: let a neighbour turn the spinner before the pull, or the pulled block lands facing a wall. | 1/1 |
| 84 | Iron Crown | 7×7, about 16 | Two escapes beside one spinner decide its direction when it is pulled (lab C1 idea, gentler). | 0/0 |
| 85 | Avalanche *(b)* | 7×6, about 16 | **Breather:** a spinner board where the magnet only shortens the route. | 1/0 |
| 86 | Glacier | 7×7, about 17, 2 magnets | **Order of escape:** a decoy sits nearest each magnet; clear the decoys in the right order. | 1/1 |
| 87 | Stormwatch | 7×6, about 17 | "Too early": the magnet is free from the start, but pulling now drops a block into a lane you still need. | 0/0 |
| 88 | High Pass | 7×6, about 18, 2 magnets | **Pull chain:** a magnet pulls another magnet into place, which then pulls the next block. | 1/1 |
| 89 | Keystone | 7×7, about 18 | Crossing lines: two magnets whose pull lines cross; one order works. | 0/0 |
| 90 | Eclipse Peak | **unchanged** (approved mystery board) | Chapter 9 finale breather | 1/0 |
| 91 | Grandmaster | 7×7, about 18, 2 magnets | Facing magnets: two magnets in one line; which one leaves first decides which pulls. | 1/1 |
| 92 | Checkmate | 7×7, about 19 | "Wait for it": a magnet's pull is only safe as the last move of a spinner sequence. | 0/0 |
| 93 | Gordian Knot | 7×7, about 20, 2–3 magnets + spinners | **Rich combination:** chain pulls and spinner timing together. | 1/1 |
| 94 | Clockwork Crown | 7×7, about 20 | The approved ALT / PATTERN spinner symbols with a magnet: the pull lands a block beside a patterned spinner. | 0/0 |
| 95 | Paradox | 7×7, about 19 | Two magnets, each one the other's decoy. | 1/0 |
| 96 | Endgame | 7×7, about 20 | **Challenge:** two visible traps (lab C1 standard). | 1/1 |
| 97 | Apex *(b)* | 7×7, about 18 | **Breather** before the climax: a satisfying long chain of pulls, few traps. | 0/0 |
| 98 | Zenith | 7×6, about 20, 3 magnets | **Hardest Magnet level:** a full plan from the first tap. | 1/1 |
| 99 | Last Light | 7×6, about 18 | **Arc finale,** slightly easier than 98: every Magnet idea once more, then a clean run into The Master. | 0/0 |

**Levels 80 and 90 (decided, Option A):** both stay byte-identical, as the approved mystery boards and chapter-finale breathers. **22 levels are redesigned:** 76–79, 81–89 and 91–99.

**Continuity**
- **Level 75** (6×6, 23 blocks, spinners) leads into a small, friendly lesson at 76. That is the usual dip at a new mechanic, like 101, 151 and 176.
- **Level 100** "The Master" stays unchanged and magnet-free. Its hint, "Every rule you have learned", is then not literally true for Magnet. Level 100 is protected, so I am flagging this, not changing it.

## 5. Difficulty progression and Chapter averages

### How the checker scores difficulty
`LevelGenerator.difficulty`:

> blocks·0.15 + depth·0.6 + decisions·1.5 + traps·0.4 + losing start moves·1.0 + spinners·0.5 + (4 − start moves)·0.5 + rule terms

The score is driven mostly by **size**: blocks, spinners and solution depth.

| Board | Score | Human verdict |
|---|---|---|
| Lab A1 | 2.5 | EASY |
| Lab B1 | 10.1 | EASY |
| Lab C1 | 11.6 | HARD (three starts, one Show a Move, "a lot of planning") |
| Current 76–99 | 50–61 | dense 20–30-block spinner boards |
| Level 100 | 67.7 (structural 54.5) | the era's hardest, as the checker requires |

The formula reproduces the measured lab scores exactly, which calibrates the predictions below. **It has no Magnet term, and I don't propose adding one.**

### Predicted scores (from each level's design targets)

| | | | | | | | | | |
|---|---|---|---|---|---|---|---|---|---|
| **C8** | 76: 2.8 | 77: 6.8 | 78: 9.3 | 79: 13.1 | *80: 50.7 (unchanged)* | | | | |
| **C9** | 81: 20.0 | 82: 22.1 | 83: 23.7 | 84: 25.6 | 85: 16.2 (b) | 86: 28.6 | 87: 31.6 | 88: 31.3 | 89: 34.2 |
| | *90: 54.2 (unchanged)* | | | | | | | | |
| **C10** | 91: 35.7 | 92: 37.8 | 93: 40.4 | 94: 42.4 | 95: 40.7 | 96: 43.3 | 97: 29.0 (b) | 98: 47.7 | 99: 38.2 |
| | *100: 67.7 (unchanged)* | | | | | | | | |

The targets assume:
- **Blocks:** 7 (76) → 16–19 (C9) → 20–22 (C10).
- **Spinners:** 0 → 4–5 → 6.
- **Decision points:** 0 → 5–10 → 10–14.

Level 98 is the arc's hardest (47.7). Level 100 stays the era's hardest by a wide margin, on both difficulty (67.7) and structural score (54.5), so the Master rule holds unchanged.

### Chapter averages (unchanged 71–75, 80, 90 and 100 included)

| | C7 | C8 | C9 | C10 |
|---|---|---|---|---|
| Today | 46.1 | 49.9 | 53.3 | 58.8 |
| **Plan** | 46.1 | **32.9** | **28.8** | **42.3** |
| Plan, Magnet levels only | — | 8.0 (76–79) | 25.9 (81–89) | 39.5 (91–99) |

| Rule (C ≥ previous + 2.0) | Plan | Result |
|---|---|---|
| C8 vs C7 | 32.9 vs 46.1 | **fails**; covered by the existing new-mechanic rule (below) |
| C9 vs C8 | 28.8 vs 32.9 | **fails by 6.1** |
| C10 vs C9 | 42.3 vs 28.8 | passes (+13.5) |

### Why each failure happens, and the exact remedy

**1. C8 vs C7.** The checker already lets a Chapter that holds a new mechanic's first level start its own curve (`ARC_STARTS` = 151, 176, 201, 226, 251: Armor, Twins, Portal, Sequence, Movable). Magnet is a new mechanic at 76, so adding **76 to `ARC_STARTS`** applies the established rule; no new exception is created.

Without it, Chapter 8 would need 48.1. Since 71–75 and 80 can't change, 76–79 would have to average **46**, i.e. 20+-block dense boards for the introduction itself, which contradicts the gentle lesson.

**2. C9 vs C8 is the only real exception, and it is narrow.** Chapter 8's average is held up by the six boards that must stay unchanged: 71–75 (48.4–50.0) and 80 (50.7). Those six alone average 49.5.

Meeting C9 ≥ C8 + 2 = 34.9 on full averages would need 81–89 to average **32.8**, against the planned 25.9. That would mean jumping from Level 79 (13.1) straight to about 30-point boards (20+ blocks, 8+ decisions) right after the lesson chapter. That is the steep, size-driven difficulty the human test warned against.

**Proposed exception, exactly sized:**
- **Scope:** only the C9 vs C8 comparison, and only because Chapter 8 mixes pre-arc boards with arc boards.
- **How it's measured:** both Chapters are compared on their **Magnet-arc levels only** (76–79 vs 81–89), excluding the unchanged 71–75 and 80 (and 90).
- **The bar stays the same:** C9 must still beat C8 by at least 2.0. The plan gives 25.9 vs 8.0, i.e. **+17.9**.
- **Nothing else changes:** C10 vs C9 stays a full-average check (+13.5), and every other Chapter and rule is untouched.
- **It is named in the checker** (`MAGNET_ARC_CHAPTER_CHECK`), with this justification in a comment and in the report output. It is not silent.

### What will be measured after the boards exist
The table above is a prediction from targets. After the boards are built, the checker prints the real per-level scores and averages, and the arc's ordering must hold:
- C8 < C9 < C10 on Magnet levels, each step at least +2;
- 98 is the hardest Magnet level, and 100 the hardest in the era;
- 85 and 97 are breathers (lower than their neighbours).

The random-tapper win rate and the look-ahead player are reported **only as secondary diagnostics**. The primary design checks are:
- **Magnet necessary:** unsolvable without magnets, except the breathers;
- **Every losing move explainable** from the board;
- **Decision points along the solution:** depth and decisions grow chapter by chapter;
- **Readable on iPhone**, and **human ratings** in QA.

## 6. Engine, Solver and performance risks
1. **Search size.** Magnet boards use the plain memoized search (no greedy "safe move" shortcut), so 7×7 boards with about 20 blocks can explode. The node limit (60,000) could abort a hint on a big board.
   - **Mitigation:** measure solve and hint time for every level (desktop and Web); keep magnet levels at 20 blocks or fewer; reject any level whose hint search aborts.
   - **Later, if needed:** a sound greedy rule for blocks that touch no magnet line or spinner.
2. **Hidden blocks.** Not supported with magnets (section 4 decision).
3. **The Hammer** needs the no-pull path in both `BoardModel` and `hammer_safe` (section 2).
4. **Analysis and checker.** `LevelAnalysis` and `verify_levels` need magnet metrics: necessity, losing moves, visible traps, the arc exception, "magnets only in 76–99", and no hidden blocks with magnets.
5. **Friend Challenge board keys.** The campaign board list (`data/classic_board_keys.json`) has to skip magnet levels, as it skips Twins (190 keys → about 168). The Friend generator rules are unchanged.
6. **Experience Lab.** Its Levels 1–200 have been byte-identical to production since the freeze, so the lab files for 76–99 would be updated to stay identical, and its checks with them.
7. **iPhone performance.** The magnet overlay redraws only while magnets are on the board; the pull is one slide. Each magnet level will be measured on the Web build: frame time, hint time, memory over a 76–99 session.

## 7. Files that would change (after approval)
| Area | Files |
|---|---|
| **Levels** | `levels/level_76..79, 81..89, 91..99.json` (22 files; **80 and 90 untouched**); `data/dev/pre_magnet_76_99/` (archive of the 22 replaced boards); `data/dev/experience_lab/` (the same 22, mirror) |
| **Engine** | `scripts/core/level_manager.gd` (campaign token); `board_model.gd` (`remove(id, pull)`); `solver.gd` (`hammer_safe` no-pull, metrics); `scripts/core/level_analysis.gd` |
| **Game** | `scripts/game_manager.gd`: the escape plays the pull, the lesson, the intro, the Hammer message, `MECHANIC_INTRO_FROM`, Chapter news "NEW: Magnets" on the Chapter 8 card. `scripts/ui/mechanic_intro.gd` (Magnet card); `scripts/dev/experience_lab.gd` (lessons table) |
| **Data** | `data/classic_board_keys.json` (regenerated) |
| **Tests and tools** | `tools/verify_levels.gd` (`ARC_STARTS` += 76, the named C9 Magnet-arc check, Magnet rules), `classic_board_keys.gd`, `playtest.gd`, `experience_lab_check.gd`, `experience_lab_qa_check.gd`, `run_tests.gd`, `friend_generator_test.gd`, `era3_prod_check.gd` (key count), `magnet_check.gd`, a new `tools/magnet_campaign_build.gd` (design and verification of the boards), web tests |
| **Docs** | `docs/magnet_campaign.md`, README |

**Not touched:** Levels 1–75, 80, 90, 100–300, `economy.json`, `chapters.json`, rewards and achievements, the save format, audio and persistence, the Friend Challenge format, the Friend Test build.

## 8. Regression and human-QA plan
**Automated**
- **Every level:** the level checker (all 300, with the new Magnet rules); Playtest clears all 300; `MagnetCheck` (plus campaign gating, the Hammer no-pull case, and `hammer_safe` agreement); the Solver fuzz.
- **Tutorial and checkpoints:** a QA check at 76 (card, then lesson, finger, end on a pull) and at 80, 90 (byte-identical), 99 and 100; the QA checkpoint sequence.
- **Builds:** Friend generator / Era 3 key checks; the Friend Test and Web QA isolation tests.
- **Browser:** the full suite, plus a new Magnet campaign test (QA jump to 76, lesson by real touches, a pull, Undo, Hammer on a magnet, hint), and performance numbers for 76–99 on the Web build.

**Human QA (real iPhone, through the isolated QA build, `?experiencelab=76`)**
1. **Level 76:** without help, does the player understand from the card plus the finger? Time and taps.
2. **76 → 99 in order:** per level, time, restarts, hints, a difficulty rating and "was any loss unfair?".
3. **Specific checks:** the pull line is readable on 7×7, the Hammer on a magnet behaves as expected, and nothing is clipped.
4. **Independent testers:** ideally at least two, playing separately (the lab test was one shared session).

## 9. Delivery after approval
Implement → full regression → an isolated QA build ZIP (the "Web QA" preset: checkpoint jumps incl. 76; not the Friend Test build) → report → stop. Nothing is deployed and the public Friend Test build is not replaced without explicit approval.
