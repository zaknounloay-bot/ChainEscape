# EXTREME Time Attack — Phase 23: new logical cores

Development only. Production, Supabase, the 300 frozen levels, saves /
progression, campaign timing and Personal Best, the approved 120-second Time
Attack baseline, global timing rules, the Social MVP and Challenge a Friend
are untouched. No new mechanic, feature or UI; **no game script changed in
Phase 23** (only `tools/` and `data/dev/`, plus this report).

**Outcome in one line:** five new logical cores were designed and searched
within a budget fixed in advance (15 runs, 2 full reports). **No board
qualified**, so there is no N52 and no Phase 23 testing page (see E). The
phase did produce: the Phase 22 human results recorded, a TIME UP dead-end
check (no defect found), a fix for the phase-aliased ttime pulse check,
validated 6 / 6, a difficulty-prediction study over 29 rated boards, and a
core-preservation check for future generation.

## A. Git

- Branch `claude/elegant-fermat-0jrmxo`; at the start, HEAD `9c3d8b6`
  (Phase 22, local only); `origin` at `cce092a`, a direct ancestor.
- As the brief authorised, a normal push (no force) moved `origin`
  `cce092a → 9c3d8b6`; `git ls-remote` confirms `9c3d8b6afef6…`.
  **Phase 22 is backed up.**
- Phase 23 is one local commit on top of `9c3d8b6` (hash in the final
  report). **It is not pushed**, because the brief authorised only the
  Phase 22 backup.

## Phase 22 human results — recorded

`data/dev/extreme90_p22/human_p22.json` holds both sessions exactly as given.
The brief does not establish that the two sessions were independent testers,
so they are recorded as two sessions, not two independent evaluations.

| Board | Session 1 | Session 2 | Decision (brief) |
|---|---|---|---|
| N48 | EXTREME, TIME UP, 4 attempts | VERY HARD, GAVE UP ~86.7 s, 3 attempts | strong provisional |
| N49 | VERY HARD, ~79.5 s, 2 attempts | VERY HARD, TIME UP (dead end, STOPPED), 5 attempts | strong provisional |
| N50 | EASY, ~25.4 s, 1 attempt | HARD, ~25.2 s, 1 attempt | **downgraded** |
| N51 | EXTREME, TIME UP, 3 attempts | VERY HARD, TIME UP (dead end, STOPPED), 3 attempts | strong provisional |

**Similarity checks the brief asked for:**
- **N48 vs N39:** overlap 0.39, the closest bank board to N48.
- **N51 vs N37:** overlap 0.36, the closest to N51.

