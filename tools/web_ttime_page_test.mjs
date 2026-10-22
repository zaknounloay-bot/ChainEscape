// The THREE phase-11 blind tests (?tta=1 / ?ttb=1 / ?ttc=1), ONE per run, on
// the same staged 2-minute clock (tools/web_stime_page_test.mjs adapted to
// their question sets), exported DEVELOPMENT Web build:
//   node tools/web_ttime_page_test.mjs <web build dir> --key=tta [--shots=dir] [--fast] [--bench-out=file]
// Also: the other two tests' and every earlier page's storage stay untouched.
// Real Chromium at iPhone SE size (375x667), real touches. The countdown's
// colours are read from the SCREEN (pixels of a screenshot), not only from
// the page's own state.
//   run 1: neutral intro; 2:00 GREEN; a real reload (clock not restored, still
//   no SHOW A MOVE); the real countdown through ORANGE (1:00), RED (0:30)
//   and the last 10 s (pulse sampled from pixels: it only darkens) with a
//   screenshot of each stage; the pill never over the board, the board never
//   moving; TIME UP after 120 s of wall time; the timed questions (incl. the
//   colour questions); CONTINUE WITHOUT TIMER; a reload in the untimed game;
//   solved by touches; the puzzle questions; separate records; the stages
//   reached in the frozen timed record.
//   run 2 (fresh profile): a timed WIN, no offer.
//   run 3 (prefers-reduced-motion): the same stages, no pulse, no scale.
//   bench: SHOW A MOVE / verify timing in the WebAssembly build.
// --fast: the saved clock is moved back at the reload (the stages are still
// reached in real time, from about 0:50). The FULL run is the one that counts.
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
const FAST = process.argv.includes('--fast');
const KEY = (process.argv.find((a) => a.startsWith('--key=')) || '--key=tta').slice(6);
const LETTER = { tta: 'A', ttb: 'B', ttc: 'C' }[KEY];
const PORT = 8800 + ['tta', 'ttb', 'ttc'].indexOf(KEY), W = 375, H = 667;  // iPhone SE
const LS = `chain_escape_${KEY}_state`;
const FILL = { green: [0x1e, 0x7b, 0x34], orange: [0xc2, 0x41, 0x0c], red: [0xb9, 0x1c, 0x1c] };
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(root, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(PORT);
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
  // The one known, harmless engine notice of the shared question screen
  // (an answer button removed in its own press handler) is not an error.
  page.on('console', (m) => { if (/SCRIPT ERROR|ERROR:|Invalid/.test(m.text()) && !m.text().includes('Condition "!is_inside_tree()" is true')) errors.push(m.text().slice(0, 300)); });
  page.on('request', (r) => { if (!r.url().startsWith(`http://127.0.0.1:${PORT}/`)) external.push(r.url()); });
  await page.addInitScript(() => {
    window.ceTestHooks = true;
    const back = Number(sessionStorage.getItem('ceRewind') || 0);
    const k = 'chain_escape_' + (new URLSearchParams(location.search).has('ttb') ? 'ttb' : new URLSearchParams(location.search).has('ttc') ? 'ttc' : 'tta') + '_state';
    if (back > 0 && localStorage.getItem(k)) {
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
  const s = { page, errors, external, vt: get('chainEscapeVhTest'), play: get('chainEscapeSocialPlay'), ta: get('chainEscapeTimeAttack'), cd: get('chainEscapeCountdown') };
  s.waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(100); }
    throw new Error(`${label}: timeout ${what} ${JSON.stringify(v).slice(0, 300)}`);
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  s.tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(80); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  s.shot = async (n) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, LETTER + '_' + n + '.png') }); } };
  s.tapVt = async (name, screen, after) => { const v = await s.waitFor(s.vt, (v) => v.screen === screen && v.buttons[name], name); await s.tap(v.buttons[name], after); };
  s.tapTa = async (name, after = 900) => { await sleep(400); const x = await s.waitFor(s.ta, (v) => v.buttons && v.buttons[name], name); await s.tap(x.buttons[name], after); };
  s.state = async () => JSON.parse(await page.evaluate((k) => localStorage.getItem(k), LS) || '{}');
  s.enter = async () => { await s.tapVt('Start', 'INTRO', 900); await s.tapVt('BeginPuzzle', 'BRIEF', 1500); };
  // The pill's fill as DRAWN: the average of a small patch at its right end
  // (between the digits and the rounded edge), from a screenshot.
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
  return s;
}

