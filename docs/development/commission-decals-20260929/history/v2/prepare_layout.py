"""Record disabled preview placement metadata; does not add an App renderer."""
from pathlib import Path
import json

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
LAYOUT = REPO / 'mistport-ios/Mistport/WisteriaMap/home-map-layout.json'
REGIONS = json.loads((HERE / 'regions.json').read_text())
PREFIXES = {'fountain': 'CommissionFountain', 'boulevard': 'CommissionBoulevard', 'yard': 'CommissionYardV2'}

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
                if site == 'boulevard':
                    entry['lighting'] = {
                        'file': 'docs/development/commission-decals-20260929/assets/CommissionBoulevardLights.png',
                        'orderFile': 'docs/development/commission-decals-20260929/assets/CommissionBoulevardLightOrder.png',
                        'blend': 'plusLighter', 'alpha': 'premultiply-once',
                        'orderChannels': {'R': '1 - lampTurnOn', 'G': 'lampTurnOff', 'B': 'unused'},
                        'enabledIn': ['sunset', 'night'],
                        'runtimeIntegration': 'pending-user-art-approval',
                    }
                    gx, gy, gw, gh = region['groundLightingRect']
                    entry['lighting']['ground'] = {
                        'file': 'docs/development/commission-decals-20260929/assets/CommissionBoulevard' + ('Snow' if snow else '') + 'GroundLights.png',
                        'orderFile': 'docs/development/commission-decals-20260929/assets/CommissionBoulevardGroundLightOrder.png',
                        'at': [(gx+gw/2)/2305,(gy+gh/2)/2305],
                        'size': [gw/2305,gh/2305],
                        'anchor': 'center', 'coordinateUnit': 'painting-height=1',
                        'blend': 'plusLighter', 'intensity': .28, 'enabledIn': ['sunset','night'],
                    }
                if site in ['boulevard','yard']:
                    entry['artRevision'] = 2
                entries.append(entry)
    text = LAYOUT.read_text()
    assert 'commissionDecals' not in text, 'Do not overwrite existing decal metadata'
    assert text.rstrip().endswith('}')
    field = json.dumps(entries, ensure_ascii=False, indent=2)
    text = text.rstrip()[:-1].rstrip() + ',\n  "commissionDecals": ' + field.replace('\n', '\n  ') + '\n}\n'
    json.loads(text)
    LAYOUT.write_text(text)

if __name__ == '__main__':
    main()
