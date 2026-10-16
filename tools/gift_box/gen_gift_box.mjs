// Renders the Photo / Message Reveal gift box (plum + rose gold) into three
// layered PNGs that SocialReveal.RevealEnvelope moves as rigid pieces:
//   assets/reveal/gift_body_back.png   the box's open inside (behind the envelope)
//   assets/reveal/gift_body_front.png  its two front walls with the ribbon (in front)
//   assets/reveal/gift_lid.png         the lid with its ribbon and bow (one piece)
// Coordinates are gift-local game units, origin at the centre of the body's
// open top; LAYERS below are mirrored in social_reveal.gd (GIFT_*_RECT).
// Usage: node tools/gift_box/gen_gift_box.mjs [--preview=out.png]
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT || 'playwright');

const SCALE = 2.25;  // texture pixels per game unit (sharp at 1.3x on 3x iPhones)
const OUT = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../../assets/reveal');

// ---- Geometry: an oblique 3/4 view, the left wall turned towards the viewer.
const add = (a, b) => [a[0] + b[0], a[1] + b[1]];
const mul = (a, k) => [a[0] * k, a[1] * k];
const lerp = (a, b, k) => [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k];
const L = [-220, -88], R = [178, -92], HB = 150, HL = 50, LIFT = 5, GROW = 1.05;
const F1 = [21, 90];                      // top front corner of the body
const F0 = add(F1, [0, HB]);              // bottom front corner
const top = { f: F1, l: add(F1, L), b: add(add(F1, L), R), r: add(F1, R) };
const scaleC = (p, k) => mul(p, k);      // the origin is the top's centre
const lid = Object.fromEntries(Object.entries(top).map(([k, p]) => [k, add(scaleC(p, GROW), [0, -LIFT])]));
const down = (p, h) => add(p, [0, h]);
const P = (...pts) => pts.map((p) => p[0].toFixed(2) + ',' + p[1].toFixed(2)).join(' ');
const RIB = 40;                            // ribbon width (game units along the wall)
const sL = [0.5 - RIB / 2 / Math.hypot(...L), 0.5 + RIB / 2 / Math.hypot(...L)];
const sR = [0.5 - RIB / 2 / Math.hypot(...R), 0.5 + RIB / 2 / Math.hypot(...R)];

const C = { plumHi: '#9C4C7E', plum: '#7C2F5F', plumMid: '#6A2752', plumDeep: '#541D42', plumDark: '#3F1534', inside: '#2C0E23',
  edge: '#C27BAA', rg0: '#FBE3D2', rg1: '#F1C4A8', rg2: '#DFA184', rg3: '#C27E62', rg4: '#9C5C45', rgEdge: '#A3644B' };

