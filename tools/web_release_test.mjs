// PRODUCTION RELEASE: the one-time fresh start and normal persistence,
// tested on the exported ZIP FILES themselves, in real Chromium at iPhone
// size with real touch taps. Both builds are served from the SAME URL (as
// when the files of the itch.io page are replaced), in the SAME browser
// profile.
//
//   node tools/web_release_test.mjs <old Friend Test ZIP> <new production ZIP>
//
// A: the OLD public Friend Test build runs first and keeps a real save
//    (Level 151 reached).
// B: the files are replaced by the NEW production build: the same browser
//    starts FRESH - PLAY, Level 1, starting coins / boosters, 0 stars - and
//    the old save is left in the browser untouched (never read, never
//    deleted). The page script carries the release save key.
// C: progress made in the new build (Level 1 played by touch, the blocks
//    found on the rendered screen) is saved: CONTINUE - LEVEL 2 after a
//    reload, and after the browser is closed and opened again.
// D: a release save at Level 75 -> Level 76 opens the Magnet NEW MECHANIC
//    card, then the Magnet finger lesson.
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

const [oldZip, newZip] = process.argv.slice(2).map((p) => path.resolve(p));
if (!oldZip || !newZip) { console.error('usage: node tools/web_release_test.mjs <old.zip> <new.zip>'); process.exit(2); }
const unzip = (zip) => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-release-zip-'));
  execSync(`unzip -q ${JSON.stringify(zip)} -d ${JSON.stringify(d)}`);
  return d;
};
const OLD = unzip(oldZip);
const NEW = unzip(newZip);
let root = OLD;  // what the "itch.io page" serves right now
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const file = path.join(root, p === '/' || p === '/game/' ? 'index.html' : decodeURIComponent(p.replace(/^\/game\//, '')));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(data);
  });
}).listen(8781, '127.0.0.1');
const URL = 'http://127.0.0.1:8781/game/index.html';

const W = 390, H = 844;
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const VIEW = { viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true };
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];

