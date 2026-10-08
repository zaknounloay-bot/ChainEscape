# TWINS integration plan for Experience Lab Levels 176–199 (read-only design)

This is a plan for review. Nothing here is implemented: no code, level, lab data, save, economy, build or export was changed.

**Unchanged:**
- Lab 1–175 and Level 200;
- production 1–300;
- the approved Twins rules (`docs/twins_prototype.md`).

**Sources:**
- the current Lab data (`data/dev/experience_lab/level_171..200.json` are byte-for-byte production boards);
- `docs/player_experience_audit_176_200.md` (full per-level audit);
- `docs/lightweight_mechanic_exploration_181_199.md`;
- `docs/twins_176_design_validation.md`;
- `docs/twins_prototype.md`;
- two new scratchpad measurements made for this plan (not in the repo), summarised in B.3 and B.4.

The repository has no file called "MASTER CONTEXT". The documents above, `docs/product_roadmap.md` and the code are the context used.

## A. Executive recommendation

**Introduce Twins at 176, and make it 10 of the 24 levels.** The other 14 stay classic, mostly the strongest existing production boards.
- **Spacing:** never more than two Twins levels in a row, and never more than three classic levels in a row between them.
- **The finish stays classic:** 198 and 199 are Twin-free classic levels, so the Grand Master stays a "classic" exam.
- **The counts:**
  - **KEEP 14** production boards unchanged; three of them move by one slot (Deep Field 179 → 180, Masterwork 186 → 185, Crown Line 185 → 186);
  - **ADAPT 1** production board in place (182, one bonded pair, solver-verified);
  - **REPLACE 9** slots with Twins boards: A, B, C from the approved prototype, plus **6 new designed boards** (D–I).

**Why designed boards and not mostly adaptations.** Measured on the real engine, the obvious shortcut (bond two adjacent arrows of an existing board) rarely adds a decision:
- of 118 possible in-place pairs in 176–199, 32 (27%) make the board unsolvable;
- of the 86 that stay solvable, only **4 pairs in 2 levels** (182 and 196) create a release-timing decision;
- the rest add only "clear both lanes", which the design report already showed is never a real choice.

**The difficulty trap to avoid.** The approved prototype boards are 12-block, 6×6 teaching boards. A random tapper wins 51–100% of them. On every production level 171–200, a random tapper wins about 0–1%; those boards have 19–26 blocks.

Dropping A, B and C into 176–199 unchanged would turn the Elite chapters into a sudden sag. The plan therefore:
- uses A, B and C **early** (176, 179, 184), where an easier "learn it" level is right;
- ramps the Twins boards back to Elite density (16–22 blocks, real decisions) by 187;
- keeps the chapter ends hard: 180 is Deep Field and 190 is a hard Twins board;
- never gets difficulty from clutter.

**Batch 1 (176–185)** needs only **one** genuinely new board (177) and **one** adaptation (182); the rest is approved or unchanged content. It can be built and played quickly.

## B. The current 176–199 sequence

### B.1 What is there (Lab = production, unchanged)

**Columns:**
- **H1 / HC:** the share of runs that simple habit players win:
  - **H1** always holds switches back until they are needed;
  - **HC** does that, also rams whenever it can, and prefers taps that turn no spinner.
- **Dev:** the share of mistakes the board survives.
- **Hammer:** the share of stuck boards that one smash rescues.

All the values come from the 176–200 audit.

