# Human-solvability audit, levels 226–300 (analysis only)

Nothing was changed: no level, game code, solver, hint or UI change. Tool: `tools/human_audit.gd` (not committed). It builds each level's **complete** reachable state graph with the game's own rules. Every level was explored in full: 7 to 6,037 states.

## Method (what each column means)

All moves are irreversible except pushes, so a "mistake" means a **fatal move**: one after which the board can never be won.

- **Flexibility.** Built from three measures:
  - *Deviation survival:* the share of the non-solution moves along the solver's line that keep the board winnable.
  - *Forced steps:* one safe move among two or more legal moves.
  - *Corridor width:* winnable states per solution step.

  Plain move-order permutations are not counted as flexibility. For example, Level 295 has about 40 million winning move orders but one plan.
- **Dead-end depth.** After a fatal move: how many more moves can be played before the board is visibly stuck (no legal move)? Reported as typical (random continuation) and maximum. "Not undo-reachable" means the shortest route to stuck is 3 or more moves, so with 3 Undos the player can't get back once the loss is visible.
- **Recovery.** Deviation survival, plus fatal moves whose failure shows within undo reach.
- **Hint-dependency risk.** Structural signals, not a measurement of human frustration:
  - **Rule + look-ahead player:** plays plain escapes freely (the Classic rule "an escape that turns nothing can't spoil the board") and checks each risky move (spinner turn, first stage, ram, push) up to 8 moves ahead.
  - **Innocent-escape traps:** solution steps where a plain escape is fatal.
  - **Hidden-trap steps.**
  - **Hidden depth.**
  - **Narrowness.**
  - **Push-route length.**
  - **Number of risky decisions.**

  Each signal adds points: LOW ≤ 1, MEDIUM 2–3, HIGH 4–5, CRITICAL ≥ 6.
- **Verdict.** Fixed rules, applied mechanically:
  - REDESIGN CANDIDATE: CRITICAL, or HIGH and single-path.
  - REVIEW: HIGH.
  - WATCH: MEDIUM with SEVERE dead ends or low flexibility.
  - KEEP: everything else.

  The same rules were applied to 176–225 as a calibration baseline.

## Full table 226–300

