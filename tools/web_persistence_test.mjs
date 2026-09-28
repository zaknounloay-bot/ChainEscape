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
  if (rel === '/blank') { res.writeHead(200, { 'Content-Type': 'text/html' }); res.end('<!doctype html><title>blank</title>'); return; }
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
  res.end(`<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="margin:0;background:#222">
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
  throw new Error(`timeout waiting for ${what} (last state: ${JSON.stringify(s && { level: s.level, card: s.card_open, title: s.title_open, chapter_card: s.chapter_card_open, select: s.select_open, settings: s.settings_open, recovery: s.recovery_open })})`);
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

// A page that is already open (a new tab, or after goto): wait for the game.
async function attach(page) {
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  let frame = null;
  for (let i = 0; i < 240 && !frame; i++) {
    const f = gameFrame(page);
    if (await f.evaluate(() => !!window.chainEscapeState).catch(() => false)) frame = f;
    else await page.waitForTimeout(500);
  }
  if (!frame) throw new Error('game did not start in ' + page.url());
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
  let ctx, g, st;
  if (!process.env.IOS_ONLY) {
  // ===== itch-like embed, persistent profile: A, B, C, D ======================
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-profile-'));
  ctx = await chromium.launchPersistentContext(profile, { ...LAUNCH, ...VIEW });
  g = await openGame(ctx, true);
  st = await state(g.frame);
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
  }

  // ===== G (v0.6): a continuous Second Era session ============================
  // Starts from a save that has cleared Level 100 (as a returning v0.5.2
  // player would), then plays 101 -> 140 in one page: switches, gates,
  // the Neon Glass / Industrial themes and music, memory sampled per level.
  {
    const profileG = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-profile-'));
    let lines = ['[meta]', '', 'version=4', 'seq=5', '', '[progress]', '', 'current_level=100', 'highest_completed=100',
      'highest_unlocked=101', '', '[scores]', ''];
    for (let n = 1; n <= 100; n++) lines.push(`${n}=5000`);
    lines.push('', '[stars]', '');
    for (let n = 1; n <= 100; n++) lines.push(`${n}=3`);
    lines.push('', '[economy]', '', 'coins=777', '');
    const saveText = lines.join('\n');
    ctx = await chromium.launchPersistentContext(profileG, { ...LAUNCH, ...VIEW });
    await ctx.addInitScript((t) => { try { if (!localStorage.getItem('chain_escape_save')) localStorage.setItem('chain_escape_save', t); } catch (e) {} }, saveText);
    g = await openGame(ctx, false);
    st = await waitFor(g.frame, (x) => x.title_open, 'title');
    check(st.continue_text === 'CONTINUE  -  LEVEL 101' && st.highest_unlocked === 101 && st.coins === 777,
      `G: a save that cleared Level 100 continues at 101 ('${st.continue_text}', unlocked ${st.highest_unlocked}, coins ${st.coins})`);
    await enterGame(g);
    await toggleDebug(g);
    const eraTrack = { total: 0, mem: [], chapters: [], chapterCards: 0 };
    const endG = QUICK ? 106 : 140;
    st = await playTo(g, endG, eraTrack);
    await notReloaded(g, `G: continuous Second Era session 101-${endG}`);
    check(st.level === endG && st.music === (endG > 130 ? 'c14' : (endG > 120 ? 'c13' : (endG > 110 ? 'c12' : 'c11'))),
      `G: reached level ${endG} with its Chapter's music (${st.music})`);
    const em = eraTrack.mem;
    if (em.length > 2) {
      info(`G memory: level ${em[0][0]} wasm ${em[0][1]} MB / js ${em[0][2]} MB -> level ${em[em.length - 1][0]} wasm ${em[em.length - 1][1]} MB / js ${em[em.length - 1][2]} MB`);
      check(em[em.length - 1][1] - em[0][1] <= 64, `G: WebAssembly heap bounded in the Second Era (+${em[em.length - 1][1] - em[0][1]} MB)`);
    }
    await ctx.close();
    fs.rmSync(profileG, { recursive: true, force: true });
  }

  // ===== iPhone acceptance flow (iPhone user agent, v0.5.2) ====================
  // Safari gives the itch.io embed partitioned, EPHEMERAL storage, separate
  // from the game's own tab. Chromium partitions the embed the same way
  // (third-party storage partitioning), so the embed and the standalone tab
  // really are two different storage buckets here too. What Chromium can't
  // do is erase the embed on close - the gate makes that irrelevant: on
  // WebKit-in-an-embed nothing is played there before the player chooses.
  const IPHONE_UA = 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
  const IOS = { ...LAUNCH, ...VIEW, userAgent: IPHONE_UA };
  const profile3 = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-profile-'));
  ctx = await chromium.launchPersistentContext(profile3, IOS);
  g = await openGame(ctx, true);
  await waitFor(g.frame, (x) => x.title_open, 'title');
  await g.page.waitForTimeout(500);
  const gate = async (fr) => fr.evaluate(() => { const e = document.getElementById('ce-gate'); return !!e && e.style.display !== 'none'; });
  const s3 = await g.frame.evaluate(() => window.ceAudio.storage());
  check(s3.ephemeral && s3.context === 'embed-ephemeral' && await gate(g.frame), `iPhone in the itch.io embed: context ${s3.context}, the "open in Safari" gate is shown before play`);
  // The gate blocks the game: a tap on CONTINUE does nothing.
  st = await state(g.frame);
  await tapN(g.page, g.frame, st.title_continue);
  await g.page.waitForTimeout(600);
  check((await state(g.frame)).title_open, 'gate: taps never reach the game underneath');
  // "Play here without saving" (explicit), a few levels, then the red pill.
  await g.frame.click('#ce-gate-here');
  check(!(await gate(g.frame)) && await g.frame.evaluate(() => !!document.getElementById('ce-unsaved')), 'Play here without saving: gate closes, a NOT SAVED pill stays visible');
  await enterGame(g);
  await toggleDebug(g);
  const iosTrack = { total: 0, mem: [], chapters: [], chapterCards: 0 };
  await playTo(g, 4, iosTrack);
  const embedTotal = (await state(g.frame)).total_score;
  // OPEN IN SAFARI from the pill: a new first-party tab, with the embed's progress handed over.
  let [tab] = await Promise.all([ctx.waitForEvent('page'), g.frame.click('#ce-unsaved')]);
  let tg = await attach(tab);
  st = await waitFor(tg.frame, (x) => x.title_open, 'standalone title');
  const s4 = await tg.frame.evaluate(() => window.ceAudio.storage());
  check(s4.context === 'standalone' && !s4.ephemeral && !(await gate(tg.frame)) && !tab.url().includes('ce_transfer'),
    `OPEN IN SAFARI: standalone tab (context ${s4.context}), no gate, transfer data removed from the address`);
  check(st.highest_completed === 3 && st.total_score === embedTotal && st.continue_text === 'CONTINUE  -  LEVEL 4',
    `embed progress transferred to the standalone tab (${st.continue_text}, total ${st.total_score})`);
  await g.page.close();
  // Real acceptance test: play to N in the tab, close Safari, reopen the PUBLIC itch link.
  const targets = QUICK ? [20] : [20, 45, 100];
  let backupCode = '';
  for (const target of targets) {
    await enterGame(tg);
    await toggleDebug(tg);
    await playTo(tg, target, iosTrack);
    if (target === 100) {
      // Level 100 is the last: clear it too, so all 100 are completed.
      await tg.page.keyboard.press('s');
      await waitFor(tg.frame, (x) => x.card_open && x.level === 100, 'level 100 cleared');
    }
    await toggleDebug(tg);  // close the debug panel (it covers the Level Select button)
    const before = await snapshot(tg.frame);
    // v0.6: clearing 100 unlocks the Second Era (101).
    const unlocked = target === 100 ? 101 : target;
    if (target < 100) {
      await tapN(tg.page, tg.frame, (await state(tg.frame)).levels_button);
      st = await waitFor(tg.frame, (x) => x.select_open, 'level select');
      check(st.select_unlocked === unlocked, `L${target}: Level Select shows 1-${unlocked} unlocked before closing (${st.select_unlocked})`);
    }
    await tg.page.waitForTimeout(1500);
    await ctx.close();  // close Safari completely
    ctx = await chromium.launchPersistentContext(profile3, IOS);
    // Reopen the SAME public itch.io link: the gate again (the embed never holds progress) ...
    g = await openGame(ctx, true);
    check(await gate(g.frame), `L${target}: reopening the public itch.io link shows the gate`);
    [tab] = await Promise.all([ctx.waitForEvent('page'), g.frame.click('#ce-gate-open')]);
    tg = await attach(tab);
    st = await waitFor(tg.frame, (x) => x.title_open, 'standalone title');
    const after = await snapshot(tg.frame);
    const expect = `CONTINUE  -  LEVEL ${target}`;
    check(st.continue_text === expect && after.highest_unlocked >= unlocked,
      `L${target}: one tap on OPEN GAME IN SAFARI -> progress restored ('${st.continue_text}', unlocked ${after.highest_unlocked}, source ${st.save_source})`);
    check(after.total === before.total && after.coins === before.coins && after.stars === before.stars,
      `L${target}: TOTAL SCORE ${after.total} (was ${before.total}), coins and stars unchanged after closing Safari`);
    check(st.save_diag.includes(`UNLOCKED ${Math.min(after.highest_unlocked, 200)}`) && st.save_diag.includes('STANDALONE') && !st.writes_held,
      `L${target}: title diagnostic '${st.save_diag}'`);
    await g.page.close();
    await enterGame(tg);
    if (target === targets[0]) {
      // Backup code from Settings (native dialog with the code).
      await tapN(tg.page, tg.frame, st.settings_button);
      st = await waitFor(tg.frame, (x) => x.settings_open, 'settings');
      await tapN(tg.page, tg.frame, st.backup_button);
      await tg.frame.waitForSelector('#ce-backup-text', { timeout: 10000 });
      backupCode = await tg.frame.$eval('#ce-backup-text', (e) => e.value);
      await tg.frame.click('#ce-backup-close');
      check(/^CE1-[A-Za-z0-9_-]{40,}$/.test(backupCode), `Settings > BACKUP CODE shows a code (${backupCode.length} chars)`);
      await tg.page.waitForTimeout(500);
    }
    await tapN(tg.page, tg.frame, (await state(tg.frame)).levels_button);
    st = await waitFor(tg.frame, (x) => x.select_open, 'level select');
    check(st.select_unlocked === unlocked, `L${target}: after reopening, Level Select shows 1-${unlocked} unlocked (${st.select_unlocked})`);
    // Back to a fresh title for the next round (a reload of the tab).
    await tg.page.reload();
    tg = await attach(tg.page);
  }

  // Recovery safety: the save disappears (site data cleared) but its beacon survives.
  const goodTotal = (await state(tg.frame)).total_score;
  const goodLevel = (await state(tg.frame)).last_played;
  await tg.page.waitForTimeout(2500);  // let the last IndexedDB sync land
  await tg.page.goto('http://127.0.0.1:8765/blank');
  await tg.page.evaluate(async () => {
    localStorage.removeItem('chain_escape_save');
    const db = await new Promise((r) => { const q = indexedDB.open('/userfs'); q.onsuccess = () => r(q.result); });
    const store = db.transaction('FILE_DATA', 'readwrite').objectStore('FILE_DATA');
    const keys = await new Promise((r) => { const q = store.getAllKeys(); q.onsuccess = () => r(q.result); });
    for (const k of keys) if (/progress\.cfg(\.bak|\.tmp)?$/.test(k)) store.delete(k);
    await new Promise((r) => { store.transaction.oncomplete = r; });
    db.close();
  });
  await tg.page.goto(GAME_URL);
  tg = await attach(tg.page);
  st = await waitFor(tg.frame, (x) => x.title_open, 'title after data loss');
  await tg.page.waitForTimeout(800);
  st = await state(tg.frame);
  check(st.recovery_open && st.writes_held && st.save_source === 'missing',
    `save missing but beacon found: recovery screen, writes held (source ${st.save_source})`);
  const idbHasSave = await tg.frame.evaluate(async () => {
    const db = await new Promise((r) => { const q = indexedDB.open('/userfs'); q.onsuccess = () => r(q.result); });
    const keys = await new Promise((r) => { const q = db.transaction('FILE_DATA').objectStore('FILE_DATA').getAllKeys(); q.onsuccess = () => r(q.result); });
    db.close();
    return keys.some((k) => /progress\.cfg$/.test(k)) || !!localStorage.getItem('chain_escape_save');
  });
  check(!idbHasSave, 'nothing blank was written over the missing save while the choice is pending');
  // RESTORE FROM BACKUP CODE on the recovery screen.
  await tapN(tg.page, tg.frame, st.recovery_restore);
  await tg.frame.waitForSelector('#ce-backup-text', { timeout: 10000 });
  await tg.frame.fill('#ce-backup-text', backupCode);
  await tg.frame.click('#ce-backup-main');
  st = await waitFor(tg.frame, (x) => !x.writes_held && !x.recovery_open && x.highest_completed >= targets[0] - 1, 'restored');
  check(st.total_score >= (targets.length === 1 ? goodTotal : 1) && st.highest_unlocked >= targets[0],
    `RESTORE FROM BACKUP CODE: progress back (unlocked ${st.highest_unlocked}, total ${st.total_score}; code made at level ${targets[0]}, last good level ${goodLevel})`);
  await ctx.close();
  fs.rmSync(profile3, { recursive: true, force: true });

  // Android / desktop Chrome in the embed: no gate (storage there is kept).
  const browser = await chromium.launch(LAUNCH);
  const c = await browser.newContext(VIEW);
  g = await openGame(c, true);
  await waitFor(g.frame, (x) => x.title_open, 'title');
  check(!(await gate(g.frame)) && !(await g.frame.evaluate(() => window.ceAudio.storage())).ephemeral, 'Chrome in the embed: no gate (its storage is kept)');
  await c.close();
  await browser.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
gameServer.close();
hostServer.close();
const failed = results.filter((r) => !r[0]).length;
console.log(failed === 0 ? `WEB PERSISTENCE TEST PASSED (${results.length} checks)` : `WEB PERSISTENCE TEST FAILED (${failed} of ${results.length})`);
process.exit(failed === 0 ? 0 : 1);
