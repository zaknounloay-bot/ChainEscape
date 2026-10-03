# VERY HARD — test 2 analysis and blind human test 3 (development only)

> **Result (2 testers × 10 boards = 20 playthroughs; the third planned tester did not take part):** **0 / 20 rated VERY HARD.**
> - Counter-clockwise spinners (X) raised the son's ratings (X 2.83 vs control 2.25; 5 of 6 X boards HARD) but not Loay's (X 1.83 vs 2.25).
> - Combined: X 2.33 vs C 2.25.
> - **None of the pre-registered main criteria was met.** The guard criteria were.
> - Spinner direction alone has not shown it can create the target VERY HARD experience.
> - The VERY HARD design is **paused** (strategic decision, §8); no test 4.
>
> Full results: §7.

Nothing in production changes:
- no backend, Supabase or API change
- no change to the live difficulty profiles, Classic levels, sharing, Photo / Message or Friend Challenge

Phase 3 stays unfrozen.

## 1. Test 2 analysis (3 testers × 14 boards = 42 playthroughs)

Raw data: the three COPY RESULTS exports (Loay, an adult first-time player, Loay's son), joined by puzzle id with each board's structure from `data/dev/vh_human_test2.json`. **Excess moves** = moves − blocks + Hammer uses: wasted taps from mistakes and replays.

### Evidence

- **0 / 42 rated VERY HARD.** Ratings: 4 EASY, 27 MEDIUM, 11 HARD. All 42 were solved.
- **Group averages (1–4):** B 2.07, D 2.07, E 2.42 (pooled). The order differs by tester:
  - Loay: E 2.75 > B 2.4 > D 1.8
  - adult: E 2.25 ≈ D 2.2 > B 1.4
  - son: B 2.4 > E 2.25 ≈ D 2.2

  **No group is consistently harder.**
- **Opening discoverability does not explain the ratings.**
  - Pooled: "obvious start: YES" averages 2.13 vs NO 2.21.
  - Loay said NO on all 5 D boards and rated D lowest.
  - The adult said YES on all 14 and still took 2–3 minutes on D and E.
- **Restarts track the ratings within every tester:**

  | Tester | Average rating with restarts | Without restarts |
  |---|---|---|
  | Loay | 3.0 (4 puzzles) | 2.0 (10) |
  | adult | 2.4 (5) | 1.67 (9) |
  | son | 2.44 (9) | 2.0 (5) |

- **But many restarts still never reached VERY HARD.** Loay restarted P09 three times (HARD); the son restarted P07 and P10 four times each (HARD).
- **Experienced players are fast.**
  - Loay's median time is 22–24 s on B and D (66 s on E).
  - The son's is 29–35 s on every group.
  - Restarts are cheap: an attempt is about 20 taps.
- **Hammer:**
  - The adult used 16 Hammers. He rated B EASY on 3 of 5 boards, with 5 Hammers used on B. On D he used 7 and took 2–2.5 minutes.
  - Loay used none and the son used 2, and neither rated anything VERY HARD.
  - The son said that without the Hammer the puzzles still would not have been very hard.
- **Board-level correlation with the pooled rating** (n = 14, weak):
  - Solver / heuristic measures are near zero: heuristic player −0.12, one-safe steps +0.13, hidden steps −0.08, later scan +0.04.
  - "Tempting" arrows (blocked, ≤ 2 cells from the edge) +0.60, block count +0.39, branching after move 1 +0.37.
- **Hardest boards for people across all three testers:**

  | Board | Source | Rating (L/A/S) | Restarts (L/A/S) |
  |---|---|---|---|
  | **P13** | L165 geometry, flattened | 3 / 2 / 3 | 1 / 3 / 1 |
  | **P09** | L169 geometry, flattened | 3 / 2 / 2 | 3 / 0 / 1 |
  | **P10** | Friend T04 | 3 / 1 / 3 | 0 / 0 / 4 |
  | **P02** | Classic L44 | 2 / 3 / 3 | 0 / 1 / 1 |

### Contradictions with the working interpretation

- "E is strongest" holds for Loay only. The son had the most trouble with B, and the adult's B ratings are confounded by his Hammer use.
- Restarts raise ratings, yet 4 restarts still gave only HARD. So mistakes alone are not the missing ingredient; **cheap recovery** seems to cap perceived difficulty.
- The solver and heuristic proxies (heuristic player, one-safe steps, hidden steps) predicted the human ratings poorly, again.

### Inference (plausible, not proven)

- Perceived difficulty follows **forced recovery** (mistakes that need a restart) much more than **opening discoverability**.
- With arrows + clockwise spinners, players solve by fast trial and error: a 20-tap attempt and an instant restart are cheaper than planning. Experienced players likely use reliable local rules (moves that turn no spinner are always safe; a clockwise turn is easy to picture). This fits the lock audit's heuristic-player finding.
- The topology space of arrows + clockwise spinners has been explored broadly (current generator, solver selection, opening constraints, forced decisions, Locks, Classic and flattened late-Classic topology) without one VERY HARD rating in 72 test-1 + test-2 playthroughs. **Further topology-only tuning shows diminishing returns.**

### Speculation (to test, not assume)

- Mixing **counter-clockwise** with clockwise spinners breaks the single mental model ("every spinner turns the same way"). It may raise the cost of predicting each move enough that trial and error stops working and planning becomes necessary.
- A **longer, more costly attempt** (bigger boards, longer solutions) could also make trial and error expensive. The weak block-count correlation hints at it, but it risks tedium rather than thought. Possible later variable; not mixed into test 3.

**Conclusion:** the evidence justifies one controlled step beyond arrows + clockwise spinners. Counter-clockwise spinners are the cleanest candidate:
- an existing Classic rule
- deterministic and visible
- fully understood by the Solver
- directly targets the "local rules make it easy" explanation

The alternatives are weaker: Locks were already measured as unhelpful; hidden arrows add luck; alternating / pattern spinners combine two changes.

## 2. Test 3 design

**Question:** does mixing counter-clockwise with clockwise spinners create the missing planning difficulty for people?

**One controlled variable:** spinner direction. Same presentation, same tools, the same Hammer rule for both groups.

| Group | Boards | How |
|---|---|---|
| **C** control (4) | test-2 P13, P09, P10, P02: the arrows + clockwise boards that were hardest **for people** | Unchanged puzzles, **rotated 90°** (an orientation no tester has seen; a rotation keeps the puzzle identical and clockwise stays clockwise) |
| **X** experimental (6) | new arrows + clockwise + **counter-clockwise** boards | Offline FriendGenerator search with the test-1 B human criteria (arrows + spinners only, `@-` allowed for this file only), then kept **only if spinner direction matters** (below); the best 6 of 16 candidates |

**"Direction matters" constraints for X** (`tools/vh_human_test3_build.gd`):
- ≥ 2 counter-clockwise **and** ≥ 2 clockwise spinners (mixed, not a uniform swap)
- **misread steps ≥ 2:** solution steps where a player who assumes every spinner turns clockwise would misjudge whether some legal move is safe or a trap
- ranked by misread steps, by whether the all-clockwise version of the board is **unsolvable** (then reading a spinner's direction wrong cannot work at all), by trap delay, and by a low heuristic-player rate

**The boards** (as built; Q-ids are the blind puzzle ids):

| Id | Group | Size | Blocks | CW / CCW | Start legal / safe / calm | One-safe steps | Depth | Misread steps | All-CW solvable | Trap delay avg / max | Heuristic player |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Q01 | X | 6×7 | 20 | 3 / 2 | 3 / 2 / 1 | 6 | 15 | 4 | **no** | 5.5 / 9 | 13% |
| Q03 | X | 6×6 | 21 | 5 / 2 | 3 / 3 / 2 | 6 | 12 | 5 | yes | 5.5 / 13 | 8% |
| Q04 | X | 6×6 | 21 | 4 / 3 | 3 / 2 / 2 | 9 | 14 | 6 | **no** | 8.5 / 16 | 10% |
| Q06 | X | 6×6 | 18 | 5 / 2 | 3 / 1 / 0 | 5 | 12 | 7 | yes | 6.5 / 10 | 5% |
| Q08 | X | 6×7 | 20 | 5 / 2 | 3 / 3 / 2 | 7 | 16 | 2 | yes | 5.5 / 11 | 2% |
| Q09 | X | 6×6 | 20 | 4 / 2 | 3 / 3 / 2 | 6 | 12 | 6 | **no** | 6.7 / 12 | 5% |
| Q02 | C | 7×7 | 21 | 6 / 0 | 5 / 4 / 3 | 8 | 16 | – | – | 8.0 / 16 | 3% |
| Q05 | C | 6×6 | 23 | 5 / 0 | 2 / 1 / 1 | 1 | 14 | – | – | 8.4 / 12 | 17% |
| Q07 | C | 7×7 | 22 | 5 / 0 | 3 / 2 / 0 | 7 | 20 | – | – | 4.2 / 8 | 10% |
| Q10 | C | 6×6 | 20 | 6 / 0 | 2 / 1 / 0 | 4 | 14 | – | – | 10.0 / 16 | 7% |

Generation cost: 16 candidates in 63 s (0.4–8 s each); 6 qualified. The generator does not enforce a counter-clockwise minimum, so most rejects had 0–1 CCW spinners.

**Honest note:** the trap-delay measure (how many random moves remain after a wrong move before getting stuck) is just as high on the clockwise controls. Random play does not separate the groups on "late discovery of mistakes"; only people can tell.

**Assistance (both groups):** UNDO x3, SHOW A MOVE x1, **HAMMER x0** (the Hammer button is hidden), RESTART.

**Presentation:** the same blind SocialPlay page as tests 1 and 2 (`?vhtest3=1`):
- "PUZZLE n / 10 · VERY HARD"
- a random order per device
- groups named only after the last puzzle
- its own storage (file + localStorage key) separate from tests 1 and 2
- no network

The intro adds one line for every board: "Spinners turn when a block next to them leaves. The arrowheads on a spinner's ring show which way it turns: some turn clockwise, some counter-clockwise."

**Limitation:** a counter-clockwise spinner is visible, so a tester can tell that an X board has one. The test is blind to the source and the design, not to the spinner rule itself, and that is unavoidable.

## 3. Measurement

**Recorded locally for each puzzle:**
- hidden group, puzzle id, completed
- total time, time to the first move
- moves, restarts, UNDO and SHOW A MOVE uses
- the rating
- **pauses:** the longest pause between two actions (move, UNDO, SHOW A MOVE, RESTART), and every pause ≥ 10 s with where it happened (attempt number, blocks already cleared / total)

**Questions after each puzzle:**
1. "How difficult was this puzzle?" EASY / MEDIUM / HARD / VERY HARD
2. **"During the puzzle, did you have to stop and plan your next moves?"** YES / NO / SKIP (replaces the opening question, which test 2 showed is not the main driver)
3. **"Did a move that looked right turn out to be a mistake later?"** YES / NO / SKIP (the "delayed consequence" experience VERY HARD should create)

## 4. Success criteria (decided before the test)

**Primary: human perceived difficulty**, for X against C. All of the following:
- ≥ 1/3 of X playthroughs rated **VERY HARD** (C and every earlier test: 0)
- X average rating ≥ C average + 0.7 (on 1–4)
- at least 2 of the 3 testers rate at least one X board VERY HARD

**Supporting: planning, not clutter.** On X compared with C:
- more "had to plan" and "a move that looked right was a mistake later" YES answers
- more long pauses
- more restarts or UNDO from the experienced testers

**Guard: not impossible.** ≥ 90% of X playthroughs solved, and no tester gives up on more than one X board.

**Readability:** after the test, each tester says whether they could see which way each spinner turns. If not, X difficulty may come from misreading rather than reasoning, and the result is inconclusive.

**If X meets the primary criteria:** counter-clockwise mixing is the candidate VERY HARD ingredient. The next steps would be a generator design (enforcing a mix, direction-matters constraints) and the backend token rule (`@-` for friend VERY HARD), both separately approved.

**If X ≈ C:** spinner direction alone is not enough. The next candidate variable would be attempt cost (board size / solution length), again tested on its own.

## 5. How the three testers run it

1. Upload the development ZIP to the separate private itch.io test page (not the live game).
2. On each iPhone, open it in Safari with `&vhtest3=1` added to the address (for example `…/index.html?v=123&vhtest3=1`).
3. Read the intro, tap START, play all **10**. Please stay on each puzzle while it is open (time counts); breaks between puzzles are fine.
4. Answer the three questions after each puzzle.
5. At the end, tap **COPY RESULTS** and paste it into the chat. Add one sentence per tester: "Could you always see which way a spinner would turn?"

## 6. Files

- `tools/vh_human_test3_build.gd` → `data/dev/vh_human_test3.json`: the boards and their measurements
- `scripts/social/vh_human_test.gd`: `?vhtest3=1`, two follow-up questions, pause recording, HAMMER x0
- `scripts/social/social_play.gd`: the Hammer button is hidden when the allowance is 0. The game's default stays x2, so live play is unchanged.
- `scripts/social/friend_generator.gd`: `mechanics_ok(..., allow_ccw)` for these offline boards only. Production validation still refuses `@-`.
- `tools/classic_topology_audit.gd`: `rotate90`
- Checks: `tools/VhHumanTestCheck.tscn` (100), `tools/web_vhtest_page_test.mjs` (17)


## 7. Test 3 results (2 testers × 10 boards, run on 2026-10-03)

**Testers:**
- **Loay:** very high exposure to Chain Escape; has completed all 200 Classic levels and every earlier test.
- **His son:** experienced, with far less exposure.

The third planned tester did not take part, and the dataset was closed at 20 playthroughs by decision. **Loay confirmed that CW vs CCW direction was visually clear throughout.** No readability answer was given for the son, and none is assumed.

**Moves** are taps that moved a block (all attempts); **excess** = moves − blocks on the board, i.e. wasted taps across all attempts. Pauses are gaps between two actions; a long pause is ≥ 10 s.

### 7.1 By tester

| | Loay C (4) | Loay X (6) | Son C (4) | Son X (6) |
|---|---|---|---|---|
| Average rating (1–4) | 2.25 | **1.83** | 2.25 | **2.83** |
| VERY HARD / HARD / MEDIUM / EASY | 0 / 1 / 3 / 0 | 0 / 0 / 5 / 1 | 0 / 1 / 3 / 0 | 0 / **5** / 1 / 0 |
| Solved | 4 / 4 | 6 / 6 | 4 / 4 | 6 / 6 |
| Median total time | 42.0 s | 51.0 s | 48.1 s | 55.4 s |
| Median time to first move | 2.9 s | 3.6 s | 3.1 s | 1.6 s |
| Moves (average) / excess | 30.5 / 9.0 | 31.2 / 11.2 | 35.5 / 14.0 | 38.3 / 18.3 |
| Restarts (total / per puzzle) | 8 / 2.0 | 6 / 1.0 | 5 / 1.25 | 10 / 1.67 |
| UNDO (total / per puzzle) | 3 / 0.75 | 1 / 0.17 | 8 / 2.0 | 14 / 2.33 |
| SHOW A MOVE | 0 | 0 | 0 | 0 |
| "Had to plan" YES | 3 / 4 (75%) | 4 / 6 (67%) | 3 / 4 (75%) | 4 / 6 (67%) |
| "Mistake later" YES | 4 / 4 (100%) | 4 / 6 (67%) | 3 / 4 (75%) | 5 / 6 (83%) |
| Long pauses (≥ 10 s) | 1 | 1 | 2 | 2 |
| Median / max longest pause | 5.5 / 11.5 s | 5.7 / 15.9 s | 8.8 / 17.2 s | 5.3 / 15.8 s |

### 7.2 Combined

| | C (8 playthroughs) | X (12 playthroughs) |
|---|---|---|
| Average rating | 2.25 | 2.33 (+0.08) |
| VERY HARD | 0 | **0** |
| HARD | 2 (25%) | 5 (42%; all 5 from the son) |
| Solved | 8 / 8 | 12 / 12 |
| Median / mean total time | 42.0 / 50.8 s | 51.0 / 50.3 s |
| Median time to first move | 2.9 s | 2.5 s |
| Moves (average) / excess | 33.0 / 11.5 | 34.8 / 14.8 |
| Restarts per puzzle | 1.63 | 1.33 |
| UNDO per puzzle | 1.38 | 1.25 |
| SHOW A MOVE | 0 | 0 |
| "Had to plan" YES | 75% | 67% |
| "Mistake later" YES | 88% | 75% |
| Long pauses per puzzle | 0.38 | 0.25 |
| Median longest pause | 6.8 s | 5.5 s |

**Per board** (rating, restarts):

| Board | Group | Loay | Son |
|---|---|---|---|
| Q01 | X | MEDIUM, 1 | HARD, 1 (15.8 s before the first move) |
| Q03 | X | MEDIUM, 2 | HARD, 1 |
| Q04 | X | EASY, 0 | MEDIUM, 1 |
| Q06 | X | MEDIUM, 1 | HARD, 4 |
| Q08 | X | MEDIUM, 1 | HARD, 2 |
| Q09 | X | MEDIUM, 1 | HARD, 1 |
| Q02 | C | **HARD, 4** | MEDIUM, 1 |
| Q05 | C | MEDIUM, 0 | MEDIUM, 1 |
| Q07 | C | MEDIUM, 2 | HARD, 2 (2 long pauses, 101 s) |
| Q10 | C | MEDIUM, 2 | MEDIUM, 1 |

### 7.3 Pre-registered criteria (§4, as written before the test; not redefined)

| Criterion | Observed | Status |
|---|---|---|
| **Main 1:** ≥ 1/3 of X playthroughs rated VERY HARD | 0 / 12 | **Not met.** Even a third tester rating all 6 X boards VERY HARD would have given exactly 6 / 18 = 1/3, so only a perfect third tester could have rescued it |
| **Main 2:** X average ≥ C average + 0.7 | 2.33 vs 2.25 (+0.08); Loay −0.42, son +0.58 | **Not met** (combined, and for each tester separately) |
| **Main 3:** at least 2 of the 3 testers rate ≥ 1 X board VERY HARD | 0 of the 2 testers who took part | **Not met.** Defined for 3 testers, so a third tester could add at most one, making 1 of 3: it could not have been met. It is not reinterpreted as a 2-tester criterion |
| **Supporting:** more "had to plan" on X | X 67% vs C 75% (the same for both testers) | Not met |
| **Supporting:** more "mistake later" on X | X 75% vs C 88%; Loay 67% vs 100%, son 83% vs 75% | Not met combined (higher for the son only) |
| **Supporting:** more long pauses on X | 0.25 vs 0.38 per puzzle; median longest pause 5.5 vs 6.8 s | Not met |
| **Supporting:** more restarts / UNDO from experienced testers on X | Son: restarts 1.67 vs 1.25, UNDO 2.33 vs 2.0 (more). Loay: restarts 1.0 vs 2.0, UNDO 0.17 vs 0.75 (fewer) | Mixed: met for the son, not for Loay |
| **Guard:** ≥ 90% of X playthroughs solved | 12 / 12 | Met (for the 2 testers who took part) |
| **Guard:** no tester gives up on > 1 X board | No give-ups | Met (for the 2 testers who took part) |
| **Readability** | Loay: clear throughout. Son: not reported | Loay assessable; son not assessable |

**Overall:** the pre-registered success condition (all three main criteria) was **not met**. Counter-clockwise spinners did not produce VERY HARD. Main 1 and Main 3 could not have been met even with the missing third tester, except, for Main 1, an implausible perfect score.

### 7.4 Interpretation

**A. Evidence (what the data shows)**
- 0 / 20 VERY HARD. All 20 solved, no give-ups, no SHOW A MOVE used.
- The effect of counter-clockwise spinners differs by tester:
  - **The son** rated X higher (2.83 vs 2.25; 5 of 6 X boards HARD vs 1 of 4 controls), with more restarts and UNDO on X.
  - **Loay** rated X lower (1.83 vs 2.25; his only HARD was a control, Q02, with 4 restarts), with fewer restarts and UNDO on X.
- Loay confirmed the spinner direction was visually clear, so his result is not a readability artefact.
- Totals and timing barely differ between the groups: mean time about 50 s for both, first move about 2.5–3 s, long pauses rare (6 in 20 playthroughs).
- Both follow-up questions got YES on most boards in **both** groups ("had to plan" 67–75%, "mistake later" 75–88%), so they did not separate the groups.
- Across tests 1, 2 and 3 there have been **92 human playthroughs** of candidate VERY HARD boards: 30 + 42 + 20, with arrows + clockwise spinners, Locks, and clockwise + counter-clockwise spinners. **None was rated VERY HARD.**

**B. Reasonable inference**
- In these boards, counter-clockwise spinners act more like a **learning-curve** factor than a lasting difficulty factor. They raised difficulty for the less-exposed player and not for the most-exposed one. A VERY HARD benchmark has to hold for experts, so this is the more important signal for the target.
- Removing the Hammer (x0 here) did not by itself create VERY HARD, which supports the earlier decision not to manufacture difficulty by removing tools.
- SHOW A MOVE was unused across tests 2 and 3 by the experienced testers, so the assistance count is not what is holding difficulty back.
- With fast trial and error (about 20–40 taps per attempt, near-instant restarts), these testers recover from mistakes cheaply. Ratings cap at HARD even when they make several mistakes, consistent with test 2.
- The "plan" and "mistake later" questions, as worded, hit a ceiling: experienced players say YES to most boards of any kind. They are weak discriminators.

**C. Speculation (not supported or refuted by this data)**
- Counter-clockwise spinners may still help as **one ingredient among several** (for example combined with longer attempts or other mechanics from levels 201–300), but this test cannot show that.
- Board ordering, fatigue across 10 puzzles, and recognition (Loay has seen the controls in two earlier orientations) could have shifted individual ratings. The sample is too small to separate these.

### 7.5 Limitations

- **2 testers, 20 playthroughs:** too small for confident effects. Per-tester differences dominate the group differences.
- **The third tester is missing,** so criteria defined for 3 testers are assessed as written.
- **Unequal group sizes** (4 C vs 6 X): rates are compared per playthrough.
- **Not fully blind:** counter-clockwise spinners are visible, and Loay has seen every control board before (in other orientations); he may recognise them.
- **No readability report for the son.**
- **Timing data is valid this time** (no reported multitasking), but there is one data point per tester per board.

## 8. Decision: VERY HARD design paused

The final VERY HARD design is **paused** after test 3. No test 4 and no new generator iteration. Production, Classic, the backend, Supabase, the API, sharing, Photo / Message, the live Friend generator and the production difficulty settings are unchanged, and **Phase 3 stays unfrozen**.

**Why (strategic):** Levels 201–300 are planned before launch and will add mechanics and a richer gameplay vocabulary. The final Friend VERY HARD should challenge a player who has learned the **whole** vocabulary through level 300. Tuning it now against the vocabulary of levels 1–200 risks optimising for a target that becomes obsolete. Test 3 is the last experiment of the current investigation.

### Lessons to carry forward (levels 201–300 and the later Friend generator)

1. **People, not proxies.** Solver and heuristic measures (random tapper, lookahead / heuristic players, one-safe steps, hidden steps, trap delay) did not predict human ratings in tests 1–3. Any future VERY HARD must be validated with people, including expert players.
2. **The expert is the benchmark.** A rule a player has not internalised yet (counter-clockwise for the son, everything for a first-time adult) creates temporary difficulty that fades with exposure. VERY HARD must stay hard for someone who knows the full vocabulary through level 300.
3. **Opening discoverability is not the driver** (test 2), and neither is the assistance count: the Hammer was removed in test 3, and SHOW A MOVE went unused across tests 2–3.
4. **Cheap recovery caps difficulty.** Ratings rise with restarts but stopped at HARD in 92 playthroughs. Future designs should look at what makes trial and error *fail* (for example longer or costlier attempts, or interactions between mechanics), not only at the number of traps.
5. **Spinner direction is a candidate ingredient, not a solution.** Keep the tooling:
   - `FriendGenerator.mechanics_ok(..., allow_ccw)` for offline boards
   - the "direction matters" measures in `tools/vh_human_test3_build.gd`: misread steps, all-clockwise solvability
   - the blind test page (`?vhtest=1` / `?vhtest2=1` / `?vhtest3=1`) with per-move pause recording, ready for future human tests
6. **Better instruments next time:** "had to plan" and "mistake later" hit a ceiling. Prefer behavioural measures (restarts, excess moves, pauses, give-ups), or comparative questions (rank two boards) over yes / no.
7. **Test design:** recruit more testers, with mixed exposure levels; balance the group sizes; avoid boards an expert has already played.
