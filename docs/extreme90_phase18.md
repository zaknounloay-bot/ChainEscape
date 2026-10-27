# EXTREME Time Attack — Phase 18: mechanical diversity

Development only. Production, the 300 frozen levels, Supabase, the Social
MVP, Challenge a Friend and campaign timing / Personal Best are untouched.
Entry: `?extreme90p18=1` (dev builds only). `?extreme90=1` (Phase 16),
`?extreme90p17=1` (Phase 17) and `?ta90=1` are unchanged.

## Step 0 — Repository audit

- Branch `claude/elegant-fermat-0jrmxo`, HEAD `3330adb` (Phase 17), working
  tree clean at the start; tracking `origin/claude/elegant-fermat-0jrmxo`,
  whose HEAD is `8b0abf6` (Phase 16A): `3330adb` is one local, unpushed
  commit on top of it.
- Board ids in use: N1–N30 and TA (`Ta90TimeAttack.BOARDS90`), every one
  with its stored fingerprint (checked by Ta90Check / Extreme90Check /
  Extreme90p17Check). N31–N40 are unused.
- Dev-only Time Attack architecture: `Ta90TimeAttack` (the 90 s page,
  extends `PilotTimeAttack` → `ExpertTimeAttack` → … → `VhHumanTest`, which
  plays a board through `SocialPlay`); hubs `Ta90Prototype` (`?ta90=1`),
  `Extreme90Bank` (`?extreme90=1`), `Extreme90Review` (`?extreme90p17=1`);
  design tools `tools/ta90_design.gd` (A/B/C report), `tools/ta90_search.gd`
  (bounded growth), `tools/xb90_calibrate.gd`, `tools/xb90_filler.gd`.

## Step 2 — Mechanics support matrix (verified in the code)

Campaign counts are from the 300 level files (`levels/`). "Runtime" is the
90 s page: `SocialPlay` → `BoardModel` (+ `set_portals`); the page enables
the campaign tokens Sequence, Movable and Magnet (`VhHumanTest` pilot pages
set `LevelManager.dev_sequence / dev_movable / dev_magnet`). "Solver":
`Solver` (the TIME UP check and every design measure). "Generator": the
design pipeline (`ta90_design.gd` parse / counterfactuals,
`ta90_search.gd` growth). "Replay / export": the page's run log, its
TIME UP replay (`_replayed`, which decides where the untimed continuation
starts), and the export.

| Mechanic | Campaign | Time Attack runtime | Solver | Generator | Replay / export | Mobile / WASM risk | Class |
|---|---|---|---|---|---|---|---|
| Spinner CW | 260 levels (L6+) | yes | yes | yes (search palette) | yes | low | **A** |
| Spinner CCW | 72 (L31+) | yes | yes | yes | yes | low | **A** |
| Alternating spinner | 76 (L41+) | yes | yes | yes | yes | low | **A** |
| Pattern spinner | 45 (L51+) | yes | yes | yes | yes | low | **A** |
| Lock / key | 128 (L13+) | yes | yes | yes (Phase 18: grown as a suffix) | yes | low | **A** |
| Switch / flip target | 73 (L101+) | yes | yes | yes (Phase 18: flip targets grown) | yes | low | **A** |
| Chain gate / links | 49 (L121+) | yes | yes | yes (Phase 18: links grown) | yes | low | **A** |
| Armor (shell) + rammer | 35 (L151+) | yes (ram) | yes (RAM moves) | yes (Phase 18: shells grown) | yes (replay handles "ram") | low | **A** |
| Magnet | 22 (L76+) | yes (dev_magnet) | yes (pulls) | yes (Phase 18: magnets grown) | yes (pulls happen in `remove`) | low; engine rule: no portals / crates / hidden on a magnet board | **A** |
| Sequence | 46 (L226+) | yes (dev_sequence) | yes | yes (Phase 18: grown as a suffix) | partly: the TIME UP replay (`BlindTimeAttack._replayed`) treats an advance as illegal, so after an advance the untimed continuation starts from a FRESH board (pre-existing; affects N5, N7, N21 today) | low | **A** (play) / **B** (continuation) |
| Movable (crate) | 39 (L251+) | yes (dev_movable; push) | yes (cycle-safe search; MovableCheck vs BFS) | yes (Phase 18: crates grown, `movable` counterfactual) | Phase 18 fix: the replay dispatched pushes, scoped to crate / portal boards | crate boards can have more positions: TIME UP cost measured per board | **B → A** after the small dev-only fix below |
| Portal | 53 (L201+) | yes (`SocialPlay` sets portals on the model and the view) | yes (PortalCheck vs brute force) | Phase 18: `verify_equiv` (portal-aware `verify`), `portal` counterfactual | Phase 18 fix: the replay sets portals, scoped as above | low; Social `PuzzleDefinition.verify()` refuses portal boards, so they can never be shared (intended) | **B → A** after the small dev-only fix below |
| Twins | 10 (L176–199) | **no**: the "!" token parses only with `dev_twins`, which the 90 s page never sets; `SocialPlay` has no pair move | yes | no | no | — | **C** |
| Hidden (mystery) | 28 (L8+) | yes | yes | — | — | excluded by the brief (hidden information) | **C** (by rule) |
| Reward blocks ($) | 163 | cosmetic (score only) | n/a | — | — | — | not a strategic mechanic |

