# Chain Escape — product findings and roadmap (Social)

Status as of the Challenge a Friend phase 3 finishing patch. This is a record of
findings and direction only: nothing below is built, designed in detail, or
scheduled beyond "next".

## Real-user findings (phase 3 real-device test)

**What worked:** the full social loop on real iPhones.
- Phone A created a HARD Friend Challenge and sent it on WhatsApp; it arrived immediately and was solved.
- From the recipient's phone, CHALLENGE A FRIEND created an EASY challenge for a third phone, which also arrived immediately and worked.
- Creator PLAY / PREVIEW, the Friend creator, the recipient flow and WhatsApp sharing all worked well.

**UX findings, addressed in the finishing patch:**
- **NEW CHALLENGE** was read as "let me choose a new challenge", not "give me another one like this". It now returns to the difficulty choice.
- **HINT** was vague for first-time players. It is now **SHOW A MOVE** everywhere (Classic and Social), with the behaviour unchanged.
- Players looked for the **Hammer** in Friend Challenge. It is now there: free, x2 per attempt (provisional), isolated from the Classic economy.

**VERY HARD did not feel very hard.** This is a real finding: the label is a promise to the player. The audit (README, *Audit: VERY HARD*) shows why: most moves in a Friend board are free and safe, and the Solver's score rewards size and length more than the decisions a person has to make. **No generator change has been made yet;** the recommendation is waiting for approval.

**Competition is what younger players asked for.** The sharing loop works technically, but simply sending and solving is not yet enough of a "wow" for repeated play. Their immediate wishes:
- a measurable completion time
- comparing results with another person and trying to beat their result
- relative performance (percentile)
- eventually live 1v1 against someone online

## Real-user findings (phase 3b real-device test, `5889e02`)

**Passed:** the NEW CHALLENGE flow, SHOW A MOVE in Classic and in Friend Challenge, the Friend HAMMER x2, the exact same Friend board on several iPhones (local themes do not affect it), and sharing / the recipient flow.

**New findings:** these are why phase 3 was not frozen at `5889e02`.
- HARD felt too easy to both testers.
- VERY HARD felt clearly too easy to both testers.
- Photo / Message Reveal lacked the Hammer; the Social tool set should be the same everywhere.

**Response (phase 3b):**
- One free Social tool set: UNDO x3, SHOW A MOVE x2, HAMMER x2, RESTART.
- HARD and VERY HARD now selected by human-difficulty criteria, with the same two mechanics (README, *Phase 3b patch*).
- If real players still find VERY HARD too easy, the next candidates are Classic mechanics: colour locks, then counter-clockwise spinners. These would need a separately approved iteration (generator, PuzzleDefinition review, backend cell validation, recipient tests, readability).

## Real-user findings (phase 3c real-device test, `87c92db`)

**Passed:** Social tool consistency (Photo / Message and Friend Hammer, SHOW A MOVE everywhere), acceptable generation speed, immediate sharing and recipient opening.

**Failed expectation:** VERY HARD still felt too easy to two real users, despite much stronger algorithmic metrics. Algorithmic metrics improved but did not predict human-perceived difficulty.

**Investigation:** the existing Classic Locked Block was audited and prototyped locally (`docs/lock_prototype_audit.md`): no production change. Evidence and a recommendation are waiting for approval.

**Phase 3d:** Locks rejected for production (audit approved). A blind development-only human test (`?vhtest=1`, `docs/vh_human_test.md`) compares current VERY HARD with offline heuristic-selected, opening-constrained boards (arrows + clockwise spinners only), with SHOW A MOVE x1 / HAMMER x1. Counter-clockwise spinners are the next controlled experiment only if those boards still feel too easy to people.

**Phase 3e:**
- Blind test 1: 0 of 30 rated VERY HARD.
- The Classic topology audit and blind test 2 (`docs/vh_human_test2.md`) test whether board structure (density, depth, visual search) is the missing ingredient.
- Mixed clockwise + counter-clockwise spinners follow only if it is not.

**Phase 3f:**
- Blind test 2: 0 of 42 rated VERY HARD.
- Topology-only tuning shows diminishing returns.
- Blind test 3 (`docs/vh_human_test3.md`) isolates clockwise + counter-clockwise spinners, with HAMMER x0 for both groups. If counter-clockwise spinners do not help, the next candidate variable is attempt cost (board size / solution length).
- The eventual Social assistance policy (HAMMER x1 for EASY–HARD, x0 for VERY HARD) is not decided; VERY HARD must first be hard by itself.

