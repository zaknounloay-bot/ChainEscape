# Experimental boards: inventory (Phase 12A consolidation)

Development only. Every board below lives in `data/dev/` and is reachable only through a development test page. Development pages are off in the player and QA builds (`BuildFlags.dev_pages_off()`). None is part of Production, the campaign, the Social MVP or Challenge a Friend.

## Notes on the data

**Fingerprints.** The fingerprint is the page fingerprint (`PuzzleDefinition.fingerprint()`), the one each page checks on load. It was recomputed from the committed data files during this consolidation, and every page constant matches.

**Human results.** These come only from:
- the session logs analysed in `docs/extreme12_replay.md` (Q1);
- the expert comparison in `docs/extreme9_analysis.md` (earlier boards);
- the results reported to me in the phase 10 and phase 11 briefs (R1, S1).

Anything not in those sources is marked "not recorded". Nothing is inferred.

**Testers.** "Son" is the experienced older son (the expert); "father" is the second tester.

**Status labels:**
- **TECHNICALLY VALIDATED**: passed the acceptance of its phase. That means solvable under the real rules; Solver / exhaustive-search parity where that gate existed (phase 9 onwards); the 40 ms desktop timing gate; and that phase's strategic gates. Recorded heuristic exceptions are listed.
- **HUMAN-TESTED**: at least one real session whose results are in the sources above.
- **NOT YET HUMAN-TESTED**: no real session recorded.

## 1. The current boards (phases 6-11)

| Board | Page | Fingerprint | Mechanics (from the data file) | Pieces | Technical QA | Human status |
|---|---|---|---|---|---|---|
| **Q1** "The Conveyor" | `?ptest11=1`, `?q1time=1` | `3fc4f9259fd8390236caf337bc5260c9b9e06eb36fec09032cdf452adb413711` | magnets, cw / ccw spinners, armored shell | 13 | TECHNICALLY VALIDATED (phase 6). Parity 0 mismatches in every position (later check, phase 9) | **HUMAN-TESTED** (`?ptest11`, untimed) |
| **R1** | `?rtime=1` (180 s) | `db0dd7e1ae7c721c3c59d1f6f18aee26d71358773d8f6db52e886e758ddfeebc` | switch, magnets, cw / ccw spinners, armored shell | 13 | TECHNICALLY VALIDATED (phase 9). Heuristic exception: expert learner 9 < 12 | **HUMAN-TESTED** (180 s) |
| **S1** | `?stime=1` (120 s, staged countdown) | `7714b7488829cefa28ea49fa427c4b2b51fabac8c2a1bae77fc9520a399efa2b` | lock, cw / ccw spinners | 13 | TECHNICALLY VALIDATED (phase 10). No exception (expert learner 23 / 25) | **HUMAN-TESTED** (120 s) |
| **TA** (test A, magnet) | `?tta=1` (120 s) | `a28e22f0a1a216ba4ac701ff549e7d212ce1fe83ae2d8e3678065da555b730cf` | magnets, cw / ccw spinners | 13 | TECHNICALLY VALIDATED (phase 11). Heuristic exception: expert learner 10 < 12 | **NOT YET HUMAN-TESTED** |
| **TB** (test B, spinner / lock) | `?ttb=1` (120 s) | `f8c22182180f45fa964593050c91d3fc534079338a438774f2b54dd00c924d99` | lock, cw / ccw spinners | 13 | TECHNICALLY VALIDATED (phase 11). Heuristic exception: expert learner 7 < 12. 6-move greedy at the 5 % limit | **NOT YET HUMAN-TESTED** |
| **TC** (test C, switch / shell) | `?ttc=1` (120 s) | `7f7ae09342e86e56a34ab4d52628346e455b97111a8f6c4663c97a9a587988d5` | switch, armored shell, cw / ccw spinners | 12 | TECHNICALLY VALIDATED (phase 11). No exception (expert learner 18 / 19) | **NOT YET HUMAN-TESTED** |

