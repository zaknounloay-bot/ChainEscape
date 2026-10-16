// Photo / Message Reveal experience MVP (Phase 4) in the exported Web build:
// real Chromium at iPhone SE (375x667), 14 (390x844) and Pro Max (430x932),
// real touch events (CDP), against tools/mock_social_api.py. Nothing leaves
// the machine (*.supabase.co is blocked and counted).
//
//   godot --headless --path . --export-release "Web Social QA" build/web_social_qa/index.html
//   node tools/web_reveal_mvp_test.mjs build/web_social_qa <portrait.jpg> <landscape.jpg> [--shots=dir]
//
// Per size: an ARMOR reveal (portrait photo + Hebrew message with emoji):
// landing, the finger lesson at once (no separate intro card) on the
// block aimed at the shell (the player's own tap cracks it), no timer, tools
// x3 / x2 / x2; solved: the reveal moment (playing -> done in ~2.4 s,
// photo, message and buttons on screen); a message-only Arabic reveal; a
// landscape photo. Once: a tap skips the moment; the page hidden and shown
// again mid-moment; an older 12-block link plays its board. No page errors.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync, spawn } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const args = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const root = path.resolve(args[0] || 'build/web_social_qa');
const portrait = fs.readFileSync(args[1]);
const landscape = fs.readFileSync(args[2]);
const shots = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
const repo = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const PORT = 8783, MOCK = 8796;
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

// New reveals (4x4, SocialGenerator.REVEAL): one with ARMOR (P>= is hit by Gv), one plain.
const PUZ_ARMOR = { format: 'ce-puzzle', v: 1, rules: 1, rows: 4, cols: 4, map: ['. . . P>', '. . . .', '. . Rv Gv', '. . . P>='] };
const PUZ_PLAIN = { format: 'ce-puzzle', v: 1, rules: 1, rows: 4, cols: 4, map: ['. B> . .', 'Y^ . Gv .', '. . . R<', 'P> . . .'] };
// An older (pre-MVP) MEDIUM reveal: 12 blocks with spinners.
const PUZ_OLD = { format: 'ce-puzzle', v: 1, rules: 1, rows: 5, cols: 5, map: ['. R> . . Pv', '. B^ G> Rv .', '. . Bv . Y<', 'P>@ . . Gv .', 'G< . . R<@ G>'] };
const HE = 'מזל טוב! 🎉❤️ Happy birthday';
const AR = 'كل عام وأنت بخير 🌹';
const mk = (puzzle, message, photo, difficulty = 'easy') => api('', { challenge_type: 'photo_message_reveal', difficulty, puzzle, message,
  ...(photo ? { image_base64: photo.toString('base64'), image_type: 'image/jpeg' } : {}) });
const armorC = await mk(PUZ_ARMOR, HE, portrait);
const arC = await mk(PUZ_PLAIN, AR, null);
const landC = await mk(PUZ_PLAIN, 'For the best weekend ☀️', landscape);
const oldC = await mk(PUZ_OLD, 'From before', null, 'medium');
check(armorC.ok && arC.ok && landC.ok && oldC.ok, 'mock reveals created (new 4x4 Armor / plain, and an older 12-block one)');

const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const supabaseHits = [];
async function open(W, H, id) {
  const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await context.route(/supabase\.co/, (r) => { supabaseHits.push(r.request().url()); r.abort(); });
  await context.route(MEDIA + '/**', async (route) => {
    const u = new URL(route.request().url());
    const r = await fetch(`http://127.0.0.1:${MOCK}${u.pathname}${u.search}`);
    await route.fulfill({ status: r.status, headers: { 'Content-Type': r.headers.get('content-type') || 'application/octet-stream', 'Access-Control-Allow-Origin': '*' },
      body: Buffer.from(await r.arrayBuffer()) });
  });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript((a) => { window.ceTestHooks = true; window.ceApiUrl = a; }, API);
  const cdp = await context.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const s = { W, H, context, page, errors, rec: get('chainEscapeRecipient'), play: get('chainEscapeSocialPlay') };
  s.waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(120); }
    throw new Error('timeout ' + what + ' ' + JSON.stringify(v).slice(0, 300));
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  s.tap = async (p, after = 600) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(60); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  s.shot = async (name) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, name + '.png') }); } };
  s.hidden = (on) => page.evaluate((h) => { Object.defineProperty(document, 'hidden', { configurable: true, get: () => h }); document.dispatchEvent(new Event('visibilitychange')); }, on);
  s.solveMoves = async () => {
    for (let i = 0; i < 80; i++) {
      const v = await s.waitFor(s.play, (v) => v.completed || (v.active && v.next && v.next.length === 2), 'next move');
      if (v.completed) return;
      await s.tap(v.next, 450);
    }
  };
  s.start = async () => {
    await s.waitFor(s.rec, (v) => v.state === 'landing' && v.buttons && v.buttons.Play, 'landing', 120000);
    await sleep(900);  // the landing settles (its entrance), then read the buttons
    return s.rec();
  };
  await page.goto(`http://127.0.0.1:${PORT}/index.html?challenge=${id}`);
  return s;
}
const inside = (r) => r && r.length === 4 && r[0] >= -0.001 && r[1] >= -0.001 && r[2] <= 1.001 && r[3] <= 1.001;
const onScreen = (b) => Object.values(b).every((p) => p[0] > 0 && p[0] < 1 && p[1] > 0 && p[1] < 1);
const near = (a, b) => a && b && Math.abs(a[0] - b[0]) < 0.03 && Math.abs(a[1] - b[1]) < 0.03;

