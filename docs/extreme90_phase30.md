# EXTREME Time Attack — Phase 30: human-difficulty improvement and quality-first generation

Development only. The following are untouched:
- Production and Supabase;
- the 300 frozen Classic levels;
- saves, timing and Personal Best;
- the 120-second Time Attack baseline;
- the Social MVP and Challenge a Friend;
- every gameplay mechanic.

There is no new mechanic and no Solver change. **Phase 30 is local only; it is not pushed.**

**Outcome: 5 technically qualified, conceptually distinct candidates, N78–N82.** This is the lower end of the 5–10 target, stated plainly.
- They are labelled TECHNICALLY QUALIFIED — HUMAN UNTESTED. Only the owner can approve them.
- Every technical gate is unchanged. Added: hint-follow progress, and an opt-in generator check that the hand core is not decorative.
- The full 24-run generator budget was used. Most cores failed for real reasons, all documented in F.

## A. Verified Phase 29 closure

- **QA:** the Phase 29 QA chain ran from 20:13 to 03:37, with no generator running alongside it.
  - Every test exited 0, except RecipientTest's 3 known layout checks ("TOTAL SCORE left, coins right", once each for en_US, he_IL and ar_SA), which are unchanged since Phase 26.
  - Results: `web_p29` 144/144; every earlier page from p17 to p28, plus archive, ta90, the p19 upgrade, tapilot, timing (timing and Personal Best), friend build, stime and ttime; all page checks; the continue check (705); the dead-end check (49); hint-follow 7/7; the xb28 validator; verify_levels (all 300 levels).
  - Full table: Phase 29 report J.
- **Commit and push:** Phase 29 was committed alone as **`7260dd7`**, on `3cea3bd`.
  - Push check: `origin` was an ancestor of HEAD, so a normal push was used, never a force-push.
  - After the push, the remote equals `7260dd7`. No Phase 30 file is in that commit.
- **ZIP:** the Phase 29 QA ZIP was rechecked by SHA-256 before the commit (`747688e8…d8ed`).

## B. Owner manifest: 35 / 50

