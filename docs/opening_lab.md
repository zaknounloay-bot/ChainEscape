# Opening Experience Lab: candidate Levels 1–10

**Status: LAB ONLY.** The candidates are not part of the production campaign.

What stays unchanged:
- Production levels 1–300, byte for byte (`levels/` is untouched).
- Mechanics, Social / Friend, the backend, the save format, the economy, navigation and progression.
- Lock stays at Level 16. Levels 11–300 are not redesigned.

## Why

A first-time adult player found the game "interesting" but stopped at about Level 6–7: "it looked like a game for small children".

The measured current opening (state-graph audit, `tools/human_audit.gd`, and the opening-lab model) explains it:
- No move in production Levels 1–10 can ever lose. A random tapper clears every one of them.
- Levels 1–4 have 3–4 blocks and almost no reading. Level 6 then jumps to 15 blocks.
- The first mechanic appears at Level 9.

## How to play it

Open the game with `?openinglab=reset` (or `?openinglab=1` to continue). For example, `https://<host>/index.html?openinglab=reset` on iPhone Safari.

- **Real game:** the same game, board, sounds, hearts, stars, SHOW A MOVE, Undo, Restart and Hammer.
- **Levels 1–10:** come from `data/dev/opening_lab/`.
- **Levels 11+:** the real production levels.
- **Fresh player:** the lab has **its own save** (`user://opening_lab_progress.cfg` and localStorage `chain_escape_openinglab_*`). A tester always starts as a brand-new player, and their real progress is never read or written. Opening the game without the parameter returns to the real save.
- **`reset`:** wipes the lab save and log, for the next tester on the same device.
- **Play log** (for facilitators, never shown to the player): for each level, starts, restarts, mistakes, undos, hints, time to clear, and **seconds from the completion card to NEXT** (the "voluntary next" signal).
  - Open it from the debug panel: tap the title 5 times.
  - It is also kept in localStorage `chain_escape_openinglab_log`.

**Code:**
- `scripts/dev/opening_lab.gd`: the lab itself.
- Hooks, inert unless the URL parameter is present:
  - `LevelManager.override_dir` / `override_last`.
  - `PlayerProgress.mirror_key` / `beacon_key`, with defaults equal to the old constants.
  - Four one-line event calls and the `_ready` switch in `GameManager`.

## The candidates

Notation: `R/B/G/Y/P` = colour, `^ v < >` = arrow, `@` = spinner (clockwise), `?` = hidden arrow, `(c, r)` = column, row.

### L1 "First Steps": I understand how this works
```
.  .  .
R< B^ G>
.  .  .
```
Three free arrows; the production Level 1 is kept. Tap → it escapes. Hint: "Tap a block to let it escape".

### L2 "In The Way": blocks can get in each other's way
```
.  .  .  .
G> B> R^ .
.  .  Y^ .
.  .  .  .
```
Only red can leave first. It frees blue and yellow, and green waits behind blue. On the first blocked tap the message is "Blocked! Clear its path first".

### L3 "The Knot": order matters
```
.  .  .  .
.  Rv Y< .
.  B< Gv .
.  P> Y> .
```
A 2×3 knot. Only the two outer arrows can move (blue ←, yellow → bottom right). The knot unties from the outside in: yellow → frees purple and green, purple frees red, red frees the top yellow. Hint: "Order matters - look before you tap".

### L4 "Two Threads": I actually need to think
```
.  .  .  .
.  Yv R< G>
.  Rv B^ Y^
.  .  .  B^
```
Two interleaved dependency threads, each with a free starting move:
- green → frees yellow ↑, which frees blue ↑;
- red ↓ frees yellow ↓, which frees red ←, which frees blue ↑.

There are two first moves and 35 valid orders, so the player picks a thread.

### L5 "Long Way Round": aha, nice
```
.  .  .  .  .
.  B^ P> G^ .
.  P^ R< Y< .
.  .  .  .  .
B> .  .  Y^ .
```
A 6-step chain runs from the cluster to the far corners: blue ↑ → purple ↑ → red ← → yellow ← → yellow ↑ → blue →.
- The lonely blue arrow at the bottom left looks free (an empty row), but waits on the yellow at the far right.
- That yellow waits on the cluster.

### L6 "Spinner": wait… what is THAT?
```
.   Yv  .   .
.   P>@ R<  .
.   Bv  .   .
.   .   .   .
```
The proven production spinner intro (production Level 9), moved to Level 6.
- The purple spinner and the red arrow face each other: a stand-off.
- When blue leaves, the spinner turns (→ to ↓), escapes, and the rest follow.
- Hint: "Spinners turn when a neighbor escapes".
- Hearts start here, as in production. This level's first blocked tap says "Careful: from now on, blocked taps cost a heart".

