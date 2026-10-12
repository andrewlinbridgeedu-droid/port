"""Matte the boss Sevian's AI strike video into a fixed-foot runtime atlas (2026-10-09 pilot,
user: 拿瑟维安试点吧 / 先做一个吧). Same recipe as prepare_ai_hero_runtime.py: gray background
matte, one affine layout from the first pose (never per-frame cropping), 48 frames of 512x640
in an 8x6 atlas. The provider video holds the raised gauntlet for ~1.5 s before the thrust;
those near-still frames are skipped so the wind-up reads at game speed.

2026-10-10: the whole-body take (user: 这些动作太静态了 … 身体都要动) - he turns away and sinks,
lunges side-on and drives the gauntlet out, sweeps it across with the coat flaring, and comes
back - replaces the arm-only strike. Both presets write the same strike.* files.

2026-10-10 sign: 夺名代签 (proposed fourth boss move) - he squats wide, signs three huge strokes
in the air with a long black pen that appears in the gauntlet (spinning once), lunges and stamps the
palm forward. Writes sign.*; a little handwriting the video drew above his head at the stamp
is erased (detached strokes above the body in those frames).

2026-10-11 charge: 第十三响 (and 镇钟重砸 until it has its own) - the user's 2:23 take, accepted
as a make-do (user: 瑟维安的单人动作也将就): he raises the gauntlet high, then thrusts it at the
camera so the huge palm covers him, holds, and pulls it back. Only the arm moves. The white
smoke swirl the video drew round the hand (2.2-2.7 s) falls inside the hold and is skipped.
4K takes are read at half size, keeping only the frames used.

usage: <media-venv>/bin/python tools/animation/prepare_sevian_video_body.py [sweep|palm|sign|charge]
       (default sweep; media-venv = /Volumes/andrew's SSD/Mistport-hero-v2/media-venv)
"""
import sys
import hashlib, json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import imageio_ffmpeg

root = Path(__file__).resolve().parents[2]
preset = sys.argv[1] if len(sys.argv) > 1 else 'sweep'
source = root/{'sweep': 'output/sevian-video-20261009/takes-20261010/v1203.mp4',
               'sign': 'output/sevian-video-20261009/takes-20261010/v1246.mp4',
               'charge': 'output/sevian-video-20261009/takes-20261011/v1423.mp4'}.get(preset, 'output/sevian-video-20261009/strike.mp4')
name = preset if preset in ('sign', 'charge') else 'strike'
ERASE = (5.35, 6.7) if preset == 'sign' else None   # seconds whose stray strokes above him are erased
out = root/'UnityBattleSource/Assets/Resources/CombatTempo/SevianVideo'
evidence = root/'output/sevian-video-20261009'
out.mkdir(parents=True, exist_ok=True)
W, H, N, COLS, ROWS = 512, 640, 48, 8, 6
FEET, FIGURE = 600, 500          # feet row and authored silhouette height in a frame
if preset == 'sign': FEET, FIGURE = 610, 400   # the raised pen and the wide lunge need more room
if preset == 'charge': FEET, FIGURE = 560, 360   # the palm rises far above his head, and the take pushes in on him in the thrust (his feet drop ~50 px)

if preset == 'sign':
    # Source seconds: squat, pen, three strokes with the spin, lunge .3-5.5 (32 frames, the last -
    # the palm stamped forward - is the release), hold and back to the stance 5.5-7.6 (16).
    times = list(np.linspace(.3, 5.5, 32)) + list(np.linspace(5.5, 7.6, 17))[1:]
    RELEASE = 31
elif preset == 'charge':
    # Source seconds: the gauntlet raised high .4-1.6 (16 frames), thrust at the camera 1.6-2.1
    # (8, the last - the palm at its biggest - is the release), the hold past the smoke swirl
    # 2.8-3.6 (6), pulled back to the stance 3.6-6.0 (18; the push-in only settles by 6 s).
    times = list(np.linspace(.4, 1.6, 16, endpoint=False)) + list(np.linspace(1.6, 2.1, 8)) + list(np.linspace(2.8, 3.6, 6, endpoint=False)) + list(np.linspace(3.6, 6.0, 18))
    RELEASE = 23
