# Lightweight mechanic exploration for Levels 181–199 (design research)

No code, level, asset, lab, economy or production change. Level 200 and Level 201 are untouched. This is a proposal for review, not an approved plan.

## 0. The problem, restated with evidence

**Human finding:** the real iPhone playthrough of 176–200 found that **181–199 feel like "more of the same"**, with no WOW moment.

The audit (`docs/player_experience_audit_176_200.md`) explains why:
- **A strict, predictable rotation.** 181–199 repeat a three-level cycle six times:
  1. a two-switch level;
  2. an Armor + Gate level;
  3. a Mystery level with every mechanic.
- **One recurring puzzle shape.** In most levels, a single decoy (a switch, or an escape that turns a spinner) must be left alone for 10–21 moves.
- **No new kind of decision since 151 (Armor).** Every 181–199 decision is one of the same three:
  - *when do I fire this switch*;
  - *which block must leave last*;
  - *which escape turns a spinner the wrong way*.

So the gap is a **new kind of decision**, not more difficulty. Reordering the existing levels cannot create one.

## 1. What already exists (verified in code)

| Mechanic | Rule (BoardModel) | Decision it creates |
|---|---|---|
| Arrow block | Escapes when its straight lane to the edge is empty | Order of clearing |
| Spinner (CW / CCW / Alternating / Pattern) | Turns when an orthogonal neighbour escapes (`remove` → `apply_turn`) | Which neighbour leaves when; face-offs |
| Hidden (Mystery) | Arrow unknown until a neighbour escapes | Reveal order (never a hidden trap here) |
| Lock (`#K`) | Can't leave while any block of colour K remains | Colour order |
| Switch / flip (`%A` / `&A`) | When the switch escapes, every `&A` arrow reverses | Timing of a remote effect |
| Chain Gate (`XC` / `+C`) | Slab blocks lanes; removed when the last `+C` block leaves | Which links first; lane opening |
| Armor (`=`) | Can't escape while shelled; a block launched into it cracks the shell and stays (a ram is never fatal) | Aiming a rammer |
| Rewards (`$S` / `$G`) | Pay coins once | None (cosmetic incentive) |
| *Era 3* Portal (`OA`) | A lane enters one portal cell and continues out of its twin | Lane topology |
| *Era 3* Sequence (`R>:^`) | First tap: the block launches, comes back, triggers the neighbour event, takes its NEXT arrow; second stage escapes | A two-step block |
| *Era 3* Movable (`M`) | A crate pushed one cell by a block launched into it | Repositioning an obstacle |

**What no mechanic does yet:**
1. **Two blocks that must act together.** Every move moves at most one block.
2. **A block whose colour or identity changes.** Colours are fixed, so lock keys are static.
3. **A rule that depends on how many moves have passed.** Everything is spatial.
4. **A block that affects lanes as a whole line** (row or column) rather than its four neighbours.

## 2. Candidates

### C1. TWINS (bonded pair)

- **Rule:** "Twins leave together. Tap one: both go, but only if **both** lanes are clear."
- **What the player sees:**
  - two **adjacent** blocks joined by a short glowing bond bar across their shared edge (with a small matching "∞" badge on each);
  - arrows can differ.
- **On tap:** if both lanes are clear, both fly out at the same time. The partner never blocks its twin: they leave together. Otherwise it is an ordinary blocked tap.
- **New decision:** *synchronising two lanes.* Clearing one lane is not enough, so the player prepares both, and must not spend the blocks that guard the other lane too early.
- **Example:** a twin pair `B^` + `R>`.
  - The up-lane is blocked by a spinner that needs one turn; the right-lane by a locked block.
  - The player must arrange both conditions at the same moment.
  - Firing the spinner's neighbour too early points it into the other twin's lane.
- **Combinations:**
  - a pair escape is a **double neighbour event**: a spinner next to both twins turns **twice** at once;
  - a twin can be a gate link (counts as two);
  - twins of a key colour release a lock in one move;
  - a shelled twin needs cracking first (no twin is ever armored itself, see the readability rules).
