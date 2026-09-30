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

**2026-09-30 补：加急委托、街区难题、城市委托的内容和规则已写进规则库 `StreetTasks.swift`**（[记录](street-tasks-20260930/README.md)）。App 只需要：
1. 存档新增键保存 `MPCStreetTaskLedger`，旧档读入为空账本；每天开游戏时调用 `open(day:contributionPoints:)`。
2. 委托板和港务处、市政厅柜台列出 `offers`；点接单调 `accept`。
3. 首页地图用 `MPCStreetTaskCatalog.streetTargets(ledger)` 点亮目标。它和通缉目标一样给出 `personID` 或 `placeID`，新种类是 `.urgentErrand`、`.jointErrand`、`.commission`。
4. 点到目标时，按当前步的 `action` 调用 `talk`、`handOver`、`answer`，或 `beginBattle`／`settleBattle`。街头战编号以 `church_maintenance_street_` 开头，走现有塔战演出。
5. 完成时（`Progress.reward` 不为空）：
   - 铜已由账本加上；
   - `contributionReceipt` 不为空时，按 `.errand` 记城市贡献度；
   - 对 `neighbors` 里每位调用 `MPCNeighborLedger.raiseAffinity`，返回小故事就播；
   - 城市委托的 `sceneID` 启用 `commissionDecals` 里对应的贴片。
6. 没开的档写“城市贡献度到 N 开放”。

- `.letterChains`：邮局发的邮件包加入回信、改址、取件三种模板。没开时只有直投和认人。
- `.urgentErrand`：委托板每天多一张加急委托（3 步，15 铜，计为 `.errand`）。
- `.jointErrand`：逢 3 的倍数的天，委托板贴一张“街区难题”（2–3 名街坊的请求串成 4–5 步，30 铜，相关街坊各好感＋1，计为 `.errand`）。
- `.higherRemnants`：余案从高一个塔段抽取（材料用高一段的，铜币不变）。
- `.cityCommission`：港务处或市政厅每 7 天一张城市委托（5–6 步，60 铜，完成后首页画面一处街景永久改变，不给战力）。

没开的档在委托板和日刊上写“城市贡献度到 N 开放”，不隐藏。

## 2.5 城市委托的街景贴片（画景色）

设计稿 6.5 节。**喷泉、货场第三版已获用户认可，PR #22 已合入 main；图稿先只保存在仓库。等城市贡献度第 4 档的“城市委托”（`.cityCommission`）功能做进 App，玩家完成对应委托并保存完成状态后，才显示对应首页贴片。**美术认可、PR 合并或达到第 4 档本身都不会直接显示变化；当前 12 条 `commissionDecals` 保持 `enabled:false`。美术准备可以和其他任务并行。

**原则：**
- 不重画首页原画。15 张原画（春、夏、秋、冬、冬雪 × 白天、黄昏、夜晚）一张都不改。
- 只做“多出一样东西”的变化，不做“把坏的修好”。

**第一批 2 处：**
1. **喷泉广场**：喷泉边加一圈矮石花坛，种当季小花；喷泉上方拉两三串三角彩旗。
2. **工坊货场**：吊臂上挂一张新帆布，下面堆几只新货箱，贴港务处的封签。

**用户定：台阶大道不加路灯，这处不做。**原任务单里的“一排 4–5 盏”是写任务单时加的细节，不是用户的要求。[PR #22](https://github.com/andrewlinbridgeedu-droid/port/pull/22) 合并前已从当前交付移除大道贴片、发光层、LightOrder、对比及 `commissionDecals` 条目；旧稿只留历史目录供追溯，不得用于 App 接入。原画已有灯光不变。

**做法：**
- 在秋景白天原画 `CityAutumnDay` 对应的区域局部重绘，画出新东西，抠成透明 PNG，每块约 512×512。
- 黄昏、夜晚两块按 `CityAutumnSunset`、`CityAutumnNight` 同一区域的色调调色，逐块用眼睛看，不能只靠程序统一调暗。
- 冬雪场景里落在积雪上的贴片，补一块带雪的版本；其余季节共用。
- 以后若有会亮的东西（灯笼等），另出一张发光层，按现有 `City*Lights`、`City*LightOrder` 的做法接入，夜里和原有的灯一起亮。第一批两处都不发光。
- 画风要和原画一致：笔触、透视、光向都一样，不能看起来像后贴上去的。
- 坐标用画高为 1 的单位，写进 `mistport-ios/Mistport/WisteriaMap/home-map-layout.json`（App 读的那份），新增 `commissionDecals`。每条写明哪处、贴片文件名、适用的季节和时段。

**交付：**
- 2 处 × 15 张原画的贴前、贴后对比截图，放在 `docs/development/commission-decals-20260929/`，按 LFS 提交。
- 贴片原图和局部重绘用的提示词，也记录在同一目录。
- 本批图稿已确认；当前先留仓库，不接 App、不装机。后续第 4 档城市委托接入时，按对应委托完成状态显示，并单独进行 App 验收。

## 3. 验收

- 新档从 0 开始；旧档迁移一次，数值对得上，重开不再加分。
- 一天内送三包信只加 2 分；同一场事件战重复结算不加分。
- 每档开放的内容出现；没开的看得到门槛提示。
- 主线、通缉 B01/B04/B10、世界事件、基础委托在任何档位都能做。
- Preferences 只多 `mistport.cityContribution.v1` 一个键。
- 档位已由用户确认（120／220／300）。加急委托、街区难题、城市委托三类新内容的台词和铜币要进 `tools/daily-loop/budget.py` 重算一遍，再交用户确认。
