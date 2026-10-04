# The PORTAL arc — levels 201–225 (v0.7, Third Era)

Portal is the first production mechanic of the Third Era. These 25 levels teach it, apply it, combine it with the older mechanics one at a time, and end on a short milestone at 225.

**Out of scope here:**
- 226+
- Sequence and Movable (still lab-only)
- Friend / Social generation (Portal is never enabled there)
- the global Game Feel pass

## 1. The production rule

Exactly the lab rule (`docs/mechlab_portal.md`), unchanged:
- A portal cell `OA` holds no block. Its pair `OA` is elsewhere; groups A–D, exactly two cells each.
- A block whose lane enters a portal comes out of the other portal of the same letter, **in the same direction**, and continues.
- What stops it on the far side stops it like any blocker. The tap is then a normal blocked tap, and the message names the portal: "Blocked after portal A".
- A lane may cross several portals. A layout where any lane could loop is rejected by the parser (`Portals.layout_errors`) and never reaches a level.

The same lane rule is used everywhere:
- escape, bump and ram (through a portal too)
- Undo / Restart (portals are part of the level, not of the board state)
- SHOW A MOVE (the solver's next move)
- the Hammer (its safety check, `Solver.hammer_safe`, solves with the portals)
- `LevelAnalysis` and the verifier

**Levels 1–200 contain no portal.** Every engine path behaves exactly as before on a board without portals; the before/after proof is in §5.

**Feel:**
- The existing portal look and its escape / bump / ram animations from the lab.
- A new short rising **portal** chime when a block escapes through a portal. It is synthesised, and audio-off, mute and the Web audio unlock all behave as for every other sound.

## 2. NEW MECHANIC card

- **What:** `scripts/ui/mechanic_intro.gd` (`MechanicIntro`).
  - The card shows **NEW MECHANIC!** and **PORTAL**, with a miniature: a block goes in at A, comes out of the other A, and keeps going. The captions read **ENTER A → EXIT A → CONTINUE**.
  - Every word comes from one table (`MechanicIntro.TEXT`) so it can be localised in one place.
- **When:** the first time a Portal level starts, normally 201.
  - It stays about **1.8 s**, then play starts by itself. A tap skips it.
  - Board taps wait while it is open.
- **Saved:** `tips_seen` gets `intro_portal` the moment the card opens. It survives a reload and is never shown again.
  - The save format is unchanged: `tips_seen` already exists.
- **Not retroactive:** never shown to a player who already cleared 201 (`GameManager.MECHANIC_INTRO_FROM`).
- **Never over the title:** a player standing on 201 behind the title sees it after CONTINUE.
- **Reduced motion** (`prefers-reduced-motion`): the same picture, still. It only fades in.
- **Interplay:**
  - Level 201 also has a one-line hint ("New: PORTAL. Blocks go in one A and come out the other A."), shown under the card and still there when it closes.
  - A Chapter card (on NEXT from 200) always closes before 201 starts, so the two never overlap.

## 3. Level 225 milestone

- **Short and presentation-only:**
  - gold level label
  - "MILESTONE · LEVEL 225" banner
  - two bursts and a MILESTONE stamp
  - the milestone sound
  - a "MILESTONE CLEARED!" card
- **Not a finale:** no GRAND MASTER text, no Master music or theme change.
- **Configured as** `chapters.json` → `celebration_levels: {"225": "short"}`, read by `Chapters.celebration_tier()`.
  - 225 is deliberately **not** in `milestone_levels`. That list pays the one-time `milestone_clear` bonus (120 coins) and changes music / theme for 125 / 150 / 175.
  - So 225 pays only the normal level reward. Economy values are unchanged.
- **Chapter 23 at 225:** Chapter 23 is levels 221–230, so it is not complete there.
  - `Economy.is_chapter_cleared()` now requires the whole Chapter to exist. No Chapter-complete card or bonus fires at 225.
  - Chapters 1–22 are full, so nothing changes for them.
- 225 is the last level for now; its card says PLAY AGAIN, as 200 did before.

## 4. The levels

**Waves:** challenge → relief → mastery. Breathers: 209, 215, 220.
- **Learn** 201–205: portal only; 205 adds a single spinner for its first real decision.
- **Apply** 206–215
- **Master / interact** 216–224: at most **two** older mechanic families per level, never a stack.
- **Milestone** 225

**Built by** `tools/generate_portal_arc.gd`:
- Per level there is a spec: size, blocks, pairs, which older mechanic, a difficulty band, and the level's **idea** as a solver-checkable need.
- Boards are found by hill climbing. A board is accepted only if it passes every campaign rule (the verifier's own functions), the armor audit and the similarity rule.
- 225 grows out of an earlier arc board and must beat every arc level by difficulty and structural difficulty.

**Metrics:**
- *diff* = campaign difficulty score; *struct* = structural difficulty (`LevelGenerator.structural_difficulty`)
- *start* = legal moves at the start; *depth* = dependency depth; *dec* = decision points; *len* = solution length
- *pm* = portal moves in the solver's solution
- *impact* = how much the portal adds: difficulty with portals minus difficulty with each portal cell made empty. **ESS** = unsolvable without the portals.

| # | Name | Idea (checked) | Mechanics | Size | blk | start | depth | dec | len | pm | impact | diff | struct | S/G |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 201 | First Portal | first portal: one chain that must use it | portal | 5×5 | 6 | 1 | 6 | 0 | 6 | 2 | ESS | 6.0 | 5.4 | – |
| 202 | Same Way Out | direction is kept: portal moves in two directions | portal | 5×5 | 8 | 1 | 8 | 0 | 8 | 5 | ESS | 7.5 | 6.7 | – |
| 203 | Far Side | blocked exit: a lane blocked on the far side of the portal | portal | 5×5 | 9 | 1 | 9 | 0 | 9 | 3 | ESS | 8.2 | 7.3 | – |
| 204 | Take Turns | order: two blocks share one portal, one waits for the other | portal | 5×6 | 10 | 1 | 10 | 0 | 10 | 2 | ESS | 9.0 | 8.0 | – |
| 205 | Through and Back | first real puzzle: both portal cells used, first decisions | portal + 1 spinner | 6×6 | 12 | 2 | 8 | 2 | 12 | 5 | ESS | 11.9 | 10.2 | – |
| 206 | Far Wall | remote dependency: 2+ portal lanes blocked far away at the start | portal + spinners | 6×6 | 14 | 2 | 9 | 10 | 14 | 4 | ESS | 29.0 | 26.1 | S |
| 207 | Turning Door | a spinner leaves through the portal | portal + spinners | 6×6 | 14 | 2 | 13 | 10 | 14 | 7 | 11.1 | 31.9 | 29.5 | – |
| 208 | Unseen Exit | a hidden arrow leaves through the portal (fair mystery) | portal + mystery + spinners | 6×6 | 14 | 2 | 11 | 11 | 14 | 5 | ESS | 32.8 | 29.2 | G |
| 209 | Open Doors | **breather** | portal + spinners | 6×6 | 13 | 2 | 11 | 7 | 13 | 2 | 16.6 | 24.8 | 22.6 | S |
| 210 | Both Sides | two-sided: traffic through both portal cells | portal + spinners | 6×6 | 15 | 2 | 10 | 13 | 15 | 3 | 26.3 | 36.5 | 33.5 | S |
| 211 | Locked Passage | a locked block / its key goes through the portal | portal + lock + spinners | 6×6 | 17 | 2 | 10 | 14 | 17 | 3 | 5.8 | 39.4 | 35.5 | G |
| 212 | Counterturn | counter-clockwise / alternating spinner through the portal | portal + ccw / alt spinners | 6×6 | 15 | 2 | 11 | 13 | 15 | 5 | 2.5 | 41.1 | 36.9 | S |
| 213 | Twin Doors | first level with **two pairs**, both used | 2 portal pairs + spinners | 6×6 | 17 | 2 | 11 | 14 | 17 | 7 | ESS | 43.4 | 39.7 | SG |
| 214 | Which Way First | choice / order: a losing portal move on the way, shared portal | portal + spinners | 6×7 | 19 | 2 | 12 | 17 | 19 | 3 | 4.2 | 46.2 | 42.9 | – |
| 215 | Easy Passage | **breather** (two pairs) | 2 pairs + spinners | 6×6 | 15 | 2 | 8 | 13 | 15 | 6 | ESS | 36.0 | 33.5 | S |
| 216 | Mirror Door | switch: the switch / flipped arrow uses the portal | portal + switch + spinners | 6×7 | 18 | 2 | 14 | 12 | 18 | 2 | 1.1 | 47.9 | 43.7 | – |
| 217 | Chain Door | gate: a portal lane is closed by a Chain Gate | portal + gate + spinners | 6×7 | 18 | 2 | 14 | 16 | 18 | 5 | ESS | 46.9 | 41.7 | S |
| 218 | Shell Shot | armor: a ram through the portal cracks the shell | portal + armor + spinners | 6×7 | 19 | 2 | 14 | 16 | 20 | 5 | ESS | 46.7 | 42.1 | – |
| 219 | Long Way Round | multi-step dependency: deep chain, remote blocks | portal + spinners | 7×7 | 21 | 2 | 14 | 19 | 21 | 6 | ESS | 52.5 | 47.9 | SG |
| 220 | Clear Flow | **breather / flow**: many portal moves, two pairs | 2 pairs + spinners | 6×7 | 17 | 2 | 15 | 13 | 17 | 6 | 16.7 | 39.8 | 36.6 | – |
| 221 | Crossroads | advanced: two pairs, all four portal cells entered | 2 pairs + spinners | 7×7 | 23 | 2 | 15 | 18 | 23 | 8 | ESS | 54.2 | 49.4 | S |
| 222 | Old Friends | two older mechanics: switch + gate, both meet the portal | portal + switch + gate | 7×7 | 20 | 2 | 11 | 16 | 20 | 5 | ESS | 56.6 | 51.8 | G |
| 223 | False Door | deceptive: a portal move open at the start loses | portal + spinners | 7×7 | 23 | 2 | 14 | 18 | 23 | 6 | ESS | 54.2 | 49.4 | – |
| 224 | Threshold | pre-milestone, two pairs (stays below 225) | 2 pairs + spinners | 7×7 | 23 | 1 | 17 | 19 | 23 | 5 | ESS | 57.8 | 53.0 | S |
| 225 | The Gateway | **milestone**: two pairs both ways; hard by reasoning | 2 pairs + spinners only | 7×7 | 25 | 1 | 16 | 21 | 25 | 6 | ESS | **67.7** | **62.7** | GS |

**Chapter averages** (each era starts its own curve):
- Chapter 21: 19.8 (the lessons pull it down on purpose, as Chapter 11 did at 17.3)
- Chapter 22: 44.0
- Chapter 23 (221–225): 58.1

**225 is the hardest arc level** (difficulty 67.7 vs 57.8 for 224; structural 62.7 vs 53.0):
- It uses only portals and clockwise spinners.
- All four portal cells are entered, the portals are essential, and losing portal moves exist along the way.

**Silver / Gold** (`LevelGenerator.assign_reward_blocks`, now portal-aware):
- Chapter 21: 3 S, 1 G. As in Chapter 11, the lessons have none.
- Chapter 22: 5 S, 3 G.
- Chapter 23 so far: 3 S, 2 G.
- Values and `from_level` rules are unchanged; never on armored or hidden blocks, never the last block.

## 5. Verification

**Campaign verifier.** The arc's rules are in `tools/verify_levels.gd`:
- portals only from 201
- every arc level uses a portal in its solution
- the portal is not decoration (impact ≥ 1.0), except on the breathers
- the lessons 201–205 need the portal, and 201–204 use nothing else
- at most two older mechanic families per level
- 225 is the hardest arc level by both measures

On top of all the existing rules (61+ shape, decorative checks, mystery fairness, armor safety, similarity, Chapter curve, rewards).

**No-change proof:**
- `tools/classic_golden.gd -- --to=200` is byte-identical before and after: sha256 `1f2d2e72…`. It dumps each level's solution, analysis, SHOW A MOVE and every move state.
- The PORTAL and SEQUENCE lab dumps (`tools/mechlab_golden.gd`) are identical.
- The `verify_levels` lines for 1–200 are identical.

**`data/classic_board_keys.json` is unchanged:** `tools/classic_board_keys.gd` skips portal levels, because a Friend board can never have a portal.

**Checks:**
- `tools/PortalProdCheck.tscn`: data, economy, the intro (once / saved / reload / not retroactive / tap / reduced motion), a blocked portal tap, a portal escape, Undo, Restart, SHOW A MOVE and the Hammer on 201, Level Select, the 225 celebration and coins.
- `tools/web_portal_arc_test.mjs`: the exported game in Chromium at iPhone size.
- The Playtest now plays all 225 levels by real taps.

## 6. Known limitations

- **Found with solver help:** boards were picked by a solver-aided search, and the solver proxies have not predicted human ratings well (tests 1–3). The difficulty curve is a proxy.
- **Short lessons:** 201–204 are short linear chains (no decision points: plain arrows and portals have no traps). Their job is to show the rule.
- **Minor portal roles:**
  - In 216 the portal's measured impact is small (1.1, over the 1.0 bar). The switch is the main idea there.
  - In 212 it is 2.5, in 214 it is 4.2.
- **Spinners everywhere from 206:** only spinners and switches create decision points (escapes never close anything), and the late-game rules ask for at least 4. So every level from 206 except 222 (switch + gate) has spinners.
- **225 is the end of the campaign for now:** after it, PLAY AGAIN goes to Level 1, as at 200 before.
- **Returning players who already finished 200:** CONTINUE keeps their last played level, as before. 201 is unlocked in Level Select, and NEXT on 200 leads there. No save migration was added.
- **Chapter 23's chest:** its tiers need 20 / 25 / 30 stars, more than its 5 current levels can give, until 226–230 exist.
