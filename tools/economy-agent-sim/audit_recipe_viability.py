"""Static unit-economics audit of experimental recipes, not realized profit."""
from pathlib import Path
import hashlib,json,math
from model import RECIPES,P0,PROFS

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/development/economy-agent-sim-20260926/recipe-viability'
OUT.mkdir(parents=True,exist_ok=True)
rows=[]
for idx,recipe in enumerate(RECIPES):
    prof,tier=divmod(idx,4)
    base_cost=sum(P0[k]*q for k,q in recipe.items() if k>=8)+1
    opportunity=sum(P0[k]*q for k,q in recipe.items())+1
    ceiling=6+2*tier if prof==1 else None
    rows.append(dict(profession=PROFS[prof],tier=tier,
                     npc_base_and_craft_floor=base_cost,
                     initial_material_opportunity_cost=opportunity,
                     initial_product_quote=P0[12+idx],
                     break_even_gross_average_fee=math.ceil(opportunity/.95),
                     repair_saving_ceiling=ceiling,
                     repair_loss_even_zero_raw_and_zero_fee=ceiling is not None and ceiling<base_cost,
                     batch5_cost_per_output=opportunity/5 if prof==1 else None))
assert [r['npc_base_and_craft_floor'] for r in rows[4:8]]==[11]*4
assert [r['repair_loss_even_zero_raw_and_zero_fee'] for r in rows[4:8]]==[True,True,True,False]
assert rows[12]['initial_material_opportunity_cost']==23
result=dict(model_sha256=hashlib.sha256((Path(__file__).parent/'model.py').read_bytes()).hexdigest(),
            assumptions='One output per craft, posted NPC base prices, craft fee 1, initial raw reference prices, amortized 5% trading fee. Quotes are not executions. Batch5 is an untested candidate; no demand elasticity or behavior claimed.',rows=rows)
(OUT/'audit.json').write_text(json.dumps(result,indent=2)+'\n')
lines=['# 候选配方逐件经济核对','',
       '这是对占位模拟目录的静态核算，不是游戏实装，不是新增服务器仿真。零材料成本下的皮革亏损判断不依赖5%手续费舍入。','',
       '| 职业/档 | 底料+制作费下限 | 按初始材料报价的总成本 | 初始商品报价 | 5%平均费率下保本售价 | 维修节省上限 |',
       '|---|---:|---:|---:|---:|---:|']
for r in rows:
    lines.append(f"| {r['profession']}/{r['tier']} | {r['npc_base_and_craft_floor']} | {r['initial_material_opportunity_cost']} | {r['initial_product_quote']} | {r['break_even_gross_average_fee']} | {r['repair_saving_ceiling'] if r['repair_saving_ceiling'] is not None else '不适用'} |")
lines+=['','## 可确认的结论','',
        '- 皮革前三档：每件至少11铜现金投入，最多替理性买家省6/8/10铜。即使原材料机会成本为0、交易费为0，也没有持续盈利空间。首次训练收益、自用、有限事件采购可以解释个别制作，不能证明成熟职业可持续经营。',
        '- 皮革最高档维修上限12铜，但现模型未解锁该职业最高档；即使解锁也不能假定它足以补贴前三档。',
        '- 基础药膏按初始报价成本23铜，24铜售价扣平均5%费后为22.8铜，初始价格略低于保本。实际材料价和成交价会变，因此不能据此宣称所有药剂师实际亏损。',
        '- 织造和金属初始报价的纸面毛利较高，但装备每档只需要绑定一次，后期需求会减少；高报价不等于成交或稳定收入。',
        '- 整体药品履约通过不能代表四职业经济均已通过。后续必须增加每职业的实际净收益、销量、库存积压和练级支出指标。','',
        '## 待比较的修正，不直接实施','',
        '皮革可比较一批产出多份维修用品，或改为玩家确实需要的其它用途。若仍沿用单件维修价值，按初始材料价一批产出5件时，四档单位成本分别为5.2/5.2/7.6/9.6铜，低于相应节省上限；这只证明有潜在交易区间，不证明一定有人买或供需平衡。熟练度应按成功制作批次计入，不能因5件输出误发5次经验；消耗、货架上限、事件采购数量、利润判断均须同步按件/批明确计量。',
        '提高NPC维修价格来创造维修包需求会增加必需负担，本轮不采用；也不靠无限NPC回购救亏损配方。','']
(OUT/'RESULTS.md').write_text('\n'.join(lines))
print('\n'.join(lines))
