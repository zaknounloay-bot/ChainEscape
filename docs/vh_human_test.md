# VERY HARD — blind human test (development only, phase 3d)

**Question:** can arrows + clockwise spinners alone produce puzzles that experienced players genuinely perceive as VERY HARD?

Nothing here changes production:
- no backend, Supabase or API contract change
- no sharing; the live Friend Challenge, Photo / Message and Classic are unchanged
- the live VERY HARD keeps SHOW A MOVE x2 / HAMMER x2

The test page opens only with `?vhtest=1`.

## The test page (`?vhtest=1`)

`scripts/social/vh_human_test.gd` (`VhHumanTest`), opened at launch like the `?friendbench=1` developer page.
- **Boards:** 15 fixed boards from `data/dev/vh_human_test.json`. The phone generates nothing, so every tester plays exactly the same boards.
- **Order:** random per device, with the variants interleaved and never shown. Every puzzle is labelled only "PUZZLE n / 15" and "VERY HARD".
- **Play:** the real SocialPlay (same rules, visuals, UNDO, SHOW A MOVE, HAMMER, RESTART), with this test's assistance: **UNDO x3, SHOW A MOVE x1, HAMMER x1**, reset by RESTART as in the game. Giving up = EXIT → LEAVE.
- **After each puzzle:** "How difficult was this puzzle?" (EASY / MEDIUM / HARD / VERY HARD), then the optional "Did you have to stop and think before your first move?" (YES / NO / SKIP).
- **Recorded locally for each puzzle:**
  - board id, variant (hidden from the tester) and fingerprint
  - solved / not solved
  - time, and time to the first move
  - moves, restarts, UNDOs, SHOW A MOVE and HAMMER uses
  - rating and the first-move answer
- **Storage:** stored only in the test's own file (`user://vh_human_test_state.json`, the browser's local storage on the Web). Closing and reopening the page resumes where you left off.
- **Results:** a count while the test is running, and the comparison by group only after the last puzzle (so the test stays blind). **COPY RESULTS** copies everything as JSON (the copy runs inside the tap, like COPY LINK), ready to paste into the chat. **START OVER** clears this test only.
- **SocialPlay additions:** a `solved` signal, per-instance `max_hints` / `max_hammers` (defaults = the game's x2 / x2; only this page sets x1 / x1), and per-challenge totals across attempts. Nothing changes for the game.

## Variants

| | What | How the boards were made |
|---|---|---|
| **A** | Current production VERY HARD (`87c92db`) | `FriendGenerator` VERY HARD as the live game runs it (1.5 s cap) |
| **B** | Heuristic-selected VERY HARD with an **opening constraint** | Offline search (30 s cap per board), arrows + clockwise spinners only. Criteria: 1–2 legal first moves, **exactly one** of them safe, **no "calm" first move** (every first move turns a spinner, so none is obviously safe), ≥ 5 later one-safe-move steps, safe choices ≤ 1.9 per step, ≥ 8 decision steps, random tapper ≤ 5%, heuristic player ≤ 12%. 14 candidates searched; the 6 with the lowest independent heuristic-player rates kept |
| **C** | VERY HARD + Classic Locks prototype (control) | The lock audit's prototype spec (`docs/lock_prototype_audit.md`) |

6 A, 6 B and 3 C boards (B vs A is the main comparison; C is a control).

## Board statistics (independent re-measurement)

| | Free at start | Safe first moves | Only one safe opening | "Calm" first moves | One-safe steps later | Safe choices / step | Decision steps | Depth | Heuristic player 2 / 3 | Random tapper |
|---|---|---|---|---|---|---|---|---|---|---|
| A | 3.17 | 2.33 | 0 / 6 | 1.83 | 3.50 | 1.93 | 12.2 | 10.8 | 21.0% / 29.5% | 1.2% |
| **B** | **2.00** | **1.00** | **6 / 6** | **0.00** | **7.67** | **1.48** | 12.5 | 13.3 | **5.2% / 7.2%** | 0.5% |
| C | 3.00 | 2.33 | 0 / 3 | 1.67 | 9.33 | 1.37 | 13.3 | 12.7 | 44.7% / 40.6% | 0.0% |

- **"Calm" first move:** a legal first move that turns no spinner. It is always safe, so a player who knows the rules takes it without thinking.
- **Heuristic player:** plays calm moves first and looks 2 / 3 moves ahead only at forced spinner moves (`Solver.heuristic_win_rate`).

## Search cost

| | Time per board | Notes |
|---|---|---|
| A | p50 1.5 s, max 2.0 s | production budget |
| **B** | 8 of 14 seeds found a board within the 30 s cap; those took **1.7–26 s** (median about 15 s) | offline only: far beyond the live budget. If B wins with people, a pre-generated pool would be the way to ship it (not decided) |
| C | 0.7–0.8 s | |

The whole 15-board set took about 5 minutes to build (`tools/vh_human_test_build.gd`).

## How to run it on an iPhone

1. Upload the development ZIP to a **separate, private itch.io page** (restricted / draft), not the live game page. The build plays exactly like the live one; only `?vhtest=1` adds the test. A separate page keeps the live page untouched.
2. Open that page in Safari and add `?vhtest=1` to the game's address, with `&` if the address already has a `?` (for example `…/index.html?v=123&vhtest=1`).
3. Each tester uses their **own iPhone**. Tap START and play all 15 puzzles. Breaks are fine: reopening the same address continues where you left off.
4. Rate each puzzle honestly; the optional question can be skipped.
5. After the last puzzle, tap **COPY RESULTS** and paste the text into the chat. If copying fails, a screenshot of the results screen also works.
6. **START OVER** only if a tester wants to begin again: it clears that phone's results.

## Checks

- `godot --headless --path . res://tools/VhHumanTestCheck.tscn`: board set integrity, blind order, x1 / x1 with RESTART reset, solve → rate → next, give up, resume, results export, no Classic save, game defaults unchanged.
- `node tools/web_vhtest_page_test.mjs build/web`: real Chromium with real touches. The board set is in the build; COPY RESULTS reaches the clipboard; no network request at all; without `?vhtest` the normal title opens.
