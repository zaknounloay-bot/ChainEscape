// Real-browser check of the mobile Web audio unlock.
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   node tools/web_audio_test.mjs            (needs Node + Playwright)
//
// Opens the exported game in Chromium with mobile emulation (touch, phone
// viewport) and Chrome's "user gesture required" autoplay policy - the same
// rule mobile browsers apply. Checks:
//   1. before any interaction: audio locked, music NOT playing
//   2. after ONE touch tap: audio unlocked, music playing, an AudioContext
//      is running
//   3. music is still playing a few seconds later (loop keeps going)
//   4. after a page reload the gate applies again and one tap unlocks again
import http from 'node:http';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

// Local or globally installed Playwright.
let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const { chromium } = pw;

const root = path.resolve(process.argv[2] || 'build/web');
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, decodeURIComponent(req.url.split('?')[0]) === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8765);

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };

// Full Chromium ("new headless"), which applies real autoplay rules; the
// lightweight headless shell does not.
const browser = await chromium.launch({
  channel: 'chromium',
  headless: !process.env.HEADED,
  // Playwright disables the autoplay rule by default; restore the real one.
  ignoreDefaultArgs: ['--autoplay-policy=no-user-gesture-required'],
  executablePath: process.env.CHROMIUM_PATH || undefined,
  args: ['--autoplay-policy=document-user-activation-required', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
});
const context = await browser.newContext({
  viewport: { width: 412, height: 915 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true,
  userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
});
// Track every AudioContext the page creates.
await context.addInitScript(() => {
  window.__ctxs = [];
  const Orig = window.AudioContext || window.webkitAudioContext;
  if (Orig) {
    window.__ctxlog = [];
    const Wrapped = function (...a) {
      const c = new Orig(...a);
      window.__ctxs.push(c);
      window.__ctxlog.push('created:' + c.state + '@' + Math.round(performance.now()));
      c.addEventListener('statechange', () => window.__ctxlog.push('state:' + c.state + '@' + Math.round(performance.now())));
      return c;
    };
    Wrapped.prototype = Orig.prototype;
    window.AudioContext = Wrapped;
    window.webkitAudioContext = Wrapped;
  }
});
const page = await context.newPage();
page.on('pageerror', (e) => console.log('pageerror:', e.message));

async function state() {
  return page.evaluate(() => ({
    game: window.chainEscapeAudio || null,
    ctx: (window.__ctxs || []).map((c) => c.state),
    activated: navigator.userActivation ? navigator.userActivation.hasBeenActive : null,
    log: window.__ctxlog || [],
  }));
}

async function loadAndTest(label) {
  await page.goto('http://localhost:8765/index.html');
  await page.waitForFunction(() => window.chainEscapeAudio !== undefined, null, { timeout: 120000 });
  await page.waitForTimeout(1500);
  let s = await state();
  console.log(label, 'before tap:', JSON.stringify(s));
  check(s.game.musicPlaying === false, `${label}: music not playing before the first interaction`);
  check(s.game.unlocked === false, `${label}: audio locked before the first interaction`);
  // Informational only: Playwright's navigation grants the page "user
  // activation", so the browser may already allow a running AudioContext.
  // What matters (and is checked) is that the GAME does not start music
  // until a real tap - which is what makes it work on phones.
  console.log(`INFO ${label}: AudioContext before tap = ${s.ctx.join(',') || 'none'} (page activation: ${s.activated})`);
  // One tap on the title's CONTINUE/PLAY button.
  await page.touchscreen.tap(206, Math.round(915 * 0.57));
  await page.waitForTimeout(3000);
  s = await state();
  console.log(label, 'after tap:', JSON.stringify(s));
  check(s.game.unlocked === true, `${label}: first tap unlocks audio`);
  check(s.game.musicPlaying === true, `${label}: music starts after the first tap`);
  check(s.ctx.includes('running'), `${label}: an AudioContext is running after the tap`);
  await page.waitForTimeout(4000);
  s = await state();
  check(s.game.musicPlaying === true && s.ctx.includes('running'), `${label}: music still playing 4 s later`);
}

try {
  await loadAndTest('first visit');
  await loadAndTest('after reload');
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close();
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(failed === 0 ? `WEB AUDIO TEST PASSED (${results.length} checks)` : `WEB AUDIO TEST FAILED (${failed} of ${results.length})`);
process.exit(failed === 0 ? 0 : 1);
