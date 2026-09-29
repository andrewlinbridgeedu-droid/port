"""Summarize actual engine runs. Never infer purchase demand or human probabilities."""
import json
import statistics
import sys
from collections import defaultdict
from pathlib import Path

source, target = map(Path, sys.argv[1:])
rows = [json.loads(line.split('CAMPAIGN_SANDBOX ', 1)[1]) for line in source.read_text().splitlines() if line.startswith('CAMPAIGN_SANDBOX ')]
assert len(rows) == 288, len(rows)
assert all(r["medal_uses"] > 0 for r in rows), "Pilot must actually activate the equipped medal"
assert len({tuple(r[k] for k in ('scenario','gear','passive','medicine','route','assumed_error_tape','seed')) for r in rows}) == len(rows)
target.mkdir(parents=True, exist_ok=True)
(target / 'trials.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2) + '\n')
groups = defaultdict(list)
for r in rows:
    groups[r['scenario']].append(r)
lines = ['# 新战役遭遇：共享战斗内核程序试跑', '', '实际调用新遭遇与正式技能/装备/药品规则；不注入胜利或直接伤害。288场=4遭遇×2装备×3被动×2药量×2策略×3预生成操作阻塞带。随机种子固定211，同一时间索引阻塞带用于全部配对。操作带是假设，不是真人胜率或购买需求。', '', '|遭遇|胜/场|时长中位秒|药品使用总瓶|有效核心回血|打断次数|', '|---|---:|---:|---:|---:|---:|']
for key, rs in groups.items():
    lines.append(f"|{key}|{sum(r['outcome']=='victory' for r in rs)}/{len(rs)}|{statistics.median(r['seconds'] for r in rs):.2f}|{sum(r['medicine_used'] for r in rs)}|{sum(r['core_healing'] for r in rs)}|{sum(r['interrupts'] for r in rs)}|")
pairs = defaultdict(dict)
for r in rows:
    pairs[tuple(r[k] for k in ('scenario','gear','passive','route','assumed_error_tape','seed'))][r['medicine']] = r
flips = sum(p[0]['outcome']!='victory' and p[3]['outcome']=='victory' for p in pairs.values())
worse = sum(p[0]['outcome']=='victory' and p[3]['outcome']!='victory' for p in pairs.values())
hp_improvement = sum(p[3]['hp'] > p[0]['hp'] for p in pairs.values())
lines += ['', f'144个带药/不带药配对：药品使失败转为胜利 {flips} 对；反向 {worse} 对；带药结束生命更高 {hp_improvement} 对。', '', '这些数值只判断此驱动器和策略下的容错/可达性，不证明玩家愿意买药。原型无铜币、NPC需求、拍卖成交或世界结算，不能据此宣布经济闭环或共享市场稳定。', '', '操作带：每0.5秒抽取可操作/阻塞状态，三档阻塞概率0/25%/50%，先生成再开战，不根据生命或药品数量改变随机流。清场策略始终优先附属敌人；抢攻策略击破一名后打核心，仅回流读条时优先剩余支援者。两者均会在生命低于正常上限一半时尝试用药，并从6秒开始尝试激活勋章。', '', '每场上限180秒；同刻机制/敌人接触先于玩家命中。事件日志中的 enemy_hit / poison_tick amount 表示实际生命净减少，可能包含同期被动影响，不能当作原始伤害量。']
lines += ['', '## 两条策略的实际差别', '', '|高难遭遇|策略|胜/场|时长中位秒|', '|---|---|---:|---:|']
for scenario in ('guardHard', 'relayHard'):
    by_route = defaultdict(dict)
    for route in ('clear_adds', 'aggressive'):
        subset = [r for r in rows if r['scenario'] == scenario and r['route'] == route]
        lines.append(f"|{scenario}|{route}|{sum(r['outcome']=='victory' for r in subset)}/{len(subset)}|{statistics.median(r['seconds'] for r in subset):.2f}|")
        for r in subset:
            by_route[tuple(r[k] for k in ('gear','passive','medicine','assumed_error_tape','seed'))][route] = r
    faster = sum(p['aggressive']['outcome'] == 'victory' and p['aggressive']['seconds'] < p['clear_adds']['seconds'] for p in by_route.values())
    lines.append(f"\n{scenario}：抢攻比清场更快且成功 {faster}/{len(by_route)} 个同配置配对。\n")
lines += ['', '护卫阵若抢攻没有时间收益，不能称两条路线均已成立；应继续调整机制收益或抢攻策略。回流阵的速度差也不等于真人偏好。所有样本均已检查勋章至少实际激活一次，避免把未生效的按钮当作有效配装。']
(target / 'TRIALS.md').write_text('\n'.join(lines) + '\n')
print('\n'.join(lines[:12])); print(f'paired medicine win flips={flips}, worse={worse}, hp improvement={hp_improvement}')
