# Mechanic lab — MOVABLE crate prototype (development only)

> **Status:** a dev-only research prototype, **not approved** (Portal: GO, Sequence: GO, Movable: prototype candidate). One question:
> **does MOVABLE make players reason about the future spatial state of the board — where things will be after their actions — while staying immediately understandable and more interesting than an equivalent board without it?**
> People decide (GO / MODIFY / DROP), not the solver.

**Open it:** the Web build with `?mechlab=movable`. `?mechlab=1` (Portal) and `?mechlab=sequence` (Sequence) are unchanged.

**Nothing in production changes:**
- **Untouched:** Classic levels 1–200, economy, hearts, Hammer, milestones, progression; Friend / Social generation, `SharedChallenge`, the puzzle format; Photo / Message Reveal; the backend, Supabase, Edge Function and sharing.
- **Portal and Sequence are unchanged** (byte-identical lab dumps, §6).

## 1. Rule (as implemented)

A **MOVABLE crate** (map token `M`) is a board object, not an arrow.
- No arrow, no colour role, never escapes.
- The board is **clear when only crates remain**; crates don't count in the progress bar.
- Tapping a crate does nothing; it is a free tap, like a Chain Gate.

**Push:**
- **When it happens:** when the **first thing in an arrow's lane** is a crate. The lane is read exactly as for an escape, through portals; the crate need not be adjacent.
- **What moves:** tapping the arrow launches it into the crate. The crate moves **exactly one cell** in the arrow's direction.
- **What stays:** the arrow stays in its own cell (like a ram). There is no Sokoban-style player movement.
- **Repeats:** any direction, any number of times.

**Blocked push:** an ordinary blocked tap (bump; the crate reacts; no CLUNK). Nothing moves when the cell behind the crate holds:
- a block
- a Chain Gate
- **another crate** (no chain pushing)
- the board edge
- a portal whose exit is blocked

**Through a portal:** if the cell behind the crate is a portal, the crate goes in, comes out of its partner, and lands on the next cell in the same direction. This is the Portal lane rule applied to one step. If that landing cell is taken or off the board, the whole push fails.

**With Sequence:**
- A first-stage Sequence block whose lane meets a crate pushes it. On success it also uses its first stage: the same neighbour event as an advance, then its next arrow.
- On a failed push **nothing** happens, and the block stays in stage 1.

**A push is not an escape:** no neighbour event, no chain, no lock-key change. This matches a ram.

**Locked, hidden, armored and gate blocks can't push.** A shell in the lane is still a ram, as before.

### A rule consequence that shapes every board (please read)

**The last arrow to push a crate stays stuck behind it, unless it can turn.**
1. After a push, the crate is still in the pusher's own lane: it moved along that lane.
2. It can only leave that lane if **another** arrow pushes it sideways, and then it sits in *that* arrow's lane.
3. So the **last** arrow to push a crate can only leave if one of these is true:
   - its direction can change (a spinner, a switch flip target, or a first-stage Sequence block)
   - the crate leaves its lane through a portal

This is a property of the rule as specified, not a bug. Every Movable board therefore has its last pusher on a spinner, and "who pushes last" becomes part of the puzzle.

If it turns out to be confusing (a player pushes with a plain arrow and is stuck), a MODIFY to consider later:
- **(a)** let the pusher follow the crate into the freed cell, or
- **(b)** let a push from an adjacent arrow carry the crate further.

Both change the experiment, so neither is done here.

## 2. Engine (inactive on every board without crates)

| Piece | Change |
|---|---|
| `BlockData` | `Kind.CRATE` (appended; existing values unchanged), `is_crate()` |
| `LevelManager` | `M` parsed **only while `dev_movable` is on** (the lab and its tools); written back by `to_json_text` |
| `BoardModel` | Crate count; `is_empty()` / `block_count()` ignore crates; `move_state` `"crate"` and `"push"`; `push_target()` / `push()`; `last_push` |
| `Solver` | See below |
| `Board` / `BlockView` | Crate look; push animation; Undo resync |
| `SocialPlay` | `"push"` tap → `_push()`: history, counters, push events, placeholder CLUNK |
| `MechLab` | `?mechlab=movable` configuration (Portal / Sequence settings untouched) |

