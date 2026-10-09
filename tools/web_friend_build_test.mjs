// FRIEND-TEST (player) build: the "Web Friend Test" export preset
// (custom feature player_build) in real Chromium at iPhone sizes.
//
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   SHOTS=<dir> node tools/web_friend_build_test.mjs build/web_friend
//
// A: a brand-new player: the title opens, CONTINUE starts Level 1 of 300,
//    hearts / boosters as a new save, no developer page active.
// B: the debug panel never opens: F1, and 5 quick taps on the LEVEL title.
// C: developer pages are off: ?experiencelab=176, the QA session
//    (?experiencelab=250&qareset=1, =300), ?experiencelab=1,
//    ?openinglab=1, ?twinsprototype=1, ?mechlab=1, ?friendbench=1, ?vhtest
//    and ?sharetest=1 all give the normal game (no lab, no overlay).
// D: persistence: after a reload the save is still there (CONTINUE at the
//    level reached, same save sequence or newer).
// E: no page errors, no console errors; three iPhone sizes.
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
const root = path.resolve(process.argv[2] || 'build/web_friend');
const shots = process.env.SHOTS || os.tmpdir();
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, req.url === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8777, '127.0.0.1');
const BASE = 'http://127.0.0.1:8777/index.html';
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const state = (page) => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(page, pred, what, ms = 120000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(page);
    if (s && pred(s)) return s;
    await sleep(150);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, title: s.title_open }));
}

const errors = [];
for (const [W, H, label] of [[390, 844, 'iphone14'], [375, 667, 'iphoneSE'], [430, 932, 'promax']]) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-friend-'));
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const tap = (page, p) => page.touchscreen.tap(p[0] * W, p[1] * H);
  try {
    const page = ctx.pages()[0] || await ctx.newPage();
    page.on('pageerror', (e) => errors.push(`${label}: ${e.message}`));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(`${label} console: ${m.text()}`); });
    // ===== A =====
    await page.goto(BASE);
    let s = await waitFor(page, (x) => x.title_open, 'title');
    check(s.player_build && s.level === 1 && s.level_count === 300 && s.highest_completed === 0 && !s.experience_lab && !s.opening_lab && !s.twins_prototype,
      `A[${label}]: a new player sees the title, Level 1 of ${s.level_count} (player build ${s.player_build})`);
    await page.screenshot({ path: path.join(shots, `friend_${label}_title.png`) });
    await tap(page, s.title_continue);
    s = await waitFor(page, (x) => !x.title_open && x.level === 1, 'level 1');
    await sleep(1200);
    s = await state(page);
    check(!s.card_open && s.blocks_left > 0, `A[${label}]: CONTINUE starts Level 1 "${s.level_name}" (${s.blocks_left} blocks)`);
    await page.screenshot({ path: path.join(shots, `friend_${label}_level1.png`) });
    // ===== B =====
    await page.focus('canvas').catch(() => {});
    await page.keyboard.press('F1');
    await sleep(400);
    s = await state(page);
    const f1Open = s.debug_open;
    await page.keyboard.press('s');
    await sleep(6000);  // a dev build would be auto-solving by now
    s = await state(page);
    check(!f1Open && !s.debug_open && !s.completed, `B[${label}]: F1 (+ S) opens no debug panel and solves nothing (open after F1: ${f1Open})`);
    for (let i = 0; i < 6; i++) { await tap(page, s.level_label); await sleep(120); }
    await sleep(500);
    s = await state(page);
    check(!s.debug_open, `B[${label}]: 5+ taps on the LEVEL title open no debug panel`);
    if (label !== 'iphone14') { await ctx.close(); continue; }
    // ===== D =====
    const seq = s.save_seq;
    await page.reload();
    s = await waitFor(page, (x) => x.title_open, 'title after reload');
    check(s.level === 1 && s.save_seq >= seq && s.save_source !== 'new', `D: after a reload the save is kept (source ${s.save_source}, seq ${s.save_seq} >= ${seq})`);
    // ===== C =====
    for (const q of ['?experiencelab=176', '?v=123&experiencelab=250&qareset=1', '?experiencelab=300', '?v=123&experiencelab=1', '?openinglab=1', '?twinsprototype=1', '?mechlab=1', '?mechlab=sequence', '?friendbench=1', '?vhtest=1', '?sharetest=1']) {
      await page.goto(BASE + q);
      s = await waitFor(page, (x) => x.title_open || x.level > 0, 'page ' + q);
      await sleep(1500);
      s = await state(page);
      const overlay = await page.evaluate(() => !!document.getElementById('ce-sharetest'));
      check(s.title_open && !s.experience_lab && !s.opening_lab && !s.twins_prototype && s.level_count === 300 && !overlay,
        `C: ${q} gives the normal game (title ${s.title_open}, lab ${s.experience_lab}/${s.opening_lab}/${s.twins_prototype}, overlay ${overlay})`);
    }
  } catch (e) {
    check(false, `${label}: ${e.message}`);
  }
  await ctx.close();
}
check(errors.length === 0, `no page or console errors (${errors.slice(0, 4).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
