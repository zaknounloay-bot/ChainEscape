# VERY HARD + Locked Blocks — audit and local prototype (phase 3c)

Status: **audit and prototype only**. Nothing here is used by the game.
- Production Friend challenges still accept only arrows + clockwise spinners (client, mock, Edge Function v4).
- No backend, contract or Supabase change.
- Phase 3 is **not** frozen.

## 0. Why: real-device result of `87c92db`

**Passed:**
- Social tool consistency (UNDO x3, SHOW A MOVE x2, HAMMER x2, RESTART)
- Photo / Message Hammer and Friend Hammer
- SHOW A MOVE in Classic, Photo / Message and Friend
- generation time felt completely acceptable
- immediate sharing and immediate recipient opening
- exact-board sharing

**Failed product expectation:** VERY HARD still felt easy to two real users (one solved it very quickly), even though its algorithmic metrics improved strongly (random tapper 22% → 3%).

**Conclusion:** the algorithmic difficulty metrics improved but did not predict human-perceived difficulty. That is why the existing Classic **Locked Block** was investigated, as a source of "I need to understand what must happen first".

## 1. The Classic Lock mechanic (as it exists)

1. **Locked:** a block with `lock_color` X cannot escape while **any block of colour X** remains (`BoardModel.is_locked`: `lock_color != ""` and the colour count of X > 0). Its lane may be clear; it still cannot leave.
2. **Unlock:** the last block of colour X leaves the board, by escape or by Hammer. There is no key object: the colour *is* the key.
3. **Relationship:** one colour → **every** block of that colour is a key, and it can lock **several** blocks. Unlocking is "clear the whole colour", not one key for one lock.
4. **Representation:** a map-token suffix `#<colour letter>` (`LevelManager._parse_map`): `R>#G` = red arrow right, locked while any green block remains; `B^@#Y` = blue clockwise spinner, locked by yellow. Validation: a block cannot be locked by its own colour, and hidden / armored blocks cannot be locked.
5. **Solver:** `_lock[id]` (key colour index) and `_color_count[]`. `_is_legal` refuses a locked block, `_apply` / `_undo` keep the colour counts exactly, and the search, `analyze()`, `recommend_move()` and `hammer_safe()` all see locks. **Locks are monotone:** removing blocks only ever *opens* locks, never closes one. So a lock alone can never create a trap (a wrong order never makes a board unsolvable through a lock; it can only make a block wait). Traps still come only from spinners.
6. **Serialization:** the token is part of the campaign map text. `PuzzleDefinition` stores the map verbatim and rebuilds it with `LevelManager.parse_level`, so locks round-trip exactly (checked on generated boards, see §5).
7. **PuzzleDefinition:** already supports locks technically (same parser, same `rules: 1`; locks have existed since v0.3, so no rules bump is needed). Today they are refused only by the **Friend validators** (`FriendGenerator.mechanics_ok`, used by `SocialApi` and `SharedChallenge.from_api`, and `FRIEND_CELL` in Edge Function v4).
8. **Interactions:**
   - **arrows:** a locked block still blocks lanes while it waits.
   - **clockwise spinners:** a locked spinner still turns when a neighbour leaves.
   - **SHOW A MOVE:** `recommend_move()` only considers legal moves, so it never points at a locked block (verified, §5).
   - **UNDO:** a snapshot restore recounts colours, so a lock that just opened closes again exactly (verified).
   - **RESTART:** the board is rebuilt from the PuzzleDefinition with its locks (verified).
   - **Tapping a locked block:** rattle, its key blocks pulse, buzz; in Social play this is a mistake (the chain resets, nothing else).
9. **Hammer today:** see §4.
10. **Ties to Classic state:** none. The rule lives in `BoardModel` / `Solver`; the first-time "Locked until every green block escapes" message lives in `GameManager` (Classic only). No coins, boosters, progression or save are involved.

## 2. Prototype design (local / development only)

