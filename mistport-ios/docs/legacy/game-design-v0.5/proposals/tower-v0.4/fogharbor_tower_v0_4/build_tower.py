#!/usr/bin/env python3
"""Build an offline design manifest, not a Unity battle implementation.
Python 3.10+, standard library. No network, no production save writes.
"""
from __future__ import annotations
import csv
import json
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path

HERE = Path(__file__).resolve().parent
VERSION = 'tower_s9_proposal_0.4'

def rounded(value: float) -> int:
    return int(Decimal(str(value)).quantize(Decimal('1'), rounding=ROUND_HALF_UP))

# Behavior is referenced, not implemented. Numbers are the previous design's originals.
RAW = [
 ('E01','铠甲守卫',1800,100,160,['armor','control_mark']),
 ('E02','青雾幽灵',1050,0,110,['periodic_shield']),
 ('E03','赤雾幽灵',1150,10,90,['shield_conditional_heal']),
 ('E04','地狱猎犬',1800,10,400,['opening_projectile']),
 ('E05','齿轮巡逻偶',1500,40,65,['three_hit_burst']),
 ('E06','钟槌执事',2600,60,620,['charge','stability']),
 ('E07','蜡封修女',1500,20,90,['ally_heal']),
 ('E08','门卫侍从',2000,80,120,['ally_protection']),
 ('E09','失名唤影者',1600,20,80,['summon']),
 ('E10','灰烬信差',1100,0,130,['death_residue']),
 ('E11','碎镜巡官',1900,40,170,['reveal_reflect']),
 ('E12','无脸登记官',2200,30,140,['same_category_audit']),
 ('B01','钟门司铎',5200,70,180,['armor','charge','phase_shield']),
 ('B02','双名馆长',6000,20,170,['shared_identity','alternating_shield','mutual_heal']),
 ('B03','失名总登记官',7200,35,150,['same_category_audit','phase_summon','phase_charge']),
]
ENEMIES = {e[0]: {'id':e[0], 'name':e[1], 'base_hp':e[2], 'armor':e[3],
 'reference_main_hit_damage':e[4], 'tags':e[5],
 'behavior_reference':f's9.design.{e[0]}', 'timing_verified':False} for e in RAW}

COMPS = {
 'L': [
 ['E01'],['E05'],['E04'],['E06'],['E01','E05'],['E01','E04'],
 ['E04','E07'],['E06','E05'],['E08','E07'],['E01','E10'],
 ['E08','E04'],['E06','E10'],['E01','E05','E07'],['E08','E07','E05']],
 'M': [
 ['E02'],['E03'],['E08'],['E07'],['E02','E03'],['E08','E07'],
 ['E08','E02'],['E11'],['E11','E03'],['E12','E11'],
 ['E08','E07','E09'],['E02','E05'],['E02','E03','E08'],['E02','E11','E07']],
 'A': [
 ['E10'],['E09'],['E12'],['E11'],['E09','E10'],['E10','E05'],
 ['E12','E09'],['E06','E10'],['E12','E11'],['E09','E10','E11'],
 ['E08','E09'],['E10','E10'],['E12','E09','E03'],['E10','E08','E07']]
}
# Nine non-boss slots per decade: 1,2,3,4,5,6,7,8,9. Slot 5 is the elite checkpoint.
FIRST_ROWS = {
 'L': [[1,2,1,3,5,1,2,4,6], [3,1,5,4,8,2,6,7,5]],
 'M': [[1,2,3,4,5,1,3,2,7], [5,8,6,7,9,1,12,6,5]],
 'A': [[1,2,3,4,5,1,2,6,7], [3,5,8,4,9,1,12,7,5]],
}
LATE_POOLS = {
 'L': [5,6,7,8,9,10,11,12,13,14],
 'M': [5,6,7,9,10,11,12,13,14,8],
 'A': [5,6,7,8,9,10,11,12,13,14],
}
THEMES = ['单机制识别','双敌节奏','关系拆解','资源持续','续航突破',
          '多目标取舍','死亡与收尾','窗口兑现','复合压力','序列9终试']
HP_BUDGET = [1100,1450,1800,2150,2500,2850,3200,3500,3800,4100]
DAMAGE_SCALE = [.40,.48,.56,.64,.72,.80,.86,.92,.96,1.00]
SLOT_SCALE = [1.00,1.02,1.04,1.06,1.10,.92,.98,1.04,1.08,1.40]

