"""Read current Swift catalog; never import/execute downloaded model code."""
import ast, hashlib, json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CORE=ROOT/'mistport-ios/MistportCombatCore/Sources/MistportCombatCore'

def extract():
    tower=(CORE/'ChurchTower.swift').read_text()
    names={'shieldJaw':'D01','saltSac':'D02','backSac':'D03','scissor':'D04','crown':'D05','boneclaw':'D06','copperback':'D07','crimsonBrute':'D08','veilOracle':'D09','goldenThroat':'D10','moonfang':'D11'}
    floors=[]
    for n,body in re.findall(r'Floor\(number: (\d+), title:.*?enemies: \[(.*?)\]\)',tower):
        monsters=['D01']*len(re.findall(r'\bjaw\(',body))+['D02']*len(re.findall(r'\bsac\(',body))
        monsters += [names[x] for x in re.findall(r'small\(\.(\w+)',body)]
        floors.append({'floor':int(n),'monsters':monsters})
    raw=tower.split('let bands: [[[[S]]]] = [',1)[1].split('// Replace only',1)[0].strip()
    raw='['+raw
    aliases={'h':'D01','j':'D01','p':'D02','m':'D03','c':'D04','n':'D05','b':'D06'}
    raw=re.sub(r'\b[hjpmcnb]\b',lambda m:repr(aliases[m[0]]),raw)
    bands=ast.literal_eval(raw)
    replacement=tower.split('let minions:',1)[1].split('let titles',1)[0]
    edits={int(n):(int(w),int(s),names[k]) for n,w,s,k in re.findall(r'(\d+): \((\d+),(\d+),\.(\w+)\)',replacement)}
    for band,layouts in enumerate(bands):
        for offset,waves in enumerate(layouts):
            n=11+band*10+offset
            if n in edits:
                w,s,k=edits[n]; assert waves[w][s]=='D01'; waves[w][s]=k
            floors.append({'floor':n,'monsters':sum(waves,[])})
    assert len(floors)==100 and [x['floor'] for x in floors]==list(range(1,101))
    mission=(CORE/'ChapterOneThirtyMissionContract.swift').read_text().split('public static func firstClear',1)[1].split('let talent',1)[0]
    q={}
    for a,b,v in re.findall(r'case (\d+)\.\.\.(\d+): copper = (\d+)',mission):
        for i in range(int(a),int(b)+1): q[i]=int(v)
    q[30]=int(re.search(r'default: copper = (\d+)',mission)[1]);assert len(q)==30
    bounty=(CORE/'ChurchBounties.swift').read_text()
    b=[{'unlock':int(u),'copper':int(c)} for u,c in re.findall(r'\.init\(id:"b\d+".*?unlockMission:(\d+).*?\],copper:(\d+)',bounty,re.S)]
    assert len(b)==10
    sources=[CORE/x for x in ('ChurchTower.swift','ChapterOneThirtyMissionContract.swift','ChurchBounties.swift','ChurchLoans.swift')]+[ROOT/'mistport-ios/Mistport/GameStore.swift']
    return {'sources':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},'q_first':[q[i] for i in range(1,31)],'q_repeat':[max(8,int(q[i]*.35)) for i in range(1,31)],'tower':floors,'tower_first':[8+2*(i//10) for i in range(100)],'bounty':b,'note':'Rosters/reward tables extracted; play frequency, outcomes, crafting and demand remain assumptions.'}
if __name__=='__main__':
    p=Path(__file__).with_name('source_inputs.json');p.write_text(json.dumps(extract(),ensure_ascii=False,indent=2)+'\n');print(p)
