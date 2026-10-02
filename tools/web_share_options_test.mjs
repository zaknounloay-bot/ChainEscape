// CHALLENGE READY share options in the exported Web build (real Chromium,
// iPhone size, real touch events via CDP), against tools/mock_social_api.py:
//   node tools/web_share_options_test.mjs build/web
// SEND ON WHATSAPP opens exactly https://wa.me/?text=<message + "\n" + link>
// in a NEW tab (the game page stays), MORE WAYS TO SHARE calls
// navigator.share with title / text / link only, COPY LINK copies the link;
// the status never claims delivery; the ?sharetest=1 dev panel is absent.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync, spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const root = path.resolve(process.argv[2] || 'build/web');
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PORT = 8778, MOCK = 8798, W = 390, H = 844;
const API = `http://127.0.0.1:${MOCK}/`;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(root, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(PORT);
const mock = spawn('python3', [path.join(repo, 'tools/mock_social_api.py'), '--port', String(MOCK)], { stdio: 'ignore' });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
for (let i = 0; i < 40; i++) { try { await fetch(API); break; } catch { await sleep(250); } }
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const TEXT = 'I made a Chain Escape for you 🔗 Can you unlock it?';
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

try {
  const context = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  await context.grantPermissions(['clipboard-read', 'clipboard-write'], { origin: `http://127.0.0.1:${PORT}` });
  await context.route('https://wa.me/**', (r) => r.fulfill({ status: 200, contentType: 'text/html', body: '<p>wa.me stub</p>' }));
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.addInitScript((api) => {
    window.ceTestHooks = true; window.ceApiUrl = api;
    window.__shared = []; navigator.share = (d) => { window.__shared.push(d); return Promise.resolve(); };
  }, API);
  const cdp = await context.newCDPSession(page);
  const get = (n) => () => page.evaluate((k) => window[k] || null, n).catch(() => null);
  const state = get('chainEscapeState'), soc = get('chainEscapeSocial');
  const waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(150); }
    throw new Error('timeout ' + what + ' ' + JSON.stringify(v).slice(0, 300));
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  const tapAt = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(60); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  const tapButton = async (name, step, after) => { const v = await waitFor(soc, (v) => v.open && v.step === step && v.buttons[name] && !v.buttons[name][2], name); await tapAt(v.buttons[name], after); };

  await page.goto(`http://127.0.0.1:${PORT}/index.html`);
  await waitFor(state, (v) => v.title_open, 'title', 120000); await sleep(1500);
  check(await page.evaluate(() => !document.getElementById('ce-sharetest')), 'no ?sharetest dev panel in normal play');
  // CREATE CHALLENGE -> PHOTO / MESSAGE REVEAL -> skip photo -> message -> easy -> create.
  await tapAt([0.5, 0.7182], 1000); await tapAt([0.5, 0.4121], 900);
  await tapButton('SkipPhoto', 'CHOOSE', 900);
  await tapButton('MessageCard', 'MESSAGE', 250); await page.waitForSelector('#ce-message-text', { timeout: 3000 });
  await page.fill('#ce-message-text', 'Share options test'); await sleep(450); await page.click('#ce-message-done');
  await waitFor(soc, (v) => v.draft === 'Share options test', 'draft'); await sleep(400);
  await tapButton('Continue', 'MESSAGE', 900);
  await tapButton('Difficulty_easy', 'DIFFICULTY', 600); await tapButton('Continue', 'DIFFICULTY', 900);
  await tapButton('Create', 'REVIEW', 300);
  let v = await waitFor(soc, (v) => v.step === 'SHARE', 'share screen', 60000);
  const url = v.share_url;
  check(/^http:\/\/127\.0\.0\.1:\d+\/index\.html\?challenge=[0-9a-f-]{36}$/.test(url), 'challenge link (only the id): ' + url);
  check(v.buttons.SendWhatsApp && v.buttons.ShareChallenge && v.buttons.CopyLink && v.buttons.PreviewChallenge && v.buttons.Done,
    'CHALLENGE READY: SEND ON WHATSAPP, MORE WAYS TO SHARE, COPY LINK, PLAY / PREVIEW, DONE');
  check(v.buttons.SendWhatsApp[1] < v.buttons.ShareChallenge[1] && v.buttons.ShareChallenge[1] < v.buttons.CopyLink[1]
    && v.buttons.CopyLink[1] < v.buttons.PreviewChallenge[1] && v.buttons.PreviewChallenge[1] < v.buttons.Done[1], 'buttons in that order, top to bottom');
  check(Object.values(v.buttons).every((p) => p[1] > 0 && p[1] < 1), 'all on screen');
  await page.screenshot({ path: '/dev/null' }).catch(() => {});

  // 1. SEND ON WHATSAPP -> new tab with the exact wa.me link; game page stays.
  const expected = 'https://wa.me/?text=' + encodeURIComponent(TEXT + '\n' + url);
  check(await page.evaluate(() => window.ceSocial.whatsAppUrl()) === expected, 'wa.me link = message + newline + exact challenge link');
  const popupP = context.waitForEvent('page', { timeout: 8000 }).catch(() => null);
  await tapButton('SendWhatsApp', 'SHARE', 300);
  const popup = await popupP;
  if (popup) await popup.waitForURL(/^https:\/\/wa\.me\//, { timeout: 5000 }).catch(() => null);
  check(popup && popup.url() === expected, 'SEND ON WHATSAPP opens exactly that wa.me link in a new tab');
  check(!decodeURIComponent(expected).includes('Share options test'), 'the personal message is never in the WhatsApp text');
  v = await waitFor(soc, (v) => v.share_status !== '', 'whatsapp status', 5000);
  check(v.share_status === 'OPENED WHATSAPP', `neutral status after WhatsApp: "${v.share_status}"`);
  check(page.url().endsWith('/index.html') && (await state()) && v.step === 'SHARE', 'the game page stays on CHALLENGE READY');
  if (popup) await popup.close();

  // 2. MORE WAYS TO SHARE -> navigator.share (title, text, link only).
  await tapButton('ShareChallenge', 'SHARE', 900);
  v = await waitFor(soc, (v) => v.share_status !== '' && v.share_status !== 'OPENED WHATSAPP', 'share status', 5000);
  const shared = await page.evaluate(() => window.__shared);
  check(shared.length === 1 && shared[0].url === url && shared[0].text === TEXT && shared[0].title === 'Chain Escape',
    'MORE WAYS TO SHARE: share sheet with title, text and the exact link only');
  check(v.share_status === 'HANDED TO THE APP YOU CHOSE' && !/SHARED|SENT/.test(v.share_status), `neutral status after the share sheet: "${v.share_status}"`);

  // 3. COPY LINK.
  await page.evaluate(() => navigator.clipboard.writeText(''));
  await tapButton('CopyLink', 'SHARE', 900);
  v = await waitFor(soc, (v) => v.share_status === 'LINK COPIED', 'copy', 5000);
  check(await page.evaluate(() => navigator.clipboard.readText()) === url, 'COPY LINK copies exactly the link');
  check(errors.length === 0, 'no page errors ' + errors.join(' | '));
  await context.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close(); server.close(); mock.kill();
const failed = results.filter((x) => !x).length;
console.log(`WEB SHARE OPTIONS TEST: ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
