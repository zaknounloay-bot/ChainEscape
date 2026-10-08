# Experience Lab 176–199: TWINS integration (implemented)

This change implements `docs/twins_176_199_integration_plan.md` (planning commit `a4fccc3`) in the Experience Lab only.

**What did not change:**
- production Levels 1–300;
- Lab 1–175 and Lab 200;
- saves, the economy, and Social / Friend data and code;
- the Twins rules (the approved prototype implementation, unchanged).

**Not yet tested by a person:** nothing here has been played on a real iPhone. The automated measurements below are evidence about structure and difficulty, **not** about enjoyment.

## 1. How to play it (itch.io)

Append the parameter to the game page URL. The `?v=` that itch.io adds is ignored.

| URL | What opens |
|---|---|
| `index.html?experiencelab=176` | Lab 176 directly (QA jump: a temporary QA save with 1–175 marked cleared; the Twins lesson plays) |
| `index.html?experiencelab=N` (2–200) | Lab N directly, the same way (e.g. `=177`, `=190`, `=199`, `=200`) |
| `index.html?experiencelab=1` | The normal Lab with its own save, from wherever it stands |
| `index.html?experiencelab=reset` | The normal Lab from Level 1 (wipes the Lab save only) |

**Behaviour of the QA jumps:**
- They never touch the real save or the normal Lab save.
- Playing on from a jump goes 176 → 177 → … → 199 → 200 (Grand Master) → the end-of-test-build screen.
- The Chapter 18 card says "NEW: Twins" (Lab only).

## 2. Final level table

**Difficulty columns:**
- **Habit / Look-ahead** = win rates of the audit's habit and look-ahead players (`tools/human_audit.gd`).
  - **Habit:** avoids spinner-turning taps and holds pairs and switches, plus a 4-move look-ahead when forced.
  - **Look-ahead:** a 4-move look-ahead player.
- **Forced** = share of solution steps with only one safe move.
- **Dead end** = moves still playable after a mistake (random / longest).

Lower habit and look-ahead values mean a harder board for simple strategies. The production Elite band (171–199) is habit 0.01–0.52 and look-ahead 0–0.10.