- **Same engine:** FriendGenerator (same search), LevelGenerator's existing lock mutations (lock / unlock / re-key / recolour, from the campaign), the existing Solver, and PuzzleDefinition. There is no second engine.
- **Opt-in:** `FriendGenerator.mechanics_ok(def, d, allow_locks)` with `LOCK_TOKEN_RE` = arrows + clockwise spinners + `#<colour>`. It is used only when a benchmark sets `"allow_locks": true` through `spec_override`. The production path (the default `allow_locks = false`, SocialApi, SharedChallenge, mock, Edge Function) is unchanged and still refuses lock boards (verified).
- **Mechanics:** only arrows, clockwise spinners and locks. No CCW / alternating / pattern spinners, hidden blocks, switches, gates, armor or rewards.
- **Lock criteria** (prototype only, in `_human_gap`): at least N locks, at least M steps where a locked block has a clear lane (it *looks* free but must wait), and locks that open late in the solution on average.
- **Prototype spec "proto":** 6×6, 17–20 blocks, 4–5 spinners, 2–3 locks; the same human criteria as current VERY HARD (start ≤ 3, one-safe ≥ 4, safe choices ≤ 1.9, decisions ≥ 8, random ≤ 5%) plus locks ≥ 2, locked-free steps ≥ 4, average unlock step ≥ 6; the same 1.5 s cap (+0.5 s grace).
- Variants measured: 1 lock, 3–4 locks, and a heuristic-player criterion (§3) with and without locks.
- **Tools:**
  - `tools/lock_prototype_bench.gd` (groups A / B / C, `--proto=<name>`)
  - `tools/LockPrototypeCheck.tscn` (safety checks through the real SocialPlay)

## 3. Metrics (what each approximates)

| Metric | Approximates for a person |
|---|---|
| Free blocks at start | an easy way in |
| Depth | rounds of "this frees that" (Solver) |
| Chain (new) | longest "must leave first" chain at the start: lane blockers + key colour for a locked block (static) |
| One-safe steps | moments where exactly one move works |
| Safe choices / step | how much "tap anything free" works |
| Decision steps | steps where a wrong (spinner-turning) move exists |
| Random tapper | a player looking 0 moves ahead |
| Lookahead 2 / 3 (new, `Solver.lookahead_win_rate`) | a player avoiding dead ends visible 2 / 3 moves ahead |
| **Heuristic player 2 / 3** (new, `Solver.heuristic_win_rate`) | **a player who has understood the rules**: a move that turns no spinner can never hurt, so it plays those first and only "thinks" (2 / 3-move lookahead) when every move turns a spinner |
| Locked-free steps / lock wait / unlock step (new, `analyze()`) | moments where a tempting, free-looking block is locked; how many; how late locks open |
| Hammer: smashable locks; lookahead-2 after smashing them / after 2 random smashes | how much the free Hammer x2 bypasses |

**Key finding on the proxies:** the heuristic player wins **31–38%** of current VERY HARD boards, while the random tapper wins 2% and the lookahead player 4–6%. That matches the real-device result. Once a person sees that non-spinner moves are always safe, most of the board plays itself, and only a few forced spinner moments need thought. The random tapper and lookahead players are poor human proxies here; the heuristic player is the best one available (still unvalidated with people).

## 4. Results (60 boards per group, product time caps, every board re-measured independently)

| | A: HARD (`87c92db`) | B: VERY HARD (`87c92db`) | C: VERY HARD + Locks (proto) |
|---|---|---|---|
| Board | 6×6, 18.3 blocks, 4.0 spinners | 6×6, 18.6 blocks, 5.7 spinners | 6×6, 18.3 blocks, 4.8 spinners, **2.5 locks** |
| Free at start | 3.9 | 3.0 | 2.9 |
| Depth / chain | 11.4 / 8.3 | 12.4 / 9.4 | 11.9 / 9.1 |
| One-safe steps / safe choices | 2.9 / 1.95 | 5.0 / 1.71 | 4.9 / 1.74 |
| Decision steps | 9.6 | 11.3 | 10.3 |
| Random tapper | 10.9% | 2.2% | 2.6% |
| Lookahead 2 / 3 | 16.2% / 20.0% | 4.3% / 6.4% | 7.4% / 10.6% |
| **Heuristic player 2 / 3** | 54.6% / 60.4% | **31.1% / 37.6%** | **43.2% / 49.5%** |
| Locked-free steps / lock wait / unlock step | – | – | 10.3 / 14.1 / 11.3 |
| Met all / within tolerance | 63% / 98% | 70% / 88% | 50% / 80% |
| Time p50 / p90 / max | 1070 / 1525 / 2023 ms | 1112 / 2004 / 2019 ms | 1502 / 2004 / 2021 ms |
| Generation failures | 0 | 0 | 0 |

