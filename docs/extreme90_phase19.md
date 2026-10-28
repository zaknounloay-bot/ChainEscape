# EXTREME Time Attack — Phase 19: strategic variety

Development only. Production, the 300 frozen levels, Supabase, the Social
MVP, Challenge a Friend and campaign timing / MY BEST are untouched.
Entry: `?extreme90p19=1` (dev builds only). `?extreme90=1`,
`?extreme90p17=1`, `?extreme90p18=1` and `?ta90=1` are unchanged.

## Step 0 — Repository safety

Branch `claude/elegant-fermat-0jrmxo`, HEAD `2277eed8…` (the approved
Phase 18B baseline), clean tree, in sync with `origin` (0 / 0). Board ids
N1–N34 and TA registered with their fingerprints; N35+ unused. The Phase
18B continuation fix present (`board_at_timeup`, the exact-resume offer).

## Step 1 / 2 — Human decisions and the Phase 18 calibration

Selection kept exactly: CORE N3, N5, N7, N11, N13 · STRONG N14, N15, N16,
N18, N21, N26, N27, N29, N30, N31, N32, N33, N34 · PROVISIONAL N23, N24 ·
ARCHIVED N17, N19, N20, N22, N25, N28. No definition, fingerprint or record
changed; no provisional board promoted.

Phase 18 calibration (three family players, iPhone, small sample):

| Board | Core | Outcomes | Ratings | What it says |
|---|---|---|---|---|
| N31 | magnet relocation, no spinner | 3 × TIME UP | EXTREME, EXTREME, VERY HARD | difficulty without spinners is possible |
| N32 | magnet + armor, no spinner | 2 × TIME UP, 57.01 s | EXTREME, EXTREME, HARD | same |
| N33 | spinner + crate | 3 × TIME UP | EXTREME, EXTREME, VERY HARD | Movable adds real variety |
| N34 | spinner + portal | 64.25 s, 83.97 s, TIME UP | HARD, VERY HARD, VERY HARD | portal the weakest of the four |

Lesson carried into Phase 19: non-spinner difficulty works, but both
non-spinner successes were magnet boards — Phase 19 had to avoid trading
spinner dominance for magnet dominance (at most 3 magnets per board, a
`suffix_max` cap in the search).

## Step 3 — Mechanics support (Phase 18 audit, re-confirmed)

Class A for the 90 s mode: all four spinner rules, lock, switch / flip,
gate, armor + rammer, magnet, Movable crate, portal, Sequence (play and,
since Phase 18B, exact TIME UP continuation). Twins and hidden blocks stay
out of scope. Re-confirmed in this phase: PortalCheck, MovableCheck and
MagnetCheck (solver vs brute force) pass; Ta90ContinueCheck (exact TIME UP
continuation, every field of every block) passes on all 20 selection boards
and the new ones. No engine change was needed.

## Step 4–6 — Design approach

The working principle from Phase 18 (losing moves come only from
non-monotone changes) was sharpened into a **deadlock-pair** rule: a
switch flip or a magnet pull is a real decision when, made too early, it
turns or drags a block face to face with a block that is waiting for it.
Every core was drawn with at least two independent traps. Growth used plain
arrows plus the core's own marks (`palette: "arrows"`, `suffixes`), capped
per mark (`suffix_max`: at most 3 magnets, 3 flip targets per switch);
crates were placed so a crate can be pushed at most once (a crate in an open
row multiplies positions — the first MF2 core had 5 325 positions and a
96.5 ms TIME UP check).

## The Phase 19 candidates

Both are **HUMAN-REVIEW CANDIDATES** (Category A and B pass; human
difficulty unvalidated). **Both are non-spinner (no spinner on the board).**

| ID | Grid | Pieces | Mechanics | Family | Strategic concept | Fingerprint |
|---|---|---|---|---|---|---|
| N35 | 7×7 | 17 | 1 crate, 2 switches + 6 flip targets, 4 shells | A/E Movable + switch + armor | push, turn, ram: a block pushes the crate out of a column and can only leave once its switch reverses it — then it must crack the shell behind it; the push itself closes the other switch's lane | `3e6a96041ad6e090b24ea50696b7436ff8819b14d5c73d5974ae5b9121d6adc2` |
| N36 | 7×7 | 17 | 3 magnets, 1 switch + 3 flip targets | C/D magnet + switch | two ways to lock blocks face to face: a magnet drags a block under one pointing back at it, the switch turns a block toward one waiting for it — each must wait for the right block to leave | `0ce35e1d021d6a7e0496c5439836e429c769a321f5bce1638484edea380971c6` |

