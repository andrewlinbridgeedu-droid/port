#!/bin/zsh
set -euo pipefail
SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h:h}"
CHECK_DIR="$(mktemp -d /tmp/mistport-workshop-check.XXXXXX)"
mkdir -p "$CHECK_DIR/Tests"
cp "$PROJECT_DIR/mistport-ios/MistportCombatCore/Tests/MistportCombatCoreTests/WorkshopPlaytestTests.swift" "$CHECK_DIR/Tests/"
cp "$PROJECT_DIR/mistport-ios/MistportCombatCore/Tests/MistportCombatCoreTests/CampaignBattleSandboxTests.swift" "$CHECK_DIR/Tests/"
python3 - "$CHECK_DIR" "$PROJECT_DIR" <<'PY'
import json, sys
from pathlib import Path
check, project = map(Path, sys.argv[1:])
dependency = json.dumps(str(project / 'mistport-ios/MistportCombatCore'))
(check / 'Package.swift').write_text('''// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "WorkshopFocusedValidation", platforms: [.macOS(.v14)],
    dependencies: [.package(path: ''' + dependency + ''')],
    targets: [.testTarget(name: "WorkshopFocusedTests",
        dependencies: [.product(name: "MistportCombatCore", package: "MistportCombatCore")],
        path: "Tests")])
''')
PY
# Source copies are temporary; production manifest/test membership is unchanged.
swift test --package-path "$CHECK_DIR" --scratch-path /tmp/mistport-campaign-build -j 1
