# Timing + Personal Best — Phase 1

Phase 1 covers four things:

- **Active-play time** for campaign levels.
- **Two local records per level:** BEST TIME and BEST CLEAN TIME.
- **One line on the completion card.**
- **Safe storage** of both records in the existing release save.

Out of scope: servers, percentiles, leaderboards, competitive play, social-challenge timing, and any change to levels, rules, scores, stars, hearts, rewards, progression or celebrations.

## What a "time" is

The time of an attempt is the **active-play time**: from the moment the board can be played to the winning move. It measures thinking and playing, not loading or ceremony.

| Counted | Not counted |
|---|---|
| The board is on screen and takes taps, including the finger lessons on Levels 76, 201, 226 and 251, where the player makes the moves | Loading, and the title screen |
| Time spent on mistakes and lost hearts | The NEW MECHANIC card |
| | Settings, the Shop, Level Select, the recovery / backup panel, the chapter card and the debug panel |
| | The out-of-hearts "Try Again" beat |
| | Everything after the winning move: the clear animation, milestone overlays and stamps, the result card |
| | Any time the page or app is hidden: Safari in the background, the phone locked, another tab or app |

### Lifecycle (`GameManager` + `AttemptTimer`)

1. **`start_level`** (first play, NEXT, REPLAY, Restart, retry after the hearts run out, Level Select): the attempt clock is reset to 0 and the attempt is marked clean.
2. **Every frame** (`_process`): the time since the previous frame is added if the attempt is active.
   - "Active" means a level is loaded and not cleared, hearts aren't out, the board takes input, and nothing in the table above is open.
   - The time comes from the real monotonic clock (`Time.get_ticks_usec()`), not from `delta`. Godot 4.3 smooths `delta` by default (`delta_smoothing`), which measurably under-reports real time when frames are uneven (about 15 % in the headless browser test).
   - A single frame adds at most **0.25 s** (`AttemptTimer.MAX_FRAME`). A stall, or a page resumed without a visibility event, can never inflate a time.
3. **Hidden page:** nothing is added while the page is hidden. The first frame after it is visible again is dropped, because that frame spans the hidden time.
4. **Winning move** (`_on_board_cleared`, called synchronously by the move that empties the board, whether escape or Hammer): the clock is frozen, the time is recorded, and only then do the celebrations start.
5. **An attempt that is not finished records nothing.** That covers Restart, Level Select, leaving to the title, closing the page, and running out of hearts.

### Hidden page / background: how it is detected

- **Web (itch.io embed and own tab):**
  - JavaScript `visibilitychange` reads `document.hidden`. It covers tab switches, Safari sent to the background, and the phone being locked.
  - `pagehide` counts as hidden even if `document.hidden` still reads false; `pageshow` ends it. This covers the back-forward cache and Safari putting the page away.
  - These events are connected through `JavaScriptBridge.create_callback` and are the same inside the itch.io iframe and on the game's own tab.
  - **Window focus is deliberately not used on the web.** In the itch.io embed the iframe loses focus whenever the player taps the surrounding itch page, while the game stays fully visible. Godot 4.3 reports that as `NOTIFICATION_APPLICATION_FOCUS_OUT`, so pausing on it would make embed times differ from own-tab times.
- **When Safari suspends the page outright** (no events, no frames): when it resumes, the first frame is either dropped (a visibility event fired) or capped at 0.25 s.
- **Native builds** (not shipped): `FOCUS_OUT` / `PAUSED` hide, `FOCUS_IN` / `RESUMED` show.

## Assisted vs. clean

An attempt is **assisted** as soon as any of these is used, and stays assisted until the attempt ends:

- **Show a Move (Hint):** free, paid, or from the inventory. It counts when a move is actually shown; a refused request ("no hints") doesn't count.
- **Undo:** counts when a move is actually undone.
- **Hammer:** counts when a block is actually smashed.
- **Developer auto-move / auto-solve:** dev and QA builds only.

Mistakes, blocked moves and lost hearts are **not** assistance. Every finished attempt updates BEST TIME; only a clean one also updates BEST CLEAN TIME. Replays update both, exactly like first clears.

