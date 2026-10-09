// PLAYER EXPERIENCE LAB 1-200 (?experiencelab) in the exported game, real
// Chromium at iPhone size, real touch taps on title / NEXT / Chapter /
// lab-complete buttons; levels are cleared with the game's debug
// auto-solve (F1, then S).
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   SHOTS=<dir> node tools/web_experience_lab_test.mjs build/web
//
// A: itch.io-style URL index.html?v=123456&experiencelab=reset with a real
//    save (Level 150) and an Opening Lab save present: the lab starts as a
//    new player at Lab 1 with 200 levels; Lab 1-3 play in order.
// B: the plain URL index.html?experiencelab=reset works too; a look-alike
//    parameter (?v=1&xexperiencelab=1) does not start the lab.
// C: lab save standing on Lab 100: The Master clears, Chapter 10 card,
//    then NEXT goes on to Lab 101 (no end screen). Standing on Lab 200 (the
//    Grand Master, a temporary lab boundary): GRAND MASTER! card, Chapter 20
//    card, then the end-of-test-build screen (never Level 201); its button
//    opens Level Select. Spot checks:
//    Lab 13 / 16 / 20 / 31 / 41 / 51 names.
// F: QA jump ?v=123456&experiencelab=N (13 25 31 41 50 51 75 100 101 102 104
//    105 111 121 125 130 131 140 144 150 151 152 153 154 156 158 160 163 165
//    167 169 170 175 176 180 181 183 188 189 190 192 196 198 199 200) and
//    the plain
//    ?experiencelab=13: Lab N opens
//    directly (no title) in a temporary QA save; its lesson (13 lock, 101
//    switch, 121 production's Chain Gate lesson) / intro hint (125: none;
//    131: the lab's corrected hint; 151: production's Armor lesson)
//    shows; no milestone just by opening; clearing 25/50/75/100 shows the
//    milestone (100: card, Chapter 10, then Lab 101). The normal lab save
//    and log are unchanged and ?experiencelab=1 still continues the normal lab.
// G: natural progression from QA jumps: 110 -> 111, 120 -> 121 (the Gate
//    lesson starts), 121 -> 122, 129 -> 130, 130 -> 131, 139 -> 140,
//    149 -> 150 -> 151 (Armor lesson; the card says NEW: Armored Blocks),
//    151 -> 152, 159 -> 160 -> 161, 169 -> 170 -> 171, 174 -> 175 (real
//    taps on NEXT / Chapter), 175 -> 176, 179 -> 180, 189 -> 190,
//    199 -> 200.
// D: the real save and the Opening Lab save are byte-identical afterwards;
//    without the parameter the real save opens at Level 150. No page errors.
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
}).listen(8775, '127.0.0.1');
const BASE = 'http://127.0.0.1:8775/index.html';
const LAB = JSON.parse(fs.readFileSync(path.resolve('data/dev/experience_lab/manifest.json'), 'utf8')).levels;
const NAME = (n) => LAB[n - 1].name;
const LAST = LAB.length;
const TWINS = [176, 177, 179, 182, 184, 187, 190, 192, 194, 197];  // the lab's Twins levels  // 200: a temporary lab boundary

const W = 390, H = 844;
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const VIEW = { viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true };

function saveText(cleared, current, seq = 5) {
  const lines = ['[meta]', '', 'version=5', `seq=${seq}`, '', '[progress]', '', `current_level=${current}`, `highest_completed=${cleared}`,
    `highest_unlocked=${cleared + 1}`, '', '[economy]', '', 'coins=500', '', '[scores]', ''];
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=5000`);
  lines.push('', '[stars]', '');
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=3`);
  return lines.join('\n') + '\n';
}
const REAL = saveText(149, 150);
const OLAB = saveText(7, 8);

const state = (page) => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(page, pred, what, ms = 120000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(page);
    if (s && pred(s)) return s;
    await sleep(150);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, card: s.card_open, title: s.title_open, lab: s.experience_lab }));
}
const tapAt = (page, p) => page.touchscreen.tap(p[0] * W, p[1] * H);
const ls = (page, k) => page.evaluate((key) => localStorage.getItem(key), k);

