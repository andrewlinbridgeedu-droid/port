// 本地预览：node engine/preview.js [film] → 在浏览器里带声音拖动预览（实时帧率取决于电脑性能）
const http = require('http'), fs = require('fs'), path = require('path'), { exec } = require('child_process');
const ROOT = path.resolve(__dirname, '..'); const film = process.argv[2] || 'physics';
const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json', '.ttf': 'font/ttf', '.ogg': 'audio/ogg', '.png': 'image/png', '.jpg': 'image/jpeg' };
http.createServer((req, rsp) => {
  const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { rsp.writeHead(404); rsp.end(); return; }
  const st = fs.statSync(p); const range = req.headers.range;
  if (range) { const [a, b] = range.replace('bytes=', '').split('-'); const s = +a, e = b ? +b : st.size - 1; rsp.writeHead(206, { 'Content-Range': `bytes ${s}-${e}/${st.size}`, 'Accept-Ranges': 'bytes', 'Content-Length': e - s + 1, 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' }); fs.createReadStream(p, { start: s, end: e }).pipe(rsp); return; }
  rsp.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream', 'Content-Length': st.size, 'Accept-Ranges': 'bytes' }); fs.createReadStream(p).pipe(rsp);
}).listen(8026, '127.0.0.1', () => {
  const url = `http://127.0.0.1:8026/engine/preview.html?film=${film}`; console.log('预览地址：' + url);
  exec((process.platform === 'darwin' ? 'open ' : process.platform === 'win32' ? 'start ' : 'xdg-open ') + url);
});
