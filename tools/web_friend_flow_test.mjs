// Challenge a Friend (phase 3) in the exported Web build: real Chromium,
// real touch events via CDP, against tools/mock_social_api.py:
//   node tools/web_friend_flow_test.mjs build/web [--shots=dir]
// Phone A (390x844): CREATE CHALLENGE -> CHALLENGE A FRIEND -> HARD (one tap)
// -> CHALLENGE READY; SEND ON WHATSAPP opens exactly
// https://wa.me/?text=<"I made a HARD Chain Escape for you 🔗\nCan you escape it?" + "\n" + link>
// in a new tab; MORE WAYS TO SHARE / COPY LINK; PLAY / PREVIEW of the exact
// board and back. Phone B (405x720): the link -> friend landing -> the exact
// board -> YOU ESCAPED! -> CHALLENGE A FRIEND -> its own new challenge.
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
const shots = (process.argv.find((a) => a.startsWith('--shots=')) || '').slice(8);
const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const PORT = 8779, MOCK = 8797;
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
const TEXT = 'I made a HARD Chain Escape for you 🔗\nCan you escape it?';
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

async function open(W, H, suffix) {
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
  const s = { context, page, errors, state: get('chainEscapeState'), fr: get('chainEscapeFriend'), rec: get('chainEscapeRecipient'), play: get('chainEscapeSocialPlay') };
  s.waitFor = async (g, pred, what, ms = 60000) => {
    const end = Date.now() + ms; let v = null;
    while (Date.now() < end) { v = await g(); if (v && pred(v)) return v; await sleep(150); }
    throw new Error('timeout ' + what + ' ' + JSON.stringify(v).slice(0, 300));
  };
  const touch = (type, x, y) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y, id: 1 }] });
  s.tap = async (p, after = 700) => { await touch('touchStart', p[0] * W, p[1] * H); await sleep(60); await touch('touchEnd', p[0] * W, p[1] * H); await sleep(after); };
  s.tapFriend = async (name, step, after) => {
    const v = await s.waitFor(s.fr, (v) => v.open && v.step === step && v.buttons[name] && !v.buttons[name][2], name);
    await s.tap(v.buttons[name], after);
  };
  s.shot = async (name) => { if (shots) { fs.mkdirSync(shots, { recursive: true }); await page.screenshot({ path: path.join(shots, name + '.png') }); } };
  s.solve = async () => {
    for (let i = 0; i < 80; i++) {
      const v = await s.waitFor(s.play, (v) => v.completed || (v.active && v.next && v.next.length === 2), 'next move');
      if (v.completed) break;
      await s.tap(v.next, 450);
    }
    await s.waitFor(s.play, (v) => v.revealed, 'reveal');
    await sleep(1500);
    return s.play();
  };
  s.onScreen = (buttons) => Object.values(buttons).every((p) => p[0] > 0 && p[0] < 1 && p[1] > 0 && p[1] < 1);
  await page.goto(`http://127.0.0.1:${PORT}/index.html${suffix}`);
  return s;
}

