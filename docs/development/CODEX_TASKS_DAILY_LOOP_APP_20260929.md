# Codex 任务单：每日玩法接进 App、按天推进验证、真机计时 · 2026-09-29

交给 Mac 上的 Codex。云端写好了规则库和模拟器，但编译不了 iOS，也装不了机，所以下面这些都要在 Mac 上做。回复用户用中文。

## 开始前

1. `git fetch && git checkout main && git pull`。`main` 已包含所有分支（PR #1、#2），从 `main` 开一个新分支做，做完开 PR 合回 `main`。
2. 按顺序读：
   - `AGENTS.md`
   - `docs/development/HANDOFF_WALLS_20260929.md`
   - `mistport-ios/docs/game-design/chapter-one-30/DAILY_LOOP_AND_ECONOMY_20260929.md`（第 4 节是各系统设计，第 10 节是分期）
   - `docs/development/workshop-phase1-20260929/README.md`
   - `docs/development/daily-content-phase2-20260929/README.md`
   - `HANDOFF_PROGRESSION_UI_20260928.md`（装机惯例）
3. 规矩，每一条都必须遵守：
   - **不覆盖玩家真实存档。** 装机前备份 Preferences，装完逐文件比对；测试用独立存档（suite）。
   - **不重复发放**一次性首通、铜币、功勋、遗落物。
   - **打赢一定发奖。** 按天推进只在开打前判断，领奖处不许再拦。
   - 新账本都要进存档，并写迁移回执；旧存档读入时为空账本，只迁移一次。
   - 构建编号用 170 以下（170 及以上归主页会话）。DerivedData 和签名包归档放外置 SSD。不要删除或重建指向 SSD 的符号链接。
   - 构建成功、测试通过、装机能启动，都**不等于**用户认可；界面和手感要用户在真机上看过才算。

## 任务 0：先让 App 编译通过（最优先）

App 从 `cee125a` 起一直没编译过，期间改了下面几处，都要在 Mac 上修到能编译、能跑：

- 通缉栏与遗落物；
- 墙关失败提示（`wallDefeatHint` 多了 `wornTowerDepth` 参数）；
- 工坊开放改到 Q5；
- 通缉战败只扣铜；
- **按天推进接入**（第四轮，只做过语法检查）：
  - `GameStore.swift` 里的 `resolveDailyPacingStart`、`pacingDay`、`missionLockText`、`towerFloorIsOpenToday`、`towerPacingLockText`、`todaySummary`、`debugSetPacingDay`；
  - `missionIsAvailable`、`enterDistrictMap`、`churchTowerSession`、`restart`、`debugJumpToOldClockMission` 里加的按天判断；
  - `ContentView.swift` 里城市页的下一关标题；
  - `ChapterOneTestView.swift` 里深井页的按钮和提示。

步骤：
1. `cd mistport-ios/MistportCombatCore && swift test`：应为 516 个全过（Mac 上多一个 `S9TalentEditorTests`）。
2. `xcodebuild` 修掉所有错误。
3. 跑 DEBUG 自检，看日志：
   - `--verify-daily-pacing` 要打印 `DAILY_PACING_VERIFY_PASS`；
   - `--verify-player-growth`（已改为断言 Q30 在第 1 天锁住）；
   - `--verify-church-tower`、`--verify-bounty-daily-risk`、`--verify-p0`。
4. 装机，先按惯例备份 Preferences。**第一次打开用户真实存档**，逐项确认：
   - 存档只多了 `mistport.daily-pacing.start.v1` 一个键，其他文件不变；
   - 记录的 `origin` 是 `migrated`；
   - 下一关当天能打，深井下一层当天能进。
5. 用独立测试存档看：新档第 1 天打完 Q3 后，城市页显示“第 4 关明天开放”；深井当天新封 4 层后，新层变灰并写明原因；已封堵的层能重打。
6. 请用户看“封线装备”页通缉栏、通缉案卷的遗落物说明、墙关失败提示、通缉战败说明。

## 任务 1：每日玩法阶段 3，接进 App

规则都在 `mistport-ios/MistportCombatCore/Sources/MistportCombatCore/`，App 只调用、不要重写规则。每接一个系统，同时做：存档键、迁移回执、防重复领奖、DEBUG 自检（仿照 `verifyDailyPacing`）。建议按下面的顺序做。

