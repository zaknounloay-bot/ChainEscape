// TIMING + PERSONAL BEST in the exported game, real Chromium at iPhone
// sizes, real touch taps (blocks found on the rendered screen).
//
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   godot --headless --path . --export-release "Web" build/web/index.html
//   SHOTS=<dir> node tools/web_timing_test.mjs build/web_friend build/web
//
// A: production (player) build, fresh save: Level 1 played by touch after
//    ~2.5 s of thinking - the recorded active time matches the wall clock
//    from the moment the board is playable to the winning tap; the card
//    shows "TIME 0:0x" (first time) and LEVEL SCORE / LEVEL BEST as before.
// B: REPLAY: a fresh attempt; the page STALLS 3 s (one 3 s frame - a page
//    resumed without a visibility event: at most 0.25 s counts), is HIDDEN
//    3 s (visibilitychange) and PUT AWAY 2 s (pagehide / pageshow): none of
//    it is counted; the card shows the time line. (Chromium's CDP lifecycle
//    freeze does not stop frames in this headless setup, so it is not used;
//    real suspension is an iPhone QA item.)
// C: the records are in the release save (chain_escape_save_r2: [times],
//    [clean_times]) and survive a reload and closing / reopening the
//    browser.
// D: the level card (with the time line) fits iPhone SE / 14 / Pro Max:
//    Level 1 first clear (coins line) in the production build and the
//    Level 100 milestone card (QA jump, dev build).
// F: the guided finger lesson (dev build, ?experiencelab=76): no clock
//    under the Magnet card or while the player follows the finger; the
//    clock starts when the lesson ends, and following it is not assistance.
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
const prodRoot = path.resolve(process.argv[2] || 'build/web_friend');
const devRoot = path.resolve(process.argv[3] || 'build/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const m = req.url.split('?')[0].match(/^\/(prod|dev)\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const file = path.join(m[1] === 'prod' ? prodRoot : devRoot, decodeURIComponent(m[2] || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8789, '127.0.0.1');
const PROD = 'http://127.0.0.1:8789/prod/index.html';
const DEV = 'http://127.0.0.1:8789/dev/index.html';

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];
let analyzer = null;
const SIZES = { iphone14: [390, 844], iphoneSE: [375, 667], promax: [430, 932] };

