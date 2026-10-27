# EXTREME Time Attack — Phase 18B: TIME UP continuation stability

Development only (the 90-second pages: `?ta90=1`, `?extreme90=1`,
`?extreme90p17=1`, `?extreme90p18=1`). Production, the 300 frozen levels,
Supabase, the Social MVP, Challenge a Friend, campaign timing and MY BEST
are untouched. No puzzle, id, fingerprint or ordering changed.

## Part A — Human decisions recorded

Three family players, iPhone, first exposure
(`data/dev/extreme90_p18/human_p18.json`):

| Board | Mechanics | Outcomes | Difficulty | Decision |
|---|---|---|---|---|
| N31 | magnet | TIME UP ×3 | EXTREME, EXTREME, VERY HARD | strong |
| N32 | magnet + armor | TIME UP ×2, 57.01 s | EXTREME, EXTREME, HARD | strong |
| N33 | movable + spinner | TIME UP ×3 | EXTREME, EXTREME, VERY HARD | strong |
| N34 | portal + spinner | 64.25 s, 83.97 s, TIME UP | HARD, VERY HARD, VERY HARD | strong |

All enjoyment 5/5, all "play another" YES. Small-sample observations, not
validated difficulty labels.

Selection (`?extreme90p18=1`, order and CHALLENGE labels unchanged):
CORE N3, N5, N7, N11, N13 · STRONG N14, N15, N16, N18, N21, N26, N27, N29,
N30, N31, N32, N33, N34 · PROVISIONAL N23, N24 · ARCHIVED N17, N19, N20,
N22, N25, N28. 18 core / strong + 2 provisional. Only the export's internal
`group` of N31–N34 changes (`phase18` → `strong`).

## Part B — Backup

Remote `origin/claude/elegant-fermat-0jrmxo` was `8b0abf6`, an ancestor of
the local HEAD (0 commits behind, 2 ahead, clean tree). Normal push:
`8b0abf6..cc0aca3`; remote HEAD verified `cc0aca3`. The Phase 18B commit
below stays local.

## Part D — Diagnosis

How the page rebuilt the board after TIME UP (before the fix):

1. The run log does not store the tapped block: each move is inferred from
   the board before / after (`VhHumanTest.infer_tap`), `-1` when it cannot
   be told (an ambiguous ram; a crate pushed through a portal).
2. At TIME UP (`BlindTimeAttack._show_offer`) the moves of the current
   attempt (after the last RESTART / reopen; UNDO popped) were replayed on
   a fresh model by `_replayed`, which accepted only **escapes and rams**
   (Phase 18 added pushes and portals, for crate / portal boards only).
3. If the replay failed, **or** if the rebuilt position could no longer be
   cleared, the offer was `from: "fresh"` and the untimed game started on
   a NEW board. The card said "The board at 0:00 can no longer be cleared,
   so it starts fresh" in both cases.

Reproduced with a new deterministic test (`tools/ta90_continue_check.gd`,
before the fix): 60 cases (20 boards × 3), **24 not resumed exactly**:
- every `dead` case (all 20 boards: a losing move last, TIME UP),
- N5 and N7 in every case (prefix, dead, undo + restart) — winnable
  positions too.

**Issue 1 — Sequence (N5, N7, N21): confirmed, a bug.** A Sequence advance
was not a move the replay accepted, so any run with an advance before 0:00
lost its position and silently started fresh — and the card wrongly said
the position could not be cleared. N21's tested prefix had no advance, so
it passed there; any N21 run with an advance was affected the same way.

**Issue 2 — the N33 record (`untimed.from = "fresh"`, STOPPED after ~3.5 s):
the intentional Phase 10 rule, not a replay failure.** N33's replay is
sound (crate pushes were accepted since Phase 18; the prefix and the UNDO +
RESTART cases resumed exactly). What does reproduce it: TIME UP in a
position that can no longer be cleared — on an EXTREME board, the usual
case. The page then started a fresh board by design (the card said so).
The player did not choose a "fresh start": there was no such option — only
CONTINUE WITHOUT TIMER and FINISH. A fresh board after a few seconds and
STOPPED fits exactly. This rule contradicts the approved Part C decision.

Not affected: UNDO and RESTART during the timed run (only the current
attempt is replayed — passed on every board).

## Part E — The fix (`scripts/social/ta90_time_attack.gd`, dev-only)

The authoritative state is the BoardModel itself. Changes, all in
`Ta90TimeAttack` (the 90-second page; the 120 s pilot and the older blind
pages keep `BlindTimeAttack` unchanged):

1. **`_time_up`** captures the board of 0:00 — every gameplay field of
   every block (id, cell, colour, direction, kind, lock, hidden, spin rule
   and step, rarity, switch / flip / gate / link groups, armor, Sequence
   stage and next arrow, twin, magnet) — into the timed record
   (`board_at_timeup`) before it is frozen.
