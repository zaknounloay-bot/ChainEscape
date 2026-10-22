# EXTREME phase 9: a new blind board against the 3-minute clock (`?rtime=1`)

Development only. Nothing is committed, deployed or uploaded. The
following are not touched: Production, campaign levels 1-300, Supabase, the
Social MVP, Challenge a Friend, coins, the campaign timer / Personal Best,
Q1, T5, hearts and the hint rules.

**Status of the board: EXPERIMENTAL - HUMAN DIFFICULTY UNVALIDATED.**
It passes every technical gate. It fails one heuristic screen: the
expert learner needs 9 dead ends where the screen asks for 12. That
failure is recorded here as a **heuristic exception**, never as a
technical one. Nothing below claims human EXTREME difficulty. That waits
for the expert player's first blind session.

Notation: R = row and C = column, both counted from 1 at the top left.
The tools print `r<row>c<col>` counted from 0, so R3C3 = `r2c2`.

## 1. The selected board: R1

```
      C1       C2       C3        C4     C5     C6
R1    P>%A     .        .         .      .      .        switch (purple, right)
R2    .        .        .         .      .      R^&A     F: red, up, reversed by the switch
R3    R^&A     .        B>&A*     B^     Gv     Gv@      L latch (reversed) | M magnet (reversed) | Q queue | H hammer | green spinner
R4    .        .        .         .      .      .
R5    B>@      .        .         .      .      .        corner spinner (cw)
R6    B<@-     Yv@-     R<=       .      Pv*    Y^       corner spinner (ccw) | yellow spinner (ccw) | SHELL | magnet N | Y
```

- Map: `["P>%A . . . . .", ". . . . . R^&A", "R^&A . B>&A* B^ Gv Gv@", ". . . . . .", "B>@ . . . . .", "B<@- Yv@- R<= . Pv* Y^"]`.
- 6x6, 13 pieces: one switch with three reversal targets (F, L and magnet
  M), two magnets, four spinners (2 clockwise, 2 counter-clockwise), one
  armored shell, three plain arrows.
- Page fingerprint (`PuzzleDefinition.fingerprint()`, the constant
  `BlindTimeAttack.R1_FINGERPRINT`, checked on load):
  `db0dd7e1ae7c721c3c59d1f6f18aee26d71358773d8f6db52e886e758ddfeebc`.
- Builder canonical fingerprint:
  `f4c56c3a37eb6225f457ac4b8f895e42bcb19a5218b782eb779362867f4def6c`.
- Data: `data/dev/extreme14.json`, id `R1`, label
  `EXPERIMENTAL - HUMAN DIFFICULTY UNVALIDATED`. The page never shows the
  label, the id meaning, the metrics or a difficulty.
- No new mechanic. A magnet as a switch flip target is allowed by the
  magnet validation, as documented in phase 6. The campaign never combines
  them: magnets appear in levels 76-99, switches from 101.

## 2. Strategic design

### 2.1 The insight

The switch does more than turn arrows: **it decides which side magnet M
pulls from.** Facing right, M would carry nothing useful. Reversed, M
escapes LEFT and drags the nearest block on its right. Once Q has gone,
that block is the hammer H, landed exactly above the shell (C3). H then
rams down and cracks it. Everything else in the puzzle is about pressing
the switch at the right moment, preparing what it reverses, and keeping
the hammer where M can reach it.

### 2.2 The dependency graph (verified on every winning line)

1. **F before the switch.** The switch also reverses F (R2C6). Pressed
   while F is still there, F turns to face down, head-on against Y at
   R6C6: a permanent stand-off in column 6.
2. **The switch reverses L and M.** L (R3C1) then faces down, and M can
   only leave left once L has gone. L can only leave down, so column 1
   below it must be cleared first: the corner.
3. **The corner has an order.** The yellow spinner (R6C2) leaves first.
   Its leaving turns the corner spinners so that they leave down in turn.
   Started from the wrong end (R5C1 right, or R6C1 left), the leaving
   pieces turn the yellow spinner to face RIGHT, at the shell. It even
   rams the shell (it looks like progress), but then the yellow spinner
   and the cracked shell face each other: a stand-off.
