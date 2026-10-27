# EXTREME Time Attack — Phase 17: human-calibrated expansion

Development only. Production, the 300 frozen levels, Supabase, the Social
MVP, Challenge a Friend and campaign timing / Personal Best are untouched.
Entry: `?extreme90p17=1` (dev builds only). `?extreme90=1` (Phase 16 bank,
15 boards) and `?ta90=1` (N1–N13) are unchanged and remain the archive /
developer entries.

## 17A — Calibration from the human results

### The data

| Board | Outcome | Attempts | Difficulty | Enjoyment | Decision |
|---|---|---|---|---|---|
| N14 | TIME UP | 10 | EXTREME | 5 | strong |
| N15 | TIME UP | 7 | EXTREME | 5 | strong |
| N16 | 86.93 s | 5 | VERY HARD | 5 | strong |
| N18 | TIME UP | 5 | EXTREME | 5 | strong |
| N21 | TIME UP | 4 | EXTREME | 5 | strong |
| N23 | TIME UP | 7 | VERY HARD | 5 (borderline) | provisional |
| N17 | 36.26 s | — | MEDIUM | — | archived |
| N19 | 50.45 s | — | MEDIUM | — | archived |
| N20 | 29.60 s | — | EASY | — | archived |
| N22 | 22.78 s | — | EASY | — | archived |

One player and one session per board: these are direction-setting
observations, not a training set. No model was fitted to them.

### What Phase 16 measured, retained vs archived

All ten Phase 16 boards passed the same Category A/B gates and the
`EXTREME` NEED targets (distinct mistakes, decision steps, coverage, late
decisions, endgame, shortcut). The gates therefore **did not separate**
the boards the player found EXTREME from the ones solved in 23–50 s.

New human-oriented diagnostics (`tools/xb90_calibrate.gd`, results in
`data/dev/extreme90_p17/calibration.json`), with the core boards for
reference:

| | pieces | positions | win share | trap delay (median) | undo-proof | multi-turned spinners | prediction share | ordering-twin share |
|---|---|---|---|---|---|---|---|---|
| N14 | 14 | 1146 | 0.15 | 7 | 0.82 | 4 | 0.56 | 0 |
| N15 | 20 | 486 | 0.23 | 8 | 0.86 | 4 | 0.52 | 0 |
| N16 | 17 | 386 | 0.21 | 6 | 0.75 | 0 | 0.24 | 0.17 |
| N18 | 20 | 647 | 0.32 | 7 | 0.76 | 3 | 0.43 | 0 |
| N21 | 20 | 967 | 0.41 | 8 | 0.86 | 4 | 0.67 | 0 |
| N23 | 18 | 719 | 0.14 | 6 | 0.86 | 1 | 0.39 | 0 |
| N17 ✗ | 14 | 228 | 0.25 | 5 | 0.68 | 2 | 0.50 | 0 |
| N19 ✗ | 18 | 290 | 0.26 | 7 | 0.86 | 1 | 0.38 | 0 |
| N20 ✗ | 14 | 527 | 0.24 | 6 | 0.79 | 3 | 0.43 | 0.17 |
| N22 ✗ | 18 | 383 | 0.26 | 6 | 0.69 | 2 | 0.35 | 0.17 |
| N3 (core) | 14 | 58 | 0.29 | 3 | 0.41 | 1 | 0.23 | 0 |
| N5 (core) | 13 | 122 | 0.24 | 4 | 0.61 | 5 | 0.64 | 0 |

(The simulated "UNDO ×3 player" — calm moves first, random otherwise —
needed 80–105 attempts on every board, retained or archived alike, and 5
on N3: it does not separate anything and is reported only for
completeness.)

### Findings

1. **No Phase 16 gate separated the groups.** Distinct mistakes, decision
   steps, coverage, late decisions, shortcut share and the learner proxies
   were in the same ranges for retained and archived boards.
2. **Only weak, overlapping signals remain.** Retained boards lean towards
   more spinners turned more than once (median 4 vs 2), longer trap delays
   (7 vs 6), a higher undo-proof share (0.82 vs 0.74), more reachable
   positions (647 vs 337) and longer solutions. Every one is contradicted by
   a counter-example: N16 (kept, 0 multi-turned), N20 (archived, 3
   multi-turned, 527 positions), N19 (archived, trap delay 7, undo-proof
   0.86) and the core reference N3 (58 positions, trap delay 3). They are
   used as **advisory ranking signals only**, never as gates.
