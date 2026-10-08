# TWINS at Level 176: design validation (no implementation)

No engine, Solver, production, Experience Lab, asset or ZIP change. Everything below was built and run in a disposable scratchpad prototype outside the repository.

**Basis:**
- `docs/lightweight_mechanic_exploration_181_199.md` (commit 0d37040);
- the real-iPhone finding that 176–200 feel like "more of the same".

## 0. Summary

- **Recommendation: GO for a small Lab-only playable prototype** (176 plus two follow-up levels, about 3 boards). **Not yet** a conversion of 176–199.
- **The rule is simple and consistent:**
  - two adjacent blocks with a visible bond;
  - tap either one and both leave together, as **one atomic move**, only if **both** lanes are clear (the partner never blocks);
  - otherwise neither moves.
- **One important honest finding:** in this game **lanes only ever get clearer.** Blocks never move into a lane, except Movable crates, which are Era 3. So "make both lanes clear at the same time" is **not a decision by itself**; on its own it only adds steps.

  Twins become a *real* decision through three things, all validated in the prototype:
  1. **Releasing the pair is a timed event.** It turns the spinners beside it once, and *when* you release it matters (puzzle B).
  2. **Facing twins** (`>` `<` side by side) can only leave together, through each other's cell: a satisfying "only possible as a pair" moment (puzzles A and B).
  3. **A twin can be a switch target:** the switch changes which lane matters, and its timing can create a face-off with the pair (puzzle C).
- **Engine fidelity of the prototype:** it reproduces the real engine exactly on production Levels 111, 113, 116 and 121 (identical state counts, winnable states and winning-order counts). So its results for the shared rules (spinners, locks, switch, gate) are trustworthy.

## 1. Final proposed rules

