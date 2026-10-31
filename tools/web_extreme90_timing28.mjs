// Phase 28/29 N68 performance watch: repeated WebAssembly TIME UP timing
// (the page's own &bench=1 check: a fresh Solver, full limit, median of 3
// solves) on the Phase 28 dev build, one fresh browser context per round.
//   node tools/web_extreme90_timing28.mjs <dev web build> <rounds> <out.json>
// Development only. Port 8870; run it alone (no other browser test or generator).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
let pw;
try { pw = await import('playwright'); } catch { pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright'); }
const root = path.resolve(process.argv[2]), ROUNDS = +(process.argv[3] || 5), OUT = process.argv[4];
const PORT = 8870, W = 375, H = 667;
// [tile, board, on PREVIOUS]: N68 plus references of similar desktop cost.
const BOARDS = [['Puzzle_6', 'N68', false], ['Puzzle_1', 'N63', false], ['Puzzle_2', 'N64', false], ['Puzzle_17', 'N57', true]];
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0]; const f = path.join(root, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(PORT);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const rows = [];
try {
  for (let r = 0; r < ROUNDS; r++) {
    for (const [tile, id, prev] of BOARDS) {
      const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
      const page = await ctx.newPage();
      await page.addInitScript(() => { window.ceTestHooks = true; });
      const cdp = await ctx.newCDPSession(page);
      const get = (k) => () => page.evaluate((n) => window[n] || null, k).catch(() => null);
      const hub = get('chainEscapeXb28'), vt = get('chainEscapeVhTest');
      const waitFor = async (g, pred, what, ms = 120000) => { const end = Date.now() + ms; let v; while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(100); } throw new Error('timeout ' + what); };
      const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
      const tap = async (p, after = 900) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(80); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
      const tapHub = async (name, view) => { const v = await waitFor(hub, (v) => v.view === view && v.buttons[name], name); await tap(v.buttons[name]); };
      await page.goto(`http://127.0.0.1:${PORT}/index.html?extreme90p28=1&bench=1`);
      await tapHub('PilotStart', 'WELCOME');
      await tapHub('Familiar_PLAYED_A_LITTLE', 'FAMILIARITY');
      let home = 'SELECT';
      await waitFor(hub, (v) => v.view === 'SELECT', 'select');
      if (prev) {
        await tapHub('PreviousChallenges', 'SELECT'); home = 'PREVIOUS';
        await waitFor(hub, (v) => v.view === 'PREVIOUS', 'previous');
        for (let k = 0; k < 40 && !(await hub()).buttons[tile]; k++) { await page.mouse.move(W / 2, H / 2); await page.mouse.wheel(0, 120); await sleep(250); }
      }
      await page.evaluate(() => { window.chainEscapeVhBench = null; });
      await tapHub(tile, home);
      const b = await waitFor(() => page.evaluate(() => window.chainEscapeVhBench || null), (x) => x.done && x.results.length === 1 && x.results[0].id === id, 'bench ' + id);
      const row = { round: r + 1, board: id, verify_ms: b.results[0].verify_ms, nodes: b.results[0].verify_nodes, load1: os.loadavg()[0].toFixed(2) };
      rows.push(row); console.log(JSON.stringify(row));
      await ctx.close();
    }
  }
} finally { await browser.close(); server.close(); }
const summary = {};
for (const [, id] of BOARDS) {
  const v = rows.filter((x) => x.board === id).map((x) => x.verify_ms).sort((a, b) => a - b);
  summary[id] = { runs: v, min: v[0], median: v[Math.floor(v.length / 2)], max: v[v.length - 1] };
}
console.log('SUMMARY ' + JSON.stringify(summary));
if (OUT) fs.writeFileSync(OUT, JSON.stringify({ rows, summary }, null, 1));
console.log(rows.length === ROUNDS * BOARDS.length ? 'N68 TIMING: PASSED (' + rows.length + ' measurements)' : 'N68 TIMING: FAILED');
