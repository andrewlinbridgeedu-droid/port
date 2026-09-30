"""Capture native housing views from an already-installed DEBUG device build.

Requires a successful local Preferences backup and build 169.12. Never installs
an app, writes player data, restores backups, or alters exported PNG pixels.
"""
import argparse
import hashlib
import json
import plistlib
import struct
import subprocess
import tempfile
import time
from pathlib import Path

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--device', required=True)
parser.add_argument('--preferences-backup', required=True, type=Path)
parser.add_argument('--destination', type=Path, default=root / 'docs/development/housing-app-20260930/device')
parser.add_argument('--screens', nargs='+', default=['agency', 'districts', 'cards', 'interior', 'lease', 'moving', 'residence', 'stamina', 'highland', 'home', 'home-night'])
args = parser.parse_args()
player = args.preferences_backup / 'mistport.player-test-01-15.plist'
plistlib.loads(player.read_bytes())  # Fail before any device launch if the backup is absent/unreadable.
args.destination.mkdir(parents=True, exist_ok=True)
bundle = 'com.yourcompany.mistport'

with tempfile.TemporaryDirectory(prefix='housing-device-capture-') as scratch:
    scratch = Path(scratch)

    def device_call(command):
        result_file = scratch / 'result.json'
        result_file.unlink(missing_ok=True)
        result = subprocess.run(['xcrun', 'devicectl', 'device', *command[:2],
                                 '--json-output', str(result_file), '--timeout', '25', *command[2:]],
                                capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(result.stdout + result.stderr)
        return json.loads(result_file.read_text())['result']

    app = device_call(['info', 'apps', '--device', args.device, '--bundle-id', bundle])['apps']
    if len(app) != 1 or app[0]['bundleVersion'] != '169.12':
        raise RuntimeError('Expected installed 169.12 before using its isolated housing fixture')

    def launch(screen):
        command = ['process', 'launch', '--device', args.device, '--terminate-existing',
                   bundle, '--', '--housing-device-walk', '--housing-screen=' + ('home' if screen == 'home-night' else screen)]
        if screen.startswith('home'):
            command += ['--home-map-review', '-MistportHubPanX', '0.265',
                        '-MistportCityHour', '22' if screen == 'home-night' else '12',
                        '-MistportCitySeason', 'autumn']
        return device_call(command)

    shots = []
    for screen in args.screens:
        if screen not in ['agency', 'districts', 'cards', 'interior', 'lease', 'moving', 'residence', 'stamina', 'highland', 'home', 'home-night']:
            raise ValueError('Unknown housing screen: ' + screen)
        launch(screen)
        time.sleep(6)  # The DEBUG native window exporter runs four seconds after launch.
        source = 'housing-' + ('home' if screen == 'home-night' else screen) + '.png'
        destination = args.destination / ('housing-' + screen + '.png')
        device_call(['copy', 'from', '--device', args.device, '--domain-type', 'appDataContainer',
                     '--domain-identifier', bundle, '--source', 'Documents/' + source,
                     '--destination', str(destination)])
        data = destination.read_bytes()
        if not data.startswith(b'\x89PNG\r\n\x1a\n'):
            raise RuntimeError('Invalid native PNG: ' + screen)
        width, height = struct.unpack('>II', data[16:24])
        shots.append({'file': destination.name, 'width': width, 'height': height,
                      'sha256': hashlib.sha256(data).hexdigest()})
        print('Captured physical device', screen, width, height, flush=True)

    for name in ['housing-verification.json', 'local-workshop-verification.json', 'church-tower-100-verification.json']:
        destination = args.destination / name
        device_call(['copy', 'from', '--device', args.device, '--domain-type', 'appDataContainer',
                     '--domain-identifier', bundle, '--source', 'Documents/' + name,
                     '--destination', str(destination)])
        if not json.loads(destination.read_text())['passed']:
            raise RuntimeError('Device self-check failed: ' + name)

    (args.destination / 'capture.json').write_text(json.dumps({
        'source': 'physical-device-native-window', 'device': args.device, 'build': '169.12',
        'screenshots': shots, 'isolatedFixture': True, 'userVisualApproval': False,
    }, ensure_ascii=False, indent=2) + '\n')
    launch('home')  # Leave the real home navigation available for the user's review.
    print('Device left on isolated home; Preferences comparison is still required', flush=True)