| Level | Mechanics | Diff | Flexibility | Dead-end risk (typ / max depth) | Recovery | Hint-dependency risk | Primary reason | Verdict |
|---|---|---|---|---|---|---|---|---|
| 226 | seq | 5.8 | HIGH | LOW (none) | HIGH | LOW | no traps (lesson) | **KEEP** |
| 227 | seq | 7.0 | HIGH | LOW (none) | HIGH | LOW | no traps (lesson) | **KEEP** |
| 228 | portal, seq | 8.5 | HIGH | LOW (none) | HIGH | LOW | no traps (lesson) | **KEEP** |
| 229 | spin, seq | 21.1 | LOW | MEDIUM (6 / 10) | HIGH | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 230 | spin, portal, seq | 24.8 | LOW | MEDIUM (4 / 7) | PARTIAL | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 231 | spin, seq | 33.4 | SINGLE-PATH | MEDIUM (5 / 10) | LOW | LOW | narrow line (forced 60%, deviations survive 28%) | **KEEP** |
| 232 | spin, mystery, seq | 38.5 | HIGH | MEDIUM (6 / 14) | HIGH | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 233 | spin, lock, seq | 39.5 | SINGLE-PATH | MEDIUM (7 / 13) | PARTIAL | LOW | narrow line (forced 61%, deviations survive 38%) | **KEEP** |
| 234 | spin, armor, seq | 42.1 | SINGLE-PATH | SEVERE (10 / 16) | LOW | MEDIUM | rule+8-lookahead wins 12%; wrong move stays hidden ~10 moves; narrow line (forced 70%, deviations survive 24%) | **WATCH** |
| 235 (breather) | spin, seq | 30.8 | SINGLE-PATH | MEDIUM (6 / 10) | PARTIAL | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 236 | spin, seq | 41.2 | SINGLE-PATH | MEDIUM (6 / 13) | LOW | LOW | narrow line (forced 69%, deviations survive 13%) | **KEEP** |
| 237 | spin, portal, seq | 42.8 | HIGH | HIGH (8 / 15) | PARTIAL | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 238 | spin, seq | 43.3 | LOW | SEVERE (13 / 16) | PARTIAL | MEDIUM | rule+8-lookahead wins 24%; wrong move stays hidden ~13 moves | **WATCH** |
| 239 | spin, portal, seq | 46.5 | LOW | HIGH (10 / 18) | PARTIAL | LOW | wrong move stays hidden ~10 moves | **KEEP** |
| 240 | spin, portal, seq | 46.5 | LOW | SEVERE (9 / 17) | LOW | MEDIUM | wrong move stays hidden ~9 moves; narrow line (forced 48%, deviations survive 23%) | **WATCH** |
| 241 | spin, seq | 48.9 | LOW | SEVERE (10 / 18) | PARTIAL | MEDIUM | wrong move stays hidden ~10 moves; narrow line (forced 58%, deviations survive 37%) | **WATCH** |
| 242 | spin, portal, seq | 51.0 | MEDIUM | SEVERE (11 / 19) | PARTIAL | LOW | wrong move stays hidden ~11 moves | **KEEP** |
| 243 | spin, armor, seq | 51.6 | MEDIUM | SEVERE (10 / 18) | PARTIAL | MEDIUM | rule+8-lookahead wins 12%; wrong move stays hidden ~10 moves | **WATCH** |
| 244 (breather) | spin, portal, seq | 39.6 | LOW | HIGH (7 / 14) | PARTIAL | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 245 | spin, seq | 53.0 | MEDIUM | SEVERE (10 / 19) | HIGH | MEDIUM | rule+8-lookahead wins 25%; wrong move stays hidden ~10 moves | **WATCH** |
| 246 | spin, lock, seq | 54.0 | SINGLE-PATH | HIGH (10 / 19) | PARTIAL | MEDIUM | rule+8-lookahead wins 24%; wrong move stays hidden ~10 moves; narrow line (forced 65%, deviations survive 39%) | **WATCH** |
| 247 | spin, portal, seq | 54.5 | LOW | SEVERE (10 / 20) | LOW | MEDIUM | wrong move stays hidden ~10 moves; narrow line (forced 59%, deviations survive 23%) | **WATCH** |
| 248 | spin, mystery, seq | 56.2 | LOW | SEVERE (11 / 20) | LOW | CRITICAL | rule+8-lookahead wins 2%; 18 steps with hidden traps; wrong move stays hidden ~11 moves | **REDESIGN CANDIDATE** |
| 249 | spin, portal, seq | 56.5 | MEDIUM | SEVERE (11 / 21) | PARTIAL | HIGH | rule+8-lookahead wins 14%; 19 steps with hidden traps; wrong move stays hidden ~11 moves | **REVIEW** |
| 250 | spin, portal, seq | 63.8 | MEDIUM | SEVERE (11 / 22) | PARTIAL | HIGH | rule+8-lookahead wins 20%; 20 steps with hidden traps; wrong move stays hidden ~11 moves | **REVIEW** |
| 251 | spin, mov | 8.5 | SINGLE-PATH | LOW (2 / 2) | HIGH | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 252 | spin, mov | 11.8 | SINGLE-PATH | MEDIUM (3 / 4) | HIGH | MEDIUM | rule+8-lookahead wins 0% | **WATCH** |
| 253 | spin, mov | 14.7 | LOW | MEDIUM (5 / 6) | PARTIAL | MEDIUM | rule+8-lookahead wins 0%; innocent escapes fatal at 2 steps | **WATCH** |
| 254 | spin, mov | 12.5 | LOW | MEDIUM (6 / 8) | HIGH | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 255 | spin, mov | 27.1 | SINGLE-PATH | MEDIUM (6 / 10) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 8 solution steps | **REDESIGN CANDIDATE** |
| 256 | spin, mov | 23.9 | SINGLE-PATH | HIGH (8 / 13) | PARTIAL | MEDIUM | rule+8-lookahead wins 0%; innocent escapes fatal at 3 steps; one parking cell | **WATCH** |
| 257 | spin, mov | 28.6 | LOW | HIGH (7 / 11) | LOW | MEDIUM | rule+8-lookahead wins 0%; innocent escapes fatal at 3 steps | **WATCH** |
| 258 (breather) | spin, mov | 23.6 | SINGLE-PATH | HIGH (8 / 12) | LOW | LOW | narrow line (forced 60%, deviations survive 33%) | **KEEP** |
| 259 | spin, mov | 33.4 | SINGLE-PATH | HIGH (7 / 15) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 9 solution steps; narrow line (forced 33%, deviations survive 23%) | **REDESIGN CANDIDATE** |
| 260 | spin, mov | 31.9 | LOW | HIGH (7 / 14) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 4 steps; narrow line (forced 49%, deviations survive 32%) | **REVIEW** |
| 261 | spin, mov | 42.2 | HIGH | SEVERE (9 / 23) | PARTIAL | HIGH | rule+8-lookahead wins 22%; innocent escapes fatal at 3 steps; wrong move stays hidden ~9 moves | **REVIEW** |
| 262 | spin, mov | 36.9 | MEDIUM | HIGH (9 / 17) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 8 solution steps | **REVIEW** |
| 263 | spin, mov | 43.3 | MEDIUM | HIGH (8 / 16) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 8 solution steps | **REVIEW** |
| 264 (breather) | spin, mov | 30.1 | MEDIUM | HIGH (7 / 11) | PARTIAL | MEDIUM | rule+8-lookahead wins 0%; innocent escapes fatal at 3 steps | **KEEP** |
| 265 | spin, mov | 36.0 | HIGH | HIGH (8 / 21) | HIGH | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 266 | spin, mov | 42.6 | LOW | HIGH (7 / 15) | LOW | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 267 | spin, armor, mov | 40.4 | LOW | SEVERE (9 / 16) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 3 steps; wrong move stays hidden ~9 moves | **REVIEW** |
| 268 | spin, portal, mov | 28.1 | SINGLE-PATH | HIGH (8 / 18) | LOW | LOW | narrow line (forced 53%, deviations survive 33%) | **KEEP** |
| 269 | spin, seq, mov | 44.8 | LOW | HIGH (8 / 18) | LOW | HIGH | rule+8-lookahead wins 5%; innocent escapes fatal at 6 solution steps; 7-push route | **REVIEW** |
| 270 (breather) | spin, portal, mov | 35.1 | SINGLE-PATH | HIGH (7 / 14) | NONE | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 6 solution steps; narrow line (forced 72%, deviations survive 12%) | **REDESIGN CANDIDATE** |
| 271 | spin, portal, mov | 45.3 | HIGH | HIGH (8 / 13) | HIGH | LOW | 8-push route; one parking cell | **KEEP** |
| 272 | spin, seq, mov | 47.8 | LOW | SEVERE (11 / 18) | LOW | LOW | wrong move stays hidden ~11 moves; one parking cell | **KEEP** |
| 273 | spin, seq, mov | 52.3 | SINGLE-PATH | HIGH (9 / 20) | LOW | HIGH | rule+8-lookahead wins 0%; wrong move stays hidden ~9 moves; narrow line (forced 50%, deviations survive 24%) | **REDESIGN CANDIDATE** |
| 274 | spin, portal, mov | 49.1 | LOW | SEVERE (13 / 22) | PARTIAL | CRITICAL | rule+8-lookahead wins 0%; innocent escapes fatal at 5 solution steps; wrong move stays hidden ~13 moves | **REDESIGN CANDIDATE** |
| 275 | spin, portal, mov | 54.4 | MEDIUM | MEDIUM (6 / 12) | PARTIAL | LOW | 7-push route | **KEEP** |
| 276 | spin, portal, seq | 50.3 | MEDIUM | SEVERE (11 / 18) | LOW | LOW | wrong move stays hidden ~11 moves | **KEEP** |
| 277 | spin, portal, mov | 49.3 | SINGLE-PATH | MEDIUM (6 / 17) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 6 solution steps; 8-push route | **REDESIGN CANDIDATE** |
| 278 | spin, seq, mov | 54.3 | LOW | SEVERE (10 / 23) | LOW | HIGH | rule+8-lookahead wins 1%; wrong move stays hidden ~10 moves; 7-push route | **REVIEW** |
| 279 | spin, seq | 53.2 | MEDIUM | HIGH (8 / 18) | PARTIAL | LOW | narrow line (forced 45%, deviations survive 42%) | **KEEP** |
| 280 | spin, armor, portal, seq | 53.3 | LOW | SEVERE (10 / 19) | LOW | MEDIUM | rule+8-lookahead wins 13%; wrong move stays hidden ~10 moves; narrow line (forced 63%, deviations survive 21%) | **WATCH** |
| 281 (breather) | spin, portal, seq | 44.4 | HIGH | HIGH (8 / 16) | HIGH | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 282 | spin, mov | 41.7 | MEDIUM | HIGH (7 / 19) | PARTIAL | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 283 | spin, mystery, portal, seq | 58.5 | MEDIUM | SEVERE (11 / 21) | PARTIAL | MEDIUM | 19 steps with hidden traps; wrong move stays hidden ~11 moves; 21 risky decisions | **WATCH** |
| 284 | spin, lock, mov | 58.2 | LOW | SEVERE (10 / 22) | NONE | CRITICAL | rule+8-lookahead wins 0%; innocent escapes fatal at 3 steps; wrong move stays hidden ~10 moves | **REDESIGN CANDIDATE** |
| 285 | spin, portal, seq | 57.6 | HIGH | SEVERE (12 / 21) | PARTIAL | MEDIUM | 19 steps with hidden traps; wrong move stays hidden ~12 moves; 21 risky decisions | **WATCH** |
| 286 | spin, portal, seq, mov | 59.2 | LOW | SEVERE (11 / 23) | LOW | HIGH | 21 steps with hidden traps; wrong move stays hidden ~11 moves; narrow line (forced 48%, deviations survive 24%) | **REVIEW** |
| 287 (breather) | spin, seq, mov | 48.8 | MEDIUM | HIGH (9 / 19) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 4 steps; 6-push route | **REVIEW** |
| 288 | spin, gate, portal, seq | 59.4 | SINGLE-PATH | SEVERE (10 / 20) | NONE | MEDIUM | 18 steps with hidden traps; wrong move stays hidden ~10 moves; narrow line (forced 77%, deviations survive 12%) | **WATCH** |
| 289 | spin, armor, mov | 50.7 | LOW | HIGH (9 / 15) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 5 solution steps; narrow line (forced 47%, deviations survive 27%) | **REVIEW** |
| 290 | spin, mystery, mov | 54.1 | LOW | HIGH (9 / 18) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 6 solution steps; 18 steps with hidden traps | **REVIEW** |
| 291 | spin, seq, mov | 53.2 | MEDIUM | HIGH (9 / 21) | PARTIAL | MEDIUM | 19 steps with hidden traps; 8-push route; one parking cell | **KEEP** |
| 292 | spin, switch, portal, seq | 66.5 | HIGH | HIGH (7 / 17) | HIGH | LOW | decisions visible: risky moves only, short look-ahead suffices | **KEEP** |
| 293 | spin, portal, mov | 53.9 | LOW | SEVERE (11 / 65) | LOW | CRITICAL | rule+8-lookahead wins 0%; innocent escapes fatal at 9 solution steps; 18 steps with hidden traps | **REDESIGN CANDIDATE** |
| 294 (breather) | spin, seq, mov | 44.5 | LOW | SEVERE (10 / 17) | LOW | LOW | wrong move stays hidden ~10 moves | **KEEP** |
| 295 | spin, lock, seq, mov | 51.0 | LOW | SEVERE (9 / 27) | LOW | CRITICAL | rule+8-lookahead wins 0%; innocent escapes fatal at 8 solution steps; 19 steps with hidden traps | **REDESIGN CANDIDATE** |
| 296 | spin, portal, seq | 65.4 | MEDIUM | SEVERE (10 / 22) | PARTIAL | HIGH | rule+8-lookahead wins 20%; 20 steps with hidden traps; wrong move stays hidden ~10 moves | **REVIEW** |
| 297 | spin, mov | 52.4 | LOW | HIGH (9 / 18) | LOW | HIGH | rule+8-lookahead wins 0%; innocent escapes fatal at 9 solution steps; 6-push route | **REVIEW** |
| 298 | armor, seq, mov | 55.8 | LOW | SEVERE (12 / 23) | LOW | HIGH | rule+8-lookahead wins 0%; 18 steps with hidden traps; wrong move stays hidden ~12 moves | **REVIEW** |
| 299 | spin, portal, seq | 68.1 | LOW | SEVERE (10 / 23) | LOW | HIGH | rule+8-lookahead wins 17%; 21 steps with hidden traps; wrong move stays hidden ~10 moves | **REVIEW** |
| 300 | spin, portal, seq | 74.7 | MEDIUM | HIGH (8 / 20) | LOW | HIGH | rule+8-lookahead wins 2%; 23 steps with hidden traps; 25 risky decisions | **REVIEW** |

