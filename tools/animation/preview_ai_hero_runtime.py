"""Play one AI hero atlas the way AIHeroAnimatedBody.Draw does: frames 0->release over the rule
contact, release->last over recovery, entry/exit blend with the outfit's rest art. Writes an mp4.

usage: <media-venv>/bin/python preview_ai_hero_runtime.py <atlas.png> <atlas.json> <rest.png> <out.mp4> [contact s] [slow: 4 = four times slower]
contact is the card's cast time (MPCOrderedSkillRules.timing). Kept from the 10-19 燃镜 review."""
import sys, json, subprocess, numpy as np
from PIL import Image
import imageio_ffmpeg
atlas_path, json_path, idle_path, out = sys.argv[1:5]
contact = float(sys.argv[5]) if len(sys.argv) > 5 else .65
slow = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
info = json.load(open(json_path)); atlas = Image.open(atlas_path).convert('RGBA'); idle = Image.open(idle_path).convert('RGBA')
W, H, C = info['width'], info['height'], info['columns']
bg = Image.new('RGBA', (W, H)); px = np.zeros((H, W, 4), np.uint8)
for y in range(H): px[y, :, :3] = (int(18 + 20 * y / H), int(20 + 18 * y / H), int(34 + 22 * y / H))
px[..., 3] = 255; bg = Image.fromarray(px)
def cell(i):
    i = int(i); return atlas.crop(((i % C) * W, (i // C) * H, (i % C + 1) * W, (i // C + 1) * H))
def over(im):
    b = bg.copy(); b.alpha_composite(im); return np.asarray(b)[..., :3].astype(np.float32)
recover = min(.55, max(.16, (info['sourceEnd'] - info['sourceRelease']) / 3)); rel = info['releaseFrame']; last = info['frames'] - 1
end = contact + recover; total = end + info['recoverySeconds']
fps = 30; frames = []
rest = over(idle)
for k in range(int(.5 * fps)): frames.append(rest)
t = 0.0
while t <= total + 1e-6:
    f = rel * min(1, t / contact) if t <= contact else rel + (last - rel) * min(1, (t - contact) / recover)
    blend = 1 - t / .045 if t < .045 else min(1, max(0, (t - end) / info['recoverySeconds']))
    frames.append(over(cell(np.floor(f))) * (1 - blend) + rest * blend)
    t += 1 / (fps * slow) if slow != 1 else 1 / fps
for k in range(int(.6 * fps)): frames.append(rest)
writer = imageio_ffmpeg.write_frames(out, (W, H), fps=fps, codec='libx264', pix_fmt_out='yuv420p', quality=8)
writer.send(None)
for _ in range(2):
    for fr in frames: writer.send(np.clip(fr, 0, 255).astype(np.uint8).tobytes())
writer.close(); print(out, len(frames), 'frames', f'contact={contact} recover={recover:.2f}')
