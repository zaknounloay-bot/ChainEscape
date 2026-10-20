# Expert human replay: T5 vs E2 (the older son)

**Method.** His actual move logs were replayed with `tools/human_replay.gd`:
- on the real game rules (BoardModel), on the boards exactly as the pages loaded them;
- after every move, whether the board could still be cleared (the Solver);
- every SHOW A MOVE recomputed (it is deterministic).

**Board identity (fact).** The page fingerprints recomputed from the board files are T5 / V3 = `a6fb5e51…3ca3` and E2 = `527f4bfc…3873`, identical to the ones in the results.

**Integrity (fact).** All 66 T5 moves and all 60 E2 move entries (59 moves + 1 ram) were legal on the board at that moment; no move was unidentified. Totals match the summaries: T5 13 restarts, 7 SHOW A MOVE, 2 UNDO, 5 blocked taps; E2 7 restarts, 5 SHOW A MOVE, 4 blocked taps.

**Missing evidence (fact, not invented).** SHOW A MOVE presses that spend nothing are not logged:
- in a lost position ("can't be cleared from here - try Undo");
- after the attempt's SHOW A MOVE is used.

So we cannot know whether he checked "am I lost?" during the failed attempts. Restarts are not taken as dead ends; every loss below comes from the solver.

## Boards (pieces named as in the timelines; cells RnCm, 1-based)

**T5:**
- magnets: purple at R1C1 (up), green at R1C5 (right), yellow at R5C1 (down);
- clockwise spinners: green R3C2, blue R4C1, purple R4C2, red R4C4, green R5C3, green R6C5;
- plain: green R1C2, red R4C3, yellow R4C5, red R5C4.

The solution's three pulls:
1. the yellow magnet drags the blue spinner up;
2. the green magnet drags the **purple magnet** along the top row;
3. the purple magnet drags yellow R4C5 up.

**E2:**
- magnets: blue at R3C4 (up), red at R6C4 (right);
- hammer: purple clockwise spinner R3C3;
- shell: R7C4;
- spinners: yellow counter-clockwise R4C3, green R5C3, purple counter-clockwise R6C2, blue counter-clockwise R2C7, yellow counter-clockwise R7C2;
- plain: blue R1C7, red R2C2, purple R2C4.

In the timelines below, the arrow is the piece's direction at the moment it was tapped.

## 1. Attempt-by-attempt reconstruction (facts)

### T5 (119.6 s, VERY HARD)

| # | Time | Moves | First losing move (solver) | After the loss | Hint / notes |
|---|---|---|---|---|---|
| 1 | 3.8-17.2 s | Yellow magnet, purple spinner, green spinner, green R1C2, **purple magnet** ... | move 5: **purple magnet R1C1** | 4 more moves, until stuck (4 possible) | the first 4 moves are the correct solution prefix |
| 2 | 20.4-28.9 | **green magnet R1C5** first ... | move 1: green magnet | 6 more (7 possible) | |
| 3 | 38.0-49.6 | Yellow magnet, purple spinner, green spinner, **purple magnet** ... | move 4: purple magnet | 2 more (5 possible) | correct 3-move prefix again |
| 4 | 59.3-68.6 | **green magnet** first ... | move 1 | 7 more (7 possible) | |
| 5 | 77.3 | **green magnet** first | move 1 | **0**: restarted 1.3 s later | |
| 6 | 79.8-91.5 | **green spinner R3C2 right** first ... | move 1 | 9 more; UNDO x2 (still lost: the losing move was the first of the 8 he had made); then 5 blocked taps | |
| 7 | 96.5-97.4 | SHOW A MOVE → yellow magnet (R5C1); plays it | never lost | restart | **hint phase begins** |
| 8 | 98.8 | SHOW A MOVE → yellow magnet | — | restart, no move | |
| 9 | 100.1-101.4 | yellow magnet; SHOW A MOVE → purple spinner R4C2; plays it | never lost | restart | |
| 10 | 102.3 | SHOW A MOVE → yellow magnet | — | restart | |
| 11 | 103.5-104.3 | yellow magnet, purple spinner; SHOW A MOVE → green spinner R3C2 | never lost | restart | |
| 12 | 105.7-106.9 | 3 moves; SHOW A MOVE → green R1C2 | never lost | restart | |
| 13 | 108.3-109.8 | 4 moves; SHOW A MOVE → **green magnet R1C5** | never lost | restart | **the decisive hint** |
| 14 | 111.2-119.7 | the full 13-move solution, **no hint, no mistake, 8.5 s** | never lost | solved | |

### E2 (110.3 s, HARD)