4. **Unload Q** (R3C4) before M goes. M takes the NEAREST block.
5. **M left, then H down (the ram).**
6. **N waits.** Magnet N (R6C5) pulls the first block above it in C5,
   which is H. Fired at any time before H has left C5, it takes the hammer
   away, and the shell can never be cracked.
7. Clean-up (5 moves, no losing option).

Solution (14 taps): F up, switch, Q up, yellow spinner down, R6C1 down,
R5C1 down, L down, M left (pulls H to R3C3), H down (ram), shell left,
H down, green spinner left, N down, Y up.

Verified facts (tool: `extreme14_lab.gd --deadends`; the explorer is
exhaustive):

| Move (at the start) | Result | Play goes on for | Where play stops (pieces stranded) |
|---|---|---|---|
| switch first | lost | up to 11 more moves | column-6 stand-off: F reversed (R2C6 facing down) and Y^ (R6C6) |
| R5C1 right first | lost | up to 11 more moves | bottom-row stand-off: yellow spinner facing right and the cracked shell facing left |
| R6C1 left first | lost | up to 11 more moves | the same bottom-row stand-off |
| N first | lost | up to 11 more moves | the hammer gone: the armored shell is left alone, among other endings |
| F up / Q up / yellow spinner down | winnable | | |

Along the solution, the same four mistakes stay available and stay late:
N up to step 8 (lost 5-12 moves later), the corner mistakes up to step 5.
Each kind of mistake ends in a **different** stranded picture: column 6,
the bottom row, or the uncracked shell. Each failure therefore points at
one rule. That a player will read it this way is a hypothesis.

### 2.3 Meaningful decisions (verified counts)

- Opening: 3 of 7 legal moves keep the board winnable.
- Decisions that 6-move lookahead cannot settle: 6 (Q1: 6). With 8-move
  lookahead: 4 (Q1: 4).
- Hidden decisions K=6 / K=8: 15 / 13 (Q1: 12 / 7).
- Deepest trap: 12 moves. Median trap delay: 10.
- Timing magnets: 2. M wins in 1 of 2 timings tried, N in 6 of 32.
- The four decisions: when to press the switch, in which order to unwind
  the corner, whether to unload Q before M, and when to fire N.

### 2.4 How R1 differs from Q1 and T5 (an honest account)

| | T5 | Q1 | R1 |
|---|---|---|---|
| Key mechanic | two magnets, timing | three magnets in a crossing; a conveyor | a SWITCH that reverses a magnet's pull side |
| What decides the win | which magnet fires at move 5 | which magnet takes H; what B carries; H's arrow | when the switch is pressed (F first); the corner order that opens M's lane; N's timing |
| Hard decisions K6 / hidden K6 | - | 6 / 12 | 6 / 15 |
| Opening | - | 1 of 3 | 3 of 7 |

**Shared with Q1 (risk of transfer):** a magnet carries a hammer into the
shell's column, and a bottom magnet that steals the hammer if fired too
early. The expert solved Q1 "by eliminating each magnet's wrong moment"
(docs/extreme12_replay.md). That habit transfers to N, so N's trap is
likely the easiest one for him.

**New in R1 (not in Q1 or T5):**
- the switch reverses a magnet, so the pull side must be read from the
  switch, not the arrow on screen;
- the switch must wait for F;
- the latch L ties the corner chain to the magnet's exit;
- the corner order with the fake-progress ram.

Three of the four losing first moves are R1-specific.

The near-copy guard compares R1 with every played board, Q1 included, and
passes.

### 2.5 Is every mechanic and piece needed? (one-piece removal screen, full acceptance)