3. **Where the selection failed (qualitative, board by board).** The
   archived boards' decisions were mostly a *visible ordering chain*: a
   gate chain, two-switch timing, a rammer allocation, unlock → open → pull.
   Once seen, the order is read off the board and executed; their risk was
   real for the Solver but cheap for a human who looks before tapping.
   The retained boards make the player *predict a state change* that is not
   drawn on the board: spinners turned several times, pattern / alternating
   parity, where a pull lands, a reversal combined with turns.
4. **Size is not difficulty.** N3 (14 pieces, 58 positions) is the
   experiential reference; N19 and N22 (18 pieces) were solved in under a
   minute.

### What this does not claim

No threshold was tuned to one player's times; no predictive model was
built. The rule below is a design rule checked by a person reading each
candidate's core, with the diagnostics as supporting evidence.

## 17B — Updated filtering

**Category A (mandatory, unchanged).** Parses and verifies; worst-case
TIME UP solver call ≤ 40 ms on desktop; no solver exhaustion; WASM cost
measured in the browser; fits the iPhone SE screen with touch targets;
no portals / hidden blocks; existing mechanics only. Not loosened.

**Category B (mandatory).** The strategic checks of `ta90_design.gd`
(interacting dependencies, consequential ordering, mistakes at different
stages, late risk, every listed mechanic essential by counterfactual,
non-trivial restart decision, distinct concepts, minimal shortcut), plus
the Phase 17 human review of the core:

- the core idea requires **predicting a state change** (multi-turn
  spinners, pattern / alternating parity, pull destinations, reversal with
  turns) — a visible ordering chain alone is not enough;
- rejected: long-but-easy boards, decorative mechanics, predetermined
  sequences, independent filler pieces, one trick plus filler, and any
  reused solution or trick from the bank or the archive (N17, N19, N20,
  N22 included).

**Category C (advisory, ranking only).** Greedy and learner proxies,
depth, distinct mistakes, late risk, shortcut share, solver cost,
dependency density, independent trivial removals, and the new
`pressure` diagnostics (`ta90_design.gd pressure()`): spinners turned more
than once, trap delay median, undo-proof share, prediction share and a
0–4 `signals` count. The search (`ta90_search.gd`, `pressure_weight`)
ranks with them; nothing is rejected on them.

## 17C — Phase 17 candidates (N24–N30)

Eight hand-drawn cores (`data/dev/extreme90_p17/cores.json`), each built
around a state change the player must predict, grown by the bounded
search (`ta90_search.gd`, 12 min per core, patience 8, `pressure_weight`
3, `max_solve_nodes` 300 for large boards), then the full
`ta90_design.gd` report, the trivial-removal check (`xb90_filler.gd`) and
a similarity check against N1–N23. Seven accepted, all labelled
**HUMAN-REVIEW CANDIDATE** (technically validated, human difficulty
unvalidated). "Weak" mechanics below are the ones whose counterfactual
costs only one distinct mistake; they are kept and named as weaknesses.

| ID | Size | Grid | Pieces | Mechanics | Concept (core) | Fingerprint |
|---|---|---|---|---|---|---|
| N24 | large | 7×7 | 23 | cw, ccw, alt spinners | domino: a row of spinners turn each other as they leave — the leaving order sets every later facing | `c01585766042da0d…` |
| N25 | large | 7×7 | 20 | spinners, gate | silent gate: the spinner beside the gate must leave through it unturned; any neighbour leaving first turns it into a deadlock | `c1b4d6f3bb6c9ba4…` |
| N26 | large | 7×7 | 22 | spinners, magnet | pull into parity: a magnet pulls an alternating spinner into a three-neighbour spot, where its turn count decides its exit | `995326ce4c6ac4e8…` |
| N27 | medium | 7×7 | 16 | spinners, magnet | pull away: a magnet pulls a spinner out of a neighbourhood whose departures would turn it wrong | `1c4e8da7efa34424…` |
| N28 | compact | 7×7 | 13 | cw, alt, pattern spinners, Sequence | advances on a rhythm: two Sequence blocks advance beside a pattern spinner — each advance is also a turn | `01e190ffd12506be…` |
| N29 | medium | 6×6 | 17 | cw, ccw, alt spinners | alternating chain: adjacent alternating spinners turn each other back and forth | `c3ba04c3fe248df1…` |
| N30 | medium | 6×6 | 17 | spinners, lock | parity key: the only purple key is an alternating spinner; it must leave facing out after an even number of turns | `fffe88195b3a60e0…` |

Full fingerprints, maps and reports: `data/dev/ta90_n24.json` …
`ta90_n30.json` (each holds its `design_report`: A, B, C, filler and
similarity), summary in `data/dev/extreme90_p17/accepted.json`.

### Category A / B / C results

