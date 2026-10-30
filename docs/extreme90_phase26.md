# EXTREME Time Attack — Phase 26: human-calibrated bank expansion

Development only. The following are untouched:
- Production, Supabase and the 300 frozen Classic levels;
- saves and progression, campaign timing and Personal Best;
- the 120-second Time Attack baseline;
- the Social MVP and Challenge a Friend.

There is no new mechanic, feature or UI. The only game-script changes are:
- the new developer page (`scripts/social/extreme90_p26.gd`);
- its `game_manager` hook;
- three `BOARDS90` entries (N59–N61).

**Outcome:**
- **Three technically qualified candidates, N59–N61**, from three distinct
  reasoning structures. That is **below the 5–10 the brief aims for**.
  Section F gives the exact reasons.
- All three are **TECHNICALLY QUALIFIED — HUMAN UNTESTED**.
- None counts toward the 50.

| Board | Concept | Mechanics | Source |
|---|---|---|---|
| N59 | the magnet moves the magnet | magnet + armor | hybrid (hand core C1a) |
| N60 | the relocated boomerang | magnet + Sequence + armor (+ spinners) | hybrid (hand core G3a) |
| N61 | the key turned to face its prisoner | switch + lock (+ spinners) | hybrid (hand core J5c) |

## A. GitHub backup status

- **Start of Phase 26:** branch `claude/elegant-fermat-0jrmxo`, HEAD `bb44dd1` (Phase 25).
- **Remote:** `origin` was at `d4166e9`, a direct ancestor (`git merge-base --is-ancestor` true).
- **Push:** a normal push (no force) moved `origin` `d4166e9 → bb44dd1`. A re-fetch confirms `origin/claude/elegant-fermat-0jrmxo` = `bb44dd1`. **Phase 25 is backed up.**
- **Phase 26:** one local commit on top (hash in section L). It is **not pushed**, merged or deployed.

## B. Phase 25 human classifications (recorded)

The file is `data/dev/extreme90_p25/human_p25.json`, which stores each fingerprint with its results. The two players are kept separate:
- **Player 1:** the project owner.
- **Player 2:** his son.

The sessions are **not** treated as fully independent: same household, and whether solutions or guidance were shared is not recorded. Earlier history (`human_p17` … `human_p24`) is unchanged.

| Board | Player 1 | Player 2 | Classification |
|---|---|---|---|
| N53 | EXTREME, TIME UP, 5 attempts, 5/5 | not tested | **STRONG PROVISIONAL** |
| N54 | MEDIUM, 45.6 s, 3 attempts, 5/5 | not tested | **DOWNGRADED** |
| N55 | VERY HARD, TIME UP, 6 attempts, 5/5 | gave up at 3.5 s with **no move**: **invalid** for difficulty | **STRONG PROVISIONAL** |
| N56 | EXTREME, TIME UP, 4 attempts, 5/5 | VERY HARD, gave up at 88.4 s, 5 attempts, 4/5 | **STRONG PROVISIONAL** |
| N57 | EASY, 19.0 s, first attempt, 5/5 | first run interrupted (0 moves, invalid); second run HARD, 29.2 s, 3/5 — the first *useful* observation, not an independent replay benchmark | **DOWNGRADED** |
| N58 | HARD, 64.4 s, 3 attempts, 5/5 | HARD, 32.4 s, 2 attempts, 4/5 | **DOWNGRADED** |

On the Phase 26 page:
- N53, N55 and N56 export as group `strong_provisional`.
- N54, N57 and N58 export as group `downgraded`.

The Phase 25 page's own export is unchanged: they stay `phase25` there. No board was promoted.

## C. Human-difficulty analysis (diagnostic only)

