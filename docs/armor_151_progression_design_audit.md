# Armor at 151? Progression design audit, Levels 151–175 (read only)

Nothing was changed: no code, level, lab, save or test. This is a design proposal, not an approved plan.

**Sources** (all read only, on production levels):
- the Armor code (`BoardModel`, `GameManager`, `BlockView`, `Board`, `LevelManager`);
- `tools/human_audit.gd`: the full state graph of every level 150–200;
- `tools/armor_audit.gd`;
- `tools/verify_levels.gd`: the "Diff" estimate;
- scratchpad heuristic players and solution walks.

**Calibration from earlier human tests:**
- 121–130 (Gate) and 131–150 were approved on iPhone.
- Those levels have dense "decoy" traps; a look-ahead-8 player wins 1–10% of games.

So low solver win rates alone are **not** evidence of unfairness. What matters is whether a fatal move *looks harmless*, as in 295.

## 1. Executive recommendation

**Recommend Option B, armor at 151, as an *interleaved relocation*.** It is feasible with almost no new content and stays within the evidence, but it needs a human test in the Experience Lab before anything is final.

**The plan:**
- Lab 151–170 keep the **same 20 production puzzles** (old 151–160 and old 161–170), reordered so Armor and Switch levels alternate.
- 155 (Mystery), 157, 160 (breather, Chapter end) and 170 (Chapter end) keep their slots.
- **Exactly one adaptation is proposed:** the first Armor level (old 161 "First Shell", moved to 151). Its post-lesson decoy keeps the intro heavier than any earlier mechanic intro.
- 171–175 and Milestone 175 are untouched.

**Why:**
1. **Armor is the safest mechanic to place right after a Milestone.**
   - In every level 161–200 a ram is never fatal.
   - No dead end ever leaves a shell that can't be cracked (`armor_audit`: 0 unsafe in 33 levels).
   - No level 150–200 has a fatal move that turns nothing (295 had 8).
2. **The move fixes the main experience risk found in the 131–160 audit.**
   - 151–159 are a repetitive Switch plateau; a "hold the switch" habit wins 7 of 9 levels 49–100% of the time.
   - The Armor block 161–170 is dense in the other direction: its best simple heuristic wins only 1–25%, and 5 of its 10 boards are 7×7.
   - Alternating the two gives novelty after 150 and spreads the hardest Armor levels out.
3. **The cost is low.** All new behaviour can be lab-only routing:
   - the lesson table;
   - the Chapter-card "NEW:" line;
   - the lab check's era rule;
   - plus one adapted board.

   Production 1–300 stays unchanged.

A **pure block swap** (161–170 ↔ 151–160) is *not* recommended:
- it would put the ten densest levels straight after Milestone 150;
- it would move the 160 breather to 170;
- the Switch plateau would just reappear at 161–169.

**Introducing Armor at 151 and then pausing it for nine levels** is also not recommended: players would forget it.

## 2. Verified Armor mechanics (from code)

**Rule** (`BoardModel.move_state` / `ram`):
- An armored block (`=` token, `BlockData.armored`) can't escape while shelled.
- A block whose lane runs **straight into** a shelled block is in state `"ram"`. Tapping it rams the shell:
  - the shell is removed (`armored = false`);
  - **the rammer stays in its cell**;
  - nothing is removed, so **no spinner turns and nothing is revealed**;
  - the cracked block then plays like any arrow.

**Free moves:**
- A ram is "a productive move, never a mistake" (`GameManager._ram`): no heart lost, the chain kept but earning nothing, Undo-able.
- Tapping a shelled block is a free explanation, not a mistake: "Armored - launch another block into it to crack the shell".

**Restrictions** (`LevelManager` validation):
- An armored block can't be a spinner, hidden, locked or a switch.
- It may still be a lock *key* by colour, and could in principle be a flip target or gate link. Levels 151–200 use neither: there are no Armor + link or Armor + flip blocks.

**Look** (`BlockView._draw_armor`, drawn above everything):
- a dark gunmetal casing over the face, with rivets;
- a black **bomb** with a lit fuse;
- a small white **direction chip** (bottom-right) showing where the block goes once free.

Two readability notes:
- **The direction chip is small**: about 13% of the cell radius.
- **The block's colour shows only as a ~7% rim around the casing.** It matters in 165, 167, 168 and 170, where the armored block's colour is a lock key.

