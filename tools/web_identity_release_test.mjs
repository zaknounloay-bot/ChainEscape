// PLAYER IDENTITY RELEASE (Phase 3A -> Production): the CURRENT production
// ZIP and the CANDIDATE production ZIP served from the SAME URL in the SAME
// browser profile (as when the itch.io files are replaced), iPhone SE size:
//
//   SHOTS=<dir> node tools/web_identity_release_test.mjs <current production ZIP|dir> <candidate ZIP|dir> <QA build ZIP|dir>
//
// A: the current build continues a release save (r2) with progress,
//    stars, scores, coins, both boosters and Personal Bests.
// B: candidate: the same save continues unchanged; a [profile] with a valid
//    id is added to the SAME key (no new storage key); a reload keeps the
//    same id (made exactly once).
// N: candidate Settings: above the whole HUD; the optional name row; the
//    native field (focused, 18 px, near the top); "NAME: <name>" with
//    English + Hebrew + 2 emoji; a 3rd emoji, another emoji and 21
//    characters are refused / held.
// C: rollback to the current build: progress unchanged; the current build
//    rewrites the save (Settings MUSIC toggle) and keeps [profile] as it is.
// F: forward to the candidate again: the same id and name, progress intact.
// Q: the QA build on the same origin: its own player, the release save
//    byte-identical.
// W: no request leaves the page's origin (no Supabase, no network).
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
const unpack = (p) => {
  const abs = path.resolve(p);
  if (fs.statSync(abs).isDirectory()) return abs;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-idr-'));
  execSync(`unzip -q "${abs}" -d "${dir}"`);
  return dir;
};
const [curArg, newArg, qaArg] = process.argv.slice(2);
if (!curArg || !newArg || !qaArg) { console.error('usage: node tools/web_identity_release_test.mjs <current> <candidate> <qa>'); process.exit(2); }
const builds = { cur: unpack(curArg), new: unpack(newArg), qa: unpack(qaArg) };
let serving = 'cur';
const PORT = 8794;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const m = req.url.split('?')[0].match(/^\/(site|qa)\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const root = m[1] === 'qa' ? builds.qa : builds[serving];
  const file = path.join(root, decodeURIComponent(m[2] || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(data);
  });
}).listen(PORT, '127.0.0.1');
const ORIGIN = `http://127.0.0.1:${PORT}`;
const URL = `${ORIGIN}/site/index.html`;
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];
const offsite = [];
const W = 375, H = 667;
const R2 = 'chain_escape_save_r2', QAKEY = 'chain_escape_experiencelab_qa_save';
const SEED = ['[meta]', '', 'version=5', 'seq=11', '', '[progress]', '', 'current_level=14', 'highest_completed=13', 'highest_unlocked=14', '',
  '[economy]', '', 'coins=200', 'inventory={"hammer": 1, "hint": 2}', '', '[chapters]', '',
  'tips_seen=["intro_portal", "intro_magnet", "lesson_lock", "lesson_magnet", "lesson_switch", "lesson_gate", "lesson_armor", "lesson_twins"]', '',
  '[scores]', '', ...Array.from({ length: 13 }, (_, i) => `${i + 1}=${9000 + i}`), '', '[stars]', '', ...Array.from({ length: 13 }, (_, i) => `${i + 1}=${i % 3 + 1}`), '',
  '[times]', '', '3=12345', '7=23456', '14=50000', '', '[clean_times]', '', '3=12345', '14=50000', ''].join('\n');
const profileDir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-idr-prof-'));
const section = (text, name) => { const m = new RegExp(`\\[${name}\\]\\n([\\s\\S]*?)(?=\\n\\[|$)`).exec(text || ''); return m ? m[1].trim() : null; };
const profId = (text) => (/id="([^"]*)"/.exec(section(text, 'profile') || '') || [])[1] || '';
const seqOf = (t) => Number((/seq=(\d+)/.exec(t || '') || [0, 0])[1]);

