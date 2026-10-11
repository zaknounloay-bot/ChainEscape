// TIMING + PERSONAL BEST: upgrade and rollback against the RELEASED build,
// in real Chromium at iPhone size, real touch taps. Both builds are served
// from the SAME URL in the SAME browser profile (as when the files of the
// itch.io page are replaced), so they share the release save
// (chain_escape_save_r2).
//
//   node tools/web_timing_compat_test.mjs <released ZIP or dir> <new production ZIP or dir>
//
// U: the RELEASED build (no timing) with an existing release save
//    (Levels 1-150 cleared, 999 coins, boosters, Level 1 being replayed)
//    plays Level 1 by touch and writes the save itself: no [times].
// V: the files are replaced by the NEW build: the same progress (not
//    reset), Level 1 played by touch -> BEST / BEST CLEAN recorded; every
//    section the released build wrote is still there, unchanged apart from
//    what this clear itself updates (coins, Level 1 score).
// W: ROLLBACK - the files are replaced by the released build again: it
//    loads the save (same progress), plays Level 1 and saves - the
//    [times] / [clean_times] sections survive untouched.
// X: and forward again: the new build still shows the same records.
// Y: no page errors.
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
const [relArg, newArg] = process.argv.slice(2).map((p) => p && path.resolve(p));
if (!relArg || !newArg) { console.error('usage: node tools/web_timing_compat_test.mjs <released ZIP|dir> <new ZIP|dir>'); process.exit(2); }
const dirOf = (p) => {
  if (fs.statSync(p).isDirectory()) return p;
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-compat-zip-'));
  execSync(`unzip -q ${JSON.stringify(p)} -d ${JSON.stringify(d)}`);
  return d;
};
const REL = dirOf(relArg);
const NEW = dirOf(newArg);
let root = REL;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const file = path.join(root, p === '/game/' ? 'index.html' : decodeURIComponent(p.replace(/^\/game\//, '')));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(data);
  });
}).listen(8790, '127.0.0.1');
const URL = 'http://127.0.0.1:8790/game/index.html';
const KEY = 'chain_escape_save_r2';

const W = 390, H = 844;
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const VIEW = { viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true };
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];

// A release save (format 5): Levels 1-150 cleared, Level 1 being replayed.
function saveText() {
  const lines = ['[meta]', '', 'version=5', 'seq=7', '', '[progress]', '', 'current_level=1', 'highest_completed=150',
    'highest_unlocked=151', '', '[economy]', '', 'coins=999', 'inventory={"hint": 4, "hammer": 2}', '', '[chapters]', '',
    'tips_seen=["intro_portal"]', '', '[scores]', ''];
  for (let n = 1; n <= 150; n++) lines.push(`${n}=5000`);
  lines.push('', '[stars]', '');
  for (let n = 1; n <= 150; n++) lines.push(`${n}=3`);
  return lines.join('\n') + '\n';
}
// ConfigFile text -> { section: { key: value } }
function parse(text) {
  const out = {};
  let sec = null;
  for (const raw of (text || '').split('\n')) {
    const line = raw.trim();
    if (!line) continue;
    const m = line.match(/^\[(.+)\]$/);
    if (m) { sec = m[1]; out[sec] = out[sec] || {}; continue; }
    const i = line.indexOf('=');
    if (sec && i > 0) out[sec][line.slice(0, i)] = line.slice(i + 1);
  }
  return out;
}

async function open(dir, seed) {
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, ...VIEW });
  if (seed) await ctx.addInitScript(([k, t]) => { try { if (!localStorage.getItem(k)) localStorage.setItem(k, t); } catch (e) {} }, [KEY, seed]);
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
const save = (g) => g.page.evaluate((k) => localStorage.getItem(k), KEY);

// Level 1: three free blocks in the middle row, found on the rendered
// screen (analysed in a separate browser, so the game page stays visible).
let analyzer = null;
async function blockCenters(g) {
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
  }, [buf.toString('base64'), Math.floor(H * 0.42), Math.floor(H * 0.66)]);
  return out.xs.map((x) => [x / W, out.y / H]);
}
async function clearLevel1(g) {
  for (let i = 0; i < 10; i++) {
    if ((await state(g)).completed) return;
    const blocks = await blockCenters(g);
    if (blocks.length === 0) { await sleep(300); continue; }
    await tapAt(g, blocks[0]);
    const end = Date.now() + 2000;
    while (Date.now() < end && !(await state(g)).completed) await sleep(100);
  }
}
// From the title: CONTINUE (Level 1), clear it by touch, wait for the card
// and for the save to be written.
async function playLevel1(g, tag) {
  let s = await waitFor(g, (x) => x.title_open, 'title ' + tag);
  const cont = s.continue_text;
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => !x.title_open && x.level === 1, 'level 1 ' + tag);
  await sleep(1200);
  await clearLevel1(g);
  s = await waitFor(g, (x) => x.card_open && x.level === 1, 'card ' + tag, 20000);
  await sleep(1500);  // the card is shown after the save is written
  return { s, cont };
}
// Back on Level 1 for the next build: REPLAY (the save keeps
// current_level = 1).
async function replay(g) {
  const s = await state(g);
  // The released build does not publish REPLAY's position: left of NEXT,
  // on its row (as laid out on the card).
  await tapAt(g, s.replay || [0.27, s.next[1]]);
  await waitFor(g, (x) => x.level === 1 && !x.card_open && !x.completed, 'replay');
  await sleep(1200);
}

