# Early-game progression audit: Levels 1–100 (boundary: Level 101, Switch)

**Status: audit and proposal only.** No level, campaign, code or save change; the Opening Lab is not promoted.

**Inputs:**
- The Opening Lab 1–10 (`data/dev/opening_lab/`).
- The 11–25 reflow (`docs/progression_reflow_11_25.md`), treated as the working candidate.
- For every production level 1–110:
  - `LevelAnalysis` difficulty / structural difficulty, block counts and spinner rules;
  - the full state-graph audit (`tools/human_audit.gd`): trap steps on the solution, deviation survival, forced moves, dead-end depth (typical / max moves until a lost board visibly locks), the share of losses beyond Undo's reach, and look-ahead player win rates.

All numbers are solver proxies, not human measurements.

Spinner rules: **cw** (clockwise), **ccw** (counter-clockwise), **alt** (alternating), **pat** (pattern). Hidden = mystery arrows.

## 0. What the data says about 26–100 (the structural findings)

1. **Each rule is introduced, then forgotten.**

   | Rule | Introduced | Next used | Gap |
   |---|---|---|---|
   | ccw | 31 | 61 | 30 levels |
   | alt | 35 | 63 | 28 levels |
   | pat | 52 | 71 | 19 levels |

   Between those points the game uses only cw spinners and locks. Each new rule gets one level and then disappears.
2. **Each rule's introduction is buried in a hard board.**
   - Lock (16) and the lab intros (6, 8) are small and gentle (difficulty 4–5).
   - The ccw intro (31) is difficulty 28.0, alt (35) is 32.6, and pat (52) is 39.0, each with hidden dead ends (typical 4–7 moves).
3. **61–100 is a 40-level plateau.**

   | Band | Mean difficulty | Spread within the band | Drops of 5+ points |
   |---|---|---|---|
   | 61–70 | 46.1 | 2.2 | 0 |
   | 71–80 | 49.9 | 0.9 | 0 |
   | 81–90 | 53.3 | 1.1 | 0 |
   | 91–99 | rising to 61 | – | 0 |

   - From 71, **30 of 30 levels** mix three or more spinner rules with 2–3 locks: the same recipe every time.
   - Typical dead-end depth is 6–18 moves, nearly all beyond Undo's reach.
   - A player looking 4 moves ahead wins 0–2%.
4. **Hidden arrows appear only on Chapter-end levels** (10, 20, …, 100), and those are *easier* than their neighbours.

   | Finale | Difficulty | Neighbours |
   |---|---|---|
   | 30 | 19.6 | 26.6 |
   | 40 | 28.6 | 36.9 |
   | 50 | 26.9 | 43.5 (47) |
   | 60 | 38.3 | 51.1 |

   The mystery fairness rule forbids hidden arrows from deciding a trap, so Chapter finales work as showcases, not peaks.
5. **Lock-only levels can't be lost,** so after a player has handled lock + spinner, Levels 26, 28, 32, 34 and 49 (difficulty 12–17) read as steps back. From 52, every level has locks.
6. **Password-like or extreme levels:**

   | Level | Problem |
   |---|---|
   | 27 | 52% forced, 17% of off-solution moves survive, 4-move look-ahead wins 16%; a spike right after 25–26 |
   | 29 | Dead ends 11.5 / 14 moves, 4-move look-ahead wins 1.7% |
   | 43 | Dead ends 12.2 / 16 moves |
   | 45 | 91% forced, 9% survive |
   | 59 | 91% forced, 11% survive |
   | 79 | 100% forced, 0% survive: a single line |
   | 83 | Dead ends 17.4 / 24 moves |
   | 88 | Dead ends 18.6 / 27 moves |
   | 51 | +21.7 difficulty over 50; 2-move look-ahead player wins 4.5% |

## 1. Progression map, Levels 1–100

