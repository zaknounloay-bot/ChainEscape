// PLAYER IDENTITY (Phase 3A, QA) - real Chromium at iPhone sizes, touch:
//
//   godot --headless --path . --export-release "Web QA" build/web_qa/index.html
//   godot --headless --path . --export-release "Web Friend Test" build/web_friend/index.html
//   SHOTS=<dir> node tools/web_profile_test.mjs build/web_qa build/web_friend <previous QA build ZIP|dir>
//
// Q: the QA build (?experiencelab=N, its own QA save):
//    - a valid anonymous id from the first start (the page state only ever
//      carries a short hash of it), the same after a reload;
//    - Settings: the optional YOUR NAME row; tapping it opens the native
//      name field (keyboard focus, near the top, above where the keyboard
//      goes) on iPhone SE / 14 / Pro Max;
//    - Hebrew, Arabic and English names saved and shown; NFC normalization
//      (e + combining acute -> é); an emoji name refused with a reason,
//      the old name kept; an empty name removes it; CANCEL changes nothing;
//    - name and id survive a reload.
// R: rollback - the PREVIOUS QA build (no identity) opens the same QA save
//    at the same address, plays and saves: the [profile] stays; the new
//    build again finds the same id and name.
// I: isolation - the release save (chain_escape_save_r2) and the old save
//    stay byte-identical; only the QA key holds a [profile].
// P: the player (production) build: no identity - no name row, no id, no
//    [profile] in the release save.
// E: no page errors.
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
const unpack = (p) => {
  const abs = path.resolve(p);
  if (fs.statSync(abs).isDirectory()) return abs;
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-prof-'));
  execSync(`unzip -q "${abs}" -d "${dir}"`);
  return dir;
};
const roots = { qa: path.resolve(process.argv[2] || 'build/web_qa'), prod: path.resolve(process.argv[3] || 'build/web_friend') };
const oldQa = process.argv[4] ? unpack(process.argv[4]) : null;
let qaServing = 'qa';
const types = { '.html': 'text/html', '.js': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const m = req.url.split('?')[0].match(/^\/(qa|prod)\/(.*)$/);
  if (!m) { res.writeHead(404); res.end(); return; }
  const root = m[1] === 'qa' ? (qaServing === 'old' ? oldQa : roots.qa) : roots.prod;
  const file = path.join(root, decodeURIComponent(m[2] || 'index.html'));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    res.end(data);
  });
}).listen(8796, '127.0.0.1');
const QA = 'http://127.0.0.1:8796/qa/index.html';
const PROD = 'http://127.0.0.1:8796/prod/index.html';

