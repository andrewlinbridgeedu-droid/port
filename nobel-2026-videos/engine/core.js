// Timeline, transitions and the overlays every film shares: chapter cards,
// subtitles, title and closing cards.
import * as L from './lib.js';
const { W, H, clamp, ease, text, reveal, F, rgba, smooth } = L;

const XF = 1.1;            // cross-fade between scenes (s)
const CHAPTER_LEAD = 3.2;  // must match tools/tts.py

export const G = { L, W, H, F };
let S, TL, MOD, spans, ctx, off, octx, chunks, chapters;

export async function setup(id) {
  S = await (await fetch(`../scripts/${id}.json`)).json();
  TL = await (await fetch(`../build/${id}/timeline.json`)).json();
  MOD = (await import(`./scenes/${id}.js`)).default;
  const canvas = document.getElementById('c');
  ctx = canvas.getContext('2d');
  off = document.createElement('canvas'); off.width = W; off.height = H; octx = off.getContext('2d');
  G.S = S; G.TL = TL; G.pal = MOD.palette || {};

  // load only the glyphs we use, for every face we use
  const src = [JSON.stringify(S), JSON.stringify(TL), await (await fetch(`./scenes/${id}.js`)).text(), await (await fetch('./core.js')).text(), await (await fetch('./lib.js')).text()].join('');
  const chars = [...new Set([...src])].join('') + '0123456789０１２３４５６７８９ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  const faces = ['400 40px "Noto Serif SC"', '500 40px "Noto Serif SC"', '600 40px "Noto Serif SC"', '700 40px "Noto Serif SC"', '900 40px "Noto Serif SC"',
    '400 40px "LXGW WenKai"', '700 40px "LXGW WenKai"', '400 40px "Ma Shan Zheng"', '400 40px "ZCOOL XiaoWei"',
    '500 40px "Cormorant Garamond"', '600 40px "Cormorant Garamond"', 'italic 500 40px "Cormorant Garamond"', '400 40px "Noto Serif"', 'italic 400 40px "Noto Serif"', '600 40px "Noto Serif"'];
  await Promise.all(faces.map(f => document.fonts.load(f, chars).catch(() => null)));
  await document.fonts.ready;

  // merge consecutive beats that share a scene into spans
  spans = [];
  TL.beats.forEach((b, i) => {
    const last = spans[spans.length - 1];
    if (last && last.scene === b.scene && !b.chapter) { last.t1 = b.t1; last.lines.push(...b.lines); last.beats.push(b); }
    else spans.push({ scene: b.scene, t0: b.t0, t1: b.t1, lines: [...b.lines], beats: [b], chapter: b.chapter });
  });
  spans[spans.length - 1].t1 = TL.duration + 10;
  spans.forEach((sp, i) => {
    sp.idx = i; sp.dur = sp.t1 - sp.t0;
    sp.cue = k => (sp.lines[Math.min(k, sp.lines.length - 1)]?.t0 ?? sp.t0) - sp.t0;
    sp.cueEnd = k => (sp.lines[Math.min(k, sp.lines.length - 1)]?.t1 ?? sp.t1) - sp.t0;
    sp.speechEnd = (sp.lines.length ? sp.lines[sp.lines.length - 1].t1 : sp.t1) - sp.t0;
  });
  chapters = TL.beats.filter(b => b.chapter).map(b => ({ t0: b.t0, num: b.chapter[0], name: b.chapter[1] }));
  chunks = buildChunks(TL.beats.flatMap(b => b.lines));
  if (MOD.init) await MOD.init(G);
  return { duration: TL.duration, spans: spans.length };
}

