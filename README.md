# Chain Escape — v0.3

A one-handed portrait puzzle prototype built with **Godot 4.3 (GDScript)** for iOS and Android.

> Tap a block → it escapes in its arrow direction → space opens → more blocks can leave → chain the exits. Clear the board.

The v0.3 goal is replayability and mastery: *"I understand the rules immediately, but I need to think carefully to solve this well."* Leaderboards, accounts, backend, timed mode, Daily Challenge, ads, monetization, multiplayer and the image-reveal collection are intentionally left out.

---

## What's new in v0.3

| Area | Change |
|---|---|
| **Score** | Every level is scored. Escapes and chains earn points, and bonuses are settled at the end. Mistakes, Undo and Hints cost points. There's no timer. Your personal best is saved per level, with **NEW BEST!** when you beat it. |
| **3 stars** | ★ complete · ★★ no Hint · ★★★ PERFECT or a strong score. The rules are data-driven per level, and your best stars are saved. |
| **PERFECT** | No heart lost, no Undo and no Hint. It shows a golden stamp animation, a special sound, a +1000 bonus and a gold-framed card. |
| **Undo** | Limited to **3 per level**. The count is shown on the button. It prevents PERFECT and costs points. It uses the same snapshot history as before. |
| **Hints** | They're per level now, not tokens. Levels 1–19 have 0, 20–29 have 1, and 30+ have 2. A hint highlights one move and never plays it. It prevents PERFECT and costs points. Debug mode has unlimited hints. |
| **Locked blocks** | A new core mechanic. A locked block can't leave until every block of its key color has escaped. It has a padlock in its key color, and the padlock pops open when it unlocks. |
| **Mystery levels** | Levels 10, 20, 30, 40, 50 and 60. Some arrows start hidden and are revealed when a neighbor escapes. They're provably fair: no guessing. |
| **60 levels** | 1–5 onboarding · 6–10 easy · 11–20 medium · 21–30 medium-hard · 31–40 hard · 41–50 very hard · 51–60 expert. |
| **Level complete screen** | Shows score (counting up), personal best / NEW BEST, stars, PERFECT, hearts left, Undo used and Hints used. Buttons: **NEXT LEVEL** and **REPLAY**. |
| **Level Select** | A grid with level number, best stars, completed/locked state and a "?" marker on Mystery levels. |
| **Analysis** | The verifier reports per-mechanic impact and mystery fairness, and enforces campaign quality rules. |

---

## Score rules (`scripts/core/score_rules.gd`)

| | Points |
|---|---|
| Each escape | **100 + 20 × (chain − 1)**, with the chain bonus capped at +200 (chain ×11) |
| Board cleared | +500 |
| Hearts remaining | +200 each. Levels without hearts count 3 minus mistakes. |
| No blocked/locked tap | +300 |
| No Hint used | +300 |
| No Undo used | +300 |
| **PERFECT** | **+1000** |
| Blocked or locked tap | −100 each |
| Undo | −150 each |
| Hint | −250 each |

- There's no time component in Classic mode.
- Escape points are stored in the Undo snapshot, so an undone move also takes back its points. You can't farm points with Undo.
- The score never goes below 0.
- The best possible score is `ScoreRules.max_score(blocks)`: one unbroken chain and PERFECT.

## Star rules

The defaults, overridable per level:

| Star | Default rule |
|---|---|
| ★ | Complete the level |
| ★★ | `no_hints`: complete without a Hint |
| ★★★ | `perfect_or_score`: PERFECT, or a score ≥ the level's target |

- Stars are cumulative: star 3 also needs star 2.
- The automatic 3-star target is `max_score − 1500`. A clean run that used Undo once still reaches it, but a run with a blocked tap does not.
- A level can override any rule in its JSON: `"stars": {"two": "no_mistakes", "three": "no_undo", "score": 9000}`.
- Available rule names: `complete`, `no_hints`, `no_undo`, `no_mistakes`, `perfect`, `score`, `perfect_or_score`.
- The best stars and best score per level are saved, and they never go down.

