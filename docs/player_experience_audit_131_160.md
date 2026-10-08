# Player Experience audit, Levels 131–160 (read only)

Nothing was changed: no level, code, UI, save or test. Production 1–300 is as committed.

## Method and calibration

**Tools** (all read only, run on the production levels):
- `tools/human_audit.gd`: the complete state graph of each level with the game's Solver rules. It measures forced and trap steps, dead-end depth, deviation survival and look-ahead players.
- Scratchpad audits:
  - per level: switch and gate behaviour, first and losing moves, Undos needed;
  - a walk along SHOW A MOVE's line with every fatal option marked;
  - each level's main trap and the stuck board it leads to;
  - **heuristic players** (3,000 games each):
    - **H1:** never fire a switch while any other tap exists;
    - **H2:** H1, and prefer taps that turn no spinner.
- `tools/verify_levels.gd`: the "Diff" column (production difficulty estimate).

**Calibration.** Solver numbers are read against two anchors:
- **Human-validated 121–130.** Look-ahead-8 player wins 1–10%. Dead ends are typically 5.4–9.5 moves (max 12–17). Forced steps are 9–16 per level. 83–94% of mistakes need more than 3 Undos. Real players found these fair; Level 125 was solved without SHOW A MOVE or Undo.
- **Level 295 (cautionary).** 8 solution steps where a *plain* escape (one that turns nothing) is fatal. One push route. 100% of mistakes are beyond Undo reach, with up to 27 moves to stuck.

What makes 295 unfair is fatal moves that **look harmless**, not the raw numbers. Every level here is compared on that axis first.

## A. Level by level

**Columns:**
- **Diff:** production difficulty estimate.
- **Win st.:** winnable states.
- **Forced:** forced steps / solution length.
- **Dead end:** moves still playable after a fatal move, typical / max.
- **H1:** win rate of the hold-the-switch player.
- **Switch role:**
  - **H** (hazard): reversal never used on a winning line; fire it late;
  - **T** (tool): the reversal is used on winning lines;
  - **M:** mixed.

