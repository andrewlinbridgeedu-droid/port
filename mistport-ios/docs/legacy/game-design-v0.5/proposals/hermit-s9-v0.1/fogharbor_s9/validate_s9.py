#!/usr/bin/env python3
"""《秘仪：雾港升序》序列9：配点、自动调度和假面承伤的参考检查器。

运行：python validate_s9.py --outdir ./results
仅验证：配点可达性；首次轮播/冷却队列；基本假面模型。
不模拟：十八天赋的全部触发、十八遗落物、完整敌人AI、完整战斗胜率。
Python 3.10+，仅使用标准库。所有时间使用0.01秒整数刻度。
"""
from __future__ import annotations
import argparse, csv, json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

TICK = 100

@dataclass(frozen=True)
class Skill:
    id: str
    name: str
    cd: int
    category: str
    impact_delay: int = 20
    lock: int = 50

SKILLS = {
    'N': Skill('N', '留痕针', 400, '设局'),
    'F': Skill('F', '错步穿行', 600, '揭幕'),
    'M': Skill('M', '假面谕令', 300, '设局'),
    'E': Skill('E', '伪造证据', 700, '设局'),
    'I': Skill('I', '身份错置', 800, '设局'),
    'R': Skill('R', '镜像追击', 500, '揭幕'),
    'A': Skill('A', '荒诞终幕', 1000, '揭幕'),
    'H': Skill('H', '敛息', 900, '设局'),
}
ZERO = [0]*6
BUILDS = [
 {'id':'B1','name':'诡术30·交替拆甲','T':[5]*6,'P':ZERO,'S':ZERO,'order':['N','F','M','R'],'relics':['R03','R04','R11'], 'mask_cd':300},
 {'id':'B2','name':'幻身30·长幕回礼','T':ZERO,'P':[5]*6,'S':ZERO,'order':['M','N','R','H'],'relics':['R02','R06','R14'], 'mask_cd':500},
 {'id':'B3','name':'秘兆30·多案结卷','T':ZERO,'P':ZERO,'S':[5]*6,'order':['E','N','A','I'],'relics':['R08','R09','R18'], 'mask_cd':300},
 {'id':'B4','name':'诡术20+幻身10·借击连场','T':[5,1,5,1,4,4],'P':[5,4,0,1,0,0],'S':ZERO,'order':['M','F','N','R'],'relics':['R03','R02','R14'], 'mask_cd':300},
 {'id':'B5','name':'幻身20+秘兆10·受击作证','T':ZERO,'P':[5,1,5,1,4,4],'S':[5,4,1,0,0,0],'order':['E','M','R','A'],'relics':['R02','R08','R18'], 'mask_cd':300},
 {'id':'B6','name':'秘兆20+诡术10·错位快递','T':[5,4,1,0,0,0],'P':ZERO,'S':[5,1,5,1,4,4],'order':['E','F','N','A'],'relics':['R03','R04','R09'], 'mask_cd':300},
 {'id':'B7','name':'诡术15+幻身15·双资源回击','T':[5,1,4,0,5,0],'P':[5,1,4,0,5,0],'S':ZERO,'order':['M','F','R','H'],'relics':['R02','R03','R10'], 'mask_cd':300},
 {'id':'B8','name':'诡术15+秘兆15·破盾移案','T':[5,1,0,4,0,5],'P':ZERO,'S':[5,1,4,0,5,0],'order':['N','F','E','A'],'relics':['R04','R13','R17'], 'mask_cd':300},
 {'id':'B9','name':'幻身15+秘兆15·隔离公证','T':ZERO,'P':[5,1,0,4,0,5],'S':[5,1,0,4,0,5],'order':['M','E','I','A'],'relics':['R02','R15','R18'], 'mask_cd':300},
]

# (前置节点编号，从0开始；前置等级；首次投入前本系点数)
PREREQUISITES = [(None,0,0),(None,0,0),(0,1,5),(1,1,5),(2,1,10),(3,1,10)]

