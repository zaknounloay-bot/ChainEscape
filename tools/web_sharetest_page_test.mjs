// Developer share test page (web/share_test.js) in the exported Web build:
//   node tools/web_sharetest_page_test.mjs build/web
// With ?sharetest=1 / &sharetest=1: the panel shows three links with the
// exact WhatsApp URLs (same page, new tab, whatsapp://), the game still
// starts underneath, taps on the panel stay on the panel. Without the
// parameter: no panel at all (production unchanged).
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
const PORT = 8777;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = req.url.split('?')[0].split('#')[0];
  const f = path.join(root, p === '/' ? 'index.html' : decodeURIComponent(p));
  fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end(); return; } res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); res.end(d); });
}).listen(PORT);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const results = [];
const check = (ok, msg) => { results.push(!!ok); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const browser = await pw.chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });

async function open(suffix) {
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true });
  // wa.me is not reachable from the test machine: a stub page stands in.
  await context.route('https://wa.me/**', (r) => r.fulfill({ status: 200, contentType: 'text/html', body: '<p>wa.me stub</p>' }));
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(`http://127.0.0.1:${PORT}/index.html${suffix}`);
  for (let i = 0; i < 240; i++) {
    if (await page.evaluate(() => !!(window.chainEscapeState && window.chainEscapeState.title_open))) break;
    await sleep(500);
  }
  return { context, page, errors };
}

try {
  for (const suffix of ['?sharetest=1', '?v=1790879289&sharetest=1']) {
    const { context, page, errors } = await open(suffix);
    const links = await page.evaluate(() => [...document.querySelectorAll('#ce-sharetest a')].map((a) => ({ id: a.id, href: a.getAttribute('href'), target: a.getAttribute('target') || '' })));
    const info = await page.evaluate(() => document.getElementById('ce-sharetest-info').textContent);
    const msg = /Message: “(.*)”/.exec(info)[1];
    const enc = encodeURIComponent(msg);
    check(links.length === 3, `${suffix}: panel with 3 links`);
    check(links[0] && links[0].href === 'https://wa.me/?text=' + enc && links[0].target === '', '1: wa.me, same page');
    check(links[1] && links[1].href === 'https://wa.me/?text=' + enc && links[1].target === '_blank', '2: wa.me, new tab');
    check(links[2] && links[2].href === 'whatsapp://send?text=' + enc, '3: whatsapp://send');
    check(/^Chain Escape share test \d\d:\d\d:\d\d http:\/\/127\.0\.0\.1:\d+\/index\.html$/.test(msg), `dummy message only: "${msg}"`);
    check(/loads in this tab: 1/.test(info), 'load counter starts at 1');
    const st = await page.evaluate(() => window.chainEscapeState);
    check(st && st.title_open, 'the game starts normally underneath');
    // New-tab link opens a separate page; the game page stays.
    const [popup] = await Promise.all([context.waitForEvent('page', { timeout: 5000 }).catch(() => null), page.click('#ce-st-2')]);
    if (popup) await popup.waitForURL(/^https:\/\/wa\.me\//, { timeout: 5000 }).catch(() => null);
    check(popup && popup.url() === 'https://wa.me/?text=' + enc, 'link 2 opens exactly that wa.me URL in a new tab');
    check(await page.evaluate(() => !!window.chainEscapeState), 'game page still alive after link 2');
    await page.click('#ce-st-close');
    check(await page.evaluate(() => !document.getElementById('ce-sharetest')), 'HIDE removes the panel');
    await page.reload();
    await sleep(1500);
    check(/loads in this tab: 2/.test(await page.evaluate(() => document.getElementById('ce-sharetest-info').textContent)), 'a reload is visible (loads in this tab: 2)');
    check(errors.length === 0, 'no page errors');
    await context.close();
  }
  for (const suffix of ['', '?v=1', '?sharetest=0', '?challenge=5a264212-44fb-499b-9e05-59c738ed98b2']) {
    const { context, page } = await open(suffix);
    check(await page.evaluate(() => !document.getElementById('ce-sharetest') && !window.ceShareTest), `"${suffix || '(none)'}": no test panel`);
    await context.close();
  }
} catch (e) {
  check(false, 'exception: ' + e.message);
}
await browser.close(); server.close();
const failed = results.filter((x) => !x).length;
console.log(`WEB SHARETEST PAGE TEST: ${failed ? 'FAILED' : 'PASSED'} (${results.length - failed}/${results.length})`);
process.exit(failed ? 1 : 0);