**New tool:** `tools/ta90_humanlike26.gd`. It is diagnostic only: it adds no threshold and rejects nothing. It answers the brief's questions with exact position-graph measures:
- **Safe opening moves:** `open_safe` / `open_moves`.
- **First trap:** `first_trap` and `first_deep_trap` (the first trap whose dead end shows only after ≥ 4 moves).
- **Forced versus free steps:** steps with exactly one winning move, and steps with two or more.
- **Exact win chances of simple players:**
  - `p_random`: any legal move.
  - `p_look1` / `p_look2`: never a move that is visibly dead within 1 / 2 moves.
  - `p_calm`: the "locally sensible" player, who takes calm moves first whenever one exists.
- **True dependency depth:** `dep_depth` is the longest chain of escapes forced in order on every one of 300 random winning lines. It measures dependency, not move count.

It was run on all 56 bank boards (`data/dev/extreme90_p26/diag_bank.json`).

**Rank study.** File: `diag_study.json`. It covers the 36 boards with ratings, using first-exposure ratings averaged on the ordinal scale (EASY 0 … EXTREME 4). Spearman ρ, descriptive only:

| Measure | ρ | | Measure | ρ |
|---|---|---|---|---|
| effective decisions (P23) | **+0.55** | | p_calm | **−0.46** |
| solution length | +0.49 | | look6 greedy | −0.45 |
| concurrency (P23) | +0.45 | | p_look1 / p_look2 | −0.33 |
| decision steps | +0.43 | | p_random | −0.30 |
| dep_depth | +0.33 | | open_safe | −0.26 |
| learner4 / learner6 | +0.24 / +0.27 | | first_trap | 0.00 (every board has a trap at move 1) |

**The Phase 25 boards against the human-approved and strong boards:**

| Board | Human | dep_depth (escapes) | safe opening | forced steps | look6 greedy | p_look2 | win density |
|---|---|---|---|---|---|---|---|
| N52 | EXTREME ×2 | 9 (15) | **1 / 5** | 10 | 0.017 | 0.001 | 0.44 |
| N53 | EXTREME | 8 (17) | 4 / 6 | 9 | 0 | 0 | 0.29 |
| N56 | EXTREME / VH | **12** (14) | **1 / 2** | 8 | 0 | 0 | 0.27 |
| N55 | VERY HARD | 11 (15) | 3 / 4 | 7 | 0.008 | 0 | 0.23 |
| **N54** | MEDIUM | 7 (15) | 3 / 4 | 7 | **0.175** | **0.013** | **0.37** |
| **N57** | EASY / HARD | **3** (9) | 3 / 6 | **3** | 0 | 0.004 | 0.20 |
| **N58** | HARD / HARD | **2** (7) | 2 / 4 | 6 | 0.05 | **0.011** | 0.39 |

**What the evidence supports (small sample, two players, not a model):**

1. **N57 and N58: shallow true dependency.** Their move counts are 14 and 15, but almost all of those moves are pushes of one crate. Only 9 and 7 blocks ever escape, and the escape order is pinned only to depth 3 and 2. Every other rated board has depth 5–14. A player meets "the same mechanic again" (push, push, push): repeated, familiar steps rather than new dependencies. N57 also has the fewest forced steps of all boards (3).
2. **N54: a greedy player with short look-ahead is not punished enough.**
   - It has the highest 6-move-lookahead greedy win rate among the Phase 25 boards (0.175).
   - Its look-2 rate (0.013) is the highest of the four approved / strong boards above.
   - Its win density is high (0.37).
   - A player who avoids visible dead ends a few moves ahead finds the route without planning. Technical "distinct mistakes" (5) did not capture this.
3. **The EXTREME boards (N52, N56) have very few safe openings** (1 of 5, 1 of 2). The first decision is already a trap whose consequence is deep.
4. **Weak or no signal:**
   - `first_trap`: every bank board has a losing move at step 1.
   - The learner counts: VERY HARD N16 / N30 also have 0.
   - Total positions.
5. **Not established:** any threshold. 36 boards rated by a few related players cannot calibrate a model. These measures are **watch-list diagnostics** for selection and for the report. Every existing gate is unchanged.

