# Player Experience audit, Levels 176–200 (read only)

Nothing was changed: no level, code, lab, save, economy or test.

**Method:**
- All production 176–200 (plus 201 as a reference), with the game's own rules:
  - `tools/human_audit.gd`: the full state graph;
  - `tools/armor_audit.gd`;
  - `tools/verify_levels.gd`: the "Diff" estimate.
- Scratchpad tools (ram-aware):
  - a walk of SHOW A MOVE's line marking every fatal option;
  - a **hidden-information test**: is a fatal move fatal for every possible direction of the still-hidden arrows?
  - **Hammer rescue:** after each fatal option, play on until stuck, then test whether one smash makes the board winnable;
  - heuristic players (H1 / HC).

**Calibration from real-iPhone approvals:**
- 121–175 are approved, including Armor from Lab 151.
- The owner found the rise across 157–175 natural. Those levels have dense, long-lived decoys, look-ahead-8 wins of 0–10%, and 80–100% of mistakes beyond 3 Undos.

So these traits alone are **not** treated as problems. Level 295 remains the cautionary example: fatal moves that look harmless (plain escapes) and one rigid push route.

## 1. Executive summary

**Overall: KEEP all of 176–200.** Every metric that separated 295 from fair levels is clean:
- **0 plain-escape traps:** every fatal move is a switch firing or a spinner-turning escape;
- **0 fatal rams;**
- **0 shells that can strand;**
- **0 fatal moves whose danger depends on hidden arrows** in the seven Mystery levels.

**Difficulty:**
- Rises from 59 (176, a fair dip after Milestone 175) to the high 60s.
- The estimate spikes at 183 / 190 / 192 (75–77) are mostly "hold the switch" levels that a simple habit solves: likely easier for humans than the number suggests.
- The real reasoning levels are 179, 181, 186, 196 and 198, where every heuristic player fails.

**Main risk: repetition, not unfairness.**
- 181–199 is a strict three-level rotation (two-switch level → Armor + Gate level → Mystery "all mechanics" level), six times over.
- The Armor + Gate levels repeat one shape: a single decoy that must wait for 20+ moves.

**Armor** stays a satisfying but light mechanic: never essential, never fatal. Its colour-key role (5 levels) and the double-gate Armor levels 188 / 191 are its best uses.

**Level 200** works as a culmination:
- the hardest board in the game so far, fair in kind;
- a real opening choice;
- its own theme, music, the biggest celebration and a 600-coin bonus.

Its risks: **rigidity** (18 forced of 26 moves) and **expensive mistakes** (a Hammer rescues only 32% of stuck boards; dead ends up to 23 moves).

**200 → 201** is a deliberate reset into the Third Era (banner, Portal intro card, a 6-block tutorial), mirroring the validated 100 → 101.

**Novelty is sufficient** at roughly 20-level spacing:
- 171 (all three Second-Era mechanics together);
- 181 (the "expert" rotation with Mystery every third level);
- 188 / 191 (two gates + Armor);
- 200 (Grand Master).

No new mechanic is warranted.

## 2. Level by level

**Columns:**
- **Diff:** production estimate.
- **Forced:** forced steps / solution length.
- **Trap:** solution steps holding a fatal option.
- **Dev:** deviation survival.
- **Dead end:** typical / max moves still playable after a mistake.
- **Main decoy:** the fatal option(s) on SHOW A MOVE's line, and the steps they stay fatal.
- **Habit:** best simple heuristic.
  - **H1:** hold switches.
  - **HC:** H1 + ram when possible + prefer taps that turn no spinner.
- **Hammer:** share of stuck boards (after a mistake) that one smash rescues.

✦ = Mystery (hidden arrows). Every level has 2 first moves with exactly one fatal, except where noted.

