# chain-escape-api — Challenge a Friend phase 2 backend change

This makes `friend_challenge` a real challenge type on the existing Supabase backend, next to `photo_message_reveal`. It reuses the same table, Edge Function, links and expiry, and has no new sharing system.

**Status:** prepared and verified against the local mock (`tools/mock_social_api.py`, which implements exactly these rules). It is **not deployed**: the build sandbox cannot reach Supabase, and the Edge Function source is not in this repository. Apply it in the Supabase dashboard / CLI, then verify with the contract test (step 4).

## 0. Before changing anything

1. Copy the currently deployed `chain-escape-api` source (Dashboard → Edge Functions → chain-escape-api → Code, or `supabase functions download chain-escape-api`) and keep it as the rollback copy.
2. Note its current version number.
3. Run the schema inspection in step 1 and keep its output.

## 1. Database: inspect, then (only if needed) widen two CHECK constraints

No new columns and no migration of existing rows. A friend challenge's data fits the existing columns: `challenge_type`, `difficulty`, `puzzle` (jsonb) and `payload` (jsonb: `{}` or `{"surprise_me": true}`).

Inspect the constraints on the table:

```sql
select conname, pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'public.shared_challenges'::regclass and contype = 'c';
```

Only if a CHECK constraint limits `challenge_type` or `difficulty`, replace it. Use the real constraint names from the output above; the names below are examples. The new constraints only widen the allowed values, so every existing row stays valid. `very_hard` is accepted for `friend_challenge` only.

```sql
begin;
alter table public.shared_challenges drop constraint if exists shared_challenges_challenge_type_check;
alter table public.shared_challenges drop constraint if exists shared_challenges_difficulty_check;
alter table public.shared_challenges add constraint shared_challenges_challenge_type_check
  check (challenge_type in ('photo_message_reveal', 'friend_challenge'));
alter table public.shared_challenges add constraint shared_challenges_type_difficulty_check
  check ((challenge_type = 'photo_message_reveal' and difficulty in ('easy', 'medium', 'hard'))
      or (challenge_type = 'friend_challenge' and difficulty in ('easy', 'medium', 'hard', 'very_hard')));
commit;
```

- RLS, policies, grants and the private `challenge-media` bucket are **not touched**.
- If the table has no such constraints (validation lives only in the Edge Function), skip this step entirely.

## 2. Edge Function: type-aware CREATE validation

Keep every existing Photo / Message Reveal rule as it is. Add the type branch so that each type has its own rules. In TypeScript, for the function's existing CREATE handler:

```ts
const DIFFICULTIES: Record<string, string[]> = {
  photo_message_reveal: ["easy", "medium", "hard"],
  friend_challenge: ["easy", "medium", "hard", "very_hard"],
};
// Any campaign token (existing rule) / Challenge a Friend tokens only:
// a plain arrow or a clockwise spinner ("R>", "B^@").
const CELL = /^(\.|[RBGYP][\^v<>]\S*|X[A-D])$/;
const FRIEND_CELL = /^(\.|[RBGYP][\^v<>](@)?)$/;

function validatePuzzle(p: any, friend: boolean): string {
  if (!p || typeof p !== "object" || p.format !== "ce-puzzle" || p.v !== 1 || p.rules !== 1) return "invalid puzzle format";
  const { rows, cols, map } = p;
  if (!Number.isInteger(rows) || !Number.isInteger(cols) || rows < 1 || cols < 1 || rows > 12 || cols > 12) return "invalid puzzle size";
  if (!Array.isArray(map) || map.length !== rows) return "invalid puzzle map";
  let blocks = 0;
  for (const row of map) {
    const cells = typeof row === "string" ? row.split(/\s+/).filter(Boolean) : null;
    if (!cells || cells.length !== cols) return "invalid puzzle map";
    for (const c of cells) {
      if (!(friend ? FRIEND_CELL : CELL).test(c)) return "invalid puzzle map";
      if (c !== ".") blocks++;
    }
  }
  if (blocks === 0) return "invalid puzzle map";
  return "";
}

// Returns "" if valid, else a short reason (sent as a 400 error).
function validateCreate(b: any): string {
  if (!b || typeof b !== "object") return "body must be an object";
  const t = b.challenge_type;
  if (!(t in DIFFICULTIES)) return "invalid challenge_type";
  if (!DIFFICULTIES[t].includes(b.difficulty)) return "invalid difficulty";
  const pe = validatePuzzle(b.puzzle, t === "friend_challenge");
  if (pe) return pe;
  if (t === "friend_challenge") {
    if (b.message != null || b.image_base64 != null || b.image_type != null) return "friend_challenge carries no message or image";
    if ("surprise_me" in b && typeof b.surprise_me !== "boolean") return "invalid surprise_me";
    return "";
  }
  // photo_message_reveal: the EXISTING checks, unchanged (message <= 200,
  // image MIME + size, "photo or message required", ...).
  return validatePhotoMessage(b); // <- the function's current validation
}
```