### A / B / C results

| ID | Positions | Solution | TIME UP worst (desktop) | Parity | Distinct | Steps | Coverage / late | Shortcut | Counterfactuals (every listed mechanic) | Trap delay | Undo-proof | Learner (look4/6) | Trivial removals | Closest board (overlap) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N35 | 467 | 21 | 14.2 ms / 617 nodes | 0 / 0 | 4 | 18 | 0.86 / 0.86 | 0.017 | without crate: 14 steps, 1 distinct; without shells: 9 steps, 3 distinct; without switches: unsolvable | 11 | 1.00 | 5 / 5 | 0 | N16 (0.21); N36 (0.27) |
| N36 | 372 | 17 | 9.0 ms / 113 | 0 / 0 | 4 | 15 | 0.88 / 0.88 | 0.017 | without magnets: 5 steps, 1 distinct; without switch: unsolvable | 9 | 0.84 | 6 / 6 | 0 | N32 (0.32); N35 (0.27) |

Category A: parse intact, verify, Solver = exhaustive search in every
reachable position, deterministic replay, TIME UP ≤ 40 ms from every
reachable position (both far below), exact TIME UP continuation
(Ta90ContinueCheck: prefix, dead end, undo + restart, lost tap — all exact);
WebAssembly and iPhone SE in the browser QA. Category B: EXTREME targets
met, every mechanic essential, no filler, no near copy.

### Known weaknesses

- **N35** — the busiest mechanic mix of the set (crate, two switches, six
  flip targets, four shells); 4 distinct mistakes, at the EXTREME floor.
  It shares its crate trap with the rejected MF2 boards (see below), so the
  crate idea appears once.
- **N36** — a magnet board (3 magnets), like N31 / N32; 4 distinct
  mistakes, at the floor; the closest to an existing board (N32, 0.32).
- **Only two boards, both medium (17 pieces)** — fewer than the 3–5 the
  brief anticipated; delivered rather than padded. Three non-spinner
  boards (N31, N32 in Phase 18; N36 here) now use magnets.
- **Fewer than 5 non-spinner boards**: the target was not reached (2 of 2
  accepted boards are non-spinner, but only 2 were accepted).

## Search and rejection summary

15 bounded searches (12 min each, patience 8), 16 772 boards evaluated;
13 full A/B/C reports and 13 filler checks (9 + 3 beam boards, and MG3 without its locks).

| Core | Family | Best reached | Outcome |
|---|---|---|---|
| MF2 (round 1) | A crates + two switches | — | redrawn before searching: two crates in open rows, 5 325 positions, 96.5 ms TIME UP |
| MF2 (round 2) | A crate + two switches | 4 distinct, 14 steps | all three beam boards pass A/B; **rejected as overlapping N35** (0.43 occupancy overlap, the same crate trap — a reused trick) |
| PX → PX2 | B portal + crate + switch(es) | 3 → 2 distinct | **rejected** after one redesign — portal-first family abandoned (a portal reroutes lanes but makes no losing move on its own; the traps came from the switch and crate, not the routing) |
| SG3 → SG4 | C switch / gate | 2 → 2 distinct (100 % shortcut) | **rejected** after one redesign — switch/gate family abandoned (greedy play avoids early reversals) |
| MG2 → MG3 → MG3b | D magnet (+ lock) | 2 → 4 → 3 distinct | MG3's three boards pass A and the decision targets, but **their locks are decorative** (lock counterfactual: no change); without the locks the board fails Category A (1 149 positions, opening solve 42.2 ms); a magnets-only rerun reached 3 distinct — **rejected** (record: `rejected_MG3_1.json`) |
| AS → AS2 | E rammer / armor + switch | 1 → 3 distinct | **rejected** after one redesign |
| SQX → SQX2 | F Sequence + magnet | 2 → 3 distinct | **rejected** after one redesign (Sequence again repeats one mistake) |
| MX4 | C/D magnet + switch | 4 distinct, 15 steps, 0 % | **N36** |
| MAS → MAS2 | A/E crate + switches + armor | 3 → 5 distinct | **N35** (MAS2_2; MAS2_1 not taken: TIME UP 39.7 ms, at the gate) |

No borderline timing was re-measured; no threshold changed.

## Step 8 — The Phase 19 developer selection (`?extreme90p19=1`)

