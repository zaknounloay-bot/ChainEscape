# Player Experience Lab: Levels 1–100 (developer build, not production)

A candidate Levels 1–100 campaign, playable in the real game for continuous human playtesting.

**What is unchanged:**
- Production Levels 1–300, byte for byte (`levels/` is untouched).
- Mechanics, Social / Friend, the backend, save format, economy, tools and production progression.

**Sources:**
- The human-approved Opening Lab (1–10).
- `docs/progression_reflow_11_25.md` (11–25).
- The **minimum-intervention** map of `docs/progression_audit_1_100.md` (26–100).

## How to open it

| Where | URL |
|---|---|
| Local / any host | `index.html?experiencelab=reset` (start fresh), `index.html?experiencelab=1` (continue) |
| **itch.io** (the page already has `?v=...`) | append **`&experiencelab=reset`**, e.g. `index.html?v=123456&experiencelab=reset`; `&experiencelab=1` to continue |
| **QA jump** (developers, any host) | **`&experiencelab=N`** with N = 2–100 opens Lab Level N directly, e.g. `index.html?v=123456&experiencelab=13` (on a plain host: `index.html?experiencelab=13`) |

### QA jump `experiencelab=N` (developer shortcut, not player progression)

Every itch.io upload is a new browser-storage origin, so the lab would start again from Lab 1. `experiencelab=N` (N = 2–100) opens Lab Level N straight away:
- **No title screen.** The board is live at once.
- **Temporary QA save** (`user://experience_lab_qa.cfg`, localStorage `chain_escape_experiencelab_qa_save` / `_qa_beacon`). It is wiped on every QA launch and seeded with what a player arriving at Lab N would have:
  - Levels 1..N-1 cleared with score 0 and no stars, so no stars or coins are invented. The coins are a new save's 60.
  - The Chapters before N's complete.
  - The one-time tips of the earlier levels seen: the Silver/Gold lines, and the Lab 13 lock lesson only when N > 13.
- **Level N itself is a first visit.** The Lab 13 lock lesson starts from the beginning, and the intro hints of 31 / 41 / 51 show as usual. Completing 25 / 50 / 75 / 100 gives its milestone (never just by opening it). A 10th level gives its Chapter Complete. 100 gives "100 / LEVELS ESCAPED!" → MASTER → Chapter 10 → the lab-complete screen.
- NEXT goes on to N+1 inside the same QA session.
- **Never touched:** the real save, the Opening Lab save, the normal lab save and the lab log (in a QA session the log stays in memory only). `experiencelab=reset` and `experiencelab=1` behave as before.
- `experiencelab=0`, `101`, `-5` and `13abc` are not jumps: as before, they do not switch the lab on.

| Lab | Why test it | itch.io parameter |
|---|---|---|
| 13 | Lock lesson | `&experiencelab=13` |
| 25 | milestone 25 | `&experiencelab=25` |
| 31 | first CCW | `&experiencelab=31` |
| 41 | first Alternating | `&experiencelab=41` |
| 50 | milestone 50 + Chapter 5 | `&experiencelab=50` |
| 51 | first Pattern | `&experiencelab=51` |
| 75 | milestone 75 | `&experiencelab=75` |
| 100 | milestone 100 → MASTER → lab complete | `&experiencelab=100` |

**Parsing** is exact key/value matching on the query string and the hash, in any order and URL-decoded:
- `xexperiencelab=1`, `experiencelabs=1` and `experiencelab=0` do **not** switch the lab on.
- If both lab parameters are present, `experiencelab` wins over `openinglab`.

**What the lab changes, and only on that URL:**
- Levels 1–100 load from `data/dev/experience_lab/`.
- The level count is 100. Level Select shows 1–100, and nothing after 100 is ever loaded.
- NEXT after Lab 100 (after its Chapter 10 card) shows a lab-only screen: **PLAYER EXPERIENCE LAB COMPLETE · LEVELS 1–100 TESTED**. Its LEVEL SELECT button reopens the lab's Level Select.
- Progress lives in its own save: `user://experience_lab_progress.cfg` and localStorage `chain_escape_experiencelab_save` / `_beacon`.
- A facilitator log (starts, restarts, mistakes, undos, hints, time to clear, seconds from the card to NEXT) is kept in `chain_escape_experiencelab_log`. It is shown in the debug panel (tap the title 5 times).

**Code:**
- `scripts/dev/experience_lab.gd`.
- Hooks in `GameManager`, inert without the parameter: the `_ready` switch, the 100-level cap, the lab events, the end screen in `_go_next`, and three diagnostic state fields.
- **Data:** built by `tools/experience_lab_build.py`, with the source of every level in `data/dev/experience_lab/manifest.json`.

## Map summary