| # | Time | Moves | First losing move (solver) | After the loss | Hint / notes |
|---|---|---|---|---|---|
| 1 | 2.2-14.4 s | **red magnet R6C4** first ... | move 1: red magnet (drags the purple spinner, not the hammer) | 10 more (10 possible) | |
| 2 | 24.0-32.8 | blue R1C7, blue R2C7, purple R2C4, **blue magnet** (the relay: drags the red magnet to R3C4), **red magnet** ... | move 5: red magnet fired with the hammer turned only twice | 6 more (6 possible) | **found the relay unaided** |
| 3 | 34.1-52.4 | (16 s pause), SHOW A MOVE → blue R1C7 | — | restart, no move | |
| 4 | 52.9-66.7 | blue R1C7, blue R2C7; SHOW A MOVE → **yellow spinner R4C3**; yellow, green R5C3, **hammer leaves** (R3C3 up) ... | move 6: the hammer | 6 more | |
| 5 | 68.7-70.8 | 3 moves; SHOW A MOVE → green R5C3 | never lost | restart | |
| 6 | 74.1-76.3 | 4 moves, **hammer leaves** | move 5: the hammer | **0**: restarted at once | |
| 7 | 81.1-90.0 | 4 moves; SHOW A MOVE → purple R2C4; purple R2C4, red R2C2 | never lost | restart | |
| 8 | 97.0-110.3 | 6 moves incl. the relay; SHOW A MOVE → **purple spinner R6C2**; red magnet carries the hammer, ram, ... | never lost | **solved** | |

## 2. First losing moves and repeats (facts)

| | Losing moves | Repeats |
|---|---|---|
| T5 | purple magnet after the correct prefix (attempts 1, 3); green magnet first (2, 4, 5); green spinner first (6) | **purple magnet 2x, green magnet first 3x** |
| E2 | red magnet first (1); red magnet after the relay, too early (2); releasing the hammer (4, 6) | **hammer release 2x** |

**After a loss he usually played on until stuck:**
- T5: attempts 1, 2, 4 and 6 went on 4-9 moves;
- E2: attempts 1, 2 and 4 went on 6-10 moves.

**Exceptions, immediate restarts:** T5 attempt 5 and E2 attempt 6. Whether he recognised the loss himself, or checked with the unlogged free "am I lost?" press, **cannot be determined** (missing evidence).

## 3. Did he learn? (interpretation from the facts)

**T5, without help (attempts 1-6, 0-95 s):**
- He found the correct 4-move opening himself in attempt 1 and the correct 3-move opening again in attempt 3.
- But at the decision point (move 5, which magnet?) he always chose wrong. Twice it was the purple magnet; three times he tried the green magnet, but as the **first** move rather than at move 5.
- He was alternating between two partial strategies. Each held half the answer (the right opening; the right magnet), but **he never combined them in six attempts**.
- **No learning across attempts is visible in that phase.** He switched opening ideas rather than refining one.

**T5, with help (attempts 7-13, 96-110 s):**
- **Hint-walking** (restart + SHOW A MOVE): each attempt is one step longer.
- The first six hints only **confirmed moves he had already played himself**: yellow magnet, purple spinner, green spinner, green R1C2.
- The seventh hint revealed the **missing insight**: the green magnet, **at move 5**.
- He then solved it in 8.5 s without help.

**E2:**
- **Clear learning from attempt 1 to 2:** he dropped the red-magnet-first move and found the **relay** (the blue magnet dragging the red magnet) **unaided**. That is E2's central idea.
- From attempt 3 on, he hint-walked the rest. Only two of the five hints were new information: the yellow spinner's turn and the purple spinner R6C2. The other three confirmed moves he had already played. The hints gave him the turn-count details, not the idea.
- Releasing the free hammer was **repeated twice** (attempts 4 and 6). The second time he restarted at once, which suggests he recognised it, but that is not provable (see above).

## 4. What SHOW A MOVE revealed at each logged request (facts, recomputed)

| | Hint 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| T5 | yellow magnet (known) | yellow magnet (known) | purple spinner (known) | yellow magnet (known) | green spinner (known) | green R1C2 (known) | **green magnet at move 5 (new: the key)** |
| E2 | blue R1C7 (known) | **yellow spinner R4C3 (new)** | green R5C3 (known: played in attempt 4) | purple R2C4 (known from attempt 2) | **purple spinner R6C2 (new)** | — | — |

**Every logged hint was requested in a winnable position**, and so every one spent the attempt's SHOW A MOVE. No logged hint fell in a lost position, as expected, because those presses are not logged.

## 5. Classification of his play

