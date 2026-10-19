# EXTREME research: Gate 0 failure analysis and five-prototype test (development only)

Branch `claude/elegant-fermat-0jrmxo`, base commit c9a2d88 (Gate 0 pilot). Nothing here touches Production, Supabase, the 300 campaign levels, the Social MVP, Photo / Message Reveal, the live Friend generator, the live difficulty labels, the shared challenge format, progression, currency, lives or tools. Every board and page below is development-only (`?xtest5=1`, switched off in player / QA / Social QA builds by `BuildFlags.dev_pages_off`).

Evidence labels used throughout:
- **Observed**: measured or reported, stated as it is.
- **Hypothesis**: a reasonable explanation that fits what was observed, not proven.
- **Unknown**: what the data cannot tell.

## A. Gate 0 failure analysis

### A.1 What we have

- **Observed (human):** your summary of the primary tester's 28 playthroughs: 0 VERY HARD, 5 HARD (V01, V10, V14, V16, V27), 12 MEDIUM, 11 EASY, 0 give-ups, all solved. V19: MEDIUM, 4 restarts, 11 pushes, ~79 s. V27: HARD, 2 restarts, 8 pushes, ~81 s. V04: MEDIUM, ~26 s. The son solved ~7 boards and rated most of them easy; which boards, and any telemetry, are not available.
- **Not available:** the results JSON (per-move logs, times, UNDO / SHOW A MOVE use, answers to the other questions). It is not in the repository or this container. Nothing below invents those records; questions that need them are marked **Unknown**. Please paste the COPY RESULTS export(s) when convenient: the logs would answer several of them directly.
- **Earlier evidence (observed, docs/vh_human_test*.md):** 92 earlier playthroughs of VERY HARD candidates, 0 rated VERY HARD; SHOW A MOVE unused by the experienced testers in tests 2-3; restarts raise ratings but stopped at HARD; solver / heuristic proxies did not predict ratings.
- **Totals now:** 120 playthroughs of candidate VERY HARD boards by experienced players, 0 rated VERY HARD (observed).

### A.2 New measures (tools/extreme_probe.gd, tools/extreme_analyze.gd)

The Gate 0 generator selected boards with one-attempt proxies: a random tapper and a "heuristic" player (always-safe moves first, then 2-move lookahead), each playing a single game with no memory. People do not play one game: they restart and remember. So three session-level measures were added and run on all 28 boards (scratch output only; the tools are in the repository):

- **Blind learner:** trial and error with memory. Always-safe moves first, risky moves in random order, back up on a dead end, never repeat a failed position. Counted: dead ends before the win.
- **Rule-of-thumb learners:** the same, but ordering its tries by one plausible human rule (escape a spinner as soon as it can go / escape spinners last / turn as few spinners as possible / keep the most moves open), looking 2 moves ahead. "Best rule" = the luckiest of the four: an optimistic model of an experienced player.
- **Greedy single attempts:** safe-first, 2- and 4-move lookahead, fewest spinner turns, most moves kept open; win rate over 120-200 games.

| Board | Rated | Recipe | Best rule: dead ends | Luckiest rule | Blind: dead ends | Best greedy win | Old heuristic win |
|---|---|---|---|---|---|---|---|
| V01 | **HARD** | rotation | 3 | opportunist | 3.5 | 4% | 0% |
| V10 | **HARD** | topology | 0 | fewest turns | 4 | 51% | 3% |
| V14 | **HARD** | remote | 0 | fewest turns | 2 | 100% | 23% |
| V16 | **HARD** | remote | 2 | fewest turns | 3 | 3% | 0% |
| V27 | **HARD** | crate + armor | 9 | opportunist | 9 | 0% | 0% |
| V08 | | crate + spin | 4 | patient | 4.5 | 0% | 0% |
| V09 | | crate | 7 | opportunist | 7 | 0% | 0% |
| V19 | MEDIUM | crate + armor | 5.5 | patient | 10 | 0% | 0% |
| V21 | | topology | 3 | fewest turns | 5 | 9% | 0% |
| V05 | | coupled | 1 | most moves open | 8 | 8% | 3% |
| V18 | | rotation | 1 | most moves open | 12 | 10% | 3% |
| V11 | | coupled | 1 | most moves open | 4 | 1% | 0% |
| the other 16 | EASY / MEDIUM | | 0-1 | (mostly "most moves open") | 0-3 | 1-100% | 0-67% |

(Rated column: only the five HARD boards and V19 are known individually; the rest are MEDIUM or EASY.)