const defs = `<defs>
  <filter id="grain" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency="1.1" numOctaves="2" seed="7" result="n"/>
    <feColorMatrix type="matrix" values="0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 .55 -.18"/></filter>
  <filter id="soft" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="7"/></filter>
  <filter id="soft2" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="2.2"/></filter>
  <linearGradient id="leftWall" gradientUnits="userSpaceOnUse" x1="-199" y1="0" x2="21" y2="0"><stop offset="0" stop-color="${C.plum}"/><stop offset=".55" stop-color="${C.plumMid}"/><stop offset="1" stop-color="${C.plumDeep}"/></linearGradient>
  <linearGradient id="leftShade" gradientUnits="userSpaceOnUse" x1="0" y1="80" x2="0" y2="250"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".07"/><stop offset="1" stop-color="#000000" stop-opacity=".22"/></linearGradient>
  <linearGradient id="rightWall" gradientUnits="userSpaceOnUse" x1="21" y1="0" x2="199" y2="0"><stop offset="0" stop-color="${C.plumDeep}"/><stop offset="1" stop-color="${C.plumDark}"/></linearGradient>
  <linearGradient id="lidTop" gradientUnits="userSpaceOnUse" x1="-180" y1="-80" x2="100" y2="90"><stop offset="0" stop-color="${C.plumHi}"/><stop offset=".55" stop-color="${C.plum}"/><stop offset="1" stop-color="${C.plumMid}"/></linearGradient>
  <linearGradient id="sheen" gradientUnits="userSpaceOnUse" x1="-200" y1="-60" x2="120" y2="80"><stop offset="0" stop-color="#FFFFFF" stop-opacity="0"/><stop offset=".38" stop-color="#FFFFFF" stop-opacity=".10"/><stop offset=".5" stop-color="#FFFFFF" stop-opacity="0"/></linearGradient>
  <linearGradient id="inside" gradientUnits="userSpaceOnUse" x1="0" y1="-90" x2="0" y2="90"><stop offset="0" stop-color="#4A1A40"/><stop offset=".5" stop-color="${C.inside}"/><stop offset="1" stop-color="#1E0819"/></linearGradient>
  <linearGradient id="ribV" gradientUnits="objectBoundingBox" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${C.rg2}"/><stop offset=".15" stop-color="${C.rg1}"/><stop offset=".6" stop-color="${C.rg1}"/><stop offset=".85" stop-color="${C.rg2}"/><stop offset="1" stop-color="${C.rg3}"/></linearGradient>
  <linearGradient id="ribVdark" gradientUnits="objectBoundingBox" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${C.rg3}"/><stop offset=".25" stop-color="${C.rg2}"/><stop offset=".7" stop-color="${C.rg2}"/><stop offset="1" stop-color="${C.rg3}"/></linearGradient>
  <radialGradient id="lidGlow" gradientUnits="userSpaceOnUse" cx="-70" cy="-40" r="170"><stop offset="0" stop-color="#FFFFFF" stop-opacity=".16"/><stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/></radialGradient>
  <linearGradient id="ribDown" gradientUnits="objectBoundingBox" x1="0" y1="0" x2=".35" y2="1"><stop offset="0" stop-color="#FFF8F2" stop-opacity=".45"/><stop offset=".35" stop-color="#FFF8F2" stop-opacity=".08"/><stop offset=".55" stop-color="#FFF8F2" stop-opacity=".22"/><stop offset=".75" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#3A1020" stop-opacity=".22"/></linearGradient>
  <linearGradient id="loopL" gradientUnits="objectBoundingBox" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${C.rg2}"/><stop offset=".3" stop-color="${C.rg0}"/><stop offset=".55" stop-color="${C.rg1}"/><stop offset=".8" stop-color="${C.rg2}"/><stop offset="1" stop-color="${C.rg3}"/></linearGradient>
  <linearGradient id="loopR" gradientUnits="objectBoundingBox" x1="1" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${C.rg2}"/><stop offset=".28" stop-color="${C.rg0}"/><stop offset=".5" stop-color="${C.rg1}"/><stop offset=".8" stop-color="${C.rg3}"/><stop offset="1" stop-color="${C.rg4}"/></linearGradient>
  <linearGradient id="loopIn" gradientUnits="objectBoundingBox" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${C.rg4}"/><stop offset="1" stop-color="${C.rg3}"/></linearGradient>
  <linearGradient id="tail" gradientUnits="objectBoundingBox" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${C.rg1}"/><stop offset=".45" stop-color="${C.rg0}"/><stop offset="1" stop-color="${C.rg3}"/></linearGradient>
  <radialGradient id="knot" cx=".38" cy=".32" r=".8"><stop offset="0" stop-color="${C.rg0}"/><stop offset=".5" stop-color="${C.rg1}"/><stop offset="1" stop-color="${C.rg3}"/></radialGradient>
</defs>`;

// A ribbon band on a wall (a parallelogram between params s0..s1 along `axis`, from `a` up to `b`).
function band(base, axis, s, h, fill, extra = '') {
  const p0 = add(base, mul(axis, s[0])), p1 = add(base, mul(axis, s[1]));
  const pts = [p0, p1, down(p1, h), down(p0, h)];
  return `<polygon points="${P(...pts)}" fill="${fill}" ${extra}/>` + (fill.startsWith('url') ? `<polygon points="${P(...pts)}" fill="url(#ribDown)"/>` : '')
    + `<polyline points="${P(pts[0], pts[3])}" stroke="${C.rgEdge}" stroke-width="1.1" fill="none" opacity=".8"/>`
    + `<polyline points="${P(pts[1], pts[2])}" stroke="${C.rgEdge}" stroke-width="1.1" fill="none" opacity=".8"/>`;
}
const grain = (clip) => `<g clip-path="url(#${clip})"><rect x="-300" y="-300" width="600" height="600" filter="url(#grain)" opacity=".5"/></g>`;