Pattern used from Chapter 3 on:
- **x1** = the Chapter's discovery (or first combination);
- x2–x6 = application with waves;
- **x7–x9** = the Chapter peak;
- **x0** = the mystery showcase finale (fair, celebratory, Chapter card).

Chapter averages must rise at least 2 per Chapter (verifier rule).

| Ch | Levels | Discovery / focus | Applications | Breathers | Peak | Finale (x0) | Feeling |
|---|---|---|---|---|---|---|---|
| 1 | 1–10 | arrows, **spinner 6**, **hidden 8** | 7, 9 | 6, 8 (intros) | 10 | 10 (2 spinners + hidden) | understand → think → surprise |
| 2 | 11–20 | **lock 13**, **lock + spinner 16** | 14, 15, 18 | 17, 19 | 18 | 20 NEW (hidden + lock + spinner) | getting better, several things to think about |
| 3 | 21–30 | first 6×6 (25) | 22, 24, 27, 29 | 21, 23, 26, 28 | **25 (first milestone)** | 30 (spinner + hidden showcase) | mastering the chapter, then "what next?" |
| 4 | 31–40 | **ccw 31** | 32, 33 (adapted to ccw), 35–39 | 32, 34 | 37 / 39 | 40 (hidden showcase) | a new twist on a familiar piece |
| 5 | 41–50 | **alt 41** (moved from 35) | 42, 43 (adapted to alt), 44–48 | 43, 49 | 47 | 50 (all three + alt showcase) | everything together |
| 6 | 51–60 | **pat 51** (moved from 52) | 53, 55, 57 (adapted to pat) | 52 / 54 (wave) | 58 / 59 | 60 (showcase) | the last rule of the era |
| 7 | 61–70 | first **ccw + alt mixing** (existing) | 61–69 | 1 adapted breather | 69 | 70 | combination mastery |
| 8 | 71–80 | first **pattern mixing** (existing) | 71–79 | 1 adapted breather | 78 | 80 | combination mastery |
| 9 | 81–90 | large 7×7 boards | 81–89 | 1 adapted breather | 89 | 90 | endurance and mastery |
| 10 | 91–100 | the **Master trial** | 91–99 | 1 adapted breather | **100 (era peak)** | 100 Master | "I mastered an era" |

**Discovery points:**
- New rules: 6, 8, 13, 31, 41, 51 (each in its own Chapter from Chapter 4 on).
- New combinations: 9, 16, 20, 61, 71.
- New scale: 25 (6×6) and 81+ (7×7).
- Era change: 101.

## 2. Levels 26–50, level by level

Notes: the Px column is the board's current production level (Px). "Proposed" is the slot it moves to.

