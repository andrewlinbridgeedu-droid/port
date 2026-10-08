import json, sys, os, soundfile as sf, sherpa_onnx
vid=sys.argv[1]; ks=[int(x) for x in sys.argv[2].split(',')]
tl=json.load(open(f'build/{vid}/timeline.json',encoding='utf-8'))
A=os.environ['ASR_DIR']
rec=sherpa_onnx.OfflineRecognizer.from_sense_voice(model=f"{A}/model.int8.onnx",tokens=f"{A}/tokens.txt",use_itn=False,language="zh",num_threads=4)
for b in tl['beats']:
  for l in b['lines']:
    if l['k'] in ks:
      a,sr=sf.read(f"build/{vid}/voice/{l['wav']}",dtype='float32'); s=rec.create_stream(); s.accept_waveform(sr,a); rec.decode_stream(s)
      print(l['k'], 'SAY:', l['say']); print('    ASR:', s.result.text)
