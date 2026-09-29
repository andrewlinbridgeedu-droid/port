# 第一章串行成长模拟器

一份新档从 Q1 连续打到 Q30。每一场战斗都用正式的 `MistportCombatCore` 结算，奖励只在真的打赢后发放。用来回答：只打主线能不能通关；不做教会（塔）或通缉会卡在哪一关；每种打法要花多少时间。

战斗驱动 `ChapterDriver.swift`、`TowerDriver.swift` 取自 Codex 2026-09-25 的[逐关审计](../../docs/development/CHAPTER1_PROGRESSION_MATH_AUDIT_20260925.md)，只改了类型名。新写的是 `Campaign.swift`（串行存档和打法）、`main.swift`（场景和关卡图）、`report.py`（汇总）。

## 运行

从项目根目录：

```sh
swift run -c release --package-path tools/progression-sim ProgressionSim <输出目录> [通缉起始日偏移，逗号分隔，默认 0,30,90]
python3 tools/progression-sim/report.py <输出目录>
```

输出 `runs.json`（每次串行运行的逐场记录）、`gate-map.json`（每关需要的最低塔层）、`summary.csv` 和 `summary.md`。

调墙用的两个快速模式（各约 1–5 秒）：

```sh
# 六堵墙逐项探针：光板、只有之前墙的要求、塔全开不带本墙遗落物、最低塔层、首次不用药
swift run -c release --package-path tools/progression-sim ProgressionSim walls <输出目录> 8,12,18,22,26,30 high,medium,low
# 单关逐套打法；TRACE=1 打印敌人每次行动
swift run -c release --package-path tools/progression-sim ProgressionSim fight 18 medium 50 -
```

不改代码扫参数：`WALLS="q18GearCheckHP=160,q30SovereignHP=7000"` 临时改 `MPCProgressionWalls`（键名见 `Walls.swift` 的 `WallTuning`）；`GEAR_SCALE="attack=2,hp=1.5,reduction=1"` 只在探针里把 F10 以上塔装备的增量放大，用来估算装备曲线要多陡。

## 模拟了什么

- **按天推进：** 主线和塔首通按 `MPCDailyPacing`（规则库）按天开放。当天没有可推进的主线时，按打法做当天能做的支线，然后进入下一天。`PACING="towerFloorsPerDay=3"` 可临时改参数。`report.py` 会列出每局第几天打完、单日最长时长，以及每天限 2 小时时第几天打完。
- **熟练度：** 三个机器人代理，不是真人数据。高：零额外延迟；中：每次动作多 0.25 秒；低：多 0.8 秒，并且主线里选目标更差。
- **打法：** `mainOnly` 只打主线；`mainTower` 主线卡住就爬塔；`mainBounty` 卡住就打通缉；`all` 两样轮流；`completionist` 每关前先清完所有能打的支线；`hinted` 卡在墙上时只做墙关提示要求的事（爬到要求的层、做对应的案），不是墙或做完仍输时才像 `all` 那样继续。`hinted` 的支线时间就是验收第 4 条说的“过墙必需的支线”。所有打法都可以做 J0 邮务赚钱，并在商店买遗落物，这两样都不算教会或通缉。
- **一场战斗：** 按出牌顺序、通缉栏遗落物、被动遗落物、勋章时机轮流尝试，任一组合赢了就算通过。机器人是确定性的，同样的状态已经输过就不再重复尝试。止痛膏只有一瓶，会用在第一套打法上；所以卡关后会做 J0 再买一瓶，每次从另一套打法开头重试（最多 8 次，药用掉输了就停），做完支线、判定卡关之前也会再这样重试一轮。
- **存档：** 首通铜币与功勋、塔层装备（每槽取最强）、通缉遗落物与通缉栏、止痛膏（Q4 后可买，一次持有一瓶）、遗落物磨损修理费（付得起才修）、通缉失败的铜币损失（2026-09-29 起不再丢遗落物），以及通缉日刊（每天 3–6 案，受理后保留；卡在机制墙时必刊对应案）。
- **邮务与工坊（2026-09-29）：** 邮务工钱走 `MPCDailyWorkLedger` 的按单递减，一天里降到一成就不再做，铜不够就等第二天（连续 3 天没进展算卡关）。塔每次胜利按 `MPCTowerMaterials` 掉材料。“全都做”和“先清支线”每天结束前去一次工坊：留 3 瓶自熬止痛膏，按 `MPCWorkshopOrderBoard` 的预算做货卖货，材料不够最多重打两次低层塔。`report.py` 列出铜币来源和工坊时长。机器人不做工坊装备。
- **每日内容（2026-09-29 阶段 2）：** “全都做”和“先清支线”每天结束前还会：做完当天的街坊委托（`MPCNeighborLedger`：送货、找东西、传话、赶塔怪），打当周世界事件的事件战（`MPCCityEventLedger`，每天最多算 2 场胜利，最多试 3 次），工坊先为事件和委托备货、交货再做订单；有已结的通缉案时接当天的无名残余（`MPCRemnantLedger`，答对调查后打一场，铜走递减账本）。世界事件没人做就算失败，失败的代价（比如止痛膏涨价一周）对所有打法都生效。街头战斗同样用正式战斗核心结算。`report.py` 列出每日内容表：委托数、解锁小故事、残余案、事件胜场与结果、各项分钟/天。走动和对话的时间是假设（`Assumptions`），要真机计时。
- **关卡图：** 假设商店遗落物都已买齐，对每一关二分查找需要的最低塔层装备，并单独检查“只有十案通缉装备”能不能过。

## 不是游戏数据的假设

每场加 20 秒载入与结算，J0 每单 150 秒，通缉最多等 10 天新案，第 120 天还没打完算卡关。机器人每天会把能推进的都推完，不设单日时长上限；时长上限在汇总时折算。这些都写在 `runs.json` 的 `assumptions` 里，可以在 `Campaign.swift` 里修改。

没有模拟：真人的误操作和学习、剧情对话和探索时间、借物、晋阶。机器人的熟练度只能拿来做相对比较，不能当成真人的胜率。
