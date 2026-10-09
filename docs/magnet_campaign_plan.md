# Magnet campaign integration: Levels 76–99 (plan, awaiting approval)

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

### Hammer: a conflict with the existing convention (needs your decision)
- **Existing convention** (README §Hammer, v0.6.4): the Hammer removes a block "exactly as an escape removes a block". Adjacent spinners turn, hidden arrows are revealed, and locks, switches and gates react; a smashed switch even fires.
- **Exceptions:** Twins (the smash removes one twin and breaks the bond, so the pair's special move does not happen) and Movable (never a target).
- **The conflict:** "Hammer removes a Magnet without pulling" is therefore **not** the general convention. It matches the Twins precedent ("the Hammer never performs a mechanic's special move"), but not the switch precedent ("the Hammer fires it").

**Recommendation: no pull on a smash**, as you proposed:
- **Predictable rescue:** the Hammer should never move an unrelated block across the board, and a pull triggered by a rescue tool would surprise players.
- **Twins precedent:** Twins is the closest analogue, a block whose special move involves another block.
- **No side effects:** the spinner neighbour event still happens, exactly as for any smash, so nothing else changes.
- **Safety check uses the same rule:** `Solver.hammer_safe` would simulate the no-pull removal (`BoardModel.remove(id, pull = false)`), so the Hammer still refuses only smashes that would make the level unsolvable.
- **A message on smash:** "Magnet smashed - nothing is pulled" (2.6 s), like the Twins "Bond broken" line.

The alternative (smash = escape, the pull happens) is simpler in code but less predictable. **Please confirm the no-pull rule.**

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
| 80 | Dark Matter | *see the decision below* | Chapter 8 finale (mystery blocks today) | 1/0 |
| 81 | Summit Path | 7×6, about 13, 1 magnet + 2 spinners | **Magnet + Spinner:** the magnet's escape turns the spinner beside it, away from the block it pulls in (lab B1 idea, larger). | 1/1 |
| 82 | Thin Air | 7×7, about 14 | The pulled block **is** a spinner: it is turned by the magnet's escape first, then lands. | 0/0 |
| 83 | Ridge Line | 7×6, about 16 | Spinner timing: let a neighbour turn the spinner before the pull, or the pulled block lands facing a wall. | 1/1 |
| 84 | Iron Crown | 7×7, about 16 | Two escapes beside one spinner decide its direction when it is pulled (lab C1 idea, gentler). | 0/0 |
| 85 | Avalanche *(b)* | 7×6, about 16 | **Breather:** a spinner board where the magnet only shortens the route. | 1/0 |
| 86 | Glacier | 7×7, about 17, 2 magnets | **Order of escape:** a decoy sits nearest each magnet; clear the decoys in the right order. | 1/1 |
| 87 | Stormwatch | 7×6, about 17 | "Too early": the magnet is free from the start, but pulling now drops a block into a lane you still need. | 0/0 |
| 88 | High Pass | 7×6, about 18, 2 magnets | **Pull chain:** a magnet pulls another magnet into place, which then pulls the next block. | 1/1 |
| 89 | Keystone | 7×7, about 18 | Crossing lines: two magnets whose pull lines cross; one order works. | 0/0 |
| 90 | Eclipse Peak | *see the decision below* | Chapter 9 finale (mystery blocks today) | 1/0 |
| 91 | Grandmaster | 7×7, about 18, 2 magnets | Facing magnets: two magnets in one line; which one leaves first decides which pulls. | 1/1 |
| 92 | Checkmate | 7×7, about 19 | "Wait for it": a magnet's pull is only safe as the last move of a spinner sequence. | 0/0 |
| 93 | Gordian Knot | 7×7, about 20, 2–3 magnets + spinners | **Rich combination:** chain pulls and spinner timing together. | 1/1 |
| 94 | Clockwork Crown | 7×7, about 20 | The approved ALT / PATTERN spinner symbols with a magnet: the pull lands a block beside a patterned spinner. | 0/0 |
| 95 | Paradox | 7×7, about 19 | Two magnets, each one the other's decoy. | 1/0 |
| 96 | Endgame | 7×7, about 20 | **Challenge:** two visible traps (lab C1 standard). | 1/1 |
| 97 | Apex *(b)* | 7×7, about 18 | **Breather** before the climax: a satisfying long chain of pulls, few traps. | 0/0 |
| 98 | Zenith | 7×6, about 20, 3 magnets | **Hardest Magnet level:** a full plan from the first tap. | 1/1 |
| 99 | Last Light | 7×6, about 18 | **Arc finale,** slightly easier than 98: every Magnet idea once more, then a clean run into The Master. | 0/0 |

**Decision: Levels 80 and 90 (mystery).** Both currently have hidden arrows (4 and 5), and Level 100 has 3. The Solver's "still hidden" rule assumes blocks never move, so magnets and hidden blocks can't share a board without extra engine work.
- **Option A (recommended):** keep 80 "Dark Matter" and 90 "Eclipse Peak" **unchanged**, as the Chapter-finale mystery breathers. That keeps mystery practice before Level 100 and means 22 new magnet levels.
- **Option B:** redesign them as magnet levels without hidden blocks (24 new). Mystery blocks then last appear at 60-something before Level 100.
- **Option C:** extend the engine so hidden and magnet blocks can mix. The Solver would recompute neighbours dynamically, at higher risk.

**Continuity**
- **Level 75** (6×6, 23 blocks, spinners) leads into a small, friendly lesson at 76. That is the usual dip at a new mechanic, like 101, 151 and 176.
- **Level 100** "The Master" stays unchanged and magnet-free. Its hint, "Every rule you have learned", is then not literally true for Magnet. Level 100 is protected, so I am flagging this, not changing it.

## 5. Expected difficulty progression
Measured with the existing proxies (random-tapper win rate, look-ahead player, losing first moves, minimum moves). These are targets; the human test decides.

| Levels | Random tapper wins | Losing first moves | Feel |
|---|---|---|---|
| 76–78 | ≥ 70% (76: 100%) | 0 | Learn by doing |
| 79 | 40–70% | 1 (visible) | First real choice |
| 81–85 | 25–50% | 1–2 | Familiar spinners, new twist |
| 86–92 | 10–30% | 1–3 | Order matters |
| 93–98 | 4–15% | 2–3 | Plan ahead (lab C1, 4.7%, is the top) |
| 99 | 10–20% | 1–2 | Satisfying finale |

**Checker conflict:** the rule "each Chapter's average difficulty ≥ previous + 2" (today C7 46.1, C8 49.9, C9 53.3, C10 58.8) cannot hold with a gentle introduction at 76–79. I propose a documented **Magnet arc exception**, like the existing arc starts at 151, 176 and 201:
- C8 is exempt;
- C9 and C10 must still rise;
- C10 must stay below Chapter 11's lesson-era band.

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
| **Levels** | `levels/level_76.json` … `level_99.json` (22 or 24 of them); `data/dev/pre_magnet_76_99/` (archive); `data/dev/experience_lab/level_76..99.json` (mirror) |
| **Engine** | `scripts/core/level_manager.gd` (campaign token); `board_model.gd` (`remove(id, pull)`); `solver.gd` (`hammer_safe` no-pull, metrics); `scripts/core/level_analysis.gd` |
| **Game** | `scripts/game_manager.gd`: the escape plays the pull, the lesson, the intro, the Hammer message, `MECHANIC_INTRO_FROM`, Chapter news "NEW: Magnets" on the Chapter 8 card. `scripts/ui/mechanic_intro.gd` (Magnet card); `scripts/dev/experience_lab.gd` (lessons table) |
| **Data** | `data/classic_board_keys.json` (regenerated) |
| **Tests and tools** | `tools/verify_levels.gd`, `classic_board_keys.gd`, `playtest.gd`, `experience_lab_check.gd`, `experience_lab_qa_check.gd`, `run_tests.gd`, `friend_generator_test.gd`, `era3_prod_check.gd` (key count), `magnet_check.gd`, a new `tools/magnet_campaign_build.gd` (design and verification of the boards), web tests |
| **Docs** | `docs/magnet_campaign.md`, README |

**Not touched:** Levels 1–75, 100–300, `economy.json`, `chapters.json`, rewards and achievements, the save format, audio and persistence, the Friend Challenge format, the Friend Test build.

## 8. Regression and human-QA plan
**Automated**
- **Every level:** the level checker (all 300, with the new Magnet rules); Playtest clears all 300; `MagnetCheck` (plus campaign gating, the Hammer no-pull case, and `hammer_safe` agreement); the Solver fuzz.
- **Tutorial and checkpoints:** a QA check at 76 (card, then lesson, finger, end on a pull) and at 80, 90, 99 and 100; the QA checkpoint sequence.
- **Builds:** Friend generator / Era 3 key checks; the Friend Test and Web QA isolation tests.
- **Browser:** the full suite, plus a new Magnet campaign test (QA jump to 76, lesson by real touches, a pull, Undo, Hammer on a magnet, hint), and performance numbers for 76–99 on the Web build.

**Human QA (real iPhone, through the isolated QA build, `?experiencelab=76`)**
1. **Level 76:** without help, does the player understand from the card plus the finger? Time and taps.
2. **76 → 99 in order:** per level, time, restarts, hints, a difficulty rating and "was any loss unfair?".
3. **Specific checks:** the pull line is readable on 7×7, the Hammer on a magnet behaves as expected, and nothing is clipped.
4. **Independent testers:** ideally at least two, playing separately (the lab test was one shared session).

## 9. Delivery after approval
Implement → full regression → an isolated QA build ZIP (the "Web QA" preset: checkpoint jumps incl. 76; not the Friend Test build) → report → stop. Nothing is deployed and the public Friend Test build is not replaced without explicit approval.