async function moment(s, tag, shotName) {
  const t0 = Date.now();
  let pv = await s.waitFor(s.play, (v) => v.revealed, 'revealed', 8000);
  check(pv.reveal_phase === 'playing', `${tag} the reveal moment plays`);
  await sleep(250);
  await s.shot(shotName + '_moment');  // mid-moment (screenshots are slow under software rendering)
  pv = await s.waitFor(s.play, (v) => v.reveal_phase === 'done', 'done', 6000);
  const ms = Date.now() - t0;
  await sleep(1000);
  pv = await s.play();
  // The game's own clock (the test's polling and screenshots are slow under software rendering).
  check(pv.reveal_moment_ms >= 2100 && pv.reveal_moment_ms <= 2900 && !pv.reveal_skipped, `${tag} the envelope moment took ${pv.reveal_moment_ms} ms (about 2.45 s; ${ms} ms as seen by the test)`);
  check(inside(pv.rects.reveal_column) && onScreen(pv.buttons) && pv.buttons.CreateYourOwn && pv.buttons.PlayAgain && pv.buttons.BackToCreate,
    `${tag} photo / message and CREATE YOUR OWN SURPRISE, PLAY AGAIN, MAIN MENU all on screen`);
  check(!pv.time_visible && pv.reveal_time === '' && !pv.timed, `${tag} no timer, no time on the reveal`);
  check(pv.reveal_heading_text === 'SURPRISE UNLOCKED!', `${tag} heading: ${pv.reveal_heading_text}`);
  await s.shot(shotName + '_revealed');
  return pv;
}

