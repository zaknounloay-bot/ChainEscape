# Competition percentile on the level card: Phase 3B-C (QA build only)

**Status:** QA candidate (committed `3ec232e`, validation fixes on top). Validated under Godot 4.3. QA build only (`BuildFlags.competition()`). The player (production) build is unchanged: no Competition object, no request, no row on the card. Nothing is deployed and the backend contract is unchanged.

## What the player sees

The level card's timing panel gets one more row, under TIME | PERSONAL BEST:

| Situation | Row |
|---|---|
| This attempt is the player's best; the server has at least 5 players on the level | `TOP 40%` |
| The standing belongs to an earlier, faster result (a slower or equal replay) | `YOUR BEST  TOP 40%` |
| Fewer than 5 players on the level | `STANDING  ·  NOT ENOUGH PLAYERS YET` |
| The result is on its way, or the standing is being fetched | `STANDING  ·  CHECKING...` |
| The result is queued: offline, timeout, 5xx or busy | `STANDING  ·  SAVED, WILL SEND LATER` |
| The standing of an earlier best couldn't be fetched | `STANDING  ·  NOT AVAILABLE RIGHT NOW` |
| Locked (`wrong_secret`), a result dropped as invalid, or nothing ever sent for the level | No row |

**Not shown, ever:** a rank, a number of players, or a locally computed value.

**Hierarchy:**
- TIME is 38 px. `TOP X%` is 30 px in the purple badge colour; the quiet states are 19 px in the soft text colour.
- There is no animation and no sound.

**Fixed height:** the `TOP X%` label always stays in the row (empty in the quiet states) and is the taller of the two, so the row is one height in every state.
- The row is reserved when the card opens, so an answer arriving later changes only the text, never the card's size or position.
- **Quiet states never show "TOP %"** without a number: they read `STANDING · …`.
- A row with nothing to show at card open is left out entirely, and does not appear later.

## Visual polish (after real-iPhone QA)

The real percentile was too subtle. Changed in `scripts/ui/ui_manager.gd` only:

- **Size:** `TOP X%` grows from 30 to **36 px** (+20%). TIME stays 38 px; PERSONAL BEST is unchanged.
- **Trophy:** a small flat trophy (30×32, drawn, no asset or emoji) sits beside the value, in the same purple.
- **Pill:** a faint purple pill (10% tint, no vertical padding) sits behind trophy + value. It appears only with a real percentile.
- **`YOUR BEST`:** stays as the small soft caption in front, with `TOP X%` at full size.
- **Quiet states:** unchanged (one 19 px soft line, no trophy, no pill).
- **Fixed height:** the row height doesn't depend on the state, because the value label always stays in the row. A late answer moves nothing (browser test, SE and Pro Max).
- **No animation.**
- **Effect on card size:** on iPhone SE the milestone cards (100 / 300) now rest at 0.913 scale (before: 0.928; the floor is 0.85). Ordinary cards stay at 1.0.

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
| `tools/web_competition_card_test.mjs` | The exported QA build at iPhone sizes, with a local fake API and Supabase blocked |

## Tests (Godot 4.3.stable.official.77dcf97d8)

| Test | Result |
|---|---|
| `tools/CompetitionCheck.tscn` (A–G) | **75/75** |
| `tools/web_competition_card_test.mjs build/web_qa` (exported QA build, Chromium at SE / 14 / Pro Max; fake API, Supabase blocked) | **39/39** (after the visual polish). Regular/PERFECT and milestone 100 / 300 cards; TOP 14%, TOP 100%, not enough players, will send later; two late answers (checking first): row text, card and row inside the screen, above REPLAY / NEXT, below the HUD, no horizontal overflow, qa pool only, 0 requests to Supabase, no page errors |
| `run_tests.gd`, TimingCheck, ProfileCheck, FeedbackCheck, FriendChallengeApiTest (58), FriendFlowTest (150), SocialApiTest, SocialPlayTest | Pass |
| ExperienceLabQaCheck `--experiencelab=13 / 100 / 12 --qareset` | Pass |
| RecipientTest (3 "TOTAL SCORE left, coins right"), SocialSmoke ("message font carries the Arabic + Hebrew fallbacks") | Fail, **identically on `67519c0` (before 3B-C)**: pre-existing, not touched here |
| Backend: migration `--check`, contract mock 40/40, edge 43/43, competition contract 61/61 | Pass |

**Validation fixes:**
- The row was 44 px while waiting and 60 px with a percentile, so the card grew when an answer arrived. It is now one height.
- The waiting states read `STANDING · …` instead of `TOP % · …`.
- Test-only fixes in `competition_check.gd`.

**Layout note:** on iPhone SE the milestone cards (Levels 100 / 300) now rest at about 0.94 scale to fit (the floor is 0.85). Ordinary level cards are not scaled.

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
