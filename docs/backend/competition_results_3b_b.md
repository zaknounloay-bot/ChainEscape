# Real-player results: Phase 3B-B (backend foundation, not deployed)

**Status:** local commits only. Nothing is deployed to Supabase, and competition is **off in the player (production) build**. The QA build sends results to the server's `qa` pool. No percentile UI.

## Pieces

| Piece | File |
|---|---|
| Migration (additive) | `supabase/migrations/20261014120000_ce_competition_results.sql` |
| Fingerprint seed in the migration | `tools/competition_migration.mjs` (`--check` verifies it against `data/level_fingerprints.json`) |
| Edge Function v5 | `supabase/functions/chain-escape-api/index.ts` (`submit_result`, `level_standing`) |
| Game client | `scripts/social/competition.gd`; `PlayerProgress` (`comp_secret`, `comp_pending`, `comp_sent`); `BuildFlags.competition()`; `SocialApi.post_action()` |
| Tests | `tools/competition_contract_test.mjs`, `tools/CompetitionCheck.tscn`, `tools/competition_e2e.sh` |

## Database

- **`ce_level_fingerprints`** `(level, fingerprint, active)`: the 300 frozen levels. A result's `(level, fingerprint)` must be an active row (foreign key + function check). If a level ever changes, its new fingerprint gets a new row and the old results stay apart.
- **`ce_comp_players`** `(pool, player_id, secret_hash, created_at)`: the anonymous competitor. The id is the game's random UUID (Phase 3A); `secret_hash` is the SHA-256 of a random 32-byte secret the game made. The first submission claims the id.
- **`ce_level_results`** `(pool, level, fingerprint, player_id, time_ms, diag, created_at, updated_at)`:
  - Primary key `(pool, level, fingerprint, player_id)`: one best per player per level, so at most 300 rows per player.
  - `time_ms` between 300 and 21,600,000 (6 h).
  - `diag` (timing diagnostics) only in the `qa` pool.
