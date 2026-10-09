# Balance audit: Experience Lab 177, 179, 184 (read only)

**Scope:** read-only. No code, level data, build or export was changed.

**Baseline:** commit `44db502`, the Twins Lab sequence that was played on a real iPhone.

**Measurements:**
- `tools/human_audit.gd`, which runs a complete state graph per board, with a pair counted as one move;
- the scratchpad board search, used only to test *possible* adjustments: every existing block frozen, new blocks added only.

## 0. The human findings this audit answers

- The whole 176–200 run is very interesting. Twins feels new every time it appears, and difficulty progresses appropriately. Some repetition remains, but it is tolerable.
- **177 and 179 have far fewer blocks than 178.** The concern is the contrast in density and visual complexity, **not** 178's difficulty. 178 is not to be made easier.
- **184 felt easy.**

## 1. Comparative findings: Lab 175–185

**Columns:**
- **Density** = blocks / cells.
- **Marked** = blocks carrying any mark (spinner, switch / flip, gate / link, lock, hidden, shell, bond).
- **Moves** = solution length.
- **Forced** = share of steps with only one safe move.
- **Trap** = share of solution steps that offer a losing move.
- **Dead end** = moves still playable after a mistake (typical / longest).
- **Habit** = win rate of the audit's habit player: it holds switches and pairs and avoids spinner turns, plus a 4-move look-ahead when forced.
- **Look-ahead** = win rate of a 4-move look-ahead player.

| L | Puzzle | Board / blocks | Density | Marked | Twins | Mechanics | Moves | Forced | Trap | Dead end | Habit | Look-ahead | Role |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 175 | Shatter Point | 7×7 / 22 | 0.45 | 12 | – | Armor, switch, gate, 5 spinners, 2 locks | 22 | 0.57 | 0.68 | 11 / 18 | 0.15 | 0.00 | Milestone |
| 176 | Twin Lights | 6×6 / 9 | 0.25 | 4 | YES (2 pairs) | Twins only | 7 | 0 | 0 | – | 1.00 | 1.00 | Lesson (deliberate reset) |
| 177 | Double Link | 6×6 / 9 | 0.25 | 4 | YES | Twins + gate links, 1 spinner | 7 | 0.06 | 0.10 | 2.5 / 3 | 1.00 | 1.00 | Second learning step |
| 178 | Crystal Heart | 7×7 / 22 | 0.45 | 12 | – | Armor key, switch, gate, 5 spinners, 2 locks | 22 | 0.63 | 0.71 | 7 / 14 | 0.52 | 0.00 | Elite classic |
| 179 | Hold Fire | 6×6 / 12 | 0.33 | 4 | YES | Twins + 2 spinners | 11 | 0.06 | 0.07 | 1.3 / 4 | 1.00 | 1.00 | First Twins decision (approved) |
| 180 | Deep Field | 7×7 / 19 | 0.39 | 15 | – | Armor, switch, gate, 5 spinners, 2 locks | 20 | 0.84 | 0.90 | 5.6 / 18 | 0.07 | 0.00 | Chapter-end reasoning |
| 181 | Elite Entry | 6×7 / 22 | 0.52 | 11 | – | 2 switches, 6 spinners, 2 locks | 22 | 0.23 | 0.53 | 9.5 / 16 | 0.10 | 0.00 | Elite reasoning |
| 182 | Gold Standard | 6×7 / 23 | 0.55 | 15 | YES | Twins + Pattern spinner on an Armor + Gate board | 23 | 0.21 | 0.77 | 9.8 / 20 | 0.05 | 0.00 | Twins in a full Elite board |
| 183 | High Council ✦ | 7×7 / 21 | 0.43 | 14 | – | Mystery, Armor, switch, gate | 21 | 0.90 | 0.86 | 9.5 / 18 | 0.02 | 0.00 | Elite (habit-friendly) |
| 184 | Turnabout | 6×6 / 12 | 0.33 | 4 | YES | Twins + switch (2 flips) | 11 | 0.09 | 0.17 | 2.3 / 4 | 1.00 | 1.00 | Switch reverses a twin (approved) |
| 185 | Masterwork ✦ | 7×7 / 21 | 0.43 | 16 | – | Mystery, Armor, switch, gate | 21 | 0.78 | 0.79 | 11 / 19 | 0.01 | 0.00 | Elite reasoning |

### What the five dimensions say

