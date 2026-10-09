# Polish: milestones, stamp fit and the Third Era finger lessons

These changes are presentation and tutorial only. Level data, progression, rewards and the economy are unchanged.

## A. Every 25th level uses the same milestone presentation

Each milestone shows:
- the big number and "LEVELS ESCAPED!" overlay, fitted to the screen;
- the existing confetti bursts and sound;
- the results-card title "N LEVELS ESCAPED!".

| Level | Tier in `data/chapters.json` | After the overlay |
|---|---|---|
| 25, 125, 225 | `lab_milestone` | — |
| 50, 150, 250 | `lab_milestone_strong` (more bursts, an extra sound) | — |
| 75, 175, 275 | `lab_milestone_plus` | — |
| 100 | `lab_major` | "MASTER!" stamp |
| 200 | `lab_major` | "GRAND MASTER!" stamp |
| 300 | `major` (largest burst) | — |

The "MILESTONE!" stamp and the "250 LEVELS!" stamp are gone. Level Select still labels these levels "MILESTONE · LEVEL N".

Rewards are computed before any presentation, in `GameManager._on_level_complete`, and have not changed:
- **Master bonus:** 300 coins at Level 100 and 600 coins at Level 200, paid once (achievements `master` and `master_200`). The card's coin line still shows "MASTER" / "GRAND MASTER".
- **Milestone bonus:** 120 coins at 125, 150 and 175, paid once (achievement `milestone_N`).

`ExperienceLab.CELEBRATIONS` matches production for Levels 1–200, and `ExperienceLabCheck` verifies this.

## B. The golden stamp always fits

`UIManager.show_perfect_stamp` previously drew its text at a fixed 110 px. "GRAND MASTER!" is 1,041 px wide at that size, and the screen is only 720 px wide, so it was cut off at both edges. Other stamps had the same latent problem.

The stamp's font size now comes from `UIManager.fit_stamp_size`. It shrinks the font, never grows it, until the text's resting extent fits inside the 40 px safe margins. The extent is calculated by `stamp_extent` as:
- text width plus the full outline on both sides;
- then widened for the resting tilt: w·cos t + h·sin t.

The size is computed at runtime with the font as the browser actually renders it, so it is correct on every phone width. Typical results:
- Web build: "GRAND MASTER!" renders at size 74, covering 42–678 of 720 px.
- Headless: it computes to 62.
- "MASTER!" stays at 110.

The slam-in animation is unchanged: the stamp scales down from 2.2× in 0.28 s. Only the resting stamp is fitted.

## C. Finger lessons at 201 (Portal), 226 (Sequence) and 251 (Movable)

These reuse the existing guided-lesson system (`LESSONS`, `_lesson_blocks`, `_lesson_step`, `_finish_lesson`). The "NEW MECHANIC!" card still plays first. While it is open:
- the board takes no input;
- nothing of the lesson shows underneath.

When the card closes, the lesson starts:

| Level | Marked blocks | Finger on | Ends when |
|---|---|---|---|
| 201 Portal | blocks whose lane runs through a portal | a portal escape that keeps the level solvable | a block escapes through a portal |
| 226 Sequence | the Sequence blocks | its first tap ("only TURNS it"), then its second ("it escapes") | the Sequence block escapes |
| 251 Movable | the Movable blocks and every block that would push one | a push that keeps the level solvable | the first push |

The finger only points at a move after the game has checked that the level stays solvable. If no such key move exists yet, the finger shows the solver's next move instead. In either case it never points at a trap.

Each lesson runs once per save (`lesson_portal`, `lesson_sequence`, `lesson_movable`). `GameManager.LESSONS` and `ExperienceLab.LESSONS` are the same table, and a test checks that. The approved boards at 201, 226 and 251 are unchanged.

## Tests

- **`tools/ExperienceLabQaCheck.tscn`**
  - Lessons at 201, 226 and 251: the card opens first; then the lesson appears with the finger on a legal move; following the finger ends the lesson on the key action; and the level is cleared or still solvable.
  - For every milestone:
    - the overlay stays on screen, and the resting stamp sits inside the safe margins;
    - there is no extra MILESTONE stamp, and the card reads "N LEVELS ESCAPED!";
    - the MASTER / GRAND MASTER stamp appears, with its bonus paid once;
    - the 125 / 150 / 175 bonus is still paid once.
- **`tools/web_milestone_fit_test.mjs`** (Chromium, iPhone sizes)
  - Pixel check: when the stamp or overlay is resting, a screenshot must show no stamp-gold pixels in the screen-edge columns of its band.
  - A negative control (`NEGATIVE=1`) against the previous build finds the old "GRAND MASTER!" gold at both edges, which proves the check catches the bug.
- **Updated expectations, now the approved presentation:** `era3_prod_check`, `portal_prod_check`, `experience_lab_check`, `web_era3_test`, `web_portal_arc_test`, `web_experience_lab_test`.