### 1.1 重复工作递减（`DailyWork.swift`，`MPCDailyWorkLedger`）
- 邮务 J0、巡检 J1、塔内维护 J2、主线重玩的结算都改走 `settle(receiptID:day:copper:merit:)`：
  - 当天第 1–3 单全额，第 4–6 单半价，之后一成；
  - 功勋每天只算前 2 单（`meritJobsPerDay`）。
- 接单前用 `preview(day:copper:)` 显示这一单实际能拿多少；超过 3 单、6 单时写明“今天第 N 单起半价／一成”。
- `day` 一律用 `GameStore.pacingDay`。

### 1.2 工坊（`Crafting.swift`；现有界面 `LocalWorkshopView.swift`，现有账本 `MPCLocalWorkshopLedger`）
- **塔材料掉落**：塔战胜利后按 `MPCTowerMaterials.drops(floor:)` 入背包，首通和重打都掉。现在只有 F1 掉韧皮，要改成按恶魔种类掉。
- **制作**：
  - 四个基础配方（绑带、止痛膏、修甲片、过滤布）和十件工坊装备配方都走 `MPCCraftingLedger.craft`；
  - 按 `requiredMission`、`requiredProficiency` 开放；
  - 熟练度每天只算前 5 次（`proficiencyCraftsPerDay`）。
  - 制作时要传事件的 `surcharge`（底料加价或降价，见 1.4）。
- **NPC 订单**：`MPCWorkshopOrderBoard` 每天刷新，预算有限，最多累积 3 天；要传事件的 `bonus`。卖不掉的货留着自用。
- **工坊装备**：
  - 穿戴要求是已打通对应塔层，按 `MPCChurchGearCatalog` 的档位；
  - 会磨损，用绑带、修甲片修；
  - 按档位计入塔层检定（`MPCChurchGearStats.towerDepth`）。
  - 在装备页和封线装备页显示档位、耐久和修理按钮。
- 城市服务开关已改为 Q5（`cityServiceIsUnlocked(.workshop)`），确认按钮第 3 天会亮。

### 1.3 日刊（设计稿 4.1；新界面，作为所有系统的入口）
每天第一次打开游戏时显示，之后可以从城市页再打开。内容：
- 今天新开的主线：`MPCDailyPacing.todaySummary` 和 `missionLockText`；
- 深井今日额度；
- 通缉日刊（现有的 `MPCDailyBountyRotation`，3–6 案）；
- 工坊订单；
- 当前事件和阶段；
- 酒馆彩头；
- 今天的街坊委托；
- 无名残余案。

“每天第一次”按 `pacingDay` 记，存档里记下看过的最后一天。

### 1.4 事件板（`CityEvents.swift`，`MPCCityEventLedger`）
- 四场本地世界事件，第 4–28 天，用 `MPCCityEventCatalog.running(day:)` 取当前事件。
- 界面显示：简报、交货清单与剩余件数（`remaining`）、胜场进度（`winsLeft`）、今天已记几场（`winsCounted`，每天最多 2 场）。
- **交货**：`deliver(...)`，从背包扣货、按单价给铜。
- **事件战**：
  - 用 `beginBattle(ticket:eventID:day:)` 拿战斗 ID，再用 `MPCCityEventCatalog.encounter(id:)` 开打；
  - 走现有塔战的 Unity 演出路径（战斗 ID 以 `church_maintenance_` 开头）；
  - 打完调 `settleBattle` 结算，胜负照规则库来，回执防重复。
- **城市效果**：`effects(day:)` 接到三处：
  - 工坊订单的 `bonus`；
  - 制作的 `surcharge`；
  - **商店止痛膏价加上 `salveSurcharge`**。
- 界面上明确标出“一起帮忙的街坊和工人是预置人物，不是联网玩家”（`fixtureNotice`）。

