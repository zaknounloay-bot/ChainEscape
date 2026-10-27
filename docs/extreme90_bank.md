# EXTREME Time Attack: the dedicated bank (Phase 16, development only)

**Entry:** `index.html?extreme90=1`. This is a development page; the player and QA builds ignore it.

The bank holds **EXTREME puzzles only**, shown to players as neutral **CHALLENGE 1-15**:
- **Baseline (5):** N3, N5, N7, N11 and N13. They were chosen from the family playtests for enjoyment, excitement, time pressure and perceived fairness. N3 is the experiential reference; N7 and N13 are the references for larger, demanding boards.
- **New (10):** N14-N23, each a **HUMAN-REVIEW CANDIDATE.** All passed technical category A and EXTREME category B. Nobody has played them yet.

**The experimental collection is kept.** `?ta90=1` still lists N1-N13 exactly as in Phase 15; it is the developer entry for the whole collection. The eight boards outside the bank (N1, N2, N4, N6, N8, N9, N10, N12) are archived there with their data files, records and fingerprints. Nothing was deleted or overwritten.

## 1. How the bank is built

- **`Extreme90Bank`** (`scripts/social/extreme90_bank.gd`) extends the 90-second hub `Ta90Prototype`. It overrides only:
  - the board order (`BANK`) and the neutral label word (CHALLENGE);
  - the texts and the export format (`ce-xb90`);
  - the storage: hub `xb90_hub`, and `xb90_<board>` per board;
  - no TA reference row.
- **The page is the same `Ta90TimeAttack`, with the rules unchanged (`ta90-v1`):**
  - 90 s with GREEN / ORANGE / RED music and the calm mix after TIME UP;
  - MUSIC ON / OFF;
  - UNDO ×3 per attempt; unlimited RESTART that never resets the clock;
  - SHOW A MOVE ×0 and HAMMER ×0;
  - the optional untimed continuation.
- **Questions:** the same research questions and export. No questions were added, and none are mandatory in any normal player mode.
- **The refactor that made this possible:**
  - `Ta90Prototype` reads its order, storage, texts, export format and publish name through accessor methods. For `?ta90=1` they return the exact Phase 15 constants; Ta90Check passes unchanged.
  - `Ta90TimeAttack` takes a storage prefix (default `ta90`) and a label word (default `PUZZLE`).
  - The 120 s `PilotTimeAttack` and `TaPilot` are untouched.
- **Traceability:** the same board keeps separate records in each entry. Every record and export entry carries the internal id (N3, N14, …), the fingerprint and the challenge number.

## 2. The new boards

Design ideas, each distinct from the five bank boards. The bank's own tricks:
- N3: a reversal opens the gate;
- N5: a Sequence advance turns a spinner;
- N7: a Sequence step aims a spinner at a shell;
- N11: a waiting lock keeps turning;
- N13: a magnet pulls a spinner next to its key.

