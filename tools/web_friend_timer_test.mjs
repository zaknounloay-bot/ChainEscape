// Challenge a Friend TIME + tools by difficulty (Phase 4) in the exported
// Web build: real Chromium, real touch events via CDP, against
// tools/mock_social_api.py (nothing leaves the machine).
//
//   godot --headless --path . --export-release "Web Social QA" build/web_social_qa/index.html
//   node tools/web_friend_timer_test.mjs build/web_social_qa [--shots=dir]
//
// Phone A (390x844) creates a VERY HARD and an EASY challenge. Each is then
// opened as a recipient at iPhone SE (375x667), 14 (390x844) and Pro Max
// (430x932):
//   - TIME under the difficulty, above the board, clear of EXIT, on screen;
//   - the tool row on screen; VERY HARD: SHOW A MOVE x1, the Hammer dimmed
//     at 0 and a tap only explains; EASY: x3 / x2 / x2;
//   - the clock runs, changes text once per second, pauses with EXIT and a
//     hidden page (visibilitychange), keeps going across RESTART;
//   - solved: YOUR TIME under YOU ESCAPED!, every button on screen; PLAY
//     AGAIN starts at 0:00; no horizontal overflow; no page errors.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const root = path.resolve(process.argv[2] || 'build/web_social_qa');
const shots = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PORT = 8781, MOCK = 8798;
const API = `http://127.0.0.1:${MOCK}/`;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(root, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(PORT);
const mock = spawn('python3', [path.join(repo, 'tools/mock_social_api.py'), '--port', String(MOCK)], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
for (let i = 0; i < 40; i++) { try { await fetch(API); break; } catch { await sleep(250); } }
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

async function open(W, H, suffix) {
  const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await context.route(/supabase\.co/, (r) => r.abort());
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript((api) => { window.ceTestHooks = true; window.ceApiUrl = api; }, API);
  const cdp = await context.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const s = { W, H, context, page, errors, state: get('chainEscapeState'), fr: get('chainEscapeFriend'), rec: get('chainEscapeRecipient'), play: get('chainEscapeSocialPlay') };
  s.waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(150); }
    throw new Error('timeout ' + what + ' ' + JSON.stringify(v).slice(0, 300));
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  s.tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(60); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  s.tapFriend = async (name, step, after) => {
    const v = await s.waitFor(s.fr, (v) => v.open && v.step === step && v.buttons[name] && !v.buttons[name][2], name);
    await s.tap(v.buttons[name], after);
  };
  s.shot = async (name) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, name + '.png') }); } };
  s.solve = async () => {
    for (let i = 0; i < 80; i++) {
      const v = await s.waitFor(s.play, (v) => v.completed || (v.active && v.next && v.next.length === 2), 'next move');
      if (v.completed) break;
      await s.tap(v.next, 450);
    }
    await s.waitFor(s.play, (v) => v.revealed, 'reveal');
    await sleep(1500);
    return s.play();
  };
  // The snapshot is republished (test hooks only) each time the shown
  // second changes: wait for the next one to read the clock fresh.
  s.tick = async () => { const u = (await s.play()).time_updates; return s.waitFor(s.play, (v) => v.time_updates > u, 'next second', 4000); };
  s.hidden = (on) => page.evaluate((h) => {
    Object.defineProperty(document, 'hidden', { configurable: true, get: () => h });
    document.dispatchEvent(new Event('visibilitychange'));
  }, on);
  await page.goto(`http://127.0.0.1:${PORT}/index.html${suffix}`);
  return s;
}
const inside = (r) => r.length === 4 && r[0] >= 0 && r[1] >= 0 && r[2] <= 1 && r[3] <= 1;
const overlap = (a, b) => a.length === 4 && b.length === 4 && a[0] < b[2] && b[0] < a[2] && a[1] < b[3] && b[1] < a[3];
const onScreen = (buttons) => Object.values(buttons).every((p) => p[0] > 0 && p[0] < 1 && p[1] > 0 && p[1] < 1);

