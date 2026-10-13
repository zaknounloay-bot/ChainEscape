// GAMEPLAY FEEDBACK POLISH (Phase 2A, QA / dev builds only) - real Chromium
// at iPhone sizes, touch input, no audio device (every signal checked here
// is visual, as on an iPhone with the ringer muted).
//
//   godot --headless --path . --export-release "Web QA" build/web_qa/index.html
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   SHOTS=<dir> node tools/web_feedback_test.mjs build/web_qa build/web_friend
//
// Q: the QA build (?experiencelab=N, its own QA save):
//    - Level 3 (no hearts): a blocked tap nudges and rings the real blocker,
//      no heart is shown;
//    - Level 6 (hearts): 3 -> 2 -> 1 -> 0, a heart rises from the tapped
//      block each time and the bar beats; lost hearts read as outlines;
//      out of hearts -> the unchanged retry with 3 hearts;
//    - Level 14: a locked tap - padlock response, the short rule, one heart;
//    - Level 7: a dead end - "tap Undo" (Undo pulses), then, with every
//      Undo used, "tap Restart";
//    - rapid repeated taps: one ring, one heart chip, everything at rest;
//    - light (L6) and dark (L41) Chapters on iPhone SE / 14 / Pro Max: the
//      lost heart, the heart chip and the HUD stay on screen, nothing
//      overlaps.
// A: assist buttons (QA): grey SHOW A MOVE / HAMMER open the Shop when
//    buying would help; nothing is bought without a tap; the Shop pauses
//    the clock and closing it resumes the same attempt; a bought hint is
//    used only on the next tap (then assisted); the Hammer limit and a
//    lost board never lead to the Shop.
// I: storage isolation: the release save (chain_escape_save_r2) and the old
//    save stay byte-identical; the QA build writes only its own key
//    (ExperienceLab.QA_MIRROR_KEY).
// P: the player (production) build: feedback polish OFF (unchanged).
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
  const file = path.join({ qa: qaRoot, prod: prodRoot }[m[1]], decodeURIComponent(m[2] || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8794, '127.0.0.1');
const QA = 'http://127.0.0.1:8794/qa/index.html';
const PROD = 'http://127.0.0.1:8794/prod/index.html';

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio'] };
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];
const SIZES = { iphoneSE: [375, 667], iphone14: [390, 844], promax: [430, 932] };
const R2 = 'chain_escape_save_r2', OLD = 'chain_escape_save', QAKEY = 'chain_escape_experiencelab_qa_save';
const SENTINEL_R2 = '[meta]\n\nversion=5\nseq=42\n\n[progress]\n\ncurrent_level=77\nhighest_completed=76\nhighest_unlocked=77\n\n[times]\n\n1=4321\n';
const SENTINEL_OLD = '[meta]\n\nversion=5\nseq=9\n\n[progress]\n\ncurrent_level=12\nhighest_completed=11\nhighest_unlocked=12\n';

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
    await sleep(60);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, title: s.title_open, fb: s.feedback }));
}
// The debug panel republishes the state (F1 twice) without touching the board.
async function sample(g) {
  await g.page.focus('canvas').catch(() => {});
  await g.page.keyboard.press('F1');
  const s = await waitFor(g, (x) => x.debug_open, 'debug panel', 5000);
  await g.page.keyboard.press('F1');
  await waitFor(g, (x) => !x.debug_open, 'debug panel closed', 5000);
  return s;
}
const fb = (s) => s.feedback || {};
const tapFrac = (g, x, y) => g.page.touchscreen.tap(x * g.W, y * g.H);
const blockOf = (s, pred) => (s.tw_blocks || []).find(pred);
// Taps a block and waits for the feedback record of that tap.
async function tapBlock(g, b) {
  const before = fb(await state(g)).seq || 0;
  await tapFrac(g, b.x, b.y);
  return waitFor(g, (x) => (fb(x).seq || 0) > before, `feedback after tapping #${b.id}`, 8000);
}
const inView = (r) => r[0] >= 0 && r[1] >= 0 && r[2] <= 1 && r[3] <= 1;
async function startQA(n, profile, size, seed) {
  const g = await open(QA + `?experiencelab=${n}&qareset=1`, profile, size, seed);
  await waitFor(g, (x) => x.level === n && x.lab_qa && !x.title_open && !x.intro_open, `QA ${n}`, 90000);
  await sleep(900);
  return g;
}

