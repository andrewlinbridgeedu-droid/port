"""Descriptive follow-up report; no retroactive acceptance gates."""
from pathlib import Path
import json, statistics

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/development/economy-agent-sim-20260926/followup'
manifest=json.loads((OUT/'manifest.json').read_text())
records=[json.loads(p.read_text()) for p in sorted(OUT.glob('*/summary.json'))]
expected={(c['name'],s) for c in manifest['configs'] for s in manifest['seeds']}
assert {(r['config']['name'],r['seed']) for r in records}==expected
rows=[]
for name in [c['name'] for c in manifest['configs']]:
    group=[r for r in records if r['config']['name']==name]
    row={'scenario':name,'seeds':len(group)}
    for key in ('free_fill_last90','free_cash_p10','advancement_wait_player_item_cycles','advancement_unpaid_eligible_items'):
        vals=[r[key] for r in group]
        row[key]={'mean':statistics.mean(vals),'min':min(vals),'max':max(vals)}
    row.update(issuance_mean=statistics.mean(sum(r['issuance'].values()) for r in group),
               repeat_issuance_mean=statistics.mean(r['issuance'].get('q_repeat',0) for r in group),
               sinks_mean=statistics.mean(sum(r['sinks'].values()) for r in group),
               advancement_sink_mean=statistics.mean(r['sinks'].get('advancement',0) for r in group),
               all_checks_pass=sum(r['all_checks_pass'] for r in group))
    rows.append(row)
(OUT/'research_summary.json').write_text(json.dumps(rows,indent=2)+'\n')
lines=['# 补充实验结果：晋阶采购与成熟服发行压力','',
       '已完成12次、每次2000账号×365周期。独立输出审计见 independent_audit.json；原220次不覆盖。本批次是额外研究，不能和旧批次混算成同一模型的重复验证。','',
       '| 情景 | 免费药品履约均值（种子范围） | 年发行铜币均值 | 其中重复关卡发行 | 年销毁均值 | 其中晋阶采购 |',
       '|---|---:|---:|---:|---:|---:|']
for r in rows:
    f=r['free_fill_last90']
    lines.append(f"| {r['scenario']} | {f['mean']:.2%}（{f['min']:.2%}–{f['max']:.2%}） | {r['issuance_mean']:,.0f} | {r['repeat_issuance_mean']:,.0f} | {r['sinks_mean']:,.0f} | {r['advancement_sink_mean']:,.0f} |")
lines+=['','## 解释边界','',
        'expense_supply2假设所有新手在Q17/20/23购买三材，忽略其它取得方式；初始老玩家已拥有。这是额外消费压力，不是完整晋阶流程模型。成熟服三个情景全员已首通、无新人，因此没有重复收取一次性晋阶费。',
        'mature_repeat3/10仅把每次活跃的Q30铜币乘3/10，没有补入对应战斗时间、药耗、维修；它们用于暴露发行规模，不是每小时净收入预测。相同种子不保证政策间完全相同随机路径。',
        '货币积累不等于同幅度涨价。本模型仍存在NPC固定价、有限购买意愿、价格上限及占位配方；药品履约通过不能证明金币有足够长期用途，也不能证明工匠赚钱。银行存款、托管和普通交易不是货币销毁。',
        f"完整旧门槛通过 {sum(r['all_checks_pass'] for r in rows)}/12；未为了新结果调整旧门槛。",'',
        '| 情景 | 晋阶等待玩家物品周期均值 | 期末已解锁未采购项均值 | 免费钱包P10均值 |',
        '|---|---:|---:|---:|']
for r in rows:
    lines.append(f"| {r['scenario']} | {r['advancement_wait_player_item_cycles']['mean']:.1f} | {r['advancement_unpaid_eligible_items']['mean']:.1f} | {r['free_cash_p10']['mean']:.1f} |")
lines+=['','等待数按每名玩家每项材料每次活跃重试累计，不是受阻玩家人数。其它必要费用、战斗失败和剧情资格没有补齐，不能据此保证完整剧情可负担。','',
        '下一轮问题及候选政策见 [研究说明](../NEXT_RESEARCH.md)。Pro本轮未连通，没有把本地判断写成外部共识。','']
(OUT/'RESULTS.md').write_text('\n'.join(lines))
print('\n'.join(lines))
