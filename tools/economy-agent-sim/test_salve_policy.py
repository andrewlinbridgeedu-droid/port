import unittest
from salve_policy import Wallet, Ledger, satisfy, buy_guarantee, transfer_crafted, deliver_event


class SalvePolicyTests(unittest.TestCase):
    def test_pro_example_and_money_conservation(self):
        a,b,l = Wallet(55*30),Wallet(0,crafted=40),Ledger()
        # Forty existing crafted doses, then fifty-five affordable system doses.
        a.crafted,b.crafted=40,0
        initial=a.cash+b.cash
        r=satisfy(a,100,l)
        self.assertEqual((r['craft_fill'],r['guarantee_fill'],r['total_fill']),(.4,.55,.95))
        self.assertEqual(r['unmet_affordability'],5)
        self.assertEqual(a.cash+b.cash+l.system_retired+l.trade_retired,initial)
        self.assertEqual(l.player_sales,0)  # Consumption is not a new sale.

    def test_binding_and_zero_inventory(self):
        a,b,l=Wallet(60),Wallet(100),Ledger()
        self.assertTrue(buy_guarantee(a,l))
        self.assertFalse(buy_guarantee(a,l))
        self.assertFalse(transfer_crafted(a,b,1,16,l))
        self.assertFalse(deliver_event(a,1))
        self.assertEqual(a.system_bound,1)

    def test_rational_alternative_and_access(self):
        seller,l=Wallet(0,crafted=3),Ledger()
        a=Wallet(50)
        r=satisfy(a,1,l,[(seller,40)])
        self.assertEqual(r['guarantee_used'],1)
        self.assertEqual(seller.crafted,3)
        b=Wallet(50,shop_unlocked=False)
        r=satisfy(b,1,l,[(seller,40)])
        self.assertEqual(r['craft_used'],1)  # 30 is not a universal market price cap.

    def test_fee_remainder_and_no_duplicate_sale(self):
        a,b,l=Wallet(64),Wallet(0,crafted=4),Ledger()
        r=satisfy(a,4,l,[(b,16)])
        self.assertEqual((l.player_gross,l.player_sales,l.trade_retired),(64,4,3))
        self.assertEqual(a.cash+b.cash+l.trade_retired,64)
        self.assertEqual(r['total_fill'],1)

    def test_legacy_and_zero_demand(self):
        a,l=Wallet(0,legacy_unknown=1),Ledger()
        r=satisfy(a,1,l)
        self.assertEqual((r['legacy_used'],r['craft_used']),(1,0))
        self.assertIsNone(satisfy(a,0,l)['total_fill'])

    def test_access_is_not_affordability(self):
        r=satisfy(Wallet(100,shop_unlocked=False),1,Ledger())
        self.assertEqual(r['unmet_access_or_supply'],1)
        self.assertEqual(r['unmet_affordability'],0)
