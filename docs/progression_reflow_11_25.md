# Early progression reflow: Levels 11–25 after the Opening Lab (audit + proposal)

**Status: proposal only.** No level, campaign, code or save change; the Opening Lab is not promoted.

**Baseline:** the human-validated Opening Lab 1–10 (`data/dev/opening_lab/`, commit `cd1dff7`).

## Method

Every production level 11–50 and lab level 1–10 was measured with the game's own analysis:
- `LevelAnalysis` difficulty and structural difficulty, the verifier's proxies;
- the full state-graph audit (`tools/human_audit.gd`): trap steps, deviation survival, forced moves, hidden dead-end depth, and k-look-ahead win rates.

All numbers are solver proxies, not human measurements.

Reference points from the lab:
- Lab Level 10 ("Clockwork") has difficulty **11.3** (structural 8.7): 10 blocks, 2 spinners, 1 hidden arrow.
- Lab Levels 7, 9 and 10 each contain one spinner-timing trap, visible within 2 moves.

## 1. Current production Levels 11–25

Abbreviations:
- **Diff / Struct:** difficulty / structural difficulty.
- **Dead ends:** typical / max moves until a lost board visibly locks. "Hidden" means at least 90% of them stay invisible for 3+ moves, beyond Undo.
- **Lock-only levels have no losing moves at all.** A lock only adds a dependency, like a plain arrow, so they are reading levels by nature.

| # | Name | Mechanics | Blocks | Diff / Struct | Teaches / tests | Redundancy with lab 1–10 | Verdict | Reason |
|---|---|---|---|---|---|---|---|---|
| 11 | Order Matters | 1 spinner | 5 | 7.6 / 6.6 | First spinner board where one wrong first move loses | **High.** Same lesson as lab 7 (spinner timing); its hint "Order matters now - look before you tap" almost repeats lab 3's; easier than lab 10 | **REPLACE** (retire) | The seam: a step back in difficulty and a repeated lesson |
| 12 | Quarter Turn | 1 spinner | 9 | 9.7 / 8.3 | Reading quarter turns; 2 trap steps, dead ends ~4/5 (hidden) | Medium: spinner-turn reading already practised in 7/9/10 | **REPLACE** (retire, or keep in reserve) | Below lab 10, no new idea; its slot is needed for a combination level |
| 13 | Wrong Way | 1 spinner | 11 | 12.3 / 10.7 | A turn sends a block the wrong way; dead ends ≤2 (fair) | Low | **REORDER → 11** | The natural next step: just above lab 10, fair failures |
| 14 | Pinwheel | 2 spinners | 13 | 12.3 / 10.1 | First board with two spinners; dead ends ~4/5 (hidden) | Low | **REORDER → 12** | "Two spinners": growth without a new rule |
| 15 | Tight Squeeze | 1 spinner | 10 | 13.4 / 11.9 | Dense 4×4; 3 trap steps; dead ends ~5/6 (hidden); 4-move look-ahead wins 65% | Low | **REORDER → 15** (WATCH) | Good challenge; the deepest early hidden dead ends, so watch in playtests |
| 16 | Locked | Lock intro | 5 | 5.0 / 3.7 | Lock (onboarding text travels with the level file) | None | **REORDER → 13** | Lock earlier (see §3) |
| 17 | Second Thoughts | 2 spinners | 14 | 14.5 / 12.1 | Big board, almost no traps (random tapper wins 97%) | Low | **REORDER → 21** | Satisfying long cascade: the breather after the Chapter 2 finale |
| 18 | Key Colors | 2 locks | 9 | 8.7 / 6.2 | Two lock colours | None | **REORDER → 14** | The Lock application right after the intro |
| 19 | Crosswind | 2 spinners | 15 | 17.9 / 15.4 | Challenge; 4 trap steps; dead ends ~6/8 (hidden) | Low | **REORDER → 18** | Chapter 2's spinner challenge |
| 20 | Fog | 3 hidden (mystery) | 11 | 9.8 / 6.8 | Several hidden arrows; no losing moves | Medium (hidden learned at 8–10; three at once is new) | **REORDER → 17** | Too easy for a Chapter finale now; a good breather |
| 21 | Knots | 2 spinners (adjacent) | 13 | 20.3 / 17.9 | 6 trap steps; dead ends ~7/10 (all hidden); rule + 2-move look-ahead wins 51% | Low | **REORDER → 22** (WATCH) | The hardest-to-read board of 11–25: keep as a late challenge, watch |
| 22 | Padlocks | 2 locks | 11 | 11.3 / 8.7 | Locks in a chain; single path | None | **REORDER → 19** | The breather right before the finale |
| 23 | Clockwork | 3 spinners | 16 | 20.8 / 17.7 | Three spinners | Low; **name clash** with lab 10 "Clockwork" | **ADAPT (rename only) → 24** | Pre-peak challenge |
| 24 | Combination | 3 locks | 12 | 11.7 / 8.1 | Three lock colours | None | **REORDER → 23** | Lock mastery as the breather before the peak |
| 25 | Gridlock | 3 spinners, first 6×6 | 20 | 21.0 / 17.5 | Biggest board yet; dead ends ~7/10 (hidden) | None | **KEEP 25** | The hardest of 1–25 and a scale novelty (first 6×6) |

