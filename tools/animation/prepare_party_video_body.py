"""Matte the final-boss party's AI videos (诺恩, 奥黛尔; rear views on gray) into fixed-foot runtime
atlases for CutoutRig20261010's video skin (2026-10-14, user: 队友视频你接). Same recipe as
prepare_sevian_video_body.py: gray background matte, one layout from the take's first (standing)
frame, never per-frame cropping, 512x640 cells, 8 columns. Anything not joined to the body is
erased (the thrown vial, the video's sparkles and smoke, the flask dropped on the floor): the
spell layer draws the effects.

Takes (output/party-video-20261014/takes, copied from the user's Downloads):
  norn-lantern   10-13 1:46 PM  he turns side-on, lifts the lantern, raises the other palm, thrusts
                                the lantern out (3.43 s a burst of light floods the frame - skipped)
  odelle-throw   10-13 1:57 PM  spins, draws the vial back, whips it out (arm straight at 3.0 s)
  odelle-heal    10-13 2:11 PM  lifts the flask, turns, opens both arms with the light at 4.6 s
  odelle-hit     10-14 2:13 PM  the blow twists her away, flask drawn in (0.7-1.53 s); she then
                                spins round to face the camera (dropped) and stands from 3.5 s
  odelle-down    10-14 3:13 PM  knees give and she goes down on her hands (0.85-3.19 s), stays,
                                and from 6.8 s gets back up (the revive)
  norn-hit       10-14 8:07 PM  (Gemini, 1280x720) the blow at 1.3 s, doubled over at 1.8, back by 2.9
  norn-down      10-14 8:03 PM  (Gemini, 720x1280) collapses 1.3-3.0 s onto his side, lies still,
                                pushes himself up 6.2-7.7 s (the revive)
  Both Gemini takes put the lantern in his other hand: they are mirrored (mirror=True) so it
  stays on the screen-right side as in the reference and the lantern take (the shoulder strap
  then runs the other way, a smaller change than the lantern jumping hands).

usage: <media-venv>/bin/python tools/animation/prepare_party_video_body.py [preset ...]
       (all presets by default; media-venv = /Volumes/andrew's SSD/Mistport-hero-v2/media-venv)
"""
import hashlib, json, sys
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
import imageio_ffmpeg

root = Path(__file__).resolve().parents[2]
takes = root/'output/party-video-20261014/takes'
out = root/'UnityBattleSource/Assets/Resources/FinalBossParty/Video'
evidence = root/'output/party-video-20261014'
out.mkdir(parents=True, exist_ok=True)
W, H, COLS = 512, 640, 8
FEET, FIGURE = 600, 500

def lin(a, b, n): return [float(x) for x in np.linspace(a, b, n)]

# times: source seconds per cell; release: the cell of the contact (the throw, the light, the
# peak of the flinch, the last cell of a fall); held: the action ends on its last cell.
PRESETS = {
    # From 3.2 s the lantern lights the gray behind him and the matte keeps that light as body
    # (a beige slab beside the lantern, v1): the thrust is cut at 3.12 s and the return taken
    # from 5.0 s, once the light and the smoke are gone.
    'norn-attack': dict(src='norn-lantern', times=lin(.6, 3.12, 24) + lin(5.0, 6.3, 16), release=23),
    # 护卫: the raised palm and the lantern held up before him, then back the same way.
    'norn-guard': dict(src='norn-lantern', times=lin(.6, 2.77, 16) + lin(2.77, .6, 17)[1:], release=15),
    # His standing stretch after the lantern, forward then back: a seamless loop.
    'norn-idle': dict(src='norn-lantern', times=lin(5.6, 7.8, 24) + lin(7.8, 5.6, 24)[1:-1], release=0),
    # From 1.4 s: the take smears blood on his coat at the blow (1.25-1.38 s) despite the prompt.
    'norn-hit': dict(src='norn-hit', mirror=True, times=lin(1.4, 1.8, 10) + lin(1.8, 2.9, 13)[1:], release=9),
    'norn-down': dict(src='norn-down', mirror=True, times=lin(1.3, 3.0, 28), release=27, held=True),
    'norn-revive': dict(src='norn-down', mirror=True, times=lin(6.2, 7.7, 16), release=15),
    'odelle-attack': dict(src='odelle-throw', times=lin(.8, 2.67, 20) + lin(2.67, 3.17, 7)[1:] + lin(3.17, 4.6, 15)[1:], release=23),
    'odelle-cast': dict(src='odelle-heal', times=lin(.8, 3.6, 14) + lin(3.6, 4.6, 9)[1:] + lin(4.6, 6.4, 9)[1:] + lin(6.4, 7.7, 11)[1:], release=21),
    'odelle-hit': dict(src='odelle-hit', times=lin(.7, 1.53, 12) + lin(1.53, .7, 13)[1:], release=11),
    'odelle-down': dict(src='odelle-down', times=lin(.85, 3.19, 28), release=27, held=True),
    'odelle-revive': dict(src='odelle-down', times=lin(6.8, 7.85, 14), release=13),
    # The standing stretch after the hit take's turn, forward then back: a seamless loop.
    'odelle-idle': dict(src='odelle-hit', times=lin(3.6, 7.8, 24) + lin(7.8, 3.6, 24)[1:-1], release=0),
}

