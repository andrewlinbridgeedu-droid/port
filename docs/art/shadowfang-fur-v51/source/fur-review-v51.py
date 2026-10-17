"""Assemble the v51 fur review video from a CharacterPolishPreview capture (1280 x 720, 30 fps).

  1. close-up, body frozen: no wind | gust (8 s), then 1.5-4.5 s at half speed
  2. production battle camera, gust: true size | 2.5x crop
  3. 扑咬 with the game's claw marks: battle camera, then the near three-quarter view, then that at half speed
  4. 喷火 with the game's hellfire breath: battle camera, then the near view, then that at half speed
  5. close-up front | side of both attacks (fur only, no effects)
Usage: python fur-review-v51.py <capture dir> <out.mp4> <ffmpeg> <near capture dir>
"""
import subprocess, sys, tempfile
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

cap, out, ffmpeg, near = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4])
FONT = ImageFont.truetype('/System/Library/Fonts/Hiragino Sans GB.ttc', 26)
W, H = 1280, 720


def frames(folder, root=None):
    return sorted(((root or cap) / folder).glob('frame-*.png'))


def label(img, text, x, y):
    d = ImageDraw.Draw(img)
    d.rectangle([x, y, x + 12 + int(d.textlength(text, font=FONT)), y + 38], fill=(0, 0, 0))
    d.text((x + 6, y + 4), text, font=FONT, fill=(255, 255, 255))


def canvas():
    return Image.new('RGB', (W, H))


def pair(a, b, la, lb, title):
    img = canvas()
    img.paste(a.resize((640, 640)), (0, 40)); img.paste(b.resize((640, 640)), (640, 40))
    label(img, la, 12, 52); label(img, lb, 652, 52)
    if title: label(img, title, 12, H - 92)
    return img


def battle(frame, la, lb, title, box):
    full = Image.open(frame).convert('RGB')                 # 720 x 1280 production camera
    img = canvas()
    img.paste(full.resize((405, 720), Image.LANCZOS), (0, 0))
    crop = full.crop(box)
    scale = min((W - 415) / crop.width, H / crop.height)
    crop = crop.resize((int(crop.width * scale), int(crop.height * scale)), Image.LANCZOS)
    img.paste(crop, (415 + (W - 415 - crop.width) // 2, (H - crop.height) // 2))
    label(img, la, 8, 8); label(img, lb, 423, 8)
    if title: label(img, title, 423, H - 50)
    return img


def wide(frame, la, title):
    img = Image.open(frame).convert('RGB').resize((W, H), Image.LANCZOS)
    label(img, la, 12, 12)
    if title: label(img, title, 12, H - 50)
    return img


def main():
    # Frames go on the SSD next to the capture (the internal disk is small) and are removed after.
    tmp = Path(tempfile.mkdtemp(prefix='fur-review-', dir=str(cap.parent)))
    seq = []
    calm, gust = frames('BattleIdle-calm'), frames('BattleIdle-gust')
    for a, b in zip(calm, gust):
        seq.append(pair(Image.open(a).convert('RGB'), Image.open(b).convert('RGB'), '无风（对照）', '有风', '身体固定不动，只有毛在动'))
    for i in range(45, 135):
        img = pair(Image.open(calm[i]).convert('RGB'), Image.open(gust[i]).convert('RGB'), '无风（对照）', '有风 · 半速', '身体固定不动，只有毛在动')
        seq += [img, img]
    for f in frames('BattleIdle-battle'):
        seq.append(battle(f, '战斗镜头 原大小', '放大', '阵风从 0.6 秒开始', (230, 430, 490, 690)))
    for clip, name in [('Light', '扑咬'), ('HeavyRelease', '喷火')]:
        folder = 'heavy-release' if clip == 'HeavyRelease' else clip
        for f in frames(folder + '-battle-vfx'):
            seq.append(battle(f, '战斗镜头 原大小', name + ' · 游戏里的特效', '动作按原长度播放', (90, 380, 630, 1010)))
        side = frames(folder + '-near-vfx', near)
        for f in side:
            seq.append(wide(f, name + ' · 侧前方近景', '动作按原长度播放'))
        lo, hi = (40, 110) if clip == 'Light' else (20, 140)
        for f in side[lo:hi]:
            img = wide(f, name + ' · 侧前方近景 · 半速', '')
            seq += [img, img]
    for clip, name in [('Light', '扑咬'), ('heavy-release', '喷火')]:
        for a, b in zip(frames(clip), frames(clip + '-side')):
            seq.append(pair(Image.open(a).convert('RGB'), Image.open(b).convert('RGB'), name + ' 正面', name + ' 侧面', '只看毛：风 + 身体运动带动毛甩（不含特效）'))
    for i, img in enumerate(seq):
        img.save(tmp / f'{i:05d}.png')
    subprocess.run([ffmpeg, '-y', '-loglevel', 'error', '-framerate', '30', '-i', str(tmp / '%05d.png'),
                    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', str(out)], check=True)
    for p in tmp.iterdir():
        p.unlink()
    tmp.rmdir()
    print('FUR_REVIEW_WRITTEN', out, len(seq), 'frames')


if __name__ == '__main__':
    main()
