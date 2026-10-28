// Phase 19 QA3: results kept across a build update (?extreme90p19=1), real
// Chromium at iPhone SE size (375x667), real touches, ONE origin (one
// localStorage) - as a tester's phone sees it when a new ZIP replaces the old:
//   node tools/web_extreme90_p19_upgrade_test.mjs <old dev build> <new dev build> [--shots=dir]
//   1. the OLD build (all 22 challenges, N3 = CHALLENGE 1, N35 = CHALLENGE 21):
//      N3 and N35 solved by touches, questions skipped;
//   2. the NEW build on the same origin: the developer build id on CHOOSE A
//      CHALLENGE; only N35 / N36 (CHALLENGE 1-2), N35 still "Solved";
//      PREVIOUS CHALLENGES shows N3 (CHALLENGE 3) still "Solved", BACK;
//      both boards' stored results byte-for-byte unchanged; N36 played on the
//      new build adds its own result and leaves the others alone; COPY ALL
//      RESULTS exports every run under its real board id and fingerprint.
// Chromium is not iPhone Safari.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const OLD = path.resolve(process.argv[2]), NEW = path.resolve(process.argv[3]);
const shots = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
const PORT = 8846, W = 375, H = 667;
let root = OLD;  // the one origin serves the old build, then the new one
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(root, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream', 'Cache-Control': 'no-store' }); res.end(d); });
}).listen(PORT);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const LSB = (b) => `chain_escape_xb19_${b.toLowerCase()}_state`;
const url = `http://127.0.0.1:${PORT}/index.html?extreme90p19=1`;
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

