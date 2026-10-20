// EXTREME PHASE 2 page (?xtest6=1) in an exported DEVELOPMENT Web build:
//   node tools/web_xtest6_page_test.mjs <web build dir> [--shots=dir] [--bench-out=file.json]
// Real Chromium at iPhone SE size, real touches, the WHOLE test: campaign
// progress -> for every puzzle its card (or first the demo card, played by
// touches: the tester executes the rule) -> the puzzle (puzzle 1 given up,
// puzzle 2 solved by touches, the rest given up) -> the five-step rating and
// six questions (incl. "did the combination make it more interesting?") ->
// the hardest puzzle. Screenshots of every demo and every board (iPhone SE
// readability, e.g. a magnet that is also a switch target). No network
// calls. Then &bench=1 at CPU throttling x1 / x4 / x6 (a desktop SIMULATION
// of a slower phone, not an iPhone measurement).
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
const PORT = 8786, W = 375, H = 667;  // iPhone SE
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

  await page.goto(`http://127.0.0.1:${PORT}/index.html?xtest6=1`);
  let v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  await sleep(800);
  await shot('Q1_intro');
  await tapVt('Start', 'INTRO', 900);
  await tapVt('Reached_300', 'PROFILE', 900);
  v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.total >= 1, 'intro after profile');
  const N = v.total;
  check(N >= 1 && N <= 6, `all 300 levels: ${N} candidates offered (six asked for)`);
  await tapVt('Start', 'INTRO', 900);
  let puzzles = 0, demos = 0, solved = 0;
  for (let step = 0; step < 20; step++) {
    v = await waitFor(vt, (v) => v.screen === 'BRIEF' || v.screen === 'HARDEST', 'next card', 30000);
    if (v.screen === 'HARDEST') break;
    if (v.demo) {
      const id = v.demo;
      await shot('demo_card_' + id);
      await tapVt('BeginPuzzle', 'BRIEF', 1500);
      await waitFor(play, (p) => p.active && p.next && p.next.length === 2, 'demo ' + id);
      await shot('demo_' + id);
      const ok = await solveByTouches('demo ' + id);
      check(ok, `demo ${id}: played to the end by touches (the tester executes the rule)`);
      await sleep(1600);
      demos += 1;
      continue;
    }
    puzzles += 1;
    await tapVt('BeginPuzzle', 'BRIEF', 1500);
    await waitFor(play, (p) => p.active && p.next && p.next.length === 2, 'puzzle ' + puzzles);
    v = await waitFor(vt, (v) => v.screen === 'PLAYING' && v.hud_bottom > 0, 'hud ' + puzzles);
    check(v.hud_bottom <= v.board_top, `puzzle ${puzzles}: clock and GIVE UP above the board`);
    await shot('board_' + puzzles);
    if (puzzles === 2) {
      check(await solveByTouches('puzzle 2'), 'puzzle 2 solved by real touches');
      solved += 1;
    } else {
      await tap(v.buttons.GiveUp, 400); await tap(v.buttons.GiveUp, 1200);
    }
    await waitFor(vt, (v) => v.screen === 'RATE', 'rate ' + puzzles, 15000);
    if (puzzles === 1) await shot('Q2_rate');
    await tapVt(puzzles === 1 ? 'Rate_EXTREME' : 'Rate_VERY_HARD', 'RATE', 700);
    for (const n of ['Think_SIMILAR', 'Think_4', 'Think_4', 'Think_MOSTLY', 'Think_YES']) await tapVt(n, 'THINK', 600);
    if (puzzles === 1) await shot('Q3_combo');
    await tapVt('Think_A_LITTLE', 'THINK', 1000);
  }
  check(puzzles === N && solved === Math.min(1, N - 1), `every candidate played (${puzzles} / ${N})`);
  const st = JSON.parse(await page.evaluate(() => localStorage.getItem('chain_escape_xtest6_state')) || '{}');
  check(st.results && st.results.length === N && st.results.every((r) => r.combo === 'A LITTLE') && st.results[1].completed && st.results[1].log.some((e) => e[1] === 'm'),
    "state in this test's own storage: every puzzle with the combination answer, the solved one with its move log");
  check(demos >= 1 && st.demos && st.demos.length === demos && st.demos.every((d) => d.completed), `demos played and recorded, never rated (${demos})`);
  const t5 = await page.evaluate(() => localStorage.getItem('chain_escape_xtest5_state'));
  check(t5 === null, 'the ?xtest5 storage is untouched');
  check(errors.length === 0, 'no page errors ' + JSON.stringify(errors.slice(0, 3)));
  check(external.length === 0, 'no network calls outside the page ' + JSON.stringify(external.slice(0, 3)));
  await context.close();

  const bench = {};
  for (const rate of [1, 4, 6]) {
    const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const pg = await ctx.newPage();
    const cd = await ctx.newCDPSession(pg);
    await pg.goto(`http://127.0.0.1:${PORT}/index.html?xtest6=1&bench=1`);
    await cd.send('Emulation.setCPUThrottlingRate', { rate });
    const b = await (async () => {
      const end = Date.now() + 600000; let x = null;
      while (Date.now() < end) { x = await pg.evaluate(() => window.chainEscapeVhBench || null).catch(() => null); if (x && x.done) return x; await sleep(500); }
      throw new Error('bench timeout');
    })();
    bench['x' + rate] = b.results;
    const worst = (k) => Math.max(...b.results.map((r) => r[k] || 0));
    console.log(`bench x${rate}: verify max ${worst('verify_ms').toFixed(1)} ms, SHOW A MOVE max ${worst('hint_ms').toFixed(1)} ms, after a mistake max ${worst('dead_hint_ms').toFixed(1)} ms`);
    check(b.results.length === N && b.results.every((r) => r.dead_hint_ms !== undefined), `bench x${rate}: every board timed, incl. SHOW A MOVE after a mistake`);
    await ctx.close();
  }
  if (benchOut) fs.writeFileSync(benchOut, JSON.stringify(bench, null, 1));
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB XTEST6 PAGE TEST: FAILED (${failed}/${results.length})` : `WEB XTEST6 PAGE TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