| L | Puzzle | Decision | Twins | Key interaction | Habit | Look-ahead | Forced | Dead end | Difficulty assessment | Deviation from plan |
|---|---|---|---|---|---|---|---|---|---|---|
| 175 | Shatter Point | (approved, unchanged) | – | Milestone | 0.15 | 0.00 | 0.57 | 11 / 18 | Elite milestone | – |
| 176 | Twin Lights | REPLACE (approved prototype board A) | YES | Guided lesson; facing red pair passes through itself | 1.00 | 1.00 | 0 | – | **Intentionally very easy:** no fatal move at all | Uses the existing Lab lesson system (marks, finger, explanation of a partner-blocked tap) |
| 177 | Double Link | REPLACE (new) | YES | Vertical pair = both links of Gate C; the gate opens in one move for the green arrow aimed at it | 1.00 | 1.00 | 0.06 | 2.5 / 3 | Easy: 2 fatal moves (spinner), recover within 3 Undos, random tapper 75% | Yellow pair, 9 blocks; short hint |
| 178 | Crystal Heart | KEEP | – | Armor colour key, switch, gate | 0.52 | 0.00 | 0.63 | 7 / 14 | Elite (breathing room after two Twins levels) | – |
| 179 | Hold Fire | REPLACE (approved prototype board B) | YES | Release timing: the pair turns the spinner on top of it | 1.00 | 1.00 | 0.06 | 1.3 / 4 | Medium: 16 visible fatal moves, max 4 Undos | – |
| 180 | Deep Field | RELOCATE (from 179) | – | Chained link turns a spinner | 0.07 | 0.00 | 0.84 | 5.6 / 18 | Elite chapter end (reasoning level) | – |
| 181 | Elite Entry | KEEP | – | Two switches, four spinner rules | 0.10 | 0.00 | 0.23 | 9.5 / 16 | Elite reasoning | – |
| 182 | Gold Standard | ADAPT (red R< + yellow Y< bonded) | YES | The pair beside a Pattern spinner: fatal at 7 steps of SHOW A MOVE's line | 0.05 | 0.00 | 0.21 | 9.8 / 20 | Elite: unchanged from production (0.04 / 0.00 / 0.22) | First mixed-colour pair; the board keeps production's one losing first move |
| 183 | High Council ✦ | KEEP | – | Mystery, hold the switch | 0.02 | 0.00 | 0.90 | 9.5 / 18 | Elite (habit-friendly breather) | – |
| 184 | Turnabout | REPLACE (approved prototype board C) | YES | A switch that reverses a twin is the obstacle, the direction changer and the trap | 1.00 | 1.00 | 0.09 | 2.3 / 4 | Medium (the last learning-size board) | – |
| 185 | Masterwork ✦ | RELOCATE (from 186) | – | Mystery reasoning | 0.01 | 0.00 | 0.78 | 11 / 19 | Elite | – |
| 186 | Crown Line | RELOCATE (from 185) | – | Armor + Gate, long decoy | 0.03 | 0.00 | 0.65 | 10.5 / 20 | Elite | – |
| 187 | Shell Game | REPLACE (new) | YES | A shell blocks one twin's lane; twins never ram, so a spinner above it must crack it; the twin is Gate C's link; every fatal move is a mistimed pair release | 0.45 | 0.09 | 0.36 | 7.7 / 13 | Elite entry (≈ Champion 189) | Hint added: "Twins can't crack a shell - another block must" (the plan had no hint; it states a consequence of the approved rules) |
| 188 | Summit Key | KEEP | – | Armor + two gates | 0.07 | 0.01 | 0.28 | 14 / 19 | Elite | – |
| 189 | Champion ✦ | KEEP | – | Mystery, Armor key | 0.44 | 0.05 | 0.35 | 5.8 / 12 | Elite | – |
| 190 | Two Bonds | REPLACE (new) | YES | Two pairs (horizontal purple, vertical L red), each beside its own spinners; both have wrong release moments | 0.20 | 0.06 | 0.12 | 8.4 / 13 | Hard Chapter 19 finale; most "meaningful" choices so far (0.08) | – |
| 191 | Final Ascent | KEEP | – | Armor + two gates | 0.04 | 0.00 | 0.62 | 10.6 / 20 | Elite | – |
| 192 | Reversal | REPLACE (new) | YES | One switch reverses **both** back-to-back twins (they turn to face each other) and a third arrow; twins are 2 of Gate C's 3 links; every fatal move is a switch fire | 0.22 | 0.05 | 0.22 | 7.1 / 13 | Hard; one losing first move (firing the switch at once), as the plan allows | – |
| 193 | Last Light | KEEP | – | Two switches | 0.22 | 0.01 | 0.59 | 5.5 / 11 | Elite breather | – |
| 194 | Pattern Lock | REPLACE (new) | YES | The red pair under an Alternating and a clockwise spinner; every fatal move is a mistimed release; red keys the purple lock | 0.27 | 0.12 | 0.34 | 7.7 / 14 | Hard; highest "meaningful choice" share in the run (0.19) | The lock is a colour-key detail, not the main decision (the plan called it a "lock timing" board) |
| 195 | Zenith ✦ | KEEP | – | Mystery, forgiving | 0.38 | 0.02 | 0.15 | 9.7 / 15 | Elite breather | – |
| 196 | Grandmaster Path | KEEP | – | Two switches, pure reasoning | 0.20 | 0.03 | 0.18 | 6.5 / 12 | Elite reasoning | – |
| 197 | Bond of Ages | REPLACE (new) | YES | L-shaped pair between two spinners; one twin flipped by switch A; both twins Gate C links; locks around it | 0.23 | 0.12 | 0.17 | 6.2 / 13 | The Twins exam (hard) | 21 blocks; random tapper 2.7% (plan: ≤ 2%) |
| 198 | Legacy ✦ | KEEP | – | Mystery reasoning, Pattern decoy | 0.02 | 0.00 | 0.41 | 10.8 / 18 | Elite reasoning | – |
| 199 | Eternal Chain | KEEP | – | Hold the switches | 0.24 | 0.00 | 0.68 | 8.8 / 17 | Elite; sets up 200's habit-breaking opening | – |
| 200 | The Grand Master | (unchanged) | – | Everything classic | 0.00 | 0.00 | 0.66 | 10.5 / 23 | The peak | – |

