// QA BUILD ("Web QA" export preset, custom feature qa_build) next to the
// FRIEND TEST build ("Web Friend Test", player_build) on ONE browser origin
// (shared localStorage + IndexedDB), real Chromium at iPhone sizes.
//
//   godot --headless --path . --export-release "Web QA" build/web_qa/index.html
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   SHOTS=<dir> node tools/web_qa_build_test.mjs build/web_qa build/web_friend
//
// A: the owner's real save (Level 26 reached, 777 coins; the production
//    release namespace) is in the shared storage; the Friend Test build
//    continues it.
// B: every checkpoint 50 ... 275: ?experiencelab=N opens Level N directly
//    in a fresh QA session (the first with &qareset=1, which is then removed
//    from the address; every later one is a new checkpoint without it): no
//    title, 1..N-1 cleared with no stars, starting coins; it clears (debug
//    auto-solve, QA build only), NEXT goes on to N+1 (200 -> 201 too);
//    a Safari-style RELOAD resumes at N+1 with N cleared.
// C: tab eviction: a new tab on the same URL resumes the session.
// D: &qareset=1 after progress restarts the checkpoint fresh.
// E: the QA build without parameters resumes the QA session (never the
//    real save); ?experiencelab=1 / reset / openinglab etc. stay in QA.
// F: isolation: the real save's every copy (file, .bak, .tmp, localStorage
//    mirror, beacon), the normal game's session diagnostics and page log are
//    byte-identical after all QA play; the Friend Test build still
//    continues at Level 26 with 777 coins and ignores
//    ?experiencelab=250&qareset=1 (no QA session, QA save untouched).
// G: audio unlocks on the first tap in a QA session (AudioContext running).
// H: iPhone SE / Pro Max: a QA checkpoint opens and lays out the board.
// I: no page errors, no console errors.
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
const friendRoot = path.resolve(process.argv[3] || 'build/web_friend');
const shots = process.env.SHOTS || os.tmpdir();
const CHECKPOINTS = (process.env.CHECKPOINTS || '50,75,100,125,150,175,200,225,250,275').split(',').map(Number);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  if (url === '/blank') { res.writeHead(200, { 'Content-Type': 'text/html' }); res.end('<html><body>blank</body></html>'); return; }
  const m = url.match(/^\/(qa|friend)\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const file = path.join(m[1] === 'qa' ? qaRoot : friendRoot, m[2] || 'index.html');
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8778, '127.0.0.1');
const ORIGIN = 'http://127.0.0.1:8778';
const QA = ORIGIN + '/qa/index.html';
const FRIEND = ORIGIN + '/friend/index.html';
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const state = (page) => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(page, pred, what, ms = 150000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(page);
    if (s && pred(s)) return s;
    await sleep(150);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, title: s.title_open, qa: s.lab_qa_level, card: s.card_open }));
}

// The owner's real save: Level 26 reached (1-25 cleared, 3 stars), 777 coins.
const REAL = (() => {
  const l = ['[meta]', '', 'version=5', 'seq=40', '', '[progress]', '', 'current_level=26', 'highest_completed=25', 'last_completed_level=25',
    'highest_unlocked=26', '', '[scores]', ''];
  for (let n = 1; n <= 25; n++) l.push(`${n}=5000`);
  l.push('', '[stars]', '');
  for (let n = 1; n <= 25; n++) l.push(`${n}=3`);
  l.push('', '[economy]', '', 'coins=777', '');
  return l.join('\n');
})();
// user:// = app_userdata/<config/name> (project.godot)
const APP_NAME = fs.readFileSync(new URL('../project.godot', import.meta.url), 'utf8').match(/^config\/name="(.*)"$/m)[1];
const SAVE_DIR = `/userfs/godot/app_userdata/${APP_NAME}/`;

// Every stored copy that is NOT the QA session's: IndexedDB files and
// localStorage keys (read from a blank same-origin page).
async function snapshotNonQa(page) {
  await page.goto(ORIGIN + '/blank');
  return page.evaluate(async (dir) => {
    const out = {};
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (!/experiencelab_qa|chain_escape_qa_/.test(k)) out['ls:' + k] = localStorage.getItem(k);
    }
    const db = await new Promise((r) => { const q = indexedDB.open('/userfs'); q.onsuccess = () => r(q.result); q.onerror = () => r(null); });
    if (db && db.objectStoreNames.contains('FILE_DATA')) {
      const store = db.transaction('FILE_DATA').objectStore('FILE_DATA');
      const keys = await new Promise((r) => { const q = store.getAllKeys(); q.onsuccess = () => r(q.result); });
      for (const k of keys) {
        // (shader_cache: the engine's GPU cache, shared by every build - not player data)
        if (!String(k).startsWith(dir) || /experience_lab_qa|chain_escape_qa_|\/shader_cache/.test(k)) continue;
        const v = await new Promise((r) => { const q = store.get(k); q.onsuccess = () => r(q.result); });
        out['idb:' + k] = v && v.contents ? Array.from(v.contents).join(',') : String(v && v.mode);
      }
      db.close();
    }
    return out;
  }, SAVE_DIR);
}
const qaKeys = (page) => page.evaluate(() => ({ save: localStorage.getItem('chain_escape_experiencelab_qa_save') || '', }));