// ---- Body, inside: the open top (seen when the lid is off), behind the envelope.
function bodyBack() {
  const k = 0.955, i = Object.fromEntries(Object.entries(top).map(([n, p]) => [n, mul(p, k)]));
  let s = `<polygon points="${P(top.f, top.l, top.b, top.r)}" fill="${C.plumDeep}"/>`;   // the rim
  s += `<polygon points="${P(i.f, i.l, i.b, i.r)}" fill="url(#inside)"/>`;
  // The far inner walls, lit a little from above.
  s += `<clipPath id="in"><polygon points="${P(i.f, i.l, i.b, i.r)}"/></clipPath><g clip-path="url(#in)">`;
  s += `<polygon points="${P(i.l, i.b, down(i.b, 70), down(i.l, 70))}" fill="#5B2250" opacity=".9"/>`;
  s += `<polygon points="${P(i.b, i.r, down(i.r, 70), down(i.b, 70))}" fill="#46183D" opacity=".9"/>`;
  s += `<polygon points="${P(down(i.l, 70), down(i.b, 70), down(i.r, 70), i.r, i.f, i.l)}" fill="#000000" opacity=".18"/></g>`;
  s += `<polyline points="${P(top.l, top.b, top.r)}" stroke="${C.edge}" stroke-width="1.6" fill="none" opacity=".55"/>`;
  return s;
}

// ---- Body, front: the two walls the viewer sees, their ribbon, the rim's front edge.
function bodyFront() {
  const lw = [F0, add(F0, L), top.l, F1], rw = [F0, add(F0, R), top.r, F1];
  let s = `<clipPath id="lw"><polygon points="${P(...lw)}"/></clipPath><clipPath id="rw"><polygon points="${P(...rw)}"/></clipPath>`;
  s += `<polygon points="${P(...lw)}" fill="url(#leftWall)"/><polygon points="${P(...lw)}" fill="url(#leftShade)"/>${grain('lw')}`;
  s += `<polygon points="${P(...rw)}" fill="url(#rightWall)"/><polygon points="${P(...rw)}" fill="#000" opacity=".1"/>${grain('rw')}`;
  s += band(F1, L, sL, HB, 'url(#ribV)') + `<g opacity=".18">${band(F1, L, sL, HB, '#000')}</g>`;
  s += band(F1, R, sR, HB, 'url(#ribVdark)') + `<g opacity=".32">${band(F1, R, sR, HB, '#000')}</g>`;
  // Edge highlights: the front corner, the rim (the cut edge of the walls).
  s += `<line x1="${F1[0]}" y1="${F1[1]}" x2="${F0[0]}" y2="${F0[1] - 2}" stroke="${C.edge}" stroke-width="1.6" opacity=".55"/>`;
  s += `<polyline points="${P(top.l, F1, top.r)}" stroke="${C.edge}" stroke-width="2" fill="none" opacity=".7" stroke-linejoin="round"/>`;
  s += `<polyline points="${P(add(F0, L), F0, add(F0, R))}" stroke="#2A0C24" stroke-width="2" fill="none" opacity=".5" stroke-linejoin="round"/>`;
  return s;
}

