"""Capture the UI art review using isolated, seeded simulator saves.
Build/install tools/housing/build_simulator_harness.py first. Never targets a device.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--simulator', required=True)
parser.add_argument('--destination', required=True, type=Path)
parser.add_argument('--screens', nargs='+', default=['events', 'neighbors', 'remnants', 'workshop', 'settings', 'skill', 'tasks', 'bounty', 'victory', 'defeat', 'profile', 'shop', 'offers', 'lease', 'tavern', 'poker'])
args = parser.parse_args()
bundle = 'local.mistport.housing-integration'
container = Path(subprocess.check_output(['xcrun', 'simctl', 'get_app_container', args.simulator, bundle, 'data'], text=True).strip())
args.destination.mkdir(parents=True, exist_ok=True)
manifest = args.destination / 'capture.json'
entries = json.loads(manifest.read_text()) if manifest.exists() else []
for screen in args.screens:
    bottom = screen.endswith('-bottom')
    page = screen.removesuffix('-bottom') if bottom else screen
    if page == 'lease':
        flags = ['--housing-device-walk', '--housing-screen=lease']
        source = 'housing-lease.png'
    elif page in ['tavern', 'poker']:
        flags = ['--daily-pacing-device-walk', '--daily-ui-review=' + page, '--preview-tavern-' + ('dialogue' if page == 'tavern' else 'poker')]
        source = 'ui-art-' + page + '.png'
    elif page in ['events', 'neighbors', 'remnants', 'workshop']:
        flags = ['--daily-pacing-device-walk', '--daily-' + page + '-preview']
        source = 'daily-pacing-' + page + '.png'
    elif page in ['settings', 'skill', 'tasks', 'bounty', 'victory', 'defeat', 'profile', 'shop', 'offers', 'newspaper', 'supplement', 'police', 'cityhall', 'harbor', 'board', 'post', 'clinic', 'oldstreet', 'cafe', 'agency', 'inventory', 'build', 'chapter-map', 'district-map', 'church', 'tower', 'battle-hud', 'poker-help']:
        flags = ['--daily-pacing-device-walk', '--daily-ui-review=' + page]
        source = 'ui-art-' + page + '.png'
    else:
        raise ValueError('Unsupported screenshot: ' + page)
    if bottom:
        flags.append('--daily-ui-review-bottom')
    stamp = time.time()
    subprocess.run(['xcrun', 'simctl', 'launch', '--terminate-running-process', args.simulator, bundle, *flags], check=True)
    file = container / 'Documents' / source
    for _ in range(100):
        if file.exists() and file.stat().st_mtime >= stamp:
            break
        time.sleep(.25)
    else:
        raise RuntimeError('No fresh screenshot: ' + page)
    shutil.copy2(file, args.destination / (screen + '.png'))
    entries = [entry for entry in entries if entry['page'] != screen]
    entries.append({'page': screen, 'file': screen + '.png', 'flags': flags, 'source': 'iOS Simulator, real SwiftUI view, isolated fixture', 'captured_at': time.time()})
    manifest.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n')
    print('Captured ' + screen, flush=True)
(args.destination / 'capture.json').write_text(json.dumps(entries, ensure_ascii=False, indent=2) + '\n')
