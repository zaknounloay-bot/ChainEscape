// v0.7 PORTAL arc (levels 201-225) in the exported game, real Chromium at
// iPhone size, real touch taps on the title / NEXT buttons.
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_portal_arc_test.mjs build/web
//
// A: a save that cleared 200 -> CONTINUE (200, no card) -> clear it ->
//    NEXT -> 201: the NEW MECHANIC card shows once, the board has its
//    portals, the card closes by itself, 201 clears, 202 has no card;
//    after a reload the card is remembered.
// B: the card never opens over the title: a save standing on 201 shows it
//    only after CONTINUE.
// C: not retroactive: a save that already cleared 201 never sees it.
// D: Level 225 completes with the short MILESTONE card; Level Select lists
//    225 levels. No page errors anywhere.
// State comes from window.chainEscapeState (published by the game).
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
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, req.url === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8771, '127.0.0.1');
const URL = 'http://127.0.0.1:8771/index.html';

const W = 390, H = 844;
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const VIEW = { viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true };

// A save in the game's own format: levels 1..cleared done, standing on `current`.
function saveText(cleared, current, tips = []) {
  const lines = ['[meta]', '', 'version=5', 'seq=5', '', '[progress]', '', `current_level=${current}`, `highest_completed=${cleared}`,
    `highest_unlocked=${cleared + 1}`, '', '[economy]', '', 'coins=500', '', '[chapters]', '',
    `tips_seen=[${['lesson_switch', 'lesson_gate', 'lesson_armor', ...tips].map((t) => `"${t}"`).join(', ')}]`, '', '[scores]', ''];
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=5000`);
  lines.push('', '[stars]', '');
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=3`);
  return lines.join('\n') + '\n';
}

async function open(save) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-portal-'));
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, ...VIEW });
  if (save) await ctx.addInitScript((t) => { try { if (!localStorage.getItem('chain_escape_save')) localStorage.setItem('chain_escape_save', t); } catch (e) {} }, save);
  const page = ctx.pages()[0] || await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(URL);
  return { ctx, page, errors, dir };
}
const state = (g) => g.page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(g, pred, what, ms = 120000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(g);
    if (s && pred(s)) return s;
    await sleep(150);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, intro: s.intro_open, card: s.card_open, title: s.title_open }));
}
const tapAt = (g, p) => g.page.touchscreen.tap(p[0] * W, p[1] * H);
async function enter(g) {
  const s = await waitFor(g, (x) => x.title_open, 'title');
  await tapAt(g, s.title_continue);
  return waitFor(g, (x) => !x.title_open, 'title closed');
}
// Debug auto-solve (F1 opens the debug panel, S solves) until the card shows.
async function solve(g, n) {
  await g.page.keyboard.press('s');
  return waitFor(g, (x) => x.card_open && x.level === n, `level ${n} cleared`, 90000);
}
async function close(g) {
  await g.ctx.close();
  fs.rmSync(g.dir, { recursive: true, force: true });
}

