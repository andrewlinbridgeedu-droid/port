import sys, types, unittest
from pathlib import Path
from run_followup import build

def variant():
    _, source, _, _ = build()
    m = types.ModuleType('followup_test')
    m.__file__ = str(Path(__file__).with_name('model.py'))
    sys.modules[m.__name__] = m
    exec(compile(source, m.__file__, 'exec'), m.__dict__)
    return m

class ExpenseContracts(unittest.TestCase):
    def test_owned_materials_cannot_be_bought_twice(self):
        m=variant();s=m.Sim(m.Config(n=8,days=20,veterans=0,newcomers=0,expense_stress=True),101)
        for a in s.p:
            a.q=30;a.cash=10000;a.activity=.99
        s.open_money=s.total_money()
        s.run()
        self.assertEqual(s.sinks['advancement'],8*1080)
        self.assertTrue(all(a.advancement=={17,20,23} for a in s.p))
        self.assertTrue(all(r['money_error']==0 for r in s.days))

    def test_cash_shortfall_does_not_grant_or_overdraw(self):
        m=variant();s=m.Sim(m.Config(n=8,days=5,veterans=0,newcomers=0,expense_stress=True,allowance=0,pass_extra=0,repeat_rate=0,tower_rate=0),101)
        for a in s.p:
            a.q=30;a.cash=0;a.activity=.99;a.bounty=set(range(10))
        s.open_money=s.total_money()
        s.run()
        self.assertEqual(s.sinks['advancement'],0)
        self.assertTrue(all(not a.advancement and a.advancement_wait>0 for a in s.p))
        self.assertTrue(all(a.cash==0 for a in s.p))

    def test_mature_issuance_matches_active_cycles(self):
        m=variant();s=m.Sim(m.Config(n=20,days=10,veterans=1,newcomers=0,repeat_count=3,repeat_rate=1,repeat_strategy='best',expense_stress=True),101).run()
        self.assertEqual(s.issue['q_repeat'],sum(a.active_days for a in s.p)*315)
        self.assertEqual(s.sinks['advancement'],0)

if __name__=='__main__':unittest.main()
