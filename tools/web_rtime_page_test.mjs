// NEW BLIND BOARD against the 3-minute clock (?rtime=1), exported
// DEVELOPMENT Web build:
//   node tools/web_rtime_page_test.mjs <web build dir> [--shots=dir] [--fast]
// Real Chromium at iPhone SE size, real touches:
//   run 1: a neutral intro; the countdown from 3:00; a blocked tap logged
//   WITH its block; a real 180 s countdown -> TIME UP (frozen) -> the timed
//   questions -> CONTINUE WITHOUT TIMER from the position at 0:00 -> a real
//   page RELOAD in the untimed game (the position rebuilt) -> solved by
//   touches -> the puzzle questions (difficulty one per line) -> results:
//   the timed TIME UP and the untimed completion kept apart.
//   run 2 (fresh profile): solved within the time -> a timed WIN, no offer.
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
const FAST = process.argv.includes('--fast');
const PORT = 8797, W = 375, H = 667;  // iPhone SE
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
  // Engine notices are errors too, except one known, harmless one: an answer
  // button removed in its own press handler (the shared question screen,
  // every developer test page) gets "!is_inside_tree()" from can_process.
  page.on('console', (m) => { if (/SCRIPT ERROR|ERROR:|Invalid/.test(m.text()) && !m.text().includes('Condition "!is_inside_tree()" is true')) errors.push(m.text().slice(0, 300)); if (process.env.RT_DEBUG) console.log('  [page] ' + m.text().slice(0, 200)); });
  page.on('request', (r) => { if (!r.url().startsWith(`http://127.0.0.1:${PORT}/`)) external.push(r.url()); });
  await page.addInitScript(() => {
    window.ceTestHooks = true;
    // --fast: before the page loads, the saved run's start is moved back
    // (as if the page had been closed that long); newest copy wins on load.
    const back = Number(sessionStorage.getItem('ceRewind') || 0);
    const k = 'chain_escape_rtime_state';
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

  const LS = 'chain_escape_rtime_state';
  const ta = get('chainEscapeTimeAttack');
  const state = async (pg = page) => JSON.parse(await pg.evaluate((k) => localStorage.getItem(k), LS) || '{}');
  const tapTa = async (name, after = 900) => { await sleep(400); const x = await waitFor(ta, (v) => v.buttons && v.buttons[name], name); await tap(x.buttons[name], after); };
  const enter = async () => {
    await tapVt('Start', 'INTRO', 900);
    await tapVt('BeginPuzzle', 'BRIEF', 1500);
  };
  await page.goto(`http://127.0.0.1:${PORT}/index.html?rtime=1`);
  await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  let t = await waitFor(ta, (v) => v.board_ok !== undefined, 'snapshot');
  check(t.board_ok, 'the exact new board (fingerprint checked by the page)');
  await sleep(600);
  await shot('R1_intro');
  await enter();
  let p = await waitFor(play, (x) => x.active && x.next && x.next.length === 2 && x.buttons.Hint, 'board');
  const fullBoard = p.blocks;
  t = await waitFor(ta, (v) => v.run_active && v.count_bottom > 0, 'running');
  const wallStart = Date.now() - (180000 - t.remaining_ms);  // the moment the clock read 3:00
  const v0 = await vt();
  check(t.count_bottom <= t.board_top && v0.hud_bottom <= v0.board_top && t.remaining_ms > 175000, `countdown from 3:00 (${t.count_text}), above the board`);
  await shot('R2_board');
  // A real touch on a blocked block: the armored shell (always blocked at the start).
  const sh = (await play()).armored[0];
  await tap(sh, 900);
  let st = await state();
  const bl = st.live && st.live.record ? st.live.record.log.filter((e) => e[1] === 'a' || e[1] === 'b') : [];
  check(bl.length === 1 && bl[0][2] >= 0, `a tap on the armored block is logged with its block (${JSON.stringify(bl)})`);
  for (let i = 0; i < 2; i++) { p = await waitFor(play, (x) => x.next && x.next.length === 2, 'move'); await tap(p.next, 500); }
  // A real reload in the timed game: the clock goes on, nothing comes back.
  // (--fast: the saved start time is moved 170 s back first, as if the page
  // had been away that long; the test then needs ~15 s instead of 3 min.)
  const remBefore = (await ta()).remaining_ms;
  if (FAST) await page.evaluate(() => sessionStorage.setItem('ceRewind', '165'));
  await page.reload();
  await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro after timed reload', 120000);
  await enter();
  p = await waitFor(play, (x) => x.active && x.buttons.Hint, 'timed after reload');
  t = await waitFor(ta, (v) => v.run_active || v.card, 'timed running after reload');
  st = await state();
  check(p.blocks === fullBoard && (t.card || t.remaining_ms < remBefore) && p.hints_left === 1 && st.live.record.log.some((e) => e[1] === 'o'),
    `reload in the timed game: the board again from the start (${p.blocks} blocks, logged), the clock not restored (${t.remaining_ms} < ${remBefore} ms), SHOW A MOVE x1`);
  for (let i = 0; i < 2; i++) { p = await waitFor(play, (x) => x.next && x.next.length === 2, 'move'); await tap(p.next, 500); }
  const blocksAt = (await play()).blocks;
  t = await waitFor(ta, (v) => v.card, 'TIME UP (real 3 minutes)', 200000);
  const wallSec = (Date.now() - wallStart) / 1000;
  check(t.card_head === 'TIME UP' && (FAST || (wallSec >= 179 && wallSec <= 183)), `TIME UP after the real countdown (${FAST ? 'clock moved back 165 s' : wallSec.toFixed(1) + ' s of wall time from 3:00, a reload included'})`);
  st = await state();
  check(st.timed && st.timed.outcome === 'TIME UP' && st.timed.completed === false && st.timed.remaining_ms === 0 && st.phase === 'timed_q', 'the timed result frozen: TIME UP, not completed');
  await shot('R3_timeup');
  await tapTa('TA_Continue');
  for (const n of ['Think_4', 'Think_3', 'Think_2', 'Think_YES', 'Think_ABOUT_RIGHT', 'Think_MAYBE']) await tapVt(n, 'THINK', 600);
  t = await waitFor(ta, (v) => v.card && v.buttons.TA_Untimed && v.buttons.TA_Finish, 'offer');
  await shot('R4_offer');
  st = await state();
  check(st.phase === 'offer' && st.offer && st.timed.answers && st.timed.answers.excite === '4' && st.timed.answers.length === 'ABOUT RIGHT', `the offer (${st.offer && st.offer.from}); the timed answers stored with the timed record ${JSON.stringify(st.timed.answers)}`);
  await tapTa('TA_Untimed', 1500);
  if (process.env.RT_DEBUG) { const d = await state(); console.log('  after TA_Untimed: phase ' + d.phase + ' q ' + d.q + ' puzzle_answers ' + JSON.stringify(d.puzzle_answers) + ' results ' + (d.results || []).length); }
  p = await waitFor(play, (x) => x.active && x.buttons.Hint, 'untimed board');
  t = await ta();
  check(t.count_text === 'NO TIMER' && (st.offer.from !== 'timeout_state' || p.blocks === blocksAt), `untimed: NO TIMER (${t.count_text}, ${p.blocks} vs ${blocksAt}); ${st.offer.from === 'timeout_state' ? 'the position at 0:00 (' + p.blocks + ' blocks)' : 'a fresh board'}`);
  await shot('R5_untimed');
  await tap((await waitFor(play, (x) => x.next && x.next.length === 2, 'move u')).next, 600);
  const blocksBefore = (await play()).blocks;
  st = await state();
  check(st.phase === 'untimed' && st.live && st.live.phase === 'untimed', `saved in the untimed game before the reload (${st.phase})`);
  await page.reload();
  await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro after reload', 120000);
  await enter();
  p = await waitFor(play, (x) => x.active && x.buttons.Hint, 'untimed after reload', 15000).catch(async (e) => { console.log(JSON.stringify(await vt()), JSON.stringify(await ta())); throw e; });
  st = await state();
  check(st.phase === 'untimed' && p.blocks === blocksBefore && (await ta()).count_text === 'NO TIMER', `reload in the untimed game: the position rebuilt (${p.blocks} blocks)`);
  check(await solveByTouches('the untimed game'), 'solved without the timer, by touches');
  t = await waitFor(ta, (v) => v.card, 'untimed result card', 15000);
  check(t.card_head === 'SOLVED', 'the untimed SOLVED card');
  await shot('R6_untimed_solved');
  await tapTa('TA_Continue');
  await shot('R7_difficulty');
  for (const n of ['Think_VERY_HARD', 'Think_5', 'Think_4', 'Think_YES', 'Think_YES', 'Think_YES']) await tapVt(n, 'THINK', 600);
  await tapVt('Think_SKIP', 'THINK', 1200);
  await waitFor(vt, (v) => v.screen === 'RESULTS', 'results');
  st = await state();
  const r = (st.results || [])[0] || {};
  check(r.timed && r.timed.outcome === 'TIME UP' && r.untimed && r.untimed.continued && r.untimed.completed && r.untimed.record && r.untimed.record.log[0][1] === 'c'
    && r.untimed.reopens === 1 && r.puzzle_answers.difficulty === 'VERY HARD' && r.puzzle_answers.achieve === '4',
    'results: timed TIME UP and the untimed completion in separate records; the puzzle answers');
  const other = await page.evaluate(() => ['q1time', 'ptest11', 'xtest8'].map((k) => localStorage.getItem('chain_escape_' + k + '_state')));
  check(other.every((x) => x === null), "the other test pages' storage is untouched");
  // Run 2: a timed WIN.
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
    await pg2.goto(`http://127.0.0.1:${PORT}/index.html?rtime=1`);
    let x = await waitFor(vt2, (y) => y.screen === 'INTRO' && y.buttons.Start, 'intro 2', 120000);
    await tap2(x.buttons.Start, 900);
    x = await waitFor(vt2, (y) => y.screen === 'BRIEF' && y.buttons.BeginPuzzle, 'card 2');
    await tap2(x.buttons.BeginPuzzle, 1500);
    for (let i = 0; i < 40; i++) {
      const q = await waitFor(play2, (y) => y.completed || (y.active && y.next && y.next.length === 2), 'move 2');
      if (q.completed) break;
      await tap2(q.next, 450);
    }
    const y = await waitFor(ta2, (z) => z.card, 'win card', 15000);
    const s2 = JSON.parse(await pg2.evaluate((k) => localStorage.getItem(k), LS) || '{}');
    check(y.card_head === 'SOLVED' && s2.timed && s2.timed.outcome === 'COMPLETED' && s2.timed.remaining_ms > 0, `a timed WIN (${s2.timed && s2.timed.remaining_ms} ms left)`);
    await ctx2.close();
  }
  check(errors.length === 0, 'no page errors ' + JSON.stringify(errors.slice(0, 3)));
  check(external.length === 0, 'no network calls outside the page ' + JSON.stringify(external.slice(0, 3)));
  await context.close();
  // WebAssembly timing of the board's solver work (&bench=1: a fresh Solver
  // as the recipient's check, SHOW A MOVE along the solution and after every
  // losing move), at CPU throttling x1 (desktop: the 40 ms gate) and x4 / x6
  // (a desktop SIMULATION of slower phones, reported; a real iPhone is still
  // the measurement that counts).
  const bench = {};
  for (const rate of [1, 4, 6]) {
    const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const pg = await ctx.newPage();
    const cd = await ctx.newCDPSession(pg);
    await pg.goto(`http://127.0.0.1:${PORT}/index.html?rtime=1&bench=1`);
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
      && (rate !== 1 || Math.max(worst('verify_ms'), worst('hint_ms'), worst('dead_hint_ms')) <= 40), `bench x${rate}: the board timed, incl. SHOW A MOVE after a mistake${rate === 1 ? ' (within 40 ms in the desktop WebAssembly build)' : ' (reported)'}`);
    await ctx.close();
  }
  if (benchOut) fs.writeFileSync(benchOut, JSON.stringify(bench, null, 1));
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB RTIME PAGE TEST: FAILED (${failed}/${results.length})` : `WEB RTIME PAGE TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
