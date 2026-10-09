// v0.8 levels 226-300 (SEQUENCE, MOVABLE, INTEGRATION) in the exported game,
// real Chromium at iPhone size, real touch taps on the title / NEXT / Chapter
// CONTINUE buttons; levels are cleared with the game's debug auto-solve
// (F1, then S - it taps the solver's moves, first stages and pushes
// included).
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_era3_test.mjs build/web
//
// A: 225 -> NEXT -> 226: the SEQUENCE card (once), 226 clears, 227 has no card.
// B: 250 (strong milestone) -> NEXT (Chapter card) -> 251: the MOVABLE card;
//    251 clears with its Movable block left on the board.
// C: 275 short milestone; representative 276-299 levels clear.
// D: 300 major milestone: "300 LEVELS ESCAPED!" fitted on screen, then the
//    card (CONTINUE -> Chapter 30 card) offers LEVEL SELECT, which opens Level Select (no loop to Level 1);
//    after a reload: CONTINUE - LEVEL 300, all 300 levels in Level Select.
// E: not retroactive, intros remembered after a reload. No page errors.
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
}).listen(8773, '127.0.0.1');
const URL = 'http://127.0.0.1:8773/index.html';

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
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-era3-'));
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
async function debugOn(g) { await g.page.keyboard.press('F1'); await sleep(300); }
async function solve(g, n) {
  await waitFor(g, (x) => !x.intro_open, 'no card', 8000);
  await g.page.keyboard.press('s');
  return waitFor(g, (x) => x.card_open && x.level === n, `level ${n} cleared`, 150000);
}
// NEXT on the card (and CONTINUE on a Chapter card if one opens).
async function next(g, to) {
  let s = await state(g);
  await tapAt(g, s.next);
  await sleep(800);
  s = await state(g);
  if (s.chapter_card_open) { await tapAt(g, s.chapter_continue); }
  return waitFor(g, (x) => x.level === to && !x.card_open && !x.chapter_card_open, `level ${to}`);
}
async function close(g) {
  await g.ctx.close();
  fs.rmSync(g.dir, { recursive: true, force: true });
}