try {
  for (const [size, W, H] of [['iphoneSE', 375, 667], ['iphone14', 390, 844], ['promax', 430, 932]]) {
    const tag = `[${size}]`;
    // ARMOR reveal: portrait photo + Hebrew message with emoji.
    const s = await open(W, H, armorC.challenge_id);
    let r = await s.start();
    check(r.type === 'photo_message_reveal' && onScreen(r.buttons), `${tag} landing: PLAY / MAIN MENU on screen`);
    await s.shot(`reveal_${size}_landing`);
    await s.tap(r.buttons.Play, 900);
    let pv = await s.waitFor(s.play, (v) => v.active && v.lesson_finger.length === 2, 'finger lesson', 8000);
    check(pv.lesson === 'armor' && !pv.timed && !pv.time_visible && JSON.stringify(pv.tools) === '[3,2,2]', `${tag} the finger lesson at once (no intro card); no timer; tools x3 / x2 / x2`);
    check(pv.armored.length === 1 && pv.marked.length === 2 && pv.message_text.includes('ARMOR'), `${tag} brackets and the finger lesson: "${pv.message_text}"`);
    check(pv.marked.some((m) => near(m, pv.lesson_finger)), `${tag} the finger is on a marked block (the one aimed at the shell)`);
    await sleep(900);
    await s.shot(`reveal_${size}_armor_lesson`);
    if (size === 'iphone14') {
      // Safari hidden and back mid-lesson: the lesson is still there.
      await s.hidden(true); await sleep(800); await s.hidden(false); await sleep(400);
      pv = await s.play();
      check(pv.lesson === 'armor' && pv.armored.length === 1, `${tag} page hidden and shown again: the lesson waits for the player`);
    }
    await s.tap(pv.lesson_finger, 900);
    pv = await s.play();
    check(pv.lesson === '' && pv.armor_learned && pv.armored.length === 0 && pv.message_text.startsWith('Shell cracked'), `${tag} the player's tap cracks the shell: "${pv.message_text}"`);
    await s.solveMoves();
    if (size === 'iphone14') {
      // Hidden mid-moment: it still ends with everything shown.
      await s.waitFor(s.play, (v) => v.revealed, 'revealed', 8000);
      await sleep(500);
      await s.hidden(true); await sleep(1200); await s.hidden(false);
      pv = await s.waitFor(s.play, (v) => v.reveal_phase === 'done', 'done after resume', 8000);
      await sleep(1000);
      pv = await s.play();
      check(inside(pv.rects.reveal_column) && pv.has_photo && pv.buttons.CreateYourOwn, `${tag} page hidden mid-moment: the reveal still completes`);
      // PLAY AGAIN (no lesson now), then a tap skips the moment.
      await s.tap(pv.buttons.PlayAgain, 1200);
      pv = await s.waitFor(s.play, (v) => v.active && !v.completed, 'again');
      check(pv.lesson === '', `${tag} PLAY AGAIN: Armor learned, no lesson`);
      await s.solveMoves();
      await s.waitFor(s.play, (v) => v.revealed && v.reveal_phase === 'playing', 'moment', 8000);
      await sleep(300);
      await s.tap([0.5, 0.5], 400);
      pv = await s.waitFor(s.play, (v) => v.reveal_phase === 'done', 'skipped', 3000);
      check(pv.reveal_skipped, `${tag} a tap skips the moment`);
      await sleep(1000);
      pv = await s.play();
      check(pv.buttons.CreateYourOwn && onScreen(pv.buttons) && pv.revealed && !pv.active === false, `${tag} after the skip: everything there, nothing tapped by accident`);
    } else {
      pv = await moment(s, `${tag} Armor + photo + Hebrew:`, `reveal_${size}_photo`);
      check(pv.has_photo && pv.photo_state === 'ready' && inside(pv.rects.reveal_photo) && inside(pv.rects.reveal_message), `${tag} the portrait photo and the message, inside the screen`);
    }
    const ov = await s.page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    check(ov[0] <= ov[1], `${tag} no horizontal overflow`);
    check(s.errors.length === 0, `${tag} no page errors ${s.errors.join(' | ')}`);
    await s.context.close();

    // Message-only Arabic reveal.
    const m = await open(W, H, arC.challenge_id);
    r = await m.start();
    await m.tap(r.buttons.Play, 900);
    pv = await m.waitFor(m.play, (v) => v.active, 'play');
    check(pv.lesson === '' && pv.blocks >= 4 && pv.blocks <= 6, `${tag} message only: a plain ${pv.blocks}-block board, no lesson`);
    await m.solveMoves();
    pv = await moment(m, `${tag} message only (Arabic):`, `reveal_${size}_message_only`);
    check(!pv.has_photo && inside(pv.rects.reveal_message), `${tag} message only: the message card on screen`);
    check(m.errors.length === 0, `${tag} message only: no page errors`);
    await m.context.close();
  }
  // A landscape photo (iPhone 14) and an older 12-block link (iPhone SE).
  const l = await open(390, 844, landC.challenge_id);
  let r = await l.start();
  await l.tap(r.buttons.Play, 900);
  await l.solveMoves();
  let pv = await moment(l, '[iphone14 landscape]', 'reveal_iphone14_landscape');
  check(pv.has_photo && inside(pv.rects.reveal_photo) && (pv.rects.reveal_photo[2] - pv.rects.reveal_photo[0]) > 0.6, '[iphone14 landscape] a wide photo fills the width');
  await l.context.close();
  const o = await open(375, 667, oldC.challenge_id);
  r = await o.start();
  await o.tap(r.buttons.Play, 900);
  pv = await o.waitFor(o.play, (v) => v.active, 'play');
  check(pv.blocks === 12 && pv.difficulty === 'medium' && pv.lesson === '', '[iphoneSE older link] its original 12-block board');
  await o.solveMoves();
  pv = await o.waitFor(o.play, (v) => v.revealed && v.reveal_phase === 'done', 'old reveal', 10000);
  check(pv.message === 'From before', '[iphoneSE older link] its reveal works');
  await o.context.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(supabaseHits.length === 0, `no request reached Supabase (${supabaseHits.length})`);
await browser.close(); server.close(); mock.kill();
const failed = results.filter((x) => !x).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed ? 'WEB REVEAL MVP TEST FAILED' : 'WEB REVEAL MVP TEST PASSED');
process.exit(failed ? 1 : 0);
