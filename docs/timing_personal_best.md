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
| The board is on screen and takes taps, and the player is playing independently | Loading, and the title screen |
| Time spent on mistakes and lost hearts | The NEW MECHANIC card |
| The rest of a lesson level once its finger lesson has ended | A guided finger lesson, from its first step until it ends (see below) |
| | Settings, the Shop, Level Select, the recovery / backup panel, the chapter card and the debug panel |
| | The out-of-hearts "Try Again" beat |
| | Everything after the winning move: the clear animation, milestone overlays and stamps, the result card |
| | Any time the page or app is hidden: Safari in the background, the phone locked, another tab or app |

### Guided finger lessons

The first time a mechanic is taught, a finger lesson guides the player's moves. In the 300-level campaign this happens on Levels 13 (Lock), 76 (Magnet), 101 (Switch), 121 (Gate), 151 (Armor), 176 (Twins), 201 (Portal), 226 (Sequence) and 251 (Movable).

- **No clock while the lesson runs.** The lesson is active (`GameManager._lesson`) from the moment it starts, which is right after the NEW MECHANIC card where there is one, until it ends.
- **The lesson ends** when the player makes its key move (`_finish_lesson`, saved as learned). It also ends quietly if the Hammer removes the blocks it is about, in which case it is not marked as learned.
- **The clock starts from that moment**, for the independent rest of the level.
- **Following the finger is not assistance.** Only Show a Move, Undo and Hammer are.
- **Once a lesson has been learned it never runs again,** so a replay of a lesson level is timed from the first playable frame.
- **What doesn't change:** lesson behaviour, its texts and its learned flag.

### Lifecycle (`GameManager` + `AttemptTimer`)

1. **`start_level`** (first play, NEXT, REPLAY, Restart, retry after the hearts run out, Level Select): the attempt clock is reset to 0 and the attempt is marked clean.
2. **Every frame** (`_process`): the time since the previous frame is added if the attempt is active.
   - "Active" means a level is loaded and not cleared, hearts aren't out, the board takes input, no guided lesson is running, and nothing in the table above is open.
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

Mistakes, blocked moves, lost hearts and following a guided lesson's finger are **not** assistance. Every finished attempt updates BEST TIME; only a clean one also updates BEST CLEAN TIME. Replays update both, exactly like first clears.

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

A **timing block** sits under LEVEL SCORE / LEVEL BEST: a soft rounded panel with **TIME | PERSONAL BEST** as two columns, each with its caption beside a large value. The values are 38 pt bold: larger than LEVEL SCORE (28 pt), smaller than the TOTAL SCORE number (64 pt). There is no live stopwatch during play.

| Case | Block |
|---|---|
| First finished attempt on the level | `TIME 0:42 │ PERSONAL BEST 0:42` (neutral; it is the record now) |
| Not faster | `TIME 0:51 │ PERSONAL BEST 0:38` (neutral; the stored record) |
| Faster than the previous record | Banner **NEW PERSONAL BEST!**, then `TIME 0:36 │ PREVIOUS BEST 0:42`. The panel turns accent: light tint and an accent border, with TIME in the accent colour. |

- **Record feedback:** after the score count-up, the banner and the time give one light pulse. There is no sound and no new celebration, and nothing waits for it: REPLAY / NEXT work at once. It stays smaller than the milestone and chapter celebrations.
- **Format:** `m:ss`; from one hour, `h:mm:ss`. Seconds are rounded down, so the card never shows a time faster than the record.
- **Fit:** checked on iPhone SE (375×667), iPhone 14 (390×844) and Pro Max (430×932), in both the record and non-record states, and on the milestone cards 100 / 150 / 250 / 300, the chapter-complete card on 10, and Level 1.
  - On a short screen, a long card would otherwise reach under the top HUD (the coin pill is drawn above the card). The card then rests **lower**, into the free space below (the bottom bar is hidden under the card). Its size and touch targets stay unchanged.
  - Only if there is no room left either would it be scaled down, and at most to 0.85. This has not happened on any tested screen.
- **Later comparison values** (Phase 3 and later) can be added as further rows inside the same panel. Nothing is shown for them now.

### BEST CLEAN TIME: placement proposal (not implemented)

The value is stored only, as requested. Proposed options, for approval first:

1. **Level Select long-press / detail strip:** `BEST 0:38 · CLEAN 0:41`. This keeps the result card unchanged.
2. **Result card, only when it matters:** a short accent `NEW BEST CLEAN TIME!` instead of the normal line, when a clean attempt beats the clean record but not the overall one.

Recommendation: option 1. It is quiet, has no effect on the result card's height, and is the natural place for the later Comparison phase.

## Tests

