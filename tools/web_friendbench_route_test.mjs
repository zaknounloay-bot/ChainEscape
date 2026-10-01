// Challenge a Friend dev benchmark entry (?friendbench=1) vs shared-challenge
// links, in the exported Web build (real Chromium):
//   node tools/web_friendbench_route_test.mjs build/web
// The benchmark page must open for ?friendbench=1, #friendbench=1 and when
// it is appended to a full challenge link (".../index.html?challenge=<id>?
// friendbench=1" - a recipient "not available" screen there was the bug);
// challenge links without it must route exactly as before, and a plain
// start must stay the normal title.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';

let pw;
try { pw = await import('playwright'); } catch {
  pw = createRequire(execSync('npm root -g').toString().trim() + '/')('playwright');
}
const root = path.resolve(process.argv[2] || 'build/web');
const PORT = 8776;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(root, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(PORT);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const ID = '5a264212-44fb-499b-9e05-59c738ed98b2';
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

// Opens the build with `suffix`; returns what the game routed to.
async function open(suffix) {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  // Block the real API: these checks are about routing only.
  await context.route('**/functions/v1/**', (r) => r.abort());
  await page.addInitScript(() => {
    let first = null;
    Object.defineProperty(window, 'chainEscapeRecipient', { configurable: true,
      set(v) { if (first === null && v && v.state !== 'closed') first = v; this.__r = v; }, get() { return this.__r; } });
    window.__firstRecipient = () => first;
  });
  await page.goto(`http://127.0.0.1:${PORT}/index.html${suffix}`);
  let v = null;
  for (let i = 0; i < 240; i++) {
    v = await page.evaluate(() => ({
      title: !!(window.chainEscapeState && window.chainEscapeState.title_open),
      bench: !!window.chainEscapeFriendBench,
      recipient: window.__firstRecipient() ? window.__firstRecipient().state : null,
      launch: window.ceSocial ? window.ceSocial.launchChallenge() : null,
      devBench: window.ceSocial ? window.ceSocial.devBench() : null,
    }));
    if (v.title || v.bench) break;
    await sleep(500);
  }
  await sleep(2000);
  v = await page.evaluate(() => ({
    title: !!(window.chainEscapeState && window.chainEscapeState.title_open),
    bench: !!window.chainEscapeFriendBench,
    recipient: window.__firstRecipient() ? window.__firstRecipient().state : null,
    launch: window.ceSocial.launchChallenge(),
    devBench: window.ceSocial.devBench(),
  }));
  v.errors = errors.length;
  await context.close();
  return v;
}

try {
  for (const suffix of ['?friendbench=1', '#friendbench=1', '?friendbench=true',
    `?challenge=${ID}?friendbench=1`, `?challenge=${ID}&friendbench=1`, `?friendbench=1&challenge=${ID}`, `?challenge=${ID}#friendbench=1`]) {
    const v = await open(suffix);
    check(v.bench && v.devBench && v.recipient === null && v.errors === 0, `${suffix} -> benchmark page, no recipient screen (${JSON.stringify(v)})`);
  }
  // Challenge links: parsed and routed exactly as before.
  let v = await open(`?challenge=${ID.toUpperCase()}`);
  check(!v.bench && v.launch === '=' + ID.toUpperCase() && v.recipient === 'loading', `?challenge=<id> -> recipient loading, no benchmark (${JSON.stringify(v)})`);
  v = await open(`#challenge=${ID}`);
  check(!v.bench && v.launch === '=' + ID && v.recipient === 'loading', `#challenge=<id> -> recipient loading (${JSON.stringify(v)})`);
  v = await open(`?challenge=${ID}&utm_source=x`);
  check(!v.bench && v.launch === '=' + ID && v.recipient === 'loading', `?challenge=<id>&other -> recipient loading (${JSON.stringify(v)})`);
  v = await open('?challenge=not-an-id');
  check(!v.bench && v.launch === '=not-an-id' && v.recipient === 'unavailable', `malformed challenge -> unavailable (${JSON.stringify(v)})`);
  v = await open('?challenge=');
  check(!v.bench && v.launch === '=' && v.recipient === 'unavailable', `empty challenge -> unavailable (${JSON.stringify(v)})`);
  v = await open('?friendbench=0');
  check(!v.bench && !v.devBench && v.title && v.recipient === null, `?friendbench=0 -> normal title (${JSON.stringify(v)})`);
  v = await open('');
  check(!v.bench && v.title && v.recipient === null && v.launch === '', `no parameter -> normal title (${JSON.stringify(v)})`);
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close(); server.close();
const failed = results.filter((x) => !x).length;
console.log(`WEB FRIENDBENCH ROUTE TEST: ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
