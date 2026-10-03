"""Small, resumable image-to-video trial. Credentials stay outside the repository."""
import argparse,base64,hashlib,json,os,time,urllib.request,urllib.error,urllib.parse,shutil
from pathlib import Path
from PIL import Image
parser=argparse.ArgumentParser();parser.add_argument('mode',choices=['submit','status']);parser.add_argument('--key-file',type=Path,required=True);parser.add_argument('--outfit',default='mistport-night');parser.add_argument('--endpoint',default='https://api.minimax.io');args=parser.parse_args()
root=Path(__file__).resolve().parents[2];out=root/'docs/development/hero-ai-animation-20261002';out.mkdir(parents=True,exist_ok=True)
key=args.key_file.read_text().strip()
def call(path,payload=None):
 request=urllib.request.Request(args.endpoint+path,data=json.dumps(payload).encode() if payload else None,headers={'Authorization':'Bearer '+key,'Content-Type':'application/json'})
 try:
  with urllib.request.urlopen(request,timeout=90) as response:return json.load(response)
 except urllib.error.HTTPError as e:
  try:return json.loads(e.read())
  except Exception:return {'http_status':e.code}
name=args.outfit;record=out/(name+'-task.json')
if args.mode=='submit':
 if record.exists() and json.loads(record.read_text()).get('task_id'):raise SystemExit('Existing task; query it instead of creating a duplicate.')
 source=root/'docs/development/hero-refinement-20261001/v4/reference'/(name+'-back-4k.png')
 im=Image.open(source).convert('RGBA');rgb=Image.new('RGBA',im.size,(218,216,211,255));rgb.alpha_composite(im)
 first=out/(name+'-input.png');rgb.convert('RGB').save(first)
 prompt='[Static shot] Animate this exact full-body rear-view hand-painted fantasy game character. Preserve his identity, proportions, hairstyle, every embroidered costume panel, gold trim, jewels and colors from the supplied illustration. High-quality detailed 2D anime illustration animation, crisp ink lines and painted fabric shading, never glossy CGI or plastic 3D. Locked rear camera, constant framing and scale, head to boots fully in frame. Flat warm light-gray background remains completely still. He stays facing away throughout, feet planted. One clear quick spell-casting gesture: brief relaxed ready stance; right upper arm lifts naturally from the shoulder, elbow bends normally, right hand rises beside his shoulder, left hand makes a small supporting sweep near his waist; then a brisk forward casting flick away from camera, fingers open naturally; both arms lower and return to the exact starting stance before the end. Shoulder, elbow and wrist move as a coordinated anatomical chain, no backward joints, axial arm reversal, rubber bending, extra fingers or extra limbs. Moderate expressive range, fluid anticipation, rapid release, gentle follow-through. Coat tails, ribbons and hair follow with light delayed secondary motion and settle. No body spin, no turning to camera, no camera motion, no cuts, no zoom, no new objects, no text, no particles, no glow or magic effects hiding the hands. Keep the original fine embroidery stable across frames.'
 payload={'model':'MiniMax-Hailuo-2.3','first_frame_image':'data:image/png;base64,'+base64.b64encode(first.read_bytes()).decode(),'prompt':prompt,'prompt_optimizer':False,'duration':6,'resolution':'1080P'}
 meta={k:v for k,v in payload.items() if k!='first_frame_image'};meta.update({'source':str(source.relative_to(root)),'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),'input':first.name,'inputSHA256':hashlib.sha256(first.read_bytes()).hexdigest(),'endpoint':args.endpoint,'submittedAt':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'inputPreparation':'Original RGBA composited onto solid warm-gray background; character pixels/scale unchanged.'})
 (out/(name+'-request.json')).write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
 result=call('/v1/video_generation',payload);record.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'outfit':name,**result},ensure_ascii=False))
else:
 result=call('/v1/query/video_generation?task_id='+str(json.loads(record.read_text())['task_id']))
 (out/(name+'-status.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps({'outfit':name,**result},ensure_ascii=False))

 if result.get('status')=='Success':
  video=out/(name+'-cast.mp4')
  if not video.exists():
   file=call('/v1/files/retrieve?file_id='+str(result['file_id']))
   if file.get('base_resp',{}).get('status_code')!=0:raise SystemExit('File retrieval failed: '+str(file.get('base_resp')))
   url=file['file']['download_url']
   if urllib.parse.urlparse(url).scheme!='https':raise SystemExit('Expected HTTPS download')
   # Signed provider download: do not forward the API Authorization header.
   with urllib.request.urlopen(url,timeout=120) as response,video.with_suffix('.part').open('wb') as target:shutil.copyfileobj(response,target)
   video.with_suffix('.part').replace(video)
  metadata={'file_id':result['file_id'],'localFile':video.name,'bytes':video.stat().st_size,'sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'task_id':result['task_id'],'notInApp':True,'userVisualApproval':False}
  (out/(name+'-result.json')).write_text(json.dumps(metadata,indent=2)+'\n')
  print('Downloaded',video.name,metadata['bytes'])
