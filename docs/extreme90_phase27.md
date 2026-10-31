# EXTREME Time Attack — Phase 27: human-first bank expansion

Development only. The following are untouched:
- Production, Supabase and the 300 frozen Classic levels;
- saves and progression, campaign timing and Personal Best;
- the 120-second Time Attack baseline;
- the Social MVP and Challenge a Friend.

There is no new mechanic, feature or UI. The only game-script changes are:
- the new developer page (`scripts/social/extreme90_p27.gd`);
- its `game_manager` hook;
- one `BOARDS90` entry (N62).

**Outcome: ONE technically qualified candidate, N62** ("the shell's exit").

- That is **below both the 5–10 aim and the 2–4 fallback** named in the brief. Sections D–F give the exact reasons.
- In short, the bank already covers almost every mechanic pairing that can create a delayed loss.
- Of the new cores, those whose central mechanic was weak (Sequence, gate, lock) lost their essentiality as soon as the generator added spinners around them.
- Several boards that passed the technical gates were rejected for conceptual novelty, for non-essential mechanics, or for an N54- / N60-like human profile.
- No threshold was relaxed.

## A. Final Phase 26 QA and Git backup status

- **Start of Phase 27:** HEAD `bb44dd1`, with Phase 26 uncommitted while its QA was still running.
- **Phase 26 QA completed.** All results are in `docs/extreme90_phase26.md` section H:
  - every browser page test passed:
    - p26 112/112, p25 106/106, p24 94/94, p22 92/92, p21 84/84, p20 66/66, p19 62/62;
    - the p19 upgrade 9/9;
    - p18 55/55, the archive 45/45, p17 51/51;
    - `?ta90=1` 55/55, `?tapilot` 28/28;
  - timing / Personal Best: 33 passed, 0 failed;
  - friend build 25/25, stime 31/31, ttime 32/32;
  - page checks: p26 222, p25 212, p24 186, p22 184, p21 168, p20 132, p19 124, p18 111;
  - continuation check: 529 checks / 188 cases, 0 not resumed exactly;
  - dead-end check on N59–N61: 21 checks;
  - Portal, Movable and Magnet checks pass;
  - 18 of 19 headless suites pass;
  - verify_levels: all 300 levels pass.
- **Infrastructure note:** three Phase 26 browser tests (p18, archive, p17) first failed to *start*, because two batches ran in parallel and both tried to use port 8840. They were rerun alone and passed. Phase 27's QA runs its batches strictly one after another.
- **Phase 26 commit:** `458fe57`.
- **Push:**
  - `origin` was at `bb44dd1`, a direct ancestor (`merge-base --is-ancestor` checked).
  - A normal push moved it to `458fe57`, confirmed by a re-fetch.
  - No force-push.
- **Phase 27:** one local commit on top (section L). It is **not pushed**.

## B. Reconciled approval count: 28 / 50

| | Boards | Count |
|---|---|---|
| Owner-approved before Phase 27 (docs/extreme90_phase25.md K) | CORE N3, N5, N7, N11, N13; STRONG N14, N15, N16, N18, N21, N26, N27, N29, N30, N31–N38; N52 | 23 |
| **Owner-approved in this brief** | **N53, N55, N56, N59, N61** | +5 |
| **Total owner-approved** | | **28** — reconciles exactly with the owner's figure; **no difference** |
| Remaining to 50 | | **22** |

The authoritative manifest is `data/dev/extreme90_bank_status.json` (new). It classifies boards and deletes no record.

| Class | Count | Boards |
|---|---|---|
| owner_approved | 28 | as above |
| strong_provisional | 3 | N48, N49, N51 |
| provisional | 9 | N23, N24, N39, N40, N42, N43, N44, N45, N47 |
| technically_qualified_untested | 1 | **N62** |
| downgraded_or_archived | 21 | N50, N54, N57, N58, N60, N41, N46, N17, N19, N20, N22, N25, N28, N1, N2, N4, N6, N8, N9, N10, N12 |

**Stale classifications corrected on the new page:** the `?extreme90p27=1` export groups N53, N55, N56, N59 and N61 as `approved`, and N54, N57, N58 and N60 as `downgraded`. Earlier pages keep their own historical groups, so their exports are unchanged; the check verifies this.

## C. Human evidence and approval updates

