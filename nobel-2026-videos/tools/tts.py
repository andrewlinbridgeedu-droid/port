"""Synthesize narration for one script and build its timeline.

usage: python3 tools/tts.py <id> [--check]
  models are looked up in $TTS_DIR (matcha-icefall-zh-baker + vocos-22khz-univ.onnx)
  and $ASR_DIR (sense-voice) for --check.
"""
import json, os, sys, re
import numpy as np
import soundfile as sf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TTS_DIR = os.environ.get("TTS_DIR")
ASR_DIR = os.environ.get("ASR_DIR")
SPEED = 0.9

GAP_LINE = 0.42      # pause between sentences
GAP_BEAT = 0.85      # pause between beats
CHAPTER_LEAD = 3.2   # chapter card before narration resumes


def make_tts():
    import sherpa_onnx
    m = f"{TTS_DIR}/matcha-icefall-zh-baker"
    cfg = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            matcha=sherpa_onnx.OfflineTtsMatchaModelConfig(
                acoustic_model=f"{m}/model-steps-3.onnx", vocoder=f"{TTS_DIR}/vocos-22khz-univ.onnx",
                lexicon=f"{m}/lexicon.txt", tokens=f"{m}/tokens.txt", dict_dir=f"{m}/dict"),
            num_threads=4),
        rule_fsts=f"{m}/phone.fst,{m}/date.fst,{m}/number.fst")
    return sherpa_onnx.OfflineTts(cfg)


def trim(a, sr, thr=0.012):
    idx = np.where(np.abs(a) > thr)[0]
    if len(idx) == 0:
        return a
    s = max(0, idx[0] - int(0.03 * sr))
    e = min(len(a), idx[-1] + int(0.08 * sr))
    return a[s:e]


def main():
    vid = sys.argv[1]
    check = "--check" in sys.argv
    script = json.load(open(f"{ROOT}/scripts/{vid}.json", encoding="utf-8"))
    out = f"{ROOT}/build/{vid}"
    os.makedirs(f"{out}/voice", exist_ok=True)
    tts = make_tts()
    rec = make_asr() if check else None
    t = 0.0
    bad = 0
    beats = []
    k = 0
    for bi, b in enumerate(script["beats"]):
        bstart = t
        if bi == 0:
            t += b.get("lead", 5.0)
        elif b.get("chapter"):
            t += CHAPTER_LEAD
        lines = []
        for li, line in enumerate(b["lines"]):
            disp = line if isinstance(line, str) else line["t"]
            say = line if isinstance(line, str) else line["s"]
            path = f"{out}/voice/l{k:03d}.wav"
            best = None
            for sp in ([SPEED, 0.87, 0.93, 0.885] if rec else [SPEED]):
                a = tts.generate(say, sid=0, speed=sp)
                sr = a.sample_rate
                w = trim(np.array(a.samples, dtype=np.float32), sr)
                diffs = asr_diffs(rec, w, sr, say) if rec else []
                if best is None or len(diffs) < len(best[1]):
                    best = (w, diffs)
                if not diffs:
                    break
            w, diffs = best
            if diffs:
                bad += 1
                print(f"  l{k:03d} {diffs}")
            sf.write(path, w, sr)
            d = len(w) / sr
            lines.append({"k": k, "text": disp, "say": say, "t0": round(t, 3), "t1": round(t + d, 3), "wav": os.path.basename(path)})
            t += d + GAP_LINE
            k += 1
        t += GAP_BEAT - GAP_LINE
        if bi == len(script["beats"]) - 1:
            t += b.get("tail", 5.0)
        beats.append({"scene": b["scene"], "chapter": b.get("chapter"), "t0": round(bstart, 3), "t1": round(t, 3), "lines": lines})
    tl = {"id": vid, "duration": round(t, 3), "sr": sr, "beats": beats}
    json.dump(tl, open(f"{out}/timeline.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(f"{vid}: {k} lines, {t:.1f}s")
    if check:
        print(f"lines still differing after retries: {bad}")


def make_asr():
    import sherpa_onnx
    return sherpa_onnx.OfflineRecognizer.from_sense_voice(
        model=f"{ASR_DIR}/model.int8.onnx", tokens=f"{ASR_DIR}/tokens.txt", use_itn=False, language="zh", num_threads=4)


def asr_diffs(rec, w, sr, say):
    """Round-trip a take through ASR and compare pinyin with what we meant to say."""
    import difflib
    from pypinyin import lazy_pinyin
    strip = lambda s: re.sub(r"[^一-鿿]", "", s)
    s = rec.create_stream(); s.accept_waveform(sr, w); rec.decode_stream(s)
    got = strip(s.result.text); want = strip(say)
    pg = lazy_pinyin(got); pw = lazy_pinyin(want)
    if pg == pw:
        return []
    sm = difflib.SequenceMatcher(None, pw, pg)
    return [(want[i1:i2], got[j1:j2]) for op, i1, i2, j1, j2 in sm.get_opcodes() if op != "equal"]


if __name__ == "__main__":
    main()