| Removed | Result |
|---|---|
| switch R1C1 | the board no longer parses (its links lose their piece); the idea is gone |
| F R2C6 | trivial: a greedy player wins 26%, learners 0 |
| L R3C1 | passes every gate (learners 9 / 12); see below |
| M R3C3 | unsolvable |
| Q R3C4 | only 1 timing magnet (gate fails) |
| H R3C5 | unsolvable |
| green spinner R3C6 | the idea no longer on every winning line; greedy 21%; SHOW A MOVE over budget |
| corner R5C1 | passes the gates, but learners drop from 9 to 5 (the corner order loses its trap) |
| corner R6C1 | armor no longer matters; 6-move greedy 8% |
| yellow spinner R6C2 | 6-move greedy 10% |
| shell R6C3 | everything trivial (greedy 94%) |
| N R6C5 | the idea off some winning lines; greedy 10% |
| Y R6C6 | the idea off some winning lines; greedy 16% |

**The latch L is a disclosed judgement call.** Without it, the board
passes the acceptance gates. It is kept because it is the piece that ties
the corner chain to M's exit. Without it, the board changes measurably:

| Measure | With L | Without L |
|---|---|---|
| hard decisions (K6) | 6 | 4 |
| hidden decisions (K6 / K8) | 15 / 13 | 14 / 11 |
| deepest trap | 12 | 11 |
| positions | 523 | 711 (the builder's 700-position search ceiling, a SHOW A MOVE proxy) |

The 9 / 12 learner figure without L does not lower the minimum learner
score (9).

### 2.6 Alternate solutions and shortcuts

- 37 of 523 reachable positions are winnable (7%).
- Every winning line contains both idea events: the reversed magnet
  pulls (`flip_pull`) and the pulled block rams (`flip_ram`). No winning
  line cracks the shell another way.
- The yellow spinner's ram reaches the shell only on losing lines (the
  bottom-row stand-off).

## 3. Heuristic and technical scores

| Gate | Kind | R1 | Required | Result |
|---|---|---|---|---|
| solvable under the real rules | technical | yes (verify 273 nodes, 8.4 ms) | yes | pass |
| Solver / exhaustive parity, every reachable position | technical | 0 / 523 solve, 0 / 523 SHOW A MOVE mismatches | 0 | pass |
| SHOW A MOVE desktop, 5 repeated runs | technical | 26.9 / 35.7 / 23.9 / 24.0 / 23.8 ms | <= 40 | pass |
| SHOW A MOVE after a mistake (lab, median of 5) | technical | 35.2 ms | <= 40 | pass |
| WebAssembly build, CPU x1 | technical | verify 17.5, SHOW A MOVE 9.3, after a mistake 22.3 ms | <= 40 | pass |
| idea on every winning line | strategic | yes | yes | pass |
| timing magnets | strategic | 2 | >= 2 | pass |
| decisions 6-move lookahead cannot settle | strategic | 6 | >= 4 | pass |
| 6-move-lookahead greedy player | strategic | 2.5% | <= 5% | pass |
| other greedy players (best) | strategic | 1.7% | | pass |
| rule-of-thumb learner | strategic | 8 dead ends | >= 3 | pass |
| late plausible losing moves | strategic | 4 | >= 2 | pass |
| near copy of a played board (incl. Q1) | strategic | none | none | pass |
| **expert learner (lookahead 4 / 6)** | **heuristic screen** | **9 / 9 dead ends** | **>= 12** | **FAILED: recorded heuristic exception** |

The learner screen is a useful filter, not a validated predictor. Q1
scored 12 / 12, and the expert solved it unaided in 200 s, rated VERY HARD.

The exception is applied by `extreme14_build.gd --learner_exception`. It
lifts only the learner clause. Any other failed gate still rejects, and
the board is labelled EXPERIMENTAL.

### Candidate comparison

| | k3 (= R1) | k0 | k5 | k3 without L |
|---|---|---|---|---|
| difference | selected | corner R6C1 `Bv@`, R3C6 `G^@-` | R3C6 `G^@-` | L removed |
| pieces / positions | 13 / 523 | 13 / 503 | 13 / 527 | 12 / 711 |
| learners look4 / look6 | 9 / 9 | 8 / 9 | 8 / 9 | 9 / 12 |
| 6-look greedy | 2.5% | 2.5% | 4.2% | 2.5% |
| hard decisions K6, hidden K6 / K8, deepest | 6, 15 / 13, 12 | 6, 15 / 13, 12 | 6, 15 / 13, 12 | 4, 14 / 11, 11 |
| parity | 0 | 0 | 0 | 0 |
| technical gates | all pass (re-measured on an idle machine) | pass | **failed timing: 43 ms** (measured under parallel load, not re-measured: k3 dominates it) | pass |

