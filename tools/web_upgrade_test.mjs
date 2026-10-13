// UPGRADE / ROLLBACK SAVE CONTINUITY between two PRODUCTION ZIPs, served from
// the SAME URL in the SAME browser profile (as when the itch.io files are
// replaced):
//
//   node tools/web_upgrade_test.mjs <current production ZIP|dir> <candidate ZIP|dir>
//
// A: the current build continues a release save (r2): Level 14, 13 cleared,
//    200 coins, 2 SHOW A MOVE boosters, BEST 50.000 s on Level 14.
// B: the files are replaced by the candidate: the same save continues -
//    progress, coins, boosters and the time record unchanged; the save
//    keeps its key (chain_escape_save_r2) and nothing else is written.
// C: rollback - the current build again reads what the candidate wrote.
// D: no page errors.
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
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-up-'));
  execSync(`unzip -q "${abs}" -d "${dir}"`);
  return dir;
};
const [curArg, newArg] = process.argv.slice(2);
if (!curArg || !newArg) { console.error('usage: node tools/web_upgrade_test.mjs <current> <candidate>'); process.exit(2); }
const builds = { cur: unpack(curArg), new: unpack(newArg) };
let serving = 'cur';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const m = req.url.split('?')[0].match(/^\/site\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const file = path.join(builds[serving], decodeURIComponent(m[1] || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(data);
  });
}).listen(8795, '127.0.0.1');
const URL = 'http://127.0.0.1:8795/site/index.html';
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const errors = [];
const R2 = 'chain_escape_save_r2';
const SEED = ['[meta]', '', 'version=5', 'seq=11', '', '[progress]', '', 'current_level=14', 'highest_completed=13', 'highest_unlocked=14', '',
  '[economy]', '', 'coins=200', 'inventory={"hammer": 0, "hint": 2}', '', '[chapters]', '',
  'tips_seen=["intro_portal", "intro_magnet", "lesson_lock", "lesson_magnet", "lesson_switch", "lesson_gate", "lesson_armor", "lesson_twins"]', '',
  '[scores]', '', ...Array.from({ length: 13 }, (_, i) => `${i + 1}=9000`), '', '[stars]', '', ...Array.from({ length: 13 }, (_, i) => `${i + 1}=3`), '',
  '[times]', '', '14=50000', '', '[clean_times]', '', '14=50000', ''].join('\n');
const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-up-prof-'));

async function session(label, seed) {
  const ctx = await chromium.launchPersistentContext(profile, { headless: true, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio'],
    viewport: { width: 375, height: 667 }, isMobile: true, hasTouch: true });
  if (seed) await ctx.addInitScript(([k, v]) => { try { if (!localStorage.getItem(k)) localStorage.setItem(k, v); } catch (e) {} }, [R2, seed]);
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(`${label}: ${e.message}`));
  await page.goto(URL);
  let s = null;
  const end = Date.now() + 90000;
  while (Date.now() < end) {
    s = await page.evaluate(() => window.chainEscapeState || null).catch(() => null);
    if (s && s.title_open) break;
    await sleep(150);
  }
  await page.touchscreen.tap(s.title_continue[0] * 375, s.title_continue[1] * 667);
  const end2 = Date.now() + 90000;
  while (Date.now() < end2) {
    s = await page.evaluate(() => window.chainEscapeState || null).catch(() => null);
    if (s && !s.title_open && s.level > 0) break;
    await sleep(150);
  }
  await sleep(1200);
  const store = await page.evaluate(() => Object.fromEntries(Object.keys(localStorage).map((k) => [k, localStorage.getItem(k)])));
  await ctx.close();
  return { s, store };
}
const summary = (s) => `L${s.level}, cleared ${s.highest_completed}, ${s.coins} coins, hints ${s.inventory.hint}, BEST ${s.best_time_ms} ms, player build ${s.player_build}, polish ${s.feedback_polish}`;

try {
  serving = 'cur';
  const a = await session('current', SEED);
  check(a.s.player_build && a.s.level === 14 && a.s.highest_completed === 13 && a.s.coins === 200 && a.s.inventory.hint === 2 && a.s.best_time_ms === 50000,
    `A: the CURRENT production build continues the release save: ${summary(a.s)}`);
  serving = 'new';
  const b = await session('candidate');
  check(b.s.player_build && b.s.feedback_polish === true && b.s.level === 14 && b.s.highest_completed === 13 && b.s.coins === 200 && b.s.inventory.hint === 2 && b.s.best_time_ms === 50000 && b.s.best_clean_ms === 50000,
    `B: files replaced by the CANDIDATE - the same save continues: ${summary(b.s)}`);
  check(Object.keys(b.store).sort().join(',') === Object.keys(a.store).sort().join(','), `B: the same storage keys (${Object.keys(b.store).sort().join(', ')})`);
  check((b.store[R2] || '').includes('[times]') && (b.store[R2] || '').includes('14=50000'), 'B: the time records are kept in chain_escape_save_r2');
  serving = 'cur';
  const c = await session('rollback');
  check(c.s.level === 14 && c.s.highest_completed === 13 && c.s.coins === 200 && c.s.inventory.hint === 2 && c.s.best_time_ms === 50000 && c.s.feedback_polish !== true,
    `C: ROLLBACK - the current build reads what the candidate wrote: ${summary(c.s)}`);
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(errors.length === 0, `D: no page errors (${errors.join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
process.exit(failed ? 1 : 0);
