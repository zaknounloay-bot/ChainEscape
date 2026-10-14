// REAL-PLAYER RESULTS contract test (Phase 3B-B): the REAL Edge Function
// source (supabase/functions/chain-escape-api/index.ts) under Deno, with
// tools/edge_harness/fake_supabase.ts whose rpc() runs the REAL migration's
// SQL functions in a local PostgreSQL - so tables, constraints, grants, RLS,
// the atomic upsert and concurrency are the real thing. Nothing remote.
//
//   DENO=<deno> CE_PG_ADMIN=postgresql://postgres@127.0.0.1:54329/postgres \
//     node tools/competition_contract_test.mjs
//
// A fresh database per run (dropped at the end): the Supabase roles (anon,
// authenticated, service_role) and Supabase's default grants (everything to
// all three) are set up first, so the migration's own REVOKEs are tested.
import fs from 'node:fs';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ADMIN = process.env.CE_PG_ADMIN || 'postgresql://postgres@127.0.0.1:54329/postgres';
const DENO = process.env.DENO || 'deno';
const DB = `ce_contract_${Date.now()}`;
const PG = ADMIN.replace(/\/[^/]*$/, `/${DB}`);
const MIGRATION = path.join(repo, 'supabase/migrations/20261014120000_ce_competition_results.sql');
const FP = JSON.parse(fs.readFileSync(path.join(repo, 'data/level_fingerprints.json'), 'utf8')).fingerprints;
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const psql = (sql, url = PG) => execFileSync('psql', ['-X', '-At', '-q', '-v', 'ON_ERROR_STOP=1', url, '-c', sql], { encoding: 'utf8' }).trim();
const psqlTry = (sql) => { try { return { ok: true, out: psql(sql) }; } catch (e) { return { ok: false, out: String(e.stderr || e.message) }; } };
const uuid = () => crypto.randomUUID();
const hex64 = () => [...crypto.getRandomValues(new Uint8Array(32))].map((b) => b.toString(16).padStart(2, '0')).join('');

// ---- database ----
psql(`create database ${DB}`, ADMIN);
psql(`do $$ begin
  if not exists (select from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select from pg_roles where rolname = 'service_role') then create role service_role nologin bypassrls; end if;
end $$;`);
psql(`grant usage on schema public to anon, authenticated, service_role;
  alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
  alter default privileges in schema public grant all on functions to anon, authenticated, service_role;`);
execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', PG, '-f', MIGRATION], { stdio: ['ignore', 'ignore', 'inherit'] });
execFileSync('psql', ['-X', '-q', '-v', 'ON_ERROR_STOP=1', PG, '-f', MIGRATION], { stdio: ['ignore', 'ignore', 'ignore'] });
check(psql('select count(*) from ce_level_fingerprints where active') === '300', 'migration: 300 active level fingerprints (applied twice: idempotent)');

// ---- server ----
let server = null;
async function start(env) {
  if (server) { server.kill(); await new Promise((r) => server.once('exit', r)); }
  server = spawn(DENO, ['run', '--quiet', '--allow-net', '--allow-env', '--allow-read', '--allow-run=psql',
    '--import-map', path.join(repo, 'tools/edge_harness/import_map.json'), path.join(repo, 'supabase/functions/chain-escape-api/index.ts')],
    { stdio: ['ignore', 'ignore', 'inherit'], env: { ...process.env, SUPABASE_URL: 'https://fake.supabase.test',
      SUPABASE_SERVICE_ROLE_KEY: 'local-test-only', CE_FAKE_PG: PG, ...env } });
  for (let i = 0; i < 120; i++) { try { await fetch('http://127.0.0.1:8000/'); return; } catch { await sleep(250); } }
  throw new Error('server did not start');
}
const API = 'http://127.0.0.1:8000/';
async function call(body, headers = {}) {
  const r = await fetch(API, { method: 'POST', headers: { 'Content-Type': 'application/json', ...headers }, body: JSON.stringify(body) });
  let data = null;
  try { data = await r.json(); } catch { /* not json */ }
  return { status: r.status, data };
}
const submit = (p, level, time_ms, extra = {}) => call({ action: 'submit_result', pool: 'qa', player_id: p.id, secret: p.secret,
  level, fingerprint: FP[level - 1], time_ms, ...extra });
const standing = (p, level, extra = {}) => call({ action: 'level_standing', pool: 'qa', player_id: p.id, secret: p.secret,
  level, fingerprint: FP[level - 1], ...extra });
const player = () => ({ id: uuid(), secret: hex64() });
const rows = (where) => psql(`select count(*) from ce_level_results where ${where}`);

