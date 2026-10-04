# 交接给 Codex：第一章试玩要做的 App 工作 · 2026-09-30

用户 2026-09-30 说：“先按现在这样，把游戏功能全部完善，我要开始试玩了。”本页只写 Mac 上还要做的事、先后顺序和怎么验收。背景和历史见 [HANDOFF_WALLS_20260929.md](HANDOFF_WALLS_20260929.md) 第六轮。回复用户用中文。

## 开始前

- **分支**：本页，以及下面用到的 `StreetTasks.swift` 和 `MPCStreetTaskCatalog.neighborTargets`，都在云端分支 `claude/nifty-planck-80307c` 上。开工时如果 `main` 里还没有它们，先请用户合并这个分支，不要从别处抄代码。
- **先读**：`AGENTS.md` → 本页 → 各项引用的任务单。
- **规矩照旧**：
  - 不覆盖玩家真实存档。每次装机前后都逐个文件核对 Preferences，测试只用隔离的测试 suite；
  - 新账本要有迁移回执，只迁移一次；奖励只发一次；
  - 构建号沿用 169.x，不用 170 以上（避免覆盖另一个会话的工作）；DerivedData 和归档放外置 SSD，不动指向 SSD 的符号链接；
  - 改了 Unity 运行资源要先核对导出新鲜度，再构建宿主；
  - 构建通过、自检通过、截图、录像都不等于用户认可。界面和手感要用户在真机上看过才算。

## 现在的包里有什么（按交付记录，Build169.10，iPhone 13）

**能玩的**：
- 主线 Q1–Q30，按天放开；
- 深井塔 100 层，每天 4 层；
- 通缉十案，旧调查流程；
- 教会 Q7 后开放，工坊 Q5 后开放，重复工作逐单递减；
- 四场城市事件、余案、日刊、酒馆牌局、旧版邮务（核对单据）；
- 新首页港城：23 名街坊、八个柜台、报社。

**本轮查源码发现：街坊委托在这个包里进不去。**
- 首页人物和柜台只读通缉目标：`ContentView.streetTargets` 和 `HomeStreetScene.swift` 里的 `HomeCounterView.localTargets` 都只调 `bountyTargets`。
- App 里唯一调用 `talkToNeighbor` 的地方是旧 3D 街道（`MissionBoardView` 里的 `WisteriaStreetWebView`）。任务 1 下线旧街道后，`.missions` 只剩 DEBUG 参数 `--preview-missions` 能打开。
- 日刊的“街坊委托”只把镜头移到委托板，委托板柜台只有寒暄。
- 后果：23 位街坊的委托、好感和小故事都玩不到；城市贡献度按“街坊委托”计的分也会没有来源。
- 首页任务单任务 1 第 9 条写了“留到下一单”，但后来没有哪份任务单接手。下面第 1 项补上。

**还没进 App 的**：新版送信、B07 六环、城市贡献度、三类街头任务、喷泉和货场贴片。

**真机验收欠着**：首页任务 1 的截图、11 组 DEBUG 自检、最后一次 Preferences 比较；每日玩法 1.8 的剩余检查。用户还没做过视觉认可。

## 要做的事（按顺序）

| # | 做什么 | 依据 | 出包 |
|---|---|---|---|
| 1 | 街坊委托接回首页 | 本页 | 和第 2 项一起 |
| 2 | 试玩包：装机、补验收，交用户开始玩 | 本页、[任务 1 记录](home-map-task1-20260929/README.md)、[1.8 重连清单](daily-device-review-20260929/RECONNECT.md) | 是 |
| 3 | 新版送信 | [首页任务单](CODEX_TASKS_HOME_MAP_20260929.md)任务 2 | 是 |
| 4 | B07 六环 | 首页任务单任务 3 | 是 |
| 5 | 城市贡献度：记分和迁移 | [城市贡献度任务单](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md)第 1 步 | 是 |
| 6 | 城市贡献度：按档开放（三类街头任务、贴片） | 城市贡献度任务单第 2、2.5、3 节，[街头任务记录](street-tasks-20260930/README.md) | 是 |
| 7 | 试玩期间：真机计时 | [每日玩法任务单](CODEX_TASKS_DAILY_LOOP_APP_20260929.md) 2.1，[计时模板](daily-timing-research-20260929/README.md) | 否 |
| 8 | 试玩之后：教会战斗改用 stepper | [共享服 App 任务单](CODEX_TASKS_SHARED_SERVER_M0_20260929.md) | 是 |