Both pairs pass the < 0.40 rule. Each pair, however, comes from **the same
core**: the records carry the same core description ("the magnet brings the
rammer"; "the crate travels"). They are geometric variants of one idea, not
two ideas. If both boards of a pair are approved, counting them as two
distinct puzzles toward 50 is a product decision this report does not make.

None of N48, N49 or N51 is labelled fully human-validated EXTREME.

## B. Why the 24 earlier cores are saturated

1. **The bank already restates them.** The Phase 21–22 boards N39–N51 came
   from the 24 cores. Twelve of those 13 boards carry a core description
   identical or nearly identical to an earlier board's:

   | New board | Earlier board with the same core |
   |---|---|
   | N39, N48 | N32 |
   | N40 | N34 |
   | N42 | N20 |
   | N43 | N14 |
   | N45 | N21 |
   | N46 | N31 |
   | N47 | N24 |
   | N50 | N35 |
   | N51 | N37 |
   | N41 | N38 (closely) |
   | N49 | N37 (closely) |

   Only N44 (the Sequence pusher) is a separate idea.
2. **The geometry is saturated too.** In Phase 22, 55 of 69 candidates died
   at the overlap pre-filter (≥ 0.40 with a bank board) before any report.
   Two more seeds per core mostly re-found the same boards.
3. **The cores are local and one-stage**:
   - a switch-timing order (switch is in about 10 of the 24 cores)
   - one push
   - ram-turn-ram
   - a magnet delivering a rammer
   - spinner turn counting
   - a Sequence advance

   Phase 20 showed what follows from that. Only one risky move is usually
   open at a time, and monotone mechanics (gate, lock, portal, plain block)
   cannot create a losing move on their own. Every board of a core therefore
   tends to have the same few losing moves.
4. **The human results fit this weakly.**
   - Rated easy: N41 and N50 (local ram-turn-ram; N50 restates N35), and
     N46 (a magnet pull, like N31).
   - Rated hard: N48 and N51, whose consequences land far from the move:
     a magnet relocates a block, or a crate crosses a portal.

   This is a hypothesis, not a finding: about 2 sessions per board.

## C. The five Phase 23 cores (`data/dev/extreme90_p23/core_probe.json`)

Every core is new to the generator; none of the 24 earlier cores was used.
Each core's cells are frozen in its seed (`seed_<key>.json`). Two cores were
broken as first drafted and were corrected **before any search ran**:
- **K2:** both portals were in one column. The portal rules reject that as a
  looping lane, so the core was unsolvable. The entry portal moved r1c4 →
  r1c3.
- **K3:** the token `G<=+C` was malformed; the parser's order is link before
  shell, so it is now `G<+C=`.

Probe of the bare cores (`tools/ta90_diag20.gd`, `core_diag.json`):

| Core | Positions | Solution length | Losing moves |
|---|---|---|---|
| K1 | 20 | 6 | 4 |
| K2 | 6 | 4 | 1 |
| K3 | 16 | 8 | 1 |
| K4 | 17 | 5 | 2 |
| K5 | 18 | 5 | 2 |

Every core has a real trap. Every core is far below EXTREME on its own; the
generator must add the rest.

### K1_LASTRAM — "the last ram"

1. **Name and id:** K1_LASTRAM, family *lastram*.
2. **Mechanics:** armor and switch (`&A` flip targets, the `%A` switch).
3. **Reasoning challenge:** sort two kinds of flip target around one
   reversal.
   - R (r0c3) is the only block that can crack G's shell (r3c3), so it must
     stay until the reversal.
   - Y (r5c1) must leave *before* the reversal, or it turns face to face
     with P.
4. **Why it differs:** earlier switch cores (N1, N20, N42) ask one target to
   leave before or after a firing. Earlier ram cores (N6, N38, N41) ask the
   rammer to stay. K1 puts opposite demands on two targets of the *same*
   switch.
5. **Critical dependency or trap:** R is the sole cracker, and its free
   escape is legal from the start.
6. **How a player fails:** taking R's free exit, which leaves the shell
   stranded; or firing the switch with Y still there, which deadlocks it
   face to face with P.
7. **Why safe moves are insufficient:** the "safe" move is exactly the trap.
   A free exit looks like progress.
8. **Expected performance:** a calm-looking losing move. In the search,
   best distinct mistakes = 2 in all 3 runs; it never qualified.
9. **Closest existing puzzles:** N6, N1, N20, N38, N41.
10. **Risk of artificial difficulty:** low in the core. The danger is in the
    padding: reaching 4 distinct mistakes needs added blocks that the core
    does not motivate.

### K2_PORTALRAM — "crack across the board"

1. **Name and id:** K2_PORTALRAM, family *portalram*.
2. **Mechanics:** portal, armor, switch.
3. **Reasoning challenge:** a remote crack.
   - After the reversal, B's lane (r1c1) enters the portal at r1c3.
   - It exits at r4c4 and meets Y's shell at r4c5, on the far side of the
     board.
   - B is the only cracker and may simply leave first.
4. **Why it differs:** the bank uses portals only for a spinner's lane (N34,
   N40) or a travelling crate (N37, N49, N51). No board cracks a shell
   through a portal.
5. **Critical dependency or trap:** B's early exit to the left, and anything
   placed in the lane on the far side.
6. **How a player fails:** B leaves before the switch (G r6c0) fires; or a
   far-side block that should have waited leaves first.
7. **Why safe moves are insufficient:** B's exit is free and nothing near B
   shows the shell it is needed for.
8. **Expected performance:** in round 1 (seed 21), 2 qualifying boards
   (one cluster). Its candidate kept the core (the losing move `r1c1<` is
   among its mistakes) but was rejected for filler. No later run
   qualified.
