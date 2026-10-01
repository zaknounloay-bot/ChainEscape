// Social 0.2C phase 2: shared challenge links in the exported Web build, in
// real Chromium at iPhone size with real touch events (CDP).
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_recipient_test.mjs build/web [shots_dir] [photo.jpg]
//
// Starts tools/mock_social_api.py (window.ceApiUrl points the game at it,
// window.ceTestHooks publishes the Solver's next move). The mock's signed
// photo URLs are https://media.mock.test/... and are answered by a route
// here (like Supabase Storage: plain GET, CORS *).
// Checks: ?challenge= and #challenge= open the recipient flow (never the
// title first), landing hides the reveal, the exact puzzle is played, the
// reveal (photo + message, message only), CREATE YOUR OWN pulses once and
// opens the creator, malformed / unknown / expired links fail kindly, no
// parameter = the normal title, the Classic save (localStorage) is not
// touched, and nothing private appears in console logs or request URLs.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync, spawn } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const root = path.resolve(process.argv[2] || 'build/web');
const shots = process.argv[3] || '';
const photoPath = process.argv[4] || '';
const repo = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const PORT = 8775, MOCK = 8794, W = 390, H = 844;
const API = `http://127.0.0.1:${MOCK}/`;
const MEDIA = 'https://media.mock.test';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(root, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(PORT);
const mock = spawn('python3', [path.join(repo, 'tools/mock_social_api.py'), '--port', String(MOCK), '--media-base', MEDIA], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const api = async (p, body) => (await fetch(API + p, body ? { method: 'POST', body: JSON.stringify(body) } : {})).json();
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };

for (let i = 0; i < 40; i++) { try { await api(''); break; } catch { await sleep(250); } }
const PUZ_EASY = { format: 'ce-puzzle', v: 1, rules: 1, rows: 4, cols: 5, map: ['. Yv . R> .', '. Bv . . R<', '. B> . G^ P>', '. . . . G^'] };
const PUZ_MED = { format: 'ce-puzzle', v: 1, rules: 1, rows: 5, cols: 5, map: ['. R> . . Pv', '. B^ G> Rv .', '. . Bv . Y<', 'P>@ . . Gv .', 'G< . . R<@ G>'] };
const MSG = 'Happy birthday! שלום';
const MSG2 = 'Only words this time';
const jpeg = photoPath ? fs.readFileSync(photoPath) : null;
const both = await api('', { challenge_type: 'photo_message_reveal', difficulty: 'medium', puzzle: PUZ_MED, message: MSG,
  ...(jpeg ? { image_base64: jpeg.toString('base64'), image_type: 'image/jpeg' } : {}) });
const msgOnly = await api('', { challenge_type: 'photo_message_reveal', difficulty: 'easy', puzzle: PUZ_EASY, message: MSG2 });
const gone = await api('', { challenge_type: 'photo_message_reveal', difficulty: 'easy', puzzle: PUZ_EASY, message: 'gone' });
await api('__expire', { id: gone.challenge_id });
check(both.ok && msgOnly.ok, 'mock challenges created');

const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const logs = [], urls = [];

async function open(suffix, { hooks = true } = {}) {
  const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => logs.push(m.text()));
  page.on('request', (r) => urls.push(r.url()));
  await context.route(MEDIA + '/**', async (route) => {
    const u = new URL(route.request().url());
    const r = await fetch(`http://127.0.0.1:${MOCK}${u.pathname}${u.search}`);
    await route.fulfill({ status: r.status, headers: { 'Content-Type': r.headers.get('content-type') || 'application/octet-stream', 'Access-Control-Allow-Origin': '*' },
      body: Buffer.from(await r.arrayBuffer()) });
  });
  await page.addInitScript(([apiUrl, hooks]) => {
    if (hooks) { window.ceTestHooks = true; window.ceApiUrl = apiUrl; }
    // First recipient state the game ever published (was the title shown first?).
    let first = null;
    Object.defineProperty(window, 'chainEscapeRecipient', { configurable: true,
      set(v) { if (first === null && v && v.state !== 'closed') first = v; this.__r = v; }, get() { return this.__r; } });
    window.__firstRecipient = () => first;
  }, [API, hooks]);
  const cdp = await context.newCDPSession(page);
  await page.goto(`http://127.0.0.1:${PORT}/index.html${suffix}`);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const s = { context, page, errors, cdp, state: get('chainEscapeState'), rec: get('chainEscapeRecipient'), play: get('chainEscapeSocialPlay'), soc: get('chainEscapeSocial') };
  s.waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(150); }
    throw new Error('timeout ' + what + ' ' + JSON.stringify(v).slice(0, 300));
  };
  s.recWait = async (pred, what, ms) => { await s.waitFor(s.rec, pred, what, ms); await sleep(400); return s.rec(); };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  s.tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(60); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  s.shot = async (name) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, name + '.png') }); } };
  s.solve = async () => {
    for (let i = 0; i < 80; i++) {
      const v = await s.waitFor(s.play, (v) => v.completed || (v.active && v.next && v.next.length === 2), 'next move');
      if (v.completed) break;
      await s.tap(v.next, 450);
    }
    return s.waitFor(s.play, (v) => v.revealed, 'reveal');
  };
  return s;
}
const ls = (page) => page.evaluate(() => JSON.stringify(Object.keys(localStorage).sort().map((k) => [k, localStorage.getItem(k)])));

