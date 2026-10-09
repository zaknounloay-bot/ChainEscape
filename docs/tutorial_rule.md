# Permanent rule: every new mechanic gets a finger-guided tutorial

This is a standing design requirement for Chain Escape. It applies to every gameplay mechanic added from now on, starting with Magnet at Level 76.

## The rule

At a mechanic's **first appearance** in the campaign, the game runs a one-time interactive lesson:

1. The existing **NEW MECHANIC** introduction card appears (`MechanicIntro`). The board takes no input while it is open, and nothing of the lesson shows underneath it.
2. When the card closes, a **guided finger** points at a valid key action: a move that performs the mechanic's essential action and keeps the level solvable.
3. The **player performs that action themselves**.
4. The lesson ends once the essential action has been demonstrated successfully. A short success line confirms it.
5. The lesson is **never repeated** once it has been completed. It is stored once per save as `lesson_<mechanic>` in `PlayerProgress.tips_seen`.

### The tutorial must never
- **perform the action automatically:** the player always taps;
- **create an unsolvable situation:** the finger only points at moves the Solver confirms keep the level solvable, otherwise at the Solver's next move;
- **block gameplay:** every legal move stays allowed; Undo, Restart, Show a Move and the Hammer work as usual; a blocked tap keeps its own explanation and the lesson returns afterwards.

## How to implement it (reuse; no new framework)

| Step | Where |
|---|---|
| The lesson level | `GameManager.LESSONS[level] = "<mechanic>"`, and the same entry in `ExperienceLab.LESSONS` (a test keeps the two tables identical) |
| Which blocks are bracketed | `GameManager._lesson_blocks` |
| Finger target and line | `GameManager._lesson_step`, with `_lesson_key_move(is_key)` choosing a solvable key move |
| When it ends | the mechanic's action in `_escape` / `_push` / ..., then `_finish_lesson` (success line) |
| The card first | `_maybe_mechanic_intro`: the lesson waits for the card and starts when it closes |
| Tests | `tools/ExperienceLabQaCheck.tscn -- --experiencelab=<level> --qareset`: the card opens first; then the lesson, with the finger on a legal move; following the finger ends it on the key action; the level is cleared or still solvable |

## Current lessons

| Level | Mechanic | Ends when |
|---|---|---|
| 13 | Lock | the lock opens |
| 101 | Switch | a switch fires |
| 121 | Chain Gate | a gate opens |
| 151 | Armor | a shell is cracked |
| 176 | Twins | a pair escapes together |
| 201 | Portal | a block escapes through a portal |
| 226 | Sequence | a Sequence block escapes |
| 251 | Movable | a block is pushed |
| 76 *(planned)* | Magnet | a magnet escapes and pulls a block |

Existing lessons are not changed by this rule.