| | T5 | E2 |
|---|---|---|
| Critical insights found **unaided** | the opening (4 moves), twice | the **relay** (central idea), attempt 2 |
| Critical insights from **SHOW A MOVE** | **which magnet, and when** (the key) | the hammer's turn count (yellow spinner) and the purple spinner R6C2: late tidy-up |
| Trial and error | 6 unaided attempts alternating two wrong plans, 3 repeats | 2 attempts, then a repeated hammer release |
| Hint-walking | attempts 7-13 (7 hints in 14 s) | attempts 3-8 (5 hints over 60 s) |
| Forced or obvious stretches | the 4-move opening (found at once); after the green magnet, the last 8 moves | blue R1C7 / blue R2C7 opening (always played first) |

## 6. Why T5 felt VERY HARD and E2 HARD (interpretation, with evidence)

- **T5: about 95 s of failure without help.** Six attempts, no progress at the decision point; he never found the key move himself. The insight was **given** (hint 7), and only after that was it easy (8.5 s).
- **E2: the core insight was his own** within 34 s (attempt 2). After that the difficulty was turn-count bookkeeping, resolved partly with hints. It is plausible that "I found the idea" makes a board feel HARD rather than VERY HARD, even though E2 also took about 110 s.
- **Structural reason (hypothesis supported by the logs).** T5's decision point offers **two magnets that look interchangeable** after a calm opening he finds easily. The right one is right **only at that moment**: the green magnet is wrong as the first move and right as the fifth. He had both ingredients separately (attempts 1/3 vs 2/4/5) and could not combine them. E2's key move (the relay) is the **only** way the red magnet can ever reach the hammer, so it is a discoverable "aha" rather than a timing choice between look-alikes.

## 7. Does unlimited hint replenishment undermine EXTREME? (evidence)

**Yes, in his sessions.**
- **T5:** after six failed attempts, restart + SHOW A MOVE produced the decisive move in **14 s**.
- **E2:** two of the five hints supplied new decisions (the yellow spinner's turn, the purple spinner R6C2); three confirmed known moves.
- **In both:** the final solve came right after the last hint, without a mistake.

With SHOW A MOVE refilled on every RESTART, any board can be "walked" one move per restart, so solve time and restarts partly measure hint-walking. In T5, attempts 7-13 are pure hint-walking (about 14 s).

Changing the rule is your decision, not done here. Options for a future EXTREME test, if you want them:
- no refill on restart;
- or record a "solved without SHOW A MOVE" flag;
- or log the free lost-check presses (Section 0).

## 8. Design lessons (from these two sessions; one player, so to be confirmed)

1. **A timing choice between look-alikes beat him; a single "aha" did not.** T5's two magnets, each right at a different moment, defeated him for 95 s. E2's relay, a unique mechanism, he found in attempt 2.
2. **Insight should not be reducible to one highlighted move.** He needed only one revealed move in T5. A board where the critical decision is a *combination* (two choices that are each plausible but only right together) cannot be unlocked by one SHOW A MOVE. But under refill-on-restart, any board can still be walked.
3. **Easy, correct openings are fine, and probably useful.** He found the T5 opening at once, and that sent him confidently into the trap at move 5. A calm, correct prefix that ends at a hard choice is what made T5 hard.
4. **Repeated mistakes cluster on "free" pieces:** the hammer in E2, and the green magnet first in T5. Free-but-wrong pieces work as traps, but he learns them within 2-3 attempts.
5. **Delayed failure keeps him playing.** After a loss he usually played on 4-10 moves until stuck. Losses that show late cost him time and restarts; losses that show at once (E1's stand-offs) do not.

## 9. "The conveyor", reassessed

- **What holds:**
  - several magnets whose pull order decides which block travels where (T5's look-alike magnets were the core of his VERY HARD);
  - long-reach geometry changes;
  - no visible stand-off traps;
  - a small board.
- **What changes:**
  - **Make the key decision a timing choice between look-alike magnets**, each correct at a different moment (T5's lesson), rather than a unique "aha" mechanism (E2's relay was found quickly).
  - **Put a calm, correct opening before it**, so the player reaches the decision confidently.
  - **Make the decision a pair:** e.g. which magnet AND whether to pre-turn the travelling spinner, so that one highlighted move does not settle it.
- **Validation under the hint confound:**
  - measure **unaided progress**: time and attempts before the first SHOW A MOVE, and the deepest winnable prefix reached unaided (T5: 4 moves; E2: the full relay at move 4);
  - compare against T5 on the same measure, with the same player and at least two other experts;
  - if you decide to, also run one condition without refill on restart.

## Files

- New: `docs/extreme10_replay.md` (this report).
- Tools used unchanged: `tools/human_replay.gd`.
- No game code, boards or tests were changed; nothing was committed.
