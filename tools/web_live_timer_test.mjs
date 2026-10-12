// LIVE TIMER HUD (QA builds): TIME under TOTAL SCORE, MY BEST under the coins,
// in real Chromium at iPhone sizes.
//
//   godot --headless --path . --export-release "Web QA" build/web_qa/index.html
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   SHOTS=<dir> node tools/web_live_timer_test.mjs build/web_qa build/web_friend
//
// Q: the QA build (?experiencelab=N, its own QA save):
//    - Level 6 (hearts) on iPhone SE: captions TIME / MY BEST (19 pt), TIME
//      0:00 / MY BEST dash at the start,
//      overlapping nothing; ~3 s later TIME = AttemptTimer as M:SS; after
//      the clear the HUD's TIME = the card's TIME and BEST = the record.
//    - Level 13 (Lock finger lesson): TIME stays 0:00 while the lesson runs.
//    - Level 76 (Magnet NEW MECHANIC card): TIME stays 0:00 under the card.
//    - Level 251 (hearts + Movable lesson) on iPhone 14, Level 100 on Pro
//      Max: overlapping nothing.
// I: storage isolation: a release save (chain_escape_save_r2) and an old
//    save (chain_escape_save) in the same browser stay byte-identical; the
//    QA build writes only chain_escape_experiencelab_qa_save.
// P: the player (production) build shows no live timer HUD.
// E: no page errors.
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
const qaRoot = path.resolve(process.argv[2] || 'build/web_qa');
const prodRoot = path.resolve(process.argv[3] || 'build/web_friend');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const m = req.url.split('?')[0].match(/^\/(qa|prod)\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const file = path.join(m[1] === 'qa' ? qaRoot : prodRoot, decodeURIComponent(m[2] || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8792, '127.0.0.1');
const QA = 'http://127.0.0.1:8792/qa/index.html';
const PROD = 'http://127.0.0.1:8792/prod/index.html';

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];
const SIZES = { iphoneSE: [375, 667], iphone14: [390, 844], promax: [430, 932] };
const R2 = 'chain_escape_save_r2', OLD = 'chain_escape_save', QAKEY = 'chain_escape_experiencelab_qa_save';
const SENTINEL_R2 = '[meta]\n\nversion=5\nseq=42\n\n[progress]\n\ncurrent_level=77\nhighest_completed=76\nhighest_unlocked=77\n\n[times]\n\n1=4321\n';
const SENTINEL_OLD = '[meta]\n\nversion=5\nseq=9\n\n[progress]\n\ncurrent_level=12\nhighest_completed=11\nhighest_unlocked=12\n';
const fmt = (ms) => { const s = Math.floor(Math.max(ms, 0) / 1000); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };

async function open(url, dir, size, seed) {
  const [W, H] = SIZES[size];
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  if (seed) await ctx.addInitScript(([a, b, c, d]) => { try { if (!localStorage.getItem(a)) localStorage.setItem(a, b); if (!localStorage.getItem(c)) localStorage.setItem(c, d); } catch (e) {} }, seed);
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(url);
  return { ctx, page, W, H };
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
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, title: s.title_open, card: s.card_open }));
}
// The debug panel (QA build) publishes the state; while it is open the clock
// is paused, so the published TIME is exactly the AttemptTimer value.
async function sample(g) {
  await g.page.focus('canvas').catch(() => {});
  await g.page.keyboard.press('F1');
  const s = await waitFor(g, (x) => x.debug_open, 'debug panel', 5000);
  await g.page.keyboard.press('F1');
  await waitFor(g, (x) => !x.debug_open, 'debug panel closed', 5000);
  return s;
}
const lt = (s) => s.live_timer;
const desc = (s) => `${lt(s).time_caption} ${lt(s).time} | ${lt(s).best_caption} ${lt(s).best}`;

