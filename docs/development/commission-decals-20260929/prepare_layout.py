"""Record disabled preview placement metadata; does not add an App renderer."""
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
LAYOUT = REPO / 'mistport-ios/Mistport/WisteriaMap/home-map-layout.json'
REGIONS = json.loads((HERE / 'regions.json').read_text())
PREFIXES = {'fountain': 'CommissionFountainV3', 'yard': 'CommissionYardV3'}

def main():
    entries = []
    for site, region in REGIONS.items():
        x, y, width, height = region['rect']
        for snow in [False, True]:
            for time in ['Day', 'Sunset', 'Night']:
                file = PREFIXES[site] + ('Snow' if snow else '') + time + '.png'
                entry = {
                    'id': site + ('-snow-' if snow else '-') + time.lower(),
                    'place': region['name'], 'zone': region['zone'],
                    'file': 'docs/development/commission-decals-20260929/assets/' + file,
                    'at': [round((x + width / 2) / 2305, 8), round((y + height / 2) / 2305, 8)],
                    'size': [round(width / 2305, 8), round(height / 2305, 8)],
                    'anchor': 'center', 'coordinateUnit': 'painting-height=1',
                    'seasons': ['winterSnow'] if snow else ['spring', 'summer', 'autumn', 'winter'],
                    'times': [time.lower()],
                    'enabled': False, 'reviewStatus': 'pending-user-art-approval',
                }
                entry['artRevision'] = 3
                entries.append(entry)
    text = LAYOUT.read_text()
    marker = ',\n  "commissionDecals": '
    assert marker in text
    existing=json.loads(text);existing.pop('commissionDecals')
    prefix=text[:text.index(marker)]
    field=json.dumps(entries,ensure_ascii=False,indent=2)
    updated=prefix+marker+field.replace('\n','\n  ')+'\n}\n'
    check=json.loads(updated);check.pop('commissionDecals')
    assert check==existing
    LAYOUT.write_text(updated)

if __name__ == '__main__':
    main()
