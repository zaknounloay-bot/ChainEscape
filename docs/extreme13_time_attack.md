# EXTREME phase 8: the 3-minute challenge on Q1 (`?q1time=1`)

Development only. It is an optional experiment, not a replacement for
EXTREME and not a campaign feature.

Not touched:
- Production, levels 1-300, the original Q1 board, Supabase, the Social MVP
  and Challenge a Friend;
- coins, progression and hearts;
- the campaign timer and Personal Bests;
- every other test mode.

Nothing is committed, pushed, deployed or uploaded.

> **Experimental limitation.** The older son has already solved Q1. His result
> here measures speed and mastery of a familiar puzzle, **not** blind
> first-time EXTREME difficulty. It is not evidence that 180 s is the right
> limit for new puzzles.

## 1. The board

The page reads the Q1 board from `data/dev/extreme11.json`, the unchanged
file of the `?ptest11` test (SHA-256
`435a1afd…cef6`, checked by the check). It refuses to start unless the
board's page fingerprint is exactly

`3fc4f9259fd8390236caf337bc5260c9b9e06eb36fec09032cdf452adb413711`

(`PuzzleDefinition.fingerprint()`, the value in both human sessions' logs).
If it does not match, the intro says the challenge is disabled, and START is
off.

## 2. Rules as built

| Rule | Behaviour |
|---|---|
| Start | On the first normally paced frame after the board appears (campaign convention: the level build / first render does not count; "normally paced" = a frame no longer than the campaign timer's `MAX_FRAME`, 0.25 s; fallback: 4 s after the board appears) |
| Runs through | moves, thinking, UNDO, RESTART, SHOW A MOVE, the page in the background, the page closed |
| RESTART | the board starts again; the clock is never reset and gets no time |
| UNDO | the board steps back; the clock does not |
| 0:00 | the run ends; a TIME UP card (not a popup during play) covers the board; recorded as **not completed**, with progress |
| Solve at the boundary | counts only if the winning move comes before 0:00 (elapsed < 180000 ms). The solve is handled inside the tap, so "exactly 0:00" is decided by the clock at that tap |
| Assistance | UNDO x3 per attempt; ONE SHOW A MOVE per run (the `?ptest11` rule: no refill on RESTART, kept through a reload, a lost position costs it); HAMMER x0 |
| Hearts | not used (the play screen has none) |
| New run | after a finished run (and its questions): a fresh 3:00 and a fresh SHOW A MOVE. Reloading or reopening an active run never restores the clock or SHOW A MOVE. START OVER is hidden while a run is active |

## 3. Timer and persistence design

**One run = one deadline.** State, in this mode's own storage
(`user://q1time_state.json` and localStorage `chain_escape_q1time_state`, the
same synchronous mirror the other test pages use):

`run = {n, started_unix, elapsed_ms, done, reopens, hidden_count, hidden_ms, stalls}`

How elapsed time is measured:
- **While the page runs:** `max(monotonic, wall)`.
  - *monotonic* is the engine's `Time.get_ticks_msec()` since this page took
    over the run, plus the elapsed time it started from;
  - *wall* is `Date.now()` minus `started_unix`.
  - The monotonic part means setting the device clock back does nothing. The
    wall part covers a phone whose monotonic clock stood still while Safari
    suspended the page.
- **Saved:** every second, at once when the page is hidden, at the end, and
  on every logged action. Saving goes through the page's existing state save
  (file and localStorage).
- **On reload or reopen of an active run:** elapsed = `max(saved elapsed,
  wall-clock time since started_unix)`. Time while the page was closed counts,
  and the saved value is a floor. If that is already 180 s or more, TIME UP
  is shown at once. The run record carries on (the `?ptest11` persistence),
  and the board starts again (logged `"o"`, counted in `reopens`).
- **The newest copy wins on load.** Every save is numbered, and the page
  loads the copy (file or localStorage) with the highest number. The `user://`
  file is flushed to IndexedDB asynchronously on the Web. The blind-test
  page's own rule, which prefers the file when both hold as many answers,
  brought back a stale run once in the browser tests: a reload had lost the
  run's background record. A SHOW A MOVE spent just before a reload could
  have come back the same way. The browser test now presses SHOW A MOVE and
  reloads immediately.
- **Visibility:** `visibilitychange` / `pagehide` / `pageshow` (this page's
  own listener) and the engine's pause / resume. Nothing pauses. Each hidden
  period is recorded (`hidden_count`, `hidden_ms`, log `"v"`). A frame gap
  over 1.5 s with no visibility event is recorded as a `stall`. Any of these
  marks the run `interrupted`.
- **Why it never pauses:** thinking time is meant to count. A clock that
  stopped in the background would let a player think with the app hidden.
  The cost is that a phone call costs time. Interruptions are recorded so an
  analyst can discount them.

**What a browser-only timer can and cannot guarantee.**
- It **does** stop the obvious resets: reload, closing the tab, backgrounding,
  RESTART, UNDO, and setting the device clock back while the page is open.
- It **cannot** stop:
  - editing or clearing the page's storage. A cleared storage simply starts a
    new session; the old one is lost, not restored;
  - setting the device clock **back** while the page is closed. That shortens
    the counted closed time, though never below the saved elapsed time, which
    is saved at least every second and when the page is hidden;
  - a modified build or a debugger;
  - a different browser or device, which is a new session.
- **The results are self-reported data, not tamper-proof records.**

## 4. UX

- **The countdown:** large (76 px, weight 900), centred between the play
  screen's top bar and the board, and never over the board (checked headless
  and in the browser at 375x667). It shows whole seconds, rounded up (3:00 at
  the start, 0:01 just before the end). Colour: the standard dark text on
  the page background, about 16:1 contrast.
- **The last 30 s:** a colour change to dark red `#B3261E` (about 6:1). No
  motion, no sound, no popup. There are no animations at all, so
  reduced-motion preferences are respected by construction.
- **Stable layout:** the board, the buttons and the touch targets are the play
  screen's own, unchanged. GIVE UP stays in its place. The old small
  elapsed-time clock under it is hidden, replaced by the countdown.
- **After the run:** a SOLVED / TIME UP / STOPPED card, then the questions.

## 5. What is recorded

Per run (`COPY RESULTS`, format `ce-q1-time-attack`):
- `outcome`: COMPLETED / TIME UP / GAVE UP;
- `elapsed_ms`, `remaining_ms`, `limit_ms`;
- `attempts` (= restarts + reopens + 1), `restarts`, `undos`;
- `hint_presses`, `show_a_move` (spends), `blocked_taps`;
- the full move log with timestamps and mechanism events (`"t"` = time up,
  `"o"` = reopen, `"v"` = hidden / stall);
- `max_cleared` (furthest progress in one attempt), `cleared_at_end`;
- `run_reopens`, `hidden_count`, `hidden_ms`, `stalls`, `interrupted`;
- `start_frames` (frame timing of the first 20 frames, diagnostics);
- the board fingerprint.

Then the answers:
- enjoyment, excitement and frustration, each 1-5;
- did the timer make it better (YES / NO / NOT SURE);
- play again (YES / MAYBE / NO);
- 3 minutes was TOO SHORT / ABOUT RIGHT / TOO LONG;
- optional free text.

`tools/human_replay.gd` can replay the log offline: `"t"` and `"v"` entries
are ignored, `"o"` acts as a restart.

**Open:** `index.html?q1time=1` from
`build/dev_qa/chain_escape_dev_q1time.zip`.

## 6. Files (none committed)

| File | Change |
|---|---|
| `scripts/social/q1_time_attack.gd` (new) | `Q1TimeAttack`, a subclass of the blind-test page: the clock, visibility, result card, questions, results |
| `scripts/game_manager.gd` | 4 lines: open the page for `?q1time=1`, next to the other developer pages (inert when developer pages are off) |
| `tools/q1time_check.gd`, `tools/Q1TimeCheck.tscn` (new) | end-to-end checks |
| `tools/web_q1time_page_test.mjs` (new) | browser test, iPhone SE, including a real 180 s run |
| `docs/extreme13_time_attack.md` (new) | this document |

Not changed:
- `scripts/social/vh_human_test.gd` and every other uncommitted Q1 /
  `?ptest11` file: byte-identical, checked by SHA-256 before and after;
- `SocialPlay`, `AttemptTimer` (the campaign timer), Personal Bests;
- the board file, levels, every other test mode.

## 7. Technical QA (this container, desktop)

| Test | Result |
|---|---|
| `Q1TimeCheck` (new, headless) | **37 / 37**, in every run. Covers: the exact board and fingerprint; isolation from `?ptest11` and every other mode; start after the board's first frames; accuracy (1 s within 30 ms); RESTART / UNDO / SHOW A MOVE neither give time back nor pause it; the last-30-s colour; the countdown never over the board; TIME UP mid-attempt, right after RESTART, and in a lost position after a spent SHOW A MOVE (not completed, board covered, saved at once); a solve 50 ms before 0:00 (COMPLETED) and at exactly 0:00 (TIME UP); a normal solve; reload / reopen (no clock or SHOW A MOVE restore, closed time counts, the saved time is a floor, a run that ran out while closed ends at once, reloading after TIME UP shows the result); background recorded and not paused; the questions and the record; results JSON; a new run with a fresh 3:00 and SHOW A MOVE; `?ptest11` unchanged |
| `web_q1time_page_test.mjs` (new; Chromium, iPhone SE 375x667, real touches) | **21 / 21 in 4 consecutive runs of the final build.** Includes a real reload, a visibility change and a DevTools page freeze (both counted), a **real full 180 s countdown** (TIME UP 180.39-180.59 s after the clock's own start; the excess is polling), the warning colour, and an immediate reload after SHOW A MOVE |
| Earlier runs before two fixes | (1) The clock started before the board's first render (a 2.5 s frozen first frame would have been counted): fixed; it now starts on the first normally paced frame. (2) A stale saved copy came back after a reload: fixed (Section 3). The test's own sampling bug was fixed as well. |
| Campaign timer / Personal Best (`web_timing_test.mjs`, player and development builds) | passed: the campaign timer and PB are unchanged |
| Browser regression | `?ptest11` 22 / 22, `?xtest8` 19 / 19 |
| Headless regression | Extreme11Check 74, VhHumanTestCheck 100, VhVal3Check 98, Extreme7Check 84, Extreme6Check 85, Extreme5Check 147, VhPilot4Check 439, MagnetCheck, TimingCheck, RevealMvpTest, SocialPlayTest, FriendFlowTest 149, CompetitionCheck, Era3ProdCheck, PortalProdCheck, SequenceCheck, MovableCheck, TwinsCheck: all passed |
| Preserved files | `vh_human_test.gd`, `human_replay.gd`, `extreme11.json` and every other uncommitted Q1 / `?ptest11` file are byte-identical to before this task (SHA-256) |
| Performance | the same board, play screen and SHOW A MOVE as `?ptest11` (within 40 ms, docs/extreme11.md). The countdown adds one label update per frame and a state save once a second |
| Real iPhone Safari | **not done: required before the test** |

**Dev ZIP:** `build/dev_qa/chain_escape_dev_q1time.zip` (git-ignored, not
uploaded), 13,118,716 bytes, SHA-256
`0d9aab798e3eafd31c6486349a1dff4f1fc3a532131fc6d8490aa9cac72349e8`. Open
`index.html?q1time=1`. It also contains every earlier test page; the earlier
ZIPs are untouched.

## 8. Known limitations and risks

- **Client-only timing** (Section 3). It stops obvious resets, not deliberate
  tampering.
- **Interruptions cost time.** The clock never pauses; phone calls and
  backgrounding are recorded, not excused.
- **Start delay.** The clock waits out the board's first render, which is
  not counted (as in the campaign). In the test browser, which renders in
  software, frames are slow and the 4 s fallback often applied: about 0.5-5.5
  s from the START PUZZLE tap. On a real phone frames are fast and the clock
  should start almost at once. On a slow phone it starts at the latest 4 s
  after the board appears.
- **Real iPhone Safari is not tested here.** Visibility, suspension and the
  frozen-page case were simulated in Chromium (a `visibilitychange` event and
  the DevTools lifecycle freeze). Safari's own behaviour, especially killing
  a hidden page, must be checked on the phone.
- **Familiar puzzle.** The older son has solved Q1; his time measures
  mastery, not first-time difficulty (top of this document).
- **Finding for `?ptest11` (not changed here):** the blind-test page prefers
  the `user://` file over the localStorage mirror when both hold as many
  answers. On the Web that file is flushed asynchronously, so a reload within
  the flush window could restore an unspent SHOW A MOVE or an older record.
  It did not happen in the two Q1 sessions (neither reloaded). This mode
  fixes it for itself; `?ptest11` was left byte-identical as instructed.
- **A frame gap without a visibility event counts as a `stall`.** On a very
  slow device, long frames could be recorded as interruptions; the count is
  data only.
