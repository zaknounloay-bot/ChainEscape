# EXTREME Time Attack — Phase 25: reasoning-first bank expansion

Development only. Production, Supabase, the 300 Classic levels, saves /
progression, campaign timing and Personal Best, the 120-second Time Attack
baseline, the Social MVP and Challenge a Friend are untouched. No new
mechanic, feature or UI. The only game-script changes are:
- the new developer page (`scripts/social/extreme90_p25.gd`);
- its `game_manager` hook;
- six `BOARDS90` entries (N53–N58).

**Outcome:** **six technically qualified candidates, N53–N58**, from six
distinct concepts. None is human-approved.

| Concept | Board | Source |
|---|---|---|
| Sequence relay | N58 | designed fully by hand |
| Shared key | N53 | hybrid |
| Links aim the spinner | N54 | hybrid |
| The firing is the turn | N55 | hybrid |
| The turners are the brake | N56 | hybrid |
| Crate route | N57 | hybrid |

"Hybrid" means a near-miss hand design frozen as a core and completed by
the existing generator, then fully re-checked. N52 is recorded as
**human-approved EXTREME**.

## A. Git backup

- **Start of Phase 25:** HEAD `d4166e9` (Phase 24); `origin` at `bb4de69`,
  a direct ancestor.
- **Push:** a normal push (no force) moved `origin` `bb4de69 → d4166e9`;
  `git ls-remote` confirms `d4166e97011f…`. **Phase 24 is backed up.**
- **Phase 25:** one local commit on top (hash in the final report), not
  pushed.

## B. Human evidence update — N52

Recorded in `data/dev/extreme90_p24/human_p24.json` (fingerprint
`919ec171…866f86`). The two first exposures are kept separate from the
replay:

| | Rating | Timed | Attempts | Other |
|---|---|---|---|---|
| Player 1, first exposure | EXTREME | TIME UP at 90 s | 4 | enjoyment 5 / 5; completed in the untimed continuation |
| Player 2, first exposure | EXTREME | TIME UP at 90 s | 3 | |
| Player 2, **replay** (not an independent first exposure) | VERY HARD | COMPLETED ~40.2 s | 2 | enjoyment 5 / 5 |

**Decision (brief):** N52 is human-approved EXTREME under the current
internal acceptance policy. The Phase 25 page exports it in group
`approved`.

## C. Design concepts attempted

**Method.**
1. Each concept was designed as a reasoning dependency first.
2. Drafts were benched (`tools/ta90_bench24.gd`), then fully checked by
   `tools/extreme90_eval25.py` (new): bench, design report
   (`tools/ta90_design.gd`), filler (`tools/xb90_filler.gd`) and bank
   overlap in one pass.
3. **Hybrid path** (protocol in `data/dev/extreme90_p25/protocol.json`), for
   near-miss hand designs:
   - the design was frozen cell for cell as a core;
   - `tools/ta90_search.gd --ops=v20` (unchanged) was allowed only to add
     blocks around it;
   - every result was then re-checked in full, and its core checked by hand
     on the Solver's line.

All drafts are in `data/dev/extreme90_p25/design_log.json`.

