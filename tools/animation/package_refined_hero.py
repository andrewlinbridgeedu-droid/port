"""Preserve labelled, uncut runtime model probes and their actual source hashes."""
import hashlib, json, shutil, subprocess
from pathlib import Path
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'output/hero-refinement-20261001/runtime-release'
DOC=ROOT/'docs/development/hero-refinement-20261001'
FF=imageio_ffmpeg.get_ffmpeg_exe()
if not (SRC/'passed.txt').is_file() or (SRC/'failed.txt').exists():
    raise SystemExit('Current runtime verification has not passed')
assets=ROOT/'UnityBattleSource/Assets/Resources/CombatTempo/RefinedHero'
hashes={}
for path in sorted(assets.glob('*')):
    if path.is_file() and path.suffix!='.meta':hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
for name in ['CombatTempoAnimatedBody','CombatTempoPresentation','RefinedHeroAppearance','RefinedHeroCapture','UnityBattleBridge']:
    path=ROOT/('UnityBattleSource/Assets/Scripts/'+name+'.cs')
    hashes[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
for path in SRC.glob('*.png'):shutil.copy2(path,DOC/path.name)
shutil.copy2(SRC/'passed.txt',DOC/'unity-verification.txt')
names=['CastMaskFlick','CastMaskTurn','CastTwinSweep','CastTwinCross','CastFinaleLift','CastFinaleThrow','CastCardFan']
for name in names:
    files=list((SRC/name).glob('*.png'))
    if len(files)!=48:raise SystemExit('Missing real frames: '+name)
    subprocess.run([FF,'-y','-hide_banner','-loglevel','error','-framerate','30','-i',str(SRC/name/'%04d.png'),
        '-vf',"pad=iw:ih+44:0:44:color=0x142129,drawtext=fontfile='/System/Library/Fonts/Supplemental/Arial.ttf':text='"+name+" - Unity model probe':x=12:y=12:fontsize=18:fontcolor=white",
        '-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(DOC/(name+'.mp4'))],check=True)
listing=DOC/'seven-casts-order.txt'
listing.write_text(''.join("file '"+name+".mp4'\n" for name in names))
subprocess.run([FF,'-y','-hide_banner','-loglevel','error','-f','concat','-safe','0','-i',str(listing),'-c','copy','-movflags','+faststart',str(DOC/'seven-casts-unity.mp4')],check=True)
(DOC/'verification.json').write_text(json.dumps({'kind':'Standalone Unity model probes, not iPhone recordings','outfits':3,'sharedController':True,'spellBodyGestures':7,'framesPerGesture':48,'fps':30,'realSkillCasts':12,'speeds':[1,2],'outfitSwitchPreservesActionTime':True,'sampleExitCancelsLateContact':True,'userVisualApproval':False,'sourceSHA256':hashes},indent=2)+'\n')
print('Packaged seven actual Unity gestures and three costumes; no device/approval claim')
