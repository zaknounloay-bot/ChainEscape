# Experimental boards: inventory (Phase 12A consolidation, updated in Phases 12B, 13 and 14)

Development only. Every board below lives in `data/dev/` and is reachable only through a development test page. Development pages are off in the player and QA builds (`BuildFlags.dev_pages_off()`). None is part of Production, the campaign, the Social MVP or Challenge a Friend.

## Notes on the data

**Fingerprints.** The fingerprint is the page fingerprint (`PuzzleDefinition.fingerprint()`), the one each page checks on load. It was recomputed from the committed data files during this consolidation, and every page constant matches.

**Human results.** These come only from:
- the session logs analysed in `docs/extreme12_replay.md` (Q1);
- the expert comparison in `docs/extreme9_analysis.md` (earlier boards);
- the results reported to me in the phase 10 and phase 11 briefs (R1, S1);
- the six first-exposure TA / TB / TC sessions reported in the phase 12B brief;
- the TA90 family-test correction reported in the phase 14 brief (section 4).

Anything not in those sources is marked "not recorded". Nothing is inferred.

**Testers.** "Son" is the experienced older son (the expert); "father" is the second tester.

**Status labels:**
- **TECHNICALLY VALIDATED**: passed the acceptance of its phase. That means solvable under the real rules; Solver / exhaustive-search parity where that gate existed (phase 9 onwards); the 40 ms desktop timing gate; and that phase's strategic gates. Recorded heuristic exceptions are listed.
- **HUMAN-TESTED**: at least one real session whose results are in the sources above.
- **NOT YET HUMAN-TESTED**: no real session recorded.

## 1. The current boards (phases 6-11)

| Board | Page | Fingerprint | Mechanics (from the data file) | Pieces | Technical QA | Human status |
|---|---|---|---|---|---|---|
| **Q1** "The Conveyor" | `?ptest11=1`, `?q1time=1` (180 s, archived reference) | `3fc4f9259fd8390236caf337bc5260c9b9e06eb36fec09032cdf452adb413711` | magnets, cw / ccw spinners, armored shell | 13 | TECHNICALLY VALIDATED (phase 6). Parity 0 mismatches in every position (later check, phase 9) | **HUMAN-TESTED** (`?ptest11`, untimed) |
| **R1** | `?rtime=1` (180 s, archived reference) | `db0dd7e1ae7c721c3c59d1f6f18aee26d71358773d8f6db52e886e758ddfeebc` | switch, magnets, cw / ccw spinners, armored shell | 13 | TECHNICALLY VALIDATED (phase 9). Heuristic exception: expert learner 9 < 12 | **HUMAN-TESTED** (180 s) |
| **S1** | `?stime=1` (120 s, staged countdown) | `7714b7488829cefa28ea49fa427c4b2b51fabac8c2a1bae77fc9520a399efa2b` | lock, cw / ccw spinners | 13 | TECHNICALLY VALIDATED (phase 10). No exception (expert learner 23 / 25) | **HUMAN-TESTED** (120 s) |
| **TA** (test A, magnet) | `?tta=1` (120 s) | `a28e22f0a1a216ba4ac701ff549e7d212ce1fe83ae2d8e3678065da555b730cf` | magnets, cw / ccw spinners | 13 | TECHNICALLY VALIDATED (phase 11). Heuristic exception: expert learner 10 < 12 | **HUMAN-TESTED** (120 s, first exposure, 2 testers) |
| **TB** (test B, spinner / lock) | `?ttb=1` (120 s) | `f8c22182180f45fa964593050c91d3fc534079338a438774f2b54dd00c924d99` | lock, cw / ccw spinners | 13 | TECHNICALLY VALIDATED (phase 11). Heuristic exception: expert learner 7 < 12. 6-move greedy at the 5 % limit | **HUMAN-TESTED** (120 s, first exposure, 2 testers) |
| **TC** (test C, switch / shell) | `?ttc=1` (120 s) | `7f7ae09342e86e56a34ab4d52628346e455b97111a8f6c4663c97a9a587988d5` | switch, armored shell, cw / ccw spinners | 12 | TECHNICALLY VALIDATED (phase 11). No exception (expert learner 18 / 19) | **HUMAN-TESTED** (120 s, first exposure, 2 testers) |

### Human results