try {
  await start({});
  const h = await (await fetch(API)).json();
  check(h.ok && h.version === 5, `health check reports version 5 (${JSON.stringify(h)})`);

  // ---- 1. first / slower / faster / duplicate ----
  const A = player();
  let r = await submit(A, 10, 20000, { diag: { discarded_ms: 0, capped_frames: 0, longest_frame_ms: 0, start_frame_ms: 1800, junk: 'x' } });
  check(r.status === 200 && r.data.ok && r.data.improved === true && r.data.best_ms === 20000 && r.data.percentile === null && !('n' in r.data),
    `first valid submission stored; no percentile below 5 players; no player count returned (${JSON.stringify(r.data)})`);
  check(psql(`select diag->>'start_frame_ms' || '/' || coalesce(diag->>'junk', '-') from ce_level_results where player_id = '${A.id}'`) === '1800/-',
    'QA diagnostics kept with the stored attempt (only the four known fields)');
  r = await submit(A, 10, 25000);
  check(r.status === 200 && r.data.improved === false && r.data.best_ms === 20000, 'a slower replay changes nothing (best stays 20000)');
  r = await submit(A, 10, 18500);
  check(r.status === 200 && r.data.improved === true && r.data.best_ms === 18500, 'a faster replay replaces the stored best (18500)');
  r = await submit(A, 10, 18500);
  check(r.status === 200 && r.data.improved === false && rows(`player_id = '${A.id}'`) === '1', 'a duplicate submission: not improved, still exactly one row');
  check(psql(`select diag is null from ce_level_results where player_id = '${A.id}'`) === 't',
    'the diagnostics follow the stored best attempt (the faster replay sent none)');

  // ---- 2. ownership ----
  r = await call({ action: 'submit_result', pool: 'qa', player_id: A.id, secret: hex64(), level: 10, fingerprint: FP[9], time_ms: 1000 });
  check(r.status === 403 && r.data.error === 'wrong_secret' && psql(`select time_ms from ce_level_results where player_id = '${A.id}'`) === '18500',
    'wrong secret: 403, the stored result is not overwritten');
  r = await standing({ id: A.id, secret: hex64() }, 10);
  check(r.status === 403 && r.data.error === 'wrong_secret', 'wrong secret cannot read the standing either');

  // ---- 3. malformed / impossible ----
  const bad = [
    [{ level: 0 }, 'invalid_level'], [{ level: 301 }, 'invalid_level'], [{ level: 10.5 }, 'invalid_level'], [{ level: '10' }, 'invalid_level'],
    [{ fingerprint: 'abc' }, 'invalid_fingerprint'], [{ fingerprint: FP[10] }, 'invalid_level'], [{ fingerprint: 'f'.repeat(64) }, 'invalid_level'],
    [{ time_ms: 299 }, 'invalid_time'], [{ time_ms: 6 * 3600 * 1000 + 1 }, 'invalid_time'], [{ time_ms: 1234.5 }, 'invalid_time'],
    [{ time_ms: '5000' }, 'invalid_time'], [{ time_ms: -5 }, 'invalid_time'], [{ player_id: 'not-a-uuid' }, 'invalid_player'],
    [{ secret: 'short' }, 'invalid_secret'], [{ secret: 'G'.repeat(64) }, 'invalid_secret'], [{ pool: 'staging' }, 'invalid_pool'],
  ];
  const B = player();
  for (const [patch, code] of bad) {
    r = await call({ action: 'submit_result', pool: 'qa', player_id: B.id, secret: B.secret, level: 10, fingerprint: FP[9], time_ms: 5000, ...patch });
    check(r.status >= 400 && r.status < 500 && r.data && r.data.error === code, `rejected ${JSON.stringify(patch)} -> ${r.status} ${r.data && r.data.error}`);
  }
  check(psql(`select count(*) from ce_comp_players where player_id = '${B.id}'`) === '0' && rows(`player_id = '${B.id}'`) === '0',
    'nothing was written for any rejected submission');
  r = await call({ action: 'nope' });
  check(r.status === 400 && r.data.error === 'invalid_challenge_type', 'an unknown action falls through to challenge CREATE validation (unchanged)');

  // ---- 4. percentile: five players, ties, rounding ----
  const L = 20;
  const five = [10200, 12000, 12000, 15000, 20000].map((t) => ({ p: player(), t }));
  for (const x of five.slice(0, 4)) await submit(x.p, L, x.t);
  r = await submit(five[0].p, L, 10200);
  check(r.data.percentile === null, '4 players: still no percentile');
  r = await submit(five[4].p, L, five[4].t);
  check(r.data.percentile === 100, `5th player (slowest): TOP 100% (${r.data.percentile})`);
  const want = [20, 40, 40, 80, 100];
  for (let i = 0; i < 5; i++) {
    r = await standing(five[i].p, L);
    check(r.status === 200 && r.data.percentile === want[i] && r.data.best_ms === five[i].t, `5 players: ${five[i].t} ms -> TOP ${r.data.percentile}% (want ${want[i]}%)`);
  }
  // 8 players: rounding 1/8 = 12.5 -> 13, 3/8 = 37.5 -> 38, 5/8 = 62.5 -> 63.
  const L8 = 21;
  const eight = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000].map((t) => ({ p: player(), t }));
  for (const x of eight) await submit(x.p, L8, x.t);
  const got8 = [];
  for (const x of eight) got8.push((await standing(x.p, L8)).data.percentile);
  check(JSON.stringify(got8) === JSON.stringify([13, 25, 38, 50, 63, 75, 88, 100]), `8 players, normal rounding (.5 up): ${got8.join(' ')}`);
  // Replay improvement moves a player up; the others' percentiles follow.
  r = await submit(eight[7].p, L8, 999);
  check(r.data.improved && r.data.percentile === 13, `the slowest replays to 999 ms -> TOP ${r.data.percentile}%`);
  r = await standing(eight[0].p, L8);
  check(r.data.percentile === 25, `... and the former fastest is now TOP ${r.data.percentile}%`);
  r = await standing(player(), L8);
  check(r.status === 200 && r.data.none === true && r.data.percentile === null, 'standing of a player with no result: none');
  check(rows(`level = ${L8}`) === '8', 'reading standings writes nothing');

  // ---- 5. concurrency ----
  const C = player();
  const times = Array.from({ length: 20 }, (_, i) => 30000 - i * 700);
  const conc = await Promise.all(times.map((t) => submit(C, 30, t)));
  check(conc.every((x) => x.status === 200) && psql(`select time_ms from ce_level_results where player_id = '${C.id}' and level = 30`) === String(Math.min(...times))
    && rows(`player_id = '${C.id}'`) === '1', `20 concurrent submissions of one player: one row, the fastest kept (${Math.min(...times)})`);
  const D = uuid();
  const secrets = Array.from({ length: 10 }, () => hex64());
  const race = await Promise.all(secrets.map((s) => call({ action: 'submit_result', pool: 'qa', player_id: D, secret: s, level: 31, fingerprint: FP[30], time_ms: 9000 })));
  const winners = race.filter((x) => x.status === 200).length;
  check(winners === 1 && race.filter((x) => x.status === 403).length === 9 && psql(`select count(*) from ce_comp_players where player_id = '${D}'`) === '1',
    `10 concurrent first submissions with different secrets: exactly one claims the id (${winners} ok)`);

  // ---- 6. permissions (anon / authenticated) ----
  for (const role of ['anon', 'authenticated']) {
    const sel = psqlTry(`set role ${role}; select count(*) from ce_level_results;`);
    const ins = psqlTry(`set role ${role}; insert into ce_comp_players (pool, player_id, secret_hash) values ('prod', gen_random_uuid(), repeat('a', 64));`);
    const fn = psqlTry(`set role ${role}; select ce_submit_result('qa', 10, '${FP[9]}', gen_random_uuid(), repeat('a', 64), 5000, null, 0);`);
    const rd = psqlTry(`set role ${role}; select ce_level_standing('qa', 10, '${FP[9]}', '${A.id}', repeat('a', 64));`);
    check(!sel.ok && !ins.ok && !fn.ok && !rd.ok, `${role} (the public key): no read, no write, no function execute`);
  }

  // ---- 7. QA / Production isolation ----
  r = await call({ action: 'submit_result', pool: 'prod', player_id: A.id, secret: A.secret, level: 10, fingerprint: FP[9], time_ms: 5000 });
  check(r.status === 403 && r.data.error === 'prod_closed', 'prod pool closed by default: a client asking for "prod" is refused');
  r = await call({ action: 'submit_result', player_id: player().id, secret: hex64(), level: 10, fingerprint: FP[9], time_ms: 5000 });
  check(r.status === 200, 'no pool given -> the QA pool');
  await start({ CE_PROD_POOL: 'open' });
  r = await call({ action: 'submit_result', pool: 'prod', player_id: A.id, secret: A.secret, level: 10, fingerprint: FP[9], time_ms: 5000 },
    { Origin: 'https://html-classic.itch.zone' });
  check(r.status === 403 && r.data.error === 'prod_closed', 'CE_PROD_POOL=open WITHOUT CE_PROD_ORIGINS: prod stays closed (no accidental wide-open prod)');
  await start({ CE_PROD_POOL: 'open', CE_PROD_ORIGINS: '*.itch.zone, https://example-prod.test' });
  r = await call({ action: 'submit_result', pool: 'prod', player_id: A.id, secret: A.secret, level: 10, fingerprint: FP[9], time_ms: 5000 });
  check(r.status === 403 && r.data.error === 'origin_not_allowed', 'prod open, but no allowed Origin -> refused');
  r = await call({ action: 'submit_result', pool: 'prod', player_id: A.id, secret: A.secret, level: 10, fingerprint: FP[9], time_ms: 5000 },
    { Origin: 'https://evil.example' });
  check(r.status === 403 && r.data.error === 'origin_not_allowed', 'prod open, foreign Origin -> refused');
  const prodSecret = hex64();
  r = await call({ action: 'submit_result', pool: 'prod', player_id: A.id, secret: prodSecret, level: 10, fingerprint: FP[9], time_ms: 5000 },
    { Origin: 'https://html-classic.itch.zone' });
  check(r.status === 200 && r.data.best_ms === 5000, 'prod open + itch Origin -> stored in prod (the same player id is a separate prod competitor)');
  check(psql(`select time_ms from ce_level_results where pool = 'qa' and player_id = '${A.id}' and level = 10`) === '18500'
    && psql(`select diag is null from ce_level_results where pool = 'prod' and player_id = '${A.id}'`) === 't',
    'the QA result is untouched; no diagnostics kept in prod');
  r = await call({ action: 'level_standing', pool: 'prod', player_id: five[0].p.id, secret: five[0].p.secret, level: L, fingerprint: FP[L - 1] },
    { Origin: 'https://html-classic.itch.zone' });
  check(r.status === 200 && r.data.none === true, 'QA players and results are invisible in prod');
  r = await call({ action: 'submit_result', pool: 'prod', player_id: A.id, secret: prodSecret, level: 10, fingerprint: FP[9], time_ms: 6000 },
    { Origin: 'https://evil.itch.zone.example' });
  check(r.status === 403 && r.data.error === 'origin_not_allowed', 'a look-alike host (evil.itch.zone.example) does not match *.itch.zone');
  await start({ CE_PROD_POOL: 'open', CE_PROD_ORIGINS: '*' });
  r = await call({ action: 'submit_result', pool: 'prod', player_id: A.id, secret: prodSecret, level: 10, fingerprint: FP[9], time_ms: 4900 });
  check(r.status === 200 && r.data.best_ms === 4900, 'CE_PROD_ORIGINS=* explicitly allows any origin');
  check(psql(`select count(*) from ce_level_results where pool = 'prod'`) === '1' && psql(`select count(*) from ce_comp_players where pool = 'prod'`) === '1',
    'prod holds only the one prod result / competitor - nothing from the QA traffic');
  await start({});
  r = await submit(player(), 10, 6000);
  check(r.status === 200, 'default new-player cap (10000/hour) does not refuse ordinary traffic');
  await start({ CE_MAX_NEW_PLAYERS_PER_HOUR: '0' });
  r = await submit(player(), 10, 6000);
  check(r.status === 200, 'CE_MAX_NEW_PLAYERS_PER_HOUR=0 turns the cap off');
  await start({ CE_QA_POOL: 'closed' });
  r = await submit(A, 10, 4000);
  check(r.status === 403 && r.data.error === 'qa_closed', 'the QA pool can be closed (CE_QA_POOL=closed)');

  // ---- 8. bounded growth ----
  await start({ CE_MAX_NEW_PLAYERS_PER_HOUR: '3' });
  r = await submit(player(), 10, 6000);
  check(r.status === 429 && r.data.error === 'busy', 'more than CE_MAX_NEW_PLAYERS_PER_HOUR new players -> 429 busy (the client keeps the result and retries)');
  r = await submit(A, 11, 7000);
  check(r.status === 200, '... existing players keep submitting');
  check(Number(psql(`select max(c) from (select count(*) c from ce_level_results group by pool, player_id) x`)) <= 300,
    'rows per player are bounded by the 300 levels (primary key)');
} catch (e) {
  check(false, 'exception: ' + e.message);
}
if (server) server.kill();
await sleep(300);
try { psql(`drop database ${DB} with (force)`, ADMIN); } catch { /* best effort */ }
const failed = results.filter((x) => !x).length;
console.log(`\nCOMPETITION CONTRACT TEST: ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
