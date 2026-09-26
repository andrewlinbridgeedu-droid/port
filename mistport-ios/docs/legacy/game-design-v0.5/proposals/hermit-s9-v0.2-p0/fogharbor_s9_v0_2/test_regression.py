"""P0 state tests and narrow v0.1 bug regressions. No Unity or full combat balance."""
from __future__ import annotations
from copy import deepcopy
from dataclasses import replace
from pathlib import Path
import json
import unittest

from evidence_gate import PassiveEvidenceGate
from validate_s9 import SKILLS, Skill, schedule, BUILDS
from combat_subset import Combat, TESTS
from talent_core import (NODE_IDS, TalentError, TalentSession, normalise, validate,
                         reachable_prefix, make_save, propose_migration, remaining)

HERE=Path(__file__).resolve().parent

def three_hit_fixture(relics=()):
    combat=Combat(['guard']*3,['E','N','F','A'],relics,hp=10000,limit=100)
    combat.queue.clear()
    for enemy in combat.enemies:
        enemy.mark_end=1000
        combat.push(100,3,'enemy_hit',(enemy.id,1.,0))
    return combat

class EvidenceTests(unittest.TestCase):
    def test_three_simultaneous_is_two_not_three(self):
        g=PassiveEvidenceGate()
        out=[g.attempt(100,i,f'h{i}') for i in range(3)]
        self.assertEqual([x.accepted for x in out],[True,True,False])
        self.assertEqual(out[-1].reason,'global_rolling_limit')

    def test_rolling_window_not_calendar_second(self):
        g=PassiveEvidenceGate()
        self.assertTrue(g.attempt(99,0,'a').accepted)
        self.assertTrue(g.attempt(99,1,'b').accepted)
        self.assertEqual(g.attempt(100,2,'c').reason,'global_rolling_limit')
        self.assertEqual(g.attempt(198,2,'d').reason,'global_rolling_limit')
        self.assertTrue(g.attempt(199,2,'e').accepted)

    def test_exact_window_expiry_is_available(self):
        g=PassiveEvidenceGate()
        g.attempt(0,0,'a'); g.attempt(0,1,'b')
        self.assertTrue(g.attempt(100,0,'c').accepted)
        self.assertTrue(g.attempt(100,1,'d').accepted)

    def test_per_enemy_cooldown_remains(self):
        g=PassiveEvidenceGate()
        self.assertTrue(g.attempt(0,0,'a').accepted)
        self.assertEqual(g.attempt(99,0,'b').reason,'per_enemy_cooldown')
        self.assertTrue(g.attempt(100,0,'c').accepted)

    def test_duplicate_callback_not_a_second_hit(self):
        g=PassiveEvidenceGate()
        g.attempt(0,0,'a')
        self.assertEqual(g.attempt(0,0,'a').reason,'duplicate_hit')
        self.assertEqual(g.attempt(100,0,'a').reason,'duplicate_hit')

    def test_rejected_hit_is_never_replayed_later(self):
        g=PassiveEvidenceGate()
        g.attempt(0,0,'a'); g.attempt(0,1,'b')
        self.assertFalse(g.attempt(0,2,'c').accepted)
        self.assertEqual(g.attempt(100,2,'c').reason,'duplicate_hit')
        self.assertTrue(g.attempt(100,2,'d').accepted)

    def test_ineligible_hit_consumes_no_budget(self):
        g=PassiveEvidenceGate()
        self.assertEqual(g.attempt(0,0,'derived',eligible=False).reason,'ineligible')
        self.assertTrue(g.attempt(0,0,'real_a').accepted)
        self.assertTrue(g.attempt(0,1,'real_b').accepted)

    def test_full_ledger_consumes_no_budget_or_enemy_cooldown(self):
        g=PassiveEvidenceGate()
        self.assertEqual(g.attempt(0,0,'full',has_capacity=False).reason,'ledger_full')
        self.assertTrue(g.attempt(1,0,'new').accepted)
        self.assertTrue(g.attempt(1,1,'other').accepted)

    def test_each_player_battle_has_separate_budget(self):
        first=PassiveEvidenceGate(); second=PassiveEvidenceGate()
        first.attempt(0,0,'a'); first.attempt(0,1,'b')
        self.assertTrue(second.attempt(0,0,'a').accepted)

    def test_reject_time_reversal_and_invalid_parameters(self):
        g=PassiveEvidenceGate();g.attempt(10,0,'a')
        with self.assertRaises(ValueError):g.attempt(9,0,'b')
        with self.assertRaises(ValueError):PassiveEvidenceGate(limit=0)

    def test_combat_path_reproduces_three_enemies(self):
        c=three_hit_fixture();c.run()
        self.assertEqual([e.proof for e in c.enemies],[1,1,0])
        self.assertEqual(c.passive_gate.stats['global_rolling_limit'],1)

    def test_relic_bonus_is_not_a_third_passive_base_trigger(self):
        c=three_hit_fixture(['R05']);c.run()
        self.assertEqual([e.proof for e in c.enemies],[2,2,0])
        self.assertEqual(c.passive_gate.stats['accepted'],2)

    def test_direct_skill_evidence_bypasses_passive_budget(self):
        c=three_hit_fixture();c.run()
        self.assertEqual(c.evidence(c.enemies[2],2),2)
        self.assertEqual(c.enemies[2].proof,2)

    def test_no_evidence_for_dead_target_or_dead_actor(self):
        c=three_hit_fixture();c.queue.clear();c.now=100
        c.enemies[0].hp=0
        self.assertEqual(c.passive_evidence_on_hit(c.enemies[0],'dead_target').reason,'ineligible')
        c.hp=0
        self.assertEqual(c.passive_evidence_on_hit(c.enemies[1],'dead_actor').reason,'ineligible')