**Ram feedback** (`Board.play_ram`): the rammer dashes into the shell, which cracks, followed by:
- fire, sparks, shell fragments and smoke;
- two shockwave rings and a screen pulse;
- the crack sound and a medium haptic.

**Lesson** (production `GameManager.LESSONS[161] = "armor"`):
- **Brackets** on the armored block and on the solution's first rammer.
- **The finger** shows SHOW A MOVE's (the Solver's) pick at every step.
- **Text while the next move isn't the ram:** "Armored: can't escape. Clear a path for the marked block to hit it".
- **Text when it is:** "Hit the armored block to break its shell".
- **The lesson ends on the first ram** with "Shell cracked! Now it moves like any other block".
- The level hint "New: ARMORED block. Launch another block into it to crack the shell." is replaced by the lesson, as at 121.
- A one-time tip covers players who skip ahead.

**Other production code tied to Level 161** (what a move must take into account):

| Where | What | Lab handling |
|---|---|---|
| `GameManager.LESSONS` | 161 → "armor" | The lab already uses its own table (`ExperienceLab.LESSONS`): add `151: "armor"` |
| `GameManager._chapter_news` | `[161, "Armored Blocks"]` puts "NEW: Armored Blocks" on Chapter 17's card | Needs a **lab-only override** (Chapter 16 instead) |
| `verify_levels.gd` | "ARMOR BEFORE 161" rule | Production only; the lab check needs its own era rule |
| `run_tests.gd`, `playtest.gd`, `level_generator.gd` | Production expectations at 161 | Unaffected (production unchanged) |

## 3. Existing Levels 151–175

**Columns:**
- **Diff:** production difficulty estimate.
- **Forced:** forced steps / solution length.
- **Trap:** solution steps that hold a fatal option.
- **Dev:** deviation survival.
- **Dead end:** typical / max moves still playable after a mistake.
- **Best rule:** best simple heuristic player.
  - **H1:** hold switches.
  - **HC:** hold switches, ram when possible, prefer taps that turn no spinner.

Every fatal move in this range is a switch firing or a spinner-turning escape, never a ram and never a plain escape.

