# Chain Escape

A one-handed portrait puzzle prototype built with **Godot 4.3 (GDScript)** for iOS and Android.

> Tap a block → it escapes in its arrow direction → space opens → more blocks can leave → chain the exits. Clear the board.

The prototype answers one question: *is the core loop fun enough that people want to play another level?* Everything else (menus, monetization, accounts, backend) is intentionally left out.

---

## Run it locally

1. Install **Godot 4.3** or newer (standard build, not .NET): https://godotengine.org/download
2. Open Godot, click **Import**, select this folder's `project.godot`.
3. Press **F5** (Run Project).

The desktop window opens at phone proportions (405×720). Mouse clicks are treated as touches.

Command line alternative:

```bash
godot --path .                                  # play
godot --path . -- --level=7                     # start directly on level 7
godot --path . -- --debug                       # start with the debug panel open
```

### Controls

| Action | How |
|---|---|
| Escape a block | Tap it |
| Undo (unlimited) | **UNDO** button |
| Restart level | **RESTART** button |
| Debug panel | **F1**, or tap the "LEVEL X" title 5× quickly on a device |
| Debug shortcuts (panel open) | `R` restart · `H` play one free block · `S` auto-solve · `[` / `]` previous/next level |

Progress (current level) is saved to `user://progress.cfg`.

### Export to mobile

The project already uses the **Compatibility** renderer, a portrait orientation and `canvas_items` stretch with `expand` aspect, so it scales across phone sizes and respects notches/safe areas.

1. *Editor → Manage Export Templates* → download the templates for your version.
2. *Project → Export → Add…* → **Android** (needs the Android SDK and a debug keystore configured in *Editor Settings → Export → Android*) or **iOS** (needs macOS + Xcode).
3. Level files are plain JSON. Godot 4 exports `.json` automatically, but if levels are missing in a build, add `levels/*.json` under *Export → Resources → Filters to export non-resource files*.

---

## Automated checks

Two tools verify the game without a device:

```bash
# 1) Static level check: every level is solvable, and shows its structure.
godot --headless --path . --script res://tools/verify_levels.gd

# 2) Full play-through of all 10 levels through the real game scene.
#    Injects real touch events, tests a blocked tap (no removal and chain
#    reset) and an Undo in every level, then waits for LEVEL COMPLETE.
godot --headless --path . res://tools/Playtest.tscn
```

Run `godot --headless --path . --import` once first on a fresh checkout so Godot registers the script classes.

With a display you can also save screenshots or animation frames:

```bash
godot --path . res://tools/Playtest.tscn -- --shots=/tmp/shots
godot --path . res://tools/Capture.tscn -- --level=3 --taps=2,1 --out=/tmp/cap
```

Current results: all 10 levels are solvable and the play-through passes (`PLAYTEST PASSED: all 10 levels cleared`).

---

## Project structure

```
project.godot                 Portrait 720x1280 base, Compatibility renderer, AudioManager autoload
scenes/Main.tscn              GameManager + LevelManager, Board, TutorialHint, UI, DebugPanel
levels/level_01..10.json      Level data (one file per level)
scripts/
  game_manager.gd             Orchestrates everything (rules → history → board/ui/audio)
  core/
    direction.gd              UP/DOWN/LEFT/RIGHT helpers
    block_data.gd             Plain block data (id, cell, color, direction)
    board_model.gd            Pure rules: occupancy, path checks, remove, snapshots
    history.gd                Generic snapshot undo stack
    level_data.gd             Parsed level
    level_manager.gd          Loads/parses JSON levels, saves progress
    board.gd                  Grid→screen mapping, block views, input, feedback FX
    block_view.gd             Draws one block, plays its animations
    escape_ghost.gd           Expanding outline effect where a block left
  ui/
    ui_manager.gd             HUD: title, progress, chain text, buttons, complete card
    pill_button.gd            Rounded button with drawn icons
    progress_bar.gd           Board-cleared progress bar
    tutorial_hint.gd          Animated tap indicator + one-line hint
    palette.gd                All colors and fonts in one place
  audio/
    audio_manager.gd          Sound hooks, pitch scaling, synthesized placeholder sounds
    haptics.gd                Vibration wrapper (mobile only)
  debug/
    debug_panel.gd            Developer overlay (hidden by default)
tools/                        verify_levels.gd, Playtest.tscn, Capture.tscn
assets/audio/                 Drop real sounds here (see Audio)
```