class ScheduleTests(unittest.TestCase):
    def test_one_card(self):
        actions=schedule(['F'],end=700)
        self.assertEqual([(a['id'],a['start_tick']) for a in actions if a['id']!='B'],[('F',0),('F',600)])
        self.assertEqual(sum(a['opening'] for a in actions),1)

    def test_two_cards(self):
        actions=schedule(['F','M'],end=700)
        self.assertEqual([a['id'] for a in actions if a['opening']],['F','M'])
        self.assertEqual([a['start_tick'] for a in actions if a['id']=='M'],[50,350,650])

    def test_three_cards(self):
        actions=schedule(['F','N','M'])
        self.assertEqual([a['id'] for a in actions if a['opening']],['F','N','M'])

    def test_empty_physical_slots_are_skipped(self):
        actions=schedule([None,'M',None,'F'],end=100)
        self.assertEqual([(a['id'],a['slot_index'],a['start_tick']) for a in actions if a['opening']],
                         [('M',1,0),('F',3,50)])

    def test_zero_cards_fails_cleanly(self):
        for order in ([],[None],[None]*4):
            with self.subTest(order=order),self.assertRaises(ValueError):schedule(order)

    def test_duplicate_unknown_or_too_many_fails(self):
        for order in (['F','F'],['bogus'],['F','N','M','R','E']):
            with self.subTest(order=order),self.assertRaises(ValueError):schedule(order)

    def test_equal_ready_times_use_physical_order(self):
        specs=dict(SKILLS)
        specs['N']=replace(specs['N'],cd=250)
        specs['F']=replace(specs['F'],cd=200)
        actions=schedule([None,'N',None,'F'],end=300,skill_specs=specs)
        self.assertEqual([(a['id'],a['start_tick']) for a in actions if not a['opening'] and a['id']!='B'],
                         [('N',250),('F',300)])

    def test_busy_basic_attack_is_not_interrupted(self):
        specs=dict(SKILLS);specs['M']=replace(specs['M'],cd=320)
        actions=schedule(['M'],end=400,skill_specs=specs)
        # Basic attack starts at 250, next at 350, so use CD 280 instead.
        specs['M']=replace(specs['M'],cd=280)
        actions=schedule(['M'],end=400,skill_specs=specs)
        self.assertEqual([a['start_tick'] for a in actions if a['id']=='M'],[0,300])

    def test_injected_per_skill_timing_not_constant_point_two(self):
        specs=dict(SKILLS)
        specs['M']=replace(specs['M'],impact_delay=43,lock=81)
        specs['F']=replace(specs['F'],impact_delay=120,lock=73)
        a=schedule(['M','F'],end=200,skill_specs=specs)
        self.assertEqual((a[0]['impact_tick'],a[1]['start_tick'],a[1]['impact_tick']),(43,81,201))
        self.assertIn('NOT_Unity',a[0]['timing_profile'])

    def test_opening_flag_only_first_cycle(self):
        specs=dict(SKILLS);specs['M']=replace(specs['M'],cd=10,lock=10,impact_delay=5)
        a=schedule(['M'],end=50,skill_specs=specs)
        self.assertEqual([x['opening'] for x in a],[True,False,False,False,False,False])

    def test_invalid_timing_rejected(self):
        specs=dict(SKILLS);specs['F']=replace(specs['F'],lock=0)
        with self.assertRaises(ValueError):schedule(['F'],skill_specs=specs)
        with self.assertRaises(ValueError):schedule(['F'],end=-1)

    def test_nine_old_four_card_timelines_unchanged(self):
        baseline=json.loads((HERE/'baseline_v01/results.json').read_text())['timelines']
        for build,old in zip(BUILDS,baseline):
            a=schedule(build['order'],mask_cd=build['mask_cd'])
            actual={sid:[x['impact_tick']/100 for x in a if x['id']==sid and x['impact_tick']<=2000]
                    for sid in build['order']}
            self.assertEqual(actual,old['impact_times_20s'])