### L7 "Right On Time": I understand it, now use it
```
.   Y<  .   .
G>  P<@ R>  .
.   B<  .   .
R>  Y^  .   .
```
The spinner faces green (another stand-off), and three free arrows sit next to it. Every escape beside it turns it a quarter clockwise.
- **Insight:** tap the spinner as soon as it points at an empty lane.
- **Trap:** clear all three neighbours first, and it ends up facing the bottom yellow, which faces it. The board locks at once, at most 1 move later, so Undo fixes it.

### L8 "Hidden Arrow": there's another mechanic?
```
.   Bv  .   P<
R>  Y>? .   .
.   Gv  .   .
.   .   .   .
```
The proven production hidden-arrow intro (production Level 10), moved to Level 8.
- The "?" is boxed in by three arrows pointing at it. Only green below can leave, which reveals it (yellow →).
- Hint: "Hidden arrows appear when a neighbor escapes".

### L9 "Out Of Sight": this game is going somewhere
```
B^  P^? .   .
P>  P<@ B^  .
.   B<  .   .
R^? Y^  .   .
```
Level 7's spinner stand-off, now with two hidden arrows.
- The "?" above the spinner is one of its neighbours. Once revealed and gone, it turns the spinner too, so the count of turns changes.
- The "?" at the bottom left appears only when the bottom yellow leaves.
- One timing decision. A wrong move shows within 2 moves.

### L10 "Clockwork": completing the opening arc
```
.   .   Bv  .   .
G^  R^@ .   .   G>?
.   G^  Y>@ Rv  R<
.   .   G>  .   G^
```
Two spinners, a hidden arrow on the right edge, 10 blocks, and the longest chain of the opening (8 steps). It completes Chapter 1.
- The bait is the free green ↑ on the left edge. Leaving first turns the red spinner the wrong way.
- The right first moves are the red spinner or red ↓.
- A wrong first move shows within 2 moves.

## Structural metrics

Sources: the real Solver (`tools/opening_lab_check.gd`), the full state-graph audit (`tools/human_audit.gd -- --dir=res://data/dev/opening_lab`), and the opening-lab model (blocking depth, winning orders, random tapper).

Column definitions:
- **Depth:** blocking chain, the parallel rounds needed to clear.
- **Reading steps:** steps where only one of three or more visible blocks can move.
- **Blocked share:** visible blocks that can't move, averaged over play.
- **Consequential decisions:** solution steps where a legal move loses.
- **Deviation survival:** off-solution moves that keep the level winnable.
- **Dead-end depth:** moves until the board visibly locks after a losing move (typical / max).
- **Random tapper:** win rate, and mistaken taps per game.

| Level | Blocks | Board | Solution | Mechanics | Free at start | Depth | Winning orders | Reading steps | Blocked share | Consequential decisions | Deviation survival | Forced moves | Dead-end depth | Within Undo reach | Random tapper |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 3 | 3×3 | 3 | arrows | 3 | 1 | 6 | 0 | 0.00 | 0 | 100% | 0% | – | – | 100% / 0 |
| 2 | 4 | 4×4 | 4 | arrows | 1 | 3 | 3 | 1.0 | 0.33 | 0 | 100% | 0% | – | – | 100% / 4.1 |
| 3 | 6 | 4×4 | 6 | arrows | 2 | 4 | 14 | 1.1 | 0.45 | 0 | 100% | 0% | – | – | 100% / 7.4 |
| 4 | 7 | 4×4 | 7 | arrows | 2 | 4 | 35 | 0.5 | 0.47 | 0 | 100% | 0% | – | – | 100% / 9.1 |
| 5 | 8 | 5×5 | 8 | arrows | 2 | 6 | 25 | 2.3 | 0.58 | 0 | 100% | 0% | – | – | 100% / 16.1 |
| 6 | 4 | 4×4 | 4 | spinner (intro) | 1 | 3 | 2 | 2.0 | 0.35 | 0 | 100% | 0% | – | – | 100% / 4.8 |
| 7 | 7 | 4×4 | 7 | spinner | 3 | 5 | 26 | 0.5 | 0.45 | 1 | 88% | 25% | 1.4 / 2 | 100% | 42% / 6.4 |
| 8 | 5 | 4×4 | 5 | hidden (intro) | 1 | 4 | 3 | 2.0 | 0.42 | 0 | 100% | 0% | – | – | 100% / 7.1 |
| 9 | 8 | 4×4 | 8 | spinner + 2 hidden | 3 | 5 | 57 | 0.0 | 0.35 | 1 | 89% | 19% | 1.3 / 2 | 100% | 54% / 5.6 |
| 10 | 10 | 5×4 | 10 | 2 spinners + hidden | 3 | 8 | 26 | 4.2 | 0.62 | 1 | 80% | 13% | 1.7 / 2 | 100% | 51% / 15.3 |

