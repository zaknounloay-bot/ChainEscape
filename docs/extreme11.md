# EXTREME phase 6: one SHOW A MOVE per puzzle, and the crossing-magnet prototype

Development only. Nothing here changes Production, levels 1-300, Supabase, the
live Social MVP, Photo / Message Reveal, Challenge a Friend, coins / progression,
campaign hearts or assistance, or any earlier prototype board. Nothing is
deployed or uploaded.

## 1. The experimental SHOW A MOVE rule (`?ptest11=1` only)

### 1.1 What the live rule does today (investigated)

`SocialPlay.hint()` (`scripts/social/social_play.gd`), used by Photo / Message
Reveal, Challenge a Friend and every earlier test mode:

| Situation | Answer | Spent? |
|---|---|---|
| allowance left, position can be cleared | the move is highlighted | yes (`hints_used += 1`) |
| allowance left, position **can't** be cleared | "This board can't be cleared from here - try Undo" | **no** |
| allowance left, no legal move | "No moves left - tap Undo" | no |
| allowance used | "No SHOW A MOVE left - Undo or Restart can help" | - |
| RESTART | `_load_puzzle()` sets `hints_used = 0` | **refilled** |

So a player can press SHOW A MOVE after every move and learn, for free and as
often as they like, whether the position is already lost: an unlimited
dead-end detector. And every RESTART refills it, so a board can be walked one
highlighted move per attempt. The page also never logged the free presses
(only presses that changed a counter), so this use was invisible in the data
(docs/extreme10_replay.md).

### 1.2 The rule in this mode (defined before it was implemented)

1. **Budget.** One SHOW A MOVE per puzzle. It is stored in this mode's own
   state (`user://extreme11_state.json` and, on the Web, the localStorage key
   `chain_escape_ptest11_state`) as `budget[puzzle id]`, and written there
   **before** any answer appears.
2. **A press while it is available always spends it, whatever the position:**
   - the position can still be cleared: the solver's move is highlighted
     (the existing `Solver.recommend_move()` choice, unchanged);
   - it can't: "Can't be cleared from here - SHOW A MOVE used". The
     information is paid for at the same price as a highlighted move.
3. **Exception: no legal move at all.** The play screen already shows "No
   moves left - tap Undo / Restart" to everyone, so this is not hidden
   information: the press gets that same answer and spends nothing.
4. **Once spent,** every press gets the same answer, "No SHOW A MOVE left in
   this puzzle", in every position, and the solver is not consulted. A press
   reveals nothing, so it cannot be used to tell a lost position from a
   winnable one.
5. **No bypass.** RESTART, UNDO, a page refresh, closing and reopening the
   page and coming back later all keep it spent: at every (re)start the page
   sets the play screen's allowance from the stored budget (0 once spent), so
   `SocialPlay`'s per-attempt refill gives nothing back. The highlight
   behaves as before (the next tap or UNDO clears it) and is not shown again
   after a refresh.
6. **The puzzle in progress survives a refresh.** Its record (move log, time,
   totals, presses) is saved after every logged action. When the page opens
   again it carries on with the same record and clock (time while the page
   was closed is not counted). The board starts again from the beginning,
   logged as `"o"` (like RESTART). After solving or giving up, a refresh
   returns to the questions, not the board.
7. **Logged:** every press, including refused ones, as
   `[ms, "h", block or -1, {"r": "shown" | "lost" | "stuck" | "none", "att": attempt}]`.
   The result also records `hint_presses`, `first_hint_ms`, `first_hint_attempt`,
   `unaided_max_cleared` (most blocks cleared before it was used), `attempts`
   and `reopens`. The page does not work out whether a refused press came
   from a lost position (that would cost solver time on the phone);
   `tools/human_replay.gd` recomputes it offline from the log.
8. **Scope.** `SocialPlay` is not modified. Only this page mode disconnects its
   SHOW A MOVE button from `SocialPlay.hint` and connects its own handler
   (`VhHumanTest.budget_hint`). Every other mode, the campaign, Photo /
   Message Reveal and Challenge a Friend keep their rule.