| Dimension | 177 | 179 | 184 |
|---|---|---|---|
| **A. Visual density** | 9 blocks, 0.25. Lowest with 176; one third of 178's 22 | 12, 0.33; about 60% of 178 / 180 | 12, 0.33, between 183 (21) and 185 (21) |
| **B. Number of moves** | 7 (178: 22) | 11 (178: 22, 180: 20) | 11 (183 / 185: 21) |
| **C. Strategic difficulty** | Very low: 2 fatal moves, max 3 Undos | Low–medium: 16 fatal moves, but the habit player always wins | Low: 8 fatal moves, all "the switch fired too early", which the habit player always avoids |
| **D. Learning value** | High: "each twin is a gate link", seen once, clearly | High: the timing lesson ("the pair turns the spinner") was approved on iPhone | Medium: "a switch reverses a twin" is new; the trap itself is the switch-timing habit trained since 101 |
| **E. Player experience** (human test) | Its sparseness stood out against 178 | Its sparseness stood out against 178 | Felt easy |

**Main finding.** The contrast the tester noticed is real in **A and B**: the learning boards have about half the blocks and half the moves of their neighbours. But **C is the dimension that decides how a level feels to play**, and it is not the same for the three:

- **177** is easy *by design*. Its job is one fact, after a lesson level.
- **179** is easy to a *habit* player, but it still holds 16 visible losing moves. It is the approved lesson, and its decision is real for a first-time player.
- **184 is the only one where the easiness has a specific, fixable cause.** Its single trap is firing the switch too early. Players have practised "hold the switch until it is needed" for 80 levels (101–183), so that one habit solves it (habit player 100%, look-ahead 100%). The new idea (a switch reverses a twin) is seen, but it never challenges the player.

## 2. What modest additions actually do (scratch experiments)

To test "would modest additional complexity help?" without guessing, each board was searched with **every existing block frozen**: only new blocks could be added, moved or turned, and the approved core of each puzzle stays intact. Each target was searched for 20–40 minutes per seed, over 2–4 seeds.

| Target | Search goal | Result |
|---|---|---|
| **177** (+3 to +5 blocks) | 12–14 blocks; stays gentle (no losing first move, ≤ 3 Undos, ≤ 4 fatal moves, random tapper ≥ 50%) | **Trivially easy:** 1,400+ variants. They add 3–5 moves (7 → 10–12) and visual density (0.25 → 0.33). **No variant adds a decision:** look-ahead and habit stay 100%, and some even remove the two existing losing moves. |
| **179** (+3 to +5 blocks) | 15–17 blocks; the habit player no longer always wins; ≤ 6 Undos | **Not found.** Additions either change nothing strategically (habit 100%), or tip the board into Elite. The best near-miss (16 blocks): random tapper 72% → **3.8%**, habit 100% → 48%, forced 0.06 → 0.50, dead ends to 8 moves. |
| **184** (+1 to +3 blocks) | ≤ 15 blocks; the switch habit alone stops winning | **Partly found.** Best (15 blocks, +3: a counter-clockwise spinner beside the top blue arrow, a clockwise spinner and a plain arrow on the bottom row): habit 100% → **49%**, look-ahead 100% → 67%, random tapper 51% → 7%, switch-timing losing moves 8 → 16, dead ends ≤ 7, no losing first move, 0 plain-escape traps. |

**Reading of the experiments:**

