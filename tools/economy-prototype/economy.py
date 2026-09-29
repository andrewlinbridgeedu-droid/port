"""Executable economic contracts prototype, not a production server or game integration.
All money is integer copper. Only explicit mint creates money. Fixtures emulate
server-owned battle/delivery events; clients must never be allowed to create them.
"""
from dataclasses import dataclass
from collections import defaultdict
import random


class Ledger:
    def __init__(self, opening):
        self.cash = defaultdict(int, opening)
        self.opening = sum(opening.values())
        self.minted = 0
        self.receipts = {}
        self.events = []

    def transfer(self, source, target, amount, key):
        payload = ('transfer', source, target, amount)
        if key in self.receipts:
            if self.receipts[key] != payload:
                raise ValueError('receipt reused with changed payload')
            return False
        if not isinstance(amount, int) or amount < 0 or self.cash[source] < amount:
            raise ValueError('unfunded or invalid payment')
        self.cash[source] -= amount
        self.cash[target] += amount
        self.receipts[key] = payload
        self.events.append((key, *payload))
        assert self.cash[source] >= 0 and self.cash[target] >= 0
        return True

    def mint(self, target, amount, entitlement):
        payload = ('mint', target, amount)
        if entitlement in self.receipts:
            if self.receipts[entitlement] != payload:
                raise ValueError('changed entitlement')
            return False
        if not isinstance(amount, int) or amount < 0:
            raise ValueError('invalid mint')
        self.cash[target] += amount
        self.minted += amount
        self.receipts[entitlement] = payload
        self.events.append((entitlement, *payload))
        self.check()
        return True

    def check(self):
        assert all(v >= 0 for v in self.cash.values())
        assert sum(self.cash.values()) == self.opening + self.minted


@dataclass(frozen=True)
class WorkEvent:
    job: str
    worker: str
    kind: str
    target: str
    quantity: int
    receipt: str
    # This is a fixture trust boundary, NOT authentication implemented by Python.
    authority: str = 'server-fixture'


