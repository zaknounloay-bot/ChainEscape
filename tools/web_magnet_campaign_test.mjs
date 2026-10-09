// MAGNET campaign (Levels 76-99) in the exported game, real Chromium at
// iPhone size, real touch taps.
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   godot --headless --path . --export-release "Web QA" build/web_qa/index.html
//   node tools/web_magnet_campaign_test.mjs build/web build/web_qa
//
// A: a save standing on 76 -> CONTINUE: the NEW MECHANIC card (magnet) shows
//    first, then the finger lesson; following the finger with real touches
//    makes a magnet escape and pull the block behind into its cell; the
//    lesson ends with its success line and is saved (not repeated after a
//    reload). UNDO puts the pulled block back; RESTART restores the board.
// B: SHOW A MOVE on 76, 88, 95, 98, 99: time from the tap until the hinted
//    block shows (browser, SwiftShader - slower than a phone GPU, CPU-bound
//    like a phone's).
// C: the Hammer on a magnet (Level 86): the magnet goes, nothing is pulled,
//    the "nothing is pulled" message shows; UNDO brings it back.
// D: 79 -> 80 and 99 -> 100 by NEXT: no card, no errors.
// Q: the QA build: ?experiencelab=76&qareset=1 opens 76 with the card, then
//    the Magnet lesson. No page errors anywhere.
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

const webRoot = path.resolve(process.argv[2] || 'build/web');
const qaRoot = path.resolve(process.argv[3] || 'build/web_qa');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const m = req.url.split('?')[0].match(/^\/(web|qa)\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const file = path.join(m[1] === 'qa' ? qaRoot : webRoot, decodeURIComponent(m[2] || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8773, '127.0.0.1');
const WEB = 'http://127.0.0.1:8773/web/index.html';
const QA = 'http://127.0.0.1:8773/qa/index.html';

const W = 390, H = 844;
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const VIEW = { viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true };
const shots = process.env.SHOTS || os.tmpdir();

// A save in the game's own format: levels 1..cleared done, standing on `current`.
function saveText(cleared, current, tips = []) {
  const lines = ['[meta]', '', 'version=5', 'seq=5', '', '[progress]', '', `current_level=${current}`, `highest_completed=${cleared}`,
    `highest_unlocked=${cleared + 1}`, '', '[economy]', '', 'coins=500', 'inventory={"hint": 9, "hammer": 9}', '', '[chapters]', '',
    `tips_seen=[${['lesson_lock', ...tips].map((t) => `"${t}"`).join(', ')}]`, '', '[scores]', ''];
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=5000`);
  lines.push('', '[stars]', '');
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=3`);
  return lines.join('\n') + '\n';
}

async function open(url, save) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-magnet-'));
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, ...VIEW });
  if (save) await ctx.addInitScript((t) => { try { if (!localStorage.getItem('chain_escape_save')) localStorage.setItem('chain_escape_save', t); } catch (e) {} }, save);
  const page = ctx.pages()[0] || await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(url);
  return { ctx, page, errors, dir };
}
const state = (g) => g.page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(g, pred, what, ms = 120000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(g);
    if (s && pred(s)) return s;
    await sleep(100);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, intro: s.intro_open, card: s.card_open, title: s.title_open, lesson: s.lesson }));
}
const tapAt = (g, p) => g.page.touchscreen.tap(p[0] * W, p[1] * H);
async function enter(g) {
  const s = await waitFor(g, (x) => x.title_open, 'title');
  await tapAt(g, s.title_continue);
  return waitFor(g, (x) => !x.title_open, 'title closed');
}
async function solve(g, n) {
  await g.page.keyboard.press('F1'); await sleep(250);
  await g.page.keyboard.press('s');
  const s = await waitFor(g, (x) => x.card_open && x.level === n, `level ${n} cleared`, 90000);
  await g.page.keyboard.press('F1'); await sleep(250);
  return s;
}
async function close(g) {
  await g.ctx.close();
  fs.rmSync(g.dir, { recursive: true, force: true });
}
const cells = (s) => Object.fromEntries(s.tw_blocks.map((b) => [b.id, b.c + ',' + b.r]));
const magCells = (s) => s.tw_blocks.filter((b) => b.mag).map((b) => b.c + ',' + b.r);

