# Magnet: isolated prototype (Mech Lab)

**Status:** prototype only. Magnet appears nowhere in Levels 1–300, normal progression or Friend Challenge. Using it in the campaign (Levels 76–99) needs separate approval.

## The rule

A **MAGNET** is an ordinary arrow block with a pink horseshoe on its back edge, the side opposite its arrow. It escapes exactly like any arrow, and then:

1. The magnet's escape has its usual effects first: adjacent spinners turn, and a switch or gate link fires if it has one.
2. Then the **first block straight behind it** (the opposite direction to its arrow) slides into the cell the magnet left. That block keeps its own arrow, and any distance counts.
3. If there is nothing behind it, nothing moves.
4. If the first block behind it is a Chain Gate, a Movable crate or a twin, it stops the pull and nothing moves.

**The preview is exact.** The board draws a dotted line, with a chevron, from the block that will be pulled to the magnet, and rings that block. This comes from `BoardModel.pull_target`, the same function the escape uses. A magnet can't open a gate behind itself (it can't carry a gate link), so what is shown is always what happens. `MagnetCheck` confirmed this on all 332 magnet escapes in its random boards.

### What it is not
- **Not Movable:** a crate is passive and pushed by being hit. A magnet moves a *live* arrow block, as a side effect of its own escape.
- **Not Twins:** twins leave together. Here the pulled block stays on the board, in a new cell.
- **Not Spinner or Switch:** the pulled block's direction never changes. Only its position does.

### Prototype restrictions (lab only)
- A magnet must be a plain arrow: no spinner, hidden, lock, switch, gate link, armor, Sequence or Twins role.
- Its board must have no portals, Movable crates or hidden arrows.
- Anything else is reported and the magnet is dropped (`LevelManager._validate_magnets`).

## Where it lives

| Area | Change |
|---|---|
| Token | `R^*` (a `*` after the arrow), parsed only while `LevelManager.dev_magnet` is set: the Magnet lab and its tools. Campaign files, Social and Friend Challenge parsing reject it as a bad token. `R>@*` is still a PATTERN spinner. |
| `BlockData.magnet` | copied by `duplicate_data`, so it survives snapshots and Undo |
| `BoardModel` | `remove()` pulls last and records `last_pull`; `pull_target()` is the preview |
| `Solver` | `_pull` / undo (LIFO); every block's cell is in the state key; magnet boards use a plain memoized DFS, because the greedy "safe move" shortcut is unsound once an escape can change what a magnet pulls |
| `Board` | the `MagnetLinks` overlay (badge, dotted line, ring), `play_pull` (the existing slide plus a small spark), and Undo moving pulled blocks back. Nothing is drawn, and nothing runs per frame, on boards without magnets. |
| `SocialPlay` | plays the pull animation and counts pulls / empty pulls |
| `MechLab` | the `magnet` config: three boards, a demo, questions, and `pulls` / `empty_pulls` / `first_pull_ms` in the results |

## The three boards (`data/dev/mechlab_magnet.json`)

These are built and verified by `tools/mechlab_magnet_build.gd`. Each one:
- is solvable;
- is **not** solvable if its magnets are made plain arrows;
- has a solver solution that replays move for move through `BoardModel`.

**A1 "First Pull" — introduction (5×5, 5 blocks, 1 magnet)**
- Blue and yellow face each other at the bottom, so neither can ever leave.
- The red magnet flies up and pulls blue into its cell, where blue's lane is free.
- Nothing can go wrong: 0 dead states, and a random tapper always wins.

**B1 "Turn and Pull" — combination with Spinner (5×5, 7 blocks)**
- The magnet's line first points at purple, the wrong block.
- Escaping the magnet now pulls purple, and the blue / yellow pair at the bottom stays stuck forever.
- Let purple go first and the line moves to blue.
- The magnet's escape also turns the yellow spinner beside it, away from the block it pulls in.
- One losing first move (the magnet). Random tapper: 48%.

**C1 "Two Magnets" — challenge (6×6, 9 blocks, 2 magnets, 1 spinner)**

Two traps, both visible from the board:
- **Red magnet first:** its line shows green, a decoy, instead of the stuck yellow at the bottom.
- **Blue magnet first:** its escape turns the purple spinner to face green and pulls it into green's row, which creates a deadlock.

The solution is to let yellow, beside the spinner, escape first. The spinner then lands pointing up and can leave. Two losing first moves; random tapper: 4.7%.

## Builds and tests

- **Web Magnet Lab** export preset (`magnet_lab` feature):
  - always opens the Magnet lab, whatever the URL;
  - no debug panel, and no other developer page;
  - the game under the lab uses its own save, diagnostics and page-log keys, so it never touches the normal save, even on the Friend Test build's origin.
- The developer **Web** build also has it, at `?mechlab=magnet`. The Friend Test build ignores it.
- **`tools/MagnetCheck.tscn`** (headless): token gating and validation, every rule case, the preview matching the actual pull, and a Solver-vs-`BoardModel` fuzz over 250 random boards (verdicts, legal moves, replays, do/undo), plus the lab's boards and config.
- **`tools/web_mechlab_magnet_test.mjs`** (Chromium, iPhone sizes, both builds on one origin):
  - the build forcing the Magnet lab; the demo's pull and empty pull;
  - the boards solved by touch; a pull undone;
  - reload resume and the results JSON;
  - byte-identical isolation from the owner's save.
