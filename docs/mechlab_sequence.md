# Mechanic lab — SEQUENCE prototype (development only)

> **Decision after the human test: GO.** Not implemented in production yet; the prototype below stays dev-only and unchanged.
>
> The question it answered: does the first stage create a genuinely new timing decision ("WHEN do I use it?"), or is it just "a block that needs two taps"?

**Open it:** the Web build with `?mechlab=sequence`. `?mechlab=1` is still the PORTAL lab, unchanged.

**Nothing in production changes:**
- **Untouched:** Classic levels 1–200, economy, hearts, Hammer, milestones, progression; Friend generation; Photo / Message Reveal; the backend, Supabase, API and sharing. Portal stays dev-only and unchanged.
- **Sequence is not combined with Portal.**

## 1. Rule (as implemented)

A **Sequence block** is a plain coloured arrow with two stages. Map token `R>:^` means: arrow now **right**, NEXT arrow **up**.

**Stage 1:**
- **Clear:** exactly what "clear" means for any block, the whole lane in its current arrow direction up to the board edge.
- **Clear lane:** the tap is an **advance**:
  1. A short launch along the lane and back (greybox, about 0.3 s).
  2. The block stays in its cell.
  3. The **neighbour event** fires around its starting cell.
  4. Its NEXT arrow becomes its arrow (stage 2).
- **Blocked lane:** an ordinary blocked tap (bump; the blocker reacts). The stage does not advance.
- **Lane into a shell:** the existing ram rule applies. The shell cracks, the block stays, the stage does **not** advance.

**Stage 2:** a plain arrow.
- A clear lane escapes and removes it normally; it counts for clearing the board.
- A blocked lane is an ordinary blocked tap.

**The neighbour event** is exactly the one an escape sends from that cell (`BoardModel.remove`), applied to the four orthogonal neighbours:
- Adjacent spinners turn by their own rule: clockwise, counter-clockwise, alternating, pattern (the step counts).
- Adjacent hidden arrows are revealed.
- Nothing diagonal or further away reacts.

**What the advance is *not*:** the block does not leave, so it is not an escape:
- Its colour still holds any lock of that colour.
- It earns no chain.
- A Sequence block is never a switch, gate link, spinner, hidden, locked, reward or armored block; the parser rejects such combinations ("one special role per arrow").

**Lab boards never use NEXT = current arrow** (that would read as "tap it twice").

## 2. Why these semantics

**Stage-1 path = the whole lane, as for an escape:**
- The player reads every arrow the same way. "Can it go?" has one answer for every block.
- The launch shows the lane being travelled.
- A "local" one-cell path would be a new concept to learn and to draw.

**The event = the existing escape neighbour event:**
- That event is the one thing in the engine that drives spinners **and** hidden arrows, in one place.
- Reusing it means no new rule for either mechanic: spinners don't care *why* a neighbour moved.
- Revealing hidden arrows follows naturally from the same event. It was not added to make Sequence interesting.

**Locks, gates, switches unchanged:** they react to blocks *leaving*, and the block doesn't leave.

**The interesting part is stage 1:**
- It turns spinners **without** freeing its cell.
- That is the one thing no existing mechanic can do; today a spinner turns only when space opens.
- So *when* to fire it matters, and that is what the boards test.

**No ambiguity was found that needed a complicated rule.**

## 3. State, Undo, Restart, SHOW A MOVE, Solver

- **Data:** `BlockData.seq_stage` (0 = not a Sequence block, 1 = first stage, 2 = second stage) and `seq_next` (NEXT arrow).
  - `duplicate_data` copies both, so snapshots, Undo and `BoardModel.restore` bring the stage, the first arrow and the turned spinners back.
  - Restart rebuilds from the stored board: stage 1.
  - `to_json_text` writes `R>:^` back.
- **Rules:** `move_state` returns `"advance"` for a stage-1 block with a clear lane; `is_playable` includes it. `BoardModel.advance(id)` performs it.
- **Solver:**
  - Per-block stage, first arrow and next arrow.
  - A stage-1 legal move is the advance: same neighbour turns, then the next arrow.
  - Undo of an advance is its exact inverse; an advance is told apart from an escape because the block is still alive.
  - **Memo key:** the stage bits of every Sequence block are part of the key (the direction follows from the stage).
  - Advances are never applied greedily: the solver branches on them, like moves that turn spinners.
  - Hidden reveal stays derived: a hidden arrow is revealed if a construction-time neighbour has left *or* advanced.
- **SHOW A MOVE:** the solver's next move. For a stage-1 block that is the advance, a normal tap; the checks prove it is always legal.
- **Hammer:** unchanged rule. A Sequence block is smashed whole; the safety check uses the same engine. The lab has no Hammer.

## 4. Isolation

- **Parsing is gated.** The `:` token is parsed only while `LevelManager.dev_sequence` is true. Only the Sequence lab and its dev tools set it.
- **Everywhere else** (game, Social, recipient, Friend) a Sequence cell is an unknown token exactly as before, so:
  - `PuzzleDefinition.verify()` rejects such a board
  - Friend validation rejects it
  - the backend's Friend cell rule (unchanged) rejects it
- **No-change proof:**
  - Levels 1–200: byte-identical `tools/classic_golden.gd` dump before / after.
  - The PORTAL lab boards: byte-identical `tools/mechlab_golden.gd` dump before / after.

