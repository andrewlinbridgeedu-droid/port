"""Report actual full-market runs; do not equate control to local-only Plan A."""
from pathlib import Path
import json,statistics
OUT=Path(__file__).resolve().parents[2]/'docs/development/economy-agent-sim-20260926/entitlement'
rows=[json.loads(p.read_text()) for p in OUT.glob('*/summary.json')]
manifest=json.loads((OUT/'manifest.json').read_text())
assert {(r['config']['name'],r['seed']) for r in rows}=={(c['name'],s) for c in manifest['configs'] for s in manifest['seeds']}
aggregate=[]
for name in ('cash_every_clear','cash_window7','cash_window14'):
    group=[r for r in rows if r['config']['name']==name]
    issuance=statistics.mean(sum(r['issuance'].values()) for r in group)
    sink=statistics.mean(sum(r['sinks'].values()) for r in group)
    aggregate.append(dict(name=name,q30_mean=statistics.mean(r['issuance']['q_repeat'] for r in group),
                          allowance_mean=statistics.mean(r['issuance'].get('free_allowance',0)+r['issuance'].get('pass_allowance',0) for r in group),
                          total_issuance=issuance,total_sink=sink,net_growth=issuance-sink,
                          free_fill_mean=statistics.mean(r['free_fill_last90'] for r in group),
                          free_fill_min=min(r['free_fill_last90'] for r in group),
                          free_fill_max=max(r['free_fill_last90'] for r in group),
                          free_cash_blocked_last90=sum(r['free_cash_blocked_last90'] for r in group),
                          free_cash_p10_mean=statistics.mean(r['free_cash_p10'] for r in group),
                          end_player_cash_mean=statistics.mean(r['end_player_cash'] for r in group),
                          end_npc_cash_mean=statistics.mean(sum(r['end_npc_cash']) for r in group),
                          full_gate_pass=sum(r['all_checks_pass'] for r in group)))
(OUT/'policy_comparison.json').write_text(json.dumps(aggregate,indent=2)+'\n')
lines=['# 每账号现金额度：9次实际模拟','',
       '2000成熟账号、无新人、365周期、活跃参数50%、月卡30%、每活跃周期一次合格Q30、双倍供给；三规则各3种子101/211/307。全部为离线共享市场实验，每次真实扣个人钱包、转移库存。每次发钱是共享压力控制组，不是Pro方案A的“关闭P2P”产品实现。','',
       '| 规则 | Q30年发行 | 生活补给年发行 | 总年发行 | 真销毁 | 年净增 | 免费药品履约 |',
       '|---|---:|---:|---:|---:|---:|---:|']
labels={'cash_every_clear':'每次105','cash_window7':'每7周期首次105','cash_window14':'每14周期首次105'}
for r in aggregate:
    lines.append(f"| {labels[r['name']]} | {r['q30_mean']:,.0f} | {r['allowance_mean']:,.0f} | {r['total_issuance']:,.0f} | {r['total_sink']:,.0f} | {r['net_growth']:,.0f} | {r['free_fill_mean']:.2%} |")
lines+=['','均为3种子均值，铜币四舍五入；净增是全服钱包变化，不是物价上涨率。','',
       '| 规则 | 免费履约种子范围 | 免费钱包P10均值 | 期末玩家铜币总量均值 | 期末NPC铜币总量均值 |',
       '|---|---:|---:|---:|---:|']
for r in aggregate:
    lines.append(f"| {labels[r['name']]} | {r['free_fill_min']:.2%}–{r['free_fill_max']:.2%} | {r['free_cash_p10_mean']:,.0f} | {r['end_player_cash_mean']:,.0f} | {r['end_npc_cash_mean']:,.0f} |")
lines+=['','## 规则和结论边界','',
        '- 周期按服务器固定日历分段，第一段第1–7或1–14周期；首次合格清关领取一次，未领取不补发，年末剩余短周期可领。不能将本结果用于“距上次领取冷却7天”或所有活跃账号每天必领的不同规则。',
        '- 7周期领取按周活跃账号计，不按日活人数除7。其发行高于Pro估算，不能据Pro的约987万总发行直接定案。',
        '- 三种规则均保留模拟内P2P及原NPC资金循环；没有把基础料采购重标成真销毁，也没有加Pro候选12+2铜成本。其它旧重复入口、迁服、新账号持续流入仍未建模；不能称为完整方案B验收。',
        '- 原有药品替代、成熟工匠预计利润和一人一专业等假设不变；皮革成本问题及耐用品需求饱和没有被本批掩盖或修正。',
        '- 年度净增下降不等于无通胀；原价格篮子仍可能缺交易，免费必需剧情成本及实际耗时不齐。不能凭药品履约通过就开放共享市场。',
        f"- 完整原门槛通过 {sum(r['full_gate_pass'] for r in aggregate)}/9；每日会计、成交额与一次性奖励上限另外独立审计。16项自动测试包括周期边界与未领不补发，均通过。",'',
        'Pro算式核对与27项活跃/周期/时长解析期望见 [复核](../pro-reconciliation/RESULTS.md)。本次不修改游戏规则、奖励、存档或付费权益。','']
(OUT/'RESULTS.md').write_text('\n'.join(lines))
print('\n'.join(lines))