- **New approvals:** N72, N75 and N77. Recorded in `data/dev/extreme90_p29/owner_decisions_n71_n77.json`, separately from the player ratings (`human_p29.json`), with fingerprints preserved.
- **Not approved:** N71 (EASY), N73 (HARD), N74 (MEDIUM), N76 (HARD).
- **Manifest** (`data/dev/extreme90_bank_status.json`): 35 approved, 3 strong provisional, 9 provisional, 1 borderline, 29 downgraded or archived, 0 untested. All 77 boards are classified exactly once. **15 remain.**
- **States kept apart:** owner approval, human rating, technical qualification (the records' design report) and release readiness are four separate records.
- **Release readiness:** green on headless Chromium for N72, N75 and N77; **no real iPhone was used.**

## C. Phase 29 prediction audit (advisory rank vs. owner decisions)

- **Origin of the flags:** they were fitted in Phase 29 on 19 earlier boards. That fit was 19/19 in-sample.
- **This test:** the Phase 29 candidates N71–N77 are the first boards the flags never saw.
- **Data:** `data/dev/extreme90_p30/prediction_audit_p29.json`.

| Board | Advisory flags | p_calm | gmax | look6 | forced | depth | Human rating | Owner |
|---|---|---|---|---|---|---|---|---|
| N71 | — | 0.000 | 0.000 | 0.000 | 0.18 | 11 | EASY | downgraded |
| N72 | — | 0.000 | 0.000 | 0.000 | 0.44 | 12 | EXTREME | **approved** |
| N73 | — | 0.006 | 0.042 | 0.025 | 0.53 | 9 | HARD | downgraded |
| N74 | simple_strategy | 0.019 | 0.008 | 0.075 | 0.21 | 6 | MEDIUM | downgraded |
| N75 | simple_strategy | 0.018 | 0.067 | **0.342** | 0.39 | 8 | VERY HARD | **approved** |
| N76 | simple_strategy | 0.009 | 0.058 | 0.083 | 0.26 | 9 | HARD | downgraded |
| N77 | simple_strategy | 0.038 | 0.083 | 0.108 | 0.35 | 7 | EXTREME | **approved** |

Prediction rule: "unflagged" means predicted to be approved.

| | Approved | Not approved |
|---|---|---|
| Unflagged (predicted approve) | TP = 1 (N72) | **FP = 2** (N71, N73) |
| Flagged (predicted not approve) | **FN = 2** (N75, N77) | TN = 2 (N74, N76) |

- **Accuracy:** 3/7. Precision of "unflagged" is 1/3; recall is 1/3.
- **By flag:** `simple_strategy` marked 4 boards, and 2 of them were approved, including N75, the board with the highest risk score. `linear` and `shallow` marked nothing in this set, so they were not tested.
- **Rejected boards:** 2 of the 4 rejected boards were flagged (N74, N76). The other 2 were not (N71, N73).
- **Did the layer add value beyond the technical gates?** **No, not on this evidence.**
  - All 7 boards passed every gate, and the flags did no better than a coin.
  - The worst miss is N71: every simulated simple player failed it (p_calm = gmax = look6 = 0), its dependency depth was 11, and people still found it EASY.
- **Caution:** with n = 7 this is not a verdict on predictive validity in general. It does show the 19/19 fit was over-fitted.

## D. Updated calibration method

- **Thresholds stay as they are.** They are not retuned to the 7 new boards; that would only over-fit again.
- **Flags stay visible but get weaker.** All advisory scores, including wrong ones, stay in every record and table. Flags now only break ties inside a concept.
  - They no longer decide which concept enters the page.
  - They are not used to rank concepts against each other.
- **New transparent prior: the family record.** This is the owner-approval rate per mechanic family over the 26 human-tested boards N52–N77 (`family_record_n52_n77.json`):

  | Family | Approved |
  |---|---|
  | turned magnet | 3/4 |
  | switch | 2/3 |
  | switch + lock | 2/3 |
  | magnet (not turned) | 2/5 |
  | crate | 3/8 (Phase 29 crate boards 0/3) |
  | other | 1/3 |

  Base rate: 13/26. These are raw counts with tiny samples. They are shown beside each candidate as context and weigh concept choice, never a gate.
- **What people seem to reward** (qualitative; the owner's ratings, not a model):
  - **Approved:** an *ordering* insight that can be lost permanently (a pull that parks a block, a reversal that sends a key the wrong way), with several plausible openings.
  - **Downgraded:** boards whose single insight, once seen, leaves a mechanical sequence. Examples: crate shuttles (N71, N73, N74) and two turned magnets on one switch (N76).
- **Not inferred:** restart, UNDO and move-sequence data were not supplied for any board, so nothing above uses them.
- **Time is not difficulty:** TIME UP alone is not treated as EXTREME, and elapsed time is not treated as depth of reasoning.

## E. Concept funnel

**Concepts:** 30 proposals in `data/dev/extreme90_p30/concept_funnel.json`. 13 advanced to hand cores; 17 were rejected before any generation.
- **Why rejected:** near-duplicates of recent approvals (turned magnets), families of downgraded boards (crate shuttles, two turned magnets), engine-impossible combinations, and monotone sets.
- **Not pursued:** concepts whose hand core could not be drawn solvable.
- **Cores built and benched before generation:** 16 (13 concepts plus 3 revisions). Every core was checked for valid tokens and benched for solvability before any generator time was spent.
- **Three cores needed fixes during drawing:**
  - T05 and T14: armor needs a ram, so a rammer was added;
  - T12: a Sequence first stage needs a clear lane, so the core was redrawn.

## F. Generator and screening report

**Pipeline:**
- Phase 28 generator: token guard, strict essentiality including spinners.
- **New `core_essential`** (`tools/ta90_search.gd`, opt-in, development only). A board whose frozen hand-core piece is a trivial removal does not qualify. Runs report `core_refused`.
- **Screen:** `tools/extreme90_screen30.py`. It runs screen28 (tokens, overlap, the 40 ms gates, strict essentiality, filler) and then **hint-follow**.
- **Advisory rank:** a tie-break inside a concept only.
- **Full evaluation:** one output directory per board.
- **Job control:** every job runs through **`tools/extreme90_jobs30.py`**. It tracks the PID and exit code, writes a `DONE` marker, refuses shared output directories and never re-runs finished jobs. A screen or evaluation is never run beside a generator.

| Round | Run (RNG) | Qualifying | Core refused | Result |
|---|---|---|---|---|
| 301 | T01 pulled trigger | 0 | – | stalled at 3 distinct mistakes |
| 301 | T03 pull the key | 0 | – | 3 distinct mistakes |
| 301 | T05 armored link | 0 | – | 3 distinct mistakes, late 0.72 |
| 301 | T10 key ladder | 74 | – | **all 46 screened boards: the core prisoner and target were filler** |
| 301 | T12 Sequence trigger | 0 | – | 3 distinct mistakes, coverage 0.55 |
| 301 | T14 two triggers | 356 | – | **all 80 screened boards: the core rammer was filler** |
| 301 | T27 trigger link | 0 | – | 3 distinct mistakes, a mechanic not essential |
| 302 (refinement) | T10b, T05r, T01r, T03r, T27r, T30 | 0 each | 0 | best boards: 3–6 distinct mistakes, but a mechanic not essential (T05r, T03r) or too few distinct mistakes; T30 had a 58% shortcut |
| 302 | **T14b** | **472** | 0 | screen 10/10 PASS |
| 302 | **T12r** | **67** | 1 | screen 9/10 PASS |
| 303 | T48 boomerang door (×2) | 0, 0 | 0 | 2 distinct mistakes, a mechanic not essential |
| 303 | **T43** crossed triggers (×2) | **469, 85** | 1, **75** | screen 9/10 PASS |
| 304 | T57 two effects (×2) | 0, 0 | 0 | 2–3 distinct mistakes, shortcut 12–15% |
| 304 | **T59** aimed ram (×2) | **501, 254** | 1, 0 | screen 6/10 PASS |
| 305 | **T61** boomerang ram | **393** | 1 | screen 6/10 PASS |

- **Key finding of the phase:**
  - Round 301 "qualified" 430 boards, and **none** were usable: in every one the designed core was decorative.
  - The `core_essential` check moved this rejection into the search. After it, screens passed 40 of 50 boards, against 0 of 16 before.
  - **Generated volume is not evidence of anything.** The 74 / 356 counts were empty.
- **Screens:** 66 boards screened.
  - 40 PASS;
  - 25 filler, including the 16 round-301 core-filler boards;
  - 1 greedy shortcut of 22%.
  - No hint loop was found on any PASS board, and no board was unsolvable.
- **Full evaluations:** 10 of 40, all isolated in their own directories with no generator running. All 10 met A and B.
- **Erratum (found in the Phase 31 audit, before this commit):** `protocol.json` specified `--ops=v20`, but **no Phase 30 generator command carried the flag** (`jobs_round30*.json`).
  - Every Phase 30 run therefore used the **baseline** operators; each `run.json` records `"generator": "baseline"`.
  - The same omission applies to Phase 29 round 92.
  - The board records N78–N82 and `selection.json` now state this; `protocol.json` carries the erratum.
  - Boards, fingerprints and gates are unchanged. The tested ZIP still holds the original record text (section K).
- **Budget:** 24 of 24 generator runs; 10 of 40 full evaluations.
  - Rounds 301 and 302 were the initial search plus the one focused refinement.
  - Rounds 303–305 used the remaining initial budget on **new** concepts only. Failed cores were not refined again.

## G. Five new technical candidates

CHALLENGE 1–5 = N78–N82. Records `data/dev/ta90_n78.json` … `ta90_n82.json`; fingerprints in `data/dev/extreme90_p30/fingerprints.json`.

| ID | Source | Concept | Mechanics | Family prior (D) |
|---|---|---|---|---|
| **N78** | T43_8 | **crossed triggers**: two switch GROUPS; each piece is held by the other group's flip target, so the order of the two reversals decides which lanes open | switch, spinner | switch 2/3 |
| **N79** | T14b_4 | **two triggers, one group**: two switch pieces fire the same reversal, so an armored target faces back after both - parity and which shell is cracked when | switch, armor, spinner | switch 2/3 |
| **N80** | T12r_9 | **the boomerang guards the reversal**: a Sequence block in the target's lane; its launch-and-return and new arrow must be ordered around the switch | Sequence, switch, spinner | — (Sequence + switch is new) |
| **N81** | T59_4 | **the aimed ram**: the only rammer that can crack the shell is a flip target; the reversal decides whether it rams or leaves, and once gone nothing can crack it | switch, armor, spinner | switch 2/3 |
| **N82** | T61_1 | **the boomerang cracks the shell**: a Sequence block's second lane runs into an armored flip target, so its escape is the ram | Sequence, switch, armor, spinner | — |

**Expected human-difficulty risk** (stated per board; not a prediction):
- **N78:** the lowest simple-player scores of the set (gmax 0.017, no flag). Risk: once the crossing is seen, the rest may be a forced sequence (forced share 0.39).
- **N79:** close to approved N75, with two switch pieces. Risk: the family is approved, so this may feel like a variant of N75. Flagged `simple_strategy` (p_calm 0.014).
- **N80:** the longest solution (22 moves) and the deepest dependency (depth 13). Risk: a Sequence block has a learning cost and may read as tedious rather than hard.
- **N81:** the "aimed ram" is a single, delayed, irreversible decision, which is what approved boards share. Risk: look6 0.183 is high, so short planning may find it.
- **N82:** combines Sequence and armor. Risk: the Phase 28 Sequence x armor attempt was structurally weak, though this one has a reversal and passed every gate.

**Diversity, stated plainly:**
- All five are reversal-driven, from the switch family (the strongest, 2/3 approved).
- Two share Sequence (N80, N82); two share switch + armor (N79, N81).
- The mechanisms differ: crossing, parity, guarding, aiming, cracking.
- The largest pairwise overlap is **0.29**.
- No magnet board, no crate board.

## H. Full metrics and novelty audit (desktop)

| ID | Positions | Solution | Distinct mistakes | Steps | Coverage | Late | Shortcut | Solve ms | TIME UP ms | Bank overlap | Hint-follow |
|---|---|---|---|---|---|---|---|---|---|---|---|
| N78 | 774 | 18 | 5 | 14 | 0.78 | 0.78 | 0.017 | 3.1 | 26.0 | 0.35 N67 | PASS (18) |
| N79 | 791 | 19 | 6 | 16 | 0.84 | 0.84 | 0.035 | 16.1 | 13.3 | 0.32 N75 | PASS (19) |
| N80 | 562 | 22 | 4 | 18 | 0.82 | 0.82 | 0.050 | 2.4 | 26.2 | 0.36 N48 | PASS (22) |
| N81 | 528 | 18 | 4 | 14 | 0.78 | 0.83 | 0.050 | 2.4 | 11.1 | 0.32 N59 | PASS (18) |
| N82 | 791 | 17 | 4 | 13 | 0.76 | 0.76 | 0.033 | 15.9 | 15.4 | 0.33 N64 | PASS (17) |

- **Gates:** all five clear every one: distinct ≥ 4, steps ≥ 8, coverage ≥ 0.60, late ≥ 0.75, solution ≥ 13, shortcut ≤ 0.20, solve and TIME UP ≤ 40 ms, 0 filler, bank overlap < 0.40, every mechanic essential, engine-valid tokens, hint-follow progress.
- **Strict essentiality:**
  - spinners: unsolvable without them on all five;
  - switch: essential on all five;
  - armor: essential on N79, N81 and N82;
  - Sequence: essential on N80 and N82.
- **Advisory diagnostics** (rank29: p_calm / gmax / look6 / forced / depth / flags; shown, not used to reject):

| ID | p_calm | gmax | look6 | forced | depth | flags |
|---|---|---|---|---|---|---|
| N78 | 0.003 | 0.017 | 0.017 | 0.39 | 9 | none |
| N79 | 0.014 | 0.025 | 0.067 | 0.21 | 7 | simple_strategy |
| N80 | 0.013 | 0.058 | 0.025 | 0.41 | 13 | simple_strategy |
| N81 | 0.021 | 0.050 | 0.183 | 0.39 | 8 | simple_strategy |
| N82 | 0.022 | 0.033 | 0.117 | 0.29 | 6 | simple_strategy |

- **Backups:** the second evaluated board of each concept (T14b_5, T12r_5, T43_6, T59_1, T61_7) also passed everything. They are kept in `ev/`, not placed on the page.

## I. Dedicated Phase 30 QA page

**`?extreme90p30=1`** (`scripts/social/extreme90_p30.gd`, class `Extreme90P30`):
- **Main screen:** CHALLENGE 1–5 = N78–N82 only.
- **PREVIOUS CHALLENGES:** the Phase 29 page's 63 boards.
- **Storage and export:** own storage (`xb30_*`) and export (`ce-xb30`, selection `xb30-v1`), DEV BUILD `p30-qa1-20261031`.
- **Groups:** carry the owner decisions, N72 / N75 / N77 approved and N71 / N73 / N74 / N76 downgraded.
- **Rules unchanged:**
  - 90 s countdown;
  - unlimited RESTART;
  - UNDO ×3;
  - HAMMER 0;
  - SHOW A MOVE 0;
  - first-exposure tracking;
  - difficulty and enjoyment questions;
  - COPY ALL RESULTS JSON;
  - the exact TIME UP continuation.
- **Untouched:** every earlier page, the campaign and the 120-second Time Attack baseline.

## J. Complete regression report

Headless Godot 4.3 and headless Chromium at an iPhone SE viewport. **No real iPhone was used.** No generator or other CPU-heavy job ran during this QA (chain 08:50 → 18:11).

**Phase 30 development page and builds**

| Test | Result |
|---|---|
| Dev export / player export | OK (0 `data/dev` files in the player build) |
| `web_p30` (`?extreme90p30=1`): the 5 new boards solved by touches in timed 90 s runs, SKIP, questionnaire, TIME UP and continuation, export `ce-xb30`, WebAssembly TIME UP for every board | **PASSED 154/154** |
| Extreme90p30Check | PASSED (306 checks); re-run after the Phase 31 source-sentence erratum in the records: see below |
| Ta90DeadendCheck N78–N82 | PASSED (35 checks) |
| Hint-follow N78–N82 | 5/5 PASS |
| xb28_validate (EXTREME records valid, fingerprints unchanged; 300 Classic levels valid) | PASSED |
| Ta90ContinueCheck | PASSED (757 checks, 271 cases, 0 not resumed exactly) |
| PortalCheck, MovableCheck, MagnetCheck | PASSED |

**WebAssembly TIME UP** (headless Chromium, `web_p30` BENCH; the page's limit is 250 ms):
- N78 3.4 ms;
- N79 25.5 ms;
- N80 0.8 ms;
- N81 1.4 ms;
- N82 26.0 ms.

The heaviest board on the page is the older N57, at 44.6 ms.

**Earlier pages (regression), on the Phase 30 build**

| Page check (headless Godot) | Result | Browser test | Result |
|---|---|---|---|
| Extreme90p29Check | 288 | `web_p29` | 144/144 |
| Extreme90p28Check | 260 | `web_p28` | 130/130 |
| Extreme90p27Check | 226 | `web_p27` | 114/114 |
| Extreme90p26Check | 222 | `web_p26` | 112/112 |
| Extreme90p25Check | 212 | `web_p25` | 106/106 |
| Extreme90p24Check | 186 | `web_p24` | 94/94 |
| Extreme90p22Check | 184 | `web_p22` | 92/92 |
| Extreme90p21Check | 168 | `web_p21` | 84/84 |
| Extreme90p20Check | 132 | `web_p20` | 66/66 |
| Extreme90p19Check | 124 | `web_p19` + P19 save upgrade | 62/62 + 9/9 |
| Extreme90p18Check | 111 | `web_p18` | 55/55 |
| — | | `?extreme90p17=1`, `?extreme90=1` archive | 51/51, 45/45 |

**Other suites**
- Browser: `?ta90=1` 55/55; `?tapilot` 28/28; web timing (timing and Personal Best) PASSED; friend build 25/25; `stime` 31/31; `ttime` (tta) 32/32.
- Headless suites: 18 of 19 pass.
- **RecipientTest fails only its 3 known layout checks** ("TOTAL SCORE left, coins right" for en_US, he_IL and ar_SA). They are unchanged since Phase 26, so this is not a regression.
- **verify_levels: all 300 Classic levels are solvable and pass the campaign rules.**

**Re-run after the erratum.** The Phase 31 audit changed one sentence (the operator provenance, section F) in the five records and in `selection.json`. Maps and fingerprints did not change. Extreme90p30Check was re-run on the edited files: **PASSED (306 checks)**.

**Evidence:** `data/dev/extreme90_p30/qa/` (summary, suites, hint-follow log, WebAssembly bench).

## K. Downloadable QA ZIP

**`build/dev_qa/chain_escape_dev_extreme90p30_p30-qa1-20261031.zip`**
- **Size:** 15,592,134 bytes.
- **SHA-256:** `f6cc807ddfaaa83e65182f7b45eb58137bc0aae1242f84fa4256ec792e70be8e`.
- **Build:** DEV BUILD `p30-qa1-20261031`. Its `index.pck` is byte-identical to the build that passed `web_p30`.
- **Delivery:** attached in the Phase 30 conversation, and already played by the owner (Phase 31 human results).
- `build/` is not in Git.
- **Note on the erratum:** the dev pck includes `data/*.json`, so the tested ZIP still carries the original source sentence ("--ops=v20") in the five records. Maps, ids, fingerprints and gameplay are identical. The ZIP was deliberately not rebuilt: it is the build the owner tested.

**Playtest:** `index.html?extreme90p30=1` on a private draft or a local server, not Production. CHALLENGE 1–5 = N78–N82, protocol unchanged.

## L. Final local Phase 30 commit

- **Contents:** this commit holds only Phase 30:
  - the Phase 30 generator option (`core_essential`) and the job/screen tools;
  - the records for N78–N82 (with the Phase 31 provenance erratum);
  - `?extreme90p30=1` and its check and web test entry;
  - the QA evidence;
  - this report.
- **Base:** it sits on Phase 29 (`7260dd7`). It is a **local** commit; it is **not pushed** (Phase 31 brief).
- **Not in this commit:** all Phase 31 work, which stays separate:
  - `data/dev/extreme90_p31/`;
  - `docs/extreme90_phase31.md`;
  - `tools/extreme90_features31.py`, `tools/ta90_struct31.gd`, `tools/extreme90_exp31.py`, `tools/extreme90_sel31.py`.