- **Player ratings:** `data/dev/extreme90_p26/human_p26.json` (new). Only the facts given are recorded:
  - N59 EXTREME, TIME UP;
  - N60 MEDIUM;
  - N61 VERY HARD, TIME UP.
- **Phase 25 evidence:** `human_p25.json` is unchanged.
- **Owner decisions:** `data/dev/extreme90_p27/owner_approvals_p27.json`. They are stored **separately** from the ratings, with each board's fingerprint and the rating it rests on:
  - N53: EXTREME, TIME UP;
  - N55: VERY HARD, TIME UP;
  - N56: EXTREME / VERY HARD, not completed;
  - N59: EXTREME, TIME UP;
  - N61: VERY HARD, TIME UP;
  - not approved: N54 (MEDIUM), N57 (EASY / HARD), N58 (HARD / HARD), N60 (MEDIUM).

**How the Phase 26 audit flags compared with the ratings:**

| Board | Phase 26 flag | Rating |
|---|---|---|
| N60 | the weakest audit: mobility greedy 16.5%, 6-move-lookahead greedy 0.10 | **MEDIUM** |
| N61 | few forced steps | VERY HARD |
| N59 | a 4-move calm opening | EXTREME |

So the greedy-lookahead flag matched the one human-easy board. The two structural flags did not predict failure. Phase 27 therefore weighs the **look6 / mobility greedy rates** together with dependency depth and win density. The calibration examples:

- **Positive:**
  - N52: look6 0.017;
  - N53: 0;
  - N55: 0.008;
  - N56: 0;
  - N59: 0.025;
  - N61: 0.042.
- **Negative:**
  - N54: 0.175;
  - N60: 0.10;
  - N57 and N58: shallow dependency (3 / 2).

This is a small, related-player sample. It is used for ranking and to flag risk; **it is not a validated threshold**.

## D. Phase 27 design concepts

The full log is `data/dev/extreme90_p27/design_log.json`, with drafts in `d_round*.json`. Before drafting, I checked:
- **The engine:** which dual-role tokens the parser accepts. Switch + link, armored flip target, locked flip target and locked switch are all valid. A magnet with any mark is not.
- **The bank:** of these, only "armored flip target" (in N55) and "flip + link" (in N3) already appear.

| # | Concept | Mechanics | Result |
|---|---|---|---|
| Q1 | rim seal: the crate parked on the key's row seals the key | crate + lock | **infeasible**: a pusher stays in the crate's line, so the last pusher needs a spinner, switch or Sequence to leave |
| Q7 | the crate shields the shell | crate + armor | infeasible (same reason) |
| MG | the magnet is the gate's last link | magnet + gate | **engine-invalid** (magnets must be plain arrows) |
| L1 | the locked trigger | switch + lock | stopped: 205 / 207 boards engine-invalid; on plain arrows 0 qualifying |
| L2 | the remote ram through a portal | spinner + portal + armor | technically qualified; **rejected**: conceptual relative of N34 / N40 and the excluded K2 / H6 remote crack, look6 0.125 |
| **L3** | **the shell's exit** | switch + armor (+ spinners) | **N62** |
| L4 | the key is also the gate's last link | lock + gate | stopped: its only passing board needed 2 filler walls (without them: shortcut 0.49); the rest show the N54 profile |
| L5 | the battering ram (a Sequence block rams every shell in its line) | Sequence + armor | stopped: the Sequence block is not essential on all 3 boards evaluated |
| L6 | the switch is the gate's last link | switch + gate | stopped: the gate is not essential on all 3 boards evaluated |
| L8 | the locked flip target | switch + lock | rejected before generation: it reduces to "leave between two firings" (N20 / N42) |

That is 10 concept proposals, plus MG, which was checked but invalid.

## E. Generation and rejection statistics

| Item | Ceiling | Used |
|---|---|---|
| Concept proposals | 8–10 | 10 (+1 invalid) |
| Revisions per concept | 8 | at most 3 (L2: W4a–W4c) |
| Generator runs (12 min, batch 40, beam 5, patience 8, v20) | 16 | **10** |
| Full evaluations | 24 | **10** (+1 bench-only re-check that failed the floor) |

| Core | Seed | Qualifying | Valid, ≤ 700 positions, sorted by overlap |
|---|---|---|---|
| L1 | 61 / 62 / 64 (arrows) | 12 / 207 / 0 | 0 / 0 / 0 |
| L2 | 61 / 62 | 276 / 562 | yes / yes |
| L3 | 61 | 585 | yes |
| L4 | 61 / 62 | 63 / 342 | yes / yes |
| L5 | 63 | 498 | yes |
| L6 | 65 | 512 | yes |