**Fairness across the ten Twins levels** (complete state graphs on the Solver's rules, a pair counted once):
- 0 plain-escape traps: every fatal move turns a spinner, fires a switch, or is a pair release that turns a spinner;
- 0 hidden-information traps (no Twins on Mystery boards);
- 0 shells that can strand;
- no losing first move, except 182 (inherited from production) and 192 (planned).

## 3. How the new boards were made (and refined)

The six new boards (D–I) were found with a scratch search on the real `Solver`, using a complete state graph per candidate.

**Accepted only if:**
- 0 plain-escape traps;
- the plan's twin feature is present (gate links, shell in a twin's lane, two pairs, a switch reversing both twins, an Alternating / Pattern spinner beside the pair, spinner + switch + gate);
- production-like composition: at most 6 spinners, at most 2 Alternating / Pattern spinners, 2 locks or fewer.

**First pass, rejected.** The audit's habit player (it holds pairs back and avoids spinner turns) beat the first versions of 187–197 at **91–100%**, against 2–13% for the boards they replaced. They fell to "release the pair last". That would have re-created the old "solved by one habit" problem with a new coat.

**Second pass.** The boards were refined (only filler blocks changed, never the pair or its partner mechanic) until the habit player wins ≤ 25–45% and the 4-move look-ahead player ≤ 6–12%. Those are production Elite levels.

## 4. Full-sequence pacing report (175 → 200)

### Difficulty progression

- **175 → 176:** the deliberate reset: a lesson board with no fatal move.
- **176–184:** a learning band: four easy-to-medium Twins boards (176 A, 177 D, 179 B, 184 C) interleaved with five Elite classics (178, 180, 181, 182, 183). Chapter 18 still ends on a reasoning level (Deep Field, 180).
- **From 187:** every Twins board is at Elite difficulty by decisions, not size. They have **fewer blocks** than the boards they replaced (17–21 vs 20–25) and **more freedom**:
  - forced share 0.12–0.36, against 0.38–0.84 for the replaced boards;
  - deviation survival 0.47–0.97, against 0.11–0.45.
- **The curve through 187–197** on the habit player falls 0.45 → 0.20 → 0.22 → 0.27 → 0.23 against breathers at 189 / 193 / 195. The run-in 196–199 is classic Elite. 200 is unchanged.

### Twins learning progression

| Level | What is learned |
|---|---|
| 176 | Rule and the facing-pair surprise (lesson) |
| 177 | Twins as gate links |
| 179 | Release timing (spinner) |
| 182 | Timing inside a full Elite board |
| 184 | Switch reverses a twin |
| 187 | Twins never ram |
| 190 | Two pairs |
| 192 | One switch reverses both |
| 194 | Spinner rules decide the window |
| 197 | Everything at once |

### Variety

- **The old strict rotation is gone.** Mystery levels now sit at 183, 185, 189, 195 and 198.
- **Format counts in 181–199:**

| Format | Before | After |
|---|---|---|
| Two-switch levels | 7 | 4 |
| Armor+Gate long-decoy levels | 4 | 1 (+ 182 with Twins) |
| Twins levels | 0 | 7 |

### Repeated patterns: an honest concern

- **One decision dominates.** The Twins decision on 179, 182, 187, 190, 194 and 197 is mostly the same idea: *the pair release turns a spinner, so release it at the right moment*.
- **The surroundings differ:**
  - a shell and rammer (187);
  - two pairs (190);
  - Alternating / Pattern rules (194);
  - switch and gate (197).