`Extreme90P19` (extends `Extreme90P18`). Its own storage `xb19_*` /
`chain_escape_xb19_hub` and export `ce-xb19` (each board's id, fingerprint,
mechanics and group — `phase19` for the new boards — and the archived ids).
No locks; any challenge opens directly.

### QA selection refinement (permanent rule)

The primary testing screen of a new EXTREME development phase shows **only
that phase's new puzzles**; testers never have to find, remember or scroll
past boards an earlier phase already tested.

| Screen | Contents |
|---|---|
| CHOOSE A CHALLENGE (primary) | CHALLENGE 1 = N35, CHALLENGE 2 = N36; then PREVIOUS CHALLENGES, COPY ALL RESULTS, HOW IT WORKS |
| PREVIOUS CHALLENGES (optional) | CHALLENGE 3–22 = the Phase 18B selection (CORE, STRONG, N23 / N24 provisional) in its order, a scrolling list with BACK — for regression or voluntary replay |

How it works (the smallest change, in the shared hub `Ta90Prototype`):

- `previous_boards()` — the boards earlier phases already tested; default
  empty, so `?ta90=1`, `?extreme90=1`, `?extreme90p17=1` and
  `?extreme90p18=1` are exactly as before.
- `new_boards()` — found automatically: every board of the page not on the
  previous list. Phase 19: `previous_boards()` = the Phase 18B selection,
  so the new boards are N35, N36. A later phase extends this page and sets
  `previous_boards()` to this page's full list.
- Challenge numbers follow the page order (new boards first, then the
  previous ones), so no two tiles share a number. A board opened from
  PREVIOUS CHALLENGES returns there; a new board returns to the primary
  screen.