- **Access:**
  - RLS is on for all three tables, with no policies.
  - Explicit `REVOKE` from `anon` and `authenticated`.
  - The two functions can be executed by `service_role` only.
  - The public key can neither read nor write any of it; only the Edge Function can (tested with Supabase's default grants in place).

## Functions (atomic)

**`ce_submit_result(pool, level, fingerprint, player, secret_hash, time_ms, diag, max_new_players)`**

1. Check the pool, that the level/fingerprint pair is active, and the time range.
2. Claim the player: `INSERT … ON CONFLICT DO NOTHING`, then read back the stored hash. Of concurrent first submissions, exactly one secret wins; the others get `wrong_secret`.
3. If the hash doesn't match: `wrong_secret`. Nothing is written.
4. Upsert the result, lowering only: `ON CONFLICT DO UPDATE … WHERE excluded.time_ms < stored`.
5. Return `{status, improved, best_ms, n, faster}`.
6. New competitors per pool are capped per hour (`max_new_players`).

**`ce_level_standing(pool, level, fingerprint, player, secret_hash)`** is read-only: the stored best, `n` and `faster`.

## Edge Function v5

Two POST actions are routed **before** challenge CREATE. CREATE bodies never carry `action`, so challenge requests are unchanged (Friend Challenge contract test: 43/43 on v5).

```
{action: "submit_result", pool, player_id, secret, level, fingerprint, time_ms, diag?}
  -> 200 {ok, improved, best_ms, percentile}
{action: "level_standing", pool, player_id, secret, level, fingerprint}
  -> 200 {ok, best_ms, percentile} | {ok, none: true}
errors: 400 invalid_level / invalid_fingerprint / invalid_time / invalid_player / invalid_secret
        403 wrong_secret / prod_closed / origin_not_allowed / invalid_pool / qa_closed
        429 busy        500 database_error
```

- The **player count is never returned**, only the percentile (or `null`).
- **Display names are never sent.**
- The secret travels over HTTPS; the database stores only its SHA-256.

## Percentile

**TOP X% = round(100 × (players strictly faster + 1) / players)**, kept between 1 and 100.

- Times are compared in milliseconds.
- **Ties:** equal times share the better place.
- **Rounding:** normal rounding, .5 up.
- **Fewer than 5 players:** `null`; the game shows nothing.
- Every player gets a real value, the slowest included (TOP 100%).

| Players (best times) | Results |
|---|---|
| 10.2 / 12.0 / 12.0 / 15.0 / 20.0 s | TOP 20 / 40 / 40 / 80 / 100 % |
| 8 players, 1…8 s | TOP 13 / 25 / 38 / 50 / 63 / 75 / 88 / 100 % |
| The slowest of those 8 replays to 0.999 s | TOP 13 %, and the previous fastest becomes TOP 25 % |

## QA / Production separation

What actually keeps the two apart, strongest first:

1. **Production is closed on the server by default.** `CE_PROD_POOL` is unset, so every "prod" request is refused (`403 prod_closed`).
2. **Opening Production takes two settings.** `CE_PROD_POOL=open` alone keeps it closed, and the server logs a warning. `CE_PROD_ORIGINS` must also be set (e.g. `*.itch.zone`, or `*` for any origin, which is an explicit choice). One forgotten setting can never leave Production wide open.
3. **The builds are hard-wired.**
   - The QA build always asks for `qa`, compiled in, whatever site serves it.
   - Dev builds have competition off.
   - The player build has competition off until a separate approved release.
4. **The data is separate in the database.** Every player, secret and result row carries its pool in the primary key. A QA id, secret or time can never appear in, overwrite, or be counted in Production. The new-player cap is per pool, so QA traffic cannot use up Production's.

**What the Origin check is not:**
- It is **not authentication.** Browsers set the Origin header honestly, so it stops other web pages from writing Production results. Any script outside a browser can send any Origin.
- Player ownership is the per-player secret, not the Origin.
- For this casual MVP that is enough: someone determined can submit their own scripted times (as in any client-timed game), but cannot touch another player's results, and QA traffic cannot reach Production by accident.

**Opening Production later (after approval):**
1. Ship a player build with competition on, so it asks for `prod`.
2. Edge Function secrets: set `CE_PROD_ORIGINS` to the real itch.io origin(s), then set `CE_PROD_POOL=open`. A refused origin is logged as `prod pool: origin not allowed: "<host>"`, which shows the exact host to add.
3. Verify one real Production clear lands in `pool = 'prod'`.
4. **To close Production again:** unset `CE_PROD_POOL`. Results stop, nothing is deleted, and clients keep their unsent results queued.

## Identity

- The **local UUID** (Phase 3A) is just a random name for this save; anyone could type it.
- **The secret** is made once on the device (`[profile] secret`, only where competition is on) and is what proves ownership:
  - the server keeps its hash from the first submission;
  - someone else using the same id with another secret gets `wrong_secret`, and nothing is overwritten.
- No login, no password, no account.
- **Backup / restore:** the code carries the id **and** the secret.
  - A restore that adopts the player keeps submitting as them.
  - Another player's code on a save with progress brings no foreign secret or results.
  - The same player from another device merges to the faster time of each level.
- **Limitations:**
  - A device that lost its secret but kept its id (e.g. restored from a pre-3B backup made before the secret existed) gets `wrong_secret`; its results stop being sent (`locked`), and play is unaffected.
  - Two devices restored from one code are one competitor. That's fine: one best per level.

## Client behaviour (QA build only for now)

- **Queueing:**
  - A cleared level is queued only if it beats this player's sent or queued time for that level. Only attempts finished while competition is on count, so older Personal Bests are never sent (no backfill).
  - Hints, Undo and Hammer are allowed. The time is the shown time (AttemptTimer); the Personal Best logic is untouched.
- **Sending:**
  - In the background after the clear, at start, and on a backoff timer (30 s doubling to 10 min). It never blocks the card or NEXT.
  - The queue is saved, so it survives a closed tab or no network.
- **Answers:**
  - Acknowledged: the result is recorded as sent.
  - `invalid_*`: dropped.
  - `wrong_secret`: dropped, and sending stops.
  - Network, timeout, 5xx, 429, pool closed, or a server without results (v4): kept for later.
- **Diagnostics** (`discarded_ms`, `capped_frames`, `longest_frame_ms`, `start_frame_ms`) are sent and stored in the QA pool only. **Nothing is enforced on them yet.**
- **QA build note:** until v5 is deployed, its clears reach the deployed v4, which answers 400 `invalid_challenge_type` and creates nothing. The client keeps them queued.

## Tests (local)

| Test | Result |
|---|---|
| `tools/competition_contract_test.mjs`: real Edge Function source → real migration in PostgreSQL 16, Supabase-like roles and grants. Covers first / slower / faster / duplicate, wrong secret, 16 malformed or impossible inputs, 5-player and 8-player percentiles, ties, rounding, replay, standings, 20 concurrent submissions, 10 concurrent first claims, anon/authenticated denied, prod closed / origin / QA closed, isolation, busy, row bound | **55/55** |
| `tools/backend_contract_test.mjs --edge=…index.ts` (Friend Challenge on v5) | **43/43** |
| `tools/CompetitionCheck.tscn`: off by default, queue rules, no backfill, offline + reload + retry, error classes, QA-only diagnostics, merge / backup, the real game | **37/37** |
| `tools/competition_e2e.sh`: game client → real HTTP → Edge Function → PostgreSQL | **40/40** |

## Cost and volume (Supabase free tier)

- **Requests:** one per new competition best (a clear that beats the player's sent time), plus retries. Replays that don't improve send nothing.
  - 1,000 daily players × ~20 improving clears = ~20k invocations/day, ~600k/month. That is around the free tier's 500k/month; at that scale the Pro plan (2M included) applies.
  - Per call: one function, two to three indexed queries.
- **Storage:** a result row is about 120 bytes with index. 10k players × 50 levels = 500k rows, about 60–80 MB.
- **Percentile query:** an index range count on `(pool, level, fingerprint, time_ms)`, fast up to hundreds of thousands of rows per level.

## Risks and limitations

- **Not cheat-proof.** A determined person can script submissions with their own id and secret: plausible fast times within the 300 ms floor, or many ids (capped per hour).
- **New-player cap:** an emergency circuit breaker, not a growth limit.
  - **Default 10,000 new competitors per hour per pool** (`CE_MAX_NEW_PLAYERS_PER_HOUR`; `0` = off), far above organic traffic for a casual web game.
  - A refused player loses nothing: the client keeps the result queued and retries (30 s up to 10 min), so it is accepted once the hour's count drops.
  - Every refusal is logged as a warning (`new-player cap reached`), so it is never silent.
  - **If it triggers in organic growth:** raise the value or set `0`. No redeploy is needed (secrets apply on the next call).
  - **If it triggers under a flood:** lower it, or close the pool.
- **Timing threshold:** no dropped-time rule yet. Collect QA diagnostics on real iPhones first.
- **Origin check:** stops browsers on other sites, not forged requests.
- **Lost secret:** a lost secret with a kept id is locked out (see Identity).

## Deployment steps (when approved; nothing done yet)

1. **Migration:** Supabase dashboard → SQL Editor → run `supabase/migrations/20261014120000_ce_competition_results.sql` (or `supabase db push`). It is additive and idempotent. Check: `select count(*) from ce_level_fingerprints` = 300.
2. **Edge Function secrets** (Dashboard → Edge Functions → Secrets): leave `CE_PROD_POOL` and `CE_PROD_ORIGINS` **unset** (Production closed). `CE_MAX_NEW_PLAYERS_PER_HOUR` can stay unset (10,000).
3. **Deploy:** `supabase functions deploy chain-escape-api --project-ref ydsippgwwdzwupbyrpfw --no-verify-jwt` ("Verify JWT" OFF, as before).
4. **Verify:**
   - `node tools/backend_contract_test.mjs <API_URL>` (Friend Challenge, 43/43).
   - A QA-pool `submit_result` with a test id.
   - The health check reports version 5.
5. **Rollback:** redeploy the previous function source (`git show 450df51:supabase/functions/chain-escape-api/index.ts`). The new tables are harmless; they can stay or be dropped.

## Real-iPhone QA plan (QA build, `qa` pool)

1. Play 5–10 levels normally. Clears are queued and acknowledged (check the `ce_level_results` rows for the QA id).
2. Airplane mode: clear a level, then close Safari. Reopen online: the queued result is sent.
3. Background the app mid-level a few times. Check `diag.discarded_ms` / `start_frame_ms` in the rows; that is the data for the eligibility threshold.
4. Use Hints, Undo and Hammer: the results are still accepted.
5. Have 5 testers (5 devices or QA saves) clear the same level, and check the percentile in the response with the formula above.
6. Backup on one device, restore on another: the same competitor continues; no `wrong_secret`.
7. Confirm card, NEXT, audio and timing behave exactly as before, online and offline.
