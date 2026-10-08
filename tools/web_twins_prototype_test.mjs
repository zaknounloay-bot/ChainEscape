// TWINS PROTOTYPE (?twinsprototype=1..3) in the exported game, real
// Chromium at iPhone sizes, real touch taps on the blocks.
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   SHOTS=<dir> node tools/web_twins_prototype_test.mjs build/web
//
// A: itch.io-style ?v=123456&twinsprototype=1 with a real save (Level 150)
//    and an Experience Lab save present: Level 1 "Twin Lights" opens
//    directly (no title), 3 levels, 2 bonds, 3 hearts. Real taps: green
//    (4,4) leaves; a blue twin whose partner's lane is blocked is a FREE
//    tap (no heart, nothing moves) and the rule is explained once; a
//    second such tap does not repeat it; yellow, purple leave; tapping a
//    blue twin releases the pair: both gone, chain +1, one Undo step, one
//    bond left. The red facing twins pass through each other.
// B: ?twinsprototype=2 / =3 open Hold Fire / Turnabout directly; Level 3
//    cleared -> the end-of-prototype screen (never Level 4) -> its button
//    opens Level Select.
// C: iPhone SE / 14 / Pro Max sizes: the board fits the screen.
// D: look-alikes (?xtwinsprototype=1, ?twinsprototype=4) start the normal
//    game with the real save; the real save and the Experience Lab save are
//    byte-identical afterwards. No page errors or console errors.
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
}).listen(8776, '127.0.0.1');
const BASE = 'http://127.0.0.1:8776/index.html';
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const SIZES = [[390, 844, 'iphone14'], [375, 667, 'iphoneSE'], [430, 932, 'promax']];
const TWIN_TEXT = "Twins leave together - clear the other twin's path first";

function saveText(cleared, current, seq = 5) {
  const lines = ['[meta]', '', 'version=5', `seq=${seq}`, '', '[progress]', '', `current_level=${current}`, `highest_completed=${cleared}`,
    `highest_unlocked=${cleared + 1}`, '', '[economy]', '', 'coins=500', '', '[scores]', ''];
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=5000`);
  lines.push('', '[stars]', '');
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=3`);
  return lines.join('\n') + '\n';
}
const REAL = saveText(149, 150);
const XLAB = saveText(120, 121);

const state = (page) => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(page, pred, what, ms = 120000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(page);
    if (s && pred(s)) return s;
    await sleep(120);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, card: s.card_open, title: s.title_open, tw: s.twins_prototype }));
}
const ls = (page, k) => page.evaluate((key) => localStorage.getItem(key), k);
const at = (s, c, r) => s.tw_blocks.find((b) => b.c === c && b.r === r);
async function tapCell(page, W, H, c, r) {
  const s = await state(page);
  const b = at(s, c, r);
  if (!b) throw new Error(`no block at ${c},${r}`);
  await page.touchscreen.tap(b.x * W, b.y * H);
  await sleep(250);
  return state(page);
}
async function solveAll(page, n) {
  await page.keyboard.press('F1');
  await sleep(200);
  await page.keyboard.press('s');
  const s = await waitFor(page, (x) => x.card_open && x.level === n, `level ${n} cleared`, 150000);
  await page.keyboard.press('F1');
  await sleep(900);
  return s;
}