### Step 3 — the small, isolated dev-only integration

Two Category B gaps blocked Movable and Portal. Both were fixed in the
smallest form, without touching campaign content, Social, or any existing
board's behaviour:

1. **Design pipeline (tools only).** `ta90_design.gd` Category A used
   `PuzzleDefinition.verify()`, which counts a portal cell as an unparsed
   token. New `verify_equiv()`: identical to `verify()` without portals;
   with portals the same checks, portal cells counted as cells and the
   Solver given the portals (what the page plays). `verify()` itself is
   unchanged. Counterfactuals added: `movable`, `portal`, and `spinners`
   (every spinner a plain arrow — reported as `spinner_dependence`).
   `ta90_search.gd`: `palette: "arrows"` (no spinner ever added),
   `crates_max`, and `suffixes` (the core's own marks: flip targets, gate
   links, locks, shells, magnets, Sequence marks).
2. **TIME UP replay (page, dev-only).** `Ta90TimeAttack._replayed`: on a
   board with crates or portals, the TIME UP position is replayed as the
   play screen dispatches moves (escape / advance / push / ram) on a model
   with its portals; every other board calls `BlindTimeAttack._replayed`
   exactly as before. Without it, a push or a portal escape made the
   untimed continuation restart from a fresh board. Tested in
   Extreme90p18Check (a crate / portal board keeps its TIME UP position;
   N5's replay unchanged).

Not done (needs separate approval): the same fix for **Sequence** boards
(N5, N7, N21 already in the bank). It is one line in `BlindTimeAttack`, but
it would change those boards' existing continuation behaviour on
`?ta90=1`, `?extreme90=1` and `?extreme90p17=1`. **Twins** would need a
`SocialPlay` pair move and page parsing — a substantial change, not
attempted.

## Why Phase 17 (and the whole bank) became spinner-dominated

- **The search could only add spinners or plain arrows.** `ta90_search.gd`'s
  edit palette was `TOKENS` = four plain arrows + twelve spinner tokens;
  every grown piece was a spinner three times out of four.
- **Plain arrows alone never lose.** Without a mechanic that makes a state
  change permanent, every order of plain arrows wins: losing moves (the
  Category B decision structure) come only from spinner turns, switch
  flips, locks, gates, crates, magnets or shells. With spinners in the
  palette, the search reached its decision targets fastest through them.
- **Measured:** the new `spinners` counterfactual on all 22 bank boards —
  18 are unsolvable without their spinners; N13, N20, N23 and N27 keep at
  most 2 decision steps. Every board in the bank, CORE included, is
  spinner-built (`data/dev/extreme90_p18/bank_spinner_dependence.json`).
  The campaign itself uses spinners in 260 of 300 levels.
- The Phase 17 rule "predict a state change" was read as "predict spinner
  turns" — the only state change the search could easily add.

## Step 1 / 4 — Human results and recalibration

Phase 17 playtest (one experienced player, first exposure, real iPhone;
`data/dev/extreme90_p18/human_p17.json`; the automatic timed outcome is the
authoritative record; N25's short second run was an intentional early exit
and is ignored):

| Board | Outcome | Attempts | Human | Decision | Phase 17 metrics (multi-turned spinners · prediction share · shortcut) | Phase 17 "known weakness" |
|---|---|---|---|---|---|---|
| N24 | 51.83 s | 3 | HARD | provisional | 4 · 0.57 · 0.18 | highest shortcut (0.18) — **matched** |
| N25 | 46.84 s | 3 | MEDIUM | archived | 3 · 0.37 · 0.04 | gate worth one mistake; "may read as an ordering chain" — **matched** |
| N26 | TIME UP | 3 | VERY HARD | strong | 5 · 0.50 · 0.00 | — |
| N27 | TIME UP | 6 | VERY HARD | strong | 5 · 0.56 · 0.01 | — |
| N28 | 33.44 s | 2 | MEDIUM | archived | 3 · 0.53 · 0.04 | pattern worth one mistake — **matched** |
| N29 | TIME UP | 5 | VERY HARD | strong | 5 · 0.59 · 0.07 | — |
| N30 | TIME UP | 8 | VERY HARD | strong | 4 · 0.47 · 0.12 | "most likely to play below EXTREME" — **wrong** |

Active selection now: CORE N3, N5, N7, N11, N13; STRONG N14, N15, N16,
N18, N21, N26, N27, N29, N30; PROVISIONAL N23, N24; ARCHIVED N17, N19,
N20, N22, N25, N28 (definitions, fingerprints, records and exports kept).

Findings (a small sample: direction only, no model, no new gate):

- Phase 17's yield was better (4 of 7 VERY HARD vs 5 of 10 retained in
  Phase 16), and the four VERY HARD boards share the Phase 17 idea: the
  player must predict a state change several times over (spinners turned
  four or five times along the solution).
