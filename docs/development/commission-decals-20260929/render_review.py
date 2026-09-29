"""Render offline art comparisons; never write to original plates or App assets."""
from pathlib import Path
import hashlib
import json

from PIL import Image, ImageChops, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
ASSETS = REPO / 'mistport-ios/Mistport/Assets.xcassets'
REGIONS = json.loads((HERE / 'regions.json').read_text())
PREFIXES = {'fountain': 'CommissionFountain', 'boulevard': 'CommissionBoulevard', 'yard': 'CommissionYard'}
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


def after_image(before, site, season, time):
    after = before.convert('RGBA')
    after.alpha_composite(Image.open(selected_asset(site, season, time)).convert('RGBA').resize(after.size, Image.Resampling.LANCZOS))
    if site == 'boulevard' and time != 'Day':
        glow = Image.open(HERE / 'assets/CommissionBoulevardLights.png').convert('RGBA').resize(after.size, Image.Resampling.LANCZOS)
        order = Image.open(HERE / 'assets/CommissionBoulevardLightOrder.png').convert('RGB').resize(after.size, Image.Resampling.NEAREST)
        on, strength = (0.20, 0.60) if time == 'Sunset' else (1.0, 1.0)
        show = order.getchannel('R').point(lambda v: 255 if v / 255 >= max(0.002, 1 - on) else 0)
        alpha = ImageChops.multiply(glow.getchannel('A'), show)
        added = Image.composite(glow.convert('RGB'), Image.new('RGB', after.size), alpha).point(lambda v: round(v * strength))
        return ImageChops.add(after.convert('RGB'), added)
    return after.convert('RGB')


def main():
    comparisons = HERE / 'comparisons'
    comparisons.mkdir(exist_ok=True)
    original_manifest = json.loads((HERE / 'originals-manifest.json').read_text())
    for entry in original_manifest['originals']:
        assert hashlib.sha256((REPO / entry['path']).read_bytes()).hexdigest() == entry['sha256'], entry['name']
    records, preview_rows = [], []
    for site, region in REGIONS.items():
        x, y, width, height = region['rect']
        box = (x, y, x + width, y + height)
        tiles = []
        for season in SEASONS:
            for time in TIMES:
                path = selected_asset(site, season, time)
                if not path.exists():
                    continue
                before = lighting(season, time, box)
                after = after_image(before, site, season, time)
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


if __name__ == '__main__':
    main()
