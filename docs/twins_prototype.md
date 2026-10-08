# TWINS: lab-only playable prototype (three levels)

This is a developer page for human validation of the TWINS mechanic. It does not ship in the game.

- **Design source:** `docs/twins_176_design_validation.md`.
- **Not integrated:** Twins are not in Levels 1–300 or in Experience Lab 1–200.
- **Production unchanged:** no production level, economy, achievement, save or Social / Friend data changes.

## How to open it

Each URL opens its level directly, with no title screen. The itch.io `?v=` parameter is ignored.

| URL | Opens |
|---|---|
| `index.html?twinsprototype=1` | Level 1, "Twin Lights" |
| `index.html?twinsprototype=2` | Level 2, "Hold Fire" (Level 1 marked cleared) |
| `index.html?twinsprototype=3` | Level 3, "Turnabout" (Levels 1–2 marked cleared) |

**URL parsing** is exact `key=value` (same as the Experience Lab).
- `xtwinsprototype=1`, `twinsprototype=0` and `twinsprototype=4` never switch the prototype on.
- Without the parameter, nothing of the prototype runs.

**Flow:**
- After Level 3, an "END OF TWINS PROTOTYPE" screen opens. It never goes to Level 4.
- Its button opens Level Select, which lists only the three levels.

## Isolation

| What | Prototype | Production / labs |
|---|---|---|
| Levels | `res://data/dev/twins_prototype/level_01..03.json` (level count capped at 3) | `res://levels`, `res://data/dev/experience_lab` untouched |
| Save file | `user://twins_prototype_progress.cfg`, **wiped on every launch** | `user://progress.cfg` and the lab saves never read or written |
| localStorage | `chain_escape_twinsprototype_save` / `_beacon` | `chain_escape_save`, `chain_escape_experiencelab_save` and others untouched |
| Web save transfer, shared challenge links | skipped | unchanged |
| Twins token `!T` / `!U` / `!V` / `!W` | parsed **only** while the prototype is on (`LevelManager.dev_twins`), and only in level files (`campaign = true`) | rejected as a bad map token everywhere else |

- **The temporary save starts with** 3 Hammers and 3 SHOW A MOVE, so both boosters can be tried on the twins. It lives in the prototype save only.
- **Social / Friend:**
  - Challenge parsing (`PuzzleDefinition`) uses `campaign = false`, so a board carrying the token never verifies, even while the prototype is on.
  - Generators never set `BlockData.twin`.
  - Existing links are unaffected, and no migration is needed.

## Implemented rules

**Pairs**
- A pair is exactly two orthogonally adjacent ordinary arrows with the same group letter.
- Validation drops any other bond and reports it: apart, diagonal, three blocks, a single block, or portals on the board.
- Directions may differ. Facing twins are allowed.

**Restrictions**
- Twins cannot be spinners, hidden, locked, switches, armored, rewards or Sequence blocks.
- A switch may reverse a twin (`&A`). A twin may link a Chain Gate (`+C`).
- A twin's color is a lock key like any block's.

**Tapping either twin**
- Both lanes must be clear. Each lane ignores the partner's cell, because the partner leaves too.
- If both lanes are clear, both twins leave as one move.
- Twins never ram a shell or push a crate while bonded.

**Blocked taps**
- **The tapped twin's own lane is clear but the partner's is blocked:** a FREE tap (`move_state` `"twin_wait"`).
  - No heart, no move, and the chain is kept.
  - Both twins wobble, the bond flickers red, and the partner's blocked lane flashes red to its blocker, which is ringed.
  - "Twins leave together - clear the other twin's path first" shows once per session.
- **The tapped twin's own lane is blocked:** an ordinary blocked tap, one heart. The same wobble and lane highlight play.

**Removal order** (`BoardModel.remove_pair`, fixed)
1. Both twins leave the board.
2. The neighbour event runs for both cells: every adjacent spinner turns once, and adjacent hidden arrows are revealed. No cell can touch both twins, so a spinner never turns twice.
3. Locks whose key color is now gone open.
4. A Chain Gate whose last links left opens. Each twin counts as one link.

**Counting:** a pair escape is one Undo step, one SHOW A MOVE step, one score event and **chain +1**. SHOW A MOVE on a pair highlights both twins.

**Hammer:** removes only the smashed twin.
- The bond breaks and the other twin plays on as an ordinary block. "Bond broken - the other twin is now a normal block" is shown.
- Cost and limits are unchanged.
- Hammer safety (`Solver.hammer_safe`) is computed on the board after the single removal, so it accounts for the broken bond. Tests check this exactly.

**Engines:**
- `BoardModel`: `twin_partner`, `twin_blockers`, `move_state` → `twin_wait`, `remove_pair`.
- Packed `Solver`: `_twin` partner array, `_is_legal` and `_partner`, pair `_apply` / `_undo`, no ram or push while bonded, and pair moves always branch in the DFS.
- Both implement the same rules.

## Visuals and sound

- **Bond:** a short cream bar with a gold rim and two rivets across the gap between the two faces. It is drawn above the blocks, never reaches the arrows, and follows the blocks when they wobble.
  - Its geometry scales with the cell size, so it works on 5×5, 6×6 and 7×7 boards, horizontally and vertically, on every block color.
  - It is nothing like the Chain Gate slab.
- **Pair escape** takes about 0.40–0.45 s:
  1. Both blocks squash (0.1 s).
  2. The bond glows (to 0.16 s).
  3. The bond snaps with a small gold spark burst.
  4. Both blocks fly out together, with the usual ghosts and trails.
  5. A synchronized two-note sound plays (a fifth, struck together); its pitch follows the chain.

## The three puzzles

All three are exactly the design-report boards. Full state graphs were measured with the real `BoardModel`:

| | A "Twin Lights" | B "Hold Fire" | C "Turnabout" |
|---|---|---|---|
| States / winnable | 42 / 42 | 184 / 176 | 100 / 92 |
| Winning orders | 315 | 28,710 | 6,600 |
| Fatal moves (losing first moves) | 0 (0) | 16 (0) | 8 (0) |
| Fatal pair releases | 0 | 8 | 0 |
| Fatal plain escapes | 0 | 0 | 0 |
| Max Undos to recover | – | 4 | 4 |
| Random tapper (a pair = one move) | 100% | 69.4% | 49.9% |

**Agreement with the design report:** every design-report number above matches. The report's 51% random rate for C came from a different random sample; this run measured 49.9%.

**Each level has:**
- 3 hearts and 2 SHOW A MOVE;
- a one-line hint, shortened so it fits an iPhone screen.

## Tests

| Test | Command | What it checks |
|---|---|---|
| Headless suite | `godot --headless --path . res://tools/TwinsCheck.tscn` | URL parsing, token gating, validation, rules on both engines, randomized agreement, puzzle graphs, game flow, save isolation |
| Design review frames | `xvfb-run godot --path . --resolution 390x844 res://tools/TwinsCapture.tscn -- --out=DIR` | Bonds, pair escape, blocked feedback, 5×5 / 7×7 demo boards |
| Browser test | `SHOTS=DIR node tools/web_twins_prototype_test.mjs build/web` | Real Chromium at 390×844, 375×667 and 430×932, real touch taps |
