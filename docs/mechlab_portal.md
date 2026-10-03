# Mechanic lab — PORTAL prototype (development only)

> **Decision after the human test: GO** (3 testers familiar with Chain Escape).
> - The mechanic was clear during play.
> - 24 / 24 evaluated portal boards were judged more interesting than, or no worse than, the experience without it; none less interesting.
> - Portal materially increased remote / dependency reasoning, time, restarts and / or planning on several matched boards.
> - It is **not** a VERY HARD solution by itself, and that is fine.
>
> **Recorded MODIFY for the later implementation:** the opening demo / onboarding was not clear enough for a player who does not already know the mechanic.
>
> **Not done yet, on purpose:** no production implementation, no polish, no levels 201–300. The prototype below stays dev-only and unchanged.

Nothing in production changes:
- **Untouched:** Classic levels 1–200, saves, economy, hearts and milestones; the Friend generator and its difficulty settings; Photo / Message Reveal; the backend, Supabase, API and sharing.
- **Engine portal code is inactive without portals.** No campaign or Social board has portals, so the portal code never runs there (no-change proof: §6).

Phase 3 stays unfrozen.

## 1. Rule (as implemented)

- A **portal pair** is two board cells with the same letter (map token `OA`, `OB`; groups A–D, exactly two cells each).
- A portal is **static board data, not a block**:
  - it can't be tapped or hammered
  - it doesn't count toward clearing the board
  - nothing stands on it
- **A lane that reaches a portal continues from its partner, in the same direction.** Portals have no orientation.
- A block escapes only if its **whole** path is clear: start → entry portal → partner → edge. A path can pass several portals.
- **Blocked exit:** an ordinary blocked tap (in the lab: the usual buzz). Feedback:
  - both portals flash
  - the far blocker shakes, with a red ring
  - a line reads **"Blocked after portal A"**
- **Gates and normal blocks** block the path after the exit portal as usual.
- **Armor / ram:** a ram travels through portals. If the first block after the exit is shelled, the tap is a ram that cracks it, and the rammer stays.
- **Spinners:** neighbour events stay tied to the block's **starting cell**. Passing through or out of a portal turns nothing.
- **Locks, hidden arrows, switches:** unchanged. A locked block still waits for its key. A hidden block is revealed by a neighbour of its own cell. A switch flip can turn a lane into, or out of, a portal lane.
- **Loops:**
  - **Layout check:** any layout where some lane could loop on the empty board is rejected by the parser (all portals dropped, with an error).
  - **Engine guard:** a lane that re-enters a portal or returns to its own cell, or runs past a step limit, counts as blocked, so even a forced bad layout can never hang the game or the solver.
- **Malformed pairs** (one cell, three cells, no partner) are rejected.

## 2. Architecture

| Piece | Change (inactive without portals) |
|---|---|
| `scripts/core/portals.gd` (new) | Pairing, the lane walk with its guards, the layout check |
| `LevelData` / `LevelManager` | `portals` (cell → letter); `OA` parse, validation, written back by `to_json_text` |
| `BoardModel` | `set_portals()`, `lane()`; `find_blocker` / `move_state` follow portals. `setup()` / `restore()` keep them, so Undo and Restart keep them |
| `Solver` | Optional portal map → `_first_in_portal_lane`. Static, so **not** in the memo key. `hammer_safe` copies portals to its test board |
| `Board` (view) | Greybox portal drawing; escape through portals (dive in, pop out); blocked / ram feedback with portal flashes |
| `SocialPlay` | Loads portals from the board; counters (`total_blocked`, `total_rams`, `total_portal_uses`, `total_portal_blocked`); placeholder portal sound |
| `scripts/dev/mech_lab.gd` (new) | The `?mechlab=1` page |
| `GameManager` | One branch: opens the lab only with `?mechlab=1` |

`PuzzleDefinition` and the backend contract are unchanged:
- `PuzzleDefinition.verify()` rejects a portal board.
- The backend's Friend cell rule rejects `OA`.

So a portal board can never become a Social challenge.

## 3. The boards

`data/dev/mechlab_portal.json`, built by `tools/mechlab_portal_build.gd`. Every board is hand-picked, some after a solver-aided search (`--search=…`). The builder checks every board: valid layout, solvable, and each portal board actually uses a portal.

**11 portal boards and 6 matched controls (17 boards).**