try {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-fb-'));
  const seed = [R2, SENTINEL_R2, OLD, SENTINEL_OLD];
  // ===== Q: Level 3, no hearts =====
  let g = await startQA(3, profile, 'iphoneSE', seed);
  let s = await state(g);
  check(s.feedback_polish && s.max_hearts === 0, `Q[SE] L3: QA build, feedback polish on, no hearts (max ${s.max_hearts})`);
  let b = blockOf(s, (x) => x.st === 'blocked' && x.partner < 0);
  s = await tapBlock(g, b);
  await sleep(90);
  await g.page.screenshot({ path: path.join(shots, 'fb_iphoneSE_L3_blocked.png') });
  check(fb(s).kind === 'blocked' && fb(s).ringed >= 0 && !fb(s).heart_chip && s.hearts === 0,
    `Q[SE] L3 blocked tap: blocker #${fb(s).ringed} ringed, no heart shown, hearts ${s.hearts}`);
  await g.ctx.close();

  // ===== Q: Level 6, hearts 3 -> 2 -> 1 -> 0 =====
  g = await startQA(6, profile, 'iphoneSE');
  s = await state(g);
  check(s.max_hearts === 3 && s.hearts === 3, 'Q[SE] L6 starts with 3 hearts');
  for (const want of [2, 1]) {
    b = blockOf(await state(g), (x) => x.st === 'blocked' && x.partner < 0);
    s = await tapBlock(g, b);
    await sleep(110);
    await g.page.screenshot({ path: path.join(shots, `fb_iphoneSE_L6_hearts${want}_moment.png`) });
    check(s.hearts === want && fb(s).heart_chip && fb(s).chip_active && fb(s).heart_anim && fb(s).ringed >= 0,
      `Q[SE] L6 -> ${want} heart(s): a heart rises from the tapped block, the bar beats, the blocker is ringed`);
    check(inView(fb(s).hearts_rect), `Q[SE] L6 (${want} left): the hearts bar is on screen (${fb(s).hearts_rect.map((v) => v.toFixed(3))})`);
    await sleep(900);
    s = await sample(g);
    check(!fb(s).chip_active && !fb(s).heart_anim && s.live_timer.overlaps.length === 0,
      `Q[SE] L6 (${want} left): at rest within 1 s, no HUD overlaps (${s.live_timer.overlaps.join(', ') || 'none'})`);
    await g.page.screenshot({ path: path.join(shots, `fb_iphoneSE_L6_hearts${want}_rest.png`) });
  }
  b = blockOf(await state(g), (x) => x.st === 'blocked' && x.partner < 0);
  const t0 = Date.now();
  s = await tapBlock(g, b);
  check(s.hearts === 0 && fb(s).heart_chip, 'Q[SE] L6: the last heart rises too');
  await sleep(150);
  await g.page.screenshot({ path: path.join(shots, 'fb_iphoneSE_L6_hearts0_moment.png') });
  s = await waitFor(g, (x) => x.hearts === 3 && x.level === 6, 'retry', 8000);
  const dt = Date.now() - t0;
  check(dt >= 1600 && dt <= 4000, `Q[SE] L6 out of hearts: the unchanged retry comes back with 3 hearts (${dt} ms)`);
  await g.ctx.close();

  // ===== Q: Level 14, locked =====
  g = await startQA(14, profile, 'iphoneSE');
  s = await state(g);
  b = blockOf(s, (x) => x.st === 'locked');
  if (!b) check(false, 'Q[SE] L14 has a locked block');
  else {
    const h = s.hearts;
    s = await tapBlock(g, b);
    await sleep(120);
    await g.page.screenshot({ path: path.join(shots, 'fb_iphoneSE_L14_locked.png') });
    check(fb(s).kind === 'locked' && fb(s).lock_pop && s.hearts === h - 1 && fb(s).heart_chip && fb(s).ringed === -1,
      `Q[SE] L14 locked tap: the padlock responds, one heart (${h} -> ${s.hearts}), no blocker ring`);
    await sleep(300);
    s = await sample(g);
    check(/^Locked - clear every [A-Z]+ block first$/.test(fb(s).tip), `Q[SE] L14: the short rule: "${fb(s).tip}"`);
  }
  await g.ctx.close();

  // ===== Q: Level 7, a dead end =====
  g = await startQA(7, profile, 'iphoneSE');
  const PATH = [0, 3, 4];  // tools/feedback_check.gd: "dead path L7"
  const playPath = async () => {
    for (const id of PATH) {
      const x = await state(g);
      const blk = blockOf(x, (k) => k.id === id);
      if (!blk || blk.st !== 'ok') return false;
      await tapFrac(g, blk.x, blk.y);
      await waitFor(g, (y) => !blockOf(y, (k) => k.id === id), `#${id} gone`, 6000);
      await sleep(350);
    }
    return true;
  };
  let ok = await playPath();
  s = await waitFor(g, (x) => fb(x).kind === 'no_moves', 'no moves', 6000).catch(() => state(g));
  await sleep(300);
  s = await sample(g);
  await g.page.screenshot({ path: path.join(shots, 'fb_iphoneSE_L7_nomoves_undo.png') });
  check(ok && fb(s).kind === 'no_moves' && fb(s).tip === 'No moves left - tap Undo' && fb(s).points_at === 'undo' && fb(s).undo_available,
    `Q[SE] L7 dead end with Undo left: "${fb(s).tip}"`);
  for (let k = 0; k < 3; k++) {
    s = await state(g);
    await tapFrac(g, s.undo_button[0], s.undo_button[1]);
    await waitFor(g, (x) => x.undos_used === k + 1, `undo ${k + 1}`, 6000);
    await sleep(500);
    const x = await state(g);
    const blk = blockOf(x, (q) => q.id === PATH[PATH.length - 1]);
    await tapFrac(g, blk.x, blk.y);
    await waitFor(g, (y) => !blockOf(y, (q) => q.id === PATH[PATH.length - 1]), 'last move again', 6000);
    await sleep(500);
  }
  s = await waitFor(g, (x) => fb(x).points_at === 'restart', 'restart pointer', 6000).catch(() => state(g));
  await sleep(200);
  await g.page.screenshot({ path: path.join(shots, 'fb_iphoneSE_L7_nomoves_restart.png') });
  check(s.undos_used === 3 && fb(s).tip === 'No moves left - tap Restart' && !fb(s).undo_available,
    `Q[SE] L7 dead end with every Undo used: "${fb(s).tip}" (never "tap Undo")`);
  await g.ctx.close();

  // ===== Q: rapid repeated taps =====
  g = await startQA(3, profile, 'iphoneSE');
  b = blockOf(await state(g), (x) => x.st === 'blocked' && x.partner < 0);
  for (let i = 0; i < 8; i++) { await tapFrac(g, b.x, b.y); await sleep(25); }
  s = await state(g);
  check(fb(s).rings_live <= 1, `Q[SE] 8 rapid blocked taps: at most one ring per blocker (${fb(s).rings_live})`);
  await sleep(1000);
  s = await sample(g);
  check(fb(s).rings_live === 0 && !fb(s).chip_active, 'Q[SE] ... and all effects are gone 1 s later');
  await g.ctx.close();
  g = await startQA(6, profile, 'iphoneSE');
  b = blockOf(await state(g), (x) => x.st === 'blocked' && x.partner < 0);
  await tapFrac(g, b.x, b.y); await sleep(40); await tapFrac(g, b.x, b.y);
  s = await waitFor(g, (x) => x.hearts === 1, 'two quick hearts', 6000);
  check(fb(s).chips_shown === 2, `Q[SE] two quick mistakes: two hearts lost, two chips in turn (${fb(s).chips_shown})`);
  await sleep(1000);
  s = await sample(g);
  check(!fb(s).heart_anim && !fb(s).chip_active && s.hearts === 1, 'Q[SE] ... the bar and chip come to rest (no stuck animation)');
  await g.page.screenshot({ path: path.join(shots, 'fb_iphoneSE_L6_rapid_rest.png') });
  await g.ctx.close();

  // ===== Q: light / dark Chapters on SE / 14 / Pro Max =====
  for (const [n, tone] of [[6, 'light'], [41, 'dark']]) {
    for (const size of ['iphoneSE', 'iphone14', 'promax']) {
      g = await startQA(n, profile, size);
      b = blockOf(await state(g), (x) => x.st === 'blocked' && x.partner < 0);
      s = await tapBlock(g, b);
      await sleep(110);
      await g.page.screenshot({ path: path.join(shots, `fb_${size}_L${n}_${tone}_moment.png`) });
      check(fb(s).heart_chip && inView(fb(s).hearts_rect) && b.x > 0 && b.x < 1 && b.y > 0 && b.y < 1,
        `Q[${size}] L${n} (${tone}): heart lost - chip at the tapped block, hearts bar on screen`);
      await sleep(900);
      s = await sample(g);
      check(s.hearts === 2 && s.live_timer.overlaps.length === 0 && !fb(s).heart_anim,
        `Q[${size}] L${n} (${tone}): 2 hearts + 1 outline at rest, no HUD overlaps`);
      await g.page.screenshot({ path: path.join(shots, `fb_${size}_L${n}_${tone}_rest.png`) });
      await g.ctx.close();
    }
  }

  // ===== A: assist buttons =====
  g = await startQA(14, profile, 'iphoneSE');
  s = await state(g);
  check(fb(s).hint_owned === 1 && s.coins === 60, `A: L14 (no free hints) starts with 1 SHOW A MOVE booster, ${s.coins} coins`);
  await tapFrac(g, s.hint_button[0], s.hint_button[1]);
  s = await waitFor(g, (x) => x.hint_block >= 0, 'booster hint', 8000);
  const hinted = blockOf(s, (x) => x.id === s.hint_block);
  await tapFrac(g, hinted.x, hinted.y);
  await waitFor(g, (x) => !blockOf(x, (k) => k.id === hinted.id), 'hinted block escaped', 8000);
  await sleep(500);
  s = await sample(g);
  const coinsA = s.coins;
  check(fb(s).hint_owned === 0 && s.attempt_assisted, 'A: the booster was used (assisted, as before); none left - SHOW A MOVE is grey');
  await tapFrac(g, s.hint_button[0], s.hint_button[1]);
  await sleep(600);
  s = await sample(g);
  await g.page.screenshot({ path: path.join(shots, 'fb_iphoneSE_L14_hint_shop.png') });
  check(fb(s).shop_open && s.hint_block === -1 && s.coins === coinsA && fb(s).hint_owned === 0,
    `A: grey SHOW A MOVE on a solvable board opens the SHOP; nothing bought (${s.coins} coins)`);
  const t1 = s.attempt_ms;
  await sleep(1200);
  s = await sample(g);
  check(!s.attempt_active && s.attempt_ms === t1, `A: SHOP open - the attempt's clock is paused (${t1} -> ${s.attempt_ms} ms)`);
  const buy = fb(s).shop_buttons.buy_hint;
  await tapFrac(g, buy[0], buy[1]);
  await sleep(500);
  s = await sample(g);
  check(s.coins === coinsA - 30 && fb(s).hint_owned === 1 && s.hint_block === -1, `A: buying by tap: ${coinsA} -> ${s.coins} coins, 1 booster, no hint shown`);
  const close = fb(s).shop_buttons.close;
  await tapFrac(g, close[0], close[1]);
  await sleep(1300);
  s = await sample(g);
  check(!fb(s).shop_open && s.attempt_ms > t1 && s.level === 14 && !s.completed && !s.title_open,  // (sampled with the debug panel up, which itself pauses)
    `A: SHOP closed - the same attempt goes on (${t1} -> ${s.attempt_ms} ms)`);
  await tapFrac(g, s.hint_button[0], s.hint_button[1]);
  s = await waitFor(g, (x) => x.hint_block >= 0, 'bought hint', 8000);
  check(fb(s).hint_owned === 0, 'A: the next SHOW A MOVE tap uses the bought booster');
  // HAMMER: none owned -> SHOP
  s = await state(g);
  await tapFrac(g, s.hammer_button[0], s.hammer_button[1]);
  await sleep(600);
  s = await sample(g);
  await g.page.screenshot({ path: path.join(shots, 'fb_iphoneSE_L14_hammer_shop.png') });
  check(fb(s).shop_open && !s.hammer_armed && fb(s).hammer_owned === 0, 'A: grey HAMMER (none owned) opens the SHOP; nothing bought, not armed');
  await tapFrac(g, fb(s).shop_buttons.close[0], fb(s).shop_buttons.close[1]);
  await sleep(500);
  await g.ctx.close();
  // A lost board with nothing left: the dead-end pointer, never the SHOP.
  g = await startQA(7, profile, 'iphoneSE');
  s = await state(g);
  await tapFrac(g, s.hint_button[0], s.hint_button[1]);  // spends the only booster (L7 has no free hints)
  s = await waitFor(g, (x) => x.hint_block >= 0, 'L7 booster hint', 8000);
  for (const id of [0, 3, 4]) {
    const x = await state(g);
    const blk = blockOf(x, (k) => k.id === id);
    await tapFrac(g, blk.x, blk.y);
    await waitFor(g, (y) => !blockOf(y, (k) => k.id === id), `#${id} gone`, 6000);
    await sleep(350);
  }
  s = await sample(g);
  check(fb(s).hint_owned === 0, 'A: L7 dead end reached with no SHOW A MOVE left');
  const seqA = fb(s).seq;
  await tapFrac(g, s.hint_button[0], s.hint_button[1]);
  await sleep(500);
  s = await sample(g);
  check(!fb(s).shop_open && fb(s).seq > seqA && /^No moves left - tap Undo$/.test(fb(s).tip), `A: SHOW A MOVE on a dead end: "${fb(s).tip}", no SHOP`);
  await g.ctx.close();

  // ===== I: storage isolation =====
  g = await open(QA + '?experiencelab=6', profile, 'iphoneSE');
  await waitFor(g, (x) => x.level > 0 && x.lab_qa && !x.title_open, 'QA again', 60000);
  const st = await g.page.evaluate(([a, b2, c]) => ({ r2: localStorage.getItem(a), old: localStorage.getItem(b2), qa: localStorage.getItem(c), keys: Object.keys(localStorage) }), [R2, OLD, QAKEY]);
  check(st.r2 === SENTINEL_R2, 'I: the release save (chain_escape_save_r2) is byte-identical after the QA sessions');
  check(st.old === SENTINEL_OLD, 'I: the old save (chain_escape_save) is byte-identical after the QA sessions');
  check(!!st.qa && st.qa.includes('[meta]'), `I: the QA build keeps its own save under ${QAKEY} (keys: ${st.keys.join(', ')})`);
  await g.ctx.close();

  // ===== P: the player build - unchanged =====
  g = await open(PROD, fs.mkdtempSync(path.join(os.tmpdir(), 'ce-fb-')), 'iphoneSE');
  s = await waitFor(g, (x) => x.title_open, 'prod title');
  check(s.player_build && s.feedback_polish === false && Object.keys(s.feedback || {}).length === 0,
    'P: the player (production) build keeps the released feedback (polish off)');
  await g.ctx.close();
} catch (e) {
  check(false, 'test run: ' + e.message);
}
check(errors.length === 0, `E: no page errors (${errors.length}${errors.length ? ': ' + errors.slice(0, 3).join(' | ') : ''})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
process.exit(failed ? 1 : 0);
