# Chain Escape — v0.2

A one-handed portrait puzzle prototype built with **Godot 4.3 (GDScript)** for iOS and Android.

> Tap a block → it escapes in its arrow direction → space opens → more blocks can leave → chain the exits. Clear the board.

The prototype answers one question: *is the core loop fun enough that people want to play another level?* Monetization, accounts, backend, stores and leaderboards are intentionally left out.

---

## What's new in v0.2 (from playtest feedback)

Players aged 12, 15 and 18, plus an adult, understood v0.1 instantly and enjoyed it. They found it too easy after the first few levels, too predictable, and visually muted. v0.2 keeps every v0.1 system (architecture, undo, layout, tests) and adds:

| Area | Change |
|---|---|
| **Ordering depth** | One new mechanic: **Spinner blocks**. A spinner turns 90° clockwise every time an orthogonally adjacent block escapes. Clearing a neighbor at the wrong moment can turn a spinner to face a block that faces it back, and then both are stuck. Move order now genuinely matters. |
| **30 curated levels** | 1–5 onboarding (unchanged) · 6–10 easy (spinners introduced at 9–10) · 11–15 medium · 16–20 medium-hard · 21–25 hard · 26–30 challenging. Difficulty comes from fewer free moves, traps, interacting lanes and direction diversity, not just block count. |
| **Hearts** | From level 6: 3 hearts per attempt. A blocked tap costs one, with a pop-and-drop animation and a soft sound. At 0, a brief friendly **"Out of hearts – try again!"** card appears and the level restarts. Undo doesn't refund hearts. |
| **Hints** | A **HINT** button highlights one recommended move with a pulsing two-tone ring. It never plays the move. It costs a hint token, which is saved. If the board is already lost, it points to Undo for free. The debug panel gives unlimited hints. |
| **Stuck detection** | If no legal move remains, the message *"No moves left – tap Undo"* appears and the Undo button pulses. It never costs a heart. |
| **Vivid palette** | Brighter, more saturated block colors on a cool light background. Yellow blocks get a dark arrow for contrast. |
| **Music and audio** | A generated, seamless 20-second lo-fi loop at low volume. It ducks under the level-complete jingle. New sounds for spinner turns, heart loss, hints and Try Again. |
| **Settings** | A gear icon (top right) opens toggles for Music, Sound Effects and Vibration. All three are saved. |
| **Solver** | A real search solver powers hints, level verification, stuck handling and the generator. |
| **LevelGenerator** | A prototype procedural generator. It generates candidates, validates them with the solver, computes difficulty metrics, and rejects trivial or repetitive boards. Levels 7 and 11–30 were generated this way, then curated by hand. |

---

## Run it locally

1. Install **Godot 4.3** or newer (standard build, not .NET): https://godotengine.org/download
2. Open Godot, click **Import**, select this folder's `project.godot`.
3. Press **F5** (Run Project).

The desktop window opens at phone proportions (405×720). Mouse clicks are treated as touches.

```bash
godot --path .                                  # play
godot --path . -- --level=17                    # start directly on level 17
godot --path . -- --debug                       # start with the debug panel open (unlimited hints)
```

### Controls

| Action | How |
|---|---|
| Escape a block | Tap it |
| Undo (unlimited) | **UNDO** |
| Hint (uses a token) | **HINT**. The badge shows tokens left (∞ in debug). |
| Restart level | **RESTART** |
| Settings | Gear icon, top right |
| Debug panel | **F1**, or tap the "LEVEL X" title 5× quickly on a device |
| Debug shortcuts (panel open) | `R` restart · `H` play one correct move · `S` auto-solve · `[` / `]` previous/next level |

### Saved progress

Saved in `user://progress.cfg`:

- current level
- highest completed level
- hint tokens
- Music / Sound Effects / Vibration settings

### Export to mobile

The project uses the **Compatibility** renderer, a portrait orientation and `canvas_items` stretch with `expand` aspect, so it scales across phone sizes and respects notches and safe areas.

1. *Editor → Manage Export Templates* → download the templates for your version.
2. *Project → Export → Add…* → **Android** (needs the Android SDK and a debug keystore) or **iOS** (needs macOS + Xcode).
3. Levels are plain JSON. Godot 4 exports `.json` automatically, but if levels are missing in a build, add `levels/*.json` under *Export → Resources → Filters to export non-resource files*.

---

## Automated checks

Run `godot --headless --path . --import` once on a fresh checkout so Godot registers the script classes.