try {
  // ===== A: the Level 76 lesson, Undo, Restart =====
  {
    const g = await open(WEB, saveText(75, 76));
    let s = await waitFor(g, (x) => x.title_open, 'title A');
    check(!s.intro_open, 'A: no card over the title');
    await enter(g);
    s = await waitFor(g, (x) => x.intro_open, 'card on 76', 8000);
    check(s.level === 76 && s.intro_mechanic === 'magnet' && s.magnets >= 1, `A: 76 opens the NEW MECHANIC card first (${s.intro_mechanic}, ${s.magnets} magnet)`);
    check(s.lesson === '' || !s.tip_text, 'A: nothing of the lesson shows under the card');
    await sleep(500);
    await g.page.screenshot({ path: path.join(shots, 'ce_magnet_card_76.png') });
    s = await waitFor(g, (x) => !x.intro_open, 'card closes', 8000);
    s = await waitFor(g, (x) => x.lesson === 'magnet' && x.lesson_target.length === 2, 'magnet lesson', 8000);
    check(true, 'A: after the card the Magnet lesson starts with its finger on a block');
    await sleep(400);
    await g.page.screenshot({ path: path.join(shots, 'ce_magnet_lesson_76.png') });
    const start = cells(s);
    const startCount = s.blocks_left;
    let pulled = false, before = s, taps = 0;
    for (; taps < 8 && !pulled; taps++) {
      before = await state(g);
      const mags = magCells(before);
      await tapAt(g, before.lesson_target);
      await sleep(900);
      s = await state(g);
      const after = cells(s);
      if (process.env.DEBUG) await g.page.screenshot({ path: path.join(shots, `dbg_${taps}.png`) });
      if (process.env.DEBUG) console.log(JSON.stringify({t: before.lesson_target, tip: s.tip_text, left: s.blocks_left, b: s.tw_blocks.map((b) => [b.id, b.c, b.r, b.x, b.y, b.st, b.mag])}));
      // a block (not the magnet) now stands where a magnet stood
      pulled = s.tw_blocks.some((b) => !b.mag && mags.includes(b.c + ',' + b.r) && cells(before)[b.id] !== after[b.id]);
    }
    check(pulled, `A: following the finger (${taps} real taps) a magnet escaped and pulled the block behind into its cell`);
    s = await waitFor(g, (x) => x.lesson === '', 'lesson ends', 5000);
    check(true, 'A: the lesson ends on the pull');
    await sleep(300);
    await g.page.screenshot({ path: path.join(shots, 'ce_magnet_pulled_76.png') });
    // UNDO: the pulled block goes back, the magnet returns.
    const pulledState = cells(s);
    await tapAt(g, s.undo_button);
    await sleep(900);
    s = await state(g);
    const undone = cells(s);
    check(JSON.stringify(undone) === JSON.stringify(cells(before)) && JSON.stringify(undone) !== JSON.stringify(pulledState),
      'A: UNDO restores the board before the pull (magnet back, pulled block back on its own cell)');
    // RESTART: the starting board.
    await tapAt(g, s.restart_button);
    await sleep(1200);
    s = await state(g);
    check(s.blocks_left === startCount && JSON.stringify(cells(s)) === JSON.stringify(start), `A: RESTART restores the starting board (${s.blocks_left} blocks)`);
    check(s.lesson === '', 'A: the lesson does not come back after RESTART');
    await g.page.reload();
    s = await waitFor(g, (x) => x.title_open, 'title after reload');
    check(s.intros_seen.includes('intro_magnet'), `A: the card is remembered (${s.intros_seen})`);
    await enter(g);
    await sleep(1500);
    s = await state(g);
    check(s.level === 76 && !s.intro_open && s.lesson === '', 'A: after a reload 76 shows neither card nor lesson again');
    check(g.errors.length === 0, `A: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== B: SHOW A MOVE timing =====
  for (const n of [76, 88, 95, 98, 99]) {
    const g = await open(WEB, saveText(n - 1, n, ['intro_magnet', 'lesson_magnet']));
    await enter(g);
    let s = await waitFor(g, (x) => x.level === n && !x.intro_open, `level ${n}`);
    await sleep(800);
    s = await state(g);
    const t0 = Date.now();
    await tapAt(g, s.hint_button);
    s = await waitFor(g, (x) => x.hint_block >= 0, `hint on ${n}`, 20000);
    const ms = Date.now() - t0;
    check(ms < 3000, `B: SHOW A MOVE on ${n} shows a block in ${ms} ms (tap -> state, incl. ~100 ms polling)`);
    check(g.errors.length === 0, `B: ${n} no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== C: the Hammer on a magnet =====
  {
    const g = await open(WEB, saveText(85, 86, ['intro_magnet', 'lesson_magnet']));
    await enter(g);
    let s = await waitFor(g, (x) => x.level === 86 && !x.intro_open, 'level 86');
    await sleep(800);
    s = await state(g);
    const mags0 = s.magnets;
    let smashed = false;
    for (const m of s.tw_blocks.filter((b) => b.mag)) {
      const before = await state(g);
      if (!before.hammer_armed) { await tapAt(g, before.hammer_button); await sleep(400); }
      await tapAt(g, [m.x, m.y]);
      await sleep(1000);
      s = await state(g);
      if (s.hammers_used === 1) {
        const b0 = cells(before), b1 = cells(s);
        const moved = Object.keys(b1).filter((id) => b0[id] !== b1[id]);
        check(s.magnets === mags0 - 1 && !(m.id in b1), `C: the Hammer removes the magnet (${mags0} -> ${s.magnets})`);
        check(moved.length === 0, `C: nothing is pulled into its cell (${moved.length} blocks moved)`);
        await g.page.screenshot({ path: path.join(shots, 'ce_magnet_hammer_86.png') });
        await tapAt(g, s.undo_button);
        await sleep(900);
        s = await state(g);
        check(s.magnets === mags0 && JSON.stringify(cells(s)) === JSON.stringify(b0), 'C: UNDO brings the smashed magnet back');
        smashed = true;
        break;
      }
    }
    check(smashed, 'C: a magnet on 86 could be smashed safely');
    check(g.errors.length === 0, `C: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== D: 79 -> 80 and 99 -> 100 =====
  for (const [a, b] of [[79, 80], [89, 90], [99, 100]]) {
    const g = await open(WEB, saveText(a - 1, a, ['intro_magnet', 'lesson_magnet']));
    await enter(g);
    let s = await waitFor(g, (x) => x.level === a, `level ${a}`);
    await sleep(600);
    s = await solve(g, a);
    await sleep(500);
    await tapAt(g, s.next);
    await sleep(800);
    s = await state(g);
    if (s.chapter_card_open) { await tapAt(g, s.chapter_continue); }
    s = await waitFor(g, (x) => x.level === b && !x.card_open && !x.chapter_card_open, `level ${b}`);
    await sleep(800);
    s = await state(g);
    check(!s.intro_open && s.lesson === '', `D: ${a} -> ${b} by NEXT: no card, no lesson (${s.level_name}, ${s.magnets} magnets)`);
    check(g.errors.length === 0, `D: ${a} -> ${b} no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
  // ===== Q: the QA build jump =====
  {
    const g = await open(QA + '?experiencelab=76&qareset=1');
    let s = await waitFor(g, (x) => x.level === 76 && x.lab_qa && !x.title_open, 'QA 76');
    s = await waitFor(g, (x) => x.intro_open, 'QA card', 8000);
    check(s.intro_mechanic === 'magnet' && s.qa_build, 'Q: QA ?experiencelab=76 opens the Magnet card first');
    s = await waitFor(g, (x) => !x.intro_open && x.lesson === 'magnet' && x.lesson_target.length === 2, 'QA lesson', 10000);
    check(/MAGNET/.test(s.tip_text), `Q: then the Magnet lesson ("${s.tip_text}")`);
    check(g.errors.length === 0, `Q: no page errors (${g.errors.join(' | ')})`);
    await close(g);
  }
} catch (e) {
  check(false, 'exception: ' + e.message);
}
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB MAGNET CAMPAIGN TEST PASSED' : 'WEB MAGNET CAMPAIGN TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