async function open(url, seed) {
  const ctx = await chromium.launchPersistentContext(profileDir, { headless: true, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio'],
    viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  if (seed) await ctx.addInitScript(([k, v]) => { try { if (!localStorage.getItem(k)) localStorage.setItem(k, v); } catch (e) {} }, [R2, seed]);
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('request', (r) => { if (!r.url().startsWith(ORIGIN) && !r.url().startsWith('data:') && !r.url().startsWith('blob:')) offsite.push(r.url()); });
  await page.goto(url);
  return { ctx, page };
}
const state = (g) => g.page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(g, pred, what, ms = 90000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(g);
    if (s && pred(s)) return s;
    await sleep(100);
  }
  throw new Error('timeout: ' + what);
}
const tap = (g, x, y) => g.page.touchscreen.tap(x * W, y * H);
const store = (g) => g.page.evaluate(() => Object.fromEntries(Object.keys(localStorage).map((k) => [k, localStorage.getItem(k)])));
async function play(seed) {
  const g = await open(URL, seed);
  let s = await waitFor(g, (x) => x.title_open, 'title');
  await tap(g, s.title_continue[0], s.title_continue[1]);
  s = await waitFor(g, (x) => !x.title_open && x.level > 0, 'level');
  await sleep(1200);
  return g;
}
const progressOf = (s) => ({ level: s.level, done: s.highest_completed, coins: s.coins, hint: s.inventory.hint, hammer: s.inventory.hammer, best: s.best_time_ms, clean: s.best_clean_ms });
const sameProgress = (s) => { const p = progressOf(s); return p.level === 14 && p.done === 13 && p.coins === 200 && p.hint === 2 && p.hammer === 1 && p.best === 50000 && p.clean === 50000; };
const prof = (s) => s.profile || {};
const row = (s) => prof(s).row || {};
async function openSettings(g) {
  const s = await state(g);
  await tap(g, s.settings_button[0], s.settings_button[1]);
  await waitFor(g, (x) => x.settings_open, 'settings', 8000);
  await sleep(400);
  return state(g);
}
async function enterName(g, text) {
  let s = await state(g);
  const r = row(s).rect;
  await tap(g, (r[0] + r[2]) / 2, (r[1] + r[3]) / 2);
  await g.page.waitForSelector('#ce-name-text', { timeout: 5000 });
  const facts = await g.page.evaluate(() => {
    const i = document.getElementById('ce-name-text');
    return { focused: document.activeElement === i, top: i.getBoundingClientRect().top, fontPx: parseFloat(getComputedStyle(i).fontSize), title: document.querySelector('#ce-name > div > div').textContent };
  });
  await g.page.fill('#ce-name-text', text);
  facts.count = await g.page.textContent('#ce-name-count');
  facts.saveDisabled = await g.page.$eval('#ce-name-done', (b) => b.disabled);
  await sleep(450);
  await g.page.click(facts.saveDisabled ? '#ce-name-cancel' : '#ce-name-done');
  await g.page.waitForSelector('#ce-name', { state: 'detached', timeout: 5000 });
  await sleep(700);
  return { facts, s: await state(g) };
}

try {
  // ===== A: current production =====
  serving = 'cur';
  let g = await play(SEED);
  let s = await state(g);
  const a = await store(g);
  check(s.player_build && sameProgress(s) && s.total_score > 0, `A: the CURRENT build continues the release save (${JSON.stringify(progressOf(s))}, total ${s.total_score}, stars ${s.total_stars ?? '-'})`);
  const aScore = s.total_score, aStars = s.total_stars;
  check(profId(a[R2]) === '', 'A: the current build has no [profile]');
  await g.ctx.close();

  // ===== B: candidate =====
  serving = 'new';
  g = await play();
  s = await state(g);
  const b = await store(g);
  const id = profId(b[R2]);
  check(s.player_build && s.player_identity === true && sameProgress(s) && s.total_score === aScore && s.total_stars === aStars,
    `B: the CANDIDATE continues the same save: ${JSON.stringify(progressOf(s))}, total ${s.total_score}`);
  check(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(id) && prof(s).id_valid, 'B: a valid anonymous id is added in [profile]');
  check(Object.keys(b).sort().join(',') === Object.keys(a).sort().join(','), `B: no new storage key (${Object.keys(b).sort().join(', ')})`);
  for (const sec of ['progress', 'economy', 'scores', 'stars', 'times', 'clean_times', 'chapters']) {
    check(section(b[R2], sec) === section(a[R2], sec), `B: [${sec}] unchanged by the upgrade`);
  }
  const created = (/created_unix=(\d+)/.exec(section(b[R2], 'profile')) || [])[1];
  await g.ctx.close();
  g = await play();
  s = await state(g);
  const b2 = await store(g);
  check(profId(b2[R2]) === id && (/created_unix=(\d+)/.exec(section(b2[R2], 'profile')) || [])[1] === created, 'B: after a reload the same id (made exactly once)');

  // ===== N: Settings + names in the player build =====
  s = await openSettings(g);
  await g.page.screenshot({ path: path.join(shots, 'release_SE_settings_empty.png') });
  check((s.settings_over || []).length === 0 && row(s).visible && row(s).text === 'ADD YOUR NAME (OPTIONAL)', `N: Settings above the whole HUD, optional name row ("${row(s).text}")`);
  let r = await enterName(g, 'Loay ❤️ לואי \u{1F3C6}');
  check(r.facts.focused && r.facts.fontPx >= 16 && r.facts.top < H * 0.35 && r.facts.title === 'YOUR NAME', `N: native field focused, ${r.facts.fontPx}px, near the top, title "${r.facts.title}"`);
  const NAME = 'Loay ❤️ לואי \u{1F3C6}';
  check(prof(r.s).name === NAME && row(r.s).text.startsWith('NAME:') && row(r.s).text.includes(NAME), `N: English + Hebrew + 2 emoji saved, shown as "${row(r.s).text}"`);
  await sleep(300);
  await g.page.screenshot({ path: path.join(shots, 'release_SE_settings_name.png') });
  r = await enterName(g, 'Loay \u{1F3C6}\u{1F525}⭐');
  check(prof(r.s).name === NAME && /at most 2 emoji/.test(row(r.s).note), `N: a 3rd emoji refused ("${row(r.s).note}")`);
  r = await enterName(g, 'Loay \u{1F600}');
  check(prof(r.s).name === NAME && /letters, numbers/.test(row(r.s).note), 'N: another emoji refused');
  r = await enterName(g, 'Alexandra Konstantine');
  check(prof(r.s).name === NAME && r.facts.count === '21 / 20' && r.facts.saveDisabled, `N: 21 characters held (${r.facts.count})`);
  for (const nm of ['محمد', 'Loay لؤي לואי']) {
    r = await enterName(g, nm);
    check(prof(r.s).name === nm, `N: "${nm}" saved`);
  }
  r = await enterName(g, NAME);
  await tap(g, 0.5, 0.02);
  await waitFor(g, (x) => !x.settings_open, 'settings closed', 8000);
  const n = await store(g);
  check(profId(n[R2]) === id && sameProgress(await state(g)), 'N: naming keeps the id and the progress');
  await g.ctx.close();

  // ===== C: rollback to the current build =====
  serving = 'cur';
  g = await play();
  s = await state(g);
  check(sameProgress(s) && s.total_score === aScore, `C: ROLLBACK - the current build continues: ${JSON.stringify(progressOf(s))}, total ${s.total_score}`);
  const c0 = await store(g);
  const profBefore = section(c0[R2], 'profile');
  // Make the current build rewrite the save: Settings > MUSIC (it sits 300
  // design units above BACKUP CODE; the 720 x 1280 canvas is scaled to the
  // screen width).
  s = await openSettings(g);
  const k = W / 720;
  await tap(g, s.backup_button[0], s.backup_button[1] - (300 * k) / H);
  await sleep(900);
  const c1 = await store(g);
  check(seqOf(c1[R2]) > seqOf(c0[R2]) && /music=false/.test(section(c1[R2], 'settings') || ''), `C: the current build rewrote the save (seq ${seqOf(c0[R2])} -> ${seqOf(c1[R2])}, music off)`);
  check(section(c1[R2], 'profile') === profBefore && profId(c1[R2]) === id, 'C: ... and kept [profile] (id and name) exactly as it was');
  await tap(g, s.backup_button[0], s.backup_button[1] - (300 * k) / H);  // music back on
  await sleep(900);
  await g.ctx.close();

  // ===== F: forward to the candidate again =====
  serving = 'new';
  g = await play();
  s = await state(g);
  check(sameProgress(s) && prof(s).name === NAME && profId((await store(g))[R2]) === id, `F: forward again - the same id, name "${prof(s).name}" and progress`);
  await g.ctx.close();

  // ===== Q: QA build on the same origin =====
  const before = (await (async () => { const x = await open(`${ORIGIN}/site/blank`); const v = await store(x); await x.ctx.close(); return v; })())[R2];
  g = await open(`${ORIGIN}/qa/index.html?experiencelab=6&qareset=1`);
  s = await waitFor(g, (x) => x.level === 6 && x.lab_qa && !x.title_open && !x.intro_open, 'QA 6');
  await sleep(800);
  const q = await store(g);
  check(q[R2] === before && profId(q[QAKEY]) !== '' && profId(q[QAKEY]) !== id, 'Q: the QA build has its own player; the release save is byte-identical');
  await g.ctx.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(offsite.length === 0, `W: no request leaves the page's origin (${offsite.length}${offsite.length ? ': ' + offsite.slice(0, 3).join(' ') : ''})`);
check(errors.length === 0, `E: no page errors (${errors.slice(0, 3).join(' | ')})`);
server.close();
const failed = results.filter((x) => !x[0]).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
process.exit(failed ? 1 : 0);
