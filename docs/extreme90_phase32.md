# EXTREME 90 — Phase 32: new candidates with the Phase 31 method

Development only. **Not deployed to Production.** Not touched:
- itch.io Production and Supabase;
- the 300 frozen Classic levels;
- the 90-second EXTREME rules and the standard 120-second Time Attack baseline;
- the exact Solver and the repository's generator;
- every gameplay mechanic.

Every acceptance gate is the Phase 30 / 31 gate, unchanged.

**Owner-approved EXTREME bank: 38 / 50 (12 remaining).**
- N83, N86 and N87 were approved in Phase 31.
- N84 and N85 were not approved.
- N82 is still pending an explicit owner decision.
- No Phase 32 board is approved: approval is the owner's decision after play.

**Labels:** the new boards N88–N93 were built as **TECHNICALLY QUALIFIED — HUMAN UNTESTED**. Owner decision (recorded at closure, section H): **all six NOT APPROVED** (N88–N91, N93 MEDIUM; N92 VERY HARD).

## A. Start of phase

**Phase 30 and 31 pushed** (owner instruction, before any Phase 32 work). The pre-push checks:
- the working tree was clean;
- HEAD was `22e57e1`;
- `5ab64b4` (Phase 30) is its ancestor;
- after a fresh fetch, the remote branch was still at `7260dd7`, so it had not advanced;
- exactly 2 local commits were pending.

A normal push moved `7260dd7..22e57e1`. There was no force-push and no divergence.

**Phase 32 stays local.** It is not pushed automatically.

## B. Method (fixed before generating)

The protocol is in `data/dev/extreme90_p32/protocol.json`. It was written before any Phase 32 generator run.

**Generation: the Phase 31 method, unchanged** (owner instruction).
- **Generator:** the one from commit `c1ddc89` (Phase 27), run in its own git worktree. The repository's generator is not used and not changed.
- **Settings:** `--ops=v20`, piece_free 13, max_pieces 17, suffix_rate 0.30, patience 8, 12 minutes, batch 40, beam 5.
- **Shortlist:** per run, the union of the two Phase 31 rules (`tools/extreme90_sel31.py`, 6 boards each).
- **Selection:** one board per concept, the one with the **fewest positions** among the boards that pass everything.

**Every modern technical check, unchanged, after generation:**
- engine-valid tokens;
- bank overlap < 0.40, against a bank that includes N78–N87;
- `tools/extreme90_screen30.py`: solve and TIME UP ≤ 40 ms, strict essentiality of every declared mechanic, 0 filler, hint-follow;
- the full evaluation `tools/extreme90_eval25.py --full`, with the gates: distinct mistakes ≥ 4, decision steps ≥ 8, coverage ≥ 0.60, late ≥ 0.75, solution ≥ 13, shortcut ≤ 0.20;
- pairwise overlap among the new boards ≤ 0.30;
- dead-end check and hint-follow on the page build.

**Budget:**
- **Round 1:** one 12-minute run per core, RNG seed 321.
- **Round 2:** RNG seed 322, only for cores with no screen-PASS board after round 1.
- **Evaluations:** at most 24 full evaluations.
- **No lowering:** if fewer than 5 concepts pass, the phase reports fewer. No gate is lowered and no filler is added.

**Tools:**
- `tools/extreme90_gen32.py` (job files);
- `data/dev/extreme90_p32/make_cores.py` (the cores);
- `data/dev/extreme90_p32/make_records.py` (the records).

## C. Cores

**Why these families.** The owner approved the lock and magnet families in Phase 31:
- N83, magnet × switch;
- N86 and N87, switch × lock.

The owner did not approve the armor-family or gate-family boards (N79, N81, N84). The new cores therefore stay near the approved families, but each carries a dependency the bank does not have.

