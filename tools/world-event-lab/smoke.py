"""HTTP contract smoke checks against the running loopback app."""
import json
import urllib.request
import urllib.error

BASE='http://127.0.0.1:8876'

def request(path,body=None,origin=None):
    headers={'Content-Type':'application/json'}
    if origin:headers['Origin']=origin
    req=urllib.request.Request(BASE+path,data=json.dumps(body).encode() if body is not None else None,headers=headers)
    with urllib.request.urlopen(req,timeout=30) as response:return response.read()

defaults=json.loads(request('/api/defaults'))
audit=json.loads(request('/api/audit'))
assert audit['events']==216 and audit['projects']==448 and audit['currency_observations']==2916
for path in ('/','/app.js','/style.css'):assert request(path)
for values in ({'trials':200,'kit_price':60,'launch_guard':True},
               {'trials':200,'participants':0},
               {'trials':200,'dau':0},
               {'trials':200,'launch_guard':True,'orders_a':0,'orders_b':0}):
    r=json.loads(request('/api/run',values,BASE))
    assert abs(sum(r['event']['outcomes'].values())-1)<1e-9
    assert all(abs(p['conservation_error'])<1e-9 for p in r['projects'])
    assert len(r['money'])==9 and len(r['chart'])==74
    print('PASS API scenario',values)
for values,origin,expected in (({'dau':2},BASE,400),({'trials':200},'https://example.invalid',403)):
    try:request('/api/run',values,origin);raise AssertionError('request should fail')
    except urllib.error.HTTPError as e:assert e.code==expected
print('PASS static assets, audit, scenarios, validation, cross-origin rejection')