try {
  // ===== A: 200 -> 201 -> 202, the card once =====
  {
    const g = await open(saveText(200, 200));
    let s = await waitFor(g, (x) => x.title_open, 'title A');
    check(s.continue_text === 'CONTINUE  -  LEVEL 200' && !s.intro_open, `A: title offers ${s.continue_text}, no card over the title`);
    s = await enter(g);
    await sleep(600);
    s = await state(g);
    check(s.level === 200 && !s.intro_open && s.portals === 0, 'A: Level 200 has no portals and no card');
    await g.page.keyboard.press('F1');
    await sleep(300);
    s = await solve(g, 200);
    await sleep(400);
    await tapAt(g, s.next);
    await sleep(700);
    s = await state(g);
    if (s.chapter_card_open) { await tapAt(g, s.chapter_continue); }
    s = await waitFor(g, (x) => x.level === 201 && !x.card_open && !x.chapter_card_open, 'level 201');
    check(s.intro_open && s.intro_seen, 'A: NEXT from 200 -> 201 opens the NEW MECHANIC card (saved at once)');
    check(s.portals === 2 && s.chapter === 21, `A: 201 has its portal pair (${s.portals} cells), Chapter ${s.chapter}`);
    await sleep(700);
    await g.page.screenshot({ path: path.join(os.tmpdir(), 'ce_portal_intro.png') });
    const t0 = Date.now();
    s = await waitFor(g, (x) => !x.intro_open, 'card closes', 6000);
    check(Date.now() - t0 < 3500, `A: the card closes by itself (${Date.now() - t0} ms)`);
    await g.page.keyboard.press('F1');
    await sleep(300);
    await g.page.screenshot({ path: path.join(os.tmpdir(), 'ce_portal_201.png') });
    await g.page.keyboard.press('F1');
    await sleep(300);
    s = await solve(g, 201);
    check(s.card_open && s.level === 201, 'A: Level 201 clears');
    await sleep(400);
    await tapAt(g, s.next);
    s = await waitFor(g, (x) => x.level === 202 && !x.card_open, 'level 202');
    await sleep(500);
    s = await state(g);
    check(!s.intro_open && s.portals > 0, 'A: 202 (portals) shows no second card');
    await g.page.reload();
    s = await waitFor(g, (x) => x.title_open, 'title after reload');
    check(s.intro_seen && s.continue_text === 'CONTINUE  -  LEVEL 202', `A: after a reload the card is remembered (${s.continue_text})`);
    check(g.errors.length === 0, `A: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== B: never over the title =====
  {
    const g = await open(saveText(200, 201));
    let s = await waitFor(g, (x) => x.title_open, 'title B');
    await sleep(2500);
    s = await state(g);
    check(s.title_open && !s.intro_open && !s.intro_seen, 'B: standing on 201 behind the title: no card yet, not marked seen');
    s = await enter(g);
    s = await waitFor(g, (x) => x.intro_open, 'card after CONTINUE', 5000);
    check(s.level === 201 && s.intro_seen, 'B: CONTINUE -> the card shows on 201');
    check(g.errors.length === 0, `B: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== C: not retroactive =====
  {
    const g = await open(saveText(205, 203));
    await enter(g);
    await sleep(2500);
    const s = await state(g);
    check(s.level === 203 && s.portals > 0 && !s.intro_open && !s.intro_seen, 'C: a player who already cleared 201 never gets the card');
    await close(g);
  }
  // ===== D: 225 milestone, Level Select =====
  {
    const g = await open(saveText(224, 225, ['intro_portal']));
    let s = await enter(g);
    await sleep(600);
    s = await state(g);
    check(s.level === 225 && !s.intro_open && s.portals >= 4, `D: 225 loads with two portal pairs (${s.portals} cells), no card`);
    const coins0 = s.coins;
    await g.page.keyboard.press('F1');
    await sleep(300);
    s = await solve(g, 225);
    await sleep(2500);
    s = await state(g);
    check(s.celebration === 'short' && s.card_title === 'MILESTONE CLEARED!', `D: 225 shows the short MILESTONE (${s.card_title})`);
    check(s.coins - coins0 < 120, `D: no milestone bonus paid (+${s.coins - coins0} coins, normal level reward only)`);
    await g.page.keyboard.press('F1');
    await sleep(300);
    await g.page.reload();
    s = await enter(g);
    await sleep(800);
    s = await state(g);
    await tapAt(g, s.levels_button);
    s = await waitFor(g, (x) => x.select_open, 'level select');
    check(s.select_unlocked === 225 && s.select_max_unlocked === 225, `D: Level Select lists 225 unlocked levels (${s.select_unlocked})`);
    check(g.errors.length === 0, `D: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
} catch (e) {
  check(false, 'exception: ' + e.message);
}
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB PORTAL ARC TEST PASSED' : 'WEB PORTAL ARC TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
