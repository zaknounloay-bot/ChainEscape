// OPENING EXPERIENCE LAB (?openinglab) in the exported game, real Chromium
// at iPhone size, real touch taps on the title / NEXT buttons; levels are
// cleared with the game's debug auto-solve (F1, then S).
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   SHOTS=<dir> node tools/web_opening_lab_test.mjs build/web
//
// A: a player with a real save (Level 150) opens ?openinglab=reset: the lab
//    starts as a brand-new player at the candidate Level 1; the real save
//    is not touched.
// B: Levels 1-10 in order: each is the lab candidate (name), hearts from
//    Level 6, every level clears, NEXT after 10 opens production Level 11.
//    A screenshot of every level's start.
// C: ?openinglab=1 after a reload continues the lab; without the parameter
//    the game opens the real save (Level 150), unchanged. No page errors.
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
const root = path.resolve(process.argv[2] || 'build/web');
const shots = process.env.SHOTS || os.tmpdir();
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, req.url === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8774, '127.0.0.1');
const BASE = 'http://127.0.0.1:8774/index.html';
const NAMES = ['First Steps', 'In The Way', 'The Knot', 'Two Threads', 'Long Way Round', 'Spinner', 'Right On Time', 'Hidden Arrow', 'Out Of Sight', 'Clockwork'];

const W = 390, H = 844;
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const VIEW = { viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true };

function saveText(cleared, current) {
  const lines = ['[meta]', '', 'version=5', 'seq=5', '', '[progress]', '', `current_level=${current}`, `highest_completed=${cleared}`,
    `highest_unlocked=${cleared + 1}`, '', '[economy]', '', 'coins=500', '', '[scores]', ''];
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=5000`);
  lines.push('', '[stars]', '');
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=3`);
  return lines.join('\n') + '\n';
}
const REAL = saveText(149, 150);

const state = (page) => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(page, pred, what, ms = 120000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(page);
    if (s && pred(s)) return s;
    await sleep(150);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, card: s.card_open, title: s.title_open }));
}
const tapAt = (page, p) => page.touchscreen.tap(p[0] * W, p[1] * H);

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-olab-'));
const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, ...VIEW });
const errors = [];
try {
  await ctx.addInitScript((t) => { try { if (!localStorage.getItem('chain_escape_save')) localStorage.setItem('chain_escape_save', t); } catch (e) {} }, REAL);
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  // ===== A =====
  await page.goto(BASE + '?openinglab=reset');
  let s = await waitFor(page, (x) => x.title_open, 'title');
  check(s.opening_lab && s.level === 1 && s.level_name === NAMES[0] && s.highest_completed === 0, `A: the lab starts as a new player at Level 1 (${s.level_name}, cleared ${s.highest_completed})`);
  await page.screenshot({ path: path.join(shots, 'olab_title.png') });
  await tapAt(page, s.title_continue);
  s = await waitFor(page, (x) => !x.title_open, 'title closed');
  // ===== B =====
  await page.keyboard.press('F1');
  await sleep(300);
  await page.keyboard.press('F1');  // close the panel again for clean screenshots (debug stays armed)
  for (let n = 1; n <= 10; n++) {
    s = await waitFor(page, (x) => x.level === n && !x.card_open, `level ${n}`);
    await sleep(1200);
    await page.screenshot({ path: path.join(shots, `olab_L${String(n).padStart(2, '0')}.png`) });
    check(s.level_name === NAMES[n - 1], `B: Level ${n} is the lab candidate "${s.level_name}"`);
    check(s.max_hearts === (n >= 6 ? 3 : 0), `B: Level ${n} hearts ${s.max_hearts}`);
    await page.keyboard.press('F1');
    await sleep(200);
    await page.keyboard.press('s');
    s = await waitFor(page, (x) => x.card_open && x.level === n, `level ${n} cleared`, 60000);
    await page.keyboard.press('F1');
    await sleep(900);
    s = await state(page);
    if (n === 10) await page.screenshot({ path: path.join(shots, 'olab_L10_card.png') });
    await tapAt(page, s.next);
    await sleep(900);
    s = await state(page);
    if (s.chapter_card_open) { await tapAt(page, s.chapter_continue); await sleep(900); }
  }
  s = await waitFor(page, (x) => x.level === 11 && !x.card_open && !x.chapter_card_open, 'level 11');
  check(s.level_name === 'Order Matters', `B: NEXT after Level 10 opens production Level 11 (${s.level_name})`);
  const log = await page.evaluate(() => { try { return JSON.parse(localStorage.getItem('chain_escape_openinglab_log') || '[]'); } catch (e) { return []; } });
  check([...Array(10).keys()].every((i) => log.some((e) => e.kind === 'next' && e.level === i + 1)), `B: the lab log has NEXT for Levels 1-10 (${log.length} events)`);
  const realNow = await page.evaluate(() => localStorage.getItem('chain_escape_save'));
  check(realNow === REAL, 'A: the real save is untouched by the lab');
  // ===== C =====
  await page.goto(BASE + '?openinglab=1');
  s = await waitFor(page, (x) => x.title_open, 'title (lab again)');
  check(s.opening_lab && s.level === 11 && s.highest_completed === 10, `C: ?openinglab=1 continues the lab (level ${s.level}, cleared ${s.highest_completed})`);
  await page.goto(BASE);
  s = await waitFor(page, (x) => x.title_open, 'title (real)');
  check(!s.opening_lab && s.level === 150 && s.highest_completed === 149, `C: without the parameter the real save opens (level ${s.level}, cleared ${s.highest_completed})`);
  s = await state(page);
  await tapAt(page, s.title_continue);
  s = await waitFor(page, (x) => !x.title_open, 'real title closed');
  check(s.level_name !== NAMES[0], 'C: production levels outside the lab');
  check(errors.length === 0, `C: no page errors (${errors.join(' | ')})`);
} catch (e) {
  check(false, 'exception: ' + e.message);
} finally {
  await ctx.close();
  fs.rmSync(dir, { recursive: true, force: true });
  server.close();
}
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed ? 'WEB OPENING LAB TEST FAILED' : 'WEB OPENING LAB TEST PASSED');
process.exit(failed ? 1 : 0);
