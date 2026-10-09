// MILESTONE TEXT FIT in real Chromium at iPhone sizes: the golden stamp
// ("MASTER!" after 100, "GRAND MASTER!" after 200) and the "N / LEVELS
// ESCAPED!" overlay must be FULLY visible - checked on the rendered pixels,
// not only on the label's box: when the stamp rests (scale 1, fully
// opaque) a screenshot is taken and the screen-edge columns inside the
// stamp's band must hold no stamp-gold pixels, while the text itself must.
// Uses the developer build's QA jump + debug auto-solve.
//
//   godot --headless --path . --export-release "Web" build/web/index.html
//   SHOTS=<dir> node tools/web_milestone_fit_test.mjs build/web
//   (NEGATIVE=1: expect the clipping - for an old build, proves the check bites)
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
const root = path.resolve(process.argv[2] || 'build/web');
const shots = process.env.SHOTS || os.tmpdir();
const NEGATIVE = !!process.env.NEGATIVE;
const LEVELS = (process.env.LEVELS || '200,100,250').split(',').map(Number);
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const file = path.join(root, req.url === '/' ? 'index.html' : decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(8781, '127.0.0.1');
const BASE = 'http://127.0.0.1:8781/index.html';
const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] };
const state = (page) => page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(page, pred, what, ms = 150000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(page);
    if (s && pred(s)) return s;
    await sleep(60);
  }
  throw new Error('timeout waiting for ' + what);
}
// Stamp gold #FFB300 (and its antialiased edge, still clearly gold) in the
// rows y0..y1 of a screenshot: how many sit in the outermost `cols` columns
// on either side, how many inside. Decoded in a blank analysis page.
let analyzer = null;
async function edgeGold(buf, y0, y1, cols) {
  return analyzer.evaluate(async ([b64, y0, y1, cols]) => {
    const img = await createImageBitmap(await (await fetch('data:image/png;base64,' + b64)).blob());
    const c = new OffscreenCanvas(img.width, img.height);
    const g = c.getContext('2d');
    g.drawImage(img, 0, 0);
    const d = g.getImageData(0, 0, img.width, img.height).data;
    let edge = 0, inner = 0;
    for (let y = Math.max(0, y0); y < Math.min(img.height, y1); y++) {
      for (let x = 0; x < img.width; x++) {
        const i = (y * img.width + x) * 4;
        if (!(d[i] > 225 && d[i + 1] > 150 && d[i + 1] < 205 && d[i + 2] < 70)) continue;
        if (x < cols || x >= img.width - cols) edge++;
        else inner++;
      }
    }
    return { edge, inner, width: img.width };
  }, [buf.toString('base64'), y0, y1, cols]);
}

const errors = [];
for (const [W, H, label] of [[390, 844, 'iphone14'], [375, 667, 'iphoneSE'], [430, 932, 'promax']]) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-fit-'));
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true, reducedMotion: 'reduce' });
  const page = ctx.pages()[0] || await ctx.newPage();
  analyzer = await ctx.newPage();
  await analyzer.goto('about:blank');
  await page.bringToFront();
  page.on('pageerror', (e) => errors.push(`${label}: ${e.message}`));
  try {
    for (const n of (label === 'iphone14' ? LEVELS : [200])) {
      await page.goto(`${BASE}?experiencelab=${n}&qareset=1`);
      await waitFor(page, (x) => x.level === n && x.lab_qa && !x.title_open, `QA ${n}`);
      await sleep(1500);
      await page.focus('canvas').catch(() => {});
      await page.keyboard.press('F1'); await sleep(250);
      await page.keyboard.press('s');
      // The overlay first (every 25th level), then (100 / 200) the stamp.
      if (NEGATIVE) {
        // An old build publishes no stamp state: scan frames from the
        // auto-solve until its card opens.
        let worst = { edge: 0, inner: 0 }, frames = 0;
        const end = Date.now() + 120000;
        while (Date.now() < end) {
          const buf = await page.screenshot();
          const g = await edgeGold(buf, Math.floor(H * 0.3), Math.ceil(H * 0.7), 2);
          frames++;
          if (g.edge > worst.edge) { worst = g; fs.writeFileSync(path.join(shots, `fit_old_${label}_L${n}.png`), buf); }
          const st = await state(page);
          if (st && st.card_open && st.level === n) break;
        }
        check(worst.edge > 0, `[${label}] NEGATIVE CONTROL L${n}: the old stamp's gold reaches the screen edges (${worst.edge} px over ${frames} frames) - the check detects clipping`);
        continue;
      }
      let s = await waitFor(page, (x) => x.level === n && x.major_rect && x.major_rect[2] > 0, `overlay ${n}`).catch(() => null);
      if (s) {
        await sleep(700);
        const r = (await state(page)).major_rect;
        const g = await edgeGold(await page.screenshot(), Math.floor(r[1] * H), Math.ceil(r[3] * H), 2);
        check(g.inner > 50 && g.edge === 0, `[${label}] L${n}: "${n} / LEVELS ESCAPED!" fully visible (gold at the edges ${g.edge}, inside ${g.inner})`);
      }
      if (n === 100 || n === 200) {
        s = await waitFor(page, (x) => x.stamp && x.stamp.text && x.stamp.scale > 0.98 && x.stamp.scale < 1.02 && x.stamp.alpha > 0.98, `stamp ${n}`, 20000);
        const buf = await page.screenshot();
        fs.writeFileSync(path.join(shots, `fit_${label}_L${n}_stamp.png`), buf);
        const scale = W / 720;  // logical 720 px wide (canvas_items, expand)
        const rest = s.stamp.rest;
        const g = await edgeGold(buf, Math.floor(rest[1] * scale) - 4, Math.ceil(rest[3] * scale) + 4, 2);
        const vw = g.width;
        const want = n === 200 ? 'GRAND MASTER!' : 'MASTER!';
        const fits = rest[0] >= 0 && rest[2] <= 720;
        check(s.stamp.text === want && g.inner > 50 && g.edge === 0 && fits,
          `[${label}] L${n}: the "${s.stamp.text}" stamp is fully visible (font ${s.stamp.font_size}, ink ${Math.round(rest[0])}..${Math.round(rest[2])} of 720, gold at the edges ${g.edge}, inside ${g.inner}, ${vw}px wide)`);
      }
      s = await waitFor(page, (x) => x.card_open && x.level === n, `card ${n}`, 30000);
      await page.keyboard.press('F1');
      check(s.card_title === `${n} LEVELS ESCAPED!`, `[${label}] L${n}: card "${s.card_title}"`);
      await page.screenshot({ path: path.join(shots, `fit_${label}_L${n}_card.png`) });
    }
  } catch (e) {
    check(false, `${label}: ${e.message}`);
  }
  await ctx.close();
}
check(errors.length === 0, `no page errors (${errors.slice(0, 3).join(' | ')})`);
server.close();
const failed = results.filter((r) => !r[0]).length;
console.log(`${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
