# Gameplay Feedback Polish: Phase 2A

**Status:** real-iPhone QA passed; this is the **Production release candidate.**

- QA commits `c442dad` and `09cae1f` were pushed. The release candidate commit then turns the flag on for the player build.
- Every change sits behind `BuildFlags.feedback_polish()` (`scripts/core/build_flags.gd`), which now returns `true` in every build, the player ("Web Friend Test") build included.
- **Rollback (code):** make it return `not player_build()`. Production then has the released feedback again and nothing else changes.
- **Rollback (upload):** re-upload the previous Production ZIP (see `docs/timing_personal_best.md`, release candidate `4432661`).

**What did not change:** rules, hearts, scoring, stars, coins, assists, the CHAIN system, Timing / Personal Best, the 300 levels, saves and save namespaces, and the Game Over timing and auto-restart.

All of this is visual. No audio or haptics were changed, so everything below still reads on an iPhone with the sound muted.

## What the player sees

| Situation | Phase 2A (QA and the release candidate) | Before (released Production `4432661`) |
|---|---|---|
| **Heart lost** (Level 6+) | A small "−♥" rises from the tapped block and fades (0.65 s). The lost heart in the bar pops to 1.6×, shows a red halo, shakes and falls (about 0.6 s). | Pop to 1.45× for 0.08 s, a 0.35 s shake, a 40 px fall |
| **Lost-heart slot** | A faint fill with a clear outline: dark Chapters use white at 62%, light Chapters use the text colour at 42% | A flat fill only (white at 22% on dark Chapters) |
| **Blocked move** | A longer nudge (0.2 cell). The block in the way recoils and gets a red ring that holds for about 0.6 s. This is the same ring portal blockers already used. | A 0.12-cell nudge plus a recoil (portal blockers got a short ring) |
| **Blocked by a Movable block that can't move** | The nudge and recoil only, with **no ring**, because the real cause is further on. The "can't be pushed" message is unchanged. | Same |
| **Blocked twin** | Unchanged: the twins' own rings and lane flash | Same |
| **Locked block** | The padlock swells (about 1.55×) and wobbles (0.42 s). The block still rattles and its key blocks still hop. "Locked - clear every YELLOW block first" shows for 2.2 s, comes back on a later tap once 6 s have passed, and stays up while the player keeps tapping. | Rattle and key hop; the explanation shows once per level |
| **No moves left** | "No moves left - tap Undo" only when Undo can actually be used (there is a move to undo and an Undo is left). Otherwise "- tap Restart" and the **Restart** button pulses. The Hint dead end ("This board can't be cleared from here") and the lesson dead end follow the same rule. Button pulses never stack. | It could say "tap Undo" with no Undo left (after a ram, and after a Hint) |
| **Free taps** (hidden, crate, gate, armored, twin waiting) | Unchanged: no heart and no failure feedback | Same |
| **Levels 1–5** (no hearts) | The nudge and blocker ring; never a heart | Same, minus the ring |

## Restraint and performance

- **One instance at a time.** There is one blocker ring per blocker, one rising heart, one padlock animation per block, one hearts-bar animation and one pulse per button. A repeated tap restarts the effect instead of adding another, and the browser test confirms everything comes to rest within 1 s.
- **No new per-frame loops.**
  - The heart chip and ring are drawn once; a tween only moves, scales and fades them.
  - The padlock's overlay is redrawn only while its 0.42 s tween runs.
  - The hearts bar redraws only during its loss animation, as it did before.
- **No new pop-ups.** The only text is the existing hint line under the board.

## Assist buttons (Phase 2A follow-up, same flag)

A grey assist opens the Shop only when the one thing missing is inventory.

| Button | Situation | Phase 2A | Before (`4432661`) |
|---|---|---|---|
| **SHOW A MOVE** | No free hints and no boosters, and the board can still be cleared | "No SHOW A MOVE left - get more in the Shop", and the **Shop opens** | Same message; the coin pill pulses |
| **SHOW A MOVE** | No free hints and no boosters, and the board can't be cleared | The free dead-end pointer ("No moves left - tap Undo/Restart" or "This board can't be cleared from here - tap Undo/Restart"). **No Shop.** | "get more in the Shop" |
| **HAMMER** | This level's Hammer is already used, whether or not any are owned | "One Hammer per level". **No Shop.** | With none owned, the Shop opened |
| **HAMMER** | None owned, and this level's Hammer not yet used | The Shop opens, as before | Same |

