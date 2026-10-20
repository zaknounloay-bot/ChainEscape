# EXTREME phase 5: human behaviour analysis (development only)

**Question.** Why did the experienced analytical player (the older son) rate T5 VERY HARD, E2 HARD and E1 MEDIUM?

**Scope.** No boards were built or changed, nothing in Production, Supabase, the campaign, the Social MVP, tools / hearts / economy or the existing boards was touched, and nothing was committed. **Confirmed** marks facts checked in code or by exhaustive solver analysis; **hypothesis** marks everything else. The evidence is one expert (plus two other family testers), so nothing here is a validated predictor.

## 0. Data actually available

**The human move logs are not available to me.** The blind-test pages keep them in each tester's browser (localStorage) and hand them over only through COPY RESULTS. The `user://` state files in this container are from my own automated QA runs; they contain canned answers such as "the second magnet", not human play.

**Consequence.** Task 1 (move-by-move reconstruction of the older son's T5 and E2 sessions) cannot be done honestly yet. I did not infer attempts from the summary numbers.

**What is ready.** `tools/human_replay.gd` reconstructs every attempt from a COPY RESULTS JSON on the real game rules:
- the moves in words;
- after each move, whether the board can still be cleared (Solver);
- the move that lost each attempt, and how long play went on after it;
- each SHOW A MOVE and what it highlighted (it is deterministic, so it is recomputed exactly);
- UNDO, RESTART, blocked taps, GIVE UP;
- losing moves repeated across attempts, and progress per attempt.

It was validated on:
- my automated logs: an E1 session with an undo and a restart, and full solves of E1, E2 and T5;
- a synthetic E2 session in which the first attempt fires the red magnet early. The tool flags that move as the losing one, with up to 10 more moves possible, exactly as the dossier says, and then reconstructs the solve after the restart.

**Needed:** the COPY RESULTS JSON from the older son's T5 session (the `?vhval3=1` or `?xtest5=1` page) and his E1 / E2 session (`?xtest8=1`). Then:
```
godot --headless --path . --script res://tools/human_replay.gd -- --results=his_results.json --verbose
```

## 1. Attempt timelines (T5 vs E2)

**Not reconstructable without the logs** (Section 0).

**From the summary only:**

| | Time | Attempts | SHOW A MOVE | Average time per attempt |
|---|---|---|---|---|
| T5 | 119.6 s | 14 (13 restarts) | 7 | about 8.5 s |
| E2 | 110.3 s | 8 (7 restarts) | 5 | about 14 s |

Attempts averaging 8-14 seconds are short, consistent with quick probing rather than long planning. That is a **hypothesis**; the logs will show it.

**Confirmed from the rules: SHOW A MOVE use follows restarts.** He had 1 per attempt, so at most 14 on T5 and 8 on E2; he used 7 and 5, about one in every second attempt.

## 2. SHOW A MOVE: exact behaviour (confirmed in code: `scripts/social/social_play.gd`, `scripts/core/solver.gd`)

| Question | What the code does |
|---|---|
| Reveals a winning continuation? | **Yes.** It highlights one move after which the board can still be cleared (`Solver.recommend_move`). It prefers a **"risky" winning move**: one that turns a spinner, fires a switch, removes a turnable block while shells remain, or pushes. It falls back to a safe winning move only if there is no risky one. So it tends to point at exactly the critical decision, not a filler move. |
| Information after mistakes? | **Yes, and free.** In a position that can no longer be cleared it shows "This board can't be cleared from here - try Undo" and **does not spend the SHOW A MOVE**. It can be pressed again and again: an unlimited "am I already lost?" oracle, as long as that attempt's SHOW A MOVE is unused. |
| Usable across restarts? | **Yes.** RESTART reloads the puzzle and resets the count (`_load_puzzle`: `hints_used = 0`, likewise UNDO). The intro says so ("RESTART gives them back"). Effectively unlimited: one per attempt. |
| Resets unexpectedly? | **No.** UNDO does not refill it; only RESTART does, as documented. The highlight clears on the next tap or UNDO. |
| Enables trial and error instead of reasoning? | **Yes, by construction** (a hypothesis about his use until the logs are read). The loop "restart, play to the confusing point, SHOW A MOVE, learn one critical move" turns a hard puzzle into a sequence of revealed decisions; T5 needs about 5 of them. Combined with the free lost-check, a player can detect every dead end immediately and cheaply. |

**Intended vs actual.** The test description promises SHOW A MOVE x1 per attempt, and that is what happens. The free lost-check is not described anywhere, yet it **reveals that a legal move has made the board unsolvable**, which the EXTREME brief says should not be signalled automatically. It is not automatic, but it is free and unlimited.

**Logging gap (confirmed).** Presses that change no counter are **not logged**: the "can't be cleared from here" answers and presses after the attempt's SHOW A MOVE is used up. **His uses of the lost-check are invisible in the data.**

## 3. Repeated mistakes and learning

**Pending the logs.** The replay tool reports which losing move ended each attempt, and how far each attempt got while still winnable.

The plausible losing moves the logs should be checked against (from the dossiers):

| Board | Move | Fails up to ... moves later |
|---|---|---|
| T5 | either top-row magnet on move 1 (wrong pull) | 7-8 |
| T5 | releasing the free spinner G at R3C2 | 7 |
| T5 | R at R4C3 as soon as it can leave | 7 |
| E2 | releasing the free hammer | 10 |
| E2 | the red magnet early | 10 |
| E2 | the green spinner early | 10 |

## 4. Structural differences

Measured with `tools/expert_features.gd` and `tools/expert_probe.gd`: exhaustive, on the solver's solution and every losing move along it.

| | T5 | E2 | T3 | E1 | H2 |
|---|---|---|---|---|---|
| Expert (older son): restarts / time | **13 / 120 s** | 7 / 110 s | 3 / 59 s | 1 / 60 s | 1 / 33 s |
| His rating | VERY HARD | HARD | HARD | MEDIUM | HARD |
| Pulls on the solution | 3 | 2 | 0 | 0 | 2 |
| **Pull reach** (cells moved by pulls, total / longest) | **8 / 4** | 4 / 3 | 0 | 0 | 3 / 2 |
| Losing moves on the path that are wrong pulls | 9 | 6 | 0 | 0 | 11 |
| Losses that leave a **visible stand-off** at once | 0 % | 0 % | 0 % | **24 %** | 0 % |
| Losing moves hidden from 4-move lookahead | 14 | 18 | 12 | 17 | 11 |
| Expert learners, look 4 / 6 (earlier gates) | 16 / 14 | 13 / 13 | 17 / 18 | 17 / 17 | 5 / 3 |
| Perceptive learner (abandons visible stand-offs at once) | 42 | 22 | 54 | 29 | 19 |
| Winning first moves | 1 / 4 | 2 / 5 | 1 / 4 | 1 / 6 | 2 / 3 |

**Confirmed structural facts:**
- **T5's pulls travel furthest.** A magnet drags another magnet along the whole top row, and that magnet drags a block up a column: 8 cells in all, far from where the magnets sit.
- **E2's pulls are medium-range** (3 + 1 cells).
- **H2's pulls are between neighbours** (1 + 2 cells): the change happens right beside the piece the player is looking at.
- **E1's traps are switch and gate timing.** A quarter of its losing moves immediately leave two arrows facing each other, a pattern the campaign teaches players to read. Its gates also show their counters, and links carry badges, so the dependency graph is drawn on the board.
- **T3 has the same family of mechanics but no visible stand-off losses.** He took 3 restarts on it, against 1 on E1.

**Hypotheses** (consistent with his data, not proven):
- **H-a. Mental simulation of geometry.** For an expert, the cost is in simulating **where things will be** after a pull, and that grows with how far pulls travel and how many chain together. Spinner turns and switch flips are local, visible changes; long pulls are not.
- **H-b. Static readability.** Losses an expert can read off the board (stand-offs, gate counters, link badges) cost him nothing; losses that only appear after an invisible state change cost restarts.
- **H-c. Forced boards feel easier.** E1 is forced from the start (1 of 6 first moves, 896 winning lines all beginning the same way). For an analytical player, a forced opening may be found by elimination rather than insight. H2 is also small (56 winning lines).
- **H-d. Hint-assisted probing.** His restarts on T5 and E2 coincide with using SHOW A MOVE, so restarts may partly measure hint-assisted probing rather than failed reasoning. The logs decide this.

## 5. Why the existing measures failed

- **They count search, not reasoning.** Lookahead and learner measures model a player who searches move sequences. An expert instead reasons about structure: he spots a stand-off or a gate dependency at a glance, which costs him nothing, while those same traps cost the models many dead ends. E1 scored highest on the model learners (17 / 17), yet he found it MEDIUM.
- **They ignore how visible a consequence is.** A trap that is "hidden 12 moves deep" for a model may be obvious to a person if the losing structure is drawn on the board.
- **They ignore the assistance.** None of them models SHOW A MOVE (a solver hint per attempt) or the free lost-check, which together change how a human attacks a hard board.
- **They are calibrated on a single player.** The first tester rated H2 VERY HARD; the expert found it HARD in 33 s.
- **Confirmed contradictions:**
  - E1 has the highest expert-learner scores of the five but was his easiest after H2;
  - P1 has the most wrong-pull traps (14) but was rated MEDIUM by the first tester;
  - H2 has more wrong-pull traps than T5 (11 vs 9) but was easy for him.

## 6. Candidate metrics (to test, not to trust)

| Metric | Definition | Fits his data? | Contradictions |
|---|---|---|---|
| **Pull reach** | Total and longest distance blocks are moved by pulls on the solution | Orders his three magnet boards correctly: T5 8 > E2 4 > H2 3 | First tester: H2 (3) rated VERY HARD, P1 (4) MEDIUM. Says nothing about non-magnet boards. |
| **Visible-loss share** | Share of losing moves that immediately create a static stand-off | E1 (24 %) was easier for him than T3 (0 %) | Only two non-magnet boards; the first tester rated T3 VERY HARD |
| **Hint resistance** (proposed, not yet computed) | Real decisions that remain after the most informative single SHOW A MOVE in an attempt; with refills per restart, how many restart+hint cycles a player needs | To be measured against his logs | — |
| **Logged behaviour** (once the logs arrive) | Distinct losing moves per attempt, repeats, winnable-prefix growth per attempt, hint position | Directly measures learning | Needs several experts |

**Conclusion.** No measure predicts human difficulty on this evidence. Pull reach and visible-loss share are the only candidates consistent with the expert's own ranking, and each is contradicted by another tester. They should be tracked on the next boards, not used as acceptance gates.

## 7. Recommended next concept: "The conveyor" (not built)

**Mechanics.** Magnets (2-3) plus clockwise and counter-clockwise spinners, optionally one armored target. All existing and compatible; magnets are only in levels 76-99 of the campaign, so no new rule.

**Strategic insight.** Magnets whose pull lines **cross**. A block pulled by the first magnet lands in the second magnet's pull line, so the order of pulls decides **which block travels where**. Only one block must make the full journey: a spinner that arrives at the far side facing its exit, or a hammer that arrives facing a shell. Its facing depends on which departures turned it along the way, including the magnets' own.

**Why it should go beyond T5:**
- pulls cover longer distances, and the reach compounds across the crossing (target total reach at least 10 cells, longest at least 4);
- every loss is non-visible: no stand-off traps, gate counters or badges that show the answer;
- the effect of an early choice appears far from where the choice was made.

**Plausible wrong choices with real consequences:**
- the "obvious" magnet first (it carries the wrong block across);
- releasing the travelling spinner at a free moment;
- a neighbour departure that changes its turn count before it is picked up.

**Constraints:**
- at most 12-13 pieces (E2-sized), because at 16 pieces magnet boards broke the mobile budget 3-14 times over;
- a solution of at most 14 taps, with no forced filler.

**How to validate it:**
1. **Build** with the phase-4 method: concept, hand core, refinement only outside the frozen core, pruning, and the idea checked on every winning line.
2. **Machine gates:** all existing gates, plus the new tracking metrics (pull reach, visible-loss share 0 %, hint resistance) **as reports, not gates**.
3. **Bench first:** `&bench=1` on the expert's iPhone before play.
4. **Blind test** with the older son, then at least two more experienced players, alongside T5 as an anchor (as in `?vhval3`). Collect COPY RESULTS from every tester and reconstruct each session with `tools/human_replay.gd`. "Beyond T5" means more distinct losing moves explored and fewer hint-revealed decisions than his T5 run, not just more restarts.
5. **Assistance:** test once with the current SHOW A MOVE; separately, *after a decision by you*, consider an experiment variant where SHOW A MOVE does not refill on RESTART. Assistance limits are unchanged here.

## 8. Bugs and technical risks

1. **The free lost-check reveals unsolvability.** It contradicts the EXTREME brief's "do not warn that a legal move made the board unsolvable", in spirit if not literally. It is a product decision for you; nothing was changed.
2. **The logs miss lost-check presses**, and presses with none left (Section 2). The analysis of human behaviour cannot see them. A dev-only log line for "h0" (a press that spent nothing) would fix this; it is not implemented, because this phase forbids changes.
3. **SHOW A MOVE refills on every RESTART.** This is as documented, but it means restarts and hint use are entangled in every difficulty reading so far.
4. **Unidentified moves.** Rams that two blocks could have made are logged as block -1. The replay stops the attempt there and reports it, rather than guessing.
5. **Timing.** E1 and E2 are heavier than T5 for SHOW A MOVE after a mistake (phase 4 report); this is unchanged.
6. **My own tool error, found and fixed during this analysis.** A ram does not clear the board model's "last pull" record, so my first pull-reach numbers double-counted. The game is unaffected: it reads that record only right after a magnet escape.

## Files (new, development only; nothing else changed)

- `tools/human_replay.gd`: session reconstruction from COPY RESULTS.
- `tools/expert_features.gd`: the candidate features in Section 4.
- `docs/extreme9_analysis.md`: this report.