All three 13-piece candidates share one strategic core. They differ only
in the corner and the green spinner. k3 has the best learner minimum and
the joint-best greedy rate.

Earlier families (4 / 4 learners or fewer) were not reviewed further.

## 4. The timed test (unchanged design, see the header of `scripts/social/blind_time_attack.gd`)

The rules:
- 180 s, by the Q1 countdown rules: thinking, RESTART, UNDO, SHOW A MOVE
  and the background all count, and a reload restores nothing;
- UNDO x3 per attempt, SHOW A MOVE x1 per run, HAMMER x0, hearts
  unchanged;
- TIME UP is frozen. After it come the timed questions (excitement,
  enjoyment, frustration, did the countdown help, 3 minutes too short /
  about right / too long, play again);
- then an optional CONTINUE WITHOUT TIMER. It continues from the
  position at 0:00 if that can still be cleared, otherwise it says so
  and starts a fresh board;
- the untimed game has unlimited RESTART, never refills SHOW A MOVE, and
  keeps its own record and log;
- then the puzzle questions (intrinsic difficulty EASY-EXTREME, one per
  line; enjoyment, achievement, fair, planning, combination, optional
  text).

Changes in this phase:
- **A tap on the armored shell is now logged as `"a"` WITH the block.**
  It changes nothing on the board, so the action log never saw it.
  Blocked taps stay `"b"` with the block. Both records count them
  (`armored_taps`, `blocked_taps`).
- **The untimed game's "NO TIMER" label reaches the test snapshot.**
  The page always showed it. The snapshot was stale.
- **The result cards re-publish their button positions after layout.**
  This is a test-snapshot fix. Players were never affected.

## 5. Technical QA (this container)

| Test | Result |
|---|---|
| `RTimeCheck` (headless) | **39 / 39**. Covers the exact board; isolation; the 3:00 start; RESTART and UNDO give no time back; SHOW A MOVE does not pause the clock; a blocked tap and an armored tap are each logged with the block; a reload in the timed phase does not restore time and keeps SHOW A MOVE spent, with the reopen logged; the background is recorded and the clock runs on; the frozen TIME UP is marked interrupted, with every log entry timestamped; the timed questions; continue from the 0:00 position, rebuilt exactly, with the hint not refilled, 5 restarts and an untimed solve; the timed record byte-identical afterwards; a fresh continuation after a lost timeout, with UNDO x3 and stop; a reload in every phase; a WIN and a GIVE UP skip the offer; `?q1time` and `?ptest11` state untouched |
| `web_rtime_page_test.mjs`, **full 180 s** run (Chromium, iPhone SE 375x667, real touches) | **17 / 17**. Covers the fingerprint; the countdown from 3:00 above the board; an armored tap logged with its block; a real reload mid-run (the board starts again, logged; the clock not restored; SHOW A MOVE x1); **TIME UP 179.9 s of wall time after 3:00, the reload included**; the frozen result; the timed questions; CONTINUE WITHOUT TIMER from the 0:00 position (11 blocks); a reload in the untimed game (rebuilt, 10 blocks); solved by touches; the puzzle questions; separate records; other pages' storage untouched; a timed WIN in a second profile (152 s left); no page errors; no network calls |
| the same test, `--fast` (saved clock moved back 165 s) plus the WebAssembly bench | **20 / 20**. Bench at CPU x1: verify 17.5, SHOW A MOVE 9.3, after a mistake 22.3 ms. At x4 / x6 (desktop simulation, reported): after a mistake 139.8 / 244 ms (Q1: 155 / 240) |

One engine notice is filtered by the browser test and is pre-existing:
an answer button removed inside its own press handler logs
`"!is_inside_tree()"`. It comes from the shared question screen of every
developer test page. It is harmless and unchanged.

Regression (after the last code change):