**Rejected after full evaluation:**

| Board | Reason |
|---|---|
| L2s62_477_4 | qualifies technically; conceptual relative (N34 / N40, K2 / H6); look6 0.125 |
| L4s62_494_1 | 2 filler spinners; without them the greedy shortcut is 0.49 |
| L5s63_441_4 | 1 filler; without it (L5s63_441f) the Sequence is not essential (14 / 5 vs 15 / 5); look6 0.233 |
| L5s63_380_1 | Sequence not essential (15 / 5 vs 16 / 5) |
| L5s63_467_5 | Sequence not essential (15 / 5 vs 16 / 5) |
| L6s65_304_0 | gate not essential (12 / 5 vs 11 / 5) |
| L6s65_427_3 | gate not essential (11 / 4 vs 10 / 4) |
| L6s65_631_5 | gate not essential (12 / 4 vs 11 / 4) |

**Amendments** (in `protocol.json`): L1 was re-run on plain arrows after the invalid-token finding.

**Why generation stopped at 10 / 16 runs:**
- Every concept was either selected (L3), or stopped for a structural reason that more runs of the same core would not change: invalid tokens, non-essential core mechanic, filler dependence, conceptual relative.
- No further engine-valid, non-duplicate dependency with a delayed loss was found.

**A lesson recorded.** The "every mechanic essential" rule is the binding constraint for hybrid cores. A core mechanic that does not itself create losses (gate, Sequence, lock) is overwhelmed once the generator adds spinners. Cores built on switch, armor or magnet keep their essentiality (N59, N61, N62).

## F. Selected candidate: N62 — the shell's exit

**TECHNICALLY QUALIFIED — HUMAN UNTESTED.** Record: `data/dev/ta90_n62.json`.

| | |
|---|---|
| Fingerprint | `1710a002d011ba038f21bafc92364d3f5776ef480f7a1344cf3c1832a3de2a36` |
| Source | hand core W6a (`seed_L3_SHELLEXIT.json`) frozen; `ta90_search.gd --ops=v20`, full palette, RNG seed 61 |
| Mechanics | switch (two pieces, group A), armor (armored flip target), spinners |
| Positions / solution | 251 / 18 |
| Distinct mistakes / decision steps / effective decisions | 5 / 15 / 14 |
| Coverage / late | 0.83 / 0.83 |
| Shortcut (best greedy) | 0.025 (mobility); look2 0, look4 0.008, safe 0 |
| look6 greedy / learners (look4, look6) | 0.067 / 2, 1 |
| Solve / TIME UP worst (desktop) | 4.0 ms / 3.7 ms |
| Deterministic replay | yes |
| Filler | 0 (16 pieces tested) |
| Essentiality | switch: unsolvable without; spinners: unsolvable without; armor: without it 7 steps / 3 distinct (with it 15 / 5) |
| Overlap | 0.27 (N38); no Phase 27 partner |
| Human diagnostics | dependency depth 10 (15 escapes); safe opening 4 of 5; forced steps 10; p_calm 0.001, p_look2 0.001, p_random 0; win density 0.19 |

**Board:**

```
. . . . . . .
. Rv@~ . . P<= . .
. R> B^%A P>@- B<&A= Bv@- .
. B>@ . . R^@- . .
. . . . Gv&A . .
. . . . . . .
. . P>%A Yv@ R>&A G> R>=
```

**Dependency graph:**
1. The spinner P (r2c3) faces the armored flip target B (r2c4), and B faces back at it. Once B is cracked, neither block can ever move — unless the reversal turns B away.
2. The switch piece B^%A (r2c2) is the reversal. Its own lane up must be clear, and it also reverses G (r4c4) and R (r6c4).
3. R must leave **before** that reversal, or it is turned back into the board's interior.
4. G must be **reversed** (v → ^), because only then does it crack the shell P<= (r1c4).
5. The second switch piece P>%A (r6c2) reverses everything again. Fired early, it undoes the timing above, so it must fire last.

**Exact Solver line:**
```
r2c3> ram, r6c5> ram, r6c6>, r6c5>, r2c5v, r6c3v, r6c4>, r2c2^, r2c3^, r2c4>,
r2c1>, r1c1<, r3c1v, r3c4<, r4c4^ ram, r1c4<, r4c4^, r6c2>
```

