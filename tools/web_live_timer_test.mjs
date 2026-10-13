// LIVE TIMER HUD + LAYOUT C (QA / dev builds): coins under TOTAL SCORE,
// 44-unit hearts in the centre, TIME / MY BEST stacked on the right, no
// CHAIN xN popup - in real Chromium at iPhone sizes.
//
//   godot --headless --path . --export-release "Web QA" build/web_qa/index.html
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   godot --headless --path . --export-release "Web" build/web/index.html
//   SHOTS=<dir> node tools/web_live_timer_test.mjs build/web_qa build/web_friend build/web
//
// Q: the QA build (?experiencelab=N, its own QA save), iPhone SE first:
//    - sizes: captions TIME / MY BEST 27, values 34, hearts 44 (gap 15);
//    - no overlaps between any top-HUD elements (TOTAL SCORE, coins,
//      hearts, title, chapter line, progress, buttons, TIME / MY BEST) and
//      none of them over the board;
//    - TIME follows AttemptTimer; the result card hides the HUD; HUD TIME =
//      card TIME, MY BEST = the stored record; coins earned;
//    - hearts 3 -> 2 -> 1 after blocked taps, still centred, nothing overlaps;
//    - the coin pill (left) opens the SHOP;
//    - a long auto-solve streak: the chain grows, the CHAIN popup never shows;
//    - lesson (13) and NEW MECHANIC (76) levels: TIME stays 0:00;
//    - light / dark Chapters, long headings, the Master Level on SE / 14 /
//      Pro Max.
// T: the dev build with a save worth 1,350,000 points: TOTAL SCORE fits, the
//    coins sit under it, nothing overlaps.
// I: storage isolation: the release save (chain_escape_save_r2) and the old
//    save (chain_escape_save) stay byte-identical; the QA build writes only
//    chain_escape_experiencelab_qa_save.
// P: the player (production) build has the same approved layout C: live
//    TIME / MY BEST (AttemptTimer), 44-unit hearts, coins under TOTAL SCORE,
//    no overlaps, no CHAIN popup, release save namespace (r2).
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
const devRoot = path.resolve(process.argv[4] || 'build/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const m = req.url.split('?')[0].match(/^\/(qa|prod|dev)\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const file = path.join({ qa: qaRoot, prod: prodRoot, dev: devRoot }[m[1]], decodeURIComponent(m[2] || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8792, '127.0.0.1');
const QA = 'http://127.0.0.1:8792/qa/index.html';
const PROD = 'http://127.0.0.1:8792/prod/index.html';
const DEV = 'http://127.0.0.1:8792/dev/index.html';

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
// Layout C: nothing in the top HUD overlaps, and nothing reaches the board.
const layoutOk = (s) => lt(s).overlaps.length === 0
  && ['r_col', 'r_coins', 'r_total', 'r_hearts'].every((k) => lt(s)[k][3] <= s.board_panel[1])
  && lt(s).r_col[3] <= lt(s).board_area_top;  // above the board AREA: clear of the tallest possible board
const layoutDesc = (s) => `overlaps: ${lt(s).overlaps.join(', ') || 'none'}; TIME/MY BEST column ends ${lt(s).r_col[3].toFixed(3)}, board area ${lt(s).board_area_top.toFixed(3)}, board ${s.board_panel[1].toFixed(3)}`;
const coinsLeft = (s) => (lt(s).r_coins[0] + lt(s).r_coins[2]) / 2 < 0.5 && lt(s).r_coins[1] >= lt(s).r_total[3] - 0.001;
const tapFrac = (g, x, y) => g.page.touchscreen.tap(x * g.W, y * g.H);
function saveText(cleared, current, coins) {
  const lines = ['[meta]', '', 'version=5', 'seq=7', '', '[progress]', '', `current_level=${current}`, `highest_completed=${cleared}`,
    `highest_unlocked=${cleared + 1}`, '', '[economy]', '', `coins=${coins}`, '', '[chapters]', '', 'tips_seen=["intro_portal", "intro_magnet", "lesson_lock", "lesson_magnet", "lesson_switch", "lesson_gate", "lesson_armor", "lesson_twins"]', '', '[scores]', ''];
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=9000`);
  lines.push('', '[stars]', '');
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=3`);
  return lines.join('\n') + '\n';
}
const desc = (s) => `${lt(s).time_caption} ${lt(s).time} | ${lt(s).best_caption} ${lt(s).best}`;

