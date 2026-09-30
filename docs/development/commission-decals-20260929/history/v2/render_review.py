"""Render offline art comparisons; never write to original plates or App assets."""
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
ASSETS = REPO / 'mistport-ios/Mistport/Assets.xcassets'
REGIONS = json.loads((HERE / 'regions.json').read_text())
PREFIXES = {'fountain': 'CommissionFountain', 'boulevard': 'CommissionBoulevard', 'yard': 'CommissionYardV2'}
SEASONS = {'Spring': '春', 'Summer': '夏', 'Autumn': '秋', 'Winter': '冬', 'WinterSnow': '冬雪'}
TIMES = {'Day': '白天', 'Sunset': '黄昏', 'Night': '夜晚'}
FONT_PATH = '/System/Library/Fonts/Supplemental/Songti.ttc'
FONT = ImageFont.truetype(FONT_PATH, 20)
TITLE_FONT = ImageFont.truetype(FONT_PATH, 25)


def plate_path(name, ext='jpg'):
    return ASSETS / (name + '.imageset') / (name + '.' + ext)


def lighting(season, time, box):
    """Same additive RGB light texture and R/G thresholds as HarborLampsLayer."""
    name = 'City' + season + time
    raw = Image.open(plate_path(name)).convert('RGB')
    if time == 'Day':
        return raw.crop(box)
    on, strength = (0.20, 0.60) if time == 'Sunset' else (1.0, 1.0)
    lights = Image.open(plate_path('City' + season + 'Lights')).convert('RGB')
    order = Image.open(plate_path('City' + season + 'LightOrder', 'png')).convert('RGB').resize(raw.size, Image.Resampling.NEAREST)
    red = order.getchannel('R').point(lambda v: 255 if v / 255 >= max(0.002, 1 - on) else 0)
    green = order.getchannel('G').point(lambda v: 255 if v > 0 else 0)
    show = ImageChops.multiply(red, green)
    added = Image.composite(lights, Image.new('RGB', raw.size), show).point(lambda v: round(v * strength))
    return ImageChops.add(raw, added).crop(box)


def selected_asset(site, season, time):
    snow = 'Snow' if season == 'WinterSnow' else ''
    return HERE / 'assets' / (PREFIXES[site] + snow + time + '.png')


def placed(file, frame, box, mode='RGBA', resampling=Image.Resampling.LANCZOS):
    x, y, width, height = frame
    source = Image.open(file).convert(mode).resize((width, height), resampling)
    canvas = Image.new(mode, (box[2] - box[0], box[3] - box[1]))
    left, top = max(x, box[0]), max(y, box[1])
    right, bottom = min(x + width, box[2]), min(y + height, box[3])
    if right > left and bottom > top:
        canvas.paste(source.crop((left-x, top-y, right-x, bottom-y)), (left-box[0], top-box[1]))
    return canvas

def added_light(after, file, order_file, frame, box, time, intensity=1):
    glow = placed(file, frame, box)
    order = placed(order_file, frame, box, 'RGB', Image.Resampling.NEAREST)
    on, strength = (0.20, 0.60) if time == 'Sunset' else (1.0, 1.0)
    show = order.getchannel('R').point(lambda v: 255 if v / 255 >= max(0.002, 1 - on) else 0)
    alpha = ImageChops.multiply(glow.getchannel('A'), show)
    added = Image.composite(glow.convert('RGB'), Image.new('RGB', after.size), alpha).point(lambda v: round(v * strength * intensity))
    return ImageChops.add(after.convert('RGB'), added)

def after_image(before, site, season, time, box, version=2):
    frame = REGIONS[site]['rect']
    file = selected_asset(site, season, time)
    if site == 'yard' and version == 1:
        file = HERE / 'assets/history/yard-v1' / ('CommissionYard' + ('Snow' if season == 'WinterSnow' else '') + time + '.png')
    after = before.convert('RGBA')
    after.alpha_composite(placed(file, frame, box))
    if site == 'boulevard' and time != 'Day':
        after = added_light(after, HERE / 'assets/CommissionBoulevardLights.png', HERE / 'assets/CommissionBoulevardLightOrder.png', frame, box, time)
        if version == 2:
            snow = 'Snow' if season == 'WinterSnow' else ''
            after = added_light(after, HERE / 'assets' / ('CommissionBoulevard' + snow + 'GroundLights.png'), HERE / 'assets/CommissionBoulevardGroundLightOrder.png', REGIONS[site]['groundLightingRect'], box, time, .28)
    return after.convert('RGB')