**Solver** (all of it only when crates exist):
- **State:** crate cells are part of the memo key. `PUSH` move bit; pushes undo exactly (a push stack).
- **Win:** `_alive_count == _crate_n`; on every other board `_crate_n` is 0, so nothing changes.
- **Cycle-safe search:** crates can be pushed back and forth, so crate boards use `_dfs_crates`:
  - every legal move is a branch (no greedy escapes: with crates moving into lanes no escape is surely safe);
  - states already on the current path are cut;
  - a state is remembered as lost only when no cut reached above it (Tarjan-style low link), so it never prunes a winning state.
- **SHOW A MOVE** is the solver's next move. Pushes are always "risky" (it prefers them as hints when they are the key move).
- **Hammer** is not used in this lab and gets no crate semantics.

## 3. Look, animation, sound (minimum game feel, required here)

- **Crate:**
  - wooden body with almost square corners and a deeper side (heavier than a block)
  - dark structural frame, plank lines, a diagonal brace
  - four small outward notches, one per direction
  - no arrow, nothing like a coloured block, Shell, Gate, Lock or Sequence chip
- **Successful push (about 0.3 s):**
  - the arrow dashes to the crate and back (like a ram)
  - the crate waits about 60 ms for the hit, slides exactly one cell (about 170 ms), then a small weighted squash-settle
  - a little dust and a slight board thump
  - **CLUNK:** the existing "hammer" thud, re-pitched down (placeholder)
  - through a portal: the crate dives in and pops out (portal flashes)
- **Blocked push:** the usual bump and buzz, and the crate recoils slightly. **No CLUNK.**
- **Reduced motion** (`prefers-reduced-motion`): a short plain slide, no squash or thump.
- **Undo / Restart during an animation:**
  - Undo stops any running slide and puts the crate's view exactly on its restored cell, so no late callback can move it again.
  - Restart rebuilds every view.
  - The Sequence push uses the Sequence resync. Both are tested (§6).

## 4. The boards (`data/dev/mechlab_movable.json`, built by `tools/mechlab_movable_build.gd`)

**11 Movable boards + 6 matched controls + 2 integration checks = 19.**

| Stage | Board | What it is about | Control |
|---|---|---|---|
| A basics | A1 | One push moves the crate out of green's row (pushed up) | — |
| A | A2 | The same, pushed sideways (another direction) | — |
| B position | B1 | The crate sits where it matters; move it away | B1_CTRL |
| B | B2 | Two pushes; a push to the wrong place gets in the way | B2_CTRL |
| B | B3 | The crate must be pushed three times | B3_CTRL |
| C order | C1 | Two pushes are possible; only one leaves it somewhere useful | C1_CTRL |
| C | C2 | Pushing at the wrong moment loses (5 losing pushes along the shortest path) | — |
| C | C3 | Where the crate ends up decides which lane opens later | — |
| D mechanic | D1 | Shell: crack a shell, push, and mind the order (the shortest solution includes a ram) | — |
| E depth | E1 | 6×6, two crates, 3 pushes (9 losing pushes along the shortest path) | E1_CTRL |
| E | E2 | 6×6, two crates, 5 pushes | E2_CTRL |
| F integration | F1 | **Portal:** the crate is pushed through portal A | (not compared) |
| F | F2 | **Sequence:** a first-stage push moves the crate and advances | (not compared) |

**Order:** basics first, then B, C and D shuffled, then E, then the F checks last. Shuffled per device; a board is never next to its control; boards are only numbered. The F boards only ask difficulty and clarity, and are summarised separately.

**Controls:**
- Same board size, arrows, spinners, shells and geometry.
- **Each crate becomes an arrow block** (one per crate), in each of the four directions, **or is removed**. The solvable variant with the **lowest** random-tapper win rate is used: the hardest fair control, never an easy one on purpose.
- Turned 180° so it doesn't look like a replay.