## PERFECT rules

A PERFECT clear needs **no heart lost** (no blocked or locked tap), **no Undo** and **no Hint**. In onboarding levels without hearts, "no heart lost" means no blocked tap. It gives:

- +1000 points
- a golden "PERFECT!" stamp over the board, a double celebration burst and a special jingle (the music ducks)
- a gold-framed card titled **PERFECT!**
- a guaranteed ★★★

## Undo rules

- **3 Undos per level attempt.** The count left is shown as a badge on the button, and the button is disabled at 0 or when there's nothing to undo.
- Each Undo costs 150 points, removes the No-Undo bonus and prevents PERFECT.
- Undo restores the board, spinner directions, hidden arrows, locks, the chain and the escape points. It does not refund hearts or penalties.
- If you're stuck with no Undos left, the game says *"No moves left – tap Restart"*.
- Restart and Replay start a fresh attempt with 3 Undos.

## Hint rules

- Allowance per level: **levels 1–19: 0** · **20–29: 1** · **30+: 2**. A level can override this with `"hints": n`.
- A hint highlights one recommended **legal** move that keeps the level solvable, with a pulsing two-tone ring. It never plays the move and never shows more than one move.
- Each hint costs 250 points, removes the No-Hint bonus (and therefore star 2) and prevents PERFECT.
- If the board is already lost, Hint points to Undo instead, and nothing is spent.
- **Debug mode** (F1, or `--debug`) has unlimited, free hints.

## Locked blocks

- A locked block shows a **padlock in its key color** and a soft veil. It can't escape while **any block of the key color** is still on the board.
- It still blocks other blocks' lanes while it waits.
- Tapping a locked block counts as a blocked tap: it costs a heart and −100 points. The block rattles and all its key blocks hop, so the rule explains itself.
- When the last key-color block escapes, the padlock **pops open**, with a burst in the key color, a flash, an unlock chime and a haptic tick.
- In level data it's written `B>#G` (a blue right-arrow block locked by green), or `"lock": "green"` in the explicit form.
- The lock state is derived from the board, so Undo re-locks correctly, and the solver needs no extra state.
- **Future lock types.** `BlockData.lock_color` and `BoardModel.is_locked()` / `key_blocks()` are the single extension point. A new condition would add a field and one branch there. None are implemented yet.
- **Teaching.** Level 16 has one lock and two green keys, with a short hint and a finger. Levels 18–34 are lock-only boards with growing depth. From 36, locks combine with spinners.

## Mystery levels

- Levels **10, 20, 30, 40, 50 and 60**. They have a slightly deeper board tint, a purple **"? MYSTERY"** label, and a "?" marker in Level Select.
- A hidden block shows its **color** but a **"?"** in place of its arrow, with a dashed inner border.
- **Reveal rule:** the arrow is revealed as soon as **an orthogonally adjacent block escapes**, with a card-flip animation and a sparkle sound.
- **A hidden block can't escape until it's revealed**, and tapping it is free: it wobbles and explains, with no heart lost and no penalty. So you never have to *guess* an arrow.
- **Fairness is proven by the verifier.** At every state along the solution, for each still-hidden arrow and each of its three other possible directions, the trap status of every risky visible move must stay the same (`Solver.mystery_fairness()`). So a player can always choose a good move from visible information only; hidden arrows are uncovered, not guessed. Alternatives that would make the level unsolvable are ignored.
- Mystery combines with other mechanics gradually:
  - 10 and 20: mystery only
  - 30 and 40: mystery + spinners
  - 50 and 60: mystery + spinners + locks
- In level data it's written `Y>?`. Spinners and locked blocks can't be hidden.

## Difficulty progression and verification

The mechanics arrive gradually:

- **1–15:** the original mechanics and spinners.
- **16–35:** locked blocks are introduced (16), then used lock-only with growing depth up to 34.
- **36–60:** spinner + lock combinations.
- **46–60:** a few boards combine all three (50 and 60).
- **Variety breathers:** lock-only 49 and spinner-only 42, 44, 47, 51 and 55 keep the late game from becoming one-note.

`tools/verify_levels.gd` computes, for every level:

- block count and board size
- legal starting moves and starting traps
- decision points
- dependency depth
- solution length
- largest direction share
- spinner, lock and hidden counts
- the **impact** of each mechanic (difficulty with vs. without it; **ESS** = the level is unsolvable without it)
- mystery fairness
- a difficulty score

The run fails if any campaign rule is broken:

- Every level is solvable, and the solver didn't give up.
- From level 21: at most 3 starting moves, depth ≥ 5, all 4 directions used, and no direction on more than 45% of blocks.
- Every spinner, lock or mystery use must add difficulty (impact ≥ 0.5; mystery ≥ 0.3). No decoration.
- Mystery levels must be fair.
- From level 11, no two boards of the same size may be more than 60% alike.

Locks on their own can't create *traps*: removing a block only ever unlocks. So lock-only levels add dependency depth and reading, while real ordering decisions come from spinner + lock combinations. That's why late levels mostly combine the two.

Current result, all 60 levels (✦ = Mystery):