## 1. Aggregate comparison

| Group | n | Deviation survival | Forced steps | Meaningful choices | Corridor width | Hidden dead-end depth (typ) | Mistakes not undo-reachable | Innocent-escape fatal (steps/level) | Rule+8-lookahead win | Pushes | Single-path / Low flex | Dead-end SEVERE | Recovery LOW/NONE | Hint HIGH+CRIT | Verdicts K/W/R/RC |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 176-200 Classic late (baseline) | 25 | 0.30 | 0.54 | 0.02 | 3.3 | 9.5 | 92% | 0.0 | 0.28 | 0.0 | 13 / 6 | 15 | 14 | 9 | 9/7/2/7 |
| 201-225 Portal (baseline) | 25 | 0.35 | 0.37 | 0.01 | 4.9 | 7.7 | 90% | 0.0 | 0.85 | 0.0 | 5 / 6 | 6 | 6 | 1 | 22/2/1/0 |
| 226-250 Sequence | 25 | 0.38 | 0.44 | 0.01 | 4.6 | 8.7 | 90% | 0.0 | 0.59 | 0.0 | 6 / 9 | 11 | 6 | 3 | 14/8/2/1 |
| 251-275 Movable | 25 | 0.38 | 0.36 | 0.09 | 4.7 | 7.4 | 93% | 2.9 | 0.28 | 3.8 | 9 / 9 | 4 | 14 | 11 | 10/4/6/5 |
| 276-300 Integration | 25 | 0.33 | 0.35 | 0.04 | 8.5 | 9.4 | 97% | 2.0 | 0.25 | 3.4 | 2 / 12 | 14 | 17 | 14 | 7/4/10/4 |
| 276-300 WITH Movable | 14 | 0.30 | 0.33 | 0.06 | 8.4 | 9.3 | 99% | 3.6 | 0.19 | 6.1 | 1 / 10 | 7 | 12 | 11 | 3/0/7/4 |
| 276-300 WITHOUT Movable | 11 | 0.38 | 0.38 | 0.02 | 8.8 | 9.6 | 94% | 0.0 | 0.34 | 0.0 | 1 / 2 | 7 | 5 | 3 | 4/4/3/0 |