| Change | Levels | Count |
|---|---|---|
| Opening Lab (human-approved) | 1–10 | 10 |
| New boards | 16 Key Turn, 20 Secret Key | 2 |
| Reordered only | 11, 12, 13, 14, 17, 18, 19, 21, 22, 23, 27, 29, 35, 36, 38, 41, 51, 52 | 18 |
| Reordered and renamed | 24 (P23 "Clockwork" → **Cogwheels**) | 1 |
| Renamed only | 49 (P49 "Long Way Round" → **Detour**) | 1 |
| Token adaptations | 28, 32, 33, 42, 43, 50, 53, 56, 57 | 9 |
| Production board, same slot, unchanged | 15, 25, 26, 30, 31, 34, 37, 39, 40, 44–48, 54, 55, 58–100 | 59 |

**Mechanic introductions:**

| Mechanic | Lab level | Board | Onboarding |
|---|---|---|---|
| Spinner | 6 | Opening Lab | its hint |
| Hidden | 8 | Opening Lab | its hint |
| **Lock** | **13** | P16 "Locked" | its hint "A lock opens when all blocks of its color are gone" moves with it |
| **CCW** | **31** | P31 | hint "Ring arrows show which way a spinner turns next" |
| **Alternating** | **41** | P35 "Gearbox" | hint "Dots show a spinner's rule: this one alternates" |
| **Pattern** | **51** | P52 "Clockmaker" | hint "Pattern spinner: right, right, left - then repeat" |

These intros are the levels' own hint texts, so they move with the boards and no intro configuration changes (production's `MECHANIC_INTRO_FROM` cards are only for Portal / Sequence / Movable at 201+).

**Chapter averages** (difficulty): 5.6 · 11.8 · 18.8 · 26.0 · 33.3 · 42.5 · 46.1 · 49.9 · 53.3 · 58.8. Each Chapter is at least +2 above the previous one, which is the campaign rule.

## New boards

### Lab 16 "Key Turn": first Lock + Spinner (11 blocks, 5×5)
```
.  .  Y> .  .
G> Pv R<@ . Pv
Yv Gv B< .  .
G> .  .  .  Bv#R
Yv .  .  .  .
```
**How it works:**
- The red spinner is the **only red block**, so it is the key: the blue block (lower right) stays locked until it escapes.
- The purple block above it waits on the blue one.
- So the spinner's turns, caused by its neighbours escaping, decide when the key path opens.

**Measures:**
- Difficulty 12.8 / 10.4.
- Lock impact 7.6; the spinner is essential.
- 3 solution steps with a losing alternative.
- Every losing move shows within 3 moves (typical 1.8), so Undo always reaches back.
- 75% of off-solution moves survive; 11% of steps are forced.
- No move that turns nothing ever loses.
- A 4-move look-ahead player wins 100%; a random tapper ~50%.
- Fair without SHOW A MOVE (0 free hints at Level 16).

### Lab 20 "Secret Key": Chapter 2 mystery finale, Hidden + Lock (14 blocks, 5×5)
```
.   .    G^? P<  .
Pv  B<   B<? Y<  .
Yv  R>#G .   Y^  .
Y>  .    .   .   B>
Pv? R^#G .   .   P^
```
**How it works:**
- Two red blocks are locked by green, and the only green block is **hidden** (top).
- The key appears only when a neighbour escapes, and its reveal unlocks both locks.