| L | Name | Board | Mechanics | Diff | Forced | Trap | Dev | Dead end | Best rule | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| 151 | Plasma Veil | 6×6 / 19 | 2 switches, ALT/CCW, locks | 50.4 | 10/19 | 11 | .27 | 4.9 / 11 | HC 100% | most Undo-friendly; gentle |
| 152 | Flux | 6×7 / 20 | switch, Pattern, ALT, locks | 59.5 | 10/20 | 13 | .28 | 5.1 / 14 | 14% | two non-switch decoys |
| 153 | Coil | 6×6 / 21 | 2 switches, Pattern, ALT, locks | 60.2 | 15/21 | 17 | .10 | 9.0 / 14 | 0% | hardest Switch level of the range |
| 154 | Spark Gap | 6×6 / 18 | switch, Pattern, ALT/CCW, locks | 56.6 | 12/18 | 13 | .23 | 6.3 / 12 | H1 100% | |
| 155 | Resonance ✦ | 6×6 / 19 | hidden 3, switch, gate, ALT, locks | 60.9 | 12/18 | 14 | .18 | 9.5 / 16 | H1 100% | Mystery |
| 156 | Live Wire | 6×7 / 19 | 2 switches, Pattern, CCW, locks | 60.4 | 9/19 | 14 | .25 | 9.7 / 16 | 51% | |
| 157 | Discharge | 6×7 / 23 | 2 switches, Pattern, CCW, locks | 61.1 | 8/23 | 14 | .55 | 9.1 / 20 | 51% | most flexible |
| 158 | Field Lines | 6×6 / 22 | 2 switches (required), locks | 57.8 | 4/22 | 13 | .43 | 10.7 / 16 | 49% | |
| 159 | Ionic Drift | 6×6 / 19 | 2 switches, Pattern, locks | 59.1 | 9/19 | 14 | .33 | 6.4 / 13 | HC 49% | |
| 160 | Plasma Core ✦ | 6×7 / 19 | hidden 3, switch, gate, locks | 47.8 | 5/18 | 10 | .41 | 6.3 / 11 | H1 100% | Chapter-end breather |
| 161 | First Shell | 6×7 / 21 | **Armor ×1** (lesson), CW/CCW/ALT, locks | 57.3 | 5/22 | 18 | .46 | 7.9 / 15 | 10% | ram at move 9 ends the lesson; decoy `Gv`(2,6) is fatal at moves 1–16 |
| 162 | Hard Case | 6×7 / 21 | Armor ×1, ALT/CCW, locks | 59.8 | 12/22 | 18 | .21 | 8.6 / 19 | 1% | a **spinner** is the rammer (move 2) |
| 163 | Crystal Ward | **7×7** / 23 | Armor ×1, CW×5/CCW, locks | 66.4 | 21/24 | 22 | .08 | 11.5 / 22 | 12% | decoy `B^`(1,0) fatal at moves 1–22 |
| 164 | Cracked Glass | **7×7** / 21 | Armor ×1, ALT/CCW, locks | 62.3 | 20/22 | 20 | .05 | 10.5 / 20 | 12% | very narrow |
| 165 | Deep Shard | **7×7** / 22 | Armor ×1 (**a lock key**), ALT, locks | 58.5 | 18/23 | 18 | .00 | 5.1 / 10 | 13% | most forgiving Armor level (look-ahead-8 wins 54%) |
| 166 | Quartz Wall | 6×7 / 22 | **Armor ×2**, Pattern, CCW, locks; hint "Cracking a shell is free - aim first, then clear." | 55.7 | 4/24 | 17 | .57 | 12.7 / 20 | 14% | flexible; second Armor lesson |
| 167 | Ice Vault | 6×7 / 22 | Armor ×2 (lock key), CCW, locks | 63.2 | 2/24 | 22 | .59 | 11.9 / 22 | 20% | flexible but long |
| 168 | Geode | **7×7** / 20 | Armor ×2 (lock key), CCW, locks | 57.2 | 8/22 | 18 | .36 | 11.1 / 17 | 25% | |
| 169 | Star Frost | **7×7** / 21 | Armor ×2, ALT/CCW, locks | 60.2 | 18/23 | 18 | .05 | 9.5 / 18 | 6% | narrow |
| 170 | Void Prism | 6×7 / 22 | Armor ×2 (lock key), ALT/CCW, locks | 66.1 | 13/24 | 21 | .25 | 12.1 / 21 | 13% | Chapter-end challenge |
| 171 | Nebula | 6×7 / 19 | Armor ×2 + switch + gate; hint "Switch, gate and shell: read every mark before you tap." | 59.2 | 1/20 | 17 | .56 | 10.7 / 18 | 6% | combination intro |
| 172 | Dark Matter | 7×7 / 20 | Armor ×2, switch, gate | **76.3** | 14/21 | 19 | .24 | 10.2 / 19 | H1 100% | estimate spike; yields to "hold the switch" |
| 173 | Crystal Orbit | 6×7 / 22 | Armor, switch, gate, Pattern | 64.9 | 8/22 | 15 | .46 | 7.4 / 15 | H1 100% | |
| 174 | Cold Star | 7×7 / 22 | Armor, switch, gate, Pattern | 52.8 | 12/22 | 13 | .48 | 4.3 / 8 | look-ahead-8 100% | pre-milestone breather |
| 175 | Shatter Point | 7×7 / 22 | Armor, switch, gate, Pattern, CCW | 66.1 | 13/22 | 15 | .25 | 11.0 / 18 | H1 100% | **Milestone** |

✦ = Mystery.

**What the audit shows:**
- **Armor itself never decides a loss.** Ramming whenever possible doesn't raise any heuristic's win rate. The difficulty in 161–170 comes from spinner face-offs and long persistent decoys, on bigger boards.
- **Armor's appeal is tactile and visual:** the bomb, the explosion and a free, satisfying move.
- **Armor's strategic layer is light:** aiming a rammer and choosing when to crack. The colour-key cases (165/167/168/170) are the most interesting interaction.
- **The Armor arc as built is steep:**
  - average Diff 60.7 versus 57.4 for Chapter 16;
  - 5 of its 10 boards are the era's first 7×7 boards (only Level 100 was 7×7 before);
  - 163/164/169 are forced on 78–91% of steps.

## 4. Option A vs Option B

