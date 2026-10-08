// 用无头 Chromium 逐帧渲染，并行分段编码，再无损拼接。
// 用法: node engine/render.js <film> [--workers N] [--from 秒] [--to 秒] [--still 秒,秒,...] [--channel chrome]
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const film = args[0];
const opt = (k, d) => { const i = args.indexOf('--' + k); return i >= 0 ? args[i + 1] : d; };
const WORKERS = +opt('workers', Math.max(2, Math.floor(require('os').cpus().length / 2)));
const FPS = 30;

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.ttf': 'font/ttf', '.png': 'image/png', '.jpg': 'image/jpeg' };
function serve() {
  return new Promise(res => {
    const srv = http.createServer((req, rsp) => {
      const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
      if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { rsp.writeHead(404); rsp.end(); return; }
      rsp.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); fs.createReadStream(p).pipe(rsp);
    }).listen(0, '127.0.0.1', () => res(srv));
  });
}

async function openPage(browser, port) {
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('console', m => { if (m.type() === 'error') console.error('[page]', m.text()); });
  page.on('pageerror', e => console.error('[pageerror]', e.message));
  await page.goto(`http://127.0.0.1:${port}/engine/player.html?film=${film}`);
  const info = await page.evaluate(() => window.ready);
  return { page, info };
}

async function grab(page, T, frame) {
  const b64 = await page.evaluate(([T, f]) => { renderAt(T, f); return document.getElementById('c').toDataURL('image/jpeg', 0.94).split(',')[1]; }, [T, frame]);
  return Buffer.from(b64, 'base64');
}

async function main() {
  const srv = await serve(); const port = srv.address().port;
  const launchArgs = { args: ['--disable-web-security', '--font-render-hinting=none', '--disable-lcd-text', '--force-color-profile=srgb', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] };
  // 优先用 Playwright 自带的 Chromium；没装时退回本机的 Google Chrome（--channel chrome 可强制）
  let browser;
  const channel = opt('channel', null);
  try { browser = await chromium.launch(channel ? { ...launchArgs, channel } : launchArgs); }
  catch (e) { console.log('未找到 Playwright Chromium，改用本机 Google Chrome'); browser = await chromium.launch({ ...launchArgs, channel: 'chrome' }); }
  const outDir = path.join(ROOT, 'build', film); fs.mkdirSync(outDir, { recursive: true });

  const still = opt('still', null);
  if (still) {
    const { page } = await openPage(browser, port);
    for (const s of still.split(',')) { const T = +s; const buf = await grab(page, T, Math.round(T * FPS)); const f = path.join(outDir, `still_${s}.jpg`); fs.writeFileSync(f, buf); console.log(f); }
    await browser.close(); srv.close(); return;
  }

  const probe = await openPage(browser, port); const total = probe.info.total; await probe.page.close();
  const from = Math.round(+opt('from', 0) * FPS); const to = Math.round(Math.min(+opt('to', total), total) * FPS);
  const n = to - from; const per = Math.ceil(n / WORKERS);
  console.log(`film=${film} frames ${from}-${to} (${(n / FPS).toFixed(1)}s) workers=${WORKERS}`);
  const t0 = Date.now(); let done = 0;
  const segs = [];
  await Promise.all([...Array(WORKERS).keys()].map(async w => {
    const a = from + w * per, b = Math.min(to, a + per); if (a >= b) return;
    const seg = path.join(outDir, `seg_${String(w).padStart(2, '0')}.mp4`); segs[w] = seg;
    const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-', '-c:v', 'libx264', '-preset', 'medium', '-crf', '19', '-pix_fmt', 'yuv420p', '-threads', '1', seg]);
    const { page } = await openPage(browser, port);
    for (let f = a; f < b; f++) {
      const buf = await grab(page, f / FPS, f);
      if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
      done++; if (done % 150 === 0) { const el = (Date.now() - t0) / 1000; console.log(`  ${done}/${n} frames, ${(done / el).toFixed(1)} fps, eta ${((n - done) / (done / el)).toFixed(0)}s`); }
    }
    ff.stdin.end(); await new Promise(r => ff.on('close', r)); await page.close();
  }));
  const list = path.join(outDir, 'segs.txt'); fs.writeFileSync(list, segs.filter(Boolean).map(s => `file '${s}'`).join('\n'));
  const out = path.join(outDir, opt('out', 'video.mp4'));
  await new Promise(r => spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', list, '-c', 'copy', out], { stdio: 'inherit' }).on('close', r));
  console.log(`done ${out} in ${((Date.now() - t0) / 1000).toFixed(0)}s`);
  await browser.close(); srv.close();
}
main().catch(e => { console.error(e); process.exit(1); });