async function solveAndNext(page, n) {
  await page.keyboard.press('F1');
  await sleep(200);
  await page.keyboard.press('s');
  let s = await waitFor(page, (x) => x.card_open && x.level === n, `level ${n} cleared`, 150000);
  await page.keyboard.press('F1');
  await sleep(900);
  s = await state(page);
  await tapAt(page, s.next);
  await sleep(900);
  return state(page);
}

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-xlab-'));
const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, ...VIEW });
const errors = [];
try {
  await ctx.addInitScript(([real, olab]) => {
    try {
      if (!localStorage.getItem('chain_escape_save')) localStorage.setItem('chain_escape_save', real);
      if (!localStorage.getItem('chain_escape_openinglab_save')) localStorage.setItem('chain_escape_openinglab_save', olab);
    } catch (e) {}
  }, [REAL, OLAB]);
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  // ===== A: itch.io-style URL =====
  await page.goto(BASE + '?v=123456&experiencelab=reset');
  let s = await waitFor(page, (x) => x.title_open, 'title');
  check(s.experience_lab && !s.opening_lab && s.level === 1 && s.level_name === NAME(1) && s.highest_completed === 0 && s.level_count === LAST,
    `A: ?v=123456&experiencelab=reset starts the lab as a new player (${s.level_name}, cleared ${s.highest_completed}, ${s.level_count} levels)`);
  await page.screenshot({ path: path.join(shots, 'xlab_title.png') });
  await tapAt(page, s.title_continue);
  s = await waitFor(page, (x) => !x.title_open, 'title closed');
  for (let n = 1; n <= 3; n++) {
    s = await waitFor(page, (x) => x.level === n && !x.card_open, `lab ${n}`);
    check(s.level_name === NAME(n), `A: Lab ${n} is "${s.level_name}"`);
    s = await solveAndNext(page, n);
  }
  s = await waitFor(page, (x) => x.level === 4 && !x.card_open, 'lab 4');
  check(s.level_name === NAME(4), `A: NEXT continues to Lab 4 "${s.level_name}"`);
  // ===== B: plain URL, look-alike =====
  await page.goto(BASE + '?experiencelab=reset');
  s = await waitFor(page, (x) => x.title_open, 'title (plain)');
  check(s.experience_lab && s.level === 1 && s.highest_completed === 0, 'B: index.html?experiencelab=reset starts the lab at Lab 1');
  // ===== C: spot checks and the end of the lab =====
  for (const n of [13, 16, 20, 31, 41, 51]) {
    // A newer copy than anything the lab wrote (the game keeps the highest seq).
    await page.evaluate((t) => localStorage.setItem('chain_escape_experiencelab_save', t), saveText(n - 1, n, 100000 + n));
    await page.goto(BASE + '?v=7&experiencelab=1');
    s = await waitFor(page, (x) => x.title_open, `title (lab ${n})`);
    check(s.experience_lab && s.level === n && s.level_name === NAME(n), `C: Lab ${n} is "${s.level_name}"`);
    if (n === 16 || n === 20) {
      await tapAt(page, s.title_continue);
      await waitFor(page, (x) => !x.title_open, 'closed');
      await sleep(1500);
      await page.screenshot({ path: path.join(shots, `xlab_L${n}.png`) });
    }
  }
  await page.evaluate((t) => localStorage.setItem('chain_escape_experiencelab_save', t), saveText(99, 100, 200000));
  await page.goto(BASE + '?v=123456&experiencelab=1');
  s = await waitFor(page, (x) => x.title_open, 'title (lab 100)');
  check(s.level === 100 && s.level_name === NAME(100), `C: Lab 100 is "${s.level_name}"`);
  await tapAt(page, s.title_continue);
  await waitFor(page, (x) => !x.title_open, 'closed');
  await sleep(1500);
  s = await solveAndNext(page, 100);
  check(!!s.chapter_card_open, 'C: the Chapter 10 card opens after Lab 100');
  if (s.chapter_card_open) { await tapAt(page, s.chapter_continue); await sleep(900); }
  s = await waitFor(page, (x) => x.level === 101 && !x.card_open, 'lab 101 after 100', 15000);
  check(s.level === 101 && !s.lab_complete_open && s.level_name === NAME(101), `C: after Lab 100 the lab goes on to Lab 101 "${s.level_name}" (no end screen)`);
  await page.evaluate((t) => localStorage.setItem('chain_escape_experiencelab_save', t), saveText(LAST - 1, LAST, 210000));
  await page.goto(BASE + '?v=123456&experiencelab=1');
  s = await waitFor(page, (x) => x.title_open, `title (lab ${LAST})`);
  await tapAt(page, s.title_continue);
  await waitFor(page, (x) => !x.title_open, 'closed');
  await sleep(1500);
  // The Grand Master: solve, check its card, then NEXT.
  await page.keyboard.press('F1'); await sleep(200);
  await page.keyboard.press('s');
  s = await waitFor(page, (x) => x.completed && x.level === LAST, `level ${LAST} completed`, 150000);
  await sleep(700);
  await page.screenshot({ path: path.join(shots, 'xlab_L200_celebration.png') });
  s = await waitFor(page, (x) => x.card_open && x.level === LAST, `level ${LAST} cleared`, 150000);
  await page.keyboard.press('F1');
  await sleep(1200);
  s = await state(page);
  await page.screenshot({ path: path.join(shots, 'xlab_L200_card.png') });
  check(s.card_title === 'GRAND MASTER!' && /GRAND MASTER/.test(s.coin_notes || ''), `C: Lab ${LAST} clears with the GRAND MASTER! card and its bonus ("${s.card_title}", "${s.coin_notes}")`);
  await tapAt(page, s.next);
  await sleep(900);
  s = await state(page);
  check(!!s.chapter_card_open, 'C: the Chapter 20 card follows the Grand Master');
  if (s.chapter_card_open) { await page.screenshot({ path: path.join(shots, 'xlab_card_after_200.png') }); await tapAt(page, s.chapter_continue); await sleep(900); }
  s = await waitFor(page, (x) => x.lab_complete_open, 'lab boundary screen', 15000);
  await sleep(900);
  s = await state(page);
  await page.screenshot({ path: path.join(shots, 'xlab_complete.png') });
  check(s.lab_complete_open && s.level === LAST && s.level_count === LAST, `C: after Lab ${LAST}: the end-of-test-build screen, still on Lab ${s.level} (never ${LAST + 1})`);
  const log = await page.evaluate(() => { try { return JSON.parse(localStorage.getItem('chain_escape_experiencelab_log') || '[]'); } catch (e) { return []; } });
  check(!log.some((e) => e.kind === 'start' && e.level > LAST) && log.some((e) => e.kind === 'lab_complete'), `C: no level after ${LAST} was ever started; the log records the boundary`);
  check(Array.isArray(s.lab_complete_button) && s.lab_complete_button.length === 2, 'C: the end-of-test-build screen has its LEVEL SELECT button');
  await tapAt(page, s.lab_complete_button);
  s = await waitFor(page, (x) => !x.lab_complete_open && x.select_open, 'level select after lab complete', 8000).catch(() => state(page));
  check(s && s.select_open && s.select_unlocked + (s.select_locked || 0) <= LAST, `C: LEVEL SELECT opens the lab's Level Select (${s && s.select_unlocked} open)`);
  // ===== E: Lab 13 lock lesson and the 25 / 50 / 75 / 100 milestones =====
  await page.evaluate((t) => localStorage.setItem('chain_escape_experiencelab_save', t), saveText(12, 13, 300000));
  await page.goto(BASE + '?v=123456&experiencelab=1');
  s = await waitFor(page, (x) => x.title_open, 'title (lab 13)');
  await tapAt(page, s.title_continue);
  s = await waitFor(page, (x) => !x.title_open && x.level === 13, 'lab 13');
  await sleep(1500);
  s = await state(page);
  check(s.lesson === 'lock', `E: Lab 13 opens the lock lesson (${s.lesson})`);
  await page.screenshot({ path: path.join(shots, 'xlab_L13_lesson_1.png') });
  check(Array.isArray(s.lesson_target) && s.lesson_target.length === 2, 'E: the lesson finger points at a block');
  await tapAt(page, s.lesson_target);   // a real touch on the guided (green) block
  await sleep(1100);
  s = await state(page);
  check(s.lesson === 'lock' && s.blocks_left === 4, `E: after the first green leaves the lesson continues - lock still closed (${s.lesson}, ${s.blocks_left} left)`);
  await page.screenshot({ path: path.join(shots, 'xlab_L13_lesson_2.png') });
  await tapAt(page, s.lesson_target);   // the last green
  await sleep(900);
  s = await state(page);
  check(s.lesson === '' && s.blocks_left === 3, `E: the last green leaves - the lock opens and the lesson ends (${s.blocks_left} left)`);
  await page.screenshot({ path: path.join(shots, 'xlab_L13_lesson_3.png') });
  for (const n of [25, 50, 75, 100]) {
    await page.evaluate(([t]) => localStorage.setItem('chain_escape_experiencelab_save', t), [saveText(n - 1, n, 400000 + n)]);
    await page.goto(BASE + '?v=123456&experiencelab=1');
    s = await waitFor(page, (x) => x.title_open, `title (lab ${n})`);
    await tapAt(page, s.title_continue);
    await waitFor(page, (x) => !x.title_open && x.level === n, `lab ${n}`);
    await sleep(1200);
    await page.keyboard.press('F1'); await sleep(200);
    await page.keyboard.press('s');
    s = await waitFor(page, (x) => x.major_rect && x.major_rect[2] > 0 && x.level === n, `milestone ${n}`, 150000);
    await page.keyboard.press('F1');
    await page.screenshot({ path: path.join(shots, `xlab_milestone_${n}.png`) });
    const r = s.major_rect;
    check(r[0] >= 0 && r[1] >= 0 && r[2] <= 1 && r[3] <= 1, `E: Lab ${n} "${n} / LEVELS ESCAPED!" fits the iPhone screen (${r.map((x) => x.toFixed(2)).join(', ')})`);
    check(r[3] < 0.85, `E: Lab ${n} overlay stays clear of the bottom controls (bottom ${r[3].toFixed(2)})`);
    s = await waitFor(page, (x) => x.card_open && x.level === n, `card ${n}`, 20000);
    await sleep(500);
    s = await state(page);
    const want = n === 100 ? 'MASTER CLEARED!' : `${n} LEVELS ESCAPED!`;
    check(s.card_title === want && s.celebration.startsWith('lab_'), `E: Lab ${n} card "${s.card_title}" (${s.celebration})`);
    check(!/FINAL|GRAND|GAME COMPLETE|THE END|HALFWAY/i.test(s.card_title), `E: Lab ${n} no finale wording`);
  }
  await page.evaluate(([t]) => localStorage.setItem('chain_escape_experiencelab_save', t), [saveText(23, 24, 500000)]);
  await page.goto(BASE + '?v=123456&experiencelab=1');
  s = await waitFor(page, (x) => x.title_open, 'title (lab 24)');
  await tapAt(page, s.title_continue);
  await waitFor(page, (x) => !x.title_open && x.level === 24, 'lab 24');
  await sleep(1000);
  await page.keyboard.press('F1'); await sleep(200);
  await page.keyboard.press('s');
  s = await waitFor(page, (x) => x.card_open && x.level === 24, 'card 24', 150000);
  check(!s.celebration && !(s.major_rect && s.major_rect[2] > 0), 'E: an ordinary level (24) shows no milestone');
  await page.keyboard.press('F1');
  // ===== F: QA jump ?experiencelab=N =====
  await page.goto(BASE + '?v=123456&experiencelab=1');
  const before = await waitFor(page, (x) => x.title_open, 'title (normal lab before QA)');
  const xlabSave = await ls(page, 'chain_escape_experiencelab_save');
  const xlabLog = await ls(page, 'chain_escape_experiencelab_log');
  const HINT = (n) => JSON.parse(fs.readFileSync(path.resolve(`data/dev/experience_lab/level_${String(n).padStart(2, '0')}.json`), 'utf8')).hint || '';
  for (const [n, q] of [[13, '?experiencelab=13'], [13, '?v=123456&experiencelab=13'], [25], [31], [41, '?v=123456&experiencelab=41'], [50], [51], [75], [100], [101], [102], [104], [105], [111], [121, '?v=123456&experiencelab=121'], [125, '?experiencelab=125'], [130], [131, '?experiencelab=131'], [140], [144], [150], [151, '?experiencelab=151'], [152], [153], [154], [156], [158], [160], [163], [165], [167], [169], [170], [175], [176, '?v=123456&experiencelab=176'], [177], [179], [180], [181], [182], [183], [184], [185], [186], [187], [188], [189], [190], [192], [194], [196], [197], [198], [199], [200, '?experiencelab=200']]) {
    const url = q || `?v=123456&experiencelab=${n}`;
    await page.goto(BASE + url);
    s = await waitFor(page, (x) => x.experience_lab && x.level === n, `QA ${url}`);
    await sleep(1500);
    s = await state(page);
    check(s.lab_qa_level === n && s.level_name === NAME(n) && !s.title_open && s.highest_completed === n - 1 && s.level_count === 300 && s.lab_qa,
      `F: ${url} opens Lab ${n} "${s.level_name}" directly (QA ${s.lab_qa_level}, title ${s.title_open}, cleared ${s.highest_completed})`);
    if (n === 13) check(s.lesson === 'lock' && /left\)/.test(s.tip_text), `F: ${url} the lock lesson from the start ("${s.tip_text}")`);
    else if (n === 101) check(s.lesson === 'switch' && /SWITCH/.test(s.tip_text), `F: ${url} production's Switch lesson ("${s.tip_text}")`);
    else if (n === 121) check(s.lesson === 'gate' && s.tip_text === 'GATE C opens when every block chained C escapes (1 left)', `F: ${url} production's Chain Gate lesson ("${s.tip_text}")`);
    else if (n === 125) check(s.lesson === '' && !s.tip_text, `F: ${url} Lab 125 starts as production: no lesson, no hint ("${s.tip_text}")`);
    else if (n === 151) check(s.lesson === 'armor' && /^Armored: can't escape/.test(s.tip_text) && s.lesson_target.length === 2, `F: ${url} production's Armor lesson with its finger ("${s.tip_text}")`);
    else if (n === 131) check(s.lesson === '' && s.tip_text === 'A switch turns the spinners beside it, too.', `F: ${url} Lab 131 shows the corrected hint, no lesson ("${s.tip_text}")`);
    else if (n === 176) check(s.lesson === 'twins' && /TWIN/.test(s.tip_text) && s.bonds === 2 && s.lesson_target.length === 2, `F: ${url} the Twins lesson with its finger on Twin Lights ("${s.tip_text}", ${s.bonds} bonds)`);
    else if (HINT(n)) check(s.tip_text === HINT(n), `F: ${url} Lab ${n} intro hint shows ("${s.tip_text}")`);
    check(!s.card_open && !(s.major_rect && s.major_rect[2] > 0), `F: ${url} no milestone just by opening`);
    if (q && n === 13) await page.screenshot({ path: path.join(shots, 'xlab_qa_L13.png') });
    if (n === 41 || n > 100) await page.screenshot({ path: path.join(shots, `xlab_qa_L${n}.png`) });
    if (n === 161) check(s.lesson === '' && !s.tip_text, `F: ${url} Lab 161 has no second Armor introduction ("${s.tip_text}")`);
    if (n >= 176 && n <= 199) check((s.bonds > 0) === TWINS.includes(n), `F: ${url} Lab ${n} ${TWINS.includes(n) ? 'draws its bonds' : 'has no Twins'} (${s.bonds})`);
    if (![25, 50, 75, 100].includes(n)) continue;
    await page.keyboard.press('F1'); await sleep(200);
    await page.keyboard.press('s');
    s = await waitFor(page, (x) => x.major_rect && x.major_rect[2] > 0 && x.level === n, `QA milestone ${n}`, 150000);
    await page.keyboard.press('F1');
    check(s.major_rect[1] >= 0 && s.major_rect[3] < 0.85, `F: Lab ${n} cleared - "${n} / LEVELS ESCAPED!" shows`);
    s = await waitFor(page, (x) => x.card_open && x.level === n, `QA card ${n}`, 20000);
    await sleep(500);
    s = await state(page);
    check(s.card_title === (n === 100 ? 'MASTER CLEARED!' : `${n} LEVELS ESCAPED!`), `F: Lab ${n} card "${s.card_title}"`);
    if (n === 100) {
      await tapAt(page, s.next);
      await sleep(900);
      s = await state(page);
      if (s.chapter_card_open) { await tapAt(page, s.chapter_continue); await sleep(900); }
      s = await waitFor(page, (x) => x.level === 101 && !x.card_open, 'QA lab 101 after 100', 15000);
      check(s.level === 101 && !s.lab_complete_open, 'F: after Lab 100 (QA): Chapter 10, then on to Lab 101');
    }
  }
  // ===== G: natural progression 110 -> 111, 120 -> 121, 121 -> 122, 129 -> 130 =====
  for (const n of [110, 120, 121, 129, 130, 139, 149, 150, 151, 159, 160, 169, 170, 174, 175, 176, 177, 179, 180, 184, 185, 186, 187, 190, 192, 194, 197, 198, 199]) {
    await page.goto(BASE + `?v=123456&experiencelab=${n}`);
    s = await waitFor(page, (x) => x.experience_lab && x.level === n, `QA ${n} (progression)`);
    await sleep(1200);
    await page.keyboard.press('F1'); await sleep(200);
    await page.keyboard.press('s');
    s = await waitFor(page, (x) => x.card_open && x.level === n, `card ${n}`, 150000);
    await page.keyboard.press('F1');
    await sleep(500);
    s = await state(page);
    await tapAt(page, s.next);
    await sleep(900);
    s = await state(page);
    if (s.chapter_card_open) {
      // (The card's "NEW:" text is checked headless in ExperienceLabCheck;
      // the screenshots show it on the device-size page.)
      if (n === 150 || n === 160) await page.screenshot({ path: path.join(shots, `xlab_card_after_${n}.png`) });
      await tapAt(page, s.chapter_continue); await sleep(900);
    }
    s = await waitFor(page, (x) => x.level === n + 1 && !x.card_open, `lab ${n + 1} after ${n}`, 15000);
    await sleep(1200);
    s = await state(page);
    check(s.level === n + 1 && s.level_name === NAME(n + 1) && !s.lab_complete_open, `G: after Lab ${n}: NEXT goes on to Lab ${n + 1} "${s.level_name}"`);
    if (n === 150) check(s.lesson === 'armor' && s.lesson_target.length === 2, `G: Lab 151 reached by play opens production's Armor lesson (lesson "${s.lesson}")`);
    if (n === 160) check(s.lesson === '', 'G: Lab 161 reached by play has no Armor lesson');
    if (n === 120) {
      // (The lesson text itself is checked on the QA jump above; reached by
      // play, the state is published before the hint fades in.)
      check(s.lesson === 'gate' && s.lesson_target.length === 2, `G: Lab 121 reached by play opens production's Chain Gate lesson (lesson "${s.lesson}", finger ${s.lesson_target})`);
      await page.screenshot({ path: path.join(shots, 'xlab_L121_lesson.png') });
    }
  }
  check(await ls(page, 'chain_escape_experiencelab_save') === xlabSave, 'F: the normal lab save is byte-identical after the QA jumps');
  check(await ls(page, 'chain_escape_experiencelab_log') === xlabLog, 'F: the lab log is unchanged by the QA jumps');
  await page.goto(BASE + '?v=123456&experiencelab=1');
  s = await waitFor(page, (x) => x.title_open, 'title (normal lab after QA)');
  check(s.experience_lab && !s.lab_qa_level && s.level === before.level && s.highest_completed === before.highest_completed,
    `F: ?experiencelab=1 still continues the normal lab (Lab ${s.level}, cleared ${s.highest_completed})`);
  await page.goto(BASE + '?v=123456&experiencelab=reset');
  s = await waitFor(page, (x) => x.title_open, 'title (reset after QA)');
  check(s.experience_lab && !s.lab_qa_level && s.level === 1 && s.highest_completed === 0, 'F: ?experiencelab=reset still starts the lab at Lab 1');
  // ===== D: isolation (before the real game is ever opened) =====
  check(await ls(page, 'chain_escape_save') === REAL, 'D: the real save is byte-identical after all lab sessions');
  check(await ls(page, 'chain_escape_openinglab_save') === OLAB, 'D: the Opening Lab save is byte-identical');
  await page.goto(BASE + '?v=1&xexperiencelab=1');
  s = await waitFor(page, (x) => x.title_open, 'title (look-alike)');
  check(!s.experience_lab && s.level === 150, `B: a look-alike parameter opens the real game (level ${s.level})`);
  await page.goto(BASE + '?v=123456');
  s = await waitFor(page, (x) => x.title_open, 'title (real)');
  check(!s.experience_lab && s.level === 150 && s.highest_completed === 149 && s.level_count === 300, `D: without the parameter the real game opens at Level ${s.level} (300 levels)`);
  check(errors.length === 0, `D: no page errors (${errors.join(' | ')})`);
} catch (e) {
  check(false, 'exception: ' + e.message);
} finally {
  await ctx.close();
  fs.rmSync(dir, { recursive: true, force: true });
  server.close();
}
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed ? 'WEB EXPERIENCE LAB TEST FAILED' : 'WEB EXPERIENCE LAB TEST PASSED');
process.exit(failed ? 1 : 0);
