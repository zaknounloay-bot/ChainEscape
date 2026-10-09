# Chain Escape — Levels 1–300 freeze

This document covers the consolidated main game used for friend testing. Levels 1–300 are frozen: no further layout, mechanic or balance changes are made without a new decision.

## Approved sources

| Range | Source |
|---|---|
| 1–200 | The approved Experience Lab. `levels/level_01..200.json` are byte-identical to `data/dev/experience_lab/level_01..200.json`. |
| 201–300 | The production levels, unchanged since `bf6b739`. Covers Portals, Sequence Blocks and Movable Blocks. |

The Experience Lab range 1–200 includes:
- the Opening Lab boards 1–10;
- the reordered and adapted production boards;
- the new boards 16, 20 and 104;
- the Armor interleave at 151–170;
- Twins 176–199.

**Twins decision:** 177, 179 and 184 stay as they are, and every approved Twins level is kept.

The production files from before the freeze are archived in `data/dev/pre_freeze_production/` (1–200). `tools/experience_lab_build.py` now reads them from there, and a rebuild reproduces `data/dev/experience_lab` exactly.

**Chain Gate:** it stays at Level 121. The 121 vs 126 question is still open and did not block the freeze.

## What was consolidated into the main game

**Lessons and chapter news**
- Lessons: Lock 13, Switch 101, Gate 121, Armor 151, Twins 176. These match the Lab.
- Chapter news cards:
  - Armor on the Chapter 16 card;
  - Twins on the Chapter 18 card.
- Silver Blocks first appear at Level 27, so `economy.json` silver `from_level` changed from 31 to 27. Coin values are unchanged.

**Milestone celebrations**
- 25, 50, 75 and 100 use the approved Lab tiers. These are presentation only, with no coins.
- 125, 150 and 175 keep their own milestone behaviour and their one-time bonus.
- Level 200 keeps the Grand Master behaviour and its one-time reward, unchanged.
- 225–300 are unchanged.

**Rule visuals:** the approved spinner symbols (ALT and PATTERN) are always shown. This also applies to the spinner rules on 201–300.

**Twins in campaign files**
- The Twins token is accepted in campaign level files.
- Friend Challenge and Social parsing still reject it. As a result, the Friend generator uses the 190 classic-board keys, which excludes the Twins boards (`data/classic_board_keys.json`).

**Solver and tools:** a Twins pair now counts as one legal move in the decision metrics, as it does in play.

## Rule exceptions in `tools/verify_levels.gd`

These are approved boards whose elements the static rules rate as decorative. They are named explicitly so that nothing else can slip through:

| Exception | Levels |
|---|---|
| Gates that never close the solver line | 187, 192, 197 |
| Locks that never matter on the solver line | 190, 197 |
| Single decision point on the solver line | 190 |
| Direction share above the limit (47%) | 187 |

Twins appear only in 176–199. The Armor lesson moved from 161 to 151.

## Friend-testing build

**Export:** the "Web Friend Test" export preset (`export_presets.cfg`, `preset.1`):
- custom feature `player_build`;
- excludes `tools/*` and `data/dev/*`;
- no share-test script in the page head.

**Player-build restrictions:** when `BuildFlags.player_build()` is true:
- the debug panel never opens: no F1, no title taps, no shortcuts;
- every developer URL page is off: Experience Lab, Opening Lab, Twins Prototype, Mech Lab, Friend Bench, VH test and share test.

The normal "Web" preset is unchanged and keeps every developer tool.

**Test:** `tools/web_friend_build_test.mjs` checks the restrictions above at three iPhone sizes.

## Known issues

- **Saves from older builds:** a player who already has a save on the same itch.io page keeps their level number. Because 1–200 content changed, per-level stars and collected block rewards may refer to the old boards.
- **Save diagnostics:** the friend build has no debug panel, so the save-diagnostics view on device is not available there.
- **Real devices:** all browser checks are automated in desktop Chromium with iPhone viewports. Nothing here is validated on a real iPhone or by human testers.
- **Chain Gate placement:** 121 vs 126 is still open.
