import itertools
import math
from pathlib import Path
import sys
import unittest

from model import config,engineering,allocation,contract,race,operate,money,q_issuance,run
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'economy-agent-sim'))
from campaign_core_race import exact_probabilities


def enumerate_race(caps,nodes,bosses,attendance):
    """Independent full binary tapes; dormant flips have weight 1/2."""
    out=dict(A=0.,B=0.,both=0.,neither=0.)
    for tape in itertools.product((0,1),repeat=sum(caps)):
        tapes=(tape[:caps[0]],tape[caps[0]:])
        stage=[0,0];weight=1.;outcome='neither';closed=False
        for wave in range(max(caps)):
            for i in (0,1):
                if wave>=caps[i]:continue
                bit=tapes[i][wave]
                if closed:
                    weight*=.5
                else:
                    p=attendance*(nodes[i] if stage[i]<3 else bosses[i])
                    weight*=p if bit else 1-p
                    stage[i]+=bit
            if not closed:
                if min(stage)>=4:outcome='both';closed=True
                elif stage[0]>=4:outcome='A';closed=True
                elif stage[1]>=4:outcome='B';closed=True
        out[outcome]+=weight
    return out


class ModelTests(unittest.TestCase):
    def test_uniform_matches_existing_exact_fraction_model(self):
        for caps in itertools.product((0,4,5,6),repeat=2):
            for p in (.35,.5,.65):
                actual,_=race(caps,(p,p),(p,p),1)
                expected=exact_probabilities(caps,p,p)
                for k in actual:self.assertAlmostEqual(actual[k],float(expected[k]),12)

    def test_different_node_and_boss_rates_against_full_tapes(self):
        for caps in ((6,4),(5,5),(0,6),(6,6)):
            actual,_=race(caps,(.4,.8),(.7,.2),.85)
            expected=enumerate_race(caps,(.4,.8),(.7,.2),.85)
            for k in actual:self.assertAlmostEqual(actual[k],expected[k],11)

    def test_same_wave_dual_death(self):
        r,starts=race((6,6),(1,1),(1,1),1)
        self.assertEqual(r['both'],1);self.assertEqual(starts,8)

    def test_zero_attendance(self):
        r,starts=race((6,4),(1,1),(1,1),0)
        self.assertEqual(r['neither'],1);self.assertEqual(starts,0)

    def test_impossible_duel(self):
        r,_=race((6,6),(1,1),(0,0),1)
        self.assertEqual(r['neither'],1)

    def test_funding_and_materials_both_required(self):
        self.assertEqual(engineering(1200,8,40)['installed'],8)
        self.assertEqual(engineering(400,12,40)['installed'],10)
        self.assertFalse(engineering(1200,12,110)['ready'])

    def test_qualification_and_candidates(self):
        self.assertEqual(allocation((20,3),(20,6),(True,True)),((6,0),'A',(True,False)))
        self.assertEqual(allocation((4,10),(8,10),(True,False)),((4,0),'A',(True,False)))
        self.assertEqual(allocation((6,6),(6,6),(True,True)),((5,5),None,(True,True)))

    def test_public_winner_survives_no_kill(self):
        self.assertEqual(contract('neither','A',(True,True)),'A')
        self.assertEqual(contract('neither',None,(True,True)),'interim')
        self.assertEqual(contract('B','A',(True,True)),'B')
        self.assertEqual(contract('both','A',(True,True)),'interim')

    def test_original_cash_example(self):
        r=operate(config(),'a');first=r['rows'][0]
        self.assertEqual(first['project'],650)
        self.assertEqual(first['distribution'],50)
        self.assertEqual(first['buyers'],5800)
        self.assertEqual(r['net_if_wins'],2400)
        self.assertEqual(r['conservation_error'],0)

    def test_no_demand_no_income(self):
        r=operate(config({'orders_a':0}),'a')
        self.assertEqual(r['fulfilled'],0)
        self.assertEqual(r['dividends'],0)
        self.assertEqual(r['net_if_wins'],-600)

    def test_finite_wallet_inputs_and_no_phantom_batches(self):
        r=operate(config({'buyer_budget':210,'orders_a':100}),'a')
        self.assertEqual(r['fulfilled'],50)
        self.assertEqual(r['buyers_left'],10)
        self.assertEqual(r['operating_days'],1)
        self.assertEqual(operate(config({'raw_capacity':24}),'a')['fulfilled'],0)

    def test_underfunded_commission_no_negative_cash(self):
        r=operate(config({'funding_a':480}),'a')
        self.assertFalse(r['can_start']);self.assertEqual(r['refund_if_wins'],0)
        self.assertEqual(r['dividends'],0)

    def test_guard_avoids_unfunded_commission_not_construction_loss(self):
        r=operate(config({'orders_a':0,'launch_guard':True}),'a')
        self.assertFalse(r['can_start']);self.assertEqual(r['net_if_wins'],-480)
        r=operate(config({'orders_a':30,'launch_guard':True}),'a')
        self.assertTrue(r['can_start']);self.assertEqual(r['prebook_net'],140)
        r=operate(config({'orders_a':50,'buyer_budget':200,'launch_guard':True}),'a')
        self.assertFalse(r['can_start']);self.assertEqual(r['prebook_net'],100)

    def test_project_grid_conservation(self):
        for price,demand,wallet in itertools.product((20,40,60,100),(0,24,30,50),(0,400,6000)):
            r=operate(config({'kit_price':price,'orders_a':demand,'buyer_budget':wallet}),'a')
            self.assertAlmostEqual(r['conservation_error'],0)
            self.assertGreaterEqual(r['buyers_left'],0)
            self.assertGreaterEqual(r['refund_if_wins'],0)

    def test_calendar_claims_are_not_dau_divided_by_seven(self):
        p=config({'dau':.5})
        self.assertEqual(q_issuance(p,7,7),2000*105*(1-.5**7))
        self.assertGreater(q_issuance(p,365,7),q_issuance(p,365,1)/7)
        self.assertEqual(q_issuance(config({'dau':1}),14,7),2000*105*2)

    def test_partial_window_and_no_activity(self):
        p=config({'dau':1})
        self.assertEqual(q_issuance(p,1,14),2000*105)
        self.assertEqual(q_issuance(p,15,14),2000*105*2)
        self.assertEqual(money(config({'dau':0}),365,7)['net'],0)
        self.assertEqual(money(p,0,7)['net'],0)

    def test_same_dau_can_have_different_unique_claimants(self):
        rotating=config({'dau':.5})
        fixed=config({'dau':.5,'fixed_active_cohort':True})
        self.assertEqual(q_issuance(fixed,7,7),1000*105)
        self.assertGreater(q_issuance(rotating,7,7),q_issuance(fixed,7,7))
        self.assertEqual(q_issuance(rotating,365,1),q_issuance(fixed,365,1))

    def test_new_accounts_and_transfer_classification(self):
        base=config({'dau':0,'fresh':5})
        self.assertEqual(money(base,365,7)['net'],5*365*4140)
        base['newcomer_sink']=False
        self.assertEqual(money(base,365,7)['net'],5*365*5220)
        p=config();a=money(p,365,7);p['external_sink']=False;b=money(p,365,7)
        self.assertAlmostEqual(b['net']-a['net'],a['material_payments'])

    def test_zero_population_participation_and_repeatability(self):
        p={'participants':0,'trials':200}
        r=run(p);self.assertEqual(r['event']['outcomes']['interim'],1)
        self.assertEqual(run({'trials':200}),run({'trials':200}))

    def test_reject_invalid_inputs(self):
        for p in ({'dau':float('nan')},{'participants':-1},{'players':1,'participants':2},
                  {'kit_price':0},{'seed':.5},{'dau':True},{'unknown':1},{'external_sink':1}):
            with self.assertRaises(ValueError):config(p)


if __name__=='__main__':unittest.main()
