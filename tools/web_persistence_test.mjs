// Web persistence + long-session test (v0.5.1): the exported game in real
// Chromium, played like a player, with the browser really closed and
// reopened.
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_persistence_test.mjs            (Node + Playwright + Chromium)
//   QUICK=1 node tools/web_persistence_test.mjs    (shorter long-session run)
//
// itch.io-like hosting: the game is served from http://127.0.0.1:8765 and
// embedded in a CROSS-ORIGIN iframe on http://localhost:8766, like itch.io
// (itch.io page + game iframe on itch.zone). A persistent browser profile
// is used, so closing and relaunching the browser is real.
//
// Levels are played with the game's own debug auto-solve (F1, then S),
// then the real NEXT / CONTINUE buttons are tapped at the positions the
// game publishes (window.chainEscapeState, read-only).
//
//   A  play to Level 12, close the BROWSER, reopen: CONTINUE - LEVEL 12
//   B  play on to Level 45, close the TAB, reopen: Level Select shows 1-45
//      unlocked (46+ locked)
//   C  coins, stars, inventory, total score identical after every reload
//   D  Total Score never decreases, across levels and reloads
//   E  continuous Level 1 -> 60 in one page, no crash / reload / error
//   F  continuous Level 40 -> 70 (same run), Chapter music/theme changes
//   +  iOS-Safari detection: in a cross-origin iframe with an iPhone user
//      agent the game reports ephemeral storage and shows the "open the
//      game in its own tab" notice; first-party it does not
//   +  WebAssembly / JS heap sampled every level (leak check)
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
const QUICK = !!process.env.QUICK;

const root = path.resolve(process.argv[2] || 'build/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const gameServer = http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(root, rel === '/' ? 'index.html' : rel);
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8765, '127.0.0.1');
const GAME_URL = 'http://127.0.0.1:8765/index.html';
const hostServer = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`<!doctype html><html><body style="margin:0;background:#222">
<iframe id="game" src="${GAME_URL}" style="border:0;width:100vw;height:100vh;display:block"
 allow="autoplay; fullscreen; gamepad" allowfullscreen></iframe></body></html>`);
}).listen(8766, 'localhost');
const HOST_URL = 'http://localhost:8766/itch-like.html';

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const info = (msg) => console.log('INFO ' + msg);