def allocation_path(target: list[int]) -> list[int]:
    """返回从零配点可达的投入顺序；不能靠下游点数反过来解锁上游。"""
    if len(target)!=6 or any(type(x) is not int or not 0<=x<=5 for x in target):
        raise ValueError(f'非法天赋向量: {target}')
    levels=[0]*6; path=[]
    while levels!=target:
        progress=False
        for node, want in enumerate(target):
            parent, rank, threshold=PREREQUISITES[node]
            if levels[node]>=want:
                continue
            if parent is not None and levels[parent]<rank:
                continue
            if sum(levels)-levels[node]<threshold:
                continue
            levels[node]+=1; path.append(node+1); progress=True
        if not progress:
            raise ValueError(f'配点不可达: {target}; 可达部分={levels}')
    return path

def schedule(order: list[str], end: int=2000, mask_cd: int=300) -> list[dict]:
    """动作不可被新就绪技能抢占；ready_at较早者优先，不是装备位永远优先。"""
    if len(order)!=4 or len(set(order))!=4 or any(s not in SKILLS for s in order):
        raise ValueError('必须装备4个不同技能')
    ready={s:0 for s in order}; now=0; opening=0; normal_ready=0; result=[]
    while now<=end:
        active=None
        if opening<len(order):
            active=order[opening]; opening+=1
        else:
            candidates=[s for s in order if ready[s]<=now]
            if candidates:
                active=min(candidates, key=lambda s:(ready[s], order.index(s)))
        if active:
            spec=SKILLS[active]
            cd=mask_cd if active=='M' else spec.cd
            result.append({'start_tick':now,'impact_tick':now+spec.impact_delay,
                'id':active,'name':spec.name,'ready_before_tick':ready[active],
                'next_ready_tick':now+cd,'opening':len(result)<4})
            ready[active]=now+cd; now+=spec.lock
        elif now>=normal_ready:
            result.append({'start_tick':now,'impact_tick':now+30,'id':'B',
                'name':'普攻','ready_before_tick':normal_ready,
                'next_ready_tick':now+100,'opening':False})
            normal_ready=now+100; now+=50
        else:
            future=[t for t in ready.values() if t>now]+[normal_ready]
            now=min(future)
    return result


def mask_probe(hits: Iterable[tuple[int,float]], mask_impacts: list[int],
               endurance: float=240., duration: int=400,
               full_absorption: bool=False) -> list[dict]:
    """不含玩家护甲、护盾、减伤和天赋。刷新在同刻伤害之前结算。"""
    events=[(t,0,0.) for t in mask_impacts]
    events += [(t,1,d) for t,d in hits]
    events.sort()
    charges=0; budget=0.; expiry=-1; rows=[]
    for tick, kind, damage in events:
        if kind==0:
            charges=2; budget=endurance; expiry=tick+duration
        else:
            before_charges=charges; before_budget=budget; absorbed=0.
            if tick<expiry and charges>0 and budget>0:
                absorbed=damage if full_absorption else min(.7*damage,budget)
                if absorbed>0:
                    charges-=1
                    if not full_absorption:
                        budget=max(0.,budget-absorbed)
                    if budget<=0:
                        charges=0
            rows.append({'time':tick/TICK,'incoming':damage,
                'charges_before':before_charges,'budget_before':round(before_budget,2),
                'absorbed':round(absorbed,2),'hp_loss':round(damage-absorbed,2),
                'charges_after':charges,'budget_after':round(budget,2)})
    return rows


