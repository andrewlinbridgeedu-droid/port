# Codex 任务单：城市贡献度接入 App · 2026-09-29

交给 Mac 上的 Codex。设计见 [首页港城与街头任务设计稿](../../mistport-ios/docs/game-design/chapter-one-30/HOME_MAP_STREET_TASKS_20260929.md) 第 6 节。规则库已写好：`MistportCombatCore/Sources/MistportCombatCore/CityContribution.swift`（`MPCCityContribution`、`MPCCityContributionLedger`），测试在 `CityContributionTests.swift`。回复用户用中文。

**排在 [首页港城任务单](CODEX_TASKS_HOME_MAP_20260929.md) 的任务 1、2 之后做。**第 1 步（记分）不依赖首页，可以先做；第 2、3 步要等首页地图层和新邮务。

## 1. 记分和迁移（可先做）

1. `GameStore` 新增存档键 `mistport.cityContribution.v1`，存 `MPCCityContributionLedger`。
2. 第一次读到没有这个键的存档时调用 `migrate(completedMissions:closedBounties:completedErrands:)`，按已通关主线数、已结案通缉数、已完成的街坊委托数换算。迁移回执就是账本里的 `migratedPoints`，只迁移一次。
3. 在这些结算点调 `record(receiptID:source:day:)`，`day` 用 `MPCDailyPacing` 的存档天数：

| 来源 | 结算点 | 回执 |
|---|---|---|
| `.mission` | 主线首通发奖处 | `mission-<关号>` |
| `.errand` | 街坊委托领奖 | `errand-<委托 offer ID>` |
| `.post` | 邮务结算（`postal-<序号>`） | 同邮务回执 |
| `.remnant` | 余案领奖 | `remnant-<存档天数>` |
| `.bounty` | 通缉结案领奖 | `bounty-<案件 ID>` |
| `.eventBattle` | 计入胜场的事件战 | 事件战票据 |
| `.eventSuccess` | 事件成功时 | `event-success-<事件 ID>` |

回执已存在或当天上限已满时 `record` 返回 0。重复回调、重开游戏都不会多给。

4. 首页和日刊原来的“区域声望 x/100”改为 `MPCCityContribution.progressText(points:)`。`districtIsUnlocked` 只用于旧区，保持原样。

## 2. 按档开放（首页地图层、新邮务做完后）

规则库只回答“开没开”：`ledger.isOpen(.letterChains)` 等。

- `.letterChains`：邮局发的邮件包加入回信、改址、取件三种模板。没开时只有直投和认人。
- `.urgentErrand`：委托板每天多一张加急委托（3 步，15 铜，计为 `.errand`）。
- `.jointErrand`：逢 3 的倍数的天，委托板贴一张“街区难题”（2–3 名街坊的请求串成 4–5 步，30 铜，相关街坊各好感＋1，计为 `.errand`）。
- `.higherRemnants`：余案从高一个塔段抽取（材料用高一段的，铜币不变）。
- `.cityCommission`：港务处或市政厅每 7 天一张城市委托（5–6 步，60 铜，完成后首页画面一处街景永久改变，不给战力）。

没开的档在委托板和日刊上写“城市贡献度到 N 开放”，不隐藏。

## 3. 验收

- 新档从 0 开始；旧档迁移一次，数值对得上，重开不再加分。
- 一天内送三包信只加 2 分；同一场事件战重复结算不加分。
- 每档开放的内容出现；没开的看得到门槛提示。
- 主线、通缉 B01/B04/B10、世界事件、基础委托在任何档位都能做。
- Preferences 只多 `mistport.cityContribution.v1` 一个键。
- 加急委托、街区难题、城市委托三类新内容的台词和铜币要进 `tools/daily-loop/budget.py` 重算一遍，再交用户确认。