| Stage | Board | What it is about | Matched control |
|---|---|---|---|
| A — basics | A1 | One pair, every path clear: in at A, out at A | — |
| A | A2 | The exit side is blocked: clear it first | — |
| A | A3 | Both directions through one pair; each exit has a blocker | — |
| B — planning | B1 | Spinner board (6×6, 10 blocks); remote exit lanes | B1_CTRL |
| B | B2 | Spinner board (6×6, 10 blocks); three portal users blocked remotely at the start | B2_CTRL |
| C — one mechanic | C1 | **Lock:** the locked block's lane runs through the portal | — |
| C | C2 | **Switch:** the switch's flip target leaves through the portal | C2_CTRL |
| C | C3 | **Armor:** a ram through the portal cracks the shell | C3_CTRL |
| C | C4 | **Gate:** the exit lane is closed by a Chain Gate; open it first | — |
| D — depth | D1 | 6×7, 13 blocks, clockwise + counter-clockwise spinners | D1_CTRL |
| D | D2 | 6×7, 14 blocks, clockwise + counter-clockwise spinners | D2_CTRL |

The exact maps are in the builder's `BOARDS` list.

**Solver proxies (information only).** Tests 1–3 showed these don't predict human ratings. Random-tapper win rate, portal → control:

| Board | Portal | Control |
|---|---|---|
| B1 | 0.26 | 1.00 |
| B2 | 0.01 | 0.51 |
| C2 | 0.23 | 1.00 |
| C3 | 0.13 | 1.00 |
| D1 | 0.02 | 0.10 |
| D2 | 0.06 | 0.18 |

The same blocks without the portal leave far fewer dead ends, so on paper the portal is load-bearing. Whether people *plan* differently is what the test measures.

**Controls:** the same blocks with the portal cells turned into plain empty cells, rotated 180° so they don't look like a replay. The rules are unchanged: clockwise stays clockwise. The comparison then isolates the portal itself.

## 4. The lab page (`?mechlab=1`)

**Order:**
1. An automatic **demonstration** of about 11 s, which can be replayed.
2. The **basic** boards (stage A), in order.
3. Stages B + C, then stage D, each shuffled per device. A board and its control are never back to back.

Boards are only numbered: nothing says which ones are controls.

**Tools:** UNDO x3, SHOW A MOVE x1, RESTART; no HAMMER.

**Questions** (each can be skipped):
- After every board: **difficulty** (EASY / MEDIUM / HARD / VERY HARD).
- After portal boards and controls: **"What did you mainly have to think about?"**
  - WHICH BLOCK TO START WITH
  - THE ORDER OF MY MOVES
  - CLEARING A FAR-AWAY AREA FIRST
  - WHERE A BLOCK WOULD END UP
  - NOTHING MUCH
- After portal boards only:
  - **"Did the portal change how you planned this puzzle?"** NOT REALLY / A LITTLE / A LOT
  - **"Was it clear where a block would go?"** CLEAR / SOMETIMES UNCLEAR / UNCLEAR
  - **"The portal made this puzzle…"** MORE INTERESTING / NO DIFFERENCE / MORE ANNOYING
- The basic boards ask only difficulty and clarity.

**Recorded automatically, per board:**
- completion, time, first action
- escapes, rams, blocked taps
- portal uses, blocked taps through a portal
- restarts, UNDO, SHOW A MOVE
- longest pause, pauses ≥ 10 s

**COPY RESULTS** gives a JSON: every result, a summary per group (basic portal / portal / control) and each matched pair side by side.

**Storage:** its own file and localStorage key only. There is no network; the browser test checks that no request leaves the page.

## 5. Success bar (from the brief) and what would reject Portal

1. **Technical:** solver correct, no regressions, Undo / Restart, no hangs, Web and iPhone stable.
2. **Comprehension:** after the demo, "if my path enters here, it continues from there" is understood. Repeated confusion is rare by about the third portal board. Signals:
   - the clarity answers
   - blocked portal taps on stage A
3. **Gameplay value:** players reason about remote board state, in their answers and in their behaviour. Experienced players plan differently than on the matched control.

**Modify or drop if any of these happen:**
- it is mainly visual
- the destination is repeatedly misread
- remote blocking feels unfair
- it needs heavy explanation
- the solver cost or rule exceptions grow
- small-screen readability is poor
- experts ignore it
- the controls are equally interesting

## 6. Verification

- **Classic no-change:** `tools/classic_golden.gd` dumps, for all 200 levels:
  - the solver's full solution
  - the analysis
  - the first SHOW A MOVE
  - every block's move state and blocker at every solution step

  Before / after dumps are byte-identical. `verify_levels` output and board keys are also unchanged (README).
- **Portal checks:** `godot --headless --path . res://tools/PortalCheck.tscn`.
- **Browser:** `node tools/web_mechlab_page_test.mjs build/web`.

## 7. Known limitations

- **Greybox look:**
  - portal colour (A teal, B orange) + letter
  - a placeholder sound (a re-pitched existing effect)
  - no final effects
- **Not shown in advance:** there is no path preview; the lane after a portal is never drawn.
- **Small sample:** a handful of testers.
- **Controls are recognisable:** they have no portals, so a tester can tell them apart. Only *which* board they match is hidden, by rotation.
- **Portals only exist on lab boards:** the level generator, `LevelAnalysis` and the Friend generator know nothing about portals.
