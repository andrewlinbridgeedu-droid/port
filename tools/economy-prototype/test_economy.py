import unittest
from economy import Economy, WorkEvent

class ContractTests(unittest.TestCase):
    def test_no_timer_salary_and_verified_payment_once(self):
        e=Economy();e.post_job('j','industry',40,'battle_clear','pump',1,10)
        e.accept_job('j','player')
        self.assertEqual(e.ledger.cash['player'],0)
        for ev in [WorkEvent('j','player','battle_clear','wrong',1,'x'),
                   WorkEvent('j','other','battle_clear','pump',1,'x'),
                   WorkEvent('j','player','battle_clear','pump',1,'x','client')]:
            with self.assertRaises(ValueError):e.complete_job(ev,1)
        ev=WorkEvent('j','player','battle_clear','pump',1,'proof')
        self.assertTrue(e.complete_job(ev,1));self.assertFalse(e.complete_job(ev,1))
        self.assertEqual(e.ledger.cash['player'],40);e.ledger.check()

    def test_failed_job_refunds_and_no_double_accept(self):
        e=Economy();before=e.ledger.cash['industry']
        e.post_job('j','industry',40,'battle_clear','pump',1,1);e.accept_job('j','a')
        with self.assertRaises(ValueError):e.accept_job('j','b')
        with self.assertRaises(ValueError):e.complete_job(WorkEvent('j','a','battle_clear','pump',1,'e'),2)
        e.cancel_job('j');e.cancel_job('j')
        self.assertEqual(e.ledger.cash['industry'],before)

    def test_import_paid_finite_delayed_and_idempotent(self):
        e=Economy();stock=e.inventory['fuel'];cash=e.ledger.cash['industry']
        for _ in range(2):e.import_goods('s','industry','fuel',3000,2,1)
        self.assertEqual(e.ledger.cash['industry'],cash-6000)
        self.assertEqual(e.foreign_stock['fuel'],39000)
        e.receive_shipments(2);self.assertEqual(e.inventory['fuel'],stock)
        e.receive_shipments(3);e.receive_shipments(3)
        self.assertEqual(e.inventory['fuel'],stock+3000)
        with self.assertRaises(ValueError):e.import_goods('bad','empty','fuel',3000,2,4)
        self.assertEqual(e.foreign_stock['fuel'],39000);e.ledger.check()

    def test_full_deposit_withdrawal_despite_bad_loan(self):
        e=Economy();e.deposit('customers',2000,'d')
        with self.assertRaises(ValueError):e.lend('bad','p',1300,100,3)
        e.lend('l','p',1150,100,3)
        e.ledger.transfer('p','suppliers',1150,'spent')
        e.settle_loan('l');self.assertEqual(e.metrics['loan_loss'],1150)
        for _ in range(2):e.withdraw('customers',2000,'w')
        self.assertEqual(e.ledger.cash['payment_reserve'],0);e.check_bank()

    def test_project_wages_order_and_loan_share_one_ledger(self):
        e=Economy();e.start_bike_batch('p',['worker'],1,borrow=True)
        j=e.projects['p']['jobs'][0]
        e.complete_job(WorkEvent(j,'worker','battle_clear','p',1,'win'),1)
        e.settle_project('p',1);self.assertEqual(e.metrics['bikes_delivered'],0)
        e.settle_project('p',6);e.settle_project('p',6)
        self.assertEqual(e.metrics['bikes_delivered'],10)
        self.assertEqual(e.wages,120)
        self.assertEqual(e.metrics['interest_received'],40)
        self.assertEqual(e.metrics['industry_profit'],0)
        e.check_bank()

    def test_failed_project_refunds_customer_and_cannot_mint(self):
        e=Economy();money=e.ledger.cash['customers'];e.start_bike_batch('p',['w'],1,borrow=True)
        e.settle_project('p',7)
        self.assertEqual(e.ledger.cash['customers'],money)
        self.assertEqual(e.wages,0);self.assertEqual(e.metrics['bikes_delivered'],0)
        self.assertEqual(e.metrics['industry_profit'],-820);e.ledger.check()

if __name__=='__main__':unittest.main()