- **Why N25 and N28 felt MEDIUM:** their non-spinner mechanic (gate,
  Sequence) carried a visible ordering, and the spinner part was the
  lightest of the set (3 multi-turned spinners). Once the order was seen,
  the rest was execution. The Phase 17 weakness notes named both.
- **Why N24 felt HARD, not EXTREME:** the largest board (23 pieces) with
  the highest shortcut share — long rather than deep.
- **Where the tools were wrong:** N30 had the weakest diagnostics of the
  set and played VERY HARD; the diagnostics under-read a board whose single
  lock dependency is late and costly. Over-reading is the more common error
  (Phase 16: four archived boards passed every gate).
- **Repetition risk:** every bank board is spinner-built (Step 2 section
  above). Phase 18 broadens "predict how the board will change" to any
  non-monotone change: a switch flip, a magnet pull, a crate push, a
  Sequence advance, a ram that frees a lane — and treats spinner turns as
  one family among several.

## Step 5 / 7 — The Phase 18 design approach

1. **Monotone vs non-monotone mechanics (the key finding).** A lock
   opening, a gate opening, a shell cracking (a ram "is never a mistake")
   and a portal lane only ever CLEAR lanes. With plain arrows they cannot
   create a losing move, whatever the layout: in Phase 18 every such core
   grown with plain arrows stalled at 0 decision steps (PR, SG, PG2, LS,
   AR). Losing moves come only from non-monotone changes: spinner turns,
   switch flips, magnet pulls, crate pushes, Sequence advances. A
   non-spinner EXTREME core therefore needs at least one of switch / magnet
   / crate / Sequence, with the monotone mechanics shaping the order.
2. **Cores with several independent traps.** A single trap — even a good
   one — grew into boards with 1–3 distinct mistakes (MS, MS2, PM, LS2,
   PS, MX1–MX3): the same mistake repeated along the solution.
