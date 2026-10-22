# EXTREME phase 7: The Conveyor (Q1), two-player human replay

Evidence-based analysis of the two real sessions of Q1 (`?ptest11=1`,
docs/extreme11.md). No board, game code or SHOW A MOVE rule was changed;
nothing was committed, pushed or deployed. Q1 / ptest11 stays uncommitted, as
it was after technical QA.

Labels used below:
- **[fact]**: verified by replaying the log on the real rules.
- **[interpretation]**: a reading of the facts.
- **[hypothesis]**: plausible, not provable from these logs.

Board, rows and columns counted from the top left (R1C1). Block ids are the
ones in the logs:

```
      C1    C2    C3     C4    C5    C6
R1    .     .     .      .     0     1          0 P<   1 lock spinner (clockwise)
R2    .     .     .      .     .     2          2 magnet C (up)
R3    3     .     4      5     6     7          4 H (counter-clockwise spinner)   5 queue spinner   6 Y^   7 magnet B (right)
R4    .     .     .      .     .     .          3 spinner facing right
R5    .     .     .      .     .     .
R6    8     9     10     11    .     12         8, 9 spinners   10 magnet A (down)   11 P<   12 the shell
```

The core of the solution, in order:
1. Unload the conveyor: 0, 1, 6, 5. The queue spinner's leaving turns H to
   face down.
2. Magnet B (7) carries H to R3C6.
3. H rams the shell.
4. Magnet C (2) turns H and lifts it out.
5. Clean-up.

## 1. Verification of the logs [fact]

| Check | Player A | Player B |
|---|---|---|
| Page fingerprint (`PuzzleDefinition.fingerprint()` of the stored Q1) | `3fc4f925…3711`: matches | matches |
| (board-file fingerprint, SHA-256 of the map JSON) | `84c131e1…88f8` (differs by design) | |
| Events, timestamps strictly increasing | 84, yes | 102, yes |
| Every logged move legal on the replayed board | 64 / 64 | 86 / 86 |
| Logged mechanism events equal to the replayed move's effects, move by move | 64 / 64 | 86 / 86 |
| Mechanism totals | pull 17, turn 36, ram 1: match | pull 22, turn 45, ram 2: match |
| Moves in the summary | 63 = 64 logged minus 1 ram (rams are counted separately) | 84 = 86 minus 2 rams |
| UNDO restores the previous position, RESTART the start | yes (2 / 8) | yes (2 / 9) |
| SHOW A MOVE | 1 press, spent, "lost" (the position was lost) | 1 spent ("lost", position lost); 2 refused ("none", both in winnable positions) |
| Final position | board empty (solved) | board empty (solved) |

Tools: `tools/human_replay.gd` (the per-attempt reconstruction, winnability
after every move by the solver, the SHOW A MOVE outcome against the replayed
position), plus a one-off per-move effect comparison using the page's own
`mech_events` logic.

"Attempt" below = one play from the start, ended by RESTART or the solve.
"Prefix" = how many moves were played before the board became unwinnable.

## 2. Player A (father): attempt by attempt

Completion was helped by the older son in a way the log does not show. **The
final attempt is not counted as independent.** Nothing below infers what was
said.

