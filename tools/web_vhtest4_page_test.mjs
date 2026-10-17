// VERY HARD GATE 0 PILOT page (?vhtest4=1) in an exported DEVELOPMENT Web build:
//   node tools/web_vhtest4_page_test.mjs <web build dir> [--shots=dir] [--bench-out=file.json]
// Real Chromium at iPhone size, real touches: intro -> campaign progress ->
// reminder card -> puzzle (clock + GIVE UP, SHOW A MOVE x1, no HAMMER) ->
// GIVE UP twice -> the five questions -> puzzle 2 solved by touches ->
// questions -> next card. No network calls at all (no backend).
// Then &bench=1: the recipient's check and SHOW A MOVE timed on every
// board in the browser's WebAssembly build, at CPU throttling x1, x4 and
// x6 (Chrome DevTools emulation - a desktop SIMULATION of a slower phone,
// not an iPhone measurement).
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
const PORT = 8784, W = 375, H = 667;  // iPhone SE
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

  await page.goto(`http://127.0.0.1:${PORT}/index.html?vhtest4=1`);
  let v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  await sleep(800);
  check(v.total === 0, 'intro: nothing ordered before the campaign question');
  await shot('P1_intro');
  await tapVt('Start', 'INTRO', 900);
  await shot('P2_profile');
  await tapVt('Reached_300', 'PROFILE', 900);
  v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.total === 28, 'intro after profile');
  check(true, 'all 300 levels played: 28 puzzles offered');
  await tapVt('Start', 'INTRO', 900);
  v = await waitFor(vt, (v) => v.screen === 'BRIEF' && v.buttons.BeginPuzzle, 'reminder card');
  await shot('P3_brief');
  check(true, 'puzzle 1 starts with its reminder card');
  await tapVt('BeginPuzzle', 'BRIEF', 1500);
  let pv = await waitFor(play, (p) => p.active && p.next && p.next.length === 2, 'puzzle 1');
  v = await waitFor(vt, (v) => v.screen === 'PLAYING' && v.buttons.GiveUp, 'GIVE UP on screen');
  check(pv.difficulty === 'very_hard' && pv.buttons.Hint && !pv.buttons.Hammer, 'puzzle 1: SHOW A MOVE available, no HAMMER');
  const g = v.buttons.GiveUp;
  const clash = Object.entries(pv.buttons).filter(([k, b]) => Math.abs(b[0] - g[0]) < 0.12 && Math.abs(b[1] - g[1]) < 0.05);
  check(clash.length === 0, 'GIVE UP does not sit on any game button ' + JSON.stringify(clash));
  await tap(pv.next, 600);
  await shot('P4_playing');
  await tap(g, 400);
  await tap(g, 1200);
  v = await waitFor(vt, (v) => v.screen === 'RATE', 'rate after give up', 15000);
  check(true, 'GIVE UP tapped twice -> the rating');
  await tapVt('Rate_HARD', 'RATE', 700);
  await shot('P5_l300');
  await tapVt('Think_HARDER', 'THINK', 700);
  await shot('P6_enjoy');
  await tapVt('Think_4', 'THINK', 700);
  await tapVt('Think_3', 'THINK', 700);
  await tapVt('Think_NO', 'THINK', 1200);
  v = await waitFor(vt, (v) => v.screen === 'BRIEF' && v.results === 1, 'card 2');
  check(v.index === 1, 'answers saved, puzzle 2 card');
  await tapVt('BeginPuzzle', 'BRIEF', 1500);
  for (let i = 0; i < 80; i++) {
    const p = await waitFor(play, (p) => p.completed || (p.active && p.next && p.next.length === 2), 'next move');
    if (p.completed) break;
    await tap(p.next, 450);
  }
  v = await waitFor(vt, (v) => v.screen === 'RATE', 'rate 2', 15000);
  check(true, 'puzzle 2 solved by real touches -> rating');
  for (const [n, s] of [['Rate_VERY_HARD', 'RATE'], ['Think_SIMILAR', 'THINK'], ['Think_5', 'THINK'], ['Think_5', 'THINK'], ['Think_NO', 'THINK']]) await tapVt(n, s, 700);
  v = await waitFor(vt, (v) => v.screen === 'BRIEF' && v.results === 2, 'card 3');
  const saved = await page.evaluate(() => localStorage.getItem('chain_escape_vhtest4_state'));
  const st = JSON.parse(saved || '{}');
  check(st.results && st.results.length === 2 && st.results[0].gave_up && st.results[1].completed && st.results[1].log.some((e) => e[1] === 'm'),
    'state in this test\'s own storage: give-up + solved puzzle with its action log');
  check(errors.length === 0, 'no page errors ' + JSON.stringify(errors.slice(0, 3)));
  check(external.length === 0, 'no network calls outside the page ' + JSON.stringify(external.slice(0, 3)));
  await context.close();

  // Bench: the recipient's check and SHOW A MOVE in WebAssembly, throttled.
  const bench = {};
  for (const rate of [1, 4, 6]) {
    const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
    const pg = await ctx.newPage();
    const cd = await ctx.newCDPSession(pg);
    await pg.goto(`http://127.0.0.1:${PORT}/index.html?vhtest4=1&bench=1`);
    await cd.send('Emulation.setCPUThrottlingRate', { rate });
    const b = await (async () => {
      const end = Date.now() + 600000; let x = null;
      while (Date.now() < end) { x = await pg.evaluate(() => window.chainEscapeVhBench || null).catch(() => null); if (x && x.done) return x; await sleep(500); }
      throw new Error('bench timeout');
    })();
    bench['x' + rate] = b.results;
    const worst = (k) => Math.max(...b.results.map((r) => r[k] || 0));
    console.log(`bench x${rate}: verify max ${worst('verify_ms').toFixed(1)} ms, SHOW A MOVE max ${worst('hint_ms').toFixed(1)} ms, after a mistake max ${worst('dead_hint_ms').toFixed(1)} ms`);
    check(b.results.length === 28, `bench x${rate}: all 28 boards timed`);
    await ctx.close();
  }
  if (benchOut) fs.writeFileSync(benchOut, JSON.stringify(bench, null, 1));
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB VHTEST4 PAGE TEST: FAILED (${failed}/${results.length})` : `WEB VHTEST4 PAGE TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
