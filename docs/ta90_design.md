# Phase 14: the 90-second puzzle design pipeline (development only)

Tools: `tools/ta90_design.gd` (the design report), `tools/ta90_search.gd` (the bounded constructive search).
Data: `data/dev/ta90_search/` (cores, seeds, every search log and result, the final design reports).
Nothing here touches Production, the 300 frozen levels, Supabase, the Social MVP or Challenge a Friend.

## 1. Why P5 and P6 failed (Phase 13 / 13B)

Both boards were measured again with the new design report (`ta90_design.gd`, categories below):

| | P5 (chain gate + spinners) | P6 (shell + alternating spinners) |
|---|---|---|
| Pieces / positions / solution | 10 / 98 / 9 | 8 / 57 / 9 |
| Losing moves per step along the solution | 3 2 1 1 0 0 0 0 0 | 2 2 2 1 1 0 0 0 0 |
| **Distinct** mistakes | 3 (`r1c1<`, `r4c1v`, `r4c2v`) | 2 (`r2c2v`, `r3c4>`) |
| A decision in the last third | no | no |
| Mechanic with it neutralised | the same 4 decision steps / 3 mistakes: **decoration** | the same 5 / 2: **decoration** |
| Greedy players (best) / 6-move lookahead greedy | 14% / 29% | 10.5% / 33% |
| Expert learners | 1 / 0 | 0 / 0 |

Root causes, split by category:

- **A (technical): none.** Both boards parse intact, solve, replay deterministically, and stay within 700 positions and 40 ms. They failed only on quality.
- **B (strategic): every failure is here.**
  1. *One lesson, repeated.* The "decision steps" were mostly the same wrong move offered again at the next step: P5 `r1c1<` (the link leaving early) is wrong at steps 1-4, and P6 repeats `r2c2v` and `r3c4>` at steps 1-5. Anyone who fails once avoids it from then on, which is why the learners find 0-1 dead ends.
  2. *A free endgame.* No decision after the first half: the last four or five moves are forced or free.
  3. *A decorative mechanic.* Without the gate (P5) or the alternating rule (P6), the board plays exactly the same.
  4. *Growth without dependency.* The beam search added arrows that raised the solver measures (positions, hidden losing moves) without joining the board's dependency chain.
- **C (estimates):** the solver scores looked respectable (decisions K4 = 3, deepest trap 7), but they did not mean the board was engaging. They are reported, and they never decide on their own.
- **Process:** the Phase 13 screens tried every edit of every board at full cost (about 20 min a round, thousands of candidates). Strategy did not change when the measures stalled.

## 2. The three categories (`tools/ta90_design.gd`)