| # | Time (s) | Moves played (block) | First losing move | Moves after it | Prefix | Note |
|---|---|---|---|---|---|---|
| 1 | 3.7-18.2 | 0, 1, **7**, 10, 2, 6 | move 3: **B fired early** (queue still loaded: B carries Y^) | 3 | 2 | |
| 2 | 21.9-39.7 | 0, 6, 1, **7**, 2, 10, 9, 4, 3, 5, then 2 blocked taps | move 4: **B early** (carries the queue spinner, H still behind it) | 6 | 3 | one item further unloaded than attempt 1. Ended with NO legal move (R6C1 facing right against R6C4 facing left, and the shell): the blocked taps came in a dead position |
| 3 | 49.5-54.9 | **10**, 9, 4, SHOW A MOVE | move 1: **A fired first** (pulls H down column 3) | 2 | 0 | **the only hint: "can't be cleared"**, spent |
| 4 | 62.0-72.3 | 0, **7** -> UNDO, 6, **7**, 1 | move 2: B early (undone), then B early again after Y^ | 1 | 2 (P<, Y^) | UNDO used, same mistake one item later |
| 5 | 98.2-100.9 | 0, 1, **7** | move 3: B early | 0 | 2 | exact repeat of attempt 1 |
| 6 | 109.0-122.9 | 0, 6, 5, **10**, 7, 8, 9 | move 4: **A fired** with the queue fully unloaded | 3 | 3 | **reached the key decision unaided** (H is now first in both A's and B's lines), chose A |
| 7 | 132.1-163.1 | 0, 1, 6, **7**, 2, 10, 3, 9 -> UNDO, 8, 9, 4, 11, 5 | move 4: B early (queue spinner still loaded) | 9 (+1 UNDO, still lost) | 3 | back to the attempt-2 mistake; longest play in a lost position |
| 8 | 191.7-204.5 | 0, 6, (6 blocked taps), 5 | **never lost** | - | 3 | at the key decision again; RESTART from a winnable position. Pauses of 17.1 s and 11.4 s |
| 9 | 228.3-240.7 | 0, 1, 6, 5, **7**, 4 ram, **2**, 4, 3, 8, 9, 10, 11, 12 | never lost | - | 14 | flawless, 12.4 s, after a 20.8 s pause |

Repeated losing decisions [fact]: B early in attempts 1, 2, 4, 5, 7; A early
in 3 and 6. He never fired magnet C early.

[interpretation] Player A's main obstacle was the conveyor rule, "B takes the
NEAREST block". He fired B five times before H was first in its line.
Twice (attempts 6 and 8) he reached the key position unaided. Once he chose
the wrong magnet (A); once he restarted without choosing. Attempt 9 is the
first in which B was fired at the right moment, and it was executed without
any error, including the end-game order. Whether that reflects his own
insight, the son's help, or both cannot be told from the log. The unlogged
help could have come at any time.

**Unaided progress [fact]:** at most 3 winnable moves in attempts 1-8. That is
the full unloading, reached in attempts 2, 6, 7 and 8. The page's
`unaided_max_cleared = 10` counts blocks cleared even after the board was
already lost (attempt 2). The replay's prefix (3) is the meaningful number.

## 3. Player B (experienced older son): attempt by attempt

| # | Time (s) | Moves played (block) | First losing move | Moves after it | Prefix | Note |
|---|---|---|---|---|---|---|
| 1 | 4.3-19.9 | 0, 1, **2**, 7, 10, 6, 5, 3, 8, 9, 4, 11 | move 3: **C fired as soon as it was free** (drags magnet B up) | 9 | 2 | played on to the end |
| 2 | 24.4-42.4 | 0, 1, 6, **7**, 2, 10, 5, 3, 8, 9, 4, 11 | move 4: **B early** (carries the queue spinner) | 8 | 3 | no longer C first |
| 3 | 60.5 | **7** | move 1: B first | 0 | 0 | 21.6 s pause, then RESTART |
| 4 | 82.8-92.2 | 0, 1, **2**, 7, 6, 5, 10, SHOW A MOVE | move 3: C early (repeat of attempt 1) | 4 | 2 | **hint spent: "can't be cleared"** (the position had been lost for 5 moves) |
| 5 | 94.8-101.0 | SHOW A MOVE x2 (refused), 0, 1, **2**, 6 | move 3: C early (third time) | 1 | 2 | both presses refused at the start, in a winnable position: "No SHOW A MOVE left in this puzzle", no information |
| 6 | 107.4-116.3 | **10**, 0, 1, 6, 7, 2, 5 | move 1: **A first** | 6 | 0 | a new plan: magnet A |
| 7 | 117.8-128.1 | 0, 6, 5, **10**, 7, 1, 2, 3, 8, 9 | move 4: A, with the queue fully unloaded | 6 | 3 | **reached the key decision**, chose A |
| 8 | 134.7-140.4 | 0, 6, **10**, 7, 1, 2 | move 3: A early | 3 | 2 | |
| 9 | 146.5-167.2 | 0, 1, 6, 5, **7**, 4 ram, **2**, 4, 10, **9**, 3 | move 10: R6C2 spinner left down (end game) | 1 | **9** | **the whole core correct, unaided**; lost in the clean-up |
| 10 | 176.2-199.6 | same 8-move core, 3, 10, **9** -> UNDO, UNDO, 8, 9, 10, 11, 12 | move 11: the same end-game move | 0 (two UNDOs) | 10, then solved | solved with UNDO |