# Each override is additive/replacing only the named field. These are content authoring
# requirements and require matching animation/timeline verification before release.
AFFIXES = [
 {'id':'entry_stagger','name':'错峰入场','requires_any':[], 'scope':'all_actors',
  'field':'first_attack_start_offset_s','operation':'add_index_times','value':.6,
  'rule':'第i个逻辑敌人的首次攻击起手加i×0.6秒，i从0起；此后周期不变。'},
 {'id':'guard_rotation','name':'轮值护送','requires_any':['E08'], 'scope':'E08',
  'field':'protection_retarget_interval_s','operation':'set','value':8,
  'rule':'每8秒尝试更换保护对象，提前1秒显示；无第二个有效同伴则保留。'},
 {'id':'charge_compact','name':'短钟蓄势','requires_any':['E06'], 'scope':'E06',
  'field':'heavy_windup_s','operation':'set','value':1.6,
  'rule':'重击前摇1.8改1.6秒，削稳阈值仍220；需要对应动画事件重新验收。'},
 {'id':'mirror_long','name':'镜面延展','requires_any':['E11'], 'scope':'E11',
  'field':'reflect_window_s','operation':'set','value':2.5,
  'rule':'镜面窗2改2.5秒，周期7秒、每窗最多两次、ICD0.6秒不变。'},
 {'id':'summon_early','name':'提前传唤','requires_any':['E09'], 'scope':'E09',
  'field':'first_summon_ready_s','operation':'set','value':3,
  'rule':'首次召唤完成参考时刻4改3秒，前摇仍1秒、之后8秒、场上最多2只。'},
 {'id':'audit_extended','name':'延长审验','requires_any':['E12'], 'scope':'E12',
  'field':'audit_window_s','operation':'set','value':4.5,
  'rule':'审验窗4改4.5秒；起始、周期、惩罚伤害及2秒ICD不变。'},
 {'id':'heal_advance','name':'提前支援','requires_any':['E07'], 'scope':'E07',
  'field':'first_heal_ready_s','operation':'set','value':3.5,
  'rule':'第一次治疗完成参考时刻4改3.5秒，1.2秒前摇及8秒周期不变。'},
 {'id':'shield_long','name':'厚雾时段','requires_any':['E02'], 'scope':'E02',
  'field':'shield_duration_s','operation':'set','value':3.5,
  'rule':'周期盾持续3改3.5秒，周期6秒；仍有2.5秒无盾窗，不累计护盾。'},
 {'id':'ash_quick','name':'余烬迫近','requires_any':['E10'], 'scope':'E10',
  'field':'death_first_tick_delay_s','operation':'set','value':1.5,
  'rule':'死亡后首跳2改1.5秒，仍三跳、跳间1秒；UI必须预告。'},
]