Alternatives rejected:
- Refusing for free in a lost position: the refusal itself is the oracle.
- Highlighting some move anyway: that would mislead.
- Spending on "no legal move": that charges for what the screen already shows.

The tester is told the rule up front on the intro card: "ONE SHOW A MOVE for
the whole puzzle: it does not come back after RESTART, UNDO or if you leave
and return".

## 2. The board (Q1, `?ptest11=1`)

Internal design name: **the Conveyor**. The tester sees only "PUZZLE 1 / 1",
the board id is `Q1`, the group `Q`, and the board file carries no name,
difficulty, solution, trap or explanation (checked).

```
      C1    C2    C3     C4    C5    C6
R1    .     .     .      .     P<    R<@        R<@  clockwise spinner, facing left
R2    .     .     .      .     .     R^*        R^*  magnet C, facing up
R3    Y>@-  .     G<@-   P<@   Y^    B>*        G<@- H, the "hammer": counter-clockwise spinner
R4    .     .     .      .     .     .          B>*  magnet B, facing right
R5    .     .     .      .     .     .
R6    P^@   G>@   Pv*    P<    .     R<=        Pv*  magnet A, facing down; R<= the shell
```

6x6, 13 pieces: three magnets, five spinners (three clockwise, two
counter-clockwise), one shell, four plain arrows. No new mechanic; every
magnet is a plain arrow; no spinner is a magnet, switch target or shell.

### 2.1 The idea: a conveyor and a crossing

- **A magnet takes the NEAREST block behind it.** Magnet B's line is row 3:
  Y^, then the spinner P<@, then H. B is a conveyor. To make it carry H you
  must first unload what stands in front of H. Each piece you unload turns
  its spinner neighbours, so unloading the queue also sets H's arrow.
- **Two pull lines meet on H.** H is also the first block above magnet A
  (column 3). Whichever magnet fires first takes it: A drags H down into the
  shell's row (it looks like the shortcut); B carries it under itself, into
  the shell's column.
- **A third line crosses B's cell.** Magnet C's line runs down column 6
  through B. Fired before B, C drags magnet B itself. Fired after B but
  before the ram, it turns H away and lifts it out of the shell's column.
  Fired after the ram, it is exactly what frees H: it turns H to face right
  and lifts it out of the way.

The insight is not "one magnet pulls another". Three things are controlled
at once: what a magnet carries (by unloading its line), which magnet takes a
shared block (by order), and the carried spinner's final arrow (by which
neighbours leave around it, and when).

### 2.2 The solution (one of the winning lines)

| # | Move | What it does |
|---|---|---|
| 1 | R1C5 `P<` left | unlocks: its leaving turns the R1C6 spinner to face up |
| 2 | R1C6 spinner up | clears magnet C's exit (C is now live) |
| 3 | R3C5 `Y^` up | first item off the conveyor; turns the queue spinner R3C4 to face up |
| 4 | R3C4 spinner up | second item off; its leaving turns H (counter-clockwise) to face DOWN |
| 5 | magnet B right | the conveyor delivers: H (now first in line) is carried to R3C6, facing down |
| 6 | H rams down | through R4C6, R5C6 into the shell at R6C6 |
| 7 | magnet C up | turns H to face right and lifts it to R2C6 |
| 8-14 | clean-up | R3C1, H, R6C1 (turns R6C2 down), R6C2, magnet A (pulls nothing now), R6C4, the shell |

Moves 8-14 have no losing option; each piece there was a blocker earlier in
the logic, for example R3C1 is the next item on B's line if H is taken by A.

### 2.3 The decisions and the traps (exhaustive)

Every losing move along the solution, with how long play can go on after it
(a "+n" is the longest legal continuation before the board is stuck):

