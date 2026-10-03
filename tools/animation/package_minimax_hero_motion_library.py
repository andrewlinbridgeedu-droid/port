"""Verify and package the original AI motions without replacing source videos."""
import hashlib,json,subprocess,sys
from pathlib import Path
import imageio_ffmpeg
root=Path(__file__).resolve().parents[2];out=root/'docs/development/hero-ai-animation-20261002/motion-library'
spec=json.loads((out/'actions.json').read_text());expected=len(spec['actions']);spec['actions']=[a for a in spec['actions'] if all((out/a['id']/(n+'.mp4')).exists() for n in spec['outfits'])];ff=imageio_ffmpeg.get_ffmpeg_exe();report=[]
def run(args):return subprocess.run([ff,'-hide_banner','-y','-loglevel','error']+args,check=True,capture_output=True,text=True)
for a in spec['actions']:
 folder=out/a['id']
 for name in spec['outfits']:
  src=folder/(name+'.mp4');proof=json.loads((folder/(name+'-result.json')).read_text());assert hashlib.sha256(src.read_bytes()).hexdigest()==proof['sha256']
  reader=imageio_ffmpeg.read_frames(str(src));meta=next(reader);reader.close()
  r=run(['-i',str(src),'-progress','pipe:1','-nostats','-f','null','-']);frames=[int(l.split('=')[1]) for l in r.stdout.splitlines() if l.startswith('frame=')][-1]
  assert meta['size'][0]>=1080 and meta['size'][1]>=1080 and frames>100
  report.append({'action':a['id'],'outfit':name,'source':str(src.relative_to(out)),'sourceSHA256':proof['sha256'],'width':meta['size'][0],'height':meta['size'][1],'fps':meta['fps'],'duration':meta['duration'],'decodedFrames':frames,'fullDecodePassed':True})
  run(['-i',str(src),'-vf','setpts=PTS/3,fps=24','-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(folder/(name+'-3x.mp4'))])
  run(['-i',str(src),'-vf',"select='eq(n,0)+eq(n,24)+eq(n,48)+eq(n,72)+eq(n,96)+eq(n,120)+eq(n,140)',scale=240:426:force_original_aspect_ratio=decrease,pad=240:426:(ow-iw)/2:(oh-ih)/2:color=0xdad8d3,tile=7x1",'-frames:v','1',str(folder/(name+'-frames.jpg'))])
 args=[]
 for name in spec['outfits']:args+=['-i',str(folder/(name+'-frames.jpg'))]
 run(args+['-filter_complex','[0:v][1:v][2:v]vstack=inputs=3[v]','-map','[v]','-frames:v','1',str(folder/'three-outfits-frames.jpg')])
 args=[]
 for name in spec['outfits']:args+=['-i',str(folder/(name+'.mp4'))]
 title=a['id'].replace('-', ' ')
 filters="[0:v]setpts=PTS/3,scale=360:640:force_original_aspect_ratio=decrease,pad=360:640:(ow-iw)/2:(oh-ih)/2:color=0xdad8d3,fps=24[a];[1:v]setpts=PTS/3,scale=360:640:force_original_aspect_ratio=decrease,pad=360:640:(ow-iw)/2:(oh-ih)/2:color=0xdad8d3,fps=24[b];[2:v]setpts=PTS/3,scale=360:640:force_original_aspect_ratio=decrease,pad=360:640:(ow-iw)/2:(oh-ih)/2:color=0xdad8d3,fps=24[c];[a][b][c]hstack=inputs=3,pad=iw:ih+40:0:40:color=0x181b22,drawtext=fontfile='/System/Library/Fonts/Supplemental/Arial.ttf':text='"+title+" - 3x':x=16:y=9:fontsize=22:fontcolor=white[v]"
 run(args+['-filter_complex',filters,'-map','[v]','-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(folder/'comparison-3x.mp4')]);print('PACKAGED',a['id'],flush=True)
listing=out/'montage-order.txt';listing.write_text(''.join("file '"+a['id']+"/comparison-3x.mp4'\n" for a in spec['actions']))
run(['-f','concat','-safe','0','-i',str(listing),'-c','copy','-movflags','+faststart',str(out/'all-actions-three-outfits-3x.mp4')])
(out/'media-check.json').write_text(json.dumps({'originals':report,'count':len(report),'complete':len(spec['actions'])==expected,'sourcesUnchanged':True,'previewSpeedOnly':3,'notInApp':True},indent=2)+'\n')
print('COMPLETE',len(report),'original videos fully decoded; separate 3x previews and',len(spec['actions']),'action montage written.',flush=True)