def matte(rgb, floor=False):
    a = np.asarray(rgb).astype(np.float32)
    edge = np.concatenate([a[:8].reshape(-1,3), a[-8:].reshape(-1,3), a[:,:8].reshape(-1,3), a[:,-8:].reshape(-1,3)])
    bg = np.median(edge, axis=0)
    if floor:
        # The Gemini takes have a lit floor under a darker wall and a soft contact shadow: the
        # background is taken row by row from the side columns, and a neutral, only slightly
        # darker patch joined to the border (the floor shadow) counts as background too.
        sides = np.concatenate([a[:, :12], a[:, -12:]], axis=1)
        rows = ndi.median_filter(np.median(sides, axis=1), size=(31, 1))
        bg = rows[:, None, :]
    distance = np.max(np.abs(a-bg), axis=2)
    near = distance < 22
    if floor:
        v = a.max(axis=2); bv = np.broadcast_to(bg, a.shape).max(axis=2)
        sat = (v - a.min(axis=2)) / np.maximum(v, 1)
        near |= (sat < .12) & (v > .58 * bv) & (v < bv + 10)
    seeds = np.zeros(near.shape, bool); seeds[0,:]=near[0,:]; seeds[-1,:]=near[-1,:]; seeds[:,0]=near[:,0]; seeds[:,-1]=near[:,-1]
    connected = ndi.binary_propagation(seeds, mask=near)
    islands, n = ndi.label((distance < 6) & ~connected)
    counts = np.bincount(islands.ravel()); counts[0] = 0
    enclosed = np.isin(islands, np.where(counts > 500)[0])
    connected |= ndi.binary_propagation(enclosed, mask=distance < 14)
    if floor:
        # Floor seen between the legs or under an arm: enclosed patches of the floor-ish mask.
        holes, n = ndi.label(near & ~connected)
        sizes = np.bincount(holes.ravel()); sizes[0] = 0
        connected |= np.isin(holes, np.where(sizes > 250)[0])
    solid = ~connected
    # Only what joins the body (dilated, so hair strands and fingers stay): no sparkles, no
    # smoke, no vial in flight, no flask on the floor.
    labels, count = ndi.label(ndi.binary_dilation(solid, iterations=5))
    if count > 1:
        sizes = np.bincount(labels.ravel()); sizes[0] = 0
        solid &= labels == sizes.argmax()
    alpha = ndi.gaussian_filter(solid.astype(np.float32), .7)
    alpha[solid & (ndi.distance_transform_edt(solid) > 1.5)] = 1
    unmix = (a - (1-alpha[...,None])*bg) / np.maximum(alpha[...,None], .15)
    rgba = np.dstack([np.clip(unmix,0,255), alpha*255]).astype(np.uint8)
    rgba[alpha < .015] = 0
    return Image.fromarray(rgba)

def fit(im, box):
    x0, y0, x1, y1 = box; scale = FIGURE/max(1, y1-y0)
    scaled = im.resize((int(im.width*scale), int(im.height*scale)), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (W, H))
    canvas.alpha_composite(scaled, (round(W*.5-(x0+x1)*.5*scale), round(FEET-y1*scale)))
    return canvas

def read(src, times, mirror=False):
    """The take's first frame and the frames nearest the requested times (4K read at half size)."""
    reader = imageio_ffmpeg.read_frames(str(takes/f'{src}.mp4'), pix_fmt='rgb24')
    meta = next(reader); w, h = meta['size']; fps = meta['fps']
    shrink = 2 if w * h > 4_000_000 else 1
    want = {0} | {min(round(t * fps), 10**6) for t in times}
    kept, total, last = {}, 0, None
    def grab(buf):
        im = Image.frombytes('RGB', (w, h), buf)
        if shrink > 1: im = im.resize((w // shrink, h // shrink), Image.Resampling.LANCZOS)
        return im.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if mirror else im
    for total, buf in enumerate(reader, 1):
        if total - 1 in want: kept[total - 1] = grab(buf)
        last = buf
    def at(t):
        k = min(total - 1, round(t * fps))
        return kept[k] if k in kept else grab(last)
    return at, fps

def build(name, p):
    times = p['times']; n = len(times); rows = (n + COLS - 1) // COLS
    at, fps = read(p['src'], times, p.get('mirror', False))
    fl = p.get('mirror', False)   # the Gemini takes (mirrored) have the lit floor
    initial = matte(at(0), fl); box = initial.getbbox()
    atlas = Image.new('RGBA', (W*COLS, H*rows)); clipped = 0; shots = []
    for i, t in enumerate(times):
        fitted = fit(matte(at(t), fl), box)
        a = np.asarray(fitted)[..., 3]
        if a[0].max() > 8 or a[:,0].max() > 8 or a[:,-1].max() > 8: clipped += 1
        atlas.alpha_composite(fitted, ((i % COLS)*W, (i//COLS)*H))
        if i in (0, p['release'] // 2, p['release'], (p['release'] + n) // 2, n - 1): shots.append(fitted)
    atlas.save(out/f'{name}.png', compress_level=4)
    fit(initial, box).save(out/f'{name}-idle.png')
    src = takes/f"{p['src']}.mp4"
    info = {'id': name, 'frames': n, 'columns': COLS, 'rows': rows, 'releaseFrame': p['release'], 'held': bool(p.get('held')),
            'sourceTimes': [round(t, 3) for t in times], 'width': W, 'height': H, 'feetRow': FEET, 'figureHeight': FIGURE,
            'source': src.name, 'sourceSHA256': hashlib.sha256(src.read_bytes()).hexdigest()}
    (out/f'{name}.json').write_text(json.dumps(info, indent=1) + '\n')
    preview = Image.new('RGB', (W*len(shots), H), (40, 46, 60))
    for i, s in enumerate(shots): preview.paste(s, (i*W, 0), s)
    preview.save(evidence/f'{name}-matte.jpg', quality=88)
    print(name, 'frames', n, 'rows', rows, 'clipped', clipped, 'box', box, 'fps', fps, flush=True)

for name in (sys.argv[1:] or PRESETS):
    build(name, PRESETS[name])