// ---- Lid: top, two skirts, ribbon bands crossing at the centre, the bow.
function lidLayer() {
  const Lp = mul(L, GROW), Rp = mul(R, GROW);
  const lsk = [lid.f, lid.l, down(lid.l, HL), down(lid.f, HL)], rsk = [lid.f, lid.r, down(lid.r, HL), down(lid.f, HL)];
  const tp = [lid.f, lid.l, lid.b, lid.r];
  let s = `<clipPath id="lt"><polygon points="${P(...tp)}"/></clipPath><clipPath id="lsk"><polygon points="${P(...lsk)}"/></clipPath><clipPath id="rsk"><polygon points="${P(...rsk)}"/></clipPath>`;
  // A soft contact shadow the lid casts on the walls just below its skirt.
  s += `<polygon points="${P(down(lid.l, HL - 4), down(lid.f, HL - 4), down(lid.r, HL - 4), down(lid.r, HL + 10), down(lid.f, HL + 12), down(lid.l, HL + 10))}" fill="#1A0616" opacity=".45" filter="url(#soft2)"/>`;
  s += `<polygon points="${P(...lsk)}" fill="url(#leftWall)"/><polygon points="${P(...lsk)}" fill="#FFF" opacity=".06"/>${grain('lsk')}`;
  s += `<polygon points="${P(...rsk)}" fill="url(#rightWall)"/>${grain('rsk')}`;
  s += `<polygon points="${P(...tp)}" fill="url(#lidTop)"/><polygon points="${P(...tp)}" fill="url(#sheen)"/><polygon points="${P(...tp)}" fill="url(#lidGlow)"/>${grain('lt')}`;
  // Ribbon over the skirts (continuing the body's bands) and across the top.
  s += band(lid.f, Lp, sL, HL, 'url(#ribV)') + `<g opacity=".12">${band(lid.f, Lp, sL, HL, '#000')}</g>`;
  s += band(lid.f, Rp, sR, HL, 'url(#ribVdark)') + `<g opacity=".3">${band(lid.f, Rp, sR, HL, '#000')}</g>`;
  const a0 = add(lid.f, mul(Lp, sL[0])), a1 = add(lid.f, mul(Lp, sL[1]));
  const bandA = [a0, a1, add(a1, Rp), add(a0, Rp)];
  const b0 = add(lid.f, mul(Rp, sR[0])), b1 = add(lid.f, mul(Rp, sR[1]));
  const bandB = [b0, b1, add(b1, Lp), add(b0, Lp)];
  s += `<linearGradient id="bandA" gradientUnits="userSpaceOnUse" x1="${a0[0]}" y1="${a0[1]}" x2="${a1[0]}" y2="${a1[1]}"><stop offset="0" stop-color="${C.rg3}"/><stop offset=".3" stop-color="${C.rg1}"/><stop offset=".5" stop-color="${C.rg0}"/><stop offset=".75" stop-color="${C.rg1}"/><stop offset="1" stop-color="${C.rg3}"/></linearGradient>`;
  s += `<linearGradient id="bandB" gradientUnits="userSpaceOnUse" x1="${b0[0]}" y1="${b0[1]}" x2="${b1[0]}" y2="${b1[1]}"><stop offset="0" stop-color="${C.rg3}"/><stop offset=".35" stop-color="${C.rg0}"/><stop offset=".65" stop-color="${C.rg1}"/><stop offset="1" stop-color="${C.rg3}"/></linearGradient>`;
  const edges = (q) => `<polyline points="${P(q[0], q[3])}" stroke="${C.rgEdge}" stroke-width="1.1" fill="none" opacity=".75"/><polyline points="${P(q[1], q[2])}" stroke="${C.rgEdge}" stroke-width="1.1" fill="none" opacity=".75"/>`;
  s += `<polygon points="${P(...bandA)}" fill="url(#bandA)"/>${edges(bandA)}`;
  s += `<polygon points="${P(...bandB)}" fill="#3A1030" opacity=".35" transform="translate(0 2)" filter="url(#soft2)"/>`;
  s += `<polygon points="${P(...bandB)}" fill="url(#bandB)"/>${edges(bandB)}`;
  // Edge highlights of the lid.
  s += `<polyline points="${P(lid.l, lid.b, lid.r)}" stroke="${C.edge}" stroke-width="1.4" fill="none" opacity=".45"/>`;
  s += `<polyline points="${P(lid.l, lid.f, lid.r)}" stroke="#E6A9CF" stroke-width="2.2" fill="none" opacity=".75" stroke-linejoin="round"/>`;
  s += `<line x1="${lid.f[0]}" y1="${lid.f[1]}" x2="${lid.f[0]}" y2="${lid.f[1] + HL}" stroke="${C.edge}" stroke-width="1.6" opacity=".6"/>`;
  s += `<polyline points="${P(down(lid.l, HL), down(lid.f, HL), down(lid.r, HL))}" stroke="#2A0C24" stroke-width="1.6" fill="none" opacity=".45"/>`;
  s += bow([0, -LIFT - 4]);
  return s;
}