Repeated losing decisions [fact]: C early in 1, 4, 5; B early in 2, 3; A
early in 6, 7, 8; the end-game move in 9, 10.

[interpretation] **A clear elimination sequence.** He tried each magnet at the
wrong moment, grouped by magnet: C too early, then B too early, then A at the
key decision. Then the correct core. These are three distinct timing errors,
one per magnet, which is what the design intended: three timing magnets,
each wrong at a different moment. He never fell back to a magnet error he had
already left behind, counting the move that lost each attempt: after
attempt 5, C early never lost an attempt again; after attempt 3, B early never
lost an attempt again. Moves played after an attempt was already lost are not
counted.

## 4. Player B's final three attempts (8, 9, 10)

**What changed from 8 to 9 [fact]:** in attempts 7 and 8, with H first in
both A's line (column 3) and B's line (row 3), he fired **A**, which takes H
down into the shell's row. In attempt 9 he fired **B** at that moment, and
also completed the unloading first (in 8 he fired A before the queue spinner
left). Then he rammed, then fired C (extracting H), then let H out.
- **Correct in attempt 9:** moves 1-9, i.e. the core plus magnet A, which is
  harmless once H has gone.
- **Where it became unsolvable:** move 10. The spinner at R6C2 left
  downwards while the spinner at R6C1 was still there. Its leaving turned
  R6C1 (clockwise) from up to right, so it faces R6C4 (facing left), with no
  spinner left to turn either. A static stand-off: lost at once [fact].

**What changed from 9 to 10 [fact]:** the identical 8-move core, then R3C1
first (it had been last in 9), then magnet A, then the same losing R6C2 move.
**UNDO, UNDO** (the first UNDO already made the board winnable again), then
R6C1 up first (turning R6C2 down), R6C2, A, R6C4, the shell. Solved.

- **New strategic insight?** [interpretation] The key insight, B rather
  than A at the crossing, with the conveyor unloaded and C after the ram, was
  **new in attempt 9** and repeated exactly in attempt 10. That is evidence
  that it was understood, not stumbled on. The change from 9 to 10 was a
  **correction of the end-game order**, a visible spinner-turn trap, not a
  strategic insight.
- **Did UNDO enable the final solution?** [fact] Yes, for the end game: without
  it, attempt 10 was lost at move 11 and would have needed an 11th attempt.
  The core did not depend on UNDO.
- **Did he find the key sequence without a winning hint?** [fact] Yes. The only
  spent hint (attempt 4, 92.2 s) answered "can't be cleared" in a position
  that had been lost since move 3 (C fired early). It named no move. The two
  later presses were refused with the same text in every position.
  [interpretation] The "lost" answer did reveal that the C-early position was
  lost. He still repeated C-early once (attempt 5), and then dropped it.

## 5. The hint rule in use

[fact]
- **Player A** spent his hint on attempt 3 at 54.9 s, after A-first, 2 moves
  into a lost position. He got "can't be cleared" and restarted. He then
  played 6 more attempts (185 s) with no assistance available.
