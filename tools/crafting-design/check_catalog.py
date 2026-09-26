"""Enumerate finite design recipes. This validates data, not game integration."""
import itertools,json,sys
from pathlib import Path

def enumerate_recipe(catalog, recipe):
    materials=catalog['materials']; solutions=[]
    base_material=recipe['baseMaterial']
    assert base_material['id'] in materials and base_material['quantity']>0
    assert len(recipe['base'])==len(recipe['required'])==3
    for selections in itertools.product(*recipe['slots']):
        for process in recipe['processes']:
            raw=list(recipe['base']); tags=set(); cost=0
            for option in selections:
                if option is None: continue
                mid=option['id'] if isinstance(option,dict) else option
                qty=option.get('quantity',1) if isinstance(option,dict) else 1
                assert isinstance(qty,int) and qty>0
                m=materials[mid]
                effect=recipe.get('materialEffects',{}).get(mid,m)
                raw=[a+b*qty for a,b in zip(raw,effect['stats'])]
                tags.update(effect.get('tags',[]));cost+=m.get('referenceCost',0)*qty
            pr=catalog['processes'][process]
            raw=[a+b for a,b in zip(raw,pr['stats'])]
            tags.update(pr.get('addTags',[]));tags.difference_update(pr.get('removeTags',[]))
            stats=[min(9,max(0,v)) for v in raw]
            if any(a<b for a,b in zip(stats,recipe['required'])):continue
            if any(a>b for a,b in zip(stats,recipe.get('maximum',[9,9,9]))):continue
            if tags.intersection(recipe.get('forbiddenTags',[])):continue
            if not set(recipe.get('requiredTags',[])).issubset(tags):continue
            solutions.append(dict(materials=selections,process=process,stats=stats,tags=sorted(tags),referenceCost=cost))
    return sorted(solutions,key=lambda x:(x['referenceCost'],str(x['materials']),x['process']))

def check(catalog):
    report={}
    for r in catalog['recipes']:
        solutions=enumerate_recipe(catalog,r)
        assert len(solutions)>=r.get('minSolutions',2),r['id']+' has too few solutions'
        report[r['id']]={'solutionCount':len(solutions),'examples':solutions[:3]}
    for o in catalog.get('orders',[]):
        source=next(r for r in catalog['recipes'] if r['id']==o['recipe'])
        rule={**source,**o.get('acceptance',{})}
        solutions=enumerate_recipe(catalog,rule)
        assert len(solutions)>=2,o['id']+' has too few solutions'
        report[o['id']]={'solutionCount':len(solutions),'examples':solutions[:2]}
    return report

if __name__=='__main__':
    print(json.dumps(check(json.loads(Path(sys.argv[1]).read_text())),ensure_ascii=False,indent=2))