| CHALLENGE | Key | Core | Size | Pieces | Mechanics | Strategic concept | Fingerprint |
|---|---|---|---|---|---|---|---|
| 6 | N14 | 16B | 6×6 | 14 | pattern spinner, armor, spinners | **The pattern's rhythm:** a pattern spinner (cw, cw, ccw) must ram two shells in turn | `c26a76e8fcd75672540d08e26a053559cc1a13ef9bfd12a87500f710e41b8698` |
| 7 | N15 | 16G | 7×7 | **20** | lock, armor, spinners | **The key aims the lock:** the departing key turns the locked spinner onto the shell | `4868df06805eaa4d89925a7f42a1e2cd85d5248e8d1b3dcd609feccfcc52e087` |
| 8 | N16 | 16D | 7×7 | 17 | switch, armor, gate, spinners | **Reverse to ram, ram to open:** the shell the reversed rammer cracks is the gate's link | `b46e1063d26a1090121bdcc0320412019553918d001dbdf940d9b2882152531b` |
| 9 | N17 | 16I2 | 6×6 | 14 | armor, spinners | **Two shells, two rammers:** spend each rammer on the right shell, and keep both until their shell is cracked | `f03a0bec59608c30fdedd8b80854226242d679323f63724ff7d4306ccf506076` |
| 10 | N18 | 16F2 | 7×7 | **20** | magnet, armor, spinners | **Bring the shell:** a magnet pulls the shell into the only rammer's lane; the rammer must not leave first | `4f81a66e1485b564f0e6478d1017ae9d532929cdf7d9f73566e6dd993a5b00ac` |
| 11 | N19 | 16E | 7×7 | 18 | two chain gates, spinners | **Gate chain:** one gate's link waits behind the other gate | `ddb67ffbb74a9040069043a04b48addb3da640118b8e6483efd3e75ecf5cab4f` |
| 12 | N20 | 16A2 | 6×6 | 14 | two switches, spinners | **Between two switches:** two switches flip the same target, which must leave between the two firings | `ebff998e4fcb4be47bc015ac7c7dff6a1eb64e944e3f6f88753dd537ff5a47b0` |
| 13 | N21 | 16H2 | 7×7 | **20** | Sequence, lock, spinners | **A key that leaves in two steps:** the Sequence key's advance turns the locked spinner without unlocking it; its escape unlocks and turns it again | `598cee830d3bcce7533cfe9b99847b376705e6e5c52181083c771e3fd8231c68` |
| 14 | N22 | 16C2 | 6×7 | 18 | magnet, gate, lock, spinners | **Unlock, open, pull:** the gate's link is locked; the magnet must wait for both | `1f4c569074172b7802c5525057cc87e0fd20bff67fc38e909a1270b5c448ffef` |
| 15 | N23 | 16J2 | 7×7 | 18 | switch, lock, spinners | **One departure, two effects:** the switch is also the last key of a lock; its timing serves both | `feeefb09e8bae3941b0964f6652b2d134a092471c4bce41b74d6fa1c500e7141` |

