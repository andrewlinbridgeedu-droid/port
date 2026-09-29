import unittest
from model import Config,Sim,SOURCE

class Contracts(unittest.TestCase):
    def test_source_contracts(self):
        self.assertEqual(sum(SOURCE['q_first']),2280)
        self.assertEqual(sum(SOURCE['tower_first']),1700)
        self.assertEqual(sum(x['copper'] for x in SOURCE['bounty']),1060)
        self.assertEqual(SOURCE['q_repeat'][-1],105)
        self.assertEqual(len(SOURCE['tower']),100)
    def test_poor_buyer_cannot_use_rich_wallet(self):
        s=Sim(Config(n=8),1);s.day=1
        s.p[0].cash=1;s.p[1].cash=100000;s.p[2].inv[0]=1
        before=[a.cash for a in s.p]
        self.assertFalse(s.transfer_good(0,2,0,1,6))
        self.assertEqual(before,[a.cash for a in s.p])
    def test_trade_records_execution_price_and_conserves(self):
        s=Sim(Config(n=8),1,True);s.day=1;s.p[1].inv[0]=10
        before=s.total_money()
        self.assertTrue(s.transfer_good(0,1,0,3,7))
        s.ref[0]=1000
        self.assertEqual(s.trade_examples[0]['gross'],21)
        self.assertEqual(s.total_money()+sum(s.sinks.values()),before)
        self.assertEqual(s.p[0].inv[0],3)
        self.assertEqual(s.p[1].inv[0],7)
        self.assertFalse(s.transfer_good(1,1,0,1,7))
    def test_finite_escrow(self):
        s=Sim(Config(n=8),1);s.day=1;s.npc[3]=5;s.p[1].inv[24]=10
        self.assertFalse(s.transfer_good(11,1,24,1,24))
        self.assertEqual(s.npc[3],5)
    def test_last_item_cannot_be_sold_twice(self):
        s=Sim(Config(n=8),1);s.day=1;s.p[2].inv[0]=1
        self.assertTrue(s.transfer_good(0,2,0,1,6))
        self.assertFalse(s.transfer_good(1,2,0,1,6))
        self.assertEqual(s.p[1].inv[0],0)
    def test_failure_refunds_without_free_capacity(self):
        s=Sim(Config(n=40,days=1),1)
        s.npc[2]-=100;s.npc[3]+=100
        s.event=dict(kind='pump',start=1,end=1,req={0:10000},filled={0:0},budget=100,spent=0,combat=0,combat_req=100000,contributors={})
        s.run()
        self.assertFalse(s.pump)
        self.assertEqual(s.npc[3],0)
        self.assertEqual(s.events[-1]['state'],'failure')
    def test_world_gate_does_not_unlock_all_professions(self):
        s=Sim(Config(n=8),1)
        for a in s.p:a.skill=100;a.xp=6000
        self.assertEqual(s.stage(s.p[0]),2)
        s.mist=True
        self.assertEqual(s.stage(s.p[0]),3)
        self.assertEqual(s.stage(s.p[1]),2)
    def test_seed_replay_and_long_accounting(self):
        c=Config(n=40,days=150)
        a=Sim(c,17).run();b=Sim(c,17).run()
        self.assertEqual(a.summary(),b.summary())
        self.assertLessEqual(a.issue['q_first'],40*2280)
        self.assertLessEqual(a.issue['tower_first'],40*1700)
        self.assertLessEqual(a.issue['bounty_first'],40*1060)
        self.assertTrue(all(x['money_error']==0 for x in a.days))
if __name__=='__main__':unittest.main()