**Reading the comparison.** The rule-independent measures are similar across all eras and do not single out Movable:
- dead-end depth
- the share of mistakes that can't be undone
- deviation survival
- pure look-ahead wins

Deep, hidden dead ends are a core-game property: late Classic 176–200 already has them at 9.5 moves, with 92% unreachable by Undo.

What Movable changes is different:
1. **It breaks the Classic safety rule.** Before 251, a plain escape (one that turns nothing) was never fatal in any level. From 251, plain escapes are fatal on 2.9–3.6 solution steps per level, because any block may be the pusher the Movable block will need later.
2. **It adds long push routes.** Many levels need 6–9 pushes into a single parking cell (one possible final position).

Inside 276–300, the control group:

| Measure | With Movable | Without Movable |
|---|---|---|
| Hint-dependency HIGH or CRITICAL | 11 of 14 | 3 of 11 |
| REDESIGN CANDIDATE | 4 | 0 |
| Recovery LOW or NONE | 12 | 5 |
| Rule + look-ahead win rate | 0.19 | 0.34 |

## 2. Level 295 case study ("Heavy Lock", 7x7)

**Board:**
- 15 arrow blocks and one Movable block at (c2, r4).
- A Sequence block 0 at (c2, r1), pointing down, with right as its NEXT arrow.
- A spinner 1 at (c6, r1).
- Block 7 at (c0, r4), locked by the red key (block 3).

