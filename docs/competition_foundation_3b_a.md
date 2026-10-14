# Competition foundation: Phase 3B-A (local only)

**Status:** local commit only. Nothing is sent anywhere, nothing is shown, and no save changes.

This phase prepares two things for later real-player percentiles: a measure of how trustworthy one attempt's time is, and a stable identity for each campaign level. Submissions, the backend, percentile UI and leaderboards come later.

## 1. Frame-cap accounting (`scripts/core/attempt_timer.gd`)

`AttemptTimer` adds at most `MAX_FRAME` (250 ms) per frame. That has not changed, so the shown time, the Personal Best and its saving are exactly as before. What is new is a record of what the cap left out:

| Field | Meaning |
|---|---|
| `discarded` / `discarded_ms()` | Active time beyond 250 ms in frames after the first one |
| `capped_frames` | How many such frames |
| `longest_frame` | The longest of them |
| `start_frame` | The attempt's first active frame (level build and first render), kept apart |

- **What counts:** only active frames. Pauses (Settings, Shop, Level Select, cards, intros, lessons) add nothing, nor does the dropped first frame after the page was hidden (Safari in the background).
- **Reset:** `reset()` clears it all, so restart, replay, NEXT and retry each start at zero.
- **Cost:** one extra branch per frame; work is done only inside the rare over-250 ms branch, with no allocation.
- **Where it shows up:** `cap_info()` is merged into the finished attempt's `last_time_result` and published in the test page state (`attempt_cap`). It is **never saved**.

### Measured (Chromium + SwiftShader, iPhone SE size, `tools/web_frame_cap_probe.mjs`)

| Scenario | Start frame | Discarded in play |
|---|---|---|
| Levels 6, 31, 77, 150, 227, 280: 15 s on the board + auto-solve | 1,614–2,143 ms | **0 ms** |
| The same with CPU throttled ×4 / ×6 (77, 280) | 1,998–2,176 ms | **0 ms** |
| A 1.5 s JavaScript long task during play (150) | 1,979 ms | 1,341 ms (1 frame) |
| Tab in the background for 5 s, then back (150) | 2,008 ms | 549 ms (1 frame, 799 ms, after the dropped resume frame) |

- **The level-load stall:** every attempt began with a 1.6–2.2 s first frame, the level build and first render. The cap already limits its share of the shown time to 250 ms. Counted as discarded time, it would have flagged every attempt, so it is kept apart as `start_frame`.
- **Normal play** discarded nothing, even when throttled.
- **Real stalls** (a long task, a debugger pause) are visible.
- **Resuming** from the background can add one more long frame, about 0.5 s discarded.

**These are desktop-emulation numbers. Real iPhone Safari values are still unknown.**

### Recommended eligibility rule (not enforced)

- **Phase 3B-B:** send `discarded_ms`, `capped_frames` and `start_frame_ms` with each result, and reject nothing on them yet. Collect real data in the `qa` pool and from early real players.
- **Starting candidate:** an attempt is eligible when `discarded_ms ≤ max(1500, 10 % of time_ms)`. That allows two or three background resumes, and still excludes deliberate stalls such as a debugger pause or a frozen tab while thinking.
- Fix the final threshold from real iPhone data before enforcing it.

## 2. Level fingerprints (`scripts/core/level_fingerprint.gd`, `data/level_fingerprints.json`)

- **Coverage:** one SHA-256 per campaign level, 300 of 300, all unique.
- **Formula:** `sha256("chain-escape-level|v1|<number>|<canonical gameplay json>")`.
  - The canonical form is every key of the level file except the presentation keys (`name`, `hint`, `hint_finger`, `blocked_hint`), with sorted keys, as compact JSON.
  - Today that covers `map` and `mystery`. Any rule key added later (`hearts`, `hints`, `stars`, which the parser already reads) changes the fingerprint automatically.
- **Tools:**
  - `tools/level_fingerprints.gd` writes the manifest.
  - `-- --check` verifies it, exiting with 1 on a stale, missing or duplicate entry.
  - `tools/run_tests.gd` (`test_level_fingerprints`) fails while the manifest is stale.
- **Verified:**
  - An independent Python reimplementation reproduces all 300 values.
  - In a throwaway copy, renaming a level and changing its tutorial text kept it valid, while changing one board row reported "level 150: stale fingerprint".
- **Level files** are only read, never changed.
- **Not included:** global rules outside the level files (hearts from level 15, the 250 ms timing rule). If those ever change, raise `LevelFingerprint.VERSION`.

## 3. Player secret: deferred

**Not added.** The Phase 3A UUID is reused unchanged. A secret only makes sense together with the server that checks it:

- it defines the claim-on-first-use rule;
- migration and old saves are a server-side decision (a save without a secret simply gets one on its first submission);
- it needs a backup/restore and two-device policy, which belongs with the submission rules.

Adding it now would put an unused credential into Production saves. In 3B-B it becomes one additive key in `[profile]`, written only when the first submission is made, and covered by ProfileCheck merge and backup tests.

## 4. Untouched
- Save keys, sections and file format. Nothing new is written.
- The shown time, the Personal Best, pauses, background behavior, restart / replay / game over.
- The 300 level files, the goldens, scoring, the economy and the UI.
- Supabase and the network: no request is made.
