"""合成解说配音并生成时间轴。

用法: python3 engine/build_tts.py <film> [--sid 60] [--speed 1.0]
输入: films/<film>.script.json
输出: assets/<film>/timeline.json, build/<film>/narration.wav (48 kHz 单声道)
"""
import hashlib, json, os, sys, argparse
import numpy as np, soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.environ.get('TTS_MODELS', os.path.join(ROOT, 'models'))
SR = 48000
FPS = 30

ap = argparse.ArgumentParser()
ap.add_argument('film')
ap.add_argument('--sid', type=int, default=None)
ap.add_argument('--speed', type=float, default=None)
ap.add_argument('--gap', type=float, default=0.38)
a = ap.parse_args()

script = json.load(open(f'{ROOT}/films/{a.film}.script.json'))
voice = script.get('voice', {})
sid = a.sid if a.sid is not None else voice.get('sid', 60)
speed = a.speed if a.speed is not None else voice.get('speed', 1.0)

_tts = None
def tts():
    global _tts
    if _tts is None:
        import sherpa_onnx
        d = f'{MODELS}/kokoro-multi-lang-v1_1/'
        cfg = sherpa_onnx.OfflineTtsConfig(
            model=sherpa_onnx.OfflineTtsModelConfig(
                kokoro=sherpa_onnx.OfflineTtsKokoroModelConfig(
                    model=d + 'model.onnx', voices=d + 'voices.bin', tokens=d + 'tokens.txt',
                    data_dir=d + 'espeak-ng-data', dict_dir=d + 'dict',
                    lexicon=d + 'lexicon-us-en.txt,' + d + 'lexicon-zh.txt'),
                num_threads=4),
            rule_fsts=f'{d}date-zh.fst,{d}phone-zh.fst,{d}number-zh.fst', max_num_sentences=1)
        _tts = sherpa_onnx.OfflineTts(cfg)
    return _tts

def resample(x, sr_in, sr_out):
    if sr_in == sr_out: return x
    n = int(round(len(x) * sr_out / sr_in))
    t_in = np.arange(len(x)) / sr_in; t_out = np.arange(n) / sr_out
    return np.interp(t_out, t_in, x).astype(np.float32)

def trim(x, thr=0.006):
    idx = np.where(np.abs(x) > thr)[0]
    if len(idx) == 0: return x
    a0 = max(0, idx[0] - int(0.03 * SR)); b0 = min(len(x), idx[-1] + int(0.08 * SR))
    return x[a0:b0]

cache_dir = f'{ROOT}/audio/cache'; os.makedirs(cache_dir, exist_ok=True)
def synth(say):
    key = hashlib.sha1(f'kokoro|{sid}|{speed}|{say}'.encode()).hexdigest()[:16]
    p = f'{cache_dir}/{key}.wav'
    if not os.path.exists(p):
        g = tts().generate(say, sid=sid, speed=speed)
        x = resample(np.array(g.samples, dtype=np.float32), g.sample_rate, SR)
        x = trim(x)
        # 轻柔的淡入淡出，避免爆音
        f = int(0.012 * SR); x[:f] *= np.linspace(0, 1, f); x[-f:] *= np.linspace(1, 0, f)
        sf.write(p, x, SR)
    x, _ = sf.read(p, dtype='float32')
    return x, p

T = 0.0
scenes = []; pieces = []
for sc in script['scenes']:
    start = T; t = T + sc.get('lead', 0.5); lines = []
    for i, ln in enumerate(sc['lines']):
        say = ln.get('say', ln['text'])
        x, p = synth(say)
        d = len(x) / SR
        lines.append({'text': ln['text'], 'start': round(t, 3), 'end': round(t + d, 3), 'nosub': ln.get('nosub', False)})
        pieces.append((t, x))
        t += d + (ln.get('pause', a.gap) if i < len(sc['lines']) - 1 else 0)
    t += sc.get('tail', 0.6) + sc.get('hold', 0)
    dur = round(round((t - start) * FPS) / FPS, 4)
    scenes.append({'id': sc['id'], 'start': round(start, 4), 'dur': dur, 'lines': lines})
    T = start + dur

total = round(T, 3)
y = np.zeros(int(total * SR) + SR, dtype=np.float32)
for t0, x in pieces:
    i = int(t0 * SR); y[i:i + len(x)] += x
peak = np.abs(y).max() or 1
y = y / peak * 0.89
os.makedirs(f'{ROOT}/build/{a.film}', exist_ok=True)
sf.write(f'{ROOT}/build/{a.film}/narration.wav', y[:int(total * SR)], SR)
os.makedirs(f'{ROOT}/assets/{a.film}', exist_ok=True)
json.dump({'fps': FPS, 'total': total, 'sid': sid, 'speed': speed, 'scenes': scenes}, open(f'{ROOT}/assets/{a.film}/timeline.json', 'w'), ensure_ascii=False, indent=1)
print(f'{a.film}: total {total:.1f}s')
for s in scenes: print(f"  {s['id']:<12} {s['start']:7.2f} +{s['dur']:6.2f}  lines={len(s['lines'])}")