try {
  // ===== A: Sequence intro =====
  {
    const g = await open(saveText(225, 225, ['intro_portal']));
    let s = await enter(g);
    await debugOn(g);
    s = await solve(g, 225);
    s = await next(g, 226);
    check(s.intro_open && s.intro_mechanic === 'sequence' && s.seq_blocks > 0, `A: 225 -> 226 opens the SEQUENCE card (${s.intro_mechanic})`);
    await sleep(600);
    await g.page.screenshot({ path: path.join(shots, 'ce_intro_sequence.png') });
    const t0 = Date.now();
    s = await waitFor(g, (x) => !x.intro_open, 'card closes', 6000);
    check(Date.now() - t0 < 3500, `A: the card closes by itself (${Date.now() - t0} ms)`);
    s = await solve(g, 226);
    check(s.card_open, 'A: 226 clears (first stage + second stage by the solver)');
    s = await next(g, 227);
    await sleep(500);
    s = await state(g);
    check(!s.intro_open && s.intros_seen.includes('intro_sequence'), 'A: 227 shows no second card');
    await g.page.reload();
    s = await waitFor(g, (x) => x.title_open, 'title after reload');
    check(s.intros_seen.includes('intro_sequence') && s.continue_text === 'CONTINUE  -  LEVEL 227', `A: remembered after a reload (${s.continue_text})`);
    check(g.errors.length === 0, `A: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== B: 250 strong milestone, Movable intro =====
  {
    const g = await open(saveText(249, 250, ['intro_portal', 'intro_sequence']));
    let s = await enter(g);
    await debugOn(g);
    const coins0 = s.coins;
    s = await solve(g, 250);
    await sleep(2500);
    s = await state(g);
    check(s.celebration === 'lab_milestone_strong' && s.card_title === '250 LEVELS ESCAPED!', `B: 250 milestone (${s.celebration}, ${s.card_title})`);
    check(!/MILESTONE/.test(s.coin_notes || '') && s.coins - coins0 < 120 + (s.chapter_complete ? 150 : 0), `B: no milestone bonus (+${s.coins - coins0} coins: ${s.coin_notes})`);
    s = await next(g, 251);
    check(s.intro_open && s.intro_mechanic === 'movable' && s.crates > 0, `B: 250 -> 251 opens the MOVABLE card (${s.intro_mechanic}, ${s.crates} Movable)`);
    await sleep(600);
    await g.page.screenshot({ path: path.join(shots, 'ce_intro_movable.png') });
    s = await waitFor(g, (x) => !x.intro_open, 'card closes', 6000);
    await g.page.keyboard.press('F1');
    await sleep(300);
    await g.page.screenshot({ path: path.join(shots, 'ce_level_251.png') });
    await g.page.keyboard.press('F1');
    await sleep(300);
    s = await solve(g, 251);
    check(s.card_open && s.crates > 0, `B: 251 clears with its Movable block still on the board (${s.crates})`);
    check(g.errors.length === 0, `B: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== C: 275 short milestone, representative integration levels =====
  {
    const g = await open(saveText(274, 275, ['intro_portal', 'intro_sequence', 'intro_movable']));
    let s = await enter(g);
    await debugOn(g);
    s = await solve(g, 275);
    await sleep(2200);
    s = await state(g);
    check(s.celebration === 'lab_milestone_plus' && s.card_title === '275 LEVELS ESCAPED!', `C: 275 milestone (${s.celebration}, ${s.card_title})`);
    s = await next(g, 276);
    check(!s.intro_open, 'C: 276 (integration) has no card');
    for (const n of [276, 277, 278]) {
      s = await solve(g, n);
      check(s.card_open, `C: ${n} clears`);
      if (n < 278) s = await next(g, n + 1);
    }
    check(g.errors.length === 0, `C: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== C2: more of 276-299 =====
  for (const n of [286, 293, 299]) {
    const g = await open(saveText(n - 1, n, ['intro_portal', 'intro_sequence', 'intro_movable']));
    let s = await enter(g);
    await debugOn(g);
    if (n === 293) {
      await g.page.keyboard.press('F1');
      await sleep(300);
      await g.page.screenshot({ path: path.join(shots, `ce_level_${n}.png`) });
      await g.page.keyboard.press('F1');
      await sleep(300);
    }
    s = await solve(g, n);
    check(s.card_open && s.level === n, `C: ${n} clears`);
    check(g.errors.length === 0, `C: ${n} no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== D: 300 major milestone, after 300 =====
  {
    const g = await open(saveText(299, 300, ['intro_portal', 'intro_sequence', 'intro_movable']));
    let s = await enter(g);
    await debugOn(g);
    await g.page.keyboard.press('F1');
    await sleep(300);
    await g.page.screenshot({ path: path.join(shots, 'ce_level_300.png') });
    await g.page.keyboard.press('F1');
    await sleep(300);
    await g.page.keyboard.press('s');
    s = await waitFor(g, (x) => x.major_rect && x.major_rect[2] > 0, 'major overlay', 150000);
    await g.page.screenshot({ path: path.join(shots, 'ce_300_overlay.png') });
    const r = s.major_rect;
    check(r[0] >= 0 && r[1] >= 0 && r[2] <= 1 && r[3] <= 1 && r[2] - r[0] > 0.5, `D: the 300 overlay fits the screen (${r.map((x) => x.toFixed(3)).join(', ')})`);
    s = await waitFor(g, (x) => x.card_open && x.level === 300, 'card 300', 20000);
    await sleep(800);
    s = await state(g);
    await g.page.screenshot({ path: path.join(shots, 'ce_300_card.png') });
    check(s.celebration === 'major' && s.card_title === '300 LEVELS ESCAPED!', `D: 300 major milestone card (${s.card_title})`);
    check(!/GRAND|FINAL|COMPLETE/.test(s.card_title), 'D: no GRAND MASTER / FINAL / GAME COMPLETE wording');
    // 300 also completes Chapter 30 here: the card says CONTINUE (to the
    // Chapter card), whose button then reads LEVEL SELECT.
    const viaChapter = s.chapter_complete > 0;
    check(s.next_text === (viaChapter ? 'CONTINUE' : 'LEVEL SELECT'), `D: the card offers ${s.next_text}`);
    await tapAt(g, s.next);
    await sleep(900);
    s = await state(g);
    check(s.chapter_card_open === viaChapter, `D: Chapter 30 card ${viaChapter ? 'opens' : 'skipped'}`);
    if (s.chapter_card_open) {
      await g.page.screenshot({ path: path.join(shots, 'ce_300_chapter_card.png') });
      check(s.chapter_continue_text === 'LEVEL SELECT', `D: the Chapter 30 card offers ${s.chapter_continue_text}`);
      await tapAt(g, s.chapter_continue); await sleep(900);
    }
    s = await waitFor(g, (x) => x.select_open, 'level select after 300', 8000);
    check(s.select_open && s.level === 300, `D: after 300 -> Level Select (still on ${s.level}, not Level 1)`);
    check(s.select_unlocked === 300, `D: all 300 levels open in Level Select (${s.select_unlocked})`);
    await g.page.reload();
    s = await waitFor(g, (x) => x.title_open, 'title after reload');
    check(s.continue_text === 'CONTINUE  -  LEVEL 300' && s.highest_completed === 300, `D: after a reload: ${s.continue_text}`);
    check(g.errors.length === 0, `D: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== E: not retroactive =====
  {
    const g = await open(saveText(260, 240, ['intro_portal']));
    await enter(g);
    await sleep(2500);
    let s = await state(g);
    check(s.level === 240 && !s.intro_open && !s.intros_seen.includes('intro_sequence'), 'E: a player past 226 never gets the SEQUENCE card');
    await close(g);
  }
} catch (e) {
  check(false, 'exception: ' + e.message);
}
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB ERA3 TEST PASSED' : 'WEB ERA3 TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
