"""One outfit's signature take for one skill, cut from a single provider video.

2026-10-19: the 燃镜 take (雾港夜行) had a starburst over the head from 0.83 s to
1.96 s, and the user could not re-record ("擦掉，我没额度，不另外重录了"). The
burst sat on a held pose, so the cut skips those frames instead of painting over
them: no frame with the flare is used. The video opens on a black-to-gray fade
and never starts at rest, so the wind-up is the clip's own lowering played
backwards (rest -> arms out low), joined to the real rise at 0.38 s.

Same matte and fixed-foot layout as prepare_ai_hero_runtime.py. Run on the SSD
with the media venv; pass nothing for every take below, or the actions to rebuild.
"""
import hashlib, json, sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import imageio_ffmpeg

root = Path(__file__).resolve().parents[2]
library = root/'docs/development/hero-ai-animation-20261002/motion-library'
output = root/'UnityBattleSource/Assets/Resources/CombatTempo/AIHero'
evidence = root/'docs/development/hero-ai-animation-20261002/integration'
W,H,N,COLS,ROWS = 512,640,48,8,6

# (source start, source end) in seconds; a segment with start > end plays backwards.
takes = [{
    'action': '06-mirror-burn', 'outfit': 'mistport-night', 'skill': 'fool_skill_12',
    'segments': [(3.00, 2.62), (0.38, 0.79), (2.04, 3.25)],
    'release': (2, 2.48),      # segment index, source second: the arms snap open
    'rest': 3.25,              # fixed-foot box
    'flare': (0.83, 1.96),     # never sampled
    # The exit blend crosses into the outfit's reference rest art, whose coat flares wider than
    # this take's last frame; half the usual 0.18 s keeps the double hem to two or three frames.
    'exitBlend': 0.09,
}, {
    # 2026-10-20 (user: 我觉得都可以，你定吧). 11_45PM: a sword appears in his hand, goes up over
    # his head and comes down; it dissolves into a ribbon at 1.42-1.50 s. Before 1.0 s the
    # background is still fading up from black and eats the dark coat, so only 1.0-2.17 s is used:
    # the wind-up is that stretch played backwards (the sword forms out of the ribbon as the arm
    # rises), then the cut itself. A conjured blade for 归谬法's single heavy blow.
    'action': '07-phantom-cleave', 'outfit': 'mistport-night', 'skill': 'fool_skill_07',
    'segments': [(2.17, 1.00), (1.00, 2.25)],
    'release': (1, 1.21),      # the arm down, the blade pointing at the floor
    'rest': 3.00,
}, {
    # 11_10PM: he spins round, faces the camera (1.0-1.5 s, feet moving) and turns back. Only the
    # turn back (1.67 s on: his back to the camera again) is used; the wind-up is it played
    # backwards, so he twists away and whips round with the coat flaring. 突转's reversal.
    'action': '08-turnabout-whirl', 'outfit': 'mistport-night', 'skill': 'fool_skill_08',
    'segments': [(2.75, 1.67), (1.67, 2.75)],
    'release': (1, 1.92),      # the arm sweeps out, the coat at its widest
    'rest': 3.00,
    'floor': True,             # this take has a contact shadow under the feet
}]
only = set(sys.argv[1:])

def matte(rgb, floor=False):
    a = np.asarray(rgb).astype(np.float32)
    edge = np.concatenate([a[:8].reshape(-1,3), a[-8:].reshape(-1,3), a[:,:8].reshape(-1,3), a[:,-8:].reshape(-1,3)])
    bg = np.median(edge, axis=0)
    distance = np.max(np.abs(a-bg),axis=2)
    near = distance < 26
    if floor:
        # A soft contact shadow under the feet (11_10PM): neutral gray a little darker than the
        # wall counts as background when it joins it. The boots are brown, so they stay.
        v = a.max(axis=2); bv = bg.max()
        sat = (v - a.min(axis=2)) / np.maximum(v, 1)
        near |= (sat < .12) & (v > .58 * bv) & (v < bv + 10)
    seeds = np.zeros(near.shape, bool); seeds[0,:]=near[0,:]; seeds[-1,:]=near[-1,:]; seeds[:,0]=near[:,0]; seeds[:,-1]=near[:,-1]
    connected = ndi.binary_propagation(seeds,mask=near)
    islands,n = ndi.label((distance < 6) & ~connected)
    counts=np.bincount(islands.ravel());counts[0]=0
    enclosed=np.isin(islands,np.where(counts>500)[0])
    connected |= ndi.binary_propagation(enclosed,mask=distance<16)
    solid = ~connected
    labels, count = ndi.label(solid)
    sizes = np.bincount(labels.ravel()); sizes[0]=0
    solid = np.isin(labels,np.where(sizes>20)[0])
    alpha = ndi.gaussian_filter(solid.astype(np.float32),.55)
    alpha[solid & (ndi.distance_transform_edt(solid)>1.5)] = 1
    unmix = (a - (1-alpha[...,None])*bg)/np.maximum(alpha[...,None],.15)
    rgba=np.dstack([np.clip(unmix,0,255),alpha*255]).astype(np.uint8)
    rgba[alpha<.015]=0
    return Image.fromarray(rgba)