| Suite | What it covers |
|---|---|
| `tools/TimingCheck.tscn` (headless, 81 checks) | **AttemptTimer:** accumulation, cap, hidden page, dropped frame, finish, reset.<br>**Records:** first, faster, slower, assisted, clean; invalid values; save / reload; old save without times; invalid stored values; merge both ways; backup-code round trip; unrelated fields unchanged.<br>**The real game:** title, menus, hidden page, clean clear and card text, slower and faster replays, Hint, Undo, Hammer, Restart, leaving a level, out of hearts / retry, the NEW MECHANIC card, reload.<br>**Guided lessons:** no clock during the Portal lesson on 201, which ends on its key move; then the clock runs, the attempt is not assisted, and the record contains only the independent play. A replay has no lesson. All 9 campaign lesson levels stop the clock. A lesson ended by the Hammer resumes the clock, and the attempt is assisted because of the Hammer. |
| `tools/web_timing_test.mjs <player build> <dev build>` (browser, 33 checks) | The production build at iPhone size, Level 1 played by touch:<br>• the time matches the wall clock;<br>• a REPLAY with a 3 s stall, a 3 s hidden page and 2 s of `pagehide` counts none of it;<br>• a faster replay gives "NEW BEST TIME!";<br>• the records are in `chain_escape_save_r2` and survive a reload and a browser restart;<br>• the card fits SE / 14 / Pro Max and the Level 100 milestone card;<br>• dev build `?experiencelab=76`: the Magnet card and the finger lesson add 0 ms, and the recorded time is the independent play after the lesson;<br>• the timing block's three states, and on every card that the block sits inside the card, above REPLAY / NEXT, and the card below the top HUD (SE first and record cards, Pro Max, Levels 10 / 100 / 150 / 250 / 300 on SE). |
| `tools/web_timing_compat_test.mjs <released ZIP> <player build>` (browser, 12 checks) | An existing release save:<br>• the released build plays and saves;<br>• the new build keeps all progress and adds the records;<br>• **rollback** to the released build keeps the records;<br>• forward again shows them. |

**Notes on the browser tests:**

- Chromium's CDP page-freeze does not stop frames in the headless setup, so real suspension is a real-iPhone QA item.
- Under headless SwiftShader every screenshot stalls the page for 0.3–0.45 s, and the 0.25 s cap takes that off by design. The test reads the page's own frame times and allows for exactly that.

## Gameplay HUD, layout C (QA builds only)

Approved after real-iPhone feedback that TIME, MY BEST and the hearts were too small. It appears in **QA, dev and lab builds only** (`BuildFlags.live_timer_hud()`). The player (production) build keeps the released HUD until approved: coins top-right, 34-unit hearts, the CHAIN popup.

| Area | Layout C |
|---|---|
| Left | TOTAL SCORE (unchanged); the **coin pill directly under it** (150×56). It keeps the same SHOP action, and coin fly-ins follow it. |
| Centre | **Hearts 44** units, gap 15 (released: 34 / 12). Same mechanics and life-loss animation. |
| Right | **TIME** over **MY BEST**, right-aligned under the Settings button. Captions 27, values 34, tabular digits. Captions use the Chapter's text colour blended 35 % toward the soft colour, so they keep strong contrast on light and dark Chapters. MY BEST is always the player's own Personal Best. |
| CHAIN | The **CHAIN xN popup is hidden**. The chain counter, its escape bonus (`ScoreRules.escape_points`), combo sounds, rising pitch, faster escape animation and haptics are unchanged. |

- **Positions** (logical units on a 720-wide screen, plus the safe-area top):
  - the column starts at +190 and ends around +276, above the board area (+290), so even the tallest board never meets it;
  - the coins sit at TOTAL SCORE's measured bottom + 6, re-placed whenever TOTAL SCORE changes size.
- **The live timer:** `AttemptTimer` is the only source. M:SS updates once per visible second; 0:00 on every new attempt; frozen whenever the clock is paused; hidden under the result card, which shows the times. MY BEST shows the stored record, or a dash.
- **Checked** on iPhone SE, 14 and Pro Max:
  - light and dark Chapters, long headings (Levels 30, 255) and the Master Level;
  - hearts at 3, 2 and 1;
  - a TOTAL SCORE of 1,350,000;
  - a streak up to x24 (no popup).
  
  No top-HUD element overlaps another or the board. The one exception is the TOTAL SCORE box and the chapter-line box, which have always touched, with the text apart.

### Fairness note for a future competition decision (not changed here)

The clock deliberately pauses for Settings, Shop, Level Select, the recovery panel and a hidden page. That is right for relaxed Classic play, but it is an exploit for a fastest-time competition:

- **Settings dims the board only to 35 %,** so the board stays readable while the clock is stopped.
- **The board can be studied off-clock:** screenshot it, leave the app, solve it elsewhere, and come back.
- **Restart and retry discard the attempt,** so runs can be rehearsed before a fast one.

Options for that decision:
- keep counting during menus and backgrounding in competition;
- hide the board while the clock is paused;
- cap the excluded time per attempt;
- record the attempt count.

## Real-iPhone QA (mandatory before any Production release)

### Builds

- **`ChainEscape_Web_TIMING_CANDIDATE.zip`**: the production candidate (player build). It reads and writes the **release save** (`chain_escape_save_r2` in localStorage and `user://progress_r2.cfg` in IndexedDB), exactly like the public game.
- **`ChainEscape_Web_TIMING_QA.zip`**: the QA build. **Always open it with `?experiencelab=N`.** It then uses its own QA save and never touches the release save. Without the parameter it would open the pre-release save name.

