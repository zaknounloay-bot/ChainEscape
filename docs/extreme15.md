# EXTREME phase 10: a new blind board against a staged 2-minute clock (`?stime=1`)

Development only. Nothing was committed, pushed, deployed or uploaded.
These were not touched: Production, campaign levels 1-300, Supabase, the
Social MVP, Challenge a Friend, the economy and progression, the campaign
timer and Personal Best, the Q1 and R1 boards, hearts, and the hint rules.

**Status of the board: EXPERIMENTAL - HUMAN DIFFICULTY UNVALIDATED.**
It passes every technical gate, and every strategic gate as well, with
no exception (Section 3). Nothing here claims human EXTREME difficulty.
That waits for the expert's first blind session.

Notation: R = row and C = column, both counted from 1 at the top left.
The tools print `r<row>c<col>` counted from 0, so R3C3 = `r2c2`.

## 1. What R1 taught, and the design response

| R1 finding | Response in S1 |
|---|---|
| Both testers solved R1 well inside 180 s (father 61 s, MEDIUM; son 137 s, VERY HARD) and rated 180 s TOO LONG | 120 s; a board with more and longer traps than R1 (expert learners 23 / 25 against R1's 9 / 9) |
| Q1, R1, T5, E2 and H2 were all magnet boards. The expert solved Q1 by "eliminating each magnet's wrong moment", and R1 shared Q1's bottom-magnet trap | **No magnet, shell or switch.** A different dependency graph: colour LOCKS chained into one another, and the turn count of a LOCKED spinner |
| In R1, the natural "free" moves were often the right ones | In S1, the most natural first moves lose: freeing a green key early, or moving a free spinner on the top row (Section 2.3) |
| Losses an expert reads off the board cost him little (phase 5 analysis) | The decisive state - how far the locked spinner has turned, and which colours are still on the board - is not a stand-off you can see at the moment of the mistake |

The two testers' unsureness about the timer, and the "too long" ratings,
are addressed by the shorter clock and a far more visible countdown
(Section 4). The two changes are tested together, so the session cannot
separate their effects (an exploratory usability test).

## 2. The board: S1

```
      C1    C2     C3      C4     C5      C6
R1    .     .      .       .      .       .
R2    .     .      Y^@-    Y^@-   B<@-    .
R3    .     R>@    P^@#G   B>     .       G>@-
R4    .     .      B^@-    P^@    .       .
R5    .     .      Gv@     B<@    Y<#P    .
R6    .     .      .       .      .       G<@-
```

- **Pieces:** 6x6, 13 pieces.
  - two locks: the purple spinner `P^@#G` at R3C3, locked by green, and the yellow arrow `Y<#P` at R5C5, locked by purple;
  - 9 spinners: 4 clockwise, 5 counter-clockwise;
  - 2 plain arrows.
- **Mechanics:** colour lock, clockwise spinner, counter-clockwise spinner. All are campaign mechanics. Locks appear from level 13 (128 levels), and locked spinners in 49 levels. Nothing is new or untaught.
- **Map:** `[". . . . . .", ". . Y^@- Y^@- B<@- .", ". R>@ P^@#G B> . G>@-", ". . B^@- P^@ . .", ". . Gv@ B<@ Y<#P .", ". . . . . G<@-"]`
- **Page fingerprint:** `7714b7488829cefa28ea49fa427c4b2b51fabac8c2a1bae77fc9520a399efa2b`. It is held in `CountdownTimeAttack.S1_FINGERPRINT` and checked on load.
- **Builder canonical fingerprint:** `dd6568045f83ad765cf0251b6a3ecdfb449a970da48f807c38c9cf7780825112`.
- **Data:** `data/dev/extreme15.json`, id `S1`. It replaces the provisional board used while the mode was built. The page never shows the label, the metrics or any difficulty.

### 2.1 The insight

**The locks chain: green, then purple, then yellow.**
- The purple spinner at R3C3 cannot leave while any green is on the board.
- The yellow arrow at R5C5 cannot leave while any purple is on the board.

**The locked spinner keeps turning while it waits.** Every neighbour that
leaves turns it a quarter turn. So the order in which the three greens and
its neighbours leave decides which way it faces at the moment it is
finally free. The last green to leave sits in the yellow arrow's lane,
and its own departure turns the blue spinner beside it. Clearing the
keys early, which is the natural plan, spends turns at the wrong time.

Verified facts (exhaustive search):
- Every winning line contains `lock_turn`: the locked spinner is turned
  while still locked, and escapes later.
- 46 of 306 reachable positions are winnable.
- The solution is 13 taps: green R3C6 right, green R6C6 left, yellow
  R2C4 up, blue R3C4 right, purple R4C4 right, blue R5C4 up, green R5C3
  left (the last green: the purple spinner is free), purple R3C3 right,
  then 5 clean-up taps (red, blue, yellow R5C5 left, the two top
  spinners).

### 2.2 Decisions (verified)

| Step | Winning / legal moves |
|---|---|
| 1 | 3 / 5 |
| 2 | 2 / 5 |
| 3 | 1 / 4 |
| 4 | 1 / 3 |
| 5 | 1 / 3 |
| 6 | 1 / 4 |
| 7 | 1 / 3 |
| 8 | 2 / 3 |
| 9-13 | clean-up, no losing option |

- Decisions that 6-move lookahead cannot settle: 4. With 8-move
  lookahead: 2.
- Hidden losing moves (K = 6 / 8): 10 / 4.
- Deepest trap: 10 moves. Median trap delay: 7.

### 2.3 Plausible losing moves, and what they cost (verified, `extreme15_lab.gd --deadends`)

| Mistake | When it is available | Play goes on for | Where play stops |
|---|---|---|---|
| green R5C3 **down** (freeing a key early, the natural plan) | steps 1-6 | 5-10 more moves | most often a stand-off in row 5: the blue spinner R5C4 turned to face RIGHT, head-on with the locked yellow facing left |
| yellow R2C3 up / left (a free top-row spinner) | steps 1-8 | 2-10 more moves | the same row-5 stand-off, or the purple spinner left facing left at a blocker |
| blue R3C4 right too early | steps 2-3 | 7-8 more moves | the row-5 stand-off, with the top-row spinners turned the wrong way |
| blue R4C3 left | steps 6-7 | 2-5 more moves | the row-5 stand-off |

Each mistake surfaces late, in the bottom-right corner, far from where it
was made. That is the "non-visible loss" the expert data points to.
Whether he reads it that way is a hypothesis.

### 2.4 How S1 differs from Q1 and R1

| | Q1 | R1 | S1 |
|---|---|---|---|
| Mechanics | 3 magnets, spinners, a shell | a switch, 2 magnets, spinners, a shell | 2 colour locks, spinners |
| Central idea | which magnet takes the hammer | the switch reverses a magnet's pull side | a lock chain, and a locked spinner's turn count |
| Expert learners (look 4 / 6) | 12 / 12 | 9 / 9 | **23 / 25** |
| Hard decisions K6 / K8 | 6 / 4 | 6 / 4 | 4 / 2 |
| Hidden K6 / K8 | 12 / 7 | 15 / 13 | 10 / 4 |
| Deepest trap | 12 | 12 | 10 |
| 6-move greedy player | 2.5% | 2.5% | 4.2% |
| Opening (winning / legal) | 1 / 3 | 3 / 7 | 3 / 5 |
| Positions | 315 | 523 | 306 |

S1 shares no mechanic idea with Q1 or R1. The near-copy guard compares
it with every played board, R1 and Q1 included, and passes. The model
scores pull in different directions: learners are far higher, hidden
decisions lower. As the R1 data showed, none of these predicts the
expert.

### 2.5 Every piece is needed (one-piece removal, full acceptance)

All 13 removals fail acceptance on a gate other than the learner screen:

| Removed | First failing gates |
|---|---|
| yellow R2C3 | the lock stops mattering; greedy 26% |
| yellow R2C4 | the lock stops mattering; 6-move greedy 13% |
| blue R2C5 | 6-move greedy 8% |
| red R3C2 | greedy 14%; 3 hard decisions |
| purple (locked) R3C3 | the lock stops mattering; the idea off a winning line |
| blue R3C4 | greedy 30%; the idea off a winning line |
| green R3C6 | 3 hard decisions; 6-move greedy 9% |
| blue R4C3 | greedy 18%; 3 hard decisions |
| purple R4C4 | random tapper 24%; greedy 76% |
| green R5C3 | trivial (greedy 100%) |
| blue R5C4 | trivial (greedy 100%) |
| yellow (locked) R5C5 | the lock stops mattering; greedy 100% |
| green R6C6 | 3 hard decisions; 6-move greedy 9% |

### 2.6 Search record (honest)

- A hand-made core (the locked purple spinner, a green key next to it,
  a second lock keyed to purple) was refined by seeded climbs that keep
  the core cells fixed.
- One climb produced S1.
- Five other climbs (four seeded, one random) and two one-edit screens
  produced nothing that passed: their best still let a greedy player win 10-43%.
- S1 is therefore the only candidate. No weaker board was offered in
  its place.

## 3. Gates

| Gate | Kind | S1 | Required | Result |
|---|---|---|---|---|
| solvable under the real rules | technical | yes (verify 101 nodes, 3.4 ms) | yes | pass |
| Solver / exhaustive parity, every reachable position | technical | 0 / 306 solve, 0 / 306 SHOW A MOVE | 0 | pass |
| SHOW A MOVE desktop, 5 repeated runs | technical | 11.2 / 10.5 / 10.6 / 10.5 / 10.6 ms | <= 40 | pass |
| SHOW A MOVE after a mistake (lab) | technical | 14.6 ms | <= 40 | pass |
| WebAssembly build, CPU x1 | technical | verify 6.4, SHOW A MOVE 3.7, after a mistake 11.2 ms | <= 40 | pass |
| idea on every winning line (`lock_turn`) | strategic | yes | yes | pass |
| greedy players (best) / 6-move greedy | strategic | 0.8% / 4.2% | <= 5% | pass |
| rule-of-thumb learner | strategic | 23 dead ends | >= 3 | pass |
| expert learner (look 4 / 6) | heuristic screen | 23 / 25 | >= 12 | pass (a screen, not a predictor) |
| hard decisions K6 | strategic | 4 | >= 4 | pass (at the limit) |
| late plausible losing moves | strategic | 4 | >= 2 | pass |
| no decorative piece | strategic | 13 / 13 needed | all | pass |
| near copy of a played board | strategic | none | none | pass |

Mobile simulation (desktop CPU throttling; a real iPhone is still the
measurement that counts):
- at x4: SHOW A MOVE after a mistake 49.7 ms, verify 43.9 ms;
- at x6: 92.3 ms after a mistake;
- R1 at x4 was 140 ms.

## 4. The staged countdown (`scripts/social/countdown_time_attack.gd`)

- **Clock.** 120 s, by the phase 8/9 rules:
  - it starts after the board's first paced frames;
  - thinking, moves, UNDO, RESTART, SHOW A MOVE and the background all
    count;
  - RESTART and a reload never give time back.
- **Assistance and continuation.** UNDO x3 per attempt, SHOW A MOVE x1
  per timed run, HAMMER x0. The frozen TIME UP is followed by the
  optional CONTINUE WITHOUT TIMER (position kept if it can still be
  cleared, otherwise a fresh board, said so). Timed and untimed logs
  stay separate.
- **The pill.**
  - Fixed size (360 x 108 design units), centred between the top bar and
    the board; never over the board.
  - Where the gap is too small (not on a phone in portrait) the whole
    pill is scaled down, a transform only, so nothing else moves.
  - White digits on a coloured fill, which is far more visible than the
    phase 9 dark digits.

| Stage | Display | Fill | Non-colour cue | Motion |
|---|---|---|---|---|
| GREEN | 2:00-1:01 | `#1E7B34` | clock icon, weight 700 | none |
| ORANGE | 1:00-0:31 | `#C2410C` | half-filled clock, weight 800 | the fill eases from green over 0.4 s, once |
| RED | 0:30-0:11 | `#B91C1C` | warning triangle, weight 900 | the fill darkens toward `#7F1111` and back (35%, 1.25 s) |
| RED, last 10 s | 0:10-0:00 | `#B91C1C` | filled triangle | 55% depth, 0.9 s, scale 1.00-1.03 |

- **Contrast.** White text on the fills is about 5.4 : 1 (green), 5.2 : 1
  (orange) and 6.5 : 1 (red). The pulse only darkens, so contrast never
  drops.
- **No flashing.** Changes are under 1.2 per second, there are no light
  flashes, no sound and no modal.
- **Reduced motion.** The browser's `prefers-reduced-motion` turns off the
  ease, the pulse and the scale. The colours, icons and weights still
  change.
- **Cost.** One colour and transform update per frame; the icon is
  redrawn only when the stage changes. No node is created during the
  run.
- **Recorded stages.** The stages reached are recorded once each, as
  `run.stages` and log entries `"z"`, with the elapsed time and whether
  the page was visible then. The frozen timed record also gets
  `stages_reached` and `reduced_motion`. That a stage appeared is NOT
  evidence that it was noticed; the questions ask.

**Questions.**
- After the timed phase:
  - enjoyment, excitement, frustration (1-5);
  - did the timer improve the game (YES / NO / NOT SURE);
  - 120 s: TOO SHORT / APPROPRIATE / TOO LONG;
  - noticed green, orange, red (YES / NO / NOT SURE);
  - did the colours create urgency (YES / NO / NOT SURE);
  - play again (YES / NO / NOT SURE).
- After the untimed phase or a win:
  - intrinsic difficulty (EASY-EXTREME);
  - enjoyment, achievement;
  - planning, combination;
  - optional text.

## 5. Technical QA (this container)

| Test | Result |
|---|---|
| `STimeCheck` (headless, new) | **66 / 66.** Covers:<br>- **stages:** both with motion and with reduced motion, the exact thresholds (1:01 green, 1:00 orange, 0:31 orange, 0:30 red, 0:11 / 0:10 the last 10 s), icons, weights; the ease into orange (none with reduced motion); the red pulse never lighter than the resting red, scale only in the last 10 s; no layout shift; the pill never over the board;<br>- **records:** stages recorded once each and carried into the frozen record;<br>- **clock rules:** the 0:00 boundary (a solve 400 ms before counts, at 0:00 it does not); RESTART / UNDO / SHOW A MOVE give no time back; blocked taps logged with the block; a reload in the timed phase (the clock and SHOW A MOVE not restored); background recorded;<br>- **continuation:** continue from the 0:00 position; continue fresh from a lost position; reload in every phase; WIN and GIVE UP;<br>- **isolation:** `?q1time`, `?ptest11` and `?rtime` state untouched |
| `web_stime_page_test.mjs`, **full 120 s** (Chromium, iPhone SE 375x667, real touches) | **29 / 29.** Covers:<br>- **timing:** green at 2:00 (screen pixel 30,123,52); a real reload (clock not restored, SHOW A MOVE x1); 1:01 green, orange at 1:00 (pixel 194,65,12); 0:31 orange; red pulse from pixels (luma 54-61, never above the resting 61); last 10 s: filled icon, scale 1.002-1.028; no layout shift; **TIME UP 119.9 s of wall time after 2:00, a reload included**;<br>- **records and continuation:** stages reached in the frozen record; all 8 timed answers; untimed from the 0:00 position (11 blocks); reload in the untimed game; solved by touches; puzzle answers; separate records; other pages' storage untouched;<br>- **other runs:** a timed WIN in a fresh profile; reduced motion (emulated: red with no pulse and no scale on screen, recorded); bench;<br>- **errors:** no page errors, no network calls |
| iPhone SE screenshots | `S2_green`, `S3_orange`, `S4_red`, `S5_final10`, `S6_timeup`, `S7_offer`, `S8_untimed`, `S9_difficulty`, `S10_reduced_red` (sent with this report) |

The browser test also has a `--fast` mode, which moves the saved clock
back at the reload. The full 120 s run is the one reported above.

## 6. Regression

All run after the last code change:

| Test | Result |
|---|---|
| `STimeCheck` (this mode) | 66 / 66 |
| `RTimeCheck` (R1, `?rtime`) | 39 / 39 (after the refactor of its class) |
| `Q1TimeCheck` (Q1 Time Attack) | 37 / 37 (after the `limit()` refactor) |
| `Extreme11Check` (Q1, `?ptest11`) | 74 / 74 |
| `VhHumanTestCheck` | 100 / 100 |
| `TimingCheck` (campaign timer) | passed |
| `FriendTimerToolsTest`, `FriendFlowTest` (149 / 149) | passed |
| Social MVP: `SocialPlayTest`, `SocialSmoke`, `SocialApiTest`, `RevealMvpTest` | passed |
| Social MVP: `RecipientTest` | **3 layout checks fail ("TOTAL SCORE left, coins right", en / he / ar). Pre-existing: they fail identically on a clean checkout of the last commit (705b4bb). Not touched in this phase.** |
| `MagnetCheck` | passed |
| `Extreme8Check` (`?xtest8`) | **timing noise.** One SHOW A MOVE timing check is at 30-50 ms against 40 ms. A clean checkout of the last commit fails it the same way (40.2 / 48.3 ms). This tree passed one of two idle runs. The check drives SocialPlay only. |
| `web_q1time_page_test.mjs` | 21 / 21 |
| `web_rtime_page_test.mjs` (full 180 s) | 20 / 20 |
| `web_ptest11_page_test.mjs` | 22 / 22 |
| `web_timing_test.mjs` (player build "Web Friend Test" + development build: campaign timer, Personal Best) | passed |
| player build contents | no `extreme15` data and no `stime` storage key in the package |

## 7. Files (none committed)

| File | Change |
|---|---|
| `scripts/social/countdown_time_attack.gd` | new: the `?stime=1` mode (staged countdown, questions, stage records) |
| `data/dev/extreme15.json` | new: S1 |
| `scripts/game_manager.gd` | +4 lines: the `?stime=1` hook (above `?rtime` / `?q1time`) |
| `scripts/social/q1_time_attack.gd` | refactor, no behaviour change: the clock length read through `limit()` (was the constant) |
| `scripts/social/blind_time_attack.gd` | refactor, no behaviour change: the board id, fingerprint, question sets and intro text read through overridable functions |
| `tools/extreme15_build.gd`, `extreme15_events.gd`, `extreme15_lab.gd`, `extreme15_screen.gd`, `extreme15_prune.gd` | new: builder (`D_lock` recipe, `lock_turn` fact, parity, acceptance), workbench, one-edit screen (with `--soft` growth), removal screen |
| `tools/stime_check.gd`, `tools/STimeCheck.tscn` | new: headless checks |
| `tools/web_stime_page_test.mjs` | new: browser test (full 120 s, screen pixels, reduced motion, bench) |
| `docs/extreme15.md` | this report |
| `docs/extreme15_shots/*.png` | the iPhone SE screenshots of each stage (from the full browser run) |
| `build/dev_qa/chain_escape_dev_stime.zip` (git-ignored) | the development QA build |

All earlier uncommitted work is preserved: Q1, `?ptest11`, `?q1time`, R1
and `?rtime`, the replay tools and their docs. It was checked against a
checksum list taken before this phase. Only the three files listed above
changed, by the hook and the two refactors, and their regression checks
still pass.

## 8. Known limitations and risks

- **Human difficulty is unvalidated.** S1 is the only candidate the
  search produced. Its model scores are mixed:
  - learners are much higher than Q1 or R1;
  - hidden and hard decisions are lower;
  - hard decisions sit exactly at the gate (4).
- **Visual density.** 9 of the 13 pieces are spinners. Every piece is
  needed (2.5), but a crowded spinner cluster may read as clutter
  rather than insight. Watch the "what made it difficult" answer.
- **Five clean-up taps** at the end have no wrong option.
- **Familiar rules.** Locks and locked spinners are campaign mechanics.
  That is fair, but campaign habits may help.
- **Two changes at once.** The clock length and its visibility change
  together, so their effects cannot be separated.
- **Noticing the colours is self-reported.** It is asked; it is not
  inferred from the screen.
- **Client-only data**, as on the earlier test pages. Use one device or
  profile per tester; clearing site data starts over.
- **Not yet tested on a real iPhone.** The browser tests use Chromium at
  iPhone SE size. Safari's handling of `prefers-reduced-motion` and of
  the timer while backgrounded must be confirmed there.