第 5 项不依赖首页，可以提前到第 3 项之前做。每做完一项就出一个新包给用户接着玩。

### 1. 街坊委托接回首页（试玩前必须做）

规则库已补 `MPCStreetTaskCatalog.neighborTargets(_:heardMessages:)`（`StreetTaskTargets.swift`，测试在 `StreetTaskTests`）：
- 给出今天没做完的委托的委托人；
- 传话委托如果已经听过口信，改为给出收话人；
- 已完成的、前几天遗留的不给。
- `kind` 是 `.neighbor`，`taskID` 是委托的 offer ID。

App 要做的：
1. `ContentView.streetTargets` 和 `HomeCounterView.localTargets` 都改为 `bountyTargets + neighborTargets`。
   - `heardMessages` 传 `NeighborRecord.heardMessages`。现在 `readNeighbors()` 是私有的，需要在 `GameStore` 加一个只读属性。
   - 以后第 6 项再加上 `streetTargets(街头任务账本)`。
2. 点到 `.neighbor` 目标（人物、任务条、屏外箭头都算）时，调 `game.talkToNeighbor(personID)`，再弹 `NeighborConversationView`。
   - 写法照抄 `MissionBoardView` 里的 sheet；出错时弹“街坊委托暂时无法打开”。
   - 收话人走同一条路：对话页已经能交口信（`canRelayNeighbor`、`relayNeighbor`）。
   - 赶塔怪也在对话页里开打，确认从首页进去能打、能结算，打输可以再打。
3. 委托板柜台列出今天的委托：谁、要什么、给多少铜，做完的划掉。点一条就把镜头移到委托人。
   - 这里只读，不新增“接单”状态。设计稿 2.3 说的“委托板接单”和每种委托补到 2–3 步，要先改规则库，放到第 8 项之后。
4. 日刊的“街坊委托”照旧回委托板。

验收：
- `verifyNeighborsIntegration` 等 11 组自检照过。
- 用隔离测试档，在第 2 天从首页把四种委托各做完一次：交货、三选一、传话（两段）、赶塔怪。重开游戏后不重复发钱。
- 好感到 2 时播出小故事。
- Preferences 不新增键（`heardMessages` 本来就存在街坊记录里）。

### 2. 试玩包

1. 用最新 `main`（含第 1 项）构建、装机；装机前后逐个文件核对 Preferences。
2. 补完首页任务 1：真机截图（首页、八个柜台、报社），逐张看过再写记录。
3. 跑 11 组 DEBUG 自检，只在测试 suite 上跑，不碰真实 suite：
   `--verify-newspaper --verify-remnants --verify-neighbors --verify-city-events --verify-daily-workshop --verify-daily-work --verify-daily-pacing --verify-church-tower --verify-bounty-daily-risk --verify-player-growth --verify-p0`
4. 做 1.8 重连清单的第 4–6 步：在最终包上重跑三类街头战夹具，然后做最后一次 Preferences 比较。
   - 第 2、3 步针对旧 3D 街道，入口已经下线，不再做，改由第 1 项的首页走查代替。
5. 最后用正常启动参数回到玩家入口，再核对一次真实存档。
6. 交给用户时用中文写清楚：
   - 构建号；
   - 这包能玩什么、还没有什么（见上）；
   - 真实存档没动。

### 3–4. 送信、B07 六环

按首页任务单任务 2、3 做，要求不变。另外注意两点：
- 送信的回信、改址、取件三种模板归城市贡献度第 2 档（`.letterChains`）。第 6 项接档位之前，只发直投和认人两种，和设计稿第 1 档一致；另外三种写好先不发，第 6 项再按档开放。
- B07 做完后用 `ProgressionSim human` 估时长，超过 12 分钟按设计稿 3.2 砍“第二个人”，六环不动。

### 5. 城市贡献度：记分和迁移

按任务单第 1 步做。“街坊委托”的记分点就是第 1 项接通的领奖处（回执 `errand-<offer ID>`）。Preferences 只新增 `mistport.cityContribution.v1`。

### 6. 城市贡献度：按档开放

