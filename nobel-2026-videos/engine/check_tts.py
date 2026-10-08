"""用语音识别回听每句配音，标出可能读错的句子。用法: python3 engine/check_tts.py <film>..."""
import sys, os, json, hashlib, re
import numpy as np, soundfile as sf, sherpa_onnx
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
A = os.environ.get('TTS_MODELS', os.path.join(ROOT, 'models')) + '/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/'
rec = sherpa_onnx.OfflineRecognizer.from_sense_voice(model=A + 'model.int8.onnx', tokens=A + 'tokens.txt', language='zh', use_itn=False, num_threads=2)
clean = lambda s: re.sub(r'[^一-鿿A-Za-z]', '', s)
def lev(a, b):
    dp = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        prev = dp[0]; dp[0] = i
        for j, cb in enumerate(b, 1):
            cur = dp[j]; dp[j] = min(dp[j] + 1, dp[j - 1] + 1, prev + (ca != cb)); prev = cur
    return dp[-1]
for film in sys.argv[1:]:
    sc = json.load(open(f'{ROOT}/films/{film}.script.json')); v = sc['voice']
    for s in sc['scenes']:
        for ln in s['lines']:
            say = ln.get('say', ln['text'])
            key = hashlib.sha1(f"kokoro|{v['sid']}|{v['speed']}|{say}".encode()).hexdigest()[:16]
            x, sr = sf.read(f'{ROOT}/audio/cache/{key}.wav', dtype='float32')
            st = rec.create_stream(); st.accept_waveform(sr, x); rec.decode_stream(st)
            ref, hyp = clean(say), clean(st.result.text); cer = lev(ref, hyp) / max(1, len(ref))
            flag = '!!' if cer > .06 else '  '
            print(f'{flag} {film:<10} {cer:.2f} | {say}\n{"":16}→ {st.result.text}' if cer > .06 else f'{flag} {film:<10} {cer:.2f} | {say[:30]}')