async function open(url, dir, size) {
  const [W, H] = SIZES[size];
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  // The page's own frame times: each frame longer than MAX_FRAME (0.25 s)
  // counts as 0.25 s by design. Headless SwiftShader stalls a frame for
  // ~0.3-0.45 s on every screenshot (used to find the blocks), so the
  // expected time subtracts that documented cap loss.
  await page.addInitScript(() => {
    window.__frames = [];
    const f = (t) => { window.__frames.push(t); requestAnimationFrame(f); };
    requestAnimationFrame(f);
  });
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
const perfNow = (g) => g.page.evaluate(() => performance.now());
// Wall time lost to the 0.25 s frame cap between two performance.now() marks.
const capLoss = (g, from, to) => g.page.evaluate(([from, to]) => {
  const a = window.__frames.filter((t) => t > from && t <= to);
  let loss = 0;
  for (let i = 1; i < a.length; i++) loss += Math.max(0, a[i] - a[i - 1] - 250);
  return Math.round(loss);
}, [from, to]);
const tapAt = (g, p) => g.page.touchscreen.tap(p[0] * g.W, p[1] * g.H);

// Level 1: three free blocks in the middle row, found on the screen.
async function blockCenters(g) {
  // Analysed in a separate browser: a second tab would hide the game page
  // (visibilitychange) and work in the game page would stall its frames -
  // either correctly takes time off its clock.
  const buf = await g.page.screenshot();
  const out = await analyzer.evaluate(async ([b64, y0, y1]) => {
    const img = await createImageBitmap(await (await fetch('data:image/png;base64,' + b64)).blob());
    const c = new OffscreenCanvas(img.width, img.height);
    const x2 = c.getContext('2d');
    x2.drawImage(img, 0, 0);
    const d = x2.getImageData(0, 0, img.width, img.height).data;
    const cols = new Array(img.width).fill(0);
    let ys = 0, yn = 0;
    for (let y = y0; y < y1; y++) {
      for (let x = 0; x < img.width; x++) {
        const i = (y * img.width + x) * 4;
        const mx = Math.max(d[i], d[i + 1], d[i + 2]), mn = Math.min(d[i], d[i + 1], d[i + 2]);
        if (mx > 150 && mx - mn > 110) { cols[x]++; ys += y; yn++; }
      }
    }
    const groups = [];
    let start = -1;
    for (let x = 0; x <= img.width; x++) {
      const on = x < img.width && cols[x] > 8;
      if (on && start < 0) start = x;
      if (!on && start >= 0) { if (x - start > 20) groups.push((start + x) / 2); start = -1; }
    }
    return { xs: groups, y: yn ? ys / yn : 0 };
  }, [buf.toString('base64'), Math.floor(g.H * 0.42), Math.floor(g.H * 0.66)]);
  return out.xs.map((x) => [x / g.W, out.y / g.H]);
}

// Clears Level 1 by touch; returns the page time (performance.now()) of
// the winning tap. The production build publishes `completed` only when
// the clear is presented (~0.5 s after the tap), so after each tap the
// state is watched for 2 s before looking for the next block.
async function clearLevel1(g) {
  let last = await perfNow(g);
  for (let i = 0; i < 8; i++) {
    if ((await state(g)).completed) break;
    const blocks = await blockCenters(g);
    if (blocks.length === 0) { await sleep(300); continue; }
    last = await perfNow(g);
    await tapAt(g, blocks[0]);
    const end = Date.now() + 2000;
    while (Date.now() < end && !(await state(g)).completed) await sleep(100);
  }
  return last;
}

const cardFits = (s) => s.card_rect && s.card_rect[0] >= 0 && s.card_rect[1] >= 0 && s.card_rect[2] <= 1 && s.card_rect[3] <= 1;
const TIME_RE = /^TIME \d+:\d\d(   ·   (BEST \d+:\d\d|NEW BEST TIME!))?$/;

try {
  const abrowser = await chromium.launch(LAUNCH);
  analyzer = await abrowser.newPage();
  // ===== A =====
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-timing-'));
  let g = await open(PROD, profile, 'iphone14');
  let s = await waitFor(g, (x) => x.title_open, 'title');
  check(s.player_build && s.continue_text === 'PLAY', `A: production build, fresh save (${s.continue_text})`);
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => !x.title_open && x.level === 1, 'level 1');
  const tStart = await perfNow(g);  // the board is playable once the title is gone
  await sleep(2500);
  const tWin = await clearLevel1(g);
  s = await waitFor(g, (x) => x.card_open && x.level === 1, 'card 1', 20000);
  const wall = Math.round(tWin - tStart);
  const lossA = await capLoss(g, tStart, tWin);
  const t1 = s.time_result.time_ms;
  // Never more than the wall clock; at least the wall clock less what the
  // 0.25 s cap takes off long frames (small slack for frame alignment).
  check(t1 <= wall + 150 && t1 >= wall - lossA - 300, `A: active time ${t1} ms within [wall clock ${wall} ms - ${lossA} ms beyond the 0.25 s frame cap, wall clock] (board playable -> winning tap)`);
  check(s.time_result.clean && s.best_time_ms === t1 && s.best_clean_ms === t1, `A: a clean first clear: BEST = BEST CLEAN = ${t1} ms`);
  check(s.card_time === `TIME 0:${String(Math.floor(t1 / 1000)).padStart(2, '0')}`, `A: the card shows "${s.card_time}" (the first time on this level)`);
  check(cardFits(s), `A: the card fits the screen (${s.card_rect.map((v) => v.toFixed(3)).join(', ')})`);
  await sleep(900);
  await g.page.screenshot({ path: path.join(shots, 'timing_iphone14_card_first.png') });
  // ===== B: replay with a stalled, a hidden and a put-away page =====
  await sleep(600);
  await tapAt(g, s.replay);
  s = await waitFor(g, (x) => x.level === 1 && !x.card_open && !x.completed, 'replay 1');
  check(s.attempt_ms < 400 && !s.attempt_assisted, `B: REPLAY starts a fresh attempt (${s.attempt_ms} ms)`);
  const rStart = await perfNow(g);
  await sleep(1000);
  // A 3 s stall of the page (one frame spanning 3 s - what a page resumed by
  // Safari without a visibility event looks like): at most MAX_FRAME counts.
  await g.page.evaluate(() => { const e = performance.now() + 3000; while (performance.now() < e) {} });
  await sleep(800);
  const setHidden = (h, type) => g.page.evaluate(([h, type]) => {
    Object.defineProperty(document, 'hidden', { configurable: true, get: () => h });
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => (h ? 'hidden' : 'visible') });
    if (type === 'visibilitychange') document.dispatchEvent(new Event(type));
    else window.dispatchEvent(new Event(type));
  }, [h, type]);
  await setHidden(true, 'visibilitychange');
  s = await waitFor(g, (x) => x.page_hidden, 'hidden', 5000);
  check(s.page_hidden, 'B: the game sees the hidden page (visibilitychange)');
  await sleep(3000);
  await setHidden(false, 'visibilitychange');
  await sleep(800);
  // pagehide (the page put away, e.g. bfcache) while document.hidden still
  // reads false, then pageshow.
  await setHidden(false, 'pagehide');
  s = await waitFor(g, (x) => x.page_hidden, 'pagehide', 5000);
  check(s.page_hidden, 'B: pagehide counts as hidden even while document.hidden is false');
  await sleep(2000);
  await setHidden(false, 'pageshow');
  s = await waitFor(g, (x) => !x.page_hidden, 'pageshow', 5000);
  await sleep(700);
  const rWin = await clearLevel1(g);
  s = await waitFor(g, (x) => x.card_open && x.level === 1, 'card replay', 20000);
  const rWall = Math.round(rWin - rStart);
  const lossB = await capLoss(g, rStart, rWin);  // includes the 3 s stall frame (all but 0.25 s of it)
  const rActive = rWall - 3000 - 2000 - lossB;  // hidden, pagehide, beyond the frame cap
  const t2 = s.time_result.time_ms;
  check(t2 < rWall - 7500, `B: the 3 s stall (≤ 0.25 s), hidden 3 s and pagehide 2 s are not counted (${t2} ms of ${rWall} ms on the wall clock)`);
  check(t2 <= rWall - 5000 + 150 && t2 >= rActive - 300, `B: active time ${t2} ms within [wall clock ${rWall} - hidden 3000 - pagehide 2000 - ${lossB} ms beyond the frame cap (incl. the stall) = ${rActive} ms, ${rWall - 5000} ms]`);
  check(TIME_RE.test(s.card_time), `B: the card time line "${s.card_time}"`);
  const best2 = Math.min(t1, t2);
  check(s.best_time_ms === best2 && s.best_clean_ms === best2, `B: BEST / BEST CLEAN = the faster of the two (${best2} ms)`);
  await sleep(900);
  await g.page.screenshot({ path: path.join(shots, 'timing_iphone14_card_replay.png') });
  // A third, quick attempt (no thinking time): a replay improves the record.
  await sleep(600);
  await tapAt(g, s.replay);
  s = await waitFor(g, (x) => x.level === 1 && !x.card_open && !x.completed, 'replay 2');
  await clearLevel1(g);
  s = await waitFor(g, (x) => x.card_open && x.level === 1, 'card replay 2', 20000);
  const t3 = s.time_result.time_ms;
  const best = Math.min(best2, t3);
  check(t3 < best2 && s.time_result.new_best_time && s.time_result.new_clean_time && s.best_time_ms === t3 && s.best_clean_ms === t3,
    `B: a faster clean replay improves BEST and BEST CLEAN (${best2} -> ${t3} ms)`);
  check(/^TIME \d+:\d\d   ·   NEW BEST TIME!$/.test(s.card_time) && cardFits(s), `B: the card shows "${s.card_time}" and fits`);
  await sleep(900);
  await g.page.screenshot({ path: path.join(shots, 'timing_iphone14_card_new_best.png') });
  // ===== C: persistence =====
  const save = await g.page.evaluate(() => localStorage.getItem('chain_escape_save_r2') || '');
  check(save.includes('[times]') && save.includes('[clean_times]') && save.includes(`1=${best}`), 'C: both records are in the release save (chain_escape_save_r2)');
  await g.page.reload();
  s = await waitFor(g, (x) => x.title_open, 'title after reload');
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => !x.title_open && x.level > 0, 'level after reload');
  check(s.level === 1 && s.best_time_ms === best && s.best_clean_ms === best, `C: after a reload Level 1 keeps BEST ${s.best_time_ms} / CLEAN ${s.best_clean_ms}`);
  await g.ctx.close();
  g = await open(PROD, profile, 'iphone14');
  s = await waitFor(g, (x) => x.title_open, 'title after reopening');
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => !x.title_open && x.level > 0, 'level after reopening');
  check(s.level === 1 && s.best_time_ms === best && s.best_clean_ms === best, `C: after closing and reopening the browser: BEST ${s.best_time_ms} / CLEAN ${s.best_clean_ms}`);
  await g.ctx.close();
  // ===== D: card fit =====
  for (const size of ['iphoneSE', 'promax']) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-timing-'));
    g = await open(PROD, dir, size);
    s = await waitFor(g, (x) => x.title_open, 'title ' + size);
    await tapAt(g, s.title_continue);
    s = await waitFor(g, (x) => !x.title_open && x.level === 1, 'level 1 ' + size);
    await sleep(1500);
    await clearLevel1(g);
    s = await waitFor(g, (x) => x.card_open && x.level === 1, 'card ' + size, 20000);
    await sleep(800);
    s = await state(g);
    check(cardFits(s) && TIME_RE.test(s.card_time), `D[${size}]: Level 1 card with "${s.card_time}" fits (${s.card_rect.map((v) => v.toFixed(3)).join(', ')})`);
    await g.page.screenshot({ path: path.join(shots, `timing_${size}_card_level1.png`) });
    await g.ctx.close();
  }
  for (const size of ['iphoneSE', 'iphone14']) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-timing-'));
    g = await open(DEV + '?experiencelab=100&qareset=1', dir, size);
    s = await waitFor(g, (x) => x.level === 100 && x.lab_qa && !x.title_open, 'QA 100 ' + size);
    await sleep(1500);
    await g.page.focus('canvas').catch(() => {});
    await g.page.keyboard.press('F1'); await sleep(250);
    await g.page.keyboard.press('s');
    s = await waitFor(g, (x) => x.card_open && x.level === 100, 'card 100 ' + size, 120000);
    await g.page.keyboard.press('F1');
    await sleep(900);
    s = await state(g);
    check(cardFits(s) && TIME_RE.test(s.card_time) && s.card_title === '100 LEVELS ESCAPED!' && !s.time_result.clean,
      `D[${size}]: the Level 100 milestone card with "${s.card_time}" fits (${s.card_rect.map((v) => v.toFixed(3)).join(', ')}; auto-solve = assisted)`);
    await g.page.screenshot({ path: path.join(shots, `timing_${size}_card_level100.png`) });
    await g.ctx.close();
  }
  // ===== F: guided finger lesson =====
  {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-timing-'));
    g = await open(DEV + '?experiencelab=76&qareset=1', dir, 'iphone14');
    s = await waitFor(g, (x) => x.level === 76 && x.lab_qa && !x.title_open, 'QA 76');
    s = await waitFor(g, (x) => !x.intro_open && x.lesson === 'magnet' && x.lesson_target.length === 2, 'magnet lesson', 20000);
    const a0 = s.attempt_ms;
    check(!s.attempt_active && a0 < 300, `F: the Magnet card and the finger lesson: the clock does not run (${a0} ms, active ${s.attempt_active})`);
    await sleep(3000);  // reading the lesson
    let taps = 0, lastTap = Date.now();
    for (; taps < 8; taps++) {
      s = await state(g);
      if (s.lesson !== 'magnet') break;
      lastTap = Date.now();
      await tapAt(g, s.lesson_target);
      await sleep(1200);  // following the finger
    }
    s = await waitFor(g, (x) => x.lesson === '', 'lesson ends', 8000);
    const tFree = lastTap;  // the lesson ends on its key move (the last guided tap)
    check(s.attempt_ms - a0 < 400 && s.attempt_active && !s.attempt_assisted,
      `F: ${taps} guided taps over ${taps * 1.2 + 3} s added ${s.attempt_ms - a0} ms; the lesson over, the clock runs; not assisted`);
    await sleep(2000);  // independent play
    await g.page.focus('canvas').catch(() => {});
    const tPanel = Date.now();
    await g.page.keyboard.press('F1'); await sleep(250);
    await g.page.keyboard.press('s');
    s = await waitFor(g, (x) => x.card_open && x.level === 76, 'card 76', 120000);
    await g.page.keyboard.press('F1');
    const t = s.time_result.time_ms;
    check(t <= tPanel - tFree + 300 && t >= 1500, `F: the recorded time is the independent play only (${t} ms of ${tPanel - tFree} ms since the lesson ended)`);
    await g.ctx.close();
  }
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(errors.length === 0, `E: no page errors (${errors.slice(0, 3).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB TIMING TEST PASSED' : 'WEB TIMING TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
