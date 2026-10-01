# chain-escape-api v4 — Challenge a Friend phase 2

| File | What it is |
|---|---|
| `supabase/functions/chain-escape-api/index.ts` | **The complete replacement** (version 4). Paste it as the function's `index.ts`. |
| `docs/backend/chain-escape-api/index.v3.deployed.ts` | The currently deployed version 3, verbatim: the reference and the rollback copy. |
| `tools/backend_contract_test.mjs` | Contract test: the mock, a local run of either source file, or the real URL. |
| `tools/edge_harness/` | A local stand-in for `supabase-js` (in-memory table and bucket), so the real source file runs under Deno with no credentials. |

## What version 4 changes (and what it keeps)

- **Same** as v3 for `photo_message_reveal`:
  - checks, in the same order, with the same error codes
  - the payload `{message, media: {kind, path, content_type} | null}`
  - the Storage upload, the orphan cleanup and the signed URL (1 h)
  - the `201` response
- **Same** shared puzzle checks for both types: format, `v: 1`, `rules: 1`, rows/cols 2–10, map row count, rows as strings of at most 500 characters.
- **New:** `challenge_type: "friend_challenge"`:
  - difficulty `easy | medium | hard | very_hard`; `very_hard` stays refused for photo challenges
  - stricter board checks: every row has exactly `cols` cells, every cell is `.`, a plain arrow (`R>`) or a clockwise spinner (`B^@`), and there is at least one block
  - no `message`, `image_base64` or `image_type` (refused with `unexpected_reveal_content`)
  - optional boolean `surprise_me` (otherwise `invalid_surprise_me`)
  - stored payload `{}` or `{"surprise_me": true}`, no Storage call
- **READ:**
  - media is signed only for `photo_message_reveal`, so a friend challenge always returns `media_url: null`
  - a non-UUID id now returns `404 challenge_not_found` instead of a `500` from the uuid column
  - everything else is unchanged; old rows read exactly as before
- **Health:** `version: 4` (was 3), so you can see which version is live.
- Secrets still come only from the function's environment (`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`). Keep **Verify JWT off**.

**Evidence** (local, Deno 2.9 with the stand-in client):
- v4 passes the contract test **42/42**.
- v3 passes all of its Photo / Message and validation checks but fails the friend ones (`invalid_challenge_type`), shows version 3, and returns `500` on a malformed id. This is exactly the intended difference.
- `deno check` and `deno lint` are clean on v4.
- **Not covered locally:** the real `supabase-js`, Storage, the real table constraints and RLS. Step 4 checks those against the real deployment.

## Exact Supabase steps

### 1. Database: check the constraints (read-only)

Supabase Dashboard → **SQL Editor** → New query:

```sql
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.shared_challenges'::regclass and contype = 'c';
```

- **No row mentions `challenge_type` or `difficulty`:** nothing to do. Go to step 2.
- **A constraint limits `challenge_type` (e.g. `= 'photo_message_reveal'`) or `difficulty` (e.g. `in ('easy','medium','hard')`):** run the following, putting the real names from the output where it says `<…>`. It only widens the allowed values; existing rows are untouched and stay valid.

```sql
begin;
alter table public.shared_challenges drop constraint <the challenge_type constraint>;
alter table public.shared_challenges drop constraint <the difficulty constraint>;
alter table public.shared_challenges add constraint shared_challenges_type_difficulty_check check (
  (challenge_type = 'photo_message_reveal' and difficulty in ('easy', 'medium', 'hard'))
  or (challenge_type = 'friend_challenge' and difficulty in ('easy', 'medium', 'hard', 'very_hard')));
commit;
```

- Do not change RLS, policies, grants or the `challenge-media` bucket.

### 2. Keep a copy of version 3

Dashboard → **Edge Functions** → `chain-escape-api` → **Code**. Its `index.ts` should match `docs/backend/chain-escape-api/index.v3.deployed.ts`, which is the rollback copy. Note the current deployment / version number shown there.

