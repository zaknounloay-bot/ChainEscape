// FRAME-CAP PROBE (Phase 3B-A, measurement only): how much active play time
// AttemptTimer's 250 ms frame cap discards in real browser conditions.
// QA build, iPhone SE size, touch; reads window.chainEscapeState.attempt_cap
// and the finished attempt's time_result (discarded_ms, capped_frames,
// longest_frame_ms). Nothing is asserted: it prints a table.
//
//   node tools/web_frame_cap_probe.mjs build/web_qa > probe.txt
//
// Scenarios per level: idle play (15 s on the board), then the debug
// auto-solve (F1, S - real move animations) to the result card; again with
// Chrome CPU throttling x4 / x6 (slow-phone stand-in), with a 1.5 s
// JavaScript long task during play, and with the tab in the background for
// 5 s (Safari-style hide / resume).
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const { chromium } = pw;
const root = path.resolve(process.argv[2] || 'build/web_qa');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0].replace(/^\/+/, '') || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8793, '127.0.0.1');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: true, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio'] };

async function scenario(level, opts = {}) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-probe-'));
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: 375, height: 667 }, isMobile: true, hasTouch: true });
  const page = ctx.pages()[0] || await ctx.newPage();
  const st = () => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
  await page.goto(`http://127.0.0.1:8793/index.html?experiencelab=${level}&qareset=1`);
  let s = null;
  for (let i = 0; i < 1200; i++) {
    s = await st();
    if (s && s.level === level && !s.title_open && !s.intro_open && s.attempt_active) break;
    await sleep(100);
  }
  const atStart = s && s.attempt_cap;
  if (opts.throttle) {
    const cdp = await ctx.newCDPSession(page);
    await cdp.send('Emulation.setCPUThrottlingRate', { rate: opts.throttle });
  }
  await sleep(15000);  // idle play on the board
  if (opts.longTask) await page.evaluate((ms) => { const t = performance.now(); while (performance.now() - t < ms) { /* block */ } }, opts.longTask);
  if (opts.background) {
    const other = await ctx.newPage();
    await other.goto('about:blank');
    await other.bringToFront();
    await page.evaluate(() => document.dispatchEvent(new Event('visibilitychange')));
    await sleep(opts.background);
    await page.bringToFront();
    await other.close();
    await sleep(500);
  }
  await sleep(500);
  const idle = (await st()).attempt_cap;
  const idleS = await st();
  const idleMs = idleS.attempt_ms, idleHidden = idleS.page_hidden, idleActive = idleS.attempt_active;
  await page.focus('canvas').catch(() => {});
  await page.keyboard.press('F1'); await sleep(250);
  await page.keyboard.press('s');
  for (let i = 0; i < 1800; i++) {
    s = await st();
    if (s && s.card_open) break;
    await sleep(100);
  }
  const r = (s && s.time_result) || {};
  await ctx.close();
  fs.rmSync(dir, { recursive: true, force: true });
  return { level, ...opts, start: atStart, idle, idle_ms: idleMs, idle_hidden: idleHidden, idle_active: idleActive, time_ms: r.time_ms, discarded_ms: r.discarded_ms, capped_frames: r.capped_frames, longest_frame_ms: r.longest_frame_ms };
}

const rows = [];
for (const lv of [6, 31, 77, 150, 227, 280]) rows.push(await scenario(lv));
for (const lv of [77, 280]) rows.push(await scenario(lv, { throttle: 4 }));
for (const lv of [77, 280]) rows.push(await scenario(lv, { throttle: 6 }));
rows.push(await scenario(150, { longTask: 1500 }));
rows.push(await scenario(150, { background: 5000 }));
for (const r of rows) console.log(JSON.stringify(r));
server.close();
