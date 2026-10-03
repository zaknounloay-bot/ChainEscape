# VERY HARD — test 2 analysis and blind human test 3 (development only)

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
