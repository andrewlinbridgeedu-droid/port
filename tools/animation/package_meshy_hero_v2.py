"""Package actual Unity captures; original v1 evidence is kept in its own directory."""
import hashlib, json, shutil, subprocess, sys
from pathlib import Path
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[2]
SRC=Path(sys.argv[1]);BEFORE=Path(sys.argv[2])
DOC=ROOT/'docs/development/hero-refinement-20261001/v2'
FF=imageio_ffmpeg.get_ffmpeg_exe()
for folder in [SRC,BEFORE]:
    if not (folder/'passed.txt').is_file() or (folder/'failed.txt').exists():raise SystemExit('Unverified capture: '+str(folder))
for p in SRC.glob('*.png'):shutil.copy2(p,DOC/p.name)
shutil.copy2(SRC/'passed.txt',DOC/'unity-verification.txt')
shutil.copy2(BEFORE/'mistport-night-close.png',DOC/'rejected-v1-close.png')
names=['CastMaskFlick','CastMaskTurn','CastTwinSweep','CastTwinCross','CastFinaleLift','CastFinaleThrow','CastCardFan']
outfits=['mistport-night','starlight-magician','midnight-carnival']
for outfit in outfits:
    for name in names:
        frames=SRC/(outfit+'-'+name)
        if len(list(frames.glob('*.png')))!=48:raise SystemExit('Incomplete frame sequence '+str(frames))
        subprocess.run([FF,'-y','-hide_banner','-loglevel','error','-framerate','30','-i',str(frames/'%04d.png'),'-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(DOC/(outfit+'-'+name+'.mp4'))],check=True)
    listing=DOC/(outfit+'-casts-order.txt')
    listing.write_text(''.join("file '"+outfit+'-'+name+".mp4'\n" for name in names))
    subprocess.run([FF,'-y','-hide_banner','-loglevel','error','-f','concat','-safe','0','-i',str(listing),'-c','copy','-movflags','+faststart',str(DOC/(outfit+'-seven-casts.mp4'))],check=True)
for name in names:
    before=BEFORE/name;after=SRC/('mistport-night-'+name)
    subprocess.run([FF,'-y','-hide_banner','-loglevel','error','-framerate','30','-i',str(before/'%04d.png'),'-framerate','30','-i',str(after/'%04d.png'),
       '-filter_complex',"[0:v]pad=iw:ih+38:0:38:color=0x182129,drawtext=fontfile='/System/Library/Fonts/Supplemental/Arial.ttf':text='Rejected v1 - Unity':x=12:y=10:fontsize=18:fontcolor=white[a];[1:v]pad=iw:ih+38:0:38:color=0x182129,drawtext=fontfile='/System/Library/Fonts/Supplemental/Arial.ttf':text='Meshy v2 - Unity':x=12:y=10:fontsize=18:fontcolor=white[b];[a][b]hstack=inputs=2[v]",'-map','[v]','-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(DOC/(name+'-comparison.mp4'))],check=True)
hashes={}
for folder in [ROOT/'UnityBattleSource/Assets/Resources/CombatTempo/RefinedHeroV2']:
    for p in sorted(folder.glob('*')):
        if p.is_file() and p.suffix!='.meta':hashes[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['CombatTempoPresentation','RefinedHeroAppearance','RefinedHeroCapture','CombatTempoAnimatedBody']:
    p=ROOT/('UnityBattleSource/Assets/Scripts/'+name+'.cs');hashes[str(p.relative_to(ROOT))]=hashlib.sha256(p.read_bytes()).hexdigest()
for relative in ['UnityBattleSource/Assets/Editor/RefinedHeroV2Import.cs','UnityBattleSource/Assets/Shaders/HeroBrocadeV2.shader','tools/animation/build_meshy_hero_v2.py','tools/animation/render_meshy_hero_v2.py','docs/development/hero-refinement-20261001/v2/HeroMeshy-v2.blend']:
    p=ROOT/relative; hashes[relative]=hashlib.sha256(p.read_bytes()).hexdigest()
(DOC/'verification.json').write_text(json.dumps({'kind':'Standalone Unity model probe, not iPhone','outfits':3,'bodyGestures':7,'gestureSequences':21,'fps':30,'framesPerSequence':48,'realProductionCasts':12,'speeds':[1,2],'outfitChangePreservesAction':True,'sceneAndCameraUnchangedByOutfit':True,'oldModelRestoredOnSampleExit':True,'userVisualApproval':False,'installed':False,'sourceSHA256':hashes},indent=2)+'\n')
print('Packaged v2, 21 real gesture sequences and 7 v1 comparisons using the same full-height framing rule')