- **177:** density can be raised safely, but it only buys *more moves*, not better play. That is exactly the "more blocks is not better gameplay" case.
- **179:** there is no gentle middle. The approved board's lesson ("the pair turns the spinner") either stays as easy as it is, or becomes a hard Elite timing puzzle. A 3.8% random-tapper board at 179 would sit right after 178 and before 180 and remove the only breathing room in Chapter 18's second half.
- **184:** this is the one place where a *small* addition creates *a new decision*. The added spinner beside the top blue arrow turns when its neighbours leave, which changes **when** the switch can safely fire. Holding the switch to the end is then no longer automatically right. The core (the reversed twin, the face-off with blue (3,3), the switch in the twin's lane) is untouched.

## 3. Recommendations

### 177 Double Link: **KEEP AS IS**

- **Why:** it is the second learning level. Right after the lesson (176) it teaches one extra fact (each twin is a gate link) on a clean board, and that clarity is its value. The experiments show that more blocks would only add moves.
- **The density contrast with 178** is the normal shape of a mechanic introduction in this game: 151 → 152 was the same, and Armor was approved. Under a sequence that "progresses appropriately", the jump to 178 reads as "back to Elite".
- **If the contrast keeps bothering testers,** there is a safe cosmetic option: 3 plain arrows (9 → 12 blocks).
  - Effect: +3 moves, the same difficulty, no new mark.
  - Risk: low, but the benefit is only visual, so it is not recommended now.

### 179 Hold Fire: **KEEP AS IS**

- **Why:** it is the approved, iPhone-tested Twins + Spinner lesson, with 16 visible losing moves and a real "when do I release" decision for a first-time player.
- **What adding to it would do:** the experiments show that additions either leave the habit unbeaten, or turn the board into a hard Elite puzzle (random tapper 3.8%, dead ends to 8). That would remove the breather between 178 and 180 and replace a validated experience with an untested one.
- **The density contrast** (12 vs 22 blocks) is the price of keeping the lesson legible.
- **No small change was found** that improves strategy without that cost.

### 184 Turnabout: **MINOR ADJUSTMENT (optional; the only change with demonstrated value)**

- **Problem it solves:** 184 is solved entirely by a habit learned 80 levels earlier, so its new idea never challenges the player. That matches the tester's "felt easy", and it sits in the 181–185 "return toward advanced difficulty" band.
- **Smallest change found:** add 3 blocks; move or modify nothing that exists.

```
. B<    .  .     .        .
. P>@-  R^ .     G>       .        <- new: purple counter-clockwise spinner (1,1)
. .     .  .     R^%A     .
. .     Bv B<&A  B^&A!T   B<!T
. .     .  Y^    Y<       .
. B^@   P< Y^    .        Y^       <- new: blue clockwise spinner (1,5), purple arrow (2,5)
```

- **Estimated effect:**

| Measure | Before | After |
|---|---|---|
| Blocks | 12 | 15 |
| Density | 0.33 | 0.42 (near the 0.43 of 183 / 185) |
| Moves | 11 | 14 |
| Habit player | 1.00 | 0.49 |
| Look-ahead player | 1.00 | 0.67 |
| Random tapper | 51% | 7% |
| Forced | 0.09 | 0.41 |
| Dead ends | ≤ 4 | ≤ 7 |
| Losing first moves | 0 | 0 |
| Plain-escape traps | 0 | 0 |
| Fatal moves | 8 (all switch) | 16 (all switch) |

  With these numbers it would sit between the learning boards (habit 1.0) and the Elite Twins boards from 187 (habit 0.20–0.45): a step up, not a spike.
- **Risks:**
  1. 184 stops being a breather between Elite 183 and Elite 185. In this slot, though, the tester asked for more, not less.
  2. "I almost fired it too early", the approved emotional beat, could become "I can't tell when to fire it". The added spinner turns visibly, but this needs a human test.
  3. Two more spinners on a board whose lesson is the switch.
- **Recommendation for timing:** implement only if you agree 184's ease is a problem, not a welcome breather. Then verify it with the same checks as the other Twins boards and include it in the next iPhone test.

## 4. Is any change genuinely worthwhile?

**Only one, possibly: 184.**
- 177 and 179 are doing their jobs as learning steps.
- Their low density is visible, but the evidence says adding blocks would add moves (177) or remove the breather (179), not improve play.
- The tester's own verdict on the whole run (interesting, novel, appropriate difficulty) argues against touching boards that are not demonstrably broken.

## 5. Risks of over-optimization

- **Optimizing to metrics, not to players.**
  - The habit / look-ahead players are proxies. 179's "habit 100%" does not mean a first-time player finds it trivial: it has 16 losing moves.
  - Tuning every board to an Elite number would erase the learning curve the tester called appropriate.
- **Density for its own sake.** Matching 177 / 179 to 178's 22 blocks would make the Twins introduction look like every other Elite level. That removes exactly the "something different is happening" feeling the tester valued.
- **Losing validated experiences.** 179 and 184 are approved prototype puzzles with tested emotional beats. Each change replaces evidence with a prediction.
- **Removing breathing room.** 177, 179 and 184 are the only light levels between 176 and 186. Hardening all three would make 178–186 one unbroken Elite block.
- **Chasing a "tolerable" repetition** by redesigning more levels risks the overall balance the tester approved.

## 6. Summary

| Level | Recommendation | Change | Effect |
|---|---|---|---|
| 177 Double Link | **KEEP AS IS** | – (a cosmetic +3 arrows exists if wanted later) | – |
| 179 Hold Fire | **KEEP AS IS** | – (no small change found that helps without removing the breather) | – |
| 184 Turnabout | **MINOR ADJUSTMENT (optional)** | +3 blocks, existing board untouched | Habit 1.00 → 0.49, random tapper 51% → 7%, density 0.33 → 0.42; needs a human test |

Level 178, Level 200, the Twins rules, production and 201–300 are untouched by every option above.