| L | Name | Board / blocks | Mechanics | Diff | Forced | Trap | Dev | Dead end | Main decoy | Habit | Hammer | Rec |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 176 | Event Horizon | 6×7 / 19 | Armor 2 (lock key), switch, gate, ALT, Pattern, lock | 59.1 | 8/20 | 13 | .38 | 13.0 / 18 | switch A, steps 1–11 | H1 100% | 100% | A |
| 177 | Frozen Relay | 6×7 / 20 | Armor 2, switch, gate (2 links), Pattern, ALT/CCW | 61.0 | 10/21 | 13 | .43 | 5.7 / 11 | switch A, 1–13 | H1 100% | 100% | A |
| 178 | Crystal Heart | 7×7 / 22 | Armor (key), switch, gate, Pattern, ALT | 64.0 | 11/22 | 17 | .35 | 7.0 / 14 | spinner 1–3, then switch A 5–18 | HC 49% | 82% | A |
| 179 | Deep Field | 7×7 / 19 | Armor 2, switch, gate (2 links), Pattern, ALT/CCW | 62.5 | 15/20 | 18 | .15 | 5.6 / 18 | a **chained** block that turns a spinner, 1–18 | 0% | 100% | A |
| 180 | Pulsar | 6×7 / 20 | Armor 2 (key), switch, gate, ALT/CCW | 69.4 | 16/21 | 16 | .06 | 10.0 / 19 | switch A, 1–16 | H1 100% | 50% | A (watch) |
| 181 | Elite Entry | 6×7 / 22 | 2 switches, CW/CCW/ALT/Pattern, lock | 65.0 | 6/22 | 15 | .49 | 9.5 / 16 | spinner 1–6; switch B 3–15 | 0% | 65% | A |
| 182 | Gold Standard | 6×7 / 23 | Armor 2, gate (3 links), Pattern, CCW | 61.2 | 5/24 | 19 | .54 | 10.2 / 21 | spinner-turner `G^`, 1–21 | HC 14% | 46% | A |
| 183 | High Council ✦ | 7×7 / 21 | hidden 2, Armor, switch, gate, ALT | 75.0 | 18/21 | 18 | .14 | 9.5 / 18 | switch A, 1–18 | H1 100% | 100% | A |
| 184 | Grand Design | 7×7 / 20 | 2 switches (4 marks), CCW/ALT/Pattern | 63.0 | 10/20 | 14 | .26 | 7.1 / 14 | switch A 1–14 | 50% | 100% | A |
| 185 | Crown Line | 6×7 / 21 | Armor 2, gate (2 links), Pattern, CCW | 63.1 | 14/22 | 20 | .23 | 10.5 / 20 | spinner-turner `Rv`, 1–20 | HC 7% | 100% | A |
| 186 | Masterwork ✦ | 7×7 / 21 | hidden 2, Armor, switch, gate, ALT, Pattern | 60.1 | 15/21 | 17 | .10 | 11.2 / 19 | chained spinner-turner, 1–15; switch first | 0% | 100% | A |
| 187 | Apex | 7×7 / 20 | 2 switches, ALT/CCW/Pattern | 70.2 | 16/20 | 17 | .10 | 9.0 / 17 | switch A, 1–17 | 49% | 100% | A |
| 188 | Summit Key | 7×7 / 25 | **Armor 2 + two gates (5 links)**, Pattern, ALT/CCW | 63.3 | 6/25 | 18 | .54 | 14.3 / 19 | spinner, 1–9 | HC 25% | 100% | A |
| 189 | Champion ✦ | 7×7 / 26 | hidden 2, Armor (key), switch, gate, Pattern, ALT/CCW | 68.2 | 6/26 | 15 | .48 | 5.8 / 12 | switch A, 1–14 | 75% | 27% | A |
| 190 | Laurel | 6×7 / 25 | 2 switches (3 marks), CCW/ALT | 76.5 | 11/25 | 17 | .45 | 10.5 / 19 | switch A 1–14, switch B 8–18 | H1 100% | 27% | A (watch) |
| 191 | Final Ascent | 6×7 / 25 | **Armor 2 + two gates (5 links)**, ALT/CCW | 65.0 | 15/25 | 20 | .31 | 10.6 / 20 | spinner 1–10, chained block 11–19 | HC 6% | 100% | A |
| 192 | Sovereign ✦ | 7×7 / 23 | hidden 2, Armor, switch, gate, ALT | 77.4 | 11/23 | 19 | .32 | 13.0 / 20 | switch A, 1–12 | H1 100% | 100% | A |
| 193 | Last Light | 6×7 / 22 | 2 switches, Pattern/ALT/CCW | 67.8 | 9/22 | 16 | .30 | 5.5 / 11 | switch B, 1–16 | HC 100% | 44% | A |
| 194 | Paragon | 7×7 / 22 | Armor 2, gate (3 links), Pattern, ALT/CCW | 66.6 | 16/23 | 21 | .19 | 11.1 / 21 | spinner-turner `Rv`, 1–21 | HC 6% | 100% | A |
| 195 | Zenith ✦ | 7×7 / 26 | hidden 2, Armor, switch, gate (3 links), ALT/CCW | 69.6 | 5/26 | 15 | .55 | 9.7 / 15 | switch A, 1–9 | HC 100% | 100% | A |
| 196 | Grandmaster Path | 6×7 / 23 | 2 switches, Pattern/ALT/CCW | 67.5 | 6/23 | 18 | .44 | 6.5 / 12 | switch A 1–4; spinner-turners 7–13 | 0% | 80% | A |
| 197 | Pinnacle | 7×7 / 23 | Armor, gate (2 links), Pattern, ALT/CCW | 66.0 | 17/23 | 21 | .16 | 11.0 / 21 | spinner-turner `R<`, 1–21 | HC 18% | 100% | A |
| 198 | Legacy ✦ | 7×7 / 23 | hidden 1, Armor (key), switch, gate (3 links), Pattern | 68.3 | 9/23 | 19 | .33 | 10.8 / 18 | switch A 1–4; Pattern-spinner turner 4–18 | 0% | 74% | A |
| 199 | Eternal Chain | 6×7 / 21 | 2 switches, ALT/Pattern | 70.2 | 13/21 | 17 | .19 | 8.8 / 17 | switch A 1–17 | HC 100% | 82% | A |
| 200 | The Grand Master ✦ | 7×7 / 25 | everything: hidden 2, Armor 2, 2 switches (4 marks), gate, CW/CCW/ALT/Pattern, locks, 3 rewards | **108.1** | **18/26** | **24** | **.12** | 10.5 / **23** | first move: switch B (right) vs switch A (fatal, stays fatal 1–20); the arrow switch B reverses, fatal 2–22; a spinner 7–15 | 0% | **32%** | A (watch) |