```bash
# 1) Unit tests. Covers:
#      - rules, spinner turning, and undo snapshots of spinners
#      - the solver and trap detection
#      - hint safety: 3 random (often bad) play-throughs of every level; on each
#        state, the hint must be a legal move that keeps the board solvable,
#        and no hint may be offered on a lost board
#      - progress and settings persistence, the hint economy, and the generator
godot --headless --path . --script res://tools/run_tests.gd

# 2) Level report. Every level must be solvable; prints difficulty metrics.
godot --headless --path . --script res://tools/verify_levels.gd

# 3) Full play-through of all 30 levels through the real game scene with
#    injected touch events. Per level, it checks:
#      - a blocked tap (chain reset; heart lost from level 6)
#      - a hint (legal, highlighted, not auto-played, costs exactly one token,
#        a second press is free)
#      - an undo (block, chain and spinner directions restored)
#      - clearing the level, and the LEVEL COMPLETE card
#    Plus extra scenarios: out of hearts → Try Again → fresh attempt;
#    Restart; a spinner trap → "no moves" → free hint refusal → Undo recovery;
#    progress and tokens persisted to disk.
godot --headless --path . res://tools/Playtest.tscn
```

Current results:

- `UNIT TESTS PASSED` (2,105 checks)
- `ALL LEVELS SOLVABLE`
- `PLAYTEST PASSED: all 30 levels cleared, hearts/hints/undo/restart/persistence OK`

The tests write progress to separate files (`user://test_progress.cfg`, `user://playtest_progress.cfg`), never to the player's.

With a display you can also save screenshots or animation frames:

```bash
godot --path . res://tools/Playtest.tscn -- --shots=/tmp/shots
godot --path . res://tools/Capture.tscn -- --level=12 --taps=2,1 --out=/tmp/cap [--hint] [--settings] [--coords] [--debug]
```

---

## The spinner mechanic

```
 . B↻ G←        B is a spinner pointing up (free). G points into B. Y is free below B.
 . Y↓  .        Right: tap B first; then G and Y are free.
                Trap:  tap Y first → B turns to face G, and G faces B → stuck.
```

- A spinner is marked by a **ring of two clockwise arrows** around its arrow. It's identified by shape, not color.
- When a neighbor escapes, its arrow turns a quarter clockwise with a small tick sound.
- Only orthogonal neighbors count. A spinner leaving also turns spinners next to it.
- Undo turns spinners back, because block directions are part of the undo snapshot.
- **Teaching.** Level 9 shows a spinner turning into an open lane, with no possible mistake. Level 10 is the first 50/50 choice where one start is a trap. From level 11 on, spinners and traps grow gradually.

## The 30 levels

These metrics come from `tools/verify_levels.gd`:

- **Start:** legal moves at the beginning.
- **Traps:** how many of those starting moves make the level unsolvable.
- **Decisions:** states along the solution where a trap move exists.
- **Depth:** number of dependency rounds.
- **Diff:** the generator's difficulty score, weighted toward decisions and traps rather than raw block count.