3. **The growth palette.** `palette: "arrows"` (no spinner can creep into
   a non-spinner core), Movable crates, and the core's own marks as
   suffixes (flip targets, links, locks, shells, magnets, Sequence marks).
4. **Mechanic economy.** The search over-grew magnets (10–12 of 16–17
   pieces); `xb90_filler.gd --economize` strips one mark at a time while
   the decisions stay identical (N31: 10 → 7 magnets; N32: 7 → 6).
5. **Spinner families only where new.** Two spinner cores, each with a
   mechanic never used in the bank before (crate, portal).

## Step 6 / 8 — The Phase 18 candidates (N31–N34)

All four are **HUMAN-REVIEW CANDIDATES** (Category A and B pass; human
difficulty unvalidated). All 7×7, medium size (14–16 pieces).

| ID | Pieces | Mechanics | Family | Primary | Strategic concept | Fingerprint |
|---|---|---|---|---|---|---|
| N31 | 16 | magnets (7) | C magnet relocation | **non-spinner** | pull chains: each departing magnet drags the first block behind it into its cell — who is pulled where decides which lanes stay open | `81fde18027c09394…` |
| N32 | 16 | magnets (6), shells (4) | D/C rammer + magnet | **non-spinner** | the magnet brings the rammer: pulls move blocks into (or out of) the lanes of shelled blocks — a pull can deliver a rammer or bury one | `bb36f7d5fea3359b…` |
| N33 | 14 | spinners + crate | H/A spinner + crate | spinner-based (mixed) | push before you turn: a spinner must launch the crate out of a lane before a neighbour's departure turns it away | `2846f6a5cab3cb3d…` |
| N34 | 15 | spinners + portal pair | H/B spinner + portal | spinner-based (mixed) | a turn that changes the far side: a spinner's lane runs through the portal in one facing and straight out in another | `5616045b9a16674c…` |

**Primarily non-spinner: 2 of 4 (50 %)** — N31 and N32 contain no spinner
at all. This meets the target exactly; it does not exceed it. Magnet
appears in both non-spinner boards: the only non-spinner concept that
cleared every gate without one (Movable + switch, N31 in the first draft)
failed Category A on the re-run below. That is the honest limit of the
supported mechanic set and the current tools.

**Rejected after acceptance: the Movable + switch board (first numbered
N31, design MF_1).** Its TIME UP check measured 38.1 ms in the first full
report. That report had run before the explorer fix (below), so it was
regenerated with the corrected tools to make its records valid — and the
TIME UP check then measured **50.6 ms (> 40)**. Two measurements straddling
the gate mean the board is borderline; the rule is never to re-measure
until a pass, so the failing measurement stands and the board is rejected
(its record: `data/dev/extreme90_p18/rejected_MF_1.json`). Its sibling MF_3
had already failed at 46.7 ms: crate boards of this shape sit at the edge
of the TIME UP budget. The remaining boards were renumbered N31–N34 before
any playtest (never pushed or played; fingerprints unchanged).

### A / B / C results

| ID | Positions | Solution | TIME UP worst (desktop) | Parity | Distinct | Steps | Coverage / late | Shortcut | Mechanic counterfactuals | Spinner dependence | Trap delay | Undo-proof | Learner (look4/6) | Trivial removals | Closest board (overlap) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| N31 | 432 | 16 | 19.0 ms / 427 nodes | 0 / 0 | 6 | 14 | 0.88 / 0.88 | 0.045 | without magnets: 0 steps | none (no spinner) | 8 | 0.83 | 7 / 7 | 0 | N2 (0.26) |
| N32 | 776 | 20 | 30.2 ms / 583 | 0 / 0 | 5 | 16 | 0.80 / 0.80 | 0.005 | without shells: 8 steps, 3 distinct; without magnets: unsolvable | none | 10 | 0.95 | 8 / 8 | 0 | N24 (0.26) |
| N33 | 915 | 18 | 32.8 ms / 1165 | 0 / 0 | 5 | 15 | 0.83 / 0.83 | 0.000 | without crate: 6 steps, 2 distinct | unsolvable without spinners | 10 | 0.83 | 6 / 3 | 0 | N26 (0.26) |
| N34 | 518 | 15 | 23.7 ms / 355 | 0 / 0 | 7 | 13 | 0.87 / 0.87 | 0.067 | without portals: 6 steps, 4 distinct | unsolvable without spinners | 7 | 0.83 | 7 / 7 | 0 | N29 (0.39) |

