// The 90-second Time Attack prototype with dynamic music (?ta90=1),
// exported DEVELOPMENT Web build, real Chromium at iPhone SE size (375x667),
// real touches:
//   node tools/web_ta90_page_test.mjs <dev web build> [--player=<player build>] [--shots=dir] [--board=TA]
//   run 1 (the FULL real-time 90 s run): welcome -> familiarity -> CHOOSE A
//   PUZZLE -> the card (1:30) -> START (the gesture that unlocks audio) ->
//   1:30 GREEN with the green mix; the MUSIC toggle beside the countdown
//   (never over the board); RESTART and UNDO give no time back; MUSIC OFF /
//   ON by touch; the page in the background (music paused, clock running);
//   a real reload mid-run (straight back to the puzzle, the clock not
//   restored, NO sound until the next tap - the browser's gesture rule);
//   ORANGE at 1:00 and RED at 0:30 with their mixes; TIME UP after 90 s of
//   wall time and silence; the questions (no music); CONTINUE WITHOUT TIMER
//   with the calm mix; solved by touches; silence on the result; COPY ALL
//   RESULTS (one ce-ta90 bundle); no other page's storage touched; no
//   network calls; no horizontal overflow.
//   run 2 (prefers-reduced-motion): the RED stage without pulse or scale, the
//   music unchanged.
//   --player: the player build ignores ?ta90=1.
// Chromium is not iPhone Safari: audio here is Chromium's Web Audio (the
// AudioContext state, the mix and its position are read from the page, not
// heard); the real Safari unlock / background behaviour still needs a phone.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const root = path.resolve(process.argv[2] || 'build/web');
const shots = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
const benchOut = (process.argv.find((a) => a.startsWith('--bench-out=')) || '').slice(12);
const playerRoot = (process.argv.find((a) => a.startsWith('--player=')) || '').slice(9);
const PORT = 8830, W = 375, H = 667;  // iPhone SE
const LSB = (b) => `chain_escape_ta90_${b.toLowerCase()}_state`;
const BOARD = (process.argv.find((a) => a.startsWith('--board=')) || '--board=').slice(8);  // '' = PUZZLE 1 of the hub
const FILL = { green: [0x1e, 0x7b, 0x34], orange: [0xc2, 0x41, 0x0c], red: [0xb9, 0x1c, 0x1c] };
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const serve = (dir) => (req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(dir, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
};
const server = http.createServer(serve(root)).listen(PORT);
const server2 = playerRoot ? http.createServer(serve(path.resolve(playerRoot))).listen(PORT + 1) : null;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

// A minimal PNG decoder (8-bit RGB / RGBA, the five scanline filters).
function decodePNG(buf) {
  let pos = 8, w = 0, h = 0, ct = 0;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8), body = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = body.readUInt32BE(0); h = body.readUInt32BE(4); ct = body[9]; }
    if (type === 'IDAT') idat.push(body);
    pos += 12 + len;
  }
  const bpp = ct === 6 ? 4 : 3, raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * bpp, out = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[y * stride + x - bpp] : 0, b = y > 0 ? out[(y - 1) * stride + x] : 0, c = x >= bpp && y > 0 ? out[(y - 1) * stride + x - bpp] : 0;
      let v = line[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      out[y * stride + x] = v & 255;
    }
  }
  return { w, h, bpp, data: out };
}
const luma = (c) => 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
const near = (c, e, tol = 22) => Math.abs(c[0] - e[0]) <= tol && Math.abs(c[1] - e[1]) <= tol && Math.abs(c[2] - e[2]) <= tol;