| L | Name | Board / blocks | Mechanics | Diff | Win st. | Forced | Dead end | H1 | Switch role | Note | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 131 | Piston | 6×7 / 20 | sw A, gate C(1), lock 2, CW/CCW | 51.7 | 28 | 13/19 | 5.5 / 12 | 0% | T (turns a spinner) | Chapter opener; switch has a 1-step window; **hint describes a combination that is not on the board** | **B** |
| 132 | Gear Train | 6×7 / 20 | sw, gate C(3), ALT, lock | 53.6 | 47 | 11/19 | 7.0 / 10 | 100% | H | | A |
| 133 | Pressure Plate | 6×6 / 18 | sw, gate C(1), CW/CCW/ALT, lock 2 | 50.8 | 23 | 11/17 | 6.0 / 11 | 100% | H | gate opens at move 2 | A |
| 134 | Conveyor | 6×6 / 20 | sw, gate C(1), CW×4, lock | 55.1 | 29 | 12/19 | 8.0 / 14 | 100% | H | gate opens at move 1 | A |
| 135 | Bolt Cutter | 6×6 / 18 | sw, gate C(1), lock 2, CW/CCW | 49.8 | 24 | 12/17 | 4.8 / 10 | 0% | T (100%) | real switch reasoning; shallow dead ends | A |
| 136 | Crank Shaft | 6×7 / 19 | sw, gate C(1), ALT/CCW, lock 2 | 53.4 | 39 | 11/18 | 6.5 / 12 | 100% | H | gate opens at move 3 | A |
| 137 | Flywheel | 6×7 / 19 | sw (required), gate C(3), lock 2 | 54.3 | 21 | 12/18 | 7.5 / 13 | 100% | T | 3 winning orders, but H1 wins | A |
| 138 | Turnstile | 6×7 / 21 | sw, gate C(1), ALT, lock | 48.7 | 41 | 6/20 | 6.6 / 14 | 0% | H | spinner decoy `B^`(4,1) fatal for 13 steps | A |
| 139 | Forge Gate | 6×6 / 21 | sw, gate C(2), ALT, lock 2 | 55.6 | 89 | 6/20 | 6.8 / 12 | 74% | H | most flexible in Ch 14 | A |
| 140 | Assembly | 6×6 / 20 | sw, gate C(3), ALT/CCW | 55.8 | 43 | 13/19 | 10.0 / 16 | 100% | H | Chapter end; every mistake needs ≥4 Undos (up to 16) | A (watch) |
| 141 | Charge | 6×6 / 19 | 2 sw, lock 2 | 50.8 | 31 | 10/19 | 9.0 / 14 | 100% | T | | A |
| 142 | Arc Line | 6×6 / 21 | sw, gate C(2), ALT, lock | 54.0 | 113 | 2/20 | 10.0 / 15 | 100% | H | open (29k orders) | A |
| 143 | Ion Field | 6×7 / 22 | 2 sw (required), ALT/CCW, lock 2 | 59.0 | 86 | 9/22 | 10.1 / 17 | 48% | T | | A |
| 144 | Surge | 6×7 / 21 | 2 sw, **Pattern returns**, ALT, lock 2 | 57.9 | 22 | 12/21 | 10.8 / 17 | 100% | H | 1 winning order; first Pattern since 100 | A (watch) |
| 145 | Pulse Grid ✦ | 6×6 / 18 | **Hidden returns** (2), sw, gate C(1), ALT | 52.4 | 75 | 6/17 | 6.6 / 12 | 100% | H | hidden blocks never part of a trap | A |
| 146 | Static | 6×7 / 22 | sw, Pattern, ALT, lock 2 | 54.5 | 425 | 4/22 | 12.6 / 17 | 100% | H | breather by flexibility (63M orders); dead ends deep | A |
| 147 | Current Knot | 6×7 / 18 | 2 sw (required), Pattern, CCW | 52.7 | 36 | 11/18 | 5.5 / 15 | 50% | T | | A |
| 148 | Overload | 6×6 / 18 | 2 sw (required), Pattern, ALT, lock 2 | 55.0 | 31 | 11/18 | 7.8 / 13 | 50% | T | | A |
| 149 | Capacitor | 6×7 / 19 | sw, Pattern, ALT, lock | 53.8 | 24 | 12/19 | 7.5 / 13 | 100% | H | | A |
| 150 | Halfway Deep ✦ | 6×7 / 20 | hidden 3, sw, gate C(2), lock 2, CW×4 | **61.9** | 207 | 6/19 | 8.5 / 16 | 100% | M (41%) | **Milestone**; flexible (142k orders) | A |
| 151 | Plasma Veil | 6×6 / 19 | 2 sw (required), ALT/CCW, lock 2 (one flip-marked block is also locked) | 50.4 | 49 | 10/19 | 4.9 / 11 | 49% | T | most Undo-friendly | A |
| 152 | Flux | 6×7 / 20 | sw, Pattern, ALT, lock 2 | 59.5 | 40 | 10/20 | 5.1 / 14 | 4% | H | two non-switch decoys | A |
| 153 | Coil | 6×6 / 21 | 2 sw, Pattern, ALT, lock 2 | 60.2 | 29 | **15/21** | 9.0 / 14 | **0%** | H | exact switch step + spinner decoy for 11 steps; 17 of 21 steps hold a trap | A (watch) |
| 154 | Spark Gap | 6×6 / 18 | sw, Pattern, ALT, CCW, lock 2 | 56.6 | 28 | 12/18 | 6.3 / 12 | 100% | H | | A |
| 155 | Resonance ✦ | 6×6 / 19 | hidden 3, sw, gate C(2), ALT, lock 2 | 60.9 | 27 | 12/18 | 9.5 / 16 | 100% | H | | A |
| 156 | Live Wire | 6×7 / 19 | 2 sw, Pattern, CCW, lock 2 | 60.4 | 35 | 9/19 | 9.7 / 16 | 50% | H | | A |
| 157 | Discharge | 6×7 / 23 | 2 sw, Pattern, CCW, lock 2 | 61.1 | 280 | 8/23 | 9.1 / 20 | 51% | T (97%) | most flexible (9.8M orders) | A |
| 158 | Field Lines | 6×6 / 22 | 2 sw (required), CW×4, CCW, lock 2 | 57.8 | 249 | 4/22 | 10.7 / 16 | 49% | T | | A |
| 159 | Ionic Drift | 6×6 / 19 | 2 sw, Pattern, CW×4, lock 2 | 59.1 | 100 | 9/19 | 6.4 / 13 | 50% | M (49%) | | A |
| 160 | Plasma Core ✦ | 6×7 / 19 | hidden 3, sw (required), gate C(2), lock 2 | 47.8 | 64 | 5/18 | 6.3 / 11 | 100% | T | Chapter end breather: no losing first move, first trap at step 4 | A |