| # | Criterion | A: Armor at 161 | B: Armor at 151 (interleaved) |
|---|---|---|---|
| 1 | Curiosity after Milestone 150 | 151 is another Switch level; nothing new until 161 | 151 opens with a new block and its lesson: strong post-Milestone hook |
| 2 | Perceived novelty | Last novelty: Pattern / Hidden return at 144/145, then 16 levels of the same toolkit | New mechanic at 151; new interactions (spinner as rammer, an Armor block as lock key) spread over 152–161 |
| 3 | Learning curve | Ten Armor levels in a row from 161, densest at 163/164/169 | Armor every other level; gentlest Armor levels first (166 → 152, 162 → 154, 165 → 158) |
| 4 | Difficulty progression | Chapter 16 averages 57.4 (a plateau), Chapter 17 60.7 with three 66+ levels | Chapter 16 ≈ 56.6, Chapter 17 ≈ 61.5; the steepest Armor boards move to 163/165/167/170 |
| 5 | Variety | Two monotone blocks of ten | Alternation breaks both monotone runs |
| 6 | Frustration risk | Low in 151–159 (but boredom); high in 163–164 / 169 | Same puzzles, spread out; Armor can't trap; main risk is the intro at 151 (see 7) |
| 7 | Preservation | 25 / 25 unchanged | All 25 puzzles kept: 9 in place, 15 relocated unchanged, 1 relocated and adapted (the intro) |
| 8 | Implementation complexity | None | Lab-only: level order in the builder, `LESSONS[151]`, a Chapter-card override, the era rule in the lab check, one adapted board |
| 9 | Regression risk | None | Low: production untouched; risks are in lab routing (Chapter card, the lesson, QA seeding of the Armor tip / lesson) |
| 10 | Toward 200 | Novelty: 161 Armor, 171 combination; 176–200 unchanged | Novelty: 151 Armor, 171 combination (a 20-level spacing, matching the 20–25 target); 176–200 unchanged |

**Recommendation: B, if human testing of the lab build confirms it.** If 151–160 test well as they are (they have not been human-validated yet), A remains a sound fallback: it already gives novelty about every 16–20 levels.

## 5. Proposed progression, Lab 151–175 (Option B)

**Chapter 16, Levels 151–160:** Armor arrives; Switch levels act as familiar breathers.

| Slot | Puzzle | Role |
|---|---|---|
| 151 | **old 161 First Shell** (adapted, see section 7) | First Armor encounter, guided lesson |
| 152 | old 166 Quartz Wall | Two shells, "cracking is free": the gentlest Armor level that adds a decision (dev .57) |
| 153 | old 151 Plasma Veil | Familiar Switch level, most Undo-friendly: a breather |
| 154 | old 162 Hard Case | New idea: a **spinner** can be the rammer |
| 155 | old 155 Resonance ✦ | Mystery stays in its slot |
| 156 | old 168 Geode | First 7×7 board; an Armor block's colour is a lock key |
| 157 | old 157 Discharge | Flexible Switch level (stays in its slot) |
| 158 | old 165 Deep Shard | 7×7, Armor block as lock key, shallow dead ends (most forgiving Armor level) |
| 159 | old 154 Spark Gap | Calm Switch level before the Chapter end |
| 160 | old 160 Plasma Core ✦ | Chapter-end breather (stays) |

**Chapter 17, Levels 161–170:** Armor mastery, with Switch levels kept for contrast.

| Slot | Puzzle | Role |
|---|---|---|
| 161 | old 167 Ice Vault | Two shells + lock key; flexible (dev .59) |
| 162 | old 152 Flux | Switch level with non-switch decoys |
| 163 | old 164 Cracked Glass | 7×7, narrow Armor route |
| 164 | old 156 Live Wire | Switch |
| 165 | old 169 Star Frost | 7×7, two shells, narrow |
| 166 | old 158 Field Lines | Two required switches |
| 167 | old 163 Crystal Ward | Hardest Armor level (22 trap steps): late in the Chapter |
| 168 | old 159 Ionic Drift | Switch |
| 169 | old 153 Coil | Hardest Switch level |
| 170 | old 170 Void Prism | Chapter-end Armor challenge (stays) |

**Levels 171–175:** unchanged.