try {
  const abrowser = await chromium.launch(LAUNCH);
  analyzer = await abrowser.newPage();
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-compat-profile-'));
  // ===== U: the released build =====
  root = REL;
  let g = await open(profile, saveText());
  let { s, cont } = await playLevel1(g, 'released');
  check(cont === 'CONTINUE  -  LEVEL 1' && s.time_result === undefined, `U: the released build (no timing) continues the release save (${cont}) and clears Level 1`);
  await replay(g);
  const relText = await save(g);
  const rel = parse(relText);
  check(!!rel.progress && rel.progress.highest_completed === '150' && !rel.times && !rel.clean_times,
    `U: the released build wrote the save itself (highest_completed ${rel.progress && rel.progress.highest_completed}, no [times])`);
  await g.ctx.close();
  // ===== V: upgrade to the new build =====
  root = NEW;
  g = await open(profile);
  ({ s, cont } = await playLevel1(g, 'new'));
  check(cont === 'CONTINUE  -  LEVEL 1', `V: the new build keeps the progress - no reset (${cont})`);
  const t1 = s.time_result && s.time_result.time_ms;
  check(t1 > 0 && s.best_time_ms === t1 && s.best_clean_ms === t1, `V: Level 1 time recorded: BEST = BEST CLEAN = ${t1} ms`);
  check(/^TIME \d+:\d\d$/.test(s.card_time), `V: the card shows "${s.card_time}" (the first time on this level)`);
  await g.page.screenshot({ path: path.join(shots, 'compat_new_card.png') });
  await replay(g);
  const newText = await save(g);
  const nw = parse(newText);
  check(nw.times && nw.times['1'] === String(t1) && nw.clean_times && nw.clean_times['1'] === String(t1), `V: [times] 1=${nw.times && nw.times['1']}, [clean_times] 1=${nw.clean_times && nw.clean_times['1']} in ${KEY}`);
  // Everything the released build wrote is still there; only what this
  // clear itself updates may differ (coins earned, Level 1's score, the
  // save time and
  // sequence number).
  const changed = [];
  for (const sec of Object.keys(rel)) for (const k of Object.keys(rel[sec])) {
    const v = nw[sec] && nw[sec][k];
    if (v !== rel[sec][k]) changed.push(`${sec}.${k}`);
  }
  const allowed = new Set(['meta.seq', 'meta.saved_unix', 'economy.coins', 'scores.1']);
  const bad = changed.filter((k) => !allowed.has(k));
  check(bad.length === 0, `V: every value the released build wrote is unchanged (${changed.length} changed, all expected: ${changed.join(', ') || '-'}${bad.length ? '; UNEXPECTED ' + bad.join(', ') : ''})`);
  await g.ctx.close();
  // ===== W: rollback to the released build =====
  root = REL;
  g = await open(profile);
  ({ s, cont } = await playLevel1(g, 'rollback'));
  check(cont === 'CONTINUE  -  LEVEL 1', `W: rollback: the released build loads the save (${cont})`);
  await replay(g);
  const backText = await save(g);
  const back = parse(backText);
  check(back.times && back.times['1'] === String(t1) && back.clean_times && back.clean_times['1'] === String(t1),
    `W: after the released build played and saved, [times] / [clean_times] are intact (${back.times && back.times['1']} / ${back.clean_times && back.clean_times['1']})`);
  check(back.progress.highest_completed === '150' && back.scores['150'] === '5000' && back.stars['150'] === '3',
    'W: progress, scores and stars intact');
  await g.ctx.close();
  // ===== X: forward again =====
  root = NEW;
  g = await open(profile);
  s = await waitFor(g, (x) => x.title_open, 'title forward');
  await tapAt(g, s.title_continue);
  s = await waitFor(g, (x) => !x.title_open && x.level === 1, 'level 1 forward');
  check(s.best_time_ms === t1 && s.best_clean_ms === t1, `X: the new build again: BEST ${s.best_time_ms} / BEST CLEAN ${s.best_clean_ms}`);
  await g.ctx.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(errors.length === 0, `Y: no page errors (${errors.slice(0, 3).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB TIMING COMPAT TEST PASSED' : 'WEB TIMING COMPAT TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
