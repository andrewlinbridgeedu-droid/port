#!/usr/bin/env python3
"""Launch the installed isolated DEBUG fixture and export native ReplayKit files.

Requires a Preferences backup and an exact installed build. Does not install,
restore, edit preferences, automate consent, or fabricate a recording on error.
"""
import argparse
import hashlib
import json
import plistlib
import subprocess
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument("--device", required=True)
p.add_argument("--build", required=True)
p.add_argument("--preferences-backup", type=Path, required=True)
p.add_argument("--destination", type=Path, required=True)
p.add_argument("--baseline", action="store_true")
p.add_argument("--sample", choices=["q4", "d01", "b01", "hero", "home"], required=True)
p.add_argument("--speed", type=int, choices=[1, 2], required=True)
a = p.parse_args()
for name in ["mistport.player-test-01-15.plist", "mistport.player-test-01-15.audit.plist"]:
    plistlib.loads((a.preferences_backup / name).read_bytes())
if not a.build.startswith("169."):
    raise SystemExit("Only the requested 169.x device build is allowed")
a.destination.mkdir(parents=True, exist_ok=True)
BUNDLE = "com.yourcompany.mistport"
stem = "tempo-" + ("before" if a.baseline else "after") + "-" + a.sample + "-x" + str(a.speed)

with tempfile.TemporaryDirectory(prefix="tempo-device-") as scratch:
    scratch = Path(scratch)

    def device(command, optional=False):
        receipt = scratch / "command.json"
        receipt.unlink(missing_ok=True)
        result = subprocess.run(["xcrun", "devicectl", "device", *command[:2],
            "--json-output", str(receipt), "--timeout", "45", *command[2:]], capture_output=True, text=True)
        if result.returncode:
            if optional:
                return None
            raise RuntimeError(result.stdout + result.stderr)
        return json.loads(receipt.read_text())["result"]

    def copy(name, optional=False):
        dest = a.destination / name
        result = device(["copy", "from", "--device", a.device, "--domain-type", "appDataContainer",
            "--domain-identifier", BUNDLE, "--source", "Documents/" + name,
            "--destination", str(dest)], optional)
        return dest if result is not None else None

    app = device(["info", "apps", "--device", a.device, "--bundle-id", BUNDLE])["apps"]
    if len(app) != 1 or app[0]["bundleVersion"] != a.build:
        raise SystemExit("Installed build differs from requested " + a.build)
    args = ["--tempo-device-review=" + a.sample, "--tempo-speed=" + str(a.speed), "--tempo-record-auto"]
    if a.baseline:
        args += ["--tempo-baseline"]
    if a.sample == "home":
        args += ["-MistportCityHour", "12", "-MistportCitySeason", "autumn",
            "-MistportCityRain", "0.9", "-MistportCityStorm", "0.8"]
    began = datetime.now(timezone.utc)
    device(["process", "launch", "--device", a.device, "--terminate-existing", BUNDLE, "--", *args])
    print("Launched isolated native fixture:", stem, a.build, flush=True)
    deadline = time.monotonic() + 240
    previous = None
    while time.monotonic() < deadline:
        time.sleep(6)
        path = copy(stem + ".json", optional=True)
        if path is None:
            continue
        report = json.loads(path.read_text())
        written = report.get("writtenAt")
        if not written or datetime.fromisoformat(written.replace("Z", "+00:00")) < began.replace(microsecond=0):
            continue
        if report["build"] != a.build or report["baseline"] != a.baseline or report["sample"] != a.sample:
            raise SystemExit("Wrong native fixture receipt")
        if report["outcome"] != previous:
            print("Native state:", report["outcome"], report.get("recordingError", ""), flush=True)
            previous = report["outcome"]
        if "error" in report["outcome"]:
            copy(stem + "-error.png", optional=True)
            raise SystemExit("Native recording failed; no valid battle video exported")
        if report["completed"]:
            video = copy(stem + ".mp4")
            shot = copy(stem + ".png")
            receipt = dict(report)
            receipt["videoSHA256"] = hashlib.sha256(video.read_bytes()).hexdigest()
            receipt["screenshotSHA256"] = hashlib.sha256(shot.read_bytes()).hexdigest()
            (a.destination / (stem + "-export.json")).write_text(json.dumps(receipt, indent=2) + "\n")
            print("Exported native complete recording:", report["outcome"], video, flush=True)
            break
        if report["outcome"] == "timeout":
            raise SystemExit("Battle timed out; not a completed recording")
    else:
        raise SystemExit("No fresh complete native recording receipt within 240 seconds")
