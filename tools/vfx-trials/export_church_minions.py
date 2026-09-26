from pathlib import Path
import sys, subprocess, html
sys.path.insert(0, '/tmp/mistport-vfx-encode')
import imageio_ffmpeg

root = Path(__file__).resolve().parents[2] / 'output/church-minions-20260921'
ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
names = {'copperback': '铜背甲兽 · F12起', 'golden-throat': '金喉树蛙 · F22起', 'crimson-brute': '赤蛮魔 · F32起', 'moonfang': '月牙鼠 · F42起', 'veil-oracle': '绯幕先知 · F62起'}
actions = {'idle': '自然待机', 'recover': '恢复', 'hit': '受击', 'death': '死亡退场',
 'tower_copperback_first': '铜甲震', 'tower_copperback_second': '掀甲崩',
 'tower_brute_first': '赤拳灼击', 'tower_brute_second': '双拳坠焰',
 'tower_throat_first': '金喉声弹', 'tower_throat_second': '扁波裂鸣',
 'tower_veil_first': '绯刃', 'tower_veil_second': '交幕裁切',
 'tower_moonfang_first': '月牙噬', 'tower_moonfang_second': '扫月'}
cards = []
for species, label in names.items():
    clips = []
    for folder in sorted((root / 'runtime').glob(species + '--*')):
        if not folder.is_dir(): continue
        frames = sorted(folder.glob('frame-*.png'))
        if not frames: continue
        for source, suffix in [(folder, ''), (folder / 'close', '-close')]:
            out = root / (folder.name + suffix + '.mp4')
            numbered = [int(f.stem.split('-')[-1]) for f in sorted(source.glob('frame-*.png'))]
            if numbered == list(range(len(numbered))):
                subprocess.run([ffmpeg, '-y', '-framerate', '30', '-i', str(source / 'frame-%03d.png'), '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(out)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif not out.exists():
                raise RuntimeError(f'Sparse frames cannot be encoded: {source}')
            subprocess.run([ffmpeg, '-v', 'error', '-i', str(out), '-f', 'null', '-'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        action = folder.name.split('--', 1)[1]
        title = actions.get(action, '第二招蓄势' if action.endswith('charge2') else '第一招蓄势')
        clips.append(f'<article><h3>{html.escape(title)}</h3><div class="pair"><video controls muted loop preload="none" poster="runtime/{folder.name}/frame-019.png" src="{folder.name}.mp4"></video><video controls muted loop preload="none" poster="runtime/{folder.name}/close/frame-019.png" src="{folder.name}-close.mp4"></video></div><button onclick="playPair(this)">同步播放全景与近景</button></article>')
    cards.append(f'<section id="{species}"><h2>{label}</h2><div class="grid">' + ''.join(clips) + '</div></section>')
mixed = []
for folder in sorted((root / 'runtime').glob('mixed-four-*')):
    for source, suffix in [(folder, ''), (folder / 'close', '-close')]:
        out = root / (folder.name + suffix + '.mp4')
        numbered = [int(f.stem.split('-')[-1]) for f in sorted(source.glob('frame-*.png'))]
        if numbered == list(range(len(numbered))):
            subprocess.run([ffmpeg, '-y', '-framerate', '30', '-i', str(source / 'frame-%03d.png'), '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(out)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif not out.exists():
            raise RuntimeError(f'Sparse frames cannot be encoded: {source}')
        subprocess.run([ffmpeg, '-v', 'error', '-i', str(out), '-f', 'null', '-'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    mixed.append(f'<article><h3>四怪同场 · {html.escape(folder.name.replace("mixed-four-", ""))}</h3><video controls muted loop preload="none" poster="runtime/{folder.name}/frame-019.png" src="{folder.name}.mp4"></video></article>')
if mixed: cards.append('<section><h2>四体混编</h2><div class="grid">' + ''.join(mixed) + '</div></section>')
(root / 'index.html').write_text('''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>五种教会塔小怪 · 动作与法术实录</title><style>
body{margin:0;background:#17151c;color:#eee4da;font:16px system-ui}header,main{max-width:1500px;margin:auto;padding:28px}header{border-bottom:1px solid #514339}h1{font-size:30px}h2{color:#dfb97c}h3{font-size:17px;margin:0 0 12px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}article{background:#24212a;padding:16px;border-radius:12px}.pair{display:grid;grid-template-columns:1fr 1fr;gap:8px;align-items:center}video{width:100%;max-height:550px;background:#14121a}button{margin-top:12px;background:#514139;color:#fff;border:1px solid #b28b58;border-radius:6px;padding:8px 14px}nav{display:flex;gap:20px;flex-wrap:wrap}a{color:#dfb97c}p{line-height:1.7;color:#c8c0bc}@media(max-width:850px){.grid{grid-template-columns:1fr}header,main{padding:18px}}</style>
<header><h1>教会塔 · 五种新小怪</h1><p>真实 Unity 塔场景录制：每种两套蓄势与攻击，附待机、恢复、受击和死亡。左为战场全景，右为身体近景。实录触发正式表现与命中回调；核心伤害、百层通关模拟另有测试证据。此页不代表手机触摸、帧率或用户视觉验收。</p><nav>''' + ''.join(f'<a href="#{k}">{v}</a>' for k, v in names.items()) + '</nav></header><main>' + ''.join(cards) + '''</main><script>function playPair(b){document.querySelectorAll('video').forEach(v=>v.pause());b.parentNode.querySelectorAll('video').forEach(v=>{v.currentTime=0;v.play();});}</script></html>''')
print('Encoded and decoded', sum(len(list((root / 'runtime').glob(k + '--*'))) for k in names) + len(mixed), 'clips in two views')
