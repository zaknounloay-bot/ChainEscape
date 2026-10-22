# Time Attack pilot (`?tapilot=1`), development only

This is a small external pilot for 5-10 invited players. It tests usability and whether players want another challenge. It is not a launch.

The link is the development web build with `?tapilot=1` added. Player and QA builds ignore the parameter: the pilot does not exist there, and neither do its boards.

## What a tester sees

1. **Welcome.** One screen: two minutes per puzzle, play as many of the four as you like, answers stay on the phone until you send them.
2. **One question, asked once:** "How familiar are you with Chain Escape?" The answers are NEVER PLAYED, PLAYED A LITTLE and EXPERIENCED PLAYER.
3. **Choose a puzzle.** PUZZLE 1-4, each with one status line: not played, in progress, solved in m:ss, or time up (with or without an untimed solve). COPY ALL RESULTS sits underneath.
4. **The card before the board.** It shows:
   - one line per mechanic on the board (the existing neutral reminders, never a hint);
   - the tools;
   - the clock.

   Testers who answered NEVER PLAYED also get the basic rule first.
5. **The 120 s Time Attack.** This is the existing page, unchanged: the green / orange / red countdown, reduced motion, rules `ta120-v2`, TIME UP, and CONTINUE WITHOUT TIMER.
6. **Questions.** Every question can be skipped, and BACK TO PUZZLES leaves at any point.
   - After the timed run: first-exposure difficulty, timed enjoyment, countdown excitement, frustration, did the timer help, was 120 s right, would you play another.
   - After the untimed play or a win: did you solve it, puzzle enjoyment, achievement, optional text.
7. **Back to the puzzle choice.** A tester can stop at any time. A puzzle played again is recorded as a later run, not a first exposure.

## Puzzle mapping

The names are neutral on purpose. The order follows the times measured in the phase 12B sessions, fastest first.

| Shown as | Board | Fingerprint |
|---|---|---|
| PUZZLE 1 | TA | `a28e22f0…30cf` |
| PUZZLE 2 | TB | `f8c22182…4d99` |
| PUZZLE 3 | TC | `7f7ae093…88d5` |
| PUZZLE 4 | S1 | `7714b748…fa2b` |

The boards, their fingerprints and the clock are unchanged.

## Rules

The rules are `CountdownTimeAttack.TA120_RULES` (`ta120-v2`), in the timed run and in the untimed continuation:
- 120 s;
- UNDO x3 per attempt;
- unlimited RESTART;
- no SHOW A MOVE;
- no HAMMER.

The clock never stops or refills on RESTART, UNDO, the background, a reload or the browser's back button.

## Data and privacy

- **Storage:** browser storage only, in its own keys: `chain_escape_tapilot_hub` plus `chain_escape_tapilot_<board>_state`, with matching `user://` files. The standalone pages' data (`?stime`, `?tta/b/c`, `?rtime`, `?q1time`, `?ptest11`) is never read or written.
- **What is never collected:** no names, contacts or device identifiers, no analytics, no server, no Supabase.
- **Session id:** 16 random hex characters made on the device. It is linked to nothing else.
- **COPY ALL RESULTS** copies one JSON bundle (`format: ce-tapilot`) to paste back into the chat. It contains:
  - the session id, the familiarity answer and the rules;
  - `runs`: one summary per finished run, with board, fingerprint, run number and first-exposure flag, timed outcome and time, attempts (restarts + reopens + 1), restarts, reopens, UNDO, moves, blocked taps, hint allowance (0), timer stages reached, reduced motion, interruptions, the untimed outcome, time and restarts, and the answers (`""` = skipped);
  - `boards`: per board, the full stored records (`raw`, with the move logs) and anything still in progress.

## Known limitations

- **No hands-on practice.** A new player gets a short written explanation, not a practice board. The game has no reusable basics tutorial outside the campaign, and building one is outside the pilot's scope.
- **Not tested on a real iPhone.** QA ran in Chromium at iPhone SE size, not Safari on a device. Notch and home-bar safe areas use the existing pages' layout and have not been checked on hardware.
- **The browser's back button leaves the pilot.** It is a single page. Coming back resumes everything, and a running clock keeps running.
- **Design data is in the package.** The development build's package also contains the boards' design data files (metrics, verification). Nothing of it is shown on screen or exported, but a technically curious tester could unpack it.
- **Results are local only.** They stay in that browser until the tester taps COPY ALL RESULTS and sends them. Clearing site data loses them.
