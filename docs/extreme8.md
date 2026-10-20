# EXTREME for expert players: calibration experiment (development only)

**Scope.** Development only: the `?xtest8=1` page (switched off in player, QA and Social QA builds), `data/dev/extreme8*.json`, and tools.

**Untouched:**
- Production, Supabase, campaign levels 1-300, the Social MVP, Photo / Message Reveal and the live Challenge a Friend generator;
- the shared challenge format, progression, coins / economy, tools, hearts and the live difficulty labels;
- every earlier pilot board file. `extreme5.json`, `extreme6.json`, `extreme7.json`, `vh_validation3.json` and `vh_pilot4.json` are byte-identical, checked by hash.

Nothing was committed, pushed, published or deployed. No human testing was started.

**Result: 2 of the 3 asked-for puzzles.**

| Board | Design | Status |
|---|---|---|
| E1 | X1 deep remote control | Delivered |
| E2 | X2 cascading geometry | Delivered |
| — | X3 expert integration | **Not delivered**; reasons in Section 6 |

No difficulty claim is made for either delivered board. Only the expert players can say whether they are EXTREME.

## 1. What the expert evidence says (calibration)

`tools/extreme8_calibrate.gd` runs new expert-style measures (`tools/expert_probe.gd`) on every board people have rated. A losing move is **hidden at depth K** when play can still go on for K or more moves after it: a player who checks every line K moves ahead cannot see that it loses.

| Board | Experienced player | Learners with memory, looking 2 / 4 / 6 moves ahead (luckiest habit, dead ends) | Decisions 6-move lookahead can't settle | Hidden losing moves on the path, K = 6 / 8 |
|---|---|---|---|---|
| H2 | HARD, 33 s, 1 restart | 5 / 5 / **3** | 4 | 6 / 2 |
| T3 | HARD, 59 s, 3 restarts | 14 / 17 / 18 | 5 | 10 / 7 |
| T5 | VERY HARD, 120 s, 13 restarts (his hardest) | 17 / 16 / 14 | 4 | 7 / 1 |

**Reading (three boards and one player: a direction, not a validation):**
- **What separates H2.** Only the deep-lookahead learners clearly separate the board he found easy (H2). Its traps are shallow: a player who looks 6 moves ahead and learns from failures hits about 3 dead ends.
- **What doesn't separate T3 from T5.** No measure explains why T5 was much harder than T3. The likeliest difference is the mechanic: magnet pulls rewrite the board, which is harder to simulate in the head than a switch flip.
- **Expert gates added** (on top of every earlier rule, never replacing it):
  - learners with memory looking 4 and 6 moves ahead each hit at least 12 dead ends, whichever habit they follow;
  - at least 4 decisions on the solution that 6-move lookahead cannot settle;
  - a greedy player looking 6 moves ahead wins at most 5 %.

**A finding that shaped the design.** On every near-miss, the habit that beat the board was **"release a spinner as soon as it can leave"**:
- 6-8 dead ends for that habit, against 14-27 for the others;
- boards whose losing moves stayed hidden 12 moves deep were still solved by it.

So both delivered designs contain a spinner that is **free early but must be held**, because releasing it too soon turns something else at the wrong moment. Holding a free piece back is the expert habit that familiar play does not suggest.

## 2. Method (for each design)

**Steps A-D, on paper:** the central challenge, the dependency chain, the tempting losing moves, and the reasoning an expert needs.

**Step E, the hand-made core board.** `tools/extreme8_lab.gd` reports:
- every reachable position;
- the winning first moves;
- each solution step with how many legal moves win;
- a winning line that *avoids* the idea, in words, when one exists, so the designer can close the loophole.

Example from the start of the experiment: in the first X2 core the shell could also be dragged to the hammer. The witness line showed it, and the geometry was redrawn.

**Step F, refinement.** A search may only change cells outside the frozen designed core, and every step is scored against the idea on every winning line. Each try continues from the best board so far.

