"""Capture isolated housing views on a simulator; never operates on a physical device.
The simulator app must already be built and installed. PNGs are copied unchanged.
"""
from pathlib import Path
import argparse,subprocess,time,shutil,json
r=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--simulator', required=True)
parser.add_argument('--destination', type=Path, default=r/'docs/development/housing-app-20260930/simulator')
parser.add_argument('--screens', nargs='+', default=['agency','districts','cards','interior','lease','moving','residence','stamina','highland','home','home-night'])
parser.add_argument('--skip-reports', action='store_true', help='Capture updated views without copying prior self-check reports')
opts=parser.parse_args()
out=opts.destination;out.mkdir(parents=True,exist_ok=True)
d=opts.simulator;bundle='local.mistport.housing-integration'
c=Path(subprocess.check_output(['xcrun','simctl','get_app_container',d,bundle,'data'],text=True).strip())
for screen in opts.screens:
 if screen not in ['agency','districts','cards','interior','lease','moving','residence','stamina','highland','home','home-night']:raise ValueError('Unknown housing screen: '+screen)
 stamp=time.time()
 args=['xcrun','simctl','launch','--terminate-running-process',d,bundle,'--housing-device-walk','--housing-screen='+('home' if screen=='home-night' else screen)]
 if screen.startswith('home'):args+=['--home-map-review','-MistportHubPanX','0.265','-MistportCityHour','22' if screen=='home-night' else '12','-MistportCitySeason','autumn']
 result=subprocess.run(args,text=True,capture_output=True,check=True)
 image=c/'Documents'/('housing-'+('home' if screen=='home-night' else screen)+'.png')
 for _ in range(35):
  if image.exists() and image.stat().st_mtime>=stamp:break
  time.sleep(.25)
 else:raise RuntimeError('No fresh screenshot for '+screen)
 shutil.copy2(image,out/('housing-'+screen+'.png'))
 print('Captured simulator',screen,flush=True)
if opts.skip_reports:raise SystemExit(0)
for name in ['housing-verification.json','local-workshop-verification.json','church-tower-100-verification.json']:
 shutil.copy2(c/'Documents'/name,out/name)
report={name:json.loads((out/name).read_text()) for name in ['housing-verification.json','local-workshop-verification.json','church-tower-100-verification.json']}
print({name:{k:v for k,v in value.items() if not isinstance(v,(list,dict))} for name,value in report.items()},flush=True)