| L | Name | Shape | Mechanics | Diff | Habit | Dev | Hammer | Character |
|---|---|---|---|---|---|---|---|---|
| 176 | Event Horizon | 6×7 / 19 | Armor (key), switch, gate, ALT, Pattern, lock | 59.1 | H1 100% | .38 | 100% | Post-milestone dip; "hold the switch" |
| 177 | Frozen Relay | 6×7 / 20 | Armor, switch, gate (2), Pattern, ALT/CCW | 61.0 | H1 100% | .43 | 100% | Same shape as 176 |
| 178 | Crystal Heart | 7×7 / 22 | Armor (key), switch, gate, Pattern, ALT | 64.0 | HC 49% | .35 | 82% | Spinner then switch decoy; Armor key twist |
| 179 | Deep Field | 7×7 / 19 | Armor, switch, gate (2), Pattern, ALT/CCW | 62.5 | 0% | .15 | 100% | **Reasoning level:** a chained link turns a spinner |
| 180 | Pulsar | 6×7 / 20 | Armor (key), switch, gate, ALT/CCW | 69.4 | H1 100% | **.06** | **50%** | Narrow, costly; habit-solved |
| 181 | Elite Entry | 6×7 / 22 | 2 switches, all 4 spinner rules, lock | 65.0 | 0% | .49 | 65% | **Reasoning level** |
| 182 | Gold Standard | 6×7 / 23 | Armor, gate (3), Pattern, CCW | 61.2 | HC 14% | .54 | 46% | Armor+Gate long decoy (1–21) |
| 183 | High Council ✦ | 7×7 / 21 | hidden, Armor, switch, gate, ALT | 75.0 | H1 100% | .14 | 100% | Mystery "everything"; estimate spike that a habit solves |
| 184 | Grand Design | 7×7 / 20 | 2 switches (4 marks), CCW/ALT/Pattern | 63.0 | 50% | .26 | 100% | Two-switch level |
| 185 | Crown Line | 6×7 / 21 | Armor, gate (2), Pattern, CCW | 63.1 | HC 7% | .23 | 100% | Armor+Gate long decoy (1–20) |
| 186 | Masterwork ✦ | 7×7 / 21 | hidden, Armor, switch, gate, ALT, Pattern | 60.1 | 0% | .10 | 100% | **Reasoning level** (chained spinner-turner) |
| 187 | Apex | 7×7 / 20 | 2 switches, ALT/CCW/Pattern | 70.2 | 49% | .10 | 100% | Two-switch level |
| 188 | Summit Key | 7×7 / 25 | **Armor + two gates (5 links)** | 63.3 | HC 25% | .54 | 100% | **Distinct:** route planning across two gates |
| 189 | Champion ✦ | 7×7 / 26 | hidden, Armor (key), switch, gate | 68.2 | 75% | .48 | 27% | Mystery "everything" |
| 190 | Laurel | 6×7 / 25 | 2 switches (3 marks), CCW/ALT | 76.5 | H1 100% | .45 | 27% | Estimate spike a habit solves; long; costly |
| 191 | Final Ascent | 6×7 / 25 | **Armor + two gates (5 links)** | 65.0 | HC 6% | .31 | 100% | **Distinct**, as 188 |
| 192 | Sovereign ✦ | 7×7 / 23 | hidden, Armor, switch, gate, ALT | 77.4 | H1 100% | .32 | 100% | Estimate spike a habit solves; Mystery "everything" |
| 193 | Last Light | 6×7 / 22 | 2 switches | 67.8 | HC 100% | .30 | 44% | Two-switch breather |
| 194 | Paragon | 7×7 / 22 | Armor, gate (3), Pattern, ALT/CCW | 66.6 | HC 6% | .19 | 100% | Armor+Gate long decoy (1–21) |
| 195 | Zenith ✦ | 7×7 / 26 | hidden, Armor, switch, gate (3) | 69.6 | HC 100% | .55 | 100% | Mystery; forgiving |
| 196 | Grandmaster Path | 6×7 / 23 | 2 switches, Pattern/ALT/CCW | 67.5 | 0% | .44 | 80% | **Reasoning level** |
| 197 | Pinnacle | 7×7 / 23 | Armor, gate (2), Pattern, ALT/CCW | 66.0 | HC 18% | .16 | 100% | Armor+Gate long decoy (1–21) |
| 198 | Legacy ✦ | 7×7 / 23 | hidden, Armor (key), switch, gate (3), Pattern | 68.3 | 0% | .33 | 74% | **Reasoning level** (Pattern-spinner decoy) |
| 199 | Eternal Chain | 6×7 / 21 | 2 switches, ALT/Pattern | 70.2 | HC 100% | .19 | 82% | Switch-holding; calm before 200 |

### B.2 Strengths, weaknesses, repetition

**Strengths, to preserve:**
- **The fairness record.** 176–200 have:
  - 0 plain-escape traps and 0 fatal rams;
  - 0 hidden-information traps;
  - 0 shells that can strand.
- **Six real reasoning levels** that every habit player fails: 179, 181, 186, 196, 198, and 200.
- **Two genuinely different boards:** 188 and 191, Armor with two Chain Gates and 5 links.
- **The Armor colour-key twist:** 178, 189, 198.

**Weaknesses:**
- **A strict three-level rotation from 181 to 199.** It runs two-switch level, Armor+Gate level, Mystery "everything" level, repeated six times.
- **One puzzle shape everywhere:** a single decoy that must wait 10–21 moves.
- **Several levels are solved by one habit (H1 100%):** 176, 177, 180, 183, 190, 192. Three of them are estimate spikes (75–77) that a player solves with "hold the switch".
- **Four Armor+Gate levels share the long-decoy shape:** 182, 185, 194, 197.
- **No new kind of decision since Armor at 151.**

