"""Reconcile supplied Pro arithmetic and exact expected fixed-window claims."""
from pathlib import Path
import json,statistics
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/development/economy-agent-sim-20260926/pro-reconciliation'
OUT.mkdir(parents=True,exist_ok=True)
records=[json.loads(p.read_text()) for p in (OUT.parent/'followup').glob('mature_repeat1-*/summary.json')]
assert len(records)==3
total=statistics.mean(sum(r['issuance'].values()) for r in records)
repeat=statistics.mean(r['issuance']['q_repeat'] for r in records)
sink=statistics.mean(sum(r['sinks'].values()) for r in records)
active=repeat/105/365
metrics=dict(total_issuance=total,q30_issuance=repeat,other_issuance=total-repeat,sinks=sink,
             implied_daily_active=active,net_money_growth=total-sink,
             net_growth_per_active_cycle=(total-sink)/(active*365),
             craft_initial_increment_profit=70-12-20-70*.05,
             gather_plus_craft_cash_net=70-12-70*.05,
             gather_plus_craft_minutes=1.3*4+.7)
rows=[]
for activity in (.2,.5,.8):
    # Deterministic quantile cohort; not the random cohorts of full simulations.
    ps=[min(.99,activity*(.35+1.3*(i+.5)/2000)) for i in range(2000)]
    for days in (180,365,730):
        for window in (0,7,14):
            if window==0:claims=sum(ps)*days
            else:
                full,tail=divmod(days,window)
                claims=sum(full*(1-(1-p)**window)+(1-(1-p)**tail if tail else 0) for p in ps)
            rows.append(dict(n=2000,activity_setting=activity,expected_dau=sum(ps),days=days,window=window,expected_q30_issuance=105*claims))
(OUT/'calculation.json').write_text(json.dumps(dict(observed_metrics=metrics,analytical_claims=rows,formula='105 * sum_i(sum_blocks(1-(1-p_i)^block_length))); independent activity per cycle, all 2000 eligible and one clear whenever active, no carry, fixed server blocks, incomplete final blocks included',note='Analytic expected issuance only; not new executed trades or observed behavior. Full market experiment in sibling entitlement folder.'),indent=2)+'\n')
lines=['# Pro最新回复数值复核','',
       '来源：用户在本会话粘贴的Pro完整回复。已收到，不再把浏览器连接列为本轮分析阻塞；未通过浏览器直接读取原页。外部建议不是正式游戏规则。','',
       '## 先修正基数','',
       f'- 旧成熟服3种子年总发行均值 **{total:,.0f}** 铜，其中Q30 **{repeat:,.0f}**，其它发行 **{total-repeat:,.0f}**；真销毁 **{sink:,.0f}**。Pro把总发行当成Q30，随后又加补给，存在重复计算。',
       f'- 按Q30每活跃周期一次105铜，反推日活约 **{active:.2f}**，不是1103。总净增约 **{total-sink:,.0f}** 铜，相当于每活跃周期 **{metrics["net_growth_per_active_cycle"]:.2f}** 铜。它不是通胀率。',
       '- 加入1080一次性采购没有“改善药品供给”：双倍供给本来就已存在。加入采购压力后履约94.31%，先前5种子为94.54%；种子数量不同，不能直接归因小幅差异。','',
       '## 周期额度必须按账号算','',
       '一个日活概率为p的账号，长度L的周期内至少活跃一次的概率为1−(1−p)^L。每个周期首次合格通关领取105；未领取不补发。这与把每天发行除以7不是同一规则。当前采用固定服务器周期，不能冒充“上次领取后冷却7天”；后者需另测。','',
       '| 活跃参数 | 预计DAU | 年Q30每次105 | 每7周期一次105 | 每14周期一次105 |',
       '|---|---:|---:|---:|---:|']
for a in (.2,.5,.8):
    rr=[r for r in rows if r['activity_setting']==a and r['days']==365]
    lines.append(f"| {a:.0%} | {rr[0]['expected_dau']:.1f} | {rr[0]['expected_q30_issuance']:,.0f} | {rr[1]['expected_q30_issuance']:,.0f} | {rr[2]['expected_q30_issuance']:,.0f} |")
lines+=['','表为2000成熟账号异质活跃概率的解析期望，0.8档沿用模型0.99上限，因此DAU不是简单1600。180/365/730全部27项在calculation.json；这些是解析计算，不计入服务器模拟次数。年末不完整周期也可能领取，已纳入。','',
       '## 工艺收益要统一口径','',
       'Pro例子售价70、外部料12、塔材机会成本20、费3.5：加工增值34.5铜正确；但再把自行采集塔材的5.2分钟加入分母，会混用加工增值和整条路线时间。',
       f'- 自采到出售的现金净收益（未扣战斗消耗）为54.5铜，5.9分钟，约 **{54.5/5.9:.2f}铜/分钟**。',
       f'- 买料加工的增值为34.5铜，纯制作操作0.7分钟，约 **{34.5/.7:.2f}铜/操作分钟**；必须另计买料、挂单、等待、滞销和资本占用，不能当稳定可刷收入。',
       '- 34.5/5.9=5.85的算术本身正确，但不宜拿这个混合口径和Q30现金净收益/战斗分钟作验收对比。新增2铜耗材还须从对应利润再扣，不能继续沿用34.5。','',
       '## 回收、新人与事件的账目边界','',
       '- 现有94万销毁已含制作费和交易费；不能把新算的制作费/手续费全部再加一次。12铜进口料若为退出本服的真销毁，须真实从商人预算支付外部采购；若只是给可再花钱的NPC则是转移。要改模型重新算，而非给旧流水换标签。',
       '- 5220=初始钱包180+主线2280+塔1700+通缉1060，只有5040是上述首通奖励。全领再消费1080，生命周期净新增4140成立；不能假定年末入服者当年已经领完并采购。',
       '- 每天5/20真新账号的7,555,500/30,222,000铜是365批全部完成生命周期后的总量，不是已验证首年现金流。固定2000账号与每年新增1825/7300账号不是同一人口模型，必须明示离服、迁服资产流与留存。转服不重发首通，但带入余额会改变目的服货币量。',
       '- 六事件60000采购预算加总正确；已有国库付款是转移。世界事件还会改变产量、库存、价格与消费，因此能影响物价，但不应冒充货币销毁。',
       '- “净发行/成交额”20%/50%只能作候选压力指标，成交额会受转手次数、对倒影响，不是无通胀证明。保留真实同用途价格、履约和财富分布一起判断。','',
       '## 工程采用边界','',
       '接受方案A作为当前工程边界：本地工艺与有限预算事件，保护现有奖励，不开放自由共享P2P及银行。方案B的7/14周期额度仅为离线候选，未经用户选择不改游戏规则。其奖励策略接口可作为后续设计，但本轮没有修改结算代码。皮革前三档的成本下限问题仍必须先修正，详见../recipe-viability/RESULTS.md。','']
(OUT/'RESULTS.md').write_text('\n'.join(lines))
print('\n'.join(lines))
