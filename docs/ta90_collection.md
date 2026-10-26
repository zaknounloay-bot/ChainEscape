# Phase 15: the 90-second collection, N4-N13 (development only)

`?ta90=1` now holds 13 puzzles. N1-N3 come from Phase 14, unchanged with their fingerprints (`docs/ta90_design.md`). N4-N13 are new.
- **The design targets are intentions, never ratings,** and players never see them.
- Every new board is a **HUMAN-REVIEW CANDIDATE:** it passed every technical check and its strategic checks, but its quality is not confirmed by people.

Tools: `tools/ta90_campaign_ref.gd` (new), plus `tools/ta90_design.gd` and `tools/ta90_search.gd`, both extended.
Data: `data/dev/ta90_collection/` holds the cores, seeds, every search log and result, every report, and the reference measurements. The boards are in `data/dev/ta90_n4.json` … `ta90_n13.json`.
Nothing here touches Production, the 300 levels, Supabase, the Social MVP, Challenge a Friend, the campaign timer, the 120 s pilot or the music system.

## 1. What the advanced campaign levels teach (read only)

Source: `data/dev/ta90_collection/campaign_ref.json` (`tools/ta90_campaign_ref.gd`).

| Level | Size | Pieces | Mechanics | Positions | Solution | Steps with a losing move | Distinct mistakes | Last losing step | Best greedy | Solve (desktop) |
|---|---|---|---|---|---|---|---|---|---|---|
| L100 "The Master" | 7×7 | 24 | cw / ccw / alternating / pattern spinners, locks, hidden, twins | 808 | 24 | 21 | **1** | 21 / 24 | **100%** (mobility) | 1 ms |
| L200 "The Grand Master" | 7×7 | 25 | every second-era rule: switches, gate, armor, locks, twins, hidden | 1153 | 26 | 24 | 3 | 24 / 26 | 0% | **50 ms** |
| L274 "Edge of Plan" | 7×7 | 17 | crates, portal, spinners | 622 | 21 | 16 | 4 | 16 / 21 | 0% | 35 ms |
| L297 "Deep Freight" | 7×6 | 17 | crates, twin, spinners | 2764 | 21 | 16 | 6 | 16 / 21 | 0% | **143 ms** |
| L300 "Every Way Out" | 7×7 | 23 | Sequence, portals, twins, spinners | 1174 | 27 | 25 | 3 | 25 / 27 | 77% (mobility) | 22 ms |