Every report above was produced with the corrected tools (N31, N32 after
the mechanic economy; N33 after the explorer fix; N34 has no crate).
Category A: every board parses intact, verifies (N34 through the
portal-aware `verify_equiv`), the Solver agrees with exhaustive search in
every reachable position (parity 0 / 0), the solution replays
deterministically, the TIME UP check is ≤ 40 ms from every reachable
position with no exhaustion; WebAssembly cost and iPhone SE layout in the
browser QA below. Category B: every board meets the EXTREME targets, every
listed mechanic is essential, no filler.

### Known weaknesses

- **N31** — 7 of 16 pieces are magnets: a dense board, hard to read at a
  glance; a single-mechanic board (if magnets do not click for a player,
  the whole board is opaque).
- **N32** — 6 magnets and 4 shells: the busiest board; shells alone are
  worth only 2 distinct mistakes (the magnets carry it). Both non-spinner
  boards rely on magnets.
- **N33** — spinner-dependent (unsolvable without spinners); the crate
  adds 3 distinct mistakes. The learner proxy settles it fastest (3). A
  crate board: its TIME UP cost (32.8 ms) is the highest of the set.
- **N34** — spinner-dependent; the portal adds 3 distinct mistakes; the
  closest to an existing board (N29, 0.39 occupancy overlap — a different
  concept, but the most similar silhouette).
- **No large board.** Every 17–25-piece attempt failed (MS, MS2, SG, SG2,
  PR, PM, MX2b, MX3): with the non-spinner palette, more pieces added length
  (repeated mistakes, up to 26 decision steps with 2 distinct mistakes),
  not decisions. All four are 14–16 pieces.
- **Only four boards.** Fewer than the 5–7 the brief anticipated, delivered
  rather than padded.

## Search and rejection summary

20 bounded searches (12 min each, patience 8), 22 193 boards evaluated,
then 18 full A/B/C reports (17 boards, MF_1 twice) and filler checks.

| Core | Family | Growth | Rounds | Evaluated | Best reached | Outcome |
|---|---|---|---|---|---|---|
| MF | movable + switch | arrows + crates | 42 | 1342 | 5 distinct, 16 steps, 0 % | rejected: MF_3 TIME UP 46.7 ms; MF_1 38.1 ms, then 50.6 ms on the post-fix report (> 40) |
| MG | magnet | arrows + magnets | 44 | 1346 | 6 distinct, 15 steps | **N31** (after mechanic economy) |
| AR → AR2 | armor → armor + magnet | arrows + shells (+ magnets) | 16 → 48 | 539 → 1489 | 0 → 5 distinct | AR rejected (monotone: 0 steps); **N32** |
| SPC | spinner + crate | all + crates | 22 | 782 | 5 distinct | **N33** (first report rejected on parity: an explorer bug, see below) |
| SPP | spinner + portal | all | 34 | 1235 | 7 distinct | **N34** |
| PR | portal | arrows | 34 | 1149 | 0 steps | rejected: monotone |
| PG → PG2 | portal + gate | arrows (+ links) | — → 20 | — → 677 | 0 steps | rejected: monotone |
| SG → SG2 | switch / gate | arrows (+ flips, links) | 37 → 50 | 1206 → 1696 | 0 → 1 distinct, 100 % shortcut | rejected |
| LS → LS2 | lock + Sequence → lock + switch | marks | 24 → 51 | 850 → 1600 | 0 → 1 distinct | rejected |
| PS | portal + switch | flips | 37 | 1231 | 1 distinct, 100 % shortcut | rejected |
| MS → MS2 | movable + Sequence | crates (+ Sequence marks) | 33 → 38 | 1046 → 1205 | 2 distinct (38 % → 0 % shortcut) | rejected: one repeated mistake |
| PM | portal + movable + Sequence | Sequence marks + crates | 30 | 989 | 2 distinct, 23 steps | rejected |
| MX1 | magnet + switch | magnets, flips | 33 | 1058 | 3 distinct | rejected (< 4) |
| MX2 → MX2b | crate + two switches | flips + crates | 23 → 29 | 740 → 920 | 3 distinct (38 % → 18 % shortcut) | rejected |
| MX3 | magnets + lock | magnets, locks | 32 | 1093 | 3 distinct | rejected (< 4) |

