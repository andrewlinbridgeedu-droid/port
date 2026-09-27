import sys,types,unittest
from pathlib import Path
from run_shopping import REPLACEMENTS,PROFIT_OLD,PROFIT_NEW

def load(profit=False):
    name='shopping_profit_test' if profit else 'shopping_test'
    module=types.ModuleType(name);module.__file__=str(Path(__file__).with_name('model.py'));sys.modules[name]=module
    source=Path(module.__file__).read_text()
    for old,new in REPLACEMENTS+([(PROFIT_OLD,PROFIT_NEW)] if profit else []):
        assert source.count(old)==1;source=source.replace(old,new)
    exec(compile(source,module.__file__,'exec'),module.__dict__)
    return module

class SubstituteContracts(unittest.TestCase):
    def test_substitutes_cannot_multiply_purchase(self):
        m=load();s=m.Sim(m.Config(n=8),1);s.day=1;s.p[0].need=1
        s.p[1].inv[24]=1;s.p[2].inv[25]=1
        s.market([0,1,2],{24:[(0,1,100)],25:[(0,1,100)]},'products')
        self.assertEqual(sum(s.p[0].inv[24:28]),1)
    def test_can_buy_second_product_when_first_absent(self):
        m=load();s=m.Sim(m.Config(n=8),1);s.day=1;s.p[0].need=1;s.p[2].inv[25]=1
        s.market([0,1,2],{24:[(0,1,100)],25:[(0,1,100)]},'products')
        self.assertEqual(s.p[0].inv[25],1)
    def test_both_policies_keep_accounting(self):
        for profit in (False,True):
            m=load(profit);s=m.Sim(m.Config(n=40,days=150),17).run()
            self.assertTrue(all(x['money_error']==0 for x in s.days))
if __name__=='__main__':unittest.main()