**Steps F-G, designed edits by hand.** The decisive changes were hand edits, each screened over all its one-edit neighbours with the expert measures:
- X1: the stand-off block at R4C7 and the held spinner at R5C5;
- X2: the spinners beside the hammer's path and the plain block at R2C4.

Then each remaining piece was removed in turn. **Every piece of both final boards is needed**: each removal fails a gate or makes the board unsolvable.

**Step H, exhaustive verification.** The idea facts (`tools/extreme8_events.gd`) are checked over every reachable position, so the idea holds on **every** winning line. Every winning line was also enumerated to verify the order claims.

**Step I, technical and mobile QA** (Section 5).

## 3. E1 (X1): "Two gates, one switch, one held spinner" (switch, gates, clockwise and counter-clockwise spinners)

```
     C1  C2    C3      C4    C5     C6       C7
R1   .   .     B^@-    .     .      .        .
R2   .   R<@   G^@-    .     XC     .        .
R3   .   .     R<      .     .      .        .
R4   .   .     .       Y^%A  R<@    .        G<
R5   .   XD    P^@+D   Yv    P>@-   .        .
R6   .   G^&A  .       .     B>     R<&A+C   .
R7   .   P^    .       .     .      .        .
```

7x7, 16 pieces, 14 taps.

**A. Central challenge.** One switch acts in three places at once. The window in which that is safe is set by two different remote systems.

**B. Dependency chain** (verified on all 896 winning lines):
1. **Top-left cascade.** R2C2 leaves first. Each departure turns the next counter-clockwise spinner to face the empty side; any other order jams column 3.
2. **Gate D opens.** The link spinner P at R5C3 leaves up the cleared column 3.
3. **Green and purple leave.** Green at R6C2 goes up through the gate cell, then purple at R7C2.
4. **The switch fires** (R4C4, always at step 7-9). It reverses red at R6C6, which leaves and opens gate C, and it turns the red spinner R4C5 from left to up, at gate C.
5. **The aimed spinner leaves** through gate C.
6. **The held spinner leaves.** Only then may P at R5C5 go; on every line it leaves after R4C5.

**C. Tempting losing moves.** Each fails up to 11 moves later:
- the switch on move 1 (it frees red, but reverses green into a permanent stand-off with purple below);
- the free spinner P at R5C5, which turns the aimed spinner too early;
- B at R1C3 or R at R3C3 first (they break the cascade);
- Y at R5C4 down.

Only **1 of the 6** legal first moves keeps the board solvable.

**D. Expert reasoning needed.** Familiar reasoning ("fire the switch when it helps", "clear free spinners") fails. The expert has to see that:
- the switch must wait for a gate that depends on a different chain;
- one free spinner must stay put until after the switch.

**Mechanics on every winning path:**
- the switch's reversal opens gate C;
- gate D opens before the switch;
- every winning line uses both facts (exhaustive);
- impact: gate 22.5, spinner rules 16.1, switch essential.

## 4. E2 (X2): "The relay" (magnet, armor, clockwise and counter-clockwise spinners)

```
     C1  C2    C3     C4     C5  C6  C7
R1   .   .     .      .      .   .   B>
R2   .   R>    .      P>     .   .   B<@-
R3   .   .     P<@    B^*    .   .   .
R4   .   .     Y>@-   .      .   .   .
R5   .   .     G>@    .      .   .   .
R6   .   P>@-  .      R>*    .   .   .
R7   .   Y^@-  .      R<=    .   .   .
```

7x7, 12 pieces, 13 taps.

**A. Central challenge.** The shell at R7C4 can never be hit where it stands, and nothing ever faces it. The hammer (purple clockwise spinner, R3C3) must be **carried** by a magnet that **another magnet moved into place**.