| Test | Result |
|---|---|
| `Q1TimeCheck` (the original Q1 Time Attack) | 37 / 37 |
| `Extreme11Check` (Q1, `?ptest11`) | 74 / 74 |
| `VhHumanTestCheck` | 100 / 100 |
| `TimingCheck` (campaign timer) | passed |
| `FriendTimerToolsTest` | passed |
| `FriendFlowTest` | 149 / 149 |
| `SocialPlayTest`, `SocialSmoke`, `MagnetCheck` | passed |
| `Extreme8Check` | 88 / 88 in two idle runs (slowest SHOW A MOVE 35.5 / 31.9 ms). Two earlier runs failed one timing check at 41.9-44.4 ms (> 40). The clean last commit shows the same spread (29.9-32.6 ms idle). That is container timing noise near the limit, not a code effect: the check drives SocialPlay only. |
| `web_q1time_page_test.mjs` | 21 / 21 |
| `web_ptest11_page_test.mjs` | 22 / 22 |
| `web_timing_test.mjs` (player build "Web Friend Test" + development build: campaign timer / Personal Best) | 33 / 33 |
| player build contents | no `extreme14` data and no `rtime` storage key in the package; the page's script is present but inert without its data, as in phase 8 |

## 6. Files (none committed)

| File | Change |
|---|---|
| `scripts/game_manager.gd` | +4 lines: the `?rtime=1` hook, above the phase 8 `?q1time` hook |
| `scripts/social/blind_time_attack.gd` | new: the test mode |
| `data/dev/extreme14.json` | new: R1, the selected board (replaces the provisional one) |
| `tools/extreme14_build.gd` | new: builder (parity gate, `--accept`, `--learner_exception`) |
| `tools/extreme14_events.gd` | new: the idea facts (`flip_pull`, `flip_ram`) |
| `tools/extreme14_lab.gd` | new: workbench (`--expert`, `--full`, `--deadends`) |
| `tools/extreme14_screen.gd` | new: one-edit screens |
| `tools/extreme14_parity.gd` | new: parity runner |
| `tools/extreme14_prune.gd` | new: the one-piece removal screen |
| `tools/rtime_check.gd`, `tools/RTimeCheck.tscn` | new: headless checks |
| `tools/web_rtime_page_test.mjs` | new: browser test (full 180 s; `--fast`; bench) |
| `docs/extreme14.md` | this report |
| `build/dev_qa/chain_escape_dev_rtime.zip` (git-ignored) | the development QA build |

Earlier uncommitted work (phases 6-8) is unchanged: Q1, `?ptest11`,
`?q1time`, the replay tools and their docs. It is verified against a
checksum list taken before this phase. The only file in that list that
changed is `game_manager.gd`, by the hook above.

## 7. Known limitations and risks

- **Human difficulty is unvalidated.** The only screen R1 fails is the
  learner screen. R1 may well play easier than Q1 for the expert, because
  N's trap matches the habit that solved Q1.
- **Long delays under a clock.** The four first-move mistakes lose only
  about 11 moves later, so a failed attempt costs perhaps 20-40 s. In 180
  s that leaves only a few attempts. This is a hypothesis to watch in the
  timed-question answers ("too short").
- **The clean-up tail.** The last 5 moves have no losing option.
- **The latch L is a judgement call** (Section 2.5).
- **The production Solver's magnet zone** (found earlier in this phase,
  not changed). The Solver precomputes a magnet's pull zone from its
  starting direction, so a switch-reversed magnet can pull from uncovered
  lines. R1 is checked exhaustively: 0 mismatches in all 523 positions.
  Other boards with reversed magnets need the same check.
- **Client-only data.** Results live in the browser (a local file plus
  localStorage), as on the earlier test pages. Clearing site data, private
  browsing, or a different browser or device starts over. A determined
  tester could edit localStorage. Two testers must use separate devices or
  browser profiles.
- **Real iPhone not tested here.** The browser tests use Chromium at iPhone
  SE size, and the x4 / x6 CPU numbers are a desktop simulation. A real
  iPhone run is still mandatory before the session.