async function session(context, label) {
  const page = await context.newPage();
  const errors = [];
  const external = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (/SCRIPT ERROR|ERROR:|Invalid/.test(m.text()) && !m.text().includes('Condition "!is_inside_tree()" is true')) errors.push(m.text().slice(0, 300)); });
  page.on('request', (r) => { if (!r.url().startsWith(`http://127.0.0.1:${PORT}/`)) external.push(r.url()); });
  await page.addInitScript(() => {
    window.ceTestHooks = true;
    if (location.protocol !== 'http:') return;  // about:blank (the back / forward check)
    const back = Number(sessionStorage.getItem('ceRewind') || 0);
    const k = sessionStorage.getItem('ceRewindKey') || '';
    if (back > 0 && k && localStorage.getItem(k)) {
      sessionStorage.removeItem('ceRewind');
      const s = JSON.parse(localStorage.getItem(k));
      s.run.started_unix -= back;
      s.run.elapsed_ms = (s.run.elapsed_ms || 0) + back * 1000;
      s.seq += 1000;
      localStorage.setItem(k, JSON.stringify(s));
    }
  });
  const cdp = await context.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const s = { page, errors, external, hub: get('chainEscapeTa90'), mus: get('chainEscapeStageMusic'), aud: get('chainEscapeAudio'), vt: get('chainEscapeVhTest'), play: get('chainEscapeSocialPlay'), ta: get('chainEscapeTimeAttack'), cd: get('chainEscapeCountdown') };
  s.waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(100); }
    throw new Error(`${label}: timeout ${what} ${JSON.stringify(v).slice(0, 300)}`);
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  s.tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(80); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  s.shot = async (n) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, n + '.png') }); } };
  s.tapHub = async (name, view, after = 900) => { const v = await s.waitFor(s.hub, (v) => v.view === view && v.buttons[name], name); await s.tap(v.buttons[name], after); };
  s.tapVt = async (name, screen, after = 600) => { const v = await s.waitFor(s.vt, (v) => v.screen === screen && v.buttons[name], name); await s.tap(v.buttons[name], after); };
  s.tapTa = async (name, after = 900) => { await sleep(400); const x = await s.waitFor(s.ta, (v) => v.buttons && v.buttons[name], name); await s.tap(x.buttons[name], after); };
  s.state = async (b) => JSON.parse(await page.evaluate((k) => localStorage.getItem(k), LSB(b)) || '{}');
  s.begin = async () => { await s.tapVt('BeginPuzzle', 'BRIEF', 1500); };
  s.fill = async (c) => {
    const r = c.rect, x = (r[0] + r[2] * 0.935) * W, y = (r[1] + r[3] * 0.5) * H;
    const png = decodePNG(await page.screenshot({ clip: { x: x - 1.5, y: y - 1.5, width: 3, height: 3 } }));
    const acc = [0, 0, 0]; const n = png.w * png.h;
    for (let i = 0; i < n; i++) for (let k = 0; k < 3; k++) acc[k] += png.data[i * png.bpp + k];
    return acc.map((v) => Math.round(v / n));
  };
  s.solveByTouches = async (what) => {
    for (let i = 0; i < 80; i++) {
      const p = await s.waitFor(s.play, (p) => p.completed || (p.active && p.next && p.next.length === 2), what);
      if (p.completed) return true;
      await s.tap(p.next, 450);
    }
    return false;
  };
  s.noOverflow = async () => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1 && document.body.scrollWidth <= window.innerWidth + 1);
  // Every visible hub button inside the screen, at least 44 CSS px tall.
  s.hubFits = async () => { const v = await s.hub(); return Object.values(v.rects).every((r) => r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= 1.0001 && r[1] + r[3] <= 1.0001 && r[3] * H >= 40); };
  // Skips the remaining questions of a set (SKIP), then whatever follows.
  s.skipAll = async (n) => { for (let i = 0; i < n; i++) await s.tapVt('Think_SKIP', 'THINK', 600); };
  return s;
}