| Step | Losing moves available |
|---|---|
| 1 | magnet B (+8: carries `Y^`), magnet A (+12: takes H down into the shell's row) |
| 2 | B (+7), A (+11) |
| 3 | C (+10: drags magnet B up), B (+6), A (+10) |
| 4 | C (+9), B (+9: carries the queue spinner), A (+9) |
| 5 | C (+8), A (+8) |
| 6 | C (+7: steals H before the ram, turns it away) |

All 13 losing moves along the solution are magnet escapes, and none of them is
visible to a 4-move lookahead or as a static stand-off (`tools/expert_features.gd`).
Three magnets are **timing magnets**: each wins in some winnable positions and
loses in others (A 12 / 7, B 2 / 5, C 2 / 5 positions). This is the T5 lesson
(docs/extreme10_replay.md) built in on purpose. After a correct opening, two
or three look-alike magnets are live at once, each right at a different
moment: B only once its line is unloaded, C only after the ram, A only once H
has left its column.

**Opening, honestly:** the first four moves are a logical unlock chain. Each
step's safe move is the non-magnet piece that has just been freed, which is
discoverable by reasoning backwards from "B must carry H". It is not a
trap-free opening, though. From move 1 a magnet is available whose failure
shows 8-12 moves later (step 2 has two winning moves; steps 1, 3 and 4 have
one). It is calmer than T5's (1 of 4 at each of its first four steps) only in
that the safe move each time is a plain piece, not a magnet.

### 2.4 How it was made

1. **Hand core** (workbench `tools/extreme11_lab.gd`): magnet B carries the
   contested spinner across; the vertical magnet is the decoy; a third magnet
   under B turns and carries it; one shell (sketches v1-v3).
2. **Refinement around the frozen core**: seeded climbs
   (`tools/extreme11_build.gd`, all earlier gates plus the idea on every
   winning line and timing magnets), then a deterministic one-edit beam
   screen (`tools/extreme11_screen.gd`: every single addition, change, move
   or removal of a non-core piece, ranked by exhaustive measures, learners
   on the best). The unlock chain on the top row, the queue spinner and the
   bottom-row blockers came from these screens, then checked by hand.
3. **Performance**: the first passing board (c2) was 43.6 ms for SHOW A MOVE
   along its solution, because the winning first move came last in the
   solver's move order. Its vertical mirror (the same puzzle) halved that. A
   stricter screen (at most 130 SHOW A MOVE nodes, measured at most 25 ms)
   then gave Q1.
4. **Pruning** (full acceptance on every one-piece removal): removing any of
   the 13 pieces makes the board unsolvable (magnets B and C, H, `Y^`), loses
   the idea (magnet A, the shell, R3C1, R6C1, R6C4), or fails the gates (R1C5
   and R1C6: learners 9; the queue spinner: learners 6; R6C2: a greedy
   player wins 18 %). No decoration.

## 3. Solver validation

All exhaustive over every reachable position (315, 39 of them winnable),
re-measured by `tools/extreme11_check.gd` from the stored board.

| Requirement | Evidence |
|---|---|
| solvable | 14-move solution; the verifier needs 125 nodes, 8.3 ms (working budget 20,000) |
| two or more consequential timing decisions | 3 timing magnets (A, B, C); 6 steps on the solution have a losing move that 6-move lookahead cannot see, 4 that 8-move lookahead cannot |
| genuine traps | 13 losing moves along the solution, all hidden (none visible as a stand-off, none detectable 4 moves ahead); deepest 12 moves |
| the dependency chain on every winning line | `contested_pull`, `contested_turn`, `contested_ram` hold on EVERY winning line (no witness exists) |
| no shortcuts | the same: no winning line avoids the contested hammer; the shell is only ever rammed by H |
| no unnecessary pieces | every one-piece removal fails (Section 2.4) |
| SHOW A MOVE correct and bounded | always finds a winning move on the solution; at most 124 solver nodes on the solution and 124 after any mistake; never aborts |
| mistake states responsive | the page's own button after 6 plausible mistakes: 26.9 ms slowest (real screen, desktop) |
| moves follow the rules | every board played to the end in the real SocialPlay; the solver and the play screen agree (the earlier parity tooling, unchanged rules) |
| earlier acceptance (unchanged) | Gate 0 limits, 5 repeated timing runs within 40 ms (21.1-27.8 ms), armor and magnets matter, greedy players at most 1.5 %, best rule of thumb 11 dead ends (gate 3), 3 late misleading moves, not a copy or variant of any played board |
| expert gates (unchanged) | learners look 4 / look 6: 12 / 12 dead ends (gate 12), 6 decisions 6-move lookahead cannot settle (gate 4), look-6 greedy 2.5 % (gate 5 %) |

## 4. Compared with the boards the expert played

| | T5 | E2 | H2 | **Q1** |
|---|---|---|---|---|
| expert's verdict | VERY HARD, 120 s, 13 restarts, 7 SHOW A MOVE | HARD, 110 s, 7 restarts, 5 SHOW A MOVE | HARD, 33 s, 1 restart | (blind test pending) |
| size / pieces / magnets | 6x6 / 13 / 3 | 7x7 / 12 / 2 | 7x7 / 10 / 2 | 6x6 / 13 / 3 |
| reachable / winnable positions | 283 / 34 | 614 / 64 | 237 / 23 | 315 / 39 |
| winning first moves | 1 / 4 | 2 / 5 | 2 / 3 | 1 / 3 |
| decisions 4 / 6 / 8 moves of lookahead cannot settle | 6 / 4 / 1 | 6 / 5 / 3 | 6 / 4 / 2 | **6 / 6 / 4** |
| hidden losing moves at 6 / 8 | 7 / 1 | 15 / 9 | 6 / 2 | 12 / 7 |
| deepest trap (moves) | 9 | 11 | 10 | **12** |
| timing magnets | 2 | 1 | 2 | **3** |
| contested pull / turn / ram on every winning line | yes / no / no | no / no / no | no / no / no | **yes / yes / yes** |
| learners look 4 / 6 (dead ends) | **16 / 14** | 13 / 13 | 4 / 3 | 12 / 12 |
| perceptive learner (dead ends) | **42** | 22 | 19 | 26 |
| losing moves on the solution that are magnet escapes | 9 of 16 | 6 of 18 | 11 of 14 | **13 of 13** |
| SHOW A MOVE after a mistake (lab) | 13 ms | 39 ms | 4 ms | 22 ms |

Reading it honestly:
- **Q1 is deeper than T5** on every lookahead measure: decisions hidden from
  8-move lookahead, the deepest trap, timing magnets, and the crossing idea
  on every line.
- **It is not deeper on the learner measures.** T5 is still higher (16 / 14
  and 42 against 12 / 12 and 26).
- Phase 5 (docs/extreme9_analysis.md) found that **no static measure predicted
  the expert's ranking**. None of these numbers is a difficulty claim; only
  people decide.

## 5. Human-relevant analysis (predictions, not results)

From the T5 / E2 replays (docs/extreme10_replay.md):
- **T5:** he found the 4-move opening himself and failed at move 5, a
  choice between two plausible magnets that are each right at a different
  moment.
- **E2:** he found the relay on attempt 2.

What Q1 asks of him:
- **The opening is a backward chain.** He is likely to find it by reasoning:
  "B must carry H; B carries the nearest block; so unload Y^ and the queue
  spinner".
- **What is new: the crossing at B's cell.** Once B has delivered, two magnets
  are live, and his T5 habit of releasing a ready magnet loses:
  - C, fired before the ram, takes the hammer;
  - A, fired early in the game, takes the hammer down into the shell's row.
    That looks like the shortcut, and it loses 12 moves later.
- **The orientation is set by the unloading,** not by an obvious turner.
  Without unloading the queue in order, H never faces the shell.
- **One SHOW A MOVE per puzzle** removes the hint-walk that solved T5 for him
  (6 hints confirmed known moves, the 7th revealed the timing). A lost
  position now costs the one hint.

The decision that defeated him on T5 recurs three times here: two or three
plausible magnets are live at once, each right at a different moment.

## 6. Performance (40 ms desktop budget)

| Measure | Result |
|---|---|
| Gate 0 timing, 5 repeated runs (verify / SHOW A MOVE along the solution / after risky mistakes) | 21.1-27.8 ms (repeated acceptances: 21-29 ms) |
| SHOW A MOVE after EVERY losing move, slowest position, median of 5 | 21.5 ms (one slow spell measured 35 ms; Section 1 of the build header) |
| real play screen, the page's own SHOW A MOVE after 6 mistakes | 26.9 ms slowest |
| Web build (wasm) `&bench=1`, desktop CPU x1 / x4 / x6 | after a mistake 22.8 / 155 / 240 ms; verify 14 / 39 / 55 ms |

**This container's timing varies by about 1.6x in slow spells.** The same
board and position measured 21-35 ms, and the E2 check that passed 2 of 3
runs before now fails every run (Phase A). Q1 has about 12 ms of headroom on
the median. The throttled x4 / x6 numbers are a desktop simulation, not an
iPhone; **real iPhone Safari QA (`&bench=1`) remains mandatory.** A slow phone
answers SHOW A MOVE late, but correctly.

## 7. The blind test mode (`?ptest11=1`)

- Neutral: "PUZZLE TEST (DEVELOPMENT)", "PUZZLE 1 / 1", board `Q1`, group
  `Q`. No name, difficulty, solution, trap or decision is shown, and no
  difficulty label sits on the play screen.
- Its own storage: `user://extreme11_state.json` and localStorage
  `chain_escape_ptest11_state`. Every other test's storage is untouched
  (checked in the browser).
- Tools: UNDO x3 per attempt, ONE SHOW A MOVE for the whole puzzle (Section
  1), no HAMMER. The intro card states the rule.
- **Recorded automatically:**
  - every move with its timestamp (ms) and its mechanism events (gate,
    pull, flip, turn, ram);
  - RESTART, UNDO, blocked taps;
  - every SHOW A MOVE press with its outcome and attempt, including refused
    presses and presses in lost positions; when the budget was spent
    (`first_hint_ms`, `first_hint_attempt`);
  - page reopenings, completion or GIVE UP, total time;
  - the most blocks cleared before SHOW A MOVE was used
    (`unaided_max_cleared`).
- **Worked out offline** from the log (`tools/human_replay.gd`, which now
  reads this mode):
  - whether each press came from a winnable or a lost position;
  - the furthest winnable progress before SHOW A MOVE (unaided);
  - the time and attempts before it;
  - the losing decisions repeated across attempts;
  - winnable moves before the first losing one, per attempt (learning
    across restarts).
- **Asked after the puzzle:** difficulty EASY ... EXTREME; compared with
  Level 300; enjoyment 1-5; achievement 1-5; fair; needed planning; did
  the combination of mechanics make it more interesting; optional free text
  ("what made this puzzle difficult or interesting?").

**Open:** `index.html?ptest11=1` from
`build/dev_qa/chain_escape_dev_ptest11.zip`. Phone timing:
`index.html?ptest11=1&bench=1`. The file name is neutral on purpose: the
tester receives it.

## 8. Changed files (Phase B, none committed)

| File | Change |
|---|---|
| `scripts/social/vh_human_test.gd` | the `ptest11` mode: test entry, one-per-puzzle SHOW A MOVE handler (`budget_hint`), saved budget, puzzle-in-progress persistence, extra analytics, intro rule text. Every other mode keeps its behaviour (checked headless and in the browser). |
| `tools/human_replay.gd` | reads the `ptest11` log: press outcomes, reopen = restart, unaided progress, learning per attempt |
| `data/dev/extreme11.json` (new) | the board file (one board) |
| `docs/extreme11.md` (new) | this dossier |
| `tools/extreme11_events.gd` (new) | the idea facts and the timing measure |
| `tools/extreme11_build.gd` (new) | builder and acceptance (`--accept`, `--merge`) |
| `tools/extreme11_lab.gd` (new) | the design workbench |
| `tools/extreme11_screen.gd` (new) | the one-edit beam screen |
| `tools/extreme11_check.gd`, `tools/Extreme11Check.tscn` (new) | end-to-end checks |
| `tools/web_ptest11_page_test.mjs` (new) | browser test, iPhone SE size |

Not changed: `SocialPlay` (`scripts/social/social_play.gd`), the solver, the
rules, levels 1-300, Production, Supabase, the Social MVP, Photo / Message
Reveal, Challenge a Friend, coins, progression, hearts, campaign assistance,
every earlier board file (checked by hash), every earlier QA ZIP (checked by
hash).

## 9. Risks and limits

- **Timing margin on phones.** About 12 ms of headroom on desktop, and this
  container's timing varies by up to about 1.6x. The x4 / x6 throttled
  simulation answers SHOW A MOVE after a mistake in 155 / 240 ms. Run
  `&bench=1` on the tester's iPhone first.
- **The learner measures are at the gate,** not above it (12 / 12), and
  below T5's. Q1 beats T5 on the lookahead measures, not on the learner
  measures (Section 4).
- **The opening is a logical chain, not a trap-free one** (Section 2.3).
- **Hybrid process.** The core is by hand. The unlock chain and the
  bottom-row blockers came from restricted search, then were checked: every
  piece is needed, but not every piece carries a meaning a player would name.
- **The board file inside the build** carries analyst fields (misleading
  moves, measures), as in every earlier test. The page never shows them; a
  tester would have to unpack the build to see them.
- **One player first.** The older son is the first calibration player; one
  person's ratings are a signal, not a validation.
- **Phase A finding, still open:** `Extreme8Check`'s 40 ms gate now fails on
  E1 / E2 in this container (57-77 ms on SHOW A MOVE after a mistake; every
  functional assertion passes). The code is unchanged. It is a timing
  property of those boards on this machine, not a regression.

## 10. Technical QA (this container, desktop)

| Test | Result |
|---|---|
| `Extreme11Check` (new) | 74 / 74 passed (SHOW A MOVE after mistakes via the page button: 26.9 ms slowest) |
| `web_ptest11_page_test.mjs` (new, Chromium, iPhone SE 375x667, real touches) | 22 / 22 passed: the rule through RESTART and a real page reload, the full flow, GIVE UP, no page errors, no network calls; bench x1 / x4 / x6 |
| browser regression on the same build | xtest8 19 / 19, vhval3 21 / 21, xtest7 15 / 15, xtest6 14 / 14, xtest5 19 / 19, vhtest4 14 / 14, vhtest 17 / 17 |
| headless regression | VhHumanTestCheck 100, VhVal3Check 98, Extreme7Check 84, Extreme6Check 85, Extreme6Parity 35, Extreme5Check 147, VhPilot4Check 439, MagnetCheck, RevealMvpTest, SocialPlayTest, FriendFlowTest 149, CompetitionCheck, Era3ProdCheck, PortalProdCheck, SequenceCheck, MovableCheck, TwinsCheck: all passed |
| `Extreme8Check` | **failed: the 40 ms timing gate only** (E1 / E2, 46.6 ms this run); all functional assertions pass. Pre-existing (Phase A), unchanged code. |
| real iPhone Safari | **not done here: mandatory before the test** (`&bench=1` first) |

**Dev ZIP:** `build/dev_qa/chain_escape_dev_ptest11.zip` (git-ignored, not
uploaded), 13,101,979 bytes, SHA-256
`9f1c807750758ac7d6836d1927230b341f47b3856010dd07f0ca6b7a39d79244`. It also
contains every earlier test page, unchanged. The earlier ZIPs are untouched.
