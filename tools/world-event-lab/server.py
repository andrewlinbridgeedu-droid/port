"""Loopback-only design app, Python standard library; no save access."""
import argparse
import json
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from model import run, DEFAULTS

ROOT=Path(__file__).resolve().parent

class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args): pass
    def send(self,status,data,kind):
        self.send_response(status)
        self.send_header('Content-Type',kind)
        self.send_header('Cache-Control','no-store')
        self.send_header('X-Content-Type-Options','nosniff')
        self.end_headers();self.wfile.write(data)
    def do_GET(self):
        route=self.path.split('?')[0]
        if route=='/api/defaults':
            return self.send(200,json.dumps(DEFAULTS).encode(),'application/json')
        if route=='/api/audit':
            path=ROOT.parents[1]/'docs/development/world-event-lab-20260927/summary.json'
            if path.exists(): return self.send(200,path.read_bytes(),'application/json; charset=utf-8')
            return self.send(404,b'No audit yet','text/plain')
        files={'/':'index.html','/app.js':'app.js','/style.css':'style.css'}
        if route not in files: return self.send(404,b'Not found','text/plain')
        mime={'/':'text/html; charset=utf-8','/app.js':'text/javascript; charset=utf-8','/style.css':'text/css; charset=utf-8'}
        self.send(200,(ROOT/files[route]).read_bytes(),mime[route])
    def do_POST(self):
        if self.path!='/api/run': return self.send(404,b'Not found','text/plain')
        # Reject cross-origin browser writes, even though this API only computes.
        if self.headers.get('Origin') not in (None,'http://'+self.headers.get('Host','')):
            return self.send(403,b'Origin rejected','text/plain')
        try:
            length=int(self.headers.get('Content-Length',0))
            if not 0<length<=20000: raise ValueError('invalid request size')
            values=json.loads(self.rfile.read(length))
            result=run(values)
            self.send(200,json.dumps(result,ensure_ascii=False,allow_nan=False).encode(),'application/json; charset=utf-8')
        except (ValueError,TypeError) as e:
            self.send(400,json.dumps({'error':str(e)}).encode(),'application/json')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=8876)
    args=parser.parse_args()
    print('World event lab: http://127.0.0.1:%d'%args.port,flush=True)
    ThreadingHTTPServer(('127.0.0.1',args.port),Handler).serve_forever()
