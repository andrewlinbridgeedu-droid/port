"""Matte approved AI videos into fixed-foot, compressed-runtime atlas sources.
Original 2D references and provider videos remain untouched. Run on the SSD.
"""
import argparse, hashlib, json, subprocess
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi
import imageio_ffmpeg

p = argparse.ArgumentParser(); p.add_argument('--only'); args = p.parse_args()
root = Path(__file__).resolve().parents[2]
library = root/'docs/development/hero-ai-animation-20261002/motion-library'
output = root/'UnityBattleSource/Assets/Resources/CombatTempo/AIHero'
evidence = root/'docs/development/hero-ai-animation-20261002/integration'
output.mkdir(parents=True, exist_ok=True); evidence.mkdir(parents=True, exist_ok=True)
spec = json.loads((library/'actions.json').read_text())
W,H,N,COLS,ROWS = 512,640,48,8,6

# Authored visible release timestamps (seconds in provider source), not rule clocks.
marks = {
 '01-diagonal-cut': [(1.75,3.2,5.83),(1.0,2.45,5.83),(1.7,3.5,5.83)],
 '02-command-flick': [(1.3,3.2,5.83),(1.0,2.6,5.83),(1.0,3.7,5.83)],
 '03-overarm-throw': [(1.2,4.25,5.83),(.5,4.8,5.83),(.45,3.4,5.83)],
 '04-seal-press': [(1.6,3.65,5.83),(1.1,3.8,5.83),(.9,3.7,5.83)],
 '05-sidearm-cast': [(.9,3.3,5.83),(.9,4.2,5.83),(.5,4.65,5.83)]
}

def matte(rgb):
    a = np.asarray(rgb).astype(np.float32)
    edge = np.concatenate([a[:8].reshape(-1,3), a[-8:].reshape(-1,3), a[:,:8].reshape(-1,3), a[:,-8:].reshape(-1,3)])
    bg = np.median(edge, axis=0)
    distance = np.max(np.abs(a-bg),axis=2)
    near = distance < 26
    seeds = np.zeros(near.shape, bool); seeds[0,:]=near[0,:]; seeds[-1,:]=near[-1,:]; seeds[:,0]=near[:,0]; seeds[:,-1]=near[:,-1]
    connected = ndi.binary_propagation(seeds,mask=near)
    # Background enclosed by a bent arm or crossed legs is not border-connected.
    # Seed only large, almost exact gray islands, then grow within a tighter
    # tolerance than the outer matte so the white costume remains opaque.
    islands,n = ndi.label((distance < 6) & ~connected)
    counts=np.bincount(islands.ravel());counts[0]=0
    enclosed=np.isin(islands,np.where(counts>500)[0])
    connected |= ndi.binary_propagation(enclosed,mask=distance<16)
    solid = ~connected
    # Only keep substantial components, preserving ribbons attached to the body.
    labels, count = ndi.label(solid)
    sizes = np.bincount(labels.ravel()); sizes[0]=0
    solid = np.isin(labels,np.where(sizes>20)[0])
    alpha = ndi.gaussian_filter(solid.astype(np.float32),.55)
    # Colour decontamination is confined to the matte edge; cloth interiors keep source colour.
    alpha[solid & (ndi.distance_transform_edt(solid)>1.5)] = 1
    unmix = (a - (1-alpha[...,None])*bg)/np.maximum(alpha[...,None],.15)
    rgba=np.dstack([np.clip(unmix,0,255),alpha*255]).astype(np.uint8)
    rgba[alpha<.015]=0
    return Image.fromarray(rgba)

def fit(im, box, size=(W,H)):
    # One affine layout per clip, derived from its initial pose. Never auto-crop
    # each moving frame: that would erase steps and make the character wobble.
    x0,y0,x1,y1=box; scale=520/max(1,y1-y0)
    target=(int(im.width*scale),int(im.height*scale))
    scaled=im.resize(target,Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',size)
    canvas.alpha_composite(scaled,(round(W*.5-(x0+x1)*.5*scale),round(590-y1*scale)))
    return canvas

report=[]
for outfitIndex,outfit in enumerate(spec['outfits']):
    for action in spec['actions']:
        key=action['id']+'/'+outfit
        if args.only and args.only not in key: continue
        folder=output/outfit;folder.mkdir(exist_ok=True)
        reader=imageio_ffmpeg.read_frames(str(library/action['id']/(outfit+'.mp4')),pix_fmt='rgb24')
        meta=next(reader); width,height=meta['size']
        frames=[Image.frombytes('RGB',(width,height),buf) for buf in reader]
        start,release,end=marks[action['id']][outfitIndex]
        times=np.linspace(start,end,N)
        initial=matte(frames[0]);box=initial.getbbox()
        atlas=Image.new('RGBA',(W*COLS,H*ROWS))
        snapshots=[]
        for i,t in enumerate(times):
            frame=matte(frames[min(len(frames)-1,round(t*meta['fps']))])
            fitted=fit(frame,box)
            atlas.alpha_composite(fitted,((i%COLS)*W,(i//COLS)*H))
            if i in [0,12,24,36,47]: snapshots.append(fitted)
        name=action['id'];atlas.save(folder/(name+'.png'),compress_level=4)
        idle=fit(initial,box);idle.save(folder/(name+'-idle.png'))
        definition={'id':name,'frames':N,'columns':COLS,'rows':ROWS,
          'releaseFrame':float((release-start)/(end-start)*(N-1)),
          'sourceStart':start,'sourceRelease':release,'sourceEnd':end,
          'recoverySeconds':.18,'width':W,'height':H}
        (folder/(name+'.json')).write_text(json.dumps(definition,indent=2)+'\n')
        preview=Image.new('RGB',(W*5,H),(24,31,46))
        for i,shot in enumerate(snapshots):preview.paste(shot,(i*W,0),shot)
        preview.save(evidence/(outfit+'-'+name+'-matte.jpg'),quality=91)
        source=library/action['id']/(outfit+'.mp4')
        report.append({'action':name,'outfit':outfit,'sourceSHA256':hashlib.sha256(source.read_bytes()).hexdigest(),**definition})
        print('ATLAS',key,flush=True)
(evidence/'atlas-build.json').write_text(json.dumps(report,indent=2)+'\n')