| # | Name | Size | Blocks | Spinners | Start | Traps | Decisions | Depth | Diff | Band |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | First Steps | 3×3 | 3 | 0 | 3 | 0 | 0 | 1 | 1.5 | Onboarding: tap |
| 2 | In The Way | 3×3 | 3 | 0 | 1 | 0 | 0 | 2 | 3.1 | Onboarding: blocking |
| 3 | One After Another | 3×3 | 3 | 0 | 1 | 0 | 0 | 3 | 3.8 | Onboarding: chain |
| 4 | Around The Corner | 4×4 | 4 | 0 | 1 | 0 | 0 | 4 | 4.5 | Onboarding |
| 5 | Two Ways In | 4×4 | 6 | 0 | 2 | 0 | 0 | 3 | 3.7 | Onboarding: two starts |
| 6 | Rush Hour | 5×5 | 15 | 0 | 6 | 0 | 0 | 5 | 5.2 | Easy: hearts begin |
| 7 | Crossroads | 5×5 | 9 | 0 | 2 | 0 | 0 | 7 | 6.5 | Easy (generated) |
| 8 | Look Closer | 5×5 | 13 | 0 | 1 | 0 | 0 | 9 | 8.8 | Easy: decoy lanes |
| 9 | Spinner | 4×4 | 4 | 1 | 1 | 0 | 0 | 3 | 4.4 | Easy: spinner intro |
| 10 | Order Matters | 4×4 | 5 | 1 | 2 | 1 | 1 | 4 | 7.6 | Easy: first trap |
| 11 | Quarter Turn | 4×4 | 9 | 1 | 2 | 0 | 2 | 5 | 9.7 | Medium |
| 12 | Wrong Way | 4×4 | 11 | 1 | 3 | 1 | 2 | 8 | 12.2 | Medium |
| 13 | Pinwheel | 5×5 | 13 | 2 | 1 | 0 | 1 | 10 | 12.3 | Medium |
| 14 | Tight Squeeze | 4×4 | 10 | 1 | 3 | 1 | 3 | 7 | 13.4 | Medium |
| 15 | Second Thoughts | 5×5 | 14 | 2 | 2 | 0 | 2 | 11 | 14.5 | Medium |
| 16 | Crosswind | 5×5 | 15 | 2 | 3 | 0 | 4 | 11 | 17.9 | Medium-hard |
| 17 | Knots | 5×5 | 13 | 2 | 3 | 0 | 6 | 9 | 20.2 | Medium-hard |
| 18 | Clockwork | 5×5 | 16 | 3 | 3 | 1 | 4 | 13 | 20.8 | Medium-hard |
| 19 | Gridlock | 6×6 | 20 | 3 | 3 | 0 | 4 | 14 | 21.0 | Medium-hard |
| 20 | Domino Line | 5×5 | 13 | 2 | 3 | 2 | 7 | 10 | 25.9 | Medium-hard |
| 21 | Traffic Jam | 6×6 | 19 | 4 | 2 | 1 | 6 | 14 | 26.6 | Hard |
| 22 | Twisted Lanes | 6×6 | 15 | 3 | 3 | 1 | 8 | 12 | 27.6 | Hard |
| 23 | Hairpin | 5×5 | 19 | 3 | 2 | 0 | 7 | 17 | 28.8 | Hard |
| 24 | Gearbox | 6×6 | 21 | 4 | 2 | 1 | 9 | 13 | 32.0 | Hard |
| 25 | Rush Order | 6×6 | 19 | 4 | 2 | 1 | 11 | 13 | 35.5 | Hard |
| 26 | Labyrinth | 6×6 | 19 | 3 | 2 | 1 | 11 | 16 | 36.9 | Challenging |
| 27 | Whirlpool | 6×6 | 20 | 4 | 2 | 1 | 11 | 17 | 38.1 | Challenging |
| 28 | Chain Reaction | 6×6 | 23 | 5 | 2 | 1 | 11 | 17 | 39.5 | Challenging |
| 29 | Grand Tangle | 6×6 | 21 | 3 | 2 | 1 | 15 | 14 | 43.5 | Challenging |
| 30 | Great Escape | 6×7 | 25 | 6 | 2 | 1 | 14 | 22 | 48.6 | Challenging |

v0.1's levels 8–10 (Two Streams, The Wave, Unwind) were removed. They were exactly the "many blocks pointing the same way, solution obvious" boards the playtest flagged.

## Hint economy

- A new player starts with **1 token**, which covers levels 1–10 (about 1 per 10 levels).
- Completing levels **15 and 20** for the first time awards +1 each (about 1 per 5 levels in 11–20).
- From level 21, every level divisible by 3 (**21, 24, 27, 30**) awards +1 (about 1 per 3 levels).
- Replaying a level never awards tokens again.
- Rewards show as **+1 HINT** on the completion card.

The formula lives in `PlayerProgress.hints_awarded_for()`, so it already covers future levels.

## Level generator (prototype)

```bash
godot --headless --path . --script res://tools/generate_levels.gd -- --profile=hard --count=3 --seed=7 [--out=user://generated]
```

`LevelGenerator` (`scripts/core/level_generator.gd`) works in five steps:

1. **Reverse construction.** It plays the game backwards: blocks slide in from the edge, one at a time, onto cells whose lane is empty, and spinner turns are undone as it goes. Played forwards, the reverse order is a solution. Placement favors cells that block currently free blocks, and outward-facing edge blocks are budgeted, because those can never be blocked.
2. **Hill-climbing refinement.** Random mutations (turn an arrow, toggle a spinner, move a block, or create a "trap motif" where a neighbor points into a spinner) are kept only if the board is still solvable and scores better on the profile.
3. **Validation.** The `Solver` checks every candidate. Nothing is accepted on construction alone.
4. **Metrics and rejection.** It checks board size, block and spinner counts, legal starting moves, start traps, decision points, dependency depth and direction diversity (largest direction share, and whether all 4 directions are used). Too many free moves, low direction diversity, a shallow structure or no real decisions each reject a board.
5. **Repetition filter.** A board is rejected if its cell/arrow similarity to any known level of the same size exceeds the profile limit.

Profiles: `easy`, `medium`, `medium_hard`, `hard`, `expert`. Output is written to a separate folder for a human to curate, never straight into `levels/`.

