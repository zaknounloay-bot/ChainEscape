// MAGNET mechanic lab (prototype) - the "Web Magnet Lab" export, next to the
// "Web Friend Test" export on ONE browser origin, real Chromium at iPhone
// size, real touches:
//   godot --headless --path . --export-release "Web Magnet Lab" build/web_magnet/index.html
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   node tools/web_mechlab_magnet_test.mjs build/web_magnet build/web_friend [--shots=dir]
// A: the build always opens the MAGNET lab (3 boards) - with no parameter,
//    ?mechlab=1, ?experiencelab=50 or ?openinglab=1 alike; no debug panel.
// B: the demo plays: the red magnet's dotted line points at blue, its escape
//    PULLS blue (a pull counted), purple's magnet has nothing behind it.
// C: puzzle 1 (introduction) solved by real touches following SHOW A MOVE;
//    questions; puzzle 2: the magnet tapped first pulls (the preview was its
//    target), UNDO puts both back with the same preview; solved by touches.
// D: reload resumes; COPY RESULTS gives the Magnet results JSON (pulls).
// E: isolation: the owner's real save (Friend Test build, same origin; the
//    production release namespace, chain_escape_save_r2) and
//    every other non-lab copy are byte-identical afterwards; the Friend Test
//    build still continues at Level 26 and ignores ?mechlab=magnet.
// F: iPhone SE: the challenge board lays out; no page errors, no requests
//    leave the page.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const magRoot = path.resolve(process.argv[2] || 'build/web_magnet');
const friendRoot = path.resolve(process.argv[3] || 'build/web_friend');
const shots = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
const PORT = 8786;
let W = 390, H = 844;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const u = decodeURIComponent(req.url.split('?')[0].split('#')[0]);
  if (u === '/blank') { res.writeHead(200, { 'Content-Type': 'text/html' }); res.end('<html></html>'); return; }
  const m = u.match(/^\/(magnet|friend)\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const f = path.join(m[1] === 'magnet' ? magRoot : friendRoot, m[2] || 'index.html');
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(PORT, '127.0.0.1');
const ORIGIN = `http://127.0.0.1:${PORT}`;
const MAG = ORIGIN + '/magnet/index.html', FRIEND = ORIGIN + '/friend/index.html';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const LAUNCH = { args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const APP_NAME = fs.readFileSync(new URL('../project.godot', import.meta.url), 'utf8').match(/^config\/name="(.*)"$/m)[1];
const SAVE_DIR = `/userfs/godot/app_userdata/${APP_NAME}/`;
// The owner's real save: Level 26 reached, 777 coins.
const REAL = (() => {
  const l = ['[meta]', '', 'version=5', 'seq=40', '', '[progress]', '', 'current_level=26', 'highest_completed=25', 'last_completed_level=25', 'highest_unlocked=26', '', '[scores]', ''];
  for (let n = 1; n <= 25; n++) l.push(`${n}=5000`);
  l.push('', '[stars]', '');
  for (let n = 1; n <= 25; n++) l.push(`${n}=3`);
  l.push('', '[economy]', '', 'coins=777', '');
  return l.join('\n');
})();
const LAB_KEY = /magnetlab|mechlab_magnet|magnet_lab|\/shader_cache/;

const browser = await pw.chromium.launch(LAUNCH);
const errors = [];
const external = [];
try {
  const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: ORIGIN });
  await context.addInitScript((t) => { window.ceTestHooks = true; try { if (!localStorage.getItem('chain_escape_save_r2')) localStorage.setItem('chain_escape_save_r2', t); } catch (e) {} }, REAL);
  const page = await context.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('request', (r) => { if (!r.url().startsWith(ORIGIN + '/')) external.push(r.url()); });
  const cdp = await context.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const lab = get('chainEscapeMechLab'), play = get('chainEscapeSocialPlay'), game = get('chainEscapeState');
  const waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(150); }
    throw new Error('timeout ' + what + ' ' + JSON.stringify(v).slice(0, 300));
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  const tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(80); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  const shot = async (n) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, n + '.png') }); } };
  const tapLab = async (name, screen, after = 900) => {
    await waitFor(lab, (v) => v.screen === screen && v.buttons[name], name, 30000);
    await sleep(500);
    const v = await lab();
    await tap(v.buttons[name], after);
  };
  const snapshot = async () => {
    await page.goto(ORIGIN + '/blank');
    return page.evaluate(async ([dir, re]) => {
      const rx = new RegExp(re);
      const out = {};
      for (let i = 0; i < localStorage.length; i++) { const k = localStorage.key(i); if (!rx.test(k)) out['ls:' + k] = localStorage.getItem(k); }
      const db = await new Promise((r) => { const q = indexedDB.open('/userfs'); q.onsuccess = () => r(q.result); q.onerror = () => r(null); });
      if (db && db.objectStoreNames.contains('FILE_DATA')) {
        const store = db.transaction('FILE_DATA').objectStore('FILE_DATA');
        const keys = await new Promise((r) => { const q = store.getAllKeys(); q.onsuccess = () => r(q.result); });
        for (const k of keys) {
          if (!String(k).startsWith(dir) || rx.test(k)) continue;
          const v = await new Promise((r) => { const q = store.get(k); q.onsuccess = () => r(q.result); });
          out['idb:' + k] = v && v.contents ? Array.from(v.contents).join(',') : String(v && v.mode);
        }
        db.close();
      }
      return out;
    }, [SAVE_DIR, LAB_KEY.source]);
  };

  // ===== E (before): the owner's real save, written by the Friend Test build.
  await page.goto(FRIEND);
  let s = await waitFor(game, (x) => x.title_open, 'friend title', 120000);
  await tap(s.title_continue, 3500);
  const before = await snapshot();
  check(Object.keys(before).some((k) => k.endsWith('progress_r2.cfg')) && before['ls:chain_escape_save_r2'], `E: the owner's real save is stored (${Object.keys(before).length} copies)`);
  // ===== A =====
  for (const q of ['?mechlab=1', '?experiencelab=50', '?openinglab=1']) {
    await page.goto(MAG + q);
    const v = await waitFor(lab, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro ' + q, 120000);
    const st = await game();
    check(v.total === 3 && st && !st.experience_lab && !st.opening_lab && st.magnet_lab, `A: ${q} still opens the MAGNET lab (${v.total} boards)`);
  }
  await page.goto(MAG);
  let v = await waitFor(lab, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro', 120000);
  await sleep(800);
  check(v.total === 3 && v.index === 0, `A: no parameter: the MAGNET lab intro, ${v.total} boards`);
  await page.keyboard.press('F1');
  await sleep(600);
  check(!(await game()).debug_open, 'A: F1 opens no debug panel');
  await shot('G1_intro');
  // ===== B: demo =====
  await tapLab('Start', 'INTRO', 1500);
  v = await waitFor(lab, (v) => v.screen === 'DEMO', 'demo');
  let p = await waitFor(play, (p) => p.active && p.magnets && p.magnets.length === 2, 'demo board');
  const lines = p.magnets.map((l) => l[1]);
  check(lines.filter((t) => t >= 0).length === 1 && lines.includes(-1), `B: demo: one magnet shows a pull line, the other has nothing behind it (${JSON.stringify(p.magnets)})`);
  await shot('G2_demo_start');
  p = await waitFor(play, (p) => p.pulls >= 1, 'demo pull', 15000);
  await sleep(400);
  await shot('G3_demo_pulled');
  check(p.pulls === 1, 'B: the red magnet escapes and PULLS blue (1 pull)');
  v = await waitFor(lab, (v) => v.screen === 'DEMO' && v.buttons.DemoDone, 'demo done', 25000);
  p = await play();
  check(p.pulls === 1, `B: purple's magnet pulled nothing (still ${p.pulls} pull)`);
  await shot('G4_demo_end');
  // ===== C: puzzle 1 =====
  await tapLab('DemoDone', 'DEMO', 1800);
  p = await waitFor(play, (p) => p.active && p.next && p.next.length === 2 && p.magnets.length === 1, 'puzzle 1');
  check(p.buttons.Hint && !p.buttons.Hammer && p.buttons.Undo && p.buttons.Restart && p.magnets[0][1] >= 0, 'C: puzzle 1: magnet with its pull line; UNDO, SHOW A MOVE, RESTART, no HAMMER');
  await shot('G5_puzzle1');
  for (let i = 0; i < 40; i++) {
    const q = await waitFor(play, (q) => q.completed || (q.active && q.next && q.next.length === 2), 'next move');
    if (q.completed) break;
    await tap(q.next, 900);
  }
  v = await waitFor(lab, (v) => v.screen === 'QUESTION' && v.question === 'rating', 'rating', 15000);
  check(true, 'C: puzzle 1 solved by real touches');
  await tapLab('Answer_EASY', 'QUESTION', 900);
  await waitFor(lab, (v) => v.screen === 'QUESTION' && v.question === 'clarity', 'clarity', 5000);
  await shot('G6_clarity');
  await tapLab('Answer_CLEAR', 'QUESTION', 1800);
  v = await waitFor(lab, (v) => v.screen === 'PLAYING' && v.results === 1, 'puzzle 2');
  p = await waitFor(play, (p) => p.active && p.magnet_at && p.magnet_at.length === 1 && p.next && p.next.length === 2, 'puzzle 2 board');
  await sleep(800);
  p = await play();
  await shot('G7_puzzle2');
  const target = p.magnets[0][1], blocks0 = p.blocks;
  await tap(p.magnet_at[0], 1200);
  p = await play();
  check(p.pulls === 1 && p.blocks === blocks0 - 1 && p.magnets.length === 0, `C: the magnet escapes and pulls its previewed block (${p.pulls} pull, ${p.blocks} blocks)`);
  await shot('G8_puzzle2_pulled');
  await tap(p.buttons.Undo, 1200);
  p = await play();
  check(p.blocks === blocks0 && p.magnets.length === 1 && p.magnets[0][1] === target, 'C: UNDO puts the magnet and the pulled block back (same pull line)');
  for (let i = 0; i < 40; i++) {
    const q = await waitFor(play, (q) => q.completed || (q.active && q.next && q.next.length === 2), 'next move');
    if (q.completed) break;
    await tap(q.next, 900);
  }
  await waitFor(lab, (v) => v.screen === 'QUESTION' && v.question === 'rating', 'rating 2', 15000);
  check(true, 'C: puzzle 2 (magnet + spinner) solved by real touches after the undo');
  for (const a of ['Answer_MEDIUM']) await tapLab(a, 'QUESTION', 900);
  for (let i = 0; i < 6; i++) {
    const q = await lab();
    if (q.screen !== 'QUESTION') break;
    const first = Object.keys(q.buttons).find((k) => k.startsWith('Answer_'));
    await tap(q.buttons[first], 900);
  }
  v = await waitFor(lab, (v) => v.screen === 'PLAYING' && v.results === 2, 'puzzle 3');
  await sleep(1200);
  await shot('G9_puzzle3');
  // ===== D =====
  await page.reload();
  v = await waitFor(lab, (v) => v.screen === 'INTRO' && v.buttons.Start, 'intro again', 120000);
  check(v.index === 2 && v.results === 2, 'D: reload resumes at puzzle 3 with both results kept');
  await tapLab('Results', 'INTRO', 1200);
  await page.evaluate(() => navigator.clipboard.writeText(''));
  await tapLab('CopyResults', 'RESULTS', 1200);
  let parsed = null;
  try { parsed = JSON.parse(await page.evaluate(() => navigator.clipboard.readText())); } catch { /* not JSON */ }
  check(parsed && parsed.mechanic === 'magnet' && parsed.results.length === 2 && parsed.results[1].pulls >= 2 && parsed.results[0].clarity === 'CLEAR',
    'D: COPY RESULTS: the Magnet results JSON (pulls counted)');
  // ===== E (after) =====
  const after = await snapshot();
  const changed = Object.keys({ ...before, ...after }).filter((k) => before[k] !== after[k]);
  check(changed.length === 0, `E: every non-lab stored copy is byte-identical (${Object.keys(before).length} copies; changed: ${changed.join(', ') || 'none'})`);
  await page.goto(FRIEND + '?mechlab=magnet');
  s = await waitFor(game, (x) => x.title_open, 'friend title after', 120000);
  await sleep(1500);
  check(s.player_build && s.continue_text === 'CONTINUE  -  LEVEL 26' && s.coins === 777 && !(await lab()),
    `E: the Friend Test build continues the real save and ignores ?mechlab=magnet ('${s.continue_text}', ${s.coins} coins)`);
  await context.close();
  // ===== F =====
  W = 375; H = 667;
  const c2 = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await c2.addInitScript(() => { window.ceTestHooks = true; });
  const p2 = await c2.newPage();
  p2.on('pageerror', (e) => errors.push(e.message));
  await p2.goto(MAG);
  const lab2 = () => p2.evaluate(() => window.chainEscapeMechLab || null).catch(() => null);
  for (let i = 0; i < 400; i++) { const x = await lab2(); if (x && x.screen === 'INTRO') break; await sleep(250); }
  check(true, 'F: iPhone SE: the Magnet lab opens');
  if (shots) await p2.screenshot({ path: path.join(shots, 'G10_se_intro.png') });
  await c2.close();
  check(external.length === 0, 'F: no request left the page: ' + external.slice(0, 3).join(' '));
  check(errors.length === 0, 'F: no page errors ' + errors.slice(0, 3).join(' | '));
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close();
server.close();
const failed = results.filter((r) => !r).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
