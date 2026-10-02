// Development VERY HARD human test page (?vhtest=1) in the exported Web build:
//   node tools/web_vhtest_page_test.mjs build/web [--shots=dir]
// Real Chromium at iPhone size, real touches: intro -> puzzle (the exact
// stored board, SHOW A MOVE x1, HAMMER x1) -> solve -> rating -> next;
// results -> COPY RESULTS puts the JSON on the clipboard; no network calls
// at all (no backend), and the normal game is unchanged without ?vhtest.
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
const PORT = 8781, W = 390, H = 844;
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

  await page.goto(`http://127.0.0.1:${PORT}/index.html?vhtest=1`);
  let v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  await sleep(800);
  check(v.total === 15 && v.index === 0, 'intro: 15 puzzles (board set is in the build)');
  await shot('V1_intro');
  await tapVt('Start', 'INTRO', 1500);
  let pv = await waitFor(play, (p) => p.active && p.next && p.next.length === 2, 'puzzle 1');
  check(pv.difficulty === 'very_hard' && pv.buttons.Hint && pv.buttons.Hammer && pv.hammers_left === 1, 'puzzle 1: VERY HARD, HAMMER x1, SHOW A MOVE available');
  await shot('V2_puzzle');
  for (let i = 0; i < 80; i++) {
    const p = await waitFor(play, (p) => p.completed || (p.active && p.next && p.next.length === 2), 'next move');
    if (p.completed) break;
    await tap(p.next, 450);
  }
  v = await waitFor(vt, (v) => v.screen === 'RATE' && v.buttons.Rate_VERY_HARD, 'rate', 15000);
  check(true, 'solved by real touches -> "How difficult was this puzzle?"');
  await shot('V3_rate');
  await tapVt('Rate_HARD', 'RATE', 700);
  await tapVt('Think_NO', 'THINK', 1500);
  v = await waitFor(vt, (v) => v.screen === 'PLAYING' && v.results === 1, 'puzzle 2');
  check(v.index === 1, 'rated -> puzzle 2 starts (1 result saved)');
  // Results + COPY RESULTS (the copy runs in the page script, inside the tap).
  await page.reload();
  v = await waitFor(vt, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro again', 120000);
  await sleep(800);
  check(v.index === 1 && v.results === 1, 'reload: resumes at puzzle 2 with the result kept');
  await tapVt('Results', 'INTRO', 1200);
  await page.evaluate(() => navigator.clipboard.writeText(''));
  await tapVt('CopyResults', 'RESULTS', 1200);
  const clip = await page.evaluate(() => navigator.clipboard.readText());
  let parsed = null;
  try { parsed = JSON.parse(clip); } catch { /* not JSON */ }
  check(parsed && parsed.format === 'ce-vh-human-results' && parsed.results.length === 1 && parsed.results[0].rating === 'HARD'
    && parsed.results[0].think_first === 'NO' && parsed.assist.hammer === 1, 'COPY RESULTS: the results JSON is on the clipboard');
  await shot('V4_results');
  check(external.length === 0, 'no request left the page (no backend): ' + external.slice(0, 3).join(' '));
  check(errors.length === 0, 'no page errors ' + errors.join(' | '));
  await context.close();
  // Test 2 (?vhtest2=1): its own 14 boards and question, still no network.
  const c3 = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const p3 = await c3.newPage();
  const ext3 = [];
  p3.on('request', (r) => { if (!r.url().startsWith(`http://127.0.0.1:${PORT}/`)) ext3.push(r.url()); });
  await p3.addInitScript(() => { window.ceTestHooks = true; });
  const cdp3 = await c3.newCDPSession(p3);
  const t3 = async (pt, after = 700) => {
    await cdp3.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: pt[0] * W, y: pt[1] * H, id: 1 }] }); await sleep(80);
    await cdp3.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] }); await sleep(after);
  };
  await p3.goto(`http://127.0.0.1:${PORT}/index.html?v=7&vhtest2=1`);
  const vt3 = () => p3.evaluate(() => window.chainEscapeVhTest || null).catch(() => null);
  const pl3 = () => p3.evaluate(() => window.chainEscapeSocialPlay || null).catch(() => null);
  v = await waitFor(vt3, (v) => v.screen === 'INTRO' && v.buttons.Start, 'test 2 intro', 120000);
  await sleep(800);
  check(v.total === 14, 'test 2 (?v=7&vhtest2=1): 14 puzzles');
  await t3(v.buttons.Start, 1500);
  for (let i = 0; i < 80; i++) {
    const p = await waitFor(pl3, (p) => p.completed || (p.active && p.next && p.next.length === 2), 'test 2 next move');
    if (p.completed) break;
    await t3(p.next, 450);
  }
  v = await waitFor(vt3, (v) => v.screen === 'RATE' && v.buttons.Rate_HARD, 'test 2 rate', 15000);
  await t3(v.buttons.Rate_MEDIUM, 700);
  v = await waitFor(vt3, (v) => v.screen === 'THINK' && v.buttons.Think_YES, 'test 2 question', 5000);
  const q = await p3.evaluate(() => document.body.innerText).catch(() => '');
  await t3(v.buttons.Think_YES, 1500);
  v = await waitFor(vt3, (v) => v.results === 1, 'test 2 result', 10000);
  check(v.results === 1, 'test 2: solved by real touches, rated, "obvious start" answered, puzzle 2 next');
  if (shots) { fs.mkdirSync(shots, { recursive: true }); await p3.screenshot({ path: path.join(shots, 'V5_test2_next.png') }); }
  check(ext3.length === 0, 'test 2: no request left the page');
  await c3.close();
  // Without ?vhtest the normal game opens (title).
  const c2 = await browser.newContext({ viewport: { width: W, height: H }, isMobile: true, hasTouch: true });
  const p2 = await c2.newPage();
  await p2.goto(`http://127.0.0.1:${PORT}/index.html`);
  const st = await (async () => { for (let i = 0; i < 400; i++) { const s = await p2.evaluate(() => window.chainEscapeState || null).catch(() => null); if (s && s.title_open) return s; await sleep(250); } return null; })();
  check(st && st.title_open && !(await p2.evaluate(() => window.chainEscapeVhTest || null)), 'without ?vhtest: the normal title, no test page');
  await c2.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close(); server.close();
const failed = results.filter((x) => !x).length;
console.log(`WEB VHTEST PAGE TEST: ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