| Proposed # | Board (current #) | Mechanics | Blocks | Diff / Struct | Role | Redundancy with 1–25 | Verdict | Reason |
|---|---|---|---|---|---|---|---|---|
| 26 | Master Key (P26) | 3 locks | 12 | 12.3 / 8.7 | Post-peak breather | Mild: 3-lock reading also at 23 | **KEEP** | An intentional breather after the 25 peak; the only pure-lock level kept in 26–30 |
| 27 | Gatekeeper (P41) | 3 cw + 2 locks | 14 | 27.4 / 22.9 | Lock + spinner application | Applies 16 / 20 | **REORDER** | The fairest board of its range (dead ends 3.7, 4-move look-ahead 70%), in place of the Domino Line spike |
| 28 | Safe House (P28) | 2 locks (+1 spinner) | 16 | 12.8 / 9.6 → ~16–18 | Light application | Pure lock now reads as a step back | **ADAPT** | Turn one arrow into a spinner: still a breather, no longer "backwards" |
| 29 | Spin the Lock (P36) | 3 cw + 2 locks | 15 | 26.0 / 21.4 | Challenge | – | **REORDER** | Lock + spinner challenge with readable dead ends (3.6 / 6) |
| 30 | Smoke and Mirrors (P30) | 2 cw + 3 hidden | 17 | 19.6 / 15.1 | Showcase finale | No longer the first spinner + hidden (lab 9) | **KEEP** | Fair showcase (dead ends ≤2); a celebratory Chapter end |
| 31 | Twisted Lanes (P31) | **ccw intro**, 2 cw | 15 | 28.0 / 24.6 | Discovery | – | **KEEP** (watch) | Chapter start is the right moment; the intro board is hard (dead ends 6.1) |
| 32 | Vault (P32) | 4 locks (+1 ccw) | 17 | 13.9 → ~17 | ccw application, breather | – | **ADAPT** | One arrow → a ccw spinner: a breather that uses the new rule |
| 33 | Hairpin (P33) | 3 spinners (one → ccw) | 19 | 28.8 / 25.4 | ccw application challenge | – | **ADAPT** | Gives ccw an application; readable (4-move look-ahead 64%) |
| 34 | Strongroom (P34) | 4 locks | 17 | 16.8 / 11.9 | Breather | – | **KEEP** | The Chapter's single pure-lock breather |
| 35 | Domino Line (P27) | 2 cw | 13 | 26.0 / 23.6 | Challenge | – | **REORDER** (watch) | Off the 27 spike; narrow (52% forced), so watch |
| 36 | Tumblers (P38) | 2 cw + 2 locks | 17 | 26.7 / 22.4 | Wave dip | – | **REORDER** | Mid-wave |
| 37 | Rush Order (P37) | 4 cw | 19 | 35.5 / 31.7 | Challenge | – | **KEEP** | |
| 38 | Traffic Jam (P29) | 4 cw | 19 | 26.6 / 22.7 | Challenge | – | **REORDER** (watch) | Deep hidden dead ends (11.5) are too early at 29; better among peers |
| 39 | Labyrinth (P39) | 3 cw | 19 | 36.9 / 33.5 | Chapter peak | – | **KEEP** (watch) | 55% forced |
| 40 | Night Shift (P40) | 2 cw + 3 hidden | 19 | 28.6 / 23.9 | Showcase finale | – | **KEEP** | |
| 41 | Gearbox (P35) | **alt intro**, 3 cw | 21 | 32.6 / 28.0 | Discovery | – | **REORDER** (35 → 41) | Its own Chapter; 35 was only 4 levels after ccw, and alt then went unused until 63 |
| 42 | Whirlpool (P42) | 4 spinners (one → alt) | 20 | 38.1 / 34.1 | alt application | – | **ADAPT** | Application right after the intro |
| 43 | Turnstile (P43) | 3 spinners (one → alt) + 2 locks | 18 | 28.2 / 23.3 | alt application / dip | – | **ADAPT** | Also shorten its 12-move hidden dead ends |
| 44 | Chain Reaction (P44) | 5 cw | 23 | 39.5 / 34.6 | Challenge | – | **KEEP** | |
| 45 | Deadbolt (P45) | 3 cw + 2 locks | 14 | 34.0 / 29.5 | Challenge | – | **ADAPT** | Password-like (91% forced); open a second safe line |
| 46 | Key Ring (P46) | 4 cw + 3 locks | 20 | 34.2 / 27.8 | Challenge | – | **KEEP** | |
| 47 | Grand Tangle (P47) | 3 cw | 21 | 43.5 / 39.9 | **Chapter peak** | – | **KEEP** (watch) | The hardest of 1–50 |
| 48 | Lockstep (P48) | 4 cw + 2 locks | 20 | 34.7 / 29.1 | Post-peak | – | **KEEP** (watch) | 2-move look-ahead player wins 5% |
| 49 | Long Way Round (P49) | 3 locks | 18 | 17.4 / 13.2 | Pre-finale breather | Name clash with lab 5 | **ADAPT (rename only)** | |
| 50 | Eclipse (P50) | 3 spinners (one → alt) + lock + 3 hidden | 17 | 26.9 → ~30 | **Showcase finale** | No longer the first all-three (that is 20) | **ADAPT** | Showcase the Chapter's discovery (alt); the peak is 47 |

