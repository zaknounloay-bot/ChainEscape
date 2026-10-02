# VERY HARD — Classic topology audit and blind human test 2 (development only)

## Why

Blind test 1 (`docs/vh_human_test.md`):
- 30 of 30 puzzles completed, **0 rated VERY HARD**.
- The heuristic-selected boards (B) also did not feel VERY HARD.
- The testers noticed that some hard **late Classic** levels felt different: they had to scan the whole board to find "where can I even start?", while on generated boards the eye sees at once which arrows can leave.

**Question:** are hard Classic boards harder for people because of their density / topology / visual search, which the Friend generator does not reproduce?

Nothing in production changes: no backend, Supabase or API change, no change to the live difficulty profiles. Phase 3 is not frozen.

## 1. Classic vs Friend structural audit (`tools/classic_topology_audit.gd`)

**Mechanics first (the key finding):** every Classic level from **161 to 200** uses mechanics excluded from this experiment:
- armor, locks and CCW / alternating spinners on every one of them
- switches, gates or hidden arrows on most

The only Classic levels after 40 that use just arrows + clockwise spinners are **42, 44, 47, 51 and 55**. So the late levels the testers remember are hard partly *because of their mechanics*. To compare **structure** without changing mechanics, two Classic groups are used:
- **pure Classic:** 42, 44, 47, 51, 55, exact
- **late Classic geometry, flattened:** levels 161–200 with every cell and arrow kept, every spinner made clockwise, and all other mechanics removed (gate slabs become empty cells). 30 of 40 stay solvable.

**Averages per group:**

| Group | n | Size | Blocks | Empty | Density | Start legal / safe / calm | Edge exits | Opening edge distance | Opening buried (of 8) | Tempting | Scan | Later scan | Hidden steps | Branching after move 1 | One-safe steps | Depth | Spinner-turning moves | Clustering | Heuristic player |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Classic 41–60 pure | 5 | 6×6 / 6×7 | 22.2 | 16.2 | **0.58** | 2 / 1 / 1.0 | 0.6 | 0.20 | 1.00 | 6.2 | 0.03 | 0.25 | 8.0 | 2.4 | 7.2 | **17.4** | 4.4 | **3.51** | 37% |
| Classic 161–200 raw (all mechanics) | 40 | 6×7 / 7×7 | 21.9 | 23.9 | 0.48 | 2 / 1 / 0.5 | 0.7 | 0.30 | 2.05 | 5.6 | 0.20 | 0.37 | **10.7** | 2.1 | 11.4 | **18.6** | 3.5 | 2.93 | 14% |
| Classic 191–200 raw | 10 | 6×7 / 7×7 | 23.3 | 22.9 | 0.51 | 2 / 1 / 0.5 | 0.6 | 0.30 | 1.80 | 5.9 | 0.06 | 0.36 | **11.0** | 2.3 | 11.9 | **19.0** | 4.0 | 3.23 | 12% |
| Classic 161–200 **flattened** | 30 | 6×7 / 7×7 | 21.1 | 24.7 | 0.46 | **4.4 / 3.9 / 2.5** | 1.2 | 0.46 | 2.38 | 5.0 | 0.02 | 0.16 | 4.3 | 4.0 | 2.3 | 14.5 | 3.4 | 2.80 | **72%** |
| Friend VERY HARD A | 6 | 6×6 | 17.8 | 18.2 | 0.50 | 3.2 / 2.3 / 1.8 | 2.2 | 0.19 | 2.06 | 4.8 | 0.05 | 0.16 | 4.0 | 3.3 | 3.5 | 10.8 | 4.2 | 2.93 | 19% |
| Friend VERY HARD B | 6 | 6×6 | 18.2 | 17.8 | 0.50 | 2 / 1 / 0 | 0.7 | 0.33 | 2.50 | 4.3 | 0.10 | 0.27 | 6.0 | 2.3 | 7.7 | 13.3 | 5.2 | 3.37 | 4% |

(Column meanings: §3.)

**What it shows (model evidence, to be checked with people):**
- **Late Classic difficulty comes mostly from its mechanics.** With them removed, the same late geometry becomes easy: 4.4 free blocks at the start, 2.3 one-safe steps, depth 14.5, and the heuristic player wins 72%. The geometry alone does not carry the difficulty.
- **Classic's opening is usually *not* hard to find by these measures.** Its start is curated to exactly 2 legal moves, but one of them is usually "calm" (always safe), the opening scan is low (0.03–0.20), and openings sit near the edge. The "where can I start?" feeling the testers describe probably comes from **later** moments.
- **Where Classic differs from Friend structurally:**
  - **Longer dependency chains:** depth 17–19 vs 11–13.
  - **More "hidden" steps,** where the next safe move is not among the most salient arrows: 8–11 vs 4–6.
  - **Denser, more clustered boards** in the pure levels: density 0.58 vs 0.50, about 3.5 occupied neighbours per block vs 2.9–3.4.
- **The pure Classic levels are, by the heuristic-player model, *easier* than B** (37% vs 4%). If people nevertheless rate them harder, the model misses something about structure (density / depth / search), which is exactly what this test checks.

## 2. Exemplars and test 2 composition (`tools/vh_human_test2_build.gd` → `data/dev/vh_human_test2.json`)