| Core | Mechanics | The dependency |
|---|---|---|
| K01 two keys, two reversals | switch A, switch B, lock | each key faces its own prisoner and needs its own switch; switch A stands in key B's exit and blocks switch B, so the two reversals have an order |
| K02 the pulled prisoner | magnet, lock | the key and its prisoner block each other; only a magnet pulling the **prisoner** out of the key's lane breaks the deadlock |
| K06 the two-group ladder | switch A, switch B, lock | the key needs reversal A; its prisoner is itself a key and a flip target of B, and B's switch stands in the prisoner's exit |
| K08 the pulled target | magnet, switch | the magnet pulls the **flip target** into a new lane (N83 pulls the switch piece) |
| K16 the shelled key | armor, switch, lock | the key is armored **and** faces its own prisoner: it needs a ram and a reversal |
| K20 the relay pull | two magnets, lock | the first magnet pulls the second, and the second pulls the prisoner out of the key's row |
| T03r pull the key (Phase 30 core) | magnet, lock | rerun with a new RNG seed: in Phase 31 it produced a qualifying pool but no screen PASS |

**Core checks:** every core has engine-valid tokens and is solvable (`tools/ta90_design.gd --quick`).
- **K01:** the first draft had its two switches facing each other, which deadlocks the board. It was corrected before any run.

## D. Generation and screening (measured)

All runs exited 0 (`DONE` markers in `data/dev/extreme90_p32/runs/*`).

| Run | Evaluated | Qualifying | Engine-valid | Screen PASS | Smallest PASS |
|---|---|---|---|---|---|
| K01_s321 | 899 | 139 | 139 | 4 / 11 | 209 |
| K02_s321 | 1095 | 283 | 283 | 6 / 12 | 269 |
| K06_s321 | 1476 | 384 | 384 | 9 / 12 | 265 |
| K08_s321 | 1471 | 206 | 205 | 6 / 12 | 213 |
| K16_s321 | 1184 | 128 | 128 | 0 / 12 | — (not essential, overlap) |
| K20_s321 | 1287 | 274 | **12** | 0 / 8 | — (not essential) |
| T03r_s321 | 1174 | 289 | 289 | 2 / 9 | 217 |
| K16_s322 (round 2) | — | 202 | 199 | 1 / 12 | 935 |
| K20_s322 (round 2) | — | 222 | 222 | 3 / 11 | 449 |

- **K20 in round 1:** 262 of its 274 qualifying boards had engine-invalid tokens and were rejected by the token guard. That is a reliability fix working as intended.
- **Concepts:** 7 of 7 concepts produced at least one screen-PASS board (after round 2 for K16 and K20).

**Full evaluations:** 13 of the 24 allowed. 12 boards are HUMAN-REVIEW CANDIDATE. One failed:
- **K06_s321_2** (265 positions): shortcut 0.217 > 0.20.

## E. Selection

The rule: one board per concept, the fewest positions among the fully qualified boards, and pairwise overlap ≤ 0.30.

**The K08 / T03r conflict:**
- **The overlap:** every K08 PASS board overlaps the T03r board at 0.35–0.38 (both are magnet boards with a similar layout). K08_s321_0 also overlaps K01 at 0.36.
- **The rule applied:** fewest positions. T03r_s321_0 (217) is kept. The best K08 board that does not conflict with K01 (K08_s321_4, 296) still conflicts with T03r.
- **Result:** **K08 is set aside.** Its boards stay in `ev/` and `screen/`.

**Selected: N88–N93**, six concepts. The maximum pairwise overlap is **0.28**.

| ID | Board | Concept | Mechanics | Positions | Solution | Distinct mistakes | Decision steps | Coverage | Late | Shortcut | Solve ms | TIME UP ms | Bank overlap |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N88 | K01_s321_3 | two keys, two reversals | switch, lock, spinner | 209 | 16 | 5 | 14 | 0.88 | 0.88 | 0.108 | 4.4 | 7.6 | 0.35 N63 |
| N89 | T03r_s321_0 | pull the key | magnet, lock, spinner | 217 | 16 | 5 | 11 | 0.69 | 0.88 | 0.042 | 15.1 | 12.4 | 0.33 N84 |
| N90 | K02_s321_6 | the pulled prisoner | magnet, lock, spinner | 269 | 13 | 4 | 11 | 0.85 | 0.85 | 0.067 | 10.3 | 8.9 | 0.32 N22 |
| N91 | K06_s321_3 | the two-group ladder | switch, lock, spinner | 274 | 13 | 5 | 10 | 0.77 | 0.77 | 0.117 | 2.0 | 1.3 | 0.30 N38 |
| N92 | K20_s322_2 | the relay pull | magnet, lock, spinner | 449 | 14 | 4 | 12 | 0.86 | 0.86 | 0.042 | 21.4 | 16.2 | 0.31 N4 |
| N93 | K16_s322_11 | the shelled key | switch, lock, armor, spinner | 935 | 18 | 4 | 15 | 0.83 | 0.89 | 0.075 | 3.5 | 5.8 | 0.36 N83 |