let link = '', fp = '';
try {
  // ---- Phone A: create and share.
  let a = await open(390, 844, '');
  await a.waitFor(a.state, (v) => v.title_open, 'title', 120000); await sleep(1500);
  await a.tap([0.5, 0.7182], 1000);          // CREATE CHALLENGE
  await a.tap([0.5, 0.62], 900);             // CHALLENGE A FRIEND card
  let f = await a.waitFor(a.fr, (v) => v.open && v.step === 'CHOOSE', 'friend choose');
  check(['Difficulty_easy', 'Difficulty_medium', 'Difficulty_hard', 'Difficulty_very_hard', 'SurpriseMe', 'Back'].every((n) => f.buttons[n]) && a.onScreen(f.buttons),
    'CHALLENGE A FRIEND: EASY / MEDIUM / HARD / VERY HARD / SURPRISE ME / BACK on screen');
  check(!f.buttons.Continue && !f.buttons.Generate, 'no GENERATE / CONTINUE');
  await a.shot('W1_choose');
  await a.tapFriend('Difficulty_hard', 'CHOOSE', 100);
  f = await a.waitFor(a.fr, (v) => v.step === 'READY' || v.failed, 'ready', 60000);
  check(f.step === 'READY' && f.difficulty === 'hard' && !f.surprise && f.subtitle === 'HARD CHALLENGE', 'one tap -> CHALLENGE READY (HARD)');
  link = f.share_url; fp = f.fingerprint;
  const id = (link.match(/challenge=([0-9a-f-]{36})$/) || [])[1];
  check(/^http:\/\/127\.0\.0\.1:\d+\/index\.html\?challenge=[0-9a-f-]{36}$/.test(link), 'link carries only the id: ' + link);
  const stored = await (await fetch(`${API}?action=read&id=${id}`)).json();
  check(stored.challenge.challenge_type === 'friend_challenge' && stored.challenge.difficulty === 'hard', 'stored as a HARD friend_challenge');
  await sleep(600);
  f = await a.fr();
  const order = ['SendWhatsApp', 'ShareChallenge', 'CopyLink', 'NewChallenge', 'Done'];
  check(order.every((n) => f.buttons[n]) && f.buttons.PreviewChallenge && a.onScreen(f.buttons), 'READY: all buttons present and on screen');
  check(order.every((n, i) => i === 0 || f.buttons[order[i - 1]][1] < f.buttons[n][1]), 'READY: WhatsApp, more ways, copy, new/preview, done (top to bottom)');
  await a.shot('W2_ready');

  // SEND ON WHATSAPP.
  const expected = 'https://wa.me/?text=' + encodeURIComponent(TEXT + '\n' + link);
  check(await a.page.evaluate(() => window.ceSocial.whatsAppUrl()) === expected, 'wa.me link = Friend message + newline + exact link');
  const popupP = a.context.waitForEvent('page', { timeout: 8000 }).catch(() => null);
  await a.tapFriend('SendWhatsApp', 'READY', 300);
  const popup = await popupP;
  if (popup) await popup.waitForURL(/^https:\/\/wa\.me\//, { timeout: 5000 }).catch(() => null);
  check(popup && popup.url() === expected, 'SEND ON WHATSAPP opens exactly that wa.me link in a new tab');
  await sleep(500);
  f = await a.fr();
  check(f.step === 'READY' && f.share_status === '' && a.page.url().endsWith('/index.html'), 'game page stays on CHALLENGE READY, no delivery claim');
  if (popup) await popup.close();
  // MORE WAYS TO SHARE.
  await a.tapFriend('ShareChallenge', 'READY', 900);
  const shared = await a.page.evaluate(() => window.__shared);
  check(shared.length === 1 && shared[0].url === link && shared[0].text === TEXT && shared[0].title === 'Chain Escape', 'MORE WAYS TO SHARE: Friend text + exact link');
  // COPY LINK.
  await a.page.evaluate(() => navigator.clipboard.writeText(''));
  await a.tapFriend('CopyLink', 'READY', 900);
  f = await a.waitFor(a.fr, (v) => v.share_status === 'LINK COPIED', 'copied', 5000);
  check(await a.page.evaluate(() => navigator.clipboard.readText()) === link, 'COPY LINK copies exactly the link');
  // PLAY / PREVIEW.
  await a.tapFriend('PreviewChallenge', 'READY', 1200);
  let pv = await a.waitFor(a.play, (v) => v.active && v.mode === 'creator', 'preview');
  check(pv.fingerprint === fp, 'PLAY / PREVIEW = the exact created board');
  pv = await a.solve();
  check(pv.buttons.PlayAgain && pv.buttons.BackToCreate && !pv.buttons.CreateYourOwn && !pv.buttons.ChallengeAFriend, 'preview solved: PLAY AGAIN + BACK TO SHARE');
  await a.tap(pv.buttons.BackToCreate, 1000);
  f = await a.waitFor(a.fr, (v) => v.open && v.step === 'READY', 'back to share');
  check(f.share_url === link && f.fingerprint === fp, 'BACK TO SHARE -> same CHALLENGE READY');
  check(a.errors.length === 0, 'phone A: no page errors ' + a.errors.join(' | '));
  await a.context.close();

  // ---- Phone B: open the link, play, challenge back.
  const b = await open(405, 720, `?challenge=${id}`);
  let r = await b.waitFor(b.rec, (v) => v.state === 'landing', 'landing', 120000);
  await sleep(600); r = await b.rec();
  check(r.type === 'friend_challenge' && r.title === 'YOUR FRIEND\nCHALLENGED YOU' && r.subtitle === 'Can you escape this HARD\nChain Escape?'
    && r.buttons.Play && r.buttons.MainMenu && b.onScreen(r.buttons), 'landing: YOUR FRIEND CHALLENGED YOU / HARD / PLAY / MAIN MENU');
  await b.shot('W3_landing');
  await b.tap(r.buttons.Play, 1200);
  pv = await b.waitFor(b.play, (v) => v.active && v.mode === 'recipient', 'recipient play');
  check(pv.fingerprint === fp && pv.difficulty === 'hard', 'phone B plays the exact board');
  pv = await b.solve();
  check(pv.buttons.ChallengeAFriend && pv.buttons.PlayAgain && pv.buttons.BackToCreate && b.onScreen(pv.buttons), 'YOU ESCAPED! + CHALLENGE A FRIEND + PLAY AGAIN + MAIN MENU');
  await b.shot('W4_escaped');
  await b.tap(pv.buttons.PlayAgain, 1200);
  pv = await b.waitFor(b.play, (v) => v.active && !v.completed, 'again');
  check(pv.fingerprint === fp, 'PLAY AGAIN: same exact board');
  pv = await b.solve();
  await b.tap(pv.buttons.ChallengeAFriend, 1200);
  f = await b.waitFor(b.fr, (v) => v.open && v.step === 'CHOOSE', 'friend creator from the CTA');
  check(f && !(await b.play()).active, 'CHALLENGE A FRIEND -> the Friend creator');
  await b.tapFriend('Difficulty_easy', 'CHOOSE', 100);
  f = await b.waitFor(b.fr, (v) => v.step === 'READY' || v.failed, 'B ready', 60000);
  check(f.step === 'READY' && f.difficulty === 'easy' && f.share_url !== link && b.onScreen(f.buttons), 'phone B made its own challenge (new link), READY fits 405x720');
  await b.shot('W5_b_ready');
  check(b.errors.length === 0, 'phone B: no page errors ' + b.errors.join(' | '));
  await b.context.close();
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close(); server.close(); mock.kill();
const failed = results.filter((x) => !x).length;
console.log(`WEB FRIEND FLOW TEST: ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