- **Player B** spent his hint on attempt 4 at 92.2 s, in a lost position (C
  early). He then pressed twice at the start of attempt 5 and was refused
  both times; those positions were winnable, but the refusal says nothing
  about that.
- **Neither player received a highlighted move.** No winning-move hint was
  given in either session. Every press, including the refused ones, is in the
  log.
- Both spent the hint in a lost position. Under the old rule those presses
  would have been free and unlimited, and RESTART would have refilled the
  hint. Each player then had zero hints for the rest of the session.

[interpretation]
- The rule did what it was meant to do: no hint-walking (T5 attempts 7-13),
  no free dead-end detector.
- The price is that a player who uses the hint to ask "is this lost?" learns
  only that, and loses all help.
- [hypothesis] Both early presses look like checks on a position the player
  already suspected was lost. The log cannot show intent.

## 6. Fairness (Player A: NO; Player B: YES)

| Question | Finding | Class |
|---|---|---|
| Inconsistent or ambiguous feedback | Every logged effect equals the rules' effect, move by move; no mismatch. The magnet preview draws, for every magnet, a dotted line to exactly the block it would pull (`BoardModel.pull_target`), updated after every move. | verified: no problem |
| Unexpected magnet interactions | A magnet's escape first turns adjacent spinners, then pulls. Magnet C turns H and then lifts it; this decides H's exit. The preview shows the pull target, not the turn. The turn is the ordinary neighbour rule, used throughout the campaign. | plausible surprise; whether it surprised these players is not in the log |
| Hidden information | None. Every piece, arrow, spinner direction, shell and pull target is on screen. | verified: none hidden |
| Legal but visually misleading moves | Magnet A's pull carries H down into the shell's row, which looks like progress, and loses 8-12 moves later. Magnet B fired early carries a queue item, not H. These are designed decoys; both are shown by the preview before firing. | deliberate design, deterministic |
| Severe but deterministic traps | Yes, by design. A lost position can be played on for up to 9 more moves without any signal (A attempt 7; B attempt 1). The only way to learn "lost" is to spend the single hint. | verified property; whether it feels unfair is a matter of taste |
| **An end-game trap not described in the design dossier** | After the core, R6C2 must not leave before R6C1: its leaving turns R6C1 to face R6C4, a static stand-off. It is visible at once and recoverable with one UNDO. **docs/extreme11.md said moves 8-14 have "no losing option".** That is true only along the solver's own order; other clean-up orders contain this trap. It ended A's attempt 2 (the dead position with the blocked taps) and B's attempts 9 and 10. | **verified documentation error** (not a game bug); the dossier's claim is corrected here |
| Repeated blocked taps | A: 2 taps in a dead position (attempt 2); 6 taps in attempt 8 in a winnable position with 4 legal moves and 7 blocked pieces (including H and magnet C). The log does not record which piece was tapped. | unresolvable: the tap target is not logged |

[interpretation] **There is no verified rule, UI or feedback defect.** Three
features plausibly drive the different ratings:
1. Long play in lost positions with no feedback, by design.
2. A strict one-hint rule that a lost-position question uses up.
3. A late end-game "gotcha" after the hard part is done.

The father hit the first two hard: he spent his hint at 55 s and then had no
help for 185 s. [hypothesis] "Unfair" may mean "the board does not tell me
when I am lost" rather than "the rules are hidden". This cannot be confirmed
without asking him.

**Recommendation on fairness:** no change to Q1 is supported by the evidence.
Two small, evidence-backed improvements, outside Q1 and not made now:
- the blind-test page should log **which piece** a blocked tap was on;
- the dossier's clean-up claim should be corrected (done in this report).

## 7. Q1 against T5 (the older son)

