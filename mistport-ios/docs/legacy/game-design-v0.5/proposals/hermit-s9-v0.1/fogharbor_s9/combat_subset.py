#!/usr/bin/env python3
"""确定性机制对照：一个刻意有限的零天赋战斗子模型。
支持8张基础卡、R01/R02/R04/R05/R17/R18、护甲/周期盾/治疗/死亡余烬。
不支持完整18天赋/18遗落物、守卫控制印记及全部精英/首领AI。
高资源方额外获得25%攻击强度，高价值方R18按规则生效；R06/R15因未装备假面/身份错置而不触发。
此人为属性优势只用于压力对照，不代表商店售卖属性。双方生命2400。
运行：python combat_subset.py --outdir ./results
"""
from __future__ import annotations
import argparse, csv, heapq, json
from dataclasses import dataclass
from pathlib import Path
from validate_s9 import schedule

@dataclass
class Enemy:
    id: int
    kind: str
    hp: float
    max_hp: float
    armor: float
    shield: float=0
    shield_end: int=0
    breach_end: int=0
    mark_end: int=0
    isolation_end: int=0
    proof: int=0
    ledger_id: int=0
    stamp_used: bool=False
    attack_proof_at: int=-1000
    dead_at: int=10**9

SPECS={
 'guard':(1800,100,[(100,160,250,0)]),
 'gear':(1500,40,[(100,65,400,0),(125,65,400,0),(150,65,400,0)]),
 'hound':(1800,10,[(80,400,400,50)]),
 'nurse':(1500,20,[(100,90,250,0)]),
 'blue':(1050,0,[(120,110,200,40)]),
 'ash':(1100,0,[(110,130,240,30)]),
}