const VIEW = { viewport: { width: 412, height: 915 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true };
const LAUNCH = {
  channel: 'chromium', headless: !process.env.HEADED,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
};

// --- helpers ------------------------------------------------------------------

function gameFrame(page) {
  return page.frames().find((f) => f.url().startsWith(GAME_URL)) || page.mainFrame();
}

async function state(frame) {
  try { return await frame.evaluate(() => window.chainEscapeState || null); } catch { return null; }
}

async function waitFor(frame, pred, what, ms = 90000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(frame);
    if (s && pred(s)) return s;
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error(`timeout waiting for ${what} (last state: ${JSON.stringify(s && { level: s.level, card: s.card_open, title: s.title_open })})`);
}

// Taps a normalized (0..1) position inside the game frame.
async function tapN(page, frame, pos) {
  let ox = 0, oy = 0, w = VIEW.viewport.width, h = VIEW.viewport.height;
  if (frame !== page.mainFrame()) {
    const box = await (await frame.frameElement()).boundingBox();
    ox = box.x; oy = box.y; w = box.width; h = box.height;
  }
  await page.touchscreen.tap(ox + pos[0] * w, oy + pos[1] * h);
}

async function openGame(context, embedded) {
  const page = context.pages()[0] || await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error' && !/favicon/.test(m.text())) errors.push(m.text()); });
  await page.goto(embedded ? HOST_URL : GAME_URL);
  let frame = null;
  for (let i = 0; i < 240 && !frame; i++) {
    const f = gameFrame(page);
    if (await f.evaluate(() => !!window.chainEscapeState).catch(() => false)) frame = f;
    else await page.waitForTimeout(500);
  }
  if (!frame) throw new Error('game did not start');
  await frame.evaluate(() => { window.__ceBoot = window.__ceBoot || Date.now(); });
  return { page, frame, errors };
}

// Title -> CONTINUE / PLAY (also the first gesture that unlocks audio).
async function enterGame(g) {
  const s = await waitFor(g.frame, (x) => x.title_open, 'title');
  await tapN(g.page, g.frame, s.title_continue);
  await waitFor(g.frame, (x) => !x.title_open, 'title closed');
  await g.page.waitForTimeout(400);
}

async function toggleDebug(g) {
  await g.page.keyboard.press('F1');
  await g.page.waitForTimeout(300);
}

// Plays level by level with the debug auto-solve and the real NEXT /
// Chapter CONTINUE buttons, from the current level up to `to` (the level
// the player is standing on at the end). Tracks the total score and memory.
async function playTo(g, to, track) {
  let s = await state(g.frame);
  while (s.level < to) {
    const n = s.level;
    await g.page.keyboard.press('s');
    s = await waitFor(g.frame, (x) => x.card_open && x.level === n, `level ${n} cleared`);
    if (s.total_score < track.total) check(false, `D: total score dropped at level ${n} (${track.total} -> ${s.total_score})`);
    track.total = Math.max(track.total, s.total_score);
    await g.page.waitForTimeout(300);
    await tapN(g.page, g.frame, s.next);
    await g.page.waitForTimeout(700);
    let t = await state(g.frame);
    if (t.chapter_card_open) {
      track.chapterCards++;
      await tapN(g.page, g.frame, t.chapter_continue);
    }
    s = await waitFor(g.frame, (x) => x.level === n + 1 && !x.card_open && !x.chapter_card_open, `level ${n + 1} started`);
    if (s.chapter !== t.chapter) track.chapters.push(`${n}->${n + 1}:${s.music}`);
    const mem = await g.frame.evaluate(() => window.ceAudio.memory());
    track.mem.push([n + 1, mem.wasm, mem.js]);
    if ((n + 1) % 10 === 0) info(`level ${n + 1}: total ${s.total_score}, coins ${s.coins}, wasm ${mem.wasm} MB, js ${mem.js} MB, save #${s.save_seq}`);
  }
  return s;
}

async function snapshot(frame) {
  const s = await state(frame);
  return { level: s.last_played, highest_completed: s.highest_completed, highest_unlocked: s.highest_unlocked,
    coins: s.coins, stars: s.stars, total: s.total_score, inventory: JSON.stringify(s.inventory) };
}

async function notReloaded(g, label) {
  const boot = await g.frame.evaluate(() => window.__ceBoot);
  check(!!boot && g.errors.length === 0, `${label}: no reload, no page errors${g.errors.length ? ' (' + g.errors.slice(0, 3).join(' | ') + ')' : ''}`);
}

// --- run -------------------------------------------------------------------------

const track = { total: 0, mem: [], chapters: [], chapterCards: 0 };
try {
  // ===== itch-like embed, persistent profile: A, B, C, D ======================
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-profile-'));
  let ctx = await chromium.launchPersistentContext(profile, { ...LAUNCH, ...VIEW });
  let g = await openGame(ctx, true);
  let st = await state(g.frame);
  check(st.title_open && st.continue_text === 'PLAY' && st.highest_unlocked === 1, 'fresh profile: title offers PLAY, only level 1 unlocked');
  const storage = await g.frame.evaluate(() => window.ceAudio.storage());
  info(`embedded storage: ${JSON.stringify(storage)}`);
  check(storage.iframe && storage.crossOrigin && storage.localStorage && !storage.ephemeral, 'embed: cross-origin iframe, localStorage works, not ephemeral (Chromium)');
  await enterGame(g);
  await toggleDebug(g);
  await playTo(g, QUICK ? 6 : 12, track);
  const beforeA = await snapshot(g.frame);
  await notReloaded(g, 'A session');
  await ctx.close();  // close the whole browser
  ctx = await chromium.launchPersistentContext(profile, { ...LAUNCH, ...VIEW });
  g = await openGame(ctx, true);
  st = await state(g.frame);
  const expA = QUICK ? 6 : 12;
  check(st.title_open && st.continue_text === `CONTINUE  -  LEVEL ${expA}`, `A: after closing the browser the title offers CONTINUE - LEVEL ${expA} ('${st.continue_text}', loaded from ${st.save_source})`);
  const afterA = await snapshot(g.frame);
  check(JSON.stringify(afterA) === JSON.stringify(beforeA), `C: coins, stars, inventory, total score identical after browser restart (${JSON.stringify(afterA)})`);
  check(afterA.total >= track.total, `D: total score kept after restart (${afterA.total})`);
  await enterGame(g);
  await toggleDebug(g);
  await playTo(g, QUICK ? 14 : 45, track);
  const beforeB = await snapshot(g.frame);
  await notReloaded(g, 'B session');
  // Close the TAB (the browser stays open), then open the game again.
  const oldPage = g.page;
  const fresh = await ctx.newPage();
  await oldPage.close();
  g = await openGame(ctx, true);
  st = await state(g.frame);
  const expB = QUICK ? 14 : 45;
  check(st.continue_text === `CONTINUE  -  LEVEL ${expB}`, `B: after closing the tab the title offers CONTINUE - LEVEL ${expB} ('${st.continue_text}')`);
  const afterB = await snapshot(g.frame);
  check(JSON.stringify(afterB) === JSON.stringify(beforeB), 'C: coins, stars, inventory, total score identical after closing the tab');
  await enterGame(g);
  await tapN(g.page, g.frame, st.levels_button);
  st = await waitFor(g.frame, (x) => x.select_open, 'level select');
  check(st.select_max_unlocked >= expB && st.select_locked_first === expB + 1 && st.select_unlocked === expB,
    `B: Level Select shows 1-${expB} unlocked, ${expB + 1}+ locked (unlocked ${st.select_unlocked}, first locked ${st.select_locked_first})`);
  // D once more: complete another level after the reloads.
  await g.page.keyboard.press('Escape');
  await ctx.close();
  ctx = await chromium.launchPersistentContext(profile, { ...LAUNCH, ...VIEW });
  g = await openGame(ctx, true);
  await enterGame(g);
  const t0 = (await state(g.frame)).total_score;
  await toggleDebug(g);
  await playTo(g, expB + 1, track);
  const t1 = (await state(g.frame)).total_score;
  check(t1 >= t0, `D: completing another level after reopening never lowers the total (${t0} -> ${t1})`);
  await ctx.close();
  fs.rmSync(profile, { recursive: true, force: true });
  void fresh;

  // ===== E + F: one continuous session, level 1 -> 70, no reload ===============
  const profile2 = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-profile-'));
  ctx = await chromium.launchPersistentContext(profile2, { ...LAUNCH, ...VIEW });
  g = await openGame(ctx, false);
  await enterGame(g);
  await toggleDebug(g);
  const longTrack = { total: 0, mem: [], chapters: [], chapterCards: 0 };
  const end = QUICK ? 22 : 70;
  const t = Date.now();
  st = await playTo(g, end, longTrack);
  await notReloaded(g, `E/F: continuous 1-${end}`);
  check(st.level === end && st.highest_completed === end - 1, `E: reached level ${end} in one continuous session (${Math.round((Date.now() - t) / 1000)} s)`);
  check(longTrack.chapters.length === Math.floor((end - 1) / 10), `F: every Chapter boundary changed theme/music (${longTrack.chapters.join(', ')})`);
  check(longTrack.chapterCards === Math.floor((end - 1) / 10), `F: a Chapter Complete card at each boundary (${longTrack.chapterCards})`);
  const m = longTrack.mem;
  const early = m.find((x) => x[0] >= 11) || m[0];
  const late = m[m.length - 1];
  info(`memory: level ${early[0]} wasm ${early[1]} MB / js ${early[2]} MB -> level ${late[0]} wasm ${late[1]} MB / js ${late[2]} MB`);
  check(late[1] - early[1] <= 64, `E: WebAssembly heap stays bounded over the session (+${late[1] - early[1]} MB)`);
  await ctx.close();
  fs.rmSync(profile2, { recursive: true, force: true });

  // ===== iOS Safari detection (user-agent spoof) ===============================
  const IPHONE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
  const browser = await chromium.launch(LAUNCH);
  for (const embedded of [true, false]) {
    const c = await browser.newContext({ ...VIEW, userAgent: IPHONE_UA });
    g = await openGame(c, embedded);
    await waitFor(g.frame, (x) => x.title_open, 'title');
    await g.page.waitForTimeout(500);
    const s2 = await g.frame.evaluate(() => window.ceAudio.storage());
    const shown = await g.frame.evaluate(() => { const e = document.getElementById('ce-save-notice'); return !!e && e.style.display !== 'none'; });
    if (embedded) check(s2.ephemeral && shown, `iPhone UA in a cross-origin iframe: storage reported ephemeral and the "open in its own tab" notice is shown`);
    else check(!s2.ephemeral && !shown, 'iPhone UA first-party: storage persistent, no notice');
    await c.close();
  }
  await browser.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
gameServer.close();
hostServer.close();
const failed = results.filter((r) => !r[0]).length;
console.log(failed === 0 ? `WEB PERSISTENCE TEST PASSED (${results.length} checks)` : `WEB PERSISTENCE TEST FAILED (${failed} of ${results.length})`);
process.exit(failed === 0 ? 0 : 1);