Columns are kept apart on purpose:
- **Outcome, restarts and hints** are objective performance, from the logs.
- **Hints** separates SHOW A MOVE *requests* from *winning moves shown*.
- **Assistance** says whether the solution was the player's own.
- **Difficulty** is the player's own rating, not a measurement. A **first-exposure** rating is asked right after the timed run, before any untimed play. A **post-play** rating is asked after all play. The two are never merged.
- **Timed** success and **untimed** (continuation) success are separate outcomes.

Every session below was played under the assistance rules **of its time**: one SHOW A MOVE per run (Q1, R1: 180 s; S1, TA, TB, TC: rules `ta120-v1`). Phase 12B removed SHOW A MOVE from the 120 s pages for *future* sessions (section 3). None of these sessions is rewritten as having had zero hints available.

#### Q1, R1, S1

| Board | Tester | Timed outcome | Untimed outcome | Assistance | Restarts | Hints | First-exposure difficulty | Post-play difficulty | Enjoyment | Achievement | Other answers |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Q1 | son | (no timer: `?ptest11`) | solved, 199.6 s; no winning move ever shown | **none (independent solution)** | 9 | 3 requests: 1 spent ("lost"), 2 refused; 0 winning moves shown | not asked | VERY HARD | 5 / 5 | 5 / 5 | fair: YES. The core was reproduced exactly twice |
| Q1 | father | (no timer) | completed | **assisted: the final solution involved help from his son** (not counted as independent) | 8 | 1 request, spent at 55 s ("can't be cleared"); 0 winning moves shown | not asked | EXTREME | 5 / 5 | 5 / 5 | rated it harder than Level 300; fair: NO (reason unknown) |
| R1 | father | WIN, 1:01.5 of 3:00 | - | none reported | 2 | 0 | not asked | MEDIUM | 5 / 5 | not recorded | 180 s: TOO LONG; timer improved: unsure; play again: yes |
| R1 | son | WIN, 2:17.3 of 3:00 | - | none reported | 6 | 0 | not asked | VERY HARD | 4 / 5 | 4 / 5 | 180 s: TOO LONG; timer improved: unsure; play again: yes |
| S1 | father | TIME UP at 2:00 | completed without the timer | none reported | 6 | 0 | not asked | not recorded | 5 / 5 | achievement came from the untimed solve (no number reported) | timer improved: YES; colour urgency: YES; 120 s: APPROPRIATE |
| S1 | son | WIN with 89 ms left (of 2:00) | - | none reported | 9 | 0 | not asked | VERY HARD | 5 / 5 (verbally corrected from an accidental 3) | 5 / 5 | timer improved: YES; colour urgency: YES; 120 s: APPROPRIATE |

#### TA, TB, TC (phase 12B data: six first-exposure sessions)

Each tester saw each board for the first time. Attempts = restarts + 1. All six sessions were played under rules `ta120-v1` (UNDO x3 per attempt, ONE SHOW A MOVE per timed run, HAMMER x0, 120 s).

| Board | Tester | Timed outcome | Attempts / restarts | Hints | Untimed continuation | First-exposure difficulty | Timed enjoyment | Excitement | Puzzle enjoyment | Achievement | Timer improved the experience | 120 s duration |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| TA | father | **WIN**, 25.222 s | 3 / 2 | 0 used | not needed | MEDIUM | 5 / 5 | 5 / 5 | 5 / 5 | 3 / 5 | YES | not recorded |
| TA | son | **WIN**, 53.225 s | 5 / 4 | 0 used | not needed | HARD | 4 / 5 | 4 / 5 | 4 / 5 | 4 / 5 | YES | not recorded |
| TB | father | **WIN**, 52.427 s | 6 / 5 | 0 used | not needed | MEDIUM | 5 / 5 | 5 / 5 | 5 / 5 | 5 / 5 | YES | **TOO LONG** |
| TB | son | **WIN**, 73.884 s | 6 / 5 | 0 used | not needed | HARD | 4 / 5 | 4 / 5 | 4 / 5 | 4 / 5 | YES | not recorded |
| TC | father | **TIME UP** at 120 s (not a timed success) | 10 / 9 | **1 request; 0 winning moves shown** | **solved without the timer** in 26.374 s, 1 more restart (untimed success, not a timed victory) | VERY HARD | 5 / 5 | 5 / 5 | 5 / 5 | 5 / 5, after the untimed solve | YES | not recorded |
| TC | son | **WIN**, 84.170 s | 7 / 6 | 0 used | not needed | HARD | 5 / 5 | 4 / 5 | 4 / 5 | 4 / 5 | YES | not recorded |

