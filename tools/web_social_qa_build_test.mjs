// SOCIAL QA BUILD ("Web Social QA" export preset, custom feature social_qa,
// Phase 4) in real Chromium at iPhone sizes: the normal game with Social,
// isolated from production.
//
//   godot --headless --path . --export-release "Web Social QA" build/web_social_qa/index.html
//   SHOTS=<dir> node tools/web_social_qa_build_test.mjs build/web_social_qa
//
// The browser already holds the production release save (chain_escape_save_r2,
// Level 14 reached), the pre-release Friend Test save and a Magnet lab save
// - as on the shared itch.io origin.
// A: the flags: social_qa, not the player / QA build, competition OFF,
//    stable links ON; a fresh Level 1 (the release save is never read).
// B: no debug panel: F1 (+ S) and 5 taps on the LEVEL title do nothing.
// C: developer pages are off: ?experiencelab / QA session, ?openinglab,
//    ?twinsprototype, ?mechlab, ?friendbench, ?vhtest, ?sharetest -> the
//    normal game.
// D: save isolation: the build writes only its own keys
//    (chain_escape_socialqa_*); the release, Friend Test and Magnet saves
//    are byte-identical; after a reload its own save is kept.
// E: no request leaves the page's origin (no results submission, nothing
//    to Supabase) during start, play and reload.
// The Social flows themselves (CREATE CHALLENGE, Photo / Message, Friend,
// share, recipient) are covered by running web_friend_flow_test,
// web_share_options_test and web_recipient_test on this build.
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
const root = path.resolve(process.argv[2] || 'build/web_social_qa');
const shots = process.env.SHOTS || os.tmpdir();
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, req.url === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8797, '127.0.0.1');
const BASE = 'http://127.0.0.1:8797/index.html';
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const state = (page) => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(page, pred, what, ms = 120000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(page);
    if (s && pred(s)) return s;
    await sleep(150);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, title: s.title_open }));
}


const SEED = ['[meta]', '', 'version=5', 'seq=11', '', '[progress]', '', 'current_level=14', 'highest_completed=13', 'highest_unlocked=14', '',
  '[economy]', '', 'coins=200', 'inventory={"hammer": 0, "hint": 2}', '', '[chapters]', '',
  'tips_seen=["intro_portal", "intro_magnet", "lesson_lock", "lesson_magnet", "lesson_switch", "lesson_gate", "lesson_armor", "lesson_twins"]', '',
  '[scores]', '', ...Array.from({ length: 13 }, (_, i) => `${i + 1}=9000`), '', '[stars]', '', ...Array.from({ length: 13 }, (_, i) => `${i + 1}=3`), '',
  '[times]', '', '14=50000', '', '[clean_times]', '', '14=50000', ''].join('\n');
const OTHER = { chain_escape_save_r2: SEED, chain_escape_save: SEED.replace('current_level=14', 'current_level=9'), chain_escape_magnetlab_save: SEED.replace('coins=200', 'coins=77') };

const errors = [];
const external = [];
for (const [W, H, label] of [[375, 667, 'iphoneSE'], [390, 844, 'iphone14'], [430, 932, 'promax']]) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-socialqa-'));
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await ctx.route((u) => !u.href.startsWith('http://127.0.0.1:8797/'), (r) => { external.push(r.request().url()); r.abort(); });
  const tap = (page, p) => page.touchscreen.tap(p[0] * W, p[1] * H);
  try {
    const page = ctx.pages()[0] || await ctx.newPage();
    page.on('pageerror', (e) => errors.push(`${label}: ${e.message}`));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(`${label} console: ${m.text()}`); });
    await page.addInitScript((other) => { try { for (const k in other) if (!localStorage.getItem(k)) localStorage.setItem(k, other[k]); } catch (e) {} }, OTHER);
    await page.goto(BASE);
    let s = await waitFor(page, (x) => x.title_open, 'title');
    check(s.social_qa && !s.player_build && !s.qa_build && s.stable_links && s.competition && s.competition.enabled === false,
      `A[${label}]: social_qa build, not player / QA, stable links on, competition off`);
    check(s.level === 1 && s.highest_completed === 0 && s.level_count === 300 && !s.experience_lab && !s.lab_qa,
      `A[${label}]: a fresh Level 1 of ${s.level_count} - the release save (Level 14) is not read`);
    await page.screenshot({ path: path.join(shots, `socialqa_${label}_title.png`) });
    await tap(page, s.title_continue);
    s = await waitFor(page, (x) => !x.title_open && x.level === 1, 'level 1');
    await sleep(1200);
    await page.focus('canvas').catch(() => {});
    await page.keyboard.press('F1'); await sleep(400);
    s = await state(page);
    const f1Open = s.debug_open;
    await page.keyboard.press('s'); await sleep(5000);
    s = await state(page);
    check(!f1Open && !s.debug_open && !s.completed, `B[${label}]: F1 (+ S) opens no debug panel and solves nothing`);
    for (let i = 0; i < 6; i++) { await tap(page, s.level_label); await sleep(120); }
    await sleep(500);
    s = await state(page);
    check(!s.debug_open, `B[${label}]: 5+ taps on the LEVEL title open no debug panel`);
    const store = await page.evaluate(() => Object.fromEntries(Object.keys(localStorage).map((k) => [k, localStorage.getItem(k)])));
    const mine = Object.keys(store).filter((k) => !(k in OTHER));
    check(Object.keys(OTHER).every((k) => store[k] === OTHER[k]), `D[${label}]: release (r2), Friend Test and Magnet saves byte-identical`);
    check(mine.length > 0 && mine.every((k) => k.startsWith('chain_escape_socialqa_') || k.startsWith('ce_')) && 'chain_escape_socialqa_save' in store,
      `D[${label}]: only its own keys written (${mine.sort().join(', ')})`);
    if (label === 'iphone14') {
      const seq = s.save_seq;
      await page.reload();
      s = await waitFor(page, (x) => x.title_open, 'title after reload');
      check(s.save_seq >= seq && s.save_source !== 'new' && s.highest_completed === 0, `D: after a reload its own save is kept (source ${s.save_source}, seq ${s.save_seq})`);
      for (const q of ['?experiencelab=176', '?v=123&experiencelab=250&qareset=1', '?experiencelab=1', '?openinglab=1', '?twinsprototype=1', '?mechlab=1', '?mechlab=sequence', '?friendbench=1', '?vhtest=1', '?sharetest=1']) {
        await page.goto(BASE + q);
        s = await waitFor(page, (x) => x.title_open || x.level > 0, 'page ' + q);
        await sleep(1500);
        s = await state(page);
        const overlay = await page.evaluate(() => !!document.getElementById('ce-sharetest'));
        check(s.title_open && !s.experience_lab && !s.opening_lab && !s.twins_prototype && !s.lab_qa && s.level_count === 300 && !overlay && s.social_qa,
          `C: ${q} gives the normal Social QA game`);
      }
      const after = await page.evaluate(() => Object.fromEntries(Object.keys(localStorage).map((k) => [k, localStorage.getItem(k)])));
      check(Object.keys(OTHER).every((k) => after[k] === OTHER[k]), 'D: after every developer address the other saves are still byte-identical');
    }
  } catch (e) {
    check(false, `${label}: ${e.message}`);
  }
  await ctx.close();
}
check(external.length === 0, `E: no request left the page's origin (${external.length}: ${external.slice(0, 3).join(' | ')})`);
check(errors.length === 0, `no page or console errors (${errors.slice(0, 4).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
