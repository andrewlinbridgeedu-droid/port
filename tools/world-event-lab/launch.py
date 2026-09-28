"""User-invoked double-click launcher. No profile/account changes."""
import json
import subprocess
import sys
import threading
import urllib.request
import webbrowser
from pathlib import Path

url='http://127.0.0.1:8876'
try:
    with urllib.request.urlopen(url+'/api/defaults',timeout=1) as response:
        data=json.load(response)
    available='fixed_active_cohort' in data and 'launch_guard' in data
except Exception:
    available=False

if available:
    webbrowser.open(url)
else:
    timer=threading.Timer(1.5,lambda:webbrowser.open(url))
    timer.start()
    try:
        subprocess.run([sys.executable,str(Path(__file__).with_name('server.py'))],check=True)
    except KeyboardInterrupt:
        pass