class TalentTests(unittest.TestCase):
    def test_zero_and_thirty_earned_budgets(self):
        self.assertEqual(remaining({},0),0)
        self.assertEqual(remaining({},30),30)
        with self.assertRaises(TalentError):validate({'T1':1},0)

    def test_cannot_spend_unearned_points(self):
        session=TalentSession({'T1':4},4)
        with self.assertRaises(TalentError):session.add('T1')
        self.assertEqual(session.draft['T1'],4)

    def test_five_levels_no_sixth(self):
        session=TalentSession({'T1':5},30)
        with self.assertRaises(TalentError):session.add('T1')
        self.assertEqual(session.draft['T1'],5)

    def test_boolean_negative_fraction_unknown_rejected(self):
        for values in ({'T1':True},{'T1':-1},{'T1':1.5},{'T7':1}):
            with self.subTest(values=values),self.assertRaises(TalentError):validate(values,30)

    def test_dependency_and_self_exclusion(self):
        with self.assertRaises(TalentError):validate({'T1':1,'T3':5},30)
        self.assertEqual(validate({'T1':5,'T3':1},30)['T3'],1)

    def test_circular_funding_cannot_unlock(self):
        with self.assertRaises(TalentError):validate({'T1':1,'T2':1,'T3':5,'T5':3},30)

    def test_story_lock_is_separate_from_budget(self):
        session=TalentSession({},30,unlocked={'T1','T2'})
        with self.assertRaises(TalentError):session.add('P1')
        session.add('T1')
        self.assertEqual(session.draft['T1'],1)

    def test_all_nine_builds_exact_thirty(self):
        for build in BUILDS:
            ranks={f'{tree}{i+1}':rank for tree in ('T','P','S') for i,rank in enumerate(build[tree])}
            self.assertEqual(sum(validate(ranks,30).values()),30)

    def test_cross_branch_threshold_refunds_six(self):
        session=TalentSession({'T1':5,'T2':1,'T3':4,'T5':5},30)
        plan=session.preview_remove('T2')
        self.assertEqual(dict(plan.refunded),{'T2':1,'T5':5})
        self.assertEqual(plan.total_refund,6)
        self.assertEqual(session.draft['T5'],5)  # Preview does not mutate.
        session.confirm_remove(plan)
        self.assertEqual(session.draft['T3'],4)
        self.assertEqual(session.draft['T5'],0)

    def test_iterated_cascade_refunds_eleven(self):
        session=TalentSession({'T1':5,'T3':5,'T5':5},30)
        plan=session.preview_remove('T1')
        self.assertEqual(dict(plan.refunded),{'T1':1,'T3':5,'T5':5})
        self.assertEqual(plan.total_refund,11)
        session.confirm_remove(plan)
        validate(session.draft,30)

    def test_stale_refund_dialog_rejected(self):
        session=TalentSession({'T1':5,'T3':5,'T5':5},30)
        plan=session.preview_remove('T1')
        session.add('P1')
        with self.assertRaises(TalentError):session.confirm_remove(plan)

    def test_minus_on_zero_rejected(self):
        with self.assertRaises(TalentError):TalentSession({},30).preview_remove('T1')

    def test_cancel_does_not_change_committed(self):
        session=TalentSession({'T1':1},30)
        session.add('T1');session.cancel()
        self.assertEqual(session.draft['T1'],1)
        self.assertEqual(session.committed['T1'],1)

    def test_apply_then_conflicting_save_rejected(self):
        session=TalentSession({},30)
        session.add('T1');saved=session.apply(expected_save_revision=0)
        self.assertEqual(saved['revision'],1)
        self.assertEqual(session.committed['T1'],1)
        with self.assertRaises(TalentError):session.apply(expected_save_revision=0)

    def test_tree_reset_preserves_other_tree(self):
        session=TalentSession({'T1':5,'P1':5},30)
        session.reset('T')
        self.assertEqual(session.draft['T1'],0)
        self.assertEqual(session.draft['P1'],5)
        session.reset()
        self.assertEqual(sum(session.draft.values()),0)