## 5. The boards (`data/dev/mechlab_sequence.json`, built by `tools/mechlab_sequence_build.gd`)

**11 Sequence boards + 6 matched controls = 17.**

| Stage | Board | What it is about | Control |
|---|---|---|---|
| A basics | A1 | Stage 1 → stage 2 (right, then up) | — |
| A | A2 | Blocked stage 1 (blue first), then blocked stage 2 (yellow first) | — |
| B timing | B1 | Two Sequence blocks, a spinner next to one; advance at the right moment | B1_CTRL |
| B | B2 | Two Sequence blocks; advancing too early loses (8 early traps on the path) | B2_CTRL |
| B | B3 | Two Sequence blocks; early and late traps | B3_CTRL |
| C spinner | C1 | Teaching: the first stage turns a spinner and breaks a deadlock | — |
| C | C2 | Moderate: the first stage turns spinners next to it | — |
| C | C3 | Deeper: the first stage turns two spinners; the wrong moment loses | C3_CTRL |
| D hidden | D1 | The first stage reveals a hidden arrow next to it | — |
| E depth | E1 | 6×6, 12 blocks, 3 Sequence blocks, spinners | E1_CTRL |
| E | E2 | 6×6, 12 blocks, 2 Sequence blocks, spinners | E2_CTRL |

- **Basics** come first, in order. Then B, C and D are shuffled, then E, per device.
- **A board is never next to its control.**
- **Boards are only numbered.**
- **Controls:** the same board with each Sequence block made a plain arrow (its final arrow), rotated 180°. Same size, blocks, spinners and density; no first stage, so no "when?" decision.

**Solver proxies (information only).** Tests 1–3 showed these don't predict human ratings.
- **Early traps:** states on the solver's path where advancing a Sequence block now is legal but loses.
- **Late traps:** the advance is the only non-losing move.
- **Random-tapper win rate** (Sequence → control):

  | Board | Sequence | Control |
  |---|---|---|
  | B1 | 0.06 | 1.00 |
  | B2 | 0.01 | 1.00 |
  | B3 | 0.05 | 1.00 |
  | C3 | 0.30 | 1.00 |
  | E1 | 0.01 | 1.00 |
  | E2 | 0.03 | 0.28 |

## 6. The lab page

**Demo (about 10 s, WATCH AGAIN):**
1. The big arrow = now, the small corner arrow = next.
2. The first tap launches, comes back, takes the next arrow, and the spinner next to it turns.
3. The spinner can now leave.
4. The second tap: the block leaves.
5. "WHEN you use the first stage matters."

The demo addresses the Portal finding: the rule is shown before any puzzle, step by step, with a caption for each step.

**Tools:** UNDO x3, SHOW A MOVE x1, no HAMMER, RESTART (not punitive).

**Questions** (skippable):

| Asked after | Questions |
|---|---|
| Every board | Difficulty |
| Basic boards | Difficulty, clarity (CLEAR / SOMEWHAT CLEAR / CONFUSING) |
| Sequence boards | Difficulty, what you were thinking about, planning, clarity, interest |
| Controls | Difficulty, what you were thinking about |

- **What were you mainly thinking about:**
  - WHICH BLOCK TO START WITH
  - WHEN TO TRIGGER THE SEQUENCE
  - WHAT THE SPINNER WOULD BECOME
  - THE ORDER OF MY MOVES
  - JUST TAPPING THE SEQUENCE TWICE
  - NOTHING MUCH
- **Planning:** did it make you think about WHEN to activate its first stage? NOT REALLY / A LITTLE / A LOT
- **Interest:** compared with a similar normal puzzle: MORE INTERESTING / NO DIFFERENCE / LESS INTERESTING

**Recorded automatically:**
- completion, time, first action
- escapes, rams, blocked taps
- restarts, UNDO, SHOW A MOVE
- longest pause, pauses ≥ 10 s
- **Sequence-specific:**
  - advances
  - blocked first-stage taps
  - stage-2 escapes
  - spinner turns caused by advances
  - when a first stage was first usable vs first used
  - for every advance: time and how much of the board was already cleared (before / after the dependencies)

**COPY RESULTS:** one JSON with every result, a summary per group (basic / Sequence / control) and each matched pair side by side.

## 7. Interpretation (from the brief)

| Decision | When |
|---|---|
| **GO** | The current / next arrows are understood; the first stage creates real timing decisions; MORE INTERESTING; behaviour shows ordering effects; the spinner interaction feels natural; players don't mainly answer "just tapping twice" |
| **MODIFY** | The timing idea is good but readability or the event rule confuses |
| **DROP** | It is mainly an extra tap; timing rarely matters; clutter without value; existing mechanics already give the same decision |

VERY HARD is not required.

## 8. Known limitations

- **Greybox look:** a white corner disc with the NEXT arrow; a placeholder sound (a re-pitched existing effect); no final effects.
- **Selection bias:** boards were picked with a solver-aided search that favours traps; the controls are much easier on paper by design.
- **Few interactions:** only spinners and hidden arrows interact. Locks, gates and switches react to leaving, so they are unchanged.
- **Small sample:** expect a handful of testers.
- **Lab only:** the level generator, `LevelAnalysis` and Friend generator know nothing about Sequence.
