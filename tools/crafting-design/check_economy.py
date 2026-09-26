"""Small design accounting checks; NOT runtime transaction or server tests."""
import json
from pathlib import Path

def check(data):
    orders=data['orders']
    catalog=json.loads(Path(__file__).with_name('catalog.json').read_text())
    assert orders==catalog['orders'], 'duplicate order tables diverged'
    assert len({o['id'] for o in orders})==len(orders)==12
    paid=sum(o['wage'] for o in orders)
    assert paid<=400
    merchant=data['initialMerchantCash']
    for scroll in data['scrolls']:
        assert 0<=scroll['buyback']<scroll['price']
        # One buy/return cycle cannot increase player wealth or world money.
        player=scroll['price']; initial=player+merchant
        player-=scroll['price']; merchant+=scroll['price']
        player+=scroll['buyback']; merchant-=scroll['buyback']
        assert player+merchant==initial
        assert player<scroll['price']
    for supply in data['baseSupply']:
        assert 0 < supply['restockPerThreeClaims'] <= supply['cap']
        assert supply['initial'] <= supply['cap'] and supply['price']>0
    return {'orderCount':len(orders),'maximumOrderWages':paid,
            'initialMerchantCash':data['initialMerchantCash'],'moduleMaximumNetTransfer':paid+data['initialMerchantCash'],
            'scope':'finite local module; excludes old rewards and all price stability claims'}

if __name__=='__main__':
    print(json.dumps(check(json.loads(Path(__file__).with_name('economy.json').read_text())),ensure_ascii=False,indent=2))