**Measures:**
- Difficulty 14.2 / 9.4, a 12-step cascade.
- Hidden impact 3.4, lock impact 1.6; the mystery is fair.
- No losing moves (hidden and lock alone can't create one), so blocked taps (hearts) are the only stake.

**Why no spinner:** the spinner version scored lock impact 0.8 and hidden impact 1.2, so a spinner would have been decoration. As asked, the simpler board was chosen because hidden + lock matter more in it.

## Adaptations (one token each, solver-verified)

Spinner tokens: `@` clockwise, `@-` counter-clockwise, `@~` alternating, `@*` pattern. "Shows" = the turn on which the new rule first differs from clockwise.

| Lab | Board | Token change (column, row) | Why / effect |
|---|---|---|---|
| 28 | Safe House (P28) | `P^` → `P^@` (4,2) | Pure-lock breather gets one clockwise spinner: 12.8 → 14.0, 1 trap step, still a breather |
| 32 | Vault (P32) | `Gv` → `Gv@-` (4,2) | First CCW application, as a breather: 13.9 → 16.1, 1 trap step |
| 33 | Hairpin (P33) | `R^@` → `R^@-` (2,3) | A clockwise spinner becomes CCW; its turns are on the solution path. 28.8 → 19.1: gentler, a readable application right after the CCW intro |
| 42 | Whirlpool (P42) | `Bv@` → `Bv@~` (3,0) | Alternating; its 2nd (opposite) turn is reachable in play but **not on the solution path**: a light application |
| 43 | Turnstile (P43) | `P<$S` → `P<@~$S` (2,1) | No existing spinner here can ever make a 2nd turn (a conversion would be cosmetic), so one arrow became an alternating spinner. Its 2nd turn is reachable; difficulty unchanged (28.1) |
| 50 | Eclipse (P50) | `Yv` → `Yv@~` (5,4) | No existing spinner can make a 2nd turn, so one arrow became an alternating spinner whose **opposite 2nd turn is on the solution path**: the Chapter 5 showcase. 26.9 → 30.5 |
| 53 | Escape Room (P53) | `G>@` → `G>@*` (3,1) | Pattern; its 3rd (left) turn **is on the solution path**. Difficulty ~unchanged |
| **56** | Pressure (P56) | `Bv@` → `Bv@*` (2,5) | Pattern, 3rd turn on the solution path. **Replaces the planned 55:** no spinner or arrow in P55 can ever make a 3rd turn, so a pattern there would have been cosmetic |
| 57 | Grand Vault (P57) | `G^` → `G^@*` (1,3) | No existing spinner can make a 3rd turn, so one arrow became a pattern spinner; its 3rd turn is reachable (not on the solution path). 43.4 → 46.5 |

**Rule:** a rule change is used only where the new rule can actually show (ccw from its 1st turn, alternating from its 2nd, pattern from its 3rd), verified over every reachable state by `tools/ExperienceLabCheck.tscn`.

## Full map Lab 1–100

Columns:
- **Trap steps:** solution steps that have a losing alternative.
- **Dead ends:** moves a player can still make after a losing move until the board visibly locks (typical / max).

| Lab | Name | Source | Change | Mechanics | Blocks | Diff / Struct | Trap steps | Dead ends (typ / max) |
|---|---|---|---|---|---|---|---|---|
| 1 | First Steps | Opening Lab 1 | unchanged | arrows | 3 | 1.5 / 1.3 | 0 | – |
| 2 | In The Way | Opening Lab 2 | unchanged | arrows | 4 | 3.9 / 3.5 | 0 | – |
| 3 | The Knot | Opening Lab 3 | unchanged | arrows | 6 | 4.3 / 3.7 | 0 | – |
| 4 | Two Threads | Opening Lab 4 | unchanged | arrows | 7 | 5 / 4.3 | 0 | – |
| 5 | Long Way Round | Opening Lab 5 | unchanged | arrows | 8 | 5.8 / 5 | 0 | – |
| 6 | Spinner | Opening Lab 6 | unchanged | spinners cw×1 | 4 | 4.4 / 3.5 | 0 | – |
| 7 | Right On Time | Opening Lab 7 | unchanged | spinners cw×1 | 7 | 6.4 / 5.1 | 1 | 1.4 / 2 |
| 8 | Hidden Arrow | Opening Lab 8 | unchanged | hidden×1 | 5 | 5.3 / 4.2 | 0 | – |
| 9 | Out Of Sight | Opening Lab 9 | unchanged | spinners cw×1, hidden×2 | 8 | 8.3 / 5.8 | 1 | 1.3 / 2 |
| 10 | Clockwork | Opening Lab 10 | unchanged | spinners cw×2, hidden×1 | 10 | 11.3 / 8.7 | 1 | 1.7 / 2 |
| 11 | Wrong Way | P13 | reordered (was 13) | spinners cw×1 | 11 | 12.3 / 10.7 | 2 | 1.7 / 2 |
| 12 | Pinwheel | P14 | reordered (was 14) | spinners cw×2 | 13 | 12.3 / 10.1 | 1 | 4.3 / 5 |
| 13 | Locked | P16 | reordered (was 16) | locks×1 | 5 | 5 / 3.7 | 0 | – |
| 14 | Key Colors | P18 | reordered (was 18) | locks×2 | 9 | 8.7 / 6.2 | 0 | – |
| 15 | Tight Squeeze | P15 | unchanged | spinners cw×1 | 10 | 13.4 / 11.9 | 3 | 5.1 / 6 |
| 16 | Key Turn | NEW (key_turn) | **NEW** | spinners cw×1, locks×1 | 11 | 12.8 / 10.4 | 3 | 1.8 / 3 |
| 17 | Fog | P20 | reordered (was 20) | hidden×3 | 11 | 9.8 / 6.8 | 0 | – |
| 18 | Crosswind | P19 | reordered (was 19) | spinners cw×2 | 15 | 17.9 / 15.4 | 4 | 6.0 / 8 |
| 19 | Padlocks | P22 | reordered (was 22) | locks×2 | 11 | 11.3 / 8.7 | 0 | – |
| 20 | Secret Key | NEW (secret_key) | **NEW** | locks×2, hidden×3 | 14 | 14.2 / 9.4 | 0 | – |
| 21 | Second Thoughts | P17 | reordered (was 17) | spinners cw×2 | 14 | 14.5 / 12.1 | 2 | 2.0 / 3 |
| 22 | Knots | P21 | reordered (was 21) | spinners cw×2 | 13 | 20.3 / 17.9 | 6 | 7.4 / 10 |
| 23 | Combination | P24 | reordered (was 24) | locks×3 | 12 | 11.7 / 8.1 | 0 | – |
| 24 | Cogwheels | P23 | reordered (was 23); renamed from "Clockwork" | spinners cw×3 | 16 | 20.8 / 17.7 | 4 | 3.3 / 4 |
| 25 | Gridlock | P25 | unchanged | spinners cw×3 | 20 | 21 / 17.5 | 4 | 6.8 / 10 |
| 26 | Master Key | P26 | unchanged | locks×3 | 12 | 12.3 / 8.7 | 0 | – |
| 27 | Gatekeeper | P41 | reordered (was 41) | spinners cw×3, locks×2 | 14 | 27.4 / 22.9 | 8 | 3.7 / 8 |
| 28 | Safe House | P28 | `P^`→`P^@` at (4,2) | spinners cw×1, locks×2 | 16 | 14 / 10.3 | 1 | 1.5 / 3 |
| 29 | Spin the Lock | P36 | reordered (was 36) | spinners cw×3, locks×2 | 15 | 26 / 21.4 | 6 | 3.6 / 6 |
| 30 | Smoke and Mirrors | P30 | unchanged | spinners cw×2, hidden×3 | 17 | 19.6 / 15.1 | 2 | 1.5 / 2 |
| 31 | Twisted Lanes | P31 | unchanged | spinners ccw×1 cw×2 | 15 | 28 / 24.6 | 8 | 6.1 / 8 |
| 32 | Vault | P32 | `Gv`→`Gv@-` at (4,2) | spinners ccw×1, locks×4 | 17 | 16.1 / 10.3 | 1 | 1.5 / 3 |
| 33 | Hairpin | P33 | `R^@`→`R^@-` at (2,3) | spinners cw×2 ccw×1 | 19 | 19.1 / 15.4 | 2 | 2.1 / 4 |
| 34 | Strongroom | P34 | unchanged | locks×4 | 17 | 16.8 / 11.9 | 0 | – |
| 35 | Domino Line | P27 | reordered (was 27) | spinners cw×2 | 13 | 26 / 23.6 | 7 | 4.5 / 7 |
| 36 | Tumblers | P38 | reordered (was 38) | spinners cw×2, locks×2 | 17 | 26.7 / 22.4 | 7 | 5.2 / 9 |
| 37 | Rush Order | P37 | unchanged | spinners cw×4 | 19 | 35.5 / 31.7 | 11 | 5.9 / 11 |
| 38 | Traffic Jam | P29 | reordered (was 29) | spinners cw×4 | 19 | 26.6 / 22.7 | 6 | 11.5 / 14 |
| 39 | Labyrinth | P39 | unchanged | spinners cw×3 | 19 | 36.9 / 33.5 | 11 | 6.0 / 11 |
| 40 | Night Shift | P40 | unchanged | spinners cw×2, hidden×3 | 19 | 28.6 / 23.9 | 7 | 4.5 / 8 |
| 41 | Gearbox | P35 | reordered (was 35) | spinners alt×1 cw×3 | 21 | 32.6 / 28 | 9 | 7.4 / 11 |
| 42 | Whirlpool | P42 | `Bv@`→`Bv@~` at (3,0) | spinners alt×1 cw×3 | 20 | 38.7 / 34.1 | 11 | 6.3 / 11 |
| 43 | Turnstile | P43 | `P<$S`→`P<@~$S` at (2,1) | spinners cw×3 alt×1, locks×2 | 18 | 28.1 / 22.1 | 6 | 12.1 / 16 |
| 44 | Chain Reaction | P44 | unchanged | spinners cw×5 | 23 | 39.5 / 34.6 | 11 | 7.3 / 16 |
| 45 | Deadbolt | P45 | unchanged | spinners cw×3, locks×2 | 14 | 34 / 29.5 | 10 | 5.5 / 10 |
| 46 | Key Ring | P46 | unchanged | spinners cw×4, locks×3 | 20 | 34.2 / 27.8 | 8 | 7.5 / 11 |
| 47 | Grand Tangle | P47 | unchanged | spinners cw×3 | 21 | 43.5 / 39.9 | 15 | 7.1 / 15 |
| 48 | Lockstep | P48 | unchanged | spinners cw×4, locks×2 | 20 | 34.7 / 29.1 | 9 | 6.8 / 10 |
| 49 | Detour | P49 | renamed from "Long Way Round" | locks×3 | 18 | 17.4 / 13.2 | 0 | – |
| 50 | Eclipse | P50 | `Yv`→`Yv@~` at (5,4) | spinners cw×3 alt×1, locks×1, hidden×3 | 17 | 30.5 / 23.6 | 7 | 4.2 / 8 |
| 51 | Clockmaker | P52 | reordered (was 52) | spinners pat×1 cw×4, locks×3 | 22 | 39 / 31.1 | 10 | 4.4 / 8 |
| 52 | Great Escape | P51 | reordered (was 51) | spinners cw×6 | 25 | 48.6 / 43.1 | 14 | 7.8 / 14 |
| 53 | Escape Room | P53 | `G>@`→`G>@*` at (3,1) | spinners cw×4 pat×1, locks×3 | 20 | 39.3 / 31.6 | 10 | 6.0 / 10 |
| 54 | Mechanism | P54 | unchanged | spinners cw×4, locks×3 | 18 | 41.5 / 35.3 | 12 | 3.6 / 10 |
| 55 | Cyclone | P55 | unchanged | spinners cw×6 | 22 | 33.7 / 28.5 | 8 | 8.6 / 12 |
| 56 | Pressure | P56 | `Bv@`→`Bv@*` at (2,5) | spinners cw×4 pat×1, locks×3 | 22 | 42.1 / 34.2 | 11 | 6.8 / 12 |
| 57 | Grand Vault | P57 | `G^`→`G^@*` at (1,3) | spinners cw×5 pat×1, locks×3 | 23 | 46.5 / 38 | 13 | 9.1 / 15 |
| 58 | Last Lock | P58 | unchanged | spinners cw×4, locks×2 | 18 | 45.2 / 39.8 | 15 | 9.0 / 16 |
| 59 | Final Turn | P59 | unchanged | spinners cw×4, locks×2 | 21 | 51.1 / 45.4 | 16 | 8.5 / 16 |
| 60 | The Last Secret | P60 | unchanged | spinners cw×4, locks×2, hidden×4 | 22 | 38.3 / 30.1 | 10 | 8.9 / 16 |
| 61 | Neon Gate | P61 | unchanged | spinners ccw×2 cw×3, locks×2 | 23 | 41.9 / 34.8 | 11 | 8.5 / 13 |
| 62 | Afterglow | P62 | unchanged | spinners cw×2 ccw×3, locks×2 | 22 | 45.2 / 38 | 13 | 8.9 / 13 |
| 63 | Static | P63 | unchanged | spinners alt×2 cw×1 ccw×2, locks×1 | 17 | 42.3 / 35.5 | 14 | 6.3 / 13 |
| 64 | Night Circuit | P64 | unchanged | spinners cw×3 ccw×2, locks×2 | 20 | 47.2 / 40.5 | 15 | 11.0 / 18 |
| 65 | Flicker | P65 | unchanged | spinners cw×2 ccw×2 alt×3, locks×2 | 24 | 46.1 / 36.2 | 12 | 12.8 / 20 |
| 66 | Voltage | P66 | unchanged | spinners ccw×2 alt×2 cw×1, locks×2 | 25 | 47.8 / 39.4 | 13 | 7.2 / 13 |
| 67 | Backspin | P67 | unchanged | spinners ccw×1 cw×4, locks×2 | 20 | 47.5 / 41.1 | 15 | 8.1 / 15 |
| 68 | Glowline | P68 | unchanged | spinners ccw×1 alt×2 cw×1, locks×2 | 25 | 47.1 / 39.5 | 14 | 12.7 / 20 |
| 69 | Prism | P69 | unchanged | spinners cw×1 ccw×2 alt×1, locks×2 | 19 | 48.5 / 41.8 | 16 | 11.6 / 17 |
| 70 | Blackout | P70 | unchanged | spinners cw×3 alt×2, locks×2, hidden×5 | 25 | 47.9 / 37 | 12 | 5.9 / 12 |
| 71 | Overdrive | P71 | unchanged | spinners cw×3 pat×2 alt×1, locks×3 | 21 | 48.4 / 38.6 | 14 | 8.5 / 14 |
| 72 | Synthwave | P72 | unchanged | spinners pat×1 cw×4 alt×1, locks×2 | 22 | 49 / 40.8 | 15 | 8.5 / 17 |
| 73 | Pulse Lock | P73 | unchanged | spinners alt×3 pat×2 ccw×1, locks×2 | 24 | 48.7 / 38 | 12 | 6.7 / 12 |
| 74 | Arcade | P74 | unchanged | spinners pat×2 cw×2 alt×2, locks×3 | 24 | 50 / 39.4 | 14 | 6.6 / 13 |
| 75 | Relay | P75 | unchanged | spinners pat×3 cw×1 alt×1, locks×2 | 23 | 50 / 40.5 | 14 | 13.8 / 21 |
| 76 | Dynamo | P76 | unchanged | spinners alt×2 cw×2 pat×2, locks×2 | 21 | 50.1 / 40.5 | 15 | 9.2 / 16 |
| 77 | Feedback | P77 | unchanged | spinners cw×3 pat×2, locks×3 | 20 | 50.9 / 42.4 | 16 | 8.5 / 16 |
| 78 | Wavelength | P78 | unchanged | spinners cw×3 pat×1 ccw×1 alt×1, locks×3 | 19 | 50 / 41.1 | 15 | 8.1 / 15 |
| 79 | Hyperloop | P79 | unchanged | spinners cw×1 ccw×1 alt×2 pat×1, locks×2 | 20 | 51.3 / 42.9 | 15 | 10.0 / 17 |
| 80 | Dark Matter | P80 | unchanged | spinners cw×3 ccw×1 pat×1 alt×1, locks×3, hidden×4 | 23 | 50.7 / 38.9 | 14 | 8.5 / 14 |
| 81 | Summit Path | P81 | unchanged | spinners pat×2 alt×3 ccw×2, locks×3 | 25 | 51 / 38.6 | 12 | 9.6 / 17 |
| 82 | Thin Air | P82 | unchanged | spinners ccw×1 pat×2 alt×3, locks×3 | 22 | 52.5 / 41.2 | 15 | 6.3 / 11 |
| 83 | Ridge Line | P83 | unchanged | spinners cw×4 ccw×1 alt×1 pat×1, locks×2 | 27 | 52 / 42.6 | 14 | 17.4 / 24 |
| 84 | Iron Crown | P84 | unchanged | spinners ccw×2 alt×2 pat×1 cw×2, locks×2 | 23 | 53.8 / 43.8 | 16 | 8.8 / 18 |
| 85 | Avalanche | P85 | unchanged | spinners pat×2 ccw×2 alt×1 cw×2, locks×3 | 24 | 53 / 41.9 | 15 | 9.3 / 16 |
| 86 | Glacier | P86 | unchanged | spinners cw×2 alt×3 pat×2, locks×3 | 24 | 53.5 / 41.8 | 14 | 5.6 / 11 |
| 87 | Stormwatch | P87 | unchanged | spinners ccw×1 cw×1 alt×3 pat×2, locks×3 | 24 | 54.2 / 42.2 | 14 | 10.7 / 21 |
| 88 | High Pass | P88 | unchanged | spinners pat×1 ccw×3 alt×1, locks×3 | 29 | 54 / 44 | 15 | 18.6 / 27 |
| 89 | Keystone | P89 | unchanged | spinners pat×2 cw×3 alt×1 ccw×1, locks×3 | 21 | 54.9 / 44.3 | 17 | 8.5 / 14 |
| 90 | Eclipse Peak | P90 | unchanged | spinners alt×2 ccw×1 pat×2, locks×3, hidden×5 | 24 | 54.2 / 40.8 | 14 | 5.9 / 15 |
| 91 | Grandmaster | P91 | unchanged | spinners cw×2 alt×2 pat×2 ccw×1, locks×3 | 25 | 55.9 / 44.4 | 15 | 13.7 / 21 |
| 92 | Checkmate | P92 | unchanged | spinners pat×2 alt×2 cw×1 ccw×2, locks×3 | 26 | 55.1 / 43.2 | 15 | 8.0 / 15 |
| 93 | Gordian Knot | P93 | unchanged | spinners alt×2 cw×2 ccw×1 pat×2, locks×2 | 30 | 56.3 / 45.1 | 14 | 8.8 / 15 |
| 94 | Clockwork Crown | P94 | unchanged | spinners cw×3 pat×2 alt×1 ccw×1, locks×2 | 27 | 56.5 / 46.3 | 15 | 10.1 / 17 |
| 95 | Paradox | P95 | unchanged | spinners ccw×1 pat×2 cw×3, locks×3 | 24 | 57.9 / 48.2 | 18 | 11.5 / 20 |
| 96 | Endgame | P96 | unchanged | spinners cw×2 alt×2 ccw×1 pat×1, locks×3 | 22 | 58 / 48.1 | 18 | 9.6 / 18 |
| 97 | Apex | P97 | unchanged | spinners ccw×1 cw×3 pat×1 alt×1, locks×2 | 22 | 58.5 / 50 | 19 | 10.0 / 19 |
| 98 | Zenith | P98 | unchanged | spinners cw×2 alt×1 ccw×1 pat×2, locks×3 | 23 | 61 / 50.8 | 19 | 9.4 / 19 |
| 99 | Last Light | P99 | unchanged | spinners alt×1 cw×2 pat×1 ccw×2, locks×2 | 25 | 61.1 / 52 | 19 | 13.7 / 22 |
| 100 | The Master | P100 | unchanged | spinners alt×2 cw×2 pat×2 ccw×1, locks×3, hidden×3 | 24 | 67.7 / 54.5 | 21 | 13.2 / 21 |

## Polish pass (after human playtests): Lock onboarding and milestones

Human result: both testers went well beyond Level 25 and enjoyed it. The progression is approved as is: no reorders, no rebalancing, no 61–100 changes. Two presentation fixes, both lab-only.

### Lock onboarding (Lab 13 "Locked")

**Before:**
- The finger pointed at one green block; the player moved it, and the lock did **not** open. It opened only later, when the *other* green block left, far from where the player was looking.
- The hint "A lock opens when all blocks of **its** color are gone" reads as the locked block's own colour (blue), not the key colour on the padlock (green).
- An experienced tester only learned the "all of them" rule hundreds of levels later.

**After** (board layout unchanged; the Lock rule unchanged):
- A guided **lock lesson**, the same lesson system as the Switch, Gate and Armor lessons:
  1. Brackets mark the lock **and every green block**. The finger points at the green **nearest the lock**. The line reads "The LOCK opens when every GREEN block is gone (2 left)".
  2. **Green 1 leaves:** the lock stays shut, **rattles**, and the remaining green **hops** (the existing "locked tap" animation). The counter reads "(1 left)" and the finger moves to the last green.
  3. **The last green leaves:** the lock **opens at once**, with the existing pop, green burst, unlock sound and haptic. The line reads "Every GREEN block is gone - the lock is open!".
- The finger only offers moves that keep the level solvable. Undo returns to the previous step.
- The lesson is shown once (`lesson_lock` in the lab save); replays show the plain hint.
- **Lab-only hint fix:** "A lock opens when every block of the LOCK's color is gone". Production is untouched.

**Code:**
- `ExperienceLab.LESSONS = {13: "lock"}`.
- "lock" in `GameManager._lesson_blocks`, `_lesson_step` and `_finish_lesson`, plus a key-escape hook. None of it runs outside the lab.
- The hint override lives in `tools/experience_lab_build.py` (`HINTS`, recorded in the manifest).

### Onboarding audit: first introduction of each mechanic

| Mechanic | Lab | A. Asked action | B. Immediate visible consequence | C. Rule understood? | D. Mismatch? | Verdict |
|---|---|---|---|---|---|---|
| Spinner | 6 | Finger on the only free block (below the spinner); "Spinners turn when a neighbor escapes" | The spinner turns at once (move 1 of 4) and can then leave | Yes | No | **CLEAR** (unchanged) |
| Hidden | 8 | Line "Hidden arrows appear when a neighbor escapes"; one free block; tapping the "?" is free and explains | The "?" is revealed the moment its neighbour leaves | Yes | No | **CLEAR** (unchanged) |
| Lock | 13 | Before: finger on one green | Before: nothing (the lock stayed shut) | Before: no | Before: **yes** | Before: **ONBOARDING FAILURE**. Now **fixed** (above) |
| CCW spinner | 31 | Line "Ring arrows show which way a spinner turns next"; no finger | Its only turn comes at move 8 of 15, among two clockwise spinners; the ring shows the direction beforehand | Mostly | Slight (late, one turn, mixed board) | **MINOR CLARITY ISSUE** (not changed) |
| Alternating | 41 | Line "Dots show a spinner's rule: this one alternates"; no finger | The spinner can turn **at most once** anywhere in the level (it never alternates); only its dot strip shows the next turn is opposite | Weakly | **Yes**: told it alternates, but it never can | **ONBOARDING FAILURE: reported, NOT changed** |
| Pattern | 51 | Line "Pattern spinner: right, right, left - then repeat"; no finger | The spinner can turn **at most twice** (the distinctive third, left, turn never happens) | Partly (strip and line) | Yes, but Lab 53 shows the third turn on its solution path two levels later | **MINOR CLARITY ISSUE** (not changed) |

**Not changed on purpose:** the brief asked to report any other onboarding failure first. The fix candidates would be:
- an alternating-spinner intro board whose solution needs both turns (Lab 50 is the first such level today);
- optionally, moving the pattern's third turn into Lab 51.

### Milestones 25 / 50 / 75 / 100 (presentation only)

`ExperienceLab.CELEBRATIONS`, read through `Chapters.celebration_tier` only while the lab is active. Every milestone uses the existing fitted overlay: the number large and dominant, "LEVELS ESCAPED!" under it, 40 px safe margins, the font shrinking to fit, never clipped.

| Level | Tier | Burst / sound | Hold before the card | Card title |
|---|---|---|---|---|
| 25 | short | 2 bursts, milestone jingle | ~1.6 s | "25 LEVELS ESCAPED!" |
| 50 | stronger | 4 bursts, milestone jingle, then a sparkle and an extra burst (0.35 s later) | ~1.9 s | "50 LEVELS ESCAPED!" |
| 75 | short+ | 3 bursts, milestone jingle | ~1.7 s | "75 LEVELS ESCAPED!" |
| 100 | major | 6 bursts, Master jingle, **"100 / LEVELS ESCAPED!"**, then the **MASTER!** stamp (Master identity kept) | ~3.8 s | "MASTER CLEARED!" |

**Before the level:** milestone levels get the gold level label and the "MILESTONE · LEVEL N" banner, the anticipation beat; 100 keeps "MASTER LEVEL".

**What does not change:**
- Chapter Complete is unchanged and still follows at 50 and 100.
- No coins, stars or rewards change.
- Nothing says final, finished, grand or halfway.

**iPhone (390×844):** every overlay sits at 6–94% of the width and 31–53% of the height, clear of the bottom controls, touch only.

## QA

| Check | Result |
|---|---|
| `tools/ExperienceLabCheck.tscn` | **2388 / 2388** (polish pass; 2137 before). Adds the Lab 13 lesson: it opens; it marks the lock and every key block; the finger starts on the key nearest the lock; the counter; after key 1 the lock is still closed and the finger moves on; Undo; the LAST key opens the lock immediately; remembered; the replay shows the plain hint. Milestones: tiers exactly at 25 / 50 / 75 / 100 and nowhere else; the overlay appears only there and fits the screen; reads "N / LEVELS ESCAPED!"; card titles; no finale words. Before the polish pass: **2137 / 2137**. URL parsing (17 cases, including `?v=123456&experiencelab=reset`, hash, URL-encoded, look-alikes); labs off by default; exactly `level_01..level_100` (+ manifest); every level equals its source plus the listed edits; unique names; all 100 solvable; first appearances spinner 6 / hidden 8 / lock 13 / ccw 31 / alt 41 / pattern 51 with their hints only there; every adapted rule can show; new 16 / 20 human-solvability rules on every reachable state; SHOW A MOVE and Hammer on sampled states of all 100. **Real game, Lab 1–100 in order:** board, hearts, SHOW A MOVE, Undo exact, Restart exact, Hammer refuses unsafe smashes, clears by taps, Chapter complete at every 10th, lab-complete screen after 100 (never 101), Level Select 1–100. **Production and Opening Lab saves byte-identical** |
| `tools/ExperienceLabQaCheck.tscn -- --experiencelab=N` (QA jump, real launch path) | **all pass for N = 13, 25, 31, 41, 50, 51, 75, 100** (19–22 checks each). Lab N opens directly with no title, in the QA save. 1..N-1 are cleared with no stars and coins at a new save's 60. Lab 13 starts its lesson, and 31 / 41 / 51 / 100 show their intro hints. Opening never celebrates. Cleared by taps (through the lesson on 13), it gives exactly its milestone, card title and Chapter Complete, and NEXT goes on (after 100: Chapter 10, then lab complete). **Real save, Opening Lab save, normal lab save and lab log byte-identical.** ExperienceLabCheck: **2398 / 2398** (+10 URL cases for the jump) |
| `tools/web_experience_lab_test.mjs` (Chromium 390×844, touch) | **81 / 81** (QA jump): section F covers `?experiencelab=13`, `?v=123456&experiencelab=13 / 25 / 31 / 41 / 50 / 51 / 75 / 100`, directly on the level. It checks the lesson and intro hints, that no milestone shows on opening, the milestone after clearing 25 / 50 / 75 / 100, and 100 → lab complete. The normal lab save and log are unchanged, `experiencelab=1` still continues, and `experiencelab=reset` still starts at Lab 1. Polish pass: **44 / 44**: adds real touches through the Lab 13 lesson (lock still closed after the first green, open after the last); 25 / 50 / 75 / 100 overlays inside the screen and above the controls; card titles; an ordinary level (24) shows none. Before: **23 / 23**. `?v=123456&experiencelab=reset` and `?experiencelab=reset` start a new lab player (a real save at Level 150 and an Opening Lab save present); Lab 1→4 by NEXT; Lab 13 / 16 / 20 / 31 / 41 / 51 / 100 boards; 100 → Chapter 10 card → lab-complete screen → LEVEL SELECT (100 levels); no level after 100 ever started; **real save and Opening Lab save byte-identical**; a look-alike parameter and the plain URL open the real game at Level 150 with 300 levels; no page errors |
| Production | `levels/` unchanged; Classic 1–200 and 201–225 solver goldens identical; Portal / Sequence / Movable lab goldens identical; verifier all 300 levels; unit tests; Opening Lab, Era3, Portal, Sequence, Movable checks; Social smoke / play, recipient, Friend flow / API; the 300-level playtest. Browser: Opening Lab, Era3 (1–300 flow), persistence (47), recipient, Friend flow all pass on this build |

## Watch list for human testing (deferred on purpose)

- **Optional fixes, deferred pending human evidence:** 45 (Deadbolt, 91% forced), 59 (Final Turn, 91% forced), 79 (Hyperloop, single line), 83 / 88 (dead ends 17–19 moves typical), plus the four plateau breathers in 61–100.
- **43 Turnstile:** keeps its 12-move hidden dead ends (unchanged layout).
- **Light rule applications (rule visible off the solution path only):** 42, 43, 57. Watch whether players notice alternating / pattern there; 50, 53 and 56 use the rule on the solution path.
- **51 → 52:** Pattern intro (39.0) then Great Escape (48.6). The spike moved one level but did not go away.
- **27 Gatekeeper (27.4) after 25 / 26:** a step above the 25 peak, but fair (dead ends ~3.7).
- **20 Secret Key** has no losing moves (by choice). Watch whether it feels like a finale or a breather.
- **Number-based systems still follow the level number:**
  - Hearts from 6.
  - Free SHOW A MOVE: 0 before 20, 1 for 20–29, 2 from 30.
  - Chapter-card "NEW:" lines (Silver Blocks in Chapter 4, Gold in Chapter 6, from production numbering).
  - Master at 100.

  Moved boards keep their reward blocks (Silver at 27, from P41).
- **Reorders change which board's stars show** for a lab level only inside the lab save, never in production.
