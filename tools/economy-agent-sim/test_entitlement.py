import sys,types,unittest
from pathlib import Path
from run_entitlement import variant

class EntitlementTests(unittest.TestCase):
    def test_fixed_blocks_and_no_duplicate_cash(self):
        _,src,_=variant();m=types.ModuleType('entitlement_test');m.__file__=str(Path(__file__).with_name('model.py'));sys.modules[m.__name__]=m
        exec(compile(src,m.__file__,'exec'),m.__dict__)
        for window,expected in ((0,15),(7,3),(14,2)):
            s=m.Sim(m.Config(n=8,days=15,veterans=1,newcomers=0,repeat_rate=1,repeat_strategy='best',repeat_window=window),101)
            for a in s.p:a.activity=1
            s.run()
            self.assertEqual(s.issue['q_repeat'],8*105*expected)
            self.assertTrue(all(r['money_error']==0 for r in s.days))
    def test_missed_blocks_are_not_back_paid(self):
        _,src,_=variant();m=types.ModuleType('entitlement_gap_test');m.__file__=str(Path(__file__).with_name('model.py'));sys.modules[m.__name__]=m
        exec(compile(src,m.__file__,'exec'),m.__dict__)
        s=m.Sim(m.Config(n=8,days=15,veterans=1,newcomers=0,repeat_rate=1,repeat_strategy='best',repeat_window=7),101);s.allowance_claim={}
        for a in s.p:a.activity=0
        for day in range(1,15):s.step(day)
        for a in s.p:a.activity=1
        s.step(15)
        self.assertEqual(s.issue['q_repeat'],8*105)

if __name__=='__main__':unittest.main()