## Architecture

```
            taps                      rules                 snapshots
  Board ───────────────► GameManager ───────► BoardModel     History
    ▲  play_escape/bump      │   │                ▲             ▲
    │                        │   └────────────────┴─────────────┘
    │                        ├──► UIManager   (chain, progress, complete card)
    └────────────────────────┤◄── UIManager signals: undo / restart / next
                             ├──► AudioManager (autoload) + Haptics
                             └──► TutorialHint, DebugPanel
```

- **Model vs. view split.** `BoardModel` is a plain `RefCounted` with no nodes. It holds the grid and answers `can_escape`, `find_blocker` and `free_block_ids`. `Board`/`BlockView` only draw and animate. `GameManager` asks the model what is legal, then tells the view what to play. This split lets `tools/verify_levels.gd` run the real rules headless.
- **Grid, not pixels.** Blocks live in grid coordinates. `Board.layout(area)` picks a cell size that fits any rows × columns into the space between the HUD bars, then maps cells to screen positions. Any board size works (3×3 to 6×6 are used; 7×7+ needs no code changes). Layout re-runs on every viewport resize.
- **Logic first, animation second.** A tap removes the block from the model immediately, and the view then animates away. Players can chain taps as fast as they like without waiting for animations, which matters for combo feel.
- **Undo = snapshots.** Before each successful move, `GameManager` pushes `{blocks, chain}` onto `History`. Undo pops and restores it. There is no per-action undo code. `Board.sync_to()` recreates returning blocks, which fly back in from the direction they left. Add anything else to the snapshot and undo covers it for free.
- **Signals between systems.** Board → `block_tapped`. UI → `undo_pressed`, `restart_pressed`, `next_pressed`. DebugPanel → `level_requested`, etc. Only `GameManager` wires them together.
- **Chain system.** Every successful escape without a blocked tap in between increments `chain`. A blocked tap resets it. As the chain grows:
  - the escape sound climbs a major pentatonic scale;
  - the "CHAIN xN" text gets larger and warmer;
  - particles get a little stronger and the exit gets a little faster (0.28s → 0.20s);
  - from x5 the board gives a subtle "thump" pulse;
  - x3, x5, x8, x12… add a combo chime.

  Finishing a level without any blocked tap shows **PERFECT CHAIN!**

## Level format

One JSON file per level: `levels/level_NN.json`. Levels are discovered by number, so creating `level_11.json` adds a level.

**Map form (recommended):** it's visual, and quick to write and edit (comments below are for illustration only; JSON files can't contain them):

```jsonc
{
  "name": "In The Way",
  "hint": "",                                   // optional: finger + text on start
  "blocked_hint": "Blocked! Clear its path first", // optional: shown after first blocked tap
  "map": [
    ".  .  .",
    "B> R^ .",
    ".  Y^ ."
  ]
}
```

Each cell is `.` (empty) or a color letter plus an arrow:

- Color letters: `R` red, `B` blue, `G` green, `Y` yellow, `P` purple.
- Arrows: `^` up, `v` down, `<` left, `>` right.

Rows and columns come from the map.

**Explicit form** (handy for generated levels or a future editor):

```json
{ "rows": 4, "columns": 4,
  "blocks": [ { "row": 1, "column": 2, "color": "red", "direction": "up" } ] }
```

## The 10 levels

`start` is how many blocks are free when the level begins. `waves` is how many blocks open up in each round if you cleared everything free at once, which describes the shape of the cascade.

