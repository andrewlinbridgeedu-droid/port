"""Run the DEBUG production-store checks in the dedicated disposable iOS host."""
import json
import shutil
import subprocess
import time
from pathlib import Path

root = Path(__file__).resolve().parents[2]
device = '4355D11F-63D1-4874-BAC6-E5E372D40EA7'
bundle = 'local.mistport.workshop-integration'
evidence = root / 'docs/development/local-workshop-integration-20260928'
container = Path(subprocess.check_output(
    ['xcrun', 'simctl', 'get_app_container', device, bundle, 'data'], text=True).strip())
report = container / 'Documents/local-workshop-verification.json'
# Only this disposable bundle's test output is removed; no preference or save changes.
report.unlink(missing_ok=True)
subprocess.run(['xcrun', 'simctl', 'launch', device, bundle, '--verify-local-workshop'], check=True)
for _ in range(60):
    if report.exists():
        result = json.loads(report.read_text())
        for name in ('local-workshop-verification.json', 'local-workshop-before.png', 'local-workshop-complete.png'):
            source = report.parent / name
            if source.exists():
                shutil.copy2(source, evidence / name)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        if not result.get('passed'):
            raise SystemExit(1)
        break
    time.sleep(1)
else:
    raise SystemExit('Timed out: verification report not produced')