elif preset == 'sweep':
    # Source seconds: turn, sink and coil .2-1.6 (22 frames, the last - gauntlet fully driven out
    # side-on - is the release), sweep across with the coat flaring 1.6-3.2 (13), back to the
    # starting stance 3.2-5.6 (13).
    times = list(np.linspace(.2, 1.6, 22)) + list(np.linspace(1.6, 3.2, 14))[1:] + list(np.linspace(3.2, 5.6, 14))[1:]
    RELEASE = 21
else:
    # Source seconds: wind-up .45-1.75 (16 frames), skip the hold, 3.1-3.8 thrust (8, the last is
    # the release), recovery 3.8-6.6 (24).
    times = list(np.linspace(.45, 1.75, 16)) + list(np.linspace(3.1, 3.8, 8)) + list(np.linspace(3.8, 6.6, 25))[1:]
    RELEASE = 23

def matte(rgb):
    a = np.asarray(rgb).astype(np.float32)
    edge = np.concatenate([a[:8].reshape(-1,3), a[-8:].reshape(-1,3), a[:,:8].reshape(-1,3), a[:,-8:].reshape(-1,3)])
    bg = np.median(edge, axis=0)
    distance = np.max(np.abs(a-bg), axis=2)
    near = distance < 22
    seeds = np.zeros(near.shape, bool); seeds[0,:]=near[0,:]; seeds[-1,:]=near[-1,:]; seeds[:,0]=near[:,0]; seeds[:,-1]=near[:,-1]
    connected = ndi.binary_propagation(seeds, mask=near)
    islands, n = ndi.label((distance < 6) & ~connected)
    counts = np.bincount(islands.ravel()); counts[0] = 0
    enclosed = np.isin(islands, np.where(counts > 500)[0])
    connected |= ndi.binary_propagation(enclosed, mask=distance < 14)
    solid = ~connected
    labels, count = ndi.label(solid)
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    solid = np.isin(labels, np.where(sizes > 400)[0])
    alpha = ndi.gaussian_filter(solid.astype(np.float32), .7)
    alpha[solid & (ndi.distance_transform_edt(solid) > 1.5)] = 1
    unmix = (a - (1-alpha[...,None])*bg) / np.maximum(alpha[...,None], .15)
    rgba = np.dstack([np.clip(unmix,0,255), alpha*255]).astype(np.uint8)
    rgba[alpha < .015] = 0
    return Image.fromarray(rgba)

def erase_stray(im):
    """Drop detached strokes lying wholly above the body (the handwriting at the stamp)."""
    a = np.asarray(im).copy()
    solid = a[..., 3] > 20
    labels, count = ndi.label(ndi.binary_dilation(solid, iterations=6))
    if count < 2: return im
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    body = sizes.argmax()
    rows = np.where((labels == body).any(axis=1))[0]
    top = rows.min() + .04 * (rows.max() - rows.min())
    for k in range(1, count + 1):
        if k == body: continue
        ys = np.where((labels == k).any(axis=1))[0]
        if ys.max() < top: a[labels == k] = 0
    return Image.fromarray(a)