**Locks create the intended *situations*:** about 10 steps per board where a free-looking block is locked, with locks opening around step 11 of about 18. But they do **not** make the board harder for a rule-aware player: the heuristic player wins **more** often (43% vs 31%). A locked block simply waits; it is never risky, so it removes options without creating decisions. The generator also met its criteria less often (50% vs 70%), and the median time rose to 1.5 s.

**Other variants** (same tools; 30 boards each, except the 60-board groups above):

| Variant | Locks | Heuristic player 2 / 3 | Random tapper | Met all / within tolerance | Time p50 / p90 / max |
|---|---|---|---|---|---|
| 1 lock (`proto_1lock`) | 1.0 | 46.3% / 49.3% | 3.1% | 60% / 83% | 1049 / 2004 / 2034 ms |
| 3–4 locks (`proto_4locks`) | 3.0 | 45.1% / 56.2% | 4.0% | 26% / 53% | 1993 / 2018 / 2033 ms |
| No locks, selected by heuristic player ≤ 15%, **1.5 s** cap (`x_nolock_fast`) | 0 | 34.2% / 37.6% | 2.7% | 33% / 70% | 1519 / 2005 / 2026 ms |
| Locks, same criterion, 1.5 s cap (`x_locks_fast`) | 2.3 | 44.9% / 50.4% | 4.0% | 33% / 70% | 1502 / 2005 / 2014 ms |
| No locks, selected by heuristic player ≤ 15%, **8 s** cap (`x_nolock`) | 0 | **14.6% / 16.7%** | 1.8% | 91% / 100% | 2571 / 7086 / 8004 ms |
| Locks, same criterion, 8 s cap (`x_locks`) | 2.4 | 19.5% / 23.7% | 1.5% | 75% / 100% | 3205 / 8005 / 8032 ms |

More locks mean more waiting, not more thinking: every lock variant is easier for the heuristic player than current VERY HARD without locks, and more locks also make generation slower and less reliable. The only clearly harder result comes from **selecting** boards by the heuristic player, without locks, which needs a search budget far beyond the live 1.5 s.

## 5. Safety checks on lock boards (`tools/LockPrototypeCheck.tscn`, 72 checks passed)

Six generated lock boards, played through the real SocialPlay:
- the same seed gives the same board (deterministic)
- exact JSON round trip, Solver-verified
- only arrows / clockwise spinners / locks
- **today's production validation refuses them** (`mechanics_ok` and `SharedChallenge.from_api` → malformed)
- tapping a locked block changes nothing
- SHOW A MOVE at every step of a full solve (110 steps) never pointed at a locked or illegal block, and following it solves the board
- UNDO right after an unlock restores the lock exactly, and redoing re-opens it identically
- RESTART rebuilds the exact board with its locks
- the stored PuzzleDefinition never changes

## 6. Hammer + Locks