| # | Name | Size | Blocks | Spin | Lock | Hidden | Start | Traps | Decisions | Depth | Diff | Band |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | First Steps | 3×3 | 3 | 0 | 0 | 0 | 3 | 0 | 0 | 1 | 1.5 | Onboarding |
| 2 | In The Way | 3×3 | 3 | 0 | 0 | 0 | 1 | 0 | 0 | 2 | 3.1 | Onboarding |
| 3 | One After Another | 3×3 | 3 | 0 | 0 | 0 | 1 | 0 | 0 | 3 | 3.8 | Onboarding |
| 4 | Around The Corner | 4×4 | 4 | 0 | 0 | 0 | 1 | 0 | 0 | 4 | 4.5 | Onboarding |
| 5 | Two Ways In | 4×4 | 6 | 0 | 0 | 0 | 2 | 0 | 0 | 3 | 3.7 | Onboarding |
| 6 | Rush Hour | 5×5 | 15 | 0 | 0 | 0 | 6 | 0 | 0 | 5 | 5.2 | Easy |
| 7 | Crossroads | 5×5 | 9 | 0 | 0 | 0 | 2 | 0 | 0 | 7 | 6.5 | Easy |
| 8 | Look Closer | 5×5 | 13 | 0 | 0 | 0 | 1 | 0 | 0 | 9 | 8.8 | Easy |
| 9 | Spinner | 4×4 | 4 | 1 | 0 | 0 | 1 | 0 | 0 | 3 | 4.4 | Easy |
| 10 ✦ | Hidden Arrow | 4×4 | 5 | 0 | 0 | 1 | 1 | 0 | 0 | 4 | 5.2 | Easy |
| 11 | Order Matters | 4×4 | 5 | 1 | 0 | 0 | 2 | 1 | 1 | 4 | 7.6 | Medium |
| 12 | Quarter Turn | 4×4 | 9 | 1 | 0 | 0 | 2 | 0 | 2 | 5 | 9.7 | Medium |
| 13 | Wrong Way | 4×4 | 11 | 1 | 0 | 0 | 3 | 1 | 2 | 8 | 12.2 | Medium |
| 14 | Pinwheel | 5×5 | 13 | 2 | 0 | 0 | 1 | 0 | 1 | 10 | 12.3 | Medium |
| 15 | Tight Squeeze | 4×4 | 10 | 1 | 0 | 0 | 3 | 1 | 3 | 7 | 13.4 | Medium |
| 16 | Locked | 4×4 | 5 | 0 | 1 | 0 | 2 | 0 | 0 | 4 | 5.0 | Medium |
| 17 | Second Thoughts | 5×5 | 14 | 2 | 0 | 0 | 2 | 0 | 2 | 11 | 14.5 | Medium |
| 18 | Key Colors | 4×4 | 9 | 0 | 2 | 0 | 1 | 0 | 0 | 7 | 8.7 | Medium |
| 19 | Crosswind | 5×5 | 15 | 2 | 0 | 0 | 3 | 0 | 4 | 11 | 17.9 | Medium |
| 20 ✦ | Fog | 5×5 | 11 | 0 | 0 | 3 | 1 | 0 | 0 | 8 | 9.8 | Medium |
| 21 | Knots | 5×5 | 13 | 2 | 0 | 0 | 3 | 0 | 6 | 9 | 20.2 | Medium-hard |
| 22 | Padlocks | 5×5 | 11 | 0 | 2 | 0 | 1 | 0 | 0 | 11 | 11.3 | Medium-hard |
| 23 | Clockwork | 5×5 | 16 | 3 | 0 | 0 | 3 | 1 | 4 | 13 | 20.8 | Medium-hard |
| 24 | Combination | 5×5 | 12 | 0 | 3 | 0 | 1 | 0 | 0 | 10 | 11.7 | Medium-hard |
| 25 | Gridlock | 6×6 | 20 | 3 | 0 | 0 | 3 | 0 | 4 | 14 | 21.0 | Medium-hard |
| 26 | Master Key | 5×5 | 12 | 0 | 3 | 0 | 1 | 0 | 0 | 11 | 12.3 | Medium-hard |
| 27 | Domino Line | 5×5 | 13 | 2 | 0 | 0 | 3 | 2 | 7 | 10 | 25.9 | Medium-hard |
| 28 | Safe House | 5×5 | 16 | 0 | 2 | 0 | 2 | 0 | 0 | 13 | 12.8 | Medium-hard |
| 29 | Traffic Jam | 6×6 | 19 | 4 | 0 | 0 | 2 | 1 | 6 | 14 | 26.6 | Medium-hard |
| 30 ✦ | Smoke and Mirrors | 6×6 | 17 | 2 | 0 | 3 | 2 | 1 | 2 | 14 | 19.6 | Medium-hard |
| 31 | Twisted Lanes | 6×6 | 15 | 3 | 0 | 0 | 3 | 1 | 8 | 12 | 27.6 | Hard |
| 32 | Vault | 5×5 | 17 | 0 | 4 | 0 | 2 | 0 | 0 | 12 | 13.9 | Hard |
| 33 | Hairpin | 5×5 | 19 | 3 | 0 | 0 | 2 | 0 | 7 | 17 | 28.8 | Hard |
| 34 | Strongroom | 6×6 | 17 | 0 | 4 | 0 | 1 | 0 | 0 | 16 | 16.8 | Hard |
| 35 | Gearbox | 6×6 | 21 | 4 | 0 | 0 | 2 | 1 | 9 | 13 | 32.0 | Hard |
| 36 | Spin the Lock | 6×6 | 15 | 3 | 2 | 0 | 2 | 1 | 6 | 12 | 26.0 | Hard |
| 37 | Rush Order | 6×6 | 19 | 4 | 0 | 0 | 2 | 1 | 11 | 13 | 35.5 | Hard |
| 38 | Tumblers | 6×6 | 17 | 2 | 2 | 0 | 2 | 0 | 7 | 12 | 26.7 | Hard |
| 39 | Labyrinth | 6×6 | 19 | 3 | 0 | 0 | 2 | 1 | 11 | 16 | 36.9 | Hard |
| 40 ✦ | Night Shift | 6×6 | 19 | 2 | 0 | 3 | 2 | 0 | 7 | 13 | 28.6 | Hard |
| 41 | Gatekeeper | 6×6 | 14 | 3 | 2 | 0 | 2 | 0 | 8 | 10 | 27.4 | Very hard |
| 42 | Whirlpool | 6×6 | 20 | 4 | 0 | 0 | 2 | 1 | 11 | 17 | 38.1 | Very hard |
| 43 | Turnstile | 6×6 | 18 | 3 | 2 | 0 | 2 | 1 | 6 | 15 | 28.2 | Very hard |
| 44 | Chain Reaction | 6×6 | 23 | 5 | 0 | 0 | 2 | 1 | 11 | 17 | 39.5 | Very hard |
| 45 | Deadbolt | 5×5 | 14 | 3 | 2 | 0 | 2 | 1 | 10 | 13 | 34.0 | Very hard |
| 46 | Key Ring | 6×6 | 20 | 4 | 3 | 0 | 2 | 1 | 8 | 16 | 34.2 | Very hard |
| 47 | Grand Tangle | 6×6 | 21 | 3 | 0 | 0 | 2 | 1 | 15 | 14 | 43.5 | Very hard |
| 48 | Lockstep | 6×6 | 20 | 4 | 2 | 0 | 2 | 1 | 9 | 15 | 34.7 | Very hard |
| 49 | Long Way Round | 6×6 | 18 | 0 | 3 | 0 | 1 | 0 | 0 | 18 | 17.4 | Very hard |
| 50 ✦ | Eclipse | 6×6 | 17 | 3 | 1 | 3 | 2 | 0 | 6 | 13 | 26.9 | Very hard |
| 51 | Great Escape | 6×7 | 25 | 6 | 0 | 0 | 2 | 1 | 14 | 22 | 48.6 | Expert |
| 52 | Clockmaker | 6×6 | 22 | 5 | 3 | 0 | 2 | 1 | 10 | 15 | 38.2 | Expert |
| 53 | Escape Room | 6×6 | 20 | 5 | 3 | 0 | 2 | 1 | 10 | 16 | 38.5 | Expert |
| 54 | Mechanism | 6×6 | 18 | 4 | 3 | 0 | 2 | 1 | 12 | 16 | 41.5 | Expert |
| 55 | Cyclone | 6×7 | 22 | 6 | 0 | 0 | 2 | 1 | 8 | 17 | 33.7 | Expert |
| 56 | Pressure | 6×7 | 22 | 5 | 3 | 0 | 2 | 1 | 11 | 17 | 41.3 | Expert |
| 57 | Grand Vault | 6×6 | 23 | 5 | 3 | 0 | 2 | 1 | 12 | 17 | 43.4 | Expert |
| 58 | Last Lock | 6×6 | 18 | 4 | 2 | 0 | 2 | 1 | 15 | 14 | 45.2 | Expert |
| 59 | Final Turn | 6×6 | 21 | 4 | 2 | 0 | 2 | 1 | 16 | 20 | 51.1 | Expert |
| 60 ✦ | The Last Secret | 6×6 | 22 | 4 | 2 | 4 | 2 | 0 | 10 | 15 | 38.3 | Expert |

