// PRODUCTION COMPETITION (Phase 3B launch candidate): the exported PLAYER
// build ("Web Friend Test", player_build) with competition on, in real
// Chromium at iPhone sizes, Level 1 played by touch. Nothing leaves the
// machine: the API is a local fake (window.ceTestHooks + ceApiUrl) and
// every request to *.supabase.co is blocked and counted.
//
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   SHOTS=<dir> node tools/web_prod_competition_test.mjs build/web_friend
//
// For each iPhone size, a fresh browser profile:
// A: the title, CONTINUE, Level 1 by touch; the server answers 403
//    prod_closed (the prod pool closed): the card says SAVED, WILL SEND
//    LATER, the result stays queued in the release save (r2), the request
//    asked for pool "prod", without diagnostics or a display name.
// B: the pool opens (TOP 14%): REPLAY, clear again - the queued result is
//    sent, the card shows TOP 14% (or YOUR BEST TOP 14%), nothing queued.
// C: 5xx and a dead network: a quiet STANDING line, never a number.
// D: fewer than 5 players: NOT ENOUGH PLAYERS YET.
// E: a reload keeps the same player id and secret (no new competitor).
// F: the card and the row fit: inside the screen and the card, under TIME,
//    above REPLAY / NEXT; no horizontal overflow.
// G: every result request asked for "prod"; 0 requests to Supabase; no
//    page errors.
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
const root = path.resolve(process.argv[2] || 'build/web_friend');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
// mode: 'closed' (403 prod_closed), a number or null (the percentile),
// 'down' (500), 'offline' (the connection is dropped).
let mode = 'closed';
const bodies = [];
const server = http.createServer((req, res) => {
  const url = req.url.split('?')[0];
  if (url === '/api') {
    let raw = '';
    req.on('data', (c) => { raw += c; });
    req.on('end', () => {
      let body = {};
      try { body = JSON.parse(raw || '{}'); } catch { body = {}; }
      const result = req.method === 'POST' && (body.action === 'submit_result' || body.action === 'level_standing');
      if (result) bodies.push(body);
      if (result && mode === 'offline') { req.socket.destroy(); return; }
      let code = 200;
      let out = { ok: true, service: 'chain-escape-api', version: 5 };
      if (result) {
        if (mode === 'closed') { code = 403; out = { ok: false, error: 'prod_closed' }; }
        else if (mode === 'down') { code = 500; out = { ok: false, error: 'database_error' }; }
        else out = { ok: true, improved: true, best_ms: body.time_ms || 999999, percentile: mode };
      }
      res.writeHead(code, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(out));
    });
    return;
  }
  const file = path.join(root, decodeURIComponent(url.replace(/^\/prod\//, '') || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8793, '127.0.0.1');
const PROD = 'http://127.0.0.1:8793/prod/index.html';

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];
const supabaseHits = [];
let analyzer = null;
const SIZES = { iphoneSE: [375, 667], iphone14: [390, 844], promax: [430, 932] };

async function open(dir, size) {
  const [W, H] = SIZES[size];
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await ctx.route(/supabase\.co/, (route) => { supabaseHits.push(route.request().url()); route.abort(); });
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(() => { window.ceTestHooks = true; window.ceApiUrl = 'http://127.0.0.1:8793/api'; });
  await page.goto(PROD);
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
const tapAt = (g, p) => g.page.touchscreen.tap(p[0] * g.W, p[1] * g.H);
const perfNow = (g) => g.page.evaluate(() => performance.now());

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

// The state is a snapshot published on events (the player build has no
// debug panel to republish it): wait for the card's pop-in and the fake's
// answer, whose own publish (standing_changed -> publish_state) is read.
async function card(g) {
  await waitFor(g, (x) => x.card_open && x.level === 1, 'card', 30000);
  await sleep(3000);
  return state(g);
}
const inside = (r, c) => r[0] >= c[0] - 0.001 && r[2] <= c[2] + 0.001 && r[1] >= c[1] - 0.001 && r[3] <= c[3] + 0.001;
const fits = (s) => {
  const c = s.card_rect, p = s.time_panel.rect, r = s.time_panel.comp_rect, t = s.time_panel.time_value_rect;
  return c[0] >= 0 && c[1] >= 0 && c[2] <= 1 && c[3] <= 1 && inside(p, c) && inside(r, p)
    && r[1] >= t[3] - 0.001 && r[3] <= s.replay[1] - 0.041 && r[3] <= s.next[1] - 0.041 && c[1] >= s.time_panel.hud_bottom;
};
const PENDING = /^STANDING   ·   [A-Z ,.]+$/;
const save = (g) => g.page.evaluate(() => localStorage.getItem('chain_escape_save_r2') || '');
const secretOf = (t) => (t.match(/^secret="([0-9a-f]{64})"/m) || [])[1] || '';
const idOf = (t) => (t.match(/^id="([0-9a-f-]{36})"/m) || [])[1] || '';
async function replay(g, s) {
  await tapAt(g, s.replay);
  await waitFor(g, (x) => x.level === 1 && !x.card_open && !x.completed, 'replay');
  await sleep(800);
  await clearLevel1(g);
  return card(g);
}

try {
  const abrowser = await chromium.launch(LAUNCH);
  analyzer = await abrowser.newPage();
  for (const size of ['iphoneSE', 'iphone14', 'promax']) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-prodcomp-'));
    let g = await open(dir, size);
    let s = await waitFor(g, (x) => x.title_open, 'title ' + size);
    check(s.player_build && !s.qa_build && s.competition.enabled && s.competition.pool === 'prod' && s.competition.has_secret,
      `A[${size}]: player build, competition on, pool prod, a secret made (qa_build ${s.qa_build})`);
    // A: closed server.
    mode = 'closed';
    const n0 = bodies.length;
    await tapAt(g, s.title_continue);
    s = await waitFor(g, (x) => !x.title_open && x.level === 1, 'level 1 ' + size);
    await sleep(1500);
    await clearLevel1(g);
    s = await card(g);
    const b = bodies.slice(n0).filter((x) => x.action === 'submit_result');
    check(s.time_panel.comp === 'STANDING   ·   SAVED, WILL SEND LATER' && !s.time_panel.comp_badge, `A[${size}]: prod closed -> "${s.time_panel.comp}"`);
    check(b.length >= 1 && b.every((x) => x.pool === 'prod' && !('diag' in x) && !('name' in x) && !('display_name' in x) && /^[0-9a-f]{64}$/.test(x.fingerprint) && x.level === 1),
      `A[${size}]: ${b.length} submit(s): pool prod, Level 1 fingerprint, no diagnostics, no name`);
    let text = await save(g);
    check(/\[competition\]/.test(text) && /pending=/.test(text) && secretOf(text) !== '' && idOf(text) !== '',
      `A[${size}]: the result is queued in chain_escape_save_r2 ([competition] pending; [profile] id + secret)`);
    check(fits(s), `F[${size}]: card ${s.card_rect.map((v) => v.toFixed(3)).join(', ')} / row ${s.time_panel.comp_rect.map((v) => v.toFixed(3)).join(', ')} fit (scale ${s.time_panel.card_scale})`);
    await g.page.screenshot({ path: path.join(shots, `prodcomp_${size}_closed.png`) });
    // B: the pool opens.
    mode = 14;
    s = await replay(g, s);
    text = await save(g);
    check(/^(YOUR BEST )?TOP 14%$/.test(s.time_panel.comp) && s.time_panel.comp_badge && !/pending=\{[^}]/.test(text),
      `B[${size}]: pool open -> "${s.time_panel.comp}", nothing left queued`);
    check(fits(s), `F[${size}]: TOP 14% card fits (scale ${s.time_panel.card_scale})`);
    await g.page.screenshot({ path: path.join(shots, `prodcomp_${size}_top14.png`) });
    if (size === 'iphoneSE') {
      // C: errors and a dead network: a quiet line, never a number.
      for (const m of ['down', 'offline']) {
        mode = m;
        s = await replay(g, s);
        check(PENDING.test(s.time_panel.comp) && !/\d|%/.test(s.time_panel.comp) && !s.time_panel.comp_badge, `C[${size}]: ${m} -> "${s.time_panel.comp}"`);
      }
      // D: fewer than 5 players.
      mode = null;
      s = await replay(g, s);
      check(s.time_panel.comp === 'STANDING   ·   NOT ENOUGH PLAYERS YET', `D[${size}]: not enough players -> "${s.time_panel.comp}"`);
      // E: a reload keeps the same competitor.
      const before = await save(g);
      await g.page.reload();
      s = await waitFor(g, (x) => x.title_open, 'title after reload');
      const after = await save(g);
      check(idOf(after) === idOf(before) && secretOf(after) === secretOf(before) && secretOf(after) !== '', `E[${size}]: after a reload the same player id and secret`);
    }
    await g.ctx.close();
  }
  const pools = [...new Set(bodies.map((x) => x.pool))];
  check(pools.length === 1 && pools[0] === 'prod', `G: every result request asked for the prod pool (${pools.join(', ')}; ${bodies.length} requests)`);
} catch (e) {
  check(false, 'exception: ' + e.message);
}
check(supabaseHits.length === 0, `G: no request reached Supabase (${supabaseHits.length})`);
check(errors.length === 0, `G: no page errors (${errors.slice(0, 3).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? 'WEB PROD COMPETITION TEST PASSED' : 'WEB PROD COMPETITION TEST FAILED');
process.exit(failed === 0 ? 0 : 1);
