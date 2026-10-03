// SEQUENCE mechanic lab (?mechlab=sequence, development only) in the exported Web build:
//   node tools/web_mechlab_sequence_test.mjs build/web [--shots=dir]
// Real Chromium at iPhone size, real touches: intro -> automatic demo ->
// puzzle 1 (basic Sequence board, SHOW A MOVE x1, no HAMMER) solved by
// touches (advance, then escape) -> the questions -> puzzle 2; reload
// resumes; COPY RESULTS puts the JSON on the clipboard; no request leaves
// the page; ?mechlab=1 is still the PORTAL lab; without ?mechlab the
// normal game opens.
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
const PORT = 8784, W = 390, H = 844;
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
  const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: `http://127.0.0.1:${PORT}` });
  const page = await context.newPage();
  const errors = [];
  const external = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('request', (r) => { if (!r.url().startsWith(`http://127.0.0.1:${PORT}/`)) external.push(r.url()); });
  await page.addInitScript(() => { window.ceTestHooks = true; });
  const cdp = await context.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const lab = get('chainEscapeMechLab'), play = get('chainEscapeSocialPlay');
  const waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(150); }
    throw new Error('timeout ' + what + ' ' + JSON.stringify(v).slice(0, 300));
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  const tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(80); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  const shot = async (n) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, n + '.png') }); } };
  // Screens publish their button positions again after layout: settle first.
  const tapLab = async (name, screen, after = 900) => {
    await waitFor(lab, (v) => v.screen === screen && v.buttons[name], name, 30000);
    await sleep(500);
    const v = await lab();
    await tap(v.buttons[name], after);
  };

  await page.goto(`http://127.0.0.1:${PORT}/index.html?mechlab=sequence`);
  let v = await waitFor(lab, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  await sleep(800);
  check(v.total >= 12 && v.index === 0, `intro: ${v.total} boards (board set is in the build)`);
  await shot('M1_intro');
  // Demo: the lab plays it by itself, then offers START PUZZLES.
  await tapLab('Start', 'INTRO', 2500);
  v = await waitFor(lab, (v) => v.screen === 'DEMO', 'demo');
  check(true, 'WATCH THE DEMO -> the automatic Sequence demonstration');
  await shot('M2_demo_start');
  await sleep(3200);
  await shot('M3_demo_advance');
  await sleep(1500);
  await shot('M4_demo_stage2');
  v = await waitFor(lab, (v) => v.screen === 'DEMO' && v.buttons.DemoDone, 'demo done', 20000);
  await shot('M5_demo_end');
  await tapLab('DemoDone', 'DEMO', 1800);
  let pv = await waitFor(play, (p) => p.active && p.next && p.next.length === 2, 'puzzle 1');
  check(pv.buttons.Hint && !pv.buttons.Hammer && pv.buttons.Undo && pv.buttons.Restart, 'puzzle 1: UNDO, SHOW A MOVE, RESTART, no HAMMER');
  await shot('M6_puzzle1');
  for (let i = 0; i < 80; i++) {
    const p = await waitFor(play, (p) => p.completed || (p.active && p.next && p.next.length === 2), 'next move');
    if (p.completed) break;
    await tap(p.next, 900);
  }
  v = await waitFor(lab, (v) => v.screen === 'QUESTION' && v.question === 'rating' && v.buttons.Answer_HARD, 'rating', 15000);
  check(true, 'solved by real touches -> "How difficult was this puzzle?"');
  await shot('M7_rating');
  await tapLab('Answer_EASY', 'QUESTION', 900);
  v = await waitFor(lab, (v) => v.screen === 'QUESTION' && v.question === 'clarity', 'clarity', 5000);
  await shot('M8_clarity');
  await tapLab('Answer_CLEAR', 'QUESTION', 1800);
  v = await waitFor(lab, (v) => v.screen === 'PLAYING' && v.results === 1, 'puzzle 2');
  check(v.index === 1, 'answered -> puzzle 2 starts (1 result saved)');
  await sleep(1200);
  await shot('M9_puzzle2');
  // Reload: resumes; results; COPY RESULTS.
  await page.reload();
  v = await waitFor(lab, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro again', 120000);
  await sleep(800);
  check(v.index === 1 && v.results === 1, 'reload: resumes at puzzle 2 with the result kept');
  await tapLab('Results', 'INTRO', 1200);
  await page.evaluate(() => navigator.clipboard.writeText(''));
  await tapLab('CopyResults', 'RESULTS', 1200);
  const clip = await page.evaluate(() => navigator.clipboard.readText());
  let parsed = null;
  try { parsed = JSON.parse(clip); } catch { /* not JSON */ }
  check(parsed && parsed.format === 'ce-mechlab-results' && parsed.mechanic === 'sequence' && parsed.results.length === 1 && parsed.results[0].rating === 'EASY'
    && parsed.results[0].clarity === 'CLEAR' && parsed.results[0].seq_advances >= 1 && parsed.results[0].seq_escapes >= 1 && parsed.demo_seen === true,
    'COPY RESULTS: the Sequence results JSON is on the clipboard');
  await shot('M10_results');
  check(external.length === 0, 'no request left the page (no backend): ' + external.slice(0, 3).join(' '));
  check(errors.length === 0, 'no page errors ' + errors.join(' | '));
  await context.close();
  // ?mechlab=1 is still the PORTAL lab (its own 17 boards and state).
  const c3 = await browser.newContext({ viewport: { width: W, height: H }, isMobile: true, hasTouch: true });
  const p3 = await c3.newPage();
  await p3.addInitScript(() => { window.ceTestHooks = true; });
  await p3.goto(`http://127.0.0.1:${PORT}/index.html?mechlab=1`);
  let pl = null;
  for (let i = 0; i < 400; i++) { pl = await p3.evaluate(() => window.chainEscapeMechLab || null).catch(() => null); if (pl && pl.screen === 'INTRO') break; await sleep(250); }
  check(pl && pl.screen === 'INTRO' && pl.total === 17 && pl.results === 0, '?mechlab=1: still the PORTAL lab (17 boards, its own empty state)');
  await c3.close();
  // Without ?mechlab the normal game opens (title), no lab.
  const c2 = await browser.newContext({ viewport: { width: W, height: H }, isMobile: true, hasTouch: true });
  const p2 = await c2.newPage();
  await p2.goto(`http://127.0.0.1:${PORT}/index.html`);
  const st = await (async () => { for (let i = 0; i < 400; i++) { const s = await p2.evaluate(() => window.chainEscapeState || null).catch(() => null); if (s && s.title_open) return s; await sleep(250); } return null; })();
  check(st && st.title_open && !(await p2.evaluate(() => window.chainEscapeMechLab || null)), 'without ?mechlab: the normal title, no lab');
  await c2.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close(); server.close();
const failed = results.filter((x) => !x).length;
console.log(`WEB MECHLAB SEQUENCE TEST: ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