## Level generator

```bash
godot --headless --path . --script res://tools/generate_levels.gd -- --profile=spin_lock_hard --count=3 --seed=7 [--out=user://generated]
```

The pipeline is the same as v0.2 (reverse construction → hill-climbing → solver validation → metric rejection → repetition filter), plus:

- **Mutations** that add, remove or re-key locks, recolor blocks (colors are keys), and hide or reveal arrows.
- **Profiles:**
  - v0.2: `easy`, `medium`, `medium_hard`, `hard`, `expert`
  - locks: `lock_easy`, `lock_medium`, `lock_hard`
  - combinations: `spin_lock`, `spin_lock_hard`, `spin_lock_expert`
  - mystery: `mystery_medium`, `mystery_hard`, `mystery_expert`
- **A final acceptance gate** (`LevelAnalysis`): a candidate is rejected if any mechanic it uses is decorative, or if a mystery isn't provably fair.

Levels 18–60 that are new in v0.3 (all except the moved v0.2 levels and the handmade 10 and 16) were generated this way and curated by difficulty.

---

## Run it locally

1. Install **Godot 4.3** or newer (standard build, not .NET): https://godotengine.org/download
2. Open Godot, click **Import**, select this folder's `project.godot`.
3. Press **F5** (Run Project).

The desktop window opens at phone proportions (405×720). Mouse clicks are treated as touches.