def split_budget(total: int, actors: list[str]) -> list[int]:
    weights = [ENEMIES[e]['base_hp'] for e in actors]
    den = sum(weights)
    allocated = [(total*w)//den for w in weights]
    order = sorted(range(len(weights)), key=lambda i: (-(total*weights[i] % den), i))
    for i in order[:total-sum(allocated)]:
        allocated[i] += 1
    return allocated


def boss_profile(church: str, band: int) -> dict:
    if church == 'L':
        return {'id':f'B01_band_{band}', 'archetype':'B01',
          'phase2_at_hp_ratio':.60 if band>=3 else None,
          'heavy_reference_damage':600, 'heavy_windup_s':1.8,
          'stability_threshold':260 if band>=8 else 240,
          'stabilized_reference_damage':260,
          'heavy_aftershock':{'enabled':band>=6,'delay_s':.8,'reference_damage':70,
                             'event_type':'enemy_native_followup'},
          'note':'第1、2章不启用60%阶段盾和双击；其后按原首领阶段。'}
    if church == 'M':
        return {'id':f'B02_band_{band}', 'archetype':'B02',
          'mutual_heal_at_hp_ratio':.50 if band>=3 else None,
          'phase2_shield_switch_interval_s':2.5 if band>=6 else 3,
          'logical_identity_count':1,'visual_body_count':2,
          'note':'两身体共享生命、证据、延后预算、奖励实体；每次施法取证去重。'}
    return {'id':f'B03_band_{band}','archetype':'B03',
       'summon_phase_at_hp_ratio':.65 if band>=3 else None,
       'charge_phase_at_hp_ratio':.30 if band>=6 else None,
       'replenish_s':10 if band>=8 else 12,'summon_cap':2,
       'note':'未开放阶段完全不注册对应触发器；阶段变化不清台账。'}


def floor_reward(number: int) -> dict:
    band=(number-1)//10+1
    is_boss=number%10==0
    return {'xp':8+2*band if band<=3 else 0,
            'crowns':4+band+(20 if is_boss else 0),
            'essence':1+(band-1)//4+(3 if is_boss else 0),
            'research':1 if is_boss else 0,
            'talent_points':0,'random_relic_rolls':0,
            'cosmetic':f'chapter_{number}' if number in (30,60,100) else None}


def choose_affixes(actors: list[str], band: int, slot: int) -> list[str]:
    limit=0 if slot in (6,10) else min(2,(band-1)//3)
    eligible=[a for a in AFFIXES if not a['requires_any'] or any(e in actors for e in a['requires_any'])]
    # A single actor cannot be staggered against a second actor that does not exist.
    eligible=[a for a in eligible if a['id']!='entry_stagger' or len(actors)>1]
    eligible=[a for a in eligible if a['id']!='guard_rotation' or len(actors)>2]
    if not eligible or not limit:
        return []
    offset=(band+slot)%len(eligible)
    return [eligible[(offset+i)%len(eligible)]['id'] for i in range(min(limit,len(eligible)))]


def build() -> dict:
    towers=[]
    floors=[]
    for church,name,boss in [('L','守灯长阶','B01'),('M','观镜长阶','B02'),('A','缄卷长阶','B03')]:
        towers.append({'id':church,'name':name,'floor_count':100,'open_after':'Q02',
            'story_completion_credit':False,'research_track':church})
        for number in range(1,101):
            band=(number-1)//10+1
            slot=(number-1)%10+1
            kind='boss' if slot==10 else 'elite' if slot==5 else 'regular'
            if slot==10:
                actors=[boss]
                template=boss_profile(church,band)['id']
            else:
                if band<=2:
                    idx=FIRST_ROWS[church][band-1][slot-1]
                else:
                    pool=LATE_POOLS[church]
                    idx=pool[((band-3)*2+slot-1)%len(pool)]
                    if slot==6:  # Deliberate relief after the elite check.
                        idx=[1,2,3][(band+ord(church))%3]
                # Three discussed gate examples are pinned, not left to a generator change.
                if church=='L' and number==47: idx=9
                if church=='M' and number==58: idx=5
                if church=='A' and number==73: idx=10
                actors=COMPS[church][idx-1]
                template=f'{church}_encounter_{idx:02}'
            hp=rounded(HP_BUDGET[band-1]*SLOT_SCALE[slot-1])
            shares=split_budget(hp,actors)
            stats=[]
            for i,(enemy,share) in enumerate(zip(actors,shares)):
                b=ENEMIES[enemy]
                stats.append({'actor_id':f'{church}.{number:03}.actor.{i}',
                  'archetype':enemy,'hp':share,'armor':b['armor'],
                  'damage_scale':DAMAGE_SCALE[band-1],
                  'reference_main_hit':rounded(b['reference_main_hit_damage']*DAMAGE_SCALE[band-1]),
                  'shield_scale':round(share/b['base_hp'],6),
                  'healing_scale':DAMAGE_SCALE[band-1],
                  'native_spawn_damage_scale':DAMAGE_SCALE[band-1],
                  'native_spawn_hp_scale':round(share/b['base_hp'],6),
                  'reward_entity':True})
            story='Q02' if number<=10 else 'Q04' if number<=20 else 'Q06' if number<=30 else 'Q08'
            affixes=choose_affixes(actors,band,slot)
            if church=='L' and number==47: affixes=['heal_advance']
            if church=='M' and number==58: affixes=['shield_long']
            if church=='A' and number==73: affixes=['summon_early','mirror_long']
            f={'id':f'tower.s9.{church}.{number:03}', 'church':church,'number':number,
               'band':band,'theme':THEMES[band-1],'kind':kind,'template':template,
               'name':'＋'.join(ENEMIES[e]['name'] for e in actors),
               'predecessor':f'tower.s9.{church}.{number-1:03}' if number>1 else None,
               'story_gate':story,'calibration_gate':None,'recommended_level':3 if band==1 else 5 if band==2 else 7 if band==3 else 10,
               'recommended_talent_budget':8 if band==1 else 14 if band==2 else 22 if band==3 else 30,
               'recommended_calibration_rank':[0,0,0,0,1,2,3,4,5,5][band-1],
               'hp_budget':hp,'hp_budget_scope':'preplaced_logical_actors_only',
               'armor_scaling':False,'global_attack_speed_scaling':False,
               'actors':stats,'affixes':affixes,
               'boss_profile':boss_profile(church,band) if slot==10 else None,
               'first_clear_reward':floor_reward(number),
               'repeat_reward':{'xp':0,'crowns':0,'essence':0,'research':0,'random_relic_rolls':0},
               'target_clear_time_s':{'regular':[25,50],'elite':[40,80],'boss':[60,120]}[kind],
               'status':'DRAFT_NOT_BATTLE_VALIDATED','release_enabled':False,
               'requires_timing_verification':True,'requires_mask_decision':True,
               'requirements':'Only implemented, versioned skills/talents/relics allowed for release.'}
            if f['first_clear_reward']['cosmetic']:
                f['first_clear_reward']['cosmetic']=f'tower.s9.{church}.chapter.{number}'
            floors.append(f)
    return {'schema_version':1,'content_version':VERSION,'status':'DESIGN_AND_STATIC_CHECKS_ONLY',
      'base_document':'CHURCH_SYSTEM_SPEC.md v0.3','original_investigation_nodes_unchanged':True,
      'tower_does_not_complete_Q09_Q10':True,'tower_does_not_grant_advancement_proof':True,
      'manual_start_required':True,'instant_sweep_enabled':False,'continuous_start_enabled':False,
      'energy_fee':0,'failure_penalty':0,'daily_reset':False,'progress_never_resets':True,
      'cross_floor_hp_carry':False,'cross_floor_resources_carry':False,
      'force_timeout_s':None,'soft_enrage_enabled':False,'max_active_logical_enemies':5,
      'currency_types':['crowns','essence'],'research_threshold':6,'random_relic_rolls':0,
      'sequence9_base_cap':{'level':10,'hp':2400,'attack':100,'talent_points':30},
      'calibration':{'status':'NEW_OPTIONAL_CANDIDATE_NOT_BATTLE_VALIDATED','unlock_after':'Q08',
        'minimum_level':10,'max_rank':5,'mode':'absolute_rank_addition_not_compounding',
        'hp_per_rank':48,'attack_per_rank':2,
        'rank_costs':[{'rank':i+1,'crowns':c,'essence':e} for i,(c,e) in enumerate(zip([200,320,480,700,1000],[24,40,60,88,128]))],
        'reversible_outside_battle':True,'refund_rate':1,
        'paid_materials_enabled':False,'carry_to_next_sequence_as_extra_multiplier':False},
      'projection':{'scope':'sequence9_tower_only','future_sequence_stats':False,
         'future_sequence_talents':False,'future_sequence_relics':False,
         'uses_earned_s9_level_and_calibration':True,'free_rental_items':False},
      'damage_scaling_rule':'All native enemy damage including followups/reflect/ash scales once by actor.damage_scale; never multiply in both emitter and receiver.',
      'shield_scaling_rule':'Base shield amounts multiply by resolved actor hp / base hp; durations and periods unchanged except explicit affix.',
      'healing_scaling_rule':'Base heal amounts multiply by actor.healing_scale, not by recipient count.',
      'spawn_rule':'Spawned actors inherit owner damage/hp scales, max 2 per summoner, no reward entity; initial hp budget excludes future adds.',
      'timing_rule':'All offsets/overrides are content targets; actual authoritative hit confirmation required, no global 0.2-second damage.',
      'boss_overrides_rule':'Boss profile replaces named phase settings; other behavior comes from original archetype. Scaling applies exactly once.',
      'enemy_archetypes':ENEMIES,'affix_definitions':AFFIXES,'towers':towers,'floors':floors}


def write_outputs(config: dict) -> None:
    (HERE/'tower_config.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    with (HERE/'floors_300.csv').open('w',newline='',encoding='utf-8-sig') as out:
        fields=['id','church','number','kind','name','story_gate','recommended_level',
          'recommended_talent_budget','recommended_calibration_rank','hp_budget','damage_scale',
          'affixes','first_xp','first_crowns','first_essence','first_research','release_enabled']
        writer=csv.DictWriter(out,fieldnames=fields)
        writer.writeheader()
        for f in config['floors']:
            row={k:f[k] for k in fields if k in f}
            row['affixes']='|'.join(f['affixes'])
            row['damage_scale']=f['actors'][0]['damage_scale']
            for key in ['xp','crowns','essence','research']:
                row['first_'+key]=f['first_clear_reward'][key]
            writer.writerow(row)

if __name__=='__main__':
    write_outputs(build())
    print('Wrote 300 draft floors. No battle simulation or Unity edits performed.')