| # | Concept (hand-designed core) | Mechanics | Result |
|---|---|---|---|
| 1 | **Sequence relay**: each Sequence pusher pushes the crate once; tapping it early wastes the push; the crate travels a route and back (Q1a–Q1l) | crate + Sequence | **N58** (hand); 11 revisions, **3 over the budget of 8** |
| 2 | **Rescue magnet**: a magnet pulls a stuck pusher out of the crate's line (R1a) | crate + magnet | **impossible**: magnets are allowed only on boards without crates or portals (the reason the pair never occurs) |
| 3 | **Crate brake and shuttle**: a gate stops the crate; reversed pushers shuttle it (G1a–c) | crate + gate + switch | stopped: every waiting block needs its own forcing element; the bypasses could not be closed by hand |
| 4 | **Crate route** (Phase 24's B9a, 12 moves) as a hybrid core (H1) | crate + spinner | **N57** |
| 5 | **Parity at unlock** (Phase 24 C6) and **two cycles** (C2) as hybrid cores (H2, H4) | switch + lock (+ gate) | 0 qualifying boards in 4 runs: switch structures again unproductive |
| 6 | **Shared key, two counts**: two locked spinner rammers share a key; each must ram after an exact number of neighbour departures (SL, SL2 → H5) | spinner + lock + armor | **N53** |
| 7 | **Remote crack through a portal** (Phase 23 K2 core, H6) | portal + armor + switch | stopped: the only cheap board overlaps N31 0.41, 0 in the second seed |
| 8 | **The prisoner**: a locked block is pulled into place before its last key leaves (PR1–PR3 → H7) | magnet + lock + armor | stopped: every board needs a filler key, and without it the lock is decoration |
| 9 | **Two-stage remote rammer** (SP1) | portal + Sequence + armor | stopped at the first draft: no losing move exists (nothing can bring a target into a Sequence rammer's lane later) |
| 10 | **The gate's links aim the spinner** (GS1, GS2 → H8) | spinner + gate + armor | **N54** |
| 11 | **The firing is the turn**: the switch piece is the spinner rammer's neighbour, so one firing turns the rammer onto the shell, flips the shell away from it and frees the flip target in its lane (SW1, SW2 → H9) | spinner + switch + armor | **N55** |
| 12 | **The turners are the brake**: the gate's links are the alternating-spinner pusher's turners, so the departures that open the gate re-aim the pusher (CG1, CG2 → H10) | crate + gate + spinner | **N56** |

## D. Generation statistics

**Hand drafts:** 28 benched boards, plus one re-check of the Phase 23 K2 board.

| Concept | Drafts |
|---|---|
| Q1 | 12 |
| G1 | 3 |
| SL | 2 |
| PR | 3 |
| SP | 1 |
| GS | 2 |
| SW | 2 |
| CG | 2 |
| R1 | 1 |

**Generator runs:** 16 runs (12 min each; batch 40, beam 5, patience 8,
`--ops=v20`), each over a frozen hand core:

| Core | Seeds | Qualifying boards (per seed) |
|---|---|---|
| H1 crate route | 31, 32 | 285, 96 |
| H2 parity at unlock | 31, 32 | 0, 0 |
| H4 two cycles | 31, 32 | 0, 0 |
| H5 shared key | 33, 34 | 157, 0 |
| H6 portal ram | 33, 34 | 5, 0 |
| H7 prisoner | 35, 36 | 277, 0 |
| H8 links aim | 37, 38 | 409, 451 |
| H9 firing is the turn | 39, 40 | 473, 824 |
| H10 brake | 41, 42 | 635, 585 |

**Budget record:**
- **Fixed in advance:** 6 runs, 3 cores.
- **Extended four times** as cores stopped, each extension recorded in
  `protocol.json` ("budget_extensions"): **16 runs in all**.
- **One amendment before the affected reports:** candidates are picked by
  solver cost first, because the top-scoring H1 board (1152 positions)
  failed the 40 ms TIME UP gate while cheaper qualifying boards existed.
- **Full evaluations:** **34**, including 8 re-evaluations after removing
  filler blocks by hand.
  - That is **more than the 12 reports fixed in advance**.
  - The overrun comes from the amendment's "up to 4 clusters per run".
  - It is reported here as a limitation.

## E. Accepted candidates (all TECHNICALLY QUALIFIED; none human-approved)

**What every row passes:**
- Category A AND B (HUMAN-REVIEW CANDIDATE);
- every mechanic essential;
- 0 filler;
- overlap < 0.40 with the whole bank and with each other (highest
  pairwise 0.32);
- exact TIME UP continuation including UNDO and RESTART (Ta90ContinueCheck);
- the dead-end check (Ta90DeadendCheck).

| ID | Concept | Mechanics | Fingerprint | Moves | Positions | Solve / TIME UP | Distinct | Decision steps | Effective decisions | Coverage / late | Greedy | Look-6 | Closest bank board |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N53 | shared key, two counts | spinner + lock + armor | `6a918b1b…` | 19 | 623 | 16.5 / 25.0 ms | 4 | 15 | 15 | 0.79 / 0.79 | 0.08 | 0 | N43 0.30 |
| N54 | the gate's links aim the spinner | spinner + gate + armor | `aab13f09…` | 17 | 393 | 5.0 / 4.3 ms | 5 | 14 | 13 | 0.82 / 0.82 | 0.05 | 0.175 | N25 0.38 |
| N55 | the firing is the turn | spinner + switch + armor | `10fd41a0…` | 17 | 186 | 1.9 / 3.9 ms | 4 | 15 | 10 | 0.88 / 0.88 | 0.01 | 0.008 | N21 0.32 |
| N56 | the turners are the brake | crate + gate + alternating spinner | `5d822d14…` | 18 | 190 | 7.6 / 5.8 ms | 6 | 16 | 14 | 0.89 / 0.89 | 0 | 0 | N21 0.38 |
| N57 | crate route | crate + spinner pushers | `0bac175e…` | 14 | 1066 | 31.5 / 29.4 ms | 5 | 11 | 11 | 0.79 / 0.79 | 0 | 0 | N52 0.21 |
| N58 | Sequence relay | crate + Sequence pushers | `ddfb46c2…` | 15 | 881 | 8.4 / 9.8 ms | 5 | 13 | 13 | 0.87 / 0.87 | 0.145 | 0.05 | N36 0.32 |

Full fingerprints, reports and filler results are in each record
(`data/dev/ta90_n53.json` … `ta90_n58.json`) and in
`data/dev/extreme90_p25/selected_metrics.json`.

**Essentiality counterfactuals (design report):**

| ID | Remove the spinners / Sequence | Remove the other mechanics |
|---|---|---|
| N53 | spinners: unsolvable | armor: 15 → 8 steps and 4 → 1 distinct; lock: 15 → 9 and 4 → 2 |
| N54 | spinners: unsolvable | armor: 14 → 7 steps; gate: 14 → 8 |
| N55 | spinners: unsolvable | switch: unsolvable; armor: 15 → 12 steps (exactly the 3-step minimum) |
| N56 | spinners: unsolvable | crate: unsolvable; gate: 16 → 2 steps |
| N57 | spinners: unsolvable | crate: unsolvable |
| N58 | Sequence: unsolvable | crate: unsolvable |

**What each one asks (from the verified Solver line, not the design
sketch):**
- **N53:** the left rammer may ram only after exactly 3 of its 4 neighbours
  have left, the right one after exactly 2.
  - The shared key counts for both, and also opens the right lock.
  - Added purple blocks are keys of the left lock.
  - The mistakes are the overshoot departures.
- **N54:** both gate links must leave before the spinner rams, which they
  turn onto the shell; its third neighbour must wait.
  - Added spinners make the links' timing matter earlier too.
- **N55:** the switch piece first rams an added shell, then fires.
  - That firing turns the rammer and reverses both the shell and the
    flip-target in the rammer's lane.
  - The rammer's other neighbour must stay to the end, and an added second
    switch piece must fire last.
- **N56:** added spinners push the crate first; the alternating-spinner
  pusher acts after one of its turners has left.
  - The mistakes include all three core traps: its third neighbour, a link,
    and the pusher itself at the wrong moment.
- **N57:** the crate goes down (pushed by a waiting block), up three times,
  then right once; each spinner's turner must wait for its pusher.
- **N58:** the crate is pushed right, up and right, pushed down twice, back
  up, and finally left. Five one-shot Sequence pushers and a Sequence blocker
  each have exactly one useful moment.

## F. Rejected candidates and reasons

| Candidate | Reason |
|---|---|
| Phase 23 K2 board minus its filler block | overlap 0.40 with N41 (the rule is strictly below 0.40); also only 5 effective decisions |
| H1 s31, top-scoring board | Category A: solve 46.9 ms, TIME UP check 66.0 ms (> 40) |
| H1 s31 c1–c4, untrimmed | 1–2 filler blocks |
| H1 c1t, c2t, c4t (filler trimmed) | timing (solve 45–59 ms or TIME UP 41–45 ms): the "filler" blocks were walls keeping the search small |
| H5 c1 | 1 filler block |
| H5 c3, c4 | qualified, but the same concept as N53 (one per concept) |
| H6 s33 c1 | overlap 0.41 with N31 |
| H7 c1–c4 | 1 filler block each (a purple key); with it removed, the report finds the lock is decoration |
| H8 c1 | 3 filler blocks |
| H8 c3 | overlap 0.41 with N25 |
| H8 c2 | qualified, same concept as N54 |
| H9 c2, c4 | armor not essential (only 1–2 decision steps fewer without it) |
| H9 c1 | 7 effective decisions, same concept |
| H10 c1 | 3 filler blocks; the gate not essential |
| H10 c2 | 1 filler block; overlap 0.40 with N2 |
| H10 c3 | qualified, same concept as N56 |
| Q1h | 2 filler blocks, late 0.71 |
| Q1j | TIME UP 45.8 ms |
| Q1k | the fifth stage bypassed (K pushes the crate itself) |
| All other drafts | unsolvable, bypassed or too few decisions (design_log.json) |

## G. Quality, novelty and diversity

**Novelty is the main risk, and it is stated plainly.** Every board has a
new *structure*, but each sits in an existing *mechanic family*:

| Board | Family | Closest bank concept |
|---|---|---|
| N58 | Sequence pusher | N44 |
| N57, N56 | crate + spinner ("push before you turn") | N33 |
| N53 | spinner counting with locks | N15, N14 / N43 |
| N54 | spinner beside a gate | N25 (archived) |
| N55 | one departure, several effects | N23 |

They are accepted by the standard applied to N52 versus N48: a new reasoning
structure over a known mechanic insight. N52 was then rated EXTREME twice.

I first rejected N58 as an N44 duplicate. I then re-examined it under that
same standard, and it is flagged rather than rejected.

**Diversity:**
- 3 crate boards (N56, N57, N58) and 3 spinner-aim boards (N53, N54, N55).
- No new magnet, portal, switch-only or lock-only board qualified.
  - Switch cores were unproductive in Phase 24 and again here.
  - Portal boards overlap the bank.
  - Magnets can't be combined with crates or portals at all.

**Why the hybrid worked where Phase 23's did not:**
- Phase 23's cores had one dependency each, and the generator bypassed them.
- The productive Phase 25 cores (H1, H5, H8, H9, H10) each have a built-in
  *window* the generator cannot remove: a spinner's exact turn count, or a
  crate's position.
- The by-hand core check found the core still deciding the line in every
  selected board.

**Human difficulty:**
- **Predictive features:** all six have 10–15 effective decisions and
  near-zero greedy and look-6 wins. In the Phase 23 study, effective
  decisions was the one feature that tracked human ratings.
- **N58** has the highest greedy share of the six (0.145).
- **N57** has the fewest moves (14).
- **Risk:** spinner and crate boards were rated anywhere from EASY (N20,
  N22) to EXTREME (N14, N33) in earlier phases, so only people can confirm
  these.

## H. QA results (exact)

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real
iPhone was used in Phase 25.**

**Builds:** dev build ("Web") and player build ("Web Friend Test") exported
from the working tree. The dev log lists all 6 new records; the player build
contains 0 `data/dev` files.

| Suite | Result |
|---|---|
| Browser `?extreme90p25=1` (new) | **106 / 106** |
| Browser `?extreme90p24=1` / `p22` / `p21` / `p20` / `p19` / the Phase 19 upgrade test | 94 / 94, 92 / 92, 84 / 84, 66 / 66, 62 / 62, 9 / 9 |
| Browser `?extreme90p18=1` / `?extreme90=1` (archive) / `?extreme90p17=1` / `?ta90=1` / `?tapilot` | 55 / 55, 45 / 45, 51 / 51, 55 / 55, 28 / 28 |
| Browser campaign timing and Personal Best | **33 passed, 0 failed** |
| Browser friend (player) build / stime / ttime (`?tta=1`, the 120 s page) | 25 / 25, 31 / 31, 32 / 32 |
| Extreme90p25Check (new) | **212 checks, pass** |
| Extreme90p24Check / p22 / p21 / p20 / p19 / p18 | 186 / 184 / 168 / 132 / 124 / 111 checks, all pass |
| Ta90ContinueCheck, all 44 selection boards incl. N53–N58 | **496 checks, 176 cases, 0 not resumed exactly** |
| Ta90DeadendCheck on N53–N58 | **42 checks, pass** |
| PortalCheck / MovableCheck / MagnetCheck | pass |
| Headless regression, the 19-suite runner | **18 pass**; RecipientTest fails, pre-existing (below) |
| — passing suites | competition, unit tests, timing, profile, experience lab, feedback, Challenge a Friend API 58 / flow 149, Social API / smoke / play, pilot 33, extreme11 74, Q1 time 37, R time 39, Ta90Check 91, Extreme90Check 91, Extreme90p17Check 97 |
| verify_levels | all 300 levels solvable, campaign rules pass |

**Details:**
- **What the `?extreme90p25=1` browser test covers:**
  - only CHALLENGE 1–6 (N53–N58) on the primary screen;
  - CHALLENGE 7–44 on PREVIOUS CHALLENGES;
  - each new board solved by touch in a timed run;
  - the SHORT questionnaire;
  - TIME UP with the exact untimed continuation;
  - the `ce-xb25` export;
  - the player build ignoring the page.
- **What the continuation check covers on every board:** the exact
  TIME UP restore, UNDO right after continuing, RESTART, a lost tap, and a
  dead end.

**WebAssembly full solve (the TIME UP check), headless Chromium:**

| Board | Time |
|---|---|
| N53 | 18.6 ms |
| N54 | 8.2 ms |
| N55 | 0.5 ms |
| N56 | 7.2 ms |
| N57 | **32.2 ms** (the slowest new board) |
| N58 | 8.1 ms |
| N52 | 38.8 ms (25.8 ms in Phase 24) |

N52's two figures show this machine's run-to-run variance.

**The QA run itself:** the combined batch B + C job hit the 2-hour
background limit after the `?extreme90p18=1` test. The three unfinished
browser tests (archive, `?extreme90p17=1`, `?ta90=1`) were rerun on their
own and passed (counts above).

**Known failure, reported separately:** RecipientTest. It is the same 3
layout checks ("TOTAL SCORE left, coins right", en_US / he_IL / ar_SA) that
have failed in every phase since Phase 16. Phase 25 changed no Social or
recipient code.

## I. Phase 25 QA ZIP

- **File:** `build/dev_qa/chain_escape_dev_extreme90p25_p25-qa1-20261030.zip`
  (14.9 MB, 9 files plus `BUILD_ID.txt`)
- **SHA-256:** `3da670950f0b61cc0cfa6a759b0198dae5a6d5c0901b187faab88e05991c153e`
- **Verification:** the archive tests clean; the pack contains the N53–N58
  records; there are 0 `data/dev` files.
- **Not uploaded** anywhere.

## J. Testing on itch.io

1. **Upload:** a **new** HTML5 upload (a new address, so Safari cannot reuse
   a cached build).
2. **Open:** `…/index.html?extreme90p25=1` on an iPhone.
3. **What the player sees:** CHOOSE A CHALLENGE shows CHALLENGE 1–6
   (N53–N58) and the build id `p25-qa1-20261030`. PREVIOUS CHALLENGES lists
   the 38 earlier boards (optional).
4. **The run:** for each board, one 90-second first-exposure run per player,
   with the unchanged protocol:
   - unlimited RESTART;
   - UNDO × 3;
   - no SHOW A MOVE, no HAMMER.
5. **Afterwards:** the 3 short questions, then optionally CONTINUE WITHOUT
   TIMER.
6. **Collect:** COPY ALL RESULTS gives the `ce-xb25` bundle (every run under
   its board id).
7. **Record per player and board:** rating, timed outcome, time, attempts,
   and whether the players are independent. Report a replay separately from
   a first exposure.
8. **Watch** whether N57, the heaviest new board, feels responsive on the
   phone. Its WebAssembly TIME UP check measured 32.2 ms in headless
   Chromium.

## K. Progress toward 50 human-approved EXTREME puzzles

| Status | Boards | Count |
|---|---|---|
| Human-approved (project classification) | CORE N3, N5, N7, N11, N13; STRONG N14, N15, N16, N18, N21, N26, N27, N29, N30, N31–N38; **N52** | **23** |
| — with a recorded EXTREME rating | N14, N15, N18, N21, N31, N32, N33, N35, **N52** (+ N3 as the reference) | 9 (+ N3) |
| Strong provisional | N48, N49, N51 | 3 |
| Human-tested, promising (provisional) | N23, N24; N39, N40, N42, N43, N44, N45, N47 | 9 |
| **Technically qualified, untested** | **N53, N54, N55, N56, N57, N58** | 6 |
| Downgraded / archived | N50; N41, N46; N17, N19, N20, N22, N25, N28; N1, N2, N4, N6, N8, N9, N10, N12 | 17 |

**Remaining to 50: 27.** None of N53–N58 counts until people approve it.

## L. Commit and risks

**The commit:**
- **Records:** `data/dev/ta90_n53.json` … `ta90_n58.json`.
- **Phase 25 data:** `data/dev/extreme90_p25/*` (protocol, seeds, runs,
  reports, design log, metrics).
- **N52 human evidence:** `data/dev/extreme90_p24/human_p24.json`.
- **Page:** `scripts/social/extreme90_p25.gd` and its hook.
- **Tools:** `tools/extreme90p25_check.gd` + `.tscn`, `tools/extreme90_eval25.py`.
- **Updated check lists:** `ta90_check`, `ta90_continue_check` and
  `web_extreme90_page_test`.
- **Docs:** this report.

**Risks:**
1. **Novelty** (G above): each board belongs to an existing mechanic family.
2. **Five of the six are hybrids.** Their cores are hand-designed, but their
   final shapes include generator blocks.
3. **Budget:** the report budget was exceeded (34 full evaluations against
   12), and concept 1 used 3 revisions over budget.
4. **iPhone performance of N57** is untested on a real device.
5. **Not pushed.**