9. **Closest existing puzzles:** N34, N40, N37, N51 (portal); N6 (ram).
10. **Risk of artificial difficulty:** moderate. Part of the difficulty is
    *seeing* a lane through a portal, which is a visual difficulty rather
    than a logical one.

### K3_RELAY — "a five-stage relay"

1. **Name and id:** K3_RELAY, family *relay*.
2. **Mechanics:** armor, gate, lock, plus a spinner.
3. **Reasoning challenge:** a relay across the board.
   - Y leaves, which turns the spinner R (r0c1) onto shell 1 (G r3c1).
   - Shell 1 is the gate's only link.
   - The gate opens, and B reaches shell 2 (P r3c2).
   - P is the key of the locked Y (r5c5).
4. **Why it differs:** it is the longest dependency chain designed so far.
   N16 has two stages (reverse → ram → open).
5. **Critical dependency or trap:** R is the only cracker of shell 1, and R
   can leave to the right at the start.
6. **How a player fails:** R leaves first.
7. **Why safe moves are insufficient:** in practice they *are* sufficient.
   Once R's escape is avoided, every later stage is forced. The search found
   greedy shortcut 100% and at most 2 distinct mistakes. This is exactly
   Phase 20's finding that gates, locks and other monotone mechanics cannot
   create losing moves.
8. **Expected performance:** long, but not hard. It never qualified.
9. **Closest existing puzzles:** N16, N2, N15, N10.
10. **Risk of artificial difficulty:** **high**. Length without decisions.

### K4_TOGGLE — "ram between two firings"

1. **Name and id:** K4_TOGGLE, family *lastram*.
2. **Mechanics:** armor, switch.
3. **Reasoning challenge:** two switch pieces (P r6c0, Y r6c4) flip the
   same rammer R (r1c5). The first firing aims R at the shell (G r1c6); the
   second aims it away again. R must ram between the two firings.
4. **Why it differs:** N20 and N42 ("between two switches") time an
   *escape*. K4 times a *ram*, and leaving early loses the shell for good.
5. **Critical dependency or trap:** R is the sole cracker; firing both
   switches before ramming loses; R's free escape loses.
6. **How a player fails:** R escapes, or the player fires both switches.
7. **Why safe moves are insufficient:** R's free exit again.
8. **Expected performance:** the only productive core.
   - **Seed 22:** 519 qualifying boards.
     - Its top cluster **bypassed the core** (rejected; see D).
     - 343 of the 519 keep the core, but their two best candidates overlap
       N49 (0.42) and N32 (0.43).
   - **Seeds 21 and 23:** 0 qualifying.
9. **Closest existing puzzles:** N20, N42, N41, N38.
10. **Risk of artificial difficulty:** moderate.

### K5_SPINCOUNT — "count the turns"

1. **Name and id:** K5_SPINCOUNT, family *spincount*.
2. **Mechanics:** armor (the cracker is a plain clockwise spinner).
3. **Reasoning challenge:** R (r2c3) is the only cracker of G's shell
   (r2c6), and it may leave at the start. Each neighbour that leaves turns
   R one step: exactly one departure aims it at the shell, and a second
   turns it past.
