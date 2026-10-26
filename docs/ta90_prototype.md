# 90-second Time Attack prototype with dynamic music (`?ta90=1`)

**Development only.** The player and QA builds ignore `?ta90=1`, and neither the music nor the board data is in those builds. The 120-second pilot (`?tapilot=1`), its boards, records and storage are untouched, and so are Production, the 300 levels, the Social MVP and Supabase.

## Boards

**Phase 14 (`docs/ta90_design.md`):** three new boards with neutral names, each a **HUMAN-REVIEW CANDIDATE**: technically validated, but their strategic quality is not yet confirmed by people. The selection lists them as PUZZLE 1-3. The targets are design intentions, not ratings.

| Shown as | Key | Data | Fingerprint | Design target | Idea |
|---|---|---|---|---|---|
| PUZZLE 1 | N1 | `data/dev/ta90_n1.json` | `b5bb75f5937f03404ba786ff93d3e914d167ad2d5e28f88f5ed46e4a40377bff` | MEDIUM | switch timing |
| PUZZLE 2 | N2 | `data/dev/ta90_n2.json` | `f4be705fcc692f27f13e0cc8d7eca216a4ba68d117b84dce4980bfa5e76d695f` | HARD | ram timing + chain gate |
| PUZZLE 3 | N3 | `data/dev/ta90_n3.json` | `76d704deb06f8a6686040e5f5cfa6edeecdfc3f2a1af8f0c98be9a4922f2272c` | VERY HARD | a reversal opens the gate |

**Phase 15 (`docs/ta90_collection.md`):** ten more HUMAN-REVIEW CANDIDATES, N4-N13, shown as PUZZLE 4-13 (key N<k> = PUZZLE k). Data files `data/dev/ta90_n4.json` … `ta90_n13.json`. The selection screen is a 3-column grid of PUZZLE tiles with short statuses.

**Phase 16 (`docs/extreme90_bank.md`):** the same page also serves the EXTREME bank, `?extreme90=1` (`Extreme90Bank`).
- It shows CHALLENGE 1-15: N3, N5, N7, N11, N13 and N14-N23. N14-N23 are played only there.
- It has its own storage (`xb90_*`) and its own export (`ce-xb90`). The rules, music and questions are identical.
- `?ta90=1` keeps N1-N13 unchanged.

**REFERENCE (TA)** is the validated 120-second board, used only to test the clock and the music.
- It shows only with `&ta90ref=1`, labelled REFERENCE and listed after the three puzzles.
- TA's 120-second record and fingerprint are untouched: the prototype has its own storage.

Phase 13's P5 and P6 were rejected (`data/dev/extreme17_search/README.md`); they are not used.

## Rules

The rules are `Ta90TimeAttack.TA90_RULES`, version `ta90-v1`, and every record carries them:
- exactly 90 s;
- GREEN 1:30-1:01, ORANGE 1:00-0:31, RED 0:30-0:00 (the 120 s page's pill, thresholds and reduced-motion behaviour);
- SHOW A MOVE x0;
- UNDO x3 per attempt;
- unlimited RESTART, which never restarts the clock;
- HAMMER x0;
- TIME UP is frozen, then CONTINUE WITHOUT TIMER, with its own record.

## Music

`tools/generate_ta90_music.py` produces one original theme using the game's own synthesiser (`tools/generate_music.py`), with no samples or third-party audio. It is rendered as four full mixes in `data/dev/ta90_audio`: mono, 22 kHz, loop-marked, compressed as QOA on import, about 0.65 MB in the build.

| Mix | When | Tempo | Arrangement |
|---|---|---|---|
| green | 1:30-1:01 | 112 BPM | Light and focused: pad, gentle arpeggio, light hats. |
| orange | 1:00-0:31 | 112 BPM | Rhythmic urgency: syncopated arpeggio, pulse bass, kick, claps, 16th hats. |
| red | 0:30-0:00 | 112 BPM | Tension: 16th arpeggio, eighth bass, four-on-the-floor kick, bell motif, counter-melody. No alarm sounds. |
| calm | untimed continuation | 92 BPM | Pad, bells, soft choir, no drums. |

**How it plays** (`scripts/audio/stage_music.gd`):
- **Stage changes:** the three timed mixes share key, chords, tempo and loop length, so a stage change is a 1.6 s cross-fade that starts the next mix at the same loop position.
- **Untimed play:** the calm mix fades in over 2.5 s.
- **Silence:** a solve, TIME UP, the result cards, the questions and leaving all fade the music out over 1 s.
- **Fades follow the wall clock**, not the frame rate. A page drawing few frames still finishes every fade on time.
- **It only follows the clock.** The countdown stage chooses the mix; nothing in the music reads or changes time.
- **Sound starts only after a real tap.** The game's existing iOS unlock is used. After a reload the music waits for the next tap.
- **Player controls:**
  - A MUSIC ON / OFF button sits beside the countdown, on the pill's row and never over the board. The hub remembers the choice.
  - The player's global music setting is followed, even while music is playing.
- **The campaign music bus stays muted while the prototype is open.** It is restored on exit, and the saved setting is never changed. The prototype's music plays on its own bus, `TA90Music`.
- **In the background:** the music pauses and resumes; the clock keeps running.
- **No audio:** if a file is missing or there is no audio output, the page is simply silent.

## The page and the hub

- `Ta90TimeAttack` (`scripts/social/ta90_time_attack.gd`) extends the 120 s pilot page. It changes only the clock, the texts, the storage (`ta90_*`), the rules version, the music and the toggle. It adds one question: "Did the music make the experience better?"
- `Ta90Prototype` (`scripts/social/ta90_prototype.gd`) is a separate copy of the pilot hub (`TaPilot` is unchanged). It has:
  - a welcome screen, one familiarity question and the puzzle choice;
  - COPY ALL RESULTS, which copies one anonymous `ce-ta90` bundle with the session id, familiarity, music setting and every run;
  - its own storage (`chain_escape_ta90_*`).

## QA

- `tools/ta90_check.gd` is the headless check. Since Phase 14 the full timed flow runs on N1. Every other board (N2-N13) is solved in a timed run on the real page, and its export entry (key, fingerprint, outcome, rules) is checked; the selection grid is checked on screen.
- `tools/web_ta90_page_test.mjs` runs a full real-time 90 s game in Chromium at iPhone SE size: stages and mixes, mute, background, reload and the tap rule, TIME UP, the calm untimed game, the bundle export, reduced motion and the player build. Run 3 (Phase 14) opens each new puzzle, reads the WebAssembly cost of a full solve (`&bench=1`, the Solver call the page makes at TIME UP) and solves N2-N13 by touch in timed runs (Phase 15: the 13-tile grid on the iPhone SE screen). `--board=TA` runs the same game on the reference (`&ta90ref=1`).
- **Chromium is not iPhone Safari.** The audio checks read Chromium's Web Audio state and the mix and position the page publishes; nobody listened. The real Safari unlock, background behaviour and audio quality need a phone. Headless Chromium uses software rendering at about 4 fps, so its frame-rate comparison (with and without music) is only a rough sign.
