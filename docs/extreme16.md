# EXTREME phase 11: three blind boards on the 120-second clock (`?tta=1`, `?ttb=1`, `?ttc=1`)

Development only. Nothing is committed, pushed, deployed or uploaded.
The following are not touched: Production, campaign levels 1-300, Supabase, the Social MVP, Challenge a Friend, coins and progression, the campaign timer and Personal Best, existing boards and fingerprints, and published challenge behaviour.

**Three technically qualified boards were produced, one per mechanic family.**
All three are labelled **EXPERIMENTAL - HUMAN DIFFICULTY UNVALIDATED**.
Two of them carry a recorded heuristic exception; that is the expert-learner screen, which is a screening measure, not a technical gate.
None was forced through: every mandatory technical gate passes on all three.

Notation: R = row and C = column, both counted from 1. The tools print `r<row>c<col>` counted from 0.

## 1. The boards

### A - magnet strategy (`?tta=1`, board id `TA`)

```
      C1     C2     C3     C4     C5     C6
R1    .      .      .      .      Bv     .
R2    .      R^@-   B>@    .      Yv@-   .
R3    .      P<@    B^*    Gv     G>@    .        B^* = magnet M (up)
R4    .      .      .      R<@    Bv@    .
R5    .      .      .      .      .      .
R6    P<*    .      R>@    Y<     .      .        P<* = magnet N (left)  R>@ = the carried spinner
```

- **Fingerprint (page):** `a28e22f0a1a216ba4ac701ff549e7d212ce1fe83ae2d8e3678065da555b730cf`
- **Data:** `data/dev/extreme16_a.json`
- **Mechanics:** 2 magnets, 8 clockwise / counter-clockwise spinners, 3 plain arrows (13 pieces). No shell, no switch, no lock.
- **Insight (verified on every winning line: `moved_then_turned`).**
  - Magnet M pulls the red spinner (R6C3) up into its own cell (R3C3).
  - There it waits beside the green arrow, which can leave only after the pull.
  - The green arrow's departure turns the spinner, and only that turn points it at a free lane.
  - So M must fire before N, and only once the board above has been unwound so that the spinner's new neighbours are the right ones.
- **Traps (verified, losing moves with how long play goes on):**
  - Firing magnet N early (R6C1). It drags the spinner sideways instead. The loss shows 2-10 moves later.
  - Turning the top-left spinner the wrong way (R2C2). Loss after 2-8 moves.
  - Clearing the right side in the wrong order (R3C5, R4C5). Loss after 9-11 moves.
- **Decisions:** 6 of the first 9 steps have 1-2 winning moves out of 3-6 legal moves.
- **Not a Q1/R1 copy.**
  - There is no hammer or shell.
  - The carried piece is a spinner whose orientation after the move decides the game.
  - Disclosed: "the other magnet fired too early" is a family trap that the expert has met in Q1 and R1.

### B - spinner / lock strategy (`?ttb=1`, board id `TB`)

```
      C1     C2     C3       C4     C5     C6
R1    .      .      G>       .      .      .
R2    .      .      G^       G^@    .      .
R3    .      .      P<@#G    G>@    .      Pv          P<@#G = the locked spinner K (key: green)
R4    .      .      B<       Y<     .      .
R5    .      .      .        .      .      B<@
R6    .      .      B^       B>     Bv@-   R>@
```

- **Fingerprint (page):** `f8c22182180f45fa964593050c91d3fc534079338a438774f2b54dd00c924d99`
- **Data:** `data/dev/extreme16_b.json`
- **Mechanics:** 1 colour lock, **6 spinners** (the recipe caps B at 6, so the difficulty cannot come from spinner count), 7 plain arrows (13 pieces).
- **Insight (verified on every winning line: `key_turn`).**
  - The purple spinner K is locked until every green is gone.
  - The LAST green must be a neighbour of K, so that its departure frees K and turns it in the same move.
  - That one turn decides which way K faces when it is free.
  - So the player has to choose which green leaves last, and arrange that the others (one of them a spinner, G R3C4) are gone first.