| | T5 | Q1 |
|---|---|---|
| Rating / enjoyment / achievement | VERY HARD / 4 / 5 | VERY HARD / 5 / 5 |
| Time / restarts | 119.6 s / 13 | 199.6 s / 9 |
| Hints | 7, refilled by RESTART; hint 7 **revealed the key timing** | 1 spent ("lost"), 2 refused; **no move ever shown** |
| Time without assistance | about 95 s (attempts 1-6) | the whole session; nothing was shown |
| Key insight | **given** by the hint | **found unaided** (attempt 9, 156 s) |
| Distinct wrong plans | two, alternated (purple vs green magnet at move 5) | three, one per magnet, each dropped in turn (C early, B early, A at the crossing) |
| Delayed consequences | traps up to 9 moves deep | played on in lost positions for up to 9 moves (attempt 1); the decoy A loses 8-12 moves later |
| Repeatability of the solution | solved once, 8.5 s after the hint | the core played identically twice (attempts 9 and 10) |
| Remaining error | none after the hint | end-game order, fixed with UNDO |

[interpretation]
- **Q1 is not shown to be "harder" by its longer time.** The conditions
  differ: T5's hints refilled, and the son's experience grew between the
  sessions.
- **Q1 does give clearly stronger evidence of independent mastery.** No
  winning move was ever shown. The insight was reached by eliminating each
  magnet's wrong moment. The correct core was then reproduced exactly.
- On T5, the decisive timing was handed over by the hint system.

## 8. What created the challenge, and lessons for EXTREME

Mechanisms seen in the logs [fact]:
- **One wrong moment per magnet:** C early (B: 3 times), B early (A: 5,
  B: 2), A at the crossing (A: 2, B: 3). Each is a separate lesson.
- **The conveyor rule** ("a magnet takes the nearest block in its line")
  defeated the father most often.
- **The crossing** (H first in two magnets' lines at once) was the son's last
  strategic barrier.
- **A late spinner-turn trap** in the clean-up cost the son two attempts.

Design principles for future EXTREME boards (no new mechanics):
1. **Give each timing piece its own wrong moment.** A player can then learn
   one lesson per restart, and progress across restarts is visible. B's
   attempts drop one class of error at a time.
2. **Make the crossing the central decision.** Two pull lines meeting on the
   same piece, both shown by the preview, so the decision is fully visible
   and still hard. Fair: Player B rated it YES and solved it unaided.
3. **Use a queue ("nearest first") to hide the timing in plain sight.** The
   rule is on screen, but firing too early still looks like progress.
4. **Audit the clean-up as hard as the core.** Check every order of the
   clean-up for traps, not only the solver's order. Keep a late trap only if
   it is intended, visible at once, and recoverable by UNDO; otherwise remove
   it.
5. **Measure learning, not just time.** Count repeated losing decisions and
   the prefix per attempt (the replay's columns), with blocked-tap targets
   logged.

## 9. Recommended next action

**A. Keep Q1 unchanged as the expert difficulty reference.**
- Both players completed it, rated it harder than Level 300, and gave
  enjoyment 5 / 5 and achievement 5 / 5.
- The expert solved it without any move being shown, by learning across
  restarts, and repeated the core.
- No rule, UI or feedback defect was found, so no targeted change is
  supported.
- Changing the board would also make these two sessions incomparable with any
  later ones.

For later, not now: a second prototype could reuse principles 1-4 with the
clean-up audited (principle 4). Before that, the page should log blocked-tap
targets, and Player A's fairness rating could be followed up by asking him.

## 10. Limitations and unanswered questions

- Two players, one family; one play each. The father's final attempt was
  assisted in an unlogged way.
- Blocked-tap targets are not logged, so the 6 taps in A's attempt 8 cannot
  be explained.
- Intent is not in the log: why each player pressed SHOW A MOVE, and what the
  long pauses were.
- The "lost" answer is information. It is not possible to tell whether it
  changed later play: B repeated the same mistake once after it.
- Learning effects: the son had played T5, E1 / E2 and other magnet boards
  before.
- Why the father rated fairness NO is not answered by the data. Only a
  question to him can answer it.
- No iPhone timing data came back with the logs; real iPhone `&bench=1` is
  still outstanding.
