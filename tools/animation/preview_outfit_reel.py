"""Per-outfit preview reel: each take played the way AIHeroAnimatedBody.Draw does at its card's rule cast time
(MPCOrderedSkillRules.timing), labelled. usage: reel.py <outfit> <out.mp4> [slow]"""
import sys, json, numpy as np, imageio_ffmpeg
from PIL import Image, ImageDraw, ImageFont
W = "/Volumes/andrew's SSD/Mistport-worktrees/merge-20261016"
outfit, out = sys.argv[1], sys.argv[2]; slow = float(sys.argv[3]) if len(sys.argv) > 3 else 1
A = f"{W}/UnityBattleSource/Assets/Resources/CombatTempo/AIHero/{outfit}"
items = [("10-sidestep-thrust", "侧身刺", .85), ("11-brand-mark", "污名记", .55), ("12-presto-beat", "急板", .45), ("06-mirror-burn", "燃镜", 1.8),
         ("09-repaint-sweep", "重绘", .65), ("08-turnabout-whirl", "突转", .65), ("13-mask-toss", "错认喜剧", .95), ("14-twin-palms", "双星追猎", 1.15),
         ("07-phantom-cleave", "归谬法", 1.8), ("15-postscript-point", "附言", .55), ("16-nameless-stage", "我叫无人", .96), ("17-hit-react", "受击", .14)]
if len(sys.argv) > 4: items = [i for i in items if i[0] in sys.argv[4].split(",")]
font = ImageFont.truetype('/System/Library/Fonts/STHeiti Medium.ttc', 34)
idle = Image.open(f"{A}/01-diagonal-cut-idle.png").convert('RGBA')
Wd, Hd = 512, 640
px = np.zeros((Hd, Wd, 4), np.uint8)
for y in range(Hd): px[y, :, :3] = (int(18 + 20 * y / Hd), int(20 + 18 * y / Hd), int(34 + 22 * y / Hd))
px[..., 3] = 255; bg = Image.fromarray(px)
def over(im):
    b = bg.copy(); b.alpha_composite(im); return np.asarray(b)[..., :3].astype(np.float32)
rest = over(idle); fps = 30; frames = []
def label(f, text):
    im = Image.fromarray(np.clip(f, 0, 255).astype(np.uint8)); ImageDraw.Draw(im).text((18, 14), text, font=font, fill=(255, 226, 120)); return np.asarray(im)
for key, name, contact in items:
    info = json.load(open(f"{A}/{key}.json")); atlas = Image.open(f"{A}/{key}.png").convert('RGBA'); C = info['columns']
    cell = lambda i: atlas.crop(((int(i) % C) * Wd, (int(i) // C) * Hd, (int(i) % C + 1) * Wd, (int(i) // C + 1) * Hd))
    recover = min(.55, max(.16, (info['sourceEnd'] - info['sourceRelease']) / 3)); rel = info['releaseFrame']; last = info['frames'] - 1
    end = contact + recover; total = end + info['recoverySeconds']; text = name + ("  · 4 倍慢放" if slow > 1 else "")
    for k in range(int(.4 * fps)): frames.append(label(rest, text))
    t = 0.0
    while t <= total + 1e-6:
        f = rel * min(1, t / contact) if t <= contact else rel + (last - rel) * min(1, (t - contact) / recover)
        blend = 1 - t / .045 if t < .045 else min(1, max(0, (t - end) / info['recoverySeconds']))
        frames.append(label(over(cell(np.floor(f))) * (1 - blend) + rest * blend, text)); t += 1 / (fps * slow)
    for k in range(int(.4 * fps)): frames.append(label(rest, text))
w = imageio_ffmpeg.write_frames(out, (Wd, Hd), fps=fps, codec='libx264', pix_fmt_out='yuv420p', quality=8); w.send(None)
for f in frames: w.send(np.ascontiguousarray(f).tobytes())
w.close(); print(out, round(len(frames) / fps, 1), "s")
