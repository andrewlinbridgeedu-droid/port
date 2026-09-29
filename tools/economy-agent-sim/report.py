"""Generate an inspectable Chinese experiment report from completed JSON runs."""
from pathlib import Path
import json,statistics,html
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/development/economy-agent-sim-20260926'
labels={'baseline':'基准','cold':'低活跃','hot':'高活跃/高月卡','no_pass':'无月卡','all_pass':'全月卡（无免费组）','no_events':'关闭事件','supply_2x':'材料及底料×2','supply_3x':'材料及底料×3','allowance_14':'补给14+14','allowance_42':'补给42+42','supply2_allowance14':'供给×2/补给14+14','supply2_fee8':'供给×2/手续费8%','low_crafting':'低制作参与','high_crafting':'高制作参与','low_tower':'少刷塔','high_tower':'多刷塔','repeat_best':'重玩最高已通关关卡','repeat_heavy':'重玩最高关卡/少刷塔','hoarding':'部分玩家留存关键料','dump':'留存后低价抛售','supply_shock':'药材/药基断供冲击','overlap_shock':'断供叠加药需冲击','churn':'活跃概率下降60%','new_server':'新服结构','mature_server':'成熟服结构','wealth_elastic':'更强财富购买意愿','slow_prices':'慢调价','fast_prices':'快调价'}

def mean(g,k):
    x=[r[k] for r in g if r.get(k) is not None]
    return statistics.mean(x) if x else None

def pct(x):return 'NA' if x is None else f'{100*x:.1f}%'