2. **`_show_offer`** no longer starts fresh because the position cannot be
   cleared. The moves are replayed as the play screen dispatches them
   (escape, Sequence advance, push, ram; portals set) — for every board —
   and used only if they rebuild the captured board exactly (`resume:
   "replay"`, UNDO history kept); otherwise the captured board itself is
   restored (`resume: "snapshot"`). `from` is always `timeout_state`. An
   unclearable position is resumed too; the card says "That position can no
   longer be cleared: RESTART starts it again." (`winnable_at_timeup`
   recorded). Only a record with neither a replayable log nor a captured
   board (none can exist after this change) falls back to fresh, and the
   card then says it "could not be rebuilt".
3. **`begin_untimed`** shows the captured board when the replay could not
   rebuild it (as UNDO does: the model restored, the view synced).
4. **`_save_untimed`** keeps the board with every untimed save: a reload
   during the untimed game comes back to exactly that board.
5. Export (`Ta90Prototype.bundle`): each run also carries `untimed_from`
   and `untimed_resume`. Existing keys unchanged; old exports readable.

The timed result is never touched: TIME UP stays TIME UP; an untimed solve
is `untimed.outcome = "COMPLETED WITHOUT TIMER"` apart from
`timed_outcome`; MY BEST / campaign timing are not involved (dev pages
only). No new screen, button or question.

## Part F — Deterministic full-state tests

`Ta90ContinueCheck` (`tools/ta90_continue_check.gd`): **PASSED, 232 checks,
80 cases, 0 not resumed exactly.** For each of the 20 selection boards
(spinners of all four rules, switches / flips, gates, locks, shells and
rams, magnets, crate, portal, Sequence):

| Case | What happens before TIME UP |
|---|---|
| prefix | 40 % of the Solver's line |
| dead | the same, then a losing move (0:00 cannot be cleared) |
| undo_restart | 2 moves, RESTART, the prefix, UNDO, one move again |
| lost_tap | the prefix, plus a move the log could not attribute (`-1`) |

Each: TIME UP by the test clock; the board captured (every field of every
block); SKIP; CONTINUE WITHOUT TIMER; the board shown compared field by
field. Also: TIME UP stays the timed result; `dead` resumes (never fresh,
recorded not winnable); `lost_tap` restores the captured board; UNDO right
after resuming takes back the last pre-TIME UP move (every prefix case).
Untimed flows on N33, N5 and N34 (with a lost tap): a reload during the
untimed game returns the same board; RESTART during it starts fresh and is
logged; solving it is stored apart (`COMPLETED WITHOUT TIMER`, 1 restart,
timed TIME UP); the export shows `timed_outcome: TIME UP`,
`timed_success: false`, `untimed_success: true`, `untimed_from:
timeout_state`, `untimed_resume`.

Before the fix the same test failed 24 of its 60 original cases (Part D).

## Part I — Regression

Dev Web export and player export (`Web Friend Test`: 0 `data/dev` files).
Browser tests: Chromium at iPhone SE size (375×667), real touches — **not
equivalent to real-iPhone Safari**, which you test before approving.

| Suite | Result |
|---|---|
| Ta90ContinueCheck (new) | PASSED, 232 checks (80 cases, all exact) |
| Extreme90p18Check | PASSED, 111 checks (incl. the Phase 18B selection groups; N5's Sequence replay now exact on the 90 s page, `BlindTimeAttack` unchanged) |
| Extreme90p17Check / Extreme90Check / Ta90Check | PASSED 97 / 91 / 91 |
| web_extreme90_page_test `?extreme90p18=1` | PASSED 55/55 (timed win, SKIP, TIME UP → untimed with the calm mix, solved by touch, export, player build ignores the entry) |
| `?extreme90=1` / `?extreme90p17=1` / `?ta90=1` (browser) | PASSED 45/45 / 51/51 / 55/55 |
| 120 s pilot (`?tapilot=1`) | PASSED 28/28 |
| Campaign timing and MY BEST (web_timing; TimingCheck) | PASSED / PASSED |
| Challenge a Friend player build (web_friend_build) | PASSED 25/25 |
| Real-time timer pages: ttime tta | PASSED 32/32 |
| Real-time timer page: stime | first run 30/31 — "0:30-0:11 … a gentle pulse (luma 57-61)": the sampled frames missed the pulse's dip; one re-run PASSED 31/31 (luma 54-61). `?stime=1` runs `CountdownTimeAttack`, which Phase 18B does not touch |
| Headless suites (Competition, unit tests, Timing, Profile, ExperienceLab QA, Feedback, FriendChallengeApi, FriendFlow, SocialApi, SocialSmoke, SocialPlay, TaPilot, Extreme11, Q1Time, RTime, Portal, Movable, Magnet) | all PASSED |
| verify_levels | ALL 300 LEVELS SOLVABLE AND PASS CAMPAIGN RULES |

**Pre-existing (not Phase 18B):** RecipientTest — the same 3 layout
checks as in Phases 16–18 ("TOTAL SCORE left, coins right" for en_US /
he_IL / ar_SA).

**Scope check:** `BlindTimeAttack`, `VhHumanTest`, `SocialPlay`,
`BoardModel`, `Solver`, `PuzzleDefinition` unchanged. Changed: 
`Ta90TimeAttack` (the 90 s page), `Ta90Prototype.bundle` (two export keys),
`Extreme90P18` (N31–N34 group), tests and docs.
