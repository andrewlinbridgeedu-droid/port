// Render frames of one film with headless Chromium.
//   node render.mjs <id> --stills 3,12.5,40 [--outdir dir]     -> PNG stills
//   node render.mjs <id> --video out.mp4 [--from s] [--to s]    -> silent H.264 segment
import { createRequire } from 'module';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const ROOT = path.dirname(fileURLToPath(import.meta.url));
const FPS = 30;

const args = process.argv.slice(2);
const id = args[0];
const opt = k => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : undefined; };

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.css': 'text/css', '.json': 'application/json', '.woff2': 'font/woff2', '.woff': 'font/woff', '.ttf': 'font/ttf', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  fs.readFile(p, (err, data) => {
    if (err) { res.writeHead(404); res.end(); return; }
    res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' });
    res.end(data);
  });
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

const browser = await chromium.launch({ args: ['--disable-gpu-vsync', '--disable-frame-rate-limit', '--force-color-profile=srgb', '--font-render-hinting=none'] });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') console.error('[page]', m.text()); });
page.on('pageerror', e => console.error('[pageerror]', e.message));
await page.goto(`http://127.0.0.1:${port}/engine/index.html?v=${id}`);
await page.waitForFunction(() => window.__ready || window.__error, null, { timeout: 120000 });
const err = await page.evaluate(() => window.__error);
if (err) { console.error(err); process.exit(1); }
const info = await page.evaluate(() => window.__info);

const shot = async (t, type = 'jpeg') => {
  await page.evaluate(t => window.renderAt(t), t);
  return page.screenshot(type === 'png' ? { type: 'png' } : { type: 'jpeg', quality: 93 });
};

if (opt('stills')) {
  const dir = opt('outdir') || path.join(ROOT, 'build', id, 'stills');
  fs.mkdirSync(dir, { recursive: true });
  for (const s of opt('stills').split(',')) {
    const t = parseFloat(s);
    fs.writeFileSync(path.join(dir, `${id}_${t.toFixed(1).padStart(6, '0')}.png`), await shot(t, 'png'));
  }
  console.log('stills ->', dir);
} else if (opt('video')) {
  const from = parseFloat(opt('from') ?? '0');
  const to = Math.min(parseFloat(opt('to') ?? '1e9'), info.duration);
  const f0 = Math.round(from * FPS), f1 = Math.round(to * FPS);
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '21', '-pix_fmt', 'yuv420p', '-r', String(FPS), opt('video')], { stdio: ['pipe', 'inherit', 'inherit'] });
  const t0 = Date.now();
  for (let f = f0; f < f1; f++) {
    const buf = await shot(f / FPS);
    if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
    if ((f - f0) % 300 === 0) console.log(`${id} frame ${f}/${f1}  ${((Date.now() - t0) / 1000 / Math.max(1, f - f0)).toFixed(3)} s/frame`);
  }
  ff.stdin.end();
  await new Promise(r => ff.on('close', r));
  console.log(`${id} ${f0}-${f1} done in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
} else {
  console.log(JSON.stringify(info));
}
await browser.close();
server.close();
