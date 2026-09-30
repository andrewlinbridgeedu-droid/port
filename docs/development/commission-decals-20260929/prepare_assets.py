"""Register painted V3 cutouts; no painting, tinting or original-plate changes."""
from pathlib import Path
import json
from PIL import Image

HERE=Path(__file__).resolve().parent
SUFFIXES=['Sunset','Night','SnowDay','SnowSunset','SnowNight']

def scaled(path):
    return Image.open(path).convert('RGBA').resize((512,512),Image.Resampling.LANCZOS)

def bounds(image):
    box=image.getchannel('A').point(lambda a:255 if a>=32 else 0).getbbox()
    assert box
    return box

def fit(image,target):
    source=bounds(image)
    x,y,r,b=target
    out=Image.new('RGBA',(512,512))
    out.alpha_composite(image.crop(source).resize((r-x,b-y),Image.Resampling.LANCZOS),(x,y))
    return out,source

def main():
    records=[]
    fountain,box=fit(scaled(HERE/'generated/CommissionFountainV3FlowerbedDay.png'),[122,202,400,287])
    # Existing painted Day pennants remain identical; only the flowerbed changes.
    flags=scaled(HERE/'generated/CommissionFountainDay-v4.png').crop((0,0,512,237))
    fountain.alpha_composite(flags,(0,0))
    fountain.save(HERE/'assets/CommissionFountainV3Day.png')
    records.append({'file':'CommissionFountainV3Day.png','flowerbedSourceBounds':box,
                    'flowerbedTargetBounds':[122,202,400,287],'pennants':'original painted Day crop [0,0,512,237]'})
    raw=scaled(HERE/'generated/CommissionYardV3Day.png')
    canvas,cbox=fit(raw.crop((0,0,512,269)),[315,71,400,190])
    # Rotate to follow the existing diagonal crane boom. Nothing is painted by code.
    canvas=canvas.rotate(-15,resample=Image.Resampling.BICUBIC,center=(315,71))
    native=Image.new('RGBA',(1080,1080))
    native.alpha_composite(canvas.resize((800,800),Image.Resampling.LANCZOS),(280,0))
    yard=native.resize((512,512),Image.Resampling.LANCZOS)
    crates,kbox=fit(raw.crop((0,269,512,512)),[130,397,240,485])
    yard.alpha_composite(crates)
    yard.save(HERE/'assets/CommissionYardV3Day.png')
    records.append({'file':'CommissionYardV3Day.png','canvasSourceBounds':cbox,
                    'canvasInOld800Frame':[315,71,400,190],'canvasRotationDegreesClockwise':15,
                    'old800FrameOffsetInNew1080Frame':[280,0],
                    'crateSourceBounds':kbox,'crateTargetBounds':[130,397,240,485],
                    'crateFootNativePixels':[274.21875,1023.046875,506.25]})
    for site,reference in [('Fountain',fountain),('Yard',yard)]:
        for suffix in SUFFIXES:
            file='Commission'+site+'V3'+suffix+'.png'
            path=HERE/'generated'/file
            if not path.exists():
                continue
            source=scaled(path);result=Image.new('RGBA',(512,512));groups=[]
            regions=[(0,0,512,512)] if site=='Fountain' else [(0,0,512,265),(0,265,512,512)]
            for region in regions:
                original=reference.crop(region)
                target=bounds(original)
                target=[target[0],target[1]+region[1],target[2],target[3]+region[1]]
                if suffix.startswith('Snow'):
                    target[1]-=2
                group,sourcebox=fit(source.crop(region),target)
                result.alpha_composite(group)
                groups.append({'sourceRegion':region,'sourceBounds':sourcebox,'targetBounds':target})
            result.save(HERE/'assets'/file)
            records.append({'file':file,'groups':groups})
    (HERE/'registration.json').write_text(json.dumps({
        'artRevision':3,'unit':'512-pixel asset canvas','artworkRepaintedByScript':False,
        'addedLamps':0,'registrations':records,
        'note':'Palette and snow are individually image-generated. Code only crops, rotates, scales and places painted pixels.'
    },ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':
    main()