Other details:

- **One Solver call.** It answers both questions: is there a move to show, and would buying a hint help? A board with no playable block skips the Solver.
- **Nothing is automatic.** Nothing is bought or used automatically. After a purchase, the next tap on the button uses the booster.
- **Unchanged:** prices (hint 30, hammer 60), the free hints per level, the one Hammer per level, and assist accounting (only *using* a hint or Hammer marks the attempt assisted).
- **Timer:** the Shop pauses the attempt's clock exactly as before, and closing it continues the same attempt. Timing fairness and pause rules are left for the later Player Identity / Competition phase.
- **Files:**
  - `scripts/game_manager.gd`: `request_hint()` and `toggle_hammer()`.
  - `scripts/ui/shop_panel.gd`: `button_centers()`, used by the tests only.
  - Tests: `tools/feedback_check.gd` (section J), `tools/web_feedback_test.mjs` (section A) and `tools/playtest.gd`.

## Files

| File | Change |
|---|---|
| `scripts/core/build_flags.gd` | `feedback_polish()` |
| `scripts/ui/hearts_bar.gd` | `strong` mode: the stronger animation (one tween at a time), `empty_outline` |
| `scripts/ui/ui_manager.gd` | Sets the hearts bar to strong mode and the lost-heart colours per Chapter; adds `pulse_restart_button()`; button pulses don't stack |
| `scripts/core/board.gd` | `play_bump` returns the ringed blocker (and never rings a stuck Movable block); `_blocker_ring`; `play_heart_loss` plus `HeartChip`; `play_locked_tap` adds the padlock animation; the `RewardRing.hold` and `delay` options |
| `scripts/core/block_view.gd` | `play_lock_pop()` (padlock swell and wobble); the key hop doesn't stack |
| `scripts/game_manager.gd` | `_mistake(id)` shows the heart chip; `_note_feedback` and `last_feedback` (published for tests only, never read by the rules); `_locked_explain` with its cooldown; `_point_at_no_moves()` and `_undo_available()`; `feedback` in the published state outside the player build |
| `tools/feedback_check.gd`, `tools/FeedbackCheck.tscn` | Headless checks (A–I) |
| `tools/web_feedback_test.mjs` | Browser checks: the QA build at iPhone sizes, storage isolation, and the production candidate (player build) by touch |

## Tests

```
godot --headless --path . res://tools/FeedbackCheck.tscn
godot --headless --path . --export-release "Web QA" build/web_qa/index.html
godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
SHOTS=<dir> node tools/web_feedback_test.mjs build/web_qa build/web_friend
```

## Real-iPhone QA checklist (Safari, ringer muted)

0. **Assists:**
   - On Level 14, use the starting SHOW A MOVE, follow it, then tap the grey SHOW A MOVE. The Shop should open with no coins spent. Buy one, close the Shop (the time continues), and tap SHOW A MOVE: the hint should appear.
   - Tap the grey HAMMER: the Shop should open.
   - After smashing one block, tap HAMMER again: "One Hammer per level", and no Shop.
   - On a dead end with no hints left, tap SHOW A MOVE: you should see the Undo/Restart pointer, not the Shop.

1. **Level 3:** tap a blocked block. The block in the way gets a red ring, and no heart appears.
2. **Level 6:** lose hearts 3 → 2 → 1 → 0.
   - Each loss shows a "−♥" rising from the tapped block and the bar's beat.
   - Lost hearts are clear outlines.
   - At 0 hearts, the usual "OUT OF HEARTS" card appears and the level restarts.
3. **Level 14 (lock):** tap the locked block.
   - The padlock jumps and the yellow blocks hop.
   - The text "Locked - clear every YELLOW block first" appears.
   - Tap again within 6 s after the text fades: there is no repeat text. Tap after 6 s: the text comes back.
4. **Level 7 dead end:** escape blocks until none can move; the tests use block ids 0, 3 and 4, in that order.
   - "No moves left - tap Undo" appears and Undo pulses.
   - Use all 3 Undos (replaying the last move each time): the text becomes "tap Restart" and Restart pulses.
5. **Rapid taps:** tap one blocked block quickly 8–10 times. Nothing piles up and every block settles.
6. **Themes:** check a dark Chapter (for example Level 41) and a light one on SE, 14 and Pro Max. Lost hearts should be readable, and nothing should cover the HUD or the TIME / MY BEST column.