const errors = [];
const consoleErrors = [];
for (const [W, H, label] of SIZES) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-twins-'));
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  try {
    await ctx.addInitScript(([real, xlab]) => {
      try {
        if (!localStorage.getItem('chain_escape_save')) localStorage.setItem('chain_escape_save', real);
        if (!localStorage.getItem('chain_escape_experiencelab_save')) localStorage.setItem('chain_escape_experiencelab_save', xlab);
      } catch (e) {}
    }, [REAL, XLAB]);
    const page = ctx.pages()[0] || await ctx.newPage();
    page.on('pageerror', (e) => errors.push(`${label}: ${e.message}`));
    page.on('console', (m) => { if (m.type() === 'error') consoleErrors.push(`${label}: ${m.text()}`); });
    // ===== A =====
    await page.goto(BASE + '?v=123456&twinsprototype=1');
    let s = await waitFor(page, (x) => x.twins_prototype && x.level === 1 && x.tw_blocks.length > 0, 'prototype level 1');
    await sleep(1500);
    s = await state(page);
    check(!s.title_open && s.level_name === 'Twin Lights' && s.level_count === 3 && s.bonds === 2 && s.hearts === 3 && !s.experience_lab,
      `A[${label}]: ?v=123456&twinsprototype=1 opens Twin Lights directly (3 levels, ${s.bonds} bonds, ${s.hearts} hearts)`);
    const xs = s.tw_blocks.map((b) => b.x), ys = s.tw_blocks.map((b) => b.y);
    check(Math.min(...xs) > 0.05 && Math.max(...xs) < 0.95 && Math.min(...ys) > 0.1 && Math.max(...ys) < 0.9, `C[${label}]: the 6x6 board fits the screen`);
    await page.screenshot({ path: path.join(shots, `web_${label}_p1_start.png`) });
    s = await tapCell(page, W, H, 4, 4);  // green leaves
    check(!at(s, 4, 4), `A[${label}]: green (4,4) escapes`);
    const before = s;
    s = await tapCell(page, W, H, 2, 4);  // blue right twin: own lane clear, partner's blocked
    check(s.hearts === 3 && s.tw_blocks.length === before.tw_blocks.length && s.undo_steps === before.undo_steps && s.chain === before.chain,
      `A[${label}]: partner-blocked twin tap is free (hearts ${s.hearts}, nothing moved)`);
    check(s.tw_message === TWIN_TEXT, `A[${label}]: the rule is explained ("${s.tw_message}")`);
    await sleep(80);
    await page.screenshot({ path: path.join(shots, `web_${label}_p1_wait.png`) });
    await sleep(3200);
    s = await tapCell(page, W, H, 1, 4);  // the other blue twin: its own lane (up) is blocked -> a heart
    check(s.hearts === 2 && s.tw_message !== TWIN_TEXT, `A[${label}]: own-blocked twin tap costs one heart; the explanation is not repeated`);
    s = await tapCell(page, W, H, 2, 4);
    check(s.hearts === 2 && s.tw_message !== TWIN_TEXT, `A[${label}]: a second free tap shows no repeated message`);
    s = await tapCell(page, W, H, 4, 2);  // yellow
    s = await tapCell(page, W, H, 1, 2);  // purple
    check(!at(s, 4, 2) && !at(s, 1, 2), `A[${label}]: yellow and purple escape`);
    const pre = s;
    await page.touchscreen.tap(at(s, 1, 4).x * W, at(s, 1, 4).y * H);
    await sleep(110);
    await page.screenshot({ path: path.join(shots, `web_${label}_p1_pair.png`) });
    await sleep(500);
    s = await state(page);
    check(!at(s, 1, 4) && !at(s, 2, 4) && s.tw_blocks.length === pre.tw_blocks.length - 2, `A[${label}]: the blue twins leave together`);
    check(s.chain === pre.chain + 1 && s.undo_steps === pre.undo_steps + 1 && s.bonds === 1 && s.hearts === 2,
      `A[${label}]: a pair = chain +1 (${pre.chain}->${s.chain}), one Undo step, one bond left`);
    s = await tapCell(page, W, H, 5, 0);  // green down
    s = await tapCell(page, W, H, 3, 0);  // red facing twins
    check(!at(s, 2, 0) && !at(s, 3, 0) && s.bonds === 0, `A[${label}]: the facing red twins pass through each other`);
    if (label !== 'iphone14') { await ctx.close(); continue; }
    // ===== B =====
    for (const [n, name] of [[2, 'Hold Fire'], [3, 'Turnabout']]) {
      await page.goto(BASE + `?twinsprototype=${n}`);
      s = await waitFor(page, (x) => x.twins_prototype && x.level === n && x.tw_blocks.length > 0, `prototype level ${n}`);
      await sleep(1500);
      s = await state(page);
      check(!s.title_open && s.level_name === name && s.bonds === 1 && s.highest_completed === n - 1, `B: ?twinsprototype=${n} opens ${name} directly (cleared ${s.highest_completed})`);
      await page.screenshot({ path: path.join(shots, `web_p${n}_start.png`) });
    }
    s = await solveAll(page, 3);
    await page.touchscreen.tap(s.next[0] * W, s.next[1] * H);
    s = await waitFor(page, (x) => x.twins_complete_open && x.twins_complete_button.length === 2, 'end screen', 20000);
    check(s.level === 3, 'B: after Level 3 the end-of-prototype screen opens (never Level 4)');
    await page.screenshot({ path: path.join(shots, 'web_prototype_end.png') });
    await page.touchscreen.tap(s.twins_complete_button[0] * W, s.twins_complete_button[1] * H);
    s = await waitFor(page, (x) => x.select_open, 'level select', 20000);
    check(s.select_max_unlocked <= 3 && s.select_locked_first === 0, `B: Level Select lists the 3 prototype levels only (max ${s.select_max_unlocked})`);
    // ===== D ===== (saves first: the normal game below writes its own save, as always)
    check(await ls(page, 'chain_escape_save') === REAL, 'D: the real save is byte-identical');
    check(await ls(page, 'chain_escape_experiencelab_save') === XLAB, 'D: the Experience Lab save is byte-identical');
    check((await ls(page, 'chain_escape_twinsprototype_save') || '').length > 0, 'D: the prototype used only its own save key');
    for (const q of ['?v=1&xtwinsprototype=1', '?twinsprototype=4']) {
      await page.goto(BASE + q);
      s = await waitFor(page, (x) => x.title_open, 'title ' + q);
      check(!s.twins_prototype && s.level === 150 && s.level_count === 300, `D: ${q} starts the normal game at Level 150 (300 levels)`);
    }

  } catch (e) {
    check(false, `${label}: ${e.message}`);
  }
  await ctx.close();
}
check(errors.length === 0, `no page errors (${errors.join(' | ')})`);
check(consoleErrors.length === 0, `no console errors (${consoleErrors.slice(0, 5).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