class MigrationTests(unittest.TestCase):
    def test_known_integer_fixture_preserved(self):
        old={'schema_version':1,'layout_id':'reference_explicit_rank_v1','ranks':{'T1':5,'T3':5},'unspent':999}
        before=deepcopy(old)
        result=propose_migration(old,12)
        self.assertEqual(result.status,'compatible')
        self.assertEqual(sum(result.candidate['nodes'].values()),10)
        self.assertEqual(remaining(result.candidate['nodes'],12),2)
        self.assertEqual(old,before)

    def test_current_migration_is_idempotent(self):
        source=make_save({'T1':5},10)
        first=propose_migration(source,10)
        second=propose_migration(first.candidate,10)
        self.assertEqual(first.candidate,second.candidate)

    def test_unknown_legacy_boolean_layout_not_guessed(self):
        source={'schema_version':1,'layout_id':'unknown','ranks':{'T1':True}}
        result=propose_migration(source,8)
        self.assertEqual(result.status,'needs_confirmation_reset')
        self.assertEqual(sum(result.candidate['nodes'].values()),0)
        self.assertEqual(result.original_backup,source)

    def test_future_schema_blocks_overwrite(self):
        result=propose_migration({'schema_version':99},30)
        self.assertEqual(result.status,'blocked_newer_schema')
        self.assertIsNone(result.candidate)

    def test_illegal_old_total_does_not_become_earned_points(self):
        result=propose_migration({'schema_version':1,'layout_id':'reference_explicit_rank_v1',
                                 'ranks':{n:5 for n in NODE_IDS}},10)
        self.assertEqual(result.status,'needs_confirmation_reset')
        self.assertEqual(result.candidate['earned_snapshot'],10)
        self.assertEqual(remaining(result.candidate['nodes'],10),10)

    def test_unreachable_old_build_requires_confirmed_reset(self):
        source=make_save({},20);source['nodes']={'T1':1,'T3':5}
        result=propose_migration(source,20)
        self.assertEqual(result.status,'needs_confirmation_reset')

    def test_unknown_node_is_preserved_in_backup(self):
        source=make_save({},20);source['nodes']={'removed_node':5}
        result=propose_migration(source,20)
        self.assertEqual(result.status,'needs_confirmation_reset')
        self.assertEqual(result.original_backup['nodes'],{'removed_node':5})

    def test_story_unavailable_node_not_silently_activated(self):
        source=make_save({'P1':5},10)
        result=propose_migration(source,10,unlocked={'T1','T2'})
        self.assertEqual(result.status,'needs_confirmation_reset')

class CoverageTests(unittest.TestCase):
    def test_unsupported_active_relic_fails_even_with_inert_opt_in(self):
        with self.assertRaises(NotImplementedError):
            Combat(['guard'],['M','F','N','R'],['R06'],allow_inert_relics=True)
        with self.assertRaises(NotImplementedError):
            Combat(['nurse'],['I','F','N','A'],['R15'],allow_inert_relics=True)

    def test_inert_relic_needs_explicit_opt_in(self):
        with self.assertRaises(NotImplementedError):
            Combat(['guard'],['N','F','R','A'],['R06'])
        c=Combat(['guard'],['N','F','R','A'],['R06'],allow_inert_relics=True)
        self.assertEqual(c.inactive_relics,['R06'])

    def test_unknown_relic_duplicate_and_slot_overflow_rejected(self):
        with self.assertRaises(NotImplementedError):Combat(['guard'],['F'],['R99'])
        with self.assertRaises(ValueError):Combat(['guard'],['F'],['R01','R01'])
        with self.assertRaises(ValueError):Combat(['guard'],['F'],['R01','R02','R04','R05'])

class BaselineCombatTests(unittest.TestCase):
    def test_old_six_baseline_outcomes_and_metrics_unchanged(self):
        baseline=json.loads((HERE/'baseline_v01/combat_subset_results.json').read_text())
        for original in baseline:
            test=next(test for test in TESTS if test['id']==original['test'])
            got=Combat(test['enemies'],**test[original['side']]).run()
            for key in ('outcome','time_s','hp_left','phantom_absorbed','healing_received_by_enemies',
                        'healing_denied','paper_used','enemies_left'):
                self.assertEqual(got[key],original[key],(original['test'],original['side'],key))

if __name__=='__main__':unittest.main(verbosity=2)