## Records and save

`PlayerProgress` keeps two maps, level number → milliseconds:

- `best_times` (BEST TIME): the fastest finished attempt, assisted or not.
- `clean_times` (BEST CLEAN TIME): the fastest unassisted attempt.

A valid time is an integer from 1 to 86 400 000 ms (24 h). The rule **BEST ≤ BEST CLEAN** always holds: a clean time is also a best-time candidate.

The records are stored in the same release save, `user://progress_r2.cfg`, mirrored to `chain_escape_save_r2`. Two new sections are added:

```
[times]
1=6647
7=41230

[clean_times]
1=6647
```

- **Save version, namespace and file names are unchanged.** Nothing is reset or migrated.
- **Old saves without these sections** load with no records and gain them on the next clear.
- **Builds released before Phase 1** (af7dc72) keep both sections when they load and save, because a ConfigFile keeps sections it does not know. This was checked headless with the released code and in the browser with the released ZIP.
- **Loading** validates every entry. Keys must be level numbers ≥ 1 and values must be valid times; anything else is ignored. The BEST ≤ CLEAN rule is then restored.
- **Merging** applies to backup-code restore and to the embed → own-tab transfer (`merge_from`):
  - For each level, the smallest valid time of the two saves is kept.
  - A missing or invalid value never replaces a valid one.
  - BEST ≤ CLEAN is restored after the merge.
- Records are written by the save that already follows every clear (`record_result`). No extra writes are made.

## Completion card

One line under LEVEL SCORE / LEVEL BEST. It uses the same 22 pt soft text as that block, and turns to the accent colour on a new best. There is no live stopwatch during play.

| Case | Line |
|---|---|
| First finished attempt on the level | `TIME 0:42` |
| Faster than the previous BEST TIME | `TIME 0:36 · NEW BEST TIME!` |
| Not faster | `TIME 0:51 · BEST 0:38` |

- **Format:** `m:ss`; from one hour, `h:mm:ss`. Seconds are rounded down, so the card never shows a time faster than the record.
- **Fit:** the card fits iPhone SE (375×667), iPhone 14 (390×844) and Pro Max (430×932), including the Level 100 milestone card.

### BEST CLEAN TIME: placement proposal (not implemented)

The value is stored only, as requested. Proposed options, for approval first:

1. **Level Select long-press / detail strip:** `BEST 0:38 · CLEAN 0:41`. This keeps the result card unchanged.
2. **Result card, only when it matters:** a short accent `NEW BEST CLEAN TIME!` instead of the normal line, when a clean attempt beats the clean record but not the overall one.

Recommendation: option 1. It is quiet, has no effect on the result card's height, and is the natural place for the later Comparison phase.

## Tests

| Suite | What it covers |
|---|---|
| `tools/TimingCheck.tscn` (headless, 70 checks) | **AttemptTimer:** accumulation, cap, hidden page, dropped frame, finish, reset.<br>**Records:** first, faster, slower, assisted, clean; invalid values; save / reload; old save without times; invalid stored values; merge both ways; backup-code round trip; unrelated fields unchanged.<br>**The real game:** title, menus, hidden page, clean clear and card text, slower and faster replays, Hint, Undo, Hammer, Restart, leaving a level, out of hearts / retry, the NEW MECHANIC card, reload. |
| `tools/web_timing_test.mjs <player build> <dev build>` (browser, 22 checks) | The production build at iPhone size, Level 1 played by touch:<br>• the time matches the wall clock;<br>• a REPLAY with a 3 s stall, a 3 s hidden page and 2 s of `pagehide` counts none of it;<br>• a faster replay gives "NEW BEST TIME!";<br>• the records are in `chain_escape_save_r2` and survive a reload and a browser restart;<br>• the card fits SE / 14 / Pro Max and the Level 100 milestone card. |
| `tools/web_timing_compat_test.mjs <released ZIP> <player build>` (browser, 12 checks) | An existing release save:<br>• the released build plays and saves;<br>• the new build keeps all progress and adds the records;<br>• **rollback** to the released build keeps the records;<br>• forward again shows them. |

