# 交接：墙关调数、按天推进与每日玩法 · 2026-09-29（第五轮）

## 最新：共享服 M0 技术小样（2026-09-29 深夜，云端）

用户定“做共享服”。按规划书，第一步是 M0 的服务端技术小样，也就是本页下一步第 5 项。已在 Linux 上跑通，[记录](shared-server-m0-20260929/README.md)。

- **规则库**：`ChurchBattleDriver.swift` 新增两样东西，534 项测试全过：
  - `MPCChurchBattleStepper`：教会系战斗 50 毫秒一格推进，只收玩家的五种操作；
  - `MPCChurchBattleDriver`：录制与复算。
- **服务端 `mistport-server/`**：Swift、Hummingbird 2.17、SQLite，16 项测试全过。
  - 账本：发行、转账、销毁分开记；物品批次带来源；操作号幂等；挂单托管与原子成交（40 人抢最后一件只成一笔）。
  - 战斗：开战前预留奖励，服务器用自己的角色复算操作记录，只为确认的胜利付一次。
  - 本地财富带入上限 12,000，另有审计。
  - HTTP 端到端跑通“一笔交易＋亮灯公共目标一战”。
- **还不是上线服务**：
  - App 没接。驱动器目前和调参模型一致，和 App 不一致。
  - 服务器上的角色是运营工具设的。
  - 没有正式登录、TLS、限流、备份演练和压测。
- **下一步（Mac）**：[Codex 任务单](CODEX_TASKS_SHARED_SERVER_M0_20260929.md)。先把 App 教会战斗的现行规则搬进 stepper，再让 App 由 stepper 推进；排在首页和城市贡献度任务单之后。
- **已代定（2026-09-30，用户说“你帮我定”）**：
  - 服务端：Swift＋SQLite 单权威服务，部署在现有 EC2 上（M2 小服开测前再改安全组、弹性 IP、S3 备份权限等，清单见 M0 记录），Caddy 做 TLS，Litestream 持续备份；扩到 2,000 注册前压测，不过线再换 PostgreSQL。
  - 经济：保留 24/12，单机数值不动；共享服每日玩法付单机的 15%（玩家每天一份篮子，城市预算每天最多收 20%）。
  - 本地铜：最多计 12,000，按 15% 折算，服务端已实现。下方“还要用户定”里的“共享服财富上限”一项到此已定。
  - 其他数值：交易费 5% 进城市预算；公共目标奖励 12 铜。
  - 为什么不选“NPC 物价乘 16”：该量级下模型测不出通胀，而且每天一份篮子会让三到五成玩家低于恢复线。
  - 定案复核：9 个情景全部过线；但玩家每天买篮子后，价格线挡不住小额凭空发币，所以通胀监控以账本按来源的发行为主。[判定页“定案”](shared-economy-decisions-20260929/README.md)。
- **街景贴片 PR #22（Codex，草稿）**：三处图稿与 45 幅对比已推送，等用户看图认可，未接 App。
  - 用户 2026-09-30 定**台阶大道不加路灯**，第一批改为喷泉、货场两处。
  - PR #22 里大道的贴片、发光层、数值图、对比图和 `commissionDecals` 条目要由 Codex 删掉，见[城市贡献度任务单 2.5 节](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md#25-城市委托的街景贴片画景色)。

## 现在在哪（2026-09-29 深夜，先读这一节）

`main` 已包含：
- 首页港城设计稿（含城市贡献度第 6 节）；
- 城市贡献度规则库；
- Codex 的首页任务 0 和任务 1（PR #19，Build169.10）。

合并后 Linux 上规则库 526 项测试全部通过。

**已完成：**
- **首页任务 1 已合入**，但真机验收还没做完：
  - 169.10 已装 iPhone 13，但手机锁屏，新版截图和最终 11 组 DEBUG 自检都没做。
  - 装机前后 194 份 Preferences 逐字节一致。
  - 用户还没在真机上认可首页、柜台分层、八方向行走和底栏缩小。
  - 详见 [任务 1 记录](home-map-task1-20260929/README.md)。