The core holds on this line:
- step 1 cracks the shell;
- step 7 R leaves first;
- step 8 fires the reversal;
- step 10 the shell leaves the face-off;
- step 15 the reversed G cracks the top shell.

**Delayed losing decisions** (in brackets: the moves still playable after the mistake):
- `r2c2^`, firing the reversal too early, at steps 1–7 (up to 15);
- `r6c4>`, R leaving at the wrong moment, at steps 5–6 (10–11);
- `r4c4v`, G leaving unreversed, at step 8 (8);
- `r2c4>` at step 9 (4);
- `r6c2>`, the second firing, at steps 8–15 (1–8).

**Human-like shortcut audit:**
- No simple player finds the route: calm 0.1%, look-2 0.1%, random 0%.
- Every greedy player is ≤ 2.5% (the gate is 20%).
- The tempting first ideas lose: "fire the switch to free the shell" (the immediate, obvious reading of the face-off), and "let the free R / G out".
- **Watch items:**
  - 4 of 5 opening moves are safe;
  - the calm prefix is 4 (as on N59, rated EXTREME);
  - look6 0.067 sits between the positive boards (≤ 0.042) and N60 (0.10).

**Conceptual similarity:**
- **N55** also reverses a shell away from its rammer, but there the switch piece is the rammer's spinner *neighbour* and the reversal is one effect of a three-effect firing. In N62 the face-off is *created by the ram itself* and is the board's central trap.
- **N38 / N41:** reversal timing around rams, but those reverse the *rammer*, not the shell.
- **N61:** reversal timing, but the deadlock there is a lock, not a face-off.

N62 is flagged as conceptually related to N55 and should be judged on human play.

## G. Diversity and human-shortcut audit

- **The batch:** one board, so there are no internal duplicates.
- **Against the bank:** overlap 0.27 (< 0.40); its relatives are named in F.
- **Human-shortcut audit of every board evaluated this phase:**
  - L2: look6 0.125 — rejected (also conceptual);
  - L5s63_441_4: look6 0.233 — rejected (also the Sequence block is not essential);
  - L4 boards: win density 0.53–0.56, greedy up to 0.20 — the N54 profile, stopped;
  - L6s65_304_0: look6 0.017 — a good profile, but the gate is not essential;
  - **N62: the strongest profile of the phase.**
- **Mechanic families on the page:** switch + armor. No crate, magnet cascade, Sequence pusher or shared-key spinner counting.

## H. Complete regression report

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real iPhone was used in Phase 27.**

**Builds:**
- Dev build ("Web") and player build ("Web Friend Test") were exported from the working tree.
- The dev export contains the N62 record.
- The player build contains 0 `data/dev` files.

| Suite | Result |
|---|---|
| Browser `?extreme90p27=1` (new) | **114 / 114** |
| Browser `?extreme90p26=1` / `p25` / `p24` / `p22` / `p21` / `p20` / `p19` / Phase 19 upgrade | 112 / 112, 106 / 106, 94 / 94, 92 / 92, 84 / 84, 66 / 66, 62 / 62, 9 / 9 |
| Browser `?extreme90p18=1` / `?extreme90=1` (archive) / `?extreme90p17=1` / `?ta90=1` / `?tapilot` | 55 / 55, 45 / 45, 51 / 51, 55 / 55, 28 / 28 |
| Browser campaign timing and Personal Best | **33 passed, 0 failed** |
| Browser friend (player) build / stime / ttime (`?tta=1`, the 120 s page) | 25 / 25, 31 / 31, 32 / 32 |
| Extreme90p27Check (new) | **226 checks, pass** |
| Extreme90p26Check / p25 / p24 / p22 / p21 / p20 / p19 / p18 | 222 / 212 / 186 / 184 / 168 / 132 / 124 / 111 checks, all pass |
| Ta90ContinueCheck, all 48 selection boards incl. N62 | **540 checks, 192 cases, 0 not resumed exactly** (TIME UP restore, UNDO after continuing, RESTART, a lost tap, a dead end) |
| Ta90DeadendCheck on N62 | **7 checks, pass** |
| PortalCheck / MovableCheck / MagnetCheck | pass |
| Headless regression, the 19-suite runner | **18 pass**; RecipientTest fails, pre-existing (below) |
| — the passing suites | competition, unit tests, timing, profile, experience lab, feedback, Challenge a Friend API 58 / flow 149, Social API / smoke / play, pilot 33, extreme11 74, Q1 time 37, R time 39, Ta90Check 91, Extreme90Check 91, Extreme90p17Check 97 |
| verify_levels | **all 300 levels solvable, campaign rules pass** |