**State space:**
- 1,418 reachable states, of which only 214 (15%) can still be won.
- About 40 million winning move orders.
- Meaningful choices at **0%** of steps: every pair of safe moves commutes.
- **One** route for the Movable block: (c2,r5) → (c3,r5) → (c4,r5) → (c4,r4) → (c4,r3) → (c4,r2) → (c3,r2) → (c2,r2) → (c2,r3).
- That is **9 pushes by 5 different pushers**, in a fixed order: red ↓, yellow → ×2, green ↑ ×3, blue ← ×2, then the Sequence block ↓ as the last pusher.
- There is **one** final position for the block: (c2,r3).

The answers to the brief's nine questions:
1. **Critical decision points:** 19 of the 25 solution steps hold a fatal alternative, and 12 steps are forced (one safe move among two or more).
2. **Irreversible decisions:** every escape, and every push the push order doesn't allow to be redone (the pushers leave). Three kinds stand out:
   - The Sequence block's first stage is fatal **every** time it is available (100%): block 0 must keep its down arrow to become the last pusher.
   - Escapes that turn a spinner are fatal 76% of the time; pushes 29%.
   - Plain escapes are fatal at 8 solution steps. Example: green 16, the only upward pusher, which can leave from move 4.
3. **Winning paths:** about 40 million orders, but 1 plan and 1 route for the Movable block. Effectively single-path.
4. **Plausible losing paths:** the Movable block ends on an edge cell inside a remaining arrow's lane. The most common dead-end boards are:
   - (c6,r5): yellow 10 and purple 14 can never leave.
   - (c3,r6): blue 9 can never leave.
   - (c4,r0): green 16 can never leave.
   - Or green 16 left early, so nobody can lift the block.