async function solveAndNext(page, n) {
  await page.focus('canvas').catch(() => {});
  await page.keyboard.press('F1');
  await sleep(250);
  await page.keyboard.press('s');
  let s = await waitFor(page, (x) => x.card_open && x.level === n, `level ${n} cleared`);
  await page.keyboard.press('F1');
  await sleep(900);
  s = await state(page);
  await tap(page, s.next);
  await sleep(1200);
  s = await state(page);
  if (s.chapter_card_open) { await tap(page, s.chapter_continue); await sleep(1200); }
  return waitFor(page, (x) => x.level === n + 1 && !x.card_open && !x.chapter_card_open, `level ${n + 1}`);
}
let W = 390, H = 844;
const tap = (page, p) => page.touchscreen.tap(p[0] * W, p[1] * H);

const errors = [];
const watch = (page, label) => {
  page.on('pageerror', (e) => errors.push(`${label}: ${e.message}`));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(`${label} console: ${m.text()}`); });
};
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-qa-'));
const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
try {
  // The production (Friend Test) build saves under the release namespace
  // (PlayerProgress.RELEASE_*: progress_r2.cfg, chain_escape_save_r2).
  await ctx.addInitScript((t) => { try { if (!localStorage.getItem('chain_escape_save_r2')) localStorage.setItem('chain_escape_save_r2', t); } catch (e) {} }, REAL);
  let page = ctx.pages()[0] || await ctx.newPage();
  watch(page, 'iphone14');
  // ===== A =====
  await page.goto(FRIEND);
  let s = await waitFor(page, (x) => x.title_open, 'friend title');
  check(s.player_build && !s.qa_build && s.continue_text === 'CONTINUE  -  LEVEL 26' && s.coins === 777 && s.highest_completed === 25,
    `A: the Friend Test build continues the owner's save ('${s.continue_text}', ${s.coins} coins)`);
  await tap(page, s.title_continue);  // starting Level 26 writes every copy of the real save
  s = await waitFor(page, (x) => !x.title_open && x.level === 26, 'friend level 26');
  await sleep(3000);  // its IndexedDB sync lands
  const real0 = await snapshotNonQa(page);
  check(Object.keys(real0).some((k) => k.endsWith('progress_r2.cfg')) && real0['ls:chain_escape_save_r2'],
    `A: the real save is stored in IndexedDB and localStorage (${Object.keys(real0).filter((k) => /progress|chain_escape_save|beacon/.test(k)).join(', ')})`);
  // ===== B =====
  let audioChecked = false;
  for (const [i, n] of CHECKPOINTS.entries()) {
    const url = QA + '?v=123&experiencelab=' + n + (i === 0 ? '&qareset=1' : '');
    await page.goto(url);
    s = await waitFor(page, (x) => x.level === n && x.lab_qa && !x.title_open, `QA ${n}`);
    await sleep(800);
    s = await state(page);
    check(s.qa_build && !s.player_build && s.lab_qa_level === n && s.level_count === 300 && s.highest_completed === n - 1 && s.stars === 0
      && s.coins !== 777 && s.blocks_left > 0,
      `B[${n}]: ${i === 0 ? 'reset' : 'new checkpoint'} opens a fresh QA session at Level ${n} "${s.level_name}" (cleared 1-${s.highest_completed}, ${s.stars} stars, ${s.coins} coins)`);
    if (i === 0) {
      const href = page.url();
      check(!href.includes('qareset') && href.includes('experiencelab=' + n) && href.includes('v=123'), `B[${n}]: &qareset is removed from the address (${href.replace(ORIGIN, '')})`);
    }
    if (!audioChecked) {
      await tap(page, [0.5, 0.06]);
      await sleep(1500);
      const ac = await page.evaluate(() => window.ceAudio ? window.ceAudio.state() : 'no-bridge');
      check(ac === 'running', `G: audio unlocks on the first tap in a QA session (AudioContext ${ac})`);
      audioChecked = true;
    }
    if (n === CHECKPOINTS[0] || n === 200) await page.screenshot({ path: path.join(shots, `qa_${n}.png`) });
    s = await solveAndNext(page, n);
    check(s.level === n + 1 && s.highest_completed >= n && s.lab_qa_level === n,
      `B[${n}]: clears, NEXT goes on to Level ${n + 1} "${s.level_name}"${n === 200 ? ' (past the Grand Master into the Third Era)' : ''}`);
    if (n === 200) await page.screenshot({ path: path.join(shots, 'qa_201.png') });
    await sleep(1500);  // let the QA save's IndexedDB sync land (localStorage is immediate)
    await page.reload();
    s = await waitFor(page, (x) => x.lab_qa && !x.title_open && x.level > 0, `reload ${n}`);
    await sleep(600);
    s = await state(page);
    check(s.level === n + 1 && s.highest_completed >= n && s.lab_qa_level === n && s.save_source !== 'new',
      `B[${n}]: a reload RESUMES the session at Level ${s.level} (cleared to ${s.highest_completed}, source ${s.save_source})`);
  }
  const last = CHECKPOINTS[CHECKPOINTS.length - 1];
  // ===== C: tab eviction =====
  const resumeUrl = page.url();
  await page.close();
  page = await ctx.newPage();
  watch(page, 'iphone14-tab2');
  await page.goto(resumeUrl);
  s = await waitFor(page, (x) => x.lab_qa && !x.title_open && x.level > 0, 'new tab');
  check(s.level === last + 1 && s.lab_qa_level === last, `C: a new tab on the same URL resumes at Level ${s.level}`);
  // ===== D: explicit reset after progress =====
  await page.goto(QA + '?experiencelab=' + last + '&qareset=1');
  s = await waitFor(page, (x) => x.lab_qa && x.level > 0 && !x.title_open, 'reset');
  await sleep(600);
  s = await state(page);
  check(s.level === last && s.highest_completed === last - 1 && s.stars === 0, `D: &qareset=1 restarts Level ${last} fresh (level ${s.level}, cleared to ${s.highest_completed})`);
  check(!page.url().includes('qareset'), 'D: &qareset is removed from the address');
  await page.reload();
  s = await waitFor(page, (x) => x.lab_qa && x.level > 0 && !x.title_open, 'reload after reset');
  check(s.level === last && s.lab_qa_level === last, `D: a reload after the reset resumes it (level ${s.level})`);
  // ===== E =====
  for (const q of ['', '?experiencelab=1', '?experiencelab=reset', '?openinglab=1', '?twinsprototype=1', '?mechlab=1', '?friendbench=1', '?vhtest=1', '?sharetest=1']) {
    await page.goto(QA + q);
    s = await waitFor(page, (x) => (x.lab_qa && x.level > 0) || x.title_open, 'QA ' + q);
    await sleep(1000);
    s = await state(page);
    const overlay = await page.evaluate(() => !!document.getElementById('ce-sharetest'));
    check(s.lab_qa && s.lab_qa_level === last && s.level === last && !s.title_open && !s.opening_lab && !s.twins_prototype && !overlay,
      `E: QA build ${q || '(no parameters)'} stays in the QA session (Level ${s.level}, title ${s.title_open})`);
  }
  // ===== F =====
  const qaSave = (await qaKeys(page)).save;
  const real1 = await snapshotNonQa(page);
  const changed = Object.keys({ ...real0, ...real1 }).filter((k) => real0[k] !== real1[k]);
  check(changed.length === 0, `F: every non-QA stored copy is byte-identical after all QA play (${Object.keys(real0).length} copies; changed: ${changed.join(', ') || 'none'})`);
  await page.goto(FRIEND + '?v=1&experiencelab=250&qareset=1');
  s = await waitFor(page, (x) => x.title_open, 'friend title after QA');
  check(s.player_build && !s.lab_qa && !s.experience_lab && s.continue_text === 'CONTINUE  -  LEVEL 26' && s.coins === 777 && s.highest_completed === 25,
    `F: the Friend Test build ignores ?experiencelab=250&qareset=1 and continues the real save ('${s.continue_text}', ${s.coins} coins)`);
  await sleep(1500);
  const qaAfter = (await qaKeys(page)).save;
  check(qaSave !== '' && qaAfter === qaSave, 'F: the Friend Test build leaves the QA save untouched');
  await page.screenshot({ path: path.join(shots, 'qa_friend_after.png') });
} catch (e) {
  check(false, `iphone14: ${e.message}`);
}
await ctx.close();
// ===== H =====
for (const [w, h, label, n] of [[375, 667, 'iphoneSE', 250], [430, 932, 'promax', 125]]) {
  W = w; H = h;
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-qa-'));
  const c = await chromium.launchPersistentContext(d, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  try {
    const page = c.pages()[0] || await c.newPage();
    watch(page, label);
    await page.goto(QA + '?experiencelab=' + n);
    let s = await waitFor(page, (x) => x.level === n && x.lab_qa && !x.title_open, `${label} ${n}`);
    await sleep(1200);
    s = await state(page);
    check(s.blocks_left > 0 && s.next && s.level_label, `H[${label}]: QA Level ${n} "${s.level_name}" opens and lays out (${s.blocks_left} blocks)`);
    await page.screenshot({ path: path.join(shots, `qa_${label}_${n}.png`) });
  } catch (e) {
    check(false, `${label}: ${e.message}`);
  }
  await c.close();
}
// ===== I =====
check(errors.length === 0, `I: no page or console errors (${errors.slice(0, 4).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