**Observed:**
1. The old proxies were saturated: 14 of 28 boards had a heuristic win rate of ~0-3 %, yet 23 of 28 were rated EASY or MEDIUM. A proxy that says "hard" for almost everything cannot select.
2. A trial-and-error player with memory and one simple rule of thumb solves 21 of the 28 boards with at most 1 dead end. The single most effective rule is "keep the most moves open" (luckiest rule on 10 boards).
3. The boards where every rule of thumb fails at least twice: V01, V16, V27 (HARD) and V08, V09, V19, V21 (not HARD). Three of these seven were rated HARD, against two of the other 21.
4. The crate boards defeat every model (V08, V09, V19: 4-7 dead ends for the luckiest rule, 0 % greedy) and were still rated EASY / MEDIUM. V19 cost 4 restarts and 79 s and was rated MEDIUM.

### A.3 The twelve questions

1. **Why did mechanic-impact scores fail to predict difficulty?** *Hypothesis, supported by A.2:* impact measures how much a mechanic changes the solver's search, i.e. what the board would be without it. That is a property of the board, not of the player's decisions. A mechanic can be essential (the board is unsolvable without it) while the decision it creates is resolved at a glance (for example, a push that is the only way to open a lane). The solver also has no "glance": it pays for every branch that a person dismisses by looking.
2. **Technically necessary but strategically obvious?** *Partly observed:* most mechanic moves on the 28 solutions had a losing alternative available (they were not forced), so they were not obvious in the narrow sense. But A.2 shows the losing alternatives were mostly avoided by a simple rule, so they were obvious to a player with that rule. *Hypothesis:* this applies most to switches (2 of the 5 G1 switch moves were the only risky move on offer) and Sequence advances.
3. **Can safe-move strategies or simple greedy play solve them?** *Observed:* single greedy attempts mostly fail (that was a selection criterion). *Observed:* a greedy rule **plus memory across restarts** solves 21 / 28 with ≤ 1 dead end. That is how people played (restarts, 0 give-ups).
4. **Obvious move order despite looking complex?** *Hypothesis, consistent with 3:* yes, for most boards: one natural ordering rule leads almost straight to the solution. The boards look complex (14-22 blocks, several mechanics) but the decisions are few and local.
5. **How often is real forward planning needed?** *Unknown for people* (no move logs). *Measured proxy:* on 21 / 28 boards, a 2-move lookahead plus one rule needed ≤ 1 backtrack, so planning beyond 2 moves was rarely necessary.
6. **Are mistakes cheap?** *Observed:* solutions are 10-22 taps; V19's 4 restarts took 79 s in total. *Observed (tests 2-3):* ratings rise with restarts but stop at HARD. *Hypothesis:* a mistake costs seconds and teaches the player exactly where they went wrong when the dead end comes soon after it. Cheap and informative failures cap felt difficulty.
7. **Does SHOW A MOVE reduce perceived difficulty?** *Unknown for Gate 0* (usage not in the summary). Earlier experienced testers never used it (tests 2-3). With one per attempt and a free RESTART, a player could use it once per attempt; the logs would show whether that happened.
8. **Do some mechanics simplify decisions?** *Hypothesis:* yes:
   - Portals / Sequence (G3) add reading effort rather than decisions (V10's luckiest rule needs 0 dead ends, yet it was rated HARD: possibly reading load rather than strategy).
   - Gates are passive ("clear its links").
   - Armor is a short forced detour.
   - Crates create many technically losing pushes, but people seem to reason spatially about a crate well enough to avoid them (A.2 item 4).
9. **What distinguishes the five HARD boards?** *Observed, n = 1 tester:* nothing consistent. Three of them (V01, V16, V27) are among the seven that defeat every rule of thumb; two (V10, V14) are among the easiest by every model. V10 and V14 may reflect reading load (portals + Sequence; switch + gate) or an unlucky first attempt. One tester cannot separate these explanations.
10. **Tester expertise or familiarity?** *Observed:* the primary tester has completed all 300 levels and every earlier test; the son has less exposure and found most of his ~7 boards easy. *Hypothesis:* the boards were easy for both levels of experience, which points to the boards, not the testers. *Unknown:* which boards the son played.
11. **Which metrics have predictive value?**
   - *None is validated* with one full tester. On this sample:
     - restarts (tests 2-3) and "every rule of thumb fails" (3 / 7 HARD vs 2 / 21) are the only measures pointing the right way;
     - the old proxies (random tapper, one-attempt heuristic player, impact, trap counts, calm share) showed no relationship, here or in tests 1-3.
   - *Proposal:* demote impact, trap counts, calm share, random / heuristic win rates to **diagnostics** (they still catch broken or trivial boards). Treat the session-level measures as **filters** (necessary, not sufficient): a board that a simple rule plus memory solves is not a candidate. Only people can show sufficiency.
12. **Which dimensions are we failing to measure?**
   - **Spatial reasoning:** people read crate geometry far better than the solver predicts.
   - **Credit assignment:** whether a dead end tells the player which earlier move caused it.
   - **Attempt cost:** taps and seconds per attempt.
   - **Reading load vs decision load:** what is hard to see, as opposed to hard to decide.
   - **Insight:** a single non-obvious idea, as opposed to many small choices.
   - **Rules of thumb people actually use:** we model four; people may use others.

### A.4 Verdict on the hypothesis

"The generator creates complicated boards without genuinely difficult strategic decisions" is **supported for most boards, with a correction**. The decisions existed (most mechanic moves had losing alternatives), but a single natural rule of thumb, plus cheap restarts with memory, resolved them. The crate boards are the exception that also shows its limit: they defeat every model and were still not hard for the tester, so "defeats our models" is not "hard for people". That is the central uncertainty this phase has to test.

## B. EXTREME design standard

A board is a candidate for EXTREME only if, **in this order**:

1. **It is fair.**
   - Every rule is visible and already taught by the campaign (no hidden arrows, no new mechanic).
   - The solution follows from reasoning, not guessing.
   - Every consequence is deterministic and readable on an iPhone SE.
2. **No simple rule plus memory solves it.** A trial-and-error player with memory that orders its tries by any one of the four rules of thumb, looking 2 moves ahead, hits **≥ 3 dead ends** (median), and no single greedy attempt wins **more than 5 %**. These are filters, not evidence of difficulty.
3. **Its mistakes are plausible and late.** At least two losing moves look natural (they are not visibly dead within one move) and play can continue **≥ 4 moves** after them before getting stuck. The player has to work out which earlier move caused the failure, which is what makes restarts expensive in thought rather than in taps.
4. **It is short and uncluttered.**
   - At most 7×7, at most 16 pieces, a solution of at most 22 taps.
   - Difficulty never comes from length, repetition (crate recipe: at most 4 pushes) or reading effort.
5. **Every mechanic matters and is a real decision.**
   - The Gate 0 impact rule (board without the mechanic is easier or unsolvable) stays.
   - The hypothesis's own mechanic must appear in at least one solution step that has a losing alternative.
6. **The technical limits stay where they are:**
   - recipient check within 60,000 nodes;
   - working budget 20,000 nodes;
   - SHOW A MOVE on every solution state and after every losing move;
   - 40 ms native desktop (the Safari / iPhone proxy calibrated in Gate 0).

   Nothing is raised.
7. **It has a written reason.** Why it should be strategically hard, the misleading moves, and which rule of thumb it defeats.

**Design method.** The Gate 0 approach (random boards + hill climbing on solver scores) is replaced by a **hybrid**:
1. The goal of the climb is the standard above.
2. Climbs start from the best of many random boards, or from seed boards (hand-designed motifs, earlier near-misses).
3. Every kept board is then read by hand: its solution and misleading moves are traced and written down (`--dossier`).

Fully hand-authored boards are not ruled out. With the limited time per board in this phase, hand design was used for seeds and selection, and the final boards are machine-verified.

## C. The five prototypes (`data/dev/extreme5.json`)

Ids are neutral (T1-T5, in a seeded random order); testers never see the hypothesis. Cells are named RnCm: row n, column m, counted from 1 at the top-left. Every claim below was traced on the solver's solution and its losing alternatives (`tools/extreme5_build.gd --dossier`).

| Board | Hypothesis | Size / pieces | Mechanics | Solution | Luckiest rule: dead ends | Blind: dead ends | Best greedy win | Old heuristic win | Random win | Distinct late traps | Legal first moves that keep it solvable |
|---|---|---|---|---|---|---|---|---|---|---|---|
| T1 | E1 Long-range dependencies | 6x7 / 15 | spinner_cw, lock, spinner_ccw | 15 taps | 9 | 12 | 3.0% | 0% | 6.2% | 3 | 5 of 6 |
| T2 | E4 Rotation and order | 6x7 / 12 | spinner_cw, spinner_ccw, spinner_alt, sequence | 15 taps | 6 | 8.5 | 3.5% | 3% | 0.0% | 3 | 5 of 7 |
| T3 | E2 Interacting control systems | 7x7 / 14 | spinner_cw, spinner_ccw, switch, gate | 13 taps | 11 | 17 | 2.5% | 3% | 0.0% | 3 | 1 of 4 |
| T4 | E3 Spatial planning | 6x6 / 10 | spinner_cw, crate | 11 taps | 6 | 10 | 0.0% | 0% | 0.0% | 4 | 1 of 5 |
| T5 | E5 Magnet chain | 6x6 / 13 | spinner_cw, magnet | 13 taps | 17 | 17 | 0.0% | 0% | 0.0% | 4 | 1 of 4 |

For comparison, the Gate 0 boards: luckiest rule 0-1 dead ends on 21 of 28, at most 9 (V27). All five prototypes are short (11-15 taps; Gate 0: 10-22) and small (10-15 pieces; Gate 0: up to 22).

### D. Each prototype: the planning challenge, and why simpler strategies should fail

Common ground: an experienced player's simple strategies are (a) play the always-safe moves, (b) take a spinner that can leave now, (c) keep options open, (d) restart and avoid what failed last time. Each prototype is built so that one specific idea defeats these strategies, and so that the failure shows up late (strategy (d) learns slowly).

**T1: E1 long-range dependencies (locks + clockwise / counter-clockwise spinners)**
- **Planning challenge: protect a future state.** The player must work out, at the start, what the locked counter-clockwise spinner R at R2C3 has to look like when its blue lock opens about 10 moves later (pointing left), and avoid every move that changes it before then.
- **Why simpler strategies should fail:**
  - (a) and (b) fail: the plain R at R1C3 is free after move 1 and is the most natural next tap, but leaving it turns the locked spinner to face down column 3, straight at the clockwise spinner R at R6C3, whose only exit is up the same column. The board then has a mutual block.
  - (c) fails: that move opens a lane, so it keeps more options open, not fewer.
  - (d) is slow: the block cannot show until both blue blocks have gone, up to 11 moves later, so the restart does not point at the move that caused it.
- **Other misleading moves:**
  - the free spinner R at R4C5 on move 1 (up to 10 moves before the jam);
  - B at R3C1 leaving down as soon as it can, when it should wait to be turned left (up to 9).

**T3: E2 interacting control systems (two switches + a chain gate)**
- **Planning challenge: schedule remote effects.**
  - Switch A (R at R4C4) reverses three blocks at once. It is free on move 1, but firing it while two or three of them are still on the board always loses (checked exhaustively over all reachable positions). In every winning line it is one of the last five moves. Only 1 of the 4 legal first moves keeps the board solvable.
  - Switch B (Y at R6C4) has a narrow window: after B at R2C6 has left (otherwise B is reversed into the spinner beside it), and before R at R5C2 can leave (R points into a spinner until switch B reverses it).
  - The gate at R6C1 needs both links gone and blocks P's way down, so P at R2C1 must be turned, not released.
- **Why simpler strategies should fail:**
  - (a) and (b) fail: both switches can leave at once and look like the point of the puzzle.
  - (c) fails: firing a switch early opens lanes, so it looks good.
  - (d) is slow: the reversed blocks only matter 8-10 moves later.
- **Misleading moves:**
  - switch A early (up to 10 moves before the jam);
  - the free spinner P at R7C3 (up to 10);
  - switch B first (up to 8).

**T4: E3 spatial planning (one crate + two spinners)**
- **Planning challenge: use a spinner as a tool before it turns.** The crate at R5C2 stands in the only exit column of P at R6C2 and in G's row. Exactly **one** route works (checked exhaustively over every reachable position):
  1. P at R6C2 pushes the crate up to R4C2.
  2. G at R5C3 leaves left through the gap.
  3. The clockwise spinner R at R4C4, **while it still points left**, pushes the crate on into R4C1, out of every remaining lane.

  The spinner has to work as a pusher before it works as a block that turns. Only 1 of the 5 legal first moves (the push by P) keeps the board solvable. Two pushes in total: no repetitive pushing.
- **Why simpler strategies should fail:**
  - (a) and (b) fail: the two blocks next to the spinner that can leave at once (B at R3C4 above it, Y at R4C5 beside it) are the most natural first taps, along empty lanes. Each turns the spinner upward, after which nothing can move the crate out of column 2.
  - "Push only when nothing else is left" fails: the push must come first.
  - (d) is slow: the jam shows up to 11 moves later, at the very end, when P at R6C2 finds its column blocked.
- **Misleading moves:**
  - B at R3C4 on move 1 (up to 11 moves before the jam);
  - Y at R4C5 on move 1 (up to 11);
  - a second push up by P (up to 10);
  - G pushing the crate left into R5C1 on move 1 (up to 8).
- **Caution:** Gate 0's crate boards defeated every model and still felt EASY / MEDIUM. People may see the push at a glance.

**T2: E4 rotation and order (clockwise / counter-clockwise / alternating spinners + Sequence)**
- **Planning challenge: predict a cluster's rotation.** Neighbouring spinners turn in different ways (and the alternating one changes direction every turn), so the order of escapes decides where each one ends up pointing. The player has to simulate several turns ahead in their head.
- The Sequence blocks add **when-it-can-start** conditions: the red one at R1C3 points down column 3 and must wait until the cluster has emptied that column.
- **Why simpler strategies should fail:**
  - (b) fails: both spinners that can leave at once (G at R4C3 down, P at R3C1 left) are wrong at the start, each turning two neighbours of different rules too early.
  - (d) is slow: up to 11 moves before the jam.
  - Misleading moves: G at R4C3 (up to 11); P at R3C1 (up to 10); P at R4C4 up (up to 10).
- **Limitation:** no spinner touches a Sequence block, so the Sequence advances turn nothing here. The "rotation **and** sequence together" idea is only partly realised (see L4 below).

**T5: E5 magnet chain (three magnets + six clockwise spinners)**
- **Planning challenge: simulate a geometry change.** A magnet that leaves drags the first block behind it into its cell, so lanes are created and destroyed. **Every winning line uses the same three pulls in the same order** (checked exhaustively):
  1. Move 1: the yellow magnet at R5C1 leaves down and drags the blue spinner at R4C1 into its place.
  2. Later, the green magnet at R1C5 leaves right and drags the purple magnet from R1C1 along the whole top row. This is only possible once G at R1C2 has left down.
  3. The purple magnet leaves up and drags Y at R4C5 up column 5 into the empty top row, where it leaves left.

  Each magnet pulls whatever is first behind it at that moment, so the order has to be planned before pulling. Only 1 of the 4 legal first moves keeps the board solvable, and the board cannot be solved without magnets.
- **Why simpler strategies should fail:**
  - (a) and (b) fail: both top-row magnets are free on move 1, and either one pulls the wrong block.
  - (c) fails: an early pull often opens lanes.
  - (d) is slow: up to 8 moves before the jam.
- **Misleading moves:**
  - the purple magnet on move 1 (up to 8 moves before the jam);
  - the green magnet on move 1 (up to 7);
  - the free spinner G at R3C2 (up to 7);
  - R at R4C3 as soon as it can leave, which turns the spinner G at R5C3 too early (up to 7).
- **Note:** this board replaces an earlier magnet prototype with the same chain idea. That one was rejected by the stricter timing gate (one of five repeated runs over budget); see Selection.

### D.2 Held-out check: are they hard only for the models they were selected against?

The search optimised the 2-move learners and the five greedy players of `tools/extreme_probe.gd`. Three other measures, **never used in the search or selection** (`tools/extreme_holdout.gd`), were run afterwards on the five prototypes and on the 28 Gate 0 boards:

| Measure (held out) | Prototypes T1-T5 | Gate 0 (28) | Separates? |
|---|---|---|---|
| **Planning depth:** for each losing move, how many moves ahead one must look to see that it is lost (median per board, capped at 10) | 6-10 | 0-9 (26 of 28 boards ≥ 5; V03 has no losing move) | **No** |
| **6-move lookahead player:** single-attempt wins | 0-8 % (T2, T5 8 %) | 0-100 %; 0-13 % on 13 boards | **Weakly** |
| **Stronger learner:** trial and error with memory, "keep moves open", looking 4 moves ahead (dead ends, median) | 7-18 | 0-7 (19 boards ≤ 1) | **Yes** |

Per board (prototypes): T1 depth 9 / look6 5 % / learner 13.5; T2 8 / 8 % / 7.5; T3 7 / 2 % / 17; T4 10 / 0 % / 7; T5 6 / 8 % / 18.

**What this means.**
- **Observed:** the prototypes are not "deeper" than the Gate 0 boards. Gate 0 already had many mistakes that only show 5-9 moves later, and people still found those boards easy. So "you must look far ahead" is not, on its own, what makes a board hard for people. That was one of my own hypotheses, and it is not supported.
- **Observed:** the prototypes differ in that **trial and error with memory does not converge quickly**, even for a stronger, held-out learner. This is the property the human test can confirm or refute.
- **Hypothesis:** people's advantage over our models is recognising structure (which spinner matters, where a crate must go). If the key idea in each prototype is one a person can spot by looking, they will still find it easy, whatever the models say.

### Selection, and what fell short

- **Volume:** 148 searches across the five hypotheses (134 in the first round, 14 in a time-boxed second round for crate and magnet). The final merge re-checked all 20 distinct candidates (E1 2, E2 3, E3 5, E4 2, E5 8) with the final code and kept the best of each hypothesis that passed.
- **Why searches failed:** in most of them a greedy player still won more than 5 % (105 of the first 134; this is the binding gate). The rest failed the phone time budget (crate and magnet boards) or used more than 4 pushes.
- **No gate was relaxed. Two were tightened during the work:**
  1. "At least 2 plausible late losing moves" counted the same move at different steps; it now counts **distinct** moves.
  2. **Mobile time:** the 40 ms native-desktop budget is unchanged, but on this cloud machine a single measurement varies by about 2×. The first crate and magnet prototypes passed once (18-24 ms) and then exceeded 40 ms in 2-3 of 8 repeated runs (up to 48 ms). Acceptance now repeats the whole measurement 5 times and requires **every** run to be within 40 ms, and the search aims for 24 ms (60 % of the budget).
  - Both earlier prototypes were rejected under (2) and replaced by new crate and magnet boards from the second round.
  - Two independent final merges selected the same five boards; every repeated run was 12.6-32.3 ms.
- **E3 (crate)** still has the weakest prior (A.2), even though its new board has a single verified route.

## E. Solver and performance

| Board | Check nodes | SHOW A MOVE max nodes | After a mistake max nodes | 5 repeated runs, worst ms each (native desktop) | x1 check / hint / after-mistake ms | x4 | x6 |
|---|---|---|---|---|---|---|---|
| T1 | 146 | 80 | 98 | 16.4, 22.5, 16.5, 15.5, 18.4 | 19 / 24 / 20 | 49 / 92 / 184 | 98 / 123 / 120 |
| T2 | 145 | 144 | 91 | 27.7, 17.3, 20, 24.8, 20.8 | 10 / 9 / 16 | 53 / 79 / 87 | 142 / 162 / 180 |
| T3 | 53 | 52 | 24 | 14.2, 12.6, 18.3, 13.7, 15.9 | 5 / 4 / 4 | 18 / 16 / 18 | 21 / 25 / 28 |
| T4 | 955 | 955 | 464 | 21.8, 32.3, 21.2, 20.3, 27.4 | 46 / 49 / 23 | 148 / 102 / 165 | 203 / 237 / 181 |
| T5 | 217 | 55 | 17 | 22, 29.4, 17.1, 16.4, 17.3 | 26 / 38 / 3 | 94 / 104 / 9 | 117 / 153 / 17 |

- **Native desktop columns:**
  - Limits unchanged: 60,000-node recipient limit, 20,000-node working budget, 40 ms mobile proxy.
  - SHOW A MOVE is measured on every state of the solution and after every losing move along it.
  - Each "run" is the worst of the check, SHOW A MOVE and SHOW A MOVE after a mistake.
  - Node counts are exact and repeatable; milliseconds vary with the machine.
- **×1 / ×4 / ×6 columns:**
  - The WebAssembly build in Chromium with CPU throttling, at iPhone SE size, on the same machine. These are **simulations, not iPhone measurements**.
  - Worst ×4: 184 ms. The Gate 0 pilot measured in the same session on the same machine: worst ×4 256 ms, ×6 385 ms. The prototypes are lighter than the board set people already played without reported slowness.
  - Absolute values were about 2× higher in this session than in the previous one (Gate 0 ×4 230 ms then, 256 ms now; the ×1 worst rose from ~24 to 46 ms).
- **Still needed:** real Safari / iPhone timing (`?xtest5=1&bench=1`) before testers start.

## F. Test interface (`?xtest5=1`, development builds only)

Same page and flow as the Gate 0 pilot (`scripts/social/vh_human_test.gd`), with:
- **Order:** the campaign-progress question, then the eligible prototypes in a random per-device order (hypotheses hidden).
- **Before each puzzle:** a neutral one-line rules reminder (new: Magnet).
- **While playing:**
  - The clock, GIVE UP (two taps), UNDO ×3 / SHOW A MOVE ×1 / HAMMER ×0 (the live VERY HARD tools) and RESTART.
  - **No difficulty label on the play screen** (it said VERY HARD in Gate 0; now blank to avoid anchoring the rating).
- **After each puzzle:**
  1. Difficulty: EASY / MEDIUM / HARD / VERY HARD / **EXTREME**.
  2. Compared with Level 300.
  3. Enjoyment 1-5.
  4. Achievement 1-5.
  5. Fairness: YES / MOSTLY / NO.
  6. Needed real planning: YES / A LITTLE / NO.
- **At the end:** the hardest puzzle and why.
- **Measured:**
  - Time, first-move time, restarts, UNDO, SHOW A MOVE, give-ups.
  - **Blocked taps** (new, logged as "b").
  - Pushes, Sequence advances, magnet pulls.
  - A timed log of every action with the tapped block (the move sequences).
- **Storage:** its own local file and storage key. COPY RESULTS exports JSON.
- **`&bench=1`:** times the recipient check, SHOW A MOVE, and SHOW A MOVE after a mistake on every board on the device.
- **Fixed during this phase (also affects `?vhtest4=1`):** GIVE UP and the clock moved into the play screen's top bar (top right). On 7-row boards they used to sit over the board's top row; the Gate 0 pilot's 6x7 boards would have had the same overlap. Both tests now check that they end above the board, for every prototype, at iPhone SE size.

## G. Automated validation and regression

All run on the final board file and the final dev build.

| Test | Result |
|---|---|
| `tools/Extreme5Check.tscn` (new). Covers: board file; every board played to the end in the real play screen, with the tapped block inferred; duplicates; budgets, including all 5 repeated timing runs; written explanations; page flow; blocked-tap log; five-step rating and questions; reload; results; bench; GIVE UP / clock above the board on every board | 146 / 146 |
| `tools/web_xtest5_page_test.mjs` (new). Covers: iPhone SE size, real touches, all five prototypes, give-up and solve, EXTREME rating, storage, no page errors, no network, bench ×1/×4/×6 | 19 / 19 |
| VhPilot4Check (Gate 0 page) | 442 / 442 |
| VhHumanTestCheck (tests 1-3) | 100 / 100 |
| web_vhtest4_page_test / web_vhtest_page_test | 14 / 14, 17 / 17 |
| RevealMvpTest, FriendFlowTest (149), SocialPlayTest | passed |
| Exhaustive position checks (scratch scripts, not kept), over every reachable position of the board | first-move counts (all five); T3 switch timing; T4 single crate route; T5 single pull sequence |

The pilot check's count varies by one or two between runs, because its page-flow part checks the reminders of whichever board comes first in a random order.

Dev build: `build/dev_qa/chain_escape_dev_extreme5.zip` (git-ignored, not uploaded), 13,087,796 bytes, SHA-256 `ff8bce86cd025044f91147e7a1b07f224d951858073ebae9804262bac4394c87`, exported with the "Web" developer preset. Open `index.html?xtest5=1` (timing: `&bench=1`). It replaces the earlier ZIP (`00fa7412…`), which had the two rejected boards.

## H. Which combinations merit further testing

- **Magnet (T5): the most promising on paper.**
  - In the campaign: essential in 21 of 22 levels, cheap to solve, and it changes geometry, which people must simulate rather than read.
  - In the models: the strongest result of this phase (17 dead ends for the luckiest rule, 0 % for every single-attempt greedy player, 18 for the held-out 4-move learner). Every winning line uses the same three pulls in the same order.
  - Constraints: no portals, crates or hidden arrows on a magnet board.
  - Risks: pulls that move a block far away may feel surprising rather than clever. Ask "fair?" carefully.
- **Switch / gate (T3): promising.**
  - Gate 0 already had 2 of its 5 HARD ratings in this group.
  - The new board turns the switch from an obvious tool into a timing problem: the switch that is free from move 1 must wait until at most one of its three targets remains. Only 1 of 4 first moves keeps the board solvable.
- **Locks with mixed spinner rules (T1): plausible.** The long-range idea is clean; the risk is that experienced players read lock colours very quickly.
- **Movable crate (T4): lowest confidence, but the cleanest single idea.**
  - Gate 0's crate boards defeated every model and still felt EASY / MEDIUM. This board needs only 2 pushes and has exactly one verified route; the whole puzzle is one idea (use the spinner as a pusher before it turns). The prior is still weak.
  - Crate + several spinners does not fit the phone budget.
- **Rotation + Sequence (T2): the hypothesis is only partly realised** (Sequence acts through its lane condition, not its turning). A hand-designed version with a Sequence block next to spinners would test it properly.
- **Twins:** not used (Gate 0 assessment: usually removes a decision rather than adding one).

## I. Next human experiment

1. **Real iPhone first:** open `index.html?xtest5=1&bench=1` in Safari once and send the numbers. Gate: no board above ~300 ms.
2. **Testers:** at least 2 experienced players per board, all past level 251, so every prototype is offered. Ideally 3-4: the primary tester, the son, and one or two who have not seen any earlier test board.
3. **Before testing, decide what would count as EXTREME** (pre-registration, as in test 3). Suggested:
   - for a board: ≥ 2 of its experienced testers rate it VERY HARD or EXTREME, ≥ 1 rates it EXTREME, and no "NO" on fairness;
   - for the hypothesis: the same board also rated "harder than Level 300".
   - Not counted as success: long times or many restarts on their own (frustration is not the target).
4. **Read the logs, not only the ratings:**
   - Did the first restart come after one of the documented misleading moves?
   - How long were the pauses before the key move?
   - Which rule of thumb does each tester seem to follow?

   This is the evidence we lacked in Gate 0.
5. **Paste the Gate 0 COPY RESULTS export(s) too:** they would let us check A.3 items 5-7 retrospectively.
6. **Afterwards:**
   - If one hypothesis clearly works: hand-design 2-3 more boards of that kind, ideally with you, before any generator.
   - If none does: the evidence points away from board difficulty within the 13-15-tap format and toward changes to the format itself. That needs your decision, for example scoring (fewest restarts), a move budget, or no-UNDO challenges.

## J. Files

**New (development only):**
- `tools/extreme_probe.gd`: session-level play models (learners with memory and rules of thumb, greedy players, choice structure, misleading moves).
- `tools/extreme_analyze.gd`: Phase A analysis of any board file.
- `tools/extreme_holdout.gd`: the held-out measures of D.2 (planning depth, 6-move lookahead player, 4-move learner), never used for selection.
- `tools/extreme5_build.gd`: the hybrid builder. It extends the unchanged Gate 0 builder and adds searches, `--seeds`, `--merge` (copies the notes by board fingerprint), `--dossier`, and the 5-run timing gate.
- `tools/extreme5_check.gd`, `tools/Extreme5Check.tscn`: end-to-end check.
- `tools/web_xtest5_page_test.mjs`: browser test + bench.
- `data/dev/extreme5.json`: the five prototypes with full measurements.
- `data/dev/extreme5_notes.json`: the hand-written explanations.
- `docs/extreme5.md`: this report.

**Modified (development only):** `scripts/social/vh_human_test.gd`. Changes:
- the `?xtest5=1` test (five-step rating, new questions, blocked-tap log, Magnet parsing on this page, no difficulty label);
- GIVE UP and the clock moved into the top bar for the pilot pages;
- answer-button names without spaces (`Think_A_LITTLE`, `Think_NOT_SURE`).

Tests 1-3 and the Gate 0 page behave as before apart from the HUD position.

**Untouched:** Production, Supabase, the 300 campaign levels, the Social MVP, Photo / Message Reveal, the live Friend generator, the live difficulty labels, the shared challenge format, progression, currency, lives, tools, and every solver or game rule. No budget was raised.

## K. Unresolved limitations

- **L1. No human evidence yet.** Every difficulty claim here is a model claim. Gate 0 showed models can call a board hard while people find it easy (the crate boards). Until people play them, these are five hypotheses, not five EXTREME puzzles.
- **L2. Partly circular selection.** Boards were chosen to beat the models they are measured with. The held-out check (D.2) reduces the concern for one property (slow trial-and-error convergence) but shows the prototypes are no "deeper" than Gate 0 boards.
- **L3. Human strategy is unmodelled.** Four rules of thumb plus lookahead do not cover pattern recognition, counting arguments or spatial intuition. That is where people beat the models in Gate 0.
- **L4. E4 is only partly realised.** Sequence blocks act through their lane condition only; none touches a spinner. A hand-designed variant is needed to test "rotation and sequence together".
- **L5. Crate prior is weak.** Gate 0's crate boards felt easy despite the models. T4 has a single verified route but one idea; people may see it at a glance.
- **L6. Machine-searched, hand-explained.** The boards come from the hybrid search, not from hand design. The explanations were written afterwards from traced solutions. A fully hand-authored board might carry a cleaner single idea.
- **L7. Phone timing is simulated, and the machine is noisy.**
  - Native timings on these cloud machines vary about 2× between runs and between sessions. The acceptance gate now requires every one of 5 repeated runs within budget, and the prototypes are lighter than Gate 0 on the same machine.
  - Real Safari timing (`&bench=1`) is still outstanding. T4 (crate, 955 nodes) and T5 (magnet, whose position includes every block's cell) are the boards to watch.
- **L8. Corrected overstatements.** An exhaustive check of every reachable position found two claims in my first explanations too strong:
  - T3's switch A is not always the last move. It must wait until at most one of its three targets remains; firing it with two or three still on the board always loses.
  - The first crate prototype had two routes, not one. That board was later replaced; the new T4's single route is verified.

  The key ideas of T3, T4 and T5 are now verified exhaustively. T1 and T2 were traced on the solver's solution and its losing alternatives, not proven unique. On those two the opening is forgiving (5 of 6 and 5 of 7 first moves keep the board solvable) and the traps come later.
- **L9. Small sample planned.** Two experienced testers per board can reveal a clear failure, but cannot establish EXTREME for the product. More independent testers are needed before any integration.
- **L10. Not designed against one model only, but still model-selected.** The search goal combined the 2-move learners and the greedy players. Acceptance added the Gate 0 technical rules, the mechanic-impact rule, distinct late traps, readability and repeated timing. The held-out measures (D.2) were never used. Even so, every board was found by a search, so whatever the models miss about people, these boards may miss too.
