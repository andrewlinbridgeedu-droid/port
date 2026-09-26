from pathlib import Path
import subprocess, os, time
root=Path(__file__).resolve().parents[2]
out=root/'output/character-art-upgrade-20260916'
player=next((Path(os.environ.get('MISTPORT_REVIEW_PLAYER','/tmp/mistport-character-art-verified.app'))/'Contents/MacOS').iterdir())
cases=[('closeups','MISTPORT_ART_CAPTURE','--capture-character-closeups'),('final','MISTPORT_CHARACTER_CAPTURE','--verify-character-polish'),('idle','MISTPORT_IDLE_CAPTURE','--verify-enemy-idle'),('hero-casts','MISTPORT_HERO_CAPTURE','--verify-hero-choreography'),('fade','MISTPORT_FADE_CAPTURE','--verify-enemy-death-fade'),('story','MISTPORT_STORY_CAPTURE','--verify-story-models')]
selected=os.environ.get('MISTPORT_REVIEW_CASES')
if selected:cases=[x for x in cases if x[0] in selected.split(',')]
for folder,var,flag in cases:
 dest=out/folder;dest.mkdir(exist_ok=True)
 (dest/'passed.txt').unlink(missing_ok=True)
 env=os.environ.copy();env[var]=str(dest);env['MISTPORT_CHARACTER_FRAMES']='240'
 log=out/(folder+'-runtime.log')
 print('START',folder,flush=True)
 with open(out/(folder+'-launch.log'),'w') as stream:
  r=subprocess.run([str(player),flag,'-logFile',str(log)],env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=1800)
 if r.returncode or not (dest/'passed.txt').exists():raise RuntimeError(f'{folder} failed {r.returncode}: {log}')
 print('PASS',folder,flush=True)
(out/('runtime-suite-passed.txt' if not selected else 'runtime-selected-passed.txt')).write_text('\n'.join(x[0] for x in cases))