---

## Project structure

```
project.godot                 Portrait 720x1280 base, Compatibility renderer, AudioManager autoload
scenes/Main.tscn              GameManager + LevelManager, Board, TutorialHint, UI, DebugPanel
levels/level_01..30.json      Level data (one file per level)
scripts/
  game_manager.gd             Orchestrates everything: rules, history, hearts, hints, board/ui/audio
  core/
    direction.gd              UP/DOWN/LEFT/RIGHT helpers, clockwise rotation
    block_data.gd             Plain block data (id, cell, color, direction, kind: normal/spinner)
    board_model.gd            Pure rules: occupancy, path checks, remove (+ spinner turns), snapshots
    solver.gd                 Search solver: solve, recommend_move (hints), analyze (metrics)
    level_generator.gd        Prototype generator: construct, refine, validate, score, reject
    player_progress.gd        Saved progress, hint tokens, settings, hint economy
    history.gd                Generic snapshot undo stack
    level_data.gd             Parsed level
    level_manager.gd          Loads/parses/serializes JSON levels
    board.gd                  Grid→screen mapping, block views, input, feedback FX, hint highlight
    block_view.gd             Draws one block (spinner badge, hint ring), plays its animations
    escape_ghost.gd           Expanding outline effect where a block left
  ui/
    ui_manager.gd             HUD: title, progress, hearts, chain, Undo/Hint/Restart, settings, cards
    hearts_bar.gd             Hearts row + heart-loss animation
    pill_button.gd            Rounded button with drawn icons and a count badge
    progress_bar.gd           Board-cleared progress bar
    tutorial_hint.gd          Animated tap indicator + one-line messages
    palette.gd                All colors and fonts in one place
  audio/
    audio_manager.gd          Music/SFX buses, sound hooks, pitch scaling, ducking, placeholders
    haptics.gd                Vibration wrapper (mobile only, can be switched off)
  debug/
    debug_panel.gd            Developer overlay (hidden by default; unlimited hints)
tools/
  run_tests.gd                Unit tests
  verify_levels.gd            Level solvability and difficulty report
  Playtest.tscn               End-to-end play-through of all levels
  generate_levels.gd          LevelGenerator CLI
  Capture.tscn                Screenshot/frame capture for design review
  generate_music.py           Renders assets/audio/music.wav (numpy)
assets/audio/                 music.wav + drop-in replacements for any sound (see Audio)
```

## Architecture

```
            taps                      rules/solver           snapshots
  Board ───────────────► GameManager ───────► BoardModel     History
    ▲  escape/bump/turn/     │   │            Solver ▲          ▲
    │  hint highlight        │   └───────────────────┴──────────┘
    │                        ├──► UIManager   (hearts, chain, progress, cards, settings)
    └────────────────────────┤◄── UIManager signals: undo / hint / restart / next / setting
                             ├──► AudioManager (autoload: Music + SFX buses) + Haptics
                             ├──► PlayerProgress (ConfigFile)
                             └──► TutorialHint, DebugPanel
```

- **Model vs. view split.** `BoardModel` holds the grid and rules, and `BoardModel.remove()` returns the spinners it turned. `Board`/`BlockView` only draw and animate. `GameManager` asks the model what is legal, then tells the view what to play.
- **Solver.** It works on a compact in-place copy of the board, and memoizes dead states by remaining blocks plus spinner directions. Its key pruning rule is that a free block with no spinner neighbor is *always* safe to remove, because it only frees space and turns nothing. So it removes those greedily, and it branches only on moves that turn spinners. That keeps hints instant on a phone. A node limit guards against pathological boards.
- **Undo = snapshots.** It's unchanged from v0.1. Spinner directions live in the block snapshot, so Undo covers the new mechanic with no extra code. Hearts are deliberately *not* in the snapshot, so undoing never refunds a mistake.
- **Grid, not pixels.** The board fits any rows × columns. 3×3 up to 6×7 are in use.
- **Logic first, animation second.** A tap updates the model immediately and the animation follows, so fast chains are never throttled.
- **Chain system.** Unchanged: consecutive escapes without a blocked tap. As the chain grows, the pitch climbs a pentatonic scale, the text grows, the particles strengthen and exits get faster. Finishing a level with no blocked taps shows **PERFECT CHAIN!**

## Level format

One JSON file per level: `levels/level_NN.json`, discovered by number.

**Map form (recommended).** Comments here are for illustration only; JSON files can't contain them.

