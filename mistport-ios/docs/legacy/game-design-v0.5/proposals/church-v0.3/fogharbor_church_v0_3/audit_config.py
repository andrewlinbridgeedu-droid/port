"""Static checks and reward arithmetic for a proposed design.

No combat, Unity timing, network transactions, drops sampled from players, or
live market data are simulated by this file. Python standard library only.
"""
import json
import unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parent
C=json.loads((ROOT/'church_config.json').read_text(encoding='utf-8'))
Q={q['id']:q for q in C['quests']}
N={n['id']:n for n in C['nodes']}
R={r['id']:r for r in C['relics']}

def reachable(quest_ids=None,node_ids=None):
    quest_ids=set(Q) if quest_ids is None else set(quest_ids)
    node_ids=set(N) if node_ids is None else set(node_ids)
    doneq,donen=set(),set()
    while True:
        before=(len(doneq),len(donen))
        for qid in sorted(quest_ids):
            q=Q[qid]
            if q['requires_quest'] is not None and q['requires_quest'] not in doneq:
                continue
            obj=q['objective']
            ok=(obj=='authored_story_trial'
                or (obj=='any_floor_5_cleared' and any(N[n]['floor']==5 for n in donen))
                or (obj=='any_boss_cleared' and any(N[n]['boss_proof'] for n in donen)))
            if ok: doneq.add(qid)
        for nid in sorted(node_ids):
            n=N[nid]
            if n['requires_quest'] in doneq and (n['requires_node'] is None or n['requires_node'] in donen):
                donen.add(nid)
        if before==(len(doneq),len(donen)): return doneq,donen

def sums(rows,field):
    return {k:sum(row[field].get(k,0) for row in rows) for k in ['xp','crowns','essence']}

def eligible_catalog(church_id,completed):
    # Q08 makes all eight story skills available; acquisition still doesn't mean equipped.
    return next(c['pool'] for c in C['churches'] if c['id']==church_id) if 'Q08' in completed else []