| ID | Positions | Solution | TIME UP worst (desktop) | Distinct | Steps | Coverage / late | Shortcut | Multi-turned | Trap delay | Undo-proof | Signals | Trivial removals | Closest board (overlap) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N24 | 1560 | 23 | 19.0 ms / 307 nodes | 6 | 20 | 0.87 / 0.87 | 0.18 | 4 | 7 | 0.78 | 4 | 0 | N13 (0.42) |
| N25 | 607 | 19 | 18.0 ms / 286 | 6 | 16 | 0.84 / 0.84 | 0.04 | 3 | 7 | 0.81 | 4 | 0 | N15 (0.37) |
| N26 | 466 | 22 | 8.2 ms / 118 | 6 | 20 | 0.91 / 0.91 | 0.00 | 5 | 9 | 0.78 | 4 | 0 | N22 (0.29) |
| N27 | 1028 | 16 | 33.8 ms / 710 | 7 | 13 | 0.81 / 0.88 | 0.01 | 5 | 7 | 0.81 | 3 | 0 | N5 (0.42) |
| N28 | 470 | 15 | 25.6 ms / 303 | 6 | 13 | 0.87 / 0.87 | 0.04 | 3 | 8 | 0.83 | 3 | 0 | N14 (0.42) |
| N29 | 1019 | 17 | 13.3 ms / 281 | 5 | 15 | 0.88 / 0.88 | 0.07 | 5 | 7 | 0.78 | 3 | 0 | N5 (0.35) |
| N30 | 443 | 17 | 6.6 ms / 107 | 6 | 15 | 0.88 / 0.88 | 0.12 | 4 | 6 | 0.69 | 1 | 0 | N5 (0.42) |

Category A: every board parses, verifies, replays, stays under the 40 ms
desktop TIME UP gate with no solver exhaustion, and fits the iPhone SE
screen (browser QA below). Category B: every board passes the
`ta90_design.gd` EXTREME checks (verdict HUMAN-REVIEW CANDIDATE), every
listed mechanic is essential by counterfactual, and no piece can be
removed without losing a decision (0 trivial removals). Overlap is
cell occupancy + spinner placement under the 8 symmetries; ≤ 0.42 for
every pair with N1–N23 and ≤ 0.41 among the new boards (no near copy).

### Weaknesses (honest list)

- **N24** — the largest board (23 pieces) and the highest shortcut share
  (0.18, under the 0.20 gate): the risk of a "long but readable" board.
- **N25** — the gate costs only one distinct mistake (6 → 5): the silent
  gate may read as a plain ordering chain, the pattern 17A warns about.
- **N26** — the alternating mechanic costs one distinct mistake; the
  magnet carries the idea.
- **N27** — the slowest TIME UP solve (33.8 ms desktop, 710 nodes): the
  closest to the Category A gate; WASM cost measured below.
- **N28** — the pattern spinner costs one distinct mistake; the Sequence
  blocks carry the idea (without them: 4 steps).
- **N29** — 5 distinct mistakes (the fewest of the set); spinners only.
- **N30** — the lock costs one distinct mistake; the lowest pressure
  signal count (1) and undo-proof share (0.69): the most likely to play
  below EXTREME.

## Search and rejection summary

| Core | Size budget | Rounds | Boards evaluated | Stop | Outcome |
|---|---|---|---|---|---|
| A domino | large | 39 | 1419 | time | → N24 (1 filler piece pruned) |
| D silent gate | large | 30 | 1091 | time | → N25 (1 filler piece pruned) |
| J pull into parity | large | 38 | 1412 | time | → N26 |
| E pull away | medium | 52 | 1902 | time | → N27 (E3: a 16-piece beam board, no stray blocker) |
| G Sequence + pattern | compact | 37 | 1256 | patience | → N28 |
| H alternating chain | medium | 44 | 1551 | patience | → N29 |
| B parity key | compact | 46 | 1573 | patience | rejected: 3 distinct mistakes (< 4) |
| B2 parity key (redesign) | medium | 52 | 1878 | time | → N30 |
| C pattern count + gate | medium | 37 | 1305 | patience | rejected: the pattern is decoration (counterfactual) |
| C2 pattern hub (redesign) | medium | 40 | 1426 | patience | rejected: removing the pattern spinner keeps every decision (trivial removal), TIME UP 36.5 ms; concept dropped |

10 bounded searches, 14 813 boards evaluated in total, 24 + 8 boards
fully reported. Cores first drawn wrong (row lengths in E and J,
unsolvable A, B, D, H) were redrawn before any search. No borderline
timing was re-measured; no Category A threshold was changed.

## The developer selection (`?extreme90p17=1`)

