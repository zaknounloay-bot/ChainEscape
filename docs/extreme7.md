# EXTREME design experiment: two hand-designed VERY HARD puzzles (development only)

Base commit d7c1aeb. Phase 2 (P1-P2) is in the working tree, uncommitted. All of this work is development-only:
- the `?xtest7=1` page, which is switched off in player, QA and Social QA builds;
- `data/dev/extreme7*.json`;
- tools.

**Untouched:**
- Production, Supabase, campaign levels 1-300, the Social MVP and the live Friend generator.
- The shared challenge format, progression / economy and the live difficulty labels.
- The earlier pilot boards. `data/dev/extreme5.json` (T1-T5) and `data/dev/extreme6.json` (P1-P2) are byte-identical, checked by hash in `Extreme7Check`. `?xtest5=1` and `?xtest6=1` are unchanged and re-tested.
- Nothing was committed, pushed, deployed or uploaded. No human testing was started.

**Result: two puzzles, H1 (A) and H2 (B).** Both meet every acceptance rule used for T1-T5 and P1-P2. Each puzzle's central idea holds on **every** winning line, checked exhaustively. **Neither board's difficulty is claimed from machine scores: only people can say whether they feel VERY HARD.**

## 1. What the human results suggested, and the design rule taken from them

| | Board | Machine: luckiest rule of thumb | Opening | People said |
|---|---|---|---|---|
| T3 | 7x7 / 14 pieces | 11 dead ends | 1 of 4 first moves works | VERY HARD |
| T5 | 6x6 / 13 | 17 | 1 of 4 | VERY HARD |
| P2 | 6x6 / 10 | 9 | 1 of 5 | HARD |
| P1 | 7x7 / 11 | 11 | 2 of 6 | MEDIUM |

The machine numbers rate P1 about as hard as T3, yet people found it MEDIUM. The visible difference between the boards is the **length of the dependency chain**:
- **P1** has one insight: drag the shell under the hammer. The pull-preview line almost shows it.
- **T3** has a timing chain across two switches and a gate.
- **T5** has three pulls, each changing what the next can grab.

**Design rule for this experiment:**
- each puzzle is built around a chain of several links, in which every link changes what the next one can do;
- the insight is not shown by any single preview;
- difficulty comes from the chain, not from more pieces.

## 2. Method: concept first, the solver last

For each puzzle:
1. the strategic insight was written down first;
2. then the dependency chain;
3. then a board was drawn by hand around it;
4. only then was it validated.

**Design workbench (`tools/extreme7_lab.gd`).** For a hand-drawn board it reports:
- every reachable position (exhaustive), and which first moves keep it solvable;
- how many legal moves win at each step of the solution;
- the idea's facts.

**Central idea as facts (`tools/extreme7_events.gd`).** The facts are read from the solver's own state, move by move. The check asks whether **any** winning line avoids the idea; the answer must be no.

| Puzzle | Facts that must hold on every winning line |
|---|---|
| A | `gate_before_switch`: the switch reverses blocks only after the gate has opened. `reversed_escape`: a block leaves in the direction the switch reversed it to. |
| B | `aimed_ram`: a magnet's escape turns a spinner AND carries it, and that spinner later rams a shell. `carried_twice`: the hammer is carried by two magnets and rams after the second carry. |

**Refinement, not generation (`tools/extreme7_build.gd --seeds`).**
- A search may only change cells **outside the frozen designed core**: move, turn, add or remove other pieces.
- Every step of the search is scored against the idea on every winning line, so it can never trade the idea for difficulty from elsewhere.
- Afterwards each periphery piece was removed by hand, one at a time. Any piece whose removal kept every acceptance rule was treated as decoration and taken out (Section 4.3).

**Design history.** Kept honest, because several hand concepts failed:

| Concept | What happened |
|---|---|
| B0 "the shell blocks a lane" | **Failed**. Any block whose lane hits a shell can ram it where it stands, so "a shell in the way" is never a real obstacle. The idea was inverted to "bring the hammer to the shell". |
| B1-B3 "aim and carry the hammer" | Worked on every winning line, but too small: 36-80 positions. |
| B6-B8 (lengthened magnet lane, recovery neighbour) | Every first move still won (about 60 % of positions winnable). Greedy players won 16-36 % even after refinement. Rejected. |
| **B9 "the travelling hammer"** | Two magnets carry the same hammer to two shells. **Kept**: became H2. |
| A1 "one switch, two opposite needs" | Worked on every winning line. Refined: became H1. |

**Acceptance (unchanged from T1-T5 and P1-P2, never weakened).**
- Gate 0 technical rules:
  - solution check within 20,000 nodes (recipient limit 60,000);
  - SHOW A MOVE on every position and after every losing move;
  - the 40 ms native-desktop mobile budget in **all 5** repeated measurements;
  - every mechanic matters;
  - a random tapper wins at most 8 %.
- EXTREME rules:
  - the luckiest rule-of-thumb learner hits at least 3 dead ends;
  - five greedy players win at most 5 % (200 / 120 games);
  - at least 2 distinct plausible losing moves that fail late (4 or more moves later);
  - the "use" mechanics are real decisions;
  - at most 14 pieces and 18 taps;
  - not a duplicate of, nor a near-copy (more than half the cells equal under rotation / reflection, colours ignored) of, any board a tester may have played: campaign, Gate 0 pilot, T1-T5, P1-P2.
- **New:** the idea on every winning line.

## 3. Puzzle A: H1 "One switch, two stand-offs" (switch / gate + spinners)

```
     C1  C2  C3   C4     C5   C6
R1   .   .   .    .      .    .
R2   .   .   .    P>@    .    .        @  clockwise spinner, @- counter-clockwise
R3   .   .   Y^%A P^@+C  P>   .        %A switch A, &A reversed by switch A
R4   .   XC  .    .      .    .        XC chain gate C, +C its link
R5   .   G^&A Y^@ G>     R<&A .
R6   .   B^  G>@- .      G^   .
```

6x6, 12 pieces, 11 taps. Mechanics: clockwise + counter-clockwise spinners, switch, gate.
- No other mechanic was added. The core needs none, and the request allowed one only where it improves the experience.
- The refined board had 14 pieces. Two top-row blocks turned out to be decoration and were removed by hand (Section 4.3).

1. **Central strategic idea.** One switch acts in two places at once, and the two places need opposite timing.
   - The switch Y at R3C3 reverses the red block at R5C5, which is locked head-to-head with G at R5C4 and can only leave once reversed. The red block wants the switch.
   - The same tap also reverses the green block at R5C2. Reversed, it would face the blue block at R6C2 head-to-head for good. The green block needs the switch **not yet**.
   - So the switch must wait until that green block has left upward, through a gate that opens only after a spinner elsewhere has been aimed and released.