try {
  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  await ctx.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: `http://127.0.0.1:${PORT}` });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript(() => { window.ceTestHooks = true; });
  const cdp = await ctx.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const hub = get('chainEscapeXb19'), vt = get('chainEscapeVhTest'), play = get('chainEscapeSocialPlay'), ta = get('chainEscapeTimeAttack');
  const waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(100); }
    throw new Error(`timeout ${what} ${JSON.stringify(v).slice(0, 300)}`);
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  const tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(80); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  const tapHub = async (name, view, after = 900) => { const v = await waitFor(hub, (v) => v.view === view && v.buttons[name], name); await tap(v.buttons[name], after); };
  const shot = async (n) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, n + '.png') }); } };
  const reveal = async (name) => {
    for (let k = 0; k < 40; k++) {
      const v = await hub();
      if (v.buttons[name]) return true;
      await page.mouse.move(W / 2, H * 0.5);
      await page.mouse.wheel(0, 120);
      await sleep(250);
    }
    return false;
  };
  const stored = async (b) => page.evaluate((k) => localStorage.getItem(k), LSB(b));
  const results0 = async (b) => JSON.stringify((JSON.parse((await stored(b)) || '{}').results) || []);
  // One board: its tile -> brief -> solved by touches -> one SKIP -> back to `home`.
  const playBoard = async (tile, home) => {
    if (home === 'PREVIOUS' || (await hub()).view === 'SELECT') await reveal(tile);
    await tapHub(tile, home, 1200);
    await waitFor(vt, (x) => x.screen === 'BRIEF' && x.buttons.BeginPuzzle, 'brief');
    await tap((await vt()).buttons.BeginPuzzle, 1500);
    await waitFor(ta, (x) => x.run_active, 'running');
    let done = false;
    for (let i = 0; i < 80 && !done; i++) {
      const p = await waitFor(play, (p) => p.completed || (p.active && p.next && p.next.length === 2), 'move');
      if (p.completed) done = true; else await tap(p.next, 450);
    }
    await waitFor(ta, (x) => x.card && x.buttons.TA_Continue, 'card', 15000);
    await sleep(400);
    await tap((await ta()).buttons.TA_Continue, 900);
    const q = await waitFor(vt, (x) => x.screen === 'THINK' && x.buttons.Think_SKIP, 'questions');
    await tap(q.buttons.Think_SKIP, 900);
    await waitFor(hub, (v) => v.view === home, 'back to ' + home, 15000);
    return done;
  };

  // ---------------- 1. The OLD build: N3 (CHALLENGE 1) and N35 (CHALLENGE 21) ----------------
  await page.goto(url);
  await waitFor(hub, (v) => v.view === 'WELCOME' && v.buttons.PilotStart, 'old welcome', 120000);
  await tapHub('PilotStart', 'WELCOME');
  await tapHub('Familiar_PLAYED_A_LITTLE', 'FAMILIARITY');
  let h = await waitFor(hub, (v) => v.view === 'SELECT', 'old select');
  const oldOrder = h.order;
  check(oldOrder.length === 22 && oldOrder[0] === 'N3' && oldOrder[20] === 'N35' && !h.buttons.PreviousChallenges && !h.build,
    `the OLD build: all 22 challenges (N3 = CHALLENGE 1, N35 = CHALLENGE 21), no PREVIOUS CHALLENGES, no build id`);
  await shot('U1_old_select');
  const s3 = await playBoard('Puzzle_1', 'SELECT');
  const s35 = await playBoard('Puzzle_21', 'SELECT');
  const before = { N3: await stored('N3'), N35: await stored('N35') };
  const r3 = JSON.parse(before.N3).results, r35 = JSON.parse(before.N35).results;
  check(s3 && s35 && r3.length === 1 && r35.length === 1 && r3[0].timed.outcome === 'COMPLETED' && r35[0].timed.outcome === 'COMPLETED',
    'OLD build: N3 and N35 solved by touches; one stored result each (xb19)');

  // ---------------- 2. The NEW build on the same origin ------------------------------------
  root = NEW;
  await page.goto(url + '&v=' + Date.now());
  h = await waitFor(hub, (v) => v.view === 'SELECT', 'new select (familiarity remembered)', 120000);
  const main = Object.keys(h.buttons).filter((n) => n.startsWith('Puzzle_')).sort();
  check(/^DEV BUILD p19-/.test(h.build) && h.primary.join(',') === 'N35,N36' && main.join(',') === 'Puzzle_1,Puzzle_2' && h.buttons.PreviousChallenges,
    `the NEW build: "${h.build}" on CHOOSE A CHALLENGE; only N35 / N36 (CHALLENGE 1-2) and PREVIOUS CHALLENGES; straight to the selection (the saved familiarity kept)`);
  check(/^Solved/.test(h.statuses['1']) && h.statuses['2'] === 'New', `N35's earlier result kept: CHALLENGE 1 "${h.statuses['1']}", CHALLENGE 2 "${h.statuses['2']}"`);
  await shot('U2_new_select');
  await tapHub('PreviousChallenges', 'SELECT');
  h = await waitFor(hub, (v) => v.view === 'PREVIOUS' && v.buttons.PreviousBack, 'previous');
  check(/^Solved/.test(h.statuses['3']) && h.order[2] === 'N3' && h.buttons.Puzzle_3 && !h.buttons.Puzzle_1, `PREVIOUS CHALLENGES: N3 (now CHALLENGE 3) "${h.statuses['3']}"; no new board listed`);
  await shot('U3_new_previous');
  await tapHub('PreviousBack', 'PREVIOUS');
  await waitFor(hub, (v) => v.view === 'SELECT', 'back');
  check((await stored('N3')) === before.N3 && (await stored('N35')) === before.N35, 'N3 and N35 stored records byte-for-byte unchanged by the new build');
  const s36 = await playBoard('Puzzle_2', 'SELECT');
  const r36 = JSON.parse((await stored('N36')) || '{}').results || [];
  check(s36 && r36.length === 1 && (await results0('N3')) === JSON.stringify(r3) && (await results0('N35')) === JSON.stringify(r35),
    'N36 played on the new build: its own result stored; N3 / N35 results unchanged');
  h = await hub();
  await page.evaluate(() => navigator.clipboard.writeText(''));
  await tap(h.buttons.CopyResults, 1200);
  let bundle = null;
  try { bundle = JSON.parse(await page.evaluate(() => navigator.clipboard.readText())); } catch { /* not JSON */ }
  const runs = bundle ? bundle.runs.map((r) => r.board).sort().join(',') : '';
  const fpOk = bundle && bundle.runs.every((r) => r.fingerprint === bundle.boards[r.board].fingerprint && /^[0-9a-f]{64}$/.test(r.fingerprint));
  check(bundle && bundle.format === 'ce-xb19' && 'DEV BUILD ' + bundle.build === h.build && runs === 'N3,N35,N36' && fpOk
    && bundle.boards.N35.puzzle === 1 && bundle.boards.N36.puzzle === 2 && bundle.boards.N3.puzzle === 3 && bundle.boards.N3.list === 'previous' && bundle.boards.N35.list === 'new',
    `COPY ALL RESULTS (${bundle && bundle.build}): runs ${runs}, each under its real board id and fingerprint (N35 = 1, N36 = 2, N3 = 3, lists new / previous)`);
  console.log('FPS ' + JSON.stringify(bundle ? { N35: bundle.boards.N35.fingerprint, N36: bundle.boards.N36.fingerprint } : null));
  check(errors.length === 0, 'no page errors ' + JSON.stringify(errors.slice(0, 3)));
  await ctx.close();
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB P19 UPGRADE TEST: FAILED (${failed}/${results.length})` : `WEB P19 UPGRADE TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
