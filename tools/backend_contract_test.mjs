// chain-escape-api contract test (Challenge a Friend phase 2): CREATE / READ
// for friend_challenge and photo_message_reveal, type-specific validation and
// backwards compatibility. Runs against ANY deployment of the API:
//
//   node tools/backend_contract_test.mjs                 # local mock (started here)
//   node tools/backend_contract_test.mjs <API_URL>       # e.g. the real Edge Function
//   node tools/backend_contract_test.mjs --edge=supabase/functions/chain-escape-api/index.ts
//       runs that Edge Function source locally under Deno (DENO=<path> or
//       deno on PATH) with tools/edge_harness/fake_supabase.ts in place of
//       supabase-js (in-memory table + bucket, seeded with a version-3
//       photo record that is then read back as --old).
//
// Against a real deployment it CREATES a few small test challenges (no
// images unless --with-image) - they expire like any other. It never needs
// or sends a service key: it is a plain public client, exactly like the game.
// Optional: --old=<challenge-id> reads a challenge created BEFORE the
// deployment and checks it still reads (backwards compatibility).
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';

const repo = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const args = process.argv.slice(2);
const flag = (n) => args.find((a) => a.startsWith(`--${n}`));
let API = args.find((a) => !a.startsWith('--')) || '';
let oldId = (flag('old') || '').split('=')[1] || '';
const edge = (flag('edge') || '').split('=')[1] || '';
let withImage = !!flag('with-image');
let mock = null;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const OLD_SEED_ID = '6f1c2a3b-4d5e-4f60-8a7b-9c0d1e2f3a4b';
if (edge) {
  // A row exactly as version 3 stores a photo challenge.
  const seedFile = path.join(repo, 'tools/edge_harness/.seed.json');
  fs.writeFileSync(seedFile, JSON.stringify([{ id: OLD_SEED_ID, challenge_type: 'photo_message_reveal', difficulty: 'easy',
    puzzle: JSON.parse(fs.readFileSync(path.join(repo, 'tools/fixtures/friend_puzzles.json'), 'utf8')).easy,
    payload: { message: 'made by version 3', media: null }, format_version: 1, rules_version: 1,
    created_at: '2026-09-30T10:00:00.000Z', expires_at: '2099-01-01T00:00:00.000Z' }]));
  API = 'http://127.0.0.1:8000/';
  mock = spawn(process.env.DENO || 'deno', ['run', '--quiet', '--allow-net', '--allow-env', '--allow-read',
    '--import-map', path.join(repo, 'tools/edge_harness/import_map.json'), path.resolve(edge)],
    { stdio: ['ignore', 'ignore', 'inherit'], env: { ...process.env, SUPABASE_URL: 'https://fake.supabase.test',
      SUPABASE_SERVICE_ROLE_KEY: 'local-test-only', CE_FAKE_SEED: seedFile } });
  for (let i = 0; i < 120; i++) { try { await fetch(API); break; } catch { await sleep(250); } }
  oldId = oldId || OLD_SEED_ID;
  withImage = true;
} else if (!API) {
  API = 'http://127.0.0.1:8796/';
  mock = spawn('python3', [path.join(repo, 'tools/mock_social_api.py'), '--port', '8796'], { stdio: 'ignore' });
  for (let i = 0; i < 40; i++) { try { await fetch(API); break; } catch { await sleep(250); } }
}
const base = API.replace(/\/?$/, '');
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const PUZ = JSON.parse(fs.readFileSync(path.join(repo, 'tools/fixtures/friend_puzzles.json'), 'utf8'));
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