2. **Intended discovery moment.** "The switch is free right now, and it frees the red block, but it would also turn the green one around. Green must leave first, through the gate. The gate needs its link, the purple spinner, gone. And that spinner must be turned exactly once, by the right neighbour."
3. **Why the interaction is interesting.** Three systems are coupled:
   - the switch (remote, permanent);
   - the gate (opens on a departure elsewhere);
   - a spinner whose turn count depends on which neighbour leaves first.

   The first decision (who turns the gate's link spinner) decides whether the switch can ever become safe. It is followed by a counting tail: the yellow spinner at R5C3 must be turned exactly twice, by G at R5C4 and the counter-clockwise spinner G at R6C3, and the blue block at R6C2 must not leave early.
4. **Why greedy strategies may fail.**
   - The two most eye-catching first moves both lose: the free switch, and the free spinner P at R2C4 with its empty lane. Only 1 of the 3 legal first moves keeps the board solvable (exhaustive).
   - In all 30 winning lines the first four moves are the same: P at R3C5, the gate's link, green up through the gate, the switch. The switch therefore always fires after green has left.
   - Machine measures:
     - the luckiest rule of thumb hits 9 dead ends (all four rules hit 9-12);
     - greedy players win at most 1.5 %;
     - 6 of the 11 solution steps are real choices with losing alternatives;
     - 6 narrow steps;
     - 25 of 198 reachable positions are winnable.
5. **Consequential mistakes.**
   - The switch on move 1: play can go on for up to 8 moves before the jam.
   - The free spinner P at R2C4 on move 1: it turns the gate's link spinner too early; up to 8 moves.
   - The switch after the link has left but before green has gone up through the gate: up to 6 moves.
   - The blue block at R6C2 as soon as green has left above it: it turns the counter-clockwise spinner at R6C3 the wrong way; up to 5 moves.
6. **Are the consequences fair?** Yes: every consequence is visible on the board.
   - The fatal stand-off (green facing blue) is two arrows pointing at each other. Players know this pattern from the campaign (switches from Level 101, gates from 121, spinner gate links in the campaign).
   - The gate shows its counter ("C 1") and the link spinner carries the C badge.
   - Nothing depends on a hidden rule or on the Sequence quirk.
7. **How it differs from T3, T5 and P2.**
   - **T3** has two switches, five flip targets and a gate linked to flip targets; its difficulty is "fire switch A when at most one of three targets remains".
   - **H1** has one switch with exactly two targets of opposite need. Its gate is linked to a spinner, so the switch's safe moment is set by a spinner-aiming decision far away.
   - No magnet, no armor: nothing from T5 or P2.
8. **Limitations and risks.**
   - **Forced opening.** The first four moves are forced, and only one first move works. A player who tries the plain block first gets the opening for free. The difficulty then lies in understanding why the switch must wait, and in the bottom-row tail.
   - The richer 14-piece parent (1,830 winning lines, 2 of 4 first moves) also passes every rule. It was set aside, because its two extra blocks were decoration by the same rule that pruned B.
   - A careful player may spot the green / blue stand-off quickly. The difficulty then rests on the gate and spinner chain.
   - The bottom-row pieces (R5C3, R6C3, R6C5) are a counting tail. They are needed for the measures (removal makes the board too easy), but they are not part of the central insight.
   - Eight pieces come from the hand-drawn core: switch, link spinner, its turner P at R3C5, gate, both flip targets, both stand-off partners. The four other pieces come from refinement and are each shown to be needed.

## 4. Puzzle B: H2 "Carry the hammer" (magnet + armor + spinners)

```
     C1  C2  C3   C4    C5  C6    C7
R1   .   .   .    B^    .   .     .
R2   .   .   .    .     .   .     .
R3   .   .   .    .     .   .     .        *  magnet (pulls the first block behind it into its cell)
R4   .   .   .    .     .   Y>=   .        =  armored (shell)
R5   .   .   Rv=  B^*   .   G>*   .        @  clockwise spinner
R6   .   B>  Pv   P^@   .   .     .
R7   .   .   Y<@  B<    .   .     .
```

7x7, 10 pieces, 12 taps. Mechanics: clockwise spinners, armor, magnet.

1. **Central strategic idea.** The two shells can never be hit where they stand: nothing points at them. The only hammer is the purple spinner at R6C4, and **two magnets carry it**:
   - When the blue magnet R5C4 above it leaves, it first turns the spinner (a neighbour), then drags it into R5C4. The spinner arrives facing the first shell only if it was turned **exactly twice** before, by both of its other neighbours.
   - Ram. The cracked red block leaves downward and turns the hammer to face up.
   - The green magnet at R5C6 drags it along row 5 to R5C6, right under the second shell.
   - Ram again. The cracked yellow block leaves to the right and turns the hammer to face right, out.

   **Every departure re-aims the same hammer.**
2. **Intended discovery moment.** "Nothing can reach the shells. But the magnet would carry the spinner, and its own departure turns it on the way. Then the second magnet can carry it again."
3. **Why the interaction is interesting.** Moving one block (the hammer) changes what is possible for two others (the shells). Each step's aim is set by a different departure:
   - two pre-turns;
   - the magnet's own escape;
   - the cracked shell's escape;
   - the second shell's escape.

   It is a geometry chain, not a single pull.
4. **Why greedy strategies may fail.**
   - The green magnet is free on move 1 and pulls "something". Its preview line shows it would drag the blue magnet away from above the hammer.
   - The hammer itself becomes free three times (facing right, then down, then up), and leaving is always a loss.
   - Only 2 of the 3 legal first moves keep the board solvable. In all 56 winning lines, the blue magnet fires at exactly step 5, before the green one (exhaustive).
   - Machine measures:
     - the luckiest rule of thumb hits 5 dead ends;
     - greedy players win at most 2 %;
     - both magnet moves are real decisions;
     - the board is unsolvable without magnets;
     - 23 of 237 positions are winnable.
5. **Consequential mistakes.**
   - Green magnet on move 1: up to 9 moves before the jam.
   - Blue magnet as soon as its column is clear, with too few turns: up to 6 moves.
   - Releasing the hammer when it is free: up to 5-6 moves; after the first shell, it can leave upward.
6. **Are the consequences fair?** Yes.
   - Every pull is previewed by the dotted line before it happens. In the iPhone SE screenshot, the green magnet's preview visibly marks the blue magnet as what it would drag.
   - "A magnet's escape turns the spinner behind it, then drags it" is a campaign situation: Levels 83 and 89 do exactly this on their solutions (checked).
   - Ramming is taught from Level 151.
   - No shell is ever pulled, so the never-taught "magnet pulls armor" rule (demo DB1 in `?xtest6`) is not needed. **No demo is required.**
7. **How it differs from T5, P2 and T3.**
   - **T5** is three pulls of ordinary blocks and magnets.
   - **P2** pulls a **shell** into a rammer's lane.
   - **H2** never moves a shell. It carries the **hammer** twice and aims it with turn counts.
   - No switch, no gate: nothing from T3.
8. **Limitations and risks.**
   - Small and tightly forced: only 56 winning lines, and the blue magnet's moment is fixed (step 5). Some people may find it "one right way" rather than a search.
   - Its machine measures are lower than A's (5 dead ends, against 12).
   - The two-turn requirement can be counted by a careful player. People may find it HARD rather than VERY HARD, as with P2.

### 4.3 Removing decoration (hand pruning, both puzzles)

Each candidate piece outside the core was removed in turn and the full acceptance re-run.

| Variant | Positions (winnable) | Result |
|---|---|---|
| H2's search parent (12 pieces) minus the free spinner R5C2 | 549 (53) | **passes**: still 7 dead ends, 2.5 %. The piece was decoration. |
| ... minus the free spinner R6C1 | 569 (62) | **passes**: decoration |
| ... minus both (**= H2**, 10 pieces) | 237 (23) | **passes**: 5 dead ends, 2 % |
| ... minus B at R6C2 | 670 (76) | passes, but weaker (5 dead ends) |
| H1's search parent (14 pieces) minus Y at R1C2 | 453 (67) | **passes**: decoration |
| ... minus B at R1C4 | 366 (28) | **passes**: decoration |
| ... minus both (**= H1**, 12 pieces) | 198 (25) | **passes**: 9 dead ends, 1.5 % |
| ... minus the spinner P at R2C4 (14 pieces) | 315 (59) | **fails**: greedy 55 %, the gate becomes decoration (it is the designed trap) |
| H1 minus G^ at R6C5 | 167 (33) | **fails**: greedy 8 % |
| H1 minus Y^@ at R5C3 | 79 (30) | **fails**: greedy 26 %, the spinners stop mattering |
| H1 minus G>@- at R6C3 | 117 (26) | **fails**: greedy 6 %, switch never a real decision |
| 14-piece parent minus G> at R5C4 (a stand-off partner) | 507 (167) | **fails**: the gate stops mattering |

So every piece left on H1 is needed or part of the designed core. H2 keeps only pieces that are part of the chain or gate it:
- Y at R7C3 frees both pre-turners;
- B at R1C4 holds the blue magnet;
- B at R6C2 is the last to leave once the hammer's row is empty.

## 5. Technical validation

| | H1 (A) | H2 (B) |
|---|---|---|
| Size / pieces / taps | 6x6 / 12 / 11 | 7x7 / 10 / 12 |
| Solution check (nodes) | 62 | 111 |
| SHOW A MOVE, max nodes: on the solution / after a mistake | 41 / 41 | 90 / 8 |
| 5 repeated runs, worst ms each (native desktop, budget 40) | 3.8, 3.5, 3.4, 5.6, 3.6 | 7.4, 6.7, 7.2, 6.8, 7.5 |
| SHOW A MOVE in the real play screen after 6 mistakes x 5 presses (slowest) | 4.1 ms | 4.9 ms |
| Luckiest rule of thumb (dead ends) / blind tapper | 9 / 10 | 5 / 6.5 |
| Best greedy win (safe / look2 / look4 / min_turn / mobility) | 1.5 % (1.5 / 1.5 / 0.8 / 0 / 0) | 2.0 % (0 / 0 / 0.8 / 0 / 2.0) |
| Random tapper | 0 % | 0 % |
| Late plausible losing moves | 3 | 3 |
| Mechanic impact | switch essential, gate 3.5, spinner rules 11.7 | magnets essential (unsolvable without), armor 12.9, spinners essential |
| Idea on every winning line | yes (30 lines) | yes (56 lines) |
| Near-copy of a played board | none | none |

**Game-versus-solver parity:**
- `Extreme6Parity` (35 / 35, re-run) covers both families: switch + gate + clockwise / counter-clockwise spinners, and magnets + armor + spinners.
- Both boards are played to the end in the real SocialPlay. The action log names every tapped block.

**SHOW A MOVE after mistakes** (`Extreme7Check`). For each board, the first 6 losing moves along the solution are made in the real play screen, and SHOW A MOVE is pressed 5 times after each. Every time:
- it answered within budget;
- it said "can't be cleared from here - try Undo";
- it spent nothing;
- after UNDO it named a winning move again.

**Browser** (`tools/web_xtest7_page_test.mjs`, Chromium at iPhone SE size, WebAssembly build). CPU throttling is a desktop **simulation** of a slower phone, not an iPhone measurement.

| | check ms | SHOW A MOVE ms | after a mistake ms |
|---|---|---|---|
| x1 | 4.2 / 3.7 | 5.2 / 5.5 | 3.6 / 0.6 |
| x4 | 17.8 / 36.3 | 22.7 / 46.7 | 19.3 / 4.7 |
| x6 | 25.5 / 37.5 | 33.0 / 64.1 | 26.5 / 4.1 |

(H1 / H2, final files.) The throttled numbers are noisy: an earlier run of the identical H2 measured SHOW A MOVE 41.3 ms at x4 and 19.8 ms at x6. For comparison, P2 measured 64 / 127 / 137 ms at x6. Real iPhone Safari timing (`&bench=1`) is still to be done by a person.

## 6. The development test mode: `?xtest7=1`

- **Purpose:** a separate blind test of the two puzzles. Its own board file (`data/dev/extreme7.json`), its own state (`user://extreme7_state.json`, localStorage `chain_escape_xtest7_state`) and its own title (PUZZLE PILOT 3).
- **Unchanged:** `?xtest5` / `?xtest6`, their storage and T1-T5 / P1-P2.
- **Blind:** the order is randomised per tester, ids are neutral (H1 / H2), and the difficulty label is blank.
- **Flow:** the same as `?xtest6`, without demos:
  - campaign progress;
  - a reminder card per puzzle;
  - the clock and GIVE UP (tap twice);
  - live VERY HARD tools: UNDO x3, SHOW A MOVE x1, HAMMER x0.
- **Collected for each puzzle:**

  | Measure | Collected as |
  |---|---|
  | Difficulty | EASY ... EXTREME rating |
  | vs Level 300 | question |
  | Enjoyment | 1-5 |
  | Achievement | 1-5 |
  | Fairness | YES / MOSTLY / NO |
  | Planning | YES / A LITTLE / NO |
  | Interest from combined mechanics | YES / A LITTLE / NO |
  | Restarts, undos, SHOW A MOVE uses | counts |
  | Solve time, give-ups | logged |
  | Every move and blocked tap | time-stamped log |

  At the end: which puzzle was hardest, and why. COPY RESULTS gives the JSON; the summary per puzzle appears only after both are played.
- **Timing on a phone:** `index.html?xtest7=1&bench=1`.

## 7. Tests

| Test | Result |
|---|---|
| `Extreme7Check` (new) | **84 / 84** |
| `web_xtest7_page_test.mjs` (new) | **15 / 15** |
| `Extreme6Check` | 85 / 85 |
| `Extreme6Parity` | 35 / 35 |
| `Extreme5Check` | 147 / 147 |
| `VhPilot4Check` | 442 (the count varies with the randomly first board's reminders) |
| `VhHumanTestCheck` | 100 |
| `MagnetCheck`, `RevealMvpTest`, `SocialPlayTest` | passed |
| `FriendFlowTest` | 149 |
| browser `?xtest6` / `?xtest5` / `?vhtest4` / `?vhtest` | 14 / 14, 19 / 19, 14 / 14, 17 / 17 |

**Dev ZIP:** `build/dev_qa/chain_escape_dev_extreme7.zip` (git-ignored, not uploaded), 13,095,267 bytes, SHA-256 `95114f55fad5cfa8922e39c7fa001596cbaeeb1ddc5ea1ee05fdeba85200c94b`.
- Open `index.html?xtest7=1`; for timing, `index.html?xtest7=1&bench=1`.
- It also contains `?xtest6=1` and `?xtest5=1`, unchanged.
- The earlier ZIPs are unchanged (extreme5 `ff8bce86...`, extreme6 `3f84a5e3...`).

## 8. Changed files

**New:**
- `data/dev/extreme7.json`: the two boards with every measurement.
- `data/dev/extreme7_notes.json`: the hand-written explanations.
- `docs/extreme7.md`: this report.
- `tools/extreme7_build.gd`: recipes, refinement around a frozen core, and acceptance; extends the phase-2 builder.
- `tools/extreme7_events.gd`: the idea facts, checked over every winning line.
- `tools/extreme7_lab.gd`: the design workbench.
- `tools/extreme7_check.gd` and `tools/Extreme7Check.tscn`.
- `tools/web_xtest7_page_test.mjs`.

**Modified:**
- `scripts/social/vh_human_test.gd`: the `xtest7` test entry and header lines; `xtest7` added to the URL keys; the combination summary shown when the config says `combo`. The `xtest6` behaviour is unchanged.

(The phase-2 files from the previous step are still uncommitted in the working tree and were not changed.)

## 9. Honest limitations

- **No human evidence yet.** Every difficulty statement here is about machine players or exhaustive search. The phase-2 result (P1 MEDIUM, despite machine numbers like T3's) shows these measures do not predict how people feel.
- **Hybrid, not purely hand-made.** Both cores, chains and ideas were designed by hand, and some hand concepts failed (Section 2). The periphery was refined by a search restricted to cells outside the frozen core, then pruned by hand.
  - H1: 8 hand-core pieces plus 4 from refinement, each shown to be needed.
  - H2: 7 hand-core pieces plus 3 supporting pieces.
- **H2 may feel HARD rather than VERY HARD:** it is small, forced, and its turn counting is learnable.
- **H1's switch trap may be spotted by players who read stand-offs**, and its opening is forced (1 of 3 first moves). Its difficulty then relies on the gate / spinner chain and the bottom-row counting tail.
- **Timing:** native desktop and throttled Chromium only. iPhone Safari still needs `&bench=1` on a real device.
