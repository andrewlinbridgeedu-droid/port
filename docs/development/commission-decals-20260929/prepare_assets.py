"""Only size and register AI-painted cutouts; no painting or time-of-day tinting."""
from pathlib import Path
import json
from PIL import Image

HERE = Path(__file__).resolve().parent

def scaled(path):
    return Image.open(path).convert('RGBA').resize((512, 512), Image.Resampling.LANCZOS)

def import_yard():
    records = []
    for suffix in ['Day', 'Sunset', 'Night', 'SnowDay', 'SnowSunset', 'SnowNight']:
        file = 'CommissionYardV2' + suffix + '.png'
        raw = HERE / 'generated' / file
        if not raw.exists():
            continue
        source = scaled(raw)
        result = Image.new('RGBA',(512,512))
        groups = []
        for name, region, target in [
            ('canvas',(0,0,512,256),(325,82,389,196)),
            ('crates',(0,256,512,512),(237,307,338,379))]:
            crop = source.crop(region)
            box = crop.getchannel('A').point(lambda a: 255 if a>=32 else 0).getbbox()
            assert box, (file,name)
            x0,y0,x1,y1 = box
            tx0,ty0,tx1,ty1 = target
            if suffix.startswith('Snow'):
                ty0 -= 3
            fitted = crop.crop(box).resize((tx1-tx0,ty1-ty0),Image.Resampling.LANCZOS)
            result.alpha_composite(fitted,(tx0,ty0))
            groups.append({'group':name,'sourceBounds':box,'sourceRegion':region,'targetBounds':[tx0,ty0,tx1,ty1]})
        result.save(HERE / 'assets' / file)
        records.append({'file':file,'groups':groups})
    return records

def register_fountain():
    source = scaled(HERE / 'generated/CommissionFountainDay-v4.png')
    # The cutout contains two painted groups. Keep the pennants at their original
    # position and place the flowerbed on the fountain terrace, in source pixels.
    flags = Image.new('RGBA', source.size)
    flags.paste(source.crop((0, 0, 512, 237)), (0, 0))
    bed = source.crop((0, 237, 512, 512))
    result = Image.new('RGBA', source.size)
    result.alpha_composite(bed, (4, 199))  # +4 x, -38 y; artwork unchanged.
    result.alpha_composite(flags)
    result.save(HERE / 'assets/CommissionFountainDay.png')

def register_fountain_variants():
    # Image generation changes the transparent framing despite matching prompts.
    # Fit each painted group canvas to the day decal's footprint, preserving the
    # individually painted sunset/night colors. This is placement, not repainting.
    reference = Image.open(HERE / 'assets/CommissionFountainDay.png').convert('RGBA')
    target = reference.getchannel('A').point(lambda a: 255 if a >= 32 else 0).getbbox()
    records = []
    for suffix in ['Sunset', 'Night', 'SnowDay', 'SnowSunset', 'SnowNight']:
        file = 'CommissionFountain' + suffix + '.png'
        raw = HERE / 'generated' / file
        if not raw.exists():
            continue
        source = scaled(raw)
        box = source.getchannel('A').point(lambda a: 255 if a >= 32 else 0).getbbox()
        tx0, ty0, tx1, ty1 = target
        if suffix.startswith('Snow'):
            ty0 -= 4  # allowance for the newly painted snow caps
        fit = source.crop(box).resize((tx1 - tx0, ty1 - ty0), Image.Resampling.LANCZOS)
        result = Image.new('RGBA', (512, 512))
        result.alpha_composite(fit, (tx0, ty0))
        result.save(HERE / 'assets' / file)
        records.append({'file': file, 'sourcePaintedBounds': box, 'targetPaintedBounds': [tx0, ty0, tx1, ty1]})
    return records

def register_glow(variants, yard):
    source = scaled(HERE / 'generated/CommissionBoulevardLights-v3.png')
    targets = [(79, 70), (122, 117), (189, 163), (288, 212), (409, 273)]
    sizes = [1.0, .90, .83, .85, .78]
    # Disjoint cutout regions include each entire painted halo. Their bright
    # glass centers are translated to the matching lamp glass, never repainted.
    boxes = [(44, 32, 110, 98), (88, 80, 158, 158),
             (154, 132, 233, 214), (249, 204, 337, 294),
             (359, 269, 457, 373)]
    result = Image.new('RGBA', source.size)
    shifts = []
    for target, box, scale in zip(targets, boxes, sizes):
        crop = source.crop(box)
        weighted = []
        for y in range(crop.height):
            for x in range(crop.width):
                r, g, b, a = crop.getpixel((x, y))
                weight = max(0, min(r, g) - 175) * a
                if weight:
                    weighted.append((x, y, weight))
        total = sum(w for x, y, w in weighted)
        cx = sum(x * w for x, y, w in weighted) / total + box[0]
        cy = sum(y * w for x, y, w in weighted) / total + box[1]
        resized = crop.resize((round(crop.width * scale), round(crop.height * scale)), Image.Resampling.LANCZOS)
        left = round(target[0] - (cx - box[0]) * scale)
        top = round(target[1] - (cy - box[1]) * scale)
        result.alpha_composite(resized, (left, top))
        shifts.append({'glassCenter': target, 'translation': [left - box[0], top - box[1]], 'scale': scale})
    result.save(HERE / 'assets/CommissionBoulevardLights.png')
    (HERE / 'registration.json').write_text(json.dumps({
        'unit': '512-pixel asset canvas',
        'fountainFlowerbedTranslation': [4, -38],
        'fountainPennantsTranslation': [0, 0],
        'fountainVariantCanvasRegistration': variants,
        'boulevardGlowRegistration': shifts,
        'yardV2Registration': yard,
        'artworkRepaintedByScript': False,
    }, ensure_ascii=False, indent=2) + '\n')

if __name__ == '__main__':
    yard = import_yard()
    register_fountain()
    variants = register_fountain_variants()
    register_glow(variants, yard)