**Expected readability:**
- 7×7 boards with 20–26 blocks and up to six marks (switch, flip, chain, lock, shell, hidden) are dense on an iPhone.
- 7×7 Armor levels were readable in the approved 151–175 test.
- The Armor direction chip is small on 7×7, but no level here needs the shelled block's direction to be read early.

## 3. Difficulty and pacing

| Stretch | Diff (est.) | Human reading |
|---|---|---|
| **175 → 176** | 66.1 → 59.1 | A natural dip after the Milestone; 176 yields to "hold the switch" |
| **176–180** (Chapter 18 end) | 59 → 69 | Steady rise. 179 is the reasoning peak. 180 is narrow by the solver (dev .06) but a holding habit solves it; its mistakes are costly (Hammer 50%) |
| **181–190** (Chapter 19) | 60–77 | The rotation starts. Estimate spikes at 183 / 190 are switch-holding levels (H1 100%), so they are probably felt as moderate. True thinking levels: 181, 186 |
| **191–199** (Chapter 20) | 65–77 | 192's estimate spike is switch-holding again. Reasoning levels: 196, 198. Persistent-decoy shape in 191 / 194 / 197 |
| **200** | 108.1 | The deliberate peak. The estimate is inflated by its hidden-arrow term, but it is truly the most constrained level (see section 7) |

**Breathers:** 176, and within the rotation the two-switch levels 184 / 187 / 193 / 199, which are solved by habit or by one choice.

**Solver complexity vs human solvability vs enjoyment:**
- **Solver numbers** (forced share, deviation survival, look-ahead wins ≈ 0) look harsh everywhere. They looked the same in the approved 157–175.
- **Human solvability** is better captured by:
  - the kind of fatal moves (all visible kinds);
  - the absence of hidden-information traps;
  - which habits solve a level.
- **Enjoyment risk** comes from sameness (the rotation, the single long decoy) and from costly mistakes on long boards, not from unfair design.

**SHOW A MOVE, Restart, Undo and Hammer:**
- **SHOW A MOVE** is solvability-checked and never points into a trap.
- **Undo 3** rarely reaches back to a mistake: 83–100% of mistakes need more, the production norm. The cost is a Restart, and boards are 20–26 moves long.
- **The Hammer is a reliable emergency exit in 15 of 25 levels** (100% rescue). It is weak at 180 (50%), 182 (46%), 189 / 190 (27%), 193 (44%) and **200 (32%)**. There, a Restart is the realistic recovery.

## 4. Human-solvability and fairness

- **No 295 patterns:** no plain-escape traps, no forced push routes, no Sequence-style fatal first stages (those mechanics are not in this range).
- **Hidden blocks are fair.** In the 7 Mystery levels, every fatal move along SHOW A MOVE's line is fatal whatever the hidden arrows turn out to be. Hidden arrows never decide a loss the player could not foresee.
- **Armor never traps:** rams are never fatal and no dead end keeps a shell (`armor_audit`: 0 unsafe).
- **The Gate never traps:** removing a chained block can be fatal only because that escape turns a spinner (179, 186, 191). That is the spinner rule, visible.
- **Persistent decoys:** one block (a switch or a spinner-turner) stays fatal for 9–21 steps in most levels. This is the approved house style, and readable once learned. It is repetitive in the Armor + Gate levels 182 / 185 / 194 / 197.

