"""One outfit's signature take for one skill, cut from a single provider video.

2026-10-19: the 燃镜 take (雾港夜行) had a starburst over the head from 0.83 s to
1.96 s, and the user could not re-record ("擦掉，我没额度，不另外重录了"). The
burst sat on a held pose, so the cut skips those frames instead of painting over
them: no frame with the flare is used. The video opens on a black-to-gray fade
and never starts at rest, so the wind-up is the clip's own lowering played
backwards (rest -> arms out low), joined to the real rise at 0.38 s.

Same matte and fixed-foot layout as prepare_ai_hero_runtime.py. Run on the SSD
with the media venv; pass nothing for every take below, or the actions (or outfit/action) to rebuild.
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
# ('mix', a, b, length): a crossfade from the frame at a to the frame at b over `length` seconds of
# the cut, standing in for a stretch that cannot be shown (a smear over a fast move).
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
}, {
    # 10_43PM (user 10-20: 不是吧，我发了很多视频): a sweep from his left to his right. The whole clip
    # is on pure black, which mattes cleanly (the coat never goes below it). At 0.75-1.17 s the turn
    # shows his face in profile, so that stretch is replaced by a two-frame crossfade from the arm
    # out to the left (0.67 s) to the arm out to the right (1.33 s): a smear across the fast part of
    # the sweep. 重绘's single wide stroke.
    'action': '09-repaint-sweep', 'outfit': 'mistport-night', 'skill': 'fool_skill_09',
    'segments': [(0.10, 0.67), ('mix', 0.67, 1.33, 0.09), (1.33, 2.75)],
    'release': (2, 1.58),      # the arm straight out to the right at the end of the stroke
    'rest': 3.00,
},
# 2026-10-21: eight takes generated with Veo 3.1 Fast (1080p) from the gray reference
# (ArtSource/HeroBackViews4K20261002/gray), prompts in HERO_MOTION_PROMPTS_20261018.md, second round.
# Each opens on the reference itself, so the rest box is frame 0. Several breathe white smoke round
# the head after the move (from ~1.8-3.3 s); every cut ends before it.
{
    # A rapier forms in the hand at 0.50-0.83 s and is gone as the arm straightens: those frames are a
    # two-frame smear from the hand coming up (0.38 s) to the arm out (0.92 s). One step out and back.
    'action': '10-sidestep-thrust', 'outfit': 'mistport-night', 'skill': 'fool_skill_01',
    'segments': [(0.0, 0.38), ('mix', 0.38, 0.92, 0.09), (0.92, 2.83)],
    'release': (2, 1.25), 'rest': 0.0,
}, {
    # Bare fingers write two strokes by the shoulder, then flick out (the first take drew a sword).
    'action': '11-brand-mark', 'outfit': 'mistport-night', 'skill': 'fool_skill_05',
    'segments': [(0.0, 2.33)], 'release': (0, 1.71), 'rest': 0.0, 'body_only': True,
}, {
    # Four quick beats at the chest, then both hands thrown open.
    'action': '12-presto-beat', 'outfit': 'mistport-night', 'skill': 'fool_skill_11',
    'segments': [(0.0, 2.83)], 'release': (0, 2.0), 'rest': 0.0,
}, {
    # A hand to the face (held 0.83-2.0 s: the middle of the hold is cut), then flung out to the right.
    'action': '13-mask-toss', 'outfit': 'mistport-night', 'skill': 'fool_skill_04',
    'segments': [(0.0, 1.17), (1.83, 3.0)], 'release': (1, 2.5), 'rest': 0.0,
}, {
    # 10-21 second round (Veo 3.1): both palms pushed out at the shoulders and brought back down, no
    # smoke until near the end (the Fast take of the first round smoked from 1.83 s).
    'action': '14-twin-palms', 'outfit': 'mistport-night', 'skill': 'fool_skill_06',
    'segments': [(0.0, 2.33)], 'release': (0, 1.33), 'rest': 0.0,
}, {
    # 10-21 second round (Veo 3.1): points, raises one finger and holds it (no glint), lowers.
    'action': '15-postscript-point', 'outfit': 'mistport-night', 'skill': 'fool_skill_13',
    'segments': [(0.0, 1.17), (2.17, 3.0)], 'release': (0, 1.0), 'rest': 0.0,
}, {
    # The ultimate: arms open wide, coat lifted by the draft; the held middle is cut short.
    'action': '16-nameless-stage', 'outfit': 'mistport-night', 'skill': 'fool_skill_10',
    'segments': [(0.0, 2.2), (3.0, 5.0)], 'release': (0, 1.5), 'rest': 0.0,
}, {
    # The hit reaction (AIHeroAnimatedBody.HitTake): head drops, knees give, arms fling, back by 2.75 s.
    'action': '17-hit-react', 'outfit': 'mistport-night', 'skill': 'hit',
    'segments': [(0.5, 2.75)], 'release': (0, 0.95), 'rest': 0.0,
}]
# 2026-10-21 second round: the other two outfits, Veo 3.1 (1080p) from their gray references, two
# versions per prompt and the better one kept (HERO_MOTION_PROMPTS_20261018.md, round-two results).
# Same action names as 雾港夜行, so AIHeroAnimatedBody.Signatures loads them per outfit.
def outfit_take(outfit, action, segments, release, body_only=False):
    take = {'action': action, 'outfit': outfit, 'skill': '', 'segments': segments, 'release': release, 'rest': 0.0}
    if body_only: take['body_only'] = True
    return take
takes += [
    # Retake 10-21 (the first kept version smoked by the hand): writes, holds, flicks out at 2.83 s.
    outfit_take('midnight-carnival', '11-brand-mark', [(0.0, 1.0), (2.33, 3.33)], (1, 2.83)),
    outfit_take('midnight-carnival', '12-presto-beat', [(0.0, 3.0)], (0, 2.33)),
    outfit_take('midnight-carnival', '06-mirror-burn', [(0.0, 3.67)], (0, 1.67)),
    outfit_take('midnight-carnival', '13-mask-toss', [(0.0, 2.83)], (0, 2.33)),
    outfit_take('midnight-carnival', '14-twin-palms', [(0.0, 2.83)], (0, 1.83)),
    outfit_take('midnight-carnival', '07-phantom-cleave', [(0.0, 3.67)], (0, 2.5)),
    outfit_take('midnight-carnival', '15-postscript-point', [(0.0, 1.33), (2.33, 3.17)], (0, 1.0)),
    outfit_take('midnight-carnival', '17-hit-react', [(0.5, 2.75)], (0, 1.0)),
    # Retakes (the first versions turned the face, conjured a rapier, lit the background or smoked).
    outfit_take('midnight-carnival', '10-sidestep-thrust', [(0.0, 3.0)], (0, 1.17)),
    outfit_take('midnight-carnival', '09-repaint-sweep', [(0.0, 3.0)], (0, 2.33)),
    outfit_take('midnight-carnival', '08-turnabout-whirl', [(0.0, 2.67)], (0, 1.67)),
    outfit_take('midnight-carnival', '16-nameless-stage', [(0.0, 2.5), (3.0, 4.8)], (0, 1.67)),
    outfit_take('starlight-magician', '10-sidestep-thrust', [(0.0, 2.5)], (0, 1.17)),
    outfit_take('starlight-magician', '11-brand-mark', [(0.0, 2.5)], (0, 1.83), body_only=True),
    outfit_take('starlight-magician', '12-presto-beat', [(0.0, 3.0)], (0, 2.33)),
    outfit_take('starlight-magician', '06-mirror-burn', [(0.0, 3.17)], (0, 1.67)),
    outfit_take('starlight-magician', '09-repaint-sweep', [(0.0, 3.0)], (0, 2.17)),
    outfit_take('starlight-magician', '08-turnabout-whirl', [(0.0, 2.17)], (0, 1.17)),
    outfit_take('starlight-magician', '13-mask-toss', [(0.0, 2.5)], (0, 1.6)),
    outfit_take('starlight-magician', '14-twin-palms', [(0.0, 2.5)], (0, 1.33)),
    outfit_take('starlight-magician', '07-phantom-cleave', [(0.0, 2.0), (3.17, 4.0)], (0, 1.67)),
    outfit_take('starlight-magician', '15-postscript-point', [(0.0, 2.33)], (0, 1.33), body_only=True),
    outfit_take('starlight-magician', '16-nameless-stage', [(0.0, 2.5), (3.0, 4.0)], (0, 1.83), body_only=True),
    outfit_take('starlight-magician', '17-hit-react', [(0.5, 2.5)], (0, 1.0)),
]
only = set(sys.argv[1:])

def matte(rgb, floor=False, body_only=False):
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
    if body_only:
        # Only what joins the body (dilated, so fingers and ribbon ends stay): a glint over a
        # fingertip or a wisp of smoke is dropped instead of becoming part of the figure.
        joined, count = ndi.label(ndi.binary_dilation(solid, iterations=4))
        if count > 1:
            sizes = np.bincount(joined.ravel()); sizes[0] = 0
            solid &= joined == sizes.argmax()
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

def seg_length(seg): return seg[3] if seg[0] == 'mix' else abs(seg[1]-seg[0])

def source_time(segments, t):
    """(second, None, 0) for a plain frame; (a, b, w) inside a crossfade."""
    for seg in segments:
        length=seg_length(seg)
        if t <= length + 1e-9:
            if seg[0] == 'mix': return seg[1], seg[2], min(1, t/length)
            a,b=seg; return a + (t if b >= a else -t), None, 0
        t -= length
    last=segments[-1]; return (last[2] if last[0] == 'mix' else last[1]), None, 0

report=[]
for take in takes:
    if only and take['action'] not in only and f"{take['outfit']}/{take['action']}" not in only: continue
    video=library/take['action']/(take['outfit']+'.mp4')
    reader=imageio_ffmpeg.read_frames(str(video),pix_fmt='rgb24')
    meta=next(reader); width,height=meta['size']; fps=meta['fps']
    frames=[Image.frombytes('RGB',(width,height),buf) for buf in reader]
    segments=take['segments']
    total=sum(seg_length(seg) for seg in segments)
    index,second=take['release']
    release=sum(seg_length(seg) for seg in segments[:index])+abs(second-segments[index][0])
    mo=dict(floor=take.get('floor',False),body_only=take.get('body_only',False))
    rest=matte(frames[round(take['rest']*fps)],**mo);box=rest.getbbox()
    folder=output/take['outfit'];name=take['action']
    atlas=Image.new('RGBA',(W*COLS,H*ROWS));snapshots=[];used=[]
    for i,t in enumerate(np.linspace(0,total,N)):
        at,mix_to,w=source_time(segments,t)
        k=min(len(frames)-1,round(at*fps))
        if 'flare' in take:
            lo,hi=take['flare']
            assert not (round(lo*fps) <= k <= round(hi*fps)), f'flare frame {k} sampled'
        used.append(k)
        fitted=fit(matte(frames[k],**mo),box)
        if mix_to is not None and w > 0:
            other=fit(matte(frames[min(len(frames)-1,round(mix_to*fps))],**mo),box)
            # Both silhouettes stay solid (a smear, not a fade through transparency); the colour mixes.
            a=np.asarray(fitted).astype(np.float32);b=np.asarray(other).astype(np.float32)
            wa=a[...,3:]/255*(1-w);wb=b[...,3:]/255*w
            rgb=(a[...,:3]*wa+b[...,:3]*wb)/np.maximum(wa+wb,1e-6)
            fitted=Image.fromarray(np.dstack([rgb,np.maximum(a[...,3],b[...,3])]).clip(0,255).astype(np.uint8))
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
report=[r for r in previous if (r['outfit'],r['action']) not in {(x['outfit'],x['action']) for x in report}]+report
(evidence/'signature-build.json').write_text(json.dumps(report,indent=2,ensure_ascii=False)+'\n')