When inserting:

```ts
const payload = b.challenge_type === "friend_challenge"
  ? (b.surprise_me === true ? { surprise_me: true } : {})
  : /* existing photo_message_reveal payload: { message, media } */ existingPayload;
// friend_challenge: NO storage upload at all.
// Store puzzle exactly as received (it was validated above); keep the
// existing format_version / rules_version / expires_at behaviour.
```

## 3. Edge Function: READ

- Return the stored row exactly as today: `challenge_type`, `difficulty` (the real one), `puzzle` (the exact stored PuzzleDefinition), `payload`, `expires_at`, …
- Sign a media URL **only** when `payload.media` exists, which is only for photo challenges, as now. For `friend_challenge`, return `media_url: null` (or omit it) and never call Storage.
- Old `photo_message_reveal` rows read exactly as before; nothing in READ depends on the new type.
- The client (`SharedChallenge.from_api`) validates READ data per type and refuses a friend challenge that carries a message, media or `media_url`, a non-boolean `surprise_me`, or tokens other than plain arrows / clockwise spinners.

## 4. Deploy and verify

1. Deploy the updated function (keep "Verify JWT" **off**, as today: recipients open links without logging in). No secret, service-role key or database password goes into the game or this repository.
2. From any machine with Node 18+ and this repository:

   ```bash
   node tools/backend_contract_test.mjs https://ydsippgwwdzwupbyrpfw.supabase.co/functions/v1/chain-escape-api \
     --old=5a264212-44fb-499b-9e05-59c738ed98b2 --with-image
   ```

   - It checks:
     - CREATE / READ `friend_challenge` for easy / medium / hard / very_hard with no message or image, and the exact puzzle back field for field
     - 5 READs of one id give the same puzzle
     - SURPRISE ME is stored as the real difficulty plus `payload.surprise_me = true`
     - 13 invalid requests are refused, including a missing puzzle, an unsupported difficulty, a bad version or size, a locked block, a message on a friend challenge and an unknown type
     - Photo / Message Reveal is unchanged: it still requires a photo or message, still refuses `very_hard`, and still returns a signed `media_url`
     - the pre-deployment challenge `--old` still reads
   - It creates about 10 small test challenges. They expire like any other, and you can delete them by id if preferred.
3. Expected result: `BACKEND CONTRACT TEST (...): PASSED (40/40)` (39 checks plus the `--old` one).

**Rollback:** redeploy the saved source from step 0. The constraint change in step 1 only widens the allowed values, so it can stay.

## 5. Results (future, not built): one challenge, many independent results

The challenge row is the immutable shared puzzle; it never stores a result. Results will be separate rows pointing at it:

```sql
-- NOT APPLIED. Intended shape for the results phase.
create table public.challenge_results (
  id            uuid primary key default gen_random_uuid(),     -- result_id
  challenge_id  uuid not null references public.shared_challenges(id) on delete cascade,
  player_key    text not null,       -- anonymous, per device / browser (random, no PII);
                                     -- an account id can be linked later without changing this
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

- Many results per `challenge_id` (one per recipient attempt or per `player_key`, rule to be decided), written and read only through the Edge Function with the service role, exactly like challenges.
- `player_key` is a random anonymous id the game keeps locally. It is never an email, phone number or name. Accounts can later be linked through `user_id` without breaking anonymous play.
- "Faster than X%" is then a per-challenge (or per-difficulty) comparison over completed rows. The population and minimum sample size are still to be defined, and nothing is computed yet.

**Why the table is not created now:** nothing writes results yet, and adding it later is purely additive (a new table with a foreign key to `shared_challenges.id`). Phase 2 needs no change to `shared_challenges` for it, and none of today's ids or links would change. Creating it now would add an unused surface with no access path to design or test yet.

## Known limitations (unchanged by this phase)

- **Private-by-link:** anyone with the link can READ the challenge. Friend challenges have nothing secret; photo reveals are readable before solving (documented MVP limitation).
- **No rate limiting** on CREATE / READ yet.
- **Expired-challenge / media cleanup** is not automated yet.
- **Server validation is structural:** format, version, rules, size, map shape and allowed tokens. It does not run the Solver. The client verifies solvability on CREATE and again on READ before anything is played; a full server-side solve is not equivalent and is not attempted.
- **Stable share URL:** unchanged; still tied to the itch.io build URL.