**How Phase 26 used it** (protocol amendment 2, recorded before any full evaluation):
- Among each run's six cheapest qualifying boards, the one sent to full evaluation was the one with deeper dependency, fewer safe openings and a lower calm-player win chance.
- The measures ranked boards; they rejected none.

## D. Conceptual designs attempted

**Method** (protocol: `data/dev/extreme90_p26/protocol.json`; drafts: `d_*.json`; log: `design_log.json`):
1. Each concept was written as a dependency first, with its tempting mistakes and its delayed failure.
2. A small hand core was benched (`tools/ta90_bench24.gd`).
3. Near-miss cores were frozen and grown by `tools/ta90_search.gd --ops=v20` (unchanged).
4. Every result was then re-checked in full and checked by hand on the Solver's line.

**Engine checks before building:**
- Magnets only on boards without portals, crates or hidden blocks.
- No block is both a switch and a flip target; the parser refuses it, see G12.
- Switch, flip and armored blocks are plain arrows: no spinner.

| # | Concept (dependency) | Mechanics | Result |
|---|---|---|---|
| K1 | the drill turns around: ram, stay, be reversed, ram behind | switch + armor | **rejected before generation**: conceptual duplicate of N41 / N38 |
| J1 | **the magnet moves the magnet**: M1 pulls M2 into its cell, moving M2's pull line | magnet + armor | **N59** |
| J2 | reversal into the gate: a link turned to face its own gate (deadlock) | switch + gate | technically qualifies, but every filler-free valid board overlaps N43 ≥ 0.40 (seed 53), or has a filler block (seed 54) — the shape is taken by J5 |
| J3 | **the relocated boomerang**: a magnet pulls a first-stage Sequence block into the shells' row, where its advance reverses it onto a shell | magnet + Sequence + armor | **N60** |
| J4 | two-hop relay: M1 pulls the cargo into M2's line, M2 pulls it again | magnet + armor | qualifies technically (4 distinct, 14 moves, overlap 0.35); **rejected as a conceptual relative of J1** (its main trap, "M2 fired first pulls M1", is J1's mechanism) — J1 kept for its stronger metrics |
| J5 | **the key turned to face its prisoner**: the key facing away must leave before any firing, or it faces the block waiting for it (lock deadlock) | switch + lock | **N61** (J2's shape in its lock form: one board for the two) |
| G4 | the gate as the magnet's blindfold: fire before it opens | magnet + gate + armor | stopped: bypass (the rammer finishes first); closing it gives N52's "wrong block first" / N22 |
| G5 | the flip sends the rammer through the portal | switch + portal + armor | excluded: Phase 23 K2 / Phase 25 H6, already stopped |
| G7 | the magnet is the last key | magnet + lock + armor | stopped: the lock is decoration |
| G8 | dormant cargo: the locked cargo blocks its key | magnet + lock | stopped: geometric contradiction (delivery cell = the magnet's own cell) |
| G12 | switch relay: a switch that is another switch's flip target | switch | **engine-invalid**: refused by the parser |
| G25 | the relocated switch | magnet + switch | stopped: no decision |

**Count:** 12 concept proposals and 26 benched hand drafts. Of these, 5 cores went to the generator (J1–J5) and 3 boards were selected.

## E. Generation budget actually consumed

The budget was fixed in `protocol.json` before the first run.

| Item | Ceiling | Used |
|---|---|---|
| Concept proposals | 8–10 | 12 (all bench-only except J1–J5) |
| Revisions per concept | 8 | at most 2 (J1, J2, J3); J5 2 |
| Generator runs (12 min, batch 40, beam 5, patience 8, v20) | 16 | **9** |
| Full evaluations (report + filler + overlap) | 24 | **9** |

| Core | Seed | Palette | Qualifying boards |
|---|---|---|---|
| J1 magnet moves magnet | 51 | arrows | 0 |
| J2 reversal into the gate | 51 | arrows | 0 |
| J3 relocated boomerang | 51 | arrows | 0 |
| J1 | 52 | arrows | 479 |
| J2 | 53 | all (amendment 1) | 686 |
| J3 | 53 | all (amendment 1) | 640 |
| J4 two-hop relay | 53 | arrows | 397 |
| J2 | 54 | all | 586 |
| J5 key faces its prisoner | 54 | all | 519 |

**Amendments** (each recorded before the affected reports):
1. **After seed 51 (0 qualifying):** J2 and J3 were grown with the full palette.
   - Reason: on plain arrows these cores repeat one losing move at many steps, so distinct mistakes stay at 2–3 against the required 4.
   - Hand enrichment (J1b, J2b, J3b) did not fix it.
2. **Diagnostic ranking** for the board sent to full evaluation: see section C.
3. **Budget extension inside the ceiling:** J2 seed 54 plus J5, after J2's seed-53 boards all overlapped N43.

**Why generation stopped at 9 / 16 runs:**
- Three concepts qualified.
- The remaining proposals are duplicates, engine-invalid or have no decision (D).
- No further distinct dependency with a delayed failure was found that the engine supports and the bank does not already hold.
- More runs on the same cores could only add conceptual duplicates, which the rules forbid.

**Pre-existing generator issue found.** `ta90_search.gd` can append a suffix to a spinner token (for example `R<@-=`, an armored spinner). The engine forbids such a token; the parser repairs it with an error, so the board played is not the board designed. All 8 of J2's lowest-overlap seed-53 boards had it, including one that passed the report.
- New check: `tools/extreme90_tokens26.py`.
- Every shortlist now skips such boards.
- None of N59–N61 has one, and no existing bank board (N3–N58) has one.
- The generator itself was not changed (out of scope).

## F. New candidate metrics and rejections

All three boards are **TECHNICALLY QUALIFIED — HUMAN UNTESTED**. Records: `data/dev/ta90_n59.json` … `n61.json`. Metrics: Phase 21 rules, desktop timing; shortcut = best greedy player; mobility in brackets where it is the best.

| | N59 | N60 | N61 |
|---|---|---|---|
| Fingerprint | `d54c9207…1a605f8683` | `593595bf…2197be233b` | `52dab141…d099a75e5bc` |
| Source board | J1 seed 52 #1 | J3 seed 53 #3 | J5 seed 54 (548 positions) |
| Positions | 171 | 237 | 548 |
| Solution | 18 | 19 | 17 |
| Distinct mistakes | 4 | 5 | 6 |
| Decision steps | 14 | 16 | 12 |
| Coverage / late | 0.78 / 0.83 | 0.84 / 0.84 | 0.71 / 0.88 |
| Shortcut (best greedy) | 0.045 (mobility) | **0.165** (mobility) | 0.008 |
| look6 greedy | 0.025 | **0.10** | 0.042 |
| Solve / TIME UP worst (ms, desktop) | 3.2 / 1.2 | 7.7 / 4.7 | 13.6 / 9.3 |
| Replay deterministic | yes | yes | yes |
| Filler | 0 | 0 | 0 |
| Overlap (bank) | 0.39 N46 | 0.37 N17 | 0.27 N46 |
| Essentiality | magnet: unsolvable without; armor: 0 decisions without | magnet, Sequence, spinners: unsolvable without; armor: 6 steps / 3 distinct without (16 / 5) | switch: unsolvable without; lock: 2 steps / 1 distinct without (12 / 6); spinners: 1 distinct without |
| dep_depth / safe opening / forced | 12 / 3 of 4 / 6 | 11 / 3 of 4 / 11 | 8 / 4 of 7 / **2** |
| p_calm / p_look2 | 0.009 / 0 | 0.002 / 0 | 0.005 / 0.001 |

**Solver lines and dependency verification** (from the bench; ram = shell cracked, advance = Sequence first stage):

- **N59:** 18 moves:
  `r0c5^ r1c5^ r3c2^ram r1c4> r1c3> r1c2> r2c2^ r3c2^ r3c3< r3c5< r2c3^ r4c5> r2c5v ram r6c5< r2c3< r2c3v ram r5c3> r2c3v`
  - Step 11 (`r2c3^`): M1 fires and pulls magnet M2 from row 4 into r2c3, so M2's pull line is now row 2.
  - Step 15 (`r2c3<`): M2 fires from there and pulls the cargo (r2c5) into column 3.
  - Step 16 (`r2c3v ram`): the cargo cracks the bottom shell.
  - Delayed losing moves, with the moves still playable after them:
    - `r4c3<` (M2 fired in place) is legal and losing at steps 1–11, with up to 15 moves still playable;
    - `r2c3^` early (M1 before its line is ready) at steps 6–9;
    - `r2c3<` / `r2c5v` (the cargo leaving instead of being delivered) at steps 12–15.
- **N60:** 19 moves:
  `r0c2^ r0c5> r1c2< r1c3< r0c3< r0c4^ r3c3< r2c3^ r2c2<ram r2c1v ram r5c1v r2c1v r2c2^ r5c2^ r2c3< advance r2c3> ram r1c5^ r1c5^ r2c3>`
  - Step 8: the magnet pulls the Sequence block from r5c3 up to r2c3.
  - Step 15: it advances, its arrow now reversed.
  - Step 16: it cracks the right shell.
  - The left shell is cracked from beside the cargo by a spinner. The hand core intended the Sequence block's own first-stage ram; that ram is **not** on the line.
  - Delayed losing moves: the magnet at r1c5 fired early (`r1c5^`) at steps 3–16, with up to 14 moves still playable; `r2c3^` early; the top-row spinners leaving in the wrong order.
- **N61:** 17 moves:
  `r4c6^ram r1c6> r2c6^ r4c6^ r2c5> r1c5> r3c4v r4c5> r3c5v r4c3> r3c3> r5c2< r5c3< r2c3v r4c1v r3c1v r6c6>`
  - Step 11: the yellow key leaves while still facing away.
  - Step 14: a switch piece fires; the block under the prisoner is reversed and leaves (step 15); the prisoner, now unlocked, leaves (step 16).
  - Delayed losing moves: the switch fired early (`r6c6>`) at steps 1–11 and 15, with up to 13 moves still playable — the key is reversed to face its prisoner and neither can ever move. Also `r3c3>`, the key leaving too early, which breaks the reversal of the block under the prisoner.

**Greedy and human-like shortcut audit** (diagnostics plus inspection of each line):
- **N59.** No shortcut found.
  - The obvious first idea is "fire the free magnet" (r4c3<). It is legal from move 1 and loses with a 15-move-deep consequence.
  - A calm player wins 0.9%; look-2 / random players win 0%.
  - Watch item: four always-safe moves at the start (calm prefix 4), more than N52 / N56 (0).
- **N60.** No obvious shortcut, but the **weakest audit of the three**:
  - the mobility player ("keep most moves open") wins 16.5%, under the 20% gate but the highest here;
  - look6 is 0.10 (N54 had 0.175).
  - This is the board most at risk of rating below EXTREME.
- **N61.** No greedy shortcut (all ≤ 0.8%).
  - Watch item: only 2 forced steps and 193 206 winning lines. The player has much freedom on most steps, which may make it feel easier than its 6 distinct mistakes suggest (compare N54's freedom).

**Rejected after full evaluation:**

| Board | Why |
|---|---|
| J2 seed 53 #5 | overlap 0.50 (N43), 1 filler |
| J2 seed 53 o395 | 1 filler (r3c3, the core's own blocker); without it, it passes the report, but it contains the engine-invalid token `R<@-=` |
| J4 seed 53 #5 | overlap 0.45 (N46) |
| J4 seed 53 o461 | **technically qualified**; rejected as the conceptual relative of J1 |
| J2 seed 54 o441 | 1 filler; the same shape as the selected J5 |

## G. Conceptual diversity audit

**Pairwise occupancy overlap between the new boards** (sim, unchanged):
- N59–N60 0.26;
- N59–N61 0.23;
- N60–N61 0.24.

**Against the full bank:** 0.39 / 0.37 / 0.27, all < 0.40.

**Closest conceptual relatives:**
- **N59:**
  - N31 / N46 "the pull decides who is in the way";
  - N32 / N39 / N48 "the magnet brings the rammer";
  - N52 pull-order cascade.
  - New: no bank board moves a magnet with another magnet, so a pull line that relocates is new.
- **N60:**
  - N21 / N45, a Sequence advance as a delayed second effect;
  - N18 / N32, magnet delivery.
  - New: magnet + Sequence never appears together in the bank. A boomerang that only works after being moved is new.
- **N61:**
  - N36 (switch half: "the switch turns a block toward one waiting for it");
  - N23, the switch and the lock;
  - N20 / N42, two switch pieces.
  - Different: the wait is a **lock dependency**, not a lane face-off. The deadlock is a key facing the very block that waits for its colour.
  - N61 is the most conceptually exposed of the three, so it is flagged.

**Family balance:**
- Two of the three boards are magnet-based, each with a distinct dependency; one is switch-based.
- There is no crate, no Sequence-pusher and no spinner-counting core.
- N60 and N61 contain generator-added spinners that supply some decisions, but neither is spinner-counting at its core. N60's spinners are essential (unsolvable without them); N61 keeps 1 distinct mistake without them.

## H. Full regression results

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real iPhone was used in Phase 26.**

**Builds:**
- Dev build ("Web") and player build ("Web Friend Test") were exported from the working tree.
- The dev export lists the 3 new records.
- The player build contains 0 `data/dev` files.

| Suite | Result |
|---|---|
| Browser `?extreme90p26=1` (new) | **112 / 112** |
| Browser `?extreme90p25=1` / `p24` / `p22` / `p21` / `p20` / `p19` / Phase 19 upgrade | 106 / 106, 94 / 94, 92 / 92, 84 / 84, 66 / 66, 62 / 62, 9 / 9 |
| Browser `?extreme90p18=1` / `?extreme90=1` (archive) / `?extreme90p17=1` / `?ta90=1` / `?tapilot` | 55 / 55, 45 / 45, 51 / 51, 55 / 55, 28 / 28 |
| Browser campaign timing and Personal Best | **33 passed, 0 failed** |
| Browser friend (player) build / stime / ttime (`?tta=1`, the 120 s page) | 25 / 25, 31 / 31, 32 / 32 |
| Extreme90p26Check (new) | **222 checks, pass** |
| Extreme90p25Check / p24 / p22 / p21 / p20 / p19 / p18 | 212 / 186 / 184 / 168 / 132 / 124 / 111 checks, all pass |
| Ta90ContinueCheck, all 47 selection boards incl. N59–N61 | **529 checks, 188 cases, 0 not resumed exactly** (TIME UP restore, UNDO after continuing, RESTART, a lost tap, a dead end) |
| Ta90DeadendCheck on N59–N61 | **21 checks, pass** |
| PortalCheck / MovableCheck / MagnetCheck | pass |
| Headless regression, the 19-suite runner | **18 pass**; RecipientTest fails, pre-existing (below) |
| — the passing suites | competition, unit tests, timing, profile, experience lab, feedback, Challenge a Friend API 58 / flow 149, Social API / smoke / play, pilot 33, extreme11 74, Q1 time 37, R time 39, Ta90Check 91, Extreme90Check 91, Extreme90p17Check 97 |
| verify_levels | **all 300 levels solvable, campaign rules pass** |

**WebAssembly full solve (the TIME UP check), headless Chromium:**

| Board | Time |
|---|---|
| N59 | 1.6 ms |
| N60 | 7.3 ms |
| N61 | 7.9 ms |
| Slowest board on the page | N57, 33.5 ms |

All boards are within 40 ms.

**On the touch runs:** in the browser test, each new board was solved by touch in a timed 90 s run (N59 30.1 s, N60 28.7 s, N61 23.9 s). Those times are scripted taps, not human times.

**The QA run itself:**
- Batches B and C were started in parallel, and their test servers clashed on port 8840 (`EADDRINUSE`).
- So the `p18`, archive and `p17` browser tests never started on the first try.
- They were rerun on their own and passed (counts above). No test result was lost or changed.

**Known failure, reported separately:** RecipientTest.
- It fails the same 3 layout checks ("TOTAL SCORE left, coins right", en_US / he_IL / ar_SA) that have failed in every phase since Phase 16.
- Phase 26 changed no Social or recipient code.

## I. Phase 26 QA ZIP

- **File:** `build/dev_qa/chain_escape_dev_extreme90p26_p26-qa1-20261030.zip`
  (15,034,781 bytes, 9 files plus `BUILD_ID.txt`). It is the dev ("Web") export of the tested build.
- **SHA-256:** `b1ad2aea3e8cc55673803a2a62731aff9a3bfda58ab65379d5b93409faf81e3f`
- **Verification:**
  - the archive tests clean;
  - it holds the complete HTML5 export (html, js, wasm, pck, audio worklet, icons);
  - the pack contains the N59–N61 records;
  - `BUILD_ID.txt`: p26-qa1-20261030, entry `index.html?extreme90p26=1`.
- **Delivered:** attached to the user as a file.
- **Not uploaded** anywhere.

## J. Human testing instructions

- **Open:** `index.html?extreme90p26=1` from the QA ZIP. Serve it over HTTP(S), for example on itch.io as a *private* draft or with a local static server. Do **not** use a production page.
- **Primary screen:** CHALLENGE 1–3 only. The labels are neutral: no difficulty, ids or groups are shown.
  - CHALLENGE 1 = N59;
  - CHALLENGE 2 = N60;
  - CHALLENGE 3 = N61.
- **Protocol (unchanged):**
  - 90 seconds;
  - unlimited RESTART (the clock keeps running);
  - UNDO ×3;
  - HAMMER 0;
  - SHOW A MOVE 0.
- **After the run:** the 3 short questions (difficulty, enjoyment, play again), then CONTINUE WITHOUT TIMER from the exact TIME UP position.
- **Results:** COPY ALL RESULTS exports `ce-xb26` JSON. Please send it back unchanged.
- **First exposure:** each player's first run of a board is the one that counts for difficulty. Record whether players talked about solutions in between.
- **Earlier challenges:** PREVIOUS CHALLENGES (4–47) is optional; those are earlier boards.
- **Unchanged:** the 120-second Time Attack baseline is separate and was not changed.

## K. Updated 50-puzzle bank status

| Status | Count | Boards |
|---|---|---|
| **Human-approved EXTREME (internal policy)** | **23 / 50** | unchanged in Phase 26; includes N52 |
| Strong provisional (not counted) | 6 | N48, N49, N51, **N53, N55, N56** |
| Provisional | 9 | unchanged |
| Downgraded (on the Phase 26 page's selection) | 6 | earlier downgraded boards plus **N54, N57, N58** |
| Technically qualified, human untested | **3** | **N59, N60, N61** |

- **"Internal approval"** means the project's own acceptance policy: at least two first-exposure EXTREME ratings from the family testers. That is **not** broader, independent human validation. No board has that yet.
- **To reach 50:** 27 more boards are needed. The target was not changed.

## L. Commit and risks

- **Local commit:** hash given in the final report. Not pushed, merged or deployed. Phase 27 is not started.
- **Risks:**
  1. Only **3** candidates, below the 5–10 aim (E explains why).
  2. N60's mobility shortcut of 16.5% is the highest here.
  3. N61 has few forced steps and is conceptually close to N36.
  4. N59 has a 4-move calm opening.
  5. The human-difficulty measures are descriptive. They rest on 36 boards and few related raters.
  6. The generator can emit engine-invalid suffix tokens. This is now caught by `extreme90_tokens26.py`; the generator itself was not fixed.
  7. Headless browser testing only: no real iPhone.
  8. The known RecipientTest layout failures remain.