### Human results

Columns are kept apart on purpose:
- **Outcome, restarts and hints** are objective performance, from the logs.
- **Assistance** says whether the solution was the player's own.
- **Subjective difficulty** is the player's own rating, not a measurement.

| Board | Tester | Timed outcome | Untimed outcome | Assistance | Restarts | Hints | Subjective difficulty | Enjoyment | Achievement | Other answers |
|---|---|---|---|---|---|---|---|---|---|---|
| Q1 | son | (no timer: `?ptest11`) | solved, 199.6 s; no winning move ever shown | **none (independent solution)** | 9 | 1 spent ("lost"), 2 refused | VERY HARD | 5 / 5 | 5 / 5 | fair: YES. The core was reproduced exactly twice |
| Q1 | father | (no timer) | completed | **assisted: the final solution involved help from his son** (not counted as independent) | 8 | 1 spent at 55 s ("can't be cleared") | EXTREME | 5 / 5 | 5 / 5 | rated it harder than Level 300; fair: NO (reason unknown) |
| R1 | father | WIN, 1:01.5 of 3:00 | - | none reported | 2 | 0 | MEDIUM | 5 / 5 | not recorded | 180 s: TOO LONG; timer improved: unsure; play again: yes |
| R1 | son | WIN, 2:17.3 of 3:00 | - | none reported | 6 | 0 | VERY HARD | 4 / 5 | 4 / 5 | 180 s: TOO LONG; timer improved: unsure; play again: yes |
| S1 | father | TIME UP at 2:00 | completed without the timer | none reported | 6 | 0 | not recorded | 5 / 5 | achievement came from the untimed solve (no number reported) | timer improved: YES; colour urgency: YES; 120 s: APPROPRIATE |
| S1 | son | WIN with 89 ms left (of 2:00) | - | none reported | 9 | 0 | VERY HARD | 5 / 5 (verbally corrected from an accidental 3) | 5 / 5 | timer improved: YES; colour urgency: YES; 120 s: APPROPRIATE |
| TA, TB, TC | - | not yet played | - | - | - | - | - | - | - | - |

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
  - 8 spinners.
  - "Magnet fired too early" is a trap the son already knows from Q1 / R1.
  - The heuristic exception (10 < 12).
- **TB:**
  - The 6-move greedy player sits exactly at the 5 % limit.
  - The heuristic exception (7 < 12).
- **TC:**
  - 7 spinners.
  - The opening is forced: 1 of 5 legal first moves wins.
  - "Move F before the switch" is R1's opening trap in the same corner.
- **TA and TC:** SHOW A MOVE after a mistake reaches 100-157 ms at x4 / x6 desktop CPU throttling (Q1 / R1: 140-240 ms). That is a simulation. None of the 120 s boards has been measured on a real iPhone (Safari, reduced motion, backgrounding).

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

## 3. Common timed-mode rules (unchanged)

| Page | Clock | Assistance | Countdown UI |
|---|---|---|---|
| `?q1time` (Q1), `?rtime` (R1) | 180 s | UNDO x3 per attempt, SHOW A MOVE x1 per run, HAMMER x0 | plain digits; red in the last 30 s |
| `?stime` (S1), `?tta` / `?ttb` / `?ttc` | **120 s** | UNDO x3 per attempt, SHOW A MOVE x1 per run, HAMMER x0 | fixed pill: green 2:00-1:01, orange 1:00-0:31, red 0:30-0:00 (pulse; filled icon in the last 10 s); reduced motion respected |

Shared rules on every timed page:
- The clock never stops or refills on RESTART, UNDO, SHOW A MOVE, the background or a reload.
- TIME UP is frozen.
- On `?rtime`, `?stime` and `?tt*`, CONTINUE WITHOUT TIMER is optional and keeps a separate record.
- Each page has its own storage.