- **城市贡献度**：用户已确认门槛 120／220／300、四档名称和各档开放内容。
  - 规则库 `CityContribution.swift` 已写好，App 没接。
  - 街景变化用小块贴片，不重画 15 张首页原画（设计稿 6.5）。

**接下来（Mac 上的 Codex）：**
1. 亮屏后补做任务 1：真机截图、11 组 DEBUG 自检、最终 Preferences 比较，交用户看。
2. 首页任务单的任务 2（送信）、任务 3（B07 六环），见 [首页任务单](CODEX_TASKS_HOME_MAP_20260929.md)。
3. [城市贡献度任务单](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md)：
   - 第 1 步（记分和迁移）可以先做；
   - 2.5 节画景色：3 处街景贴片先出对比图给用户看，完整指令（画什么、怎么调色、交付什么）在[任务单 2.5 节](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md#25-城市委托的街景贴片画景色)；
   - 第 2 步（按档开放）等送信做完再做。
4. 世界事件服务区、委托板上的街坊委托改流程，留到下一单。

**还要用户定：**
- 首页标注位置在任务 1 真机截图上复核；
- 共享服财富上限 12,000；
- 贴片第一批 3 处的具体内容（喷泉花坛彩旗、大道路灯、货场帆布货箱）。

**注意事项：**
- 任务 1 让资源包从约 422 MiB 涨到约 487 MiB（分层柜台和新人物），要留意包体。
- 加急委托、街区难题、城市委托三类新内容的铜币还没进经济模拟。

## 首页港城任务 0：Mac 编译与真机坐标核对

基线 main `7e3731a`；518 项核心测试、两次 iOS Debug 构建与 11 组真机 DEBUG 自检通过。Build169.1 已装 iPhone 13，真实玩家 Preferences 逐字节不变。两张 LFS 标注图、三段首页原始截图和叠图见 [任务 0 记录](home-map-task0-20260929/README.md)。发现广场、货场部分路径穿墙及固定岗位偏离入口，用户已授权按实际路面修正，任务 1 提供新叠图复核；此记录不代表用户认可最终界面。


## 首页港城任务 1：地图、人物与柜台分层（已合入 main，PR #19；真机验收未完成）

分支 `codex/home-map-task1`，基线 `d39e0ed`。用户后续要求包括路线修正、八方向行走、前后景人物比例、日刊移报社及原生报纸文字、店主与莫尔少量全城外出、柜台美术和四枚图标略减。所有柜台固定无人的背景，换人只换透明人物，并保留柜台前景遮挡；已接入地图层、八个柜台、报馆、咖啡馆、餐厅与酒馆。合入最新 main `931a81a` 后 526 项规则测试通过。最新要求把任务条移到地图底部、导航栏上方，并将底栏图标、文字、间距和内容高度整体再缩小 10%；Build169.10 已构建并安装，系统应用清单确认版本。安装期间手机再次锁屏，系统拒绝启动，新版真机截图与最终 11 组自检尚未完成。169.10 安装前后 194 份 Preferences 全部逐字节一致。用户已重新要求推送当前分支，此次布局和验证记录一并提交。任务 1 还未开 PR 或合并，送信及 B07 六环还未实装。记录见 [任务 1](home-map-task1-20260929/README.md)。

## 最新（2026-09-29 夜）：首页港城设计定稿

首页港城与街头任务的设计已由用户定稿（[设计稿](../../mistport-ios/docs/game-design/chapter-one-30/HOME_MAP_STREET_TASKS_20260929.md)），Mac 上的实装见 [Codex 任务单](CODEX_TASKS_HOME_MAP_20260929.md)：先编译并生成标注图，再做首页地图层、送信、B07。

城市贡献度（设计稿第 6 节）：规则库 `CityContribution.swift` 和测试已写好，全部 522 项规则测试通过（Linux）；进度模拟器已在各结算点记分（`contributionByDay`、`contributionTierDays`）。App 接入见 [Codex 任务单](CODEX_TASKS_CITY_CONTRIBUTION_20260929.md)，排在首页任务单之后。门槛 120／220／300 已由用户确认。

## 第五轮：用户决定与云端改动（2026-09-29 晚）

用户的决定：

1. **教会 Q7 后开放**（深井、通缉、教会工作）。
2. **真人计时改用模拟器来做**。
3. **共享服经济的几项候选用模拟计算来定**（已完成，见下文）。
4. **`codex/profile-ui-fixes-20260929` 先开 PR 合并**：已作为 PR #14 合进 `main`，没有冲突；该分支只做过类型检查，没装机。
5. **其余 15 名街坊的委托和小故事补写完**。

本轮云端改动（规则库 518 个测试全过；App 只做了语法解析，**没编译、没装机**）：

- **教会 Q7 后开放**：
  - 规则库：`MPCChurchTowerCatalog.isUnlocked` 改为完成第 7 关或之后任意一关，新增 `lockText`；`todaySummary` 在 Q7 前显示“深井在第 7 关后开放”。深井首通额度仍从第 1 天起每天 4 层累积，第 5 天一开就有 20 层。
  - App：`cityServiceIsUnlocked(.church)` 同一判断，教会页和日刊的深井、通缉两行显示锁定原因。
  - 自检夹具（新档直接进教会的地方）已改：`verifyChurchTower`、`verifyDailyPacing`、`verifyDailyWorkshopIntegration`；按天推进走查默认档改为第 5 天、Q1–Q7 已打、今天 20 层已用。
  - 模拟器的 `churchOpen` 改为调用同一规则。**Mac 上要重跑 11 组自检。**
- **23 名街坊都写好了**：每人 3 条委托、2 段小故事。23 人按固定顺序轮流上门（`MPCNeighborCatalog.rotation`），小故事改在好感 2、3 解锁（原 3、6）。
  - 街头乐师仍是第 7 天第一次上门（赶塔怪），走查夹具 `--daily-street-kind=pest` 不受影响。
  - App 里对话页的好感提示改为读规则库常数；`verifyNeighborsIntegration` 的“人人两段故事”断言改为按好感核对。
- **人类计时模拟器**：[记录](human-timing-20260929/README.md)（`ProgressionSim human`）。
  - App 的技能是自动出招，所以人的差别在战斗外。
  - 按现有内容，一般速度每天约 12 分钟正经内容、全章约 6 小时，**离每天 1–2 小时差很远**；要填满 1 小时得每天再刷 12–18 单巡检/维护。
  - 邮务一单约 20 秒，不是原假设的 150 秒。
  - 结论需要用户定方向（改目标或加内容）。
- **共享服经济判定**：[记录](shared-economy-decisions-20260929/README.md)，脚本在 `tools/economy-decisions/`。模型结论，未实施。
  - 用 V3 整服模型跑了 870 局，另在 2000 账户市场模型上测了交易费和本地财富带入；验收线和判定规则先写进脚本再跑。
  - 结果：
    - 每日玩法的铜在共享服由城市预算付，只付得起单机的 5%；玩家每天买一份篮子时可到 15%。照单机全额发会通胀，开放服务价格峰值 2.1–2.3 倍。
    - 保护篮子覆盖每活跃日一份。
    - 价格验收用严格线：1.25 倍／15%／15%。
    - 地下委托 560 铜可以加。
    - 银行与投资不进首版。
    - 恢复基金维持 96 万。
    - 交易费 5%。
  - **待用户定两件**：
    - 单机每日玩法一天约 142 铜，是 12 铜篮子的 12 倍。三个选项：共享服打折、NPC 物价乘 16、单机本身降下来。
    - 本地财富带入：用户已定**带进共享服**（上限暂按模拟支持的 12,000 铜，待确认）；本地存档可被改的风险由用户接受。
  - 过程里修过三个模型问题：
    - 预算多收的钱闲置在国库，NPC 缺钱。
    - 多收的钱全付给了 NPC 家庭，结果税越高越稳。
    - 交易费判定把两个负数的比值算反。

## 第四轮最新状态：Build169 与设备断线（2026-09-29）

任务0、1.1–1.7的实现已逐项通过PR合并。任务1.8本轮修复真机街道空白：统一离线资源根目录和文件路径规范化，避免`/private/var`与`/var`误判。三类街头战在较早169候选取得胜利和清晰帧；最后169包安装后168份Preferences全一致，地图23人加载及实际到达邮差回调通过。随后iPhone断线，地图图片未取回、收话人实走、最终包三场复测/全套自检/测试后存档复核未完成。不要把本轮标成完整视觉验收通过。

证据、初次安装前后引导标记变化的失败记录、后续比较、待连接步骤见 [1.8设备检查](daily-device-review-20260929/README.md)。真实玩家存档未回灌或覆盖；无法归因的引导标记变化不能被后续比较通过抹去。最近完整规则回归仍是518项/92 suites，11组App自检在Build168通过。

任务2无真人正常玩法计时样本，未替换模型数字。已交付[采集模板、校验器与经济研究](daily-timing-research-20260929/README.md)：16类各至少3次，当前48条样本均缺；5项校验测试通过。预算脚本仍混有候选内容，正式计时与更新压力模型未完成。用户视觉认可、教会开放口径决定仍未收到。以下各构建条目保留历史，不代表最终全部验收状态。

## Mac 最新验证（2026-09-29）

任务 1.2 工坊已接入，当前 Build 164；新工坊自检、旧检修流程17项检查及原六组自检通过，真实玩家仅新增工坊账本键。见 [工坊接入记录](daily-workshop-app-20260929/README.md)。事件效果读取接口已预留，随任务1.4账本接通；后续日刊/事件/街坊/残余案、真机计时未完成。

任务 1.1 已接入四类重复工作递减，新增独立账本及迁移回执，Build 163 真机六组自检通过；同时补齐任务 0 的塔战直接开战日额度检查。见 [任务 1.1 记录](daily-work-app-20260929/README.md)。当前仍未取得用户视觉/手感认可，任务 1.2–1.8、2 待做。

每日玩法任务 0 已完成编译、自检及存档差异核对，Build 161 已装 iPhone 13；516 个规则测试及五组 DEBUG 自检通过。修正深井地图层号未按每日额度变灰的问题。详情、截图、真实旧档通缉迁移的额外变化和待用户验收项见 [任务 0 记录](daily-loop-task0-20260929/README.md)。以下云端“未编译”记录保留为历史，不代表当前构建状态。

接手前按顺序读：本页 → [每日玩法第二阶段记录](daily-content-phase2-20260929/README.md) → [第一阶段记录](workshop-phase1-20260929/README.md) → [每日玩法与经济设计](../../mistport-ios/docs/game-design/chapter-one-30/DAILY_LOOP_AND_ECONOMY_20260929.md) → [按天推进报告](progression-sim-20260929-daily-pacing/README.md) → [第二轮调数报告](progression-sim-20260929-tower-check/README.md) → [第一轮调数报告](progression-sim-20260929/README.md) → [HANDOFF_PROGRESSION_UI_20260928.md](HANDOFF_PROGRESSION_UI_20260928.md) → [HANDOFF_M0_20260928.md](HANDOFF_M0_20260928.md)。回复用户用中文。

## 仓库与分支

- **工作仓库：`github.com/andrewlinbridgeedu-droid/port`**（用户 2026-09-29 定为以后唯一的工作仓库）。换 Claude 账号也可以继续：新账号连上有这个仓库权限的 GitHub 账号，开会话时选这个仓库，先读本页。
- **从 `main` 起步。** 2026-09-29 已通过 PR #1 把所有分支的工作合进 `main`（合并提交 `9b62e55`）。新会话从 `main` 开始；`claude/world-economy-m0`、`claude/world-economy-m0-u62oho`、`claude/nifty-planck-80307c` 都已并入，不要再在旧分支上继续。
- 第一轮交接提到的 `showcase.py` 冲突已合好（保留 PIL 画字，字体优先用 main 选的华文黑体）。

## 第四轮：按天推进第二步（App 接入，云端写，没编译）

- 规则库 `DailyPacing.swift` 新增 `MPCDailyPacingStart`：存档的第 1 天，只写一次。没有记录时，有主线或塔进度的旧存档按 `migratedStart` 迁移（`origin = .migrated`，`recordedAt` 就是迁移回执），没有进度的新档记今天。另有 `missionLockText`（“第 N 关明天开放”／“N 天后开放”）、`towerLockText`、`todaySummary`。新增 2 个测试，规则库 **516 个测试全过**（云端 Linux；读地图文件的街坊测试需要保持仓库目录结构才能跑）。
- `GameStore.swift`：
  - 存档键 `mistport.daily-pacing.start.v1`；`init` 末尾（所有进度和重置参数处理完后）调用 `resolveDailyPacingStart()`，旧档在这里迁移一次。
  - `missionIsAvailable`：未通关的关要 `isMissionOpen`；已通关的重打不受限。发奖路径（`settleActiveMissionRewards`）没有加任何判断，打赢一定发奖。
  - `enterDistrictMap`：下一关还没开放时回城，不再停在黑屏地图。
  - `churchTowerSession`：新层要 `towerFloorIsOpenToday`；已封堵的层随时重打。
  - `restart()` 清掉记录并按新档重记；`debugJumpToOldClockMission`（工坊、第二章走查存档用它播种）清掉记录后按迁移重记，下一关当天可打。`--reset-to-chapter-one-q3/q4` 的清理列表里加了这个键。
  - DEBUG：`debugSetPacingDay(_:)`；`verifyPlayerGrowthPersistence` 改为先断言 Q30 在第 1 天锁住、推到第 40 天后可打；新自检 `--verify-daily-pacing`（新档第 1 天、Q4 明天、重打、次日、重开、深井每天 4 层、旧档只迁移一次、重开新档），通过时打印 `DAILY_PACING_VERIFY_PASS`。
- 界面：城市页“下一关”标题在锁住时显示“第 N 关明天开放”（`ContentView.swift`）；深井页（`ChapterOneTestView.swift`）新层按每日限额禁用并显示原因，胜利页的“下一层”按钮同样判断。任务板上锁住的关沿用原来的“未开放”样式，没有单独写原因。
- 只做了 `swiftc -parse` 语法检查，**没有类型检查、没有编译**。`todaySummary` 还没放到任何界面上。

## 用户 2026-09-29 的决定（第三轮已实装）

1. Q18、Q26 不是墙 → 先选“拉陡塔装备曲线”；实测需要每 20 层战力翻倍后，改为**塔层装备检定**，曲线只温和拉陡。
2. 验收第 3 条改为“只做通缉卡在 Q8”。
3. 通缉战败只扣铜，不再丢随身遗落物。
5. **按天推进**：玩家不能靠投入更多时间取得领先，多玩只能多赚铜币；按每天 1–2 小时、约 30 天打完第一章设计。验收第 4 条改为这个时间预算。用户同意分两步做：第一步规则和模拟器（本轮已完成），第二步 App（见“下一步”）。
4. 验收第 4 条只算过墙必需的支线。

## 本轮完成

- **塔层装备检定**：Q18 第十三击、Q26 押运车猛砸、Q30 总签官猛砸，身上没有来自 F50/F70/F90 或更深的塔装备时按基础生命 140% 结算。新字段 `MPCChurchGearStats.towerDepth`，判断在 `MPCProgressionWalls.meetsTowerFloor`，数值在 `towerCheckBlowHealthPercent`。
- **塔装备曲线**：F2–F10 不变；F20 起每 10 层约 +10% 攻击，护甲生命和减伤同步加快（表见报告）。
- **机制墙跟着加重**：Q12 强化上限 95%；Q22 失败重击 140% 生命、钟匠 5000 血；Q30 总签官 6500 血。
- **Q18、Q26 这一仗本身加压（用户要求）**：裁定者 5200 血 / 140 攻，押运车 5600 血 / 150 攻。满足塔层后中熟练首次剩 36%、37% 血（原 65%、53%），检定不变。
- **通缉战败只扣铜**：`MPCBountyDefeatRisk` 不再返回遗落物；App 两处说明文字和风险自检已改。
- **失败提示**：`defeatHint` 新增 `wornTowerDepth`（App 调用处已传），打到过要求层但身上装备不够深时，提示换装备。
- **测试**：规则库 472 个全过（云端 Linux）。新增 `towerWallsNeedTheirFloor`、`towerDepthComesFromTheDeepestWornPiece`；三个旧测试随改动更新。
- **模拟器**：新打法 `hinted`（按失败提示只补必需支线）；止痛膏重试改为换整套打法（修正了第一轮“低熟练卡 Q8 是因为丢遗落物”的误判，真正原因是机器人总把唯一一瓶药用在同一套会输的打法上）；探针新增 `GEAR_SCALE`，`WALLS=` 新增三个检定键。
- **验收**：六条全过（第 4 条有分母口径说明，见报告）。

| 关 | 状态 | 要求 |
|---|---|---|
| Q3 | 放宽（不是墙） | — |
| Q8 W1 | ✅ 数值墙 | 塔 F10 |
| Q12 W2 | ✅ 机制墙 | B01 七号缺齿剑 |
| Q18 W3 | ✅ 塔层检定 | 身穿 F50 或更深的塔装备 |
| Q22 W4 | ✅ 机制墙 | B04 伪造者倒签笔 |
| Q26 W5 | ✅ 塔层检定 | 身穿 F70 或更深的塔装备 |
| Q30 W6 | ✅ 塔层检定＋机制墙 | 身穿 F90 或更深的塔装备 ＋ B10 绯月寿账签 |

## 按天推进（第三轮，第一步已完成）

- 规则：`DailyPacing.swift` 的 `MPCDailyPacing`。第 1 天开 Q1–Q3、之后每天一关（Q30 在第 28 天）；塔首通每天 4 层、可累积；旧存档用 `migratedStart`。只是判断函数，**还没接进 App 的开战和领奖流程**。新增 4 个测试（规则库共 476 个）。
- 模拟器：主线、塔首通按天开放，逐天记时长，`PACING=` 可临时改参数，`report.py` 输出按天推进表。原“每天打 3 关”的假设已删除。
- 结果：所有熟练度都在第 28 天打完；边推主线边爬塔时单日战斗最长 20–79 分钟、平均 5–9 分钟。

## 需要用户定的

- **第一天已改为开 Q1–Q3**（用户定），Q30 在第 28 天开放；模拟结果改为第 28 天打完。
- **每天剩下的时间怎么填**：已写[每日玩法与经济设计候选](../../mistport-ios/docs/game-design/chapter-one-30/DAILY_LOOP_AND_ECONOMY_20260929.md)（估算脚本 `tools/daily-loop/budget.py`），用户已定（第 8 节）：工坊提前到 Q5 且可以出装备（档位对应塔层、穿戴要求打通该层、属性不超过同档塔装备、计入塔层检定、会磨损）；重复工作按单递减、功勋每天前 2 单；四场事件用设计稿主题；先做街坊委托和无名残余清剿。实施分期见第 10 节。**阶段 1 已完成**（规则库＋模拟器，[记录](workshop-phase1-20260929/README.md)）：`DailyWork.swift`（重复工作递减、功勋每天前 2 单）、`Crafting.swift`（塔材料、四个基础配方、十件工坊装备配方、制作账本、NPC 订单）、`ChurchGear.swift`（工坊装备：档位、穿戴要求、磨损修理、计入塔层检定），工坊开放改到 Q5。**阶段 2 已完成**（规则库＋第一批文案＋模拟器，[记录](daily-content-phase2-20260929/README.md)）：`CityEvents.swift`（四场本地世界事件，事件战每天最多记 2 场，成功改城市、失败只罚一周）、`RemnantCases.swift`（通缉结案后每天一个无名残余小案，铜走递减）、`NeighborErrands.swift`（23 名街坊每天 2–3 条委托，第一批 8 人有专属委托和小故事）、`StreetEncounters.swift`（街头战复用塔恶魔身体和塔战演出路径）。规则库 514 个测试全过。App 都还没接入。

- **模拟器的教会开放时间**（阶段 2 发现）：模拟器假设教会（塔、通缉）Q7 后才开，App 和规则库里教会一直开着。打完天数不受影响，但前几天的塔进度、材料和第 5 天的时长偏了。改不改请用户定，改了以后前几轮报告的单日最长会变。

## 没验证

- **iOS App 从 `cee125a` 起没编译过**，第四轮的按天推进接入也没编译（见上）。 阶段 2 改了 `GameStore.swift` 的工坊开放判断（阶段 1 只改了文字，按钮实际还要 Q16），改成和规则库一样“完成第 5 关或之后任意一关”，也没编译。 本轮 App 只改了：两处通缉说明文字、`verifyBountyDailyRisk` 自检、`wallDefeatHint` 多传一个参数。规则库里 `MPCChurchGearStats` 多了带默认值的字段。
- 没有真机、没有真人试玩；机器人熟练度只能相对比较。Unity 端没有塔层检定、Q12 叠层、Q22 校验失败、Q30 狂暴的专门演出。

## 下一步（按优先级）

**Mac 上的工作已整理成 Codex 任务单：[CODEX_TASKS_DAILY_LOOP_APP_20260929.md](CODEX_TASKS_DAILY_LOOP_APP_20260929.md)**（编译与按天推进验证、每日玩法阶段 3、真机计时与经济阶段 4）。


1. **每日玩法阶段 3（App，Mac）**：日刊；工坊界面接 `MPCCraftingLedger`、`MPCWorkshopOrderBoard`（带事件的 `bonus`、`surcharge`）和工坊装备的穿戴修理；事件板（交货、事件战入口、`MPCCityEventLedger` 的回执和结算）；地图上街坊的委托对话（`MPCNeighborLedger`，传话要走到收话人那里再调 `relay`）；残余案卷（`MPCRemnantLedger`，领奖走 `MPCDailyWorkLedger`）；商店止痛膏价加上 `effects(day:).salveSurcharge`；递减和“今天已记满”的提示。新账本都要进存档并有迁移回执，旧存档读入为空账本。街头战要在 Unity 里各看一场。
2. **按天推进第二步：在 Mac 上编译并验证第四轮的接入**。`xcodebuild` 修掉类型错误；跑 `--verify-daily-pacing` 和 `--verify-player-growth`；真机上先备份 Preferences，确认用户真实存档第一次打开时被迁移（下一关当天可打），并逐文件核对只多了 `mistport.daily-pacing.start.v1` 一个键。可选：把 `todaySummary` 放到城市页；任务板上锁住的关显示原因。
3. 交给 Codex（Mac）：拉 `main`，`xcodebuild`，按惯例备份 Preferences 后装机；看“封线装备”页通缉栏、通缉案卷的遗落物说明、墙关失败提示（含“换上深井第 N 层或更深的装备”）、通缉战败说明，以及几个新机制的实际手感。装机、编号、SSD、存档隔离规矩见 `HANDOFF_PROGRESSION_UI_20260928.md` 和 `AGENTS.md`。
4. 用户对上面两条可选项的意见。
5. 其余 7 件遗落物效果；第二章核心人物战、死亡与继任；服务端账户与可信战斗结算小样（2026-09-29 已在云端做出，见本页顶部“共享服 M0”）。

## 常用命令

```sh
# 规则库测试（Mac）
cd mistport-ios/MistportCombatCore && swift test
# 模拟器：六堵墙探针（约 5 秒）
swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 8,12,18,22,26,30 high,medium,low
# 临时改墙值扫参数，不改代码
WALLS="q18GearCheckHP=160,q30SovereignHP=7000" swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 18,30
# 估算塔装备曲线要多陡（只影响探针）
GEAR_SCALE="attack=2,hp=2,reduction=1.5" swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 18
# 单关逐套打法；TRACE=1 打印每次敌人行动
swift run -c release --package-path tools/progression-sim ProgressionSim fight 22 medium 50 bounty_relic_b04_reverse_seal
# 串行全流程（约 1 分钟）与汇总（含按天推进表）；PACING= 临时改按天参数
# PACING="towerFloorsPerDay=3" swift run -c release --package-path tools/progression-sim ProgressionSim <输出目录> 0,30,90
swift run -c release --package-path tools/progression-sim ProgressionSim <输出目录> 0,30,90
python3 tools/progression-sim/report.py <输出目录>
```

可调键名见 `tools/progression-sim/Sources/ProgressionSim/Walls.swift` 的 `WallTuning`。

## 在 Linux 云端跑 Swift

官方下载被网络策略拦截。从 `archive.ubuntu.com/ubuntu/pool/universe/s/swiftlang/` 取 `swiftlang`、`libswiftlang` 的 6.0.3 deb（`6.0.3-2build1`），再从 `pool/main/libx/libxml2/` 取 `libxml2-16`（`2.14.5+dfsg-0.2ubuntu0.2`），`dpkg -x` 解到临时目录，设 `PATH=<目录>/usr/libexec/swift/bin:$PATH` 和 `LD_LIBRARY_PATH=<目录>/usr/lib/x86_64-linux-gnu:<目录>/usr/lib`。`S9TalentEditorTests` 里一个 `@MainActor` 测试在 Linux 的测试自动发现下编不过：跑测试时在临时副本里去掉这个文件，它只在 Mac 上跑。

每日玩法任务 1.4 已接入：城市事件板、交货和战斗回执、三处城市价格效果。当前装机 Build165；8 项自检通过，事件板四日期截图和存档比较见 `daily-city-events-app-20260929/README.md`。为使日刊入口都有实际目标，先做 1.4–1.6 再汇总 1.3。Unity 三类街头战演出复看、用户视觉认可及任务 2 正常游玩计时仍未完成。

每日玩法 1.5 已接入街坊委托和地图交谈桥接，当前装机 Build166；规则库 9 项、自检 9 项通过，真实存档只新增街坊账本。证据见 `daily-neighbors-app-20260929/README.md`。现行 3D 街道原有 12 人，本次对齐规则库 23 人；实际地图走近触发与赶塔怪 Unity 演出仍待 1.8 检查，不冒充视觉验收。

每日玩法 1.6 已接入无名残余案，当前装机 Build167；8 项规则测试、10 项 App 自检通过，真实存档只新增残余案账本。证据见 `daily-remnants-app-20260929/README.md`。普通记录保留 7 天；在途战斗及已胜未领报酬受保护。接下来汇总日刊（1.3）并执行 1.7/1.8；视觉认可和正常游玩计时仍未完成。

每日玩法 1.3 日刊已接入，当前装机 Build168；11 项 App 自检与规则库 518 项/92 suites 全通过。真实存档只新增日刊回执。四日期截图和存档比较见 `daily-newspaper-app-20260929/README.md`。1.1–1.6 的代码接入已具备；1.7 提示审查、1.8 实地导航/Unity 演出检查和任务 2 真人正常游玩计时尚未完成，不等同用户认可。

任务 1.7 提示审查完成，实际修正酒馆解锁原因、日刊状态、工坊逐项灰按钮原因和任务板 VoiceOver；见 `daily-limit-hints-20260929/README.md`。Build169 候选已编译，但设备仍为 Build168；最终 169 将随 1.8 验收夹具一起装机、归档。