5. **When a loss becomes mathematically doomed:** as early as move 4. At search depth 4, 2 of the 6 states are already lost; at depth 8, 14 of 23 are.
6. **When the failure becomes visible:** after a fatal move the board can be played on for at least 3 moves (min 8 on average), typically about 9, at most 27. Every one of 295's fatal moves is beyond the reach of 3 Undos once it shows.
7. **Knowledge needed too far ahead:** yes. A player who checks every move 8 moves ahead wins 0.3%. With the Classic rule (play plain escapes freely), the win rate is 0%. The key fact ("the block must end at (c2,r3), and block 0 must stay pointing down until the end") is not visible on the starting board. (c2,r3) only becomes a cell outside every lane after 9 other blocks have left.
8. **Alternative move orders:** only interleavings of independent escapes survive. Any change in **which** block pushes, **when**, or a Sequence first stage taken early fails. Only 24% of off-solution moves survive.
9. **Mastery or sequence discovery:** primarily discovery of one exact sequence. The level asks the player to plan a 9-step Sokoban tour that ends at a parking cell they can't identify at the start.

**Why it produced the hint-extraction loop:**
- The level has 19 hidden-trap decisions, each detectable only about 9 moves later.
- SHOW A MOVE gives 2 per attempt, and Undo (3) can't reach back far enough. That forces about 10 restarts to collect the decisions two at a time, which is exactly the behaviour observed.
- SHOW A MOVE on a doomed board is free and says "This board can't be cleared from here". That invites probing for doom rather than reasoning.
- Root cause on the production side: my generator **rewarded** these properties. Trap count and depth fed the difficulty estimate, and needs like "a push that loses" were acceptance targets. The push cap allowed up to 10 pushes on a 25-move solution.

## 3. Top 10 highest-risk levels

| # | Level | Mechanics | Main problem |
|---|---|---|---|
| 1 | 295 | spin, lock, seq, mov | 9-push single route, one parking cell, plain escapes fatal at 8 steps, Sequence first stage always fatal |
| 2 | 293 | spin, portal, mov | Plain escapes fatal at 9 steps; the block cycles through a portal (longest dead end: 65 moves); rule + look-ahead wins 0% |
| 3 | 284 | spin, lock, mov | Recovery NONE, one parking cell, 6-push route, mistakes hidden about 10 moves |
| 4 | 274 | spin, portal, mov | Mistakes hidden about 13 moves (the deepest), plain escapes fatal at 5 steps, 6-push route |
| 5 | 248 | spin, mystery, seq | No Movable. 18 hidden-trap steps, rule + look-ahead wins 2%, 56% forced |
| 6 | 259 | spin, mov | Plain escapes fatal at 9 of 15 steps, single path |
| 7 | 297 | spin, mov | Plain escapes fatal at 9 steps, 6-push route, one parking cell |
| 8 | 270 (breather) | spin, portal, mov | A breather that is single-path: 72% forced, 12% deviation survival, recovery NONE |
| 9 | 277 | spin, portal, mov | Single path, 8-push route, plain escapes fatal at 6 steps |
| 10 | 290 | spin, mystery, mov | Plain escapes fatal at 6 steps, hidden arrows on top |

