// Real-browser checks of the Web audio unlock (tools/web_audio_test.mjs).
//
//   python3 tools/sync_web_head.py            (if web/audio_unlock.js changed)
//   godot --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_audio_test.mjs             (Node + Playwright + Chromium)
//
// Runs the exported game in Chromium under the strict autoplay policy
// (document-user-activation-required) and checks, per case:
//   * nothing plays before the first user gesture (music off, no SFX)
//   * one tap/click unlocks: the page-level unlock (web/audio_unlock.js)
//     resumes the engine's AudioContext inside the gesture, Godot sees it
//     "running", THEN starts music (if ON) and allows SFX (if ON)
//   * the [CE-Audio] log shows the full sequence
//   * the ?audiotest=1 test sounds run (JS tone + Godot SFX, clock advancing)
//   * music is never restarted by later taps
// Cases: mobile (touch) first visit, returning player with Music ON,
// Music OFF, SFX OFF (settings changed through the real settings path and
// persisted across a reload), and desktop mouse (Chrome; Edge uses the same
// Chromium engine). iOS Safari cannot run here - see README for the manual
// iPhone checklist.
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
    if (err) { res.writeHead(404); res.end(); return; }
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

const MOBILE = {
  viewport: { width: 412, height: 915 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
  userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
};
const DESKTOP = { viewport: { width: 1280, height: 800 } };
const URL = 'http://localhost:8765/index.html?audiotest=1';

// Taps everything the engine sends to the speakers into an AnalyserNode,
// so the test can prove real (non-silent) audio comes out, in either
// playback type (STREAM: one mixer node; SAMPLE: per-sound buffer nodes).
function signalProbe() {
  const origConnect = AudioNode.prototype.connect;
  const probes = new Map();
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
  window.__peak = () => {
    let peak = 0;
    for (const a of probes.values()) {
      const buf = new Float32Array(a.fftSize);
      a.getFloatTimeDomainData(buf);
      for (const v of buf) peak = Math.max(peak, Math.abs(v));
    }
    return peak;
  };
}

// Peak level over ~2 s of sampling (the music has short rests).
async function peakLevel(page) {
  let peak = 0;
  for (let i = 0; i < 20; i++) {
    peak = Math.max(peak, await page.evaluate(() => window.__peak()));
    await page.waitForTimeout(100);
  }
  return peak;
}

async function newContext(opts) {
  const c = await browser.newContext(opts);
  await c.addInitScript(signalProbe);
  return c;
}

async function game(page) {
  return page.evaluate(() => ({
    g: window.chainEscapeAudio || null,
    ctx: window.ceAudio ? window.ceAudio.state() : 'no-bridge',
    lines: window.ceAudio ? window.ceAudio.lines() : [],
  }));
}

async function load(page, extra = '') {
  await page.goto(URL + extra);
  await page.waitForFunction(() => window.chainEscapeAudio !== undefined, null, { timeout: 120000 });
  await page.waitForTimeout(1200);
}

async function tap(page, mobile) {
  if (mobile) await page.touchscreen.tap(206, Math.round(915 * 0.57));
  else await page.mouse.click(640, Math.round(800 * 0.57));
}

// One scenario: load, verify silence, tap, verify the unlock sequence.
async function scenario(page, label, { mobile, musicOn, sfxOn, playback = 'STREAM' }) {
  let s = await game(page);
  check(new RegExp(`playback type: ${playback}`).test(s.lines.join('\n')), `${label}: playback type logged as ${playback}`);
  const before = await peakLevel(page);
  check(before === 0, `${label}: output is silent before the first gesture (peak ${before.toFixed(4)})`);
  check(s.ctx !== 'no-bridge', `${label}: page-level unlock script (ceAudio) is present`);
  check(s.g.unlocked === false, `${label}: audio not unlocked before the first gesture`);
  check(s.g.musicPlaying === false, `${label}: no music before the first gesture`);
  check(s.g.sfxPlayed === 0, `${label}: no sound effects before the first gesture`);
  check(s.g.musicEnabled === musicOn && s.g.sfxEnabled === sfxOn, `${label}: saved settings restored (music ${musicOn ? 'ON' : 'OFF'}, sfx ${sfxOn ? 'ON' : 'OFF'})`);
  console.log(`INFO ${label}: context before gesture = ${s.ctx}`);
  await tap(page, mobile);
  await page.waitForTimeout(2500);
  s = await game(page);
  const log = s.lines.join('\n');
  check(s.ctx === 'running', `${label}: AudioContext running after the gesture (${s.ctx})`);
  check(s.g.unlocked === true, `${label}: Godot marked audio unlocked`);
  check(s.g.musicPlaying === musicOn, `${label}: music ${musicOn ? 'playing' : 'NOT playing (Music OFF)'}`);
  check(/first user gesture: (touchend|pointerup|mouseup|click)/.test(log), `${label}: log shows the first gesture event`);
  check(/\(godot\) audio unlocked \(context: running\)/.test(log), `${label}: log shows Godot unlocking only once the context runs`);
  check(new RegExp(musicOn ? '\\(godot\\) music: started' : '\\(godot\\) music: OFF').test(log), `${label}: log shows the music decision`);
  check(/JS test tone played/.test(log), `${label}: ?audiotest JS test tone played`);
  check(new RegExp(musicOn ? `music play attempt: theme \\w+ \\(${playback}, context running\\) -> playing=true` : 'music: OFF').test(log),
    `${label}: music play attempt logged (${musicOn ? playback + ', context running' : 'Music OFF'})`);
  if (sfxOn) check(new RegExp(`SFX play attempt #1: '\\w+' \\(${playback}, context running\\)`).test(log), `${label}: SFX play attempt logged (${playback})`);
  if (sfxOn) {
    check(s.g.sfxPlayed >= 1, `${label}: Godot SFX played after unlock (${s.g.sfxPlayed})`);
    check(/SFX test: .*advancing\)/.test(log) && !/NOT advancing/.test(log), `${label}: SFX test ran with the audio clock advancing`);
  } else {
    check(s.g.sfxPlayed === 0, `${label}: no SFX when Sound Effects are OFF`);
    check(/SFX test skipped: Sound Effects are OFF/.test(log), `${label}: SFX test reports SFX OFF`);
  }
  // Later taps must not restart anything.
  const unlockCount = (log.match(/audio unlocked/g) || []).length;
  await tap(page, mobile);
  await tap(page, mobile);
  await page.waitForTimeout(800);
  s = await game(page);
  const log2 = s.lines.join('\n');
  check((log2.match(/audio unlocked/g) || []).length === unlockCount && s.g.musicPlaying === musicOn,
    `${label}: extra taps do not re-unlock or restart music`);
  if (musicOn) {
    const after = await peakLevel(page);
    if (playback === 'STREAM') check(after > 0.005, `${label}: music signal actually reaches the output (peak ${after.toFixed(4)})`);
    // Godot's SAMPLE path measured silent in headless Chromium for this
    // project; kept as information for the A/B comparison only.
    else console.log(`INFO ${label}: output peak with ${playback} playback = ${after.toFixed(4)}`);
  }
  return s;
}

