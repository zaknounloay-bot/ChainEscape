// COMPETITION STANDING ROW (Phase 3B-C) in the exported QA build, real
// Chromium at iPhone sizes. Nothing leaves the machine: the game's API is
// pointed at a fake on the same local server (window.ceTestHooks +
// ceApiUrl) and every request to *.supabase.co is blocked and counted.
//
//   godot --headless --path . --export-release "Web QA" build/web_qa/index.html
//   SHOTS=<dir> node tools/web_competition_card_test.mjs build/web_qa
//
// For each case: a QA jump level (?experiencelab=N&qareset=1) is solved
// with the debug auto-solve; the fake answers TOP 37%, null (not enough
// players) or 500 (kept, "will send later"). Checks: the row text; the
// card, its timing panel and the row inside the screen, below the top HUD,
// above REPLAY / NEXT; no horizontal overflow; requests ask for the qa
// pool only; no request reaches Supabase; no page errors.
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
const root = path.resolve(process.argv[2] || 'build/web_qa');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
let fakeMode = 'top';
const apiBodies = [];
const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  if (url === '/api') {
    let raw = '';
    req.on('data', (c) => { raw += c; });
    req.on('end', () => {
      let body = {};
      try { body = JSON.parse(raw || '{}'); } catch { body = {}; }
      if (req.method === 'POST') apiBodies.push(body);
      let code = 200;
      let out = { ok: true, service: 'chain-escape-api', version: 5 };
      if (req.method === 'POST' && (body.action === 'submit_result' || body.action === 'level_standing')) {
        if (fakeMode === 'down') { code = 500; out = { ok: false, error: 'database_error' }; }
        else out = { ok: true, improved: true, best_ms: body.time_ms || 1000, percentile: fakeMode === 'top' ? 37 : null };
      }
      res.writeHead(code, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(out));
    });
    return;
  }
  const file = path.join(root, decodeURIComponent(url.replace(/^\/qa\//, '') || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8791, '127.0.0.1');
const QA = 'http://127.0.0.1:8791/qa/index.html';

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];
const supabaseHits = [];
const SIZES = { iphoneSE: [375, 667], iphone14: [390, 844], promax: [430, 932] };

async function open(url, size) {
  const [W, H] = SIZES[size];
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-comp-'));
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await ctx.route(/supabase\.co/, (route) => { supabaseHits.push(route.request().url()); route.abort(); });
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(() => { window.ceTestHooks = true; window.ceApiUrl = 'http://127.0.0.1:8791/api'; });
  await page.goto(url);
  return { ctx, page, W, H };
}
const state = (g) => g.page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(g, pred, what, ms = 150000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(g);
    if (s && pred(s)) return s;
    await sleep(150);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, title: s.title_open, card: s.card_open }));
}
const inside = (r, c) => r[0] >= c[0] - 0.001 && r[2] <= c[2] + 0.001 && r[1] >= c[1] - 0.001 && r[3] <= c[3] + 0.001;
const fits = (s) => {
  const c = s.card_rect, p = s.time_panel.rect, r = s.time_panel.comp_rect;
  return c[0] >= 0 && c[1] >= 0 && c[2] <= 1 && c[3] <= 1 && inside(p, c) && inside(r, p)
    && r[3] <= s.replay[1] - 0.041 && r[3] <= s.next[1] - 0.041 && c[1] >= s.time_panel.hud_bottom;
};

const CASES = [
  { size: 'iphoneSE', level: 100, mode: 'top', want: /^TOP 37%$/ },
  { size: 'iphoneSE', level: 300, mode: 'down', want: /^STANDING   ·   SAVED, WILL SEND LATER$/ },
  { size: 'iphoneSE', level: 10, mode: 'needs', want: /^STANDING   ·   NOT ENOUGH PLAYERS YET$/ },
  { size: 'iphone14', level: 12, mode: 'top', want: /^TOP 37%$/ },
  { size: 'promax', level: 250, mode: 'needs', want: /^STANDING   ·   NOT ENOUGH PLAYERS YET$/ },
];

try {
  for (const k of CASES) {
    fakeMode = k.mode;
    const g = await open(QA + `?experiencelab=${k.level}&qareset=1`, k.size);
    let s = await waitFor(g, (x) => x.level === k.level && x.lab_qa && !x.title_open, `QA ${k.level}`);
    for (let i = 0; i < 100 && s.intro_open; i++) { await sleep(200); s = await state(g); }
    await sleep(1500);
    await g.page.focus('canvas').catch(() => {});
    await g.page.keyboard.press('F1'); await sleep(250);
    await g.page.keyboard.press('s');
    s = await waitFor(g, (x) => x.card_open && x.level === k.level, `card ${k.level}`);
    await g.page.keyboard.press('F1');
    await sleep(2500);  // the card has settled and the fake has answered
    s = await state(g);
    const tp = s.time_panel;
    check(s.qa_build && s.competition.enabled && s.competition.pool === 'qa', `[${k.size} L${k.level}] QA build, competition on, pool qa`);
    check(tp.comp_row && k.want.test(tp.comp), `[${k.size} L${k.level}] row "${tp.comp}"`);
    check(fits(s), `[${k.size} L${k.level}] card ${s.card_rect.map((v) => v.toFixed(3)).join(', ')}, row ${tp.comp_rect.map((v) => v.toFixed(3)).join(', ')} inside the card, above REPLAY / NEXT, below the HUD (scale ${tp.card_scale})`);
    const ov = await g.page.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth]);
    check(ov[0] <= ov[1], `[${k.size} L${k.level}] no horizontal overflow (${ov[0]} <= ${ov[1]})`);
    await g.page.screenshot({ path: path.join(shots, `comp_${k.size}_L${k.level}_${k.mode}.png`) });
    await g.ctx.close();
  }
  const pools = [...new Set(apiBodies.filter((b) => b.action).map((b) => b.pool))];
  check(pools.length === 1 && pools[0] === 'qa', `every result request asked for the qa pool (${pools.join(', ')}; ${apiBodies.length} requests)`);
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(supabaseHits.length === 0, `no request reached Supabase (${supabaseHits.length})`);
check(errors.length === 0, `no page errors (${errors.slice(0, 3).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB COMPETITION CARD TEST PASSED' : 'WEB COMPETITION CARD TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