```bash
godot --path .                                  # play
godot --path . -- --level=40                    # start directly on level 40
godot --path . -- --debug                       # start with the debug panel open (unlimited hints)
```

### Controls

| Action | How |
|---|---|
| Escape a block | Tap it |
| Undo (3 per level) | **UNDO**. The badge shows the uses left. |
| Hint (0–2 per level) | **HINT**. The badge shows hints left for this level (∞ in debug). |
| Level Select | Grid icon, top left |
| Restart level | **RESTART** |
| Settings | Gear icon, top right |
| Debug panel | **F1**, or tap the "LEVEL X" title 5× quickly on a device |
| Debug shortcuts (panel open) | `R` restart · `H` play one correct move · `S` auto-solve · `[` / `]` previous/next level |

### Saved progress

Saved in `user://progress.cfg`:

- current level
- highest completed level
- best score and best stars for every level
- Music / Sound Effects / Vibration settings

### Export to mobile

The project uses the **Compatibility** renderer, a portrait orientation and `canvas_items` stretch with `expand` aspect, so it scales across phone sizes and respects notches and safe areas.

1. *Editor → Manage Export Templates* → download the templates for your version.
2. *Project → Export → Add…* → **Android** (needs the Android SDK and a debug keystore) or **iOS** (needs macOS + Xcode).
3. Levels are plain JSON. Godot 4 exports `.json` automatically, but if levels are missing in a build, add `levels/*.json` under *Export → Resources → Filters to export non-resource files*.

---

---

## Automated checks

Run `godot --headless --path . --import` once on a fresh checkout so Godot registers the script classes.

```bash
godot --headless --path . --script res://tools/run_tests.gd        # unit tests
godot --headless --path . --script res://tools/verify_levels.gd    # 60-level analysis + campaign rules
godot --headless --path . res://tools/Playtest.tscn                # end-to-end play-through
```

**Unit tests** (`run_tests.gd`) cover:

- directions and spinner turning
- undo snapshots (spinners, locks and hidden arrows)
- solver trap detection
- **lock / unlock** in the model and solver, and a lock facing its only key being unsolvable
- **mystery reveal**, re-hiding on Undo, and fairness: the intro level is fair, and a deliberately unfair board is rejected
- **score arithmetic**, PERFECT, and default and data-driven **stars**
- **best score / stars / progress persistence**
- all levels solvable
- **hint safety**: 3 random (often bad) play-throughs of every level. On every state, the hint must be legal and keep the board solvable, and no hint may be offered on a lost board.
- the generator

**Playtest** (`Playtest.tscn`) plays every level through the real scene with injected touches. Per level:

- a blocked tap: chain reset, and a heart lost from level 6
- a hint where allowed: legal, keeps the board solvable, highlighted, not auto-played, counted
- an Undo: block, directions, hidden arrows and locks restored; the count goes up
- clearing the board by following the solver, then the complete card with score, stars and the best saved

Plus these scenarios:

- **PERFECT** gives exactly `max_score` and ★★★. A worse replay keeps the best, and it's persisted to disk.
- **Replay** restarts the same level.
- **Level Select** opens with every level, and choosing a level starts it.
- **Undo limit:** the 4th Undo is refused and the button is disabled.
- **Hint limits:** 0 / 1 / 2 by band, and unlimited in debug.
- **Locked block:** tapping it is a mistake; the unlock animation clears the padlock.
- **Mystery:** tapping a hidden block is free, and the arrow is revealed on screen.
- the out-of-hearts flow, Restart, and a spinner trap → stuck → Undo recovery
- every level's best score persisted