4. **Why it differs:** **it barely does.** On review it is close in concept
   to N12 ("count the turns: an alternating spinner faces the shell only
   after an odd number of turns"), and also to N2 and N17. It is flagged as
   conceptually near-duplicate, not as a new idea.
5. **Critical dependency or trap:** R's early exit, or a second departure
   before the ram.
6. **How a player fails:** a second neighbour leaves too early.
7. **Why safe moves are insufficient:** each turn is a side effect of an
   otherwise free departure.
8. **Expected performance:** best distinct mistakes 3, shortcut 22–32%;
   never qualified.
9. **Closest existing puzzles:** N12, N2, N17, N4.
10. **Risk of artificial difficulty:** low, but the risk of conceptual
    duplication is high.

## D. Generation statistics (`data/dev/extreme90_p23/protocol.json`)

**Budget, fixed before any run:**
- **Round 1:** every core with seed 21.
- **Round 2:** every core with seed 22.
- **Round 3:** seed 23, only for cores with no accepted board, and only if
  fewer than 5 boards were accepted.
- **Settings:** `--ops=v20`, 12 min per run, batch 40, beam 5, patience 8;
  at most 20 full reports.

**Why this budget, and not Phase 22's 48 runs:** those runs mostly hit the
bank-overlap wall of old cores. New cores raise a different question: do
they qualify at all? Two seeds per core answer that, plus at most one more
seed for a core that fails. Spent: **15 runs, 2 full reports.**

| Core | Seed | Qualifying | Rounds | Evaluated | Seconds | Best score | Best distinct | Best steps | Shortcut |
|---|---|---|---|---|---|---|---|---|---|
| K1_LASTRAM | 21 | 0 | 22 | 776 | 181 | 132.7 | 2 | 15 | 18% |
| K1_LASTRAM | 22 | 0 | 29 | 954 | 193 | 133.0 | 2 | 15 | 18% |
| K1_LASTRAM | 23 | 0 | 30 | 1026 | 207 | 132.0 | 2 | 15 | 15% |
| K2_PORTALRAM | 21 | 2 | 43 | 1375 | 458 | 140.8 | 3 | 14 | 0% |
| K2_PORTALRAM | 22 | 0 | 64 | 1941 | 546 | 138.7 | 2 | 15 | 8% |
| K2_PORTALRAM | 23 | 0 | 37 | 1249 | 281 | 139.3 | 2 | 15 | 18% |
| K3_RELAY | 21 | 0 | 28 | 982 | 251 | 58.2 | 1 | 13 | 100% |
| K3_RELAY | 22 | 0 | 20 | 678 | 176 | 87.0 | 2 | 7 | 22% |
| K3_RELAY | 23 | 0 | 32 | 1026 | 163 | 57.9 | 1 | 16 | 100% |
| K4_TOGGLE | 21 | 0 | 36 | 1208 | 277 | 136.1 | 2 | 16 | 8% |
| K4_TOGGLE | 22 | **519** | 49 | 1586 | 354 | 140.6 | 4 | 16 | 5% |
| K4_TOGGLE | 23 | 0 | 41 | 1377 | 342 | 132.5 | 2 | 15 | 18% |
| K5_SPINCOUNT | 21 | 0 | 41 | 1294 | 230 | 120.1 | 2 | 15 | 22% |
| K5_SPINCOUNT | 22 | 0 | 28 | 949 | 163 | 118.1 | 3 | 14 | 32% |
| K5_SPINCOUNT | 23 | 0 | 33 | 1073 | 179 | 120.0 | 3 | 15 | 28% |

The "best" columns come from each run's last log line, which is the
best-scoring board even when it does not qualify. Every run stopped on
patience (no improvement for 8 rounds) well before its 12 minutes.

**Every stage-2 candidate and decision** (`stage2_state.json`):

| Candidate | Stage | Decision | Why |
|---|---|---|---|
| K2_PORTALRAM_s21_1 | report | rejected | A and B pass (HUMAN-REVIEW CANDIDATE), and every mechanic is essential. But the filler check found 1 trivial removal (`r2c1 P^`). |
| K4_TOGGLE_s22_2 | pre-filter | dropped | overlap 0.41 with N38 |
| K4_TOGGLE_s22_1 | report → core check | **rejected** | A and B pass, every mechanic is essential, 0 filler. But **the core dependency is bypassed**: the core's rammer R r1c5 leaves at step 3 of the Solver's line before any switch fires, and the core shell is cracked by an added block (G r3c6). It is a switch-timing / ram board of the N38 / N41 kind (overlap 0.39 with N32). |
| K4_TOGGLE_s22c_1 | pre-filter | dropped | overlap 0.42 with N49 |
| K4_TOGGLE_s22c_2 | pre-filter | dropped | overlap 0.43 with N32 |

**One protocol amendment, made after seeing results and recorded in
`protocol.json` ("amendments"):**
- **Trigger:** after the bypass, `tools/ta90_corecheck.gd` (new) checked all
  519 qualifying K4 boards. **343 keep the core**, defined as: the core
  rammer rams on the line, and leaving with it is a distinct losing move.
  Picking by score alone had selected one of the 176 that do not.
- **Change:** rule 5 (the core must survive) is applied *before*
  candidate selection.
- **Unchanged:** no threshold, no search run, the 2-cluster limit, the
  20-report limit.
- **Result:** both selected candidates died at the pre-filter, so the
  amendment produced nothing.
- **Bookkeeping:** stage 2 was rerun for seed 22 under the amendment. That
  overwrote `stage2_round_s22.json`, so the original seed-22 pool (s22_1,
  s22_2) survives only in `stage2_state.json`: the rejected board's record
  and the log.

**Why the new cores fail — the main finding of this phase:**
- Category B needs at least 4 distinct mistakes. A core built around one
  critical dependency supplies 1–2 losing moves.
- The generator makes up the rest with added blocks. Its cheapest routes
  are either geometry that recreates bank boards (K4's core-keeping
  candidates at 0.42 / 0.43) or a second cracker that removes the core's
  trap (K4_TOGGLE_s22_1).
- A relay of monotone stages (K3) adds length, not decisions.

New cores therefore need **two or more interacting critical dependencies
designed in by hand**, not one dependency plus generated padding. This is a
recommendation for the next phase, which has not been started.

## E. Candidates from N52

**None.** No board passed every rule, so no record from N52 on was created,
nothing was added to `BOARDS90`, and no existing candidate was renumbered or
modified.

The **Phase 23 testing page was not built**. The brief asks for a page with
only the new candidates, and there are none. An empty page would add risk
(a new query parameter, storage key and build id) with nothing to test. For
the same reason there is no new ZIP.

## F. Per-candidate metrics (the reported candidates, none accepted)

| Candidate | Positions | Solution | Solve | TIME UP worst | Distinct | Steps | Coverage | Shortcut | Look-6 greedy | Learner dead ends (look-4 / look-6) | Mistakes | Without |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| K2_PORTALRAM_s21_1 | 461 | 17 | 12 ms | 6.2 ms | 4 | 13 | 0.76 | 0.017 | 0.025 | 3 / 3 | r1c1< r1c6> r5c5> r6c0v | portal: unsolvable; switch: unsolvable; armor: 0 / 0 |
| K4_TOGGLE_s22_1 | 399 | 19 | 2.1 ms | 1.4 ms | 4 | 16 | 0.84 | 0.05 | 0.158 | 2 / 0 | r6c0v r6c4v r3c4^ r3c5> | switch: unsolvable; armor: 0 / 0 |

## G. Reasoning diversity

The five cores were chosen to pull away from local, one-stage cores:
- a remote consequence (K2);
- a multi-stage relay (K3);
- opposite demands within one switch group (K1);
- a reversible aim (K4);
- turn counting (K5, which turned out close to N12).

None survived, so the bank's reasoning diversity is unchanged by Phase 23.
The one board that passed every numeric rule (K4_TOGGLE_s22_1) was rejected
precisely because its reasoning was *not* the new one.

## H. Comparison to existing puzzles

- **Conceptual closeness of the cores:** listed in C, items 9.
- **Geometric overlap of the stage-2 candidates:**
  - K2_s21_1: 0.38 (N41)
  - K4_s22_1: 0.39 (N32)
  - K4_s22_2: 0.41 (N38)
  - K4_s22c_1: 0.42 (N49)
  - K4_s22c_2: 0.43 (N32)
- **Bank pairs:** N48 / N39 (0.39) and N51 / N37 (0.36) pass the geometric
  rule but share their core (see the Phase 22 section).

## I. Difficulty-prediction study (diagnostic only — no new cutoff)

**Data:**
- `human_ratings.json`: 29 boards with at least one rating, scored EASY 0,
  MEDIUM 1, HARD 2, VERY HARD 3, EXTREME 4, and averaged per board.
- The 7 boards rated only "promising" in P21 (N39, N40, N42, N43, N44, N45,
  N47) are listed, not scored.

**Features:** `tools/ta90_humanfit.gd`, giving 18 per board
(`humanfit_features.json`), along the Solver's line and the full position
graph. They cover:
- safe-move shortcuts (calm prefix, safe share)
- greedy and look-ahead players
- trial-and-error recovery (learner dead ends; losing moves that show within
  3 moves, so UNDO fixes them)
- delayed failures (trap delay, deep traps)
- effective decisions (steps with ≥ 2 risky legal moves, one of which loses)
- concurrency, length and size

**Spearman ρ with the mean human rating (n = 29):**

| Feature | ρ |
|---|---|
| effective_decisions | **+0.55** |
| concurrency | +0.45 |
| steps | +0.43 |
| solution | +0.41 |
| positions | +0.36 |
| trap_delay | +0.35 |
| learner6 | +0.28 |
| undo_proof | +0.26 |
| learner4 | +0.23 |
| pieces | +0.19 |
| coverage | +0.16 |
| calm_prefix | −0.01 |
| distinct | −0.05 |
| safe_share | −0.06 |
| deep_traps | −0.11 |
| quick_fail_share | −0.26 |
| shortcut | −0.31 |
| look6 | **−0.43** |

**Is it signal?**
- **Multiple comparisons:** with 18 features and 29 boards, a shuffle test
  (2000 permutations) gives P(max |ρ| ≥ 0.55) = 0.03 and
  P(max |ρ| ≥ 0.43) = 0.25. Only effective_decisions clears the bar;
  concurrency, steps and look-6 are not distinguishable from chance on this
  sample.
- **Confounding:** effective_decisions correlates with solution length
  (ρ 0.75), and per step (effective / solution) its ρ falls to 0.33. Part of
  the signal is "longer boards with more forks".
- **Stability:** ρ = 0.61 on N14–N34 (21 boards) and 0.40 on N35–N51
  (8 boards). Look-6 greedy is strong on the recent boards (−0.74) and weak
  on the older ones (−0.26).

**The mismatched boards:**
- **N50 (EASY / HARD):** the largest safe-move shortcut in the set. Its
  calm prefix is 10 of 18 moves (share 0.56), with look-6 0.25. A player can
  make half the board's moves with no risk, and the remaining forks are few
  (12 effective decisions).
- **N41 (EASY):** look-6 0.31 (the highest), safe share 0.24.
- **N46 (MEDIUM):** **not explained.** It has 15 effective decisions,
  look-6 0, and 16 / 16 learner dead ends. Every feature calls it hard, so
  it is a false positive of every screen here. A plausible reading is that
  its magnet pulls are easy to read once seen, so dead ends are recognised
  at once; no feature measures that.
- **N48, N51 (E / VH):** high calm prefix (4), yet rated hard. Their effects
  are remote (a magnet relocation; a crate through a portal). So the safe
  share does not predict easy on its own (ρ −0.06).
- **N49 (VH / VH):** 19 effective decisions, consistent with the
  correlation.

**Retrospective screen, illustrative only and NOT adopted:**
"effective_decisions ≥ 13" would have kept 15 of the 18 boards rated ≥ 3.
- **Misses (false negatives):** N16, N23, N35, all at 12.
- **Kept but rated ≤ 1 (false positives):** 2 of 9, N25 and N46, both at 15.

A screen "look-6 ≥ 0.25 or safe share ≥ 0.5" flags N41 and N50 correctly,
and N30 wrongly (rated VERY HARD).

**Limitations:**
- ratings come from very few family players per board;
- the sessions are not known to be independent;
- P21 gave one joint assessment per board;
- the rating scale is ordinal;
- the features were defined by me before this study, but the list was not
  pre-registered;
- n = 29.

**Use:** these features may be *reported* for future candidates as context.
None is used to accept or reject, and no cutoff is introduced.

## J. TIME UP investigation (N49 and N51, session 2)

**What the sessions showed:** winnable_at_timeup = false, and the untimed
continuation STOPPED.

**Question:** a legitimate dead end, or a defect?

**Method:** the user's exact export logs are not in the repository, so the
situation was reproduced. `tools/ta90_deadend_check.gd` (new;
`tools/Ta90DeadendCheck.tscn`) runs on the real 90-second page, per board:
1. Plays a third of the Solver's line, then a **losing** move, then reaches
   TIME UP at 90 s.
2. The offer resumes the 0:00 board, never a fresh one; it is recorded as
   winnable_at_timeup false; and the card says "can no longer be cleared".
   An **independent exhaustive search** (expert_probe.explore, not the
   page's Solver) confirms no winning line exists.
3. CONTINUE WITHOUT TIMER shows exactly that board.
4. RESTART in the untimed game gives the full fresh board, which the
   exhaustive search confirms solvable; the timed result stays TIME UP.
5. GIVE UP (confirmed) shows the STOPPED card; CONTINUE then stores **one**
   result: timed TIME UP, untimed STOPPED, not completed, winnable_at_timeup
   false, from timeout_state.
6. A new page reads the stored record back intact.

**Result:** PASSED: 28 checks in the first run (N49, N51, N48, N37; 7 per
board), and again in the QA run over N48–N51 and N37 (see K).

**Conclusion:** this is the designed behaviour for a position that can no
longer be cleared. The 0:00 board is a genuine dead end, the player is told
so, and RESTART is offered. **No defect, no change.** The rules were not
changed because a player reached an unsolvable state.

## K. QA (exact counts)

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real
iPhone was used in Phase 23.** No game script changed, so the browser page
tests of the earlier pages were not re-run; the ttime page test was (below).

| Suite | Result |
|---|---|
| Headless regression, the 19-suite runner | **18 pass**; RecipientTest fails, pre-existing |
| — passing suites | CompetitionCheck, unit tests, TimingCheck, ProfileCheck, ExperienceLabQaCheck, FeedbackCheck, FriendChallengeApiTest 58, FriendFlowTest 149, SocialApiTest, SocialSmoke, SocialPlayTest, TaPilotCheck 33, Extreme11Check 74, Q1TimeCheck 37, RTimeCheck 39, Ta90Check 91, Extreme90Check 91, Extreme90p17Check 97 |
| — RecipientTest | the same 3 layout checks ("TOTAL SCORE left, coins right", en_US / he_IL / ar_SA) as in every phase since Phase 16 |
| Extreme90p22Check / p21 / p20 | 184 / 168 / 132 checks, all pass |
| Ta90ContinueCheck, all selection boards | **419 checks, pass** |
| Ta90DeadendCheck (new), N48, N49, N50, N51, N37 | **35 checks, pass** (7 per board) |
| verify_levels | all 300 levels solvable, campaign rules pass |
| Browser ttime (`?tta=1`), fixed test | **6 / 6 runs pass** (3 on the Phase 22 build, 3 on the Phase 21 build); every other check of the test passed in every run |
| Browser ttime, the original test with a probe line, before the fix | P21 3 / 3, P22 2 / 3 (see below) |
| Browser `?extreme90p22=1` and the other page tests | **not re-run**: no game script or page changed in Phase 23 |
| Real iPhone | **not tested in Phase 23** |

### The ttime pulse check (`tools/web_ttime_page_test.mjs`)

**Phase 22 status:** the check "RED … a gentle pulse" failed 2 of 2 on the
Phase 22 build and passed on the Phase 21 build. It was reported as
sampling-sensitive.

**Controlled comparison, Phase 23:**
- **Setup:** the official test, unchanged in logic, plus a probe line
  logging each sample's time, screen luma and the page's own fill colour.
  It ran 3 times on each build, alternating builds
  (`data/dev/extreme90_p23/ttime/before_probe_summary.txt`).
- **Results:** P21 passed 3 / 3; **P22 passed 2 / 3** (the failure: screen
  luma 57.9–61.4, span 3.5 against the required > 4).
- **Cause:** the 6 samples are mostly 2.3–3.0 s apart (two of 30 intervals
  were ~1.5 s), typically about 2.4 s; in the failing run, 2.36–2.65 s.
  Almost all of that is screenshot time (the test sleeps only 60 ms). The
  pulse period is 1.25 s, so consecutive samples land about **two periods**
  apart, at almost the same phase of the pulse. In the failing run, all six
  screen samples stayed within 3.5 luma of each other, while the page's own
  fill colour, read at each call, varied (span 5.6). The screenshot
  happened to catch the same part of the cycle each time.
- **Interpretation:** the failure is phase aliasing of the test's sampling,
  not a rendering difference. Across Phases 22 and 23, P22 failed 3 of 5
  runs and P21 0 of 4. That build difference is not significant on these
  counts (Fisher exact p ≈ 0.17), and no code read by the `?tta` page
  differs between the builds.

**Fix (test only; the requirement unchanged):**
- **Requirement, still in force:** at least 6 samples; every one red and
  never above the resting red + 6; span > 4.
- **Stagger:** every second sample waits an extra 417 ms (a third of a
  period), which breaks the two-period alignment.
- **Extra samples:** if the first 6 show no span and the pulse is still the
  plain red one (before the last 10 s), up to 4 more samples are taken. A
  static fill shows no span however often it is sampled, so this cannot
  pass a fill that does not pulse.
- **Result:** **6 / 6 passes**, 3 per build
  (`ttime/after_fix_summary.txt`). Every run reached a span of 5–7 within
  its first 6 samples (16.1–18.1 s); none needed an extra sample.
- **Other runs:** the reduced-motion check (no pulse) and the rest of the
  test are untouched.

## L. Test instructions

There is no new board and no new page to test.
- **Most useful next:** independent re-tests of the strong provisional
  boards **N48, N49, N51** with players who have not seen them, on the
  existing Phase 22 page.
  - ZIP: `build/dev_qa/chain_escape_dev_extreme90p22_p22-qa1-20261029.zip`.
  - Open it with `?extreme90p22=1`, as a new HTML5 upload, as in
    docs/extreme90_phase22.md, part F.
  - Record per board: rating, timed outcome, time, attempts.
  - Say whether the players are independent.
- **If a run ends in TIME UP with "can no longer be cleared":** that is the
  dead-end case of J. RESTART gives the full board.

## M. Bank progress — technical vs human evidence

| Status | Boards | Count |
|---|---|---|
| Puzzle records | N1–N51 (none added in Phase 23) | 51 |
| Human-approved per the project classification (CORE + STRONG) | CORE N3, N5, N7, N11, N13; STRONG N14, N15, N16, N18, N21, N26, N27, N29, N30, N31–N38 | **22** |
| — with a recorded EXTREME rating | N14, N15, N18, N21, N31, N32, N33, N35 (+ N3 as the reference) | 8 (+ N3) |
| Strong provisional (Phase 22 results) | N48, N49, N51 | 3 |
| Human-tested, promising (provisional) | N23, N24; N39, N40, N42, N43, N44, N45, N47 | 9 |
| Technically qualified, untested | — | 0 |
| Downgraded / archived | N50 (new); N41, N46; N17, N19, N20, N22, N25, N28; N1, N2, N4, N6, N8, N9, N10, N12 | 17 |

**Remaining to 50: 28**, unchanged. Technical qualification and "strong
provisional" are not approval.

**Reading the evidence strictly:**
- only 8 boards (plus N3) carry a recorded EXTREME rating;
- several approved boards were rated VERY HARD;
- three same-core pairs (N39 / N48, N37 / N51, N32 / N39) mean the count of
  distinct *ideas* is lower than the count of boards.

## N. Commit and risks

**Files in the commit:**
- **Changed tools:**
  - `tools/web_ttime_page_test.mjs` (the pulse sampling).
  - `tools/extreme90_stage2.py`: report budget from the protocol; the
    core-check filter when a `corecheck_` file exists.
  - `tools/extreme90_round.sh`: families of any size; an optional core
    list. The order is unchanged for the Phase 21 / 22 protocols.
- **New tools:**
  - `tools/ta90_deadend_check.gd` + `tools/Ta90DeadendCheck.tscn`
  - `tools/ta90_humanfit.gd`
  - `tools/ta90_corecheck.gd`
- **New data:**
  - `data/dev/extreme90_p22/human_p22.json`
  - `data/dev/extreme90_p23/*`: protocol, cores and seeds, runs and logs,
    stage 2, reports, the human-fit study, the ttime evidence.
- **Docs:** this report and a note in docs/extreme90_phase22.md.

**Risks and open points:**
1. **No new board.** The bank grows only by human review of N48, N49 and
   N51 until new cores with several interacting dependencies are designed
   by hand.
2. **The amendment was made after seeing results.** It is recorded as such.
   It changed nothing in the outcome.
3. **The ttime fix changes a test.** Its requirement is unchanged and it was
   validated 6 / 6 on two builds. Still, it is a test change, and a single
   run is still subject to screenshot-timing variance.
4. **The difficulty study** rests on very few raters; its one robust
   feature is partly a length effect.
5. **Scope of the dead-end check:** it reproduces the reported state; it
   did not use the testers' own exports.
6. **Not pushed:** Phase 23 is local only.