按任务单第 2 步做。规则库这边已经备好：
- **存档**：新增一个键存 `MPCStreetTaskLedger`，建议叫 `mistport.streetTasks.v1`。旧档读进来是空账本，不迁移、不补发。
- **每天**：`open(day:contributionPoints:)`，`day` 用 `MPCDailyPacing` 的存档天数。
- **目标**：首页目标改为 `bountyTargets + neighborTargets + streetTargets`。
- **完成时**：
  - 铜已经由账本加上；
  - `contributionReceipt` 不为空时，按 `.errand` 记城市贡献度；
  - 对 `neighbors` 里每位调 `MPCNeighborLedger.raiseAffinity`，返回小故事就播；
  - 城市委托的 `sceneID` 记在账本的 `scenes` 里。
- **贴片**：`home-map-layout.json` 里 `commissionDecals` 的 12 条，`id` 以 `fountain-`、`yard-` 开头，和 `sceneID` 一致。
  - 显示与否只看存档里的 `scenes`；
  - 不要把 `enabled` 改成 `true` 来显示，那样所有玩家都会看到；
  - 图稿已获用户认可（PR #22），接进 App 后要单独做真机验收。
- **街头战**：编号以 `church_maintenance_street_` 开头，复用塔恶魔的身体，走现有塔战演出，预计不用改 Unity 资源。每类在真机上各看一场。
- **第 3 档的“余案高一段”（`.higherRemnants`）规则库还没写。**
  - 现在余案的塔段取“案件上限”和“玩家已通关的十层段”中较小的一个，材料按案件固定；
  - 设计稿说“材料用高一段的”，和现有模型对不上，需要用户定，再由云端补规则；
  - 在那之前这一档只显示开放文字，不改余案。
- **没开的档**：在委托板和日刊上写“城市贡献度到 N 开放”，不隐藏。

验收按任务单第 3 节。另加三条：
- 三类街头任务各从首页完整做一次；
- 城市委托完成后，四季、昼夜、冬雪下各看一次贴片；
- Preferences 只多上面两个键。

### 7. 试玩期间：真机计时

- 用户试玩时，按[计时模板](daily-timing-research-20260929/README.md)记录，每类至少 3 次。只记正常玩法，不跳剧情、不自动出招。
- 用 `tools/daily-loop/timings.py` 出中位数，再替换这三处的估算：
  - `tools/daily-loop/budget.py`；
  - `tools/progression-sim` 里 `Campaign.swift` 的 `Assumptions`；
  - `HumanTiming.swift`。
- 重跑模拟器，写报告：每天实际要几分钟、赚多少铜。用户要据此定“每天内容时长”。

### 8. 试玩之后

- **共享服 App 任务单**：
  - 第 1 步（把 App 教会战斗的 6 处差别搬进 stepper）只改规则库，云端也能做。开工前问用户由谁做，避免重复。
  - 第 2 步（App 由 stepper 推进，Unity 只播放）在 Mac 上做。
- **设计稿 2.3、2.4 的多步改版**：街坊委托补到 2–3 步，“找东西”加目击者；余案改成 3 步。先由云端改规则库和台词，再接 App。

## 不要做的

- 不加路灯。
- App 不连共享服；共享服 App 部分等第一章试玩之后。
- 不改 24/12 候选经济，不宣称经济没有通胀。
- 主线 Q1–Q30 的战斗不改用 stepper。
- 酒馆抽水、打听消息、地下委托 U01–U06 都是候选，不排。

## 还等用户定的

- 每天的内容时长：模拟器估一般速度每天只有 12–14 分钟正经内容（14 分钟含三类街头任务），离“每天 1–2 小时”差很远。等真机计时出来再定。
- 首页、柜台分层、八方向行走、底栏大小的真机认可，以及首页标注位置。
- “余案高一段”的材料怎么算（第 6 项）。

## 每项交付

- 一项一个 PR，合回 `main`。PR 里写清楚验证了什么、没验证什么。
- 截图和日志放在 `docs/development/` 下的记录目录，按 LFS 提交；只写实际看过的截图。
- 出新包时告诉用户：构建号、这包新增了什么、在哪里玩到（第几天、首页哪个位置），并确认真实存档没动。
- 做完一项就更新本页的表格和 `HANDOFF_WALLS_20260929.md` 的“现在在哪”。