**Current results (v0.3):**

| Check | Result |
|---|---|
| Unit tests | `UNIT TESTS PASSED`: 4,418 checks, 0 failures |
| Level verifier | `ALL 60 LEVELS SOLVABLE AND PASS CAMPAIGN RULES`. All 6 Mystery levels are proven fair. Every mechanic use adds difficulty. |
| Playtest | `PLAYTEST PASSED`: all 60 levels cleared through real touch input, plus the PERFECT, bests, Replay, Level Select, Undo/Hint limits, lock, mystery, hearts, Restart and trap scenarios |
| Rendering | Checked at portrait 9:16 (720×1280) with screenshots of the HUD, locks, mystery levels, the complete/PERFECT cards and Level Select |

The tests write progress to separate files (`user://test_progress.cfg`, `user://playtest_progress.cfg`), never to the player's.

---

## Project structure

```
levels/level_01..60.json      Level data (map form; modifiers @ spinner, ? hidden, #K locked by color K)
scripts/
  game_manager.gd             Orchestration: rules, history, hearts, undo/hint limits, score, stars, level select
  core/
    board_model.gd            Rules: lanes, spinners, locks (color counts), hidden arrows, snapshots
    solver.gd                 Search solver: solve, recommend_move (hints), analyze, mystery_fairness
    level_analysis.gd         Per-level report incl. mechanic impact + fairness (verifier / generator)
    score_rules.gd            Score, PERFECT and data-driven star rules
    player_progress.gd        Saved progress, best score + stars per level, settings
    level_generator.gd        Prototype generator (construct, refine, validate, score, reject)
    level_manager.gd          Loads/parses/serializes JSON levels (tokens with @ ? #K)
    block_data.gd / level_data.gd / direction.gd / history.gd
    board.gd / block_view.gd  Board and block visuals (padlock, "?" arrows, reveal/unlock animations, score pop-ups)
    escape_ghost.gd
  ui/
    ui_manager.gd             HUD, Undo/Hint badges, complete card (score, stars, best), PERFECT stamp, settings
    level_select.gd           Level grid (stars, locked/completed, Mystery marker)
    stars_row.gd / shapes.gd  Star widgets
    hearts_bar.gd / pill_button.gd / progress_bar.gd / tutorial_hint.gd / palette.gd
  audio/ audio_manager.gd, haptics.gd
  debug/ debug_panel.gd
tools/ run_tests.gd, verify_levels.gd, Playtest.tscn, generate_levels.gd, Capture.tscn, generate_music.py
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
                             ├──► PlayerProgress (ConfigFile: progress, bests, stars, settings)
                             ├──► ScoreRules (score, PERFECT, stars)
                             └──► TutorialHint, DebugPanel
```

- **Model vs. view split.** `BoardModel` holds the grid and rules, and `BoardModel.remove()` returns the spinners it turned. `Board`/`BlockView` only draw and animate. `GameManager` asks the model what is legal, then tells the view what to play.
- **Solver.** It works on a compact in-place copy of the board, and memoizes dead states by remaining blocks plus spinner directions. Locks (color counts) and reveals (whether any original neighbor has escaped) are derived from the alive set, so the memo key stays exact. Its key pruning rule is that a free block with no spinner neighbor is *always* safe to remove, because it only frees space and turns nothing. So it removes those greedily, and it branches only on moves that turn spinners. That keeps hints instant on a phone. A node limit guards against pathological boards.
- **Undo = snapshots.** Unchanged since v0.1. Spinner directions and hidden flags live in the block snapshot. Locks are derived from the board (color counts), so Undo re-locks automatically. Escape points are in the snapshot too, so an undone move also takes back its points. Hearts, mistakes and penalties are deliberately *not* in the snapshot.
- **Locks and mystery in the model.** `BoardModel.move_state(id)` returns `ok`, `blocked`, `locked` or `hidden`. `remove()` reports turned spinners, `last_revealed` and `last_unlocked`, so the Board can animate them.
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