**Chapter averages after the change:** C3 ≈ 19.0, C4 ≈ 27.0, C5 ≈ 33.0. Production is 18.2, 27.4 and 32.4, so the +2 rule holds.

**The specific questions:**
- **25 → 26:** the 21.0 peak, then a 12.3 breather. Intentional.
- **The spike at 27:** Domino Line moves to 35, and Gatekeeper (fair) takes 27.
- **Lock-only dips:** keep one pure-lock breather per Chapter (26, 34, 49). Turn 28 and 32 into spinner-light breathers that apply the current rule.
- **ccw at 31:** stays.
- **alt at 35:** moves to 41.
- **Combinations at 30, 36 and 50:** 30 keeps a showcase role, 36's board moves to 29 as the lock + spinner application, and 50 becomes the alt showcase.
- **Level 50:** not a peak (47 is); see §6F.

## 3. Levels 51–100 by band

| Band | What is there now | Experience | Recommendation |
|---|---|---|---|
| 51–60 | **51 Great Escape** (6 cw, 25 blocks, 48.6) right after 50 (+21.7); **52 pattern intro** (39.0) inside a heavy board; 53–59 cw + locks only, climbing 38 → 51; 58 (67% forced) and 59 (91% forced) are narrow; 60 showcase (38.3) | The spike at 51; pattern introduced, then forgotten; narrow peak | **REORDER:** swap 51 ↔ 52, so pattern starts Chapter 6 and Great Escape follows at 52 (watch). **ADAPT:** 3 of 53–57 get a pattern spinner (e.g. 53, 55, 57); open a second line in 59 |
| 61–70 | First ccw + alt mixing with locks; 41.9–48.5; no breathers; dead ends 6–13 | Genuine novelty: the first real combination of rule variants. Flat, though | **ADAPT one breather** (simplify one board by about 10 points, e.g. 62); keep the rest |
| 71–80 | Pattern mixed into everything; 48.4–51.3 (spread 0.9); 79 is a single line (100% forced); 75 dead ends 13.8 / 21 | Combination novelty fades by ~76 | **ADAPT** 79 (open a line) and **one breather**; keep the rest |
| 81–90 | 7×7 boards, every level all four rules + locks; 83 / 88 dead ends 17–19 typical (24–27 max) | **Repetition risk:** identical recipe, no waves, the deepest hidden dead ends of 1–100 | **ADAPT** 83 and 88 (shorten dead ends) and **one breather**; optionally reorder so each level stresses one rule (Chapter "signatures") |
| 91–100 | The Master trial: 55 → 61 → **100 (67.7)**; 96 74% forced; dead ends ~10–14 | A purposeful final climb to the Master | **ADAPT one breather** (e.g. 92); **KEEP 100** |

**Is 52–100 a discovery desert?** Partly; see §6E.

## 4. Change budget (Levels 1–100)

| Kind | 1–25 | 26–50 | 51–100 | Total |
|---|---|---|---|---|
| Unchanged and in place | 1 (P25) | 11 | 37 | **49** |
| Reorder only | 11 | 6 | 2 | **19** |
| Minor adaptation (one or two tokens, a rename, or opening one line; re-verified by the solver) | 1 (P23 rename, also reordered) | 8 (one rename only) | 11 | **20** |
| New layouts | 10 lab (**already built**) + 2 (16, 20) | 0 | 0 | **12 (2 still to design)** |

Retired from 1–100: the old production 1–10 (the lab reuses their two intro boards) and P11–P12.

## 5. Minimum intervention for a coherent 1–100

1. **The new start** (≈25 levels touched, 2 new boards):
   - Adopt the lab 1–10.
   - Apply the 11–25 reflow: 2 new layouts, 12 reorders, 1 rename.