- **Differs from S1.** In S1 the lock chain and the turns K takes while still locked carried the puzzle. Here the key's own departure is the turn, and there is no second lock.
- **Traps (verified):**
  - Sending the green R2C3 up, which frees K at the wrong moment.
  - Sending blue R4C3 left early.
  - Tidying the bottom-right corner in the wrong order.
  - Each is lost 2-11 moves later. The stuck picture is usually purple K facing a wall.

### C - switch / shell strategy (`?ttc=1`, board id `TC`)

```
      C1     C2     C3      C4     C5     C6
R1    Pv%A   .      .       .      .      .           Pv%A = switch S
R2    .      .      .       .      B>@    R^&A        R^&A = F, reversed by S
R3    .      .      B^&A    G<@    Pv@    P>@-        B^&A = hammer H, reversed by S
R4    .      .      .       .      .      .
R5    .      B>@    .       .      .      Y^@-
R6    .      .      R<=     .      R>@    Gv          R<= = the shell
```

- **Fingerprint (page):** `7f7ae09342e86e56a34ab4d52628346e455b97111a8f6c4663c97a9a587988d5`
- **Data:** `data/dev/extreme16_c.json`
- **Mechanics:** 1 switch with 2 reversal targets, 1 armored shell, 7 spinners, 1 plain arrow (12 pieces). No magnet, no lock.
- **Insight (verified on every winning line: `reversed_ram`).**
  - The hammer H points AWAY from the shell, and its own lane up is open, so moving it is the obvious free move, and the losing one.
  - Only the switch turns it to face the shell (R6C3) and ram it.
  - But the switch also reverses F (R2C6), which must already be gone, or it ends up facing the bottom-right spinners.
  - Then the shell and the spinner cluster on the right must be cleared in a set order.
- **Traps (verified):**
  - H up at once: the shell is never cracked, and play goes on for 10 moves.
  - The switch before F: loss after 8-10 moves.
  - The right-hand spinners in the wrong order: loss after 3-11 moves.
- **Simplified in this phase.** The candidate C1 had a green block at R1C3. Removing it passes every gate and RAISES the expert-learner score from 9 / 7 to 18 / 19, so it was decoration and was removed (Section 3).
- **Disclosed overlap with R1.** F, which must leave before the switch, is R1's opening trap in the same corner. The central idea differs: here the reversed block is the hammer itself, and there is no magnet.

## 2. Mechanic diversity

| | A | B | C |
|---|---|---|---|
| Families | magnets + spinners | colour lock + spinners | switch + shell + spinners |
| Central object | a spinner carried by a magnet | a locked spinner and its last key | the reversed hammer |
| What the player must plan | which magnet fires first, and the carried spinner's new neighbours | which green leaves last | when to press the switch, and what must be gone before |
| Shares a mechanic with Q1 / R1 / S1 | magnets (Q1, R1) | lock + spinner (S1) | switch + shell (R1) |
| Shares a trap pattern | "a magnet fired too early" (Q1, R1) | - | "a reversal target not gone before the switch" (R1) |

## 3. Technical and strategic acceptance

Every row is from the full acceptance (`tools/extreme16_build.gd --accept`). C was measured with no other job running. A was measured with two other jobs running, and B with three, so their timings are upper bounds.

| Gate | A | B | C | Required |
|---|---|---|---|---|
| Solvable (verify) | 7.3 ms | 10.2 ms | 1.6 ms | yes |
| Solver / exhaustive parity, every reachable position | 0 / 394 | 0 / 412 | 0 / 436 | 0 mismatches |
| Repeated timing runs, desktop | 11.9-14.8 ms | 22.7-32.6 ms | 16.2-27.2 ms | <= 40 ms |
| SHOW A MOVE after a mistake (lab) | 13.0 ms | 14.6 ms | 23.7 ms | <= 40 ms |
| Idea on every winning line | `moved_then_turned` | `key_turn` | `reversed_ram` | yes |
| Greedy players (best) | 1.7% | 0.8% | 0.5% | <= 5% |
| 6-move-lookahead greedy | 0% | 5.0% (at the limit) | 1.7% | <= 5% |
| Hard decisions K6 / K8 | 4 / 3 | 5 / 3 | 5 / 3 | K6 >= 4 |
| Hidden losing moves K6 / K8 | 11 / 7 | 17 / 9 | 13 / 9 | |
| Deepest trap | 11 | 11 | 11 | |
| Late plausible losing moves | 4 | 5 | 4 | >= 2 |
| Positions (winnable) | 394 (100) | 412 (45) | 436 (22) | <= 700 |
| Opening (winning / legal) | 2 / 6 | 2 / 6 | 1 / 5 | |
| **Expert learner, look 4 / 6** | **11 / 10** | **7 / 7** | **18 / 19** | screen >= 12 |
| Heuristic exception | the learner screen (10 < 12) | the learner screen (7 < 12) | none | recorded |
| Near copy of any played board | none | none | none | none |

