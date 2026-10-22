// 3-MINUTE CHALLENGE page (?q1time=1) in an exported DEVELOPMENT Web build:
//   node tools/web_q1time_page_test.mjs <web build dir> [--shots=dir]
// Real Chromium at iPhone SE size, real touches:
//   run 1: the countdown runs from the board's first frame; RESTART and SHOW
//   A MOVE do not stop or reset it; the page in the background (a
//   visibilitychange) and a FROZEN page (the CDP lifecycle freeze, as Safari
//   suspends a page) both keep counting; a real page RELOAD gives no time
//   back and keeps SHOW A MOVE spent; the puzzle solved by touches -> SOLVED
//   card -> the seven questions -> results; a NEW RUN starts at 3:00.
//   run 2 (fresh profile): a REAL full 180 s countdown -> the warning colour
//   in the last 30 s -> TIME UP, the board covered, recorded as not completed.
// The other test pages' storage untouched; no page errors, no network calls.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const root = path.resolve(process.argv[2] || 'build/web');
const shots = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
const benchOut = (process.argv.find((a) => a.startsWith('--bench-out=')) || '').slice(12);
const PORT = 8793, W = 375, H = 667;  // iPhone SE
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

try {
  const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const page = await context.newPage();
  const errors = [];
  const external = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('request', (r) => { if (!r.url().startsWith(`http://127.0.0.1:${PORT}/`)) external.push(r.url()); });
  await page.addInitScript(() => { window.ceTestHooks = true; });
  const cdp = await context.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const vt = get('chainEscapeVhTest'), play = get('chainEscapeSocialPlay');
  const waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(150); }
    throw new Error('timeout ' + what + ' ' + JSON.stringify(v).slice(0, 300));
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  const tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(80); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  const shot = async (n) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, n + '.png') }); } };
  const tapVt = async (name, screen, after) => { const v = await waitFor(vt, (v) => v.screen === screen && v.buttons[name], name); await tap(v.buttons[name], after); };
  const solveByTouches = async (what) => {
    for (let i = 0; i < 80; i++) {
      const p = await waitFor(play, (p) => p.completed || (p.active && p.next && p.next.length === 2), what);
      if (p.completed) return true;
      await tap(p.next, 450);
    }
    return false;
  };

  const LS = 'chain_escape_q1time_state';
  const ta = get('chainEscapeTimeAttack');
  const state = async (pg = page) => JSON.parse(await pg.evaluate((k) => localStorage.getItem(k), LS) || '{}');
  const tapTa = async (name, after = 900) => { const x = await waitFor(ta, (v) => v.buttons && v.buttons[name], name); await tap(x.buttons[name], after); };
  const enter = async () => {
    await tapVt('Start', 'INTRO', 900);
    await tapVt('BeginPuzzle', 'BRIEF', 1500);
    await waitFor(play, (p) => p.active && p.next && p.next.length === 2 && p.buttons.Hint, 'board');
  };
  await page.goto(`http://127.0.0.1:${PORT}/index.html?q1time=1`);
  await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  let t = await waitFor(ta, (v) => v.board_ok !== undefined, 'time attack snapshot');
  check(t.board_ok, 'the exact Q1 board (fingerprint checked by the page)');
  await sleep(600);
  await shot('T1_intro');
  await enter();
  t = await waitFor(ta, (v) => v.run_active && v.count_bottom > 0, 'running');
  let v = await vt();
  check(t.count_bottom <= t.board_top && v.hud_bottom <= v.board_top, `countdown (bottom ${t.count_bottom}) and GIVE UP above the board (top ${t.board_top})`);
  await shot('T2_board');
  t = await ta();
  const r0 = t.remaining_ms, w0 = Date.now();
  await sleep(2000);
  t = await ta();
  const drop = r0 - t.remaining_ms, wall = Date.now() - w0;
  check(Math.abs(drop - wall) <= 300, `countdown accuracy: ${drop} ms counted over ${wall} ms (${t.count_text})`);
  let p = await play();
  await tap(p.next, 500);
  p = await play();
  const beforeRestart = (await ta()).remaining_ms;
  await tap(p.buttons.Restart, 1200);
  p = await waitFor(play, (x) => x.plays === 2, 'restart');
  t = await ta();
  check(t.remaining_ms < beforeRestart && t.run_active, `RESTART resets the board, not the clock (${beforeRestart} -> ${t.remaining_ms} ms left)`);
  const beforeHint = t.remaining_ms;
  await tap(p.buttons.Hint, 1200);
  p = await waitFor(play, (x) => x.hints_left === 0, 'hint spent');
  t = await ta();
  check(t.remaining_ms <= beforeHint - 1000, 'SHOW A MOVE spent; the clock keeps running');
  // Background: visibilitychange (hidden 1.5 s), then a frozen page (3 s).
  await page.evaluate(() => { Object.defineProperty(document, 'hidden', { value: true, configurable: true }); document.dispatchEvent(new Event('visibilitychange')); });
  await sleep(1500);
  await page.evaluate(() => { Object.defineProperty(document, 'hidden', { value: false, configurable: true }); document.dispatchEvent(new Event('visibilitychange')); });
  await sleep(500);
  let st = await state();
  check(st.run && st.run.hidden_count === 1 && st.run.hidden_ms >= 1400, `background recorded (${st.run && st.run.hidden_ms} ms), not paused`);
  const beforeFreeze = (await ta()).remaining_ms;
  const wf = Date.now();
  await cdp.send('Page.setWebLifecycleState', { state: 'frozen' });
  await sleep(3000);
  await cdp.send('Page.setWebLifecycleState', { state: 'active' });
  await sleep(800);
  t = await ta();
  check(beforeFreeze - t.remaining_ms >= (Date.now() - wf) - 400, `a frozen (suspended) page: ${beforeFreeze - t.remaining_ms} ms counted over ${Date.now() - wf} ms`);
  // A real reload.
  const beforeReload = t.remaining_ms;
  const wr = Date.now();
  await page.reload();
  v = await waitFor(vt, (x) => x.screen === 'INTRO' && x.buttons.Start, 'intro after reload', 120000);
  await enter();
  t = await waitFor(ta, (x) => x.run_live, 'running after reload');
  p = await play();
  check(t.remaining_ms <= beforeReload - (Date.now() - wr) + 500 && p.hints_left === 0, `after a reload: ${t.remaining_ms} ms left (was ${beforeReload} before ${Date.now() - wr} ms of reloading); SHOW A MOVE still spent`);
  check(await solveByTouches('the puzzle'), 'solved by real touches');
  t = await waitFor(ta, (x) => x.card, 'result card', 15000);
  check(t.card_head === 'SOLVED', 'the SOLVED card (no popup during play)');
  await shot('T3_solved');
  await tapTa('TA_Continue');
  for (const n of ['Think_4', 'Think_5', 'Think_2', 'Think_YES', 'Think_MAYBE', 'Think_ABOUT_RIGHT']) await tapVt(n, 'THINK', 600);
  await shot('T4_feedback');
  await tapVt('Think_SKIP', 'THINK', 1200);
  await waitFor(vt, (x) => x.screen === 'RESULTS', 'results');
  st = await state();
  const r = (st.results || [])[0] || {};
  check(r.outcome === 'COMPLETED' && r.remaining_ms > 0 && r.elapsed_ms + r.remaining_ms === 180000 && r.attempts === 3 && r.restarts === 1 && r.reopens === 1
    && r.interrupted === true && r.hidden_count >= 1 && r.show_a_move === 1 && r.hint_presses === 1 && 'blocked_taps' in r && r.max_cleared === 13 && r.log.some((e) => e[1] === 'o'),
    `recorded: COMPLETED, ${r.elapsed_ms} ms used, ${r.remaining_ms} left, attempts ${r.attempts} (restart, reopen), interrupted, SHOW A MOVE 1 ` + JSON.stringify({ o: r.outcome, a: r.attempts, rs: r.restarts, ro: r.reopens, i: r.interrupted, h: r.hidden_count, s: r.show_a_move, hp: r.hint_presses, mc: r.max_cleared }));
  check(r.enjoy === '4' && r.excite === '5' && r.frustrate === '2' && r.timer_better === 'YES' && r.again === 'MAYBE' && r.length === 'ABOUT RIGHT' && r.feedback === '',
    'answers: enjoyment, excitement, frustration, timer, again, length, free text (skipped)');
  await shot('T5_results');
  await tapTa('NewRun', 1200);
  await tapVt('BeginPuzzle', 'BRIEF', 1500);
  t = await waitFor(ta, (x) => x.run_active && x.run_live, 'new run');
  p = await play();
  check(t.remaining_ms > 175000 && p.hints_left === 1, `a NEW run: ${t.count_text} and a fresh SHOW A MOVE`);
  const other = await page.evaluate(() => ['ptest11', 'xtest5', 'xtest6', 'xtest7', 'xtest8', 'vhval3', 'vhtest4'].map((k) => localStorage.getItem('chain_escape_' + k + '_state')));
  check(other.every((x) => x === null), "the other test pages' storage is untouched");
  // Run 2: a real 3-minute countdown to TIME UP.
  {
    const ctx2 = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const pg2 = await ctx2.newPage();
    await pg2.addInitScript(() => { window.ceTestHooks = true; });
    pg2.on('pageerror', (e) => errors.push(e.message));
    const cdp2 = await ctx2.newCDPSession(pg2);
    const g2 = (n) => () => pg2.evaluate((k) => window[k] || null, n).catch(() => null);
    const vt2 = g2('chainEscapeVhTest'), ta2 = g2('chainEscapeTimeAttack'), play2 = g2('chainEscapeSocialPlay');
    const tap2 = async (q, after = 700) => {
      for (const type of ['touchStart', 'touchEnd']) {
        await cdp2.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x: q[0] * W, y: q[1] * H, id: 1 }] });
        await sleep(80);
      }
      await sleep(after);
    };
    await pg2.goto(`http://127.0.0.1:${PORT}/index.html?q1time=1`);
    let x = await waitFor(vt2, (y) => y.screen === 'INTRO' && y.buttons.Start, 'intro 2', 120000);
    await tap2(x.buttons.Start, 900);
    x = await waitFor(vt2, (y) => y.screen === 'BRIEF' && y.buttons.BeginPuzzle, 'card 2');
    const tStart = Date.now();
    await tap2(x.buttons.BeginPuzzle, 1500);
    for (let i = 0; i < 3; i++) { const q = await waitFor(play2, (y) => y.next && y.next.length === 2, 'move'); await tap2(q.next, 500); }
    let y = await waitFor(ta2, (z) => z.remaining_ms <= 25000, 'last 25 s', 200000);
    check(y.warn && !y.card, `the last 30 s: warning colour (${y.count_text}), no popup`);
    await pg2.screenshot({ path: shots ? path.join(shots, 'T6_warning.png') : '/dev/null' }).catch(() => {});
    y = await waitFor(ta2, (z) => z.card, 'TIME UP', 60000);
    const seen = Date.now();
    const s1 = JSON.parse(await pg2.evaluate((k) => localStorage.getItem(k), LS) || '{}');
    const started = s1.run ? s1.run.started_unix * 1000 : 0;
    const took = seen - started;
    check(y.card_head === 'TIME UP' && took >= 180000 && took <= 182000,
      `TIME UP ${took} ms after the clock started (180000 expected; the page's own start time); clock started ${Math.round(started - tStart)} ms after the START PUZZLE tap (the board's first render, not counted)`);
    if (shots) await pg2.screenshot({ path: path.join(shots, 'T7_timeup.png') });
    const s2 = JSON.parse(await pg2.evaluate((k) => localStorage.getItem(k), LS) || '{}');
    const lr = s2.live && s2.live.record;
    check(lr && lr.outcome === 'TIME UP' && lr.completed === false && lr.remaining_ms === 0 && lr.elapsed_ms === 180000 && lr.max_cleared >= 3 && lr.log.some((e) => e[1] === 't'),
      `recorded: TIME UP, not completed, furthest progress ${lr && lr.max_cleared} of 13`);
    await pg2.reload();
    x = await waitFor(vt2, (z) => z.screen === 'INTRO' && z.buttons.Start, 'intro after timeout', 120000);
    await tap2(x.buttons.Start, 900);
    x = await waitFor(vt2, (z) => z.screen === 'BRIEF' && z.buttons.BeginPuzzle, 'card after timeout');
    await tap2(x.buttons.BeginPuzzle, 1500);
    y = await waitFor(ta2, (z) => z.card, 'result again');
    check(y.card_head === 'TIME UP' && !y.run_active, 'a reload after TIME UP shows the result, no new clock');
    await ctx2.close();
  }
  // Run 3 (fresh profile): SHOW A MOVE, then an IMMEDIATE reload (inside the
  // file save's flush window): it must stay spent.
  {
    const ctx3 = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const pg3 = await ctx3.newPage();
    await pg3.addInitScript(() => { window.ceTestHooks = true; });
    pg3.on('pageerror', (e) => errors.push(e.message));
    const cdp3 = await ctx3.newCDPSession(pg3);
    const g3 = (n) => () => pg3.evaluate((k) => window[k] || null, n).catch(() => null);
    const vt3 = g3('chainEscapeVhTest'), play3 = g3('chainEscapeSocialPlay'), ta3 = g3('chainEscapeTimeAttack');
    const tap3 = async (q, after = 700) => {
      for (const type of ['touchStart', 'touchEnd']) {
        await cdp3.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x: q[0] * W, y: q[1] * H, id: 1 }] });
        await sleep(80);
      }
      await sleep(after);
    };
    const enter3 = async () => {
      let z = await waitFor(vt3, (y) => y.screen === 'INTRO' && y.buttons.Start, 'intro 3', 120000);
      await tap3(z.buttons.Start, 900);
      z = await waitFor(vt3, (y) => y.screen === 'BRIEF' && y.buttons.BeginPuzzle, 'card 3');
      await tap3(z.buttons.BeginPuzzle, 1500);
      return waitFor(play3, (y) => y.active && y.buttons.Hint, 'board 3');
    };
    await pg3.goto(`http://127.0.0.1:${PORT}/index.html?q1time=1`);
    let q = await enter3();
    await waitFor(ta3, (y) => y.run_live, 'running 3');
    await tap3(q.buttons.Hint, 0);
    await waitFor(play3, (y) => y.hints_left === 0, 'spent 3');
    await pg3.reload();
    q = await enter3();
    const z3 = await waitFor(ta3, (y) => y.run_live, 'running after the quick reload');
    check(q.hints_left === 0 && z3.run_active, 'SHOW A MOVE then an immediate reload: still spent (the newest saved copy wins)');
    await ctx3.close();
  }
  check(errors.length === 0, 'no page errors ' + JSON.stringify(errors.slice(0, 3)));
  check(external.length === 0, 'no network calls outside the page ' + JSON.stringify(external.slice(0, 3)));
  await context.close();
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB Q1TIME PAGE TEST: FAILED (${failed}/${results.length})` : `WEB Q1TIME PAGE TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