## 5. Mechanic variety

**Present:** Armor, Switch (one or two groups), Chain Gate (one or two, up to 5 links), Lock (every level), Hidden (7 Mystery levels), CW / CCW / Alternating / Pattern spinners, Silver / Gold rewards.

**Not present:** Portal, Sequence, Movable (Third Era).

**Structure:**
- **176–180:** Armor + Switch + Gate in every level (the 171 combination continues).
- **181–199:** a strict three-level rotation, repeated six times:
  1. a **two-switch level** without Armor or Gate (181, 184, 187, 190, 193, 196, 199);
  2. an **Armor + Gate level** without switches (182, 185, 188, 191, 194, 197);
  3. a **Mystery level** with every mechanic (183, 186, 189, 192, 195, 198).
- **200:** everything.

**Does Armor still create decisions?** Only lightly.
- It is never essential: the verifier's impact is 3–21 points, never "ESS".
- Rams are always safe, and SHOW A MOVE's line uses 0–2 rams.

Its best uses:
- **The colour-key twist** (176, 178, 180, 189, 198): a shelled block must leave to open a lock.
- **188 / 191:** two gates with 5 links where shells sit on the routes.

Elsewhere Armor is a satisfying extra beat (the explosion was approved) rather than a decision. That is acceptable; it is not clutter in the sense of misleading marks.

**Meaningful discoveries:**
- 179 / 186: chained blocks whose escape turns a spinner, so a link becomes a timing decision.
- 198: a Pattern spinner as the decoy.
- 200: the first move breaks the "hold the switch" habit; switch B must fire first.

**Clutter risk:** the Mystery "everything" levels (183–198) carry 6 kinds of marks on 7×7. They are readable in principle, but they are the most likely to feel busy.

**Lab dependencies from the approved 1–175:** none that block 176–200.
- Armor is learned earlier (151), which only helps.
- Production's Armor lesson/tip is not referenced in 176–200.
- No lesson routes past 151.
- The lab's Chapter-card override only moves "NEW: Armored Blocks".

## 6. Novelty and retention

**Novelty after Armor (151):**
- **171:** all three Second-Era mechanics combined (hint "read every mark").
- **181:** a new format, focused expert levels with Mystery every third level.
- **188 / 191:** Armor with two gates and 5 links: a different, route-planning puzzle.
- **200:** the Grand Master.
- **201:** a new era and mechanic (Portal).

That is roughly one meaningful beat every 10–20 levels. **Sufficient: no new mechanic is needed.**

**Retention risk:** sameness inside 181–199 (the rotation becomes predictable, and the Armor + Gate levels share the long-decoy shape). The smallest possible mitigation, **only if the human test shows fatigue**, is presentation, not content: e.g. naming the format on the Chapter cards ("Expert" stretch). No board change is proposed.

**Small presentation note (B, optional):** production reuses earlier names here, so a player of the full game sees two of each:
- "Dark Matter" (80 / 172);
- "Apex" (97 / 187);
- "Zenith" (98 / 195);
- "Last Light" (99 / 193).

## 7. Level 200 milestone

**Puzzle:**
- **Board:** 7×7, 25 blocks: every Second-Era mechanic plus hidden arrows and 3 rewards.
- **The opening is a real decision:** fire switch **B** (right) or switch **A** (fatal). It reverses the "hold the switch" habit the player has built.
- **Then, for about 20 moves, three visible decoys must wait:**
  - switch A (until move 21);
  - the arrow switch B reversed (until 23);
  - a spinner (moves 7–15).
- Two rams crack the shells, a gate opens at move 9, and hidden arrows reveal along the way.

**Fairness:**
- No plain-escape or hidden-information trap; shells can't strand.
- **Rigid:** 18 of 26 steps forced, 24 holding a fatal option, deviation survival 12%.
- **Costly mistakes:** dead ends typically 10.5 moves (max 23); a Hammer rescues only 32% of stuck boards.

This is a demanding but legible exam. The difficulty estimate (108) overstates it, because its hidden-arrow term counts reveals that never decide a loss.

**Presentation** (verified in code):
- **Look and sound:** its own Grand Master theme (black-gold, rays, gold dust) and music (`master2`).
- **During play:** the label "GRAND MASTER" instead of a level number.
- **On clearing:** 5 celebration bursts (Master 100: 3), the stamp "GRAND MASTER!", the Master sound and a haptic.
- **The card:** titled "GRAND MASTER!"; the hint reads "The Grand Master. Every rule of both eras."
- **Rewards:** a one-time 600-coin bonus (Master 100: 300).