`Extreme90Review` (extends the Phase 16 `Extreme90Bank`): the same 90 s
page, rules `ta90-v1`, GREEN / ORANGE / RED music, calm continuation,
MUSIC ON/OFF, UNDO ×3, unlimited RESTART without a clock reset, no hints,
no HAMMER, optional untimed continuation, and the Phase 16A short
questionnaire with one-tap SKIP.

| CHALLENGE | Board | Group (internal, export only) |
|---|---|---|
| 1–5 | N3, N5, N7, N11, N13 | core |
| 6–10 | N14, N15, N16, N18, N21 | strong |
| 11 | N23 | provisional |
| 12–18 | N24–N30 | phase17 |

- Storage `xb17_*` per board and `chain_escape_xb17_hub`; export format
  `ce-xb17` with `selection: "xb17-v1"`, each board's `group`, its id and
  fingerprint, and `archived: [N17, N19, N20, N22]`. Nothing internal is
  shown on screen.
- **Archive preserved:** N17, N19, N20, N22 keep their definitions, data
  files, fingerprints and records; `?extreme90=1` still lists all 15
  Phase 16 boards and exports `ce-xb90` exactly as before, so earlier
  exports stay readable. `?ta90=1` (N1–N13) is unchanged.
- Player / QA builds never open it (`BuildFlags.dev_pages_off()`).

## QA report (Phase 17)

Builds: the dev Web export (`Web`) and the player export (`Web Friend
Test`, which excludes `data/dev`). The browser tests ran in Chromium at
iPhone SE size (375×667) with real touches; Chromium is not iPhone Safari.

| Suite | Result |
|---|---|
| Extreme90p17Check (new, headless) | PASSED, 97 checks. Selection composition, CORE fingerprints, archive kept, N24–N30 new ids, every board solved on the real page and exported, ORANGE/RED/TIME UP, short questionnaire, untimed continuation (calm), RESTART keeps the clock, GIVE UP + SKIP, `ce-xb17` export with groups, `?extreme90=1` export unchanged, other storage untouched |
| web_extreme90_page_test `--entry=extreme90p17` | PASSED 51/51. 18 tiles on screen, every challenge solved by touch in a timed run, SKIP, TIME UP → untimed with the calm mix, `ce-xb17` bundle (N23 group "provisional"), player build ignores the entry |
| WASM full solve (TIME UP call), per board | N24 4.3, N25 21.1, N26 9.8, N27 26.3, N28 3.5, N29 9.7, N30 7.9 ms (existing boards 0.4–30.4 ms) |
| web_extreme90_page_test (`?extreme90=1`, archive) | PASSED 45/45 |
| Extreme90Check / Ta90Check | PASSED 91 / 91 (Ta90Check's board-count rule now also excludes the Phase 17 ids) |
| web_ta90 / web_tapilot (120 s pilot) | PASSED 55/55 / 28/28 |
| web_stime / web_ttime tta (real time) | PASSED 31/31 / 32/32 |
| web_friend_build (Social / Challenge a Friend player build) | PASSED 25/25 |
| web_timing (campaign timing, Personal Best) | first run 32/33: "active time 9242 ms within [wall clock 9090 ms …]", a 152 ms overshoot of wall-clock time on a loaded container. The one allowed re-run passed 33/33. No campaign timing code changed in this phase. |
| Headless suites (Competition, unit tests, Timing, Profile, ExperienceLab QA, Feedback, FriendChallengeApi, FriendFlow, SocialApi, SocialSmoke, SocialPlay, TaPilot, Extreme11, Q1Time, RTime) | all PASSED |
| verify_levels | ALL 300 LEVELS SOLVABLE AND PASS CAMPAIGN RULES |

**Pre-existing failures (not Phase 17):** RecipientTest fails the same
3 layout checks as in Phase 16 ("TOTAL SCORE left, coins right" for
en_US / he_IL / ar_SA). `vh_pilot4_canon.gd` prints index errors while
the search loads its near-copy list (the non-square N22); they are
non-fatal, and similarity is also checked separately.

**Safety audit:** `levels/` untouched; Production, Supabase, the Social
MVP, Challenge a Friend and campaign timing code untouched. The only
runtime change is a `BuildFlags`-gated developer hook in
`game_manager.gd` plus new `BOARDS90` entries. Nothing pushed, merged,
deployed or uploaded.

## Phase 18 (follow-up)

The Phase 17 playtests archived N25 and N28 from the active selection and
kept N24 as provisional (N26, N27, N29, N30 strong). They stay here, on
`?extreme90p17=1`, unchanged. The active selection lives on
`?extreme90p18=1` — see `docs/extreme90_phase18.md`.