### B.3 Measurement 1: in-place pairs (all 24 levels, real engine)

**Method:** for every pair of orthogonally adjacent plain arrows in 176–199, bond them, then:
1. solve the board;
2. walk SHOW A MOVE's line;
3. at every step where the pair can leave, test whether releasing it now makes the board unsolvable.

**Results:**
- 118 candidate pairs; 32 (27%) make the board unsolvable; 184 has no candidate at all.
- Of the 86 solvable ones, **82 never create a fatal release moment:** the pair is only a "clear both lanes" chore.
- **4 pairs create a real timing decision.** In each one the release turns a spinner, a visible cause:

| Level | Pair | Fatal release steps | Notes |
|---|---|---|---|
| 182 Gold Standard | R< (4,5) + Y< (5,5) | 7 | Released at step 16; turns a spinner |
| 182 Gold Standard | G^ (4,0) + Rv (4,1) | 2 | Makes the level **easier** (random tapper 0% → 23%) |
| 196 Grandmaster Path | Y> (2,0) + B^ (2,1) | 8 | 196 is already a reasoning level |
| 196 Grandmaster Path | B^ (2,1) + G> (2,2) | 4 | Same |

**Conclusion:**
- One adaptation is worth making: **182 with R< + Y<**.
- The 196 pair is held in reserve; 196 is a strong level to keep.
- Everything else needs designed boards.

### B.4 Measurement 2: difficulty yardstick

**The yardstick** is the random tapper: a player who taps any legal move. It was run on the real Solver for 1,500 games, counting a pair as one move.

| Boards | Random tapper wins |
|---|---|
| Lab 171–200 (production boards) | **0–1.3%** on every level (188: 0.9%, 195: 1.3%, 196: 1.2%; all others ≤ 0.1%) |
| Prototype A "Twin Lights" | 100% |
| Prototype B "Hold Fire" | 72% |
| Prototype C "Turnabout" | 51% |
| 182 adapted (R< + Y<) | ≈0%, like its source |

The prototypes are teaching boards. Elite Twins boards must be designed to the 0–5% band, with decisions, not size.

## C. The 24-level plan

**Legend:**
- **T** = Twins appear.
- **Reorder** = a production board moved by one slot inside the Lab (the 151–170 interleave already set this precedent).
- **Displaced** production boards are not deleted. They stay in production 176–199 unchanged; they are only left out of this Lab path.

