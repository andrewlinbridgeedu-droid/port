// 播放器：读取影片定义与配音时间轴，按全局时间 T 画出一帧。
(function () {
  'use strict';
  const { W, H, clamp, env, subtitle, grain, vignette, bloom, text } = MP;
  const params = new URLSearchParams(location.search);
  const filmId = params.get('film');
  const canvas = document.getElementById('c');
  const ctx = canvas.getContext('2d');
  const off = document.createElement('canvas'); off.width = W; off.height = H; const octx = off.getContext('2d');
  const XF = 0.9; // 场景交叉淡化时长（秒）

  let film = null, TL = null;
  window.FILM = f => { film = f; };

  function loadScript(src) { return new Promise((res, rej) => { const s = document.createElement('script'); s.src = src; s.onload = res; s.onerror = rej; document.head.appendChild(s); }); }

  // 把一句配音按标点切成更短的字幕段，时间按字数比例分配
  function splitSub(line) {
    const maxLen = 26; const s = line.text;
    if ([...s].length <= maxLen) return [line];
    const parts = []; let cur = '';
    for (const ch of s) { cur += ch; if ('，。；：？！'.includes(ch) && [...cur].length >= 8) { parts.push(cur); cur = ''; } }
    if (cur) parts.push(cur);
    // 合并过短的段
    const merged = []; for (const p of parts) { if (merged.length && [...merged[merged.length - 1]].length + [...p].length <= maxLen) merged[merged.length - 1] += p; else merged.push(p); }
    const total = merged.reduce((a, p) => a + [...p].length, 0); let t = line.start; const out = [];
    merged.forEach((p, i) => { const d = (line.end - line.start) * [...p].length / total; out.push({ text: p.replace(/[，。；：]$/, ''), start: t, end: i === merged.length - 1 ? line.end : t + d }); t += d; });
    return out;
  }

  function sceneState(i, T, frame) {
    const sc = TL.scenes[i]; const t = T - sc.start;
    const cues = sc.lines.map(l => l.start - sc.start); const ends = sc.lines.map(l => l.end - sc.start);
    return { t, d: sc.dur, i, frame, T, cue: k => cues[Math.max(0, Math.min(cues.length - 1, k))] ?? 0, cend: k => ends[Math.max(0, Math.min(ends.length - 1, k))] ?? sc.dur, n: cues.length, film: TL };
  }

  function drawScene(c, i, T, frame) {
    const sc = TL.scenes[i]; const def = film.scenes[sc.id];
    if (!def) { c.fillStyle = '#200'; c.fillRect(0, 0, W, H); text(c, '缺少场景 ' + sc.id, W / 2, H / 2, { size: 60 }); return; }
    const st = sceneState(i, T, frame);
    c.save();
    const push = (film.noPush || []).includes(sc.id) ? 0 : (film.push ?? .03);
    if (push) { const k = 1 + push * MP.E.inOutSine(clamp(st.t / sc.dur)); c.translate(W / 2, H / 2); c.scale(k, k); c.translate(-W / 2, -H / 2); }
    def(c, st); c.restore();
    const ch = film.chapters && film.chapters[sc.id];
    if (ch) KIT.chapter(c, ch[0], ch[1], st.t, { color: film.accent, brand: film.brand, textColor: film.chapterText });
  }

  window.renderAt = function (T, frame = 0) {
    const S = TL.scenes; let i = S.findIndex(s => T >= s.start && T < s.start + s.dur); if (i < 0) i = T < 0 ? 0 : S.length - 1;
    ctx.globalCompositeOperation = 'source-over'; ctx.globalAlpha = 1; ctx.filter = 'none';
    drawScene(ctx, i, T, frame);
    const sc = S[i]; const tEnd = sc.start + sc.dur;
    if (i + 1 < S.length && T > tEnd - XF && !(film.cut || []).includes(S[i + 1].id)) {
      const p = clamp((T - (tEnd - XF)) / XF); octx.save(); octx.globalCompositeOperation = 'source-over'; drawScene(octx, i + 1, T, frame); octx.restore();
      ctx.save(); ctx.globalAlpha = p * p * (3 - 2 * p); ctx.drawImage(off, 0, 0); ctx.restore();
    }
    // 后期
    const post = film.post || {};
    if ((post.bloom ?? .5) > 0) bloom(ctx, canvas, post.bloom ?? .5, post.bloomBlur ?? 10);
    vignette(ctx, post.vignette ?? .5, post.vignetteColor || '#000');
    grain(ctx, frame, post.grain ?? .05);
    // 字幕
    if (!film.noSubs) for (const l of window.__subs) if (T >= l.start - .2 && T <= l.end + .2) subtitle(ctx, l, T, film.subStyle || {});
  };

  window.ready = (async () => {
    await loadScript(`../films/${filmId}.js`);
    TL = await (await fetch(`../assets/${filmId}/timeline.json`)).json();
    window.__TL = TL;
    window.__subs = TL.scenes.flatMap(s => s.lines.filter(l => !l.nosub)).flatMap(splitSub);
    const fams = ['Noto Serif SC', 'LXGW WenKai', 'LXGW WenKai Medium', 'Ma Shan Zheng', 'Zhi Mang Xing', 'Cormorant Garamond', 'Cormorant Garamond Italic', 'GFS Didot'];
    await Promise.all(fams.flatMap(f => [document.fonts.load(`400 40px "${f}"`, '诺贝尔永ABCabcγλυκύ'), document.fonts.load(`700 40px "${f}"`, '诺贝尔永ABCabc')]));
    if (film.init) await film.init();
    return { total: TL.total, fps: TL.fps };
  })();
})();