The boards come in three sizes:
- **Compact** (6×6, 14 pieces): N14, N17, N20.
- **Medium interconnected** (17-18 pieces, including the bank's only 6×7): N16, N19, N22, N23.
- **Large multi-mechanic** (7×7, 20 pieces): N15, N18, N21.

No two boards of the bank (baseline + new) share more than 14% of their cells. The highest pair is N20 / N23: both cores used the same switch deadlock pair at the same coordinates, but their ideas differ.

## 3. Results (`data/dev/extreme90_bank/final_report.json`, one consolidated pass)

**Category A, technical: all ten pass the unchanged gates.**
- Every board parses intact, verifies, solves, and replays deterministically twice through BoardModel.
- Parity is 0 / 0 in every reachable position.
- The solve takes at most 40 ms, and so does the TIME UP check from EVERY reachable position.
- No Solver node limit was ever reached.

| Key | Positions | Solution | Solve (desktop) | TIME UP worst (desktop) |
|---|---|---|---|---|
| N14 | 1146 | 16 | 26.4 ms | 18.9 ms |
| N15 | 486 | 21 | **32.1 ms** | **28.5 ms** |
| N16 | 386 | 17 | 17.9 ms | 17.1 ms |
| N17 | 228 | 16 | 8.6 ms | 8.3 ms |
| N18 | 647 | 21 | 19.8 ms | **31.1 ms** |
| N19 | 290 | 16 | 19.5 ms | 12.9 ms |
| N20 | 527 | 14 | 8.2 ms | 9.4 ms |
| N21 | 967 | 21 | 7.3 ms | 9.8 ms |
| N22 | 383 | 17 | 24.7 ms | 12.0 ms |
| N23 | 719 | 18 | 4.8 ms | 3.2 ms |

**Category B, strategic: all ten meet the EXTREME benchmark calibrated on N3.**

| Key | Idea on every winning line | Distinct mistakes | Decision steps (coverage / last losing step) | Endgame | Greedy (cap 20%) |
|---|---|---|---|---|---|
| N14 | `shell_rammed` | 6 | 14 (0.88 / 0.88) | yes | 13% |
| N15 | `shell_rammed` | 6 | 18 (0.86 / 0.86) | yes | 0% |
| N16 | `reversed_ram` + `gate_through` | 6 | 13 (0.76 / 0.76) | yes | 17% |
| N17 | `shell_rammed` | 6 | 14 (0.88 / 0.88) | yes | 0% |
| N18 | `shell_rammed` | 6 | 19 (0.90 / 0.90) | yes | 5.5% |
| N19 | `gate_through` | 6 | 14 (0.88 / 0.88) | yes | 1% |
| N20 | `reversed_escape` | 6 | 12 (0.86 / 0.86) | yes | 11% |
| N21 | `key_turn` | 5 | 19 (0.90 / 0.90) | yes | 1% |
| N22 | `gate_pull` | 6 | 14 (0.82 / 0.82) | yes | 2.5% |
| N23 | `reversed_escape` | 6 | 15 (0.83 / 0.83) | yes | 1% |

**Each mechanic neutralised.** "13, 4" means 13 decision steps and 4 distinct mistakes.

| Key | Neutralised mechanic → decisions without it (with it) |
|---|---|
| N14 | armor 12, 3 (14, 6); pattern 14, 7 (14, 6) |
| N15 | armor 13, 4; lock 10, 4 (18, 6) |
| N16 | switch: unsolvable; armor 11, 2; gate 14, 6 (13, 6) |
| N17 | armor 12, 5 (14, 6) |
| N18 | magnet: unsolvable; armor 18, 5 (19, 6) |
| N19 | gate 8, 3 (14, 6) |
| N20 | switch: unsolvable |
| N21 | lock 10, 3; Sequence 10, 3 (19, 5) |
| N22 | magnet: unsolvable; gate 11, 5; lock 12, 5 (14, 6) |
| N23 | switch: unsolvable; lock 10, 5 (15, 6) |

**Category C, estimates: diagnostic only.**

| Key | Learners (look 4 / 6) | 6-move lookahead greedy | Deepest trap | Opening (good / legal) |
|---|---|---|---|---|
| N14 | 5 / 6 | 7.5% | 14 | 5 / 7 |
| N15 | 4 / 4 | 0% | 19 | 3 / 6 |
| N16 | **0 / 0** | 6.7% | 14 | 3 / 7 |
| N17 | 2 / 2 | 3.3% | 13 | 3 / 5 |
| N18 | 6 / 6 | 0% | 12 | 2 / 3 |
| N19 | 8 / 7 | 1.7% | 14 | 2 / 7 |
| N20 | 2 / 2 | 4.2% | 12 | 3 / 8 |
| N21 | **1 / 0** | 5% | 17 | 3 / 6 |
| N22 | 3 / 0 | 4.2% | 14 | 4 / 6 |
| N23 | 3 / 3 | 2.5% | 16 | 3 / 5 |

## 4. Known weaknesses

- **N14:** the pattern spinner changes the decisions only slightly (14, 7 without it against 14, 6). Its rhythm is the idea, but most of the difficulty comes from the armor and the other spinners.
- **N15:** the **slowest board.** Its solve takes 32.1 ms and its TIME UP check 28.5 ms on desktop: inside the gate, but with the least margin. Watch it on a real iPhone.
- **N16:** the gate barely matters (14, 6 without it against 13, 6), and its learners find 0 dead ends. It may play easier than EXTREME.
- **N17:** the armor's effect on the decision count is small (12, 5 against 14, 6), although the shells are the idea.
- **N18:** a 31.1 ms TIME UP check in its worst position, the second-least margin. The armor's effect is small (18, 5 against 19, 6).
- **N20 / N23:** they share the same deadlock-pair geometry (the highest cell overlap of the bank, 14%).
- **N21:** learners 1 / 0. It may play easier than its decision count suggests.
- **All boards:**
  - design checks and estimates only, until people play them;
  - shell ideas appear in four boards (N14, N15, N17, N18), each with a different mechanism (pattern rhythm, key aiming, allocation, pull);
  - all ten target EXTREME, and whether each one feels EXTREME is for the playtests to say.

## 5. Rejected candidates and search effort

- **Effort:** 19,228 boards evaluated in 14 bounded searches (6-12 minutes each, at most 4 at a time), plus full A / B / C reports on 16 candidates and one consolidated pass.
- **New this phase:** the search takes a Solver-cost cap (`max_solve_nodes`, the nodes of the opening solve). Large boards are grown inside the 40 ms TIME UP gate instead of being found and then rejected.

| Candidate | Why it was not used |
|---|---|
| core I (flip and spin) | engine rule: a spinner cannot be a switch / flip target (rejected at the core) |
| core J (lock ladder) | unsolvable as drawn: no order frees the lock chain |
| H first version (Sequence switch) | engine rule: a Sequence block must be a plain arrow (cannot be a switch). Redrawn as "a key that leaves in two steps" → N21 |
| I2 first drawing | unsolvable as drawn (rammer facing the wrong way, then a rammed shell pointing back at its rammer). Fixed at the core → N17 |
| A first growth | greedy 23% > 20%. A follow-up with a stronger shortcut penalty → N20 (11%) |
| F first growth (20 pieces) | **category A:** solve 43.3 ms > 40. Regrown under the node cap → N18 |
| H first growth (21 pieces) | **category A:** solve 74.7 ms, TIME UP 55.2 ms > 40. Regrown under the node cap → N21 |
| C first growth (18 pieces) | **category A** in the consolidated pass: solve 41.0 ms > 40 (27.7 ms in an earlier, loaded run). Not re-measured to pass; regrown under the node cap → N22 (TIME UP 12 ms) |

The timing gates were never relaxed, and no failing board was re-measured until it passed.

## 6. Files

- `scripts/social/extreme90_bank.gd`: the entry (`?extreme90=1`).
- `data/dev/ta90_n14.json` … `ta90_n23.json`: the boards.
- `data/dev/extreme90_bank/`: cores (including the rejected ones, with reasons), seeds, every search log and result, every report, `final_boards.json` and `final_report.json`.
- `tools/extreme90_check.gd`: the headless check. `tools/web_extreme90_page_test.mjs`: the browser test.

## 7. QA and regression (final build)

- **The bank:**
  - `tools/extreme90_check.gd` **73 / 73**: the five baseline boards with their exact Phase 14 / 15 fingerprints; the ?ta90=1 collection N1-N13 complete (the 8 archived boards kept); CHALLENGE 1-15 tiles on screen; **every one of the 15 boards** solved through the real page in a timed 90 s run (ta90-v1, UNDO ×3, no SHOW A MOVE / HAMMER, GREEN music) and exported under its internal id, fingerprint and challenge number (`ce-xb90`, stored as `xb90_<id>`); TIME UP, the questions, CONTINUE WITHOUT TIMER with the calm mix, and an untimed solve that leaves the timed result at TIME UP; ?ta90=1's and the 120 s pilot's storage untouched; no campaign progress written.
  - `tools/web_extreme90_page_test.mjs` **43 / 43** (Chromium at iPhone SE size, real touches): the 15-tile grid on screen, every challenge solved by touch in a timed run, TIME UP through a reload, the calm continuation, the `ce-xb90` export, `?ta90=1` storage never written, and the player build ignoring `?extreme90=1`.
- **WebAssembly full solve** (the TIME UP check, headless Chromium):

  | Board | ms | Board | ms | Board | ms |
  |---|---|---|---|---|---|
  | N3 | 0.7 | N14 | 14.6 | N19 | 12.5 |
  | N5 | 2.5 | N15 | **28.9** | N20 | 6.8 |
  | N7 | 8.0 | N16 | 20.4 | N21 | 7.7 |
  | N11 | 10.0 | N17 | 9.5 | N22 | 24.6 |
  | N13 | 5.6 | N18 | 16.4 | N23 | 4.2 |

- **A real bug found and fixed in the browser:** "CHALLENGE 12" was wider than a tile, so the grid grew past the iPhone SE screen. Long-word tiles now use an 18 px font and clip their text. The headless check missed it because its font metrics differ from the browser's.
- **The experimental collection (?ta90=1):** Ta90Check **91 / 91**; browser test **55 / 55**, re-run because the hub changed.
- **Regression:**
  - all 300 levels solvable and passing the campaign rules;
  - unit tests, Timing, Competition, Profile, Feedback, the Experience Lab, the Friend Challenge API, the friend flow, the Social API, the Social smoke test and SocialPlay;
  - the 120 s pilot (33 / 33 headless, 28 / 28 browser), Extreme11, Q1 and R1;
  - campaign timing and Personal Best (browser); the player build 25 / 25;
  - S1 31 / 31 and TA 32 / 32 in real time.
- **Pre-existing, not Phase 16:** RecipientTest, the same 3 layout checks as before (en / he / ar).
- **Changed outside the dev pages:** only the 4-line `?extreme90=1` hook in `game_manager.gd`, behind `BuildFlags.dev_pages_off()`, like `?ta90=1`.
- Screenshots: `docs/extreme90_bank_shots/`.

## 8. Phase 16A: the short playtest questionnaire (`?extreme90=1` only)

Questionnaire fatigue was reduced. After each tested challenge, **whatever the outcome** (a timed win, TIME UP or GIVE UP), the bank asks only:

| # | Question | Answers | Control |
|---|---|---|---|
| Q1 | How difficult was this puzzle? | EASY / MEDIUM / HARD / VERY HARD / EXTREME | one compact button per line |
| Q2 | How much did you enjoy it? | 1-5 | one row |
| Q3 | Would you play another challenge? | YES / NO | one row |

- **Nothing else is asked.** No music, timer, excitement, frustration, length, achievement or "was it solved" questions, and **no second (post-play) questionnaire**, not even after TIME UP and the untimed game. The run is stored as soon as the third answer, a FINISH or the untimed result's CONTINUE is tapped.
- **SKIP** (always shown) leaves the whole questionnaire in one tap. It is recorded as `answers_skipped`, never inferred. It never blocks replay, the next challenge, the untimed offer after TIME UP, or navigation.
- **Kept apart in the records:**
  - the answers in each run's `timed.answers` (exported as `timed_answers`), with `answers_set: "xb90-short-v1"`;
  - the automatic telemetry: the board id, fingerprint, `timed_outcome`, time, attempts, restarts, moves, UNDO and blocked taps. Success is only ever the `timed_outcome`.
  - The export also carries the questionnaire version and each board's mechanics.
- **Scope:** the page change is opt-in (`Ta90TimeAttack.short_q`, set by `Extreme90Bank.short_questions()`). `?ta90=1` still asks its own questions, and every earlier record stays readable and unchanged. The rules, puzzles, fingerprints, timer and music are unchanged.
- **Older bank records** (Phase 16) keep their 8-answer `timed.answers` and post-play `puzzle_answers`. The two sets are told apart by `answers_set`.

## Phase 17 (follow-up)

The family playtests archived N17, N19, N20 and N22 from the active
selection (they stay here, on `?extreme90=1`, with their data,
fingerprints and records). The active selection — CORE, N14, N15, N16,
N18, N21, N23 (provisional) and the Phase 17 candidates N24–N30 — lives on
its own developer entry, `?extreme90p17=1` (storage `xb17`, export
`ce-xb17`). See `docs/extreme90_phase17.md`. This page, its storage and
its `ce-xb90` export are unchanged.