| L | Existing (now) | Decision | T | Main intended experience | Mechanic interaction | Target difficulty | Reason |
|---|---|---|---|---|---|---|---|
| **176** | Event Horizon | **REPLACE → A "Twin Lights"** (approved prototype board, unchanged) + guided Twins lesson | T | Discovery: "they leave together", then the WOW of the facing red pair passing through each other | Twins only, two pairs (horizontal facing, mixed directions) | Very easy (post-milestone dip, a lesson level) | Directly after Milestone 175, as intended. Event Horizon's character (H1 100%) is shared by 177 / 180 / 183 / 190 / 192 |
| **177** | Frozen Relay | **REPLACE → new board D "Double Link"** | T | Confidence: a bonded pair is two Chain Gate links that leave in one move, opening the gate in a satisfying double beat | Twins + Chain Gate; a **vertical** pair (A had horizontal pairs); 2-link gate opened only by the pair; one decoy lane | Easy (random tapper 60–90%; no losing first move; ≤ 2 fatal moves) | Teaches the second rule fact (each twin counts as a link) on a fresh geometry. Frozen Relay repeats 176's shape |
| **178** | Crystal Heart | **KEEP** | – | Breathing room in the familiar Elite style; the Armor colour key | Armor key, switch, gate, ALT/Pattern | Elite (Diff 64) | Good, varied, fair; a classic level so the twins don't crowd the chapter |
| **179** | Deep Field | **REPLACE → B "Hold Fire"** (approved prototype board, unchanged). Deep Field moves to 180 | T | First real Twins decision: *when* to release the pair, which turns the spinner on top of it | Twins + Spinner (facing pair; a fatal release only when the spinner points up, a visible face-off) | Medium (random tapper ≈ 70%; 16 visible fatal moves; ≤ 4 Undos) | The tested "timing lever" board. Its 12 blocks make it a deliberate learning step |
| **180** | Pulsar | **KEEP Deep Field (moved from 179)**; Pulsar displaced | – | Chapter 18 ends on a real reasoning level (a chained link that turns a spinner) | Armor, switch, gate (2), Pattern / ALT / CCW | Elite peak of Chapter 18 (dev .15, Hammer 100%) | Keeps the chapter end hard **and fair**. Pulsar was the narrowest and costliest (dev .06, Hammer 50%) and habit-solved |
| **181** | Elite Entry | **KEEP** | – | "Elite" chapter opener; pure reasoning with two switches and all four spinner rules | 2 switches, spinners | Elite (Diff 65, habit 0%) | One of the six reasoning levels |
| **182** | Gold Standard | **ADAPT:** bond R< (4,5) + Y< (5,5) (no other change) | T | Twins in a full Elite board: the pair is a spinner lever that must wait, replacing the anonymous long decoy with a visible "not yet" | Twins + Spinner on an Armor + Gate board | Elite (random tapper ≈ 0%, as the source) | The only measured adaptation that adds a decision (7 fatal release steps). Breaks the repeated Armor+Gate long-decoy shape |
| **183** | High Council ✦ | **KEEP** | – | A Mystery level and a breather: the estimate spike is solved by holding the switch | hidden, Armor, switch, gate, ALT | Elite, habit-friendly | Variety (Mystery) and relief between two Twins levels |
| **184** | Grand Design | **REPLACE → C "Turnabout"** (approved prototype board, unchanged) | T | "I almost fired it too early": a switch that is at once the obstacle, the direction changer and the trap for the pair | Twins + Switch (a reversed twin; the switch must leave after blue (3,3)) | Medium (random tapper ≈ 50%; 8 visible fatal moves) | The tested switch combination. Grand Design is a two-switch level, the most repeated format (seven of them in 181–199) |
| **185** | Crown Line | **KEEP (reorder): Masterwork ✦** (moved from 186); Crown Line moves to 186 | – | A Mystery reasoning level right after two Twins levels | hidden, Armor, switch, gate, ALT, Pattern | Elite (habit 0%) | Moves the Mystery levels off the every-third-level beat (183, 185, 189, 195, 198) |
| **186** | Masterwork | **KEEP Crown Line (moved from 185)** | – | Classic Armor + Gate | Armor, gate (2), Pattern, CCW | Elite (Diff 63) | Kept as the one remaining long-decoy Armor+Gate level (of four) |
| **187** | Apex | **REPLACE → new board E "Shell Game"** | T | The twins need help: a shelled block sits in one twin's lane, and twins never ram, so the player must keep a rammer for it | Twins + Armor + Chain Gate; one pair linked to the gate; a rammer whose own escape turns a spinner (a timing choice) | Elite-entry (random tapper ≤ 10%; 16–19 blocks; ≥ 1 fatal release or rammer-timing decision) | First Twins board at Elite density. A new Armor role (protecting the pair's lane). Apex is a two-switch level solved by habit half the time |
| **188** | Summit Key | **KEEP** | – | Route planning across two gates | Armor + two gates (5 links) | Elite (Diff 63) | One of the two genuinely different boards |
| **189** | Champion ✦ | **KEEP** | – | Mystery with the Armor colour key | hidden, Armor key, switch, gate | Elite | Varied; fair (Hammer only 27%, noted) |
| **190** | Laurel | **REPLACE → new board F "Two Bonds"** | T | Chapter 19 finale: **two pairs**, where releasing one pair turns a spinner into the other pair's lane; ordering between pairs | Twins ×2 + Spinner (one ALT, so the second turn differs) | Hard (random tapper ≤ 5%; 16–20 blocks; max Undo ≤ 4; no losing first move) | A chapter end with a WOW of its own. Laurel is a habit-solved estimate spike, long and costly (Hammer 27%) |
| **191** | Final Ascent | **KEEP** | – | Two gates + Armor, the second time | Armor + two gates (5 links) | Elite | Distinct board; good chapter-20 opener |
| **192** | Sovereign ✦ | **REPLACE → new board G "Reversal"** | T | One switch reverses **both** twins: back-to-back becomes facing. Fire it at the right moment, while its other flip target must already be gone | Twins + Switch + Chain Gate (the twins are 2 of 3 links) | Hard (random tapper ≤ 5%; ≥ 1 fatal switch-before decision; 0 plain traps) | Builds on C at Elite density. Sovereign is the third habit-solved Mystery spike |
| **193** | Last Light | **KEEP** | – | Breathing room: two switches, habit-friendly | 2 switches, spinners | Elite, relief (HC 100%) | Needed relief in Chapter 20 |
| **194** | Paragon | **REPLACE → new board H "Pattern Lock"** | T | The pair is the decoy: an ALT / Pattern spinner beside it means the *second* release window is the safe one, not the first | Twins + Pattern / ALT spinners + lock (the pair's colour is a key: releasing early opens a lock that then faces a spinner) | Hard (random tapper ≤ 3%; ≥ 2 fatal release steps; 0 plain traps) | A Twins decision that depends on spinner rules (no prototype board does this). Paragon is the third repeated long-decoy Armor+Gate level |
| **195** | Zenith ✦ | **KEEP** | – | Mystery, forgiving | hidden, Armor, switch, gate (3) | Elite (HC 100%) | Relief before the run-in |
| **196** | Grandmaster Path | **KEEP** (reserve: bond Y> (2,0) + B^ (2,1), measured at 8 fatal release steps) | – | Pure reasoning with two switches | 2 switches, spinners | Elite (habit 0%) | One of the strongest levels; the reserve adaptation is used only if a new board fails its bar |
| **197** | Pinnacle | **REPLACE → new board I "Bond of Ages"** | T | The Twins exam: one release turns a spinner **and** completes the gate links; the switch reversing a twin must come before or after it | Twins + Spinner + Switch + Gate (no hidden blocks) | Hardest Twins level (random tapper ≤ 2%; ≤ 22 blocks; max Undo ≤ 5; no losing first move) | The last Twins beat, three levels before 200. Pinnacle is the fourth repeated long-decoy Armor+Gate level |
| **198** | Legacy ✦ | **KEEP** | – | Mystery reasoning (Pattern-spinner decoy) | hidden, Armor key, switch, gate (3), Pattern | Elite (habit 0%) | A strong classic reasoning level as the penultimate step |
| **199** | Eternal Chain | **KEEP** | – | Calm before the storm: a switch-holding level that builds the habit 200 will break | 2 switches, ALT/Pattern | Elite (HC 100%) | Sets up the Grand Master's opening (switch **B** must fire first) |

**Counts:**
- **KEEP 14:** 178, 180 (Deep Field, moved from 179), 181, 183, 185 (Masterwork, moved from 186), 186 (Crown Line, moved from 185), 188, 189, 191, 193, 195, 196, 198, 199.
- **ADAPT 1:** 182.
- **REPLACE 9:** 176 (A), 177 (D), 179 (B), 184 (C), 187 (E), 190 (F), 192 (G), 194 (H), 197 (I): three approved prototype boards and six new boards.

**Exact slot accounting:**

| Slots | Count |
|---|---|
| Twins | 10: 176, 177, 179, 182, 184, 187, 190, 192, 194, 197 |
| Classic | 14: 178, 180, 181, 183, 185, 186, 188, 189, 191, 193, 195, 196, 198, 199 |
| Production boards displaced from the Lab path (they stay in production) | 9: Event Horizon 176, Frozen Relay 177, Pulsar 180, Grand Design 184, Apex 187, Laurel 190, Sovereign 192, Paragon 194, Pinnacle 197 |
| New boards to design | 6: D, E, F, G, H, I |

## D. Twins introduction and learning progression

| Step | Level | What the player learns | How |
|---|---|---|---|
| 1 | **176 A** | Rule core: tap one, both leave; both lanes must be clear; the partner is not an obstacle (the facing pair) | A guided lesson in the Lab style (as Lock 13, Switch 101, Gate 121, Armor 151): brackets on a pair, a finger on a twin, then the line "Twins leave together - both paths must be clear". The free partner-blocked tap explains itself once. Lesson key `lesson_twins`, a new string in the existing `tips_seen` list (no save format change) |
| 2 | **177 D** | Each twin is a gate link: one move opens a 2-link gate. Vertical geometry | The board teaches it; a short hint line |
| 3 | **179 B** | Releasing a pair is a neighbour event, so **timing** matters | No hint beyond the tested one ("Twins turn a spinner beside them…") |
| 4 | **182 (adapted)** | The same lever inside a full Elite board | No hint |
| 5 | **184 C** | A switch can reverse a twin; fire it at the right time | The tested hint |
| 6 | **187 E** | Twins never ram: protect a rammer for the shell in a twin's lane | No hint |
| 7 | **190 F** | Two pairs interact: the order between pairs | No hint (chapter finale) |
| 8 | **192 G** | One switch reverses both twins (back-to-back becomes facing) | No hint |
| 9 | **194 H** | Spinner rules (ALT / Pattern) make the second release window the safe one | No hint |
| 10 | **197 I** | Everything at once, without hidden blocks | No hint |

**Rules for every Twins level (safeguards from the prototype work):**
- **No twin on a Mystery board in this plan.** Mystery levels already carry six kinds of marks; a bond on top is clutter.
- **Learning steps are gentle:**
  - 176 and 177 have no losing first move and at most 2 fatal moves.
  - From 179 on, every fatal move must be a visible decision: a spinner turn, a switch fire, or a pair release that turns a spinner.
  - Never a plain-escape trap (the Level 295 lesson).
- **Geometry and colour vary.** Across the ten levels, mix horizontal and vertical pairs; facing, back-to-back, same-direction and L-different arrows; different twin colours. No two consecutive Twins boards share a pair geometry.
- **Free taps must be discoverable** (`twin_wait` states reachable) on 176, 177 and 179, and occur naturally later.

## E. Variety and pacing

**Mechanic of each level (T = Twins):**

| Chapter 18 | Mechanic | Chapter 19 | Mechanic | Chapter 20 | Mechanic |
|---|---|---|---|---|---|
| 176 | T (lesson) | 181 | 2sw | 191 | A+2G |
| 177 | T+G | 182 | T+spin (adapted) | 192 | T+sw+G |
| 178 | classic | 183 | ✦ | 193 | 2sw |
| 179 | T+spin | 184 | T+sw | 194 | T+ALT/Pattern+lock |
| 180 | reasoning | 185 | ✦ reasoning | 195 | ✦ |
| | | 186 | A+G | 196 | 2sw reasoning |
| | | 187 | T+A+G | 197 | T exam |
| | | 188 | A+2G | 198 | ✦ reasoning |
| | | 189 | ✦ | 199 | 2sw |
| | | 190 | T×2 (end) | 200 | GRAND MASTER |

**Format counts in 181–199:**

| Format | Now | Plan |
|---|---|---|
| Two-switch levels | 7 | 4 (181, 193, 196, 199) |
| Armor+Gate long-decoy levels | 4 | 1 (186) + 182 adapted with twins |
| Mystery levels | 6 | 5 (183, 185, 189, 195, 198), off the fixed every-third-level beat |
| Twins levels | 0 | 7 (182, 184, 187, 190, 192, 194, 197) |

**Rhythm:**
- Twins appear 10 times; the gaps between them are 1, 2, 3, 2, 3, 3, 2, 2, 3 levels.
- No more than three classic levels in a row (183, 185, 186 are separated by 184; the longest classic run is 195, 196 and then 198, 199).
- **The strict three-level rotation is gone.**

**Novelty beats:**
- 176: new mechanic;
- 179: first decision;
- 184: twin reversed;
- 187: shell in a twin's lane;
- 190: two pairs;
- 192: both twins reversed;
- 194: spinner-rule timing;
- 197: the exam.

That is one new idea every 2–3 levels, instead of none since 151.

**Breathing room:**
- 178 and 183 (familiar);
- 189 (Mystery);
- 193 and 195 (habit-friendly);
- 199 (calm before 200).

## F. Difficulty progression toward 200

| Stretch | Shape |
|---|---|
| **175 → 176** | A deliberate dip into a lesson (as 150 → 151 Armor, which was approved). |
| **177–180** | Easy (D) → Elite classic (178) → medium (B) → **Elite chapter end (Deep Field)**. Chapter 18 still ends hard. |
| **181–190** | Elite throughout, with C (184) as the last "learning-size" Twins board. From 187 every Twins board is at Elite density (random tapper ≤ 10%, falling to ≤ 5% at 190). Chapter 19 ends on the hardest Twins board so far. |
| **191–199** | Elite, with two hard Twins boards (192, 194), the exam (197), and classic reasoning (196, 198), easing slightly into the switch-holding 199. |
| **200** | Unchanged: the hardest board in the game, whose opening breaks the switch-holding habit. |

**Targets for the new boards** (checked with the existing tools, plus the Twins graph and agreement tools):

| Board | Blocks | Random tapper | Fatal moves | Losing first move | Max Undo | Other |
|---|---|---|---|---|---|---|
| D (177) | ≤ 13 | 60–90% | ≤ 2 | 0 | ≤ 3 | Pair opens a 2-link gate |
| E (187) | 16–19 | ≤ 10% | ≥ 2, all visible | 0 | ≤ 4 | ≥ 1 rammer-timing or release decision |
| F (190) | 16–20 | ≤ 5% | ≥ 3, visible | 0 | ≤ 4 | Releasing one pair changes the other pair's lane |
| G (192) | 16–20 | ≤ 5% | ≥ 2, visible | ≤ 1 | ≤ 4 | One switch reverses both twins |
| H (194) | 16–20 | ≤ 3% | ≥ 2 release-timing steps | 0 | ≤ 4 | ALT / Pattern spinner decides which release window is safe |
| I (197) | ≤ 22 | ≤ 2% | ≥ 3, visible | 0 | ≤ 5 | Spinner + switch + gate around one pair; no hidden blocks |

**What difficulty must not come from:** more blocks (no new board above 22), longer solutions, clutter, arbitrary restrictions, or unfair traps.

**Rules for every new board:**
- 0 plain-escape traps;
- 0 hidden-information traps (none use hidden blocks);
- Hammer rescue ≥ 50% after mistakes.

## G. Risks and safeguards

| Risk | Safeguard |
|---|---|
| **A sag from the prototype boards** (B.4) | Only A, B and C are small, at 176 / 179 / 184; from 187 on every Twins board meets the Elite targets in F; chapter ends stay hard (180 Deep Field, 190 F) |
| **Twins as a chore, not a choice** | From 179 on, every Twins board must contain a measured release-timing or ordering decision (the B.3 method, run on the design) |
| **Two rule engines disagreeing on large boards** | The existing randomized agreement test, plus exhaustive model ↔ Solver checks on every Lab Twins board (state graphs where ≤ 14 blocks; SHOW A MOVE-line checks otherwise) |
| **7×7 readability** (bond on dense boards) | No twins on Mystery boards; Twins boards are 6×6 / 6×7 / 7×7 with ≤ 22 blocks; a screenshot review of every Twins board at 375×667 |
| **Hammer recovery** | Hammer safety stays exact (tested); new boards target ≥ 50% Hammer rescue |
| **The Lab diverging from production** | Production 176–199 stays untouched. Whether production follows is a later, separate decision |
| **Repetition creeping back** (every Twins board a "spinner on the pair") | The variety rules in D (geometry, partner mechanic, colour) are checked in review; no two consecutive Twins boards share a partner mechanic |
| **The lesson save key** | `lesson_twins` is one more string in the existing `tips_seen` list (as `lesson_armor`); no save format change, no migration |
| **Social / Friend** | The Twins token stays rejected outside Lab / prototype level files (`campaign = false`); this is already tested and must be re-run |
| **Level 200 hint wording** | Report only (see the Level 200 section below) |

## H. Proposed first implementation batch: Levels 176–185

| L | Content | Work |
|---|---|---|
| 176 | A "Twin Lights" + Twins lesson | Data copy of the approved board; lesson routing |
| 177 | D "Double Link" | **Design, search and verify one new board** (D targets) |
| 178 | Crystal Heart | Unchanged |
| 179 | B "Hold Fire" | Data copy of the approved board |
| 180 | Deep Field (from 179) | Reorder only |
| 181 | Elite Entry | Unchanged |
| 182 | Gold Standard + bond R< (4,5) + Y< (5,5) | One token edit; verify (7 fatal release steps, 0 plain traps, Hammer exact) |
| 183 | High Council | Unchanged |
| 184 | C "Turnabout" | Data copy of the approved board |
| 185 | Masterwork (from 186) | Reorder only (Crown Line moves to 186, so slot 186 changes in batch 1 too) |

**Batch 1 deliberately contains:**
- the three approved boards;
- one new gentle board (D);
- one measured adaptation (182);
- six unchanged production boards: three in place (178, 181, 183) and three moved by one slot (Deep Field to 180, Masterwork to 185, Crown Line to 186).

It tests the whole learning path (steps 1–5 in D) and the difficulty dip and recovery in a single short session.

**186–199 (batch 2)** follow only after the batch 1 playtest; the six other new boards are designed then.

## I. Files that would change during implementation (none changed now)

| File | Change |
|---|---|
| `data/dev/experience_lab/level_176.json` … `level_185.json` (batch 1: 176, 177, 179, 180, 182, 184, 185; 186 for the reorder) | New / moved / adapted Lab boards (production `levels/` untouched) |
| `data/dev/experience_lab/manifest.json` | Names / sources of the changed slots |
| `tools/experience_lab_build.py` | Sources for 176–199: prototype boards, the new boards, the 182 token edit, the reorders (as `ARMOR_INTERLEAVE` / `EDITS` do for 151–170) |
| `scripts/dev/experience_lab.gd` | `LESSONS[176] = "twins"`; turn the Twins token on for Lab level files (`LevelManager.dev_twins` while the Lab is active); `seed_qa` marks `lesson_twins` seen for jumps past 176 |
| `scripts/core/level_manager.gd` | Possibly none: the gate is already `dev_twins and campaign`. Only a comment update |
| `scripts/game_manager.gd` | A `"twins"` lesson in `_lesson_step` / `_lesson_blocks` (marks the first pair, finishes on the first pair escape), as the existing lessons. The Lab-only Chapter card news, if wanted (176 is mid-Chapter 18, so probably none) |
| `scripts/core/board.gd`, `board_model.gd`, `solver.gd`, `block_data.gd`, `audio_manager.gd` | **None:** the Twins engine is already in place and approved |
| `tools/experience_lab_check.gd` | Expected boards and sources for the changed slots; Twins checks on Lab boards (model ↔ Solver agreement, Hammer exactness, SHOW A MOVE); lesson flow at 176 |
| `tools/experience_lab_qa_check.gd` | QA jumps 176 / 179 / 182 / 184 |
| `tools/web_experience_lab_test.mjs` | Names and progressions for the changed slots; the 176 lesson; real taps on a pair |
| `tools/twins_check.gd` | Run the puzzle-graph / agreement checks on the Lab Twins boards too |
| `docs/twins_176_199_integration_plan.md` (this file), a new batch-1 results doc | Documentation |

**Not touched:**
- `levels/` (production);
- Lab 1–175 and Lab 200;
- saves, the economy and achievements;
- Social / Friend code;
- the prototype mode, which can stay for comparison.

## J. Acceptance criteria for the first iPhone playtest (batch 1, Lab 176–185)

**Technical gate, before the build goes to the phone:**
- All existing suites green, with production goldens unchanged and Lab 1–175 / 200 byte-identical.
- Every changed slot:
  - solvable;
  - 0 plain-escape traps;
  - Hammer safety exact;
  - SHOW A MOVE legal and winnable from every winnable state;
  - model ↔ Solver agreement.
- The browser test passes at 375×667 / 390×844 / 430×932 with no console errors.

**Human criteria** (the tester plays 176–185 in order, from a QA jump to 176):

| # | Criterion | Pass if |
|---|---|---|
| 1 | Twins are understood at 176 without outside help | The lesson is followed; the tester can say the rule ("both leave, both paths must be clear") after the level |
| 2 | The discovery moment lands | At 176 the facing pair is felt as a pleasant surprise ("they pass through each other") |
| 3 | The free tap feels fair, not exploitable | The tester does not feel punished by a partner-blocked tap and does not use free taps to probe the board |
| 4 | The gate rule is clear at 177 | The pair opening the 2-link gate in one move is understood |
| 5 | **Real decisions** | At 179, 182 and 184 the tester reports thinking about *when* to release the pair or fire the switch (not just "clearing both lanes") |
| 6 | Fairness | No level reported as "unfair" or "I couldn't have known"; mistakes recovered with Undo / Restart / Hammer within normal effort (≤ 3 restarts per level) |
| 7 | No difficulty sag | 176–179 feel like a fresh start, not "too easy for the Elite chapters"; 180 (Deep Field) and 181–185 feel Elite again |
| 8 | Novelty | Asked "does 176–185 feel more varied than the previous run of 176–185?", the answer is yes |
| 9 | Readability | The bond is noticed on 182 (6×7, 23 blocks) on an iPhone; no mark is confused with a Chain Gate |
| 10 | Tools | SHOW A MOVE on a pair, Undo after a pair escape and Hammer on a twin all behave as in the prototype |

**Record:**
- per level: restarts, Undos, SHOW A MOVE and Hammer uses, and time;
- one line of feeling after 180 and after 185.

**Go / no-go for batch 2:** criteria 1, 5, 6 and 7 must pass. If criterion 7 fails ("too easy"), the next step is an Elite-density remake of B or C for 179 / 184, not more blocks elsewhere.

## Level 200 transition (assessment only, nothing changed)

**The lead-in is good.**
- 197 is the last Twins exam; 198 is a classic reasoning level; 199 is a switch-holding level.
- So the player arrives at 200 with the "hold the switch" habit freshly practised, and 200's opening (switch **B** must fire first) breaks it. That is the intended climax.
- With the rotation gone, 200 also stands out more clearly as "everything classic".

**Concerns, reported only:**
1. **The hint text.** Level 200's hint reads "The Grand Master. Every rule of both eras." With Twins in 176–197 and none in 200, a player may notice that one Second-Era rule is missing from the "every rule" exam.
   - **Options for a later decision:** accept it (Twins as the Elite chapters' own rule); or a Lab-only hint wording.
   - The board is not touched either way.
2. **Expectation.** After ten Twins levels, some players may expect twins in the Grand Master. The two classic levels before it (198, 199) soften this, but the human test should ask about it.
3. **Its known risks are unchanged:** rigidity (18 of 26 steps forced) and costly mistakes (a Hammer rescues 32% of stuck boards).
