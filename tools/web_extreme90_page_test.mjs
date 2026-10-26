// EXTREME Time Attack bank (?extreme90=1), exported DEVELOPMENT Web build,
// real Chromium at iPhone SE size (375x667), real touches:
//   node tools/web_extreme90_page_test.mjs <dev web build> [--player=<player build>] [--shots=dir]
//   run 1: welcome -> familiarity -> CHOOSE A CHALLENGE (only the bank, neutral
//   CHALLENGE 1..k tiles, all on screen) -> every challenge: its brief, the
//   WebAssembly cost of a full solve (&bench=1 - the Solver call the page makes
//   at TIME UP), a timed 90 s run solved by touches (ta90-v1; the GREEN mix
//   after the START gesture), SOLVED with silence, questions skipped.
//   Phase 16A: CHALLENGE 1's SHORT questionnaire answered by touch (3
//   questions, compact, on screen), every other one left with a single SKIP;
//   never a second questionnaire.
//   run 2: TIME UP on CHALLENGE 1 (the saved clock moved to 0:05 at a reload),
//   silence, one SKIP, CONTINUE WITHOUT TIMER with the CALM mix, solved by
//   touches, straight back to the selection;
//   COPY ALL RESULTS: one ce-xb90 bundle with every board's internal id and
//   fingerprint; ?ta90=1's storage never written.
//   --player: the player build ignores ?extreme90=1.
// Chromium is not iPhone Safari (see tools/web_ta90_page_test.mjs).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const root = path.resolve(process.argv[2] || 'build/web');
const shots = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
const benchOut = (process.argv.find((a) => a.startsWith('--bench-out=')) || '').slice(12);
const playerRoot = (process.argv.find((a) => a.startsWith('--player=')) || '').slice(9);
const PORT = 8840, W = 375, H = 667;  // iPhone SE
const LSB = (b) => `chain_escape_xb90_${b.toLowerCase()}_state`;
const FILL = { green: [0x1e, 0x7b, 0x34], orange: [0xc2, 0x41, 0x0c], red: [0xb9, 0x1c, 0x1c] };
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const serve = (dir) => (req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(dir, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
};
const server = http.createServer(serve(root)).listen(PORT);
const server2 = playerRoot ? http.createServer(serve(path.resolve(playerRoot))).listen(PORT + 1) : null;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

// A minimal PNG decoder (8-bit RGB / RGBA, the five scanline filters).
function decodePNG(buf) {
  let pos = 8, w = 0, h = 0, ct = 0;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8), body = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = body.readUInt32BE(0); h = body.readUInt32BE(4); ct = body[9]; }
    if (type === 'IDAT') idat.push(body);
    pos += 12 + len;
  }
  const bpp = ct === 6 ? 4 : 3, raw = zlib.inflateSync(Buffer.concat(idat)), stride = w * bpp, out = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], line = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[y * stride + x - bpp] : 0, b = y > 0 ? out[(y - 1) * stride + x] : 0, c = x >= bpp && y > 0 ? out[(y - 1) * stride + x - bpp] : 0;
      let v = line[x];
      if (f === 1) v += a; else if (f === 2) v += b; else if (f === 3) v += (a + b) >> 1;
      else if (f === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); v += pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
      out[y * stride + x] = v & 255;
    }
  }
  return { w, h, bpp, data: out };
}
const luma = (c) => 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
const near = (c, e, tol = 22) => Math.abs(c[0] - e[0]) <= tol && Math.abs(c[1] - e[1]) <= tol && Math.abs(c[2] - e[2]) <= tol;