| Slot | Puzzle | Role |
|---|---|---|
| 171 | Nebula | Switch + gate + shell combination intro (its hint stays true) |
| 172 | Dark Matter | Unchanged |
| 173 | Crystal Orbit | Unchanged |
| 174 | Cold Star | Pre-milestone breather |
| 175 | Shatter Point | Milestone, unchanged |

**Checks on the proposal:**
- **No duplicates:** it is a permutation of 151–170.
- **No missing introductions:** no relocated Switch level needs Armor, and no Armor level needs a Switch or gate.
- **Mystery positions 155/160 and Chapter ends 160/170 are kept.**
- **Milestones 150/175 are untouched.**

## 6. Decisions per level

| Level (lab) | Class | Original | Why / experience gained | Risk |
|---|---|---|---|---|
| 151 | **C** | 161 | Armor at the start of a Chapter; reuse the lesson. The board needs a small change (section 7) | Adaptation must be solver-verified; fallback D |
| 152 | **B** | 166 | Second Armor beat while the lesson is fresh; its "free" hint helps | 2 shells early; long (24 moves) |
| 153 | **B** | 151 | Breather after two Armor levels | None known |
| 154 | **B** | 162 | Develops Armor (spinner rammer) | Narrow (dev .21) |
| 155 | A | 155 | Mystery slot kept | — |
| 156 | **B** | 168 | First 7×7; colour-key interaction | 7×7 readability on iPhone; the key colour shows only on the casing rim |
| 157 | A | 157 | — | — |
| 158 | **B** | 165 | Forgiving Armor + key | 7×7; zero deviation survival but shallow dead ends |
| 159 | **B** | 154 | Calm Switch level before the Chapter end | — |
| 160 | A | 160 | Breather kept | — |
| 161 | **B** | 167 | Mastery: two shells + key, flexible | Long (24 moves) |
| 162 | **B** | 152 | Contrast | — |
| 163 | **B** | 164 | Mastery | Narrow 7×7 |
| 164 | **B** | 156 | Contrast | — |
| 165 | **B** | 169 | Mastery | Narrow 7×7 |
| 166 | **B** | 158 | Contrast | — |
| 167 | **B** | 163 | Hardest Armor level, late | 22-step decoy (watch) |
| 168 | **B** | 159 | Contrast | — |
| 169 | **B** | 153 | Hardest Switch level, late | as audited (watch) |
| 170 | A | 170 | Chapter end kept | — |
| 171–175 | A | same | — | 172's estimate spike (yields to holding the switch) |

**Totals over 151–175:**
- **A: 9:** 155, 157, 160, 170, 171, 172, 173, 174, 175.
- **B: 15:** relocated, unchanged boards.
- **C: 1:** 151.
- **D: 0.**

**Cosmetic side effect:** level names follow their puzzles. Chapter 16 (Energy family) would hold some Crystal-named levels, and Chapter 17 some Energy-named ones. Renaming is optional and not proposed.

## 7. Armor onboarding at 151

**Reuse production's Armor lesson unchanged** by routing it in the lab (`ExperienceLab.LESSONS` gains `151: "armor"`; 161 gets none). This is the same approach that worked at 121.

**What the lesson already does well:**
- marks the shell and the right rammer;
- the finger never points into a trap;
- the ram is a big, satisfying, free event;
- tapping the shell explains it, at no cost.

**Why the old 161 board should be adapted:** it is a heavier first encounter than any earlier intro.

| | 121 (Gate intro, validated) | 161 First Shell |
|---|---|---|
| Difficulty estimate | 39.7 | 57.3 |
| Solution length | 16 moves | 22 moves |
| Trap steps | 13 | 18 |
| Board | 6×6, 17 blocks | 6×7, 21 blocks |
| Post-lesson decoy | Fatal for 2 more steps | **Fatal for 8 more steps** (moves 9–16, `Gv`(2,6) at the bottom edge, which turns a spinner) |

The lesson guides only until the first ram at move 9.

**Proposed minimal adaptation (C):**
- one or two token edits that neutralise or shorten the `Gv`(2,6) decoy;
- keep the shell, the rammer (`Rv`(0,0) via the cleared column) and the lesson path;
- verify on the full state graph: no losing first move, no fatal move after the lesson ends beyond Undo reach, a solution of 16–18 moves.

If no such edit exists, design a new gentle intro (D), modelled on 121.