def run_checks() -> list[dict]:
    checks=[]
    for build in BUILDS:
        paths={tree:allocation_path(build[tree]) for tree in ['T','P','S']}
        assert sum(sum(build[t]) for t in ['T','P','S'])==30
        checks.append({'test':build['id']+' 配点可达且恰为30点','pass':True,'paths':paths})
    try:
        allocation_path([1,1,5,0,3,0])
    except ValueError:
        checks.append({'test':'拒绝依靠下游点数反解锁上游的循环门槛','pass':True})
    else:
        raise AssertionError('循环解锁应被拒绝')
    sch=schedule(['M','F','N','R'])
    assert [a['id'] for a in sch[:4]]==['M','F','N','R']
    assert [a['start_tick'] for a in sch[:4]]==[0,50,100,150]
    checks.append({'test':'首次严格按装备顺序且动作锁0.5秒','pass':True})
    prior={s:0 for s in ['M','F','N','R']}
    for a in sch:
        if a['id']!='B':
            assert a['start_tick']>=prior[a['id']]
            prior[a['id']]=a['next_ready_tick']
    checks.append({'test':'技能不在自身CD结束前重放','pass':True})
    p=mask_probe([(80,160),(180,160),(280,160)],[20])
    assert [r['hp_loss'] for r in p]==[48.,48.,160.]
    checks.append({'test':'两次真实命中才耗两次，第三击正常受伤','pass':True})
    p=mask_probe([(80,400)],[20])
    assert p[0]['absorbed']==240 and p[0]['hp_loss']==160
    checks.append({'test':'400火球受耐久限制，只分担240','pass':True})
    p=mask_probe([(20,100)],[20])
    assert p[0]['hp_loss']==30
    checks.append({'test':'同时间假面完成先于命中','pass':True})
    p=mask_probe([(420,100)],[20])
    assert p[0]['hp_loss']==100
    checks.append({'test':'持续区间为左闭右开，到期同刻不能承接','pass':True})
    p=mask_probe([(80,100),(320,100),(330,100),(340,100)],[20,320])
    assert [r['hp_loss'] for r in p]==[30.,30.,30.,100.]
    checks.append({'test':'刷新为两次，不把旧剩余次数加进去','pass':True})
    return checks


def main() -> None:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outdir',type=Path,default=Path('results'))
    args=parser.parse_args(); args.outdir.mkdir(parents=True,exist_ok=True)
    checks=run_checks()
    summary=[]
    with (args.outdir/'timeline_20s.csv').open('w',newline='',encoding='utf-8-sig') as f:
        cols=['build','name','skill','skill_name','start_s','impact_s','next_ready_s','opening']
        writer=csv.DictWriter(f,fieldnames=cols); writer.writeheader()
        for build in BUILDS:
            acts=schedule(build['order'],mask_cd=build['mask_cd'])
            table={s:[a['impact_tick']/TICK for a in acts if a['id']==s and a['impact_tick']<=2000] for s in build['order']}
            summary.append({'id':build['id'],'name':build['name'],'impact_times_20s':table})
            for a in acts:
                if a['impact_tick']<=2000:
                    writer.writerow({'build':build['id'],'name':build['name'],
                        'skill':a['id'],'skill_name':a['name'],'start_s':a['start_tick']/TICK,
                        'impact_s':a['impact_tick']/TICK,'next_ready_s':a['next_ready_tick']/TICK,
                        'opening':a['opening']})
    mask_impacts=list(range(20,2000,300))
    probes={
        '慢攻160每2秒':[(t,160.) for t in range(80,2000,200)],
        '连射65每0.6秒':[(t,65.) for t in range(80,2000,60)],
        '犬火400每4秒':[(t,400.) for t in range(80,2000,400)],
        '重击700每5秒':[(t,700.) for t in range(80,2000,500)],
    }
    probe_summary=[]
    with (args.outdir/'mask_probe_events.csv').open('w',newline='',encoding='utf-8-sig') as f:
        writer=csv.DictWriter(f,fieldnames=['probe','rule','time','incoming','charges_before','budget_before','absorbed','hp_loss','charges_after','budget_after'])
        writer.writeheader()
        for name,hits in probes.items():
            for rule,old in [('旧规则完整吸收',True),('提议70%且耐久240',False)]:
                rows=mask_probe(hits,mask_impacts,full_absorption=old)
                total=sum(r['incoming'] for r in rows); loss=sum(r['hp_loss'] for r in rows)
                probe_summary.append({'probe':name,'rule':rule,'hits':len(rows),'incoming':total,
                    'hp_loss':round(loss,2),'absorbed':round(total-loss,2)})
                for row in rows:
                    writer.writerow({'probe':name,'rule':rule,**row})
    output={'scope':'配点、调度、独立假面探针；非完整战斗或平衡模拟',
        'checks':checks,'builds':BUILDS,'timelines':summary,'mask_probe_summary':probe_summary}
    (args.outdir/'results.json').write_text(json.dumps(output,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps({'checks_passed':len(checks),'timelines':summary,'mask_probe_summary':probe_summary},ensure_ascii=False,indent=2))

if __name__=='__main__':
    main()