```jsonc
{
  "name": "Order Matters",
  "hint": "Order matters now - look before you tap",  // optional start message
  "hint_finger": false,        // optional: show the animated finger with the hint (default true)
  "blocked_hint": "…",         // optional: shown once after the first blocked tap
  "hearts": 3,                 // optional: override the heart rule (0 = none)
  "map": [
    ".   .   .   .",
    ".   B^@ G<  R<",
    "P>  Yv  .   .",
    ".   .   .   ."
  ]
}
```

Each cell is `.` (empty) or a color letter + arrow, with an optional `@` for a spinner:

- Colors: `R` red, `B` blue, `G` green, `Y` yellow, `P` purple.
- Arrows: `^` up, `v` down, `<` left, `>` right.

**Explicit form:**

```json
{ "rows": 4, "columns": 4,
  "blocks": [ { "row": 1, "column": 2, "color": "red", "direction": "up", "spinner": true } ] }
```

## Audio

Sound hooks:

- `play_escape(chain)`
- `play_invalid()`
- `play_combo(chain)`
- `play_level_complete()` (also ducks the music)
- `play_turn()`
- `play_heart_lost()`
- `play_hint()`
- `play_try_again()`
- `play_ui_tap()`
- `play_undo()`

The placeholder sounds are synthesized at startup.

**Music.** `assets/audio/music.wav` is generated by `tools/generate_music.py`: 96 BPM, maj7 progression, pad + pluck arpeggio + bass + soft kick/shaker. It's rendered in a circular buffer, so the loop is sample-seamless, with WAV loop points embedded. It plays at −15 dB on its own `Music` bus and dips 8 dB during the level-complete jingle.

**Replacing audio.** Put a file named after the sound id in `assets/audio/`, and it's picked up automatically:

- `escape`, `invalid`, `combo`, `level_complete`, `turn`, `heart_lost`, `hint`, `try_again`, `ui_tap`, `undo`
- `music` for the background track

`.ogg`, `.wav` and `.mp3` all work.

---

## Known limitations

- **Trap feedback is delayed.** A trap is only obvious when the board becomes stuck, sometimes several moves later. Hint and "No moves left" guide the player back with Undo. We didn't add an explicit "this board is now lost" warning; playtest whether players want one.
- **Hint strategy.** Hint recommends the first legal move that keeps the board solvable. It prefers moves that turn spinners (the real decisions) over always-safe moves. It doesn't try to explain *why*.
- **Generated levels were curated, but only by metrics and screenshots.** Levels 7 and 11–30 have not yet been hand-played by humans for fun or fairness. Some long dependency chains (depth 17–22) may feel grindy. Re-order or replace any that playtest poorly.
- **Hearts vs. Undo.** Undo is unlimited and free, so hearts only punish blocked taps, not spinner mistakes. This is intentional: it's not harsh. A future "moves" or "star" rating could reward clean solves.
- **Solver limits.** The solver has a node limit (60k). All shipped levels solve far below it. Much larger boards (8×8+ with many spinners) may need a smarter heuristic.
- **Music is a generated placeholder**, and so are the sound effects.
- **Fonts.** The UI uses the device's system font (SF Pro / Roboto) via `SystemFont`. On desktop Linux it falls back to DejaVu Sans.
- **Haptics use `Input.vibrate_handheld`.** On iOS the duration is ignored.
- **Not yet tested on physical devices.** It was verified by automated play-throughs and rendered screenshots at 9:16, 19.5:9 and 3:4-ish ratios.
- **Headless test runs print an exit warning.** It's an `ObjectDB … leaked` / `music.wav still in use` warning: Godot's dummy audio driver never releases the looping music playback on quit. It's harmless, and it doesn't occur with a real audio device.
- **Debug side effect.** The "Show grid coords" checkbox doesn't reflect the `--coords` capture flag.

## Recommended next steps

1. **Playtest v0.2 with the same group.** Watch levels 9–12 (do people understand spinners without text?), 20 and 25–30 (is it hard-fun or hard-frustrating?), and how often Hint and Undo are used.
2. **Tune the curve with data.** Log time per level, blocked taps, undo count, hint use and quits. Swap levels using the generator and the `verify_levels.gd` metrics.
3. **Mid-game trap feedback.** Consider a subtle cue when the board becomes unsolvable, for example spinners flashing gray, and measure whether it helps or spoils the puzzle.
4. **Grow the generator into a pipeline.** Add a batch mode with more profiles, then curate with human playtest ratings. Only then consider endless generated content.
5. **Juice with real assets:** designed SFX and music, iOS haptic patterns, and a bundled brand font.
6. **Meta-lite:** a level select with PERFECT badges. The background-image reveal idea is reserved for a later version.