| # | Name | Size | Blocks | Start | Waves | Teaches |
|---|---|---|---|---|---|---|
| 1 | First Steps | 3×3 | 3 | 3 | [3] | Tapping (finger hint) |
| 2 | In The Way | 3×3 | 3 | 1 | [1,2] | Blocking (hint after first bump) |
| 3 | One After Another | 3×3 | 3 | 1 | [1,1,1] | First chain |
| 4 | Around The Corner | 4×4 | 4 | 1 | [1,1,1,1] | Chain of 4 that turns a corner |
| 5 | Two Ways In | 4×4 | 6 | 2 | [2,3,1] | Two possible starting moves |
| 6 | Rush Hour | 5×5 | 15 | 6 | [6,3,3,3] | Crowded board |
| 7 | Look Closer | 5×5 | 13 | 1 | [1,2,3,2,2,1,1,1] | Decoys: many lanes look open but are blocked far away |
| 8 | Two Streams | 5×5 | 20 | 2 | [2,3,3,6,2,1,1,2] | Two chain paths that meet in the middle |
| 9 | The Wave | 5×5 | 25 | 1 | [1,2,3,4,5,4,3,2,1] | Large chain; the clearing front sweeps diagonally |
| 10 | Unwind | 6×6 | 36 | 1 | 36 × [1] | Showcase: one tap starts a 36-block spiral |

## Audio

`AudioManager` exposes semantic hooks: `play_escape(chain)`, `play_invalid()`, `play_combo(chain)`, `play_level_complete()`, `play_ui_tap()`, `play_undo()`. Placeholder sounds are synthesized at startup (soft plucks, a gentle low "tock" for blocked moves, a bell arpeggio for completion), so the prototype needs no audio files.

To use real sounds, put a file named after the sound id in `assets/audio/`:

- `escape.ogg`
- `invalid.ogg`
- `combo.ogg`
- `level_complete.ogg`
- `ui_tap.ogg`
- `undo.ogg`

`.wav` and `.mp3` also work. A file there is picked up automatically, and pitch scaling still applies.

---

## Known limitations

- **Order never causes a dead end.** An escape only ever frees space, so if a level is solvable, every order of free moves solves it. The skill is *reading* lanes, and the reward is an unbroken chain (PERFECT CHAIN). Level 7's "better sequence" works through decoys that look free, not through true ordering traps. If playtests show this lacks depth, see the first two improvements below.
- **The chain is player-driven.** "Cascades" come from every escape opening the next move. Blocks don't leave on their own.
- **Levels 9 and 10 are long.** They have 25 and 36 taps and are intentionally "easy but satisfying". Test whether they feel great or tedious.
- **Fonts.** The UI uses the device's system font (SF Pro on iOS, Roboto on Android) via `SystemFont`, so no font file ships. On desktop Linux it falls back to DejaVu Sans. For brand consistency, bundle a font (for example Nunito, OFL) and change `Palette.font()`.
- **Sounds are synthesized placeholders.** They are pleasant but basic.
- **Haptics use `Input.vibrate_handheld`.** On iOS, the duration is ignored by the system.
- **Not yet tested on physical devices.** It was verified with headless automated play-throughs and rendered screenshots at 9:16, 19.5:9 and 3:4 aspect ratios.
- **Development-only side effects.** The debug "Show grid coords" checkbox does not reflect the `--coords` capture flag. Playtest and capture runs overwrite the saved level progress.

## Recommended next steps

1. **Playtest the question.** Put it on 5–10 phones. Watch whether people press NEXT LEVEL without prompting, where they tap blocked blocks, and whether 9 and 10 feel great or long.
2. **Add ordering depth if needed**, one mechanic at a time, taught through levels:
   - *sliders*: blocks that slide until they hit something, so order changes the board;
   - *locks and keys*: a color leaves only after all blocks of another color are gone;
   - a *move/time target* for stars.
3. **Level tooling:** an in-game editor writing the same JSON, plus a generator. `tools/verify_levels.gd` already scores structure. Add difficulty metrics such as decoy count.
4. **Juice pass with real assets:** designed SFX, a light music loop, iOS haptic patterns (Core Haptics plugin), and a bundled brand font.
5. **Meta-lite:** a level select grid with PERFECT badges. Keep it light.
6. **Analytics hooks** (local first): time per level, blocked taps, undo count, quit points.
7. **Accessibility:** color-blind check (arrows already carry the meaning), a reduced-motion option, and larger tap targets on 7×7+.
