"""Build the real Swift app in an isolated simulator host (no Unity runtime).
No production project settings, player containers or device installations are changed.
"""
import json, plistlib, subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[2]
source=root/'mistport-ios'
out=Path('/tmp/mistport-local-workshop-host')
project=out/'WorkshopIntegration.xcodeproj'
project.mkdir(parents=True,exist_ok=True)
pbx=json.loads(subprocess.check_output(['plutil','-convert','json','-o','-',str(source/'Mistport.xcodeproj/project.pbxproj')]))
objects=pbx['objects'];project_obj=objects[pbx['rootObject']]
def resolve(obj_id, parent):
 obj=objects[obj_id]; tree=obj.get('sourceTree','<group>');p=obj.get('path','')
 base=source if tree=='SOURCE_ROOT' else parent
 absolute=(base/p).resolve()
 if obj['isa']=='PBXGroup':
  for child in obj.get('children',[]):resolve(child,absolute)
 elif obj['isa']=='PBXFileReference' and tree in ('<group>','SOURCE_ROOT') and p:
  obj['path']=str(absolute);obj['sourceTree']='<absolute>'
resolve(project_obj['mainGroup'],source)
project_obj.pop('projectReferences',None)
for obj in objects.values():
 if obj['isa']=='PBXNativeTarget':
  obj['dependencies']=[]
  obj['buildPhases']=[p for p in obj['buildPhases'] if objects[p]['isa'] in ('PBXSourcesBuildPhase','PBXFrameworksBuildPhase','PBXResourcesBuildPhase')]
 elif obj['isa']=='PBXFrameworksBuildPhase':
  obj['files']=[f for f in obj['files'] if 'productRef' in objects[f]]
 elif obj['isa']=='PBXResourcesBuildPhase':
  obj['files']=[f for f in obj['files'] if objects.get(objects[f].get('fileRef'),{}).get('path','').endswith('Assets.xcassets')]
 elif obj['isa']=='XCLocalSwiftPackageReference':
  obj['relativePath']=str((source/obj['relativePath']).resolve())
 elif obj['isa']=='XCBuildConfiguration':
  settings=obj['buildSettings']
  settings['CODE_SIGNING_ALLOWED']='NO'
  settings['SUPPORTED_PLATFORMS']='iphonesimulator'
  settings['SDKROOT']='iphonesimulator'
  settings['PRODUCT_BUNDLE_IDENTIFIER']='local.mistport.workshop-integration'
  settings.pop('DEVELOPMENT_TEAM',None)
  settings['ASSETCATALOG_COMPILER_APPICON_NAME']='AppIcon'
(project/'project.pbxproj').write_bytes(plistlib.dumps(pbx))
subprocess.run(['xcodebuild','-project',str(project),'-scheme','Mistport','-configuration','Debug',
 '-sdk','iphonesimulator','-destination','generic/platform=iOS Simulator','-derivedDataPath',str(out/'Derived'),
 '-jobs','2','ARCHS=arm64','ONLY_ACTIVE_ARCH=YES','CODE_SIGNING_ALLOWED=NO','build'],check=True)
print(out/'Derived/Build/Products/Debug-iphonesimulator/Mistport.app')