async function create(body) {
  const r = await fetch(base, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  let j = null; try { j = await r.json(); } catch { /* not json */ }
  return { status: r.status, body: j };
}
async function read(id) {
  const r = await fetch(`${base}?action=read&id=${id}`);
  let j = null; try { j = await r.json(); } catch { /* not json */ }
  return { status: r.status, body: j };
}
const ok = (r) => r.status >= 200 && r.status < 300 && r.body && r.body.ok === true && UUID.test(r.body.challenge_id || '');
const refused = (r) => r.status >= 400 && r.status < 500 && r.body && r.body.ok === false;

try {
  const h = await (await fetch(base)).json();
  check(h.ok && h.service === 'chain-escape-api' && h.version >= 4, `health: chain-escape-api version ${h.version} (friend_challenge needs >= 4)`);
  // 1-4: CREATE + READ friend_challenge, every difficulty, no message / image.
  const ids = {};
  for (const d of ['easy', 'medium', 'hard', 'very_hard']) {
    const c = await create({ challenge_type: 'friend_challenge', difficulty: d, puzzle: PUZ[d] });
    check(ok(c), `CREATE friend_challenge ${d} (no image, no message) -> id (${c.status} ${JSON.stringify(c.body).slice(0, 120)})`);
    if (!ok(c)) continue;
    ids[d] = c.body.challenge_id;
    const r = await read(ids[d]);
    const ch = r.body && r.body.challenge;
    check(r.status === 200 && ch && ch.challenge_type === 'friend_challenge' && ch.difficulty === d,
      `READ ${d}: type friend_challenge, actual difficulty ${d}`);
    check(ch && same(ch.puzzle, PUZ[d]), `READ ${d}: the exact PuzzleDefinition, field for field`);
    check(ch && (ch.media_url === null || ch.media_url === undefined) && !(ch.payload && (ch.payload.message || ch.payload.media)),
      `READ ${d}: no message, media or media_url for a friend challenge`);
  }
  // Multiple recipients: repeated READs of one id are identical.
  if (ids.hard) {
    const reads = await Promise.all([1, 2, 3, 4, 5].map(() => read(ids.hard)));
    check(reads.every((r) => r.status === 200 && same(r.body.challenge.puzzle, PUZ.hard)), '5 READs of one id (5 recipients) -> the same puzzle every time');
  }
  // SURPRISE ME: real difficulty stored, flag kept.
  const s = await create({ challenge_type: 'friend_challenge', difficulty: 'medium', puzzle: PUZ.medium, surprise_me: true });
  check(ok(s), 'CREATE with surprise_me: true');
  if (ok(s)) {
    const r = await read(s.body.challenge_id);
    check(r.body.challenge.difficulty === 'medium' && r.body.challenge.payload && r.body.challenge.payload.surprise_me === true,
      'SURPRISE ME: stored difficulty is the real one (medium), payload.surprise_me = true');
  }
  // 5-7: invalid friend challenges are refused.
  const bad = [
    [{ challenge_type: 'friend_challenge', difficulty: 'hard' }, 'missing puzzle'],
    [{ challenge_type: 'friend_challenge', difficulty: 'hard', puzzle: null }, 'null puzzle'],
    [{ challenge_type: 'friend_challenge', difficulty: 'insane', puzzle: PUZ.hard }, 'unsupported difficulty'],
    [{ challenge_type: 'friend_challenge', difficulty: 'surprise', puzzle: PUZ.hard }, '"surprise" as a difficulty'],
    [{ challenge_type: 'friend_challenge', difficulty: 'hard', puzzle: { ...PUZ.hard, v: 2 } }, 'unsupported puzzle version'],
    [{ challenge_type: 'friend_challenge', difficulty: 'hard', puzzle: { ...PUZ.hard, rules: 9 } }, 'unsupported rules version'],
    [{ challenge_type: 'friend_challenge', difficulty: 'hard', puzzle: { ...PUZ.hard, rows: 5 } }, 'map / size mismatch'],
    [{ challenge_type: 'friend_challenge', difficulty: 'hard', puzzle: { ...PUZ.hard, cols: 13 } }, 'board too large'],
    [{ challenge_type: 'friend_challenge', difficulty: 'easy', puzzle: { ...PUZ.easy, map: ['B^#R Y< G> . Pv', ...PUZ.easy.map.slice(1)] } }, 'locked block (not a friend mechanic)'],
    [{ challenge_type: 'friend_challenge', difficulty: 'easy', puzzle: { ...PUZ.easy, map: ['. . . . .', '. . . . .', '. . . . .', '. . . . .'] } }, 'empty board'],
    [{ challenge_type: 'friend_challenge', difficulty: 'easy', puzzle: PUZ.easy, message: 'hi' }, 'a message on a friend challenge'],
    [{ challenge_type: 'friend_challenge', difficulty: 'easy', puzzle: PUZ.easy, surprise_me: 'yes' }, 'non-boolean surprise_me'],
    [{ challenge_type: 'mystery_type', difficulty: 'easy', puzzle: PUZ.easy, message: 'hi' }, 'unknown challenge type'],
  ];
  for (const [b, what] of bad) {
    const r = await create(b);
    check(refused(r), `refused: ${what} (${r.status})`);
  }
  // 8-9: Photo / Message Reveal unchanged.
  const pm = await create({ challenge_type: 'photo_message_reveal', difficulty: 'easy', puzzle: PUZ.easy, message: 'contract test' });
  check(ok(pm), 'photo_message_reveal with a message still CREATEs');
  if (ok(pm)) {
    const r = await read(pm.body.challenge_id);
    check(r.body.challenge.challenge_type === 'photo_message_reveal' && r.body.challenge.payload.message === 'contract test'
      && same(r.body.challenge.puzzle, PUZ.easy), 'photo_message_reveal READ: message + exact puzzle');
  }
  check(refused(await create({ challenge_type: 'photo_message_reveal', difficulty: 'easy', puzzle: PUZ.easy })),
    'photo_message_reveal still requires a photo or a message');
  check(refused(await create({ challenge_type: 'photo_message_reveal', difficulty: 'very_hard', puzzle: PUZ.very_hard, message: 'x' })),
    'very_hard is refused for photo_message_reveal');
  if (withImage) {
    const jpeg = Buffer.from('/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=', 'base64');
    const pi = await create({ challenge_type: 'photo_message_reveal', difficulty: 'easy', puzzle: PUZ.easy, image_base64: jpeg.toString('base64'), image_type: 'image/jpeg' });
    check(ok(pi), 'photo_message_reveal with an image still CREATEs');
    if (ok(pi)) {
      const r = await read(pi.body.challenge_id);
      check(typeof r.body.challenge.media_url === 'string' && r.body.challenge.media_url.startsWith('http'), 'photo READ: signed media_url');
    }
  }
  // 10: a challenge created before this deployment.
  if (oldId) {
    const r = await read(oldId);
    check(r.status === 200 && r.body.ok && r.body.challenge.challenge_type === 'photo_message_reveal' && r.body.challenge.puzzle,
      `old challenge ${oldId} still reads (${r.status})`);
  }
  check((await read('3f2b8c1e-9a4d-4e7b-8c21-5d6e7f809a1b')).status === 404, 'unknown id -> 404');
  const badId = await read('not-a-uuid');
  check(badId.status >= 400 && badId.status < 500, `malformed id -> 4xx, not a server error (${badId.status})`);
} catch (e) {
  check(false, 'exception: ' + e.message);
}
if (mock) mock.kill();
const failed = results.filter((x) => !x).length;
console.log(`BACKEND CONTRACT TEST (${edge ? 'edge ' + edge : mock ? 'mock' : base}): ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