**Notes on the browser tests:**

- Chromium's CDP page-freeze does not stop frames in the headless setup, so real suspension is a real-iPhone QA item.
- Under headless SwiftShader every screenshot stalls the page for 0.3–0.45 s, and the 0.25 s cap takes that off by design. The test reads the page's own frame times and allows for exactly that.

## Real-iPhone QA (mandatory before any Production release)

### Builds

- **`ChainEscape_Web_TIMING_CANDIDATE.zip`**: the production candidate (player build, release save `chain_escape_save_r2`).
- **`ChainEscape_Web_TIMING_QA.zip`**: the QA build. It has its own separate save and direct level access through `?experiencelab=N`.

Upload each to a **new, private** itch.io project (Draft or Restricted), never to the public Chain Escape page.

> **itch.io serves every HTML game from the same web origin** (`html-classic.itch.zone`). The candidate therefore reads and writes the **same release save** as the public game on that iPhone. That is exactly what checks 10 and 11 below need, and every earlier build keeps the new sections. Even so, before testing the candidate, open the public game → Settings → **BACKUP CODE** and keep a copy of the code (Settings → RESTORE brings it back).

### Checklist

Use an external stopwatch for item 2. "Card" means the result card after the clear.

| # | Check | How | Expected |
|---|---|---|---|
| 1 | Plausible time | Play any level normally | The card shows `TIME m:ss` matching roughly how long you played |
| 2 | Matches a stopwatch | Start the stopwatch on the first frame the board can be tapped, stop it on the winning tap | Within about 1 s (the card rounds seconds down) |
| 3 | App switch excluded | Mid-level, switch to another app for 30 s, come back, finish | The card time doesn't include the 30 s (compare with the stopwatch minus 30 s) |
| 4 | Lock excluded | Mid-level, lock the phone 30 s, unlock, finish | Same as 3 |
| 5 | Menus and blocking overlays pause | Mid-level, open Settings / Shop / Level Select for 20 s each. In the QA build, open `?experiencelab=76` and wait 20 s on the NEW MECHANIC card before continuing | None of that waiting appears in the time |
| 6 | Restart and retry reset | Play 20 s, Restart, then finish quickly. Lose all hearts on a heart level, then finish the retry | Only the final attempt's time is shown. Restarted or failed attempts never show up as records |
| 7 | Assisted vs clean | Clear a level once using Show a Move, Undo or Hammer; clear it again with none, more slowly | The assisted clear sets BEST. The clean clear isn't a new BEST (card shows `BEST`), but it sets the clean record |
| 8 | Replay improves BEST | REPLAY a cleared level faster | `TIME … · NEW BEST TIME!` in the accent colour |
| 9 | Replay improves BEST CLEAN | After 7, REPLAY clean and faster than the clean record. Then REPLAY with a hint, slower | The clean record improves (not shown on the card in Phase 1). Then the hinted, slower run changes neither record (card: `BEST …`) |
| 10 | Survives reload and closure | Reload the page; close Safari completely and reopen; REPLAY a cleared level slowly | The card still shows the earlier `BEST` |
| 11 | r2 progress unchanged | Open the candidate on the phone that has public-game progress | Same CONTINUE level, coins, stars, scores and boosters as in the public game, without any reset. Afterwards the public game also still shows the same progress |
| 12 | Card fits small screens | On the smallest iPhone available (SE if possible), clear Level 1. In the QA build, also open `?experiencelab=100` and clear it | The time line is fully inside the card. REPLAY / NEXT are not pushed off-screen |
| 13 | Embed vs own tab | Play the same level in the itch embed and in its own tab (open in a new tab / full screen) and time both with the stopwatch. In the embed, tap the itch page outside the game once mid-level | Both times match the stopwatch. Tapping outside the embed doesn't pause the clock |
| 14 | Stability | Play 10–15 minutes across levels with sound on | Audio, touch response, animations and performance are the same as the released build |

Report any item that fails, with the level number, what the card showed, and the stopwatch reading.