// Reads the save file straight from the browser storage (IndexedDB).
async function savedFile(page) {
  return page.evaluate(async () => {
    const db = await new Promise((r) => { const q = indexedDB.open('/userfs'); q.onsuccess = () => r(q.result); });
    const v = await new Promise((r) => {
      const q = db.transaction('FILE_DATA').objectStore('FILE_DATA').get('/userfs/godot/app_userdata/Chain Escape/progress.cfg');
      q.onsuccess = () => r(q.result);
    });
    db.close();
    return v ? new TextDecoder().decode(v.contents) : '';
  });
}

// Changes a setting through the game's own settings handler, then waits
// until Godot has synced the save to IndexedDB (can take a few seconds).
async function setSetting(page, key, on) {
  await page.evaluate(([k, v]) => window.ceSetSetting(k, v), [key, on]);
  for (let i = 0; i < 60; i++) {
    await page.waitForTimeout(500);
    if ((await savedFile(page)).includes(`${key}=${on}`)) return;
  }
  throw new Error(`setting ${key}=${on} never reached browser storage`);
}

try {
  // --- Mobile (touch), same browser profile across reloads -----------------
  const mctx = await newContext(MOBILE);
  const mp = await mctx.newPage();
  mp.on('console', (m) => { if (process.env.VERBOSE && m.text().includes('CE-Audio')) console.log('   ' + m.text()); });
  await load(mp);
  const first = await scenario(mp, 'mobile first visit', { mobile: true, musicOn: true, sfxOn: true });
  console.log('--- unlock sequence (mobile first visit) ---\n' + first.lines.map((l) => '   ' + l).join('\n'));

  await load(mp); // reload = returning player, Music ON
  await scenario(mp, 'returning player, Music ON', { mobile: true, musicOn: true, sfxOn: true });

  await setSetting(mp, 'music', false);
  await load(mp);
  await scenario(mp, 'returning player, Music OFF', { mobile: true, musicOn: false, sfxOn: true });

  await setSetting(mp, 'music', true);
  await setSetting(mp, 'sfx', false);
  await load(mp);
  await scenario(mp, 'returning player, SFX OFF', { mobile: true, musicOn: true, sfxOn: false });
  await setSetting(mp, 'sfx', true);
  await mctx.close();

  // --- iOS-like: the engine's AudioContext starts "suspended" -------------
  // Playwright navigation already grants activation, so Chromium creates the
  // context running. Force it to start suspended (as iOS Safari does) to
  // prove the gesture really resumes it.
  const sctx = await newContext(MOBILE);
  await sctx.addInitScript(() => {
    const C = window.AudioContext;
    const Wrapped = function (...a) { const c = new C(...a); c.suspend(); return c; };
    Wrapped.prototype = C.prototype;
    window.AudioContext = Wrapped;
  });
  const sp = await sctx.newPage();
  await load(sp);
  const pre = await game(sp);
  check(pre.ctx === 'suspended', `suspended context: starts suspended before the gesture (${pre.ctx})`);
  const sus = await scenario(sp, 'suspended context (iOS-like)', { mobile: true, musicOn: true, sfxOn: true });
  check(/state before = suspended/.test(sus.lines.join('\n')) && /resume\(\) resolved/.test(sus.lines.join('\n')),
    'suspended context: log shows resume() inside the gesture');
  console.log('--- unlock sequence (suspended context) ---\n' + sus.lines.map((l) => '   ' + l).join('\n'));
  await sctx.close();

  // --- A/B: Godot's SAMPLE playback forced by URL (device comparison) ----
  const actx = await newContext(MOBILE);
  const ap = await actx.newPage();
  await load(ap, '&audiomode=sample');
  await scenario(ap, 'A/B ?audiomode=sample', { mobile: true, musicOn: true, sfxOn: true, playback: 'SAMPLE' });
  await actx.close();

  // --- Desktop (mouse) ---------------------------------------------------------
  const dctx = await newContext(DESKTOP);
  const dp = await dctx.newPage();
  await load(dp);
  await scenario(dp, 'desktop Chrome (mouse)', { mobile: false, musicOn: true, sfxOn: true });
  await dctx.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close();
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(failed === 0 ? `WEB AUDIO TEST PASSED (${results.length} checks)` : `WEB AUDIO TEST FAILED (${failed} of ${results.length})`);
process.exit(failed === 0 ? 0 : 1);