(Solve and TIME UP are desktop measurements from the full evaluation. The WebAssembly measurements are in section G.)

**Pre-registered predictions** (recorded before any human play; **not used to select**; the owner is the judge):

| ID | Positions (fewer = harder?) | early3 (lower = harder?) | Tempting fatal openings (fewer = harder?) |
|---|---|---|---|
| N88 | 209 | 10 | 3 |
| N89 | 217 | 11 | 4 |
| N90 | 269 | 10 | 3 |
| N91 | 274 | 4 | 1 |
| N92 | 449 | 7 | 2 |
| N93 | 935 | 9 | 3 |

**Expected risks** (stated per board; these are not predictions):
- **N88–N91:** small boards (209–274 positions), the size range of the Phase 31 approvals (87–143). The early3 values of N88–N90 (10–11) are higher than any Phase 31 board's: they may open more gently.
- **N92 and N93:** larger (449 and 935 positions). The positions hypothesis would predict them the *least* hard of the six.
- **N93:** the only armor board. The owner did not approve the earlier armor-family boards (N79, N81).
- **N89:** the bank's closest board is N84, which the owner rated MEDIUM.

**Records:** `data/dev/ta90_n88.json` … `ta90_n93.json`.
- Each record carries the full design report, the structure measures (`structure31`), the prediction and a **`human_test` block**:
  - difficulty, enjoyment, 90-second outcome, solve time, attempts, restarts, Undo used, notes, owner decision;
  - all marked "not supplied" until the owner plays.
  - The page's COPY ALL RESULTS JSON carries time, restarts, Undo, moves and attempts per run. Nothing will be inferred.
- **Data files:** fingerprints in `data/dev/extreme90_p32/fingerprints.json`; selection in `selection.json`.

## F. Dedicated Phase 32 QA page

**`?extreme90p32=1`** (`scripts/social/extreme90_p32.gd`, class `Extreme90P32`):
- **Main screen:** CHALLENGE 1–6 = N88–N93 only.
- **PREVIOUS CHALLENGES:** the Phase 31 page's 73 boards.
- **Storage and export:** own storage (`xb32_*`) and export (`ce-xb32`, selection `xb32-v1`), DEV BUILD `p32-qa1-20261102`.
- **Groups:** the export carries the Phase 31 owner decisions:
  - N83, N86 and N87 → `approved`;
  - N84 and N85 → `downgraded`;
  - N78–N82 → `tested_no_decision`.
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
- **Untouched:** every earlier page, the campaign and the 120-second baseline.
- **Check:** `tools/extreme90p32_check.gd` (`Extreme90p32Check.tscn`), derived from the Phase 31 check with the offsets shifted by 6 and the new owner groups (16 approved, 17 downgraded, 5 played without decision).

## G. Complete regression report

All runs are headless (Godot desktop and headless Chromium at iPhone SE size), **not a real iPhone**. Evidence: `data/dev/extreme90_p32/qa/` (`regression_summary.txt`, `suites_summary.txt`, the logs).