def hand_point(cell, last):
    """Where the bronze gauntlet is in a fitted cell (2026-10-11): the centre of a bronze region
    - warm, saturated, R > G > B, not the red lining - so the wind-up glow can follow the video's
    hand instead of the hidden 3D body's. Of the big regions it takes the one nearest the last
    frame's hand (the leather book at his hip is bronze-ish too and outgrows a raised,
    foreshortened gauntlet); falls back to the last frame's."""
    a = cell.astype(np.float32); r, g, b, al = a[..., 0], a[..., 1], a[..., 2], a[..., 3]
    mx = np.maximum(np.maximum(r, g), b); mn = np.minimum(np.minimum(r, g), b)
    sat = (mx - mn) / np.maximum(mx, 1)
    bronze = (al > 160) & (r > g) & (g > b) & (sat > .28) & (r > 70) & (g > .5 * r) & (g < .92 * r) & (b < .72 * r)
    labels, n = ndi.label(ndi.binary_closing(bronze, iterations=2))
    if n == 0: return last
    sizes = np.bincount(labels.ravel()); sizes[0] = 0
    if sizes.max() < 150: return last
    best, near = None, 1e9
    for k in np.nonzero(sizes >= max(150, .25 * sizes.max()))[0]:
        ys, xs = np.nonzero(labels == k); c = [float(xs.mean()), float(ys.mean())]
        d = (c[0] - last[0]) ** 2 + (c[1] - last[1]) ** 2
        if d < near: best, near = c, d
    return [round(best[0], 1), round(best[1], 1)]

def fit(im, box):
    x0, y0, x1, y1 = box; scale = FIGURE/max(1, y1-y0)
    scaled = im.resize((int(im.width*scale), int(im.height*scale)), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (W, H))
    canvas.alpha_composite(scaled, (round(W*.5-(x0+x1)*.5*scale), round(FEET-y1*scale)))
    return canvas

reader = imageio_ffmpeg.read_frames(str(source), pix_fmt='rgb24')
meta = next(reader); w, h = meta['size']; fps = meta['fps']
SHRINK = 2 if w * h > 4_000_000 else 1   # a 4K take at half size: plenty for 512x640 cells
want = {0} | {round(t * fps) for t in times}
def grab(buf):
    im = Image.frombytes('RGB', (w, h), buf)
    return im.resize((w // SHRINK, h // SHRINK), Image.Resampling.LANCZOS) if SHRINK > 1 else im
kept, total, last = {}, 0, None
for total, buf in enumerate(reader, 1):
    if total - 1 in want: kept[total - 1] = grab(buf)
    last = buf
def frame_at(t):
    k = min(total - 1, round(t * fps))
    return kept[k] if k in kept else grab(last)
initial = matte(frame_at(0)); box = initial.getbbox()
atlas = Image.new('RGBA', (W*COLS, H*ROWS)); clipped = 0; shots = []; hands = []; last = [W * .3, FEET * .55]
for i, t in enumerate(times):
    m = matte(frame_at(t))
    if ERASE and ERASE[0] <= t <= ERASE[1]: m = erase_stray(m)
    fitted = fit(m, box)
    last = hand_point(np.asarray(fitted), last); hands.extend(last)
    a = np.asarray(fitted)[..., 3]
    if a[0].max() > 8 or a[-1].max() > 8 or a[:,0].max() > 8 or a[:,-1].max() > 8: clipped += 1
    atlas.alpha_composite(fitted, ((i % COLS)*W, (i//COLS)*H))
    if i in (0, RELEASE // 2, RELEASE - 4, RELEASE, (RELEASE + N) // 2, N - 1): shots.append(fitted)
atlas.save(out/f'{name}.png', compress_level=4)
fit(initial, box).save(out/f'{name}-idle.png')
info = {'id': name, 'frames': N, 'columns': COLS, 'rows': ROWS, 'releaseFrame': RELEASE,
        'sourceTimes': [round(float(t), 3) for t in times], 'width': W, 'height': H,
        'feetRow': FEET, 'figureHeight': FIGURE, 'hand': hands,
        'sourceSHA256': hashlib.sha256(source.read_bytes()).hexdigest()}
(out/f'{name}.json').write_text(json.dumps(info, indent=1) + '\n')
preview = Image.new('RGB', (W*len(shots), H), (40, 46, 60))
for i, s in enumerate(shots): preview.paste(s, (i*W, 0), s)
preview.save(evidence/f'{name}-matte.jpg', quality=90)
print('frames', len(times), 'clipped', clipped, 'box', box, 'fps', fps)