try {
  // A, G-L, P, R, Q: ?challenge=<photo + message>.
  let s = await open(`?challenge=${both.challenge_id}`);
  let r = await s.recWait((v) => v.state === 'landing', 'landing', 120000);
  const first = await s.page.evaluate(() => window.__firstRecipient());
  check(first && first.state === 'loading', 'A: ?challenge= opens the loading screen first (published state: ' + (first && first.state) + ')');
  const st = await s.state();
  check(st && st.title_open, 'A: the title is underneath (MAIN MENU target), covered by the recipient screens');
  check(r.difficulty === 'medium' && r.buttons.Play && r.buttons.MainMenu, 'landing: difficulty + PLAY + MAIN MENU');
  const lsBefore = await ls(s.page);
  await sleep(1500);
  await s.shot('web_landing');
  if (jpeg) await s.waitFor(s.rec, (v) => v.photo === 'ready', 'photo prefetched');
  let pv = await s.play();
  check(!pv || !pv.active, 'I: nothing of the reveal is shown on the landing');
  await s.tap(r.buttons.Play, 1200);
  pv = await s.waitFor(s.play, (v) => v.active && v.mode === 'recipient', 'play');
  check(pv.difficulty === 'medium' && pv.blocks === 12, 'J: PLAY = the exact shared board (12 blocks)');
  const fp = pv.fingerprint;
  await s.shot('web_play');
  pv = await s.solve();
  check(pv.message === MSG && (!jpeg || (pv.has_photo && pv.photo_state === 'ready')), 'K/L: reveal with the photo (signed URL) and the message');
  check(pv.buttons.CreateYourOwn && pv.buttons.PlayAgain && pv.buttons.BackToCreate, 'CREATE YOUR OWN, PLAY AGAIN, MAIN MENU on the reveal');
  check(Object.values(pv.buttons).every((p) => p[1] > 0 && p[1] < 1), 'everything above the fold');
  await sleep(1200);
  await s.shot('web_reveal');
  pv = await s.play();
  check(pv.cta_pulses === 1, 'R: CTA pulsed once (~1.2 s)');
  await sleep(3000);
  pv = await s.play();
  check(pv.cta_pulses === 1, 'R: and never again');
  await s.tap(pv.buttons.PlayAgain, 1200);
  pv = await s.waitFor(s.play, (v) => v.active && !v.revealed, 'play again');
  check(pv.plays === 2 && pv.blocks === 12 && pv.fingerprint === fp, 'P: PLAY AGAIN = the same puzzle');
  pv = await s.solve();
  await sleep(1500);
  pv = await s.play();
  await s.tap(pv.buttons.CreateYourOwn, 1200);
  const so = await s.waitFor(s.soc, (v) => v.open && v.step === 'CHOOSE', 'creator');
  check(so && so.buttons && so.buttons.SkipPhoto, 'Q: CREATE YOUR OWN -> the existing Photo / Message creator');
  await s.shot('web_create_your_own');
  check((await ls(s.page)) === lsBefore, 'S: Classic save (localStorage) untouched by the whole shared challenge');
  check(s.errors.length === 0, 'no page errors (' + s.errors.join(' | ').slice(0, 200) + ')');
  await s.context.close();

  // B: #challenge= (message only).
  s = await open(`#challenge=${msgOnly.challenge_id}`);
  r = await s.recWait((v) => v.state === 'landing', 'landing #', 120000);
  check(r.difficulty === 'easy' && r.photo === 'none', 'B: #challenge= opens its landing');
  await s.tap(r.buttons.Play, 1200);
  pv = await s.solve();
  check(pv.message === MSG2 && !pv.has_photo && pv.photo_state === 'none', 'N: message-only reveal');
  await sleep(1500);
  await s.shot('web_reveal_message_only');
  pv = await s.play();
  await s.tap(pv.buttons.BackToCreate, 1200);
  const t = await s.waitFor(s.state, (v) => v.title_open, 'title after MAIN MENU');
  r = await s.rec();
  check(t.title_open && r.state === 'closed', 'MAIN MENU -> the normal title');
  await s.context.close();

  // D, E, F: malformed / unknown / expired.
  for (const [suffix, what] of [['?challenge=not-a-real-id', 'D: malformed'], ['?challenge=', 'D: empty'],
    ['?challenge=3f2b8c1e-9a4d-4e7b-8c21-5d6e7f809a1b', 'E: unknown'], [`?challenge=${gone.challenge_id}`, 'F: expired']]) {
    s = await open(suffix);
    r = await s.recWait((v) => v.state === 'unavailable' || v.state === 'error', what, 120000);
    check(r.state === 'unavailable' && r.buttons.MainMenu && !r.buttons.Retry, `${what} link -> "isn't available" + MAIN MENU (${r.error})`);
    if (what.startsWith('D: malformed')) {
      await sleep(800);
      await s.shot('web_unavailable');
      await s.tap(r.buttons.MainMenu, 1000);
      check((await s.state()).title_open && (await s.rec()).state === 'closed', 'D: MAIN MENU -> title');
    }
    await s.context.close();
  }

  // Network trouble: RETRY.
  await api('__mode', { fail_next_read: '500' });
  s = await open(`?challenge=${msgOnly.challenge_id}`);
  r = await s.recWait((v) => v.state === 'error', 'error', 120000);
  check(r.buttons.Retry && r.buttons.MainMenu, 'server error -> RETRY + MAIN MENU');
  await sleep(800);
  await s.shot('web_error_retry');
  await s.tap(r.buttons.Retry, 800);
  r = await s.recWait((v) => v.state === 'landing', 'landing after retry');
  check(r.state === 'landing', 'RETRY -> landing');
  await s.context.close();

  // C: no parameter = the normal start.
  s = await open('', { hooks: false });
  const tt = await s.waitFor(s.state, (v) => v.title_open, 'title', 120000);
  await sleep(1500);
  r = await s.rec();
  check(tt.title_open && (!r || r.state === 'closed'), 'C: no parameter -> normal title, no recipient screen');
  check(!urls.some((u) => u.includes(`127.0.0.1:${PORT}`) === false && u.includes('supabase')), 'C: no API call at a normal start');
  await s.context.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}

// V / U: nothing private in console logs or in any request URL.
const joined = logs.join('\n');
check(![MSG, MSG2, 'שלום', 'token=', 'storage/v1', 'reveal.jpg', 'media.mock.test'].some((x) => joined.includes(x)),
  'V: no message, photo path or signed URL in console logs');
check(!urls.some((u) => u.includes(encodeURIComponent('Happy')) || u.includes('Happy') || u.includes('words')),
  'U: no message text in any request URL');
check(urls.filter((u) => u.startsWith(API) && u.includes('action=read')).every((u) => /\?action=read&id=[0-9a-f-]{36}$/.test(u)),
  'READ requests carry only the id');

await browser.close(); server.close(); mock.kill();
const failed = results.filter((x) => !x).length;
console.log(`WEB RECIPIENT TEST: ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