### 3. Deploy version 4

1. In the same **Code** editor, select all of `index.ts` and replace it with the full contents of `supabase/functions/chain-escape-api/index.ts`.
2. Click **Deploy**.
3. In the function's **Details / Settings**, confirm **Verify JWT (Enforce JWT verification)** is still **OFF**. No secrets, environment variables or other settings change.

(CLI alternative, from the repository root: `supabase functions deploy chain-escape-api --project-ref ydsippgwwdzwupbyrpfw --no-verify-jwt`.)

### 4. Verify the live function

1. Open `https://ydsippgwwdzwupbyrpfw.supabase.co/functions/v1/chain-escape-api` in a browser. Expect `{"ok":true,"service":"chain-escape-api","version":4}`.
2. From a computer with Node 18+ and this repository, using an **existing** Photo / Message link's id for `--old`:

   ```bash
   node tools/backend_contract_test.mjs https://ydsippgwwdzwupbyrpfw.supabase.co/functions/v1/chain-escape-api \
     --old=5a264212-44fb-499b-9e05-59c738ed98b2 --with-image
   ```

   Expect `BACKEND CONTRACT TEST (...): PASSED (42/42)`.

   It creates 7 small test challenges (5 friend, 2 photo, one with a tiny test JPEG) that expire after 30 days like any other. To review or remove them in the SQL Editor:

   ```sql
   select id, challenge_type, difficulty, created_at from public.shared_challenges
   order by created_at desc limit 10;
   ```

3. On the iPhone, open an existing Photo / Message link and create a new photo challenge as usual. Both must behave exactly as before.

### Rollback

Paste `docs/backend/chain-escape-api/index.v3.deployed.ts` back into the Code editor and deploy. The step 1 constraint change (if you made it) only widens the allowed values and can stay.

## Results (future, not built): one challenge, many independent results

The challenge row is the immutable shared puzzle; it never stores a result. Results will be separate rows pointing at it. This table is **not created** in phase 2:

```sql
-- NOT APPLIED. Intended shape for the results phase.
create table public.challenge_results (
  id            uuid primary key default gen_random_uuid(),     -- result_id
  challenge_id  uuid not null references public.shared_challenges(id) on delete cascade,
  player_key    text not null,       -- anonymous random id per device / browser (no PII)
  user_id       uuid null,           -- reserved for future accounts
  started_at    timestamptz not null,
  completed_at  timestamptz null,
  duration_ms   integer null check (duration_ms >= 0),
  moves         integer null,
  hints_used    smallint not null default 0,
  undos_used    smallint not null default 0,
  state         text not null check (state in ('started', 'completed', 'abandoned')),
  client_version text null,
  created_at    timestamptz not null default now()
);
create index on public.challenge_results (challenge_id, duration_ms) where state = 'completed';
alter table public.challenge_results enable row level security;  -- no anon policies: Edge Function only
```

- Many results per `challenge_id`, written and read only through the Edge Function, like challenges.
- `player_key` is anonymous; accounts can be linked later through `user_id` without breaking anonymous play.
- "Faster than X%" will compare completed rows per challenge (or per difficulty). The population and minimum sample are to be defined, and nothing is computed yet.

**Why the table is not created now:** nothing writes results yet. Adding it later is purely additive (a new table with a foreign key to `shared_challenges.id`) and changes no existing table, id or link.

## Known limitations (unchanged)

- **Private-by-link:** anyone with a link can READ it. Photo reveals are readable before solving (MVP limitation); friend challenges hold nothing secret.
- **No rate limiting** on CREATE / READ.
- **Expired rows and media are not cleaned up automatically.** READ already hides expired rows (404).
- **Server validation is structural** (format, versions, size, map shape; for friend challenges also the cells). It does not run the Solver. The game verifies solvability before CREATE and again after READ, before anything is played.
- **Share URLs** are still tied to the itch.io build URL.