✦ = Mystery level. Every level has 2 first moves with exactly 1 losing (except 160: one first move, safe). SHOW A MOVE never points into a trap (the Solver's pick keeps the board winnable).

## B. Chapter difficulty and pacing

| Chapter | Levels | Diff avg (range) | Shape | Ending |
|---|---|---|---|---|
| 14 Steel Works | 131–140 | 52.9 (48.7–55.8) | Saw-tooth, no clear breather (138 at 48.7 is the low point). Switch + Gate every level. | 140 at the Chapter high (55.8); the deepest dead ends of the Chapter |
| 15 Plasma Field | 141–150 | 55.2 (50.8–61.9) | Rises to 143/144, eases 145–149, peaks at the milestone 150 | 150, the milestone, is the hardest by estimate but one of the most flexible: a fair climax |
| 16 Storm Core | 151–160 | 57.4 (47.8–61.1) | Starts low (151), then a **plateau at 57–61 for 152–159**, then a deliberate dip | 160 is the gentlest late level: a good breather before the Armored chapter |

**Human-difficulty view (the hold-the-switch rule).** In 16 of the 30 levels, every losing move is a switch fired too early. A player who has learned "fire a switch only when nothing else is left" wins those every time (H1 = 100%), whatever the solver-narrowness numbers say. 144 has one winning order, yet H1 wins it 100%.

The levels that need more than that one rule are 131, 135, 138, 152 and 153 (H1 ≤ 4%). Most others are 50%: one real decision, usually which of two switches to fire first.

So the felt curve is flatter than the estimate. Growing mastery is real in Chapter 14, where gates and the switch's spinner side-effects matter. From about 146 on, the levels mostly reward one learned habit.

## C. Human-solvability and fairness

1. **No 295-style hidden traps.** Plain escapes (that turn nothing) are fatal at **0** solution steps in every level 131–160 (295: 8). Every fatal move is a switch firing or a spinner-turning escape: the two kinds players learn to treat as risky. Most immediately create a visible face-off: two arrows pointing at each other.
2. **The Gate never creates a trap.** In all 30 levels:
   - removing a chained block is never a losing move;
   - an escape through an opened gate cell is never a losing move;
   - opening is forced on every winning path.
3. **Hidden blocks never create a trap.** In the four Mystery levels (145, 150, 155, 160), every losing move is a switch firing.
4. **Undo 3 is often not enough**, as in the validated 111–130:
   - **share of mistakes needing more than 3 Undos:** 67–100% per level (121–130: 83–94%);
   - **moves still playable after a mistake:** typically 4.7–12.6 (121–130: 5.4–9.5);
   - **deepest dead ends:** 157 (20 moves), 140, 144, 146 and 143 (16–17).

   This is the production norm, not new in this range. The cost is a Restart, not confusion.
5. **Solver difficulty ≠ human difficulty.** The narrowest levels by the solver (137: 3 orders; 144: 1 order; 149: 5 orders) are fully solved by the hold-the-switch rule. The levels that demand real reasoning are 131, 135, 138, 152 and 153.
   - **Good-hard:** 135 and 151 (switch as a tool, shallow dead ends).
   - **Hardest to read:** 153, which combines an exact switch step with an 11-step spinner decoy.
6. **Hammer dependence was not measured** (see Limitations).

## D. Mechanics and novelty

**Switch** (every level):
- **Hazard only** (fire it late; its reversal never helps) in 17 levels: those marked H in table A.
- **A tool** in 11 (T, including 131, where the switch's job is turning a spinner) and **mixed** in 2 (M).
- Many levels repeat the same lesson: the switch is the trap.

**Gate** (131–140 every level; then only 142, 145, 150, 155, 160):
- **133–136:** the gate opens at move 1–3, so it barely shapes the level.
- **132, 137, 140:** 3-link gates, a real sequencing task.
- **After 140:** the Gate mostly disappears (5 of 20 levels).

**Switch × Gate interaction:**
- No block in 111–161 is both a switch (or a switch-marked arrow) and a chained block.
- The two mechanics share a board but never act on each other.
- **131's hint "Switches can be gate links too." describes something that appears in no level 1–300.** Its source is `tools/generate_era2.gd` (`HINTS[131]`); the generator never enforced it.

**Pattern spinner:**
- Absent from production 101–143 (last seen at 100); returns at 144 with no reminder.
- Its turns are on the solution of 144–159. None of its turns is ever a losing move (all of 144's losing moves are switch firings), so the rule must be read but cannot trap.
- The Experience Lab's approved Pattern visual would apply here, if the lab were extended.

**Hidden** (Mystery levels 145/150/155/160): absent since 100; adds surprise, never a trap.

**Lock:** present in 29 of 30 levels, as a sequencing constraint. 120 and 151 have a switch-marked arrow that is also locked; this is never a trap.

**Clutter risk:** Chapter 16 (151–159) is nine levels of the same kit: switches, CW/CCW/ALT/Pattern spinners and locks. There is no new interaction, and the gate appears only in 155.

## E. Watch list (with evidence)

| Level | Concern | Evidence | Rec |
|---|---|---|---|
| **131** | Opener hint describes a mechanic interaction that is not on the board | No block is both a switch and a chained block (in 131 or anywhere in 1–300). The switch's real job here is turning `G>@-` (1,1) into the gate's lane, fired in a 1-step window right after its marked arrows leave (fatal at steps 1–3). H1 0%. | **B** |
| **153** | Most demanding of 131–160 | 17 of 21 solution steps hold a fatal option; 15 forced; 10% deviation survival; switch fatal at steps 1–5 and needed at step 6; spinner decoy `Y^@`(4,3) fatal for 11 steps; H1/H2 0% | **A** (watch; D only on human evidence) |
| **144** | Pattern returns after 43 levels without a reminder; solver single path | 1 winning order, dead ends typically 10.8 (max 17), first Pattern since 100. Against it: H1 wins 100%, and Pattern turns are never fatal | **A** (watch) |
| **140** | Chapter end with expensive mistakes | 13 losing moves, all switch firings, all needing 4–16 Undos | **A** (watch) |
| **151–159** | Plateau / repetition | Diff 57–61 for 152–159 with one toolkit; H1 ≥ 49% in 7 of 9 levels; no new interaction until 160/161 | **A** (watch; **C** candidate only if testers report fatigue) |
| **152** | Non-switch decoys after a run of switch-only levels | 13 non-switch fatal moves (`G<`(4,2), `G^`(2,6)); H1 4% | **A** |
| 133–136 | Gate opens at moves 1–3 | Gate barely constrains (133: 6 orders with gate vs 18 without) | **A** (novelty note only) |

## F. Seam 160 → 161

- **160 "Plasma Core"** is a well-placed breather:
  - the lowest estimate in Chapter 16 (47.8);
  - no losing first move; first trap at step 4;
  - a look-ahead-8 player wins 68% (every other level here: ≤ 60%); random play wins 6%;
  - the switch is a required tool (reversal used on every winning line);
  - the gate is a 2-link sequencing task.

  It closes Chapter 16 on mastery, not strain.
- **161 "First Shell"** (reference only):
  - Armored plus a guided lesson (production `LESSONS[161] = "armor"`);
  - **no switches and no gates**: a clean slate for the new mechanic;
  - estimate 57.3 (**+9.5** over 160);
  - 18 of 22 solution steps hold a fatal option; look-ahead-8 wins 2%.

  For comparison:
  - the Gate intro, 121 (39.7), sat *below* 120 (43.1);
  - the Switch intro, 101 (7.6), was a tiny board.
- **Assessment:** the *pacing* is right (a dip, then novelty in isolation). 161 is the steepest mechanic introduction so far, so it is the first question for the dedicated Armored audit.
- **Note for the lab:** if the Experience Lab is extended past 160, `ExperienceLab.LESSONS` will need `161: "armor"`. This is the same issue that was fixed for 121.

## G. Recommendations for flagged levels

| Level | Rec | Minimal action (proposal only; nothing done) |
|---|---|---|
| 131 | **B — presentation only** | Replace the hint with one true to the board (e.g. about firing the switch once its marked arrows have left), or drop it. Board unchanged. |
| 153 | A — KEEP | Human-test; consider D only if testers stall or loop on SHOW A MOVE / Restart. |
| 144 | A — KEEP | Human-test whether players recognise the Pattern spinner after 43 levels; a one-line reminder hint would be B, only on evidence. |
| 140 | A — KEEP | Human-test restarts at the Chapter end. |
| 151–159 | A — KEEP | Human-test for fatigue; a reflow (C) only with evidence. |
| 152, 133–136, all others | A — KEEP | — |

No level is a redesign candidate on current evidence.

## H. Overall recommendation and next human test

**Overall: KEEP 131–160.**
- The range is fair by the standard that matters: there are no harmless-looking fatal moves, and the Gate and Hidden blocks never trap.
- Difficulty comes from switch timing and spinner face-offs, which are visible kinds of risk.
- **One genuine defect:** 131's hint promises an interaction that doesn't exist (B).
- **Main experience risk: repetition, not unfairness.** From about 146, most levels yield to a single learned habit ("hold the switch"), and 151–159 is a plateau of the same toolkit.

**Minimal next human-test scope** (if the lab is extended through 160, unchanged boards):
1. **131:** does the hint mislead? Do players find the switch's spinner job?
2. **140:** restarts at the Chapter end.
3. **144:** Pattern recognition after a long gap.
4. **150:** does the milestone feel like a fair climax?
5. **153:** the hardest reasoning level; watch SHOW A MOVE and Restart use.
6. **156–159:** a fatigue check: do players report sameness?
7. **160:** does it feel like a satisfying breather before 161?

## Limitations

- **Hammer** use and dependence were not simulated.
- **Heuristic players are proxies.** H1/H2 show what a learned habit achieves, not how real players learn it.
- **Hidden blocks:** the solver sees them; human surprise at a reveal is not modelled. No hidden block is part of a fatal move here.
- **Difficulty estimates** come from production's estimator and include solver-trap terms that overweight narrowness.
- **Visual clarity** of crowded boards (19–23 blocks with locks, switches, patterns and gates) was not reviewed on device.
- **Undo-depth figures** count the longest continuation; a human usually gets stuck sooner.