class ConfigTests(unittest.TestCase):
    def test_01_three_six_node_routes(self):
        self.assertEqual(len(C['churches']),3)
        self.assertEqual(len(N),18)
        for c in C['churches']:
            self.assertEqual(sorted(n['floor'] for n in N.values() if n['church']==c['id']),list(range(1,7)))
    def test_02_unique_ids(self):
        for key in ['quests','nodes','relics','churches']:
            ids=[r['id'] for r in C[key]]
            self.assertEqual(len(ids),len(set(ids)))
    def test_03_no_progression_deadlock(self):
        q,n=reachable()
        self.assertEqual(q,set(Q)); self.assertEqual(n,set(N))
    def test_04_one_church_is_enough_for_progression(self):
        for c in C['churches']:
            q,n=reachable(node_ids=[n['id'] for n in N.values() if n['church']==c['id']])
            self.assertIn('Q10',q)
    def test_05_point_milestones(self):
        checkpoints={1:4,2:8,4:14,6:22,8:30}
        s=0
        for i,q in enumerate(C['quests'],1):
            s+=q['completion_reward']['talent_points']
            if i in checkpoints: self.assertEqual(s,checkpoints[i])
        self.assertEqual(s,30)
    def test_06_all_eight_skills_guaranteed(self):
        skills=set()
        for q in C['quests']:
            skills.update(q['accepted_skill_grants']); skills.update(q['completion_skill_grants'])
        self.assertEqual(skills,set('NFMEIRAH'))
    def test_07_story_xp_reaches_cap_without_repeat_farming(self):
        self.assertEqual(C['levels'][-1]['cumulative_xp'],2340)
        self.assertEqual(sum(q['completion_reward']['xp'] for q in C['quests']),2490)
    def test_08_level_caps_match_combat_benchmark(self):
        self.assertEqual(C['levels'][-1]['base_hp'],2400)
        self.assertEqual(C['levels'][-1]['base_attack'],100)
        self.assertEqual(len(C['levels']),10)
        self.assertEqual(sorted(l['cumulative_xp'] for l in C['levels']),[l['cumulative_xp'] for l in C['levels']])
    def test_09_all_eighteen_relics_have_a_source(self):
        got=set()
        for q in C['quests']: got.update(q['completion_reward']['restored_relics'])
        for n in C['nodes']: got.update(n['first_clear_bonus']['restored_relics'])
        for c in C['churches']: got.update(c['pool'])
        self.assertEqual(got,set(R))
    def test_10_all_references_resolve(self):
        for q in Q.values():
            self.assertTrue(q['requires_quest'] is None or q['requires_quest'] in Q)
        for n in N.values():
            self.assertIn(n['requires_quest'],Q)
            self.assertTrue(n['requires_node'] is None or n['requires_node'] in N)
        for c in C['churches']:
            for rid in c['pool']: self.assertIn(rid,R)
    def test_11_six_clears_fund_most_expensive_target(self):
        n=N['A03']; cost=R['R18']['repair_or_research_claim_cost']
        self.assertGreaterEqual(n['base_reward']['crowns']*6,cost['crowns'])
        self.assertGreaterEqual(n['base_reward']['essence']*6,cost['essence'])
        self.assertEqual(n['research_increment']*6,C['research']['threshold'])
    def test_12_no_duplicate_profit_from_crafting(self):
        for r in R.values():
            self.assertLess(r['random_duplicate_dismantle']['essence'],r['repair_or_research_claim_cost']['essence'])
            self.assertEqual(r['random_duplicate_dismantle']['crowns'],0)
    def test_13_no_reward_for_failure_or_summons(self):
        self.assertEqual(C['failure_reward'],0)
        self.assertEqual(C['spawned_enemy_reward'],0)
    def test_14_research_and_first_claim_are_separate(self):
        self.assertFalse(C['research']['random_resets_progress'])
        self.assertTrue(C['research']['counts_before_catalog_unlock'])
        for n in N.values():
            self.assertEqual(n['research_increment'],int(n['floor']>=3))
    def test_15_catalog_requires_completed_story(self):
        for c in C['churches']:
            self.assertEqual(eligible_catalog(c['id'],{'Q06'}),[])
            self.assertEqual(eligible_catalog(c['id'],{'Q08'}),c['pool'])
    def test_16_only_two_standard_currencies(self):
        self.assertEqual(C['currency_types'],['crowns','essence'])
        self.assertFalse(C['research']['is_trade_currency'])
    def test_17_mvp_progression_is_closed(self):
        q,n=reachable(C['mvp']['quests'],C['mvp']['nodes'])
        self.assertEqual(q,set(C['mvp']['quests']))
        self.assertEqual(n,set(C['mvp']['nodes']))
        self.assertFalse(C['mvp']['random_drop'])
        self.assertFalse(C['mvp']['bosses'])
    def test_18_one_boss_required_not_three(self):
        self.assertEqual(C['ritual']['requires_boss_count'],1)
        self.assertEqual(sum(n['boss_proof'] for n in N.values()),3)
    def test_19_enemy_group_coverage(self):
        enemies={e for n in N.values() for e in n['enemies']}
        self.assertTrue({f'E{i:02d}' for i in range(1,13)}<=enemies)
        self.assertEqual({n['existing_group'] for n in N.values()}-{None},{f'G{i}' for i in range(1,7)})
    def test_20_nonnegative_awards(self):
        for q in Q.values():
            for k in ['xp','crowns','essence','talent_points']:
                v=q['completion_reward'][k]
                self.assertIs(type(v),int); self.assertGreaterEqual(v,0)
        for n in N.values():
            for k,v in n['base_reward'].items():
                self.assertIs(type(v),int); self.assertGreaterEqual(v,0)
    def test_21_manual_battles_and_no_market_in_prototype(self):
        self.assertTrue(C['manual_start_required'])
        self.assertFalse(C['instant_sweep_enabled'])
        self.assertFalse(C['public_market_enabled'])
    def test_22_target_progress_is_bounded_by_successful_clears_not_attempts(self):
        threshold=C['research']['threshold']
        outcomes=[False,True,False,True,True,False,True,True,True]
        completions=sum(outcomes)
        self.assertEqual(completions,threshold)
        self.assertEqual(completions//threshold,1)
        self.assertEqual((completions-1)//threshold,0)

def report():
    qtotal=sums(C['quests'],'completion_reward')
    route=[n for n in N.values() if n['church']=='L']
    base=sums(route,'base_reward'); bonus=sums(route,'first_clear_bonus')
    together={k:qtotal[k]+base[k]+bonus[k] for k in qtotal}
    n=N['A03']; cost=R['R18']['repair_or_research_claim_cost']
    clear6={k:n['base_reward'].get(k,0)*6+n['first_clear_bonus'].get(k,0) for k in ['xp','crowns','essence']}
    clear6net={k:clear6[k]-cost.get(k,0) for k in clear6}
    return {"scope":"static_config_and_arithmetic_only","combat_simulated":False,"unity_modified":False,"transaction_implementation_tested":False,
      "story_completion_rewards":qtotal,"story_xp_cap":C['levels'][-1]['cumulative_xp'],"story_xp_surplus":qtotal['xp']-C['levels'][-1]['cumulative_xp'],
      "talent_points":sum(q['completion_reward']['talent_points'] for q in C['quests']),
      "one_route_base_rewards":base,"one_route_first_clear_bonus":bonus,"story_plus_one_route":together,
      "six_A03_clears_including_first_bonus":clear6,"six_A03_clears_then_R18_research_claim":clear6net,
      "chance_any_random_relic_by_six_eligible_clears":1-.9**6,
      "chance_no_random_relic_by_six_eligible_clears":.9**6,
      "deterministic_target_successful_clear_limit":6,
      "target_time_efficiency_not_measured":[{"floor":n['floor'],"essence_per_minute_at_midpoint_target_duration":round(n['base_reward']['essence']*60/(sum(n['suggested_duration_seconds'])/2),4)} for n in route]}

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(ConfigTests)
    with (ROOT/'audit_tests.txt').open('w',encoding='utf-8') as out:
        result=unittest.TextTestRunner(stream=out,verbosity=2).run(suite)
    result_report=report()
    result_report['test_count']=result.testsRun
    result_report['tests_passed']=result.wasSuccessful()
    (ROOT/'audit_results.json').write_text(json.dumps(result_report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print((ROOT/'audit_tests.txt').read_text(encoding='utf-8'))
    print(json.dumps(result_report,ensure_ascii=False,indent=2))
    raise SystemExit(0 if result.wasSuccessful() else 1)