- Every export records the real board id (the export's key and every
  run's `board`), its fingerprint, its displayed challenge number and its
  `list` (`new` / `previous`), plus `new: ["N35", "N36"]`. The selection
  version is now `xb19-v2` (the numbering changed); the storage namespace
  stays `xb19` (records are kept per board id, so nothing earlier is
  overwritten). Earlier pages' storage and exports are untouched.
- Board ids, definitions, fingerprints, gameplay, the Phase 18B exact
  TIME UP continuation and the short questionnaire are unchanged.
- The Phase 19 "Newest: CHALLENGE 21-22 (scroll down)" line is gone — no
  longer needed.

## QA (final build)

Dev build ("Web") and player build ("Web Friend Test") exported from the
working tree; the player build contains 0 `data/dev` files.

| Suite | Result |
|---|---|
| Browser `?extreme90p19=1` (iPhone SE viewport) | 60 / 60 — scrolling list, every tile revealed and opened, labels fit, buttons on screen, xb19 storage, ce-xb19 export, TIME UP + exact continue |
| Browser `?extreme90p18=1` / `?extreme90=1` / `?extreme90p17=1` | 55 / 55, 45 / 45, 51 / 51 (unchanged) |
| Browser `?ta90=1` / `?tapilot` | 55 / 55, 28 / 28 |
| Browser timing / friend build / stime / ttime tta | pass, 25 / 25, 31 / 31, 32 / 32 |
| Extreme90p19Check / Extreme90p18Check | 120 / 111 checks pass |
| Ta90ContinueCheck (exact TIME UP continuation, all 22 boards) | 254 checks, 88 cases, 0 not resumed exactly |
| PortalCheck / MovableCheck / MagnetCheck | pass |
| Ta90Check / Extreme90Check / Extreme90p17Check | 91 / 91 / 97 |
| Headless regression (unit tests, competition, timing, profile, feedback, friend, social, pilot, extreme11, q1/r time) | pass |
| verify_levels | all 300 levels solvable, campaign rules pass |

**Pre-existing failure (not Phase 19):** RecipientTest — the same 3 layout
checks ("TOTAL SCORE left, coins right" for en_US / he_IL / ar_SA) that
fail on the Phase 18B baseline.

WebAssembly full solve (the TIME UP check), headless Chromium on this
machine: N35 7.5 ms, N36 7.4 ms; slowest on the page N34 41.8 ms, N15
38.7 ms.

The browser tests run headless Chromium at an iPhone SE viewport; they are
**not** equivalent to testing on a real iPhone (touch feel, Safari, real
CPU speed and readability still need a device).

### Safety audit of the change

Runtime changes: one dev-gated hook in `game_manager.gd` (only when
`?extreme90p19=1`, dev builds), two `BOARDS90` entries (N35, N36), and two
opt-in hub accessors (`select_scroll`, `select_note`) whose defaults leave
every existing page unchanged. No campaign level, Production code,
Supabase, existing board definition, fingerprint or record changed. One
local commit; nothing pushed, merged, deployed or uploaded.

## QA — selection refinement (new boards only on the primary screen)

Re-run on a fresh dev / player export after the change:

| Suite | Result |
|---|---|
| Browser `?extreme90p19=1` (iPhone SE viewport) | 62 / 62 — the primary screen shows only CHALLENGE 1-2 (N35, N36), no scrolling; PREVIOUS CHALLENGES lists CHALLENGE 3-22 (every tile reached, BACK on screen, none of the new boards); every board played by touch, earlier boards return to PREVIOUS CHALLENGES; TIME UP + exact continuation; export names the new boards and every board's list under its real id |
| Browser `?extreme90p18=1` / `?extreme90=1` / `?extreme90p17=1` / `?ta90=1` | 55 / 55, 45 / 45, 51 / 51, 55 / 55 (unchanged) |
| Browser friend (player) build | 25 / 25; the player build contains 0 `data/dev` files |
| Extreme90p19Check | 123 checks (primary screen, PREVIOUS CHALLENGES, BACK, return to the right list, export lists) |
| Extreme90p18Check / Ta90ContinueCheck | 111 / 254 checks (88 cases, all resumed exactly) |
| Headless regression (incl. Ta90Check, Extreme90Check, Extreme90p17Check, TaPilotCheck) | pass |
| verify_levels | all 300 levels solvable, campaign rules pass |

Pre-existing, unchanged: RecipientTest's 3 layout checks ("TOTAL SCORE left,
coins right", en_US / he_IL / ar_SA).

One assertion of the new browser check was corrected during the run: it
assumed the PREVIOUS CHALLENGES list must scroll, but without the note and
the COPY / HOW IT WORKS buttons its 20 tiles fit on the iPhone SE screen.
The check now requires every tile to be reachable (as the headless check
does); the re-run passed.

Not run again (the change does not reach them; they passed on the Phase 19
build): the browser `?tapilot`, timing, stime and ttime pages.

Browser tests are headless Chromium at iPhone SE size, not a real iPhone.

## QA3 — deployment investigation and build identifier

Real-iPhone report on `html-classic.itch.zone/html/20096816/…?extreme90p19=1`:
the old layout (22 tiles, "Newest: CHALLENGE 21-22"). Findings:

- The QA2 ZIP was correct. Its `index.pck` file table and decompressed
  bytecode contain the new hub (`PREVIOUS CHALLENGES`, `PreviousScroll`,
  `PreviousBack`) and `xb19-v2`, and no "Newest" line. The first Phase 19 ZIP
  contains `Newest: CHALLENGE` and `xb19-v1`: the iPhone showed exactly that
  build.
- No service worker (PWA off). Godot loads `index.pck` by a fixed name with no
  version suffix, so `?v=` on the page URL refreshes `index.html` only.
- The deployed files could not be fetched from this environment (itch.io is
  blocked by its network policy). The symptom therefore points to the old
  ZIP still being the upload at that itch.io address, or a cached `index.pck`
  — not to the build.

Added: a developer-only build id, `DEV BUILD p19-qa3-20261028`, in small text
under the buttons on CHOOSE A CHALLENGE (`Ta90Prototype.build_label()`, empty
by default, so no other page changes), and `build` in the ce-xb19 export.
The ZIP also carries `BUILD_ID.txt`.

New browser test `tools/web_extreme90_p19_upgrade_test.mjs` (one origin, one
localStorage): N3 and N35 solved on the OLD build; then the NEW build shows
its build id and only N35 / N36, N35 still "Solved", N3 (CHALLENGE 3) still
"Solved" on PREVIOUS CHALLENGES, both records byte-for-byte unchanged, and
N36's new result added beside them; the export lists every run under its
real id and fingerprint — 9 / 9.

QA3 on the fresh export: Extreme90p19Check 124, Extreme90p18Check 111,
Extreme90p17Check 97, Extreme90Check 91, Ta90Check 91; browser
`?extreme90p19=1` 62 / 62, `?extreme90p18=1` 55 / 55, upgrade 9 / 9, friend
(player) build 25 / 25 with 0 `data/dev` files. Headless Chromium at
iPhone SE size, not a real iPhone.