class Economy:
    def __init__(self):
        self.ledger = Ledger({'customers': 200000, 'industry': 100000,
                              'treasury': 960000, 'bank_equity': 1500,
                              'suppliers': 100000, 'foreign': 0})
        self.jobs = {}
        self.work_events = set()
        self.wages = 0
        self.inventory = {'fuel': 180000, 'steel': 18000}
        self.foreign_stock = {'fuel': 42000, 'steel': 6000}
        self.shipments = {}
        self.loans = {}
        self.deposits = {}
        self.projects = {}
        self.metrics = defaultdict(int)

    def post_job(self, jid, employer, wage, kind, target, quantity, deadline):
        spec = (employer, wage, kind, target, quantity, deadline)
        if jid in self.jobs:
            if self.jobs[jid]['spec'] != spec:
                raise ValueError('job identity collision')
            return
        self.ledger.transfer(employer, 'job:'+jid, wage, 'post:'+jid)
        self.jobs[jid] = dict(spec=spec, state='open', worker=None)

    def accept_job(self, jid, worker):
        job = self.jobs[jid]
        if job['state'] == 'accepted' and job['worker'] == worker:
            return
        if job['state'] != 'open':
            raise ValueError('job unavailable')
        job.update(state='accepted', worker=worker)

    def complete_job(self, event, day):
        job = self.jobs[event.job]
        employer, wage, kind, target, quantity, deadline = job['spec']
        if event.authority != 'server-fixture':
            raise ValueError('client assertion is not proof')
        if (event.worker, event.kind, event.target, event.quantity) != (job['worker'], kind, target, quantity):
            raise ValueError('wrong worker, objective or quantity')
        if job['state'] == 'paid':
            return False
        if job['state'] != 'accepted' or day > deadline or event.receipt in self.work_events:
            raise ValueError('expired, cancelled or reused work evidence')
        self.ledger.transfer('job:'+event.job, event.worker, wage, 'wage:'+event.job)
        job['state'] = 'paid'
        self.work_events.add(event.receipt)
        self.wages += wage
        self.metrics['verified_jobs'] += 1
        return True

    def cancel_job(self, jid):
        job = self.jobs[jid]
        if job['state'] in ('cancelled', 'paid'):
            return
        self.ledger.transfer('job:'+jid, job['spec'][0], job['spec'][1], 'cancel:'+jid)
        job['state'] = 'cancelled'

    def import_goods(self, sid, buyer, item, quantity, unit_price, day, delay=2):
        spec = (buyer, item, quantity, unit_price, day, delay)
        if sid in self.shipments:
            if self.shipments[sid]['spec'] != spec:
                raise ValueError('shipment identity collision')
            return
        if quantity <= 0 or delay < 1 or unit_price < 0 or self.foreign_stock[item] < quantity:
            raise ValueError('invalid shipment or finite stock exhausted')
        self.ledger.transfer(buyer, 'foreign', quantity*unit_price, 'import:'+sid)
        self.foreign_stock[item] -= quantity
        self.shipments[sid] = dict(spec=spec, delivered=False)

    def receive_shipments(self, day):
        for shipment in self.shipments.values():
            buyer, item, qty, price, placed, delay = shipment['spec']
            if not shipment['delivered'] and day >= placed+delay:
                self.inventory[item] += qty
                shipment['delivered'] = True

    def deposit(self, person, amount, receipt):
        if self.ledger.transfer(person, 'payment_reserve', amount, 'deposit:'+receipt):
            self.deposits[person] = self.deposits.get(person, 0)+amount
        self.check_bank()

    def withdraw(self, person, amount, receipt):
        key = 'withdraw:'+receipt
        payload = ('transfer', 'payment_reserve', person, amount)
        if key in self.ledger.receipts:
            if self.ledger.receipts[key] != payload:
                raise ValueError('withdrawal identity collision')
            return
        if amount > self.deposits.get(person, 0):
            raise ValueError('exceeds deposit')
        self.ledger.transfer('payment_reserve', person, amount, key)
        self.deposits[person] -= amount
        self.check_bank()

    def lend(self, lid, borrower, principal, interest, due, operations_reserve=72):
        if lid in self.loans:
            raise ValueError('duplicate loan')
        if principal < 0 or interest < 0 or self.ledger.cash['bank_equity']-principal < 200+operations_reserve:
            raise ValueError('loan breaches operating reserve')
        self.ledger.transfer('bank_equity', borrower, principal, 'loan:'+lid)
        self.loans[lid] = dict(borrower=borrower, principal=principal, interest=interest, due=due, settled=False)

    def settle_loan(self, lid):
        loan = self.loans[lid]
        if loan['settled']:
            return
        due = loan['principal']+loan['interest']
        payment = min(due, self.ledger.cash[loan['borrower']])
        self.ledger.transfer(loan['borrower'], 'bank_equity', payment, 'repay:'+lid)
        self.metrics['loan_loss'] += max(0, loan['principal']-payment)
        self.metrics['interest_received'] += max(0, payment-loan['principal'])
        loan['settled'] = True
        self.check_bank()

    def check_bank(self):
        assert self.ledger.cash['payment_reserve'] == sum(self.deposits.values())
        self.ledger.check()

    def start_bike_batch(self, pid, workers, day, borrow=False):
        """10-bike trial cost 1560: inputs780 + NPC labor660 + battle contract120.
        This is a NEW cost allocation fixture, not an approved player reward.
        No automatic salvage sale; successful revenue1600, margin40 before interest.
        """
        if pid in self.projects:
            raise ValueError('duplicate project')
        if len(workers) != 1 or self.inventory['steel'] < 80 or self.inventory['fuel'] < 80:
            raise ValueError('missing workers or real inputs')
        capital = 1160 if borrow else 1560
        if self.ledger.cash['industry'] < capital or self.ledger.cash['customers'] < 1600:
            raise ValueError('unfunded project or customer')
        if borrow and self.ledger.cash['bank_equity'] < 400+200+72:
            raise ValueError('bank unable to fund')
        self.ledger.transfer('customers', 'order:'+pid, 1600, 'order:'+pid)
        self.ledger.transfer('industry', 'project:'+pid, capital, 'capital:'+pid)
        if borrow:
            self.lend(pid, 'project:'+pid, 400, 40, day+5)
        self.inventory['steel'] -= 80
        self.inventory['fuel'] -= 80
        self.ledger.transfer('project:'+pid, 'suppliers', 780, 'inputs:'+pid)
        stages = [('battle_clear',120)]
        jids = []
        for i, ((kind, wage), worker) in enumerate(zip(stages, workers)):
            jid = f'{pid}:{i}'
            self.post_job(jid, 'project:'+pid, wage, kind, pid, 1, day+5)
            self.accept_job(jid, worker)
            jids.append(jid)
        self.projects[pid] = dict(jobs=jids, day=day, settled=False, borrow=borrow)

    def settle_project(self, pid, day):
        p = self.projects[pid]
        if p['settled']:
            return
        success = all(self.jobs[j]['state'] == 'paid' for j in p['jobs'])
        if not success and day <= p['day']+5:
            return
        if success and day < p['day']+5:
            return
        if success:
            self.ledger.transfer('project:'+pid, 'suppliers', 660, 'npc-labor:'+pid)
            self.ledger.transfer('order:'+pid, 'project:'+pid, 1600, 'sale:'+pid)
            self.metrics['bikes_delivered'] += 10
        else:
            self.ledger.transfer('order:'+pid, 'customers', 1600, 'refund:'+pid)
            for jid in p['jobs']:
                self.cancel_job(jid)
            self.metrics['projects_failed'] += 1
        if p['borrow']:
            self.settle_loan(pid)
        recovered = self.ledger.cash['project:'+pid]
        self.metrics['industry_profit'] += recovered-(1160 if p['borrow'] else 1560)
        self.ledger.transfer('project:'+pid, 'industry', recovered, 'close:'+pid)
        p['settled'] = True
        self.check_bank()


