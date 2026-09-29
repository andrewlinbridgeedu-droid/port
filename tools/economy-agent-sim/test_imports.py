import sys,types,unittest
from pathlib import Path
from run_imports import variant
def load():
    _,source,_=variant();m=types.ModuleType('imports_test');m.__file__=str(Path(__file__).with_name('model.py'));sys.modules[m.__name__]=m
    exec(compile(source,m.__file__,'exec'),m.__dict__);return m
class ImportsTests(unittest.TestCase):
    def test_finite_imports_retire_money_without_crediting_npc(self):
        m=load();s=m.Sim(m.Config(n=8),1);s.day=1;s.npc[0]=25
        before=s.total_money();resource=s.npc[1];s.production()
        self.assertEqual(before-s.total_money(),24)
        self.assertEqual(s.sinks['external_import'],24)
        self.assertEqual(s.npc[1],resource)
        self.assertEqual(s.npc[0],1)
    def test_batch_conservation_and_fee_once(self):
        m=load();s=m.Sim(m.Config(n=20,days=150,leather_batch=6),101).run()
        self.assertEqual(s.sinks['craft'],2*sum(a.crafts for a in s.p))
        for a in s.p:self.assertLessEqual(max(a.inv[16:20]),8)
        self.assertEqual(sum(s.created[16:20]),6*sum(a.crafts for a in s.p if a.prof==1))
        self.assertTrue(all(x['money_error']==0 for x in s.days))
    def test_product_sale_uses_recorded_basis(self):
        m=load();s=m.Sim(m.Config(n=8),101);s.day=1
        s.p[1].inv[16]=3;s.p[1].unit_basis[4]=4
        self.assertTrue(s.transfer_good(0,1,16,2,6))
        self.assertEqual(s.p[1].sold_opportunity_cost,8)
        self.assertEqual(s.p[1].craft_sold_units,2)
        self.assertEqual(s.p[0].unit_basis[4],6)
        self.assertTrue(s.transfer_good(2,0,16,1,7))
        self.assertEqual(s.p[0].sold_opportunity_cost,6)
if __name__=='__main__':unittest.main()