function saveText(cleared, current, coins, mirrorTips = []) {
  const lines = ['[meta]', '', 'version=5', 'seq=7', '', '[progress]', '', `current_level=${current}`, `highest_completed=${cleared}`,
    `highest_unlocked=${cleared + 1}`, '', '[economy]', '', `coins=${coins}`, 'inventory={"hint": 4, "hammer": 2}', '', '[chapters]', '',
    `tips_seen=[${mirrorTips.map((t) => `"${t}"`).join(', ')}]`, '', '[scores]', ''];
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=5000`);
  lines.push('', '[stars]', '');
  for (let n = 1; n <= cleared; n++) lines.push(`${n}=3`);
  return lines.join('\n') + '\n';
}

async function open(dir, init) {
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, ...VIEW });
  if (init) await ctx.addInitScript(init[0], init[1]);
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(URL);
  return { ctx, page };
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
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, title: s.title_open, card: s.card_open }));
}
const tapAt = (g, p) => g.page.touchscreen.tap(p[0] * W, p[1] * H);
const ls = (g, key) => g.page.evaluate((k) => localStorage.getItem(k), key);

// Level 1 ("First Steps"): three free blocks in the middle row. Found on
// the rendered screen (strongly coloured pixels in the board band), tapped
// one at a time, as a player would.
async function blockCenters(g) {
  const buf = await g.page.screenshot();
  const an = await g.ctx.newPage();
  const out = await an.evaluate(async ([b64, y0, y1]) => {
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
  }, [buf.toString('base64'), Math.floor(H * 0.42), Math.floor(H * 0.66)]);
  await an.close();
  return out.xs.map((x) => [x / W, out.y / H]);
}

try {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-release-profile-'));
  // ===== A: the old public build, with a real save =====
  let g = await open(profile, [(t) => { try { if (!localStorage.getItem('chain_escape_save')) localStorage.setItem('chain_escape_save', t); } catch (e) {} }, saveText(150, 151, 999, ['intro_portal'])]);
  let s = await waitFor(g, (x) => x.title_open, 'old title');
  check(s.continue_text === 'CONTINUE  -  LEVEL 151' && s.highest_completed === 150, `A: the old Friend Test build: ${s.continue_text} (cleared ${s.highest_completed}, ${s.coins} coins)`);
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => !x.title_open && x.level === 151, 'old level 151');
  await sleep(1500);
  const oldSave = await ls(g, 'chain_escape_save');
  const oldBeacon = await ls(g, 'chain_escape_beacon');
  check(!!oldSave && oldSave.includes('highest_completed=150'), 'A: the old build keeps its save in the browser (chain_escape_save)');
  await g.ctx.close();

  // ===== B: the files are replaced by the production build =====
  root = NEW;
  const html = fs.readFileSync(path.join(NEW, 'index.html'), 'utf8');
  check(html.includes("var SAVE_KEY = 'chain_escape_save_r2';") && !html.includes("var SAVE_KEY = 'chain_escape_save';"),
    'B: the production page carries the release save key (embed -> own tab transfer)');
  g = await open(profile);
  s = await waitFor(g, (x) => x.title_open, 'new title');
  check(s.player_build && s.level_count === 300, `B: the production build (player build ${s.player_build}, ${s.level_count} levels)`);
  check(s.continue_text === 'PLAY' && s.highest_completed === 0 && s.highest_unlocked === 1 && s.level === 1,
    `B: an old Friend Test player starts FRESH: ${s.continue_text}, Level ${s.level}, cleared ${s.highest_completed}`);
  check(s.coins === 60 && s.stars === 0 && s.total_score === 0 && s.inventory.hint === 1 && s.inventory.hammer === 0,
    `B: starting coins / boosters / stars / score (${s.coins} coins, ${JSON.stringify(s.inventory)}, ${s.stars} stars, score ${s.total_score})`);
  check(s.save_source === 'new' && s.intros_seen.length === 0, `B: a new save (source ${s.save_source}), no mechanic intro marked seen`);
  check(await ls(g, 'chain_escape_save') === oldSave && await ls(g, 'chain_escape_beacon') === oldBeacon,
    'B: the old save is left in the browser untouched (not read, not deleted)');
  await g.page.screenshot({ path: path.join(shots, 'release_fresh_title.png') });

  // ===== C: progress in the new build persists =====
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => !x.title_open && x.level === 1, 'level 1');
  await sleep(2500);
  await g.page.screenshot({ path: path.join(shots, 'release_level1.png') });
  for (let i = 0; i < 6; i++) {
    s = await state(g);
    if (s.card_open || s.blocks_left === 0) break;
    const blocks = await blockCenters(g);
    if (blocks.length === 0) { await sleep(600); continue; }
    await tapAt(g, blocks[0]);
    await sleep(900);
  }
  s = await waitFor(g, (x) => x.card_open && x.level === 1, 'level 1 cleared', 20000);
  check(s.highest_completed === 1 && s.coins > 60 && s.stars > 0, `C: Level 1 cleared by touch (cleared ${s.highest_completed}, ${s.coins} coins, ${s.stars} stars)`);
  const coins1 = s.coins;
  await g.page.screenshot({ path: path.join(shots, 'release_level1_card.png') });
  await sleep(800);
  await tapAt(g, s.next);
  s = await waitFor(g, (x) => x.level === 2 && !x.card_open, 'level 2');
  await sleep(1000);
  const r2 = await ls(g, 'chain_escape_save_r2');
  check(!!r2 && r2.includes('highest_completed=1'), 'C: the progress is saved under the release key (chain_escape_save_r2)');
  check(await ls(g, 'chain_escape_save') === oldSave, 'C: the old save is still untouched');
  await g.page.reload();
  s = await waitFor(g, (x) => x.title_open, 'title after reload');
  check(s.continue_text === 'CONTINUE  -  LEVEL 2' && s.highest_completed === 1 && s.coins === coins1, `C: after a reload: ${s.continue_text} (${s.coins} coins, source ${s.save_source})`);
  await g.ctx.close();
  g = await open(profile);
  s = await waitFor(g, (x) => x.title_open, 'title after reopening');
  check(s.continue_text === 'CONTINUE  -  LEVEL 2' && s.highest_completed === 1 && s.coins === coins1 && s.stars > 0,
    `C: after closing and reopening the browser: ${s.continue_text} (${s.coins} coins, ${s.stars} stars, source ${s.save_source})`);
  await g.page.screenshot({ path: path.join(shots, 'release_reopened_title.png') });
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => !x.title_open && x.level === 2, 'continue to level 2');
  check(s.level === 2 && !s.card_open, 'C: CONTINUE goes on at Level 2');
  await g.ctx.close();

  // ===== D: the Magnet card and lesson at Level 76 in the production build =====
  const p2 = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-release-profile-'));
  g = await open(p2, [(t) => { try { if (!localStorage.getItem('chain_escape_save_r2')) localStorage.setItem('chain_escape_save_r2', t); } catch (e) {} },
    saveText(75, 76, 300, ['lesson_lock', 'lesson_switch', 'lesson_gate', 'lesson_armor', 'lesson_twins', 'intro_portal', 'lesson_portal', 'intro_sequence', 'lesson_sequence', 'intro_movable', 'lesson_movable'])]);
  s = await waitFor(g, (x) => x.title_open, 'title 76');
  check(s.continue_text === 'CONTINUE  -  LEVEL 76', `D: a release save at Level 75: ${s.continue_text}`);
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => x.intro_open, 'magnet card', 10000);
  check(s.level === 76 && s.intro_mechanic === 'magnet', `D: Level 76 opens the NEW MECHANIC card (${s.intro_mechanic})`);
  await sleep(600);
  await g.page.screenshot({ path: path.join(shots, 'release_76_card.png') });
  s = await waitFor(g, (x) => !x.intro_open && x.lesson === 'magnet' && x.lesson_target.length === 2, 'magnet lesson', 10000);
  check(true, 'D: then the Magnet finger lesson starts');
  await sleep(500);
  await g.page.screenshot({ path: path.join(shots, 'release_76_lesson.png') });
  await g.ctx.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(errors.length === 0, `E: no page errors (${errors.slice(0, 3).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB RELEASE TEST PASSED' : 'WEB RELEASE TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
