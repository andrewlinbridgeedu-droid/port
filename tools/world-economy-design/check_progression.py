"""Independent arithmetic review of Pro's candidate; not runtime gameplay."""
import json
stages=[(0,20,2,8,0),(20,45,3,10,60),(45,70,4,12,120),(70,100,5,14,200)]
rows=[]
for start,target,units,cost,scroll in stages:
 p=start;count=0
 while p<target:
  gain=3 if p<start+10 else 2 if p<start+20 else 1 if p<start+30 else 0
  assert gain>0
  p=min(100,p+gain);count+=1
 rows.append(dict(start=start,end=p,crafts=count,towerMaterialUnits=count*units,copper=count*(cost+1)+scroll))
print(json.dumps({'status':'candidate arithmetic only; costs and materials are assumptions, not recipe catalog or drop measurements','stages':rows,'crafts':sum(r['crafts'] for r in rows),'units':sum(r['towerMaterialUnits'] for r in rows),'copper':sum(r['copper'] for r in rows)},indent=2))
