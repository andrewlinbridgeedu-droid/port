"""Lossless channel packing for existing actors; keeps all original files in backup.
Run with Python + Pillow before ModelAssetOptimization20260916.ImportAndBuild.
"""
from pathlib import Path
from PIL import Image, ImageChops
import json, shutil
ROOT=Path(__file__).resolve().parents[2]
RES=ROOT/'UnityBattleSource/Assets/Resources/CharacterSurface20260916'
BACKUP=ROOT/'backups/model-optimization-20260916'
report=[]
for family in ['Guard','OldHound','Core','Ghost']:
    folder=RES/family
    channels=[]
    for name in ['metallic','roughness']:
        path=folder/(name+'.png')
        if not path.exists():
            path=ROOT/'UnityBattleSource/Assets/SourceOnly/CharacterSurface20260916'/family/(name+'.png')
        for source in [path,Path(str(path)+'.meta')]:
            if source.exists():
                dest=BACKUP/source.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True)
                if not dest.exists():shutil.copy2(source,dest)
        channels.append(Image.open(path).convert('RGB').getchannel('R'))
    metal,rough=channels
    assert metal.size==rough.size
    packed=Image.merge('RGB',(Image.new('L',metal.size,255),rough,metal))
    out=folder/'surface_orm.png';packed.save(out)
    restored=Image.open(out)
    assert ImageChops.difference(restored.getchannel('G'),rough).getbbox() is None
    assert ImageChops.difference(restored.getchannel('B'),metal).getbbox() is None
    report.append(dict(family=family,size=metal.size,source_maps=2,runtime_maps=1,channel_error=0))
folder=RES/'Story';folder.mkdir(exist_ok=True)
for name,source in [('Scribe','ArtSource/TranscriptionScribe20260916/Image_1_2k.png'),('Rescue','ArtSource/RescueBearer20260916/Rescue_ORM.png')]:
    Image.open(ROOT/source).convert('RGB').save(folder/(name+'_ORM.png'))
out=ROOT/'output/model-optimization-20260916';out.mkdir(parents=True,exist_ok=True)
(out/'texture-channel-verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