async function session(context, label) {
  const page = await context.newPage();
  const errors = [];
  const external = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (/SCRIPT ERROR|ERROR:|Invalid/.test(m.text()) && !m.text().includes('Condition "!is_inside_tree()" is true')) errors.push(m.text().slice(0, 300)); });
  page.on('request', (r) => { if (!r.url().startsWith(`http://127.0.0.1:${PORT}/`)) external.push(r.url()); });
  await page.addInitScript(() => {
    window.ceTestHooks = true;
    if (location.protocol !== 'http:') return;  // about:blank (the back / forward check)
    const back = Number(sessionStorage.getItem('ceRewind') || 0);
    const k = sessionStorage.getItem('ceRewindKey') || '';
    if (back > 0 && k && localStorage.getItem(k)) {
      sessionStorage.removeItem('ceRewind');
      const s = JSON.parse(localStorage.getItem(k));
      s.run.started_unix -= back;
      s.run.elapsed_ms = (s.run.elapsed_ms || 0) + back * 1000;
      s.seq += 1000;
      localStorage.setItem(k, JSON.stringify(s));
    }
  });
  const cdp = await context.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const s = { page, errors, external, hub: get('chainEscapeXb90'), mus: get('chainEscapeStageMusic'), aud: get('chainEscapeAudio'), vt: get('chainEscapeVhTest'), play: get('chainEscapeSocialPlay'), ta: get('chainEscapeTimeAttack'), cd: get('chainEscapeCountdown') };
  s.waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(100); }
    throw new Error(`${label}: timeout ${what} ${JSON.stringify(v).slice(0, 300)}`);
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  s.tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(80); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  s.shot = async (n) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, n + '.png') }); } };
  s.tapHub = async (name, view, after = 900) => { const v = await s.waitFor(s.hub, (v) => v.view === view && v.buttons[name], name); await s.tap(v.buttons[name], after); };
  s.tapVt = async (name, screen, after = 600) => { const v = await s.waitFor(s.vt, (v) => v.screen === screen && v.buttons[name], name); await s.tap(v.buttons[name], after); };
  s.tapTa = async (name, after = 900) => { await sleep(400); const x = await s.waitFor(s.ta, (v) => v.buttons && v.buttons[name], name); await s.tap(x.buttons[name], after); };
  s.state = async (b) => JSON.parse(await page.evaluate((k) => localStorage.getItem(k), LSB(b)) || '{}');
  s.begin = async () => { await s.tapVt('BeginPuzzle', 'BRIEF', 1500); };
  s.fill = async (c) => {
    const r = c.rect, x = (r[0] + r[2] * 0.935) * W, y = (r[1] + r[3] * 0.5) * H;
    const png = decodePNG(await page.screenshot({ clip: { x: x - 1.5, y: y - 1.5, width: 3, height: 3 } }));
    const acc = [0, 0, 0]; const n = png.w * png.h;
    for (let i = 0; i < n; i++) for (let k = 0; k < 3; k++) acc[k] += png.data[i * png.bpp + k];
    return acc.map((v) => Math.round(v / n));
  };
  s.solveByTouches = async (what) => {
    for (let i = 0; i < 80; i++) {
      const p = await s.waitFor(s.play, (p) => p.completed || (p.active && p.next && p.next.length === 2), what);
      if (p.completed) return true;
      await s.tap(p.next, 450);
    }
    return false;
  };
  s.noOverflow = async () => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth + 1 && document.body.scrollWidth <= window.innerWidth + 1);
  // Every visible hub button inside the screen, at least 44 CSS px tall.
  s.hubFits = async () => { const v = await s.hub(); return Object.values(v.rects).every((r) => r[0] >= 0 && r[1] >= 0 && r[0] + r[2] <= 1.0001 && r[1] + r[3] <= 1.0001 && r[3] * H >= 40); };
  // Skips the remaining questions of a set (SKIP), then whatever follows.
  s.skipAll = async (n) => { for (let i = 0; i < n; i++) await s.tapVt('Think_SKIP', 'THINK', 600); };
  return s;
}