All 14 boards:
- use only arrows + clockwise spinners (verified; exact JSON round trip)
- are **rotated 180°**, so a board played before is not recognised; a rotation keeps the puzzle identical and clockwise spinners stay clockwise
- carry no Classic reward markers (they change nothing in play but would look like Classic)

| Group | Boards | Why |
|---|---|---|
| **B**: strongest Friend (from test 1) | test-1 T01, T03, T04, T10, T11 | The lowest heuristic-player rates of test 1 (0–12%), 2 legal / 1 safe / 0 calm openings, 4–10 one-safe steps |
| **D**: pure Classic, exact | levels 42, 44, 47, 51, 55 | The only Classic levels after 40 without excluded mechanics: dense (0.52–0.64), deep (15–22), 7–16 hidden steps. **L51:** the strongest structure (25 blocks, depth 22, 16 hidden steps). **L44:** the densest (0.64, 9 tempting arrows). **L42, L47:** deep, many tempting arrows. **L55:** a calibration board the model calls easy (heuristic player 100%) despite depth 15–17 |
| **E**: late Classic geometry, flattened | levels 163, 165, 169, 194 | The only flattened late boards that keep a hard structure: 10–13 hidden steps, 8–16 one-safe steps, depth 14–20, heuristic player 3–30%. Most others collapse (45–100%). **L165:** depth 20, 0 calm openings. **L163:** 11 hidden steps, 14 one-safe steps |

The builder prints every board's measurements (puzzle id, group, source, size, density, opening, scan, hidden steps, one-safe steps, depth, heuristic player).

**Visible differences that remain:** board size (B is 6×6, D 6×6 / 6×7, E 7×7) and block colours (the Classic levels' designed colours vs generated colours). The look, theme, labels and tools are identical; the source is never shown.

## 3. Visual / topological metrics (hypotheses, not proof)

| Metric | Meant to approximate |
|---|---|
| density, empty cells, clustering (occupied neighbours of 8) | how crowded the board looks |
| edge exits | openings that are outer-ring blocks pointing straight out: the most obvious moves |
| opening edge distance, opening buried | how far inside, and how surrounded, a safe first move is |
| tempting | blocked arrows that are almost out (≤ 2 cells from the edge along the arrow) |
| **scan** (salience model) | the eye checks the arrows closest to leaving first; scan = the share of the board checked before the first **safe** move (0 = the first arrow looked at) |
| **later scan / hidden steps** | the same at every solution step; hidden steps = steps where the next safe move is not in the first 30% of what the eye checks |
| branching after move 1, one-safe steps, depth, spinner-turning moves | planning load after the opening |

None of these is validated against people yet. Test 2 is the check.

## 4. The test page (`?vhtest2=1`)

The same isolated page as test 1 (`scripts/social/vh_human_test.gd`), with its own board file, its own storage, and a clearer second question:
- **Play:** blind, in a random order per device, every puzzle shown as "PUZZLE n / 14 · VERY HARD" in the same SocialPlay presentation (same theme, HUD and tools: UNDO x3, SHOW A MOVE x1, HAMMER x1, RESTART). Classic boards are rebuilt from PuzzleDefinition and played in SocialPlay, never as Classic levels.
- **After each puzzle:** "How difficult was this puzzle?" (EASY / MEDIUM / HARD / VERY HARD), then **"Was it immediately obvious which block you could start with?"** (YES / NO / SKIP).
- **Recorded locally:** hidden group, puzzle id, solved / not, total moves, restarts, UNDO / SHOW A MOVE / HAMMER uses, time to the first move, total time, rating, the obvious-start answer.
- **Storage:** the test's own file plus a synchronous localStorage copy under its own key, so closing Safari right after a rating loses nothing. The Classic save is never touched, and there is no network.
- **Results:** groups are named only after the last puzzle. COPY RESULTS gives the JSON.

## 5. How Loay and his son run it on iPhone

1. Upload the development ZIP to the **separate private itch.io test page** used for test 1 (not the live game page).
2. On **each** iPhone, open that page in Safari and add `vhtest2=1` to the address: `…/index.html?v=123&vhtest2=1` (use `&` when the address already has a `?`). Test 1's results on the phone are kept separately.
3. Tap START and play all **14** puzzles. Breaks are fine: reopening the same address continues. Please stay on the puzzle while it is open: time counts.
4. After each puzzle, answer:
   - **How difficult was this puzzle?**
   - **Was it immediately obvious which block you could start with?** Answer only about the *first* move: YES if you saw a block you could start with almost at once, NO if you had to search the board for it.
5. After the last puzzle, tap **COPY RESULTS** and paste it into the chat (or send a screenshot of the results screen).

## 6. How the results will be read

- **Main comparison:** perceived difficulty and the obvious-start answers, **D vs B** (and E vs B).
- **Supporting:** restarts, time to the first move, total time.
- **If D (and / or E) is rated clearly harder than B,** and more often "not obvious where to start": density / topology / search matters. The structural differences above (deep dependency chains, dense clustered boards, hidden next moves) are what the generator would need to reproduce. No generator change before that decision.
- **If D and E are not harder than B:** board structure with arrows + clockwise spinners is not the missing ingredient. The next controlled experiment would be mixed clockwise + counter-clockwise spinners.