- **A, hard technical (mandatory, never weakened):**
  - the map parses intact into a well-formed, verifiable puzzle with a fingerprint;
  - it is solvable;
  - the Solver agrees with exhaustive search in **every** reachable position, for solve and hint (parity);
  - the solution replays to an empty board through `BoardModel` (the play screen's rules), twice and identically;
  - at most 700 positions, and solving takes at most 40 ms (worst of 5 runs);
  - SHOW A MOVE work is reported (the 90 s mode has no SHOW A MOVE).
- **B, strategic quality (the design's own checks):**
  - the idea holds on **every** winning line (exhaustive facts);
  - the mechanic is **not decoration:** neutralising it makes the board unsolvable, or changes its decisions;
  - **distinct** mistakes along the solution, where one mistake repeated step after step counts once;
  - decision steps;
  - a decision in the endgame (the last third), for HARD and VERY HARD;
  - **no trivial shortcut:** no simple greedy player wins more than 20%.

  | Target | Distinct mistakes | Decision steps | Endgame decision |
  |---|---|---|---|
  | MEDIUM | ≥ 2 | ≥ 3 | not required |
  | HARD | ≥ 3 | ≥ 4 | required |
  | VERY HARD | ≥ 4 | ≥ 5 | required |

- **C, difficulty estimates (diagnostic only):** greedy players, 6-move lookahead greedy, expert learners, decisions lookahead cannot settle, hidden losing moves, the deepest trap, positions, win share.

**Verdict:**
- **REJECTED:** any A failure.
- **NEEDS WORK:** A holds and a B check fails (the reasons are listed).
- **HUMAN-REVIEW CANDIDATE:** A and B both hold. This is never "approved": people decide.

The targets (MEDIUM / HARD / VERY HARD) are design intentions, not validated ratings.

## 3. The constructive method (`tools/ta90_search.gd`)

1. **Idea first:** a hand-drawn core of 4-7 pieces whose idea already holds on every winning line, with the critical dependency stated (see §4).
2. **Grow only where it interacts:** an edit adds or changes a plain arrow or spinner only on an empty cell next to a piece (its leaving turns a spinner or frees a lane), or in the row or column of a core piece. Designed pieces (switches, flip targets, gates, links, shells) and the core's cells are frozen.
3. **Score the B checks, not solver depth.** These are filters:
   - solvable within the position cap;
   - the idea on every line.

   These make the score:
   - distinct mistakes and decision steps;
   - decisions spread over the opening, middle and endgame;
   - a decision in the endgame;
   - each mechanic mattering (counterfactual);
   - a penalty for a greedy shortcut;
   - a small penalty for every piece over 8.
4. **Small batches:** 40 sampled edits a round, a beam of 5, and a time budget in minutes. The search stops when the best board has not improved for `--patience` rounds; then the **strategy changes** (it does not just run longer).
5. **Full report** (`ta90_design.gd`, A + B + C) on the best boards only.

## 4. The three designs

The targets are design intentions; none is a validated rating.

### 14A → N1 (target MEDIUM): "the switch must wait"

- **Idea:** a switch reverses two blocks.
  - One of them (the right-hand link) can only leave *after* the reversal.
  - The other (the up-pointing target) must leave *before* it. Reversed, it points down into a block that points back at it: a deadlock.
- **Critical dependency:** the target's lane is closed by a spinner, which only opens after its neighbour leaves. So the switch has to wait for a two-step opening.
- **Core:** 7 pieces. The switch is unsolvable without its mechanic (the counterfactual).
- **Growth:** 2 searches, about 1,500 boards evaluated. The second search used a stronger shortcut penalty, which took the greedy shortcut from 32% to 3%.
- **Final:** 11 pieces.

### 14B → N2 (target HARD): "ram once, at the right moment"

- **First core rejected:**
  - In it, the ram was always free and always right, so a greedy player won every time (100%).
  - Three searches (about 1,800 boards) stalled with a 38-48% shortcut. That's a flaw in the idea, so the core was redrawn rather than searched longer.
- **Redrawn idea:** the chain gate's only link is itself armored. The only block that can ram it is a clockwise spinner with two free neighbours.
  - Exactly one neighbour may leave before the ram.
  - If both leave, the spinner turns past the shell and the board is lost.
  - The block behind the gate escapes through the gate cell.
- **Growth:**
  - 2 seeds: one had no endgame decision, the other a 22% shortcut.
  - Then 2 endgame-targeted seeds from the better one.
  - About 4,100 boards in all.
- **Final:** 13 pieces. Seed 6 was chosen over seed 7, which is otherwise identical but solves in 32.5 ms against 17.6 ms.

### 14C → N3 (target VERY HARD): "a reversal opens the gate"

- **Idea:** the gate's link points into a block that points back at it, so it can leave only after the switch reverses it. Its leaving opens the gate for the last block (`flip_opens_gate`, on every winning line).
- **Growth:** 3 searches, about 2,700 boards. The shortcut fell from 100% to 15%, and distinct mistakes rose from 0 to 4.
- **Final:** 14 pieces.

## 5. Search log (every run is in `data/dev/ta90_search/`)

| Run | Seed / strategy | Rounds | Boards evaluated | Stopped | Best: pieces / positions / distinct / steps / endgame / mechanic / shortcut |
|---|---|---|---|---|---|
| `search_14A` | core, shortcut weight 25 | 24 | 631 | no gain for 8 rounds | 10 / 121 / 2 / 5 / no / 1 of 1 / 32% |
| `search2_14A` | from that best, weight 80 | 32 | 899 | no gain for 15 | **11 / 173 / 4 / 6 / no / 1 of 1 / 2.5%** → N1 |
| `search_14B` | first core, weight 25 | 43 | 1391 | no gain for 8 | 11 / 56 / 5 / 6 / yes / 2 of 2 / 48% |
| `search2_14B` | from that best, weight 80 | 16 | 449 | no gain for 15 | 12 / 121 / 5 / 7 / yes / 2 of 2 / 38% |
| `search3_14B` | first core again, weight 80 | 16 | 554 | stopped by hand (no gain, 28%) | **first core rejected** |
| `search_14B2_s4` | redrawn core, weight 80 | 53 | 1518 | no gain for 15 | 12 / 298 / 5 / 5 / **no** / 2 of 2 / 7.5% |
| `search_14B2_s5` | redrawn core, weight 80 | 33 | 1021 | no gain for 15 | 12 / 218 / 4 / 4 / yes / 2 of 2 / 20% (22.5% in full) |
| `search_14B2_e6` | from s4, endgame weight 25 | 25 | 696 | no gain for 15 | **13 / 334 / 5 / 9 / yes / 2 of 2 / 0%** → N2 |
| `search_14B2_e7` | from s4, endgame weight 25 | 32 | 866 | no gain for 15 | the same board with one block changed; solves slower |
| `search_14C` | core, weight 25 | 24 | 800 | no gain for 8 | 11 / 28 / 3 / 8 / yes / 2 of 2 / 50% |
| `search2_14C` | from that best, weight 80 | 27 | 846 | no gain for 15 | 13 / 61 / 3 / 10 / yes / 2 of 2 / 17.5% |
| `search3_14C` | from that best, weight 80 | 33 | 1028 | no gain for 15 | **14 / 58 / 4 / 11 / yes / 2 of 2 / 12.5%** → N3 |

Each search took 1-6 minutes of wall time; at most three ran at once. In the table, "distinct" means distinct mistakes and "steps" means decision steps.

## 6. Results (`data/dev/ta90_search/final_report.json`)

**Category A, hard technical: all pass.**

| | N1 | N2 | N3 |
|---|---|---|---|
| Fingerprint | `b5bb75f5…377bff` | `f4be705f…e76d695f` | `76d704de…5f2272c` |
| Positions (winnable) | 173 (31) | 334 (53) | 58 (17) |
| Solver / exhaustive parity (solve / hint) | 0 / 0 | 0 / 0 | 0 / 0 |
| Solution replays to empty through BoardModel, twice | yes | yes | yes |
| Solve, desktop, worst of 5 | 1.7 ms | 17.6 ms | 1.3 ms |
| TIME UP check, worst reachable position (desktop) | 2.6 ms | 16.5 ms | 0.7 ms |
| Full solve in WebAssembly (headless Chromium, `&bench=1`) | 1.2 ms | 19.8 ms | 0.4 ms |
| SHOW A MOVE work (nodes; not used in 90 s) | 27 / 29 | 123 / 140 | 3 / 3 |

**Category B, strategic quality: all pass their target's checks.**

| | N1 (MEDIUM) | N2 (HARD) | N3 (VERY HARD) |
|---|---|---|---|
| Idea on every winning line | `reversed_escape` | `gate_through` + `shell_rammed` | `flip_opens_gate` |
| Distinct mistakes | 4 (`r1c1^`, `r1c3^`, `r2c3v`, `r3c2<`) | 5 (`r2c1^`, `r2c5>`, `r3c0<`, `r3c2^`, `r4c1v`) | 4 (`r0c0^`, `r2c5v`, `r3c0>`, `r2c2>`) |
| Losing moves per step along the solution | 4 4 3 3 1 1 0 0 0 0 0 | 5 4 4 1 1 1 1 1 1 0 0 0 0 | 3 2 2 2 1 1 1 2 1 1 1 0 0 |
| Decision steps / endgame decision | 6 / no (not required) | 9 / yes (step 9 of 13) | 11 / yes |
| Mechanic neutralised | switch: unsolvable | armor: 5 steps, 1 mistake (was 9, 5); gate: 11, 6 | switch: unsolvable; gate: 8, 3 (was 11, 4) |
| Best greedy player (the shortcut check) | 3% | 2% | 15% |

**Category C, estimates: diagnostic only.**

| | N1 | N2 | N3 |
|---|---|---|---|
| Expert learners (look 4 / 6; dead ends) | 2 / 0 | 7 / 7 | 1 / 0 |
| 6-move lookahead greedy | 10% | 3.3% | **43%** |
| Decisions lookahead 4 / 6 / 8 cannot settle | 5 / 3 / 1 | 5 / 3 / 1 | 5 / 3 / 1 |
| Hidden losing moves (6 / 8) | 10 / 4 | 13 / 5 | 3 / 1 |
| Deepest trap / opening (good / legal) | 9 / 1 of 5 | 9 / 1 of 6 | 9 / 2 of 5 |

**Honest reading:**
- **N2** looks like the strongest design. Every measure points the same way.
- **N1** is a compact MEDIUM-type board: an opening with one right move, then a free endgame.
- **N3 has the most decision steps, but its estimates do not support "VERY HARD".** A 6-move lookahead finds the way 43% of the time, and the learners find 0-1 dead ends. Its mistakes are few and repeated (`r0c0^` stays wrong for many steps).
  - It may well play like a MEDIUM-HARD board.
  - Only people can tell; that is the point of the next test.

The verdict on all three is **HUMAN-REVIEW CANDIDATE**, never "approved".

## 7. Limitations and next steps

- **Nobody has played N1-N3.** Every quality statement above is a design check or an estimate. The B checks encode what P5/P6 lacked; they are not proven to predict enjoyment.
- **"Distinct mistakes" counts by tile and arrow.** Two mistakes that teach the same lesson (for example, "don't fire the switch yet") can count twice.
- **The endgame rule is coarse.** "A decision in the last third" is met by N2 at exactly step 9 of 13.
- **The constructive search is random and short.** Other seeds could find better boards. The cores were hand-drawn ideas, and only their growth was searched.
- **Performance was measured in headless desktop Chromium**, not on a phone: 19.8 ms there for N2's one-off TIME UP check. A slow phone could take several times longer. That is still a single call at 0:00, never during play.
- **Next:**
  1. First-exposure sessions on N1-N3, with the recording sheet in `docs/experimental_inventory.md` §4.
  2. Compare the players' ratings with the targets and the C estimates (N3 especially).
  3. Keep or retire the B thresholds based on those results.
