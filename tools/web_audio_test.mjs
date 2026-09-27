// Real-browser checks of the Web audio unlock (tools/web_audio_test.mjs).
//
//   python3 tools/sync_web_head.py            (if web/audio_unlock.js changed)
//   godot --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_audio_test.mjs             (Node + Playwright + Chromium)
//
// Runs the exported game in Chromium under the strict autoplay policy
// (document-user-activation-required). The game has no test hooks: the
// test only taps the screen, reads window.chainEscapeAudio (published by
// AudioManager) and measures the REAL output signal with an analyser
// tapped onto the audio destination. Per case it checks:
//   * nothing plays before the first gesture (output silent, music off,
//     no SFX, audio not unlocked)
//   * one tap/click unlocks: the page-level unlock (web/audio_unlock.js)
//     resumes the engine's AudioContext inside the gesture, Godot sees it
//     "running", THEN starts music (if ON) and allows SFX (if ON)
//   * music really reaches the output; SFX really reach it when ON
//   * later taps never restart the music
//   * no temporary debug remains (no console logging, no test hooks)
// Cases: mobile (touch) first visit, returning player with Music ON,
// Music OFF and SFX OFF (set by editing the real save file in IndexedDB,
// then reloading), an iOS-like context that starts suspended, and desktop
// mouse (Chrome; Edge uses the same Chromium engine). iOS Safari itself
// cannot run here - see README for the iPhone checklist.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const { chromium } = pw;

const root = path.resolve(process.argv[2] || 'build/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split('?')[0]);
  const file = path.join(root, rel === '/' ? 'index.html' : rel);
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404, { 'Content-Type': 'text/html' }); res.end('<html></html>'); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8765);

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };

const browser = await chromium.launch({
  channel: 'chromium',
  headless: !process.env.HEADED,
  // Playwright disables the autoplay rule by default; restore a strict one.
  ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'],
  args: ['--autoplay-policy=document-user-activation-required', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});

// Pixel density 1: this build machine renders with a software GPU, where a
// 2x canvas drops to ~8 fps and starves Godot's main-thread (Stream) mixer.
// The unlock logic does not depend on pixel density.
const MOBILE = {
  viewport: { width: 412, height: 915 }, deviceScaleFactor: 1, isMobile: true, hasTouch: true,
  userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
};
const DESKTOP = { viewport: { width: 1280, height: 800 } };
const ORIGIN = 'http://localhost:8765';
const GAME = ORIGIN + '/index.html';
const SAVE_KEY = '/userfs/godot/app_userdata/Chain Escape/progress.cfg';

// Taps everything the engine sends to the speakers into an AnalyserNode and
// keeps the running maximum, so even a 40 ms UI click is caught.
function signalProbe() {
  const origConnect = AudioNode.prototype.connect;
  const probes = new Map();
  window.__maxPeak = 0;
  AudioNode.prototype.connect = function (target, ...rest) {
    const r = origConnect.call(this, target, ...rest);
    if (target instanceof AudioDestinationNode) {
      const ctx = this.context;
      let a = probes.get(ctx);
      if (!a) {
        a = ctx.createAnalyser();
        a.fftSize = 2048;
        const mute = ctx.createGain();
        mute.gain.value = 0;
        origConnect.call(a, mute);
        origConnect.call(mute, ctx.destination);
        probes.set(ctx, a);
      }
      origConnect.call(this, a);
    }
    return r;
  };
  const buf = new Float32Array(2048);
  window.__sample = () => {
    for (const a of probes.values()) {
      a.getFloatTimeDomainData(buf);
      for (const v of buf) if (Math.abs(v) > window.__maxPeak) window.__maxPeak = Math.abs(v);
    }
    return window.__maxPeak;
  };
  window.__consoleCE = 0;
  const log = console.log;
  console.log = function (...args) {
    if (String(args[0]).startsWith('[CE-Audio]')) window.__consoleCE++;
    return log.apply(this, args);
  };
}

// Peak over a window of `ms` milliseconds (the analyser is sampled every
// 50 ms; each sample covers the last ~46 ms of output).
async function peakDuring(page, ms) {
  await page.evaluate(() => { window.__maxPeak = 0; });
  const end = Date.now() + ms;
  while (Date.now() < end) {
    await page.evaluate(() => window.__sample());
    await page.waitForTimeout(50);
  }
  return page.evaluate(() => window.__sample());
}

async function state(page) {
  return page.evaluate(() => ({
    g: window.chainEscapeAudio || null,
    ctx: window.ceAudio ? window.ceAudio.state() : 'no-bridge',
    info: window.ceAudio && window.ceAudio.info ? window.ceAudio.info() : null,
    hooks: typeof window.ceSetSetting + '/' + (window.ceAudio ? typeof window.ceAudio.testTone : 'none'),
    ceLogs: window.__consoleCE,
  }));
}

async function load(page) {
  await page.goto(GAME);
  await page.waitForFunction(() => window.chainEscapeAudio !== undefined, null, { timeout: 120000 });
  await page.waitForTimeout(1200);
}

// Canvas layout: 720x1280 base, stretch "expand" -> map canvas to screen.
function toScreen(vp, cx, cy, fromBottom = false) {
  const scale = Math.min(vp.width / 720, vp.height / 1280);
  const W = vp.width / scale;
  const H = vp.height / scale;
  const x = W / 2 + (cx - 360);
  const y = fromBottom ? H - cy : cy;
  return [x * scale, y * scale];
}

async function tapAt(page, mobile, x, y) {
  if (mobile) await page.touchscreen.tap(x, y);
  else await page.mouse.click(x, y);
}

// The title's PLAY / CONTINUE button (first gesture), then any later tap.
async function tapTitle(page, mobile, vp) {
  await tapAt(page, mobile, vp.width / 2, Math.round(vp.height * 0.57));
}

// RESTART in the bottom bar: always plays the UI click sound.
async function tapRestart(page, mobile, vp) {
  const [x, y] = toScreen(vp, 606, 108, true);
  await tapAt(page, mobile, x, y);
}

async function scenario(page, label, { mobile, vp, musicOn, sfxOn, expectSuspended = false }) {
  let s = await state(page);
  check(s.ctx !== 'no-bridge', `${label}: page-level unlock script (ceAudio) is present`);
  check(s.hooks === 'undefined/undefined', `${label}: no temporary test hooks left (ceSetSetting / testTone)`);
  check(s.g.unlocked === false && s.g.musicPlaying === false && s.g.sfxPlayed === 0, `${label}: nothing unlocked or played before the first gesture`);
  check(s.g.musicEnabled === musicOn && s.g.sfxEnabled === sfxOn, `${label}: saved settings restored (music ${musicOn ? 'ON' : 'OFF'}, sfx ${sfxOn ? 'ON' : 'OFF'})`);
  if (expectSuspended) check(s.ctx === 'suspended', `${label}: AudioContext starts suspended (${s.ctx})`);
  const before = await peakDuring(page, 1000);
  check(before === 0, `${label}: output is silent before the first gesture (peak ${before.toFixed(4)})`);
  await tapTitle(page, mobile, vp);
  await page.waitForTimeout(2500);
  s = await state(page);
  check(s.ctx === 'running', `${label}: AudioContext running after the gesture (${s.ctx})`);
  check(s.g.unlocked === true, `${label}: Godot unlocked audio after the gesture`);
  if (expectSuspended) check(s.info.unlockAttempts >= 1, `${label}: resume() was called inside the gesture (${s.info.unlockAttempts} attempts)`);
  check(s.g.musicPlaying === musicOn, `${label}: music ${musicOn ? 'playing' : 'NOT playing (Music OFF)'}`);
  const musicPeak = await peakDuring(page, 1500);
  if (musicOn) check(musicPeak > 0.005, `${label}: music signal reaches the output (peak ${musicPeak.toFixed(4)})`);
  else check(musicPeak === 0, `${label}: output silent with Music OFF (peak ${musicPeak.toFixed(4)})`);
  // Later taps: nothing restarts. The music position keeps running.
  const pos0 = (await state(page)).g.musicPos;
  await tapTitle(page, mobile, vp);
  await page.waitForTimeout(600);
  s = await state(page);
  const wrapped = s.g.musicPos < pos0 && pos0 > 12;
  check(s.g.unlocked && s.g.musicPlaying === musicOn && (!musicOn || s.g.musicPos > pos0 || wrapped),
    `${label}: later taps never restart the music (pos ${pos0.toFixed(2)} -> ${s.g.musicPos.toFixed(2)})`);
  // SFX: RESTART plays the UI click.
  const sfxBefore = s.g.sfxPlayed;
  await tapRestart(page, mobile, vp);
  const sfxPeak = await peakDuring(page, 900);
  s = await state(page);
  if (sfxOn) {
    check(s.g.sfxPlayed > sfxBefore, `${label}: sound effect played after unlock (${sfxBefore} -> ${s.g.sfxPlayed})`);
    if (!musicOn) check(sfxPeak > 0.003, `${label}: SFX signal reaches the output with music off (peak ${sfxPeak.toFixed(4)})`);
  } else {
    check(s.g.sfxPlayed === 0, `${label}: no SFX with Sound Effects OFF`);
  }
  check(s.ceLogs === 0, `${label}: no [CE-Audio] debug logging (${s.ceLogs} lines)`);
  return s;
}

// Edits the real save file in IndexedDB (settings), from a same-origin page
// where the game is not running, so the next load starts with them.
async function setSaved(page, edits) {
  await page.waitForFunction(async (key) => {
    const db = await new Promise((r) => { const q = indexedDB.open('/userfs'); q.onsuccess = () => r(q.result); });
    const v = await new Promise((r) => { const q = db.transaction('FILE_DATA').objectStore('FILE_DATA').get(key); q.onsuccess = () => r(q.result); });
    db.close();
    return !!v;
  }, SAVE_KEY, { timeout: 30000, polling: 500 });
  await page.waitForTimeout(1500);  // let the game's last sync land
  await page.goto(ORIGIN + '/blank');
  await page.evaluate(async ([key, edits]) => {
    const db = await new Promise((r) => { const q = indexedDB.open('/userfs'); q.onsuccess = () => r(q.result); });
    const store = db.transaction('FILE_DATA', 'readwrite').objectStore('FILE_DATA');
    const v = await new Promise((r) => { const q = store.get(key); q.onsuccess = () => r(q.result); });
    let text = new TextDecoder().decode(v.contents);
    for (const k in edits) text = text.replace(new RegExp('^' + k + '=.*$', 'm'), k + '=' + edits[k]);
    v.contents = new TextEncoder().encode(text);
    v.timestamp = new Date();
    await new Promise((r) => { const q = store.put(v, key); q.onsuccess = () => r(); });
    db.close();
  }, [SAVE_KEY, edits]);
}

try {
  // --- Mobile (touch), same browser profile across reloads -----------------
  const mctx = await browser.newContext(MOBILE);
  await mctx.addInitScript(signalProbe);
  const mp = await mctx.newPage();
  await load(mp);
  await scenario(mp, 'mobile first visit', { mobile: true, vp: MOBILE.viewport, musicOn: true, sfxOn: true });

  await load(mp); // reload = returning player, Music ON
  await scenario(mp, 'returning player, Music ON', { mobile: true, vp: MOBILE.viewport, musicOn: true, sfxOn: true });

  await setSaved(mp, { music: 'false' });
  await load(mp);
  await scenario(mp, 'returning player, Music OFF', { mobile: true, vp: MOBILE.viewport, musicOn: false, sfxOn: true });

  await setSaved(mp, { music: 'true', sfx: 'false' });
  await load(mp);
  await scenario(mp, 'returning player, SFX OFF', { mobile: true, vp: MOBILE.viewport, musicOn: true, sfxOn: false });
  await mctx.close();

  // --- iOS-like: the engine's AudioContext starts "suspended" -------------
  // Playwright navigation already grants activation, so Chromium creates the
  // context running. Force it to start suspended (as iOS Safari does) to
  // prove the gesture really resumes it.
  const sctx = await browser.newContext(MOBILE);
  await sctx.addInitScript(signalProbe);
  await sctx.addInitScript(() => {
    const C = window.AudioContext;
    const Wrapped = function (...a) { const c = new C(...a); c.suspend(); return c; };
    Wrapped.prototype = C.prototype;
    window.AudioContext = Wrapped;
  });
  const sp = await sctx.newPage();
  await load(sp);
  await scenario(sp, 'suspended context (iOS-like)', { mobile: true, vp: MOBILE.viewport, musicOn: true, sfxOn: true, expectSuspended: true });
  await sctx.close();

  // --- Desktop (mouse) ---------------------------------------------------------
  const dctx = await browser.newContext(DESKTOP);
  await dctx.addInitScript(signalProbe);
  const dp = await dctx.newPage();
  await load(dp);
  await scenario(dp, 'desktop Chrome (mouse)', { mobile: false, vp: DESKTOP.viewport, musicOn: true, sfxOn: true });
  await dctx.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close();
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(failed === 0 ? `WEB AUDIO TEST PASSED (${results.length} checks)` : `WEB AUDIO TEST FAILED (${failed} of ${results.length})`);
process.exit(failed === 0 ? 0 : 1);
