import unittest
from campaign_model import Config,Sim


class CampaignTests(unittest.TestCase):
    def test_full_chain_money_inventory_and_provenance(self):
        s=Sim(Config(n=80,days=30,war=True,campaign_starts=(12,25)),101)
        r=s.run()
        self.assertEqual(len(r['events']),2)
        self.assertGreater(sum(s.produced.values()),0)
        self.assertEqual(r['end_money'],r['opening_money']+sum(r['mint'].values())-sum(r['outflow'].values()))
        for key,q in s.first_sold.items():self.assertLessEqual(q,s.produced[key])
        for row in s.daily:
            for plan in ('free','paid'):
                self.assertEqual(row[plan+'_demand'],sum(row[plan+'_'+k] for k in ('craft_used','event_craft_used','guarantee_used','unmet')))

    def test_import_one_cycle_lag_and_shared_wallet(self):
        s=Sim(Config(n=8),101);stock=list(s.base);s.import_goods()
        self.assertEqual(s.base,stock)
        self.assertEqual(s.merchant,250)
        self.assertEqual(s.transit,[20,30,40,80])
        s.import_goods()
        self.assertEqual(s.base,[40,60,80,160])
        self.assertGreaterEqual(s.merchant,0)
        s.audit()

    def test_policy_preserves_exogenous_activity_and_consumption(self):
        a=Sim(Config(n=40,days=14,cash_window=0),211);b=Sim(Config(n=40,days=14,cash_window=7),211)
        a.run();b.run()
        self.assertEqual([r['active'] for r in a.daily],[r['active'] for r in b.daily])
        self.assertEqual([r['free_demand']+r['paid_demand'] for r in a.daily],
                         [r['free_demand']+r['paid_demand'] for r in b.daily])
        self.assertGreater(a.mint['q30_repeat'],b.mint['q30_repeat'])

    def test_authorization_is_not_double_minted_on_procurement(self):
        s=Sim(Config(n=40,days=15,war=True,procurement_mint=True,campaign_starts=(12,)),307)
        r=s.run()
        self.assertEqual(r['mint']['procurement_authorization'],6000)
        self.assertGreaterEqual(r['investment_paid'],r['investment_refunded'])
        self.assertTrue(all(t['gross']==t['fee']+t['seller_net'] for t in s.trades))

    def test_resale_does_not_count_twice(self):
        s=Sim(Config(n=4),101);a=s.p[0];a.inv[12]=4;a.lots[12].append([4,2.,0,0,False])
        s.created[12]=4;s.produced[(0,12)]=4
        s.trade(0,1,12,2,'test');s.trade(1,2,12,2,'test')
        self.assertEqual(s.first_sold[(0,12)],2)
        s.audit()