def generate():
    sections=[];total=days=trades=passed=0;md=[]
    for folder,title in [('year1','一年：28组配置'),('year2','两年：四组长期压力'),('targeted','一年：主动选层刷缺料'),('shopping','一年：修正同类药替代购买'),('shopping_profit','一年：替代购买及成熟工匠利润约束')]:
        base=OUT/folder
        rows=[json.loads(p.read_text()) for p in sorted(base.glob('*/summary.json'))]
        if not rows:continue
        total+=len(rows);days+=sum(r['config']['days'] for r in rows);trades+=sum(r['trades'] for r in rows);passed+=sum(r['all_checks_pass'] for r in rows)
        trs=[];md += [f'## {title}','', '| 情景 | 种子数 | 免费药品履约均值（最低–最高） | 免费余额P10均值 | 最后完整30期价格指数均值 | 全部门槛通过 |','|---|---:|---:|---:|---:|---:|']
        for name in sorted({r['config']['name'] for r in rows}):
            g=[r for r in rows if r['config']['name']==name];fills=[r['free_fill_last90'] for r in g if r['free_fill_last90'] is not None]
            fill=mean(g,'free_fill_last90');cash=mean(g,'free_cash_p10')
            indices=[r['basket_index_30d'][-1] for r in g if r['basket_index_30d'][-1] is not None]
            ix=statistics.mean(indices) if indices else None
            span=f'{pct(min(fills))}–{pct(max(fills))}' if fills else '无免费组'
            n=sum(r['all_checks_pass'] for r in g)
            label=labels.get(name,name);cashtext='NA' if cash is None else f'{cash:,.0f}'
            idx='NA (0/'+str(len(g))+')' if ix is None else f'{ix:.3f} ({len(indices)}/{len(g)})'
            bar=f'<div class="bar"><span style="width:{100*(fill or 0):.1f}%"></span></div>'
            trs.append(f'<tr><td>{html.escape(label)}<small>{name}</small></td><td>{len(g)}</td><td>{bar}{pct(fill)}<small>{span}</small></td><td>{cashtext} 铜</td><td>{idx}</td><td>{n}/{len(g)}</td></tr>')
            md.append(f'| {label} | {len(g)} | {pct(fill)}（{span}） | {cashtext} | {idx} | {n}/{len(g)} |')
        sections.append(f'<section><h2>{title}</h2><p>药品履约按最后90周期统计。指数初始设定为1；缺成交的篮子为NA。点击原始数据可查看每个种子。</p><table><thead><tr><th>情景</th><th>种子</th><th>免费药品履约</th><th>免费余额P10均值</th><th>末期价格指数</th><th>全部检查通过</th></tr></thead><tbody>{"".join(trs)}</tbody></table><p><a href="{folder}/comparison.csv">结果表</a> · <a href="{folder}/manifest.json">参数与门槛</a> · <a href="{folder}/independent_audit.json">独立复核</a></p></section>')
        md.append('')
    intro=f'''# 2000独立玩家经济：多场景实验结果

本轮实际完成 **{total}次运行、{days:,}个服务器模拟日、{trades:,}笔成交**。每次2000独立账户。当前实验门槛全部通过的运行数：{passed}/{total}。无免费组的全月卡对照不能用于免费玩家通过判定，不把NA误写为零购买力。

模型代码与假设见 [说明](../../../tools/economy-agent-sim/README.md)，可视化表见 [index.html](index.html)，设计含义见 [INTERPRETATION.md](INTERPRETATION.md)。这不是游戏实装或真实服务器测试，也不是“无通胀”证明。价格均值括号内列出有完整成交篮子的种子数；有缺失就不能作为全部种子的稳定性证据。

第一轮28参数组×5种子×365周期（单品购买控制组）；第二轮4组×5种子×730周期（沿用控制组购物策略）；额外4组×5种子验证主动选择已通关楼层刷缺料；另两批各4组×5种子修正同类药替代购买，并进一步限制成熟工匠亏本生产。所有修改以policy_patch逐条保留，不改正式游戏。每个目录保留配置、种子、每日账、汇总和独立复核。

两年批次沿用同一人口生成规则，但延迟新人窗口按总期长的一半生成（一年约182周期、两年365周期），因此并非同一批玩家一年轨迹的无条件续跑；不能把一年/两年差异只归因于时间。主动选层批次与一年原模型使用同种子，但分支随机调用不同，不是严格共同随机数方差缩减实验。

## 判读边界

**优先使用shopping/shopping_profit修正批次评估药品履约。** 原始year1/year2/targeted只买一个SKU，未成交即退出，会夸大缺货；保留它们作为行为假设敏感性对照，不能把其低履约直接归因于实际物资不足。原始批次成熟工匠也不以利润约束产量，容易出现亏本继续制作，不能据此认定长期市场价格。

- 先看买不买得到，再看有没有钱和价格。富余现金不能消除缺货；价格稳定也可能只是NPC底料固定价。
- 价格篮子含固定价底料和药膏，不能代表全市场；最大30周期变化同时惩罚涨价/跌价，开服变化也在内，不能将失败一律称为通胀。
- 任务首通与重玩奖励、塔怪编排来自源码；中间档配方、药需、消费意愿、活跃和刷塔行为是假设。主线晋阶材料支出未覆盖，因此正余额不证明全流程可负担。
- 逐笔资金/库存校验及每日总钱物守恒通过后才写结果；独立脚本再从导出日账重算钱与成交额。没有把缓存PASS当现场检查。
- 所有金额是测试候选。没有改真实存档、补给、掉落或现行奖励；银行与投资尚未模拟。

'''
    (OUT/'RESULTS.md').write_text(intro+'\n'.join(md)+'\n')
    style='body{font:16px/1.55 system-ui;background:#101b27;color:#eaf0f7;margin:0}main{max-width:1160px;margin:auto;padding:36px 24px}h1{font-size:32px}h2{margin-top:40px}p{color:#bdcbd9}a{color:#78dcca}section{padding:12px 0 32px}table{border-collapse:collapse;width:100%;background:#172737}td,th{text-align:left;padding:12px;border-bottom:1px solid #304356}th{color:#b8d0e2;font-size:14px}small{display:block;color:#a1b3c4;font-size:12px}.bar{width:140px;height:7px;background:#334656;margin-bottom:5px}.bar span{display:block;height:7px;background:#7ad6c5}.cards{display:flex;gap:16px;flex-wrap:wrap}.cards div{background:#203448;border-radius:8px;padding:18px 24px}.cards b{font-size:25px;display:block}.note{border-left:3px solid #f3bb6d;padding-left:16px}@media(max-width:700px){main{padding:20px 10px}table{font-size:12px}td,th{padding:6px}.bar{width:80px}}'
    doc=f'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>雾港经济多场景实验</title><style>{style}</style><main><h1>2000独立玩家 · 经济压力实验</h1><p>真实成交记账 · 有限库存与采购 · 2026-09-26</p><div class="cards"><div><b>{total}</b>运行</div><div><b>{days:,}</b>服务器模拟日</div><div><b>{trades:,}</b>真实模拟成交</div><div><b>{passed}/{total}</b>全部候选门槛通过</div></div><p class="note">仿真结果，不是实装或稳定性保证。源码奖励保持；配方及玩家行为仍有假设。缺货与个体购买力需要同时通过。两年人口入场窗口不同，不是同一轨迹续跑。</p><p><a href="RESULTS.md">完整说明</a> · <a href="../../../tools/economy-agent-sim/README.md">模型边界与运行方法</a></p>{"".join(sections)}</main></html>'
    (OUT/'index.html').write_text(doc)
    print(total,days,trades,passed)
if __name__=='__main__':generate()