Also redesign candidates: **255** (the "first real Movable puzzle": plain escapes fatal at 8 of 13 steps) and **273**.

## 4. Difficult but GOOD (hard, fair, understandable)

| Level | Why it works |
|---|---|
| **292** (66.5) | Flexibility HIGH, recovery HIGH, only risky moves matter |
| **275** milestone (54.4) | 131 distinct routes for the Movable block, 38 useful positions, dead ends typically 6 moves deep. Movable creating choices |
| **271** (45.3) | Flexibility HIGH, recovery HIGH, 17 useful block positions |
| **265** (36.0) | Flexibility HIGH, recovery HIGH, 13 useful block positions |
| **279** (53.2) | Look-ahead on risky moves is enough |
| **276** (50.3) | Look-ahead on risky moves is enough |
| **282** (41.7) | Movable, but plain escapes stay safe; 9 useful block positions |
| **281** (44.4) | Breather that is open |
| **237** (42.8) | Rule + look-ahead wins 58% |
| **239** (46.5) | Rule + look-ahead wins 51% |
| **242** (51.0) | Hard, but its decisions are all visible risky moves |

In these levels the risky moves are the only real decisions, and a player who looks a few moves ahead at those moves can win.

## 5. Difficult for the WRONG reason

**A. Innocent-escape traps (Movable):** 255, 259, 262, 263, 269, 270, 274, 277, 289, 290, 293, 295, 297. A free escape that turns nothing silently removes a future pusher.

**B. Long push routes to a single parking cell:** 269, 277, 278, 284, 287, 291, 293, 295, 297. Six or more pushes, one final position for the block. This is Sokoban-style "password" routing, which the mechanic rule was meant to avoid.

The contrast is **271**: it also has 8 pushes, yet 17 useful positions for the block and HIGH flexibility. So push count alone isn't the problem; a single route is.

**C. Pure Classic rigidity (no Movable):**
- 248: a CRITICAL score.
- 288: 77% forced, 12% deviation survival.
- 234 and 246: about 65–70% forced.
- 299 and 300: 21–23 hidden-trap steps.

Late Classic 176–200 shows the same signature: by the same rules, 7 of those 25 levels would be redesign candidates. So part of the late-game rigidity predates this arc. Whether 176–200 also produced hint extraction is a useful calibration question for the human playtest.

**D. Breathers that are not breathers:** 270 (single path, recovery NONE) and 287 (HIGH hint risk).

## 6. Design rules proposed for 301+

The point is to change the level structure, not to add hints.

1. **Keep the safety rule, or make breaking it visible.** A plain escape may be fatal only if the block visibly faces the Movable block at that moment. Gate: at most 1 innocent-escape trap step per level, and 0 in breathers and lessons.
2. **Movable creates choices, not a password:**
   - At most 4 pushes in a solution, and at most 2 pushers.
   - At least 2 useful final positions for the block, or the parking cell must be visibly outside every lane from the start.
   - More pushes are acceptable only when many routes for the block win (as in 271 and 275).
3. **Sequence first stage:** it must not be fatal in every state where it can be played (it is now, in 272, 278, 286, 291 and 295). It needs a safe window, or a role the player can read on the board.
4. **One core insight, testable:** rule + 4-move look-ahead should win at least 20% (non-milestone) or at least 5% (milestone). Hidden-trap steps should be at most about 12, and at most 2 of them should be invisible for more than 6 moves.
5. **Recovery floor:** deviation survival at least 0.30, and forced steps at most 50% outside milestones. Breathers: no single path, recovery at least PARTIAL.
6. **Stop counting traps as difficulty.** Difficulty should come from the core insight's depth (the look-ahead needed for risky moves), not from the number of fatal options or push count. Add this audit's metrics to the generator's acceptance and the verifier.
7. **Calibrate with people:** use the 10 top-risk levels and the 12 good-hard levels as a human A/B set before writing any 301+ thresholds into tools.
