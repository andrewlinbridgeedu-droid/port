import json,sys
tl=json.load(open(f'build/{sys.argv[1]}/timeline.json',encoding='utf-8'))
prev=None
for b in tl['beats']:
    print(f"{b['t0']:7.1f}-{b['t1']:7.1f} {b['scene']:12s} {b.get('chapter') or ''}  cues: {[round(l['t0']-b['t0'],1) for l in b['lines']]}")
print('duration', tl['duration'])