**Piece removal** (`tools/extreme16_prune.gd`, every piece in turn; quick gates first, then full acceptance). Every remaining piece is needed in all three boards:

- **A, 13 / 13 needed.**
  - Magnet M: unsolvable without it.
  - The carried spinner, the green arrow, the yellow arrow: the idea is no longer on every line.
  - The other nine pieces: a greedy player wins 6-8%, or there are only 3 hard decisions.
- **B, 13 / 13 needed.**
  - K, its key, three others: `key_turn` is no longer on every line.
  - The rest: a greedy player wins 7-19%.
- **C, 12 / 12 needed.**
  - The switch: the links lose their piece.
  - H: unsolvable.
  - The shell: the idea is lost.
  - The rest: a greedy player wins 6-29%.
  - The earlier 13th piece (green R1C3) was decoration and was removed.

The learner score was not optimised further, as instructed. C1's simplification is the one case where removing a piece improved the board; all the mandatory gates were re-run on the simpler board.

## 4. The three blind tests (`scripts/social/expert_time_attack.gd`)

**Timer and assistance**
- Exactly the phase 10 timer and UX: `ExpertTimeAttack` extends `CountdownTimeAttack` and changes only the board, the storage and the questions.
- 120 s; green 2:00-1:01, orange 1:00-0:31, red 0:30-0:00.
- The fixed pill; the reduced-motion rule.
- UNDO x3 per attempt, ONE SHOW A MOVE per timed run, HAMMER x0.
- The clock never stops and never refills on RESTART, a reload or the background.

**Isolation**
- `?tta=1`, `?ttb=1` and `?ttc=1` each load ONLY their own board file.
- Another test's board is never loaded, shown or referenced on the page.
- Each test has its own state file and localStorage key (`chain_escape_tta_state` / `_ttb_` / `_ttc_`), and its own fingerprint.
- The titles say "PUZZLE TEST A / B / C".

**Outcomes**
- TIME UP freezes the timed record.
- CONTINUE WITHOUT TIMER keeps the position when it can still be cleared, otherwise starts a fresh board and says so.
- The untimed record is separate; a timed failure and an untimed solve stay two outcomes.

**Questions, timed portion** (asked before any untimed play):
1. first-exposure difficulty (EASY - EXTREME);
2. enjoyment (1-5);
3. excitement (1-5);
4. frustration (1-5);
5. timer improved play (YES / NO / NOT SURE);
6. 120 s (TOO SHORT / APPROPRIATE / TOO LONG);
7. noticed the colours (YES / NO / NOT SURE);
8. play another puzzle (YES / NO / NOT SURE).

**Questions, afterwards** (after the untimed play, a FINISH after TIME UP, a timed win or a give-up; what they follow is recorded as `_after`):
- did you solve it (YES / NO);
- satisfaction / achievement (1-5);
- enjoyment of the puzzle (1-5);
- an important insight (YES / NO / NOT SURE);
- did the combination add interest (YES / A LITTLE / NO);
- optional text.

The first-exposure rating is stored only with the timed record; the post-play answers are stored apart.

**Testers**
- Each tester should use their own device or browser profile.
- Within one profile, a later run of the same test is a new record in the results list, not an overwrite.

## 5. QA results (after the last code change)

### Headless

