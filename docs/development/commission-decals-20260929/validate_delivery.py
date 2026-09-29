"""Validate this art-only delivery, without compiling or touching the device."""
from pathlib import Path
import hashlib
import json
import subprocess
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
BASE = '485b5d67308f2ea9dddac476d74a8d9af4f10cfa'
LAYOUT = 'mistport-ios/Mistport/WisteriaMap/home-map-layout.json'

def main():
    manifest = json.loads((HERE / 'originals-manifest.json').read_text())
    assert len(manifest['originals']) == 15
    for entry in manifest['originals']:
        path = REPO / entry['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
        assert Image.open(path).size == (4096, 2305), path
    metadata = json.loads((REPO / LAYOUT).read_text())
    entries = metadata.pop('commissionDecals')
    original = json.loads(subprocess.check_output(['git', 'show', BASE + ':' + LAYOUT], cwd=REPO))
    assert metadata == original, 'Existing layout data changed'
    assert len(entries) == 18
    assert len({e['id'] for e in entries}) == 18
    for entry in entries:
        assert entry['enabled'] is False
        assert entry['reviewStatus'] == 'pending-user-art-approval'
        assert entry['coordinateUnit'] == 'painting-height=1'
        assert (REPO / entry['file']).is_file(), entry['file']
    for place in ['喷泉广场', '台阶大道', '工坊货场']:
        for season in ['spring', 'summer', 'autumn', 'winter', 'winterSnow']:
            for time in ['day', 'sunset', 'night']:
                selected = [e for e in entries if e['place'] == place and season in e['seasons'] and time in e['times']]
                assert len(selected) == 1, (place, season, time)
    images = sorted((HERE / 'assets').glob('*.png'))
    assert len(images) == 20
    for path in images:
        im = Image.open(path)
        assert im.size == (512, 512), path
        if path.name.endswith('LightOrder.png'):
            assert im.mode == 'RGB'
        else:
            assert im.mode == 'RGBA', path
            lo, hi = im.getchannel('A').getextrema()
            assert lo == 0 and hi == 255, (path, lo, hi)
    review = json.loads((HERE / 'comparison-manifest.json').read_text())
    assert review['previewOnly'] and review['originalsUnchanged']
    assert review['comparisonCount'] == 45
    assert len(list((HERE / 'comparisons').glob('*.png'))) == 45
    for entry in review['comparisons']:
        assert (HERE / entry['comparison']).is_file()
    changed = subprocess.check_output(['git', 'diff', '--name-only', BASE], cwd=REPO, text=True).splitlines()
    assert all(p in [LAYOUT, 'docs/development/HANDOFF_WALLS_20260929.md'] or p.startswith('docs/development/commission-decals-20260929/') for p in changed), changed
    report = {
        'originalPlatesUnchanged': 15, 'existingLayoutFieldsUnchanged': True,
        'disabledPlacementEntries': 18, 'transparent512Assets': 19,
        'numeric512LightOrderAssets': 1, 'beforeAfterComparisons': 45,
        'coverage': '3 places × 5 seasons × 3 times; exactly one decal per scene',
        'appSourceOrAssetCatalogChanged': False,
        'iOSBuildRun': False, 'deviceInstalled': False, 'playerSavesTouched': False,
        'userVisualApproval': 'pending', 'imagesTrackedBy': 'Git LFS',
    }
    (HERE / 'validation.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps(report, ensure_ascii=False))

if __name__ == '__main__':
    main()