(The decision columns here are one-ply, from the game's own Solver; the Time Attack reports use exhaustive search.)

Lessons:
1. **More pieces is not more difficulty.** L100 has 24 pieces but **one** distinct mistake, offered for 21 steps. A player who always takes the move that leaves the most moves (the "mobility" greedy player) always wins it.
2. **Advanced levels keep risk alive almost to the end.** A losing move exists on 75-95% of their steps, and until 2-5 moves from the finish. N1 is free after step 6 of 11. N3, the family's EXTREME reference, has risk until step 11 of 13: its tension is sustained risk, not size.
3. **Size cost is in the Solver, not the board.** Every level has fewer than 2,800 positions, but L200 and L297 take 50-143 ms to solve on desktop. At TIME UP the page solves the 0:00 board once, so a board like L297 would freeze the result screen on a phone.

## 2. Board-size and mechanic constraints

- **Board size:**
  - The format allows 12×12 (`PuzzleDefinition.MAX_SIDE`).
  - The campaign never goes beyond 7×7. On an iPhone SE, 7 columns give tiles of about 47 CSS px; 8 would drop below the 44-point touch size.
  - **The collection uses 5×5 to 7×7.**
- **Runtime gate, unchanged:** the only Solver call in a 90 s run is the TIME UP check from the 0:00 board.
  - Category A requires it to take **at most 40 ms on desktop in EVERY reachable position**, lost positions included.
  - The tools use the Solver with a 20,000-node budget, tighter than the game's 60,000. Since Phase 15, a check that reaches the limit is a Category A failure.
  - Neither the budget nor the timeout was raised.
- **The analysis-size cap, made explicit:**
  - Phase 11's 700-position cap stood in for SHOW A MOVE's cost in a lost position. The 90 s mode has no SHOW A MOVE.
  - For HARD boards the cap is 1,500 positions and for EXTREME 3,000 (L297 has 2,764). Each report records the cap it used.
  - Parity in every position and the TIME UP gate still apply in full.
- **Mechanics usable in Time Attack:**
  - **Usable:** cw / ccw / alternating / pattern spinners, locks, switches, chain gates, armor, magnets, Sequence. All are implemented by `SocialPlay` and accepted by the format with the Time Attack page's dev flags.
  - **Twins: not usable.** `SocialPlay` has no pair move (only the campaign's `game_manager.gd` calls `remove_pair`), so a twin tap would remove one block of the pair.
  - **Portals: not usable.** `PuzzleDefinition.verify` rejects them outside the campaign.
  - **Crates: not used.** Phase 13 found the Solver overflowing the stack on crate boards, and L297 shows their solve cost.
  - **Hidden arrows: not used.** Guessing an arrow under a 90 s clock is the kind of unfairness the brief excludes.
  - No new mechanics and no new tutorials: each brief uses the existing one-line reminders.
- **A real test bug fixed:** the Phase 14 replay and TIME UP measurement handled only escapes and rams. They now dispatch every move exactly as `SocialPlay.tap` does (escape / Sequence advance / push / ram). Without this, a Sequence board's TIME UP cost would have been measured on the wrong positions.

## 3. The design checks (`tools/ta90_design.gd`), extended

- Categories A, B and C are unchanged from Phase 14. MEDIUM / HARD / VERY HARD keep their values, and HARD only gains a light coverage floor (N2: 0.69).
- **New targets:**

| Target | Distinct mistakes | Decision steps | Endgame decision | Coverage | Last losing step | Shortest solution | Greedy cap |
|---|---|---|---|---|---|---|---|
| EASY | ≥ 1 | ≥ 2 | — | — | — | — | 40% |
| HARD (added) | — | — | — | ≥ 45% | — | — | — |
| EXTREME | ≥ 4 | ≥ 8 | yes | ≥ 60% | ≥ 75% | ≥ 13 | 20% |

  - **Coverage** is the share of solution steps that have a losing move. **Last losing step** is that step's position as a share of the solution.
  - The EASY greedy cap is looser than the standard 20% because an easy board may be partly solvable by instinct.
- **EXTREME is anchored on N3.** My first draft (≥ 5 distinct mistakes, a 10% greedy cap) would have rejected N3, the board the family test confirmed as the EXTREME experience. Human evidence wins: N3 itself defines the floor (4 distinct, 11 steps, coverage 0.85, last losing step 0.85, 13 moves, greedy 15%).
- **New counterfactuals:** the pattern spinner and Sequence can now be neutralised to test whether they matter.

## 4. The ten boards

Key N<k> is PUZZLE k. The order mixes size and target on purpose, so position on the selection screen gives nothing away.

| PUZZLE | Key | Design | Target (hidden) | Size | Pieces | Mechanics | Strategic concept | Fingerprint |
|---|---|---|---|---|---|---|---|---|
| 4 | N4 | 15E1 | EASY | 5×5 | 9 | cw / ccw spinners | **Turn it once:** the blocked spinner must be turned exactly once before it leaves | `6adc71d670366c04f57bdef2f825990f930214ff63baa0a754f8d3362002c7e9` |
| 5 | N5 | 15M2 | MEDIUM | 6×6 | 13 | Sequence, cw / ccw / alt spinners | **The first step is a key:** the Sequence block's advance turns the trapped spinner | `3f420b14215a44aa1bb6b96c85be519ff1c247312a6300c444c673f43e650c40` |
| 6 | N6 | 15H1 | HARD | 6×7 | 13 | switch, armor, spinners | **Reverse the rammer first:** escaping it the easy way strands the shell | `d2850675394c1963e34a0986ece8010b83f81758aa4f3790ea8a93f686afecb0` |
| 7 | N7 | 15X2 | EXTREME | 7×7 | 21 | Sequence, armor, cw / ccw / alt spinners | **Aim with a Sequence step:** the advance turns a spinner onto the shell, inside a long, risky 23-move sequence | `a9465918d8f02112da791892a32c7e3ff2d79d8fe173c59b34b2d674d8e9587b` |
| 8 | N8 | 15M1 | MEDIUM | 6×6 | 12 | magnet, chain gate, spinners | **Open, then pull:** the magnet must wait for the gate, or the block behind it is stranded | `033745db265b1291d2b19f342fb679d5ec4708fcdffa29e660a72ce0d0161e01` |
| 9 | N9 | 15E2c | EASY | 6×6 | 9 | magnet, spinners | **The magnet frees a jam:** its departure pulls a deadlocked block into an open lane | `c631418dff67b0bf39bfb88411be0ec9abde6b41dad3cb13dcb181b91b5b75a3` |
| 10 | N10 | 15H3 | HARD | 7×7 | 14 | lock, chain gate, pattern spinner, spinners | **Unlock the link:** the gate's only link is locked by the green colour | `a5474adbd79311a651865a183c1094fd080bd65fe4b26bb4bc4bb1f80f8fddfe` |
| 11 | N11 | 15X1 | EXTREME | 7×7 | 17 | lock, chain gate, spinners | **A waiting lock keeps turning:** every neighbour that leaves while it is locked turns it; choose what to clear before the last key, so it faces the gate | `a92813074460913b95b9f54433ffd156ead01c04c1e5d357ad83ea380f8bf4fb` |
| 12 | N12 | 15M3 | MEDIUM | 6×6 | 11 | alternating spinner, armor | **Count the turns:** the alternating spinner faces the shell only after an odd number of turns | `52dffbaefdde0a4cd91cba51a37999cf238f705d06a9da42179400fe3357fbbd` |
| 13 | N13 | 15H2 | HARD | 7×7 | 16 | magnet, lock, spinners | **Pull, then turn:** the magnet brings a trapped spinner next to the key whose departure turns it | `9acdd496511edcd6e847217ec37d7029d7cc82a62d1f93258d7ac08b5d86c943` |

The four size families:
- **compact** (5×5 / 6×6, 9 pieces): N4, N9;
- **medium interconnected** (6×6, 11-13 pieces): N5, N8, N12;
- **large multi-mechanic** (6×7 / 7×7, 13-16 pieces): N6, N10, N13;
- **EXTREME experience** (7×7, 17 and 21 pieces): N11, N7.

No two boards of the collection (N1-N13) share more than 9% of their cells.

## 5. Results (`data/dev/ta90_collection/final_report.json`)

**Category A, technical: all ten pass.**

| Key | Positions | Solution | Parity (solve / hint) | Replay ×2 | Solve, desktop | TIME UP worst (desktop) |
|---|---|---|---|---|---|---|
| N4 | 39 | 9 | 0 / 0 | yes | 1.7 ms | 1.0 ms |
| N5 | 122 | 14 | 0 / 0 | yes | 4.9 ms | 2.2 ms |
| N6 | 268 | 14 | 0 / 0 | yes | 18.7 ms | 17.8 ms |
| N7 | 682 | 23 | 0 / 0 | yes | 5.2 ms | 18.9 ms |
| N8 | 242 | 11 | 0 / 0 | yes | 4.0 ms | 2.3 ms |
| N9 | 128 | 9 | 0 / 0 | yes | 6.3 ms | 3.8 ms |
| N10 | 183 | 13 | 0 / 0 | yes | 1.2 ms | 5.4 ms |
| N11 | 641 | 16 | 0 / 0 | yes | 12.5 ms | 9.3 ms |
| N12 | 82 | 12 | 0 / 0 | yes | 4.7 ms | 2.0 ms |
| N13 | 488 | 16 | 0 / 0 | yes | 11.9 ms | 12.2 ms |

The WebAssembly timings (headless Chromium) are in the QA report.

**Category B, strategic: all ten pass their target.**

| Key | Target | Idea on every winning line | Distinct mistakes | Decision steps (coverage / last losing step) | Endgame | Each mechanic neutralised | Greedy |
|---|---|---|---|---|---|---|---|
| N4 | EASY | (spinner order) | 2 | 7 (0.78 / 0.78) | yes | - (plain spinners) | 32% |
| N5 | MEDIUM | `advance_turn` | 4 | 12 (0.86 / 0.86) | yes | Sequence: 11, 4 (was 12, 4) | 1% |
| N6 | HARD | `reversed_ram` | 5 | 11 (0.79 / 0.79) | yes | switch: unsolvable; armor: 5, 4 (was 11, 5) | 2% |
| N7 | EXTREME | `advance_turn` + `shell_rammed` | 6 | 20 (0.87 / 0.87) | yes | Sequence: 16, 5 (was 20, 6); armor: 19, 6 | 0% |
| N8 | MEDIUM | `gate_pull` | 4 | 9 (0.82 / 0.82) | yes | magnet: unsolvable; gate: 9, 3 (was 9, 4) | 8% |
| N9 | EASY | (magnet pull) | 3 | 5 (0.56 / 0.56) | no (not required) | magnet: unsolvable | 10% |
| N10 | HARD | `gate_through` | 5 | 10 (0.77 / 0.77) | yes | lock: 6, 4 (was 10, 5); gate: 11, 5 | 0.5% |
| N11 | EXTREME | `key_turn` + `gate_through` | 4 | 12 (0.75 / 0.75) | yes | lock: 13, 4 (was 12, 4); gate: 12, 5 | 3% |
| N12 | MEDIUM | `alt_ram` | 4 | 9 (0.75 / 0.75) | yes | alternation: unsolvable; armor: 2, 1 (was 9, 4) | 4% |
| N13 | HARD | `moved_then_turned` | 5 | 11 (0.69 / 0.69) | yes | magnet: unsolvable; lock: 10, 4 (was 11, 5) | 0.5% |

In the mechanic column, "11, 4" means 11 decision steps and 4 distinct mistakes.

**Category C, estimates: diagnostic only.**

| Key | Target | Learners (look 4 / 6) | 6-move lookahead greedy | Deepest trap | Opening (good / legal) |
|---|---|---|---|---|---|
| N4 | EASY | 0 / 0 | 55% | 7 | 2 / 4 |
| N5 | MEDIUM | 2 / 0 | 8% | 12 | 2 / 5 |
| N6 | HARD | 4 / 0 | 1% | 12 | 2 / 5 |
| N7 | EXTREME | 6 / 5 | 0% | 17 | 3 / 7 |
| N8 | MEDIUM | **8 / 8** | 13% | 9 | 2 / 6 |
| N9 | EASY | 2 / 0 | 37% | 7 | 2 / 5 |
| N10 | HARD | 4 / 2 | 5% | 11 | 2 / 7 |
| N11 | EXTREME | **0 / 0** | 10% | 14 | 4 / 7 |
| N12 | MEDIUM | 1 / 1 | 10% | 10 | 2 / 4 |
| N13 | HARD | 6 / 5 | 3% | 13 | 3 / 6 |

## 6. Known weaknesses, board by board

- **N4:** plain spinners only: an order puzzle with no special mechanic (intended for EASY). A 6-move lookahead finds the way 55% of the time, which is fine for EASY but may be too easy.
- **N5:** the Sequence block changes the decision count only slightly (11 → 12 steps). Its role is clear, but its share of the difficulty is small.
- **N6:** the **slowest board.** Its solve (18.7 ms) and TIME UP check (17.8 ms) on desktop are under the 40 ms gate, but the highest of the collection; see the WebAssembly timing.
- **N7:** the armor barely changes the decisions (19, 6 without it; 20, 6 with it). It is part of the idea (`shell_rammed` on every line) but not of the difficulty. 21 pieces on 7×7 is the densest board; readability on an iPhone SE should be watched in the test.
- **N8:** MEDIUM by intent, but the learners suggest HARD (8 / 8).
- **N9:** EASY by intent, with 3 distinct mistakes and a 10% greedy: it may play like MEDIUM.
- **N10:** the gate changes the decisions only slightly (lock: strong).
- **N11:** EXTREME by intent, meeting N3's floor exactly (coverage 0.75 and last losing step 0.75 at the limit). Its learners find **0** dead ends, and the lock and gate move the decision counts only by 1. **It may play like HARD.** Of the two EXTREME boards, N7 has the stronger evidence.
- **N12:** strong mechanic evidence. It may play harder than MEDIUM.
- **N13:** none found beyond the general caveat.
- **All:** the targets are design intentions. The B checks encode what made P5 / P6 fail and what N3 did right; they are not proven to predict enjoyment.

## 7. Rejected candidates and effort

18,763 boards were evaluated by 17 bounded searches (1.2-12 minutes each, at most 4 at a time), plus full A / B / C reports on 15 candidates.

| Candidate | Why it was not used |
|---|---|
| E2 (first lock core) | the lock was decoration: its key always had to leave first anyway. Core redrawn as E2b. |
| E2b (lock bottleneck) | greedy 43% > 40% in the full report. A follow-up search with a stronger shortcut penalty did not improve. Replaced by a new idea (E2c, the magnet jam → N9). |
| X1 seeds 1 and 2 (first EXTREME lock core, 21-22 pieces) | the lock was decoration in both (17, 5 and 15, 6 unchanged without it). Core redrawn as "a waiting lock keeps turning" (X1b). |
| X1b seed 2 | the gate was decoration and only 3 distinct mistakes. |
| X2 seed 1 | **Category A:** solve 95 ms and a TIME UP check of 54.5 ms (> 40). The runtime gate was kept, not relaxed. |

## 8. The selection screen

13 puzzles no longer fit a list on an iPhone SE.
- The selection is now a **3-column grid of "PUZZLE n" tiles**, each with a short status: New / Continue / Solved 0:42 / Time up / Time up / solved, plus ×n for repeat plays.
- The REFERENCE (TA) row, shown only with `&ta90ref=1`, keeps its own full-width labelled row under the grid.
- No difficulty is shown anywhere. The full status sentence is still used for the reference row.
- Screenshots (iPhone SE size): `docs/ta90_collection_shots/` — the selection grid, PUZZLE 7 (21 pieces) and PUZZLE 11 in play.

## 9. Technical QA and regression (Phase 15)

- **The collection:**
  - `tools/ta90_check.gd` **91 / 91**: all 13 tiles on screen; N1-N3 fingerprints unchanged; the full timed flow with music on N1; every other board solved through the real page in a timed 90 s run under rules `ta90-v1`, with its export entry under its own key and fingerprint.
  - `tools/web_ta90_page_test.mjs` **55 / 55** (iPhone SE size, touch): a real-time 90 s game, the music stages and the calm mix, mute, background, reload, reduced motion, the 13-tile grid, N2-N13 solved by touch, and the player build ignoring `?ta90=1`.
  - The reference variant (`--board=TA`) **27 / 27**.
- **WebAssembly full solve** (the TIME UP check, headless Chromium, `&bench=1`):

  | Board | ms | Board | ms | Board | ms |
  |---|---|---|---|---|---|
  | N4 | 2.5 | N8 | 2.7 | N12 | 2.5 |
  | N5 | 2.4 | N9 | 4.7 | N13 | 7.7 |
  | N6 | 21.8 | N10 | 0.6 | N1 | 1.6 |
  | N7 | 7.8 | N11 | 23.9 | N3 | 0.6 |

  N2 measured 39.9 ms in this run against 19.8 ms in Phase 14, on the same board and code: this container's timing varies by up to about 2×.
- **Regression:**
  - all 300 levels solvable and passing the campaign rules;
  - unit tests, Timing, Competition, Profile, Feedback, the Experience Lab (levels 13 and 200), the Friend Challenge API, the friend flow, the Social API, the Social smoke test and SocialPlay;
  - the 120 s pilot (33 / 33 headless, 28 / 28 browser), Extreme11, Q1 and R1;
  - campaign timing and Personal Best (browser), the player build 25 / 25;
  - S1 31 / 31 and TA 32 / 32 in real time.
- **Pre-existing, not Phase 15:**
  - **RecipientTest:** the same 3 layout checks as before (en / he / ar).
  - **The S1 and TA browser tests in `--fast` mode** time out at "1:01 / 1:00". The **Phase 14 build fails identically today**, and both pages pass in real time, so it is the test's clock-rewind shortcut in this container, not the pages.