Each cell is `.` (empty) or a color letter + arrow, then optional modifiers in this order: `@` spinner, `?` hidden arrow (mystery), `#K` locked by color K. For example: `B>`, `R^@`, `Y<?`, `G>#P`, `B>@#R`.

- Colors: `R` red, `B` blue, `G` green, `Y` yellow, `P` purple.
- Arrows: `^` up, `v` down, `<` left, `>` right.

**Explicit form:**

```json
{ "rows": 4, "columns": 4,
  "blocks": [ { "row": 1, "column": 2, "color": "red", "direction": "up", "spinner": true, "lock": "green", "hidden": false } ] }
```

Optional level keys:

- `mystery` (bool)
- `hints` (per-level hint allowance)
- `stars` (star rules)
- `hearts`, `hint`, `hint_finger`, `blocked_hint`

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
- `play_unlock()`
- `play_reveal()`
- `play_star(i)`
- `play_perfect()` (also ducks the music)
- `play_new_best()`

The placeholder sounds are synthesized at startup.

**Music.** `assets/audio/music.wav` is generated by `tools/generate_music.py`: 96 BPM, maj7 progression, pad + pluck arpeggio + bass + soft kick/shaker. It's rendered in a circular buffer, so the loop is sample-seamless, with WAV loop points embedded. It plays at −15 dB on its own `Music` bus and dips 8 dB during the level-complete jingle.

**Replacing audio.** Put a file named after the sound id in `assets/audio/`, and it's picked up automatically:

- `escape`, `invalid`, `combo`, `level_complete`, `turn`, `heart_lost`, `hint`, `try_again`, `ui_tap`, `undo`
- `unlock`, `reveal`, `star`, `perfect`, `new_best`
- `music` for the background track

`.ogg`, `.wav` and `.mp3` all work.

---

---

## Known limitations

- **Lock-only levels can't create traps.** Removing a block only ever unlocks, so lock-only boards add depth and reading but not ordering *consequences*. Real ordering decisions come from spinner + lock combinations. That's why lock-only levels have lower difficulty scores than their neighbors (for example 32, 34 and 49).
- **Locks depend on color.** Arrows and spinners are identified by shape, but a lock's key is a color. The padlock is drawn in the key color, and tapping a lock makes every key block hop, but color-blind players may still find some boards harder. A future "symbol per color" option would fix this.
- **Mystery fairness is checked along the solver's solution path**, not every reachable state. It guarantees a fair line of play exists, not that every detour is equally informative.
- **Generated levels were curated by metrics and screenshots**, not by human playtests. Some expert boards have 20+ moves with long dependency chains.
- **Progress from v0.2 carries over by level number,** but levels were renumbered (v0.2 levels moved to new slots), so old saves may unlock a slightly different set. v0.2 hint tokens are no longer used.
- **The 3-star target is automatic** (`max_score − 1500`) unless a level sets one. It hasn't been tuned per level.
- **Solver node limit (60k).** All 60 levels solve far below it.
- **Placeholder audio.** Music and sound effects are generated placeholders. The UI uses the device's system font (DejaVu Sans on desktop Linux).
- **Headless runs print an exit warning** (`music.wav still in use` / `ObjectDB leaked`). It comes from the dummy audio driver and is harmless.
- **Not yet tested on physical devices.** It was verified by automated play-throughs and rendered screenshots at 9:16, 19.5:9 and a wider ratio.

## Recommended next steps

1. **Playtest v0.3 with the same group.** Do players chase stars and replay? Is the lock rule obvious from level 16 alone? Do the Mystery levels feel like "uncovering"?
2. **Tune 3-star targets per level** from real score distributions.
3. **Color-independent lock keys** (symbols per color) for accessibility.
4. **Stronger lock-only puzzles:** a second lock condition (a future version) could create lock traps.
5. **Only then** consider Daily Challenge, leaderboards and the image-reveal collection.