const ctxOpts = { viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };
const allErrors = [], allExternal = [];
try {
  // ---------------- Run 1: the full run --------------------------------------------------
  const context = await browser.newContext(ctxOpts);
  const a = await session(context, 'run 1');
  await a.page.goto(`http://127.0.0.1:${PORT}/index.html?${KEY}=1`);
  await a.waitFor(a.vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  let t = await a.waitFor(a.ta, (v) => v.board_ok !== undefined, 'snapshot');
  check(t.board_ok, 'the exact new board (fingerprint checked by the page)');
  await sleep(600);
  await a.shot('S1_intro');
  await a.enter();
  let p = await a.waitFor(a.play, (x) => x.active && x.next && x.next.length === 2 && x.buttons.Undo && x.buttons.Restart, 'board');
  const fullBoard = p.blocks;
  let c = await a.waitFor(a.cd, (v) => v.visible && v.stage === 'green' && v.rect[3] > 0, 'countdown');
  t = await a.waitFor(a.ta, (v) => v.run_active, 'running');
  const wallStart = Date.now() - (120000 - t.remaining_ms);
  c = await a.cd();
  const rect0 = c.rect, boardTop0 = c.board_top;
  let px = await a.fill(c);
  check(c.stage === 'green' && c.icon === 'green' && c.weight === 700 && t.remaining_ms > 115000 && near(px, FILL.green),
    `2:00: a GREEN pill on screen (pixel ${px}), clock icon, weight 700 (${c.text})`);
  check(rect0[1] + rect0[3] <= boardTop0 && rect0[1] > 0.05 && rect0[2] > 0.4 && rect0[3] > 0.06, `the pill sits between the top bar and the board, never over it (pill ${rect0.map((v) => v.toFixed(3))}, board top ${boardTop0})`);
  await a.shot('S2_green');
  // Phase 12B: no SHOW A MOVE. Only UNDO and RESTART on screen; nothing a
  // player can press (touches across the tool bar, Enter / Space / H keys)
  // shows a move or is logged as a request.
  const noHint = async (what) => {
    const q = await a.play();
    const bar = [q.buttons.Undo, q.buttons.Restart];
    for (const fx of [0.15, 0.35, 0.5, 0.65, 0.85]) {
      const y = (bar[0][1] + bar[1][1]) / 2;
      if (Math.abs(fx - bar[0][0]) > 0.12 && Math.abs(fx - bar[1][0]) > 0.12) await a.tap([fx, y], 150);
    }
    for (const k of ['Enter', 'Space', 'h', 'H']) await a.page.keyboard.press(k);
    await sleep(400);
    const q2 = await a.play();
    const s9 = await a.state();
    const rec = (s9.live && s9.live.record) || {};
    check(!q2.buttons.Hint && q2.hints_left === 0 && q2.tools[1] === 0 && q2.tools[0] === 3 && q2.tools[2] === 0 && !(rec.log || []).some((e) => e[1] === 'h')
      && !(s9.budget) && (rec.assist || {}).show_a_move === 0,
      `${what}: no SHOW A MOVE control (tools ${JSON.stringify(q2.tools)}: UNDO x3, SHOW A MOVE x0, HAMMER x0); touches and keys request nothing; the record says show_a_move 0`);
  };
  await noHint('timed run');
  for (let i = 0; i < 2; i++) { p = await a.waitFor(a.play, (x) => x.next && x.next.length === 2, 'move'); await a.tap(p.next, 500); }
  // A real reload in the timed game.
  const remBefore = (await a.ta()).remaining_ms;
  if (FAST) await a.page.evaluate(() => sessionStorage.setItem('ceRewind', '30'));
  await a.page.reload();
  await a.waitFor(a.vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro after reload', 120000);
  await a.enter();
  p = await a.waitFor(a.play, (x) => x.active && x.buttons.Undo && x.buttons.Restart, 'timed after reload');
  t = await a.waitFor(a.ta, (v) => v.run_active || v.card, 'timed running after reload');
  let st = await a.state();
  check(p.blocks === fullBoard && t.remaining_ms < remBefore && p.hints_left === 0 && !p.buttons.Hint && st.live.record.log.some((e) => e[1] === 'o'),
    `reload in the timed game: the board from the start (logged), the clock not restored (${t.remaining_ms} < ${remBefore} ms), still no SHOW A MOVE`);
  for (let i = 0; i < 2; i++) { p = await a.waitFor(a.play, (x) => x.next && x.next.length === 2, 'move'); await a.tap(p.next, 500); }
  const blocksAt = (await a.play()).blocks;
  // The stages, on screen, in real time.
  let steady = true;
  const atStage = async (pred, what, ms) => {
    const v = await a.waitFor(a.cd, pred, what, ms);
    steady = steady && (v.final || v.rect.every((x, i) => Math.abs(x - rect0[i]) < 0.002)) && Math.abs(v.board_top - boardTop0) < 0.001 && v.rect[1] + v.rect[3] <= v.board_top;
    return v;
  };
  c = await atStage((v) => v.text === '1:01' || v.text === '1:00', '1:01 / 1:00', 130000);
  check((c.text === '1:01' && c.stage === 'green') || (c.text === '1:00' && c.stage === 'orange'), `the 1:00 threshold: ${c.text} is ${c.stage}`);
  c = await atStage((v) => v.stage === 'orange' && v.text <= '0:58', 'orange', 10000);
  px = await a.fill(c);
  check(c.stage === 'orange' && c.icon === 'orange' && c.weight === 800 && near(px, FILL.orange), `1:00-0:31: ORANGE on screen (pixel ${px}), half-filled clock, weight 800`);
  await a.shot('S3_orange');
  c = await atStage((v) => v.text === '0:31' || v.text === '0:30', '0:31 / 0:30', 40000);
  check((c.text === '0:31' && c.stage === 'orange') || (c.text === '0:30' && c.stage === 'red'), `the 0:30 threshold: ${c.text} is ${c.stage}`);
  c = await atStage((v) => v.stage === 'red' && !v.final && v.text <= '0:28', 'red', 10000);
  // The pulse, from pixels: it varies, and is never lighter than the resting red.
  const reds = [];
  const redT0 = Date.now();
  for (let i = 0; i < 6; i++) { const v = await a.cd(); reds.push(await a.fill(v)); await sleep(60); }
  console.log(`  (6 pixel samples took ${((Date.now() - redT0) / 1000).toFixed(1)} s)`);
  const lumas = reds.map(luma);
  check(c.stage === 'red' && c.icon === 'red' && c.weight === 900 && reds.every((x) => x[0] > x[1] + 60 && x[0] > x[2] + 60) && Math.max(...lumas) <= luma(FILL.red) + 6 && Math.max(...lumas) - Math.min(...lumas) > 4,
    `0:30-0:11: RED on screen, warning icon, weight 900; a gentle pulse (luma ${Math.min(...lumas).toFixed(0)}-${Math.max(...lumas).toFixed(0)}, never above the resting ${luma(FILL.red).toFixed(0)})`);
  await a.shot('S4_red');
  c = await atStage((v) => v.final, 'last 10 s', 30000);
  const scales = [];
  for (let i = 0; i < 8; i++) { scales.push((await a.cd()).scale); await sleep(120); }
  check(c.final && c.icon === 'red_final' && Math.max(...scales) > Math.min(...scales) + 0.005, `the last 10 s: filled warning icon, a slightly stronger pulse (scale ${Math.min(...scales).toFixed(3)}-${Math.max(...scales).toFixed(3)}), no flash`);
  await a.shot('S5_final10');
  check(steady, 'no layout shift through the run: the pill keeps its place and size (except the last-10-s breathing), the board never moves, the pill never over the board');
  t = await a.waitFor(a.ta, (v) => v.card, 'TIME UP (real 2 minutes)', 30000);
  const wallSec = (Date.now() - wallStart) / 1000;
  check(t.card_head === 'TIME UP' && (FAST || (wallSec >= 119 && wallSec <= 123)), `TIME UP after the countdown (${FAST ? 'clock moved back 30 s at the reload' : wallSec.toFixed(1) + ' s of wall time from 2:00, a reload included'})`);
  st = await a.state();
  check(st.timed && st.timed.outcome === 'TIME UP' && st.timed.completed === false && st.timed.remaining_ms === 0 && st.timed.limit_ms === 120000 && st.phase === 'timed_q'
    && JSON.stringify(st.timed.stages_reached) === JSON.stringify(['green', 'orange', 'red', 'final10']) && st.timed.reduced_motion === false,
    `the timed result frozen: TIME UP at 120 s, the stages reached ${JSON.stringify(st.timed && st.timed.stages_reached)}`);
  await a.shot('S6_timeup');
  await a.tapTa('TA_Continue');
  await a.shot('S6b_first_difficulty');
  for (const n of ['Think_VERY_HARD', 'Think_3', 'Think_4', 'Think_2', 'Think_YES', 'Think_APPROPRIATE', 'Think_YES', 'Think_YES']) await a.tapVt(n, 'THINK', 600);
  t = await a.waitFor(a.ta, (v) => v.card && v.buttons.TA_Untimed && v.buttons.TA_Finish, 'offer');
  await a.shot('S7_offer');
  st = await a.state();
  const ans = st.timed.answers || {};
  check(st.phase === 'offer' && ans.first_difficulty === 'VERY HARD' && ans.enjoy === '3' && ans.excite === '4' && ans.frustrate === '2' && ans.timer_better === 'YES' && ans.length === 'APPROPRIATE'
    && ans.noticed_colours === 'YES' && ans.another === 'YES', `the timed questions (first-exposure difficulty first) stored with the timed record, before the offer ${JSON.stringify(ans)}`);
  await a.tapTa('TA_Untimed', 1500);
  p = await a.waitFor(a.play, (x) => x.active && x.buttons.Undo && x.buttons.Restart, 'untimed board');
  await noHint('untimed game');
  t = await a.ta();
  c = await a.cd();
  check(t.count_text === 'NO TIMER' && c.text === 'NO TIMER' && (st.offer.from !== 'timeout_state' || p.blocks === blocksAt), `untimed: NO TIMER; ${st.offer.from === 'timeout_state' ? 'the position at 0:00 (' + p.blocks + ' blocks)' : 'a fresh board (the 0:00 position was lost)'}`);
  await a.shot('S8_untimed');
  await a.tap((await a.waitFor(a.play, (x) => x.next && x.next.length === 2, 'move u')).next, 600);
  const blocksBefore = (await a.play()).blocks;
  await a.page.reload();
  await a.waitFor(a.vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro after reload', 120000);
  await a.enter();
  p = await a.waitFor(a.play, (x) => x.active && x.buttons.Undo && x.buttons.Restart, 'untimed after reload', 15000);
  st = await a.state();
  check(st.phase === 'untimed' && p.blocks === blocksBefore && (await a.ta()).count_text === 'NO TIMER', `reload in the untimed game: the position rebuilt (${p.blocks} blocks)`);
  check(await a.solveByTouches('the untimed game'), 'solved without the timer, by touches');
  t = await a.waitFor(a.ta, (v) => v.card, 'untimed result card', 15000);
  check(t.card_head === 'SOLVED', 'the untimed SOLVED card');
  await a.tapTa('TA_Continue');
  await a.shot('S9_difficulty');
  for (const n of ['Think_YES', 'Think_4', 'Think_5', 'Think_YES', 'Think_A_LITTLE']) await a.tapVt(n, 'THINK', 600);
  await a.tapVt('Think_SKIP', 'THINK', 1200);
  await a.waitFor(a.vt, (v) => v.screen === 'RESULTS', 'results');
  st = await a.state();
  const r = (st.results || [])[0] || {};
  check(r.timed && r.timed.outcome === 'TIME UP' && r.untimed && r.untimed.continued && r.untimed.completed && r.untimed.record && r.untimed.record.log[0][1] === 'c'
    && r.timed.assist.show_a_move === 0 && r.timed.assist.version === 'ta120-v2' && r.untimed.record.assist.show_a_move === 0 && !r.timed.log.some((e) => e[1] === 'h') && !r.untimed.record.log.some((e) => e[1] === 'h')
    && r.untimed.reopens === 1 && r.puzzle_answers.solved === 'YES' && r.puzzle_answers.achieve === '4' && r.puzzle_answers.enjoy_puzzle === '5' && r.puzzle_answers.insight === 'YES'
    && r.puzzle_answers.combo === 'A LITTLE' && r.puzzle_answers._after === 'untimed play (solved)' && !('first_difficulty' in r.puzzle_answers) && r.timed.answers.first_difficulty === 'VERY HARD' && r.id === 'T' + LETTER,
    'results: the timed TIME UP and the untimed completion in separate records; first-exposure rating with the timed record, post-play answers apart');
  const other = await a.page.evaluate((key) => ['q1time', 'ptest11', 'xtest8', 'rtime', 'stime', 'tta', 'ttb', 'ttc'].filter((k) => k !== key).map((k) => localStorage.getItem('chain_escape_' + k + '_state')), KEY);
  check(other.every((x) => x === null), "the other tests' storage (the other two boards, ?stime, ?rtime ...) is untouched");
  const seen = await a.page.evaluate(() => JSON.stringify(window.chainEscapeVhTest || {}));
  check(!/T[ABC]/.test(seen.replace('T' + LETTER, '')), 'only this test\'s board id appears on the page');
  allErrors.push(...a.errors); allExternal.push(...a.external);
  await context.close();

  // ---------------- Run 2: a timed WIN ---------------------------------------------------
  {
    const ctx2 = await browser.newContext(ctxOpts);
    const b = await session(ctx2, 'run 2');
    await b.page.goto(`http://127.0.0.1:${PORT}/index.html?${KEY}=1`);
    await b.waitFor(b.vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro 2', 120000);
    await b.enter();
    check(await b.solveByTouches('the timed game'), 'run 2: solved by touches within the time');
    const y = await b.waitFor(b.ta, (z) => z.card, 'win card', 15000);
    const s2 = await b.state();
    check(y.card_head === 'SOLVED' && s2.timed && s2.timed.outcome === 'COMPLETED' && s2.timed.remaining_ms > 0 && s2.timed.stages_reached[0] === 'green',
      `a timed WIN (${s2.timed && s2.timed.remaining_ms} ms left; stages ${JSON.stringify(s2.timed && s2.timed.stages_reached)})`);
    allErrors.push(...b.errors); allExternal.push(...b.external);
    await ctx2.close();
  }

  // ---------------- Run 3: prefers-reduced-motion ----------------------------------------
  {
    const ctx3 = await browser.newContext({ ...ctxOpts, reducedMotion: 'reduce' });
    const d = await session(ctx3, 'run 3');
    await d.page.goto(`http://127.0.0.1:${PORT}/index.html?${KEY}=1`);
    await d.waitFor(d.vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro 3', 120000);
    await d.enter();
    await d.waitFor(d.ta, (v) => v.run_active, 'running 3');
    // Into the red stage: the saved clock moved back 95 s, then a reload.
    await sleep(1500);
    await d.page.evaluate(() => sessionStorage.setItem('ceRewind', '80'));
    await d.page.reload();
    await d.waitFor(d.vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro 3b', 120000);
    await d.enter();
    let v = await d.waitFor(d.cd, (x) => x.visible && x.stage === 'red' && !x.final, 'red 3', 20000);
    const reds = [];
    const sc = [];
    for (let i = 0; i < 4; i++) { const w = await d.cd(); if (w.stage !== 'red' || w.final) break; reds.push(await d.fill(w)); sc.push(w.scale); await sleep(60); }
    const l = reds.map(luma);
    check(v.reduced_motion && v.icon === 'red' && v.weight === 900 && reds.length >= 3 && Math.max(...l) - Math.min(...l) <= 2 && near(reds[0], FILL.red) && sc.every((x) => x === sc[0]),
      `reduced motion: RED, warning icon, weight 900 - no pulse on screen (luma ${Math.min(...l).toFixed(0)}-${Math.max(...l).toFixed(0)}), no scale`);
    await d.shot('S10_reduced_red');
    v = await d.waitFor(d.cd, (x) => x.final, 'final 3', 25000);
    const sc2 = [];
    for (let i = 0; i < 6; i++) { sc2.push((await d.cd()).scale); await sleep(120); }
    check(v.icon === 'red_final' && sc2.every((x) => x === sc2[0]), 'reduced motion, last 10 s: the filled warning icon, still no pulse or scale');
    const s3 = await d.waitFor(d.ta, (x) => x.card, 'time up 3', 20000);
    const st3 = await d.state();
    check(s3.card_head === 'TIME UP' && st3.timed && st3.timed.reduced_motion === true, `reduced motion is recorded with the timed result (${JSON.stringify(st3.timed && st3.timed.reduced_motion)}, phase ${st3.phase})`);
    allErrors.push(...d.errors); allExternal.push(...d.external);
    await ctx3.close();
  }

  // ---------------- WebAssembly timing ---------------------------------------------------
  const bench = {};
  for (const rate of [1, 4, 6]) {
    const ctx = await browser.newContext(ctxOpts);
    const pg = await ctx.newPage();
    const cd = await ctx.newCDPSession(pg);
    await pg.goto(`http://127.0.0.1:${PORT}/index.html?${KEY}=1&bench=1`);
    await cd.send('Emulation.setCPUThrottlingRate', { rate });
    const b = await (async () => {
      const end = Date.now() + 600000; let x = null;
      while (Date.now() < end) { x = await pg.evaluate(() => window.chainEscapeVhBench || null).catch(() => null); if (x && x.done) return x; await sleep(500); }
      throw new Error('bench timeout');
    })();
    bench['x' + rate] = b.results;
    const worst = (k) => Math.max(...b.results.map((r) => r[k] || 0));
    console.log(`bench x${rate}: verify max ${worst('verify_ms').toFixed(1)} ms, SHOW A MOVE max ${worst('hint_ms').toFixed(1)} ms, after a mistake max ${worst('dead_hint_ms').toFixed(1)} ms`);
    check(b.results.length === 1 && b.results.every((r) => r.dead_hint_ms !== undefined)
      && (rate !== 1 || Math.max(worst('verify_ms'), worst('hint_ms'), worst('dead_hint_ms')) <= 40), `bench x${rate}: the board timed${rate === 1 ? ' (within 40 ms, desktop WebAssembly)' : ' (reported: a desktop simulation)'}`);
    await ctx.close();
  }
  if (benchOut) fs.writeFileSync(benchOut, JSON.stringify(bench, null, 1));
  check(allErrors.length === 0, 'no page errors ' + JSON.stringify(allErrors.slice(0, 3)));
  check(allExternal.length === 0, 'no network calls outside the page ' + JSON.stringify(allExternal.slice(0, 3)));
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB TTIME PAGE TEST ${KEY}: FAILED (${failed}/${results.length})` : `WEB TTIME PAGE TEST ${KEY}: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