| # | Question | Rule (recommended) |
|---|---|---|
| 1 | Adjacency | **Horizontal or vertical** neighbours only (no diagonals). Exactly two blocks per bond. |
| 2 | Directions | **Any** two directions: same, different, facing or back to back. |
| 3 | Opposite-facing pairs | **Allowed and encouraged.** Facing twins (`>` `<`) leave through each other's cell, which is only possible as a pair. |
| 4 | Simultaneous? | **Yes: one atomic move.** Both leave at the same instant. One Undo step, one SHOW A MOVE step. |
| 5 | Lane evaluation | Both lanes are checked on the board **as it is before the move, ignoring the partner**. Each lane needs only empty cells to the edge. |
| 6 | One lane blocked | **Neither moves.** Tapping a twin whose *own* lane is blocked is an ordinary blocked tap (a mistake, as for any arrow). Tapping a twin whose own lane is clear but whose *partner's* lane is blocked is a **free explanation tap**, like tapping a locked or shelled block. |
| 7 | Other roles on a twin | Twins are **plain arrows**: never a spinner, hidden, locked, switch or armored (the game's existing "one special role per arrow" rule). A twin **may** be a switch target (`&A`), a gate link (`+C`), a lock-key colour or a reward. |
| 8 | Locks | Twins count as two blocks of their colour. Two key-coloured twins open a lock in one move. |
| 9 | Chain Gates | Each twin counts as a link. Two linked twins can open a 2-link gate in one move. |
| 10 | Spinners | The pair's escape is one neighbour event: **every spinner beside the pair turns once.** On a square grid **no cell touches both twins** (proved and tested), so the "turns twice" case **cannot occur**. The atomic rule needs no exception. |
| 11 | Switches | A switch reverses its marked twin like any arrow. The bond stays. |
| 12 | Armor | A twin is never armored. A twin's lane can run into a shell: then that lane is simply blocked, and **twins never ram** (a twin tap always means "the pair escapes"). |
| 13 | Undo / Restart | Unchanged. Both are snapshot-based; a pair move is one step. |
| 14 | SHOW A MOVE | Points at either twin (the pair move). It never points into a trap (the Solver checks solvability, as today). |
| 15 | Hammer | **B: breaking the bond** (recommended). Smashing one twin removes only that block; its partner becomes a normal arrow. |

**Why B for the Hammer:**
- **A (remove both)** makes the Hammer twice as strong on twins, and it is a hidden special case.
- **C (disallow)** removes the emergency tool exactly where a new mechanic may confuse players.
- **B** keeps the Hammer's meaning ("remove the block I pick"), and the existing safety check still works.

## 2. Three sample boards (verified in the prototype)

**Notation (the game's tokens):**
- colour letter + arrow (`^ v < >`);
- `@` = clockwise spinner;
- `%A` = switch A, `&A` = reversed by switch A;
- `!T` / `!U` = **twin bond group (new, prototype-only marker)**.

Coordinates are (column, row) from the top left.

### A. Level 176, first encounter: "Twin Lights" (6×6, 9 blocks, two pairs)

```
row 0:  .     .     R>!U  R<!U  .     Gv
row 1:  .     .     .     .     .     .
row 2:  .     P>    .     .     Y^    .
row 3:  G^    .     .     .     .     .
row 4:  .     B^!T  B>!T  .     Gv    .
row 5:  .     .     .     .     .     .
```

- **Pair T:** blue `^` at (1,4) and blue `>` at (2,4), different directions.
  - The up lane is blocked by purple `>` (1,2).
  - The right lane is blocked by green `v` (4,4).
- **Pair U:** red `>` (2,0) and red `<` (3,0), **facing each other**. The right lane is blocked by green `v` (5,0); the left lane is clear.

**Intended solution:**
1. Green (4,4) leaves.
2. **Tap a blue twin: nothing moves.** The up lane is still blocked. This is the free explanation tap, the "aha".
3. Purple (1,2) leaves.
4. **The blue twins fly out together.**
5. Green (5,0) leaves.
6. **The red twins pass through each other.** This is the WOW.
7. Yellow and green finish.

**Prototype results:**
- 42 states, all winnable; 315 winning orders; no losing first move; **no fatal move at all**.
- 26 reachable states show the "one lane blocked" situation, so the rule is discovered naturally.

**Why it works:** both teaching beats happen on every playthrough:
- "both lanes" (pair T needs two different blockers removed);
- "they leave as one" (pair U is only possible together).

**Fatal moves:** none, by design. This matches the gentle adapted Armor intro at 151, which was approved. Difficulty is intentionally low after Milestone 175, with the guided lesson carrying it.

**Readability:** two clear pairs in different orientations, and very few other blocks.

**Emotion:** curiosity ("why didn't it move?"), a quick aha, then delight when the red pair crosses.

### B. Intermediate: Twins + Spinner, "Hold Fire" (6×6, 12 blocks)

```
row 0:  Rv    .     .     B>    .     .
row 1:  .     Rv    .     .     .     .
row 2:  .     .     Yv@   R^    .     .
row 3:  .     .     P^    Rv@   .     G<
row 4:  .     .     P>!T  P<!T  B>    .
row 5:  .     .     Y>    .     .     .
```

- **Facing twins:** purple `>` (2,4) and purple `<` (3,4). Only blue `>` (4,4) blocks the right lane.
- **A red spinner (3,3) sits on top of the pair, pointing down into it.** Releasing the pair frees the spinner's downward exit **and** turns it once.
- **The green arrow (5,3) aims left through the spinner's cell.** It can only leave after the spinner.

**The decision:** **when to release the twins.** The pair turns the spinner once:
- **Safe** while the spinner points down or left: it turns left or up, and can exit.
- **Fatal** only when the spinner points **up**: the release turns it **right, nose to nose with the green arrow**, a visible face-off.

The spinner's direction is set by the order in which its other neighbours leave (red `^` above, purple `^` left).

**Prototype results:**
- 184 states, 176 winnable; 28,710 winning orders; **no losing first move**.
- 16 fatal moves: 8 pair releases at the wrong time, and 8 purple escapes that turn the spinner wrongly. **Zero plain-escape traps.**
- Mistakes are recoverable within 4 Undos (14 of 16 within 3).
- Random tapping wins 69%.
- The pair release turns the spinner on 55% of winning paths. On the others, the spinner left first; both plans work.

**One intended solution** (SHOW A MOVE's line):
1. Blue (3,0) leaves, then red (3,2), which turns the spinner and the yellow spinner.
2. Yellow (2,2) leaves.
3. Purple (2,3) leaves (the red spinner turns up).
4. Red spinner (3,3) leaves upward.
5. Blue (4,4) leaves.
6. Red (0,0), red (1,1) and green (5,3) leave.
7. **The twins leave together.**
8. Yellow (5,5) finishes.

**Why it is interesting:** the twins are not just a "clear two lanes" chore. Their release is **a lever on the spinner**. The player chooses between two plans: release the twins to turn the spinner, or let the spinner leave first.

**Readability:** the spinner sitting on the pair and the face-off target are both visible.

**Emotion:** "I need to release them at the right moment", a small, readable timing puzzle.

### C. Advanced: Twins + Switch, "Turnabout" (6×6, 12 blocks)

```
row 0:  .     B<    .     .     .     .
row 1:  .     .     R^    .     G>    .
row 2:  .     .     .     .     R^%A  .
row 3:  .     .     Bv    B<&A  B^&A!T B<!T
row 4:  .     .     .     Y^    Y<    .
row 5:  .     .     .     Y^    .     Y^
```

- **Twins:** blue `^` (4,3), which is **reversed by switch A**, and blue `<` (5,3).
- **Switch A (red, 4,2) sits right in the up-twin's lane**, so it must leave, and when it does, it **reverses the up-twin to point down**.
- **It also reverses blue `<` (3,3) to point right, straight at the pair.** If that arrow is still there, it and the pair block each other for ever.

**The decision:**
- the switch must go, because it blocks a twin;
- but **fire it only after blue (3,3) has left**;
- then clear the new (down) lane, yellow (4,4).

**Prototype results:**
- 100 states, 92 winnable; 6,600 winning orders; **no losing first move**.
- 8 fatal moves, **all** "switch fired while blue (3,3) is still there": a visible face-off. **Zero plain-escape traps.**
- Worst mistake: 4 Undos. Random tapping wins 51%.
- On **every** winning path the twins leave with the reversed (down) lane.

**One intended solution:**
1. Blue (2,3) leaves, then blue `<` (3,3), then yellow (3,4).
2. Green (4,1) leaves.
3. **Switch (4,2) fires:** the up-twin turns down.
4. Yellow (4,4) leaves.
5. **The twins leave**, down and left.
6. The rest finish.

**Why it is interesting:** one block (the switch) is at once the **obstacle**, the **direction changer** and the **potential trap** for the pair. That is coordination, not a long forced sequence: the line has free choices at most steps.

**Readability:** switch marks (`A` badges) are already understood from 101+.

**Emotion:** "I almost fired it too early": a fair, visible mistake.

## 3. Scratchpad validation

**Prototype:** a Python rules model in the scratchpad (not in the repository).
- It mirrors `BoardModel`: lane escape, neighbour spinners, locks, switch flips, gate opening.
- It adds Twins.
- It builds **full state graphs** (every reachable state, winnable states, fatal moves, Undo depth) and runs a random tapper.

**Fidelity check against the real engine** (same counts as the Godot audits):

| Level | States | Winnable | Winning orders |
|---|---|---|---|
| 121 | 102 | 67 | 825 |
| 111 | 55 | 35 | 116 |
| 113 | 60 | 38 | 180 |
| 116 | 400 | 205 | 141,878 |

All four match the real engine exactly.

**Rule tests: 12 / 12 pass.** They confirm:
- both lanes are required, and neither twin moves if one is blocked;
- the "one lane blocked" state is detected;
- one pair move removes both twins;
- facing twins leave through each other;
- a twin blocks other arrows like any block;
- each spinner beside the pair turns once;
- no cell can touch both twins;
- switch A reverses a marked twin;
- two linked twins open a 2-link gate in one move;
- two key-coloured twins open a lock in one move.

**Puzzle checks:** A, B and C as reported above. All are solvable. None has a losing first move. **None has a fatal move that turns nothing** (the Level 295 lesson). Their intended solutions are valid.

| Puzzle | Random tapper wins | Readout |
|---|---|---|
| A | 100% | A gentle intro |
| B | 69% | Not trivial, not opaque |
| C | 51% | Not trivial, not opaque |

**Search evidence on what Twins add:**
- **Twins + Spinner.** About **5%** of solvable random boards with a twin pair next to a spinner contained a real "release the pair at the right time" decision. Good boards exist but must be **designed**, not generated blindly.
- **Twins + Lock.** In 14,000 random boards, **0** produced a pair-timing decision. As lock keys, twins mostly add steps. Lock is therefore **not** recommended as the main partner mechanic.
- **The "both lanes clear" idea alone** never creates a fatal decision (lanes only clear over time), which confirms the honest finding in section 0.

**Limits:**
- The prototype has no hidden blocks, Alternating / Pattern spinners or Armor.
- It is not the game. Feel, animation and readability need the real build.

## 4. Mobile visual concept (static mockup)

The concepts were drawn onto a real iPhone-size screenshot (390×844) of the dense 7×7 Lab Level 189. That board has Chain Gate C, switch `A` marks, locks, hidden blocks and Armor. Two pairs are shown: one horizontal, one vertical. The mockup images are scratchpad files sent with this review; they are not committed and not assets.

| Approach | Look | Strengths | Weaknesses |
|---|---|---|---|
| **1. Bond bar** | A short, cream-white rounded bar with two gold rivets, bridging the shared edge, with a soft warm glow | Reads instantly as "joined"; never covers an arrow; neutral colour works on all five block colours; works horizontal and vertical; **nothing like** the Chain Gate's chain-link icon or the "C n" counter | Small (about 34×12 px on 7×7); needs the glow to stay visible on yellow / green |
| **2. Shared capsule outline** | One rounded white-gold outline around both blocks | Strong grouping, very visible | **Looks like the gold reward frame and the lesson highlight brackets**; it adds visual noise to dense boards and clashes with other mark rims |

**Recommendation: approach 1 (the bond bar).** Optionally add a 1-frame capsule flash only during the lesson or when tapped, to say "these two".

## 5. Game feel

**A successful pair tap (about 0.45 s total, as fast as a normal escape plus about 0.1 s):**
1. **0.00 s:** the tapped twin and its partner both squash slightly (90%), and the bond bar brightens.
2. **0.06 s:** the bar **snaps**: a tiny burst of 6–8 sparks in the bond's colour at the shared edge.
3. **0.08 s:** both blocks launch at the same time along their own lanes (the existing escape motion), with a short **two-note chime** (the escape sound at two pitches, a fifth apart).
4. Neighbour spinners turn as usual (once each).
5. The chain counter counts **+2**; this is score presentation only, and any economy decision stays with you.

**Blocked feedback:**
- **The partner's lane is blocked (free tap):** both twins wobble once and the bar pulses. A thin red line flashes along the blocked lane up to its first blocker. One short line on the first occurrence: "Twins leave together - both lanes must be clear". No heart lost.
- **The twin's own lane is blocked:** the ordinary blocked-tap feedback (a heart, as for any blocked arrow), plus the same red lane flash.

## 6. Progression concept, 176–199 (high level)

**Goals:** about 10 of the 24 levels use Twins; never in a fixed slot; the three-level rotation is broken; 200 and 201 are unchanged.

| Range | Role | Content (proposal) |
|---|---|---|
| **176** | Introduction, guided lesson | **New board A** (gentle, two pairs, facing twins) |
| **177–180** | Early mastery | 1 new small board (twins with a gate link, so two links leave at once) + 1 adapted production board (two adjacent plain arrows become a pair, solver-verified like Lab 151); 2 production levels unchanged |
| **181–185** | First combinations | Board **B** (Twins + Spinner "Hold Fire") + 1–2 adapted boards; the rest unchanged |
| **186–190** | Advanced combinations | Board **C** (Twins + Switch "Turnabout") + 1 Twins + Gate board; Mystery levels stay as they are |
| **191–199** | Varied | 2–3 adapted boards (two pairs, a pair + Armor on a lane); at least two Twin-free levels before 200 so the Grand Master stays "classic" |
| **200** | Grand Master | **Unchanged** |
| **201** | Portal, Third Era | **Unchanged** |

**Notes:**
- **Slots for new boards:** where a new board replaces a production board's slot, the displaced production puzzle is either moved or dropped. That choice is open (for example, retiring one of the repeated long-decoy Armor + Gate levels, 194 / 197).
- **Level 200's hint** ("Every rule of both eras") would no longer list every rule if Twins never appear in 200. The board stays untouched either way. You can accept this (Twins as the Elite Chapters' own rule) or approve a lab-only hint wording later.

## 7. Technical impact (inspection only)

| Area | Required change | Risk |
|---|---|---|
| `BlockData` | A `bond` group / partner field | Low |
| `LevelManager` | A new token modifier (prototype `!T`; the real character to be chosen to avoid `@ ? # $ % & + = :`); validation (exactly two, adjacent, plain-arrow roles); `to_json_text` round trip | Low |
| `BoardModel` | `move_state` (both lanes, partner ignored); `remove` of the pair as one event (neighbour turns once each; locks / links / flips as for two escapes); `last_*` lists; a free "partner blocked" tap state | **Medium:** must match the Solver exactly |
| `Solver` (packed arrays) | A `_bond` array; `legal_moves` emits one move per pair; `_do` / `_undo_move` for two removals (spinner steps, colour counts, links, gate); `_is_free` ignores the partner; `_key` is unchanged (block presence) | **Medium–high:** two rule engines must agree turn by turn |
| SHOW A MOVE | Unchanged logic; the move encodes the pair | Low |
| Hammer | `hammer_safe` with "the bond breaks" | Low–medium |
| Undo / Restart | None (snapshots) | None |
| Level verifier | Rules for twins (era gating, "twins before combinations") | Low |
| Social / Friend Challenge | Generators never place twins; `PuzzleDefinition.verify` must **reject** the token (as for portals) | Low; must be tested |
| Board / BlockView | Draw the bond bar across two cells (in `Board`); a pair escape animation; the lane flash | Low–medium |
| Audio | Reuse escape sounds at two pitches (no new asset needed at first) | Low |
| Save | **None**: progress saves don't store boards; a new tip key is additive | None |
| Performance | One extra node per pair; two simultaneous escape animations; branching drops slightly in the Solver | Negligible (iPhone Safari) |

**Tests needed:**
- parser / serialiser and validation errors;
- model rule unit tests (the 12 prototype tests, ported);
- **model ↔ Solver agreement on random walks**;
- `hammer_safe` with bonds;
- Undo / Restart exactness;
- the lesson flow;
- the Social / Friend rejection test;
- Lab checks (only the intended boards changed);
- production goldens unchanged;
- browser tests at iPhone size.

## 8. GO / NO-GO

| Question | Answer |
|---|---|
| 1. Genuinely different? | **Yes, with a caveat.** It is the only mechanic where one tap moves **two** blocks, and facing twins are a new spatial idea. "Both lanes clear" alone is weak, because lanes only get clearer; the real decisions come from the pair as a **timed trigger** and from **switch-reversed twins**. |
| 2. Understood in 5–10 s? | **Yes**: the bond bar + one blocked tap + one double launch (board A). |
| 3. Sample puzzles interesting? | **A:** a good gentle intro. **B and C:** real, readable decisions with no plain-escape traps, verified in the prototype. Not yet human-tested. |
| 4. Improves post-175 experience? | **Likely**: it adds novelty and breaks the rotation. **Unproven** until a human plays it. |
| 5. Safe to implement? | **Yes, with care**: the main risk is keeping `BoardModel` and the packed `Solver` identical (covered by agreement tests). No save changes. |
| 6. Preserves Grand Master 200? | **Yes**: the board is untouched. Only the hint wording question remains. |
| 7. Preserves Portal 201? | **Yes**: Twins never change a lane or move a block within the board. |
| 8. Worth the cost? | **Probably, but only if the feel lands.** That should be measured cheaply first. |

**Recommendation: further validation through the smallest playable step.**
1. **A Lab-only prototype:**
   - the Twins rule in both engines;
   - the bond-bar visual and pair animation;
   - the lesson;
   - boards A (176), B and C in place of three Lab slots;
   - everything behind lab gating.
2. **One real-iPhone session:** is the rule clear, is the pair release satisfying, and do B and C feel new?

Only then decide on the full 176–199 progression.

## 9. Open questions

1. Accept the Hammer rule "breaks the bond"?
2. A partner-blocked tap free, and an own-lane-blocked tap a mistake, as proposed?
3. Should twins appear in 201–300 later (for example, the 276–300 integration chapter), or stay an Elite-Chapter rule?
4. Level 200's hint wording: accept, or a lab-only tweak?
5. Which production puzzles (if any) make room for new boards A / B / C, or should twins be added only by in-place adaptations?
6. The chain counter for a pair: +2 (two escapes) or +1 (one move)? A presentation decision; no economy change proposed.