`TTimeCheck` passes **67 / 67** for A and for B, and **68 / 68** for C (C's board has a shell, which adds the armored-tap check).

**Each test loads only its own board.** It has its own state, localStorage key and fingerprint, and the other two tests' storage and every earlier page's storage stay untouched.

**The clock and assistance**
- starts at 2:00, with UNDO x3, SHOW A MOVE x1 and HAMMER x0;
- the stage thresholds are exact, with and without reduced motion: 1:01 green, 1:00 orange, 0:31 orange, 0:30 red, then the last 10 s;
- the pill never shifts and never covers the board;
- RESTART, UNDO and SHOW A MOVE give no time back;
- a reload restores neither the clock nor SHOW A MOVE;
- going to the background is recorded;
- the 0:00 boundary holds: a solve 400 ms before it counts, at 0:00 it does not.

**Records and questions**
- blocked taps are logged with the block;
- TIME UP is frozen with the stages reached;
- the 8 timed questions come before any untimed play, with the first-exposure rating stored with the timed record;
- CONTINUE WITHOUT TIMER works from the 0:00 position, and also fresh after a lost position;
- after an untimed solve the timed record is byte-identical;
- the post-play answers are stored apart, with `_after`;
- a reload works in every phase;
- a WIN and a GIVE UP both skip the offer.

### Full 120 s browser tests

`web_ttime_page_test.mjs` runs in Chromium at iPhone SE size (375x667) with real touches, one test per run. Each run passes **30 / 30** for `tta`, `ttb` and `ttc`.

| | A | B | C |
|---|---|---|---|
| TIME UP after 2:00 (wall time, a reload included) | 120.0 s | 119.9 s | 119.9 s |
| WebAssembly x1 (verify / SHOW A MOVE / after a mistake) | 6.9 / 6.7 / 14.7 ms | 15.9 / 18.1 / 2.3 ms | 4.0 / 1.7 / 24.3 ms |
| x4 / x6 after a mistake (desktop simulation, reported) | 134 / 78 ms | 12 / 16 ms | 103 / 157 ms |

Each run also covers:
- **Timer on screen:** the stages read from screen pixels (green, orange, red pulse, last 10 s); no layout shift; the clock not restored after a reload.
- **Flow:** the timed questions; CONTINUE WITHOUT TIMER from the 0:00 position; a reload in the untimed game; solved by touches; the post-play answers; separate records.
- **Isolation:** the other tests' storage untouched; only this test's board id on the page.
- **Other runs:** a timed WIN in a fresh profile; reduced motion (no pulse, no scale, recorded).
- **Cleanliness:** no page errors; no network calls.

### iPhone SE screenshots

`docs/extreme16_shots/`: for each test, the green, orange, red and last-10-s timer stages, the first-exposure difficulty question and the offer, plus one reduced-motion red frame.

Inspected for:
- timer prominence (the fixed pill above the board);
- board readability (lock badge, switch badge, shell);
- touch-target separation (the 6x6 grid);
- stage contrast (white on fill, at least 5.2 : 1);
- no clipping and no layout shift.

## 6. Files (none committed)

| File | Change |
|---|---|
| `scripts/social/expert_time_attack.gd` | new: the three tests (presets, questions, `_after`) |
| `data/dev/extreme16_a.json`, `_b.json`, `_c.json` | new: the three boards (one per file, so a page loads only its own) |
| `scripts/game_manager.gd` | +6 lines: the `?tta` / `?ttb` / `?ttc` hook (above `?stime`) |
| `tools/extreme16_build.gd`, `extreme16_events.gd`, `extreme16_lab.gd`, `extreme16_screen.gd`, `extreme16_prune.gd` | new: the builder (three recipes, the facts, parity, acceptance with the labelled learner exception), the workbench, the one-edit screen (`--max_pos`), the removal screen (quick path) |
| `tools/ttime_check.gd`, `tools/TTimeCheck.tscn` | new: headless checks, one test per run (`-- --key=tta`) |
| `tools/web_ttime_page_test.mjs` | new: browser test (full 120 s, one test per run) |
| `docs/extreme16.md`, `docs/extreme16_shots/` | this report and the iPhone SE screenshots |

The earlier work (Q1, R1, S1, `?ptest11`, `?q1time`, `?rtime`, `?stime`) is unchanged. It is verified against a checksum list taken at the start of this phase; only `game_manager.gd` differs, by the hook.


## 7. Regression (after the last code change)

| Test | Result |
|---|---|
| `STimeCheck` (S1, `?stime`) / `web_stime_page_test.mjs` full 120 s | 66 / 66 / 29 / 29 |
| `RTimeCheck` (R1, `?rtime`) / `web_rtime_page_test.mjs` full 180 s | 39 / 39 / see below |
| `Q1TimeCheck` / `web_q1time_page_test.mjs` | 37 / 37 / 21 / 21 |
| `Extreme11Check` / `web_ptest11_page_test.mjs` | 74 / 74 / 22 / 22 |
| `VhHumanTestCheck` | 100 / 100 |
| `TimingCheck`, `web_timing_test.mjs` (player + development builds: campaign timer, Personal Best) | passed |
| `FriendTimerToolsTest`, `FriendFlowTest` (149 / 149), `SocialPlayTest`, `SocialSmoke`, `SocialApiTest`, `RevealMvpTest`, `MagnetCheck` | passed |
| player build contents | no `extreme16` data and no `tta` / `ttb` / `ttc` storage key in the package |

**R1 browser test (full 180 s).** It passed 19 / 20, with TIME UP at 180.0 s. The one failure was its WebAssembly bench: SHOW A MOVE after a mistake took 48.1 ms, against 40. A forgotten background job (an earlier removal screen) was still running at the time. Re-run alone, the test passed **20 / 20**, with the bench at 30.2 ms. R1's board and the Solver are unchanged in this phase.

**Unresolved, pre-existing (not caused by this phase):**
- **`RecipientTest`, 3 layout checks** ("TOTAL SCORE left, coins right", en / he / ar). They fail identically on a clean checkout of the last commit (shown in phase 10). The Social MVP is not touched.
- **`Extreme8Check`, the SHOW A MOVE timing check for the old E1 / E2 boards.** It failed again here (45.7-48.5 ms against 40) during the same load. In phase 10 it failed the same way on a clean checkout of the last commit, and passed on idle re-runs of this tree. It is container timing noise around 40 ms.

## 8. Test URLs (the development QA build)

| Test | URL parameter | Board | Storage key |
|---|---|---|---|
| A (magnet) | `index.html?tta=1` | TA, `a28e22f0...` | `chain_escape_tta_state` (+ `user://tta_state.json`) |
| B (spinner / lock) | `index.html?ttb=1` | TB, `f8c22182...` | `chain_escape_ttb_state` |
| C (switch / shell) | `index.html?ttc=1` | TC, `7f7ae093...` | `chain_escape_ttc_state` |

- Each tester should use their own device or browser profile.
- Give the tests in any order. A page never shows the other two boards.
- At the end, the results screen has COPY RESULTS for the JSON (timed record, untimed record and both question sets, per run).

## 9. Known limitations and risks

- **Human difficulty is unvalidated for all three.**
  - A and B pass every gate except the expert-learner screen (10 and 7 against 12). That is recorded as a heuristic exception.
  - C passes every gate with no exception.
  - None of these scores predicts the expert. R1 scored 9 and he rated it VERY HARD; S1 scored 23.
- **Shared trap patterns:**
  - A's "magnet fired too early" is the habit the expert built on Q1 and R1.
  - C's "F before the switch" is R1's opening trap. Both are disclosed (Section 2).
  - B shares the lock + spinner mechanics with S1, but not its central idea.
- **Density:** A has 8 spinners and C has 7, out of 12-13 pieces. Every piece is needed, but the boards are busy.
- **B is at the limit on one gate:** its 6-move greedy player wins exactly 5%.
- **C's opening is forced:** 1 of 5 legal first moves wins. That could make the first move easy to find by elimination.
- **Mobile simulation:** A and C reach 100-157 ms for SHOW A MOVE after a mistake at x4 / x6 desktop throttling. That is comparable to Q1 / R1 (140-240 ms), but a real iPhone is still the measurement that counts.
- **Exploratory evidence only:** two testers and three uncontrolled boards. Do not compare the boards' difficulty as if it were controlled.
- **Client-only data:** one device or profile per tester. Clearing site data starts over.
- **Not yet tested on a real iPhone** (Safari, reduced motion, backgrounding).
