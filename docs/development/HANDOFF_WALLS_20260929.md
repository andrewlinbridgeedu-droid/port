# 交接：墙关调数、按天推进与每日玩法 · 2026-09-29（第四轮）

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
5. 其余 7 件遗落物效果；第二章核心人物战、死亡与继任；服务端账户与可信战斗结算小样。

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
