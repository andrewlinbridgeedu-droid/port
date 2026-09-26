#!/usr/bin/env python3
"""一键复现本设计中实际运行过的检查；仅使用标准库。"""
from pathlib import Path
from itertools import product
from collections import Counter
import argparse, json, subprocess, sys
from validate_s9 import allocation_path
from combat_subset import Combat, TESTS

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--outdir',type=Path,default=Path(__file__).parent/'results')
    args=parser.parse_args(); args.outdir.mkdir(parents=True,exist_ok=True)
    here=Path(__file__).resolve().parent
    for script in ['validate_s9.py','combat_subset.py']:
        subprocess.run([sys.executable,str(here/script),'--outdir',str(args.outdir)],check=True,capture_output=True,text=True)
    counts=Counter()
    for vector in product(range(6),repeat=6):
        try:allocation_path(list(vector))
        except ValueError:continue
        counts[sum(vector)]+=1
    result={'scope':'单系全部46656种配点向量，仅验证可达性',
            'valid_vectors':sum(counts.values()),'by_points':dict(sorted(counts.items()))}
    (args.outdir/'allocation_exhaustive.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    matrix=[]
    for label,hp,scale in [('baseline',2400,1.0),('hp_minus_5pct',2280,1.0),('correct_ap_minus_5pct',2400,0.95)]:
        for test in TESTS:
            for side in ['correct','wrong']:
                params=dict(test[side]); params['ap']*=scale if side=='correct' else 1.0
                result=Combat(test['enemies'],hp=hp,**params).run()
                matrix.append({'variation':label,'test':test['id'],'side':side,'hp_start':hp,'ap':params['ap'],**result})
    (args.outdir/'sensitivity.json').write_text(json.dumps(matrix,ensure_ascii=False,indent=2),encoding='utf-8')
    assert all(x['outcome']==('胜利' if x['side']=='correct' else '失败') for x in matrix)
    print(f'17项定向检查通过；单系合法配点{sum(counts.values())}种；9套20秒调度已导出；3组机制对照及两种敏感性变化符合记录结果。输出：{args.outdir}')
if __name__=='__main__':main()