- **The exceptions:** 177 (gate links) and 184 / 192 (switch reversal) are the only Twins levels whose key decision is not spinner timing.
- **Next step if needed:** if testers say "the twins puzzles all feel alike", the next refinement is to make 194 or 197 turn on the switch or gate rather than a spinner.

### Potential frustration points

| Level | Watch for |
|---|---|
| 182 | One losing first move (as in production) on a dense 23-block board with a mixed-colour pair: is the bond noticed? |
| 192 | Firing the switch first loses at once (the one losing first move) |
| 197 | Dense 7×7 (21 blocks) with switch, gate and lock badges around the pair |
| 194, 197 | Look-ahead win slightly above the production maximum (0.12 vs 0.10): good for decisions, but mistakes can be deep (dead ends up to 13–14 moves) |

### Possibly too easy

- **184 Turnabout** (approved prototype board C) sits in the 181–185 "return to advanced difficulty" band as a learning-size board. The habit and look-ahead players win 100%.
- **Why it was kept:** it is an approved puzzle (not redesigned silently), and it works as breathing room between 183 and 185.
- **If testers find it a step back:** an Elite-density remake for 184 is the smallest change.

### Possibly too hard

None found beyond the Elite band. **200** remains the peak (forced 0.66, dead ends to 23, a Hammer rescues few stuck boards), unchanged.

### Lead-in to 200

- 197 is the last Twins level; 198 is classic reasoning; 199 builds the switch-holding habit that 200's opening breaks.
- **Wording, report only (not changed):** 200's hint "Every rule of both eras" does not include Twins, which appear in 176–197 only.

### Remaining "more of the same" risk

- **Lower than before:** a new idea every 2–3 levels, and the Elite Twins boards have more meaningful choices than the classics they replaced.
- **What remains:** the spinner-timing commonality above, and the classic stretches 185–186 and 188–189 (Mystery / Armor+Gate).

## 5. Tests

| Test | Result |
|---|---|
| `tools/ExperienceLabCheck.tscn` (whole Lab, data + game) | 5,868 checks pass. Covers sources, Twins only in their slots, full-graph fairness of every Twins level, model ↔ Solver agreement walks, Hammer / SHOW A MOVE on sampled states, the 176 lesson, every transition (175 → 176 … 199 → 200, Chapter 18 / 19 / 20 cards, NEW: Twins only on Chapter 18's Lab card), 200's Grand Master card and one-time bonus, and save isolation |
| QA jumps, browser test, full regression | See the commit report |
| Visual review | `tools/TwinsCapture.tscn -- --lab` at 375×667, 390×844 and 430×932; screenshots in `docs/twins_176_199_shots/` |

## 6. Changed files

| File | Change |
|---|---|
| `data/dev/experience_lab/level_176.json` … `level_197.json` (176, 177, 179, 180, 182, 184, 185, 186, 187, 190, 192, 194, 197) and `manifest.json` | Lab data (built by the script) |
| `tools/experience_lab_build.py` | Sources for 176–199, the new boards, the 182 bond |
| `scripts/dev/experience_lab.gd` | `LESSONS[176] = "twins"`, `TWINS_INTRO`, the Twins token on for the Lab's own files |
| `scripts/game_manager.gd` | The Twins lesson; Chapter card news (Lab only); Lab test state |
| `tools/experience_lab_check.gd`, `tools/experience_lab_qa_check.gd`, `tools/web_experience_lab_test.mjs` | Checks |
| `tools/human_audit.gd` | A pair counted as one move (boards with twins only) |
| `tools/twins_capture.gd` | `--lab` mode |
| `docs/` | This file and screenshots |

**Not touched:**
- the Twins engine (`board_model.gd`, `solver.gd`, `board.gd`, `level_manager.gd`, `block_data.gd`);
- production `levels/`;
- the Twins prototype mode.