**Assessment:** a strong sense of culmination; no change recommended.

**Watch in the human test:**
- How many restarts?
- Is SHOW A MOVE used to find the opening switch?
- Do players feel the rigid middle as tense mastery or as rote?

If testers stall repeatedly, consider presentation only (e.g. no change to the board, but confirm the existing hint is seen). Re-evaluate the board only on evidence.

## 8. 200 → 201 transition

201 "First Portal":
- a 5×5 board with 6 blocks, no fatal option at any step (estimate 6.0);
- hint "New: PORTAL. Blocks go in one A and come out the other A.";
- the "THIRD ERA" banner;
- the Portal mechanic intro card (`MECHANIC_INTRO_FROM.portal = 201`);
- Chapter 20's card before it says "NEW: Portals".

From the hardest board to a tiny tutorial: a deliberate reset with fresh novelty, the same pattern as 100 → 101, which the Lab's 101–110 test validated. **Natural and exciting.** The only risk is that the sudden ease feels like a step back; the new mechanic and era banner should carry it. Watch 201–205 when the lab gets there.

## 9. Watch list

| Level | Why | Evidence |
|---|---|---|
| **200** | Rigid exam, costly mistakes | 18 / 26 forced, dev .12, dead ends to 23, Hammer 32%, opening switch-order choice |
| **180** | Chapter-end narrowness | dev .06, 16 / 21 forced, Hammer 50% (a habit solves it) |
| **189 / 190** | Mistakes rarely rescued by the Hammer | 27% each; 190 is 25 moves long |
| **182 / 185 / 194 / 197** | Repeated long-decoy shape (Armor + Gate) | one decoy fatal for 20–21 steps each |
| **181–199 as a whole** | Predictable rotation | six identical three-level cycles |
| **183 / 190 / 192** | Estimate spikes that a habit solves | H1 100% at Diff 75–77: do they feel like breathers? |
| **179, 186, 196, 198** | Real reasoning levels (good-hard) | every heuristic player fails |

## 10. Recommendations

| Class | Levels |
|---|---|
| **A — KEEP** | **All 176–200** |
| **B — presentation only (optional, low priority)** | Duplicate names (172, 187, 193, 195 share names with 80, 97, 99, 98); an "Expert" framing for 181–199 only if fatigue is observed |
| **C — minor adaptation** | None on current evidence |
| **D — redesign candidate** | None. 200 is the closest to the 295 profile in rigidity and recovery cost, but it lacks the unfair features (no harmless-looking fatal moves). Decide only after the human test |

## 11. Minimal human-test plan

Play 176–200 naturally, but observe these closely:
- **176:** the post-Milestone dip; continuity from Lab 175.
- **179, 186:** chained blocks that turn spinners. Is the cause visible?
- **180:** Chapter end; restarts and Hammer use.
- **183 or 192:** an estimate spike solved by habit; breather or chore?
- **188, 191:** two gates + Armor; is this the "new" feeling?
- **189 / 190:** restarts when the Hammer can't rescue.
- **194 / 197:** fatigue from the long-decoy shape late in the run.
- **200:** the opening choice, restarts, SHOW A MOVE use, and the feeling at the GRAND MASTER! stamp.
- **201** (one level): does the new era start feel exciting rather than a step back?

**Record:** restarts, SHOW A MOVE / Hammer use, time per level, and a one-line feeling after each Chapter (18, 19, 20).

## 12. Limitations and uncertainties

- **Heuristic players and Hammer rescue are proxies.**
  - Hammer rescue is measured at random stuck boards reached after mistakes on SHOW A MOVE's line, not at every possible mistake.
  - Hammer stock (1 per level, bought with coins) and its score penalty are not modelled.
- **The hidden-information test covers SHOW A MOVE's line, not every state.**
- **The Diff estimate** includes solver-trap and hidden-arrow terms that overweight narrowness and reveals.
- **On-device readability and performance** of the densest 7×7 boards (22–26 blocks) and of 200's celebration were not measured here.
- **Not human-validated:** 176–200 have not been played in the Lab. The Lab ends at 175.

## 13. Overall recommendation

**KEEP 176–200 unchanged.**
- The range is fair in the ways that matter: no harmless-looking traps, no hidden-information traps, and Armor and Gate never trap.
- It has enough novelty up to a strong Grand Master culmination and a clean Third-Era hand-off.

**Next step:** extend the Experience Lab to 200 with production boards unchanged. There is no new routing to add (no lessons or Chapter-card changes needed past 175). Then play 176–200 with the watch list above, focusing on Level 200's restart cost and on fatigue across 181–199.
