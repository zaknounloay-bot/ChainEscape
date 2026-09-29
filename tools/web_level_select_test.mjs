// Level Select touch test (v0.6.3): the exported game in real Chromium at
// iPhone size, driven with REAL touch events (CDP Input.dispatchTouchEvent:
// touchStart -> touchMove... -> touchEnd), like a finger on Safari.
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_level_select_test.mjs
//
// Checks: vertical swipes scroll the list no matter where they start (on a
// level tile, a Chapter header or empty space), fast flicks and slow drags,
// a swipe that starts on a tile never opens that level, a plain tap still
// opens it, and the whole list (Level 1 -> 200 -> 1) can be scrolled.
// Positions come from window.chainEscapeSelect (published by the game).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const { chromium } = pw;

const root = path.resolve(process.argv[2] || 'build/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, req.url === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8767, '127.0.0.1');
const URL = 'http://127.0.0.1:8767/index.html';

const W = 390, H = 844;  // iPhone 12-15 viewport
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };

const browser = await chromium.launch({ headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
const page = await context.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
const cdp = await context.newCDPSession(page);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const game = () => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
const sel = () => page.evaluate(() => window.chainEscapeSelect || null).catch(() => null);
async function waitFor(get, pred, what, ms = 90000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await get();
    if (s && pred(s)) return s;
    await sleep(200);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s));
}
const px = (p) => [p[0] * W, p[1] * H];

async function touch(type, x, y) {
  await cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
}
async function tap(p) {
  const [x, y] = px(p);
  await touch('touchStart', x, y);
  await sleep(60);
  await touch('touchEnd', x, y);
}
// A vertical swipe: dy < 0 = finger moves up (list scrolls down).
async function swipe(p, dy, ms, steps) {
  const [x, y] = px(p);
  await touch('touchStart', x, y);
  for (let i = 1; i <= steps; i++) {
    await sleep(ms / steps);
    await touch('touchMove', x, y + dy * i / steps);
  }
  await touch('touchEnd', x, y + dy);
}
async function settle() { await sleep(900); return sel(); }

await page.goto(URL);
let s = await waitFor(game, (x) => x.title_open, 'title');
await page.touchscreen.tap(...px(s.title_continue));
s = await waitFor(game, (x) => !x.title_open && x.level >= 1, 'level 1');
await sleep(800);
await page.touchscreen.tap(...px(s.levels_button));
await waitFor(game, (x) => x.select_open, 'level select');
let ls = await waitFor(sel, (x) => x.open && x.tile.length && x.header.length && x.gap.length, 'select positions');
check(ls.max > 5000, `the list is long (scroll range ${ls.max}px for 200 levels)`);

// Swipes from each kind of start point, fast and slow, up and down.
const kinds = [['tile', 'a level tile'], ['header', 'a Chapter header'], ['gap', 'empty space']];
// Scroll (a little at a time) until a start point of this kind is on screen.
async function ensure(key) {
  let x = await sel();
  for (let i = 0; i < 40 && !x[key].length; i++) {
    await swipe(x.tile.length ? x.tile : [0.5, 0.5], -140, 400, 8);
    x = await settle();
  }
  return x;
}
for (const [key, label] of kinds) {
  for (const [speed, ms, steps] of [['fast flick', 90, 4], ['slow drag', 900, 18]]) {
    ls = await ensure(key);
    const before = ls.scroll;
    const level = (await game()).level;
    await swipe(ls[key], -260, ms, steps);
    let after = await settle();
    check(after.open && after.scroll - before >= 150, `${speed} UP starting on ${label} scrolls the list (${before} -> ${after.scroll})`);
    check(after.open && (await game()).level === level, `${speed} UP starting on ${label} opens nothing`);
    const mid = after.scroll;
    after = await ensure(key);
    const mid2 = after.scroll;
    await swipe(after[key], 260, ms, steps);
    after = await settle();
    check(mid > before && (after.scroll < mid2 - 150 || after.scroll === 0), `${speed} DOWN starting on ${label} scrolls back (${mid2} -> ${after.scroll})`);
  }
}

// Whole list: Level 1 -> 200 with flicks, then back to the top.
let flicks = 0;
ls = await sel();
while (ls.scroll < ls.max - 2 && flicks < 80) {
  await swipe(ls.tile.length ? ls.tile : ls.gap, -380, 90, 4);
  flicks++;
  ls = await settle();
}
check(ls.scroll >= ls.max - 2, `flicking reaches the end of the list (Level 200) in ${flicks} flicks (scroll ${ls.scroll}/${ls.max})`);
flicks = 0;
while (ls.scroll > 0 && flicks < 80) {
  await swipe(ls.gap.length ? ls.gap : [0.5, 0.4], 380, 90, 4);
  flicks++;
  ls = await settle();
}
check(ls.scroll === 0, `flicking back reaches the top (Level 1) in ${flicks} flicks`);

// A plain tap on a level tile still opens it (Level 1 is at the top).
ls = await sel();
const n = ls.open_number;
check(ls.open_tile.length > 0, `an unlocked tile is on screen at the top (Level ${n})`);
await tap(ls.open_tile);
s = await waitFor(game, (x) => !x.select_open, 'select to close', 8000).catch(() => null);
check(!!s && s.level === n, `tapping Level ${n}'s tile opens it (level ${s && s.level})`);
check(errors.length === 0, `no page errors (${errors.join(' | ')})`);

await browser.close();
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(failed === 0 ? `LEVEL SELECT TOUCH TEST PASSED (${results.length} checks)` : `LEVEL SELECT TOUCH TEST FAILED (${failed} of ${results.length})`);
process.exit(failed === 0 ? 0 : 1);