const results = [];
const check = (ok, msg) => { results.push([ok, msg]); console.log((ok ? 'PASS ' : 'FAIL ') + msg); };
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LAUNCH = { headless: !process.env.HEADED, args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio'] };
const shots = process.env.SHOTS || os.tmpdir();
const errors = [];
const SIZES = { iphoneSE: [375, 667], iphone14: [390, 844], promax: [430, 932] };
const R2 = 'chain_escape_save_r2', OLD = 'chain_escape_save', QAKEY = 'chain_escape_experiencelab_qa_save';
const SENTINEL_R2 = '[meta]\n\nversion=5\nseq=42\n\n[progress]\n\ncurrent_level=77\nhighest_completed=76\nhighest_unlocked=77\n\n[times]\n\n1=4321\n';
const SENTINEL_OLD = '[meta]\n\nversion=5\nseq=9\n\n[progress]\n\ncurrent_level=12\nhighest_completed=11\nhighest_unlocked=12\n';

async function open(url, dir, size, seed) {
  const [W, H] = SIZES[size];
  const ctx = await chromium.launchPersistentContext(dir, { ...LAUNCH, viewport: { width: W, height: H }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  if (seed) await ctx.addInitScript(([a, b, c, d]) => { try { if (!localStorage.getItem(a)) localStorage.setItem(a, b); if (!localStorage.getItem(c)) localStorage.setItem(c, d); } catch (e) {} }, seed);
  const page = ctx.pages()[0] || await ctx.newPage();
  page.on('pageerror', (e) => errors.push(e.message));
  await page.goto(url);
  return { ctx, page, W, H };
}
const state = (g) => g.page.evaluate(() => window.chainEscapeState || null).catch(() => null);
async function waitFor(g, pred, what, ms = 90000) {
  const end = Date.now() + ms;
  let s = null;
  while (Date.now() < end) {
    s = await state(g);
    if (s && pred(s)) return s;
    await sleep(80);
  }
  throw new Error('timeout waiting for ' + what + ' ' + JSON.stringify(s && { level: s.level, profile: s.profile }));
}
const tapFrac = (g, x, y) => g.page.touchscreen.tap(x * g.W, y * g.H);
const prof = (s) => s.profile || {};
const row = (s) => prof(s).row || {};
async function startQA(n, dir, size, reset, seed) {
  const g = await open(QA + `?experiencelab=${n}${reset ? '&qareset=1' : ''}`, dir, size, seed);
  await waitFor(g, (x) => x.level === n && x.lab_qa && !x.title_open && !x.intro_open, `QA ${n}`);
  await sleep(800);
  return g;
}
async function openSettings(g) {
  const s = await state(g);
  await tapFrac(g, s.settings_button[0], s.settings_button[1]);
  return waitFor(g, (x) => x.settings_open && row(x).visible, 'settings open', 8000);
}
async function closeSettings(g) {
  await tapFrac(g, 0.5, 0.02);  // the dim backdrop outside the card
  return waitFor(g, (x) => !x.settings_open, 'settings closed', 8000);
}
// Taps the name row, types `text` into the native field and presses SAVE
// (or CANCEL). Returns the dialog facts seen while it was open.
async function enterName(g, text, shotName, cancel = false) {
  let s = await state(g);
  const r = row(s).rect;
  await tapFrac(g, (r[0] + r[2]) / 2, (r[1] + r[3]) / 2);
  await g.page.waitForSelector('#ce-name-text', { timeout: 5000 });
  const facts = await g.page.evaluate(() => {
    const i = document.getElementById('ce-name-text');
    const b = i.getBoundingClientRect();
    return { focused: document.activeElement === i, top: b.top, bottom: b.bottom, h: window.innerHeight, dir: i.dir, max: i.maxLength,
      fontPx: parseFloat(getComputedStyle(i).fontSize), draft: i.value };
  });
  await g.page.fill('#ce-name-text', text);
  if (shotName) await g.page.screenshot({ path: path.join(shots, shotName) });
  await sleep(450);  // the dialog ignores clicks in its first 400 ms (the opening tap)
  const seq = prof(s).name_set_unix;
  await g.page.click(cancel ? '#ce-name-cancel' : '#ce-name-done');
  await g.page.waitForSelector('#ce-name', { state: 'detached', timeout: 5000 });
  await sleep(700);
  s = await state(g);
  return { facts, s, seq };
}

try {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-prof-'));
  const seed = [R2, SENTINEL_R2, OLD, SENTINEL_OLD];
  // ===== Q: SE - id, Settings row, names =====
  let g = await startQA(6, profile, 'iphoneSE', true, seed);
  let s = await state(g);
  const H = prof(s).id_hash;
  check(s.player_identity && prof(s).id_valid && /^[0-9a-f]{12}$/.test(H) && prof(s).name === '',
    `Q[SE] a valid anonymous id from the first start (state shows only a hash: ${H}), no name`);
  check(!JSON.stringify(s).match(/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/), 'Q[SE] the id itself is nowhere in the page state');
  s = await openSettings(g);
  await sleep(300);
  await g.page.screenshot({ path: path.join(shots, 'profile_iphoneSE_settings_empty.png') });
  check(row(s).text === 'ADD YOUR NAME (OPTIONAL)' && row(s).zone && row(s).rect[1] > 0 && row(s).rect[3] < 1,
    `Q[SE] Settings shows the optional name row on screen ("${row(s).text}")`);
  let r = await enterName(g, 'דנה כהן', 'profile_iphoneSE_dialog_hebrew.png');
  check(r.facts.focused && r.facts.dir === 'auto' && r.facts.fontPx >= 16 && r.facts.top < r.facts.h * 0.35,
    `Q[SE] the native field opens focused (keyboard), dir=auto, ${r.facts.fontPx}px, near the top (y ${Math.round(r.facts.top)} of ${r.facts.h})`);
  check(prof(r.s).name === 'דנה כהן' && row(r.s).text.includes('דנה כהן') && row(r.s).note === 'Name saved', `Q[SE] a Hebrew name is saved and shown ("${row(r.s).text}")`);
  await g.page.screenshot({ path: path.join(shots, 'profile_iphoneSE_settings_hebrew.png') });
  r = await enterName(g, 'Dana😀', 'profile_iphoneSE_dialog_emoji.png');
  check(prof(r.s).name === 'דנה כהן' && /letters, numbers/.test(row(r.s).note), `Q[SE] an emoji name is refused with a reason ("${row(r.s).note}"), the old name kept`);
  await g.page.screenshot({ path: path.join(shots, 'profile_iphoneSE_settings_refused.png') });
  check(r.facts.draft === 'דנה כהן', 'Q[SE] the field opens with the current name');
  r = await enterName(g, 'José', null);
  check(prof(r.s).name === 'José' && prof(r.s).name.length === 4, `Q[SE] NFC: "e + combining acute" is saved as one "é" (${[...prof(r.s).name].map((c) => c.codePointAt(0).toString(16)).join(' ')})`);
  r = await enterName(g, 'Someone Else', null, true);
  check(prof(r.s).name === 'José', 'Q[SE] CANCEL changes nothing');
  r = await enterName(g, '   ', null);
  check(prof(r.s).name === '' && row(r.s).text === 'ADD YOUR NAME (OPTIONAL)' && row(r.s).note === 'Name removed', 'Q[SE] an empty name removes it');
  r = await enterName(g, 'דנה כהן', null);
  await closeSettings(g);
  await g.ctx.close();
  // reload (same browser profile, no reset): same id and name
  g = await startQA(6, profile, 'iphoneSE', false);
  s = await state(g);
  check(prof(s).id_hash === H && prof(s).name === 'דנה כהן', `Q[SE] after a reload: the same id (${prof(s).id_hash}) and name`);
  await g.ctx.close();

  // ===== Q: iPhone 14 (Arabic) and Pro Max (English) =====
  for (const [size, name] of [['iphone14', 'محمد'], ['promax', "Alex O'Neil"]]) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ce-prof-'));
    g = await startQA(6, dir, size, true);
    s = await openSettings(g);
    await sleep(300);
    r = await enterName(g, name, `profile_${size}_dialog.png`);
    check(r.facts.focused && r.facts.top < r.facts.h * 0.35 && prof(r.s).name === name && row(r.s).text.includes(name),
      `Q[${size}] the native field opens focused near the top; "${name}" is saved and shown`);
    await g.page.screenshot({ path: path.join(shots, `profile_${size}_settings_name.png`) });
    const rr = row(r.s).rect;
    check(rr[0] >= 0 && rr[2] <= 1 && rr[1] >= 0 && rr[3] <= 1, `Q[${size}] the name row fits the screen (${rr.map((v) => v.toFixed(3))})`);
    await g.ctx.close();
  }

  // ===== R: rollback to the previous QA build and forward again =====
  if (oldQa) {
    qaServing = 'old';
    g = await open(QA + '?experiencelab=6', profile, 'iphoneSE');
    s = await waitFor(g, (x) => x.level === 6 && x.lab_qa && !x.title_open && !x.intro_open, 'old QA 6');
    await sleep(900);
    check(s.player_identity === undefined, 'R: the previous QA build (no identity) opens the same QA save');
    const before = await g.page.evaluate((k) => localStorage.getItem(k) || '', QAKEY);
    // clear the level (debug auto-solve, QA builds only): the old build saves the result
    await g.page.focus('canvas').catch(() => {});
    await g.page.keyboard.press('F1'); await sleep(250);
    await g.page.keyboard.press('s');
    await waitFor(g, (x) => x.card_open && x.level === 6, 'old build clears 6', 120000);
    await g.page.keyboard.press('F1');
    await sleep(1500);
    const after = await g.page.evaluate((k) => localStorage.getItem(k) || '', QAKEY);
    const seqOf = (t) => Number((/seq=(\d+)/.exec(t) || [0, 0])[1]);
    check(seqOf(after) > seqOf(before) && after.includes('[profile]') && after.includes('name="דנה כהן"'),
      `R: the previous build cleared Level 6 and saved (seq ${seqOf(before)} -> ${seqOf(after)}) and kept the [profile] section`);
    await g.ctx.close();
    qaServing = 'qa';
    g = await startQA(6, profile, 'iphoneSE', false);
    s = await state(g);
    check(prof(s).id_hash === H && prof(s).name === 'דנה כהן', 'R: forward again - the new build finds the same id and name');
    await g.ctx.close();
  } else {
    check(false, 'R: no previous QA build given (3rd argument)');
  }

  // ===== I: isolation =====
  g = await startQA(6, profile, 'iphoneSE', false);
  const st = await g.page.evaluate(([a, b, c]) => ({ r2: localStorage.getItem(a), old: localStorage.getItem(b), qa: localStorage.getItem(c) || '' }), [R2, OLD, QAKEY]);
  check(st.r2 === SENTINEL_R2 && st.old === SENTINEL_OLD, 'I: the release save (r2) and the old save are byte-identical after every QA session');
  check(st.qa.includes('[profile]'), `I: only the QA save (${QAKEY}) holds the profile`);
  await g.ctx.close();

  // ===== P: the player build - identity off =====
  g = await open(PROD, fs.mkdtempSync(path.join(os.tmpdir(), 'ce-prof-')), 'iphoneSE');
  s = await waitFor(g, (x) => x.title_open, 'prod title');
  await tapFrac(g, s.title_continue[0], s.title_continue[1]);
  s = await waitFor(g, (x) => !x.title_open && x.level === 1, 'prod level 1');
  await sleep(800);
  await tapFrac(g, s.settings_button[0], s.settings_button[1]);
  s = await waitFor(g, (x) => x.settings_open, 'prod settings', 8000);
  await sleep(300);
  await g.page.screenshot({ path: path.join(shots, 'profile_player_build_settings.png') });
  const prodSave = await g.page.evaluate((k) => localStorage.getItem(k) || '', R2);
  check(s.player_build && s.player_identity === false && Object.keys(s.profile || {}).length === 0,
    'P: the player build has no identity (no id, no name row in the state)');
  check(prodSave.includes('[meta]') && !prodSave.includes('[profile]'), 'P: the release save gets no [profile] section');
  await g.ctx.close();
} catch (e) {
  check(false, 'test run: ' + e.message);
}
check(errors.length === 0, `E: no page errors (${errors.length}${errors.length ? ': ' + errors.slice(0, 3).join(' | ') : ''})`);
server.close();
const failed = results.filter((x) => !x[0]).length;
console.log(`\n${results.length - failed}/${results.length} checks passed`);
process.exit(failed ? 1 : 0);