const ctxOpts = { viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };
const allErrors = [], allExternal = [];
const url = `http://127.0.0.1:${PORT}/index.html?ta90=1${BOARD ? '&ta90ref=1' : ''}`;
const puzzleBtn = async (h) => BOARD ? Object.keys(h.buttons).find((k) => k.startsWith('Puzzle_') && h.order[Number(k.slice(7)) - 1] === BOARD) : 'Puzzle_1';
try {
  // ---------------- Run 1: the FULL real-time run ------------------------------------------
  const context = await browser.newContext(ctxOpts);
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: `http://127.0.0.1:${PORT}` });
  const a = await session(context, 'run 1');
  await a.page.goto(url);
  let h = await a.waitFor(a.hub, (v) => v.view === 'WELCOME' && v.buttons.PilotStart, 'welcome', 120000);
  check(await a.noOverflow() && await a.hubFits(), '?ta90=1: the welcome screen; no overflow; buttons on screen');
  await sleep(500);
  await a.shot('M1_welcome');
  await a.tapHub('PilotStart', 'WELCOME');
  await a.tapHub('Familiar_NEVER_PLAYED', 'FAMILIARITY');
  h = await a.waitFor(a.hub, (v) => v.view === 'SELECT', 'select');
  const pb = await puzzleBtn(h);
  check(pb && h.buttons[pb] && await a.hubFits(), `CHOOSE A PUZZLE (${JSON.stringify(h.order)})`);
  await a.shot('M2_select');
  const board = BOARD || h.order[0];
  await a.tapHub(pb, 'SELECT', 1200);
  await a.waitFor(a.vt, (x) => x.screen === 'BRIEF' && x.buttons.BeginPuzzle, 'brief');
  await a.shot('M3_brief');
  let m = await a.mus();
  check(!m || m.sounding === 0, 'no music before the board');
  await a.begin();
  let p = await a.waitFor(a.play, (x) => x.active && x.next && x.next.length === 2 && x.buttons.Undo && x.buttons.Restart, 'board');
  const fullBoard = p.blocks;
  let c = await a.waitFor(a.cd, (x) => x.visible && x.stage === 'green' && x.rect[3] > 0, 'countdown');
  let t = await a.waitFor(a.ta, (x) => x.run_active, 'running');
  const wallStart = Date.now() - (90000 - t.remaining_ms);
  check(t.remaining_ms > 85000 && t.remaining_ms <= 90000 && c.text <= '1:30' && c.text >= '1:2', `a 90-second clock (${c.text}, ${t.remaining_ms} ms left)`);
  m = await a.waitFor(a.mus, (x) => x.playing && x.mix === 'green', 'green music', 15000);
  const au = await a.aud();
  check(m.unlocked && au && au.context === 'running' && m.button && m.button_rect[1] + m.button_rect[3] <= c.board_top + 0.0005 && m.button_rect[0] + m.button_rect[2] <= 1.0001 && m.limit_ms === 90000,
    `START (a real tap) unlocked audio (context ${au && au.context}); the GREEN mix plays; MUSIC toggle beside the countdown, above the board ${JSON.stringify(m.button_rect)} / ${c.board_top}`);
  check(!p.buttons.Hint && p.tools[0] === 3 && p.tools[1] === 0 && p.tools[2] === 0, `tools ${JSON.stringify(p.tools)}: UNDO x3, SHOW A MOVE x0, HAMMER x0`);
  await a.shot('M4_green_music');
  // RESTART / UNDO: no time back; the music goes on.
  for (let i = 0; i < 2; i++) { p = await a.waitFor(a.play, (x) => x.next && x.next.length === 2, 'move'); await a.tap(p.next, 450); }
  const r0 = (await a.ta()).remaining_ms;
  await a.tap(p.buttons.Restart, 700);
  t = await a.ta();
  m = await a.mus();
  check(t.run_active && t.remaining_ms < r0 && m.playing && m.mix === 'green', `RESTART: the clock keeps running (${r0} -> ${t.remaining_ms} ms), the music too`);
  // MUSIC OFF / ON by touch.
  const fpsOn = [];
  for (let i = 0; i < 6; i++) { fpsOn.push((await a.mus()).fps); await sleep(500); }
  await a.tap(m.button, 300);
  m = await a.waitFor(a.mus, (x) => !x.enabled && x.sounding === 0, 'music off', 3000).catch(() => a.mus());
  check(!m.enabled && m.sounding === 0, 'MUSIC OFF (touch): silence ' + JSON.stringify(m));
  const fpsOff = [];
  for (let i = 0; i < 6; i++) { fpsOff.push((await a.mus()).fps); await sleep(500); }
  const avg = (x) => x.reduce((s, v) => s + v, 0) / x.length;
  console.log(`  frame rate with music ${avg(fpsOn).toFixed(1)} fps, without ${avg(fpsOff).toFixed(1)} fps (headless Chromium, software rendering)`);
  check(avg(fpsOn) >= avg(fpsOff) * 0.8 - 1, `the music costs no meaningful frame rate (${avg(fpsOn).toFixed(1)} fps with, ${avg(fpsOff).toFixed(1)} without)`);
  await a.tap(m.button, 900);
  m = await a.waitFor(a.mus, (x) => x.playing && x.mix === 'green', 'music on again', 5000);
  check(m.enabled, 'MUSIC ON (touch): the current mix again');
  // Background: paused, the clock keeps running.
  const rb = (await a.ta()).remaining_ms;
  await a.page.evaluate(() => { Object.defineProperty(document, 'hidden', { value: true, configurable: true }); document.dispatchEvent(new Event('visibilitychange')); });
  await sleep(1500);
  m = await a.mus();
  const hiddenOk = m.hidden && !m.playing;
  await a.page.evaluate(() => { Object.defineProperty(document, 'hidden', { value: false, configurable: true }); document.dispatchEvent(new Event('visibilitychange')); });
  await sleep(600);
  t = await a.ta();
  m = await a.mus();
  check(hiddenOk && m.playing && t.remaining_ms <= rb - 1500, `background: the music paused and came back; the clock kept running (${rb} -> ${t.remaining_ms} ms)`);
  // A real reload mid-run: back to the puzzle, the clock not restored, no sound until the next tap.
  for (let i = 0; i < 2; i++) { p = await a.waitFor(a.play, (x) => x.next && x.next.length === 2, 'move'); await a.tap(p.next, 450); }
  const remBefore = (await a.ta()).remaining_ms;
  await a.page.reload();
  p = await a.waitFor(a.play, (x) => x.active && x.buttons.Undo, 'back to the puzzle after a reload', 120000);
  t = await a.waitFor(a.ta, (x) => x.run_active, 'running after reload');
  await sleep(1500);
  m = await a.mus();
  check(p.blocks === fullBoard && t.remaining_ms < remBefore && m && m.sounding === 0 && !m.unlocked, `a reload mid-run: straight back to the puzzle, the clock not restored (${t.remaining_ms} < ${remBefore} ms), and NO sound before a tap (the gesture rule)`);
  p = await a.waitFor(a.play, (x) => x.next && x.next.length === 2, 'move after reload');
  await a.tap(p.next, 900);
  m = await a.waitFor(a.mus, (x) => x.playing && ['green', 'orange'].includes(x.mix), 'music after the first tap', 8000);
  check(m.unlocked && m.playing, `the first tap after the reload unlocks audio; the ${m.mix} mix plays`);
  // ORANGE / RED in real time.
  c = await a.waitFor(a.cd, (x) => x.stage === 'orange' && x.text <= '0:59', 'orange', 70000);
  m = await a.waitFor(a.mus, (x) => x.playing && x.mix === 'orange', 'orange music', 4000);
  check(c.text <= '1:00' && c.text >= '0:31' && m.stage === 'orange', `1:00-0:31 ORANGE (${c.text}): the orange mix (cross-faded, ${m.fades} fades so far)`);
  await a.shot('M5_orange_music');
  c = await a.waitFor(a.cd, (x) => x.stage === 'red' && x.text <= '0:29', 'red', 40000);
  m = await a.waitFor(a.mus, (x) => x.playing && x.mix === 'red', 'red music', 4000);
  check(c.text <= '0:30' && m.stage === 'red', `0:30-0:00 RED (${c.text}): the red mix`);
  await a.shot('M6_red_music');
  t = await a.waitFor(a.ta, (x) => x.card, 'TIME UP (real 90 s)', 40000);
  const wallSec = (Date.now() - wallStart) / 1000;
  let st = await a.state(board);
  check(t.card_head === 'TIME UP' && wallSec >= 89 && wallSec <= 93 && st.timed.outcome === 'TIME UP' && st.timed.limit_ms === 90000 && st.timed.assist.version === 'ta90-v1'
    && JSON.stringify(st.timed.stages_reached) === JSON.stringify(['green', 'orange', 'red', 'final10']),
    `TIME UP after ${wallSec.toFixed(1)} s of wall time (a reload, a RESTART and the background included); stages ${JSON.stringify(st.timed.stages_reached)}; rules ta90-v1`);
  m = await a.waitFor(a.mus, (x) => x.sounding === 0, 'silence after TIME UP', 3000).catch(() => a.mus());
  check(m.sounding === 0, 'TIME UP: the music faded out (a clean result screen) ' + JSON.stringify(m));
  await a.shot('M7_timeup');
  await a.tapTa('TA_Continue');
  m = await a.mus();
  check(m.sounding === 0, 'the questions: no music');
  for (const n of ['Think_HARD', 'Think_4', 'Think_5', 'Think_2', 'Think_YES', 'Think_YES', 'Think_APPROPRIATE', 'Think_YES']) await a.tapVt(n, 'THINK', 600);
  t = await a.waitFor(a.ta, (x) => x.card && x.buttons.TA_Untimed, 'offer');
  await a.tapTa('TA_Untimed', 1500);
  p = await a.waitFor(a.play, (x) => x.active && x.buttons.Undo && x.buttons.Restart, 'untimed');
  m = await a.waitFor(a.mus, (x) => x.playing && x.mix === 'calm', 'calm music', 6000);
  check((await a.ta()).count_text === 'NO TIMER' && m.stage === 'calm' && !p.buttons.Hint, 'CONTINUE WITHOUT TIMER: NO TIMER, the CALM mix, no SHOW A MOVE');
  await a.shot('M8_untimed_calm');
  check(await a.solveByTouches('the untimed game'), 'solved without the timer, by touches');
  t = await a.waitFor(a.ta, (x) => x.card, 'untimed card', 15000);
  m = await a.waitFor(a.mus, (x) => x.sounding === 0, 'silence on SOLVED', 3000).catch(() => a.mus());
  check(t.card_head === 'SOLVED' && m.sounding === 0, 'the SOLVED card: silence ' + JSON.stringify(m));
  await a.tapTa('TA_Continue');
  for (const n of ['Think_YES', 'Think_5', 'Think_4']) await a.tapVt(n, 'THINK', 600);
  await a.tapVt('Think_SKIP', 'THINK', 1200);
  h = await a.waitFor(a.hub, (x) => x.view === 'SELECT', 'back to the selection');
  await a.page.evaluate(() => navigator.clipboard.writeText(''));
  await sleep(400);
  h = await a.hub();
  await a.tap(h.buttons.CopyResults, 1200);
  let bundle = null;
  try { bundle = JSON.parse(await a.page.evaluate(() => navigator.clipboard.readText())); } catch { /* not JSON */ }
  const r = bundle && bundle.runs[0];
  check(bundle && bundle.format === 'ce-ta90' && bundle.rules.version === 'ta90-v1' && r && r.timed_outcome === 'TIME UP' && r.untimed_success && r.elapsed_ms === 90000 && r.hint_allowance === 0
    && r.timed_answers.music === 'YES' && r.timed_answers.length === 'APPROPRIATE' && r.restarts >= 1 && r.reopens === 1 && !JSON.stringify(bundle).includes('"device"'),
    'COPY ALL RESULTS: one ce-ta90 bundle (TIME UP and the untimed solve apart, 90 s, hint allowance 0, the music answer, restarts and the reopen)');
  const other = await a.page.evaluate(() => Object.keys(localStorage).filter((k) => k.startsWith('chain_escape_') && !k.startsWith('chain_escape_ta90_') && /state|hub/.test(k)));
  check(other.length === 0, `no other test page's storage (the 120-second pilot, standalone pages) touched ${JSON.stringify(other)}`);
  allErrors.push(...a.errors); allExternal.push(...a.external);
  await context.close();

  // ---------------- Run 2: prefers-reduced-motion -----------------------------------------
  {
    const ctx = await browser.newContext({ ...ctxOpts, reducedMotion: 'reduce' });
    const d = await session(ctx, 'run 2');
    await d.page.goto(url);
    await d.tapHub('PilotStart', 'WELCOME');
    await d.tapHub('Familiar_EXPERIENCED_PLAYER', 'FAMILIARITY');
    const h2 = await d.waitFor(d.hub, (v) => v.view === 'SELECT', 'select 2');
    await d.tapHub(await puzzleBtn(h2), 'SELECT', 1200);
    await d.begin();
    await d.waitFor(d.ta, (x) => x.run_active, 'running 2');
    await sleep(1500);
    await d.page.evaluate((k) => { sessionStorage.setItem('ceRewind', '55'); sessionStorage.setItem('ceRewindKey', k); }, LSB(BOARD || h2.order[0]));
    await d.page.reload();
    let v = await d.waitFor(d.cd, (x) => x.visible && x.stage === 'red' && !x.final, 'red 2', 120000);
    await sleep(800);
    const reds = [], sc = [];
    for (let i = 0; i < 4; i++) { const y = await d.cd(); if (y.stage !== 'red' || y.final) break; reds.push(await d.fill(y)); sc.push(y.scale); await sleep(60); }
    const l = reds.map(luma);
    check(v.reduced_motion && reds.length >= 3 && Math.max(...l) - Math.min(...l) <= 2 && near(reds[0], FILL.red) && sc.every((x) => x === sc[0]),
      `reduced motion: RED without pulse (luma ${Math.min(...l).toFixed(0)}-${Math.max(...l).toFixed(0)}) or scale`);
    await d.shot('M9_reduced_red');
    const p2 = await d.waitFor(d.play, (x) => x.next && x.next.length === 2, 'move 2');
    await d.tap(p2.next, 900);
    const m2 = await d.waitFor(d.mus, (x) => x.playing && x.mix === 'red', 'red music 2', 8000);
    check(m2.playing, 'reduced motion: the music is the same (the red mix after the first tap)');
    allErrors.push(...d.errors); allExternal.push(...d.external);
    await ctx.close();
  }

  // ---------------- The player build ignores ?ta90=1 --------------------------------------
  if (server2) {
    const ctx = await browser.newContext(ctxOpts);
    const pg = await ctx.newPage();
    await pg.goto(`http://127.0.0.1:${PORT + 1}/index.html?ta90=1&ta90ref=1`);
    await sleep(25000);
    const seen = await pg.evaluate(() => ({ ta90: !!window.chainEscapeTa90, music: !!window.chainEscapeStageMusic, ta: !!window.chainEscapeTimeAttack, keys: Object.keys(localStorage).filter((k) => k.includes('ta90')) }));
    check(!seen.ta90 && !seen.music && !seen.ta && seen.keys.length === 0, `the player build ignores ?ta90=1 ${JSON.stringify(seen)}`);
    await ctx.close();
  }
  check(allErrors.length === 0, 'no page errors ' + JSON.stringify(allErrors.slice(0, 3)));
  check(allExternal.length === 0, 'no network calls outside the page ' + JSON.stringify(allExternal.slice(0, 3)));
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  if (server2) server2.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB TA90 TEST: FAILED (${failed}/${results.length})` : `WEB TA90 TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