try {
  // ---- Phone A: a VERY HARD and an EASY challenge.
  const a = await open(390, 844, '');
  await a.waitFor(a.state, (v) => v.title_open, 'title', 120000); await sleep(1500);
  await a.tap([0.5, 0.7182], 1000);          // CREATE CHALLENGE
  await a.tap([0.5, 0.62], 900);             // CHALLENGE A FRIEND card
  const ids = {};
  for (const d of ['very_hard', 'easy']) {
    await a.waitFor(a.fr, (v) => v.open && v.step === 'CHOOSE', 'choose');
    await a.tapFriend('Difficulty_' + d, 'CHOOSE', 100);
    const f = await a.waitFor(a.fr, (v) => v.step === 'READY' || v.failed, 'ready', 60000);
    ids[d] = (f.share_url.match(/challenge=([0-9a-f-]{36})/) || [])[1];
    check(f.step === 'READY' && f.difficulty === d && ids[d], `phone A: ${d.toUpperCase()} challenge created`);
    await a.tapFriend('NewChallenge', 'READY', 900);
  }
  check(a.errors.length === 0, 'phone A: no page errors ' + a.errors.join(' | '));
  await a.context.close();

  const runs = [
    ['iphoneSE', 375, 667, 'very_hard'], ['iphone14', 390, 844, 'very_hard'], ['promax', 430, 932, 'very_hard'], ['iphone14', 390, 844, 'easy'],
  ];
  for (const [size, W, H, d] of runs) {
    const tag = `[${size} ${d.toUpperCase()}]`;
    const b = await open(W, H, `?challenge=${ids[d]}`);
    const r = await b.waitFor(b.rec, (v) => v.state === 'landing' && v.buttons && v.buttons.Play, 'landing', 120000);
    await sleep(600);
    await b.tap((await b.rec()).buttons.Play, 1200);
    let pv = await b.waitFor(b.play, (v) => v.active && v.mode === 'recipient' && v.time_visible, 'play');
    await sleep(1200);
    pv = await b.play();
    const R = pv.rects;
    const want = d === 'very_hard' ? [3, 1, 0] : [3, 2, 2];
    check(JSON.stringify(pv.tools) === JSON.stringify(want) && pv.undos_left === want[0] && pv.hints_left === want[1] && pv.hammers_left === want[2],
      `${tag} tools x${want.join(' / x')}`);
    check(pv.timed && /^TIME  0:0\d$/.test(pv.time_text), `${tag} live TIME "${pv.time_text}"`);
    check(inside(R.time) && R.time[1] >= R.chip[3] - 0.002 && R.time[3] <= R.progress[1] + 0.002 && R.progress[3] <= R.board[1] + 0.002 && !overlap(R.time, R.exit),
      `${tag} TIME under the difficulty, above the progress bar and the board, clear of EXIT (${R.time.join(', ')})`);
    check(pv.buttons.Undo && pv.buttons.Hint && pv.buttons.Hammer && pv.buttons.Restart && onScreen(pv.buttons) && inside(R.bottom),
      `${tag} UNDO / SHOW A MOVE / HAMMER / RESTART on screen`);
    await b.shot(`timer_${size}_${d}_play`);
    // The clock: text once per second.
    pv = await b.tick();
    const t0 = pv.time_ms, u0 = pv.time_updates;
    await sleep(3000);
    pv = await b.tick();
    const secs = Math.round((pv.time_ms - t0) / 1000);
    check(pv.time_ms - t0 >= 2800 && pv.time_ms - t0 <= 4500 && pv.time_updates - u0 === secs,
      `${tag} runs (+${pv.time_ms - t0} ms), text changed ${pv.time_updates - u0}x for ${secs} s (once per second)`);
    // Tools.
    if (d === 'very_hard') {
      await b.tap(pv.buttons.Hammer, 600);
      pv = await b.play();
      check(!pv.hammer_armed && pv.hammers_left === 0 && pv.message_text === 'No Hammer in VERY HARD challenges', `${tag} the dimmed Hammer only explains: "${pv.message_text}"`);
      await b.tap(pv.buttons.Hint, 600);
      await b.tap(pv.buttons.Hint, 600);
      pv = await b.play();
      check(pv.hints_left === 0 && pv.message_text.startsWith('No SHOW A MOVE left'), `${tag} SHOW A MOVE x1, then refused`);
    }
    // Hidden page: paused.
    await b.hidden(true);
    pv = await b.waitFor(b.play, (v) => v.page_hidden, 'hidden');
    const th = pv.time_ms;
    await sleep(1500);
    pv = await b.play();
    check(pv.time_ms - th < 150, `${tag} paused while the page is hidden (+${pv.time_ms - th} ms)`);
    await b.hidden(false);
    pv = await b.tick();
    check(!pv.page_hidden && pv.time_ms > th, `${tag} visible again: it runs (${th} -> ${pv.time_ms} ms)`);
    // EXIT open: paused.
    await b.tap(pv.buttons.Exit, 600);
    pv = await b.waitFor(b.play, (v) => v.confirm && v.buttons.KeepPlaying, 'confirm');
    const te = pv.time_ms;
    await sleep(1500);
    pv = await b.play();
    check(pv.time_ms - te < 150, `${tag} paused while EXIT is open (+${pv.time_ms - te} ms)`);
    await b.tap(pv.buttons.KeepPlaying, 600);
    // RESTART keeps the clock.
    pv = await b.play();
    const tr = pv.time_ms;
    await b.tap(pv.buttons.Restart, 900);
    pv = await b.play();
    check(!pv.confirm && pv.time_ms >= tr && pv.final_time_ms === -1, `${tag} RESTART keeps the clock (${tr} -> ${pv.time_ms} ms)`);
    // Solved.
    pv = await b.solve();
    const RR = pv.rects;
    check(pv.final_time_ms > 0 && pv.reveal_time === pv.time_text.replace('TIME  ', '') && pv.time_ms === pv.final_time_ms,
      `${tag} YOU ESCAPED! shows YOUR TIME ${pv.reveal_time} (${pv.final_time_ms} ms)`);
    check(inside(RR.reveal_time) && RR.reveal_time[1] >= RR.reveal_heading[3] - 0.002 && onScreen(pv.buttons) && pv.buttons.PlayAgain && pv.buttons.ChallengeAFriend,
      `${tag} the time under the heading; PLAY AGAIN / CHALLENGE A FRIEND / MAIN MENU on screen`);
    const ov = await b.page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    check(ov[0] <= ov[1], `${tag} no horizontal overflow (${ov[0]} <= ${ov[1]})`);
    await b.shot(`timer_${size}_${d}_solved`);
    await sleep(1500);
    const tf = (await b.play()).time_ms;
    check(tf === pv.final_time_ms, `${tag} nothing added after the solve`);
    // PLAY AGAIN: a fresh timed run.
    await b.tap(pv.buttons.PlayAgain, 1000);
    pv = await b.waitFor(b.play, (v) => v.active && !v.completed, 'again');
    check(pv.final_time_ms === -1 && pv.time_ms < 1500 && pv.time_text.startsWith('TIME  0:0') && JSON.stringify(pv.tools) === JSON.stringify(want),
      `${tag} PLAY AGAIN starts a fresh run (${pv.time_ms} ms), same tools`);
    check(b.errors.length === 0, `${tag} no page errors ` + b.errors.join(' | '));
    await b.context.close();
  }
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close(); server.close(); mock.kill();
const failed = results.filter((x) => !x).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed ? 'WEB FRIEND TIMER TEST FAILED' : 'WEB FRIEND TIMER TEST PASSED');
process.exit(failed ? 1 : 0);