**B. Dependency chain** (verified on all 2,714 winning lines):
1. **Clear magnet 1's column.** Column 4 above it must be empty.
2. **The blue magnet (R3C4) leaves up.** It turns the hammer, then drags the red magnet up from R6C4 to R3C4. The red magnet now points right, with the hammer first behind it.
3. **The yellow counter-clockwise spinner (R4C3) leaves.** This turns the hammer once more.
4. **The red magnet leaves.** It turns the hammer a third time, so its exact count is now left, up, right, down, and drags it into R3C4, facing down column 4 at the shell.
5. **Ram.** The cracked shell leaves left, and the hammer leaves down.

On every line the blue magnet fires before the red one.

**C. Tempting losing moves.** Each fails up to 10 moves later:
- releasing the free hammer (left, move 1);
- firing the red magnet early (it drags the purple spinner at R6C2 instead);
- releasing the green spinner R5C3 early (it turns the yellow one wrongly).

Only **2 of the 5** first moves work.

**D. Expert reasoning needed.** The expert must:
- see that a magnet can rewrite **another magnet's** pull line;
- count turns across two drags;
- leave a free hammer alone at several moments.

**Mechanics on every winning path:**
- relay carry and aimed ram on every line (exhaustive);
- unsolvable without magnets;
- armor impact 17.1;
- spinners essential.

The ram is the payoff, not a choice. Every neighbour of the hammer's landing cell is a magnet's lane, so "ram" was dropped from X2's list of mechanics that must be real decisions; the magnets are the decisions. That is a per-design choice, recorded in the builder. The expert gates are unchanged.

## 5. Measurements

| | E1 | E2 | T5 (his hardest) | H2 (easy for him) |
|---|---|---|---|---|
| Positions (winnable) | 839 (65) | 614 (64) | 283 (34) | 237 (23) |
| Winning first moves | 1 / 6 | 2 / 5 | 1 / 4 | 2 / 3 |
| Expert learners, look 4 / 6 (luckiest habit) | **17 / 17** | **13 / 13** | 16 / 14 | 5 / 3 |
| Rule-of-thumb learners, look 2 (release / hold / min turn / keep moves open) | 16 / 25 / 25 / 21 | 13 / 18 / 20 / 18 | 17 (luckiest) | 5 (luckiest) |
| Decisions 6-move lookahead can't settle | 6 | 5 | 4 | 4 |
| Hidden losing moves, K = 6 / 8 | 21 / 16 | 15 / 9 | 7 / 1 | 6 / 2 |
| Deepest trap (moves) | 12 | 11 | 9 | 10 |
| Greedy players (max), 6-move greedy | 3.5 %, 1.7 % | 0 %, 1.7 % | 0 %, 8.3 % | 0.8 %, 3.3 % |
| Random tapper | 0 % | 1.3 % | | |

**Machine timings** (native desktop, budget 40 ms):

| | E1 | E2 |
|---|---|---|
| Solution check | 155 nodes, 6.7 ms | 250 nodes, 4.5 ms |
| 5 repeated runs (worst of check / SHOW A MOVE / after a mistake) | 30.4, 31.8, 30.0, 34.3, 31.8 ms | 16.5, 17.9, 19.9, 19.2, 22.5 ms |

**SHOW A MOVE after mistakes, in the real play screen.** Six plausible losing moves per board, 5 presses each. Every press:
- recognised the lost position ("can't be cleared from here - try Undo");
- spent nothing;
- worked again after UNDO.

The slowest press across three full check runs was E1 31.0-37.0 ms and E2 31.5-**43.7** ms. One run had one press 3.7 ms over the 40 ms budget, so `Extreme8Check` passed 2 of its 3 runs. This is a real timing risk (Section 8).

**Browser** (`web_xtest8_page_test.mjs`, Chromium at iPhone SE size, WebAssembly). CPU throttling is a desktop **simulation**, not an iPhone measurement.