- **Similar to:** nothing directly. It is closest to Gate (two things linked), but Gate is "A opens B", while Twins is "A and B act as one".
- **Complexity:** low–medium. One new field (`bond` partner id); move = pair; `remove` of two.
- **Mobile readability:** high. The bond bar is a single, bold, unmistakable shape across one edge.
- **Animation and sound:** simultaneous launch with a stretched bond "snap" spark and a two-note chime. Very satisfying.
- **Frustration risk:** low–medium. The rule is visible; it does not create plain-escape traps.
- **Repetition risk:** medium. It needs variety in pair geometry (straight, L-shaped, facing, back-to-back) and in what blocks each lane.

### C2. PHASE BLOCKS (ghost / solid every move)

- **Rule:** "Phase blocks switch between solid and ghost after every escape. Ghosts don't block."
- **What the player sees:** a block with a dashed, translucent outline when ghost, and solid when solid. It flickers with a soft pulse on every escape.
- **On tap:** it is a normal arrow. It escapes when its lane is clear, in either phase.
- **New decision:** *tempo / parity.* "Not now; after one more escape this ghost lets my arrow through."
- **Combinations:**
  - a ram does not count as an escape, so rams become "tempo-neutral" moves;
  - a gate opening is not an escape;
  - spinners still turn.
- **Similar to:** nothing. A temporal rule is new to the game.
- **Complexity:** low. A global parity bit, and `find_blocker` skips ghosts.
- **Readability:** medium. The state is visible, but planning needs odd/even counting.
- **Animation:** strong (a shimmer on every move).
- **Frustration risk: high.** Every plain escape flips the parity, so **harmless-looking escapes become fatal**: exactly the Level 295 pattern the audits warn against.
- **Repetition risk:** low.

### C3. CHAMELEON (colour taker)

- **Rule:** "A chameleon takes the colour of the last block that escapes next to it."
- **What the player sees:** a block with a prismatic rim. When it changes colour, it fills in the new colour.
- **On tap:** it is a normal arrow.
- **New decision:** *which colour should it be when the locks check?* Locks are present in every 181–199 level; a chameleon makes lock keys dynamic.
- **Combinations:**
  - Lock (it becomes, or stops being, a key);
  - Gate (unchanged);
  - Switch (its flip is independent).
- **Similar to:** Lock (it modifies lock logic) and spinners (a neighbour-event trigger). Medium similarity.
- **Complexity:** medium. Colour counts become mutable in both engines; locks re-evaluate.
- **Readability:** medium–low. Colour changes on a 7×7 board are subtle, and colour-blind players depend on lock icons.
- **Animation:** nice (a colour wash).
- **Frustration risk:** medium. The consequences are delayed: a lock stays shut far away.
- **Repetition risk:** medium.

### C4. MIRROR TILE (deflector)

