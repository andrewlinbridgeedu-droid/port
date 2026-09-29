"""Reference event purchase contract; independent of game and Pro market model."""
from dataclasses import dataclass, field
from copy import deepcopy
import json

@dataclass
class Event:
    budget:int
    demand:dict
    prices:dict
    phase:str='active'
    delivered:dict=field(default_factory=dict)
    receipts:dict=field(default_factory=dict)

    def sell(self, request, player, item, qty, wallet, inventory):
        args=(player,item,qty)
        if request in self.receipts:
            assert self.receipts[request]['args']==args,'idempotency key reused with different payload'
            return self.receipts[request]
        assert self.phase=='active'
        assert isinstance(qty,int) and qty>0
        assert item in self.demand and item in self.prices
        assert self.delivered.get(item,0)+qty<=self.demand[item]
        assert inventory.get((player,item),0)>=qty
        payment=self.prices[item]*qty
        assert payment<=self.budget
        # All validations precede state mutation; SQLite transaction required in game.
        self.budget-=payment;wallet[player]=wallet.get(player,0)+payment
        inventory[player,item]-=qty;self.delivered[item]=self.delivered.get(item,0)+qty
        receipt={'args':args,'payment':payment};self.receipts[request]=receipt
        if self.delivered==self.demand:self.phase='completed'
        return receipt

def check():
    e=Event(100,{'part':2},{'part':30});w={'a':0,'b':0};inv={('a','part'):3,('b','part'):3}
    r=e.sell('one','a','part',1,w,inv)
    for _ in range(10):assert e.sell('one','a','part',1,w,inv)==r
    assert (w['a'],inv['a','part'],e.delivered['part'])==(30,2,1)
    before=deepcopy((e,w,inv))
    try:e.sell('one','b','part',1,w,inv)
    except AssertionError:pass
    else:raise AssertionError('payload collision accepted')
    assert (e,w,inv)==before
    e.sell('two','b','part',1,w,inv)
    before=deepcopy((e,w,inv))
    try:e.sell('three','a','part',1,w,inv)
    except AssertionError:pass
    else:raise AssertionError('sold beyond remaining demand')
    assert (e,w,inv)==before
    assert e.budget+sum(w.values())==100
    assert sum(inv.values())+sum(e.delivered.values())==6
    poor=Event(1,{'part':1},{'part':30});before=deepcopy((poor,w,inv))
    try:poor.sell('poor','a','part',1,w,inv)
    except AssertionError:pass
    else:raise AssertionError('unfunded payment')
    assert (poor,w,inv)==before
    return dict(passed=['duplicate receipt x10','payload collision','last unit cannot be resold','money conservation','material conservation','insufficient funds causes no partial mutation'],scope='sequential in-memory reference only; no SQLite, concurrency, crash, price or multiplayer validation')
if __name__=='__main__':print(json.dumps(check(),indent=2))