2. **Fix "introduce, then forget"** (≈3 reorders and ≈7 one-spinner rule changes):
   - Reorders: alt intro 35 → 41; pattern intro 52 → 51 (swap); Gatekeeper / Spin the Lock / Domino Line / Traffic Jam / Tumblers for the 27 spike.
   - ccw applications: 32 and 33.
   - alt applications: 42, 43 and the 50 showcase.
   - pattern applications: 53, 55 and 57.
3. **Rename the clash:** current Level 49.

That is **≈9 reorders + ≈9 minor adaptations** beyond 1–25, and **no new layouts** after 25.

**Recommended, not minimum:**
- 4 plateau breathers (one per Chapter 7–10).
- Password and dead-end fixes: 45, 59, 79, 83, 88.

These need human evidence first; the creator has played 1–100.

## 6. Explicit answers

- **A. Lock at 13:** **yes.** Lock appears in 65 of the 100 levels, so an early, clean introduction pays off. Minor point: 23 and 26 are both pure 3-lock breathers three levels apart, which is acceptable around the peak.
- **B. ccw at 31:** **yes** (a Chapter start), but it needs application levels. Today it is unused until 61, so adapt 32 and 33.
- **C. alt at 35:** **no, move it to 41.** 35 is only 4 levels after ccw, and alt is then unused until 63. At 41 it gets its own Chapter, applications at 42–43, and the 50 showcase.
- **D. Pattern around 52:** **yes, at 51** (swap with Great Escape, which also removes the +21.7 spike). It needs applications at 53–57; today it is unused until 71.
- **E. Is 52–100 a discovery desert?** **Partly, and not in the way suspected.**
  - 52–60 is a desert: cw + locks only, after pattern is shown once.
  - 61–75 is real novelty: the first actual use of ccw, alt and pattern, and their combinations.
  - The real problem is **76–100**: a flat plateau (spread about 1) of the same "all rules + locks" recipe, with no breathers and very deep hidden dead ends. That is a **pacing and repetition** problem, not a missing mechanic.
  - The evidence does not support moving Switch or adding a mechanic. Use breathers, Chapter signatures and the applications above.
- **F. Is Level 50 a strong peak?** **No as a difficulty peak:** 26.9 is below 8 of the 9 other Chapter 5 levels; 47, Grand Tangle at 43.5, is the real peak. After the reflow it is also no longer the first all-three combination (that is 20). It works as a **showcase finale** if it shows the Chapter's discovery (alt). Adopt "peak at x7–x9, showcase at x0" as the explicit pattern.
- **G. Is Level 100 a strong end-of-era peak?** **Yes:**
  - 67.7, +6.6 over 99, verified as the hardest of 1–100;
  - every rule plus hidden ("Every rule you have learned");
  - the Master presentation.

  Watch it: dead ends typically 13 moves, and the rule + 8-move look-ahead player wins 11%.
- **H. Does 100 hand off naturally to Switch at 101?** **Yes thematically:** an era change, a new rule, new visuals, and a small board (101: 9 blocks, 7.6). One risk is in §7.

## 7. Consequences for 101–200 (only new seams)

- **The 101–105 seam.** Levels 101–105 are five trap-free Switch tutorial boards (7.6–9.4, 9 blocks), and 106 jumps to 27.8. After a stronger, better-paced 1–100 this could recreate the "childish opening" feeling at a smaller scale. Not caused by these proposals, but made more visible by them. A later decision could compress Switch onboarding to 2 intro levels, then application, as in the lab.
- **Nothing else** in 101–200 depends on 1–100's order.

**Promotion consequences for any change:**
- Every adapted or new board changes `data/classic_board_keys.json`, the Friend exclusion list, which a unit test enforces.
- Stars and best scores are stored by level number, so reordered levels would show other boards' records. This needs a decision: accept it, or migrate by board identity.