class Combat:
    def __init__(self,kinds,order,relics,ap=100.,hp=2400.,limit=18000):
        self.ap=ap; self.hp=hp; self.limit=limit; self.order=order; self.relics=set(relics)
        self.enemies=[Enemy(i,k,SPECS[k][0],SPECS[k][0],SPECS[k][1]) for i,k in enumerate(kinds)]
        self.queue=[]; self.serial=0; self.now=0; self.log=[]
        self.mask_uses=0; self.mask_budget=0.; self.mask_end=0
        self.shield=0.; self.shield_end=0; self.paper_used=False; self.box_next=0
        self.focus=0; self.outgoing=0.; self.absorbed=0.; self.healed=0.; self.denied_heal=0.
        self.pending_hazards=0; self.copy_next=0; self.last_qualified_seal={}
        for a in schedule(order,end=limit):
            self.push(a['start_tick'],5,'action',a)
        for e in self.enemies:
            for first,damage,period,travel in SPECS[e.kind][2]:
                for t in range(first,limit+1,period):
                    self.push(t,3,'enemy_hit',(e.id,damage,travel))
            if e.kind=='nurse':
                for t in range(400,limit+1,800):
                    self.push(t,2,'heal',e.id)
            if e.kind=='blue':
                for t in range(0,limit+1,600):
                    self.push(t,0,'blue_shield',e.id)
    def push(self,t,phase,kind,data):
        self.serial+=1; heapq.heappush(self.queue,(t,phase,self.serial,kind,data))
    def record(self,kind,detail,damage=0.):
        self.log.append({'time':round(self.now/100,2),'event':kind,'detail':detail,
                         'value':round(damage,2),'player_hp':round(self.hp,2),
                         'enemies_hp':';'.join(f'{e.kind}:{max(0,e.hp):.2f}' for e in self.enemies)})
    def alive(self): return [e for e in self.enemies if e.hp>0]
    def choose(self,skill):
        live=self.alive()
        if not live:return None
        cur=next((e for e in live if e.id==self.focus),live[0]); self.focus=cur.id
        if skill=='I':return next((e for e in live if e.kind=='nurse'),cur).id
        if skill=='A':return max(live,key=lambda e:(e.proof,e.id==cur.id,-e.id)).id
        return cur.id
    def evidence(self,e,n):
        if e.hp<=0:return
        if 'R05' in self.relics and not e.stamp_used:
            n+=1; e.stamp_used=True
        if e.proof==0:
            e.ledger_id+=1; self.push(self.now+600,1,'auto_seal',(e.id,e.ledger_id))
        cap=max(3,6-int('R05' in self.relics)-int('R18' in self.relics))
        e.proof=min(cap,e.proof+n)
    def seal(self,e,coef,delay):
        n=e.proof
        if n:
            e.proof=0; e.ledger_id+=1
            self.push(self.now+delay,3,'packet',(e.id,n*coef*self.ap/100))
            if 'R18' in self.relics and n>=4:
                previous=self.last_qualified_seal.get(e.id,-10**9)
                if self.now-previous<1200 and self.now>=self.copy_next:
                    self.push(self.now+delay+300,3,'packet',(e.id,n*coef*self.ap/100*.25))
                    self.copy_next=self.now+1200; self.last_qualified_seal.pop(e.id,None)
                    self.record('校样复印',f'{e.id}: 原案25%，不递归')
                else:self.last_qualified_seal[e.id]=self.now
            self.record('封卷',f'{e.id}: {n}层，{delay/100:.1f}秒后兑现')
        return n
    def damage_enemy(self,eid,raw):
        e=self.enemies[eid]
        if e.hp<=0:return
        armor=e.armor*(.5 if self.now<e.breach_end else 1.)
        damage=raw*100/(100+armor)
        if self.now>=e.shield_end:e.shield=0
        shield_loss=min(e.shield,damage); e.shield-=shield_loss; damage-=shield_loss
        e.hp-=damage; self.outgoing+=damage
        self.record('玩家命中',f'{eid}; 削盾{shield_loss:.2f}',damage)
        if e.hp<=0:
            e.dead_at=self.now; cancelled=0
            if e.kind=='ash':
                if 'R17' in self.relics and self.now<e.mark_end and self.now>=self.box_next:
                    cancelled=min(2,e.proof); e.proof-=cancelled
                    if cancelled:self.box_next=self.now+300
                for i in range(cancelled,3):
                    self.pending_hazards+=1
                    self.push(self.now+200+i*100,3,'hazard',100.)
            e.proof=0; e.ledger_id+=1
            self.record('敌人离场',f'{eid}; 取消余烬{cancelled}次')
    def damage_player(self,damage,eligible=True):
        if self.now>=self.shield_end:self.shield=0
        absorbed=0
        if eligible and self.now<self.mask_end and self.mask_uses>0 and self.mask_budget>0:
            absorbed=min(.7*damage,self.mask_budget)
            if absorbed>0:
                self.mask_uses-=1; self.mask_budget-=absorbed
                if self.mask_budget<=1e-9:self.mask_uses=0
        after=damage-absorbed; shield_loss=min(self.shield,after); self.shield-=shield_loss
        after-=shield_loss; self.absorbed+=absorbed
        if after>=self.hp and 'R01' in self.relics and not self.paper_used:
            self.paper_used=True; self.hp=1.; self.record('纸人代身','本场破碎')
        else:self.hp-=after
        self.record('敌方/环境命中',f'幻影{absorbed:.2f}; 护盾{shield_loss:.2f}',after)
    def run(self):
        while self.queue:
            t,phase,serial,kind,data=heapq.heappop(self.queue)
            if t>self.limit:break
            self.now=t
            if self.hp<=0:break
            if kind=='action':
                a=data; s=a['id']; target=self.choose(s)
                if target is None:continue
                if s in ('M','H'):self.push(a['impact_tick'],1,'support',s)
                else:self.push(a['impact_tick'],3,'player_hit',(s,target))
            elif kind=='support':
                if data=='M':
                    self.mask_budget=(240+(60 if 'R02' in self.relics else 0))*self.ap/100
                    self.mask_uses=2; self.mask_end=t+(300 if 'R02' in self.relics else 400)
                else:
                    self.shield=max(self.shield if t<self.shield_end else 0,140*self.ap/100)
                    self.shield_end=t+300
            elif kind=='player_hit':
                s,eid=data; e=self.enemies[eid]
                if e.hp<=0:continue
                if s=='B':self.damage_enemy(eid,60*self.ap/100)
                elif s=='N':
                    self.damage_enemy(eid,90*self.ap/100); self.evidence(e,1)
                elif s=='F':
                    targets=[e]+[x for x in self.alive() if x.id!=eid][:1]
                    for idx,x in enumerate(targets):
                        x.breach_end=t+(700 if 'R04' in self.relics else 500)
                        raw=120 if idx==0 else (0 if 'R04' in self.relics else 60)
                        if raw:self.damage_enemy(x.id,raw*self.ap/100)
                elif s=='E':
                    self.damage_enemy(eid,40*self.ap/100)
                    if e.hp>0:e.mark_end=t+800; self.evidence(e,2)
                elif s=='I':
                    targets=[e]+[x for x in self.alive() if x.id!=eid][:1]
                    self.damage_enemy(eid,60*self.ap/100)
                    for x in targets:
                        if x.hp>0:x.mark_end=t+800; x.isolation_end=t+400
                    self.evidence(e,1)
                elif s=='R':
                    extra=t<e.mark_end or t<e.breach_end
                    self.damage_enemy(eid,80*self.ap/100)
                    if extra:
                        next_target=eid if e.hp>0 else self.choose('R')
                        if next_target is not None:self.push(t+35,3,'packet',(next_target,50*self.ap/100))
                elif s=='A':
                    self.seal(e,50,120); self.damage_enemy(eid,80*self.ap/100)
            elif kind=='packet':self.damage_enemy(*data)
            elif kind=='auto_seal':
                eid,version=data; e=self.enemies[eid]
                if e.hp>0 and e.ledger_id==version:self.seal(e,30,60)
            elif kind=='blue_shield':
                e=self.enemies[data]
                if e.hp>0:e.shield=420; e.shield_end=t+300
            elif kind=='enemy_hit':
                eid,damage,travel=data; e=self.enemies[eid]
                if e.dead_at<=t-travel:continue
                if e.kind=='nurse':
                    next_heal=400 if t<=400 else 400+((t-400+799)//800)*800
                    if next_heal-120<=t<=next_heal:continue
                self.damage_player(damage)
                if e.hp>0 and t<e.mark_end and t>=e.attack_proof_at:
                    self.evidence(e,1); e.attack_proof_at=t+100
            elif kind=='heal':
                nurse=self.enemies[data]
                if nurse.hp<=0:continue
                others=[e for e in self.alive() if e.id!=nurse.id]
                if not others:continue
                target=min(others,key=lambda e:(e.hp/e.max_hp,e.id))
                if t<nurse.isolation_end or t<target.isolation_end:
                    self.denied_heal+=260; self.record('治疗被隔离阻止',str(target.id),260)
                else:
                    amount=min(260,target.max_hp-target.hp); target.hp+=amount; self.healed+=amount
                    self.record('治疗',str(target.id),amount)
            elif kind=='hazard':
                self.pending_hazards-=1; self.damage_player(data,eligible=False)
            if self.hp<=0:break
            if not self.alive() and self.pending_hazards==0:
                # 已发出的远程攻击仍需结算。未发射的定时攻击不得复活敌人。
                pending=False
                for qt,qp,qs,qk,qd in self.queue:
                    if qk=='enemy_hit':
                        eid,damage,travel=qd
                        if travel>0 and qt-travel<t and self.enemies[eid].dead_at>qt-travel:
                            pending=True;break
                if not pending:break
        outcome='胜利' if self.hp>0 and not self.alive() and self.pending_hazards==0 else ('失败' if self.hp<=0 else '超时')
        return {'outcome':outcome,'time_s':round(self.now/100,2),'hp_left':round(max(0,self.hp),2),
                'phantom_absorbed':round(self.absorbed,2),'healing_received_by_enemies':round(self.healed,2),
                'healing_denied':round(self.denied_heal,2),'paper_used':self.paper_used,
                'enemies_left':[{ 'kind':e.kind,'hp':round(max(0,e.hp),2)} for e in self.enemies if e.hp>0]}

TESTS=[
 {'id':'C1','label':'护甲与连击：守卫+齿轮偶','enemies':['guard','gear'],
  'correct':{'order':['M','F','N','R'],'relics':['R01','R02','R04'],'ap':100.},
  'wrong':{'order':['N','E','R','A'],'relics':['R18','R06','R15'],'ap':125.}},
 {'id':'C2','label':'治疗与重弹：猎犬+蜡封修女','enemies':['hound','nurse'],
  'correct':{'order':['M','I','E','A'],'relics':['R01','R02','R05'],'ap':100.},
  'wrong':{'order':['A','R','E','N'],'relics':['R18','R06','R15'],'ap':125.}},
 {'id':'C3','label':'死亡余烬：三个灰烬信差','enemies':['ash','ash','ash'],
  'correct':{'order':['M','E','F','H'],'relics':['R01','R02','R17'],'ap':100.},
  'wrong':{'order':['N','E','R','A'],'relics':['R18','R06','R15'],'ap':125.}},
]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outdir',type=Path,default=Path('results'))
    args=parser.parse_args();args.outdir.mkdir(parents=True,exist_ok=True)
    results=[]
    for test in TESTS:
        for side in ['correct','wrong']:
            params=test[side]; c=Combat(test['enemies'],**params); result=c.run()
            results.append({'test':test['id'],'label':test['label'],'side':side,**params,**result})
            with (args.outdir/f"combat_{test['id']}_{side}.csv").open('w',newline='',encoding='utf-8-sig') as f:
                writer=csv.DictWriter(f,fieldnames=['time','event','detail','value','player_hp','enemies_hp']);writer.writeheader();writer.writerows(c.log)
    (args.outdir/'combat_subset_results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(results,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