**Phase 3g:**
- Blind test 3: 0 of 20 rated VERY HARD; counter-clockwise spinners helped the less-exposed tester only. Across tests 1–3, 0 of 92 playthroughs rated VERY HARD.
- **VERY HARD design is paused** until levels 201–300 (planned before launch) add mechanics: the final VERY HARD must challenge an expert who knows the whole vocabulary through level 300.
- Lessons: `docs/vh_human_test3.md` §8. Phase 3 stays unfrozen.

**Chapter 2 mechanic lab (levels 201–300 come first):**
- PORTAL is the first candidate. A dev-only prototype (`?mechlab=1`, `docs/mechlab_portal.md`) with matched control boards decides GO / MODIFY / DROP with people.
- Sequence, Choice, Linked / Trigger, levels 201–300 and the global Game Feel pass are not started.

## Next product phase (after phase 3 is frozen): COMPETITIVE CHALLENGE

The likely first step is **asynchronous competition on the exact same stored challenge**. The exact-board architecture already built (one immutable `PuzzleDefinition` per challenge, rebuilt identically on every device) is what makes this possible: everyone plays the same board.

Concepts to choose from (not designed yet):
- completion time
- same-board comparison: sender versus recipient
- personal best and the opponent's result
- how many players completed the challenge
- percentile, once the sample is large enough
- challenge-specific ranking
- Challenge Back (answer a result with your own)
- later, possibly, live 1v1

**Not now:** no design of the full system, no database tables, no backend change, no results. The intended shape of a future `challenge_results` table (one challenge, many independent results, anonymous player key, accounts addable later) is already sketched, *not applied*, in `docs/backend/friend_challenge_phase2.md`.

### Fairness: time alone is not a result

A future comparison cannot rank on time alone without considering help:

| | Time | SHOW A MOVE | HAMMER |
|---|---|---|---|
| Player A | 35 s | 2 | 2 |
| Player B | 42 s | 0 | 0 |

Who did better depends on rules not yet decided. The scoring formula is **not** defined now. The data architecture must simply be able to record, per attempt:
- completion time (and start / finish)
- SHOW A MOVE uses
- HAMMER uses
- UNDO uses
- RESTARTs
- possibly failed or abandoned attempts

The phase-2 sketch already has `duration_ms`, `hints_used`, `undos_used` and `state`. A results phase would add `hammers_used` and `restarts` (or a per-attempt record) before any result is stored. Today every Social tool is already counted per attempt in `SocialPlay` (`undos_used`, `hints_used`, `hammers_used`, restart = a new attempt), so nothing in the play code blocks this.

### Live 1v1: later, not now

Players asked for it, and it stays on the roadmap. It is a different order of complexity:
- rooms and matchmaking
- synchronisation and latency
- reconnect and disconnect handling
- a shared start time
- cheating and result validation
- player identity
- session lifecycle

First test whether asynchronous competition (same challenge + time + direct comparison) creates enough engagement. Future choices should avoid blocking live 1v1 (for example: results keyed by challenge id and attempt, board identity by `PuzzleDefinition` fingerprint), but nothing is built for it.

### Personal performance (possible direction)

Time and personal bests may matter beyond friends:
- beat your previous time and improve your result
- track your own performance over time
- challenge yourself on harder puzzles

Framed only around focus, problem solving, personal performance and personal bests. **No medical or cognitive-improvement claims.** Chain Escape must not claim to improve cognitive function unless appropriate evidence ever supports it.

**Research possibility (future, evidence-based only):**
- There is a broader research literature suggesting that cognitive training and puzzle / brain-training activities may support or improve performance in some cognitive domains.
- **Chain Escape itself has not been validated for any such effect, and no such claim is made.**
- Future adult positioning may explore problem solving, focus, planning, personal performance and personal bests, repeated challenge, and measurable improvement over time.
- If the product later shows sufficient traction, a formal study could evaluate whether repeated Chain Escape play is associated with measurable changes in specific cognitive-performance measures.
- Until then: no medical, therapeutic, preventive or cognitive-improvement claim of any kind, in the product, store listing or marketing.

## Explicitly not in phase 3

Timer, `challenge_results` / result storage, percentile, "faster than X%", opponent comparison, leaderboards and ranking, Challenge Back results, live multiplayer and rooms, accounts and profiles, friends and followers, notifications, monetization.