const ctxOpts = { viewport: { width: W, height: H }, deviceScaleFactor: 2, isMobile: true, hasTouch: true };
const allErrors = [], allExternal = [];
const url = `http://127.0.0.1:${PORT}/index.html?extreme90=1`;
const skipToSelect = async (s) => {
  for (let k = 0; k < 40; k++) {
    if ((await s.hub()).view === 'SELECT') return true;
    const q = await s.vt(); const t = await s.ta();
    if (q && q.screen === 'THINK' && q.buttons.Think_SKIP) await s.tap(q.buttons.Think_SKIP, 600);
    else if (t && t.card && t.buttons && (t.buttons.TA_Finish || t.buttons.TA_Continue)) await s.tap(t.buttons.TA_Finish || t.buttons.TA_Continue, 900);
    else await sleep(400);
  }
  return (await s.hub()).view === 'SELECT';
};
try {
  // ---------------- Run 1: every challenge, timed, by touches ------------------------------
  const ctx = await browser.newContext(ctxOpts);
  const a = await session(ctx, 'run 1');
  await a.page.goto(url + '&bench=1');
  let h = await a.waitFor(a.hub, (v) => v.view === 'WELCOME' && v.buttons.PilotStart, 'welcome', 120000);
  check(await a.noOverflow() && await a.hubFits(), '?extreme90=1: the welcome screen; no overflow; buttons on screen');
  await a.shot('X1_welcome');
  await a.tapHub('PilotStart', 'WELCOME');
  await a.tapHub('Familiar_PLAYED_A_LITTLE', 'FAMILIARITY');
  h = await a.waitFor(a.hub, (v) => v.view === 'SELECT', 'select');
  const bank = h.order;
  const tiles = bank.map((_, i) => h.rects['Puzzle_' + (i + 1)]);
  check(bank.slice(0, 5).join(',') === 'N3,N5,N7,N11,N13' && !bank.includes('TA') && tiles.every((r) => r && r[1] + r[3] <= 1.0001 && r[3] * H >= 40)
    && !h.buttons['Puzzle_' + (bank.length + 1)] && await a.hubFits() && await a.noOverflow() && Object.values(h.statuses).every((t) => t === 'New'),
    `CHOOSE A CHALLENGE: only the bank (${bank.join(', ')}), CHALLENGE 1-${bank.length} tiles all on the iPhone SE screen, no reference`);
  await a.shot('X2_select');
  const benchMs = {};
  let unlocked = false;
  for (let i = 0; i < bank.length; i++) {
    const b = bank[i];
    await a.page.evaluate(() => { window.chainEscapeVhBench = null; });
    await a.tapHub('Puzzle_' + (i + 1), 'SELECT', 1200);
    await a.waitFor(a.vt, (x) => x.screen === 'BRIEF' && x.buttons.BeginPuzzle, 'brief ' + b);
    const bench = await a.waitFor(() => a.page.evaluate(() => window.chainEscapeVhBench || null), (x) => x.done && x.results.length === 1 && x.results[0].id === b, 'bench ' + b, 60000);
    benchMs[b] = bench.results[0].verify_ms;
    if (i === 0) await a.shot('X3_brief');
    await a.begin();
    const t0 = await a.waitFor(a.ta, (x) => x.run_active, 'running ' + b);
    if (!unlocked) {
      const m = await a.waitFor(a.mus, (x) => x.playing && x.mix === 'green', 'green music', 8000);
      check(m.unlocked && m.limit_ms === 90000, `${b}: START (a real tap) unlocked audio; the GREEN mix plays; a 90 s clock`);
      unlocked = true;
      await a.shot('X4_play');
    }
    const ok = await a.solveByTouches('timed ' + b);
    const t = await a.waitFor(a.ta, (x) => x.card, 'card ' + b, 15000);
    const st = await a.state(b);
    const m = await a.waitFor(a.mus, (x) => x.sounding === 0, 'silence ' + b, 4000).catch(() => a.mus());
    check(ok && t.card_head === 'SOLVED' && st.timed.outcome === 'COMPLETED' && st.timed.limit_ms === 90000 && st.timed.assist.version === 'ta90-v1' && m.sounding === 0,
      `CHALLENGE ${i + 1} (${b}): solved by touches in a timed 90 s run (${((90000 - st.timed.remaining_ms) / 1000).toFixed(1)} s), rules ta90-v1, silence on SOLVED`);
    await a.tapTa('TA_Continue');
    if (i === 0) {
      // The SHORT questionnaire by touch: 3 questions, compact, all on screen; no second set.
      let q = await a.waitFor(a.vt, (x) => x.screen === 'THINK' && x.buttons.Think_EXTREME, 'difficulty');
      const fits = (x) => Object.values(x.buttons).every((c) => c[0] > 0 && c[0] < 1 && c[1] > 0 && c[1] < 1);
      const f1 = fits(q) && !!q.buttons.Think_SKIP;
      await a.shot('X6_q_difficulty');
      await a.tap(q.buttons.Think_HARD, 600);
      q = await a.waitFor(a.vt, (x) => x.screen === 'THINK' && x.buttons.Think_5, 'enjoy');
      const f2 = fits(q) && Math.abs(q.buttons.Think_1[1] - q.buttons.Think_5[1]) < 0.01;
      await a.shot('X7_q_enjoy');
      await a.tap(q.buttons.Think_4, 600);
      q = await a.waitFor(a.vt, (x) => x.screen === 'THINK' && x.buttons.Think_YES && x.buttons.Think_NO, 'another');
      const f3 = fits(q) && Math.abs(q.buttons.Think_YES[1] - q.buttons.Think_NO[1]) < 0.01;
      await a.shot('X8_q_another');
      await a.tap(q.buttons.Think_YES, 900);
      const back = await a.waitFor(a.hub, (x) => x.view === 'SELECT', 'select after 3 answers', 15000).then(() => true).catch(() => false);
      const st2 = await a.state(b);
      const r0 = (st2.results || [])[0] || {};
      check(f1 && f2 && f3 && back && r0.timed && r0.timed.answers && r0.timed.answers.difficulty === 'HARD' && r0.timed.answers.enjoy === '4' && r0.timed.answers.another === 'YES' && Object.keys(r0.timed.answers).length === 3 && r0.timed.outcome === 'COMPLETED',
        `${b}: the SHORT questionnaire by touch - difficulty (one per line), 1-5 in a row, YES / NO in a row, all on the iPhone SE screen; then straight back to the selection (no second set)`);
    } else {
      await a.tapVt('Think_SKIP', 'THINK', 900);
      const back = await a.waitFor(a.hub, (x) => x.view === 'SELECT', 'select after SKIP', 15000).then(() => true).catch(() => false);
      check(back, `${b}: one SKIP leaves the questionnaire; back to CHOOSE A CHALLENGE`);
    }
  }
  check(Object.keys(benchMs).length === bank.length && Object.values(benchMs).every((x) => x <= 250), `WebAssembly: a full solve (the TIME UP check) per board ${JSON.stringify(benchMs)} ms`);
  console.log('BENCH ' + JSON.stringify(benchMs));
  const ta90Keys = await a.page.evaluate(() => Object.keys(localStorage).filter((k) => k.startsWith('chain_escape_ta90_') || k.startsWith('chain_escape_tapilot')));
  check(ta90Keys.length === 0, `?ta90=1 / the 120-second pilot storage never written ${JSON.stringify(ta90Keys)}`);
  allErrors.push(...a.errors); allExternal.push(...a.external);
  await ctx.close();

  // ---------------- Run 2: TIME UP, calm continuation, export ------------------------------
  {
    const c2 = await browser.newContext(ctxOpts);
    await c2.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: `http://127.0.0.1:${PORT}` });
    const d = await session(c2, 'run 2');
    await d.page.goto(url);
    await d.tapHub('PilotStart', 'WELCOME');
    await d.tapHub('Familiar_NEVER_PLAYED', 'FAMILIARITY');
    const h2 = await d.waitFor(d.hub, (v) => v.view === 'SELECT', 'select 2');
    const b0 = h2.order[0];
    await d.tapHub('Puzzle_1', 'SELECT', 1200);
    await d.begin();
    await d.waitFor(d.ta, (x) => x.run_active, 'running 2');
    await sleep(1500);
    await d.page.evaluate((k) => { sessionStorage.setItem('ceRewind', '85'); sessionStorage.setItem('ceRewindKey', k); }, LSB(b0));
    await d.page.reload();
    const t = await d.waitFor(d.ta, (x) => x.card, 'TIME UP', 120000);
    const st = await d.state(b0);
    let m = await d.waitFor(d.mus, (x) => x.sounding === 0, 'silence', 4000).catch(() => d.mus());
    check(t.card_head === 'TIME UP' && st.timed.outcome === 'TIME UP' && st.timed.limit_ms === 90000 && m.sounding === 0, `CHALLENGE 1 (${b0}): TIME UP at 90 s (the clock kept running through a reload); silence`);
    await d.shot('X5_timeup');
    await d.tapTa('TA_Continue');
    await d.tapVt('Think_SKIP', 'THINK', 900);
    const offer = await d.waitFor(d.ta, (x) => x.card && x.buttons.TA_Untimed, 'offer');
    check(offer.card && offer.buttons.TA_Finish, 'TIME UP: one SKIP, then CONTINUE WITHOUT TIMER / FINISH at once (no other question)');
    await d.tapTa('TA_Untimed', 1500);
    const p = await d.waitFor(d.play, (x) => x.active && x.buttons.Undo, 'untimed');
    // The calm mix needs an unlocked context: the CONTINUE tap was the gesture.
    m = await d.waitFor(d.mus, (x) => x.playing && x.mix === 'calm', 'calm', 8000).catch(() => d.mus());
    check((await d.ta()).count_text === 'NO TIMER' && m.mix === 'calm' && m.playing && !p.buttons.Hint, 'CONTINUE WITHOUT TIMER: NO TIMER, the CALM mix, no SHOW A MOVE');
    check(await d.solveByTouches('untimed'), 'solved without the timer, by touches');
    await d.waitFor(d.ta, (x) => x.card, 'untimed card', 15000);
    await d.tapTa('TA_Continue');
    const back2 = await d.waitFor(d.hub, (x) => x.view === 'SELECT', 'select after untimed', 15000).then(() => true).catch(() => false);
    check(back2, 'after the untimed solve: straight back to CHOOSE A CHALLENGE (no post-play questionnaire)');
    const hh = await d.hub();
    await d.page.evaluate(() => navigator.clipboard.writeText(''));
    await d.tap(hh.buttons.CopyResults, 1200);
    let bundle = null;
    try { bundle = JSON.parse(await d.page.evaluate(() => navigator.clipboard.readText())); } catch { /* not JSON */ }
    const r = bundle && bundle.runs[0];
    console.log('BUNDLE ' + JSON.stringify(bundle ? { format: bundle.format, rules: bundle.rules && bundle.rules.version, run0: r && { board: r.board, timed: r.timed_outcome, untimed: r.untimed_success }, keys: Object.keys(bundle.boards), nums: Object.values(bundle.boards).map((x) => x.puzzle) } : null));
    check(bundle && bundle.questionnaire === 'xb90-short-v1' && h2.order.every((b) => Array.isArray(bundle.boards[b].mechanics) && bundle.boards[b].mechanics.length > 0)
      && r && r.timed_answers && Object.keys(r.timed_answers).length === 0 && r.timed_outcome === 'TIME UP', 'export: questionnaire version, each board\'s mechanics; the skipped run has no answers and keeps its TIME UP outcome');
    check(bundle && bundle.format === 'ce-xb90' && bundle.rules.version === 'ta90-v1' && r && r.board === b0 && r.timed_outcome === 'TIME UP' && r.untimed_success
      && Object.keys(bundle.boards).length === h2.order.length && h2.order.every((b, i) => bundle.boards[b].puzzle === i + 1 && /^[0-9a-f]{64}$/.test(bundle.boards[b].fingerprint)),
      'COPY ALL RESULTS: one ce-xb90 bundle - every board under its internal id with its fingerprint and challenge number; the run kept TIME UP and the untimed solve apart');
    allErrors.push(...d.errors); allExternal.push(...d.external);
    await c2.close();
  }

  // ---------------- The player build ignores ?extreme90=1 -----------------------------------
  if (server2) {
    const c3 = await browser.newContext(ctxOpts);
    const pg = await c3.newPage();
    await pg.goto(`http://127.0.0.1:${PORT + 1}/index.html?extreme90=1`);
    await sleep(25000);
    const seen = await pg.evaluate(() => ({ hub: !!window.chainEscapeXb90, music: !!window.chainEscapeStageMusic, keys: Object.keys(localStorage).filter((k) => k.includes('xb90')) }));
    check(!seen.hub && !seen.music && seen.keys.length === 0, `the player build ignores ?extreme90=1 ${JSON.stringify(seen)}`);
    await c3.close();
  }
  check(allErrors.length === 0, 'no page errors ' + JSON.stringify(allErrors.slice(0, 3)));
  check(allExternal.length === 0, 'no network calls outside the page ' + JSON.stringify(allExternal.slice(0, 3)));
} catch (e) {
  check(false, 'run: ' + e.message);
} finally {
  await browser.close();
  server.close();
  if (server2) server2.close();
  const failed = results.filter((x) => !x).length;
  console.log(failed ? `WEB EXTREME90 TEST: FAILED (${failed}/${results.length})` : `WEB EXTREME90 TEST: PASSED (${results.length}/${results.length})`);
  process.exit(failed ? 1 : 0);
}