Not recorded for TA / TB / TC: a post-play difficulty rating, frustration, the colour questions, "another puzzle", insight, combination and free-text feedback. They are left blank rather than inferred.

Reading of the six sessions:
- **Timed success.** 5 of 6 were won in the 120 s. TC defeated the father in the timed run; he solved it untimed.
- **Difficulty order.** By time, the order is TA < TB < TC for both testers.
  - The son rated all three HARD.
  - The father rated TA and TB MEDIUM and TC VERY HARD.
  - The father solved TA and TB faster than the son.
- **Experience.** Every session rated the timer as improving the experience. Enjoyment was 4-5 / 5 throughout.
- **Achievement.** Achievement varied most: father TA 3 / 5 (a 25 s solve), the rest 4-5 / 5.
- **Hints.** None of the six sessions received a winning move. The one request (father, TC) showed none.
- **Caution.** These ratings are encouraging. They come from two players of one family, one first exposure each. They are **not** evidence of broad player demand.

### Known limitations per board

- **Q1:**
  - Long play in lost positions without feedback, by design.
  - A late clean-up trap that the design report did not describe.
  - The father's fairness NO is unexplained.
  - Only one of the two Q1 solutions (the son's) is independent.
- **R1:**
  - Both testers solved it inside 180 s.
  - Its "other magnet fired early" trap repeats Q1's.
  - It is the board that led to the 120 s clock.
- **S1:**
  - 9 of 13 pieces are spinners (busy).
  - It has 5 clean-up taps with no wrong option.
  - The lock is a familiar campaign mechanic.
- **TA:**
  - Solved quickly by both testers (25 s, 53 s): the easiest of the three for both; the father's achievement was 3 / 5.
  - 8 spinners.
  - "Magnet fired too early" is a trap the son already knows from Q1 / R1.
  - The heuristic exception (10 < 12).
- **TB:**
  - Both testers won (52 s, 74 s); the father found 120 s TOO LONG for it.
  - The 6-move greedy player sits exactly at the 5 % limit.
  - The heuristic exception (7 < 12).
- **TC:**
  - The hardest of the three for both testers: the only TIME UP (father) and the son's slowest win (84 s).
  - 7 spinners.
  - The opening is forced: 1 of 5 legal first moves wins.
  - "Move F before the switch" is R1's opening trap in the same corner.
- **TA and TC (historical):** under rules `ta120-v1`, SHOW A MOVE after a mistake reached 100-157 ms at x4 / x6 desktop CPU throttling (Q1 / R1: 140-240 ms). Since phase 12B the 120 s pages no longer offer SHOW A MOVE, so this cost no longer applies to them. None of the 120 s boards has been measured on a real iPhone (Safari, reduced motion, backgrounding).
- **All 120 s boards:** the six TA / TB / TC sessions were played *with* one SHOW A MOVE available. Five used none and the one request showed no move, but no session has yet been played under the new zero-hint rules.

## 2. Earlier experimental boards (earlier phases; kept, not active)

| Board | Data file / page | Fingerprint | Mechanics | Pieces | Technical QA | Human results (son unless stated; ratings are subjective) |
|---|---|---|---|---|---|---|
| T1 | `extreme5.json`, `?xtest5` | `45e0d85acdceddd7f20df3a426642a723c09c9ecfd9a71d427ab6dc8f88eb3f9` | lock, cw / ccw spinners | 15 | TECHNICALLY VALIDATED (phase 1 gates) | not recorded in these reports |
| T2 | `extreme5.json`, `?xtest5` | `eb90d99a57bb599ce52887c3c11f1590f27222fa38f8bc559e06ce302f5f79f9` | cw / ccw / alternating spinners, Sequence | 9 | TECHNICALLY VALIDATED (phase 1 gates) | not recorded in these reports |
| T3 | `extreme5.json`, `?xtest5` / `?vhval3` | `c7849e13f7ea630165294f42f315cecc1e373076a96ec550a860cb7f60b692c2` | switch, gate, cw / ccw spinners | 14 | TECHNICALLY VALIDATED (phase 1 gates) | HUMAN-TESTED: HARD, 59 s, 3 restarts; the first tester rated it VERY HARD |
| T4 | `extreme5.json`, `?xtest5` | `b7b850898165aeb68a4ccc4ba2c8fda970c676d1c98ab5c86e253af1b82d05ec` | Movable crate, cw spinners | 10 | TECHNICALLY VALIDATED (phase 1 gates) | not recorded in these reports |
| T5 | `extreme5.json`, `?xtest5` / `?vhval3` | `a6fb5e514465cb61bee6486d186747fdffe7748d42c17b516725b54c0dd43ca3` | magnets, cw spinners | 13 | TECHNICALLY VALIDATED (phase 1 gates) | HUMAN-TESTED: VERY HARD, 119.6 s, 13 restarts, enjoyment 4, achievement 5. The key timing was revealed by a hint |
| P1, P2 | `extreme6.json`, `?xtest6` | `30eaacc67a379bdaf66a7dc54d853547d7a4463067accd5de71fe0c80b66ed59`, `336ce67af5f98d07fa2e5c4b398ce715d9d3903c4da6483f7ad43171fe1a40a0` | magnets, armored shell, cw / ccw spinners | 11, 10 | TECHNICALLY VALIDATED (phase 2 gates) | first tester: P1 MEDIUM; P2 not recorded |
| H1, H2 | `extreme7.json`, `?xtest7` | `e03b42cdb7e519e8330cc764890fff9cf13f597eb3caf40e757efdcac7067376`, `1cf2dc9fc15ba6b129074c575e0565adb0ef3405c22222effc16bb761ddce720` | H1: switch, gate, spinners. H2: magnet, shell, cw spinners | 12, 10 | TECHNICALLY VALIDATED (phase 3 gates) | H2: HARD, 33 s, 1 restart; the first tester rated it VERY HARD. H1 not recorded |
| E1, E2 | `extreme8.json`, `?xtest8` | `eced6b6b6dc1c88b735986e8cc418406da6bb7007663b3c1fcd8b53188a87477`, `527f4bfc0d21556d6fd68914e3278f0249e375177d8f16046e77fc3cb1873873` | E1: switch, gates, spinners. E2: magnets, shell, spinners | 16, 12 | TECHNICALLY VALIDATED (phase 4 expert gates) | E1: MEDIUM, 60 s, 1 restart. E2: HARD, 110 s, 7 restarts |

Solver / exhaustive parity on Q1, T5, E1, E2, H1 and H2 was checked exhaustively in phase 9: 0 mismatches. Parity was not run on T1-T4, P1, P2. The 28 pilot boards of the VERY HARD pilot (`vh_*` files) are not listed here.

## 3. Timed-mode rules

| Page | Status | Clock | Assistance | Countdown UI |
|---|---|---|---|---|
| `?q1time` (Q1), `?rtime` (R1) | archived experimental references; their historical rules are unchanged, so old sessions stay reproducible | 180 s | UNDO x3 per attempt, SHOW A MOVE x1 per run, HAMMER x0 | plain digits; red in the last 30 s |
| `?stime` (S1), `?tta` / `?ttb` / `?ttc` | the 120 s Time Attack for future use. **Rules `ta120-v2`** since phase 12B | **120 s** | **UNDO x3 per attempt, unlimited RESTART, SHOW A MOVE x0, HAMMER x0**, in the timed run *and* in the untimed continuation | fixed pill: green 2:00-1:01, orange 1:00-0:31, red 0:30-0:00 (pulse; filled icon in the last 10 s); reduced motion respected; no audio, no popups |

**Rules `ta120-v2`** (`CountdownTimeAttack.TA120_RULES`) cover S1, TA, TB and TC:
- **The SHOW A MOVE control is gone from the play screen.** It is hidden, every connection is cut, and it takes no mouse, touch, focus, shortcut or processing.
- **The hint budget is 0.** Any request from code is refused without asking the solver: nothing is shown, spent or logged.
- **Reload, RESTART and the untimed continuation cannot bring it back.**
- **Every new record carries the rules.** The timed record, the untimed record and the export carry `assist`, with `show_a_move: 0` and version `ta120-v2`.
- **Older records are not rewritten.** Records from before phase 12B (rules `ta120-v1`: ONE SHOW A MOVE per timed run) are exported with the rules they were played under, and their hint use stays intact.
- **The board data files are unchanged.** Their `assist` block still documents the `ta120-v1` rules of the recorded sessions, and every fingerprint is unchanged.
- **Untouched:** the campaign hint system, the Social MVP, Challenge a Friend, SocialPlay and the solver.
- **Screenshots.** iPhone SE screenshots of the intro and the tool bar (timed and untimed, all four pages) are in `docs/ta120_v2_shots/`.

**External pilot (phase 12C).** `?tapilot=1` puts the four 120 s boards behind one entry point for invited testers: welcome, a familiarity question, puzzle choice, the same pages and rules, skippable questions, and one export bundle. Its storage is separate. See `docs/tapilot.md`.

**Phase 13 (curated bank, then the 90-second prototype).**
- Five candidates were started (P5-P9, `tools/extreme17_*`; state preserved in `data/dev/extreme17_search/`).
- The bank was then paused for a 90-second prototype with dynamic music: `?ta90=1`, `docs/ta90_prototype.md`.
- **No Phase 13 board has been accepted.** P5 and P6 failed the full mandatory acceptance. P6's first version (a movable crate) was rejected because the Solver overflows the stack on crate boards. P7-P9 are paused.
- The prototype ran with TA as a labelled technical reference only, until Phase 14.

**Phase 14 (the 90-second design pipeline).** See `docs/ta90_design.md`.
- **Three new boards on `?ta90=1`:** N1, N2 and N3, shown as PUZZLE 1-3. Their status is **HUMAN-REVIEW CANDIDATE**: they passed every technical check, but their strategic quality is not confirmed by people. Nobody has played them yet.
- TA is now shown only with `&ta90ref=1`, as a labelled REFERENCE.
- Phase 13's P5 and P6 stay rejected.

Shared rules on every timed page:
- The clock never stops or refills on RESTART, UNDO, the background or a reload. It also never stops on SHOW A MOVE where that tool still exists (Q1, R1).
- TIME UP is frozen. An untimed solve is never recorded as a timed victory.
- On `?rtime`, `?stime` and `?tt*`, CONTINUE WITHOUT TIMER is optional. It keeps the same puzzle and continues from the 0:00 position when that position can still be cleared, otherwise it starts fresh. It keeps a separate record.
- Each page has its own storage.


## 4. Phase 14: the 90-second prototype (`?ta90=1`)

### Boards

Every board passed the mandatory technical checks of `tools/ta90_design.gd`, category A: intact parse, solvable, Solver / exhaustive-search parity 0 / 0 in every position, a deterministic replay, at most 700 positions, and at most 40 ms for the solve and the TIME UP check. All three are **NOT YET HUMAN-TESTED**.

| Board | Fingerprint | Mechanics | Pieces | Design target (not a rating) | Status |
|---|---|---|---|---|---|
| **N1** (PUZZLE 1) | `b5bb75f5937f03404ba786ff93d3e914d167ad2d5e28f88f5ed46e4a40377bff` | switch, cw / alternating spinners | 11 | MEDIUM | HUMAN-REVIEW CANDIDATE |
| **N2** (PUZZLE 2) | `f4be705fcc692f27f13e0cc8d7eca216a4ba68d117b84dce4980bfa5e76d695f` | chain gate, armored shell, cw / ccw / alternating spinners | 13 | HARD | HUMAN-REVIEW CANDIDATE |
| **N3** (PUZZLE 3) | `76d704deb06f8a6686040e5f5cfa6edeecdfc3f2a1af8f0c98be9a4922f2272c` | switch, chain gate, cw / ccw spinners | 14 | VERY HARD | HUMAN-REVIEW CANDIDATE |

### TA90 family test: a correction

TA90 here means the reference board TA, played on the 90-second prototype.

- **The middle son's frustration rating.** The recorded raw answer was **5 / 5**. He later clarified verbally that he meant **1 / 5** (not frustrating).
  - The raw value is kept unchanged as recorded.
  - The interpretation to use is **1 / 5 (verbal clarification)**.
  - Any analysis must name which one it uses.
- No other values from that test were reported to me, so none are listed here. They are not inferred.

### Recording sheet for the coming first-exposure sessions (N1-N3)

The `ce-ta90` bundle (COPY ALL RESULTS) carries the objective fields. The answers come from the questions after each run. One row per player and board.

| Field | Source |
|---|---|
| Time and outcome (WIN with the time left / TIME UP), untimed outcome kept apart | bundle: `timed_outcome`, `elapsed_ms`, `untimed_success` |
| Attempts and restarts | bundle: `restarts` (attempts = restarts + 1) |
| UNDO use | bundle: `undos` |
| Blocked taps | bundle: `blocked_taps` |
| Difficulty (first exposure) | question: "How difficult was this puzzle?" |
| Enjoyment, excitement, frustration (1-5) | questions |
| Achievement | the post-play question, where answered |
| Music contribution | question: "Did the music make the experience better?" (YES / NO / NOT SURE / MUSIC WAS OFF) |
| Desire to play again | question: "Would you play another puzzle?" |
| Verbal corrections | written next to the raw value, never instead of it (as above) |
