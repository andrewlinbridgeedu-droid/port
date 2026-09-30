# 共享服定案复核（2026-09-30）

The user delegated the open choices. Chosen package: keep the 24/12 NPC scale; the shared
server pays the new daily systems 15% of single-player copper from the city budget (levy cap
20% of NPC basket and open-service sales); players buy one protected basket per active day
(D3); local copper enters at the same 15% rate, counting at most 12,000 local copper.
Rule fixed before running: the package is kept only if every normal year, the repaired supply
shock, dormant return, investment heat, local import and underground runs pass L1, L2_strict
and L3 with at least 95% of the daily-loop copper paid; the unbacked-mint controls must still
fail L2_strict.

5 个种子 × 365 天，Pro V3 模型＋钩子，是设计模型。

| 情景 | 峰值 | 30天变化 | 全年 | 篮子最低 | 货币增长 | 每日玩法付出 | 玩家中位现金 | 低于恢复线 | L1 | L2 | L2严 | L3 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| launch_base·定案 | 1.00 | 0% | +0% | 100.0% | +40%–+42% | 100% | 1102–1135 | 0.5%–0.5% | 5/5 | 5/5 | 5/5 | 5/5 |
| steady_fresh20·定案 | 1.00–1.03 | 0%–0% | +0% | 100.0% | +52%–+55% | 100% | 1427 | 0.0% | 5/5 | 5/5 | 5/5 | 5/5 |
| dormant_return_200·定案 | 1.00 | 0% | +0% | 100.0% | +42%–+44% | 100% | 1102–1174 | 0.4%–0.5% | 5/5 | 5/5 | 5/5 | 5/5 |
| investment_heat·定案 | 1.00 | 0% | +0% | 100.0% | +40%–+42% | 100% | 1102–1135 | 0.5%–0.5% | 5/5 | 5/5 | 5/5 | 5/5 |
| supply_half_90_repair·定案 | 1.00 | 0% | +0% | 100.0% | +37%–+39% | 100% | 1102–1135 | 0.5%–0.5% | 5/5 | 5/5 | 5/5 | 5/5 |
| launch_base·定案·带入12000按15% | 1.00 | 0% | +0% | 100.0% | +34%–+35% | 100% | 1102–1175 | 0.5%–0.5% | 5/5 | 5/5 | 5/5 | 5/5 |
| launch_base·定案·带入12000不折算 | 1.00 | 0% | +0% | 100.0% | +6%–+9% | 100% | 1102–1175 | 0.5%–0.5% | 5/5 | 5/5 | 5/5 | 5/5 |
| launch_base·定案·地下委托 | 1.00 | 0% | +0% | 100.0% | +42%–+43% | 100% | 1102–1135 | 0.5%–0.5% | 5/5 | 5/5 | 5/5 | 5/5 |
| steady_fresh20·定案·地下委托 | 1.02–1.10 | 0%–1% | +0%–+0% | 100.0% | +55%–+57% | 100% | 1427 | 0.0% | 5/5 | 5/5 | 5/5 | 5/5 |
| 反例·照单机发币 | 2.27–2.39 | 37%–40% | +102%–+105% | 100.0% | +350%–+353% | 100% | 3395–3430 | 0.1%–0.1% | 5/5 | 0/5 | 0/5 | 5/5 |
| 反例·每活跃玩家每天无源+30 | 1.15–1.17 | 2%–5% | +1%–+2% | 100.0% | +109%–+112% | — | 1546–1635 | 0.3%–0.4% | 5/5 | 5/5 | 5/5 | 5/5 |

**定案复核**：未通过。正常与冲击情景：{"launch_base·定案": true, "steady_fresh20·定案": true, "dormant_return_200·定案": true, "investment_heat·定案": true, "supply_half_90_repair·定案": true, "launch_base·定案·带入12000按15%": true, "launch_base·定案·带入12000不折算": true, "launch_base·定案·地下委托": true, "steady_fresh20·定案·地下委托": true}；反例被严格线挡住：{"反例·照单机发币": true, "反例·每活跃玩家每天无源+30": false}。（“不折算”一行只作对照，不计入判定。）

