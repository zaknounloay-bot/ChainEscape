# Competition percentile on the level card: Phase 3B-C (QA build only)

**Status:** local changes, not committed. QA build only (`BuildFlags.competition()`). The player (production) build is unchanged: no Competition object, no request, no row on the card. Nothing is deployed and the backend contract is unchanged.

## What the player sees

The level card's timing panel gets one more row, under TIME | PERSONAL BEST:

| Situation | Row |
|---|---|
| This attempt is the player's best; the server has at least 5 players on the level | `TOP 40%` |
| The standing belongs to an earlier, faster result (a slower or equal replay) | `YOUR BEST  TOP 40%` |
| Fewer than 5 players on the level | `TOP %  ·  NOT ENOUGH PLAYERS YET` |
| The result is on its way, or the standing is being fetched | `TOP %  ·  CHECKING...` |
| The result is queued: offline, timeout, 5xx or busy | `TOP %  ·  SAVED, WILL SEND LATER` |
| The standing of an earlier best couldn't be fetched | `TOP %  ·  NOT AVAILABLE RIGHT NOW` |
| Locked (`wrong_secret`), a result dropped as invalid, or nothing ever sent for the level | No row |

**Not shown, ever:** a rank, a number of players, or a locally computed value.

**Hierarchy:**
- TIME is 38 px. `TOP X%` is 30 px in the purple badge colour; the quiet states are 19 px in the soft text colour.
- There is no animation and no sound.

**Fixed height:** the row is 44 px.
- It is reserved when the card opens, so an answer arriving later changes only the text, never the card's size or position.
- A row with nothing to show at card open is left out entirely, and does not appear later.

## Rules (unchanged backend contract)

- **Server values only.** `TOP X%` is the `percentile` field of `submit_result` or `level_standing`.
  - `null` means fewer than 5 players, shown as NOT ENOUGH PLAYERS YET.
  - Ties and rounding are the server's (`topPercent`). The slowest player is TOP 100%.
- **One comparison group per level, as agreed in 3B-B.**
  - Hint, Undo and Hammer attempts are sent like any other, with the shown time.
  - The assisted/clean split stays a local Personal Best matter (BEST TIME / BEST CLEAN TIME) and is not part of competition.
- **Replays:**
  - A faster replay is queued and submitted through the existing 3B-B queue (no second pipeline); its answer is the new standing.
  - A slower or equal replay submits nothing. The card asks the read-only `level_standing` for the stored best. That never registers a player or writes a result, and it is never sent for a level this player hasn't sent before.
- **No stale standings:**
  - Every answer and failure carries a sequence number, and a card shows only what arrived after its own clear.
  - An answer for a time that a faster queued time has already replaced is not shown; the faster time is sent right after it.
  - A lookup overtaken by a new queued result is ignored.
- **Background only:** nothing blocks the card, NEXT or REPLAY. An answer that arrives after the card has closed only updates memory.
- **No backfill and milliseconds kept:** unchanged from 3B-B.

## Files

| File | Change |
|---|---|
| `scripts/social/competition.gd` | `standing_changed` signal; `mark()`, `card_status()`, `lookup()`; per-level answers and failures with sequence numbers; a result queued during a send is sent right after it |
| `scripts/ui/ui_manager.gd` | The standing row in the timing panel; `show_comp_status()`; `time_panel_state()` reports the row |
| `scripts/game_manager.gd` | Ties the card to the clear (`_comp_card`), starts the lookup, refreshes the row on `standing_changed` |
| `tools/competition_check.gd` | Sections F (standing rules, fake server) and G (the real level card); the "off" section checks for no row |

## Tests

| Test | Result |
|---|---|
| `tools/CompetitionCheck.tscn` (A–G, with the new F and G) | **Not run.** No Godot 4.3 binary is reachable from the build environment. All four changed `.gd` files parse with `gdtoolkit` 4.x, but types and runtime are unverified. |
| `tools/competition_migration.mjs --check` | OK (300 levels) |
| `tools/backend_contract_test.mjs` (local mock) | 40/40 |
| `tools/backend_contract_test.mjs --edge=…index.ts` | 43/43 |
| `tools/competition_contract_test.mjs` | 61/61 |
| QA web export and the browser layout tests at SE / 14 / Pro Max | **Not run.** They need Godot and its export templates. |

## Real-iPhone QA (QA build, `qa` pool)

1. **Fewer than 5 players:** clear a level nobody else has played. The row shows NOT ENOUGH PLAYERS YET, with no number.
2. **5 or more players:** 5 testers clear the same level. Each card shows a `TOP X%` that matches the formula in the 3B-B doc.
3. **Faster replay:** a new `TOP X%`, plain.
4. **Slower replay:** `YOUR BEST  TOP X%`. Personal Best unchanged.
5. **Assisted:** clears with Show a Move, Undo or Hammer get a standing too.
6. **Offline:** in airplane mode, clear a level: SAVED, WILL SEND LATER. Turn the network back on with the card still up: the row turns into the standing, and the card doesn't move.
7. **Leave and come back:** NEXT before the answer, then come back and replay slower: `YOUR BEST  TOP X%`. Close Safari and reopen: same.
8. **Layout:** on the smallest iPhone (SE if possible), check the row and Level 100 / 300 milestone cards. Nothing clipped or overlapping, no horizontal scroll, REPLAY / NEXT fully on screen.
9. **Friend Challenge:** create and open one as before.
10. **Production:** the player build shows no row and sends nothing.

Note: the QA pool already holds one synthetic player on level 12 (3,600,000 ms) from the deployment check. It counts toward level 12's 5-player minimum and is not real demand.