- **Rule:** "A mirror bends any lane 90°."
- **What the player sees:** a fixed diagonal mirror cell (`/` or `\`).
- **On tap:** it can't be tapped. Lanes passing it turn.
- **New decision:** lane geometry.
- **Similar to:** **Portal** (lane redirection). Introducing it at 181 would pre-empt Era 3's signature idea.
- **Complexity:** medium (lane walker). **Not recommended** for this reason.

### C5. RELAY NUMBERS (ordered batons)

- **Rule:** "Numbered blocks must leave in order: 1, then 2, then 3."
- **What the player sees:** a small number badge.
- **New decision:** a dependency order.
- **Similar to:** Lock and Gate (waiting conditions). It is another "who must go first" constraint, which is exactly what 181–199 already overuse.
- **Complexity:** low. **Low novelty.**

### C6. SHOCKWAVE (line trigger)

- **Rule:** "When a shockwave block escapes, every spinner in its row **and** column turns once."
- **What the player sees:** a block with a radiating-lines badge.
- **New decision:** long-range spinner control, i.e. *where on the board am I firing this?*
- **Combinations:** spinners everywhere, so it is strong with Pattern / Alternating spinners.
- **Similar to:** Switch (a remote effect), but positional rather than marked. Medium similarity.
- **Complexity:** low.
- **Readability:** medium. The player must trace the row and column; a preview highlight would help.
- **Frustration risk:** medium. Many spinners turn at once, and that is hard to predict on 7×7.

### C7. SLEEPER (wake counter)

- **Rule:** "A sleeper can't move until N other blocks have escaped."
- **What the player sees:** a number counting down.
- **New decision:** tempo, but it always counts down, and the player can't fall behind.
- **Similar to:** a Gate whose links are "any N blocks". **Low novelty**; it rarely creates a decision.

## 3. Evaluation (1–5)

| Candidate | Novelty | Fun | Depth | Easy to learn | Mobile readability | Implementation simplicity | Fits existing mechanics | Long-term variety | Total |
|---|---|---|---|---|---|---|---|---|---|
| **C1 Twins** | 4 | 5 | 4 | 5 | 5 | 4 | 5 | 4 | **36** |
| C2 Phase | 5 | 4 | 5 | 3 | 3 | 4 | 4 | 4 | 32 |
| C3 Chameleon | 4 | 3 | 4 | 3 | 2 | 3 | 3 | 3 | 25 |
| C4 Mirror | 3 | 4 | 4 | 4 | 4 | 3 | 3 | 4 | 29 |
| C5 Relay numbers | 2 | 2 | 2 | 5 | 5 | 5 | 4 | 2 | 27 |
| C6 Shockwave | 3 | 4 | 3 | 4 | 3 | 4 | 4 | 3 | 28 |
| C7 Sleeper | 1 | 2 | 1 | 5 | 5 | 5 | 4 | 1 | 24 |

**Why these scores:**
- **Twins:**
  - They score high on readability (one bond bar) and fit (they reuse every existing rule unchanged: double neighbour events, link counting, colour counts).
  - Novelty is 4, not 5, because "two at once" is a familiar puzzle idea in general, though new to this game.
- **Phase** has the most original *decision*, but scores lower on learnability and readability. It also carries the **fairness risk that rules it out**: it turns plain escapes into potential traps.
- **Mirror** is fun but borrows Portal's thunder (lane redirection). It scores low on fit for that reason.
- **Relay numbers and Sleeper** are easy but add only more "wait for X": the very thing that feels repetitive.
- **Chameleon** is clever but colour changes are hard to read at 7×7 and for colour-blind players, and its consequences are delayed.
- **Shockwave** is a decent, cheap idea, but its effect is hard to predict on dense boards and close to Switch's "remote effect".

**The scores are not the decision.** The deciding factors are the 295 fairness lesson, which rules out Phase, and protecting Era 3's identity, which rules out Mirror.

## 4. Top three

### 1. Twins (C1)

**A. First encounter (181):**
- A small board with **one twin pair** and a few plain arrows. One twin's lane is free at once; the other is blocked by a single arrow.
- The guided lesson pattern (as at 101 / 121 / 151):
  - brackets on both twins;
  - the finger first on the blocker;
  - then on a twin, so both fly together;
  - one line: "TWINS leave together - both lanes must be clear".

**B. Intro puzzle (182–183):**
- Two pairs: one with arrows pointing the same way, one with arrows pointing in different directions.
- The obvious first twin can't go yet; the player learns to look at *both* lanes.

**C. Intermediate (≈ 185–188):**
- **Twins + spinner:** a spinner touching both twins turns **twice** when they leave. The player uses that double turn to aim it.
- **Twins + lock:** the twins are the last two blocks of a key colour, so one move opens the lock.

**D. Surprising (≈ 190–195):**
- **Twins + Switch:** one twin is a flip target (`&A`), so firing switch A changes *which* lane must be clear.
- **Twins + Gate:** both twins are links of a 2-link gate, so one tap opens it, with the chain and twin effects in the same animation.
- **Twins + Armor:** one twin's lane runs into a shell. The partner must wait while another block cracks it, or a twin rams while its partner waits.

**E. Staying fresh to 199:**
- **Vary the geometry:**
  - straight pairs and L-shaped pairs;
  - **facing twins**: arrows pointing at each other, whose lanes pass through each other's cell, which works only together;
  - back-to-back twins.
- **Vary the guard:** spinner, lock, switch, gate or shell.
- **Two pairs that compete** for the same blocker.
- Twins appear in about half of 181–199, never as a fixed rotation slot.

**Why it feels different:** every existing decision is about **one block and when**. Twins make it **two blocks and both at once**: a spatial coordination puzzle with a visible, satisfying payoff (two blocks leaving together, double spinner turns).

### 2. Shockwave (C6)

- **A.** 181: one Shockwave block beside a row of three spinners. Its escape turns all of them. Lesson line: "SHOCKWAVE turns every spinner in its row and column".
- **B.** Choosing *where* it can leave from, by clearing it earlier or later.
- **C.** Combinations with Pattern / Alternating spinners: one wave advances several patterns.
- **D.** A Shockwave that is also a gate link: the last link opens the gate *and* fires the wave.
- **E.** Variety is limited by spinner density. It risks becoming "count the spinners in the cross".

**Why it differs:** a *positional* remote effect, versus Switch's *marked* one.

### 3. Phase blocks (C2), only with a safety rule

- **A–E** as in Twins, with a ghost block guarding a lane.
- To be fair, it would need a rule such as "phase flips only on **taps of the Phase block itself**". That removes the plain-escape traps, but it also removes most of the novelty: it becomes a toggle block, close to Switch.
- It is kept in the top three only to document why it was rejected in its pure form.

## 5. Technical feasibility (Twins)

**Where it would live:**

| Area | Change |
|---|---|
| `BlockData` | New field `bond: int` (partner id, -1 = none) and `bond_group: String` for parsing |
| `LevelManager` | Token suffix, e.g. `~X`/`^T`-style marker. A free character such as `!A`, `!B` = bond group, added to `_token_re` (`level_manager.gd:157`). Validation: exactly two adjacent blocks per group; never on a gate; not a spinner or hidden block (one special role per arrow, as for switches and shells). `to_json_text` round-trip |
| `BoardModel` | `move_state` / `can_escape` (both lanes clear, the partner ignored as a blocker); `remove` removes both. Order: both leave, then neighbour events for each (a shared spinner turns twice); `last_*` lists cover both |
| `Solver` (packed arrays, `solver.gd`) | A parallel `_bond` array. `legal_moves` emits one move per pair; `_do` / `_undo_move` handle two removals (spinner steps, colour counts, links, locks); `_is_free` ignores the partner. **The model and solver must agree turn by turn** (existing test pattern) |
| `GameManager` | `_escape` handles a pair (score / chain for two blocks, reward if either is a reward); a blocked-twin tap gets a free explanation line; one-time tip; `LESSONS` entry (lab first) |
| `Board` / `BlockView` | Draw the bond bar across the shared edge (in `Board`, since it spans two cells) plus a small badge; `play_escape` for both at once; a "bond snap" burst |
| `AudioManager` | Reuse the escape sounds (two pitches) or one new short sample (later, if approved) |

**Other implications:**
- **SHOW A MOVE / hint:** `recommend_move` returns either twin's id. Tapping it does the pair move. No change in logic, only in the move encoding.
- **Undo / Restart:** history is snapshot-based (`_capture_state`), so a pair move is one Undo step. No change.
- **Hammer:**
  - Rule needed: smashing one twin **breaks the bond** (the partner becomes a normal block).
  - `Solver.hammer_safe` must model that (it builds a model and calls `remove`).
- **Save compatibility:** progress saves store level numbers, scores and tips, not boards, so **no save format change**. Lab saves are unaffected. A new tip key ("twins") is additive.
- **Social / Friend Challenge:** generated boards never contain twins. `PuzzleDefinition.verify` should reject the token, as it does for portals. Nothing else changes.
- **Performance:**
  - One extra bar per pair and one simultaneous double animation: negligible on iPhone Safari.
  - The solver's branching drops slightly (pairs are one move).

**Tests needed:**
- parse / serialize round trip and validation errors;
- model rules (both lanes, partner ignored, double spinner turn, locks / links counted twice);
- model ↔ solver agreement on random walks;
- `hammer_safe` with a bond;
- Undo / Restart exactness;
- the lesson flow;
- lab checks;
- browser tests;
- no change to production goldens (`classic_golden`) for levels without twins;
- Social / Friend rejection.

**Estimated size:** the same order as Armor's v0.6 addition. Smaller than Portal / Sequence / Movable, which needed lane walking, multi-stage state or pushes.

## 6. Recommendation

**Recommend TWINS, introduced at Lab 181, in the Experience Lab only first.**

**Why it is worth it:**
- It gives 181–199 a genuinely new decision: *coordinating two lanes at once*.
- It produces a visible WOW payoff: two blocks leaving together, and a shared spinner spinning twice.
- It is learnable in about 5 seconds from the bond bar alone.

**Why not just rearrange:** the playtest problem is that every level asks the same three questions. Reordering changes when they are asked, not what is asked.

**Why it isn't another Lock or Switch:** Lock, Gate and Armor are all "X must happen before Y" (waiting). Switch is "a remote change". Twins are neither: the player must make **two things true at the same time**, and the reward is a single, simultaneous action.

**How many levels:** about 9–10 of 181–199:
- 181–183 intro and development;
- then roughly every other level, mixed with existing ones;
- the rest stay as they are.

The rotation becomes irregular because twins appear in different "slots".

**Content approach** (lab first, minimal):
1. One new gentle intro board at 181, in the style of the adapted 151.
2. **Token-level adaptations** of existing 181–199 boards: turning two adjacent arrows into a twin pair, verified with the solver like the Lab 151 adaptation.

This keeps most approved structure and each level's identity.

**Level 200 is preserved unchanged.** One wrinkle: its hint says "Every rule of both eras" but would not include twins.

| Option | What it means |
|---|---|
| (a) | Accept it: twins become the Elite Chapters' own rule |
| (b) | A lab-only hint tweak later |

Both are decisions for review. The board stays untouched either way.

**Era 3 stays distinctive:** Portal (lane topology), Sequence (two-stage blocks) and Movable (pushing) are all about **one block's path or position**. Twins never change a lane or move a block within the board. 201 remains the next big conceptual shift.

**Not recommended:**
- **Phase:** it reintroduces harmless-looking traps (the 295 lesson).
- **Mirror:** it pre-empts Portal.
- **Relay / Sleeper:** more waiting rules.
- **Chameleon:** readability.
- **Shockwave:** a reasonable second choice if Twins is rejected.

## 7. Main technical risks

1. **Two rule engines must stay identical:** `BoardModel` (play) and `Solver` (hints, verification, Hammer safety). A pair move touches spinner steps, colour counts, gate links and locks in both. Mitigation: the existing model ↔ solver agreement tests, extended to twins.
2. **Hammer semantics** (breaking a bond) must be defined and covered by `hammer_safe`.
3. **The token grammar:** a new modifier character must not collide with existing ones (`@ ? # $ % & + = :`), and Social / Friend parsing must reject it.
4. **The two-cell visual:** the bond bar must survive board scaling (5×5 to 7×7) and must not be confused with the Chain Gate's chain icon (use a bar, not chain links).
5. **Lesson routing** (lab-only `LESSONS[181]`) and the one-time tip, exactly as done for 151.

## 8. Suggested next design step

Before any engine work:
1. **Paper-prototype three Twin boards** (intro 181, one Twins + spinner, one Twins + switch) as JSON-like sketches, and check them with a throwaway scratchpad solver extension (no repo change).
2. **Review the visual** with a static mockup of a 7×7 board with one bond bar (an image only, not an asset), on iPhone size.
3. **Decide the open questions:**
   - adjacent-only pairs?
   - Hammer breaks the bond?
   - Level 200's hint wording?
   - how many of 181–199 to adapt?

Then authorise a lab-only implementation in the same controlled style as Armor at 151.
