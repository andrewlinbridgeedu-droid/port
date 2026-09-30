"""Validate the current two-place preview; historical lamp drafts are never active."""
from pathlib import Path
import hashlib,json,subprocess
from PIL import Image

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[2]
BASE='485b5d67308f2ea9dddac476d74a8d9af4f10cfa'
LAYOUT='mistport-ios/Mistport/WisteriaMap/home-map-layout.json'

def main():
    manifest=json.loads((HERE/'originals-manifest.json').read_text())
    assert len(manifest['originals'])==15
    for entry in manifest['originals']:
        path=REPO/entry['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256'],path
        assert Image.open(path).size==(4096,2305),path
    layout=json.loads((REPO/LAYOUT).read_text());entries=layout.pop('commissionDecals')
    old=json.loads(subprocess.check_output(['git','show',BASE+':'+LAYOUT],cwd=REPO))
    assert layout==old
    assert len(entries)==12 and len({e['id'] for e in entries})==12
    for entry in entries:
        assert entry['enabled'] is False and entry['reviewStatus']=='pending-user-art-approval'
        assert entry['artRevision']==3 and entry['coordinateUnit']=='painting-height=1'
        assert entry['zone'] in ['plaza','yard'] and 'lighting' not in entry
        assert '/assets/Commission' in entry['file'] and 'V3' in entry['file'] and 'history' not in entry['file']
        assert (REPO/entry['file']).is_file()
    for place in ['喷泉广场','工坊货场']:
        for season in ['spring','summer','autumn','winter','winterSnow']:
            for time in ['day','sunset','night']:
                assert len([e for e in entries if e['place']==place and season in e['seasons'] and time in e['times']])==1
    images=sorted((HERE/'assets').glob('*.png'))
    assert len(images)==12 and all('V3' in p.name and 'Boulevard' not in p.name for p in images)
    for path in images:
        im=Image.open(path);assert im.size==(512,512) and im.mode=='RGBA'
        lo,hi=im.getchannel('A').getextrema();assert lo==0 and hi>0
    provenance=json.loads((HERE/'generation-paths.json').read_text())
    assert len(provenance['outputs'])==12 and provenance['addedLamps']==0
    for entry in provenance['outputs']:
        assert (HERE/entry['source']).is_file() and (HERE/'assets'/entry['asset']).is_file()
        assert all((HERE/'prompts'/(p+'.txt')).is_file() for p in entry['prompts'])
    review=json.loads((HERE/'comparison-manifest.json').read_text())
    assert review['previewOnly'] and review['originalsUnchanged'] and review['comparisonCount']==30
    assert len(list((HERE/'comparisons').glob('*.png')))==30
    assert all(e['site'] in ['fountain','yard'] and (HERE/e['comparison']).is_file() for e in review['comparisons'])
    changed=subprocess.check_output(['git','diff','--name-only',BASE],cwd=REPO,text=True).splitlines()
    assert all(p in [LAYOUT,'docs/development/HANDOFF_WALLS_20260929.md'] or p.startswith('docs/development/commission-decals-20260929/') for p in changed),changed
    report={'artRevision':3,'originalPlatesUnchanged':15,'existingCityLightsUnchanged':True,
            'existingLayoutFieldsUnchanged':True,'disabledPlacementEntries':12,'transparent512Assets':12,
            'addedLamps':0,'addedLampGlowLayers':0,'beforeAfterComparisons':30,
            'coverage':'2 places × 5 seasons × 3 times; exactly one decal per selected scene',
            'withdrawnDrafts':'Five added boulevard lamps and all associated glow/order layers retained in history only',
            'appSourceOrAssetCatalogChanged':False,'iOSBuildRun':False,'deviceInstalled':False,
            'playerSavesTouched':False,'userVisualApproval':'pending','imagesTrackedBy':'Git LFS'}
    (HERE/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False))

if __name__=='__main__':
    main()