Findings:
- **Repeats:** 11 and 12 repeat what lab 7/9/10 already taught, at lower difficulty. 13–15 continue the spinner thread at the right level.
- **Combinations:** production 11–25 never combines mechanics (spinner, lock and hidden each stand alone). Lock + spinner first appears at 36, spinner + hidden at 30, all three at 50. The lab already combined spinner + hidden at 9–10, so a single-mechanic stretch 11–25 would feel like "old tutorial content".
- **Hidden arrows:** they appear only on Chapter-end "mystery" levels (10, 20, 30, 40, 50). The lab moved hidden to 8–10, which leaves Fog (20) as an easy, trap-free Chapter finale.

## 2. Proposed progression map, Levels 1–25

Beats: **I** = introduction, **A** = application, **C** = challenge, **B** = breather, **N** = novelty (new interaction), **M** = finale / milestone. (Px = current production level x.)

| New # | Source | Mechanics | Diff | Beat | Intended feeling |
|---|---|---|---|---|---|
| 1 | Lab 1 | arrows | 1.5 | I | "I understand." |
| 2 | Lab 2 | arrows | 3.9 | A | "Blocks get in each other's way." |
| 3 | Lab 3 | arrows | 4.3 | C | "This makes me think." |
| 4 | Lab 4 | arrows | 5.0 | C | "I need to think." |
| 5 | Lab 5 | arrows | 5.8 | C (aha) | "Nice." |
| 6 | Lab 6 | **Spinner** | 4.4 | I | "There's more." |
| 7 | Lab 7 | spinner | 6.4 | A | "I understand the spinner." |
| 8 | Lab 8 | **Hidden** | 5.3 | I | "Another surprise." |
| 9 | Lab 9 | spinner + hidden | 8.3 | A | "I can combine." |
| 10 | Lab 10 | 2 spinners + hidden | 11.3 | M (Chapter 1 card) | "Done with the basics." |
| 11 | P13 Wrong Way | spinner | 12.3 | C | "I'm getting better." |
| 12 | P14 Pinwheel | 2 spinners | 12.3 | C | "It keeps growing." |
| 13 | P16 Locked | **Lock** | 5.0 | I | "Something new." |
| 14 | P18 Key Colors | 2 locks | 8.7 | A | "I get locks." |
| 15 | P15 Tight Squeeze | spinner | 13.4 | C | "Back to the spinner, harder." |
| 16 | **NEW-A** | lock + spinner | ~13–15 | N | "Several things to think about." |
| 17 | P20 Fog | 3 hidden | 9.8 | B | "A calm one." |
| 18 | P19 Crosswind | 2 spinners | 17.9 | C | "That was hard." |
| 19 | P22 Padlocks | 2 locks | 11.3 | B | "Breathe." |
| 20 | **NEW-B** | hidden + lock (+1 spinner), mystery | ~17–19 | M (Chapter 2 card) | "I combined everything." |
| 21 | P17 Second Thoughts | 2 spinners | 14.5 | B | A big satisfying cascade |
| 22 | P21 Knots | 2 spinners | 20.3 | C | "I'm mastering this." |
| 23 | P24 Combination | 3 locks | 11.7 | B | Lock mastery |
| 24 | P23 (renamed) | 3 spinners | 20.8 | C | "Almost there." |
| 25 | P25 Gridlock | 3 spinners, 6×6 | 21.0 | **Peak** | "I achieved something. What's next?" |

**Introduction points:**
- Spinner 6, hidden 8, lock 13.
- New interactions: spinner + hidden at 9, lock + spinner at 16, hidden + lock at 20.
- Scale novelty at 25 (first 6×6).