| | check ms | SHOW A MOVE ms | after a mistake ms |
|---|---|---|---|
| x1 | 12.8 / 6.7 | 10.9 / 6.2 | 32.5 / 19.0 |
| x4 | 56.8 / 48.2 | 67.7 / 44.9 | 215.7 / 90.7 |
| x6 | 82.7 / 50.9 | 73.8 / 64.0 | 201.1 / 173.5 |

(E1 / E2.) For comparison, T5's own report gives SHOW A MOVE 104 / 153 ms at x4 / x6, and only 9 / 17 ms after a mistake. **E1 and E2 are clearly heavier than T5 after a mistake** (Section 8).

## 6. Why X3 was not delivered

**Direction chosen from the evidence.** Magnets plus advanced spinners (counter-clockwise, alternating). T5, the expert's hardest board, ran on magnet geometry with plain clockwise spinners only.

**Idea, enforced on every winning line.** A magnet drags a counter-clockwise or alternating spinner into a new neighbourhood, where a different departure turns it before it leaves. The expert has to track a turn rule across a change of place. For the alternating rule, that means tracking the rule's memory.

**Attempts:**
1. A 16-piece version reached the expert gates on some habits. But the solver work was far over the mobile budget: solution check about 100 ms, SHOW A MOVE 230-570 ms, against 40 ms.
2. Compact versions, capped at 13 pieces, are cheap (under 10 ms). The best, with a designed alternating spinner beside the magnet, reached:
   - luckiest expert learner 10, then 8 with full measurement (12 needed);
   - 6-move greedy 6.7-7.5 % (5 % maximum).

**Process.** Four concepts, about 15 refinement runs and three one-edit screens.

**Decision.** Lowering the expert gate after the fact would remove the one thing separating the boards he found HARD from the one he found VERY HARD, so it was not lowered. X3 needs a different, smaller mechanism, perhaps a single alternating spinner carried twice, rather than more search.

## 7. The blind test: `?xtest8=1`

**Setup:**
- its own board file (`data/dev/extreme8.json`) and its own storage (`user://extreme8_state.json`, localStorage `chain_escape_xtest8_state`);
- titled "PUZZLE TEST";
- random order, neutral ids (E1 / E2), no titles, no mechanic labels, no explanations, no difficulty label;
- tools as live VERY HARD: UNDO x3, SHOW A MOVE x1, HAMMER x0; normal restart behaviour; hearts not changed.

**After each puzzle:**
1. difficulty EASY ... EXTREME;
2. vs Level 300;
3. enjoyment 1-5;
4. achievement 1-5;
5. fairness;
6. planning;
7. combination of mechanics;
8. **optional free text**: "what made this puzzle difficult or interesting?" (NEXT or SKIP).

**Recorded automatically:**
- solve time, restarts, UNDO, SHOW A MOVE, blocked taps, give-ups;
- the time-stamped move log, with each move's **mechanism events** read from the board: gates opened, blocks pulled, arrows reversed by a switch, spinners turned, shells cracked. A per-puzzle total is also kept.

At the end: "Which puzzle was the hardest, and why?" Then COPY RESULTS.

**Campaign progress, as on every pilot page:** E1 is offered from Level 121, E2 from Level 151. An expert who answers "all 300 levels" gets both.

**Open:** `index.html?xtest8=1` from `build/dev_qa/chain_escape_dev_extreme8.zip`. Phone timing: `index.html?xtest8=1&bench=1`.

## 8. Limitations and risks

- **Calibration is three boards and one player.** The expert gates are a reasoned screen, not a validated predictor. Machine scores are not difficulty claims.
- **Timing margin.** On native desktop, E1's repeated runs are 30-34 ms of 40, and SHOW A MOVE after a mistake in the real screen reached 44 ms once (E2). The throttled simulations reach about 200 ms after a mistake. **Run `&bench=1` on the expert's iPhone before or during the test.** If it is slow, SHOW A MOVE after a mistake will lag but still answer correctly; no crash or hang was seen.
- **E1 is at the 16-piece limit and dense.** E2 is easier to read, but its turn count (three turns, two of them from magnets) may be found by careful counting rather than discovery.
- **Hybrid process.** Cores, chains and the decisive edits are by hand; some periphery pieces came from restricted search. Every piece is shown to be needed, but not every piece carries a meaning a player would name.
- **X3 not delivered** (Section 6).
- **Free text on iPhone.** It uses the same text field as the existing "why" box on the hardest-puzzle screen; typing on a real iPhone was not tested here.