**Readability checks for the human test (iPhone Safari):**
- Do players read the direction chip?
- Do they notice the casing rim colour (it matters from 156/158 in the proposal)?
- Does the explosion feel good and stay smooth? Four bursts + two rings per ram; performance was not measured here.

**Text:** none new. The lesson lines and the 166 hint ("Cracking a shell is free - aim first, then clear.", moving to 152) already fit.

## 8. Human-solvability and fairness

- **No 295-style traps** in 151–175: 0 fatal plain escapes, 0 fatal rams, 0 shells that can strand.
- **Every fatal move is a visible kind:** a spinner-turning escape or a switch firing.
- **Undo 3 is often insufficient (typical dead end 5–13 moves), as in the human-approved 121–150.** The cost is a Restart, not confusion.
- **Watch:**
  - old 163 / 164 / 169 (forced on 78–91% of steps, persistent decoys, 7×7);
  - old 153 (exact switch timing);
  - 172 (estimate spike 76.3, though "hold the switch" solves it).
- **Main fatigue fix:** alternation. The main new risk is the 151 intro, addressed in section 7.

## 9. Impact on 176–200

- **176–200 need nothing:** they already assume Armor, Switch and Gate. Moving Armor earlier only adds ten levels of prior Armor exposure before 171, which is helpful.
- **No duplicate introduction:** 171's combination hint stays true. 200 ("every rule of both eras") is unaffected.
- **The Chapter-card line** ("NEW: Armored Blocks" from `_chapter_news`) is hard-coded to 161. In the lab it must move to Chapter 16, or Chapter 17's card announces something the player already knows.
- **Difficulty:** Chapter 17 rises slightly (≈ 61.5); 171–180 (avg ≈ 62) follow smoothly. The 172 spike exists either way.
- **Production:** if Option B is ever promoted, production needs `LESSONS`, `_chapter_news`, the verifier rule "ARMOR BEFORE 161", and the `run_tests` / `playtest` expectations at 161 updated together. This audit proposes lab-only first.

## 10. Minimum implementation scope (lab only, when approved)

1. **`tools/experience_lab_build.py`:**
   - extend the lab to 170 or 175;
   - for 151–170, take the boards in the order of section 5 (`SOURCES` mapping);
   - apply one solver-verified adaptation to the 151 board;
   - keep names.
2. **`ExperienceLab.LESSONS`:** add `151: "armor"`.
3. **A lab-only override of the Chapter-card "NEW:" line:** Armored Blocks in Chapter 16.
4. **`seed_qa`:** count the Armor lesson and tip as seen for jumps past 151.
5. **Lab checks:**
   - era rule (Armor allowed from 151);
   - relocated boards equal their sources;
   - the 151 adaptation is the only edit;
   - lesson 151 runs as production's;
   - Chapter-card text;
   - progression 150 → 151 … 169 → 170;
   - boundary.
6. **Production:** unchanged.

## 11. Levels needing human validation

| Lab slot | Original | Question |
|---|---|---|
| 151 | 161, adapted | Does the first encounter feel clear and inviting? |
| 152 | 166 | Do players use the "free" ram deliberately? |
| 154 | 162 | Do they discover the spinner rammer? |
| 156 | 168 | First 7×7: is the colour key on a shelled block readable? |
| 158 | 165 | Same question as 156 |
| 160 | 160 | Is it a satisfying Chapter end? |
| 163 / 165 / 167 | 164 / 169 / 163 | Narrow 7×7 Armor levels: restarts and SHOW A MOVE use |
| 169 | 153 | — |
| 170 | 170 | — |

Also ask, after 150 → 151: is there a sense of a fresh Chapter?

## 12. Open questions and limitations

- **151–160 have not been human-validated.** Option A could turn out fine; the plateau finding is structural.
- **The 151 adaptation is not designed yet.** Its feasibility needs a solver search in the implementation phase.
- **Heuristic players are proxies.** Hammer use and on-device performance (the ram explosion on Safari) were not measured.
- **Names / Chapter themes:** relocated levels keep their names, so some Crystal-named levels sit in an Energy-family Chapter. Is this acceptable?
- **Lab range:** extend the lab to 170 (to cover the whole interleave) or to 175 (the Milestone)? This audit suggests 175, so the full arc can be judged.