Upload each to a **new, private** itch.io project (Draft or Restricted), never to the public Chain Escape page.

### Protecting your real progress (read first)

**A private itch.io page does NOT isolate saves.** itch.io runs every HTML game from the same web origin (`html-classic.itch.zone`). The game's storage, localStorage and IndexedDB alike, belongs to that origin, not to the itch page. On the same Safari profile, the candidate on any itch page therefore opens **your real release save**: same progress, coins and stars. Its writes go into that save. Restricted or Draft pages make no difference.

The safest practical setup is to keep the real save out of reach entirely:

1. **Back up first** (in your normal Safari): open the public game → Settings → **BACKUP CODE**, and save the code somewhere outside Safari, for example in Notes. Settings → RESTORE brings it back.
2. **Create a separate Safari profile for QA** (iOS 17 or later): Settings → Apps → Safari → **New Profile**, for example "CE QA". Each Safari profile has its own website data, so its `html-classic.itch.zone` storage is empty and separate from your normal profile. In Safari, switch to it from the tabs view.
3. **Prove the isolation before anything else:** in the CE QA profile, open the **public** game. It must show **PLAY** and a fresh start at Level 1. If it shows your progress, the profile is not isolated: **stop** and tell me.
4. **Create a realistic save inside the QA profile:** play the public game there for a few levels (for item 11).
5. **Test both QA builds only inside the CE QA profile.** Item 11 is then checked on the save you just made: the candidate shows the same progress, and the public game afterwards still does.
6. **Never open the candidate in your normal Safari profile** until Production is approved.

**Fallbacks:**
- **No Safari profiles (iOS 16 or older):** use a different browser app for the candidates, for example Chrome or Firefox on iOS. Each app keeps its own website data separate from Safari. Repeat step 3 there. Safari-only behaviour (lock and background suspension) then still needs one short check in Safari.
- **Avoid Private Browsing.** Its storage is separate, but it is wiped when the tab closes, which defeats item 10.

### Checklist

Use an external stopwatch for item 2. "Card" means the result card after the clear.

| # | Check | How | Expected |
|---|---|---|---|
| 1 | Plausible time | Play any level normally | The card shows `TIME m:ss` matching roughly how long you played |
| 2 | Matches a stopwatch | Start the stopwatch on the first frame the board can be tapped, stop it on the winning tap | Within about 1 s (the card rounds seconds down) |
| 3 | App switch excluded | Mid-level, switch to another app for 30 s, come back, finish | The card time doesn't include the 30 s (compare with the stopwatch minus 30 s) |
| 4 | Lock excluded | Mid-level, lock the phone 30 s, unlock, finish | Same as 3 |
| 5 | Menus, blocking overlays and guided lessons pause | Mid-level, open Settings / Shop / Level Select for 20 s each. In the QA build, open `?experiencelab=76`, wait 20 s on the NEW MECHANIC card, then take about 20 s to follow the finger lesson. Start the stopwatch when the lesson's success line appears, and stop it on the winning tap | None of that waiting or guided time appears. The card time roughly matches the stopwatch from the end of the lesson |
| 6 | Restart and retry reset | Play 20 s, Restart, then finish quickly. Lose all hearts on a heart level, then finish the retry | Only the final attempt's time is shown. Restarted or failed attempts never show up as records |
| 7 | Assisted vs clean | Clear a level once using Show a Move, Undo or Hammer; clear it again with none, more slowly | The assisted clear sets BEST. The clean clear isn't a new BEST (card shows `BEST`), but it sets the clean record |
| 8 | Replay improves BEST | REPLAY a cleared level faster | `TIME … · NEW BEST TIME!` in the accent colour |
| 9 | Replay improves BEST CLEAN | After 7, REPLAY clean and faster than the clean record. Then REPLAY with a hint, slower | The clean record improves (not shown on the card in Phase 1). Then the hinted, slower run changes neither record (card: `BEST …`) |
| 10 | Survives reload and closure | Reload the page; close Safari completely and reopen; REPLAY a cleared level slowly | The card still shows the earlier `BEST` |
| 11 | r2 progress unchanged | In the CE QA profile, after playing the public game there (step 4), open the candidate. Afterwards open the public game again | The candidate shows the same CONTINUE level, coins, stars, scores and boosters, without any reset. The public game then still shows the same progress, plus anything played in the candidate |
| 12 | Card fits small screens | On the smallest iPhone available (SE if possible), clear Level 1. In the QA build, also open `?experiencelab=100` and clear it | The time line is fully inside the card. REPLAY / NEXT are not pushed off-screen |
| 13 | Embed vs own tab | Play the same level in the itch embed and in its own tab (open in a new tab / full screen) and time both with the stopwatch. In the embed, tap the itch page outside the game once mid-level | Both times match the stopwatch. Tapping outside the embed doesn't pause the clock |
| 14 | Stability | Play 10–15 minutes across levels with sound on | Audio, touch response, animations and performance are the same as the released build |

Report any item that fails, with the level number, what the card showed, and the stopwatch reading.
