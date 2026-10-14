#!/usr/bin/env bash
# REAL-PLAYER RESULTS end to end (Phase 3B-B): the GAME client (Godot,
# headless, real HTTPRequest) -> the REAL Edge Function source under Deno ->
# the REAL migration in a local PostgreSQL (fresh database, dropped after).
#   GODOT=<godot> DENO=<deno> CE_PG_ADMIN=postgresql://postgres@127.0.0.1:54329/postgres \
#     bash tools/competition_e2e.sh
set -euo pipefail
cd "$(dirname "$0")/.."
ADMIN="${CE_PG_ADMIN:-postgresql://postgres@127.0.0.1:54329/postgres}"
DB="ce_e2e_$(date +%s)"
PG="${ADMIN%/*}/$DB"
psql -X -q -v ON_ERROR_STOP=1 "$ADMIN" -c "create database $DB"
psql -X -q -v ON_ERROR_STOP=1 "$PG" <<'SQL'
do $$ begin
  if not exists (select from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;
grant usage on schema public to anon, authenticated, service_role;
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
SQL
psql -X -q -v ON_ERROR_STOP=1 "$PG" -f supabase/migrations/20261014120000_ce_competition_results.sql
SUPABASE_URL=https://fake.supabase.test SUPABASE_SERVICE_ROLE_KEY=local-test-only CE_FAKE_PG="$PG" \
  "${DENO:-deno}" run --quiet --allow-net --allow-env --allow-read --allow-run=psql \
  --import-map tools/edge_harness/import_map.json supabase/functions/chain-escape-api/index.ts &
SERVER=$!
for i in $(seq 1 120); do curl -s -o /dev/null http://127.0.0.1:8000/ && break; sleep 0.25; done
set +e
CE_E2E_API=http://127.0.0.1:8000/ timeout 900 "${GODOT:-godot}" --headless --path . res://tools/CompetitionCheck.tscn 2>&1 | grep -E "FAIL|checks passed|PASSED|FAILED"
STATUS=${PIPESTATUS[0]}
echo "rows in ce_level_results (level 12, qa): $(psql -X -At "$PG" -c "select count(*) from ce_level_results where pool = 'qa' and level = 12")"
echo "diagnostics stored (qa): $(psql -X -At "$PG" -c "select count(*) from ce_level_results where diag is not null")"
kill $SERVER
wait $SERVER 2>/dev/null
psql -X -q "$ADMIN" -c "drop database $DB with (force)"
exit $STATUS
