#!/usr/bin/env python3
"""Static manifest + reference accounting tests, never a battle simulation."""
from __future__ import annotations
import io, json, math, unittest
from collections import Counter
from copy import deepcopy
from pathlib import Path
from build_tower import build, write_outputs
from reference_rules import State, apply_design_clear, set_calibration, project_s9
HERE=Path(__file__).resolve().parent
C=build(); F=C['floors']; BY={f['id']:f for f in F}

def all_story() -> set[str]:
    return {f'Q{i:02}' for i in range(1,11)}

def run_tower(church='L',n=100,state=None):
    state=state or State(completed_quests=all_story())
    for i in range(1,n+1):
        state,_=apply_design_clear(state,BY[f'tower.s9.{church}.{i:03}'],f'{church}-{i}','win')
    return state

class StaticTests(unittest.TestCase):
    def test_01_count_unique(self):
        self.assertEqual(len(F),300); self.assertEqual(len(BY),300)
    def test_02_each_tower_contiguous(self):
        for t in 'LMA': self.assertEqual([f['number'] for f in F if f['church']==t],list(range(1,101)))
    def test_03_floor_types(self):
        for t in 'LMA': self.assertEqual(Counter(f['kind'] for f in F if f['church']==t),{'regular':80,'elite':10,'boss':10})
    def test_04_predecessor_chain(self):
        for f in F:
            expected=None if f['number']==1 else f"tower.s9.{f['church']}.{f['number']-1:03}"
            self.assertEqual(f['predecessor'],expected)
    def test_05_story_gates(self):
        for f in F:
            n=f['number']; expect='Q02' if n<=10 else 'Q04' if n<=20 else 'Q06' if n<=30 else 'Q08'
            self.assertEqual(f['story_gate'],expect)
    def test_06_optional_tower_not_campaign(self):
        self.assertTrue(C['tower_does_not_complete_Q09_Q10'])
        self.assertTrue(C['tower_does_not_grant_advancement_proof'])
        self.assertTrue(C['original_investigation_nodes_unchanged'])
    def test_07_hp_budget(self):
        for f in F: self.assertEqual(sum(a['hp'] for a in f['actors']),f['hp_budget'])
    def test_08_actor_references(self):
        ids=[]
        for f in F:
            for a in f['actors']:
                self.assertIn(a['archetype'],C['enemy_archetypes']); self.assertGreater(a['hp'],0); ids.append(a['actor_id'])
        self.assertEqual(len(ids),len(set(ids)))
    def test_09_actor_limit(self):
        self.assertTrue(all(1<=len(f['actors'])<=3 for f in F))
    def test_10_affix_eligibility(self):
        defs={a['id']:a for a in C['affix_definitions']}
        for f in F:
            self.assertLessEqual(len(f['affixes']),2)
            self.assertEqual(len(f['affixes']),len(set(f['affixes'])))
            actors={a['archetype'] for a in f['actors']}
            for tag in f['affixes']:
                rule=defs[tag]
                if rule['requires_any']: self.assertTrue(actors.intersection(rule['requires_any']))
                if tag=='entry_stagger': self.assertGreater(len(f['actors']),1)
                if tag=='guard_rotation': self.assertGreater(len(f['actors']),2)
    def test_11_no_implicit_scaling(self):
        for f in F:
            self.assertFalse(f['armor_scaling']); self.assertFalse(f['global_attack_speed_scaling'])
            for a in f['actors']: self.assertEqual(a['armor'],C['enemy_archetypes'][a['archetype']]['armor'])
    def test_12_damage_scale_bounds(self):
        self.assertTrue(all(.4<=a['damage_scale']<=1 for f in F for a in f['actors']))
    def test_13_first_clear_totals(self):
        for t in 'LMA':
            r={k:sum(f['first_clear_reward'][k] for f in F if f['church']==t) for k in ('xp','crowns','essence','research')}
            self.assertEqual(r,dict(xp=360,crowns=1150,essence=210,research=10))
    def test_14_no_talent_or_random_rewards(self):
        self.assertTrue(all(f['first_clear_reward']['talent_points']==0 and f['first_clear_reward']['random_relic_rolls']==0 for f in F))
    def test_15_repeat_rewards_zero(self):
        self.assertTrue(all(not any(f['repeat_reward'].values()) for f in F))
    def test_16_milestone_only_research(self):
        for f in F: self.assertEqual(f['first_clear_reward']['research'],int(f['number']%10==0))
    def test_17_calibration_cost_total(self):
        costs=C['calibration']['rank_costs']
        self.assertEqual(sum(x['crowns'] for x in costs),2700)
        self.assertEqual(sum(x['essence'] for x in costs),340)
    def test_18_calibration_grind_arithmetic(self):
        self.assertEqual(max(math.ceil(2700/54),math.ceil(340/7)),50)
        self.assertGreaterEqual(50*54,2700); self.assertGreaterEqual(50*7,340)
    def test_19_legacy_caps(self):
        self.assertEqual(project_s9(10,0),{'hp':2400,'attack':100})
        self.assertEqual(project_s9(10,5),{'hp':2640,'attack':110})
        self.assertEqual(project_s9(1,0),{'hp':1800,'attack':80})
    def test_20_manual_start_no_resets(self):
        self.assertTrue(C['manual_start_required']); self.assertFalse(C['continuous_start_enabled']); self.assertFalse(C['daily_reset'])
        self.assertFalse(C['instant_sweep_enabled']); self.assertEqual(C['energy_fee'],0)
    def test_21_all_draft_gated(self):
        self.assertTrue(all(not f['release_enabled'] and f['requires_timing_verification'] and f['requires_mask_decision'] for f in F))
    def test_22_currency_types(self):
        self.assertEqual(C['currency_types'],['crowns','essence'])
    def test_23_no_calibration_hard_gate(self):
        self.assertTrue(all(f['calibration_gate'] is None for f in F))
    def test_24_boss_profiles(self):
        for f in F:
            if f['kind']=='boss':
                self.assertEqual(f['boss_profile']['archetype'],f['actors'][0]['archetype'])
                if f['church']=='M': self.assertEqual(f['boss_profile']['logical_identity_count'],1)
            else: self.assertIsNone(f['boss_profile'])
    def test_25_snapshot_reproducible(self):
        self.assertEqual(build(),C)
        path=HERE/'tower_config.json'
        self.assertEqual(json.loads(path.read_text(encoding='utf-8')),C)
    def test_26_per_tower_60_budget(self):
        s=run_tower(n=60)
        self.assertEqual(s.wallet,{'xp':360,'crowns':570,'essence':98})
        self.assertEqual(s.research['L'],6)
    def test_49_research_is_not_cross_church_currency(self):
        points={t:sum(f['first_clear_reward']['research'] for f in F if f['church']==t) for t in 'LMA'}
        self.assertEqual(sum(p//6 for p in points.values()),3)
        self.assertEqual({t:p%6 for t,p in points.items()},dict(L=4,M=4,A=4))
    def test_27_duration_arithmetic_not_simulation(self):
        self.assertEqual(sum(f['target_clear_time_s'][0] for f in F),9000)
        self.assertEqual(sum(f['target_clear_time_s'][1] for f in F),18000)

class ReferenceAccountingTests(unittest.TestCase):
    def test_28_same_receipt_no_double_reward(self):
        f=F[0]; s=State(completed_quests=all_story())
        once,r=apply_design_clear(s,f,'x','win')
        twice,r2=apply_design_clear(once,f,'x','win')
        self.assertEqual(twice.wallet,once.wallet); self.assertFalse(r2['credited_now'])
        self.assertEqual(s.wallet,dict(xp=0,crowns=0,essence=0))
    def test_29_new_battle_same_floor_no_repeat_reward(self):
        s=run_tower(n=1)
        after,r=apply_design_clear(s,F[0],'replay','win')
        self.assertEqual(s.wallet,after.wallet); self.assertFalse(r['credited_now'])
    def test_30_rule_version_no_refirst_clear(self):
        s=run_tower(n=1); changed=deepcopy(F[0]); changed['first_clear_reward']['crowns']=999999
        after,_=apply_design_clear(s,changed,'new_revision','win','hotfix_9')
        self.assertEqual(after.wallet,s.wallet)
    def test_31_conflicting_receipt_rejected(self):
        s=run_tower(n=1)
        with self.assertRaises(ValueError): apply_design_clear(s,F[0],'L-1','loss')
    def test_32_failure_no_reward(self):
        s=State(completed_quests=all_story())
        for result in ('loss','abort'):
            after,_=apply_design_clear(s,F[0],result,result)
            self.assertEqual(after.wallet,s.wallet); self.assertEqual(after.highest,s.highest)
    def test_33_skip_rejected(self):
        with self.assertRaises(ValueError): apply_design_clear(State(completed_quests=all_story()),F[1],'skip','win')
    def test_34_story_lock(self):
        with self.assertRaises(ValueError): apply_design_clear(State(),F[0],'locked','win')
    def test_35_three_tower_independence(self):
        s=run_tower(n=2); s=run_tower('M',1,s)
        self.assertEqual(s.highest,dict(L=2,M=1,A=0))
    def test_36_all_300_replay(self):
        s=State(completed_quests=all_story())
        for t in 'LMA': s=run_tower(t,100,s)
        before=deepcopy(s)
        for f in F: s,_=apply_design_clear(s,f,'replay-'+f['id'],'win')
        self.assertEqual(s.wallet,before.wallet); self.assertEqual(s.research,before.research)
        self.assertEqual(s.wallet,dict(xp=1080,crowns=3450,essence=630))
    def test_37_shared_research_threshold(self):
        s=State(completed_quests=all_story()); s.research['L']=5
        s=run_tower(n=10,state=s)
        self.assertEqual(s.research['L'],6); self.assertEqual(s.research['L']//6,1)
    def test_38_calibration_purchase_refund(self):
        s=State(completed_quests=all_story()); s.wallet.update(xp=2340,crowns=2700,essence=340)
        bought=set_calibration(s,5,C['calibration'])
        self.assertEqual(bought.wallet,dict(xp=2340,crowns=0,essence=0))
        returned=set_calibration(bought,0,C['calibration'])
        self.assertEqual(returned.wallet,s.wallet); self.assertEqual(len(returned.calibration_paid),0)
    def test_39_calibration_refund_historical_prices(self):
        s=State(completed_quests=all_story()); s.wallet.update(xp=2340,crowns=1000,essence=100)
        s=set_calibration(s,1,C['calibration']); cfg=deepcopy(C['calibration']); cfg['rank_costs'][0]['crowns']=9999
        s=set_calibration(s,0,cfg)
        self.assertEqual(s.wallet['crowns'],1000)
    def test_40_calibration_insufficient_atomic_model(self):
        s=State(completed_quests=all_story()); s.wallet.update(xp=2340,crowns=2699,essence=340)
        before=deepcopy(s)
        with self.assertRaises(ValueError): set_calibration(s,5,C['calibration'])
        self.assertEqual(s,before)
    def test_41_calibration_battle_lock(self):
        s=State(completed_quests=all_story(),active_battle=True)
        with self.assertRaises(ValueError): set_calibration(s,0,C['calibration'])
    def test_42_calibration_gate_and_bounds(self):
        with self.assertRaises(ValueError): set_calibration(State(),0,C['calibration'])
        for bad in (-1,6,True,1.5):
            with self.assertRaises(ValueError): project_s9(10,bad)
    def test_43_do_not_infer_tower_from_campaign(self):
        self.assertEqual(State(completed_quests=all_story()).highest,dict(L=0,M=0,A=0))
    def test_45_xp_cap_and_repeated_receipt(self):
        s=State(completed_quests=all_story()); s.wallet['xp']=2339
        after,r=apply_design_clear(s,F[0],'capped','win')
        self.assertEqual(after.wallet['xp'],2340); self.assertEqual(after.xp_overflow,9)
        again,_=apply_design_clear(after,F[0],'capped','win')
        self.assertEqual(again.xp_overflow,9)
    def test_46_cosmetics_unique_and_once(self):
        items=[f['first_clear_reward']['cosmetic'] for f in F if f['first_clear_reward']['cosmetic']]
        self.assertEqual(len(items),9); self.assertEqual(len(set(items)),9)
        s=run_tower(n=30); self.assertEqual(len(s.cosmetics),1)
        after,_=apply_design_clear(s,BY['tower.s9.L.030'],'replay-cosmetic','win')
        self.assertEqual(s.cosmetics,after.cosmetics)
    def test_47_same_archetype_two_logical_actors(self):
        for f in F:
            if len(f['actors'])==2 and all(a['archetype']=='E10' for a in f['actors']):
                self.assertNotEqual(f['actors'][0]['actor_id'],f['actors'][1]['actor_id'])
                return
        self.fail('expected a two-courier fixture')
    def test_48_calibration_level_gate(self):
        s=State(completed_quests=all_story()); s.wallet.update(xp=2339,crowns=9999,essence=9999)
        with self.assertRaises(ValueError): set_calibration(s,1,C['calibration'])
    def test_44_bad_progress_no_silent_repair(self):
        s=State(completed_quests=all_story()); s.highest['L']=2
        with self.assertRaises(ValueError): apply_design_clear(s,F[0],'bad','win')


def main() -> int:
    write_outputs(C)
    stream=io.StringIO()
    suite=unittest.TestSuite([unittest.defaultTestLoader.loadTestsFromTestCase(StaticTests),
                             unittest.defaultTestLoader.loadTestsFromTestCase(ReferenceAccountingTests)])
    result=unittest.TextTestRunner(stream=stream,verbosity=2).run(suite)
    (HERE/'audit_tests.txt').write_text(stream.getvalue(),encoding='utf-8')
    per_tower={k:sum(f['first_clear_reward'][k] for f in F if f['church']=='L') for k in ('xp','crowns','essence','research')}
    summary={'version':C['content_version'],'tests_run':result.testsRun,'passed':result.wasSuccessful(),
       'failures':len(result.failures),'errors':len(result.errors),'floor_count':len(F),
       'per_tower_rewards':per_tower,
       'all_towers_rewards':{k:v*3 for k,v in per_tower.items()},
       'research_tracks_separate':True,
       'selections_from_tower_research_alone':3,
       'research_remainder_each_church':4,
       'calibration_max_stats':project_s9(10,5),'calibration_total_cost':{'crowns':2700,'essence':340},
       'isolated_repeat_node3_wins_for_all_calibration_costs':50,
       'assumed_victory_time_sum_seconds':[9000,18000],
       'first_60_floor_rewards':{'xp':360,'crowns':570,'essence':98,'research':6},
       'implemented':'static configuration and pure in-memory reference transitions',
       'not_implemented':['combat simulation','Unity animation bindings','actual 300 playable floors',
           'real player win rate','persistent atomic save transactions','network concurrency',
           'anti-cheat','live economy','safe area rendering'],
       'do_not_infer':'Configuration reachability does not prove any build can win.'}
    (HERE/'audit_results.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(stream.getvalue()); print(json.dumps(summary,ensure_ascii=False,indent=2))
    return 0 if result.wasSuccessful() else 1

if __name__=='__main__':
    raise SystemExit(main())
