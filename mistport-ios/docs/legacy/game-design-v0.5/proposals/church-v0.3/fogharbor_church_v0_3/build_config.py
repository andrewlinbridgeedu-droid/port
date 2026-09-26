"""Build the fictional sequence-9 church design fixture, not production game data."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
churches=[
 {"id":"L","name":"守灯教会","name_status":"暂定","theme":"护甲、直击、蓄力","pool":["R06","R11"]},
 {"id":"M","name":"观镜教会","name_status":"暂定","theme":"护盾、治疗、保护关系","pool":["R10","R14","R15"]},
 {"id":"A","name":"缄卷教会","name_status":"暂定","theme":"召唤、死亡遗留、审验","pool":["R16","R18"]},
]
# Rewards here are quest-completion awards. Accepted skills are granted once at acceptance.
qnames=["入职演证","假面与纸人","失名邮件","自护演证","代签调查","镜匠回声","灰烬留证","闭卷演证","联合调查","晋阶推荐"]
xps=[80,100,150,180,220,260,300,350,400,450]
coins=[60,80,90,110,140,160,180,220,240,300]
ess=[4,6,8,10,12,14,16,18,20,24]
points=[4,4,0,6,0,8,0,8,0,0]
skills={1:["N"],2:["M"],3:["E"],4:["H"],5:["I"],6:["R"],8:["A"]}
qrelics={2:["R01","R02"],3:["R05"],4:["R08"],5:["R09"],6:["R03"],7:["R17"]}
quests=[]
for i,name in enumerate(qnames,1):
 quests.append({"id":f"Q{i:02d}","name":name,"requires_quest":None if i==1 else f"Q{i-1:02d}",
   "accepted_skill_grants":skills.get(i,[]),"completion_skill_grants":["F"] if i==1 else [],
   "objective":"any_floor_5_cleared" if i==9 else "any_boss_cleared" if i==10 else "authored_story_trial",
   "completion_reward":{"xp":xps[i-1],"crowns":coins[i-1],"essence":ess[i-1],"talent_points":points[i-1],"restored_relics":qrelics.get(i,[])}})
levels=[]
cumulative=0
for i in range(1,11):
 levels.append({"level":i,"cumulative_xp":cumulative,"base_hp":1800+(600*(i-1))//9,"base_attack":80+(20*(i-1))//9})
 if i<10: cumulative += 100+40*(i-1)
base=[(50,32,4),(65,42,5),(90,54,7),(110,68,9),(135,84,11),(180,112,15)]
times=[(25,40),(30,45),(35,55),(40,65),(45,75),(60,90)]
layouts={
 "L":[("封印门廊",["E01"],None,["R04"]),("猎犬值守",["E04"],None,["R12"]),("门禁检验",["E01","E05"],"G1",["R07"]),("蜡封火线",["E04","E07"],"G3",[]),("重钟与齿轮",["E06","E05"],None,["R11"]),("钟门司铎",["B01"],None,[])],
 "M":[("青雾灯室",["E02"],None,[]),("赤雾侧廊",["E03"],None,[]),("双色误认",["E02","E03"],"G2",["R13"]),("代签队列",["E08","E07","E09"],"G4",[]),("审验镜廊",["E12","E11"],"G6",["R15"]),("双名馆长",["B02"],None,[])],
 "A":[("未熄信件",["E10"],None,[]),("唤影记录",["E09"],None,[]),("无脸审验",["E12"],None,[]),("重钟余烬",["E06","E10"],"G5",[]),("遗稿围场",["E09","E10","E11"],None,["R16"]),("失名总登记官",["B03"],None,[])],
}
nodes=[]
for c in churches:
 for n,(name,enemies,group,relics) in enumerate(layouts[c['id']],1):
  xp,cr,es=base[n-1]
  nodes.append({"id":f"{c['id']}{n:02d}","church":c['id'],"floor":n,"name":name,"enemies":enemies,"existing_group":group,
   "requires_quest":("Q01" if c["id"]=="L" and n==1 else {1:"Q02",2:"Q04",3:"Q06",4:"Q06",5:"Q08",6:"Q08"}[n]),"requires_node":None if n==1 else f"{c['id']}{n-1:02d}",
   "suggested_duration_seconds":list(times[n-1]),"base_reward":{"xp":xp,"crowns":cr,"essence":es},
   "first_clear_bonus":{"crowns":40,"essence":5,"restored_relics":relics},
   "research_increment":1 if n>=3 else 0,"random_relic_chance":0.10 if n>=3 else 0.0,
   "random_and_choice_unlock_quest":"Q08","boss_proof":n==6})
relic_names=["纸人代身","补缝针","两色票根","缺角铠钉","旧邮戳","无客面具","候钟怀表","冷瓷咖啡杯","返潮信封","单面镜片","警员哨扣","犬齿封蜡","双生纽扣","断线提偶","无名索引","空白终页","灰烬存证盒","禁售校样"]
rare={6,10,11,14,15,16}
relics=[]
for i,name in enumerate(relic_names,1):
 rarity="珍奇" if i==18 else "稀有" if i in rare else "普通"
 cost={"普通":(100,10),"稀有":(200,20),"珍奇":(300,30)}[rarity]
 rid=f"R{i:02d}"
 relics.append({"id":rid,"name":name,"rarity":rarity,"repair_or_research_claim_cost":{"crowns":cost[0],"essence":cost[1]},
  "random_duplicate_dismantle":{"crowns":0,"essence":{"普通":2,"稀有":4,"珍奇":6}[rarity]},
  "mask_rule_dependency":"experimental_partial_endurance" if i in {2,6,12,14} else None})
config={"version":"church_s9_proposal_0.3","status":"design_and_static_checks_only","sequence":9,"level_cap":10,"talent_cap":30,
 "research":{"threshold":6,"random_resets_progress":False,"counts_before_catalog_unlock":True,"is_trade_currency":False},
 "first_clear_bonus_is_additive":True,"failure_reward":0,"spawned_enemy_reward":0,"random_relic_max_per_clear":1,
 "manual_start_required":True,"instant_sweep_enabled":False,"consecutive_runs_enabled":False,"public_market_enabled":False,
 "currency_types":["crowns","essence"],"levels":levels,"churches":churches,"quests":quests,"nodes":nodes,"relics":relics,
 "ritual":{"requires_level":10,"requires_talent_points_earned":30,"requires_quest":"Q10","requires_boss_count":1,"cost":{"crowns":160,"essence":24}},
 "mvp":{"churches":["L"],"quests":["Q01"],"nodes":["L01"],"real_currency_purchases":False,"random_drop":False,"bosses":False}}
(ROOT/'church_config.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Wrote',ROOT/'church_config.json')