**What the proxies say.** An exact breadth-first search finds min moves, min pushes, losing pushes along the shortest path, and whether a solution needs a push. Tests 1–3 showed proxies don't predict how people rate boards.
- Every Movable board **needs** a push.
- The controls have no losing moves at all, and most are 1.00 random-win: without crates these boards have no traps. That *is* the comparison. Humans decide whether the crate's traps are interesting or just annoying.
- **Random-tapper win rate** (Movable → control):

  | Board | Movable | Control |
  |---|---|---|
  | B1 | 0.20 | 1.00 |
  | B2 | 0.03 | 1.00 |
  | B3 | 0.05 | 1.00 |
  | C1 | 0.09 | 1.00 |
  | E1 | 0.00 | 1.00 |
  | E2 | 0.00 | 0.13 |

## 5. The lab page

**Demo (about 10 s, WATCH AGAIN):**
1. "An arrow launched into it PUSHES it exactly ONE cell."
2. Red hits a crate: it slides one cell, red stays.
3. Blue hits a crate with green right behind it: it CAN'T move.
4. "Crates never need to leave: clear every ARROW block."

**Tools:** UNDO x3, SHOW A MOVE x1, no HAMMER, RESTART (not punitive). Undo / Restart restore everything: crate cells, Sequence stage, spinners, hidden arrows, shells.

**Questions** (skippable):

| Asked after | Questions |
|---|---|
| Basic and integration boards | Difficulty, clarity (CLEAR / NOT CLEAR) |
| Movable boards | Difficulty, focus, planning, clarity, interest |
| Controls | Difficulty, control focus |

- **Focus:** what were you thinking about most?
  - WHERE TO MOVE THE MOVABLE BLOCK
  - WHERE THE MOVABLE BLOCK WOULD END UP
  - THE ORDER OF MY MOVES
  - WHICH ARROW TO START WITH
  - JUST PUSHING IT WHEN I COULD
  - NOTHING MUCH
- **Planning:** did MOVABLE make you think about where the board would be after your move? NOT REALLY / A LITTLE / A LOT
- **Interest:** MORE INTERESTING / NO DIFFERENCE / LESS INTERESTING
- **Control focus:**
  - WHERE THINGS WOULD BE LATER
  - THE ORDER OF MY MOVES
  - WHICH ARROW TO START WITH
  - JUST TAPPING WHAT COULD MOVE
  - NOTHING MUCH

**Telemetry (local only):**
- board id, variant, completion, time, first action
- escapes, rams, blocked taps
- restarts, UNDO, SHOW A MOVE
- longest pause, pauses ≥ 10 s
- **Movable-specific:**
  - pushes, blocked pushes, pushes by direction
  - distinct cells each crate occupied
  - **corrections:** pushes straight back against that crate's previous push, and pushes back onto a cell it already visited in the same attempt
  - first push time
  - Portal pushes, Sequence pushes
  - every push event: time, attempt, crate, from, to, direction, arrows already cleared

**COPY RESULTS:** one JSON with every result, a summary per group (basic / movable / control / integration) and the matched pairs side by side.

## 6. Verification

- **No-change proof:** byte-identical before / after dumps of:
  - **Levels 1–200** (`tools/classic_golden.gd`): solutions, analysis, SHOW A MOVE, every move state
  - the **PORTAL lab** and **SEQUENCE lab** boards (`tools/mechlab_golden.gd`)

  `verify_levels` output is identical.
- **`MovableCheck`:**
  - push rules, Portal / Sequence pushes and their failures, Undo / Restart, late callbacks, win with crates left
  - the solver's memo key
  - the solver vs an exact breadth-first search on random small crate boards and on mutated lab boards
  - SHOW A MOVE chains
  - the lab's board file and page flow
  - Social isolation
- **Browser:** `node tools/web_mechlab_movable_test.mjs build/web`.

## 7. Known limitations

- **Last-pusher consequence (§1):** every board relies on a turning (spinner) last pusher. Expect testers to get stuck sometimes by pushing with a plain arrow. That is data, but it may colour the clarity answers.
- **Controls are much easier on paper:** removing the crate removes the traps it creates.
- **Placeholder look and sound:** the crate art and the CLUNK (a re-pitched existing thud) are prototype quality.
- **Selection bias:** boards were picked with a solver-aided search that favours traps.
- **Lab only:** the level generator, `LevelAnalysis` and the Friend generator know nothing about crates. The Hammer has no crate rule.