## 9. Recommendation for the next expert test

1. **Bench first.** Send the ZIP to the experienced player (the older son) first, alone, before he sees anyone else's results. Ask for `&bench=1` on his iPhone.
2. **What to compare.** Compare his restarts, time and ratings on E1 / E2 with his T5 (13 restarts, 120 s, VERY HARD) and H2 (1 restart, 33 s, HARD).
3. **Watch** whether the "release spinners early" habit shows in his move logs (the mechanism events show turns).
4. **What counts as a pass.** Treat "EXTREME, or VERY HARD with many restarts, and fair = YES" from him as a first signal only. Then recruit at least two more expert players before drawing conclusions.
5. **If he finds them HARD,** the deep-lookahead measures did not capture what makes his play strong. The next step is to study his move logs, not to tighten machine gates.

## 10. Tests

| Test | Result |
|---|---|
| `Extreme8Check` (new) | 88 / 88 in 2 of 3 runs; the third failed on one 43.7 ms SHOW A MOVE press (Section 5) |
| `web_xtest8_page_test.mjs` (new) | 19 / 19 |
| `VhVal3Check` / `Extreme7Check` / `Extreme6Check` / `Extreme5Check` | 98 / 84 / 85 / 145 (all passed) |
| `Extreme6Parity` / `VhPilot4Check` / `VhHumanTestCheck` | 35 / 439 / 100 (all passed) |
| `MagnetCheck`, `RevealMvpTest`, `FriendFlowTest` (149), `SocialPlayTest` | passed |
| Browser `?vhval3` / `?xtest7` / `?xtest6` / `?xtest5` / `?vhtest4` / `?vhtest` | 21 / 21, 15 / 15, 14 / 14, 19 / 19, 14 / 14, 17 / 17 |

(The `Extreme5Check` and `VhPilot4Check` counts vary by design with the randomly first board's reminder lines.)

**Dev ZIP:** `build/dev_qa/chain_escape_dev_extreme8.zip` (git-ignored, not uploaded), 13,102,522 bytes, SHA-256 `f3b34bfb215cadd0b52e8ff523662e51a83bd9b1929caee27cfc74e3a51729dd`. It also contains every earlier test page, unchanged; the earlier ZIPs are untouched.

## 11. Changed files

**New (this experiment):**
- `data/dev/extreme8.json`, `data/dev/extreme8_notes.json`
- `docs/extreme8.md`
- `tools/expert_probe.gd`, `tools/extreme8_calibrate.gd`, `tools/extreme8_events.gd`, `tools/extreme8_build.gd`, `tools/extreme8_lab.gd`
- `tools/extreme8_check.gd`, `tools/Extreme8Check.tscn`
- `tools/web_xtest8_page_test.mjs`

**Modified (this experiment):**
- `scripts/social/vh_human_test.gd`:
  - the `xtest8` entry and header;
  - `X8_QUESTIONS`, including the optional free-text question type `["TEXT"]`;
  - mechanism events in the move log (only when a test sets `mech_events`);
  - the intro's question count now goes up to "eight".

  Every earlier mode's behaviour is unchanged and re-tested.

**Pre-existing uncommitted work from earlier steps (not part of this experiment; preserved):**
- the phase 2, phase 3 (H1 / H2) and three-board validation files;
- the earlier edits to `vh_human_test.gd`, `extreme5_build.gd`, `extreme5_check.gd`, `vh_pilot4_build.gd` and `vh_pilot4_check.gd`.