**WebAssembly full solve (the TIME UP check), headless Chromium:**
- N62: 3.5 ms.
- All boards on the page are within the 40 ms limit (N57, the slowest, is near 33 ms).

**Touch run:** the browser test solved N62 by touch in a timed 90 s run (27.2 s of scripted taps, not a human time). It also passed TIME UP at 90 s with the clock running through a reload.

**The QA run itself:**
- The batches ran strictly one after another this time, so there were no port clashes.
- A **container restart** interrupted batch B after `p24`. The working tree, the dev build (same `index.pck` hash as the ZIP) and all results so far survived.
- The remaining tests (`p22` onwards, batches C and D) were resumed from where they stopped and all passed. No test was skipped.

**Known failure, reported separately:** RecipientTest.
- It fails the same 3 layout checks ("TOTAL SCORE left, coins right" for en_US / he_IL / ar_SA) as every phase since Phase 16.
- Phase 27 changed no Social or recipient code.

## I. Verified Phase 27 QA ZIP

- **File:** `build/dev_qa/chain_escape_dev_extreme90p27_p27-qa1-20261030.zip`
  (15,135,905 bytes, 9 files plus `BUILD_ID.txt`). It is the dev ("Web") export of the tested build.
- **SHA-256:** `3f18bf783b42a4ea5f839cbfda824db3659d27905d2a289f84ddbaef522c0797`
- **Verification:**
  - the archive tests clean;
  - it holds the complete HTML5 export (html, js, wasm, pck, audio worklet, icons);
  - the pack contains the N62 record and the `?extreme90p27=1` page;
  - `BUILD_ID.txt`: p27-qa1-20261030, entry `index.html?extreme90p27=1`, `index.pck` sha256 `79c61e64…ae201263`;
  - the `?extreme90p27=1` browser test (114 / 114) ran on this exact build.
- **Delivered:** attached to the user as a downloadable file.
- **Not uploaded** anywhere, and not deployed.

## J. Human playtest instructions

- **Open:** `index.html?extreme90p27=1` from the QA ZIP, served over HTTP(S), for example on itch.io as a private draft. **Not Production.**
- **Primary screen:** **CHALLENGE 1 = N62** only. The label is neutral: no difficulty, id or group is shown.
- **Protocol (unchanged):**
  - 90 seconds;
  - unlimited RESTART (the clock keeps running);
  - UNDO ×3;
  - HAMMER 0;
  - SHOW A MOVE 0.
- **After the run:** the 3 short questions, then CONTINUE WITHOUT TIMER from the exact TIME UP position.
- **Results:** COPY ALL RESULTS exports `ce-xb27` JSON. Please send it back unchanged.
- **First exposure counts.** Please note whether players shared solutions or guidance.
- **Earlier challenges:** PREVIOUS CHALLENGES (2–48) is optional; those are earlier boards.
- **Unchanged:** the 120-second Time Attack baseline is separate and was not changed.

## K. Updated bank progress

- **Owner-approved: 28 / 50. Remaining: 22.**
- **Strong provisional:** 3 (N48, N49, N51).
- **Provisional:** 9.
- **Technically qualified, human untested:** 1 (**N62**).
- **Downgraded / archived:** 21.

Only explicit owner approval moves N62 into the approved bank.

## L. Final local Phase 27 commit

- **One local commit** on top of `458fe57` (Phase 26). Its hash is given in the final report, because a commit cannot contain its own hash.
- It is **not pushed**, merged or deployed.
- Phase 28 is not started.

**Risks:**
1. Only one candidate this phase. The mechanic space is close to saturated under the essentiality and novelty rules.
2. N62 is conceptually related to N55.
3. N62's look6 of 0.067 lies between the human-approved boards and N60.
4. The generator still emits engine-invalid suffix tokens. They are caught by `tools/extreme90_tokens26.py`; the generator itself is not fixed.
5. The difficulty measures are descriptive only, on a small related-player sample.
6. Headless browser testing only: no real iPhone.
7. The known RecipientTest layout failures remain (section H).