// --- subtitles ---------------------------------------------------------------
const W1 = c => (/[一-鿿　-〿＀-￯“”《》—…·]/.test(c) ? 1 : 0.55);
function buildChunks(lines) {
  const out = [];
  const MAX = 21;
  for (const l of lines) {
    // split into clauses, remembering the punctuation that ended each
    const parts = []; let cur = '', book = 0;
    for (const c of [...l.text]) {
      if (c === '《') book++; if (c === '》') book--;
      if (!book && ('，。；：！？、'.includes(c) || c === '—')) {
        if (c === '—') { if (cur.endsWith('—') || cur === '') { cur = cur.replace(/—$/, ''); } else { cur += '—'; continue; } }
        parts.push({ s: cur.replace(/—$/, ''), p: c === '—' ? '—' : c }); cur = '';
      } else cur += c;
    }
    if (cur.trim()) parts.push({ s: cur, p: '' });
    const clean = parts.filter(p => p.s.trim());
    // greedy pack clauses into subtitle cards
    const cards = []; let card = [];
    const len = arr => arr.reduce((a, p) => a + [...p.s].reduce((x, c) => x + W1(c), 0) + 1, 0);
    for (const p of clean) {
      if (card.length && len([...card, p]) > MAX) { cards.push(card); card = []; }
      card.push(p);
      if ('。！？；'.includes(p.p) && len(card) > MAX * 0.55) { cards.push(card); card = []; }
    }
    if (card.length) cards.push(card);
    const weight = cards.map(cd => len(cd) + cd.length * 1.2);
    const tot = weight.reduce((a, b) => a + b, 0);
    let t = l.t0; const D = l.t1 - l.t0;
    cards.forEach((cd, i) => {
      const d = D * weight[i] / tot;
      const s = cd.map((p, j) => p.s + (j < cd.length - 1 ? ('？！'.includes(p.p) ? p.p + ' ' : (p.p === '、' ? '、' : '　')) : ('？！'.includes(p.p) ? p.p : ''))).join('');
      out.push({ t0: t, t1: t + d, s });
      t += d;
    });
  }
  return out;
}
function drawSubs(t) {
  const c = chunks.find(c => t >= c.t0 - 0.05 && t < c.t1 + 0.18);
  if (!c) return;
  const a = smooth(c.t0 - 0.05, c.t0 + 0.12, t) * (1 - smooth(c.t1 + 0.02, c.t1 + 0.18, t));
  text(ctx, c.s, W / 2, H - 92, { size: 46, weight: 600, color: '#f6f2e8', alpha: a, spacing: 2, stroke: 7, strokeColor: 'rgba(0,0,0,0.55)', glow: 18, glowColor: 'rgba(0,0,0,0.9)' });
}

// --- chapter cards -------------------------------------------------------------
function drawChapter(t) {
  const pal = G.pal; const gold = pal.gold || '#e8c477';
  let cur = null;
  for (const c of chapters) if (t >= c.t0) cur = c;
  if (!cur) return;
  const k = t - cur.t0;
  const a = smooth(0.15, 0.9, k) * (1 - smooth(CHAPTER_LEAD - 0.5, CHAPTER_LEAD + 0.4, k));
  if (a > 0.003) {
    ctx.save(); ctx.globalAlpha = a * 0.55; ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H); ctx.restore();
    const e = ease.out(clamp((k - 0.15) / 1.2));
    text(ctx, cur.num, W / 2, 420, { size: 170, font: F.brush, weight: 400, color: gold, alpha: a, glow: 40, glowColor: rgba(gold, 0.8) });
    reveal(ctx, cur.name, W / 2, 590, clamp((k - 0.35) / 1.1), { size: 68, weight: 700, color: '#fbf6ea', spacing: 18, alpha: a, glow: 12, glowColor: rgba(gold, 0.6), spread: 0.5 });
    const lw = 260 * e;
    L.line(ctx, [[W / 2 - 60 - lw, 680], [W / 2 - 60, 680]], gold, 1.5, a * 0.8);
    L.line(ctx, [[W / 2 + 60, 680], [W / 2 + 60 + lw, 680]], gold, 1.5, a * 0.8);
    L.dot(ctx, W / 2, 680, 4, gold, a);
  }
  // small running tag
  const tagA = smooth(CHAPTER_LEAD + 0.2, CHAPTER_LEAD + 1.2, k) * 0.78 * (1 - smooth(TL.duration - 14, TL.duration - 12, t)) * (finaleSpan(t) ? 0 : 1);
  if (tagA > 0.003) {
    text(ctx, `${cur.num} · ${cur.name}`, 72, 70, { size: 28, weight: 600, color: gold, align: 'left', alpha: tagA, spacing: 4, glow: 10, glowColor: 'rgba(0,0,0,0.9)' });
  }
}
const finaleSpan = t => { const sp = spans[spans.length - 1]; return t >= sp.t0 && sp.scene === 'finale'; };

