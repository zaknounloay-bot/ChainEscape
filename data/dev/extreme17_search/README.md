# Phase 13 board searches: preserved state (development only)

The five P5-P9 beam screens (`tools/extreme17_screen.gd`) were stopped on 2026-10-23 when the Phase 13 target changed from 120 s (a MEDIUM-EXTREME bank) to a 90-second prototype. **No board was validated: every search was still in its soft growth rounds.** Nothing here is played by any page.

## Files

| File | What it is |
|---|---|
| `seed_pN.json` | The exact seed each search started from: the hand-drawn core plus its frozen cells. |
| `screen_pN.json` | Every candidate the search kept, round by round (`--out`). |
| `screen_pN.log` | The search's own log: round summaries and the best boards. |
| `resume_pN.json` | The best board of the last completed round, with the same frozen cells: the seed to continue from. |
| `cores_initial.json`, `core_p6_altshell.json` | The hand-drawn cores as first checked in the lab. |

## The searches when stopped

All five ran with: `--soft=8 --rounds=13 --beam=4`.

| Search | Recipe and idea (on every winning line) | Rounds done | Best board | State |
|---|---|---|---|---|
| P5 | `P5_gate`, chain gate + spinners: `gate_through` | 5 / 13 | 8 pieces, 39 positions, greedy 25%, opening 1 / 4 | growing; the most promising |
| P6 | `P6_altshell`, shell + alternating spinners: `alt_ram` | 4 / 13 | 7 pieces, 49 positions, greedy 23%, opening 1 / 3 | growing; the most promising |
| P7 | `P7_seq`, Sequence + spinners: `advance_turn` | 6 / 13 | 8 pieces, 113 positions, greedy 60% | growing |
| P8 | `P8_flipgate`, switch + gate + spinners: `flip_opens_gate` | 5 / 13 | 9 pieces, 35 positions, greedy 50% | growing |
| P9 | `P9_gatepull`, magnets + gate + spinners: `gate_pull` | 4 / 13 | 9 pieces, 126 positions, greedy 100% | growing; furthest from a board |

P6 was first a movable-crate board (`P6_crate`, `crate_through`). It was **rejected**: on crate boards the game's own Solver search (`scripts/core/solver.gd`) overflowed the GDScript stack (`_first_in_lane` / `_partner` recursion). A board like that could fail the same way in the game, so crates are not used. Its log was replaced by the `P6_altshell` run.

## Resuming one

A resumed search does not repeat finished rounds.
- Start it from `resume_pN.json`.
- Use `--soft` = (8 - rounds already done) for the remaining growth rounds.
- For a new target, adjust `BANDS` / `TARGET` in `tools/extreme17_build.gd` first.

```
godot --headless --path . --script res://tools/extreme17_screen.gd -- --recipe=P5_gate --file=data/dev/extreme17_search/resume_p5.json --soft=3 --rounds=8 --beam=4 --out=/tmp/p5.json
```

## Phase 13B: P5 and P6 for the 90-second prototype (rejected)

P5 and P6 were retargeted to the 90-second band "TA90" (expert learner 4-10) in `tools/extreme17_build.gd`. They were resumed from `resume_p5.json` / `resume_p6.json` with a 3-hour cap each, and stopped after about 40 minutes when the phase was closed. Every mandatory gate was kept unchanged.

| Search | Resumed rounds | Best board | Saved as |
|---|---|---|---|
| P5 | 2 | 10 pieces | `screen90_p5.*`, `best90_p5.json`, `resume90_p5.json` |
| P6 | 1 | 8 pieces | `screen90_p6.*`, `best90_p6.json`, `resume90_p6.json` |

**Full acceptance of the best candidates** (`tools/extreme17_build.gd --accept`). **Both are REJECTED.**

| Gate | P5 (chain gate) | P6 (shell + alternating spinners) | Required |
|---|---|---|---|
| Recipe mechanic | the gate does not matter (impact -0.6): decoration | - | matters |
| Rule of thumb, dead ends | 1.0 | 0.0 | >= 3 |
| Greedy player wins | 14% | 10% | <= 5% |
| 6-move lookahead greedy wins | 29% | 33% | <= 5% |
| Decisions 6-move lookahead cannot settle | 1 | 1 | >= 4 |
| Expert learner, dead ends | 0 | 0 | 4-10 (the TA90 band) |

Both boards are still far too easy and too shallow. Neither is used anywhere. The 90-second prototype (`?ta90=1`) runs with TA as a labelled internal REFERENCE only.

To continue later, start from `resume90_pN.json`. With 2-3 growth rounds left, the screens need several more hours each.

## Phase 14

P5 and P6 were measured again with the Phase 14 design report (`tools/ta90_design.gd`). Both boards are technically valid, but their mechanic is decoration and they have no endgame decision. They remain rejected. The 90-second prototype now plays three Phase 14 boards (N1-N3): see `docs/ta90_design.md` and `data/dev/ta90_search/`.