- **A. Existing behaviour:** Classic and the Social Hammer smash **any** block (locked blocks and key-colour blocks included) unless `Solver.hammer_safe` says the smash would make a solvable board unsolvable. Smashing the last block of a colour opens its locks. On the prototype boards, **13 of 14 locked blocks could be smashed at the start**.
- **B. Does it undermine Locks?** Yes, and it undermines VERY HARD in general. A 2-move-lookahead player goes from 7% to **43%** after smashing the locked blocks, but also from 4% to **26–30%** after two smashes of *random* safe blocks. Two free Hammers are a large part of why VERY HARD can feel easy.
- **C. Recommended rule if Locks are ever adopted:** the Hammer may **not** target a block that is currently locked. The padlock *is* the puzzle; a refused smash costs nothing, like an unsafe one, with a one-line reason. Key-colour blocks stay smashable (they are ordinary blocks), with the existing solvability protection. Independently of Locks: test **VERY HARD with HAMMER x1** (or x0), since the Hammer count matters more than the rule.

## 7. Backend changes that WOULD be required (not done)

- **Token:** widen Edge Function v4 `FRIEND_CELL` from `^(\.|[RBGYP][\^v<>](@)?)$` to `^(\.|[RBGYP][\^v<>](@)?(#[RBGYP])?)$`, optionally rejecting a lock of its own colour (`R>#R`). Ideally accept it for `very_hard` only.
- **No** schema, table, payload or `PuzzleDefinition` format change; no database migration; READ unchanged (it returns the stored puzzle as is).
- **Old challenges:** fully compatible (a strict subset of the new rule). **Photo / Message:** unaffected (separate validation).
- **Client:** the same widening in `FriendGenerator.mechanics_ok` as used by `SocialApi` (create) and `SharedChallenge.from_api` (read), plus `tools/mock_social_api.py` and the contract test.
- **Recipient reconstruction:** no change (same parser). **Risk:** a recipient on an older cached build would see "isn't available / newer version" for a lock challenge.

## 8. Readability for a recipient who never played Classic

- **What exists:** a dark veil on the block, a padlock in the **key colour** in its corner, and on tap a rattle with the key-colour blocks pulsing.
- **Self-explanatory?** Partly. "Locked" reads instantly; "locked *until every green block is gone*" does not. The pulsing keys hint at it, but in Social play the tap also counts as a mistake.
- **Recommendation if adopted:** reuse Classic's one-line first-time message on the first locked tap ("Locked until every green block escapes"), make a locked tap free (not a mistake, like Classic's free "explain" taps), and add no tutorial screen.

## 9. Assessment and recommendation

- **Do Locks materially improve planning difficulty?** Not in this form. In generated Friend boards, the Classic colour lock adds waiting rather than decisions; by the best available proxy it makes VERY HARD slightly *easier*, and it costs generation time plus a backend change. The proxies have now twice disagreed with people, so this is evidence, not proof.
- **Recommended next VERY HARD design** (no backend change; needs approval):
  1. **Select by the heuristic player.** Boards a rule-aware player rarely wins (≤ 15%, against 31–38% today) exist with arrows + clockwise spinners alone, but need about 3–8 s of search. That is too slow live, so generate them **offline** into a pool shipped with the build: verified PuzzleDefinitions, picked at random and varied per challenge by symmetry and colour permutation. Each challenge still stores its exact board, so the exact-board architecture and sharing are unchanged.
  2. **VERY HARD Hammer x1** (test x1 vs x2 on real devices).
  3. Before (1) ships, a quick human check: a **development-only local page** (no backend, no sharing) that serves a few boards of each kind (current VERY HARD, heuristic-selected, lock prototype) for the two testers. This is cheap evidence that the new proxy predicts people better.
- **Locks alone are not sufficient**, and not obviously helpful. **Counter-clockwise spinners** are the more promising mechanic to consider later. The heuristic player does not model the mental rotation a person must do, and mixing CW / CCW makes every spinner move a real simulation problem; this is human load that the generated boards currently lack. They also need the backend token widened (`@-`), so they would be a separate, approved experiment.

## 10. Risks

- **Proxy risk:** the heuristic player is a model, not a person. Validate it before building on it.
- **Pool approach:** the board pool lives in the client. Variety comes from size × symmetry × colours; repeats across users are possible (acceptable for a challenge you send).
- **Locks in production:** a backend change, the old-build "isn't available" risk, readability work, the Hammer rule change, and slower generation, for no measured gain.