def fit(im, box, size=(W,H)):
    x0,y0,x1,y1=box; scale=520/max(1,y1-y0)
    target=(int(im.width*scale),int(im.height*scale))
    scaled=im.resize(target,Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',size)
    canvas.alpha_composite(scaled,(round(W*.5-(x0+x1)*.5*scale),round(590-y1*scale)))
    return canvas

def source_time(segments, t):
    for a,b in segments:
        length=abs(b-a)
        if t <= length + 1e-9: return a + (t if b >= a else -t)
        t -= length
    return segments[-1][1]

report=[]
for take in takes:
    if only and take['action'] not in only: continue
    video=library/take['action']/(take['outfit']+'.mp4')
    reader=imageio_ffmpeg.read_frames(str(video),pix_fmt='rgb24')
    meta=next(reader); width,height=meta['size']; fps=meta['fps']
    frames=[Image.frombytes('RGB',(width,height),buf) for buf in reader]
    segments=take['segments']
    total=sum(abs(b-a) for a,b in segments)
    index,second=take['release']
    release=sum(abs(b-a) for a,b in segments[:index])+abs(second-segments[index][0])
    rest=matte(frames[round(take['rest']*fps)],take.get('floor',False));box=rest.getbbox()
    folder=output/take['outfit'];name=take['action']
    atlas=Image.new('RGBA',(W*COLS,H*ROWS));snapshots=[];used=[]
    for i,t in enumerate(np.linspace(0,total,N)):
        k=min(len(frames)-1,round(source_time(segments,t)*fps))
        if 'flare' in take:
            lo,hi=take['flare']
            assert not (round(lo*fps) <= k <= round(hi*fps)), f'flare frame {k} sampled'
        used.append(k)
        fitted=fit(matte(frames[k],take.get('floor',False)),box)
        atlas.alpha_composite(fitted,((i%COLS)*W,(i//COLS)*H))
        snapshots.append(fitted)
    atlas.save(folder/(name+'.png'),compress_level=4)
    # No idle file: at rest the runtime shows the outfit's reference art (AIHeroAnimatedBody.Signatures).
    definition={'id':name,'frames':N,'columns':COLS,'rows':ROWS,
      'releaseFrame':float(release/total*(N-1)),
      'sourceStart':0.0,'sourceRelease':float(release),'sourceEnd':float(total),
      'recoverySeconds':take.get('exitBlend',.18),'width':W,'height':H}
    (folder/(name+'.json')).write_text(json.dumps(definition,indent=2)+'\n')
    # Every frame, small, in order: the joins and the release are checked here.
    sheet=Image.new('RGB',(W//2*12,H//2*4),(24,31,46))
    for i,shot in enumerate(snapshots):
        small=shot.resize((W//2,H//2));sheet.paste(small,((i%12)*W//2,(i//12)*H//2),small)
    sheet.save(evidence/(take['outfit']+'-'+name+'-frames.jpg'),quality=88)
    report.append({**{k:take[k] for k in ('action','outfit','skill','segments','release','rest','flare') if k in take},
        'sourceSHA256':hashlib.sha256(video.read_bytes()).hexdigest(),'sourceFrames':used,**definition})
    print('ATLAS',take['outfit'],name,f'release={definition["releaseFrame"]:.2f}',flush=True)
previous=json.loads((evidence/'signature-build.json').read_text()) if (evidence/'signature-build.json').exists() else []
report=[r for r in previous if r['action'] not in {x['action'] for x in report}]+report
(evidence/'signature-build.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