try {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-live-'));
  const seed = [R2, SENTINEL_R2, OLD, SENTINEL_OLD];
  // ===== Q: Level 6 (hearts) on iPhone SE =====
  let g = await open(QA + '?experiencelab=6&qareset=1', profile, 'iphoneSE', seed);
  let s = await waitFor(g, (x) => x.level === 6 && x.lab_qa && !x.title_open && !x.intro_open, 'QA 6');
  check(lt(s).time_caption === 'TIME' && lt(s).best_caption === 'MY BEST' && lt(s).caption_size === 27 && lt(s).value_size === 34
    && lt(s).heart_size === 44 && lt(s).heart_gap === 15,
    `Q[SE] layout C sizes: captions "${lt(s).time_caption}" / "${lt(s).best_caption}" ${lt(s).caption_size}, values ${lt(s).value_size}, hearts ${lt(s).heart_size} (gap ${lt(s).heart_gap})`);
  check(s.qa_build && lt(s).visible && lt(s).time === '0:00' && lt(s).best === '\u2014' && s.max_hearts > 0,
    `Q[SE] L6 (hearts ${s.max_hearts}): the HUD at the start: ${desc(s)}`);
  if (process.env.DEBUG) console.log(JSON.stringify(lt(s)));
  const s6 = await sample(g);  // once laid out (the first state is published as the level starts)
  check(layoutOk(s6) && coinsLeft(s6), `Q[SE] L6: coins under TOTAL SCORE, nothing overlaps (${layoutDesc(s6)})`);
  const coins0 = s.coins;
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
  check(s.coins > coins0 && coinsLeft(s), `Q[SE] L6: the clear's coins arrive in the pill (coins ${coins0} -> ${s.coins}, pill under TOTAL SCORE)`);
  await g.page.screenshot({ path: path.join(shots, 'live_iphoneSE_level6_card.png') });
  const qaSave = await g.page.evaluate((k) => localStorage.getItem(k) || '', QAKEY);
  check(qaSave.includes('[times]') && qaSave.includes(`6=${s.best_time_ms}`), `I: the clear's record went to the QA save (${QAKEY}: [times] 6=${s.best_time_ms})`);
  await g.ctx.close();
  // ===== Q: hearts 3 -> 2 -> 1, the SHOP from the coin pill =====
  g = await open(QA + '?experiencelab=6&qareset=1', profile, 'iphoneSE');
  s = await waitFor(g, (x) => x.level === 6 && x.lab_qa && !x.title_open && !x.intro_open, 'QA 6 hearts');
  await sleep(800);
  for (const want of [2, 1]) {
    s = await state(g);
    const b = s.tw_blocks.find((x) => x.st === 'blocked');
    if (!b) break;
    await tapFrac(g, b.x, b.y);
    s = await waitFor(g, (x) => x.hearts === want, `hearts ${want}`, 8000);
    await sleep(900);
    s = await sample(g);
    check(s.hearts === want && layoutOk(s) && Math.abs((lt(s).r_hearts[0] + lt(s).r_hearts[2]) / 2 - 0.5) < 0.01,
      `Q[SE] L6 ${want} heart${want > 1 ? 's' : ''} left: centred, ${layoutDesc(s)}`);
    await g.page.screenshot({ path: path.join(shots, `live_iphoneSE_level6_hearts${want}.png`) });
  }
  s = await state(g);
  await tapFrac(g, (lt(s).r_coins[0] + lt(s).r_coins[2]) / 2, (lt(s).r_coins[1] + lt(s).r_coins[3]) / 2);
  await sleep(900);
  s = await sample(g);
  check(lt(s).shop_open, 'Q[SE] the coin pill (under TOTAL SCORE) opens the SHOP');
  await g.page.screenshot({ path: path.join(shots, 'live_iphoneSE_shop.png') });
  await g.ctx.close();
  // ===== Q: a long streak - the chain grows, no CHAIN popup =====
  g = await open(QA + '?experiencelab=100&qareset=1', profile, 'iphoneSE');
  s = await waitFor(g, (x) => x.level === 100 && x.lab_qa && !x.title_open && !x.intro_open, 'QA 100 streak', 60000);
  await sleep(1000);
  await g.page.focus('canvas').catch(() => {});
  await g.page.keyboard.press('F1'); await sleep(250);
  await g.page.keyboard.press('s');
  let maxChain = 0, popupSeen = false, shotTaken = false;
  const endT = Date.now() + 120000;
  while (Date.now() < endT) {
    const x = await state(g);
    if (x) {
      maxChain = Math.max(maxChain, x.chain || 0);
      popupSeen = popupSeen || x.live_timer.chain_visible;
      if (!shotTaken && x.chain >= 8) { await g.page.screenshot({ path: path.join(shots, 'live_iphoneSE_level100_streak.png') }); shotTaken = true; }
      if (x.card_open || x.completed) break;
    }
    await sleep(80);
  }
  await g.page.keyboard.press('F1');
  check(maxChain >= 10 && !popupSeen, `Q[SE] L100 auto-solve streak up to x${maxChain}: the CHAIN popup never shows`);
  await g.ctx.close();
  // ===== Q: Level 13, Lock finger lesson =====
  g = await open(QA + '?experiencelab=13&qareset=1', profile, 'iphoneSE');
  s = await waitFor(g, (x) => x.level === 13 && x.lab_qa && !x.title_open && x.lesson === 'lock', 'QA 13 lesson');
  await sleep(3000);
  s = await sample(g);
  check(s.lesson === 'lock' && lt(s).time === '0:00' && s.attempt_ms === 0 && layoutOk(s),
    `Q[SE] L13 Lock lesson running 3 s: ${desc(s)} (no clock during the lesson; ${layoutDesc(s)})`);
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
  for (const [n, size] of [[251, 'iphoneSE'], [251, 'iphone14'], [251, 'promax'], [100, 'iphoneSE'], [100, 'iphone14'], [100, 'promax'],
    [30, 'iphoneSE'], [30, 'iphone14'], [30, 'promax'], [255, 'iphoneSE'], [226, 'iphoneSE'], [6, 'iphone14'], [6, 'promax']]) {
    g = await open(QA + `?experiencelab=${n}&qareset=1`, profile, size);
    s = await waitFor(g, (x) => x.level === n && x.lab_qa && !x.title_open && !x.intro_open, `QA ${n}`, 60000);
    await sleep(1200);
    s = await sample(g);
    check(lt(s).visible && layoutOk(s) && coinsLeft(s) && !lt(s).chain_visible,
      `Q[${size}] L${n} "${s.level_name || ''}"${s.max_hearts > 0 ? ' (hearts)' : ''}${s.lesson ? ` (${s.lesson} lesson)` : ''}: ${desc(s)}, ${layoutDesc(s)}`);
    if (process.env.DEBUG) console.log(JSON.stringify(lt(s)));
    await g.page.screenshot({ path: path.join(shots, `live_${size}_level${n}.png`) });
    await g.ctx.close();
  }
  // ===== T: TOTAL SCORE 1,350,000 (dev build, a seeded save) =====
  for (const size of ['iphoneSE', 'promax']) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-live-'));
    g = await open(DEV, dir, size, ['chain_escape_save', saveText(150, 151, 4321), 'chain_escape_unused', 'x']);
    s = await waitFor(g, (x) => x.title_open, 'dev title');
    await tapFrac(g, s.title_continue[0], s.title_continue[1]);
    s = await waitFor(g, (x) => !x.title_open && x.level === 151 && !x.intro_open, 'dev 151', 60000);
    await sleep(1500);
    s = await sample(g);
    check(s.total_score >= 1000000 && layoutOk(s) && coinsLeft(s),
      `T[${size}] TOTAL SCORE ${s.total_score.toLocaleString('en-US')} fits; coins ${s.coins} under it; ${layoutDesc(s)}`);
    await g.page.screenshot({ path: path.join(shots, `live_${size}_score_1M.png`) });
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
  check(s.player_build && lt(s).visible && lt(s).qa_hud && lt(s).heart_size === 44 && lt(s).caption_size === 27 && lt(s).value_size === 34
    && lt(s).time_caption === 'TIME' && lt(s).best_caption === 'MY BEST' && coinsLeft(s) && !lt(s).chain_visible,
    `P: the player (production) build shows layout C: ${desc(s)}, hearts ${lt(s).heart_size}, coins under TOTAL SCORE, no CHAIN popup`);
  await sleep(2300);
  await g.page.touchscreen.tap(s.settings_button[0] * g.W, s.settings_button[1] * g.H);  // Settings: the clock pauses, the state is republished
  s = await waitFor(g, (x) => x.settings_open && x.attempt_ms > 0, 'prod settings', 8000);
  check(lt(s).time === fmt(s.attempt_ms) && s.attempt_ms >= 1500 && layoutOk(s),
    `P: production TIME ${lt(s).time} = AttemptTimer ${s.attempt_ms} ms; ${layoutDesc(s)}`);
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
