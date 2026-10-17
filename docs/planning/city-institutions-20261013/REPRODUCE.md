# 复现与文件说明

> 接入后提示：下列是调价前源码下保存的设计实验复算命令。生产Core现已采用500/650/950主材、300仪式及早期奖励前移；不要在新源码上再次叠加`EARLY_SHIFT=100`并把它当作同一次实验。当前目录复算见[机构试玩接入](../../development/institutions-playtest-20261013/README.md)，使用`EARLY_SHIFT=0`；原始结果与源清单保持历史证据。

从项目根运行。所有数据是隔离模拟，不能导入玩家真实存档。Swift编译缓存与输出放项目所在SSD；Python无需新增依赖。`source-manifest.json`记录交付时的模拟器、所用规则源码与原始结果哈希，不把当前源码哈希冒充每个历史轮次的编译快照。

## 当前候选

用户确认：赚钱方式自由选择，但必须买齐材料才能晋阶；投资可选；保留主线与塔层日期门槛，同进度允许战力差。`earning`模式默认三材500/650/950及300仪式、无现金J0、分阶段储备。`original`和`final`是较早1360铜阶段的模式名，**`final`不代表当前最终设计**。

编译：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/institutions-clang-cache" swift build -c release --package-path tools/progression-sim --scratch-path "$PWD/.build/institutions-sim" --cache-path "$PWD/.build/swiftpm-cache" --config-path "$PWD/.build/swiftpm-config" --security-path "$PWD/.build/swiftpm-security" --disable-sandbox
```

最新486条路线、18条关闭缓存对照及边界检查：

```sh
EARLY_SHIFT=100 BANK_BONUS=4 .build/institutions-sim/release/ProgressionSim bank docs/planning/city-institutions-20261013/simulation/earning-final 0,30,90 earning
EARLY_SHIFT=100 BANK_BONUS=4 BANK_CACHE=0 BANK_CASES=earning_none,earning_risk80_total_loss .build/institutions-sim/release/ProgressionSim bank docs/planning/city-institutions-20261013/simulation/earning-uncached 0 earning
.build/institutions-sim/release/ProgressionSim bank-check
.build/institutions-sim/release/ProgressionSim bank-power docs/planning/city-institutions-20261013/simulation/power.json
```

复跑宜更改输出目录，保留已交付原始证据。当前模型无随机战斗，只有公告与事件日历受0/30/90建号偏移影响。`HumanPace`代理不是实测玩家，时间阈值在活动开始前判断。

价格扫描使用相同earning模式，只改 `ADV_COSTS`，每档3个情景×3策略×3操作代理＝27条：

| 目录 | ADV_COSTS |
|---|---|
| earning2200-pilot | 480,620,820,280 |
| earning2400-pilot | 500,650,950,300 |
| earning2600-pilot | 550,700,1030,320 |
| earning3200-pilot | 650,900,1250,400 |

```sh
EARLY_SHIFT=100 BANK_BONUS=4 ADV_COSTS=550,700,1030,320 BANK_CASES=earning_none,earning_risk80_total_loss,earning_risk160_total_loss .build/institutions-sim/release/ProgressionSim bank docs/planning/city-institutions-20261013/simulation/earning2600-pilot 0 earning
```

宏观层复跑，`--earning`明确使用2400材料费、96万实物保障基金，无现金J0：

```sh
python3 tools/economy-decisions/bank_check.py --campaign docs/planning/city-institutions-20261013/simulation/earning-final/runs.json --out docs/planning/city-institutions-20261013/simulation/server-earning-reproduced --earning --cases none,coupon12,risk80_total_loss,risk160_total_loss,repair2000,combined_loss_and_supply,supply_half_unrepaired,negative_unbacked_coupon --seeds 1,2,3 --days 365 --workers 3
```

已保存结果分两批：`server-earning`含前5项及3个168万旧预算组合对照；`server-earning-controls`含最终96万组合冲击、无修复冲击、无来源奖励反例。分析脚本明确排除被替代的168万组合，不把两套预算混为一谈。宏观模型由成长综合路线导入收入与准备费，采用回执队列近似成长；它不重新运行2000人的战斗。

核验与生成当前报告：

```sh
python3 docs/planning/city-institutions-20261013/check_proposal.py
python3 docs/planning/city-institutions-20261013/check_food_aid.py
python3 docs/planning/city-institutions-20261013/analyze_simulation.py
python3 docs/planning/city-institutions-20261013/analyze_earning.py
python3 docs/planning/city-institutions-20261013/write_earning_report.py
```

`analyze_simulation.py`只核查已保存1360铜阶段，`analyze_earning.py`核查当前2400铜阶段。`write_simulation_report.py`只重新生成旧阶段报告，不能覆盖当前报告。

## 原始证据

- `proposal-before-simulation.md`：首次完整机构方案，调整前原文。
- `simulation/original`：1360铜共同账单下的原案；`final`：旧恢复机制修订案，各486条。
- `revised`、`iteration2`、`iteration3`：预算/恢复/引导/补助断崖的逐步修正，不是当前最终设计。
- `server-final`、`server-adjusted`：1360阶段45个年度样本。
- `earning*-pilot`：取消现金救济后的四档材料价格对照。
- `earning-final`、`earning-uncached`：最新主要样本与无缓存复算。
- `earning-summary.json`：全部当前验收和代表路线；`power.json`：102组现有遗落物条件对照。

大文件保存为 `runs.json.gz`，读取器优先找JSON、找不到自动解压读取gzip。压缩前后核对解压字节一致，不修改结果；不需要先手工解压。浮点累计时长允许1e-8舍入误差，整数资金、物品、日期和战斗结果必须精确相同。

目前不含：新遗落物强化系统、可变高级人物世界分支、真实玩家订单簿、共享服并发结算、所有机构故事体验、真机表现。不能以此报告宣称这些已经落地。

## 高级住宿与私人会客追加（当前候选）

详见 [住宿模拟与会客玩法](HOUSING_AND_PRIVATE_MEETINGS.md)。使用 `housing` 模式，不将旧bank的每天回满体力当成连续恢复。生产目录不改，候选输入为推荐食宿12/16/22/26/42、固定服务抵扣1/2/3、阶段储备与最多20点实际溢出储备。原价 `draft` 保留12/18/26/30/50及百分比保养。

```sh
EARLY_SHIFT=100 BANK_BONUS=4 HOUSING_COSTS=12,16,22,26,42 .build/institutions-sim/release/ProgressionSim housing docs/planning/city-institutions-20261013/simulation/housing-adjusted-reproduced 0,30,90 adjusted
EARLY_SHIFT=100 BANK_BONUS=4 HOUSING_COSTS=12,16,22,26,42 HOUSING_CASES=basic_no_meeting .build/institutions-sim/release/ProgressionSim housing docs/planning/city-institutions-20261013/simulation/housing-basic-no-guests-reproduced 0,30,90 adjusted
.build/institutions-sim/release/ProgressionSim housing-check
.build/institutions-sim/release/ProgressionSim housing-power docs/planning/city-institutions-20261013/simulation/housing-power-reproduced.json
```

首次主实验运行时包含14个住房策略，新增基本住处不参加会面后默认包含15个策略。要精确复算旧1134条主样本，设置：

```sh
HOUSING_CASES=basic,budget,greedy,arcade,canal,loft,highland,no_reserve,no_buff,no_maintenance,no_meeting,meeting_failed,rent_only,split
```

案例筛选在模拟调用前设置环境变量。`HOUSING_BANKS`默认为 `none,risk80_total_loss,unsafe160_loss`；`HOUSING_HORIZON`默认为42。较早原价pilot与价格pilot在“升档等待租约到期”的中间规则下运行，不能直接与最终换房规则做纯价格因果比较；`housing-draft`243条才是相同换房规则的原价对照。

关闭缓存复算普通与预算18条：

```sh
EARLY_SHIFT=100 BANK_BONUS=4 BANK_CACHE=0 HOUSING_COSTS=12,16,22,26,42 HOUSING_BANKS=none HOUSING_CASES=basic,budget .build/institutions-sim/release/ProgressionSim housing docs/planning/city-institutions-20261013/simulation/housing-uncached-reproduced 0 adjusted
```

45分钟、120分钟、间歇登录各54条：在以下命令前分别加 `HOUSING_MINUTES=45`、`HOUSING_MINUTES=120`、`HOUSING_SKIP=4`，更换输出目录。

```sh
EARLY_SHIFT=100 BANK_BONUS=4 HOUSING_COSTS=12,16,22,26,42 HOUSING_BANKS=none,unsafe160_loss HOUSING_CASES=basic,budget,greedy .build/institutions-sim/release/ProgressionSim housing docs/planning/city-institutions-20261013/simulation/housing-timing-reproduced 0 adjusted
```

宏观层房源真实占用7日，离线不马上退房；会客订单从现有商户资金付，材料/招待转账，验收款先托管。不从工业买家无限借采购预算：

```sh
python3 tools/economy-decisions/housing_check.py --campaign docs/planning/city-institutions-20261013/simulation/housing-adjusted/runs.json --out docs/planning/city-institutions-20261013/simulation/server-housing-reproduced --costs 12,16,22,26,42 --days 365 --seeds 1,2,3 --workers 3
python3 docs/planning/city-institutions-20261013/analyze_housing.py
```

验收脚本读取已保存原始结果；要核验新的输出，应显式修改读取目录或先在新目录比对，避免覆盖历史证据。`bank-regression-housing`18条为住宿扩展关闭时的旧银行回归，整数、日期、奖励与旧结果一致。

本轮UI会客演示是本地交互示例：私人核验合同净26、缺证拒绝、公开柜台替代与窄屏布局已检查。分支收据、制作失败、后续关系/事件和真人体验尚未接App。

`housing-split-clock-fixed`是分两次登录跨日偏移修复后的81条；已替换进入`housing-adjusted`主结果，原受影响样本保留在`housing-split-before-clock-fix`。修复防止银行到期被前一天12小时会话偏移提前，所有合约验收都检查真实签约后足额小时数。该修复不影响其他住房策略及宏观层。

字段口径：`housingExperiment.days[].cost`记录当天档位报价；实际扣款以同日`bankExperiment.events`的`day_open.amount`为准。食宿援助日的报价仍为12，但实际扣款为0；总支出与所有验收均使用实际回执，不用报价充当已付钱。