// --- title / closing --------------------------------------------------------------
export function drawTitle(c, st, o = {}) {
  const gold = G.pal.gold || '#e8c477';
  const y0 = o.y ?? 0;
  const a1 = smooth(0.6, 1.8, st);
  text(c, S.prize, W / 2, 285 + y0, { size: 40, weight: 600, color: gold, spacing: 14, alpha: a1, glow: 18, glowColor: rgba(gold, 0.6) });
  text(c, S.prizeEn, W / 2, 338 + y0, { size: 22, font: F.latin, weight: 600, color: '#d9d2c0', spacing: 9, alpha: a1 * 0.75 });
  const g = c.createLinearGradient(0, 430 + y0, 0, 610 + y0); g.addColorStop(0, '#ffffff'); g.addColorStop(0.55, '#fff4dc'); g.addColorStop(1, gold);
  reveal(c, S.title, W / 2, 515 + y0, clamp((st - 1.3) / 1.8), { size: 168, weight: 900, color: g, spacing: 28, glow: 28, glowColor: rgba(o.glow || gold, 0.55), spread: 0.55, rise: 30 });
  reveal(c, S.subtitle, W / 2, 652 + y0, clamp((st - 2.6) / 1.4), { size: 46, weight: 500, color: '#efe9dc', spacing: 12, spread: 0.6 });
  const a3 = smooth(3.4, 4.4, st);
  L.line(c, [[W / 2 - 240 * a3, 718 + y0], [W / 2 + 240 * a3, 718 + y0]], gold, 1.2, a3 * 0.7);
  text(c, '获奖者　' + S.laureates, W / 2, 766 + y0, { size: 30, weight: 500, color: '#d8d0bf', spacing: 6, alpha: a3 * 0.9 });
  const a4 = smooth(4.3, 5.4, st);
  S.citation.forEach((s, i) => text(c, s, W / 2, 828 + i * 44 + y0, { size: 31, font: F.kai, weight: 400, color: '#cfc6b2', spacing: 3, alpha: a4 * 0.92 }));
}
function drawClosing(t) {
  const sp = spans[spans.length - 1];
  if (sp.scene !== 'finale') return;
  const k = t - (sp.t0 + sp.speechEnd + 0.5);
  if (k < 0) return;
  const gold = G.pal.gold || '#e8c477';
  ctx.save(); ctx.globalAlpha = smooth(0, 1.2, k) * 0.5; ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H); ctx.restore();
  const g = ctx.createLinearGradient(0, 430, 0, 520); g.addColorStop(0, '#ffffff'); g.addColorStop(1, gold);
  reveal(ctx, S.closing, W / 2, 470, clamp(k / 2.0), { size: 66, weight: 700, color: g, spacing: 10, glow: 22, glowColor: rgba(gold, 0.5), spread: 0.6 });
  const a2 = smooth(1.6, 2.6, k);
  text(ctx, S.prize, W / 2, 580, { size: 30, weight: 600, color: gold, spacing: 10, alpha: a2 });
  S.citation.forEach((s, i) => text(ctx, s, W / 2, 635 + i * 42, { size: 28, font: F.kai, color: '#d6cdb9', spacing: 2, alpha: a2 * 0.9 }));
  text(ctx, S.sources, W / 2, 1000, { size: 19, weight: 400, color: '#b9b2a4', alpha: smooth(2.4, 3.4, k) * 0.7, spacing: 1 });
}

// --- frame ------------------------------------------------------------------
function drawSpan(c, sp, t) {
  const fn = MOD.scenes[sp.scene];
  c.save();
  if (fn) fn(c, t - sp.t0, sp, G, t); else { c.fillStyle = '#000'; c.fillRect(0, 0, W, H); text(c, sp.scene, W / 2, H / 2, { size: 60 }); }
  c.restore();
}
export function renderAt(t) {
  let i = spans.findIndex(sp => t >= sp.t0 && t < sp.t1);
  if (i < 0) i = t < 0 ? 0 : spans.length - 1;
  const sp = spans[i], st = t - sp.t0;
  if (i > 0 && st < XF) {
    drawSpan(ctx, spans[i - 1], t);
    octx.clearRect(0, 0, W, H);
    drawSpan(octx, sp, t);
    ctx.save(); ctx.globalAlpha = ease.inOut(st / XF); ctx.drawImage(off, 0, 0); ctx.restore();
  } else drawSpan(ctx, sp, t);

  if (MOD.post) MOD.post(ctx, t, G);
  L.vignette(ctx, 0.55);
  // bottom band for legibility
  const band = ctx.createLinearGradient(0, H - 230, 0, H); band.addColorStop(0, 'rgba(0,0,0,0)'); band.addColorStop(1, 'rgba(0,0,0,0.5)');
  ctx.fillStyle = band; ctx.fillRect(0, H - 230, W, 230);
  drawChapter(t);
  // prize tag
  const tagA = smooth(spans[1].t0 + 1, spans[1].t0 + 2, t) * (finaleSpan(t) ? 1 - smooth(spans[spans.length - 1].t0, spans[spans.length - 1].t0 + 1, t) : 1);
  text(ctx, S.prize, W - 72, 70, { size: 26, weight: 600, color: G.pal.gold || '#e8c477', align: 'right', alpha: tagA * 0.62, spacing: 4, glow: 10, glowColor: 'rgba(0,0,0,0.9)' });
  drawClosing(t);
  drawSubs(t);
  // fade from / to black
  const fa = Math.max(1 - smooth(0, 1.2, t), smooth(TL.duration - 2.0, TL.duration - 0.1, t));
  if (fa > 0) { ctx.save(); ctx.globalAlpha = fa; ctx.fillStyle = '#000'; ctx.fillRect(0, 0, W, H); ctx.restore(); }
}
