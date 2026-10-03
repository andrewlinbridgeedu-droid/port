"""Generate/resume the user-approved five-action, three-outfit MiniMax library.
No credentials or signed download URLs are written to the repo. Ambiguous POST
outcomes are not retried automatically, to avoid duplicate paid jobs.
"""
import argparse,base64,hashlib,json,shutil,time,urllib.request,urllib.error,urllib.parse
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--key-file',type=Path,required=True);p.add_argument('--max-inflight',type=int,default=9);args=p.parse_args()
root=Path(__file__).resolve().parents[2];base=root/'docs/development/hero-ai-animation-20261002';out=base/'motion-library'
spec=json.loads((out/'actions.json').read_text());token=args.key_file.read_text().strip();api='https://api.minimax.io'
def write(path,obj):
 tmp=path.with_suffix(path.suffix+'.tmp');tmp.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n');tmp.replace(path)
def call(path,payload=None):
 req=urllib.request.Request(api+path,data=json.dumps(payload).encode() if payload is not None else None,headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(req,timeout=90) as response:return json.load(response)
 except urllib.error.HTTPError as e:
  try:return json.loads(e.read())
  except Exception:return {'base_resp':{'status_code':e.code,'status_msg':'HTTP error'}}
inputs={n:'data:image/png;base64,'+base64.b64encode((base/(n+'-input.png')).read_bytes()).decode() for n in spec['outfits']}
queue=[];active=[];done=[];failed=[]
for a in spec['actions']:
 folder=out/a['id'];folder.mkdir(exist_ok=True)
 for outfit in spec['outfits']:
  job={'action':a,'outfit':outfit,'folder':folder,'name':a['id']+'/'+outfit}
  record=folder/(outfit+'-task.json')
  if (folder/(outfit+'.mp4')).exists():done.append(job)
  elif record.exists():
   result=json.loads(record.read_text())
   if result.get('task_id'):job['task_id']=result['task_id'];active.append(job)
   else:failed.append(job);print('UNRESOLVED_EXISTING_POST',job['name'],flush=True)
  else:queue.append(job)
last_submit=0;last_poll=0;started=time.time()
while queue or active:
 if time.time()-started>1800:raise SystemExit('30-minute bounded run ended; tasks persisted for safe resume.')
 if queue and len(active)<args.max_inflight and time.time()-last_submit>=4:
  job=queue.pop(0);folder=job['folder'];outfit=job['outfit'];a=job['action'];record=folder/(outfit+'-task.json')
  meta={k:spec[k] for k in ['model','duration','resolution','prompt_optimizer']};meta.update({'prompt':a['prompt'],'input':'../../'+outfit+'-input.png','inputSHA256':hashlib.sha256((base/(outfit+'-input.png')).read_bytes()).hexdigest(),'suggestedSpell':a['suggestedSpell'],'runtimeSkillID':a['runtimeSkillID'],'submittedAt':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())})
  write(folder/(outfit+'-request.json'),meta);write(record,{'unknownOutcome':True,'submittedAt':meta['submittedAt']})
  payload={k:meta[k] for k in ['model','duration','resolution','prompt_optimizer','prompt']};payload['first_frame_image']=inputs[outfit]
  try:result=call('/v1/video_generation',payload)
  except Exception as e:
   print('UNKNOWN_POST_OUTCOME',job['name'],type(e).__name__,flush=True);failed.append(job);queue.clear();break
  write(record,result);last_submit=time.time()
  if result.get('task_id') and result.get('base_resp',{}).get('status_code')==0:
   job['task_id']=result['task_id'];active.append(job);print('ACCEPTED',job['name'],result['task_id'],flush=True)
  else:
   print('REJECTED',job['name'],result.get('base_resp'),flush=True);failed.append(job)
   # Stop new paid requests on balance/auth/model failures; preserve queued plan.
   queue.clear()
 if active and time.time()-last_poll>=30:
  last_poll=time.time()
  for job in active[:]:
   outfit=job['outfit'];folder=job['folder']
   try:result=call('/v1/query/video_generation?task_id='+str(job['task_id']))
   except Exception as e:print('QUERY_RETRY_LATER',job['name'],type(e).__name__,flush=True);continue
   write(folder/(outfit+'-status.json'),result)
   if result.get('status')=='Success':
    try:
     r=call('/v1/files/retrieve?file_id='+str(result['file_id']));url=r['file']['download_url']
     if urllib.parse.urlparse(url).scheme!='https':raise ValueError('Expected HTTPS')
     video=folder/(outfit+'.mp4')
     with urllib.request.urlopen(url,timeout=120) as source,video.with_suffix('.part').open('wb') as target:shutil.copyfileobj(source,target)
     video.with_suffix('.part').replace(video)
     write(folder/(outfit+'-result.json'),{'task_id':result['task_id'],'file_id':result['file_id'],'bytes':video.stat().st_size,'sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'width':result['video_width'],'height':result['video_height'],'notInApp':True})
     active.remove(job);done.append(job);print('DOWNLOADED',job['name'],'count',len(done),'/ '+str(spec['count']),flush=True)
    except Exception as e:print('DOWNLOAD_RETRY_LATER',job['name'],type(e).__name__,flush=True)
   elif result.get('status')=='Fail':active.remove(job);failed.append(job);print('FAILED',job['name'],result.get('base_resp'),flush=True)
  write(out/'progress.json',{'completed':len(done),'active':len(active),'queued':len(queue),'failedOrUnresolved':[j['name'] for j in failed],'totalPlanned':spec['count'],'updatedAt':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())})
 time.sleep(1)
write(out/'progress.json',{'completed':len(done),'active':len(active),'queued':len(queue),'failedOrUnresolved':[j['name'] for j in failed],'totalPlanned':spec['count'],'updatedAt':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())})
print('FINISHED',len(done),'of '+str(spec['count'])+'; failures',len(failed),flush=True)