**Tool correctness issue found and fixed.** On SPC the design tools'
exhaustive explorer (`tools/expert_probe.gd`) disagreed with the game's
Solver in 6 positions. A third, independent breadth-first search
(`tools/xb90_parity_probe.gd`) sided with the Solver every time: the
explorer was not cycle-safe — Movable pushes are the only reversible moves,
and a cycle could memoise "losing" for a winnable position. Fixed for crate
boards only (the explored graph is kept and wins are propagated to a
fixpoint; `longest()` gets a cycle guard); every board without crates is
explored exactly as before. After the fix: 0 disagreements on SPC and MF;
SPC was then reported again with the corrected oracle (a measurement fix,
not a borderline re-measure). The game's Solver was right throughout.

## Step 9 — The Phase 18 developer selection (`?extreme90p18=1`)

`Extreme90P18` (extends `Extreme90Bank`): the same 90 s page, rules
`ta90-v1`, the Phase 16A short questionnaire with one-tap SKIP.

| CHALLENGE | Board | Group (internal, export only) |
|---|---|---|
| 1–5 | N3, N5, N7, N11, N13 | core |
| 6–14 | N14, N15, N16, N18, N21, N26, N27, N29, N30 | strong |
| 15–16 | N23, N24 | provisional |
| 17–20 | N31–N34 | phase18 |

- 20 challenges, three tiles to a row, all on one iPhone SE screen with
  the full "CHALLENGE n" label: tiles 80 high (84 elsewhere) and a tighter
  selection screen (new hub accessors `grid_columns`, `tile_height`,
  `tile_font`, `select_compact`; defaults unchanged for every other hub).
  A four-to-a-row grid was tried first and rejected: it clipped the label
  to "CHALLEN" (the browser test checked the text, not its rendering; the
  headless check now measures that the label fits its tile). Up to 21
  challenges fit this way; more will need another layout (e.g. scrolling). Any challenge — the
  new ones included — opens directly.
- Storage `xb18_*` per board and `chain_escape_xb18_hub`; export
  `ce-xb18` with `selection: "xb18-v1"`, each board's id, fingerprint,
  mechanics and group, and `archived: [N17, N19, N20, N22, N25, N28]`.
- `?extreme90=1` (15 boards, `ce-xb90`), `?extreme90p17=1` (18 boards,
  `ce-xb17`, N25 / N28 still there) and `?ta90=1` (13 boards) unchanged.

## Step 11 — QA report

Builds: the dev Web export (`Web`) and the player export (`Web Friend
Test`, which excludes `data/dev`: 0 dev files in it). Browser tests: Chromium
at iPhone SE size (375×667), real touches. **A desktop-sized Chromium test
does not replace real-iPhone Safari QA**, which follows on your device.