def main():
    comparisons = HERE / 'comparisons'
    comparisons.mkdir(exist_ok=True)
    original_manifest = json.loads((HERE / 'originals-manifest.json').read_text())
    for entry in original_manifest['originals']:
        assert hashlib.sha256((REPO / entry['path']).read_bytes()).hexdigest() == entry['sha256'], entry['name']
    records, preview_rows = [], []
    for site, region in REGIONS.items():
        x, y, width, height = region.get('reviewRect', region['rect'])
        box = (x, y, x + width, y + height)
        tiles = []
        for season in SEASONS:
            for time in TIMES:
                path = selected_asset(site, season, time)
                if not path.exists():
                    continue
                before = lighting(season, time, box)
                after = after_image(before, site, season, time, box)
                name = f'{site}-City{season}{time}'
                pair = Image.new('RGB', (2 * width + 16, height + 60), '#18242c')
                pair.paste(before, (0, 60)); pair.paste(after, (width + 16, 60))
                draw = ImageDraw.Draw(pair)
                title = f"{region['name']} · {SEASONS[season]} · {TIMES[time]}"
                draw.text((12, 12), title + '  贴前', font=TITLE_FONT, fill='#efe5cf')
                draw.text((width + 28, 12), '贴后 · 待审核图稿', font=TITLE_FONT, fill='#efe5cf')
                pair.save(comparisons / (name + '.png'))
                tile = pair.resize((540, round(pair.height * 540 / pair.width)), Image.Resampling.LANCZOS)
                tiles.append((season, time, tile))
                if season == 'Autumn' and time == 'Day':
                    preview_rows.append(pair.resize((1000, round(pair.height * 1000 / pair.width)), Image.Resampling.LANCZOS))
                records.append({'site': site, 'plate': 'City' + season + time, 'decal': str(path.relative_to(HERE)), 'comparison': f'comparisons/{name}.png', 'lighting': 'existing CityLights R/G order, sunset on=0.20 strength=0.60; night on=1 off=0'})
        if tiles:
            cell_h = max(tile.height for _, _, tile in tiles) + 12
            contact = Image.new('RGB', (1620, 5 * cell_h), '#18242c')
            for season, time, tile in tiles:
                contact.paste(tile, (list(TIMES).index(time) * 540, list(SEASONS).index(season) * cell_h))
            contact.save(HERE / (site + '-all-seasons.jpg'), quality=94)
    if len(preview_rows) == 3:
        overview = Image.new('RGB', (1000, sum(im.height for im in preview_rows) + 32), '#18242c')
        top = 0
        for row in preview_rows:
            overview.paste(row, (0, top)); top += row.height + 16
        overview.save(HERE / 'autumn-day-overview.jpg', quality=95)
    report = {'previewOnly': True, 'originalsUnchanged': True, 'comparisonCount': len(records), 'comparisons': records}
    (HERE / 'comparison-manifest.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print('Originals unchanged: 15; comparisons:', len(records))

    # Matching crops compare the feedback revision against the original PR art.
    revision_rows = []
    for site, time in [('boulevard', 'Night'), ('yard', 'Day')]:
        x, y, w, h = REGIONS[site].get('reviewRect', REGIONS[site]['rect'])
        box = (x, y, x+w, y+h)
        before = lighting('Autumn', time, box)
        old = after_image(before, site, 'Autumn', time, box, version=1)
        new = after_image(before, site, 'Autumn', time, box)
        pair = Image.new('RGB', (2*w+16, h+60), '#18242c')
        pair.paste(old, (0,60)); pair.paste(new,(w+16,60))
        d = ImageDraw.Draw(pair)
        d.text((12,12), REGIONS[site]['name'] + ' · 原 PR 图稿', font=TITLE_FONT, fill='#efe5cf')
        d.text((w+28,12), '修订图稿 · 待确认', font=TITLE_FONT, fill='#efe5cf')
        revision_rows.append(pair.resize((1000, round(pair.height*1000/pair.width)), Image.Resampling.LANCZOS))
    revision = Image.new('RGB',(1000,sum(im.height for im in revision_rows)+16),'#18242c')
    y = 0
    for im in revision_rows:
        revision.paste(im,(0,y)); y += im.height+16
    revision.save(HERE/'revision-v2-overview.jpg',quality=95)

    # Realistic 390pt viewport scaling; this is an offline art preview, not a device capture.
    box = (2914, 0, 4096, 2305)
    base = lighting('Autumn','Day',box)
    phone = Image.new('RGB',(796,810),'#18242c')
    d = ImageDraw.Draw(phone)
    d.text((12,12),'货场 · 手机宽度参考 · 原稿',font=FONT,fill='#efe5cf')
    d.text((410,12),'新版 · 离线图，非真机',font=FONT,fill='#efe5cf')
    for version, x in [(1,0),(2,406)]:
        scene = after_image(base,'yard','Autumn','Day',box,version=version)
        phone.paste(scene.resize((390,760),Image.Resampling.LANCZOS),(x,50))
    phone.save(HERE/'yard-phone-width-v2.jpg',quality=96)


if __name__ == '__main__':
    main()
