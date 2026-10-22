// The external Time Attack pilot (?tapilot=1), exported DEVELOPMENT Web
// build, real Chromium at iPhone SE size (375x667), real touches:
//   node tools/web_tapilot_page_test.mjs <dev web build> [--player=<player build>] [--shots=dir]
//   run 1 (never played; the FULL real-time run): welcome -> familiarity ->
//   CHOOSE A PUZZLE -> PUZZLE 1: the card (basic rule), the 2:00 board (no
//   SHOW A MOVE: touches across the tool bar and keys request nothing), a
//   real reload mid-run (straight back to the puzzle, the clock not
//   restored), the real 120 s countdown to TIME UP, the questions (some
//   skipped), CONTINUE WITHOUT TIMER, solved by touches, back to the
//   selection; PUZZLE 4 won in time; browser back / forward; COPY ALL
//   RESULTS (the clipboard holds one bundle with both puzzles); no other
//   page's storage touched; no horizontal overflow; no network calls.
//   run 2 (experienced, prefers-reduced-motion): PUZZLE 3 into the red stage
//   (the saved clock moved back, then a reload), no pulse; TIME UP; FINISH.
//   --player: the player build ignores ?tapilot=1 (no pilot, no dev board).
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
const PORT = 8820, W = 375, H = 667;  // iPhone SE
const LSB = (b) => `chain_escape_tapilot_${b.toLowerCase()}_state`;
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
  const s = { page, errors, external, hub: get('chainEscapeTaPilot'), vt: get('chainEscapeVhTest'), play: get('chainEscapeSocialPlay'), ta: get('chainEscapeTimeAttack'), cd: get('chainEscapeCountdown') };
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
try {
  // ---------------- Run 1: never played; the FULL real-time run ------------------------------
  const context = await browser.newContext(ctxOpts);
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: `http://127.0.0.1:${PORT}` });
  const a = await session(context, 'run 1');
  await a.page.goto(`http://127.0.0.1:${PORT}/index.html?tapilot=1`);
  let h = await a.waitFor(a.hub, (v) => v.view === 'WELCOME' && v.buttons.PilotStart, 'welcome', 120000);
  check(/^[0-9a-f]{16}$/.test(h.session) && h.familiarity === '' && await a.noOverflow() && await a.hubFits(), 'one entry point (?tapilot=1): the welcome screen; an anonymous session id; no horizontal overflow; buttons on screen');
  await sleep(500);
  await a.shot('P1_welcome');
  await a.tapHub('PilotStart', 'WELCOME');
  h = await a.waitFor(a.hub, (v) => v.view === 'FAMILIARITY', 'familiarity');
  check(h.buttons.Familiar_NEVER_PLAYED && h.buttons.Familiar_PLAYED_A_LITTLE && h.buttons.Familiar_EXPERIENCED_PLAYER && await a.hubFits(), 'the one question: never played / played a little / experienced player');
  await a.shot('P2_familiarity');
  await a.tapHub('Familiar_NEVER_PLAYED', 'FAMILIARITY');
  h = await a.waitFor(a.hub, (v) => v.view === 'SELECT', 'select');
  check(h.familiarity === 'NEVER PLAYED' && ['1', '2', '3', '4'].every((n) => h.buttons['Puzzle_' + n] && h.statuses[n] === 'Not played yet') && h.buttons.CopyResults && await a.hubFits() && await a.noOverflow(),
    'CHOOSE A PUZZLE: PUZZLE 1-4 (each "Not played yet"), COPY ALL RESULTS; everything on screen, no overflow');
  await a.shot('P3_select');
  await a.tapHub('Puzzle_1', 'SELECT', 1200);
  let v = await a.waitFor(a.vt, (x) => x.screen === 'BRIEF' && x.buttons.BeginPuzzle && x.buttons.BackToPuzzles, 'brief');
  check(v.buttons.BeginPuzzle[1] < 0.97 && v.buttons.BackToPuzzles[1] < 0.98, 'the card before PUZZLE 1 (the basic rule for a new player): START and BACK TO PUZZLES on screen');
  await a.shot('P4_brief_never_played');
  await a.begin();
  let p = await a.waitFor(a.play, (x) => x.active && x.next && x.next.length === 2 && x.buttons.Undo && x.buttons.Restart, 'board');
  const fullBoard = p.blocks;
  let c = await a.waitFor(a.cd, (x) => x.visible && x.stage === 'green' && x.rect[3] > 0, 'countdown');
  let t = await a.waitFor(a.ta, (x) => x.run_active, 'running');
  const wallStart = Date.now() - (120000 - t.remaining_ms);
  let px = await a.fill(c);
  check(c.stage === 'green' && t.remaining_ms > 115000 && near(px, FILL.green) && c.rect[1] + c.rect[3] <= c.board_top && !p.buttons.Hint && p.tools[0] === 3 && p.tools[1] === 0 && p.tools[2] === 0,
    `PUZZLE 1: the 2:00 GREEN countdown on screen (pixel ${px}) above the board; tools ${JSON.stringify(p.tools)}: UNDO x3, SHOW A MOVE x0, HAMMER x0`);
  check(p.buttons.Undo[1] > c.board_top && p.buttons.Restart[1] > c.board_top && p.buttons.Undo[1] < 0.98 && p.buttons.Restart[1] < 0.98, 'UNDO and RESTART below the board, on screen');
  await a.shot('P5_board_green');
  // Nothing a player can press asks for a move.
  for (const fx of [0.15, 0.5, 0.85]) {
    const y = (p.buttons.Undo[1] + p.buttons.Restart[1]) / 2;
    if (Math.abs(fx - p.buttons.Undo[0]) > 0.12 && Math.abs(fx - p.buttons.Restart[0]) > 0.12) await a.tap([fx, y], 150);
  }
  for (const k of ['Enter', 'Space', 'h']) await a.page.keyboard.press(k);
  await sleep(400);
  let st = await a.state('TA');
  check(!(st.live.record.log || []).some((e) => e[1] === 'h') && st.live.record.assist.show_a_move === 0 && st.live.record.pilot.familiarity === 'NEVER PLAYED' && !st.budget,
    'no SHOW A MOVE through touches or keys; the record: hint allowance 0, the familiarity, the session');
  for (let i = 0; i < 2; i++) { p = await a.waitFor(a.play, (x) => x.next && x.next.length === 2, 'move'); await a.tap(p.next, 500); }
  await a.tap(p.buttons.Restart, 800);
  t = await a.ta();
  check(t.run_active && t.remaining_ms < 118000, `RESTART: the board again, the clock keeps running (${t.remaining_ms} ms left)`);
  for (let i = 0; i < 2; i++) { p = await a.waitFor(a.play, (x) => x.next && x.next.length === 2, 'move'); await a.tap(p.next, 500); }
  const remBefore = (await a.ta()).remaining_ms;
  await a.page.reload();
  p = await a.waitFor(a.play, (x) => x.active && x.buttons.Undo, 'straight back to the puzzle after a reload', 120000);
  t = await a.waitFor(a.ta, (x) => x.run_active, 'running after reload');
  h = await a.hub();
  check(h.view === 'PUZZLE' && h.current === 'TA' && p.blocks === fullBoard && t.remaining_ms < remBefore && !p.buttons.Hint, `a reload mid-run: straight back to PUZZLE 1 (no menu), the clock not restored (${t.remaining_ms} < ${remBefore} ms)`);
  // The real countdown, to TIME UP.
  c = await a.waitFor(a.cd, (x) => x.stage === 'orange', 'orange', 130000);
  await a.shot('P6_orange');
  c = await a.waitFor(a.cd, (x) => x.stage === 'red' && !x.final, 'red', 40000);
  await a.shot('P7_red');
  t = await a.waitFor(a.ta, (x) => x.card, 'TIME UP (real 2 minutes)', 60000);
  const wallSec = (Date.now() - wallStart) / 1000;
  st = await a.state('TA');
  check(t.card_head === 'TIME UP' && wallSec >= 119 && wallSec <= 123 && st.timed.outcome === 'TIME UP' && JSON.stringify(st.timed.stages_reached) === JSON.stringify(['green', 'orange', 'red', 'final10']),
    `TIME UP after ${wallSec.toFixed(1)} s of wall time (a reload and a RESTART included); stages ${JSON.stringify(st.timed.stages_reached)}`);
  await a.shot('P8_timeup');
  await a.tapTa('TA_Continue');
  await a.shot('P9_question');
  for (const n of ['Think_VERY_HARD', 'Think_4', 'Think_SKIP', 'Think_2', 'Think_YES', 'Think_SKIP', 'Think_YES']) await a.tapVt(n, 'THINK', 600);
  t = await a.waitFor(a.ta, (x) => x.card && x.buttons.TA_Untimed && x.buttons.TA_Finish, 'offer');
  await a.shot('P10_offer');
  await a.tapTa('TA_Untimed', 1500);
  p = await a.waitFor(a.play, (x) => x.active && x.buttons.Undo && x.buttons.Restart, 'untimed');
  check((await a.ta()).count_text === 'NO TIMER' && !p.buttons.Hint, 'CONTINUE WITHOUT TIMER: the same puzzle, NO TIMER, no SHOW A MOVE');
  await a.shot('P11_untimed');
  check(await a.solveByTouches('the untimed game'), 'solved without the timer, by touches');
  t = await a.waitFor(a.ta, (x) => x.card, 'untimed card', 15000);
  await a.tapTa('TA_Continue');
  for (const n of ['Think_YES', 'Think_5', 'Think_4']) await a.tapVt(n, 'THINK', 600);
  await a.tapVt('Think_SKIP', 'THINK', 1200);
  h = await a.waitFor(a.hub, (x) => x.view === 'SELECT', 'back to the selection');
  check(h.statuses['1'] === 'Time up - solved without the timer' && h.statuses['4'] === 'Not played yet', 'back to CHOOSE A PUZZLE: PUZZLE 1 "Time up - solved without the timer"');
  await a.shot('P12_select_after_one');
  // PUZZLE 4: a timed WIN.
  await a.tapHub('Puzzle_4', 'SELECT', 1200);
  await a.begin();
  check(await a.solveByTouches('PUZZLE 4'), 'PUZZLE 4 solved by touches');
  t = await a.waitFor(a.ta, (x) => x.card, 'win card', 15000);
  check(t.card_head === 'SOLVED', 'PUZZLE 4: SOLVED in time');
  await a.tapTa('TA_Continue');
  await a.skipAll(7);
  await a.skipAll(3);
  await a.tapVt('Think_SKIP', 'THINK', 1200);
  h = await a.waitFor(a.hub, (x) => x.view === 'SELECT', 'select 2');
  check(h.statuses['4'].startsWith('Solved in ') && h.statuses['1'].startsWith('Time up'), `each puzzle keeps its own result (${h.statuses['1']} / ${h.statuses['4']})`);
  // Browser back / forward: leaving and coming back.
  await a.page.goto('about:blank');
  await a.page.goBack();
  h = await a.waitFor(a.hub, (x) => x.view === 'SELECT', 'select after back', 120000);
  check(h.statuses['4'].startsWith('Solved in ') && h.familiarity === 'NEVER PLAYED', 'browser BACK to the pilot: the selection, results and familiarity kept');
  // COPY ALL RESULTS
  await a.page.evaluate(() => navigator.clipboard.writeText(''));
  await sleep(400);
  h = await a.hub();
  await a.tap(h.buttons.CopyResults, 1200);
  let bundle = null;
  try { bundle = JSON.parse(await a.page.evaluate(() => navigator.clipboard.readText())); } catch { /* not JSON */ }
  const ta = bundle && bundle.runs.find((r) => r.board === 'TA'), s1 = bundle && bundle.runs.find((r) => r.board === 'S1');
  check(bundle && bundle.format === 'ce-tapilot' && bundle.session === h.session && bundle.familiarity === 'NEVER PLAYED' && bundle.runs.length === 2 && ta && s1,
    'COPY ALL RESULTS: the clipboard holds ONE bundle with both puzzles, the session and the familiarity');
  check(ta && ta.timed_outcome === 'TIME UP' && !ta.timed_success && ta.untimed_success && ta.hint_allowance === 0 && ta.restarts === 1 && ta.reopens === 1 && ta.attempts === 3 && ta.moves >= 4
    && ta.timed_answers.first_difficulty === 'VERY HARD' && ta.timed_answers.excite === '' && ta.post_answers.solved === 'YES' && ta.fingerprint && s1 && s1.timed_success && !s1.untimed_played,
    `the bundle keeps timed and untimed apart, with time, attempts, restarts, reopens, moves, blocked taps, hint allowance 0, stages and answers ${JSON.stringify(ta).slice(0, 200)}`);
  const raw = JSON.stringify(bundle || {}).toLowerCase();
  check(!raw.includes('"device"') && !raw.includes('"metrics"') && !raw.includes('"recipe"'), 'the bundle: no device field, no design data');
  h = await a.waitFor(a.hub, (x) => x.copy_status !== '', 'copy status', 5000).catch(() => a.hub());
  check(/^COPIED/.test(h.copy_status || ''), `the player sees the copy confirmation ("${h.copy_status}")`);
  const other = await a.page.evaluate(() => ['q1time', 'ptest11', 'rtime', 'stime', 'tta', 'ttb', 'ttc'].map((k) => localStorage.getItem('chain_escape_' + k + '_state')));
  check(other.every((x) => x === null), "no standalone test page's storage is touched");
  await a.shot('P13_select_copied');
  allErrors.push(...a.errors); allExternal.push(...a.external);
  await context.close();

  // ---------------- Run 2: experienced player, prefers-reduced-motion --------------------------
  {
    const ctx = await browser.newContext({ ...ctxOpts, reducedMotion: 'reduce' });
    const d = await session(ctx, 'run 2');
    await d.page.goto(`http://127.0.0.1:${PORT}/index.html?tapilot=1`);
    await d.tapHub('PilotStart', 'WELCOME');
    await d.tapHub('Familiar_EXPERIENCED_PLAYER', 'FAMILIARITY');
    await d.tapHub('Puzzle_3', 'SELECT', 1200);
    await d.waitFor(d.vt, (x) => x.screen === 'BRIEF', 'brief 3');
    await d.shot('P14_brief_experienced');
    await d.begin();
    await d.waitFor(d.ta, (x) => x.run_active, 'running 3');
    await sleep(1500);
    await d.page.evaluate(() => { sessionStorage.setItem('ceRewind', '80'); sessionStorage.setItem('ceRewindKey', 'chain_escape_tapilot_tc_state'); });
    await d.page.reload();
    let w = await d.waitFor(d.cd, (x) => x.visible && x.stage === 'red' && !x.final, 'red 3', 120000);
    await sleep(1000);  // the resumed board has just been laid out
    w = await d.cd();
    const reds = [], sc = [], rects = [];
    for (let i = 0; i < 4; i++) { const y = await d.cd(); if (y.stage !== 'red' || y.final) break; reds.push(await d.fill(y)); sc.push(y.scale); rects.push(JSON.stringify(y.rect)); await sleep(60); }
    console.log('  reduced-motion samples', JSON.stringify(reds), JSON.stringify(rects));
    const l = reds.map(luma);
    check(w.reduced_motion && reds.length >= 3 && Math.max(...l) - Math.min(...l) <= 2 && near(reds[0], FILL.red) && sc.every((x) => x === sc[0]) && rects.every((x) => x === rects[0]),
      `reduced motion on PUZZLE 3: RED, no pulse (luma ${Math.min(...l).toFixed(0)}-${Math.max(...l).toFixed(0)}), no scale`);
    await d.shot('P15_reduced_red');
    const tu = await d.waitFor(d.ta, (x) => x.card, 'time up 3', 40000);
    const s3 = await d.state('TC');
    check(tu.card_head === 'TIME UP' && s3.timed.reduced_motion === true && s3.timed.pilot.familiarity === 'EXPERIENCED PLAYER', 'TIME UP; reduced motion and the familiarity recorded');
    await d.tapTa('TA_Continue');
    await d.skipAll(7);
    await d.tapTa('TA_Finish');
    await d.skipAll(3);
    await d.tapVt('Think_SKIP', 'THINK', 1200);
    const h3 = await d.waitFor(d.hub, (x) => x.view === 'SELECT', 'select 3');
    check(h3.statuses['3'] === 'Time up' && h3.statuses['1'] === 'Not played yet', 'FINISH (no untimed play): PUZZLE 3 "Time up"; the other puzzles untouched');
    allErrors.push(...d.errors); allExternal.push(...d.external);
    await ctx.close();
  }

  // ---------------- The player build ignores ?tapilot=1 ----------------------------------------
  if (server2) {
    const ctx = await browser.newContext(ctxOpts);
    const pg = await ctx.newPage();
    await pg.goto(`http://127.0.0.1:${PORT + 1}/index.html?tapilot=1`);
    await sleep(25000);
    const seen = await pg.evaluate(() => ({ pilot: !!window.chainEscapeTaPilot, vt: !!window.chainEscapeVhTest, ta: !!window.chainEscapeTimeAttack, keys: Object.keys(localStorage).filter((k) => k.includes('tapilot')) }));
    await pg.screenshot({ path: shots ? path.join(shots, 'P16_player_build_ignores_tapilot.png') : '/dev/null' }).catch(() => {});
    check(!seen.pilot && !seen.vt && !seen.ta && seen.keys.length === 0, `the player build ignores ?tapilot=1 ${JSON.stringify(seen)}`);
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
  console.log(failed ? `WEB TAPILOT TEST: FAILED (${failed}/${results.length})` : `WEB TAPILOT TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
