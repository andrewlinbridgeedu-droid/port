// 由时间轴生成 SRT 字幕（与画面内字幕的切分规则一致）。用法: node engine/make_srt.js physics
const fs = require('fs'), path = require('path');
const film = process.argv[2]; const ROOT = path.resolve(__dirname, '..');
const TL = JSON.parse(fs.readFileSync(path.join(ROOT, 'assets', film, 'timeline.json'), 'utf8'));
function splitSub(line) {
  const maxLen = 26; const s = line.text; if ([...s].length <= maxLen) return [line];
  const parts = []; let cur = '';
  for (const ch of s) { cur += ch; if ('，。；：？！'.includes(ch) && [...cur].length >= 8) { parts.push(cur); cur = ''; } }
  if (cur) parts.push(cur);
  const merged = []; for (const p of parts) { if (merged.length && [...merged[merged.length - 1]].length + [...p].length <= maxLen) merged[merged.length - 1] += p; else merged.push(p); }
  const total = merged.reduce((a, p) => a + [...p].length, 0); let t = line.start; const out = [];
  merged.forEach((p, i) => { const d = (line.end - line.start) * [...p].length / total; out.push({ text: p.replace(/[，。；：]$/, ''), start: t, end: i === merged.length - 1 ? line.end : t + d }); t += d; });
  return out;
}
const ts = x => { const ms = Math.round(x * 1000); const h = Math.floor(ms / 3600000), m = Math.floor(ms / 60000) % 60, s = Math.floor(ms / 1000) % 60; return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')},${String(ms % 1000).padStart(3, '0')}`; };
const subs = TL.scenes.flatMap(s => s.lines.filter(l => !l.nosub)).flatMap(splitSub);
const out = subs.map((l, i) => `${i + 1}\n${ts(l.start)} --> ${ts(l.end)}\n${l.text}\n`).join('\n');
fs.writeFileSync(path.join(ROOT, 'assets', film, 'subtitles.srt'), out); console.log(`${film}: ${subs.length} 条字幕`);