try {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-live-'));
  const seed = [R2, SENTINEL_R2, OLD, SENTINEL_OLD];
  // ===== Q: Level 6 (hearts) on iPhone SE =====
  let g = await open(QA + '?experiencelab=6&qareset=1', profile, 'iphoneSE', seed);
  let s = await waitFor(g, (x) => x.level === 6 && x.lab_qa && !x.title_open && !x.intro_open, 'QA 6');
  check(lt(s).time_caption === 'TIME' && lt(s).best_caption === 'MY BEST' && lt(s).caption_size === 19 && lt(s).value_size === 26,
    `Q[SE] captions "${lt(s).time_caption}" / "${lt(s).best_caption}" at ${lt(s).caption_size} pt, values ${lt(s).value_size} pt`);
  check(s.qa_build && lt(s).visible && lt(s).time === '0:00' && lt(s).best === '—' && s.max_hearts > 0,
    `Q[SE] L6 (hearts ${s.max_hearts}): the HUD at the start: ${desc(s)}`);
  if (process.env.DEBUG) console.log(JSON.stringify(lt(s)));
  check(lt(s).overlaps.length === 0, `Q[SE] L6: TIME / MY BEST overlap nothing (${lt(s).overlaps.join(', ') || 'none'}; TIME ${lt(s).time_rect.map((v) => v.toFixed(3))}, BEST ${lt(s).best_rect.map((v) => v.toFixed(3))})`);
  await sleep(3300);
  s = await sample(g);
  check(lt(s).time === fmt(s.attempt_ms) && s.attempt_ms >= 2500 && s.attempt_ms <= 4500,
    `Q[SE] L6: ~3.3 s later TIME ${lt(s).time} = AttemptTimer ${s.attempt_ms} ms as M:SS`);
  await g.page.screenshot({ path: path.join(shots, 'live_iphoneSE_level6.png') });
  // the clear (auto-solve): HUD = card
  await g.page.keyboard.press('F1'); await sleep(250);
  await g.page.keyboard.press('s');
  s = await waitFor(g, (x) => x.card_open && x.level === 6, 'card 6', 120000);
  await g.page.keyboard.press('F1');
  await sleep(1500);
  s = await state(g);
  check(lt(s).time === s.time_panel.time && lt(s).best === fmt(s.best_time_ms) && s.best_time_ms === s.time_result.time_ms,
    `Q[SE] L6 cleared: HUD ${desc(s)} = card TIME ${s.time_panel.time}, stored BEST ${s.best_time_ms} ms`);
  check(!lt(s).visible && s.time_panel.visible, 'Q[SE] L6: the result card open, the live HUD steps aside');
  await g.page.screenshot({ path: path.join(shots, 'live_iphoneSE_level6_card.png') });
  const qaSave = await g.page.evaluate((k) => localStorage.getItem(k) || '', QAKEY);
  check(qaSave.includes('[times]') && qaSave.includes(`6=${s.best_time_ms}`), `I: the clear's record went to the QA save (${QAKEY}: [times] 6=${s.best_time_ms})`);
  await g.ctx.close();
  // ===== Q: Level 13, Lock finger lesson =====
  g = await open(QA + '?experiencelab=13&qareset=1', profile, 'iphoneSE');
  s = await waitFor(g, (x) => x.level === 13 && x.lab_qa && !x.title_open && x.lesson === 'lock', 'QA 13 lesson');
  await sleep(3000);
  s = await sample(g);
  check(s.lesson === 'lock' && lt(s).time === '0:00' && s.attempt_ms === 0 && lt(s).overlaps.length === 0,
    `Q[SE] L13 Lock lesson running 3 s: ${desc(s)} (no clock during the lesson; overlaps: ${lt(s).overlaps.join(', ') || 'none'})`);
  await g.page.screenshot({ path: path.join(shots, 'live_iphoneSE_level13_lesson.png') });
  await g.ctx.close();
  // ===== Q: Level 76, NEW MECHANIC card =====
  g = await open(QA + '?experiencelab=76&qareset=1', profile, 'iphoneSE');
  s = await waitFor(g, (x) => x.level === 76 && x.lab_qa && x.intro_open, 'QA 76 card', 30000);
  await sleep(600);
  await g.page.screenshot({ path: path.join(shots, 'live_iphoneSE_level76_card.png') });
  s = await state(g);
  check(s.intro_open && lt(s).time === '0:00', `Q[SE] L76 NEW MECHANIC card: ${desc(s)}`);
  await g.ctx.close();
  // ===== Q: Level 251 on iPhone 14, Level 100 on Pro Max =====
  for (const [n, size] of [[251, 'iphone14'], [100, 'promax'], [226, 'iphoneSE']]) {
    g = await open(QA + `?experiencelab=${n}&qareset=1`, profile, size);
    s = await waitFor(g, (x) => x.level === n && x.lab_qa && !x.title_open && !x.intro_open, `QA ${n}`, 60000);
    await sleep(1200);
    s = await sample(g);
    check(lt(s).visible && lt(s).overlaps.length === 0, `Q[${size}] L${n}${s.max_hearts > 0 ? ' (hearts)' : ''}${s.lesson ? ` (${s.lesson} lesson)` : ''}: ${desc(s)}, overlaps: ${lt(s).overlaps.join(', ') || 'none'}`);
    if (process.env.DEBUG) console.log(JSON.stringify(lt(s)));
    await g.page.screenshot({ path: path.join(shots, `live_${size}_level${n}.png`) });
    await g.ctx.close();
  }
  // ===== I: storage isolation =====
  g = await open(QA + '?experiencelab=6', profile, 'iphoneSE');
  s = await waitFor(g, (x) => x.level > 0 && x.lab_qa && !x.title_open, 'QA again', 60000);
  const st = await g.page.evaluate(([a, b, c]) => ({ r2: localStorage.getItem(a), old: localStorage.getItem(b), qa: localStorage.getItem(c) }), [R2, OLD, QAKEY]);
  check(st.r2 === SENTINEL_R2, 'I: the release save (chain_escape_save_r2) is byte-identical after the QA sessions');
  check(st.old === SENTINEL_OLD, 'I: the old save (chain_escape_save) is byte-identical after the QA sessions');
  check(!!st.qa && st.qa.includes('[meta]'), `I: the QA build keeps its own save under ${QAKEY}`);
  await g.ctx.close();
  // ===== P: the player build =====
  g = await open(PROD, fs.mkdtempSync(path.join(os.tmpdir(), 'ce-live-')), 'iphoneSE');
  s = await waitFor(g, (x) => x.title_open, 'prod title');
  await g.page.touchscreen.tap(s.title_continue[0] * g.W, s.title_continue[1] * g.H);
  s = await waitFor(g, (x) => !x.title_open && x.level === 1, 'prod level 1');
  await sleep(800);
  s = await state(g);
  check(s.player_build && !lt(s).visible, 'P: the player (production) build shows no live timer HUD');
  await g.page.screenshot({ path: path.join(shots, 'live_player_build_level1.png') });
  await g.ctx.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(errors.length === 0, `E: no page errors (${errors.slice(0, 3).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB LIVE TIMER TEST PASSED' : 'WEB LIVE TIMER TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