### 1.5 街坊委托（`NeighborErrands.swift`，`MPCNeighborLedger`）
- 港城地图上的 23 名街坊（`harbor-pedestrians.json`），每天由 `open(day:completedMissions:)` 给出 2–3 条委托。当天不做，第二天作废。
- 在地图上走到这个人面前对话，显示请求。四种委托：
  - **送货**：`deliver`，扣背包里的工坊货；
  - **找东西**：`answer`，三选一，答错划掉这个选项、不扣钱；
  - **传话**：要走到收话人那里再调 `relay`；
  - **赶塔怪**：`beginPest` 拿战斗 ID，用 `MPCNeighborCatalog.encounter(id:)` 开打，走塔战演出，打完调 `settlePest` 结算。
- 好感到 3 和 6 时解锁小故事（`stories`），在对话里播放。第一批写好小故事的是 8 人，其余 15 人暂时没有。

### 1.6 无名残余案（`RemnantCases.swift`，`MPCRemnantLedger`）
- 通缉结案后开放，每天一个小案：`MPCRemnantCatalog.today(day:closedCaseIDs:)`。
- 流程：
  1. `accept`；
  2. 看线索并选择：`answer`；
  3. 开打：`beginBattle`，按已打到的塔层取强度档（`band`）；
  4. 结算：`settleBattle`；
  5. 领奖：`claim`，领奖要走 `MPCDailyWorkLedger`，计入重复工作递减。
- 中途退出调 `abandonBattle`。账本只保留 7 天。

### 1.7 提示
所有“今天已记满”“第 N 关明天开放”“今天第 N 单起半价”“熟练度今天已满 5 次”“事件战今天已记 2 场”的地方都要有明确文字，不能只把按钮变灰。任务板上锁住的关也要写原因（现在只显示“未开放”）。

### 1.8 验收
- 每个系统都有 DEBUG 自检，并给出一次真机截图。
- 街头战（事件战、赶塔怪、残余案）在 Unity 里各看一场，确认身体和演出正确。
- 用一个独立测试存档，把 `debugSetPacingDay` 设到第 4、11、18、25 天，各看一次日刊和事件板。
- 装机前后逐文件核对真实存档：只新增账本键，原有数据不变。

## 任务 2：阶段 4，真机计时和经济

### 2.1 真机计时（可以和任务 1 穿插做）
设计稿第 9 节：在真机上用正常玩法计时，每项至少 3 次，取中位数，记下构建号和日期：
- 一关主线（含剧情）；
- 一层塔；
- 一个通缉案（调查＋战斗）；
- 一单 J0、J1、J2；
- 一次制作和一次卖货；
- 一条街坊委托（各类型各一次）；
- 一局牌；
- 一次事件交货和一场事件战；
- 一个残余案。

然后：
1. 把分钟数替换进 `tools/daily-loop/budget.py`（`MIN_*`、`JOBS`）和 `tools/progression-sim/Sources/ProgressionSim/Campaign.swift` 的 `Assumptions`（`postalSeconds`、`craftSeconds`、`errandSeconds` 等）。
2. 重跑：
   ```sh
   swift run -c release --package-path tools/progression-sim ProgressionSim <输出目录> 0,30,90
   python3 tools/progression-sim/report.py <输出目录>
   ```
3. 写报告：每类玩家每天实际要多少分钟、赚多少铜，还是不是每天 1–2 小时、约 30 天打完第一章。

### 2.2 共享服的铜币发行和市场（先研究，不接游戏）
单机版的铜都是新发行的。以后联网时，发行量、市场和通胀另算。先读：
- `CURRENCY_CALIBRATION_20260925.md`
- `ECONOMY_2000_PLAYER_PRO_20260926.md`
- `WORLD_EVENTS_AND_ECONOMY_20260926.md`

然后用真机计时后的新数字更新压力模型，写一份结论，并列出需要用户定的事项。**24 铜工日、银行、产业投资仍是候选，不能宣称经济已无通胀**（`AGENTS.md`）。这一项只出报告，不改游戏。

## 还没决定、需要问用户的
- 模拟器的教会开放时间：模拟器假设教会 Q7 后才开，App 里一直开着。改了以后，前几轮报告的单日最长时长会变。
- 酒馆抽水 5%、打听消息、地下委托 U01–U06 都是候选，没排进这次。

## 交付
- 每个任务开 PR 合进 `main`，PR 里写清楚已验证什么、没验证什么。
- 更新 `docs/development/HANDOFF_WALLS_20260929.md`，或者新写一份交接文档，写明装机的构建号、自检日志和截图位置。