Two further results:
- A player who looks 2 moves ahead wins every candidate.
- No losing move hides for more than 2 moves, so the 3 Undos always reach back.

For comparison, the current production Levels 1–10 have blocks 3, 3, 3, 4, 6, **15**, 9, 13, 4, 5, with the spinner at **9** and hidden at **10**. They have **0** consequential decisions anywhere, and a random tapper clears 100% of every level.

**Recovery:**
- Levels 1–6 and 8 can't be lost (plain arrows and intros); mistakes cost only stars, and hearts from Level 6.
- In 7, 9 and 10 every losing move becomes visible within 1–2 moves, so Undo (3) always reaches back, and Restart costs at most 10 taps.

## QA

| Check | Result |
|---|---|
| `tools/OpeningLabCheck.tscn` | **168/168**. Isolation (without the lab, Levels 1–11 are production; with it, 1–10 are candidates and 11 is production; default save path and keys unchanged). Every candidate: solvable, small, intended mechanics only. SHOW A MOVE legal and solvable-preserving on **every reachable state**. Hammer safety exact on every state. In the real game scene: loads, hearts from 6, SHOW A MOVE, Undo exact, Restart exact, Hammer refuses unsafe smashes, clears by taps with 3 stars, NEXT after 10 opens production Level 11, play log records NEXT |
| `tools/web_opening_lab_test.mjs` (Chromium, 390×844, touch) | **28/28**. A player with a real save (Level 150) opens `?openinglab=reset` and starts as a new player at Level 1; Levels 1–10 in order (names, hearts); NEXT after 10 opens production 11; the real save is byte-identical afterwards; `?openinglab=1` continues the lab; without the parameter the real save opens at Level 150; no page errors |
| Production | Level files unchanged; Classic 1–200 and 201–225 solver goldens identical; unit tests, Era3 / Portal production checks, Social smoke, recipient, friend flow (see the report) |

## Scorecard (designer estimate from structure, before human tests)

| Dimension | Score | Why, and the weak spot |
|---|---|---|
| 1. Hook | 4 | Level 1 plays in one tap and Level 2 is already a small puzzle. Weakness: Level 1 is still trivial (by design). |
| 2. Clarity | 4 | Each rule is learned by doing, with one short line each (blocked, spinner, hidden) reused from production. Weakness: the spinner turning **clockwise** is only shown, never said. Level 3's hint is generic. |
| 3. Aha / competence | 3 | Reading-based ahas in 3–5 (the knot, two threads, the long way round), and real consequential ones in 7, 9 and 10. Weakness: before hearts (Level 6) a mistake in 3–5 costs only a star, so the "think" moment may not land for players who ignore stars. |
| 4. Novelty | 4 | Spinner at 6 (was 9), hidden at 8 (was 10), and both combined by 9–10. |
| 5. Game feel | 4 | Unchanged production feel. Longer cascades at 5 and 10. Weakness: the intros (6, 8) are small boards with short cascades. |
| 6. Pacing | 4 | 3 → 4 → 6 → 7 → 8, an intentional dip for each new mechanic (4, 5), then 7 → 8 → 10; no 15-block wall. Weakness: two dips in four levels could read as steps back. |
| 7. Anticipation | 3 | Level 10 combines everything and closes Chapter 1 with its card. Weakness: nothing teases what is next (no popups by rule). Production Level 11 ("Order Matters", 5 blocks) is easier than lab Level 10 and repeats Level 7's lesson, so the seam could deflate curiosity. |

## Concerns and tradeoffs

1. **Plain arrows can't lose.** With only arrows, removing a block never hurts, so Levels 3–5 can only be deep in *reading* (blocking chains 4–6 deep, about half the visible blocks stuck). Consequential order decisions start with the spinner at 7. Hearts begin at Level 6 as in production. Making 3–5 matter more would need a system decision: for example hearts from Level 3, which the existing per-level `hearts` field could express without code. Not done.
2. **The seam at Level 11.** Production 11–20 were built after the old opening. Promoting this candidate needs a 11–20 pass, at least for difficulty order and for Level 11 repeating Level 7.
3. **Reused intros.** Levels 6 and 8 are the production Level 9 and 10 boards, which are already proven. Promotion would remove their old slots.
4. **Names can hint.** "Right On Time" points at Level 7's insight, which may be good or a spoiler; testers can tell.
5. **Estimates are not humans.** The scorecard is a structural estimate. The real test is the lab's "seconds to NEXT" and whether testers keep going past Level 6–7.