That gives a discovery every 2–5 levels, never two new rules in a row.

**Chapter averages** (the verifier needs +2 per Chapter): C1 5.6 → C2 ~12.3 → C3 ~18.6 → C4 27.4 (unchanged). Production today is 4.7 / 11.1 / 18.2 / 27.4.

**Waves:**
- 11–12 rise above lab 10 (no seam).
- 13 is a deliberately small intro, as in the lab (6, 8).
- 14–16 climb.
- Breathers at 17, 19, 21 and 23 alternate with challenges at 15, 18, 22 and 24.
- The Chapter 2 finale is at 20, and the peak at 25.

## 3. Recommendations

- **Lock: first appear at Level 13.**
  - It gives two consolidation levels after the opening (11–12, both above lab 10) as breathing room after hidden.
  - That leaves gaps of 5 and then 3 to the next discoveries, against a 7-level gap to the old position at 16.
  - At 12 there would be only one consolidation level after Chapter 1. At 14–16, 11–15 would be a spinner-only stretch.
  - Lock's onboarding is level data (its hint plus the locked-tap message), so moving it needs no code.
- **Current Level 11: retire it.** It is redundant with lab 7 and easier than lab 10. P12 (Quarter Turn) is also retired, or kept in reserve; it is the weakest remaining spinner board.
- **Preserved but moved:** 12 of the 15 existing boards (P13–P24, with P23 renamed). P25 stays in place. P11 and P12 leave 1–25.
- **New layouts: two.**
  - **NEW-A (16), first lock + spinner:**
    - Shape: about 10–12 blocks, 4×4 or 5×5, 1 spinner and 1 lock colour, difficulty about 13–15.
    - The insight: the spinner's turn decides when the key colour can leave.
    - Rules: dead ends visible within 3 moves, no innocent-escape traps, and the rule + 4-move look-ahead player should win at least 20% (the 301+ rules from the human audit).
  - **NEW-B (20), Chapter 2 mystery finale:**
    - Shape: about 12–14 blocks, 5×5, hidden + lock + at most 1 spinner, difficulty about 17–19, mystery styling (keeping the "Chapter end = mystery" convention).
    - Rules: the same fairness rules as NEW-A.

## 4. Minimum redesign

| Option | New layouts | Other changes | Trade-off |
|---|---|---|---|
| Strict minimum | **1** (NEW-A at 16) | Fog stays the Chapter 2 finale at 20 | A weak, trap-free finale at 20 |
| **Recommended** | **2** (NEW-A at 16, NEW-B at 20) | **1 rename** (P23) | Fixes the finale |
| Avoid | 0 | Reorder only | No lock combination before 36, so 13–35 becomes a combination desert, and the Chapter 2 finale is trivial |

Promotion would also retire the old 1–10 (the lab already reuses their two intro boards) and P11–P12. Every other board is reused as is.

## 5. Consequences for Levels 26–50 (no redesign proposed)

1. **No numbering shift.** 1–25 keeps 25 slots, so 26–50 keep their numbers, and the 25 → 26 step is the same as production today.
2. **Pre-empted firsts.** Spinner + hidden (P30 "Smoke and Mirrors"), lock + spinner (P36 "Spin the Lock") and all three (P50 "Eclipse") are no longer firsts. They become applications, which is fine but changes what those levels "mean".
3. **Deeper troughs.** Lock-only levels P26, P28, P32, P34 and P49 (difficulty 12–17, no losing moves) will feel like steeper troughs after a player has handled lock + spinner at 16 and 20. 26–34 is the likely next seam.
4. **Discovery gap 26–30.** After 25 the next new rules are the counter-clockwise spinner (P31) and the alternating spinner (P35), so 26–30 has no discovery.
5. **Existing spike.** P27 "Domino Line" (difficulty 26.0; random tapper wins 1.4%, 52% of steps forced) is a large jump right after 25 (21.0) / 26 (12.3). It exists today too.
6. **Name clashes.** P49 "Long Way Round" duplicates lab 5, and P23 "Clockwork" duplicates lab 10.
7. **Promotion side effects** (not design, but they need a decision):
   - `data/classic_board_keys.json`, the Friend generator's list of campaign boards to avoid, must be regenerated, because the set of Classic boards changes. The unit test enforces it.
   - Existing players' best scores and stars for Levels 1–25 are stored by level number, so they would attach to different boards.
   - Free SHOW A MOVE is 0 before Level 20 by design, so NEW-A must stay fair without hints.
