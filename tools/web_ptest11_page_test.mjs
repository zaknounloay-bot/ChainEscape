// EXTREME phase 6 page (?ptest11=1) in an exported DEVELOPMENT Web build:
//   node tools/web_ptest11_page_test.mjs <web build dir> [--shots=dir] [--bench-out=file.json]
// Real Chromium at iPhone SE size, real touches: campaign progress -> the
// one puzzle's card -> the puzzle. The EXPERIMENTAL SHOW A MOVE RULE with
// real touches: one press highlights a move and spends it (saved in this
// test's own storage), RESTART does not give it back, a press then is
// refused with the same answer, a PAGE RELOAD keeps it spent and carries
// the record on (reopen logged), then the puzzle solved by touches -> the
// five-step rating, six questions and the free-text question. Then a fresh
// run: GIVE UP. The other test pages' storage untouched, no network calls.
// Then &bench=1 at CPU throttling x1 / x4 / x6 (a desktop SIMULATION of a
// slower phone, not an iPhone measurement).
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
const PORT = 8791, W = 375, H = 667;  // iPhone SE
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

  const LS = 'chain_escape_ptest11_state';
  const state = async () => JSON.parse(await page.evaluate((k) => localStorage.getItem(k), LS) || '{}');
  await page.goto(`http://127.0.0.1:${PORT}/index.html?ptest11=1`);
  let v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  await sleep(800);
  await shot('Q1_intro');
  await tapVt('Start', 'INTRO', 900);
  await tapVt('Reached_300', 'PROFILE', 900);
  v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.total >= 1, 'intro after profile');
  check(v.total === 1, `one puzzle offered (${v.total})`);
  await tapVt('Start', 'INTRO', 900);
  v = await waitFor(vt, (v) => v.screen === 'BRIEF', 'card');
  check(!v.demo, 'no demo card');
  await shot('Q2_card');
  await tapVt('BeginPuzzle', 'BRIEF', 1500);
  let p = await waitFor(play, (p) => p.active && p.next && p.next.length === 2 && p.buttons.Hint, 'puzzle');
  v = await waitFor(vt, (v) => v.screen === 'PLAYING' && v.hud_bottom > 0, 'hud');
  check(v.hud_bottom <= v.board_top, 'clock and GIVE UP above the board');
  check(p.hints_left === 1 && p.undos_left === 3 && p.hammers_left === 0, `one SHOW A MOVE, UNDO x3, no HAMMER (${p.hints_left} / ${p.undos_left} / ${p.hammers_left})`);
  await shot('board');
  // One move, then SHOW A MOVE: highlighted and spent, saved first.
  await tap(p.next, 600);
  p = await waitFor(play, (p) => p.active && p.buttons.Hint, 'after a move');
  await tap(p.buttons.Hint, 900);
  p = await waitFor(play, (p) => p.hints_left === 0, 'SHOW A MOVE spent');
  await shot('Q3_hint_used');
  let st = await state();
  check(st.budget && st.budget.Q1 && st.budget.Q1.r === 'shown' && st.live && st.live.record.hint_presses === 1, 'SHOW A MOVE: a move highlighted, spent and saved in this test\'s own storage');
  // RESTART: not given back; a press is refused (same answer everywhere).
  await tap(p.buttons.Restart, 1200);
  p = await waitFor(play, (p) => p.plays === 2, 'restart');
  check(p.hints_left === 0, 'RESTART does not give SHOW A MOVE back');
  await tap(p.buttons.Hint, 900);
  p = await waitFor(play, (p) => p.message_text !== '', 'refusal');
  check(p.message_text === 'No SHOW A MOVE left in this puzzle', 'a press after RESTART: "' + p.message_text + '"');
  await tap(p.next, 600);
  // A page reload: still spent, the record carries on.
  await page.reload();
  v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro after reload', 120000);
  await tapVt('Start', 'INTRO', 900);
  await tapVt('BeginPuzzle', 'BRIEF', 1500);
  p = await waitFor(play, (p) => p.active && p.next && p.next.length === 2 && p.buttons.Hint, 'puzzle after reload');
  check(p.hints_left === 0, 'after a page reload: still no SHOW A MOVE');
  await tap(p.buttons.Hint, 900);
  p = await waitFor(play, (p) => p.message_text !== '', 'refusal after reload');
  check(p.message_text === 'No SHOW A MOVE left in this puzzle', 'a press after the reload is refused');
  st = await state();
  check(st.live && st.live.record.reopens === 1 && st.live.record.log.some((e) => e[1] === 'o') && st.live.record.log.filter((e) => e[1] === 'h').length === 3,
    'the record carried on through the reload: reopen logged, all three presses logged');
  check(await solveByTouches('the puzzle'), 'the puzzle solved by real touches');
  await waitFor(vt, (v) => v.screen === 'RATE', 'rate', 15000);
  await shot('Q4_rate');
  await tapVt('Rate_EXTREME', 'RATE', 700);
  for (const n of ['Think_HARDER', 'Think_4', 'Think_5', 'Think_YES', 'Think_YES', 'Think_YES']) await tapVt(n, 'THINK', 600);
  await shot('Q5_feedback');
  await tapVt('Think_SKIP', 'THINK', 1000);
  v = await waitFor(vt, (v) => v.screen === 'HARDEST' || v.screen === 'RESULTS', 'after the questions', 15000);
  await shot('Q6_end');
  st = await state();
  const r = (st.results || [])[0] || {};
  check(st.results && st.results.length === 1 && r.completed && r.rating === 'EXTREME' && r.l300 === 'HARDER' && r.enjoy === '4' && r.achieve === '5' && r.fair === 'YES' && r.planned === 'YES' && r.combo === 'YES' && r.feedback === '',
    'the answers recorded: difficulty, vs Level 300, enjoyment, achievement, fairness, planning, combination, free text (skipped)');
  check(r.show_a_move === 1 && r.hint_presses === 3 && r.reopens === 1 && r.attempts === 3 && r.restarts === 1 && r.first_hint_attempt === 1 && 'unaided_max_cleared' in r && 'first_hint_ms' in r,
    `recorded: SHOW A MOVE 1, presses ${r.hint_presses}, attempts ${r.attempts} (restart ${r.restarts}, reopen ${r.reopens}), first used on attempt ${r.first_hint_attempt}`);
  check(r.log.filter((e) => e[1] === 'h').map((e) => e[3].r).join(',') === 'shown,none,none' && r.log.some((e) => e[1] === 'm' && e.length > 3) && r.mech && Object.keys(r.mech).length > 0,
    'every press logged with its outcome; mechanism events in the move log');
  check(!st.live, 'nothing left in progress after the questions');
  const other = await page.evaluate(() => ['xtest5', 'xtest6', 'xtest7', 'xtest8', 'vhval3', 'vhtest4'].map((k) => localStorage.getItem('chain_escape_' + k + '_state')));
  check(other.every((x) => x === null), 'the other test pages\' storage is untouched');
  // A fresh run (a new browser profile): GIVE UP (tap twice) is recorded.
  {
    const ctx2 = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const pg2 = await ctx2.newPage();
    const cdp2 = await ctx2.newCDPSession(pg2);
    const vt2 = () => pg2.evaluate(() => window.chainEscapeVhTest || null).catch(() => null);
    const tap2 = async (p, after = 700) => {
      for (const type of ['touchStart', 'touchEnd']) {
        await cdp2.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x: p[0] * W, y: p[1] * H, id: 1 }] });
        await sleep(80);
      }
      await sleep(after);
    };
    const tapVt2 = async (name, screen, after) => { const x = await waitFor(vt2, (v) => v.screen === screen && v.buttons[name], name); await tap2(x.buttons[name], after); };
    await pg2.goto(`http://127.0.0.1:${PORT}/index.html?ptest11=1`);
    await waitFor(vt2, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro (fresh)', 120000);
    await tapVt2('Start', 'INTRO', 900);
    await tapVt2('Reached_300', 'PROFILE', 900);
    await tapVt2('Start', 'INTRO', 900);
    await tapVt2('BeginPuzzle', 'BRIEF', 1500);
    const pv = await waitFor(vt2, (v) => v.screen === 'PLAYING' && v.buttons.GiveUp, 'playing for give-up');
    await tap2(pv.buttons.GiveUp, 400); await tap2(pv.buttons.GiveUp, 1200);
    await waitFor(vt2, (v) => v.screen === 'RATE', 'rate after give-up', 15000);
    await tapVt2('Rate_HARD', 'RATE', 700);
    for (const n of ['Think_HARDER', 'Think_2', 'Think_1', 'Think_NO', 'Think_NO', 'Think_NO', 'Think_SKIP']) await tapVt2(n, 'THINK', 600);
    const st2 = JSON.parse(await pg2.evaluate((k) => localStorage.getItem(k), LS) || '{}');
    check(st2.results && st2.results.length === 1 && st2.results[0].gave_up === true && st2.results[0].completed === false && st2.results[0].rating === 'HARD' && st2.results[0].show_a_move === 0,
      'GIVE UP (tapped twice) is recorded as a give-up, still rated');
    await ctx2.close();
  }
  check(errors.length === 0, 'no page errors ' + JSON.stringify(errors.slice(0, 3)));
  check(external.length === 0, 'no network calls outside the page ' + JSON.stringify(external.slice(0, 3)));
  await context.close();

  const bench = {};
  for (const rate of [1, 4, 6]) {
    const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const pg = await ctx.newPage();
    const cd = await ctx.newCDPSession(pg);
    await pg.goto(`http://127.0.0.1:${PORT}/index.html?ptest11=1&bench=1`);
    await cd.send('Emulation.setCPUThrottlingRate', { rate });
    const b = await (async () => {
      const end = Date.now() + 600000; let x = null;
      while (Date.now() < end) { x = await pg.evaluate(() => window.chainEscapeVhBench || null).catch(() => null); if (x && x.done) return x; await sleep(500); }
      throw new Error('bench timeout');
    })();
    bench['x' + rate] = b.results;
    const worst = (k) => Math.max(...b.results.map((r) => r[k] || 0));
    console.log(`bench x${rate}: verify max ${worst('verify_ms').toFixed(1)} ms, SHOW A MOVE max ${worst('hint_ms').toFixed(1)} ms, after a mistake max ${worst('dead_hint_ms').toFixed(1)} ms`);
    check(b.results.length === 1 && b.results.every((r) => r.dead_hint_ms !== undefined), `bench x${rate}: every board timed, incl. SHOW A MOVE after a mistake`);
    await ctx.close();
  }
  if (benchOut) fs.writeFileSync(benchOut, JSON.stringify(bench, null, 1));
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB PTEST11 PAGE TEST: FAILED (${failed}/${results.length})` : `WEB PTEST11 PAGE TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