// The bow, seen face on: two satin loops (outer face, the darker inside
// showing in a narrow fold near the knot, crease highlights), two tails with
// V-cut ends draped towards the front, and the knot.
function bow(k) {
  const [x, y] = k;
  const g = (d) => d.replace(/([-\d.]+),([-\d.]+)/g, (_, a, b) => `${(+a + x).toFixed(1)},${(+b + y).toFixed(1)}`);
  const ln = (d, col, w, op) => `<path d="${g(d)}" stroke="${col}" stroke-width="${w}" fill="none" opacity="${op}" stroke-linecap="round"/>`;
  let s = `<ellipse cx="${x + 8}" cy="${y + 20}" rx="92" ry="20" fill="#1A0616" opacity=".3" filter="url(#soft)"/>`;
  // Tails (behind the loops), lying on the lid towards the front corners.
  s += `<path d="${g('M-12,4 C-30,28 -58,54 -92,80 L-72,84 L-66,104 C-40,78 -16,46 10,12 Z')}" fill="url(#tail)" stroke="${C.rgEdge}" stroke-width="1"/>`;
  s += ln('M-6,12 C-24,36 -46,58 -76,90', C.rg3, 1.4, .55);
  s += `<path d="${g('M8,4 C30,26 62,48 100,62 L84,76 L92,94 C58,74 32,50 -6,14 Z')}" fill="url(#tail)" stroke="${C.rgEdge}" stroke-width="1"/>`;
  s += ln('M4,12 C28,34 54,54 88,76', C.rg0, 1.6, .7);
  // Left loop: rises up and out to the left.
  s += `<path d="${g('M-6,-6 C-38,-48 -108,-76 -140,-52 C-160,-36 -152,-6 -128,4 C-96,16 -50,14 -6,6 Z')}" fill="url(#loopL)" stroke="${C.rgEdge}" stroke-width="1.1"/>`;
  s += `<path d="${g('M-14,-1 C-46,-22 -98,-38 -124,-28 C-112,-18 -76,-6 -14,3 Z')}" fill="url(#loopIn)" opacity=".9"/>`;
  s += ln('M-22,-22 C-58,-56 -110,-68 -138,-48', '#FFF6EF', 2.6, .75);
  s += ln('M-30,-10 C-70,-30 -110,-40 -132,-30', C.rg3, 1.4, .45);
  s += ln('M-24,8 C-60,12 -100,10 -126,2', C.rg4, 1.2, .5);
  // Right loop: a little smaller and lower (it turns away from the viewer).
  s += `<path d="${g('M6,-6 C34,-44 98,-66 128,-44 C146,-30 138,-4 116,6 C86,16 46,14 6,6 Z')}" fill="url(#loopR)" stroke="${C.rgEdge}" stroke-width="1.1"/>`;
  s += `<path d="${g('M14,-1 C44,-20 90,-32 114,-22 C102,-12 70,-4 14,3 Z')}" fill="url(#loopIn)" opacity=".85"/>`;
  s += ln('M22,-22 C56,-52 104,-58 126,-40', '#FFF6EF', 2.4, .7);
  s += ln('M24,8 C58,12 92,10 116,4', C.rg4, 1.2, .5);
  // Knot: a short wrapped band with two soft folds.
  s += `<path d="${g('M-16,-14 C-10,-19 10,-19 16,-14 C20,-4 20,8 16,15 C9,20 -9,20 -16,15 C-20,8 -20,-4 -16,-14 Z')}" fill="url(#knot)" stroke="${C.rgEdge}" stroke-width="1.1"/>`;
  s += ln('M-8,-12 C-10,-3 -10,8 -7,15', C.rg4, 1.2, .45) + ln('M5,-13 C7,-4 7,7 4,15', C.rg4, 1.2, .45);
  s += ln('M-11,-12 C-4,-15 6,-15 11,-12', '#FFF4EC', 1.8, .85);
  return s;
}

// Layer rects (gift-local game units): x, y, w, h. Keep in sync with social_reveal.gd.
const LAYERS = {
  gift_body_back: { rect: [-203, -95, 406, 188], svg: bodyBack },
  gift_body_front: { rect: [-203, -7, 406, 252], svg: bodyFront },
  gift_lid: { rect: [-217, -104, 434, 263], svg: lidLayer },
};

const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: SCALE, viewport: { width: 800, height: 800 } });
fs.mkdirSync(OUT, { recursive: true });
for (const [name, { rect, svg }] of Object.entries(LAYERS)) {
  const [x, y, w, h] = rect;
  await page.setContent(`<html><body style="margin:0;background:transparent"><svg id="s" xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="${x} ${y} ${w} ${h}">${defs}${svg()}</svg></body></html>`);
  await page.locator('#s').screenshot({ path: path.join(OUT, name + '.png'), omitBackground: true });
  console.log(`${name}: Rect2(${x}, ${y}, ${w}, ${h}) -> ${Math.round(w * SCALE)}x${Math.round(h * SCALE)} px`);
}
const prev = (process.argv.find((a) => a.startsWith('--preview=')) || '').slice(10);
if (prev) {
  const img = (n) => 'data:image/png;base64,' + fs.readFileSync(path.join(OUT, n + '.png')).toString('base64');
  const lay = (n) => { const [x, y, w, h] = LAYERS[n].rect; return `<img src="${img(n)}" style="position:absolute;left:${x + 300}px;top:${y + 300}px;width:${w}px;height:${h}px">`; };
  await page.setViewportSize({ width: 600, height: 600 });
  await page.setContent(`<body style="margin:0;background:linear-gradient(#F4EEFB,#E9DFF6)"><div style="position:relative;width:600px;height:600px">${lay('gift_body_back')}${lay('gift_body_front')}${lay('gift_lid')}</div></body>`);
  await page.screenshot({ path: prev });
}
await browser.close();