| Suite | Result |
|---|---|
| Extreme90p18Check (new, headless) | PASSED, 110 checks (final, 20-board build): selection (CORE fingerprints; 9 strong; N23, N24 provisional; N31–N34 new ids; 6 archived boards still defined and still on `?extreme90=1` / `?extreme90p17=1`); every board solved on the real page and exported (`ce-xb18`, id, fingerprint, mechanics, group); ORANGE / RED / TIME UP; short questionnaire; untimed continuation (calm); RESTART keeps the clock; GIVE UP + SKIP; **TIME UP on N33 after a crate push keeps that position for the untimed continuation**; **N5's TIME UP replay unchanged**; the selection screen fits (three to a row, the full label measured against its tile, both buttons); the `ce-xb90` and `ce-xb17` exports unchanged; no other storage touched |
| web_extreme90_page_test `--entry=extreme90p18` | PASSED 55/55 (final build): 20 tiles on screen; every challenge (N31–N34 included) solved by touch in a timed run; SKIP; TIME UP → untimed with the calm mix; `ce-xb18` bundle; player build ignores the entry; `xb90` / `xb17` storage never written. (Earlier 21-board builds: 57/57 twice.) |
| WebAssembly full solve (TIME UP call) | final build: N31 12, N32 10.2, N33 11.1, N34 40.3 ms. Earlier runs, same boards: 19 / 18.9, 11.2 / 5.6, 10.6 / 12, 40.5 / 27 ms. Approved boards in the same three runs: N15 49.3 / 52.4 / 51.9, N16 21.9 / 21.8 / 45.4 ms — browser timing varies run to run (one Solver call at TIME UP); the 40 ms gate is the desktop worst-case check, which every board passes. N34 is at the top of the new set: watch it on the iPhone |
| `?extreme90=1` / `?extreme90p17=1` (browser) | PASSED 45/45 / 51/51 |
| Extreme90Check / Extreme90p17Check / Ta90Check | PASSED 91 / 97 / 91 (Ta90Check's board-count rule also excludes the Phase 18 ids) |
| PortalCheck / MovableCheck / MagnetCheck (solver vs brute force) | all PASSED |
| `?ta90=1` / 120 s pilot (browser) | PASSED 55/55 / 28/28 |
| Real-time timer pages (stime / ttime tta) | PASSED 31/31 / 32/32 |
| Campaign timing and Personal Best (web_timing) | PASSED (33/33) |
| Challenge a Friend player build (web_friend_build) | PASSED 25/25 (both full and final runs) |
| Headless suites (Competition, unit tests, Timing, Profile, ExperienceLab QA, Feedback, FriendChallengeApi, FriendFlow, SocialApi, SocialSmoke, SocialPlay, TaPilot, Extreme11, Q1Time, RTime) | all PASSED |
| verify_levels | ALL 300 LEVELS SOLVABLE AND PASS CAMPAIGN RULES |

**Pre-existing failures (not Phase 18):** RecipientTest — the same 3
layout checks as in Phases 16 and 17 ("TOTAL SCORE left, coins right" for
en_US / he_IL / ar_SA). `vh_pilot4_canon.gd` index errors while the search
loads its near-copy list (non-fatal, as before).

**Defects found and fixed during Phase 18:** (1) the 4-to-a-row layout
clipped the challenge labels (caught by screenshot review; fixed, and the
headless check now measures the label against its tile); (2) the design
explorer's cycle bug on crate boards (above); (3) the Movable + switch
board rejected after its post-fix report measured 50.6 ms (above).

The full regression (every headless suite, every web suite, 300 levels)
ran on the 21-board build; after the rejection only dev board data and two
constants changed, and every check that reads them was run again on the
final build (the four time-attack headless checks, the Phase 18 browser
test, the player build).

## Safety audit (end of phase)

- `levels/` untouched; Production, Supabase, Social (`PuzzleDefinition.verify`
  unchanged), Challenge a Friend and campaign timing code untouched.
- Runtime changes, all dev-only: a `BuildFlags`-gated hook in
  `game_manager.gd` (`?extreme90p18=1`); new `BOARDS90` entries N31–N34;
  `Ta90TimeAttack._replayed` override (crate / portal boards only; every
  existing board calls the unchanged base); `Ta90Prototype` selection-grid
  accessors whose defaults reproduce the old layout exactly.
- Historical entries, ids, fingerprints and saved records unchanged
  (checked by Extreme90Check, Extreme90p17Check, Ta90Check and the browser
  tests). Nothing pushed, merged, deployed or uploaded.