| Area | Result |
|---|---|
| Phase 32 page `?extreme90p32=1` (browser) | **176 / 176** |
| Earlier pages p31 → p17 (browser) | 164, 154, 144, 130, 114, 112, 106, 94, 92, 84, 66, 62, 55, 51: all passed |
| P19 upgrade, archive page, `?ta90`, `?tapilot`, timing, friend build, stime, ttime tta | 9/9, 45/45, 55/55, 28/28, passed, 25/25, 31/31, 32/32 |
| Extreme90 phase checks p32 → p18 | all passed (p32: 350 checks) |
| Ta90ContinueCheck | 315 cases, 0 not resumed exactly (878 checks) |
| Portal, Movable, Magnet checks; Ta90DeadendCheck N88–N93 (42); hint-follow N88–N93 6 / 6; xb28 validate | all passed |
| Headless suites | 17 / 19 passed |
| All 300 Classic levels | solvable and pass the campaign rules |
| WebAssembly full solve (TIME UP check), N88–N93 | 4.5, 14.1, 8.0, 1.0, 11.3, 2.1 ms |

**The two suite failures:**
- **RecipientTest:** only its 3 known layout checks ("TOTAL SCORE left, coins right" for en_US, he_IL, ar_SA), unchanged since Phase 26; not a regression.
- **Extreme11Check (timing):** Q1 "SHOW A MOVE after 6 mistakes" measured **42.6 ms** against the unchanged 40 ms native-desktop gate. Investigated, not dismissed (`qa/extreme11_investigation.json`):
  - Two idle reruns: 39.7 ms (pass), **41.8 ms (fail)**. The gated chain halted.
  - Interleaved idle A/B, 5 runs each: Phase 31 baseline `22e57e1` 22.0–26.4 ms (5 / 5 pass); current tree 22.0–24.3 ms plus one **41.9 ms** (4 / 5). Fisher p = 1.0.
  - Component timing (8 × 6 measurements per configuration, both trees): the state save is never the cause (≤ 1.2 ms); the solver's work per mistake is the same on both trees (medians 3.0 / 17–19 / 2.2 / 21 / 7.5 / 1.6 ms); spikes over 30 ms occur on **both** (current 6 / 96, max 49.4; baseline 3 / 96, max 35.6; Fisher p = 0.50). No engine code changed since `22e57e1`.
  - **Conclusion:** sporadic scheduling stalls on the shared container, not a Phase 32 regression. **The 40 ms gate is unchanged.**
  - **Pre-registered strict rerun** (written before running; 3 runs, one CPU, real-time priority, idle machine, no retries): **34.2, 15.2, 16.6 ms — 3 / 3 passed.** A container restart came after run 1; only runs 2 and 3 were then run.
- **After the owner decisions were written into the N88–N93 records:** Extreme90p32Check rerun **passed (350)**, Ta90Check **passed (91)**; every fingerprint unchanged.

## H. Downloadable QA ZIP

**`build/dev_qa/chain_escape_dev_extreme90p32_p32-qa1-20261102.zip`** (attached in Phase 32; not committed, `build/` is ignored):
- 16,011,194 bytes, SHA-256 `7132c142ccc518a93738e1f9b3458678ed1a27d3455a8523b2908ae32d3c3532`;
- its `index.pck` is byte-identical to the tested build (SHA-256 `32acd1d5…fb28`);
- open `index.html?extreme90p32=1`.

**Note:** the ZIP was built before the owner decisions. Its six N88–N93 records still carry the pre-test label "HUMAN UNTESTED". The page never reads that field, and maps and fingerprints are identical, so the ZIP plays exactly as the repository. It is not rebuilt.

**Owner decisions (recorded in Phase 33, `owner_decisions_n88_n93.json`):** N88, N89, N90, N91, N93 MEDIUM; N92 VERY HARD; **all six NOT APPROVED (0 / 6)**. Records relabelled "TECHNICALLY QUALIFIED - HUMAN TESTED, NOT APPROVED", with `owner_decision` and `human_test` blocks. Bank stays **38 / 50**; N82 still pending.

## I. Final local Phase 32 commit

One **local** commit on top of `22e57e1` (Phase 31): the Phase 32 page, check and wiring; records N88–N93 with the owner decisions; `data/dev/extreme90_p32/` (protocol, cores, generator runs, selection, QA evidence); `tools/extreme90_gen32.py`; this report. **Not pushed, not deployed.** Phase 33 files are kept out of this commit.