def simulate(seed=1, days=365, stress=False, workers_enabled=True):
    """Demand/participation fixtures, not observed player behavior or balance proof."""
    rng = random.Random(seed)
    e = Economy()
    people = [f'p{i}' for i in range(2000)]
    for p in people:
        e.ledger.mint(p, 5220 if stress else 180, 'initial:'+p)
    e.ledger.transfer('customers', 'depositor', 2000, 'deposit-funding')
    e.deposit('depositor', 2000, 'opening')
    rows = []
    for day in range(1, days+1):
        if stress:
            # Old accounts remain on the ledger; no wealth deletion or remint to old IDs.
            for i in range(20):
                p = f'new:{day}:{i}'
                people[(day*20+i) % 2000] = p
                e.ledger.mint(p, 5220, 'initial:'+p)
        e.receive_shipments(day)
        if day <= 14:
            try:
                e.import_goods(f'fuel:{day}', 'industry', 'fuel', 3000, 2, day)
            except ValueError:
                e.metrics['unfunded_imports'] += 1
        production = 300 if stress and 60 <= day <= 149 else 900
        # Domestic fuel is purchased, not a free daily inventory reset.
        affordable = min(production, e.ledger.cash['industry'])
        e.ledger.transfer('industry', 'suppliers', affordable, f'domestic:{day}')
        e.inventory['fuel'] += affordable
        demand = 1200 if stress else 600
        supplied = min(demand, e.inventory['fuel'], e.ledger.cash['customers'])
        e.ledger.transfer('customers', 'industry', supplied, f'fuel-sale:{day}')
        e.inventory['fuel'] -= supplied
        if supplied < demand:
            e.metrics['fuel_shortfall_days'] += 1
        if day % 10 == 1 and workers_enabled:
            pid = f'batch:{day}'
            try:
                e.start_bike_batch(pid, rng.sample(people, 1), day, borrow=(day % 30 == 1))
            except ValueError:
                e.metrics['rejected_projects'] += 1
        for pid, project in e.projects.items():
            if project['settled']:
                continue
            age = day-project['day']
            # Fixture emulates a daily completed milestone, not a timer-based wage.
            if 0 <= age < len(project['jobs']):
                jid = project['jobs'][age]
                j = e.jobs[jid]
                if not stress or rng.random() > 0.15:
                    event = WorkEvent(jid,j['worker'],j['spec'][2],pid,1,'e:'+jid)
                    e.complete_job(event,day)
                    e.complete_job(event,day)  # network retry fixture
            e.settle_project(pid,day)
        if day % 30 == 0:
            if e.ledger.cash['bank_equity'] >= 224:
                e.ledger.transfer('bank_equity','suppliers',24,f'bank-ops:{day}')
            else:
                e.metrics['bank_closed'] = 1
        if day == min(180,days):
            e.withdraw('depositor',2000,'all')
            e.withdraw('depositor',2000,'all')
        # Open service market: finite capacity, explicit cash expenditure.
        budgets = [(p,min(30,max(0,e.ledger.cash[p]-600)//200)) for p in people if rng.random()<0.35]
        spend = sum(b for p,b in budgets)
        index = max(1,spend/5000)
        for p,b in budgets:
            if b:
                e.ledger.transfer(p,'customers',b,f'service:{day}:{p}')
        e.check_bank()
        rows.append(dict(day=day,wages=e.wages,minted=e.ledger.minted,
                         service_index=index,fuel_shortfall=demand-supplied,
                         employer_cash=e.ledger.cash['industry'],
                         bank_cash=e.ledger.cash['bank_equity']))
    return dict(seed=seed,days=days,stress=stress,workers_enabled=workers_enabled,
                money_error=sum(e.ledger.cash.values())-e.ledger.opening-e.ledger.minted,
                wages=e.wages,service_index_peak=max(r['service_index'] for r in rows),
                jobs_open=sum(j['state'] in ('open','accepted') for j in e.jobs.values()),
                foreign_fuel_remaining=e.foreign_stock['fuel'],**e.metrics), rows
